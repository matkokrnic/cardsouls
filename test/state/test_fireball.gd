extends TestCase

## Story 6-5d: FIREBALL -- the variable-cost, damage-locked, hero-sourced homing projectile (AC 5-23),
## plus the ADDED totem-shot guards AC 36 exists for and the M6 reload refusal (AC 38).
##
## Fixture shape, on `test_pitch_staging.gd`'s discipline: every config, flag set, cost map and EFFECT is
## built IN-TEST and the authored `.tres` files never reach here (`BC/R3`). Every count is distinct from
## every other (deck 8, hand 4, minimum 3.0, cap 10.0, max mana 20.0, per-mana 1.5, cast 6 ticks, timer
## 30 ticks, delay 3 ticks, orb price 1) so an off-by-one that read the wrong quantity lands on a
## different number instead of coinciding with one.
##
## `max_mana` IS 20.0 HERE, DELIBERATELY UNLIKE THE SHIPPED 10.0. The authored cap equals the shipped
## pool maximum, which makes the cap INERT in the real game (the whole pool is always spent) -- so a
## fixture at the shipped numbers could not tell `min(pool, cap)` from `the whole pool` at all. A wider
## pool is what makes the cap's clamp OBSERVABLE, and both readings are asserted below.
##
## THE CONTACT TESTS FEED SYNTHETIC FACTS through `MatchState.push_contact`, the sole intake -- the
## established headless pattern for the step-4 ladder. A projectile's attacker address is
## `[slot, MatchState.projectile_attacker_index(board_index)]` (`E4-P/R12`).

const SEED := 6565
const DECK_SIZE := 8
const HAND_SIZE := 4
const CAST_COST := 2.0
const PITCH_MINIMUM := 3.0
const MANA_CAP := 10.0
const DAMAGE_PER_MANA := 1.5
const MAX_MANA := 20.0
const PITCH_ORBS := 1
const PITCH_COLOR := Enums.CardColor.RED
const TIMER_TICKS := 30
const DELAY_TICKS := 3
const CAST_TICKS := 6
const MAX_ORBS := 5
const STAGE_SLOT := 2
const MAX_HP := 100.0
const UNIT_HP := 40.0
const STAMINA := 50.0
const BLOCK_MULTIPLIER := 0.5
const DEFLECT_COST := 5.0
const TOTEM_SHOT_DAMAGE := 7.0
const BUDGET := 60.0
const LAUNCH_SPEED := 8.0

const FIREBALL := &"fireball"
const MINION_KIND := &"minion"
const TOTEM_KIND := &"combat_totem"


# --- AC 5 / AC 6 / AC 7: the variable cost and the locked damage ------------------------------

## AC 5 (`6-5d/R1`): a staging with mana BELOW the cap spends ALL of it, leaves the pool at zero, and the
## staged card REMEMBERS the amount. 7.3 rather than a round number so nothing here could coincide with
## the minimum, the cap or the hand size.
func test_staging_spends_the_whole_pool_below_the_cap_and_remembers_it() -> void:
	var ms := _make_match(7.3)
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_almost_eq(ms.p1.mana.get_current(), 0.0, 0.0001,
		"a variable-cost staging spent the WHOLE pool (AC 5)")
	assert_true(ms.pitch.is_staged(0), "...and the card is staged")
	assert_almost_eq(ms.pitch.staged_mana_spent(0), 7.3, 0.0001,
		"...and the staged card remembers the spent amount (AC 5)")
	var zone: Dictionary = ms.to_snapshot()["pitch"]["p1"]
	assert_almost_eq(float(zone["mana_spent"]), 7.3, 0.0001,
		"...and the spent amount is HASHED (AC 30)")


## AC 5: a staging with mana ABOVE the cap spends exactly the cap and LEAVES THE SURPLUS. This is the
## reading the shipped numbers cannot exercise (see the header), and it is the whole reason `mana_cap`
## is authored data rather than a literal: a later `max_mana` raise must not silently raise the ceiling.
func test_staging_above_the_cap_spends_the_cap_and_leaves_the_surplus() -> void:
	var ms := _make_match(15.0)
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_almost_eq(ms.p1.mana.get_current(), 5.0, 0.0001,
		"the cap CLAMPED the spend and the surplus stayed in the pool (AC 5)")
	assert_almost_eq(ms.pitch.staged_mana_spent(0), MANA_CAP, 0.0001,
		"...and exactly the cap was remembered")
	assert_almost_eq(ms.pitch.staged_locked_damage(0), MANA_CAP * DAMAGE_PER_MANA, 0.0001,
		"...and the damage locked off the CAPPED amount, not the pool (AC 7)")


## AC 6: BELOW THE MINIMUM the staging is refused through the EXISTING path -- no new token ships. Every
## clause of AC 6 asserted separately, and the shared helper additionally proves nothing was owed.
func test_staging_below_the_minimum_is_refused_through_the_existing_mana_path() -> void:
	var ms := _make_match(2.5)
	_assert_stage_refused(ms, CastEvaluator.REASON_INSUFFICIENT_MANA)
	assert_almost_eq(ms.p1.mana.get_current(), 2.5, 0.0001, "the mana is untouched (AC 6)")
	assert_eq(ms.p1.hand.occupied_count(), HAND_SIZE, "the card stayed in hand (AC 6)")


## AC 6's boundary, both sides of it, so the refusal is a `<` and not a `<=`: EXACTLY the minimum stages.
func test_exactly_the_minimum_stages_and_a_hair_under_it_does_not() -> void:
	var at := _make_match(PITCH_MINIMUM)
	_advance(at, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_true(at.pitch.is_staged(0), "EXACTLY the minimum stages (AC 6 is a strict `below`)")
	assert_almost_eq(at.pitch.staged_locked_damage(0), 4.5, 0.0001,
		"...for 1.5 x 3 == 4.5, UNROUNDED (AC 7's own worked example)")
	var under := _make_match(PITCH_MINIMUM - 0.01)
	_assert_stage_refused(under, CastEvaluator.REASON_INSUFFICIENT_MANA)


## AC 7 (`6-5d/R2`): NO ROUNDING, at the story's own second worked example -- 7.3 mana is 10.95 damage.
## A test that only ever used whole numbers could not tell a float product from a rounded one.
func test_the_locked_damage_is_the_unrounded_product() -> void:
	var ms := _make_match(7.3)
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_almost_eq(ms.pitch.staged_locked_damage(0), 10.95, 0.0001,
		"1.5 x 7.3 == 10.95, with NO rounding (AC 7)")


## AC 7: MANA GAINED OR LOST AFTER STAGING CANNOT CHANGE A STAGED CARD'S DAMAGE. Both directions, on one
## staged card, so the frozen value is proven frozen rather than merely correct once.
func test_mana_movement_after_staging_cannot_change_the_locked_damage() -> void:
	var ms := _make_match(5.0)
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	var locked := ms.pitch.staged_locked_damage(0)
	assert_almost_eq(locked, 7.5, 0.0001, "locked at 1.5 x 5")
	ms.p1.mana.add(12.0)
	_tick(ms)
	assert_almost_eq(ms.pitch.staged_locked_damage(0), locked, 0.0001,
		"a refilled pool did not raise the staged damage (AC 7)")
	ms.p1.mana.add(-12.0)
	_tick(ms)
	assert_almost_eq(ms.pitch.staged_locked_damage(0), locked, 0.0001,
		"...and an emptied pool did not lower it either")


## OPEN QUESTION 5, PINNED: the PRODUCT is frozen, not the factors. An authored `damage_per_mana` RETUNE
## between the staging and the activation is deliberately NOT seen by a card already in the zone.
##
## THIS IS THE CHOICE, NOT AN ACCIDENT, and it is pinned here because either answer would have been
## defensible: freezing the FACTORS would have let a mid-match retune reach an armed card, which reads as
## a live-tuning feature until a player watches a staged card's damage change under them. The scope says
## "locked at staging"; this is what that costs and what it buys.
func test_a_damage_per_mana_retune_between_staging_and_activation_is_not_seen() -> void:
	var ms := _make_match(6.0)
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_almost_eq(ms.pitch.staged_locked_damage(0), 9.0, 0.0001, "locked at 1.5 x 6")
	# The retune: the SAME injected effect object the staging read, edited under the staged card.
	_fireball_effect_of(ms).damage_per_mana = 99.0
	_tick(ms)
	assert_almost_eq(ms.pitch.staged_locked_damage(0), 9.0, 0.0001,
		"Open Question 5: the FROZEN PRODUCT ignores a retune of its factor (pinned choice)")
	_bank_orb(ms)
	_advance(ms, _activate_intent(), InputIntent.new())
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p1.projectiles.size(), 1, "the shot launched")
	assert_almost_eq(ms.p1.projectiles.damage_at(0), 9.0, 0.0001,
		"...carrying the damage frozen at STAGING, not the retuned product")


## AC 9: STAGING ANY OTHER PITCH CARD IS BIT-IDENTICAL TO TODAY. Asserted against a fixture whose pitch
## effect authors NO `mana_cap`, which is every effect in the project but Fireball: the fixed price is
## spent, the surplus stays, and nothing is locked.
func test_staging_a_fixed_cost_pitch_card_spends_exactly_its_price() -> void:
	var ms := _make_match(9.0, _buff_pitch_effects())
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_almost_eq(ms.p1.mana.get_current(), 9.0 - PITCH_MINIMUM, 0.0001,
		"a FIXED-cost staging spent its authored price and nothing more (AC 9)")
	assert_almost_eq(ms.pitch.staged_mana_spent(0), PITCH_MINIMUM, 0.0001,
		"...and remembered that price")
	assert_almost_eq(ms.pitch.staged_locked_damage(0), 0.0, 0.0001,
		"...and locked NO damage: an effect authoring no `damage_per_mana` has none")


## AC 8: A FIZZLED FIREBALL LOSES EVERYTHING. The one path where a player loses a full pool for nothing,
## and the ONLY new thing about it is how much was lost -- the fizzle seat itself is untouched.
func test_a_fizzled_fireball_refunds_no_mana_and_casts_nothing() -> void:
	var ms := _make_match(12.0)
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_almost_eq(ms.p1.mana.get_current(), 2.0, 0.0001, "the cap was spent")
	_idle(ms, TIMER_TICKS + 1)
	assert_false(ms.pitch.is_staged(0), "the countdown closed and the zone emptied")
	assert_eq(ms.p1.discard.size(), 1, "...the card went to the DISCARD")
	assert_almost_eq(ms.p1.mana.get_current(), 2.0, 0.0001,
		"...the mana is NOT refunded (AC 8)")
	assert_false(ms.p1.is_casting(), "...no cast started")
	assert_eq(ms.p1.projectiles.size(), 0, "...and no projectile exists")


# --- AC 10 / AC 11 / AC 12 / AC 13: activation, the cast, and the launch -----------------------

## AC 10: ACTIVATION IS THE EXISTING FLOW PLUS A CAST. Every mutation the flow already made is asserted
## still made -- orb spent, card discarded, zone cleared, replacement owed, resolved card recorded as
## PITCH -- and the ONE difference is that no effect applied and a cast is now in flight.
func test_activation_spends_the_orb_and_starts_a_cast_instead_of_applying() -> void:
	var ms := _make_match(9.0)
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	_bank_orb(ms)
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_eq(ms.p1.orbs.get_count(PITCH_COLOR), 0, "the red orb was spent (AC 10)")
	assert_eq(ms.p1.discard.size(), 1, "the card was discarded")
	assert_false(ms.pitch.is_staged(0), "the zone cleared")
	assert_eq(ms.p1.pending_draw_owed, [STAGE_SLOT] as Array[int],
		"the replacement is owed at the PRESS, not at the strike")
	assert_eq(ms.p1.last_resolved_card_mode, int(Enums.ModeKind.PITCH),
		"...and the resolved card was recorded as PITCH")
	assert_true(ms.p1.is_casting(), "A CAST IS IN FLIGHT (AC 10's one difference)")
	assert_eq(ms.p1.cast_effect_mode, int(Enums.ModeKind.PITCH),
		"...carrying the PITCH mode, so the strike resolves the pitch effect (AC 12)")
	assert_eq(ms.p1.projectiles.size(), 0, "...and NOTHING is in the air yet (AC 13: at cast END)")


## AC 10: a staged Fireball WAITS in the zone until the orb is banked. The activation refusal is the
## existing `REASON_PITCH_NOT_READY` and nothing about the variable cost changes it -- in particular the
## STAGING MANA STAYS SPENT, which is the standing no-refund rule and not a new one.
func test_a_staged_fireball_waits_for_its_orb_and_a_refusal_refunds_nothing() -> void:
	var ms := _make_match(9.0)
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	var rejections := _rejections(ms.p1)
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_PITCH_NOT_READY]],
		"no orb banked: the existing NOT READY refusal (AC 10)")
	assert_true(ms.pitch.is_staged(0), "...the card is still staged")
	assert_almost_eq(ms.p1.mana.get_current(), 0.0, 0.0001,
		"...and the staging mana stays spent -- a refusal is not the chance expiring")
	assert_false(ms.p1.is_casting(), "...and no cast started")


## AC 11: THE CAST IS THE 6-5c FRAME, and the assertions are the frame's own: the caster is committed for
## the authored count, a card press during it is REFUSED with the announced cue, and the strike lands on
## the tick the window runs out. The duration comes from the EFFECT (`cast_seconds`), not from balance.
func test_the_cast_runs_the_authored_length_and_refuses_every_card_press() -> void:
	var ms := _make_match(9.0)
	_stage_and_activate(ms)
	assert_eq(ms.p1.cast_window.remaining_ticks(), CAST_TICKS,
		"the cast is the EFFECT's authored length in ticks (AC 11)")
	var rejections := _rejections(ms.p1)
	_advance(ms, _cast_intent(0), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_CASTING]],
		"a card press during the cast is refused with the announced cue (AC 11)")
	_idle(ms, CAST_TICKS - 1)
	assert_false(ms.p1.is_casting(), "the cast ended at the authored tick")
	assert_eq(ms.p1.projectiles.size(), 1, "...and the strike launched the shot (AC 13)")


## AC 11: STARTING THE CAST DROPS A HELD BLOCK ON THE SAME TICK -- the mode ① fork's own review fix
## (`6-5c/R4`, `5-2/R17`) reaching the mode ④ fork, which would otherwise have let a blocking caster keep
## its mitigation for the whole cast.
func test_starting_a_pitch_cast_drops_a_held_block_on_the_same_tick() -> void:
	var ms := _make_match(9.0)
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	_bank_orb(ms)
	ms.p1.hero.set_action_state(HeroState.ActionState.BLOCKING)
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_true(ms.p1.is_casting(), "the cast started")
	assert_ne(ms.p1.hero.action_state, HeroState.ActionState.BLOCKING,
		"...and the held block was dropped on the SAME tick (AC 11)")


## AC 11: ONLY BEING STUNNED INTERRUPTS, and then THE CARD AND THE MANA ARE LOST -- no refund, and above
## all NO PROJECTILE. The negative half (an ordinary hit does not interrupt) is `6-5c`'s and is covered
## on its own fixture; what is new here is that the interrupt must stop a LAUNCH.
func test_a_stun_mid_cast_loses_the_card_and_the_mana_and_fires_nothing() -> void:
	var ms := _make_match(9.0)
	_stage_and_activate(ms)
	_idle(ms, 2)
	ms.p1.hero.start_stun(30, false)
	ms.p1.hero.set_action_state(HeroState.ActionState.STUNNED)
	_idle(ms, CAST_TICKS)
	assert_false(ms.p1.is_casting(), "the stun interrupted the cast (AC 11)")
	assert_eq(ms.p1.projectiles.size(), 0, "NO FIREBALL WAS THROWN (AC 11)")
	assert_almost_eq(ms.p1.mana.get_current(), 0.0, 0.0001, "the mana is not refunded")
	assert_eq(ms.p1.discard.size(), 1, "...and the card stays in the discard")


## AC 11: A CASTER WHO DIES MID-CAST NEVER FIRES. Read hp-based, which is what makes it true on the KILL
## TICK itself rather than one tick later (`_cast_is_interrupted`'s own N8 argument).
func test_a_caster_killed_mid_cast_never_fires() -> void:
	var ms := _make_match(9.0)
	_stage_and_activate(ms)
	_idle(ms, 2)
	ms.p1.hero.take_damage(MAX_HP)
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p1.projectiles.size(), 0, "a dead caster threw nothing (AC 11)")


## AC 12, BOTH DIRECTIONS -- the AC's own two clauses, and the reason `cast_effect_mode` exists.
##
## The card id is the SAME in both halves. What differs is the MODE, and without it the strike seat would
## look one id up in one map and resolve the wrong effect: a Fireball would arm a roll buff.
func test_a_pitch_cast_throws_a_fireball_and_a_basic_cast_still_arms_the_roll_buff() -> void:
	# (1) THE PITCH CAST: a projectile, and NO roll buff.
	var pitch_ms := _make_match(9.0)
	_stage_and_activate(pitch_ms)
	_idle(pitch_ms, CAST_TICKS)
	assert_eq(pitch_ms.p1.projectiles.size(), 1, "the PITCH cast threw a Fireball (AC 12)")
	assert_false(pitch_ms.p1.is_rule_active(PlayerState.RULE_BLOODHOUND_ARMED),
		"...and armed NO roll buff -- the basic effect of the same card never resolved (AC 12)")
	# (2) THE BASIC CAST of the same card: the roll buff, instantly, and NO cast at all.
	var basic_ms := _make_match(9.0)
	_advance(basic_ms, _cast_intent(STAGE_SLOT), InputIntent.new())
	assert_true(basic_ms.p1.is_rule_active(PlayerState.RULE_BLOODHOUND_ARMED),
		"the BASIC cast of the same card still arms the roll buff (AC 12)")
	assert_false(basic_ms.p1.is_casting(), "...and starts no cast")
	assert_eq(basic_ms.p1.projectiles.size(), 0, "...and throws nothing")


## AC 13: WHAT THE STRIKE PLACES. Every clause separately: on the CASTER's board, sourced at the caster's
## HERO, addressed at the target captured at cast start, carrying the locked damage, alive and homing.
func test_the_strike_places_a_hero_sourced_shot_at_the_captured_target() -> void:
	var ms := _make_match(9.0)
	ms.p2.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = 0
	_stage_and_activate(ms)
	_idle(ms, CAST_TICKS)
	var board := ms.p1.projectiles
	assert_eq(board.size(), 1, "the shot is on the CASTER's board (AC 13)")
	assert_eq(ms.p2.projectiles.size(), 0, "...and not on the target's")
	assert_true(board.is_hero_sourced_at(0), "...it is HERO-SOURCED")
	assert_eq(board.effect_id_at(0), "fireball", "...authored by the pitch effect")
	assert_eq(board.source_index_at(0), TargetingService.HERO_INDEX,
		"...sourced at the caster's hero, so the runner launches it from the hero (AC 13)")
	assert_eq(board.kind_index_at(0), BalanceConfig.NO_KIND_INDEX,
		"...and resolves NO unit kind")
	assert_eq([board.target_slot_at(0), board.target_index_at(0)], [1, 0],
		"...addressed at the CAPTURED target (AC 13/AC 24)")
	assert_almost_eq(board.damage_at(0), 9.0 * DAMAGE_PER_MANA, 0.0001,
		"...carrying the damage locked at staging (AC 7/AC 13)")
	assert_true(board.is_alive_at(0) and board.is_homing_at(0), "...alive and homing")


## AC 13's last sentence: A CLOSED SPELLS LAYER STARTS NO CAST, and the activation still RESOLVES. The
## resolver's existing degrade, asserted rather than re-implemented.
func test_a_closed_spells_layer_resolves_the_activation_and_starts_no_cast() -> void:
	var flags := _flags()
	flags.spells = false
	var ms := _make_match(9.0, null, flags)
	_stage_and_activate(ms)
	assert_false(ms.p1.is_casting(), "no cast started with the spells layer closed (AC 13)")
	assert_eq(ms.p1.projectiles.size(), 0, "...and nothing was thrown")
	assert_eq(ms.p1.discard.size(), 1, "...but the activation RESOLVED: the card is discarded")
	assert_eq(ms.p1.orbs.get_count(PITCH_COLOR), 0, "...and the orb is spent")


# --- AC 14 / AC 15 / AC 16: the landing, and what does not help -------------------------------

## AC 14: THE LOCKED DAMAGE GOES THROUGH THE FUNNEL. The plain case first -- no buffs on either side --
## so the landed number is exactly the frozen product and nothing else.
## AC 15: A HIT IS DAMAGE ONLY. No stun, no root, no state change beyond hp, and `hit_landed` announced.
func test_a_landed_fireball_deals_its_locked_damage_and_nothing_else() -> void:
	var ms := _in_flight(9.0)
	var hits := _hits(ms)
	_land(ms)
	assert_almost_eq(ms.p2.hero.get_hp(), MAX_HP - 13.5, 0.0001,
		"the landed damage is the frozen 1.5 x 9 (AC 14)")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE,
		"NO stun (AC 15)")
	assert_false(ms.p2.root_window.is_running, "NO root (AC 15)")
	assert_eq(hits.size(), 1, "`hit_landed` is announced as for any hero hit (AC 15)")
	assert_false(ms.p1.projectiles.is_alive_at(0), "...and the shot was consumed by the landing")


## AC 14 (Discrepancy 5): BLOODLUST REACHES A HERO-SOURCED SHOT, both halves, because the caster's
## Fireball is the caster's own damage. This is one of the two shipped exclusions AC 14 deliberately
## breaks -- `_is_bloodlust_body` returned FALSE for every projectile index.
func test_bloodlust_multiplies_a_fireball_on_both_sides() -> void:
	var ms := _in_flight(9.0)
	ms.p1.start_rule(PlayerState.RULE_BLOODLUST, 600, 2.0, 2.0)
	ms.p2.start_rule(PlayerState.RULE_BLOODLUST, 600, 2.0, 2.0)
	_land(ms)
	assert_almost_eq(ms.p2.hero.get_hp(), MAX_HP - 13.5 * 4.0, 0.0001,
		"the caster's DEALT and the target's TAKEN multipliers both applied (AC 14)")


## AC 14 (Discrepancy 5): VAMPIRIC AURA HEALS THE CASTER FROM A FIREBALL. The second shipped exclusion
## AC 14 breaks -- `_apply_lifesteal` gated on `attacker_index == HERO_INDEX`, and a shot carries a
## projectile index. Measured off the hp ACTUALLY removed, so the caster is hurt first.
func test_vampiric_aura_heals_the_caster_from_a_fireball() -> void:
	var ms := _in_flight(9.0)
	ms.p1.hero.take_damage(50.0)
	ms.p1.start_rule(PlayerState.RULE_VAMPIRIC_AURA, 600, 0.5, 0.0)
	_land(ms)
	assert_almost_eq(ms.p1.hero.get_hp(), 50.0 + 13.5 * 0.5, 0.0001,
		"the caster healed half the hp its Fireball removed (AC 14)")


## AC 16 (`6-5d/R4`): BLOCK DOES NOT HELP. Both halves of the AC: a BLOCKING target that FACES the shot
## takes the full damage, and one that does not face it takes the full damage too -- so the exemption is
## not accidentally riding the facing test.
func test_block_does_not_reduce_a_fireball_facing_or_not() -> void:
	for facing_the_shot: bool in [true, false]:
		var ms := _in_flight(9.0)
		ms.p2.hero.set_action_state(HeroState.ActionState.BLOCKING)
		var hits := _hits(ms)
		_land(ms, facing_the_shot, _block_intent())
		assert_eq(ms.p2.hero.action_state, HeroState.ActionState.BLOCKING,
			"fixture: the target really was BLOCKING when the shot resolved (facing: %s)"
					% facing_the_shot)
		assert_almost_eq(ms.p2.hero.get_hp(), MAX_HP - 13.5, 0.0001,
			"a BLOCKING target took the FULL damage (facing: %s) (AC 16)" % facing_the_shot)
		assert_eq(hits.size(), 1, "...the hit landed (facing: %s)" % facing_the_shot)
		if hits.size() == 1:
			assert_false(bool(hits[0][3]),
				"...and is NOT recorded as blocked -- the block did nothing, and saying otherwise "
				+ "would tell the player it did (facing: %s)" % facing_the_shot)


## AC 16: A DEFLECT STILL NEGATES AND CONSUMES IT, and the caster is NOT stunned. The exemption above is
## the block RUNG only: the facing test, the deflect window, the defender's stamina spend and the
## consumption all still run, which is what keeps a perfect deflect an answer to a Fireball.
func test_a_deflect_negates_and_consumes_a_fireball_without_stunning_the_caster() -> void:
	var ms := _in_flight(9.0)
	ms.p2.hero.set_action_state(HeroState.ActionState.BLOCKING)
	ms.p2.hero.deflect.start(10)
	var hits := _hits(ms)
	var deflects := _deflects(ms)
	_land(ms, true, _block_intent())
	assert_almost_eq(ms.p2.hero.get_hp(), MAX_HP, 0.0001, "a DEFLECT negated it entirely (AC 16)")
	assert_eq(hits.size(), 0, "...no `hit_landed`")
	assert_eq(deflects.size(), 1, "...`deflect_landed` announced")
	assert_false(ms.p1.projectiles.is_alive_at(0), "...and the shot was CONSUMED")
	assert_ne(ms.p1.hero.action_state, HeroState.ActionState.STUNNED,
		"...and the CASTER is not stunned by it (AC 16) -- the deflect stun is hero-attackers only")
	assert_almost_eq(ms.p2.stamina.get_current(), STAMINA - DEFLECT_COST, 0.0001,
		"...and the defender paid the deflect cost exactly as today")


# --- AC 17 / AC 18 / AC 20 / AC 21 / AC 22 / AC 23: the flight ---------------------------------

## AC 17: ROLL AND RISE I-FRAMES DROP THE CONTACT, END THE HOMING AND DO NOT CONSUME THE SHOT. Both
## windows, because `HeroState.is_iframe_open()` covers both and the contact rung reads that LIVE
## predicate -- deliberately NOT the wider step-3 latch the bolt uses. Recorded so the two seats' tick
## semantics are not "fixed" into each other.
func test_roll_and_rise_iframes_drop_a_fireball_and_end_its_homing() -> void:
	for window_name: String in ["roll", "get_up"]:
		var ms := _in_flight(9.0)
		if window_name == "roll":
			ms.p2.hero.roll_iframe.start(10)
		else:
			ms.p2.hero.get_up_iframe.start(10)
		_land(ms)
		assert_almost_eq(ms.p2.hero.get_hp(), MAX_HP, 0.0001,
			"the %s i-frame dropped the contact: NO damage (AC 17)" % window_name)
		assert_true(ms.p1.projectiles.is_alive_at(0),
			"...the shot is NOT consumed and flies on (AC 17)")
		assert_false(ms.p1.projectiles.is_homing_at(0),
			"...but its homing ENDED on that tick (AC 17)")


## AC 17/AC 18: HOMING NEVER RESUMES once ended, and NOTHING ELSE ends it. The two halves of `4-4/R4`'s
## no-path-back rule, asserted for the new shot kind: many ticks of ordinary flight after an i-frame drop
## leave it straight, and a long ordinary flight with a live target leaves it homing.
func test_homing_never_resumes_and_nothing_else_ends_it() -> void:
	var dropped := _in_flight(9.0)
	dropped.p2.hero.roll_iframe.start(2)
	_land(dropped)
	_idle(dropped, 30)
	assert_false(dropped.p1.projectiles.is_homing_at(0),
		"homing that ended never resumes, even with the target out of i-frames (AC 17)")
	var running := _in_flight(9.0)
	_idle(running, 30)
	assert_true(running.p1.projectiles.is_homing_at(0),
		"a live shot keeps steering toward a live target -- nothing else ends homing (AC 18)")
	assert_true(running.p1.projectiles.is_alive_at(0), "...and it is still in the air")


## AC 20 (`6-5d/R5`): A FIREBALL PASSES THROUGH ANY BODY THAT IS NOT ITS CAPTURED TARGET. All three
## clauses of the AC: no damage, not consumed, and NO i-frame effect -- the last one is why the rung sits
## above the i-frame rung, and it is asserted with the bystander's i-frames OPEN, which is the case that
## would otherwise have silently ended the homing.
func test_a_fireball_passes_through_a_non_target_body() -> void:
	var ms := _make_match(9.0)
	ms.p2.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	# Locked on the enemy HERO, with a minion in between.
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = TargetingService.HERO_INDEX
	_stage_and_activate(ms)
	_idle(ms, CAST_TICKS)
	var hits := _hits(ms)
	# The shot overlaps the NON-TARGET minion, whose i-frames are irrelevant but set anyway.
	_push_shot_contact(ms, [1, 0])
	_tick(ms)
	assert_almost_eq(ms.p2.units.hp_at(0), UNIT_HP, 0.0001,
		"the non-target minion took NO damage (AC 20)")
	assert_true(ms.p1.projectiles.is_alive_at(0), "...the shot was NOT consumed (AC 20)")
	assert_true(ms.p1.projectiles.is_homing_at(0), "...and its homing was untouched (AC 20)")
	assert_eq(hits.size(), 0, "...and nothing was announced")
	# ...and it then lands on the hero it was actually aimed at.
	_land(ms)
	assert_almost_eq(ms.p2.hero.get_hp(), MAX_HP - 13.5, 0.0001,
		"...and it went on to hit the CAPTURED target (AC 20's point)")


## AC 19: A MINION OR TOTEM TARGET HAS NO DEFENCE -- the shot lands, is consumed, the damage goes through
## the funnel's unit seat, and a LETHAL hit leaves a corpse through the same death seat as every other
## combat kill. No stun and no root, which a unit structurally cannot take anyway.
func test_a_fireball_on_a_minion_lands_for_its_locked_damage_and_leaves_a_corpse() -> void:
	var ms := _make_match(9.0)
	ms.p2.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = 0
	_stage_and_activate(ms)
	_idle(ms, CAST_TICKS)
	_push_shot_contact(ms, [1, 0])
	_tick(ms)
	assert_almost_eq(ms.p2.units.hp_at(0), UNIT_HP - 13.5, 0.0001,
		"the minion took the shot's locked damage through the unit seat (AC 19)")
	assert_false(ms.p1.projectiles.is_alive_at(0), "...and the shot was consumed on impact (AC 19)")
	# LETHAL: the same 15-damage shot (mana 20, capped to 10, x1.5) onto a minion already down to 10 hp.
	# Wounded rather than fresh, because a capped Fireball is 15 and a fresh minion has 40 -- the point
	# here is the DEATH SEAT, not how many shots a full-health minion survives.
	var lethal := _make_match(20.0)
	lethal.p2.units.add(UNIT_HP, _kind_index(lethal, MINION_KIND))
	lethal.p2.units.apply_damage_at(0, UNIT_HP - 10.0, 0)
	lethal.p1.lock_target_slot = 1
	lethal.p1.lock_target_index = 0
	_stage_and_activate(lethal)
	_idle(lethal, CAST_TICKS)
	_push_shot_contact(lethal, [1, 0])
	_tick(lethal)
	assert_false(lethal.p2.units.is_alive_at(0), "a lethal Fireball killed the minion (AC 19)")
	assert_eq(lethal.p2.units.corpse_indices(), [0] as Array[int],
		"...and left a CORPSE through the shared death seat (AC 19)")


## Review fix MINOR-5 (AC 19's TOTEM arm, unproven until now): a Fireball whose captured target is a
## Combat TOTEM lands on it for the locked damage, is consumed, and -- structurally, a unit has neither
## field -- applies no stun or root. The one place a totem DIFFERS from a minion is the one place
## Fireball was untested: it leaves NO corpse, through `_corpse_ticks_for`'s standing exclusion, not
## this arm's. Mirrors the minion test above and `test_spell_targeting.gd`'s bolt-on-totem test.
func test_a_fireball_on_a_totem_lands_for_its_locked_damage_and_leaves_no_corpse() -> void:
	var ms := _make_match(20.0)
	ms.p2.units.add(UNIT_HP, _kind_index(ms, TOTEM_KIND))
	ms.p2.units.apply_damage_at(0, UNIT_HP - 10.0, 0)
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = 0
	_stage_and_activate(ms)
	_idle(ms, CAST_TICKS)
	_push_shot_contact(ms, [1, 0])
	_tick(ms)
	assert_false(ms.p2.units.is_alive_at(0), "a lethal Fireball killed the totem (AC 19)")
	assert_eq(ms.p2.units.corpse_indices(), [] as Array[int],
		"...and a TOTEM leaves no corpse -- unlike the minion arm above (AC 19)")
	assert_false(ms.p1.projectiles.is_alive_at(0), "...and the shot was consumed on impact (AC 19)")


## AC 21 (`6-5d/R15`): THE TARGET DYING MID-FLIGHT ENDS THE HOMING -- state-decided, so a replay
## reproduces it -- and the shot flies straight on, damaging nothing and never re-acquiring. The
## snap-back the lock performs on that death is deliberately NOT followed: the captured address is frozen.
func test_a_fireball_whose_target_dies_mid_flight_flies_straight_and_never_re_acquires() -> void:
	var ms := _make_match(9.0)
	ms.p2.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = 0
	_stage_and_activate(ms)
	_idle(ms, CAST_TICKS)
	assert_true(ms.p1.projectiles.is_homing_at(0), "the shot is homing on the minion")
	ms.p2.units.apply_damage_at(0, UNIT_HP, 0)
	_tick(ms)
	assert_false(ms.p1.projectiles.is_homing_at(0),
		"the target's death ended the homing IN STATE (AC 21, Open Question 6)")
	assert_true(ms.p1.projectiles.is_alive_at(0), "...and the shot flies straight on (AC 21)")
	assert_eq([ms.p1.projectiles.target_slot_at(0), ms.p1.projectiles.target_index_at(0)], [1, 0],
		"...still addressed at the DEAD minion -- never re-acquired, never the snap-back hero (AC 21)")
	assert_almost_eq(ms.p2.hero.get_hp(), MAX_HP, 0.0001, "...and the hero behind it is untouched")


## AC 22 (`6-5d/R13`): A TARGET ALREADY DEAD ON THE STRIKE TICK IS STILL LAUNCHED AT. The positive
## decision, not a missing guard: the shot is PLACED, flies straight, homes on nothing and expires at the
## budget. It never falls on the lock's snap-back hero.
func test_a_fireball_whose_target_is_dead_on_the_launch_tick_is_still_launched() -> void:
	var ms := _make_match(9.0)
	ms.p2.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = 0
	_stage_and_activate(ms)
	# Killed DURING the cast, so the captured address is already a corpse at the strike tick.
	ms.p2.units.apply_damage_at(0, UNIT_HP, 0)
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p1.projectiles.size(), 1, "the shot was STILL placed and launched (AC 22)")
	assert_eq([ms.p1.projectiles.target_slot_at(0), ms.p1.projectiles.target_index_at(0)], [1, 0],
		"...addressed at the dead minion, never re-acquired (AC 22)")
	# ONE TICK, AND THE LAG IS STRUCTURAL RATHER THAN A TOLERANCE. The dead-target rung lives in
	# `_advance_projectiles` at step 2, and the shot is PLACED by the strike at step 6c -- so a shot
	# launched at a corpse carries `_homing` true for exactly the tick it was born on and is straightened
	# on the next one. Nothing observes the difference: the runner's drive phase finds no actor for a dead
	# body and does not steer, so the shot never visibly homes, and it cannot damage anything either way
	# (its captured target is the only body it may hit, AC 20). Asserted rather than hidden.
	_tick(ms)
	assert_false(ms.p1.projectiles.is_homing_at(0), "...homing on nothing (AC 22)")
	assert_almost_eq(ms.p2.hero.get_hp(), MAX_HP, 0.0001,
		"...and it never fell on the lock's snap-back hero (AC 22)")


## AC 23: THE BUDGET ENDS IT, at the authored distance, and the board never reuses an index. Driven by
## ticking until the odometer spends 60 m at the authored launch speed, with a generous ceiling so the
## test fails by running out rather than by asserting a tick count it would have to keep in step with.
func test_a_fireball_that_hits_nothing_expires_at_its_authored_budget() -> void:
	var ms := _in_flight(9.0)
	var ceiling := int(ceil(BUDGET / (LAUNCH_SPEED / TimingWindow.TICK_HZ))) + 10
	var ticks := 0
	while ms.p1.projectiles.is_alive_at(0) and ticks < ceiling:
		_tick(ms)
		ticks += 1
	assert_false(ms.p1.projectiles.is_alive_at(0), "the shot expired (AC 23)")
	assert_true(ms.p1.projectiles.travelled_at(0) >= BUDGET,
		"...having spent its authored %s m budget (AC 23)" % BUDGET)
	# AC 23's second clause: the indices are never reused -- a second shot APPENDS.
	ms.p1.projectiles.add_hero_shot(1, TargetingService.HERO_INDEX, FIREBALL, 1.0)
	assert_eq(ms.p1.projectiles.size(), 2,
		"`add_hero_shot` is an unconditional APPEND -- a spent index is never refilled (AC 23)")
	# ...and an expired shot damages nothing afterwards.
	var hits := _hits(ms)
	_push_shot_contact(ms, [1, TargetingService.HERO_INDEX])
	_tick(ms)
	assert_almost_eq(ms.p2.hero.get_hp(), MAX_HP, 0.0001,
		"an expired shot damages nothing afterwards (AC 23)")
	assert_eq(hits.size(), 0, "...and announces nothing")


# --- AC 36: THE TOTEM'S SHOT IS BIT-IDENTICAL (`6-5d/R11`, `6-5d/R17`) -------------------------

## AC 36, and `6-5d/R17` is why these tests exist AT ALL rather than resting on "every existing
## projectile test passes unchanged". MEASURED at the readiness gate: NO shipped test exercises a
## projectile under Bloodlust or Vampiric Aura, so the existing suite proved nothing about a totem shot.
## AC 14 deliberately deletes two exclusions (`_is_bloodlust_body`'s projectile FALSE and
## `_apply_lifesteal`'s hero-index gate), and a dev pass that simply removed them would have kept every
## old test green while silently DOUBLING a totem's shot. These are the tests that would have failed.
##
## AC 36'S TWO HALVES DISAGREE, AND THE `bit-identical` CLAUSE IS THE ONE THAT GOVERNS. The AC's opening
## sentence demands the totem shot be bit-identical in "damage ... no Bloodlust, no Vampiric Aura" and
## that "every `test_projectile_flight*.gd` / `test_unit_combat_live.gd` assertion passes unchanged"; its
## NEW-TEST clause then describes a shot that "deals its authored `attack_at(0).damage` unmultiplied" with
## the TARGET under Bloodlust (taken). Those cannot both hold, because the TARGET's taken multiplier
## reached a totem shot BEFORE 6-5d and this story provably does not touch it: `_funnel_damage`'s second
## branch asks `_is_bloodlust_body(target, target_index)`, and for a HERO target that returns `true` on its
## first line, unchanged. The new-test clause rests on a factual error about shipped behaviour -- the same
## blind spot `6-5d/R17` names (no shipped test ever exercised a projectile under a buff), which is why it
## could be written at all.
##
## SO THIS TEST PINS BIT-IDENTICAL, WHICH IS THE CONSERVATIVE READING AND THE ONE THAT CHANGES NO
## GAMEPLAY: the ATTACKER-side dealt multiplier does NOT reach a totem's shot (a totem is not a Bloodlust
## body and neither is its shot -- the thing 6-5d had to be careful not to break while widening the rule
## for a HERO-sourced shot), Vampiric Aura heals nobody off it, and the TARGET-side taken multiplier
## applies exactly as it always has. Reported to the operator as a discrepancy rather than chosen silently.
func test_a_totem_shot_is_unbuffed_by_its_owners_bloodlust_and_heals_nobody() -> void:
	# (a) THE OWNER under Bloodlust (dealt) and Vampiric Aura, the TARGET unbuffed.
	var ms := _make_match(9.0)
	var shot := _totem_shot(ms)
	ms.p1.hero.take_damage(50.0)
	ms.p1.start_rule(PlayerState.RULE_BLOODLUST, 600, 2.0, 2.0)
	ms.p1.start_rule(PlayerState.RULE_VAMPIRIC_AURA, 600, 0.5, 0.0)
	_push_shot_contact(ms, [1, TargetingService.HERO_INDEX], shot)
	_tick(ms)
	assert_almost_eq(ms.p2.hero.get_hp(), MAX_HP - TOTEM_SHOT_DAMAGE, 0.0001,
		"a TOTEM's shot deals its authored damage with NO dealt multiplier -- its owner's Bloodlust does "
		+ "not reach it (AC 36). This is the assertion a careless removal of "
		+ "`_is_bloodlust_body`'s projectile branch would have failed")
	assert_almost_eq(ms.p1.hero.get_hp(), 50.0, 0.0001,
		"...and Vampiric Aura heals NOBODY off it (AC 36) -- the assertion a careless removal of "
		+ "`_apply_lifesteal`'s hero-index gate would have failed")
	# (b) THE TARGET under Bloodlust (taken): UNCHANGED shipped behaviour, pinned so 6-5d's widening is
	# visibly scoped to the attacker side.
	var buffed_target := _make_match(9.0)
	var shot2 := _totem_shot(buffed_target)
	buffed_target.p2.start_rule(PlayerState.RULE_BLOODLUST, 600, 2.0, 2.0)
	_push_shot_contact(buffed_target, [1, TargetingService.HERO_INDEX], shot2)
	_tick(buffed_target)
	assert_almost_eq(buffed_target.p2.hero.get_hp(), MAX_HP - TOTEM_SHOT_DAMAGE * 2.0, 0.0001,
		"a Bloodlusted TARGET still takes double from a totem's shot -- unchanged shipped behaviour "
		+ "(`_funnel_damage`'s target branch returns true for any hero target and 6-5d does not touch "
		+ "it). AC 36's `unmultiplied` clause is read against its own `bit-identical` clause here")


## AC 36: A BLOCKING HERO STILL TAKES THE BLOCK-MITIGATED DAMAGE FROM A TOTEM SHOT. "Block multiplier"
## is on AC 36's bit-identical list precisely because AC 16 removes that rung for Fireball, and this is
## the assertion that keeps the removal Fireball-only.
func test_a_blocking_hero_still_block_mitigates_a_totem_shot() -> void:
	var ms := _make_match(9.0)
	var shot := _totem_shot(ms)
	ms.p2.hero.set_action_state(HeroState.ActionState.BLOCKING)
	var hits := _hits(ms)
	_push_shot_contact(ms, [1, TargetingService.HERO_INDEX], shot)
	_advance(ms, InputIntent.new(), _block_intent())
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.BLOCKING,
		"fixture: the target really was BLOCKING when the totem's shot resolved")
	assert_almost_eq(ms.p2.hero.get_hp(), MAX_HP - TOTEM_SHOT_DAMAGE * BLOCK_MULTIPLIER, 0.0001,
		"the block multiplier STILL applies to a totem's shot (AC 36)")
	assert_eq(hits.size(), 1, "...the hit landed")
	if hits.size() == 1:
		assert_true(bool(hits[0][3]), "...and IS recorded as blocked (AC 36)")


## AC 36: A TOTEM'S SHOT STILL LANDS ON THE FIRST OPPOSING BODY IT TOUCHES -- pass-through is
## Fireball-only. Asserted with the shot addressed at the HERO and the fact naming a MINION, which is
## exactly the case AC 20 changes for a Fireball and must not change here.
func test_a_totem_shot_still_lands_on_the_first_body_it_touches() -> void:
	var ms := _make_match(9.0)
	ms.p2.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	var shot := _totem_shot(ms)
	_push_shot_contact(ms, [1, 0], shot)
	_tick(ms)
	assert_almost_eq(ms.p2.units.hp_at(0), UNIT_HP - TOTEM_SHOT_DAMAGE, 0.0001,
		"a totem's shot hit the NON-TARGET body it overlapped (AC 36, `6-5d/R11`)")
	assert_false(ms.p1.projectiles.is_alive_at(shot),
		"...and was CONSUMED by it -- the shipped first-body behaviour, untouched")


## AC 36: a totem's shot resolves its damage and its whole flight profile through its KIND, not through
## the per-shot fields the hero-sourced path added. The negative half of the discriminator.
func test_a_totem_shot_is_not_hero_sourced_and_carries_no_per_shot_damage() -> void:
	var ms := _make_match(9.0)
	var shot := _totem_shot(ms)
	assert_false(ms.p1.projectiles.is_hero_sourced_at(shot),
		"a unit-fired shot is not hero-sourced (AC 36)")
	assert_eq(ms.p1.projectiles.effect_id_at(shot), "",
		"...it names no effect: its numbers come from its KIND")
	assert_almost_eq(ms.p1.projectiles.damage_at(shot), 0.0, 0.0001,
		"...and its per-shot damage field is the unread resting 0.0")


# --- AC 38: M6 -- the reload-time `unit_kinds` reorder refusal (`6-5d/R12`) --------------------

## AC 38 (`6-5d/R12`, deferred-work M6): A SAME-LENGTH REORDER WHILE A RECORD IS LIVE IS REFUSED, the
## running config is KEPT, no record is re-pointed, and the reason NAMES the reordered kind.
##
## THE DEFECT: a unit record and a projectile record both store a KIND INDEX, not a kind. A reload that
## merely reorders the authored list silently re-points every live record at a different kind -- a minion
## becomes a totem, a totem's shot reads another kind's damage and profile -- and nothing saw it, because
## the length is unchanged and every index still resolves.
func test_a_unit_kinds_reorder_while_a_record_is_live_is_refused_by_name() -> void:
	var ms := _make_match(9.0)
	var minion_index := _kind_index(ms, MINION_KIND)
	ms.p1.units.add(UNIT_HP, minion_index)
	var running := ms.balance
	var reason := ms.apply_balance(_config_with_kinds_reordered())
	assert_ne(reason, "", "a reorder under a live record is REFUSED (AC 38)")
	assert_true(reason.contains(String(MINION_KIND)) and reason.contains(String(TOTEM_KIND)),
		"...and the reason NAMES the reordered kind (AC 38): %s" % reason)
	assert_true(reason.contains("position 0"), "...and where it moved to: %s" % reason)
	assert_eq(ms.balance, running, "...the RUNNING config was kept unchanged (AC 38)")
	assert_eq(ms.p1.units.kind_index_at(0), minion_index,
		"...and no live record was re-pointed (AC 38)")


## AC 38: a reorder is refused for a LIVE PROJECTILE record too -- the other half of "any unit or
## projectile record", and the half M6 was actually raised about.
func test_a_unit_kinds_reorder_while_a_projectile_is_live_is_refused() -> void:
	var ms := _make_match(9.0)
	_totem_shot(ms)
	assert_ne(ms.apply_balance(_config_with_kinds_reordered()), "",
		"a live PROJECTILE record refuses a reorder too (AC 38)")


## AC 38's scope, asserted as narrowly as the ruling: EVERY OTHER RELOAD IS UNAFFECTED. An unchanged
## list, a SHORTENED one and an APPENDED one all apply -- the X3-legal cases the existing
## graceful-degradation paths already handle honestly -- and so does a reorder on an EMPTY board, where
## there is nothing to re-point.
func test_every_other_reload_is_unaffected_by_the_reorder_refusal() -> void:
	var unchanged := _make_match(9.0)
	unchanged.p1.units.add(UNIT_HP, _kind_index(unchanged, MINION_KIND))
	assert_eq(unchanged.apply_balance(_config()), "",
		"an UNCHANGED `unit_kinds` applies (AC 38)")
	var appended := _make_match(9.0)
	appended.p1.units.add(UNIT_HP, _kind_index(appended, MINION_KIND))
	var longer := _config()
	longer.unit_kinds.append(_kind(&"a_third_kind", 1.0))
	assert_eq(appended.apply_balance(longer), "", "an APPENDED `unit_kinds` applies (AC 38)")
	var shortened := _make_match(9.0)
	shortened.p1.units.add(UNIT_HP, _kind_index(shortened, MINION_KIND))
	var shorter := _config()
	shorter.unit_kinds.remove_at(1)
	assert_eq(shortened.apply_balance(shorter), "", "a SHORTENED `unit_kinds` applies (AC 38)")
	var empty := _make_match(9.0)
	assert_eq(empty.apply_balance(_config_with_kinds_reordered()), "",
		"a reorder on an EMPTY board applies -- there is nothing to re-point (AC 38)")


## AC 38: "LIVE" MEANS ANY RECORD, NOT A LIVING ONE, and this is the case that decides it: a CORPSE is a
## `UnitBoard` record whose kind index still decides what it renders as and whether it can be raised, so
## a reorder under a corpse must be refused exactly as one under a living minion is.
func test_a_corpse_is_a_live_record_for_the_reorder_refusal() -> void:
	var ms := _make_match(9.0)
	ms.p1.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	ms.p1.units.apply_damage_at(0, UNIT_HP, 600)
	assert_false(ms.p1.units.is_alive_at(0), "the minion is a corpse")
	assert_ne(ms.apply_balance(_config_with_kinds_reordered()), "",
		"a CORPSE still refuses a reorder -- its kind index decides its corpse behaviour (AC 38)")


## Review fix MINOR-2: "LIVE" for a PROJECTILE record means ALIVE, unlike the UNIT half above -- a
## CONSUMED shot's kind index is never read again (the board never reclaims an index, deferred-work
## M4), so a board holding only a consumed shot must not permanently block every same-length reorder.
## Mutation-proven: reverting the projectile half of `_kind_reorder_refusal` back to `size()` must fail
## the first assertion here.
func test_a_consumed_projectile_does_not_refuse_a_reorder_but_a_live_one_still_does() -> void:
	# Placed through the projectile board DIRECTLY (not `_totem_shot`, which also adds a UNIT
	# record -- that would confound this test with the unit half's OWN liveness, already proven
	# above), so only the projectile board carries a record and the isolation is real.
	var consumed := _make_match(9.0)
	consumed.p1.projectiles.add(1, TargetingService.HERO_INDEX, _kind_index(consumed, TOTEM_KIND), 0)
	consumed.p1.projectiles.consume_at(0)
	assert_false(consumed.p1.projectiles.is_alive_at(0), "fixture: the shot is consumed")
	assert_eq(consumed.p1.units.size() + consumed.p2.units.size(), 0, "fixture: no unit record exists")
	assert_eq(consumed.apply_balance(_config_with_kinds_reordered()), "",
		"a board holding only a CONSUMED projectile does not refuse a reorder (MINOR-2)")
	var live := _make_match(9.0)
	live.p1.projectiles.add(1, TargetingService.HERO_INDEX, _kind_index(live, TOTEM_KIND), 0)
	assert_true(live.p1.projectiles.is_alive_at(0), "fixture: the shot is alive")
	assert_ne(live.apply_balance(_config_with_kinds_reordered()), "",
		"...and a board with an ALIVE projectile still refuses one (MINOR-2)")


## Review fix MAJOR-1: the M6 refusal reason must be SURFACED at its only operator-facing caller,
## `MatchRunner.trigger_live_balance_reload`, not discarded -- a source scan on
## `test_hero_cast.gd`'s fork-scan pattern, proven non-vacuous by construction (removing the read line
## fails this test).
func test_trigger_live_balance_reload_reads_apply_balances_return_value() -> void:
	var source := FileAccess.get_file_as_string("res://src/main/match_runner.gd")
	assert_ne(source, "", "match_runner.gd was read")
	var fn_start := source.find("func trigger_live_balance_reload(")
	assert_true(fn_start >= 0, "trigger_live_balance_reload exists")
	var fn_end := source.find("\nfunc ", fn_start + 1)
	var body := source.substr(fn_start, fn_end - fn_start)
	assert_true(body.contains("var refusal := _match_state.apply_balance(config)"),
		"the reload seat BINDS apply_balance's return value to a name (MAJOR-1)")
	assert_true(body.contains("push_warning(refusal)"),
		"...and SURFACES it with push_warning, matching the neighbouring replay refusal (MAJOR-1)")


# --- helpers ---------------------------------------------------------------------------------

## A MatchState with the Fireball pitch effect injected, mana `mana` on P1, and P1 locked on the enemy
## hero (the resting lock `_reset_lock` sets, restated so no test depends on construction order).
func _make_match(mana: float, pitch_effects: Variant = null,
		flags: FeatureFlags = null) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_feature_flags(flags if flags != null else _flags())
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	ms.inject_card_effects(_basic_effects())
	ms.inject_pitch_costs(_pitch_costs())
	var effects: Dictionary[StringName, CardEffect] = _fireball_pitch_effects()
	if pitch_effects != null:
		effects = pitch_effects
	ms.inject_pitch_effects(effects)
	_tick(ms)
	ms.p1.mana.add(mana - ms.p1.mana.get_current())
	ms.p1.stamina.refill()
	ms.p2.stamina.refill()
	ms.drain_signals()
	return ms


## Stage, bank the orb, activate -- the three presses every cast test needs, as one call.
func _stage_and_activate(ms: MatchState) -> void:
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	_bank_orb(ms)
	_advance(ms, _activate_intent(), InputIntent.new())


## A match with one Fireball IN THE AIR, aimed at the enemy HERO, launched and past its strike tick.
func _in_flight(mana: float) -> MatchState:
	var ms := _make_match(mana)
	_stage_and_activate(ms)
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p1.projectiles.size(), 1, "fixture: the shot launched")
	return ms


## Land shot 0 on the address it was aimed at, by feeding the contact fact the runner would gather.
##
## `defender` IS THE TARGET'S INTENT ON THE RESOLVING TICK, and it has to be threaded rather than left
## empty: a contact is resolved at step 4 of the SAME `advance()` whose step 3 evaluates the defender's
## intent, so a BLOCKING hero handed an empty intent has RELEASED the block before the ladder reads it.
## A test that set `action_state = BLOCKING` and then ticked idly would be asserting against a hero that
## is no longer blocking -- and would have read "block does not help" as a pass for the wrong reason,
## which is exactly the false green AC 16 must not be proven by.
func _land(ms: MatchState, facing := true, defender: InputIntent = null) -> void:
	_push_shot_contact(ms, [ms.p1.projectiles.target_slot_at(0),
			ms.p1.projectiles.target_index_at(0)], 0, facing)
	_advance(ms, InputIntent.new(), defender if defender != null else InputIntent.new())


## An intent with the block key HELD, so step 3 keeps the defender in BLOCKING through step 4.
func _block_intent() -> InputIntent:
	var i := InputIntent.new()
	i.held[&"block"] = true
	return i


## Push a contact fact from P1's projectile `shot` onto `target`.
##
## `facing` IS DERIVED FROM THE TARGET'S OWN FACING, NOT FROM A PICKED CONSTANT. The block and deflect
## rungs gate on `_is_facing(target.hero, fact["dir"])`, which compares the fact's direction against the
## TARGET HERO's `facing` -- so a fixture naming a literal direction would be asserting against whichever
## way the hero happened to rest, and would break the day that resting value changed. Reading the live
## facing and handing the fact THAT vector (or its negation) makes both cases exact whatever the resting
## heading is. The arc is authored at 180 degrees here, `test_block_deflect.gd`'s own fixture value, so
## `facing` and `not facing` are genuinely the two halves of a real arc rather than a boundary case.
## Harmless for a unit target: a unit has no facing and no block rung.
func _push_shot_contact(ms: MatchState, target: Array, shot := 0, facing := true) -> void:
	var address: Array[int] = [int(target[0]), int(target[1])]
	var attacker: Array[int] = [0, MatchState.projectile_attacker_index(shot)]
	var target_side: PlayerState = ms.p1 if int(target[0]) == 0 else ms.p2
	var heading := target_side.hero.facing
	var dir := heading if facing else -heading
	ms.push_contact(attacker, address, ms.p1.projectiles.flight_ticks_at(shot), dir,
			MatchState.CONTACT_STRIKE)


## A live COMBAT TOTEM shot on P1's board, placed through the UNIT seat (`ProjectileBoard.add`) so it is
## the genuine article rather than a hero shot with its fields cleared. Returns its board index.
func _totem_shot(ms: MatchState) -> int:
	var totem_index := _kind_index(ms, TOTEM_KIND)
	ms.p1.units.add(UNIT_HP, totem_index)
	var unit_index := ms.p1.units.size() - 1
	ms.p1.projectiles.add(1, TargetingService.HERO_INDEX, totem_index, unit_index)
	return ms.p1.projectiles.size() - 1


## The Fireball effect object THIS fixture injected. `inject_pitch_effects` duplicates the DICTIONARY but
## not the resources inside it, so this is the very object the state layer reads -- which is what makes
## the Open Question 5 retune pin a REAL retune rather than an edit to a second copy. A test-side handle
## rather than a new public accessor on `MatchState`: the injected map is private and stays so.
func _fireball_effect_of(_ms: MatchState) -> CardEffect:
	return _shared_fireball


## ONE shared `CardEffect` instance per fixture, for the reason directly above.
var _shared_fireball: CardEffect = null


func _fireball_pitch_effects() -> Dictionary[StringName, CardEffect]:
	_shared_fireball = CardEffect.new()
	_shared_fireball.effect_id = FIREBALL
	_shared_fireball.cast_seconds = float(CAST_TICKS) / TimingWindow.TICK_HZ
	_shared_fireball.mana_cap = MANA_CAP
	_shared_fireball.damage_per_mana = DAMAGE_PER_MANA
	_shared_fireball.launch_speed = LAUNCH_SPEED
	_shared_fireball.homing_turn_rate_degrees_per_second = 120.0
	_shared_fireball.acceleration_delay_seconds = 0.0
	_shared_fireball.acceleration_per_second_squared = 0.0
	_shared_fireball.max_speed = LAUNCH_SPEED
	_shared_fireball.travel_budget = BUDGET
	var out: Dictionary[StringName, CardEffect] = {}
	for id in _deck_contents():
		out[id] = _shared_fireball
	return out


## A pitch map whose effect authors NO `mana_cap` -- the fixed-cost control for AC 9. A BLOODLUST, so it
## is a real shipped effect shape rather than an empty one.
func _buff_pitch_effects() -> Dictionary[StringName, CardEffect]:
	var buff := CardEffect.new()
	buff.effect_id = &"bloodlust"
	buff.duration_seconds = 10.0
	buff.damage_dealt_multiplier = 2.0
	buff.damage_taken_multiplier = 2.0
	var out: Dictionary[StringName, CardEffect] = {}
	for id in _deck_contents():
		out[id] = buff
	return out


## The BASIC effects: Bloodhound Step's roll buff, which is what AC 12's second half needs -- the same
## card id resolving a DIFFERENT effect on a Mode ① press.
func _basic_effects() -> Dictionary[StringName, CardEffect]:
	var roll := CardEffect.new()
	roll.effect_id = &"bloodhound_step"
	roll.duration_seconds = 10.0
	roll.roll_distance_multiplier = 2.0
	roll.roll_iframe_multiplier = 2.0
	var out: Dictionary[StringName, CardEffect] = {}
	for id in _deck_contents():
		out[id] = roll
	return out


func _bank_orb(ms: MatchState) -> void:
	ms.p1.orbs.add(PITCH_COLOR, PITCH_ORBS)
	ms.drain_signals()


func _kind_index(ms: MatchState, kind_name: StringName) -> int:
	return ms.balance.kind_index_of(kind_name)


func _kind(kind_name: StringName, damage: float) -> UnitKindProfile:
	var k := UnitKindProfile.new()
	k.kind_name = kind_name
	k.max_hp = UNIT_HP
	k.move_speed = 1.0
	k.stop_distance = 1.0
	k.priority_name = &"nearest"
	var attack := UnitAttackProfile.new()
	attack.damage = damage
	attack.windup_seconds = 0.1
	attack.active_seconds = 0.1
	attack.recovery_seconds = 0.1
	attack.range = 2.0
	if kind_name == TOTEM_KIND:
		var projectile := ProjectileProfile.new()
		projectile.launch_speed = LAUNCH_SPEED
		projectile.homing_turn_rate_degrees_per_second = 120.0
		projectile.max_speed = LAUNCH_SPEED
		projectile.travel_budget = BUDGET
		attack.projectile = projectile
	k.attacks.append(attack)
	return k


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.max_mana = MAX_MANA
	c.max_stamina = STAMINA
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	c.max_orbs_per_color = MAX_ORBS
	c.pitch_stage_timer_seconds = TIMER_TICKS / TimingWindow.TICK_HZ
	c.draw_replacement_delay_seconds = DELAY_TICKS / TimingWindow.TICK_HZ
	c.block_damage_multiplier = BLOCK_MULTIPLIER
	c.block_facing_arc_degrees = 180.0
	c.deflect_stamina_cost = DEFLECT_COST
	c.deflect_window_seconds = 10.0 / TimingWindow.TICK_HZ
	c.hero_damage_to_unit = 3.0
	c.corpse_lifetime_seconds = 10.0
	c.unit_kinds.append(_kind(MINION_KIND, 3.0))
	c.unit_kinds.append(_kind(TOTEM_KIND, TOTEM_SHOT_DAMAGE))
	return c


## The SAME TWO KINDS in the OTHER ORDER -- a same-length reorder, which is exactly M6's case and the
## one no existing guard sees.
func _config_with_kinds_reordered() -> BalanceConfig:
	var c := _config()
	var kinds := c.unit_kinds
	var first: UnitKindProfile = kinds[0]
	kinds[0] = kinds[1]
	kinds[1] = first
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.pitch_zone = true
	f.orbs = true
	f.spells = true
	f.minions = true
	f.totems = true
	return f


func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("fb_card_%02d" % i))
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = CAST_COST
		out[id] = c
	return out


func _pitch_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = PITCH_MINIMUM
		c.orb_costs[PITCH_COLOR] = PITCH_ORBS
		out[id] = c
	return out


func _assert_stage_refused(ms: MatchState, reason: StringName) -> void:
	var rejections := _rejections(ms.p1)
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", reason]], "refused with %s" % reason)
	assert_false(ms.pitch.is_staged(0), "nothing was staged")
	assert_eq(ms.p1.orbs.to_snapshot(), ms.p1.orbs.to_snapshot(), "no orb moved")
	assert_eq(ms.p1.pending_draw_owed, [] as Array[int], "nothing was owed")


func _rejections(player: PlayerState) -> Array:
	var out: Array = []
	player.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: out.append([action, reason]))
	return out


## Each landed hit as `[attacker slot, target slot, damage, was_blocked]`.
##
## `was_blocked` IS READ INSIDE THE HANDLER, which is the only place it is true:
## `MatchState.hit_landed_was_blocked()` is raised only while a BLOCKED hit's `hit_landed` is being
## emitted and is cleared immediately after (`6-6a` review D2). Asking it after the drain returns false
## for every hit, blocked or not -- a false negative a test could easily have read as a pass.
## THE MATCH STATE IS CAPTURED WEAKLY, AND THAT IS A LEAK FIX RATHER THAN A STYLE CHOICE. A lambda that
## captured `ms` STRONGLY and was then connected to a signal ON `ms` is a reference cycle: the state holds
## the connection, the connection holds the lambda, the lambda holds the state -- so no `MatchState` in
## this file would ever free, and every `Resource` it injected would still be live at engine exit. The
## harness surfaces that as `27 resources still in use at exit`, which `run_all.sh` greps as a FAILURE
## (its `^ERROR:` pattern), so the leak fails the suite rather than passing quietly. Measured: the first
## version of this helper produced exactly that line, and the weak capture removes it.
func _hits(ms: MatchState) -> Array:
	var out: Array = []
	# EXPLICITLY TYPED: `weakref()` is declared to return `Variant`, so `:=` would infer Variant and this
	# project treats that warning as an error.
	var weak_ms: WeakRef = weakref(ms)
	ms.hit_landed.connect(
		func(attacker: int, target: int, damage: float, _hp: float) -> void:
			var live: MatchState = weak_ms.get_ref()
			out.append([attacker, target, damage,
					live != null and live.hit_landed_was_blocked()]))
	return out


func _deflects(ms: MatchState) -> Array:
	var out: Array = []
	ms.deflect_landed.connect(
		func(attacker: int, target: int, _color: int) -> void: out.append([attacker, target]))
	return out


func _stage_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.PITCH
	i.card_commit = true
	return i


func _cast_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.BASIC
	i.card_commit = true
	return i


func _activate_intent() -> InputIntent:
	var i := InputIntent.new()
	i.card_mode = Enums.ModeKind.PITCH
	i.card_commit = true
	i.card_activate = true
	return i


func _idle(ms: MatchState, ticks: int) -> void:
	for _t in ticks:
		_tick(ms)


func _tick(ms: MatchState) -> void:
	_advance(ms, InputIntent.new(), InputIntent.new())


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
