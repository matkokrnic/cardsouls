extends SceneTree

## Story 4-6 (AC 1) integration test: the CAMERA RIG's per-tick lock-on yaw, driven through the
## real chain in the live scene — MatchState's lock address -> the runner's step-1c gather ->
## CameraRig.face_lock_direction -> the rig ROOT's own basis. Nothing here holds a MatchState
## handle; every observation is a scene-tree read, the same discipline as every other integration
## file.
##
##   [AC 1 FRAMED] Each slot's rig root yaws so that CAMERA FORWARD (the rig's own -Z, which the
##     child camera at +Z looks back through) points at that slot's locked target. Asserted on
##     BOTH slots against their two live world positions, so a rig that yawed to a fixed angle, or
##     to the WRONG slot's target, fails.
##   [AC 1 LIVE] The yaw TRACKS: the hero is driven sideways so the bearing to its target really
##     changes, and the rig's yaw changes with it. A one-time write at _ready would pass the first
##     check and fail this one.
##   [AC 1 FRAMING UNTOUCHED] The CHILD camera still carries the authored distance/height/pitch
##     from data/camera_config.tres, and its local rotation stays pitch-only — the yaw is a
##     SEPARATE write to a SEPARATE node (`4-6/R1`), so a rig yaw that leaked onto the child, or an
##     apply_config() that got dragged into the per-tick path, fails here.
##   [DECISION A] The hero ROOT never rotates, throughout.
##
## Run: godot --headless --path . --script res://test/integration/test_lock_on_live.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

## The rig yaw is derived from positions the runner reads BEFORE that tick's move_and_slide, so a
## measurement taken after it is always one tick of movement stale (the F1 one-tick lag). At
## move_speed 5.0 over the separations this fixture holds that is well under 0.05 rad; the band
## still fails a yaw that is off by a quadrant, which is the failure worth catching.
const YAW_EPS := 0.05
## The hero root must not rotate AT ALL — this is not a tolerance, it is float noise.
const ROOT_EPS := 1.0e-6

var _p1: CharacterBody3D
var _p2: CharacterBody3D
var _p1_rig: Node3D
var _p2_rig: Node3D
var _p1_cam: Camera3D
var _config: CameraConfig

var _framed_p1 := false
var _framed_p2 := false
var _yaw_before := 0.0
var _yaw_tracked := false
var _framing_intact := false
var _pitch_only := false
var _roots_never_rotated := true
var _frames := 0
var _detail := ""


func _initialize() -> void:
	root.add_child(load("res://src/main/main.tscn").instantiate())
	_p1 = root.get_node("Main/P1Hero")
	_p2 = root.get_node("Main/P2Hero")
	_p1_rig = root.get_node("Main/P1Hero/CameraRig")
	_p2_rig = root.get_node("Main/P2Hero/CameraRig")
	_p1_cam = root.get_node("Main/P1Hero/CameraRig/Camera3D")
	_config = load("res://data/camera_config.tres")


func _physics_process(_delta: float) -> bool:
	_frames += 1
	# DECISION A, checked on EVERY frame rather than at the phase boundaries: a root rotation that
	# appeared for one tick and vanished would still have folded into a pushed basis.
	if _frames > 1:
		if not _p1.transform.basis.is_equal_approx(Basis.IDENTITY) \
				or not _p2.transform.basis.is_equal_approx(Basis.IDENTITY):
			_roots_never_rotated = false
	if _frames == 5:
		_framed_p1 = _is_framed(_p1_rig, _p1, _p2, "P1")
		_framed_p2 = _is_framed(_p2_rig, _p2, _p1, "P2")
		# The authored framing, on the CHILD, untouched by the root's new per-tick yaw. 7-6 POLISH 2 (operator ruling
		# P11, a NAMED change): the distance and height are scaled by the one `framing_scale` knob.
		_framing_intact = _config != null \
				and is_equal_approx(_p1_cam.position.z, _config.distance * _config.framing_scale) \
				and is_equal_approx(_p1_cam.position.y, _config.height * _config.framing_scale) \
				and is_equal_approx(_p1_cam.rotation_degrees.x, _config.pitch_degrees)
		_pitch_only = is_zero_approx(_p1_cam.rotation.y) and is_zero_approx(_p1_cam.rotation.z)
		if not _framing_intact:
			_detail += " framing_moved(cam=%v rot=%v);" % [_p1_cam.position, _p1_cam.rotation_degrees]
		if not _pitch_only:
			_detail += " child_camera_yawed(%v);" % _p1_cam.rotation
		_yaw_before = _p1_rig.rotation.y
		# Drive P1 SIDEWAYS relative to its own camera, which is the one direction that actually
		# changes the bearing to the target — walking straight at it leaves the yaw exactly where
		# it is, and would make the tracking check below vacuous.
		Input.action_press(&"p1_move_right")
	if _frames == 40:
		Input.action_release(&"p1_move_right")
		_yaw_tracked = absf(angle_difference(_p1_rig.rotation.y, _yaw_before)) > 0.05
		if not _yaw_tracked:
			_detail += " yaw_did_not_track(before=%f after=%f);" % [_yaw_before, _p1_rig.rotation.y]
	if _frames >= 55:
		# Re-checked after the move: the rig is still FRAMING, from a different position and a
		# different yaw, which is what makes it a driver rather than a lucky initial value.
		var still_framed := _is_framed(_p1_rig, _p1, _p2, "P1-after-move")
		var ok := _framed_p1 and _framed_p2 and _yaw_tracked and still_framed \
				and _framing_intact and _pitch_only and _roots_never_rotated
		print(("lock_on_live: framed_p1=%s framed_p2=%s yaw_tracked=%s still_framed=%s "
				+ "framing_intact=%s pitch_only=%s roots_identity=%s%s")
				% [_framed_p1, _framed_p2, _yaw_tracked, still_framed, _framing_intact,
					_pitch_only, _roots_never_rotated, _detail])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false


## Camera forward is the rig's LOCAL -Z, which for a yaw-only rig root under an unrotated hero root
## is world (-sin y, 0, -cos y). Framed means that direction points at the target.
func _is_framed(rig: Node3D, hero: Node3D, target: Node3D, label: String) -> bool:
	var forward := Vector2(-sin(rig.rotation.y), -cos(rig.rotation.y))
	var to_target := target.global_position - hero.global_position
	var bearing := Vector2(to_target.x, to_target.z).normalized()
	var off := absf(forward.angle_to(bearing))
	if off > YAW_EPS:
		_detail += " %s_not_framed(off=%f rad, yaw=%f);" % [label, off, rig.rotation.y]
	return off <= YAW_EPS
