pragma solidity 0.6.12;

interface IRariFTribeRewardsDistributorDelegator {
    function claimRewards(address holder, address[] calldata cTokens) external;
}
