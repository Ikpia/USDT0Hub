"use client";

import { useQuery } from "@tanstack/react-query";
import { useAccount, useReadContract } from "wagmi";
import { formatUnits } from "viem";
import { StatCard } from "@/components/StatCard";
import { CONTRACTS, getContracts } from "@/config/contracts";
import { USDT0_ROUTER_ABI, FX_PAIR_ABI } from "@/config/abis";
import Link from "next/link";

type MarketSnapshot = {
  source: string;
  network: string;
  token: string;
  poolCount: number;
  topPool: {
    address: string;
    name: string;
    reserveUsd: number;
    baseTokenPriceUsd: number;
    quoteTokenPriceUsd: number;
    volume24hUsd: number;
    buys24h: number;
    sells24h: number;
  } | null;
  fetchedAt: number;
};

export default function Dashboard() {
  const { isConnected, chain } = useAccount();
  const contracts = getContracts(chain?.id ?? 71);

  const { data: totalAssets } = useReadContract({
    address: contracts.USDT0Router,
    abi: USDT0_ROUTER_ABI,
    functionName: "totalAssets",
  });

  const { data: bestStrategy } = useReadContract({
    address: contracts.USDT0Router,
    abi: USDT0_ROUTER_ABI,
    functionName: "getBestStrategy",
  });

  const { data: reserves } = useReadContract({
    address: contracts.USDT0AxCNHPair,
    abi: FX_PAIR_ABI,
    functionName: "getReserves",
  });

  const { data: oracleRate } = useReadContract({
    address: contracts.USDT0AxCNHPair,
    abi: FX_PAIR_ABI,
    functionName: "getOracleRate",
  });

  const { data: marketSnapshot } = useQuery<MarketSnapshot>({
    queryKey: ["usdt0-market-snapshot"],
    queryFn: async () => {
      const res = await fetch("/api/market/usdt0");
      if (!res.ok) throw new Error("Failed to fetch GeckoTerminal snapshot");
      return res.json();
    },
    staleTime: 300_000,
    refetchInterval: 300_000,
  });

  const tvl = totalAssets ? formatUnits(totalAssets, 6) : "0";
  const bestApy = bestStrategy ? Number(bestStrategy[1]) / 100 : 0;
  const oracleFx = oracleRate ? Number(formatUnits(oracleRate, 18)) : 0;
  const testnetPoolUsdt0 = reserves ? Number(formatUnits(reserves[0], 6)) : 0;
  const topPool = marketSnapshot?.topPool;
  const strategies = [
    {
      name: "Auto-routed vault",
      apy: `${bestApy.toFixed(2)}%`,
      tvl: `$${Number(tvl).toLocaleString()}`,
      status: "Live",
    },
    {
      name: "Pyth USD/CNH FX",
      apy: `${oracleFx.toFixed(2)} CNH`,
      tvl: "Oracle-backed",
      status: "Live",
    },
    {
      name: "GeckoTerminal USDT0",
      apy: topPool ? `$${topPool.baseTokenPriceUsd.toFixed(4)}` : "Loading",
      tvl: topPool ? `$${topPool.reserveUsd.toLocaleString()}` : "Syncing",
      status: topPool ? "Mainnet" : "Pending",
    },
  ];

  return (
    <div className="space-y-8">
      {/* Hero */}
      <div className="text-center py-12">
        <h1 className="text-4xl md:text-5xl font-bold text-white mb-4">
          The Intelligent Liquidity Layer
          <br />
          <span className="bg-gradient-to-r from-primary-400 to-accent-400 bg-clip-text text-transparent">
            for USDT0 on Conflux
          </span>
        </h1>
        <p className="text-dark-300 text-lg max-w-2xl mx-auto">
          Bridge once, earn everywhere. Smart routing across dForce, WallFreeX,
          and SHUI Finance. Zero CFX needed — all gas sponsored.
        </p>
        <div className="flex justify-center gap-4 mt-8">
          <Link
            href="/deposit"
            className="px-6 py-3 rounded-xl bg-gradient-to-r from-primary-500 to-primary-600 text-white font-medium hover:opacity-90 transition-opacity"
          >
            Start Earning
          </Link>
          <Link
            href="/swap"
            className="px-6 py-3 rounded-xl bg-dark-700 text-white font-medium hover:bg-dark-600 transition-colors border border-dark-600"
          >
            FX Swap
          </Link>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <StatCard
          title="Total Value Locked"
          value={`$${Number(tvl).toLocaleString()}`}
          subtitle="Across all strategies"
        />
        <StatCard
          title="Best APY"
          value={`${bestApy.toFixed(2)}%`}
          subtitle="Auto-routed"
          trend="up"
        />
        <StatCard
          title="FX Pool Reserves"
          value={
            reserves ? `${testnetPoolUsdt0.toLocaleString()} USDT0` : "0 USDT0"
          }
          subtitle="Testnet USDT0/AxCNH pool"
        />
        <StatCard
          title="Oracle FX"
          value={oracleRate ? `${oracleFx.toFixed(2)} CNH` : "Loading"}
          subtitle="Live Pyth USDT0/AxCNH rate"
          trend={oracleRate ? "up" : undefined}
        />
      </div>

      <div className="glass p-6">
        <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div>
            <h2 className="text-xl font-bold text-white">
              Live USDT0 Market Snapshot
            </h2>
            <p className="text-dark-400 text-sm">
              GeckoTerminal data for the official Conflux eSpace USDT0 token
              and the real LayerZero OFT deployment.
            </p>
          </div>
          <div className="text-sm text-dark-400">
            <div>USDT0: {CONTRACTS.mainnet.USDT0}</div>
            <div>OFT: {CONTRACTS.mainnet.USDT0OFT}</div>
          </div>
        </div>

        <div className="mt-6 grid grid-cols-1 gap-4 md:grid-cols-4">
          <div className="rounded-2xl border border-dark-700 bg-dark-900/50 p-4">
            <div className="text-xs uppercase tracking-wide text-dark-500">
              Top Pool
            </div>
            <div className="mt-2 text-white font-semibold">
              {topPool?.name ?? "Loading..."}
            </div>
          </div>
          <div className="rounded-2xl border border-dark-700 bg-dark-900/50 p-4">
            <div className="text-xs uppercase tracking-wide text-dark-500">
              USDT0 Price
            </div>
            <div className="mt-2 text-white font-semibold">
              {topPool ? `$${topPool.baseTokenPriceUsd.toFixed(4)}` : "Loading"}
            </div>
          </div>
          <div className="rounded-2xl border border-dark-700 bg-dark-900/50 p-4">
            <div className="text-xs uppercase tracking-wide text-dark-500">
              24h Volume
            </div>
            <div className="mt-2 text-white font-semibold">
              {topPool
                ? `$${topPool.volume24hUsd.toLocaleString()}`
                : "Loading"}
            </div>
          </div>
          <div className="rounded-2xl border border-dark-700 bg-dark-900/50 p-4">
            <div className="text-xs uppercase tracking-wide text-dark-500">
              Liquidity
            </div>
            <div className="mt-2 text-white font-semibold">
              {topPool
                ? `$${topPool.reserveUsd.toLocaleString()}`
                : "Loading"}
            </div>
          </div>
        </div>
      </div>

      {/* Strategy Overview */}
      <div className="glass p-6">
        <h2 className="text-xl font-bold text-white mb-4">
          Integration Scorecard
        </h2>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="text-dark-400 text-sm border-b border-dark-700">
                <th className="text-left py-3 px-4">Module</th>
                <th className="text-right py-3 px-4">Live Signal</th>
                <th className="text-right py-3 px-4">Value</th>
                <th className="text-right py-3 px-4">Status</th>
              </tr>
            </thead>
            <tbody>
              {strategies.map((s, i) => (
                <tr
                  key={i}
                  className="border-b border-dark-700/50 hover:bg-dark-700/30 transition-colors"
                >
                  <td className="py-4 px-4 text-white font-medium">
                    {s.name}
                  </td>
                  <td className="py-4 px-4 text-right text-primary-400 font-medium">
                    {s.apy}
                  </td>
                  <td className="py-4 px-4 text-right text-dark-200">
                    {s.tvl}
                  </td>
                  <td className="py-4 px-4 text-right">
                    <span className="px-2 py-1 bg-primary-500/10 text-primary-400 rounded-full text-xs">
                      {s.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Features */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="glass p-6">
          <div className="w-10 h-10 rounded-lg bg-primary-500/10 flex items-center justify-center mb-4">
            <span className="text-primary-400 text-xl">$</span>
          </div>
          <h3 className="text-lg font-bold text-white mb-2">
            Smart Yield Routing
          </h3>
          <p className="text-dark-400 text-sm">
            Automatically routes your USDT0 to the highest-yielding strategy.
            Rebalances as rates shift.
          </p>
        </div>
        <div className="glass p-6">
          <div className="w-10 h-10 rounded-lg bg-accent-500/10 flex items-center justify-center mb-4">
            <span className="text-accent-400 text-xl">&#x21C4;</span>
          </div>
          <h3 className="text-lg font-bold text-white mb-2">
            USD/CNH FX Swap
          </h3>
          <p className="text-dark-400 text-sm">
            Live Pyth-powered USDT0 to AxCNH pricing on testnet with seeded
            liquidity for the demo swap path.
          </p>
        </div>
        <div className="glass p-6">
          <div className="w-10 h-10 rounded-lg bg-emerald-500/10 flex items-center justify-center mb-4">
            <span className="text-emerald-400 text-xl">&#x26A1;</span>
          </div>
          <h3 className="text-lg font-bold text-white mb-2">
            Official USDT0 OFT
          </h3>
          <p className="text-dark-400 text-sm">
            The router is now wired to the official LayerZero OFT deployment on
            Conflux eSpace for real omnichain USDT0 flows.
          </p>
        </div>
      </div>

      {/* Connection prompt */}
      {!isConnected && (
        <div className="glass p-8 text-center glow-blue">
          <h3 className="text-xl font-bold text-white mb-2">
            Connect your wallet to get started
          </h3>
          <p className="text-dark-400 mb-4">
            Use MetaMask or Fluent Wallet configured for Conflux eSpace
          </p>
        </div>
      )}
    </div>
  );
}
