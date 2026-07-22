extends SceneTree

## Story 1-2 integration (AC 5): [smoke] the authored camera config .tres reaches the rig's
## camera, and [movement] rotating the rig PROGRAMMATICALLY (camera look input is out of E1
## scope — no Input Map action exists or may be added) makes a fixed forward intent move the
## hero along the camera's forward, proving rig basis -> runner push -> state rotation ->
## actor displacement end-to-end.
##
## Run: godot --headless --path . --script res://test/integration/test_camera_relative.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code).

var _p1: CharacterBody3D
var _rig: Node3D
var _start := Vector3.ZERO
var _frames := 0
var _smoke_ok := false


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())
	_p1 = root.get_node("Main/P1Hero")
	_rig = root.get_node("Main/P1Hero/CameraRig")
	# Rotate the camera 90 deg yaw — PROGRAMMATICALLY, on the rig transform (no look input).
	_rig.rotation_degrees = Vector3(0.0, 90.0, 0.0)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	# Everything below runs AFTER the tree is live: _ready fires only once the main loop
	# starts (pressing input or reading rig framing in _initialize races scene setup).
	if _frames == 5:
		# Smoke: authored .tres values reached the rig's camera (loaded once at scene setup).
		var config: CameraConfig = load("res://data/camera_config.tres")
		var cam: Camera3D = _rig.get_node("Camera3D")
		_smoke_ok = (
			config != null
			and is_equal_approx(cam.position.z, config.distance)
			and is_equal_approx(cam.position.y, config.height)
			and is_equal_approx(cam.rotation_degrees.x, config.pitch_degrees)
		)
		Input.action_press(&"p1_move_up")  # fixed forward intent
		_start = _p1.global_position
	if _frames >= 35:
		Input.action_release(&"p1_move_up")
		var moved := _p1.global_position - _start
		# Rig yawed +90 deg: camera forward = world -X. Forward intent must displace the
		# hero along -X (following the camera), with no drift onto the unrotated -Z axis.
		var followed := moved.x < -0.1 and absf(moved.z) < 0.05
		var ok := _smoke_ok and followed
		print("camera-relative dx=%f dz=%f (smoke_ok=%s, followed_camera=%s)" % [
			moved.x, moved.z, _smoke_ok, followed])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
