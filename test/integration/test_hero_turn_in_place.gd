extends SceneTree

## Story 6-7b (AC 6/AC 7) machine contract: an IDLE hero standing still whose pushed facing keeps
## turning plays `turn_left`/`turn_right`, picked by the SIGN of the facing change, and those two
## clips add no body yaw of their own on top of HeroActor.drive()'s single yaw write.
##
## DRIVEN THROUGH THE REAL PATH, the test_hero_clip_selection.gd way: HeroActor.drive() ->
## AnimationController.on_locomotion() -> AnimationPlayer, one tick per `_push`.
##
## WHAT "A KNOWN ROTATION DIRECTION" MEANS HERE (AC 6(a)). The facing is rotated toward the hero's
## local +X -- the exact vector AnimationController's direction split calls "right" and that
## `strafe_right` is selected for -- and the clip that plays must be the one whose SOURCE take
## (the Mixamo FBX, read before the library tool neutralised it) turns its Hips toward model +X. So
## the sign mapping is pinned against the clip's own authored rotation, not against a formula or a
## file name. (Anatomically local +X is the paladin's LEFT; the project names it "right" and the
## clip files follow that convention -- 6-7b finding, operator ruling, recorded not renamed.)
##
## THE FLICKER GUARD IS READ OFF THE CONTROLLER, never re-typed: the per-tick step used to turn is
## a multiple of `TURN_MIN_FACING_CROSS`, and the tick at which a turn may first appear is
## `TURN_MIN_HOLD_TICKS` -- both untuned knobs, so a retune must not need an edit here.
##
## Run: godot --headless --path . --script res://test/integration/test_hero_turn_in_place.gd

const TICK := 1.0 / 60.0
const AUTHORED_BALANCE := "res://data/balance/balance_config.tres"
const SOURCE_DIR := "res://assets/characters/paladin/"
const HIPS_TRACK := "Skeleton3D:mixamorig_Hips"
const TURN_CLIPS: Array[StringName] = [&"turn_left", &"turn_right"]

## Library vs source tolerances for AC 7: yaw in degrees, swing angle in degrees, position in metres.
## Float32 key residue measured at <= 0.00001 deg swing and 0.000 m position (6-7b dev pass).
const YAW_EPS_DEG := 0.01
const SWING_EPS_DEG := 0.001
const POS_EPS := 0.00001

## Ticks of unchanged facing that clear any held turn before a case starts.
const SETTLE_TICKS := 4
## How many ticks a turn case keeps turning past the hold, so "keeps playing" is asserted too.
const EXTRA_TURN_TICKS := 4

var _hero: HeroActor
var _player: AnimationPlayer
var _state: HeroState
var _walk_speed := 0.0
var _run_speed := 0.0
var _frames := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_hero = load("res://src/actors/hero/hero.tscn").instantiate() as HeroActor
	root.add_child(_hero)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


## One tick: push this velocity/facing through drive() and advance playback one physics step.
func _push(velocity: Vector3, facing: Vector2) -> StringName:
	_state.velocity = velocity
	_state.facing = facing
	_hero.drive(_state, TICK, _walk_speed, _run_speed)
	_player.advance(TICK)
	return _player.current_animation


## `facing` turned by `radians` toward the hero's local +X (negative: toward local -X). Local +X of
## a facing (x, y) is (y, -x) -- the same vector the controller's direction split calls "right".
static func _turned(facing: Vector2, radians: float) -> Vector2:
	var right := Vector2(facing.y, -facing.x)
	return (facing * cos(radians) + right * sin(radians)).normalized()


## A per-tick yaw step `factor` times the controller's minimum (its sine is the cross term).
static func _step(factor: float) -> float:
	return asin(AnimationController.TURN_MIN_FACING_CROSS) * factor


func _settle(facing: Vector2, label: String) -> void:
	for i in SETTLE_TICKS:
		var got := _push(Vector3.ZERO, facing)
		if i == SETTLE_TICKS - 1:
			_check(got == &"idle", "%s: settling on an unchanged facing should rest on idle, got '%s'"
				% [label, got])


## Turns the facing by `step` per tick at zero velocity: the first TURN_MIN_HOLD_TICKS - 1 ticks must
## still read idle, the hold tick and every tick after must read `want`. Returns the final facing.
func _turn_case(facing: Vector2, step: float, want: StringName, label: String) -> Vector2:
	_settle(facing, label)
	var hold := AnimationController.TURN_MIN_HOLD_TICKS
	for tick in range(1, hold + EXTRA_TURN_TICKS + 1):
		facing = _turned(facing, step)
		var got := _push(Vector3.ZERO, facing)
		var expected: StringName = &"idle" if tick < hold else want
		_check(got == expected, "%s: tick %d of turning (hold %d) expected '%s', got '%s'"
			% [label, tick, hold, expected, got])
	# Stop turning: the very next unchanged-facing tick drops the turn.
	var after := _push(Vector3.ZERO, facing)
	_check(after == &"idle", "%s: facing stopped changing, expected idle, got '%s'" % [label, after])
	return facing


## Signed net yaw, degrees, of a take's Hips rotation track: last key relative to the first, about
## skeleton +Y (the model's up; the Skeleton3D sits at identity in the model and Hips is its root).
static func _net_yaw_deg(anim: Animation) -> float:
	var track := _track(anim, Animation.TYPE_ROTATION_3D)
	if track == -1:
		return NAN
	var keys := anim.track_get_key_count(track)
	var t0 := _twist(anim.track_get_key_value(track, 0))
	var tl := _twist(anim.track_get_key_value(track, keys - 1))
	var rel := t0.inverse() * tl
	return rad_to_deg(wrapf(2.0 * atan2(rel.y, rel.w), -PI, PI))


static func _twist(q: Quaternion) -> Quaternion:
	var t := Quaternion(0.0, q.y, 0.0, q.w)
	return Quaternion.IDENTITY if t.length_squared() < 1e-12 else t.normalized()


static func _track(anim: Animation, type: Animation.TrackType) -> int:
	for t in anim.get_track_count():
		if anim.track_get_path(t) == NodePath(HIPS_TRACK) and anim.track_get_type(t) == type:
			return t
	return -1


func _source_take(clip: StringName) -> Animation:
	var scene: PackedScene = load(SOURCE_DIR + String(clip) + ".fbx")
	if scene == null:
		return null
	var root_node := scene.instantiate()
	var players := root_node.find_children("*", "AnimationPlayer", true, false)
	var out: Animation = null
	if players.size() == 1 and (players[0] as AnimationPlayer).has_animation(&"mixamo_com"):
		out = (players[0] as AnimationPlayer).get_animation(&"mixamo_com").duplicate(true)
	root_node.free()
	return out


## AC 6(a): the sign mapping, proven against the clip's own authored rotation in both directions.
func _sign_mapping_against_known_rotation() -> void:
	var toward_plus_x := _turn_case(Vector2(0.0, 1.0), _step(3.0), &"turn_right",
		"turning toward local +X ('right') from facing +Z")
	_turn_case(toward_plus_x, -_step(3.0), &"turn_left",
		"turning toward local -X ('left')")
	# The same two directions under a different starting facing: relative, never world-axis.
	_turn_case(Vector2(1.0, 0.0), _step(3.0), &"turn_right",
		"turning toward local +X ('right') from facing +X")
	_turn_case(Vector2(1.0, 0.0), -_step(3.0), &"turn_left",
		"turning toward local -X ('left') from facing +X")
	# The anchor: the clip selected for "toward local +X" is the one whose SOURCE take turns the body
	# toward model +X (positive yaw), and the other turns it the other way.
	var right_src := _source_take(&"turn_right")
	var left_src := _source_take(&"turn_left")
	if right_src == null or left_src == null:
		_failures.append("known rotation: turn_left.fbx / turn_right.fbx source take did not load")
		return
	var right_yaw := _net_yaw_deg(right_src)
	var left_yaw := _net_yaw_deg(left_src)
	_check(right_yaw > YAW_EPS_DEG,
		("known rotation: turn_right plays for a facing turning toward local +X, so its source take "
		+ "must turn the Hips toward model +X (positive yaw); measured %.3f deg") % right_yaw)
	_check(left_yaw < -YAW_EPS_DEG,
		("known rotation: turn_left plays for a facing turning toward local -X, so its source take "
		+ "must turn the Hips toward model -X (negative yaw); measured %.3f deg") % left_yaw)


## AC 6: the no-turn cases -- facing unchanged, a change below the minimum, and a change while moving.
func _no_turn_cases() -> void:
	var facing := Vector2(0.0, 1.0)
	_settle(facing, "unchanged facing")
	for i in 10:
		var got := _push(Vector3.ZERO, facing)
		_check(got == &"idle", "unchanged facing, tick %d: expected idle, got '%s'" % [i, got])

	# Below TURN_MIN_FACING_CROSS: however long it goes on, no turn.
	_settle(facing, "sub-threshold turning")
	for i in 20:
		facing = _turned(facing, _step(0.5))
		var got := _push(Vector3.ZERO, facing)
		_check(got == &"idle", "turning below the minimum yaw change, tick %d: expected idle, got '%s'"
			% [i, got])

	# Moving at the walk tempo along a facing that keeps turning well above the minimum: the moving
	# clip plays and a turn clip never does (IDLE-and-still only, by construction).
	_settle(facing, "turning while moving")
	for i in 12:
		facing = _turned(facing, _step(3.0))
		var got := _push(Vector3(facing.x, 0.0, facing.y) * _walk_speed, facing)
		_check(got == &"walk", "turning while walking forward, tick %d: expected walk, got '%s'"
			% [i, got])


## AC 6(b): a facing change made DURING a non-IDLE action, then a return to IDLE with no further
## change, must not fire a turn. The hero is mid-turn (hold already reached) when the roll starts, so
## a facing memory that only advanced on IDLE ticks would compare the pre-roll facing with the
## post-roll one on the first IDLE tick -- same sign, hold still counted -- and play a spurious turn.
func _no_spurious_turn_after_action() -> void:
	var controller := _hero.animation_controller
	var facing := Vector2(0.0, 1.0)
	_settle(facing, "post-action")
	var hold := AnimationController.TURN_MIN_HOLD_TICKS
	for i in hold + 1:
		facing = _turned(facing, _step(3.0))
		_push(Vector3.ZERO, facing)
	_check(_player.current_animation == &"turn_right",
		"post-action: precondition, the hero should be mid-turn before the roll (got '%s')"
			% _player.current_animation)
	controller.on_action_state_changed(HeroState.ActionState.IDLE, HeroState.ActionState.ROLLING)
	for i in 3:
		facing = _turned(facing, _step(3.0))
		var rolling := _push(Vector3.ZERO, facing)
		_check(rolling == &"roll", "post-action: turning during ROLLING must keep the roll clip, got '%s'"
			% rolling)
	for i in 3:
		_push(Vector3.ZERO, facing)
	controller.on_action_state_changed(HeroState.ActionState.ROLLING, HeroState.ActionState.IDLE)
	for i in hold + 2:
		var got := _push(Vector3.ZERO, facing)
		_check(got == &"idle",
			("post-action: back in IDLE with the facing unchanged since the roll, tick %d: expected "
			+ "idle, got '%s' (a spurious turn off a stale previous facing)") % [i, got])


## Content, not naming (the 5-0a `_clip_content_changes` precedent): each turn clip, once selected,
## actually animates the Hips -- the yaw is gone but the step/sway must not be.
func _turn_clip_content() -> void:
	var skeleton := _hero.skeleton
	var bone := skeleton.find_bone("mixamorig_Hips")
	if bone < 0:
		_failures.append("turn content: mixamorig_Hips bone missing from Skeleton3D")
		return
	for clip: StringName in TURN_CLIPS:
		var step := _step(3.0) if clip == &"turn_right" else -_step(3.0)
		var facing := Vector2(0.0, 1.0)
		_settle(facing, "turn content '%s'" % clip)
		for i in AnimationController.TURN_MIN_HOLD_TICKS:
			facing = _turned(facing, step)
			_push(Vector3.ZERO, facing)
		_check(_player.current_animation == clip, "turn content: could not select '%s' (got '%s')"
			% [clip, _player.current_animation])
		_player.seek(0.0, true)
		var before: Transform3D = skeleton.get_bone_pose(bone)
		var length: float = _player.get_animation(clip).length
		_player.advance(length * 0.5)
		var after: Transform3D = skeleton.get_bone_pose(bone)
		_check(not before.is_equal_approx(after),
			"turn content: clip '%s' - mixamorig_Hips pose did not change after advancing %.4fs"
				% [clip, length * 0.5])


## AC 7: the library turn clips carry NO Hips yaw (net or at any key, relative to the first key), and
## everything else on the Hips -- the swing (sway/tilt) of every rotation key and every position key
## -- is identical to the source take. Yaw removed, nothing else touched.
func _turn_clips_carry_no_yaw() -> void:
	for clip: StringName in TURN_CLIPS:
		var lib := _player.get_animation(clip)
		var src := _source_take(clip)
		if lib == null or src == null:
			_failures.append("AC 7: '%s' missing from the library or its source take did not load" % clip)
			continue
		var lr := _track(lib, Animation.TYPE_ROTATION_3D)
		var sr := _track(src, Animation.TYPE_ROTATION_3D)
		if lr == -1 or sr == -1 or lib.track_get_key_count(lr) != src.track_get_key_count(sr):
			_failures.append("AC 7: '%s' Hips rotation tracks missing or key counts differ" % clip)
			continue
		var src_net := _net_yaw_deg(src)
		_check(absf(src_net) > 45.0,
			"AC 7: '%s' source take should be a real turn (it is the thing neutralised); net yaw %.3f"
				% [clip, src_net])
		var t0 := _twist(lib.track_get_key_value(lr, 0))
		var worst_yaw := 0.0
		var worst_swing := 0.0
		for k in lib.track_get_key_count(lr):
			var ql: Quaternion = lib.track_get_key_value(lr, k)
			var qs: Quaternion = src.track_get_key_value(sr, k)
			var rel := t0.inverse() * _twist(ql)
			worst_yaw = maxf(worst_yaw, absf(rad_to_deg(wrapf(2.0 * atan2(rel.y, rel.w), -PI, PI))))
			var swing_rel := (_twist(ql).inverse() * ql).inverse() * (_twist(qs).inverse() * qs)
			var vec_len := minf(Vector3(swing_rel.x, swing_rel.y, swing_rel.z).length(), 1.0)
			worst_swing = maxf(worst_swing, rad_to_deg(2.0 * asin(vec_len)))
		_check(worst_yaw <= YAW_EPS_DEG,
			"AC 7: '%s' library Hips yaw still moves %.4f deg from its first key (source net %.3f)"
				% [clip, worst_yaw, src_net])
		_check(worst_swing <= SWING_EPS_DEG,
			"AC 7: '%s' library Hips SWING differs from the source by %.5f deg -- only yaw may change"
				% [clip, worst_swing])
		var lp := _track(lib, Animation.TYPE_POSITION_3D)
		var sp := _track(src, Animation.TYPE_POSITION_3D)
		if lp == -1 or sp == -1 or lib.track_get_key_count(lp) != src.track_get_key_count(sp):
			_failures.append("AC 7: '%s' Hips position tracks missing or key counts differ" % clip)
			continue
		var worst_pos := 0.0
		for k in lib.track_get_key_count(lp):
			worst_pos = maxf(worst_pos, ((lib.track_get_key_value(lp, k) as Vector3)
				- (src.track_get_key_value(sp, k) as Vector3)).length())
		_check(worst_pos <= POS_EPS,
			"AC 7: '%s' library Hips POSITION differs from the source by %.6f -- only yaw may change"
				% [clip, worst_pos])


## Fix pass (2026-09-16, operator live smoke item 4): AC 6 amendment -- a slow SUSTAINED rotation
## clearly above true noise but far below the old ~30 deg/s selection floor must still select a turn
## clip once the hold clears. 5 deg/s is a BEHAVIOURAL REQUIREMENT (this is exactly the reported
## defect: a far, slow-circling lock target), not derived from any knob -- unlike `_no_turn_cases`'
## sub-threshold case, which reads `TURN_MIN_FACING_CROSS` directly and must keep doing so.
func _slow_sustained_rotation_selects_turn() -> void:
	const SLOW_ROTATION_DEG_PER_SEC := 5.0
	var facing := Vector2(0.0, 1.0)
	_settle(facing, "slow sustained rotation")
	var hold := AnimationController.TURN_MIN_HOLD_TICKS
	var step := deg_to_rad(SLOW_ROTATION_DEG_PER_SEC) * TICK
	for tick in range(1, hold + EXTRA_TURN_TICKS + 1):
		facing = _turned(facing, step)
		var got := _push(Vector3.ZERO, facing)
		var expected: StringName = &"idle" if tick < hold else &"turn_right"
		_check(got == expected,
			("slow sustained rotation (%.1f deg/s): tick %d of turning (hold %d) expected '%s', got "
			+ "'%s'") % [SLOW_ROTATION_DEG_PER_SEC, tick, hold, expected, got])


## Fix pass (2026-09-16): AC 8 amendment -- turn playback rate is proportional to the rotation rate.
## Two rates DERIVED from `TURN_NATIVE_ROTATION_RATE_DEG_PER_SEC` and the clamp knobs
## (`TURN_MIN_PLAYBACK_RATE`/`TURN_MAX_PLAYBACK_RATE`) at 25% and 75% of the clamp span, so both stay
## strictly inside the clamp regardless of a retune: the ratio of the resulting PLAYING speeds must
## equal the ratio of the rotation rates -- asserting the ratio, never a knob value, so a retune of the
## native rate or the clamp bounds cannot make this pass by accident.
func _rate_proportional_to_rotation_rate() -> void:
	var span := AnimationController.TURN_MAX_PLAYBACK_RATE - AnimationController.TURN_MIN_PLAYBACK_RATE
	var rate_a_deg_per_sec := (AnimationController.TURN_MIN_PLAYBACK_RATE + 0.25 * span) \
		* AnimationController.TURN_NATIVE_ROTATION_RATE_DEG_PER_SEC
	var rate_b_deg_per_sec := (AnimationController.TURN_MIN_PLAYBACK_RATE + 0.75 * span) \
		* AnimationController.TURN_NATIVE_ROTATION_RATE_DEG_PER_SEC
	var speed_a := _turn_playing_speed_at(rate_a_deg_per_sec,
		"rate proportionality, rate A (%.1f deg/s)" % rate_a_deg_per_sec)
	var speed_b := _turn_playing_speed_at(rate_b_deg_per_sec,
		"rate proportionality, rate B (%.1f deg/s)" % rate_b_deg_per_sec)
	if speed_a <= 0.0 or speed_b <= 0.0:
		return
	var want_ratio := rate_b_deg_per_sec / rate_a_deg_per_sec
	var got_ratio := speed_b / speed_a
	_check(absf(got_ratio - want_ratio) <= 0.01,
		("rate proportionality: rotation-rate ratio %.4f, playing-speed ratio %.4f (speeds %.4f / "
		+ "%.4f measured) -- must match within tolerance") % [want_ratio, got_ratio, speed_a, speed_b])


## Drives a sustained rotation at `deg_per_sec` past the hold and returns the resulting
## `AnimationPlayer` playing speed. Appends a failure and returns 0.0 if a turn clip never selects at
## all (the caller treats that as a hard fail rather than comparing against a meaningless 0.0 ratio).
func _turn_playing_speed_at(deg_per_sec: float, label: String) -> float:
	var facing := Vector2(0.0, 1.0)
	_settle(facing, label)
	var hold := AnimationController.TURN_MIN_HOLD_TICKS
	var step := deg_to_rad(deg_per_sec) * TICK
	var got: StringName = &""
	for tick in range(1, hold + 2):
		facing = _turned(facing, step)
		got = _push(Vector3.ZERO, facing)
	if got != &"turn_right":
		_failures.append("%s: expected 'turn_right' to be selected, got '%s'" % [label, got])
		return 0.0
	return _player.get_playing_speed()


## One tick of grace: AnimationController resolves its AnimationPlayer in _ready, which a node added
## from _initialize() only gets on the first processed frame (4-3c, measured).
func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false

	var authored: BalanceConfig = load(AUTHORED_BALANCE)
	if authored == null or authored.walk_speed <= AnimationController.RUN_SPEED_EPS \
			or authored.move_speed <= authored.walk_speed:
		_failures.append("authored balance must carry RUN_SPEED_EPS < walk_speed < move_speed")
	else:
		_walk_speed = authored.walk_speed
		_run_speed = authored.move_speed
	_state = HeroState.new(SignalQueue.new(), 100.0, _run_speed)
	_player = _hero.animation_controller.animation_player
	if _player == null:
		_failures.append("hero.tscn did not yield a wired AnimationController")
	elif _failures.is_empty():
		_sign_mapping_against_known_rotation()
		_no_turn_cases()
		_no_spurious_turn_after_action()
		_turn_clip_content()
		_turn_clips_carry_no_yaw()
		_slow_sustained_rotation_selects_turn()
		_rate_proportional_to_rotation_rate()

	if is_instance_valid(_hero):
		_hero.queue_free()
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
