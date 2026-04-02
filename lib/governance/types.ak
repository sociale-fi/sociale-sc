// lib/governance/types.ak

use aiken/crypto.{VerificationKeyHash}
use cardano/transaction.{OutputReference}

pub type ProposalStatus {
  Active
  Approved
  Rejected
  Executed
  Cancelled
}

pub type Vote {
  For
  Against
  Abstain
}

pub type ProposalCategory {
  TreasuryAction
  ParameterChange
  MembershipChange
  Other
}

pub type Proposal {
  title: ByteArray,
  description: ByteArray,
  category: ProposalCategory,
  proposer: VerificationKeyHash,
  /// POSIX timestamp (ms) when the proposal was submitted
  creation_time: Int,
  /// POSIX timestamp (ms) after which no new votes are accepted
  voting_deadline: Int,
  status: ProposalStatus,
  execution_data: Data,
  votes: List<Pair<VerificationKeyHash, Vote>>,
  for_votes: Int,
  against_votes: Int,
  abstain_votes: Int,
}

pub type GovernanceParams {
  /// Minimum percentage of for-votes required to approve (0-100)
  approval_threshold: Int,
  /// Minimum voting window in milliseconds
  minimum_voting_period: Int,
  /// Minimum percentage of members that must vote for a result to be valid (0-100)
  quorum_percentage: Int,
}

pub type GovernanceDatum {
  entity_utxo_ref: OutputReference,
  treasury_utxo_ref: OutputReference,
  params: GovernanceParams,
  proposals: List<Proposal>,
  next_proposal_id: Int,
  /// Current member count — used to evaluate quorum (total_votes * 100 >= quorum_percentage * member_count)
  member_count: Int,
  /// Verification key hashes authorised to update governance parameters
  admins: List<VerificationKeyHash>,
}

pub type GovernanceAction {
  CreateProposal {
    title: ByteArray,
    description: ByteArray,
    category: ProposalCategory,
    voting_deadline: Int,
    execution_data: Data,
  }
  CastVote { proposal_id: Int, vote: Vote }
  ExecuteProposal { proposal_id: Int }
  CancelProposal { proposal_id: Int }
  UpdateParams { new_params: GovernanceParams }
}
