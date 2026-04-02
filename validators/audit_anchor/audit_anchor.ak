// validators/audit_anchor/audit_anchor.ak
//
// Audit Anchor validator — Verifiable Ledger
//
// The Sociale platform operator periodically submits Merkle root commitments
// of batched cooperative transactions on-chain. Members and external parties
// can verify that the platform's records have not been altered by checking
// the on-chain anchor chain independently of the platform.
//
// Each cooperative has one UTxO at this address. Anchors form an immutable
// chain via prev_record_hash; any gap or tampered record is detectable
// off-chain by re-hashing the anchor sequence.

use aiken/collection/list
use aiken/interval.{Finite}
use audit_anchor/types.{AnchorAction, AnchorDatum, AnchorRecord, hash_record}
use cardano/transaction.{InlineDatum, Output, OutputReference, Transaction}

// ── Time ─────────────────────────────────────────────────────────────────────

fn get_current_time(tx: Transaction) -> Int {
  when tx.validity_range.lower_bound.bound_type is {
    Finite(t) -> t
    _ -> 0
  }
}

// ── Output verification ───────────────────────────────────────────────────────

fn get_output_datum(outputs: List<Output>) -> Option<AnchorDatum> {
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
          expect datum: AnchorDatum = data
          Some(datum)
        }
        _ -> None
      }
    _ -> None
  }
}

fn verify_anchor_output(
  outputs: List<Output>,
  old_datum: AnchorDatum,
  record: AnchorRecord,
) -> Bool {
  when get_output_datum(outputs) is {
    Some(new_datum) -> {
      let identity_unchanged =
        new_datum.operator == old_datum.operator && new_datum.cooperative_id == old_datum.cooperative_id
      let count_incremented =
        new_datum.anchor_count == old_datum.anchor_count + 1
      // last_anchor_time must strictly advance
      let time_advanced =
        new_datum.last_anchor_time > old_datum.last_anchor_time
      // The new hash must be the canonical hash of the submitted record
      let hash_chained = new_datum.last_record_hash == hash_record(record)
      identity_unchanged && count_incremented && time_advanced && hash_chained
    }
    None -> False
  }
}

fn verify_rotate_output(
  outputs: List<Output>,
  old_datum: AnchorDatum,
  new_operator: ByteArray,
) -> Bool {
  when get_output_datum(outputs) is {
    Some(new_datum) -> {
      let operator_updated = new_datum.operator == new_operator
      // All other fields must be unchanged during a key rotation
      let rest_unchanged =
        new_datum.cooperative_id == old_datum.cooperative_id && new_datum.last_anchor_time == old_datum.last_anchor_time && new_datum.anchor_count == old_datum.anchor_count && new_datum.last_record_hash == old_datum.last_record_hash
      operator_updated && rest_unchanged
    }
    None -> False
  }
}

// ── Validator ─────────────────────────────────────────────────────────────────

validator audit_anchor {
  spend(
    datum_opt: Option<AnchorDatum>,
    redeemer: AnchorAction,
    _own_ref: OutputReference,
    tx: Transaction,
  ) {
    when datum_opt is {
      Some(datum) -> {
        let current_time = get_current_time(tx)
        let operator_signed = list.has(tx.extra_signatories, datum.operator)

        when redeemer is {
          AnchorAction.Anchor { record } -> {
            let valid_merkle_root = record.merkle_root != #""
            let valid_time_window =
              record.batch_start > 0 && record.batch_end > record.batch_start
            let valid_tx_count = record.tx_count > 0
            // Chain integrity: prev_record_hash must match the stored last hash
            let chain_linked = record.prev_record_hash == datum.last_record_hash
            // Batch end must not exceed the tx validity lower bound
            let not_future =
              if current_time > 0 {
                record.batch_end <= current_time
              } else {
                True
              }
            if !operator_signed || !valid_merkle_root || !valid_time_window || !valid_tx_count || !chain_linked || !not_future {
              False
            } else {
              verify_anchor_output(tx.outputs, datum, record)
            }
          }

          AnchorAction.RotateOperator { new_operator } -> {
            let valid_new_operator =
              new_operator != #"" && new_operator != datum.operator
            if !operator_signed || !valid_new_operator {
              False
            } else {
              verify_rotate_output(tx.outputs, datum, new_operator)
            }
          }
        }
      }
      // The initial UTxO is seeded by the platform; spend always requires a datum
      None -> False
    }
  }

  else(_) {
    False
  }
}
