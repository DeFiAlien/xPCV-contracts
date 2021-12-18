// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../Pausable.sol";
import "../../interfaces/IController.sol";

/*

 A strategy must implement the following calls;

 - deposit()
 - withdraw(address) must exclude any tokens used in the yield - Controller role - withdraw should return to Controller
 - withdraw(uint) - Controller | Vault role - withdraw should always return to vault
 - withdrawAll() - Controller | Vault role - withdraw should always return to vault
 - harvest() - Controller | Vault role - harvest should always send to vault
 - balanceOf()

 Where possible, strategies must remain as immutable as possible, instead of updating variables, we update the contract by linking it in the controller

*/

abstract contract BaseStrategy is Pausable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */

    address public want;
    address public reward;

    address public governance;
    address public controller;
    address public strategist;

    uint256 public managementFee = 50;
    uint256 public performanceFee = 500;
    uint256 public constant max = 10000;


    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _controller,
        address _want,
        address _reward
    ) public {
        governance = msg.sender;
        strategist = msg.sender;
        controller = _controller;
        want = _want;
        reward = _reward;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setGovernance(address _governance) external {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function setController(address _controller) external {
        require(msg.sender == governance, "!governance");
        controller = _controller;
    }

    function setManagementFee(uint256 _managementFee) external {
        require(msg.sender == governance, "!governance");
        require(_managementFee < max, "over max");
        managementFee = _managementFee;
    }

    function setPerformanceFee(uint256 _performanceFee) external {
        require(msg.sender == governance, "!governance");
        require(_performanceFee < max, "over max");
        performanceFee = _performanceFee;
    }

    function setStrategist(address _strategist) external {
        require(msg.sender == governance || msg.sender == strategist, "!gs");
        strategist = _strategist;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function deposit() external {
        _deposit();
    }

    /// @dev claim and transfer claimed reward to vault
    function harvest() external {
        _claimReward();

        uint256 _balance = IERC20(reward).balanceOf(address(this)); // balance of tribe
        require(_balance > 0, "!_balance");
        uint256 _fee = _balance.mul(performanceFee).div(max);
        IERC20(reward).safeTransfer(strategist, _fee);

        address _vault = IController(controller).vaults(address(this));
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
        IERC20(reward).safeTransfer(_vault, _balance.sub(_fee));
    }

    // Controller only function for creating additional rewards from dust
    function withdraw(IERC20 _asset) external returns (uint256 balance) {
        require(msg.sender == controller, "!controller");
        require(
            want != address(_asset) && reward != address(_asset),
            "cannot withdraw want or reward"
        );
        balance = _asset.balanceOf(address(this));
        _asset.safeTransfer(controller, balance);
    }

    // Withdraw partial funds, normally used with a vault withdrawal
    // from strategy to vaults
    function withdraw(uint256 _amount) external {
        require(msg.sender == controller, "!controller");

        uint256 _balance = IERC20(want).balanceOf(address(this));
        if (_balance < _amount) {
            _amount = _withdrawSome(_amount.sub(_balance));
            _amount = _amount.add(_balance);
        }

        uint256 _fee = _amount.mul(managementFee).div(max);
        IERC20(want).safeTransfer(strategist, _fee);

        address _vault = IController(controller).vaults(address(this));
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
        IERC20(want).safeTransfer(_vault, _amount.sub(_fee));
    }

    // Withdraw all funds, normally used when migrating strategies
    function withdrawAll() external returns (uint256 balance) {
        require(msg.sender == controller, "!controller");
        _withdrawAll();

        balance = IERC20(want).balanceOf(address(this));

        address _vault = IController(controller).vaults(address(this));
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
        IERC20(want).safeTransfer(_vault, balance);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _deposit() internal virtual;

    function _claimReward() internal virtual;

    function _withdrawSome(uint256 _amount) internal virtual returns (uint256);

    function _withdrawAll() internal virtual;

    /* ========== VIEW FUNCTIONS ========== */

    function getName() external pure virtual returns (string memory);

    function balanceOf() public view virtual returns (uint256);
    

}
