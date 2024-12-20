// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IStrategyManager
 * @dev Interface for strategy management
 */
interface IStrategyManager {
    // Strategy types
    enum StrategyClass {
        DOV,            // DeFi Options Vault
        PERPETUAL,      // Perpetual Options
        ADVANCED_DOV,   // Advanced DOV
        ADVANCED_PERP   // Advanced Perpetual
    }
    
    // Events
    event StrategyCreated(bytes32 indexed strategyId, StrategyClass class_);
    event StrategyUpdated(bytes32 indexed strategyId, uint256 timestamp);
    event StrategyExecuted(bytes32 indexed strategyId, uint256 result);
    event MetricsUpdated(bytes32 indexed strategyId, uint256 metrics);
    
    /**
     * @dev Create new strategy
     * @param strategyId Strategy identifier
     * @param class_ Strategy class
     * @param params Strategy parameters (encoded)
     */
    function createStrategy(
        bytes32 strategyId,
        StrategyClass class_,
        bytes memory params
    ) external returns (bool);
    
    /**
     * @dev Update strategy parameters
     * @param strategyId Strategy identifier
     * @param params New parameters (encoded)
     */
    function updateStrategy(
        bytes32 strategyId,
        bytes memory params
    ) external returns (bool);
    
    /**
     * @dev Execute strategy
     * @param strategyId Strategy identifier
     */
    function executeStrategy(
        bytes32 strategyId
    ) external returns (uint256);
    
    /**
     * @dev Get strategy metrics
     * @param strategyId Strategy identifier
     */
    function getMetrics(
        bytes32 strategyId
    ) external view returns (bytes memory);
    
    /**
     * @dev Check if strategy exists
     * @param strategyId Strategy identifier
     */
    function strategyExists(
        bytes32 strategyId
    ) external view returns (bool);
    
    /**
     * @dev Get strategy class
     * @param strategyId Strategy identifier
     */
    function getStrategyClass(
        bytes32 strategyId
    ) external view returns (StrategyClass);
    
    /**
     * @dev Get strategy parameters
     * @param strategyId Strategy identifier
     */
    function getParameters(
        bytes32 strategyId
    ) external view returns (bytes memory);
}
