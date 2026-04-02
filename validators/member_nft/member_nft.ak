// validators/member_nft/member_nft.ak
// Member NFT minting policy — issues unique identity certificates tied to entity registry operations

use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/assets.{PolicyId}
use cardano/transaction.{Input, OutputReference, Transaction}
use member_nft/types.{MembershipLevel, MintAction}

/// Verify the entity registry UTxO is being spent in the same transaction.
/// Enforces atomic member registration + NFT minting.
fn verify_entity_registry_spent(
  inputs: List<Input>,
  entity_registry_ref: OutputReference,
) -> Bool {
  list.any(inputs, fn(input) { input.output_reference == entity_registry_ref })
}

/// Token name for a member NFT is the member's verification key hash.
fn generate_nft_token_name(member_hash: VerificationKeyHash) -> ByteArray {
  member_hash
}

fn validate_membership_level(level: MembershipLevel) -> Bool {
  when level is {
    MembershipLevel.Standard -> True
    MembershipLevel.Premium -> True
    MembershipLevel.Admin -> True
    MembershipLevel.Founder -> True
  }
}

/// Member NFT minting policy.
///
/// Parameterised by the entity registry UTxO reference so minting is only
/// valid in the same transaction that modifies the cooperative's registry state.
validator member_nft_policy(entity_registry_ref: OutputReference) {
  mint(redeemer: MintAction, policy_id: PolicyId, transaction: Transaction) {
    let Transaction { inputs, mint, .. } = transaction

    expect [Pair(asset_name, quantity)] =
      mint
        |> assets.tokens(policy_id)
        |> dict.to_pairs()

    when redeemer is {
      MintAction.MintMember { member_hash, entity_name, membership_level } -> {
        let expected_token_name = generate_nft_token_name(member_hash)

        let entity_spent =
          verify_entity_registry_spent(inputs, entity_registry_ref)
        let single_mint = quantity == 1
        let correct_token_name = asset_name == expected_token_name
        let valid_level = validate_membership_level(membership_level)
        let valid_entity = entity_name != #""

        entity_spent && single_mint && correct_token_name && valid_level && valid_entity
      }

      MintAction.BurnMember { member_hash } -> {
        let expected_token_name = generate_nft_token_name(member_hash)
        quantity == -1 && asset_name == expected_token_name
      }
    }
  }

  else(_) {
    False
  }
}
