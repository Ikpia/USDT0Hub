"use client";

import { useState } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseUnits, formatUnits } from "viem";
import { TokenInput } from "@/components/TokenInput";
import { getContracts } from "@/config/contracts";
import { ERC20_ABI, FX_PAIR_ABI } from "@/config/abis";

export default function SwapPage() {
  const [amountIn, setAmountIn] = useState("");
  const [direction, setDirection] = useState<"usdt0-to-axcnh" | "axcnh-to-usdt0">(
    "usdt0-to-axcnh"
  );
  const [errorMessage, setErrorMessage] = useState("");
  const { address, isConnected, chain } = useAccount();
  const contracts = getContracts(chain?.id ?? 71);
  const isWrongNetwork = isConnected && chain?.id !== 71;

  const isUSDT0In = direction === "usdt0-to-axcnh";
  const tokenIn = isUSDT0In ? "USDT0" : "AxCNH";
  const tokenOut = isUSDT0In ? "AxCNH" : "USDT0";
  const decimalsIn = isUSDT0In ? 6 : 18;
  const decimalsOut = isUSDT0In ? 18 : 6;

  const { data: balanceIn } = useReadContract({
    address: isUSDT0In ? contracts.USDT0 : contracts.AxCNH,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
  });

  const parsedAmountIn = amountIn ? parseUnits(amountIn, decimalsIn) : 0n;

  const { data: quotedOut } = useReadContract({
    address: contracts.USDT0AxCNHPair,
    abi: FX_PAIR_ABI,
    functionName: isUSDT0In ? "quoteUSDT0ForAxCNH" : "quoteAxCNHForUSDT0",
    args: parsedAmountIn > 0n ? [parsedAmountIn] : undefined,
  });

  const { data: reserves } = useReadContract({
    address: contracts.USDT0AxCNHPair,
    abi: FX_PAIR_ABI,
    functionName: "getReserves",
  });

  const { data: swapFee } = useReadContract({
    address: contracts.USDT0AxCNHPair,
    abi: FX_PAIR_ABI,
    functionName: "swapFeeBps",
  });

  const { data: allowance } = useReadContract({
    address: isUSDT0In ? contracts.USDT0 : contracts.AxCNH,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: address ? [address, contracts.USDT0AxCNHPair] : undefined,
  });

  const { writeContract: approve, data: approveTx } = useWriteContract();
  const { writeContract: swap, data: swapTx } = useWriteContract();

  const { isLoading: isApproving } = useWaitForTransactionReceipt({ hash: approveTx });
  const { isLoading: isSwapping } = useWaitForTransactionReceipt({ hash: swapTx });

  const needsApproval = allowance !== undefined && parsedAmountIn > (allowance as bigint);
  const reserve0 = reserves ? (reserves[0] as bigint) : 0n;
  const reserve1 = reserves ? (reserves[1] as bigint) : 0n;
  const hasLiquidity = reserve0 > 0n && reserve1 > 0n;

  const handleApprove = () => {
    setErrorMessage("");
    approve({
      address: isUSDT0In ? contracts.USDT0 : contracts.AxCNH,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [contracts.USDT0AxCNHPair, parsedAmountIn],
    });
  };

  const handleSwap = () => {
    setErrorMessage("");
    if (parsedAmountIn <= 0n) {
      setErrorMessage(`Enter a valid ${tokenIn} amount first.`);
      return;
    }
    if (!hasLiquidity) {
      setErrorMessage("This pool has no liquidity yet. Add liquidity before trying to swap.");
      return;
    }
    if (!quotedOut || (quotedOut as bigint) <= 0n) {
      setErrorMessage("No output quote is available for this trade right now.");
      return;
    }
    const minOut = quotedOut ? ((quotedOut as bigint) * 997n) / 1000n : 0n; // 0.3% slippage

    swap({
      address: contracts.USDT0AxCNHPair,
      abi: FX_PAIR_ABI,
      functionName: isUSDT0In ? "swapUSDT0ForAxCNH" : "swapAxCNHForUSDT0",
      args: [parsedAmountIn, minOut],
    });
  };

  const flipDirection = () => {
    setDirection(isUSDT0In ? "axcnh-to-usdt0" : "usdt0-to-axcnh");
    setAmountIn("");
  };

  return (
    <div className="max-w-lg mx-auto space-y-6">
      <h1 className="text-3xl font-bold text-white">FX Swap</h1>
      <p className="text-dark-400">
        Swap USDT0 &#x21C4; AxCNH at near-zero slippage. First on-chain USD/CNH
        FX market on Conflux.
      </p>

      {/* From Token */}
      <TokenInput
        label="You pay"
        token={tokenIn}
        value={amountIn}
        onChange={setAmountIn}
        balance={
          balanceIn ? formatUnits(balanceIn as bigint, decimalsIn) : "0"
        }
        onMax={() => {
          if (balanceIn) setAmountIn(formatUnits(balanceIn as bigint, decimalsIn));
        }}
      />

      {/* Flip Button */}
      <div className="flex justify-center -my-3 relative z-10">
        <button
          onClick={flipDirection}
          className="w-10 h-10 rounded-full bg-dark-700 border border-dark-600 flex items-center justify-center hover:bg-dark-600 transition-colors"
        >
          <span className="text-white">&#x21C5;</span>
        </button>
      </div>

      {/* To Token */}
      <TokenInput
        label="You receive"
        token={tokenOut}
        value={
          quotedOut
            ? Number(formatUnits(quotedOut as bigint, decimalsOut)).toFixed(
                decimalsOut === 6 ? 2 : 4
              )
            : ""
        }
        onChange={() => {}}
        disabled
      />

      {/* Info */}
      <div className="glass p-4 space-y-2">
        <div className="flex justify-between text-sm">
          <span className="text-dark-400">Exchange Rate</span>
          <span className="text-white">
            {quotedOut && parsedAmountIn > 0n
              ? `1 ${tokenIn} = ${(
                  Number(formatUnits(quotedOut as bigint, decimalsOut)) /
                  Number(amountIn)
                ).toFixed(4)} ${tokenOut}`
              : "—"}
          </span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-dark-400">Swap Fee</span>
          <span className="text-white">
            {swapFee ? `${Number(swapFee) / 100}%` : "0.05%"}
          </span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-dark-400">Pool Reserves</span>
          <span className="text-white">
            {reserves
              ? `${Number(formatUnits(reserves[0] as bigint, 6)).toLocaleString()} USDT0 / ${Number(formatUnits(reserves[1] as bigint, 18)).toLocaleString()} AxCNH`
              : "—"}
          </span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-dark-400">Slippage Tolerance</span>
          <span className="text-white">0.3%</span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-dark-400">Gas Fee</span>
          <span className="text-primary-400">Sponsored (Free)</span>
        </div>
      </div>

      {errorMessage && (
        <div className="glass border border-red-500/20 p-4 text-sm text-red-300">
          {errorMessage}
        </div>
      )}

      {/* Action */}
      {!isConnected ? (
        <div className="glass p-4 text-center text-dark-400">
          Connect your wallet to swap
        </div>
      ) : isWrongNetwork ? (
        <div className="glass border border-amber-500/20 p-4 text-center text-amber-300">
          Switch your wallet to Conflux eSpace Testnet to continue.
        </div>
      ) : !hasLiquidity ? (
        <div className="glass border border-amber-500/20 p-4 text-center text-amber-300">
          The USDT0/AxCNH pool is empty right now. Add liquidity first, then swap.
        </div>
      ) : needsApproval ? (
        <button
          onClick={handleApprove}
          disabled={!amountIn || isApproving}
          className="w-full py-4 rounded-xl bg-accent-500 text-white font-medium hover:opacity-90 disabled:opacity-50"
        >
          {isApproving ? "Approving..." : `Approve ${tokenIn}`}
        </button>
      ) : (
        <button
          onClick={handleSwap}
          disabled={!amountIn || isSwapping}
          className="w-full py-4 rounded-xl bg-gradient-to-r from-accent-500 to-accent-600 text-white font-medium hover:opacity-90 disabled:opacity-50"
        >
          {isSwapping ? "Swapping..." : `Swap ${tokenIn} for ${tokenOut}`}
        </button>
      )}
    </div>
  );
}
