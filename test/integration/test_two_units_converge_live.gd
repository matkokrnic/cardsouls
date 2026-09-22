extends SceneTree

## Story 6-5a (AC 13): the summon-bearing test deck this file is re-pointed at.
const LiveSummonDeck := preload("res://test/live_summon_deck.gd")

## Story 4-3a (AC 10, `4-3a/R18`): TWO UNITS DRIVEN AT THE SAME ACQUIRED TARGET SIMULTANEOUSLY --
## measured to MOVE, to CONVERGE on that target, and to do it without JITTER, WEDGING or
## PASS-THROUGH.
##
## THIS DISCHARGES THE DEFERRED-WORK ITEM `4-3/R21` FINDING 1 ("Unit-vs-unit body collision is
## unmeasured", OWNER `4-3a-minion-damage-and-death`). The 4-3 close-out observed this BY HAND in the
## live smoke and filed the machine coverage; this file is that coverage.
##
## IT IS BODY COLLISION ONLY, and that is a scope statement rather than a gap: it is NOT a combat AC
## and does NOT require either unit to be able to damage the other. Unit-vs-unit damage is `4-3b`'s.
##
## THE POSITIVE HALF IS WHY THIS FILE IS NOT VACUOUS (`4-3a/R18`). As originally written the AC was
## THREE NEGATIVE CLAIMS -- no jitter, no wedging, no pass-through -- every one of which is trivially
## true of two units that never spawned or never moved. So this file additionally REQUIRES:
##   * both units MOVED, measured as a start-to-end displacement well past float noise;
##   * both units CONVERGED, measured as a final planar distance to the target within a bound;
##   * both units acquired the SAME `[slot, index]` pair, so "converged on the same target" is read
##     off the state layer's own verdict rather than inferred from two boxes ending up near a node.
## Every threshold and sample frame below is DERIVED AT RUNTIME from the authored balance
## (`unit_move_speed`, `unit_stop_distance`) and `Engine.physics_ticks_per_second`, so the `4-3b`
## melee retune cannot silently desynchronise it (the `4-3/R22` discipline).
##
## THE EXISTING SINGLE-ACTOR HELPER CANNOT BE REUSED, as the story's own AC 10 notes: it returns the
## FIRST `UnitActor` in tree order. `_both_unit_actors()` below resolves BOTH, by board index, out of
## the runner's per-slot array -- so "unit 0" and "unit 1" here are the same two records the state
## layer is reasoning about.
##
## Run: godot --headless --path . --script res://test/integration/test_two_units_converge_live.gd

const ARM_FRAME := 4
const CONFIRM_FRAME := 10
const RELEASE_FRAME := 14
const ARM2_FRAME := 20
const CONFIRM2_FRAME := 26
const RELEASE2_FRAME := 30
const SPAWN_CHECK_FRAME := 36

## Story 4-3e: P1's hero leaves the units' lane on the frame BEFORE the spawn check -- after both
## casts have resolved, never before. See the block at that frame for why the ordering is now
## load-bearing rather than incidental.
const HERO_CLEAR_FRAME := SPAWN_CHECK_FRAME - 1
const HERO_CLEAR_Z := 8.0

## Settling allowance before the approach is judged, and the window over which jitter is sampled.
const RETARGET_SETTLE_TICKS := 30
const ARRIVAL_MARGIN_FRACTION := 0.6
const ARRIVAL_FLOOR_TICKS := 60
const JITTER_WINDOW_TICKS := 45

## Planar body half-extents. Each unit's `Collision` box is 0.6 x 1.2 x 0.6, so two non-overlapping
## unit bodies can never have their centres closer than 0.3 + 0.3, whatever their yaw -- a measured
## separation below this means one box is INSIDE the other, which is exactly "passed through".
const UNIT_INRADIUS := 0.3
const PASS_THROUGH_DISTANCE := UNIT_INRADIUS * 2.0
const OVERLAP_EPSILON := 0.05
## A unit blocked by its sibling parks FARTHER than the authored stop distance -- by at most a body
## diameter or so. The convergence bound allows that and nothing more, so a unit WEDGED halfway
## across the arena fails.
const CONVERGE_BODY_ALLOWANCE := 3.0

var _frames := 0
var _runner: Node
var _state: MatchState
var _slot_chosen := false
var _armed_action := &""
var _spawned := false

var _speed := 0.0
var _stop_distance := 0.0
var _ticks_per_second := 60.0

var _start_positions: Array[Vector3] = []
var _initial_distances: Array[float] = []
var _converge_bound := 0.0
var _moved_epsilon := 0.0
var _jitter_epsilon := 0.0
var _arrival_frame := 0
var _jitter_end_frame := 0

var _same_target := false
var _target_pair: Array[int] = []
var _min_separation := INF
var _max_jitter := 0.0
var _last_positions: Array[Vector3] = []
var _moved: Array[bool] = [false, false]
var _converged: Array[bool] = [false, false]
var _final_distances: Array[float] = [0.0, 0.0]
var _convergence_is_meaningful := false
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
			return _fail("missing: runner=%s state=%s" % [_runner, _state])
		# Story 4-4 (AC 6): the approach values are PER KIND now. Read off the MINION kind by name,
		# not by index 0, so a reordered authored list fails here loudly instead of silently
		# measuring a totem's zero speed and reporting "the approach ships invisible".
		var kind: UnitKindProfile = _state.balance.kind_at(
			_state.balance.kind_index_of(&"minion"))
		if kind == null:
			return _fail("authored balance carries no `minion` kind -- nothing to converge")
		_speed = kind.move_speed
		_stop_distance = kind.stop_distance
		_ticks_per_second = maxf(Engine.physics_ticks_per_second, 1.0)
		if _speed <= 0.0 or _stop_distance <= 0.0:
			return _fail("authored balance ships the approach invisible: speed=%f stop=%f"
					% [_speed, _stop_distance])
		# DERIVED THRESHOLDS. "Moved" must clear float noise but sit far below a full approach;
		# "jitter" must sit far below one tick of intentional travel, so a unit still walking reads
		# as moving and a parked one reads as still.
		var per_tick := _speed / _ticks_per_second
		_moved_epsilon = per_tick * 4.0
		_jitter_epsilon = per_tick * 0.25
		_converge_bound = _stop_distance + UNIT_INRADIUS * 2.0 * CONVERGE_BODY_ALLOWANCE
	if _frames == 2:
		_state.p1.mana.add(_state.p1.mana.get_maximum())
		if not _state.flags.minions:
			return _fail("the authored FeatureFlags has minions OFF -- this test cannot summon")
	if _frames == HERO_CLEAR_FRAME:
		# P1'S OWN HERO IS MOVED OFF THE UNITS' LANE, and this is a SCOPE decision rather than a
		# convenience. The two units walk +x toward P2's hero; P1's hero stands at (-3, 0), squarely
		# in that lane, so the trailing unit runs into ITS OWN HERO'S BODY and stops there.
		#
		# THAT IS NOT A DEFECT AND IT IS NOT THIS AC. It is the shipped 4-3 approach behaviour, and
		# 4-3a's own Non-Goals keep it: "`approach()` is NOT taught to distinguish 'arrived' from
		# 'physically blocked'". AC 10 is UNIT-VS-UNIT body collision, so the hero is taken out of
		# the lane to leave the two units as the only bodies that can interact. Position is
		# actor-owned (`4-1/R12`), so moving it here is a presentation-side setup step, no state.
		#
		# STORY 4-3e MOVED THIS BLOCK, AND THE ORDERING IS NOW LOAD-BEARING. Placement became
		# HERO-RELATIVE: a unit is summoned BEHIND its own hero, on the side away from the opponent.
		# So the old shape -- teleport at frame 2, summon afterwards -- INVERTED ITSELF. It used to
		# carry the hero out of a fixed row's lane; it would now carry THE LANE ALONG WITH THE HERO,
		# spawning both units behind the hero at z ~ 10 and putting the hero back between them and
		# their target. RE-MEASURED at the 4-3e dev pass: with the teleport left at frame 2 both
		# units wedge on their own hero and park 10.98 and 11.58 from the target, against a
		# convergence bound of 3.30.
		#
		# The hero therefore leaves AFTER both casts have resolved. There is no placement geometry
		# that puts a summoned unit somewhere its own hero is not behind it -- that is the whole
		# content of 4-3e AC 1 -- so clearing the lane is only possible once the units exist.
		# RE-MEASURED with this block deleted entirely: the LEADING unit parks 6.80 from the target,
		# pinned against its own hero at a planar gap of ~0.80 (hero inradius 0.5 + unit 0.3), and
		# the trailing one 7.40, stacked a body-width behind it. (The pre-4-3e figure recorded here
		# was 6.82 against the frozen row; the row is gone, so that number is gone with it.)
		var p1_hero: Node3D = _runner._p1_hero
		p1_hero.global_position = Vector3(
				p1_hero.global_position.x, p1_hero.global_position.y, HERO_CLEAR_Z)
	if _frames == 3:
		_slot_chosen = _choose_a_summoning_slot()
		if not _slot_chosen:
			return _fail("no summoning card in the dealt hand: %s" % str(_state.p1.hand.to_array()))
	# --- two casts, two units ---
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
	if _frames == ARM2_FRAME:
		Input.action_press(&"p1_cast_mode")
		_slot_chosen = _choose_a_summoning_slot()
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

	if _frames == SPAWN_CHECK_FRAME:
		var actors := _both_unit_actors()
		_spawned = _state.p1.units.size() >= 2 and actors.size() == 2
		if not _spawned:
			return _fail("need two spawned units: board=%d actors=%d"
					% [_state.p1.units.size(), actors.size()])
		for a in actors:
			_start_positions.append(a.global_position)
			_last_positions.append(a.global_position)
		_derive_frames()

	# --- SEPARATION: sampled every frame of the whole approach. Two bodies that ever pass through
	#     one another register here, not only at the end. ---
	if _spawned and _frames > SPAWN_CHECK_FRAME and _frames <= _jitter_end_frame:
		var actors := _both_unit_actors()
		if actors.size() == 2:
			_min_separation = minf(_min_separation,
					_planar_distance(actors[0].global_position, actors[1].global_position))

	# --- ARRIVAL: both moved, both converged, both on the same acquired pair. ---
	if _arrival_frame > 0 and _frames == _arrival_frame:
		_measure_arrival()

	# --- JITTER: after arrival, neither unit may keep twitching. ---
	if _arrival_frame > 0 and _frames > _arrival_frame and _frames <= _jitter_end_frame:
		var actors := _both_unit_actors()
		if actors.size() == 2:
			for i in 2:
				_max_jitter = maxf(_max_jitter,
						_planar_distance(actors[i].global_position, _last_positions[i]))
				_last_positions[i] = actors[i].global_position

	if _jitter_end_frame > 0 and _frames == _jitter_end_frame:
		return _report()
	return false


## Sample frames derived from the AUTHORED speed and the LIVE spawn-to-target distance -- neither is
## a literal, so a retuned `unit_move_speed` moves them rather than breaking them.
func _derive_frames() -> void:
	var target: Variant = _target_position()
	if target == null:
		return
	var actors := _both_unit_actors()
	for a in actors:
		_initial_distances.append(_planar_distance(a.global_position, target))
	var per_tick := _speed / _ticks_per_second
	var farthest: float = _initial_distances.max()
	var ticks_to_close := int(ceil(maxf(farthest - _stop_distance, per_tick) / per_tick))
	var margin := maxi(ARRIVAL_FLOOR_TICKS, int(ticks_to_close * ARRIVAL_MARGIN_FRACTION))
	_arrival_frame = SPAWN_CHECK_FRAME + RETARGET_SETTLE_TICKS + ticks_to_close + margin
	_jitter_end_frame = _arrival_frame + JITTER_WINDOW_TICKS
	# CONVERGENCE IS ONLY MEANINGFUL IF THERE WAS A DISTANCE TO CLOSE. Both units must start well
	# outside the bound they have to end inside, or "converged" would be true of where they spawned.
	_convergence_is_meaningful = _initial_distances.min() > _converge_bound * 1.5
	if not _convergence_is_meaningful:
		_detail += " spawned_already_converged(min_start=%.2f bound=%.2f);" % [
			_initial_distances.min(), _converge_bound]


func _measure_arrival() -> void:
	var actors := _both_unit_actors()
	var target: Variant = _target_position()
	if actors.size() != 2 or target == null:
		_detail += " arrival_sample_missing(actors=%d target=%s);" % [actors.size(), target]
		return
	# THE SAME ACQUIRED PAIR, read off the STATE layer -- this is the "same target" half of AC 10's
	# positive requirement, and it is a state fact rather than a geometric coincidence.
	var pair0 := _state.p1.units.target_at(0)
	var pair1 := _state.p1.units.target_at(1)
	_target_pair = pair0
	_same_target = pair0 == pair1 and not TargetingService.is_no_target(pair0)
	if not _same_target:
		_detail += " different_targets(%s vs %s);" % [pair0, pair1]
	for i in 2:
		var travelled := _planar_distance(actors[i].global_position, _start_positions[i])
		_moved[i] = travelled > _moved_epsilon
		if not _moved[i]:
			_detail += " unit%d_never_moved(travelled=%.4f eps=%.4f);" % [
				i, travelled, _moved_epsilon]
		_final_distances[i] = _planar_distance(actors[i].global_position, target)
		_converged[i] = _final_distances[i] <= _converge_bound
		if not _converged[i]:
			_detail += " unit%d_wedged(distance=%.2f bound=%.2f);" % [
				i, _final_distances[i], _converge_bound]
		_last_positions[i] = actors[i].global_position


func _report() -> bool:
	var no_pass_through := _min_separation >= PASS_THROUGH_DISTANCE - OVERLAP_EPSILON
	if not no_pass_through:
		_detail += " passed_through(min_sep=%.3f floor=%.3f);" % [
			_min_separation, PASS_THROUGH_DISTANCE]
	var no_jitter := _max_jitter <= _jitter_epsilon
	if not no_jitter:
		_detail += " jitter(max=%.4f eps=%.4f);" % [_max_jitter, _jitter_epsilon]
	var ok := _slot_chosen and _spawned and _convergence_is_meaningful and _same_target \
			and _moved[0] and _moved[1] and _converged[0] and _converged[1] \
			and no_pass_through and no_jitter
	print("two_units_converge_live: speed=%.2f stop=%.2f pair=%s same_target=%s "
			% [_speed, _stop_distance, _target_pair, _same_target]
			+ "moved=%s/%s converged=%s/%s dist=%.2f/%.2f bound=%.2f "
			% [_moved[0], _moved[1], _converged[0], _converged[1],
				_final_distances[0], _final_distances[1], _converge_bound]
			+ "min_sep=%.3f max_jitter=%.4f%s" % [_min_separation, _max_jitter, _detail])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false


func _fail(message: String) -> bool:
	print(message)
	print("RESULT: FAIL")
	quit(1)
	return false


## BOTH of P1's unit actors, by BOARD INDEX, out of the runner's per-slot array. The story's AC 10
## names this explicitly: the existing single-actor helper returns the first `UnitActor` in TREE
## order and cannot address two. Indices here are the same numbers the state layer uses, so a
## measurement about "unit 1" is a measurement about record 1.
func _both_unit_actors() -> Array[UnitActor]:
	var out: Array[UnitActor] = []
	var actors: Array = _runner._unit_actors[0]
	for index in mini(actors.size(), 2):
		var node: Node = actors[index]
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			out.append(node as UnitActor)
	return out


## The world position of the target the units ACQUIRED, resolved the way the runner resolves it --
## through the state-side `[slot, index]` pair rather than by assuming which node it is.
func _target_position() -> Variant:
	if _state.p1.units.size() < 1:
		return null
	var target_slot := _state.p1.units.target_slot_at(0)
	if target_slot == TargetingService.NO_TARGET_SLOT:
		return null
	return _runner._target_world_position(target_slot, _state.p1.units.target_index_at(0))


func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


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
