extends TestCase

## Story 1-6 (AC 1, AC 5b): the NullController + the null-driven-slot guarantee. NON-GOLDEN
## — this file never touches the determinism sequence. Two things are proven:
##  (1) NullController.sample() yields a FRESH empty InputIntent each tick (the inherited
##      base Controller null behavior — no move, no presses, no holds; a new instance per
##      call, never a reused mutable one, per the InputIntent LIFETIME contract).
##  (2) A MatchState slot fed NullController output for many ticks never leaves IDLE and
##      never acquires velocity — the state-layer guarantee of an unmoved dummy. Position
##      itself is actor-owned (F1) and never in state, so "unmoved" is asserted as
##      action_state == IDLE and velocity == ZERO.


## A fully-live E1 config, so the slot is proven inert even in a normally-started match
## (balance injected), not merely a pre-injection one. Same shape as the other state tests.
func _config() -> BalanceConfig:
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
	c.attack_move_speed_multiplier = 0.0
	c.melee_hit_mana = 8.0
	c.deflect_window_seconds = 4.0 / 60.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	return c


func _make_match() -> MatchState:
	var ms := MatchState.new(7, 100.0, 5.0, 50.0, 80.0)
	ms.apply_balance(_config())
	ms.drain_signals()
	return ms


func test_null_controller_sample_is_fresh_and_empty() -> void:
	var c := NullController.new()
	var a := c.sample()
	var b := c.sample()
	assert_not_null(a, "sample() returns an InputIntent")
	assert_true(a is InputIntent, "sample() returns an InputIntent")
	assert_ne(a, b, "a FRESH instance per tick, never a reused mutable one")
	assert_true(a.move_dir.is_zero_approx(), "null move")
	assert_eq(a.pressed.size(), 0, "no presses")
	assert_eq(a.held.size(), 0, "no holds")


func test_null_driven_slot_stays_idle_and_unmoved() -> void:
	var ms := _make_match()
	var dummy := NullController.new()
	for _i in range(30):
		var intents: Array[InputIntent] = [dummy.sample(), dummy.sample()]
		ms.advance(intents)
		ms.drain_signals()
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
			"P1 null slot never leaves IDLE")
		assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE,
			"P2 null slot never leaves IDLE")
		assert_true(ms.p1.hero.velocity.is_zero_approx(), "P1 null slot never moves")
		assert_true(ms.p2.hero.velocity.is_zero_approx(), "P2 null slot never moves")
