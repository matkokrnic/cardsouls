extends SceneTree

## Story 4-3e (AC 1, AC 2, AC 3, AC 8): A SUMMONED UNIT APPEARS BEHIND THE HERO THAT SUMMONED IT,
## WHEREVER THAT HERO IS STANDING -- and when that spot is taken, the search walks OUTWARD AND
## BACKWARD until it finds a free one rather than dropping the cast.
##
## THE DEFECT THIS PINS. Until this story every summoned unit landed on a per-slot ROW frozen into
## the runner (`UNIT_ROW_X = [-5.5, 5.5]`, `UNIT_ROW_Z_START = -2.1`, `UNIT_ROW_SPACING = 1.4`).
## That row only LOOKED hero-relative while both heroes stood on their authored spawns; heroes have
## moved freely since 1-2, so a player who walked anywhere got their minion delivered to a fixed
## corner of the arena. This file summons from a hero that has been moved AND turned, and measures
## where the unit actually lands.
##
## EVERY ASSERTION IS AN EFFECT. The unit's `global_position` on the first frame its actor exists,
## compared against the hero's own live position on that same frame. Nothing here reads a constant
## to check that a constant is used, and nothing reads the source of `match_runner.gd`.
##
## THE SPAWN POSITION IS SAMPLED ON THE FRAME THE ACTOR APPEARS, not at a fixed later frame: the
## unit begins approaching its target within a few ticks of spawning, so a late sample would
## measure where it walked to, not where it was placed.
##
## PHASE 2 IS THE OUTWARD SEARCH, and it needs only ONE body to be a real test of it. A unit pinned
## exactly on the computed base spot blocks ring 0 outright, and -- because the clearance radius
## exceeds one ring step -- it also blocks EVERY candidate of ring 1, so the second summon can only
## resolve by walking out to a further ring. The pin is re-applied every frame across the second
## cast, or the blocker would simply walk away and free the spot before the cast resolved.
##
##   WHAT THIS FILE CANNOT SEE: whether the result LOOKS right on screen -- that a minion popping
##   in behind you reads as your own action rather than as scenery. That is the operator's eye at
##   Live Smoke, and it is why Live Smoke point 1 exists.
##
## NAMED MUTATIONS, re-derived against the shipped code:
##   AC 1 hero-relativity -- restore the frozen row (any absolute per-slot coordinate) in
##     `_spawn_missing_unit_actors`. `_tracks_hero` goes false: the unit lands at the row, metres
##     from a hero standing at (2, -6).
##   AC 1 rear half-space -- flip the sign of `_rear_direction`'s return. `_behind` goes false on
##     both phases: the unit appears between the summoning hero and its opponent.
##   AC 2/AC 3 clearance -- drop the occupancy test (accept ring 0 unconditionally). Phase 2's
##     `_cleared_blocker` goes false: the second unit spawns inside the pinned first one.
##
## Run: godot --headless --path . --script res://test/integration/test_unit_spawn_placement_live.gd

## The hero is moved AND turned before the first cast. Non-origin, off both authored spawns, and
## nowhere near the old row -- so "landed behind the hero" and "landed on the old row" cannot both
## be true of the same measurement.
const HERO_MOVED_TO := Vector3(2.0, 1.0, -6.0)
const HERO_TURNED_TO := 1.1

## The old frozen row's first slot-0 coordinate. Kept as an explicit NEGATIVE claim: the unit must
## not land there. A transcription, deliberately -- it names the DELETED scheme, so it can never
## drift with the shipped one.
const OLD_ROW_SPOT := Vector3(-5.5, 0.0, -2.1)
const OLD_ROW_CLEARANCE := 2.0

const ARM_FRAME := 6
const CONFIRM_FRAME := 12
const RELEASE_FRAME := 16
const PIN_FRAME := 26
const ARM2_FRAME := 30
const CONFIRM2_FRAME := 36
const RELEASE2_FRAME := 40
const REPORT_FRAME := 70

## How far a measured spot may sit from the spot the shipped geometry predicts. The hero is
## stationary across the sample, so this is float slop plus at most one tick of `move_and_slide`
## settling, not a tuning knob.
const PLACEMENT_EPS := 0.05
## Exactly the ground the runner spawns onto (AC 8). `test_unit_vertical_alignment.gd` owns the
## cross-check against main.tscn's actual ground surface; this is the live counterpart of it.
const GROUND_EPS := 0.001

var _frames := 0
var _runner: Node
var _state: MatchState
var _armed_action := &""
var _slot_chosen := false
var _detail := ""

var _behind_distance := 0.0
var _clearance := 0.0

## Phase 1 evidence.
var _spawn1: Vector3 = Vector3.INF
var _hero_at_spawn1: Vector3 = Vector3.INF
var _behind1 := false
var _tracks_hero := false
var _off_old_row := false
var _on_ground := false

## Phase 2 evidence.
var _blocker_spot: Vector3 = Vector3.INF
var _pinning := false
var _spawn2: Vector3 = Vector3.INF
var _hero_at_spawn2: Vector3 = Vector3.INF
var _behind2 := false
var _cleared_blocker := false
var _walked_outward := false
var _not_dropped := false


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _runner == null or _state == null:
			return _fail("missing: runner=%s state=%s" % [_runner, _state])
		_behind_distance = _runner.SPAWN_BEHIND_DISTANCE
		_clearance = _runner.SPAWN_CLEARANCE_RADIUS
	if _frames == 2:
		_state.p1.mana.add(_state.p1.mana.get_maximum())
		if not _state.flags.minions:
			return _fail("the authored FeatureFlags has minions OFF -- this test cannot summon")
		# THE WHOLE SETUP: P1's hero is somewhere it was never authored to be, and facing somewhere
		# else again. Position is actor-owned (`4-1/R12`), so this is a presentation-side setup step
		# and touches no state. The ROTATION is here to make one thing explicit -- placement is
		# computed from hero->OPPONENT, never from the hero's heading (AC 5 leaves facing alone), so
		# turning the hero must change nothing about where the unit lands.
		var p1_hero: Node3D = _runner._p1_hero
		p1_hero.global_position = HERO_MOVED_TO
		p1_hero.rotation.y = HERO_TURNED_TO
	if _frames == 3:
		_slot_chosen = _choose_a_summoning_slot()
		if not _slot_chosen:
			return _fail("no summoning card in the dealt hand: %s" % str(_state.p1.hand.to_array()))

	if _frames == ARM_FRAME:
		Input.action_press(&"p1_cast_mode")
	if _frames == ARM_FRAME + 1:
		Input.action_press(_armed_action)
	if _frames == ARM_FRAME + 2:
		Input.action_release(_armed_action)
	if _frames == CONFIRM_FRAME:
		Input.action_press(&"p1_cast_confirm")
	if _frames == CONFIRM_FRAME + 2:
		Input.action_release(&"p1_cast_confirm")
	if _frames == RELEASE_FRAME:
		Input.action_release(&"p1_cast_mode")

	# --- PHASE 1 SAMPLE: the frame the first actor exists, before it has walked anywhere. ---
	if _spawn1 == Vector3.INF and _live_actors() >= 1:
		_spawn1 = _actor_at(0).global_position
		_hero_at_spawn1 = (_runner._p1_hero as Node3D).global_position
		_measure_phase_one()

	# --- PIN THE BLOCKER on the base spot the NEXT cast will compute, and hold it there. ---
	if _frames >= PIN_FRAME and _frames <= RELEASE2_FRAME and _spawn1 != Vector3.INF:
		if not _pinning:
			_blocker_spot = _base_spot()
			_pinning = true
		var blocker: Node3D = _actor_at(0)
		if blocker != null:
			blocker.global_position = _blocker_spot

	if _frames == PIN_FRAME + 1:
		_state.p1.mana.add(_state.p1.mana.get_maximum())
		_slot_chosen = _choose_a_summoning_slot()
	if _frames == ARM2_FRAME and _slot_chosen:
		Input.action_press(&"p1_cast_mode")
	if _frames == ARM2_FRAME + 1 and _slot_chosen:
		Input.action_press(_armed_action)
	if _frames == ARM2_FRAME + 2:
		Input.action_release(_armed_action)
	if _frames == CONFIRM2_FRAME:
		Input.action_press(&"p1_cast_confirm")
	if _frames == CONFIRM2_FRAME + 2:
		Input.action_release(&"p1_cast_confirm")
	if _frames == RELEASE2_FRAME:
		Input.action_release(&"p1_cast_mode")

	# --- PHASE 2 SAMPLE: same rule, the frame the second actor exists. ---
	if _spawn1 != Vector3.INF and _spawn2 == Vector3.INF and _live_actors() >= 2:
		_spawn2 = _actor_at(1).global_position
		_hero_at_spawn2 = (_runner._p1_hero as Node3D).global_position
		_measure_phase_two()

	if _frames == REPORT_FRAME:
		return _report()
	return false


## The base spot the placement routine computes for P1 right now, derived the way the shipped
## routine derives it: `SPAWN_BEHIND_DISTANCE` along the away-from-opponent axis, at ground level.
func _base_spot() -> Vector3:
	var hero: Vector3 = (_runner._p1_hero as Node3D).global_position
	var opponent: Vector3 = (_runner._p2_hero as Node3D).global_position
	var away := Vector2(hero.x - opponent.x, hero.z - opponent.z).normalized()
	return Vector3(hero.x + away.x * _behind_distance, 0.0, hero.z + away.y * _behind_distance)


func _measure_phase_one() -> void:
	# AC 1, the REAR HALF-SPACE: the unit's displacement from its own hero has a NEGATIVE component
	# along hero->opponent. This is the claim that a summon never appears in the fighting space.
	_behind1 = _rear_component(_spawn1, _hero_at_spawn1) < 0.0
	if not _behind1:
		_detail += " phase1_not_behind(rear=%.3f);" % _rear_component(_spawn1, _hero_at_spawn1)
	# AC 1, HERO-RELATIVE: the spot IS the base spot for the hero's live position -- so it moved
	# with the hero rather than staying where main.tscn once put a row.
	var expected := _base_spot()
	_tracks_hero = _planar(_spawn1, expected) <= PLACEMENT_EPS
	if not _tracks_hero:
		_detail += " phase1_off_base(spawn=%s expected=%s delta=%.3f);" % [
			str(_spawn1), str(expected), _planar(_spawn1, expected)]
	# The same claim from the other side, against the scheme this story DELETED.
	_off_old_row = _planar(_spawn1, OLD_ROW_SPOT) > OLD_ROW_CLEARANCE
	if not _off_old_row:
		_detail += " phase1_on_old_row(dist=%.3f);" % _planar(_spawn1, OLD_ROW_SPOT)
	# AC 8: ground level, and NOT the hero's y (the hero root is its body CENTRE, sitting at 1.0).
	_on_ground = absf(_spawn1.y) <= GROUND_EPS
	if not _on_ground:
		_detail += " phase1_floating(y=%.4f hero_y=%.4f);" % [_spawn1.y, _hero_at_spawn1.y]


func _measure_phase_two() -> void:
	_not_dropped = _state.p1.units.size() >= 2
	if not _not_dropped:
		_detail += " phase2_cast_dropped(board=%d);" % _state.p1.units.size()
	_behind2 = _rear_component(_spawn2, _hero_at_spawn2) < 0.0
	if not _behind2:
		_detail += " phase2_not_behind(rear=%.3f);" % _rear_component(_spawn2, _hero_at_spawn2)
	# AC 2/AC 3: the walk found a candidate CLEAR of the blocker rather than stacking on it.
	var gap := _planar(_spawn2, _blocker_spot)
	_cleared_blocker = gap >= _clearance - PLACEMENT_EPS
	if not _cleared_blocker:
		_detail += " phase2_overlaps_blocker(gap=%.3f clearance=%.3f);" % [gap, _clearance]
	# AC 2: it got there by stepping OUTWARD from the base spot -- the ring walk actually ran.
	_walked_outward = _planar(_spawn2, _base_spot()) > PLACEMENT_EPS
	if not _walked_outward:
		_detail += " phase2_took_occupied_base(delta=%.3f);" % _planar(_spawn2, _base_spot())


## The component of `spot - hero` along hero->opponent. Negative means BEHIND the hero.
func _rear_component(spot: Vector3, hero: Vector3) -> float:
	var opponent: Vector3 = (_runner._p2_hero as Node3D).global_position
	var toward := Vector2(opponent.x - hero.x, opponent.z - hero.z).normalized()
	return Vector2(spot.x - hero.x, spot.z - hero.z).dot(toward)


func _planar(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _live_actors() -> int:
	var total := 0
	for unit: Node in _runner._unit_actors[0]:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			total += 1
	return total


func _actor_at(index: int) -> Node3D:
	var actors: Array = _runner._unit_actors[0]
	if index >= actors.size():
		return null
	var unit: Node = actors[index]
	return unit as Node3D if is_instance_valid(unit) else null


func _report() -> bool:
	var ok := _slot_chosen and _spawn1 != Vector3.INF and _spawn2 != Vector3.INF \
			and _behind1 and _tracks_hero and _off_old_row and _on_ground \
			and _not_dropped and _behind2 and _cleared_blocker and _walked_outward
	if _spawn1 == Vector3.INF:
		_detail += " phase1_never_spawned;"
	if _spawn2 == Vector3.INF:
		_detail += " phase2_never_spawned(board=%d actors=%d);" % [
			_state.p1.units.size(), _live_actors()]
	print("unit_spawn_placement_live: hero=%s spawn1=%s behind=%s tracks_hero=%s off_old_row=%s "
			% [str(_hero_at_spawn1), str(_spawn1), _behind1, _tracks_hero, _off_old_row]
			+ "on_ground=%s | blocker=%s spawn2=%s not_dropped=%s behind=%s cleared=%s walked=%s%s"
			% [_on_ground, str(_blocker_spot), str(_spawn2), _not_dropped, _behind2,
				_cleared_blocker, _walked_outward, _detail])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false


func _fail(message: String) -> bool:
	print(message)
	print("RESULT: FAIL")
	quit(1)
	return false


## The first dealt slot whose authored card carries a `summon_*` effect -- test_unit_approach_live
## .gd's chooser verbatim. Re-run before the SECOND cast, because the first consumed its slot.
func _choose_a_summoning_slot() -> bool:
	var db := root.get_node_or_null("/root/CardDatabase")
	if db == null:
		return false
	var hand := _state.p1.hand.to_array()
	for index in hand.size():
		if _state.p1.hand.is_slot_empty(index):
			continue
		var card := db.get_card(hand[index]) as CardData
		if card == null or card.basic_effect == null:
			continue
		# Story 4-4 (AC 1): MINION-summoning cards ONLY. Before this story every `summon_*` id
		# resolved to one uniform unit, so any of them served. Three of them now summon TOTEMS --
		# which stand still (`4-4/R12`), carry no animation rig, and in the Combat totem's case fire
		# a projectile instead of swinging -- so a test that measures MINION behaviour must not have
		# its subject chosen by the shuffle. The exclusion reads the resolver's OWN table rather than
		# a second list of totem ids, so the two can never disagree.
		var effect_id: StringName = card.basic_effect.effect_id
		var is_summon := String(effect_id).begins_with(CardEffectResolver.PREFIX_SUMMON)
		var is_totem := CardEffectResolver.SUMMON_KINDS.has(effect_id)
		if is_summon and not is_totem:
			var action := StringName("p1_card_%d" % (index + 1))
			if not InputMap.has_action(action):
				return false
			_armed_action = action
			return true
	return false
