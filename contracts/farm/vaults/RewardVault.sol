// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../Pausable.sol";
import "../../interfaces/IController.sol";
import "../../interfaces/IVault.sol";

// yearn yVault reference: (https://github.com/yearn/yearn-protocol/blob/develop/contracts/vaults/yVault.sol)

abstract contract RewardVault is ERC20, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */

    // token and rewardToken can not be same
    IERC20 public token;
    IERC20 public rewardToken;

    uint256 public availableMin = 9500;
    uint256 public farmKeeperFeeMin = 0;
    uint256 public harvestKeeperFeeMin = 0;
    uint256 public constant MAX = 10000;

    uint256 public rewardsPerShareStored;
    mapping(address => uint256) public userRewardPerSharePaid;
    mapping(address => uint256) public rewards;

    address public governance;
    address public controller;
    mapping(address => bool) public keepers;
    mapping(address => uint256) public nonces;

     

    /// @dev The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    /// @dev The EIP-712 typehash for the permit struct used by the contract
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    bytes32 public immutable domainSeparator;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        string memory _name,
        string memory _symbol,
        address _token,
        address _rewardToken,
        address _controller
    ) public ERC20(_name, _symbol) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        _setupDecimals(ERC20(_token).decimals());
        token = IERC20(_token);
        rewardToken = IERC20(_rewardToken);
        controller = _controller;
        governance = msg.sender;
        domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(_name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    /**
     * @notice Triggers an approval from owner to spends
     * @param owner The address to approve from
     * @param spender The address to be approved
     * @param amount The number of tokens that are approved (2^256-1 means infinite)
     * @param deadline The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp, "Expired");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        amount,
                        nonces[owner]++,
                        deadline
                    )
                )
            )
        );
        address signatory = ecrecover(digest, v, r, s);
        require(
            signatory != address(0) && signatory == owner,
            "Invalid signature"
        );
        _approve(owner, spender, amount);
    }

    /* ========== VIEWS ========== */

    function balance() public view returns (uint256) {
        return
            token.balanceOf(address(this)).add(
                IController(controller).balanceOf(address(this))
            );
    }

    // Custom logic in here for how much the vault allows to be borrowed
    // Sets minimum required on-hand to keep small withdrawals cheap
    function available() public view returns (uint256) {
        return token.balanceOf(address(this)).mul(availableMin).div(MAX);
    }

    function getPricePerFullShare() public view returns (uint256) {
        return balance().mul(1e18).div(totalSupply());
    }

    function earned(address account) public view returns (uint256) {
        uint256 totalBalance = balanceOf(account);
        return
            totalBalance
                .mul(rewardsPerShareStored.sub(userRewardPerSharePaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    /* ========== USER MUTATIVE FUNCTIONS ========== */

    function deposit(uint256 _amount) external nonReentrant {
        _updateReward(msg.sender);
        _deposit(_amount);
    }

    /**
     * @notice Deposit ERC20 tokens with permit aka gasless approval.
     * @param amount ERC20 token amount.
     * @param deadline The time at which signature will expire
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function depositWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual nonReentrant whenNotPaused {
        IVault(address(token)).permit(
            _msgSender(),
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
        _updateReward(msg.sender);
        _deposit(amount);
    }

    // No rebalance implementation for lower fees and faster swaps
    function withdraw(uint256 _shares) public nonReentrant {
        _updateReward(msg.sender);

        uint256 r = (balance().mul(_shares)).div(totalSupply());
        _burn(msg.sender, _shares);

        // Check balance
        uint256 b = token.balanceOf(address(this));
        if (b < r) {
            uint256 _withdraw = r.sub(b);
            IController(controller).withdraw(address(this), _withdraw);
            uint256 _after = token.balanceOf(address(this));
            uint256 _diff = _after.sub(b);
            if (_diff < _withdraw) {
                r = b.add(_diff);
            }
        }

        token.safeTransfer(msg.sender, r);
        emit Withdraw(msg.sender, _shares, r);
    }

    function claim() public {
        _updateReward(msg.sender);

        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
        }
        emit Claim(msg.sender, reward);
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        claim();
    }

    // Override underlying transfer function to update reward before transfer, except on staking/withdraw to token master
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        _updateReward(from);
        _updateReward(to);

        super._beforeTokenTransfer(from, to, amount);
    }

    /* ========== KEEPER MUTATIVE FUNCTIONS ========== */

    // Keepers call farm() to send funds to strategy
    function farm() external onlyKeeper {
        uint256 _bal = available();

        uint256 keeperFee = _bal.mul(farmKeeperFeeMin).div(MAX);
        if (keeperFee > 0) {
            token.safeTransfer(msg.sender, keeperFee);
        }

        uint256 amountLessFee = _bal.sub(keeperFee);
        token.safeTransfer(controller, amountLessFee);
        IController(controller).farm(address(this), amountLessFee);

        emit Farm(msg.sender, keeperFee, amountLessFee);
    }

    // Keepers call harvest() to claim rewards from strategy
    // harvest() is marked as onlyEOA to prevent sandwich/MEV attack to collect most rewards through a flash-deposit() follow by a claim
    function harvest() external onlyKeeper {
        uint256 _rewardBefore = rewardToken.balanceOf(address(this));
        IController(controller).harvest(address(this));
        uint256 _rewardAfter = rewardToken.balanceOf(address(this));

        uint256 harvested = _rewardAfter.sub(_rewardBefore);
        uint256 keeperFee = harvested.mul(harvestKeeperFeeMin).div(MAX);
        if (keeperFee > 0) {
            rewardToken.safeTransfer(msg.sender, keeperFee);
        }

        uint256 newRewardAmount = harvested.sub(keeperFee);
        // distribute new rewards to current shares evenly
        rewardsPerShareStored = rewardsPerShareStored.add(
            newRewardAmount.mul(1e18).div(totalSupply())
        );

        emit Harvest(msg.sender, keeperFee, newRewardAmount);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /// @dev Deposit incoming token and mint pool token i.e. shares.
    function _deposit(uint256 _amount) internal {
        uint256 _pool = balance();
        token.safeTransferFrom(msg.sender, address(this), _amount);

        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalSupply())).div(_pool);
        }
        _mint(msg.sender, shares);
        emit Deposit(msg.sender, shares, _amount);
    }

    function _updateReward(address account) internal {
        rewards[account] = earned(account);
        userRewardPerSharePaid[account] = rewardsPerShareStored;
    }
    
    /* ========== RESTRICTED FUNCTIONS ========== */

    function setAvailableMin(uint256 _availableMin) external {
        require(msg.sender == governance, "!governance");
        require(_availableMin < MAX, "over MAX");
        availableMin = _availableMin;
    }

    function setFarmKeeperFeeMin(uint256 _farmKeeperFeeMin) external {
        require(msg.sender == governance, "!governance");
        require(_farmKeeperFeeMin < MAX, "over MAX");
        farmKeeperFeeMin = _farmKeeperFeeMin;
    }

    function setHarvestKeeperFeeMin(uint256 _harvestKeeperFeeMin) external {
        require(msg.sender == governance, "!governance");
        require(_harvestKeeperFeeMin < MAX, "over MAX");
        harvestKeeperFeeMin = _harvestKeeperFeeMin;
    }

    function setGovernance(address _governance) external {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function setController(address _controller) external {
        require(msg.sender == governance, "!governance");
        controller = _controller;
    }

    function addKeeper(address _address) external {
        require(msg.sender == governance, "!governance");
        keepers[_address] = true;
    }

    function removeKeeper(address _address) external {
        require(msg.sender == governance, "!governance");
        keepers[_address] = false;
    }

    function pause() external onlyController {
        _pause();
    }

    function unpause() external onlyController {
        _unpause();
    }

    function shutdown() external onlyController {
        _shutdown();
    }

    function open() external onlyController {
        _open();
    }

    /* ========== MODIFIERS ========== */

    modifier onlyKeeper() {
        require(keepers[msg.sender] == true, "!keeper");
        _;
    }

    modifier onlyController() {
        require(
            address(controller) == _msgSender(),
            "Caller is not the controller"
        );
        _;
    }

    /* ========== EVENTS ========== */

    event Deposit(address indexed user, uint256 shares, uint256 amount);
    event Withdraw(address indexed user, uint256 shares, uint256 amount);
    event Claim(address indexed user, uint256 amount);
    event Farm(address indexed keeper, uint256 keeperFee, uint256 farmedAmount);
    event Harvest(
        address indexed keeper,
        uint256 keeperFee,
        uint256 harvestedAmount
    );
}
