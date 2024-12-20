// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./BoronStable.sol";
import "./BoronOracle.sol";

/**
 * @title MarketOperations
 * @dev Manages market operations for BRST stability
 */
contract MarketOperations is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    BoronStable public boronStable;
    BoronOracle public boronOracle;
    
    // Market operation parameters
    struct OperationParams {
        uint256 minOperationSize;    // Minimum operation size
        uint256 maxOperationSize;    // Maximum operation size
        uint256 cooldownPeriod;      // Time between operations
        uint256 priceImpactLimit;    // Maximum price impact
        uint256 operationFee;        // Fee for market operations
    }
    
    // Market operation record
    struct Operation {
        uint256 id;
        OperationType opType;
        uint256 amount;
        uint256 price;
        uint256 timestamp;
        address operator;
        bool success;
    }
    
    enum OperationType { MINT, BURN, REBALANCE }
    
    OperationParams public params;
    mapping(uint256 => Operation) public operations;
    uint256 public operationCount;
    
    // Market metrics
    struct MarketMetrics {
        uint256 totalMinted;
        uint256 totalBurned;
        uint256 lastOperationTime;
        uint256 averagePrice;
        uint256 volatilityIndex;
    }
    
    MarketMetrics public metrics;
    
    // Events
    event OperationExecuted(uint256 indexed id, OperationType opType, uint256 amount);
    event ParamsUpdated(uint256 minSize, uint256 maxSize, uint256 cooldown);
    event MetricsUpdated(uint256 totalMinted, uint256 totalBurned, uint256 avgPrice);
    
    constructor(address _boronStable, address _boronOracle) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        boronStable = BoronStable(_boronStable);
        boronOracle = BoronOracle(_boronOracle);
        
        // Initialize parameters
        params = OperationParams({
            minOperationSize: 1000 * 1e18,    // 1,000 BRST
            maxOperationSize: 100000 * 1e18,  // 100,000 BRST
            cooldownPeriod: 1 hours,
            priceImpactLimit: 5e16,           // 5%
            operationFee: 1e16                // 1%
        });
    }
    
    /**
     * @dev Execute market operation
     */
    function executeOperation(
        OperationType opType,
        uint256 amount
    ) external onlyRole(OPERATOR_ROLE) nonReentrant {
        require(
            block.timestamp >= metrics.lastOperationTime + params.cooldownPeriod,
            "Cooldown active"
        );
        require(
            amount >= params.minOperationSize &&
            amount <= params.maxOperationSize,
            "Invalid amount"
        );
        
        // Get current market data
        (uint256 supply, uint256 demand, uint256 price,) = boronOracle.getLatestMarketData();
        require(price > 0, "Invalid price data");
        
        // Calculate price impact
        uint256 priceImpact = _calculatePriceImpact(amount, supply);
        require(priceImpact <= params.priceImpactLimit, "High price impact");
        
        // Execute operation
        bool success = false;
        if (opType == OperationType.MINT) {
            success = _executeMint(amount);
            if (success) metrics.totalMinted += amount;
        } else if (opType == OperationType.BURN) {
            success = _executeBurn(amount);
            if (success) metrics.totalBurned += amount;
        } else {
            success = _executeRebalance(amount, supply, demand);
        }
        
        // Record operation
        operationCount++;
        operations[operationCount] = Operation({
            id: operationCount,
            opType: opType,
            amount: amount,
            price: price,
            timestamp: block.timestamp,
            operator: msg.sender,
            success: success
        });
        
        // Update metrics
        metrics.lastOperationTime = block.timestamp;
        metrics.averagePrice = (metrics.averagePrice * 9 + price) / 10;
        metrics.volatilityIndex = _calculateVolatility(price);
        
        emit OperationExecuted(operationCount, opType, amount);
        emit MetricsUpdated(metrics.totalMinted, metrics.totalBurned, metrics.averagePrice);
    }
    
    /**
     * @dev Execute mint operation
     */
    function _executeMint(
        uint256 amount
    ) internal returns (bool) {
        try boronStable.mint(address(this), amount) {
            return true;
        } catch {
            return false;
        }
    }
    
    /**
     * @dev Execute burn operation
     */
    function _executeBurn(
        uint256 amount
    ) internal returns (bool) {
        try boronStable.burn(amount) {
            return true;
        } catch {
            return false;
        }
    }
    
    /**
     * @dev Execute rebalance operation
     */
    function _executeRebalance(
        uint256 amount,
        uint256 supply,
        uint256 demand
    ) internal returns (bool) {
        if (demand > supply) {
            return _executeMint(amount);
        } else {
            return _executeBurn(amount);
        }
    }
    
    /**
     * @dev Calculate price impact of operation
     */
    function _calculatePriceImpact(
        uint256 amount,
        uint256 supply
    ) internal pure returns (uint256) {
        return (amount * 1e18) / supply;
    }
    
    /**
     * @dev Calculate price volatility
     */
    function _calculateVolatility(
        uint256 currentPrice
    ) internal view returns (uint256) {
        if (metrics.averagePrice == 0) return 0;
        
        uint256 priceDiff;
        if (currentPrice > metrics.averagePrice) {
            priceDiff = currentPrice - metrics.averagePrice;
        } else {
            priceDiff = metrics.averagePrice - currentPrice;
        }
        
        return (priceDiff * 1e18) / metrics.averagePrice;
    }
    
    /**
     * @dev Update operation parameters
     */
    function updateParams(
        uint256 minSize,
        uint256 maxSize,
        uint256 cooldown,
        uint256 impactLimit,
        uint256 fee
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(minSize < maxSize, "Invalid sizes");
        require(fee < 1e17, "Fee too high"); // Max 10%
        
        params = OperationParams({
            minOperationSize: minSize,
            maxOperationSize: maxSize,
            cooldownPeriod: cooldown,
            priceImpactLimit: impactLimit,
            operationFee: fee
        });
        
        emit ParamsUpdated(minSize, maxSize, cooldown);
    }
    
    /**
     * @dev Get market metrics
     */
    function getMetrics() external view returns (
        uint256 minted,
        uint256 burned,
        uint256 avgPrice,
        uint256 volatility
    ) {
        return (
            metrics.totalMinted,
            metrics.totalBurned,
            metrics.averagePrice,
            metrics.volatilityIndex
        );
    }
    
    /**
     * @dev Get operation details
     */
    function getOperation(
        uint256 opId
    ) external view returns (Operation memory) {
        return operations[opId];
    }
}
