const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

async function deployFullSuite() {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();
    
    // Deploy token
    const SBXToken = await ethers.getContractFactory("SBXToken");
    const sbxToken = await SBXToken.deploy(ethers.utils.parseEther("1000000"));
    await sbxToken.deployed();
    
    // Deploy core contracts
    const AgentRegistry = await ethers.getContractFactory("AgentRegistry");
    const registry = await AgentRegistry.deploy();
    await registry.deployed();
    
    const AgentPerformance = await ethers.getContractFactory("AgentPerformance");
    const performance = await AgentPerformance.deploy(registry.address);
    await performance.deployed();
    
    const AgentSecurity = await ethers.getContractFactory("AgentSecurity");
    const security = await AgentSecurity.deploy(registry.address);
    await security.deployed();
    
    const AgentRewards = await ethers.getContractFactory("AgentRewards");
    const rewards = await AgentRewards.deploy(
        sbxToken.address,
        registry.address,
        performance.address
    );
    await rewards.deployed();
    
    const AgentGovernance = await ethers.getContractFactory("AgentGovernance");
    const governance = await AgentGovernance.deploy(
        registry.address,
        sbxToken.address
    );
    await governance.deployed();
    
    const AgentCommunication = await ethers.getContractFactory("AgentCommunication");
    const communication = await AgentCommunication.deploy(registry.address);
    await communication.deployed();
    
    return {
        sbxToken,
        registry,
        performance,
        security,
        rewards,
        governance,
        communication,
        owner,
        addr1,
        addr2,
        addr3
    };
}

async function setupRoles(contracts) {
    const {
        registry,
        performance,
        security,
        rewards,
        governance,
        owner
    } = contracts;
    
    // Registry roles
    const REGISTRAR_ROLE = await registry.REGISTRAR_ROLE();
    await registry.grantRole(REGISTRAR_ROLE, owner.address);
    
    // Performance roles
    const EVALUATOR_ROLE = await performance.EVALUATOR_ROLE();
    await performance.grantRole(EVALUATOR_ROLE, owner.address);
    
    // Security roles
    const SECURITY_ADMIN_ROLE = await security.SECURITY_ADMIN_ROLE();
    await security.grantRole(SECURITY_ADMIN_ROLE, owner.address);
    
    // Rewards roles
    const DISTRIBUTOR_ROLE = await rewards.DISTRIBUTOR_ROLE();
    await rewards.grantRole(DISTRIBUTOR_ROLE, owner.address);
    
    // Governance roles
    const GOVERNANCE_ADMIN_ROLE = await governance.GOVERNANCE_ADMIN_ROLE();
    await governance.grantRole(GOVERNANCE_ADMIN_ROLE, owner.address);
}

async function registerAgent(registry, owner, name, description, version) {
    const tx = await registry.registerAgent(
        owner,
        name,
        description,
        version
    );
    const receipt = await tx.wait();
    return receipt.events[0].args.agentId;
}

async function createSecurityProfile(security, agentId) {
    await security.createSecurityProfile(agentId);
    return await security.getSecurityProfile(agentId);
}

async function evaluateAgentTask(performance, taskId, agentId, success = true) {
    await performance.evaluateTask(
        taskId,
        agentId,
        80, // complexity
        100, // executionTime
        50,  // resourceUsage
        success ? 90 : 40,  // qualityScore
        success,
        success ? "Task completed successfully" : "Task failed"
    );
}

async function distributeRewards(rewards, agentId, amount, category = 0) {
    await rewards.distributeReward(
        agentId,
        amount,
        category
    );
}

async function createAndExecuteProposal(governance, proposer, agentId) {
    const proposalTx = await governance.connect(proposer).createProposal(
        "Test Proposal",
        "Description",
        [agentId],
        0, // AgentUpgrade type
        7 * 24 * 60 * 60, // 7 days voting period
        10 // 10% quorum
    );
    const receipt = await proposalTx.wait();
    const proposalId = receipt.events[0].args.proposalId;
    
    // Advance time
    await time.increase(9 * 24 * 60 * 60);
    
    await governance.executeProposal(proposalId);
    return proposalId;
}

async function createStakingPosition(rewards, token, staker, agentId, amount, duration) {
    await token.connect(staker).approve(rewards.address, amount);
    await rewards.connect(staker).createStakingPosition(
        agentId,
        amount,
        duration
    );
}

async function setupCommunicationChannel(communication, agents) {
    await communication.createChannel(
        agents,
        0, // Direct channel
        ethers.constants.HashZero
    );
}

module.exports = {
    deployFullSuite,
    setupRoles,
    registerAgent,
    createSecurityProfile,
    evaluateAgentTask,
    distributeRewards,
    createAndExecuteProposal,
    createStakingPosition,
    setupCommunicationChannel
};
