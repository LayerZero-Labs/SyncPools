// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

contract MockSyncPool {
    bytes public data;
    uint256 public value;
    bytes32 private _peer;

    function setPeer(bytes32 peer) public {
        _peer = peer;
    }

    function peers(uint32) external view returns (bytes32) {
        return _peer;
    }

    receive() external payable {
        revert("MockSyncPool::receive");
    }

    fallback() external payable {
        data = msg.data;
        value = msg.value;
    }
}
