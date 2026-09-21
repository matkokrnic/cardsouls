extends SceneTree

## Story 5-3 (AC 21): THE RUNTIME DISPATCH PIN `3-0b/R34` names verbatim -- the suite asserts
## authored data AT REST and never runtime COMPOSITION. This story's CHARGING dispatch (AC 8:
## colour -> clip, AC 10: colour -> telegraph shape/sting) is exactly that shape: a runtime
## SELECTION decided by `charge_color` at the transition instant, invisible to every headless
## state test (none of them load a .tscn or touch an AnimationPlayer/AudioStreamPlayer).
##
## DIRECT FIELD POKES, not a card cast: driving a real chargeup through MatchState would
## duplicate 5-2's own coverage of the cast-to-CHARGING path for no new signal. What THIS file
## needs is colour -> clip name / colour -> shape tint + sting node, which is reached directly
## by setting `PlayerState.charge_color` and calling `HeroState.set_action_state(CHARGING)` --
## the queued signal `set_action_state` pushes is drained by `MatchState.advance()`, called
## every tick from `match_runner.gd`'s one `_physics_process` (F1), so a frame gap after each
## poke is enough for the real dispatch (match_runner's wrapping lambdas -> the two
## controllers' `on_action_state_changed`) to run for real.
##
## NON-VACUOUS BY CONSTRUCTION: each colour's clip and orb are measured BEFORE the poke (the clip
## must NOT already be that colour's, and the orb must be dark, with all three stings silent --
## which catches a dispatch that never actually fired, the case AC 21 explicitly bars from passing)
## and AFTER (must read as the RIGHT colour's result). All three colours must resolve to three
## DISTINCT clip names and three DISTINCT stings -- two colours collapsing to the same clip or
## sting is a FAIL, not a pass.
##
## WHAT THE STINGS RECORD IS WHAT THE PRODUCTION CODE RESOLVED, NEVER WHAT THIS FILE EXPECTED (the
## 5-3 review's finding). All three sting nodes are read at every check, so the recorded value is an
## OBSERVATION -- which also lets the silence of the other two be asserted, catching a dispatch that
## fires the right sting AND the wrong ones (every colour audible destroys the audio tell the RGB
## read exchange is built on, and a check that only asked "is MY sting playing" could not see it).
## The stings are stopped before each case so that observation is about THIS dispatch: headless
## physics frames advance at no wall-clock cost, so an earlier case's tone is still playing.
##
## THE ORB IS ASSERTED DARK AGAIN AFTER LEAVING CHARGING, per colour (the same finding). Exempting
## `ChargeMarker` from `TelegraphController.on_action_state_changed`'s shape-clearing loop otherwise
## passes this file unnoticed -- and that is a hero carrying a lit coloured orb for the rest of the
## match, a real defect shape, not a cosmetic one.
##
## CROSS-SLOT, on `test_cast_success_cue_live.gd`'s discipline: P1's dispatch must leave P2's orb
## dark and P2's stings silent. The per-slot lambdas in `match_runner.gd` are what make that true
## and a cross-wired seam is the exact class of bug they exist to prevent.
##
## Run: godot --headless --path . --script res://test/integration/test_charge_telegraph_dispatch_live.gd

## STORY 6-1 (AC 1), AND A CORRECTION TO THAT STORY'S OWN MEASURED FINDING 4. That finding listed
## this file as OUTSIDE the hold-through blast radius because it enters `CHARGING` by a direct
## `set_action_state` with no intent at all — true of the ENTRY, and not the whole question. The
## poke has to SURVIVE `CHECK_DELAY` frames to be measurable, and every one of those frames is a
## real `advance()` driven by real controllers; with no pad connected those emit a neutral intent,
## which since 6-1 reads as "the cast confirm was released" and feints the poked chargeup back to
## IDLE before this file ever looks at it. Measured, not predicted: without the stand-in below all
## three colours read clip `idle`, a dark marker and silence.
##
## THE STAND-IN IS AT THE INPUT SEAM, which is where the new fact actually lives — the alternative
## (re-poking `CHARGING` every frame) would fight the state layer with a second write per frame and
## make the dispatch under test fire repeatedly instead of once. P2 keeps its real controller: this
## file's cross-slot claim is that P1's dispatch is P1's alone.
class BareController extends Controller:
	func sample() -> InputIntent:
		return InputIntent.new()


const CHECK_DELAY := 2  ## frames between a poke and reading its result (test_totem_tint_live precedent)

var _frames := 0
## Every charge sting node on a hero's TelegraphController. Read in full at each check so the
## recorded resolution is an observation and the other two colours' silence is assertable.
const STING_NODES := ["StingChargeRed", "StingChargeBlue", "StingChargeGreen"]
const MARKER_PATH := "Shapes/ChargeMarker"

var _runner: Node
var _state: MatchState
var _hero: HeroActor
var _p2_hero: HeroActor
var _player: PlayerState

## (colour, expected clip, expected sting node name, expected tint)
var _cases := [
	[Enums.CardColor.RED, &"swipe", "StingChargeRed", Color(0.95, 0.1, 0.1, 1)],
	[Enums.CardColor.BLUE, &"thrust", "StingChargeBlue", Color(0.15, 0.35, 0.95, 1)],
	[Enums.CardColor.GREEN, &"jump_attack", "StingChargeGreen", Color(0.15, 0.85, 0.25, 1)],
]
var _case_index := 0
var _phase := "idle"  ## idle -> poked -> checked -> reset -> idle (next case)
var _phase_frame := 0
var _failures: Array[String] = []
var _seen_clips: Array[StringName] = []
var _seen_stings: Array[String] = []


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		_hero = _runner._p1_hero if _runner != null else null
		_p2_hero = _runner._p2_hero if _runner != null else null
		_player = _state.p1 if _state != null else null
		if _runner == null or _state == null or _hero == null or _p2_hero == null or _player == null:
			print("missing: runner=%s state=%s hero=%s p2_hero=%s player=%s"
					% [_runner, _state, _hero, _p2_hero, _player])
			print("RESULT: FAIL")
			quit(1)
			return false
		# Story 6-1: P1's controller is replaced by the stand-in declared at the top of this file,
		# so the poked chargeup is HELD for the frames this test measures it over.
		_runner._p1_controller = BareController.new()
		# Baseline: nothing has charged yet, so no charge clip/shape should be live.
		var idle_clip: StringName = _hero.animation_controller.animation_player.current_animation
		if idle_clip == &"swipe" or idle_clip == &"thrust" or idle_clip == &"jump_attack":
			_failures.append("baseline already reads a charge clip (%s) before any poke -- test setup is not clean" % idle_clip)
		return false

	if _phase == "idle":
		if _case_index >= _cases.size():
			_finish()
			return false
		var case: Array = _cases[_case_index]
		# Clean slate for the OBSERVED sting read: headless physics frames cost no wall-clock time,
		# so the previous case's 0.18 s tone is still playing unless it is stopped here.
		for sting_name in STING_NODES:
			var previous: AudioStreamPlayer = _hero.telegraph_controller.get_node_or_null(sting_name)
			if previous != null:
				previous.stop()
		# THE PER-CASE PRE-READ this file's header claims (the 5-3 review's finding: it claimed one
		# and shipped a single frame-1 clip-name baseline). Nothing may already read as this colour's
		# result, or "it read as RED afterwards" would not be evidence that anything dispatched.
		var before_clip: StringName = _hero.animation_controller.animation_player.current_animation
		if before_clip == case[1]:
			_failures.append("colour %s: clip already reads '%s' BEFORE the poke -- a pass would prove nothing"
					% [case[0], before_clip])
		var before_marker: MeshInstance3D = _hero.telegraph_controller.get_node(MARKER_PATH)
		if before_marker.visible:
			_failures.append("colour %s: ChargeMarker is already lit BEFORE the poke" % case[0])
		for playing_name in _playing_stings(_hero):
			_failures.append("colour %s: sting '%s' is already playing BEFORE the poke"
					% [case[0], playing_name])
		_player.charge_color = case[0]
		# `MatchState.advance()`'s CHARGING arm resolves the landing the instant
		# `charge_window.is_running` is false (5-2's own contract) -- a fresh/unarmed window
		# would resolve away on the very next tick, undoing the transition before this test
		# ever measures it. Armed generously past CHECK_DELAY so it is still running when read.
		_player.charge_window.start(1000)
		# Story 6-1c: the LANDING now fires when `landing_window` stops (it runs from the cast through
		# the launch), not when `charge_window` does -- so the poke arms it too, exactly as the cast seat
		# does, or the unarmed landing window resolves the poked chargeup away on the next tick.
		_player.landing_window.start(1000)
		_player.hero.set_action_state(HeroState.ActionState.CHARGING)
		_phase = "poked"
		_phase_frame = _frames
		return false

	if _phase == "poked" and _frames - _phase_frame >= CHECK_DELAY:
		var case: Array = _cases[_case_index]
		var want_clip: StringName = case[1]
		var want_sting_name: String = case[2]
		var want_tint: Color = case[3]

		var got_clip: StringName = _hero.animation_controller.animation_player.current_animation
		_seen_clips.append(got_clip)
		if got_clip != want_clip:
			_failures.append("colour %s: expected clip '%s', got '%s'" % [case[0], want_clip, got_clip])

		var marker: MeshInstance3D = _hero.telegraph_controller.get_node(MARKER_PATH)
		var got_visible: bool = marker.visible
		var got_tint: Variant = null
		if marker.material_override is StandardMaterial3D:
			got_tint = (marker.material_override as StandardMaterial3D).albedo_color
		if not got_visible:
			_failures.append("colour %s: ChargeMarker not visible after CHARGING dispatch" % case[0])
		elif got_tint == null or not (got_tint as Color).is_equal_approx(want_tint):
			_failures.append("colour %s: expected tint %s, got %s" % [case[0], want_tint, got_tint])

		# OBSERVED, not expected: whatever the production dispatch actually started. Recording the
		# expected name here instead is what made the distinctness check below unable to fail on its
		# own (the 5-3 review's finding).
		var playing: Array[String] = _playing_stings(_hero)
		if playing.is_empty():
			_failures.append("colour %s: no charge sting is playing after CHARGING dispatch" % case[0])
		else:
			_seen_stings.append(playing[0])
			if playing[0] != want_sting_name:
				_failures.append("colour %s: expected sting '%s', got '%s'"
						% [case[0], want_sting_name, playing[0]])
		for extra in playing:
			if extra != want_sting_name:
				_failures.append(("colour %s: sting '%s' is ALSO playing -- every colour audible is "
						+ "no colour audible") % [case[0], extra])

		# CROSS-SLOT: P1's dispatch is P1's alone.
		var p2_marker: MeshInstance3D = _p2_hero.telegraph_controller.get_node(MARKER_PATH)
		if p2_marker.visible:
			_failures.append("colour %s: P1's dispatch lit P2's ChargeMarker" % case[0])
		for p2_playing in _playing_stings(_p2_hero):
			_failures.append("colour %s: P1's dispatch played P2's sting '%s'" % [case[0], p2_playing])

		_player.hero.set_action_state(HeroState.ActionState.IDLE)
		_phase = "reset"
		_phase_frame = _frames
		return false

	if _phase == "reset" and _frames - _phase_frame >= CHECK_DELAY:
		# THE ORB GOES DARK AGAIN, asserted per colour. A ChargeMarker exempted from the
		# shape-clearing loop leaves the hero wearing a lit coloured orb for the rest of the match.
		var cleared_marker: MeshInstance3D = _hero.telegraph_controller.get_node(MARKER_PATH)
		if cleared_marker.visible:
			_failures.append("colour %s: ChargeMarker is STILL lit after leaving CHARGING"
					% _cases[_case_index][0])
		_case_index += 1
		_phase = "idle"
		return false

	if _phase == "draining" and _frames - _phase_frame >= CHECK_DELAY:
		_report()
		return false

	return false


## Every charge sting on `hero` that is CURRENTLY PLAYING, in STING_NODES order. A missing node is
## reported as a failure rather than silently skipped -- it is the same defect as a silent one.
func _playing_stings(hero: HeroActor) -> Array[String]:
	var playing: Array[String] = []
	for sting_name in STING_NODES:
		var sting: AudioStreamPlayer = hero.telegraph_controller.get_node_or_null(sting_name)
		if sting == null:
			_failures.append("sting node '%s' not found on %s" % [sting_name, hero.name])
		elif sting.playing:
			playing.append(sting_name)
	return playing


func _finish() -> void:
	# A still-playing AudioStreamPlayer leaks its internal mixer playback resource across
	# SceneTree.quit() if torn down the same frame it is stopped -- stopped here, then a few
	# more frames are let pass (the "draining" phase) before quit() so AudioServer's own mix
	# step actually retires it, rather than racing engine teardown against the audio thread.
	for sting_name in STING_NODES:
		var sting: AudioStreamPlayer = _hero.telegraph_controller.get_node_or_null(sting_name)
		if sting != null:
			sting.stop()
	# Simulated physics ticks advance instantly, not at wall-clock speed, so a frame COUNT gap
	# alone does not guarantee the audio mixer thread (which runs on real time) has actually
	# retired the stopped playback before quit() tears the tree down -- a real, if tiny, delay
	# is what closes that race, measured to still leave the flake behind a frame-count-only wait.
	OS.delay_msec(100)
	_phase = "draining"
	_phase_frame = _frames


func _report() -> void:
	var distinct_clips := {}
	for c in _seen_clips:
		distinct_clips[c] = true
	if _seen_clips.size() != _cases.size() or distinct_clips.size() != _cases.size():
		_failures.append("expected %d distinct clip names, saw %s" % [_cases.size(), _seen_clips])

	var distinct_stings := {}
	for s in _seen_stings:
		distinct_stings[s] = true
	if _seen_stings.size() != _cases.size() or distinct_stings.size() != _cases.size():
		_failures.append("expected %d distinct sting resolutions, saw %s" % [_cases.size(), _seen_stings])

	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("clips seen: %s" % [_seen_clips])
	print("stings seen: %s" % [_seen_stings])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
