// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title MessageRewards
 * @dev Manages rewards for messaging platform participation
 */
contract MessageRewards is Ownable, ReentrancyGuard {
    IERC20 public rewardToken;
    
    // Reward constants
    uint256 public constant BASE_MESSAGE_REWARD = 10 ether; // 10 tokens
    uint256 public constant REPLY_REWARD = 5 ether;        // 5 tokens
    uint256 public constant REACTION_REWARD = 1 ether;     // 1 token
    
    // Multipliers (in basis points, 10000 = 100%)
    uint256 public constant COMMUNITY_MULTIPLIER = 15000;  // 1.5x
    uint256 public constant PROPOSAL_MULTIPLIER = 20000;   // 2x
    uint256 public constant GOVERNANCE_MULTIPLIER = 30000; // 3x
    
    // Time-based bonuses
    uint256 public constant EARLY_ADOPTER_BONUS = 20000;  // 2x
    uint256 public constant WEEKLY_BONUS = 1000;          // +10%
    uint256 public constant STREAK_BONUS = 500;           // +5%
    
    // User activity tracking
    struct UserActivity {
        uint256 lastActivityTimestamp;
        uint256 weeklyActivityCount;
        uint256 dailyStreak;
        uint256 totalRewardsEarned;
        bool isEarlyAdopter;
    }
    
    mapping(address => UserActivity) public userActivities;
    
    // Events
    event RewardDistributed(address indexed user, uint256 amount, string activityType);
    event MultiplierApplied(address indexed user, uint256 multiplier, string multiplierType);
    
    constructor(address _rewardToken) {
        rewardToken = IERC20(_rewardToken);
    }
    
    /**
     * @dev Records a message activity and calculates rewards
     * @param user Address of the message sender
     * @param activityType Type of activity (message, reply, reaction)
     * @param qualityScore Quality score of the activity (0-100)
     */
    function recordActivity(
        address user,
        string memory activityType,
        uint256 qualityScore
    ) external onlyOwner nonReentrant {
        require(qualityScore <= 100, "Invalid quality score");
        
        UserActivity storage activity = userActivities[user];
        uint256 baseReward = getBaseReward(activityType);
        uint256 multiplier = calculateMultiplier(user, activityType);
        uint256 qualityMultiplier = 10000 + (qualityScore * 100); // Max 2x for perfect quality
        
        uint256 totalReward = (baseReward * multiplier * qualityMultiplier) / (10000 * 10000);
        
        // Update user activity
        activity.lastActivityTimestamp = block.timestamp;
        activity.weeklyActivityCount++;
        activity.totalRewardsEarned += totalReward;
        
        // Transfer rewards
        require(rewardToken.transfer(user, totalReward), "Reward transfer failed");
        
        emit RewardDistributed(user, totalReward, activityType);
    }
    
    /**
     * @dev Calculates the base reward for an activity
     */
    function getBaseReward(string memory activityType) internal pure returns (uint256) {
        bytes32 activityHash = keccak256(abi.encodePacked(activityType));
        
        if (activityHash == keccak256(abi.encodePacked("message"))) {
            return BASE_MESSAGE_REWARD;
        } else if (activityHash == keccak256(abi.encodePacked("reply"))) {
            return REPLY_REWARD;
        } else if (activityHash == keccak256(abi.encodePacked("reaction"))) {
            return REACTION_REWARD;
        }
        
        revert("Invalid activity type");
    }
    
    /**
     * @dev Calculates the total multiplier for a user's activity
     */
    function calculateMultiplier(address user, string memory activityType) internal view returns (uint256) {
        UserActivity storage activity = userActivities[user];
        uint256 multiplier = 10000; // Base 1x
        
        // Early adopter bonus
        if (activity.isEarlyAdopter) {
            multiplier = (multiplier * EARLY_ADOPTER_BONUS) / 10000;
        }
        
        // Weekly activity bonus
        if (activity.weeklyActivityCount > 0) {
            multiplier += WEEKLY_BONUS;
        }
        
        // Daily streak bonus
        if (activity.dailyStreak > 0) {
            multiplier += (STREAK_BONUS * activity.dailyStreak);
        }
        
        // Activity-specific multipliers
        bytes32 activityHash = keccak256(abi.encodePacked(activityType));
        if (activityHash == keccak256(abi.encodePacked("governance"))) {
            multiplier = (multiplier * GOVERNANCE_MULTIPLIER) / 10000;
        } else if (activityHash == keccak256(abi.encodePacked("proposal"))) {
            multiplier = (multiplier * PROPOSAL_MULTIPLIER) / 10000;
        }
        
        return multiplier;
    }
    
    /**
     * @dev Updates the daily streak for a user
     */
    function updateDailyStreak(address user) external onlyOwner {
        UserActivity storage activity = userActivities[user];
        
        // Check if the last activity was within 24 hours
        if (block.timestamp <= activity.lastActivityTimestamp + 1 days) {
            activity.dailyStreak++;
        } else {
            activity.dailyStreak = 0;
        }
    }
    
    /**
     * @dev Marks a user as an early adopter
     */
    function setEarlyAdopter(address user) external onlyOwner {
        userActivities[user].isEarlyAdopter = true;
    }
    
    /**
     * @dev Resets weekly activity count (called weekly)
     */
    function resetWeeklyActivity(address user) external onlyOwner {
        userActivities[user].weeklyActivityCount = 0;
    }
}
