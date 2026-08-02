extends SceneTree

## Story 3-0b integration (AC 1 + AC 2): deterministic step/pause and the live window countdown,
## driven through the REAL chain in the live scene — Input Map action -> DebugInputReader ->
## match_runner's tick gate -> MatchState -> HeroActor / DebugInstrumentPanel. Nothing here holds
## a MatchState handle; every observation is a scene-tree read (the hero's world position, the
## panel's Label text), the same discipline as every other integration file.
##
##   [AC 1 FREEZE] With p1_move_right held, P1 advances a constant distance per tick. Pressing
##     debug_pause stops it DEAD: the position is bit-identical across ten further frames. That is
##     the whole freeze — advance(), both drive() calls and the contact gather sit in one gated
##     block, so a hero that does not move is a tick that did not run.
##   [AC 1 ONE TICK PER PRESS] One debug_step press advances the hero by EXACTLY one tick's
##     measured displacement, then it freezes again. Holding the key does not auto-fire: the
##     reader reports edges, so the frames between press and release add nothing.
##   [AC 1 N STEPS == N TICKS — the determinism claim] Four steps land the hero at exactly
##     4 x the per-tick displacement measured while running. Stepping is not a different
##     simulation, it is the same tick order run by hand.
##   [AC 1 RESUME] A second debug_pause press resumes free running.
##   [AC 2 LIVE COUNTDOWN] After a real p1_attack press, the panel's per-slot countdown row walks
##     windup -> active -> recovery (+ chain) and back to "--", with the tick numbers falling; the
##     opponent's row stays "--" throughout (the payload is per slot, not global). While PAUSED the
##     row is frozen — the runner does not tick, so it does not poll, so the last stepped tick's
##     values stay on screen, which is what makes the instrument readable at all.
##
## Run: godot --headless --path . --script res://test/integration/test_step_pause.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

const EPS := 1.0e-4      # position comparisons against a measured per-tick displacement
const FROZEN_EPS := 1.0e-6  # "did not move at all" — drive() was never called

var _frames := 0
var _p1: CharacterBody3D
var _slot0: Label
var _slot1: Label

var _x_a := 0.0
var _x_b := 0.0
var _per_tick := 0.0
var _x_paused := 0.0
var _frozen_text := ""
var _x_resume := 0.0

var _nodes_ok := false
var _moved_while_running := false
var _frozen_while_paused := true
var _one_step_is_one_tick := false
var _four_steps_are_four_ticks := false
var _resumed_after_unpause := false
var _countdown_phases: Dictionary = {}
var _countdown_frozen := true
var _opponent_row_stayed_blank := true


func _initialize() -> void:
	root.add_child(load("res://src/main/main.tscn").instantiate())
	_p1 = root.get_node("Main/P1Hero")


func _physics_process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		2:
			var panel := root.get_node_or_null("Main/DebugInstrumentPanel")
			_slot0 = panel.find_child("Slot0Countdown", true, false) if panel != null else null
			_slot1 = panel.find_child("Slot1Countdown", true, false) if panel != null else null
			_nodes_ok = _p1 != null and _slot0 != null and _slot1 != null
		5:
			Input.action_press(&"p1_move_right")  # held until the countdown phase below
		10:
			_x_a = _p1.global_position.x
		20:
			# Per-tick displacement, measured on the FREE-RUNNING match. Everything below is
			# compared against this, so the test never hardcodes move_speed or the tick rate.
			_x_b = _p1.global_position.x
			_per_tick = (_x_b - _x_a) / 10.0
			_moved_while_running = _per_tick > 1.0e-3
		22:
			Input.action_press(&"debug_pause")
		23:
			Input.action_release(&"debug_pause")
		25:
			_x_paused = _p1.global_position.x
		36:
			Input.action_press(&"debug_step")
		37:
			Input.action_release(&"debug_step")
		38:
			_one_step_is_one_tick = absf(
				(_p1.global_position.x - _x_paused) - _per_tick) < EPS
		# Three more steps, each its own press — the press/release pairs deliberately leave idle
		# frames between them, which must contribute nothing.
		43, 46, 49:
			Input.action_press(&"debug_step")
		44, 47, 50:
			Input.action_release(&"debug_step")
		52:
			_four_steps_are_four_ticks = absf(
				(_p1.global_position.x - _x_paused) - 4.0 * _per_tick) < EPS
		54:
			Input.action_press(&"debug_pause")   # resume
		55:
			Input.action_release(&"debug_pause")
		58:
			_x_resume = _p1.global_position.x
		68:
			_resumed_after_unpause = (_p1.global_position.x - _x_resume) > 5.0 * _per_tick
			Input.action_release(&"p1_move_right")
			Input.action_press(&"p1_attack")     # AC 2: give the countdown a real window to show
		69:
			Input.action_release(&"p1_attack")
		96:
			Input.action_press(&"debug_pause")   # freeze mid-window
		97:
			Input.action_release(&"debug_pause")
		99:
			_frozen_text = _slot0.text
	# Between the pause press and the first step, and again after the fourth step, the hero must
	# not move by so much as a float epsilon.
	if (_frames > 25 and _frames < 36) or (_frames > 52 and _frames < 54):
		if absf(_p1.global_position.x - _x_paused) > FROZEN_EPS and _frames < 36:
			_frozen_while_paused = false
	# AC 2: record which attack phases the countdown row actually displayed while free-running.
	if _frames >= 70 and _frames <= 95:
		_countdown_phases[_slot0.text] = true
		if _slot1.text != "P2 windows  --":
			_opponent_row_stayed_blank = false
	# AC 2: and that it stops moving the moment the match is paused.
	if _frames >= 100 and _frames <= 106:
		if _slot0.text != _frozen_text:
			_countdown_frozen = false
	if _frames >= 108:
		var phases: Array = _countdown_phases.keys()
		var saw := func(needle: String) -> bool:
			for t: String in phases:
				if t.contains(needle):
					return true
			return false
		var walked_the_windows: bool = (saw.call("windup") and saw.call("active")
			and saw.call("recovery") and saw.call("chain"))
		var counted_down := _countdown_ticks_fell(phases)
		var froze_non_empty: bool = _frozen_text != "" and _frozen_text != "P1 windows  --"
		var ok := (_nodes_ok and _moved_while_running and _frozen_while_paused
			and _one_step_is_one_tick and _four_steps_are_four_ticks and _resumed_after_unpause
			and walked_the_windows and counted_down and froze_non_empty and _countdown_frozen
			and _opponent_row_stayed_blank)
		print("step/pause: per_tick=%f moved=%s frozen=%s one_step=%s four_steps=%s resumed=%s" % [
			_per_tick, _moved_while_running, _frozen_while_paused, _one_step_is_one_tick,
			_four_steps_are_four_ticks, _resumed_after_unpause])
		print("countdown: walked=%s counted_down=%s froze_non_empty=%s (%s) frozen=%s p2_blank=%s" % [
			walked_the_windows, counted_down, froze_non_empty, _frozen_text, _countdown_frozen,
			_opponent_row_stayed_blank])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false


## The instrument is only useful if the numbers FALL. Pulls every integer out of the recorded
## windup rows and asserts at least three distinct values with a real spread — a row that showed
## a constant number every tick would be a dead readout that still passed the phase walk above.
func _countdown_ticks_fell(rows: Array) -> bool:
	var seen: Dictionary = {}
	for row: String in rows:
		if not row.contains("windup"):
			continue
		for token in row.split(" ", false):
			if token.is_valid_int():
				seen[int(token)] = true
	var values: Array = seen.keys()
	values.sort()
	return values.size() >= 3 and values[-1] - values[0] >= 2
