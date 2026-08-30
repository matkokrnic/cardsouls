extends SceneTree

## Story 1-9 (AC 7) integration test: a roll actually displaces the actor in the intended
## world direction through the FULL chain — KeyboardController -> InputIntent ->
## MatchState step 3 (entry-locked roll_direction) -> _resolve_movement roll override ->
## HeroState.velocity -> HeroActor.drive. Releasing move on the roll press frame also
## exercises the neutral-stick FALLBACK live, and the stop after the roll pins that displacement
## comes from the roll, not residual input.
##
## STORY 4-6, OPERATOR RULING `4-6/R7`: THIS FILE IS NOW THE LIVE PROOF OF THE BACKSTEP. The
## neutral-stick fallback no longer rolls ALONG facing; it rolls AWAY from the locked target -- the
## DS/ER locked-on neutral-dodge convention, delivered as the ordinary roll (same i-frames, same
## speed, same distance). So the assertions become basis-free and direction-checked against the
## live lock rather than against the world +X axis the identity basis used to hand them:
##   * the DISTANCE and SPEED are magnitudes, unchanged by the ruling and unchanged by the live
##     camera basis (`4-6` AC 4 cause (b)) -- which is exactly why they are the right things to
##     pin now that a pressed direction no longer maps to a world axis;
##   * STRAIGHT is displacement parallel to the mid-roll velocity, which is what "the entry-locked
##     direction is held for the whole roll" actually claims;
##   * and the new one, AWAY: the displacement points AWAY from the locked target, which fails if
##     the ruling's sign is dropped.
##
## Authored values (data/balance/balance_config.tres): roll_distance 3.0 over
## roll_duration_seconds 0.5 -> constant 6.0 u/s for 30 ticks. Tune the .tres, update this.
##
## Run: godot --headless --path . --script res://test/integration/test_roll_displacement.gd

const ROLL_SPEED := 6.0     # 3.0 / 0.5
const ROLL_DISTANCE := 3.0

var _p1: CharacterBody3D
## Story 4-6: the locked target, read live so the backstep assertion below compares against the
## direction the runner itself pushed rather than a literal.
var _p2: CharacterBody3D
var _x0 := 0.0
var _z0 := 0.0
var _mid_roll_velocity := Vector3.ZERO
var _frames := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())
	_p1 = root.get_node("Main/P1Hero")
	_p2 = root.get_node("Main/P2Hero")


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		Input.action_press(&"p1_move_right")  # run, so the roll follows a live match rather than a standing start
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
		var moved := Vector2(dx, dz)
		var moved_roll_distance := absf(moved.length() - ROLL_DISTANCE) < 0.35
		# STRAIGHT means "held the entry-locked direction", so it is measured against the mid-roll
		# velocity rather than against a world axis: the displacement must be parallel to it.
		var roll_heading := Vector2(_mid_roll_velocity.x, _mid_roll_velocity.z)
		var straight := not roll_heading.is_zero_approx() \
				and moved.normalized().dot(roll_heading.normalized()) > 0.999
		var roll_velocity_from_state := is_equal_approx(_mid_roll_velocity.length(), ROLL_SPEED) \
				and is_zero_approx(_mid_roll_velocity.y)
		var stopped := _p1.velocity.is_zero_approx()
		# `4-6/R7`: the backstep. P1's default lock is the opposing hero, so the roll must carry
		# the hero AWAY from it -- a dropped sign lands this at +1 instead of -1.
		var to_target := _p2.global_position - _p1.global_position
		var away := moved.normalized().dot(Vector2(to_target.x, to_target.z).normalized()) < -0.99
		var ok := moved_roll_distance and straight and roll_velocity_from_state and stopped and away
		print(("roll dx=%f dz=%f mid_roll_velocity=%v (distance=%s, straight=%s, "
				+ "velocity_from_state=%s, stopped=%s, away_from_lock=%s)") % [
			dx, dz, _mid_roll_velocity, moved_roll_distance, straight, roll_velocity_from_state,
			stopped, away])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
