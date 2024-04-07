// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oapp/interfaces/IOAppCore.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oapp/OAppReceiverUpgradeable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "../TestHelper.sol";

import "../utils/MockEndpoint.sol";
import "../utils/MockERC20.sol";
import "../../contracts/examples/L1/L1SyncPoolETH.sol";
import "../../contracts/examples/mock/L1VaultETH.sol";
import "../../contracts/tokens/DummyTokenUpgradeable.sol";

contract L1SyncPoolTest is TestHelper {
    L1SyncPoolETH public l1SyncPool;
    MockEndpoint public endpoint;

    L1VaultETH public l1Vault;

    address public tokenA;
    address public tokenB;
    address public tokenOut;

    address public lockBox = makeAddr("lockBox");

    event ReceiverSet(uint32 indexed originEid, address receiver);
    event TokenOutSet(address tokenOut);
    event LockBoxSet(address lockBox);
    event InsufficientDeposit(
        uint32 indexed originEid,
        bytes32 guid,
        uint256 actualAmountOut,
        uint256 expectedAmountOut,
        uint256 unbackedTokens
    );
    event Fee(uint32 indexed originEid, bytes32 guid, uint256 actualAmountOut, uint256 expectedAmountOut, uint256 fee);
    event VaultSet(address Vault);
    event DummyTokenSet(uint32 originEid, address MockERC20);

    function setUp() public override {
        super.setUp();

        tokenA = address(new MockERC20("TokenA", "A", 18));
        tokenB = address(new MockERC20("TokenB", "B", 6));

        endpoint = new MockEndpoint(ETHEREUM.originEid);

        l1Vault = new L1VaultETH();
        tokenOut = address(l1Vault);

        l1SyncPool = L1SyncPoolETH(
            _deployProxy(
                type(L1SyncPoolETH).creationCode,
                abi.encode(address(endpoint)),
                abi.encodeWithSelector(
                    L1SyncPoolETH.initialize.selector,
                    address(l1Vault),
                    address(tokenOut),
                    address(lockBox),
                    address(this)
                )
            )
        );

        l1Vault.depositETH{value: 1e18}(1e18, address(1));
        (bool s,) = address(l1Vault).call{value: 0.04e18}("");
        require(s, "L1SyncPoolTest::setUp:1");
    }

    function test_Reinitialize() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        l1SyncPool.initialize(address(l1Vault), address(tokenOut), address(lockBox), address(this));
    }

    function test_TokenOut() public {
        assertEq(l1SyncPool.getTokenOut(), tokenOut, "test_TokenOut::1");

        vm.expectEmit(true, true, true, true);
        emit TokenOutSet(address(0));
        l1SyncPool.setTokenOut(address(0));

        assertEq(l1SyncPool.getTokenOut(), address(0), "test_TokenOut::2");

        vm.expectEmit(true, true, true, true);
        emit TokenOutSet(tokenOut);
        l1SyncPool.setTokenOut(tokenOut);

        assertEq(l1SyncPool.getTokenOut(), tokenOut, "test_TokenOut::3");
    }

    function test_LockBox() public {
        assertEq(l1SyncPool.getLockBox(), lockBox, "test_LockBox::1");

        vm.expectEmit(true, true, true, true);
        emit LockBoxSet(address(0));
        l1SyncPool.setLockBox(address(0));

        assertEq(l1SyncPool.getLockBox(), address(0), "test_LockBox::2");

        vm.expectEmit(true, true, true, true);
        emit LockBoxSet(lockBox);
        l1SyncPool.setLockBox(lockBox);

        assertEq(l1SyncPool.getLockBox(), lockBox, "test_LockBox::3");
    }

    function test_Receiver() public {
        uint32 originEid = 1;
        address receiver = makeAddr("receiver");

        assertEq(l1SyncPool.getReceiver(originEid), address(0), "test_Receiver::1");

        vm.expectEmit(true, true, true, true);
        emit ReceiverSet(originEid, receiver);
        l1SyncPool.setReceiver(originEid, receiver);

        assertEq(l1SyncPool.getReceiver(originEid), receiver, "test_Receiver::2");

        vm.expectEmit(true, true, true, true);
        emit ReceiverSet(originEid, address(0));
        l1SyncPool.setReceiver(originEid, address(0));

        assertEq(l1SyncPool.getReceiver(originEid), address(0), "test_Receiver::3");
    }

    function test_Vault() public {
        assertEq(l1SyncPool.getVault(), address(l1Vault), "test_Vault::1");

        vm.expectEmit(true, true, true, true);
        emit VaultSet(address(0));
        l1SyncPool.setVault(address(0));

        assertEq(l1SyncPool.getVault(), address(0), "test_Vault::2");

        vm.expectEmit(true, true, true, true);
        emit VaultSet(address(l1Vault));
        l1SyncPool.setVault(address(l1Vault));

        assertEq(l1SyncPool.getVault(), address(l1Vault), "test_Vault::3");
    }

    function test_DummyToken() public {
        uint32 originEid = 1;
        address dummy = makeAddr("dummy");

        assertEq(l1SyncPool.getDummyToken(originEid), address(0), "test_DummyToken::1");

        vm.expectEmit(true, true, true, true);
        emit DummyTokenSet(originEid, dummy);
        l1SyncPool.setDummyToken(originEid, dummy);

        assertEq(l1SyncPool.getDummyToken(originEid), dummy, "test_DummyToken::2");

        vm.expectEmit(true, true, true, true);
        emit DummyTokenSet(originEid, address(0));
        l1SyncPool.setDummyToken(originEid, address(0));

        assertEq(l1SyncPool.getDummyToken(originEid), address(0), "test_DummyToken::3");
    }

    function test_Sweep() public {
        MockERC20(tokenA).mint(address(l1SyncPool), 100e6);

        assertEq(MockERC20(tokenA).balanceOf(address(l1SyncPool)), 100e6, "test_Sweep::1");

        l1SyncPool.sweep(tokenA, address(this), 100e6);

        assertEq(MockERC20(tokenA).balanceOf(address(l1SyncPool)), 0, "test_Sweep::2");
        assertEq(MockERC20(tokenA).balanceOf(address(this)), 100e6, "test_Sweep::3");

        MockERC20(tokenB).mint(address(l1SyncPool), 2e18);

        assertEq(MockERC20(tokenB).balanceOf(address(l1SyncPool)), 2e18, "test_Sweep::4");

        l1SyncPool.sweep(tokenB, address(this), 1e18);

        assertEq(MockERC20(tokenB).balanceOf(address(l1SyncPool)), 1e18, "test_Sweep::5");
        assertEq(MockERC20(tokenB).balanceOf(address(this)), 1e18, "test_Sweep::6");

        vm.deal(address(l1SyncPool), 3e18);

        assertEq(address(l1SyncPool).balance, 3e18, "test_Sweep::7");

        vm.expectRevert(L1BaseSyncPoolUpgradeable.L1BaseSyncPool__NativeTransferFailed.selector);
        l1SyncPool.sweep(Constants.ETH_ADDRESS, address(this), 1e18);

        address user = makeAddr("user");

        l1SyncPool.sweep(Constants.ETH_ADDRESS, user, 1e18);

        assertEq(address(l1SyncPool).balance, 2e18, "test_Sweep::8");
        assertEq(user.balance, 1e18, "test_Sweep::9");
    }

    function test_LzReceiveCase1() external {
        uint256 amountIn = 1e18;
        uint256 amountOut = 0.9e18;

        vm.expectRevert(abi.encodeWithSelector(OAppReceiverUpgradeable.OnlyEndpoint.selector, address(this)));
        l1SyncPool.lzReceive(Origin(0, 0, 0), 0, "", address(0), "");

        vm.prank(address(endpoint));
        vm.expectRevert(abi.encodeWithSelector(IOAppCore.NoPeer.selector, 0));
        l1SyncPool.lzReceive(Origin(0, 0, 0), 0, "", address(0), "");

        bytes32 peer = bytes32(uint256(uint160(makeAddr("peer"))));

        l1SyncPool.setPeer(MODE.originEid, peer);

        vm.prank(address(endpoint));
        vm.expectRevert(abi.encodeWithSelector(IOAppCore.OnlyPeer.selector, MODE.originEid, 0));
        l1SyncPool.lzReceive(Origin(MODE.originEid, 0, 0), 0, "", address(0), "");

        vm.prank(address(endpoint));
        vm.expectRevert(L1SyncPoolETH.L1SyncPoolETH__OnlyETH.selector);
        l1SyncPool.lzReceive(Origin(MODE.originEid, peer, 0), 0, abi.encode(tokenA, 0, 0), address(0), "");

        bytes memory message = abi.encode(Constants.ETH_ADDRESS, amountIn, amountOut);

        vm.prank(address(endpoint));
        vm.expectRevert(L1SyncPoolETH.L1SyncPoolETH__UnsetDummyToken.selector);
        l1SyncPool.lzReceive(Origin(MODE.originEid, peer, 0), 0, message, address(0), "");

        DummyTokenUpgradeable(tokenA).grantRole(keccak256("MINTER_ROLE"), address(l1SyncPool));

        l1SyncPool.setDummyToken(MODE.originEid, tokenA);

        vm.prank(address(endpoint));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(l1SyncPool),
                keccak256("SYNC_POOL_ROLE")
            )
        );
        l1SyncPool.lzReceive(Origin(MODE.originEid, peer, 0), 0, message, address(0), "");

        l1Vault.grantRole(keccak256("SYNC_POOL_ROLE"), address(l1SyncPool));

        vm.prank(address(endpoint));
        vm.expectRevert("L1Vault: dummy token not set");
        l1SyncPool.lzReceive(Origin(MODE.originEid, peer, 0), 0, message, address(0), "");

        l1Vault.addDummyETH(address(tokenA));

        uint256 lockBoxBalance = IERC20(tokenOut).balanceOf(lockBox);

        uint256 actualAmountOut = l1Vault.previewDeposit(amountIn);

        vm.expectEmit(true, true, true, true);
        emit Fee(MODE.originEid, 0, actualAmountOut, amountOut, actualAmountOut - amountOut);

        vm.prank(address(endpoint));
        l1SyncPool.lzReceive(Origin(MODE.originEid, peer, 0), 0, message, address(0), "");

        assertEq(l1SyncPool.getTotalUnbackedTokens(), 0, "test_LzReceiveCase1::1");
        assertEq(IERC20(tokenOut).balanceOf(lockBox), lockBoxBalance + amountOut, "test_LzReceiveCase1::2");
        assertEq(IERC20(tokenOut).balanceOf(address(l1SyncPool)), actualAmountOut - amountOut, "test_LzReceiveCase1::3");

        uint256 amountOut2 = 1e18;

        message = abi.encode(Constants.ETH_ADDRESS, amountIn, amountOut2);

        vm.expectEmit(true, true, true, true);
        emit InsufficientDeposit(MODE.originEid, 0, actualAmountOut, amountOut2, amountOut2 - actualAmountOut); // the previous fee will cover the deviation

        vm.prank(address(endpoint));
        l1SyncPool.lzReceive(Origin(MODE.originEid, peer, 0), 0, message, address(0), "");

        uint256 expectedBalance = (actualAmountOut - amountOut) - (amountOut2 - actualAmountOut);

        assertEq(l1SyncPool.getTotalUnbackedTokens(), 0, "test_LzReceiveCase1::4");
        assertEq(IERC20(tokenOut).balanceOf(lockBox), lockBoxBalance + amountOut + amountOut2, "test_LzReceiveCase1::5");
        assertEq(IERC20(tokenOut).balanceOf(address(l1SyncPool)), expectedBalance, "test_LzReceiveCase1::6");

        uint256 amountOut3 = 2e18;

        message = abi.encode(Constants.ETH_ADDRESS, amountIn, amountOut3);

        vm.expectEmit(true, true, true, true);
        emit InsufficientDeposit(MODE.originEid, 0, actualAmountOut, amountOut3, amountOut3 - actualAmountOut);

        vm.prank(address(endpoint));
        l1SyncPool.lzReceive(Origin(MODE.originEid, peer, 0), 0, message, address(0), "");

        assertGt(l1SyncPool.getTotalUnbackedTokens(), 0, "test_LzReceiveCase1::7");
        assertEq(
            l1SyncPool.getTotalUnbackedTokens(),
            (amountOut + amountOut2 + amountOut3) - 3 * actualAmountOut,
            "test_LzReceiveCase1::8"
        );
        assertEq(IERC20(tokenOut).balanceOf(lockBox), lockBoxBalance + 3 * actualAmountOut, "test_LzReceiveCase1::9");
        assertEq(IERC20(tokenOut).balanceOf(address(l1SyncPool)), 0, "test_LzReceiveCase1::10");
    }

    function test_LzReceiveCase2() external {
        uint256 amountIn = 1e18;
        uint256 amountOut = 1e18 - 1;

        bytes32 peer = bytes32(uint256(uint160(makeAddr("peer"))));

        l1SyncPool.setPeer(LINEA.originEid, peer);

        bytes memory message = abi.encode(Constants.ETH_ADDRESS, amountIn, amountOut);

        DummyTokenUpgradeable(tokenA).grantRole(keccak256("MINTER_ROLE"), address(l1SyncPool));

        l1SyncPool.setDummyToken(LINEA.originEid, tokenA);

        l1Vault.grantRole(keccak256("SYNC_POOL_ROLE"), address(l1SyncPool));

        l1Vault.addDummyETH(address(tokenA));

        uint256 lockBoxBalance = IERC20(tokenOut).balanceOf(lockBox);

        uint256 actualAmountOut = l1Vault.previewDeposit(amountIn);

        vm.expectEmit(true, true, true, true);
        emit InsufficientDeposit(LINEA.originEid, 0, actualAmountOut, amountOut, amountOut - actualAmountOut);

        vm.prank(address(endpoint));
        l1SyncPool.lzReceive(Origin(LINEA.originEid, peer, 0), 0, message, address(0), "");

        assertGt(l1SyncPool.getTotalUnbackedTokens(), 0, "test_LzReceiveCase2::1");
        assertEq(l1SyncPool.getTotalUnbackedTokens(), amountOut - actualAmountOut, "test_LzReceiveCase2::2");
        assertEq(IERC20(tokenOut).balanceOf(lockBox), lockBoxBalance + actualAmountOut, "test_LzReceiveCase2::3");
        assertEq(IERC20(tokenOut).balanceOf(address(l1SyncPool)), 0, "test_LzReceiveCase2::4");

        uint256 amountIn2 = 1.05e18;
        uint256 amountOut2 = 1e18;
        uint256 actualAmountOut2 = l1Vault.previewDeposit(amountIn2);

        message = abi.encode(Constants.ETH_ADDRESS, amountIn2, amountOut2);

        vm.expectEmit(true, true, true, true);
        emit Fee(LINEA.originEid, 0, actualAmountOut2, amountOut2, actualAmountOut2 - amountOut2);

        vm.prank(address(endpoint));
        l1SyncPool.lzReceive(Origin(LINEA.originEid, peer, 0), 0, message, address(0), "");

        assertGt(l1SyncPool.getTotalUnbackedTokens(), 0, "test_LzReceiveCase2::5");
        assertEq(
            l1SyncPool.getTotalUnbackedTokens(),
            amountOut + amountOut2 - actualAmountOut - actualAmountOut2,
            "test_LzReceiveCase2::6"
        );
        assertEq(
            IERC20(tokenOut).balanceOf(lockBox),
            lockBoxBalance + actualAmountOut + actualAmountOut2,
            "test_LzReceiveCase2::7"
        );
        assertEq(IERC20(tokenOut).balanceOf(address(l1SyncPool)), 0, "test_LzReceiveCase2::8");

        uint256 amountIn3 = 10e18;
        uint256 amountOut3 = 1e18;
        uint256 actualAmountOut3 = l1Vault.previewDeposit(amountIn3);

        message = abi.encode(Constants.ETH_ADDRESS, amountIn3, amountOut3);

        vm.expectEmit(true, true, true, true);
        emit Fee(LINEA.originEid, 0, actualAmountOut3, amountOut3, actualAmountOut3 - amountOut3);

        vm.prank(address(endpoint));
        l1SyncPool.lzReceive(Origin(LINEA.originEid, peer, 0), 0, message, address(0), "");

        assertEq(l1SyncPool.getTotalUnbackedTokens(), 0, "test_LzReceiveCase2::9");
        assertEq(
            IERC20(tokenOut).balanceOf(lockBox),
            lockBoxBalance + amountOut + amountOut2 + amountOut3,
            "test_LzReceiveCase2::10"
        );
        assertEq(
            IERC20(tokenOut).balanceOf(address(l1SyncPool)),
            actualAmountOut + actualAmountOut2 + actualAmountOut3 - (amountOut + amountOut2 + amountOut3),
            "test_LzReceiveCase2::11"
        );
    }

    function test_OnMessageReceived() public {
        vm.expectRevert(L1BaseSyncPoolUpgradeable.L1BaseSyncPool__UnauthorizedCaller.selector);
        l1SyncPool.onMessageReceived(0, 0, address(0), 0, 0);

        address receiver = makeAddr("receiver");

        l1SyncPool.setReceiver(MODE.originEid, receiver);

        vm.prank(receiver);
        vm.expectRevert(L1SyncPoolETH.L1SyncPoolETH__OnlyETH.selector);
        l1SyncPool.onMessageReceived(MODE.originEid, 0, tokenA, 0, 0);

        vm.prank(receiver);
        vm.expectRevert(L1SyncPoolETH.L1SyncPoolETH__InvalidAmountIn.selector);
        l1SyncPool.onMessageReceived(MODE.originEid, 0, Constants.ETH_ADDRESS, 1e18, 1e18);

        vm.deal(receiver, 100e18);

        vm.prank(receiver);
        vm.expectRevert(L1SyncPoolETH.L1SyncPoolETH__UnsetDummyToken.selector);
        l1SyncPool.onMessageReceived{value: 1e18}(MODE.originEid, 0, Constants.ETH_ADDRESS, 1e18, 0);

        DummyTokenUpgradeable(tokenA).grantRole(keccak256("MINTER_ROLE"), address(l1SyncPool));
        l1SyncPool.setDummyToken(MODE.originEid, tokenA);

        vm.prank(receiver);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(l1SyncPool),
                keccak256("SYNC_POOL_ROLE")
            )
        );
        l1SyncPool.onMessageReceived{value: 1e18}(MODE.originEid, 0, Constants.ETH_ADDRESS, 1e18, 0);

        l1Vault.grantRole(keccak256("SYNC_POOL_ROLE"), address(l1SyncPool));

        vm.prank(receiver);
        vm.expectRevert("L1Vault: dummy token not set");
        l1SyncPool.onMessageReceived{value: 1e18}(MODE.originEid, 0, Constants.ETH_ADDRESS, 1e18, 0);

        l1Vault.addDummyETH(address(tokenA));

        bytes memory message = abi.encode(Constants.ETH_ADDRESS, 1e18, 0.9e18);
        bytes32 peer = bytes32(uint256(uint160(makeAddr("peer"))));

        l1SyncPool.setPeer(MODE.originEid, peer);

        uint256 lockBoxBalance = IERC20(tokenOut).balanceOf(lockBox);
        uint256 VaultETHBalance = address(address(l1Vault)).balance;

        vm.prank(address(endpoint));
        l1SyncPool.lzReceive(Origin(MODE.originEid, peer, 0), 0, message, address(0), "");

        uint256 actualAmountOut = l1Vault.previewDeposit(1e18);

        assertEq(IERC20(tokenOut).balanceOf(lockBox), lockBoxBalance + 0.9e18, "test_OnMessageReceived::1");
        assertEq(IERC20(tokenOut).balanceOf(address(l1SyncPool)), actualAmountOut - 0.9e18, "test_OnMessageReceived::2");
        assertEq(IERC20(tokenA).balanceOf(address(address(l1Vault))), 1e18, "test_OnMessageReceived::3");
        assertEq(address(address(l1Vault)).balance, VaultETHBalance, "test_OnMessageReceived::4");

        vm.prank(receiver);
        l1SyncPool.onMessageReceived{value: 1e18}(MODE.originEid, 0, Constants.ETH_ADDRESS, 1e18, 0);

        assertEq(IERC20(tokenOut).balanceOf(lockBox), lockBoxBalance + 0.9e18, "test_OnMessageReceived::5");
        assertEq(IERC20(tokenOut).balanceOf(address(l1SyncPool)), actualAmountOut - 0.9e18, "test_OnMessageReceived::6");
        assertEq(IERC20(tokenA).balanceOf(address(address(l1Vault))), 0, "test_OnMessageReceived::7");
        assertEq(address(address(l1Vault)).balance, VaultETHBalance + 1e18, "test_OnMessageReceived::8");
    }
}
