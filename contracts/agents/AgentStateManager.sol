// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./AgentRegistry.sol";

contract AgentStateManager is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant STATE_MANAGER_ROLE = keccak256("STATE_MANAGER_ROLE");
    
    AgentRegistry public immutable registry;
    
    enum StateType {
        Idle,
        Processing,
        Waiting,
        Learning,
        Coordinating,
        Error
    }
    
    struct AgentState {
        StateType currentState;
        bytes32 currentTask;
        uint256 stateStartTime;
        uint256 lastStateChange;
        uint256 processingPower;
        uint256 memoryUsage;
        bytes32[] dependencies;
        mapping(bytes32 => bool) completedTasks;
    }
    
    struct StateTransition {
        StateType fromState;
        StateType toState;
        uint256 timestamp;
        bytes32 reason;
    }
    
    // State storage
    mapping(bytes32 => AgentState) public agentStates;
    mapping(bytes32 => StateTransition[]) public stateHistory;
    mapping(bytes32 => mapping(StateType => uint256)) public stateMetrics;
    
    // Events
    event StateChanged(
        bytes32 indexed agentId,
        StateType fromState,
        StateType toState,
        bytes32 reason
    );
    
    event ResourcesUpdated(
        bytes32 indexed agentId,
        uint256 processingPower,
        uint256 memoryUsage
    );
    
    event TaskCompleted(
        bytes32 indexed agentId,
        bytes32 indexed taskId,
        uint256 timestamp
    );
    
    constructor(address _registry) {
        registry = AgentRegistry(_registry);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(STATE_MANAGER_ROLE, msg.sender);
    }
    
    function updateState(
        bytes32 agentId,
        StateType newState,
        bytes32 reason
    ) external onlyRole(STATE_MANAGER_ROLE) nonReentrant {
        require(isValidTransition(agentId, newState), "Invalid state transition");
        
        AgentState storage state = agentStates[agentId];
        StateType oldState = state.currentState;
        
        // Update state metrics
        uint256 timeInState = block.timestamp - state.stateStartTime;
        stateMetrics[agentId][oldState] += timeInState;
        
        // Record state transition
        state.currentState = newState;
        state.stateStartTime = block.timestamp;
        state.lastStateChange = block.timestamp;
        
        // Store in history
        stateHistory[agentId].push(StateTransition({
            fromState: oldState,
            toState: newState,
            timestamp: block.timestamp,
            reason: reason
        }));
        
        emit StateChanged(agentId, oldState, newState, reason);
    }
    
    function updateResources(
        bytes32 agentId,
        uint256 processingPower,
        uint256 memoryUsage
    ) external onlyRole(STATE_MANAGER_ROLE) {
        AgentState storage state = agentStates[agentId];
        state.processingPower = processingPower;
        state.memoryUsage = memoryUsage;
        
        emit ResourcesUpdated(agentId, processingPower, memoryUsage);
    }
    
    function addDependency(
        bytes32 agentId,
        bytes32 dependencyId
    ) external onlyRole(STATE_MANAGER_ROLE) {
        AgentState storage state = agentStates[agentId];
        state.dependencies.push(dependencyId);
    }
    
    function completeTask(
        bytes32 agentId,
        bytes32 taskId
    ) external onlyRole(STATE_MANAGER_ROLE) {
        AgentState storage state = agentStates[agentId];
        require(!state.completedTasks[taskId], "Task already completed");
        
        state.completedTasks[taskId] = true;
        state.currentTask = bytes32(0);
        
        emit TaskCompleted(agentId, taskId, block.timestamp);
    }
    
    function getAgentState(bytes32 agentId) external view returns (
        StateType currentState,
        bytes32 currentTask,
        uint256 stateStartTime,
        uint256 lastStateChange,
        uint256 processingPower,
        uint256 memoryUsage,
        bytes32[] memory dependencies
    ) {
        AgentState storage state = agentStates[agentId];
        return (
            state.currentState,
            state.currentTask,
            state.stateStartTime,
            state.lastStateChange,
            state.processingPower,
            state.memoryUsage,
            state.dependencies
        );
    }
    
    function getStateHistory(bytes32 agentId) external view returns (StateTransition[] memory) {
        return stateHistory[agentId];
    }
    
    function getStateMetrics(
        bytes32 agentId,
        StateType stateType
    ) external view returns (uint256) {
        return stateMetrics[agentId][stateType];
    }
    
    function isTaskCompleted(
        bytes32 agentId,
        bytes32 taskId
    ) external view returns (bool) {
        return agentStates[agentId].completedTasks[taskId];
    }
    
    // Internal functions
    function isValidTransition(
        bytes32 agentId,
        StateType newState
    ) internal view returns (bool) {
        AgentState storage state = agentStates[agentId];
        StateType currentState = state.currentState;
        
        // Allow any transition from Error state
        if (currentState == StateType.Error) return true;
        
        // Prevent transition to same state
        if (currentState == newState) return false;
        
        // Add specific transition rules here
        if (currentState == StateType.Processing) {
            // Can only transition to Waiting, Error, or Idle from Processing
            return newState == StateType.Waiting ||
                   newState == StateType.Error ||
                   newState == StateType.Idle;
        }
        
        // Default to allowing transitions
        return true;
    }
}
