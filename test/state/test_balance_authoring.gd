extends TestCase

## Story 1-3b AC 3: PERMANENT authoring audit over the REAL data/balance/balance_config.tres
## (deliberately not a mock — this guards what ships). The 1-3 phase mechanism derives attack
## phases from which window is running and degenerates on 0-tick phases, so a zero-authored
## ACTION duration is a config authoring DEFECT, not a tuning choice. The audit enforces
## authored non-zero; it never supplies values.
##
## EXEMPT: stun_seconds. It is a data-only field until OPEN decision (a) (attacker
## consequence on deflect, decision-log Session 2026-07-22) is resolved — no E1 code path
## ever starts the stun window, so a zero there is inert, not degenerate.
##
## Story 1-4 (D7) adds the NON-DURATION stamina-economy class below, with one exemption:
## EXEMPT: stamina_regen_delay_seconds — 0 is legitimate tuning (no delay), not a defect.
## Story 1-8 (R-N6) LIFTS the deflect_stamina_cost exemption — the field gained its
## consumer, and a free deflect unguards the economy (roll precedent). It also adds the
## defense pair: block_damage_multiplier bounded 0 < m < 1 (0.0 = free total negation
## that obsoletes deflect; >= 1.0 = a no-op or self-harm — defects by construction, not
## tuning) and block_facing_arc_degrees bounded > 0 and <= 360.
##
## The stamina-cost corrective pass (E3-RG/R2) adds attack_stamina_cost to that class, NOT
## exempt: decision (d) is RESOLVED (DP/R2 — the basic attack costs stamina), so a zero there
## is a silently disarmed anti-spam lever, exactly the roll/deflect reasoning.
##
## Story 1-5 (B4) adds the melee-hit economy pair:
## melee_hit_mana must be authored > 0 — a zero faucet is a dead flywheel; the
## melee_mana_generation FLAG is the off-switch, never a zero amount.
## EXEMPT from > 0: attack_move_speed_multiplier — 0.0 (full root) IS the authored design
## value (B6 operator decision), so the audit asserts non-negative only.

const CONFIG_PATH := "res://data/balance/balance_config.tres"

## Every action `*_seconds` duration the 1-3 machine consumes (attack windup/active/
## recovery/chain window, deflect window, roll iframe/duration). stun_seconds is exempt
## (see header) and deliberately absent.
const ACTION_SECONDS_FIELDS: Array[StringName] = [
	&"attack_windup_seconds",
	&"attack_active_seconds",
	&"attack_recovery_seconds",
	&"attack_chain_window_seconds",
	&"deflect_window_seconds",
	&"roll_iframe_seconds",
	&"roll_duration_seconds",
]


func test_authored_action_durations_are_positive() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	for field in ACTION_SECONDS_FIELDS:
		assert_true(float(config.get(field)) > 0.0,
			"%s must be authored > 0.0 (0-tick phases degenerate the 1-3 phase mechanism)" % field)


func test_authored_chain_length_is_at_least_one() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.attack_chain_length >= 1,
		"attack_chain_length must be >= 1 (a sequence needs at least one swing)")


## ---- Non-duration assertion class (story 1-4, D7) — kept separate from the duration ----
## ---- block above; the one remaining exemption (stamina_regen_delay_seconds) in the -----
## ---- file header. ----------------------------------------------------------------------

func test_authored_stamina_economy_values_are_positive() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.max_stamina > 0.0,
		"max_stamina must be authored > 0 (a zero pool locks out every stamina consumer)")
	assert_true(config.stamina_regen_per_second > 0.0,
		"stamina_regen_per_second must be authored > 0 (spent stamina must come back)")
	assert_true(config.roll_stamina_cost > 0.0,
		"roll_stamina_cost must be authored > 0 (a free roll unguards the 1-4 economy)")
	assert_true(config.attack_stamina_cost > 0.0,
		"attack_stamina_cost must be authored > 0 (a free attack is the mashing DP/R2 priced — roll precedent)")


## ---- Melee-hit economy pair (story 1-5, B4) — exemption reasoning in the file header. --

func test_authored_melee_hit_mana_is_positive() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.melee_hit_mana > 0.0,
		"melee_hit_mana must be authored > 0 (a zero faucet is a dead flywheel — the flag is the off-switch)")


## ---- Defense values (story 1-8, R-N6) — bounds reasoning in the file header. -----------

func test_authored_defense_values_are_sane() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.deflect_stamina_cost > 0.0,
		"deflect_stamina_cost must be authored > 0 (exemption LIFTED at 1-8 — a free deflect unguards the economy)")
	assert_true(config.block_damage_multiplier > 0.0 and config.block_damage_multiplier < 1.0,
		"block_damage_multiplier must be authored in (0, 1) — 0.0 obsoletes deflect, >= 1.0 makes block a no-op or self-harm")
	assert_true(config.block_facing_arc_degrees > 0.0 and config.block_facing_arc_degrees <= 360.0,
		"block_facing_arc_degrees must be authored in (0, 360] — the facing gate needs a real arc")


## ---- Roll window bound (story 1-9, 1-9/R3) ----------------------------------------------
## The "iframe is a subset of the roll" premise as a defect-by-construction bound: step-4
## negation is judged on the iframe window ALONE (never on state == ROLLING), so an iframe
## outliving the roll would be invulnerability while walking. Compared in TICKS — the form
## the windows actually run in.

func test_authored_roll_iframe_within_roll_duration() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	var ticks := BalanceTicks.from_config(config)
	assert_true(ticks.roll_iframe_ticks <= ticks.roll_duration_ticks,
		"roll_iframe must not outlive roll_duration in ticks (window-alone negation, 1-9/R3)")


func test_authored_attack_move_speed_multiplier_is_non_negative() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.attack_move_speed_multiplier >= 0.0,
		"attack_move_speed_multiplier must be non-negative (0.0 = full root is the authored design)")
