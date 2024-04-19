// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../TestHelper.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20Errors} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../../contracts/tokens/DummyTokenUpgradeable.sol";

contract DummyTokenUpgradeableTest is TestHelper {
    DummyTokenUpgradeable public token;

    function setUp() public override {
        super.setUp();

        token = DummyTokenUpgradeable(
            _deployProxy(
                type(DummyTokenUpgradeable).creationCode,
                abi.encode(6),
                abi.encodeCall(DummyTokenUpgradeable.initialize, ("DummyToken", "DT", address(this)))
            )
        );
    }

    function test_Reinitialize() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        token.initialize("DummyToken", "DT", address(this));
    }

    function test_GetTokenInfo() public view {
        assertEq(token.name(), "DummyToken", "test_GetTokenInfo::1");
        assertEq(token.symbol(), "DT", "test_GetTokenInfo::2");
        assertEq(token.decimals(), 6, "test_GetTokenInfo::3");
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

    function test_Burn() public {
        token.grantRole(keccak256("MINTER_ROLE"), address(this));
        token.mint(address(this), 100);

        token.burn(50);

        assertEq(token.balanceOf(address(this)), 50, "test_Burn::1");

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), 50, 51));
        token.burn(51);

        token.burn(50);

        assertEq(token.balanceOf(address(this)), 0, "test_Burn::2");
    }
}
