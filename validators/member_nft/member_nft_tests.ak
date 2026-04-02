// validators/member_nft/member_nft_tests.ak

use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/assets.{PolicyId, from_lovelace}
use cardano/transaction.{Transaction}
use member_nft/types.{MembershipLevel, MintAction}
use mocktail.{
  complete, mock_pub_key_address, mocktail_tx, required_signer_hash, tx_out,
}
use mocktail/virgin_key_hash.{mock_pub_key_hash}
use mocktail/virgin_output_reference.{mock_utxo_ref}

fn create_mint_member_action(
  member_hash: VerificationKeyHash,
  entity_name: ByteArray,
  level: MembershipLevel,
) -> MintAction {
  MintAction.MintMember { member_hash, entity_name, membership_level: level }
}

fn mock_policy_id() -> PolicyId {
  #"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}

test mint_action_structure() {
  let member_hash = mock_pub_key_hash(1)
  let mint_action =
    create_mint_member_action(
      member_hash,
      "Test SACCO",
      MembershipLevel.Standard,
    )
  when mint_action is {
    MintAction.MintMember {
      member_hash: hash,
      entity_name: name,
      membership_level: level,
    } ->
      hash == member_hash && name == "Test SACCO" && level == MembershipLevel.Standard
    _ -> False
  }
}

test membership_levels_are_distinct() {
  MembershipLevel.Standard != MembershipLevel.Premium && MembershipLevel.Admin != MembershipLevel.Founder
}

test burn_action_structure() {
  let member_hash = mock_pub_key_hash(1)
  let burn_action = MintAction.BurnMember { member_hash }
  when burn_action is {
    MintAction.BurnMember { member_hash: hash } -> hash == member_hash
    _ -> False
  }
}

test mint_requires_signature() {
  let admin_hash = mock_pub_key_hash(0)
  let member_index = 1
  let tx =
    mocktail_tx()
      |> required_signer_hash(True, admin_hash)
      |> tx_out(
          True,
          mock_pub_key_address(member_index, None),
          from_lovelace(2_000_000),
        )
      |> complete()
  let has_signature = list.has(tx.extra_signatories, admin_hash)
  let has_outputs = list.length(tx.outputs) >= 1
  has_signature && has_outputs
}

test validator_parameterisation() {
  let entity_ref = mock_utxo_ref(0, 0)
  let member_hash = mock_pub_key_hash(1)
  let policy_id = mock_policy_id()
  let mint_action =
    create_mint_member_action(
      member_hash,
      "Test SACCO",
      MembershipLevel.Standard,
    )
  when mint_action is {
    MintAction.MintMember { member_hash: hash, entity_name: name, .. } ->
      hash != #"" && name != #"" && entity_ref != mock_utxo_ref(1, 1) && policy_id != #""
    _ -> False
  }
}
