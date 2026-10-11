extends SceneTree

## Story 7-3, feel pass 2 (defect E, an OUTSIDE-SCOPE fix: the path is identical at `aff32e4`): A SHOT IN
## FLIGHT WHEN A HERO DIES AND THE ROUND IS RESET. Seen at the operator's re-smoke:
##
##   ERROR: INVARIANT VIOLATED: projectile board index 1 is out of range (board holds 0)
##     effect_id_at <- _free_dead_projectile_actors <- _physics_process
##
## THE CAUSE. The debug reset clears each player's `ProjectileBoard` INSIDE `advance()`; the runner frees
## the matching actors off the `round_started` relay, which runs at the signal drain -- the LAST step of
## the frame. Between the two, the post-`advance()` poll walks its index-aligned actor array and asks
## the board about every record that is no longer alive, and the board no longer holds them.
##
## THE TEST drives the real thing: a Combat totem fires at the enemy hero, the hero is killed while the
## shot is in the air (the round-over freeze holds the shot alive), and the reset is pressed. It listens
## to the engine's own error stream, so the failing condition is the defect itself and not a restatement
## of the fix: before the fix the reset tick logs the violated invariant; after it, nothing.
##
## Run: godot --headless --path . --script res://test/integration/test_projectile_reset_live.gd

const TOTEM_KIND := &"combat_totem"
const DEADLINE := 1500
## How far from the enemy hero the totem is stood: inside its firing range, far enough that the shot
## is still in the air when the hero dies.
const TOTEM_DISTANCE := 7.0


## Counts what the engine logs as an error while the test runs.
class ErrorCounter extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		errors.append("%s %s (%s)" % [code, rationale, function])


var _frames := 0
var _stage := 0
var _stage_frame := 0
var _runner: Node
var _state: MatchState
var _counter := ErrorCounter.new()
var _shot: Node = null
var _shots_at_reset := 0
var _failures: Array[String] = []


func _initialize() -> void:
	OS.add_logger(_counter)
	root.add_child((load("res://src/main/main.tscn") as PackedScene).instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames >= DEADLINE:
		return _finish("deadline reached at stage %d" % _stage)
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _state == null:
			return _finish("no runner or no match state")
		return false
	var since := _frames - _stage_frame
	match _stage:
		0:  # a Combat totem on P1's board
			if _frames == 3:
				var kind_index := _state.balance.kind_index_of(TOTEM_KIND)
				var kind := _state.balance.kind_at(kind_index)
				if kind == null:
					return _finish("authored data carries no `combat_totem` kind")
				_state.p1.units.add(kind.max_hp, kind_index)
				_next(1)
		1:  # stood inside its firing range of the enemy hero
			if since == 3:
				var actors: Array = _runner._unit_actors[0]
				if actors.is_empty() or not is_instance_valid(actors[0]):
					return _finish("the totem was not spawned")
				var enemy: Vector3 = _runner._p2_hero.global_position
				(actors[0] as Node3D).global_position = Vector3(enemy.x, 0.0, enemy.z + TOTEM_DISTANCE)
				_next(2)
		2:  # its first shot is in the air: the enemy hero dies
			_shot = _live_shot()
			if _shot != null:
				_state.p2.hero.take_damage(_state.p2.hero.get_hp() + 1000.0)
				_next(3)
		3:  # the round is over and the shot is still in flight: reset
			if bool(_state.to_snapshot().get("round_over", false)):
				_shots_at_reset = _state.p1.projectiles.size()
				_check(_live_shot() != null,
						"fixture: no shot was still in flight when the round ended (vacuous)")
				_check(_counter.errors.is_empty(), "fixture: errors before the reset: %s" % [_counter.errors])
				Input.action_press(&"p1_debug_reset")
				_next(4)
			elif since > 120:
				return _finish("fixture: the kill never ended the round")
		4:
			if since == 2:
				Input.action_release(&"p1_debug_reset")
			elif since == 6:
				_check(not bool(_state.to_snapshot().get("round_over", true)),
						"fixture: the reset did not start a new round")
				_check(_counter.errors.is_empty(),
						"the reset with a shot in flight logged %d error(s): %s"
								% [_counter.errors.size(), _counter.errors])
				_check(not is_instance_valid(_shot) or _shot.is_queued_for_deletion(),
						"the shot that was in flight at the reset still has its actor")
				for slot in 2:
					var board: ProjectileBoard = (_state.p1 if slot == 0 else _state.p2).projectiles
					var shots: Array = _runner._projectile_actors[slot]
					_check(shots.size() == board.size(),
							"slot %d holds %d projectile actors for a board of %d after the reset"
									% [slot, shots.size(), board.size()])
				_next(5)
		5:  # the round-end cue plays out: a stream still playing at exit is a resource in use
			if not _any_cue_playing() or since > 600:
				return _finish("")
	return false


func _any_cue_playing() -> bool:
	for player in root.find_children("*", "AudioStreamPlayer", true, false):
		if (player as AudioStreamPlayer).playing:
			return true
	for player in root.find_children("*", "AudioStreamPlayer3D", true, false):
		if (player as AudioStreamPlayer3D).playing:
			return true
	return false


## P1's first live shot's actor, or null while none is in the air.
func _live_shot() -> Node:
	var board := _state.p1.projectiles
	var shots: Array = _runner._projectile_actors[0]
	for index in shots.size():
		if board.is_alive_at(index) and is_instance_valid(shots[index]):
			return shots[index]
	return null


func _next(stage: int) -> void:
	_stage = stage
	_stage_frame = _frames


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _finish(error: String) -> bool:
	if error != "":
		_failures.append(error)
	Input.action_release(&"p1_debug_reset")
	OS.remove_logger(_counter)
	for f in _failures:
		print("  FAILED: " + f)
	print("projectile_reset_live: %d shot record(s) on P1's board at the reset, %d error(s) logged, %d frames"
			% [_shots_at_reset, _counter.errors.size(), _frames])
	_counter = null
	_shot = null
	# The totem's shot sound is still playing; a playing stream is a resource in use at exit.
	if _runner != null and _runner._effects != null:
		_runner._effects.stop_all_sounds()
	OS.delay_msec(100)
	var ok := _failures.is_empty()
	var main := root.get_node_or_null("Main")
	if main != null:
		main.free()
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false
