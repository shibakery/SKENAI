// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./EverstrikeIntegration.sol";

/**
 * @title StateChannelOptimizer
 * @dev Optimizes state channels for Everstrike integration
 */
contract StateChannelOptimizer is AccessControl, ReentrancyGuard {
    bytes32 public constant OPTIMIZER_ROLE = keccak256("OPTIMIZER_ROLE");
    
    struct ChannelHealth {
        uint256 liquidityScore;
        uint256 utilizationScore;
        uint256 efficiencyScore;
        uint256 riskScore;
        bool isHealthy;
    }
    
    struct OptimizationParams {
        uint256 minLiquidity;
        uint256 maxUtilization;
        uint256 targetEfficiency;
        uint256 riskThreshold;
    }
    
    // State variables
    mapping(bytes32 => ChannelHealth) public channelHealth;
    mapping(bytes32 => OptimizationParams) public optimizationParams;
    EverstrikeIntegration public everstrikeIntegration;
    
    // Events
    event ChannelOptimized(bytes32 indexed channelId, bool success);
    event HealthUpdated(bytes32 indexed channelId, bool isHealthy);
    event ParamsUpdated(bytes32 indexed channelId, OptimizationParams params);
    
    constructor(address _everstrikeIntegration) {
        require(_everstrikeIntegration != address(0), "Invalid integration address");
        everstrikeIntegration = EverstrikeIntegration(_everstrikeIntegration);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @dev Optimize a state channel
     * @param channelId The ID of the state channel
     */
    function optimizeChannel(
        bytes32 channelId
    ) external onlyRole(OPTIMIZER_ROLE) nonReentrant returns (bool) {
        require(channelId != bytes32(0), "Invalid channel ID");
        
        // Get current health and params
        ChannelHealth storage health = channelHealth[channelId];
        OptimizationParams storage params = optimizationParams[channelId];
        
        // Get metrics from integration contract
        EverstrikeIntegration.ChannelMetrics memory metrics = 
            everstrikeIntegration.getChannelMetrics(channelId);
        
        // Calculate new optimal parameters
        uint256 targetDepth = _calculateOptimalDepth(metrics, params);
        uint256 maxSlippage = _calculateMaxSlippage(metrics, params);
        
        // Optimize through integration contract
        uint256 efficiency = everstrikeIntegration.optimizeChannel(
            channelId,
            targetDepth,
            maxSlippage
        );
        
        // Update health status
        bool success = _updateChannelHealth(channelId, metrics, efficiency);
        
        emit ChannelOptimized(channelId, success);
        return success;
    }
    
    /**
     * @dev Calculate optimal depth for a channel
     */
    function _calculateOptimalDepth(
        EverstrikeIntegration.ChannelMetrics memory metrics,
        OptimizationParams memory params
    ) internal pure returns (uint256) {
        // Start with current liquidity
        uint256 optimalDepth = metrics.liquidity;
        
        // Adjust based on utilization
        if (metrics.utilization > params.maxUtilization) {
            optimalDepth = (optimalDepth * 120) / 100; // Increase by 20%
        } else if (metrics.utilization < params.maxUtilization / 2) {
            optimalDepth = (optimalDepth * 80) / 100; // Decrease by 20%
        }
        
        // Ensure minimum liquidity
        if (optimalDepth < params.minLiquidity) {
            optimalDepth = params.minLiquidity;
        }
        
        return optimalDepth;
    }
    
    /**
     * @dev Calculate maximum allowed slippage
     */
    function _calculateMaxSlippage(
        EverstrikeIntegration.ChannelMetrics memory metrics,
        OptimizationParams memory params
    ) internal pure returns (uint256) {
        // Base slippage of 0.1%
        uint256 maxSlippage = 10;
        
        // Adjust based on utilization
        if (metrics.utilization > 90) {
            maxSlippage = 20; // 0.2% for high utilization
        } else if (metrics.utilization < 30) {
            maxSlippage = 5; // 0.05% for low utilization
        }
        
        // Adjust based on efficiency
        if (metrics.efficiency < params.targetEfficiency) {
            maxSlippage = (maxSlippage * 80) / 100; // Reduce slippage
        }
        
        return maxSlippage;
    }
    
    /**
     * @dev Update channel health status
     */
    function _updateChannelHealth(
        bytes32 channelId,
        EverstrikeIntegration.ChannelMetrics memory metrics,
        uint256 efficiency
    ) internal returns (bool) {
        ChannelHealth storage health = channelHealth[channelId];
        OptimizationParams storage params = optimizationParams[channelId];
        
        // Update scores
        health.liquidityScore = (metrics.liquidity >= params.minLiquidity) ? 100 : 0;
        health.utilizationScore = (metrics.utilization <= params.maxUtilization) ? 100 : 0;
        health.efficiencyScore = (efficiency >= params.targetEfficiency) ? 100 : 0;
        health.riskScore = _calculateRiskScore(metrics, params);
        
        // Update health status
        health.isHealthy = (
            health.liquidityScore > 0 &&
            health.utilizationScore > 0 &&
            health.efficiencyScore > 0 &&
            health.riskScore < params.riskThreshold
        );
        
        emit HealthUpdated(channelId, health.isHealthy);
        return health.isHealthy;
    }
    
    /**
     * @dev Calculate risk score for a channel
     */
    function _calculateRiskScore(
        EverstrikeIntegration.ChannelMetrics memory metrics,
        OptimizationParams memory params
    ) internal pure returns (uint256) {
        uint256 riskScore = 0;
        
        // Liquidity risk
        if (metrics.liquidity < params.minLiquidity) {
            riskScore += 25;
        }
        
        // Utilization risk
        if (metrics.utilization > params.maxUtilization) {
            riskScore += 25;
        }
        
        // Efficiency risk
        if (metrics.efficiency < params.targetEfficiency) {
            riskScore += 25;
        }
        
        // Time risk
        if (block.timestamp - metrics.lastUpdate > 1 hours) {
            riskScore += 25;
        }
        
        return riskScore;
    }
    
    /**
     * @dev Update optimization parameters
     */
    function updateOptimizationParams(
        bytes32 channelId,
        OptimizationParams memory params
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(channelId != bytes32(0), "Invalid channel ID");
        require(params.minLiquidity > 0, "Invalid min liquidity");
        require(params.maxUtilization > 0 && params.maxUtilization <= 100, "Invalid max utilization");
        require(params.targetEfficiency > 0, "Invalid target efficiency");
        require(params.riskThreshold > 0 && params.riskThreshold <= 100, "Invalid risk threshold");
        
        optimizationParams[channelId] = params;
        emit ParamsUpdated(channelId, params);
    }
    
    /**
     * @dev Get current channel health
     */
    function getChannelHealth(
        bytes32 channelId
    ) external view returns (ChannelHealth memory) {
        return channelHealth[channelId];
    }
}
