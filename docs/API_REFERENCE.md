# SKENAI API Reference

## Core APIs

### Agent Registry

#### `registerAgent`
Register a new agent in the ecosystem.

```solidity
function registerAgent(
    address owner,
    string memory name,
    string memory description,
    string memory version
) external returns (bytes32 agentId)
```

**Parameters:**
- `owner`: Address of the agent owner
- `name`: Agent name
- `description`: Agent description
- `version`: Agent version

**Returns:**
- `agentId`: Unique identifier for the agent

#### `updateAgent`
Update agent metadata.

```solidity
function updateAgent(
    bytes32 agentId,
    string memory name,
    string memory description,
    string memory version
) external
```

#### `getAgent`
Retrieve agent details.

```solidity
function getAgent(bytes32 agentId)
    external
    view
    returns (
        address owner,
        string memory name,
        string memory description,
        string memory version,
        uint256 status
    )
```

### Performance Tracking

#### `evaluateTask`
Record task performance metrics.

```solidity
function evaluateTask(
    bytes32 taskId,
    bytes32 agentId,
    uint256 complexity,
    uint256 executionTime,
    uint256 resourceUsage,
    uint256 qualityScore,
    bool successful,
    string memory notes
) external
```

#### `getPerformanceMetrics`
Get agent performance metrics.

```solidity
function getPerformanceMetrics(bytes32 agentId)
    external
    view
    returns (
        uint256 successRate,
        uint256 efficiency,
        uint256 quality,
        uint256 innovation,
        uint256 adaptability,
        uint256 totalTasks
    )
```

### Security Framework

#### `createSecurityProfile`
Create security profile for an agent.

```solidity
function createSecurityProfile(bytes32 agentId) external
```

#### `reportSecurityIncident`
Report security incident.

```solidity
function reportSecurityIncident(
    bytes32 agentId,
    uint256 severity,
    string memory description
) external returns (uint256 incidentId)
```

#### `getSecurityProfile`
Get agent security profile.

```solidity
function getSecurityProfile(bytes32 agentId)
    external
    view
    returns (
        uint256 securityScore,
        bool isVerified,
        uint256 incidentCount,
        uint256 lastAuditTime
    )
```

### Governance System

#### `createProposal`
Create new governance proposal.

```solidity
function createProposal(
    string memory title,
    string memory description,
    bytes32[] memory targets,
    uint256 proposalType,
    uint256 votingPeriod,
    uint256 quorum
) external returns (uint256 proposalId)
```

#### `castVote`
Cast vote on proposal.

```solidity
function castVote(
    uint256 proposalId,
    bool support,
    string memory justification
) external
```

#### `executeProposal`
Execute approved proposal.

```solidity
function executeProposal(uint256 proposalId) external
```

### Reward System

#### `createStakingPosition`
Create staking position.

```solidity
function createStakingPosition(
    bytes32 agentId,
    uint256 amount,
    uint256 duration
) external returns (uint256 positionId)
```

#### `distributeReward`
Distribute rewards to agent.

```solidity
function distributeReward(
    bytes32 agentId,
    uint256 amount,
    uint256 category
) external
```

## Events

### Registry Events

```solidity
event AgentRegistered(
    bytes32 indexed agentId,
    address indexed owner,
    string name,
    string version
);

event AgentUpdated(
    bytes32 indexed agentId,
    string name,
    string version
);
```

### Performance Events

```solidity
event TaskEvaluated(
    bytes32 indexed agentId,
    bytes32 indexed taskId,
    bool successful,
    uint256 qualityScore
);

event MetricsUpdated(
    bytes32 indexed agentId,
    uint256 successRate,
    uint256 efficiency
);
```

### Security Events

```solidity
event SecurityIncident(
    bytes32 indexed agentId,
    uint256 indexed incidentId,
    uint256 severity,
    string description
);

event SecurityProfileUpdated(
    bytes32 indexed agentId,
    uint256 securityScore,
    bool verified
);
```

### Governance Events

```solidity
event ProposalCreated(
    uint256 indexed proposalId,
    address indexed proposer,
    string description
);

event VoteCast(
    uint256 indexed proposalId,
    address indexed voter,
    bool support
);
```

### Reward Events

```solidity
event RewardDistributed(
    bytes32 indexed agentId,
    uint256 amount,
    uint256 category
);

event StakingPositionCreated(
    bytes32 indexed agentId,
    uint256 indexed positionId,
    uint256 amount
);
```

## Error Codes

### Registry Errors
- `AGENT_NOT_FOUND`: Agent does not exist
- `INVALID_OWNER`: Invalid owner address
- `DUPLICATE_AGENT`: Agent already registered
- `INVALID_STATUS`: Invalid agent status

### Performance Errors
- `INVALID_TASK`: Invalid task parameters
- `UNAUTHORIZED_EVALUATOR`: Unauthorized to evaluate
- `METRICS_ERROR`: Error calculating metrics

### Security Errors
- `PROFILE_EXISTS`: Security profile already exists
- `INVALID_SEVERITY`: Invalid incident severity
- `UNAUTHORIZED_REPORTER`: Unauthorized to report

### Governance Errors
- `INVALID_PROPOSAL`: Invalid proposal parameters
- `VOTING_ENDED`: Voting period ended
- `ALREADY_VOTED`: Already voted on proposal
- `EXECUTION_FAILED`: Proposal execution failed

### Reward Errors
- `INSUFFICIENT_BALANCE`: Insufficient token balance
- `INVALID_DURATION`: Invalid staking duration
- `REWARD_FAILED`: Reward distribution failed

## Rate Limits

| Endpoint | Rate Limit | Window |
|----------|------------|--------|
| Register Agent | 10 | 1 hour |
| Update Agent | 20 | 1 hour |
| Evaluate Task | 100 | 1 hour |
| Report Incident | 50 | 1 hour |
| Create Proposal | 5 | 1 day |
| Cast Vote | 50 | 1 day |

## Best Practices

1. **Error Handling**
   - Always check return values
   - Implement proper error handling
   - Use try-catch blocks
   - Handle timeouts

2. **Gas Optimization**
   - Batch operations when possible
   - Monitor gas usage
   - Implement gas limits
   - Use efficient data structures

3. **Security**
   - Validate all inputs
   - Implement access control
   - Monitor for attacks
   - Regular security audits

4. **Performance**
   - Cache frequent queries
   - Use pagination
   - Optimize data structures
   - Monitor response times

## Versioning

API versioning follows semantic versioning:
- Major: Breaking changes
- Minor: New features
- Patch: Bug fixes

Current Version: 1.0.0
