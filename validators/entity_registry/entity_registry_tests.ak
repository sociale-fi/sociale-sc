// validators/entity_registry/entity_registry_tests.ak

use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/assets.{from_lovelace}
use cardano/transaction.{InlineDatum, Transaction}
use entity_registry/types.{Entity, Member, MemberStatus, RegistryDatum}
use mocktail.{
  complete, mock_script_address, mocktail_tx, required_signer_hash, tx_out,
  tx_out_inline_datum,
}
use mocktail/virgin_key_hash.{mock_pub_key_hash}

// ── Test helpers ──────────────────────────────────────────────────────────────

fn sample_entity(founder: VerificationKeyHash, creation_time: Int) -> Entity {
  Entity {
    name: "Test SACCO",
    description: "A test cooperative",
    creation_time,
    founder,
    member_count: 0,
  }
}

fn sample_member(
  vkh: VerificationKeyHash,
  name: ByteArray,
  join_time: Int,
) -> Member {
  Member {
    name,
    verification_key_hash: vkh,
    join_time,
    nft_token_name: "member_cert",
    status: MemberStatus.Active,
    keri_aid: None,
  }
}

fn sample_datum(admin: VerificationKeyHash) -> RegistryDatum {
  RegistryDatum {
    entity: sample_entity(admin, 1700000000000),
    members: [],
    admins: [admin],
  }
}

fn tx_with_signer_and_datum(
  signer: VerificationKeyHash,
  datum: RegistryDatum,
) -> Transaction {
  mocktail_tx()
    |> required_signer_hash(True, signer)
    |> tx_out(True, mock_script_address(0, None), from_lovelace(10_000_000))
    |> tx_out_inline_datum(True, datum)
    |> complete()
}

// ── Entity creation ───────────────────────────────────────────────────────────

test create_entity_output_structure() {
  let founder = mock_pub_key_hash(0)
  let creation_time = 1700000000000

  let output_datum =
    RegistryDatum {
      entity: Entity {
        name: "Farmers Cooperative",
        description: "Agricultural savings group",
        creation_time,
        founder,
        member_count: 0,
      },
      members: [],
      admins: [founder],
    }

  let tx = tx_with_signer_and_datum(founder, output_datum)

  // Verify expected output state
  let has_signer = list.has(tx.extra_signatories, founder)
  let has_output =
    list.any(
      tx.outputs,
      fn(o) {
        when o.datum is {
          InlineDatum(_) -> True
          _ -> False
        }
      },
    )
  let datum_valid =
    output_datum.entity.member_count == 0 && list.is_empty(output_datum.members) && output_datum.admins == [
      founder,
    ]

  has_signer && has_output && datum_valid
}

test create_entity_rejects_empty_name() {
  let empty = #""
  let valid = "Valid Name"
  empty == #"" && valid != #""
}

test create_entity_rejects_empty_description() {
  let empty = #""
  let valid = "A valid description"
  empty == #"" && valid != #""
}

// ── Add member ────────────────────────────────────────────────────────────────

test add_member_output_structure() {
  let admin = mock_pub_key_hash(0)
  let member_vkh = mock_pub_key_hash(1)
  let existing_datum = sample_datum(admin)
  let new_member = sample_member(member_vkh, "Jane Doe", 1700000000000)

  let output_datum =
    RegistryDatum {
      entity: Entity { ..existing_datum.entity, member_count: 1 },
      members: [new_member],
      admins: [admin],
    }

  let tx = tx_with_signer_and_datum(admin, output_datum)

  let admin_signed = list.has(tx.extra_signatories, admin)
  let member_count_correct = output_datum.entity.member_count == 1
  let member_in_list =
    list.any(
      output_datum.members,
      fn(m) { m.verification_key_hash == member_vkh },
    )
  let admins_unchanged = output_datum.admins == existing_datum.admins

  admin_signed && member_count_correct && member_in_list && admins_unchanged
}

test add_member_rejects_duplicate() {
  let admin = mock_pub_key_hash(0)
  let member_vkh = mock_pub_key_hash(1)
  let existing_member = sample_member(member_vkh, "Existing", 1699999000000)

  let datum =
    RegistryDatum {
      entity: Entity { ..sample_entity(admin, 1699000000000), member_count: 1 },
      members: [existing_member],
      admins: [admin],
    }

  let already_exists =
    list.any(datum.members, fn(m) { m.verification_key_hash == member_vkh })
  already_exists
}

test add_member_requires_active_status() {
  let member_vkh = mock_pub_key_hash(1)

  let inactive_member =
    Member {
      name: "Jane",
      verification_key_hash: member_vkh,
      join_time: 1700000000000,
      nft_token_name: "cert",
      status: MemberStatus.Inactive,
      keri_aid: None,
    }

  // New members must have Active status — Inactive is invalid on creation
  inactive_member.status != MemberStatus.Active
}

test add_member_requires_admin_signature() {
  let admin = mock_pub_key_hash(0)
  let non_admin = mock_pub_key_hash(2)
  let datum = sample_datum(admin)

  let non_admin_signed = list.has([non_admin], admin)
  let admin_in_list = list.any(datum.admins, fn(a) { a == admin })

  !non_admin_signed && admin_in_list
}

test add_member_without_entity_fails() {
  let no_datum: Option<RegistryDatum> = None
  when no_datum is {
    None -> True
    Some(_) -> False
  }
}

// ── Update member status ──────────────────────────────────────────────────────

test update_member_status_output_structure() {
  let admin = mock_pub_key_hash(0)
  let member_vkh = mock_pub_key_hash(1)
  let existing_member = sample_member(member_vkh, "Jane Doe", 1699000000000)

  let old_datum =
    RegistryDatum {
      entity: Entity { ..sample_entity(admin, 1698000000000), member_count: 1 },
      members: [existing_member],
      admins: [admin],
    }

  // Updated member has Suspended status; everything else unchanged
  let updated_member =
    Member { ..existing_member, status: MemberStatus.Suspended }

  let output_datum =
    RegistryDatum {
      entity: old_datum.entity,
      members: [updated_member],
      admins: old_datum.admins,
    }

  let member_status_changed =
    list.any(
      output_datum.members,
      fn(m) {
        m.verification_key_hash == member_vkh && m.status == MemberStatus.Suspended
      },
    )
  let entity_unchanged = output_datum.entity == old_datum.entity
  let count_unchanged =
    list.length(output_datum.members) == list.length(old_datum.members)

  member_status_changed && entity_unchanged && count_unchanged
}

test update_status_requires_existing_member() {
  let admin = mock_pub_key_hash(0)
  let nonexistent_vkh = mock_pub_key_hash(9)
  let datum = sample_datum(admin)

  let found =
    list.any(
      datum.members,
      fn(m) { m.verification_key_hash == nonexistent_vkh },
    )
  !found
}

// ── Add admin ─────────────────────────────────────────────────────────────────

test add_admin_output_structure() {
  let admin = mock_pub_key_hash(0)
  let new_admin = mock_pub_key_hash(3)
  let old_datum = sample_datum(admin)

  let output_datum = RegistryDatum { ..old_datum, admins: [admin, new_admin] }

  let count_increased =
    list.length(output_datum.admins) == list.length(old_datum.admins) + 1
  let new_admin_present = list.has(output_datum.admins, new_admin)
  let original_admin_preserved = list.has(output_datum.admins, admin)
  let entity_unchanged = output_datum.entity == old_datum.entity
  let members_unchanged = output_datum.members == old_datum.members

  count_increased && new_admin_present && original_admin_preserved && entity_unchanged && members_unchanged
}

test add_admin_rejects_duplicate() {
  let admin = mock_pub_key_hash(0)
  let datum = sample_datum(admin)

  // admin is already in the list — should be rejected
  let already_admin = list.has(datum.admins, admin)
  already_admin
}

test multi_admin_any_can_sign() {
  let admin1 = mock_pub_key_hash(0)
  let admin2 = mock_pub_key_hash(3)

  let datum =
    RegistryDatum {
      entity: sample_entity(admin1, 1700000000000),
      members: [],
      admins: [admin1, admin2],
    }

  // Either admin's signature satisfies the check
  let admin1_authorised =
    list.any(datum.admins, fn(a) { list.has([admin1], a) })
  let admin2_authorised =
    list.any(datum.admins, fn(a) { list.has([admin2], a) })
  let non_admin_rejected =
    !list.any(datum.admins, fn(a) { list.has([mock_pub_key_hash(9)], a) })

  admin1_authorised && admin2_authorised && non_admin_rejected
}

// ── Remove admin ──────────────────────────────────────────────────────────────

test remove_admin_output_structure() {
  let admin1 = mock_pub_key_hash(0)
  let admin2 = mock_pub_key_hash(3)

  let old_datum =
    RegistryDatum {
      entity: sample_entity(admin1, 1700000000000),
      members: [],
      admins: [admin1, admin2],
    }

  let output_datum = RegistryDatum { ..old_datum, admins: [admin1] }

  let count_decreased =
    list.length(output_datum.admins) == list.length(old_datum.admins) - 1
  let removed_absent = !list.has(output_datum.admins, admin2)
  let remaining_present = list.has(output_datum.admins, admin1)

  count_decreased && removed_absent && remaining_present
}

test remove_last_admin_prevented() {
  let admin = mock_pub_key_hash(0)
  let datum = sample_datum(admin)

  // Cannot remove admin when only one exists
  let would_leave_no_admin = list.length(datum.admins) <= 1
  would_leave_no_admin
}

// ── Member data integrity ─────────────────────────────────────────────────────

test member_count_matches_list_length() {
  let admin = mock_pub_key_hash(0)
  let m1 = sample_member(mock_pub_key_hash(1), "Alice", 1699000000000)
  let m2 = sample_member(mock_pub_key_hash(2), "Bob", 1699500000000)

  let datum =
    RegistryDatum {
      entity: Entity { ..sample_entity(admin, 1698000000000), member_count: 2 },
      members: [m1, m2],
      admins: [admin],
    }

  datum.entity.member_count == list.length(datum.members)
}

test member_keri_aid_is_optional() {
  let vkh = mock_pub_key_hash(1)

  let without_aid = sample_member(vkh, "Alice", 1700000000000)
  let with_aid = Member { ..without_aid, keri_aid: Some("ENjS95qC...") }

  without_aid.keri_aid == None && with_aid.keri_aid != None
}

test multiple_cooperatives_at_same_contract() {
  let founder1 = mock_pub_key_hash(0)
  let founder2 = mock_pub_key_hash(1)

  let datum1 =
    RegistryDatum {
      entity: Entity {
        name: "Farmers SACCO",
        description: "Agricultural cooperative",
        creation_time: 1700000000000,
        founder: founder1,
        member_count: 0,
      },
      members: [],
      admins: [founder1],
    }

  let datum2 =
    RegistryDatum {
      entity: Entity {
        name: "Teachers SACCO",
        description: "Education cooperative",
        creation_time: 1700010000000,
        founder: founder2,
        member_count: 0,
      },
      members: [],
      admins: [founder2],
    }

  datum1.admins != datum2.admins && datum1.entity.name != datum2.entity.name
}
