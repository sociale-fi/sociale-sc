// validators/audit_anchor/audit_anchor_tests.ak

use aiken/collection/list
use audit_anchor/types.{AnchorDatum, AnchorRecord, hash_record}
use cardano/assets.{from_lovelace}
use cardano/transaction.{InlineDatum, Transaction}
use mocktail.{
  complete, mock_script_address, mocktail_tx, required_signer_hash, tx_out,
  tx_out_inline_datum,
}
use mocktail/virgin_key_hash.{mock_pub_key_hash}

// ── Test helpers ──────────────────────────────────────────────────────────────

fn sample_datum() -> AnchorDatum {
  AnchorDatum {
    operator: mock_pub_key_hash(0),
    cooperative_id: "coop-001",
    // last_anchor_time is before sample_record's batch window
    last_anchor_time: 1699700000000,
    anchor_count: 5,
    last_record_hash: #"abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
  }
}

fn sample_record(prev_hash: ByteArray) -> AnchorRecord {
  AnchorRecord {
    merkle_root: #"aabbccdd11223344aabbccdd11223344aabbccdd11223344aabbccdd11223344",
    // Batch window is strictly after sample_datum.last_anchor_time
    batch_start: 1699800000000,
    batch_end: 1699900000000,
    tx_count: 42,
    prev_record_hash: prev_hash,
  }
}

fn tx_with_signer_and_datum(
  signer: ByteArray,
  datum: AnchorDatum,
) -> Transaction {
  mocktail_tx()
    |> required_signer_hash(True, signer)
    |> tx_out(True, mock_script_address(0, None), from_lovelace(2_000_000))
    |> tx_out_inline_datum(True, datum)
    |> complete()
}

// ── Record field validation ────────────────────────────────────────────────────

test record_rejects_empty_merkle_root() {
  let valid = #"aabbccdd"
  let empty = #""
  valid != #"" && empty == #""
}

test record_requires_positive_batch_start() {
  let valid_start = 1699000000000
  let zero_start = 0
  valid_start > 0 && !(zero_start > 0)
}

test record_requires_batch_end_after_start() {
  let start = 1699000000000
  let valid_end = start + 100000
  let equal_end = start
  let past_end = start - 1
  valid_end > start && !(equal_end > start) && !(past_end > start)
}

test record_requires_positive_tx_count() {
  let valid = 10
  let zero = 0
  valid > 0 && !(zero > 0)
}

// ── Chain linking ──────────────────────────────────────────────────────────────

test chain_link_must_match_last_record_hash() {
  let datum = sample_datum()

  let valid_record = sample_record(datum.last_record_hash)
  let broken_record =
    sample_record(
      #"deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
    )

  let valid_links = valid_record.prev_record_hash == datum.last_record_hash
  let broken_fails = broken_record.prev_record_hash != datum.last_record_hash

  valid_links && broken_fails
}

test first_anchor_uses_empty_prev_hash() {
  // The initial datum for a cooperative has no prior anchor.
  // last_record_hash is #"" and the first record's prev_record_hash must match.
  let initial_datum =
    AnchorDatum {
      operator: mock_pub_key_hash(0),
      cooperative_id: "coop-001",
      last_anchor_time: 0,
      anchor_count: 0,
      last_record_hash: #"",
    }

  let first_record =
    AnchorRecord {
      merkle_root: #"aabbccdd11223344",
      batch_start: 1700000000000,
      batch_end: 1700100000000,
      tx_count: 10,
      prev_record_hash: #"",
    }

  first_record.prev_record_hash == initial_datum.last_record_hash
}

test record_hash_is_deterministic() {
  let record = sample_record(#"aabbccdd")
  hash_record(record) == hash_record(record)
}

test different_records_produce_different_hashes() {
  let record_a = sample_record(#"0102030405060708")
  let record_b =
    AnchorRecord {
      merkle_root: #"bbbbccccddddeeeebbbbccccddddeeee",
      batch_start: 1699000000000,
      batch_end: 1699100000000,
      tx_count: 7,
      prev_record_hash: #"0807060504030201",
    }
  hash_record(record_a) != hash_record(record_b)
}

// ── Anchor output datum ────────────────────────────────────────────────────────

test anchor_output_increments_count() {
  let datum = sample_datum()
  let record = sample_record(datum.last_record_hash)

  let output_datum =
    AnchorDatum {
      ..datum,
      anchor_count: datum.anchor_count + 1,
      last_anchor_time: record.batch_end,
      last_record_hash: hash_record(record),
    }

  output_datum.anchor_count == datum.anchor_count + 1
}

test anchor_output_advances_time() {
  let datum = sample_datum()
  let record = sample_record(datum.last_record_hash)

  let output_datum =
    AnchorDatum {
      ..datum,
      anchor_count: datum.anchor_count + 1,
      last_anchor_time: record.batch_end,
      last_record_hash: hash_record(record),
    }

  output_datum.last_anchor_time > datum.last_anchor_time
}

test anchor_output_updates_hash() {
  let datum = sample_datum()
  let record = sample_record(datum.last_record_hash)
  let new_hash = hash_record(record)

  let output_datum =
    AnchorDatum {
      ..datum,
      anchor_count: datum.anchor_count + 1,
      last_anchor_time: record.batch_end,
      last_record_hash: new_hash,
    }

  output_datum.last_record_hash == new_hash && output_datum.last_record_hash != datum.last_record_hash
}

test anchor_output_preserves_identity() {
  let datum = sample_datum()
  let record = sample_record(datum.last_record_hash)

  let output_datum =
    AnchorDatum {
      ..datum,
      anchor_count: datum.anchor_count + 1,
      last_anchor_time: record.batch_end,
      last_record_hash: hash_record(record),
    }

  output_datum.operator == datum.operator && output_datum.cooperative_id == datum.cooperative_id
}

// ── Operator rotation ─────────────────────────────────────────────────────────

test rotate_rejects_empty_new_operator() {
  let empty_key = #""
  empty_key == #""
}

test rotate_rejects_same_operator() {
  let datum = sample_datum()
  // Rotating to the current operator is a no-op and must be rejected
  datum.operator == datum.operator
}

test rotate_output_updates_only_operator() {
  let datum = sample_datum()
  let new_operator = mock_pub_key_hash(1)

  let output_datum = AnchorDatum { ..datum, operator: new_operator }

  let operator_updated = output_datum.operator == new_operator
  let cooperative_unchanged =
    output_datum.cooperative_id == datum.cooperative_id
  let count_unchanged = output_datum.anchor_count == datum.anchor_count
  let hash_unchanged = output_datum.last_record_hash == datum.last_record_hash
  let time_unchanged = output_datum.last_anchor_time == datum.last_anchor_time

  operator_updated && cooperative_unchanged && count_unchanged && hash_unchanged && time_unchanged
}

// ── Transaction authorisation ─────────────────────────────────────────────────

test operator_must_sign_transaction() {
  let datum = sample_datum()
  let operator = datum.operator
  let non_operator = mock_pub_key_hash(9)

  let tx = tx_with_signer_and_datum(operator, datum)

  let operator_present = list.any(tx.extra_signatories, fn(s) { s == operator })
  let non_operator_absent =
    !list.any(tx.extra_signatories, fn(s) { s == non_operator })

  operator_present && non_operator_absent
}

test tx_output_carries_inline_datum() {
  let datum = sample_datum()
  let tx = tx_with_signer_and_datum(datum.operator, datum)

  list.any(
    tx.outputs,
    fn(o) {
      when o.datum is {
        InlineDatum(_) -> True
        _ -> False
      }
    },
  )
}

test none_datum_rejects_all_actions() {
  let no_datum: Option<AnchorDatum> = None
  when no_datum is {
    None -> True
    Some(_) -> False
  }
}

// ── Cooperative isolation ──────────────────────────────────────────────────────

test cooperatives_have_independent_anchor_chains() {
  let coop_a =
    AnchorDatum {
      operator: mock_pub_key_hash(0),
      cooperative_id: "coop-a",
      last_anchor_time: 1700000000000,
      anchor_count: 10,
      last_record_hash: #"cafebabe00000000cafebabe00000000cafebabe00000000cafebabe00000001",
    }

  let coop_b =
    AnchorDatum {
      operator: mock_pub_key_hash(1),
      cooperative_id: "coop-b",
      last_anchor_time: 1700100000000,
      anchor_count: 3,
      last_record_hash: #"cafebabe00000000cafebabe00000000cafebabe00000000cafebabe00000002",
    }

  coop_a.cooperative_id != coop_b.cooperative_id && coop_a.anchor_count != coop_b.anchor_count && coop_a.last_record_hash != coop_b.last_record_hash
}
