// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../AgentRegistry.sol";
import "../AgentStateManager.sol";
import "../security/AgentSecurity.sol";

contract AgentErrorHandler is AccessControl, ReentrancyGuard {
    bytes32 public constant ERROR_HANDLER_ROLE = keccak256("ERROR_HANDLER_ROLE");
    bytes32 public constant RECOVERY_ROLE = keccak256("RECOVERY_ROLE");
    
    AgentRegistry public immutable registry;
    AgentStateManager public immutable stateManager;
    AgentSecurity public immutable security;
    
    struct Error {
        bytes32 errorId;
        bytes32 agentId;
        ErrorType errorType;
        ErrorSeverity severity;
        uint256 timestamp;
        bytes data;
        bool resolved;
        bytes32 resolution;
    }
    
    enum ErrorType {
        Execution,
        Memory,
        Security,
        Communication,
        Resource,
        Validation
    }
    
    enum ErrorSeverity {
        Low,
        Medium,
        High,
        Critical
    }
    
    struct ErrorMetrics {
        uint256 totalErrors;
        uint256 resolvedErrors;
        uint256 criticalErrors;
        uint256 lastError;
        uint256 mttr; // Mean Time To Resolution
    }
    
    // Error storage
    mapping(bytes32 => Error) public errors;
    mapping(bytes32 => ErrorMetrics) public errorMetrics;
    mapping(bytes32 => bytes32[]) public agentErrors;
    mapping(ErrorType => uint256) public errorTypeCount;
    
    // Recovery plans
    mapping(bytes32 => bytes) public recoveryPlans;
    mapping(bytes32 => bool) public autoRecovery;
    
    uint256 public constant MAX_RETRY_ATTEMPTS = 3;
    uint256 public constant ERROR_COOLDOWN = 5 minutes;
    
    event ErrorReported(
        bytes32 indexed errorId,
        bytes32 indexed agentId,
        ErrorType errorType,
        ErrorSeverity severity
    );
    
    event ErrorResolved(
        bytes32 indexed errorId,
        bytes32 indexed agentId,
        bytes32 resolution
    );
    
    event RecoveryPlanExecuted(
        bytes32 indexed errorId,
        bytes32 indexed agentId,
        bool success
    );
    
    constructor(
        address _registry,
        address _stateManager,
        address _security
    ) {
        registry = AgentRegistry(_registry);
        stateManager = AgentStateManager(_stateManager);
        security = AgentSecurity(_security);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ERROR_HANDLER_ROLE, msg.sender);
        _grantRole(RECOVERY_ROLE, msg.sender);
    }
    
    function reportError(
        bytes32 agentId,
        ErrorType errorType,
        ErrorSeverity severity,
        bytes calldata data
    ) external onlyRole(ERROR_HANDLER_ROLE) nonReentrant returns (bytes32) {
        require(
            block.timestamp >= errorMetrics[agentId].lastError + ERROR_COOLDOWN,
            "Error cooldown"
        );
        
        bytes32 errorId = generateErrorId(agentId, errorType, severity);
        
        errors[errorId] = Error({
            errorId: errorId,
            agentId: agentId,
            errorType: errorType,
            severity: severity,
            timestamp: block.timestamp,
            data: data,
            resolved: false,
            resolution: bytes32(0)
        });
        
        agentErrors[agentId].push(errorId);
        errorTypeCount[errorType]++;
        
        // Update metrics
        updateErrorMetrics(agentId, severity);
        
        // Handle critical errors
        if (severity == ErrorSeverity.Critical) {
            handleCriticalError(agentId, errorId);
        }
        
        // Attempt auto-recovery if enabled
        if (autoRecovery[agentId]) {
            executeRecoveryPlan(errorId);
        }
        
        emit ErrorReported(errorId, agentId, errorType, severity);
        return errorId;
    }
    
    function resolveError(
        bytes32 errorId,
        bytes32 resolution
    ) external onlyRole(ERROR_HANDLER_ROLE) {
        Error storage error = errors[errorId];
        require(!error.resolved, "Already resolved");
        
        error.resolved = true;
        error.resolution = resolution;
        
        // Update metrics
        ErrorMetrics storage metrics = errorMetrics[error.agentId];
        metrics.resolvedErrors++;
        
        // Calculate MTTR
        uint256 resolutionTime = block.timestamp - error.timestamp;
        metrics.mttr = (metrics.mttr * (metrics.resolvedErrors - 1) + resolutionTime) 
                      / metrics.resolvedErrors;
        
        emit ErrorResolved(errorId, error.agentId, resolution);
    }
    
    function setRecoveryPlan(
        bytes32 agentId,
        bytes calldata plan
    ) external onlyRole(RECOVERY_ROLE) {
        recoveryPlans[agentId] = plan;
    }
    
    function setAutoRecovery(
        bytes32 agentId,
        bool enabled
    ) external onlyRole(RECOVERY_ROLE) {
        autoRecovery[agentId] = enabled;
    }
    
    function executeRecoveryPlan(
        bytes32 errorId
    ) public onlyRole(RECOVERY_ROLE) returns (bool) {
        Error storage error = errors[errorId];
        bytes storage plan = recoveryPlans[error.agentId];
        require(plan.length > 0, "No recovery plan");
        
        bool success = true;
        // Execute recovery steps
        // This would integrate with the specific recovery mechanisms
        
        if (success) {
            resolveError(errorId, "AUTO_RECOVERY");
        }
        
        emit RecoveryPlanExecuted(errorId, error.agentId, success);
        return success;
    }
    
    function getAgentErrors(
        bytes32 agentId
    ) external view returns (bytes32[] memory) {
        return agentErrors[agentId];
    }
    
    function getErrorMetrics(
        bytes32 agentId
    ) external view returns (
        uint256 total,
        uint256 resolved,
        uint256 critical,
        uint256 mttr
    ) {
        ErrorMetrics storage metrics = errorMetrics[agentId];
        return (
            metrics.totalErrors,
            metrics.resolvedErrors,
            metrics.criticalErrors,
            metrics.mttr
        );
    }
    
    // Internal functions
    function generateErrorId(
        bytes32 agentId,
        ErrorType errorType,
        ErrorSeverity severity
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                agentId,
                errorType,
                severity,
                block.timestamp
            )
        );
    }
    
    function updateErrorMetrics(
        bytes32 agentId,
        ErrorSeverity severity
    ) internal {
        ErrorMetrics storage metrics = errorMetrics[agentId];
        
        metrics.totalErrors++;
        metrics.lastError = block.timestamp;
        
        if (severity == ErrorSeverity.Critical) {
            metrics.criticalErrors++;
        }
    }
    
    function handleCriticalError(
        bytes32 agentId,
        bytes32 errorId
    ) internal {
        // Update agent state
        stateManager.updateState(
            agentId,
            AgentStateManager.StateType.Error,
            errorId
        );
        
        // Report security violation
        security.reportViolation(agentId, "CRITICAL_ERROR");
    }
}
