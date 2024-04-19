// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../TestHelper.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20Errors} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../../contracts/tokens/MintableOFTUpgradeable.sol";

contract MintableOFTUpgradeableTest is TestHelper {
    MintableOFTUpgradeable public token;

    function setUp() public override {
        super.setUp();

        vm.createSelectFork(ETHEREUM.rpcUrl, ETHEREUM.forkBlockNumber);

        token = MintableOFTUpgradeable(
            _deployProxy(
                type(MintableOFTUpgradeable).creationCode,
                abi.encode(ETHEREUM.endpoint),
                abi.encodeCall(MintableOFTUpgradeable.initialize, ("MintableOFT", "OFT", address(this)))
            )
        );
    }

    function test_Reinitialize() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        token.initialize("MintableOFT", "OFT", address(this));
    }

    function test_GetTokenInfo() public view {
        assertEq(token.name(), "MintableOFT", "test_GetTokenInfo::1");
        assertEq(token.symbol(), "OFT", "test_GetTokenInfo::2");
    }

    function test_Mint() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), keccak256("MINTER_ROLE")
            )
        );
        token.mint(address(this), 100);

        token.grantRole(keccak256("MINTER_ROLE"), address(this));

        token.mint(address(this), 100);

        assertEq(token.balanceOf(address(this)), 100, "test_Mint::1");
    }
}
