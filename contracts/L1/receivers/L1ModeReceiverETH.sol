// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L1BaseReceiver} from "../L1BaseReceiver.sol";
import {ICrossDomainMessenger} from "../../interfaces/ICrossDomainMessenger.sol";
import {Constants} from "../../libraries/Constants.sol";

/**
 * @title L1 Mode Receiver ETH
 * @notice L1 receiver contract for ETH
 * @dev This contract receives messages from the L2 messenger and forwards them to the L1 sync pool
 * It only supports ETH
 */
contract L1ModeReceiverETH is L1BaseReceiver {
    error L1ModeReceiverETH__OnlyETH();

    /**
     * @dev Constructor for L1 Mode Receiver ETH
     * @param l1SyncPool Address of the L1 sync pool
     * @param messenger Address of the messenger contract
     * @param owner Address of the owner
     */
    constructor(address l1SyncPool, address messenger, address owner) L1BaseReceiver(l1SyncPool, messenger, owner) {}

    /**
     * @dev Function to receive messages from the L2 messenger
     * @param message The message received from the L2 messenger
     */
    function onMessageReceived(bytes calldata message) external payable virtual override {
        (uint32 originEid, bytes32 guid, address tokenIn, uint256 amountIn, uint256 amountOut) =
            abi.decode(message, (uint32, bytes32, address, uint256, uint256));

        if (tokenIn != Constants.ETH_ADDRESS) revert L1ModeReceiverETH__OnlyETH();

        address sender = ICrossDomainMessenger(getMessenger()).xDomainMessageSender();

        _forwardToL1SyncPool(
            originEid, bytes32(uint256(uint160(sender))), guid, tokenIn, amountIn, amountOut, msg.value
        );
    }
}
