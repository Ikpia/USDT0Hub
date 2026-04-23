# USDT0Hub

> The intelligent liquidity layer for USDT0 on Conflux — bridge once, earn everywhere.

---

## Overview

USDT0Hub is an omnichain liquidity aggregation and smart routing protocol purpose-built for USDT0 — the LayerZero-powered omnichain USDT — on Conflux eSpace. Users bridge USDT0 from any of 60+ supported chains via Meson.fi, and USDT0Hub automatically routes it into the highest-yielding sink available on Conflux: dForce Unitus lending markets, WallFreeX stablecoin liquidity pools, or SHUI Finance via swap. USDT0Hub also introduces the first on-chain USDT0 ↔ AxCNH atomic swap primitive, enabling instant USD-to-offshore-CNH foreign exchange directly on Conflux eSpace — no CEX, no KYC, no settlement delay.

USDT0Hub is the missing liquidity infrastructure layer for Conflux eSpace: one entry point that makes every dollar of USDT0 bridged to Conflux immediately productive.

---

## Hackathon

**Global Hackfest 2026** | 2026-03-23 – 2026-04-20

**Prize Targets:** Main Award ($1,500) + Best USDT0 Integration ($500) + Best DeFi Project ($500)

---

## Team

- **Ikpia Emmanuel** — Full-Stack Developer & Project Lead (GitHub: [@Ikpia](https://github.com/Ikpia))


---

## Problem Statement

USDT0 is one of the most consequential stablecoin innovations of the past two years — a LayerZero-powered OFT (Omnichain Fungible Token) that lets USDT move natively across 60+ chains without wrapping, without bridges, and without liquidity fragmentation. Conflux eSpace has USDT0 deployed and live.

But having USDT0 on Conflux eSpace is not the same as having USDT0 *work* on Conflux eSpace. Today, a user who bridges USDT0 to Conflux faces three compounding dead ends:

**1. No unified yield entry point.** dForce Unitus offers USDT lending yield. WallFreeX offers stablecoin LP yield. SHUI Finance offers CFX staking yield accessible via swap. Each requires separate transactions, separate approvals, and separate ongoing monitoring. Most users deposit into whichever protocol they happen to find first — not whichever offers the best return.

**2. No USD ↔ CNH FX primitive.** Conflux's strategic positioning is as the payment infrastructure for Asia-aligned trade corridors. AxCNH (offshore CNH-pegged stablecoin) is the settlement asset for that corridor. Yet there is no atomic, on-chain swap between USDT0 and AxCNH that a business or individual can use for real-world FX settlement. Converting USDT to offshore CNH today requires leaving the chain entirely.

**3. No intelligent routing.** When a user bridges USDT0 to Conflux today, the tokens sit in their wallet. The chain has yield-generating protocols, but no infrastructure to route incoming stablecoin liquidity toward them automatically. Capital efficiency on Conflux eSpace is systematically below its potential.

The result: Conflux has USDT0, but USDT0 does not yet have a home on Conflux.

---

## Solution

USDT0Hub provides three composable primitives that together make USDT0 fully productive on Conflux eSpace:

**1. The Smart Router.** A `USDT0Router.sol` contract that accepts USDT0 deposits and routes them to yield strategies based on a real-time allocation engine. Strategies are registered as adapters implementing a common `IYieldStrategy` interface. The router reads current APYs across dForce Unitus, WallFreeX, and SHUI (via swap path) and deposits into the highest-yielding strategy. Users receive `huUSDT0` — an ERC-4626 share token representing their proportional claim on the underlying USDT0 plus accrued yield.

**2. The FX Swap Primitive.** A `USDT0AxCNHPair.sol` contract that maintains a concentrated liquidity pool for USDT0/AxCNH, modeled after WallFreeX's stablecoin AMM (Uniswap V3 style). Businesses and individuals can atomically swap USDT0 for AxCNH — or vice versa — at near-zero slippage for the stablecoin pair. This is the first on-chain USD ↔ offshore CNH FX market on Conflux eSpace. Liquidity providers earn swap fees; fees are distributed in the deposited assets, not a protocol token.

**3. The Omnichain Entry Point.** A `USDT0BridgeReceiver.sol` contract that integrates with Meson.fi's cross-chain router. Users on Ethereum, Arbitrum, Base, or any other USDT0-supported chain can call a single function: `depositFromChain(sourceChain, amount, strategyHint)`. Meson bridges the USDT0 to Conflux eSpace and triggers the receiver, which immediately routes the incoming tokens into the target strategy. From the user's perspective: one transaction on their source chain, yield accruing on Conflux within minutes.

All user-facing interactions — deposit, withdraw, swap, claim yield — are sponsored via Conflux's Fee Sponsorship mechanism. Users with zero CFX can interact fully.

---

## Go-to-Market Plan

### Target Users

**Primary — Stablecoin yield seekers bridging to Conflux:**
Users and protocols holding USDT0 on Ethereum, Arbitrum, or Base who want Conflux's lower-fee, higher-yield environment without the friction of manually navigating multiple protocols. USDT0's omnichain architecture makes this the path of least resistance.

**Secondary — Asia corridor businesses needing on-chain FX:**
Companies operating across USD and CNH payment corridors — importers, exporters, payroll processors, supply chain finance platforms — who need a reliable, non-custodial USD ↔ AxCNH swap without CEX exposure. The USDT0 ↔ AxCNH pair is the only on-chain primitive serving this use case.

**Tertiary — Conflux-native DeFi users:**
Existing Conflux eSpace users who hold USDT or stablecoins and want a single interface to compare and access all available yield without manually monitoring each protocol.

**Quaternary — Liquidity providers:**
USDT0 holders willing to provide liquidity to the USDT0/AxCNH pair in exchange for swap fee revenue from the Asia FX corridor volume.

### Distribution

**Phase 1 — Hackathon (now → April 20):**
Deploy on Conflux eSpace testnet with mock USDT0 and AxCNH. Live demo showing cross-chain deposit flow from Arbitrum testnet → Conflux eSpace testnet via Meson. Submit to Global Hackfest 2026 targeting Main Award + Best USDT0 Integration + Best DeFi Project.

**Phase 2 — Mainnet Launch (Month 1–2):**
- Deploy on Conflux eSpace mainnet
- Apply for Conflux Ecosystem Grants (fast-tracked for hackathon winners)
- Outreach to Meson.fi for official integration listing — USDT0Hub generates Meson bridge volume, strong aligned incentive
- Outreach to AnchorX to co-market the USDT0/AxCNH FX pair — first USD ↔ offshore CNH on-chain market is a flagship use case for their stablecoin
- List on ConfluxScan and ConfluxHub ecosystem directories

**Phase 3 — Scale (Month 3–6):**
- Add Pyth Network price feeds for real-time APY data in the routing engine (replacing on-chain read-only queries)
- Launch liquidity mining incentives for USDT0/AxCNH pair funded from protocol swap fees
- Integrate with KinetFlow for Core Space ↔ eSpace USDT0 movement
- Target $1M in routed USDT0 volume within 90 days of mainnet

### Key Metrics

| Metric | 30-Day Target | 90-Day Target |
|--------|--------------|---------------|
| Total USDT0 routed (USD) | $100K | $1M |
| USDT0/AxCNH swap volume (USD) | $50K | $500K |
| Unique depositors | 150 | 1,000 |
| Active yield strategies | 3 | 5 |
| Gas sponsored (USD equiv.) | $300 | $2,000 |

---

## Conflux Integration

USDT0Hub is built to showcase the full depth of Conflux eSpace's DeFi ecosystem and unique protocol features:

- [ ] Core Space
- [x] **eSpace** — All contracts deployed on Conflux eSpace. The EVM-compatible environment supports standard Solidity patterns; Conflux's high TPS and low fees make the routing and rebalancing logic economically viable at scale.
- [ ] Cross-Space Bridge
- [x] **Gas Sponsorship** — `SponsorWhitelistControl` built-in contract sponsors all user-facing transactions: `deposit()`, `withdraw()`, `swap()`, and `claimYield()`. Users bridge USDT0 to Conflux and immediately start earning — zero CFX required.
- [x] **Built-in Contracts** — Uses Conflux's `SponsorWhitelistControl` built-in contract at `0x0888000000000000000000000000000000000001` for programmatic fee sponsorship management, managed by `USDT0HubSponsorManager.sol`.
- [x] **Partner Integrations:**
  - **LayerZero (USDT0 OFT)** — USDT0 is a LayerZero OFT token. USDT0Hub is built natively around the USDT0 OFT standard, accepting USDT0 deposits from any LayerZero-connected chain and routing them on Conflux eSpace. The router integrates the official USDT0 OFT contract (`0xC57efa1c7113D98BdA6F9f249471704Ece5dd84A` on mainnet) for cross-chain sends via `quoteUsdt0Bridge()` and `bridgeUsdt0()`.
  - **Meson.fi** — Cross-chain entry point. Meson's stablecoin bridge routes USDT0 from 60+ chains to Conflux eSpace; `USDT0BridgeReceiver.sol` hooks into Meson's destination call to automatically route incoming USDT0 into yield strategies.
  - **dForce Unitus** — Primary USDT0 lending yield strategy. USDT0Hub supplies USDT0 to Unitus lending markets and harvests interest continuously.
  - **WallFreeX** — Stablecoin LP yield strategy. USDT0Hub provides USDT0/AxCNH liquidity to WallFreeX pools and earns swap fees.
  - **Pyth Network** — Real-time price feeds for USDT/USD and USD/CNH used in the FX pair's oracle-powered pricing and slippage protection.

---

## Features

- **Smart yield routing** — Automatically routes USDT0 deposits to the highest-yielding strategy across dForce Unitus, WallFreeX, and SHUI Finance; rebalances as rates shift
- **USDT0 ↔ AxCNH FX swap** — First on-chain atomic swap between USDT0 (USD-pegged) and AxCNH (offshore CNH-pegged) on Conflux eSpace; near-zero slippage for the stablecoin pair
- **Omnichain single-transaction entry** — Deposit USDT0 from any supported chain in one transaction; Meson.fi bridges and routes automatically on arrival
- **LayerZero OFT bridge** — Route USDT0 cross-chain directly from the vault via the official USDT0 OFT contract; `quoteUsdt0Bridge()` + `bridgeUsdt0()` for seamless outbound transfers
- **ERC-4626 vault shares (huUSDT0)** — Yield-bearing receipt token that is composable with any DeFi protocol reading the ERC-4626 standard
- **Gasless all interactions** — Fee Sponsorship via Conflux's `SponsorWhitelistControl` covers all user transactions; zero CFX required
- **Pyth-powered routing** — Real-time Pyth Network price feeds inform routing decisions and protect the FX pair against stale price manipulation
- **LP fee revenue** — Liquidity providers in the USDT0/AxCNH pair earn swap fees in USDT0 and AxCNH; no protocol token required
- **Strategy registry** — Open adapter interface (`IYieldStrategy`) allows new yield strategies to be added via governance without redeploying the core router
- **Real-time dashboard** — Live APY comparison, USDT0/AxCNH FX rate from Pyth oracle, GeckoTerminal market data, bridge status tracker, and depositor portfolio view
- **Multi-wallet support** — Fluent Wallet (Conflux native), MetaMask, Rabby, Coinbase Wallet, OKX, and any EIP-1193 injected wallet

---

## Technology Stack

- **Frontend:** React 18, Next.js 14, Wagmi v2, Viem, TailwindCSS
- **Backend:** Node.js, TypeScript — rebalancer service that monitors yield rates and triggers `rebalance()` on the router contract when APY delta exceeds threshold
- **Blockchain:** Conflux eSpace (Chain ID: 1030 mainnet / 71 testnet)
- **Smart Contracts:** Solidity ^0.8.24, Foundry (forge, cast, anvil), OpenZeppelin 5.x
- **Protocol Integrations:** LayerZero USDT0 OFT interface, Meson.fi cross-chain SDK, dForce Unitus lending interface, WallFreeX router, Pyth Network EVM SDK
- **Conflux-Specific:** `SponsorWhitelistControl` built-in contract, Conflux eSpace RPC (`evm.confluxrpc.com`)
- **Testing:** Forge test suite (35 tests passing); unit tests for router, FX pair, and bridge receiver
- **Deployment:** Vercel (frontend), Conflux eSpace testnet (contracts)

---

## Setup Instructions

### Prerequisites

- Node.js v20+
- Foundry (`curl -L https://foundry.paradigm.xyz | bash && foundryup`)
- Git
- Conflux wallet — Fluent Wallet or MetaMask configured for Conflux eSpace testnet
- Testnet CFX from the [Conflux eSpace faucet](https://efaucet.confluxnetwork.org/)

### Installation

1. Clone the repository

   ```bash
   git clone https://github.com/Ikpia/USDT0Hub.git
   cd USDT0Hub
   ```

2. Install Foundry dependencies

   ```bash
   forge install
   ```

3. Install frontend dependencies

   ```bash
   cd frontend && npm install && cd ..
   ```

4. Install rebalancer dependencies

   ```bash
   cd rebalancer && npm install && cd ..
   ```

5. Configure environment

   ```bash
   cp .env.example .env
   ```

   Edit `.env` with your configuration:

   ```env
   # Conflux eSpace
   CONFLUX_ESPACE_RPC=https://evm.confluxrpc.com
   CONFLUX_ESPACE_TESTNET_RPC=https://evmtestnet.confluxrpc.com
   CHAIN_ID=71

   # Deployer
   PRIVATE_KEY=your_private_key_here

   # Conflux built-in
   SPONSOR_WHITELIST_CONTROL=0x0888000000000000000000000000000000000001

   # Rebalancer
   REBALANCE_THRESHOLD_BPS=75
   REBALANCE_POLL_INTERVAL_SECONDS=300

   # Protocol fees
   SWAP_FEE_BPS=5
   PROTOCOL_FEE_SHARE_BPS=1000
   ```

6. Compile contracts

   ```bash
   forge build
   ```

7. Run the application

   ```bash
   # Start frontend
   cd frontend && npm run dev

   # Start rebalancer service (in separate terminal)
   cd rebalancer && npm run dev
   ```

### Testing

```bash
# Run full test suite (35 tests)
forge test -vvv

# Run specific test file
forge test --match-path test/USDT0Router.t.sol -vvv

# Run with verbosity for debugging
forge test --match-test test_deposit -vvvv
```

---

## Usage

### Depositing USDT0 for Yield

**From Conflux eSpace directly:**

1. Open USDT0Hub and connect your wallet (zero CFX needed — all gas sponsored).
2. Select "Deposit" and enter your USDT0 amount.
3. The router displays the current APY breakdown across all strategies and shows the recommended allocation.
4. Confirm the deposit. You receive `huUSDT0` shares immediately. Yield accrues automatically.

**From another chain (one-transaction entry):**

1. Open USDT0Hub and select "Bridge & Deposit".
2. Choose your source chain (Ethereum, Arbitrum, Base, etc.) and enter your USDT0 amount.
3. Optionally select a strategy hint (e.g. "maximize APY" or "dForce only").
4. Confirm on your source chain. Meson bridges USDT0 to Conflux eSpace and the `USDT0BridgeReceiver` automatically routes it into your chosen strategy. Bridge + deposit completes in 1–3 minutes.

### USDT0 ↔ AxCNH FX Swap

1. Open the "FX Swap" tab.
2. Enter your USDT0 amount. The interface displays the current USDT0/AxCNH rate (powered by Pyth price feeds) and estimated AxCNH output.
3. Review slippage (typically < 0.1% for the stablecoin pair).
4. Confirm. AxCNH arrives in your wallet in the same transaction.

### Providing Liquidity to the FX Pair

1. Open "Liquidity" tab and select the USDT0/AxCNH pair.
2. Enter the amounts of USDT0 and AxCNH you want to deposit.
3. Confirm. You receive LP tokens representing your share of the pool and begin earning swap fees immediately.
4. Withdraw liquidity and claim accumulated fees at any time.

---

## Demo

- **Live Demo:** https://usdt0hub.vercel.app *(testnet deployment)*
- **Demo Video:** [YouTube — USDT0Hub walkthrough](https://youtu.be/aN47DfVBlp4)
- **Pitch Deck:** [Slide Presentation](https://gamma.app/docs/qm1kg9kkipkhpyd)
- **Twitter/X:** [Announcement Post](https://x.com/i/status/2046364674828967982)

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Omnichain Entry Points                           │
│                                                                      │
│  ┌────────────────────┐   ┌────────────────────┐  ┌───────────────┐ │
│  │  Direct deposit    │   │  Meson.fi bridge   │  │  LayerZero    │ │
│  │  (eSpace wallet)   │   │  (60+ source chains│  │  USDT0 OFT   │ │
│  │  USDT0 direct      │   │  → eSpace USDT0)   │  │  native xfer │ │
│  └─────────┬──────────┘   └──────────┬─────────┘  └──────┬───────┘ │
└────────────┼──────────────────────────┼───────────────────┼─────────┘
             │  deposit()              │  onReceive()       │  lzReceive()
             └──────────────┬──────────┘───────────────────┘
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      USDT0Router.sol                                 │
│                                                                      │
│  Reads live APYs → Computes optimal allocation → Routes USDT0       │
│  Mints huUSDT0 (ERC-4626 shares) to depositor                      │
│  Manages strategy registry (IYieldStrategy adapters)                │
│  Integrates official USDT0 OFT for cross-chain bridge               │
│  Sponsored by SponsorWhitelistControl (0x0888...)                   │
└──────────┬───────────────────┬────────────────────┬─────────────────┘
           │                   │                    │
           ▼                   ▼                    ▼
  ┌─────────────────┐ ┌────────────────┐ ┌──────────────────────┐
  │ dForceUnitus    │ │ WallFreeX      │ │ SHUI Finance         │
  │ Adapter.sol     │ │ Adapter.sol    │ │ Adapter.sol          │
  │                 │ │                │ │                      │
  │ USDT0 → Unitus  │ │ USDT0/AxCNH   │ │ USDT0 → CFX swap    │
  │ lending yield   │ │ LP fee yield   │ │ → staking yield      │
  └─────────────────┘ └────────────────┘ └──────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                   USDT0AxCNHPair.sol (FX Swap)                       │
│                                                                      │
│  StableSwap AMM with Pyth oracle-based pricing                      │
│  USDT0 ↔ AxCNH at near-zero slippage                                │
│  Pyth Network price feeds (USDT/USD + USD/CNH)                      │
│  LP fee revenue: distributed in USDT0 + AxCNH                      │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│               Off-Chain Rebalancer Service                           │
│  Node.js · Polls strategy APYs every 5 min · Signs rebalance()     │
│  Only triggers when APY delta > configured threshold (75bps)        │
└──────────────────────────────────────────────────────────────────────┘
```

**Key Design Decisions:**

- **`IYieldStrategy` interface** makes the router extensible without redeployment. Adding a new yield source (e.g. a new dForce market, a new DEX) is a single adapter contract deployment and a governance call to `registerStrategy()`.
- **Pyth Network oracle** is used for the FX pair rather than an on-chain TWAP because USDT0 and AxCNH are both stablecoins with external reference prices (USD and offshore CNH). A TWAP of a thin on-chain pool would be easily manipulated; Pyth's pull-based oracle provides a tamper-resistant external reference.
- **huUSDT0 ERC-4626 shares** are intentionally composable. A future lending protocol on Conflux can accept `huUSDT0` as collateral, letting depositors borrow against their yield-bearing position — no changes to USDT0Hub required.
- **Rebalancer threshold (75bps)** prevents excessive gas spend on micro-rebalances while capturing meaningful yield improvements. The rebalancer is off-chain but non-custodial — it can only call `rebalance()`, never `withdraw()`.
- **Official USDT0 OFT integration** — The router holds a reference to the real LayerZero USDT0 OFT contract, enabling `quoteUsdt0Bridge()` and `bridgeUsdt0()` for cross-chain sends directly from the vault.

---

## Smart Contracts

### Testnet (Conflux eSpace Testnet — Chain ID: 71)

| Contract | Address |
|----------|---------|
| `USDT0 (Mock)` | `0xd382984b05554D9d5aE9Ab62f6aA22De553be8b7` |
| `USDT0 OFT (Mock)` | `0xBa600674c1b3FEDaD2244Be759aF4142c00f0BE2` |
| `AxCNH (Mock)` | `0x809FA23FEa777d37CdF3acab67Cd62D9A75e7BCf` |
| `USDT0Router` | `0xFca52d74ab1E9468889b7bC59DdC7D84b8B84F8a` |
| `USDT0AxCNHPair` | `0xd75deBc05976291Df39411607121873330Fd14F3` |
| `USDT0BridgeReceiver` | `0x00f1AE6Ef6C6C3aD0Cbb9f424aDfCF344cB4fC35` |
| `USDT0HubSponsorManager` | `0xa23f76b617f4F6aEa723645D399A523fdb9A3fc5` |

### Mainnet References (Conflux eSpace — Chain ID: 1030)

| Token | Address |
|-------|---------|
| `USDT0` | `0xaf37E8B6C9ED7f6318979f56Fc287d76c30847ff` |
| `USDT0 OFT` | `0xC57efa1c7113D98BdA6F9f249471704Ece5dd84A` |

*Mainnet protocol contracts: post-hackathon deployment*

---

## Future Improvements

- **Governance module** — On-chain voting (CFX-weighted) to whitelist new yield strategies, adjust rebalance thresholds, and set protocol fee parameters; eliminates remaining admin key dependency
- **huUSDT0 collateral integration** — Partner with dForce to accept `huUSDT0` ERC-4626 shares as borrowing collateral, enabling leveraged yield strategies for advanced users
- **Dynamic liquidity concentration** — Automatically adjust the USDT0/AxCNH pair's liquidity concentration range based on Pyth price feed data, maximizing LP fee capture during periods of FX volatility
- **Core Space ↔ eSpace routing** — Integrate KinetFlow to route USDT0 held on Conflux Core Space into eSpace yield strategies via the Cross-Space Bridge, capturing liquidity currently siloed in Core Space
- **Limit orders on FX pair** — Allow businesses to place USDT0 ↔ AxCNH limit orders that execute automatically when the exchange rate hits a target, enabling programmatic FX hedging
- **Multi-stablecoin support** — Extend the router to support USDC, CNHT0 (omnichain CNH token), and additional stablecoins as they achieve liquidity depth on Conflux eSpace
- **Known Limitations:** The rebalancer service is a single centralized process in the current version — decentralization via a bonded keeper network is planned for post-hackathon production. The USDT0/AxCNH pair's liquidity depth at launch will be thin; meaningful FX volume requires a liquidity bootstrapping campaign. Meson.fi bridge latency (1–3 minutes) means the "one-transaction cross-chain deposit" involves a waiting period — the UI will show a bridge progress tracker to manage expectations.

---

## License

This project is licensed under the MIT License — see the [LICENSE](./LICENSE) file for details.

---

## Acknowledgments

- **Conflux Network** — For the Gas Sponsorship mechanism and high-throughput eSpace infrastructure; without sponsored transactions, routing cross-chain stablecoin deposits gaslessly would be impossible
- **LayerZero** — For the USDT0 OFT standard that makes omnichain USDT movement natively possible; USDT0Hub is built entirely around this primitive
- **Meson.fi** — For the cross-chain stablecoin bridge infrastructure that enables one-transaction deposits from 60+ chains; USDT0Hub's cross-chain UX depends on Meson's routing
- **AnchorX** — For the AxCNH offshore yuan stablecoin that makes the USDT0/AxCNH FX pair meaningful; without a credible CNH-pegged stablecoin on Conflux, the FX use case doesn't exist
- **dForce** — For the Unitus lending market that provides the primary USDT0 yield strategy and the DeFAI infrastructure vision that USDT0Hub contributes to
- **WallFreeX** — For the stablecoin AMM infrastructure on Conflux eSpace that USDT0Hub uses as a yield strategy and FX pair model
- **Pyth Network** — For the pull-based price oracle used in the FX pair and routing engine; real-time price feeds are essential for manipulation-resistant stablecoin swaps
- **OpenZeppelin** — ERC-20, ERC-4626, and security pattern libraries
- **Foundry** — Solidity testing and deployment toolchain
