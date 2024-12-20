// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title PRIME Stablecoin
 * @dev Implementation of the PRIME blockchain's native stablecoin
 * Pegged to energy cost of Boron mining
 */
contract PrimeStablecoin is ERC20, ERC20Burnable, ERC20Snapshot, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant STABILITY_ROLE = keccak256("STABILITY_ROLE");
    
    // Precision for calculations
    uint256 private constant PRECISION = 1e18;
    
    // Energy cost parameters
    struct EnergyParams {
        uint256 baseEnergyCost;     // Base energy cost per ton of Boron
        uint256 extractionCost;      // Additional processing cost per ton
        uint256 globalOutput;        // Daily Boron production in tons
        uint256 lastUpdate;          // Last energy cost update
    }
    
    // Market parameters
    struct MarketParams {
        uint256 targetPrice;         // Target price ($1.00)
        uint256 deviationThreshold;  // Allowed deviation before rebase
        uint256 dampingFactor;       // Reduces volatility in adjustments
        uint256 lastRebase;          // Last rebase timestamp
        uint256 rebaseInterval;      // Minimum time between rebases
    }
    
    // Mining parameters
    struct MiningParams {
        uint256 difficulty;          // Current mining difficulty
        uint256 targetBlockTime;     // Target time between blocks
        uint256 networkHashrate;     // Current network hashrate
        uint256 energyEfficiency;    // Mining energy efficiency factor
    }
    
    EnergyParams public energyParams;
    MarketParams public marketParams;
    MiningParams public miningParams;
    
    // Events
    event EnergyParamsUpdated(uint256 energyCost, uint256 extractionCost, uint256 output);
    event MarketParamsUpdated(uint256 targetPrice, uint256 threshold, uint256 dampingFactor);
    event MiningParamsUpdated(uint256 difficulty, uint256 hashrate, uint256 efficiency);
    event Rebase(uint256 epoch, int256 supplyDelta);
    event PriceUpdate(uint256 price, uint256 energyCost);
    
    constructor() ERC20("PRIME Stablecoin", "PRIME") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(ORACLE_ROLE, msg.sender);
        _setupRole(STABILITY_ROLE, msg.sender);
        
        // Initialize energy parameters
        energyParams = EnergyParams({
            baseEnergyCost: 500 * PRECISION,  // 500 kWh per ton
            extractionCost: 200 * PRECISION,  // $200 per ton
            globalOutput: 4900000,            // 4.9M tons (2023 data)
            lastUpdate: block.timestamp
        });
        
        // Initialize market parameters
        marketParams = MarketParams({
            targetPrice: PRECISION,           // $1.00
            deviationThreshold: PRECISION / 20, // 5%
            dampingFactor: PRECISION / 2,     // 50%
            lastRebase: block.timestamp,
            rebaseInterval: 24 hours
        });
        
        // Initialize mining parameters
        miningParams = MiningParams({
            difficulty: 1000000,              // Initial difficulty
            targetBlockTime: 30,              // 30 seconds
            networkHashrate: 0,               // Will be updated
            energyEfficiency: PRECISION       // Initial 1:1 ratio
        });
    }
    
    /**
     * @dev Update energy parameters
     */
    function updateEnergyParams(
        uint256 newEnergyCost,
        uint256 newExtractionCost,
        uint256 newOutput
    ) external onlyRole(ORACLE_ROLE) {
        require(newEnergyCost > 0, "Invalid energy cost");
        require(newOutput > 0, "Invalid output");
        
        energyParams.baseEnergyCost = newEnergyCost;
        energyParams.extractionCost = newExtractionCost;
        energyParams.globalOutput = newOutput;
        energyParams.lastUpdate = block.timestamp;
        
        emit EnergyParamsUpdated(newEnergyCost, newExtractionCost, newOutput);
    }
    
    /**
     * @dev Calculate token value based on energy costs
     */
    function calculateTokenValue() public view returns (uint256) {
        uint256 totalCost = energyParams.baseEnergyCost + energyParams.extractionCost;
        return (totalCost * PRECISION) / energyParams.globalOutput;
    }
    
    /**
     * @dev Rebase supply based on price and energy costs
     */
    function rebase(
        uint256 currentPrice
    ) external onlyRole(STABILITY_ROLE) nonReentrant returns (bool) {
        require(
            block.timestamp >= marketParams.lastRebase + marketParams.rebaseInterval,
            "Too early for rebase"
        );
        
        // Calculate token value from energy costs
        uint256 energyBasedValue = calculateTokenValue();
        
        // Use weighted average of market price and energy-based value
        uint256 effectivePrice = (currentPrice * 6 + energyBasedValue * 4) / 10;
        
        // Calculate price deviation
        uint256 deviation;
        if (effectivePrice > marketParams.targetPrice) {
            deviation = effectivePrice - marketParams.targetPrice;
        } else {
            deviation = marketParams.targetPrice - effectivePrice;
        }
        
        // Check if rebase is needed
        if (deviation > marketParams.deviationThreshold) {
            int256 supplyDelta = calculateSupplyDelta(effectivePrice);
            
            if (supplyDelta > 0) {
                _mint(address(this), uint256(supplyDelta));
            } else {
                _burn(address(this), uint256(-supplyDelta));
            }
            
            marketParams.lastRebase = block.timestamp;
            emit Rebase(totalSupplySnapshots().length, supplyDelta);
            return true;
        }
        
        return false;
    }
    
    /**
     * @dev Calculate supply adjustment
     */
    function calculateSupplyDelta(
        uint256 effectivePrice
    ) public view returns (int256) {
        // Calculate base adjustment
        int256 priceDeviation = int256(effectivePrice) - int256(marketParams.targetPrice);
        int256 adjustmentRatio = (priceDeviation * int256(marketParams.dampingFactor)) / int256(marketParams.targetPrice);
        
        // Apply mining efficiency factor
        int256 miningImpact = int256(PRECISION) - int256(miningParams.energyEfficiency);
        adjustmentRatio = (adjustmentRatio * (int256(PRECISION) + miningImpact)) / int256(PRECISION);
        
        // Calculate supply change
        return (int256(totalSupply()) * adjustmentRatio) / int256(PRECISION);
    }
    
    /**
     * @dev Update mining parameters
     */
    function updateMiningParams(
        uint256 newDifficulty,
        uint256 newHashrate,
        uint256 newEfficiency
    ) external onlyRole(STABILITY_ROLE) {
        require(newDifficulty > 0, "Invalid difficulty");
        require(newHashrate > 0, "Invalid hashrate");
        require(newEfficiency > 0, "Invalid efficiency");
        
        miningParams.difficulty = newDifficulty;
        miningParams.networkHashrate = newHashrate;
        miningParams.energyEfficiency = newEfficiency;
        
        emit MiningParamsUpdated(newDifficulty, newHashrate, newEfficiency);
    }
    
    /**
     * @dev Calculate mining reward based on energy costs
     */
    function calculateMiningReward(
        uint256 blockDifficulty
    ) external view returns (uint256) {
        uint256 energyValue = calculateTokenValue();
        uint256 efficiencyFactor = miningParams.energyEfficiency;
        
        return (energyValue * blockDifficulty * efficiencyFactor) / (miningParams.difficulty * PRECISION);
    }
    
    // Override required functions
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Snapshot) whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}
