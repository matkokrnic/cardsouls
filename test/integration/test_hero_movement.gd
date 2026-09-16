extends SceneTree

## Integration test (needs the engine runtime — scene, physics frames, real main loop). Drives
## the actual main scene and asserts the hero moves from simulated input through the FULL chain:
## KeyboardController -> InputIntent -> MatchState.advance -> HeroState.velocity -> HeroActor. This
## is the E0 "hero moves via the keyboard controller" exit criterion, and it also proves the actor's
## velocity comes from STATE (not the intent) — HeroActor.velocity must have move_speed's MAGNITUDE,
## which a raw intent (a unit vector) cannot produce on its own.
##
## STORY 4-6 (AC 1/AC 4 cause (b)) GENERALISED THE SECOND CLAIM FROM AN AXIS TO A MAGNITUDE, and
## the change is this story's live consequence landing on an existing fixture rather than a
## weakening. The rig now yaws every tick to frame the locked target, so the pushed camera basis is
## non-identity in live play for the first time and a pressed direction no longer maps to a world
## AXIS -- it maps to that axis ROTATED by the lock yaw. `velocity.x == move_speed` was never the
## claim; it was the identity-basis shorthand for it. The magnitude is basis-invariant and is the
## thing that was always being asserted: state multiplies a unit intent by move_speed, and nothing
## else in the chain can.
##
## Run: godot --headless --path . --script res://test/integration/test_hero_movement.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code).

# Live move_speed comes from data/balance/balance_config.tres, injected at match start via
# apply_balance (story 1-3b). Story 3-1 (AC 3) deleted match_runner._MOVE_SPEED, the placeholder
# that injection used to overwrite — the .tres is now the ONLY source.
# Story 6-7b (AC 2): READ LIVE off the config the runner APPLIED, never a pinned literal -- the
# `test_unit_approach_live.gd` `walk_speed` precedent. 6-7b's own retune (5.0 -> 6.0) is the edit a
# literal here would have silently broken; a future tempo retune is now a one-line .tres edit.
var _move_speed := 0.0

var _p1: CharacterBody3D
var _x0 := 0.0
var _z0 := 0.0
var _frames := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())
	_p1 = root.get_node("Main/P1Hero")


func _physics_process(_delta: float) -> bool:
	_frames += 1
	# Press AFTER the tree is live (pressing in _initialize races the input system).
	if _frames == 5:
		var runner: Node = root.get_node_or_null("Main")
		var state: MatchState = runner._match_state if runner != null else null
		if state == null or state.balance == null or state.balance.move_speed <= 0.0:
			print("no applied balance with a positive move_speed (runner=%s state=%s)" % [runner, state])
			print("RESULT: FAIL")
			quit(1)
			return false
		_move_speed = state.balance.move_speed
		Input.action_press(&"p1_move_right")
		# Story 6-7 (AC 1/AC 6): move_speed is the RUN speed as of this story -- press the run key
		# too (Task 6(d)), matching the delivered default two-keyboard config, or the hero would
		# move at the authored walk_speed instead and this assertion would fail.
		Input.action_press(&"p1_run")
		_x0 = _p1.global_position.x
		_z0 = _p1.global_position.z
	if _frames >= 35:
		Input.action_release(&"p1_move_right")
		Input.action_release(&"p1_run")
		var dx := _p1.global_position.x - _x0
		var actor_velocity := _p1.velocity  # set by HeroActor.drive from HeroState.velocity
		var travelled := Vector2(dx, _p1.global_position.z - _z0).length()
		var moved := travelled > 0.1
		var velocity_from_state := is_equal_approx(actor_velocity.length(), _move_speed)
		# The velocity is PLANAR: the yaw-only basis flattening can never tilt movement, which is
		# the 1-2 AC 3 property and is worth keeping asserted now that the basis is live.
		var planar := is_zero_approx(actor_velocity.y)
		var ok := moved and velocity_from_state and planar
		print("hero travelled=%f  actor.velocity=%v  authored move_speed=%f  (moved=%s, velocity_from_state=%s, planar=%s)" % [
			travelled, actor_velocity, _move_speed, moved, velocity_from_state, planar])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
