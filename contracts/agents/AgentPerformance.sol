// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./AgentRegistry.sol";

contract AgentPerformance is AccessControl, ReentrancyGuard {
    bytes32 public constant EVALUATOR_ROLE = keccak256("EVALUATOR_ROLE");
    bytes32 public constant PERFORMANCE_ADMIN_ROLE = keccak256("PERFORMANCE_ADMIN_ROLE");
    
    AgentRegistry public immutable registry;
    
    struct PerformanceMetrics {
        uint256 successRate;
        uint256 efficiency;
        uint256 qualityScore;
        uint256 innovationScore;
        uint256 collaborationScore;
        uint256 adaptabilityScore;
        uint256 totalTasks;
        uint256 completedTasks;
        uint256 lastUpdateTime;
    }
    
    struct TaskEvaluation {
        bytes32 taskId;
        bytes32 agentId;
        uint256 timestamp;
        uint256 complexity;
        uint256 executionTime;
        uint256 resourceUsage;
        uint256 qualityScore;
        bool successful;
        string feedback;
    }
    
    struct LearningProgress {
        uint256 knowledgeGrowth;
        uint256 skillDevelopment;
        uint256 adaptationRate;
        uint256 innovationIndex;
        mapping(bytes32 => uint256) domainExpertise;
        uint256 lastAssessment;
    }
    
    struct CollaborationMetrics {
        uint256 teamworkScore;
        uint256 communicationEfficiency;
        uint256 resourceSharing;
        uint256 conflictResolution;
        mapping(bytes32 => uint256) peerRatings;
        uint256 totalCollaborations;
    }
    
    struct PerformanceHistory {
        mapping(uint256 => TaskEvaluation) taskEvaluations;
        uint256[] evaluationTimestamps;
        uint256 averagePerformance;
        uint256 performanceTrend;
        uint256 lastCalculated;
    }
    
    // Storage
    mapping(bytes32 => PerformanceMetrics) public performanceMetrics;
    mapping(bytes32 => TaskEvaluation[]) public taskEvaluations;
    mapping(bytes32 => LearningProgress) public learningProgress;
    mapping(bytes32 => CollaborationMetrics) public collaborationMetrics;
    mapping(bytes32 => PerformanceHistory) public performanceHistory;
    
    // Performance thresholds
    uint256 public constant MINIMUM_QUALITY_THRESHOLD = 70;
    uint256 public constant HIGH_PERFORMANCE_THRESHOLD = 90;
    uint256 public constant EVALUATION_PERIOD = 30 days;
    
    // Events
    event TaskEvaluated(
        bytes32 indexed taskId,
        bytes32 indexed agentId,
        uint256 qualityScore,
        bool successful
    );
    
    event PerformanceUpdated(
        bytes32 indexed agentId,
        uint256 newSuccessRate,
        uint256 newEfficiency,
        uint256 qualityScore
    );
    
    event LearningAssessed(
        bytes32 indexed agentId,
        uint256 knowledgeGrowth,
        uint256 skillDevelopment,
        uint256 adaptationRate
    );
    
    event CollaborationRecorded(
        bytes32 indexed agentId,
        bytes32 indexed partnerId,
        uint256 teamworkScore,
        uint256 timestamp
    );
    
    constructor(address _registry) {
        registry = AgentRegistry(_registry);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EVALUATOR_ROLE, msg.sender);
        _grantRole(PERFORMANCE_ADMIN_ROLE, msg.sender);
    }
    
    function evaluateTask(
        bytes32 taskId,
        bytes32 agentId,
        uint256 complexity,
        uint256 executionTime,
        uint256 resourceUsage,
        uint256 qualityScore,
        bool successful,
        string calldata feedback
    ) external onlyRole(EVALUATOR_ROLE) {
        require(qualityScore <= 100, "Invalid quality score");
        require(registry.agents(agentId).active, "Agent not active");
        
        TaskEvaluation memory evaluation = TaskEvaluation({
            taskId: taskId,
            agentId: agentId,
            timestamp: block.timestamp,
            complexity: complexity,
            executionTime: executionTime,
            resourceUsage: resourceUsage,
            qualityScore: qualityScore,
            successful: successful,
            feedback: feedback
        });
        
        taskEvaluations[agentId].push(evaluation);
        updatePerformanceMetrics(agentId, evaluation);
        
        emit TaskEvaluated(taskId, agentId, qualityScore, successful);
    }
    
    function assessLearning(
        bytes32 agentId,
        uint256 knowledgeGrowth,
        uint256 skillDevelopment,
        uint256 adaptationRate,
        uint256 innovationIndex,
        bytes32[] calldata domains,
        uint256[] calldata expertiseLevels
    ) external onlyRole(PERFORMANCE_ADMIN_ROLE) {
        require(domains.length == expertiseLevels.length, "Array length mismatch");
        
        LearningProgress storage progress = learningProgress[agentId];
        progress.knowledgeGrowth = knowledgeGrowth;
        progress.skillDevelopment = skillDevelopment;
        progress.adaptationRate = adaptationRate;
        progress.innovationIndex = innovationIndex;
        progress.lastAssessment = block.timestamp;
        
        for (uint i = 0; i < domains.length; i++) {
            progress.domainExpertise[domains[i]] = expertiseLevels[i];
        }
        
        emit LearningAssessed(agentId, knowledgeGrowth, skillDevelopment, adaptationRate);
    }
    
    function recordCollaboration(
        bytes32 agentId,
        bytes32 partnerId,
        uint256 teamworkScore,
        uint256 communicationScore,
        uint256 resourceSharingScore,
        uint256 conflictResolutionScore
    ) external onlyRole(EVALUATOR_ROLE) {
        CollaborationMetrics storage metrics = collaborationMetrics[agentId];
        
        metrics.teamworkScore = (metrics.teamworkScore * metrics.totalCollaborations + teamworkScore) / 
            (metrics.totalCollaborations + 1);
        metrics.communicationEfficiency = communicationScore;
        metrics.resourceSharing = resourceSharingScore;
        metrics.conflictResolution = conflictResolutionScore;
        metrics.peerRatings[partnerId] = teamworkScore;
        metrics.totalCollaborations++;
        
        emit CollaborationRecorded(agentId, partnerId, teamworkScore, block.timestamp);
    }
    
    function calculatePerformanceTrend(
        bytes32 agentId
    ) external onlyRole(PERFORMANCE_ADMIN_ROLE) {
        PerformanceHistory storage history = performanceHistory[agentId];
        require(
            block.timestamp >= history.lastCalculated + EVALUATION_PERIOD,
            "Too soon to recalculate"
        );
        
        uint256 totalScore = 0;
        uint256 count = history.evaluationTimestamps.length;
        
        for (uint i = 0; i < count; i++) {
            TaskEvaluation storage eval = history.taskEvaluations[
                history.evaluationTimestamps[i]
            ];
            totalScore += eval.qualityScore;
        }
        
        if (count > 0) {
            history.averagePerformance = totalScore / count;
            history.performanceTrend = calculateTrend(agentId);
            history.lastCalculated = block.timestamp;
        }
    }
    
    // Internal functions
    function updatePerformanceMetrics(
        bytes32 agentId,
        TaskEvaluation memory evaluation
    ) internal {
        PerformanceMetrics storage metrics = performanceMetrics[agentId];
        
        metrics.totalTasks++;
        if (evaluation.successful) {
            metrics.completedTasks++;
        }
        
        metrics.successRate = (metrics.completedTasks * 100) / metrics.totalTasks;
        metrics.efficiency = calculateEfficiency(evaluation);
        metrics.qualityScore = evaluation.qualityScore;
        
        // Update innovation and adaptability scores
        if (evaluation.complexity > 0) {
            metrics.innovationScore = (metrics.innovationScore * 9 + 
                (evaluation.qualityScore * 100 / evaluation.complexity)) / 10;
        }
        
        metrics.adaptabilityScore = calculateAdaptabilityScore(agentId);
        metrics.lastUpdateTime = block.timestamp;
        
        emit PerformanceUpdated(
            agentId,
            metrics.successRate,
            metrics.efficiency,
            metrics.qualityScore
        );
    }
    
    function calculateEfficiency(
        TaskEvaluation memory evaluation
    ) internal pure returns (uint256) {
        if (evaluation.executionTime == 0 || evaluation.complexity == 0) {
            return 0;
        }
        
        return (evaluation.qualityScore * evaluation.complexity * 100) / 
            (evaluation.executionTime * evaluation.resourceUsage);
    }
    
    function calculateAdaptabilityScore(
        bytes32 agentId
    ) internal view returns (uint256) {
        LearningProgress storage progress = learningProgress[agentId];
        return (progress.adaptationRate * 60 + progress.innovationIndex * 40) / 100;
    }
    
    function calculateTrend(
        bytes32 agentId
    ) internal view returns (uint256) {
        PerformanceHistory storage history = performanceHistory[agentId];
        if (history.evaluationTimestamps.length < 2) {
            return 100; // Neutral trend
        }
        
        uint256 recentPerformance = getRecentPerformance(agentId);
        if (recentPerformance > history.averagePerformance) {
            return 100 + ((recentPerformance - history.averagePerformance) * 100 / 
                history.averagePerformance);
        } else {
            return 100 - ((history.averagePerformance - recentPerformance) * 100 / 
                history.averagePerformance);
        }
    }
    
    function getRecentPerformance(
        bytes32 agentId
    ) internal view returns (uint256) {
        TaskEvaluation[] storage evaluations = taskEvaluations[agentId];
        if (evaluations.length == 0) {
            return 0;
        }
        
        uint256 total = 0;
        uint256 count = 0;
        uint256 recentPeriod = block.timestamp - EVALUATION_PERIOD;
        
        for (uint i = evaluations.length; i > 0; i--) {
            if (evaluations[i-1].timestamp < recentPeriod) {
                break;
            }
            total += evaluations[i-1].qualityScore;
            count++;
        }
        
        return count > 0 ? total / count : 0;
    }
    
    // View functions
    function getPerformanceMetrics(
        bytes32 agentId
    ) external view returns (
        uint256 successRate,
        uint256 efficiency,
        uint256 qualityScore,
        uint256 innovationScore,
        uint256 adaptabilityScore,
        uint256 totalTasks
    ) {
        PerformanceMetrics storage metrics = performanceMetrics[agentId];
        return (
            metrics.successRate,
            metrics.efficiency,
            metrics.qualityScore,
            metrics.innovationScore,
            metrics.adaptabilityScore,
            metrics.totalTasks
        );
    }
    
    function getLearningMetrics(
        bytes32 agentId
    ) external view returns (
        uint256 knowledgeGrowth,
        uint256 skillDevelopment,
        uint256 adaptationRate,
        uint256 innovationIndex,
        uint256 lastAssessment
    ) {
        LearningProgress storage progress = learningProgress[agentId];
        return (
            progress.knowledgeGrowth,
            progress.skillDevelopment,
            progress.adaptationRate,
            progress.innovationIndex,
            progress.lastAssessment
        );
    }
    
    function getCollaborationMetrics(
        bytes32 agentId
    ) external view returns (
        uint256 teamworkScore,
        uint256 communicationEfficiency,
        uint256 resourceSharing,
        uint256 conflictResolution,
        uint256 totalCollaborations
    ) {
        CollaborationMetrics storage metrics = collaborationMetrics[agentId];
        return (
            metrics.teamworkScore,
            metrics.communicationEfficiency,
            metrics.resourceSharing,
            metrics.conflictResolution,
            metrics.totalCollaborations
        );
    }
}
