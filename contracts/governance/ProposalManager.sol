// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../tokens/SBXToken.sol";
import "../tokens/ISHIBAKToken.sol";
import "../tokens/SBVToken.sol";
import "../engagement/CommunityEngagement.sol";

contract ProposalManager is AccessControl, ReentrancyGuard {
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    
    SBXToken public sbxToken;
    ISHIBAKToken public shibakToken;
    SBVToken public sbvToken;
    CommunityEngagement public engagement;
    
    enum Track { Genesis, Fractal, Options, Research, Community, Encyclic }
    enum Status { Draft, Active, Completed, Failed, Cancelled }
    
    struct Proposal {
        uint256 id;
        Track track;
        uint256 level;
        string series;
        address proposer;
        uint256 budget;
        uint256 startTime;
        uint256 duration;
        Status status;
        uint256 votesFor;
        uint256 votesAgainst;
        mapping(address => bool) hasVoted;
    }
    
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    
    // Track-specific requirements
    mapping(Track => uint256) public minStake;
    mapping(Track => uint256) public minEngagement;
    mapping(Track => uint256) public minValue;
    
    event ProposalCreated(
        uint256 indexed id,
        Track track,
        uint256 level,
        string series,
        address proposer
    );
    event ProposalVoted(
        uint256 indexed id,
        address voter,
        bool support,
        uint256 weight
    );
    event ProposalExecuted(uint256 indexed id, Status status);
    
    constructor(
        address _sbxToken,
        address _shibakToken,
        address _sbvToken,
        address _engagement
    ) {
        sbxToken = SBXToken(_sbxToken);
        shibakToken = ISHIBAKToken(_shibakToken);
        sbvToken = SBVToken(_sbvToken);
        engagement = CommunityEngagement(_engagement);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        
        // Set initial requirements
        minStake[Track.Genesis] = 10000 * 10**18;    // 10,000 SBX
        minStake[Track.Fractal] = 5000 * 10**18;     // 5,000 SBX
        minStake[Track.Options] = 7500 * 10**18;     // 7,500 SBX
        minStake[Track.Research] = 5000 * 10**18;    // 5,000 SBX
        minStake[Track.Community] = 2500 * 10**18;   // 2,500 SBX
        minStake[Track.Encyclic] = 1000 * 10**18;    // 1,000 SBX
        
        minEngagement[Track.Community] = 5000;        // High engagement for Community
        minValue[Track.Options] = 1000 * 10**18;     // Proven value for Options
    }
    
    function createProposal(
        Track track,
        uint256 level,
        string calldata series,
        uint256 budget,
        uint256 duration
    ) external nonReentrant returns (uint256) {
        require(checkEligibility(msg.sender, track), "Not eligible");
        require(budget <= 10000 * 10**18, "Budget too high"); // Max 10k budget
        
        uint256 id = ++proposalCount;
        Proposal storage prop = proposals[id];
        prop.id = id;
        prop.track = track;
        prop.level = level;
        prop.series = series;
        prop.proposer = msg.sender;
        prop.budget = budget;
        prop.startTime = block.timestamp;
        prop.duration = duration;
        prop.status = Status.Active;
        
        emit ProposalCreated(id, track, level, series, msg.sender);
        return id;
    }
    
    function vote(uint256 proposalId, bool support) external nonReentrant {
        Proposal storage prop = proposals[proposalId];
        require(prop.status == Status.Active, "Not active");
        require(!prop.hasVoted[msg.sender], "Already voted");
        require(block.timestamp < prop.startTime + prop.duration, "Voting ended");
        
        uint256 weight = getVotingWeight(msg.sender, prop.track);
        require(weight > 0, "No voting power");
        
        if (support) {
            prop.votesFor += weight;
        } else {
            prop.votesAgainst += weight;
        }
        
        prop.hasVoted[msg.sender] = true;
        
        emit ProposalVoted(proposalId, msg.sender, support, weight);
    }
    
    function executeProposal(uint256 proposalId) external onlyRole(EXECUTOR_ROLE) {
        Proposal storage prop = proposals[proposalId];
        require(prop.status == Status.Active, "Not active");
        require(block.timestamp >= prop.startTime + prop.duration, "Voting ongoing");
        
        if (prop.votesFor > prop.votesAgainst) {
            prop.status = Status.Completed;
            // Additional execution logic here
        } else {
            prop.status = Status.Failed;
        }
        
        emit ProposalExecuted(proposalId, prop.status);
    }
    
    // Internal functions
    function checkEligibility(
        address user,
        Track track
    ) internal view returns (bool) {
        uint256 stake = sbxToken.balanceOf(user);
        if (stake < minStake[track]) return false;
        
        if (minEngagement[track] > 0) {
            uint256 engagementScore = engagement.getEngagementLevel(user);
            if (engagementScore < minEngagement[track]) return false;
        }
        
        if (minValue[track] > 0) {
            (uint256 value,,) = sbvToken.getValueMetrics(user);
            if (value < minValue[track]) return false;
        }
        
        return true;
    }
    
    function getVotingWeight(
        address user,
        Track track
    ) internal view returns (uint256) {
        uint256 baseWeight = sbxToken.getVotingPower(user);
        
        // Track-specific multipliers
        if (track == Track.Community) {
            uint256 engagementScore = engagement.getEngagementLevel(user);
            baseWeight = (baseWeight * (10000 + engagementScore)) / 10000;
        } else if (track == Track.Options) {
            (uint256 value, uint256 successRate,) = sbvToken.getValueMetrics(user);
            if (value > 0 && successRate > 5000) {  // >50% success rate
                baseWeight = (baseWeight * 12000) / 10000;  // 1.2x multiplier
            }
        }
        
        // Add SHIBAK balance multiplier
        uint256 shibakBalance = shibakToken.balanceOf(user);
        if (shibakBalance > 0) {
            baseWeight = (baseWeight * (10000 + (shibakBalance / 1e20))) / 10000;
        }
        
        return baseWeight;
    }
}
