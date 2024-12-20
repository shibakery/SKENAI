// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title BoronOracle
 * @dev Oracle system for Boron market data
 */
contract BoronOracle is AccessControl, ChainlinkClient {
    using Chainlink for Chainlink.Request;
    
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    
    // Market data sources
    struct DataSource {
        string endpoint;
        bytes32 jobId;
        uint256 fee;
        bool active;
    }
    
    // Validator data
    struct Validator {
        uint256 stake;
        uint256 accuracy;
        uint256 reportCount;
        uint256 lastReport;
    }
    
    // Market data
    struct MarketData {
        uint256 supply;
        uint256 demand;
        uint256 price;
        uint256 timestamp;
        address reporter;
    }
    
    mapping(address => Validator) public validators;
    mapping(string => DataSource) public dataSources;
    MarketData[] public historicalData;
    
    uint256 public constant MIN_VALIDATOR_STAKE = 1000 ether;
    uint256 public constant REPORT_COOLDOWN = 1 hours;
    uint256 public constant DATA_EXPIRY = 24 hours;
    
    address public boronStable;
    
    // Events
    event MarketDataUpdated(uint256 supply, uint256 demand, uint256 price);
    event ValidatorRegistered(address indexed validator, uint256 stake);
    event DataSourceAdded(string indexed name, string endpoint);
    
    constructor(address _link) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        setChainlinkToken(_link);
    }
    
    /**
     * @dev Set BoronStable contract address
     */
    function setBoronStable(
        address _boronStable
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_boronStable != address(0), "Invalid address");
        boronStable = _boronStable;
    }
    
    /**
     * @dev Register as a validator
     */
    function registerValidator() external payable {
        require(msg.value >= MIN_VALIDATOR_STAKE, "Insufficient stake");
        require(!hasRole(VALIDATOR_ROLE, msg.sender), "Already registered");
        
        validators[msg.sender] = Validator({
            stake: msg.value,
            accuracy: 100,
            reportCount: 0,
            lastReport: 0
        });
        
        _setupRole(VALIDATOR_ROLE, msg.sender);
        emit ValidatorRegistered(msg.sender, msg.value);
    }
    
    /**
     * @dev Add data source
     */
    function addDataSource(
        string memory name,
        string memory endpoint,
        bytes32 jobId,
        uint256 fee
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        dataSources[name] = DataSource({
            endpoint: endpoint,
            jobId: jobId,
            fee: fee,
            active: true
        });
        
        emit DataSourceAdded(name, endpoint);
    }
    
    /**
     * @dev Request market data from Chainlink
     */
    function requestMarketData(
        string memory source
    ) external onlyRole(VALIDATOR_ROLE) {
        require(dataSources[source].active, "Invalid source");
        require(
            block.timestamp >= validators[msg.sender].lastReport + REPORT_COOLDOWN,
            "Cooldown active"
        );
        
        Chainlink.Request memory request = buildChainlinkRequest(
            dataSources[source].jobId,
            address(this),
            this.fulfillMarketData.selector
        );
        
        request.add("get", dataSources[source].endpoint);
        request.add("path", "boron.marketData");
        
        sendChainlinkRequestTo(
            chainlinkOracleAddress(),
            request,
            dataSources[source].fee
        );
    }
    
    /**
     * @dev Callback function for Chainlink
     */
    function fulfillMarketData(
        bytes32 _requestId,
        uint256 supply,
        uint256 demand,
        uint256 price
    ) external recordChainlinkFulfillment(_requestId) {
        require(supply > 0 && demand > 0 && price > 0, "Invalid data");
        
        MarketData memory newData = MarketData({
            supply: supply,
            demand: demand,
            price: price,
            timestamp: block.timestamp,
            reporter: tx.origin
        });
        
        historicalData.push(newData);
        
        // Update validator metrics
        Validator storage validator = validators[tx.origin];
        validator.reportCount++;
        validator.lastReport = block.timestamp;
        
        // Update BoronStable contract
        IBoronStable(boronStable).updateBoronData(supply, 0, demand);
        
        emit MarketDataUpdated(supply, demand, price);
    }
    
    /**
     * @dev Get latest market data
     */
    function getLatestMarketData() external view returns (
        uint256 supply,
        uint256 demand,
        uint256 price,
        uint256 timestamp
    ) {
        require(historicalData.length > 0, "No data available");
        MarketData memory latest = historicalData[historicalData.length - 1];
        return (
            latest.supply,
            latest.demand,
            latest.price,
            latest.timestamp
        );
    }
    
    /**
     * @dev Get validator info
     */
    function getValidator(
        address validator
    ) external view returns (
        uint256 stake,
        uint256 accuracy,
        uint256 reportCount
    ) {
        Validator memory v = validators[validator];
        return (v.stake, v.accuracy, v.reportCount);
    }
}

interface IBoronStable {
    function updateBoronData(
        uint256 supply,
        uint256 sites,
        uint256 demand
    ) external;
}
