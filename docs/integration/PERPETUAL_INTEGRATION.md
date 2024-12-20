# Perpetual Options Integration Guide

## Overview
This guide details how to integrate SKENAI's Perpetual Options strategies with external systems and protocols.

## Integration Scenarios

### 1. DEX Integration

#### Setup
```solidity
interface IDEXRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract PerpDEXStrategy is PerpetualOptionsManager {
    IDEXRouter public dexRouter;
    
    constructor(address _aiAgent, address _router) PerpetualOptionsManager(_aiAgent) {
        dexRouter = IDEXRouter(_router);
    }
    
    function executeDEXStrategy(
        bytes32 strategyId,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path
    ) external returns (uint256[] memory) {
        return dexRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            block.timestamp + 1800
        );
    }
}
```

### 2. Funding Rate Integration

#### Implementation
```solidity
interface IFundingRate {
    function getFundingRate() external view returns (int256);
    function predictNextRate() external view returns (int256);
}

contract PerpFundingStrategy is PerpetualOptionsManager {
    IFundingRate public fundingOracle;
    
    constructor(address _aiAgent, address _oracle) PerpetualOptionsManager(_aiAgent) {
        fundingOracle = IFundingRate(_oracle);
    }
    
    function optimizeFunding(bytes32 strategyId) external returns (bool) {
        int256 currentRate = fundingOracle.getFundingRate();
        int256 predictedRate = fundingOracle.predictNextRate();
        
        if (predictedRate > currentRate) {
            // Long position
            return openLong(strategyId);
        } else {
            // Short position
            return openShort(strategyId);
        }
    }
}
```

### 3. Liquidation Integration

#### Protection System
```solidity
interface ILiquidationGuard {
    function checkLiquidation(address account) external view returns (bool);
    function getHealthFactor(address account) external view returns (uint256);
}

contract PerpLiquidationStrategy is PerpetualOptionsManager {
    ILiquidationGuard public guard;
    
    event LiquidationWarning(bytes32 indexed strategyId, uint256 healthFactor);
    
    constructor(address _aiAgent, address _guard) PerpetualOptionsManager(_aiAgent) {
        guard = ILiquidationGuard(_guard);
    }
    
    function monitorHealth(bytes32 strategyId) external returns (bool) {
        uint256 healthFactor = guard.getHealthFactor(address(this));
        
        if (healthFactor < 1.2e18) { // 120%
            emit LiquidationWarning(strategyId, healthFactor);
            return reduceRisk(strategyId);
        }
        
        return true;
    }
}
```

## Best Practices

### 1. Position Management
```solidity
contract PerpPositionManager is PerpetualOptionsManager {
    struct Position {
        uint256 size;
        uint256 leverage;
        uint256 entryPrice;
        uint256 liquidationPrice;
        bool isLong;
    }
    
    mapping(bytes32 => Position) public positions;
    
    function validatePosition(bytes32 strategyId, Position memory position) internal pure {
        require(position.leverage <= 10e18, "Leverage too high");
        require(position.size <= 1000000e18, "Position too large");
    }
}
```

### 2. Market Making
```solidity
contract PerpMarketMaker is PerpetualOptionsManager {
    struct OrderBook {
        uint256[] bids;
        uint256[] asks;
        uint256 spread;
    }
    
    function maintainSpread(bytes32 strategyId) external returns (bool) {
        OrderBook memory book = getOrderBook(strategyId);
        
        if (book.spread > targetSpread) {
            return tightenSpread(strategyId);
        }
        
        return true;
    }
}
```

### 3. Hedging
```solidity
contract PerpHedgeStrategy is PerpetualOptionsManager {
    function deltaHedge(bytes32 strategyId) external returns (bool) {
        int256 delta = calculateDelta(strategyId);
        
        if (delta > deltaThreshold) {
            return hedgeShort(strategyId, uint256(delta));
        } else if (delta < -deltaThreshold) {
            return hedgeLong(strategyId, uint256(-delta));
        }
        
        return true;
    }
}
```

## Testing Integration

### 1. Mock Setup
```solidity
contract MockPerpExchange {
    mapping(address => int256) public positions;
    
    function openPosition(bool isLong, uint256 size) external returns (bool) {
        positions[msg.sender] = isLong ? int256(size) : -int256(size);
        return true;
    }
}
```

### 2. Integration Tests
```solidity
contract PerpIntegrationTest is Test {
    PerpDEXStrategy public strategy;
    MockPerpExchange public exchange;
    
    function setUp() public {
        exchange = new MockPerpExchange();
        strategy = new PerpDEXStrategy(address(0), address(exchange));
    }
    
    function testPositionOpening() public {
        bytes32 strategyId = keccak256("TEST_STRATEGY");
        assertTrue(strategy.openPosition(strategyId, true, 1000e18));
    }
}
```

## Error Handling

### 1. Market Errors
```solidity
contract PerpErrorHandler is PerpetualOptionsManager {
    error MarketError(string message);
    error SlippageError(uint256 expected, uint256 actual);
    
    function executeWithSlippage(
        bytes32 strategyId,
        uint256 expectedPrice,
        uint256 maxSlippage
    ) external returns (bool) {
        uint256 actualPrice = getExecutionPrice(strategyId);
        
        if (abs(actualPrice - expectedPrice) > maxSlippage) {
            revert SlippageError(expectedPrice, actualPrice);
        }
        
        return executeMarketOrder(strategyId);
    }
}
```

### 2. Network Failures
```solidity
contract PerpNetworkHandler is PerpetualOptionsManager {
    event NetworkError(bytes32 strategyId, string message);
    uint256 public constant MAX_RETRIES = 3;
    
    function executeWithRetry(bytes32 strategyId) external returns (bool) {
        for (uint256 i = 0; i < MAX_RETRIES; i++) {
            try this.executeStrategy(strategyId) returns (bool success) {
                return success;
            } catch (bytes memory reason) {
                emit NetworkError(strategyId, string(reason));
            }
        }
        return false;
    }
}
```

## Monitoring and Maintenance

### 1. Performance Tracking
```solidity
contract PerpPerformanceTracker is PerpetualOptionsManager {
    struct Performance {
        uint256 pnl;
        uint256 volume;
        uint256 fees;
        uint256 timestamp;
    }
    
    mapping(bytes32 => Performance) public performance;
    
    function trackPerformance(bytes32 strategyId) external returns (Performance memory) {
        Performance memory current = calculatePerformance(strategyId);
        performance[strategyId] = current;
        return current;
    }
}
```

### 2. Circuit Breakers
```solidity
contract PerpCircuitBreaker is PerpetualOptionsManager {
    uint256 public constant PRICE_CHANGE_THRESHOLD = 10e16; // 10%
    
    function checkCircuitBreaker(bytes32 strategyId) external view returns (bool) {
        uint256 priceChange = calculatePriceChange(strategyId);
        return priceChange > PRICE_CHANGE_THRESHOLD;
    }
    
    modifier withCircuitBreaker(bytes32 strategyId) {
        require(!checkCircuitBreaker(strategyId), "Circuit breaker triggered");
        _;
    }
}
```

## Upgradeability

### 1. Strategy Upgrades
```solidity
contract PerpUpgrader is PerpetualOptionsManager {
    event StrategyUpgraded(bytes32 indexed strategyId, uint256 version);
    
    function upgradeStrategy(
        bytes32 strategyId,
        address newImplementation
    ) external onlyRole(UPGRADER_ROLE) {
        // Transfer positions
        transferPositions(strategyId, newImplementation);
        
        // Update implementation
        updateImplementation(strategyId, newImplementation);
        
        emit StrategyUpgraded(strategyId, getVersion(newImplementation));
    }
}
```

### 2. Data Migration
```solidity
contract PerpMigrator is PerpetualOptionsManager {
    function migrateStrategy(
        bytes32 strategyId,
        address newStrategy
    ) external onlyRole(ADMIN_ROLE) {
        // Migrate positions
        migratePositions(strategyId, newStrategy);
        
        // Migrate performance data
        migratePerformance(strategyId, newStrategy);
        
        // Update references
        updateReferences(strategyId, newStrategy);
    }
}
```
