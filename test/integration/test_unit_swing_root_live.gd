extends SceneTree

## Story 4-3c1 (AC 2, `4-3c/R19`, seat `4-3c1/R1`, IDLE rule `4-3c1/R2`): A UNIT PLANTS ITS FEET
## FOR THE WHOLE OF ITS OWN SWING, AND ONLY FOR ITS OWN SWING -- driven through the real runner, in
## the real scene, against the AUTHORED balance.
##
## WHY A NEW FILE RATHER THAN AN EXTENSION OF `test_unit_approach_live.gd` (operator's ruling, and
## `test_unit_attack_retrigger.gd`'s precedent): that file is an EXPECTED CASUALTY this story has to
## repair, and bundling "fix the old assertion" into "prove the new behaviour" would hide both --
## the repair would look like the proof and the proof would look like the repair.
##
## WHY THE HEADLESS STATE SUITE CANNOT SEE THIS: a unit's velocity and position are ACTOR-owned
## (`unit_actor.gd:143-151`; there is no `Vector3` on `UnitBoard`), and `_approach_unit_actors`
## never runs in the state harness at all. The multiplier itself is a pure state-side function and
## IS unit-tested there -- but "the unit does not move" is only observable on a live node.
##
## THE OBSERVABLE IS DISPLACEMENT ON A UNIT WITH NO NEIGHBOUR IN CONTACT, and both halves of that
## are asserted, not assumed. `approach()` calls `move_and_slide()` even at zero velocity
## (`unit_actor.gd:151`), so a unit shoved by a neighbour could in principle depenetrate and move
## for a reason this story does not cause. Exactly one unit is summoned and
## `get_slide_collision_count()` is asserted 0 on every rooted sample, so "nothing was touching it"
## is measured rather than hoped for. The crowd case stays a LIVE SMOKE observation with no numeric
## tolerance bound to it (AC 2), deliberately.
##
## THE NON-VACUITY PAIR: rooting alone would pass for a unit that never moved at all (which is
## precisely the `4-3c1/R2` defect), and moving alone would pass for a unit that never swung. So
## BOTH are measured, separately, on the same live unit in one run: EXACTLY 0.0 planar displacement
## across WINDUP, ACTIVE and RECOVERY (each observed in its own right, not as one "not IDLE"
## bucket), and the full authored `unit_move_speed` while IDLE.
##
## NAMED MUTATION (`4-3c/R6`'s discipline): replace the explicit `IDLE -> 1.0` arm of
## `MatchState.unit_attack_phase_multiplier()` with a literal mirror of the hero's
## `_attack_phase_multiplier()` -- a `_:` catch-all returning
## `balance.minion_attack_recovery_move_speed_multiplier`. IDLE then reads the authored 0.0, every
## unit is rooted from the instant it spawns, and this file goes RED on
## "IDLE_NOT_MOVING" (the unit never travels its authored per-tick distance) and on
## "PHASE_NEVER_OBSERVED" (rooted at spawn, it never closes to reach and never swings at all).
##
## SAMPLES ARE PHASE-STABLE PAIRS ONLY: a displacement is attributed to a phase only when the tick
## BEFORE it and the tick OF it report the same phase. The runner's `_physics_process` and this
## script's are two callbacks in an unspecified order (`test_unit_aim_live.gd`'s measured reason),
## so a boundary tick cannot be attributed to either side of the boundary and is simply not used.
## The authored windows are 54 / 12 / 48 ticks, so every phase still yields many stable pairs.
##
## Run: godot --headless --path . --script res://test/integration/test_unit_swing_root_live.gd

## The cast sequence is `test_unit_approach_live.gd`'s verbatim, including its reason for HOLDING
## presses across frames rather than pulsing them.
const ARM_FRAME := 4
const CONFIRM_FRAME := 10
const CONFIRM_RELEASE_FRAME := 14
const SPAWN_CHECK_FRAME := 18
## Past the retarget throttle, so the unit has an acquired target and is genuinely walking before
## anything is sampled -- an un-targeted unit is zeroed by the `NO_TARGET_SLOT` skip path, which is
## a different mechanism entirely and must not be mistaken for this story's rooting.
const SAMPLE_START_OFFSET := 15
## Generous: the authored swing is 54 + 12 + 48 = 114 ticks and the unit must first close roughly
## 6 units at 0.05/tick. The run ends EARLY the moment every phase has enough stable pairs.
const MAX_FRAMES := 900

## A rooted tick must be EXACTLY 0.0 -- not "small". The velocity written is `Vector3.ZERO`, and
## with nothing in contact `move_and_slide()` has no displacement to produce. A nonzero epsilon
## here would let a genuinely-creeping unit pass, which is the whole defect.
const ROOTED_DISPLACEMENT := 0.0
## An IDLE tick must travel the authored per-tick distance. The tolerance covers only float noise
## in the normalise-and-scale in `approach()`, not a fraction of a tick of travel.
const IDLE_TRAVEL_TOLERANCE := 0.0005
## Enough stable pairs per phase that a single lucky tick cannot carry a phase.
const MIN_SAMPLES_PER_PHASE := 5
const MIN_IDLE_SAMPLES := 10

var _frames := 0
var _runner: Node
var _state: MatchState

var _armed_slot := -1
var _armed_action := &""
var _slot_chosen := false
var _spawned := false

var _speed := 0.0
var _stop_distance := 0.0
var _ticks_per_second := 60.0
var _expected_idle_travel := 0.0

var _prev_position := Vector3.ZERO
var _prev_phase := -1
var _have_previous := false

## Per phase: how many stable pairs were seen, and the WORST displacement among them.
var _counts := {}
var _worst := {}
## IDLE is judged on its own terms (it must MOVE), so its worst case is a deviation, not a raw
## displacement -- and only pairs taken while genuinely beyond the stop distance count.
var _idle_samples := 0
var _idle_worst_deviation := 0.0
var _contact_violations := 0
var _detail := ""


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())
	for phase in [UnitBoard.AttackPhase.WINDUP, UnitBoard.AttackPhase.ACTIVE,
			UnitBoard.AttackPhase.RECOVERY]:
		_counts[phase] = 0
		_worst[phase] = 0.0


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _runner == null or _state == null:
			return _finish(false, "missing: runner=%s state=%s" % [_runner, _state])
		# THE AUTHORED VALUES, read off the config the runner APPLIED -- the same handle the
		# approach seat reads at point of use, so this measures what shipped rather than a constant
		# copied into the test.
		_speed = _state.balance.unit_move_speed
		_stop_distance = _state.balance.unit_stop_distance
		_ticks_per_second = maxf(Engine.physics_ticks_per_second, 1.0)
		if _speed <= 0.0 or _stop_distance <= 0.0:
			return _finish(false, "authored balance ships the mechanic invisible: "
					+ "unit_move_speed=%f unit_stop_distance=%f" % [_speed, _stop_distance])
		# THE POSITIVE CONTROL FOR THE ROOT: all three authored multipliers must be 0.0, or
		# "displacement is exactly 0.0" is not what the authored data actually asks for and this
		# file would be asserting a number nobody authored.
		for field in [&"minion_attack_windup_move_speed_multiplier",
				&"minion_attack_active_move_speed_multiplier",
				&"minion_attack_recovery_move_speed_multiplier"]:
			if float(_state.balance.get(field)) != 0.0:
				return _finish(false, ("authored %s is %f, not the 0.0 full root this file "
						+ "measures") % [field, float(_state.balance.get(field))])
		_expected_idle_travel = _speed / _ticks_per_second
	if _frames == 2:
		_state.p1.mana.add(_state.p1.mana.get_maximum())
		# NON-VACUITY up front, the `test_summon_actor_live.gd` idiom: with the minion layer off
		# every summon degrades and every assertion below would "pass" for the wrong reason.
		if not _state.flags.minions:
			return _finish(false, "the authored FeatureFlags has minions OFF -- cannot summon")
	if _frames == 3:
		_choose_a_summoning_slot()
		if not _slot_chosen:
			return _finish(false, "no summoning card in the dealt hand: %s"
					% str(_state.p1.hand.to_array()))
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
		# EXACTLY ONE unit, which is what makes "no neighbour in contact" a property of the scene
		# rather than a hope about it.
		_spawned = _state.p1.units.size() == 1 and _first_unit_actor() != null
		if not _spawned:
			return _finish(false, "summon did not land: board=%d actor=%s"
					% [_state.p1.units.size(), _first_unit_actor()])

	if _spawned and _frames > SPAWN_CHECK_FRAME + SAMPLE_START_OFFSET:
		_sample()

	if _frames >= MAX_FRAMES or _enough_samples():
		return _report()
	return false


## One tick of evidence: the phase the board reports NOW, and the planar displacement since the
## previous tick. Used only when both ends of that pair are in the same phase (see the header).
func _sample() -> void:
	var unit := _first_unit_actor()
	if unit == null or _state.p1.units.size() < 1 or not _state.p1.units.is_alive_at(0):
		# The unit died or its actor was freed -- stop accumulating rather than attributing a
		# teardown to a phase. Whether enough was already gathered is the report's problem.
		_have_previous = false
		return
	var phase := _state.p1.units.attack_phase_at(0)
	var position := unit.global_position
	if _have_previous and phase == _prev_phase:
		var displacement := _planar_distance(position, _prev_position)
		if phase == UnitBoard.AttackPhase.IDLE:
			# IDLE only proves anything while the unit still has somewhere to go: inside
			# `unit_stop_distance` standing still is the CORRECT behaviour and would frame a
			# working unit as broken.
			var target: Variant = _target_position()
			if target != null and _planar_distance(position, target) > _stop_distance:
				_idle_samples += 1
				_idle_worst_deviation = maxf(_idle_worst_deviation,
						absf(displacement - _expected_idle_travel))
		else:
			_counts[phase] = int(_counts[phase]) + 1
			_worst[phase] = maxf(float(_worst[phase]), displacement)
			# "No neighbour in contact" MEASURED, not assumed: a rooted unit calls
			# `move_and_slide()` with zero velocity, so a neighbour in contact here would mean the
			# displacement (or its absence) is about depenetration, not about this story.
			#
			# A NEIGHBOUR IS A MOVING BODY, AND THE FLOOR IS NOT ONE. A grounded unit reports a
			# slide collision with the arena floor on EVERY tick (measured: 69 of 69 rooted samples
			# in the first run of this file), so a bare `get_slide_collision_count() != 0` would
			# fail always and prove nothing. What AC 2 excludes is another ACTOR shoving this one --
			# heroes and units are both `CharacterBody3D`, static level geometry is not.
			if _neighbour_in_contact(unit):
				_contact_violations += 1
	_prev_position = position
	_prev_phase = phase
	_have_previous = true


## True when any body this unit slid against on the last `move_and_slide()` is a MOVING body -- a
## hero or another unit. The arena floor is static and is deliberately not counted; see the caller.
func _neighbour_in_contact(unit: UnitActor) -> bool:
	for i in unit.get_slide_collision_count():
		var collider: Object = unit.get_slide_collision(i).get_collider()
		if collider is CharacterBody3D:
			return true
	return false


func _enough_samples() -> bool:
	if _idle_samples < MIN_IDLE_SAMPLES:
		return false
	for phase in _counts:
		if int(_counts[phase]) < MIN_SAMPLES_PER_PHASE:
			return false
	return true


func _report() -> bool:
	var ok := _slot_chosen and _spawned
	if _idle_samples < MIN_IDLE_SAMPLES:
		ok = false
		_detail += (" PHASE_NEVER_OBSERVED(IDLE): only %d stable IDLE pairs beyond the stop "
				+ "distance, need %d -- a unit rooted from spawn never walks;") % [
					_idle_samples, MIN_IDLE_SAMPLES]
	elif _idle_worst_deviation > IDLE_TRAVEL_TOLERANCE:
		ok = false
		_detail += (" IDLE_NOT_MOVING: worst IDLE tick deviated %.6f from the authored "
				+ "unit_move_speed travel of %.6f -- IDLE must return 1.0 (`4-3c1/R2`), never a "
				+ "phase field;") % [_idle_worst_deviation, _expected_idle_travel]
	for phase in [UnitBoard.AttackPhase.WINDUP, UnitBoard.AttackPhase.ACTIVE,
			UnitBoard.AttackPhase.RECOVERY]:
		var count := int(_counts[phase])
		if count < MIN_SAMPLES_PER_PHASE:
			ok = false
			_detail += " PHASE_NEVER_OBSERVED(%s): %d stable pairs, need %d;" % [
				_phase_name(phase), count, MIN_SAMPLES_PER_PHASE]
		elif float(_worst[phase]) > ROOTED_DISPLACEMENT:
			ok = false
			_detail += (" NOT_ROOTED(%s): moved %.6f in one tick while committed to its own swing "
					+ "-- authored 0.0 multiplier means EXACTLY 0.0 displacement;") % [
						_phase_name(phase), float(_worst[phase])]
	if _contact_violations > 0:
		ok = false
		_detail += (" NEIGHBOUR_IN_CONTACT: %d rooted samples had slide collisions -- the "
				+ "displacement measured is not this story's to claim;") % _contact_violations
	print(("unit_swing_root_live: speed=%.2f per_tick=%.5f frames=%d idle_pairs=%d "
			+ "idle_worst_dev=%.6f windup=%d/%.6f active=%d/%.6f recovery=%d/%.6f contacts=%d%s")
			% [_speed, _expected_idle_travel, _frames, _idle_samples, _idle_worst_deviation,
				int(_counts[UnitBoard.AttackPhase.WINDUP]),
				float(_worst[UnitBoard.AttackPhase.WINDUP]),
				int(_counts[UnitBoard.AttackPhase.ACTIVE]),
				float(_worst[UnitBoard.AttackPhase.ACTIVE]),
				int(_counts[UnitBoard.AttackPhase.RECOVERY]),
				float(_worst[UnitBoard.AttackPhase.RECOVERY]), _contact_violations, _detail])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false


func _finish(ok: bool, message: String) -> bool:
	print(message)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false


func _phase_name(phase: int) -> String:
	match phase:
		UnitBoard.AttackPhase.IDLE:
			return "IDLE"
		UnitBoard.AttackPhase.WINDUP:
			return "WINDUP"
		UnitBoard.AttackPhase.ACTIVE:
			return "ACTIVE"
		UnitBoard.AttackPhase.RECOVERY:
			return "RECOVERY"
		_:
			return "phase#%d" % phase


## The world position of the target the unit ACQUIRED, resolved the way the runner resolves it --
## via the state-side `[slot, index]` pair, not by assuming which node it is.
## `test_unit_approach_live.gd`'s helper verbatim.
func _target_position() -> Variant:
	if _state.p1.units.size() < 1:
		return null
	var target_slot := _state.p1.units.target_slot_at(0)
	if target_slot == TargetingService.NO_TARGET_SLOT:
		return null
	return _runner._target_world_position(target_slot, _state.p1.units.target_index_at(0))


func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The first dealt slot whose authored card carries a `summon_*` effect --
## `test_unit_approach_live.gd`'s chooser verbatim, including its reason for reaching the library
## through the autoload NODE (this file IS the `--script` main loop, compiled before the autoloads
## register).
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


## Walks the TREE rather than reading the runner's bookkeeping array -- the
## `test_summon_actor_live.gd` reason: a runner that appended to its array and forgot to
## `add_child` would otherwise report success with nothing on screen. It applies with full force
## here, where the whole claim is about where a node in the tree is.
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
