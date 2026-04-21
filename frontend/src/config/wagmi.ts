import { http, createConfig } from "wagmi";
import { injected } from "@wagmi/core";
import { defineChain } from "viem";

export const confluxESpaceTestnet = defineChain({
  id: 71,
  name: "Conflux eSpace Testnet",
  nativeCurrency: { name: "CFX", symbol: "CFX", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://evmtestnet.confluxrpc.com"] },
  },
  blockExplorers: {
    default: {
      name: "ConfluxScan",
      url: "https://evmtestnet.confluxscan.org",
    },
  },
  testnet: true,
});

export const confluxESpace = defineChain({
  id: 1030,
  name: "Conflux eSpace",
  nativeCurrency: { name: "CFX", symbol: "CFX", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://evm.confluxrpc.com"] },
  },
  blockExplorers: {
    default: {
      name: "ConfluxScan",
      url: "https://evm.confluxscan.org",
    },
  },
});

export const config = createConfig({
  multiInjectedProviderDiscovery: true,
  ssr: true,
  chains: [confluxESpaceTestnet, confluxESpace],
  connectors: [
    injected({
      target: {
        id: "fluent",
        name: "Fluent Wallet",
        provider: () => {
          if (typeof window !== "undefined") {
            return (window as any).fluent;
          }
        },
      },
    }),
    injected(),
  ],
  transports: {
    [confluxESpaceTestnet.id]: http(),
    [confluxESpace.id]: http(),
  },
});

declare module "wagmi" {
  interface Register {
    config: typeof config;
  }
}
