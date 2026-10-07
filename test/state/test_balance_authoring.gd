extends TestCase

## Story 1-3b AC 3: PERMANENT authoring audit over the REAL data/balance/balance_config.tres
## (deliberately not a mock — this guards what ships). The 1-3 phase mechanism derives attack
## phases from which window is running and degenerates on 0-tick phases, so a zero-authored
## ACTION duration is a config authoring DEFECT, not a tuning choice. The audit enforces
## authored non-zero; it never supplies values.
##
## Story 5-6 (AC 4) REMOVES THE `stun_seconds` EXEMPTION this header used to carry. That exemption
## rested entirely on "no E1 code path ever starts the stun window, so a zero there is inert" —
## which stopped being true the moment `E5-P/R1` resolved OPEN decision (a) and `5-6` gave `STUNNED`
## its two inbound edges. The field itself is gone too, split at `5-6` into `color_counter_stun_seconds`
## and `deflect_stun_seconds` -- and the first of that pair is itself retired at 6-6b post-smoke
## (R-S6), the counter having knocked the attacker down since 6-6b AC 4. What remains is audited
## below in its OWN bespoke function rather than joining ACTION_SECONDS_FIELDS (see that constant).
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
## recovery/chain window, deflect window, roll iframe/duration).
##
## Story 5-6 (AC 4): THE TWO STUN DURATIONS DO NOT JOIN THIS LIST, and the reason is scope rather
## than exemption. This list is "every action `*_seconds` duration THE 1-3 MACHINE CONSUMES", i.e.
## the ATTACKING phase machine; a stun is not a 1-3 phase. Neither later duration family joined it
## either — the `5-2` chargeup / `5-5` defense-window pair each took its own bespoke function — and
## this story follows that same precedent instead of widening this constant's stated scope. The two
## stuns are audited (positivity AND their directional order) in
## test_authored_stun_values_are_positive_and_correctly_ordered below.
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
	assert_true(config.unblockable_stamina_cost > 0.0,
		"unblockable_stamina_cost must be authored > 0 (a free unblockable is the roll precedent "
		+ "again, on the FOURTH spend seat — story 5-2, `5-2/R4`)")
	# Story 5-6 (AC 4): the SIXTH line of this class. Not a spend seat — a PUNITIVE DRAIN
	# (`StaminaPool.add(-x)`, AC 10) — but the same defect-by-construction argument applies verbatim:
	# a zero silently disarms `E5-P/R1`'s whole attacker consequence while every other audit stays
	# green, exactly as a zero `attack_stamina_cost` silently disarms the anti-spam lever.
	assert_true(config.deflect_stamina_penalty > 0.0,
		"deflect_stamina_penalty must be authored > 0 (a zero penalty silently disarms `E5-P/R1` — "
		+ "the deflected attacker pays nothing and the ladder's melee tier ships invisible)")


## Story 6-7 (AC 13): the two-gait system's three new fields — positivity in the defect-by-
## construction class PLUS the two directional bounds AC 13 names, not merely `>= 0.0`
## (E1_BALANCE_FIELDS's blanket non-negativity check above).
##   * walk_speed 0.0 freezes the hero at empty stamina with no gait left to fall back to (the R6
##     latch's whole point is that RUN degrades to something, not to nothing).
##   * walk_speed > move_speed would invert the two-gait premise itself — WALK is never faster
##     than RUN, exactly the `5-5`/`5-6` "both directions asserted" precedent applied here.
##   * run_resume_stamina_percent <= 0.0 would make the R6 latch resume before it can ever be
##     observed set; > 100.0 would make it never resume at all.
func test_authored_gait_values_are_positive_and_correctly_ordered() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.walk_speed > 0.0,
		"walk_speed must be authored > 0 (a zero walk speed freezes the hero at empty stamina with "
		+ "no gait to fall back to)")
	assert_true(config.walk_speed <= config.move_speed,
		"walk_speed must be authored <= move_speed (WALK is never faster than RUN, the whole "
		+ "premise of the two-gait system)")
	assert_true(config.run_resume_stamina_percent > 0.0 and config.run_resume_stamina_percent <= 100.0,
		"run_resume_stamina_percent must be authored in (0, 100] — <= 0 resumes the R6 latch before "
		+ "it can ever be observed set, and > 100 would make it never resume")


## Story 5-2 (AC 6/AC 10/AC 17/AC 18): the other THREE unblockable numbers, audited in the
## defect-by-construction class rather than exempted, because a 0.0 in any of them ships the story
## INVISIBLE rather than merely untuned — which is exactly the class `draw_replacement_delay_seconds`
## joined at 3-5b and for the same stated reason.
##   * chargeup 0.0 s derives 0 ticks, `TimingWindow.start(0)` never runs, and the attack lands on
##     the tick it was cast — no telegraph window exists at all, so `5-3` has nothing to render and
##     `5-5`/`5-6` have no window to answer against. The whole read exchange collapses.
##   * reach 0.0 makes every landing check answer OUTSIDE (planar distance is never <= 0 between two
##     bodies that cannot occupy one point), so the attack can never land and the boundary
##     `E5-P/R4` calls "the escape" is the whole board.
##   * damage 0.0 lands a hit that takes nothing off, which is a miss wearing a hit's clothes.
func test_authored_unblockable_values_are_positive() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.unblockable_chargeup_seconds > 0.0,
		"unblockable_chargeup_seconds must be authored > 0 (a zero chargeup lands on the cast tick "
		+ "and there is no telegraph window at all)")
	# Story 6-1c (AC 5): the one reach became three, and the bound goes with each -- a zero radius in
	# ANY colour makes that colour's attack unable to land, the same defect for one third of the deck.
	# (The per-colour ARC bound that stood beside it retired with the arc at story 7-8, `7-8/R8`.)
	# These are BOUNDS, not pins: any authored value inside them passes, so tuning the feel knobs never
	# needs this file.
	for color: int in [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN]:
		assert_true(config.unblockable_reach_for(color) > 0.0,
			"the colour-%d unblockable reach must be authored > 0 (a zero reach can never be "
			% color + "satisfied — that colour's attack could never land)")
	assert_true(config.unblockable_damage_percent_of_max_hp > 0.0,
		"unblockable_damage_percent_of_max_hp must be authored > 0 (a landed hit that takes "
		+ "nothing off is a miss wearing a hit's clothes)")


## Story 5-4 (AC 3/AC 9): the TWO orb numbers, in the same defect-by-construction class as the three
## above and for the same stated reason -- a 0 in either ships the story INVISIBLE rather than merely
## untuned, and the `>= 0` loop in test_data_resources.gd passes on the 0 script default.
##   * a 0 grant makes every landed unblockable pay nothing, so the whole payout half of the RGB read
##     exchange is dead machinery that `5-5`/`5-6` have no earned orbs to answer against.
##   * a 0 cap clamps every colour to zero at the FIRST injection, which is the same outcome reached
##     from the other end -- orbs are granted and immediately clamped away, with the grant path
##     looking healthy the whole time.
func test_authored_orb_economy_values_are_positive() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.unblockable_orb_grant > 0,
		"unblockable_orb_grant must be authored > 0 (a landed unblockable that pays no orb leaves "
		+ "the payout half of the read exchange dead)")
	assert_true(config.max_orbs_per_color > 0,
		"max_orbs_per_color must be authored > 0 (a zero cap clamps every grant away at the first "
		+ "injection, which looks exactly like a working faucet paying into a hole)")


## Story 5-5 (AC 6/AC 14): the TWO mode ③ numbers, in the same defect-by-construction class as the
## unblockable three and the orb two above, and for the same stated reason -- a 0.0 in either ships
## the story INVISIBLE rather than merely untuned, and the `>= 0.0` loop in test_data_resources.gd
## passes on the 0.0 script default.
##   * a 0.0 window derives 0 ticks, `TimingWindow.start(0)` never runs, and `is_running` is false at
##     every landing -- so no defense cast could EVER negate anything. The cast still spends the card
##     and the stamina, so the machinery looks healthy from every angle except the one that matters.
##   * a 0.0 cost makes defending free, which is the roll precedent again on the FIFTH spend seat:
##     an answer with no price is not a read exchange, it is a button to hold.
##
## THE RELATIONAL BOUND IS ALSO ASSERTED, unlike the unblockable family's: R-A and R-D both state
## DIRECTIONS rather than values (the window LONGER than the chargeup, the cost SMALLER than the
## unblockable's), and a bare `> 0` would pass on an authored pair that inverted either one. These
## are PROVISIONAL starting points the live smoke judges -- the assertions pin the DIRECTION the
## operator ratified, not the numbers.
func test_authored_defense_values_are_positive_and_correctly_ordered() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.defense_stamina_cost > 0.0,
		"defense_stamina_cost must be authored > 0 (a free defense is the roll precedent again, on "
		+ "the FIFTH spend seat)")
	# Story 6-6b POST-SMOKE (R-S6): THE WINDOW-LENGTH BOUND IS GONE WITH THE FIELD IT BOUNDED.
	# `defense_window_seconds` -- the `5-5` one-size pre-arm, and the `> chargeup + longest launch`
	# relation the 6-1c review widened -- is retired outright: the counter window is each colour's
	# own busy span now (audited in the function below), and a bound on a field nothing reads was a
	# true statement about nothing. NOTHING REPLACES IT, and that is the ruling rather than a gap:
	# "still open when the attack lands" stopped being something the defender pre-arms.
	assert_true(config.defense_stamina_cost < config.unblockable_stamina_cost,
		"defense_stamina_cost must be authored SMALLER than unblockable_stamina_cost (R-D): the "
		+ "defender answers a commitment already made rather than making one")


## Story 6-6b (AC 1/AC 2/AC 9), POST-SMOKE (R-S1/R-S2/R-S4/R-S6): THE COLOUR COUNTER'S SIX TUNABLES,
## on the function directly above's template exactly -- positivity in the defect-by-construction
## class, plus the one bound that is a DIRECTION rather than a value.
##
## THE NUMBERS ARE FEEL KNOBS AND ARE DELIBERATELY NOT PINNED (AC 2 says so in as many words; the
## post-smoke pass cut all three busy spans and re-sized both travel distances without touching this
## file, which is `BC/R3` working). What survives is only what a zero or an inversion would BREAK:
##   * a 0.0 BUSY span for a colour derives 0 ticks, `TimingWindow.start(0)` never runs, and that
##     colour's press opens no window at all -- no counter window, no busy time, no presentation;
##   * a 0.0 TRAVEL DISTANCE for RED or BLUE ships that colour's whole travel half invisible: BLUE's
##     slide never arrives and RED's jump stomps the spot it started on, which is exactly what the
##     live smoke found and what R-S1/R-S2 exist to fix;
##   * RED's FORWARD FRACTION must lie strictly INSIDE (0, 1): at 0 the jump never goes out, at 1 the
##     backflip never comes back, and either way the out-and-back profile is not a profile at all.
##
## THE `busy > eligibility > 0` BOUND IS GONE WITH THE ELIGIBILITY SPAN (R-S6). The whole busy span
## is the counter window now, so there is no head left to be shorter than the span containing it.
func test_authored_counter_values_are_positive_and_correctly_ordered() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.counter_travel_distance_red > 0.0,
		"counter_travel_distance_red must be authored > 0 (a zero distance leaves RED stomping the "
		+ "spot it started on -- the live-smoke finding R-S1 exists to fix)")
	assert_true(config.counter_travel_distance_blue > 0.0,
		"counter_travel_distance_blue must be authored > 0 (a zero distance ships BLUE's slide "
		+ "invisible -- it never reaches the attacker it is answering)")
	assert_true(config.counter_travel_forward_fraction_red > 0.0
			and config.counter_travel_forward_fraction_red < 1.0,
		"counter_travel_forward_fraction_red must be authored strictly INSIDE (0, 1): at 0 RED never "
		+ "travels out, at 1 it never comes back (got %f)"
				% config.counter_travel_forward_fraction_red)
	# Read off the three authored spans through the SAME per-colour lookup the state layer uses, so
	# a colour the lookup forgot lands here as a zero rather than being silently skipped.
	var ticks := BalanceTicks.from_config(config)
	for color: int in [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN]:
		assert_true(ticks.counter_busy_ticks_for(color) > 0,
			("colour %d: counter_busy_ticks must survive the seconds->ticks boundary as at least "
			+ "one tick -- a zero span opens no window, so that colour can never counter") % color)


## Story 5-6 (AC 4): THE TWO STUN DURATIONS, on the function directly above's template exactly --
## positivity in the defect-by-construction class, PLUS the directional bound the ratified ruling
## states rather than merely implies.
##   * a 0.0 stun derives 0 ticks, `TimingWindow.start(0)` never runs, and the step-3 timer arm
##     (AC 12) returns the hero to IDLE on the very tick it was stunned. The window start and the
##     `STUNNED` write both still happen, so the mechanism looks healthy from every angle except the
##     one that matters -- the punish lasts no time at all. "0-tick stuns degenerate the mechanism"
##     applies to both durations exactly as it would inside ACTION_SECONDS_FIELDS.
##   * THE DIRECTION IS THE HALF A BARE `> 0` WOULD MISS. `E5-P/R1`'s own text
##     (`decision-log.md:8142-8144`) requires the colour counter's ~1s to be MARKEDLY LONGER than the
##     melee deflect's "so the three-tier ladder keeps its escalation gradient". An authored pair that
##     INVERTED that gradient -- a heavier punish for the easier read -- would ship a broken ladder
##     with every other audit green, which is the `5-5` "both directions asserted, not just `> 0`"
##     precedent (there: `defense_stamina_cost < unblockable_stamina_cost`) applied a second time.
##     These are PROVISIONAL starting points the live smoke judges -- the assertion pins the
##     DIRECTION, not the numbers. POST-SMOKE (R-S6) the pair it was written about is a pair no
##     longer: the gradient asserted below is `knockdown > deflect`.
func test_authored_stun_values_are_positive_and_correctly_ordered() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	# Story 6-6b POST-SMOKE (R-S6): THE MIDDLE RUNG IS RETIRED. `color_counter_stun_seconds` and the
	# `> deflect` bound it carried went with it: since 6-6b AC 4 the colour counter KNOCKS THE
	# ATTACKER DOWN rather than stunning it, so the ladder's top rung IS the counter's punish and the
	# gradient that remains is `knockdown > deflect`, asserted in ticks below. `E5-P/R1`'s reasoning
	# is not overturned, it is satisfied by a heavier consequence than the one it authored.
	assert_true(config.deflect_stun_seconds > 0.0,
		"deflect_stun_seconds must be authored > 0 (a 0-tick stun ends on the tick it began -- the "
		+ "melee tier's whole attacker consequence, shipped invisible)")
	# Story 6-6a (AC 4): THE THIRD STUN AND THE FULL THREE-WAY BOUND, ASSERTED IN TICKS. Seconds alone
	# under-test it: two distinct authored second-values can round to the SAME tick count through
	# `seconds_to_ticks`, and the tick count is what the state layer runs and what
	# `BalanceTicks.is_knockdown_stun` compares -- two equal counts would silently merge two flavors.
	# The seconds-domain line above stays as the authoring-intent half; these are the enforcement half.
	assert_true(config.knockdown_stun_seconds > 0.0,
		"knockdown_stun_seconds must be authored > 0 (a 0-tick knockdown never runs, and the "
		+ "flavor classifier then treats nothing as a knockdown)")
	var ticks := BalanceTicks.from_config(config)
	assert_true(ticks.knockdown_stun_ticks > ticks.deflect_stun_ticks,
		"knockdown_stun_ticks (%d) must be LONGER than deflect_stun_ticks (%d) — AC 4's bound, "
		% [ticks.knockdown_stun_ticks, ticks.deflect_stun_ticks]
		+ "in ticks: the knockdown flavor is told apart by duration alone, so two equal counts "
		+ "would silently merge the two flavors that remain")
	# Story 6-6a (AC 8): the get-up iframes, in the defect-by-construction class -- a 0-tick window never
	# opens, so the timer exit would arm nothing and the get-up could be timed into after all.
	assert_true(config.get_up_iframe_seconds > 0.0,
		"get_up_iframe_seconds must be authored > 0 (a 0-tick window arms nothing on the get-up)")


## Story 5-3's `test_the_charge_clip_speeds_still_describe_the_authored_chargeup` RETIRED here
## (6-1b, finding 6): it guarded `AnimationController.CHARGE_CLIP_SPEED` /
## `CHARGE_ALIGNED_CHARGEUP_SECONDS`, both retired by 6-1b's re-tempo (a per-tick driven playhead
## replaces the uniform `custom_speed` compression these constants described). Guarding them here
## after they are dead code would be the vacuous-guard class this project rules out.
##
## THE COUPLING DUTY ITSELF IS DISCHARGED BY CONSTRUCTION, not replaced by an equivalent guard:
## the new mapping (`AnimationController.charge_playhead_seconds`) takes unitless PROGRESS
## (0..1), never a duration, so no animation-side constant is derived from
## `unblockable_chargeup_seconds` any more, and a retune of that field needs no re-derivation
## anywhere in this file's reach. `test/integration/test_charge_playhead_live.gd` proves that
## claim rather than merely asserting it: it drives a real `CHARGING` session off the LIVE
## authored `unblockable_chargeup_ticks` and asserts the playhead lands on the measured strike
## frame at the window's last tick — a test that keeps passing across a chargeup retune instead
## of one that turns red and demands a re-derivation. The pure-mapping endpoint pin lives in
## `test/state/test_charge_playhead_mapping.gd` (AC 11).


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
	# Story 4-4 (AC 5/AC 6, `4-4/R12`): THE SPEED BOUND IS PER KIND AND IS NO LONGER `> 0` FOR EVERY
	# KIND. `4-4/R12` rules all three TOTEM kinds to speed 0 — the GDD's "small, unimposing static
	# structure" — so a blanket `> 0` audit would forbid the very authoring the ruling mandates. The
	# bound splits: the MINION kind keeps `> 0` for 4-3's reason verbatim, every kind is
	# non-negative, and every TOTEM kind is audited `== 0` so AC 5 is machine-checked rather than
	# merely intended.
	var minion := _kind(config, &"minion")
	assert_not_null(minion, "the authored config must carry a `minion` kind")
	if minion == null:
		return
	assert_true(minion.move_speed > 0.0,
		"the minion kind's move_speed must be authored > 0 (a zero speed ships 4-3 invisible — the "
		+ "unit rotates to face its target and never closes, which is the 4-2 behaviour it replaces)")
	for kind: UnitKindProfile in config.unit_kinds:
		assert_true(kind.move_speed >= 0.0, "%s move_speed is non-negative" % kind.kind_name)
		assert_true(kind.stop_distance > 0.0,
			("%s stop_distance must be authored > 0 (a zero distance walks the unit into its target "
			+ "until the two bodies wedge, which reads as a physics glitch, not as an approach) — "
			+ "authored for every kind including ones that never move, per AC 6's 'no field is left "
			+ "undefined for a kind'") % kind.kind_name)


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
	# Story 4-4 (AC 6/AC 9): PER KIND. `max_hp` keeps its `> 0` bound for EVERY kind — a zero
	# maximum summons something already dead whatever kind it is — and the hits-to-kill BAND is now
	# audited per kind against `hero_damage_to_unit`, which is the hero-attacker successor of the
	# flat `unit_damage_per_hit` this test used to read.
	assert_true(config.hero_damage_to_unit > 0.0,
		"hero_damage_to_unit must be authored > 0 (a zero flat damage ships the invulnerable box "
		+ "`4-3a` exists to replace — a unit that can be hit forever and never dies)")
	assert_true(config.unit_kinds.size() > 0,
		"the authored config must carry unit kinds, or every per-kind audit here is vacuous")
	for kind: UnitKindProfile in config.unit_kinds:
		assert_true(kind.max_hp > 0.0,
			("%s max_hp must be authored > 0 (a zero maximum summons a unit that is already dead — "
			+ "the first fact drops at the liveness rung and the kind ships invisible)")
					% kind.kind_name)
		var hits_to_kill := ceili(kind.max_hp / config.hero_damage_to_unit)
		assert_true(hits_to_kill >= 2,
			("%s takes %d hero swing(s) to kill — must be >= 2; a one-shot unit makes its authored "
			+ "max_hp cosmetic, the exact failure `4-3a/R8` rejected the percent-of-max formula for")
					% [kind.kind_name, hits_to_kill])
		assert_true(hits_to_kill <= 10,
			("%s takes %d hero swings to kill — must be <= 10; beyond that a kill stops being the "
			+ "legible, decisive event `4-3a` ships") % [kind.kind_name, hits_to_kill])
		# AC 6's completeness clause, machine-checked: "every kind's value for a field it does not
		# use for anything ... is still authored and NON-NEGATIVE — no field is left undefined for a
		# kind". A kind that never attacks still authors a damage; it is audited non-negative, not
		# positive, because 0.0 is the honest authoring for a totem that makes no contact.
		var attack := kind.attack_at(0)
		if attack != null:
			assert_true(attack.damage >= 0.0, "%s attack damage is non-negative" % kind.kind_name)


## ---- Corpse lifetime (story 6-5b, AC 2, `6-5b/R2`) -------------------------------------
##
## AUDITED > 0 for the failure the `>= 0.0` reflection loop in test_data_resources.gd structurally
## cannot see, which is the same failure `unblockable_chargeup_seconds` and
## `draw_replacement_delay_seconds` carry their own bespoke bounds against: `field in config` and
## `>= 0.0` BOTH pass on the 0.0 script default, and a zero authored lifetime makes every death leave
## a corpse that is already expired. Grave Ward would extend nothing, Raise Dead would raise nothing,
## the Culling -> Raise Dead loop this story exists for would be unreachable, and the whole feature
## would ship invisible in the build with the full suite green.
##
## THE UPPER BOUND IS AUDITED TOO, on `minion_retarget_interval_seconds`' precedent rather than as a
## taste judgement: the corpse's actor is a solid-until-disabled grey box the runner keeps in the tree
## for the whole lifetime, so an absurd authored value is a population leak with a playable-looking
## number in front of it. 120 s is deliberately loose -- six times the authored 20 s -- because this
## bound exists to catch a misplaced decimal point, not to hold the tuning.
func test_authored_corpse_lifetime_is_positive_and_bounded() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.corpse_lifetime_seconds > 0.0,
		"corpse_lifetime_seconds must be authored > 0 (a zero ships every corpse already expired: "
		+ "Grave Ward extends nothing, Raise Dead raises nothing, and the Culling -> Raise Dead loop "
		+ "is unreachable, all with the suite green)")
	assert_true(config.corpse_lifetime_seconds <= 120.0,
		"corpse_lifetime_seconds must be authored <= 120 s -- a corpse holds a real actor in the tree "
		+ "for its whole lifetime, so a misplaced decimal point is a population leak")


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
	# Story 4-4 (AC 6/AC 9/AC 10): PER KIND, AND ONLY FOR KINDS THAT ACTUALLY ATTACK. A kind
	# authoring an EMPTY attack list is the honest shape for the two accelerator totems (AC 3: "the
	# accelerators never attack"), so it is skipped rather than failed — but a kind that DOES author
	# an attack must author a playable one, for the three reasons stated in this test's header.
	for kind: UnitKindProfile in config.unit_kinds:
		var attack := kind.attack_at(0)
		if attack == null:
			continue
		assert_true(attack.windup_seconds > 0.0,
			("%s windup_seconds must be authored > 0 (a zero derives 0 ticks and the phase "
			+ "completes on the tick it starts — no readable windup at all)") % kind.kind_name)
		assert_true(attack.active_seconds > 0.0,
			("%s active_seconds must be authored > 0 (a zero-tick active window never flags the "
			+ "hitbox, so the swing can never land a fact)") % kind.kind_name)
		assert_true(attack.recovery_seconds > 0.0,
			("%s recovery_seconds must be authored > 0 (a zero recovery makes the rhythm the "
			+ "unit's only limiter meaningless)") % kind.kind_name)
		assert_true(attack.range > 0.0,
			("%s attack range must be authored > 0 (a zero range is never satisfied, so the unit "
			+ "never leaves idle)") % kind.kind_name)
		assert_true(attack.cadence_seconds >= 0.0,
			("%s cadence_seconds is non-negative (0 is the legitimate back-to-back authoring every "
			+ "minion ships with, so this bound is NOT > 0)") % kind.kind_name)
		# THE REACH-VERSUS-STOP-DISTANCE BOUND APPLIES TO MELEE RECORDS ONLY, and the narrowing is
		# `4-4/R1`'s consequence rather than a weakening. The bound exists because a unit WALKS to
		# `stop_distance` and must then be in reach; a PROJECTILE record's range is a FIRING range
		# on a kind that never walks at all (`4-4/R12`, speed 0), and it is deliberately far longer
		# than the stop distance. Applying the melee bound there would assert something true by
		# accident and hide the real one.
		if attack.projectile == null:
			assert_true(attack.range >= kind.stop_distance,
				("%s melee range (%.2f) must be >= its stop_distance (%.2f) — a unit halts at the "
				+ "stop distance, so a shorter reach parks it permanently outside its own reach and "
				+ "the kind ships invisible with every test green")
						% [kind.kind_name, attack.range, kind.stop_distance])


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
##
## STORY 4-4 (AC 6): PER KIND NOW, and audited for EVERY kind rather than once — which is strictly
## more coverage than the three flat globals had, and is the point of the conversion.
func test_authored_minion_attack_move_speed_multipliers_are_non_negative() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	for kind: UnitKindProfile in config.unit_kinds:
		for field in [&"attack_windup_move_speed_multiplier",
				&"attack_active_move_speed_multiplier",
				&"attack_recovery_move_speed_multiplier"]:
			assert_true(float(kind.get(field)) >= 0.0,
				"%s.%s must be non-negative (0.0 = full root is the authored design)"
						% [kind.kind_name, field])


## ---- The shipped KIND SET (story 4-4, AC 1) ---------------------------------------------
##
## THE FOUR KINDS AC 6 NAMES ARE AUDITED BY NAME, AND SO IS THEIR ORDER. A unit record stores its
## kind as a plain INT INDEX into `BalanceConfig.unit_kinds` (never the StringName — see
## `UnitBoard._kind_index`), so reordering the authored list silently renames every existing
## record's kind and would repoint a saved replay's units at the wrong profiles. The order is
## therefore part of the authored contract, and this is where that is said out loud.
##
## THE NAMES MUST MATCH `CardEffectResolver.SUMMON_KINDS`'s VALUES, or a totem card would resolve to
## a kind name `BalanceConfig` does not author and put NOTHING on the board — loudly by absence
## (which is the designed failure), but with the card silently dead. That cross-file agreement is the
## one this test exists to hold, so it reads the resolver's own table rather than a second literal.
func test_authored_unit_kinds_cover_every_summon_kind_in_a_pinned_order() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	var names: Array[StringName] = []
	for kind: UnitKindProfile in config.unit_kinds:
		assert_not_null(kind, "no authored kind slot may be null — indices must stay stable")
		names.append(kind.kind_name)
	assert_eq(names, [&"minion", &"combat_totem", &"mana_accelerator", &"stamina_accelerator"],
		"the authored kind list and ITS ORDER are the contract a record's stored kind INDEX means; "
		+ "reordering renames every existing record's kind")
	# Every kind the resolver can name must exist, plus the unmapped default it falls back to.
	for kind_name: StringName in CardEffectResolver.SUMMON_KINDS.values():
		assert_true(config.kind_index_of(kind_name) != BalanceConfig.NO_KIND_INDEX,
			("CardEffectResolver maps a summon id to kind `%s`, which the authored config does not "
			+ "carry — that card would resolve successfully and put nothing on the board")
					% kind_name)
	assert_true(config.kind_index_of(CardEffectResolver.KIND_MINION) != BalanceConfig.NO_KIND_INDEX,
		"the unmapped-summon default kind must be authored, or every minion card is inert")


## ---- The three TOTEM kinds (story 4-4, AC 5/AC 8/AC 10, `4-4/R1`/`4-4/R9`/`4-4/R12`) ------
##
## AC 5 / `4-4/R12` MACHINE-CHECKED: all three totem kinds author movement speed 0, "not only the
## two accelerators". This is the one place that ruling is enforced rather than merely honoured — a
## retune that gave the Combat totem a walking speed would otherwise pass every other test.
##
## AC 8 / `4-4/R9` MACHINE-CHECKED: the Combat totem names a HERO-PREFERRING priority that is
## NEITHER `standard` NOR the test-only `hero_seeker`, and the named profile must actually exist in
## `data/minions/` AND actually prefer the hero. Naming a profile that does not exist would leave
## the totem permanently targetless; naming one that does not prefer the hero would silently undo
## `4-4/R9`'s rationale (projectile avoidance is designed for a target that can roll).
##
## AC 3 MACHINE-CHECKED: the two accelerators author NO attack at all, and the Combat totem attacks
## only via a projectile.
func test_authored_totem_kinds_are_static_and_correctly_prioritised() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	for kind_name in [&"combat_totem", &"mana_accelerator", &"stamina_accelerator"]:
		var kind := _kind(config, kind_name)
		assert_not_null(kind, "the authored config must carry a `%s` kind" % kind_name)
		if kind == null:
			continue
		assert_eq(kind.move_speed, 0.0,
			("%s must author move_speed 0 (`4-4/R12`: ALL THREE totem kinds are static, not only "
			+ "the two accelerators — the GDD's 'small, unimposing static structure')") % kind_name)
	var combat := _kind(config, &"combat_totem")
	if combat == null:
		return
	assert_ne(combat.priority_name, TargetingService.PRIORITY_STANDARD,
		"AC 8: the Combat totem authors a NEW priority, not a reuse of `standard`")
	assert_ne(combat.priority_name, &"hero_seeker",
		"AC 8: the Combat totem authors a NEW priority, not a reuse of the TEST-ONLY `hero_seeker`")
	var priority := TargetingService.priority_named(
		TargetingService.authored_priorities(), combat.priority_name)
	assert_not_null(priority,
		("the Combat totem names priority `%s`, which `data/minions/` does not author — the totem "
		+ "would be permanently targetless and never fire") % combat.priority_name)
	if priority == null:
		return
	assert_true(priority.prefer_hero,
		("`%s` must PREFER THE HERO (`4-4/R9`: projectile avoidance is designed for a target that "
		+ "can roll, and a unit cannot)") % combat.priority_name)
	for kind_name in [&"mana_accelerator", &"stamina_accelerator"]:
		var accelerator := _kind(config, kind_name)
		if accelerator != null:
			assert_false(accelerator.has_attack(),
				"AC 3: %s must author NO attack — the accelerators never attack" % kind_name)
	assert_true(combat.has_attack(), "AC 10: the Combat totem authors exactly one attack record")
	assert_eq(combat.attacks.size(), 1,
		"AC 9 Non-Goal: every kind ships exactly ONE attack record this story")
	assert_not_null(combat.attack_at(0).projectile,
		"AC 3/AC 14: the Combat totem attacks ONLY via its projectile")


## ---- The Combat totem's projectile (story 4-4, AC 10/AC 15/AC 19, `4-4/R1`/`4-4/R2`) ------
##
## THE 8 M FIRING RANGE AND THE 60 M TRAVEL BUDGET ARE AUDITED SEPARATELY AND AGAINST EACH OTHER,
## which is AC 19's own requirement: they are "a distinct authored number" governing "a different
## thing (total travel budget vs. whether the totem may fire at all)". A build that collapsed them
## into one number would make a shot expire at the edge of the firing range and never reach a target
## that stepped back, and nothing else in the suite would notice.
##
## THE ARENA BOUNDS ARE WHERE BOTH VALUES COME FROM (`4-4/R1`, `4-4/R2`), so they are audited against
## the arena rather than against themselves: the range must stay WELL INSIDE the 40 m span (a totem
## whose threat radius covered the arena would not be a placed structure at all), and the budget must
## clear the ~56.57 m diagonal so a corner-to-corner shot can complete.
const ARENA_SPAN := 40.0
const ARENA_DIAGONAL := 56.5685424949238

func test_authored_projectile_profile_is_playable() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	var combat := _kind(config, &"combat_totem")
	if combat == null or combat.attack_at(0) == null:
		assert_true(false, "the Combat totem must author an attack record to audit")
		return
	var attack := combat.attack_at(0)
	var projectile := attack.projectile
	assert_not_null(projectile, "the Combat totem's attack must author a projectile")
	if projectile == null:
		return
	assert_true(attack.range > 0.0 and attack.range < ARENA_SPAN * 0.5,
		("the firing range (%.2f) must be > 0 and well inside the %.0f m arena span (`4-4/R1`) — a "
		+ "range covering the arena makes the totem's placement decide nothing")
				% [attack.range, ARENA_SPAN])
	assert_true(attack.cadence_seconds > 0.0,
		"AC 10: the Combat totem authors its OWN firing cadence > 0 (a zero cadence degrades it to "
		+ "the minion's back-to-back cycle and AC 10's number would decide nothing)")
	assert_true(projectile.travel_budget >= ARENA_DIAGONAL,
		("the travel budget (%.2f) must clear the arena's ~%.2f m diagonal (`4-4/R2`) so a "
		+ "corner-to-corner shot can complete") % [projectile.travel_budget, ARENA_DIAGONAL])
	assert_true(projectile.travel_budget > attack.range,
		("AC 19: the travel budget (%.2f) and the firing range (%.2f) are DISTINCT numbers "
		+ "governing different things — a budget at or below the range expires every shot that "
		+ "chases a target which stepped back") % [projectile.travel_budget, attack.range])
	assert_true(projectile.launch_speed > 0.0,
		"launch_speed must be authored > 0 (a zero launch with zero acceleration never leaves the "
		+ "totem, and AC 14's 'distinct entity that travels' ships invisible)")
	assert_true(projectile.homing_turn_rate_degrees_per_second >= 0.0,
		"the homing turn rate is non-negative (0 is the honest 'flies straight' authoring)")
	assert_true(projectile.homing_turn_rate_degrees_per_second > 0.0,
		"AC 15: the SHIPPED profile must actually home (> 0), or AC 16/AC 17's homing-end rules "
		+ "guard behaviour the build never exhibits")
	assert_true(projectile.acceleration_per_second_squared >= 0.0,
		"acceleration is non-negative (0 is the honest 'constant speed' authoring)")
	assert_true(projectile.acceleration_per_second_squared > 0.0,
		"AC 15: the SHIPPED profile must actually accelerate (> 0)")
	assert_true(projectile.acceleration_delay_seconds >= 0.0,
		"the acceleration delay is non-negative (0 means accelerating from launch)")
	assert_true(projectile.max_speed >= projectile.launch_speed,
		("max_speed (%.2f) must be >= launch_speed (%.2f) — a lower ceiling would DECELERATE a "
		+ "projectile the profile says accelerates")
				% [projectile.max_speed, projectile.launch_speed])


## ---- M7: the derived projectile speed cannot reach zero (story 5-1, AC 10, `5-1/R3`) -------
##
## THIS IS A NAMED REGRESSION GUARD, NOT A FIX. `4-4` M7 (`_44-review.md:416`, "zero or negative
## derived projectile speed makes a shot immortal") was independently audited at 5-1's readiness gate
## and found ALREADY CLOSED: under the bounds `test_authored_projectile_profile_is_playable` asserts
## directly above (`launch_speed > 0`, `acceleration >= 0`, `max_speed >= launch_speed`), every
## branch of `MatchState._speed_at_flight_ticks` returns `>= launch_speed > 0`, and the only `0.0`
## return is the null-profile branch, which `_advance_projectiles` consumes before the speed function
## is ever called. No gap existed to close. The finding is DISCHARGED-AS-ALREADY-CLOSED, and what
## ships here is the assertion that keeps it closed.
##
## IT WALKS THE CURVE RATHER THAN RE-ASSERTING THE BOUNDS. Re-checking `launch_speed > 0` would only
## restate the test above; the claim M7 actually makes is about the DERIVED value at every point of
## the flight, so this evaluates the shipped arithmetic tick by tick across a full budget's worth of
## travel — through the acceleration delay boundary and past `max_speed` saturation — and asserts the
## speed never reaches zero or below at any of them.
func test_the_authored_projectile_speed_curve_never_reaches_zero() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	var combat := _kind(config, &"combat_totem")
	if combat == null or combat.attack_at(0) == null or combat.attack_at(0).projectile == null:
		assert_true(false, "the Combat totem must author a projectile to audit")
		return
	var projectile := combat.attack_at(0).projectile
	var delay_ticks := int(round(projectile.acceleration_delay_seconds * TimingWindow.TICK_HZ))
	if projectile.launch_speed <= 0.0:
		assert_true(false,
			("`4-4` M7 regressed: authored `launch_speed` must be > 0.0 — the budget-ticks sweep "
			+ "divides by it, and a zero or negative launch speed makes the derived curve "
			+ "unrunnable (got %.3f)") % projectile.launch_speed)
		return
	# A full budget's worth of flight at the SLOWEST speed the curve can produce, so the sweep
	# outlives any shot this profile can launch, plus a margin past the delay boundary in case the
	# authored delay ever exceeds that.
	var budget_ticks := int(ceil(projectile.travel_budget / projectile.launch_speed
			* TimingWindow.TICK_HZ))
	var horizon := maxi(budget_ticks, delay_ticks * 2) + 2
	var slowest := INF
	var slowest_tick := -1
	for ticks in range(0, horizon + 1):
		# `MatchState._speed_at_flight_ticks`' arithmetic, evaluated here against the AUTHORED
		# profile — the state-layer function needs a live board and an index, which an authoring
		# audit has no business standing up.
		var speed := projectile.launch_speed
		if ticks > delay_ticks:
			var accelerating_seconds := float(ticks - delay_ticks) / TimingWindow.TICK_HZ
			speed = minf(projectile.max_speed, projectile.launch_speed
					+ projectile.acceleration_per_second_squared * accelerating_seconds)
		if speed < slowest:
			slowest = speed
			slowest_tick = ticks
	assert_true(slowest > 0.0,
		("`4-4` M7, DISCHARGED-AS-ALREADY-CLOSED and guarded here: the derived speed must stay > 0 "
		+ "across the whole authored curve — the slowest point of %d sampled flight ticks was %.3f "
		+ "at tick %d. A zero or negative derived speed makes a shot that never advances its "
		+ "odometer and therefore never expires: an immortal projectile")
				% [horizon + 1, slowest, slowest_tick])
	assert_eq(slowest, projectile.launch_speed,
		"...and the slowest point of the curve is the LAUNCH speed itself — the profile only ever "
		+ "accelerates, so `launch_speed > 0` (audited above) is what makes the whole curve positive")


## ---- Accelerator working values (story 4-4, AC 20/AC 21, `4-4/R13`) -----------------------
##
## `4-4/R13` MAKES THESE DERIVED, NOT PRINCIPLED: the Mana Accelerator's cadence/amount are set
## relative to the existing `passive_tick` rule and the Stamina Accelerator's factor relative to the
## non-accelerated `stamina_regen_per_second` baseline. So the bounds audited here are RELATIONS to
## those baselines rather than absolute numbers — which is what keeps them playtest-tunable while
## still catching the two silent failures.
##
## THE STAMINA MULTIPLIER IS AUDITED > 1.0, NOT > 0. AC 21 requires the rate to be RAISED ABOVE its
## non-accelerated value; an authored 1.0 ships a totem that does exactly nothing and below 1.0 ships
## one that HARMS its owner, and both pass a `> 0` bound silently.
func test_authored_accelerator_values_are_derived_and_effective() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.mana_accelerator_mana > 0.0,
		"mana_accelerator_mana must be authored > 0 (a zero amount is a dead faucet — the totem "
		+ "ships visible but inert)")
	assert_true(config.mana_accelerator_interval_seconds > 0.0,
		"mana_accelerator_interval_seconds must be authored > 0 (a zero authored cadence derives a "
		+ "clamped 1 tick and pays out EVERY tick, which is not a cadence at all)")
	# `4-4/R13`'s derivation, machine-checked as a BAND against the `passive_tick` baseline it is
	# derived from: stronger than passive (the totem must be worth casting) but the same order of
	# magnitude (it is a faucet, not a win condition).
	var accelerator_per_second := config.mana_accelerator_mana / config.mana_accelerator_interval_seconds
	assert_true(accelerator_per_second > config.mana_regen_per_second,
		("the Mana Accelerator (%.3f mana/s) must out-produce the passive faucet (%.3f mana/s) — "
		+ "`4-4/R13`: 'stronger since totem-gated'")
				% [accelerator_per_second, config.mana_regen_per_second])
	assert_true(accelerator_per_second <= config.mana_regen_per_second * 10.0,
		("the Mana Accelerator (%.3f mana/s) must stay within an order of magnitude of the passive "
		+ "faucet (%.3f mana/s) — `4-4/R13`: 'same order of magnitude'")
				% [accelerator_per_second, config.mana_regen_per_second])
	# Story 5-1 (AC 7, `5-1/R1`/`5-1/R2`): the field is now the ADDITIVE STEP in `1 + N x step`, so
	# the failure this bound catches moved with the semantics. Under the old direct multiplier the
	# do-nothing value was 1.0 and the harmful range was below it; under an additive step the
	# do-nothing value is 0.0 and the harmful range is below THAT. The bound is not relaxed from
	# `> 1.0` to `> 0` — it is re-derived, and `> 1.0` would now reject today's correct `0.5`.
	assert_true(config.stamina_accelerator_regen_step > 0.0,
		("stamina_accelerator_regen_step must be authored > 0 (got %.2f) — AC 21 still requires the "
		+ "owner's regen to be RAISED; under `1 + N x step` a 0.0 step ships a totem that does "
		+ "nothing at every N and a negative one ships one that harms its owner")
				% config.stamina_accelerator_regen_step)
	# `5-1/R1`'s derivation, machine-checked rather than left in prose: ONE totem must reproduce
	# 4-4's shipped factor EXACTLY, so the first accelerator a player summons moves no balance and
	# only the second and third do. An authored step that drifted off 0.5 would silently re-tune the
	# single-totem case this story promised not to touch.
	assert_eq(1.0 + 1.0 * config.stamina_accelerator_regen_step, 1.5,
		"`5-1/R1`: the authored step is DERIVED from `1 + 1 x step = 1.5` (story 4-4's shipped "
		+ "single-totem factor), so N=1 is byte-identical to today and stacking starts at N=2")


## The authored kind carrying `kind_name`, or null. A test-local read of the same lookup
## `BalanceConfig.kind_index_of` performs, expressed as the profile rather than the index because
## every assertion above is about the profile's fields.
func _kind(config: BalanceConfig, kind_name: StringName) -> UnitKindProfile:
	return config.kind_at(config.kind_index_of(kind_name))


## Story 6-1d (AC 8) shipped the swing-at-commit knob OFF and pinned it so; STORY 7-8 SUPERSEDES THE
## AUTHORED HALF (AC 13, `7-8/R4`): the shipped mapping must start every colour's sweep at or after the
## commit. What is pinned is that PROPERTY of the shipped spans and knobs, never the bool: on the commit
## tick -- the first launch tick, pushed with L ticks left -- the runner's composed progress maps each
## colour's playhead to no further than its held pose. The script-default half is unchanged: every
## in-test `BalanceConfig.new()` still inherits OFF, so the unit suite keeps running the linear mapping
## unless a test opts in. Renamed from `test_the_swing_at_commit_knob_is_authored_off`.
func test_the_shipped_mapping_starts_each_sweep_at_or_after_the_commit() -> void:
	assert_false(BalanceConfig.new().unblockable_swing_at_commit,
		"the script default must be OFF -- it is what every in-test config inherits")
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	var ticks := BalanceTicks.from_config(config)
	var c := ticks.unblockable_chargeup_ticks
	for color: int in [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN]:
		var l := ticks.unblockable_launch_ticks_for(color)
		var progress := AnimationController.charge_attack_progress(l, c, l)
		if config.unblockable_swing_at_commit:
			progress = AnimationController.charge_commit_anchored_progress(progress,
					float(c) / float(c + l), AnimationController.charge_hold_end_for(color))
		var knobs: Dictionary = AnimationController._CHARGE_HOLD_KNOBS[color]
		var held: float = AnimationController._CHARGE_STRIKE_FRAME_SECONDS[color] \
				* float(knobs["hold_fraction"])
		var at_commit := AnimationController.charge_playhead_for(color, progress)
		assert_true(at_commit <= held + 0.0001,
			"colour %d: the shipped mapping has the blade at %.4f s on the commit tick, past the held "
				% [color, at_commit] + "pose %.4f s -- the sweep starts before the commit (AC 13)" % held)


## Story 6-2 (AC 9): the Pitch Zone countdown is authored > 0, the `unblockable_chargeup_seconds`
## bespoke bound's reason verbatim: `field in config` and `>= 0.0` both pass on the 0.0 script default, and a 0.0
## derives 0 ticks, so every staged card would fizzle on its own staging tick -- the buildup half of the
## bluff shipped invisible. The PROVISIONAL value (20 s, `E6-P/R5`) is not pinned; the playtest judges it.
func test_authored_pitch_stage_timer_is_positive() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.pitch_stage_timer_seconds > 0.0,
		"pitch_stage_timer_seconds must be authored > 0 (a zero countdown fizzles every staged card "
		+ "on the tick it was staged)")


## Story 6-3b (AC 5): the pitch HUD's countdown push cadence is authored > 0. `field in config` and
## `>= 0.0` both pass on the 0.0 script default, which clamps to 1 tick and ships the `2-6/R7`
## per-tick firehose the authored throttle exists to prevent. The ruled value (0.5 s -> 30 ticks) is
## not pinned here; the conversion test pins the arithmetic.
func test_authored_pitch_countdown_push_interval_is_positive() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_true(config.pitch_countdown_push_interval_seconds > 0.0,
		"pitch_countdown_push_interval_seconds must be authored > 0 (a zero clamps to 1 tick and "
		+ "pushes the countdown to presentation every tick)")


## Story 6-2 (AC 13): THE ORB-CLEAR RULE SHIPS OFF, in BOTH places that can decide it -- the script
## default every in-test config inherits, and the authored `.tres` that ships. The shape of
## `test_the_swing_at_commit_knob_is_authored_off` directly above. UNLIKE that knob this one gates HASHED
## state, so both branches are behaviour-tested in test_pitch_staging.gd; this pin is only about which
## branch ships until the post-E6 playtest deletes the loser.
func test_the_pitch_orb_clear_rule_is_authored_off() -> void:
	assert_false(BalanceConfig.new().pitch_stage_clears_orbs,
		"the script default must be OFF -- it is what every in-test config inherits")
	var config := load(CONFIG_PATH) as BalanceConfig
	assert_not_null(config, "authored balance config loads as BalanceConfig")
	if config == null:
		return
	assert_false(config.pitch_stage_clears_orbs,
		"pitch_stage_clears_orbs ships OFF (AC 12/AC 13: orbs banked before staging count toward READY)")
