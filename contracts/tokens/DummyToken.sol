// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {IDummyToken} from "../interfaces/IDummyToken.sol";

/**
 * @title Dummy Token
 * @dev ERC20 token with mint and burn functions.
 * This token is expected to be used as an accounting token for anticipated deposits.
 * For example, when a user deposit ETH on an L2, it needs ~7 days to be sent back to the L1,
 * using a faster bridge such as LayerZero allows to deposit a dummy ETH token on the L1
 * to keep track of the actual ETH amount deposited on the L1 and L2, without any delay.
 * The dummy token will then be exchanged against the actual ETH when the ETH withdrawal is completed.
 */
contract DummyToken is ERC20, AccessControl, IDummyToken {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint8 private immutable _decimals;

    /**
     * @dev Constructor for DummyToken
     * @param name_ The name of the token
     * @param symbol_ The symbol of the token
     * @param decimals_ The number of decimals the token uses
     */
    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Get the number of decimals the token uses
     * @return The number of decimals the token uses
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Mint function that can only be called by a minter
     * @param to The account to mint the tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external virtual override onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Burn function that can be called by anyone
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external virtual override {
        _burn(msg.sender, amount);
    }
}
