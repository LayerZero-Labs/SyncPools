// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IL1SyncPool} from "../interfaces/IL1SyncPool.sol";
import {IL1Receiver} from "../interfaces/IL1Receiver.sol";

/**
 * @title L1 Base Receiver
 * @notice Base contract for L1 receivers
 * This contract is intended to receive messages from the native L2 bridge, decode the message
 * and then forward it to the L1 sync pool.
 */
abstract contract L1BaseReceiver is Ownable, IL1Receiver {
    error L1BaseReceiver__UnauthorizedCaller();
    error L1BaseReceiver__UnauthorizedL2Sender();

    event L1SyncPoolSet(address l1SyncPool);
    event MessengerSet(address messenger);

    IL1SyncPool private _l1SyncPool;
    address private _messenger;

    /**
     * @dev Constructor for L1 Base Receiver
     * @param l1SyncPool Address of the L1 sync pool
     * @param messenger Address of the messenger contract
     * @param owner Address of the owner
     */
    constructor(address l1SyncPool, address messenger, address owner) Ownable(owner) {
        _setL1SyncPool(l1SyncPool);
        _setMessenger(messenger);
    }

    /**
     * @dev Get the L1 sync pool address
     * @return The L1 sync pool address
     */
    function getL1SyncPool() public view virtual returns (address) {
        return address(_l1SyncPool);
    }

    /**
     * @dev Get the messenger contract address
     * @return The messenger contract address
     */
    function getMessenger() public view virtual returns (address) {
        return _messenger;
    }

    /**
     * @dev Set the L1 sync pool address
     * @param l1SyncPool The L1 sync pool address
     */
    function setL1SyncPool(address l1SyncPool) public virtual onlyOwner {
        _setL1SyncPool(l1SyncPool);
    }

    /**
     * @dev Set the messenger contract address
     * @param messenger The messenger contract address
     */
    function setMessenger(address messenger) public virtual onlyOwner {
        _setMessenger(messenger);
    }

    /**
     * @dev Internal function to set the L1 sync pool address
     * @param l1SyncPool The L1 sync pool address
     */
    function _setL1SyncPool(address l1SyncPool) internal virtual {
        _l1SyncPool = IL1SyncPool(l1SyncPool);

        emit L1SyncPoolSet(l1SyncPool);
    }

    /**
     * @dev Internal function to set the messenger contract address
     * @param messenger The messenger contract address
     */
    function _setMessenger(address messenger) internal virtual {
        _messenger = messenger;

        emit MessengerSet(messenger);
    }

    /**
     * @dev Internal function to forward the message to the L1 sync pool
     * @param originEid Origin endpoint ID
     * @param sender Sender address
     * @param guid Message GUID
     * @param tokenIn Token address
     * @param amountIn Amount of tokens
     * @param amountOut Amount of tokens
     * @param valueToL1SyncPool Value to send to the L1 sync pool
     */
    function _forwardToL1SyncPool(
        uint32 originEid,
        bytes32 sender,
        bytes32 guid,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut,
        uint256 valueToL1SyncPool
    ) internal virtual {
        if (msg.sender != _messenger) revert L1BaseReceiver__UnauthorizedCaller();

        IL1SyncPool l1SyncPool = _l1SyncPool;

        if (_getAuthorizedL2Address(originEid) != sender) revert L1BaseReceiver__UnauthorizedL2Sender();

        l1SyncPool.onMessageReceived{value: valueToL1SyncPool}(originEid, guid, tokenIn, amountIn, amountOut);
    }

    /**
     * @dev Internal function to get the authorized L2 address
     * @param originEid Origin endpoint ID
     * @return The authorized L2 address
     */
    function _getAuthorizedL2Address(uint32 originEid) internal view virtual returns (bytes32) {
        return _l1SyncPool.peers(originEid);
    }
}
