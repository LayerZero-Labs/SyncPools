// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L2ModeSyncPoolETHUpgradeable} from "../../../L2/syncPools/L2ModeSyncPoolETHUpgradeable.sol";

contract L2ModeSyncPoolETH is L2ModeSyncPoolETHUpgradeable {
    constructor(address endpoint) L2ModeSyncPoolETHUpgradeable(endpoint) {}
}
