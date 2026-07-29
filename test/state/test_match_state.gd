extends TestCase

## Item 3(c) coverage: MatchState.advance(intents) + drain_signals().

func _step(ms: MatchState, d1: Vector2, d2: Vector2) -> void:
	var i1 := InputIntent.new()
	i1.move_dir = d1
	var i2 := InputIntent.new()
	i2.move_dir = d2
	var intents: Array[InputIntent] = [i1, i2]
	ms.advance(intents)
	ms.drain_signals()


func test_movement_seam_computes_world_velocity() -> void:
	var ms := MatchState.new(42, 100.0, 5.0, 50.0, 80.0)
	_step(ms, Vector2(1, 0), Vector2(0, 1))
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3(5, 0, 0)), "p1 (1,0) -> world +X * speed")
	assert_true(ms.p1.hero.facing.is_equal_approx(Vector2(1, 0)))
	assert_true(ms.p2.hero.velocity.is_equal_approx(Vector3(0, 0, 5)), "p2 (0,1) -> world +Z * speed")


func test_analog_input_clamped_to_move_speed() -> void:
	var ms := MatchState.new(42, 100.0, 5.0, 50.0, 80.0)
	_step(ms, Vector2(3, 4), Vector2.ZERO)  # length 5 input
	assert_almost_eq(ms.p1.hero.velocity.length(), 5.0, 1e-4, "never exceeds move_speed")


func test_tick_counter_advances() -> void:
	var ms := MatchState.new(1, 100.0, 5.0, 50.0, 80.0)
	_step(ms, Vector2.ZERO, Vector2.ZERO)
	_step(ms, Vector2.ZERO, Vector2.ZERO)
	assert_eq(int(ms.to_snapshot()["tick"]), 2)


func test_round_ended_is_queued_and_fires_once() -> void:
	var ms := MatchState.new(1, 100.0, 5.0, 50.0, 80.0)
	var ev := {"n": 0, "loser": -1}
	ms.round_ended.connect(func(loser: int) -> void:
		ev.n += 1
		ev.loser = loser)
	ms.p1.hero.take_damage(999.0)
	# advance WITHOUT draining, to observe the queue discipline directly
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	assert_eq(ev.n, 0, "queued, not fired mid-advance")
	ms.drain_signals()
	assert_eq(ev.n, 1, "fires once on drain")
	assert_eq(ev.loser, 0, "P1 (index 0) lost")
	assert_true(ms.to_snapshot()["round_over"])
	ms.advance(intents)
	ms.drain_signals()
	assert_eq(ev.n, 1, "not re-fired after round over")


## Story 1-7 (D-1 consequence): extends the "exactly once" pin above — round_ended fires
## once per DEATH, not once per match. The debug reset clears the latch (and revives the
## DEAD hero), so a second death fires a second round_ended.
func test_round_ended_rearms_after_debug_reset_and_fires_once_per_death() -> void:
	var ms := MatchState.new(1, 100.0, 5.0, 50.0, 80.0)
	var ev := {"n": 0, "loser": -1}
	ms.round_ended.connect(func(loser: int) -> void:
		ev.n += 1
		ev.loser = loser)
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.p2.hero.take_damage(999.0)
	ms.advance(intents)
	ms.drain_signals()
	assert_eq(ev.n, 1, "first death fires")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.DEAD, "loser entered DEAD (step 8)")
	ms.advance(intents)
	ms.drain_signals()
	assert_eq(ev.n, 1, "latched: no re-fire while the round stays over")
	var reset := InputIntent.new()
	reset.debug_reset = true
	var reset_intents: Array[InputIntent] = [reset, InputIntent.new()]
	ms.advance(reset_intents)
	ms.drain_signals()
	assert_false(bool(ms.to_snapshot()["round_over"]), "reset cleared the round latch")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE, "reset revived DEAD -> IDLE")
	assert_eq(ms.p2.hero.get_hp(), 100.0, "reset restored HP to max")
	assert_eq(ev.n, 1, "reset itself fires nothing")
	ms.p2.hero.take_damage(999.0)
	ms.advance(intents)
	ms.drain_signals()
	assert_eq(ev.n, 2, "second death fires again — once per DEATH, not per match")
	assert_eq(ev.loser, 1, "same loser reported")


## Story 2-3 (AC2/AC4, 2-3/R5): a DEAD hero's velocity is EXPLICITLY zeroed every tick.
## HeroActor.drive() reads hero_state.velocity straight into move_and_slide(), so a skipped
## write would leave the last live velocity in place and the corpse would slide forever —
## the residual this story kills. The kill tick still moves while alive (movement resolves in
## step 3, DEAD is set in step 8), so the corpse carries velocity until the FIRST dead tick
## zeroes it, and it stays zero across further ticks even with live move intents.
##
## STORY 2-6 SUPERSESSION: this now passes because of the step-1b round-over FREEZE, NOT the
## step-3 DEAD branch. A dead hero always implies _round_over, so on every tick after the kill
## advance() returns at step 1b — and step 1b zeroes both heroes' velocity (2-6 halt ruling),
## which is what keeps the corpse from sliding here. The step-3 DEAD velocity-zero is now
## unreachable via advance() (see the 2-6 arch-amendment queue entry: removal vs retention).
func test_dead_hero_velocity_zeroed_every_tick() -> void:
	var ms := MatchState.new(1, 100.0, 5.0, 50.0, 80.0)
	_step(ms, Vector2(1, 0), Vector2.ZERO)   # P1 moving: velocity (5, 0, 0)
	ms.p1.hero.take_damage(999.0)
	_step(ms, Vector2(1, 0), Vector2.ZERO)   # kill tick: alive at step 3 -> velocity kept, DEAD at step 8
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.DEAD, "P1 is DEAD")
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3(5, 0, 0)),
		"corpse still carries its last live velocity after the kill tick — the residual this closes")
	_step(ms, Vector2(0, 1), Vector2.ZERO)   # first DEAD tick, LIVE perpendicular intent
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3.ZERO),
		"DEAD: velocity EXPLICITLY zeroed despite a live move intent")
	_step(ms, Vector2(-1, 0), Vector2.ZERO)  # a further DEAD tick, another live intent
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3.ZERO),
		"stays zero across further ticks with live intents")


## Story 2-3 (AC2/AC4, 2-3/R5): a DEAD hero's facing write is SKIPPED — the last value
## persists unchanged, and that persistence IS the freeze (no stored frozen copy, no new
## snapshot field). Asymmetric with velocity above: velocity is written, facing is not.
##
## STORY 2-6 SUPERSESSION: after the kill the round is over, so advance() returns at step 1b,
## which SKIPS the facing write (facing is display-only — the same asymmetry rule). So facing
## persists here because of the freeze, not the step-3 DEAD branch (now unreachable via advance()).
func test_dead_hero_facing_frozen() -> void:
	var ms := MatchState.new(1, 100.0, 5.0, 50.0, 80.0)
	_step(ms, Vector2(1, 0), Vector2.ZERO)   # P1 facing -> (1, 0)
	assert_true(ms.p1.hero.facing.is_equal_approx(Vector2(1, 0)), "live facing set from input")
	ms.p1.hero.take_damage(999.0)
	_step(ms, Vector2(1, 0), Vector2.ZERO)   # kill tick: DEAD at step 8, facing still (1, 0)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.DEAD, "P1 is DEAD")
	var frozen := ms.p1.hero.facing
	_step(ms, Vector2(0, 1), Vector2.ZERO)   # DEAD tick, live perpendicular intent
	assert_true(ms.p1.hero.facing.is_equal_approx(frozen),
		"DEAD: facing write SKIPPED — last value persists, NOT updated to (0, 1)")
	_step(ms, Vector2(0, -1), Vector2.ZERO)  # a further DEAD tick, another live intent
	assert_true(ms.p1.hero.facing.is_equal_approx(frozen),
		"facing stays frozen across further ticks with live intents")


# --- Story 2-6 (AC 1): round-lifecycle freeze + reset visibility ---------------------------
# The step-1b round-over early return, seated AFTER step-1 reset ingestion. A balance-applied
# match so an attack press can actually transition (action_state is part of the AC's "no
# velocity OR action state changes" pin — without balance the press is inert and would not bite).

func _b1_config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = 5.0
	c.max_stamina = 50.0
	c.stamina_regen_per_second = 60.0
	c.stamina_regen_delay_seconds = 3.0 / 60.0
	c.roll_stamina_cost = 10.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 6.0
	c.attack_move_speed_multiplier = 0.5  # non-zero, so a wrongful ATTACKING gives a distinct velocity
	c.melee_hit_mana = 8.0
	c.deflect_window_seconds = 4.0 / 60.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	return c


func _b1_match() -> MatchState:
	var ms := MatchState.new(9, 100.0, 5.0, 50.0, 80.0)
	ms.apply_balance(_b1_config())
	ms.drain_signals()
	return ms


func _b1_intent(move: Vector2, pressed: Array = [], reset := false) -> InputIntent:
	var i := InputIntent.new()
	i.move_dir = move
	i.debug_reset = reset
	for k in pressed:
		i.pressed[k] = true
		i.held[k] = true
	return i


func _b1_advance(ms: MatchState, p1: InputIntent, p2: InputIntent = null) -> void:
	var intents: Array[InputIntent] = [p1, p2 if p2 != null else InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()


## AC 1 property (a): once _round_over is true, the match HALTS until a reset — the step-1b
## early return zeroes BOTH heroes' velocity every frozen tick (the surviving hero stops moving)
## and no action state changes; facing is SKIPPED (the 2-3 asymmetry rule — a display-only field
## persists) and the tick counter still increments. Velocity is zeroed rather than left drifting
## because the runner reads it into move_and_slide() every frame regardless of the early return
## (2-6 operator ruling; the 2-3/R14 residual reason honoured here instead of step 3).
## MUTATION PROOF A: delete the step-1b early return and this FAILS — the frozen-tick move intent
## resolves to a new velocity and the attack press enters ATTACKING.
## MUTATION PROOF B: delete just the two velocity-zero writes in step 1b and this FAILS — the
## surviving hero's kill-tick velocity (5,0,0) is left drifting instead of halting to zero.
func test_round_over_freezes_resolution_until_reset() -> void:
	var ms := _b1_match()
	_b1_advance(ms, _b1_intent(Vector2(1, 0)))       # P1 moving east: velocity (5,0,0), facing (1,0)
	ms.p2.hero.take_damage(999.0)                    # arm P2's death
	_b1_advance(ms, _b1_intent(Vector2(1, 0)))       # kill tick: alive through step 3, DEAD at step 8
	assert_true(bool(ms.to_snapshot()["round_over"]), "round is over after the kill tick")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "surviving hero still IDLE")
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3(5, 0, 0)),
		"2-3/R13 one-tick carry: the survivor still holds its kill-tick velocity (freeze begins NEXT tick)")
	var frozen_facing := ms.p1.hero.facing
	var tick_before := int(ms.to_snapshot()["tick"])
	# First frozen tick: a DIFFERENT move dir AND an attack press. Both must be ignored, and the
	# halt zeroes velocity for BOTH heroes.
	_b1_advance(ms, _b1_intent(Vector2(0, 1), [&"attack"]))
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3.ZERO),
		"frozen: surviving hero HALTS — velocity zeroed despite a live perpendicular move intent")
	assert_true(ms.p2.hero.velocity.is_equal_approx(Vector3.ZERO),
		"frozen: the corpse is zeroed too — no residual slide (2-3/R14 honoured in step 1b)")
	assert_true(ms.p1.hero.facing.is_equal_approx(frozen_facing),
		"frozen: facing SKIPPED — its last value persists (the display-only asymmetry rule)")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"frozen: attack press ignored — action state does not change")
	assert_eq(int(ms.to_snapshot()["tick"]), tick_before + 1, "tick counter still increments while frozen")
	# A second frozen tick with yet another live intent: still halted, counter still advances.
	_b1_advance(ms, _b1_intent(Vector2(-1, 0), [&"attack"]))
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3.ZERO), "stays halted across further ticks")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "stays IDLE across further ticks")
	assert_eq(int(ms.to_snapshot()["tick"]), tick_before + 2, "counter keeps advancing while frozen")


## AC 1 property (b): a round-over tick followed by a debug-reset tick resolves movement again
## on THAT SAME reset tick — because step 1b sits AFTER step 1 (reset ingestion), the reset
## clears _round_over before the guard is consulted. MUTATION PROOF: hoist the step-1b check
## ahead of the reset (the R6-forbidden order) and this FAILS — the guard returns before the
## reset runs, so the round stays over and the surviving hero stays frozen.
func test_debug_reset_on_frozen_tick_resolves_same_tick() -> void:
	var ms := _b1_match()
	_b1_advance(ms, _b1_intent(Vector2(1, 0)))       # P1 velocity (5,0,0)
	ms.p2.hero.take_damage(999.0)
	_b1_advance(ms, _b1_intent(Vector2(1, 0)))       # kill tick: round over
	assert_true(bool(ms.to_snapshot()["round_over"]), "round over after kill")
	_b1_advance(ms, _b1_intent(Vector2(0, 1)))       # a frozen tick: step 1b halts P1 to zero
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3.ZERO), "halted before the reset")
	# Reset AND a NEW move dir on the SAME tick. Correct order resumes movement this tick.
	_b1_advance(ms, _b1_intent(Vector2(0, 1), [], true))
	assert_false(bool(ms.to_snapshot()["round_over"]), "reset cleared the round latch")
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3(0, 0, 5)),
		"movement resolved on the SAME reset tick: (0,1) -> world +Z * speed (fails if the guard is hoisted ahead of the reset)")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE, "reset revived the DEAD loser to IDLE")


## AC 1 (D1 relay proof — STATE half): `round_started` is PUSHED (queued, D5) by
## `_apply_debug_reset` on EVERY debug reset and fires EXACTLY ONCE per reset. This pins the
## FIRST previously-unproven link in the relay chain — the queue push itself; no prior test
## connected to `ms.round_started` or asserted it was emitted (only that the latch cleared).
## MUTATION PROOF: remove `_queue.push(round_started.emit)` from `_apply_debug_reset` and this
## FAILS (the signal never fires). The runner-relay half is proven by the integration test.
func test_round_started_pushed_once_per_debug_reset() -> void:
	var ms := _b1_match()
	var seen := {"count": 0}
	ms.round_started.connect(func() -> void: seen.count += 1)
	# A plain advance (no reset) fires nothing.
	_b1_advance(ms, _b1_intent(Vector2.ZERO))
	assert_eq(seen.count, 0, "no reset -> round_started never fires")
	# A reset: QUEUED during advance (not emitted mid-tick, D5), fires exactly once on drain.
	var reset_intents: Array[InputIntent] = [_b1_intent(Vector2.ZERO, [], true), InputIntent.new()]
	ms.advance(reset_intents)
	assert_eq(seen.count, 0, "queued during advance, not emitted mid-tick (D5)")
	ms.drain_signals()
	assert_eq(seen.count, 1, "fires EXACTLY ONCE on drain, per reset")
	# A second reset fires again — unconditional, every reset (not once-per-match like round_ended).
	ms.advance(reset_intents)
	ms.drain_signals()
	assert_eq(seen.count, 2, "unconditional: every debug reset pushes round_started")
