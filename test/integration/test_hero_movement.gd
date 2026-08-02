extends SceneTree

## Integration test (needs the engine runtime — scene, physics frames, real main loop). Drives
## the actual main scene and asserts the hero moves from simulated input through the FULL chain:
## KeyboardController -> InputIntent -> MatchState.advance -> HeroState.velocity -> HeroActor. This
## is the E0 "hero moves via the keyboard controller" exit criterion, and it also proves the actor's
## velocity comes from STATE (not the intent) — HeroActor.velocity must equal move_speed on the axis.
##
## Run: godot --headless --path . --script res://test/integration/test_hero_movement.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code).

# Live move_speed comes from data/balance/balance_config.tres, injected at match start via
# apply_balance (story 1-3b). Story 3-1 (AC 3) deleted match_runner._MOVE_SPEED, the placeholder
# that injection used to overwrite — the .tres is now the ONLY source. Tune it, update this.
const MOVE_SPEED := 5.0

var _p1: CharacterBody3D
var _x0 := 0.0
var _frames := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())
	_p1 = root.get_node("Main/P1Hero")


func _physics_process(_delta: float) -> bool:
	_frames += 1
	# Press AFTER the tree is live (pressing in _initialize races the input system).
	if _frames == 5:
		Input.action_press(&"p1_move_right")
		_x0 = _p1.global_position.x
	if _frames >= 35:
		Input.action_release(&"p1_move_right")
		var dx := _p1.global_position.x - _x0
		var actor_velocity := _p1.velocity  # set by HeroActor.drive from HeroState.velocity
		var moved_right := dx > 0.1
		var velocity_from_state := is_equal_approx(actor_velocity.x, MOVE_SPEED)
		var ok := moved_right and velocity_from_state
		print("hero dx=%f  actor.velocity=%v  (moved_right=%s, velocity_from_state=%s)" % [
			dx, actor_velocity, moved_right, velocity_from_state])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
