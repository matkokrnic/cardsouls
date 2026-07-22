extends SceneTree

## DECISION A guard (story 1-2 review follow-up): hero-ROOT rotation must never bleed into
## the pushed camera basis. The rig is a child of the hero root, so the runner reads the
## rig's LOCAL basis — if it read the global basis, rotating the root would fold hero
## rotation into "camera forward" and silently break camera-relative movement. This test
## drives the REAL runner step-2 push path (not a direct set_camera_basis, which would miss
## the defect): rotate the P1 hero root a non-trivial yaw, hold a fixed forward intent, and
## assert displacement matches what the FIXED camera gives (world -Z, no -X bleed).
##
## While the camera is fixed (all of E1) the hero root must simply never be rotated —
## body/facing visuals belong on a child mesh node. A later story that needs a rotating
## root must decouple the rig from hero rotation deliberately (deferred DECISION B).
##
## Run: godot --headless --path . --script res://test/integration/test_root_rotation_isolation.gd

var _p1: CharacterBody3D
var _start := Vector3.ZERO
var _frames := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())
	_p1 = root.get_node("Main/P1Hero")
	# Simulate the FORBIDDEN condition: something rotated the hero root. The camera stays
	# fixed (the rig's own rotation is untouched), so movement must stay fixed-camera
	# correct — the root yaw must not leak through the basis push into velocity.
	_p1.rotation_degrees = Vector3(0.0, 60.0, 0.0)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	# Act only after the tree is live (_ready fires once the main loop starts).
	if _frames == 5:
		Input.action_press(&"p1_move_up")  # fixed forward intent
		_start = _p1.global_position
	if _frames >= 35:
		Input.action_release(&"p1_move_up")
		var moved := _p1.global_position - _start
		# Fixed camera => forward = world -Z. Root yaw must NOT rotate that toward -X.
		var isolated := moved.z < -0.1 and absf(moved.x) < 0.05
		print("root-rotation isolation dx=%f dz=%f (isolated=%s)" % [moved.x, moved.z, isolated])
		print("RESULT: %s" % ("PASS" if isolated else "FAIL"))
		quit(0 if isolated else 1)
	return false
