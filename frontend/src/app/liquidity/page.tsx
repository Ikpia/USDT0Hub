"use client";

import { useState } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseUnits, formatUnits } from "viem";
import { TokenInput } from "@/components/TokenInput";
import { StatCard } from "@/components/StatCard";
import { getContracts } from "@/config/contracts";
import { ERC20_ABI, FX_PAIR_ABI } from "@/config/abis";

export default function LiquidityPage() {
  const [usdt0Amount, setUsdt0Amount] = useState("");
  const [axcnhAmount, setAxcnhAmount] = useState("");
  const [lpToRemove, setLpToRemove] = useState("");
  const [isRemove, setIsRemove] = useState(false);
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

  const { data: axcnhBalance } = useReadContract({
    address: contracts.AxCNH,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
  });

  const { data: lpBalance } = useReadContract({
    address: contracts.USDT0AxCNHPair,
    abi: FX_PAIR_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
  });

  const { data: reserves } = useReadContract({
    address: contracts.USDT0AxCNHPair,
    abi: FX_PAIR_ABI,
    functionName: "getReserves",
  });

  const { data: totalSupply } = useReadContract({
    address: contracts.USDT0AxCNHPair,
    abi: FX_PAIR_ABI,
    functionName: "totalSupply",
  });

  const { data: usdt0Allowance } = useReadContract({
    address: contracts.USDT0,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: address ? [address, contracts.USDT0AxCNHPair] : undefined,
  });

  const { data: axcnhAllowance } = useReadContract({
    address: contracts.AxCNH,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: address ? [address, contracts.USDT0AxCNHPair] : undefined,
  });

  const { writeContract: approve, data: approveTx } = useWriteContract();
  const { writeContract: addLiq, data: addTx } = useWriteContract();
  const { writeContract: removeLiq, data: removeTx } = useWriteContract();

  const { isLoading: isApproving } = useWaitForTransactionReceipt({ hash: approveTx });
  const { isLoading: isAdding } = useWaitForTransactionReceipt({ hash: addTx });
  const { isLoading: isRemoving } = useWaitForTransactionReceipt({ hash: removeTx });

  const usdt0Parsed = usdt0Amount ? parseUnits(usdt0Amount, 6) : 0n;
  const axcnhParsed = axcnhAmount ? parseUnits(axcnhAmount, 18) : 0n;
  const needsUsdt0Approval = usdt0Parsed > 0n && usdt0Allowance !== undefined && usdt0Parsed > (usdt0Allowance as bigint);
  const needsAxcnhApproval = axcnhParsed > 0n && axcnhAllowance !== undefined && axcnhParsed > (axcnhAllowance as bigint);

  const handleAddLiquidity = () => {
    setErrorMessage("");
    if (usdt0Parsed <= 0n && axcnhParsed <= 0n) {
      setErrorMessage("Enter a USDT0 amount, an AxCNH amount, or both.");
      return;
    }

    addLiq({
      address: contracts.USDT0AxCNHPair,
      abi: FX_PAIR_ABI,
      functionName: "addLiquidity",
      args: [usdt0Parsed, axcnhParsed],
    });
  };

  const handleRemoveLiquidity = () => {
    setErrorMessage("");
    const lpParsed = lpToRemove ? parseUnits(lpToRemove, 18) : 0n;
    if (lpParsed <= 0n) {
      setErrorMessage("Enter a valid LP token amount first.");
      return;
    }

    removeLiq({
      address: contracts.USDT0AxCNHPair,
      abi: FX_PAIR_ABI,
      functionName: "removeLiquidity",
      args: [lpParsed],
    });
  };

  const poolShare =
    lpBalance && totalSupply && (totalSupply as bigint) > 0n
      ? (
          (Number(lpBalance as bigint) / Number(totalSupply as bigint)) *
          100
        ).toFixed(2)
      : "0";

  const handleApprove = (token: `0x${string}`, amount: bigint) => {
    setErrorMessage("");
    approve({
      address: token,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [contracts.USDT0AxCNHPair, amount],
    });
  };

  return (
    <div className="max-w-lg mx-auto space-y-6">
      <h1 className="text-3xl font-bold text-white">Liquidity</h1>
      <p className="text-dark-400">
        Provide USDT0/AxCNH liquidity and earn swap fees from the FX corridor.
      </p>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4">
        <StatCard
          title="Your LP Tokens"
          value={lpBalance ? Number(formatUnits(lpBalance as bigint, 18)).toFixed(2) : "0"}
        />
        <StatCard title="Pool Share" value={`${poolShare}%`} />
        <StatCard
          title="Pool TVL"
          value={
            reserves
              ? `$${Number(formatUnits(reserves[0] as bigint, 6)).toLocaleString()}`
              : "$0"
          }
        />
      </div>

      {/* Toggle */}
      <div className="glass p-1 flex">
        <button
          onClick={() => setIsRemove(false)}
          className={`flex-1 py-2 rounded-xl text-sm font-medium transition-colors ${
            !isRemove
              ? "bg-primary-500 text-white"
              : "text-dark-400 hover:text-white"
          }`}
        >
          Add Liquidity
        </button>
        <button
          onClick={() => setIsRemove(true)}
          className={`flex-1 py-2 rounded-xl text-sm font-medium transition-colors ${
            isRemove
              ? "bg-primary-500 text-white"
              : "text-dark-400 hover:text-white"
          }`}
        >
          Remove Liquidity
        </button>
      </div>

      {errorMessage && (
        <div className="glass border border-red-500/20 p-4 text-sm text-red-300">
          {errorMessage}
        </div>
      )}

      {isRemove ? (
        <>
          <TokenInput
            label="LP tokens to remove"
            token="huFX-LP"
            value={lpToRemove}
            onChange={setLpToRemove}
            balance={lpBalance ? formatUnits(lpBalance as bigint, 18) : "0"}
            onMax={() => {
              if (lpBalance) setLpToRemove(formatUnits(lpBalance as bigint, 18));
            }}
          />
          <button
            onClick={handleRemoveLiquidity}
            disabled={!lpToRemove || isRemoving || !isConnected || isWrongNetwork}
            className="w-full py-4 rounded-xl bg-gradient-to-r from-red-500 to-red-600 text-white font-medium hover:opacity-90 disabled:opacity-50"
          >
            {isRemoving ? "Removing..." : "Remove Liquidity"}
          </button>
        </>
      ) : (
        <>
          <TokenInput
            label="USDT0 amount"
            token="USDT0"
            value={usdt0Amount}
            onChange={setUsdt0Amount}
            balance={usdt0Balance ? formatUnits(usdt0Balance as bigint, 6) : "0"}
            onMax={() => {
              if (usdt0Balance) setUsdt0Amount(formatUnits(usdt0Balance as bigint, 6));
            }}
          />
          <TokenInput
            label="AxCNH amount"
            token="AxCNH"
            value={axcnhAmount}
            onChange={setAxcnhAmount}
            balance={axcnhBalance ? formatUnits(axcnhBalance as bigint, 18) : "0"}
            onMax={() => {
              if (axcnhBalance)
                setAxcnhAmount(formatUnits(axcnhBalance as bigint, 18));
            }}
          />

          <div className="glass p-4 space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-dark-400">Pool Reserves</span>
              <span className="text-white">
                {reserves
                  ? `${Number(formatUnits(reserves[0] as bigint, 6)).toLocaleString()} / ${Number(formatUnits(reserves[1] as bigint, 18)).toLocaleString()}`
                  : "—"}
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-dark-400">Gas Fee</span>
              <span className="text-primary-400">Sponsored (Free)</span>
            </div>
          </div>

          {isWrongNetwork ? (
            <div className="glass border border-amber-500/20 p-4 text-center text-amber-300">
              Switch your wallet to Conflux eSpace Testnet to continue.
            </div>
          ) : needsUsdt0Approval ? (
            <button
              onClick={() => handleApprove(contracts.USDT0, usdt0Parsed)}
              disabled={isApproving || !isConnected}
              className="w-full py-4 rounded-xl bg-accent-500 text-white font-medium hover:opacity-90 disabled:opacity-50"
            >
              {isApproving ? "Approving..." : "Approve USDT0"}
            </button>
          ) : needsAxcnhApproval ? (
            <button
              onClick={() => handleApprove(contracts.AxCNH, axcnhParsed)}
              disabled={isApproving || !isConnected}
              className="w-full py-4 rounded-xl bg-accent-500 text-white font-medium hover:opacity-90 disabled:opacity-50"
            >
              {isApproving ? "Approving..." : "Approve AxCNH"}
            </button>
          ) : (
            <button
              onClick={handleAddLiquidity}
              disabled={(!usdt0Amount && !axcnhAmount) || isAdding || !isConnected}
              className="w-full py-4 rounded-xl bg-gradient-to-r from-primary-500 to-accent-500 text-white font-medium hover:opacity-90 disabled:opacity-50"
            >
              {isAdding ? "Adding Liquidity..." : "Add Liquidity"}
            </button>
          )}
        </>
      )}
    </div>
  );
}
