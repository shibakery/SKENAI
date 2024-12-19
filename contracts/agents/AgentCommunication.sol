// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IAgentCommunication.sol";
import "./AgentRegistry.sol";

contract AgentCommunication is IAgentCommunication, AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    AgentRegistry public immutable registry;
    
    struct Channel {
        bytes32 channelId;
        bytes32[] participants;
        ChannelType channelType;
        uint256 creationTime;
        bool active;
        mapping(bytes32 => bool) authorized;
    }
    
    struct Protocol {
        bytes32 protocolId;
        string name;
        bytes32[] requiredCapabilities;
        mapping(bytes32 => bool) supportedMessageTypes;
        bool active;
    }
    
    enum ChannelType {
        Direct,
        Group,
        Broadcast,
        Protocol
    }
    
    // Enhanced message structure
    struct EnhancedMessage {
        Message baseMessage;
        bytes32 channelId;
        bytes32 protocolId;
        bytes32 conversationId;
        uint256 sequence;
        MessagePriority priority;
        bytes32[] references;
        mapping(bytes32 => bool) acknowledgments;
    }
    
    enum MessagePriority {
        Low,
        Normal,
        High,
        Critical
    }
    
    // Storage
    mapping(bytes32 => Channel) public channels;
    mapping(bytes32 => Protocol) public protocols;
    mapping(bytes32 => EnhancedMessage) public enhancedMessages;
    mapping(bytes32 => bytes32[]) public agentChannels;
    mapping(bytes32 => bytes32[]) public conversationMessages;
    
    // Events
    event ChannelCreated(
        bytes32 indexed channelId,
        ChannelType channelType,
        bytes32[] participants
    );
    
    event ProtocolRegistered(
        bytes32 indexed protocolId,
        string name,
        bytes32[] capabilities
    );
    
    event MessageAcknowledged(
        bytes32 indexed messageId,
        bytes32 indexed acknowledger,
        uint256 timestamp
    );
    
    constructor(address _registry) {
        registry = AgentRegistry(_registry);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }
    
    function createChannel(
        bytes32[] calldata participants,
        ChannelType channelType,
        bytes32 protocolId
    ) external onlyRole(OPERATOR_ROLE) returns (bytes32) {
        bytes32 channelId = generateChannelId(participants, channelType);
        
        Channel storage channel = channels[channelId];
        channel.channelId = channelId;
        channel.participants = participants;
        channel.channelType = channelType;
        channel.creationTime = block.timestamp;
        channel.active = true;
        
        for (uint i = 0; i < participants.length; i++) {
            channel.authorized[participants[i]] = true;
            agentChannels[participants[i]].push(channelId);
        }
        
        emit ChannelCreated(channelId, channelType, participants);
        return channelId;
    }
    
    function registerProtocol(
        string calldata name,
        bytes32[] calldata requiredCapabilities,
        MessageType[] calldata supportedTypes
    ) external onlyRole(OPERATOR_ROLE) returns (bytes32) {
        bytes32 protocolId = keccak256(
            abi.encodePacked(name, block.timestamp)
        );
        
        Protocol storage protocol = protocols[protocolId];
        protocol.protocolId = protocolId;
        protocol.name = name;
        protocol.requiredCapabilities = requiredCapabilities;
        protocol.active = true;
        
        for (uint i = 0; i < supportedTypes.length; i++) {
            protocol.supportedMessageTypes[bytes32(uint256(supportedTypes[i]))] = true;
        }
        
        emit ProtocolRegistered(protocolId, name, requiredCapabilities);
        return protocolId;
    }
    
    function sendMessage(
        bytes32 toAgentId,
        MessageType messageType,
        bytes calldata data
    ) external override returns (bytes32) {
        bytes32 messageId = generateMessageId();
        
        Message memory baseMessage = Message({
            messageId: messageId,
            fromAgentId: msg.sender,
            toAgentId: toAgentId,
            messageType: messageType,
            data: data,
            timestamp: block.timestamp,
            processed: false
        });
        
        EnhancedMessage storage enhancedMsg = enhancedMessages[messageId];
        enhancedMsg.baseMessage = baseMessage;
        enhancedMsg.priority = MessagePriority.Normal;
        enhancedMsg.sequence = conversationMessages[messageId].length + 1;
        
        conversationMessages[messageId].push(messageId);
        
        emit MessageSent(messageId, msg.sender, toAgentId, messageType);
        return messageId;
    }
    
    function sendProtocolMessage(
        bytes32 channelId,
        bytes32 protocolId,
        MessageType messageType,
        bytes calldata data,
        MessagePriority priority,
        bytes32[] calldata references
    ) external returns (bytes32) {
        require(isAuthorized(channelId, msg.sender), "Not authorized");
        require(isProtocolSupported(protocolId, messageType), "Protocol mismatch");
        
        bytes32 messageId = generateMessageId();
        Channel storage channel = channels[channelId];
        
        Message memory baseMessage = Message({
            messageId: messageId,
            fromAgentId: msg.sender,
            toAgentId: bytes32(0), // Broadcast to channel
            messageType: messageType,
            data: data,
            timestamp: block.timestamp,
            processed: false
        });
        
        EnhancedMessage storage enhancedMsg = enhancedMessages[messageId];
        enhancedMsg.baseMessage = baseMessage;
        enhancedMsg.channelId = channelId;
        enhancedMsg.protocolId = protocolId;
        enhancedMsg.priority = priority;
        enhancedMsg.references = references;
        enhancedMsg.sequence = conversationMessages[channelId].length + 1;
        
        conversationMessages[channelId].push(messageId);
        
        emit MessageSent(messageId, msg.sender, bytes32(0), messageType);
        return messageId;
    }
    
    function acknowledgeMessage(
        bytes32 messageId
    ) external returns (bool) {
        EnhancedMessage storage message = enhancedMessages[messageId];
        require(!message.acknowledgments[msg.sender], "Already acknowledged");
        
        message.acknowledgments[msg.sender] = true;
        
        emit MessageAcknowledged(messageId, msg.sender, block.timestamp);
        return true;
    }
    
    function getChannelMessages(
        bytes32 channelId
    ) external view returns (bytes32[] memory) {
        return conversationMessages[channelId];
    }
    
    function getMessageAcknowledgments(
        bytes32 messageId,
        bytes32[] calldata participants
    ) external view returns (bool[] memory) {
        bool[] memory acks = new bool[](participants.length);
        for (uint i = 0; i < participants.length; i++) {
            acks[i] = enhancedMessages[messageId].acknowledgments[participants[i]];
        }
        return acks;
    }
    
    // Internal functions
    function generateChannelId(
        bytes32[] memory participants,
        ChannelType channelType
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                participants,
                channelType,
                block.timestamp
            )
        );
    }
    
    function generateMessageId() internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                msg.sender,
                block.timestamp,
                block.number
            )
        );
    }
    
    function isAuthorized(
        bytes32 channelId,
        bytes32 agentId
    ) internal view returns (bool) {
        return channels[channelId].authorized[agentId];
    }
    
    function isProtocolSupported(
        bytes32 protocolId,
        MessageType messageType
    ) internal view returns (bool) {
        return protocols[protocolId].supportedMessageTypes[
            bytes32(uint256(messageType))
        ];
    }
}
