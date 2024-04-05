// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../contracts/interfaces/IRateLimiter.sol";

contract MockRateLimiter is IRateLimiter {
    bool public isRateLimited = false;

    bytes[] public deposits;

    function numberOfDeposits() external view returns (uint256) {
        return deposits.length;
    }

    function setRateLimited(bool _isRateLimited) external {
        isRateLimited = _isRateLimited;
    }

    function updateRateLimit(address sender, address tokenIn, uint256 amountIn, uint256 amountOut) external override {
        if (isRateLimited) revert("Rate limited");

        deposits.push(abi.encode(sender, tokenIn, amountIn, amountOut));
    }
}
