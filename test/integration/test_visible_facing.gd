extends SceneTree

## Story 1-7b (AC 5): the child Mesh is the TRUTHFUL DISPLAY of hitbox yaw. Drives the real
## main scene with two different movement presses (real Input, existing-suite pattern) and
## asserts after each, and again after release:
##   (a) mesh yaw == hitbox yaw (the truthful-display pin — one shared value in drive())
##       == the expected mapping of the hero's FACING (N2 — the test has no HeroState handle);
##   (b) the hero ROOT never rotates (DECISION A — root rotation stays identity throughout);
##   (c) the yaw survives input release with no snap-back and no mesh-side "remember last
##       direction" logic.
## Yaws are compared approximately and angle-aware (angle_difference), never exactly (N2).
##
## STORY 4-6 (AC 2/AC 6) REPLACED WHAT (a) AND (c) MEAN, and the file was re-derived rather than
## re-tuned. Facing is no longer written from movement input, so "the expected mapping of the
## PRESSED direction" is not a claim the code makes any more, and "the zero-guard freezes facing"
## names a guard that is gone. The expected yaw is now derived from the LOCKED TARGET's live
## position -- P1's default lock is the opposing hero (`CC/R2`) -- read off the scene tree at
## assertion time, exactly as every other observation in this file is.
##
## THE TWO HALVES THAT MATTER ARE UNCHANGED AND ARE THE REASON THIS FILE EXISTS: the single-yaw
## source (AC 6 -- mesh and hitbox share ONE computed value, so the visible body can never lie
## about hitbox aim) and DECISION A. What the presses buy now is STRONGER than the old mapping
## check: they prove facing does NOT follow input -- the hero is driven in two different
## directions and keeps facing its target through both, which is AC 2's headline claim.
##
## Run: godot --headless --path . --script res://test/integration/test_visible_facing.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

const YAW_EPS := 0.001

## Story 4-6: the tolerance for the LOCK-FACING assertion only -- never for the mesh==hitbox pin
## above, which stays exact-to-a-thousandth because it compares two values computed in the SAME
## statement and any gap at all is the defect.
##
## IT IS THE F1 ONE-TICK LAG, BOUNDED RATHER THAN WISHED AWAY. The runner gathers the lock
## direction at step 1c, BEFORE that tick's move_and_slide; this test reads both heroes' positions
## AFTER it. So the yaw on the mesh is always one tick of movement behind the yaw derived here.
## The bound: two heroes closing at no more than move_speed (5.0 u/s = 0.083 per tick) about a
## separation this fixture never lets fall below ~2 units gives at most ~0.042 rad of drift, and
## the measured value is 0.014. At 0.05 this still fails a facing that is off by a quadrant, which
## is the failure mode worth catching, and passes one that is off by a frame, which is the
## contract.
const LOCK_YAW_EPS := 0.05

var _p1: CharacterBody3D
## Story 4-6: the LOCKED TARGET. P1's default lock is the opposing hero, so the expected yaw is
## derived from this node's live position rather than from a literal -- both heroes move during
## the run, and a hardcoded angle would be a second, drifting answer to the same question.
var _p2: CharacterBody3D
var _mesh: MeshInstance3D
var _hitbox: Area3D
var _failures: Array[String] = []
var _frames := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())
	_p1 = root.get_node("Main/P1Hero")
	_p2 = root.get_node("Main/P2Hero")
	_mesh = _p1.get_node("Mesh")
	_hitbox = _p1.get_node("Hitbox")


func _physics_process(_delta: float) -> bool:
	_frames += 1
	# Press AFTER the tree is live (pressing in _initialize races the input system).
	if _frames == 5:
		Input.action_press(&"p1_move_right")
	if _frames == 20:
		# Story 4-6: the press steers the hero; it does NOT turn it. The expected yaw is the
		# direction to the locked target, whatever the stick is doing.
		_check_phase("right press", _expected_lock_yaw())
		Input.action_release(&"p1_move_right")
		Input.action_press(&"p1_move_up")
	if _frames == 35:
		# A DIFFERENT press, and the same expectation -- which is the whole of AC 2: two opposite
		# steering inputs, one facing, because facing has stopped listening to input.
		_check_phase("up press", _expected_lock_yaw())
		Input.action_release(&"p1_move_up")
	if _frames >= 50:
		# 15 zero-input frames later the hero still faces its target: no snap-back, and no
		# mesh-side memory -- the lock direction is pushed every tick whether or not input is.
		_check_phase("after release (no snap-back)", _expected_lock_yaw())
		var ok := _failures.is_empty()
		for f in _failures:
			print("  FAILED: " + f)
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false


## Story 4-6: the yaw the hero SHOULD be showing right now -- derived from the two live world
## positions the runner itself derives the lock direction from, using `hero.gd`'s own
## atan2(facing.x, facing.y) mapping. Read at assertion time, never cached.
func _expected_lock_yaw() -> float:
	var to_target := _p2.global_position - _p1.global_position
	return atan2(to_target.x, to_target.z)


## One phase = the full AC 5 assert set at the current frame: mesh==hitbox (primary pin),
## mesh==expected mapping of the hero's facing, root basis identity.
func _check_phase(phase: String, expected_yaw: float) -> void:
	var mesh_yaw := _mesh.rotation.y
	var hitbox_yaw := _hitbox.rotation.y
	if absf(angle_difference(mesh_yaw, hitbox_yaw)) > YAW_EPS:
		_failures.append("%s: mesh yaw %f != hitbox yaw %f (truthful-display pin)"
				% [phase, mesh_yaw, hitbox_yaw])
	if absf(angle_difference(mesh_yaw, expected_yaw)) > LOCK_YAW_EPS:
		_failures.append("%s: mesh yaw %f != expected yaw %f (facing points at the locked target)"
				% [phase, mesh_yaw, expected_yaw])
	if not _p1.transform.basis.is_equal_approx(Basis.IDENTITY):
		_failures.append("%s: hero ROOT basis is not identity (DECISION A violated): %s"
				% [phase, _p1.transform.basis])
	print("phase [%s]: mesh=%f hitbox=%f expected=%f root_identity=%s" % [
			phase, mesh_yaw, hitbox_yaw, expected_yaw,
			_p1.transform.basis.is_equal_approx(Basis.IDENTITY)])
