// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../contracts/strategies/DOVStrategyManager.sol";
import "../../contracts/strategies/PerpetualOptionsManager.sol";
import "../../contracts/strategies/advanced/AdvancedDOVStrategies.sol";
import "../../contracts/strategies/advanced/AdvancedPerpStrategies.sol";

contract StrategyTest is Test {
    DOVStrategyManager public dovManager;
    PerpetualOptionsManager public perpManager;
    AdvancedDOVStrategies public advancedDOV;
    AdvancedPerpStrategies public advancedPerp;
    
    // Test accounts
    address public admin = address(1);
    address public operator = address(2);
    address public user = address(3);
    
    // Test strategy IDs
    bytes32 public constant DOV_STRATEGY = keccak256("TEST_DOV_STRATEGY");
    bytes32 public constant PERP_STRATEGY = keccak256("TEST_PERP_STRATEGY");
    bytes32 public constant ADV_DOV_STRATEGY = keccak256("TEST_ADV_DOV_STRATEGY");
    bytes32 public constant ADV_PERP_STRATEGY = keccak256("TEST_ADV_PERP_STRATEGY");
    
    function setUp() public {
        // Deploy contracts
        vm.startPrank(admin);
        
        // Deploy managers
        dovManager = new DOVStrategyManager(address(0)); // Mock AI agent
        perpManager = new PerpetualOptionsManager(address(0)); // Mock AI agent
        advancedDOV = new AdvancedDOVStrategies(address(0)); // Mock AI agent
        advancedPerp = new AdvancedPerpStrategies(address(0)); // Mock AI agent
        
        // Setup roles
        bytes32 strategyManager = keccak256("STRATEGY_MANAGER");
        dovManager.grantRole(strategyManager, operator);
        perpManager.grantRole(strategyManager, operator);
        advancedDOV.grantRole(strategyManager, operator);
        advancedPerp.grantRole(strategyManager, operator);
        
        vm.stopPrank();
    }
    
    function testDOVStrategyCreation() public {
        vm.startPrank(operator);
        
        // Create DOV strategy
        DOVStrategyManager.VaultStrategy memory params = DOVStrategyManager.VaultStrategy({
            targetUtilization: 8000,    // 80%
            maxLeverage: 2000,          // 2x
            fundingRate: 10,            // 0.1%
            volatilityThreshold: 2000,  // 20%
            isActive: true
        });
        
        dovManager.createStrategy(DOV_STRATEGY, DOVStrategyManager.StrategyType.COVERED_CALL, params);
        
        // Verify strategy
        assertTrue(dovManager.vaultStrategies(DOV_STRATEGY).isActive);
        assertEq(dovManager.vaultStrategies(DOV_STRATEGY).targetUtilization, 8000);
        
        vm.stopPrank();
    }
    
    function testPerpStrategyCreation() public {
        vm.startPrank(operator);
        
        // Create perpetual strategy
        PerpetualOptionsManager.PerpStrategy memory params = PerpetualOptionsManager.PerpStrategy({
            targetLeverage: 2000,      // 2x
            fundingRate: 10,           // 0.1%
            maintenanceMargin: 1000,   // 10%
            liquidationThreshold: 500,  // 5%
            isActive: true
        });
        
        perpManager.createStrategy(PERP_STRATEGY, PerpetualOptionsManager.PerpType.DELTA_NEUTRAL, params);
        
        // Verify strategy
        assertTrue(perpManager.perpStrategies(PERP_STRATEGY).isActive);
        assertEq(perpManager.perpStrategies(PERP_STRATEGY).targetLeverage, 2000);
        
        vm.stopPrank();
    }
    
    function testAdvancedDOVStrategyCreation() public {
        vm.startPrank(operator);
        
        // Create advanced DOV strategy
        advancedDOV.createAdvancedStrategy(
            ADV_DOV_STRATEGY,
            AdvancedDOVStrategies.AdvancedStrategyType.BUTTERFLY
        );
        
        // Verify strategy
        assertTrue(advancedDOV.vaultStrategies(ADV_DOV_STRATEGY).isActive);
        
        vm.stopPrank();
    }
    
    function testAdvancedPerpStrategyCreation() public {
        vm.startPrank(operator);
        
        // Create advanced perpetual strategy
        advancedPerp.createAdvancedStrategy(
            ADV_PERP_STRATEGY,
            AdvancedPerpStrategies.AdvancedPerpType.GRID_TRADING
        );
        
        // Verify strategy
        assertTrue(advancedPerp.perpStrategies(ADV_PERP_STRATEGY).isActive);
        
        vm.stopPrank();
    }
    
    function testStrategyExecution() public {
        vm.startPrank(operator);
        
        // Setup strategies
        testDOVStrategyCreation();
        testPerpStrategyCreation();
        
        // Execute DOV strategy
        dovManager.updateStrategy(DOV_STRATEGY);
        dovManager.rebalancePositions(DOV_STRATEGY);
        
        // Execute perpetual strategy
        perpManager.updatePosition(PERP_STRATEGY);
        perpManager.processFunding(PERP_STRATEGY);
        
        vm.stopPrank();
    }
    
    function testAdvancedStrategyExecution() public {
        vm.startPrank(operator);
        
        // Setup strategies
        testAdvancedDOVStrategyCreation();
        testAdvancedPerpStrategyCreation();
        
        // Execute advanced DOV strategy
        advancedDOV.updateGreeks(ADV_DOV_STRATEGY);
        advancedDOV.scoreEfficiency(ADV_DOV_STRATEGY);
        
        // Execute advanced perpetual strategy
        advancedPerp.updateMetrics(ADV_PERP_STRATEGY);
        advancedPerp.scorePerformance(ADV_PERP_STRATEGY);
        
        vm.stopPrank();
    }
    
    function testRiskManagement() public {
        vm.startPrank(operator);
        
        // Setup strategies
        testPerpStrategyCreation();
        
        // Update margin requirements
        perpManager.updateMargin(PERP_STRATEGY);
        
        // Verify margin
        uint256 margin = perpManager.positionMetrics(PERP_STRATEGY).margin;
        assertTrue(margin > 0);
        
        vm.stopPrank();
    }
    
    function testStrategyMetrics() public {
        vm.startPrank(operator);
        
        // Setup strategies
        testAdvancedDOVStrategyCreation();
        testAdvancedPerpStrategyCreation();
        
        // Get DOV metrics
        uint256 greeks = advancedDOV.advancedMetrics(ADV_DOV_STRATEGY).greeks;
        uint256 efficiency = advancedDOV.advancedMetrics(ADV_DOV_STRATEGY).efficiency;
        
        // Get perpetual metrics
        uint256 profitFactor = advancedPerp.advancedMetrics(ADV_PERP_STRATEGY).profitFactor;
        uint256 sharpeRatio = advancedPerp.advancedMetrics(ADV_PERP_STRATEGY).sharpeRatio;
        
        vm.stopPrank();
    }
}
