# 🏛️ Sovereign Gold Logistics Simulation

An advanced **Geopolitical Game Theory & Economic Simulation** smart contract built on Solidity (`^0.8.20`).

## 📜 Scenario & Geopolitical Mechanics
This smart contract simulates a macro-economic gold repatriation event between Germany (Bundesbank) and the US Federal Reserve (NY FED):

1. **Phase 1 (Public Pressure & Citizen Lease):** German citizens lease strategic gold slugs (strictly 1 slug per family/address to prevent whale monopoly and maximize diplomatic mobilization).
2. **Phase 1.5 (Peacekeeper Diplomacy):** US Federal Authority signs the peacekeeping release order to save face globally, broadcasting an official White House statement while receiving 0 EUR from arbitrage proceeds.
3. **Phase 2 ("The French Maneuver"):** The sovereign state executes international market arbitrage:
   - **100% of Net Arbitrage Profits (~13B EUR)** stay in the German treasury.
   - 5% of net profit funds a nationwide celebration (Oktoberfest for all).
   - **100% of accumulated public ETH stays home**: 10% is allocated to citizen yield, and 90% powers state social reforms.
4. **Phase 3 (Citizen Yield & Celebration):** Participants claim honorary Bayerische Sausage Vouchers and withdraw their real ETH yield via a secure Pull-Payment mechanism.

---

## 🛠️ Security & Architecture Features

- **Pull-Payment Dividend Distribution:** Prevents Reentrancy attacks by applying the strict *Checks-Effects-Interactions* pattern (`pendingDividendPayouts` zeroed prior to `.call`).
- **Anti-Whale Enforcement:** Enforces strict `1 family - 1 slug` allocation (`require(citizenGoldShares[msg.sender] == 0)`).
- **State Machine Guardrails:** Multi-stage execution protected by role-based access control (`bankAdmin` and `fedAdmin`).
- **Modern Low-Level Transfers:** Utilizes `.call{value: amount}("")` conforming to modern EVM practices.

---

## 💻 Contract Roles

| Role / Entity | Variable | Description |
| :--- | :--- | :--- |
| **Sovereign Bank** | `bankAdmin` | Executes arbitrage maneuver & state treasury harvest |
| **US Federal Authority** | `fedAdmin` | Signs the official diplomatic release order |
| **Citizen Holder** | `msg.sender` | Leases gold shares, claims sausage vouchers & pulls ETH yield |

---

## 🚀 Technical Overview

- **Solidity Version:** `^0.8.20`
- **License:** MIT
- **Category:** DePIN / Geopolitical Game Theory / Simulation
