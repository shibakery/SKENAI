// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../tokens/SBXToken.sol";

contract DutchAuction is AccessControl, ReentrancyGuard {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    SBXToken public sbxToken;
    IERC20 public paymentToken;
    
    struct AuctionConfig {
        uint256 startTime;
        uint256 endTime;
        uint256 startPrice;
        uint256 endPrice;
        uint256 totalTokens;
        uint256 minPurchase;
        uint256 maxPurchase;
    }
    
    struct AuctionState {
        uint256 tokensSold;
        uint256 totalRaised;
        bool finalized;
    }
    
    AuctionConfig public config;
    AuctionState public state;
    
    mapping(address => uint256) public purchases;
    
    event AuctionStarted(
        uint256 startTime,
        uint256 endTime,
        uint256 startPrice,
        uint256 endPrice
    );
    event TokensPurchased(
        address indexed buyer,
        uint256 amount,
        uint256 price
    );
    event AuctionFinalized(
        uint256 tokensSold,
        uint256 totalRaised
    );
    
    constructor(
        address _sbxToken,
        address _paymentToken
    ) {
        sbxToken = SBXToken(_sbxToken);
        paymentToken = IERC20(_paymentToken);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }
    
    function startAuction(
        uint256 startTime,
        uint256 duration,
        uint256 startPrice,
        uint256 endPrice,
        uint256 totalTokens,
        uint256 minPurchase,
        uint256 maxPurchase
    ) external onlyRole(MANAGER_ROLE) {
        require(block.timestamp < startTime, "Invalid start time");
        require(duration > 0, "Invalid duration");
        require(startPrice > endPrice, "Invalid prices");
        require(totalTokens > 0, "Invalid token amount");
        require(maxPurchase >= minPurchase, "Invalid purchase limits");
        
        config.startTime = startTime;
        config.endTime = startTime + duration;
        config.startPrice = startPrice;
        config.endPrice = endPrice;
        config.totalTokens = totalTokens;
        config.minPurchase = minPurchase;
        config.maxPurchase = maxPurchase;
        
        state.tokensSold = 0;
        state.totalRaised = 0;
        state.finalized = false;
        
        emit AuctionStarted(startTime, startTime + duration, startPrice, endPrice);
    }
    
    function getCurrentPrice() public view returns (uint256) {
        if (block.timestamp < config.startTime) return config.startPrice;
        if (block.timestamp >= config.endTime) return config.endPrice;
        
        uint256 elapsed = block.timestamp - config.startTime;
        uint256 duration = config.endTime - config.startTime;
        uint256 priceDiff = config.startPrice - config.endPrice;
        
        return config.startPrice - (priceDiff * elapsed) / duration;
    }
    
    function purchase(uint256 amount) external nonReentrant {
        require(block.timestamp >= config.startTime, "Not started");
        require(block.timestamp < config.endTime, "Ended");
        require(amount >= config.minPurchase, "Below min purchase");
        require(amount <= config.maxPurchase, "Above max purchase");
        require(state.tokensSold + amount <= config.totalTokens, "Exceeds available");
        
        uint256 price = getCurrentPrice();
        uint256 cost = price * amount;
        
        require(paymentToken.transferFrom(msg.sender, address(this), cost), "Payment failed");
        require(sbxToken.transfer(msg.sender, amount), "Transfer failed");
        
        purchases[msg.sender] += amount;
        state.tokensSold += amount;
        state.totalRaised += cost;
        
        emit TokensPurchased(msg.sender, amount, price);
    }
    
    function finalizeAuction() external onlyRole(MANAGER_ROLE) {
        require(block.timestamp >= config.endTime, "Not ended");
        require(!state.finalized, "Already finalized");
        
        state.finalized = true;
        
        // Transfer remaining tokens and funds
        if (state.tokensSold < config.totalTokens) {
            uint256 remaining = config.totalTokens - state.tokensSold;
            require(sbxToken.transfer(msg.sender, remaining), "Transfer failed");
        }
        
        require(
            paymentToken.transfer(msg.sender, state.totalRaised),
            "Payment transfer failed"
        );
        
        emit AuctionFinalized(state.tokensSold, state.totalRaised);
    }
    
    // View functions
    function getAuctionStatus() external view returns (
        uint256 currentPrice,
        uint256 remainingTokens,
        uint256 timeRemaining
    ) {
        currentPrice = getCurrentPrice();
        remainingTokens = config.totalTokens - state.tokensSold;
        timeRemaining = block.timestamp < config.endTime ?
            config.endTime - block.timestamp : 0;
    }
}
