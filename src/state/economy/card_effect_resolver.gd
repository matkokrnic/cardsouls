class_name CardEffectResolver
extends RefCounted

## D6 pure evaluator (story 4-1, AC 1) — THE one place `CardEffect.effect_id` strings are
## matched against gameplay meaning. `effect_id` has been authored on all nine fixture cards
## since 3-2 and read by NOTHING until this file; card_effect.gd's own header promised "the
## resolver that turns an effect_id into gameplay lands with the card-play story", and this is
## it.
##
## A SIBLING OF CastEvaluator AND EconomyEvaluator, NOT A BRANCH INSIDE EITHER. Each of those
## files opens by declaring itself "THE one place" its kind of data is read — ResourceGeneration
## Rules for one, CardCastConditions for the other — and a card-EFFECT read folded into either
## would contradict that identity. Costs, faucets and effects are three different questions asked
## of three different resources, and each gets one file.
##
## Fully STATIC and stateless, exactly like both siblings: there is no instance to hold a
## reference in, so CONSTRAINT C (never cache `balance` / `balance_ticks` / an injected value)
## holds BY CONSTRUCTION. Nothing is retained between calls.
##
## PURE means it COMPUTES, it does not APPLY (D6). `outcome()` returns a StringName and touches
## NO board, NO pool and NO container — appending the unit record happens in
## MatchState.advance()'s ordered dispatch, through UnitBoard.add(), so the mutation stays where
## every other mutation lives (D2).
##
## NO CARD LIBRARY REACHES THIS FILE. It never names CardDatabase, CARDS_DIR or data/cards — the
## effect arrives as an ARGUMENT, resolved by MatchState from the one-shot injected map (AC 2).
## Both architecture guards in test_architecture_invariants.gd scan src/state/ and cover this
## file for free.
##
## THE VERDICT IS A RETURNED VALUE AND NOTHING ELSE (`4-1/R3`, `4-1/R10`). No branch here or at
## the call site reaches HeroState.reject_action: every outcome below is a SUCCESSFUL cast —
## CastEvaluator has already allowed it, the mana is spent and the card is discarded — so
## rendering any of them as a player-facing refusal would be a lie about what happened. The
## reasons are asserted in unit tests, which is the whole of their contract.

## The recognized `effect_id` PREFIXES, and the entire vocabulary this story understands. The
## nine authored ids are exactly six `summon_*` and three `spell_*`; test_card_authoring.gd
## asserts that every authored id carries one of these two prefixes, which is the machine half
## of AC 3's golden-discipline ruling (`4-1/R4`).
##
## Matched as a PREFIX, never as a whole-id table: the six summon ids differ (`summon_imp`,
## `summon_combat_totem`, ...) and this story treats every one of them IDENTICALLY (the ratified
## totem clause). A whole-id table would be the place `4-4`'s totem/minion split has to land, and
## writing it now would pre-commit that shape.
const PREFIX_SUMMON := "summon_"
const PREFIX_SPELL := "spell_"

## FOUR NAMED OUTCOMES, EXACTLY ONE OF WHICH MUTATES THE BOARD. Named as constants rather than
## repeated StringName literals so a typo at a call site fails to compile-match instead of
## silently producing an unrecognised verdict — the CastEvaluator.REASON_* /
## EconomyEvaluator.SOURCE_* precedent.
##
## DELIBERATELY NOT CastEvaluator's `ALLOWED := &""` CONVENTION, and the divergence is the point.
## There, EMPTY MEANS ALLOWED works because the question is binary — a cast either proceeds or
## carries a reason. Here there is no such binary: three of the four outcomes are non-mutating and
## all three are successful casts, so an empty "success" value would have to stand for one of them
## and read as failure for the other two. Every outcome is named.
const OUTCOME_SUMMON := &"summon"

## AC 5, `E4-P/R10`: a `spell_*` id is a NAMED NO-OP, never a rejection. The cast has already
## passed CastEvaluator; mana is spent and the card discarded exactly as today. `bramble_snare`,
## `frost_dart` and `ember_lash` are the three fixture cards that land here. Real spell resolution
## acquires an owner at the E4 close-out at the latest — this is not a partial implementation of
## any spell's actual effect, which is why the reason says NOT YET rather than NOTHING.
const REASON_SPELL_NOT_YET_RESOLVED := &"spell_not_yet_resolved"

## AC 6(i), the MISSING-ENTRY HONEST DEFAULT — no injected effect entry for the cast id. The
## `CastEvaluator.refusal_reason` null-branch precedent verbatim, including its rationale: a total
## function's honest default rather than a crash. UNLIKE that branch it IS naturally reachable and
## IS mutation-proven, because injection is state-side OPTIONAL by ruling (`4-1/R3`) — every
## existing MatchState-building fixture in the suite injects a deck and costs but no effects, and
## every cast in those fixtures lands here.
const REASON_NO_EFFECT_ENTRY := &"no_effect_entry"

## AC 6(ii), the UNKNOWN-PREFIX REFUSAL — an entry exists but its `effect_id` is neither
## `summon_*` nor `spell_*`. NO FIXTURE CARD PRODUCES THIS TODAY (the nine authored ids are
## exactly six and three, confirmed by reading every data/cards/*.tres, and test_card_authoring.gd
## now fails if a tenth arrives with a third prefix), so it is proven with a SYNTHETIC map entry
## in a unit test and is declared NOT naturally reachable — never a claim of live reachability.
const REASON_UNKNOWN_EFFECT_PREFIX := &"unknown_effect_prefix"

## The project-context HARD RULE on feature flags, made concrete for the E4 minion layer:
## `FeatureFlags.minions` is one of the seven named toggleable layers, so summon resolution
## CHECKS it and DEGRADES GRACEFULLY when it is off. Degrading gracefully here means the cast
## still resolves exactly as it does today — mana spent, card discarded, replacement owed — and
## no unit reaches the board, which is precisely the `spell_*` branch's shape. It gets its OWN
## name rather than reusing REASON_SPELL_NOT_YET_RESOLVED because "the layer is switched off" and
## "this effect has no owner yet" are different facts about the match.
##
## The story left flag-gating as "an implementation choice against the project-context HARD RULE,
## not decided here" (Dev Notes). The HARD RULE decides it: "NEVER hardcode a gameplay layer on.
## Any of {..., minions, totems, ...} must check the injected FeatureFlags resource and degrade
## gracefully when off." The authored data/feature_flags.tres turns `minions` ON with this story,
## which is the rule working as intended — toggling the layer is a checkbox, not a code edit.
const REASON_MINIONS_FLAG_CLOSED := &"minions_flag_closed"


## What this cast's effect does, as one of the four named outcomes above. `effect` is the injected
## per-card CardEffect for the id just cast — null when no entry was injected for it; `flags` is
## the injected FeatureFlags, dereferenced within this call and never retained.
##
## ORDER IS LOAD-BEARING between the last two branches: the flag is consulted only AFTER the id
## has been recognised as a summon, so an UNKNOWN prefix reports itself as unknown whether the
## minion layer is on or off. Reading the flag first would make an authoring error invisible
## behind a switch.
static func outcome(effect: CardEffect, flags: FeatureFlags) -> StringName:
	if effect == null:
		return REASON_NO_EFFECT_ENTRY
	var id := String(effect.effect_id)
	if id.begins_with(PREFIX_SUMMON):
		return OUTCOME_SUMMON if _minions_open(flags) else REASON_MINIONS_FLAG_CLOSED
	if id.begins_with(PREFIX_SPELL):
		return REASON_SPELL_NOT_YET_RESOLVED
	return REASON_UNKNOWN_EFFECT_PREFIX


## NO FLAGS INJECTED READS AS CLOSED — CastEvaluator._flag_open's own reading, in the same
## direction and for the same reason: a layer that cannot be verified open stays shut. Every
## MatchState in the shipped path is handed flags at match start; a fixture that injects none is
## exercising a state that live play cannot reach, and it gets the safe answer.
static func _minions_open(flags: FeatureFlags) -> bool:
	return flags != null and flags.minions
