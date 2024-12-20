// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title BoronStable
 * @dev Implements a stablecoin pegged to Boron market value
 */
contract BoronStable is ERC20, AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    // Boron market data
    struct BoronData {
        uint256 globalSupply;      // in metric tons
        uint256 activeMiningSites; // number of active mining sites
        uint256 marketDemand;      // in metric tons
        uint256 lastUpdate;        // timestamp
    }
    
    // Price stability parameters
    struct StabilityParams {
        uint256 targetPrice;       // target price in USD (18 decimals)
        uint256 supplyThreshold;   // threshold for supply adjustment
        uint256 adjustmentRate;    // rate of supply adjustment
        uint256 cooldownPeriod;    // minimum time between adjustments
    }
    
    BoronData public boronData;
    StabilityParams public stabilityParams;
    
    // Events
    event SupplyAdjusted(uint256 amount, bool isIncrease);
    event OracleDataUpdated(uint256 supply, uint256 demand);
    event StabilityParamsUpdated(uint256 targetPrice, uint256 threshold);
    
    constructor() ERC20("Boron Stable Token", "BRST") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        // Initialize stability parameters
        stabilityParams = StabilityParams({
            targetPrice: 1e18,         // $1.00
            supplyThreshold: 5e16,     // 5% deviation
            adjustmentRate: 1e17,      // 10% adjustment
            cooldownPeriod: 1 hours
        });
    }
    
    /**
     * @dev Update Boron market data from oracle
     */
    function updateBoronData(
        uint256 supply,
        uint256 sites,
        uint256 demand
    ) external onlyRole(ORACLE_ROLE) {
        require(supply > 0, "Invalid supply");
        require(demand > 0, "Invalid demand");
        
        boronData = BoronData({
            globalSupply: supply,
            activeMiningSites: sites,
            marketDemand: demand,
            lastUpdate: block.timestamp
        });
        
        emit OracleDataUpdated(supply, demand);
        
        // Adjust supply based on new data
        _adjustSupply();
    }
    
    /**
     * @dev Mint new tokens
     */
    function mint(
        address to,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(to != address(0), "Invalid address");
        _mint(to, amount);
    }
    
    /**
     * @dev Burn tokens
     */
    function burn(
        uint256 amount
    ) external whenNotPaused {
        _burn(msg.sender, amount);
    }
    
    /**
     * @dev Update stability parameters
     */
    function updateStabilityParams(
        uint256 targetPrice,
        uint256 threshold,
        uint256 rate,
        uint256 cooldown
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(targetPrice > 0, "Invalid target price");
        require(threshold > 0 && threshold < 1e18, "Invalid threshold");
        require(rate > 0 && rate < 1e18, "Invalid rate");
        
        stabilityParams = StabilityParams({
            targetPrice: targetPrice,
            supplyThreshold: threshold,
            adjustmentRate: rate,
            cooldownPeriod: cooldown
        });
        
        emit StabilityParamsUpdated(targetPrice, threshold);
    }
    
    /**
     * @dev Internal function to adjust supply based on market conditions
     */
    function _adjustSupply() internal {
        // Calculate supply-demand ratio
        uint256 ratio = (boronData.marketDemand * 1e18) / boronData.globalSupply;
        
        // Check if adjustment is needed
        if (ratio > 1e18 + stabilityParams.supplyThreshold) {
            // Demand exceeds supply - mint tokens
            uint256 mintAmount = (totalSupply() * stabilityParams.adjustmentRate) / 1e18;
            _mint(address(this), mintAmount);
            emit SupplyAdjusted(mintAmount, true);
        } else if (ratio < 1e18 - stabilityParams.supplyThreshold) {
            // Supply exceeds demand - burn tokens
            uint256 burnAmount = (totalSupply() * stabilityParams.adjustmentRate) / 1e18;
            _burn(address(this), burnAmount);
            emit SupplyAdjusted(burnAmount, false);
        }
    }
    
    /**
     * @dev Pause token operations
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause token operations
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
