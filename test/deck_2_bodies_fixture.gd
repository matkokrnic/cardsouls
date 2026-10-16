extends RefCounted

## Story 7-5b: THE SHARED HEADLESS FIXTURE for Deck 2's three bodies -- the Healer, Elemental Fury and Wrath
## of God. It builds on `Deck2Fixture` (its config, cards, drives and hits) and adds the three cards, the
## Healer kind and a walking minion that reacts to damage. PRELOADED by the tests, never a `class_name`, so
## no editor pass is needed to use it.
##
## EVERY NUMBER HERE IS A TEST LITERAL (`BC/R3`): the tests are isolated from `data/` tuning. Only the EFFECT
## IDS and the KIND NAME are the shipped vocabulary, because the resolver and the summon seat key on them.

const D := preload("res://test/deck_2_fixture.gd")

const HEALER_HP := 18.0
const HEAL_AMOUNT := 2.0
const HEAL_INTERVAL_TICKS := 10
const SHOT_DELAY_TICKS := 3
const SHOT_DAMAGE := 3.0
const HEALER_SPEED := 3.0
## Smoke fix 1 (S9): the share of the Healer's shot a held block takes.
const HEALER_BLOCKED_MULT := 1.0 / 3.0

const RED_DAMAGE := 3.0
const SLOW_MULT := 0.5
const SLOW_TICKS := 30
const GREEN_HEAL := 5.0
const VOLLEY_TICKS := 4

const WRATH_DAMAGE := 6.0
const WINDUP_TICKS := 5
const WRATH_STUN_TICKS := 8
const BASE_RADIUS := 4.0
const RADIUS_PER_ORB := 1.0
const KNOCKBACK_DISTANCE := 4.0
const KNOCKBACK_TICKS := 6
const BLOCKED_MULT := 0.5

const HEALER := &"fx_healer"
const FURY := &"fx_fury"
const WRATH := &"fx_wrath"

## The walking kind that reacts to damage (the hound's rule, without its seeded behaviour).
const KIND_WALKER := &"walker"

## id -> [colour, basic effect id, pitch effect id, basic mana, pitch mana] -- `Deck2Fixture.CARDS`' shape.
const BODY_CARDS: Dictionary = {
	HEALER: [Enums.CardColor.GREEN, &"healer", &"stoneskin", 3.0, 2.0],
	FURY: [Enums.CardColor.BLUE, &"manablossom", &"elemental_fury", 1.0, 5.0],
	WRATH: [Enums.CardColor.BLUE, &"manapulation", &"wrath_of_god", 1.0, 6.0],
}


static func ticks_to_seconds(ticks: int) -> float:
	return float(ticks) / TimingWindow.TICK_HZ


static func healer_kind() -> UnitKindProfile:
	var kind := UnitKindProfile.new()
	kind.kind_name = &"healer"
	kind.move_speed = HEALER_SPEED
	kind.stop_distance = 2.0
	kind.max_hp = HEALER_HP
	kind.is_minion = true
	kind.heal_amount = HEAL_AMOUNT
	kind.heal_interval_seconds = ticks_to_seconds(HEAL_INTERVAL_TICKS)
	kind.heal_range = 8.0
	kind.owner_chargeup_shot_effect = &"healer"
	kind.shot_delay_seconds = ticks_to_seconds(SHOT_DELAY_TICKS)
	return kind


static func walker_kind() -> UnitKindProfile:
	var kind := UnitKindFixture.melee(KIND_WALKER, D.MINION_HP, 2.0, 2, 3, 4, 2.0)
	kind.is_minion = true
	kind.react_on_damage = true
	kind.reaction_seconds = ticks_to_seconds(5)
	return kind


static func config() -> BalanceConfig:
	var c := D.config()
	c.deck_size = D.CARDS.size() - 1 + BODY_CARDS.size()
	var kinds: Array[UnitKindProfile] = []
	kinds.append_array(c.unit_kinds)
	kinds.append(healer_kind())
	kinds.append(walker_kind())
	c.unit_kinds = kinds
	return c


static func effect(effect_id: StringName) -> CardEffect:
	var e := D.effect(effect_id)
	match effect_id:
		&"healer":
			e.summon_kind = &"healer"
			e.damage_amount = SHOT_DAMAGE
			e.blocked_damage_multiplier = HEALER_BLOCKED_MULT
			e.launch_speed = 5.0
			e.max_speed = 5.0
			e.travel_budget = 500.0
		&"elemental_fury":
			e.damage_amount = RED_DAMAGE
			e.slow_speed_multiplier = SLOW_MULT
			e.slow_duration_seconds = ticks_to_seconds(SLOW_TICKS)
			e.heal_amount = GREEN_HEAL
			e.volley_interval_seconds = ticks_to_seconds(VOLLEY_TICKS)
			e.launch_speed = 5.0
			e.max_speed = 5.0
			e.travel_budget = 500.0
		&"wrath_of_god":
			e.cast_seconds = ticks_to_seconds(WINDUP_TICKS)
			e.damage_amount = WRATH_DAMAGE
			e.stun_seconds = ticks_to_seconds(WRATH_STUN_TICKS)
			e.pulse_radius = BASE_RADIUS
			e.radius_per_orb = RADIUS_PER_ORB
			e.knockback_distance = KNOCKBACK_DISTANCE
			e.knockback_seconds = ticks_to_seconds(KNOCKBACK_TICKS)
			e.blocked_damage_multiplier = BLOCKED_MULT
	return e


static func all_cards() -> Dictionary:
	var out: Dictionary = D.CARDS.duplicate()
	out.merge(BODY_CARDS)
	return out


static func card_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in all_cards():
		if id != D.BOULDER:
			out.append(id)
	return out


static func make(flags: FeatureFlags = null, balance: BalanceConfig = null) -> MatchState:
	var ms := MatchState.new(MatchParams.new(D.SEED))
	ms.apply_balance(balance if balance != null else config())
	inject_content(ms, flags if flags != null else D.flags())
	D.idle(ms, 1)
	ms.p1.mana.add(D.MAX_MANA)
	ms.p2.mana.add(D.MAX_MANA)
	ms.drain_signals()
	return ms


static func inject_content(ms: MatchState, flags: FeatureFlags) -> void:
	var cards := all_cards()
	var costs: Dictionary[StringName, CardCastCondition] = {}
	var pitch_costs: Dictionary[StringName, CardCastCondition] = {}
	var basic: Dictionary[StringName, CardEffect] = {}
	var pitch: Dictionary[StringName, CardEffect] = {}
	var colors: Dictionary[StringName, Enums.CardColor] = {}
	for id: StringName in cards:
		var row: Array = cards[id]
		var cost := CardCastCondition.new()
		cost.mana_cost = float(row[3])
		costs[id] = cost
		basic[id] = effect(row[1])
		colors[id] = int(row[0]) as Enums.CardColor
		if StringName(row[2]) != &"":
			var pitch_cost := CardCastCondition.new()
			pitch_cost.mana_cost = float(row[4])
			pitch_cost.orb_costs[int(row[0]) as Enums.CardColor] = 1
			pitch_costs[id] = pitch_cost
			pitch[id] = effect(row[2])
	ms.inject_feature_flags(flags)
	ms.inject_deck(card_ids())
	ms.inject_card_costs(costs)
	ms.inject_card_effects(basic)
	ms.inject_card_colors(colors)
	ms.inject_pitch_costs(pitch_costs)
	ms.inject_pitch_effects(pitch)


static func flags_with(minions: bool, spells: bool) -> FeatureFlags:
	var f := D.flags()
	f.minions = minions
	f.spells = spells
	return f


## Seat `index` plays the Healer (Mode 1); returns the board index of the new record, or -1.
static func summon_healer(ms: MatchState, index: int, slot: int = 0) -> int:
	var player := D.seat(ms, index)
	var before := player.units.size()
	D.set_mana(ms, player, D.MAX_MANA)
	D.play(ms, index, HEALER, slot)
	return player.units.size() - 1 if player.units.size() > before else -1


## Seat `index`'s board puts a unit of `kind_name` straight onto the board (the summon seat's own
## `add()`), returning its index -- for opposing bodies a test needs without a card.
static func add_unit(ms: MatchState, index: int, kind_name: StringName) -> int:
	var player := D.seat(ms, index)
	var kind_index := ms.balance.kind_index_of(kind_name)
	player.units.add(ms.balance.kind_at(kind_index).max_hp, kind_index)
	return player.units.size() - 1


## One tick with `p1` / `p2` intents, pushing `ranges` (an Array of [slot, index]) as this tick's
## heal-range facts first -- the runner's step-2 position.
static func advance_with_ranges(ms: MatchState, ranges: Array, p1: InputIntent = null,
		p2: InputIntent = null) -> void:
	for push: Array in ranges:
		ms.push_heal_range(int(push[0]), int(push[1]))
	D.advance(ms, p1 if p1 != null else InputIntent.new(), p2 if p2 != null else InputIntent.new())


## Push a PULSE-RING fact: seat `caster`'s ring holds the other seat's body at `target_index` (-1 = hero),
## the body-to-caster bearing `dir`.
static func push_ring(ms: MatchState, caster: int, target_index: int, dir: Vector2 = Vector2.DOWN) -> void:
	ms.push_contact([caster, -1], [1 - caster, target_index], D.seat(ms, caster).hero.attack_index, dir,
			MatchState.CONTACT_PULSE)


## Seat `index` STAGES Wrath and activates it with `extra_orbs` blue orbs held beyond the activation orb.
## Returns whether the cast started.
static func cast_wrath(ms: MatchState, index: int, extra_orbs: int = 0, slot: int = 2) -> bool:
	var player := D.seat(ms, index)
	D.set_mana(ms, player, D.MAX_MANA)
	D.stage(ms, index, WRATH, slot)
	D.set_orbs(ms, player, 0, 1 + extra_orbs, 0)
	D.activate(ms, index)
	return player.is_casting()


## Run seat `caster`'s Wrath windup to its strike, pushing the ring facts `ring` (Array of
## [target_index, dir]) on EVERY tick (the runner's own every-tick gather) and `p_other` to the other seat.
static func run_windup(ms: MatchState, caster: int, ring: Array, other: InputIntent = null) -> void:
	var player := D.seat(ms, caster)
	for _t in WINDUP_TICKS + 2:
		if not player.is_casting():
			break
		for fact: Array in ring:
			push_ring(ms, caster, int(fact[0]), fact[1] as Vector2)
		if caster == 0:
			D.advance(ms, InputIntent.new(), other if other != null else InputIntent.new())
		else:
			D.advance(ms, other if other != null else InputIntent.new(), InputIntent.new())
