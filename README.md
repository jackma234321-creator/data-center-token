# Data Center Token (DCT)

> ERC-20 token representing a proportional claim on the audited distributable profit of a sovereign data centre SPV.
> Module: Decentralised Finance and Blockchain (IFTE0007) — UCL

---

## Contract Address (Sepolia Testnet)

```
0x6CA533afeF51e240722a49d1007bD6476e424B2D
```

[View on Blockscout](https://eth-sepolia.blockscout.com/address/0x6CA533afeF51e240722a49d1007bD6476e424B2D)

---

## Token Details

| Parameter | Value |
|---|---|
| Name | Data Center Token |
| Symbol | DCT |
| Decimals | 18 |
| Total Supply | 10,000,000 DCT |
| Network | Sepolia Testnet |
| Payout Token | USDC (0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238) |
| Compiler | Solidity 0.8.34 |
| Optimisation | Enabled (runs = 1) |

---

## What is DCT?

DCT does **not** represent ownership of a physical data centre or any hardware unit. It represents a **proportional claim on the audited distributable profit** of a single sovereign data centre project, ring-fenced inside a Special Purpose Vehicle (SPV).

```
Distributable profit = gross revenue
                     - operating expenses
                     - maintenance costs
                     - reserve allocations
                     - approved capital upgrades
```

This design is motivated by a country such as Senegal, where the government contributes 10% of the initial capital cost as a subsidy, while the remaining 90% is raised through the primary sale of DCT to investors.

---

## Contract Architecture

### Profit Distribution (Section 3.4)
The contract implements a **cumulative magnified profit-per-token model** — solving the critical flaw where a buyer entering after a deposit could unfairly claim past profit. Holders only receive profit deposited while they held tokens.

| Function | Description |
|---|---|
| `depositDistributableProfit()` | Manager deposits audited USDC profit on-chain with audit hash |
| `claimProfit()` | Holder claims their proportional USDC share |
| `accumulativeProfitOf()` | Total profit ever accumulated by an address |
| `claimableProfitOf()` | Profit available to claim right now |
| `getTotalDistributed()` | Total USDC ever distributed across all rounds |

### Governance (Section 3.2)
Token-weighted snapshot voting on six major strategic matters, with a **conflict-of-interest guard** preventing the operator from voting on operator-related proposals.

| Proposal Type | Description |
|---|---|
| `OperatorReplacement` | Replace the professional operating company |
| `CapacityExpansion` | Approve significant capacity expansion |
| `ReservePolicyChange` | Change reserve / profit retention policy |
| `MajorRepairProgram` | Approve exceptional repair programmes |
| `NewBusinessLine` | Introduce new business lines |
| `WholeProjectSale` | Decide on sale of the whole project |

| Function | Description |
|---|---|
| `createProposal()` | Raise a governance proposal (requires 1% of supply) |
| `castVote()` | Cast snapshot-weighted vote (FOR / AGAINST) |
| `getProposalState()` | Returns Active / Passed / Failed / Executed |
| `executeProposal()` | Owner records outcome on-chain |

### KYC Whitelist (Section 4)
Because DCT gives holders an expectation of profit, it is likely a security in most jurisdictions. Token transfers are restricted to KYC-approved addresses only.

| Function | Description |
|---|---|
| `setKycStatus()` | Approve or revoke a single address |
| `batchSetKycApproved()` | Batch approve multiple addresses |

### Emergency Pause (Section 5)
If a vulnerability is discovered, the owner can immediately halt all transfers and claims.

| Function | Description |
|---|---|
| `emergencyPause()` | Halt all transfers and profit claims |
| `unpause()` | Resume normal operations |

---

## Deployment Parameters

```
initialHolder : 0x2d4902BbCd49ce0855A8AC2a92Fd4C5916e51ae
fixedSupply   : 10000000000000000000000000
payoutToken_  : 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
manager_      : 0x2d4902BbCd49ce0855A8AC2a92Fd4C5916e51ae
operator_     : 0x2d4902BbCd49ce0855A8AC2a92Fd4C5916e51ae
```

---

## Files

| File | Description |
|---|---|
| `DCT.sol` | Main contract — ERC-20 + profit distribution + governance + KYC |
| `EIP20Interface.sol` | Reference interface from course material |
| `LICENSE` | MIT License |

---

## License

MIT © 2026 jackma234321-creator
