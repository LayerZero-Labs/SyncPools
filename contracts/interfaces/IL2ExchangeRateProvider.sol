// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IL2ExchangeRateProvider {
    function getConversionAmount(address tokenIn, uint256 amountIn) external returns (uint256 amountOut);
}
