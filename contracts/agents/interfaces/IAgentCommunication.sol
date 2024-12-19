// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IAgentCommunication {
    enum MessageType {
        Task,
        Response,
        Validation,
        Coordination,
        SystemUpdate
    }
    
    struct Message {
        bytes32 messageId;
        bytes32 fromAgentId;
        bytes32 toAgentId;
        MessageType messageType;
        bytes data;
        uint256 timestamp;
        bool processed;
    }
    
    event MessageSent(
        bytes32 indexed messageId,
        bytes32 indexed fromAgentId,
        bytes32 indexed toAgentId,
        MessageType messageType
    );
    
    event MessageProcessed(
        bytes32 indexed messageId,
        bytes32 indexed processorAgentId
    );
    
    function sendMessage(
        bytes32 toAgentId,
        MessageType messageType,
        bytes calldata data
    ) external returns (bytes32 messageId);
    
    function processMessage(bytes32 messageId) external returns (bool);
    
    function getMessage(bytes32 messageId) external view returns (
        bytes32 fromAgentId,
        bytes32 toAgentId,
        MessageType messageType,
        bytes memory data,
        uint256 timestamp,
        bool processed
    );
    
    function getAgentMessages(bytes32 agentId) external view returns (bytes32[] memory);
    
    function getPendingMessages(bytes32 agentId) external view returns (bytes32[] memory);
}
