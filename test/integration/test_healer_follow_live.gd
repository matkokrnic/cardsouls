extends SceneTree

## Story 7-5b (AC 3, AC 6; the runner side of T3), REWRITTEN BY SMOKE FIX 1 (S1, S2, S4): THE HEALER KEEPS ITS
## FOLLOW BAND, AND THE RUNNER REPORTS WHEN IT IS IN HEAL RANGE -- in the real `main.tscn`, against the authored
## balance and the authored `healer` presentation row, read at run time.
##
## A Healer is put on P1's board (the summon seat's own `add()`) and P1's hero, hurt beforehand, is moved about.
## Every number is read off the authored kind or row (never copied here); the OUTER radius is `heal_range`, the
## INNER one `stop_distance`:
##   STAND     the owner inside the band (85 % of the outer radius): the Healer NEVER MOVES, and every tick carries
##             its heal-range row `[0, index]` (S2: in range wherever it stands still).
##   WALK      the owner moved beyond the outer radius: the Healer sets off, never faster than `move_speed` (per
##             tick, planar), never farther from its owner than the tick before (it never flees), carries no row
##             while beyond the outer radius and one on every tick inside it, and halts at the INNER radius --
##             then stands still, FACING its owner. It never acquires a target (`target_slot_at` stays
##             `NO_TARGET_SLOT`) throughout.
##   CLOSER    the owner moved to within the inner radius: the Healer does not move away (S1: it never flees).
##   ROOT      the owner moved just beyond the outer radius as the heal clock is about to come round, so the heal
##             lands while the Healer WALKS back in range: from that tick it does not move for the row's
##             `cast_seconds` (S4, `cast` is played standing), and then it walks on.
##   HEAL      the owner's first heal is exactly `heal_amount`.
##   SHOOT     (smoke fix 2, S18) the owner moved beyond the outer radius again, and once the Healer walks a shot is
##             made owed on its record (the countdown state's own seat spends): it does not move from the tick the
##             shot is owed through the row's `shoot_face_hold_seconds` after it leaves, then walks on.
##   DEAD ZONE (S15a) the Healer standing, its owner straight ahead and then moved round it by 0.6 of the row's
##             `turn_dead_zone_degrees`: the body does not turn at all.
##   TURN      (S15a/b) the owner moved 90 degrees round to its LEFT: the body turns, never faster per tick than the
##             row's `reaim_turn_rate_degrees_per_second`, plays `turn_left` while it turns (the measured yaw reaches
##             the rig), and ends facing its owner.
##
## Run: godot --headless --path . --script res://test/integration/test_healer_follow_live.gd

const SPAWN_SETTLE := 6
const STAND_FRACTION := 0.85
const STAND_FRAMES := 90
const OUT_MARGIN := 4.0
const CLOSE_DISTANCE := 3.0
## The ROOT phase: the owner is moved this far beyond the outer radius when the heal is this many ticks away.
const ROOT_OUT := 1.0
const ROOT_LEAD_TICKS := 40
## A row is judged only this far (m) either side of the outer radius: the gather reads the previous tick's place.
const ROW_BAND := 0.2
const ARRIVE_EPS := 0.15
const SPEED_EPS := 0.01
const STILL := 0.001
const HURT_HP := 50.0
const MAX_FRAMES := 4500
## SHOOT: the shot is made owed once the Healer has walked this many frames.
const SHOOT_AFTER_FRAMES := 20
## DEAD ZONE / TURN: the share of the dead zone the small move uses, the frames each is watched, the big move, and
## how squarely the body must face its owner when the turn is done.
const SMALL_TURN_FRACTION := 0.6
const HOLD_FRAMES := 30
const SETTLE_FRAMES := 5
const BIG_TURN_DEGREES := 90.0
const TURN_MARGIN_FRAMES := 20
const FACED_DOT := 0.999
const YAW_EPS := 0.0005

enum Phase { STAND, WALK, CLOSER, WAIT_ROOT, ROOT, SHOOT, SETTLE, DEAD_ZONE, TURN }

var _frames := 0
var _runner: Node
var _state: MatchState
var _kind: UnitKindProfile
var _index := -1
var _interval_ticks := 0
var _cast_ticks := 0
var _phase := -1
var _phase_frame := 0
var _last := Vector3.ZERO
var _prev_apart := INF
var _still_frames := 0
var _heals_seen := 0

var _stand_ticks := 0
var _stand_rows := 0
var _stand_moves := 0
var _walk_moved := 0.0
var _out_rows := 0
var _missing_rows := 0
var _fled := 0
var _closer_moves := 0
var _root_heal_frame := -1
var _moving_before_heal := false
var _root_moves := 0
var _resumed := 0.0
var _first_heal_hp := -1.0
var _failures: Array[String] = []

var _delay_ticks := 0
var _hold_ticks := 0
var _dead_zone := 0.0
var _reaim_step := 0.0
var _shot_frame := -1
var _shot_left_frame := -1
var _moving_before_shot := false
var _shot_moves := 0
var _shot_resumed := 0.0
var _yaw0 := 0.0
var _yaw_still_frames := 0
var _small_turned := 0.0
var _turn_frames := 0
var _too_fast := 0
var _saw_turn_left := false
var _turn_faced := -1.0


func _initialize() -> void:
	root.add_child((load("res://src/main/main.tscn") as PackedScene).instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _state == null:
			return _end("missing runner or state")
		var kind_index: int = _state.balance.kind_index_of(&"healer")
		_kind = _state.balance.kind_at(kind_index)
		if _kind == null or _kind.move_speed <= 0.0 or _kind.heal_range <= _kind.stop_distance or _kind.stop_distance <= 0.0:
			return _end("the authored balance carries no walking, healing Healer kind with a follow band")
		_interval_ticks = _state.balance_ticks.kind_ticks_at(kind_index).heal_interval_ticks
		var row: EffectPresentationRow = _runner._effects.row(&"healer") if _runner._effects != null else null
		_cast_ticks = int(round(row.knob(&"cast_seconds", 0.0) * TimingWindow.TICK_HZ)) if row != null else 0
		if _cast_ticks <= 0:
			return _end("the authored `healer` row carries no `cast_seconds`")
		_delay_ticks = TimingWindow.seconds_to_ticks(_kind.shot_delay_seconds)
		_hold_ticks = int(round(row.knob(&"shoot_face_hold_seconds", 0.0) * TimingWindow.TICK_HZ))
		_dead_zone = deg_to_rad(row.knob(&"turn_dead_zone_degrees", 0.0))
		_reaim_step = deg_to_rad(row.knob(&"reaim_turn_rate_degrees_per_second", 0.0)) / TimingWindow.TICK_HZ
		if _delay_ticks <= 0 or _hold_ticks <= 0 or _dead_zone <= 0.0 or _reaim_step <= 0.0:
			return _end("the authored kind or row lacks a shot delay, a face hold, a dead zone or a re-aim rate")
		_state.p1.units.add(_kind.max_hp, kind_index)
		_index = _state.p1.units.size() - 1
		_state.p1.hero.take_damage(_state.p1.hero.get_hp() - HURT_HP)
		return false
	var healer := _healer()
	var owner: Node3D = _runner._p1_hero
	if healer == null:
		if _frames > SPAWN_SETTLE:
			return _end("the Healer's actor never spawned")
		return false
	if _frames == SPAWN_SETTLE:
		_move_owner(healer, owner, _kind.heal_range * STAND_FRACTION)
		_enter(Phase.STAND, healer)
		return false
	if _phase < 0:
		return false
	if _frames > MAX_FRAMES:
		return _end("the run did not finish in %d frames (phase %d)" % [MAX_FRAMES, _phase])
	_phase_frame += 1

	_check(_state.p1.units.target_slot_at(_index) == TargetingService.NO_TARGET_SLOT,
			"frame %d: the Healer acquired a target" % _frames)
	var step := _planar(healer.global_position - _last)
	_check(step <= _kind.move_speed / TimingWindow.TICK_HZ + SPEED_EPS,
			"frame %d: the Healer moved %.4f m in one tick, faster than its %.2f m/s" % [_frames, step, _kind.move_speed])
	_last = healer.global_position
	var apart := _planar(healer.global_position - owner.global_position)
	var rows: Array = _runner._recorder.heal_range_pushes_at(_runner._recorder.tick_count())
	var has_row := rows.has([0, _index])
	var heals: int = _state.p1.units.heal_count_at(_index)
	var healed_now := heals > _heals_seen
	if healed_now and _heals_seen == 0:
		_first_heal_hp = _state.p1.hero.get_hp()
	_heals_seen = heals
	_still_frames = _still_frames + 1 if step < STILL else 0

	match _phase:
		Phase.STAND:
			if _phase_frame >= 2:
				_stand_ticks += 1
				if has_row:
					_stand_rows += 1
				if step >= STILL:
					_stand_moves += 1
			if _phase_frame >= STAND_FRAMES:
				_move_owner(healer, owner, _kind.heal_range + OUT_MARGIN)
				_enter(Phase.WALK, healer)
		Phase.WALK:
			_judge_rows(apart, has_row)
			if apart > _prev_apart + STILL:
				_fled += 1
			_prev_apart = apart
			_walk_moved += step
			_check(apart >= _kind.stop_distance - ARRIVE_EPS,
					"frame %d: the Healer came %.3f m from its owner, inside its %.2f m inner radius"
							% [_frames, apart, _kind.stop_distance])
			# Still for longer than a cast's root: it has arrived, not paused to heal.
			if _walk_moved > 1.0 and _still_frames > _cast_ticks + 30:
				_check_arrived(healer, owner, apart)
				_move_owner(healer, owner, CLOSE_DISTANCE)
				_enter(Phase.CLOSER, healer)
		Phase.CLOSER:
			if _phase_frame >= 2 and step >= STILL:
				_closer_moves += 1
			if _phase_frame >= STAND_FRAMES:
				_enter(Phase.WAIT_ROOT, healer)
		Phase.WAIT_ROOT:
			var remaining: int = _interval_ticks - _state.p1.units.heal_ticks_at(_index)
			if remaining <= ROOT_LEAD_TICKS and remaining > ROOT_LEAD_TICKS - 5:
				_move_owner(healer, owner, _kind.heal_range + ROOT_OUT)
				_enter(Phase.ROOT, healer)
		Phase.ROOT:
			if _root_heal_frame < 0:
				if healed_now:
					_root_heal_frame = _frames
				elif step >= STILL:
					_moving_before_heal = true
				elif _phase_frame > ROOT_LEAD_TICKS + 30:
					return _end("no heal came while the Healer walked back in range")
			else:
				var since := _frames - _root_heal_frame
				if since >= 2 and since <= _cast_ticks - 2 and step >= STILL:
					_root_moves += 1
				if since > _cast_ticks + 2:
					_resumed += step
				if since > _cast_ticks + 30:
					_move_owner(healer, owner, _kind.heal_range + OUT_MARGIN)
					_enter(Phase.SHOOT, healer)
		Phase.SHOOT:
			var owed: bool = _state.p1.units.shot_owed_at(_index) != UnitBoard.NO_SHOT_OWED
			if _shot_frame < 0:
				if _phase_frame >= SHOOT_AFTER_FRAMES:
					_moving_before_shot = step >= STILL
					_state.p1.units.set_shot_owed_at(_index, _delay_ticks - 1)
					_shot_frame = _frames
			elif _shot_left_frame < 0:
				if _frames >= _shot_frame + 2 and step >= STILL:
					_shot_moves += 1
				if not owed:
					_shot_left_frame = _frames
			else:
				var after := _frames - _shot_left_frame
				if after <= _hold_ticks - 2 and step >= STILL:
					_shot_moves += 1
				if after > _hold_ticks + 2:
					_shot_resumed += step
				if after > _hold_ticks + 30:
					_move_owner(healer, owner, _kind.heal_range * STAND_FRACTION)
					_enter(Phase.SETTLE, healer)
		Phase.SETTLE:
			# Still in place AND in yaw (any re-aim already under way has finished), then the owner is put straight
			# ahead of the body at the band distance -- no facing error at all -- and left there a few ticks.
			_yaw_still_frames = _yaw_still_frames + 1 \
					if absf(angle_difference(_yaw0, healer.global_rotation.y)) < YAW_EPS else 0
			_yaw0 = healer.global_rotation.y
			if _still_frames > HOLD_FRAMES and _yaw_still_frames > HOLD_FRAMES:
				_place_owner_at(healer, owner, 0.0)
				_enter(Phase.DEAD_ZONE, healer)
		Phase.DEAD_ZONE:
			if _phase_frame == SETTLE_FRAMES:
				_yaw0 = healer.global_rotation.y
				_place_owner_at(healer, owner, _dead_zone * SMALL_TURN_FRACTION)
			elif _phase_frame > SETTLE_FRAMES:
				_small_turned = maxf(_small_turned, absf(angle_difference(_yaw0, healer.global_rotation.y)))
			if _phase_frame >= SETTLE_FRAMES + HOLD_FRAMES:
				_place_owner_at(healer, owner, deg_to_rad(BIG_TURN_DEGREES))
				_yaw0 = healer.global_rotation.y
				_enter(Phase.TURN, healer)
		Phase.TURN:
			var yaw := healer.global_rotation.y
			if absf(angle_difference(_yaw0, yaw)) > _reaim_step + YAW_EPS:
				_too_fast += 1
			if absf(angle_difference(_yaw0, yaw)) > YAW_EPS:
				_turn_frames += 1
			_yaw0 = yaw
			var anim := (healer.animation as HealerAnimationController).animation_player
			if anim.current_animation == &"turn_left":
				_saw_turn_left = true
			if _phase_frame >= int(ceil(deg_to_rad(BIG_TURN_DEGREES) / _reaim_step)) + TURN_MARGIN_FRAMES:
				var forward := -healer.global_transform.basis.z
				var to_owner := Vector2(owner.global_position.x - healer.global_position.x,
						owner.global_position.z - healer.global_position.z).normalized()
				_turn_faced = Vector2(forward.x, forward.z).normalized().dot(to_owner)
				return _finish()
	return false


func _finish() -> bool:
	_check(_stand_ticks > 0 and _stand_rows == _stand_ticks,
			"STAND: %d of %d ticks carried the Healer's heal-range row" % [_stand_rows, _stand_ticks])
	_check(_stand_moves == 0, "STAND: the Healer moved on %d ticks with its owner inside the band" % _stand_moves)
	_check(_out_rows == 0, "WALK: %d ticks beyond the outer radius still carried the row" % _out_rows)
	_check(_missing_rows == 0, "WALK: %d ticks inside the outer radius carried no row" % _missing_rows)
	_check(_fled == 0, "WALK: on %d ticks the Healer ended farther from its owner than before" % _fled)
	_check(_closer_moves == 0, "CLOSER: the Healer moved on %d ticks as its owner came close (it never flees)" % _closer_moves)
	_check(_moving_before_heal, "ROOT: the Healer was not walking when the heal came (the case was not exercised)")
	_check(_root_moves == 0, "ROOT: the Healer moved on %d ticks of its %d-tick cast" % [_root_moves, _cast_ticks])
	_check(_resumed > 0.1, "ROOT: the Healer did not walk on after its cast (moved %.3f m)" % _resumed)
	_check(is_equal_approx(_first_heal_hp, HURT_HP + _kind.heal_amount),
			"the owner, hurt to %.1f, read %.2f after the first heal (want +%.1f)" % [HURT_HP, _first_heal_hp, _kind.heal_amount])
	_check(_moving_before_shot, "SHOOT: the Healer was not walking when its shot became owed (the case was not exercised)")
	_check(_shot_left_frame > 0, "SHOOT: the owed shot never left")
	_check(_shot_moves == 0, "SHOOT: the Healer moved on %d ticks while its shot was owed or held (S18: rooted)" % _shot_moves)
	_check(_shot_resumed > 0.1, "SHOOT: the Healer did not walk on after its face hold (moved %.3f m)" % _shot_resumed)
	_check(_small_turned < YAW_EPS,
			"DEAD ZONE: the body turned %.4f rad for an owner %.1f degrees off (inside the %.1f degree dead zone)"
					% [_small_turned, rad_to_deg(_dead_zone * SMALL_TURN_FRACTION), rad_to_deg(_dead_zone)])
	_check(_turn_frames > 0, "TURN: the body never turned toward an owner %.0f degrees round" % BIG_TURN_DEGREES)
	_check(_too_fast == 0, "TURN: on %d ticks the body turned faster than its re-aim rate" % _too_fast)
	_check(_saw_turn_left, "TURN: the standing body turned left without playing `turn_left`")
	_check(_turn_faced > FACED_DOT, "TURN: the body ended facing its owner at %.4f, not on it" % _turn_faced)
	return _end("")


## Put the owner at the band's standing distance from the Healer, `angle` radians round to its LEFT of the way the
## body faces (positive about +Y), at the owner's own height.
func _place_owner_at(healer: Node3D, owner: Node3D, angle: float) -> void:
	var forward := -healer.global_transform.basis.z
	var dir := Vector3(forward.x, 0.0, forward.z).normalized().rotated(Vector3.UP, angle)
	var at := healer.global_position + dir * _kind.heal_range * STAND_FRACTION
	owner.global_position = Vector3(at.x, owner.global_position.y, at.z)


## WALK: the row is judged away from the outer radius, both ways.
func _judge_rows(apart: float, has_row: bool) -> void:
	if _phase_frame < 2:
		return
	if apart > _kind.heal_range + ROW_BAND and has_row:
		_out_rows += 1
	elif apart < _kind.heal_range - ROW_BAND and not has_row:
		_missing_rows += 1


func _enter(phase: int, healer: Node3D) -> void:
	_phase = phase
	_phase_frame = 0
	_prev_apart = INF
	_still_frames = 0
	_last = healer.global_position


## Put the owner `distance` m from the Healer along x, toward the arena's centre, at the Healer's z.
func _move_owner(healer: Node3D, owner: Node3D, distance: float) -> void:
	var toward := signf(-healer.global_position.x) if not is_zero_approx(healer.global_position.x) else 1.0
	owner.global_position = Vector3(healer.global_position.x + toward * distance, owner.global_position.y,
			healer.global_position.z)


func _check_arrived(healer: Node3D, owner: Node3D, apart: float) -> void:
	_check(absf(apart - _kind.stop_distance) <= ARRIVE_EPS,
			"the Healer halted %.3f m from its owner, not at its %.2f m inner radius" % [apart, _kind.stop_distance])
	var forward := -healer.global_transform.basis.z
	var to_owner := Vector2(owner.global_position.x - healer.global_position.x,
			owner.global_position.z - healer.global_position.z).normalized()
	_check(Vector2(forward.x, forward.z).normalized().dot(to_owner) > 0.9, "the Healer does not face its owner")


func _planar(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _healer() -> UnitActor:
	if _runner == null or _index < 0:
		return null
	var actors: Array = _runner._unit_actors[0]
	if _index >= actors.size() or not is_instance_valid(actors[_index]):
		return null
	return actors[_index] as UnitActor


func _check(ok: bool, message: String) -> void:
	if not ok and _failures.size() < 20:
		_failures.append(message)


func _end(message: String) -> bool:
	if message != "":
		_failures.append(message)
	for f in _failures:
		print("  FAILED: " + f)
	var ok := _failures.is_empty()
	print("healer_follow_live: frames=%d stand=%d/%d walked=%.2f root_heal_frame=%d root_moves=%d resumed=%.2f first_heal_hp=%.2f"
			% [_frames, _stand_rows, _stand_ticks, _walk_moved, _root_heal_frame, _root_moves, _resumed, _first_heal_hp])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	if _runner != null and _runner._effects != null:
		_runner._effects.stop_all_sounds()
	var main := root.get_node_or_null("Main")
	if main != null:
		main.free()
	quit(0 if ok else 1)
	return false
