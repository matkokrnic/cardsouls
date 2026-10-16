class_name HealerAnimationController
extends UnitAnimationController

## Rig presentation layer for the Healer (story 7-5b, ACs 9-11): the Healer's READ-ONLY clip selector,
## `UnitAnimationController`'s per-kind counterpart, holding that file's whole posture -- no
## `_physics_process` (F1), no `Input`, no state handle, no mutator, no decision -- and PUSHED from the same
## seat, `MatchRunner._aim_unit_actors`, once per tick.
##
## THREE POLLED FACTS, ONE MORE ARGUMENT LIST ON THE EXISTING PUSH (AC 10; the family stays ten). The runner
## calls `on_unit_support(heal_count, shot_owed, hp)` with three plain values off the unit's board record
## (`UnitBoard.heal_count_at`, `shot_owed_at`, `hp_at`) just before `on_unit_tick`, the hound's
## `on_unit_behavior` precedent, and `on_unit_motion(forward, side, row, yaw)` with the motion the body actually
## made, the kind's presentation row and (smoke fix 2) the yaw speed it actually turned at. This controller only STORES them there; it selects inside
## `on_unit_tick`.
##
## SELECTION (a machine contract, like the base's):
##   1. NOT ALIVE              -> `death`, at authored speed, held on its last frame.
##   2. a shot became OWED     -> `shoot`, from frame 0, RATE-FITTED so its measured release frame lands on
##                                the tick state spawns the shot (below) -- and HELD while the shot is owed.
##   3. the heal count ROSE    -> `cast`, from frame 0 (a heal tick that healed; a skipped tick counts nothing),
##                                RATE-FITTED to the row's `cast_seconds` (smoke fix 1, S4: about 1.0 s, a
##                                gesture rather than the clip's 2.97 s). The runner roots the body for the same
##                                `cast_seconds` (`MatchRunner._follow_owner`), so it is played standing still.
##   4. the hp FELL            -> `hurt`, from frame 0 (smoke fix 1, S6) -- unless a `cast` is playing, which it
##                                never cuts; an owed `shoot` returned at 2 already. Presentation only: no state
##                                reads it, nothing staggers.
##   5. otherwise              -> `walk` or `idle` by the body's measured ground speed, with HYSTERESIS (smoke
##                                fix 1, S3) -- after a playing `cast`, `shoot` or `hurt` has run to its end (a
##                                one-shot is not cut by walking off). Since smoke fix 2 (S15): WALKING with its
##                                motion more sideways than forward plays `strafe_left` / `strafe_right` instead
##                                of `walk`, fitted to ground speed the same way; STANDING while the body turns
##                                plays `turn_left` / `turn_right`, fitted to the turn (below).
## 2, 3 and 4 are EDGES: a newly owed shot, a new heal or a new hit restarts its clip.
##
## WHY THE SHOT OUTRANKS THE HEAL (story 7-5b dev pass, measured live): AC 10 lists `cast` before `shoot`,
## but its machine claim is that the release lands on the spawn tick. The heal clock (5 s) and an owed shot
## (0.4 s) are independent, so a heal tick can fall inside the owed window (`test_healer_strike_alignment_
## live.gd` hit it); a `cast` started there would cut the `shoot` and miss the spawn. So a newly owed shot
## wins its tick, and a heal inside the owed window plays no `cast` (its marker still shows over the owner).
##
## THE SHOOT RATE COMES FROM THE PUSHED COUNTDOWN, NOT FROM A COPIED CONSTANT. State owes the shot at the
## owner's accepted press with `shot_owed = delay - 1` after that tick's `advance()`, and spawns it `owed + 1`
## ticks after the tick the edge is seen. Playing the clip at `SHOOT_RELEASE_SECONDS / ((owed + 1) / TICK_HZ)`
## puts the release frame on that spawn tick for any authored delay -- `4-3d`'s single custom rate with
## `7-3`'s pushed time, so a retune needs nothing re-derived here.
##
## WALK WITHOUT SLIDING (smoke fix 1, S3, the hound's `PLAYBACK AT GROUND SPEED`): `walk` plays at the body's
## ground speed over the clip's natural one (`WALK_GROUND_SPEED_UNITS` times the mount scale read off the
## scene), inside the row's `locomotion_rate_min`/`_max`. The body starts walking above the row's
## `walk_enter_speed` and stops below its lower `walk_exit_speed`, so a body hovering at one threshold does not
## flicker; every change of clip blends over the row's `blend_seconds`.

## The measured RELEASE FRAME of `shoot` (Mixamo "Standing 1H Magic Attack 03", 2.3000 s), in seconds of the
## clip's own time. MEASURED (`tools/measure_healer_rig.gd`, table 4; story 7-5b T1, re-measured unchanged at
## smoke fix 1): the right hand winds back to -0.513 model units behind the hips (frames 10-11), thrusts
## forward and its forward extension peaks at +0.8147 at FRAME 27 of 69 (30 fps) -- `measure_strike_frame.gd`'s
## method, the hand's arrival, not the Hips peak (`4-3d/R13`).
const SHOOT_RELEASE_SECONDS := 27.0 / 30.0

## The NATURAL GROUND SPEED of `walk`, in MODEL units per second, MEASURED (`tools/measure_healer_rig.gd`,
## table 6; smoke fix 1): the take is in place, so it is the speed at which a planted toe is carried back under
## the body -- 1.8835 (left) and 1.8724 (right) over 33 planted steps. Times the 0.8 mount that is 1.50 m/s, so
## the authored 3.0 m/s plays the clip at 2.0.
const WALK_GROUND_SPEED_UNITS := 1.8778

## Smoke fix 2 (S15c): the two strafes' NATURAL GROUND SPEED as built, in MODEL units per second, MEASURED
## (`tools/measure_healer_rig.gd` table 6 AS BUILT): Mixamo "Standing Walk Left" / "Standing Walk Right" travel
## (Hips net X +1.7496 / -1.8613), so the build zeroes their Hips X/Z and a planted toe is then carried under the
## body at 1.5645 (left) and 1.6637 (right). Played at ground speed over these, the walk's rule.
const STRAFE_LEFT_GROUND_SPEED_UNITS := 1.5645
const STRAFE_RIGHT_GROUND_SPEED_UNITS := 1.6637

## Smoke fix 2 (S15b): how far each turn clip turns the body over its whole length, MEASURED on the raw takes
## (`tools/measure_healer_rig.gd` table 8: Hips net yaw +90.00 / -90.15). The build NEUTRALISES that yaw (the
## runner's own yaw turns the actor), so the clip is footwork for this many degrees: played at
## `length x yaw speed / degrees`, its feet cover the turn the body is making -- rate-fitted to the turn.
const TURN_LEFT_DEGREES := 90.00
const TURN_RIGHT_DEGREES := 90.15

## A measured yaw speed at or below this (degrees per second) is standing still, not turning. Not tuning: the
## line between a turn and float noise in the measured rotation.
const TURN_SPEED_EPS := 1.0

## A countdown of zero is given one tick, so no rate divides by zero.
const MIN_SHOT_TICKS := 1

## `UnitBoard.NO_SHOT_OWED`, the resting countdown: no shot owed.
const NO_SHOT_OWED := UnitBoard.NO_SHOT_OWED

## How far the pushed hp must fall to count as a hit. Not tuning: the line between a hit and float noise.
const HURT_HP_EPS := 0.0001

## The facts `on_unit_support` stores for the `on_unit_tick` that follows it, and the previous tick's. The
## previous hp is UNKNOWN (INF) until the first push, which is therefore never a hit -- a Healer that enters
## below its maximum (raised, or summoned onto a hurt board) does not flinch as it appears.
var _heal_count := 0
var _shot_owed: int = NO_SHOT_OWED
var _hp := 0.0
var _prev_heal_count := 0
var _prev_shot_owed: int = NO_SHOT_OWED
var _prev_hp := INF

## The facts `on_unit_motion` stores: the body's planar ground speed and the row's knobs. Until the first
## push, and for a kind with no row, nothing blends, the walk plays at 1.0, the two thresholds are the base's
## `WALK_SPEED_EPS` and `cast` plays at authored speed.
var _ground_speed := 0.0
## Smoke fix 2 (S15): the motion split (forward, to its right) and the yaw speed (positive = left) it was pushed.
var _forward_speed := 0.0
var _side_speed := 0.0
var _yaw_speed := 0.0
var _blend_seconds := 0.0
var _rate_min := 1.0
var _rate_max := 1.0
var _walk_enter_speed := WALK_SPEED_EPS
var _walk_exit_speed := WALK_SPEED_EPS
var _cast_seconds := 0.0

## Whether the body was walking on the last tick -- the hysteresis's memory.
var _walking := false

## The scale the model is mounted at, read once (the hound's `_mount_scale`): what turns the measured
## model-unit ground speed into metres per second for THIS scene.
var _mount_scale := 1.0

## The rate the last `shoot` was started at -- what a test reads to check the fit against the pushed delay.
var shoot_rate := 1.0


func _ready() -> void:
	super._ready()
	var mount := animation_player.get_node_or_null(animation_player.root_node) as Node3D
	if mount != null:
		_mount_scale = mount.transform.basis.get_scale().y


func on_unit_support(heal_count: int, shot_owed: int, hp: float) -> void:
	_heal_count = heal_count
	_shot_owed = shot_owed
	_hp = hp


## `knobs` is the kind's PRESENTATION ROW (or null for a kind with none): authored presentation data, read here
## for the knobs this rig plays by. Not a state handle -- no state object reaches a rig.
func on_unit_motion(forward_speed: float, side_speed: float, knobs: EffectPresentationRow,
		yaw_speed: float = 0.0) -> void:
	_ground_speed = Vector2(side_speed, forward_speed).length()
	_forward_speed = forward_speed
	_side_speed = side_speed
	_yaw_speed = yaw_speed
	if knobs == null:
		return
	_blend_seconds = maxf(0.0, knobs.knob(&"blend_seconds", 0.0))
	_rate_min = maxf(0.0, knobs.knob(&"locomotion_rate_min", 1.0))
	_rate_max = maxf(_rate_min, knobs.knob(&"locomotion_rate_max", 1.0))
	_walk_exit_speed = maxf(0.0, knobs.knob(&"walk_exit_speed", WALK_SPEED_EPS))
	_walk_enter_speed = maxf(_walk_exit_speed, knobs.knob(&"walk_enter_speed", WALK_SPEED_EPS))
	_cast_seconds = maxf(0.0, knobs.knob(&"cast_seconds", 0.0))


## `_speed` (the actor's `velocity` length) is the base controller's input and is NOT read here: the Healer's
## locomotion comes from `on_unit_motion`, the motion the body actually made (the hound's reason).
func on_unit_tick(alive: bool, _phase: int, _speed: float) -> void:
	var healed := _heal_count > _prev_heal_count
	var owed := _shot_owed != NO_SHOT_OWED \
			and (_prev_shot_owed == NO_SHOT_OWED or _shot_owed > _prev_shot_owed)
	var hurt := _prev_hp != INF and _hp < _prev_hp - HURT_HP_EPS
	_prev_heal_count = _heal_count
	_prev_shot_owed = _shot_owed
	_prev_hp = _hp
	if not alive:
		_play(&"death", 1.0, false)
		return
	if owed:
		shoot_rate = SHOOT_RELEASE_SECONDS / (float(maxi(MIN_SHOT_TICKS, _shot_owed + 1)) / float(TimingWindow.TICK_HZ))
		_play(&"shoot", shoot_rate, true)
		return
	if _shot_owed != NO_SHOT_OWED and _selected == &"shoot":
		return
	if healed:
		_play(&"cast", _cast_rate(), true)
		return
	if hurt and not _is_running(&"cast"):
		_play(&"hurt", 1.0, true)
		return
	if _is_running(&"cast") or _is_running(&"shoot") or _is_running(&"hurt"):
		return
	_play_locomotion()


## `walk` or `idle` by the ground speed, through the hysteresis band; `walk` at the rate that moves its feet
## with the floor. Smoke fix 2 (S15): a body WALKING more sideways than forward (the hound's `on_unit_motion`
## split) strafes instead, at the same rule over its own natural speed; a body STANDING while it turns plays its
## turn clip (`_play_turn`).
func _play_locomotion() -> void:
	_walking = _ground_speed > (_walk_exit_speed if _walking else _walk_enter_speed)
	if not _walking:
		if absf(_yaw_speed) > TURN_SPEED_EPS:
			_play_turn()
			return
		_play_looping(&"idle", 1.0)
		return
	var clip := &"walk"
	var natural_units := WALK_GROUND_SPEED_UNITS
	if absf(_side_speed) > absf(_forward_speed):
		clip = &"strafe_right" if _side_speed > 0.0 else &"strafe_left"
		natural_units = STRAFE_RIGHT_GROUND_SPEED_UNITS if _side_speed > 0.0 else STRAFE_LEFT_GROUND_SPEED_UNITS
	var natural := natural_units * _mount_scale
	_play_looping(clip, clampf(_ground_speed / natural, _rate_min, _rate_max) if natural > 0.0 else 1.0)


## Smoke fix 2 (S15b): TURN IN PLACE -- `turn_left` (a positive yaw speed) or `turn_right`, its playhead carried at
## `length x |yaw speed| / measured degrees`, so the feet step through the angle the body is turning. Started from
## frame 0 when selected, and again if a long turn outlasts the clip; never reached while `cast`, `shoot` or `hurt`
## plays (`on_unit_tick` returns first). A rig missing the clip stands in `idle`.
func _play_turn() -> void:
	var left := _yaw_speed > 0.0
	var clip := &"turn_left" if left else &"turn_right"
	if not animation_player.has_animation(clip):
		_play_looping(&"idle", 1.0)
		return
	var rate := animation_player.get_animation(clip).length * absf(_yaw_speed) \
			/ (TURN_LEFT_DEGREES if left else TURN_RIGHT_DEGREES)
	if not _is_running(clip):
		_selected = clip
		animation_player.play(clip, _blend_seconds, 1.0)
		animation_player.seek(0.0, true)
	animation_player.speed_scale = rate


## The rate that plays the whole `cast` clip in the row's `cast_seconds` (1.0 with no row).
func _cast_rate() -> float:
	if _cast_seconds <= 0.0 or not animation_player.has_animation(&"cast"):
		return 1.0
	return animation_player.get_animation(&"cast").length / _cast_seconds


## The one-shot `clip` this controller started is still playing.
func _is_running(clip: StringName) -> bool:
	return _selected == clip and animation_player.is_playing() \
			and animation_player.current_animation == String(clip)


## Select `clip` and play it from frame 0 at `rate`, blending out of the previous clip over the row's
## `blend_seconds`. A selection already current is left alone unless `restart` (a new heal, a newly owed shot,
## a new hit). The player's `speed_scale` goes back to 1.0, so `rate` is the whole playback speed.
func _play(clip: StringName, rate: float, restart: bool) -> void:
	if _selected == clip and not restart:
		return
	_selected = clip
	animation_player.speed_scale = 1.0
	animation_player.play(clip, _blend_seconds, rate)
	if restart:
		animation_player.seek(0.0, true)


## Select a LOOPING clip and keep its playback at `rate` (the hound's `_play_looping`): the clip is started, and
## blended into, only when the selection changes; the rate follows the body every tick through `speed_scale`,
## which `_play` puts back to 1.0.
func _play_looping(clip: StringName, rate: float) -> void:
	if _selected != clip:
		_selected = clip
		animation_player.play(clip, _blend_seconds, 1.0)
	animation_player.speed_scale = rate
