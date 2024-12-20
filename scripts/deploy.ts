import { ethers } from 'hardhat';
import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs/promises';
import path from 'path';

const execAsync = promisify(exec);

interface DeploymentConfig {
    network: string;
    validatorCount: number;
    minStake: string;
    proposalThreshold: string;
    messagingEndpoint: string;
}

interface DeploymentState {
    consensusAddress?: string;
    daoAddress?: string;
    messagingAddress?: string;
    validators: string[];
    deploymentTime: number;
}

/**
 * Main deployment script
 */
async function main() {
    console.log('Starting SKENAI deployment...');

    // Load configuration
    const config: DeploymentConfig = await loadConfig();
    let state: DeploymentState = {
        validators: [],
        deploymentTime: Date.now()
    };

    try {
        // Deploy L1 Chain
        console.log('\n1. Deploying L1 Chain...');
        state = await deployL1Chain(config, state);

        // Deploy DAO
        console.log('\n2. Deploying DAO...');
        state = await deployDAO(config, state);

        // Deploy Messaging
        console.log('\n3. Deploying Messaging Platform...');
        state = await deployMessaging(config, state);

        // Setup integrations
        console.log('\n4. Setting up integrations...');
        await setupIntegrations(config, state);

        // Verify deployment
        console.log('\n5. Verifying deployment...');
        await verifyDeployment(config, state);

        // Save deployment state
        await saveDeploymentState(state);

        console.log('\nDeployment completed successfully!');
    } catch (error) {
        console.error('Deployment failed:', error);
        await handleDeploymentFailure(error, state);
        process.exit(1);
    }
}

/**
 * Deploy L1 Chain components
 */
async function deployL1Chain(
    config: DeploymentConfig,
    state: DeploymentState
): Promise<DeploymentState> {
    // Deploy ConsensusEngine
    const ConsensusEngine = await ethers.getContractFactory('ConsensusEngine');
    const consensus = await ConsensusEngine.deploy();
    await consensus.deployed();
    
    state.consensusAddress = consensus.address;
    console.log('ConsensusEngine deployed to:', consensus.address);

    // Setup validators
    for (let i = 0; i < config.validatorCount; i++) {
        const validator = ethers.Wallet.createRandom();
        await consensus.registerValidator({ value: config.minStake });
        state.validators.push(validator.address);
        console.log(`Validator ${i + 1} registered:`, validator.address);
    }

    return state;
}

/**
 * Deploy DAO components
 */
async function deployDAO(
    config: DeploymentConfig,
    state: DeploymentState
): Promise<DeploymentState> {
    // Deploy DAO contracts
    const DAOGovernance = await ethers.getContractFactory('DAOGovernance');
    const dao = await DAOGovernance.deploy(
        state.consensusAddress,
        config.proposalThreshold
    );
    await dao.deployed();
    
    state.daoAddress = dao.address;
    console.log('DAOGovernance deployed to:', dao.address);

    return state;
}

/**
 * Deploy Messaging Platform
 */
async function deployMessaging(
    config: DeploymentConfig,
    state: DeploymentState
): Promise<DeploymentState> {
    // Deploy Messaging contracts
    const MessagingPlatform = await ethers.getContractFactory('MessagingPlatform');
    const messaging = await MessagingPlatform.deploy(
        state.consensusAddress,
        state.daoAddress
    );
    await messaging.deployed();
    
    state.messagingAddress = messaging.address;
    console.log('MessagingPlatform deployed to:', messaging.address);

    // Initialize Farcaster client
    await execAsync('npm run init-farcaster');
    console.log('Farcaster client initialized');

    return state;
}

/**
 * Setup component integrations
 */
async function setupIntegrations(
    config: DeploymentConfig,
    state: DeploymentState
): Promise<void> {
    // Setup DAO-Chain bridge
    const dao = await ethers.getContractAt('DAOGovernance', state.daoAddress!);
    await dao.setupChainBridge(state.consensusAddress!);
    console.log('DAO-Chain bridge configured');

    // Setup Messaging-Chain bridge
    const messaging = await ethers.getContractAt(
        'MessagingPlatform',
        state.messagingAddress!
    );
    await messaging.setupChainBridge(state.consensusAddress!);
    console.log('Messaging-Chain bridge configured');

    // Setup Messaging-DAO bridge
    await messaging.setupDAOBridge(state.daoAddress!);
    console.log('Messaging-DAO bridge configured');
}

/**
 * Verify deployment
 */
async function verifyDeployment(
    config: DeploymentConfig,
    state: DeploymentState
): Promise<void> {
    // Verify contracts
    await verifyContract(state.consensusAddress!, 'ConsensusEngine');
    await verifyContract(state.daoAddress!, 'DAOGovernance');
    await verifyContract(state.messagingAddress!, 'MessagingPlatform');

    // Test integrations
    await testIntegrations(state);

    // Verify validator set
    const consensus = await ethers.getContractAt(
        'ConsensusEngine',
        state.consensusAddress!
    );
    const validators = await consensus.getValidatorSet();
    console.log('Validator set verified:', validators.length === config.validatorCount);
}

/**
 * Load deployment configuration
 */
async function loadConfig(): Promise<DeploymentConfig> {
    const configPath = path.join(__dirname, '../config/deployment.json');
    const configData = await fs.readFile(configPath, 'utf8');
    return JSON.parse(configData);
}

/**
 * Save deployment state
 */
async function saveDeploymentState(state: DeploymentState): Promise<void> {
    const statePath = path.join(__dirname, '../deployment/state.json');
    await fs.writeFile(statePath, JSON.stringify(state, null, 2));
    console.log('Deployment state saved to:', statePath);
}

/**
 * Handle deployment failure
 */
async function handleDeploymentFailure(
    error: any,
    state: DeploymentState
): Promise<void> {
    // Save error state
    const errorPath = path.join(__dirname, '../deployment/error.json');
    await fs.writeFile(
        errorPath,
        JSON.stringify({ error: error.message, state }, null, 2)
    );
    
    // Attempt cleanup
    if (state.consensusAddress) {
        console.log('Attempting to cleanup deployed contracts...');
        // Implement cleanup logic
    }
}

/**
 * Verify contract on block explorer
 */
async function verifyContract(
    address: string,
    contractName: string
): Promise<void> {
    try {
        await execAsync(
            `npx hardhat verify --network ${network.name} ${address}`
        );
        console.log(`${contractName} verified on block explorer`);
    } catch (error) {
        console.warn(`Warning: Failed to verify ${contractName}:`, error);
    }
}

/**
 * Test component integrations
 */
async function testIntegrations(state: DeploymentState): Promise<void> {
    // Test DAO-Chain integration
    const dao = await ethers.getContractAt('DAOGovernance', state.daoAddress!);
    const chainConnection = await dao.isChainConnected();
    console.log('DAO-Chain integration:', chainConnection ? 'OK' : 'Failed');

    // Test Messaging-Chain integration
    const messaging = await ethers.getContractAt(
        'MessagingPlatform',
        state.messagingAddress!
    );
    const messagingConnection = await messaging.isChainConnected();
    console.log('Messaging-Chain integration:', messagingConnection ? 'OK' : 'Failed');
}

// Run deployment
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
