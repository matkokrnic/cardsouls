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
## STORY 4-4 (AC 1): THE WHOLE-ID TABLE THIS COMMENT NAMED IN ADVANCE NOW EXISTS, directly below.
## The paragraph this replaces read: "Matched as a PREFIX, never as a whole-id table ... A whole-id
## table would be the place `4-4`'s totem/minion split has to land, and writing it now would
## pre-commit that shape." This is 4-4; the shape is chosen here, by the story that has to live with
## it, exactly as that note intended.
##
## THE PREFIXES SURVIVE AND STILL DO THEIR OWN JOB. They classify an id as a summon or a spell — the
## question `outcome()` asks — and `test_card_authoring.gd` still asserts every authored id carries
## one of the two, which is the machine half of `4-1/R4`'s golden-discipline ruling. What the table
## adds is a SECOND, finer question the prefix cannot answer: WHICH kind a summon puts on the board.
## Two questions, two mechanisms, neither replacing the other.
const PREFIX_SUMMON := "summon_"
const PREFIX_SPELL := "spell_"

## AC 1: the `summon_*` id -> UNIT KIND NAME table — the differentiation the ratified TOTEM CLAUSE
## withheld until this story. The three totem fixture cards named in AC 1 (`hellforge_totem` /
## `summon_combat_totem`, `tidal_wardstone` / `summon_mana_accelerator`, `verdant_wardstone` /
## `summon_stamina_accelerator`) each resolve to a DISTINCT kind here, which is what makes them "no
## longer uniform `summon_*` handling indistinguishable from a minion or from one another".
##
## A `Dictionary`, AND ITS ITERATION ORDER DECIDES NOTHING. It is only ever `get()`-ed by a single
## known key — never iterated, never sorted, never hashed — so the standing prohibition on
## Dictionary iteration order and on StringNames reaching a hash is untouched. The VALUE that leaves
## this file is a kind NAME, and `BalanceConfig.kind_index_of()` turns it into the plain int that
## actually crosses into the record and the snapshot.
##
## AN UNMAPPED `summon_*` ID FALLS TO THE MINION KIND, and that is a DELIBERATE default rather than
## an oversight: `summon_imp` and the two other minion fixture ids are not listed, so the shipped
## minion verdict is untouched by this table's arrival and a future minion card needs no edit here.
## Only a kind that DIFFERS earns a row. The failure this cannot hide is the one that matters — a
## row naming a kind `BalanceConfig` does not author reaches `NO_KIND_INDEX` at the cast seat and
## puts NOTHING on the board, loudly, rather than silently summoning a minion.
##
## THE KIND NAMES ARE NAMED CONSTANTS, not literals repeated at the table and again at every reader.
## Story 4-4's accelerator seats (`MatchState._generate_mana`'s third call site and
## `_regen_stamina`) each have to ask "is a live totem of THIS kind on this player's board", and a
## StringName literal at those seats would be a second spelling of a name only this file owns — a
## typo would silently make a faucet permanently dry with nothing failing. This is the same
## constant-vocabulary discipline `CastEvaluator.REASON_*` and `EconomyEvaluator.SOURCE_*` already
## carry, applied to the kind names.
const KIND_MINION := &"minion"
const KIND_COMBAT_TOTEM := &"combat_totem"
const KIND_MANA_ACCELERATOR := &"mana_accelerator"
const KIND_STAMINA_ACCELERATOR := &"stamina_accelerator"
const SUMMON_KINDS: Dictionary[StringName, StringName] = {
	&"summon_combat_totem": KIND_COMBAT_TOTEM,
	&"summon_mana_accelerator": KIND_MANA_ACCELERATOR,
	&"summon_stamina_accelerator": KIND_STAMINA_ACCELERATOR,
}

## AC 1: the three ids above are TOTEMS and gate on `FeatureFlags.totems`; every other `summon_*` id
## is a minion and gates on `FeatureFlags.minions`. Derived from the table rather than listed a
## second time, so the two can never disagree — see `_is_totem()` below.

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

## Story 4-4 (story Dev Notes, the B11(b) correction): the TOTEM twin of the reason directly above.
## Both `minions` and `totems` bools have existed on `FeatureFlags` since 1-5, but only
## `flags.minions` was ever read in `src/` — `flags.totems` was UNREAD, while `epics.md`'s E4 goal
## commits `FeatureFlags: minions, totems`. This story discharges that commitment by giving the
## totem layer its own gate, read the same way `minions` already is.
##
## ITS OWN NAME RATHER THAN A REUSE OF `REASON_MINIONS_FLAG_CLOSED`, on that constant's own stated
## reasoning: "the layer is switched off" is a different fact about the match per LAYER, and a
## playtester isolating cognitive overload needs to know WHICH switch closed the cast. Degrading
## gracefully means the identical thing it means for minions — the cast still resolves (mana spent,
## card discarded, replacement owed) and no totem reaches the board.
const REASON_TOTEMS_FLAG_CLOSED := &"totems_flag_closed"

## Story 6-5a (AC 4, AC 15): THE FIRST WHOLE-ID FAMILY THAT IS NOT A SUMMON. Deck 1's effect ids carry
## no `summon_`/`spell_` prefix -- they are matched here as WHOLE ids, one table row each, which is what
## AC 4 means by dispatching "on the WHOLE `effect_id`, not a prefix". Ruin Vanguard is the exception by
## design: `summon_ruin_vanguard` takes the unchanged `summon_*` path above (an unmapped summon is a
## minion), because it is a summon rather than a new effect family.
##
## THE FOUR BUFF OUTCOMES. Each names what `MatchState` must APPLY (D6: this file computes, the ordered
## dispatch applies -- the `OUTCOME_SUMMON` discipline, unchanged). None of them mutates anything here.
const OUTCOME_BLOODLUST := &"bloodlust"
const OUTCOME_VAMPIRIC_AURA := &"vampiric_aura"
const OUTCOME_BLOODHOUND_STEP := &"bloodhound_step"
const OUTCOME_FROSTBITE := &"frostbite"

## The authored effect id -> buff outcome table. A `Dictionary` only ever `get()`-ed by one known key --
## never iterated, never sorted, never hashed -- the `SUMMON_KINDS` posture verbatim.
const BUFF_OUTCOMES: Dictionary[StringName, StringName] = {
	&"bloodlust": OUTCOME_BLOODLUST,
	&"vampiric_aura": OUTCOME_VAMPIRIC_AURA,
	&"bloodhound_step": OUTCOME_BLOODHOUND_STEP,
	&"frostbite": OUTCOME_FROSTBITE,
}

## Story 6-5a (AC 15): the NINE Deck 1 effects that are authored but not yet built resolve as ONE named
## no-op -- `REASON_SPELL_NOT_YET_RESOLVED`'s shape and reasoning: a SUCCESSFUL cast (mana/orbs spent,
## card discarded, replacement owed, no `reject_action`), NOT YET rather than NOTHING. The card that
## was cast stays distinguishable through its own id; the owning story is machine-readable below.
const REASON_DECK1_NOT_YET_RESOLVED := &"deck1_not_yet_resolved"

## Each deferred Deck 1 effect id -> the board key of the story that owns building it (AC 15,
## `6-5a/R19`). A constant rather than a comment because a comment is not machine-checkable; a unit test
## asserts all nine rows. Only ever `get()`-ed, never iterated.
const DEFERRED_EFFECT_OWNERS: Dictionary[StringName, StringName] = {
	&"culling": &"6-5b-corpses-and-own-minions",
	&"grave_ward": &"6-5b-corpses-and-own-minions",
	&"raise_dead": &"6-5b-corpses-and-own-minions",
	&"drain": &"6-5b-corpses-and-own-minions",
	&"rocksling": &"6-5d-hero-and-corpse-projectiles",
	&"boom": &"6-5e-boulder-injection",
	&"honed_bolt": &"6-5c-hero-cast-honed-bolt",
	&"counterspell": &"6-5f-counterspell",
	&"corpse_bomb": &"6-5d-hero-and-corpse-projectiles",
}

## Story 6-5a (AC 16): the SPELL layer's closed-gate reason, the `REASON_TOTEMS_FLAG_CLOSED` twin. The
## four buffs gate on `FeatureFlags.spells`; off, the cast still resolves and the buff does not apply.
const REASON_SPELLS_FLAG_CLOSED := &"spells_flag_closed"


## What this cast's effect does, as one of the four named outcomes above. `effect` is the injected
## per-card CardEffect for the id just cast — null when no entry was injected for it; `flags` is
## the injected FeatureFlags, dereferenced within this call and never retained.
##
## ORDER IS LOAD-BEARING between the last two branches: the flag is consulted only AFTER the id
## has been recognised as a summon, so an UNKNOWN prefix reports itself as unknown whether the
## minion layer is on or off. Reading the flag first would make an authoring error invisible
## behind a switch.
##
## STORY 4-4 (AC 1): THE FLAG CONSULTED IS NOW THE ONE THAT OWNS THIS ID'S LAYER. The ordering
## argument this docstring already makes is UNCHANGED and now does more work: the id is recognised
## as a summon first, then classified as totem or minion, and only THEN is the owning flag read — so
## an unknown prefix still reports itself as unknown whether either layer is on or off, and a totem
## id whose kind `BalanceConfig` does not author still resolves as a summon here (the missing kind is
## the CAST SEAT's problem, not the resolver's — this file computes, it does not apply).
static func outcome(effect: CardEffect, flags: FeatureFlags) -> StringName:
	if effect == null:
		return REASON_NO_EFFECT_ENTRY
	var id := String(effect.effect_id)
	if id.begins_with(PREFIX_SUMMON):
		if _is_totem(effect.effect_id):
			return OUTCOME_SUMMON if _totems_open(flags) else REASON_TOTEMS_FLAG_CLOSED
		return OUTCOME_SUMMON if _minions_open(flags) else REASON_MINIONS_FLAG_CLOSED
	# Story 6-5a (AC 4): the WHOLE-ID matches, AFTER the summon prefix (a summon id is never a table
	# row) and BEFORE the `spell_*` prefix. The id is recognised first and the flag read only after, the
	# ordering argument this docstring already makes for the summon branch.
	var buff: StringName = BUFF_OUTCOMES.get(effect.effect_id, &"")
	if buff != &"":
		return buff if _spells_open(flags) else REASON_SPELLS_FLAG_CLOSED
	if owner_story_for(effect.effect_id) != &"":
		return REASON_DECK1_NOT_YET_RESOLVED
	if id.begins_with(PREFIX_SPELL):
		return REASON_SPELL_NOT_YET_RESOLVED
	return REASON_UNKNOWN_EFFECT_PREFIX


## Story 6-5a (AC 15): the board key of the story that owns a deferred Deck 1 effect id, or `&""` when
## the id is not one of the nine.
static func owner_story_for(effect_id: StringName) -> StringName:
	return DEFERRED_EFFECT_OWNERS.get(effect_id, &"")


## Story 4-4 (AC 1): the UNIT KIND NAME this cast puts on the board — the second, finer question the
## prefix cannot answer (see `SUMMON_KINDS`).
##
## TOTAL OVER EVERY `summon_*` ID, by construction: a mapped id returns its own kind, an unmapped one
## returns `KIND_MINION`. That default is what keeps the three minion fixture cards' behaviour
## bit-for-bit unmoved by this story and what stops a future minion card from needing an edit here.
##
## IT COMPUTES, IT DOES NOT APPLY (D6). The returned NAME is turned into the plain int index the
## record actually stores by `BalanceConfig.kind_index_of()`, at the cast seat inside `advance()`'s
## ordered dispatch — this file never touches a board, a pool or a `BalanceConfig`.
##
## A NON-SUMMON EFFECT IS A PROGRAMMING ERROR AT THE CALL SITE, not a case handled here: the one
## caller reaches this only after `outcome()` returned `OUTCOME_SUMMON`. It still answers total
## rather than crashing — `KIND_MINION` — because a total function's honest default is this file's
## standing posture (the `REASON_NO_EFFECT_ENTRY` null branch, `CastEvaluator.refusal_reason`).
static func kind_for(effect: CardEffect) -> StringName:
	if effect == null:
		return KIND_MINION
	return SUMMON_KINDS.get(effect.effect_id, KIND_MINION)


## Whether this `summon_*` id belongs to the TOTEM layer. DERIVED FROM `SUMMON_KINDS` rather than
## listed a second time, which is the whole reason it is a function: a second literal list of totem
## ids would be a second thing to keep in agreement with the first, and the failure mode is silent
## (an id in one list and not the other gates on the wrong flag).
static func _is_totem(effect_id: StringName) -> bool:
	return SUMMON_KINDS.has(effect_id)


## NO FLAGS INJECTED READS AS CLOSED — CastEvaluator._flag_open's own reading, in the same
## direction and for the same reason: a layer that cannot be verified open stays shut. Every
## MatchState in the shipped path is handed flags at match start; a fixture that injects none is
## exercising a state that live play cannot reach, and it gets the safe answer.
static func _minions_open(flags: FeatureFlags) -> bool:
	return flags != null and flags.minions


## Story 4-4: the TOTEM twin, in the same direction and for the same reason.
static func _totems_open(flags: FeatureFlags) -> bool:
	return flags != null and flags.totems


## Story 6-5a (AC 16): the SPELL twin, in the same direction and for the same reason.
static func _spells_open(flags: FeatureFlags) -> bool:
	return flags != null and flags.spells
