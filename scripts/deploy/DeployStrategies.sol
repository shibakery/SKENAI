// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../../contracts/strategies/DOVStrategyManager.sol";
import "../../contracts/strategies/PerpetualOptionsManager.sol";
import "../../contracts/strategies/advanced/AdvancedDOVStrategies.sol";
import "../../contracts/strategies/advanced/AdvancedPerpStrategies.sol";

contract DeployStrategies is Script {
    function run() external {
        // Get deployment private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy AI agent first (mock for now)
        address aiAgent = address(0x123); // Replace with actual AI agent deployment
        
        // Deploy base managers
        DOVStrategyManager dovManager = new DOVStrategyManager(aiAgent);
        PerpetualOptionsManager perpManager = new PerpetualOptionsManager(aiAgent);
        
        // Deploy advanced strategies
        AdvancedDOVStrategies advancedDOV = new AdvancedDOVStrategies(aiAgent);
        AdvancedPerpStrategies advancedPerp = new AdvancedPerpStrategies(aiAgent);
        
        // Setup roles
        bytes32 strategyManager = keccak256("STRATEGY_MANAGER");
        dovManager.grantRole(strategyManager, msg.sender);
        perpManager.grantRole(strategyManager, msg.sender);
        advancedDOV.grantRole(strategyManager, msg.sender);
        advancedPerp.grantRole(strategyManager, msg.sender);
        
        // Log deployments
        console.log("DOV Manager deployed at:", address(dovManager));
        console.log("Perpetual Manager deployed at:", address(perpManager));
        console.log("Advanced DOV deployed at:", address(advancedDOV));
        console.log("Advanced Perpetual deployed at:", address(advancedPerp));
        
        vm.stopBroadcast();
    }
}
