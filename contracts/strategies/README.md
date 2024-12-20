# SKENAI Strategy Contracts

## Overview
This directory contains the core strategy contracts for SKENAI's DeFi Options Vault (DOV) and Perpetual Options trading system. These contracts integrate AI-driven insights with traditional options strategies for optimized trading performance.

## Contract Structure

### Base Strategies
- `DOVStrategyManager.sol`: Manages DeFi Options Vault strategies
- `PerpetualOptionsManager.sol`: Handles perpetual options strategies

### Advanced Strategies
Located in `/advanced` directory:
- `AdvancedDOVStrategies.sol`: Enhanced DOV strategies
- `AdvancedPerpStrategies.sol`: Enhanced perpetual strategies

## Strategy Types

### DOV Strategies
1. Base Strategies:
   - Covered Call
   - Put Selling
   - Strangle
   - Iron Condor

2. Advanced Strategies:
   - Butterfly Spread
   - Calendar Spread
   - Jade Lizard
   - Poor Man's Covered Call
   - Diagonal Spread
   - Ratio Spread
   - Collar Strategy
   - Broken Wing Butterfly

### Perpetual Strategies
1. Base Strategies:
   - Delta Neutral
   - Momentum
   - Volatility
   - Arbitrage

2. Advanced Strategies:
   - Grid Trading
   - Mean Reversion
   - Trend Following
   - Statistical Arbitrage
   - Market Making
   - Gamma Scalping
   - Funding Rate Arbitrage
   - Cross-Exchange Arbitrage

## Usage

### Prerequisites
- Solidity ^0.8.19
- OpenZeppelin Contracts
- Foundry/Forge for testing

### Installation
```bash
forge install
```

### Testing
```bash
forge test --match-contract StrategyTest
```

## Security

### Access Control
- Role-based access control (RBAC)
- Strategy manager role
- Admin capabilities

### Risk Management
- Maximum leverage limits
- Position size restrictions
- Minimum margin requirements
- Liquidation thresholds

## Integration

### AI Agent Integration
Strategies integrate with Phase 3 Syndicate Agent for:
- Market analysis
- Parameter optimization
- Risk assessment
- Performance prediction

### External Systems
- Price feeds
- Liquidity pools
- Order books
- Cross-chain bridges

## Contributing
1. Fork the repository
2. Create feature branch
3. Commit changes
4. Open pull request

## License
MIT License
