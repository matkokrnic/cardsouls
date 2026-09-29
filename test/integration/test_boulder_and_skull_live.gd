extends SceneTree

## STORY 6-5e: THE TWO THINGS UNIT FIXTURES CANNOT SEE -- the SHIPPED DATA WIRING and the SKULL'S LAUNCH
## POSITION. Both are the runtime-composition blind spot `3-0b/R34` names: state and runner each correct,
## wired to each other wrongly, with nothing in the headless suite able to fail.
##
## PART A -- THE BOULDER MUST EXIST IN THE LIVE MAPS, AND BE CLEARABLE (AC 4/AC 16/AC 21).
## `MatchState._boulder_card_id` is DERIVED by scanning the injected basic-effect map for the
## cover-clearing effect, and a Mode ① press on a covered slot prices through the injected COST map. Every
## headless fixture injects maps it wrote itself, so the whole suite would stay green if the shipped
## `data/cards/boulder.tres` were absent from what the RUNNER injects -- and the shipped game would then
## plant nothing, or plant something nobody could clear. Boulder is in NO DECK, so the usual
## "it is in the composition, therefore it is in the maps" argument does not apply to it: the maps are
## derived from the WHOLE LIBRARY and that is the only reason it is there. Part A proves the whole path on
## the real authored content: the real `CardDatabase`, the real `balance_config.tres`, the real deck list,
## the maps derived the way `MatchRunner` derives them -- a Rocksling cast fires the authored stones, a
## landed stone plants a Boulder, and a Mode ① press clears it for the authored 2 mana with the covered card
## restored.
##
## PART B -- THE SKULL LEAVES THE MINION'S BODY, NOT THE CASTER'S FEET (AC 3a/AC 31). `add_minion_shot`
## stores the dying minion's BOARD INDEX and relies on `MatchRunner._projectile_launch_position` resolving
## it to that unit's actor, with a caster's-feet fallback when the actor is gone. Position is actor-owned
## and never enters `src/state/`, so NO headless test can measure it: a skull launching from the caster
## would pass every state assertion in the suite while being exactly the defect AC 31 forbids. Part B
## measures the spawned actor's own `global_position`, and it measures BOTH arms -- the minion's body and
## the fallback -- because a test that only saw the first could pass on a runner that ignored the index.
##
## THE RECORD IS APPENDED STRAIGHT ONTO THE BOARD for Part B, `test_projectile_flight_live.gd`'s stated
## precedent ("the runner spawns an actor per BOARD RECORD, so a record appended here exercises exactly the
## spawn path a cast would"): what is under test is the RUNNER's resolution of `source_index`, and driving a
## real Corpse Bomb activation would make the measurement depend on the deal and the orb bank as well.
##
## Run: godot --headless --path . --script res://test/integration/test_boulder_and_skull_live.gd

const CARDS_DIR := "res://data/cards/"
const BALANCE_PATH := "res://data/balance/balance_config.tres"
const DECK_PATH := "res://data/decks/deck_1.tres"
const ROCKSLING_CARD := &"rocksling"
const BOULDER_CARD := &"boulder"
const CORPSE_BOMB_EFFECT := &"corpse_bomb"
const MINION_KIND := &"minion"

## Part B's lane. The minion stands FAR from the caster on a single axis, so "it launched from the minion"
## and "it launched from the hero" are metres apart rather than a tolerance argument.
const P1_X := -8.0
const MINION_X := 9.0
## How close the spawned shot must sit to the body it left.
##
## MEASURED AND CORRECTED: the first value was 0.25 and BOTH arms read 0.267 m -- the skull from its minion
## and the fallback from its hero, the SAME figure, which is a constant spawn nudge along the launch heading
## (`ProjectileActor.launch_toward`) rather than a mis-resolved source. 0.5 m keeps a gross error caught
## while leaving that offset room; the load-bearing assertions are the RELATIVE ones below, which no spawn
## offset can satisfy by accident.
const POSITION_TOLERANCE := 0.5
## Quiet frames after the last measurement.
const TAIL := 8
const DEADLINE := 400

var _frames := 0
var _runner: Node = null
var _state: MatchState = null
var _failures: Array[String] = []
var _detail := ""

var _part_a_done := false
var _db: Node = null
var _minion_position := Vector3.ZERO
var _skull_position := Vector3.ZERO
var _fallback_position := Vector3.ZERO
var _hero_position := Vector3.ZERO


func _initialize() -> void:
	# PART A needs the CardDatabase AUTOLOAD, which is only in the tree after one frame -- so it runs at
	# frame 2 below, not here. It lives in `test/integration/` rather than `test/state/` for exactly that
	# reason: the headless state harness runs in `_initialize()` with no autoload and no frame.

	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _fail(message: String) -> bool:
	_check(false, message)
	return _finish()


# ------------------------------------------------------------------ PART A: the shipped data wiring

func _run_part_a(_database: Node) -> void:
	var balance: BalanceConfig = load(BALANCE_PATH)
	if balance == null:
		_check(false, "PART A: %s did not load" % BALANCE_PATH)
		return
	# THE AUTHORED SLOW IS READ, NOT ASSUMED: S1's knob must actually be in the shipped file, or AC 37a
	# ships switched off and nothing would fail.
	_check(balance.boulder_slow_per_boulder > 0.0,
		"PART A: `boulder_slow_per_boulder` is authored positive in %s (S1, AC 37a) -- got %f"
				% [BALANCE_PATH, balance.boulder_slow_per_boulder])
	var boulder: CardData = load(CARDS_DIR + "boulder.tres")
	if boulder == null:
		_check(false, "PART A: data/cards/boulder.tres did not load -- the shipped game has no Boulder")
		return
	_check(boulder.id == BOULDER_CARD, "PART A: the authored Boulder's id is `boulder`")
	_check(boulder.color == Enums.CardColor.COLORLESS,
		"PART A: Boulder authors the COLOURLESS ordinal (AC 4, `6-5e/R26`) -- got %d" % boulder.color)
	_check(boulder.pitch_effect == null and boulder.pitch_condition == null,
		"PART A: Boulder authors NO Mode 4 at all (ruling 7)")
	if boulder.cast_condition == null:
		_check(false, "PART A: Boulder authors no cast condition -- it could never be played")
		return
	_check(is_equal_approx(boulder.cast_condition.mana_cost, 2.0),
		"PART A: Boulder is priced at the authored 2 mana (AC 20) -- got %f"
				% boulder.cast_condition.mana_cost)
	_check(boulder.basic_effect != null
			and CardEffectResolver.clears_cover(boulder.basic_effect),
		"PART A: Boulder's authored basic effect is the one the resolver knows as cover-clearing (AC 28a)")
	# THE DECK LIST MUST NOT NAME IT (AC 22): the exclusion is by construction, and this is the assertion
	# that makes "by construction" checkable rather than a claim.
	var deck_list: DeckList = load(DECK_PATH)
	if deck_list != null:
		_check(not deck_list.card_ids.has(BOULDER_CARD),
			"PART A: Boulder is in NO deck list -- it can only enter a hand from a landed stone (AC 22)")
	var rocksling: CardData = load(CARDS_DIR + "rocksling.tres")
	if rocksling == null or rocksling.basic_effect == null:
		_check(false, "PART A: the authored Rocksling card or its basic effect is missing")
		return
	var effect := rocksling.basic_effect
	_check(effect.boulders_per_cast > 0,
		"PART A: `rocksling.tres` authors a positive `boulders_per_cast` (AC 1) -- got %d"
				% effect.boulders_per_cast)
	_check(effect.damage_amount > 0.0,
		"PART A: ...and a positive per-stone damage -- got %f" % effect.damage_amount)
	_check(effect.travel_budget > 0.0 and effect.launch_speed > 0.0,
		"PART A: ...and a real flight profile, or the stone never leaves the caster")
	# --- the whole path, on the real content and the real derivations ---------------------------
	var ms := MatchState.new(MatchParams.new(4242))
	ms.apply_balance(balance)
	ms.inject_feature_flags(_shipped_flags())
	var composition := _shipped_composition(deck_list)
	if composition.is_empty():
		_check(false, "PART A: the authored deck list expanded to nothing")
		return
	ms.inject_deck(composition)
	ms.inject_card_costs(_derived_costs())
	ms.inject_card_effects(_derived_effects())
	ms.inject_pitch_costs(_derived_pitch_costs())
	ms.inject_pitch_effects(_derived_pitch_effects())
	_advance(ms)
	# THE DERIVED BOULDER ID -- the single fact Part A exists for. Everything below is downstream of it.
	_check(ms._boulder_card_id == BOULDER_CARD,
		("PART A: MatchState derived the Boulder card id from the maps the RUNNER builds -- got '%s'. "
			+ "An empty id here means the shipped game plants nothing, silently, with the whole "
			+ "headless suite green") % ms._boulder_card_id)
	if ms._boulder_card_id != BOULDER_CARD:
		return
	# Cast Rocksling for real: poke the cast the way the press seat arms it, then let it strike.
	ms.p1.mana.add(balance.max_mana)
	ms.p1.start_cast(ROCKSLING_CARD, TimingWindow.seconds_to_ticks(effect.cast_seconds),
			Enums.ModeKind.BASIC, 1, TargetingService.HERO_INDEX, 0.0)
	for _t in TimingWindow.seconds_to_ticks(effect.cast_seconds) + 1:
		_advance(ms)
	_check(ms.p1.projectiles.size() >= 1,
		"PART A: the shipped Rocksling fired a stone -- %d on the board" % ms.p1.projectiles.size())
	if ms.p1.projectiles.is_empty():
		return
	# Land stone 0 on P2's hero, through the one intake the runner uses.
	var attacker: Array[int] = [0, MatchState.projectile_attacker_index(0)]
	var address: Array[int] = [1, TargetingService.HERO_INDEX]
	ms.push_contact(attacker, address, ms.p1.projectiles.flight_ticks_at(0),
			ms.p2.hero.facing, MatchState.CONTACT_STRIKE)
	_advance(ms)
	_check(ms.p2.hand.cover_count() == 1,
		"PART A: a landed stone planted ONE Boulder on the shipped configuration (AC 16) -- got %d"
				% ms.p2.hand.cover_count())
	if ms.p2.hand.cover_count() != 1:
		return
	var slot: int = ms.p2.hand.covered_indices()[0]
	_check(ms.p2.hand.visible_id_at(slot) == BOULDER_CARD,
		"PART A: the covered slot SHOWS the authored Boulder card")
	var beneath := ms.p2.hand.to_array()[slot]
	# Now CLEAR it, through the real Mode ① dispatch, priced out of the real cost map.
	ms.p2.mana.add(balance.max_mana)
	var mana_before := ms.p2.mana.get_current()
	var press := InputIntent.new()
	press.card_slot = slot
	press.card_mode = Enums.ModeKind.BASIC
	press.card_commit = true
	var intents: Array[InputIntent] = [InputIntent.new(), press]
	ms.advance(intents)
	ms.drain_signals()
	_check(not ms.p2.hand.is_covered(slot),
		"PART A: the Boulder was CLEARED by a real Mode 1 press on the shipped configuration (AC 21)")
	_check(is_equal_approx(mana_before - ms.p2.mana.get_current(), 2.0),
		"PART A: ...for exactly the authored 2 mana -- got %f"
				% (mana_before - ms.p2.mana.get_current()))
	_check(ms.p2.hand.to_array()[slot] == beneath,
		"PART A: ...and the covered card is back in its own slot, unmoved (AC 21)")
	_check(ms.p2.pending_draw_owed.is_empty(),
		"PART A: ...with no replacement owed (AC 21)")
	_check(not ms.p2.discard.to_array().has(BOULDER_CARD),
		"PART A: ...and the Boulder did NOT reach the discard pile (AC 22)")
	_part_a_done = true


func _shipped_flags() -> FeatureFlags:
	var flags: FeatureFlags = load("res://data/feature_flags.tres")
	if flags != null:
		return flags
	var fallback := FeatureFlags.new()
	fallback.spells = true
	fallback.minions = true
	fallback.pitch_zone = true
	return fallback


func _shipped_composition(deck_list: DeckList) -> Array[StringName]:
	var out: Array[StringName] = []
	if deck_list == null:
		return out
	for index in mini(deck_list.card_ids.size(), deck_list.copies.size()):
		var id: StringName = deck_list.card_ids[index]
		if not _db.has_card(id):
			continue
		for _copy in int(deck_list.copies[index]):
			out.append(id)
	return out


## `MatchRunner._derive_card_costs` / `_derive_card_effects` / their pitch twins, reproduced over the same
## `_db.sorted_ids()` walk. Reproduced rather than called because those are private methods on the
## runner NODE and Part A deliberately runs before any scene exists -- and because a copy that walked a
## NARROWER set than the runner does would fail the `_boulder_card_id` assertion above, which is the whole
## point: the derivation must cover the whole library, not the composition.
func _derived_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id: StringName in _db.sorted_ids():
		var card := _db.get_card(id) as CardData
		if card == null or card.cast_condition == null:
			continue
		out[id] = card.cast_condition
	return out


func _derived_effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id: StringName in _db.sorted_ids():
		var card := _db.get_card(id) as CardData
		if card == null or card.basic_effect == null:
			continue
		out[id] = card.basic_effect
	return out


func _derived_pitch_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id: StringName in _db.sorted_ids():
		var card := _db.get_card(id) as CardData
		if card == null or card.pitch_condition == null:
			continue
		out[id] = card.pitch_condition
	return out


func _derived_pitch_effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id: StringName in _db.sorted_ids():
		var card := _db.get_card(id) as CardData
		if card == null or card.pitch_effect == null:
			continue
		out[id] = card.pitch_effect
	return out


func _advance(ms: MatchState) -> void:
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()


# ---------------------------------------------------- PART B: where a skull actually leaves from

func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _runner == null or _state == null:
			return _fail("missing: runner=%s state=%s" % [_runner, _state])
		return false

	if _frames == 2:
		# PART A RUNS HERE, not in `_initialize()`: it needs the `CardDatabase` AUTOLOAD, which is in the
		# tree only once a frame has passed (`test_card_database.gd`'s own stated reason for reaching it
		# through `/root/` at frame 1 rather than by identifier). Reached as a NODE rather than by the
		# singleton identifier, which is not registered for a `--script` run at all -- measured: the
		# identifier form failed to compile the whole file.
		_db = root.get_node_or_null("/root/CardDatabase")
		if _db == null:
			return _fail("PART A: the CardDatabase autoload is not in the tree")
		_run_part_a(_db)
		# PART B's non-vacuity: the live runner must have derived the same Boulder id from the maps it
		# really injected. Part A proved the DERIVATION over a reproduced walk; this proves the RUNNER
		# does that walk -- the two halves of the wiring, and neither implies the other.
		_check(_state._boulder_card_id == BOULDER_CARD,
			("PART B: the LIVE runner's injected maps yield the Boulder card id -- got '%s'. Part A can "
				+ "only prove the derivation; this proves the runner feeds it") % _state._boulder_card_id)
		var corpse_bomb: CardEffect = load("res://data/effects/corpse_bomb.tres")
		if corpse_bomb == null or corpse_bomb.travel_budget <= 0.0:
			return _fail("PART B: corpse_bomb.tres authors no flight profile -- a skull could not fly")
		return false

	if _frames == 3:
		_p1_hero().global_position = Vector3(P1_X, 1.0, 0.0)
		var minion_kind := _state.balance.kind_index_of(MINION_KIND)
		_state.p1.units.add(_state.balance.kind_at(minion_kind).max_hp, minion_kind)
		_state.p1.units.add(_state.balance.kind_at(minion_kind).max_hp, minion_kind)
		return false

	if _frames == 5:
		var minion := _unit_actor(0, 0)
		if minion == null:
			return _fail("PART B: the runner spawned no actor for the minion record")
		# Stood far down the lane from its own hero, so the two candidate launch points are 17 m apart.
		minion.global_position = Vector3(MINION_X, minion.global_position.y, 0.0)
		return false

	if _frames == 7:
		var minion := _unit_actor(0, 0)
		if minion == null:
			return _fail("PART B: the minion actor vanished before the launch")
		_minion_position = minion.global_position
		_hero_position = _p1_hero().global_position
		# THE MINION-SOURCED SEAT, exercised exactly as Corpse Bomb exercises it: the record names the
		# board index it left. Shot 0.
		_state.p1.projectiles.add_minion_shot(1, TargetingService.HERO_INDEX,
				CORPSE_BOMB_EFFECT, 5.0, 0)
		# THE FALLBACK ARM, in the same run: a record naming a board index whose actor does NOT exist.
		# Index 1's record was added at frame 3 but the unit is freed below, so the runner must fall back
		# to the caster's feet. Shot 1.
		_state.p1.projectiles.add_minion_shot(1, TargetingService.HERO_INDEX,
				CORPSE_BOMB_EFFECT, 5.0, 99)
		return false

	if _frames == 9:
		var skull := _shot_actor(0)
		var fallback := _shot_actor(1)
		if skull == null or fallback == null:
			return _fail("PART B: the runner spawned no actor for a minion-sourced record (%s / %s)"
					% [skull, fallback])
		_skull_position = skull.global_position
		_fallback_position = fallback.global_position
		return false

	if _frames >= 9 + TAIL:
		return _finish()

	if _frames >= DEADLINE:
		return _fail("PART B: the DEADLINE was reached -- a measurement never ran")
	return false


func _finish() -> bool:
	# PART A's completion is itself asserted: a Part A that returned early left every assertion after the
	# early return unrun, and a silent skip would read as a pass.
	_check(_part_a_done, "PART A ran to completion -- an early return means assertions never ran")
	# PART B's two arms, measured on the horizontal plane: the y of a spawned shot carries the actor's own
	# authored offset and is not what AC 3a is about.
	var from_minion := _planar_gap(_skull_position, _minion_position)
	var from_hero := _planar_gap(_skull_position, _hero_position)
	_check(from_minion <= POSITION_TOLERANCE,
		("PART B: the skull launched from its OWN converted minion's position (AC 3a/AC 31) -- "
			+ "%.3f m from the minion, %.3f m from the caster") % [from_minion, from_hero])
	_check(from_hero > POSITION_TOLERANCE,
		("PART B: ...and NOT from the caster's feet -- the two candidates are %.3f m apart, so this is "
			+ "a real distinction rather than a tolerance") % _planar_gap(_minion_position,
				_hero_position))
	# THE DECISIVE FORM IS RELATIVE, for the reason recorded at `POSITION_TOLERANCE`: a constant spawn
	# offset can satisfy an absolute bound on the wrong body only if the two bodies are close together, and
	# these are 17 m apart. "Nearer the minion than the caster" is the claim AC 31 actually makes.
	_check(from_minion < from_hero,
		("PART B: the skull is NEARER its own minion than the caster -- %.3f m vs %.3f m. This is the "
			+ "form no spawn offset can pass by accident") % [from_minion, from_hero])
	var fallback_gap := _planar_gap(_fallback_position, _hero_position)
	var fallback_to_minion := _planar_gap(_fallback_position, _minion_position)
	_check(fallback_gap <= POSITION_TOLERANCE,
		("PART B: a record whose source actor is GONE falls back to the caster's feet (AC 3a) -- "
			+ "%.3f m from the hero") % fallback_gap)
	_check(fallback_gap < fallback_to_minion,
		("PART B: ...and the fallback is NEARER the caster than the minion -- %.3f m vs %.3f m. Without "
			+ "this arm a runner that ignored `source_index` entirely would pass the first assertion "
			+ "whenever the minion happened to stand near the hero") % [fallback_gap, fallback_to_minion])
	_detail = ("boulder_id=%s part_a=%s | minion=%.2f hero=%.2f skull=%.2f fallback=%.2f "
		+ "(from_minion=%.3f from_hero=%.3f fallback_to_hero=%.3f)") % [
			_state._boulder_card_id if _state != null else &"<no state>", _part_a_done,
			_minion_position.x, _hero_position.x, _skull_position.x, _fallback_position.x,
			from_minion, from_hero, fallback_gap]
	print("boulder_and_skull_live: %s" % _detail)
	if _failures.is_empty():
		print("RESULT: PASS")
		quit(0)
		return true
	for message in _failures:
		print("  [XX] %s" % message)
	print("RESULT: FAIL")
	quit(1)
	return true


## The horizontal distance only -- a spawned `ProjectileActor` carries its own authored y offset (the
## `projectile_actor.tscn` chest-height calibration), which AC 3a says nothing about.
func _planar_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _p1_hero() -> HeroActor:
	return _runner._p1_hero as HeroActor


## Read off the runner's own arrays, so the test and the runner agree about which node is which record --
## the `test_fireball_live.gd` / `test_projectile_flight_live.gd` discipline.
func _unit_actor(slot: int, index: int) -> Node3D:
	var actors: Array = _runner._unit_actors[slot]
	if index < 0 or index >= actors.size():
		return null
	var node: Node = actors[index]
	return node as Node3D if is_instance_valid(node) else null


func _shot_actor(index: int) -> Node3D:
	var actors: Array = _runner._projectile_actors[0]
	if index < 0 or index >= actors.size():
		return null
	var node: Node = actors[index]
	return node as Node3D if is_instance_valid(node) else null
