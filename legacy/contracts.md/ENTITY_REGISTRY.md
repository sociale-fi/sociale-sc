# Entity Registry Validator - Documentation

## Overview

The Entity Registry validator is a fundamental component of the Sociale platform. It serves as the on-chain identity layer that manages cooperative entities and their members on the Cardano blockchain. This document provides an overview of its implementation, functionality, and usage guidelines.

## Core Functionality

The Entity Registry validator provides the following key functions:

1. **Entity Creation** - Establishing a new SACCO with initial parameters
2. **Member Management** - Adding members and updating their status
3. **Admin Management** - Adding and removing administrative users

## Implementation Details

### Data Structures

The validator uses the following primary data structures:

- **Entity** - Stores metadata about a SACCO (name, description, creation time, founder, member count)
- **Member** - Represents a SACCO member (name, verification key hash, join time, status)
- **RegistryDatum** - On-chain state containing the entity, members list, and admins list

### Actions

The validator supports five different actions via its redeemer:

1. **CreateEntity** - Initialize a new SACCO entity
2. **AddMember** - Add a new member to an existing entity
3. **UpdateMemberStatus** - Change a member's status (Active, Inactive, Suspended)
4. **AddAdmin** - Add a new administrator to the entity
5. **RemoveAdmin** - Remove an existing administrator

### Validation Logic

Each action implements specific validation checks:

#### CreateEntity
- Only allowed during initial setup (when no datum exists)
- Entity name and description must be non-empty
- Transaction must be signed by at least one key (becomes the founder)
- Output datum must be properly formatted with the entity details, founder as admin, and empty members list

#### AddMember
- Transaction must be signed by an existing admin
- Member must not already exist
- Member data must be valid (non-empty name, valid join time)
- Output datum must properly include the new member while preserving existing members
- Entity's member count must be incremented by one

#### UpdateMemberStatus
- Transaction must be signed by an existing admin
- Member must exist
- Output datum must update only the specified member's status while preserving other data
- Member count must remain unchanged

#### AddAdmin
- Transaction must be signed by an existing admin
- New admin must not already exist in the admin list
- Output datum must include the new admin while preserving existing admins

#### RemoveAdmin
- Transaction must be signed by an existing admin
- Admin to remove must exist
- Cannot remove the last admin
- Output datum must remove only the specified admin while preserving other admins

## Usage Guidelines

### Initial Setup

To deploy a new SACCO, follow these steps:

1. Generate a transaction that includes:
   - A redeemer of type `CreateEntity` with SACCO name and description
   - A properly formatted output with inline datum containing entity details
   - The founder's signature

2. After successful validation, the entity is registered on-chain with:
   - The transaction signer as both founder and initial admin
   - Zero initial members
   - A complete entity record with creation timestamp

### Member Operations

To add or update members:

1. Create a transaction signed by an admin with:
   - For adding: A redeemer of type `AddMember` with complete member details
   - For status updates: A redeemer of type `UpdateMemberStatus` with member key and new status
   - A properly formatted output datum with updated member information

2. The validator ensures:
   - Only authorized admins can modify membership
   - No duplicate members are added
   - Status changes only affect the specified member

### Admin Operations

To add or remove admins:

1. Create a transaction signed by an existing admin with:
   - For adding: A redeemer of type `AddAdmin` with the new admin's verification key hash
   - For removing: A redeemer of type `RemoveAdmin` with the admin's verification key hash
   - A properly formatted output datum with updated admin list

2. The validator ensures:
   - Only existing admins can modify the admin list
   - At least one admin always remains to maintain control

## Integration with Other Contracts

The Entity Registry is designed to work alongside other Sociale smart contracts:

- **Treasury Management Contract** - Verifies member identity by consulting the Entity Registry
- **Governance Contract** - Checks admin permissions and member eligibility for voting

When integrating with these contracts, use the Entity Registry's hash as a parameter to enable cross-contract validation.
