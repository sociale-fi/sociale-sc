// lib/member_nft/types.ak
// Member NFT types — unique on-chain identity certificates for cooperative members

use aiken/crypto.{VerificationKeyHash}

/// Membership tier, used as metadata in the NFT and for governance weight
pub type MembershipLevel {
  Standard
  Premium
  Admin
  Founder
}

/// Redeemer actions for the member NFT minting policy
pub type MintAction {
  /// Mint a member identity NFT — must be atomic with an entity registry spend
  MintMember {
    member_hash: VerificationKeyHash,
    entity_name: ByteArray,
    membership_level: MembershipLevel,
  }
  /// Burn a member NFT on member removal
  BurnMember { member_hash: VerificationKeyHash }
}
