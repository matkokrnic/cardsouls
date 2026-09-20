extends SceneTree

## Story 6-6b (AC 10/AC 11/AC 12/AC 14): the COLOUR COUNTER's presentation through the REAL runner --
## `main.tscn`, match_runner's per-tick polls, the live `MatchState`, one `_physics_process` (F1).
## `test_defense_reactions_live.gd`'s shape exactly, one story later, and for its stated reason: the
## runner's EDGE READ of the `defense` snapshot key and the clip/prop choices it drives are runtime
## COMPOSITION that no state-level test reaches (`3-0b/R34`).
##
## THE STATE IS POKED, NOT PLAYED, on that file's own precedent: running a real two-pad counter here
## would duplicate test_unblockable_defense.gd's coverage and needs a mode-3 press the headless
## controllers cannot make (`keyboard_controller.gd` hardcodes BASIC). The pokes are the state layer's
## OWN seats -- the window start the cast seat performs, and the knockdown package step 6b runs --
## and everything read afterwards is produced by the runner's own next ticks.
##
## THE SEQUENCE, P2 the counterer, P1 the cross-slot control:
##   1. GREEN  -- the shortest span. The rising edge of the `defense` key plays `counter_throw` on P2
##                and nothing on P1, and a DAGGER prop exists and is flying (AC 11).
##   2. expiry -- the falling edge of the same key: the counter releases the body back to locomotion
##                (`idle`), and the dagger is gone (AC 11: freed on arrival or teardown).
##   3. RED    -- the two-clip SEQUENCE: `counter_jump` first, and `counter_backflip` after the join,
##                with no third clip and no loop (AC 10). No dagger on a non-GREEN counter.
##   4. knockdown mid-counter -- a real transition WINS over a counter in flight: the pose becomes
##                `knockdown` (AC 12's classifier, untouched). The DAGGER is NOT released by the
##                knockdown and this phase does not assert that it is: nothing consumes the counter
##                window any more (AC 5), so a stun leaves it running and the prop keeps flying to
##                its arrival. Its release is pinned on the FALLING edge instead, in phase 2.
##
## Run: godot --headless --path . --script res://test/integration/test_counter_reactions_live.gd

const CHECK_DELAY := 3
const SPAN_BUDGET_FRAMES := 400
const QUIT_DEFER_FRAMES := 30   ## `4-3b/R29`: never quit on the frame of the last read

var _frames := 0
var _runner: Node
var _state: MatchState
var _p1: HeroActor
var _p2: HeroActor
var _phase := "green"
var _phase_frame := 0
var _done_frame := -1
var _failures: Array[String] = []
var _saw_jump := false
var _saw_backflip := false


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _clip(hero: HeroActor) -> StringName:
	return hero.animation_controller.animation_player.current_animation


func _next(phase: String) -> void:
	_phase = phase
	_phase_frame = _frames


## Exactly what `_resolve_defense_cast` does to arm a counter, through the same two fields and the
## same per-colour tick lookup -- never a hand-picked duration.
func _arm_counter(color: int) -> void:
	_state.p2.defense_color = color
	_state.p2.defense_window.start(_state.balance_ticks.counter_busy_ticks_for(color))


func _dagger() -> Node:
	return _runner._counter_daggers[1]


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _done_frame >= 0:
		if _frames - _done_frame >= QUIT_DEFER_FRAMES:
			var ok := _failures.is_empty()
			for f in _failures:
				print("  FAILED: " + f)
			print("RESULT: %s" % ("PASS" if ok else "FAIL"))
			quit(0 if ok else 1)
			return true
		return false
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		_p1 = _runner._p1_hero if _runner != null else null
		_p2 = _runner._p2_hero if _runner != null else null
		if _state == null or _p1 == null or _p2 == null or _state.balance_ticks == null:
			_failures.append("setup: runner/state/heroes/balance missing")
			_done_frame = _frames
		_next("green")
		return false
	var since := _frames - _phase_frame
	match _phase:
		"green":
			if since >= CHECK_DELAY:
				_arm_counter(Enums.CardColor.GREEN)
				_next("green_check")
		"green_check":
			if since >= CHECK_DELAY:
				if _clip(_p2) != &"counter_throw":
					_failures.append("1. GREEN's counter plays counter_throw on the PRESS, off the "
						+ "rising edge of the `defense` key (got '%s')" % _clip(_p2))
				if _clip(_p1) == &"counter_throw":
					_failures.append("1. P2's counter played on P1 -- the poll is cross-wired")
				if _dagger() == null:
					_failures.append("1. GREEN throws a DAGGER prop (AC 11) -- none was spawned")
				elif _dagger().global_position.is_equal_approx(Vector3.ZERO):
					_failures.append("1. ...launched to a real position, not the origin")
				if _runner._counter_daggers[0] != null:
					_failures.append("1. ...and only the counterer's slot gets one")
				_next("expire_wait")
		"expire_wait":
			if not _state.p2.defense_window.is_running:
				_next("expire_check")
			elif since > SPAN_BUDGET_FRAMES:
				_failures.append("2. GREEN's busy span never expired within %d frames"
					% SPAN_BUDGET_FRAMES)
				_done_frame = _frames
		"expire_check":
			if since >= CHECK_DELAY:
				if _clip(_p2) == &"counter_throw":
					_failures.append("2. the FALLING edge releases the body back to locomotion -- "
						+ "the counter clip is still held (got '%s')" % _clip(_p2))
				if _dagger() != null:
					_failures.append("2. ...and the dagger is freed on arrival or teardown (AC 11)")
				_arm_counter(Enums.CardColor.RED)
				_next("red_watch")
		"red_watch":
			# RED is a SEQUENCE: watch every frame of the span rather than sampling one, because the
			# join is the claim and a single sample could land on either side of it.
			if _clip(_p2) == &"counter_jump":
				_saw_jump = true
			elif _clip(_p2) == &"counter_backflip":
				_saw_backflip = true
			elif String(_clip(_p2)).begins_with("counter_"):
				_failures.append("3. RED played an unexpected counter clip '%s'" % _clip(_p2))
				_done_frame = _frames
			if not _state.p2.defense_window.is_running:
				_next("red_check")
			elif since > SPAN_BUDGET_FRAMES:
				_failures.append("3. RED's busy span never expired within %d frames"
					% SPAN_BUDGET_FRAMES)
				_done_frame = _frames
		"red_check":
			if since >= CHECK_DELAY:
				if not _saw_jump:
					_failures.append("3. RED's sequence plays counter_jump first (AC 10)")
				if not _saw_backflip:
					_failures.append("3. ...then counter_backflip after the join (AC 10)")
				if _runner._counter_daggers[1] != null:
					_failures.append("3. ...and a non-GREEN counter throws NO dagger (AC 11)")
				_arm_counter(Enums.CardColor.GREEN)
				_next("interrupt")
		"interrupt":
			if since >= CHECK_DELAY:
				if _clip(_p2) != &"counter_throw":
					_failures.append("4. setup: a GREEN counter is in flight before the knockdown")
				# The knockdown package, exactly as step 6b applies it.
				_state._landing_package_pending[0] = true
				_state._apply_landing_packages()
				_next("interrupt_check")
		"interrupt_check":
			if since >= CHECK_DELAY:
				if _clip(_p2) != &"knockdown":
					_failures.append("4. a real transition WINS over a counter in flight -- the "
						+ "knockdown takes the body (got '%s')" % _clip(_p2))
				_done_frame = _frames
	return false
