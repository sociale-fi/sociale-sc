// Example: Simple Buyer-Seller Escrow
// Developed alongside competition contracts. Not part of the core cooperative contract suite.

use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use aiken/interval.{Finite, NegativeInfinity, PositiveInfinity}
use cardano/transaction.{OutputReference, Transaction, ValidityRange}

fn is_buyer_signed(tx: Transaction, buyer: VerificationKeyHash) -> Bool {
  list.has(tx.extra_signatories, buyer)
}

fn is_seller_signed(tx: Transaction, seller: VerificationKeyHash) -> Bool {
  list.has(tx.extra_signatories, seller)
}

fn is_deadline_passed(validity_range: ValidityRange, deadline: Int) -> Bool {
  when validity_range.lower_bound.bound_type is {
    Finite(n) -> n > deadline
    NegativeInfinity -> False
    PositiveInfinity -> True
  }
}

pub type EscrowDatum {
  buyer: VerificationKeyHash,
  seller: VerificationKeyHash,
  amount: Int,
  deadline: Int,
}

pub type EscrowRedeemer {
  action: Int,
}

validator escrow {
  spend(
    datum: Option<EscrowDatum>,
    redeemer: EscrowRedeemer,
    _utxo: OutputReference,
    tx: Transaction,
  ) {
    expect Some(EscrowDatum { buyer, seller, deadline, .. }) = datum

    when redeemer.action is {
      // Buyer claims refund after deadline
      0 ->
        is_buyer_signed(tx, buyer) && is_deadline_passed(
          tx.validity_range,
          deadline,
        )
      // Seller claims payment with buyer approval
      1 -> is_seller_signed(tx, seller) && is_buyer_signed(tx, buyer)
      // Buyer releases payment directly
      2 -> is_buyer_signed(tx, buyer)
      _ -> is_buyer_signed(tx, buyer)
    }
  }

  else(_) {
    fail
  }
}
