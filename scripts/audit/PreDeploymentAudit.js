const { ethers } = require("hardhat");
const { deployFullSuite } = require("../helpers/testHelpers");
const { DeploymentMonitor } = require("../monitor/DeploymentMonitor");

async function runSecurityAudit() {
    console.log("Starting Pre-deployment Security Audit...\n");
    
    const results = {
        contractChecks: {},
        vulnerabilities: [],
        recommendations: [],
        passed: true
    };
    
    try {
        // Deploy contracts in test environment
        const contracts = await deployFullSuite();
        
        // 1. Check Contract Sizes
        console.log("Checking contract sizes...");
        for (const [name, contract] of Object.entries(contracts)) {
            if (typeof contract.address === 'string') {
                const bytecode = await ethers.provider.getCode(contract.address);
                const size = bytecode.length / 2 - 1; // Convert from hex
                results.contractChecks[name] = {
                    size,
                    withinLimit: size <= 24576 // Ethereum contract size limit
                };
                
                if (!results.contractChecks[name].withinLimit) {
                    results.passed = false;
                    results.vulnerabilities.push(
                        `${name} exceeds size limit: ${size} bytes`
                    );
                }
            }
        }
        
        // 2. Check Role Configurations
        console.log("Checking role configurations...");
        const roles = await checkRoleConfigurations(contracts);
        results.contractChecks.roles = roles;
        
        // 3. Check Security Configurations
        console.log("Checking security configurations...");
        const security = await checkSecurityConfigurations(contracts);
        results.contractChecks.security = security;
        
        // 4. Check Governance Parameters
        console.log("Checking governance parameters...");
        const governance = await checkGovernanceParameters(contracts);
        results.contractChecks.governance = governance;
        
        // 5. Check Token Economics
        console.log("Checking token economics...");
        const tokenomics = await checkTokenEconomics(contracts);
        results.contractChecks.tokenomics = tokenomics;
        
        // Generate recommendations
        results.recommendations = generateRecommendations(results);
        
    } catch (error) {
        results.passed = false;
        results.vulnerabilities.push(`Audit failed: ${error.message}`);
    }
    
    // Output results
    console.log("\nAudit Results:");
    console.log("==============");
    console.log(`Overall Status: ${results.passed ? "PASSED" : "FAILED"}`);
    
    if (results.vulnerabilities.length > 0) {
        console.log("\nVulnerabilities Found:");
        results.vulnerabilities.forEach(v => console.log(`- ${v}`));
    }
    
    if (results.recommendations.length > 0) {
        console.log("\nRecommendations:");
        results.recommendations.forEach(r => console.log(`- ${r}`));
    }
    
    return results;
}

async function checkRoleConfigurations(contracts) {
    const results = {
        passed: true,
        issues: []
    };
    
    try {
        const { registry, performance, security, rewards, governance } = contracts;
        
        // Check Registry Roles
        const registrarRole = await registry.REGISTRAR_ROLE();
        if (await registry.getRoleMemberCount(registrarRole) === 0) {
            results.passed = false;
            results.issues.push("Registry: No REGISTRAR_ROLE members");
        }
        
        // Check Performance Roles
        const evaluatorRole = await performance.EVALUATOR_ROLE();
        if (await performance.getRoleMemberCount(evaluatorRole) === 0) {
            results.passed = false;
            results.issues.push("Performance: No EVALUATOR_ROLE members");
        }
        
        // Check Security Roles
        const securityAdminRole = await security.SECURITY_ADMIN_ROLE();
        if (await security.getRoleMemberCount(securityAdminRole) === 0) {
            results.passed = false;
            results.issues.push("Security: No SECURITY_ADMIN_ROLE members");
        }
        
    } catch (error) {
        results.passed = false;
        results.issues.push(`Role check failed: ${error.message}`);
    }
    
    return results;
}

async function checkSecurityConfigurations(contracts) {
    const results = {
        passed: true,
        issues: []
    };
    
    try {
        const { security } = contracts;
        
        // Check security thresholds
        const config = await security.getSecurityConfig();
        if (config.minSecurityScore.lt(50)) {
            results.passed = false;
            results.issues.push("Security: Minimum security score too low");
        }
        
        // Check incident handling
        const incidentConfig = await security.getIncidentConfig();
        if (incidentConfig.responseTimeout.lt(3600)) { // 1 hour minimum
            results.passed = false;
            results.issues.push("Security: Incident response timeout too short");
        }
        
    } catch (error) {
        results.passed = false;
        results.issues.push(`Security check failed: ${error.message}`);
    }
    
    return results;
}

async function checkGovernanceParameters(contracts) {
    const results = {
        passed: true,
        issues: []
    };
    
    try {
        const { governance } = contracts;
        
        // Check governance parameters
        const params = await governance.getGovernanceParameters();
        
        if (params.quorumPercentage.lt(10)) {
            results.passed = false;
            results.issues.push("Governance: Quorum percentage too low");
        }
        
        if (params.votingPeriod.lt(24 * 3600)) { // 1 day minimum
            results.passed = false;
            results.issues.push("Governance: Voting period too short");
        }
        
    } catch (error) {
        results.passed = false;
        results.issues.push(`Governance check failed: ${error.message}`);
    }
    
    return results;
}

async function checkTokenEconomics(contracts) {
    const results = {
        passed: true,
        issues: []
    };
    
    try {
        const { sbxToken, rewards } = contracts;
        
        // Check total supply
        const totalSupply = await sbxToken.totalSupply();
        if (totalSupply.gt(ethers.utils.parseEther("1000000000"))) {
            results.passed = false;
            results.issues.push("Token: Total supply exceeds 1 billion");
        }
        
        // Check reward parameters
        const rewardConfig = await rewards.getRewardConfig();
        if (rewardConfig.baseReward.gt(ethers.utils.parseEther("1000"))) {
            results.passed = false;
            results.issues.push("Rewards: Base reward too high");
        }
        
    } catch (error) {
        results.passed = false;
        results.issues.push(`Token economics check failed: ${error.message}`);
    }
    
    return results;
}

function generateRecommendations(results) {
    const recommendations = [];
    
    // Contract size recommendations
    Object.entries(results.contractChecks)
        .filter(([name, check]) => check.size > 20000)
        .forEach(([name]) => {
            recommendations.push(
                `Consider optimizing ${name} to reduce contract size`
            );
        });
    
    // Add specific recommendations based on vulnerabilities
    results.vulnerabilities.forEach(v => {
        if (v.includes("size limit")) {
            recommendations.push(
                "Implement contract splitting pattern to reduce contract sizes"
            );
        }
        if (v.includes("role")) {
            recommendations.push(
                "Review role-based access control implementation"
            );
        }
    });
    
    return recommendations;
}

module.exports = {
    runSecurityAudit
};
