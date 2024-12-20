// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title RewardsCalculator
 * @dev Calculates and manages rewards across all phases
 */
contract RewardsCalculator is AccessControl, ReentrancyGuard {
    bytes32 public constant REWARDS_MANAGER = keccak256("REWARDS_MANAGER");
    
    struct RewardTier {
        uint256 minStake;      // Minimum stake required
        uint256 multiplier;    // Reward multiplier (base 1000)
        uint256 duration;      // Lock duration in seconds
    }
    
    struct UserRewards {
        uint256 tradingFees;   // Accumulated trading fees
        uint256 sbxRewards;    // Accumulated SBX rewards
        uint256 sbvPoints;     // Future SBV points
        uint256 bstblEnergy;   // Future BSTBL energy
        uint256 lastClaim;     // Last claim timestamp
    }
    
    // Phase-specific multipliers (base 1000)
    uint256 public constant PHASE1_MULTIPLIER = 1200;  // 1.2x
    uint256 public constant PHASE2_MULTIPLIER = 1100;  // 1.1x
    uint256 public constant PHASE3_MULTIPLIER = 1050;  // 1.05x
    uint256 public constant PHASE4_MULTIPLIER = 1000;  // 1.0x
    
    // Reward parameters
    uint256 public constant BASE_RATE = 100;           // Base reward rate
    uint256 public constant MAX_MULTIPLIER = 2000;     // 2x max multiplier
    uint256 public constant CLAIM_COOLDOWN = 1 days;   // Minimum time between claims
    
    // State variables
    IERC20 public sbxToken;
    mapping(address => UserRewards) public userRewards;
    mapping(uint256 => RewardTier) public rewardTiers;
    uint256 public currentPhase;
    
    // Events
    event RewardsCalculated(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event TierUpdated(uint256 indexed tier, uint256 minStake, uint256 multiplier);
    event PhaseAdvanced(uint256 newPhase);
    
    constructor(address _sbxToken) {
        require(_sbxToken != address(0), "Invalid token address");
        sbxToken = IERC20(_sbxToken);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        currentPhase = 1;
        
        // Initialize reward tiers
        _initializeRewardTiers();
    }
    
    /**
     * @dev Initialize reward tiers
     */
    function _initializeRewardTiers() internal {
        rewardTiers[1] = RewardTier({
            minStake: 1000 ether,    // 1,000 tokens
            multiplier: 1100,         // 1.1x
            duration: 30 days
        });
        
        rewardTiers[2] = RewardTier({
            minStake: 5000 ether,    // 5,000 tokens
            multiplier: 1250,         // 1.25x
            duration: 90 days
        });
        
        rewardTiers[3] = RewardTier({
            minStake: 10000 ether,   // 10,000 tokens
            multiplier: 1500,         // 1.5x
            duration: 180 days
        });
        
        rewardTiers[4] = RewardTier({
            minStake: 50000 ether,   // 50,000 tokens
            multiplier: 2000,         // 2x
            duration: 365 days
        });
    }
    
    /**
     * @dev Calculate rewards for a user
     * @param user User address
     * @param amount Base amount
     * @param tier Reward tier
     */
    function calculateRewards(
        address user,
        uint256 amount,
        uint256 tier
    ) external onlyRole(REWARDS_MANAGER) returns (uint256) {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Invalid amount");
        require(tier > 0 && tier <= 4, "Invalid tier");
        
        // Get phase multiplier
        uint256 phaseMultiplier = _getPhaseMultiplier();
        
        // Get tier multiplier
        uint256 tierMultiplier = rewardTiers[tier].multiplier;
        
        // Calculate total rewards
        uint256 totalRewards = amount
            .mul(phaseMultiplier)
            .mul(tierMultiplier)
            .div(1000000); // Adjust for two multiplier bases
        
        // Update user rewards
        UserRewards storage rewards = userRewards[user];
        rewards.tradingFees += totalRewards;
        
        // Calculate token rewards based on phase
        if (currentPhase >= 2) {
            rewards.sbxRewards += _calculateSBXRewards(totalRewards);
        }
        
        if (currentPhase >= 3) {
            rewards.sbvPoints += _calculateSBVPoints(totalRewards);
        }
        
        if (currentPhase >= 4) {
            rewards.bstblEnergy += _calculateBSTBLEnergy(totalRewards);
        }
        
        emit RewardsCalculated(user, totalRewards);
        return totalRewards;
    }
    
    /**
     * @dev Claim accumulated rewards
     */
    function claimRewards() external nonReentrant returns (bool) {
        UserRewards storage rewards = userRewards[msg.sender];
        require(rewards.tradingFees > 0, "No rewards to claim");
        require(
            block.timestamp >= rewards.lastClaim + CLAIM_COOLDOWN,
            "Cooldown active"
        );
        
        // Transfer rewards
        uint256 totalRewards = rewards.tradingFees;
        rewards.tradingFees = 0;
        
        if (rewards.sbxRewards > 0 && currentPhase >= 2) {
            require(
                sbxToken.transfer(msg.sender, rewards.sbxRewards),
                "SBX transfer failed"
            );
            rewards.sbxRewards = 0;
        }
        
        // Future token transfers would be added here
        
        rewards.lastClaim = block.timestamp;
        emit RewardsClaimed(msg.sender, totalRewards);
        return true;
    }
    
    /**
     * @dev Advance to next phase
     */
    function advancePhase() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(currentPhase < 4, "Max phase reached");
        currentPhase += 1;
        emit PhaseAdvanced(currentPhase);
    }
    
    /**
     * @dev Update reward tier
     */
    function updateRewardTier(
        uint256 tier,
        uint256 minStake,
        uint256 multiplier,
        uint256 duration
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tier > 0 && tier <= 4, "Invalid tier");
        require(multiplier <= MAX_MULTIPLIER, "Multiplier too high");
        
        rewardTiers[tier] = RewardTier({
            minStake: minStake,
            multiplier: multiplier,
            duration: duration
        });
        
        emit TierUpdated(tier, minStake, multiplier);
    }
    
    /**
     * @dev Get phase multiplier
     */
    function _getPhaseMultiplier() internal view returns (uint256) {
        if (currentPhase == 1) return PHASE1_MULTIPLIER;
        if (currentPhase == 2) return PHASE2_MULTIPLIER;
        if (currentPhase == 3) return PHASE3_MULTIPLIER;
        return PHASE4_MULTIPLIER;
    }
    
    /**
     * @dev Calculate SBX rewards
     */
    function _calculateSBXRewards(
        uint256 amount
    ) internal pure returns (uint256) {
        return amount.mul(5).div(100); // 5% in SBX
    }
    
    /**
     * @dev Calculate SBV points
     */
    function _calculateSBVPoints(
        uint256 amount
    ) internal pure returns (uint256) {
        return amount.mul(2).div(100); // 2% in SBV points
    }
    
    /**
     * @dev Calculate BSTBL energy
     */
    function _calculateBSTBLEnergy(
        uint256 amount
    ) internal pure returns (uint256) {
        return amount.mul(3).div(100); // 3% in BSTBL energy
    }
}
