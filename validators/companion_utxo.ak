use aiken/collection/list.{any, head, length, filter, push, has}
use aiken/collection/dict.{get, keys}
use cardano/address.{PaymentCredential, VerificationKey}
use cardano/assets.{to_dict, PolicyId, AssetName}
use cardano/script_context.{ScriptContext}
use cardano/transaction.{Datum}
use aiken/transaction.{InlineDatum}

// Companion metadata validator with transfer, burn, bonding (via NFT or affection), cosmetics, and unbonding

pub type CompanionDatum {
  version:         Int,
  policy_id:       PolicyId,
  ownership_log:   List<PaymentCredential>,
  dna_hash:        AssetName,
  affection_score: Int,
  trust_threshold: Int,
  bonded:          Bool,
  ipfs_hash:       ByteArray
}

pub type CompanionRedeemer {
  Transfer(PaymentCredential)
  Burn
  BondingRitual(ByteArray)
  CosmeticUpgrade(ByteArray, Int)
  Event(ByteArray, Int)
  Unbonding(ByteArray)
}

fn max_affection() -> Int { 100 }
fn min_affection() -> Int { 0 }
fn max_cosmetics_per_tx() -> Int { 4 }

fn cosmetic_policy_id() -> PolicyId {
  #"3217a73bb393fd45e3d5aafa386d16e314637fcd8feea94839218177"
}

fn current_owner(log: List<PaymentCredential>) -> Option<PaymentCredential> {
  head(log)
}

fn signed_by(owner: PaymentCredential, ctx: ScriptContext) -> Bool {
  when owner is {
    VerificationKey(pkh) -> any(ctx.transaction.extra_signatories, fn(x) { x == pkh })
    _ -> False
  }
}

fn as_companion_datum(datum: Datum) -> Option<CompanionDatum> {
  when datum is {
    InlineDatum(d) -> CompanionDatum::deserialize(d)
    _ -> None
  }
}

fn collect_cosmetic_step(inputs, seen) -> List<AssetName> {
  when inputs is {
    [] -> seen
    [x, ..rest] -> {
      let m = to_dict(x.output.value)
      let names = when get(m, cosmetic_policy_id()) is {
        Some(inner) -> keys(inner)
        _ -> []
      }
      let updated = filter(names, fn(n) { !has(seen, n) })
      let next_seen = add_all(updated, seen)
      collect_cosmetic_step(rest, next_seen)
    }
  }
}

fn add_all(xs: List<AssetName>, acc: List<AssetName>) -> List<AssetName> {
  when xs is {
    [] -> acc
    [x, ..rest] -> add_all(rest, push(x, acc))
  }
}

fn collect_unique_cosmetic_items(inputs) -> List<AssetName> {
  collect_cosmetic_step(inputs, [])
}

validator companion_metadata {
  spend(
    datum: Option<CompanionDatum>,
    redeemer: CompanionRedeemer,
    ctx: ScriptContext,
    _purpose
  ) -> Bool {
    let companion_outputs = filter(ctx.transaction.outputs, fn(o) {
      when as_companion_datum(o.datum) is {
        Some(_) -> True
        _ -> False
      }
    })

    when datum is {
      Some(d) -> {
        when current_owner(d.ownership_log) is {
          Some(ownerCred) -> {
            if !signed_by(ownerCred, ctx) {
              fail
            } else {
              when redeemer is {
                Transfer(newOwner) -> {
                  if d.bonded {
                    fail
                  } else {
                    when newOwner is {
                      VerificationKey(npkh) -> when ownerCred is {
                        VerificationKey(opkh) -> {
                          if npkh == opkh {
                            fail
                          } else {
                            let consumed = any(ctx.transaction.inputs, fn(i) {
                              let m = to_dict(i.output.value)
                              when get(m, d.policy_id) is {
                                Some(inner) -> when get(inner, d.dna_hash) is { Some(q) -> q >= 1 _ -> False }
                                _ -> False
                              }
                            })
                            if consumed { True } else { fail }
                          }
                        } _ -> fail
                      } _ -> fail
                    }
                  }
                }

                Burn -> {
                  let consumed = any(ctx.transaction.inputs, fn(i) {
                    let m = to_dict(i.output.value)
                    when get(m, d.policy_id) is {
                      Some(inner) -> when get(inner, d.dna_hash) is { Some(q) -> q >= 1 _ -> False }
                      _ -> False
                    }
                  })
                  if consumed { True } else { fail }
                }

                BondingRitual(_) -> {
                  if d.bonded || length(companion_outputs) != 1 {
                    fail
                  } else {
                    let nft_consumed = any(ctx.transaction.inputs, fn(i) {
                      let m = to_dict(i.output.value)
                      when get(m, d.policy_id) is {
                        Some(inner) -> when get(inner, d.dna_hash) is { Some(q) -> q >= 1 _ -> False }
                        _ -> False
                      }
                    })
                    let affection_ok = d.affection_score >= d.trust_threshold
                    let output_bonded = any(companion_outputs, fn(o) {
                      when as_companion_datum(o.datum) is {
                        Some(newDatum) -> newDatum.bonded == True
                        _ -> False
                      }
                    })
                    if (nft_consumed || affection_ok) && output_bonded {
                      True
                    } else {
                      fail
                    }
                  }
                }

                CosmeticUpgrade(item, modifier) -> {
                  let unique_items = collect_unique_cosmetic_items(ctx.transaction.inputs)
                  if length(unique_items) > max_cosmetics_per_tx() {
                    fail
                  } else {
                    let consumed = any(ctx.transaction.inputs, fn(i) {
                      let m = to_dict(i.output.value)
                      when get(m, cosmetic_policy_id()) is {
                        Some(inner) -> when get(inner, item) is { Some(q) -> q >= 1 _ -> False }
                        _ -> False
                      }
                    })
                    let affection_updated = any(companion_outputs, fn(o) {
                      when as_companion_datum(o.datum) is {
                        Some(newDatum) -> {
                          let next_score = d.affection_score + modifier
                          let capped = if next_score > max_affection() {
                            max_affection()
                          } else if next_score < min_affection() {
                            min_affection()
                          } else {
                            next_score
                          }
                          newDatum.affection_score == capped
                        }
                        _ -> False
                      }
                    })
                    if consumed && affection_updated { True } else { fail }
                  }
                }

                Event(event_id, modifier) -> {
                  if length(companion_outputs) != 1 {
                    fail
                  } else {
                    let consumed = any(ctx.transaction.inputs, fn(i) {
                      let m = to_dict(i.output.value)
                      when get(m, d.policy_id) is {
                        Some(inner) -> when get(inner, event_id) is { Some(q) -> q >= 1 _ -> False }
                        _ -> False
                      }
                    })
                    let affection_updated = any(companion_outputs, fn(o) {
                      when as_companion_datum(o.datum) is {
                        Some(newDatum) -> {
                          let next_score = d.affection_score + modifier
                          let capped = if next_score > max_affection() {
                            max_affection()
                          } else if next_score < min_affection() {
                            min_affection()
                          } else {
                            next_score
                          }
                          newDatum.affection_score == capped
                        }
                        _ -> False
                      }
                    })
                    if consumed && affection_updated { True } else { fail }
                  }
                }

                Unbonding(_) -> {
                  if !d.bonded || length(companion_outputs) != 1 {
                    fail
                  } else {
                    let output_unbonded = any(companion_outputs, fn(o) {
                      when as_companion_datum(o.datum) is {
                        Some(newDatum) -> newDatum.bonded == False
                        _ -> False
                      }
                    })
                    if output_unbonded { True } else { fail }
                  }
                }
              }
            }
          }
          _ -> fail
        }
      }
      _ -> fail
    }
  }
}
