pragma solidity 0.6.12;

interface IVault {
    function token() external view returns (address);
    function farm() external;
    function harvest() external;
    function permit(
        address,
        address,
        uint256,
        uint256,
        uint8,
        bytes32,
        bytes32
    ) external;
}
