# Data Center Token (DCT)

**Data Center Token (DCT)** is an ERC-20 tokenisation design for financing a **single sovereign data centre project** through a ring-fenced **special purpose vehicle (SPV)**.

This project was developed for the **IFTE0007 Decentralised Finance and Blockchain** individual coursework on **asset tokenisation design**.

---

## Project Idea

DCT does **not** tokenise the physical building, land, or specific hardware units inside the data centre.  
Instead, it tokenises a **proportional claim on the SPV’s audited distributable profit**.

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

A non-fungible token structure would not be appropriate here because the claim is not unique from holder to holder.  
Each unit of DCT carries the same standardised economic right.

ERC-20 is used because it supports:

- divisibility
- transferability
- wallet compatibility
- interoperability with Ethereum-compatible infrastructure
- programmable payout and governance mechanisms

---

## Economic Rights of DCT

Each DCT token represents:

- a proportional claim on the SPV’s **audited distributable profit**
- limited token-weighted voting rights on major strategic matters

DCT does **not** represent:

- legal ownership of the building itself
- ownership of servers, racks, GPUs, or other hardware units
- a claim on gross revenue
- day-to-day operational control of the data centre

This distinction is important.

The token is linked to **distributable profit**, not gross revenue, because a data centre requires continuous spending on:

- operations
- maintenance
- reserve allocation
- approved capital upgrades
- resilience and cybersecurity investment

Tokenising gross revenue would overstate investor entitlement and ignore the economics of maintaining infrastructure over time.

---

## Core Contract Logic

The contract is designed to support more than basic token minting.

### 1. Fixed Supply
DCT is issued with a **fixed total supply** for a single ring-fenced project.  
This keeps proportional entitlement stable and avoids dilution in the simplified coursework design.

### 2. Transferability
As an ERC-20 token, DCT can be transferred between eligible holders, supporting the idea that infrastructure-linked claims may become easier to trade than conventional SPV interests.

### 3. Profit Distribution
Audited distributable profit is deposited on-chain in a payout token such as **USDC**.

The contract uses a **cumulative profit-per-token accounting model** to ensure that:
- holders receive profit in proportion to their entitlement
- past profit rights remain with the holders who were economically exposed at the relevant time
- a new buyer cannot unfairly claim profit that was deposited before they acquired the tokens

This is economically stronger than a naive “current balance at claim time” approach.

### 4. Governance
The contract includes **limited governance functionality** for major strategic decisions, such as:
- operator replacement
- major expansion
- reserve policy changes
- major repair programmes
- whole-project sale proposals

This is intentionally limited governance.  
Token holders do not run the facility day to day.  
The data centre remains professionally managed off-chain by a specialist operator.

### 5. Compliance-Oriented Restrictions
Because DCT represents an investment-like claim on future profit, the design assumes that real-world deployment may require compliance controls such as:
- KYC / whitelisting
- transfer restrictions where legally required
- off-chain disclosure and legal documentation

This reflects the realistic possibility that DCT would be treated as a regulated investment instrument in many jurisdictions.

---

## Simplified Lifecycle

### Stage 1: Project Finance
- Government contributes 10% of project capital as a subsidy
- SPV issues DCT
- Investors subscribe to DCT in the primary sale
- Capital raised finances the data centre project

### Stage 2: Operation
- The facility is operated by a professional operator
- Revenue is generated through data centre services
- Costs, reserves, and approved upgrades are deducted

### Stage 3: Profit Determination
- The SPV determines audited distributable profit off-chain
- The authorised manager deposits the distributable amount on-chain in USDC

### Stage 4: Tokenholder Entitlement
- DCT holders claim profit according to token-based proportional entitlement
- Major strategic matters can be voted on through token-weighted governance

### Stage 5: Secondary Transfer
- Holders may transfer eligible tokens to other investors
- Market price may move above or below estimated fundamental value depending on market conditions

---

## Why This Design Makes Sense Financially

This project is designed around the logic required by the coursework:

### Asset
A single data centre project capable of generating long-run net cash flow.

### Token
A standardised ERC-20 claim on audited distributable profit.

### Market
Primary issuance finances construction; secondary transfer may improve liquidity relative to conventional private infrastructure interests.

### Risk
Blockchain improves divisibility, transferability, transparency, and administrative efficiency, but does not eliminate:
- off-chain reporting risk
- operator risk
- smart contract risk
- governance concentration risk
- legal and regulatory risk
- market illiquidity

---

## Important Limitations

This project is a **coursework design**, not a production-ready infrastructure financing platform.

Several limitations remain important:

- on-chain logic cannot independently verify off-chain accounting
- legal enforceability still depends on SPV contracts and applicable law
- tokenisation does not guarantee deep market liquidity
- governance can still be vulnerable to concentrated holders
- real-world distributions depend on honest and audited profit determination
- compliance requirements may limit open transferability in practice

Accordingly, the strongest interpretation of DCT is as a model showing how blockchain can support the life cycle of a tokenised infrastructure profit claim, rather than as proof that blockchain removes the need for legal, accounting, and governance institutions.

---

## Repository Contents

- `DCT.sol` — main smart contract implementing the DCT design
- `README.md` — project overview and coursework explanation
- `LICENSE` — repository licence file

---

## Contract Information

- **Token Name:** Data Center Token
- **Token Symbol:** DCT
- **Standard:** ERC-20
- **Underlying economic claim:** proportional claim on audited distributable profit of a single SPV data centre project

**Testnet Contract Address:**  
`0x1e65896b5481a7af0a929683526507ca7c90d907`

---

## Coursework Context

This repository is submitted as supporting implementation evidence for the coursework report.  
The main purpose of the project is to demonstrate how a real asset can be transformed into a tokenised financial instrument with a logically coherent relationship between:

- asset selection
- token structure
- market design
- liquidity logic
- risk analysis
- blockchain / DeFi infrastructure support

The full economic and analytical discussion is provided in the written report.

---

## Disclaimer

This repository is for **academic coursework purposes only**.  
It does not constitute investment advice, an offer of securities, or a production-ready infrastructure financing product.
