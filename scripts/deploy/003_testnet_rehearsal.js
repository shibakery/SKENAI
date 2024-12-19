const { ethers } = require("hardhat");
const { deployFullSuite } = require("../helpers/testHelpers");
const { DeploymentMonitor } = require("../monitor/DeploymentMonitor");
const { runSecurityAudit } = require("../audit/PreDeploymentAudit");

async function main() {
    console.log("Starting Testnet Deployment Rehearsal...\n");
    
    // 1. Run Pre-deployment Security Audit
    console.log("Running security audit...");
    const auditResults = await runSecurityAudit();
    if (!auditResults.passed) {
        console.error("Security audit failed. Aborting rehearsal.");
        process.exit(1);
    }
    
    // 2. Deploy Contracts
    console.log("\nDeploying contracts...");
    const contracts = await deployFullSuite();
    
    // 3. Setup Monitoring
    console.log("\nSetting up monitoring...");
    const monitor = new DeploymentMonitor(ethers.provider, {
        sbxToken: contracts.sbxToken.address,
        registry: contracts.registry.address,
        performance: contracts.performance.address,
        security: contracts.security.address,
        rewards: contracts.rewards.address,
        governance: contracts.governance.address,
        communication: contracts.communication.address
    });
    await monitor.initialize();
    
    // 4. Run Integration Tests
    console.log("\nRunning integration tests...");
    await runIntegrationTests(contracts);
    
    // 5. Monitor Contract Health
    console.log("\nChecking contract health...");
    const health = await monitor.checkContractHealth();
    if (Object.values(health).some(h => h.status !== "healthy")) {
        console.error("Contract health check failed:", health);
        process.exit(1);
    }
    
    // 6. Simulate User Operations
    console.log("\nSimulating user operations...");
    await simulateUserOperations(contracts);
    
    console.log("\nTestnet rehearsal completed successfully!");
}

async function runIntegrationTests(contracts) {
    const [owner, user1, user2] = await ethers.getSigners();
    
    try {
        // Test agent registration
        const tx = await contracts.registry.registerAgent(
            user1.address,
            "Test Agent",
            "Test Description",
            "1.0.0"
        );
        const receipt = await tx.wait();
        const agentId = receipt.events[0].args.agentId;
        
        // Test security profile
        await contracts.security.createSecurityProfile(agentId);
        
        // Test performance tracking
        await contracts.performance.evaluateTask(
            ethers.utils.id("test-task"),
            agentId,
            80,
            100,
            50,
            90,
            true,
            "Test evaluation"
        );
        
        // Test governance
        await contracts.sbxToken.transfer(
            user1.address,
            ethers.utils.parseEther("1000")
        );
        await contracts.governance.connect(user1).createProposal(
            "Test Proposal",
            "Description",
            [agentId],
            0,
            7 * 24 * 60 * 60,
            10
        );
        
        console.log("Integration tests passed");
        
    } catch (error) {
        console.error("Integration tests failed:", error);
        throw error;
    }
}

async function simulateUserOperations(contracts) {
    const [owner, user1, user2] = await ethers.getSigners();
    
    try {
        // Simulate token transfers
        await contracts.sbxToken.transfer(
            user1.address,
            ethers.utils.parseEther("10000")
        );
        await contracts.sbxToken.transfer(
            user2.address,
            ethers.utils.parseEther("10000")
        );
        
        // Simulate agent operations
        const agents = [];
        for (let i = 0; i < 3; i++) {
            const tx = await contracts.registry.registerAgent(
                user1.address,
                `Agent ${i}`,
                "Simulation Agent",
                "1.0.0"
            );
            const receipt = await tx.wait();
            agents.push(receipt.events[0].args.agentId);
            
            // Create security profiles
            await contracts.security.createSecurityProfile(agents[i]);
            
            // Evaluate tasks
            await contracts.performance.evaluateTask(
                ethers.utils.id(`task-${i}`),
                agents[i],
                80,
                100,
                50,
                90,
                true,
                "Simulation evaluation"
            );
        }
        
        // Simulate governance
        await contracts.governance.connect(user1).createProposal(
            "Simulation Proposal",
            "Description",
            agents,
            0,
            7 * 24 * 60 * 60,
            10
        );
        
        console.log("User operations simulation completed");
        
    } catch (error) {
        console.error("User operations simulation failed:", error);
        throw error;
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
