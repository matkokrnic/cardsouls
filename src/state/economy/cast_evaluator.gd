class_name CastEvaluator
extends RefCounted

## D6 pure evaluator (story 3-5a, AC 3) — THE one place CardCastConditions are read. A SIBLING
## of EconomyEvaluator, not a second block inside it: that file's own header declares it "THE
## one place ResourceGenerationRules are read", a GENERATION-side identity that a cost-gating
## read would contradict if folded in. Costs and faucets are opposite directions through the
## same pools, and each gets one file.
##
## Fully STATIC and stateless, exactly like its sibling: there is no instance to hold a
## reference in, so CONSTRAINT C (never cache `balance` / `balance_ticks`) holds BY
## CONSTRUCTION. Nothing is retained between calls.
##
## PURE means it COMPUTES, it does not APPLY. `refusal_reason()` returns a StringName and
## touches NO pool — the mana spend happens in MatchState.advance()'s ordered dispatch, through
## ManaPool.spend(), so the mutation stays where every other mutation lives (D2). This is the
## contract CardCastCondition's header already bound this story to, inherited from the 3-2 gate
## and not re-litigated here.
##
## NO CARD LIBRARY REACHES THIS FILE. It never names CardDatabase, CARDS_DIR or data/cards —
## the cast condition arrives as an ARGUMENT, resolved by MatchState from the one-shot injected
## map (AC 4). Both architecture guards in test_architecture_invariants.gd scan src/state/ and
## cover this file for free.

## Refusal vocabulary. Named as constants rather than repeated StringName literals so a typo at
## a call site fails to compile-match instead of silently producing an unrecognised reason —
## the EconomyEvaluator.SOURCE_* precedent.
##
## EMPTY MEANS ALLOWED. The convention is deliberate: a refusal always carries a reason, so
## `if reason != &""` is the whole gate and there is no second boolean to disagree with it.
const ALLOWED := &""
const REASON_EMPTY_SLOT := &"empty_slot"
const REASON_UNKNOWN_CARD := &"unknown_card"
const REASON_FLAG_CLOSED := &"flag_closed"
const REASON_INSUFFICIENT_MANA := &"insufficient_mana"
const REASON_INSUFFICIENT_ORBS := &"insufficient_orbs"


## Why this cast is refused, or ALLOWED (&"") if it may proceed. `condition` is the injected
## per-card cost; `mana_current` and `orbs` are the casting player's LIVE readings, passed in
## and dereferenced within this call.
##
## A NULL condition reads as REASON_UNKNOWN_CARD rather than crashing. This branch is
## UNREACHABLE BY CONSTRUCTION in shipped play — MatchState.inject_card_costs validates at
## injection time that every id in the injected composition has an entry (AC 4), and a hand can
## only ever hold ids that came from that composition — which is exactly why AC 4 chose a seam
## check over a crash guard here. It is kept as a total function's honest default, not as a
## live path, and it is declared NOT mutation-proven for that reason.
static func refusal_reason(condition: CardCastCondition, mana_current: float,
		orbs: OrbPool, flags: FeatureFlags) -> StringName:
	if condition == null:
		return REASON_UNKNOWN_CARD
	var reason := flag_and_mana_refusal_reason(condition, mana_current, flags)
	if reason != ALLOWED:
		return reason
	if not _orbs_affordable(condition, orbs, flags):
		return REASON_INSUFFICIENT_ORBS
	return ALLOWED


## Story 6-2 (AC 4): the FIRST TWO CHECKS of `refusal_reason` directly above, as their own entry
## point -- the flag gate, then the mana price, in that fixed order, and NOTHING about orbs.
##
## A NEW ENTRY POINT, NOT A SKIP PARAMETER AND NOT A TOLERATE-AND-DISCARD CALLER (the dev-pass choice
## AC 4 left open). Pitch STAGING must not be gated on orbs -- the orb price is evaluated
## continuously afterwards as READY -- and each rejected shape had a real cost: a `skip_orbs` bool
## would give Mode ①'s single production call a second behaviour to get wrong, and a staging caller
## that discarded `REASON_INSUFFICIENT_ORBS` would stay correct only while the orb check remained the
## LAST check in `refusal_reason`. Here the order is shared BY CONSTRUCTION instead: `refusal_reason`
## calls this, so the two paths cannot disagree about the flag or the mana half.
##
## NON-NULL `condition` IS THE CALLER'S OBLIGATION. `refusal_reason` handles null before calling in;
## the staging seat refuses a missing pitch entry with its OWN reason before calling in (AC 5), so
## `REASON_UNKNOWN_CARD`'s "unreachable by construction" contract above is not weakened by this path.
static func flag_and_mana_refusal_reason(condition: CardCastCondition, mana_current: float,
		flags: FeatureFlags) -> StringName:
	if not _flag_open(condition, flags):
		return REASON_FLAG_CLOSED
	if condition.mana_cost > mana_current:
		return REASON_INSUFFICIENT_MANA
	return ALLOWED


## AC 3's flag scope, evaluated as DATA — EconomyEvaluator._flag_open's twin, same reading in
## the same direction: an ungated condition is always open; a gated one needs an injected
## FeatureFlags whose named property is a true bool. No flags injected, or a flag name that
## does not exist on the resource, reads as CLOSED (graceful degradation — a cast that cannot
## be verified open stays shut).
static func _flag_open(condition: CardCastCondition, flags: FeatureFlags) -> bool:
	if condition.required_flag == &"":
		return true
	if flags == null:
		return false
	var value: Variant = flags.get(condition.required_flag)
	return value is bool and value


## GRACEFUL DEGRADATION, the project-context HARD RULE spelled out: ORBS OFF -> MANA-ONLY CAST.
## With the orbs layer off (its E5 default) an authored orb cost is IGNORED rather than treated
## as unpayable, so a card that carries one is still castable for its mana price. The opposite
## reading — orb costs unpayable while the layer is off — would make such a card permanently
## dead instead of degrading, which is the direction the rule exists to forbid.
##
## Every authored card ships an EMPTY orb_costs today (mode ① is mana-only per GDD §D), so this
## is currently a no-op on real content; it is written against the flag rather than against the
## emptiness so that turning the E5 flag on is a data change and not a code change.
##
## ITERATION ORDER IS SORTED EXPLICITLY. CardCastCondition's header states that its
## orb_costs iteration order is NEVER a contract; a refusal REASON that depended on which
## short colour was visited first would quietly make it one. Sorting the keys — plain
## Enums.CardColor INTS, never StringNames — keeps the returned reason a deterministic
## function of the cost alone. (Sorting StringName keys is the measured hazard this repo
## avoids everywhere: Array[StringName].sort() orders by internal POINTER on this engine.)
static func _orbs_affordable(condition: CardCastCondition, orbs: OrbPool,
		flags: FeatureFlags) -> bool:
	return orb_costs_affordable(condition.orb_costs, orbs, flags)


## Story 6-2 (AC 10): the body of `_orbs_affordable` directly above, over a bare orb price rather than
## a whole condition, and PUBLIC -- because the pitch zone's READY check asks exactly this question
## about the price it copied at staging, and a second copy of the sorted-colour loop would be a second
## place the iteration-order discipline could drift. `_orbs_affordable` forwards here, so Mode ①'s
## refusal and a staged card's READY are one reading of one rule.
static func orb_costs_affordable(orb_costs: Dictionary, orbs: OrbPool,
		flags: FeatureFlags) -> bool:
	if orb_costs.is_empty():
		return true
	if flags == null or not flags.orbs:
		return true
	if orbs == null:
		return false
	for color: Enums.CardColor in sorted_orb_colors(orb_costs):
		if orbs.get_count(color) < int(orb_costs[color]):
			return false
	return true


## Story 7-4 (AC 6/AC 9, `7-4/R14`): `orb_costs_affordable` directly above, over a bare per-colour COUNT
## dictionary (`Enums.CardColor` -> int) instead of an `OrbPool` -- the question a SORCERY asks of the
## orbs earned since it was staged (`PitchState._fresh_orbs`). Same degrade rule (an empty price, or the
## orbs layer off, reads covered) and the same `sorted_orb_colors` walk, so the iteration order still
## lives in one place. A colour the price does not name is never visited, so it can never count; a
## colour missing from `counts` reads 0.
static func orb_costs_covered_by(orb_costs: Dictionary, counts: Dictionary,
		flags: FeatureFlags) -> bool:
	if orb_costs.is_empty():
		return true
	if flags == null or not flags.orbs:
		return true
	for color: Enums.CardColor in sorted_orb_colors(orb_costs):
		if int(counts.get(color, 0)) < int(orb_costs[color]):
			return false
	return true


## Story 6-3a (AC 7): the ORDERING half of the loop directly above, extracted -- the ONE place the
## sort-the-colour-keys decision lives (plain `Enums.CardColor` ints, never StringNames; see
## `_orbs_affordable`'s note). TWO consumers, not one shared loop: the READ loop above, and the WRITE
## loop in `MatchState._resolve_pitch_activate` that spends the price. The spend stays in MatchState
## because this file COMPUTES and never APPLIES (the header).
static func sorted_orb_colors(orb_costs: Dictionary) -> Array:
	var colors: Array = orb_costs.keys()
	colors.sort()
	return colors
