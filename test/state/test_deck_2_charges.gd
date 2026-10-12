extends TestCase

## Story 7-5a, PART B (AC 16-26): THE THREE CHARGES -- Setup, Execute and Stoneskin -- headless, on the
## shared `Deck2Fixture` (test-literal numbers: base hit 3, block 0.3, unblockable 10, orb grant 1,
## unblockable mana 1).
##
## SEAT 0 (P1) holds the charge under test unless a test says otherwise; seat 1 (P2) is the opponent.

const F := preload("res://test/deck_2_fixture.gd")


# ================================================================ SETUP (AC 16-19)

## AC 16: Setup costs its authored mana and adds ONE charge; several stack; it is never refused for
## being active.
func test_setup_costs_its_mana_and_adds_one_charge_and_stacks() -> void:
	var ms := F.make()
	var rejections := F.rejections(ms.p1)
	F.play(ms, 0, F.SETUP)
	assert_eq(ms.p1.mana.get_current(), F.MAX_MANA - 2.0, "Setup costs its authored 2 mana")
	assert_eq(ms.p1.to_snapshot()["setup"], [1, F.SETUP_MULTIPLIER], "one charge, carrying its multiplier")
	F.play(ms, 0, F.SETUP)
	F.play(ms, 0, F.SETUP)
	assert_eq(ms.p1.setup_charges, 3, "three Setups are three charges -- they stack (`7-5a/R9`)")
	assert_true(rejections.is_empty(), "a Setup is never refused for one already being held")
	assert_eq(ms.p2.setup_charges, 0, "the charge is the CASTER's")


## AC 17: the ACCEPTED press spends one charge and costs NO MANA; stamina is charged as always.
func test_an_accepted_unblockable_press_spends_one_charge_and_no_mana() -> void:
	var ms := F.make()
	F.play(ms, 0, F.SETUP)
	F.play(ms, 0, F.SETUP)
	var mana_before := ms.p1.mana.get_current()
	var stamina_before := ms.p1.stamina.get_current()
	assert_true(F.press_unblockable(ms, 0), "the press is accepted")
	assert_eq(ms.p1.mana.get_current(), mana_before, "a press with a Setup charge costs NO mana")
	assert_eq(ms.p1.stamina.get_current(), stamina_before - F.UNBLOCKABLE_STAMINA,
		"the stamina price is unchanged")
	assert_eq(ms.p1.setup_charges, 1, "ONE charge per unblockable -- one of the two is left")
	assert_eq(ms.p1.to_snapshot()["charge_setup"], F.SETUP_MULTIPLIER,
		"the attack CARRIES Setup from the press (the hashed per-attack fact)")


## AC 17: without a charge the press costs its mana, exactly as before the story -- and carries nothing.
func test_a_press_without_a_charge_costs_its_mana_and_carries_nothing() -> void:
	var ms := F.make()
	var mana_before := ms.p1.mana.get_current()
	assert_true(F.press_unblockable(ms, 0), "the press is accepted")
	assert_eq(ms.p1.mana.get_current(), mana_before - F.UNBLOCKABLE_MANA, "the unblockable's mana is paid")
	assert_eq(ms.p1.to_snapshot()["charge_setup"], 0.0, "an attack with no Setup behind it carries nothing")


## AC 17: Setup's saving is REAL -- a hero with no mana at all may still press while holding a charge,
## and a hero with no mana and no charge is refused for mana with nothing spent.
func test_a_charge_lets_a_hero_with_no_mana_press_and_no_charge_is_refused_for_mana() -> void:
	var ms := F.make()
	F.play(ms, 0, F.SETUP)
	F.set_mana(ms, ms.p1, 0.0)
	assert_true(F.press_unblockable(ms, 0), "with a charge, an empty mana pool does not stop the press")
	assert_eq(ms.p1.setup_charges, 0, "...and the charge is spent")
	var broke := F.make()
	F.set_mana(broke, broke.p1, 0.0)
	var rejections := F.rejections(broke.p1)
	var stamina_before := broke.p1.stamina.get_current()
	assert_false(F.press_unblockable(broke, 0), "with no charge and no mana the press is refused")
	assert_eq(rejections, [[&"card_cast", CastEvaluator.REASON_INSUFFICIENT_MANA]], "...for mana")
	assert_eq(broke.p1.stamina.get_current(), stamina_before, "...with no stamina spent")


## AC 17: a press refused for STAMINA spends nothing and KEEPS the charge.
func test_a_press_refused_for_stamina_keeps_the_charge() -> void:
	var ms := F.make()
	F.play(ms, 0, F.SETUP)
	ms.p1.stamina.spend(ms.p1.stamina.get_current(), 0)
	ms.drain_signals()
	var rejections := F.rejections(ms.p1)
	var mana_before := ms.p1.mana.get_current()
	assert_false(F.press_unblockable(ms, 0), "no stamina: the press is refused")
	assert_eq(rejections, [[&"card_cast", &"insufficient_stamina"]], "...for stamina")
	assert_eq(ms.p1.setup_charges, 1, "the charge is KEPT")
	assert_eq(ms.p1.mana.get_current(), mana_before, "no mana moved")
	assert_eq(ms.p1.to_snapshot()["charge_setup"], 0.0, "and no attack carries anything")
	assert_eq(ms.p1.hand.to_array()[1], F.PLAIN, "the card stays in hand")


## AC 17: a press refused for STATE (a blocking hero cannot initiate) spends nothing and keeps the charge.
func test_a_press_refused_for_state_keeps_the_charge() -> void:
	var ms := F.make()
	F.play(ms, 0, F.SETUP)
	F.act(ms, 0, F.press(&"block"))
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.BLOCKING, "fixture: the hero is blocking")
	var rejections := F.rejections(ms.p1)
	F.put(ms.p1, 1, F.PLAIN)
	var intent := F.card_intent(1, Enums.ModeKind.UNBLOCKABLE)
	intent.held[&"block"] = true
	F.act(ms, 0, intent)
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_UNBLOCKABLE_COMMITTED]], "refused for state")
	assert_eq(ms.p1.setup_charges, 1, "the charge is KEPT")


## AC 18: a carrying attack that LANDS grants double -- 1 becomes 2 -- and the carry rests (AC 19, landed).
func test_a_landed_attack_carrying_setup_grants_double_orbs() -> void:
	var ms := F.make()
	F.play(ms, 0, F.SETUP)
	assert_eq(F.land_unblockable(ms, 0), 1, "the unblockable landed")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 2 * F.ORB_GRANT,
		"a landed unblockable carrying Setup grants DOUBLE: 1 becomes 2")
	assert_eq(ms.p1.to_snapshot()["charge_setup"], 0.0, "AC 19 (landed): the carry is cleared")
	assert_eq(ms.p1.setup_charges, 0, "the charge was spent at the press")
	# ...and the SAME landing without Setup grants the plain amount (the doubling is the charge's doing).
	var plain := F.make()
	assert_eq(F.land_unblockable(plain, 0), 1, "the plain unblockable landed")
	assert_eq(plain.p1.orbs.get_count(Enums.CardColor.RED), F.ORB_GRANT, "no Setup: the plain grant")


## AC 18: the bank cap is respected -- at 2 of 3 a doubled grant fills the bank and stops.
func test_the_doubled_grant_respects_the_bank_cap() -> void:
	var ms := F.make()
	F.set_orbs(ms, ms.p1, F.MAX_ORBS - 1, 0, 0)
	F.play(ms, 0, F.SETUP)
	assert_eq(F.land_unblockable(ms, 0), 1, "the unblockable landed")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), F.MAX_ORBS, "the bank cap holds: 2 + 2 is 3")


## AC 18, non-landing case (per the AC's list: "blocked or deflected by the defender"). IN THIS REPO AN
## UNBLOCKABLE IS NOT STOPPED BY A BLOCK OR A DEFLECT (5-2 / 5-6: it never enters the block ladder), so a
## blocking defender is HIT. Pinned as what happens: the attack LANDS on a blocking defender and so the
## doubled grant is paid. (Recorded in the Dev Agent Record as a deviation from the AC's wording.)
func test_a_blocking_defender_does_not_stop_the_unblockable_so_the_setup_still_pays() -> void:
	var ms := F.make()
	F.play(ms, 0, F.SETUP)
	assert_true(F.press_unblockable(ms, 0), "the press is accepted")
	F.act(ms, 1, F.press(&"block"))
	assert_eq(F.fly_unblockable(ms, 0, F.held(&"block")), 1,
		"a held block does not stop an unblockable: it lands")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 2 * F.ORB_GRANT, "...so the Setup doubling is paid")
	assert_eq(ms.p1.to_snapshot()["charge_setup"], 0.0, "and the carry rests")


## AC 18/AC 19 (defended): a COLOUR COUNTER answers the attack -- no orb at all, the charge stays spent,
## and the carry is cleared at the counter's teardown.
func test_a_colour_countered_attack_wastes_the_charge_and_grants_nothing() -> void:
	var ms := F.make()
	F.play(ms, 0, F.SETUP)
	assert_true(F.press_unblockable(ms, 0), "P1 presses (a RED card)")
	assert_eq(ms.p1.to_snapshot()["charge_setup"], F.SETUP_MULTIPLIER, "the attack carries Setup")
	F.put(ms.p2, 2, F.PLAIN)
	F.act(ms, 1, F.card_intent(2, Enums.ModeKind.DEFENSE))
	assert_true(ms.p2.defense_window.is_running, "fixture: P2 answered with the same colour")
	assert_eq(F.fly_unblockable(ms, 0), 0, "the attack was countered -- it never landed")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "fixture: the attacker was knocked down")
	assert_eq(F.total_orbs(ms.p1), 0, "no orb is granted, doubled or otherwise")
	assert_eq(ms.p1.setup_charges, 0, "the charge is still spent")
	assert_eq(ms.p1.to_snapshot()["charge_setup"], 0.0, "AC 19 (defended): the carry is cleared")


## AC 18/AC 19: the defender ROLLS through every touch -- the attack misses, no extra orb, charge spent,
## and the carry is cleared at the landing exit.
func test_a_rolled_attack_wastes_the_charge_and_grants_nothing() -> void:
	var ms := F.make()
	F.play(ms, 0, F.SETUP)
	assert_true(F.press_unblockable(ms, 0), "P1 presses")
	var roll := F.press(&"roll")
	roll.move_dir = Vector2(1.0, 0.0)
	F.act(ms, 1, roll)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.ROLLING, "fixture: the defender is rolling")
	assert_eq(F.fly_unblockable(ms, 0), 0, "every touch fell inside the roll's i-frames")
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "the defender took nothing")
	assert_eq(F.total_orbs(ms.p1), 0, "no orb is granted")
	assert_eq(ms.p1.setup_charges, 0, "the charge is still spent")
	assert_eq(ms.p1.to_snapshot()["charge_setup"], 0.0, "AC 19 (missed): the carry is cleared at the landing exit")


## AC 18/AC 19: the defender is inside the POST-GET-UP IMMUNITY -- every touch is dropped, nothing is
## granted, the charge is spent and the carry clears.
func test_an_attack_into_the_post_get_up_immunity_wastes_the_charge() -> void:
	var ms := F.make()
	F.play(ms, 0, F.SETUP)
	ms.p2.hero.unblockable_immunity.start(F.IMMUNITY_TICKS)
	assert_true(F.press_unblockable(ms, 0), "P1 presses")
	assert_eq(F.fly_unblockable(ms, 0), 0, "the touch was dropped by the immunity")
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "the defender took nothing")
	assert_eq(F.total_orbs(ms.p1), 0, "no orb is granted")
	assert_eq(ms.p1.setup_charges, 0, "the charge is still spent")
	assert_eq(ms.p1.to_snapshot()["charge_setup"], 0.0, "the carry is cleared")


## AC 18/AC 19 (interrupted): the carrying attacker is KNOCKED DOWN DURING ITS CHARGEUP by the other
## hero's unblockable -- its own attack is abandoned, never lands, and its carry clears with it.
func test_a_knockdown_during_the_chargeup_abandons_the_attack_and_clears_the_carry() -> void:
	var ms := F.make()
	F.play(ms, 0, F.SETUP)
	assert_true(F.press_unblockable(ms, 1, F.PLAIN, 1), "P2 presses FIRST")
	F.idle(ms, 2)
	assert_true(F.press_unblockable(ms, 0, F.PLAIN, 1), "P1 presses two ticks later, carrying Setup")
	assert_eq(ms.p1.to_snapshot()["charge_setup"], F.SETUP_MULTIPLIER, "P1's attack carries Setup")
	assert_eq(F.fly_unblockable(ms, 1), 1, "P2's attack lands on the charging P1")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "P1 is knocked down mid-chargeup")
	assert_eq(ms.p1.to_snapshot()["charge_setup"], 0.0, "AC 19 (interrupted): the carry is cleared")
	assert_eq(F.total_orbs(ms.p1), 0, "P1's attack never landed: no orb")
	assert_eq(ms.p1.setup_charges, 0, "and its charge stays spent")


## AC 19 (interrupted, the bolt): a Honed Bolt stun abandons the carrying attack and clears the carry.
func test_a_bolt_stun_during_the_chargeup_clears_the_carry() -> void:
	var balance := F.config()
	balance.unblockable_chargeup_seconds = F.ticks_to_seconds(30)
	var ms := F.make(balance)
	F.play(ms, 0, F.SETUP)
	F.play(ms, 1, F.BOLT)   # P2's bolt is now in its cast window
	assert_true(ms.p2.is_casting(), "fixture: P2 is casting a bolt")
	assert_true(F.press_unblockable(ms, 0), "P1 presses, carrying Setup")
	F.idle(ms, 4)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "the bolt stunned the charging P1")
	assert_eq(ms.p1.to_snapshot()["charge_setup"], 0.0, "AC 19 (interrupted): the carry is cleared")


## The literal reading of AC 18's last named case ("defender knocked down during the chargeup"), pinned as
## what the repo does: a DOWNED defender is still hit by an unblockable (the floor rule skips only the
## second knockdown write), so that attack LANDS and the doubling is paid.
func test_a_defender_already_knocked_down_is_still_hit_so_the_setup_pays() -> void:
	var ms := F.make()
	F.play(ms, 0, F.SETUP)
	assert_true(F.press_unblockable(ms, 0), "P1 presses, carrying Setup")
	ms.p2.hero.start_stun(F.KNOCKDOWN_TICKS, false)
	ms.p2.hero.set_action_state(HeroState.ActionState.STUNNED)
	ms.drain_signals()
	assert_eq(F.fly_unblockable(ms, 0), 1, "a downed defender is still hit")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 2 * F.ORB_GRANT, "...so the doubling is paid")


## AC 19 (round end, reset): the carry is cleared by `_end_round` and by the debug reset, mid-flight.
func test_round_end_and_the_debug_reset_clear_the_carry_mid_flight() -> void:
	var ended := F.make()
	F.play(ended, 0, F.SETUP)
	assert_true(F.press_unblockable(ended, 0), "P1 presses, carrying Setup")
	ended.p2.hero.take_damage(F.MAX_HP)
	F.idle(ended, 1)
	assert_true(ended.to_snapshot()["round_over"], "fixture: the round ended with the attack in flight")
	assert_eq(ended.p1.to_snapshot()["charge_setup"], 0.0, "AC 19 (round end): the carry is cleared")
	var reset := F.make()
	F.play(reset, 0, F.SETUP)
	assert_true(F.press_unblockable(reset, 0), "P1 presses, carrying Setup")
	assert_eq(reset.p1.to_snapshot()["charge_setup"], F.SETUP_MULTIPLIER, "sanity: carrying before the reset")
	var intent := InputIntent.new()
	intent.debug_reset = true
	F.act(reset, 0, intent)
	assert_eq(reset.p1.to_snapshot()["charge_setup"], 0.0, "AC 19 (reset): the carry is cleared")


# ================================================================ EXECUTE (AC 20-23)

## AC 20: Execute costs its mana at STAGING and one red orb at ACTIVATION, and adds one charge; several stack.
func test_execute_costs_mana_at_staging_and_an_orb_at_activation_and_stacks() -> void:
	var ms := F.make()
	var rejections := F.rejections(ms.p1)
	F.stage(ms, 0, F.SETUP)
	assert_eq(ms.p1.mana.get_current(), F.MAX_MANA - 4.0, "the staging pays Execute's 4 mana")
	assert_eq(ms.p1.execute_charges, 0, "staging alone adds no charge")
	F.set_orbs(ms, ms.p1, 2, 0, 0)
	F.activate(ms, 0)
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 1, "the activation spends ONE red orb")
	assert_eq(ms.p1.to_snapshot()["execute"], [1, F.EXECUTE_MULTIPLIER], "one charge, carrying its multiplier")
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.pitch(ms, 0, F.SETUP)
	assert_eq(ms.p1.execute_charges, 2, "a second Execute is a second charge (never refused for being active)")
	assert_true(rejections.is_empty(), "nothing was refused")


## AC 21: a CLEAN melee hit on the opposing hero consumes the charge and deals TRIPLE.
func test_a_clean_melee_hit_consumes_execute_and_deals_triple() -> void:
	var ms := _with_execute(1)
	assert_eq(F.melee_hit(ms, 0), F.HIT_DAMAGE * F.EXECUTE_MULTIPLIER, "3 becomes 9")
	assert_eq(ms.p1.execute_charges, 0, "the charge is consumed")
	assert_eq(F.melee_hit(ms, 0), F.HIT_DAMAGE, "the next hit is a plain one")


## AC 21: an UNBLOCKABLE is a weapon hit -- it consumes the charge and is tripled.
func test_an_unblockable_consumes_execute_and_deals_triple() -> void:
	var ms := _with_execute(1)
	assert_eq(F.land_unblockable(ms, 0), 1, "the unblockable landed")
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - F.UNBLOCKABLE_DAMAGE * F.EXECUTE_MULTIPLIER, "10 becomes 30")
	assert_eq(ms.p1.execute_charges, 0, "the charge is consumed")


## AC 21: a hit on a UNIT never consumes Execute and is not tripled.
func test_a_hit_on_a_unit_neither_consumes_nor_triples() -> void:
	var ms := _with_execute(1)
	ms.p2.units.add(F.MINION_HP, 0)
	assert_eq(F.melee_hit_unit(ms, 0, 0), F.HERO_TO_UNIT, "a minion takes the plain hit")
	assert_eq(ms.p1.execute_charges, 1, "the charge is KEPT")
	ms.p2.units.add(F.MINION_HP, 1)
	assert_eq(F.melee_hit_unit(ms, 0, 1), F.HERO_TO_UNIT, "a totem takes the plain hit")
	assert_eq(ms.p1.execute_charges, 1, "the charge is still kept")


## AC 21: spells and projectiles are NOT weapon hits -- a Honed Bolt and a hero-sourced shot leave the
## charge alone and deal their own damage.
func test_spells_and_projectiles_do_not_consume_execute() -> void:
	var ms := _with_execute(1)
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.play(ms, 0, F.BOLT)
	F.idle(ms, 3)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - F.BOLT_DAMAGE, "the bolt deals its own damage, untripled")
	assert_eq(ms.p1.execute_charges, 1, "the bolt did not consume the charge")
	ms.p1.projectiles.add_hero_shot(1, TargetingService.HERO_INDEX, &"fireball", 4.0)
	var hp_before := ms.p2.hero.get_hp()
	ms.push_contact([0, MatchState.projectile_attacker_index(0)], [1, -1], 0, F.FACT_DIR,
			MatchState.CONTACT_STRIKE)
	F.idle(ms, 1)
	assert_eq(hp_before - ms.p2.hero.get_hp(), 4.0, "the projectile deals its own damage, untripled")
	assert_eq(ms.p1.execute_charges, 1, "the projectile did not consume the charge")


## AC 22: a BLOCKED hit does not consume Execute and is not tripled, but deals its reduced damage.
func test_a_blocked_hit_keeps_execute_and_deals_reduced_damage() -> void:
	var ms := _with_execute(1)
	assert_almost_eq(F.melee_hit(ms, 0, true), F.HIT_DAMAGE * F.BLOCK_MULT, 0.0001,
		"a blocked hit deals 3 x 0.3 = 0.9, not tripled")
	assert_eq(ms.p1.execute_charges, 1, "the charge is KEPT")


## AC 22: a DEFLECTED hit and a ROLLED (i-frame) hit do not consume Execute; a MISSED swing does not either.
func test_deflected_rolled_and_missed_hits_keep_execute() -> void:
	var deflected := _with_execute(1)
	assert_eq(F.melee_hit(deflected, 0, false, true), 0.0, "a deflected hit deals nothing")
	assert_eq(deflected.p1.execute_charges, 1, "deflected: the charge is kept")
	var rolled := _with_execute(1)
	var roll := F.press(&"roll")
	roll.move_dir = Vector2(1.0, 0.0)
	F.act(rolled, 1, roll)
	assert_eq(F.melee_hit(rolled, 0), 0.0, "a hit inside the roll's i-frames is dropped")
	assert_eq(rolled.p1.execute_charges, 1, "rolled: the charge is kept")
	var missed := _with_execute(1)
	F.act(missed, 0, F.press(&"attack"))
	F.idle(missed, 12)
	assert_eq(missed.p1.execute_charges, 1, "a swing that touches nothing keeps the charge")


## AC 22/AC 25: a hit ABSORBED BY STONESKIN still consumes Execute (and the Stoneskin charge).
func test_a_hit_absorbed_by_stoneskin_still_consumes_execute() -> void:
	var ms := _with_execute(1)
	ms.p2.add_stoneskin_charge()
	assert_eq(F.melee_hit(ms, 0), 0.0, "Stoneskin absorbs the tripled hit whole")
	assert_eq(ms.p1.execute_charges, 0, "Execute IS consumed by the absorbed hit")
	assert_eq(ms.p2.stoneskin_charges, 0, "...and so is the Stoneskin charge")


## AC 23: Execute grants NO orbs, on either consumer.
func test_execute_grants_no_orbs_on_any_consumer() -> void:
	var melee := _with_execute(1)
	F.melee_hit(melee, 0)
	assert_eq(F.total_orbs(melee.p1), 0, "a tripled melee hit grants no orb")
	var unblockable := _with_execute(1)
	F.land_unblockable(unblockable, 0)
	assert_eq(unblockable.p1.orbs.get_count(Enums.CardColor.RED), F.ORB_GRANT,
		"a tripled unblockable grants only the landing's own orb -- Execute adds none")


## AC 23: two charges, two clean hits: x3 EACH and none left -- never multiplied together.
func test_two_charges_triple_two_hits_once_each() -> void:
	var ms := _with_execute(2)
	assert_eq(F.melee_hit(ms, 0), F.HIT_DAMAGE * F.EXECUTE_MULTIPLIER, "the first hit is x3, not x9")
	assert_eq(ms.p1.execute_charges, 1, "one charge left")
	assert_eq(F.melee_hit(ms, 0), F.HIT_DAMAGE * F.EXECUTE_MULTIPLIER, "the second hit is x3")
	assert_eq(ms.p1.to_snapshot()["execute"], [0, 0.0], "none left, and the magnitude rests with the stack")


# ================================================================ STONESKIN (AC 24-26)

## AC 24: Stoneskin costs its mana at staging and one green orb at activation, and adds one charge; they stack.
func test_stoneskin_costs_mana_at_staging_and_an_orb_at_activation_and_stacks() -> void:
	var ms := F.make()
	F.stage(ms, 0, F.STONE)
	assert_eq(ms.p1.mana.get_current(), F.MAX_MANA - 2.0, "the staging pays Stoneskin's 2 mana")
	F.set_orbs(ms, ms.p1, 0, 0, 2)
	F.activate(ms, 0)
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.GREEN), 1, "the activation spends ONE green orb")
	assert_eq(ms.p1.to_snapshot()["stoneskin"], 1, "one charge")
	F.pitch(ms, 0, F.STONE)
	assert_eq(ms.p1.stoneskin_charges, 2, "a second Stoneskin is a second charge")


## AC 24: the next damage instance from ANY source deals zero and spends one charge -- one test per source.
func test_stoneskin_absorbs_a_melee_hit() -> void:
	var ms := _with_stoneskin(1)
	assert_eq(F.melee_hit(ms, 0), 0.0, "the melee hit deals zero")
	assert_eq(ms.p2.stoneskin_charges, 0, "the charge is consumed")
	assert_eq(F.melee_hit(ms, 0), F.HIT_DAMAGE, "the next hit lands in full")


## AC 24/AC 25: an absorbed UNBLOCKABLE still knocks the defender down and still pays the attacker's orbs;
## only the damage is absorbed, and the charge is consumed.
func test_an_absorbed_unblockable_still_knocks_down_and_still_grants_orbs() -> void:
	var ms := _with_stoneskin(1)
	assert_eq(F.land_unblockable(ms, 0), 1, "the unblockable LANDED (`hit_landed` fired)")
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "its damage was absorbed")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "the defender is still knocked down")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), F.ORB_GRANT, "the attacker still earned its orb")
	assert_eq(ms.p2.stoneskin_charges, 0, "the charge is consumed")


func test_stoneskin_absorbs_a_spell() -> void:
	var ms := _with_stoneskin(1)
	F.play(ms, 0, F.BOLT)
	F.idle(ms, 3)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "the bolt's damage was absorbed")
	assert_eq(ms.p2.stoneskin_charges, 0, "the charge is consumed")


func test_stoneskin_absorbs_a_projectile_hit() -> void:
	var ms := _with_stoneskin(2)
	ms.p1.projectiles.add_hero_shot(1, TargetingService.HERO_INDEX, &"fireball", 4.0)
	ms.push_contact([0, MatchState.projectile_attacker_index(0)], [1, -1], 0, F.FACT_DIR,
			MatchState.CONTACT_STRIKE)
	F.idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "the hero projectile's damage was absorbed")
	assert_eq(ms.p2.stoneskin_charges, 1, "one charge consumed, one left")
	assert_false(ms.p1.projectiles.is_alive_at(0), "the shot was still consumed -- it resolved")


func test_stoneskin_absorbs_a_minion_hit() -> void:
	var ms := _with_stoneskin(1)
	ms.p1.units.add(F.MINION_HP, 0)
	ms.p1.units.set_target_at(0, 1, -1)
	ms.push_contact([0, 0], [1, -1], 0, F.FACT_DIR, MatchState.CONTACT_REACH_PROBE)
	F.idle(ms, 4)
	ms.push_contact([0, 0], [1, -1], ms.p1.units.attack_count_at(0), F.FACT_DIR, MatchState.CONTACT_STRIKE)
	F.idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "the minion's bite was absorbed")
	assert_eq(ms.p2.stoneskin_charges, 0, "the charge is consumed")


## AC 24 (`7-5a/R27`): ONE Boulder's Boom is one instance -- two Boulders and one charge leave one Boulder's
## damage through.
func test_one_stoneskin_charge_absorbs_one_boulders_boom() -> void:
	var ms := _with_stoneskin(1)
	ms.p2.hand.cover_at(0, F.BOULDER)
	ms.p2.hand.cover_at(1, F.BOULDER)
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.pitch(ms, 0, F.BOOM)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - F.BOOM_DAMAGE,
		"two Boulders detonated, ONE was absorbed: one Boulder's damage got through")
	assert_eq(ms.p2.stoneskin_charges, 0, "the one charge is consumed")


## AC 25: a hit the hero AVOIDS (deflected, rolled) does not consume a charge.
func test_avoided_hits_do_not_consume_stoneskin() -> void:
	var deflected := _with_stoneskin(1)
	assert_eq(F.melee_hit(deflected, 0, false, true), 0.0, "a deflected hit deals nothing")
	assert_eq(deflected.p2.stoneskin_charges, 1, "deflected: the charge is kept")
	var rolled := _with_stoneskin(1)
	var roll := F.press(&"roll")
	roll.move_dir = Vector2(1.0, 0.0)
	F.act(rolled, 1, roll)
	assert_eq(F.melee_hit(rolled, 0), 0.0, "a rolled hit is dropped")
	assert_eq(rolled.p2.stoneskin_charges, 1, "rolled: the charge is kept")


## AC 21/AC 24, the "would damage" half: a hit that deals ZERO damage is not "the next damage instance" and
## not "a hit that would damage the opposing hero" -- it spends neither a Stoneskin charge nor an Execute
## charge. (Added at the mutation pass: the `damage > 0.0` guard on the Stoneskin seat survived a mutant
## until this test existed -- both states are in the dev log.)
func test_a_zero_damage_hit_spends_neither_stoneskin_nor_execute() -> void:
	var balance := F.config()
	balance.attack_damage_percent_of_max_hp = 0.0
	var ms := F.make(balance)
	ms.p2.add_stoneskin_charge()
	ms.p1.add_execute_charge(F.EXECUTE_MULTIPLIER)
	assert_eq(F.melee_hit(ms, 0), 0.0, "fixture: the swing deals zero damage")
	assert_eq(ms.p2.stoneskin_charges, 1, "a zero-damage hit does NOT spend the Stoneskin charge")
	assert_eq(ms.p1.execute_charges, 1, "...and does NOT spend the Execute charge")


## AC 24: several stack as charges, ONE INSTANCE EACH, and there is NO TIMER.
func test_stoneskin_charges_absorb_one_instance_each_and_never_expire() -> void:
	var ms := _with_stoneskin(2)
	F.idle(ms, 2000)
	assert_eq(ms.p2.stoneskin_charges, 2, "no timer: both charges are still held after 2000 idle ticks")
	assert_eq(F.melee_hit(ms, 0), 0.0, "the first instance is absorbed")
	assert_eq(F.melee_hit(ms, 0), 0.0, "the second instance is absorbed")
	assert_eq(F.melee_hit(ms, 0), F.HIT_DAMAGE, "the third lands -- one instance per charge")


## AC 26: charges are cleared at round end and at the debug reset.
func test_stoneskin_charges_clear_at_round_end_and_at_the_reset() -> void:
	var ended := _with_stoneskin(2)
	ended.p1.hero.take_damage(F.MAX_HP)
	F.idle(ended, 1)
	assert_true(ended.to_snapshot()["round_over"], "fixture: the round ended")
	assert_eq(ended.p2.stoneskin_charges, 0, "round end clears the charges")
	var reset := _with_stoneskin(2)
	var intent := InputIntent.new()
	intent.debug_reset = true
	F.act(reset, 0, intent)
	assert_eq(reset.p2.stoneskin_charges, 0, "the debug reset clears the charges")


# ---------------------------------------------------------------- fixtures

## A match in which P1 holds `charges` Execute charges (added directly, at the fixture's multiplier).
func _with_execute(charges: int) -> MatchState:
	var ms := F.make()
	for _c in charges:
		ms.p1.add_execute_charge(F.EXECUTE_MULTIPLIER)
	return ms


## A match in which P2 (the defender) holds `charges` Stoneskin charges.
func _with_stoneskin(charges: int) -> MatchState:
	var ms := F.make()
	for _c in charges:
		ms.p2.add_stoneskin_charge()
	return ms
