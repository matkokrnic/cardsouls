extends SceneTree

## Story 1-7b (AC 5): the child Mesh is the TRUTHFUL DISPLAY of hitbox yaw. Drives the real
## main scene with two different movement presses (real Input, existing-suite pattern) and
## asserts after each, and again after release:
##   (a) mesh yaw == hitbox yaw (the truthful-display pin — one shared value in drive())
##       == the expected mapping of the pressed direction: under the scene's fixed IDENTITY
##       camera basis, facing equals the pressed world direction, so expected yaw is
##       atan2(world.x, world.z) of the press (N2 — the test has no HeroState handle);
##   (b) the hero ROOT never rotates (DECISION A — root rotation stays identity throughout);
##   (c) after input release the yaw PERSISTS (AC 4 — the state-side zero-guard freezes
##       facing; no snap-back, and no mesh-side "remember last direction" logic exists).
## Yaws are compared approximately and angle-aware (angle_difference), never exactly (N2).
##
## Run: godot --headless --path . --script res://test/integration/test_visible_facing.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

const YAW_EPS := 0.001

var _p1: CharacterBody3D
var _mesh: MeshInstance3D
var _hitbox: Area3D
var _failures: Array[String] = []
var _frames := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())
	_p1 = root.get_node("Main/P1Hero")
	_mesh = _p1.get_node("Mesh")
	_hitbox = _p1.get_node("Hitbox")


func _physics_process(_delta: float) -> bool:
	_frames += 1
	# Press AFTER the tree is live (pressing in _initialize races the input system).
	if _frames == 5:
		Input.action_press(&"p1_move_right")
	if _frames == 20:
		# p1_move_right -> move_dir (1, 0) -> identity-basis world (1, 0, 0) -> yaw PI/2.
		_check_phase("right press", atan2(1.0, 0.0))
		Input.action_release(&"p1_move_right")
		Input.action_press(&"p1_move_up")
	if _frames == 35:
		# p1_move_up -> move_dir (0, -1) -> identity-basis world (0, 0, -1) -> yaw PI.
		_check_phase("up press", atan2(0.0, -1.0))
		Input.action_release(&"p1_move_up")
	if _frames >= 50:
		# 15 zero-input frames later the yaw still shows the LAST press (no snap-back).
		_check_phase("after release (persistence)", atan2(0.0, -1.0))
		var ok := _failures.is_empty()
		for f in _failures:
			print("  FAILED: " + f)
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false


## One phase = the full AC 5 assert set at the current frame: mesh==hitbox (primary pin),
## mesh==expected mapping of the press, root basis identity.
func _check_phase(phase: String, expected_yaw: float) -> void:
	var mesh_yaw := _mesh.rotation.y
	var hitbox_yaw := _hitbox.rotation.y
	if absf(angle_difference(mesh_yaw, hitbox_yaw)) > YAW_EPS:
		_failures.append("%s: mesh yaw %f != hitbox yaw %f (truthful-display pin)"
				% [phase, mesh_yaw, hitbox_yaw])
	if absf(angle_difference(mesh_yaw, expected_yaw)) > YAW_EPS:
		_failures.append("%s: mesh yaw %f != expected yaw %f (mapping of the press)"
				% [phase, mesh_yaw, expected_yaw])
	if not _p1.transform.basis.is_equal_approx(Basis.IDENTITY):
		_failures.append("%s: hero ROOT basis is not identity (DECISION A violated): %s"
				% [phase, _p1.transform.basis])
	print("phase [%s]: mesh=%f hitbox=%f expected=%f root_identity=%s" % [
			phase, mesh_yaw, hitbox_yaw, expected_yaw,
			_p1.transform.basis.is_equal_approx(Basis.IDENTITY)])
