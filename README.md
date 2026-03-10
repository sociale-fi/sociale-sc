# Sociale Smart Contracts

Cardano smart contracts powering transparent governance and decentralized financial operations for savings cooperatives (SACCOs, stokvels, and chamas) on the Sociale platform.

## Overview

These contracts address the core trust and accountability challenges facing savings cooperatives:

- **Funds Mismanagement** - Through transparent, on-chain financial transactions
- **Poor Governance** - With decentralised, tamper-proof decision-making
- **Limited Access** - Eliminating geographical constraints for diaspora and cross-border members

## Smart Contract Architecture

Three interconnected validators form the foundation of the on-chain layer:

```
┌──────────────────┐    ┌───────────────────┐    ┌──────────────────┐
│  Entity Registry │    │     Treasury      │    │    Governance    │
│    Contract      │◄───┤    Management     │◄───┤     Contract     │
│                  │    │     Contract      │    │                  │
└────────┬─────────┘    └─────────┬─────────┘    └────────┬─────────┘
         │                        │                       │
         ▼                        ▼                       ▼
┌────────────────────────────────────────────────────────────────────┐
│                           Cardano Blockchain                        │
└────────────────────────────────────────────────────────────────────┘
```

- **Entity Registry**: Manages cooperative entities and their members
- **Treasury Management**: Handles financial operations with multi-signature approval
- **Governance**: Facilitates decision-making through proposals and voting

## Documentation

Detailed documentation is available in the `/contracts.md` directory:

- [Entity Registry](./contracts.md/ENTITY_REGISTRY.md)
- [Treasury Management](./contracts.md/TREASURY_MANAGEMENT.md)
- [Governance](./contracts.md/GOVERNANCE.md)

## Getting Started

### Requirements

- Aiken v1.1.15 or higher
- Cardano development environment

### Build and Test

```bash
# Build the contracts
aiken build

# Run the test suite
aiken check
```

## Key Features

### Entity Registry
- Cooperative entity creation and management
- Member registration with status tracking
- Admin management with multi-admin support

### Treasury Management
- Transparent fund management
- Multi-signature transaction approval
- Comprehensive transaction history

### Governance
- Proposal creation and management
- Transparent voting system
- Automatic execution of approved decisions

## Project Structure

```
sociale-sc/
├── aiken.toml               # Project configuration
├── lib/                     # Shared library code
│   ├── entity_registry/     # Entity Registry types
│   ├── governance/          # Governance types
│   └── treasury_management/ # Treasury Management types
├── validators/              # Smart contracts
│   ├── entity_registry/     # Entity Registry contract
│   ├── governance/          # Governance contract
│   └── treasury_management/ # Treasury Management contract
└── contracts.md/            # Detailed documentation
```

## License

Apache License 2.0
