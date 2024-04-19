// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "forge-std/Test.sol";
import "./utils/Addresses.sol";

contract TestHelper is Test, Addresses {
    address public proxyAdmin = makeAddr("proxyAdmin");

    function setUp() public virtual {}

    function _deployContract(bytes memory bytecode, bytes memory constructorArgs) internal returns (address addr) {
        bytecode = bytes.concat(abi.encodePacked(bytecode, constructorArgs));
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
            if iszero(extcodesize(addr)) { revert(0, 0) }
        }
    }

    function _deployImmutableProxy(bytes memory bytecode, bytes memory constructorArgs, bytes memory initializerArgs)
        internal
        returns (address addr)
    {
        addr = _deployContract(bytecode, constructorArgs);

        if (initializerArgs.length > 0) {
            (bool success,) = addr.call(initializerArgs);

            if (!success) {
                assembly {
                    if returndatasize() {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                }

                revert("initialize failed");
            }
        }
    }

    function _deployProxy(bytes memory bytecode, bytes memory constructorArgs, bytes memory initializerArgs)
        internal
        returns (address addr)
    {
        address implementation = _deployContract(bytecode, constructorArgs);

        vm.label(implementation, "implementation");

        return address(new TransparentUpgradeableProxy(implementation, proxyAdmin, initializerArgs));
    }
}
