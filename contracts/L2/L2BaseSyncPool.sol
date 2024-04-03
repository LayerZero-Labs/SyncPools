// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OAppSender, OAppCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import {
    MessagingFee,
    MessagingReceipt
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {OAppOptionsType3} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OAppOptionsType3.sol";

import {IL2ExchangeRateProvider} from "../interfaces/IL2ExchangeRateProvider.sol";
import {IL2SyncPool} from "../interfaces/IL2SyncPool.sol";
import {IMintableERC20} from "../interfaces/IMintableERC20.sol";
import {IRateLimiter} from "../interfaces/IRateLimiter.sol";
import {Constants} from "../libraries/Constants.sol";

/**
 * @title L2 Base Sync Pool
 * @dev Base contract for Layer 2 sync pools
 * A sync pool is an OApp that allows users to deposit tokens on Layer 2, and then sync them to Layer 1
 * using the LayerZero messaging protocol.
 * The L2 sync pool takes care of deposits on the L2 and syncing to the L1 using the L1 sync pool.
 * Once enough tokens have been deposited, anyone can trigger a sync to Layer 1.
 */
abstract contract L2BaseSyncPool is OAppSender, OAppOptionsType3, ReentrancyGuard, IL2SyncPool {
    error L2BaseSyncPool__ZeroAmount();
    error L2BaseSyncPool__InsufficientAmountOut();
    error L2BaseSyncPool__InsufficientAmountToSync();
    error L2BaseSyncPool__UnauthorizedToken();
    error L2BaseSyncPool__InvalidAmountIn();

    event L2ExchangeRateProviderSet(address l2ExchangeRateProvider);
    event RateLimiterSet(address rateLimiter);
    event TokenOutSet(address tokenOut);
    event DstEidSet(uint32 dstEid);
    event MinSyncAmountSet(address tokenIn, uint256 minSyncAmount);
    event L1TokenInSet(address tokenIn, address l1TokenIn);
    event Deposit(address indexed tokenIn, uint256 amountIn, uint256 amountOut);
    event Sync(uint32 dstEid, address indexed tokenIn, uint256 amountIn, uint256 amountOut);

    /**
     * @dev Token data
     * @param unsyncedAmountIn Amount of tokens deposited on Layer 2
     * @param unsyncedAmountOut Amount of tokens minted on Layer 2
     * @param minSyncAmount Minimum amount of tokens required to sync
     * @param l1Address Address of the token on Layer 1, address(0) is unauthorized
     */
    struct Token {
        uint256 unsyncedAmountIn;
        uint256 unsyncedAmountOut;
        uint256 minSyncAmount;
        address l1Address;
    }

    IL2ExchangeRateProvider private _l2ExchangeRateProvider;
    IRateLimiter private _rateLimiter;

    address private _tokenOut;

    uint32 private _dstEid;

    mapping(address => Token) private _tokens;

    /**
     * @dev Constructor for L2 Base Sync Pool
     * @param l2ExchangeRateProvider Address of the exchange rate provider
     * @param rateLimiter Address of the rate limiter
     * @param tokenOut Address of the token to mint on Layer 2
     * @param dstEid Destination endpoint ID (most of the time, the Layer 1 endpoint ID)
     * @param endpoint Address of the LayerZero endpoint
     * @param owner Address of the owner
     */
    constructor(
        address l2ExchangeRateProvider,
        address rateLimiter,
        address tokenOut,
        uint32 dstEid,
        address endpoint,
        address owner
    ) OAppCore(endpoint, owner) Ownable(owner) {
        _setL2ExchangeRateProvider(l2ExchangeRateProvider);
        _setRateLimiter(rateLimiter);
        _setTokenOut(tokenOut);
        _setDstEid(dstEid);
    }

    /**
     * @dev Get the exchange rate provider
     * @return l2ExchangeRateProvider Address of the exchange rate provider
     */
    function getL2ExchangeRateProvider() public view virtual returns (address) {
        return address(_l2ExchangeRateProvider);
    }

    /**
     * @dev Get the rate limiter
     * @return rateLimiter Address of the rate limiter
     */
    function getRateLimiter() public view virtual returns (address) {
        return address(_rateLimiter);
    }

    /**
     * @dev Get the token to mint on Layer 2
     * @return tokenOut Address of the token to mint on Layer 2
     */
    function getTokenOut() public view virtual returns (address) {
        return address(_tokenOut);
    }

    /**
     * @dev Get the destination endpoint ID, most of the time the Layer 1 endpoint ID
     * @return dstEid Destination endpoint ID
     */
    function getDstEid() public view virtual returns (uint32) {
        return _dstEid;
    }

    /**
     * @dev Get token data
     * If the l1Address is address(0), the token is unauthorized
     * @param tokenIn Address of the token
     * @return token Token data
     */
    function getTokenData(address tokenIn) public view virtual returns (Token memory) {
        return _tokens[tokenIn];
    }

    /**
     * @dev Quote the messaging fee for a sync
     * @param tokenIn Address of the token
     * @param extraOptions Extra options for the messaging protocol
     * @param payInLzToken Whether to pay the fee in LZ token
     * @return msgFee Messaging fee
     */
    function quoteSync(address tokenIn, bytes calldata extraOptions, bool payInLzToken)
        public
        view
        virtual
        returns (MessagingFee memory msgFee)
    {
        Token storage token = _tokens[tokenIn];

        uint32 dstEid = _dstEid;

        (bytes memory message, bytes memory options) =
            _buildMessageAndOptions(dstEid, tokenIn, token.unsyncedAmountIn, token.unsyncedAmountOut, extraOptions);

        return _quote(dstEid, message, options, payInLzToken);
    }

    /**
     * @dev Deposit tokens on Layer 2
     * This will mint tokenOut on Layer 2 using the exchange rate for tokenIn to tokenOut.
     * The amount deposited and minted will be stored in the token data which can be synced to Layer 1.
     * Will revert if:
     * - The amountIn is zero
     * - The token is unauthorized (that is, the l1Address is address(0))
     * - The amountOut is less than the minAmountOut
     * @param tokenIn Address of the token
     * @param amountIn Amount of tokens to deposit
     * @param minAmountOut Minimum amount of tokens to mint on Layer 2
     * @return amountOut Amount of tokens minted on Layer 2
     */
    function deposit(address tokenIn, uint256 amountIn, uint256 minAmountOut)
        public
        payable
        virtual
        override
        nonReentrant
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert L2BaseSyncPool__ZeroAmount();

        Token storage token = _tokens[tokenIn];
        if (token.l1Address == address(0)) revert L2BaseSyncPool__UnauthorizedToken();

        emit Deposit(tokenIn, amountIn, minAmountOut);

        _receiveTokenIn(tokenIn, amountIn);

        amountOut = _l2ExchangeRateProvider.getConversionAmount(tokenIn, amountIn);
        if (amountOut < minAmountOut) revert L2BaseSyncPool__InsufficientAmountOut();

        token.unsyncedAmountIn += amountIn;
        token.unsyncedAmountOut += amountOut;

        IRateLimiter rateLimiter = _rateLimiter;
        if (address(rateLimiter) != address(0)) rateLimiter.updateRateLimit(msg.sender, tokenIn, amountIn, amountOut);

        _sendTokenOut(msg.sender, amountOut);

        return amountOut;
    }

    /**
     * @dev Sync tokens to Layer 1
     * This will send a message to the destination endpoint with the token data to
     * sync the tokens minted on Layer 2 to Layer 1.
     * Will revert if:
     * - The token is unauthorized (that is, the l1Address is address(0))
     * - The amount to sync is zero or less than the minSyncAmount
     * @param tokenIn Address of the token
     * @param extraOptions Extra options for the messaging protocol
     * @param fee Messaging fee
     * @return unsyncedAmountIn Amount of tokens deposited on Layer 2
     * @return unsyncedAmountOut Amount of tokens minted on Layer 2
     */
    function sync(address tokenIn, bytes calldata extraOptions, MessagingFee calldata fee)
        public
        payable
        virtual
        override
        nonReentrant
        returns (uint256 unsyncedAmountIn, uint256 unsyncedAmountOut)
    {
        Token storage token = _tokens[tokenIn];

        address l1TokenIn = token.l1Address;
        if (l1TokenIn == address(0)) revert L2BaseSyncPool__UnauthorizedToken();

        unsyncedAmountIn = token.unsyncedAmountIn;
        unsyncedAmountOut = token.unsyncedAmountOut;

        if (unsyncedAmountIn == 0 || unsyncedAmountIn < token.minSyncAmount) {
            revert L2BaseSyncPool__InsufficientAmountToSync();
        }

        token.unsyncedAmountIn = 0;
        token.unsyncedAmountOut = 0;

        uint32 dstEid = _dstEid;

        emit Sync(dstEid, tokenIn, unsyncedAmountIn, unsyncedAmountOut);

        _sync(dstEid, tokenIn, l1TokenIn, unsyncedAmountIn, unsyncedAmountOut, extraOptions, fee);

        return (unsyncedAmountIn, unsyncedAmountOut);
    }

    /**
     * @dev Set the exchange rate provider
     * @param l2ExchangeRateProvider Address of the exchange rate provider
     */
    function setL2ExchangeRateProvider(address l2ExchangeRateProvider) public virtual onlyOwner {
        _setL2ExchangeRateProvider(l2ExchangeRateProvider);
    }

    /**
     * @dev Set the rate limiter
     * @param rateLimiter Address of the rate limiter
     */
    function setRateLimiter(address rateLimiter) public virtual onlyOwner {
        _setRateLimiter(rateLimiter);
    }

    /**
     * @dev Set the token to mint on Layer 2
     * @param tokenOut Address of the token to mint on Layer 2
     */
    function setTokenOut(address tokenOut) public virtual onlyOwner {
        _setTokenOut(tokenOut);
    }

    /**
     * @dev Set the destination endpoint ID, most of the time the Layer 1 endpoint ID
     * @param dstEid Destination endpoint ID
     */
    function setDstEid(uint32 dstEid) public virtual onlyOwner {
        _setDstEid(dstEid);
    }

    /**
     * @dev Set the minimum amount of tokens required to sync
     * @param tokenIn Address of the token
     * @param minSyncAmount Minimum amount of tokens required to sync
     */
    function setMinSyncAmount(address tokenIn, uint256 minSyncAmount) public virtual onlyOwner {
        _setMinSyncAmount(tokenIn, minSyncAmount);
    }

    /**
     * @dev Set the Layer 1 address of the token
     * @param l2TokenIn Address of the token on Layer 2
     * @param l1TokenIn Address of the token on Layer 1
     */
    function setL1TokenIn(address l2TokenIn, address l1TokenIn) public virtual onlyOwner {
        _setL1TokenIn(l2TokenIn, l1TokenIn);
    }

    /**
     * @dev Internal function to set the exchange rate provider
     * @param l2ExchangeRateProvider Address of the exchange rate provider
     */
    function _setL2ExchangeRateProvider(address l2ExchangeRateProvider) internal virtual {
        _l2ExchangeRateProvider = IL2ExchangeRateProvider(l2ExchangeRateProvider);

        emit L2ExchangeRateProviderSet(l2ExchangeRateProvider);
    }

    /**
     * @dev Internal function to set the rate limiter
     * @param rateLimiter Address of the rate limiter
     */
    function _setRateLimiter(address rateLimiter) internal virtual {
        _rateLimiter = IRateLimiter(rateLimiter);

        emit RateLimiterSet(rateLimiter);
    }

    /**
     * @dev Internal function to set the token to mint on Layer 2
     * @param tokenOut Address of the token to mint on Layer 2
     */
    function _setTokenOut(address tokenOut) internal virtual {
        _tokenOut = tokenOut;

        emit TokenOutSet(tokenOut);
    }

    /**
     * @dev Internal function to set the destination endpoint ID, most of the time the Layer 1 endpoint ID
     * @param dstEid Destination endpoint ID
     */
    function _setDstEid(uint32 dstEid) internal virtual {
        _dstEid = dstEid;

        emit DstEidSet(dstEid);
    }

    /**
     * @dev Internal function to set the minimum amount of tokens required to sync
     * @param tokenIn Address of the token
     * @param minSyncAmount Minimum amount of tokens required to sync
     */
    function _setMinSyncAmount(address tokenIn, uint256 minSyncAmount) internal virtual {
        _tokens[tokenIn].minSyncAmount = minSyncAmount;

        emit MinSyncAmountSet(tokenIn, minSyncAmount);
    }

    /**
     * @dev Internal function to set the Layer 1 address of the token
     * @param l2TokenIn Address of the token on Layer 2
     * @param l1TokenIn Address of the token on Layer 1
     */
    function _setL1TokenIn(address l2TokenIn, address l1TokenIn) internal virtual {
        _tokens[l2TokenIn].l1Address = l1TokenIn;

        emit L1TokenInSet(l2TokenIn, l1TokenIn);
    }

    /**
     * @dev Internal function to receive tokens on Layer 2
     * @param tokenIn Address of the token
     * @param amountIn Amount of tokens to receive
     */
    function _receiveTokenIn(address tokenIn, uint256 amountIn) internal virtual {
        if (tokenIn == Constants.ETH_ADDRESS) {
            if (amountIn != msg.value) revert L2BaseSyncPool__InvalidAmountIn();
        } else {
            if (msg.value != 0) revert L2BaseSyncPool__InvalidAmountIn();

            // warning: not safe with transfer tax tokens
            SafeERC20.safeTransferFrom(IERC20(tokenIn), msg.sender, address(this), amountIn);
        }
    }

    /**
     * @dev Internal function to sync tokens to Layer 1
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
        address,
        address l1TokenIn,
        uint256 amountIn,
        uint256 amountOut,
        bytes calldata extraOptions,
        MessagingFee calldata fee
    ) internal virtual returns (MessagingReceipt memory) {
        (bytes memory message, bytes memory options) =
            _buildMessageAndOptions(dstEid, l1TokenIn, amountIn, amountOut, extraOptions);

        return _lzSend(dstEid, message, options, fee, msg.sender);
    }

    /**
     * @dev Internal function to build the message and options for the messaging protocol
     * @param dstEid Destination endpoint ID
     * @param tokenIn Address of the token
     * @param amountIn Amount of tokens deposited on Layer 2
     * @param amountOut Amount of tokens minted on Layer 2
     * @param extraOptions Extra options for the messaging protocol
     * @return message Message for the messaging protocol
     * @return options Options for the messaging protocol
     */
    function _buildMessageAndOptions(
        uint32 dstEid,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut,
        bytes calldata extraOptions
    ) internal view virtual returns (bytes memory message, bytes memory options) {
        message = abi.encode(tokenIn, amountIn, amountOut);
        options = combineOptions(dstEid, 0, extraOptions);
    }

    /**
     * @dev Internal function to send tokenOut to an account
     * @param account Address of the account
     * @param amount Amount of tokens to send
     */
    function _sendTokenOut(address account, uint256 amount) internal virtual {
        IMintableERC20(_tokenOut).mint(account, amount);
    }
}
