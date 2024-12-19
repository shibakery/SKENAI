// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SBVToken is ERC20, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    // Value accrual tracking
    mapping(address => uint256) public valueContributed;
    mapping(address => uint256) public lastValueUpdate;
    
    // Performance metrics
    struct Performance {
        uint256 totalValue;
        uint256 successRate;
        uint256 stakingPeriod;
    }
    mapping(address => Performance) public userPerformance;
    
    event ValueAccrued(address indexed user, uint256 amount, uint256 reward);
    event PerformanceUpdated(address indexed user, uint256 totalValue, uint256 successRate);
    
    constructor() ERC20("SKENAI Value", "SBV") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }
    
    // Record value contribution and mint rewards
    function recordValue(
        address user,
        uint256 amount,
        uint256 successRate
    ) external onlyRole(MINTER_ROLE) nonReentrant {
        require(successRate <= 10000, "Invalid success rate"); // Max 100%
        
        valueContributed[user] += amount;
        lastValueUpdate[user] = block.timestamp;
        
        Performance storage perf = userPerformance[user];
        perf.totalValue += amount;
        perf.successRate = successRate;
        perf.stakingPeriod = block.timestamp;
        
        // Calculate reward based on amount and success rate
        uint256 reward = (amount * successRate) / 10000;
        _mint(user, reward);
        
        emit ValueAccrued(user, amount, reward);
        emit PerformanceUpdated(user, perf.totalValue, successRate);
    }
    
    // Burn tokens for failed strategies
    function penalizeValue(
        address user,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) nonReentrant {
        require(balanceOf(user) >= amount, "Insufficient balance");
        _burn(user, amount);
        
        Performance storage perf = userPerformance[user];
        if (perf.totalValue >= amount) {
            perf.totalValue -= amount;
        } else {
            perf.totalValue = 0;
        }
        
        emit PerformanceUpdated(user, perf.totalValue, perf.successRate);
    }
    
    // View functions
    function getValueMetrics(
        address user
    ) external view returns (
        uint256 value,
        uint256 successRate,
        uint256 stakingPeriod
    ) {
        Performance memory perf = userPerformance[user];
        return (perf.totalValue, perf.successRate, perf.stakingPeriod);
    }
    
    function getValueRank(address user) external view returns (uint256) {
        return valueContributed[user];
    }
}
