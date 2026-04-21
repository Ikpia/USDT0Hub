"use client";

import { useState } from "react";
import { StatCard } from "@/components/StatCard";

const CHAINS = [
  { id: 1, name: "Ethereum", icon: "ETH" },
  { id: 42161, name: "Arbitrum", icon: "ARB" },
  { id: 8453, name: "Base", icon: "BASE" },
  { id: 10, name: "Optimism", icon: "OP" },
  { id: 137, name: "Polygon", icon: "POL" },
  { id: 56, name: "BNB Chain", icon: "BNB" },
  { id: 43114, name: "Avalanche", icon: "AVAX" },
];

const STRATEGIES = [
  { id: "auto", name: "Auto (Best APY)", desc: "Router picks highest yield" },
  { id: "dforce", name: "dForce Unitus", desc: "Lending yield ~5.2% APY" },
  { id: "wallfreex", name: "WallFreeX LP", desc: "Swap fee yield ~3.8% APY" },
  { id: "shui", name: "SHUI Finance", desc: "Staking yield ~6.1% APY" },
];

export default function BridgePage() {
  const [sourceChain, setSourceChain] = useState(CHAINS[0]);
  const [amount, setAmount] = useState("");
  const [strategy, setStrategy] = useState("auto");
  const [step, setStep] = useState<"input" | "bridging" | "done">("input");

  const handleBridge = () => {
    setStep("bridging");
    // Simulate bridge delay
    setTimeout(() => setStep("done"), 5000);
  };

  return (
    <div className="max-w-lg mx-auto space-y-6">
      <h1 className="text-3xl font-bold text-white">Bridge & Deposit</h1>
      <p className="text-dark-400">
        One transaction from any chain. Meson.fi bridges your USDT0 to Conflux
        and routes it into yield automatically.
      </p>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-4">
        <StatCard title="Bridge Time" value="1-3 min" subtitle="via Meson.fi" />
        <StatCard title="Bridge Fee" value="~$0.50" subtitle="Paid on source chain" />
      </div>

      {step === "done" ? (
        <div className="glass p-8 text-center glow-green">
          <div className="text-4xl mb-4">&#x2713;</div>
          <h3 className="text-xl font-bold text-white mb-2">
            Bridge Complete!
          </h3>
          <p className="text-dark-300">
            {amount} USDT0 bridged from {sourceChain.name} and deposited into{" "}
            {STRATEGIES.find((s) => s.id === strategy)?.name}. Your huUSDT0
            shares are in your wallet.
          </p>
          <button
            onClick={() => {
              setStep("input");
              setAmount("");
            }}
            className="mt-6 px-6 py-3 rounded-xl bg-primary-500 text-white font-medium hover:opacity-90"
          >
            Bridge More
          </button>
        </div>
      ) : step === "bridging" ? (
        <div className="glass p-8 text-center">
          <div className="animate-spin w-12 h-12 border-4 border-primary-500 border-t-transparent rounded-full mx-auto mb-4" />
          <h3 className="text-xl font-bold text-white mb-2">
            Bridging via Meson.fi...
          </h3>
          <p className="text-dark-300">
            Transferring {amount} USDT0 from {sourceChain.name} to Conflux
            eSpace. This takes 1-3 minutes.
          </p>
          <div className="mt-6 space-y-2">
            <div className="flex items-center justify-between glass p-3">
              <span className="text-sm text-dark-400">Source Chain TX</span>
              <span className="text-sm text-primary-400">Confirmed</span>
            </div>
            <div className="flex items-center justify-between glass p-3">
              <span className="text-sm text-dark-400">Meson Bridge</span>
              <span className="text-sm text-yellow-400">Processing...</span>
            </div>
            <div className="flex items-center justify-between glass p-3">
              <span className="text-sm text-dark-400">Yield Deposit</span>
              <span className="text-sm text-dark-500">Pending</span>
            </div>
          </div>
        </div>
      ) : (
        <>
          {/* Source Chain */}
          <div className="glass p-4">
            <label className="text-sm text-dark-400 block mb-3">
              Source Chain
            </label>
            <div className="grid grid-cols-4 gap-2">
              {CHAINS.map((chain) => (
                <button
                  key={chain.id}
                  onClick={() => setSourceChain(chain)}
                  className={`p-3 rounded-xl text-center text-xs font-medium transition-colors ${
                    sourceChain.id === chain.id
                      ? "bg-primary-500/20 text-primary-400 border border-primary-500/50"
                      : "bg-dark-700 text-dark-300 hover:bg-dark-600 border border-transparent"
                  }`}
                >
                  <div className="text-lg mb-1">{chain.icon}</div>
                  {chain.name}
                </button>
              ))}
            </div>
          </div>

          {/* Amount */}
          <div className="glass p-4">
            <label className="text-sm text-dark-400 block mb-2">
              USDT0 Amount
            </label>
            <input
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.00"
              className="w-full bg-transparent text-2xl font-medium text-white outline-none placeholder:text-dark-600"
            />
          </div>

          {/* Strategy Hint */}
          <div className="glass p-4">
            <label className="text-sm text-dark-400 block mb-3">
              Yield Strategy
            </label>
            <div className="space-y-2">
              {STRATEGIES.map((s) => (
                <button
                  key={s.id}
                  onClick={() => setStrategy(s.id)}
                  className={`w-full p-3 rounded-xl text-left transition-colors ${
                    strategy === s.id
                      ? "bg-primary-500/20 border border-primary-500/50"
                      : "bg-dark-700 border border-transparent hover:bg-dark-600"
                  }`}
                >
                  <div className="text-sm font-medium text-white">{s.name}</div>
                  <div className="text-xs text-dark-400">{s.desc}</div>
                </button>
              ))}
            </div>
          </div>

          {/* Summary */}
          <div className="glass p-4 space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-dark-400">Route</span>
              <span className="text-white">
                {sourceChain.name} → Meson → Conflux eSpace → Yield
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-dark-400">Estimated Time</span>
              <span className="text-white">1-3 minutes</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-dark-400">Conflux Gas</span>
              <span className="text-primary-400">Sponsored (Free)</span>
            </div>
          </div>

          <button
            onClick={handleBridge}
            disabled={!amount}
            className="w-full py-4 rounded-xl bg-gradient-to-r from-purple-500 to-accent-500 text-white font-medium hover:opacity-90 disabled:opacity-50"
          >
            Bridge & Deposit USDT0
          </button>
        </>
      )}
    </div>
  );
}
