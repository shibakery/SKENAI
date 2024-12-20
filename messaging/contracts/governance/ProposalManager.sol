// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./TokenGate.sol";

/**
 * @title ProposalManager
 * @dev Manages proposal creation, discussion, and voting
 */
contract ProposalManager is Ownable, ReentrancyGuard {
    TokenGate public tokenGate;
    
    // Proposal states
    enum ProposalState {
        Draft,
        Active,
        Voting,
        Completed,
        Cancelled
    }
    
    // Proposal structure
    struct Proposal {
        uint256 id;
        address creator;
        string title;
        string description;
        uint256 createdAt;
        uint256 votingStartTime;
        uint256 votingEndTime;
        ProposalState state;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 discussionCount;
        mapping(address => bool) hasVoted;
        mapping(uint256 => Discussion) discussions;
    }
    
    // Discussion structure
    struct Discussion {
        uint256 id;
        address author;
        string content;
        uint256 timestamp;
        uint256 upvotes;
        uint256 downvotes;
        mapping(address => bool) hasVoted;
    }
    
    // Storage
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    
    // Configuration
    uint256 public constant DISCUSSION_THRESHOLD = 100 ether; // 100 tokens to start discussion
    uint256 public constant PROPOSAL_THRESHOLD = 1000 ether;  // 1000 tokens to create proposal
    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant DISCUSSION_PERIOD = 3 days;
    
    // Events
    event ProposalCreated(uint256 indexed proposalId, address indexed creator);
    event DiscussionAdded(uint256 indexed proposalId, uint256 discussionId, address indexed author);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support);
    event DiscussionVoted(uint256 indexed proposalId, uint256 discussionId, address indexed voter, bool support);
    event ProposalStateChanged(uint256 indexed proposalId, ProposalState newState);
    
    constructor(address _tokenGate) {
        tokenGate = TokenGate(_tokenGate);
    }
    
    /**
     * @dev Creates a new proposal
     */
    function createProposal(
        string memory title,
        string memory description
    ) external nonReentrant returns (uint256) {
        require(
            tokenGate.getUserAccessLevel(msg.sender) >= 2,
            "Insufficient access level"
        );
        
        uint256 proposalId = ++proposalCount;
        Proposal storage proposal = proposals[proposalId];
        
        proposal.id = proposalId;
        proposal.creator = msg.sender;
        proposal.title = title;
        proposal.description = description;
        proposal.createdAt = block.timestamp;
        proposal.state = ProposalState.Draft;
        
        emit ProposalCreated(proposalId, msg.sender);
        return proposalId;
    }
    
    /**
     * @dev Adds a discussion to a proposal
     */
    function addDiscussion(
        uint256 proposalId,
        string memory content
    ) external nonReentrant {
        require(
            tokenGate.meetsMinimumRequirements(msg.sender),
            "Insufficient access"
        );
        
        Proposal storage proposal = proposals[proposalId];
        require(
            proposal.state == ProposalState.Draft ||
            proposal.state == ProposalState.Active,
            "Proposal not open for discussion"
        );
        
        uint256 discussionId = ++proposal.discussionCount;
        Discussion storage discussion = proposal.discussions[discussionId];
        
        discussion.id = discussionId;
        discussion.author = msg.sender;
        discussion.content = content;
        discussion.timestamp = block.timestamp;
        
        emit DiscussionAdded(proposalId, discussionId, msg.sender);
    }
    
    /**
     * @dev Casts a vote on a proposal
     */
    function castVote(uint256 proposalId, bool support) external nonReentrant {
        require(
            tokenGate.meetsMinimumRequirements(msg.sender),
            "Insufficient access"
        );
        
        Proposal storage proposal = proposals[proposalId];
        require(
            proposal.state == ProposalState.Voting,
            "Proposal not in voting state"
        );
        require(
            !proposal.hasVoted[msg.sender],
            "Already voted"
        );
        
        proposal.hasVoted[msg.sender] = true;
        
        if (support) {
            proposal.forVotes++;
        } else {
            proposal.againstVotes++;
        }
        
        emit VoteCast(proposalId, msg.sender, support);
    }
    
    /**
     * @dev Activates a proposal for discussion
     */
    function activateProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.creator ||
            tokenGate.getUserAccessLevel(msg.sender) >= 2,
            "Unauthorized"
        );
        require(
            proposal.state == ProposalState.Draft,
            "Invalid state"
        );
        
        proposal.state = ProposalState.Active;
        emit ProposalStateChanged(proposalId, ProposalState.Active);
    }
    
    /**
     * @dev Starts the voting period for a proposal
     */
    function startVoting(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.creator ||
            tokenGate.getUserAccessLevel(msg.sender) >= 2,
            "Unauthorized"
        );
        require(
            proposal.state == ProposalState.Active,
            "Invalid state"
        );
        require(
            block.timestamp >= proposal.createdAt + DISCUSSION_PERIOD,
            "Discussion period not ended"
        );
        
        proposal.state = ProposalState.Voting;
        proposal.votingStartTime = block.timestamp;
        proposal.votingEndTime = block.timestamp + VOTING_DURATION;
        
        emit ProposalStateChanged(proposalId, ProposalState.Voting);
    }
    
    /**
     * @dev Completes a proposal after voting period
     */
    function completeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(
            proposal.state == ProposalState.Voting,
            "Not in voting state"
        );
        require(
            block.timestamp >= proposal.votingEndTime,
            "Voting period not ended"
        );
        
        proposal.state = ProposalState.Completed;
        emit ProposalStateChanged(proposalId, ProposalState.Completed);
    }
    
    /**
     * @dev Gets proposal details
     */
    function getProposal(uint256 proposalId) external view returns (
        address creator,
        string memory title,
        string memory description,
        uint256 createdAt,
        ProposalState state,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 discussionCount
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.creator,
            proposal.title,
            proposal.description,
            proposal.createdAt,
            proposal.state,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.discussionCount
        );
    }
}
