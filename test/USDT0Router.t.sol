// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {USDT0Router} from "../src/USDT0Router.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockUSDT0OFT} from "../src/mocks/MockUSDT0OFT.sol";
import {MockYieldStrategy} from "../src/mocks/MockYieldStrategy.sol";

contract USDT0RouterTest is Test {
    USDT0Router public router;
    MockERC20 public usdt0;
    MockUSDT0OFT public oft;
    MockYieldStrategy public strategyA;
    MockYieldStrategy public strategyB;

    address public owner = makeAddr("owner");
    address public rebalancer = makeAddr("rebalancer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant INITIAL_BALANCE = 100_000 * 1e6; // 100k USDT0

    function setUp() public {
        usdt0 = new MockERC20("USDT0", "USDT0", 6);
        oft = new MockUSDT0OFT(address(usdt0));

        vm.startPrank(owner);
        router = new USDT0Router(
            IERC20(address(usdt0)),
            address(oft),
            owner,
            rebalancer,
            75 // 75 bps threshold
        );

        // Create strategies
        strategyA = new MockYieldStrategy(address(usdt0), "Strategy A", 500); // 5% APY
        strategyB = new MockYieldStrategy(address(usdt0), "Strategy B", 800); // 8% APY

        // Register strategies
        router.registerStrategy(address(strategyA));
        router.registerStrategy(address(strategyB));
        vm.stopPrank();

        // Fund users
        usdt0.mint(alice, INITIAL_BALANCE);
        usdt0.mint(bob, INITIAL_BALANCE);

        // Approve router
        vm.prank(alice);
        usdt0.approve(address(router), type(uint256).max);
        vm.prank(bob);
        usdt0.approve(address(router), type(uint256).max);
    }

    // ─── Deposit Tests ──────────────────────────────────────────────────

    function test_deposit_mintsShares() public {
        vm.prank(alice);
        uint256 shares = router.deposit(1000 * 1e6, alice);

        assertGt(shares, 0, "should mint shares");
        assertEq(router.balanceOf(alice), shares, "alice should hold shares");
    }

    function test_deposit_firstDepositor_getsOneToOne() public {
        vm.prank(alice);
        uint256 shares = router.deposit(1000 * 1e6, alice);

        // First depositor: 1:1 ratio
        assertEq(shares, 1000 * 1e6, "first deposit should be 1:1");
    }

    function test_deposit_deploysToStrategy() public {
        vm.prank(alice);
        router.deposit(10_000 * 1e6, alice);

        // Some funds should be deployed (95% = total - 5% idle buffer)
        uint256 routerBalance = usdt0.balanceOf(address(router));
        assertLt(routerBalance, 10_000 * 1e6, "should deploy funds to strategy");
    }

    function test_deposit_multipleUsers() public {
        vm.prank(alice);
        router.deposit(5000 * 1e6, alice);

        vm.prank(bob);
        router.deposit(5000 * 1e6, bob);

        assertEq(router.balanceOf(alice), router.balanceOf(bob), "equal deposits = equal shares");
    }

    // ─── Withdraw Tests ─────────────────────────────────────────────────

    function test_withdraw_returnsUSDT0() public {
        vm.prank(alice);
        router.deposit(5000 * 1e6, alice);

        uint256 shares = router.balanceOf(alice);

        vm.prank(alice);
        uint256 assets = router.redeem(shares, alice, alice);

        assertGt(assets, 0, "should return assets");
        assertEq(router.balanceOf(alice), 0, "should burn all shares");
    }

    function test_withdraw_partialWithdraw() public {
        vm.prank(alice);
        router.deposit(10_000 * 1e6, alice);

        uint256 shares = router.balanceOf(alice);
        uint256 halfShares = shares / 2;

        vm.prank(alice);
        router.redeem(halfShares, alice, alice);

        assertApproxEqAbs(router.balanceOf(alice), halfShares, 1, "should have half shares left");
    }

    // ─── Strategy Management Tests ──────────────────────────────────────

    function test_registerStrategy() public {
        assertEq(router.getStrategyCount(), 2, "should have 2 strategies");
    }

    function test_registerStrategy_onlyOwner() public {
        MockYieldStrategy strategyC = new MockYieldStrategy(address(usdt0), "C", 100);

        vm.prank(alice);
        vm.expectRevert();
        router.registerStrategy(address(strategyC));
    }

    function test_removeStrategy_withdrawsFunds() public {
        // Deposit so funds go to strategy
        vm.prank(alice);
        router.deposit(10_000 * 1e6, alice);

        vm.prank(owner);
        router.removeStrategy(0);

        // Strategy should have 0 deposited after removal
        assertEq(strategyA.totalDeposited(), 0, "strategy should be empty");
    }

    function test_getBestStrategy_returnsHighestAPY() public {
        (uint256 bestId, uint256 bestApy) = router.getBestStrategy();

        // Strategy B has 800 bps (8%), Strategy A has 500 bps (5%)
        assertEq(bestId, 1, "strategy B should be best");
        assertEq(bestApy, 800, "best APY should be 800 bps");
    }

    // ─── Rebalance Tests ────────────────────────────────────────────────

    function test_rebalance_onlyRebalancer() public {
        vm.prank(alice);
        vm.expectRevert("not rebalancer");
        router.rebalance();
    }

    function test_rebalance_migratesToBetterStrategy() public {
        // Deposit to strategy A
        vm.prank(alice);
        router.deposit(10_000 * 1e6, alice);

        // Change APYs: A now better than B
        strategyA.setAPY(1200); // 12%
        strategyB.setAPY(300);  // 3%

        // Wait for cooldown
        vm.warp(block.timestamp + 61);

        vm.prank(rebalancer);
        router.rebalance();

        // Active strategy should now be A
        assertEq(router.activeStrategyId(), 0, "should migrate to strategy A");
    }

    function test_rebalance_respectsCooldown() public {
        vm.warp(100);

        vm.prank(rebalancer);
        router.rebalance();

        vm.prank(rebalancer);
        vm.expectRevert("rebalance cooldown");
        router.rebalance();
    }

    // ─── Total Assets Tests ─────────────────────────────────────────────

    function test_totalAssets_includesIdleAndDeployed() public {
        vm.prank(alice);
        router.deposit(10_000 * 1e6, alice);

        uint256 total = router.totalAssets();
        assertEq(total, 10_000 * 1e6, "total assets should equal deposit");
    }

    // ─── Admin Tests ────────────────────────────────────────────────────

    function test_setRebalancer() public {
        vm.prank(owner);
        router.setRebalancer(alice);

        vm.warp(100);

        // Alice should now be able to rebalance
        vm.prank(alice);
        router.rebalance();
    }

    function test_setIdleBuffer() public {
        vm.prank(owner);
        router.setIdleBufferBps(1000); // 10%

        assertEq(router.idleBufferBps(), 1000);
    }

    function test_setIdleBuffer_maxCap() public {
        vm.prank(owner);
        vm.expectRevert("max 50%");
        router.setIdleBufferBps(6000);
    }

    function test_quoteUsdt0Bridge_returnsFee() public {
        (uint256 nativeFee, uint256 lzTokenFee) = router.quoteUsdt0Bridge(
            30110,
            bytes32(uint256(uint160(alice))),
            1_000 * 1e6,
            990 * 1e6,
            "",
            "",
            ""
        );

        assertGt(nativeFee, 0, "should quote native fee");
        assertEq(lzTokenFee, 0, "mock lz fee should stay zero");
    }

    function test_bridgeUsdt0_callsOfficialOft() public {
        vm.prank(alice);
        router.deposit(2_000 * 1e6, alice);

        (uint256 nativeFee,) = router.quoteUsdt0Bridge(
            30110,
            bytes32(uint256(uint160(bob))),
            1_000 * 1e6,
            995 * 1e6,
            "",
            "",
            ""
        );

        vm.deal(owner, nativeFee);
        vm.prank(owner);
        router.bridgeUsdt0{value: nativeFee}(
            30110,
            bytes32(uint256(uint160(bob))),
            1_000 * 1e6,
            995 * 1e6,
            "",
            "",
            ""
        );

        (
            uint32 dstEid,
            bytes32 recipient,
            uint256 amountLD,
            uint256 minAmountLD,
            bytes memory extraOptions,
            bytes memory composeMsg,
            bytes memory oftCmd
        ) = oft.lastSendParam();

        assertEq(oft.sendCount(), 1, "router should call oft");
        assertEq(dstEid, 30110, "wrong destination eid");
        assertEq(recipient, bytes32(uint256(uint160(bob))), "wrong recipient");
        assertEq(amountLD, 1_000 * 1e6, "wrong bridged amount");
        assertEq(minAmountLD, 995 * 1e6, "wrong min amount");
        assertEq(extraOptions.length, 0, "unexpected options");
        assertEq(composeMsg.length, 0, "unexpected compose msg");
        assertEq(oftCmd.length, 0, "unexpected oft cmd");
    }
}
