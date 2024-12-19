const { ethers } = require("hardhat");
const { readDeploymentData } = require("../utils/deployment-utils");

async function main() {
    console.log("Starting role setup...");
    
    // Get deployer account
    const [deployer] = await ethers.getSigners();
    console.log("Setting up roles with account:", deployer.address);
    
    // Read deployment data
    const deploymentData = await readDeploymentData();
    
    // Setup Registry roles
    console.log("\nSetting up Registry roles...");
    const registry = await ethers.getContractAt("AgentRegistry", deploymentData.registry);
    const REGISTRAR_ROLE = await registry.REGISTRAR_ROLE();
    await registry.grantRole(REGISTRAR_ROLE, deployer.address);
    console.log("Granted REGISTRAR_ROLE to deployer");
    
    // Setup Performance roles
    console.log("\nSetting up Performance roles...");
    const performance = await ethers.getContractAt("AgentPerformance", deploymentData.performance);
    const EVALUATOR_ROLE = await performance.EVALUATOR_ROLE();
    await performance.grantRole(EVALUATOR_ROLE, deployer.address);
    console.log("Granted EVALUATOR_ROLE to deployer");
    
    // Setup Security roles
    console.log("\nSetting up Security roles...");
    const security = await ethers.getContractAt("AgentSecurity", deploymentData.security);
    const SECURITY_ADMIN_ROLE = await security.SECURITY_ADMIN_ROLE();
    await security.grantRole(SECURITY_ADMIN_ROLE, deployer.address);
    console.log("Granted SECURITY_ADMIN_ROLE to deployer");
    
    // Setup Rewards roles
    console.log("\nSetting up Rewards roles...");
    const rewards = await ethers.getContractAt("AgentRewards", deploymentData.rewards);
    const DISTRIBUTOR_ROLE = await rewards.DISTRIBUTOR_ROLE();
    await rewards.grantRole(DISTRIBUTOR_ROLE, deployer.address);
    console.log("Granted DISTRIBUTOR_ROLE to deployer");
    
    // Setup Governance roles
    console.log("\nSetting up Governance roles...");
    const governance = await ethers.getContractAt("AgentGovernance", deploymentData.governance);
    const GOVERNANCE_ADMIN_ROLE = await governance.GOVERNANCE_ADMIN_ROLE();
    await governance.grantRole(GOVERNANCE_ADMIN_ROLE, deployer.address);
    console.log("Granted GOVERNANCE_ADMIN_ROLE to deployer");
    
    console.log("\nRole setup completed!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
