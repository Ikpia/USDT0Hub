// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";

import {USDT0AxCNHPair} from "../src/USDT0AxCNHPair.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockPyth} from "../src/mocks/MockPyth.sol";

contract USDT0AxCNHPairTest is Test {
    USDT0AxCNHPair public pair;
    MockERC20 public usdt0;
    MockERC20 public axcnh;
    MockPyth public pyth;

    bytes32 constant USDT_FEED = 0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b;
    bytes32 constant USD_CNH_FEED = 0xeef52e09c878ad41f6a81803e3640fe04dceea727de894edd4ea117e2e332e66;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        usdt0 = new MockERC20("USDT0", "USDT0", 6);
        axcnh = new MockERC20("AxCNH", "AxCNH", 18);
        pyth = new MockPyth();

        // Set prices: USDT = $1, USD/CNH = 7.3
        pyth.setPrice(USDT_FEED, 1_0000_0000, 100_0000, -8);
        pyth.setPrice(USD_CNH_FEED, 73000_0000, 50_0000, -8);

        pair = new USDT0AxCNHPair(
            address(usdt0),
            address(axcnh),
            address(pyth),
            USDT_FEED,
            USD_CNH_FEED,
            owner
        );

        // Fund users
        usdt0.mint(alice, 1_000_000 * 1e6);
        axcnh.mint(alice, 7_300_000 * 1e18);
        usdt0.mint(bob, 1_000_000 * 1e6);
        axcnh.mint(bob, 7_300_000 * 1e18);

        // Approve pair
        vm.startPrank(alice);
        usdt0.approve(address(pair), type(uint256).max);
        axcnh.approve(address(pair), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        usdt0.approve(address(pair), type(uint256).max);
        axcnh.approve(address(pair), type(uint256).max);
        vm.stopPrank();
    }

    // ─── Add Liquidity Tests ────────────────────────────────────────────

    function test_addLiquidity_firstDeposit() public {
        vm.prank(alice);
        uint256 lp = pair.addLiquidity(10_000 * 1e6, 73_000 * 1e18);

        assertGt(lp, 0, "should mint LP tokens");
        assertEq(pair.balanceOf(alice), lp, "alice should hold LP");
    }

    function test_addLiquidity_singleSided_usdt0Only() public {
        // First add dual-sided
        vm.prank(alice);
        pair.addLiquidity(10_000 * 1e6, 73_000 * 1e18);

        // Then single-sided USDT0
        vm.prank(bob);
        uint256 lp = pair.addLiquidity(5_000 * 1e6, 0);
        assertGt(lp, 0, "should mint LP for single-sided");
    }

    function test_addLiquidity_rejectsZeroAmounts() public {
        vm.prank(alice);
        vm.expectRevert("zero amounts");
        pair.addLiquidity(0, 0);
    }

    // ─── Remove Liquidity Tests ─────────────────────────────────────────

    function test_removeLiquidity_returnsTokens() public {
        vm.startPrank(alice);
        uint256 lp = pair.addLiquidity(10_000 * 1e6, 73_000 * 1e18);

        (uint256 usdt0Out, uint256 axcnhOut) = pair.removeLiquidity(lp);
        vm.stopPrank();

        assertGt(usdt0Out, 0, "should return USDT0");
        assertGt(axcnhOut, 0, "should return AxCNH");
        assertEq(pair.balanceOf(alice), 0, "should burn all LP");
    }

    function test_removeLiquidity_partial() public {
        vm.startPrank(alice);
        uint256 lp = pair.addLiquidity(10_000 * 1e6, 73_000 * 1e18);

        pair.removeLiquidity(lp / 2);
        vm.stopPrank();

        assertApproxEqAbs(pair.balanceOf(alice), lp / 2, 1, "should have half LP left");
    }

    // ─── Swap Tests ─────────────────────────────────────────────────────

    function test_swapUSDT0ForAxCNH() public {
        // Add liquidity first
        vm.prank(alice);
        pair.addLiquidity(100_000 * 1e6, 730_000 * 1e18);

        // Bob swaps USDT0 for AxCNH
        uint256 bobAxCNHBefore = axcnh.balanceOf(bob);

        vm.prank(bob);
        uint256 amountOut = pair.swapUSDT0ForAxCNH(1000 * 1e6, 0);

        assertGt(amountOut, 0, "should receive AxCNH");
        assertEq(axcnh.balanceOf(bob), bobAxCNHBefore + amountOut, "balance should increase");
    }

    function test_swapAxCNHForUSDT0() public {
        // Add liquidity
        vm.prank(alice);
        pair.addLiquidity(100_000 * 1e6, 730_000 * 1e18);

        // Bob swaps AxCNH for USDT0
        uint256 bobUSDT0Before = usdt0.balanceOf(bob);

        vm.prank(bob);
        uint256 amountOut = pair.swapAxCNHForUSDT0(7300 * 1e18, 0);

        assertGt(amountOut, 0, "should receive USDT0");
        assertEq(usdt0.balanceOf(bob), bobUSDT0Before + amountOut, "balance should increase");
    }

    function test_swap_slippageProtection() public {
        vm.prank(alice);
        pair.addLiquidity(100_000 * 1e6, 730_000 * 1e18);

        vm.prank(bob);
        vm.expectRevert("slippage exceeded");
        pair.swapUSDT0ForAxCNH(1000 * 1e6, type(uint256).max);
    }

    function test_swap_nearOneToOneForStablecoins() public {
        // Add balanced liquidity
        vm.prank(alice);
        pair.addLiquidity(100_000 * 1e6, 730_000 * 1e18);

        // Swap a small amount — should be close to 1:1 for same-value stablecoins
        vm.prank(bob);
        uint256 amountOut = pair.swapUSDT0ForAxCNH(100 * 1e6, 0);

        // Output should track the live FX rate: 100 USDT ~= 730 AxCNH.
        uint256 expected = 730 * 1e18;
        uint256 deviation = amountOut > expected ? amountOut - expected : expected - amountOut;
        assertLt(deviation, expected / 20, "should be within 5% of live FX");
    }

    // ─── Fee Tests ──────────────────────────────────────────────────────

    function test_swap_accumulatesFees() public {
        vm.prank(alice);
        pair.addLiquidity(100_000 * 1e6, 730_000 * 1e18);

        vm.prank(bob);
        pair.swapUSDT0ForAxCNH(10_000 * 1e6, 0);

        uint256 fee1 = pair.accumulatedFee1();
        assertGt(fee1, 0, "should accumulate AxCNH fees");
    }

    function test_collectFees() public {
        vm.prank(alice);
        pair.addLiquidity(100_000 * 1e6, 730_000 * 1e18);

        vm.prank(bob);
        pair.swapUSDT0ForAxCNH(10_000 * 1e6, 0);

        uint256 ownerAxCNHBefore = axcnh.balanceOf(owner);

        vm.prank(owner);
        pair.collectFees();

        assertGt(axcnh.balanceOf(owner), ownerAxCNHBefore, "owner should receive fees");
    }

    // ─── Quote Tests ────────────────────────────────────────────────────

    function test_quote_matchesActualSwap() public {
        vm.prank(alice);
        pair.addLiquidity(100_000 * 1e6, 730_000 * 1e18);

        uint256 quoted = pair.quoteUSDT0ForAxCNH(1000 * 1e6);

        vm.prank(bob);
        uint256 actual = pair.swapUSDT0ForAxCNH(1000 * 1e6, 0);

        // Quote should match actual (state is identical at time of quote)
        // Allow 1 wei tolerance for rounding
        assertApproxEqAbs(quoted, actual, 1, "quote should match actual swap");
    }

    // ─── Oracle Tests ───────────────────────────────────────────────────

    function test_getOracleRate() public view {
        uint256 rate = pair.getOracleRate();
        // USDT/USD ~= 1 and USD/CNH ~= 7.3, so the resulting FX rate is ~7.3.
        // rate should be ~7.3e18
        assertGt(rate, 6e18, "rate should be > 6 CNH/USD");
        assertLt(rate, 9e18, "rate should be < 9 CNH/USD");
    }
}
