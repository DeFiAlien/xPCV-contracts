// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./BaseStrategy.sol";
import "../../interfaces/ILendingPool.sol"; // aave
import "../../interfaces/ITribalChief.sol";

/// @title A title that should describe the contract/interface
/// @author The name of the author
/// @notice Explain to an end user what this does
/// @dev Implemented a strategy that deposit ETH to AAVE and borrow Fei to earn Tribe
///      Then deposit borrowed Fei to G/UNI to earn more Tribe
contract StrategyFeiETH is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */

    address public constant WETH =
        address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // want
    address public constant Tribe =
        address(0xc7283b66Eb1EB5FB86327f08e1B5816b0720212B); // reward
    address public constant Fei =
        address(0x956F47F50A910163D8BF957Cf5846D573E7f87CA); // to borrow
    address public constant tribalChief =
        address(0x9e1076cC0d19F9B0b8019F384B0a29E48Ee46f7f);
    address public constant aaveLendingPool =
        address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    uint256 public constant pidWant = 2;
    // Aave's referral code
    uint16 internal referral; 

    /* ========== CONSTRUCTOR ========== */

    constructor(address _controller, uint16 _referral)
        public
        BaseStrategy(_controller, WETH, Tribe)
    {
        referral = _referral;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function getName() external pure virtual override returns (string memory) {
        return "StrategyFeiETH";
    }

    function balanceOf() public view virtual override returns (uint256) {
        return balanceOfWant().add(balanceOfWantInTribalChief());
    }

    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function balanceOfWantInTribalChief()
        public
        view
        returns (uint256)
    {
        uint256 depositLength = ITribalChief(tribalChief).openUserDeposits(pidWant, address(this));
        
        uint256 depositSum = 0;
        
        for(uint256 i = 0; i < depositLength; i++){
            (uint256 amount, , ) = ITribalChief(tribalChief).depositInfo(pidWant, address(this), i);

            if(amount > 0){
                depositSum = depositSum.add(amount);
            }
        }
        return depositSum;
    }

    function pendingRewards() public view returns (uint256) {
        return ITribalChief(tribalChief).pendingRewards(pidWant, address(this));
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _deposit() internal virtual override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).safeApprove(aaveLendingPool, 0);
            IERC20(want).safeApprove(aaveLendingPool, _want);

            ILendingPool(aaveLendingPool).deposit(
                WETH,
                _want,
                address(this),
                0
            );
            ILendingPool(aaveLendingPool).setUserUseReserveAsCollateral(
                WETH,
                true
            );
            // uint256 amountToBorrowIT = _fromETH(
            //     amountToBorrowETH,
            //     address(investmentToken)
            // );
            uint256 amountToBorrow = 5000;
            

            if (amountToBorrow > 0) {
                ILendingPool(aaveLendingPool).borrow(Fei, amountToBorrow, 2, referral, address(this));
            }
        }
    }

    function _claimReward() internal virtual override {
        ITribalChief(tribalChief).harvest(pidWant, address(this));
    }

    function _withdrawSome(uint256 _amount)
        internal
        virtual
        override
        returns (uint256)
    {
        uint256 _before = IERC20(want).balanceOf(address(this));
        uint256 depositLength = ITribalChief(tribalChief).openUserDeposits(pidWant, address(this));
        uint256[] memory depositAmounts = new uint256[](depositLength);
        uint256 sum = 0;
        uint256 count = 0;

        //Can we combine the below two loops into one - main issue is checking if sum >= _amount
        for(uint256 i = 0; i < depositLength; i++){
            (uint256 amount, , ) = ITribalChief(tribalChief).depositInfo(pidWant, address(this), i);

            if(amount > 0){
                depositAmounts[i] = amount;
                sum = sum.add(amount);
            }
            count++;
            if(sum>=_amount){
                break;
            }
        }
        require(sum >= _amount, "Insufficient amount staked ");
        for(uint256 i = 0; i < count; i++){
            if(depositAmounts[i] > 0){
                //Don't want to withdraw entire deposit of the last depositIndex... but this would be handled in harvest or new staker - clears all dust
                if (i == count - 1){
                    ITribalChief(tribalChief).withdrawFromDeposit(pidWant, sum, address(this), i);
                }
                else{
                    ITribalChief(tribalChief).withdrawFromDeposit(pidWant, depositAmounts[i], address(this), i);
                }
                sum = sum.sub(depositAmounts[i]);
            }
        }

        uint256 _after = IERC20(want).balanceOf(address(this));
        uint256 _withdrew = _after.sub(_before);
        return _withdrew;
    }

    function _withdrawAll() internal virtual override {
        ITribalChief(tribalChief).withdrawAllAndHarvest(pidWant, address(this));
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function emergencyWithdrawWithoutRewards() external {
        // in case something goes wrong with master chef, allow governance to rescue funds
        require(msg.sender == governance, "!governance");
        address _vault = IController(controller).vaults(address(this));
        require(_vault != address(0), "!vault");
        // sent token back to vault
        ITribalChief(tribalChief).emergencyWithdraw(pidWant, address(_vault));
    }
}
