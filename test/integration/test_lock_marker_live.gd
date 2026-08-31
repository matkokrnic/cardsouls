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
##   [BODY-MARK, live-smoke micro-fix 2026-08-31] The marker's centre lands on the locked target's
##     BODY, not its ground-level ROOT, when that target is a summoned unit rather than a hero. A
##     `Resource_kind_minion` (`data/balance/balance_config.tres` kind index 0 -- melee, no
##     projectile) is appended directly to P2's board and P1's lock addressed onto it, the
##     `_lock_direction`/`face_lock_direction` route a real flick or relock would also drive, so
##     the reframe and the marker push are exercised exactly as they would be live. `_marks()`
##     covers hero targets already (`P1`/`P2`/`P1-after-move`/`P1-restored` above); this is the same
##     check with the unit's own `LOCK_MARK_UNIT_LIFT` (`match_runner.gd`) folded into the expected
##     point, so a marker still landing at the unit's feet -- the defect this fix corrects -- fails
##     here exactly as it would have before the fix.
##
## Run: godot --headless --path . --script res://test/integration/test_lock_marker_live.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

## The marker and the fixture unproject the SAME world point through the SAME camera, one runner
## step apart with both heroes at rest, so this band is float noise plus at most one frame of
## follower-camera settling -- not a tolerance for being roughly right.
const PIXEL_EPS := 2.0

## `data/balance/balance_config.tres` kind index 0: `Resource_kind_minion`, melee (no
## `projectile`), so `MatchRunner._unit_scene_for` spawns it on `unit_actor.tscn` -- a UnitActor
## carrying a `Hitbox`, which is what makes `LOCK_MARK_UNIT_LIFT` rather than
## `LOCK_MARK_TOTEM_LIFT` the offset under test.
const MINION_KIND_INDEX := 0
const MINION_MAX_HP := 10.0
## `match_runner.gd`'s own `LOCK_MARK_UNIT_LIFT` -- duplicated here as a literal deliberately
## (`4-6a` house rule already applies to the SHARED runner computation; a fixture is a second,
## independent reader of the same authored number, not a second producer of it) rather than reached
## through a private runner member. Live-smoke micro-fix v2: ~3/4 of the skinned model's real AABB
## height from the ground (match_runner.gd's own derivation), not half the placeholder box anymore.
const UNIT_LIFT := 1.53

var _p1_hero: Node3D
var _p2_hero: Node3D
var _p1_cam: Camera3D
var _p2_cam: Camera3D
var _p1_marker: Panel
var _p2_marker: Panel
var _runner: Node
var _state: MatchState
var _p2_minion: Node3D

var _frames := 0
var _per_viewport := false
var _on_target := false
var _hides := false
var _restored := false
var _on_unit_target := false
var _round_over_hides := false
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
	if _frames == 48:
		# [BODY-MARK] Stage a minion directly on P2's board and address P1's lock at it, the
		# same shape `test_summon_actor_live.gd` uses to reach `MatchState` from this fixture
		# (`_runner._match_state`) -- cheaper than driving a real cast through the Input Map,
		# and this is the STATE the runner's spawn poll and `_lock_direction` both read
		# regardless of how a lock address arrives (`_resolve_retarget` stamps this same pair
		# on a real flick/relock; this fixture stamps it directly).
		_runner = root.get_node("Main")
		_state = _runner._match_state
		_state.p2.units.add(MINION_MAX_HP, MINION_KIND_INDEX)
		_state.p1.lock_target_slot = 1
		_state.p1.lock_target_index = 0
	if _frames == 90:
		# Forty-two ticks for the runner's spawn poll (`_spawn_missing_unit_actors`, same tick
		# as the board write above settles into the physics-process order) and for
		# `CameraRig`'s `lock_yaw_smoothing` to bring the always-locked camera back onto the
		# new target -- generous rather than tuned, because `_marks_lifted` compares the marker
		# to a projection made through the SAME camera transform at the SAME tick, so the
		# camera's exact heading does not matter once the target is on screen at all.
		var actors: Array = _runner._unit_actors[1]
		_p2_minion = actors[0] if actors.size() > 0 else null
		if _p2_minion == null or not is_instance_valid(_p2_minion):
			_detail += " p2_minion_never_spawned;"
		else:
			_on_unit_target = _marks_lifted(_p1_marker, _p1_cam, _p2_minion, UNIT_LIFT, "P1-unit")
	if _frames == 91:
		# [ROUND-OVER HIDES, live-smoke micro-fix v2, low priority] Stamp the round-over latch
		# directly on state -- the same cheaper-than-a-real-kill staging shape frame 48 already
		# uses for the minion (`_state.p2.units.add`), reaching the field GDScript never actually
		# makes private rather than driving a real kill through the whole contact pipeline, which
		# this fixture has no cheap way to stage against a live, moving, always-locked camera.
		_state._round_over = true
	if _frames == 92:
		# Both markers hide on the very next tick once the freeze is up -- the runner reads the
		# SAME `to_snapshot()["round_over"]` flag both slots share, so this is not a per-slot check.
		_round_over_hides = not _p1_marker.visible and not _p2_marker.visible
		if not _round_over_hides:
			_detail += " round_over_did_not_hide_markers(p1_visible=%s p2_visible=%s);" % [_p1_marker.visible, _p2_marker.visible]
		_finish(_per_viewport and _on_target and _hides and _restored and _on_unit_target and _round_over_hides)
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


## The `_marks` check with a vertical LIFT folded into the expected point -- the unit body-mark
## counterpart. A marker still landing on `target.global_position` (the unit's feet, the pre-fix
## defect) misses `expected` by roughly `lift` metres of screen distance and fails here.
func _marks_lifted(marker: Panel, cam: Camera3D, target: Node3D, lift: float, label: String) -> bool:
	if not marker.visible:
		_detail += " %s_marker_hidden;" % label
		return false
	var expected := cam.unproject_position(target.global_position + Vector3.UP * lift)
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
	print("lock_marker: per_viewport=%s on_target=%s hides=%s restored=%s on_unit_target=%s round_over_hides=%s%s"
			% [_per_viewport, _on_target, _hides, _restored, _on_unit_target, _round_over_hides, _detail])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
