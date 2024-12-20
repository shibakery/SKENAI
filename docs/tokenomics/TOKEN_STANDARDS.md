# SKENAI Token Standards

## Overview
This document outlines the token standards and implementations used in the SKENAI ecosystem, ensuring compatibility, security, and proper integration across all components.

## Token Standards

### 1. SHIBAK (Core Governance Token)
- **Standard**: ERC20
- **Extensions**:
  - AccessControl: Role-based permissions
  - ReentrancyGuard: Protection against reentrancy attacks
- **Features**:
  - Community engagement tracking
  - Reward distribution
  - Governance participation
  - Emergency controls

### 2. SBX (Utility & Staking Token)
- **Standard**: ERC20
- **Extensions**:
  - ERC20Votes: On-chain voting
  - AccessControl: Role-based permissions
- **Features**:
  - Fixed maximum supply (25M)
  - Voting power calculation
  - Minting controls
  - Burning mechanism

### 3. BSTBL (Energy-Backed Stablecoin)
- **Standard**: ERC20
- **Extensions**:
  - AccessControl: Role-based permissions
  - ReentrancyGuard: Protection against reentrancy
  - Pausable: Emergency pause functionality
- **Features**:
  - Energy backing verification
  - Market parameter management
  - Stability controls
  - Oracle integration

### 4. SBV (Special Blockchain Vehicle)
- **Standard**: ERC20
- **Extensions**:
  - AccessControl: Role-based permissions
  - ReentrancyGuard: Protection against reentrancy
- **Features**:
  - Performance tracking
  - Value accrual
  - Service metrics
  - Reward distribution

## Implementation Details

### 1. Access Control
```solidity
bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
```

### 2. Security Features
- Multi-signature requirements
- Role separation
- Update cooldowns
- Emergency pause mechanisms
- Maximum limits

### 3. Integration Points
```solidity
interface ITokenIntegration {
    function verifyEnergyBacking(bytes memory proof) external returns (bool);
    function calculateVotingPower(address user) external view returns (uint256);
    function getServiceMetrics(address provider) external view returns (ServiceMetrics memory);
}
```

## Best Practices

### 1. Security Best Practices
- Always use OpenZeppelin contracts as base
- Implement proper access control
- Add emergency pause functionality
- Include event logging
- Set appropriate limits and cooldowns

### 2. Integration Best Practices
- Use standardized interfaces
- Implement proper error handling
- Add comprehensive events
- Include view functions for data access
- Maintain backwards compatibility

### 3. Upgrade Best Practices
- Use proxy patterns when needed
- Maintain state compatibility
- Include proper documentation
- Test thoroughly before deployment
- Plan for migration scenarios

## Extensions

### 1. Governance Extensions
```solidity
interface IGovernanceExtension {
    function getVotingPower(address account) external view returns (uint256);
    function delegate(address delegatee) external;
    function getVotes(address account) external view returns (uint256);
}
```

### 2. Service Extensions
```solidity
interface IServiceExtension {
    function recordService(bytes32 serviceId, uint256 value) external;
    function validateService(bytes32 serviceId) external view returns (bool);
    function getServiceStats(bytes32 serviceId) external view returns (ServiceStats memory);
}
```

### 3. Market Extensions
```solidity
interface IMarketExtension {
    function updateMarketParams(MarketParams memory params) external;
    function getMarketState() external view returns (MarketState memory);
    function calculateStability() external view returns (uint256);
}
```

## Compatibility

### 1. Cross-Chain Compatibility
- Bridge support
- Message passing
- State verification
- Asset locking

### 2. Protocol Compatibility
- DEX integration
- Lending protocol support
- Oracle compatibility
- Governance integration

### 3. Upgrade Compatibility
- State preservation
- Function selector stability
- Event compatibility
- Storage layout preservation
