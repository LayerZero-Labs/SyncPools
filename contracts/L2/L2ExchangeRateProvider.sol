// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IL2ExchangeRateProvider} from "../interfaces/IL2ExchangeRateProvider.sol";
import {Constants} from "../libraries/Constants.sol";

/**
 * @title Exchange Rate Provider
 * @dev Provides exchange rate for different tokens against a common quote token
 * The rates oracles are expected to all use the same quote token.
 * For example, if quote is ETH and token is worth 2 ETH, the rate should be 2e18.
 */
abstract contract L2ExchangeRateProvider is Ownable, IL2ExchangeRateProvider {
    error L2ExchangeRateProvider__DepositFeeExceedsMax();
    error L2ExchangeRateProvider__OutdatedRate();
    error L2ExchangeRateProvider__NoRateOracle();

    /**
     * @dev Rate parameters for a token
     * @param rateOracle Rate oracle contract, providing the exchange rate
     * @param depositFee Deposit fee, in 1e18 precision (e.g. 1e16 for 1% fee)
     * @param freshPeriod Fresh period, in seconds
     */
    struct RateParameters {
        address rateOracle;
        uint64 depositFee;
        uint32 freshPeriod;
    }

    event RateParametersSet(address token, address rateOracle, uint64 depositFee, uint32 freshPeriod);

    /**
     * @dev Mapping of token address to rate parameters
     * All rate oracles are expected to return rates with the `18 + decimalsIn - decimalsOut` decimals
     */
    mapping(address => RateParameters) private _rateParameters;

    /**
     * @dev Constructor
     * @param owner Owner address
     */
    constructor(address owner) Ownable(owner) {}

    /**
     * @dev Get rate parameters for a token
     * @param token Token address
     * @return parameters Rate parameters
     */
    function getRateParameters(address token) public view virtual returns (RateParameters memory parameters) {
        return _rateParameters[token];
    }

    /**
     * @dev Get conversion amount for a token, given an amount in of token it should return the amount out.
     * It also applies the deposit fee.
     * Will revert if:
     * - No rate oracle is set for the token
     * - The rate is outdated (fresh period has passed)
     * @param token Token address
     * @param amountIn Amount in
     * @return amountOut Amount out
     */
    function getConversionAmount(address token, uint256 amountIn)
        public
        view
        virtual
        override
        returns (uint256 amountOut)
    {
        RateParameters storage rateParameters = _rateParameters[token];

        address rateOracle = _rateParameters[token].rateOracle;

        if (rateOracle == address(0)) revert L2ExchangeRateProvider__NoRateOracle();

        (uint256 rate, uint256 lastUpdated) = _getRateAndLastUpdated(rateOracle, token);

        if (lastUpdated + rateParameters.freshPeriod < block.timestamp) revert L2ExchangeRateProvider__OutdatedRate();

        uint256 feeAmount = (amountIn * rateParameters.depositFee + Constants.PRECISION_SUB_ONE) / Constants.PRECISION;
        uint256 amountInAfterFee = amountIn - feeAmount;

        amountOut = amountInAfterFee * Constants.PRECISION / rate;

        return amountOut;
    }

    /**
     * @dev Set rate parameters for a token
     * @param token Token address
     * @param rateOracle Rate oracle contract, providing the exchange rate
     * @param depositFee Deposit fee, in 1e18 precision (e.g. 1e16 for 1% fee)
     * @param freshPeriod Fresh period, in seconds
     */
    function setRateParameters(address token, address rateOracle, uint64 depositFee, uint32 freshPeriod)
        public
        virtual
        onlyOwner
    {
        _setRateParameters(token, rateOracle, depositFee, freshPeriod);
    }

    /**
     * @dev Internal function to set rate parameters for a token
     * Will revert if:
     * - Deposit fee exceeds 100% (1e18)
     * @param token Token address
     * @param rateOracle Rate oracle contract, providing the exchange rate
     * @param depositFee Deposit fee, in 1e18 precision (e.g. 1e16 for 1% fee)
     * @param freshPeriod Fresh period, in seconds
     */
    function _setRateParameters(address token, address rateOracle, uint64 depositFee, uint32 freshPeriod)
        internal
        virtual
    {
        if (depositFee > Constants.PRECISION) revert L2ExchangeRateProvider__DepositFeeExceedsMax();

        _rateParameters[token] = RateParameters(rateOracle, depositFee, freshPeriod);

        emit RateParametersSet(token, rateOracle, depositFee, freshPeriod);
    }

    /**
     * @dev Internal function to get rate and last updated time from a rate oracle
     * @param rateOracle Rate oracle contract
     * @param token The token address which the rate is for
     * @return rate The exchange rate in 1e18 precision
     * @return lastUpdated Last updated time
     */
    function _getRateAndLastUpdated(address rateOracle, address token)
        internal
        view
        virtual
        returns (uint256 rate, uint256 lastUpdated);
}
