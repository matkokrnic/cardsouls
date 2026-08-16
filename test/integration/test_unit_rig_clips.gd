extends SceneTree

## Story 4-3c (AC 3) machine contract: unit_actor.tscn carries the skeleton-zombie's
## AnimationPlayer with EXACTLY the four named clips and their loop flags, and the model's
## own bundled Mixamo take ("mixamo_com") is kept OUT of the scene. The minion counterpart
## of test_rig_clips.gd, which does the identical job for the hero's six clips.
##
## Instantiates unit_actor.tscn and asserts, scene-wide:
##   (a) exactly four animations total (no fifth clip riding in from the model import);
##   (b) the four expected names -- idle, walk, attack, death;
##   (c) loop ENABLED on idle/walk, DISABLED on attack/death;
##   (d) no clip named "mixamo_com" anywhere in the instantiated scene.
##
## (d) IS THE ONE THAT NEEDED A MECHANISM. The model FBX embeds a single Mixamo take and the
## importer's own `animation/import=false` does NOT strip it on this engine build (4.6.3) --
## 3-0a measured that and 3-0a/R10 sanctioned the substitute, an EditorScenePostImport hook
## (assets/characters/skeletonzombie/strip_model_anim.gd) that frees any AnimationPlayer the
## model import produces. This assertion is what keeps that hook honest: if the hook is
## removed, unregistered, or silently stops running at reimport, the model's AnimationPlayer
## comes back with mixamo_com on it and this test goes red on BOTH (a) and (d).
##
## The clip count/exclusion is scene-WIDE rather than scoped to the one AnimationPlayer, so a
## stray model-import AnimationPlayer is caught wherever in the tree it reappears.
##
## Structure only -- read from the packed scene at instantiation, no frame/_ready needed
## (test_rig_clips.gd's pattern).
##
## Run: godot --headless --path . --script res://test/integration/test_unit_rig_clips.gd

const EXPECTED_LOOP := {
	&"idle": true, &"walk": true,
	&"attack": false, &"death": false,
}

var _failures: Array[String] = []


func _initialize() -> void:
	var ps: PackedScene = load("res://src/actors/minions/unit_actor.tscn")
	if ps == null:
		print("RESULT: FAIL")
		print("  FAILED: unit_actor.tscn did not load")
		quit(1)
		return
	var unit := ps.instantiate()

	var players := unit.find_children("*", "AnimationPlayer", true, false)
	var names: Array[StringName] = []
	for p in players:
		var ap := p as AnimationPlayer
		for n in ap.get_animation_list():
			names.append(n)
			if String(n).contains("mixamo"):
				_failures.append("forbidden clip present: '%s' (model take leaked in)" % n)

	if names.size() != 4:
		_failures.append("expected exactly 4 clips, found %d: %s" % [names.size(), names])

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
	# Never added to the tree, so never freed by one: unit_actor.tscn carries two Area3Ds and a
	# body collision shape whose Jolt RIDs the tightened harness would otherwise report leaked
	# at exit (the 4-3b/F4 finding, which this file inherits rather than re-learns).
	unit.free()
	quit(0 if ok else 1)
