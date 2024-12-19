// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./AgentRegistry.sol";

contract AgentMemory is AccessControl, ReentrancyGuard {
    bytes32 public constant MEMORY_MANAGER_ROLE = keccak256("MEMORY_MANAGER_ROLE");
    
    AgentRegistry public immutable registry;
    
    enum MemoryType {
        ShortTerm,
        WorkingMemory,
        LongTerm,
        SharedMemory
    }
    
    struct Memory {
        bytes32 memoryId;
        MemoryType memoryType;
        bytes32 agentId;
        bytes data;
        uint256 timestamp;
        uint256 lastAccessed;
        uint256 accessCount;
        uint256 importance;
        bool isShared;
    }
    
    struct MemoryPointer {
        bytes32 memoryId;
        uint256 importance;
        uint256 lastAccessed;
    }
    
    // Memory storage
    mapping(bytes32 => Memory) public memories;
    mapping(bytes32 => mapping(MemoryType => bytes32[])) public agentMemories;
    mapping(bytes32 => bytes32[]) public sharedMemories;
    
    // Memory metrics
    mapping(bytes32 => uint256) public memoryUsage;
    mapping(bytes32 => uint256) public lastConsolidation;
    
    uint256 public constant MAX_MEMORY_SIZE = 1024 * 1024; // 1MB
    uint256 public constant CONSOLIDATION_PERIOD = 1 days;
    uint256 public constant MAX_MEMORIES_PER_TYPE = 1000;
    
    event MemoryStored(
        bytes32 indexed memoryId,
        bytes32 indexed agentId,
        MemoryType memoryType,
        uint256 importance
    );
    
    event MemoryAccessed(
        bytes32 indexed memoryId,
        bytes32 indexed agentId,
        uint256 timestamp
    );
    
    event MemoryConsolidated(
        bytes32 indexed agentId,
        uint256 memoriesProcessed,
        uint256 memoriesRetained
    );
    
    event MemoryShared(
        bytes32 indexed memoryId,
        bytes32 indexed fromAgent,
        bytes32 indexed toAgent
    );
    
    constructor(address _registry) {
        registry = AgentRegistry(_registry);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MEMORY_MANAGER_ROLE, msg.sender);
    }
    
    function storeMemory(
        bytes32 agentId,
        MemoryType memoryType,
        bytes calldata data,
        uint256 importance,
        bool isShared
    ) external onlyRole(MEMORY_MANAGER_ROLE) nonReentrant returns (bytes32) {
        require(data.length <= MAX_MEMORY_SIZE, "Memory too large");
        require(
            agentMemories[agentId][memoryType].length < MAX_MEMORIES_PER_TYPE,
            "Memory limit reached"
        );
        
        bytes32 memoryId = generateMemoryId(agentId, data);
        
        memories[memoryId] = Memory({
            memoryId: memoryId,
            memoryType: memoryType,
            agentId: agentId,
            data: data,
            timestamp: block.timestamp,
            lastAccessed: block.timestamp,
            accessCount: 1,
            importance: importance,
            isShared: isShared
        });
        
        agentMemories[agentId][memoryType].push(memoryId);
        memoryUsage[agentId] += data.length;
        
        if (isShared) {
            sharedMemories[agentId].push(memoryId);
        }
        
        emit MemoryStored(memoryId, agentId, memoryType, importance);
        return memoryId;
    }
    
    function accessMemory(
        bytes32 memoryId,
        bytes32 agentId
    ) external onlyRole(MEMORY_MANAGER_ROLE) returns (bytes memory) {
        Memory storage memory_ = memories[memoryId];
        require(memory_.memoryId == memoryId, "Memory not found");
        require(
            memory_.agentId == agentId || memory_.isShared,
            "Memory access denied"
        );
        
        memory_.lastAccessed = block.timestamp;
        memory_.accessCount++;
        
        emit MemoryAccessed(memoryId, agentId, block.timestamp);
        return memory_.data;
    }
    
    function shareMemory(
        bytes32 memoryId,
        bytes32 toAgentId
    ) external onlyRole(MEMORY_MANAGER_ROLE) {
        Memory storage memory_ = memories[memoryId];
        require(memory_.memoryId == memoryId, "Memory not found");
        require(!memory_.isShared, "Already shared");
        
        memory_.isShared = true;
        sharedMemories[toAgentId].push(memoryId);
        
        emit MemoryShared(memoryId, memory_.agentId, toAgentId);
    }
    
    function consolidateMemories(
        bytes32 agentId
    ) external onlyRole(MEMORY_MANAGER_ROLE) returns (uint256, uint256) {
        require(
            block.timestamp >= lastConsolidation[agentId] + CONSOLIDATION_PERIOD,
            "Too soon to consolidate"
        );
        
        uint256 processed = 0;
        uint256 retained = 0;
        
        // Process short-term memories
        bytes32[] storage shortTermMemories = agentMemories[agentId][MemoryType.ShortTerm];
        for (uint i = 0; i < shortTermMemories.length; i++) {
            bytes32 memoryId = shortTermMemories[i];
            Memory storage memory_ = memories[memoryId];
            
            processed++;
            
            // Retain important or frequently accessed memories
            if (shouldRetainMemory(memory_)) {
                // Move to long-term memory
                memory_.memoryType = MemoryType.LongTerm;
                agentMemories[agentId][MemoryType.LongTerm].push(memoryId);
                retained++;
            } else {
                // Remove memory
                delete memories[memoryId];
                memoryUsage[agentId] -= memory_.data.length;
            }
        }
        
        // Clear short-term memories
        delete agentMemories[agentId][MemoryType.ShortTerm];
        lastConsolidation[agentId] = block.timestamp;
        
        emit MemoryConsolidated(agentId, processed, retained);
        return (processed, retained);
    }
    
    function getMemories(
        bytes32 agentId,
        MemoryType memoryType
    ) external view returns (MemoryPointer[] memory) {
        bytes32[] storage memoryIds = agentMemories[agentId][memoryType];
        MemoryPointer[] memory pointers = new MemoryPointer[](memoryIds.length);
        
        for (uint i = 0; i < memoryIds.length; i++) {
            Memory storage memory_ = memories[memoryIds[i]];
            pointers[i] = MemoryPointer({
                memoryId: memory_.memoryId,
                importance: memory_.importance,
                lastAccessed: memory_.lastAccessed
            });
        }
        
        return pointers;
    }
    
    function getSharedMemories(
        bytes32 agentId
    ) external view returns (MemoryPointer[] memory) {
        bytes32[] storage memoryIds = sharedMemories[agentId];
        MemoryPointer[] memory pointers = new MemoryPointer[](memoryIds.length);
        
        for (uint i = 0; i < memoryIds.length; i++) {
            Memory storage memory_ = memories[memoryIds[i]];
            pointers[i] = MemoryPointer({
                memoryId: memory_.memoryId,
                importance: memory_.importance,
                lastAccessed: memory_.lastAccessed
            });
        }
        
        return pointers;
    }
    
    // Internal functions
    function generateMemoryId(
        bytes32 agentId,
        bytes calldata data
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                agentId,
                data,
                block.timestamp,
                block.number
            )
        );
    }
    
    function shouldRetainMemory(
        Memory storage memory_
    ) internal view returns (bool) {
        // Retain if:
        // 1. High importance
        if (memory_.importance >= 80) return true;
        
        // 2. Frequently accessed
        if (memory_.accessCount >= 5) return true;
        
        // 3. Recently accessed
        if (block.timestamp - memory_.lastAccessed <= 1 days) return true;
        
        // 4. Shared memory
        if (memory_.isShared) return true;
        
        return false;
    }
}
