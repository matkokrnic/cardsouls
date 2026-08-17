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
## EXEMPT from > 0: the attack movement multipliers — 0.0 (full root) IS the authored design
## value (B6 operator decision), so the audit asserts non-negative only. Story 3-0b (AC5)
## splits that single flat field into three per-phase fields; the exemption and its reason
## carry over UNCHANGED to all three, and the audit now covers three fields instead of one.
## EXEMPT from > 0 likewise: attack_lunge_distance (story 3-0b AC6) — a zero lunge is
## legitimate tuning (no lunge), not a degenerate config, so this is the
## stamina_regen_delay_seconds class, not the roll/deflect-cost class. The authored value is
## a non-zero starting magnitude; AC8 tunes it and may legitimately take it to zero.

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


## Story 3-1 (AC 2/AC 6, 3-1/R1): the two NEW mana fields, audited in the same
## defect-by-construction class as the stamina economy rather than the exempt class.
## max_mana: a zero cap makes mana unearnable (ManaPool clamps every add to the maximum) and
## every card uncastable — the same shape as "a zero stamina pool locks out every consumer".
## mana_regen_per_second: 3-1/R1 authored the trio as ONE coherent set against a recorded
## funding criterion (~2-4 buildup->bluff->payoff cycles per round), and the arithmetic behind
## that criterion counts the passive faucet explicitly (~22 mana over 90 s at 0.25/s). A
## zeroed passive would silently break the criterion the values were chosen against, so it is
## audited like stamina_regen_per_second, not exempted like stamina_regen_delay_seconds. A
## future tuning pass that genuinely wants a melee-only economy LIFTS this the way 1-8 lifted
## the deflect_stamina_cost exemption — deliberately, with its reason recorded here.
func test_authored_mana_set_is_positive() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.max_mana > 0.0,
		"max_mana must be authored > 0 (a zero cap clamps every add to nothing — no card is ever castable)")
	assert_true(config.mana_regen_per_second > 0.0,
		"mana_regen_per_second must be authored > 0 (the 3-1/R1 funding criterion counts the passive faucet)")


## Story 3-3 (AC 6): the deck/hand COUNTS, audited in the defect-by-construction class rather
## than the exempt one. deck_size 0 is a match whose players hold no cards at all — the "zero
## stamina pool locks out every consumer" shape. hand_size 0 is a deal that deals nothing, which
## would leave the whole step-6 seat silently inert. The RELATIONAL bound is the third: the fill
## stops at an exhausted pile (no reshuffle ships, AC 11), so a hand_size ABOVE deck_size would
## quietly deal a short hand forever instead of failing — a defect by construction, not tuning.
##
## `3-6/R8` adds a FOURTH bound, closing the code-review finding deferred from 3-6: the HUD's
## own hand row is built from exactly 4 slots (`hud_root.gd::_build_hand_row`, 2-5/R1's
## presentation-local constant), and `HudRoot.on_cards_changed` silently drops any hand_ids
## entry past index 3 rather than erroring. A hand_size of 5 is therefore a defect by
## construction the moment playtest tuning authors one — exactly the class this file exists
## for — so it fails HERE, loudly, instead of the HUD truncating silently at the next launch.
func test_authored_deck_and_hand_counts_are_sane() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.deck_size > 0,
		"deck_size must be authored > 0 (a zero deck is a match with no cards in it)")
	assert_true(config.hand_size > 0,
		"hand_size must be authored > 0 (a zero hand makes the whole deal seat silently inert)")
	assert_true(config.hand_size <= config.deck_size,
		"hand_size must be <= deck_size (no reshuffle ships — an over-large hand deals short forever)")
	assert_true(config.hand_size <= 4,
		"hand_size must be <= 4 (3-6/R8): the HUD hand row is built from exactly 4 slots "
		+ "(2-5/R1) and would silently truncate a larger hand instead of failing loud")


## Story 3-5b (AC 1/AC 2): the two card DURATIONS, audited in the defect-by-construction class —
## the deck_size / hand_size precedent directly above, NOT the exempt stamina_regen_delay_seconds
## class, and the distinction is the whole point of this test existing at all.
##
## `field in config` and the `>= 0.0` loop in test_data_resources.gd BOTH pass on BalanceConfig's
## 0.0 script default. So existence alone is not sufficient, and an implementation that added the
## fields, wired the seats and forgot the .tres would ship this entire story INVISIBLE in the
## build: every replacement would arrive instantly (the 3-5a behaviour it replaces) and every
## vulnerable window would close on the tick it opened. That is exactly the dead field
## balance_config.gd's reservation comment existed to prevent, arriving by a different door.
##
## Zero is still a legal IN-TEST value — the golden isolates the delay's seat from its content by
## pricing it 0.0, and the derived-zero path degrades to the instant refill deliberately. It is the
## AUTHORED value that must be positive.
func test_authored_card_timing_values_are_positive() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.draw_replacement_delay_seconds > 0.0,
		"draw_replacement_delay_seconds must be authored > 0 (a zero delay ships 3-5b invisible — "
		+ "every replacement arrives instantly, which is the 3-5a behaviour it replaces)")
	assert_true(config.reshuffle_vulnerable_window_seconds > 0.0,
		"reshuffle_vulnerable_window_seconds must be authored > 0 (a zero window closes on the "
		+ "tick it opens, leaving 3-6 nothing to render)")


## Story 4-2 (AC 7, `4-2/R5`): the retarget cadence, audited in the defect-by-construction class —
## the `draw_replacement_delay_seconds` precedent directly above, NOT the exempt
## `stamina_regen_delay_seconds` class, and the distinction carries the same weight here.
##
## `field in config`, the `>= 0.0` loop in test_data_resources.gd, and BalanceTicks' own clamp ALL
## pass on the 0.0 script default — and the clamp is precisely what makes the omission dangerous
## rather than loud: an unauthored cadence derives to 1 tick and every unit re-evaluates its target
## EVERY TICK, which is exactly the per-frame-per-unit scan the project-context Performance Rule
## forbids ("target-acquisition scans must NOT run every frame for every unit"). The throttle would
## be shipped INVISIBLE in the build, with nothing failing — the dead-field failure mode
## balance_config.gd's reservation comments exist to prevent, arriving through the door a clamp
## opened.
##
## THE UPPER BOUND IS AUDITED TOO, unlike this field's siblings, and it is not a style preference:
## the Performance Rule names ~0.1-0.25 s as the intended band, and a cadence far above it would
## make a unit visibly unresponsive to a candidate set that has already changed (a target held for a
## second after its owner died). 0.5 s is a deliberately generous ceiling — twice the named band's
## top — so ordinary playtest tuning inside and a little past the band is free, while an authoring
## slip of an order of magnitude fails here instead of at a playtest.
##
## Zero stays a legal IN-TEST value: test_determinism.gd relies on the clamp's defined meaning, and
## test_balance_config.gd asserts it in both directions. It is the AUTHORED value that is bounded.
func test_authored_minion_retarget_interval_is_within_the_throttle_band() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.minion_retarget_interval_seconds > 0.0,
		"minion_retarget_interval_seconds must be authored > 0 (a zero clamps to 1 tick and ships "
		+ "the whole THROTTLE invisible — every unit rescanning every tick, which is what the "
		+ "Performance Rule forbids)")
	assert_true(config.minion_retarget_interval_seconds <= 0.5,
		"minion_retarget_interval_seconds must be authored <= 0.5 s — the Performance Rule's band is "
		+ "~0.1-0.25 s, and this generous ceiling catches an order-of-magnitude authoring slip "
		+ "without constraining ordinary tuning")


## Story 4-3 (AC 2): the approach RATE and the stop DISTANCE, both in the defect-by-construction
## class — the `draw_replacement_delay_seconds` reason verbatim, and it is load-bearing here in a
## way it is not for a duration. This story's ENTIRE positive control depends on these two values
## being real: `field in config` passes on the 0.0 script default, the `>= 0.0` loop in
## test_data_resources.gd passes on it, and half (b) of that file's reflection guard never looks at
## either name (neither carries the `_seconds` suffix that keys the `BalanceTicks` obligation). So
## an implementation that shipped both fields, wired the drive-phase seat and forgot the `.tres`
## would fail NOTHING here — and would ship the mechanic INVISIBLE in the build: a zero speed
## leaves the unit standing where it spawned, rotating to face its target and never closing, which
## is precisely 4-2's shipped behaviour that this story exists to replace.
##
## THIS IS ALSO WHAT MAKES test/integration/test_unit_approach_live.gd NON-VACUOUS from authoring
## rather than from a default: that test measures a live delta against the AUTHORED values, so with
## either field at 0 it fails (a zero speed never moves; a zero stop distance never stops short).
##
## Zero stays a legal IN-TEST value — no golden fixture authors either field (`4-3/R19/N3`) — it is
## the AUTHORED value that must be positive.
func test_authored_minion_approach_values_are_positive() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.unit_move_speed > 0.0,
		"unit_move_speed must be authored > 0 (a zero speed ships 4-3 invisible — the unit rotates "
		+ "to face its target and never closes, which is the 4-2 behaviour it replaces)")
	assert_true(config.unit_stop_distance > 0.0,
		"unit_stop_distance must be authored > 0 (a zero distance walks the unit into its target "
		+ "until the two bodies wedge, which reads as a physics glitch, not as an approach)")


## ---- Minion combat values (story 4-3a, AC 1/AC 2, `4-3a/R8`) ---------------------------
##
## BOTH AUDITED > 0, and each for its own failure. A zero `unit_max_hp` ships a unit that is
## already dead the instant it is summoned — the first contact fact would find `hp <= 0` and drop
## at the liveness rung, so summoning would resolve to a corpse and the whole story would be
## invisible in the build. A zero `unit_damage_per_hit` ships the opposite and equally silent
## failure: a unit that can be hit forever and never dies, which is precisely the invulnerable box
## this story exists to replace.
##
## `field in config` and the `>= 0.0` loop in test_data_resources.gd BOTH pass on this script's 0.0
## defaults, which is why these bespoke bounds exist at all — the `draw_replacement_delay_seconds`
## reason verbatim.
##
## THE RATIO IS AUDITED TOO, and it is the only place the story's "three swings to kill" claim is
## machine-checked. It is stated as a BAND rather than an equality so the `4-3b` melee retune can
## re-tune both values without editing a test: hits-to-kill must be at least 2 (a one-shot minion
## makes the hp field cosmetic — exactly the failure `4-3a/R8` rejected the percentage formula for)
## and at most 10 (beyond that a kill stops being a legible, decisive event, which is this story's
## own stated goal).
##
## Zero stays a legal IN-TEST value for both — no golden fixture authors either field — it is the
## AUTHORED value that must be positive.
func test_authored_minion_combat_values_are_positive() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.unit_max_hp > 0.0,
		"unit_max_hp must be authored > 0 (a zero maximum summons a unit that is already dead — "
		+ "the first fact drops at the liveness rung and the story ships invisible)")
	assert_true(config.unit_damage_per_hit > 0.0,
		"unit_damage_per_hit must be authored > 0 (a zero flat damage ships the invulnerable box "
		+ "this story exists to replace)")
	var hits_to_kill := ceili(config.unit_max_hp / config.unit_damage_per_hit)
	assert_true(hits_to_kill >= 2,
		"authored hits-to-kill must be >= 2 — a one-shot minion makes unit_max_hp cosmetic, the "
		+ "exact failure `4-3a/R8` rejected the percent-of-max formula for (got %d)" % hits_to_kill)
	assert_true(hits_to_kill <= 10,
		"authored hits-to-kill must be <= 10 — beyond that a kill stops being the legible, "
		+ "decisive event this story ships (got %d)" % hits_to_kill)


## ---- Minion attack rhythm (story 4-3b, AC 1/AC 13) -------------------------------------
##
## THREE DURATIONS AUDITED > 0, for the failure the `>= 0.0` reflection loop cannot see: a
## 0.0-authored phase derives 0 TICKS out of `seconds_to_ticks()`, and a phase of zero ticks
## completes on the tick it starts — a minion whose whole rhythm collapses to nothing, swinging
## every tick with no readable windup. Zero stays a legal IN-TEST value (no golden fixture authors
## any of the three); it is the AUTHORED value that must be positive.
##
## THE REACH IS AUDITED AGAINST `unit_stop_distance`, AND THAT BOUND IS THE LOAD-BEARING ONE. A unit
## HALTS at `unit_stop_distance` from its acquired target (`4-3` AC 2), so an authored reach SHORTER
## than the stop distance parks every minion permanently just outside its own reach: no probe fact
## ever reports in-reach, no windup ever begins, and the entire story ships invisible in the build
## with every test still green. This is the `4-3b` twin of the `unit_move_speed > 0` audit and it
## exists for the identical class of silent failure.
##
## NO CEILING ON THE THREE DURATIONS. They are PROVISIONAL by AC 1 and the melee retune (`E3-R/R3`)
## owns the real numbers; a band authored here would be this pass guessing at that block's output.
func test_authored_minion_attack_rhythm_is_playable() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.minion_attack_windup_seconds > 0.0,
		"minion_attack_windup_seconds must be authored > 0 (a zero derives 0 ticks and the phase "
		+ "completes on the tick it starts — no readable windup at all)")
	assert_true(config.minion_attack_active_seconds > 0.0,
		"minion_attack_active_seconds must be authored > 0 (a zero-tick active window never flags "
		+ "the hitbox, so the swing can never land a fact)")
	assert_true(config.minion_attack_recovery_seconds > 0.0,
		"minion_attack_recovery_seconds must be authored > 0 (a zero recovery makes the rhythm the "
		+ "unit's only limiter meaningless — AC 11 has no other gate)")
	assert_true(config.minion_attack_reach_distance > 0.0,
		"minion_attack_reach_distance must be authored > 0 (a zero reach is never satisfied, so no "
		+ "unit ever leaves idle)")
	assert_true(config.minion_attack_reach_distance >= config.unit_stop_distance,
		("minion_attack_reach_distance (%.2f) must be >= unit_stop_distance (%.2f) — a unit halts "
		+ "at the stop distance, so a shorter reach parks it permanently outside its own reach and "
		+ "the story ships invisible with every test green")
				% [config.minion_attack_reach_distance, config.unit_stop_distance])


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


## Story 3-0b (AC5): the flat field's audit, carried onto all three per-phase successors —
## the exemption's reason (0.0 = full root is a design value) is unchanged, so the bound
## stays non-negative rather than > 0. A NEGATIVE multiplier is the defect this catches:
## it would drive the hero BACKWARDS along its own input direction while attacking.
func test_authored_attack_move_speed_multipliers_are_non_negative() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	for field in [&"attack_windup_move_speed_multiplier", &"attack_active_move_speed_multiplier",
			&"attack_recovery_move_speed_multiplier"]:
		assert_true(float(config.get(field)) >= 0.0,
			"%s must be non-negative (0.0 = full root is the authored design)" % field)


## Story 4-3c1 (AC 3, `4-3c/R19`): the MINION-SIDE TWIN of the audit directly above — a separate
## test rather than three more entries in that loop, because the two triplets are deliberately
## separate fields (AC 1) and a shared audit would quietly re-couple them in the one place that is
## supposed to keep them apart.
##
## Same exemption, same reason: 0.0 = full root is the authored design value, so the bound is
## non-negative rather than > 0. A NEGATIVE multiplier is the defect this catches — it would drive
## a minion BACKWARDS, away from the target it is swinging at, for the whole swing.
func test_authored_minion_attack_move_speed_multipliers_are_non_negative() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	for field in [&"minion_attack_windup_move_speed_multiplier",
			&"minion_attack_active_move_speed_multiplier",
			&"minion_attack_recovery_move_speed_multiplier"]:
		assert_true(float(config.get(field)) >= 0.0,
			"%s must be non-negative (0.0 = full root is the authored design)" % field)
