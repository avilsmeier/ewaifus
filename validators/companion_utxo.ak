use aiken/collection/dict.{Dict, get}
use aiken/collection/list.{any, filter_map, head}
use cardano/address.{PaymentCredential, VerificationKey}
use cardano/assets.{AssetName, PolicyId, to_dict}
use cardano/script_context.{ScriptContext}
use cardano/transaction.{InlineDatum, Input, find_datum, DatumHash}

// Companion metadata validator with transfer, burn, bonding, cosmetic, and unbonding

pub type CompanionDatum {
  version: Int,
  policy_id: PolicyId,
  ownership_log: List<PaymentCredential>,
  dna_hash: AssetName,
  dna_ipfs: ByteArray,
  cosmetics: List<ByteArray>,
  bonded: Bool,
  affection_score: Int,
  trust_threshold: Int,
}

pub type CompanionRedeemer {
  Transfer(PaymentCredential)
  Burn
  BondingRitual(ByteArray)
  CosmeticUpgrade(ByteArray)
  Unbonding(ByteArray)
}

pub type ModifierMap =
  Dict<AssetName, Int>

// Return the most recent owner
fn current_owner(log: List<PaymentCredential>) -> Option<PaymentCredential> {
  head(log)
}

// Check that the given credential signed the tx
fn signed_by(owner: PaymentCredential, ctx: ScriptContext) -> Bool {
  when owner is {
    VerificationKey(pkh) ->
      any(ctx.transaction.extra_signatories, fn(x) { x == pkh })
    _ -> False
  }
}

// Check if a specific asset under a policy ID was consumed from inputs
fn asset_consumed(
  ctx: ScriptContext,
  policy: PolicyId,
  asset: AssetName,
) -> Bool {
  any(
    ctx.transaction.inputs,
    fn(i) {
      let m = to_dict(i.output.value)
      when get(m, policy) is {
        Some(inner) ->
          when get(inner, asset) is {
            Some(q) -> q >= 1
            _ -> False
          }
        _ -> False
      }
    },
  )
}

// Ensure transfer is between different verification keys
fn is_valid_transfer(from: PaymentCredential, to: PaymentCredential) -> Bool {
  when from is {
    VerificationKey(a) ->
      when to is {
        VerificationKey(b) -> a != b
        _ -> False
      }
    _ -> False
  }
}

fn lookup_modifier(
  ctx: ScriptContext,
  mod_admin_pid: PolicyId,
  mod_admin_aname: AssetName,
  item: AssetName
) -> Option<Int> {
  head(filter_map(ctx.transaction.reference_inputs, fn(input: Input) {
    let val = to_dict(input.output.value)

    when get(val, mod_admin_pid) is {
      Some(inner) ->
        when get(inner, mod_admin_aname) is {
          Some(_) ->
            when input.output.datum is {
              InlineDatum(data) ->
                // Try casting the inline datum into a Dict<AssetName, Int>
                when data is {
                  map: Dict<AssetName, Int> -> get(map, item)
                  _ -> None
                }
              _ -> None
            }
          _ -> None
        }
      _ -> None
    }
  }))
}




validator companion_metadata {
  spend(
    datum: Option<CompanionDatum>,
    redeemer: CompanionRedeemer,
    ctx: ScriptContext,
    _purpose,
  ) {
    // Must have metadata
    when datum is {
      Some(d) ->
        // Must be signed by current owner
        when current_owner(d.ownership_log) is {
          Some(ownerCred) ->
            if not(signed_by(ownerCred, ctx)) {
              False
            } else {
              // Handle each redeemer
              when redeemer is {
                // Transfer: only if not bonded
                Transfer(newOwner) ->
                  !d.bonded && is_valid_transfer(ownerCred, newOwner) && asset_consumed(
                    ctx,
                    d.policy_id,
                    d.dna_hash,
                  )

                // Burn: consume NFT
                Burn -> asset_consumed(ctx, d.policy_id, d.dna_hash)

                // Bonding: allowed if not bonded AND (NFT consumed OR affection > trust)
                BondingRitual(ritual) ->
                  !d.bonded && (
                    asset_consumed(ctx, d.policy_id, ritual) || d.affection_score >= d.trust_threshold
                  )

                // Cosmetic upgrade: consume cosmetic NFT
                CosmeticUpgrade(item) -> asset_consumed(ctx, d.policy_id, item)

                // Unbonding: only if currently bonded
                Unbonding(_) -> d.bonded
              }
            }
          _ -> False
        }
      _ -> False
    }
  }

  else(_) {
    False
  }
}
