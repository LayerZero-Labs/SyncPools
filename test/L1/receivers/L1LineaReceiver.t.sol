// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.22;

import {IOAppCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";

import "../../TestHelper.sol";

import "../../utils/MockSyncPool.sol";
import "../../utils/MockLineaBridge.sol";
import "../../../contracts/examples/L1/receivers/L1LineaReceiverETH.sol";
import "../../../contracts/L1/L1BaseReceiverUpgradeable.sol";
import "../../../contracts/libraries/Constants.sol";

contract L1LineaReceiverETHTest is TestHelper {
    L1LineaReceiverETH public l1Receiver;
    MockSyncPool public syncPool;
    MockLineaBridge public messenger;

    event L1SyncPoolSet(address l1SyncPool);
    event MessengerSet(address messenger);

    function setUp() public override {
        super.setUp();

        syncPool = new MockSyncPool();
        messenger = new MockLineaBridge();

        l1Receiver = L1LineaReceiverETH(
            _deployProxy(
                type(L1LineaReceiverETH).creationCode,
                new bytes(0),
                abi.encodeCall(
                    L1LineaReceiverETHUpgradeable.initialize, (address(syncPool), address(messenger), address(this))
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

        vm.expectRevert(L1LineaReceiverETHUpgradeable.L1LineaReceiverETH__OnlyETH.selector);
        l1Receiver.onMessageReceived(
            abi.encode(ETHEREUM.originEid, bytes32(uint256(uint160(address(messenger)))), address(1), 2e18, 1e18)
        );

        bytes memory data = abi.encode(
            ETHEREUM.originEid, bytes32(uint256(uint160(address(messenger)))), Constants.ETH_ADDRESS, 2e18, 1e18
        );
        bytes memory message = abi.encodeCall(L1LineaReceiverETHUpgradeable.onMessageReceived, data);

        vm.expectRevert(L1BaseReceiverUpgradeable.L1BaseReceiver__UnauthorizedL2Sender.selector);
        messenger.claimMessage(address(this), address(l1Receiver), 0, 1e18, payable(address(0)), message, 0);

        messenger.claimMessage(
            address(uint160(uint256(peer))), address(l1Receiver), 0, 1e18, payable(address(0)), message, 0
        );

        assertEq(
            keccak256(syncPool.data()),
            keccak256(
                abi.encodeCall(
                    IL1SyncPool.onMessageReceived,
                    (
                        ETHEREUM.originEid,
                        bytes32(uint256(uint160(address(messenger)))),
                        Constants.ETH_ADDRESS,
                        uint256(2e18),
                        uint256(1e18)
                    )
                )
            ),
            "test_OnMessageReceived::1"
        );
        assertEq(syncPool.value(), 1e18, "test_OnMessageReceived::2");
    }
}
