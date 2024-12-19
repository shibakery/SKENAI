// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ISHIBAKToken.sol";

contract CommunityEngagement is AccessControl, ReentrancyGuard {
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    
    ISHIBAKToken public immutable shibakToken;
    
    // Staking and engagement tracking
    struct UserInfo {
        uint256 stakedAmount;
        uint256 lastStakeTime;
        uint256 engagementScore;
        uint256 lastEngagement;
        uint256 rewardDebt;
    }
    
    mapping(address => UserInfo) public userInfo;
    
    // Engagement parameters
    uint256 public constant ENGAGEMENT_COOLDOWN = 1 days;
    uint256 public constant MAX_ENGAGEMENT_SCORE = 10000;
    uint256 public constant REWARD_RATE = 100; // Base reward rate
    uint256 public constant MINIMUM_STAKE = 1000 * 10**18; // Minimum stake required
    
    // Reward pool
    uint256 public accRewardPerShare;
    uint256 public lastRewardBlock;
    uint256 public totalStaked;
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event EngagementRecorded(address indexed user, uint256 score, uint256 reward);
    event RewardClaimed(address indexed user, uint256 amount);
    
    constructor(address _shibakToken) {
        shibakToken = ISHIBAKToken(_shibakToken);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MODERATOR_ROLE, msg.sender);
    }
    
    // Staking functions
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        UserInfo storage user = userInfo[msg.sender];
        
        // Update reward debt
        updatePool();
        if (user.stakedAmount > 0) {
            uint256 pending = (user.stakedAmount * accRewardPerShare) / 1e12 - user.rewardDebt;
            if (pending > 0) {
                user.engagementScore += pending;
            }
        }
        
        // Transfer tokens
        require(shibakToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        user.stakedAmount += amount;
        user.lastStakeTime = block.timestamp;
        totalStaked += amount;
        user.rewardDebt = (user.stakedAmount * accRewardPerShare) / 1e12;
        
        emit Staked(msg.sender, amount);
    }
    
    function unstake(uint256 amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(amount > 0 && amount <= user.stakedAmount, "Invalid amount");
        require(block.timestamp >= user.lastStakeTime + 7 days, "Staking period not met");
        
        // Update reward debt
        updatePool();
        uint256 pending = (user.stakedAmount * accRewardPerShare) / 1e12 - user.rewardDebt;
        if (pending > 0) {
            user.engagementScore += pending;
        }
        
        // Transfer tokens
        user.stakedAmount -= amount;
        totalStaked -= amount;
        require(shibakToken.transfer(msg.sender, amount), "Transfer failed");
        
        user.rewardDebt = (user.stakedAmount * accRewardPerShare) / 1e12;
        
        emit Unstaked(msg.sender, amount);
    }
    
    // Engagement functions
    function recordEngagement(
        address user,
        uint256 score,
        uint256 multiplier
    ) external onlyRole(MODERATOR_ROLE) nonReentrant {
        require(score <= MAX_ENGAGEMENT_SCORE, "Score too high");
        require(
            block.timestamp >= userInfo[user].lastEngagement + ENGAGEMENT_COOLDOWN,
            "Too frequent"
        );
        
        UserInfo storage userStake = userInfo[user];
        require(userStake.stakedAmount >= MINIMUM_STAKE, "Insufficient stake");
        
        updatePool();
        
        // Calculate reward based on stake and engagement
        uint256 reward = (score * REWARD_RATE * multiplier * userStake.stakedAmount) / (1e4 * 1e18);
        userStake.engagementScore += reward;
        userStake.lastEngagement = block.timestamp;
        
        emit EngagementRecorded(user, score, reward);
    }
    
    // Pool update and reward calculation
    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }
        
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        
        uint256 multiplier = block.number - lastRewardBlock;
        uint256 reward = multiplier * REWARD_RATE;
        accRewardPerShare = accRewardPerShare + ((reward * 1e12) / totalStaked);
        lastRewardBlock = block.number;
    }
    
    // View functions
    function getEngagementLevel(address user) external view returns (uint256) {
        return userInfo[user].engagementScore;
    }
    
    function getStakeInfo(address user) external view returns (
        uint256 stakedAmount,
        uint256 engagementScore,
        uint256 pendingRewards
    ) {
        UserInfo storage userStake = userInfo[user];
        stakedAmount = userStake.stakedAmount;
        engagementScore = userStake.engagementScore;
        
        uint256 accRewardPerShareTemp = accRewardPerShare;
        if (block.number > lastRewardBlock && totalStaked != 0) {
            uint256 multiplier = block.number - lastRewardBlock;
            uint256 reward = multiplier * REWARD_RATE;
            accRewardPerShareTemp = accRewardPerShare + ((reward * 1e12) / totalStaked);
        }
        
        pendingRewards = (userStake.stakedAmount * accRewardPerShareTemp) / 1e12 - userStake.rewardDebt;
    }
    
    function canEngage(address user) external view returns (bool) {
        return block.timestamp >= userInfo[user].lastEngagement + ENGAGEMENT_COOLDOWN;
    }
}
