// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../GrowVault.sol";

contract VaultTribe is GrowVault {

    constructor(address _controller)
        public
        GrowVault(
            "pcvTribe",
            "pcvTribe",
            address(0xc7283b66Eb1EB5FB86327f08e1B5816b0720212B), // want: Tribe
            address(0x6B175474E89094C44Da98b954EedeAC495271d0F), // baseToken: Dai
            _controller
        )
    {
    }
}
