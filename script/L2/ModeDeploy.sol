// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// @dev careful here, older OZ version doesn't deploy the ProxyAdmin contract by default and the send would be
// the direct owner of the proxy contract (he won't be able to call any function of the implementation contract)
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "forge-std/Script.sol";

import "../../contracts/examples/L2/syncpools/L2ModeSyncPoolETH.sol";
import "../../contracts/examples/L2/L2ExchangeRateProvider.sol";
import "../../contracts/libraries/Constants.sol";

struct Proxy {
    address admin;
    address implementation;
    address proxy;
}

struct L2Contracts {
    Proxy syncPool;
    Proxy exchangeRateProvider;
}

contract ModeDeploy is Script {
    L2Contracts l2;

    string rpcUrl = "https://mainnet.mode.network";

    address owner = 0x1234567890123456789012345678901234567890;
    address proxyAdmin = 0x1234567890123456789012345678901234567890;
    address endpoint = 0x1a44076050125825900e736c501f859c50fE728c;
    address rateLimiter = address(0);
    address oftToken = 0x1234567890123456789012345678901234567890;
    uint32 dstEid = 30101;
    address messenger = 0x4200000000000000000000000000000000000007; // The L2 Messenger address
    address l1receiver = 0x1234567890123456789012345678901234567890; // The L1 Mode Receiver address

    address tokenIn = Constants.ETH_ADDRESS;
    address l1TokenIn = Constants.ETH_ADDRESS;
    address tokenOut = 0x1234567890123456789012345678901234567890; // Most of the time it will be the oft itself
    address rateOracle = 0x1234567890123456789012345678901234567890;
    uint64 depositFee = 0;
    uint32 freshperiod = 0;
    uint256 minSyncAmount = 0;

    function run() public returns (L2Contracts memory) {
        vm.createSelectFork(rpcUrl);

        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(pk);

        vm.startBroadcast(pk);
        // Deploy l2 exchange rate provider
        {
            l2.exchangeRateProvider.implementation = address(new L2ExchangeRateProvider());

            // Initialize the implementation for best practices
            L2ExchangeRateProvider(l2.exchangeRateProvider.implementation).initialize(address(0));

            l2.exchangeRateProvider.proxy = address(
                new TransparentUpgradeableProxy(
                    l2.exchangeRateProvider.implementation,
                    proxyAdmin,
                    abi.encodeWithSelector(L2ExchangeRateProvider.initialize.selector, deployer)
                )
            );
        }

        // Deploy l2 sync pool
        {
            l2.syncPool.implementation = address(new L2ModeSyncPoolETH(endpoint));

            // Initialize the implementation for best practices
            L2ModeSyncPoolETH(l2.syncPool.implementation).initialize(
                address(0), address(0), address(0), 0, address(0), address(0), address(0)
            );

            l2.syncPool.proxy = address(
                new TransparentUpgradeableProxy(
                    l2.syncPool.implementation,
                    proxyAdmin,
                    abi.encodeWithSelector(
                        L2ModeSyncPoolETHUpgradeable.initialize.selector,
                        l2.exchangeRateProvider.proxy,
                        rateLimiter,
                        oftToken,
                        dstEid,
                        messenger,
                        l1receiver,
                        deployer
                    )
                )
            );
        }
        vm.stopBroadcast();

        // Update the admin of the contracts
        l2.exchangeRateProvider.admin = _getAdmin(l2.exchangeRateProvider.proxy);
        l2.syncPool.admin = _getAdmin(l2.syncPool.proxy);

        vm.startBroadcast(pk);
        // Set the rate parameters and token parameters
        {
            L2ExchangeRateProvider(l2.exchangeRateProvider.proxy).setRateParameters(
                tokenIn, rateOracle, depositFee, freshperiod
            );

            L2ModeSyncPoolETH(l2.syncPool.proxy).setMinSyncAmount(tokenIn, minSyncAmount);
            L2ModeSyncPoolETH(l2.syncPool.proxy).setL1TokenIn(tokenIn, l1TokenIn);
        }

        // Transfer the ownership to the owner if it is not the deployer
        if (owner != deployer) {
            L2ModeSyncPoolETH(l2.syncPool.proxy).transferOwnership(owner);
            L2ModeSyncPoolETH(l2.syncPool.proxy).setDelegate(owner);

            L2ExchangeRateProvider(l2.exchangeRateProvider.proxy).transferOwnership(owner);
        }
        vm.stopBroadcast();

        return l2;
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
