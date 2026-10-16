class_name HoundAnimationController
extends UnitAnimationController

## Rig presentation layer for the Hellhound (story 7-3, ACs 7, 9, 12, 16, 17, 18): the hound's
## READ-ONLY clip selector, `UnitAnimationController`'s per-kind counterpart. It holds that file's
## whole posture unchanged -- no `_physics_process` (F1), no `Input`, no state handle, no mutator, no
## decision -- and it is PUSHED from the same seat, `MatchRunner._aim_unit_actors`, once per tick.
##
## THREE PUSHES, ONE SEAT. The runner calls `on_unit_behavior(...)`, `on_unit_motion(...)` and then
## `on_unit_tick(...)` for every rig. The first two only STORE plain values (ints off the unit's
## board record; the velocity the body actually had; knobs off the kind's presentation row); the
## selection still happens inside `on_unit_tick`, the existing polled path (AC 7: the hit reaction is
## a polled state fact, and the observation family stays ten). The base controller ignores the first
## two pushes, so a zombie selects exactly as it did.
##
## SELECTION, in this order (a machine contract, like the base's):
##   1. NOT ALIVE                -> `death`, forwards, at authored speed.
##   2. behaviour GET_UP         -> `death` BACKWARDS, rate-fitted to the lockout (AC 16, `7-3/R8`).
##   3. behaviour REACT          -> `hit`, rate-fitted to the reaction (AC 7), re-triggered by every
##                                  new reaction.
##   4. attack phase != IDLE     -> `attack` (the bite, entry 0) or `leap` (entry 1), PHASE-ANCHORED
##                                  (below).
##   5. otherwise locomotion     -> BY WHAT THE BODY IS ACTUALLY DOING (feel pass), never by the
##                                  behaviour phase: standing -> `idle` (slowed while it STALKS);
##                                  moving forward relative to its facing -> `run` or `walk`; sideways
##                                  -> `walk_left` / `walk_right` (`run_left` / `run_right` when
##                                  faster than a walk can be played); backward -> `walk_backwards`.
##
## PHASE-ANCHORED ATTACK PLAYBACK (AC 17), the mechanism this story rules in place of `4-3d`'s single
## playback rate. Each attack clip is cut at two MEASURED marks into three segments, and each segment
## is played across the matching state phase:
##     [0, strike]        over WINDUP      [strike, release]  over ACTIVE      [release, end]  over RECOVERY
## On the tick a phase is first seen, the clip is sought to that segment's start and its rate is set
## to `segment length / time left in the phase`. The time left is the unit's OWN countdown
## (`UnitBoard.attack_ticks_at`), pushed by the runner -- so the strike mark lands on the first
## ACTIVE tick BY CONSTRUCTION, for any authored windup, and a retune at the live smoke needs no
## constant re-derived here. `4-3d`'s rate needed a copy of the authored windup in the controller
## (`ATTACK_ALIGNED_WINDUP_SECONDS`) and a test to catch the two drifting; this needs neither.
## A single rate also cannot serve the leap: its body travels during ACTIVE only, so the airborne
## part of the clip has to span exactly that window whatever the windup is.
##
## FEEL PASS, THREE THINGS THE LIVE SMOKE ASKED FOR:
##   CROSSFADE. Every change of clip blends over the row's authored `blend_seconds`. The blend mixes
##     the OUTGOING pose out; the incoming clip's playhead is where it always was, so the strike and
##     take-off marks still land on the first ACTIVE tick. A get-up does not blend: its actor is new
##     and has no pose worth blending from.
##   CLIP BY ACTUAL DIRECTION. The body's own velocity, in its own frame, picks the locomotion clip.
##     A hound spiralling outward while it circles walks backwards; one running in runs.
##   PLAYBACK AT GROUND SPEED. A locomotion clip plays at `ground speed / the clip's natural ground
##     speed`, inside the row's authored bounds, so the paws move with the floor.
##
## NOTHING IN STATE DEPENDS ON ANY OF THIS. A replay that never instantiates a rig is identical.

## The measured marks, in seconds of each clip's own time (`tools/measure_hellhound_rig.gd`, story
## 7-3 T1; the clips are sampled at 30 fps).
##
## THE BITE (`attack`, 1.2667 s). The jaw's forward reach peaks at frame 18 (2.348 model units, up
## from 1.519 at rest) with the head reared to its highest (frame 17); from there the head slams
## down and the jaw reaches its lowest point at frame 22. Frame 18 is where the chomp BEGINS at full
## reach -- the strike -- and frame 22 is where it has closed.
const BITE_STRIKE_SECONDS := 18.0 / 30.0
const BITE_RELEASE_SECONDS := 22.0 / 30.0

## THE LEAP (`leap`, the pack's `Attack01`, 1.4333 s). The pelvis sinks back into a crouch until
## frame 4 and from frame 5 is thrown forward; it stops travelling at frame 13 and the jaw's forward
## reach peaks at frame 14. Frames 4 to 14 are the airborne part, which is what the ACTIVE window --
## the only phase the leap's body travels in -- has to carry.
const LEAP_STRIKE_SECONDS := 4.0 / 30.0
const LEAP_RELEASE_SECONDS := 14.0 / 30.0

## THE NATURAL GROUND SPEED OF THE LOCOMOTION CLIPS, in MODEL units per second, MEASURED
## (`tools/measure_hellhound_rig.gd`, table 5): every take is in place, so the speed is the one at
## which a planted paw is carried under the body, averaged over the four paws. The four walks
## (forward, backward, left, right) measure the same 1.742; the run measures 10.61, from a gallop
## whose paws touch for one to three frames each, so that figure is the rougher of the two. Times the
## scale the model is mounted at (read off the scene in `_ready`, never copied here) these are
## 0.57 m/s and 3.50 m/s at the 0.33 mount.
const WALK_GROUND_SPEED_UNITS := 1.742
const RUN_GROUND_SPEED_UNITS := 10.61

## Which way the body is going relative to its facing: the four locomotion directions. How wide the
## forward and backward sectors are, and the margin a direction is HELD by before it changes (so a
## body moving along a sector edge does not flicker between two clips), are the row's
## `heading_forward_degrees` and `heading_hold_degrees`.
enum Heading { FORWARD, BACKWARD, LEFT, RIGHT }

## A phase whose countdown reads zero is given one tick, so no rate ever divides by zero.
const MIN_PHASE_TICKS := 1

## The facts `on_unit_behavior` stores for the `on_unit_tick` that follows it.
var _behavior_phase: int = UnitBoard.BehaviorPhase.ENGAGE
var _behavior_ticks := 0
var _circle_dir: int = UnitBoard.CIRCLE_NONE
var _attack_choice := 0
var _attack_ticks := 0
var _bark_interval_ticks := 0
var _bark_chance := 0.0

## The facts `on_unit_motion` stores: the body's own velocity (forward, to its right) and the row's
## knobs. Until the first push, and for a kind with no row, the rates are 1.0, nothing blends, the
## four headings are quarter-turns and nothing is held.
var _forward_speed := 0.0
var _side_speed := 0.0
var _blend_seconds := 0.0
var _rate_min := 1.0
var _rate_max := 1.0
var _stalk_rate := 1.0
var _forward_sector_degrees := 45.0
var _sector_hold_degrees := 0.0

## The scale the model is mounted at, read once: what turns the measured model-unit speeds into
## metres per second for THIS scene.
var _mount_scale := 1.0

## The locomotion direction last selected, for the sector hold.
var _heading: int = Heading.FORWARD

## The previous tick's behaviour phase and countdown: the EDGE into a reaction or a get-up, and a
## reaction re-armed while one is already playing (the countdown jumps back up).
var _prev_behavior_phase: int = UnitBoard.BehaviorPhase.ENGAGE
var _prev_behavior_ticks := 0

## The previous tick's ATTACK phase, for the segment edges. The base's `_prev_phase` serves its own
## windup re-trigger and is not reused: this one must also see ACTIVE and RECOVERY begin.
var _prev_attack_phase: int = UnitBoard.AttackPhase.IDLE

## Ticks until this hound may bark again, how many back-offs it has begun, and whether a bark is
## waiting to be taken (AC 18).
var _bark_ticks := 0
var _back_offs := 0
var _bark_pending := false

## Feel pass 2: THE HOUND'S OTHER VOICES. The voices that came due and have not been taken yet; the
## growl's own cadence (ticks until it may growl again, how many times it has begun to watch or
## circle, and the row's two knobs for it); and whether the hound was alive on the last push.
var _voices: Array[StringName] = []
var _growl_ticks := 0
var _watches := 0
var _growl_interval_ticks := 0
var _growl_chance := 0.0
var _was_alive := true


func _ready() -> void:
	super._ready()
	var mount := animation_player.get_node_or_null(animation_player.root_node) as Node3D
	if mount != null:
		_mount_scale = mount.transform.basis.get_scale().y


func on_unit_behavior(behavior_phase: int, behavior_ticks: int, circle_dir: int, attack_choice: int,
		attack_ticks: int, bark_interval_ticks: int, bark_chance: float = 0.0) -> void:
	_behavior_phase = behavior_phase
	_behavior_ticks = behavior_ticks
	_circle_dir = circle_dir
	_attack_choice = attack_choice
	_attack_ticks = attack_ticks
	_bark_interval_ticks = bark_interval_ticks
	_bark_chance = bark_chance


## `knobs` is the kind's PRESENTATION ROW (or null for a kind with none): authored presentation data,
## read here for the six knobs this rig plays by. Not a state handle -- no state object reaches a rig.
## `_yaw_speed` (story 7-5b smoke fix 2) is the Healer's; a hound turns by its heading sectors and ignores it.
func on_unit_motion(forward_speed: float, side_speed: float, knobs: EffectPresentationRow,
		_yaw_speed: float = 0.0) -> void:
	_forward_speed = forward_speed
	_side_speed = side_speed
	if knobs == null:
		return
	_blend_seconds = maxf(0.0, knobs.knob(&"blend_seconds", 0.0))
	_rate_min = maxf(0.0, knobs.knob(&"locomotion_rate_min", 1.0))
	_rate_max = maxf(_rate_min, knobs.knob(&"locomotion_rate_max", 1.0))
	_stalk_rate = maxf(0.0, knobs.knob(&"stalk_rate", 1.0))
	_forward_sector_degrees = clampf(knobs.knob(&"heading_forward_degrees", 45.0), 0.0, 90.0)
	_sector_hold_degrees = maxf(0.0, knobs.knob(&"heading_hold_degrees", 0.0))
	_growl_interval_ticks = int(round(maxf(0.0, knobs.knob(&"growl_interval_seconds", 0.0)) * TimingWindow.TICK_HZ))
	_growl_chance = knobs.knob(&"growl_chance", 0.0)


## `_speed` (the actor's `velocity` length) is the base controller's input and is NOT read here: the
## hound's locomotion comes from `on_unit_motion`, which is the motion the body actually made.
func on_unit_tick(alive: bool, phase: int, _speed: float) -> void:
	var behavior_edge := _behavior_phase != _prev_behavior_phase \
			or _behavior_ticks > _prev_behavior_ticks
	var attack_edge := phase != _prev_attack_phase
	# Feel pass 2: it barks as it starts to back off OR to retreat; it may growl as it starts to watch
	# (a stalk) or to circle.
	var backed_off := _is_backing(_behavior_phase) and not _is_backing(_prev_behavior_phase)
	var watching := _is_watching(_behavior_phase) and not _is_watching(_prev_behavior_phase)
	_prev_behavior_phase = _behavior_phase
	_prev_behavior_ticks = _behavior_ticks
	_prev_attack_phase = phase
	if not alive:
		if _was_alive:
			_voices.append(&"death")
		_was_alive = false
		_play(&"death", 1.0, 0.0, false, _blend_seconds)
		return
	_was_alive = true
	_advance_bark(backed_off)
	_advance_growl(watching)
	if _behavior_phase == UnitBoard.BehaviorPhase.GET_UP:
		# AC 16: Death in reverse, from its last frame, fitted to what is left of the lockout.
		var length := _length(&"death")
		_play(&"get_up", -length / _seconds(_behavior_ticks), length, behavior_edge, 0.0)
		return
	if _behavior_phase == UnitBoard.BehaviorPhase.REACT:
		# The hurt yelp, once per reaction (the row has no file for it yet, so nothing is heard).
		if behavior_edge:
			_voices.append(&"yelp")
		_play(&"hit", _length(&"hit") / _seconds(_behavior_ticks), 0.0, behavior_edge, _blend_seconds)
		return
	# The bite's snap as its ACTIVE window opens; the leap's snarl at take-off, which is the same edge.
	if attack_edge and phase == UnitBoard.AttackPhase.ACTIVE:
		_voices.append(&"leap" if _attack_choice == 1 else &"bite")
	if phase != UnitBoard.AttackPhase.IDLE:
		_play_attack_segment(phase, attack_edge)
		return
	_play_locomotion()


## AC 18: has a bark come due since the last call? Read (and cleared) by the runner right after the
## push, which plays the sound at this hound. The controller decides WHEN from what it is pushed; it
## owns no sound.
func take_bark() -> bool:
	var due := _bark_pending
	_bark_pending = false
	return due


## Feel pass 2: EVERY VOICE that has come due since the last call, in the order it came due, the bark
## among them (`EffectPresentationSet.ROW_VOICES`' names). Read and cleared by the runner right after
## the push, which plays each at this hound. The controller decides WHEN from what it is pushed; it
## owns no sound, picks no variant and knows no volume.
func take_voices() -> Array[StringName]:
	var due := _voices.duplicate()
	_voices.clear()
	if take_bark():
		due.append(&"bark")
	return due


func _is_backing(behavior: int) -> bool:
	return behavior == UnitBoard.BehaviorPhase.BACK_OFF or behavior == UnitBoard.BehaviorPhase.RETREAT


func _is_watching(behavior: int) -> bool:
	return behavior == UnitBoard.BehaviorPhase.STALK or behavior == UnitBoard.BehaviorPhase.CIRCLE \
			or behavior == UnitBoard.BehaviorPhase.CIRCLE_TURN or behavior == UnitBoard.BehaviorPhase.ORBIT \
			or behavior == UnitBoard.BehaviorPhase.ORBIT_TURN


## Feel pass 2: A HOUND GROWLS NOW AND THEN, as it starts to watch its target (a stalk) or to circle
## it: only when the row's `growl_interval_seconds` have passed since its last growl, and then only
## with the row's `growl_chance`. The bark's own shape, on its own counter: a fixed sequence, not a
## draw, so a replay growls where the match did and two siblings do not growl together.
func _advance_growl(watching: bool) -> void:
	if _growl_ticks > 0:
		_growl_ticks -= 1
	if not watching or _growl_interval_ticks <= 0:
		return
	_watches += 1
	if _growl_ticks > 0:
		return
	if UnitTemperament.unit_value(get_parent().get_index(), _watches, 1) >= _growl_chance:
		return
	_voices.append(&"growl")
	_growl_ticks = _growl_interval_ticks


## The clip segment for `phase`, started on the tick the phase is first seen.
func _play_attack_segment(phase: int, entered: bool) -> void:
	var clip: StringName = &"leap" if _attack_choice == 1 else &"attack"
	var strike := LEAP_STRIKE_SECONDS if _attack_choice == 1 else BITE_STRIKE_SECONDS
	var release := LEAP_RELEASE_SECONDS if _attack_choice == 1 else BITE_RELEASE_SECONDS
	var from := 0.0
	var to := strike
	if phase == UnitBoard.AttackPhase.ACTIVE:
		from = strike
		to = release
	elif phase == UnitBoard.AttackPhase.RECOVERY:
		from = release
		to = _length(clip)
	_play(clip, (to - from) / _seconds(_attack_ticks), from, entered, _blend_seconds)


## Rule 5: what the body is doing on its feet, from the velocity it actually had.
##
## STANDING is `idle`, and `idle` at the row's slower `stalk_rate` while state says the hound STALKS
## (the pack's other standing take, `Idle01`, was measured and is a hound with its nose on the
## ground, not one watching its prey: `tools/measure_hellhound_rig.gd`, table 6).
##
## MOVING picks the clip by HEADING and plays it at the body's ground speed over the clip's natural
## one. Forward is `walk` up to the fastest the walk can be played, `run` beyond it.
func _play_locomotion() -> void:
	var speed := Vector2(_side_speed, _forward_speed).length()
	if speed <= WALK_SPEED_EPS:
		if _behavior_phase == UnitBoard.BehaviorPhase.STALK:
			_play_looping(&"stalk", _stalk_rate)
		else:
			_play_looping(&"idle", 1.0)
		return
	_heading = _heading_of(rad_to_deg(atan2(_side_speed, _forward_speed)))
	var walk_speed := WALK_GROUND_SPEED_UNITS * _mount_scale
	var run_speed := RUN_GROUND_SPEED_UNITS * _mount_scale
	# Faster than the walk can be played, the body RUNS -- forward and to either side. The pack has
	# no backward run; the hound only ever backs away at a walk.
	var running := speed > walk_speed * _rate_max
	match _heading:
		Heading.BACKWARD:
			_play_looping(&"walk_backwards", _rate(speed, walk_speed))
		Heading.LEFT:
			_play_looping(&"run_left" if running else &"walk_left", _rate(speed, run_speed if running else walk_speed))
		Heading.RIGHT:
			_play_looping(&"run_right" if running else &"walk_right", _rate(speed, run_speed if running else walk_speed))
		_:
			_play_looping(&"run" if running else &"walk", _rate(speed, run_speed if running else walk_speed))


## The heading a body moving at `degrees` off its own forward (positive to its right) is given. The
## heading it already has is kept until the direction is the row's hold margin past that heading's
## edge.
func _heading_of(degrees: float) -> int:
	var off_forward := absf(degrees)
	var side: int = Heading.RIGHT if degrees > 0.0 else Heading.LEFT
	var forward_edge := _forward_sector_degrees
	var backward_edge := 180.0 - _forward_sector_degrees
	match _heading:
		Heading.FORWARD:
			forward_edge += _sector_hold_degrees
		Heading.BACKWARD:
			backward_edge -= _sector_hold_degrees
		_:
			forward_edge -= _sector_hold_degrees
			backward_edge += _sector_hold_degrees
	if off_forward <= forward_edge:
		return Heading.FORWARD
	if off_forward >= backward_edge:
		return Heading.BACKWARD
	return side


## The playback rate that moves a clip's paws at `speed`, inside the row's authored bounds.
func _rate(speed: float, natural_speed: float) -> float:
	if natural_speed <= 0.0:
		return 1.0
	return clampf(speed / natural_speed, _rate_min, _rate_max)


## AC 18, as retuned at the live smoke ("terribly annoying"): A HOUND BARKS RARELY. Only as it starts
## to back off, only when the kind's authored interval has passed since its last bark, and then only
## with the kind's authored chance. The interval counts every tick the hound is alive.
##
## THE CHANCE IS NOT A DRAW. It is a fixed sequence over this hound's own back-off count
## (`UnitTemperament.unit_value`, a golden-ratio step), started from the actor's place among its
## siblings: the long-run share of barking back-offs is the authored chance, the two hounds of a cast
## do not bark on the same ones, and a replay barks where the match did. A kind authoring no
## interval, or a chance of zero, never barks.
func _advance_bark(backed_off: bool) -> void:
	if _bark_ticks > 0:
		_bark_ticks -= 1
	if not backed_off or _bark_interval_ticks <= 0:
		return
	_back_offs += 1
	if _bark_ticks > 0:
		return
	if UnitTemperament.unit_value(get_parent().get_index(), _back_offs, 0) >= _bark_chance:
		return
	_bark_pending = true
	_bark_ticks = _bark_interval_ticks


## Select `selection` and play its clip at `rate` from `from` seconds, blending out of the previous
## clip over `blend` seconds. A selection already current is left alone unless `restart` (a new
## segment, a new reaction, a new get-up).
##
## `get_up` is a SELECTION, not a clip: it plays `death`. Keeping the two apart is what lets a hound
## killed mid-get-up switch from the reversed clip to the forward one.
func _play(selection: StringName, rate: float, from: float, restart: bool, blend: float) -> void:
	if _selected == selection and not restart:
		return
	_selected = selection
	var clip: StringName = &"death" if selection == &"get_up" else selection
	animation_player.speed_scale = 1.0
	animation_player.play(clip, blend, rate, rate < 0.0)
	animation_player.seek(from, true)


## Select a LOOPING selection and keep its playback at `rate`. The clip is started (and blended into)
## only when the selection changes; the rate follows the body every tick, through the player's
## `speed_scale`, which every other selection puts back to 1.0.
##
## `stalk` is a SELECTION, not a clip: it plays `idle`.
func _play_looping(selection: StringName, rate: float) -> void:
	if _selected != selection:
		_selected = selection
		animation_player.play(&"idle" if selection == &"stalk" else selection, _blend_seconds, 1.0)
	animation_player.speed_scale = rate


func _length(clip: StringName) -> float:
	return animation_player.get_animation(clip).length


func _seconds(ticks: int) -> float:
	return float(maxi(MIN_PHASE_TICKS, ticks)) / float(TimingWindow.TICK_HZ)
