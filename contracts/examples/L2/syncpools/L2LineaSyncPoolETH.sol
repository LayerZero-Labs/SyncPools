// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L2LineaSyncPoolETHUpgradeable} from "../../../L2/syncPools/L2LineaSyncPoolETHUpgradeable.sol";

contract L2LineaSyncPoolETH is L2LineaSyncPoolETHUpgradeable {
    constructor(address endpoint) L2LineaSyncPoolETHUpgradeable(endpoint) {}
}
