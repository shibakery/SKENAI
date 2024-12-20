// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title TokenGate
 * @dev Manages access control based on token holdings and reputation
 */
contract TokenGate is Ownable, ReentrancyGuard {
    IERC20 public governanceToken;
    
    // Access level thresholds (in token amounts)
    uint256 public constant BASIC_ACCESS = 100 ether;    // 100 tokens
    uint256 public constant ADVANCED_ACCESS = 1000 ether; // 1000 tokens
    uint256 public constant PREMIUM_ACCESS = 10000 ether; // 10000 tokens
    
    // Reputation thresholds
    uint256 public constant BASIC_REPUTATION = 100;
    uint256 public constant ADVANCED_REPUTATION = 1000;
    uint256 public constant PREMIUM_REPUTATION = 10000;
    
    // User data
    struct UserAccess {
        uint256 reputation;
        uint256 lastCheckTimestamp;
        bool isWhitelisted;
        mapping(bytes32 => bool) featureAccess;
    }
    
    mapping(address => UserAccess) public userAccess;
    mapping(bytes32 => uint256) public featureThresholds;
    
    // Events
    event AccessGranted(address indexed user, string feature);
    event AccessRevoked(address indexed user, string feature);
    event ReputationUpdated(address indexed user, uint256 newReputation);
    event WhitelistUpdated(address indexed user, bool status);
    
    constructor(address _governanceToken) {
        governanceToken = IERC20(_governanceToken);
    }
    
    /**
     * @dev Checks if a user has access to a specific feature
     */
    function hasAccess(address user, string memory feature) public view returns (bool) {
        bytes32 featureHash = keccak256(abi.encodePacked(feature));
        
        // Whitelisted users always have access
        if (userAccess[user].isWhitelisted) {
            return true;
        }
        
        // Check token balance and reputation
        uint256 balance = governanceToken.balanceOf(user);
        uint256 reputation = userAccess[user].reputation;
        uint256 threshold = featureThresholds[featureHash];
        
        return balance >= threshold || reputation >= threshold;
    }
    
    /**
     * @dev Sets access threshold for a feature
     */
    function setFeatureThreshold(string memory feature, uint256 threshold) external onlyOwner {
        bytes32 featureHash = keccak256(abi.encodePacked(feature));
        featureThresholds[featureHash] = threshold;
    }
    
    /**
     * @dev Updates user's reputation
     */
    function updateReputation(address user, uint256 reputationDelta, bool increase) external onlyOwner {
        UserAccess storage access = userAccess[user];
        
        if (increase) {
            access.reputation += reputationDelta;
        } else {
            if (access.reputation < reputationDelta) {
                access.reputation = 0;
            } else {
                access.reputation -= reputationDelta;
            }
        }
        
        emit ReputationUpdated(user, access.reputation);
    }
    
    /**
     * @dev Updates whitelist status for a user
     */
    function setWhitelist(address user, bool status) external onlyOwner {
        userAccess[user].isWhitelisted = status;
        emit WhitelistUpdated(user, status);
    }
    
    /**
     * @dev Gets user's access level based on tokens and reputation
     */
    function getUserAccessLevel(address user) public view returns (uint8) {
        uint256 balance = governanceToken.balanceOf(user);
        uint256 reputation = userAccess[user].reputation;
        
        if (balance >= PREMIUM_ACCESS || reputation >= PREMIUM_REPUTATION) {
            return 3; // Premium
        } else if (balance >= ADVANCED_ACCESS || reputation >= ADVANCED_REPUTATION) {
            return 2; // Advanced
        } else if (balance >= BASIC_ACCESS || reputation >= BASIC_REPUTATION) {
            return 1; // Basic
        }
        return 0; // No access
    }
    
    /**
     * @dev Checks if user meets minimum requirements for basic access
     */
    function meetsMinimumRequirements(address user) public view returns (bool) {
        return getUserAccessLevel(user) > 0 || userAccess[user].isWhitelisted;
    }
}
