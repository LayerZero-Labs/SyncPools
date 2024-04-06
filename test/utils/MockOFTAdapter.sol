// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oft/OFTAdapterUpgradeable.sol";

contract MockOFTAdapter is OFTAdapterUpgradeable {
    constructor(address token, address lzEndpoint) OFTAdapterUpgradeable(token, lzEndpoint) {}

    function initialize(address owner) external initializer {
        __OFTAdapter_init(owner);
        __Ownable_init(owner);
    }
}
