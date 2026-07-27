extends SceneTree

## Story 1-2 integration (AC 5) + Story 2-1 (AC 3): [smoke] the authored camera config .tres
## reaches the rig's camera, and [movement] rotating a rig PROGRAMMATICALLY (camera look input
## is out of E1 scope — no Input Map action exists or may be added) makes a fixed forward intent
## move that hero along ITS OWN camera forward, proving rig basis -> runner push -> state rotation
## -> actor displacement end-to-end.
##
## Story 2-1 extends this to BOTH slots, exercising the per-slot camera basis (_camera_bases —
## two live entries already at HEAD) independently for P1 (slot 0) and P2 (slot 1). The two rigs
## are yawed in OPPOSITE senses and both heroes are driven forward: each follows its OWN camera
## and is unaffected by the other's rotation (P1 -> world -X, P2 -> world +X). Opposite results
## from opposite rig yaws prove the two bases are distinct, not shared. Slot 1 is put on a
## KEYBOARD_P2 controller FOR THIS TEST ONLY (shipped main.tscn keeps slot 1 = NULL, the training
## dummy); the kind is set on the scene instance BEFORE it enters the tree, through the single
## per-slot config point (match_runner.slot_controller_kinds), never a private reach-in.
##
## Run: godot --headless --path . --script res://test/integration/test_camera_relative.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code).

var _p1: CharacterBody3D
var _p2: CharacterBody3D
var _p1_rig: Node3D
var _p2_rig: Node3D
var _p1_start := Vector3.ZERO
var _p2_start := Vector3.ZERO
var _frames := 0
var _smoke_ok := false


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	# Variant-typed so the runner's script-local export is reached dynamically (the runner has
	# no class_name to statically type against).
	var main: Variant = scene.instantiate()
	# Single per-slot config point (story 1-6): drive slot 1 with a real keyboard controller so
	# P2's camera-relative movement can be exercised. assign() coerces into the typed export in
	# place, BEFORE add_child so the runner's _ready reads it. Shipped default keeps slot 1 = NULL.
	main.slot_controller_kinds.assign([0, 1])  # 0 = KEYBOARD_P1, 1 = KEYBOARD_P2
	root.add_child(main)
	_p1 = root.get_node("Main/P1Hero")
	_p2 = root.get_node("Main/P2Hero")
	_p1_rig = root.get_node("Main/P1Hero/CameraRig")
	_p2_rig = root.get_node("Main/P2Hero/CameraRig")
	# Rotate each rig PROGRAMMATICALLY (no look input), in OPPOSITE senses: P1 +90 deg yaw
	# (camera forward -> world -X), P2 -90 deg yaw (camera forward -> world +X). Opposite
	# directions prove each hero uses ITS OWN per-slot basis, not a shared one.
	_p1_rig.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	_p2_rig.rotation_degrees = Vector3(0.0, -90.0, 0.0)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	# Everything below runs AFTER the tree is live: _ready fires only once the main loop
	# starts (pressing input or reading rig framing in _initialize races scene setup).
	if _frames == 5:
		# Smoke: authored .tres values reached P1's rig camera (loaded once at scene setup).
		var config: CameraConfig = load("res://data/camera_config.tres")
		var cam: Camera3D = _p1_rig.get_node("Camera3D")
		_smoke_ok = (
			config != null
			and is_equal_approx(cam.position.z, config.distance)
			and is_equal_approx(cam.position.y, config.height)
			and is_equal_approx(cam.rotation_degrees.x, config.pitch_degrees)
		)
		Input.action_press(&"p1_move_up")  # fixed forward intent, slot 0
		Input.action_press(&"p2_move_up")  # fixed forward intent, slot 1
		_p1_start = _p1.global_position
		_p2_start = _p2.global_position
	if _frames >= 35:
		Input.action_release(&"p1_move_up")
		Input.action_release(&"p2_move_up")
		var p1_moved := _p1.global_position - _p1_start
		var p2_moved := _p2.global_position - _p2_start
		# P1 rig yawed +90 deg: camera forward = world -X. Forward intent must displace P1
		# along -X, with no drift onto the unrotated -Z axis.
		var p1_followed := p1_moved.x < -0.1 and absf(p1_moved.z) < 0.05
		# P2 rig yawed -90 deg: camera forward = world +X. Forward intent must displace P2
		# along +X — the OPPOSITE axis, proving slot 1's basis is live AND independent of P1's.
		var p2_followed := p2_moved.x > 0.1 and absf(p2_moved.z) < 0.05
		var ok := _smoke_ok and p1_followed and p2_followed
		print("camera-relative P1 dx=%f dz=%f  P2 dx=%f dz=%f (smoke_ok=%s, p1_followed=%s, p2_followed=%s)" % [
			p1_moved.x, p1_moved.z, p2_moved.x, p2_moved.z, _smoke_ok, p1_followed, p2_followed])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
