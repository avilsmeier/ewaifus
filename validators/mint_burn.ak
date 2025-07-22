use cardano/script_context.{ScriptContext}
use cardano/address.{PaymentCredential, VerificationKey}
use aiken/collection/list


// Type alias for clarity
type OwnerLog = List<PaymentCredential>

// Redeemer determines if this is a mint or a burn action
pub type Redeemer {
  Mint
  Burn
}

// Datum containing dna_hash and full ownership log
pub type CompanionDatum {
  ownership_log: OwnerLog,
  dna_hash: ByteArray
}

fn current_owner(log: OwnerLog) -> Option<PaymentCredential> {
  list.last(log)
}

fn validate_mint(ctx: ScriptContext, datum: CompanionDatum) -> Bool {
  when current_owner(datum.ownership_log) is {
    Some(VerificationKey(owner)) -> 
      list.length(datum.ownership_log) == 1 && list.has(ctx.transaction.extra_signatories, owner)
    _ -> False
  }
}

fn validate_burn(ctx: ScriptContext, datum: CompanionDatum) -> Bool {
  when current_owner(datum.ownership_log) is {
    Some(VerificationKey(owner)) -> 
      list.has(ctx.transaction.extra_signatories, owner)
    _ -> False
  }
}


// Entry point
validator main {
  mint(
    datum: CompanionDatum,
    redeemer: Redeemer,
    context: ScriptContext,
  ) {
    when redeemer is {
      Mint -> validate_mint(context, datum)
      Burn -> validate_burn(context, datum)
    }
  }
}