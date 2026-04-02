# Treasury Management Contract - Documentation

## Overview

The Treasury Management contract handles all financial transactions for cooperative entities, including contributions, withdrawals, and loans. This contract ensures transparent fund management with multi-signature approval mechanisms and an immutable record of all financial activities.

## Core Functionality

1. **Contribution Management** - Processing deposits into the treasury
2. **Transaction Proposals** - Creating and managing proposed financial transactions
3. **Multi-signature Approvals** - Enforcing approval requirements for transactions
4. **Transaction Execution** - Processing approved transactions
5. **Transaction Cancellation** - Allowing proposers to cancel pending transactions

## Implementation Details

### Data Structures

- **TransactionRecord** - type, amount, member, time, description
- **PendingTransaction** - proposed transaction with approval status and approvals list
- **TreasuryDatum** - entity_utxo_ref, balance, transaction_history, pending_transactions, approval_thresholds

### Actions

1. **Contribute** - Add funds to the treasury
2. **ProposeTransaction** - Create a transaction requiring approval
3. **ApproveTransaction** - Add approval to a pending transaction
4. **ExecuteTransaction** - Process a transaction with sufficient approvals
5. **CancelTransaction** - Remove a pending transaction

## Integration with Other Contracts

- **Entity Registry Contract** - Verifies member identity and authorization
- **Governance Contract** - May trigger treasury transactions based on approved proposals

The Entity Registry hash is passed as a constructor parameter to enable cross-contract validation.
