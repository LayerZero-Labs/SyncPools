// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oapp/interfaces/IOAppCore.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oapp/libs/OptionsBuilder.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oapp/interfaces/IOAppOptionsType3.sol";
import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";

import "../../TestHelper.sol";

import "../../../contracts/examples/L2/syncpools/L2ModeSyncPoolETH.sol";
import "../../../contracts/examples/L2/L2ExchangeRateProvider.sol";
import "../../../contracts/L2/syncPools/L2ModeSyncPoolETHUpgradeable.sol";
import "../../../contracts/tokens/MintableOFTUpgradeable.sol";
import "../../../contracts/tokens/DummyTokenUpgradeable.sol";
import "../../../contracts/interfaces/IMintableERC20.sol";
import "../../utils/MockOracle.sol";
import "../../utils/MockRateLimiter.sol";

contract L2ModeSyncPoolETHTest is TestHelper {
    using OptionsBuilder for bytes;

    address tokenA;
    address tokenB;

    address tokenOut;

    L2ModeSyncPoolETH public l2SyncPool;
    address l2ExchangeRateProvider;
    address oracle;
    address rateLimiter;

    address receiver = makeAddr("receiver");

    event L2ExchangeRateProviderSet(address l2ExchangeRateProvider);
    event RateLimiterSet(address rateLimiter);
    event TokenOutSet(address tokenOut);
    event DstEidSet(uint32 dstEid);
    event MinSyncAmountSet(address tokenIn, uint256 minSyncAmount);
    event MessengerSet(address messenger);
    event ReceiverSet(address receiver);

    function setUp() public override {
        super.setUp();

        vm.createSelectFork(MODE.rpcUrl, MODE.forkBlockNumber);

        tokenA = _deployProxy(
            type(DummyTokenUpgradeable).creationCode,
            abi.encode(6),
            abi.encodeCall(DummyTokenUpgradeable.initialize,( "tokenA", "A", address(this)))
        );
        tokenB = _deployProxy(
            type(DummyTokenUpgradeable).creationCode,
            abi.encode(18),
            abi.encodeCall(DummyTokenUpgradeable.initialize, ("tokenB", "B", address(this)))
        );

        DummyTokenUpgradeable(tokenA).grantRole(keccak256("MINTER_ROLE"), address(this));
        DummyTokenUpgradeable(tokenB).grantRole(keccak256("MINTER_ROLE"), address(this));

        tokenOut = _deployProxy(
            type(MintableOFTUpgradeable).creationCode,
            abi.encode(MODE.endpoint),
            abi.encodeCall(MintableOFTUpgradeable.initialize, ("TokenOut", "TO", address(this)))
        );

        l2ExchangeRateProvider = _deployProxy(
            type(L2ExchangeRateProvider).creationCode,
            new bytes(0),
            abi.encodeCall(L2ExchangeRateProvider.initialize, address(this))
        );

        rateLimiter = address(new MockRateLimiter());

        oracle = address(new MockOracle());
        MockOracle(oracle).setPrice(1.01e18);
        L2ExchangeRateProvider(l2ExchangeRateProvider).setRateParameters(Constants.ETH_ADDRESS, oracle, 0, 30 days);

        l2SyncPool = L2ModeSyncPoolETH(
            _deployProxy(
                type(L2ModeSyncPoolETH).creationCode,
                abi.encode(MODE.endpoint),
                abi.encodeCall(
                    L2ModeSyncPoolETHUpgradeable.initialize,
                (    l2ExchangeRateProvider,
                    rateLimiter,
                    tokenOut,
                    ETHEREUM.originEid,
                    MODE.L2messenger,
                    receiver,
                    address(this))
                )
            )
        );

        MintableOFTUpgradeable(tokenOut).grantRole(keccak256("MINTER_ROLE"), address(l2SyncPool));
    }

    function test_ExchangeProvider() public {
        assertEq(l2SyncPool.getL2ExchangeRateProvider(), l2ExchangeRateProvider, "test_ExchangeProvider::1");

        vm.expectEmit(true, true, true, true);
        emit L2ExchangeRateProviderSet(address(0));
        l2SyncPool.setL2ExchangeRateProvider(address(0));

        assertEq(l2SyncPool.getL2ExchangeRateProvider(), address(0), "test_ExchangeProvider::2");

        vm.expectEmit(true, true, true, true);
        emit L2ExchangeRateProviderSet(l2ExchangeRateProvider);
        l2SyncPool.setL2ExchangeRateProvider(l2ExchangeRateProvider);

        assertEq(l2SyncPool.getL2ExchangeRateProvider(), l2ExchangeRateProvider, "test_ExchangeProvider::3");
    }

    function test_RateLimiter() public {
        assertEq(l2SyncPool.getRateLimiter(), rateLimiter, "test_RateLimiter::1");

        vm.expectEmit(true, true, true, true);
        emit RateLimiterSet(address(0));
        l2SyncPool.setRateLimiter(address(0));

        assertEq(l2SyncPool.getRateLimiter(), address(0), "test_RateLimiter::2");

        vm.expectEmit(true, true, true, true);
        emit RateLimiterSet(rateLimiter);
        l2SyncPool.setRateLimiter(rateLimiter);

        assertEq(l2SyncPool.getRateLimiter(), rateLimiter, "test_RateLimiter::3");
    }

    function test_TokenOut() public {
        assertEq(l2SyncPool.getTokenOut(), tokenOut, "test_TokenOut::1");

        vm.expectEmit(true, true, true, true);
        emit TokenOutSet(address(0));
        l2SyncPool.setTokenOut(address(0));

        assertEq(l2SyncPool.getTokenOut(), address(0), "test_TokenOut::2");

        vm.expectEmit(true, true, true, true);
        emit TokenOutSet(tokenOut);
        l2SyncPool.setTokenOut(tokenOut);

        assertEq(l2SyncPool.getTokenOut(), tokenOut, "test_TokenOut::3");
    }

    function test_DstEid() public {
        assertEq(l2SyncPool.getDstEid(), ETHEREUM.originEid, "test_DstEid::1");

        vm.expectEmit(true, true, true, true);
        emit DstEidSet(0);
        l2SyncPool.setDstEid(0);

        assertEq(l2SyncPool.getDstEid(), 0, "test_DstEid::2");

        vm.expectEmit(true, true, true, true);
        emit DstEidSet(ETHEREUM.originEid);
        l2SyncPool.setDstEid(ETHEREUM.originEid);

        assertEq(l2SyncPool.getDstEid(), ETHEREUM.originEid, "test_DstEid::3");
    }

    function test_Token() public {
        L2ModeSyncPoolETHUpgradeable.Token memory tokenAData = l2SyncPool.getTokenData(tokenA);

        assertEq(tokenAData.unsyncedAmountIn, 0, "test_Token::1");
        assertEq(tokenAData.unsyncedAmountOut, 0, "test_Token::2");
        assertEq(tokenAData.minSyncAmount, 0, "test_Token::3");

        vm.expectEmit(true, true, true, true);
        emit MinSyncAmountSet(tokenA, 100);
        l2SyncPool.setMinSyncAmount(tokenA, 100);

        tokenAData = l2SyncPool.getTokenData(tokenA);

        assertEq(tokenAData.unsyncedAmountIn, 0, "test_Token::4");
        assertEq(tokenAData.unsyncedAmountOut, 0, "test_Token::5");
        assertEq(tokenAData.minSyncAmount, 100, "test_Token::6");

        vm.expectEmit(true, true, true, true);
        emit MinSyncAmountSet(tokenA, 0);
        l2SyncPool.setMinSyncAmount(tokenA, 0);

        vm.expectEmit(true, true, true, true);
        emit MinSyncAmountSet(tokenB, 200);
        l2SyncPool.setMinSyncAmount(tokenB, 200);

        tokenAData = l2SyncPool.getTokenData(tokenA);

        assertEq(tokenAData.unsyncedAmountIn, 0, "test_Token::7");
        assertEq(tokenAData.unsyncedAmountOut, 0, "test_Token::8");
        assertEq(tokenAData.minSyncAmount, 0, "test_Token::9");

        L2ModeSyncPoolETHUpgradeable.Token memory tokenBData = l2SyncPool.getTokenData(tokenB);

        assertEq(tokenBData.unsyncedAmountIn, 0, "test_Token::10");
        assertEq(tokenBData.unsyncedAmountOut, 0, "test_Token::11");
        assertEq(tokenBData.minSyncAmount, 200, "test_Token::12");
    }

    function test_Messenger() public {
        assertEq(l2SyncPool.getMessenger(), MODE.L2messenger, "test_Messenger::1");

        vm.expectEmit(true, true, true, true);
        emit MessengerSet(address(0));
        l2SyncPool.setMessenger(address(0));

        assertEq(l2SyncPool.getMessenger(), address(0), "test_Messenger::2");

        vm.expectEmit(true, true, true, true);
        emit MessengerSet(MODE.L2messenger);
        l2SyncPool.setMessenger(MODE.L2messenger);

        assertEq(l2SyncPool.getMessenger(), MODE.L2messenger, "test_Messenger::3");
    }

    function test_Receiver() public {
        assertEq(l2SyncPool.getReceiver(), receiver, "test_Receiver::1");

        vm.expectEmit(true, true, true, true);
        emit ReceiverSet(address(0));
        l2SyncPool.setReceiver(address(0));

        assertEq(l2SyncPool.getReceiver(), address(0), "test_Receiver::2");

        vm.expectEmit(true, true, true, true);
        emit ReceiverSet(receiver);
        l2SyncPool.setReceiver(receiver);

        assertEq(l2SyncPool.getReceiver(), receiver, "test_Receiver::3");
    }

    function test_Deposit() public {
        vm.expectRevert(L2BaseSyncPoolUpgradeable.L2BaseSyncPool__ZeroAmount.selector);
        l2SyncPool.deposit(tokenA, 0, 0);

        vm.expectRevert(L2BaseSyncPoolUpgradeable.L2BaseSyncPool__UnauthorizedToken.selector);
        l2SyncPool.deposit(tokenA, 1, 0);

        l2SyncPool.setL1TokenIn(tokenA, tokenA);

        vm.expectRevert(L2ModeSyncPoolETHUpgradeable.L2ModeSyncPoolETH__OnlyETH.selector);
        l2SyncPool.deposit(tokenA, 1, 0);

        l2SyncPool.setL1TokenIn(Constants.ETH_ADDRESS, Constants.ETH_ADDRESS);

        vm.expectRevert(L2BaseSyncPoolUpgradeable.L2BaseSyncPool__InvalidAmountIn.selector);
        l2SyncPool.deposit(Constants.ETH_ADDRESS, 1, 0);

        uint256 expectedAmount =
            L2ExchangeRateProvider(l2ExchangeRateProvider).getConversionAmount(Constants.ETH_ADDRESS, 1e18);

        vm.expectRevert(L2BaseSyncPoolUpgradeable.L2BaseSyncPool__InsufficientAmountOut.selector);
        l2SyncPool.deposit{value: 1e18}(Constants.ETH_ADDRESS, 1e18, expectedAmount + 1);

        MockRateLimiter(rateLimiter).setRateLimited(true);

        vm.expectRevert("Rate limited");
        l2SyncPool.deposit{value: 1e18}(Constants.ETH_ADDRESS, 1e18, expectedAmount);

        MockRateLimiter(rateLimiter).setRateLimited(false);

        l2SyncPool.deposit{value: 1e18}(Constants.ETH_ADDRESS, 1e18, expectedAmount);

        assertEq(MintableOFTUpgradeable(tokenOut).balanceOf(address(this)), expectedAmount, "test_Deposit::1");

        assertEq(
            keccak256(MockRateLimiter(rateLimiter).deposits(0)),
            keccak256(abi.encode(address(this), Constants.ETH_ADDRESS, 1e18, expectedAmount)),
            "test_Deposit::2"
        );

        L2ModeSyncPoolETHUpgradeable.Token memory tokenAData = l2SyncPool.getTokenData(Constants.ETH_ADDRESS);

        assertEq(tokenAData.unsyncedAmountIn, 1e18, "test_Deposit::3");
        assertEq(tokenAData.unsyncedAmountOut, expectedAmount, "test_Deposit::4");

        uint256 expectedAmount2 =
            L2ExchangeRateProvider(l2ExchangeRateProvider).getConversionAmount(Constants.ETH_ADDRESS, 5e18);

        l2SyncPool.deposit{value: 5e18}(Constants.ETH_ADDRESS, 5e18, expectedAmount2);

        assertEq(
            MintableOFTUpgradeable(tokenOut).balanceOf(address(this)),
            expectedAmount + expectedAmount2,
            "test_Deposit::5"
        );

        assertEq(
            keccak256(MockRateLimiter(rateLimiter).deposits(1)),
            keccak256(abi.encode(address(this), Constants.ETH_ADDRESS, 5e18, expectedAmount2)),
            "test_Deposit::6"
        );

        tokenAData = l2SyncPool.getTokenData(Constants.ETH_ADDRESS);

        assertEq(tokenAData.unsyncedAmountIn, 1e18 + 5e18, "test_Deposit::7");
        assertEq(tokenAData.unsyncedAmountOut, expectedAmount + expectedAmount2, "test_Deposit::8");
    }

    function test_Sync() public {
        vm.expectRevert(L2BaseSyncPoolUpgradeable.L2BaseSyncPool__UnauthorizedToken.selector);
        l2SyncPool.sync(tokenA, "", MessagingFee({nativeFee: 0, lzTokenFee: 0}));

        l2SyncPool.setL1TokenIn(Constants.ETH_ADDRESS, Constants.ETH_ADDRESS);

        vm.expectRevert(L2BaseSyncPoolUpgradeable.L2BaseSyncPool__InsufficientAmountToSync.selector);
        l2SyncPool.sync(Constants.ETH_ADDRESS, "", MessagingFee({nativeFee: 0, lzTokenFee: 0}));

        l2SyncPool.deposit{value: 1e18}(Constants.ETH_ADDRESS, 1e18, 0);

        l2SyncPool.setMinSyncAmount(Constants.ETH_ADDRESS, 2e18);

        vm.expectRevert(L2BaseSyncPoolUpgradeable.L2BaseSyncPool__InsufficientAmountToSync.selector);
        l2SyncPool.sync(Constants.ETH_ADDRESS, "", MessagingFee({nativeFee: 0, lzTokenFee: 0}));

        l2SyncPool.setMinSyncAmount(Constants.ETH_ADDRESS, 1e18);

        vm.expectRevert(abi.encodeWithSelector(IOAppCore.NoPeer.selector, ETHEREUM.originEid));
        l2SyncPool.sync(Constants.ETH_ADDRESS, "", MessagingFee({nativeFee: 0, lzTokenFee: 0}));

        L2ModeSyncPoolETH(l2SyncPool).setPeer(ETHEREUM.originEid, bytes32(uint256(1)));

        _setUpOApp();

        MessagingFee memory fee = l2SyncPool.quoteSync(Constants.ETH_ADDRESS, "", false);

        l2SyncPool.sync{value: fee.nativeFee}(Constants.ETH_ADDRESS, "", fee);
    }

    function _setUpOApp() internal {
        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](1);
        enforcedOptions[0] = EnforcedOptionParam({
            eid: ETHEREUM.originEid,
            msgType: 0,
            options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(1_000_000, 0)
        });

        L2ModeSyncPoolETH(l2SyncPool).setEnforcedOptions(enforcedOptions);

        SetConfigParam[] memory params = new SetConfigParam[](1);
        address[] memory requiredDVNs = new address[](1);
        requiredDVNs[0] = MODE.lzDvn;

        UlnConfig memory ulnConfig = UlnConfig({
            confirmations: 64,
            requiredDVNCount: 1,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: requiredDVNs,
            optionalDVNs: new address[](0)
        });

        params[0] = SetConfigParam(ETHEREUM.originEid, 2, abi.encode(ulnConfig));

        ILayerZeroEndpointV2(MODE.endpoint).setConfig(address(l2SyncPool), MODE.send302, params);
    }

    receive() external payable {}
}
