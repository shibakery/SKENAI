# SKENAI Strategy Tests

## Overview
This directory contains comprehensive test suites for SKENAI's strategy system, covering DOV and Perpetual Options strategies.

## Test Structure

### Main Test Files
- `StrategyTest.sol`: Core strategy tests

### Test Coverage

#### Base Strategies
1. DOV Strategy Tests:
   - Strategy creation
   - Parameter validation
   - Position management
   - Rebalancing logic

2. Perpetual Strategy Tests:
   - Strategy creation
   - Position updates
   - Funding calculations
   - Margin management

#### Advanced Strategies
1. Advanced DOV Tests:
   - Greeks calculation
   - Efficiency scoring
   - Complex strategy execution
   - Risk management

2. Advanced Perpetual Tests:
   - Performance metrics
   - Market making functions
   - Arbitrage execution
   - Risk controls

## Running Tests

### Prerequisites
1. Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Install dependencies:
```bash
forge install
```

### Test Commands

#### Run All Tests
```bash
forge test
```

#### Run Specific Tests
```bash
forge test --match-contract StrategyTest
forge test --match-test testDOVStrategyCreation
```

#### Run with Gas Report
```bash
forge test --gas-report
```

#### Run with Coverage
```bash
forge coverage
```

## Test Environment

### Mock Contracts
- Mock AI Agent
- Mock Price Feeds
- Mock Liquidity Pools

### Test Accounts
- Admin: `address(1)`
- Operator: `address(2)`
- User: `address(3)`

### Test Data
- Strategy IDs
- Default parameters
- Test scenarios

## Writing Tests

### Test Structure
```solidity
function testFeature() public {
    // Setup
    vm.startPrank(operator);
    
    // Execute
    // ... test code ...
    
    // Verify
    assertTrue(...);
    assertEq(...);
    
    vm.stopPrank();
}
```

### Best Practices
1. Test isolation
2. Comprehensive assertions
3. Clear documentation
4. Gas optimization
5. Error handling

## Troubleshooting

### Common Issues
1. Test Failures
   - Check setup steps
   - Verify mock data
   - Confirm permissions

2. Gas Issues
   - Optimize test execution
   - Check loop bounds
   - Monitor state changes

3. Coverage Gaps
   - Identify missing scenarios
   - Add edge cases
   - Test error conditions

## Contributing
1. Write failing test
2. Implement feature
3. Ensure all tests pass
4. Submit pull request

## License
MIT License
