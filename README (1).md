# Data Center Token (DCT)

**Data Center Token (DCT)** is an ERC-20 tokenisation design for financing a **single sovereign data centre project** through a ring-fenced **special purpose vehicle (SPV)**.

This project was developed for the **IFTE0007 Decentralised Finance and Blockchain** individual coursework on **asset tokenisation design**.

---

## Contract Information

| Parameter | Value |
|---|---|
| Token Name | Data Center Token |
| Symbol | DCT |
| Standard | ERC-20 |
| Decimals | 18 |
| Total Supply | 10,000,000 DCT |
| Network | Sepolia Testnet |
| Compiler | Solidity 0.8.34 |
| Optimisation | Enabled (runs = 1) |
| Payout Token | USDC (0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238) |

**Testnet Contract Address:**
```
0x6CA533afeF51e240722a49d1007bD6476e424B2D
```

[View on Blockscout](https://eth-sepolia.blockscout.com/address/0x6CA533afeF51e240722a49d1007bD6476e424B2D)

---

## Project Idea

DCT does **not** tokenise the physical building, land, or specific hardware units inside the data centre.
Instead, it tokenises a **proportional claim on the SPV's audited distributable profit**.

This is the core economic logic of the project:

**real infrastructure asset → audited distributable profit → tokenised ERC-20 claim → transferability, payout, and governance on-chain**

The design is intended to show how a real-world infrastructure project can be abstracted into a tokenised financial instrument in a way that is economically coherent, rather than simply minting a token for a physical object.

---

## Why This Asset Is Tokenised

A sovereign data centre is a capital-intensive infrastructure asset that generates value through:

- colocation and hosting services
- connectivity and digital infrastructure services
- reliable power, cooling, and physical security
- long-term demand for domestic digital capacity and data resilience

However, direct investment in infrastructure projects is usually limited to governments, banks, funds, and large institutions.

DCT is designed to address that problem by making the economic exposure:

- more divisible
- easier to transfer
- more transparent to record
- easier to administer through smart contracts

In the model proposed in the report, the government contributes **10%** of the initial capital cost as a strategic subsidy, while the remaining **90%** is raised from investors through the primary sale of DCT.

---

## Why ERC-20 and Why Fungible

DCT is implemented as an **ERC-20 fungible token** because every token represents the **same proportional claim on the same distributable profit stream**.

A non-fungible token structure would not be appropriate here because the claim is not unique from holder to holder. Each unit of DCT carries the same standardised economic right.

ERC-20 is used because it supports:

- divisibility
- transferability
- wallet compatibility
- interoperability with Ethereum-compatible infrastructure
- programmable payout and governance mechanisms

---

## Economic Rights of DCT

Each DCT token represents:

- a proportional claim on the SPV's **audited distributable profit**
- limited token-weighted voting rights on major strategic matters

DCT does **not** represent:

- legal ownership of the building itself
- ownership of servers, racks, GPUs, or other hardware units
- a claim on gross revenue
- day-to-day operational control of the data centre

This distinction is important. The token is linked to **distributable profit**, not gross revenue, because a data centre requires continuous spending on operations, maintenance, reserve allocation, approved capital upgrades, and cybersecurity investment. Tokenising gross revenue would overstate investor entitlement and ignore the economics of maintaining infrastructure over time.

---

## Core Contract Logic

### 1. Fixed Supply
DCT is issued with a **fixed total supply** for a single ring-fenced project. This keeps proportional entitlement stable and avoids dilution.

### 2. Transferability
As an ERC-20 token, DCT can be transferred between KYC-approved holders, supporting the idea that infrastructure-linked claims may become easier to trade than conventional SPV interests.

### 3. Profit Distribution
Audited distributable profit is deposited on-chain in **USDC**. The contract uses a **cumulative profit-per-token accounting model** to ensure that:

- holders receive profit in proportion to their entitlement
- past profit rights remain with holders who were economically exposed at the time
- a new buyer cannot unfairly claim profit deposited before they acquired tokens

| Function | Description |
|---|---|
| `depositDistributableProfit()` | Manager deposits audited USDC profit on-chain with audit hash |
| `claimProfit()` | Holder claims their proportional USDC share |
| `accumulativeProfitOf()` | Total profit ever accumulated by an address |
| `claimableProfitOf()` | Profit available to claim right now |
| `getTotalDistributed()` | Total USDC ever distributed across all rounds |

### 4. Governance
The contract includes **limited governance functionality** for major strategic decisions. Voting uses **ERC20Votes snapshot** balances so that transfers during a voting window cannot manipulate the outcome. A **conflict-of-interest guard** prevents the operator from voting on operator-related proposals.

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

### 5. KYC Whitelist
Because DCT represents an investment-like claim on future profit, it is likely treated as a regulated instrument in many jurisdictions. Token transfers are restricted to KYC-approved addresses only.

| Function | Description |
|---|---|
| `setKycStatus()` | Approve or revoke a single address |
| `batchSetKycApproved()` | Batch approve multiple addresses at once |

### 6. Emergency Pause
If a vulnerability is discovered, the owner can immediately halt all transfers and claims.

| Function | Description |
|---|---|
| `emergencyPause()` | Halt all token transfers and profit claims |
| `unpause()` | Resume normal operations after resolution |

---

## Simplified Lifecycle

### Stage 1: Project Finance
- Government contributes 10% of project capital as a subsidy
- SPV issues DCT and sells to investors in primary sale
- Capital raised finances the data centre project

### Stage 2: Operation
- The facility is operated by a professional operator under contract
- Revenue is generated through data centre services
- Costs, reserves, and approved upgrades are deducted

### Stage 3: Profit Determination
- The SPV determines audited distributable profit off-chain
- The authorised manager deposits the distributable amount on-chain in USDC with an audit hash

### Stage 4: Tokenholder Entitlement
- DCT holders claim profit according to proportional token entitlement
- Major strategic matters can be voted on through token-weighted governance

### Stage 5: Secondary Transfer
- KYC-approved holders may transfer tokens to other eligible investors
- Market price may move above or below estimated fundamental value

---

## Risk Summary

Blockchain improves divisibility, transferability, transparency, and administrative efficiency, but does not eliminate:

- off-chain reporting risk — on-chain logic cannot verify off-chain accounting
- operator risk — management quality affects distributable profit
- smart contract risk — code may contain vulnerabilities
- governance concentration risk — large holders may dominate votes
- legal and regulatory risk — compliance requirements vary by jurisdiction
- market illiquidity risk — tokenisation does not guarantee deep markets

---

## Important Limitations

This project is a **coursework design**, not a production-ready infrastructure financing platform. Several limitations remain important:

- legal enforceability still depends on SPV contracts and applicable law
- tokenisation does not guarantee deep market liquidity
- real-world distributions depend on honest and audited profit determination
- compliance requirements may limit open transferability in practice

The strongest interpretation of DCT is as a model showing how blockchain can support the life cycle of a tokenised infrastructure profit claim, rather than as proof that blockchain removes the need for legal, accounting, and governance institutions.

---

## Repository Contents

| File | Description |
|---|---|
| `DCT.sol` | Main contract — ERC-20 + profit distribution + governance + KYC + pause |
| `EIP20Interface.sol` | Reference interface from course material |
| `README.md` | Project overview and coursework explanation |
| `LICENSE` | MIT License |

---

## Coursework Context

This repository is submitted as supporting implementation evidence for the coursework report. The main purpose of the project is to demonstrate how a real asset can be transformed into a tokenised financial instrument with a logically coherent relationship between:

- asset selection and value source
- token structure and design
- market access and liquidity logic
- risk analysis and limitations
- blockchain and DeFi infrastructure support

The full economic and analytical discussion is provided in the written report.

---

## Disclaimer

This repository is for **academic coursework purposes only**.
It does not constitute investment advice, an offer of securities, or a production-ready infrastructure financing product.

---

## License

MIT © 2026 jackma234321-creator
