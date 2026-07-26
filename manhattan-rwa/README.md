# 🏢 Manhattan RWA (Real World Asset) Fractional Ownership

An automated **Real World Asset (RWA) Tokenization & Consolidation** smart contract built on Solidity (`^0.8.20`).

## 📜 Scenario & Mechanics
This smart contract enables fractional real estate investment and automated asset buyback for high-value prime properties:

1. **Target Asset:** `721 5th Ave, Penthouse, New York, NY 10022` (Trump Tower Penthouse, valued at $15M USD).
2. **Fractional Ownership ("Bricks"):** The property equity is divided into `15,000` total shares ("bricks") priced at `0.001 ETH` per brick.
3. **Crowdsourcing Phase:** Investors purchase property shares via `buyManhattanBrick()`.
4. **Corporate Call Option & Consolidation:** The `propertyManager` triggers asset consolidation by executing a buyout offer with a **20% liquidation bonus** (`0.0012 ETH` per brick).
5. **Automated Exit Liquidity:** Investors execute `claimLiquidatedFunds()` via pull-payments to claim their initial principal plus net arbitrage profit.

---

## 🛠️ Security & Architecture Features

- **Reentrancy Protection:** Employs the strict *Checks-Effects-Interactions* pattern (`myBricks[msg.sender] = 0` prior to low-level ETH transfer).
- **Secure Low-Level Transfers:** Modern `.call{value: payout}("")` transfer standard with transaction success validation.
- **Liquidation Reserve Escrow:** Enforces exact funding validation (`msg.value >= totalRequiredFunds`) before locking the contract into the consolidation phase.

---

## 💻 Contract Roles

| Role / Entity | Variable / Address | Description |
| :--- | :--- | :--- |
| **Asset Manager** | `propertyManager` | Deploys contract and triggers property buyback/consolidation |
| **Retail Investor** | `msg.sender` | Purchases property bricks, holds equity, and claims liquidated ETH |

---

## 🚀 Technical Overview

- **Solidity Version:** `^0.8.20`
- **License:** MIT
- **Category:** RWA / Real Estate Tokenization / Call Option Protocol
---

📌 **Version Architecture:**
- `ManhattanRWA_v2.sol` — **Production Version:** Includes automated Call Option registry, liquidity reserve escrow, and automated ETH dividend distribution.
- `Manhattan.sol` — **v1 Prototype:** Archived initial property tokenization foundation.
