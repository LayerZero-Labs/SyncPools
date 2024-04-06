// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IL1Vault {
    function depositDummyETH(address token, uint256 assets) external returns (uint256);

    function swapDummyETH(address token, uint256 assets) external payable returns (uint256);
}
