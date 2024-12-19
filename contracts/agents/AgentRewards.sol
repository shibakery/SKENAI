// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../tokens/SBXToken.sol";
import "./AgentRegistry.sol";
import "./AgentPerformance.sol";

contract AgentRewards is AccessControl, ReentrancyGuard {
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");
    
    SBXToken public immutable sbxToken;
    AgentRegistry public immutable registry;
    AgentPerformance public immutable performance;
    
    struct RewardConfig {
        uint256 baseReward;
        uint256 performanceMultiplier;
        uint256 successBonus;
        uint256 valueShare;
        uint256 collaborationBonus;
        uint256 innovationBonus;
        uint256 stakingMultiplier;
    }
    
    struct StakingPosition {
        uint256 amount;
        uint256 startTime;
        uint256 lockDuration;
        uint256 multiplier;
        bool active;
    }
    
    struct RewardPool {
        uint256 totalAllocated;
        uint256 totalDistributed;
        uint256 lastUpdateBlock;
        mapping(bytes32 => uint256) categoryAllocations;
        mapping(uint256 => uint256) epochRewards;
    }
    
    struct AgentRewardMetrics {
        uint256 totalRewards;
        uint256 performanceRewards;
        uint256 collaborationRewards;
        uint256 innovationRewards;
        uint256 stakingRewards;
        uint256 lastRewardTime;
        uint256 rewardStreak;
    }
    
    struct EpochMetrics {
        uint256 epochId;
        uint256 startTime;
        uint256 endTime;
        uint256 totalRewards;
        uint256 participantCount;
        mapping(bytes32 => bool) hasParticipated;
    }
    
    // Reward categories
    enum RewardCategory {
        Performance,
        Collaboration,
        Innovation,
        Staking,
        Special
    }
    
    // Storage
    mapping(bytes32 => AgentRewardMetrics) public rewardMetrics;
    mapping(bytes32 => StakingPosition[]) public stakingPositions;
    mapping(bytes32 => mapping(RewardCategory => uint256)) public categoryRewards;
    mapping(uint256 => EpochMetrics) public epochMetrics;
    
    RewardConfig public config;
    RewardPool public pool;
    
    uint256 public currentEpoch;
    uint256 public epochDuration = 7 days;
    uint256 public constant MAX_STREAK_MULTIPLIER = 200; // 2x
    uint256 public constant MIN_STAKE_DURATION = 30 days;
    
    event RewardDistributed(
        bytes32 indexed agentId,
        uint256 amount,
        RewardCategory category,
        uint256 multiplier
    );
    
    event StakingPositionCreated(
        bytes32 indexed agentId,
        uint256 amount,
        uint256 lockDuration,
        uint256 multiplier
    );
    
    event EpochCompleted(
        uint256 indexed epochId,
        uint256 totalRewards,
        uint256 participantCount
    );
    
    constructor(
        address _sbxToken,
        address _registry,
        address _performance
    ) {
        sbxToken = SBXToken(_sbxToken);
        registry = AgentRegistry(_registry);
        performance = AgentPerformance(_performance);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
        _grantRole(REWARD_MANAGER_ROLE, msg.sender);
        
        // Initialize reward config
        config = RewardConfig({
            baseReward: 100 * 10**18,      // 100 SBX base reward
            performanceMultiplier: 200,     // Up to 2x multiplier
            successBonus: 50 * 10**18,      // 50 SBX bonus for success
            valueShare: 1000,               // 10% value share
            collaborationBonus: 30 * 10**18, // 30 SBX collaboration bonus
            innovationBonus: 40 * 10**18,   // 40 SBX innovation bonus
            stakingMultiplier: 150          // 1.5x staking multiplier
        });
        
        // Initialize first epoch
        startNewEpoch();
    }
    
    function distributeReward(
        bytes32 agentId,
        uint256 taskValue,
        RewardCategory category
    ) external onlyRole(DISTRIBUTOR_ROLE) nonReentrant {
        require(isEligibleForReward(agentId), "Not eligible for reward");
        
        // Get agent metrics
        (
            uint256 performanceScore,
            uint256 successRate,
            ,
            uint256 reputationScore
        ) = registry.getAgentMetrics(agentId);
        
        // Calculate base reward
        uint256 baseAmount = calculateBaseReward(
            agentId,
            performanceScore,
            successRate,
            reputationScore
        );
        
        // Apply category-specific bonuses
        uint256 categoryBonus = calculateCategoryBonus(
            category,
            taskValue,
            performanceScore
        );
        
        // Apply streak multiplier
        uint256 streakMultiplier = calculateStreakMultiplier(agentId);
        
        // Calculate final reward
        uint256 totalReward = (baseAmount + categoryBonus) * streakMultiplier / 100;
        
        // Update metrics
        updateRewardMetrics(agentId, totalReward, category);
        
        // Transfer rewards
        require(
            sbxToken.transfer(registry.agents(agentId).owner, totalReward),
            "Transfer failed"
        );
        
        emit RewardDistributed(agentId, totalReward, category, streakMultiplier);
    }
    
    function createStakingPosition(
        bytes32 agentId,
        uint256 amount,
        uint256 lockDuration
    ) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(lockDuration >= MIN_STAKE_DURATION, "Lock duration too short");
        require(
            registry.agents(agentId).owner == msg.sender,
            "Not agent owner"
        );
        
        require(
            sbxToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        
        uint256 multiplier = calculateStakingMultiplier(lockDuration);
        
        StakingPosition memory position = StakingPosition({
            amount: amount,
            startTime: block.timestamp,
            lockDuration: lockDuration,
            multiplier: multiplier,
            active: true
        });
        
        stakingPositions[agentId].push(position);
        
        emit StakingPositionCreated(
            agentId,
            amount,
            lockDuration,
            multiplier
        );
    }
    
    function processEpochRewards() external onlyRole(REWARD_MANAGER_ROLE) {
        require(
            block.timestamp >= epochMetrics[currentEpoch].endTime,
            "Epoch not ended"
        );
        
        EpochMetrics storage epoch = epochMetrics[currentEpoch];
        
        // Distribute epoch rewards
        distributeEpochRewards(epoch);
        
        emit EpochCompleted(
            currentEpoch,
            epoch.totalRewards,
            epoch.participantCount
        );
        
        // Start new epoch
        startNewEpoch();
    }
    
    // Internal functions
    function calculateBaseReward(
        bytes32 agentId,
        uint256 performanceScore,
        uint256 successRate,
        uint256 reputationScore
    ) internal view returns (uint256) {
        uint256 baseAmount = config.baseReward;
        
        // Apply performance multiplier
        uint256 performanceMultiplier = (performanceScore * config.performanceMultiplier) / 100;
        baseAmount = baseAmount * (100 + performanceMultiplier) / 100;
        
        // Apply success bonus
        if (successRate >= 7500) { // 75% success rate
            baseAmount += config.successBonus;
        }
        
        // Apply reputation modifier
        baseAmount = baseAmount * (100 + reputationScore) / 100;
        
        return baseAmount;
    }
    
    function calculateCategoryBonus(
        RewardCategory category,
        uint256 taskValue,
        uint256 performanceScore
    ) internal view returns (uint256) {
        if (category == RewardCategory.Performance) {
            return (taskValue * config.valueShare) / 10000;
        } else if (category == RewardCategory.Collaboration) {
            return config.collaborationBonus;
        } else if (category == RewardCategory.Innovation) {
            return config.innovationBonus;
        } else if (category == RewardCategory.Staking) {
            return (taskValue * config.stakingMultiplier) / 100;
        }
        return 0;
    }
    
    function calculateStreakMultiplier(
        bytes32 agentId
    ) internal view returns (uint256) {
        uint256 streak = rewardMetrics[agentId].rewardStreak;
        uint256 multiplier = 100 + (streak * 5); // 5% increase per streak
        return multiplier > MAX_STREAK_MULTIPLIER ? MAX_STREAK_MULTIPLIER : multiplier;
    }
    
    function calculateStakingMultiplier(
        uint256 lockDuration
    ) internal pure returns (uint256) {
        if (lockDuration >= 365 days) return 200;     // 2x
        if (lockDuration >= 180 days) return 150;     // 1.5x
        if (lockDuration >= 90 days) return 125;      // 1.25x
        return 100;                                   // 1x
    }
    
    function updateRewardMetrics(
        bytes32 agentId,
        uint256 amount,
        RewardCategory category
    ) internal {
        AgentRewardMetrics storage metrics = rewardMetrics[agentId];
        
        metrics.totalRewards += amount;
        metrics.lastRewardTime = block.timestamp;
        metrics.rewardStreak++;
        
        if (category == RewardCategory.Performance) {
            metrics.performanceRewards += amount;
        } else if (category == RewardCategory.Collaboration) {
            metrics.collaborationRewards += amount;
        } else if (category == RewardCategory.Innovation) {
            metrics.innovationRewards += amount;
        } else if (category == RewardCategory.Staking) {
            metrics.stakingRewards += amount;
        }
        
        categoryRewards[agentId][category] += amount;
        
        // Update epoch participation
        EpochMetrics storage epoch = epochMetrics[currentEpoch];
        if (!epoch.hasParticipated[agentId]) {
            epoch.hasParticipated[agentId] = true;
            epoch.participantCount++;
        }
    }
    
    function startNewEpoch() internal {
        currentEpoch++;
        
        epochMetrics[currentEpoch] = EpochMetrics({
            epochId: currentEpoch,
            startTime: block.timestamp,
            endTime: block.timestamp + epochDuration,
            totalRewards: 0,
            participantCount: 0
        });
    }
    
    function distributeEpochRewards(
        EpochMetrics storage epoch
    ) internal {
        // Implementation for epoch reward distribution
    }
    
    function isEligibleForReward(
        bytes32 agentId
    ) internal view returns (bool) {
        return registry.agents(agentId).active;
    }
}
