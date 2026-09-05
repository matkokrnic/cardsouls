extends SceneTree

## Story 5-3 (AC 13): S5's success-cue half. `MatchState.card_cast_resolved` is an EXISTING
## signal both `_resolve_basic_cast` and `_resolve_unblockable_cast` already emit on their
## success paths -- but nothing listened before this story (Dev Notes, `match_state.gd:2369,
## 2508`). This pin is the runtime half of that claim: a headless state test can prove the
## signal exists and fires, but not that a REAL hero's `CueCastSuccess` actually plays when it
## does -- exactly `3-0b/R34`'s blind spot (authored data at rest vs. runtime composition),
## the same reason AC 21 gets its own live pin.
##
## DIRECT SIGNAL EMIT, not a real cast: `card_cast_resolved` is pushed through the D5 queue by
## its two real callers, but what this file needs to prove is ONLY the wiring from the signal
## to the cue -- match_runner's direct connect (AC 13's own "plain connect, not a seam" choice)
## -- not `_resolve_basic_cast`'s mana/hand preconditions, which are unrelated to this story.
## Emitting directly is therefore the right-sized poke, mirroring AC 21's own field-poke
## rationale one level up the stack.
##
## Run: godot --headless --path . --script res://test/integration/test_cast_success_cue_live.gd

var _frames := 0
var _runner: Node
var _state: MatchState
var _hero: HeroActor
var _p2_hero: HeroActor


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames != 1:
		return false

	_runner = root.get_node_or_null("Main")
	_state = _runner._match_state if _runner != null else null
	_hero = _runner._p1_hero if _runner != null else null
	_p2_hero = _runner._p2_hero if _runner != null else null
	if _runner == null or _state == null or _hero == null or _p2_hero == null:
		print("missing: runner=%s state=%s hero=%s p2_hero=%s" % [_runner, _state, _hero, _p2_hero])
		print("RESULT: FAIL")
		quit(1)
		return false

	var cue_p1: AudioStreamPlayer = _hero.telegraph_controller.get_node_or_null("CueCastSuccess")
	var cue_p2: AudioStreamPlayer = _p2_hero.telegraph_controller.get_node_or_null("CueCastSuccess")
	var failures: Array[String] = []
	if cue_p1 == null or cue_p2 == null:
		failures.append("CueCastSuccess node missing (p1=%s p2=%s)" % [cue_p1, cue_p2])
	else:
		if cue_p1.playing or cue_p2.playing:
			failures.append("baseline: a cast-success cue is already playing before any emit")

		# NON-VACUOUS: P1's cast resolves P1's cue only, never P2's -- a slot mismatch would be
		# a cross-wired seam (the exact class of bug the `if cast_slot == slot` guard prevents).
		_state.card_cast_resolved.emit(0, &"test_card")
		if not cue_p1.playing:
			failures.append("P1 cast_cast_resolved(slot=0) did not play P1's CueCastSuccess")
		if cue_p2.playing:
			failures.append("P1's card_cast_resolved(slot=0) incorrectly played P2's CueCastSuccess")
		cue_p1.stop()

		_state.card_cast_resolved.emit(1, &"test_card")
		if not cue_p2.playing:
			failures.append("P2 card_cast_resolved(slot=1) did not play P2's CueCastSuccess")
		cue_p2.stop()

	OS.delay_msec(100)  # let the audio mixer thread retire the stopped playbacks before quit()
	var ok := failures.is_empty()
	for f in failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false
