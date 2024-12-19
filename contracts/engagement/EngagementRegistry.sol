// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./CommunityEngagement.sol";

contract EngagementRegistry is AccessControl, ReentrancyGuard {
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    
    CommunityEngagement public immutable engagement;
    
    // Activity types and weights
    enum ActivityType {
        Comment,
        Post,
        Review,
        Contribution,
        Moderation,
        Development
    }
    
    struct ActivityConfig {
        uint256 baseScore;
        uint256 multiplier;
        bool active;
    }
    
    mapping(ActivityType => ActivityConfig) public activityConfigs;
    
    // Achievement tracking
    struct Achievement {
        string name;
        uint256 threshold;
        uint256 bonus;
        bool repeatable;
    }
    
    mapping(bytes32 => Achievement) public achievements;
    mapping(address => mapping(bytes32 => uint256)) public userAchievements;
    
    event ActivityRecorded(
        address indexed user,
        ActivityType activityType,
        uint256 score,
        uint256 multiplier
    );
    
    event AchievementUnlocked(
        address indexed user,
        bytes32 indexed achievementId,
        string name,
        uint256 bonus
    );
    
    constructor(address _engagement) {
        engagement = CommunityEngagement(_engagement);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VALIDATOR_ROLE, msg.sender);
        
        // Initialize activity configs
        activityConfigs[ActivityType.Comment] = ActivityConfig(100, 100, true);
        activityConfigs[ActivityType.Post] = ActivityConfig(300, 100, true);
        activityConfigs[ActivityType.Review] = ActivityConfig(500, 100, true);
        activityConfigs[ActivityType.Contribution] = ActivityConfig(1000, 100, true);
        activityConfigs[ActivityType.Moderation] = ActivityConfig(800, 100, true);
        activityConfigs[ActivityType.Development] = ActivityConfig(2000, 100, true);
        
        // Initialize achievements
        bytes32 socialId = keccak256("SOCIAL_BUTTERFLY");
        achievements[socialId] = Achievement("Social Butterfly", 1000, 500, true);
        
        bytes32 contributorId = keccak256("TOP_CONTRIBUTOR");
        achievements[contributorId] = Achievement("Top Contributor", 5000, 1000, true);
        
        bytes32 developerId = keccak256("MASTER_DEVELOPER");
        achievements[developerId] = Achievement("Master Developer", 10000, 2000, false);
    }
    
    function recordActivity(
        address user,
        ActivityType activityType,
        uint256 quality
    ) external onlyRole(VALIDATOR_ROLE) nonReentrant {
        require(quality <= 100, "Quality score too high");
        ActivityConfig memory config = activityConfigs[activityType];
        require(config.active, "Activity type not active");
        
        // Calculate score with quality multiplier
        uint256 score = (config.baseScore * quality * config.multiplier) / 10000;
        
        // Record engagement
        engagement.recordEngagement(user, score, config.multiplier);
        
        emit ActivityRecorded(user, activityType, score, config.multiplier);
        
        // Check achievements
        checkAchievements(user);
    }
    
    function checkAchievements(address user) internal {
        uint256 totalScore = engagement.getEngagementLevel(user);
        
        bytes32[] memory achievementIds = new bytes32[](3);
        achievementIds[0] = keccak256("SOCIAL_BUTTERFLY");
        achievementIds[1] = keccak256("TOP_CONTRIBUTOR");
        achievementIds[2] = keccak256("MASTER_DEVELOPER");
        
        for (uint i = 0; i < achievementIds.length; i++) {
            bytes32 id = achievementIds[i];
            Achievement memory achievement = achievements[id];
            
            if (totalScore >= achievement.threshold) {
                if (achievement.repeatable || userAchievements[user][id] == 0) {
                    userAchievements[user][id]++;
                    
                    // Award bonus engagement score
                    engagement.recordEngagement(user, achievement.bonus, 100);
                    
                    emit AchievementUnlocked(user, id, achievement.name, achievement.bonus);
                }
            }
        }
    }
    
    // Admin functions
    function setActivityConfig(
        ActivityType activityType,
        uint256 baseScore,
        uint256 multiplier,
        bool active
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        activityConfigs[activityType] = ActivityConfig(baseScore, multiplier, active);
    }
    
    function addAchievement(
        bytes32 id,
        string calldata name,
        uint256 threshold,
        uint256 bonus,
        bool repeatable
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        achievements[id] = Achievement(name, threshold, bonus, repeatable);
    }
    
    // View functions
    function getActivityConfig(
        ActivityType activityType
    ) external view returns (uint256 baseScore, uint256 multiplier, bool active) {
        ActivityConfig memory config = activityConfigs[activityType];
        return (config.baseScore, config.multiplier, config.active);
    }
    
    function getAchievement(
        bytes32 id
    ) external view returns (
        string memory name,
        uint256 threshold,
        uint256 bonus,
        bool repeatable
    ) {
        Achievement memory achievement = achievements[id];
        return (achievement.name, achievement.threshold, achievement.bonus, achievement.repeatable);
    }
    
    function getUserAchievementCount(
        address user,
        bytes32 id
    ) external view returns (uint256) {
        return userAchievements[user][id];
    }
}
