// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../agents/AgentRegistry.sol";
import "../tokens/SBXToken.sol";

contract AgentGovernance is AccessControl, ReentrancyGuard {
    bytes32 public constant GOVERNANCE_ADMIN_ROLE = keccak256("GOVERNANCE_ADMIN_ROLE");
    bytes32 public constant PROPOSAL_MANAGER_ROLE = keccak256("PROPOSAL_MANAGER_ROLE");
    
    AgentRegistry public immutable registry;
    SBXToken public immutable votingToken;
    
    struct Proposal {
        uint256 proposalId;
        bytes32 proposer;
        string title;
        string description;
        bytes32[] targetAgents;
        ProposalType proposalType;
        uint256 startTime;
        uint256 endTime;
        uint256 requiredQuorum;
        uint256 approvalThreshold;
        bool executed;
        bool canceled;
        mapping(bytes32 => Vote) votes;
        uint256 totalVotes;
        uint256 approvalVotes;
        uint256 rejectionVotes;
    }
    
    struct Vote {
        bool hasVoted;
        bool support;
        uint256 weight;
        string justification;
    }
    
    struct DelegationInfo {
        bytes32 delegator;
        bytes32 delegate;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        bool active;
    }
    
    struct GovernanceMetrics {
        uint256 proposalsCreated;
        uint256 proposalsApproved;
        uint256 proposalsRejected;
        uint256 totalVotesCast;
        uint256 participationRate;
        mapping(bytes32 => uint256) agentInfluence;
    }
    
    enum ProposalType {
        AgentUpgrade,
        ProtocolChange,
        ParameterUpdate,
        ResourceAllocation,
        SecurityPolicy,
        EmergencyAction
    }
    
    // Storage
    mapping(uint256 => Proposal) public proposals;
    mapping(bytes32 => DelegationInfo[]) public delegations;
    mapping(bytes32 => uint256) public votingPower;
    mapping(bytes32 => GovernanceMetrics) public governanceMetrics;
    
    // Governance parameters
    uint256 public proposalThreshold;
    uint256 public minVotingPeriod;
    uint256 public maxVotingPeriod;
    uint256 public quorumPercentage;
    uint256 public executionDelay;
    
    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        bytes32 indexed proposer,
        string title,
        ProposalType proposalType,
        uint256 startTime,
        uint256 endTime
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        bytes32 indexed voter,
        bool support,
        uint256 weight
    );
    
    event ProposalExecuted(
        uint256 indexed proposalId,
        bytes32 indexed executor,
        uint256 timestamp
    );
    
    event DelegationCreated(
        bytes32 indexed delegator,
        bytes32 indexed delegate,
        uint256 amount,
        uint256 endTime
    );
    
    constructor(
        address _registry,
        address _votingToken
    ) {
        registry = AgentRegistry(_registry);
        votingToken = SBXToken(_votingToken);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNANCE_ADMIN_ROLE, msg.sender);
        _grantRole(PROPOSAL_MANAGER_ROLE, msg.sender);
        
        // Initialize governance parameters
        proposalThreshold = 100 * 10**18;  // 100 tokens
        minVotingPeriod = 3 days;
        maxVotingPeriod = 14 days;
        quorumPercentage = 10;             // 10%
        executionDelay = 2 days;
    }
    
    function createProposal(
        string calldata title,
        string calldata description,
        bytes32[] calldata targetAgents,
        ProposalType proposalType,
        uint256 votingPeriod,
        uint256 requiredQuorum
    ) external returns (uint256) {
        require(
            votingToken.balanceOf(msg.sender) >= proposalThreshold,
            "Insufficient tokens"
        );
        require(
            votingPeriod >= minVotingPeriod && votingPeriod <= maxVotingPeriod,
            "Invalid voting period"
        );
        
        bytes32 proposer = bytes32(uint256(uint160(msg.sender)));
        uint256 proposalId = generateProposalId();
        
        Proposal storage proposal = proposals[proposalId];
        proposal.proposalId = proposalId;
        proposal.proposer = proposer;
        proposal.title = title;
        proposal.description = description;
        proposal.targetAgents = targetAgents;
        proposal.proposalType = proposalType;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + votingPeriod;
        proposal.requiredQuorum = requiredQuorum;
        proposal.approvalThreshold = calculateApprovalThreshold(proposalType);
        
        // Update metrics
        GovernanceMetrics storage metrics = governanceMetrics[proposer];
        metrics.proposalsCreated++;
        
        emit ProposalCreated(
            proposalId,
            proposer,
            title,
            proposalType,
            proposal.startTime,
            proposal.endTime
        );
        
        return proposalId;
    }
    
    function castVote(
        uint256 proposalId,
        bool support,
        string calldata justification
    ) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.executed && !proposal.canceled, "Proposal not active");
        
        bytes32 voter = bytes32(uint256(uint160(msg.sender)));
        require(!proposal.votes[voter].hasVoted, "Already voted");
        
        uint256 weight = calculateVotingWeight(voter);
        require(weight > 0, "No voting power");
        
        Vote storage vote = proposal.votes[voter];
        vote.hasVoted = true;
        vote.support = support;
        vote.weight = weight;
        vote.justification = justification;
        
        if (support) {
            proposal.approvalVotes += weight;
        } else {
            proposal.rejectionVotes += weight;
        }
        proposal.totalVotes += weight;
        
        // Update metrics
        GovernanceMetrics storage metrics = governanceMetrics[voter];
        metrics.totalVotesCast++;
        metrics.participationRate = (metrics.totalVotesCast * 100) / 
            getTotalProposals();
        
        emit VoteCast(proposalId, voter, support, weight);
    }
    
    function executeProposal(
        uint256 proposalId
    ) external onlyRole(PROPOSAL_MANAGER_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(
            block.timestamp > proposal.endTime + executionDelay,
            "Execution delay not met"
        );
        require(!proposal.executed && !proposal.canceled, "Invalid proposal state");
        
        require(
            proposal.totalVotes >= calculateQuorum(),
            "Quorum not reached"
        );
        
        uint256 approvalPercentage = (proposal.approvalVotes * 100) / 
            proposal.totalVotes;
        require(
            approvalPercentage >= proposal.approvalThreshold,
            "Approval threshold not met"
        );
        
        proposal.executed = true;
        
        // Update metrics
        GovernanceMetrics storage metrics = governanceMetrics[proposal.proposer];
        metrics.proposalsApproved++;
        
        emit ProposalExecuted(proposalId, msg.sender, block.timestamp);
    }
    
    function createDelegation(
        bytes32 delegate,
        uint256 amount,
        uint256 duration
    ) external {
        require(amount > 0, "Invalid amount");
        require(duration > 0, "Invalid duration");
        require(
            votingToken.balanceOf(msg.sender) >= amount,
            "Insufficient balance"
        );
        
        bytes32 delegator = bytes32(uint256(uint160(msg.sender)));
        
        DelegationInfo memory delegation = DelegationInfo({
            delegator: delegator,
            delegate: delegate,
            amount: amount,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            active: true
        });
        
        delegations[delegator].push(delegation);
        votingPower[delegate] += amount;
        
        emit DelegationCreated(delegator, delegate, amount, delegation.endTime);
    }
    
    // Internal functions
    function generateProposalId() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.number,
            msg.sender
        )));
    }
    
    function calculateApprovalThreshold(
        ProposalType proposalType
    ) internal pure returns (uint256) {
        if (proposalType == ProposalType.EmergencyAction) {
            return 75; // 75% approval required
        } else if (proposalType == ProposalType.SecurityPolicy) {
            return 70; // 70% approval required
        } else {
            return 51; // Simple majority
        }
    }
    
    function calculateVotingWeight(
        bytes32 voter
    ) internal view returns (uint256) {
        uint256 baseWeight = votingToken.balanceOf(address(uint160(uint256(voter))));
        uint256 delegatedWeight = votingPower[voter];
        return baseWeight + delegatedWeight;
    }
    
    function calculateQuorum() internal view returns (uint256) {
        return (votingToken.totalSupply() * quorumPercentage) / 100;
    }
    
    function getTotalProposals() internal view returns (uint256) {
        // Implementation for getting total proposals count
        return 0;
    }
    
    // View functions
    function getProposalDetails(
        uint256 proposalId
    ) external view returns (
        bytes32 proposer,
        string memory title,
        ProposalType proposalType,
        uint256 startTime,
        uint256 endTime,
        uint256 totalVotes,
        uint256 approvalVotes,
        uint256 rejectionVotes,
        bool executed,
        bool canceled
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.title,
            proposal.proposalType,
            proposal.startTime,
            proposal.endTime,
            proposal.totalVotes,
            proposal.approvalVotes,
            proposal.rejectionVotes,
            proposal.executed,
            proposal.canceled
        );
    }
    
    function getVoteDetails(
        uint256 proposalId,
        bytes32 voter
    ) external view returns (
        bool hasVoted,
        bool support,
        uint256 weight,
        string memory justification
    ) {
        Vote storage vote = proposals[proposalId].votes[voter];
        return (
            vote.hasVoted,
            vote.support,
            vote.weight,
            vote.justification
        );
    }
    
    function getGovernanceMetrics(
        bytes32 agent
    ) external view returns (
        uint256 proposalsCreated,
        uint256 proposalsApproved,
        uint256 proposalsRejected,
        uint256 totalVotesCast,
        uint256 participationRate
    ) {
        GovernanceMetrics storage metrics = governanceMetrics[agent];
        return (
            metrics.proposalsCreated,
            metrics.proposalsApproved,
            metrics.proposalsRejected,
            metrics.totalVotesCast,
            metrics.participationRate
        );
    }
}
