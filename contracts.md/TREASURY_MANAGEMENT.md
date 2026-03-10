# Treasury Management Contract - Documentation

## Overview

The Treasury Management contract is a core component of the Sociale platform. It handles all financial transactions for cooperative entities, including contributions, withdrawals, and loans. This contract ensures transparent fund management with multi-signature approval mechanisms and maintains an immutable record of all financial activities.

## Core Functionality

The Treasury Management contract provides the following key functions:

1. **Contribution Management** - Processing deposits into the treasury
2. **Transaction Proposals** - Creating and managing proposed financial transactions
3. **Multi-signature Approvals** - Enforcing approval requirements for transactions
4. **Transaction Execution** - Processing approved transactions
5. **Transaction Cancellation** - Allowing proposers to cancel pending transactions

## Implementation Details

### Data Structures

The validator uses the following primary data structures:

- **SerializableValue** - Representation of assets held in the treasury
- **TransactionRecord** - Details about a financial transaction (type, amount, member, time, description)
- **PendingTransaction** - A proposed transaction with its approval status
- **TreasuryDatum** - On-chain state containing balance, transaction history, and pending transactions

### Actions

The validator supports five different actions via its redeemer:

1. **Contribute** - Add funds to the treasury
2. **ProposeTransaction** - Create a new transaction that requires approval
3. **ApproveTransaction** - Add approval to a pending transaction
4. **ExecuteTransaction** - Process a transaction that has sufficient approvals
5. **CancelTransaction** - Remove a pending transaction from the queue

### Validation Logic

Each action implements specific validation checks:

#### Contribute
- Works both for initial setup and subsequent contributions
- Verifies the transaction is signed by at least one member
- For initial setup, ensures output datum is correctly initialized with entity reference, empty initial balance, and default approval thresholds
- For subsequent contributions, ensures the transaction record is added to history while preserving existing data
- Enforces that contribution amount matches actual funds transferred

#### ProposeTransaction
- Verifies the transaction is signed by the proposer
- Validates transaction details (positive amount, non-empty description, valid type)
- Ensures output datum is correctly updated with new pending transaction
- Determines required approvals based on transaction type and amount
- Enforces that existing data (entity reference, balance, transaction history) remains unchanged

#### ApproveTransaction
- Verifies the transaction is signed by an active member
- Validates that the transaction index is within range
- Checks that the signer hasn't already approved this transaction
- Ensures the approvals list is updated correctly while preserving other transaction details
- Enforces that all other pending transactions remain unchanged

#### ExecuteTransaction
- Verifies the transaction index is valid
- Ensures the transaction has sufficient approvals
- For withdrawals and loans, validates that funds are correctly transferred out
- For repayments, validates that funds are received into the treasury
- Ensures the transaction is moved from pending list to transaction history
- Verifies that output datum is correctly updated with preserved entity reference

#### CancelTransaction
- Verifies the transaction is signed by the original proposer
- Validates that the transaction index is within range
- Ensures the transaction is removed from pending transactions
- Enforces that other datum fields (entity reference, balance, transaction history, approval thresholds) remain unchanged

## Usage Guidelines

### Initial Setup

To set up a new treasury, follow these steps:

1. Generate a transaction that includes:
   - A redeemer of type `Contribute` with an initial amount and description
   - A properly formatted output with inline datum containing entity reference, empty initial balance, default approval thresholds, and initial transaction record
   - The founder's signature

2. After successful validation, the treasury is initialized on-chain with:
   - A reference to the entity registry
   - A transaction history with the initial contribution
   - An empty pending transactions list
   - Default approval thresholds for different transaction types

### Contribution Operations

To make additional contributions:

1. Create a transaction that includes:
   - A redeemer of type `Contribute` with amount and description
   - An output with updated datum containing the new transaction record in history
   - The contributor's signature

2. The validator ensures:
   - The transaction history is properly updated
   - Other datum fields remain unchanged

### Transaction Proposal and Approval

To propose and approve transactions:

1. For proposals, create a transaction signed by the proposer with:
   - A redeemer of type `ProposeTransaction` with transaction details
   - An output with updated datum containing the new pending transaction

2. For approvals, create a transaction signed by an approver with:
   - A redeemer of type `ApproveTransaction` with the transaction index
   - An output with updated datum containing the added approval

3. The validator ensures:
   - Only valid transactions can be proposed
   - Each member can only approve once
   - The approval count is accurately tracked

### Transaction Execution and Cancellation

To execute or cancel transactions:

1. For execution, create a transaction with:
   - A redeemer of type `ExecuteTransaction` with the transaction index
   - Outputs that fulfill the transaction requirements (e.g., payment to recipient for withdrawals)
   - An output with updated datum showing the transaction moved to history

2. For cancellation, create a transaction signed by the proposer with:
   - A redeemer of type `CancelTransaction` with the transaction index
   - An output with updated datum with the transaction removed from pending list

3. The validator ensures:
   - Only transactions with sufficient approvals can be executed
   - Only proposers can cancel their transactions
   - Funds are transferred according to transaction type

## Best Practices

1. **Transaction Structure**
   - Always include exactly one output with an inline datum for validator state updates
   - For transaction execution, structure outputs to correctly implement the transaction type
   - Ensure the output datum is correctly formatted with all required fields

2. **Approval Thresholds**
   - Set appropriate approval thresholds based on transaction amounts and types
   - Consider higher thresholds for larger withdrawal amounts
   - Review thresholds periodically to adjust for changes in SACCO size

3. **Transaction Descriptions**
   - Include clear, informative descriptions for all transactions
   - For loans, specify purpose, terms, and repayment schedule
   - For withdrawals, document the recipient and purpose

4. **Testing**
   - Thoroughly test all operations before deploying to mainnet
   - Use the provided test suite to verify validator behavior
   - Simulate various approval scenarios to ensure correct execution

## Integration with Other Contracts

The Treasury Management contract is designed to work alongside other Sociale smart contracts:

- **Entity Registry Contract** - Used to verify member identity and authorization
- **Governance Contract** - May trigger treasury transactions based on approved proposals

When integrating with these contracts, use the Entity Registry's hash as a parameter to enable cross-contract validation.

## Limitations and Future Enhancements

Current limitations include:

- Basic transaction types without complex financial products
- Manual transaction execution rather than time-based automation
- Simple approval thresholds based only on transaction type
- Limited integration with external financial services

Future enhancements could include:

- Automated loan repayment schedules
- Interest-bearing treasury accounts
- Time-locked transactions
- Tiered approval requirements based on member roles
- Integration with DeFi protocols for yield generation
- Enhanced reporting and analytics capabilities