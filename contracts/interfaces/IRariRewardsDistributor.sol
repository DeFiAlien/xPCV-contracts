pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface IRariRewardsDistributor {
    function getMaxRedeem ( address account, address cTokenModify ) external returns ( uint256 );
    // function getRewardsDistributorsBySupplier ( address supplier ) external view returns ( uint256[], address[], address[][] );
    function getUnclaimedRewardsByDistributors ( address holder, address[] calldata distributors ) external view returns ( address[] memory, uint256[] memory, address[][] memory, uint256[2][][] memory, uint256[] memory);
    // function getRewardSpeedsByPools ( address[] calldata comptrollers ) external view returns ( address[][], address[][], address[][], uint256[][][], uint256[][][] calldata );
}
