"use client";

import { useState } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseUnits, formatUnits } from "viem";
import { TokenInput } from "@/components/TokenInput";
import { StatCard } from "@/components/StatCard";
import { getContracts } from "@/config/contracts";
import { ERC20_ABI, USDT0_ROUTER_ABI } from "@/config/abis";

export default function DepositPage() {
  const [amount, setAmount] = useState("");
  const [isWithdraw, setIsWithdraw] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");
  const { address, isConnected, chain } = useAccount();
  const contracts = getContracts(chain?.id ?? 71);
  const isWrongNetwork = isConnected && chain?.id !== 71;

  const { data: usdt0Balance } = useReadContract({
    address: contracts.USDT0,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
  });

  const { data: huUSDT0Balance } = useReadContract({
    address: contracts.USDT0Router,
    abi: USDT0_ROUTER_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
  });

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

  const { data: strategyCount } = useReadContract({
    address: contracts.USDT0Router,
    abi: USDT0_ROUTER_ABI,
    functionName: "getStrategyCount",
  });

  const { data: allowance } = useReadContract({
    address: contracts.USDT0,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: address ? [address, contracts.USDT0Router] : undefined,
  });

  const { writeContract: approve, data: approveTx } = useWriteContract();
  const { writeContract: deposit, data: depositTx } = useWriteContract();
  const { writeContract: redeem, data: redeemTx } = useWriteContract();

  const { isLoading: isApproving } = useWaitForTransactionReceipt({ hash: approveTx });
  const { isLoading: isDepositing } = useWaitForTransactionReceipt({ hash: depositTx });
  const { isLoading: isRedeeming } = useWaitForTransactionReceipt({ hash: redeemTx });

  const parsedAmount = amount ? parseUnits(amount, 6) : 0n;
  const needsApproval = !isWithdraw && allowance !== undefined && parsedAmount > (allowance as bigint);
  const isLoading = isApproving || isDepositing || isRedeeming;

  const handleApprove = () => {
    setErrorMessage("");
    approve({
      address: contracts.USDT0,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [contracts.USDT0Router, parsedAmount],
    });
  };

  const handleDeposit = () => {
    if (!address) return;
    setErrorMessage("");
    if (parsedAmount <= 0n) {
      setErrorMessage("Enter a valid USDT0 amount first.");
      return;
    }
    deposit({
      address: contracts.USDT0Router,
      abi: USDT0_ROUTER_ABI,
      functionName: "deposit",
      args: [parsedAmount, address],
    });
  };

  const handleWithdraw = () => {
    if (!address) return;
    setErrorMessage("");
    if (parsedAmount <= 0n) {
      setErrorMessage("Enter a valid huUSDT0 amount first.");
      return;
    }
    redeem({
      address: contracts.USDT0Router,
      abi: USDT0_ROUTER_ABI,
      functionName: "redeem",
      args: [parsedAmount, address, address],
    });
  };

  return (
    <div className="max-w-lg mx-auto space-y-6">
      <h1 className="text-3xl font-bold text-white">
        {isWithdraw ? "Withdraw" : "Deposit"} USDT0
      </h1>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-4">
        <StatCard
          title="Your huUSDT0"
          value={huUSDT0Balance ? formatUnits(huUSDT0Balance as bigint, 6) : "0"}
        />
        <StatCard
          title="Best APY"
          value={bestStrategy ? `${(Number(bestStrategy[1]) / 100).toFixed(2)}%` : "0%"}
          trend="up"
        />
      </div>

      {/* Toggle */}
      <div className="glass p-1 flex">
        <button
          onClick={() => setIsWithdraw(false)}
          className={`flex-1 py-2 rounded-xl text-sm font-medium transition-colors ${
            !isWithdraw
              ? "bg-primary-500 text-white"
              : "text-dark-400 hover:text-white"
          }`}
        >
          Deposit
        </button>
        <button
          onClick={() => setIsWithdraw(true)}
          className={`flex-1 py-2 rounded-xl text-sm font-medium transition-colors ${
            isWithdraw
              ? "bg-primary-500 text-white"
              : "text-dark-400 hover:text-white"
          }`}
        >
          Withdraw
        </button>
      </div>

      {/* Input */}
      <TokenInput
        label={isWithdraw ? "huUSDT0 to redeem" : "USDT0 to deposit"}
        token={isWithdraw ? "huUSDT0" : "USDT0"}
        value={amount}
        onChange={setAmount}
        balance={
          isWithdraw
            ? huUSDT0Balance
              ? formatUnits(huUSDT0Balance as bigint, 6)
              : "0"
            : usdt0Balance
              ? formatUnits(usdt0Balance as bigint, 6)
              : "0"
        }
        onMax={() => {
          const bal = isWithdraw ? huUSDT0Balance : usdt0Balance;
          if (bal) setAmount(formatUnits(bal as bigint, 6));
        }}
      />

      {/* Info */}
      <div className="glass p-4 space-y-2">
        <div className="flex justify-between text-sm">
          <span className="text-dark-400">Active Strategy</span>
          <span className="text-white">
            {strategyCount && Number(strategyCount) > 0 ? "Auto-routed vault" : "Idle vault"}
          </span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-dark-400">Total TVL</span>
          <span className="text-white">
            ${totalAssets ? Number(formatUnits(totalAssets as bigint, 6)).toLocaleString() : "0"}
          </span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-dark-400">Gas Fee</span>
          <span className="text-primary-400">Sponsored (Free)</span>
        </div>
        {strategyCount !== undefined && Number(strategyCount) === 0 && (
          <p className="text-xs text-amber-300">
            No live yield strategy is registered yet, so deposits currently stay in the vault.
          </p>
        )}
      </div>

      {errorMessage && (
        <div className="glass border border-red-500/20 p-4 text-sm text-red-300">
          {errorMessage}
        </div>
      )}

      {/* Action Button */}
      {!isConnected ? (
        <div className="glass p-4 text-center text-dark-400">
          Connect your wallet to {isWithdraw ? "withdraw" : "deposit"}
        </div>
      ) : isWrongNetwork ? (
        <div className="glass border border-amber-500/20 p-4 text-center text-amber-300">
          Switch your wallet to Conflux eSpace Testnet to continue.
        </div>
      ) : isWithdraw ? (
        <button
          onClick={handleWithdraw}
          disabled={!amount || isLoading}
          className="w-full py-4 rounded-xl bg-gradient-to-r from-primary-500 to-primary-600 text-white font-medium hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isRedeeming ? "Withdrawing..." : "Withdraw USDT0"}
        </button>
      ) : needsApproval ? (
        <button
          onClick={handleApprove}
          disabled={!amount || isLoading}
          className="w-full py-4 rounded-xl bg-accent-500 text-white font-medium hover:opacity-90 transition-opacity disabled:opacity-50"
        >
          {isApproving ? "Approving..." : "Approve USDT0"}
        </button>
      ) : (
        <button
          onClick={handleDeposit}
          disabled={!amount || isLoading}
          className="w-full py-4 rounded-xl bg-gradient-to-r from-primary-500 to-primary-600 text-white font-medium hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isDepositing ? "Depositing..." : "Deposit & Earn Yield"}
        </button>
      )}
    </div>
  );
}
