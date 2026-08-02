class_name ResourceGenerationRule
extends Resource

## D6 data vocabulary (story 3-4, AC 1): ONE authored resource faucet. A rule says WHAT
## generates WHICH resource and WHERE the amount is read from; it never carries the amount
## itself. Pure schema — no logic lives here (src/state/resources/ is the "Resource SCHEMA
## classes (.gd) — pure data vocabulary" tier); EconomyEvaluator is the one place rules are
## read and applied.
##
## WHY the amount is a FIELD NAME and not a float (the departure from Novel Pattern 5's
## sketch, which exports `amount: float`): every gameplay number in this project lives in
## BalanceConfig, hot-reloadable through the X3 seam, and CONSTRAINT C requires it to be read
## INLINE at the moment of use. A float baked into a rule `.tres` would be a SECOND source of
## truth for tuning, immune to `apply_balance()` — the melee faucet would stop responding to
## the authored `melee_hit_mana`, and the passive faucet could not use the derived
## `mana_regen_per_tick` at all. So the rule names its amount's HOME and the evaluator
## dereferences it against the live balance objects on every call.
##
## Two homes exist because the project already distinguishes them (A1): per-EVENT amounts are
## plain BalanceConfig fields, per-TICK rates are DERIVED ONCE PER LOAD onto BalanceTicks.
## `amount_domain` picks which object `amount_field` is read from.

## Which live balance object `amount_field` names a field on.
enum AmountDomain {
	BALANCE,        ## BalanceConfig — per-EVENT amounts (melee_hit_mana)
	BALANCE_TICKS,  ## BalanceTicks — per-TICK rates derived at load (mana_regen_per_tick)
}

## What fires this rule. The evaluator matches it against the source the caller asks for:
## &"melee_hit" (a confirmed hit, step 5) | &"passive_tick" (every live tick, step 5) |
## &"mana_accelerator" (an E4 totem — a new .tres, no code).
@export var source: StringName = &""

## Which pool receives it. Only &"mana" has a consumer today; the field exists so a stamina
## or orb faucet is a new .tres rather than a new evaluator.
@export var resource: StringName = &""

@export var amount_domain: AmountDomain = AmountDomain.BALANCE

## Field name on the object `amount_domain` selects. An unknown name yields no amount
## (graceful degradation, the FeatureFlags-null precedent) rather than a hard failure.
@export var amount_field: StringName = &""

## OPTIONAL FeatureFlags property name gating this rule. Empty = always active. The flag is
## read off the INJECTED FeatureFlags the evaluator is handed — state never reads
## FeatureFlagsService (HARD RULE), and no flags injected closes every gated rule, exactly
## as the direct melee grant behaved before the evaluator took it over (story 1-5, B3).
## This is what keeps AC 3 honest: the flag scope is DATA on the rule, not a second
## flag-gated code path at the call site.
@export var required_flag: StringName = &""
