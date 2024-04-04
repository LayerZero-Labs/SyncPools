// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Base Messenger
 * @dev Base contract for setting the messenger contract
 */
abstract contract BaseMessenger is Ownable {
    event MessengerSet(address messenger);

    /**
     * @dev The messenger contract, this is the contract that allows to send and/or receive messages
     * from another chain
     */
    address private _messenger;

    /**
     * @dev Constructor for Base Messenger
     * @param messenger Address of the messenger contract
     */
    constructor(address messenger) {
        _setMessenger(messenger);
    }

    /**
     * @dev Get the messenger address
     * @return The messenger address
     */
    function getMessenger() public view virtual returns (address) {
        return _messenger;
    }

    /**
     * @dev Set the messenger address
     * @param messenger The messenger address
     */
    function setMessenger(address messenger) public virtual onlyOwner {
        _setMessenger(messenger);
    }

    /**
     * @dev Internal function to set the messenger address
     * @param messenger The messenger address
     */
    function _setMessenger(address messenger) internal {
        _messenger = messenger;

        emit MessengerSet(messenger);
    }
}
