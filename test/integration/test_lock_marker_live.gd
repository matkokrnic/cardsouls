extends SceneTree

## Story 4-6a (AC 13/AC 14) integration test: the LOCKED-TARGET MARKER in the live scene, observed
## through the scene tree only -- never a MatchState handle, never a runner private, the same
## discipline as every other file in this folder.
##
## WHAT THIS FILE DOES NOT CLAIM. Whether the dot READS as marking the right enemy is an operator
## smoke surface (`PROC/R8`) and no machine check may answer it. What is machine-checkable is
## everything the legibility rests on: that a marker exists per viewport, that it is where the
## locked target actually projects, that it is re-pushed every tick, and that it hides rather than
## lying about a target it can no longer see.
##
##   [AC 13 PER-VIEWPORT] Exactly TWO markers exist in the whole tree, one under each SubViewport's
##     own HudRoot, and each reports its OWN viewport. This is the property AC 13 requires under
##     either Open Question 3 branch -- P1's marker never renders in P2's view -- and taking the
##     HudRoot-owned branch is what makes it structural. A single shared marker, or one parented
##     above the viewports, fails here.
##   [AC 13 ON TARGET] Each marker's CENTRE sits on its own slot's locked target as projected
##     through its own follower camera. Asserted on BOTH slots against their two different targets,
##     so a marker pinned to a fixed screen spot, or one fed the WRONG slot's target, fails. The
##     centre is checked, not the Control's top-left, because a half-size offset error is exactly
##     the kind of small constant that reads as "the marker is on the wrong thing".
##   [AC 14 RE-PUSHED EVERY TICK] The marker is CLEARED directly on the HUD, and the runner puts it
##     back -- correctly placed -- on the very NEXT tick. A one-time write at _ready, or a push
##     seated behind any condition that has already been satisfied, never recovers and fails here.
##     This is what AC 14's "relocates on the same tick" and "no additional lag" rest on.
##
##     IT IS NOT TESTED BY WALKING THE HERO AND WATCHING THE DOT MOVE, and that is a finding rather
##     than a shortcut: under `CC/R2`'s always-locked camera the rig yaws to frame the locked
##     target, so the target projects to very near the same screen point no matter how the hero
##     moves. Measured here, forty frames of sideways sprint moved the marker 1.1 px -- inside this
##     file's own noise band. A "the marker moved" assertion would have been vacuous by
##     construction, passing on a marker that had merely drifted and failing to distinguish a live
##     push from a dead one.
##   [AC 14 HIDES] A null push hides the marker rather than leaving it stranded at its last point.
##     Driven by a direct call: the off-screen case is a camera arrangement this fixture cannot
##     stage without fighting the always-locked camera, and the branch under test is the HUD's.
##
## Run: godot --headless --path . --script res://test/integration/test_lock_marker_live.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

## The marker and the fixture unproject the SAME world point through the SAME camera, one runner
## step apart with both heroes at rest, so this band is float noise plus at most one frame of
## follower-camera settling -- not a tolerance for being roughly right.
const PIXEL_EPS := 2.0

var _p1_hero: Node3D
var _p2_hero: Node3D
var _p1_cam: Camera3D
var _p2_cam: Camera3D
var _p1_marker: Panel
var _p2_marker: Panel

var _frames := 0
var _per_viewport := false
var _on_target := false
var _hides := false
var _restored := false
var _detail := ""


func _initialize() -> void:
	root.add_child(load("res://src/main/main.tscn").instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		_p1_hero = root.get_node("Main/P1Hero")
		_p2_hero = root.get_node("Main/P2Hero")
		_p1_cam = root.get_node("Main/P1View/P1Viewport/P1Camera")
		_p2_cam = root.get_node("Main/P2View/P2Viewport/P2Camera")
		var p1_node := root.get_node_or_null("Main/P1View/P1Viewport/HudRoot/LockMarker")
		var p2_node := root.get_node_or_null("Main/P2View/P2Viewport/HudRoot/LockMarker")
		# Counted across the WHOLE tree, not merely found at the two expected paths: the failure
		# worth catching is a THIRD marker rendering somewhere it should not, which "both exist"
		# cannot see.
		var total := _count_markers(root)
		_per_viewport = p1_node != null and p2_node != null and total == 2
		if not _per_viewport:
			_detail += " marker_nodes(p1=%s p2=%s total=%d);" % [p1_node != null, p2_node != null, total]
		if not _per_viewport:
			_finish(false)
			return false
		_p1_marker = p1_node
		_p2_marker = p2_node
		# Each marker belongs to its OWN viewport -- the per-slot claim, read off the tree rather
		# than inferred from the path it was found at.
		var p1_vp := _p1_marker.get_viewport()
		var p2_vp := _p2_marker.get_viewport()
		if p1_vp == p2_vp or p1_vp != _p1_cam.get_viewport() or p2_vp != _p2_cam.get_viewport():
			_per_viewport = false
			_detail += " markers_share_or_cross_viewports;"
		# By `CC/R2` each slot starts locked on the opposing HERO, so P1's marker is on P2 and
		# P2's is on P1 -- two different targets, two different cameras.
		var p1_ok := _marks(_p1_marker, _p1_cam, _p2_hero, "P1")
		var p2_ok := _marks(_p2_marker, _p2_cam, _p1_hero, "P2")
		_on_target = p1_ok and p2_ok
		# Drive P1 SIDEWAYS so the SECOND on-target check below is made from a genuinely different
		# world arrangement rather than from the same standing start.
		Input.action_press(&"p1_move_right")
	if _frames == 45:
		Input.action_release(&"p1_move_right")
		# Still on target, from a hero position ~3 m from where the first check was made.
		if not _marks(_p1_marker, _p1_cam, _p2_hero, "P1-after-move"):
			_on_target = false
		# [AC 14 HIDES] then [AC 14 RE-PUSHED EVERY TICK], in that order and one tick apart.
		var p1_hud: HudRoot = root.get_node("Main/P1View/P1Viewport/HudRoot")
		p1_hud.set_lock_marker(null)
		_hides = not _p1_marker.visible
		if not _hides:
			_detail += " null_push_left_the_marker_visible;"
	if _frames == 46:
		_restored = _p1_marker.visible and _marks(_p1_marker, _p1_cam, _p2_hero, "P1-restored")
		if not _p1_marker.visible:
			_detail += " marker_never_came_back_after_being_cleared;"
		_finish(_per_viewport and _on_target and _hides and _restored)
	return false


## The marker's CENTRE lands where this camera projects the target's world position.
func _marks(marker: Panel, cam: Camera3D, target: Node3D, label: String) -> bool:
	if not marker.visible:
		_detail += " %s_marker_hidden;" % label
		return false
	var expected := cam.unproject_position(target.global_position)
	var centre := marker.position + marker.size * 0.5
	var off := centre.distance_to(expected)
	if off > PIXEL_EPS:
		_detail += " %s_marker_off_target(by=%f centre=%v want=%v);" % [label, off, centre, expected]
	return off <= PIXEL_EPS


func _count_markers(node: Node) -> int:
	var total := 1 if node.name == "LockMarker" else 0
	for child: Node in node.get_children():
		total += _count_markers(child)
	return total


func _finish(ok: bool) -> void:
	print("lock_marker: per_viewport=%s on_target=%s hides=%s restored=%s%s"
			% [_per_viewport, _on_target, _hides, _restored, _detail])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
