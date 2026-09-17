extends SceneTree

## Story 6-6a (AC 5/AC 8/AC 9/AC 11, Open Questions 3 and 9): the defense reactions through the REAL
## runner -- `main.tscn`, match_runner's wiring closures, the live `MatchState`, one `_physics_process`
## (F1). The controller-shape file (test_hero_reaction_clips.gd) feeds AnimationController hand-built
## arguments; this one proves the RUNNER computes and forwards them correctly, which is runtime
## composition no state-level test reaches (`3-0b/R34`).
##
## THE STATE IS POKED, NOT PLAYED, on test_orb_cue_live.gd's precedent: running a real chargeup here would
## duplicate test_unblockable_defense.gd's coverage. The pokes are the state layer's OWN seats -- a forced
## stun (the `test_action_state.gd` idiom), `_apply_landing_packages` with a package owed (exactly what
## step 6b runs), `_apply_debug_reset` (exactly what step 1 runs) -- and the queued signals they push are
## drained by the runner's own next tick, through its own closures.
##
## THE SEQUENCE, P2 throughout, P1 the cross-slot control:
##   1. hit    -- a `hit_landed` on P1: P1 plays `hit_react`, P2 does not (the second consumer, per slot).
##   2. stun   -- an ORDINARY stun on P2: `stunned`.
##   3. escalate -- a knockdown PACKAGE on the stunned P2 (a same-state write that emits no transition):
##               the pose switches to `knockdown` off the package's own `hit_landed`, and the state
##               window is the knockdown's (AC 5: the escalation is visible, the window extends).
##   4. reset  -- the debug reset's `STUNNED -> IDLE`: NO `get_up`, NO get-up iframes (AC 9).
##   5. knockdown again, then wait out the timer -- the timer's `STUNNED -> IDLE`: `get_up` plays and the
##      get-up iframes are armed (AC 8). Both exits queue the identical transition; the runner's
##      `_get_up_armed_for_slot` is what tells them apart (Open Question 9).
##   6. an ORDINARY stun that starts and ends while that get-up window is STILL RUNNING: its exit plays no
##      `get_up`. This is why the runner forwards "armed ON THIS TICK" (running with nothing elapsed)
##      rather than merely "running" -- a hero deflected during its get-up iframes, say.
##
## Run: godot --headless --path . --script res://test/integration/test_defense_reactions_live.gd

const CHECK_DELAY := 2
const TIMER_BUDGET_FRAMES := 400
const QUIT_DEFER_FRAMES := 30   ## `4-3b/R29`: never quit on the frame of the last read

var _frames := 0
var _runner: Node
var _state: MatchState
var _p1: HeroActor
var _p2: HeroActor
var _phase := "hit"
var _phase_frame := 0
var _done_frame := -1
var _failures: Array[String] = []


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _clip(hero: HeroActor) -> StringName:
	return hero.animation_controller.animation_player.current_animation


func _next(phase: String) -> void:
	_phase = phase
	_phase_frame = _frames


func _knock_down_p2() -> void:
	_state._landing_package_pending[0] = true
	_state._apply_landing_packages()


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
		_next("hit")
		return false
	var since := _frames - _phase_frame
	var p2 := _state.p2.hero
	match _phase:
		"hit":
			if since >= CHECK_DELAY:
				_state._queue.push(_state.hit_landed.emit.bind(1, 0, 3.0, 97.0))
				_next("hit_check")
		"hit_check":
			if since >= CHECK_DELAY:
				if _clip(_p1) != &"hit_react":
					_failures.append("1. a hit on idle P1 plays hit_react (got '%s')" % _clip(_p1))
				if _clip(_p2) == &"hit_react":
					_failures.append("1. P1's hit played hit_react on P2 -- the consumer is cross-wired")
				p2.stun.start(_state.balance_ticks.color_counter_stun_ticks)
				p2.set_action_state(HeroState.ActionState.STUNNED)
				_next("stun_check")
		"stun_check":
			if since >= CHECK_DELAY:
				if _clip(_p2) != &"stunned":
					_failures.append("2. an ordinary stun plays stunned (got '%s')" % _clip(_p2))
				_knock_down_p2()
				_next("escalate_check")
		"escalate_check":
			if since >= CHECK_DELAY:
				if _clip(_p2) != &"knockdown":
					_failures.append("3. the escalation is VISIBLE: stunned -> knockdown off the package's "
						+ "hit_landed, with no transition emitted (got '%s')" % _clip(_p2))
				if p2.stun.duration_ticks() != _state.balance_ticks.knockdown_stun_ticks:
					_failures.append("3. ...and the window EXTENDS to the knockdown's (%d, got %d)"
						% [_state.balance_ticks.knockdown_stun_ticks, p2.stun.duration_ticks()])
				_state._apply_debug_reset()
				_next("reset_check")
		"reset_check":
			if since >= CHECK_DELAY:
				if p2.action_state != HeroState.ActionState.IDLE:
					_failures.append("4. setup: the reset returns P2 to IDLE")
				if _clip(_p2) == &"get_up":
					_failures.append("4. the DEBUG RESET exit from a knockdown must NOT play get_up")
				if p2.get_up_iframe.is_running:
					_failures.append("4. ...and must NOT arm the get-up iframes")
				_knock_down_p2()
				_next("timer_wait")
		"timer_wait":
			if p2.action_state == HeroState.ActionState.IDLE:
				_next("timer_check")
			elif since > TIMER_BUDGET_FRAMES:
				_failures.append("5. the knockdown never timed out within %d frames" % TIMER_BUDGET_FRAMES)
				_done_frame = _frames
		"timer_check":
			if since >= 1:
				if _clip(_p2) != &"get_up":
					_failures.append("5. the TIMER exit from a knockdown plays get_up (got '%s')" % _clip(_p2))
				if not p2.get_up_iframe.is_running:
					_failures.append("5. ...and the get-up iframes are armed")
				if _clip(_p1) == &"get_up":
					_failures.append("5. P2's get-up played on P1")
				p2.stun.start(_state.balance_ticks.deflect_stun_ticks)
				p2.set_action_state(HeroState.ActionState.STUNNED)
				_next("ordinary_wait")
		"ordinary_wait":
			if p2.action_state == HeroState.ActionState.IDLE:
				_next("ordinary_check")
			elif since > TIMER_BUDGET_FRAMES:
				_failures.append("6. the ordinary stun never timed out within %d frames" % TIMER_BUDGET_FRAMES)
				_done_frame = _frames
		"ordinary_check":
			if since >= 1:
				if not p2.get_up_iframe.is_running:
					_failures.append("6. setup: the earlier get-up window must still be running at this exit")
				if _clip(_p2) == &"get_up":
					_failures.append("6. an ORDINARY stun's exit played get_up because an older get-up "
						+ "window was still running")
				_done_frame = _frames
	return false
