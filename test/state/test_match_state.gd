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
