// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./BaseStrategy.sol";
import "../../interfaces/ILendingPool.sol"; // aave
import "../../interfaces/IRariFusePool.sol";
import "../../interfaces/IRariRewardsDistributor.sol";
import "../../interfaces/IRariFTribeRewardsDistributorDelegator.sol";



/// @title A title that should describe the contract/interface
/// @author The name of the author
/// @notice Explain to an end user what this does
/// @dev Implemented a strategy to deposit stable coin
contract StrategyTribe is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */
    
    address constant public tribe = address(0xc7283b66Eb1EB5FB86327f08e1B5816b0720212B); // reward
    address constant public rariRewardsDistributor = address(0xc76190E04012f26A364228Cfc41690429C44165d);
    address constant public tribeDistributor = address(0x73F16f0c0Cd1A078A54894974C5C054D8dC1A3d7);
    address constant public rariFuse8 = address(0xFd3300A9a74b3250F1b2AbC12B47611171910b07);
    address public baseToken;
    

    /* ========== CONSTRUCTOR ========== */

    constructor(address _controller)
      public
      BaseStrategy(_controller, tribe, tribe)
    {
        baseToken = address(0x6B175474E89094C44Da98b954EedeAC495271d0F); // base
    }

    /* ========== VIEW FUNCTIONS ========== */

    function getName() external pure virtual override returns (string memory) {
        return "StrategyTribe";
    }

    function balanceOf() public view virtual override returns (uint) {
        return balanceOfWant()
               .add(balanceOfWantInFuse());
    }

    // Tribe Balance in Strategy
    function balanceOfWant() public view returns (uint) {
        return IERC20(want).balanceOf(address(this));
    }

    // Tribe Balance in Fuse
    function balanceOfWantInFuse() public view returns (uint) {
        return IRariFusePool(rariFuse8).balanceOf(address(this)).mul(IRariFusePool(rariFuse8).exchangeRateStored());
    }

    function pendingRewards() public view returns (uint) {
        address[] memory distributors = new address[](1);
        distributors[0] = tribeDistributor;
        (, uint256[] memory pending, , , ) = IRariRewardsDistributor(rariRewardsDistributor)
          .getUnclaimedRewardsByDistributors(address(this), distributors);
        return pending[0];
    }
    

    /* ========== INTERNAL FUNCTIONS ========== */

    /// @dev move fund from strategy to underlying pool
    function _deposit() internal virtual override {
        uint _want = IERC20(want).balanceOf(address(this));
        require(_want > 0, "no balance can be deposited");
        IERC20(want).safeIncreaseAllowance(rariFuse8, _want);
        IRariFusePool(rariFuse8).mint(_want); // make sure it failed if do not have enough balance
    }

    /// @dev claim rewards from underlying pool to this address
    function _claimReward() internal virtual override {
        address[] memory cTokens = new address[](1);
        cTokens[0] = rariFuse8;
        // uint _before = IERC20(want).balanceOf(address(this));
        IRariFTribeRewardsDistributorDelegator(tribeDistributor).claimRewards(address(this), cTokens);
        // uint _after = IERC20(want).balanceOf(address(this));
        // uint _claimed  = _after.sub(_before);
        // return _claimed
    }

    // withdraw some base and want from underlying pools to this address
    function _withdrawSome(uint _amount) internal virtual override returns (uint) {
        uint _before = IERC20(want).balanceOf(address(this));
        IRariFusePool(rariFuse8).redeemUnderlying(_amount);
        uint _after = IERC20(want).balanceOf(address(this));
        uint _withdrew = _after.sub(_before);
        return _withdrew;
    }

    function _withdrawAll() internal virtual override {
        _withdrawSome(balanceOfWantInFuse());
    }

    function _reinvest() internal virtual {
        uint _before = IERC20(want).balanceOf(address(this));
        _claimReward();
        uint _after = IERC20(want).balanceOf(address(this));
        uint _diff = _after.sub(_before);
        require(_diff > 0, "no diff when reinvest");
        _deposit();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function emergencyWithdrawWithoutRewards() external {
        // allow governance to rescue funds
        require(msg.sender == governance, "!governance");
        address _vault = IController(controller).vaults(address(this));
        require(_vault != address(0), "!vault");
        // withdraw and sent token back to vault
        _withdrawAll();
        uint _before = IERC20(want).balanceOf(address(this));
        IERC20(want).transfer(address(_vault), _before);
    }

    /* ========== external functions for fund manager ========== */

    

    /* ========== external functions for keepers ========== */
    function reinvest() external {
        _reinvest();
    }
}
