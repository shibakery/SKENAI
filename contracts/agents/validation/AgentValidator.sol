// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../AgentRegistry.sol";
import "../AgentPerformance.sol";
import "../security/AgentSecurity.sol";

contract AgentValidator is AccessControl, ReentrancyGuard {
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    
    AgentRegistry public immutable registry;
    AgentPerformance public immutable performance;
    AgentSecurity public immutable security;
    
    struct ValidationRule {
        bytes32 ruleId;
        string name;
        uint256 weight;
        bool isActive;
        ValidationCategory category;
    }
    
    struct ValidationResult {
        bytes32 resultId;
        bytes32 agentId;
        bytes32 ruleId;
        bool passed;
        uint256 score;
        uint256 timestamp;
        address validator;
    }
    
    enum ValidationCategory {
        Performance,
        Security,
        Compliance,
        Quality,
        Reliability
    }
    
    struct ValidationMetrics {
        uint256 totalValidations;
        uint256 passedValidations;
        uint256 failedValidations;
        uint256 averageScore;
        uint256 lastValidation;
    }
    
    // Validation storage
    mapping(bytes32 => ValidationRule) public rules;
    mapping(bytes32 => ValidationResult[]) public results;
    mapping(bytes32 => ValidationMetrics) public metrics;
    mapping(bytes32 => mapping(ValidationCategory => bytes32[])) public categoryRules;
    
    // Thresholds
    uint256 public constant MIN_VALIDATION_SCORE = 70;
    uint256 public constant MAX_VALIDATION_WEIGHT = 100;
    uint256 public constant VALIDATION_COOLDOWN = 1 hours;
    
    event RuleCreated(
        bytes32 indexed ruleId,
        string name,
        uint256 weight,
        ValidationCategory category
    );
    
    event ValidationPerformed(
        bytes32 indexed resultId,
        bytes32 indexed agentId,
        bytes32 indexed ruleId,
        bool passed,
        uint256 score
    );
    
    event ValidationMetricsUpdated(
        bytes32 indexed agentId,
        uint256 totalValidations,
        uint256 passedValidations,
        uint256 averageScore
    );
    
    constructor(
        address _registry,
        address _performance,
        address _security
    ) {
        registry = AgentRegistry(_registry);
        performance = AgentPerformance(_performance);
        security = AgentSecurity(_security);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VALIDATOR_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
    }
    
    function createRule(
        string calldata name,
        uint256 weight,
        ValidationCategory category
    ) external onlyRole(VALIDATOR_ROLE) returns (bytes32) {
        require(weight <= MAX_VALIDATION_WEIGHT, "Weight too high");
        
        bytes32 ruleId = keccak256(
            abi.encodePacked(name, category, block.timestamp)
        );
        
        rules[ruleId] = ValidationRule({
            ruleId: ruleId,
            name: name,
            weight: weight,
            isActive: true,
            category: category
        });
        
        categoryRules[ruleId][category].push(ruleId);
        
        emit RuleCreated(ruleId, name, weight, category);
        return ruleId;
    }
    
    function validate(
        bytes32 agentId,
        bytes32 ruleId,
        uint256 score
    ) external onlyRole(VALIDATOR_ROLE) nonReentrant returns (bytes32) {
        ValidationRule storage rule = rules[ruleId];
        require(rule.isActive, "Rule not active");
        require(
            block.timestamp >= metrics[agentId].lastValidation + VALIDATION_COOLDOWN,
            "Validation cooldown"
        );
        
        bool passed = score >= MIN_VALIDATION_SCORE;
        bytes32 resultId = generateResultId(agentId, ruleId, score);
        
        // Create validation result
        ValidationResult memory result = ValidationResult({
            resultId: resultId,
            agentId: agentId,
            ruleId: ruleId,
            passed: passed,
            score: score,
            timestamp: block.timestamp,
            validator: msg.sender
        });
        
        results[agentId].push(result);
        
        // Update metrics
        updateMetrics(agentId, passed, score);
        
        // Update performance and security if needed
        if (!passed) {
            if (rule.category == ValidationCategory.Security) {
                security.reportViolation(agentId, "VALIDATION_FAILURE");
            }
            performance.updateAgentMetrics(agentId, score);
        }
        
        emit ValidationPerformed(resultId, agentId, ruleId, passed, score);
        return resultId;
    }
    
    function validateBatch(
        bytes32 agentId,
        bytes32[] calldata ruleIds,
        uint256[] calldata scores
    ) external onlyRole(VALIDATOR_ROLE) nonReentrant {
        require(ruleIds.length == scores.length, "Length mismatch");
        
        for (uint i = 0; i < ruleIds.length; i++) {
            validate(agentId, ruleIds[i], scores[i]);
        }
    }
    
    function deactivateRule(
        bytes32 ruleId
    ) external onlyRole(VALIDATOR_ROLE) {
        require(rules[ruleId].isActive, "Rule not active");
        rules[ruleId].isActive = false;
    }
    
    function getValidationResults(
        bytes32 agentId
    ) external view returns (ValidationResult[] memory) {
        return results[agentId];
    }
    
    function getCategoryRules(
        ValidationCategory category
    ) external view returns (bytes32[] memory) {
        bytes32 categoryKey = keccak256(abi.encodePacked(category));
        return categoryRules[categoryKey][category];
    }
    
    // Internal functions
    function generateResultId(
        bytes32 agentId,
        bytes32 ruleId,
        uint256 score
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                agentId,
                ruleId,
                score,
                block.timestamp
            )
        );
    }
    
    function updateMetrics(
        bytes32 agentId,
        bool passed,
        uint256 score
    ) internal {
        ValidationMetrics storage metric = metrics[agentId];
        
        metric.totalValidations++;
        if (passed) {
            metric.passedValidations++;
        } else {
            metric.failedValidations++;
        }
        
        // Update average score
        metric.averageScore = (
            (metric.averageScore * (metric.totalValidations - 1) + score)
        ) / metric.totalValidations;
        
        metric.lastValidation = block.timestamp;
        
        emit ValidationMetricsUpdated(
            agentId,
            metric.totalValidations,
            metric.passedValidations,
            metric.averageScore
        );
    }
}
