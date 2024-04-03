// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {IMintableERC20} from "../interfaces/IMintableERC20.sol";

/**
 * @title Mintable OFT
 * @dev An OFT token that can be minted by a minter.
 */
contract MintableOFT is OFT, AccessControl, IMintableERC20 {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @dev Constructor for MintableOFT
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param endpoint The layer zero endpoint address
     * @param owner The owner of the token
     */
    constructor(string memory name, string memory symbol, address endpoint, address owner)
        OFT(name, symbol, endpoint, owner)
        Ownable(owner)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
    }

    /**
     * @dev Mint function that can only be called by a minter
     * @param account The account to mint the tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address account, uint256 amount) external virtual override onlyRole(MINTER_ROLE) {
        _mint(account, amount);
    }
}
