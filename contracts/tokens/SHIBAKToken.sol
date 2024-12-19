// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SHIBAKToken is ERC20, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    // Social engagement tracking
    mapping(address => uint256) public engagementScore;
    mapping(address => uint256) public lastEngagement;
    
    // Community rewards
    uint256 public constant ENGAGEMENT_COOLDOWN = 1 days;
    uint256 public constant MAX_ENGAGEMENT_SCORE = 10000;
    uint256 public constant REWARD_MULTIPLIER = 100;
    
    event EngagementRecorded(address indexed user, uint256 score, uint256 reward);
    
    constructor() ERC20("SKENAI Community", "SHIBAK") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }
    
    // Record user engagement and distribute rewards
    function recordEngagement(
        address user,
        uint256 score
    ) external onlyRole(MINTER_ROLE) nonReentrant {
        require(score <= MAX_ENGAGEMENT_SCORE, "Score too high");
        require(
            block.timestamp >= lastEngagement[user] + ENGAGEMENT_COOLDOWN,
            "Too frequent"
        );
        
        lastEngagement[user] = block.timestamp;
        engagementScore[user] += score;
        
        uint256 reward = score * REWARD_MULTIPLIER;
        _mint(user, reward);
        
        emit EngagementRecorded(user, score, reward);
    }
    
    // Burn tokens based on negative engagement
    function penalize(
        address user,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) nonReentrant {
        require(balanceOf(user) >= amount, "Insufficient balance");
        _burn(user, amount);
        
        if (engagementScore[user] >= amount) {
            engagementScore[user] -= amount;
        } else {
            engagementScore[user] = 0;
        }
    }
    
    // View functions
    function getEngagementLevel(address user) external view returns (uint256) {
        return engagementScore[user];
    }
    
    function canEngage(address user) external view returns (bool) {
        return block.timestamp >= lastEngagement[user] + ENGAGEMENT_COOLDOWN;
    }
}
