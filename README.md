# Sociale Smart Contracts

Cardano smart contracts for transparent governance and financial operations in savings cooperatives — SACCOs, stokvels, chamas, and similar member-owned financial groups.

Built with [Aiken](https://aiken-lang.org) targeting Plutus v3.

---

## What this does

Savings cooperatives face a recurring set of trust problems: funds can be mismanaged, governance decisions can be made without accountability, and members — especially diaspora — have limited visibility into the group's operations.

These contracts address that directly. Every material action a cooperative takes — admitting a member, approving a withdrawal, passing a governance vote, committing a batch of transactions — is recorded on Cardano with cryptographic guarantees. No central authority can silently alter the record.

## Contracts

| Contract | Description |
|----------|-------------|
| [Audit Anchor](./docs/AUDIT_ANCHOR.md) | Merkle root commitments forming a tamper-evident transaction history |
| [Entity Registry](./docs/contracts/ENTITY_REGISTRY.md) | Cooperative identity, member roster, and admin keys |
| [Governance](./docs/contracts/GOVERNANCE.md) | Proposals, voting, quorum, and parameter management |
| [Treasury Management](./docs/contracts/TREASURY_MANAGEMENT.md) | Multi-signature fund management |

Each cooperative is represented by a set of independent UTxOs — one per contract. Multiple cooperatives coexist at the same script addresses.

## Identity

Members can link a [KERI](https://keri.one) Autonomic Identifier (AID) to their on-chain record. KERI provides self-sovereign identity that is not bound to any single blockchain. With the Cardano Foundation's [`cardano-backer`](https://github.com/cardano-foundation/cardano-backer) tool, KERI Key Event Logs can be anchored directly on Cardano, making the identity chain independently verifiable on-ledger.

See [KERI_INTEGRATION.md](./docs/KERI_INTEGRATION.md) for details.

## Getting started

Requires Aiken v1.1.15 or higher.

```bash
# Type-check and run all tests
aiken check

# Compile and generate plutus.json
aiken build
```

## Project layout

```
sociale-sc/
├── docs/
│   ├── ARCHITECTURE.md          # System design and UTxO model
│   ├── AUDIT_ANCHOR.md          # Verifiable audit trail specification
│   ├── KERI_INTEGRATION.md      # KERI identity and cardano-backer
│   ├── ROADMAP.md               # Current state and direction
│   └── contracts/               # Per-contract reference documentation
├── lib/                         # Shared types and utilities
│   ├── audit_anchor/
│   ├── entity_registry/
│   ├── governance/
│   ├── member_nft/
│   └── treasury_management/
├── validators/                  # Contract implementations and tests
│   ├── audit_anchor/
│   ├── entity_registry/
│   ├── governance/
│   ├── member_nft/
│   └── treasury_management/
└── legacy/                      # Archived competition submission (reference only)
```

## License

Apache License 2.0
