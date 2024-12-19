const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("Agent Ecosystem Integration Tests", function () {
    let owner, addr1, addr2, addr3;
    let sbxToken, registry, performance, security, rewards, governance, communication;
    
    // Test constants
    const INITIAL_SUPPLY = ethers.utils.parseEther("1000000");
    const PROPOSAL_THRESHOLD = ethers.utils.parseEther("100");
    const MIN_STAKE_DURATION = 30 * 24 * 60 * 60; // 30 days
    const EVALUATION_PERIOD = 30 * 24 * 60 * 60; // 30 days
    
    beforeEach(async function () {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();
        
        // Deploy token
        const SBXToken = await ethers.getContractFactory("SBXToken");
        sbxToken = await SBXToken.deploy(INITIAL_SUPPLY);
        await sbxToken.deployed();
        
        // Deploy registry
        const AgentRegistry = await ethers.getContractFactory("AgentRegistry");
        registry = await AgentRegistry.deploy();
        await registry.deployed();
        
        // Deploy performance tracking
        const AgentPerformance = await ethers.getContractFactory("AgentPerformance");
        performance = await AgentPerformance.deploy(registry.address);
        await performance.deployed();
        
        // Deploy security
        const AgentSecurity = await ethers.getContractFactory("AgentSecurity");
        security = await AgentSecurity.deploy(registry.address);
        await security.deployed();
        
        // Deploy rewards
        const AgentRewards = await ethers.getContractFactory("AgentRewards");
        rewards = await AgentRewards.deploy(
            sbxToken.address,
            registry.address,
            performance.address
        );
        await rewards.deployed();
        
        // Deploy governance
        const AgentGovernance = await ethers.getContractFactory("AgentGovernance");
        governance = await AgentGovernance.deploy(
            registry.address,
            sbxToken.address
        );
        await governance.deployed();
        
        // Deploy communication
        const AgentCommunication = await ethers.getContractFactory("AgentCommunication");
        communication = await AgentCommunication.deploy(registry.address);
        await communication.deployed();
        
        // Setup roles
        await setupRoles();
        
        // Transfer tokens for testing
        await distributeTokens();
    });
    
    async function setupRoles() {
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
    
    async function distributeTokens() {
        await sbxToken.transfer(addr1.address, ethers.utils.parseEther("10000"));
        await sbxToken.transfer(addr2.address, ethers.utils.parseEther("10000"));
        await sbxToken.transfer(addr3.address, ethers.utils.parseEther("10000"));
    }
    
    describe("Agent Lifecycle Integration", function () {
        let agentId;
        
        it("Should register and initialize an agent with all components", async function () {
            // Register agent
            const tx = await registry.registerAgent(
                addr1.address,
                "Test Agent",
                "AI Assistant",
                "1.0.0"
            );
            const receipt = await tx.wait();
            agentId = receipt.events[0].args.agentId;
            
            // Create security profile
            await security.createSecurityProfile(agentId);
            
            // Initialize performance tracking
            await performance.evaluateTask(
                ethers.utils.id("task1"),
                agentId,
                80, // complexity
                100, // executionTime
                50,  // resourceUsage
                90,  // qualityScore
                true, // successful
                "Initial evaluation"
            );
            
            // Setup rewards
            await rewards.distributeReward(
                agentId,
                ethers.utils.parseEther("100"),
                0 // Performance category
            );
            
            // Verify integration
            const [successRate, efficiency, quality, innovation, adaptability, totalTasks] = 
                await performance.getPerformanceMetrics(agentId);
            
            expect(successRate).to.be.gt(0);
            expect(totalTasks).to.equal(1);
            
            const securityProfile = await security.getSecurityProfile(agentId);
            expect(securityProfile.isVerified).to.equal(false);
            
            const rewardMetrics = await rewards.getAgentRewards(agentId);
            expect(rewardMetrics.totalRewards).to.be.gt(0);
        });
        
        it("Should handle collaborative tasks between agents", async function () {
            // Register two agents
            const tx1 = await registry.registerAgent(
                addr1.address,
                "Agent 1",
                "Collaborator 1",
                "1.0.0"
            );
            const receipt1 = await tx1.wait();
            const agent1Id = receipt1.events[0].args.agentId;
            
            const tx2 = await registry.registerAgent(
                addr2.address,
                "Agent 2",
                "Collaborator 2",
                "1.0.0"
            );
            const receipt2 = await tx2.wait();
            const agent2Id = receipt2.events[0].args.agentId;
            
            // Create communication channel
            await communication.createChannel(
                [agent1Id, agent2Id],
                0, // Direct channel
                ethers.constants.HashZero
            );
            
            // Record collaboration
            await performance.recordCollaboration(
                agent1Id,
                agent2Id,
                90, // teamworkScore
                85, // communicationScore
                80, // resourceSharingScore
                95  // conflictResolutionScore
            );
            
            // Verify collaboration metrics
            const metrics = await performance.getCollaborationMetrics(agent1Id);
            expect(metrics.teamworkScore).to.equal(90);
            expect(metrics.totalCollaborations).to.equal(1);
        });
        
        it("Should handle governance proposals and voting", async function () {
            // Register agent
            const tx = await registry.registerAgent(
                addr1.address,
                "Governance Agent",
                "Proposal Maker",
                "1.0.0"
            );
            const receipt = await tx.wait();
            const agentId = receipt.events[0].args.agentId;
            
            // Create proposal
            await sbxToken.connect(addr1).approve(governance.address, PROPOSAL_THRESHOLD);
            const proposalTx = await governance.connect(addr1).createProposal(
                "Test Proposal",
                "Description",
                [agentId],
                0, // AgentUpgrade type
                7 * 24 * 60 * 60, // 7 days voting period
                10 // 10% quorum
            );
            const proposalReceipt = await proposalTx.wait();
            const proposalId = proposalReceipt.events[0].args.proposalId;
            
            // Cast votes
            await governance.connect(addr1).castVote(proposalId, true, "Support");
            await governance.connect(addr2).castVote(proposalId, true, "Support");
            await governance.connect(addr3).castVote(proposalId, false, "Against");
            
            // Advance time
            await time.increase(9 * 24 * 60 * 60); // 9 days
            
            // Execute proposal
            await governance.executeProposal(proposalId);
            
            // Verify proposal execution
            const proposalDetails = await governance.getProposalDetails(proposalId);
            expect(proposalDetails.executed).to.equal(true);
        });
        
        it("Should handle security incidents and recovery", async function () {
            // Register agent
            const tx = await registry.registerAgent(
                addr1.address,
                "Security Test Agent",
                "Security Tester",
                "1.0.0"
            );
            const receipt = await tx.wait();
            const agentId = receipt.events[0].args.agentId;
            
            // Create security profile
            await security.createSecurityProfile(agentId);
            
            // Report security incident
            await security.reportSecurityIncident(
                agentId,
                70, // High severity
                "Security breach detected"
            );
            
            // Verify security impact
            const securityProfile = await security.getSecurityProfile(agentId);
            expect(securityProfile.securityScore).to.be.lt(100);
            
            // Resolve incident
            await security.resolveSecurityIncident(1); // First incident
            
            // Conduct security audit
            await security.conductAudit(
                agentId,
                "Security measures improved",
                true // passed
            );
            
            // Verify recovery
            const updatedProfile = await security.getSecurityProfile(agentId);
            expect(updatedProfile.securityScore).to.be.gt(securityProfile.securityScore);
        });
        
        it("Should handle staking and rewards distribution", async function () {
            // Register agent
            const tx = await registry.registerAgent(
                addr1.address,
                "Staking Agent",
                "Reward Earner",
                "1.0.0"
            );
            const receipt = await tx.wait();
            const agentId = receipt.events[0].args.agentId;
            
            // Create staking position
            const stakeAmount = ethers.utils.parseEther("1000");
            await sbxToken.connect(addr1).approve(rewards.address, stakeAmount);
            await rewards.connect(addr1).createStakingPosition(
                agentId,
                stakeAmount,
                365 * 24 * 60 * 60 // 1 year
            );
            
            // Perform tasks and earn rewards
            for (let i = 0; i < 5; i++) {
                await performance.evaluateTask(
                    ethers.utils.id(`task${i}`),
                    agentId,
                    80, // complexity
                    100, // executionTime
                    50,  // resourceUsage
                    90,  // qualityScore
                    true, // successful
                    `Task ${i} completed`
                );
                
                await rewards.distributeReward(
                    agentId,
                    ethers.utils.parseEther("10"),
                    0 // Performance category
                );
            }
            
            // Verify rewards with staking multiplier
            const rewardMetrics = await rewards.getAgentRewards(agentId);
            expect(rewardMetrics.stakingRewards).to.be.gt(0);
        });
    });
    
    describe("Error Handling and Edge Cases", function () {
        it("Should handle invalid operations gracefully", async function () {
            // Try to execute non-existent proposal
            await expect(
                governance.executeProposal(999)
            ).to.be.revertedWith("Invalid proposal state");
            
            // Try to create proposal without enough tokens
            await expect(
                governance.connect(addr3).createProposal(
                    "Invalid Proposal",
                    "Description",
                    [],
                    0,
                    7 * 24 * 60 * 60,
                    10
                )
            ).to.be.revertedWith("Insufficient tokens");
            
            // Try to evaluate task for non-existent agent
            await expect(
                performance.evaluateTask(
                    ethers.utils.id("invalid"),
                    ethers.utils.id("invalid"),
                    80,
                    100,
                    50,
                    90,
                    true,
                    "Invalid"
                )
            ).to.be.revertedWith("Agent not active");
        });
        
        it("Should handle concurrent operations correctly", async function () {
            // Register agent
            const tx = await registry.registerAgent(
                addr1.address,
                "Concurrent Agent",
                "Tester",
                "1.0.0"
            );
            const receipt = await tx.wait();
            const agentId = receipt.events[0].args.agentId;
            
            // Perform multiple operations concurrently
            await Promise.all([
                performance.evaluateTask(
                    ethers.utils.id("task1"),
                    agentId,
                    80,
                    100,
                    50,
                    90,
                    true,
                    "Concurrent task 1"
                ),
                performance.evaluateTask(
                    ethers.utils.id("task2"),
                    agentId,
                    85,
                    95,
                    45,
                    95,
                    true,
                    "Concurrent task 2"
                ),
                rewards.distributeReward(
                    agentId,
                    ethers.utils.parseEther("10"),
                    0
                )
            ]);
            
            // Verify state consistency
            const metrics = await performance.getPerformanceMetrics(agentId);
            expect(metrics.totalTasks).to.equal(2);
        });
    });
});
