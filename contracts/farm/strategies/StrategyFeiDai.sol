// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./BaseStrategy.sol";
import "../../interfaces/ILendingPool.sol"; // aave
import "../../interfaces/ITribalChief.sol";
import "../../interfaces/IGUniPool.sol";
import "../../interfaces/IGUniRouter.sol";
import "../../interfaces/IGUniResolver.sol";


/// @title A title that should describe the contract/interface
/// @author The name of the author
/// @notice Explain to an end user what this does
/// @dev Implemented a strategy to deposit stable coin
contract StrategyFeiDai is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */

    address constant public Dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F); // want
    address constant public Tribe = address(0xc7283b66Eb1EB5FB86327f08e1B5816b0720212B); // reward
    address constant public tribalChief = address(0x9e1076cC0d19F9B0b8019F384B0a29E48Ee46f7f);
    address constant public gUniPoolAddress = address(0x3D1556e84783672f2a3bd187a592520291442539); // fei-dai
    address constant public gUniResolver = address(0x3B01f3534c9505fE8e7cf42794a545A0d2ede976); 
    address constant public gUniRouter = address(0x8CA6fa325bc32f86a12cC4964Edf1f71655007A7);
    address constant public gUniDaiFeiLP = address(0x3D1556e84783672f2a3bd187a592520291442539); // gUni DAI/FEI LP
    uint256 constant public pidWant = 2; // G-UNI DAI/FEI
    uint256 public slippage = 2000;

    /* ========== CONSTRUCTOR ========== */

    constructor(address _controller)
      public
      BaseStrategy(_controller, Dai, Tribe)
    {

    }

    /* ========== VIEW FUNCTIONS ========== */

    function getName() external pure virtual override returns (string memory) {
        return "StrategyFeiDai";
    }

    function balanceOf() public view virtual override returns (uint) {
        return balanceOfWant()
               .add(balanceOfWantInMasterChef());
    }

    function balanceOfWant() public view returns (uint) {
        return IERC20(want).balanceOf(address(this));
    }

    function balanceOfWantInMasterChef() public view returns (uint256) {
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

    // Todo:: Add AAVE lending rewards
    function pendingRewards() public view returns (uint) {
        return ITribalChief(tribalChief).pendingRewards(pidWant, address(this));
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _depositToGUNI(uint256 _want) internal virtual {
        IERC20(want).safeIncreaseAllowance(gUniRouter, _want);
        uint256 amount0In = _want;  // dai
        uint256 amount1In = 0;      // fei
        IGUniPool gUniPool = IGUniPool(gUniPoolAddress);
        (bool zeroForOne, uint256 swapAmount, uint160 swapThreshold) = IGUniResolver(gUniResolver).getRebalanceParams(
            gUniPool,
            amount0In,
            amount1In,
            uint16(slippage)
        );
        // TODO: Check price
        IGUniRouter(gUniRouter).rebalanceAndAddLiquidity(
            gUniPool,
            amount0In,
            amount1In,
            zeroForOne,
            swapAmount,
            swapThreshold,
            0,
            0,
            address(this)
        );
    }
    
    function _deposit() internal virtual override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        require(_want > 0, "no balance can be deposited");
        // deposit to g-uni
        _depositToGUNI(_want);
        
        // stake to TribeChief
        uint256 _stake_available = IERC20(gUniDaiFeiLP).balanceOf(address(this));
        require(_stake_available > 0, 'nothing to stake');
        IERC20(gUniDaiFeiLP).safeApprove(tribalChief, 0);
        IERC20(gUniDaiFeiLP).safeApprove(tribalChief, _stake_available);
        ITribalChief(tribalChief).deposit(pidWant, _stake_available, 0);
    }

    function _claimReward() internal virtual override {
        ITribalChief(tribalChief).harvest(pidWant, address(this));
    }

    function _unstakeFromTribeChief(uint256 _amount) internal virtual  {
        uint256 depositLength = ITribalChief(tribalChief).openUserDeposits(pidWant, address(this));
        uint256[] memory depositAmounts = new uint256[](depositLength);
        uint256 sum = 0;
        uint256 count = 0;

        // Todo:: what if index is too high
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
    }

    /*
        withdraw lp from g-uni
    */
    function _withdrawFromGUNI(uint256 _lpAmount) internal virtual {
        // Todo:: unimplement
        // uint256 balanceBefore = IERC20(gUniDaiFeiLP).balanceOf(address(this));

        // IGUniPool gUniPool = IGUniPool(gUniPoolAddress);
        // uint256 amount0Max = _lpAmount;
        // uint256 amount1Max = 0;
        // bool supply0 = (Dai == IGUniPool(gUniPoolAddress).token0()); // Whether the supply token is token0
        // if (!supply0) {
        //     (amount0Max, amount1Max) = (amount1Max, amount0Max);
        // }
        
        // uint256 burnAmount = _lpAmount.mul(gUniPool.balanceOf(address(this))).div(getAssetAmount()); // check security
        // IERC20(gUniPoolAddress).safeIncreaseAllowance(gUniRouter, burnAmount);
        // // TODO: Check price
        // (uint256 removedAmount0, uint256 removedAmount1, ) = gUniPool.burn(burnAmount, address(this));
        // uint256 balanceAfter = IERC20(gUniDaiFeiLP).balanceOf(address(this));
        // return balanceAfter.sub(balanceBefore);
    }


    // _amount: dai amount
    function _withdrawSome(uint256 _amount)
        internal
        virtual
        override
        returns (uint256)
    {
        uint256 _before = IERC20(want).balanceOf(address(this));
        uint256 _lpAmount = _amount; // g-uni lp

        // unstake from TribeChief
        _unstakeFromTribeChief(_lpAmount);

        // withdraw from g-uni
        _withdrawFromGUNI(_lpAmount);

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
