# 🧱 HUBRewardVault — Draft Proposal

**Author:** Mysticpol  
**Status:** RFC (Request for Comments)  
**Category:** Reward & Ecosystem Infrastructure  
**Created:** 2025-10-14  

---

## 🎯 Purpose

`HUBRewardVault` is a structural concept for managing HUB reward distribution within the **HUB Ecosystem**.  
It aims to provide predictable and transparent emission of HUB tokens over time while maintaining on-chain administrative control through the **ADMIN_CONTRACT (Gnosis Safe)**.

---

## ⚙️ Core Parameters

| Parameter | Value | Description |
|------------|--------|-------------|
| `epochDuration` | 365 days | Duration of one epoch |
| `epochBudget` | 1,000,000,000 HUB | Amount of HUB released per epoch |
| `maxEpochs` | 8 | Total epochs (8B HUB total budget) |
| `startTime` | `block.timestamp` (deploy) | Time when first epoch starts |
| `receiver` | `RewardDistributor` address | Contract that receives released HUB |
| `buybackTopUp` | optional | Future connection for top-up flow if price drops |

---

## 🧩 Key Design Principles

- **Predictable rewards** — long-term emission schedule to stabilize distribution.
- **Admin control** — only `ADMIN_CONTRACT` (Gnosis Safe) can:
  - update parameters,
  - change receiver,
  - or trigger emergency stop.
- **Upgradeable** — logic can be evolved (e.g., V2, dynamic epochs, governance-based allocation).
- **Separation of concerns** — reward emission is distinct from buyback or liquidity mechanisms.

---

## 🔒 Governance

- All privileged operations (parameter updates, epoch restarts, vault pauses) are restricted to `ADMIN_CONTRACT`.
- Future versions may introduce a **timelock** for transparent governance transitions.

---

## 🧠 Open Questions (for community review)

1. Should epoch emission be linear or callable only once per epoch?
2. Should the vault integrate a minimal “keeper reward” to incentivize periodic calls?
3. Should buyback/replenish flow be built-in or exist in a separate contract (BuybackManager)?
4. How should surplus HUB (unclaimed or recovered) be handled after 8 epochs?

---

## 🧰 Next Steps

- [ ] Finalize the emission logic draft  
- [ ] Add basic test cases (Forge/Foundry)  
- [ ] Discuss integration with `RewardDistributor`  
- [ ] Evaluate timelock upgrade pattern  
- [ ] Collect feedback from community  

---

**📂 File:** `contracts/HUBRewardVault.sol`  
**Maintainer:** Mysticpol  
**License:** MIT  

---

> 💬 *Comments and pull requests are welcome. Use labels: `design`, `security`, `economics` to focus feedback areas.*
