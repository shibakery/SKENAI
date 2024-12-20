# SKENAI Deployment Scripts

## Overview
This directory contains deployment scripts and configurations for SKENAI's strategy system. The scripts handle contract deployment, role setup, and initial configuration.

## Directory Structure

```
deploy/
├── DeployStrategies.sol    # Main deployment script
├── config/                 # Configuration files
│   └── strategy_config.json # Strategy configuration
└── README.md              # This file
```

## Configuration

### Environment Variables
Required environment variables:
```bash
export PRIVATE_KEY=your_private_key
export RPC_URL=your_rpc_url
```

### Network Configuration
Edit `config/strategy_config.json` to set:
- Network addresses
- Role assignments
- Default parameters
- System limits
- Gas settings

## Deployment

### Prerequisites
1. Install dependencies:
```bash
forge install
```

2. Set up environment:
```bash
source .env
```

### Deploy Contracts
```bash
forge script scripts/deploy/DeployStrategies.sol --rpc-url $RPC_URL --broadcast
```

### Verify Contracts
```bash
forge verify-contract [address] [contract] --chain [chain-id]
```

## Post-Deployment

### Role Setup
1. Grant strategy manager role
2. Set up admin accounts
3. Configure operator permissions

### Strategy Initialization
1. Set default parameters
2. Initialize AI agent connection
3. Configure risk limits

## Maintenance

### Contract Upgrades
1. Deploy new implementation
2. Update proxy
3. Verify new implementation

### Configuration Updates
1. Update strategy_config.json
2. Run update script
3. Verify changes

## Troubleshooting

### Common Issues
1. Deployment Failures
   - Check gas settings
   - Verify network connection
   - Confirm account balance

2. Role Assignment Issues
   - Check admin permissions
   - Verify role hierarchy
   - Confirm transaction success

3. Configuration Problems
   - Validate JSON format
   - Check parameter bounds
   - Verify network settings

## Support
For deployment support:
1. Check documentation
2. Open GitHub issue
3. Contact development team

## License
MIT License
