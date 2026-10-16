extends SceneTree

## Story 7-5b (AC 10): WHAT THE HEALER'S RIG PLAYS FOR WHAT STATE SAYS, driven the way the runner drives it --
## `on_unit_support(heal_count, shot_owed, hp)`, `on_unit_motion(forward, side, row)`, then
## `on_unit_tick(alive, phase, speed)` -- on the shipped healer_actor.tscn with the AUTHORED `healer` presentation
## row (read at run time, never copied). `test_hound_clip_selection.gd`'s counterpart.
##
## EVERY ASSERTION IS AN EFFECT READ OFF THE AnimationPlayer: which clip is current, where its playhead is and
## how fast it runs. None reads a controller constant.
##
##   LOCOMOTION   (smoke fix 1, S3) standing `idle`; `walk` only ABOVE the row's `walk_enter_speed` and back to
##                `idle` only BELOW its `walk_exit_speed` -- between the two the clip held is kept, both ways;
##                `walk` plays at ground speed over the measured natural speed at the mount, inside the row's
##                rate bounds.
##   CAST         a RISE of the heal count plays `cast` from frame 0, fitted to the row's `cast_seconds` (S4);
##                walking off does not cut it.
##   SHOOT        a newly OWED shot plays `shoot` from frame 0 at `release / ((owed + 1) / 60)` -- fitted to the
##                pushed countdown, so a retuned delay fits too; a heal inside the owed window does not cut it.
##   HURT         (S6) a FALL of the pushed hp plays `hurt` from frame 0; the first push never does; it does not
##                cut a playing `cast` nor an owed `shoot`; a second hit restarts it.
##   DEATH        liveness FIRST, over a newly owed shot, a heal and a hit on the same tick.
##   STRAFE       (smoke fix 2, S15c) WALKING with the motion more sideways than forward plays `strafe_right` (to its
##                right) or `strafe_left`, at ground speed over the strafe's own natural speed at the mount, inside
##                the row's bounds; forward-dominant motion stays `walk`.
##   TURN         (S15b) STANDING while the body turns plays `turn_left` (a positive yaw speed) or `turn_right`, from
##                frame 0, at `length x |yaw| / measured degrees`; no turn is `idle`; a WALKING body that turns stays
##                on its walk; a turn never cuts `cast`, an owed `shoot` or `hurt`.
##   THE ZOMBIE   pushed the same facts, selects exactly as before.
##
## THE MARKS BELOW ARE MEASUREMENTS (tools/measure_healer_rig.gd: the release frame 27 at 30 fps, table 4; the
## walk's natural ground speed 1.8778 model units/s, table 6; smoke fix 2: the strafes' 1.5645 / 1.6637 as built,
## table 6, and the turns' 90.00 / 90.15 degrees, table 8), restated so this file fails if the controller's
## numbers move without the measurement being redone.
##
## Run: godot --headless --path . --script res://test/integration/test_healer_clip_selection.gd

const RELEASE := 27.0 / 30.0
const WALK_GROUND_UNITS := 1.8778
const STRAFE_LEFT_UNITS := 1.5645
const STRAFE_RIGHT_UNITS := 1.6637
const TURN_LEFT_DEGREES := 90.00
const TURN_RIGHT_DEGREES := 90.15
const TICK_HZ := 60.0
const EPS := 0.002
const NONE := UnitBoard.NO_SHOT_OWED
const IDLE := UnitBoard.AttackPhase.IDLE
const HP := 18.0
const HEALERS := 20

var _healers: Array[UnitActor] = []
var _zombie: UnitActor
var _row: EffectPresentationRow
var _next := 0
var _failures: Array[String] = []


## One frame, for test_unit_attack_retrigger.gd's measured reason: `_ready()` has not run on a node added
## from inside `_initialize()`, so the controllers resolve their AnimationPlayer on the first `_process`.
func _initialize() -> void:
	var scene: PackedScene = load("res://src/actors/minions/healer_actor.tscn")
	for i in HEALERS:
		var healer := scene.instantiate() as UnitActor
		root.add_child(healer)
		_healers.append(healer)
	_zombie = (load("res://src/actors/minions/unit_actor.tscn") as PackedScene).instantiate() as UnitActor
	root.add_child(_zombie)
	var set := load(EffectPresentationSet.AUTHORED_PATH) as EffectPresentationSet
	_row = set.row(&"healer") if set != null else null


func _process(_delta: float) -> bool:
	if _row == null:
		_failures.append("the authored `healer` presentation row did not load")
	else:
		_run()
	_check(_next <= HEALERS, "the test used %d healers and instantiated %d" % [_next, HEALERS])
	for healer: UnitActor in _healers:
		healer.queue_free()
	_zombie.queue_free()
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true


func _run() -> void:
	var enter := _row.knob(&"walk_enter_speed", -1.0)
	var exit := _row.knob(&"walk_exit_speed", -1.0)
	var rate_min := _row.knob(&"locomotion_rate_min", -1.0)
	var rate_max := _row.knob(&"locomotion_rate_max", -1.0)
	var cast_seconds := _row.knob(&"cast_seconds", -1.0)
	_check(exit > 0.0 and enter > exit, "the row's walk thresholds are not a band (exit %.2f, enter %.2f)" % [exit, enter])
	_check(cast_seconds > 0.0, "the row authors no `cast_seconds`")
	var between := (enter + exit) * 0.5

	# LOCOMOTION, with hysteresis.
	var h := _fresh()
	_tick(h, true, 0.0, 0, NONE, HP)
	_expect(h, &"idle", "standing")
	_tick(h, true, between, 0, NONE, HP)
	_expect(h, &"idle", "between the thresholds from standing (%.2f m/s)" % between)
	_tick(h, true, enter + 0.05, 0, NONE, HP)
	_expect(h, &"walk", "above `walk_enter_speed`")
	_tick(h, true, between, 0, NONE, HP)
	_expect(h, &"walk", "between the thresholds from walking (%.2f m/s)" % between)
	_tick(h, true, exit - 0.05, 0, NONE, HP)
	_expect(h, &"idle", "below `walk_exit_speed`")

	# WALK AT GROUND SPEED: the authored kind speed and a slow one, each against the bounds.
	var natural := WALK_GROUND_UNITS * _mount_scale(h)
	for speed: float in [2.4, 1.0]:
		h = _fresh()
		_tick(h, true, speed, 0, NONE, HP)
		_expect(h, &"walk", "walking at %.1f m/s" % speed)
		var want := clampf(speed / natural, rate_min, rate_max)
		_check(absf(_player(h).get_playing_speed() - want) < EPS,
				"`walk` at %.1f m/s plays at %.4f, its feet keep the floor at %.4f (natural %.4f m/s)"
						% [speed, _player(h).get_playing_speed(), want, natural])

	# CAST on a heal that healed, fitted to `cast_seconds`, not cut by walking off.
	h = _fresh()
	_tick(h, true, 0.0, 0, NONE, HP)
	_tick(h, true, 0.0, 1, NONE, HP)
	_expect(h, &"cast", "the heal count rose")
	_check(absf(_player(h).current_animation_position) < EPS, "`cast` did not start at frame 0")
	var cast_rate := _player(h).get_animation(&"cast").length / cast_seconds
	_check(absf(_player(h).get_playing_speed() - cast_rate) < EPS,
			"`cast` plays at %.4f, the whole clip in %.2f s is %.4f" % [_player(h).get_playing_speed(), cast_seconds, cast_rate])
	_tick(h, true, 3.0, 1, NONE, HP)
	_expect(h, &"cast", "walking off mid-cast")
	_tick(h, true, 0.0, 2, NONE, HP)
	_expect(h, &"cast", "a second heal")
	_check(absf(_player(h).current_animation_position) < EPS, "a second heal did not restart `cast`")

	# SHOOT, fitted to the pushed countdown: the authored delay's (owed 23 -> 24 ticks) and a retuned one.
	for owed: int in [23, 5]:
		h = _fresh()
		_tick(h, true, 0.0, 0, NONE, HP)
		_tick(h, true, 0.0, 0, owed, HP)
		_expect(h, &"shoot", "a shot became owed (%d)" % owed)
		_check(absf(_player(h).current_animation_position) < EPS, "`shoot` did not start at frame 0 (owed %d)" % owed)
		var want := RELEASE / (float(owed + 1) / TICK_HZ)
		_check(absf(_player(h).get_playing_speed() - want) < EPS,
				"owed %d: `shoot` plays at %.4f, the release lands on the spawn tick at %.4f"
						% [owed, _player(h).get_playing_speed(), want])
		_tick(h, true, 3.0, 1, owed - 1, HP)
		_expect(h, &"shoot", "a heal inside the owed window (owed %d)" % owed)
		_tick(h, true, 0.0, 1, owed - 2, HP - 3.0)
		_expect(h, &"shoot", "a hit inside the owed window (owed %d)" % owed)

	# HURT on a fall of hp; never on the first push; a second hit restarts it.
	h = _fresh()
	_tick(h, true, 0.0, 0, NONE, HP - 3.0)
	_expect(h, &"idle", "the first push, at less than full hp")
	_tick(h, true, 0.0, 0, NONE, HP - 6.0)
	_expect(h, &"hurt", "the hp fell")
	_check(absf(_player(h).current_animation_position) < EPS, "`hurt` did not start at frame 0")
	_player(h).seek(0.5, true)
	_tick(h, true, 3.0, 0, NONE, HP - 6.0)
	_expect(h, &"hurt", "walking off mid-hurt")
	_tick(h, true, 0.0, 0, NONE, HP - 9.0)
	_check(absf(_player(h).current_animation_position) < EPS, "a second hit did not restart `hurt`")
	_player(h).seek(0.5, true)
	_tick(h, true, 0.0, 0, NONE, HP - 7.0)
	_expect(h, &"hurt", "the hp rose mid-hurt")
	_check(absf(_player(h).current_animation_position - 0.5) < EPS, "a RISE of hp restarted `hurt` as a hit")

	# A HIT DOES NOT CUT A CAST.
	h = _fresh()
	_tick(h, true, 0.0, 0, NONE, HP)
	_tick(h, true, 0.0, 1, NONE, HP)
	_tick(h, true, 0.0, 1, NONE, HP - 3.0)
	_expect(h, &"cast", "hit mid-cast")

	# DEATH first, over a newly owed shot, a heal and a hit on the same tick.
	h = _fresh()
	_tick(h, true, 0.0, 0, NONE, HP)
	_tick(h, false, 0.0, 1, 23, 0.0)
	_expect(h, &"death", "killed on the tick a heal, a shot and the killing hit all arrived")

	_run_strafe_and_turn(enter, rate_min, rate_max)

	# THE ZOMBIE ignores the push.
	_zombie.animation.on_unit_support(5, 3, 1.0)
	_zombie.animation.on_unit_tick(true, IDLE, 0.0)
	_check(_zombie.animation.animation_player.current_animation == &"idle",
			"the zombie, pushed a heal, an owed shot and a hit, plays '%s'" % _zombie.animation.animation_player.current_animation)


## Smoke fix 2 (S15b/c): the strafes and the turns.
func _run_strafe_and_turn(enter: float, rate_min: float, rate_max: float) -> void:
	var speed := enter + 1.4
	# STRAFE, both ways, each at its own natural speed; forward-dominant stays `walk`.
	for side: float in [1.0, -1.0]:
		var h := _fresh()
		_tick_moving(h, speed * 0.3, speed * side, 0.0, 0, NONE, HP)
		var clip := &"strafe_right" if side > 0.0 else &"strafe_left"
		_expect(h, clip, "walking more sideways than forward (side %+.1f)" % side)
		var ground := Vector2(speed * 0.3, speed).length()
		var natural := (STRAFE_RIGHT_UNITS if side > 0.0 else STRAFE_LEFT_UNITS) * _mount_scale(h)
		var want := clampf(ground / natural, rate_min, rate_max)
		_check(absf(_player(h).get_playing_speed() - want) < EPS,
				"`%s` at %.2f m/s plays at %.4f, its feet keep the floor at %.4f (natural %.4f m/s)"
						% [clip, ground, _player(h).get_playing_speed(), want, natural])
		_tick_moving(h, speed, speed * 0.3 * side, 0.0, 0, NONE, HP)
		_expect(h, &"walk", "walking more forward than sideways (side %+.1f)" % side)

	# TURN IN PLACE, both ways, fitted to the yaw speed; none is `idle`.
	for yaw: float in [90.0, -90.0, 540.0]:
		var h := _fresh()
		_tick_moving(h, 0.0, 0.0, 0.0, 0, NONE, HP)
		_tick_moving(h, 0.0, 0.0, yaw, 0, NONE, HP)
		var left := yaw > 0.0
		var clip := &"turn_left" if left else &"turn_right"
		_expect(h, clip, "standing while turning at %+.0f deg/s" % yaw)
		_check(absf(_player(h).current_animation_position) < EPS, "`%s` did not start at frame 0" % clip)
		var want := _player(h).get_animation(clip).length * absf(yaw) / (TURN_LEFT_DEGREES if left else TURN_RIGHT_DEGREES)
		_check(absf(_player(h).get_playing_speed() - want) < EPS,
				"`%s` at %+.0f deg/s plays at %.4f, its feet cover the turn at %.4f" % [clip, yaw,
						_player(h).get_playing_speed(), want])
		_tick_moving(h, 0.0, 0.0, 0.0, 0, NONE, HP)
		_expect(h, &"idle", "the turn ended (from %+.0f deg/s)" % yaw)

	# A WALKING body that turns stays on its walk.
	var walker := _fresh()
	_tick_moving(walker, speed, 0.0, 90.0, 0, NONE, HP)
	_expect(walker, &"walk", "walking while turning")

	# A TURN NEVER CUTS `cast`, an owed `shoot` or `hurt`.
	var h := _fresh()
	_tick_moving(h, 0.0, 0.0, 0.0, 0, NONE, HP)
	_tick_moving(h, 0.0, 0.0, 0.0, 1, NONE, HP)
	_tick_moving(h, 0.0, 0.0, 90.0, 1, NONE, HP)
	_expect(h, &"cast", "turning mid-cast")
	h = _fresh()
	_tick_moving(h, 0.0, 0.0, 0.0, 0, NONE, HP)
	_tick_moving(h, 0.0, 0.0, 0.0, 0, 23, HP)
	_tick_moving(h, 0.0, 0.0, 540.0, 0, 22, HP)
	_expect(h, &"shoot", "turning to the target while a shot is owed")
	h = _fresh()
	_tick_moving(h, 0.0, 0.0, 0.0, 0, NONE, HP)
	_tick_moving(h, 0.0, 0.0, 0.0, 0, NONE, HP - 3.0)
	_tick_moving(h, 0.0, 0.0, 90.0, 0, NONE, HP - 3.0)
	_expect(h, &"hurt", "turning mid-hurt")


## One runner tick with the whole motion: forward and side speed (m/s) and the yaw speed (deg/s, + = left).
func _tick_moving(healer: UnitActor, forward: float, side: float, yaw: float, heal_count: int, shot_owed: int,
		hp: float) -> void:
	healer.animation.on_unit_support(heal_count, shot_owed, hp)
	healer.animation.on_unit_motion(forward, side, _row, yaw)
	healer.animation.on_unit_tick(true, IDLE, Vector2(forward, side).length())


func _fresh() -> UnitActor:
	var healer := _healers[_next]
	_next += 1
	return healer


## One runner tick: the support facts, the motion (all of `speed` forward) with the authored row, then the tick.
func _tick(healer: UnitActor, alive: bool, speed: float, heal_count: int, shot_owed: int, hp: float) -> void:
	healer.animation.on_unit_support(heal_count, shot_owed, hp)
	healer.animation.on_unit_motion(speed, 0.0, _row)
	healer.animation.on_unit_tick(alive, IDLE, speed)


func _mount_scale(healer: UnitActor) -> float:
	var mount := healer.get_node_or_null("Healer") as Node3D
	return mount.transform.basis.get_scale().y if mount != null else 1.0


func _player(healer: UnitActor) -> AnimationPlayer:
	return healer.animation.animation_player


func _expect(healer: UnitActor, clip: StringName, when: String) -> void:
	var current := _player(healer).current_animation
	_check(current == clip, "%s: expected '%s', playing '%s'" % [when, clip, current])


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
