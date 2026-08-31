extends SceneTree

## Story 4-6a (AC 10/AC 11/AC 12) integration test: the CAMERA RIG's lock-on yaw SMOOTHING, proven
## on the rig in ISOLATION rather than through the live match.
##
## WHY IN ISOLATION, deliberately. The smoothing's FEEL is an operator smoke surface (`PROC/R8`)
## and no machine check may claim it. What IS machine-checkable is the MECHANISM -- that the yaw
## eases toward its target by the authored per-tick fraction instead of snapping -- and that is a
## property of `face_lock_direction` alone, driven here by direct calls at known angles. Measuring
## it through main.tscn instead would have made the assertion a function of hero speed, separation
## and one-tick gather lag, i.e. a band tuned until it passed rather than a stated contract.
##
##   [AC 10 EASES] With smoothing authored below 1.0, a NEW bearing is approached by the authored
##     fraction of the remaining angle per call -- checked against the closed form, so a rig that
##     snapped, that moved by a different fraction, or that moved a fixed step, all fail.
##   [AC 10 FIRST SNAPS] The FIRST heading a rig ever receives is taken WHOLE. A rig that eased
##     from its arbitrary scene-zero would swing across the arena at match start, and would also
##     break `test_lock_on_live.gd`'s frame-5 framing check -- so this is a contract, not a detail.
##   [AC 10 CONVERGES] Repeated calls at a FIXED bearing converge onto it. An easing rig that
##     stalled short would leave the camera permanently mis-framed.
##   [AC 10 WRAPS THE SHORT WAY] A target crossing directly BEHIND the hero (a +3.0 rad to
##     -3.0 rad transition) is eased the SHORT way round, which is what `lerp_angle` buys over a
##     raw lerp. A raw lerp would spin the camera the long way through the whole arena.
##   [AC 12 ZERO IS NO FACT] A `Vector2.ZERO` direction still leaves the rig exactly where it is --
##     4-6's "no fact" semantics, which AC 12 forbids this story from disturbing.
##   [AC 10 SNAP IS AUTHORABLE] At smoothing 1.0 the rig reproduces the shipped 4-6 behaviour
##     verbatim, so the .tres value is a real off switch rather than a scaling of a new behaviour.
##
## Run: godot --headless --path . --script res://test/integration/test_camera_smoothing_live.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

## The authored fraction this fixture drives with -- COVERAGE, not feel, and deliberately NOT the
## value in data/camera_config.tres: a fixture that borrowed the authored number would start
## passing vacuously the day the operator retunes it at the smoke.
const SMOOTHING := 0.25
## Float comparison only. Every expectation below is a closed form evaluated in the same
## arithmetic, so anything looser would be hiding a real discrepancy.
const EPS := 1.0e-5

var _detail := ""


## EVERYTHING RUNS AT FRAME 1, NOT IN `_initialize`. A CameraRig resolves its `@onready` child
## camera in `_ready`, which fires only once the main loop is running -- building the fixture in
## `_initialize` gave a rig whose `apply_config` silently no-opped against a null camera, so the
## smoothing rate was never authored and the "eases" check failed for the wrong reason. Same race
## every other integration file in this folder guards against by waiting a frame.
func _physics_process(_delta: float) -> bool:
	var rig := _make_rig(SMOOTHING)
	var ok := true

	# [AC 10 FIRST SNAPS] -- a rig with no heading takes the first one whole. `direction` (0,-1)
	# is atan2(-0.0, 1.0) == 0.0 rad; use a bearing that is NOT zero so "snapped" cannot be
	# confused with "never written".
	rig.face_lock_direction(Vector2(1.0, 0.0))            # atan2(-1, -0) == -PI/2
	var first := rig.rotation.y
	ok = _check(is_equal_approx(first, -PI * 0.5), "first_heading_not_snapped(%f)" % first) and ok

	# [AC 10 EASES] -- a SECOND, different bearing is approached by exactly SMOOTHING of the gap.
	# Target here is 0.0 rad; from -PI/2 the closed form is lerp_angle(-PI/2, 0, 0.25).
	rig.face_lock_direction(Vector2(0.0, -1.0))           # atan2(-0, 1) == 0.0
	var eased := rig.rotation.y
	var expected := lerp_angle(first, 0.0, SMOOTHING)
	ok = _check(absf(eased - expected) < EPS,
		"did_not_ease_by_the_authored_fraction(got=%f want=%f)" % [eased, expected]) and ok
	# ...and it is genuinely PARTIAL: neither still at the old bearing nor already at the new one.
	ok = _check(absf(angle_difference(eased, 0.0)) > EPS and absf(angle_difference(eased, first)) > EPS,
		"ease_was_not_partial(%f between %f and 0)" % [eased, first]) and ok

	# [AC 12 ZERO IS NO FACT] -- inserted mid-sequence on purpose: a zero must not merely be
	# "ignored", it must not advance the smoothing state either.
	rig.face_lock_direction(Vector2.ZERO)
	ok = _check(is_equal_approx(rig.rotation.y, eased),
		"zero_direction_moved_the_rig(%f -> %f)" % [eased, rig.rotation.y]) and ok

	# [AC 10 CONVERGES] -- held at the same bearing, the yaw arrives rather than stalling short.
	for _i in 200:
		rig.face_lock_direction(Vector2(0.0, -1.0))
	ok = _check(absf(angle_difference(rig.rotation.y, 0.0)) < EPS,
		"did_not_converge(%f)" % rig.rotation.y) and ok

	# [AC 10 WRAPS THE SHORT WAY] -- a target crossing behind the hero. Park the rig just under
	# +PI, then ask for a bearing just over -PI: the gap is a hair across the wrap, so ONE eased
	# step must stay near the wrap rather than travelling back through zero.
	var wrap_rig := _make_rig(SMOOTHING)
	wrap_rig.face_lock_direction(_bearing(3.0))    # snaps to +3.0 rad
	ok = _check(is_equal_approx(wrap_rig.rotation.y, 3.0),
		"wrap_fixture_did_not_snap(%f)" % wrap_rig.rotation.y) and ok
	wrap_rig.face_lock_direction(_bearing(-3.0))   # target -3.0 rad
	var stepped := wrap_rig.rotation.y
	# The SHORT way is +0.283 rad of travel (through PI); the long way is -6.0 rad (through 0).
	# A short-way step therefore stays within a fraction of a radian of where it started; a
	# raw-lerp long-way step would land near +1.5.
	ok = _check(absf(angle_difference(stepped, 3.0)) < 0.1,
		"wrapped_the_long_way_round(%f)" % stepped) and ok

	# [AC 10 SNAP IS AUTHORABLE] -- 1.0 reproduces 4-6 exactly: every call lands whole.
	var snap_rig := _make_rig(1.0)
	snap_rig.face_lock_direction(Vector2(1.0, 0.0))
	snap_rig.face_lock_direction(Vector2(0.0, -1.0))
	ok = _check(is_equal_approx(snap_rig.rotation.y, 0.0),
		"smoothing_1.0_did_not_snap(%f)" % snap_rig.rotation.y) and ok

	print("camera_smoothing: ok=%s%s" % [ok, _detail])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true


## A CameraRig from the real hero scene, added to the tree so its _ready/@onready wiring runs, then
## handed a fixture config. `apply_config` is called a SECOND time here, overriding the authored
## .tres the rig loaded in _ready -- which is exactly the load-once path the rig ships, exercised
## rather than bypassed.
func _make_rig(smoothing: float) -> CameraRig:
	var hero: Node = load("res://src/actors/hero/hero.tscn").instantiate()
	root.add_child(hero)
	var rig: CameraRig = hero.get_node("CameraRig")
	var config := CameraConfig.new()
	config.distance = 6.0
	config.height = 3.0
	config.pitch_degrees = -20.0
	config.lock_yaw_smoothing = smoothing
	rig.apply_config(config)
	rig.rotation.y = 0.0
	return rig


## The planar direction that makes face_lock_direction produce yaw `theta` -- the inverse of its
## own atan2(-x, -y). Stated once here rather than inlined as literals, so a reader can check the
## fixture's bearings against the function under test instead of against arithmetic done by hand.
func _bearing(theta: float) -> Vector2:
	return Vector2(-sin(theta), -cos(theta))


func _check(condition: bool, failure: String) -> bool:
	if not condition:
		_detail += " " + failure + ";"
	return condition
