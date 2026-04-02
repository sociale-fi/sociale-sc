// validators/entity_registry/entity_registry.ak
//
// Entity Registry validator.
//
// Each cooperative has a separate UTxO at this contract address, carrying
// its state as an inline RegistryDatum. Multiple cooperatives can coexist at
// the same script address, each identified by its own UTxO.
//
// Supported actions: CreateEntity, AddMember, UpdateMemberStatus, AddAdmin, RemoveAdmin.

use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use aiken/interval.{Finite}
use aiken/primitive/bytearray
use cardano/transaction.{InlineDatum, Output, OutputReference, Transaction}
use entity_registry/types.{
  Entity, Member, MemberStatus, RegistryAction, RegistryDatum,
}

// ── Time ─────────────────────────────────────────────────────────────────────

/// Read the lower bound of the transaction validity range as a POSIX timestamp.
/// Returns 0 when no finite lower bound is set (e.g. in test transactions).
fn get_current_time(tx: Transaction) -> Int {
  when tx.validity_range.lower_bound.bound_type is {
    Finite(t) -> t
    _ -> 0
  }
}

// ── Input validation ──────────────────────────────────────────────────────────

fn validate_entity_inputs(name: ByteArray, description: ByteArray) -> Bool {
  let valid_name = name != #"" && bytearray.length(name) <= 64
  let valid_description =
    description != #"" && bytearray.length(description) <= 256
  valid_name && valid_description
}

fn validate_member_data(member: Member, current_time: Int) -> Bool {
  let valid_name = member.name != #"" && bytearray.length(member.name) <= 64
  let valid_vkh = member.verification_key_hash != #""
  // join_time upper-bound enforced only when a finite lower bound was set
  let valid_time =
    if current_time > 0 {
      member.join_time > 0 && member.join_time <= current_time
    } else {
      member.join_time > 0
    }
  let valid_nft = member.nft_token_name != #""
  // Members must be added with Active status
  let valid_status = member.status == MemberStatus.Active
  valid_name && valid_vkh && valid_time && valid_nft && valid_status
}

// ── Authorisation helpers ─────────────────────────────────────────────────────

fn is_signed_by_any_admin(
  signatories: List<VerificationKeyHash>,
  admins: List<VerificationKeyHash>,
) -> Bool {
  list.any(admins, fn(admin) { list.has(signatories, admin) })
}

fn member_exists(members: List<Member>, vkh: VerificationKeyHash) -> Bool {
  list.any(members, fn(m) { m.verification_key_hash == vkh })
}

// ── Output verification ───────────────────────────────────────────────────────

/// Extract the single inline-datum output, decoded as RegistryDatum.
/// Returns None if there is not exactly one such output.
fn get_updated_datum(outputs: List<Output>) -> Option<RegistryDatum> {
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
          expect datum: RegistryDatum = data
          Some(datum)
        }
        _ -> None
      }
    _ -> None
  }
}

fn verify_create_entity_output(
  outputs: List<Output>,
  name: ByteArray,
  description: ByteArray,
  founder: VerificationKeyHash,
  current_time: Int,
) -> Bool {
  when get_updated_datum(outputs) is {
    Some(new_datum) -> {
      let entity_valid =
        new_datum.entity.name == name && new_datum.entity.description == description && new_datum.entity.founder == founder && new_datum.entity.creation_time >= current_time && new_datum.entity.member_count == 0
      // Founder is the sole initial admin
      let admins_valid = new_datum.admins == [founder]
      let members_empty = list.is_empty(new_datum.members)
      entity_valid && admins_valid && members_empty
    }
    None -> False
  }
}

fn verify_add_member_output(
  outputs: List<Output>,
  old_datum: RegistryDatum,
  new_member: Member,
) -> Bool {
  when get_updated_datum(outputs) is {
    Some(new_datum) -> {
      let entity_unchanged =
        new_datum.entity.name == old_datum.entity.name && new_datum.entity.description == old_datum.entity.description && new_datum.entity.founder == old_datum.entity.founder && new_datum.entity.creation_time == old_datum.entity.creation_time && new_datum.entity.member_count == old_datum.entity.member_count + 1
      let admins_unchanged = new_datum.admins == old_datum.admins
      let existing_preserved =
        list.all(old_datum.members, fn(m) { list.has(new_datum.members, m) })
      let new_member_present = list.has(new_datum.members, new_member)
      let count_correct =
        list.length(new_datum.members) == list.length(old_datum.members) + 1
      entity_unchanged && admins_unchanged && existing_preserved && new_member_present && count_correct
    }
    None -> False
  }
}

fn verify_update_status_output(
  outputs: List<Output>,
  old_datum: RegistryDatum,
  vkh: VerificationKeyHash,
  new_status: MemberStatus,
) -> Bool {
  when get_updated_datum(outputs) is {
    Some(new_datum) -> {
      let entity_unchanged = new_datum.entity == old_datum.entity
      let admins_unchanged = new_datum.admins == old_datum.admins
      let count_unchanged =
        list.length(new_datum.members) == list.length(old_datum.members)
      // Every old member must appear in the new list, with the target's status updated
      let members_valid =
        list.all(
          old_datum.members,
          fn(old_m) {
            if old_m.verification_key_hash == vkh {
              list.has(
                new_datum.members,
                Member { ..old_m, status: new_status },
              )
            } else {
              list.has(new_datum.members, old_m)
            }
          },
        )
      entity_unchanged && admins_unchanged && count_unchanged && members_valid
    }
    None -> False
  }
}

fn verify_add_admin_output(
  outputs: List<Output>,
  old_datum: RegistryDatum,
  new_admin: VerificationKeyHash,
) -> Bool {
  when get_updated_datum(outputs) is {
    Some(new_datum) -> {
      let entity_unchanged = new_datum.entity == old_datum.entity
      let members_unchanged = new_datum.members == old_datum.members
      let count_increased =
        list.length(new_datum.admins) == list.length(old_datum.admins) + 1
      let new_admin_present = list.has(new_datum.admins, new_admin)
      let old_admins_preserved =
        list.all(old_datum.admins, fn(a) { list.has(new_datum.admins, a) })
      entity_unchanged && members_unchanged && count_increased && new_admin_present && old_admins_preserved
    }
    None -> False
  }
}

fn verify_remove_admin_output(
  outputs: List<Output>,
  old_datum: RegistryDatum,
  admin_to_remove: VerificationKeyHash,
) -> Bool {
  when get_updated_datum(outputs) is {
    Some(new_datum) -> {
      let entity_unchanged = new_datum.entity == old_datum.entity
      let members_unchanged = new_datum.members == old_datum.members
      let count_decreased =
        list.length(new_datum.admins) == list.length(old_datum.admins) - 1
      let removed_absent = !list.has(new_datum.admins, admin_to_remove)
      // All remaining admins must have been in the old list
      let remaining_valid =
        list.all(new_datum.admins, fn(a) { list.has(old_datum.admins, a) })
      entity_unchanged && members_unchanged && count_decreased && removed_absent && remaining_valid
    }
    None -> False
  }
}

// ── Validator ─────────────────────────────────────────────────────────────────

validator entity_registry {
  spend(
    datum_opt: Option<RegistryDatum>,
    redeemer: RegistryAction,
    _own_ref: OutputReference,
    tx: Transaction,
  ) {
    let current_time = get_current_time(tx)

    when datum_opt is {
      Some(datum) ->
        when redeemer is {
          // Cannot create a new entity when a UTxO already exists at this address
          RegistryAction.CreateEntity { .. } -> False

          RegistryAction.AddMember { member } -> {
            let valid_data = validate_member_data(member, current_time)
            let admin_signed =
              is_signed_by_any_admin(tx.extra_signatories, datum.admins)
            let not_duplicate =
              !member_exists(datum.members, member.verification_key_hash)
            if !valid_data || !admin_signed || !not_duplicate {
              False
            } else {
              verify_add_member_output(tx.outputs, datum, member)
            }
          }

          RegistryAction.UpdateMemberStatus { vkh, new_status } -> {
            let admin_signed =
              is_signed_by_any_admin(tx.extra_signatories, datum.admins)
            let member_found = member_exists(datum.members, vkh)
            if !admin_signed || !member_found {
              False
            } else {
              verify_update_status_output(tx.outputs, datum, vkh, new_status)
            }
          }

          RegistryAction.AddAdmin { vkh } -> {
            let admin_signed =
              is_signed_by_any_admin(tx.extra_signatories, datum.admins)
            let not_existing = !list.has(datum.admins, vkh)
            if !admin_signed || !not_existing {
              False
            } else {
              verify_add_admin_output(tx.outputs, datum, vkh)
            }
          }

          RegistryAction.RemoveAdmin { vkh } -> {
            let admin_signed =
              is_signed_by_any_admin(tx.extra_signatories, datum.admins)
            let admin_found = list.has(datum.admins, vkh)
            // Prevent removing the last admin, which would lock the contract
            let not_last_admin = list.length(datum.admins) > 1
            if !admin_signed || !admin_found || !not_last_admin {
              False
            } else {
              verify_remove_admin_output(tx.outputs, datum, vkh)
            }
          }
        }

      None ->
        when redeemer is {
          RegistryAction.CreateEntity { name, description } -> {
            let valid_inputs = validate_entity_inputs(name, description)
            let has_signer = list.length(tx.extra_signatories) > 0
            if !valid_inputs || !has_signer {
              False
            } else {
              expect Some(founder) = list.at(tx.extra_signatories, 0)
              verify_create_entity_output(
                tx.outputs,
                name,
                description,
                founder,
                current_time,
              )
            }
          }
          // All other actions require an existing entity UTxO
          _ -> False
        }
    }
  }

  else(_) {
    False
  }
}
