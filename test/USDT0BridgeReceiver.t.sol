// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {USDT0Router} from "../src/USDT0Router.sol";
import {USDT0BridgeReceiver} from "../src/USDT0BridgeReceiver.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockUSDT0OFT} from "../src/mocks/MockUSDT0OFT.sol";
import {MockYieldStrategy} from "../src/mocks/MockYieldStrategy.sol";

contract USDT0BridgeReceiverTest is Test {
    USDT0Router public router;
    USDT0BridgeReceiver public receiver;
    MockERC20 public usdt0;
    MockUSDT0OFT public oft;
    MockYieldStrategy public strategy;

    address public owner = makeAddr("owner");
    address public mesonRouter = makeAddr("meson");
    address public alice = makeAddr("alice");

    function setUp() public {
        usdt0 = new MockERC20("USDT0", "USDT0", 6);
        oft = new MockUSDT0OFT(address(usdt0));

        vm.startPrank(owner);
        router = new USDT0Router(
            IERC20(address(usdt0)),
            address(oft),
            owner,
            owner,
            75
        );

        strategy = new MockYieldStrategy(address(usdt0), "Test", 500);
        router.registerStrategy(address(strategy));

        receiver = new USDT0BridgeReceiver(
            address(usdt0),
            address(router),
            mesonRouter,
            owner
        );
        vm.stopPrank();

        // Fund alice for direct deposits
        usdt0.mint(alice, 100_000 * 1e6);
        vm.prank(alice);
        usdt0.approve(address(receiver), type(uint256).max);
    }

    function test_directDeposit() public {
        vm.prank(alice);
        uint256 shares = receiver.depositDirect(5000 * 1e6);

        assertGt(shares, 0, "should receive shares");
        assertEq(router.balanceOf(alice), shares, "alice should hold router shares");
    }

    function test_onReceive_fromMeson() public {
        // Simulate Meson bridge delivering USDT0 + calling onReceive
        usdt0.mint(address(receiver), 10_000 * 1e6);

        bytes memory data = abi.encode(alice, uint8(0)); // auto strategy

        vm.prank(mesonRouter);
        receiver.onReceive(10_000 * 1e6, data);

        assertGt(router.balanceOf(alice), 0, "alice should have shares from bridge");
    }

    function test_onReceive_onlyMeson() public {
        usdt0.mint(address(receiver), 1000 * 1e6);
        bytes memory data = abi.encode(alice, uint8(0));

        vm.prank(alice);
        vm.expectRevert("only meson router");
        receiver.onReceive(1000 * 1e6, data);
    }

    function test_onReceive_rejectsZeroRecipient() public {
        usdt0.mint(address(receiver), 1000 * 1e6);
        bytes memory data = abi.encode(address(0), uint8(0));

        vm.prank(mesonRouter);
        vm.expectRevert("zero recipient");
        receiver.onReceive(1000 * 1e6, data);
    }

    function test_rescueTokens() public {
        MockERC20 randomToken = new MockERC20("Random", "RND", 18);
        randomToken.mint(address(receiver), 1000 * 1e18);

        vm.prank(owner);
        receiver.rescueTokens(address(randomToken), 1000 * 1e18);

        assertEq(randomToken.balanceOf(owner), 1000 * 1e18, "owner should receive rescued tokens");
    }
}
