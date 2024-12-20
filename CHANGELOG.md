# Changelog

All notable changes to the SKENAI project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2024-12-20

### Breaking Changes
- **Governance Structure**: Expanded base layer from 36 to 42 proposals
  - Impact: Existing proposal indices and voting mechanisms will need to be updated
  - Migration: Existing proposals will need to be remapped to new structure

### Changed
- **Architecture**: Updated base layer proposal matrix structure
  - Expanded from 36 to 42 total proposals (6 tracks × 7 levels)
  - Introduced physics-based gravitational naming scheme for performance levels:
    - Entry → Quantum (fundamental proposals)
    - Bronze → Orbital (basic gravitational pull)
    - Silver → Stellar (significant influence)
    - Gold → Pulsar (periodic impact)
    - Platinum → Neutron (dense, high impact)
    - Diamond → Quasar (massive reach)
    - Legend → Singularity (maximum influence)
  - Updated all performance metrics and thresholds to align with new level names
  - Enhanced documentation clarity around the 42-proposal structure

### Added
- Detailed descriptions for each performance level's gravitational significance
- Complete performance thresholds for all tracks across all levels
- Explicit documentation of the base layer matrix structure

### Technical Details
- Matrix Dimensions: 6 tracks × 7 levels = 42 total proposal slots
- Tracks: Genesis, Fractal, Options, Research, Community, Encyclic
- Performance Levels: Quantum, Orbital, Stellar, Pulsar, Neutron, Quasar, Singularity

[1.0.0]: https://github.com/shibakenfinance/SKENAI/releases/tag/v1.0.0
