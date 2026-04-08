// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * ============================================================
 *  Data Center Token (DCT)
 *  Module: Decentralised Finance and Blockchain (IFTE0007)
 * ============================================================
 *
 *  ASSET BEING TOKENISED
 *  ---------------------
 *  DCT does NOT represent ownership of the physical data centre
 *  building or any individual hardware unit (servers, racks, GPUs).
 *  It represents a PROPORTIONAL CLAIM ON AUDITED DISTRIBUTABLE
 *  PROFIT of a single sovereign data centre project ring-fenced
 *  inside a Special Purpose Vehicle (SPV).
 *
 *  "Distributable profit" = gross revenue
 *                         - operating expenses
 *                         - maintenance costs
 *                         - reserve allocations
 *                         - approved capital upgrades
 *
 *  WHY ERC-20 FUNGIBLE?
 *  --------------------
 *  Every DCT unit carries an identical proportional right.
 *  There is no economic reason to distinguish one token from
 *  another, so a fungible token is the appropriate structure.
 *
 *  LIFECYCLE (matches report Section 3.4 step-by-step)
 *  ----------------------------------------------------
 *  Step 1  Off-chain: SPV earns revenue, deducts costs, audits profit.
 *  Step 2  Manager calls depositDistributableProfit() — deposits
 *          stablecoin (USDC on testnet) and registers a profit round.
 *  Step 3  Contract records the round with auditHash for on-chain
 *          transparency.
 *  Step 4  Holders call claimProfit() — entitlement is calculated
 *          using a CUMULATIVE PROFIT-PER-TOKEN model so that buyers
 *          who enter AFTER a deposit cannot claim past profit.
 *          (This directly addresses the critical limitation the
 *           report acknowledges in Section 3.4.)
 *  Step 5  Governance: holders propose and vote on major strategic
 *          matters using ERC20Votes snapshot voting to prevent
 *          balance manipulation during a vote.
 *
 *  NEW FEATURES (beyond basic ERC-20)
 *  ------------------------------------
 *  emergencyPause()      — report Section 5: technical risk mitigation
 *  getProposalState()    — report Section 6: on-chain transparency
 *  getTotalDistributed() — report Section 4: investor price discovery
 *  KYC whitelist         — report Section 4: regulatory compliance
 *
 *  TOKEN PARAMETERS
 *  ----------------
 *  Name:         Data Center Token
 *  Symbol:       DCT
 *  Decimals:     18
 *  Fixed supply: 10,000,000 DCT  (10_000_000 * 10**18)
 *  Payout token: USDC on Sepolia testnet
 *                0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
 *
 *  DEPLOY PARAMETERS (Remix)
 *  -------------------------
 *  initialHolder : your wallet address
 *  fixedSupply   : 10000000000000000000000000
 *  payoutToken_  : 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
 *  manager_      : your wallet address
 *  operator_     : your second wallet (or same for testnet)
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

contract DataCenterToken is
    ERC20,
    ERC20Permit,
    ERC20Votes,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    // ================================================================
    // CUSTOM ERRORS — replaces require strings to reduce bytecode size
    // ================================================================
    error DCT_NotManagerOrOwner();
    error DCT_ProposalNotExist();
    error DCT_InvalidAddress();
    error DCT_InvalidSupply();
    error DCT_VotingPeriodTooShort();
    error DCT_AmountZero();
    error DCT_NoSupply();
    error DCT_NoProfitToClaim();
    error DCT_EmptyDescription();
    error DCT_InsufficientVotingPower();
    error DCT_VotingNotStarted();
    error DCT_VotingEnded();
    error DCT_AlreadyVoted();
    error DCT_OperatorBarred();
    error DCT_NoVotingPower();
    error DCT_VotingStillActive();
    error DCT_AlreadyExecuted();
    error DCT_TransfersPaused();
    error DCT_NotKYCApproved();
    error DCT_ZeroAddress();

    // ================================================================
    // SECTION A — CORE PARAMETERS
    // ================================================================

    /// @notice Stablecoin used for profit distributions (USDC on Sepolia testnet).
    IERC20 public immutable payoutToken;

    /// @notice Authorised SPV manager that deposits audited distributable profit.
    address public manager;

    /// @notice Professional operating company address.
    /// Barred from voting on operator-related proposals (report Section 5).
    address public operator;

    // ================================================================
    // SECTION B — KYC WHITELIST
    // ================================================================
    /*
     *  Report Section 4 explicitly states:
     *  "KYC-gated trading venues or transfer restrictions" would apply
     *  because DCT gives holders an expectation of profit derived from
     *  the efforts of others, making it likely a security in most
     *  jurisdictions.
     *
     *  This whitelist enforces that tokens can only be transferred to
     *  KYC-approved addresses, implementing the compliance control
     *  described in the report's market access design.
     *
     *  address(0) is always whitelisted to allow burns.
     *  The contract itself is always whitelisted to allow deposits.
     *  The initialHolder is whitelisted in the constructor.
     */
    mapping(address => bool) public kycApproved;

    // ================================================================
    // SECTION C — PROFIT DISTRIBUTION (Cumulative per-token model)
    // ================================================================
    /*
     *  WHY THIS MODEL?
     *  Report Section 3.4 identifies a critical flaw in naive dividend
     *  contracts: a buyer entering AFTER a deposit could claim profit
     *  they did not earn. The magnified cumulative model fixes this.
     *
     *  - magnifiedProfitPerShare grows with every deposit.
     *  - On every token movement, each address's correction term is
     *    adjusted so entitlement reflects only profit deposited WHILE
     *    that address held the tokens.
     *
     *  OVERFLOW NOTE
     *  Intermediate products (magnifiedProfitPerShare * balance) are
     *  designed to overflow and cancel correctly within unchecked blocks.
     *  This is the standard pattern in production dividend contracts.
     */
    uint256 private constant MAGNITUDE = 2 ** 128;

    /// @notice Cumulative USDC-per-DCT accumulator (scaled by MAGNITUDE).
    uint256 public magnifiedProfitPerShare;

    /// @notice Total USDC ever deposited across all distribution rounds.
    /// Supports report Section 4: investor price discovery and transparency.
    uint256 public totalDistributed;

    mapping(address => int256)  private magnifiedProfitCorrections;
    mapping(address => uint256) public  withdrawnProfit;

    /// @notice On-chain record of each annual profit distribution round.
    struct ProfitRound {
        uint256 id;
        uint256 amount;      // USDC deposited (6-decimal units)
        uint256 timestamp;   // block.timestamp of deposit
        uint256 fiscalYear;  // e.g. 2025
        bytes32 auditHash;   // keccak256 of off-chain audit report
        string  memo;        // e.g. "FY2025 annual distribution"
    }

    uint256 public nextProfitRoundId;
    mapping(uint256 => ProfitRound) public profitRounds;

    // ================================================================
    // SECTION D — GOVERNANCE
    // ================================================================
    /*
     *  Covers the six major strategic matters in report Section 3.2.
     *  Uses ERC20Votes snapshot voting (getPastVotes at snapshotBlock)
     *  to prevent manipulation through transfers during the vote.
     *
     *  COI guard (report Section 5): operator blocked from voting on
     *  any proposal marked operatorRelated = true.
     */

    enum ProposalType {
        OperatorReplacement,   // report: "replacement of the operating company"
        CapacityExpansion,     // report: "significant capacity expansion"
        ReservePolicyChange,   // report: "whether some annual profit should be retained"
        MajorRepairProgram,    // report: "exceptional repair programmes"
        NewBusinessLine,       // report: "introduction of new business lines"
        WholeProjectSale,      // report: "decisions over sale of the whole project"
        Other
    }

    /// @notice Human-readable state of a governance proposal.
    /// Supports report Section 6: on-chain transparency.
    enum ProposalState {
        Active,    // voting window is open
        Passed,    // voting ended, quorum met, forVotes > againstVotes
        Failed,    // voting ended, quorum not met OR againstVotes >= forVotes
        Executed   // outcome recorded on-chain by owner
    }

    struct Proposal {
        uint256      id;
        address      proposer;
        ProposalType proposalType;
        string       description;
        bytes32      metadataHash;    // optional hash of off-chain document
        uint256      snapshotBlock;   // ERC20Votes snapshot block
        uint256      startTime;
        uint256      endTime;
        uint256      forVotes;
        uint256      againstVotes;
        bool         executed;
        bool         operatorRelated; // triggers COI guard when true
    }

    /// @notice 1% of fixed supply required to create a proposal (100,000 DCT).
    uint256 public proposalThreshold = 100_000 * 10 ** 18;

    /// @notice 10% of fixed supply must vote for quorum (1,000,000 DCT).
    uint256 public quorum = 1_000_000 * 10 ** 18;

    /// @notice Default voting window — updatable by owner.
    uint256 public votingPeriod = 7 days;

    uint256 public nextProposalId;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // ================================================================
    // SECTION E — EVENTS
    // ================================================================

    event ManagerUpdated(address indexed oldManager, address indexed newManager);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event GovernanceParametersUpdated(
        uint256 newProposalThreshold,
        uint256 newQuorum,
        uint256 newVotingPeriod
    );
    event KycStatusUpdated(address indexed account, bool approved);
    event ProfitDeposited(
        uint256 indexed roundId,
        uint256 indexed fiscalYear,
        uint256         amount,
        bytes32         auditHash,
        string          memo
    );
    event ProfitClaimed(address indexed account, uint256 amount);
    event ProposalCreated(
        uint256      indexed proposalId,
        address      indexed proposer,
        ProposalType         proposalType,
        bool                 operatorRelated,
        uint256              snapshotBlock,
        uint256              startTime,
        uint256              endTime,
        string               description
    );
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool            support,
        uint256         weight
    );
    event ProposalExecuted(
        uint256 indexed proposalId,
        bool            passed,
        uint256         forVotes,
        uint256         againstVotes
    );

    // ================================================================
    // SECTION F — MODIFIERS
    // ================================================================

    modifier onlyManagerOrOwner() {
        if (msg.sender != manager && msg.sender != owner()) revert DCT_NotManagerOrOwner();
        _;
    }

    /// @dev Revert if proposalId has never been created.
    modifier proposalExists(uint256 proposalId) {
        if (proposalId >= nextProposalId) revert DCT_ProposalNotExist();
        _;
    }

    // ================================================================
    // SECTION G — CONSTRUCTOR
    // ================================================================

    /**
     * @param initialHolder  SPV treasury wallet — receives all DCT for primary sale.
     * @param fixedSupply    10000000000000000000000000  (10M * 10^18)
     * @param payoutToken_   Sepolia USDC: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
     * @param manager_       Authorised SPV manager wallet.
     * @param operator_      Professional operating company wallet.
     */
    constructor(
        address initialHolder,
        uint256 fixedSupply,
        address payoutToken_,
        address manager_,
        address operator_
    )
        ERC20("Data Center Token", "DCT")
        ERC20Permit("Data Center Token")
        Ownable(msg.sender)
    {
        if (initialHolder == address(0)) revert DCT_InvalidAddress();
        if (payoutToken_ == address(0)) revert DCT_InvalidAddress();
        if (manager_ == address(0)) revert DCT_InvalidAddress();
        if (operator_ == address(0)) revert DCT_InvalidAddress();
        if (fixedSupply == 0) revert DCT_InvalidSupply();

        payoutToken = IERC20(payoutToken_);
        manager     = manager_;
        operator    = operator_;

        // KYC-approve the initial holder and this contract on deployment
        kycApproved[initialHolder]    = true;
        kycApproved[address(this)]    = true;
        kycApproved[owner()]          = true;

        // Mint entire fixed supply to SPV treasury for primary investor sale
        _mint(initialHolder, fixedSupply);

        // Auto-delegate so initialHolder has voting power immediately
        _delegate(initialHolder, initialHolder);
    }

    // ================================================================
    // SECTION H — ADMIN FUNCTIONS
    // ================================================================

    /// @notice Replace the authorised SPV manager wallet.
    function updateManager(address newManager) external onlyOwner {
        if (newManager == address(0)) revert DCT_InvalidAddress();
        address old = manager;
        manager = newManager;
        emit ManagerUpdated(old, newManager);
    }

    /// @notice Replace the operator after a successful governance vote.
    /// Matches report Section 3.2: "replacement of the operating company".
    function updateOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert DCT_InvalidAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /// @notice Update governance parameters. Emits event for transparency.
    function updateGovernanceParameters(
        uint256 newProposalThreshold,
        uint256 newQuorum,
        uint256 newVotingPeriod
    ) external onlyOwner {
        if (newVotingPeriod < 1 days) revert DCT_VotingPeriodTooShort();
        proposalThreshold = newProposalThreshold;
        quorum            = newQuorum;
        votingPeriod      = newVotingPeriod;
        emit GovernanceParametersUpdated(newProposalThreshold, newQuorum, newVotingPeriod);
    }

    /// @notice Delegate voting power to yourself.
    /// All holders must call this before their votes count.
    function delegateToSelf() external {
        _delegate(msg.sender, msg.sender);
    }

    // ================================================================
    // SECTION I — EMERGENCY PAUSE
    // ================================================================
    /*
     *  Report Section 5 (Technical Risk):
     *  "Smart contracts may contain vulnerabilities, payout logic may
     *  be flawed, and governance systems may be exploitable."
     *
     *  If a vulnerability is discovered, the owner can immediately pause
     *  all token transfers and profit claims, preventing further loss
     *  while the issue is investigated and fixed.
     *
     *  Pause affects: transfer(), transferFrom(), claimProfit()
     *  Pause does NOT affect: view functions, governance voting
     */

    /// @notice Halt all token transfers and profit claims immediately.
    /// Use only if a critical vulnerability is discovered (report Section 5).
    function emergencyPause() external onlyOwner {
        _pause();
    }

    /// @notice Resume normal operations after the issue is resolved.
    function unpause() external onlyOwner {
        _unpause();
    }

    // ================================================================
    // SECTION J — KYC WHITELIST
    // ================================================================
    /*
     *  Report Section 4 (Market Access and Liquidity Design):
     *  "Because DCT gives holders an expectation of profit derived
     *  largely from the efforts of others, it would likely be treated
     *  as a security or investment instrument in many jurisdictions.
     *  This would imply disclosure obligations, investor-protection
     *  measures, and potentially KYC-gated market access or transfer
     *  restrictions."
     *
     *  This whitelist ensures tokens can only be transferred to
     *  addresses that have completed KYC verification off-chain.
     *  The owner (SPV) manages approvals based on off-chain KYC records.
     *
     *  Exemptions (always allowed):
     *  - address(0): burn operations
     *  - address(this): contract receives nothing in normal flow
     */

    /**
     * @notice Approve or revoke KYC status for an address.
     *         Only KYC-approved addresses can receive DCT transfers.
     * @param  account  The address to update.
     * @param  approved True to approve, false to revoke.
     */
    function setKycStatus(address account, bool approved) external onlyOwner {
        if (account == address(0)) revert DCT_ZeroAddress();
        kycApproved[account] = approved;
        emit KycStatusUpdated(account, approved);
    }

    /**
     * @notice Batch KYC approval for multiple addresses at once.
     *         Saves gas and time during primary issuance onboarding.
     * @param  accounts  Array of addresses to approve.
     */
    function batchSetKycApproved(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] == address(0)) revert DCT_ZeroAddress();
            kycApproved[accounts[i]] = true;
            emit KycStatusUpdated(accounts[i], true);
        }
    }

    // ================================================================
    // SECTION K — PROFIT DISTRIBUTION
    // ================================================================

    /**
     * @notice  Manager deposits audited distributable profit in USDC.
     *
     *          Implements report Section 3.4 Steps 2 and 3.
     *          The manager must physically transfer USDC into the
     *          contract and register the round on-chain with an audit
     *          hash. They cannot merely announce a dividend informally.
     *
     * @dev     IMPORTANT: Manager must call USDC.approve(contractAddress, amount)
     *          before calling this — safeTransferFrom will revert without approval.
     *
     * @param   amount      USDC amount in base units (6 decimals).
     * @param   fiscalYear  Fiscal year this covers, e.g. 2025.
     * @param   auditHash   keccak256 of the off-chain audit report or board resolution.
     * @param   memo        Human-readable label, e.g. "FY2025 annual distribution".
     */
    function depositDistributableProfit(
        uint256 amount,
        uint256 fiscalYear,
        bytes32 auditHash,
        string calldata memo
    ) external onlyManagerOrOwner nonReentrant whenNotPaused {
        if (amount == 0) revert DCT_AmountZero();
        if (totalSupply() == 0) revert DCT_NoSupply();

        // Pull USDC from caller into this contract
        payoutToken.safeTransferFrom(msg.sender, address(this), amount);

        // Accumulate profit-per-token (scaled by MAGNITUDE for precision)
        magnifiedProfitPerShare += (amount * MAGNITUDE) / totalSupply();

        // Track cumulative total for getTotalDistributed() transparency
        totalDistributed += amount;

        // Record this round permanently on-chain
        uint256 roundId = nextProfitRoundId++;
        profitRounds[roundId] = ProfitRound({
            id:         roundId,
            amount:     amount,
            timestamp:  block.timestamp,
            fiscalYear: fiscalYear,
            auditHash:  auditHash,
            memo:       memo
        });

        emit ProfitDeposited(roundId, fiscalYear, amount, auditHash, memo);
    }

    /**
     * @notice  Holder claims all accumulated USDC profit not yet withdrawn.
     *
     *          Implements report Section 3.4 Step 4.
     *          Only profit deposited WHILE the caller held tokens is
     *          claimable. Late buyers cannot claim past distributions.
     *          Blocked when contract is paused (emergency safety).
     */
    function claimProfit() external nonReentrant whenNotPaused {
        uint256 claimable = claimableProfitOf(msg.sender);
        if (claimable == 0) revert DCT_NoProfitToClaim();

        // CEI: state update before external call
        withdrawnProfit[msg.sender] += claimable;
        payoutToken.safeTransfer(msg.sender, claimable);

        emit ProfitClaimed(msg.sender, claimable);
    }

    /**
     * @notice  Total USDC ever deposited across all profit rounds.
     *
     *          Report Section 4: supports investor price discovery and
     *          fundamental valuation of the token in secondary markets.
     */
    function getTotalDistributed() public view returns (uint256) {
        return totalDistributed;
    }

    /**
     * @notice  Total USDC profit ever accumulated by an account
     *          (including amounts already withdrawn).
     */
    function accumulativeProfitOf(address account) public view returns (uint256) {
        unchecked {
            int256 magnified = int256(magnifiedProfitPerShare * balanceOf(account))
                + magnifiedProfitCorrections[account];
            if (magnified < 0) return 0;
            return uint256(magnified) / MAGNITUDE;
        }
    }

    /**
     * @notice  USDC profit available to claim right now (not yet withdrawn).
     */
    function claimableProfitOf(address account) public view returns (uint256) {
        uint256 accumulated      = accumulativeProfitOf(account);
        uint256 alreadyWithdrawn = withdrawnProfit[account];
        if (accumulated <= alreadyWithdrawn) return 0;
        return accumulated - alreadyWithdrawn;
    }

    // ================================================================
    // SECTION L — GOVERNANCE
    // ================================================================

    /**
     * @notice  Create a governance proposal on a major strategic matter.
     *
     *          Caller needs at least proposalThreshold delegated voting
     *          power (default 1% = 100,000 DCT).
     *
     * @param   proposalType    Category from the six matters in report Section 3.2.
     * @param   description     Plain-text description (must be non-empty).
     * @param   metadataHash    Optional keccak256 of off-chain supporting document.
     * @param   operatorRelated True if this concerns the operator — triggers
     *                          the COI guard (report Section 5).
     */
    function createProposal(
        ProposalType proposalType,
        string calldata description,
        bytes32 metadataHash,
        bool operatorRelated
    ) external returns (uint256) {
        if (bytes(description).length == 0) revert DCT_EmptyDescription();
        if (getVotes(msg.sender) < proposalThreshold) revert DCT_InsufficientVotingPower();

        uint256 proposalId    = nextProposalId++;
        uint256 snapshotBlock = block.number - 1;

        // Store directly — avoids extra local variables that cause stack-too-deep
        proposals[proposalId] = Proposal({
            id:              proposalId,
            proposer:        msg.sender,
            proposalType:    proposalType,
            description:     description,
            metadataHash:    metadataHash,
            snapshotBlock:   snapshotBlock,
            startTime:       block.timestamp,
            endTime:         block.timestamp + votingPeriod,
            forVotes:        0,
            againstVotes:    0,
            executed:        false,
            operatorRelated: operatorRelated
        });

        // Read back from storage for emit — keeps stack depth minimal
        Proposal storage p = proposals[proposalId];
        emit ProposalCreated(
            proposalId, msg.sender, proposalType, operatorRelated,
            snapshotBlock, p.startTime, p.endTime, description
        );

        return proposalId;
    }

    /**
     * @notice  Cast a token-weighted vote on an active proposal.
     *
     *          Weight = getPastVotes(voter, snapshotBlock) — balance at
     *          proposal creation, NOT current balance. Prevents vote
     *          manipulation through transfers during the voting window.
     *
     *          COI guard: operator rejected on operatorRelated proposals
     *          (report Section 5: self-dealing risk).
     *
     * @param   proposalId  Target proposal ID.
     * @param   support     true = FOR, false = AGAINST.
     */
    function castVote(uint256 proposalId, bool support)
        external
        proposalExists(proposalId)
    {
        Proposal storage p = proposals[proposalId];

        if (block.timestamp < p.startTime) revert DCT_VotingNotStarted();
        if (block.timestamp >= p.endTime) revert DCT_VotingEnded();
        if (hasVoted[proposalId][msg.sender]) revert DCT_AlreadyVoted();

        // Conflict-of-interest guard (report Section 5)
        if (p.operatorRelated) {
            if (msg.sender == operator) revert DCT_OperatorBarred();
        }

        uint256 weight = getPastVotes(msg.sender, p.snapshotBlock);
        if (weight == 0) revert DCT_NoVotingPower();

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    /**
     * @notice  Returns the current human-readable state of a proposal.
     *
     *          Report Section 6: provides transparent on-chain status
     *          that investors and block explorers can query directly.
     *
     *          States:
     *          Active   — voting window is open
     *          Passed   — voting ended, quorum met, FOR > AGAINST
     *          Failed   — voting ended, quorum not met OR AGAINST >= FOR
     *          Executed — outcome formally recorded on-chain by owner
     *
     * @param   proposalId  Target proposal ID.
     * @return  ProposalState enum value.
     */
    function getProposalState(uint256 proposalId)
        public
        view
        proposalExists(proposalId)
        returns (ProposalState)
    {
        Proposal storage p = proposals[proposalId];

        if (p.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp < p.endTime) {
            return ProposalState.Active;
        }

        // Voting has ended — check quorum and majority
        uint256 totalCast = p.forVotes + p.againstVotes;
        if (totalCast >= quorum && p.forVotes > p.againstVotes) {
            return ProposalState.Passed;
        }

        return ProposalState.Failed;
    }

    /**
     * @notice  Returns true if a proposal has passed.
     *          Conditions: voting ended + quorum met + forVotes > againstVotes.
     */
    function proposalPassed(uint256 proposalId)
        public
        view
        proposalExists(proposalId)
        returns (bool)
    {
        ProposalState state = getProposalState(proposalId);
        return state == ProposalState.Passed || state == ProposalState.Executed;
    }

    /**
     * @notice  Owner records the outcome of a completed proposal on-chain.
     *
     *          "Signalling governance": the on-chain record is the
     *          authoritative outcome reference, but real-world
     *          implementation (e.g. replacing the operator) still occurs
     *          through the SPV's legal and contractual structure.
     */
    function executeProposal(uint256 proposalId)
        external
        onlyOwner
        proposalExists(proposalId)
    {
        Proposal storage p = proposals[proposalId];
        if (block.timestamp < p.endTime) revert DCT_VotingStillActive();
        if (p.executed) revert DCT_AlreadyExecuted();

        // Capture pass/fail result BEFORE marking executed,
        // otherwise getProposalState() would always return Executed.
        bool passed = (getProposalState(proposalId) == ProposalState.Passed);

        p.executed = true;

        emit ProposalExecuted(proposalId, passed, p.forVotes, p.againstVotes);
    }

    // ================================================================
    // SECTION M — INTERNAL HOOKS
    // ================================================================

    /**
     * @dev  Called on every transfer, mint, and burn.
     *       Enforces two things:
     *
     *       1. KYC WHITELIST (report Section 4):
     *          Recipient must be KYC-approved, or address(0) for burns.
     *          Sender restriction is not applied — a holder who loses KYC
     *          status can still transfer out but not receive new tokens.
     *
     *       2. PAUSE CHECK (report Section 5):
     *          whenNotPaused blocks all transfers during emergency.
     *
     *       3. MAGNIFIED PROFIT CORRECTIONS:
     *          Maintains fair entitlement accounting across all movements.
     *          unchecked blocks are intentional — see OVERFLOW NOTE above.
     */
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        // Pause check: block all transfers when paused (except minting in constructor)
        if (from != address(0)) {
            if (paused()) revert DCT_TransfersPaused();
        }

        // KYC check: recipient must be approved (burns to address(0) always allowed)
        if (to != address(0)) {
            if (!kycApproved[to]) revert DCT_NotKYCApproved();
        }

        // Magnified profit correction accounting
        unchecked {
            if (from == address(0)) {
                // Mint: new tokens carry zero entitlement to past profit
                magnifiedProfitCorrections[to] -= int256(magnifiedProfitPerShare * value);
            } else if (to == address(0)) {
                // Burn: remove entitlement for burned tokens
                magnifiedProfitCorrections[from] += int256(magnifiedProfitPerShare * value);
            } else {
                // Transfer: sender loses entitlement, recipient starts fresh
                int256 correction = int256(magnifiedProfitPerShare * value);
                magnifiedProfitCorrections[from] += correction;
                magnifiedProfitCorrections[to]   -= correction;
            }
        }

        super._update(from, to, value);
    }

    // ================================================================
    // SECTION N — REQUIRED OVERRIDE (OZ v5 multiple inheritance)
    // ================================================================

    /// @dev Resolves nonces() ambiguity between ERC20Permit and Nonces.
    function nonces(address owner_)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner_);
    }
}
