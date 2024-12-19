const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deployFullSuite } = require("../helpers/testHelpers");

describe("Deployment Tests", function () {
    let contracts;
    let owner, addr1, addr2;
    
    beforeEach(async function () {
        contracts = await deployFullSuite();
        ({ owner, addr1, addr2 } = contracts);
    });
    
    describe("Contract Deployment", function () {
        it("Should deploy all contracts with correct configurations", async function () {
            const {
                sbxToken,
                registry,
                performance,
                security,
                rewards,
                governance,
                communication
            } = contracts;
            
            // Verify contract deployments
            expect(await sbxToken.address).to.be.properAddress;
            expect(await registry.address).to.be.properAddress;
            expect(await performance.address).to.be.properAddress;
            expect(await security.address).to.be.properAddress;
            expect(await rewards.address).to.be.properAddress;
            expect(await governance.address).to.be.properAddress;
            expect(await communication.address).to.be.properAddress;
            
            // Verify contract connections
            expect(await performance.registry()).to.equal(registry.address);
            expect(await security.registry()).to.equal(registry.address);
            expect(await rewards.registry()).to.equal(registry.address);
            expect(await governance.registry()).to.equal(registry.address);
            expect(await communication.registry()).to.equal(registry.address);
        });
        
        it("Should set up initial token supply correctly", async function () {
            const { sbxToken } = contracts;
            const totalSupply = await sbxToken.totalSupply();
            expect(totalSupply).to.equal(ethers.utils.parseEther("1000000000"));
        });
    });
    
    describe("Role Setup", function () {
        it("Should set up all required roles", async function () {
            const {
                registry,
                performance,
                security,
                rewards,
                governance
            } = contracts;
            
            // Check registry roles
            const REGISTRAR_ROLE = await registry.REGISTRAR_ROLE();
            expect(await registry.hasRole(REGISTRAR_ROLE, owner.address)).to.be.true;
            
            // Check performance roles
            const EVALUATOR_ROLE = await performance.EVALUATOR_ROLE();
            expect(await performance.hasRole(EVALUATOR_ROLE, owner.address)).to.be.true;
            
            // Check security roles
            const SECURITY_ADMIN_ROLE = await security.SECURITY_ADMIN_ROLE();
            expect(await security.hasRole(SECURITY_ADMIN_ROLE, owner.address)).to.be.true;
            
            // Check rewards roles
            const DISTRIBUTOR_ROLE = await rewards.DISTRIBUTOR_ROLE();
            expect(await rewards.hasRole(DISTRIBUTOR_ROLE, owner.address)).to.be.true;
            
            // Check governance roles
            const GOVERNANCE_ADMIN_ROLE = await governance.GOVERNANCE_ADMIN_ROLE();
            expect(await governance.hasRole(GOVERNANCE_ADMIN_ROLE, owner.address)).to.be.true;
        });
    });
    
    describe("Initial State", function () {
        it("Should have correct initial states", async function () {
            const { registry, performance, security, governance } = contracts;
            
            // Check registry state
            expect(await registry.getAgentCount()).to.equal(0);
            
            // Check performance state
            const defaultMetrics = await performance.getDefaultMetrics();
            expect(defaultMetrics.successRate).to.equal(0);
            expect(defaultMetrics.totalTasks).to.equal(0);
            
            // Check security state
            const securityConfig = await security.getSecurityConfig();
            expect(securityConfig.minSecurityScore).to.be.gt(0);
            
            // Check governance state
            const govParams = await governance.getGovernanceParameters();
            expect(govParams.quorumPercentage).to.be.gt(0);
            expect(govParams.votingPeriod).to.be.gt(0);
        });
    });
    
    describe("Contract Interactions", function () {
        it("Should allow basic contract interactions", async function () {
            const { registry, performance, security } = contracts;
            
            // Register an agent
            const tx = await registry.registerAgent(
                addr1.address,
                "Test Agent",
                "Test Description",
                "1.0.0"
            );
            const receipt = await tx.wait();
            const agentId = receipt.events[0].args.agentId;
            
            // Create security profile
            await security.createSecurityProfile(agentId);
            
            // Evaluate task
            await performance.evaluateTask(
                ethers.utils.id("task1"),
                agentId,
                80,
                100,
                50,
                90,
                true,
                "Test evaluation"
            );
            
            // Verify interactions
            expect(await registry.getAgentCount()).to.equal(1);
            const securityProfile = await security.getSecurityProfile(agentId);
            expect(securityProfile.isVerified).to.be.false;
            const perfMetrics = await performance.getPerformanceMetrics(agentId);
            expect(perfMetrics.totalTasks).to.equal(1);
        });
    });
    
    describe("Error Cases", function () {
        it("Should handle invalid operations correctly", async function () {
            const { registry, performance, security } = contracts;
            
            // Try to evaluate non-existent agent
            await expect(
                performance.evaluateTask(
                    ethers.utils.id("task1"),
                    ethers.utils.id("invalid"),
                    80,
                    100,
                    50,
                    90,
                    true,
                    "Test"
                )
            ).to.be.revertedWith("Agent not active");
            
            // Try to create duplicate security profile
            const tx = await registry.registerAgent(
                addr1.address,
                "Test Agent",
                "Test Description",
                "1.0.0"
            );
            const receipt = await tx.wait();
            const agentId = receipt.events[0].args.agentId;
            
            await security.createSecurityProfile(agentId);
            await expect(
                security.createSecurityProfile(agentId)
            ).to.be.revertedWith("Security profile already exists");
        });
    });
});
