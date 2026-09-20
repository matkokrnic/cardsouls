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
## POST-REVIEW FIX PASS (findings P1/P2/P3, rulings R-P1/P3 and R-P2) adds the INTERRUPTED shapes --
## the half of AC 2's "busy for the whole counter presentation" that phases 1-4 never reached, because
## every one of them runs with the hero standing IDLE for the entire span:
##   5. BLOCK-HELD CAST -- the cast drops the block, so the queued `BLOCKING -> IDLE` drains in the
##                SAME frame as the rising edge, AFTER the poll. The counter must survive it.
##   6. MID-SWING CAST -- while the swing owns the body its own clip plays (the span ticks anyway),
##                and the counter RESUMES when the swing ends inside the span.
##   7. HIT MID-COUNTER -- an ordinary hit plays no `hit_react` over a counter.
##   8. RE-CAST WITH NO FALLING EDGE -- a second press while the key still reads running is a NEW
##                press: the old presentation ends (its dagger freed) and the new colour starts.
##
## POST-SMOKE FIX PASS (R-S1/R-S5) adds the two presentation facts the operator's live smoke asked
## for, both pinned where the counter they belong to already runs:
##   * RED PASSES THROUGH THE ATTACKER'S BODY for its span and gets its collision back at the end
##     (phase 3), so the out-and-back travel the state layer writes actually happens instead of
##     stopping on a collision box -- and GREEN does NOT (phase 1), because the ruling is RED-only;
##   * THE DAGGER IS DRAWN AT `DaggerActor.MODEL_SCALE` and that scale is an ENLARGEMENT (phase 1).
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
## Story 6-6b POST-SMOKE (R-S1): whether RED's span was ever seen passing through the attacker's
## body. Sampled every frame of the span rather than once, for `_saw_jump`'s reason.
var _saw_pass_through := false


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


## Story 6-6b POST-SMOKE (R-S1): does the counterer's body currently IGNORE the attacker's collider?
## Read off the engine's own exception list, which is what `move_and_slide()` consults -- never off
## the runner's bookkeeping, so the test cannot pass on an intention the physics never received.
func _passes_through() -> bool:
	return _p2.get_collision_exceptions().has(_p1)


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
				# R-S5: the prop is DRAWN BIGGER than the model authors it. Two claims, because one
				# alone is vacuous: the instanced model carries the constant (the wiring), and the
				# constant is an ENLARGEMENT (the ruling -- a dagger at authored scale is what the
				# smoke could not see cross the gap).
				if _dagger() != null:
					var model: Node3D = _dagger().get_child(0)
					if not is_equal_approx(model.scale.x, DaggerActor.MODEL_SCALE):
						_failures.append(("1. ...the model carries MODEL_SCALE (R-S5): got %.3f, "
							+ "want %.3f") % [model.scale.x, DaggerActor.MODEL_SCALE])
					if DaggerActor.MODEL_SCALE <= 1.0:
						_failures.append("1. ...and MODEL_SCALE is an ENLARGEMENT (R-S5): got %.3f"
							% DaggerActor.MODEL_SCALE)
				# R-S1: GREEN keeps its collision -- only RED steps through the attacker.
				if _passes_through():
					_failures.append("1. ...and a GREEN counter does NOT pass through the attacker's "
						+ "body (R-S1 is RED only)")
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
			# R-S1: the pass-through is armed for the WHOLE span, so sampling it every frame here
			# samples it while the counter is actually travelling.
			if _passes_through():
				_saw_pass_through = true
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
				if not _saw_pass_through:
					_failures.append("3. ...and RED's counter passes THROUGH the attacker's body for "
						+ "the span, so the travel completes (R-S1)")
				if _passes_through():
					_failures.append("3. ...and gets its collision back on the falling edge -- the "
						+ "pass-through is the SPAN's, not the match's (R-S1)")
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
				_next("settle")
		"settle":
			# Back to a clean slate before the interrupted shapes: the knockdown's stun, its get-up
			# lock and the GREEN window it was countering with all have to be gone, or phase 5 would
			# be measuring the tail of phase 4.
			if _state.p2.hero.action_state == HeroState.ActionState.IDLE \
					and not _state.p2.hero.is_getting_up() \
					and not _state.p2.defense_window.is_running:
				_next("block_cast")
			elif since > SPAN_BUDGET_FRAMES:
				_failures.append("5. setup: the knockdown never cleared within %d frames"
					% SPAN_BUDGET_FRAMES)
				_done_frame = _frames
		"block_cast":
			if since >= CHECK_DELAY:
				# The cast-from-BLOCKING shape, in the state layer's own two moves and in the ONE
				# frame the real cast makes them: the block is engaged and the window armed before
				# this frame's tick, so `_resolve_actions`' BLOCKING arm drops the block (nothing
				# holds it) INSIDE the same advance() whose poll takes the rising edge -- and the
				# queued `BLOCKING -> IDLE` reaches the controller only at the drain, after the
				# counter has started. That order is the whole of finding P3.
				_state.p2.hero.set_action_state(HeroState.ActionState.BLOCKING)
				_arm_counter(Enums.CardColor.GREEN)
				_next("block_cast_check")
		"block_cast_check":
			if since >= CHECK_DELAY:
				if _clip(_p2) != &"counter_throw":
					_failures.append("5. a counter cast from BLOCKING owns the body for its span -- "
						+ "the block drop must not kill it (got '%s')" % _clip(_p2))
				if not _state.p2.defense_window.is_running:
					_failures.append("5. setup: the busy span ended before the check")
				_next("swing_settle")
		"swing_settle":
			if not _state.p2.defense_window.is_running:
				_next("swing_cast")
			elif since > SPAN_BUDGET_FRAMES:
				_failures.append("6. setup: GREEN's span never expired within %d frames"
					% SPAN_BUDGET_FRAMES)
				_done_frame = _frames
		"swing_cast":
			if since >= CHECK_DELAY:
				# A REAL swing through the state layer's own entry (what `_try_transition` calls), so
				# the windup/active/recovery machine ends it on its own contract (AC 1). RED's 1.5 s
				# span outlasts the 0.75 s authored swing, so there is span left to resume into.
				_state.p2.hero.enter_attack(_state.balance_ticks.attack_windup_ticks)
				_next("swing_arm")
		"swing_arm":
			if since >= CHECK_DELAY:
				# The cast is made a few frames INTO the swing, deliberately: armed in the same frame
				# as the transition, the rising edge would reach the controller while its mirrored
				# state is still IDLE and the `attack` clip would win by arriving second, which proves
				# nothing about a counter pressed mid-swing.
				if _clip(_p2) != &"attack":
					_failures.append("6. setup: the swing owns the body before the cast (got '%s')"
						% _clip(_p2))
				_arm_counter(Enums.CardColor.RED)
				_next("swing_watch")
		"swing_watch":
			if _state.p2.hero.action_state == HeroState.ActionState.ATTACKING:
				if String(_clip(_p2)).begins_with("counter_"):
					_failures.append("6. a swing in progress keeps ITS OWN clip across the busy span "
						+ "-- the counter played over it (got '%s')" % _clip(_p2))
					_done_frame = _frames
			elif _state.p2.defense_window.is_running:
				_next("swing_check")
			else:
				_failures.append("6. setup: the swing outlasted RED's busy span")
				_done_frame = _frames
		"swing_check":
			if since >= CHECK_DELAY:
				if not String(_clip(_p2)).begins_with("counter_"):
					_failures.append("6. the counter RESUMES when the swing ends inside the span "
						+ "(got '%s')" % _clip(_p2))
				# Still inside RED's span, so the hit shape rides the same counter.
				_state._queue.push(_state.hit_landed.emit.bind(0, 1, 1.0, _state.p2.hero.get_hp()))
				_next("hit_check")
		"hit_check":
			if since >= CHECK_DELAY:
				if _clip(_p2) == &"hit_react":
					_failures.append("7. an ordinary hit plays NO hit_react over a counter -- a "
						+ "countering hero is an acting one (the 6-6a AC 2 register)")
				elif not String(_clip(_p2)).begins_with("counter_"):
					_failures.append("7. ...and the counter keeps the body through it (got '%s')"
						% _clip(_p2))
				_next("recast_settle")
		"recast_settle":
			if not _state.p2.defense_window.is_running:
				_arm_counter(Enums.CardColor.GREEN)
				_next("recast")
			elif since > SPAN_BUDGET_FRAMES:
				_failures.append("8. setup: RED's span never expired within %d frames"
					% SPAN_BUDGET_FRAMES)
				_done_frame = _frames
		"recast":
			if since >= CHECK_DELAY:
				if _clip(_p2) != &"counter_throw" or _dagger() == null:
					_failures.append("8. setup: a GREEN counter with its dagger is in flight")
				# The re-cast: a second press while the key STILL READS RUNNING, which is what the
				# last-tick case looks like to a poll that runs once per tick. No falling edge ever
				# appears; only the colour changing and the count RISING say a new press happened.
				_arm_counter(Enums.CardColor.RED)
				_next("recast_check")
		"recast_check":
			if since >= CHECK_DELAY:
				if _clip(_p2) != &"counter_jump" and _clip(_p2) != &"counter_backflip":
					_failures.append("8. a re-cast with no falling edge is a NEW press -- RED's "
						+ "sequence must start (got '%s')" % _clip(_p2))
				if _dagger() != null:
					_failures.append("8. ...and the ended counter's dagger is freed with it")
				_done_frame = _frames
	return false
