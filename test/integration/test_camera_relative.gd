extends SceneTree

## Story 1-2 integration (AC 5) + Story 2-1 (AC 3) + Story 4-6 (AC 1, AC 7): [smoke] the authored
## camera config .tres reaches the rig's camera, and [movement] a fixed forward intent moves each
## hero along ITS OWN camera forward, proving rig basis -> runner push -> state rotation -> actor
## displacement end-to-end.
##
## STORY 4-6 RE-EXAMINED THIS FILE RATHER THAN RE-RUNNING IT (AC 7 requires exactly that), and it
## needed the fixture rewritten. Through 4-4 the test rotated each rig PROGRAMMATICALLY, because
## camera rotation was out of scope and nothing else could move a rig. That is no longer possible:
## the runner now yaws both rigs EVERY TICK to frame the locked target, so a rotation written in
## _initialize() is overwritten before the first measurement. THE DRIVER REPLACES THE FIXTURE.
##
## WHAT THE TEST PROVES IS UNCHANGED, and if anything is now proven against the shipping path
## instead of a test-only one. Each rig looks at its own locked target, which by default is the
## opposing hero (`CC/R2`); main.tscn parks P1 at x -3 and P2 at x +3; so P1's camera forward is
## world +X and P2's is world -X. A forward intent must therefore walk each hero TOWARD the other
## -- in OPPOSITE world directions, which is still the per-slot proof: two heroes following one
## shared basis would move the same way, and the bases here are live rather than staged.
##
## THE EXPECTED SIGNS ARE THE EXACT INVERSE of the pre-4-6 ones (P1 was -X, P2 was +X), because
## the old fixture yawed P1 +90 and P2 -90 while the live lock yaws them to face each other.
##
## Slot 1 is put on a KEYBOARD_P2 controller EXPLICITLY, via assign() below (shipped main.tscn also
## ships KEYBOARD_P2 on slot 1 as of 2-3 — NULL, the training dummy, remains an available kind but
## is no longer the default); the kind is set on the scene instance BEFORE it enters the tree,
## through the single per-slot config point (match_runner.slot_controller_kinds), never a
## private reach-in.
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
	# place, BEFORE add_child so the runner's _ready reads it. As of 2-3 this now matches the
	# shipped default (slot 1 = KEYBOARD_P2), but the explicit override is kept on purpose: a
	# test must not depend on a default it does not itself set.
	main.slot_controller_kinds.assign([0, 1])  # 0 = KEYBOARD_P1, 1 = KEYBOARD_P2
	root.add_child(main)
	_p1 = root.get_node("Main/P1Hero")
	_p2 = root.get_node("Main/P2Hero")
	_p1_rig = root.get_node("Main/P1Hero/CameraRig")
	_p2_rig = root.get_node("Main/P2Hero/CameraRig")
	# Story 4-6: NOTHING IS STAGED HERE ANY MORE. The rigs are yawed by the runner's own per-tick
	# lock-on driver, from the default lock (`CC/R2`: the opposing hero), so the bases this test
	# measures against are the ones the game actually ships.


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
			# 7-6 POLISH (P11, a NAMED change): the framing is scaled by the one `framing_scale` knob.
			and is_equal_approx(cam.position.z, config.distance * config.framing_scale)
			and is_equal_approx(cam.position.y, config.height * config.framing_scale)
			and config.framing_scale > 0.0
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
		# P1 is locked on P2, which sits at +X: camera forward = world +X. A forward intent must
		# displace P1 along +X, with no drift onto the unrotated -Z axis the identity basis gave.
		var p1_followed := p1_moved.x > 0.1 and absf(p1_moved.z) < 0.05
		# P2 is locked on P1, which sits at -X: camera forward = world -X. The OPPOSITE axis,
		# proving slot 1's basis is live AND independent of P1's -- and that the yaw driver is
		# per-slot rather than one shared camera.
		var p2_followed := p2_moved.x < -0.1 and absf(p2_moved.z) < 0.05
		var ok := _smoke_ok and p1_followed and p2_followed
		print("camera-relative P1 dx=%f dz=%f  P2 dx=%f dz=%f (smoke_ok=%s, p1_followed=%s, p2_followed=%s)" % [
			p1_moved.x, p1_moved.z, p2_moved.x, p2_moved.z, _smoke_ok, p1_followed, p2_followed])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
