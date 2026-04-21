"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { useAccount, useBalance, useConnect, useDisconnect, useSwitchChain } from "wagmi";

const NAV_ITEMS = [
  { href: "/", label: "Dashboard" },
  { href: "/deposit", label: "Deposit" },
  { href: "/swap", label: "FX Swap" },
  { href: "/liquidity", label: "Liquidity" },
  { href: "/bridge", label: "Bridge & Deposit" },
];

export function Navbar() {
  const pathname = usePathname();
  const { address, chain, isConnected, connector } = useAccount();
  const { connectors, connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, isPending: isSwitchingChain } = useSwitchChain();
  const [showWalletModal, setShowWalletModal] = useState(false);
  const [showMobileMenu, setShowMobileMenu] = useState(false);
  const [mounted, setMounted] = useState(false);

  const { data: balance } = useBalance({ address });
  const isWrongNetwork = mounted && isConnected && chain?.id !== 71;

  useEffect(() => {
    setMounted(true);
  }, []);

  const availableConnectors = useMemo(() => {
    const seen = new Set<string>();
    return connectors.filter((item) => {
      const id = `${item.id}:${item.name}`;
      if (seen.has(id)) return false;
      seen.add(id);
      return true;
    });
  }, [connectors]);

  const getWalletIcon = (name: string) => {
    const lower = name.toLowerCase();
    if (lower.includes("fluent")) return "F";
    if (lower.includes("metamask")) return "M";
    if (lower.includes("coinbase")) return "C";
    if (lower.includes("okx")) return "O";
    if (lower.includes("rabby")) return "R";
    return name[0]?.toUpperCase() ?? "?";
  };

  const getWalletColor = (name: string) => {
    const lower = name.toLowerCase();
    if (lower.includes("fluent")) return "from-blue-400 to-blue-600";
    if (lower.includes("metamask")) return "from-orange-400 to-orange-600";
    if (lower.includes("coinbase")) return "from-blue-500 to-blue-700";
    if (lower.includes("rabby")) return "from-emerald-400 to-emerald-600";
    return "from-gray-400 to-gray-600";
  };

  return (
    <>
      <nav className="glass border-b border-dark-700/50 sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            {/* Logo */}
            <Link href="/" className="flex items-center space-x-2">
              <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-primary-500 to-accent-500 flex items-center justify-center text-white font-bold text-sm">
                U0
              </div>
              <span className="text-lg font-bold text-white">USDT0Hub</span>
            </Link>

            {/* Nav Links (Desktop) */}
            <div className="hidden md:flex items-center space-x-1">
              {NAV_ITEMS.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                    pathname === item.href
                      ? "bg-primary-500/10 text-primary-400"
                      : "text-dark-300 hover:text-white hover:bg-dark-700/50"
                  }`}
                >
                  {item.label}
                </Link>
              ))}
            </div>

            {/* Mobile menu button */}
            <button
              onClick={() => setShowMobileMenu(!showMobileMenu)}
              className="md:hidden p-2 rounded-lg text-dark-300 hover:text-white hover:bg-dark-700/50"
            >
              <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>

            {/* Wallet Button */}
            <div className="hidden md:block">
              {mounted && isConnected ? (
                <div className="flex items-center space-x-2">
                  {balance && (
                    <span className="text-xs text-dark-400">
                      {Number(balance.formatted).toFixed(2)} {balance.symbol}
                    </span>
                  )}
                  <button
                    onClick={() => setShowWalletModal(true)}
                    className="px-4 py-2 rounded-xl bg-dark-700 text-sm text-dark-200 hover:bg-dark-600 transition-colors border border-dark-600 flex items-center space-x-2"
                  >
                    <div className={`w-5 h-5 rounded-full bg-gradient-to-br ${getWalletColor(connector?.name ?? "")} flex items-center justify-center text-white text-[10px] font-bold`}>
                      {getWalletIcon(connector?.name ?? "")}
                    </div>
                    <span>{address?.slice(0, 6)}...{address?.slice(-4)}</span>
                  </button>
                </div>
              ) : (
                <button
                  onClick={() => setShowWalletModal(true)}
                  className="px-4 py-2 rounded-xl bg-gradient-to-r from-primary-500 to-accent-500 text-white text-sm font-medium hover:opacity-90 transition-opacity"
                >
                  Connect Wallet
                </button>
              )}
            </div>
          </div>
        </div>

        {/* Mobile Nav Menu */}
        {showMobileMenu && (
          <div className="md:hidden border-t border-dark-700/50 px-4 py-3 space-y-1">
            {NAV_ITEMS.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setShowMobileMenu(false)}
                className={`block px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                  pathname === item.href
                    ? "bg-primary-500/10 text-primary-400"
                    : "text-dark-300 hover:text-white hover:bg-dark-700/50"
                }`}
              >
                {item.label}
              </Link>
            ))}
            <div className="pt-2 border-t border-dark-700/50">
              {mounted && isConnected ? (
                <button
                  onClick={() => { setShowWalletModal(true); setShowMobileMenu(false); }}
                  className="w-full px-3 py-2 rounded-lg bg-dark-700 text-sm text-dark-200 text-left"
                >
                  {address?.slice(0, 6)}...{address?.slice(-4)}
                </button>
              ) : (
                <button
                  onClick={() => { setShowWalletModal(true); setShowMobileMenu(false); }}
                  className="w-full px-3 py-2 rounded-xl bg-gradient-to-r from-primary-500 to-accent-500 text-white text-sm font-medium"
                >
                  Connect Wallet
                </button>
              )}
            </div>
          </div>
        )}
      </nav>

      {/* Wallet Modal */}
      {showWalletModal && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center">
          {/* Backdrop */}
          <div
            className="absolute inset-0 bg-black/60 backdrop-blur-sm"
            onClick={() => setShowWalletModal(false)}
          />

          {/* Modal */}
          <div className="relative glass p-6 w-full max-w-sm mx-4 glow-blue">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-bold text-white">
                {isConnected ? "Wallet" : "Connect Wallet"}
              </h3>
              <button
                onClick={() => setShowWalletModal(false)}
                className="text-dark-400 hover:text-white transition-colors"
              >
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            {mounted && isConnected ? (
              /* Connected state */
              <div className="space-y-4">
                <div className="glass p-4 text-center">
                  <div className={`w-12 h-12 rounded-full bg-gradient-to-br ${getWalletColor(connector?.name ?? "")} flex items-center justify-center text-white text-lg font-bold mx-auto mb-3`}>
                    {getWalletIcon(connector?.name ?? "")}
                  </div>
                  <p className="text-sm text-dark-400 mb-1">Connected via {connector?.name}</p>
                  <p className="text-white font-mono text-sm">
                    {address?.slice(0, 10)}...{address?.slice(-8)}
                  </p>
                  {balance && (
                    <p className="text-dark-400 text-sm mt-2">
                      {Number(balance.formatted).toFixed(4)} {balance.symbol}
                    </p>
                  )}
                </div>

                {isWrongNetwork && (
                  <button
                    onClick={() => switchChain({ chainId: 71 })}
                    disabled={isSwitchingChain}
                    className="w-full py-3 rounded-xl bg-amber-500/10 text-amber-300 text-sm font-medium hover:bg-amber-500/20 transition-colors border border-amber-500/20"
                  >
                    {isSwitchingChain ? "Switching..." : "Switch To eSpace Testnet"}
                  </button>
                )}

                <button
                  onClick={() => {
                    if (address) {
                      navigator.clipboard.writeText(address);
                    }
                  }}
                  className="w-full py-3 rounded-xl bg-dark-700 text-dark-200 text-sm hover:bg-dark-600 transition-colors border border-dark-600"
                >
                  Copy Address
                </button>

                <a
                  href={`https://evmtestnet.confluxscan.org/address/${address}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="block w-full py-3 rounded-xl bg-dark-700 text-dark-200 text-sm hover:bg-dark-600 transition-colors border border-dark-600 text-center"
                >
                  View on ConfluxScan
                </a>

                <button
                  onClick={() => {
                    disconnect();
                    setShowWalletModal(false);
                  }}
                  className="w-full py-3 rounded-xl bg-red-500/10 text-red-400 text-sm font-medium hover:bg-red-500/20 transition-colors border border-red-500/20"
                >
                  Disconnect
                </button>
              </div>
            ) : (
              /* Wallet selection */
              <div className="space-y-2">
                <p className="text-dark-400 text-sm mb-4">
                  Choose your wallet to connect to Conflux eSpace
                </p>

                {availableConnectors.map((c) => (
                  <button
                    key={c.uid}
                    onClick={() => {
                      connect({ connector: c });
                      setShowWalletModal(false);
                    }}
                    disabled={isPending}
                    className="w-full flex items-center space-x-3 p-3 rounded-xl bg-dark-700/50 hover:bg-dark-700 transition-colors border border-dark-600/50 hover:border-dark-500 disabled:opacity-50"
                  >
                    <div className={`w-10 h-10 rounded-xl bg-gradient-to-br ${getWalletColor(c.name)} flex items-center justify-center text-white font-bold`}>
                      {getWalletIcon(c.name)}
                    </div>
                    <div className="text-left flex-1">
                      <p className="text-white text-sm font-medium">{c.name}</p>
                      <p className="text-dark-400 text-xs">
                        {c.name.toLowerCase().includes("fluent")
                          ? "Conflux native wallet"
                          : "Browser extension"}
                      </p>
                    </div>
                    <svg className="w-4 h-4 text-dark-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                    </svg>
                  </button>
                ))}

                {isPending && (
                  <div className="text-center py-3">
                    <div className="animate-spin w-6 h-6 border-2 border-primary-500 border-t-transparent rounded-full mx-auto mb-2" />
                    <p className="text-dark-400 text-sm">Connecting...</p>
                  </div>
                )}

                <p className="text-dark-500 text-xs text-center pt-3">
                  Fluent, MetaMask, Rabby, OKX and other injected wallets are supported.
                </p>
              </div>
            )}
          </div>
        </div>
      )}
    </>
  );
}
