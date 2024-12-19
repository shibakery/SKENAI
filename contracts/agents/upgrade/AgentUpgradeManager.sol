// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../AgentRegistry.sol";
import "../validation/AgentValidator.sol";
import "../security/AgentSecurity.sol";

contract AgentUpgradeManager is AccessControl, ReentrancyGuard {
    bytes32 public constant UPGRADE_MANAGER_ROLE = keccak256("UPGRADE_MANAGER_ROLE");
    bytes32 public constant IMPLEMENTATION_MANAGER_ROLE = keccak256("IMPLEMENTATION_MANAGER_ROLE");
    
    AgentRegistry public immutable registry;
    AgentValidator public immutable validator;
    AgentSecurity public immutable security;
    
    struct Implementation {
        address implementation;
        uint256 version;
        bool active;
        bytes32 checksum;
        address proposer;
        uint256 timestamp;
    }
    
    struct Upgrade {
        bytes32 upgradeId;
        bytes32 agentId;
        address fromImplementation;
        address toImplementation;
        uint256 proposedTime;
        uint256 scheduledTime;
        bool validated;
        bool executed;
        bytes32 validationResult;
    }
    
    // Upgrade storage
    mapping(bytes32 => Implementation) public implementations;
    mapping(bytes32 => Upgrade) public upgrades;
    mapping(bytes32 => bytes32[]) public agentUpgrades;
    mapping(address => bool) public validatedImplementations;
    
    // Version tracking
    mapping(bytes32 => uint256) public agentVersions;
    mapping(uint256 => bytes32[]) public versionImplementations;
    
    uint256 public constant UPGRADE_DELAY = 1 days;
    uint256 public constant MAX_VERSION_JUMP = 2;
    
    event ImplementationRegistered(
        bytes32 indexed implementationId,
        address implementation,
        uint256 version,
        bytes32 checksum
    );
    
    event UpgradeProposed(
        bytes32 indexed upgradeId,
        bytes32 indexed agentId,
        address fromImplementation,
        address toImplementation
    );
    
    event UpgradeValidated(
        bytes32 indexed upgradeId,
        bytes32 validationResult
    );
    
    event UpgradeExecuted(
        bytes32 indexed upgradeId,
        bytes32 indexed agentId,
        uint256 newVersion
    );
    
    constructor(
        address _registry,
        address _validator,
        address _security
    ) {
        registry = AgentRegistry(_registry);
        validator = AgentValidator(_validator);
        security = AgentSecurity(_security);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_MANAGER_ROLE, msg.sender);
        _grantRole(IMPLEMENTATION_MANAGER_ROLE, msg.sender);
    }
    
    function registerImplementation(
        address implementation,
        uint256 version,
        bytes32 checksum
    ) external onlyRole(IMPLEMENTATION_MANAGER_ROLE) returns (bytes32) {
        require(implementation != address(0), "Invalid implementation");
        require(version > 0, "Invalid version");
        
        bytes32 implementationId = keccak256(
            abi.encodePacked(implementation, version, checksum)
        );
        
        implementations[implementationId] = Implementation({
            implementation: implementation,
            version: version,
            active: true,
            checksum: checksum,
            proposer: msg.sender,
            timestamp: block.timestamp
        });
        
        versionImplementations[version].push(implementationId);
        
        emit ImplementationRegistered(
            implementationId,
            implementation,
            version,
            checksum
        );
        
        return implementationId;
    }
    
    function proposeUpgrade(
        bytes32 agentId,
        address toImplementation
    ) external onlyRole(UPGRADE_MANAGER_ROLE) returns (bytes32) {
        require(validatedImplementations[toImplementation], "Implementation not validated");
        
        (address currentImplementation,,,,,,,) = registry.agents(agentId);
        require(currentImplementation != toImplementation, "Same implementation");
        
        bytes32 upgradeId = generateUpgradeId(agentId, toImplementation);
        
        upgrades[upgradeId] = Upgrade({
            upgradeId: upgradeId,
            agentId: agentId,
            fromImplementation: currentImplementation,
            toImplementation: toImplementation,
            proposedTime: block.timestamp,
            scheduledTime: block.timestamp + UPGRADE_DELAY,
            validated: false,
            executed: false,
            validationResult: bytes32(0)
        });
        
        agentUpgrades[agentId].push(upgradeId);
        
        emit UpgradeProposed(
            upgradeId,
            agentId,
            currentImplementation,
            toImplementation
        );
        
        return upgradeId;
    }
    
    function validateUpgrade(
        bytes32 upgradeId
    ) external onlyRole(UPGRADE_MANAGER_ROLE) {
        Upgrade storage upgrade = upgrades[upgradeId];
        require(!upgrade.validated, "Already validated");
        
        // Perform validation checks
        bytes32 validationResult = performUpgradeValidation(upgrade);
        upgrade.validated = true;
        upgrade.validationResult = validationResult;
        
        emit UpgradeValidated(upgradeId, validationResult);
    }
    
    function executeUpgrade(
        bytes32 upgradeId
    ) external onlyRole(UPGRADE_MANAGER_ROLE) nonReentrant {
        Upgrade storage upgrade = upgrades[upgradeId];
        require(canExecuteUpgrade(upgradeId), "Cannot execute upgrade");
        
        // Perform the upgrade
        bool success = performUpgrade(upgrade);
        require(success, "Upgrade failed");
        
        upgrade.executed = true;
        uint256 newVersion = agentVersions[upgrade.agentId] + 1;
        agentVersions[upgrade.agentId] = newVersion;
        
        emit UpgradeExecuted(upgradeId, upgrade.agentId, newVersion);
    }
    
    function getAgentUpgrades(
        bytes32 agentId
    ) external view returns (bytes32[] memory) {
        return agentUpgrades[agentId];
    }
    
    function getImplementationsByVersion(
        uint256 version
    ) external view returns (bytes32[] memory) {
        return versionImplementations[version];
    }
    
    // Internal functions
    function generateUpgradeId(
        bytes32 agentId,
        address toImplementation
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                agentId,
                toImplementation,
                block.timestamp
            )
        );
    }
    
    function performUpgradeValidation(
        Upgrade storage upgrade
    ) internal returns (bytes32) {
        // Validate version jump
        uint256 fromVersion = agentVersions[upgrade.agentId];
        uint256 toVersion = fromVersion + 1;
        require(toVersion - fromVersion <= MAX_VERSION_JUMP, "Version jump too large");
        
        // Validate implementation
        require(
            validatedImplementations[upgrade.toImplementation],
            "Implementation not validated"
        );
        
        // Perform security checks
        security.validateOperation(
            upgrade.agentId,
            this.executeUpgrade.selector,
            0,
            0
        );
        
        return bytes32(0); // Success
    }
    
    function canExecuteUpgrade(
        bytes32 upgradeId
    ) internal view returns (bool) {
        Upgrade storage upgrade = upgrades[upgradeId];
        
        if (upgrade.executed) return false;
        if (!upgrade.validated) return false;
        if (block.timestamp < upgrade.scheduledTime) return false;
        
        return true;
    }
    
    function performUpgrade(
        Upgrade storage upgrade
    ) internal returns (bool) {
        // Create proxy if needed
        address proxyAddress = getProxyAddress(upgrade.agentId);
        if (proxyAddress == address(0)) {
            proxyAddress = createProxy(upgrade.agentId, upgrade.toImplementation);
        }
        
        // Upgrade proxy
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(proxyAddress)
        );
        
        try proxy.upgradeTo(upgrade.toImplementation) {
            return true;
        } catch {
            return false;
        }
    }
    
    function getProxyAddress(
        bytes32 agentId
    ) internal view returns (address) {
        // Implementation to get proxy address
        return address(0);
    }
    
    function createProxy(
        bytes32 agentId,
        address implementation
    ) internal returns (address) {
        // Implementation to create new proxy
        return address(0);
    }
}
