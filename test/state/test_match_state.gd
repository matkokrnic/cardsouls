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
