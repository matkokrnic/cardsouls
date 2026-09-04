extends TestCase

## Story 5-2: mode (2) — UNBLOCKABLE INITIATION. The dispatch arm and its S6 gate, the spend and
## the CHARGING entry, the rooted uncancellable chargeup, and the landing check that reads an
## untethered every-tick reach fact on the exact tick the timer expires.
##
## WHY A NEW FILE RATHER THAN test_card_play.gd (the story leaves the choice to the dev pass and
## asks for it to be named): the chain this covers is a DURATION, not a cast. Half of it —
## rooting, regen suppression, auto-aim, the death branches, the landing — happens ticks after the
## cast and has nothing to do with mode (1)'s one-tick resolution, which is what test_card_play.gd
## is organised around (its own fixture authors no stamina economy and no durations at all). The
## BASIC-mode regression AC 3 demands is the one thing that lives in both worlds, and it is
## asserted HERE against a fixture that can actually get a hero into ROLLING and BLOCKING — which
## test_card_play.gd's cannot.
##
## FIXTURE SHAPE. Every quantity is distinct from every other so an off-by-one lands on a wrong
## number instead of coinciding with a right one: chargeup 24 ticks, stamina 40 with a 20 cost
## (exactly half, so "spent once" and "spent twice" are 20 and 0), damage 10.0 against 100.0 hp,
## draw delay 30 ticks so the vacated slot is observably a HOLE rather than instantly refilled.
##
## THE `unblockable` LAYER FLAG IS INJECTED OPEN by default (`5-2/R13`) and parameterised on
## `_make_match`, because a null `flags` reads as CLOSED and every mode (2) test here would
## otherwise refuse before reaching the behaviour it is about.
##
## THE REACH FACT IS PUSHED BY HAND, exactly as the runner pushes it: `push_contact` with one of
## the two CHARGE-REACH kinds, before `advance()`. That is the real seam and the real ordering —
## these tests drive no runner, and the fact being ABSENT is itself one of the cases under test.

const SEED := 5252
const DECK_SIZE := 8
const HAND_SIZE := 4
const CARD_COST := 3.0
const START_MANA := 10.0
const MAX_HP := 100.0
const MAX_STAMINA := 40.0
const UNBLOCKABLE_COST := 20.0
const CHARGEUP_TICKS := 24
const REGEN_DELAY_TICKS := 12
const DRAW_DELAY_TICKS := 30
const UNBLOCKABLE_DAMAGE := 10.0   # 10 % of 100.0 max hp
const REACH := 8.0

## The planar TARGET -> ATTACKER direction the runner would compute (the 1-8 convention). Facing
## must come back as its NEGATION.
const FACT_DIR := Vector2(0.0, 1.0)


# --- AC 1 / AC 7: dispatch and the CHARGING entry ---------------------------------------------

## AC 1 and AC 7 together, on the cast tick: an UNBLOCKABLE commit reaches a real arm (it does not
## trip the guarded stub — a stub hit would print INVARIANT VIOLATED, which run_all.sh's grep gate
## fails the whole suite on) and the hero is CHARGING on that same tick, through a direct
## `set_action_state` at the cast seat rather than through a TRANSITION_TABLE row.
func test_an_unblockable_commit_enters_charging_on_the_cast_tick() -> void:
	var ms := _make_match()
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "precondition: IDLE")
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"CHARGING on the very tick the cast resolved (mode (2) goes live at INITIATION, Ruling 1)")


## AC 7/AC 8's structural half, asserted here as well as re-proven by test_action_state.gd: the
## entry mechanism added NO table row. If a later story reaches for the table instead, this fails
## beside that one rather than leaving the mechanism claim to a comment.
func test_charging_entry_added_no_transition_table_row() -> void:
	assert_false(HeroState.TRANSITION_TABLE.has(&"charging"),
		"CHARGING still has NO row (AC 7, `5-2/R7`): the card layer drives this edge directly, so "
		+ "the zero-inbound-CHARGING guard in test_action_state.gd stays true UNEDITED (AC 8)")


# --- AC 6: the spend --------------------------------------------------------------------------

## AC 6 in one tick, as five separate facts because they are five separate mutations and a partial
## resolution must not read as a pass.
func test_the_cast_spends_stamina_discards_the_card_and_owes_a_replacement() -> void:
	var ms := _make_match()
	var before := ms.p1.hand.to_array()
	var played_expected: StringName = before[2]
	var announcements: Array = []
	ms.p1.cards_changed.connect(
		func(_ids: Array[StringName], _d: int, _x: int) -> void: announcements.append(true))
	_advance(ms, _unblockable_intent(2), InputIntent.new())
	assert_eq(ms.p1.stamina.get_current(), MAX_STAMINA - UNBLOCKABLE_COST,
		"the stamina price was spent through the pool (40 - 20)")
	assert_false(ms.p1.hand.occupied_ids().has(played_expected), "the card LEFT the hand")
	assert_eq(ms.p1.discard.to_array(), [played_expected] as Array[StringName],
		"...and landed in the discard, that card and only that card")
	assert_eq(ms.p1.pending_draw_owed, [2] as Array[int],
		"a replacement is OWED, to the slot the cast vacated (AC 6)")
	assert_true(ms.p1.pending_draw.is_running, "...and its window is in flight")
	assert_eq(announcements.size(), 1, "notify_cards_changed() fired exactly once")


## AC 6: the spend is PER-PLAYER, which is structural rather than checked — the seat is reached
## once per player with that player's own pool.
##
## THE REGEN-DELAY RESTART IS NOT ASSERTED HERE, deliberately and with its reason: the spend passes
## `balance_ticks.stamina_regen_delay_ticks` exactly as the roll, attack and deflect seats do, but
## its effect is UNOBSERVABLE from outside — AC 14 suppresses regen for the whole of CHARGING, so
## the delay window and the suppression cannot be told apart by any sequence of ticks. Asserting it
## would need a source scan standing in for a behaviour, which is the weaker guard.
func test_the_stamina_spend_is_per_player() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_true(ms.p1.stamina.get_current() < MAX_STAMINA, "precondition: stamina was spent")
	assert_eq(ms.p2.stamina.get_current(), MAX_STAMINA,
		"the OPPOSING pool is untouched — the spend is per-player")


# --- AC 5: no mana, no orbs, no CastEvaluator -------------------------------------------------

## AC 5 (`5-2/R2`) in its strongest observable form: a hero with ZERO mana, against a fixture in
## which every card costs 3.0, casts mode (2) SUCCESSFULLY. If `CastEvaluator.refusal_reason` ran
## anywhere on this path the cast would refuse with `insufficient_mana` and this fails.
func test_an_unblockable_cast_ignores_mana_entirely() -> void:
	var ms := _make_match(0.0)
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: rejections.append([action, reason]))
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(rejections, [], "no refusal of any kind at zero mana")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "the cast resolved")
	assert_eq(ms.p1.mana.get_current(), 0.0, "and NOTHING was taken from the mana pool")


## The other side of AC 5: stamina affordability is the ONE cost refusal, and it refuses through
## the shipped seam with the shipped reason. Nothing is spent and nothing enters CHARGING.
func test_insufficient_stamina_refuses_through_the_shipped_seam() -> void:
	var ms := _make_match()
	ms.p1.stamina.spend(MAX_STAMINA - 1.0, 0)   # 1.0 left against a 20.0 price
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: rejections.append([action, reason]))
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", &"insufficient_stamina"]],
		"refused on action_rejected with the shipped stamina vocabulary")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "no CHARGING entry")
	assert_eq(ms.p1.discard.size(), 0, "the card stayed in the hand — nothing was spent")
	assert_true(ms.p1.stamina.get_current() >= 1.0,
		"...and the pool never went DOWN: a refused cast charges nothing (the 1-4 fallthrough, "
		+ "never deflect's degrade)")


# --- AC 5 / `5-2/R13`: the layer flag ---------------------------------------------------------

## `5-2/R13` (amending `5-2/R2`): mode (2) is a gameplay LAYER and must be switchable off, per
## project-context's feature-flag HARD RULE. A closed `unblockable` flag refuses through the shipped
## seam with the shipped reason and spends NOTHING -- the insufficient-stamina fallthrough shape
## exactly, because there is no degraded unblockable to fall back to.
func test_a_closed_unblockable_flag_refuses_and_spends_nothing() -> void:
	var ms := _make_match(START_MANA, false)
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: rejections.append([action, reason]))
	var hand_before := ms.p1.hand.to_array()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", CastEvaluator.REASON_FLAG_CLOSED]],
		"refused on the shipped action_rejected seam with the shipped REASON_FLAG_CLOSED token")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "no CHARGING entry")
	assert_eq(ms.p1.stamina.get_current(), MAX_STAMINA, "no stamina was spent")
	assert_eq(ms.p1.hand.to_array(), hand_before, "no card left the hand")
	assert_eq(ms.p1.discard.size(), 0, "...and none reached the discard")
	assert_eq(ms.p1.pending_draw_owed, [] as Array[int], "no replacement is owed")
	assert_eq(ms.to_snapshot()["p1"]["telegraph"], [PlayerState.NO_TELEGRAPH_COLOR, 0],
		"and NO telegraph exists — a refused cast publishes nothing for `5-3` to render")


## The other direction, which is what stops the test above passing against an implementation that
## simply never casts: the SAME fixture with the one bit flipped resolves normally.
func test_an_open_unblockable_flag_still_casts() -> void:
	var ms := _make_match(START_MANA, true)
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: rejections.append([action, reason]))
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(rejections, [], "no refusal with the layer open")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "the cast resolved")
	assert_eq(ms.p1.stamina.get_current(), MAX_STAMINA - UNBLOCKABLE_COST, "and the cost was paid")


## The gate is SPECIFIC to mode (2), exactly as the S6 gate is (AC 3). A BASIC cast is unaffected by
## the `unblockable` toggle -- it is a different layer, and closing E5 must not silently disable
## mode (1). This is the "confirm the existing flag behaviour on the BASIC path is unchanged" half
## of `5-2/R13`, asserted rather than assumed.
func test_a_closed_unblockable_flag_does_not_touch_basic_casts() -> void:
	var ms := _make_match(START_MANA, false)
	_advance(ms, _basic_intent(0), InputIntent.new())
	assert_eq(ms.p1.discard.size(), 1,
		"a BASIC cast resolves with the unblockable layer switched OFF")
	assert_eq(ms.p1.mana.get_current(), START_MANA - CARD_COST,
		"...through the unchanged mana path")


## `5-2/R2`'s SURVIVING half, re-proven now that a flag reading exists on this path: the layer gate
## did NOT arrive by routing through `CastEvaluator`. With the layer OPEN and mana at ZERO the cast
## still resolves, so no `refusal_reason` call was smuggled in beside the flag check.
func test_the_layer_gate_did_not_reintroduce_a_mana_reading() -> void:
	var ms := _make_match(0.0, true)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"open layer + zero mana still casts — `5-2/R2`'s mana and orb exclusions stand unchanged")


# --- AC 2: the S6 gate ------------------------------------------------------------------------

## AC 2 (`5-2/R11`): the three states the story NAMES, each refused with the named reason, and each
## asserted to have spent nothing. Driven through real presses so the hero is genuinely in the
## state at the moment the step-6 cast is evaluated.
func test_mode_two_is_refused_while_rolling_blocking_or_attacking() -> void:
	for action: StringName in [&"roll", &"block", &"attack"]:
		var ms := _make_match()
		var rejections: Array = []
		ms.p1.hero.action_rejected.connect(
			func(a: StringName, r: StringName) -> void: rejections.append([a, r]))
		var intent := _unblockable_intent(0)
		intent.pressed[action] = true
		intent.held[action] = true
		_advance(ms, intent, InputIntent.new())
		assert_ne(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
			"pressing %s and committing mode (2) on one tick must not enter CHARGING" % action)
		assert_true(rejections.has([&"card_cast", MatchState.REASON_UNBLOCKABLE_COMMITTED]),
			"refused with the named S6 reason while %s (got %s)" % [action, rejections])
		assert_eq(ms.p1.discard.size(), 0, "nothing was played while %s" % action)


## The FOURTH refused state, which AC 2 does not name and this dev pass added on the AC's own
## stated reason (a duration effect that roots the hero needs a reachability gate). Without it a
## second commit mid-chargeup spends a second card and a second 20 stamina, restarts the window,
## and overwrites the live telegraph.
func test_mode_two_is_refused_while_already_charging() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(
		func(a: StringName, r: StringName) -> void: rejections.append([a, r]))
	var stamina_after_first := ms.p1.stamina.get_current()
	_advance(ms, _unblockable_intent(1), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_UNBLOCKABLE_COMMITTED]],
		"a second commit mid-chargeup is refused with the same named reason")
	assert_eq(ms.p1.discard.size(), 1, "only the FIRST card was ever played")
	assert_eq(ms.p1.stamina.get_current(), stamina_after_first,
		"...and no second 20 stamina was taken")


## AC 3: the gate is SPECIFIC to mode (2) and `BASIC` stays UNGATED. This is the behaviour the
## operator observed at the 3-5a smoke, ratified as correct by `5-2/R11` — a BASIC cast is an
## instant summon that interrupts nothing, so the card layer keeps running parallel to melee.
func test_basic_mode_still_casts_while_rolling_and_blocking() -> void:
	for action: StringName in [&"roll", &"block"]:
		var ms := _make_match()
		var intent := _basic_intent(0)
		intent.pressed[action] = true
		intent.held[action] = true
		_advance(ms, intent, InputIntent.new())
		assert_eq(ms.p1.discard.size(), 1,
			"a BASIC cast still resolves while %s (AC 3 — NOT a residual gap)" % action)
		assert_eq(ms.p1.mana.get_current(), START_MANA - CARD_COST,
			"...through the unchanged mana path")


# --- AC 10 / AC 20: the window and its exact-tick exit ----------------------------------------

## AC 10 and AC 20: the chargeup runs for exactly the authored tick count, and the hero is still
## CHARGING on the tick before it ends. A test that only checked "it eventually exits" would pass
## against a window of any length.
func test_the_chargeup_exits_on_the_exact_authored_tick() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS - 1:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"still CHARGING one tick before the authored end")
	_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"back to IDLE on the exact tick the timer ended (AC 20)")


# --- AC 11 / AC 12: rooting and auto-aim ------------------------------------------------------

## AC 11 (`5-2/R5`): HARD-rooted. Full move input, and the resolved velocity is an exact zero —
## not a scaled value, which is what a multiplier field would have produced.
func test_the_hero_is_hard_rooted_for_the_whole_chargeup() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS - 1:
		var moving := InputIntent.new()
		moving.move_dir = Vector2(1.0, 0.0)
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, moving, InputIntent.new())
		assert_eq(ms.p1.hero.velocity, Vector3.ZERO,
			"velocity is an exact zero under full move input while CHARGING")


## AC 12 (Ruling 3/Ruling 8): facing tracks the enemy HERO, derived from the charge-reach fact's
## own direction. Asserted as the NEGATION of the pushed target-to-attacker vector, so a sign
## error fails rather than passing on symmetry.
func test_facing_auto_aims_at_the_enemy_hero_while_charging() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.facing, -FACT_DIR,
		"facing is the hero -> enemy heading, i.e. the negation of the fact's target -> attacker "
		+ "direction")


# --- AC 13: no interruption -------------------------------------------------------------------

## AC 13 (Ruling 4): taking damage mid-chargeup does not interrupt it. The hero takes the hit and
## the attack still lands on schedule.
func test_damage_taken_mid_chargeup_does_not_interrupt_it() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in 3:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	ms.p1.hero.take_damage(25.0)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"still CHARGING immediately after the hit")
	for _t in CHARGEUP_TICKS - 3:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "it ended ON SCHEDULE")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"...and the attack still landed")


# --- AC 14: regen suppression -----------------------------------------------------------------

## AC 14 (`5-2/R4`): stamina regen is suppressed for the whole of CHARGING. Proven by contrast
## against the same pool at the same reading over the same tick count while IDLE — a test that
## only asserted "it did not reach maximum" would pass against a slow faucet.
func test_stamina_does_not_regenerate_while_charging() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	var at_entry := ms.p1.stamina.get_current()
	for _t in CHARGEUP_TICKS - 1:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.stamina.get_current(), at_entry,
		"not one tick of regen arrived during the chargeup")
	# ...and the faucet is REAL: the same pool, IDLE, over the same number of ticks, refills.
	var idle := _make_match()
	idle.p1.stamina.spend(UNBLOCKABLE_COST, 0)
	var idle_before := idle.p1.stamina.get_current()
	for _t in CHARGEUP_TICKS - 1:
		_advance(idle, InputIntent.new(), InputIntent.new())
	assert_true(idle.p1.stamina.get_current() > idle_before,
		"the suppression test is non-vacuous — an IDLE hero's pool DOES refill over these ticks")


# --- AC 17 / AC 18 / AC 19: the landing check -------------------------------------------------

## AC 17 and AC 18: inside reach at expiry lands, for exactly the authored percentage of the
## TARGET's own maximum.
func test_inside_reach_at_expiry_lands_the_authored_damage() -> void:
	var ms := _make_match()
	var landed: Array = []
	ms.hit_landed.connect(
		func(a: int, t: int, d: float, _hp: float) -> void: landed.append([a, t, d]))
	_run_chargeup(ms, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"10 %% of the target's 100.0 maximum came off (AC 18)")
	assert_eq(landed, [[0, 1, UNBLOCKABLE_DAMAGE]],
		"and it announced on the shipped hit_landed seam, once, with the attacker and target slots")


## AC 19: outside reach at expiry does nothing to either hero — and the card and the stamina STAY
## SPENT, which is the half that makes the boundary real rather than decorative (`E5-P/R4`).
func test_outside_reach_at_expiry_does_nothing_but_the_cost_stays_paid() -> void:
	var ms := _make_match()
	var landed: Array = []
	ms.hit_landed.connect(
		func(a: int, t: int, d: float, _hp: float) -> void: landed.append([a, t, d]))
	_run_chargeup(ms, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "no damage")
	assert_eq(ms.p1.hero.get_hp(), MAX_HP, "...and nothing came off the attacker either")
	assert_eq(landed, [], "no hit_landed")
	assert_eq(ms.p1.discard.size(), 1, "the card stays spent")
	assert_true(ms.p1.stamina.get_current() < MAX_STAMINA,
		"...and so does the stamina: the pool never returned to full, so the 20 was NOT refunded "
		+ "when the attack missed (the miss is discovered at LANDING — `E5-P/R4`'s \"spacing still "
		+ "matters\" reading, where the boundary is real rather than decorative)")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "the hero still exits (AC 20)")


## AC 17's load-bearing negative: ABSENCE of a fact is NOT "outside". Nothing is pushed at all, and
## the landing must not resolve as a hit — but the state that made that decision is
## `REACH_UNKNOWN`, a THIRD value, not the OUTSIDE the previous test drives. A design that defaulted
## the latch to OUTSIDE would pass the previous test and this one identically and would be wrong;
## what this pins is that no measurement was ever taken and none was invented.
func test_an_absent_reach_fact_lands_nothing() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS:
		_advance(ms, InputIntent.new(), InputIntent.new())   # nothing pushed, ever
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "an unmeasured relation lands nothing")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "and the hero still exits")


## The freshness property `5-2/R6` bought by refusing the probe's cadence: the answer that decides
## the landing is the one measured AT EXPIRY, not one measured earlier in the window. The hero is
## inside reach for eleven of twelve ticks and outside on the twelfth — and misses.
func test_the_landing_reads_the_answer_from_the_expiry_tick_only() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS - 1:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP,
		"leaving reach on the LAST tick is the escape (`E5-P/R4`) — eleven ticks inside do not "
		+ "buy the hit")


## ...and the same fixture in the other direction, so the test above cannot pass against an
## implementation that simply never lands.
func test_arriving_inside_reach_on_the_expiry_tick_lands() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS - 1:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"arriving inside reach on the expiry tick lands the hit")


## AC 17's seam half: a CHARGE-REACH fact LATCHES and never joins the contact queue, so it can
## never resolve as a strike at step 4. Asserted by consequence — an inside-reach fact pushed while
## nothing is charging deals no damage on any later tick.
func test_a_charge_reach_fact_never_resolves_as_a_strike() -> void:
	var ms := _make_match()
	for _t in 5:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP,
		"a charge-reach fact is not a strike and deals nothing through the step-4 ladder")


# --- AC 15 / AC 16: death during the chargeup -------------------------------------------------

## AC 15 (`5-2/R3`): a hero that dies mid-chargeup resolves to nothing and STAYS DEAD. The
## forced-DEAD idiom (`set_action_state(DEAD)` with `_round_over` left FALSE) is what makes this
## non-vacuous — in natural play the round-over freeze would return before step 2.
func test_a_hero_that_dies_mid_chargeup_lands_nothing_and_stays_dead() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	ms.p1.hero.set_action_state(HeroState.ActionState.DEAD)
	for _t in CHARGEUP_TICKS + 2:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.DEAD,
		"the corpse is NOT returned to IDLE by the chargeup exit (the F3 finding, closed)")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "and no landing check ran")
	assert_eq(ms.p1.discard.size(), 1, "the card stays spent — AC 6 already ran")


## AC 16: an enemy that died before the timer expired takes no damage. Driven by killing the enemy
## OUTRIGHT one tick before expiry, so the guard is exercised on a hero whose hp is genuinely zero
## rather than one merely flagged DEAD.
func test_a_dead_enemy_is_not_damaged_by_a_landing() -> void:
	var ms := _make_match()
	var landed: Array = []
	ms.hit_landed.connect(
		func(_a: int, _t: int, d: float, _hp: float) -> void: landed.append(d))
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS - 1:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	ms.p2.hero.take_damage(MAX_HP)
	assert_false(ms.p2.hero.is_alive(), "precondition: the enemy is dead before the expiry tick")
	_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(landed, [], "no damage is applied to a dead hero (AC 16)")
	assert_eq(ms.p1.discard.size(), 1, "the card stays spent on the charging hero's side")


# --- AC 4 / AC 21: the colour seam and the telegraph fact -------------------------------------

## AC 21 (`5-2/R9`): while CHARGING the per-player snapshot carries the active telegraph — the
## spent card's COLOUR and the REMAINING TIME IN TICKS — and it is on `PlayerState.to_snapshot()`,
## the pinned key set, not on the hero.
func test_the_snapshot_carries_the_active_telegraph_while_charging() -> void:
	var ms := _make_match()
	# READ BEFORE THE CAST: the cast VACATES the slot, and with a 30-tick draw delay authored the
	# slot holds a HOLE for the rest of this test — a marker the colour map has no entry for.
	var played := _dealt(ms, 0)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	var telegraph: Array = ms.to_snapshot()["p1"]["telegraph"]
	assert_eq(int(telegraph[0]), int(_colors()[played]),
		"the colour is the SPENT CARD's, read through the AC 4 injection seam")
	assert_eq(telegraph[1], CHARGEUP_TICKS,
		"the remaining time is in TICKS, and the window has not been advanced yet on the cast tick")
	assert_false(ms.to_snapshot()["p1"]["hero"].has("telegraph"),
		"it is a PER-PLAYER key, NOT a hero one (AC 21 is explicit — a hero seat would move the "
		+ "golden without moving the pinned set)")


## The countdown is real, and the resting value is restored the moment the chargeup ends. A
## telegraph that stayed lit after the landing would be a fact `5-3` would render forever.
func test_the_telegraph_counts_down_and_rests_after_the_landing() -> void:
	var ms := _make_match()
	assert_eq(ms.to_snapshot()["p1"]["telegraph"], [PlayerState.NO_TELEGRAPH_COLOR, 0],
		"resting before any cast")
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(int(ms.to_snapshot()["p1"]["telegraph"][1]), CHARGEUP_TICKS - 1,
		"one tick of the window has been consumed")
	for _t in CHARGEUP_TICKS - 1:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.to_snapshot()["p1"]["telegraph"], [PlayerState.NO_TELEGRAPH_COLOR, 0],
		"and RESTING again the moment the hero left CHARGING — the key is derived from the action "
		+ "state, so a stale telegraph is unrepresentable rather than merely unlikely")


## AC 4: the colour seam is the source, and it is per-card rather than global. The fixture authors
## one RED card among BLUEs; casting that slot telegraphs RED.
func test_the_telegraph_colour_is_the_spent_cards_own() -> void:
	var colors := _colors()
	var observed: Dictionary = {}
	for slot in HAND_SIZE:
		var ms := _make_match()
		var expected: int = int(colors[_dealt(ms, slot)])
		_advance(ms, _unblockable_intent(slot), InputIntent.new())
		assert_eq(int(ms.to_snapshot()["p1"]["telegraph"][0]), expected,
			"slot %d telegraphs ITS OWN card's colour" % slot)
		observed[expected] = true
	assert_true(observed.size() >= 2,
		"NON-VACUITY: the dealt hand must span more than one colour, or a hardcoded constant would "
		+ "pass every assertion above (observed %d)" % observed.size())


## AC 4's seam contract: `src/state/` still never reads a `CardData`. The map that crosses the
## boundary carries plain ids and plain enum values, and the id itself never reaches the hash.
func test_the_injected_colour_map_never_reaches_the_snapshot() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	var text := str(ms.to_snapshot())
	for id in _deck_contents():
		assert_false(text.contains(str(id)),
			"card id %s must not appear anywhere in the snapshot — the COLOUR crosses, the id "
			% id + "does not")


# --- helpers ----------------------------------------------------------------------------------

func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("ub_card_%02d" % i))
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = CARD_COST
		out[id] = c
	return out


## Colours ALTERNATE by deck index, so "the telegraph is THIS card's colour" is separable from "the
## telegraph is whatever colour the fixture happens to use": a four-card hand dealt off an
## eight-card deck of alternating colours spans both, and the test that needs that asserts it rather
## than assuming it. A single odd-one-out card was tried first and left the dealt hand monochrome
## under this seed, which made the per-card claim vacuous — measured, not guessed.
func _colors() -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	var ids := _deck_contents()
	for i in ids.size():
		out[ids[i]] = Enums.CardColor.RED if i % 2 == 0 else Enums.CardColor.BLUE
	return out


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.max_mana = 90.0
	c.max_stamina = MAX_STAMINA
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	c.stamina_regen_per_second = 6.0
	c.stamina_regen_delay_seconds = float(REGEN_DELAY_TICKS) / TimingWindow.TICK_HZ
	c.roll_stamina_cost = 5.0
	c.attack_stamina_cost = 5.0
	c.deflect_stamina_cost = 5.0
	c.attack_windup_seconds = 0.5
	c.attack_active_seconds = 0.1
	c.attack_recovery_seconds = 0.2
	c.roll_duration_seconds = 0.5
	c.roll_iframe_seconds = 0.2
	c.roll_distance = 3.0
	c.deflect_window_seconds = 0.1
	c.draw_replacement_delay_seconds = float(DRAW_DELAY_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_stamina_cost = UNBLOCKABLE_COST
	c.unblockable_chargeup_seconds = float(CHARGEUP_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_reach = REACH
	c.unblockable_damage_percent_of_max_hp = 10.0
	return c


## A match with a dealt hand, full stamina and mana on the board. The deal happens at step 6 of the
## FIRST advance(), so one tick is run here — the test_card_play.gd fixture idiom exactly, plus the
## colour channel this story adds.
func _make_match(mana := START_MANA, unblockable_open := true) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	# Story 5-2 (`5-2/R13`): the LAYER FLAG is injected, and it has to be -- a null `flags` reads as
	# CLOSED, so every mode (2) test in this file would refuse without it. Injected in the runner's
	# own order (flags before content), and parameterised so the closed-layer test drives the same
	# fixture with the one bit flipped rather than building a second one.
	ms.inject_feature_flags(_flags(unblockable_open))
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	ms.inject_card_colors(_colors())
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()
	ms.p1.mana.add(mana)
	ms.p2.mana.add(mana)
	ms.drain_signals()
	return ms


## The injected FeatureFlags. Only the bit under test is parameterised; everything else stays at the
## resource's own defaults, so this fixture never silently turns another layer on.
func _flags(unblockable_open: bool) -> FeatureFlags:
	var f := FeatureFlags.new()
	f.unblockable = unblockable_open
	return f


func _unblockable_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.UNBLOCKABLE
	i.card_commit = true
	return i


func _basic_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.BASIC
	i.card_commit = true
	return i


## The runner's every-tick charge-reach push, by hand and through the real seam: attacker is that
## slot's HERO, target is the enemy HERO, and the kind carries the inside/outside answer.
func _push_reach(ms: MatchState, slot: int, kind: int) -> void:
	var player: PlayerState = ms.p1 if slot == 0 else ms.p2
	ms.push_contact([slot, TargetingService.HERO_INDEX],
		[1 - slot, TargetingService.HERO_INDEX], player.hero.attack_index, FACT_DIR, kind)


## Cast on slot 0 and run the whole chargeup out, pushing `kind` on every tick of it.
func _run_chargeup(ms: MatchState, kind: int) -> void:
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS:
		_push_reach(ms, 0, kind)
		_advance(ms, InputIntent.new(), InputIntent.new())


## The id the deal actually put in `slot` — read rather than assumed, so no assertion depends on
## what the seeded shuffle happened to do.
func _dealt(ms: MatchState, slot: int) -> StringName:
	return ms.p1.hand.to_array()[slot]


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
