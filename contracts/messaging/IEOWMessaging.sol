// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IEOWMessaging
 * @dev Interface for the Evolution of Work (EOW) messaging protocol
 */
interface IEOWMessaging {
    enum ConversationType {
        DirectMessage,
        TeamChat,
        AIAssisted,
        ProjectCoordination,
        ProposalDiscussion
    }

    struct Conversation {
        bytes32 conversationId;
        ConversationType conversationType;
        address[] participants;
        bytes32[] aiListeners;
        bool isEncrypted;
        uint256 createdAt;
        bool isActive;
    }

    struct Message {
        bytes32 messageId;
        bytes32 conversationId;
        address sender;
        bytes encryptedContent;
        bytes32[] mentionedAgents;
        uint256 timestamp;
        bytes signature;
    }

    event ConversationCreated(
        bytes32 indexed conversationId,
        ConversationType conversationType,
        address creator
    );

    event MessageSent(
        bytes32 indexed conversationId,
        bytes32 indexed messageId,
        address indexed sender
    );

    event AIAgentJoined(
        bytes32 indexed conversationId,
        bytes32 indexed agentId
    );

    /**
     * @dev Creates a new conversation
     * @param conversationType Type of conversation to create
     * @param participants Initial participants in the conversation
     * @param aiListeners AI agents allowed to monitor the conversation
     * @return conversationId The ID of the created conversation
     */
    function createConversation(
        ConversationType conversationType,
        address[] calldata participants,
        bytes32[] calldata aiListeners
    ) external returns (bytes32 conversationId);

    /**
     * @dev Sends a message in a conversation
     * @param conversationId The conversation to send the message in
     * @param encryptedContent The encrypted message content
     * @param mentionedAgents Any AI agents mentioned/tagged in the message
     * @return messageId The ID of the sent message
     */
    function sendMessage(
        bytes32 conversationId,
        bytes calldata encryptedContent,
        bytes32[] calldata mentionedAgents
    ) external returns (bytes32 messageId);

    /**
     * @dev Allows an AI agent to join a conversation as a listener
     * @param conversationId The conversation to join
     * @param agentId The ID of the AI agent
     * @param signature Cryptographic proof of agent's authorization
     */
    function joinAsAIListener(
        bytes32 conversationId,
        bytes32 agentId,
        bytes calldata signature
    ) external;
}
