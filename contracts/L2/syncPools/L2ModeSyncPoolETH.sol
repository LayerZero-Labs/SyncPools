// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    MessagingFee,
    MessagingReceipt
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

import {BaseMessenger} from "../../utils/BaseMessenger.sol";
import {L2BaseSyncPool} from "../L2BaseSyncPool.sol";
import {ICrossDomainMessenger} from "../../interfaces/ICrossDomainMessenger.sol";
import {Constants} from "../../libraries/Constants.sol";
import {IL1Receiver} from "../../interfaces/IL1Receiver.sol";

/**
 * @title L2 Mode Sync Pool for ETH
 * @dev A sync pool that only supports ETH on Mode L2
 * This contract allows to send ETH from L2 to L1 during the sync process
 */
contract L2ModeSyncPoolETH is L2BaseSyncPool, BaseMessenger {
    error L2ModeSyncPoolETH__OnlyETH();

    /**
     * @dev Constructor for L2 Mode Sync Pool for ETH
     * @param messenger The messenger contract address
     * @param l2ExchangeRateProvider Address of the exchange rate provider
     * @param rateLimiter Address of the rate limiter
     * @param tokenOut Address of the token to mint on Layer 2
     * @param dstEid Destination endpoint ID (most of the time, the Layer 1 endpoint ID)
     * @param endpoint Address of the LayerZero endpoint
     * @param owner Address of the owner
     */
    constructor(
        address messenger,
        address l2ExchangeRateProvider,
        address rateLimiter,
        address tokenOut,
        uint32 dstEid,
        address endpoint,
        address owner
    ) L2BaseSyncPool(l2ExchangeRateProvider, rateLimiter, tokenOut, dstEid, endpoint, owner) BaseMessenger(messenger) {}

    /**
     * @dev Only allows ETH to be received
     * @param tokenIn The token address
     * @param amountIn The amount of tokens
     */
    function _receiveTokenIn(address tokenIn, uint256 amountIn) internal virtual override {
        if (tokenIn != Constants.ETH_ADDRESS) revert L2ModeSyncPoolETH__OnlyETH();

        super._receiveTokenIn(tokenIn, amountIn);
    }

    /**
     * @dev Internal function to sync tokens to L1
     * This will send an additional message to the messenger contract after the LZ message
     * This message will contain the ETH that the LZ message anticipates to receive
     * @param dstEid Destination endpoint ID
     * @param l1TokenIn Address of the token on Layer 1
     * @param amountIn Amount of tokens deposited on Layer 2
     * @param amountOut Amount of tokens minted on Layer 2
     * @param extraOptions Extra options for the messaging protocol
     * @param fee Messaging fee
     * @return receipt Messaging receipt
     */
    function _sync(
        uint32 dstEid,
        address l2TokenIn,
        address l1TokenIn,
        uint256 amountIn,
        uint256 amountOut,
        bytes calldata extraOptions,
        MessagingFee calldata fee
    ) internal virtual override returns (MessagingReceipt memory) {
        if (l1TokenIn != Constants.ETH_ADDRESS || l2TokenIn != Constants.ETH_ADDRESS) {
            revert L2ModeSyncPoolETH__OnlyETH();
        }

        address peer = address(uint160(uint256(_getPeerOrRevert(dstEid))));
        uint32 originEid = endpoint.eid();

        MessagingReceipt memory receipt =
            super._sync(dstEid, l2TokenIn, l1TokenIn, amountIn, amountOut, extraOptions, fee);

        bytes memory data = abi.encode(originEid, receipt.guid, l1TokenIn, amountIn, amountOut);
        bytes memory message = abi.encodeWithSelector(IL1Receiver.onMessageReceived.selector, data);

        ICrossDomainMessenger(getMessenger()).sendMessage{value: amountIn}(peer, message, 0);

        return receipt;
    }
}
