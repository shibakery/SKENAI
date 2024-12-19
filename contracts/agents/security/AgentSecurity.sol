// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../AgentRegistry.sol";

contract AgentSecurity is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant SECURITY_ADMIN_ROLE = keccak256("SECURITY_ADMIN_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    
    AgentRegistry public immutable registry;
    
    struct SecurityProfile {
        bytes32 agentId;
        uint256 securityScore;
        uint256 riskLevel;
        uint256 lastAuditTime;
        uint256 auditCount;
        bool isVerified;
        mapping(bytes32 => bool) approvedCapabilities;
        mapping(bytes32 => uint256) capabilityRisks;
    }
    
    struct AuditRecord {
        uint256 auditId;
        bytes32 agentId;
        uint256 timestamp;
        uint256 previousScore;
        uint256 newScore;
        bytes32 auditor;
        string findings;
        bool passed;
    }
    
    struct RiskAssessment {
        uint256 baseRisk;
        uint256 capabilityRisk;
        uint256 interactionRisk;
        uint256 reputationImpact;
        uint256 lastUpdateTime;
    }
    
    struct CapabilityControl {
        bytes32 capabilityId;
        uint256 riskLevel;
        bool requiresApproval;
        bool requiresAudit;
        mapping(bytes32 => bool) approvedAgents;
    }
    
    struct SecurityIncident {
        uint256 incidentId;
        bytes32 agentId;
        uint256 timestamp;
        uint256 severity;
        string description;
        bool resolved;
        uint256 resolutionTime;
    }
    
    // Storage
    mapping(bytes32 => SecurityProfile) public securityProfiles;
    mapping(uint256 => AuditRecord) public auditRecords;
    mapping(bytes32 => RiskAssessment) public riskAssessments;
    mapping(bytes32 => CapabilityControl) public capabilityControls;
    mapping(uint256 => SecurityIncident) public securityIncidents;
    
    // Counters
    uint256 public auditCount;
    uint256 public incidentCount;
    
    // Constants
    uint256 public constant MAX_RISK_LEVEL = 100;
    uint256 public constant MIN_AUDIT_INTERVAL = 30 days;
    uint256 public constant HIGH_RISK_THRESHOLD = 75;
    
    // Events
    event SecurityProfileCreated(
        bytes32 indexed agentId,
        uint256 initialScore,
        uint256 riskLevel
    );
    
    event AuditCompleted(
        uint256 indexed auditId,
        bytes32 indexed agentId,
        uint256 newScore,
        bool passed
    );
    
    event SecurityIncidentReported(
        uint256 indexed incidentId,
        bytes32 indexed agentId,
        uint256 severity
    );
    
    event CapabilityApproved(
        bytes32 indexed agentId,
        bytes32 indexed capabilityId,
        uint256 riskLevel
    );
    
    constructor(address _registry) {
        registry = AgentRegistry(_registry);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SECURITY_ADMIN_ROLE, msg.sender);
        _grantRole(VALIDATOR_ROLE, msg.sender);
    }
    
    function createSecurityProfile(
        bytes32 agentId
    ) external onlyRole(SECURITY_ADMIN_ROLE) {
        require(
            registry.agents(agentId).active,
            "Agent not active"
        );
        require(
            securityProfiles[agentId].agentId == bytes32(0),
            "Profile exists"
        );
        
        uint256 initialScore = calculateInitialScore(agentId);
        uint256 riskLevel = assessInitialRisk(agentId);
        
        SecurityProfile storage profile = securityProfiles[agentId];
        profile.agentId = agentId;
        profile.securityScore = initialScore;
        profile.riskLevel = riskLevel;
        profile.lastAuditTime = block.timestamp;
        profile.auditCount = 0;
        profile.isVerified = false;
        
        emit SecurityProfileCreated(agentId, initialScore, riskLevel);
    }
    
    function conductAudit(
        bytes32 agentId,
        string calldata findings,
        bool passed
    ) external onlyRole(VALIDATOR_ROLE) whenNotPaused {
        SecurityProfile storage profile = securityProfiles[agentId];
        require(profile.agentId != bytes32(0), "Profile not found");
        require(
            block.timestamp >= profile.lastAuditTime + MIN_AUDIT_INTERVAL,
            "Audit too soon"
        );
        
        uint256 previousScore = profile.securityScore;
        uint256 newScore = calculateAuditScore(agentId, passed, findings);
        
        // Update profile
        profile.securityScore = newScore;
        profile.lastAuditTime = block.timestamp;
        profile.auditCount++;
        
        if (passed) {
            profile.isVerified = true;
        }
        
        // Create audit record
        uint256 auditId = ++auditCount;
        auditRecords[auditId] = AuditRecord({
            auditId: auditId,
            agentId: agentId,
            timestamp: block.timestamp,
            previousScore: previousScore,
            newScore: newScore,
            auditor: bytes32(uint256(uint160(msg.sender))),
            findings: findings,
            passed: passed
        });
        
        emit AuditCompleted(auditId, agentId, newScore, passed);
    }
    
    function approveCapability(
        bytes32 agentId,
        bytes32 capabilityId
    ) external onlyRole(SECURITY_ADMIN_ROLE) {
        SecurityProfile storage profile = securityProfiles[agentId];
        require(profile.agentId != bytes32(0), "Profile not found");
        require(profile.isVerified, "Agent not verified");
        
        CapabilityControl storage control = capabilityControls[capabilityId];
        require(control.capabilityId != bytes32(0), "Capability not registered");
        
        if (control.requiresAudit) {
            require(
                block.timestamp - profile.lastAuditTime <= 90 days,
                "Recent audit required"
            );
        }
        
        profile.approvedCapabilities[capabilityId] = true;
        profile.capabilityRisks[capabilityId] = control.riskLevel;
        control.approvedAgents[agentId] = true;
        
        // Update risk assessment
        updateRiskAssessment(agentId);
        
        emit CapabilityApproved(agentId, capabilityId, control.riskLevel);
    }
    
    function reportSecurityIncident(
        bytes32 agentId,
        uint256 severity,
        string calldata description
    ) external onlyRole(VALIDATOR_ROLE) {
        require(severity <= MAX_RISK_LEVEL, "Invalid severity");
        require(securityProfiles[agentId].agentId != bytes32(0), "Profile not found");
        
        uint256 incidentId = ++incidentCount;
        securityIncidents[incidentId] = SecurityIncident({
            incidentId: incidentId,
            agentId: agentId,
            timestamp: block.timestamp,
            severity: severity,
            description: description,
            resolved: false,
            resolutionTime: 0
        });
        
        // Update security score and risk level
        updateSecurityMetrics(agentId, severity);
        
        emit SecurityIncidentReported(incidentId, agentId, severity);
    }
    
    function resolveSecurityIncident(
        uint256 incidentId
    ) external onlyRole(SECURITY_ADMIN_ROLE) {
        SecurityIncident storage incident = securityIncidents[incidentId];
        require(!incident.resolved, "Already resolved");
        
        incident.resolved = true;
        incident.resolutionTime = block.timestamp;
        
        // Update security metrics after resolution
        updateSecurityMetrics(incident.agentId, 0);
    }
    
    // Internal functions
    function calculateInitialScore(
        bytes32 agentId
    ) internal view returns (uint256) {
        // Implementation for initial score calculation
        return 50; // Base score
    }
    
    function assessInitialRisk(
        bytes32 agentId
    ) internal view returns (uint256) {
        // Implementation for initial risk assessment
        return 50; // Base risk
    }
    
    function calculateAuditScore(
        bytes32 agentId,
        bool passed,
        string calldata findings
    ) internal view returns (uint256) {
        // Implementation for audit score calculation
        return passed ? 80 : 40;
    }
    
    function updateRiskAssessment(
        bytes32 agentId
    ) internal {
        SecurityProfile storage profile = securityProfiles[agentId];
        RiskAssessment storage assessment = riskAssessments[agentId];
        
        // Update risk metrics
        assessment.lastUpdateTime = block.timestamp;
        
        if (assessment.baseRisk >= HIGH_RISK_THRESHOLD) {
            _pause();
        }
    }
    
    function updateSecurityMetrics(
        bytes32 agentId,
        uint256 severity
    ) internal {
        SecurityProfile storage profile = securityProfiles[agentId];
        
        // Update security score based on severity
        if (severity > 0) {
            profile.securityScore = profile.securityScore > severity ? 
                profile.securityScore - severity : 0;
        }
        
        // Update risk level
        profile.riskLevel = calculateRiskLevel(profile);
    }
    
    function calculateRiskLevel(
        SecurityProfile storage profile
    ) internal view returns (uint256) {
        // Implementation for risk level calculation
        return (MAX_RISK_LEVEL - profile.securityScore);
    }
    
    // View functions
    function getSecurityProfile(
        bytes32 agentId
    ) external view returns (
        uint256 securityScore,
        uint256 riskLevel,
        uint256 lastAuditTime,
        uint256 auditCount,
        bool isVerified
    ) {
        SecurityProfile storage profile = securityProfiles[agentId];
        return (
            profile.securityScore,
            profile.riskLevel,
            profile.lastAuditTime,
            profile.auditCount,
            profile.isVerified
        );
    }
    
    function isCapabilityApproved(
        bytes32 agentId,
        bytes32 capabilityId
    ) external view returns (bool) {
        return securityProfiles[agentId].approvedCapabilities[capabilityId];
    }
}
