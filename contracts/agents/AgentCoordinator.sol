// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./AgentRegistry.sol";
import "./AgentStateManager.sol";
import "./AgentCommunication.sol";

contract AgentCoordinator is AccessControl, ReentrancyGuard {
    bytes32 public constant COORDINATOR_ROLE = keccak256("COORDINATOR_ROLE");
    
    AgentRegistry public immutable registry;
    AgentStateManager public immutable stateManager;
    AgentCommunication public immutable communication;
    
    struct Task {
        bytes32 taskId;
        bytes32 initiatorId;
        TaskType taskType;
        bytes32[] participants;
        mapping(bytes32 => bool) completed;
        uint256 startTime;
        uint256 deadline;
        TaskStatus status;
        bytes data;
    }
    
    enum TaskType {
        Analysis,
        Trading,
        Research,
        Validation,
        Coordination
    }
    
    enum TaskStatus {
        Pending,
        Active,
        Completed,
        Failed,
        Cancelled
    }
    
    struct Coordination {
        bytes32[] activeAgents;
        mapping(bytes32 => bytes32[]) agentTasks;
        mapping(bytes32 => uint256) taskPriorities;
        uint256 lastCoordination;
    }
    
    // Storage
    mapping(bytes32 => Task) public tasks;
    mapping(bytes32 => Coordination) public coordinations;
    mapping(bytes32 => mapping(bytes32 => uint256)) public collaborationScores;
    
    uint256 public constant MAX_PARTICIPANTS = 10;
    uint256 public constant MIN_COORDINATION_INTERVAL = 5 minutes;
    
    event TaskCreated(
        bytes32 indexed taskId,
        bytes32 indexed initiatorId,
        TaskType taskType,
        uint256 deadline
    );
    
    event TaskUpdated(
        bytes32 indexed taskId,
        TaskStatus status,
        uint256 timestamp
    );
    
    event CoordinationUpdated(
        bytes32 indexed coordinationId,
        uint256 activeAgents,
        uint256 timestamp
    );
    
    constructor(
        address _registry,
        address _stateManager,
        address _communication
    ) {
        registry = AgentRegistry(_registry);
        stateManager = AgentStateManager(_stateManager);
        communication = AgentCommunication(_communication);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COORDINATOR_ROLE, msg.sender);
    }
    
    function createTask(
        bytes32 initiatorId,
        TaskType taskType,
        bytes32[] calldata participants,
        uint256 deadline,
        bytes calldata data
    ) external onlyRole(COORDINATOR_ROLE) nonReentrant returns (bytes32) {
        require(participants.length <= MAX_PARTICIPANTS, "Too many participants");
        require(deadline > block.timestamp, "Invalid deadline");
        
        bytes32 taskId = generateTaskId(initiatorId, taskType, block.timestamp);
        
        Task storage task = tasks[taskId];
        task.taskId = taskId;
        task.initiatorId = initiatorId;
        task.taskType = taskType;
        task.participants = participants;
        task.startTime = block.timestamp;
        task.deadline = deadline;
        task.status = TaskStatus.Pending;
        task.data = data;
        
        // Update coordination
        Coordination storage coord = coordinations[initiatorId];
        coord.agentTasks[initiatorId].push(taskId);
        
        // Notify participants
        for (uint i = 0; i < participants.length; i++) {
            bytes32 participantId = participants[i];
            coord.agentTasks[participantId].push(taskId);
            
            // Send coordination message
            communication.sendMessage(
                participantId,
                IAgentCommunication.MessageType.Coordination,
                abi.encode(taskId, taskType, deadline)
            );
        }
        
        emit TaskCreated(taskId, initiatorId, taskType, deadline);
        return taskId;
    }
    
    function updateTaskStatus(
        bytes32 taskId,
        bytes32 agentId,
        TaskStatus status
    ) external onlyRole(COORDINATOR_ROLE) {
        Task storage task = tasks[taskId];
        require(task.taskId == taskId, "Task not found");
        require(isParticipant(task, agentId), "Not a participant");
        
        if (status == TaskStatus.Completed) {
            task.completed[agentId] = true;
            if (allParticipantsCompleted(task)) {
                task.status = TaskStatus.Completed;
            }
        } else {
            task.status = status;
        }
        
        // Update collaboration scores
        if (status == TaskStatus.Completed) {
            updateCollaborationScores(task);
        }
        
        emit TaskUpdated(taskId, status, block.timestamp);
    }
    
    function coordinateAgents(
        bytes32 coordinationId
    ) external onlyRole(COORDINATOR_ROLE) {
        Coordination storage coord = coordinations[coordinationId];
        require(
            block.timestamp >= coord.lastCoordination + MIN_COORDINATION_INTERVAL,
            "Too frequent"
        );
        
        // Update active agents
        bytes32[] storage activeAgents = coord.activeAgents;
        uint256 activeCount = 0;
        
        for (uint i = 0; i < activeAgents.length; i++) {
            bytes32 agentId = activeAgents[i];
            (AgentStateManager.StateType state,,,,,,) = stateManager.getAgentState(agentId);
            
            if (state != AgentStateManager.StateType.Error && 
                state != AgentStateManager.StateType.Idle) {
                activeAgents[activeCount] = agentId;
                activeCount++;
            }
        }
        
        // Resize array
        while (activeAgents.length > activeCount) {
            activeAgents.pop();
        }
        
        coord.lastCoordination = block.timestamp;
        
        emit CoordinationUpdated(
            coordinationId,
            activeAgents.length,
            block.timestamp
        );
    }
    
    function getTaskParticipants(
        bytes32 taskId
    ) external view returns (bytes32[] memory) {
        return tasks[taskId].participants;
    }
    
    function getAgentTasks(
        bytes32 agentId
    ) external view returns (bytes32[] memory) {
        return coordinations[agentId].agentTasks[agentId];
    }
    
    function getCollaborationScore(
        bytes32 agent1,
        bytes32 agent2
    ) external view returns (uint256) {
        return collaborationScores[agent1][agent2];
    }
    
    // Internal functions
    function generateTaskId(
        bytes32 initiatorId,
        TaskType taskType,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                initiatorId,
                taskType,
                timestamp
            )
        );
    }
    
    function isParticipant(
        Task storage task,
        bytes32 agentId
    ) internal view returns (bool) {
        for (uint i = 0; i < task.participants.length; i++) {
            if (task.participants[i] == agentId) return true;
        }
        return false;
    }
    
    function allParticipantsCompleted(
        Task storage task
    ) internal view returns (bool) {
        for (uint i = 0; i < task.participants.length; i++) {
            if (!task.completed[task.participants[i]]) return false;
        }
        return true;
    }
    
    function updateCollaborationScores(Task storage task) internal {
        for (uint i = 0; i < task.participants.length; i++) {
            for (uint j = i + 1; j < task.participants.length; j++) {
                bytes32 agent1 = task.participants[i];
                bytes32 agent2 = task.participants[j];
                
                collaborationScores[agent1][agent2] += 1;
                collaborationScores[agent2][agent1] += 1;
            }
        }
    }
}
