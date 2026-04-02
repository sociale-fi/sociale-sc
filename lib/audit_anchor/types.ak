// lib/audit_anchor/types.ak
// Types for the Audit Anchor validator — Phase A: Verifiable Ledger
//
// The audit anchor provides cryptographic proof that a cooperative's transaction
// records have not been altered. Transaction batches are hashed (Merkle root)
// and periodically anchored on-chain by the Sociale platform operator.
//
// Each cooperative has one UTxO at the audit anchor script address. Anchors
// form a chain via prev_record_hash, making gaps in the history detectable.

/// On-chain state stored at the audit anchor script address.
/// One UTxO per cooperative, identified by cooperative_id.
pub type AnchorDatum {
  /// Sociale platform key authorised to submit anchors for this cooperative
  operator: ByteArray,
  /// Cooperative identifier — matches the platform's internal tenant record
  cooperative_id: ByteArray,
  /// POSIX timestamp (milliseconds) of the most recent anchor submission
  last_anchor_time: Int,
  /// Cumulative count of anchor submissions — aids off-chain chain validation
  anchor_count: Int,
  /// Hash of the most recent AnchorRecord, chaining the anchor history
  last_record_hash: ByteArray,
}

/// An individual anchor record, supplied in the redeemer when submitting a batch.
pub type AnchorRecord {
  /// SHA-256 Merkle root of the transaction batch
  merkle_root: ByteArray,
  /// Start of the batch window — POSIX milliseconds, inclusive
  batch_start: Int,
  /// End of the batch window — POSIX milliseconds, inclusive
  batch_end: Int,
  /// Number of transactions included in this batch
  tx_count: Int,
  /// Hash of the previous AnchorRecord — links the chain for gap detection
  prev_record_hash: ByteArray,
}

/// Redeemer actions for the audit anchor validator
pub type AnchorAction {
  /// Submit a new Merkle root anchor for a cooperative's transaction batch
  Anchor { record: AnchorRecord }
  /// Transfer operator authority to a new key (e.g. key rotation)
  RotateOperator { new_operator: ByteArray }
}
