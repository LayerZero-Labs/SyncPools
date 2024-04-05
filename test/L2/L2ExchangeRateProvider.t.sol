// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../TestHelper.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

import "../../contracts/examples/L2/L2ExchangeRateProvider.sol";
import "../utils/MockOracle.sol";

contract ExchangeRateProviderTest is TestHelper {
    MockOracle rateOracle;
    L2ExchangeRateProvider public provider;

    address tokenA = makeAddr("tokenA");
    address tokenB = makeAddr("tokenB");

    event RateParametersSet(address token, address rateOracle, uint64 depositFee, uint32 freshPeriod);

    function setUp() public override {
        super.setUp();

        rateOracle = new MockOracle();

        provider = L2ExchangeRateProvider(
            _deployProxy(
                type(L2ExchangeRateProvider).creationCode,
                new bytes(0),
                abi.encodeWithSelector(L2ExchangeRateProvider.initialize.selector, address(this))
            )
        );
    }

    function test_Reinitialize() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        provider.initialize(address(this));
    }

    function test_RateParameters() public {
        L2ExchangeRateProviderUpgradeable.RateParameters memory parameters = provider.getRateParameters(tokenA);

        assertEq(address(parameters.rateOracle), address(0), "test_RateParameters::1");
        assertEq(parameters.depositFee, 0, "test_RateParameters::2");
        assertEq(parameters.freshPeriod, 0, "test_RateParameters::3");

        vm.expectEmit(true, true, true, true);
        emit RateParametersSet(tokenA, address(rateOracle), 100, 100);
        provider.setRateParameters(tokenA, address(rateOracle), 100, 100);

        parameters = provider.getRateParameters(tokenA);

        assertEq(address(parameters.rateOracle), address(rateOracle), "test_RateParameters::4");
        assertEq(parameters.depositFee, 100, "test_RateParameters::5");
        assertEq(parameters.freshPeriod, 100, "test_RateParameters::6");

        vm.expectEmit(true, true, true, true);
        emit RateParametersSet(tokenA, address(0), 0, 0);
        provider.setRateParameters(tokenA, address(0), 0, 0);

        parameters = provider.getRateParameters(tokenA);

        assertEq(address(parameters.rateOracle), address(0), "test_RateParameters::7");
        assertEq(parameters.depositFee, 0, "test_RateParameters::8");
        assertEq(parameters.freshPeriod, 0, "test_RateParameters::9");

        vm.expectRevert(L2ExchangeRateProviderUpgradeable.L2ExchangeRateProvider__DepositFeeExceedsMax.selector);
        provider.setRateParameters(tokenA, address(rateOracle), 1e18 + 1, 100);
    }

    function test_GetConversionAmount() public {
        vm.expectRevert(L2ExchangeRateProviderUpgradeable.L2ExchangeRateProvider__NoRateOracle.selector);
        provider.getConversionAmount(tokenA, 1e18);

        provider.setRateParameters(tokenA, address(rateOracle), 0, 100);

        vm.expectRevert(L2ExchangeRateProvider.L2ExchangeRateProvider__InvalidRate.selector);
        provider.getConversionAmount(tokenA, 1e18);

        rateOracle.setPrice(-1);

        vm.expectRevert(L2ExchangeRateProvider.L2ExchangeRateProvider__InvalidRate.selector);
        provider.getConversionAmount(tokenA, 1e18);

        rateOracle.setPrice(1e18);

        assertEq(provider.getConversionAmount(tokenA, 1e18), 1e18, "test_GetConversionAmount::1");

        rateOracle.setPrice(2e18);

        assertEq(provider.getConversionAmount(tokenA, 1e18), 5e17, "test_GetConversionAmount::2");

        vm.expectRevert(L2ExchangeRateProviderUpgradeable.L2ExchangeRateProvider__NoRateOracle.selector);
        provider.getConversionAmount(tokenB, 1e18);

        vm.warp(block.timestamp + 100);

        provider.getConversionAmount(tokenA, 1e18);

        vm.warp(block.timestamp + 1);

        vm.expectRevert(L2ExchangeRateProviderUpgradeable.L2ExchangeRateProvider__OutdatedRate.selector);
        provider.getConversionAmount(tokenA, 1e18);

        rateOracle.setPrice(2e18);

        assertEq(provider.getConversionAmount(tokenA, 1e18), 0.5e18, "test_GetConversionAmount::3");

        provider.setRateParameters(tokenA, address(rateOracle), 0.5e18, 0);

        assertEq(provider.getConversionAmount(tokenA, 1e18), 0.25e18, "test_GetConversionAmount::4");
    }
}
