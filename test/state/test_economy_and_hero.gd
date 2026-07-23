extends TestCase

## Item 3(b) coverage: pools + HeroState + PlayerState.

func _player() -> PlayerState:
	return PlayerState.new(SignalQueue.new(), 100.0, 5.0, 50.0, 80.0)


func test_stamina_spend_and_overspend_guard() -> void:
	var p := _player()
	assert_eq(p.stamina.get_current(), 50.0, "starts full")
	assert_true(p.stamina.spend(20.0))
	assert_eq(p.stamina.get_current(), 30.0)
	assert_false(p.stamina.spend(40.0), "overspend refused")
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
	var p := PlayerState.new(q, 100.0, 5.0, 50.0, 80.0)
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
