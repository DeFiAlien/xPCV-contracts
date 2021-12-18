// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../RewardVault.sol";

contract VaultFeiDai is RewardVault {
    address public growVault;

    constructor(address _controller, address _growVault)
        public
        RewardVault(
            "pcvDai",
            "pcvDai",
            address(0x6B175474E89094C44Da98b954EedeAC495271d0F), // Dai
            address(0xc7283b66Eb1EB5FB86327f08e1B5816b0720212B), // Tribe
            _controller
        )
    {
      growVault = _growVault; 
    }
}
