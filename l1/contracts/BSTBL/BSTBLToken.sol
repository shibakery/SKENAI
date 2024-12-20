// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title BSTBL Token
 * @dev Implementation of the BSTBL L1 coin
 */
contract BSTBLToken is ERC20, ERC20Burnable, ERC20Snapshot, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    // Token parameters
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 1e18; // 1M tokens
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18; // 1B tokens
    
    // Market parameters
    struct MarketParams {
        uint256 lastRebaseTime;
        uint256 rebaseInterval;
        uint256 targetPrice;
        uint256 deviationThreshold;
    }
    
    MarketParams public marketParams;
    
    // Events
    event Rebase(uint256 epoch, uint256 totalSupply);
    event PriceUpdate(uint256 newPrice, uint256 targetPrice);
    event MarketParamsUpdated(
        uint256 rebaseInterval,
        uint256 targetPrice,
        uint256 deviationThreshold
    );
    
    constructor() ERC20("Boron Stable Token", "BSTBL") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(SNAPSHOT_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        
        // Initialize market parameters
        marketParams = MarketParams({
            lastRebaseTime: block.timestamp,
            rebaseInterval: 24 hours,
            targetPrice: 1e18, // $1.00
            deviationThreshold: 5e16 // 5%
        });
        
        // Mint initial supply
        _mint(msg.sender, INITIAL_SUPPLY);
    }
    
    /**
     * @dev Create a new snapshot
     */
    function snapshot() public onlyRole(SNAPSHOT_ROLE) returns (uint256) {
        return _snapshot();
    }
    
    /**
     * @dev Pause token transfers
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause token transfers
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Mint new tokens
     */
    function mint(
        address to,
        uint256 amount
    ) public onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }
    
    /**
     * @dev Rebase token supply based on market conditions
     */
    function rebase(
        uint256 currentPrice
    ) external onlyRole(MINTER_ROLE) nonReentrant returns (bool) {
        require(
            block.timestamp >= marketParams.lastRebaseTime + marketParams.rebaseInterval,
            "Too early for rebase"
        );
        
        // Calculate price deviation
        uint256 deviation;
        if (currentPrice > marketParams.targetPrice) {
            deviation = currentPrice - marketParams.targetPrice;
        } else {
            deviation = marketParams.targetPrice - currentPrice;
        }
        
        // Check if rebase is needed
        if (deviation > marketParams.deviationThreshold) {
            uint256 supplyDelta = _calculateSupplyDelta(currentPrice);
            
            if (currentPrice > marketParams.targetPrice) {
                // Price too high - increase supply
                require(totalSupply() + supplyDelta <= MAX_SUPPLY, "Exceeds max supply");
                _mint(address(this), supplyDelta);
            } else {
                // Price too low - decrease supply
                _burn(address(this), supplyDelta);
            }
            
            marketParams.lastRebaseTime = block.timestamp;
            emit Rebase(totalSupplySnapshots().length, totalSupply());
            return true;
        }
        
        return false;
    }
    
    /**
     * @dev Update market parameters
     */
    function updateMarketParams(
        uint256 rebaseInterval,
        uint256 targetPrice,
        uint256 deviationThreshold
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(rebaseInterval > 0, "Invalid interval");
        require(targetPrice > 0, "Invalid target price");
        require(deviationThreshold > 0 && deviationThreshold < 1e18, "Invalid threshold");
        
        marketParams.rebaseInterval = rebaseInterval;
        marketParams.targetPrice = targetPrice;
        marketParams.deviationThreshold = deviationThreshold;
        
        emit MarketParamsUpdated(rebaseInterval, targetPrice, deviationThreshold);
    }
    
    /**
     * @dev Calculate supply adjustment
     */
    function _calculateSupplyDelta(
        uint256 currentPrice
    ) internal view returns (uint256) {
        uint256 deviation;
        if (currentPrice > marketParams.targetPrice) {
            deviation = currentPrice - marketParams.targetPrice;
        } else {
            deviation = marketParams.targetPrice - currentPrice;
        }
        
        // Calculate proportional supply adjustment
        uint256 supplyDelta = (totalSupply() * deviation) / marketParams.targetPrice;
        
        // Apply dampening factor to prevent large swings
        return supplyDelta / 2;
    }
    
    // Override required functions
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Snapshot) whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
    
    // The following functions are overrides required by Solidity
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        super._afterTokenTransfer(from, to, amount);
    }
    
    function _mint(
        address to,
        uint256 amount
    ) internal override(ERC20) {
        super._mint(to, amount);
    }
    
    function _burn(
        address account,
        uint256 amount
    ) internal override(ERC20) {
        super._burn(account, amount);
    }
}
