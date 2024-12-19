# SKENAI Deployment Guide

This guide provides step-by-step instructions for deploying the SKENAI agent ecosystem contracts.

## Prerequisites

- Node.js (v14 or later)
- Hardhat
- Access to deployment networks (Ethereum, testnet, etc.)
- Network API keys and configuration
- Etherscan API key for contract verification

## Environment Setup

1. Create a `.env` file in the project root with the following variables:

```env
PRIVATE_KEY=your_deployment_wallet_private_key
INFURA_API_KEY=your_infura_api_key
ETHERSCAN_API_KEY=your_etherscan_api_key
REPORT_GAS=true
```

2. Install dependencies:

```bash
npm install
```

## Deployment Steps

### 1. Core Contract Deployment

Run the core deployment script:

```bash
npx hardhat run scripts/deploy/001_deploy_core.js --network <network_name>
```

This script will:
- Deploy SBX Token
- Deploy Agent Registry
- Deploy Agent Performance
- Deploy Agent Security
- Deploy Agent Rewards
- Deploy Agent Governance
- Deploy Agent Communication
- Save deployment addresses
- Verify contracts on Etherscan (if supported)

### 2. Role Setup

Run the role setup script:

```bash
npx hardhat run scripts/deploy/002_setup_roles.js --network <network_name>
```

This script will:
- Set up all necessary roles
- Grant roles to deployer address
- Configure initial permissions

## Post-Deployment Verification

1. Check contract verification on Etherscan
2. Verify deployment data in `deployments` directory
3. Test basic contract interactions
4. Review role assignments

## Contract Addresses

After deployment, contract addresses will be saved in:
`deployments/<network>_<date>.json`

## Security Considerations

1. Secure private keys and API keys
2. Use multi-sig wallets for production deployments
3. Conduct thorough testing on testnets first
4. Review gas costs and optimize if necessary
5. Implement proper access controls

## Troubleshooting

Common issues and solutions:

1. **Deployment Fails**
   - Check network configuration
   - Verify account balance
   - Review gas settings

2. **Verification Fails**
   - Check Etherscan API key
   - Ensure correct constructor arguments
   - Wait for contract deployment confirmation

3. **Role Setup Fails**
   - Verify deployment addresses
   - Check account permissions
   - Review transaction logs

## Maintenance

1. Regular monitoring of:
   - Contract performance
   - Gas usage
   - Security events
   - Governance proposals

2. Updates and upgrades:
   - Follow governance procedures
   - Test thoroughly
   - Document changes

## Support

For deployment support:
1. Check deployment logs
2. Review contract documentation
3. Contact development team
4. Submit issues on GitHub
