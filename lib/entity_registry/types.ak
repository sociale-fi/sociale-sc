// lib/entity_registry/types.ak

use aiken/crypto.{VerificationKeyHash}

/// Lifecycle status of a cooperative member
pub type MemberStatus {
  Active
  Inactive
  Suspended
}

/// Cooperative entity metadata
pub type Entity {
  name: ByteArray,
  description: ByteArray,
  /// POSIX timestamp (ms) when the cooperative was created on-chain
  creation_time: Int,
  founder: VerificationKeyHash,
  member_count: Int,
}

/// Cooperative member record
pub type Member {
  name: ByteArray,
  verification_key_hash: VerificationKeyHash,
  /// POSIX timestamp (ms) when the member joined
  join_time: Int,
  /// Token name of this member's identity NFT
  nft_token_name: ByteArray,
  status: MemberStatus,
  /// Optional KERI Autonomic Identifier — links on-chain identity to the KERI identity layer
  keri_aid: Option<ByteArray>,
}

/// On-chain state for a cooperative entity.
/// Each cooperative is a separate UTxO at the entity registry script address.
pub type RegistryDatum {
  entity: Entity,
  members: List<Member>,
  /// Ordered list of authorised administrator verification key hashes
  admins: List<VerificationKeyHash>,
}

/// Redeemer actions for the entity registry validator
pub type RegistryAction {
  CreateEntity { name: ByteArray, description: ByteArray }
  AddMember { member: Member }
  UpdateMemberStatus { vkh: VerificationKeyHash, new_status: MemberStatus }
  AddAdmin { vkh: VerificationKeyHash }
  RemoveAdmin { vkh: VerificationKeyHash }
}
