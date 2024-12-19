const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deployFullSuite } = require("../helpers/testHelpers");

describe("Gas Optimization Tests", function () {
    let contracts;
    let owner, addr1, addr2;
    let agentId;
    
    // Test constants
    const INITIAL_SUPPLY = ethers.utils.parseEther("1000000");
    const STAKE_AMOUNT = ethers.utils.parseEther("1000");
    const REWARD_AMOUNT = ethers.utils.parseEther("100");
    
    async function measureGas(tx) {
        const receipt = await tx.wait();
        return receipt.gasUsed;
    }
    
    beforeEach(async function () {
        contracts = await deployFullSuite();
        ({ owner, addr1, addr2 } = contracts);
        
        // Register a test agent
        const tx = await contracts.registry.registerAgent(
            addr1.address,
            "Test Agent",
            "Gas Test Agent",
            "1.0.0"
        );
        const receipt = await tx.wait();
        agentId = receipt.events[0].args.agentId;
    });
    
    describe("Registry Operations", function () {
        it("Should optimize agent registration gas usage", async function () {
            const gasResults = [];
            
            // Test different name lengths
            const nameLengths = [5, 10, 20, 50];
            for (const length of nameLengths) {
                const name = "A".repeat(length);
                const tx = await contracts.registry.registerAgent(
                    addr2.address,
                    name,
                    "Description",
                    "1.0.0"
                );
                const gas = await measureGas(tx);
                gasResults.push({ length, gas });
            }
            
            // Verify gas increase is linear or better
            for (let i = 1; i < gasResults.length; i++) {
                const gasIncrease = gasResults[i].gas.sub(gasResults[i-1].gas);
                const lengthIncrease = gasResults[i].length - gasResults[i-1].length;
                console.log(`Gas increase per character: ${gasIncrease.div(lengthIncrease)}`);
                // Gas increase per character should be constant or decreasing
                expect(gasIncrease.div(lengthIncrease)).to.be.lte(100);
            }
        });
        
        it("Should optimize batch operations", async function () {
            const batchSizes = [1, 5, 10, 20];
            const gasPerOperation = [];
            
            for (const size of batchSizes) {
                const agents = Array(size).fill().map((_, i) => ({
                    owner: addr2.address,
                    name: `Agent ${i}`,
                    description: "Batch Test",
                    version: "1.0.0"
                }));
                
                const tx = await contracts.registry.batchRegisterAgents(agents);
                const gas = await measureGas(tx);
                gasPerOperation.push(gas.div(size));
                
                console.log(`Gas per agent in batch of ${size}: ${gas.div(size)}`);
            }
            
            // Verify batch operations are more efficient
            for (let i = 1; i < gasPerOperation.length; i++) {
                expect(gasPerOperation[i]).to.be.lt(gasPerOperation[i-1]);
            }
        });
    });
    
    describe("Performance Tracking", function () {
        it("Should optimize task evaluation gas usage", async function () {
            // Initialize agent
            await contracts.security.createSecurityProfile(agentId);
            
            const scenarios = [
                { complexity: 10, executionTime: 50, resourceUsage: 25 },
                { complexity: 50, executionTime: 100, resourceUsage: 50 },
                { complexity: 100, executionTime: 200, resourceUsage: 75 }
            ];
            
            const gasResults = [];
            
            for (const scenario of scenarios) {
                const tx = await contracts.performance.evaluateTask(
                    ethers.utils.id("task"),
                    agentId,
                    scenario.complexity,
                    scenario.executionTime,
                    scenario.resourceUsage,
                    90, // qualityScore
                    true, // successful
                    "Gas optimization test"
                );
                const gas = await measureGas(tx);
                gasResults.push({ scenario, gas });
                
                console.log(`Gas used for complexity ${scenario.complexity}: ${gas}`);
            }
            
            // Verify gas usage scales efficiently with complexity
            for (let i = 1; i < gasResults.length; i++) {
                const gasIncrease = gasResults[i].gas.sub(gasResults[i-1].gas);
                const complexityIncrease = 
                    gasResults[i].scenario.complexity - gasResults[i-1].scenario.complexity;
                expect(gasIncrease.div(complexityIncrease)).to.be.lte(1000);
            }
        });
    });
    
    describe("Rewards Distribution", function () {
        it("Should optimize staking operations", async function () {
            // Setup staking
            await contracts.sbxToken.transfer(addr1.address, STAKE_AMOUNT.mul(2));
            await contracts.sbxToken.connect(addr1).approve(
                contracts.rewards.address,
                STAKE_AMOUNT.mul(2)
            );
            
            const durations = [30, 90, 180, 365].map(days => days * 24 * 60 * 60);
            const gasResults = [];
            
            for (const duration of durations) {
                const tx = await contracts.rewards.connect(addr1).createStakingPosition(
                    agentId,
                    STAKE_AMOUNT,
                    duration
                );
                const gas = await measureGas(tx);
                gasResults.push({ duration, gas });
                
                console.log(`Gas used for ${duration} day stake: ${gas}`);
            }
            
            // Verify staking gas usage is consistent
            const gasVariance = gasResults.reduce((max, curr, i) => {
                if (i === 0) return max;
                const diff = curr.gas.sub(gasResults[i-1].gas).abs();
                return diff.gt(max) ? diff : max;
            }, ethers.BigNumber.from(0));
            
            expect(gasVariance).to.be.lt(5000);
        });
        
        it("Should optimize reward distribution", async function () {
            const rewardScenarios = [
                { amount: REWARD_AMOUNT, category: 0 }, // Performance
                { amount: REWARD_AMOUNT.mul(2), category: 1 }, // Collaboration
                { amount: REWARD_AMOUNT.mul(3), category: 2 }  // Innovation
            ];
            
            const gasResults = [];
            
            for (const scenario of rewardScenarios) {
                const tx = await contracts.rewards.distributeReward(
                    agentId,
                    scenario.amount,
                    scenario.category
                );
                const gas = await measureGas(tx);
                gasResults.push({ scenario, gas });
                
                console.log(
                    `Gas used for ${scenario.amount} reward in category ${scenario.category}: ${gas}`
                );
            }
            
            // Verify reward distribution gas usage is consistent across categories
            const gasVariance = gasResults.reduce((max, curr, i) => {
                if (i === 0) return max;
                const diff = curr.gas.sub(gasResults[i-1].gas).abs();
                return diff.gt(max) ? diff : max;
            }, ethers.BigNumber.from(0));
            
            expect(gasVariance).to.be.lt(5000);
        });
    });
    
    describe("Governance Operations", function () {
        it("Should optimize proposal creation gas usage", async function () {
            await contracts.sbxToken.transfer(
                addr1.address,
                ethers.utils.parseEther("1000")
            );
            
            const descriptionLengths = [100, 500, 1000, 2000];
            const gasResults = [];
            
            for (const length of descriptionLengths) {
                const description = "A".repeat(length);
                const tx = await contracts.governance.connect(addr1).createProposal(
                    "Test Proposal",
                    description,
                    [agentId],
                    0, // AgentUpgrade type
                    7 * 24 * 60 * 60,
                    10
                );
                const gas = await measureGas(tx);
                gasResults.push({ length, gas });
                
                console.log(`Gas used for proposal with ${length} chars: ${gas}`);
            }
            
            // Verify gas increase is reasonable with description length
            for (let i = 1; i < gasResults.length; i++) {
                const gasIncrease = gasResults[i].gas.sub(gasResults[i-1].gas);
                const lengthIncrease = gasResults[i].length - gasResults[i-1].length;
                expect(gasIncrease.div(lengthIncrease)).to.be.lte(100);
            }
        });
        
        it("Should optimize voting operations", async function () {
            // Create proposal
            const tx = await contracts.governance.connect(addr1).createProposal(
                "Test Proposal",
                "Description",
                [agentId],
                0,
                7 * 24 * 60 * 60,
                10
            );
            const receipt = await tx.wait();
            const proposalId = receipt.events[0].args.proposalId;
            
            const voters = [addr1, addr2];
            const gasResults = [];
            
            for (const voter of voters) {
                const tx = await contracts.governance.connect(voter).castVote(
                    proposalId,
                    true,
                    "Vote justification"
                );
                const gas = await measureGas(tx);
                gasResults.push(gas);
                
                console.log(`Gas used for vote by ${voter.address}: ${gas}`);
            }
            
            // Verify voting gas usage is consistent
            const gasVariance = gasResults[1].sub(gasResults[0]).abs();
            expect(gasVariance).to.be.lt(5000);
        });
    });
    
    describe("Security Operations", function () {
        it("Should optimize security profile updates", async function () {
            await contracts.security.createSecurityProfile(agentId);
            
            const scenarios = [
                { severity: 30, description: "Low severity incident" },
                { severity: 60, description: "Medium severity incident" },
                { severity: 90, description: "High severity incident" }
            ];
            
            const gasResults = [];
            
            for (const scenario of scenarios) {
                const tx = await contracts.security.reportSecurityIncident(
                    agentId,
                    scenario.severity,
                    scenario.description
                );
                const gas = await measureGas(tx);
                gasResults.push({ scenario, gas });
                
                console.log(`Gas used for severity ${scenario.severity}: ${gas}`);
            }
            
            // Verify security operation gas usage is consistent
            const gasVariance = gasResults.reduce((max, curr, i) => {
                if (i === 0) return max;
                const diff = curr.gas.sub(gasResults[i-1].gas).abs();
                return diff.gt(max) ? diff : max;
            }, ethers.BigNumber.from(0));
            
            expect(gasVariance).to.be.lt(5000);
        });
    });
});
