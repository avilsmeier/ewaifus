use aiken/collection/dict
use cardano/assets.{AssetName, PolicyId, to_dict}
use cardano/script_context.{ScriptContext}

// Redeemer carries the dna_hash (asset name) to mint or burn
pub type PolicyRedeemer {
  Mint(AssetName)
  Burn(AssetName)
}

validator mint_companion {
  mint(redeemer: PolicyRedeemer, ctx: ScriptContext, self: PolicyId) {
    when redeemer is {
      Mint(dna_hash) -> {
        let m = to_dict(ctx.transaction.mint)
        when dict.get(m, self) is {
          Some(inner) ->
            when dict.get(inner, dna_hash) is {
              Some(qty) -> qty == 1
              _ -> False
            }
          _ -> False
        }
      }
      Burn(dna_hash) -> {
        let m = to_dict(ctx.transaction.mint)
        when dict.get(m, self) is {
          Some(inner) ->
            when dict.get(inner, dna_hash) is {
              Some(qty) -> qty < 0
              _ -> False
            }
          _ -> True
        }
      }
    }
    // burn is allowed if asset is not being minted at all
  }

  else(_) {
    fail
  }
}
