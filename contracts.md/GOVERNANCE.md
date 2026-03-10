# Governance Contract - Documentation

## Overview

The Governance contract is a fundamental component of the Sociale platform. It manages the decision-making process for cooperative entities, enabling members to create proposals, vote on them, and automatically execute approved decisions. The contract ensures transparent and fair governance with immutable record-keeping of all voting activities.

## Core Functionality

The Governance contract provides the following key functions:

1. **Proposal Management** - Creating and tracking proposals for community decisions
2. **Voting System** - Processing member votes with transparent tallying
3. **Proposal Execution** - Implementing approved decisions automatically
4. **Proposal Cancellation** - Allowing proposers to withdraw active proposals
5. **Governance Parameters** - Managing configurable decision-making rules

## Implementation Details

### Data Structures

The validator uses the following primary data structures:

- **Proposal** - A record containing:
  - `title`: The proposal name (ByteArray)
  - `description`: Detailed explanation of the proposal (ByteArray)
  - `category`: Type of proposal (TreasuryAction, ParameterChange, MembershipChange, Other)
  - `proposer`: The verification key hash of the member who created the proposal
  - `creation_time`: Timestamp when the proposal was created (milliseconds)
  - `voting_deadline`: Timestamp when voting ends (milliseconds)
  - `status`: Current state of the proposal (Active, Approved, Rejected, Executed, Cancelled)
  - `execution_data`: Specific action to execute if approved (Data)
  - `votes`: List of (member hash, vote) pairs recording all votes
  - `for_votes`, `against_votes`, `abstain_votes`: Vote tallies for easy calculation

- **GovernanceParams** - Configuration parameters including:
  - `approval_threshold`: Percentage of votes needed to approve a proposal (0-100)
  - `minimum_voting_period`: Minimum time in milliseconds a proposal must be open for voting
  - `quorum_percentage`: Minimum participation percentage required for valid decisions (0-100)

- **GovernanceDatum** - On-chain state containing:
  - `entity_utxo_ref`: Reference to the Entity Registry UTxO
  - `treasury_utxo_ref`: Reference to the Treasury Management UTxO
  - `params`: Governance parameters
  - `proposals`: List of all proposals
  - `next_proposal_id`: Counter for creating sequential proposal IDs

### Actions

The validator supports five different actions via its redeemer:

1. **CreateProposal** - Submit a new proposal for consideration with:
   - Title, description, and category
   - Voting deadline
   - Execution data specific to the proposal type

2. **CastVote** - Record a member's vote on a proposal with:
   - Proposal ID
   - Vote (For, Against, or Abstain)

3. **ExecuteProposal** - Implement a proposal that meets approval criteria with:
   - Proposal ID

4. **CancelProposal** - Remove an active proposal from consideration with:
   - Proposal ID

5. **UpdateParams** - Modify the governance parameters with:
   - New parameters (approval threshold, minimum voting period, quorum percentage)

### Validation Logic

Each action implements specific validation checks:

#### CreateProposal
- Verifies the proposal has non-empty title and description
- Ensures the transaction is signed by at least one key (the proposer)
- Validates that the voting deadline is sufficiently in the future (beyond minimum voting period)
- Checks that output datum is correctly updated with:
  - Entity and treasury references unchanged
  - Governance parameters unchanged
  - Proposals list grown by exactly one
  - Next proposal ID incremented
  - All previous proposals preserved
  - New proposal correctly formatted with active status and empty vote tallies

- For initial setup (when no datum exists):
  - Initializes governance parameters with sensible defaults
  - Sets up entity and treasury references
  - Creates the first proposal
  - Sets next_proposal_id to 1

#### CastVote
- Verifies the transaction is signed by at least one key (the voter)
- Validates that the proposal ID is within range of existing proposals
- Checks that the proposal is active and voting deadline hasn't passed
- Ensures the voter hasn't already voted on this proposal
- Verifies the output datum is correctly updated with:
  - Entity and treasury references unchanged
  - Governance parameters unchanged
  - Proposal count unchanged
  - Next proposal ID unchanged
  - Only the target proposal modified
  - Vote correctly added to the proposal's votes list
  - Vote tallies properly incremented based on vote type

#### ExecuteProposal
- Verifies the proposal ID is valid
- Checks if the proposal is already approved, or if it's active but meets approval criteria:
  - Calculates if quorum is met (total votes * 100 ≥ quorum_percentage)
  - Calculates if approval threshold is met (for_votes * 100 / total_votes ≥ approval_threshold)
- Validates the output datum is correctly updated with:
  - Entity and treasury references unchanged
  - Governance parameters unchanged
  - Proposal count unchanged
  - Next proposal ID unchanged
  - Only the target proposal modified
  - Proposal status updated to Executed
  - Other proposal fields unchanged
- Verifies the transaction is properly structured based on proposal category:
  - For TreasuryAction, checks interaction with treasury contract
  - For ParameterChange, ensures proper implementation
  - For MembershipChange, validates entity registry interaction
  - For Other, performs basic validation

#### CancelProposal
- Verifies the proposal ID is valid
- Ensures the proposal is active (cannot cancel executed or already cancelled proposals)
- Checks that the transaction is signed by the proposer
- Validates the output datum is correctly updated with:
  - Entity and treasury references unchanged
  - Governance parameters unchanged
  - Proposal count unchanged
  - Next proposal ID unchanged
  - Only the target proposal modified
  - Proposal status updated to Cancelled
  - Other proposal fields unchanged

#### UpdateParams
- Verifies the transaction is signed by at least one admin
- Validates the new parameters:
  - Approval threshold > 50% and ≤ 100%
  - Minimum voting period > 0
  - Quorum percentage > 0% and ≤ 100%
- Ensures the output datum is correctly updated with:
  - Entity and treasury references unchanged
  - Governance parameters updated to new values
  - Proposals list unchanged
  - Next proposal ID unchanged

## Usage Guidelines

### Initial Setup

To set up a new governance system, follow these steps:

1. Generate a transaction that includes:
   - A redeemer of type `CreateProposal` with the first proposal details
   - A properly formatted output with inline datum containing entity and treasury references, default governance parameters, and the initial proposal
   - The founder's signature

2. After successful validation, the governance system is initialized on-chain with:
   - References to the entity registry and treasury
   - Default governance parameters
   - The first proposal with Active status
   - Next proposal ID set to 1

### Proposal Creation and Voting

To create proposals and vote on them:

1. For creating proposals:
   - Generate a transaction with a `CreateProposal` redeemer containing proposal details
   - Ensure the voting deadline is sufficiently in the future
   - Include an output with properly updated datum

2. For voting on proposals:
   - Generate a transaction with a `CastVote` redeemer containing proposal ID and vote
   - Ensure the transaction is signed by the voter
   - Include an output with properly updated datum showing the new vote and updated tallies

3. The validator ensures:
   - Votes are only accepted for active proposals before their deadline
   - Each member can only vote once per proposal
   - Vote tallies are accurately maintained

### Proposal Execution and Cancellation

To execute or cancel proposals:

1. For execution:
   - Generate a transaction with an `ExecuteProposal` redeemer containing the proposal ID
   - For treasury actions, include appropriate inputs/outputs to interact with the treasury contract
   - Include an output with updated datum showing the proposal status as Executed

2. For cancellation:
   - Generate a transaction signed by the proposer with a `CancelProposal` redeemer
   - Include an output with updated datum showing the proposal status as Cancelled

3. The validator ensures:
   - Only proposals that meet approval criteria can be executed
   - Only proposers can cancel their active proposals
   - Proposal execution follows the appropriate pattern for its category

### Governance Parameter Updates

To update governance parameters:

1. Generate a transaction signed by an admin with:
   - An `UpdateParams` redeemer containing the new parameter values
   - An output with updated datum reflecting the new parameters

2. The validator ensures:
   - The transaction is properly signed by an admin
   - The new parameters are within valid ranges
   - Other datum fields remain unchanged

## Best Practices

1. **Proposal Design**
   - Craft clear, specific proposals with detailed descriptions
   - Set appropriate voting deadlines based on proposal complexity
   - Choose the correct proposal category to ensure proper execution
   - Include all necessary execution data in the proposal

2. **Voting Participation**
   - Encourage high participation to meet quorum requirements
   - Communicate voting deadlines clearly to members
   - Allow sufficient time for members to consider proposals

3. **Parameter Configuration**
   - Set approval thresholds based on proposal importance
   - Balance quorum requirements to ensure legitimate decisions without paralysis
   - Adjust minimum voting periods to give members adequate time to participate

4. **Transaction Structure**
   - Always include exactly one output with an inline datum for validator state updates
   - Ensure the output datum is correctly formatted with all required fields
   - For proposal execution, structure transaction to implement the proposal correctly

## Integration with Other Contracts

The Governance contract is designed to work alongside other Sociale smart contracts:

- **Entity Registry Contract** - Used to verify member identity and admin status
- **Treasury Management Contract** - Target of treasury action proposals

When integrating with these contracts, references to their UTxOs are maintained in the governance datum, enabling cross-contract validation and interaction.

## Limitations and Future Enhancements

Current limitations include:

- Simple voting mechanism without delegation
- Basic majority voting without weighted votes
- Limited proposal categories
- Manual proposal execution rather than automatic time-based execution

Future enhancements could include:

- Delegation of voting power
- Weighted voting based on member contributions or stake
- Specialized governance for different decision types
- Automatic proposal execution when approved
- More detailed voting analytics and history
- Tiered approval requirements based on proposal impact
- Integration with external governance systems