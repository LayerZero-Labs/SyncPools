// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IOAppCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";

import "../../TestHelper.sol";

import "../../utils/MockSyncPool.sol";
import "../../utils/MockModeBridge.sol";
import "../../../contracts/examples/L1/receivers/L1ModeReceiverETH.sol";
import "../../../contracts/L1/L1BaseReceiverUpgradeable.sol";
import "../../../contracts/libraries/Constants.sol";

contract L1ModeReceiverETHTest is TestHelper {
    L1ModeReceiverETH public l1Receiver;
    MockSyncPool public syncPool;
    MockModeBridge public messenger;

    event L1SyncPoolSet(address l1SyncPool);
    event MessengerSet(address messenger);

    function setUp() public override {
        super.setUp();

        syncPool = new MockSyncPool();
        messenger = new MockModeBridge();

        l1Receiver = L1ModeReceiverETH(
            _deployProxy(
                type(L1ModeReceiverETH).creationCode,
                new bytes(0),
                abi.encodeWithSelector(
                    L1ModeReceiverETHUpgradeable.initialize.selector,
                    address(syncPool),
                    address(messenger),
                    address(this)
                )
            )
        );

        vm.deal(address(messenger), 100e18);
    }

    function test_L1SyncPool() public {
        assertEq(l1Receiver.getL1SyncPool(), address(syncPool), "test_L1SyncPool::1");

        vm.expectEmit(true, true, true, true);
        emit L1SyncPoolSet(address(0));
        l1Receiver.setL1SyncPool(address(0));

        assertEq(l1Receiver.getL1SyncPool(), address(0), "test_L1SyncPool::2");

        vm.expectEmit(true, true, true, true);
        emit L1SyncPoolSet(address(syncPool));
        l1Receiver.setL1SyncPool(address(syncPool));

        assertEq(l1Receiver.getL1SyncPool(), address(syncPool), "test_L1SyncPool::3");
    }

    function test_Messenger() public {
        assertEq(l1Receiver.getMessenger(), address(messenger), "test_Messenger::1");

        vm.expectEmit(true, true, true, true);
        emit MessengerSet(address(0));
        l1Receiver.setMessenger(address(0));

        assertEq(l1Receiver.getMessenger(), address(0), "test_Messenger::2");

        vm.expectEmit(true, true, true, true);
        emit MessengerSet(address(messenger));
        l1Receiver.setMessenger(address(messenger));

        assertEq(l1Receiver.getMessenger(), address(messenger), "test_Messenger::3");
    }

    function test_OnMessageReceived() public {
        bytes32 peer = bytes32(uint256(uint160(makeAddr("peer"))));
        syncPool.setPeer(peer);

        vm.expectRevert(L1BaseReceiverUpgradeable.L1BaseReceiver__UnauthorizedCaller.selector);
        l1Receiver.onMessageReceived(abi.encode(ETHEREUM.originEid, bytes32(0), Constants.ETH_ADDRESS, 2e18, 1e18));

        vm.expectRevert(L1ModeReceiverETHUpgradeable.L1ModeReceiverETH__OnlyETH.selector);
        l1Receiver.onMessageReceived(
            abi.encode(ETHEREUM.originEid, bytes32(uint256(uint160(address(messenger)))), address(1), 2e18, 1e18)
        );

        bytes memory data = abi.encode(
            ETHEREUM.originEid, bytes32(uint256(uint160(address(messenger)))), Constants.ETH_ADDRESS, 2e18, 1e18
        );
        bytes memory message = abi.encodeWithSelector(L1ModeReceiverETHUpgradeable.onMessageReceived.selector, data);

        vm.expectRevert(L1BaseReceiverUpgradeable.L1BaseReceiver__UnauthorizedL2Sender.selector);
        messenger.relayMessage(0, address(this), address(l1Receiver), 1e18, 0, message);

        messenger.relayMessage(0, address(uint160(uint256(peer))), address(l1Receiver), 1e18, 0, message);

        assertEq(
            keccak256(syncPool.data()),
            keccak256(
                abi.encodeWithSelector(
                    IL1SyncPool.onMessageReceived.selector,
                    ETHEREUM.originEid,
                    bytes32(uint256(uint160(address(messenger)))),
                    Constants.ETH_ADDRESS,
                    uint256(2e18),
                    uint256(1e18)
                )
            ),
            "test_OnMessageReceived::1"
        );
        assertEq(syncPool.value(), 1e18, "test_OnMessageReceived::2");
    }
}
