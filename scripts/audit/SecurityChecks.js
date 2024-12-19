const { ethers } = require("hardhat");
const { execSync } = require("child_process");

class SecurityChecker {
    constructor(contracts) {
        this.contracts = contracts;
        this.vulnerabilities = [];
        this.recommendations = [];
    }
    
    async runFullScan() {
        console.log("Running comprehensive security scan...\n");
        
        await this.checkAccessControl();
        await this.checkReentrancy();
        await this.checkIntegerOverflow();
        await this.checkTokenSecurity();
        await this.checkGovernanceSecurity();
        await this.checkEmergencyProcedures();
        await this.checkEventEmissions();
        await this.checkGasOptimization();
        await this.checkUpgradeability();
        await this.checkExternalCalls();
        
        return {
            vulnerabilities: this.vulnerabilities,
            recommendations: this.recommendations,
            passed: this.vulnerabilities.length === 0
        };
    }
    
    async checkAccessControl() {
        console.log("Checking access control...");
        
        try {
            const contracts = this.contracts;
            
            // Check role assignments
            for (const [name, contract] of Object.entries(contracts)) {
                if (contract.hasRole) {
                    const roles = await this.getRoles(contract);
                    for (const role of roles) {
                        const members = await contract.getRoleMemberCount(role);
                        if (members.eq(0)) {
                            this.vulnerabilities.push(
                                `${name}: Role ${role} has no members assigned`
                            );
                        }
                        if (members.gt(5)) {
                            this.recommendations.push(
                                `${name}: Consider reducing number of members for role ${role}`
                            );
                        }
                    }
                }
            }
            
            // Check admin roles
            if (contracts.registry) {
                const DEFAULT_ADMIN_ROLE = await contracts.registry.DEFAULT_ADMIN_ROLE();
                const adminCount = await contracts.registry.getRoleMemberCount(DEFAULT_ADMIN_ROLE);
                if (adminCount.lt(2)) {
                    this.recommendations.push(
                        "Consider implementing multi-sig admin control"
                    );
                }
            }
            
        } catch (error) {
            this.vulnerabilities.push(`Access control check failed: ${error.message}`);
        }
    }
    
    async checkReentrancy() {
        console.log("Checking reentrancy vulnerabilities...");
        
        try {
            const contracts = this.contracts;
            
            // Check reward distributions
            if (contracts.rewards) {
                const code = await ethers.provider.getCode(contracts.rewards.address);
                if (!code.includes("nonReentrant")) {
                    this.vulnerabilities.push(
                        "Rewards contract missing reentrancy protection"
                    );
                }
            }
            
            // Check governance executions
            if (contracts.governance) {
                const code = await ethers.provider.getCode(contracts.governance.address);
                if (!code.includes("nonReentrant")) {
                    this.vulnerabilities.push(
                        "Governance execution missing reentrancy protection"
                    );
                }
            }
            
        } catch (error) {
            this.vulnerabilities.push(`Reentrancy check failed: ${error.message}`);
        }
    }
    
    async checkIntegerOverflow() {
        console.log("Checking integer overflow protections...");
        
        try {
            // Check performance calculations
            if (this.contracts.performance) {
                const code = await ethers.provider.getCode(this.contracts.performance.address);
                if (!code.includes("SafeMath")) {
                    this.recommendations.push(
                        "Consider using SafeMath for performance calculations"
                    );
                }
            }
            
            // Check reward calculations
            if (this.contracts.rewards) {
                const code = await ethers.provider.getCode(this.contracts.rewards.address);
                if (!code.includes("SafeMath")) {
                    this.vulnerabilities.push(
                        "Rewards contract missing SafeMath implementation"
                    );
                }
            }
            
        } catch (error) {
            this.vulnerabilities.push(`Integer overflow check failed: ${error.message}`);
        }
    }
    
    async checkTokenSecurity() {
        console.log("Checking token security...");
        
        try {
            const { sbxToken } = this.contracts;
            
            if (sbxToken) {
                // Check transfer restrictions
                const code = await ethers.provider.getCode(sbxToken.address);
                if (!code.includes("pause")) {
                    this.recommendations.push(
                        "Consider adding pause functionality to token"
                    );
                }
                
                // Check minting capabilities
                const totalSupply = await sbxToken.totalSupply();
                const cap = ethers.utils.parseEther("1000000000");
                if (totalSupply.gt(cap)) {
                    this.vulnerabilities.push("Token supply exceeds intended cap");
                }
            }
            
        } catch (error) {
            this.vulnerabilities.push(`Token security check failed: ${error.message}`);
        }
    }
    
    async checkGovernanceSecurity() {
        console.log("Checking governance security...");
        
        try {
            const { governance } = this.contracts;
            
            if (governance) {
                // Check timelock
                const params = await governance.getGovernanceParameters();
                if (params.executionDelay.lt(24 * 3600)) {
                    this.recommendations.push(
                        "Consider increasing proposal execution delay"
                    );
                }
                
                // Check quorum requirements
                if (params.quorumPercentage.lt(10)) {
                    this.vulnerabilities.push("Quorum requirement too low");
                }
            }
            
        } catch (error) {
            this.vulnerabilities.push(`Governance security check failed: ${error.message}`);
        }
    }
    
    async checkEmergencyProcedures() {
        console.log("Checking emergency procedures...");
        
        try {
            const contracts = this.contracts;
            
            // Check pause functionality
            for (const [name, contract] of Object.entries(contracts)) {
                if (contract.paused && !contract.pause) {
                    this.recommendations.push(
                        `${name}: Consider adding emergency pause functionality`
                    );
                }
            }
            
            // Check emergency roles
            if (contracts.security) {
                const EMERGENCY_ROLE = await contracts.security.EMERGENCY_ROLE();
                const emergencyAdmins = await contracts.security.getRoleMemberCount(EMERGENCY_ROLE);
                if (emergencyAdmins.lt(2)) {
                    this.vulnerabilities.push(
                        "Insufficient emergency response administrators"
                    );
                }
            }
            
        } catch (error) {
            this.vulnerabilities.push(`Emergency procedures check failed: ${error.message}`);
        }
    }
    
    async checkEventEmissions() {
        console.log("Checking event emissions...");
        
        try {
            // Check critical operations
            for (const [name, contract] of Object.entries(this.contracts)) {
                const code = await ethers.provider.getCode(contract.address);
                if (!code.includes("event")) {
                    this.recommendations.push(
                        `${name}: Consider adding event emissions for critical operations`
                    );
                }
            }
            
        } catch (error) {
            this.vulnerabilities.push(`Event emission check failed: ${error.message}`);
        }
    }
    
    async checkGasOptimization() {
        console.log("Checking gas optimization...");
        
        try {
            for (const [name, contract] of Object.entries(this.contracts)) {
                const code = await ethers.provider.getCode(contract.address);
                const size = (code.length - 2) / 2;
                
                if (size > 20000) {
                    this.recommendations.push(
                        `${name}: Consider optimizing contract size (${size} bytes)`
                    );
                }
            }
            
        } catch (error) {
            this.vulnerabilities.push(`Gas optimization check failed: ${error.message}`);
        }
    }
    
    async checkUpgradeability() {
        console.log("Checking upgradeability...");
        
        try {
            for (const [name, contract] of Object.entries(this.contracts)) {
                const code = await ethers.provider.getCode(contract.address);
                
                if (code.includes("delegatecall")) {
                    this.recommendations.push(
                        `${name}: Review delegatecall usage for security implications`
                    );
                }
                
                if (!code.includes("initialize")) {
                    this.recommendations.push(
                        `${name}: Consider implementing initializable pattern`
                    );
                }
            }
            
        } catch (error) {
            this.vulnerabilities.push(`Upgradeability check failed: ${error.message}`);
        }
    }
    
    async checkExternalCalls() {
        console.log("Checking external calls...");
        
        try {
            for (const [name, contract] of Object.entries(this.contracts)) {
                const code = await ethers.provider.getCode(contract.address);
                
                if (code.includes("call{value:")) {
                    this.vulnerabilities.push(
                        `${name}: Review raw call usage with value transfer`
                    );
                }
                
                if (code.includes("selfdestruct")) {
                    this.vulnerabilities.push(
                        `${name}: Contains selfdestruct - review for security implications`
                    );
                }
            }
            
        } catch (error) {
            this.vulnerabilities.push(`External call check failed: ${error.message}`);
        }
    }
    
    async getRoles(contract) {
        const roles = [];
        try {
            const filter = contract.filters.RoleGranted();
            const events = await contract.queryFilter(filter);
            roles.push(...new Set(events.map(e => e.args.role)));
        } catch (error) {
            console.warn(`Could not fetch roles for contract: ${error.message}`);
        }
        return roles;
    }
}

module.exports = {
    SecurityChecker
};
