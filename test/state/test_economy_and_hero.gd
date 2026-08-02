extends TestCase

## Item 3(b) coverage: pools + HeroState + PlayerState.

## Story 3-1 (AC 1/AC 3): PlayerState is constructed STAT-LESS — every bound now arrives by
## injection (MatchState._apply_balance_to_player), so this helper injects the SAME values
## the old positional constructor supplied, the same way the real seat does: bounds set, then
## stamina refilled (D9) and mana left EMPTY (the flywheel contract, 3-1/R2). Every
## assertion below is therefore unchanged.
func _player() -> PlayerState:
	return _stat_player(SignalQueue.new())


func _stat_player(queue: SignalQueue) -> PlayerState:
	var p := PlayerState.new(queue)
	p.hero.set_max_hp(100.0)
	p.hero.heal(100.0)
	p.hero.move_speed = 5.0
	p.stamina.set_maximum(50.0)
	p.stamina.refill()
	p.mana.set_maximum(80.0)
	return p


func test_stamina_spend_and_overspend_guard() -> void:
	var p := _player()
	assert_eq(p.stamina.get_current(), 50.0, "starts full")
	assert_true(p.stamina.spend(20.0, 0))
	assert_eq(p.stamina.get_current(), 30.0)
	assert_false(p.stamina.spend(40.0, 0), "overspend refused")
	assert_eq(p.stamina.get_current(), 30.0, "unchanged after refusal")


func test_mana_starts_empty_and_clamps() -> void:
	var p := _player()
	assert_eq(p.mana.get_current(), 0.0)
	p.mana.add(200.0)
	assert_eq(p.mana.get_current(), 80.0, "clamped to max")


func test_hp_damage_floor_and_death() -> void:
	var p := _player()
	p.hero.take_damage(30.0)
	assert_eq(p.hero.get_hp(), 70.0)
	assert_true(p.hero.is_alive())
	p.hero.take_damage(999.0)
	assert_eq(p.hero.get_hp(), 0.0, "floored at 0")
	assert_false(p.hero.is_alive())


func test_signals_queue_until_drain() -> void:
	var q := SignalQueue.new()
	var p := _stat_player(q)
	# Story 3-1: the stat injection above QUEUES its own re-injection signals (hp fill,
	# stamina refill). Drain them here, before connecting, so this test still observes
	# exactly one queued emission — its own.
	q.drain()
	var hits := {"n": 0}
	p.hero.hp_changed.connect(func(_c: float, _m: float) -> void: hits.n += 1)
	p.hero.take_damage(10.0)
	assert_eq(hits.n, 0, "queued during mutation, not emitted")
	q.drain()
	assert_eq(hits.n, 1, "emitted on drain")


func test_hero_timers_tick() -> void:
	var p := _player()
	p.hero.windup.start(2)
	p.hero.tick_timers()
	assert_true(p.hero.windup.is_running, "running 1/2")
	p.hero.tick_timers()
	assert_false(p.hero.windup.is_running, "done 2/2")


func test_orb_pool_all_color_reset() -> void:
	var p := _player()
	p.orbs.add(Enums.CardColor.RED, 2)
	p.orbs.add(Enums.CardColor.GREEN, 1)
	assert_eq(p.orbs.get_count(Enums.CardColor.RED), 2)
	p.orbs.reset_all()
	assert_eq(p.orbs.get_count(Enums.CardColor.RED), 0, "reset clears RED")
	assert_eq(p.orbs.get_count(Enums.CardColor.GREEN), 0, "reset clears ALL colors (TDD 8.2)")


func test_player_snapshot_shape() -> void:
	var p := _player()
	var snap := p.to_snapshot()
	assert_true(snap.has("hero") and snap.has("stamina") and snap.has("mana") and snap.has("orbs"))
	assert_eq(snap["hand_size"], 0)
