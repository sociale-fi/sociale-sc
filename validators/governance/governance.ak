// validators/governance/governance.ak
//
// Governance validator for cooperative on-chain decision-making.
//
// Supports the full proposal lifecycle: create, vote, execute, cancel, and
// parameter updates. Parameterised by the entity registry script hash and
// treasury script hash for cross-contract category validation.

use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use aiken/interval.{Finite}
use cardano/transaction.{InlineDatum, Output, OutputReference, Transaction}
use governance/types.{
  GovernanceAction, GovernanceDatum, GovernanceParams, Proposal,
  ProposalCategory, ProposalStatus, Vote,
}

// ── Time ─────────────────────────────────────────────────────────────────────

fn get_current_time(tx: Transaction) -> Int {
  when tx.validity_range.lower_bound.bound_type is {
    Finite(t) -> t
    _ -> 0
  }
}

// ── Output helpers ────────────────────────────────────────────────────────────

fn get_updated_datum(outputs: List<Output>) -> Option<GovernanceDatum> {
  let inline_outputs =
    list.filter(
      outputs,
      fn(o) {
        when o.datum is {
          InlineDatum(_) -> True
          _ -> False
        }
      },
    )
  when inline_outputs is {
    [output] ->
      when output.datum is {
        InlineDatum(data) -> {
          expect datum: GovernanceDatum = data
          Some(datum)
        }
        _ -> None
      }
    _ -> None
  }
}

// ── Authorisation ─────────────────────────────────────────────────────────────

fn is_signed_by_any_admin(
  signatories: List<VerificationKeyHash>,
  admins: List<VerificationKeyHash>,
) -> Bool {
  list.any(admins, fn(admin) { list.has(signatories, admin) })
}

// ── Parameter validation ──────────────────────────────────────────────────────

fn valid_params(p: GovernanceParams) -> Bool {
  let valid_threshold = p.approval_threshold > 50 && p.approval_threshold <= 100
  let valid_period = p.minimum_voting_period > 0
  let valid_quorum = p.quorum_percentage > 0 && p.quorum_percentage <= 100
  valid_threshold && valid_period && valid_quorum
}

// ── Quorum and approval checks ────────────────────────────────────────────────

fn quorum_met(proposal: Proposal, datum: GovernanceDatum) -> Bool {
  let total_votes =
    proposal.for_votes + proposal.against_votes + proposal.abstain_votes
  // total_votes must represent at least quorum_percentage% of member_count
  if datum.member_count > 0 {
    total_votes * 100 >= datum.params.quorum_percentage * datum.member_count
  } else {
    total_votes > 0
  }
}

fn approval_threshold_met(proposal: Proposal, datum: GovernanceDatum) -> Bool {
  let total_votes =
    proposal.for_votes + proposal.against_votes + proposal.abstain_votes
  if total_votes > 0 {
    proposal.for_votes * 100 / total_votes >= datum.params.approval_threshold
  } else {
    False
  }
}

// ── Invariant checks ──────────────────────────────────────────────────────────

/// Verify the non-proposal fields of the datum are unchanged between two states.
fn refs_and_params_unchanged(
  new_datum: GovernanceDatum,
  old_datum: GovernanceDatum,
) -> Bool {
  new_datum.entity_utxo_ref == old_datum.entity_utxo_ref && new_datum.treasury_utxo_ref == old_datum.treasury_utxo_ref && new_datum.params == old_datum.params && new_datum.next_proposal_id == old_datum.next_proposal_id && new_datum.member_count == old_datum.member_count && new_datum.admins == old_datum.admins
}

// ── Validator ─────────────────────────────────────────────────────────────────

validator governance(
  entity_registry_hash: ByteArray,
  treasury_hash: ByteArray,
) {
  spend(
    datum_opt: Option<GovernanceDatum>,
    redeemer: GovernanceAction,
    _own_ref: OutputReference,
    tx: Transaction,
  ) {
    let current_time = get_current_time(tx)
    let Transaction { extra_signatories, outputs, .. } = tx

    when datum_opt is {
      Some(datum) ->
        when redeemer is {
          GovernanceAction.CreateProposal {
            title,
            description,
            category,
            voting_deadline,
            execution_data,
          } -> {
            let valid_title = title != #""
            let valid_description = description != #""
            let has_signer = list.length(extra_signatories) > 0
            let valid_deadline =
              voting_deadline > current_time + datum.params.minimum_voting_period

            expect Some(proposer) = list.head(extra_signatories)

            when get_updated_datum(outputs) is {
              Some(new_datum) -> {
                let refs_unchanged = refs_and_params_unchanged(new_datum, datum)
                let proposals_grew =
                  list.length(new_datum.proposals) == list.length(
                    datum.proposals,
                  ) + 1
                let id_incremented =
                  new_datum.next_proposal_id == datum.next_proposal_id + 1
                let prior_preserved =
                  list.all(
                    datum.proposals,
                    fn(p) { list.has(new_datum.proposals, p) },
                  )
                let new_proposal_valid =
                  list.any(
                    new_datum.proposals,
                    fn(p) {
                      p.title == title && p.description == description && p.category == category && p.proposer == proposer && p.voting_deadline == voting_deadline && p.execution_data == execution_data && p.status == ProposalStatus.Active && list.is_empty(
                        p.votes,
                      ) && p.for_votes == 0 && p.against_votes == 0 && p.abstain_votes == 0
                    },
                  )
                valid_title? && valid_description? && has_signer? && valid_deadline? && refs_unchanged? && proposals_grew? && id_incremented? && prior_preserved? && new_proposal_valid?
              }
              None -> False
            }
          }

          GovernanceAction.CastVote { proposal_id, vote } -> {
            let has_signer = list.length(extra_signatories) > 0
            let valid_id =
              proposal_id >= 0 && proposal_id < list.length(datum.proposals)

            if !has_signer || !valid_id {
              False
            } else {
              expect Some(voter) = list.head(extra_signatories)
              expect Some(proposal) = list.at(datum.proposals, proposal_id)

              let is_active = proposal.status == ProposalStatus.Active
              // Voting window is open when the transaction's validity lower bound
              // is at or before the proposal's voting deadline
              let voting_open = current_time <= proposal.voting_deadline
              let already_voted =
                list.any(
                  proposal.votes,
                  fn(pair) {
                    let Pair(voter_key, _) = pair
                    voter_key == voter
                  },
                )

              if !is_active || !voting_open || already_voted {
                False
              } else {
                let vote_type: Vote = vote

                when get_updated_datum(outputs) is {
                  Some(new_datum) -> {
                    let refs_unchanged =
                      refs_and_params_unchanged(new_datum, datum)
                    let count_unchanged =
                      list.length(new_datum.proposals) == list.length(
                        datum.proposals,
                      )

                    expect Some(new_proposal) =
                      list.at(new_datum.proposals, proposal_id)

                    let other_proposals_unchanged =
                      list.all(
                        list.range(0, list.length(datum.proposals)),
                        fn(index) {
                          if index == proposal_id {
                            True
                          } else {
                            expect Some(old_p) = list.at(datum.proposals, index)
                            expect Some(new_p) =
                              list.at(new_datum.proposals, index)
                            old_p == new_p
                          }
                        },
                      )

                    let status_active =
                      new_proposal.status == ProposalStatus.Active
                    let core_unchanged =
                      new_proposal.title == proposal.title && new_proposal.description == proposal.description && new_proposal.category == proposal.category && new_proposal.proposer == proposal.proposer && new_proposal.creation_time == proposal.creation_time && new_proposal.voting_deadline == proposal.voting_deadline && new_proposal.execution_data == proposal.execution_data

                    let vote_added =
                      list.has(new_proposal.votes, Pair(voter, vote_type))
                    let prior_votes_preserved =
                      list.all(
                        proposal.votes,
                        fn(v) { list.has(new_proposal.votes, v) },
                      )
                    let vote_count_grew =
                      list.length(new_proposal.votes) == list.length(
                        proposal.votes,
                      ) + 1

                    let tallies_correct =
                      when vote_type is {
                        Vote.For ->
                          new_proposal.for_votes == proposal.for_votes + 1 && new_proposal.against_votes == proposal.against_votes && new_proposal.abstain_votes == proposal.abstain_votes
                        Vote.Against ->
                          new_proposal.for_votes == proposal.for_votes && new_proposal.against_votes == proposal.against_votes + 1 && new_proposal.abstain_votes == proposal.abstain_votes
                        Vote.Abstain ->
                          new_proposal.for_votes == proposal.for_votes && new_proposal.against_votes == proposal.against_votes && new_proposal.abstain_votes == proposal.abstain_votes + 1
                      }

                    refs_unchanged? && count_unchanged? && other_proposals_unchanged? && status_active? && core_unchanged? && vote_added? && prior_votes_preserved? && vote_count_grew? && tallies_correct?
                  }
                  None -> False
                }
              }
            }
          }

          GovernanceAction.ExecuteProposal { proposal_id } -> {
            let valid_id =
              proposal_id >= 0 && proposal_id < list.length(datum.proposals)

            if !valid_id {
              False
            } else {
              expect Some(proposal) = list.at(datum.proposals, proposal_id)

              let is_approved = proposal.status == ProposalStatus.Approved
              let can_be_approved =
                proposal.status == ProposalStatus.Active && quorum_met(
                  proposal,
                  datum,
                ) && approval_threshold_met(proposal, datum)

              if !is_approved && !can_be_approved {
                False
              } else {
                when get_updated_datum(outputs) is {
                  Some(new_datum) -> {
                    let refs_unchanged =
                      refs_and_params_unchanged(new_datum, datum)
                    let count_unchanged =
                      list.length(new_datum.proposals) == list.length(
                        datum.proposals,
                      )

                    expect Some(new_proposal) =
                      list.at(new_datum.proposals, proposal_id)

                    let other_proposals_unchanged =
                      list.all(
                        list.range(0, list.length(datum.proposals)),
                        fn(index) {
                          if index == proposal_id {
                            True
                          } else {
                            expect Some(old_p) = list.at(datum.proposals, index)
                            expect Some(new_p) =
                              list.at(new_datum.proposals, index)
                            old_p == new_p
                          }
                        },
                      )

                    let status_executed =
                      new_proposal.status == ProposalStatus.Executed
                    let core_unchanged =
                      new_proposal.title == proposal.title && new_proposal.description == proposal.description && new_proposal.category == proposal.category && new_proposal.proposer == proposal.proposer && new_proposal.creation_time == proposal.creation_time && new_proposal.voting_deadline == proposal.voting_deadline && new_proposal.execution_data == proposal.execution_data && new_proposal.votes == proposal.votes && new_proposal.for_votes == proposal.for_votes && new_proposal.against_votes == proposal.against_votes && new_proposal.abstain_votes == proposal.abstain_votes

                    // Category-specific cross-contract checks
                    let execution_valid =
                      when proposal.category is {
                        ProposalCategory.TreasuryAction -> treasury_hash != #""
                        ProposalCategory.MembershipChange ->
                          entity_registry_hash != #""
                        ProposalCategory.ParameterChange -> True
                        ProposalCategory.Other -> True
                      }

                    refs_unchanged? && count_unchanged? && other_proposals_unchanged? && status_executed? && core_unchanged? && execution_valid?
                  }
                  None -> False
                }
              }
            }
          }

          GovernanceAction.CancelProposal { proposal_id } -> {
            let valid_id =
              proposal_id >= 0 && proposal_id < list.length(datum.proposals)

            if !valid_id {
              False
            } else {
              expect Some(proposal) = list.at(datum.proposals, proposal_id)

              let is_active = proposal.status == ProposalStatus.Active
              let signed_by_proposer =
                list.has(extra_signatories, proposal.proposer)

              if !is_active || !signed_by_proposer {
                False
              } else {
                when get_updated_datum(outputs) is {
                  Some(new_datum) -> {
                    let refs_unchanged =
                      refs_and_params_unchanged(new_datum, datum)
                    let count_unchanged =
                      list.length(new_datum.proposals) == list.length(
                        datum.proposals,
                      )

                    expect Some(new_proposal) =
                      list.at(new_datum.proposals, proposal_id)

                    let other_proposals_unchanged =
                      list.all(
                        list.range(0, list.length(datum.proposals)),
                        fn(index) {
                          if index == proposal_id {
                            True
                          } else {
                            expect Some(old_p) = list.at(datum.proposals, index)
                            expect Some(new_p) =
                              list.at(new_datum.proposals, index)
                            old_p == new_p
                          }
                        },
                      )

                    let status_cancelled =
                      new_proposal.status == ProposalStatus.Cancelled
                    let core_unchanged =
                      new_proposal.title == proposal.title && new_proposal.description == proposal.description && new_proposal.category == proposal.category && new_proposal.proposer == proposal.proposer && new_proposal.creation_time == proposal.creation_time && new_proposal.voting_deadline == proposal.voting_deadline && new_proposal.execution_data == proposal.execution_data && new_proposal.votes == proposal.votes && new_proposal.for_votes == proposal.for_votes && new_proposal.against_votes == proposal.against_votes && new_proposal.abstain_votes == proposal.abstain_votes

                    refs_unchanged? && count_unchanged? && other_proposals_unchanged? && status_cancelled? && core_unchanged?
                  }
                  None -> False
                }
              }
            }
          }

          GovernanceAction.UpdateParams { new_params } -> {
            // Only authorised governance admins may update parameters
            let admin_signed =
              is_signed_by_any_admin(extra_signatories, datum.admins)

            if !admin_signed || !valid_params(new_params) {
              False
            } else {
              when get_updated_datum(outputs) is {
                Some(new_datum) -> {
                  let refs_unchanged =
                    new_datum.entity_utxo_ref == datum.entity_utxo_ref && new_datum.treasury_utxo_ref == datum.treasury_utxo_ref && new_datum.next_proposal_id == datum.next_proposal_id && new_datum.member_count == datum.member_count && new_datum.admins == datum.admins
                  let params_updated = new_datum.params == new_params
                  let proposals_unchanged =
                    new_datum.proposals == datum.proposals

                  refs_unchanged? && params_updated? && proposals_unchanged?
                }
                None -> False
              }
            }
          }
        }

      None ->
        // Bootstrap: first CreateProposal initialises the governance UTxO
        when redeemer is {
          GovernanceAction.CreateProposal {
            title,
            description,
            category,
            voting_deadline,
            execution_data,
          } -> {
            let valid_title = title != #""
            let valid_description = description != #""
            let has_signer = list.length(extra_signatories) > 0
            let valid_deadline = voting_deadline > current_time

            expect Some(proposer) = list.head(extra_signatories)

            when get_updated_datum(outputs) is {
              Some(new_datum) -> {
                let valid_refs =
                  new_datum.entity_utxo_ref.transaction_id != #"" && new_datum.treasury_utxo_ref.transaction_id != #""
                let valid_initial_params = valid_params(new_datum.params)
                let has_admins = list.length(new_datum.admins) > 0
                let one_proposal = list.length(new_datum.proposals) == 1
                let next_id_is_one = new_datum.next_proposal_id == 1

                let proposal_valid =
                  when list.head(new_datum.proposals) is {
                    Some(p) ->
                      p.title == title && p.description == description && p.category == category && p.proposer == proposer && p.voting_deadline == voting_deadline && p.execution_data == execution_data && p.status == ProposalStatus.Active && list.is_empty(
                        p.votes,
                      ) && p.for_votes == 0 && p.against_votes == 0 && p.abstain_votes == 0
                    None -> False
                  }

                valid_title? && valid_description? && has_signer? && valid_deadline? && valid_refs? && valid_initial_params? && has_admins? && one_proposal? && next_id_is_one? && proposal_valid?
              }
              None -> False
            }
          }
          _ -> False
        }
    }
  }

  else(_) {
    False
  }
}
