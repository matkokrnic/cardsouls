class_name EconomyEvaluator
extends RefCounted

## D6 pure evaluator (story 3-4, AC 1) — THE one place ResourceGenerationRules are read.
## Fully STATIC and stateless: there is no instance to hold a reference in, so CONSTRAINT C
## (never cache `balance` / `balance_ticks`) holds BY CONSTRUCTION — the live objects arrive
## as arguments on every call and are dereferenced immediately.
##
## PURE means it COMPUTES, it does not APPLY: `amount_for()` returns a number and touches no
## pool. This is a deliberate departure from Novel Pattern 5's sketch, which has the
## evaluator call `player.mana.add(...)` itself — pools apply, the evaluator computes, so the
## mutation stays inside MatchState.advance()'s ordered dispatch (D2) where every other
## mutation lives. (Recorded for the architecture amendment queue's fifth member.)
##
## RULE SOURCING — the one structural novelty. The authored rules are loaded HERE, from
## `data/economy/`, rather than injected the way BalanceConfig and FeatureFlags are. Two
## reasons, both load-bearing:
##   1. Rules are STRUCTURE, not tuning. A rule `.tres` carries no gameplay number (see
##      ResourceGenerationRule) — only which faucet reads which balance field. So the
##      standing property that authored data cannot move the determinism golden (BC/R3)
##      survives intact: `data/balance/balance_config.tres` is still never read by the
##      hashed run.
##   2. A new autoload service would be a project.godot edit, and an injection seam would
##      force every existing fixture to inject rules before mana generation worked at all —
##      i.e. the evaluator swap could not be a behaviour-preserving no-op (AC 2).
## Loading is a DIRECTORY SCAN, not a preload list, so D6's promise holds literally: the E4
## Mana Accelerator totem is a new `.tres` in `data/economy/` and NO code change here.
## Deterministic by construction — the file list is SORTED before loading, and the rule set
## is content, loaded once (the FeatureFlags load-once shape, no reload path).

const RULES_DIR := "res://data/economy/"

## Resource names (the `resource` field's vocabulary).
const MANA := &"mana"
## Story 5-4 (AC 1): THE SECOND RESOURCE, and the first consumer of the `resource` field's own
## stated purpose -- `ResourceGenerationRule.resource`'s header has said since 3-4 that "only
## &"mana" has a consumer today; the field exists so a stamina or orb faucet is a new .tres rather
## than a new evaluator". This is that .tres arriving, and the evaluator is unchanged by it: the
## grant is a `resource`/`source` pair on an existing call, not a second evaluator and not an
## inline formula at the landing seat.
const ORBS := &"orbs"

## Source names (the `source` field's vocabulary). Named here so call sites reference a
## constant rather than repeating a StringName literal that a typo would silently break.
const SOURCE_MELEE_HIT := &"melee_hit"
const SOURCE_PASSIVE_TICK := &"passive_tick"
## Story 4-4 (AC 20): THE THIRD SOURCE — the Mana Accelerator totem's faucet, and the one this
## file's own header predicted in advance ("the E4 Mana Accelerator totem is a new `.tres` in
## `data/economy/` and NO code change here"). That prediction is HALF TRUE, and the story's B8
## correction says which half: the RULE needed no code, and `data/economy/mana_accelerator.tres`
## really is nothing but authored data read by this unchanged evaluator. What it did need is a
## CALL SITE — nothing scans authored rules by source, so a rule nobody asks for is loaded and
## never queried. `MatchState._generate_mana` asks for this source at its third rung.
const SOURCE_MANA_ACCELERATOR := &"mana_accelerator"
## Story 5-4 (AC 1/AC 2): THE FOURTH SOURCE and the first NON-MANA one -- a landed mode (2)
## unblockable hit, paying the attacker orbs of the spent card's own colour. Its rule
## (`data/economy/unblockable_landing.tres`) carries `required_flag = &"orbs"`, the SAME flag
## `CastEvaluator._orbs_affordable` already reads on the SPEND side, which is what closes the
## `4-5` D1 flag-matrix split symmetrically rather than leaving it half-real: `unblockable` gates
## whether mode (2) exists at all, `orbs` gates whether landing one pays out.
##
## The COLOUR is deliberately NOT part of the rule vocabulary. A rule answers "how much", the
## landing seat answers "into which colour" (from `PlayerState.charge_color`) -- one value for all
## three colours in this story (`5-2` Ruling 2's fixed-damage precedent applied to the payout side;
## `5-6` owns tiering).
const SOURCE_UNBLOCKABLE_LANDING := &"unblockable_landing"

static var _authored: Array[ResourceGenerationRule] = []
static var _authored_loaded := false


## The shipped rule set. Loaded on first use and kept — rules are content, not live state.
static func authored_rules() -> Array[ResourceGenerationRule]:
	if not _authored_loaded:
		_authored = load_rules(RULES_DIR)
		_authored_loaded = true
	return _authored


## Every ResourceGenerationRule `.tres` in `dir_path`, in SORTED filename order (determinism:
## the set must not depend on filesystem enumeration order). Non-rule resources in the
## directory are skipped, so a stray `.tres` cannot poison the rule set. A missing directory
## yields an empty set rather than failing — graceful degradation, the FeatureFlags precedent.
##
## RECIPROCAL NOTE (story 3-2): `CardDatabase._load_all()` (src/systems/card_database.gd)
## runs the same sorted, extension-filtered, single-directory scan over `data/cards/`. The
## duplication is DELIBERATE — a shared helper is deferred to a third scan, because these two
## sit on opposite sides of the state/systems layer boundary and the helper has no honest home
## today. Change one and check the other. The export-packaging remap risk filed here at 3-4/R8
## covers BOTH directories.
static func load_rules(dir_path: String) -> Array[ResourceGenerationRule]:
	var out: Array[ResourceGenerationRule] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	var files := dir.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var rule := load(dir_path + file_name) as ResourceGenerationRule
		if rule != null:
			out.append(rule)
	return out


## Total amount of `resource` generated by `source` under the current balance and flags —
## the sum over every matching, flag-open rule. Returns a NUMBER; the caller applies it to a
## pool. `balance` / `balance_ticks` / `flags` are the caller's LIVE objects, passed in and
## dereferenced within this call (CONSTRAINT C: nothing is retained between calls).
static func amount_for(rules: Array[ResourceGenerationRule], source: StringName,
		resource: StringName, balance: BalanceConfig, balance_ticks: BalanceTicks,
		flags: FeatureFlags) -> float:
	var total := 0.0
	for rule in rules:
		if rule.source != source or rule.resource != resource:
			continue
		if not _flag_open(rule, flags):
			continue
		total += _amount(rule, balance, balance_ticks)
	return total


## AC 3's flag scope, evaluated as DATA. An ungated rule is always open; a gated one needs an
## injected FeatureFlags whose named property is a true bool. No flags injected, or a flag
## name that does not exist on the resource, reads as CLOSED — the graceful-degradation
## direction (a faucet that cannot be verified open stays shut), matching the pre-evaluator
## behaviour of the direct melee grant exactly.
static func _flag_open(rule: ResourceGenerationRule, flags: FeatureFlags) -> bool:
	if rule.required_flag == &"":
		return true
	if flags == null:
		return false
	var value: Variant = flags.get(rule.required_flag)
	return value is bool and value


## Dereference one rule's amount against the live balance objects. A null balance object is a
## pre-injection MatchState (inert by design, the step-5 guard's family) and an unknown field
## name is an authoring error that degrades to no amount rather than crashing the tick.
static func _amount(rule: ResourceGenerationRule, balance: BalanceConfig,
		balance_ticks: BalanceTicks) -> float:
	var home: Object = balance
	if rule.amount_domain == ResourceGenerationRule.AmountDomain.BALANCE_TICKS:
		home = balance_ticks
	if home == null:
		return 0.0
	var value: Variant = home.get(rule.amount_field)
	if value is float or value is int:
		return float(value)
	return 0.0
