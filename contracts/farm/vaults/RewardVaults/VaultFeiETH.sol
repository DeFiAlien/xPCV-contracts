// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../RewardVault.sol";

contract VaultFeiETH is RewardVault {
    address public growVault;

    constructor(address _controller, address _growVault)
        public
        RewardVault(
            "pcvETH",
            "pcvETH",
            address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), // WETH
            address(0xc7283b66Eb1EB5FB86327f08e1B5816b0720212B), // Tribe
            _controller
        )
    {
      growVault = _growVault;
    }
}
