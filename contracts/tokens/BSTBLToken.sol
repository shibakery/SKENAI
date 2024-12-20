// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title BSTBLToken
 * @dev Implementation of the Boron-backed Stablecoin (BSTBL)
 * This token maintains stability through energy cost tracking and boron market dynamics
 */
contract BSTBLToken is ERC20, AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    
    // Energy backing tracking
    struct EnergyMetrics {
        uint256 computationalEnergy;  // Energy used in computation
        uint256 stakingEnergy;        // Energy from staking operations
        uint256 totalEnergy;          // Total energy backing
        uint256 lastUpdate;           // Last update timestamp
        uint256 efficiency;           // Energy efficiency score (1-10000)
    }
    
    // Market parameters
    struct MarketParams {
        uint256 boronPrice;           // Current boron price (USD)
        uint256 energyCost;           // Energy cost per unit (USD)
        uint256 stabilityIndex;       // Market stability score (1-10000)
        uint256 lastUpdate;           // Last update timestamp
    }
    
    // State variables
    mapping(address => EnergyMetrics) public energyMetrics;
    MarketParams public marketParams;
    
    // Constants
    uint256 public constant PRECISION = 10000;
    uint256 public constant MIN_EFFICIENCY = 5000;      // 50%
    uint256 public constant MAX_MINT_AMOUNT = 1000000 * 10**18;  // 1M tokens
    uint256 public constant UPDATE_COOLDOWN = 1 hours;
    
    // Events
    event EnergyUpdated(
        address indexed user,
        uint256 computationalEnergy,
        uint256 stakingEnergy,
        uint256 efficiency
    );
    event MarketParamsUpdated(
        uint256 boronPrice,
        uint256 energyCost,
        uint256 stabilityIndex
    );
    event StabilityAdjustment(
        uint256 oldIndex,
        uint256 newIndex,
        uint256 timestamp
    );
    
    constructor() ERC20("Boron Stablecoin", "BSTBL") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        
        // Initialize market parameters
        marketParams = MarketParams({
            boronPrice: 1000,         // $10.00 USD
            energyCost: 100,          // $1.00 USD per unit
            stabilityIndex: 10000,    // 100%
            lastUpdate: block.timestamp
        });
    }
    
    /**
     * @dev Update energy metrics for a user
     * @param user Address of the user
     * @param computationalEnergy New computational energy value
     * @param stakingEnergy New staking energy value
     * @param efficiency New efficiency score
     */
    function updateEnergyMetrics(
        address user,
        uint256 computationalEnergy,
        uint256 stakingEnergy,
        uint256 efficiency
    ) external onlyRole(ORACLE_ROLE) whenNotPaused {
        require(efficiency <= PRECISION, "Invalid efficiency");
        require(efficiency >= MIN_EFFICIENCY, "Efficiency too low");
        
        EnergyMetrics storage metrics = energyMetrics[user];
        require(
            block.timestamp >= metrics.lastUpdate + UPDATE_COOLDOWN,
            "Update too frequent"
        );
        
        metrics.computationalEnergy = computationalEnergy;
        metrics.stakingEnergy = stakingEnergy;
        metrics.totalEnergy = computationalEnergy + stakingEnergy;
        metrics.efficiency = efficiency;
        metrics.lastUpdate = block.timestamp;
        
        emit EnergyUpdated(
            user,
            computationalEnergy,
            stakingEnergy,
            efficiency
        );
    }
    
    /**
     * @dev Update market parameters
     * @param boronPrice New boron price
     * @param energyCost New energy cost
     * @param stabilityIndex New stability index
     */
    function updateMarketParams(
        uint256 boronPrice,
        uint256 energyCost,
        uint256 stabilityIndex
    ) external onlyRole(ORACLE_ROLE) whenNotPaused {
        require(stabilityIndex <= PRECISION, "Invalid stability index");
        require(
            block.timestamp >= marketParams.lastUpdate + UPDATE_COOLDOWN,
            "Update too frequent"
        );
        
        emit StabilityAdjustment(
            marketParams.stabilityIndex,
            stabilityIndex,
            block.timestamp
        );
        
        marketParams = MarketParams({
            boronPrice: boronPrice,
            energyCost: energyCost,
            stabilityIndex: stabilityIndex,
            lastUpdate: block.timestamp
        });
        
        emit MarketParamsUpdated(boronPrice, energyCost, stabilityIndex);
    }
    
    /**
     * @dev Mint tokens based on energy backing
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(
        address to,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(amount <= MAX_MINT_AMOUNT, "Amount exceeds limit");
        
        EnergyMetrics storage metrics = energyMetrics[to];
        require(metrics.efficiency >= MIN_EFFICIENCY, "Insufficient efficiency");
        
        uint256 requiredEnergy = (amount * marketParams.energyCost) / (marketParams.boronPrice * marketParams.stabilityIndex);
        require(metrics.totalEnergy >= requiredEnergy, "Insufficient energy backing");
        
        _mint(to, amount);
    }
    
    /**
     * @dev Burn tokens
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burn(
        address from,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) whenNotPaused nonReentrant {
        _burn(from, amount);
    }
    
    /**
     * @dev Get current energy value for a user
     * @param user Address to check
     * @return Value of energy backing
     */
    function getEnergyValue(address user) external view returns (uint256) {
        EnergyMetrics storage metrics = energyMetrics[user];
        return (metrics.totalEnergy * metrics.efficiency * marketParams.energyCost) / PRECISION;
    }
    
    /**
     * @dev Verify energy proof for consensus
     * @param proof Energy proof data
     * @return isValid Whether the proof is valid
     */
    function verifyEnergyProof(
        bytes memory proof
    ) external view returns (bool) {
        // TODO: Implement proof verification logic
        return true;
    }
    
    /**
     * @dev Emergency pause
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev Resume from pause
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
