// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AgentRegistry is AccessControl, ReentrancyGuard {
    bytes32 public constant REGISTRY_ADMIN_ROLE = keccak256("REGISTRY_ADMIN_ROLE");
    
    struct Agent {
        address owner;
        string name;
        uint256 performanceScore;
        uint256 successRate;
        uint256 reputationScore;
        AgentType agentType;
        bool active;
        uint256 registrationTime;
    }
    
    enum AgentType {
        Worker,
        Validator,
        Coordinator,
        Learner,
        Specialist
    }
    
    struct AgentCapabilities {
        bytes32[] skills;
        uint256[] skillLevels;
        bytes32[] specializations;
        bytes32[] certifications;
    }
    
    struct CollaborationNetwork {
        bytes32[] collaborators;
        mapping(bytes32 => uint256) trustScores;
        mapping(bytes32 => uint256) successfulCollaborations;
        bytes32[] learningPartners;
    }
    
    struct LearningMetrics {
        uint256 knowledgeScore;
        uint256 adaptabilityScore;
        uint256 innovationScore;
        uint256 lastUpdate;
        bytes32[] contributions;
    }
    
    // Storage
    mapping(bytes32 => Agent) public agents;
    mapping(address => bytes32[]) public ownerAgents;
    mapping(bytes32 => AgentCapabilities) public capabilities;
    mapping(bytes32 => CollaborationNetwork) public networks;
    mapping(bytes32 => LearningMetrics) public learningMetrics;
    mapping(bytes32 => mapping(bytes32 => bool)) public skillCertifications;
    
    // Events
    event AgentRegistered(
        bytes32 indexed agentId,
        address indexed owner,
        string name,
        AgentType agentType
    );
    
    event AgentUpdated(
        bytes32 indexed agentId,
        uint256 performanceScore,
        uint256 successRate,
        uint256 reputationScore
    );
    
    event CapabilitiesUpdated(
        bytes32 indexed agentId,
        bytes32[] skills,
        uint256[] skillLevels
    );
    
    event CollaborationRecorded(
        bytes32 indexed agentId,
        bytes32 indexed collaboratorId,
        uint256 trustScore
    );
    
    event LearningProgressUpdated(
        bytes32 indexed agentId,
        uint256 knowledgeScore,
        uint256 adaptabilityScore,
        uint256 innovationScore
    );
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REGISTRY_ADMIN_ROLE, msg.sender);
    }
    
    function registerAgent(
        string calldata name,
        AgentType agentType,
        bytes32[] calldata initialSkills,
        uint256[] calldata skillLevels
    ) external returns (bytes32) {
        require(bytes(name).length > 0, "Empty name");
        require(initialSkills.length == skillLevels.length, "Skills mismatch");
        
        bytes32 agentId = generateAgentId(msg.sender, name);
        
        agents[agentId] = Agent({
            owner: msg.sender,
            name: name,
            performanceScore: 0,
            successRate: 0,
            reputationScore: 0,
            agentType: agentType,
            active: true,
            registrationTime: block.timestamp
        });
        
        ownerAgents[msg.sender].push(agentId);
        
        // Initialize capabilities
        capabilities[agentId].skills = initialSkills;
        capabilities[agentId].skillLevels = skillLevels;
        
        // Initialize learning metrics
        learningMetrics[agentId] = LearningMetrics({
            knowledgeScore: 0,
            adaptabilityScore: 0,
            innovationScore: 0,
            lastUpdate: block.timestamp,
            contributions: new bytes32[](0)
        });
        
        emit AgentRegistered(agentId, msg.sender, name, agentType);
        return agentId;
    }
    
    function updateAgentMetrics(
        bytes32 agentId,
        uint256 performanceScore,
        uint256 successRate
    ) external onlyRole(REGISTRY_ADMIN_ROLE) {
        require(agents[agentId].active, "Agent not active");
        
        Agent storage agent = agents[agentId];
        agent.performanceScore = performanceScore;
        agent.successRate = successRate;
        
        // Update reputation based on performance and success
        uint256 newReputation = calculateReputation(
            performanceScore,
            successRate,
            agent.reputationScore
        );
        agent.reputationScore = newReputation;
        
        emit AgentUpdated(
            agentId,
            performanceScore,
            successRate,
            newReputation
        );
    }
    
    function recordCollaboration(
        bytes32 agentId,
        bytes32 collaboratorId,
        uint256 successScore
    ) external onlyRole(REGISTRY_ADMIN_ROLE) {
        require(agents[agentId].active && agents[collaboratorId].active, "Agents not active");
        
        CollaborationNetwork storage network = networks[agentId];
        if (!isCollaborator(network, collaboratorId)) {
            network.collaborators.push(collaboratorId);
        }
        
        network.trustScores[collaboratorId] = (
            network.trustScores[collaboratorId] * network.successfulCollaborations[collaboratorId] +
            successScore
        ) / (network.successfulCollaborations[collaboratorId] + 1);
        
        network.successfulCollaborations[collaboratorId]++;
        
        emit CollaborationRecorded(agentId, collaboratorId, successScore);
    }
    
    function updateLearningProgress(
        bytes32 agentId,
        uint256 knowledgeScore,
        uint256 adaptabilityScore,
        uint256 innovationScore,
        bytes32 contributionId
    ) external onlyRole(REGISTRY_ADMIN_ROLE) {
        require(agents[agentId].active, "Agent not active");
        
        LearningMetrics storage metrics = learningMetrics[agentId];
        metrics.knowledgeScore = knowledgeScore;
        metrics.adaptabilityScore = adaptabilityScore;
        metrics.innovationScore = innovationScore;
        metrics.lastUpdate = block.timestamp;
        
        if (contributionId != bytes32(0)) {
            metrics.contributions.push(contributionId);
        }
        
        emit LearningProgressUpdated(
            agentId,
            knowledgeScore,
            adaptabilityScore,
            innovationScore
        );
    }
    
    function addCertification(
        bytes32 agentId,
        bytes32 skillId,
        bytes32 certificationId
    ) external onlyRole(REGISTRY_ADMIN_ROLE) {
        require(agents[agentId].active, "Agent not active");
        require(hasSkill(agentId, skillId), "Skill not found");
        
        capabilities[agentId].certifications.push(certificationId);
        skillCertifications[agentId][skillId] = true;
    }
    
    function addLearningPartner(
        bytes32 agentId,
        bytes32 partnerId
    ) external onlyRole(REGISTRY_ADMIN_ROLE) {
        require(agents[agentId].active && agents[partnerId].active, "Agents not active");
        
        CollaborationNetwork storage network = networks[agentId];
        if (!isLearningPartner(network, partnerId)) {
            network.learningPartners.push(partnerId);
        }
    }
    
    // View functions
    function getAgentCapabilities(
        bytes32 agentId
    ) external view returns (
        bytes32[] memory skills,
        uint256[] memory skillLevels,
        bytes32[] memory specializations,
        bytes32[] memory certifications
    ) {
        AgentCapabilities storage caps = capabilities[agentId];
        return (
            caps.skills,
            caps.skillLevels,
            caps.specializations,
            caps.certifications
        );
    }
    
    function getCollaborationMetrics(
        bytes32 agentId,
        bytes32 collaboratorId
    ) external view returns (
        uint256 trustScore,
        uint256 successfulCollabs
    ) {
        CollaborationNetwork storage network = networks[agentId];
        return (
            network.trustScores[collaboratorId],
            network.successfulCollaborations[collaboratorId]
        );
    }
    
    function getLearningMetrics(
        bytes32 agentId
    ) external view returns (
        uint256 knowledge,
        uint256 adaptability,
        uint256 innovation,
        bytes32[] memory contributions
    ) {
        LearningMetrics storage metrics = learningMetrics[agentId];
        return (
            metrics.knowledgeScore,
            metrics.adaptabilityScore,
            metrics.innovationScore,
            metrics.contributions
        );
    }
    
    // Internal functions
    function generateAgentId(
        address owner,
        string memory name
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                owner,
                name,
                block.timestamp,
                ownerAgents[owner].length
            )
        );
    }
    
    function calculateReputation(
        uint256 performanceScore,
        uint256 successRate,
        uint256 currentReputation
    ) internal pure returns (uint256) {
        uint256 newScore = (performanceScore * 4 + successRate * 4 + currentReputation * 2) / 10;
        return newScore > 100 ? 100 : newScore;
    }
    
    function isCollaborator(
        CollaborationNetwork storage network,
        bytes32 collaboratorId
    ) internal view returns (bool) {
        for (uint i = 0; i < network.collaborators.length; i++) {
            if (network.collaborators[i] == collaboratorId) return true;
        }
        return false;
    }
    
    function isLearningPartner(
        CollaborationNetwork storage network,
        bytes32 partnerId
    ) internal view returns (bool) {
        for (uint i = 0; i < network.learningPartners.length; i++) {
            if (network.learningPartners[i] == partnerId) return true;
        }
        return false;
    }
    
    function hasSkill(
        bytes32 agentId,
        bytes32 skillId
    ) internal view returns (bool) {
        bytes32[] storage skills = capabilities[agentId].skills;
        for (uint i = 0; i < skills.length; i++) {
            if (skills[i] == skillId) return true;
        }
        return false;
    }
}
