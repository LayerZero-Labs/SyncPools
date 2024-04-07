// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// @dev careful here, older OZ version doesn't deploy the ProxyAdmin contract by default and the send would be
// the direct owner of the proxy contract (he won't be able to call any function of the implementation contract)
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "forge-std/Script.sol";

import "../../contracts/examples/L1/L1SyncPoolETH.sol";
import "../../contracts/examples/L1/receivers/L1LineaReceiverETH.sol";
import "../../contracts/examples/L1/receivers/L1ModeReceiverETH.sol";
import "../../contracts/tokens/DummyTokenUpgradeable.sol";

struct Proxy {
    address admin;
    address implementation;
    address proxy;
}

struct L1Contracts {
    Proxy syncPool;
    Receiver[] receivers;
}

struct Receiver {
    string chainName; // The L2 chain name
    uint32 eid; // The L2 Endpoint ID
    Proxy receiver;
    Proxy dummyEth;
}

struct ChainParameters {
    string name; // The L2 chain name
    uint32 eid; // The L2 Endpoint ID
    address messenger; // The L1 Messenger address
    uint8 ethDecimals; // The number of decimals of the ETH token on the L2 chain
}

contract L1Deploy is Script {
    string rpcUrl = "https://eth-mainnet.alchemyapi.io/v2/pwc5rmJhrdoaSEfimoKEmsvOjKSmPDrP";

    address proxyAdmin = 0x1234567890123456789012345678901234567890;
    address endpoint = 0x1a44076050125825900e736c501f859c50fE728c;
    address vault = 0x1234567890123456789012345678901234567890;
    address tokenOut = 0x1234567890123456789012345678901234567890;
    address lockBox = 0x1234567890123456789012345678901234567890;
    address owner = 0x1234567890123456789012345678901234567890;

    ChainParameters LINEA = ChainParameters("Linea", 30183, 0xd19d4B5d358258f05D7B411E21A1460D11B0876F, 18);

    ChainParameters MODE = ChainParameters("Mode", 30260, 0x95bDCA6c8EdEB69C98Bd5bd17660BaCef1298A6f, 18);

    L1Contracts l1;

    function run() public returns (L1Contracts memory) {
        vm.createSelectFork(rpcUrl);

        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(pk);

        vm.startBroadcast(pk);
        // Deploy L1 SyncPool
        {
            l1.syncPool.implementation = address(new L1SyncPoolETH(endpoint));

            // Initialize the implementation for best practices
            L1SyncPoolETH(l1.syncPool.implementation).initialize(address(0), address(0), address(0), address(0));

            l1.syncPool.proxy = address(
                new TransparentUpgradeableProxy(
                    l1.syncPool.implementation,
                    proxyAdmin,
                    abi.encodeWithSelector(L1SyncPoolETH.initialize.selector, vault, tokenOut, lockBox, deployer)
                )
            );
        }

        // Deploy Linea Receiver and its dependencies
        Receiver storage linea = l1.receivers.push();
        {
            linea.chainName = LINEA.name;
            linea.eid = LINEA.eid;
            linea.receiver.implementation = address(new L1LineaReceiverETH());

            // Initialize the implementation for best practices
            L1LineaReceiverETH(linea.receiver.implementation).initialize(address(0), address(0), address(0));

            linea.receiver.proxy = address(
                new TransparentUpgradeableProxy(
                    linea.receiver.implementation,
                    proxyAdmin,
                    abi.encodeWithSelector(
                        L1LineaReceiverETHUpgradeable.initialize.selector, l1.syncPool.proxy, LINEA.messenger, owner
                    )
                )
            );

            // Deploy linea dummy ETH token
            linea.dummyEth.implementation = address(new DummyTokenUpgradeable(LINEA.ethDecimals));

            // Initialize the implementation for best practices
            DummyTokenUpgradeable(linea.dummyEth.implementation).initialize("", "", address(0));

            linea.dummyEth.proxy = address(
                new TransparentUpgradeableProxy(
                    linea.dummyEth.implementation,
                    proxyAdmin,
                    abi.encodeWithSelector(
                        DummyTokenUpgradeable.initialize.selector, "Linea Dummy ETH", "lineaETH", deployer
                    )
                )
            );
        }

        // Deploy Mode Receiver and its dependencies
        Receiver storage mode = l1.receivers.push();
        {
            mode.chainName = MODE.name;
            mode.eid = MODE.eid;
            mode.receiver.implementation = address(new L1ModeReceiverETH());

            // Initialize the implementation for best practices
            L1ModeReceiverETH(mode.receiver.implementation).initialize(address(0), address(0), address(0));

            mode.receiver.proxy = address(
                new TransparentUpgradeableProxy(
                    mode.receiver.implementation,
                    proxyAdmin,
                    abi.encodeWithSelector(
                        L1ModeReceiverETHUpgradeable.initialize.selector, l1.syncPool.proxy, MODE.messenger, owner
                    )
                )
            );

            // Deploy mode dummy ETH token
            mode.dummyEth.implementation = address(new DummyTokenUpgradeable(MODE.ethDecimals));

            // Initialize the implementation for best practices
            DummyTokenUpgradeable(mode.dummyEth.implementation).initialize("", "", address(0));

            mode.dummyEth.proxy = address(
                new TransparentUpgradeableProxy(
                    mode.dummyEth.implementation,
                    proxyAdmin,
                    abi.encodeWithSelector(
                        DummyTokenUpgradeable.initialize.selector, "Mode Dummy ETH", "modeETH", deployer
                    )
                )
            );
        }
        vm.stopBroadcast();

        // Update the admin of the contracts
        l1.syncPool.admin = _getAdmin(l1.syncPool.proxy);
        linea.receiver.admin = _getAdmin(linea.receiver.proxy);
        linea.dummyEth.admin = _getAdmin(linea.dummyEth.proxy);
        mode.receiver.admin = _getAdmin(mode.receiver.proxy);
        mode.dummyEth.admin = _getAdmin(mode.dummyEth.proxy);

        L1Contracts memory l1Contracts = l1;

        vm.startBroadcast(pk);
        // Grant the minter role to the sync pool and set the dummy token and receiver for each chain
        {
            for (uint256 i = 0; i < l1Contracts.receivers.length; i++) {
                Receiver memory receiver = l1Contracts.receivers[i];

                DummyTokenUpgradeable(receiver.dummyEth.proxy).grantRole(
                    keccak256("MINTER_ROLE"), l1Contracts.syncPool.proxy
                );
                L1SyncPoolETH(l1Contracts.syncPool.proxy).setDummyToken(receiver.eid, receiver.dummyEth.proxy);
                L1SyncPoolETH(l1Contracts.syncPool.proxy).setReceiver(receiver.eid, receiver.receiver.proxy);
            }
        }

        // Transfer the ownership to the owner if it is not the deployer
        if (owner != deployer) {
            L1SyncPoolETH(l1Contracts.syncPool.proxy).transferOwnership(owner);
            L1SyncPoolETH(l1Contracts.syncPool.proxy).setDelegate(owner);

            for (uint256 i = 0; i < l1Contracts.receivers.length; i++) {
                Receiver memory receiver = l1Contracts.receivers[i];

                DummyTokenUpgradeable(receiver.dummyEth.proxy).grantRole(bytes32(0), owner);
                DummyTokenUpgradeable(receiver.dummyEth.proxy).renounceRole(bytes32(0), deployer);
            }
        }
        vm.stopBroadcast();

        return l1;
    }

    function _getAdmin(address proxy) internal view returns (address) {
        bytes32 admin = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return _toAddress(admin);
    }

    function _toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function _toAddress(bytes32 b) internal pure returns (address) {
        require(uint256(b) < type(uint160).max, "invalid address");
        return address(uint160(uint256(b)));
    }
}
