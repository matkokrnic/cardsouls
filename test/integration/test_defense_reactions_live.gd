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
##   7. 6-6a review D2, a BLOCKING P2 and the runner's `blocked` discriminator, each clip read from INSIDE the
##      hit's own emission (a handler connected after the runner's), since the headless P2 holds no block key
##      and drops back to IDLE on the very next advance:
##        a. a full-damage hit from OUTSIDE the arc (the state's own step-4 emit, `blocked` false): NOT
##           `block_impact` -- the block pose stays;
##        b. a BLOCKED hit (`blocked` true): `block_impact`;
##        c. an unanswered unblockable on the blocker (the landing package): `knockdown`, not `block_impact`.
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
var _p2_hit_clips: Array[StringName] = []   ## P2's clip as each hit on P2 finishes its runner consumers


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
		else:
			# Connected AFTER the runner wired its own consumers in _ready, so it runs after the rig closure.
			_state.hit_landed.connect(func(_a: int, target_slot: int, _d: float, _hp: float) -> void:
				if target_slot == 1:
					_p2_hit_clips.append(_clip(_p2)))
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
				# 6-6b post-smoke (R-S6): the colour-counter stun was retired with its field (the
				# counter knocks the attacker down instead), so the ORDINARY stun this phase needs
				# is the one that remains -- the melee deflect's, still classified as ordinary by
				# `is_knockdown_stun`, which is the only property this phase turns on.
				p2.stun.start(_state.balance_ticks.deflect_stun_ticks)
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
				_block_p2_and_hit(false)
				_next("arc_out_check")
		"arc_out_check":
			if since >= CHECK_DELAY:
				if _last_p2_hit_clip() != &"block":
					_failures.append("7a. a full-damage hit from OUTSIDE the arc on a BLOCKING P2 must not play "
						+ "block_impact -- the block pose stays (got '%s')" % _last_p2_hit_clip())
				_block_p2_and_hit(true)
				_next("arc_in_check")
		"arc_in_check":
			if since >= CHECK_DELAY:
				if _last_p2_hit_clip() != &"block_impact":
					_failures.append("7b. a BLOCKED hit on a BLOCKING P2 plays block_impact (got '%s')"
						% _last_p2_hit_clip())
				p2.set_action_state(HeroState.ActionState.BLOCKING)
				_knock_down_p2()
				_next("unblockable_check")
		"unblockable_check":
			if since >= CHECK_DELAY:
				if _last_p2_hit_clip() != &"knockdown":
					_failures.append("7c. an unanswered unblockable on a BLOCKING P2 plays knockdown, never a "
						+ "stale block_impact (got '%s')" % _last_p2_hit_clip())
				# Two knockdown packages (phases 3 and 5) + the three hits of phase 7.
				if _p2_hit_clips.size() != 5:
					_failures.append("7. setup: five hits on P2 reached the recorder (got %d)" % _p2_hit_clips.size())
				_done_frame = _frames
	return false


## P2 enters BLOCKING and takes one step-4-shaped hit whose block verdict is `blocked` -- through the state
## layer's OWN emit seat, `_emit_hit_landed`, which is what `_resolve_contacts` queues. Both are drained by
## the runner's next tick, the transition first.
func _block_p2_and_hit(blocked: bool) -> void:
	_state.p2.hero.set_action_state(HeroState.ActionState.BLOCKING)
	var damage := 1.5 if blocked else 6.0
	_state._queue.push(_state._emit_hit_landed.bind(0, 1, damage, _state.p2.hero.get_hp(), blocked))


func _last_p2_hit_clip() -> StringName:
	return _p2_hit_clips.back() if not _p2_hit_clips.is_empty() else &""
