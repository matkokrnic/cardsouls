extends SceneTree

## Review fix pass (4-3b, F3a): `MatchRunner._probe_counter` is the RUNNER-LOCAL reach-probe
## cadence counter (`match_runner.gd`). It was not cleared by the debug reset, so after a reset the
## probe cadence carried an ARBITRARY PHASE left over from the previous run instead of restarting at
## tick zero. Fixed by resetting it to 0 in `_relay_round_started` -- the one relay `round_started`
## fires only FROM a debug reset -- alongside the actor-freeing it already does there.
##
## MEASURED DIRECTLY ON THE RUNNER'S OWN FIELD (`_runner._probe_counter`), the same "no real privacy,
## underscore is convention" access `test_contact_pipeline.gd` and `test_unit_attack_live.gd` already
## rely on to reach `_match_state` -- there is no public seam for a runner-local debug counter and
## none is warranted for this.
##
## NON-VACUOUS BY CONSTRUCTION: the counter is left to grow for several ticks BEFORE the reset (so
## `_before` is asserted nonzero — a build where the counter never moves at all would otherwise pass
## trivially), and the assertion after reset requires it to have DROPPED, not merely to have kept
## growing — a mutation that deletes the reset line leaves the counter monotonically increasing and
## fails here.
##
## Run: godot --headless --path . --script res://test/integration/test_probe_counter_reset_live.gd

const DEADLINE := 200
const BEFORE_RESET_FRAME := 10
const PRESS_FRAME := 11
const RELEASE_FRAME := 13
const CHECK_FRAME := 16

var _frames := 0
var _runner: Node
var _before := -1
var _after := -1
var _failures: Array[String] = []


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures.append(label)


func _finish() -> void:
	print("probe_counter_reset: before=%d after=%d frames=%d" % [_before, _after, _frames])
	for f in _failures:
		print("FAILED: " + f)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames >= DEADLINE:
		_failures.append("deadline reached before the check frame")
		_finish()
		return false

	if _frames == 1:
		_runner = root.get_node("Main")

	if _frames == BEFORE_RESET_FRAME:
		_before = int(_runner._probe_counter)

	if _frames == PRESS_FRAME:
		Input.action_press(&"p1_debug_reset")
	if _frames == RELEASE_FRAME:
		Input.action_release(&"p1_debug_reset")

	if _frames == CHECK_FRAME:
		_after = int(_runner._probe_counter)
		_check(_before > 0,
			"sanity: the counter had already advanced past zero before the reset (frame %d, was %d)"
					% [BEFORE_RESET_FRAME, _before])
		_check(_after < _before,
			"the debug reset must clear the probe counter -- it read %d before the reset and %d a "
					% [_before, _after]
			+ "few ticks after, which is not a drop (an un-reset counter only ever grows)")
		_check(_after <= (CHECK_FRAME - RELEASE_FRAME) + 1,
			("after the reset the counter should read close to zero (at most the %d ticks since the "
			+ "reset relay ran), not a value still carrying the pre-reset phase — got %d")
					% [CHECK_FRAME - RELEASE_FRAME + 1, _after])
		_finish()
		return false

	return false
