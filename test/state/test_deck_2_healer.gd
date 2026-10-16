extends TestCase

## Story 7-5b (AC 1-8): THE HEALER, headless. Summon, body, heal clock, the same-side range intake, the
## shot on the owner's chargeup, its defences, and the Counterspell reversal. Every number is a test literal
## (`deck_2_bodies_fixture.gd`, `BC/R3`).

const Fx := preload("res://test/deck_2_bodies_fixture.gd")
const F := preload("res://test/deck_2_fixture.gd")


# ---------------------------------------------------------------- AC 1/AC 2: summon

## AC 2: Healer costs its mana and summons ONE unit of the Healer kind, at that kind's maximum.
func test_the_healer_summons_one_unit_of_its_own_kind() -> void:
	var ms := Fx.make()
	var index := Fx.summon_healer(ms, 0)
	assert_eq(index, 0, "one record joins the board")
	assert_eq(ms.p1.units.size(), 1, "...exactly one")
	assert_eq(ms.p1.units.kind_index_at(0), ms.balance.kind_index_of(&"healer"), "...of the Healer kind")
	assert_eq(ms.p1.units.hp_at(0), Fx.HEALER_HP, "...at the kind's authored maximum")
	assert_eq(ms.p1.mana.get_current(), F.MAX_MANA - 3.0, "the card's mana is paid")


## AC 1: the minion layer OFF resolves the cast and puts nothing on the board.
func test_with_the_minion_layer_off_the_healer_resolves_and_summons_nothing() -> void:
	var ms := Fx.make(Fx.flags_with(false, true))
	var rejections := F.rejections(ms.p1)
	F.play(ms, 0, Fx.HEALER)
	assert_true(rejections.is_empty(), "not refused")
	assert_eq(ms.p1.units.size(), 0, "nothing is summoned")
	assert_eq(ms.p1.discard.size(), 1, "...the card still resolved (discarded)")


# ---------------------------------------------------------------- AC 3/AC 4/AC 5: the body

## AC 4: six basic hero hits kill an unbuffed Healer (18 hp at 3 per hit), it leaves a corpse, and it has
## NO hit reaction (AC 5).
func test_six_hero_hits_kill_the_healer_and_it_leaves_a_corpse_without_flinching() -> void:
	var ms := Fx.make()
	Fx.summon_healer(ms, 0)
	for hit in 5:
		F.melee_hit_unit(ms, 1, 0)
		assert_true(ms.p1.units.is_alive_at(0), "alive after %d hits" % (hit + 1))
		assert_eq(ms.p1.units.behavior_phase_at(0), UnitBoard.BehaviorPhase.ENGAGE,
			"...and never reacting (AC 5)")
	F.melee_hit_unit(ms, 1, 0)
	assert_false(ms.p1.units.is_alive_at(0), "the SIXTH hit kills it")
	assert_true(ms.p1.units.has_corpse_at(0), "...and it leaves a corpse (`is_minion`, AC 5)")


## AC 3: it never acquires an enemy target, never attacks, and draws nothing from the match RNG.
func test_the_healer_never_targets_never_attacks_and_draws_no_rng() -> void:
	var ms := Fx.make()
	Fx.summon_healer(ms, 0)
	var rng_before := int(ms.to_snapshot()["rng_state"])
	for _t in 120:
		Fx.advance_with_ranges(ms, [[0, 0]])
	assert_eq(ms.p1.units.target_slot_at(0), TargetingService.NO_TARGET_SLOT, "it acquires no target")
	assert_eq(ms.p1.units.attack_phase_at(0), UnitBoard.AttackPhase.IDLE, "it never winds up")
	assert_eq(int(ms.to_snapshot()["rng_state"]), rng_before, "...and the match RNG never moves")


# ---------------------------------------------------------------- AC 6: the heal

## AC 6: in range, the owner heals the authored amount on the interval's tick and not before.
func test_in_range_the_owner_heals_on_the_interval_tick() -> void:
	var ms := Fx.make()
	Fx.summon_healer(ms, 0)
	F.set_hp(ms, ms.p1, 50.0)
	for _t in Fx.HEAL_INTERVAL_TICKS - 1:
		Fx.advance_with_ranges(ms, [[0, 0]])
	assert_eq(ms.p1.hero.get_hp(), 50.0, "nothing before the interval")
	Fx.advance_with_ranges(ms, [[0, 0]])
	assert_eq(ms.p1.hero.get_hp(), 50.0 + Fx.HEAL_AMOUNT, "the authored heal on the interval tick")
	assert_eq(ms.p1.units.heal_count_at(0), 1, "...counted as a heal")


## AC 6 (`7-5b/R3`): OUT OF RANGE the clock keeps running and the tick heals nothing -- it is skipped, not
## banked: the next in-range interval heals once, on its own tick.
func test_out_of_range_the_clock_runs_and_the_tick_is_skipped() -> void:
	var ms := Fx.make()
	Fx.summon_healer(ms, 0)
	F.set_hp(ms, ms.p1, 50.0)
	for _t in Fx.HEAL_INTERVAL_TICKS:
		Fx.advance_with_ranges(ms, [])
	assert_eq(ms.p1.hero.get_hp(), 50.0, "out of range on the interval tick: no heal")
	assert_eq(ms.p1.units.heal_ticks_at(0), 0, "...but the clock closed its tick and restarted")
	assert_eq(ms.p1.units.heal_count_at(0), 0, "...and counted no heal")
	for _t in Fx.HEAL_INTERVAL_TICKS - 1:
		Fx.advance_with_ranges(ms, [[0, 0]])
	assert_eq(ms.p1.hero.get_hp(), 50.0, "back in range, nothing before the next interval -- nothing banked")
	Fx.advance_with_ranges(ms, [[0, 0]])
	assert_eq(ms.p1.hero.get_hp(), 50.0 + Fx.HEAL_AMOUNT, "...and one heal on it")


## AC 6: the range fact is SAME-SIDE and per unit -- a push for the OTHER slot, or for another index, does
## not put this Healer in range.
func test_only_this_slots_push_for_this_index_puts_the_healer_in_range() -> void:
	var ms := Fx.make()
	Fx.summon_healer(ms, 0)
	F.set_hp(ms, ms.p1, 50.0)
	for _t in Fx.HEAL_INTERVAL_TICKS:
		Fx.advance_with_ranges(ms, [[1, 0], [0, 7]])
	assert_eq(ms.p1.hero.get_hp(), 50.0, "a push for the other slot or another index heals nothing")


## AC 6: healing never exceeds max HP, and two Healers heal independently.
func test_two_healers_heal_independently_and_never_past_the_maximum() -> void:
	var ms := Fx.make()
	Fx.summon_healer(ms, 0, 0)
	Fx.summon_healer(ms, 0, 1)
	F.set_hp(ms, ms.p1, 90.0)
	# The second Healer joined one tick later (its summon tick already counted one on the first's clock),
	# so its clock runs one tick behind the first's.
	for _t in Fx.HEAL_INTERVAL_TICKS - 2:
		Fx.advance_with_ranges(ms, [[0, 0], [0, 1]])
	assert_eq(ms.p1.hero.get_hp(), 90.0, "sanity: nothing yet")
	Fx.advance_with_ranges(ms, [[0, 0], [0, 1]])
	assert_eq(ms.p1.hero.get_hp(), 90.0 + Fx.HEAL_AMOUNT, "the first Healer's tick")
	Fx.advance_with_ranges(ms, [[0, 0], [0, 1]])
	assert_eq(ms.p1.hero.get_hp(), 90.0 + 2.0 * Fx.HEAL_AMOUNT, "...and the second's, one tick later")
	F.set_hp(ms, ms.p1, F.MAX_HP - 1.0)
	for _t in Fx.HEAL_INTERVAL_TICKS + 1:
		Fx.advance_with_ranges(ms, [[0, 0], [0, 1]])
	assert_eq(ms.p1.hero.get_hp(), F.MAX_HP, "the heal clamps at the maximum")


## AC 6: a dead owner, or a frozen round, heals nothing.
func test_a_dead_owner_or_a_frozen_round_heals_nothing() -> void:
	var ms := Fx.make()
	Fx.summon_healer(ms, 0)
	ms.p1.hero.take_damage(ms.p1.hero.get_hp())
	for _t in Fx.HEAL_INTERVAL_TICKS * 3:
		Fx.advance_with_ranges(ms, [[0, 0]])
	assert_eq(ms.p1.hero.get_hp(), 0.0, "the dead owner is never healed back to life")


## AC 6: healing triggers nothing -- no `hit_landed`, no Stoneskin charge spent, no Lifechain split.
func test_a_heal_is_not_damage_and_triggers_nothing() -> void:
	var ms := Fx.make()
	Fx.summon_healer(ms, 0)
	F.set_hp(ms, ms.p1, 50.0)
	ms.p1.add_stoneskin_charge()
	var hits: Array = []
	ms.hit_landed.connect(func(a: int, t: int, _d: float, _h: float) -> void: hits.append([a, t]))
	for _t in Fx.HEAL_INTERVAL_TICKS:
		Fx.advance_with_ranges(ms, [[0, 0]])
	assert_eq(ms.p1.hero.get_hp(), 50.0 + Fx.HEAL_AMOUNT, "healed")
	assert_true(hits.is_empty(), "no `hit_landed`")
	assert_eq(ms.p1.stoneskin_charges, 1, "no Stoneskin charge spent")


# ---------------------------------------------------------------- AC 7: the shot

## AC 7: the owner's ACCEPTED unblockable press owes one shot per living Healer; it spawns after the
## authored delay as a hero-sourced record at the opposing hero, launched from the Healer.
func test_an_accepted_chargeup_spawns_one_shot_per_healer_after_the_delay() -> void:
	var ms := Fx.make()
	Fx.summon_healer(ms, 0, 0)
	Fx.summon_healer(ms, 0, 2)
	assert_true(F.press_unblockable(ms, 0), "the press is accepted")
	assert_eq(ms.p1.units.shot_owed_at(0), Fx.SHOT_DELAY_TICKS - 1, "a shot is owed (one tick already counted)")
	F.idle(ms, Fx.SHOT_DELAY_TICKS - 1)
	assert_eq(ms.p1.projectiles.size(), 0, "nothing before the spawn tick")
	F.idle(ms, 1)
	assert_eq(ms.p1.projectiles.size(), 2, "ONE shot per Healer on the spawn tick")
	for shot in 2:
		assert_true(ms.p1.projectiles.is_hero_sourced_at(shot), "shot %d is hero-sourced (a stone's ladder)" % shot)
		assert_eq(ms.p1.projectiles.target_slot_at(shot), 1, "...at the OPPOSING slot")
		assert_eq(ms.p1.projectiles.target_index_at(shot), TargetingService.HERO_INDEX, "...its HERO")
		assert_eq(ms.p1.projectiles.damage_at(shot), Fx.SHOT_DAMAGE, "...with the authored damage")
		assert_eq(ms.p1.projectiles.effect_id_at(shot), "healer", "...authored by the Healer's effect")
	assert_eq(ms.p1.projectiles.source_index_at(0), 0, "launched from Healer 0")
	assert_eq(ms.p1.projectiles.source_index_at(1), 1, "...and Healer 1")
	assert_eq(ms.p1.units.shot_owed_at(0), UnitBoard.NO_SHOT_OWED, "nothing more is owed")
	F.idle(ms, 20)
	assert_eq(ms.p1.projectiles.size(), 2, "one per Healer PER CHARGEUP, whatever the unblockable does")


## AC 7: a press REFUSED for stamina (or mana, or state) owes nothing.
func test_a_refused_press_fires_nothing() -> void:
	var ms := Fx.make()
	Fx.summon_healer(ms, 0)
	ms.p1.stamina.spend(ms.p1.stamina.get_current(), 0)
	assert_false(F.press_unblockable(ms, 0), "the press is refused for stamina")
	assert_eq(ms.p1.units.shot_owed_at(0), UnitBoard.NO_SHOT_OWED, "no shot is owed")
	F.idle(ms, Fx.SHOT_DELAY_TICKS + 2)
	assert_eq(ms.p1.projectiles.size(), 0, "...and none spawns")


## AC 7: a Healer dead before its spawn tick fires nothing.
func test_a_healer_dead_before_the_spawn_tick_fires_nothing() -> void:
	var ms := Fx.make()
	Fx.summon_healer(ms, 0)
	assert_true(F.press_unblockable(ms, 0), "accepted")
	ms.p1.units.kill_at(0, 0)
	F.idle(ms, Fx.SHOT_DELAY_TICKS + 2)
	assert_eq(ms.p1.projectiles.size(), 0, "a dead Healer fires nothing")
	assert_eq(ms.p1.units.shot_owed_at(0), UnitBoard.NO_SHOT_OWED, "...and owes nothing")


## AC 7: a ZERO delay spawns on the chargeup tick itself.
func test_a_zero_delay_spawns_on_the_chargeup_tick() -> void:
	var config := Fx.config()
	config.unit_kinds[config.kind_index_of(&"healer")].shot_delay_seconds = 0.0
	var ms := Fx.make(null, config)
	Fx.summon_healer(ms, 0)
	assert_true(F.press_unblockable(ms, 0), "accepted")
	assert_eq(ms.p1.projectiles.size(), 1, "the shot spawned on the chargeup tick")


# ---------------------------------------------------------------- AC 8: the shot's defences

## A live Healer shot at P2's hero; returns its board index.
func _healer_shot(ms: MatchState) -> int:
	Fx.summon_healer(ms, 0)
	F.press_unblockable(ms, 0)
	F.idle(ms, Fx.SHOT_DELAY_TICKS)
	assert_eq(ms.p1.projectiles.size(), 1, "fixture: one Healer shot is in the air")
	return ms.p1.projectiles.size() - 1


func _shot_fact(ms: MatchState, shot: int, target_index: int = TargetingService.HERO_INDEX,
		facing := true) -> void:
	var dir := ms.p2.hero.facing if facing else -ms.p2.hero.facing
	ms.push_contact([0, MatchState.projectile_attacker_index(shot)], [1, target_index],
			ms.p1.projectiles.flight_ticks_at(shot), dir, MatchState.CONTACT_STRIKE)


## AC 8: it deals its authored damage, plants no Boulder, and is consumed.
func test_the_shot_deals_its_damage_plants_no_boulder_and_is_consumed() -> void:
	var ms := Fx.make()
	var shot := _healer_shot(ms)
	_shot_fact(ms, shot)
	F.idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - Fx.SHOT_DAMAGE, "the authored damage")
	assert_false(ms.p1.projectiles.is_alive_at(shot), "...and the shot is consumed")
	assert_eq(ms.p2.hand.cover_count(), 0, "it plants NO Boulder")


## Smoke fix 1 (S9, superseding AC 8's block clause, `7-5b/R4`/`R23`, for this shot only): a held BLOCK facing it
## takes the EFFECT's own share -- a third, 1.0 of 3.0 -- and the shot is consumed. Every other hero-sourced shot
## authors no share and stays exempt: `test_fireball.gd`'s `test_block_does_not_reduce_a_fireball_facing_or_not`
## and `test_rocksling_and_boulder.gd`'s two stone pins are that half.
func test_a_block_takes_the_shots_own_blocked_share() -> void:
	var ms := Fx.make()
	var shot := _healer_shot(ms)
	ms.p2.stamina.spend(ms.p2.stamina.get_current(), 0)   # no stamina to deflect
	F.act(ms, 1, F.press(&"block"))
	_shot_fact(ms, shot)
	F.act(ms, 1, F.held(&"block"))
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.BLOCKING, "sanity: P2 is blocking")
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - Fx.SHOT_DAMAGE * Fx.HEALER_BLOCKED_MULT,
		"a third of the shot lands through the block (1.0 of 3.0)")
	assert_false(ms.p1.projectiles.is_alive_at(shot), "...and the blocked shot is consumed")


## Smoke fix 1 (S9): the share is a BLOCK's, so a block held FACING AWAY from the shot takes all of it.
func test_a_block_facing_away_takes_the_whole_shot() -> void:
	var ms := Fx.make()
	var shot := _healer_shot(ms)
	ms.p2.stamina.spend(ms.p2.stamina.get_current(), 0)
	F.act(ms, 1, F.press(&"block"))
	_shot_fact(ms, shot, TargetingService.HERO_INDEX, false)
	F.act(ms, 1, F.held(&"block"))
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.BLOCKING, "sanity: P2 is blocking")
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - Fx.SHOT_DAMAGE, "the FULL shot lands on a block that faces away")


## AC 8: a timed DEFLECT negates and consumes it.
func test_a_deflect_negates_and_consumes_the_shot() -> void:
	var ms := Fx.make()
	var shot := _healer_shot(ms)
	_shot_fact(ms, shot)
	F.act(ms, 1, F.press(&"block"))
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "the deflect negates the damage")
	assert_false(ms.p1.projectiles.is_alive_at(shot), "...and consumes the shot")


## AC 8: roll i-frames drop the fact and end its homing; the shot flies on.
func test_iframes_drop_the_shot_and_end_its_homing() -> void:
	var ms := Fx.make()
	var shot := _healer_shot(ms)
	F.act(ms, 1, F.press(&"roll"))
	_shot_fact(ms, shot)
	F.idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "no damage through the i-frames")
	assert_true(ms.p1.projectiles.is_alive_at(shot), "the shot flies on")
	assert_false(ms.p1.projectiles.is_homing_at(shot), "...no longer homing")


## AC 8: it passes through a body that is not its target.
func test_the_shot_passes_through_a_non_target() -> void:
	var ms := Fx.make()
	var shot := _healer_shot(ms)
	var unit := Fx.add_unit(ms, 1, CardEffectResolver.KIND_MINION)
	_shot_fact(ms, shot, unit)
	F.idle(ms, 1)
	assert_eq(ms.p2.units.hp_at(unit), F.MINION_HP, "the non-target body is untouched")
	assert_true(ms.p1.projectiles.is_alive_at(shot), "...and the shot is not consumed")


## AC 8: Stoneskin absorbs it, and Lifechain splits it.
func test_stoneskin_absorbs_and_lifechain_splits_the_shot() -> void:
	var ms := Fx.make()
	var shot := _healer_shot(ms)
	ms.p2.add_stoneskin_charge()
	_shot_fact(ms, shot)
	F.idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "Stoneskin absorbs the shot")
	assert_eq(ms.p2.stoneskin_charges, 0, "...spending its charge")
	var split := Fx.make()
	var shot2 := _healer_shot(split)
	var minion := Fx.add_unit(split, 1, CardEffectResolver.KIND_MINION)
	split.p2.open_lifechain(600)
	_shot_fact(split, shot2)
	F.idle(split, 1)
	assert_eq(split.p2.hero.get_hp(), F.MAX_HP - Fx.SHOT_DAMAGE / 2.0, "the hero takes half under Lifechain")
	assert_eq(split.p2.units.hp_at(minion), F.MINION_HP - Fx.SHOT_DAMAGE / 2.0, "...its minion the other half")


# ---------------------------------------------------------------- AC 5/AC 8: Counterspell

## AC 5/AC 8 (`7-5b/R4`): a Counterspell on the Healer card removes the Healer with NO corpse and removes its
## shot still in flight.
func test_a_counterspell_removes_the_healer_without_a_corpse_and_its_shot_in_flight() -> void:
	var ms := Fx.make()
	var shot := _healer_shot(ms)
	assert_true(F.counter(ms, 1), "the Healer card is a counter target")
	assert_false(ms.p1.units.is_alive_at(0), "the Healer is gone")
	assert_false(ms.p1.units.has_corpse_at(0), "...leaving NO corpse")
	assert_false(ms.p1.projectiles.is_alive_at(shot), "its shot in flight is removed")


## AC 8 (`7-5b/R4`): a Healer shot that already LANDED has its damage refunded by the counter.
func test_a_counterspell_refunds_a_landed_healer_shot() -> void:
	var ms := Fx.make()
	var shot := _healer_shot(ms)
	_shot_fact(ms, shot)
	F.idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP - Fx.SHOT_DAMAGE, "sanity: the shot landed")
	assert_true(F.counter(ms, 1), "the counter resolves")
	assert_eq(ms.p2.hero.get_hp(), F.MAX_HP, "the landed damage is refunded")


## AC 8, the last-resolved rule: once the owner resolves ANOTHER card, a later Healer shot belongs to no
## packet, and a counter targets that other card instead.
func test_a_shot_after_another_resolution_joins_no_healer_packet() -> void:
	var ms := Fx.make()
	Fx.summon_healer(ms, 0)
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.play(ms, 0, F.PLAIN, 3)
	F.press_unblockable(ms, 0)
	F.idle(ms, Fx.SHOT_DELAY_TICKS)
	assert_eq(ms.p1.projectiles.size(), 1, "the Healer still fires")
	assert_false(ms.p1.reversal_has_part(PlayerState.REVERSAL_HEALER, PlayerState.PART_PROJECTILE, 0),
		"...but the shot joins no Healer packet: the packet now describes the other card")
