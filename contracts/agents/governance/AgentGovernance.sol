// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../AgentRegistry.sol";
import "../AgentPerformance.sol";

contract AgentGovernance is AccessControl, ReentrancyGuard {
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant PROPOSAL_MANAGER_ROLE = keccak256("PROPOSAL_MANAGER_ROLE");
    
    AgentRegistry public immutable registry;
    AgentPerformance public immutable performance;
    IERC20 public immutable governanceToken;
    
    struct Proposal {
        bytes32 proposalId;
        address proposer;
        ProposalType proposalType;
        bytes32 targetAgent;
        bytes data;
        uint256 startTime;
        uint256 endTime;
        uint256 yesVotes;
        uint256 noVotes;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
    }
    
    enum ProposalType {
        AgentUpgrade,
        ParameterChange,
        SecurityUpdate,
        RewardAdjustment,
        AgentDeactivation
    }
    
    struct VotingPower {
        uint256 amount;
        uint256 lockTime;
        uint256 multiplier;
    }
    
    // Governance storage
    mapping(bytes32 => Proposal) public proposals;
    mapping(address => VotingPower) public votingPowers;
    mapping(bytes32 => bytes32[]) public agentProposals;
    
    // Governance parameters
    uint256 public proposalThreshold;
    uint256 public votingPeriod;
    uint256 public executionDelay;
    uint256 public quorumPercentage;
    
    // Events
    event ProposalCreated(
        bytes32 indexed proposalId,
        address indexed proposer,
        ProposalType proposalType,
        bytes32 indexed targetAgent
    );
    
    event VoteCast(
        bytes32 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight
    );
    
    event ProposalExecuted(
        bytes32 indexed proposalId,
        bool success
    );
    
    event VotingPowerUpdated(
        address indexed account,
        uint256 amount,
        uint256 multiplier
    );
    
    constructor(
        address _registry,
        address _performance,
        address _governanceToken
    ) {
        registry = AgentRegistry(_registry);
        performance = AgentPerformance(_performance);
        governanceToken = IERC20(_governanceToken);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNOR_ROLE, msg.sender);
        
        // Initialize governance parameters
        proposalThreshold = 100000 * 10**18; // 100,000 tokens
        votingPeriod = 3 days;
        executionDelay = 1 days;
        quorumPercentage = 10; // 10%
    }
    
    function createProposal(
        ProposalType proposalType,
        bytes32 targetAgent,
        bytes calldata data
    ) external returns (bytes32) {
        require(
            governanceToken.balanceOf(msg.sender) >= proposalThreshold,
            "Insufficient tokens"
        );
        
        bytes32 proposalId = generateProposalId(
            msg.sender,
            proposalType,
            targetAgent
        );
        
        Proposal storage proposal = proposals[proposalId];
        proposal.proposalId = proposalId;
        proposal.proposer = msg.sender;
        proposal.proposalType = proposalType;
        proposal.targetAgent = targetAgent;
        proposal.data = data;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + votingPeriod;
        
        agentProposals[targetAgent].push(proposalId);
        
        emit ProposalCreated(proposalId, msg.sender, proposalType, targetAgent);
        return proposalId;
    }
    
    function castVote(
        bytes32 proposalId,
        bool support
    ) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        
        uint256 votingPower = calculateVotingPower(msg.sender);
        require(votingPower > 0, "No voting power");
        
        if (support) {
            proposal.yesVotes += votingPower;
        } else {
            proposal.noVotes += votingPower;
        }
        
        proposal.hasVoted[msg.sender] = true;
        
        emit VoteCast(proposalId, msg.sender, support, votingPower);
    }
    
    function executeProposal(
        bytes32 proposalId
    ) external onlyRole(GOVERNOR_ROLE) nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(canExecuteProposal(proposalId), "Cannot execute");
        
        proposal.executed = true;
        bool success = executeProposalLogic(proposal);
        
        emit ProposalExecuted(proposalId, success);
    }
    
    function updateVotingPower(
        address account,
        uint256 amount,
        uint256 lockTime
    ) external {
        require(amount > 0, "Invalid amount");
        require(
            governanceToken.transferFrom(account, address(this), amount),
            "Transfer failed"
        );
        
        uint256 multiplier = calculateMultiplier(lockTime);
        votingPowers[account] = VotingPower({
            amount: amount,
            lockTime: block.timestamp + lockTime,
            multiplier: multiplier
        });
        
        emit VotingPowerUpdated(account, amount, multiplier);
    }
    
    function getProposalVotes(
        bytes32 proposalId
    ) external view returns (uint256 yes, uint256 no) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.yesVotes, proposal.noVotes);
    }
    
    function getAgentProposals(
        bytes32 agentId
    ) external view returns (bytes32[] memory) {
        return agentProposals[agentId];
    }
    
    // Internal functions
    function generateProposalId(
        address proposer,
        ProposalType proposalType,
        bytes32 targetAgent
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                proposer,
                proposalType,
                targetAgent,
                block.timestamp
            )
        );
    }
    
    function calculateVotingPower(
        address account
    ) internal view returns (uint256) {
        VotingPower storage power = votingPowers[account];
        if (block.timestamp > power.lockTime) return 0;
        return power.amount * power.multiplier / 100;
    }
    
    function calculateMultiplier(
        uint256 lockTime
    ) internal pure returns (uint256) {
        if (lockTime >= 365 days) return 200; // 2x
        if (lockTime >= 180 days) return 150; // 1.5x
        if (lockTime >= 90 days) return 125; // 1.25x
        return 100; // 1x
    }
    
    function canExecuteProposal(
        bytes32 proposalId
    ) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.executed || proposal.canceled) return false;
        if (block.timestamp <= proposal.endTime + executionDelay) return false;
        
        uint256 totalVotes = proposal.yesVotes + proposal.noVotes;
        uint256 totalSupply = governanceToken.totalSupply();
        
        // Check quorum
        if (totalVotes * 100 < totalSupply * quorumPercentage) return false;
        
        // Check majority
        return proposal.yesVotes > proposal.noVotes;
    }
    
    function executeProposalLogic(
        Proposal storage proposal
    ) internal returns (bool) {
        if (proposal.proposalType == ProposalType.AgentUpgrade) {
            // Handle agent upgrade
            return handleAgentUpgrade(proposal);
        } else if (proposal.proposalType == ProposalType.ParameterChange) {
            // Handle parameter change
            return handleParameterChange(proposal);
        } else if (proposal.proposalType == ProposalType.SecurityUpdate) {
            // Handle security update
            return handleSecurityUpdate(proposal);
        } else if (proposal.proposalType == ProposalType.RewardAdjustment) {
            // Handle reward adjustment
            return handleRewardAdjustment(proposal);
        } else if (proposal.proposalType == ProposalType.AgentDeactivation) {
            // Handle agent deactivation
            return handleAgentDeactivation(proposal);
        }
        
        return false;
    }
    
    // Proposal execution handlers
    function handleAgentUpgrade(
        Proposal storage proposal
    ) internal returns (bool) {
        // Implementation for agent upgrade
        return true;
    }
    
    function handleParameterChange(
        Proposal storage proposal
    ) internal returns (bool) {
        // Implementation for parameter change
        return true;
    }
    
    function handleSecurityUpdate(
        Proposal storage proposal
    ) internal returns (bool) {
        // Implementation for security update
        return true;
    }
    
    function handleRewardAdjustment(
        Proposal storage proposal
    ) internal returns (bool) {
        // Implementation for reward adjustment
        return true;
    }
    
    function handleAgentDeactivation(
        Proposal storage proposal
    ) internal returns (bool) {
        // Implementation for agent deactivation
        return true;
    }
}
