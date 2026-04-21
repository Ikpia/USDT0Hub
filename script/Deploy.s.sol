// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {USDT0Router} from "../src/USDT0Router.sol";
import {USDT0AxCNHPair} from "../src/USDT0AxCNHPair.sol";
import {USDT0BridgeReceiver} from "../src/USDT0BridgeReceiver.sol";
import {USDT0HubSponsorManager} from "../src/USDT0HubSponsorManager.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockPyth} from "../src/mocks/MockPyth.sol";
import {MockUSDT0OFT} from "../src/mocks/MockUSDT0OFT.sol";

/// @title Deploy - USDT0Hub deployment script for Conflux eSpace testnet
contract Deploy is Script {
    // Pyth price feed IDs
    bytes32 constant USDT_FEED_ID = 0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b;
    bytes32 constant USD_CNH_FEED_ID = 0xeef52e09c878ad41f6a81803e3640fe04dceea727de894edd4ea117e2e332e66;
    address constant USDT0_MAINNET = 0xaf37E8B6C9ED7f6318979f56Fc287d76c30847ff;
    address constant USDT0_OFT_MAINNET = 0xC57efa1c7113D98BdA6F9f249471704Ece5dd84A;

    function run() external {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        // ─── 1. Deploy mock tokens (testnet only) ───────────────────────
        MockERC20 usdt0 = new MockERC20("USDT0 (Test)", "USDT0", 6);
        MockERC20 axcnh = new MockERC20("AxCNH (Test)", "AxCNH", 18);
        MockUSDT0OFT oft = new MockUSDT0OFT(address(usdt0));
        console2.log("MockUSDT0:", address(usdt0));
        console2.log("MockAxCNH:", address(axcnh));
        console2.log("MockUSDT0OFT:", address(oft));

        // ─── 2. Deploy mock Pyth oracle ─────────────────────────────────
        MockPyth pyth = new MockPyth();
        // Set initial prices: USDT = $1.00, USD/CNH = 7.3
        pyth.setPrice(USDT_FEED_ID, 1_0000_0000, 100_0000, -8); // $1.00
        pyth.setPrice(USD_CNH_FEED_ID, 73000_0000, 50_0000, -8); // 7.3 CNH per USD
        console2.log("MockPyth:", address(pyth));

        // ─── 3. Deploy USDT0Router (ERC-4626 vault) ─────────────────────
        USDT0Router router = new USDT0Router(
            IERC20(address(usdt0)),
            address(oft),
            deployer,       // owner
            deployer,       // rebalancer (deployer for testnet)
            75              // 75 bps rebalance threshold
        );
        console2.log("USDT0Router:", address(router));

        // ─── 4. Deploy FX Pair ──────────────────────────────────────────
        USDT0AxCNHPair pair = new USDT0AxCNHPair(
            address(usdt0),
            address(axcnh),
            address(pyth),
            USDT_FEED_ID,
            USD_CNH_FEED_ID,
            deployer
        );
        console2.log("USDT0AxCNHPair:", address(pair));

        // ─── 5. Deploy Bridge Receiver ──────────────────────────────────
        USDT0BridgeReceiver receiver = new USDT0BridgeReceiver(
            address(usdt0),
            address(router),
            deployer,       // mock meson router for testnet
            deployer
        );
        console2.log("USDT0BridgeReceiver:", address(receiver));

        // ─── 6. Deploy Sponsor Manager ──────────────────────────────────
        USDT0HubSponsorManager sponsor = new USDT0HubSponsorManager(deployer);
        console2.log("USDT0HubSponsorManager:", address(sponsor));

        // ─── 7. Mint test tokens ────────────────────────────────────────
        usdt0.mint(deployer, 1_000_000 * 1e6);  // 1M USDT0
        axcnh.mint(deployer, 7_300_000 * 1e18);  // 7.3M AxCNH (~1M USD equiv)
        console2.log("Minted test tokens to deployer");

        vm.stopBroadcast();

        // ─── Print summary ──────────────────────────────────────────────
        console2.log("\n=== USDT0Hub Deployment Summary ===");
        console2.log("Network: Conflux eSpace Testnet (Chain ID 71)");
        console2.log("Deployer:", deployer);
        console2.log("Official Conflux USDT0 mainnet token:", USDT0_MAINNET);
        console2.log("Official Conflux USDT0 OFT mainnet:", USDT0_OFT_MAINNET);
    }
}
