extends SceneTree

## Story 1-9 (AC 7) integration test: a roll actually displaces the actor in the intended
## world direction through the FULL chain — KeyboardController -> InputIntent ->
## MatchState step 3 (entry-locked roll_direction) -> _resolve_movement roll override ->
## HeroState.velocity -> HeroActor.drive. Releasing move on the roll press frame also
## exercises the neutral-stick FACING FALLBACK live (facing was established by the
## preceding run), and the stop after the roll pins that displacement comes from the roll,
## not residual input.
##
## Authored values (data/balance/balance_config.tres): roll_distance 3.0 over
## roll_duration_seconds 0.5 -> constant 6.0 u/s for 30 ticks. Tune the .tres, update this.
##
## Run: godot --headless --path . --script res://test/integration/test_roll_displacement.gd

const ROLL_SPEED := 6.0     # 3.0 / 0.5
const ROLL_DISTANCE := 3.0

var _p1: CharacterBody3D
var _x0 := 0.0
var _z0 := 0.0
var _mid_roll_velocity := Vector3.ZERO
var _frames := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())
	_p1 = root.get_node("Main/P1Hero")


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		Input.action_press(&"p1_move_right")  # run right: establishes facing (1, 0)
	if _frames == 15:
		# Neutral-stick roll: move released the same frame the roll is pressed, so the
		# sampled intent has a zero move_dir and the direction comes from facing.
		Input.action_release(&"p1_move_right")
		Input.action_press(&"p1_roll")
		_x0 = _p1.global_position.x
		_z0 = _p1.global_position.z
	if _frames == 17:
		Input.action_release(&"p1_roll")
	if _frames == 30:
		_mid_roll_velocity = _p1.velocity  # mid-roll: state-driven roll override
	if _frames >= 70:
		# Roll pressed ~frame 16, 30 ticks -> ends ~frame 46; no input since, so the
		# displacement has stabilized at the roll distance (+/- one tick of frame slack
		# around the press).
		var dx := _p1.global_position.x - _x0
		var dz := _p1.global_position.z - _z0
		var moved_roll_distance := absf(dx - ROLL_DISTANCE) < 0.35
		var straight := absf(dz) < 0.05
		var roll_velocity_from_state := is_equal_approx(_mid_roll_velocity.x, ROLL_SPEED) \
				and is_zero_approx(_mid_roll_velocity.z)
		var stopped := _p1.velocity.is_zero_approx()
		var ok := moved_roll_distance and straight and roll_velocity_from_state and stopped
		print("roll dx=%f dz=%f mid_roll_velocity=%v (distance=%s, straight=%s, velocity_from_state=%s, stopped=%s)" % [
			dx, dz, _mid_roll_velocity, moved_roll_distance, straight, roll_velocity_from_state, stopped])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
