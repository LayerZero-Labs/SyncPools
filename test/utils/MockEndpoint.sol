// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroReceiver.sol";

contract MockEndpoint {
    address public constant lzToken = address(0);

    uint32 public immutable eid;

    uint256 private _feePerBytes = 1e12;

    mapping(address => mapping(uint32 => mapping(bytes32 => uint64))) public nonces;

    constructor(uint32 eid_) {
        eid = eid_;
    }

    function quote(MessagingParams calldata _params, address) public view returns (MessagingFee memory) {
        return MessagingFee(abi.encode(_params).length * _feePerBytes, 0);
    }

    function send(MessagingParams calldata _params, address _refundAddress)
        public
        payable
        returns (MessagingReceipt memory)
    {
        MessagingFee memory fee = quote(_params, msg.sender);
        require(msg.value >= fee.nativeFee, "Insufficient fee");

        uint64 nonce = ++nonces[msg.sender][_params.dstEid][_params.receiver];

        bytes32 guid = keccak256(
            abi.encodePacked(nonce, eid, bytes32(uint256(uint160(msg.sender))), _params.dstEid, _params.receiver)
        );

        if (msg.value > fee.nativeFee) {
            (bool success,) = _refundAddress.call{value: msg.value - fee.nativeFee}("");
            require(success, "Failed to refund");
        }

        return MessagingReceipt(guid, nonce, fee);
    }

    function lzReceive(
        Origin calldata _origin,
        address _receiver,
        bytes32 _guid,
        bytes calldata _message,
        bytes calldata _extraData
    ) public payable {
        ILayerZeroReceiver(_receiver).lzReceive{value: msg.value}(_origin, _guid, _message, msg.sender, _extraData);
    }

    function setDelegate(address _delegate) public {}

    fallback() external {
        revert("Not implemented");
    }

    function setFeePerBytes(uint256 nativeFee_) public {
        _feePerBytes = nativeFee_;
    }
}
