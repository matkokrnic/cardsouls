extends SceneTree

## Story 6-5a (AC 13): the summon-bearing test deck this file is re-pointed at.
const LiveSummonDeck := preload("res://test/live_summon_deck.gd")

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

## `4-3/R22`: the sample frames and the STOP_BAND used to be hand-derived literals pinned to the
## authored `unit_move_speed = 3.0` / `unit_stop_distance = 1.5` -- brittle against the melee
## retune boarded for `4-3a`. Every one of them is now COMPUTED at runtime from the authored values
## this test already reads (`_speed`, `_stop_distance`), `Engine.physics_ticks_per_second`, and the
## live spawn-to-target distance (scene-determined, not authored, so it is measured rather than
## assumed too). WHAT is measured is unchanged -- a tick-over-tick delta beyond the stop distance,
## a tick-over-tick halt at the authored distance, and a hero walking into the parked unit -- only
## WHEN the samples are taken and HOW WIDE the tolerance bands are now scale with the shipped speed.
const RETARGET_SETTLE_TICKS := 15
const MOVE_FRACTION_OF_CLOSE := 0.2
const STOP_MARGIN_FRACTION := 0.5
const STOP_MARGIN_FLOOR_TICKS := 40
const WALK_START_BUFFER_TICKS := 8
const WALK_MARGIN_FACTOR := 1.3
const WALK_FLOOR_TICKS := 40

## Planar distance moved in ONE tick at the authored speed is 0.05 (at the shipped 3.0 / 60 Hz).
## "Moving" is asserted well above float noise and well below that; "stopped" well below it. These
## thresholds stay literal (4-3/R22 only re-derives frames and STOP_BAND) -- the MOVED sample gap
## is widened instead, at runtime, so a retuned speed still clears MOVED_EPSILON with margin.
const MOVED_EPSILON := 0.02
const STOPPED_EPSILON := 0.005
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
## Story 4-3e: how far BEHIND its own fresh unit the summoning hero is parked, so the unit has a
## clear run at its target and the hero still has one at the unit. Comfortably outside
## `BODY_CONTACT_DISTANCE` (0.8), so the two do not start the run already touching.
const HERO_CLEAR_DISTANCE := 2.0

var _frames := 0
var _runner: Node
var _state: MatchState
var _armed_slot := -1
var _armed_action := &""

var _slot_chosen := false
var _spawned := false
var _speed := 0.0
var _stop_distance := 0.0
var _hero_speed := 0.0
var _ticks_per_second := 60.0

var _hero_start_pos := Vector3.ZERO
var _initial_unit_distance := 0.0

## Derived once the spawn is confirmed and the live spawn-to-target distance is known.
var _move_sample_frame := 0
var _move_confirm_frame := 0
var _stop_sample_frame := 0
var _stop_band := 0.0
## Derived once the unit has actually parked, since where it parks (and so how far the hero must
## walk) depends on the authored `unit_stop_distance`.
var _walk_start_frame := 0
var _walk_end_frame := 0

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
	# REWRITTEN BY STORY 6-5a (AC 13): re-pointed at the summon-bearing TEST deck through the runner's
	# deck-list seat -- on Deck 1 this test's fixed seed deals no summon (measured). See live_summon_deck.gd.
	var main := scene.instantiate()
	main.deck_list_override = LiveSummonDeck.all_summons()
	root.add_child(main)


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
		# Story 4-4 (AC 6): PER KIND now, resolved BY NAME rather than by index 0 — a reordered
		# authored list must fail loudly here, not quietly measure a static totem's zero speed.
		var kind: UnitKindProfile = _state.balance.kind_at(
			_state.balance.kind_index_of(&"minion"))
		if kind == null:
			print("authored balance carries no `minion` kind -- nothing to approach")
			print("RESULT: FAIL")
			quit(1)
			return false
		_speed = kind.move_speed
		_stop_distance = kind.stop_distance
		# The hero's OWN authored move speed, needed only to size the WALK window (`4-3/R22`) --
		# distinct from `_speed` (`unit_move_speed`), which the unit's approach uses.
		# Story 6-7 (Task 6(d)): re-derived from `walk_speed`, not `move_speed` (the RUN speed as
		# of this story) -- this file never presses `p1_run`, so the hero actually approaches at
		# the WALK-gated speed, and sizing the window from the run speed would under-run it.
		_hero_speed = maxf(_state.balance.walk_speed, 0.0001)
		_ticks_per_second = maxf(Engine.physics_ticks_per_second, 1.0)
		if _speed <= 0.0 or _stop_distance <= 0.0:
			print("authored balance ships the mechanic invisible: unit_move_speed=%f "
					% _speed + "unit_stop_distance=%f" % _stop_distance)
			print("RESULT: FAIL")
			quit(1)
			return false
		var hero: Node3D = _runner._p1_hero
		if hero != null:
			_hero_start_pos = hero.global_position
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
		else:
			_clear_the_summoners_hero(unit)
			_derive_sample_frames(unit)

	# ---- MOVED: a delta on a real node, while beyond the stop distance. The gap between the two
	#      samples is derived (`_move_confirm_frame`), not always one tick, so the expected travel
	#      clears MOVED_EPSILON regardless of the authored speed. ----
	if _frames == _move_sample_frame:
		var unit := _first_unit_actor()
		if unit != null:
			_move_from = unit.global_position
	if _frames == _move_confirm_frame:
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
	if _frames == _stop_sample_frame:
		var unit := _first_unit_actor()
		if unit != null:
			_stop_from = unit.global_position
	if _stop_sample_frame > 0 and _frames == _stop_sample_frame + 1:
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
			_stopped_at_the_authored_distance = absf(distance - _stop_distance) <= _stop_band
			if not _stopped_at_the_authored_distance:
				_detail += " wrong_distance(distance=%.3f authored=%.3f);" % [
					distance, _stop_distance]
			_aimed_while_stopped = _is_facing(unit, target)
			if not _aimed_while_stopped:
				_detail += " lost_facing_while_stopped;"
			# The WALK window depends on where the unit actually parked (which moves with a
			# retuned `unit_stop_distance`), so it is only derivable now, not up front (`4-3/R22`).
			_derive_walk_frames(unit.global_position)

	# ---- BLOCKED (AC 4): P1's hero walks into P1's own parked unit. Shipped defaults, no kill,
	#      no slot_controller_kinds flip -- `R-D6` is NOT spent by this story (`4-3/R14`).
	#      Camera-forward is world +x while the default lock holds (pinned end-to-end by
	#      test_camera_relative.gd -- test_hero_movement.gd pins the velocity MAGNITUDE, not an
	#      axis, since story 4-6 made the basis live), and the unit parks between P1's hero and
	#      P2's, so the hero walks straight at it. See the press below. ----
	if _frames == _walk_start_frame:
		# STORY 4-6 (AC 1): `p1_move_up` -- CAMERA-FORWARD -- is what world +X is now, and the
		# swap is this story's cause (b) landing on an existing fixture rather than a fix. The rig
		# yaws every tick to frame the locked target, the default lock is the opposing hero, and
		# main.tscn parks P1 at x -3 and P2 at x +3 -- so camera-forward IS +X, and `p1_move_right`
		# is camera-RIGHT, which is now perpendicular to it. Measured, not assumed: with the rig
		# fixed this pressed `p1_move_right`; test_camera_relative.gd is the file that pins the new
		# mapping end-to-end.
		Input.action_press(&"p1_move_up")
	if _frames > _walk_start_frame and _frames <= _walk_end_frame:
		var unit := _first_unit_actor()
		var hero: Node3D = _runner._p1_hero
		if unit != null and hero != null:
			_min_hero_gap = minf(_min_hero_gap,
					_planar_distance(hero.global_position, unit.global_position))
	if _frames == _walk_end_frame:
		Input.action_release(&"p1_move_up")
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


## STORY 4-3e SETUP STEP: put P1's hero on the FAR SIDE of its own freshly-summoned unit.
##
## WHY THIS IS NOW NEEDED, and why it is a setup repair rather than a defect being papered over.
## 4-3e made placement HERO-RELATIVE: a summoned unit appears BEHIND its summoner, on the side away
## from the opponent (that story's AC 1, an owner ruling). So the summoner is ALWAYS between its own
## fresh unit and the enemy -- by construction, for every summon in the game. A stationary hero
## therefore stands in its own minion's path, and the shipped 4-3 approach still does not
## distinguish "arrived" from "physically blocked" (4-3's own Non-Goal, unchanged). MEASURED at the
## 4-3e dev pass with this call absent: the unit wedges on its own hero and parks 6.800 from the
## target instead of the authored 1.500, failing `at_authored_distance`.
##
## THAT IS THE SHIPPED BEHAVIOUR, NOT A BUG THIS FILE MAY ASSERT AWAY. In play the summoner walks
## on and the minion streams past; this file measures the approach RULE, so it takes the summoner
## out of the way once, deterministically, the frame the unit appears.
##
## THE HERO GOES BEHIND THE UNIT, not merely aside, because the BLOCKED half of this test still
## needs the original topology: the unit parked between P1's hero and P2's, with `p1_move_right`
## walking the hero straight at it. The direction is DERIVED from the live unit->opponent axis
## rather than assumed to be -x, so the setup survives a scene whose heroes move.
func _clear_the_summoners_hero(unit: UnitActor) -> void:
	var hero: Node3D = _runner._p1_hero
	var opponent: Node3D = _runner._p2_hero
	if hero == null or opponent == null:
		return
	var unit_position := unit.global_position
	var away := Vector2(unit_position.x - opponent.global_position.x,
			unit_position.z - opponent.global_position.z).normalized()
	hero.global_position = Vector3(
			unit_position.x + away.x * HERO_CLEAR_DISTANCE,
			hero.global_position.y,
			unit_position.z + away.y * HERO_CLEAR_DISTANCE)
	# The walk window is derived from where the hero STARTS, so the start must be the moved one.
	_hero_start_pos = hero.global_position


## `4-3/R22`: computes `_move_sample_frame`, `_move_confirm_frame`, `_stop_sample_frame` and
## `_stop_band` from the authored `_speed` / `_stop_distance`, `Engine.physics_ticks_per_second`,
## and the live spawn-to-target distance -- instead of the hand-derived literals this replaced.
func _derive_sample_frames(unit: UnitActor) -> void:
	var target: Variant = _target_position()
	if target == null:
		return
	_initial_unit_distance = _planar_distance(unit.global_position, target)
	var unit_per_tick := _speed / _ticks_per_second
	var distance_to_close := maxf(_initial_unit_distance - _stop_distance, unit_per_tick)
	var ticks_to_close := int(ceil(distance_to_close / unit_per_tick))

	# MOVE_SAMPLE: comfortably past initial settle, still well outside the stop distance --
	# a fixed floor of ticks past spawn, or a fraction of the full close, whichever is later.
	var move_offset := maxi(RETARGET_SETTLE_TICKS, int(ticks_to_close * MOVE_FRACTION_OF_CLOSE))
	_move_sample_frame = SPAWN_CHECK_FRAME + move_offset
	# The confirm sample sits far enough past the first that the EXPECTED travel clears
	# MOVED_EPSILON with margin, whatever the authored speed -- one tick at 3.0/60, more ticks at
	# a retuned-slower speed, still one at a retuned-faster speed.
	var move_gap_ticks := maxi(1, int(ceil((MOVED_EPSILON * 2.0) / unit_per_tick)))
	_move_confirm_frame = _move_sample_frame + move_gap_ticks

	# STOP_SAMPLE: past full arrival, with a generous margin so the unit has settled.
	var stop_margin := maxi(STOP_MARGIN_FLOOR_TICKS, int(ticks_to_close * STOP_MARGIN_FRACTION))
	_stop_sample_frame = SPAWN_CHECK_FRAME + ticks_to_close + stop_margin

	# STOP_BAND: the unit may overshoot or undershoot the authored stop distance by at most a
	# little more than one tick of travel -- a unit halted early by something other than the rule
	# fails. At the shipped 3.0 / 60 Hz this is exactly the original 0.08.
	_stop_band = maxf(unit_per_tick * 1.6, 0.02)


## `4-3/R22`: computes `_walk_start_frame` / `_walk_end_frame` from where the unit ACTUALLY parked
## (`stop_position`, which shifts with a retuned `unit_stop_distance`) and the hero's own authored
## move speed -- instead of the hand-derived literals this replaced.
func _derive_walk_frames(stop_position: Vector3) -> void:
	var hero_per_tick := _hero_speed / _ticks_per_second
	var walk_distance := _planar_distance(_hero_start_pos, stop_position)
	var walk_ticks := maxi(WALK_FLOOR_TICKS,
			int(ceil((walk_distance / hero_per_tick) * WALK_MARGIN_FACTOR)))
	_walk_start_frame = _stop_sample_frame + 1 + WALK_START_BUFFER_TICKS
	_walk_end_frame = _walk_start_frame + walk_ticks


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
