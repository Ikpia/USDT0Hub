// Contract addresses — updated after deployment
export const CONTRACTS = {
  // Conflux eSpace Testnet (Chain ID 71)
  testnet: {
    USDT0: "0xd382984b05554D9d5aE9Ab62f6aA22De553be8b7" as `0x${string}`,
    USDT0OFT: "0xBa600674c1b3FEDaD2244Be759aF4142c00f0BE2" as `0x${string}`,
    AxCNH: "0x809FA23FEa777d37CdF3acab67Cd62D9A75e7BCf" as `0x${string}`,
    USDT0Router: "0xFca52d74ab1E9468889b7bC59DdC7D84b8B84F8a" as `0x${string}`,
    USDT0AxCNHPair: "0xd75deBc05976291Df39411607121873330Fd14F3" as `0x${string}`,
    USDT0BridgeReceiver: "0x00f1AE6Ef6C6C3aD0Cbb9f424aDfCF344cB4fC35" as `0x${string}`,
    USDT0HubSponsorManager: "0xa23f76b617f4F6aEa723645D399A523fdb9A3fc5" as `0x${string}`,
  },
  // Conflux eSpace Mainnet (Chain ID 1030)
  mainnet: {
    USDT0: "0xaf37E8B6C9ED7f6318979f56Fc287d76c30847ff" as `0x${string}`,
    USDT0OFT: "0xC57efa1c7113D98BdA6F9f249471704Ece5dd84A" as `0x${string}`,
    AxCNH: "0x0000000000000000000000000000000000000000" as `0x${string}`,
    USDT0Router: "0x0000000000000000000000000000000000000000" as `0x${string}`,
    USDT0AxCNHPair: "0x0000000000000000000000000000000000000000" as `0x${string}`,
    USDT0BridgeReceiver: "0x0000000000000000000000000000000000000000" as `0x${string}`,
    USDT0HubSponsorManager: "0x0000000000000000000000000000000000000000" as `0x${string}`,
  },
} as const;

export function getContracts(chainId: number) {
  if (chainId === 71) return CONTRACTS.testnet;
  if (chainId === 1030) return CONTRACTS.mainnet;
  return CONTRACTS.testnet; // default to testnet
}
