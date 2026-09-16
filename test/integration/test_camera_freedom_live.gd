extends SceneTree

## Story 6-8 (camera freedom) integration test: the unlocked state, the unlocked camera and 360
## cycling, driven through the REAL chain in the live scene -- keyboard Input Map actions ->
## KeyboardController -> the runner's step-1c rig seat and pre-advance retarget resolution ->
## MatchState's lock seat -> the rig ROOT's basis and the HUD marker. The shipped default slot kinds
## are KEYBOARD/KEYBOARD, so every press below is a real binding from the ratified table (AC 23).
##
## Lock STATE is read through `_runner._match_state`, the `test_lock_marker_live.gd` /
## `test_summon_actor_live.gd` precedent; a unit is staged on the board the same way.
##
##   [G1 SIGN]      `CameraRig.rotate_free_yaw(+1)` turns camera-forward TOWARD the rig's previous
##                  screen-right, by exactly the authored per-tick rate (AC 7/AC 8). A standalone rig.
##   [OQ5 MAPPING]  For a rig snapped onto lock direction d, `LockOnResolver.bearing_of` of the rig's
##                  screen-right is bearing_of(d) + PI/2 -- a sweep toward screen-right is a sweep of
##                  increasing bearing, the convention AC 15's clockwise claim rests on. Checked at
##                  four headings, against the real node basis, not the derivation in the resolver.
##   [AC 1 HERO->UNLOCK] P1 starts locked on P2's hero; `p1_lock` unlocks.
##   [AC 6]         P1's marker hides while unlocked.
##   [AC 9]         Unlocking keeps the rig's heading.
##   [AC 11]        `p1_cycle_right` while unlocked changes nothing.
##   [AC 7/AC 8]    Holding `p1_camera_right` turns P1's view RIGHT at the authored rate.
##   [AC 10]        Released, the heading holds -- no recenter.
##   [AC 1 UNLOCK->HERO / AC 12] `p1_lock` relocks P2's hero, and the rig swings back onto it.
##   [AC 13]        With a minion staged BEHIND P1's camera, `p1_cycle_right` reaches it through the
##                  real 360 gather (4-6a's on-screen filter would have found nothing).
##   [AC 1 UNIT->HERO] `p1_lock` on a minion lock returns to P2's hero.
##   [AC 23 P2]     P2's `Numpad 5` unlocks P2 and `Numpad 4` turns P2's view LEFT.
##   [DECISION A]   The hero roots never rotate.
##
## Run: godot --headless --path . --script res://test/integration/test_camera_freedom_live.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

const EPS := 1.0e-4
## Framing tolerance after the relock swing, the `test_lock_on_live.gd` band.
const YAW_EPS := 0.05
## `data/balance/balance_config.tres` kind index 0 (melee minion), the lock-marker fixture's choice.
const MINION_KIND_INDEX := 0
const MINION_MAX_HP := 10.0
const HERO_INDEX := TargetingService.HERO_INDEX

var _runner: Node
var _state: MatchState
var _p1: Node3D
var _p2: Node3D
var _p1_rig: CameraRig
var _p2_rig: CameraRig
var _p1_view_cam: Camera3D
var _p1_marker: Control
var _rate := 0.0

var _frames := 0
var _ok := true
var _detail := ""
var _yaw0 := 0.0
var _yaw_a := 0.0
var _yaw_b := 0.0
var _p2_yaw := 0.0
var _minion_was_behind := false


func _initialize() -> void:
	root.add_child(load("res://src/main/main.tscn").instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames > 1 and _p1 != null:
		if not _p1.transform.basis.is_equal_approx(Basis.IDENTITY) \
				or not _p2.transform.basis.is_equal_approx(Basis.IDENTITY):
			_fail("hero_root_rotated(frame=%d)" % _frames)
	match _frames:
		1:
			# In a physics frame rather than _initialize, so the standalone rig's @onready wiring has run.
			_check_rig_sign_and_bearing_mapping()
		5:
			_runner = root.get_node("Main")
			_state = _runner._match_state
			_p1 = root.get_node("Main/P1Hero")
			_p2 = root.get_node("Main/P2Hero")
			_p1_rig = root.get_node("Main/P1Hero/CameraRig")
			_p2_rig = root.get_node("Main/P2Hero/CameraRig")
			_p1_view_cam = root.get_node("Main/P1View/P1Viewport/P1Camera")
			_p1_marker = root.get_node("Main/P1View/P1Viewport/HudRoot/LockMarker")
			_rate = deg_to_rad((load("res://data/camera_config.tres") as CameraConfig).free_yaw_degrees_per_tick)
			_expect(_lock(_state.p1) == [1, HERO_INDEX], "p1_not_locked_at_start(%s)" % str(_lock(_state.p1)))
			_expect(_rate > 0.0, "authored_free_yaw_rate_not_positive")
			_yaw0 = _p1_rig.rotation.y
			Input.action_press(&"p1_lock")
		6:
			Input.action_release(&"p1_lock")
		8:
			_expect(_lock(_state.p1) == [PlayerState.UNLOCKED_SLOT, HERO_INDEX],
				"AC1_hero_lock_click_did_not_unlock(%s)" % str(_lock(_state.p1)))
			_expect(not _p1_marker.visible, "AC6_marker_visible_while_unlocked")
			_expect(absf(angle_difference(_p1_rig.rotation.y, _yaw0)) < EPS,
				"AC9_unlock_moved_heading(%f->%f)" % [_yaw0, _p1_rig.rotation.y])
			Input.action_press(&"p1_cycle_right")
		9:
			Input.action_release(&"p1_cycle_right")
		11:
			_expect(_lock(_state.p1) == [PlayerState.UNLOCKED_SLOT, HERO_INDEX],
				"AC11_flick_while_unlocked_changed_lock(%s)" % str(_lock(_state.p1)))
			_yaw_a = _p1_rig.rotation.y
			Input.action_press(&"p1_camera_right")
		21:
			Input.action_release(&"p1_camera_right")
		23:
			_yaw_b = _p1_rig.rotation.y
			var turned := angle_difference(_yaw_a, _yaw_b)   # (b - a), wrapped
			_expect(_turned_right(_yaw_a, _yaw_b), "AC7_camera_right_did_not_turn_view_right(%f->%f)" % [_yaw_a, _yaw_b])
			# Ten frames held; the exact count of sampled ticks depends on callback order within a
			# frame, so one tick either side is allowed -- a wrong RATE is off by far more.
			var ticks := absf(turned) / _rate
			_expect(ticks > 8.5 and ticks < 11.5, "AC8_rotation_not_at_authored_rate(ticks=%f)" % ticks)
		40:
			_expect(absf(angle_difference(_p1_rig.rotation.y, _yaw_b)) < EPS,
				"AC10_heading_drifted_after_release(%f->%f)" % [_yaw_b, _p1_rig.rotation.y])
			Input.action_press(&"p1_lock")
		41:
			Input.action_release(&"p1_lock")
		43:
			_expect(_lock(_state.p1) == [1, HERO_INDEX], "AC1_unlocked_click_did_not_lock_hero(%s)" % str(_lock(_state.p1)))
			_expect(_p1_marker.visible, "marker_did_not_return_on_relock")
		80:
			_expect(_framed(_p1_rig, _p1, _p2), "AC12_rig_did_not_swing_back_onto_the_target")
			_state.p2.units.add(MINION_MAX_HP, MINION_KIND_INDEX)
		85:
			var actors: Array = _runner._unit_actors[1]
			var minion: Node3D = actors[0] if actors.size() > 0 else null
			if minion == null or not is_instance_valid(minion):
				_fail("minion_never_spawned")
			else:
				# BEHIND P1's CAMERA, not merely behind the hero: the camera sits `distance` (6 m) back
				# and 3 m up, so a ground point 9 m behind P1 is behind its near plane.
				var away := (_p1.global_position - _p2.global_position)
				away.y = 0.0
				minion.global_position = _p1.global_position + away.normalized() * 9.0
				_minion_was_behind = _p1_view_cam.is_position_behind(minion.global_position)
			Input.action_press(&"p1_cycle_right")
		86:
			Input.action_release(&"p1_cycle_right")
		88:
			_expect(_minion_was_behind, "fixture_minion_was_not_behind_the_camera")
			_expect(_lock(_state.p1) == [1, 0], "AC13_behind_target_not_reached(%s)" % str(_lock(_state.p1)))
			Input.action_press(&"p1_lock")
		89:
			Input.action_release(&"p1_lock")
		91:
			_expect(_lock(_state.p1) == [1, HERO_INDEX], "AC1_unit_lock_click_did_not_return_to_hero(%s)" % str(_lock(_state.p1)))
			Input.action_press(&"p2_lock")
		92:
			Input.action_release(&"p2_lock")
		94:
			_expect(_lock(_state.p2) == [PlayerState.UNLOCKED_SLOT, HERO_INDEX],
				"AC23_p2_lock_key_did_not_unlock(%s)" % str(_lock(_state.p2)))
			_p2_yaw = _p2_rig.rotation.y
			Input.action_press(&"p2_camera_left")
		99:
			Input.action_release(&"p2_camera_left")
		101:
			_expect(_turned_right(_p2_rig.rotation.y, _p2_yaw),
				"AC23_p2_camera_left_did_not_turn_view_left(%f->%f)" % [_p2_yaw, _p2_rig.rotation.y])
			print("camera_freedom_live: ok=%s%s" % [_ok, _detail])
			print("RESULT: %s" % ("PASS" if _ok else "FAIL"))
			quit(0 if _ok else 1)
	return false


## [G1 SIGN] and [OQ5 MAPPING] on a standalone rig from the real hero scene, the
## `test_camera_smoothing_live.gd` `_make_rig` shape, freed before the match scene is added.
func _check_rig_sign_and_bearing_mapping() -> void:
	var hero: Node = load("res://src/actors/hero/hero.tscn").instantiate()
	root.add_child(hero)
	var rig: CameraRig = hero.get_node("CameraRig")
	var config := CameraConfig.new()
	config.distance = 6.0
	config.height = 3.0
	config.pitch_degrees = -20.0
	config.lock_yaw_smoothing = 1.0
	config.free_yaw_degrees_per_tick = 4.0
	rig.apply_config(config)
	for d: Vector2 in [Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(-0.6, 0.8), Vector2(-1.0, 0.0)]:
		rig.face_lock_direction(d)
		var right := Vector2(rig.basis.x.x, rig.basis.x.z)
		var forward := Vector2(-rig.basis.z.x, -rig.basis.z.z)
		_expect(forward.is_equal_approx(d), "OQ5_rig_not_looking_along_%s(%s)" % [d, forward])
		var sweep := fposmod(LockOnResolver.bearing_of(right) - LockOnResolver.bearing_of(d), TAU)
		_expect(absf(sweep - PI / 2.0) < EPS,
			"OQ5_screen_right_is_not_plus_quarter_bearing_at_%s(%f)" % [d, sweep])
		var before := rig.rotation.y
		rig.rotate_free_yaw(1.0)
		var turned_forward := Vector2(-rig.basis.z.x, -rig.basis.z.z)
		_expect(turned_forward.dot(right) > 0.0, "G1_plus_axis_did_not_turn_toward_screen_right_at_%s" % d)
		_expect(absf(absf(angle_difference(before, rig.rotation.y)) - deg_to_rad(4.0)) < EPS,
			"AC8_one_tick_is_not_the_authored_rate_at_%s" % d)
		rig.rotation.y = before
		rig.rotate_free_yaw(0.0)
		_expect(is_equal_approx(rig.rotation.y, before), "AC10_zero_axis_wrote_the_rig")
	hero.queue_free()


## True when the view turned RIGHT going from yaw `from` to yaw `to`: the new camera-forward has a
## positive component along the OLD screen-right.
func _turned_right(from: float, to: float) -> bool:
	var old_right := Vector2(cos(from), -sin(from))
	var new_forward := Vector2(-sin(to), -cos(to))
	return new_forward.dot(old_right) > 0.0 and absf(angle_difference(from, to)) > EPS


func _framed(rig: Node3D, hero: Node3D, target: Node3D) -> bool:
	var forward := Vector2(-sin(rig.rotation.y), -cos(rig.rotation.y))
	var to_target := target.global_position - hero.global_position
	var off := absf(forward.angle_to(Vector2(to_target.x, to_target.z).normalized()))
	if off > YAW_EPS:
		_detail += " not_framed(off=%f);" % off
	return off <= YAW_EPS


func _lock(player: PlayerState) -> Array:
	return [player.lock_target_slot, player.lock_target_index]


func _expect(condition: bool, failure: String) -> void:
	if not condition:
		_fail(failure)


func _fail(failure: String) -> void:
	_ok = false
	_detail += " " + failure + ";"
