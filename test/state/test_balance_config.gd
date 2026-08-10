extends TestCase

## Story 1-1 coverage: the BalanceTicks seconds->ticks conversion boundary (AC 2/4), the
## X3 reload() -> apply_balance() end-to-end path against the authored .tres (AC 3), and
## in-flight window isolation across a mid-match reload (AC 5). Headless: the service
## SCRIPT is instantiated as a plain Node and freed manually — no autoload, no frame.

const SERVICE_SCRIPT := "res://src/systems/balance_config_service.gd"


## Fresh config with sane hero/stamina baselines (so apply_balance never zeroes a pool
## as a side effect) plus per-test overrides.
func _make_config(overrides: Dictionary = {}) -> BalanceConfig:
	var config := BalanceConfig.new()
	config.max_hp = 100.0
	config.move_speed = 5.0
	config.max_stamina = 50.0
	for key in overrides:
		config.set(key, overrides[key])
	return config


func _make_match() -> MatchState:
	return MatchState.new(MatchParams.new(1))


func test_conversion_zero_seconds_is_zero_ticks() -> void:
	var t := BalanceTicks.from_config(_make_config({"attack_windup_seconds": 0.0}))
	assert_eq(t.attack_windup_ticks, 0, "0.0 s -> 0 ticks")


func test_conversion_sub_tick_duration_clamps_to_one_tick() -> void:
	var t := BalanceTicks.from_config(_make_config({"deflect_window_seconds": 0.001}))
	assert_eq(t.deflect_window_ticks, 1, "non-zero sub-tick duration still opens")


func test_conversion_rounds_at_halfway_not_floor_or_ceil() -> void:
	# 0.025 s * 60 Hz = 1.5 ticks: round() -> 2 (floor would give 1)
	var half := BalanceTicks.from_config(_make_config({"roll_iframe_seconds": 0.025}))
	assert_eq(half.roll_iframe_ticks, 2, "round() at the halfway boundary, not floor")
	# 0.02 s * 60 Hz = 1.2 ticks: round() -> 1 (ceil would give 2)
	var below := BalanceTicks.from_config(_make_config({"roll_iframe_seconds": 0.02}))
	assert_eq(below.roll_iframe_ticks, 1, "round() below halfway, not ceil")


func test_conversion_covers_every_seconds_field() -> void:
	var t := BalanceTicks.from_config(_make_config({
		"stamina_regen_delay_seconds": 0.8,
		"attack_windup_seconds": 0.25,
		"attack_active_seconds": 0.15,
		"attack_recovery_seconds": 0.35,
		"attack_chain_window_seconds": 0.5,
		"deflect_window_seconds": 0.15,
		"roll_iframe_seconds": 0.3,
		"roll_duration_seconds": 0.5,
		"stun_seconds": 0.6,
	}))
	assert_eq(t.stamina_regen_delay_ticks, 48)
	assert_eq(t.attack_windup_ticks, 15)
	assert_eq(t.attack_active_ticks, 9)
	assert_eq(t.attack_recovery_ticks, 21)
	assert_eq(t.attack_chain_window_ticks, 30)
	assert_eq(t.deflect_window_ticks, 9)
	assert_eq(t.roll_iframe_ticks, 18)
	assert_eq(t.roll_duration_ticks, 30)
	assert_eq(t.stun_ticks, 36, "stun converts like any duration (DATA ONLY in E1)")


## Story 1-4 (AC 1): the load-time derived RATE field — per-second authoring value over
## TICK_HZ, computed once in from_config() like every other tick-domain value.
func test_conversion_derives_stamina_regen_per_tick() -> void:
	var t := BalanceTicks.from_config(_make_config({"stamina_regen_per_second": 15.0}))
	assert_eq(t.stamina_regen_per_tick, 0.25, "15/s at 60 Hz -> 0.25 per tick, derived at load")


## Story 3-4 (AC 4): the MANA twin of the derived rate above — same derivation, same reason
## (advance() takes no delta, A1, so the per-second authoring value is never consumed
## directly), landing on BalanceTicks per E3-RG/R8. This is the field the authored
## `passive_tick` rule names; the per-second value never reaches the tick ladder.
func test_conversion_derives_mana_regen_per_tick() -> void:
	var t := BalanceTicks.from_config(_make_config({"mana_regen_per_second": 30.0}))
	assert_eq(t.mana_regen_per_tick, 0.5, "30/s at 60 Hz -> 0.5 per tick, derived at load")


## Story 4-2 (AC 7, `4-2/R5`(a)): the retarget cadence derives like every other duration, on the
## `draw_replacement_delay_seconds` precedent. Ordinary conversion first, so the clamp test below is
## testing the CLAMP and not the conversion.
func test_conversion_derives_minion_retarget_interval_ticks() -> void:
	var t := BalanceTicks.from_config(_make_config({"minion_retarget_interval_seconds": 0.2}))
	assert_eq(t.minion_retarget_interval_ticks, 12, "0.2 s at 60 Hz -> 12 ticks, derived at load")
	var quarter := BalanceTicks.from_config(
		_make_config({"minion_retarget_interval_seconds": 0.25}))
	assert_eq(quarter.minion_retarget_interval_ticks, 15,
		"0.25 s -> 15 ticks — the top of the project-context Performance Rule's ~0.1-0.25 s range")


## Story 4-2 (AC 7, `4-2/R5`(d)): THE ONE FIELD IN BalanceTicks THAT IS NOT A BARE
## seconds_to_ticks() CALL, and the reason it is special is that it is a MODULO DIVISOR. Every other
## derived duration may legitimately be 0 ticks (`TimingWindow.start(0)` simply leaves the window
## stopped); a 0 here would divide by zero on the tick ladder at MatchState's step-7 seat.
##
## The ruling gives the degenerate value a DEFINED meaning rather than a guard at the consumer: the
## interval clamps to at least 1 tick ALWAYS, so an authored 0 means "retarget EVERY tick". Asserted
## for zero AND for negative, because a hand-edited `.tres` can carry either and both would otherwise
## reach the modulo — the clamp is `maxi(1, ...)`, not a zero special-case.
##
## THE CLAMP LIVES AT THE CONVERSION BOUNDARY, not at the consumer, which is what makes it
## impossible to bypass: no consumer can read an unclamped value because none exists.
func test_conversion_clamps_the_retarget_interval_to_at_least_one_tick() -> void:
	var zero := BalanceTicks.from_config(_make_config({"minion_retarget_interval_seconds": 0.0}))
	assert_eq(zero.minion_retarget_interval_ticks, 1,
		"an authored 0 clamps to 1 tick — 'retarget every tick', never a modulo by zero (`4-2/R5`(d))")
	var negative := BalanceTicks.from_config(
		_make_config({"minion_retarget_interval_seconds": -3.0}))
	assert_eq(negative.minion_retarget_interval_ticks, 1,
		"a negative authored value clamps the same way — seconds_to_ticks returns 0 for it, and the "
		+ "clamp is maxi(1, ...) rather than a zero special-case")
	# The clamp must NOT be a floor applied to every field: a sub-tick duration elsewhere still
	# converts by the shared rule, and a genuinely zero duration elsewhere still derives 0 ticks.
	assert_eq(zero.reshuffle_vulnerable_window_ticks, 0,
		"the clamp is scoped to the divisor field alone — a sibling duration authored 0 still "
		+ "derives 0 ticks, so this is not a blanket floor over from_config()")


## AC 3 end-to-end: service reload() -> apply_balance() -> pools and windows reflect the
## authored .tres values.
func test_reload_to_apply_balance_reflects_tres_values() -> void:
	var service: Node = (load(SERVICE_SCRIPT) as GDScript).new()
	service.reload()
	var config: BalanceConfig = service.get_config()
	assert_not_null(config, "service loaded the authored .tres")
	var ms := _make_match()
	ms.apply_balance(config)
	ms.drain_signals()
	assert_eq(ms.p1.stamina.get_maximum(), config.max_stamina, "p1 stamina bound re-injected")
	assert_eq(ms.p2.stamina.get_maximum(), config.max_stamina, "p2 stamina bound re-injected")
	assert_eq(ms.p1.hero.get_max_hp(), config.max_hp, "hero hp bound re-injected")
	assert_eq(ms.p1.hero.move_speed, config.move_speed, "hero move_speed re-injected")
	assert_eq(ms.balance_ticks.attack_windup_ticks,
		TimingWindow.seconds_to_ticks(config.attack_windup_seconds),
		"durations re-converted from the .tres")
	assert_eq(ms.balance_ticks.deflect_window_ticks,
		TimingWindow.seconds_to_ticks(config.deflect_window_seconds))
	service.free()


## ---- Story 3-0d (AC 1, `3-0d/R5`): DEBT B's CACHE HALF ----------------------------------
##
## reload() must BYPASS the resource cache, or it re-reads nothing and X3 hot-reload is a lie
## (decision-log:130 — "on-disk hot-reload is a no-op without CACHE_MODE_IGNORE"). The proof is
## REFERENCE IDENTITY and it touches NO FILE: two reload() calls must hand back DIFFERENT
## instances carrying EQUAL values, while a plain load() of the same path hands back ONE.
##
## MEASURED against this engine before the assertion was written (Godot 4.6.3, the shipped
## data/balance/balance_config.tres): plain load() twice -> same instance; CACHE_MODE_IGNORE
## twice -> different instances, equal values; CACHE_MODE_IGNORE vs the cached instance ->
## different.
##
## MUTATION PROOF: revert reload()'s body to `_config = load(CONFIG_PATH) as BalanceConfig` and
## the first assertion FAILS — both reloads return the one cached instance.
##
## ZERO FILE MUTATION, DELIBERATELY. The authored .tres is tracked and other tests read it
## (test_balance_authoring.gd, test/integration/test_contact_pipeline.gd); a permanently
## re-running test that edited it would have no restore step at all, which is strictly worse than
## the one-off dev-pass case the PERMANENT RULE at decision-log:799 was written for.
func test_reload_bypasses_the_resource_cache_and_hands_back_a_fresh_instance() -> void:
	var script: GDScript = load(SERVICE_SCRIPT)
	var config_path: String = script.get_script_constant_map()["CONFIG_PATH"]
	assert_eq(config_path, "res://data/balance/balance_config.tres",
		"the path under test is the service's own const, not a second literal to drift from it")
	var service: Node = script.new()
	service.reload()
	var first: BalanceConfig = service.get_config()
	service.reload()
	var second: BalanceConfig = service.get_config()
	assert_not_null(first, "the first reload produced a config")
	assert_not_null(second, "...and so did the second")
	assert_false(first == second,
		"two reload() calls must hand back DIFFERENT instances — a plain load() returns the "
		+ "CACHED resource forever, so a mid-session edit to the .tres would be silently ignored")
	# EQUAL VALUES: the second reload re-read the same unmodified file, so a fresh instance is the
	# only difference. Every script-declared property is compared, so this cannot pass on a
	# half-populated re-read.
	var compared := 0
	for prop: Dictionary in first.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		compared += 1
		assert_eq(second.get(prop["name"]), first.get(prop["name"]),
			"reloaded value differs for %s — the re-read must be a fresh INSTANCE, not fresh DATA"
					% prop["name"])
	assert_true(compared > 10,
		"the property walk must actually visit BalanceConfig's authored fields (got %d)" % compared)
	# The other half, and what makes the first assertion about the CACHE MODE rather than about
	# load() being unpredictable: a plain load() of the same path DOES hand back one instance.
	var cached_a: BalanceConfig = load(config_path)
	var cached_b: BalanceConfig = load(config_path)
	assert_true(cached_a == cached_b,
		"a plain load() of the same path returns the SAME cached instance twice — the behaviour "
		+ "reload() must not have")
	assert_false(first == cached_a,
		"...and neither reload handed back that cached instance either")
	service.free()


func test_apply_balance_reclamps_and_resignals_shrunk_bound() -> void:
	var ms := _make_match()  # stamina starts full at max 50
	var ev := {"n": 0, "max": -1.0}
	ms.p1.stamina.stamina_changed.connect(func(_current: float, maximum: float) -> void:
		ev.n += 1
		ev.max = maximum)
	ms.apply_balance(_make_config({"max_stamina": 30.0}))
	assert_eq(ev.n, 0, "re-signal is queued (D5), not emitted during apply_balance")
	ms.drain_signals()
	assert_eq(ev.n, 1, "shrunk bound re-signals on drain")
	assert_eq(ev.max, 30.0)
	assert_eq(ms.p1.stamina.get_current(), 30.0, "re-clamped to the new max")


## ---- Story 3-1 (AC 4, 3-1/R2): the PER-POOL reload contract -----------------------------
## The three pools are deliberately NOT symmetric across apply_balance(), and each half of
## the asymmetry has its own pin: stamina's refill-on-every-reload is
## test_stamina_economy.gd::test_mid_match_reload_refills_stamina_to_max (untouched by this
## story), and mana's NEVER-refill is the test below.

## Mana gets set_maximum and NOTHING else — earned mana is re-clamped into the new bound and
## never handed back full. ManaPool's own contract is that mana starts empty and is built by
## the flywheel (mana_pool.gd:4-5); a reload-refill would gift a full bar mid-match.
##
## MUTATION PROOF: add `player.mana.refill()` (or `player.mana.add(config.max_mana)`) beside
## the mana set_maximum in _apply_balance_to_player and this FAILS — the earned 4.0 becomes a
## full bar on the reload. The shrink half fails on any implementation that skips
## set_maximum entirely.
func test_mid_match_reload_sets_mana_maximum_but_never_refills() -> void:
	var ms := _make_match()
	ms.apply_balance(_make_config({"max_mana": 10.0}))
	ms.drain_signals()
	assert_eq(ms.p1.mana.get_current(), 0.0, "match start: mana EMPTY (the flywheel builds it)")
	assert_eq(ms.p1.mana.get_maximum(), 10.0, "match start: the authored cap is injected")
	ms.p1.mana.add(4.0)  # earned mid-match, the state a reload must respect
	ms.drain_signals()
	# Reload with a LARGER cap: the bound moves, the earned value does not.
	ms.apply_balance(_make_config({"max_mana": 20.0}))
	ms.drain_signals()
	assert_eq(ms.p1.mana.get_maximum(), 20.0, "reload re-injects the new mana bound")
	assert_eq(ms.p1.mana.get_current(), 4.0,
		"reload NEVER refills mana — the earned 4.0 survives untouched (3-1/R2)")
	assert_eq(ms.p2.mana.get_current(), 0.0, "the other player's empty bar is not filled either")
	# Reload with a SMALLER cap: set_maximum re-clamps, which is all a rescale may do.
	ms.apply_balance(_make_config({"max_mana": 3.0}))
	ms.drain_signals()
	assert_eq(ms.p1.mana.get_maximum(), 3.0, "shrunk bound re-injected")
	assert_eq(ms.p1.mana.get_current(), 3.0, "current CLAMPED into the smaller bound, not refilled")


## Story 3-1 (AC 4, 3-1/R2/R4): the FIRST-INJECTION outcome, the half that cannot fall out of
## one uniform rule. set_max_hp only re-clamps (it never raises hp), so with the constructor
## no longer seeding hp a stat-less hero would sit at 0 and start the match DEAD — the 3-1/R4
## finding. Match start must yield FULL hp, FULL stamina, EMPTY mana.
##
## MUTATION PROOF: delete the `if first_injection: player.hero.heal(config.max_hp)` branch in
## _apply_balance_to_player and this FAILS — hp stays 0.0 and the hero is not alive.
func test_first_injection_yields_full_hp_full_stamina_empty_mana() -> void:
	var ms := MatchState.new(MatchParams.new(1))
	assert_eq(ms.p1.hero.get_hp(), 0.0, "pre-injection: stat-less (AC 1) — hp is not seeded")
	ms.apply_balance(_make_config({"max_mana": 10.0}))
	ms.drain_signals()
	for player: PlayerState in [ms.p1, ms.p2]:
		assert_eq(player.hero.get_hp(), 100.0, "match start: FULL hp at the authored maximum")
		assert_true(player.hero.is_alive(), "match start: alive — never a hero that starts dead")
		assert_eq(player.stamina.get_current(), 50.0, "match start: FULL stamina (D9)")
		assert_eq(player.mana.get_current(), 0.0, "match start: EMPTY mana (the flywheel contract)")
		assert_eq(player.mana.get_maximum(), 10.0, "match start: the mana bound is injected")


## Story 3-1 (AC 4): hp is PRESERVED and clamped across a reload — exactly what set_max_hp
## ships today, and deliberately NOT the stamina refill. A reload must never heal.
##
## MUTATION PROOF: change the first-injection hp fill into an unconditional one (drop the
## `if first_injection`) and this FAILS — the wounded 40.0 becomes a free full heal.
func test_mid_match_reload_preserves_hp_and_clamps_it() -> void:
	var ms := _make_match()
	ms.apply_balance(_make_config())
	ms.p1.hero.take_damage(60.0)
	ms.drain_signals()
	assert_eq(ms.p1.hero.get_hp(), 40.0, "wounded mid-match")
	ms.apply_balance(_make_config())        # live reload, same bound
	ms.drain_signals()
	assert_eq(ms.p1.hero.get_hp(), 40.0, "reload PRESERVES current hp — never a free heal")
	ms.apply_balance(_make_config({"max_hp": 25.0}))  # reload with a smaller bound
	ms.drain_signals()
	assert_eq(ms.p1.hero.get_max_hp(), 25.0, "shrunk hp bound re-injected")
	assert_eq(ms.p1.hero.get_hp(), 25.0, "current hp CLAMPED into the smaller bound")


## AC 5: a mid-match reload must not disturb an in-flight window; the new duration takes
## effect only at the next start().
func test_mid_match_reload_keeps_in_flight_window_duration() -> void:
	var ms := _make_match()
	ms.apply_balance(_make_config({"attack_windup_seconds": 0.1}))  # 6 ticks
	assert_eq(ms.balance_ticks.attack_windup_ticks, 6)
	var w := ms.p1.hero.windup
	w.start(ms.balance_ticks.attack_windup_ticks)
	w.tick()
	w.tick()  # 2 of 6 elapsed
	ms.apply_balance(_make_config({"attack_windup_seconds": 0.2}))  # 12 ticks
	assert_eq(w.remaining_ticks(), 4, "in-flight window keeps its original duration")
	w.tick()
	w.tick()
	w.tick()
	assert_true(w.is_running, "still running at 5/6")
	w.tick()
	assert_false(w.is_running, "finished on the ORIGINAL 6-tick duration")
	w.start(ms.balance_ticks.attack_windup_ticks)
	assert_eq(w.remaining_ticks(), 12, "next start() picks up the new duration")
	ms.drain_signals()
