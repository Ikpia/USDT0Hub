import "dotenv/config";
import {
  createPublicClient,
  createWalletClient,
  http,
  defineChain,
  type Address,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";

// ─── Config ─────────────────────────────────────────────────────────────────

const ROUTER_ADDRESS = (process.env.USDT0_ROUTER_ADDRESS ?? "0x0") as Address;
const PRIVATE_KEY = process.env.PRIVATE_KEY ?? "";
const RPC_URL = process.env.CONFLUX_ESPACE_RPC ?? "https://evmtestnet.confluxrpc.com";
const POLL_INTERVAL = Number(process.env.REBALANCE_POLL_INTERVAL_SECONDS ?? 300) * 1000;
const THRESHOLD_BPS = Number(process.env.REBALANCE_THRESHOLD_BPS ?? 75);

const confluxESpace = defineChain({
  id: Number(process.env.CHAIN_ID ?? 71),
  name: "Conflux eSpace",
  nativeCurrency: { name: "CFX", symbol: "CFX", decimals: 18 },
  rpcUrls: { default: { http: [RPC_URL] } },
});

// ─── ABI Fragments ──────────────────────────────────────────────────────────

const ROUTER_ABI = [
  {
    inputs: [],
    name: "rebalance",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "getBestStrategy",
    outputs: [
      { name: "strategyId", type: "uint256" },
      { name: "apy", type: "uint256" },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "activeStrategyId",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "totalAssets",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "lastRebalanceTimestamp",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
] as const;

// ─── Clients ────────────────────────────────────────────────────────────────

const publicClient = createPublicClient({
  chain: confluxESpace,
  transport: http(RPC_URL),
});

const account = privateKeyToAccount(`0x${PRIVATE_KEY.replace("0x", "")}` as `0x${string}`);

const walletClient = createWalletClient({
  account,
  chain: confluxESpace,
  transport: http(RPC_URL),
});

// ─── Main Loop ──────────────────────────────────────────────────────────────

async function checkAndRebalance() {
  try {
    const [bestResult, activeId, totalAssets, lastRebalance] = await Promise.all([
      publicClient.readContract({
        address: ROUTER_ADDRESS,
        abi: ROUTER_ABI,
        functionName: "getBestStrategy",
      }),
      publicClient.readContract({
        address: ROUTER_ADDRESS,
        abi: ROUTER_ABI,
        functionName: "activeStrategyId",
      }),
      publicClient.readContract({
        address: ROUTER_ADDRESS,
        abi: ROUTER_ABI,
        functionName: "totalAssets",
      }),
      publicClient.readContract({
        address: ROUTER_ADDRESS,
        abi: ROUTER_ABI,
        functionName: "lastRebalanceTimestamp",
      }),
    ]);

    const [bestId, bestApy] = bestResult;
    const now = Math.floor(Date.now() / 1000);

    console.log(`[${new Date().toISOString()}] Status:`);
    console.log(`  Active Strategy: ${activeId}`);
    console.log(`  Best Strategy: ${bestId} (APY: ${Number(bestApy) / 100}%)`);
    console.log(`  Total Assets: ${totalAssets}`);
    console.log(`  Last Rebalance: ${lastRebalance} (${now - Number(lastRebalance)}s ago)`);

    // Check if rebalance is needed
    if (bestId !== activeId) {
      console.log(`  Strategy change detected! Triggering rebalance...`);

      const hash = await walletClient.writeContract({
        address: ROUTER_ADDRESS,
        abi: ROUTER_ABI,
        functionName: "rebalance",
      });

      console.log(`  Rebalance TX: ${hash}`);

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      console.log(`  Rebalance confirmed in block ${receipt.blockNumber}`);
    } else {
      console.log(`  No rebalance needed.`);
    }
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Error:`, error);
  }
}

// ─── Entry ──────────────────────────────────────────────────────────────────

console.log("USDT0Hub Rebalancer Service");
console.log(`  Router: ${ROUTER_ADDRESS}`);
console.log(`  Chain: ${confluxESpace.name} (${confluxESpace.id})`);
console.log(`  Poll interval: ${POLL_INTERVAL / 1000}s`);
console.log(`  Threshold: ${THRESHOLD_BPS} bps`);
console.log(`  Rebalancer: ${account.address}`);
console.log("");

// Run immediately, then on interval
checkAndRebalance();
setInterval(checkAndRebalance, POLL_INTERVAL);
