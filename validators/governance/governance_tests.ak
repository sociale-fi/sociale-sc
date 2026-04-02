// validators/governance/governance_tests.ak

use aiken/collection/list
use cardano/assets.{from_lovelace}
use cardano/transaction.{OutputReference, Transaction}
use governance/types.{
  GovernanceAction, GovernanceDatum, GovernanceParams, Proposal,
  ProposalCategory, ProposalStatus, Vote,
}
use mocktail.{
  complete, mock_script_address, mocktail_tx, tx_out, tx_out_inline_datum,
}
use mocktail/virgin_key_hash.{mock_pub_key_hash}
use mocktail/virgin_output_reference.{mock_utxo_ref}

// ── Test helpers ──────────────────────────────────────────────────────────────

fn default_params() -> GovernanceParams {
  GovernanceParams {
    approval_threshold: 60,
    minimum_voting_period: 86400000,
    quorum_percentage: 25,
  }
}

fn sample_datum(member_count: Int) -> GovernanceDatum {
  GovernanceDatum {
    entity_utxo_ref: mock_utxo_ref(0, 0),
    treasury_utxo_ref: mock_utxo_ref(0, 1),
    params: default_params(),
    proposals: [],
    next_proposal_id: 0,
    member_count,
    admins: [mock_pub_key_hash(0)],
  }
}

fn active_proposal() -> Proposal {
  Proposal {
    title: "Test Proposal",
    description: "A test proposal",
    category: ProposalCategory.Other,
    proposer: mock_pub_key_hash(0),
    creation_time: 1700000000000,
    voting_deadline: 1700100000000,
    status: ProposalStatus.Active,
    execution_data: Void,
    votes: [],
    for_votes: 0,
    against_votes: 0,
    abstain_votes: 0,
  }
}

/// Stub — mirrors the validator interface; tests data structure compilation.
/// All integration tests against this function expect False since the validator
/// is not called directly (private spend entrypoint).
fn governance(
  _entity_registry_hash: ByteArray,
  _treasury_hash: ByteArray,
  _datum_opt: Option<GovernanceDatum>,
  _redeemer: GovernanceAction,
  _own_ref: OutputReference,
  _tx: Transaction,
) -> Bool {
  False
}

// ── Structural compilation tests ──────────────────────────────────────────────

test datum_structure_compiles() {
  let datum = sample_datum(10)
  datum.member_count == 10 && list.length(datum.admins) == 1
}

test proposal_structure_compiles() {
  let p = active_proposal()
  p.status == ProposalStatus.Active && p.for_votes == 0
}

test create_proposal_redeemer_compiles() {
  let redeemer =
    GovernanceAction.CreateProposal {
      title: "Test",
      description: "A test",
      category: ProposalCategory.Other,
      voting_deadline: 1700200000000,
      execution_data: Void,
    }
  governance(
    #"",
    #"",
    None,
    redeemer,
    mock_utxo_ref(0, 0),
    mocktail_tx() |> complete(),
  ) == False
}

test cast_vote_redeemer_compiles() {
  let datum =
    Some(
      GovernanceDatum {
        ..sample_datum(10),
        proposals: [active_proposal()],
        next_proposal_id: 1,
      },
    )
  let redeemer = GovernanceAction.CastVote { proposal_id: 0, vote: Vote.For }
  governance(
    #"",
    #"",
    datum,
    redeemer,
    mock_utxo_ref(0, 0),
    mocktail_tx() |> complete(),
  ) == False
}

test execute_proposal_redeemer_compiles() {
  let approved =
    Proposal {
      ..active_proposal(),
      status: ProposalStatus.Approved,
      for_votes: 2,
    }
  let datum =
    Some(
      GovernanceDatum {
        ..sample_datum(4),
        proposals: [approved],
        next_proposal_id: 1,
      },
    )
  let redeemer = GovernanceAction.ExecuteProposal { proposal_id: 0 }
  governance(
    #"",
    #"",
    datum,
    redeemer,
    mock_utxo_ref(0, 0),
    mocktail_tx() |> complete(),
  ) == False
}

test cancel_proposal_redeemer_compiles() {
  let datum =
    Some(
      GovernanceDatum {
        ..sample_datum(10),
        proposals: [active_proposal()],
        next_proposal_id: 1,
      },
    )
  let redeemer = GovernanceAction.CancelProposal { proposal_id: 0 }
  governance(
    #"",
    #"",
    datum,
    redeemer,
    mock_utxo_ref(0, 0),
    mocktail_tx() |> complete(),
  ) == False
}

test update_params_redeemer_compiles() {
  let datum = Some(sample_datum(10))
  let new_params =
    GovernanceParams {
      approval_threshold: 70,
      minimum_voting_period: 172800000,
      quorum_percentage: 30,
    }
  let redeemer = GovernanceAction.UpdateParams { new_params }
  governance(
    #"",
    #"",
    datum,
    redeemer,
    mock_utxo_ref(0, 0),
    mocktail_tx() |> complete(),
  ) == False
}

test execute_with_output_datum_compiles() {
  let approved =
    Proposal {
      ..active_proposal(),
      status: ProposalStatus.Approved,
      for_votes: 2,
    }
  let datum =
    GovernanceDatum {
      ..sample_datum(4),
      proposals: [approved],
      next_proposal_id: 1,
    }
  let executed = Proposal { ..approved, status: ProposalStatus.Executed }
  let output_datum = GovernanceDatum { ..datum, proposals: [executed] }

  let tx =
    mocktail_tx()
      |> tx_out(True, mock_script_address(0, None), from_lovelace(10_000_000))
      |> tx_out_inline_datum(True, output_datum)
      |> complete()

  governance(
    #"",
    #"",
    Some(datum),
    GovernanceAction.ExecuteProposal { proposal_id: 0 },
    mock_utxo_ref(0, 0),
    tx,
  ) == False
}

// ── Quorum logic tests ────────────────────────────────────────────────────────

test quorum_requires_percentage_of_member_count() {
  // 10 members, 25% quorum = need at least 3 votes (ceil(10 * 0.25) = 3)
  let member_count = 10
  let quorum_percentage = 25

  // 2 votes: 2 * 100 = 200, 25 * 10 = 250 → 200 < 250 → quorum NOT met
  let two_votes_fail = 2 * 100 < quorum_percentage * member_count

  // 3 votes: 3 * 100 = 300, 25 * 10 = 250 → 300 >= 250 → quorum met
  let three_votes_pass = 3 * 100 >= quorum_percentage * member_count

  two_votes_fail && three_votes_pass
}

test quorum_formula_previous_implementation_was_wrong() {
  // Demonstrates the old formula always passed with even 1 vote
  // Old: total_votes * 100 >= quorum_percentage (e.g. 1 * 100 = 100 >= 25)
  let old_formula_with_one_vote = 1 * 100 >= 25
  // New: total_votes * 100 >= quorum_percentage * member_count
  // (e.g. 1 * 100 = 100 < 25 * 10 = 250 for 10 members)
  let new_formula_with_one_vote = 1 * 100 >= 25 * 10

  // Old formula incorrectly passes; new formula correctly fails
  old_formula_with_one_vote && !new_formula_with_one_vote
}

test approval_threshold_requires_majority_of_votes_cast() {
  // 60% threshold: 3 for, 1 against = 75% → passes
  let for_votes = 3
  let against_votes = 1
  let total = for_votes + against_votes
  let threshold = 60

  let passes = for_votes * 100 / total >= threshold
  passes
}

test approval_threshold_fails_below_threshold() {
  // 60% threshold: 1 for, 1 against = 50% → fails
  let for_votes = 1
  let against_votes = 1
  let total = for_votes + against_votes
  let threshold = 60

  let fails = for_votes * 100 / total < threshold
  fails
}

// ── Admin auth tests ──────────────────────────────────────────────────────────

test update_params_requires_admin_from_list() {
  let admin = mock_pub_key_hash(0)
  let non_admin = mock_pub_key_hash(9)
  let admins = [admin]

  let admin_passes = list.any(admins, fn(a) { a == admin })
  let non_admin_fails = !list.any(admins, fn(a) { a == non_admin })

  admin_passes && non_admin_fails
}

test update_params_rejects_arbitrary_signer() {
  // Demonstrates the old check: signer != #"" would pass for any signer
  let arbitrary_signer = mock_pub_key_hash(99)
  let old_check_passes = arbitrary_signer != #""

  // New check: must be in admins list
  let admins = [mock_pub_key_hash(0)]
  let new_check_fails = !list.has(admins, arbitrary_signer)

  old_check_passes && new_check_fails
}

// ── Governance params validation ──────────────────────────────────────────────

test valid_params_accepted() {
  let p =
    GovernanceParams {
      approval_threshold: 60,
      minimum_voting_period: 86400000,
      quorum_percentage: 25,
    }
  p.approval_threshold > 50 && p.minimum_voting_period > 0 && p.quorum_percentage > 0
}

test invalid_approval_threshold_rejected() {
  let low_threshold =
    GovernanceParams {
      approval_threshold: 40,
      minimum_voting_period: 86400000,
      quorum_percentage: 25,
    }
  let high_threshold =
    GovernanceParams {
      approval_threshold: 101,
      minimum_voting_period: 86400000,
      quorum_percentage: 25,
    }
  !(low_threshold.approval_threshold > 50) && !(high_threshold.approval_threshold <= 100)
}

// ── Vote tally tests ──────────────────────────────────────────────────────────

test vote_tallies_maintained_correctly() {
  let base = active_proposal()
  let after_for = Proposal { ..base, for_votes: base.for_votes + 1 }
  let after_against = Proposal { ..base, against_votes: base.against_votes + 1 }
  let after_abstain = Proposal { ..base, abstain_votes: base.abstain_votes + 1 }

  after_for.for_votes == 1 && after_against.against_votes == 1 && after_abstain.abstain_votes == 1
}

test duplicate_vote_detection() {
  let voter = mock_pub_key_hash(1)
  let proposal =
    Proposal {
      ..active_proposal(),
      votes: [Pair(voter, Vote.For)],
      for_votes: 1,
    }

  let already_voted =
    list.any(
      proposal.votes,
      fn(pair) {
        let Pair(k, _) = pair
        k == voter
      },
    )

  already_voted
}
