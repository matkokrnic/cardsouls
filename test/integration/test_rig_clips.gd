extends SceneTree

## Story 3-0a (AC 3) machine contract, EXTENDED BY 5-0a (AC 1) from six clips to NINE, and BY
## 5-3 (AC 3) from nine to TWELVE: hero.tscn carries the paladin's AnimationPlayer with
## EXACTLY the twelve named clips and their loop flags, and the model's own Mixamo T-pose
## take ("mixamo_com") is kept OUT of the scene. Instantiates hero.tscn and asserts,
## scene-wide:
##   (a) exactly twelve animations total (no thirteenth clip riding in from the model import);
##   (b) the twelve expected names — idle, run, attack, block, roll, death (3-0a),
##       strafe_left, strafe_right, backpedal (5-0a), plus swipe, jump_attack, thrust
##       (5-3's colour-telegraph attack poses);
##   (c) loop ENABLED on idle/run/block/strafe_left/strafe_right/backpedal (every repeating
##       movement or resting pose), DISABLED on attack/roll/death/swipe/jump_attack/thrust
##       (one-shot poses, 5-3's three matching `attack`'s existing flag);
##   (d) no clip named "mixamo_com" anywhere in the instantiated scene.
## Structure only — read from the packed scene at instantiation, no frame/_ready needed.
##
## The count assertion is derived from EXPECTED_LOOP rather than a second hand-written
## literal: 3-0a wrote "6" in two places, and this story had to change both. One source.
##
## Run: godot --headless --path . --script res://test/integration/test_rig_clips.gd

const EXPECTED_LOOP := {
	&"idle": true, &"run": true, &"block": true,
	&"strafe_left": true, &"strafe_right": true, &"backpedal": true,
	&"attack": false, &"roll": false, &"death": false,
	&"swipe": false, &"jump_attack": false, &"thrust": false,
}

var _failures: Array[String] = []


func _initialize() -> void:
	var ps: PackedScene = load("res://src/actors/hero/hero.tscn")
	if ps == null:
		print("RESULT: FAIL")
		print("  FAILED: hero.tscn did not load")
		quit(1)
		return
	var hero := ps.instantiate()

	# Every clip across every AnimationPlayer in the scene (the count/exclusion is scene-wide,
	# so a stray model-import AnimationPlayer with mixamo_com would be caught here too).
	var players := hero.find_children("*", "AnimationPlayer", true, false)
	var names: Array[StringName] = []
	for p in players:
		var ap := p as AnimationPlayer
		for n in ap.get_animation_list():
			names.append(n)
			if String(n).contains("mixamo"):
				_failures.append("forbidden clip present: '%s' (model T-pose leaked in)" % n)

	if names.size() != EXPECTED_LOOP.size():
		_failures.append("expected exactly %d clips, found %d: %s"
			% [EXPECTED_LOOP.size(), names.size(), names])

	for want: StringName in EXPECTED_LOOP:
		if not names.has(want):
			_failures.append("missing expected clip '%s'" % want)

	# Loop flag per clip (only meaningful for clips that exist).
	for p in players:
		var ap := p as AnimationPlayer
		for n in ap.get_animation_list():
			if not EXPECTED_LOOP.has(n):
				continue
			var loops := ap.get_animation(n).loop_mode != Animation.LOOP_NONE
			if loops != EXPECTED_LOOP[n]:
				_failures.append("clip '%s' loop=%s, expected loop=%s" % [n, loops, EXPECTED_LOOP[n]])

	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("clips found: %s" % [names])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	# Review fix pass (4-3b, F4): `instantiate()` above is never added to the tree, so it was
	# never freed either -- a leaked Node whose physics shapes (hero.tscn's hurtbox/hitbox
	# Area3Ds) leaked their Jolt RIDs with it. Measured cause of the "N RID allocations ... were
	# leaked at exit" errors the tightened harness now catches (a loose harness let a PASSing run
	# hide them). Freed explicitly rather than added to the tree and freed there: this file reads
	# scene structure only and never runs a frame, so there is no teardown seat to ride on.
	hero.free()
	quit(0 if ok else 1)
