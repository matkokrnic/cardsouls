class_name TargetingService
extends RefCounted

## D6 pure evaluator (story 4-2, AC 2) — THE one place MinionPriority rules are read.
##
## A SIBLING OF EconomyEvaluator / CastEvaluator / CardEffectResolver, NOT A BRANCH INSIDE ANY OF
## THEM (`E4-P/R5`). Each of those files opens by declaring itself "THE one place" its kind of data
## is read — ResourceGenerationRules, CardCastConditions, CardEffect ids — and a targeting read
## folded into one of them would contradict that identity. It lives in `src/state/targeting/`
## rather than `src/state/economy/` (`4-2/R12`): `economy/` holds three economy evaluators, and
## targeting is not economy.
##
## Fully STATIC and stateless, exactly like all three siblings: there is no instance to hold a
## reference in, so CONSTRAINT C (never cache `balance` / `balance_ticks` / an injected value)
## holds BY CONSTRUCTION. Nothing is retained between calls. The one static member below is the
## loaded RULE SET — content, not live state, the EconomyEvaluator._authored shape verbatim.
##
## PURE means it COMPUTES, it does not APPLY (D6). `target_for()` returns a `[slot, index]` pair
## and `reason_for()` returns a StringName; neither touches a board, a pool or a container.
## Storing the verdict happens in MatchState.advance()'s step-7 ordered dispatch, so the mutation
## stays where every other mutation lives (D2).
##
## IT TAKES PLAIN FACTS, NOT A PlayerState. The candidate set reaches this file as an int, a bool
## and an ARRAY OF INTS (the opposing slot, whether that hero is alive, and which of that board's
## indices are LIVING), which is what makes "touches no board" literally true rather than a promise,
## and what lets every branch below be unit-tested without building a match.
##
## STORY 4-3a (AC 8, `4-3a/R15`) REPLACED THE THIRD FACT: it was `opposing_unit_count: int` through
## 4-2, and a COUNT structurally cannot skip a hole. With a dead unit at index 0 the old
## `return [opposing_slot, 0]` would hand back the CORPSE, and REASON_NO_LIVING_CANDIDATE tested a
## count that a hole keeps non-zero. An array of plain ints is still a plain fact, so the contract
## this paragraph states is preserved rather than weakened -- what changed is that the fact is now
## rich enough to answer the question being asked of it.
##
## RULE SOURCING — the EconomyEvaluator precedent verbatim (AC 3). Rules are loaded HERE from
## `data/minions/` by DIRECTORY SCAN in SORTED filename order, rather than injected the way
## BalanceConfig and FeatureFlags are, for that precedent's own stated reason: rules are STRUCTURE,
## not tuning, and a new injection seam would force every existing fixture to inject rules before
## targeting worked at all. Loaded ONCE and kept; NO reload path and NO cache mode
## (`4-2/R9`: `CACHE_MODE_IGNORE` exists only on BalanceConfigService.reload(), and only because
## balance has a LIVE reload trigger — this content has none, and a dev pass must not add one by
## analogy).

const RULES_DIR := "res://data/minions/"

## `4-2/R17`: THE named priority the shipped path selects, resolved BY NAME from the sorted rule
## set. Every unit summoned this story evaluates against this one, because no unit carries a type —
## 4-1's totem clause ships unit records type/kind-less and `4-2/R14` adds no field to them.
##
## `hero_seeker.tres` IS AUTHORED BUT TEST-ONLY. Nothing in the shipped path selects it; it exists
## so the evaluator can be proven GENERIC rather than a hardcoded branch, which is the same
## non-vacuity argument the golden's measured pairs rest on. Per-unit priority CHOICE has a named
## forcing point rather than staying open: the first story where units actually differ (4-3 combat
## / 4-4 totems), and that story — not this one — is allowed to add a field to the unit record.
const PRIORITY_STANDARD := &"standard"

## The `slot` half of a NO-TARGET verdict. It cannot be the `index` half: `index == -1` already
## MEANS the hero (AC 11), so the slot is the discriminator and -1 is not a legal slot.
const NO_TARGET_SLOT := -1

## AC 11: `index == -1` addresses the `slot`-identified player's HERO; `index >= 0` addresses a
## unit at that board index. Both halves are plain ints — no identity, no object, no StringName
## reaches the hash (the `pending_draw_owed` slot-INDICES precedent, player_state.gd:94-95).
const HERO_INDEX := -1

## Every outcome is a NAMED RETURNED VALUE, never an `Invariant.check` crash (AC 6), on the
## CastEvaluator.REASON_* / CardEffectResolver constant-vocabulary precedent. Named as constants
## rather than repeated StringName literals so a typo at a call site fails to match instead of
## silently producing an unrecognised verdict.
##
## DELIBERATELY NOT CastEvaluator's `ALLOWED := &""` CONVENTION, for CardEffectResolver's own
## stated reason: empty-means-allowed works only when the question is binary, and "no target" is
## not a refusal — it is an honest outcome a unit can sit in for a whole round. Every outcome is
## named, including success.
const REASON_ACQUIRED := &"acquired"

## AC 6, reason ONE: no living candidate exists. The opposing hero is DEAD and the opposing board
## is empty, so the ordered candidate set is empty. Distinguishable from "acquired and it happens
## to be null" by construction, because success has its own name above.
##
## STORY 4-3a (AC 8) FALSIFIED THIS CONSTANT'S ORIGINAL NOTE, which read: "A UNIT IS ALWAYS A LIVING
## CANDIDATE THIS STORY ... units have no HP until 4-3, so a unit on the board cannot be dead. Only
## the hero's liveness varies." That is no longer true in either half. Units carry `hp` as of this
## story, a unit CAN be dead, and its death is exactly what this reason now has to be able to see —
## which is why the parameter below is a list of LIVING indices and not a count. Both liveness
## sources vary now, and this reason fires only when BOTH are exhausted: the opposing hero is dead
## AND the opposing board holds no living unit (an EMPTY board and a board that is ALL HOLES reach
## it identically, which is the point).
const REASON_NO_LIVING_CANDIDATE := &"no_living_candidate"

## AC 6, reason TWO: the priority data is missing or unrecognized. Three ways in, all authored-data
## reachable and all mutation-proven: no rule with the selected name exists in the scanned set
## (an empty `data/minions/`, or an export remap that degraded it — AC 3's graceful degradation);
## an authored `target_side` outside the recognized vocabulary; an authored `ordering_mode` outside
## it. AC 1 names this the reason an "unrecognized or unauthored PARAMETER" falls to.
const REASON_NO_PRIORITY_DATA := &"no_priority_data"

## AC 5, the project-context HARD RULE made concrete for this layer: a unit with
## `FeatureFlags.minions` closed NEVER acquires a target, exactly as 4-1's summon resolution gates
## on the same flag. Its own name rather than a reuse of the two above, because "the layer is
## switched off" is a different fact about the match from "there was nothing to shoot at" — the
## CardEffectResolver.REASON_MINIONS_FLAG_CLOSED reasoning verbatim.
const REASON_MINIONS_FLAG_CLOSED := &"minions_flag_closed"

static var _authored: Array[MinionPriority] = []
static var _authored_loaded := false


## The shipped rule set. Loaded on first use and kept — rules are content, not live state.
static func authored_priorities() -> Array[MinionPriority]:
	if not _authored_loaded:
		_authored = load_priorities(RULES_DIR)
		_authored_loaded = true
	return _authored


## Every MinionPriority `.tres` in `dir_path`, in SORTED filename order — the
## EconomyEvaluator.load_rules body verbatim, including all three of its degradation properties
## (AC 3): the file list is SORTED so the set never depends on filesystem enumeration order,
## non-MinionPriority resources are SKIPPED so a stray `.tres` cannot poison the set, and a MISSING
## directory yields an EMPTY set rather than failing.
##
## RECIPROCAL NOTE: this is now the THIRD copy of this scan (EconomyEvaluator.load_rules,
## CardDatabase._load_all, this). economy_evaluator.gd's own note deferred a shared helper "to a
## third scan" — this is that third scan, and the helper is STILL not extracted, because the
## honest home has not changed: CardDatabase sits in `src/systems/` on the far side of the layer
## boundary, so a shared helper could only live in `src/state/` and would make a systems autoload
## depend on the state layer. Change one and check the others. The export-packaging remap risk
## filed at 3-4/R8 now covers this directory too, and AC 3's non-empty load assertion under the
## headless harness is what makes a degraded remap loud instead of silent.
static func load_priorities(dir_path: String) -> Array[MinionPriority]:
	var out: Array[MinionPriority] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	var files := dir.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var rule := load(dir_path + file_name) as MinionPriority
		if rule != null:
			out.append(rule)
	return out


## The rule carrying `rule_name`, or NULL when the set holds none (`4-2/R17`). NEVER a fallback to
## another rule: substituting a different priority for a missing one would change which priority
## governs the game without anything saying so. A null return reaches
## REASON_NO_PRIORITY_DATA at `reason_for` below.
##
## FIRST MATCH IN THE SORTED SET, so a duplicated name resolves deterministically rather than by
## enumeration order. Names are compared as StringNames and never SORTED — `Array[StringName]
## .sort()` orders by INTERNAL POINTER on this engine (player_state.gd:77, 206-207;
## test_determinism.gd:170), so a name may be COMPARED but must never decide an order.
static func priority_named(rules: Array[MinionPriority], rule_name: StringName) -> MinionPriority:
	for rule in rules:
		if rule != null and rule.priority_name == rule_name:
			return rule
	return null


## The named outcome for one unit, and the PUBLIC PREDICATE the step-7 seat is wired to (AC 6): a
## returned value tested in BOTH directions, never an `Invariant.check` that a headless run would
## print and continue past (`3-0c/R15`).
##
## ORDER IS LOAD-BEARING between the first two branches, the CardEffectResolver.outcome() ordering
## argument applied to a different pair. The FLAG is consulted FIRST: with the minion layer off,
## nothing about this unit's targeting runs at all, so reporting an authoring error the switched-off
## layer would never have reached would be a false statement about the match. Reversing them would
## make a closed flag report REASON_NO_PRIORITY_DATA whenever `data/minions/` happened to be empty.
##
## `flags` is the caller's LIVE object, passed in and dereferenced within this call (CONSTRAINT C).
##
## `opposing_living_units` (story 4-3a, AC 8) is the opposing board's LIVING indices. Only its
## EMPTINESS is consulted here — which index is taken is `target_for`'s decision, not this one's.
static func reason_for(priority: MinionPriority, opposing_hero_alive: bool,
		opposing_living_units: Array[int], flags: FeatureFlags) -> StringName:
	if not _minions_open(flags):
		return REASON_MINIONS_FLAG_CLOSED
	if not _is_recognized(priority):
		return REASON_NO_PRIORITY_DATA
	if not opposing_hero_alive and opposing_living_units.is_empty():
		return REASON_NO_LIVING_CANDIDATE
	return REASON_ACQUIRED


## The applied verdict as AC 11's HASHED INDEX PAIR: `[slot, index]`, both plain ints, where
## `index >= 0` addresses a unit on the `slot`-identified player's board and `index == -1`
## addresses that player's hero. `no_target()` when `reason_for` above is anything but
## REASON_ACQUIRED — the reason and the pair can never disagree, because the pair is computed only
## after that call returns success.
##
## THE CANDIDATE SET IS THE OPPOSING SIDE ONLY (`4-2/R3`), and here that is structural rather than
## filtered: the only slot this function can name is `opposing_slot`, so an own-side unit is not
## excluded by a check that could be got wrong — it is unreachable.
##
## THE TOTAL ORDER (`4-2/R3`): slot ascending, then board index ascending. The SLOT half is
## satisfied by construction — the opposing side of a 1v1 is exactly one slot, and a one-element
## slot set is trivially sorted — so the only half with anything to decide is the INDEX half, and
## the ascending-first LIVING index is the answer (story 4-3a, AC 8 -- it was the constant `0`
## through 4-2, when nothing could be dead). `prefer_hero` chooses WHICH partition is taken; the
## total order
## picks inside it. Ties never resolve by Dictionary iteration order or by
## `Array[StringName].sort()`: no Dictionary and no StringName participates in this decision at all.
##
## `ordering_mode` is not branched on because its vocabulary has exactly one member, which
## `_is_recognized` has already established by the time this line runs. A second mode arrives with
## the facts it orders by (position/HP, 4-3) and gets its branch then — writing a switch over one
## value now would be a branch nothing can take.
##
## STORY 4-3a (AC 8, `4-3a/R15`): THE INDEX HALF IS NO LONGER THE CONSTANT 0. It is the ASCENDING-
## FIRST LIVING index, which is the same answer 4-2 gave whenever nothing was dead and a DIFFERENT
## one the moment a hole exists at index 0 — where the old code handed back the corpse. `min()`
## rather than `[0]` expresses the total order itself rather than trusting the caller to have built
## the array in order: `living_indices()` does build it ascending, but the ORDER IS THE CONTRACT
## here (`4-2/R3`), and a contract a caller could break silently is not one.
static func target_for(priority: MinionPriority, opposing_slot: int, opposing_hero_alive: bool,
		opposing_living_units: Array[int], flags: FeatureFlags) -> Array[int]:
	if reason_for(priority, opposing_hero_alive, opposing_living_units, flags) != REASON_ACQUIRED:
		return no_target()
	if priority.prefer_hero and opposing_hero_alive:
		return [opposing_slot, HERO_INDEX]
	if not opposing_living_units.is_empty():
		return [opposing_slot, opposing_living_units.min()]
	# Units-first exhausted: a Standard unit falls through to the hero rather than reporting no
	# target, which is what makes `prefer_hero` a PREFERENCE and not a restriction. Reachable only
	# with a live hero, because reason_for() has already refused the both-empty case above.
	return [opposing_slot, HERO_INDEX]


## The NO-TARGET pair, as a function rather than a `const` array: a shared constant Array would
## hand every caller the same instance to mutate. `NO_TARGET_SLOT` in the slot half is the
## discriminator; the index half repeats it only because a pair needs two ints and no index value
## is meaningful without a slot.
static func no_target() -> Array[int]:
	return [NO_TARGET_SLOT, NO_TARGET_SLOT]


static func is_no_target(pair: Array[int]) -> bool:
	return pair.size() != 2 or pair[0] == NO_TARGET_SLOT


## NO FLAGS INJECTED READS AS CLOSED — CardEffectResolver._minions_open / CastEvaluator._flag_open
## verbatim, in the same direction and for the same reason: a layer that cannot be verified open
## stays shut. Every MatchState in the shipped path is handed flags at match start.
static func _minions_open(flags: FeatureFlags) -> bool:
	return flags != null and flags.minions


## Whether every parameter on this rule is in the recognized vocabulary (AC 1, AC 6). A null rule
## (no rule carried the selected name) reads as unrecognized, the CastEvaluator null-branch
## precedent: a total function's honest default rather than a crash.
##
## The enum bounds are checked as INTEGER RANGES rather than by matching each member, so a `.tres`
## authored with an out-of-vocabulary int — the only way this is reachable, since the editor offers
## members only — fails here instead of silently selecting member 0. `size()` is not available on a
## GDScript enum at runtime, so the upper bound names the last member explicitly; adding a member
## means extending it deliberately, which is the intent.
static func _is_recognized(priority: MinionPriority) -> bool:
	if priority == null:
		return false
	if priority.target_side != MinionPriority.TargetSide.OPPOSING:
		return false
	return priority.ordering_mode == MinionPriority.OrderingMode.SLOT_THEN_INDEX_ASCENDING
