extends SceneTree

## Story 4-3 (AC 7, `4-3/R9`): THE GREY BOX WALKS TO ITS TARGET, STOPS SHORT OF IT, AND STANDS IN A
## HERO'S WAY -- driven through the real runner, in the real scene, against the AUTHORED balance.
##
## WHY THIS EXISTS AS A MACHINE TEST AT ALL: the headless state suite structurally cannot see it
## (`3-0b/R34`'s blind spot). `test_targeting_service.gd` proves the STATE contract -- a `[slot,
## index]` pair is stored at a throttle boundary -- and every word of that stays true of a match in
## which no node ever moved. Position is actor-owned (`4-1/R12`), so the ONLY place the approach is
## observable is a live `global_position`, and that is what this file reads.
##
## THE NON-VACUITY PAIR IS THE POINT (AC 3/AC 7): a unit that teleported once and a unit that never
## started BOTH have to fail here, so MOVED and STOPPED are measured separately, tick-over-tick, and
## the run passes only if both hold. The stop is measured against the AUTHORED `unit_stop_distance`
## rather than against "it eventually quit moving", so a unit stopped by an obstacle instead of by
## the rule fails too.
##
## IT FAILS IF EITHER AUTHORED VALUE WERE 0, which is what makes it prove the fields are READ FROM
## AUTHORING and not from `BalanceConfig`'s 0.0 script default (AC 6's positive control, half b):
## at `unit_move_speed = 0` nothing ever moves and the MOVED half fails; at `unit_stop_distance = 0`
## the unit walks into its target until the two bodies wedge, so the measured final distance is a
## body-contact distance and not the authored one, and the STOPPED half fails.
##
## Run: godot --headless --path . --script res://test/integration/test_unit_approach_live.gd

## The cast sequence is `test_unit_aim_live.gd`'s verbatim, including its reason for HOLDING presses
## across frames rather than pulsing them: the runner's `_physics_process` and this script's are two
## callbacks in an unspecified order, so a one-frame pulse can be released before the runner samples
## the just_pressed edge.
const ARM_FRAME := 4
const CONFIRM_FRAME := 10
const CONFIRM_RELEASE_FRAME := 14
const SPAWN_CHECK_FRAME := 18
## Comfortably past the authored 12-tick retarget cadence, so a boundary has certainly passed and
## the unit has a target to walk toward -- and early enough that it is still far outside
## `unit_stop_distance` (it spawns ~8.7 units from P2's hero and closes 0.05 per tick).
const MOVE_SAMPLE_FRAME := 45
## Arrival needs ~145 ticks at the authored speed; this leaves a wide margin, and the stop is
## asserted against the authored distance rather than against having stopped.
const STOP_SAMPLE_FRAME := 260
## The hero walks into the parked unit from here. 130 ticks at the authored move_speed carries it
## ~10.8 units from x -3, which is well past the unit's parked x if nothing stopped it.
const WALK_START_FRAME := 268
const WALK_END_FRAME := 398

## Planar distance moved in ONE tick at the authored speed is 0.05. "Moving" is asserted well above
## float noise and well below one tick's travel; "stopped" well below it.
const MOVED_EPSILON := 0.02
const STOPPED_EPSILON := 0.005
## The unit may overshoot its stop test by at most one tick of travel (0.05), and must not stop
## short of the band by more than that -- a unit halted early by something other than the rule fails.
const STOP_BAND := 0.08
const YAW_EPSILON := 0.01
## Body half-extents, planar: the hero's `Collision` box is 1 x 2 x 1 (`hero.tscn:20-21`) and the
## unit's is 0.6 x 1.2 x 0.6. Two convex boxes that are not overlapping can never have their centres
## closer than the sum of their INRADII (0.5 + 0.3), whatever their yaw -- so a planar centre
## distance below this means the hero is INSIDE the unit, which is precisely "walked through".
const BODY_CONTACT_DISTANCE := 0.8
const OVERLAP_EPSILON := 0.05
## The hero must actually ARRIVE at the obstacle for "it never got inside" to mean anything: it has
## to come within a box-width of contact at some point, or the check is vacuously true of a hero
## that walked nowhere near the unit.
const REACHED_DISTANCE := 1.3

var _frames := 0
var _runner: Node
var _state: MatchState
var _armed_slot := -1
var _armed_action := &""

var _slot_chosen := false
var _spawned := false
var _speed := 0.0
var _stop_distance := 0.0

var _move_from := Vector3.ZERO
var _moved := false
var _far_while_moving := false
var _aimed_while_moving := false

var _stop_from := Vector3.ZERO
var _stopped := false
var _stopped_at_the_authored_distance := false
var _aimed_while_stopped := false

var _min_hero_gap := INF
var _hero_reached_the_unit := false
var _hero_never_inside := false
var _detail := ""


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _runner == null or _state == null:
			print("missing: runner=%s state=%s" % [_runner, _state])
			print("RESULT: FAIL")
			quit(1)
			return false
		# THE AUTHORED VALUES, read off the config the runner APPLIED -- the same handle the
		# approach step reads at point of use, so this test measures what shipped rather than a
		# constant copied into it. A zero in either is not tolerated here: it would make the
		# assertions below meaningless, and `test_balance_authoring.gd` is the permanent guard.
		_speed = _state.balance.unit_move_speed
		_stop_distance = _state.balance.unit_stop_distance
		if _speed <= 0.0 or _stop_distance <= 0.0:
			print("authored balance ships the mechanic invisible: unit_move_speed=%f "
					% _speed + "unit_stop_distance=%f" % _stop_distance)
			print("RESULT: FAIL")
			quit(1)
			return false
	if _frames == 2:
		# Mana, so the cast is affordable -- the economy is not what this test is about.
		_state.p1.mana.add(_state.p1.mana.get_maximum())
		# NON-VACUITY up front, the `test_summon_actor_live.gd` idiom: with the minion layer off
		# every summon degrades and every assertion below would "pass" for the wrong reason.
		if not _state.flags.minions:
			print("the authored FeatureFlags has minions OFF -- this test cannot summon")
			print("RESULT: FAIL")
			quit(1)
			return false
	if _frames == 3:
		_choose_a_summoning_slot()
		if not _slot_chosen:
			print("no summoning card in the dealt hand: %s" % str(_state.p1.hand.to_array()))
			print("RESULT: FAIL")
			quit(1)
			return false
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
	if _frames == CONFIRM_RELEASE_FRAME:
		Input.action_release(&"p1_cast_mode")
	if _frames == SPAWN_CHECK_FRAME:
		var unit := _first_unit_actor()
		_spawned = _state.p1.units.size() == 1 and unit != null
		if not _spawned:
			_detail += " board=%d actor=%s;" % [_state.p1.units.size(), unit]

	# ---- MOVED: a tick-over-tick delta on a real node, while beyond the stop distance. ----
	if _frames == MOVE_SAMPLE_FRAME:
		var unit := _first_unit_actor()
		if unit != null:
			_move_from = unit.global_position
	if _frames == MOVE_SAMPLE_FRAME + 1:
		var unit := _first_unit_actor()
		var target: Variant = _target_position()
		if unit == null or target == null:
			_detail += " move_sample_missing(unit=%s target=%s);" % [unit, target]
		else:
			var delta := _planar_distance(unit.global_position, _move_from)
			_moved = delta > MOVED_EPSILON
			if not _moved:
				_detail += " never_started(delta=%.4f);" % delta
			# The delta only means "approaching" if the unit was outside its stop distance when it
			# was taken -- inside it, standing still would be the CORRECT behaviour.
			var distance := _planar_distance(unit.global_position, target)
			_far_while_moving = distance > _stop_distance
			if not _far_while_moving:
				_detail += " already_arrived(distance=%.3f);" % distance
			_aimed_while_moving = _is_facing(unit, target)
			if not _aimed_while_moving:
				_detail += " lost_facing_while_moving;"

	# ---- STOPPED: no longer moving, AND parked at the AUTHORED distance, still facing. ----
	if _frames == STOP_SAMPLE_FRAME:
		var unit := _first_unit_actor()
		if unit != null:
			_stop_from = unit.global_position
	if _frames == STOP_SAMPLE_FRAME + 1:
		var unit := _first_unit_actor()
		var target: Variant = _target_position()
		if unit == null or target == null:
			_detail += " stop_sample_missing(unit=%s target=%s);" % [unit, target]
		else:
			var delta := _planar_distance(unit.global_position, _stop_from)
			_stopped = delta < STOPPED_EPSILON
			if not _stopped:
				_detail += " still_moving(delta=%.4f);" % delta
			var distance := _planar_distance(unit.global_position, target)
			_stopped_at_the_authored_distance = absf(distance - _stop_distance) <= STOP_BAND
			if not _stopped_at_the_authored_distance:
				_detail += " wrong_distance(distance=%.3f authored=%.3f);" % [
					distance, _stop_distance]
			_aimed_while_stopped = _is_facing(unit, target)
			if not _aimed_while_stopped:
				_detail += " lost_facing_while_stopped;"

	# ---- BLOCKED (AC 4): P1's hero walks into P1's own parked unit. Shipped defaults, no kill,
	#      no slot_controller_kinds flip -- `R-D6` is NOT spent by this story (`4-3/R14`).
	#      `p1_move_right` is world +x (pinned by test_hero_movement.gd), and the unit parks
	#      between P1's hero and P2's, so the hero walks straight at it. ----
	if _frames == WALK_START_FRAME:
		Input.action_press(&"p1_move_right")
	if _frames > WALK_START_FRAME and _frames <= WALK_END_FRAME:
		var unit := _first_unit_actor()
		var hero: Node3D = _runner._p1_hero
		if unit != null and hero != null:
			_min_hero_gap = minf(_min_hero_gap,
					_planar_distance(hero.global_position, unit.global_position))
	if _frames == WALK_END_FRAME:
		Input.action_release(&"p1_move_right")
		# The pair, and neither half means anything alone: the hero must have ARRIVED at the unit
		# (or "never inside" is true of a hero that walked elsewhere), and must never have been
		# INSIDE it (which is what walking through a body looks like frame by frame).
		_hero_reached_the_unit = _min_hero_gap <= REACHED_DISTANCE
		_hero_never_inside = _min_hero_gap >= BODY_CONTACT_DISTANCE - OVERLAP_EPSILON
		if not _hero_reached_the_unit:
			_detail += " hero_never_arrived(min_gap=%.3f);" % _min_hero_gap
		if not _hero_never_inside:
			_detail += " hero_walked_through(min_gap=%.3f contact=%.3f);" % [
				_min_hero_gap, BODY_CONTACT_DISTANCE]
		var ok := _slot_chosen and _spawned \
				and _moved and _far_while_moving and _aimed_while_moving \
				and _stopped and _stopped_at_the_authored_distance and _aimed_while_stopped \
				and _hero_reached_the_unit and _hero_never_inside
		print("unit_approach_live: speed=%.2f stop=%.2f spawned=%s moved=%s far_while_moving=%s "
				% [_speed, _stop_distance, _spawned, _moved, _far_while_moving]
				+ "stopped=%s at_authored_distance=%s facing=%s/%s reached=%s never_inside=%s "
				% [_stopped, _stopped_at_the_authored_distance, _aimed_while_moving,
					_aimed_while_stopped, _hero_reached_the_unit, _hero_never_inside]
				+ "min_gap=%.3f%s" % [_min_hero_gap, _detail])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false


## The world position of the target the unit ACQUIRED, resolved the way the runner resolves it --
## via the state-side `[slot, index]` pair, not by assuming which node it is. P2's board is empty,
## so `standard`'s units-first ordering falls through to the opposing HERO, but this reads the pair
## rather than hardcoding that.
func _target_position() -> Variant:
	if _state.p1.units.size() < 1:
		return null
	var target_slot := _state.p1.units.target_slot_at(0)
	if target_slot == TargetingService.NO_TARGET_SLOT:
		return null
	return _runner._target_world_position(target_slot, _state.p1.units.target_index_at(0))


## The AC 3 facing half: the unit keeps facing its target throughout the approach. Recomputed from
## the two live positions, `test_unit_aim_live.gd`'s comparison verbatim -- both nodes move, so a
## hardcoded heading would be measuring the wrong thing.
func _is_facing(unit: Node3D, target: Variant) -> bool:
	var to: Vector3 = target
	var planar := Vector2(to.x - unit.global_position.x, to.z - unit.global_position.z)
	if planar.is_zero_approx():
		return false
	var expected := atan2(planar.x, planar.y) + PI
	return absf(angle_difference(unit.global_rotation.y, expected)) <= YAW_EPSILON


func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The first dealt slot whose authored card carries a `summon_*` effect -- `test_summon_actor_live
## .gd`'s chooser verbatim, including its reason for reaching the library through the autoload NODE
## (this file IS the `--script` main loop, compiled before the autoloads register).
func _choose_a_summoning_slot() -> void:
	var db := root.get_node_or_null("/root/CardDatabase")
	if db == null:
		return
	var hand := _state.p1.hand.to_array()
	for index in hand.size():
		if _state.p1.hand.is_slot_empty(index):
			continue
		var card := db.get_card(hand[index]) as CardData
		if card == null or card.basic_effect == null:
			continue
		if String(card.basic_effect.effect_id).begins_with(CardEffectResolver.PREFIX_SUMMON):
			_armed_slot = index
			_armed_action = StringName("p1_card_%d" % (index + 1))
			_slot_chosen = InputMap.has_action(_armed_action)
			return


## The first live UnitActor found by WALKING THE TREE rather than by reading the runner's
## bookkeeping array -- the `test_summon_actor_live.gd` reason: a runner that appended to its array
## and forgot to `add_child` would otherwise report success with nothing on screen. Applies with
## full force here, where the whole claim is that a node in the tree MOVED.
func _first_unit_actor() -> UnitActor:
	return _find_unit_actor(root)


func _find_unit_actor(node: Node) -> UnitActor:
	if node is UnitActor and not node.is_queued_for_deletion():
		return node
	for child in node.get_children():
		var found := _find_unit_actor(child)
		if found != null:
			return found
	return null
