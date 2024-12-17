# DOV Strategies for S1 Synthesis Agent

This directory contains the DOV (Decentralized Options Vault) strategies implementation for the S1 synthesis agent. The strategies are built on top of the poly-dov-amm protocol.

## Structure

- `strategies/` - Contains individual DOV strategy implementations
- `utils/` - Utility functions for strategy synthesis and analysis
- `config/` - Configuration files for different strategies
- `tests/` - Strategy-specific tests

## Integration with poly-dov-amm

The DOV strategies reference the poly-dov-amm protocol implementation located at `../../poly-dov-amm/`. Key components used:
- AMM core mechanics
- Options pricing models
- Pool management utilities

## Strategy Synthesis

1. Strategy Development
   - Synthesize new strategies in the `strategies/` directory
   - Leverage poly-dov-amm core components for AMM functionality
   - Implement synthesis-driven optimizations and adaptations

2. Testing
   - Add strategy-specific tests in `tests/`
   - Use shared test utilities from poly-dov-amm when applicable

3. Configuration
   - Store strategy parameters in `config/`
   - Maintain separate configs for different market conditions and synthesis parameters
