extends SceneTree

## Story 7-1 (AC 23/AC 24): EACH NEW CAST CLIP'S MEASURED RELEASE FRAME LANDS ON THE TICK THE SHOT LAUNCHES, AT
## ANY AUTHORED `cast_seconds`.
##
## THE LAUNCH TICK IS THE CAST'S END. Fireball and Rocksling launch at the strike (`6-5c`: the cast window's
## falling edge is the strike tick), and the runner pushes `elapsed = elapsed_ticks / TICK_HZ`, which on that tick
## is exactly the window's own length. So the claim is: `spell_cast_pose(outcome, cast, cast)` sits ON the release
## frame, for every `cast` -- pinned here at five durations either side of the authored 0.8 s, so a retune of
## `cast_seconds` (or of a measured constant) that breaks it fails without a code edit to this file.
##
## Also pinned: Rocksling is the LIFT then the THROW (option A, AC 24) and the throw's playhead never runs
## backwards; every pose stays inside its clip's real length (read from the assembled library); Honed Bolt is
## NOT a spell pose and a real hero plays `cast` exactly as before (AC 23's third clause), while a Fireball cast
## plays `cast_fireball` on the real rig and sits on the release frame at the end of the window.
##
## 7-1 POLISH ROUND (2026-10-04): THE GESTURE CLIPS. Pinned: which clip each instant effect plays (Vampiric Aura
## and Frostbite -> `cast_buff`, Counterspell -> `cast_counterspell`, the cast spells none); where each starts and
## when its measured beat lands -- Counterspell's peak no later than 0.15 s after the resolution tick, by cutting
## the lead-in, inside the clip; the buff from its start, beat at the measured peak. On the real rig: a hero
## standing still plays the gesture from its start; a moving hero plays none; and movement cuts one in progress.
##
## Run: godot --headless --path . --script res://test/integration/test_spell_cast_clips.gd

const CASTS: Array[float] = [0.3, 0.8, 1.25, 2.0, 4.0]
const FIREBALL := CardEffectResolver.OUTCOME_FIREBALL
const ROCKSLING := CardEffectResolver.OUTCOME_ROCKSLING

var _failures: Array[String] = []
var _frames := 0
var _hero: HeroActor


func _initialize() -> void:
	var library := load("res://assets/characters/paladin/paladin_anims.res") as AnimationLibrary
	for cast: float in CASTS:
		var fire := AnimationController.spell_cast_pose(FIREBALL, cast, cast)
		_check(fire.size() == 2 and fire[0] == &"cast_fireball", "fireball pose names cast_fireball (cast %.2f)" % cast)
		if fire.size() == 2:
			_check(is_equal_approx(float(fire[1]), AnimationController.FIREBALL_RELEASE_SECONDS),
				"fireball at the end of a %.2f s cast sits on the release frame (got %.4f)" % [cast, fire[1]])
		var rock := AnimationController.spell_cast_pose(ROCKSLING, cast, cast)
		_check(rock.size() == 2 and rock[0] == &"cast_rocksling_throw",
			"rocksling ends on the THROW (cast %.2f)" % cast)
		if rock.size() == 2:
			_check(is_equal_approx(float(rock[1]), AnimationController.ROCKSLING_THROW_RELEASE_SECONDS),
				"rocksling at the end of a %.2f s cast sits on the throw's release (got %.4f)" % [cast, rock[1]])
		var start := AnimationController.spell_cast_pose(ROCKSLING, 0.0, cast)
		_check(start.size() == 2 and start[0] == &"cast_rocksling_lift", "rocksling starts on the LIFT (cast %.2f)" % cast)
		_check_monotonic(FIREBALL, cast)
		_check_monotonic(ROCKSLING, cast)
	_check(AnimationController.spell_cast_pose(CardEffectResolver.OUTCOME_HONED_BOLT, 0.4, 0.8).is_empty(),
		"Honed Bolt is not a spell pose -- it keeps `cast`")
	_check(library != null, "the paladin library loads")
	if library != null:
		for clip: StringName in [&"cast_fireball", &"cast_rocksling_lift", &"cast_rocksling_throw"]:
			_check(library.has_animation(clip), "library carries %s" % clip)
		_check(AnimationController.FIREBALL_RELEASE_SECONDS < library.get_animation(&"cast_fireball").length,
			"fireball release inside its clip")
		_check(AnimationController.ROCKSLING_LIFT_PEAK_SECONDS < library.get_animation(&"cast_rocksling_lift").length,
			"lift peak inside its clip")
		_check(AnimationController.ROCKSLING_THROW_RELEASE_SECONDS
				< library.get_animation(&"cast_rocksling_throw").length, "throw release inside its clip")
		_check_gesture_timing(library)
	_check_gesture_selection()
	var scene := load("res://src/actors/hero/hero.tscn") as PackedScene
	_hero = scene.instantiate() as HeroActor
	root.add_child(_hero)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames != 2:
		return false
	var anim := _hero.animation_controller
	var player := anim.animation_player
	anim.on_cast_started(0.8, CardEffectResolver.OUTCOME_HONED_BOLT)
	_check(player.current_animation == &"cast", "a Honed Bolt cast plays `cast` (got %s)" % player.current_animation)
	_check(is_equal_approx(player.current_animation_position, AnimationController.cast_cut_start(0.8)),
		"and seeks today's sub-range start")
	anim.on_cast_ended()
	anim.on_cast_started(0.8, FIREBALL)
	_check(player.current_animation == &"cast_fireball", "a Fireball cast plays cast_fireball (got %s)"
			% player.current_animation)
	anim.on_cast_progress(0.8)
	_check(absf(player.current_animation_position - AnimationController.FIREBALL_RELEASE_SECONDS) < 0.001,
		"the Fireball cast's last tick shows the release frame (got %.4f)" % player.current_animation_position)
	anim.on_cast_ended(true)
	_check(player.current_animation == &"cast_fireball" and player.get_playing_speed() > 0.0,
		"a struck Fireball cast plays its follow-through at native rate")
	anim.on_cast_started(0.8, ROCKSLING)
	_check(player.current_animation == &"cast_rocksling_lift", "a Rocksling cast starts on the lift")
	anim.on_cast_progress(0.8)
	_check(player.current_animation == &"cast_rocksling_throw", "and ends on the throw")
	anim.on_cast_ended(false)
	_check_gestures_on_rig(anim, player)
	_hero.queue_free()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
	return false


## Which clip each effect plays (polish 4/5).
func _check_gesture_selection() -> void:
	var want := {
		CardEffectResolver.OUTCOME_VAMPIRIC_AURA: &"cast_buff",
		CardEffectResolver.OUTCOME_FROSTBITE: &"cast_buff",
		CardEffectResolver.OUTCOME_COUNTERSPELL: &"cast_counterspell",
		CardEffectResolver.OUTCOME_HONED_BOLT: &"",
		CardEffectResolver.OUTCOME_FIREBALL: &"",
		CardEffectResolver.OUTCOME_ROCKSLING: &"",
		CardEffectResolver.OUTCOME_BLOODHOUND_STEP: &"",
	}
	for outcome: StringName in want:
		var got := AnimationController.gesture_clip(outcome)
		_check(got == want[outcome], "%s plays gesture '%s' (got '%s')" % [outcome, want[outcome], got])


## Where each gesture starts and when its measured beat lands (polish 2/3/5).
func _check_gesture_timing(library: AnimationLibrary) -> void:
	for clip: StringName in [&"cast_buff", &"cast_counterspell"]:
		_check(library.has_animation(clip), "library carries %s" % clip)
		if library.has_animation(clip):
			_check(library.get_animation(clip).loop_mode == Animation.LOOP_NONE, "%s is a one-shot" % clip)
	if not (library.has_animation(&"cast_buff") and library.has_animation(&"cast_counterspell")):
		return
	var counter_start := AnimationController.gesture_start(&"cast_counterspell")
	var counter_beat := AnimationController.gesture_beat_delay(&"cast_counterspell")
	_check(counter_start > 0.0 and counter_start < AnimationController.COUNTERSPELL_PEAK_SECONDS,
		"the counterspell lead-in is CUT: it starts inside the clip, before the peak (start %.4f)" % counter_start)
	_check(counter_beat > 0.0 and counter_beat <= 0.15 + 0.0001,
		"the counterspell peak lands no later than 0.15 s after the resolution tick (%.4f)" % counter_beat)
	_check(is_equal_approx(counter_start + counter_beat, AnimationController.COUNTERSPELL_PEAK_SECONDS),
		"...and that beat IS the measured peak (%.4f + %.4f)" % [counter_start, counter_beat])
	_check(AnimationController.COUNTERSPELL_PEAK_SECONDS < library.get_animation(&"cast_counterspell").length,
		"counterspell peak inside its clip")
	_check(AnimationController.gesture_start(&"cast_buff") == 0.0, "the buff gesture plays from its start")
	_check(is_equal_approx(AnimationController.gesture_beat_delay(&"cast_buff"),
			AnimationController.BUFF_PEAK_SECONDS), "the buff's beat lands at its measured peak")
	_check(AnimationController.BUFF_PEAK_SECONDS < library.get_animation(&"cast_buff").length,
		"buff peak inside its clip")
	_check(AnimationController.gesture_start(&"cast") < 0.0, "`cast` is not a gesture clip")


## On the real rig: plays only standing still, from its start; movement cuts it (polish 4: never slide).
func _check_gestures_on_rig(anim: AnimationController, player: AnimationPlayer) -> void:
	var still := Vector3.ZERO
	var facing := Vector2(0.0, 1.0)
	anim.on_locomotion(still, facing, 1.82, 5.0)
	anim.on_locomotion(still, facing, 1.82, 5.0)
	_check(anim.play_gesture(&"cast_counterspell"), "a hero standing still plays the counterspell gesture")
	_check(player.current_animation == &"cast_counterspell", "...as cast_counterspell (got %s)"
			% player.current_animation)
	_check(absf(player.current_animation_position - AnimationController.gesture_start(&"cast_counterspell")) < 0.001,
		"...from its cut start (got %.4f)" % player.current_animation_position)
	anim.on_locomotion(still, facing, 1.82, 5.0)
	_check(player.current_animation == &"cast_counterspell", "a still hero keeps the gesture")
	anim.on_locomotion(Vector3(2.0, 0.0, 0.0), facing, 1.82, 5.0)
	_check(player.current_animation != &"cast_counterspell", "movement cuts the gesture (never slides)")
	_check(not anim.play_gesture(&"cast_buff"), "a moving hero plays no buff gesture")
	_check(player.current_animation != &"cast_buff", "...and the clip does not start")
	anim.on_locomotion(still, facing, 1.82, 5.0)
	_check(anim.play_gesture(&"cast_buff"), "a hero standing still again plays the buff gesture")
	_check(player.current_animation == &"cast_buff" and player.current_animation_position < 0.001,
		"...as cast_buff from its start")


func _check_monotonic(outcome: StringName, cast: float) -> void:
	var last_clip: StringName = &""
	var last_pos := -1.0
	for i in 61:
		var pose := AnimationController.spell_cast_pose(outcome, cast * float(i) / 60.0, cast)
		var clip: StringName = pose[0]
		var pos := float(pose[1])
		if clip == last_clip and pos < last_pos - 0.00001:
			_failures.append("%s playhead runs backwards at step %d of a %.2f s cast" % [outcome, i, cast])
			return
		last_clip = clip
		last_pos = pos


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
