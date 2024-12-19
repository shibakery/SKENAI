const { ethers } = require("hardhat");
const { readDeploymentData } = require("../utils/deployment-utils");

class DeploymentMonitor {
    constructor(provider, deploymentData) {
        this.provider = provider;
        this.deploymentData = deploymentData;
        this.contracts = {};
        this.metrics = {
            transactions: {},
            events: {},
            gasUsage: {},
            errors: []
        };
    }
    
    async initialize() {
        // Initialize contract instances
        this.contracts.sbxToken = await ethers.getContractAt(
            "SBXToken",
            this.deploymentData.sbxToken
        );
        this.contracts.registry = await ethers.getContractAt(
            "AgentRegistry",
            this.deploymentData.registry
        );
        this.contracts.performance = await ethers.getContractAt(
            "AgentPerformance",
            this.deploymentData.performance
        );
        this.contracts.security = await ethers.getContractAt(
            "AgentSecurity",
            this.deploymentData.security
        );
        this.contracts.rewards = await ethers.getContractAt(
            "AgentRewards",
            this.deploymentData.rewards
        );
        this.contracts.governance = await ethers.getContractAt(
            "AgentGovernance",
            this.deploymentData.governance
        );
        this.contracts.communication = await ethers.getContractAt(
            "AgentCommunication",
            this.deploymentData.communication
        );
    }
    
    async monitorTransactions() {
        const startBlock = await this.provider.getBlockNumber();
        
        // Monitor transactions for each contract
        for (const [name, contract] of Object.entries(this.contracts)) {
            this.provider.on({ address: contract.address }, (log) => {
                this.metrics.transactions[name] = 
                    (this.metrics.transactions[name] || 0) + 1;
                this.analyzeTransaction(name, log);
            });
        }
        
        console.log(`Started monitoring from block ${startBlock}`);
    }
    
    async monitorEvents() {
        // Monitor specific events for each contract
        const contracts = this.contracts;
        
        // Registry events
        contracts.registry.on("AgentRegistered", (agentId, owner, name, version) => {
            this.logEvent("Registry", "AgentRegistered", { agentId, owner, name, version });
        });
        
        // Performance events
        contracts.performance.on("TaskEvaluated", (agentId, taskId, success) => {
            this.logEvent("Performance", "TaskEvaluated", { agentId, taskId, success });
        });
        
        // Security events
        contracts.security.on("SecurityIncident", (agentId, severity, description) => {
            this.logEvent("Security", "SecurityIncident", { agentId, severity, description });
        });
        
        // Rewards events
        contracts.rewards.on("RewardDistributed", (agentId, amount, category) => {
            this.logEvent("Rewards", "RewardDistributed", { agentId, amount, category });
        });
        
        // Governance events
        contracts.governance.on("ProposalCreated", (proposalId, proposer, description) => {
            this.logEvent("Governance", "ProposalCreated", { proposalId, proposer, description });
        });
    }
    
    async monitorGasUsage() {
        const filter = {
            fromBlock: "latest"
        };
        
        this.provider.on(filter, async (tx) => {
            if (tx.to && this.isMonitoredContract(tx.to)) {
                const receipt = await tx.wait();
                const contractName = this.getContractName(tx.to);
                this.metrics.gasUsage[contractName] = 
                    (this.metrics.gasUsage[contractName] || 0) + receipt.gasUsed.toNumber();
            }
        });
    }
    
    logEvent(contract, event, data) {
        const eventKey = `${contract}:${event}`;
        this.metrics.events[eventKey] = this.metrics.events[eventKey] || [];
        this.metrics.events[eventKey].push({
            timestamp: new Date(),
            data
        });
        
        console.log(`Event: ${eventKey}`, data);
    }
    
    analyzeTransaction(contractName, log) {
        try {
            const interface = this.contracts[contractName].interface;
            const event = interface.parseLog(log);
            
            if (event) {
                this.logEvent(contractName, event.name, event.args);
            }
        } catch (error) {
            this.metrics.errors.push({
                timestamp: new Date(),
                contract: contractName,
                error: error.message
            });
        }
    }
    
    isMonitoredContract(address) {
        return Object.values(this.deploymentData).includes(address.toLowerCase());
    }
    
    getContractName(address) {
        address = address.toLowerCase();
        return Object.keys(this.deploymentData).find(
            key => this.deploymentData[key].toLowerCase() === address
        );
    }
    
    async getMetrics() {
        const currentBlock = await this.provider.getBlockNumber();
        
        return {
            currentBlock,
            transactions: this.metrics.transactions,
            events: this.metrics.events,
            gasUsage: this.metrics.gasUsage,
            errors: this.metrics.errors
        };
    }
    
    async checkContractHealth() {
        const health = {};
        
        try {
            // Check Registry
            health.registry = {
                agentCount: (await this.contracts.registry.getAgentCount()).toString(),
                status: "healthy"
            };
            
            // Check Performance
            const defaultMetrics = await this.contracts.performance.getDefaultMetrics();
            health.performance = {
                metricsInitialized: defaultMetrics.totalTasks.toString() !== undefined,
                status: "healthy"
            };
            
            // Check Security
            const securityConfig = await this.contracts.security.getSecurityConfig();
            health.security = {
                configInitialized: securityConfig.minSecurityScore.toString() !== undefined,
                status: "healthy"
            };
            
            // Check Rewards
            const rewardConfig = await this.contracts.rewards.getRewardConfig();
            health.rewards = {
                configInitialized: rewardConfig.baseReward.toString() !== undefined,
                status: "healthy"
            };
            
            // Check Governance
            const govParams = await this.contracts.governance.getGovernanceParameters();
            health.governance = {
                paramsInitialized: govParams.quorumPercentage.toString() !== undefined,
                status: "healthy"
            };
            
        } catch (error) {
            console.error("Health check error:", error);
            this.metrics.errors.push({
                timestamp: new Date(),
                type: "HealthCheck",
                error: error.message
            });
        }
        
        return health;
    }
}

async function startMonitoring() {
    const provider = ethers.provider;
    const deploymentData = await readDeploymentData();
    
    const monitor = new DeploymentMonitor(provider, deploymentData);
    await monitor.initialize();
    
    // Start monitoring
    await monitor.monitorTransactions();
    await monitor.monitorEvents();
    await monitor.monitorGasUsage();
    
    // Periodic health checks
    setInterval(async () => {
        const health = await monitor.checkContractHealth();
        console.log("\nContract Health Status:", health);
        
        const metrics = await monitor.getMetrics();
        console.log("\nCurrent Metrics:", metrics);
    }, 5 * 60 * 1000); // Every 5 minutes
    
    return monitor;
}

module.exports = {
    DeploymentMonitor,
    startMonitoring
};
