const { ethers } = require("hardhat");
const { writeDeploymentData, verifyContract } = require("../utils/deployment-utils");

async function main() {
    console.log("Starting core contract deployment...");
    
    // Get deployer account
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    
    // Deploy SBX Token
    console.log("\nDeploying SBX Token...");
    const SBXToken = await ethers.getContractFactory("SBXToken");
    const initialSupply = ethers.utils.parseEther("1000000000"); // 1 billion tokens
    const sbxToken = await SBXToken.deploy(initialSupply);
    await sbxToken.deployed();
    console.log("SBX Token deployed to:", sbxToken.address);
    
    // Deploy Agent Registry
    console.log("\nDeploying Agent Registry...");
    const AgentRegistry = await ethers.getContractFactory("AgentRegistry");
    const registry = await AgentRegistry.deploy();
    await registry.deployed();
    console.log("Agent Registry deployed to:", registry.address);
    
    // Deploy Agent Performance
    console.log("\nDeploying Agent Performance...");
    const AgentPerformance = await ethers.getContractFactory("AgentPerformance");
    const performance = await AgentPerformance.deploy(registry.address);
    await performance.deployed();
    console.log("Agent Performance deployed to:", performance.address);
    
    // Deploy Agent Security
    console.log("\nDeploying Agent Security...");
    const AgentSecurity = await ethers.getContractFactory("AgentSecurity");
    const security = await AgentSecurity.deploy(registry.address);
    await security.deployed();
    console.log("Agent Security deployed to:", security.address);
    
    // Deploy Agent Rewards
    console.log("\nDeploying Agent Rewards...");
    const AgentRewards = await ethers.getContractFactory("AgentRewards");
    const rewards = await AgentRewards.deploy(
        sbxToken.address,
        registry.address,
        performance.address
    );
    await rewards.deployed();
    console.log("Agent Rewards deployed to:", rewards.address);
    
    // Deploy Agent Governance
    console.log("\nDeploying Agent Governance...");
    const AgentGovernance = await ethers.getContractFactory("AgentGovernance");
    const governance = await AgentGovernance.deploy(
        registry.address,
        sbxToken.address
    );
    await governance.deployed();
    console.log("Agent Governance deployed to:", governance.address);
    
    // Deploy Agent Communication
    console.log("\nDeploying Agent Communication...");
    const AgentCommunication = await ethers.getContractFactory("AgentCommunication");
    const communication = await AgentCommunication.deploy(registry.address);
    await communication.deployed();
    console.log("Agent Communication deployed to:", communication.address);
    
    // Save deployment data
    const deploymentData = {
        network: network.name,
        sbxToken: sbxToken.address,
        registry: registry.address,
        performance: performance.address,
        security: security.address,
        rewards: rewards.address,
        governance: governance.address,
        communication: communication.address,
        timestamp: new Date().toISOString()
    };
    
    await writeDeploymentData(deploymentData);
    
    // Verify contracts if on a supported network
    if (network.name !== "hardhat" && network.name !== "localhost") {
        console.log("\nVerifying contracts...");
        
        await verifyContract(sbxToken.address, [initialSupply]);
        await verifyContract(registry.address, []);
        await verifyContract(performance.address, [registry.address]);
        await verifyContract(security.address, [registry.address]);
        await verifyContract(rewards.address, [
            sbxToken.address,
            registry.address,
            performance.address
        ]);
        await verifyContract(governance.address, [
            registry.address,
            sbxToken.address
        ]);
        await verifyContract(communication.address, [registry.address]);
    }
    
    console.log("\nCore contract deployment completed!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
