pragma solidity ^0.4.21;

import "./EIP20Interface.sol";

/**
 * @title Data Center Revenue Token (DCRT)
 * @notice ERC-20 fungible token representing a proportional claim on the
 *         distributable profit of a sovereign data centre SPV.
 *         Based on the EIP20 reference implementation (course material).
 *
 * Design summary (from report):
 *  - Fixed supply: 10,000,000 DCRT (18 decimals)
 *  - All tokens minted to the SPV/issuer on deployment
 *  - Annual profit distribution in a stablecoin (simulated here with ETH for testnet)
 *  - Governance: token-weighted voting on major proposals
 *  - Conflict-of-interest guard: operator address cannot vote on operator-related proposals
 *  - Owner can update the operator address
 */
contract DCRT is EIP20Interface {

    // -----------------------------------------------------------------------
    // ERC-20 state (mirrors EIP20 reference implementation)
    // -----------------------------------------------------------------------

    uint256 constant private MAX_UINT256 = 2**256 - 1;

    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowed;

    string  public name;        // "Data Center Revenue Token"
    uint8   public decimals;    // 18
    string  public symbol;      // "DCRT"

    // -----------------------------------------------------------------------
    // DCRT-specific state
    // -----------------------------------------------------------------------

    address public owner;       // SPV / issuer
    address public operator;    // Professional operating company

    // --- Profit distribution ---

    // Epoch counter: increments every time a distribution round is opened
    uint256 public currentEpoch;

    struct DistributionRound {
        uint256 totalProfitWei;   // Total ETH (proxy for USDC) deposited for this round
        uint256 snapshotSupply;   // totalSupply at the time of deposit (always fixed here)
        bool    distributed;      // Guard against double-open
    }
    mapping (uint256 => DistributionRound) public rounds;

    // Track how much each address has already claimed per epoch
    mapping (uint256 => mapping (address => bool)) public hasClaimed;

    // --- Governance ---

    uint256 public proposalCount;

    struct Proposal {
        string  description;
        bool    operatorRelated;  // If true, operator address is barred from voting
        uint256 votesFor;
        uint256 votesAgainst;
        bool    executed;
        mapping (address => bool) hasVoted;
    }
    mapping (uint256 => Proposal) public proposals;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event ProfitDeposited(uint256 indexed epoch, uint256 amountWei);
    event ProfitClaimed(uint256 indexed epoch, address indexed holder, uint256 amountWei);
    event ProposalCreated(uint256 indexed proposalId, string description, bool operatorRelated);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, bool passed);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    /**
     * @param _initialAmount  Total token supply (should be 10000000 * 10**18)
     * @param _tokenName      "Data Center Revenue Token"
     * @param _decimalUnits   18
     * @param _tokenSymbol    "DCRT"
     * @param _operator       Address of the professional operating company
     */
    constructor(
        uint256 _initialAmount,
        string  _tokenName,
        uint8   _decimalUnits,
        string  _tokenSymbol,
        address _operator
    ) public {
        owner              = msg.sender;
        operator           = _operator;

        balances[msg.sender] = _initialAmount;
        totalSupply          = _initialAmount;
        name                 = _tokenName;
        decimals             = _decimalUnits;
        symbol               = _tokenSymbol;

        currentEpoch = 0;
    }

    // -----------------------------------------------------------------------
    // ERC-20 functions  (identical logic to course EIP20.sol)
    // -----------------------------------------------------------------------

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value);
        balances[msg.sender] -= _value;
        balances[_to]        += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        uint256 _allowance = allowed[_from][msg.sender];
        require(balances[_from] >= _value && _allowance >= _value);
        balances[_to]   += _value;
        balances[_from] -= _value;
        if (_allowance < MAX_UINT256) {
            allowed[_from][msg.sender] -= _value;
        }
        emit Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    // -----------------------------------------------------------------------
    // Profit distribution  (DCRT-specific)
    // -----------------------------------------------------------------------

    /**
     * @notice Owner (SPV) deposits audited annual profit into the contract.
     *         In a real deployment this would pull USDC; here we accept ETH
     *         as a testnet proxy.
     * @dev    Opens a new distribution epoch.
     */
    function depositProfit() public payable onlyOwner {
        require(msg.value > 0);

        currentEpoch += 1;
        rounds[currentEpoch] = DistributionRound({
            totalProfitWei : msg.value,
            snapshotSupply : totalSupply,
            distributed    : true
        });

        emit ProfitDeposited(currentEpoch, msg.value);
    }

    /**
     * @notice Token holders call this to claim their proportional share
     *         of the profit for a given epoch.
     * @param  _epoch  The distribution epoch to claim from.
     */
    function claimProfit(uint256 _epoch) public {
        require(_epoch >= 1 && _epoch <= currentEpoch);
        require(!hasClaimed[_epoch][msg.sender]);
        require(balances[msg.sender] > 0);

        hasClaimed[_epoch][msg.sender] = true;

        DistributionRound storage r = rounds[_epoch];

        // Proportional share: (holderBalance / totalSupply) * totalProfit
        uint256 share = (r.totalProfitWei / r.snapshotSupply) * balances[msg.sender];

        // Guard against rounding dust draining the contract
        require(share > 0);
        require(address(this).balance >= share);

        msg.sender.transfer(share);
        emit ProfitClaimed(_epoch, msg.sender, share);
    }

    // -----------------------------------------------------------------------
    // Governance  (DCRT-specific)
    // -----------------------------------------------------------------------

    /**
     * @notice Any token holder can raise a governance proposal.
     * @param _description     Plain-text description of the proposal.
     * @param _operatorRelated True if this concerns the operator appointment,
     *                         compensation, or renewal (triggers COI guard).
     */
    function createProposal(string _description, bool _operatorRelated)
        public
        returns (uint256 proposalId)
    {
        require(balances[msg.sender] > 0);

        proposalId = proposalCount;
        proposalCount += 1;

        Proposal storage p = proposals[proposalId];
        p.description     = _description;
        p.operatorRelated = _operatorRelated;
        p.votesFor        = 0;
        p.votesAgainst    = 0;
        p.executed        = false;

        emit ProposalCreated(proposalId, _description, _operatorRelated);
    }

    /**
     * @notice Vote on a proposal. Weight = token balance.
     *         Operator is barred from operator-related votes (COI guard).
     * @param _proposalId  ID of the proposal.
     * @param _support     True = vote for; false = vote against.
     */
    function vote(uint256 _proposalId, bool _support) public {
        require(_proposalId < proposalCount);

        Proposal storage p = proposals[_proposalId];
        require(!p.executed);
        require(!p.hasVoted[msg.sender]);
        require(balances[msg.sender] > 0);

        // Conflict-of-interest guard: operator cannot vote on its own matters
        if (p.operatorRelated) {
            require(msg.sender != operator);
        }

        p.hasVoted[msg.sender] = true;
        uint256 weight = balances[msg.sender];

        if (_support) {
            p.votesFor += weight;
        } else {
            p.votesAgainst += weight;
        }

        emit Voted(_proposalId, msg.sender, _support, weight);
    }

    /**
     * @notice Execute a proposal after voting. Simple majority wins.
     *         Only the owner (SPV) executes to mirror real governance process.
     * @param _proposalId  ID of the proposal to execute.
     */
    function executeProposal(uint256 _proposalId) public onlyOwner {
        require(_proposalId < proposalCount);

        Proposal storage p = proposals[_proposalId];
        require(!p.executed);

        p.executed = true;
        bool passed = (p.votesFor > p.votesAgainst);

        emit ProposalExecuted(_proposalId, passed);
    }

    // -----------------------------------------------------------------------
    // Owner administration
    // -----------------------------------------------------------------------

    /**
     * @notice Update the operator address (e.g. after a governance vote
     *         to replace the operating company).
     * @param _newOperator  Address of the new professional operator.
     */
    function updateOperator(address _newOperator) public onlyOwner {
        require(_newOperator != address(0));
        address old = operator;
        operator = _newOperator;
        emit OperatorUpdated(old, _newOperator);
    }

    // -----------------------------------------------------------------------
    // Fallback: accept ETH (for profit top-ups or test funding)
    // -----------------------------------------------------------------------

    function () public payable {}
}
