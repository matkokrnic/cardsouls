extends TestCase

## Story 7-3 (the Hellhound), STATE-LEVEL: the summon batch (AC 4), minion membership as an authored
## fact (AC 5), three hits (AC 6), the hit and deflect reaction with its seat-symmetric trade (AC 7,
## AC 8), the two attacks chosen by two reach bands (AC 9), the unchanged defence ladder (AC 10), the
## seeded between-attack behaviour (AC 12) and the get-up lockout (AC 16) -- plus the shelved zombie
## proven unchanged beside each (AC 1).
##
## EVERY NUMBER HERE IS AN IN-TEST LITERAL (`BC/R3`): no authored `.tres` is read except by the one
## recombination test, whose whole subject is the authored effect files (AC 3). A retune of the
## shipped hound therefore needs no edit here.

const SEED := 7301
const MAX_HP := 100.0
const HERO_TO_UNIT := 3.0
const HOUND_HP := 9.0
const BITE_DAMAGE := 2.0
const LEAP_DAMAGE := 4.0
const ZOMBIE_DAMAGE := 5.0
const WINDUP := 2
const ACTIVE := 3
const RECOVERY := 4
const BITE_REACH := 2.0
const LEAP_REACH := 5.0
const REACTION_TICKS := 6
const GET_UP_TICKS := 7
const BACK_OFF_MIN := 3
const BACK_OFF_MAX := 9
const CIRCLE_MIN := 5
const CIRCLE_MAX := 20
const CORPSE_TICKS := 600
const START_MANA := 40.0
const CAST_MANA := 2.0
const CULLING_MANA_PER_KILL := 2.0
const DRAIN_HEAL := 12.0
const BOLT_DAMAGE := 2.0
const BOLT_CAST_TICKS := 4
const BLOCK_MULTIPLIER := 0.5

## Kind indices in `_config()`'s authored order.
const ZOMBIE_KIND := 0
const TOTEM_KIND := 1
const HOUND_KIND := 2

const ID_HOUND := &"hh_hound"
const ID_VANGUARD := &"hh_vanguard"
const ID_CULLING := &"hh_culling"
const ID_DRAIN := &"hh_drain"
const ID_RAISE := &"hh_raise"
const ID_BOMB := &"hh_bomb"
const ID_COUNTER := &"hh_counter"
const ID_BOLT := &"hh_bolt"
const ID_WARD := &"hh_ward"
## Grave Ward's extension in the test's own effect, in ticks.
const WARD_TICKS := 300
## The hound kind's `leap_chance` in the NEXT config `_config()` builds. A test that wants 0.0 or 1.0
## sets it, builds its match and puts it back at once.
var _leap_chance := 0.5
## Feel pass: fields set on the hound kind of the NEXT config `_config()` builds, by name. Used like
## `_leap_chance`: set, build the match, clear at once. Empty, the hound is the fixture's -- no option
## weights (always circle), no reversal, no temperament.
var _hound_overrides: Dictionary = {}

## The feel-pass durations, in ticks, the tests that author them use.
const STALK_MIN := 4
const STALK_MAX := 11
const FEINT_MIN := 2
const FEINT_MAX := 6
const FEINT_RETREAT := 5
const FLIP_REMAINING := 3

## Feel pass 2: the run-on's, the reposition's and the retreat's drawn bounds, in ticks, and the
## overshoot the NEXT config's leap authors (`_leap_chance`'s shape: set, build, put back). With no
## overshoot no swing "carried the unit past its target", so a run-on is never on offer.
const RUN_ON_MIN := 3
const RUN_ON_MAX := 8
const REPOSITION_MIN := 6
const REPOSITION_MAX := 14
const RETREAT_MIN := 4
const RETREAT_MAX := 10
var _leap_overshoot := 0.0
## Feel pass 3: the orbit's drawn bounds, in ticks -- wholly above the circle's (`CIRCLE_MAX`), so an
## orbit and a circle cannot be mistaken for each other by their length.
const ORBIT_MIN := 40
const ORBIT_MAX := 70

const DECK: Array[StringName] = [ID_HOUND, ID_VANGUARD, ID_CULLING, ID_DRAIN, ID_RAISE, ID_BOMB,
		ID_COUNTER, ID_BOLT, ID_WARD]


## ---- AC 4 (`7-3/R3`/`R16`): one cast, two hounds; the defaults keep Vanguard at one zombie ----

func test_one_hellhound_cast_puts_two_hounds_on_the_board_and_draws_no_rng() -> void:
	var ms := _make_match()
	var rng_before: int = ms.to_snapshot()["rng_state"]
	_cast(ms, 0, ID_HOUND)
	assert_eq(ms.p1.units.size(), 2, "one Hellhound cast puts exactly TWO records on the board")
	for index in ms.p1.units.size():
		assert_true(ms.p1.units.is_alive_at(index), "hound %d is alive on the cast tick" % index)
		assert_eq(ms.p1.units.kind_index_at(index), HOUND_KIND, "...and is the HOUND kind")
		assert_eq(ms.p1.units.hp_at(index), HOUND_HP, "...at the hound's own maximum hp")
		assert_eq(ms.p1.units.behavior_phase_at(index), UnitBoard.BehaviorPhase.ENGAGE,
			"...and ENGAGING: a fresh summon has no get-up lockout")
	assert_eq(ms.p1.reversal_indices, [0, 1] as Array[int],
		"the ONE reversal packet names BOTH summoned records")
	assert_eq(ms.to_snapshot()["rng_state"], rng_before,
		"a Hellhound cast draws NOTHING on the cast tick (`7-3/R20`)")


func test_a_vanguard_cast_still_puts_exactly_one_zombie_on_the_board() -> void:
	var ms := _make_match()
	_cast(ms, 0, ID_VANGUARD)
	assert_eq(ms.p1.units.size(), 1, "one Vanguard cast still puts exactly ONE record on the board")
	assert_eq(ms.p1.units.kind_index_at(0), ZOMBIE_KIND, "...of the zombie kind (the default)")
	assert_eq(ms.p1.reversal_indices, [0] as Array[int], "...and its packet names that one record")


## `SUMMON_KINDS` gained no row, so a hound cast is a MINION-layer cast: it closes with
## `FeatureFlags.minions` and is untouched by `FeatureFlags.totems`.
func test_a_hellhound_cast_gates_on_the_minion_flag_and_not_the_totem_flag() -> void:
	var no_minions := _flags()
	no_minions.minions = false
	var closed := _make_match(no_minions)
	var mana_before := closed.p1.mana.get_current()
	_cast(closed, 0, ID_HOUND)
	assert_eq(closed.p1.units.size(), 0, "with the MINION layer closed a hound cast summons nothing")
	assert_eq(closed.p1.mana.get_current(), mana_before - CAST_MANA,
		"...and is still a resolved cast (the layer degrades gracefully)")
	var no_totems := _flags()
	no_totems.totems = false
	var open := _make_match(no_totems)
	_cast(open, 0, ID_HOUND)
	assert_eq(open.p1.units.size(), 2, "with the TOTEM layer closed a hound cast is unaffected")


## A zero or negative authored count is a successful cast that puts nothing on the board and
## records nothing to reverse.
func test_a_non_positive_summon_count_summons_nothing_and_records_no_reversal() -> void:
	var ms := _make_match()
	var effects := _effects()
	(effects[ID_HOUND] as CardEffect).summon_count = 0
	ms.inject_card_effects(effects)
	_cast(ms, 0, ID_HOUND)
	assert_eq(ms.p1.units.size(), 0, "count 0 summons nothing")
	assert_eq(ms.p1.reversal_indices, [] as Array[int], "...and leaves no packet to counter")


## ---- AC 4 (`6-5f` extended to a batch): a Counterspell removes BOTH, alive or dead ----

func test_countering_a_hellhound_cast_removes_both_hounds_with_no_corpse() -> void:
	for dead_index: int in [-1, 0, 1]:
		var ms := _make_match()
		_cast(ms, 1, ID_HOUND)
		assert_eq(ms.p2.units.living_indices(), [0, 1] as Array[int], "sanity: two hounds summoned")
		if dead_index >= 0:
			ms.p2.units.kill_at(dead_index, CORPSE_TICKS)
			assert_true(ms.p2.units.has_corpse_at(dead_index), "sanity: one died and left a corpse")
		_counter(ms)
		assert_eq(ms.p2.units.living_indices(), [] as Array[int],
			"dead_index=%d: BOTH hounds are gone" % dead_index)
		assert_eq(ms.p2.units.corpse_indices(), [] as Array[int],
			"dead_index=%d: ...and NO corpse is left either way" % dead_index)


## The dead-with-expired-corpse arm, extended to a batch: one hound dead with its corpse gone is
## simply skipped while the other still vanishes; BOTH dead with no corpse leaves nothing to
## reverse, so the Counterspell is refused and stays staged.
func test_the_expired_corpse_arm_holds_for_a_batch() -> void:
	var mixed := _make_match()
	_cast(mixed, 1, ID_HOUND)
	mixed.p2.units.kill_at(0, CORPSE_TICKS)
	mixed.p2.units.consume_corpse_at(0)
	_counter(mixed)
	assert_false(mixed.pitch.is_staged(0), "one hound left is enough: the Counterspell resolved")
	assert_eq(mixed.p2.units.living_indices(), [] as Array[int], "...and the living hound is gone")
	var spent := _make_match()
	_cast(spent, 1, ID_HOUND)
	for index in 2:
		spent.p2.units.kill_at(index, CORPSE_TICKS)
		spent.p2.units.consume_corpse_at(index)
	_counter(spent)
	assert_true(spent.pitch.is_staged(0),
		"both hounds dead with no corpse: nothing is left to reverse, so the Counterspell is REFUSED")


## ---- AC 3 (`7-3/R2`): the halves recombine by DATA only ----
##
## THE FOUR COMBINATIONS, built from the AUTHORED effect files: {Vanguard, Hellhound} as the normal
## half x {Culling, another existing pitch effect} as the pitch half. No resolver row, no card id and
## no code path names any of the four pairings; each resolves both halves.
func test_all_four_normal_and_pitch_combinations_resolve_from_authored_effect_files() -> void:
	var normals := {
		&"summon_ruin_vanguard": [1, ZOMBIE_KIND],
		&"summon_hellhound": [2, HOUND_KIND],
	}
	for normal_id: StringName in normals:
		for pitch_id: StringName in [&"culling", &"vampiric_aura"]:
			var card := CardData.new()
			card.id = &"hh_combo"
			card.basic_effect = load("res://data/effects/%s.tres" % normal_id) as CardEffect
			card.pitch_effect = load("res://data/effects/%s.tres" % pitch_id) as CardEffect
			assert_not_null(card.basic_effect, "%s.tres loads" % normal_id)
			assert_not_null(card.pitch_effect, "%s.tres loads" % pitch_id)
			var label := "%s + %s" % [normal_id, pitch_id]
			var ms := _make_combo_match(card)
			_advance_slot(ms, 0, _cast_intent(0))
			assert_eq(ms.p1.units.size(), int(normals[normal_id][0]),
				"%s: the normal half summons its authored count" % label)
			for index in ms.p1.units.size():
				assert_eq(ms.p1.units.kind_index_at(index), int(normals[normal_id][1]),
					"%s: ...of its authored kind" % label)
			_advance_slot(ms, 0, _stage_intent(1))
			_advance_slot(ms, 0, _activate_intent())
			assert_false(ms.pitch.is_staged(0), "%s: the pitch half activated" % label)
			if pitch_id == &"culling":
				assert_eq(ms.p1.units.living_indices(), [] as Array[int],
					"%s: Culling killed what the normal half summoned" % label)
			else:
				assert_true(ms.p1.is_rule_active(PlayerState.RULE_VAMPIRIC_AURA),
					"%s: the other pitch effect applied" % label)


## ---- AC 5 (`7-3/D4`): a hound is a MINION for every rule that keys on "minion" ----

func test_a_hound_killed_in_combat_leaves_a_corpse_and_a_totem_does_not() -> void:
	var ms := _make_match()
	ms.p2.units.add(HOUND_HP, HOUND_KIND)
	ms.p2.units.add(HOUND_HP, TOTEM_KIND)
	for index in 2:
		for _hit in 3:
			_hero_hits_unit(ms, 0, index)
	assert_false(ms.p2.units.is_alive_at(0), "sanity: the hound died")
	assert_false(ms.p2.units.is_alive_at(1), "sanity: the totem died")
	assert_true(ms.p2.units.has_corpse_at(0), "a HOUND leaves a corpse when killed")
	assert_false(ms.p2.units.has_corpse_at(1), "a TOTEM still leaves none")


func test_culling_kills_hounds_pays_for_them_and_spares_a_totem() -> void:
	var ms := _make_match()
	_cast(ms, 0, ID_HOUND)
	ms.p1.units.add(HOUND_HP, TOTEM_KIND)
	var mana_before := ms.p1.mana.get_current()
	_cast(ms, 0, ID_CULLING)
	assert_eq(ms.p1.units.living_indices(), [2] as Array[int],
		"Culling killed BOTH hounds and spared the totem")
	assert_eq(ms.p1.units.corpse_indices(), [0, 1] as Array[int], "...each leaving a corpse")
	assert_eq(ms.p1.mana.get_current(), mana_before - CAST_MANA + 2.0 * CULLING_MANA_PER_KILL,
		"...and paid its mana for both")


## The pre-spend gate `NEEDS_OWN_LIVING_MINION` counts hounds. The totem-only control is what makes
## "not refused" a measurement: the same three casts ARE refused when no minion is out.
func test_with_only_hounds_out_culling_drain_and_corpse_bomb_are_not_refused() -> void:
	for id: StringName in [ID_CULLING, ID_DRAIN, ID_BOMB]:
		var totem_only := _make_match()
		totem_only.p1.units.add(HOUND_HP, TOTEM_KIND)
		var refused_before := totem_only.p1.mana.get_current()
		_cast(totem_only, 0, id)
		assert_eq(totem_only.p1.mana.get_current(), refused_before,
			"control, %s: with only a TOTEM out the cast is refused before the spend" % id)
		var hounds := _make_match()
		_cast(hounds, 0, ID_HOUND)
		var mana_before := hounds.p1.mana.get_current()
		_cast(hounds, 0, id)
		assert_true(hounds.p1.mana.get_current() != mana_before,
			"%s: with ONLY hounds out the cast is NOT refused" % id)
		assert_true(hounds.p1.units.living_indices().size() < 2, "%s: ...and it took a hound" % id)


func test_drain_sacrifices_a_hound_and_corpse_bomb_converts_both() -> void:
	var drained := _make_match()
	_cast(drained, 0, ID_HOUND)
	drained.p1.hero.take_damage(30.0)
	var hp_before := drained.p1.hero.get_hp()
	_cast(drained, 0, ID_DRAIN)
	assert_eq(drained.p1.units.living_indices().size(), 1, "Drain sacrificed exactly one hound")
	assert_eq(drained.p1.hero.get_hp(), hp_before + DRAIN_HEAL, "...and healed its caster")
	var bombed := _make_match()
	_cast(bombed, 0, ID_HOUND)
	_cast(bombed, 0, ID_BOMB)
	assert_eq(bombed.p1.units.living_indices(), [] as Array[int], "Corpse Bomb converted both hounds")
	assert_eq(bombed.p1.units.corpse_indices(), [0, 1] as Array[int], "...each leaving a corpse")
	assert_eq(bombed.p1.projectiles.size(), 2, "...and throwing one skull each")


func test_raise_dead_revives_a_hound_as_a_hound() -> void:
	var ms := _make_match()
	_cast(ms, 0, ID_HOUND)
	ms.p1.units.kill_at(0, CORPSE_TICKS)
	ms.p1.units.kill_at(1, CORPSE_TICKS)
	_cast(ms, 0, ID_RAISE)
	assert_eq(ms.p1.units.living_indices(), [2, 3] as Array[int], "both corpses were raised")
	for index: int in [2, 3]:
		assert_eq(ms.p1.units.kind_index_at(index), HOUND_KIND,
			"a raised hound is a HOUND (the kind is read off the dead record)")


func test_bloodlust_doubles_a_hounds_damage_dealt_and_taken() -> void:
	var taken := _make_match()
	taken.p2.units.add(HOUND_HP, HOUND_KIND)
	taken.p2.start_rule(PlayerState.RULE_BLOODLUST, 600, 2.0, 2.0)
	_hero_hits_unit(taken, 0, 0)
	assert_eq(taken.p2.units.hp_at(0), HOUND_HP - 2.0 * HERO_TO_UNIT,
		"a hound under its owner's Bloodlust TAKES double damage")
	var dealt := _make_match()
	dealt.p1.units.add(HOUND_HP, HOUND_KIND)
	dealt.p1.start_rule(PlayerState.RULE_BLOODLUST, 600, 2.0, 2.0)
	_unit_into_active(dealt, 0, 0)
	var hp_before := dealt.p2.hero.get_hp()
	_strike(dealt, 0, 0)
	_idle(dealt, 1)
	assert_eq(hp_before - dealt.p2.hero.get_hp(), 2.0 * BITE_DAMAGE,
		"a hound under its owner's Bloodlust DEALS double damage")


## Vampiric Aura is NOT changed (`7-3/D4`, gate M5): a hound's own hits never heal its owner; the
## caster's own hits on a hound heal as on any unit.
func test_vampiric_aura_ignores_a_hounds_bite_and_still_heals_off_a_hit_on_a_hound() -> void:
	var biting := _make_match()
	biting.p1.units.add(HOUND_HP, HOUND_KIND)
	biting.p1.hero.take_damage(40.0)
	biting.p1.start_rule(PlayerState.RULE_VAMPIRIC_AURA, 600, 0.5, 0.0)
	_unit_into_active(biting, 0, 0)
	var owner_hp := biting.p1.hero.get_hp()
	var target_hp := biting.p2.hero.get_hp()
	_strike(biting, 0, 0)
	_idle(biting, 1)
	assert_true(biting.p2.hero.get_hp() < target_hp, "sanity: the bite landed")
	assert_eq(biting.p1.hero.get_hp(), owner_hp, "a hound's own hit does NOT heal its owner")
	var hitting := _make_match()
	hitting.p2.units.add(HOUND_HP, HOUND_KIND)
	hitting.p1.hero.take_damage(40.0)
	hitting.p1.start_rule(PlayerState.RULE_VAMPIRIC_AURA, 600, 0.5, 0.0)
	var caster_hp := hitting.p1.hero.get_hp()
	_hero_hits_unit(hitting, 0, 0)
	assert_eq(hitting.p1.hero.get_hp(), caster_hp + 0.5 * HERO_TO_UNIT,
		"the caster's own hit on a hound heals as on any unit")


## ---- AC 6 (`7-3/R3`): exactly three unbuffed basic hero melee hits ----

func test_a_full_health_hound_dies_to_exactly_three_hero_hits() -> void:
	var ms := _make_match()
	ms.p2.units.add(HOUND_HP, HOUND_KIND)
	_hero_hits_unit(ms, 0, 0)
	_hero_hits_unit(ms, 0, 0)
	assert_true(ms.p2.units.is_alive_at(0), "two hits leave the hound ALIVE")
	assert_true(ms.p2.units.hp_at(0) > 0.0, "...with positive hp (%s)" % ms.p2.units.hp_at(0))
	_hero_hits_unit(ms, 0, 0)
	assert_false(ms.p2.units.is_alive_at(0), "the THIRD hit kills it")


## ---- AC 7 (`7-3/R4`/`D3`/`R18`): the hit reaction ----

## THE SAME-TICK TRADE, PINNED ON BOTH SEATS. A hero hits a hound on the very tick that hound's own
## strike resolves. Facts resolve attacker-slot ascending, so without the deferral the P2 hound
## (struck first by the P1 hero) would lose its bite while the mirrored P1 hound kept it.
func test_the_same_tick_trade_is_seat_symmetric() -> void:
	var p2_hound := _trade(1)
	var p1_hound := _trade(0)
	for run: Dictionary in [p2_hound, p1_hound]:
		assert_eq(run["bite_damage"], BITE_DAMAGE,
			"hound on slot %d: its bite LANDS although it was damaged that same tick" % run["slot"])
		assert_eq(run["hound_hp"], HOUND_HP - HERO_TO_UNIT,
			"hound on slot %d: ...and the hero's hit landed too (a trade)" % run["slot"])
		assert_eq(run["attack_phase"], UnitBoard.AttackPhase.IDLE,
			"hound on slot %d: the swing STOPPED on that tick (hitbox inactive)" % run["slot"])
		assert_eq(run["behavior"], UnitBoard.BehaviorPhase.REACT,
			"hound on slot %d: ...and it is REACTING" % run["slot"])
		assert_eq(run["behavior_ticks"], REACTION_TICKS,
			"hound on slot %d: ...for its authored duration" % run["slot"])
		assert_eq(run["open_records"], 0,
			"hound on slot %d: the swing's dedupe record was DISCARDED with the interrupt" % run["slot"])
		assert_eq(run["late_damage"], 0.0,
			"hound on slot %d: ...so a fact arriving a tick later registers nothing" % run["slot"])
	p2_hound.erase("slot")
	p1_hound.erase("slot")
	assert_eq(p2_hound, p1_hound, "mirrored inputs give the SAME outcome on both seats (`7-3/R18`)")


## One trade, with the hound on `hound_slot` and the hero that hits it on the other.
func _trade(hound_slot: int) -> Dictionary:
	var ms := _make_match()
	var hero_slot := 1 - hound_slot
	var hound_owner := _player(ms, hound_slot)
	var hero_owner := _player(ms, hero_slot)
	hound_owner.units.add(HOUND_HP, HOUND_KIND)
	hound_owner.units.set_target_at(0, hero_slot, -1)
	ms.push_contact([hound_slot, 0], [hero_slot, -1], 0, Vector2.DOWN,
			MatchState.CONTACT_REACH_PROBE)
	_idle(ms, 1)
	_advance_slot(ms, hero_slot, _press(&"attack"))
	_idle(ms, 2)
	assert_eq(hound_owner.units.attack_phase_at(0), UnitBoard.AttackPhase.ACTIVE,
		"fixture: the hound is in its ACTIVE window")
	var hero_hp := hero_owner.hero.get_hp()
	ms.push_contact([hero_slot, -1], [hound_slot, 0], hero_owner.hero.attack_index, Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_strike(ms, hound_slot, 0)
	_idle(ms, 1)
	var out := {
		"slot": hound_slot,
		"bite_damage": hero_hp - hero_owner.hero.get_hp(),
		"hound_hp": hound_owner.units.hp_at(0),
		"attack_phase": hound_owner.units.attack_phase_at(0),
		"behavior": hound_owner.units.behavior_phase_at(0),
		"behavior_ticks": hound_owner.units.behavior_ticks_at(0),
		"open_records": hound_owner.unit_dedupe.size(),
	}
	# A late fact against a DIFFERENT target address than the one the bite already registered, so an
	# undiscarded record would let it through: the hound's own swing against a unit on the hero's side.
	hero_owner.units.add(HOUND_HP, ZOMBIE_KIND)
	var hp_after := hero_owner.units.hp_at(0)
	ms.push_contact([hound_slot, 0], [hero_slot, 0], hound_owner.units.attack_count_at(0),
			Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_idle(ms, 1)
	out["late_damage"] = hp_after - hero_owner.units.hp_at(0)
	return out


## The zombie path, per kind: damaged mid-swing, a zombie's rhythm sits EXACTLY where an undamaged
## swing leaves it (`4-3b` no-stagger), and it never reacts.
func test_a_zombie_damaged_mid_swing_still_finishes_its_swing() -> void:
	var hit := _swing_state_after(ZOMBIE_KIND, true)
	var control := _swing_state_after(ZOMBIE_KIND, false)
	assert_true(hit["hp"] < control["hp"], "sanity: the hit run really was damaged")
	hit.erase("hp")
	control.erase("hp")
	assert_eq(hit, control,
		"a damaged zombie's phase, countdown, swing counter and behaviour are exactly an undamaged "
		+ "zombie's: nothing was interrupted")
	assert_eq(control["attack_phase"], UnitBoard.AttackPhase.ACTIVE,
		"...and that swing is still ACTIVE (non-vacuity: the comparison is mid-swing)")


## ...and the same script on a hound DIFFERS, which is what makes the zombie comparison mean
## something: the two kinds run through the identical helper.
func test_a_hound_damaged_mid_swing_stops_its_swing() -> void:
	var hit := _swing_state_after(HOUND_KIND, true)
	var control := _swing_state_after(HOUND_KIND, false)
	assert_eq(control["attack_phase"], UnitBoard.AttackPhase.ACTIVE, "sanity: the control still swings")
	assert_eq(hit["attack_phase"], UnitBoard.AttackPhase.IDLE, "the damaged hound's swing stopped")
	assert_eq(hit["behavior"], UnitBoard.BehaviorPhase.REACT, "...and it reacts")


## A unit of `kind` on P2 brought into ACTIVE, then hit by the P1 hero (or not); its state after.
func _swing_state_after(kind: int, damaged: bool) -> Dictionary:
	var ms := _make_match()
	ms.p2.units.add(HOUND_HP, kind)
	ms.p2.units.set_target_at(0, 0, -1)
	ms.push_contact([1, 0], [0, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
	_idle(ms, 1)
	_advance_slot(ms, 0, _press(&"attack"))
	_idle(ms, 2)
	if damaged:
		ms.push_contact([0, -1], [1, 0], ms.p1.hero.attack_index, Vector2.DOWN,
				MatchState.CONTACT_STRIKE)
	_idle(ms, 1)
	return {
		"hp": ms.p2.units.hp_at(0),
		"attack_phase": ms.p2.units.attack_phase_at(0),
		"attack_ticks": ms.p2.units.attack_ticks_at(0),
		"attack_count": ms.p2.units.attack_count_at(0),
		"behavior": ms.p2.units.behavior_phase_at(0),
		"dedupe": ms.p2.unit_dedupe.snapshot(),
	}


func test_a_hit_that_kills_a_hound_starts_no_reaction() -> void:
	var ms := _make_match()
	ms.p2.units.add(HOUND_HP, HOUND_KIND)
	ms.p2.units.apply_damage_at(0, HOUND_HP - 1.0, CORPSE_TICKS)
	_hero_hits_unit(ms, 0, 0)
	assert_false(ms.p2.units.is_alive_at(0), "sanity: the hit killed it")
	assert_eq(ms.p2.units.behavior_phase_at(0), UnitBoard.BehaviorPhase.ENGAGE,
		"a killing hit plays Death, not Hit: no reaction phase is entered")


## The SECOND damage seat (Honed Bolt's unit arm, step 6c) reacts too -- damage from any source.
func test_a_honed_bolt_on_a_hound_interrupts_its_swing() -> void:
	var ms := _make_match()
	ms.p2.units.add(HOUND_HP, HOUND_KIND)
	ms.p2.units.begin_windup_at(0, 500, 0, 1)
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = 0
	_cast(ms, 0, ID_BOLT)
	_idle(ms, BOLT_CAST_TICKS)
	assert_eq(ms.p2.units.hp_at(0), HOUND_HP - BOLT_DAMAGE, "sanity: the bolt landed on the hound")
	assert_eq(ms.p2.units.attack_phase_at(0), UnitBoard.AttackPhase.IDLE,
		"the bolt stopped the hound's swing")
	assert_eq(ms.p2.units.behavior_phase_at(0), UnitBoard.BehaviorPhase.REACT, "...and it reacts")


## `7-3/R11`: after the reaction the hound BACKS OFF, then CIRCLES, then re-engages -- each a tick
## timer inside its authored bounds. It never re-attacks straight out of the reaction.
func test_after_a_reaction_a_hound_backs_off_and_circles_before_it_re_engages() -> void:
	var ms := _make_match()
	ms.p2.units.add(HOUND_HP, HOUND_KIND)
	_hero_hits_unit(ms, 0, 0, false)
	var board := ms.p2.units
	assert_eq(board.behavior_phase_at(0), UnitBoard.BehaviorPhase.REACT, "sanity: it is reacting")
	assert_eq(board.behavior_ticks_at(0), REACTION_TICKS, "...for its authored duration")
	_run_until_phase_leaves(ms, board, 0, UnitBoard.BehaviorPhase.REACT)
	assert_eq(board.behavior_phase_at(0), UnitBoard.BehaviorPhase.BACK_OFF, "REACT -> BACK_OFF")
	assert_true(board.behavior_ticks_at(0) >= BACK_OFF_MIN and board.behavior_ticks_at(0) <= BACK_OFF_MAX,
		"...for a drawn duration inside [min, max]: %d" % board.behavior_ticks_at(0))
	_run_until_phase_leaves(ms, board, 0, UnitBoard.BehaviorPhase.BACK_OFF)
	assert_eq(board.behavior_phase_at(0), UnitBoard.BehaviorPhase.CIRCLE, "BACK_OFF -> CIRCLE")
	assert_true(board.behavior_ticks_at(0) >= CIRCLE_MIN and board.behavior_ticks_at(0) <= CIRCLE_MAX,
		"...for a drawn duration inside [min, max]: %d" % board.behavior_ticks_at(0))
	assert_true(board.circle_dir_at(0) == UnitBoard.CIRCLE_CLOCKWISE
			or board.circle_dir_at(0) == UnitBoard.CIRCLE_COUNTER_CLOCKWISE,
		"...in a drawn direction")
	_run_until_phase_leaves(ms, board, 0, UnitBoard.BehaviorPhase.CIRCLE)
	assert_true(board.behavior_phase_at(0) == UnitBoard.BehaviorPhase.ENGAGE_BITE
			or board.behavior_phase_at(0) == UnitBoard.BehaviorPhase.ENGAGE_LEAP,
		"CIRCLE -> engaging, with a drawn attack (phase %d)" % board.behavior_phase_at(0))
	assert_true(board.is_engaging_at(0), "...which IS engaging")
	assert_eq(board.behavior_ticks_at(0), 0, "...with no countdown left over")


## A hound in reach does NOT wind up while it reacts, backs off or circles; it does the moment it
## is engaging again.
func test_a_hound_cannot_begin_an_attack_until_it_is_engaging_again() -> void:
	var ms := _make_match()
	ms.p2.units.add(HOUND_HP, HOUND_KIND)
	ms.p2.units.set_target_at(0, 0, -1)
	_hero_hits_unit(ms, 0, 0)
	var board := ms.p2.units
	var guard := 0
	while not board.is_engaging_at(0) and guard < 200:
		ms.push_contact([1, 0], [0, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
		_idle(ms, 1)
		guard += 1
		if not board.is_engaging_at(0):
			assert_eq(board.attack_phase_at(0), UnitBoard.AttackPhase.IDLE,
				"in reach but not engaging (phase %d): no windup begins" % board.behavior_phase_at(0))
	assert_true(board.is_engaging_at(0), "fixture: the hound re-engaged")
	assert_eq(board.attack_phase_at(0), UnitBoard.AttackPhase.WINDUP,
		"...and winds up on the very tick it is engaging again")


## ---- AC 8 (`7-3/R12`/`R19`): a deflect reacts, a block does not ----

func test_deflecting_a_hound_attack_makes_it_react_and_blocking_does_not() -> void:
	var deflected := _defended_swing(HOUND_KIND, true)
	var blocked := _defended_swing(HOUND_KIND, false)
	assert_eq(deflected["deflects"], 1, "sanity: the deflect run really deflected")
	assert_eq(blocked["deflects"], 0, "sanity: the block run really only blocked")
	assert_eq(deflected["behavior"], UnitBoard.BehaviorPhase.REACT,
		"a DEFLECT of a hound attack starts the hit reaction")
	assert_eq(deflected["attack_phase"], UnitBoard.AttackPhase.IDLE, "...and stops the swing")
	assert_eq(blocked["behavior"], UnitBoard.BehaviorPhase.ENGAGE, "a BLOCK starts no reaction")
	assert_eq(blocked["attack_phase"], UnitBoard.AttackPhase.ACTIVE, "...and the swing carries on")


## The zombie counterpart, on the same helper: deflected or blocked, a zombie's state is identical
## (`4-3b/R7` stands for the zombie).
func test_deflecting_a_zombie_attack_still_starts_no_reaction() -> void:
	var deflected := _defended_swing(ZOMBIE_KIND, true)
	var blocked := _defended_swing(ZOMBIE_KIND, false)
	assert_eq(deflected["deflects"], 1, "sanity: the deflect run really deflected")
	assert_eq(deflected["behavior"], UnitBoard.BehaviorPhase.ENGAGE, "a deflected zombie does not react")
	assert_eq(deflected["attack_phase"], blocked["attack_phase"], "...and its swing is not interrupted")
	assert_eq(deflected["attack_ticks"], blocked["attack_ticks"], "...to the tick")


## A P1 unit of `kind` strikes a BLOCKING P2 hero; with `deflect` false P2 cannot afford the deflect.
func _defended_swing(kind: int, deflect: bool) -> Dictionary:
	var ms := _make_match()
	ms.p1.units.add(HOUND_HP, kind)
	_unit_into_active(ms, 0, 0)
	var deflects: Array = []
	ms.deflect_landed.connect(func(_a: int, _t: int, _c: int) -> void: deflects.append(1))
	if not deflect:
		ms.p2.stamina.spend(ms.p2.stamina.get_current(), 0)
	_strike(ms, 0, 0)
	_advance_slot(ms, 1, _press(&"block"))
	return {
		"deflects": deflects.size(),
		"behavior": ms.p1.units.behavior_phase_at(0),
		"attack_phase": ms.p1.units.attack_phase_at(0),
		"attack_ticks": ms.p1.units.attack_ticks_at(0),
	}


## ---- AC 9 (`7-3/R5`/`R20`/`R21`): two attacks, two reach bands ----

func test_the_second_band_alone_starts_the_leap_and_the_first_band_wins_when_both_are_confirmed() -> void:
	var leap := _make_match()
	leap.p1.units.add(HOUND_HP, HOUND_KIND)
	_unit_into_active(leap, 0, 0, [MatchState.CONTACT_REACH_PROBE_SECOND])
	assert_eq(leap.p1.units.attack_choice_at(0), 1, "mid range only: the hound LEAPS (entry 1)")
	var hp_before := leap.p2.hero.get_hp()
	_strike(leap, 0, 0)
	_idle(leap, 1)
	assert_eq(hp_before - leap.p2.hero.get_hp(), LEAP_DAMAGE, "...and the hit deals the LEAP's damage")
	var bite := _make_match()
	bite.p1.units.add(HOUND_HP, HOUND_KIND)
	_unit_into_active(bite, 0, 0,
			[MatchState.CONTACT_REACH_PROBE, MatchState.CONTACT_REACH_PROBE_SECOND])
	assert_eq(bite.p1.units.attack_choice_at(0), 0, "close range: the hound BITES (entry 0)")
	assert_false(bite.p1.units.is_in_second_reach_at(0),
		"...and the windup CONSUMED both bands, so the next attack needs a fresh probe")
	hp_before = bite.p2.hero.get_hp()
	_strike(bite, 0, 0)
	_idle(bite, 1)
	assert_eq(hp_before - bite.p2.hero.get_hp(), BITE_DAMAGE, "...and the hit deals the BITE's damage")


## A second probe is a PROBE: it deals nothing, and it starts nothing on a kind with one attack.
func test_a_second_probe_deals_no_damage_and_never_starts_a_zombie_swing() -> void:
	var ms := _make_match()
	ms.p1.units.add(HOUND_HP, ZOMBIE_KIND)
	ms.p1.units.set_target_at(0, 1, -1)
	var hp_before := ms.p2.hero.get_hp()
	for _t in 6:
		ms.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE_SECOND)
		_idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), hp_before, "a second probe deals no damage")
	assert_eq(ms.p1.units.attack_count_at(0), 0, "a one-attack kind never winds up on the second band")
	assert_eq(ms.p1.units.attack_phase_at(0), UnitBoard.AttackPhase.IDLE, "...and stays idle")


## The leap's travel is authored per ATTACK: the bite is rooted, the leap is not.
func test_the_bite_is_rooted_and_the_leap_travels_through_the_multiplier_seat() -> void:
	var ms := _make_match()
	for phase: int in [UnitBoard.AttackPhase.WINDUP, UnitBoard.AttackPhase.ACTIVE,
			UnitBoard.AttackPhase.RECOVERY]:
		assert_eq(ms.unit_attack_phase_multiplier(phase, HOUND_KIND, 0), 0.0,
			"the bite is rooted in phase %d" % phase)
	assert_true(ms.unit_attack_phase_multiplier(UnitBoard.AttackPhase.ACTIVE, HOUND_KIND, 1) > 0.0,
		"the leap travels during its active phase")


## ---- AC 10 (`7-3/R5`): the SAME defence ladder, for the bite and for the leap ----

func test_a_bite_and_a_leap_are_blocked_deflected_and_dodged_like_a_zombie_strike() -> void:
	for choice: int in [0, 1]:
		var probes: Array = [MatchState.CONTACT_REACH_PROBE] if choice == 0 \
				else [MatchState.CONTACT_REACH_PROBE_SECOND]
		var full_damage := BITE_DAMAGE if choice == 0 else LEAP_DAMAGE
		# BLOCK: mitigated by the block multiplier.
		var blocking := _make_match()
		blocking.p1.units.add(HOUND_HP, HOUND_KIND)
		_unit_into_active(blocking, 0, 0, probes)
		blocking.p2.stamina.spend(blocking.p2.stamina.get_current(), 0)
		var hp_before := blocking.p2.hero.get_hp()
		_strike(blocking, 0, 0)
		_advance_slot(blocking, 1, _press(&"block"))
		assert_eq(hp_before - blocking.p2.hero.get_hp(), full_damage * BLOCK_MULTIPLIER,
			"attack %d: a BLOCK mitigates it by the block multiplier" % choice)
		# DEFLECT: fully negated.
		var deflecting := _make_match()
		deflecting.p1.units.add(HOUND_HP, HOUND_KIND)
		_unit_into_active(deflecting, 0, 0, probes)
		hp_before = deflecting.p2.hero.get_hp()
		_strike(deflecting, 0, 0)
		_advance_slot(deflecting, 1, _press(&"block"))
		assert_eq(deflecting.p2.hero.get_hp(), hp_before,
			"attack %d: a DEFLECT inside the window negates it" % choice)
		# ROLL: the i-frames drop the fact.
		var rolling := _make_match()
		rolling.p1.units.add(HOUND_HP, HOUND_KIND)
		_unit_into_active(rolling, 0, 0, probes)
		hp_before = rolling.p2.hero.get_hp()
		_strike(rolling, 0, 0)
		_advance_slot(rolling, 1, _press(&"roll"))
		assert_true(rolling.p2.hero.is_iframe_open(), "fixture: the roll opened its i-frames")
		assert_eq(rolling.p2.hero.get_hp(), hp_before,
			"attack %d: a rolling hero's i-frames dodge it" % choice)
		assert_eq(rolling.p1.units.behavior_phase_at(0), UnitBoard.BehaviorPhase.ENGAGE,
			"attack %d: ...and a dodge starts no reaction" % choice)


## ---- AC 12 (`7-3/R6`/`R13`/`R20`): chaotic, aggressive, deterministic ----

## THE DRAW DISCIPLINE, PINNED AGAINST A REPLICA OF THE STREAM: one draw per back-off entry, FOUR per
## decision at its end (the option, the duration, the direction, the reversal) and one per re-engage,
## P1 before P2, board-index order, on the single match RNG. The replica is seeded from the hashed
## `rng_state`, drawn in the ruled order, and must predict every value AND end on the same state --
## so an extra draw, a missing one or a reordered one all fail.
func test_the_behaviour_draws_are_fixed_in_count_and_ordered_p1_then_p2_by_board_index() -> void:
	var ms := _make_match()
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	ms.p2.units.add(HOUND_HP, HOUND_KIND)
	var order: Array = [[ms.p1.units, 0], [ms.p1.units, 1], [ms.p2.units, 0]]
	for entry: Array in order:
		(entry[0] as UnitBoard).set_behavior_at(entry[1], UnitBoard.BehaviorPhase.REACT, 1)
	var replica := RandomNumberGenerator.new()
	replica.state = ms.to_snapshot()["rng_state"]
	_idle(ms, 1)
	for entry: Array in order:
		var board := entry[0] as UnitBoard
		assert_eq(board.behavior_phase_at(entry[1]), UnitBoard.BehaviorPhase.BACK_OFF,
			"fixture: every hound entered back-off on this tick")
		assert_eq(board.behavior_ticks_at(entry[1]), _drawn_ticks(replica, BACK_OFF_MIN, BACK_OFF_MAX),
			"back-off entry is ONE draw, taken in P1-then-P2 board-index order")
	assert_eq(ms.to_snapshot()["rng_state"], replica.state,
		"...and exactly three draws were made for three hounds")
	for entry: Array in order:
		(entry[0] as UnitBoard).set_behavior_at(entry[1], UnitBoard.BehaviorPhase.BACK_OFF, 1)
	_idle(ms, 1)
	for entry: Array in order:
		var board := entry[0] as UnitBoard
		assert_eq(board.behavior_phase_at(entry[1]), UnitBoard.BehaviorPhase.CIRCLE,
			"fixture: every hound entered its circle on this tick")
		replica.randf()   # 1: WHICH option. This fixture authors no weights, so it is always the circle.
		assert_eq(board.behavior_ticks_at(entry[1]), _drawn_ticks(replica, CIRCLE_MIN, CIRCLE_MAX),
			"the decision draws the option first, then its DURATION")
		var clockwise := replica.randf() < 0.5
		assert_eq(board.circle_dir_at(entry[1]),
			UnitBoard.CIRCLE_CLOCKWISE if clockwise else UnitBoard.CIRCLE_COUNTER_CLOCKWISE,
			"...then its DIRECTION, against the authored clockwise chance")
		replica.randf()   # 4: the reversal. No flip chance is authored here; the draw is still made.
	assert_eq(ms.to_snapshot()["rng_state"], replica.state,
		"...and exactly twelve draws were made for three hounds: four per decision, used or not")
	# The re-engage: ONE draw each, the attack the hound comes back in with.
	for entry: Array in order:
		(entry[0] as UnitBoard).set_behavior_at(entry[1], UnitBoard.BehaviorPhase.CIRCLE, 1)
	_idle(ms, 1)
	for entry: Array in order:
		var leaps := replica.randf() < 0.5
		assert_eq((entry[0] as UnitBoard).behavior_phase_at(entry[1]),
			UnitBoard.BehaviorPhase.ENGAGE_LEAP if leaps else UnitBoard.BehaviorPhase.ENGAGE_BITE,
			"leaving the circle is ONE draw against the authored leap chance, in the same order")
	assert_eq(ms.to_snapshot()["rng_state"], replica.state,
		"...and exactly three draws were made for three hounds")


## ---- The re-engage draw (pre-smoke fix): bites AND leaps ----

## Put the hound at `index` through one circle exit and answer the engaging phase it drew.
func _re_engage(ms: MatchState, board: UnitBoard, index: int) -> int:
	board.set_behavior_at(index, UnitBoard.BehaviorPhase.CIRCLE, 1)
	_idle(ms, 1)
	return board.behavior_phase_at(index)


## The engaging phases `count` successive re-engages draw, for one hound with no target in reach.
func _re_engage_sequence(seed_value: int, count: int) -> Array[int]:
	var ms := _make_match(null, seed_value)
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	var drawn: Array[int] = []
	for i in count:
		drawn.append(_re_engage(ms, ms.p1.units, 0))
	return drawn


## At the default chance both attacks come up over forty re-engages, every one of them is a DRAWN
## intent (never the plain no-intent phase), the same seed gives the same sequence and another seed
## a different one.
func test_a_hound_leaving_its_circle_draws_its_next_attack_and_both_come_up() -> void:
	var drawn := _re_engage_sequence(SEED, 40)
	var leaps := drawn.count(UnitBoard.BehaviorPhase.ENGAGE_LEAP)
	var bites := drawn.count(UnitBoard.BehaviorPhase.ENGAGE_BITE)
	assert_eq(leaps + bites, 40, "every re-engage carries a drawn attack: %s" % [drawn])
	assert_true(leaps > 0 and bites > 0, "both attacks come up over forty re-engages (%d leaps, %d bites)"
			% [leaps, bites])
	assert_eq(_re_engage_sequence(SEED, 40), drawn, "the same seed draws the same sequence")
	assert_true(_re_engage_sequence(SEED + 1, 40) != drawn, "another seed draws another sequence")


## Chance 0.0: never a leap after a circle. A hound that drew the bite IGNORES the leap band -- with
## only the second band confirmed it begins nothing -- and bites once the close band is confirmed.
## And the draw is still made: exactly one per re-engage, whatever the chance.
func test_a_leap_chance_of_zero_never_leaps_after_a_circle_and_still_draws_once() -> void:
	_leap_chance = 0.0
	var ms := _make_match()
	_leap_chance = 0.5
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	var board := ms.p1.units
	board.set_target_at(0, 1, -1)
	var replica := RandomNumberGenerator.new()
	replica.state = ms.to_snapshot()["rng_state"]
	for i in 40:
		assert_eq(_re_engage(ms, board, 0), UnitBoard.BehaviorPhase.ENGAGE_BITE,
			"leap_chance 0.0: re-engage %d drew the bite" % i)
		replica.randf()
	assert_eq(ms.to_snapshot()["rng_state"], replica.state, "forty re-engages made exactly forty draws")
	for tick in 12:
		ms.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE_SECOND)
		_idle(ms, 1)
		assert_eq(board.attack_phase_at(0), UnitBoard.AttackPhase.IDLE,
			"a hound that drew the bite does not leap from the leap band (tick %d)" % tick)
	assert_eq(board.attack_count_at(0), 0, "...it has begun no swing at all")
	ms.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
	_idle(ms, 2)
	assert_eq(board.attack_phase_at(0), UnitBoard.AttackPhase.WINDUP, "the close band starts its attack")
	assert_eq(board.attack_choice_at(0), 0, "...and it is the BITE")


## Chance 1.0: always the leap after a circle, begun from the leap band -- and still the bite when
## the close band is confirmed first.
func test_a_leap_chance_of_one_always_leaps_unless_the_close_band_comes_first() -> void:
	_leap_chance = 1.0
	var ms := _make_match()
	var close_first := _make_match()
	_leap_chance = 0.5
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	var board := ms.p1.units
	board.set_target_at(0, 1, -1)
	for i in 40:
		assert_eq(_re_engage(ms, board, 0), UnitBoard.BehaviorPhase.ENGAGE_LEAP,
			"leap_chance 1.0: re-engage %d drew the leap" % i)
	ms.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE_SECOND)
	_idle(ms, 2)
	assert_eq(board.attack_phase_at(0), UnitBoard.AttackPhase.WINDUP, "the leap band starts its attack")
	assert_eq(board.attack_choice_at(0), 1, "...and it is the LEAP")
	close_first.p1.units.add(HOUND_HP, HOUND_KIND)
	close_first.p1.units.set_target_at(0, 1, -1)
	assert_eq(_re_engage(close_first, close_first.p1.units, 0), UnitBoard.BehaviorPhase.ENGAGE_LEAP,
		"fixture: it drew the leap")
	close_first.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
	close_first.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE_SECOND)
	_idle(close_first, 2)
	assert_eq(close_first.p1.units.attack_choice_at(0), 0,
		"a hound that drew the leap still BITES when the close band is confirmed")
	assert_eq(close_first.p1.units.attack_phase_at(0), UnitBoard.AttackPhase.WINDUP, "...and it has begun")


## The FIRST engagement draws nothing and keeps the band rule: a fresh summon leaps from the leap
## band at leap_chance 0.0, and a hound that has just got up is engaging with no intent and no draw.
func test_the_first_engagement_after_a_summon_or_a_get_up_draws_nothing() -> void:
	_leap_chance = 0.0
	var ms := _make_match()
	_leap_chance = 0.5
	_cast(ms, 0, ID_HOUND)
	var board := ms.p1.units
	var rng_before: int = ms.to_snapshot()["rng_state"]
	assert_eq(board.behavior_phase_at(0), UnitBoard.BehaviorPhase.ENGAGE, "a fresh hound has drawn no attack")
	board.set_target_at(0, 1, -1)
	ms.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE_SECOND)
	_idle(ms, 2)
	assert_eq(board.attack_choice_at(0), 1,
		"...and leaps from the leap band even at leap_chance 0.0: the band rule, not a draw")
	assert_eq(board.attack_phase_at(0), UnitBoard.AttackPhase.WINDUP, "...it has begun")
	assert_eq(ms.to_snapshot()["rng_state"], rng_before, "...and nothing was drawn")
	board.kill_at(1, CORPSE_TICKS)
	_cast(ms, 0, ID_RAISE)
	var raised := board.size() - 1
	assert_eq(board.behavior_phase_at(raised), UnitBoard.BehaviorPhase.GET_UP, "fixture: a hound is getting up")
	rng_before = ms.to_snapshot()["rng_state"]
	_run_until_phase_leaves(ms, board, raised, UnitBoard.BehaviorPhase.GET_UP)
	assert_eq(board.behavior_phase_at(raised), UnitBoard.BehaviorPhase.ENGAGE,
		"a hound that has got up is engaging with no drawn attack")
	assert_eq(ms.to_snapshot()["rng_state"], rng_before, "...and getting up drew nothing")


## ONLY HOUND RECORDS DRAW. The identical attack script run with zombies leaves `rng_state` where
## it started; run with hounds it moves. This is the two-direction proof the golden rests on.
func test_only_hounds_draw_from_the_match_rng() -> void:
	var zombies := _make_match()
	var zombie_rng: int = zombies.to_snapshot()["rng_state"]
	_run_attack_script(zombies, ZOMBIE_KIND, 120)
	assert_true(zombies.p1.units.attack_count_at(0) > 1, "sanity: the zombies really swung")
	assert_eq(zombies.to_snapshot()["rng_state"], zombie_rng,
		"zombies swinging for 120 ticks draw NOTHING from the match RNG")
	var hounds := _make_match()
	var hound_rng: int = hounds.to_snapshot()["rng_state"]
	_run_attack_script(hounds, HOUND_KIND, 120)
	assert_true(hounds.p1.units.attack_count_at(0) > 0, "sanity: the hounds really swung")
	assert_true(hounds.to_snapshot()["rng_state"] != hound_rng,
		"hounds draw at every back-off and circle entry, so `rng_state` MOVES")


## Same seed, same intents: the same decisions and the same hash. Two seeds: different play.
func test_the_same_seed_reproduces_the_hounds_decisions_and_two_seeds_differ() -> void:
	var first := _make_match(null, SEED)
	var first_trace := _run_attack_script(first, HOUND_KIND, 400)
	var again := _make_match(null, SEED)
	var again_trace := _run_attack_script(again, HOUND_KIND, 400)
	assert_eq(first_trace, again_trace, "the same seed reproduces every behaviour decision, tick by tick")
	assert_eq(CanonicalHash.of(first.to_snapshot()), CanonicalHash.of(again.to_snapshot()),
		"...and the same final state hash")
	var other := _make_match(null, SEED + 1)
	var other_trace := _run_attack_script(other, HOUND_KIND, 400)
	assert_true(first_trace != other_trace, "a different seed gives visibly different hound play")


## `7-3/R13`: no coordination. Two hounds of one cast, given identical inputs on every tick, do not
## move in lockstep -- each draws its own durations and direction.
func test_the_two_hounds_of_one_cast_do_not_decide_in_lockstep() -> void:
	var ms := _make_match()
	_cast(ms, 0, ID_HOUND)
	var lockstep := true
	for tick in 400:
		if tick % 10 == 0:
			for index in 2:
				ms.p1.units.set_target_at(index, 1, -1)
				ms.push_contact([0, index], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
		_idle(ms, 1)
		if ms.p1.units.behavior_phase_at(0) != ms.p1.units.behavior_phase_at(1) \
				or ms.p1.units.behavior_ticks_at(0) != ms.p1.units.behavior_ticks_at(1):
			lockstep = false
	assert_true(ms.p1.units.attack_count_at(0) > 2 and ms.p1.units.attack_count_at(1) > 2,
		"sanity: both hounds attacked repeatedly")
	assert_false(lockstep, "two hounds fed identical inputs do NOT stay in lockstep")


## ---- Feel pass: what a hound does when its back-off ends (circle, stalk, feint, re-engage) ----

## A match whose hound kind authors the feel-pass durations plus `overrides` (weights, chances,
## spreads). Durations alone change nothing: with no weight the hound always circles.
func _feel_match(overrides: Dictionary, seed_value: int = SEED) -> MatchState:
	_hound_overrides = {
		&"stalk_min_seconds": float(STALK_MIN) / TimingWindow.TICK_HZ,
		&"stalk_max_seconds": float(STALK_MAX) / TimingWindow.TICK_HZ,
		&"feint_min_seconds": float(FEINT_MIN) / TimingWindow.TICK_HZ,
		&"feint_max_seconds": float(FEINT_MAX) / TimingWindow.TICK_HZ,
		&"feint_retreat_seconds": float(FEINT_RETREAT) / TimingWindow.TICK_HZ,
		&"circle_flip_remaining_seconds": float(FLIP_REMAINING) / TimingWindow.TICK_HZ,
		&"run_on_min_seconds": float(RUN_ON_MIN) / TimingWindow.TICK_HZ,
		&"run_on_max_seconds": float(RUN_ON_MAX) / TimingWindow.TICK_HZ,
		&"reposition_min_seconds": float(REPOSITION_MIN) / TimingWindow.TICK_HZ,
		&"reposition_max_seconds": float(REPOSITION_MAX) / TimingWindow.TICK_HZ,
		&"retreat_min_seconds": float(RETREAT_MIN) / TimingWindow.TICK_HZ,
		&"retreat_max_seconds": float(RETREAT_MAX) / TimingWindow.TICK_HZ,
		&"orbit_min_seconds": float(ORBIT_MIN) / TimingWindow.TICK_HZ,
		&"orbit_max_seconds": float(ORBIT_MAX) / TimingWindow.TICK_HZ,
	}
	_hound_overrides.merge(overrides, true)
	var ms := _make_match(null, seed_value)
	_hound_overrides = {}
	return ms


## End the back-off of the hound at `index` on this tick and answer the phase it decided on.
func _decide(ms: MatchState, board: UnitBoard, index: int) -> int:
	board.set_behavior_at(index, UnitBoard.BehaviorPhase.BACK_OFF, 1)
	_idle(ms, 1)
	return board.behavior_phase_at(index)


## Run the hound at `index` until it leaves `phase`, re-confirming it in close reach every tick, and
## answer how many ticks that took. No swing may begin on the way.
func _hold_phase_in_reach(ms: MatchState, board: UnitBoard, index: int, phase: int, what: String) -> int:
	var ticks := 0
	while board.behavior_phase_at(index) == phase and ticks < 200:
		ms.push_contact([0, index], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
		_idle(ms, 1)
		ticks += 1
		if board.behavior_phase_at(index) == phase:
			assert_eq(board.attack_phase_at(index), UnitBoard.AttackPhase.IDLE,
				"%s: in reach but not engaging, no windup begins" % what)
	assert_true(ticks < 200, "fixture: %s ended" % what)
	return ticks


## The decision's DURATION draw, replicated: ONE `randf()` mapped onto the inclusive tick range, so it
## moves the stream by exactly one draw whatever the bounds are (equal bounds included).
func _drawn_ticks(replica: RandomNumberGenerator, low: int, high: int) -> int:
	return low + mini(int(replica.randf() * float(high - low + 1)), high - low)


func _is_drawn_engage(phase: int) -> bool:
	return phase == UnitBoard.BehaviorPhase.ENGAGE_BITE or phase == UnitBoard.BehaviorPhase.ENGAGE_LEAP


## STALK: the hound stands for a drawn time inside its authored bounds, begins no attack however
## close its target is, and leaves through the re-engage draw.
func test_a_stalk_holds_for_its_drawn_time_attacks_nothing_and_ends_in_the_re_engage_draw() -> void:
	var ms := _feel_match({&"stalk_weight": 1.0})
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	var board := ms.p1.units
	board.set_target_at(0, 1, -1)
	assert_eq(_decide(ms, board, 0), UnitBoard.BehaviorPhase.STALK, "BACK_OFF -> STALK when only the stalk has a weight")
	var drawn := board.behavior_ticks_at(0)
	assert_true(drawn >= STALK_MIN and drawn <= STALK_MAX,
		"...for a drawn duration inside [min, max]: %d" % drawn)
	assert_false(board.is_engaging_at(0), "a stalking hound is not engaging")
	var replica := RandomNumberGenerator.new()
	replica.state = ms.to_snapshot()["rng_state"]
	assert_eq(_hold_phase_in_reach(ms, board, 0, UnitBoard.BehaviorPhase.STALK, "the stalk"), drawn,
		"the stalk lasts exactly the ticks it drew")
	var leaps := replica.randf() < 0.5
	assert_eq(board.behavior_phase_at(0),
		UnitBoard.BehaviorPhase.ENGAGE_LEAP if leaps else UnitBoard.BehaviorPhase.ENGAGE_BITE,
		"STALK -> the re-engage draw, one draw against the leap chance")
	assert_eq(ms.to_snapshot()["rng_state"], replica.state, "...and nothing else was drawn while it stalked")


## FEINT: the dart in lasts a drawn time, the retreat its authored time with NO draw, no attack
## begins in either, and the retreat ends in the re-engage draw.
func test_a_feint_darts_in_for_a_drawn_time_retreats_for_its_authored_time_and_never_attacks() -> void:
	var ms := _feel_match({&"feint_weight": 1.0})
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	var board := ms.p1.units
	board.set_target_at(0, 1, -1)
	assert_eq(_decide(ms, board, 0), UnitBoard.BehaviorPhase.FEINT_IN, "BACK_OFF -> FEINT_IN when only the feint has a weight")
	var drawn := board.behavior_ticks_at(0)
	assert_true(drawn >= FEINT_MIN and drawn <= FEINT_MAX,
		"...for a drawn dart inside [min, max]: %d" % drawn)
	var replica := RandomNumberGenerator.new()
	replica.state = ms.to_snapshot()["rng_state"]
	assert_eq(_hold_phase_in_reach(ms, board, 0, UnitBoard.BehaviorPhase.FEINT_IN, "the dart"), drawn,
		"the dart lasts exactly the ticks it drew")
	assert_eq(board.behavior_phase_at(0), UnitBoard.BehaviorPhase.FEINT_OUT, "FEINT_IN -> FEINT_OUT")
	assert_eq(board.behavior_ticks_at(0), FEINT_RETREAT, "...for the AUTHORED retreat")
	assert_eq(ms.to_snapshot()["rng_state"], replica.state, "...which is not drawn: the stream did not move")
	assert_false(board.is_engaging_at(0), "a retreating hound is not engaging")
	assert_eq(board.attack_count_at(0), 0, "the dart began no swing")
	assert_eq(_hold_phase_in_reach(ms, board, 0, UnitBoard.BehaviorPhase.FEINT_OUT, "the retreat"), FEINT_RETREAT,
		"the retreat lasts exactly its authored ticks")
	# The helper held it in reach: the first swing begins on the tick the feint is OVER, not before.
	assert_eq(board.attack_count_at(0), 1, "the first swing begins only once the feint has ended")
	var leaps := replica.randf() < 0.5
	assert_eq(board.behavior_phase_at(0),
		UnitBoard.BehaviorPhase.ENGAGE_LEAP if leaps else UnitBoard.BehaviorPhase.ENGAGE_BITE,
		"FEINT_OUT -> the re-engage draw")
	assert_eq(ms.to_snapshot()["rng_state"], replica.state, "...one draw, and no other")


## IMMEDIATE RE-ENGAGE: on the very tick the back-off ends the hound is engaging with a drawn attack,
## and may wind up at once.
func test_an_immediate_re_engage_is_engaging_with_a_drawn_attack_on_the_same_tick() -> void:
	var ms := _feel_match({&"re_engage_weight": 1.0})
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	var board := ms.p1.units
	board.set_target_at(0, 1, -1)
	ms.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
	_idle(ms, 1)
	board.set_behavior_at(0, UnitBoard.BehaviorPhase.BACK_OFF, 1)
	var replica := RandomNumberGenerator.new()
	replica.state = ms.to_snapshot()["rng_state"]
	ms.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
	_idle(ms, 1)
	# The decision's four, each ONE raw draw: the option, the duration (drawn even though a re-engage
	# has none -- `randi_range(0, 0)` would draw nothing and leave the stream one short), the direction
	# and the reversal. Then the re-engage's own.
	for i in 4:
		replica.randf()
	var leaps := replica.randf() < 0.5
	assert_eq(board.behavior_phase_at(0),
		UnitBoard.BehaviorPhase.ENGAGE_LEAP if leaps else UnitBoard.BehaviorPhase.ENGAGE_BITE,
		"BACK_OFF -> engaging at once, the attack drawn after the decision's four draws")
	assert_eq(ms.to_snapshot()["rng_state"], replica.state, "...five draws in all: the decision's four, then the re-engage")
	assert_eq(board.attack_phase_at(0), UnitBoard.AttackPhase.WINDUP,
		"...and, in close reach, it winds up on that same tick")


## A REVERSING CIRCLE: drawn at circle entry, it runs as CIRCLE_TURN until its authored remainder is
## left, then carries on as CIRCLE the other way round. The reversal draws nothing, resets nothing,
## and the circle is exactly as long as it drew.
func test_a_reversing_circle_turns_once_when_its_authored_remainder_is_left() -> void:
	var ms := _feel_match({&"circle_flip_chance": 1.0})
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	var board := ms.p1.units
	assert_eq(_decide(ms, board, 0), UnitBoard.BehaviorPhase.CIRCLE_TURN,
		"flip chance 1.0: the circle is entered as one that will reverse")
	var drawn := board.behavior_ticks_at(0)
	var first_dir := board.circle_dir_at(0)
	assert_true(drawn >= CIRCLE_MIN and drawn <= CIRCLE_MAX, "...for a drawn duration inside [min, max]: %d" % drawn)
	assert_true(first_dir == UnitBoard.CIRCLE_CLOCKWISE or first_dir == UnitBoard.CIRCLE_COUNTER_CLOCKWISE,
		"...in a drawn direction")
	assert_false(board.is_engaging_at(0), "a circling hound is not engaging")
	var rng_at_entry: int = ms.to_snapshot()["rng_state"]
	var before_turn := _hold_phase_in_reach(ms, board, 0, UnitBoard.BehaviorPhase.CIRCLE_TURN, "the first leg")
	assert_eq(board.behavior_phase_at(0), UnitBoard.BehaviorPhase.CIRCLE, "CIRCLE_TURN -> CIRCLE")
	assert_eq(board.circle_dir_at(0), -first_dir, "...going the OTHER way round")
	assert_eq(board.behavior_ticks_at(0), FLIP_REMAINING, "...with exactly the authored remainder left")
	assert_eq(before_turn, drawn - FLIP_REMAINING, "...so the reversal came that long before the end")
	assert_eq(ms.to_snapshot()["rng_state"], rng_at_entry, "the reversal draws nothing")
	assert_eq(_hold_phase_in_reach(ms, board, 0, UnitBoard.BehaviorPhase.CIRCLE, "the second leg"), FLIP_REMAINING,
		"the circle ends when its own countdown does: it is as long as it drew")
	assert_true(_is_drawn_engage(board.behavior_phase_at(0)), "...and ends in the re-engage draw")
	# Flip chance 0.0 (the fixture's): never a reversing circle, and the flip draw is still made.
	var plain := _feel_match({})
	plain.p1.units.add(HOUND_HP, HOUND_KIND)
	for i in 30:
		assert_eq(_decide(plain, plain.p1.units, 0), UnitBoard.BehaviorPhase.CIRCLE,
			"flip chance 0.0: decision %d is a plain circle" % i)


## THE DECISION IS FOUR DRAWS WHATEVER IS DECIDED: the option, the duration inside the chosen option's
## bounds, the direction, the reversal. Pinned for each option against a replica of the stream.
func test_the_decision_after_a_back_off_is_four_draws_for_every_option() -> void:
	var cases: Array = [
		[{&"circle_weight": 1.0}, UnitBoard.BehaviorPhase.CIRCLE, CIRCLE_MIN, CIRCLE_MAX],
		[{&"stalk_weight": 1.0}, UnitBoard.BehaviorPhase.STALK, STALK_MIN, STALK_MAX],
		[{&"feint_weight": 1.0}, UnitBoard.BehaviorPhase.FEINT_IN, FEINT_MIN, FEINT_MAX],
		[{&"reposition_weight": 1.0}, UnitBoard.BehaviorPhase.REPOSITION, REPOSITION_MIN, REPOSITION_MAX],
		[{&"retreat_weight": 1.0}, UnitBoard.BehaviorPhase.RETREAT, RETREAT_MIN, RETREAT_MAX],
		[{&"orbit_weight": 1.0}, UnitBoard.BehaviorPhase.ORBIT, ORBIT_MIN, ORBIT_MAX],
	]
	for case: Array in cases:
		var ms := _feel_match(case[0])
		ms.p1.units.add(HOUND_HP, HOUND_KIND)
		var board := ms.p1.units
		for i in 12:
			var replica := RandomNumberGenerator.new()
			replica.state = ms.to_snapshot()["rng_state"]
			var phase := _decide(ms, board, 0)
			replica.randf()
			var ticks := _drawn_ticks(replica, case[2], case[3])
			var clockwise := replica.randf() < 0.5
			replica.randf()
			assert_eq(phase, case[1], "weights %s: decision %d chose phase %d" % [case[0], i, phase])
			assert_eq(board.behavior_ticks_at(0), ticks, "...its duration is the SECOND draw, inside its own bounds")
			if phase == UnitBoard.BehaviorPhase.CIRCLE or phase == UnitBoard.BehaviorPhase.REPOSITION \
					or phase == UnitBoard.BehaviorPhase.ORBIT:
				assert_eq(board.circle_dir_at(0),
					UnitBoard.CIRCLE_CLOCKWISE if clockwise else UnitBoard.CIRCLE_COUNTER_CLOCKWISE,
					"...its direction is the THIRD")
			assert_eq(ms.to_snapshot()["rng_state"], replica.state,
				"...and exactly four draws were made (weights %s, decision %d)" % [case[0], i])
	# THE STREAM STANDS IN THE SAME PLACE WHICHEVER OPTION WAS DECIDED -- a FIXED duration included
	# (equal bounds, where a ranged integer draw would have drawn nothing).
	var after: Array[int] = []
	var fixed := float(STALK_MIN) / TimingWindow.TICK_HZ
	for overrides: Dictionary in [{&"circle_weight": 1.0}, {&"stalk_weight": 1.0}, {&"feint_weight": 1.0},
			{&"reposition_weight": 1.0}, {&"retreat_weight": 1.0}, {&"orbit_weight": 1.0},
			{&"stalk_weight": 1.0, &"stalk_min_seconds": fixed, &"stalk_max_seconds": fixed}]:
		var ms := _feel_match(overrides)
		ms.p1.units.add(HOUND_HP, HOUND_KIND)
		_decide(ms, ms.p1.units, 0)
		after.append(ms.to_snapshot()["rng_state"])
	for index in after.size():
		assert_eq(after[index], after[0],
			"after one decision the stream is where it is for a circle, whatever was decided (case %d)" % index)


## VARIETY: with all four options weighted, all four come up; the same seed repeats the sequence and
## another seed does not.
func test_with_every_option_weighted_all_four_come_up_and_the_seed_decides_the_sequence() -> void:
	var weights := {&"circle_weight": 1.0, &"stalk_weight": 1.0, &"feint_weight": 1.0, &"re_engage_weight": 1.0}
	var drawn := _decision_sequence(weights, SEED, 0, 200)
	var circles := drawn.count(UnitBoard.BehaviorPhase.CIRCLE)
	var stalks := drawn.count(UnitBoard.BehaviorPhase.STALK)
	var feints := drawn.count(UnitBoard.BehaviorPhase.FEINT_IN)
	var direct := drawn.count(UnitBoard.BehaviorPhase.ENGAGE_BITE) + drawn.count(UnitBoard.BehaviorPhase.ENGAGE_LEAP)
	assert_eq(circles + stalks + feints + direct, 200, "every decision is one of the four options")
	assert_true(circles > 20 and stalks > 20 and feints > 20 and direct > 20,
		"all four come up over 200 decisions at equal weights (%d circles, %d stalks, %d feints, %d direct)"
				% [circles, stalks, feints, direct])
	assert_eq(_decision_sequence(weights, SEED, 0, 200), drawn, "the same seed decides the same sequence")
	assert_true(_decision_sequence(weights, SEED + 1, 0, 200) != drawn, "another seed decides another")
	# A weight of zero is never drawn.
	var no_feint := _decision_sequence({&"circle_weight": 1.0, &"stalk_weight": 1.0, &"re_engage_weight": 1.0},
			SEED, 0, 200)
	assert_eq(no_feint.count(UnitBoard.BehaviorPhase.FEINT_IN), 0, "an option with no weight is never chosen")


## The phases `count` successive decisions give the hound at board `index` (of two on P1's board).
## Only that hound decides, so two calls with one seed see the SAME rolls.
func _decision_sequence(overrides: Dictionary, seed_value: int, index: int, count: int) -> Array[int]:
	var ms := _feel_match(overrides, seed_value)
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	var drawn: Array[int] = []
	for i in count:
		drawn.append(_decide(ms, ms.p1.units, index))
	return drawn


## ---- Feel pass: temperament ----

## `UnitTemperament` is a pure function of the unit's address: in range, repeatable, different for
## the two slots, and -- the point of its golden-ratio step -- never close for two hounds one board
## index apart, on any channel.
func test_temperament_is_a_pure_function_of_the_address_and_siblings_are_never_alike() -> void:
	assert_eq(UnitTemperament.CHANNEL_COUNT, UnitTemperament.CHANNEL_ORBIT + 1,
		"CHANNEL_COUNT covers every channel, the last one included")
	for channel in UnitTemperament.CHANNEL_COUNT:
		for slot in 2:
			for index in 40:
				var value := UnitTemperament.unit_value(slot, index, channel)
				assert_true(value >= 0.0 and value < 1.0,
					"unit_value(%d, %d, %d) = %f is outside [0, 1)" % [slot, index, channel, value])
				assert_eq(UnitTemperament.unit_value(slot, index, channel), value, "the same address gives the same value")
				var sibling := UnitTemperament.unit_value(slot, index + 1, channel)
				assert_true(absf(sibling - value) >= 0.38,
					"siblings %d and %d differ by only %f on channel %d (slot %d)"
							% [index, index + 1, absf(sibling - value), channel, slot])
				assert_eq(UnitTemperament.factor(slot, index, channel, 0.0), 1.0,
					"a kind authoring no spread has a factor of exactly 1.0")
				var factor := UnitTemperament.factor(slot, index, channel, 0.25)
				assert_true(factor >= 0.75 and factor < 1.25, "factor %f is outside [1 - spread, 1 + spread)" % factor)
		assert_true(UnitTemperament.unit_value(0, 0, channel) != UnitTemperament.unit_value(1, 0, channel),
			"the two slots' first units differ on channel %d" % channel)
	assert_true(UnitTemperament.unit_value(0, 0, UnitTemperament.CHANNEL_SPEED)
			!= UnitTemperament.unit_value(0, 0, UnitTemperament.CHANNEL_RADIUS),
		"one unit's traits are not all the same value")


## THE LEAP-AGAINST-BITE WEIGHT IS THE HOUND'S OWN. Two siblings shown the SAME rolls: the one whose
## temperament favours the leap leaps on every roll the other does, and on more. A chance of 0.0 is
## still never and 1.0 still always, for both.
func test_temperament_scales_a_hounds_leap_weight_and_keeps_never_and_always() -> void:
	var spread := 0.6
	var leaps: Array[int] = [0, 0]
	var sequences: Array = [[], []]
	for index in 2:
		var ms := _feel_match({&"temperament_weight_spread": spread})
		ms.p1.units.add(HOUND_HP, HOUND_KIND)
		ms.p1.units.add(HOUND_HP, HOUND_KIND)
		for i in 300:
			var phase := _re_engage(ms, ms.p1.units, index)
			(sequences[index] as Array).append(phase)
			if phase == UnitBoard.BehaviorPhase.ENGAGE_LEAP:
				leaps[index] += 1
	var keen := 0 if UnitTemperament.factor(0, 0, UnitTemperament.CHANNEL_LEAP, spread) \
			> UnitTemperament.factor(0, 1, UnitTemperament.CHANNEL_LEAP, spread) else 1
	assert_true(leaps[keen] > leaps[1 - keen],
		"the hound whose temperament favours the leap leaps more over the same 300 rolls (%d against %d)"
				% [leaps[keen], leaps[1 - keen]])
	for i in 300:
		if sequences[1 - keen][i] == UnitBoard.BehaviorPhase.ENGAGE_LEAP:
			assert_eq(sequences[keen][i], UnitBoard.BehaviorPhase.ENGAGE_LEAP,
				"roll %d: the keener hound leaps wherever its sibling does" % i)
	for chance: float in [0.0, 1.0]:
		_leap_chance = chance
		var ms := _feel_match({&"temperament_weight_spread": spread})
		_leap_chance = 0.5
		ms.p1.units.add(HOUND_HP, HOUND_KIND)
		ms.p1.units.add(HOUND_HP, HOUND_KIND)
		for index in 2:
			for i in 40:
				assert_eq(_re_engage(ms, ms.p1.units, index),
					UnitBoard.BehaviorPhase.ENGAGE_LEAP if chance == 1.0 else UnitBoard.BehaviorPhase.ENGAGE_BITE,
					"leap_chance %.1f stays %s for hound %d whatever its temperament"
							% [chance, "always" if chance == 1.0 else "never", index])


## THE OPTION WEIGHTS ARE THE HOUND'S OWN TOO. Circle against stalk at equal authored weights: over
## the same rolls the sibling whose temperament favours the stalk stalks more.
func test_temperament_scales_a_hounds_option_weights() -> void:
	var spread := 0.6
	var overrides := {&"circle_weight": 1.0, &"stalk_weight": 1.0, &"temperament_weight_spread": spread}
	var stalks: Array[int] = [0, 0]
	var share: Array[float] = [0.0, 0.0]
	for index in 2:
		stalks[index] = _decision_sequence(overrides, SEED, index, 300).count(UnitBoard.BehaviorPhase.STALK)
		var circle := UnitTemperament.factor(0, index, UnitTemperament.CHANNEL_CIRCLE, spread)
		var stalk := UnitTemperament.factor(0, index, UnitTemperament.CHANNEL_STALK, spread)
		share[index] = stalk / (circle + stalk)
	var keen := 0 if share[0] > share[1] else 1
	assert_true(absf(share[0] - share[1]) > 0.05, "fixture: the two siblings' stalk shares differ (%s)" % [share])
	assert_true(stalks[keen] > stalks[1 - keen],
		"the hound whose temperament favours the stalk stalks more over the same 300 rolls (%d against %d, shares %s)"
				% [stalks[keen], stalks[1 - keen], share])
	# With no spread authored the two siblings decide identically from identical rolls.
	var flat := {&"circle_weight": 1.0, &"stalk_weight": 1.0}
	assert_eq(_decision_sequence(flat, SEED, 0, 100), _decision_sequence(flat, SEED, 1, 100),
		"with no temperament spread, siblings shown the same rolls decide the same")


## ---- Feel pass 2: what a hound does when an ATTACK ends (back off, press, run on) ----

## End, on this tick, a swing of attack entry `choice` by the hound at `index`, and answer the
## behaviour phase it decided on. The swing is begun from whatever engaging phase the hound holds, so
## a press chain is walked by calling this again.
func _end_swing(ms: MatchState, board: UnitBoard, index: int, choice: int = 0) -> int:
	board.begin_windup_at(index, 1, 0, choice)
	board.set_phase_at(index, UnitBoard.AttackPhase.RECOVERY, 1)
	_idle(ms, 1)
	return board.behavior_phase_at(index)


## A feel match whose hound's LEAP carries it past its target (`overshoot`), so a run-on is on offer.
func _swing_match(overrides: Dictionary, overshoot: float = 1.0, seed_value: int = SEED) -> MatchState:
	_leap_overshoot = overshoot
	var ms := _feel_match(overrides, seed_value)
	_leap_overshoot = 0.0
	return ms


## The fixture authors no after-attack weight: a hound ALWAYS backs off, for a drawn time inside its
## bounds, as it did before this pass. With only the back-off weighted, the same.
func test_with_no_press_or_run_on_weight_an_attack_always_ends_in_a_back_off() -> void:
	for overrides: Dictionary in [{}, {&"back_off_weight": 1.0}]:
		var ms := _swing_match(overrides)
		ms.p1.units.add(HOUND_HP, HOUND_KIND)
		var board := ms.p1.units
		for i in 30:
			var choice := i % 2
			assert_eq(_end_swing(ms, board, 0, choice), UnitBoard.BehaviorPhase.BACK_OFF,
				"weights %s: swing %d (attack %d) ends in a back-off" % [overrides, i, choice])
			assert_true(board.behavior_ticks_at(0) >= BACK_OFF_MIN and board.behavior_ticks_at(0) <= BACK_OFF_MAX,
				"...for a drawn duration inside [min, max]: %d" % board.behavior_ticks_at(0))
			assert_eq(board.attack_phase_at(0), UnitBoard.AttackPhase.IDLE, "...and the swing is over")
			board.set_behavior_at(0, UnitBoard.BehaviorPhase.ENGAGE, 0)


## PRESS: the hound stays ENGAGING, with a freshly drawn attack, and in reach it winds up on the very
## tick the last swing ended -- no back-off, no countdown.
func test_a_press_keeps_the_hound_engaging_with_a_drawn_attack_and_it_attacks_at_once() -> void:
	var ms := _swing_match({&"press_weight": 1.0})
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	var board := ms.p1.units
	var phase := _end_swing(ms, board, 0)
	assert_true(phase == UnitBoard.BehaviorPhase.PRESS_BITE or phase == UnitBoard.BehaviorPhase.PRESS_LEAP,
		"only the press weighted: the swing ends in a pressed engagement (phase %d)" % phase)
	assert_true(board.is_engaging_at(0), "a pressing hound IS engaging")
	assert_eq(board.behavior_ticks_at(0), 0, "...with no countdown")
	assert_eq(UnitBoard.press_level(phase), 1, "...on the first link of its chain")
	# In reach: the next windup begins in the same pass that ended the swing.
	var chained := _swing_match({&"press_weight": 1.0})
	chained.p1.units.add(HOUND_HP, HOUND_KIND)
	var chain_board := chained.p1.units
	chain_board.set_target_at(0, 1, -1)
	chain_board.begin_windup_at(0, 1, 0, 0)
	chain_board.set_phase_at(0, UnitBoard.AttackPhase.RECOVERY, 2)
	chained.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
	_idle(chained, 2)
	assert_eq(chain_board.attack_count_at(0), 2, "in reach, a pressing hound begins its next swing at once")
	assert_eq(chain_board.attack_phase_at(0), UnitBoard.AttackPhase.WINDUP,
		"...on the very tick the last one's recovery ended")


## A CHAIN IS AT MOST THREE ATTACKS. With the press always drawn: the first swing ends on link 1, the
## second on link 2, and the third ends in a back-off -- the press is no longer on offer.
func test_a_press_chain_is_at_most_three_attacks() -> void:
	var ms := _swing_match({&"press_weight": 1.0})
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	var board := ms.p1.units
	for round in 10:
		board.set_behavior_at(0, UnitBoard.BehaviorPhase.ENGAGE, 0)
		var first := _end_swing(ms, board, 0)
		assert_eq(UnitBoard.press_level(first), 1, "round %d: the first swing is pressed (phase %d)" % [round, first])
		var second := _end_swing(ms, board, 0)
		assert_eq(UnitBoard.press_level(second), 2, "round %d: the second is pressed again (phase %d)" % [round, second])
		assert_true(second == UnitBoard.BehaviorPhase.PRESS_AGAIN_BITE or second == UnitBoard.BehaviorPhase.PRESS_AGAIN_LEAP,
			"...on the chain's last link")
		assert_eq(_end_swing(ms, board, 0), UnitBoard.BehaviorPhase.BACK_OFF,
			"round %d: the THIRD swing of a chain ends in a back-off, whatever the weights" % round)
	# The same through the real ladder: held in reach, the hound swings exactly three times before it
	# first backs off.
	var live := _swing_match({&"press_weight": 1.0})
	live.p1.units.add(HOUND_HP, HOUND_KIND)
	var live_board := live.p1.units
	live_board.set_target_at(0, 1, -1)
	var guard := 0
	while live_board.behavior_phase_at(0) != UnitBoard.BehaviorPhase.BACK_OFF and guard < 200:
		live.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
		_idle(live, 1)
		guard += 1
	assert_true(guard < 200, "fixture: the chain ended in a back-off")
	assert_eq(live_board.attack_count_at(0), 3, "a hound that always presses swings three times, then backs off")


## A pressed intent is an intent: a hound that pressed with the BITE ignores the leap band, one that
## pressed with the LEAP leaps from it -- at either link.
func test_a_pressed_bite_ignores_the_leap_band_and_a_pressed_leap_takes_it() -> void:
	for phase: int in [UnitBoard.BehaviorPhase.PRESS_BITE, UnitBoard.BehaviorPhase.PRESS_AGAIN_BITE]:
		var ms := _make_match()
		ms.p1.units.add(HOUND_HP, HOUND_KIND)
		var board := ms.p1.units
		board.set_target_at(0, 1, -1)
		board.set_behavior_at(0, phase, 0)
		assert_true(UnitBoard.is_bite_intent(phase), "phase %d is a bite intent" % phase)
		for tick in 6:
			ms.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE_SECOND)
			_idle(ms, 1)
		assert_eq(board.attack_count_at(0), 0, "phase %d: a pressed BITE does not leap from the leap band" % phase)
		ms.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
		_idle(ms, 2)
		assert_eq(board.attack_choice_at(0), 0, "phase %d: ...and bites once the close band is confirmed" % phase)
		assert_eq(board.attack_count_at(0), 1, "...having begun")
	for phase: int in [UnitBoard.BehaviorPhase.PRESS_LEAP, UnitBoard.BehaviorPhase.PRESS_AGAIN_LEAP]:
		var ms := _make_match()
		ms.p1.units.add(HOUND_HP, HOUND_KIND)
		var board := ms.p1.units
		board.set_target_at(0, 1, -1)
		board.set_behavior_at(0, phase, 0)
		assert_false(UnitBoard.is_bite_intent(phase), "phase %d is not a bite intent" % phase)
		ms.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE_SECOND)
		_idle(ms, 2)
		assert_eq(board.attack_choice_at(0), 1, "phase %d: a pressed LEAP leaps from the leap band" % phase)
	# The three helpers agree with each other for every intent and link.
	for level in 3:
		for leaps: bool in [false, true]:
			var phase := UnitBoard.drawn_engage_phase(leaps, level)
			assert_true(UnitBoard.is_engage_phase(phase), "drawn_engage_phase(%s, %d) is engaging" % [leaps, level])
			assert_eq(UnitBoard.press_level(phase), level, "...on link %d" % level)
			assert_eq(UnitBoard.is_bite_intent(phase), not leaps, "...with the intent it was given")


## RUN ON: offered only after a swing that carried the hound past its target. After such a leap it
## runs on for a drawn time, attacks nothing however close its target is, and then makes the same
## four-draw decision a back-off ends in. After a bite, or a leap with no overshoot, it backs off.
func test_a_run_on_follows_only_an_overshooting_swing_and_ends_in_the_back_off_decision() -> void:
	var ms := _swing_match({&"run_on_weight": 1.0})
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	var board := ms.p1.units
	board.set_target_at(0, 1, -1)
	assert_eq(_end_swing(ms, board, 0, 0), UnitBoard.BehaviorPhase.BACK_OFF,
		"only the run-on weighted, after a BITE: the run-on is not on offer, so it backs off")
	board.set_behavior_at(0, UnitBoard.BehaviorPhase.ENGAGE, 0)
	assert_eq(_end_swing(ms, board, 0, 1), UnitBoard.BehaviorPhase.RUN_ON, "after the LEAP: it runs on")
	var drawn := board.behavior_ticks_at(0)
	assert_true(drawn >= RUN_ON_MIN and drawn <= RUN_ON_MAX, "...for a drawn duration inside [min, max]: %d" % drawn)
	assert_false(board.is_engaging_at(0), "a hound running on is not engaging")
	var replica := RandomNumberGenerator.new()
	replica.state = ms.to_snapshot()["rng_state"]
	var swings := board.attack_count_at(0)
	assert_eq(_hold_phase_in_reach(ms, board, 0, UnitBoard.BehaviorPhase.RUN_ON, "the run-on"), drawn,
		"the run-on lasts exactly the ticks it drew")
	replica.randf()
	var ticks := _drawn_ticks(replica, CIRCLE_MIN, CIRCLE_MAX)
	var clockwise := replica.randf() < 0.5
	replica.randf()
	assert_eq(board.behavior_phase_at(0), UnitBoard.BehaviorPhase.CIRCLE,
		"RUN_ON -> the back-off's own decision (this fixture weights no option: the circle)")
	assert_eq(board.behavior_ticks_at(0), ticks, "...its duration the decision's second draw")
	assert_eq(board.circle_dir_at(0), UnitBoard.CIRCLE_CLOCKWISE if clockwise else UnitBoard.CIRCLE_COUNTER_CLOCKWISE,
		"...its direction the third")
	assert_eq(ms.to_snapshot()["rng_state"], replica.state, "...four draws, and none while it ran on")
	assert_eq(board.attack_count_at(0), swings, "...and no swing began while it ran on")
	# A leap that authors no overshoot carried the hound nowhere: no run-on after it either.
	var plain := _swing_match({&"run_on_weight": 1.0}, 0.0)
	plain.p1.units.add(HOUND_HP, HOUND_KIND)
	assert_eq(_end_swing(plain, plain.p1.units, 0, 1), UnitBoard.BehaviorPhase.BACK_OFF,
		"a leap with no authored overshoot is followed by a back-off, not a run-on")


## THE DECISION AFTER AN ATTACK IS TWO DRAWS WHATEVER IS DECIDED: which, then how long (inside the
## chosen option's own bounds; a press has no duration and still draws it). A press then makes the
## re-engage draw as its own decision. Pinned for each against a replica of the stream.
func test_the_decision_after_an_attack_is_two_draws_for_every_option() -> void:
	var cases: Array = [
		[{&"back_off_weight": 1.0}, 0, UnitBoard.BehaviorPhase.BACK_OFF, BACK_OFF_MIN, BACK_OFF_MAX],
		[{&"run_on_weight": 1.0}, 1, UnitBoard.BehaviorPhase.RUN_ON, RUN_ON_MIN, RUN_ON_MAX],
	]
	var after: Array[int] = []
	for case: Array in cases:
		var ms := _swing_match(case[0])
		ms.p1.units.add(HOUND_HP, HOUND_KIND)
		var board := ms.p1.units
		for i in 12:
			board.set_behavior_at(0, UnitBoard.BehaviorPhase.ENGAGE, 0)
			var replica := RandomNumberGenerator.new()
			replica.state = ms.to_snapshot()["rng_state"]
			var phase := _end_swing(ms, board, 0, case[1])
			replica.randf()
			var ticks := _drawn_ticks(replica, case[3], case[4])
			assert_eq(phase, case[2], "weights %s: swing %d ended in phase %d" % [case[0], i, phase])
			assert_eq(board.behavior_ticks_at(0), ticks, "...its duration is the SECOND draw, inside its own bounds")
			assert_eq(ms.to_snapshot()["rng_state"], replica.state,
				"...and exactly two draws were made (weights %s, swing %d)" % [case[0], i])
			if i == 0:
				after.append(ms.to_snapshot()["rng_state"])
	assert_eq(after[0], after[1], "after one decision the stream is in the same place for a back-off and a run-on")
	# The press: the decision's two, then the re-engage's one.
	var pressed := _swing_match({&"press_weight": 1.0})
	pressed.p1.units.add(HOUND_HP, HOUND_KIND)
	var replica := RandomNumberGenerator.new()
	replica.state = pressed.to_snapshot()["rng_state"]
	var phase := _end_swing(pressed, pressed.p1.units, 0, 0)
	replica.randf()
	replica.randf()
	assert_eq(replica.state, after[0], "a press leaves the decision's own two draws where a back-off leaves them")
	var leaps := replica.randf() < 0.5
	assert_eq(phase, UnitBoard.BehaviorPhase.PRESS_LEAP if leaps else UnitBoard.BehaviorPhase.PRESS_BITE,
		"the press's attack is drawn after the decision's two draws, against the leap chance")
	assert_eq(pressed.to_snapshot()["rng_state"], replica.state, "...three draws in all")
	# A FIXED back-off (equal bounds) still draws its duration: at a swing's end and out of a reaction.
	var fixed := float(BACK_OFF_MIN) / TimingWindow.TICK_HZ
	var steady := _swing_match({&"back_off_min_seconds": fixed, &"back_off_max_seconds": fixed})
	steady.p1.units.add(HOUND_HP, HOUND_KIND)
	replica.state = steady.to_snapshot()["rng_state"]
	_end_swing(steady, steady.p1.units, 0, 0)
	assert_eq(steady.p1.units.behavior_ticks_at(0), BACK_OFF_MIN, "a fixed back-off lasts its one authored length")
	replica.randf()
	replica.randf()
	assert_eq(steady.to_snapshot()["rng_state"], replica.state, "...and the decision still made its two draws")
	steady.p1.units.set_behavior_at(0, UnitBoard.BehaviorPhase.REACT, 1)
	_idle(steady, 1)
	assert_eq(steady.p1.units.behavior_phase_at(0), UnitBoard.BehaviorPhase.BACK_OFF, "fixture: REACT -> BACK_OFF")
	replica.randf()
	assert_eq(steady.to_snapshot()["rng_state"], replica.state,
		"the reaction's exit is ONE draw even when the back-off's bounds are equal")


## VARIETY after an attack: with all three weighted, all three come up after a leap and only two after
## a bite; the same seed repeats the sequence and another does not.
func test_with_every_after_attack_option_weighted_all_three_come_up() -> void:
	var weights := {&"back_off_weight": 1.0, &"press_weight": 1.0, &"run_on_weight": 1.0}
	var after_leap := _after_attack_sequence(weights, SEED, 0, 1, 150)
	var backs := after_leap.count(UnitBoard.BehaviorPhase.BACK_OFF)
	var runs := after_leap.count(UnitBoard.BehaviorPhase.RUN_ON)
	var presses := after_leap.size() - backs - runs
	assert_true(backs > 20 and runs > 20 and presses > 20,
		"after a leap all three come up over 150 swings (%d back-offs, %d run-ons, %d presses)" % [backs, runs, presses])
	for phase: int in after_leap:
		assert_true(phase == UnitBoard.BehaviorPhase.BACK_OFF or phase == UnitBoard.BehaviorPhase.RUN_ON
				or UnitBoard.press_level(phase) == 1, "every swing ends in one of the three (phase %d)" % phase)
	assert_eq(_after_attack_sequence(weights, SEED, 0, 1, 150), after_leap, "the same seed decides the same sequence")
	assert_true(_after_attack_sequence(weights, SEED + 1, 0, 1, 150) != after_leap, "another seed decides another")
	var after_bite := _after_attack_sequence(weights, SEED, 0, 0, 150)
	assert_eq(after_bite.count(UnitBoard.BehaviorPhase.RUN_ON), 0, "a bite is never followed by a run-on")
	assert_true(after_bite.count(UnitBoard.BehaviorPhase.BACK_OFF) > 20
			and after_bite.count(UnitBoard.BehaviorPhase.BACK_OFF) < 130,
		"...and both the back-off and the press still come up after it")


## The phases `count` successive swings of attack entry `choice` end in, for the hound at board
## `index` (of two on P1's board), each swing begun from a plain engagement.
func _after_attack_sequence(overrides: Dictionary, seed_value: int, index: int, choice: int, count: int) -> Array[int]:
	var ms := _swing_match(overrides, 1.0, seed_value)
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	var drawn: Array[int] = []
	for i in count:
		ms.p1.units.set_behavior_at(index, UnitBoard.BehaviorPhase.ENGAGE, 0)
		drawn.append(_end_swing(ms, ms.p1.units, index, choice))
	return drawn


## THE PRESS WEIGHT IS THE HOUND'S OWN. Back-off against press at equal authored weights: over the
## same rolls the sibling whose temperament favours the press presses more.
func test_temperament_scales_a_hounds_after_attack_weights() -> void:
	var spread := 0.6
	var overrides := {&"back_off_weight": 1.0, &"press_weight": 1.0, &"temperament_weight_spread": spread}
	var presses: Array[int] = [0, 0]
	var share: Array[float] = [0.0, 0.0]
	for index in 2:
		var sequence := _after_attack_sequence(overrides, SEED, index, 0, 300)
		presses[index] = 300 - sequence.count(UnitBoard.BehaviorPhase.BACK_OFF)
		var back := UnitTemperament.factor(0, index, UnitTemperament.CHANNEL_BACK_OFF, spread)
		var press := UnitTemperament.factor(0, index, UnitTemperament.CHANNEL_PRESS, spread)
		share[index] = press / (back + press)
	var keen := 0 if share[0] > share[1] else 1
	assert_true(absf(share[0] - share[1]) > 0.05, "fixture: the two siblings' press shares differ (%s)" % [share])
	assert_true(presses[keen] > presses[1 - keen],
		"the hound whose temperament favours the press presses more over the same 300 rolls (%d against %d, shares %s)"
				% [presses[keen], presses[1 - keen], share])


## ---- Feel pass 2: two more things a hound may do when its back-off ends (reposition, retreat) ----

## REPOSITION: a run round the target for a drawn time in a drawn direction; no attack begins however
## close the target is; it ends in the re-engage draw on the kind's own leap chance.
func test_a_reposition_runs_its_drawn_time_in_a_drawn_direction_and_ends_in_the_re_engage_draw() -> void:
	var ms := _feel_match({&"reposition_weight": 1.0})
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	var board := ms.p1.units
	board.set_target_at(0, 1, -1)
	var directions := {}
	for i in 12:
		assert_eq(_decide(ms, board, 0), UnitBoard.BehaviorPhase.REPOSITION,
			"BACK_OFF -> REPOSITION when only the reposition has a weight")
		directions[board.circle_dir_at(0)] = true
		var drawn := board.behavior_ticks_at(0)
		assert_true(drawn >= REPOSITION_MIN and drawn <= REPOSITION_MAX,
			"...for a drawn duration inside [min, max]: %d" % drawn)
		assert_false(board.is_engaging_at(0), "a repositioning hound is not engaging")
		var replica := RandomNumberGenerator.new()
		replica.state = ms.to_snapshot()["rng_state"]
		var swings := board.attack_count_at(0)
		assert_eq(_hold_phase_in_reach(ms, board, 0, UnitBoard.BehaviorPhase.REPOSITION, "the reposition"), drawn,
			"the reposition lasts exactly the ticks it drew")
		var leaps := replica.randf() < 0.5
		assert_eq(board.behavior_phase_at(0),
			UnitBoard.BehaviorPhase.ENGAGE_LEAP if leaps else UnitBoard.BehaviorPhase.ENGAGE_BITE,
			"REPOSITION -> the re-engage draw, one draw against the leap chance")
		assert_eq(ms.to_snapshot()["rng_state"], replica.state, "...and nothing else was drawn while it ran")
		# Held in reach, it may begin its swing on the tick the reposition is OVER, and no sooner.
		assert_true(board.attack_count_at(0) <= swings + 1, "no swing began while it repositioned")
		board.set_phase_at(0, UnitBoard.AttackPhase.IDLE, 0)
	assert_true(directions.has(UnitBoard.CIRCLE_CLOCKWISE) and directions.has(UnitBoard.CIRCLE_COUNTER_CLOCKWISE),
		"over twelve repositions both directions were drawn: %s" % [directions.keys()])


## RETREAT: it goes away for a drawn time, attacks nothing, and comes back on its OWN leap chance --
## `retreat_leap_chance`, not the kind's `leap_chance` -- in one draw.
func test_a_retreat_lasts_its_drawn_time_and_re_engages_on_its_own_leap_chance() -> void:
	for favours_leap: bool in [true, false]:
		_leap_chance = 0.0 if favours_leap else 1.0
		var ms := _feel_match({&"retreat_weight": 1.0, &"retreat_leap_chance": 1.0 if favours_leap else 0.0})
		_leap_chance = 0.5
		ms.p1.units.add(HOUND_HP, HOUND_KIND)
		var board := ms.p1.units
		for i in 12:
			assert_eq(_decide(ms, board, 0), UnitBoard.BehaviorPhase.RETREAT,
				"BACK_OFF -> RETREAT when only the retreat has a weight")
			var drawn := board.behavior_ticks_at(0)
			assert_true(drawn >= RETREAT_MIN and drawn <= RETREAT_MAX,
				"...for a drawn duration inside [min, max]: %d" % drawn)
			assert_false(board.is_engaging_at(0), "a retreating hound is not engaging")
			var replica := RandomNumberGenerator.new()
			replica.state = ms.to_snapshot()["rng_state"]
			var ticks := 0
			while board.behavior_phase_at(0) == UnitBoard.BehaviorPhase.RETREAT and ticks < 200:
				_idle(ms, 1)
				ticks += 1
			assert_eq(ticks, drawn, "the retreat lasts exactly the ticks it drew")
			assert_eq(board.behavior_phase_at(0),
				UnitBoard.BehaviorPhase.ENGAGE_LEAP if favours_leap else UnitBoard.BehaviorPhase.ENGAGE_BITE,
				"RETREAT re-engages on `retreat_leap_chance` (%s), not on the kind's `leap_chance`"
						% ("1.0" if favours_leap else "0.0"))
			replica.randf()
			assert_eq(ms.to_snapshot()["rng_state"], replica.state, "...in exactly one draw")


## ORBIT (feel pass 3): a circle that lasts long, under its own phase. Drawn when a back-off ends, it
## is entered as ORBIT (or ORBIT_TURN when it will reverse) for a duration inside the ORBIT's own
## bounds, in a drawn direction; it begins no attack however close its target is, lasts exactly what
## it drew, reverses once as a circle does, and ends in the re-engage draw. With no orbit weight, no
## orbit is ever entered and no circle is ever that long.
func test_an_orbit_is_a_long_circle_drawn_inside_its_own_bounds() -> void:
	var ms := _feel_match({&"orbit_weight": 1.0})
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	var board := ms.p1.units
	board.set_target_at(0, 1, -1)
	for i in 12:
		assert_eq(_decide(ms, board, 0), UnitBoard.BehaviorPhase.ORBIT, "BACK_OFF -> ORBIT when only the orbit has a weight")
		var drawn := board.behavior_ticks_at(0)
		assert_true(drawn >= ORBIT_MIN and drawn <= ORBIT_MAX,
			"...for a duration drawn inside the ORBIT's bounds [%d, %d], not the circle's: %d" % [ORBIT_MIN, ORBIT_MAX, drawn])
		assert_true(board.circle_dir_at(0) == UnitBoard.CIRCLE_CLOCKWISE
				or board.circle_dir_at(0) == UnitBoard.CIRCLE_COUNTER_CLOCKWISE, "...in a drawn direction")
		assert_false(board.is_engaging_at(0), "an orbiting hound is not engaging")
		var replica := RandomNumberGenerator.new()
		replica.state = ms.to_snapshot()["rng_state"]
		assert_eq(_hold_phase_in_reach(ms, board, 0, UnitBoard.BehaviorPhase.ORBIT, "the orbit"), drawn,
			"the orbit lasts exactly the ticks it drew, and begins no attack on the way")
		var leaps := replica.randf() < 0.5
		assert_eq(board.behavior_phase_at(0),
			UnitBoard.BehaviorPhase.ENGAGE_LEAP if leaps else UnitBoard.BehaviorPhase.ENGAGE_BITE,
			"the orbit ends in the re-engage draw")
		assert_eq(ms.to_snapshot()["rng_state"], replica.state, "...one draw, and none while it orbited")
		board.set_phase_at(0, UnitBoard.AttackPhase.IDLE, 0)
	# It may reverse once, like any circle.
	var turning := _feel_match({&"orbit_weight": 1.0, &"circle_flip_chance": 1.0})
	turning.p1.units.add(HOUND_HP, HOUND_KIND)
	assert_eq(_decide(turning, turning.p1.units, 0), UnitBoard.BehaviorPhase.ORBIT_TURN, "an orbit that will reverse is an ORBIT_TURN")
	var long := turning.p1.units.behavior_ticks_at(0)
	var first_dir := turning.p1.units.circle_dir_at(0)
	assert_true(long >= ORBIT_MIN and long <= ORBIT_MAX, "...as long as an orbit: %d" % long)
	assert_false(turning.p1.units.is_engaging_at(0), "...and not engaging")
	_idle(turning, long - FLIP_REMAINING - 1)
	assert_eq(turning.p1.units.behavior_phase_at(0), UnitBoard.BehaviorPhase.ORBIT_TURN, "one tick before its authored remainder it has not yet reversed")
	_idle(turning, 1)
	assert_eq(turning.p1.units.behavior_phase_at(0), UnitBoard.BehaviorPhase.ORBIT, "it reverses when its authored remainder is left, and stays an orbit")
	assert_eq(turning.p1.units.circle_dir_at(0), -first_dir, "...the other way round")
	assert_eq(turning.p1.units.behavior_ticks_at(0), FLIP_REMAINING, "...with its countdown carrying on")
	_idle(turning, FLIP_REMAINING)
	assert_true(_is_drawn_engage(turning.p1.units.behavior_phase_at(0)), "...and it ends in the re-engage draw")
	# No orbit weight: a circle is never as long as an orbit. With one: both lengths come up.
	var plain := _feel_match({&"circle_weight": 1.0})
	plain.p1.units.add(HOUND_HP, HOUND_KIND)
	var mixed := _feel_match({&"circle_weight": 1.0, &"orbit_weight": 1.0})
	mixed.p1.units.add(HOUND_HP, HOUND_KIND)
	var short := 0
	var orbits := 0
	for i in 60:
		assert_eq(_decide(plain, plain.p1.units, 0), UnitBoard.BehaviorPhase.CIRCLE, "with no orbit weight no orbit is entered")
		assert_true(plain.p1.units.behavior_ticks_at(0) <= CIRCLE_MAX, "...and no circle lasts longer than a circle")
		if _decide(mixed, mixed.p1.units, 0) == UnitBoard.BehaviorPhase.ORBIT:
			orbits += 1
			assert_true(mixed.p1.units.behavior_ticks_at(0) >= ORBIT_MIN, "an orbit is never as short as a circle")
		else:
			short += 1
			assert_true(mixed.p1.units.behavior_ticks_at(0) <= CIRCLE_MAX, "a circle is never as long as an orbit")
	assert_true(short > 10 and orbits > 10, "circle and orbit at equal weights: both come up (%d circles, %d orbits)" % [short, orbits])


## VARIETY: with all SIX options weighted, all six come up.
func test_with_all_six_options_weighted_all_six_come_up() -> void:
	var weights := {&"circle_weight": 1.0, &"stalk_weight": 1.0, &"feint_weight": 1.0, &"re_engage_weight": 1.0,
			&"reposition_weight": 1.0, &"retreat_weight": 1.0}
	var drawn := _decision_sequence(weights, SEED, 0, 300)
	var counts := {
		"circle": drawn.count(UnitBoard.BehaviorPhase.CIRCLE),
		"stalk": drawn.count(UnitBoard.BehaviorPhase.STALK),
		"feint": drawn.count(UnitBoard.BehaviorPhase.FEINT_IN),
		"direct": drawn.count(UnitBoard.BehaviorPhase.ENGAGE_BITE) + drawn.count(UnitBoard.BehaviorPhase.ENGAGE_LEAP),
		"reposition": drawn.count(UnitBoard.BehaviorPhase.REPOSITION),
		"retreat": drawn.count(UnitBoard.BehaviorPhase.RETREAT),
	}
	var total := 0
	for option: String in counts:
		total += int(counts[option])
		assert_true(int(counts[option]) > 20, "`%s` comes up over 300 decisions at equal weights: %s" % [option, counts])
	assert_eq(total, 300, "every decision is one of the six options: %s" % [counts])
	var without := _decision_sequence({&"circle_weight": 1.0, &"reposition_weight": 1.0}, SEED, 0, 200)
	assert_eq(without.count(UnitBoard.BehaviorPhase.RETREAT), 0, "an option with no weight is never chosen")


## ---- Smoke finding 2: Grave Ward on a HOUND's corpse (the state half) ----

## The card extends a hound's corpse exactly as it extends a zombie's: the lifetime grows by the
## authored duration and the corpse is marked. With ONLY a hound corpse out the cast is not refused.
## The opponent's hound corpse and a living hound are untouched.
func test_grave_ward_extends_a_hounds_corpse_and_marks_it() -> void:
	var ms := _make_match()
	var board := ms.p1.units
	board.add(HOUND_HP, HOUND_KIND)
	board.add(HOUND_HP, ZOMBIE_KIND)
	board.add(HOUND_HP, HOUND_KIND)
	ms.p2.units.add(HOUND_HP, HOUND_KIND)
	board.kill_at(0, CORPSE_TICKS)
	board.kill_at(1, CORPSE_TICKS)
	ms.p2.units.kill_at(0, CORPSE_TICKS)
	assert_true(board.has_corpse_at(0), "fixture: the dead hound left a corpse")
	var hound_before := board.corpse_ticks_at(0)
	var zombie_before := board.corpse_ticks_at(1)
	var enemy_before := ms.p2.units.corpse_ticks_at(0)
	_cast(ms, 0, ID_WARD)
	# The cast tick ages every corpse by one before the ward lands.
	assert_eq(board.corpse_ticks_at(0), hound_before - 1 + WARD_TICKS,
		"Grave Ward adds its authored duration to a HOUND's corpse")
	assert_true(board.is_corpse_extended_at(0), "...and marks it extended")
	assert_eq(board.corpse_ticks_at(1), zombie_before - 1 + WARD_TICKS, "...exactly as it does a zombie's")
	assert_true(board.is_corpse_extended_at(1), "...which is marked too")
	assert_false(board.is_corpse_extended_at(2), "a LIVING hound is not marked")
	assert_eq(ms.p2.units.corpse_ticks_at(0), enemy_before - 1, "the OPPONENT's hound corpse is untouched")
	assert_false(ms.p2.units.is_corpse_extended_at(0), "...and not marked")
	# Only a hound corpse on the board: the cast is not refused (it needs an own corpse; a hound's is one).
	var only := _make_match()
	only.p1.units.add(HOUND_HP, HOUND_KIND)
	only.p1.units.kill_at(0, CORPSE_TICKS)
	var mana_before := only.p1.mana.get_current()
	_cast(only, 0, ID_WARD)
	assert_true(only.p1.units.is_corpse_extended_at(0), "with only a hound corpse out, Grave Ward resolves on it")
	assert_true(only.p1.mana.get_current() < mana_before, "...and was paid for, not refused")
	# And the extended corpse outlives an unextended one by the extension.
	_idle(only, CORPSE_TICKS)
	assert_true(only.p1.units.has_corpse_at(0), "an extended hound corpse is still there after the plain lifetime")


## ---- AC 16 (`7-3/R8`/`R10`/`R17`): the get-up lockout ----

func test_a_raised_hound_is_locked_out_of_attacking_for_its_get_up_and_takes_damage_without_a_reaction() -> void:
	var ms := _make_match()
	_cast(ms, 0, ID_HOUND)
	ms.p1.units.kill_at(0, CORPSE_TICKS)
	ms.p1.units.kill_at(1, CORPSE_TICKS)
	_cast(ms, 0, ID_RAISE)
	var board := ms.p1.units
	assert_eq(board.behavior_phase_at(2), UnitBoard.BehaviorPhase.GET_UP, "a raised hound is GETTING UP")
	assert_eq(board.behavior_ticks_at(2), GET_UP_TICKS, "...for its kind's authored duration")
	board.set_target_at(2, 1, -1)
	ms.push_contact([0, 2], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
	# TWO ticks: the probe is consumed at step 4 of the first, so the first step-3b pass that could
	# begin a windup is the second tick's. One tick would prove nothing.
	_idle(ms, 2)
	assert_eq(board.attack_phase_at(2), UnitBoard.AttackPhase.IDLE,
		"in reach but getting up: it does NOT wind up")
	assert_eq(board.attack_count_at(2), 0, "...and has begun no swing at all")
	# Damage lands during the get-up, and starts no reaction.
	var hp_before := board.hp_at(2)
	var ticks_before := board.behavior_ticks_at(2)
	_hero_hits_unit(ms, 1, 2, false)
	assert_eq(board.hp_at(2), hp_before - HERO_TO_UNIT, "a hound CAN be damaged while it gets up")
	assert_eq(board.behavior_phase_at(2), UnitBoard.BehaviorPhase.GET_UP,
		"...and has NO hit reaction during it: it is still getting up")
	assert_eq(board.behavior_ticks_at(2), ticks_before - 4,
		"...the lockout simply kept counting down, one tick per tick, neither reset nor cut")
	var guard := 0
	while not board.is_engaging_at(2) and guard < 60:
		_idle(ms, 1)
		guard += 1
	assert_true(board.is_engaging_at(2), "the lockout ENDS and the hound is engaging")


## The lockout's exact length, and the windup that follows it on the very tick it ends.
func test_the_get_up_lockout_lasts_exactly_its_authored_ticks() -> void:
	var ms := _make_match()
	ms.p1.units.add(HOUND_HP, HOUND_KIND)
	ms.p1.units.kill_at(0, CORPSE_TICKS)
	_cast(ms, 0, ID_RAISE)
	var board := ms.p1.units
	board.set_target_at(1, 1, -1)
	ms.push_contact([0, 1], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
	_idle(ms, GET_UP_TICKS - 1)
	assert_eq(board.behavior_phase_at(1), UnitBoard.BehaviorPhase.GET_UP, "one tick short: still up-getting")
	assert_eq(board.attack_count_at(1), 0, "...and it has not attacked")
	_idle(ms, 1)
	assert_true(board.is_engaging_at(1), "on the authored tick the lockout ends")
	assert_eq(board.attack_phase_at(1), UnitBoard.AttackPhase.WINDUP,
		"...and the hound, still in reach, winds up at once")


## ONE RULE for every hound that rises from a corpse: a Counterspell RESTORE gets up exactly as a
## Raise Dead does. And a zombie, which authors no get-up, rises attack-ready on both paths.
func test_a_counterspell_restore_gets_up_like_a_raise_and_a_zombie_has_no_lockout() -> void:
	var restored := _make_match()
	restored.p2.units.add(HOUND_HP, HOUND_KIND)
	restored.p2.units.add(HOUND_HP, ZOMBIE_KIND)
	_cast(restored, 1, ID_CULLING)
	assert_eq(restored.p2.units.living_indices(), [] as Array[int], "sanity: the Culling killed both")
	_counter(restored)
	assert_eq(restored.p2.units.living_indices(), [2, 3] as Array[int], "sanity: both were restored")
	assert_eq(restored.p2.units.kind_index_at(2), HOUND_KIND, "the restored hound is a hound")
	assert_eq(restored.p2.units.behavior_phase_at(2), UnitBoard.BehaviorPhase.GET_UP,
		"a hound RESTORED by a Counterspell is getting up (`7-3/R17`: one rule)")
	assert_eq(restored.p2.units.behavior_ticks_at(2), GET_UP_TICKS, "...for the same authored duration")
	assert_eq(restored.p2.units.behavior_phase_at(3), UnitBoard.BehaviorPhase.ENGAGE,
		"a restored ZOMBIE has no lockout")
	var raised := _make_match()
	raised.p1.units.add(HOUND_HP, ZOMBIE_KIND)
	raised.p1.units.kill_at(0, CORPSE_TICKS)
	_cast(raised, 0, ID_RAISE)
	assert_eq(raised.p1.units.behavior_phase_at(1), UnitBoard.BehaviorPhase.ENGAGE,
		"a raised ZOMBIE is attack-ready, exactly as before")


## ---- fixtures ----

func _make_match(flags: FeatureFlags = null, seed_value: int = SEED) -> MatchState:
	var ms := MatchState.new(MatchParams.new(seed_value))
	ms.apply_balance(_config())
	ms.inject_feature_flags(flags if flags != null else _flags())
	ms.inject_deck(DECK)
	ms.inject_card_costs(_costs(DECK))
	ms.inject_card_effects(_effects())
	ms.inject_pitch_costs(_costs(DECK))
	ms.inject_pitch_effects(_effects())
	_idle(ms, 1)   # the step-6 deal
	for player: PlayerState in [ms.p1, ms.p2]:
		player.mana.add(START_MANA)
		player.orbs.add(Enums.CardColor.GREEN, 8)
	ms.drain_signals()
	return ms


## A match whose whole deck is copies of ONE in-test card built from authored effect files (AC 3).
func _make_combo_match(card: CardData) -> MatchState:
	var deck: Array[StringName] = []
	for _i in DECK.size():
		deck.append(card.id)
	var basic: Dictionary[StringName, CardEffect] = {card.id: card.basic_effect}
	var pitch: Dictionary[StringName, CardEffect] = {card.id: card.pitch_effect}
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_feature_flags(_flags())
	ms.inject_deck(deck)
	ms.inject_card_costs(_costs(deck))
	ms.inject_card_effects(basic)
	ms.inject_pitch_costs(_costs(deck))
	ms.inject_pitch_effects(pitch)
	_idle(ms, 1)
	ms.p1.mana.add(START_MANA)
	ms.p1.orbs.add(Enums.CardColor.GREEN, 8)
	ms.drain_signals()
	return ms


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.move_speed = 5.0
	c.walk_speed = 2.5
	c.max_stamina = 50.0
	c.max_mana = 60.0
	c.deck_size = DECK.size()
	c.hand_size = DECK.size()
	# No replacement is ever delivered inside a test, so no cast can trigger a reshuffle and the RNG
	# assertions above measure the hounds' draws alone.
	c.draw_replacement_delay_seconds = 1000.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 3.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 6.0
	c.block_facing_arc_degrees = 360.0
	c.block_damage_multiplier = BLOCK_MULTIPLIER
	c.deflect_window_seconds = 4.0 / 60.0
	c.deflect_stamina_cost = 8.0
	c.roll_stamina_cost = 5.0
	c.roll_duration_seconds = 8.0 / 60.0
	c.roll_iframe_seconds = 6.0 / 60.0
	c.roll_distance = 3.0
	c.hero_damage_to_unit = HERO_TO_UNIT
	c.minion_retarget_interval_seconds = 1000.0
	c.corpse_lifetime_seconds = float(CORPSE_TICKS) / TimingWindow.TICK_HZ
	c.knockdown_stun_seconds = 2.0
	c.pitch_stage_timer_seconds = 30.0
	c.max_orbs_per_color = 99
	var kinds: Array[UnitKindProfile] = [
		UnitKindFixture.melee(CardEffectResolver.KIND_MINION, HOUND_HP, ZOMBIE_DAMAGE, WINDUP, ACTIVE,
				RECOVERY, BITE_REACH),
		UnitKindFixture.inert(CardEffectResolver.KIND_COMBAT_TOTEM, HOUND_HP),
		UnitKindFixture.hound(&"hellhound", HOUND_HP, BITE_DAMAGE, LEAP_DAMAGE, WINDUP, ACTIVE,
				RECOVERY, BITE_REACH, LEAP_REACH, REACTION_TICKS, GET_UP_TICKS, BACK_OFF_MIN,
				BACK_OFF_MAX, CIRCLE_MIN, CIRCLE_MAX),
	]
	kinds[HOUND_KIND].leap_chance = _leap_chance
	kinds[HOUND_KIND].attack_at(1).travel_overshoot = _leap_overshoot
	for field: StringName in _hound_overrides:
		kinds[HOUND_KIND].set(field, _hound_overrides[field])
	c.unit_kinds = kinds
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.orbs = true
	f.pitch_zone = true
	f.minions = true
	f.totems = true
	f.spells = true
	return f


func _costs(ids: Array[StringName]) -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in ids:
		var c := CardCastCondition.new()
		c.mana_cost = CAST_MANA
		c.orb_costs = {Enums.CardColor.GREEN: 1} as Dictionary[Enums.CardColor, int]
		out[id] = c
	return out


func _effects() -> Dictionary[StringName, CardEffect]:
	var ids := {ID_HOUND: &"summon_hellhound", ID_VANGUARD: &"summon_ruin_vanguard",
			ID_CULLING: &"culling", ID_DRAIN: &"drain", ID_RAISE: &"raise_dead",
			ID_BOMB: &"corpse_bomb", ID_COUNTER: &"counterspell", ID_BOLT: &"honed_bolt",
			ID_WARD: &"grave_ward"}
	var out: Dictionary[StringName, CardEffect] = {}
	for id: StringName in ids:
		var e := CardEffect.new()
		e.effect_id = ids[id]
		match e.effect_id:
			&"summon_hellhound":
				e.summon_count = 2
				e.summon_kind = &"hellhound"
			&"culling":
				e.mana_per_kill = CULLING_MANA_PER_KILL
			&"drain":
				e.heal_amount = DRAIN_HEAL
			&"corpse_bomb":
				e.damage_amount = 5.0
				e.launch_speed = 6.0
				e.max_speed = 6.0
				e.travel_budget = 60.0
			&"honed_bolt":
				e.cast_seconds = float(BOLT_CAST_TICKS) / TimingWindow.TICK_HZ
				e.damage_amount = BOLT_DAMAGE
			&"grave_ward":
				e.duration_seconds = float(WARD_TICKS) / TimingWindow.TICK_HZ
		out[id] = e
	return out


func _player(ms: MatchState, slot: int) -> PlayerState:
	return ms.p1 if slot == 0 else ms.p2


## The unit at `index` on `slot`'s board brought into its ACTIVE window through the real reach
## trigger and phase ladder, on whichever reach band(s) `probes` names.
func _unit_into_active(ms: MatchState, slot: int, index: int,
		probes: Array = [MatchState.CONTACT_REACH_PROBE]) -> void:
	var player := _player(ms, slot)
	player.units.set_target_at(index, 1 - slot, -1)
	for probe: int in probes:
		ms.push_contact([slot, index], [1 - slot, -1], 0, Vector2.DOWN, probe)
	_idle(ms, 2 + WINDUP)
	assert_eq(player.units.attack_phase_at(index), UnitBoard.AttackPhase.ACTIVE,
		"fixture: the unit reached its ACTIVE window")


## Queue the unit's own strike fact against the opposing hero (resolved by the next advance).
func _strike(ms: MatchState, slot: int, index: int) -> void:
	ms.push_contact([slot, index], [1 - slot, -1], _player(ms, slot).units.attack_count_at(index),
			Vector2.DOWN, MatchState.CONTACT_STRIKE)


## One fresh hero swing from `attacker_slot` landing on the unit at `index` on the other board, then
## (with `settle`) enough idle ticks for the swing to finish so the next call starts a new one. The
## hit resolves on the FOURTH tick of the call; a test reading the tick the hit landed passes false.
func _hero_hits_unit(ms: MatchState, attacker_slot: int, index: int, settle: bool = true) -> void:
	var attacker := _player(ms, attacker_slot)
	_advance_slot(ms, attacker_slot, _press(&"attack"))
	_idle(ms, 2)
	ms.push_contact([attacker_slot, -1], [1 - attacker_slot, index], attacker.hero.attack_index,
			Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_idle(ms, 1)
	if settle:
		_idle(ms, 12)


## `ticks` ticks of every unit of `kind` attacking whenever it may: P1 gets two units and P2 one,
## each re-confirmed in reach every tenth tick. Returns the per-tick behaviour trace.
func _run_attack_script(ms: MatchState, kind: int, ticks: int) -> Array:
	ms.p1.units.add(HOUND_HP, kind)
	ms.p1.units.add(HOUND_HP, kind)
	ms.p2.units.add(HOUND_HP, kind)
	var trace: Array = []
	for tick in ticks:
		if tick % 10 == 0:
			for slot in 2:
				var board := _player(ms, slot).units
				for index in board.size():
					board.set_target_at(index, 1 - slot, -1)
					ms.push_contact([slot, index], [1 - slot, -1], 0, Vector2.DOWN,
							MatchState.CONTACT_REACH_PROBE)
		_idle(ms, 1)
		trace.append([ms.p1.units.behavior_phase_snapshot(), ms.p1.units.behavior_ticks_snapshot(),
				ms.p1.units.circle_dir_snapshot(), ms.p2.units.behavior_phase_snapshot(),
				ms.p2.units.behavior_ticks_snapshot(), ms.p2.units.circle_dir_snapshot()])
	return trace


func _run_until_phase_leaves(ms: MatchState, board: UnitBoard, index: int, phase: int) -> void:
	var guard := 0
	while board.behavior_phase_at(index) == phase and guard < 200:
		_idle(ms, 1)
		guard += 1
	assert_true(guard < 200, "fixture: behaviour phase %d ended" % phase)


func _cast(ms: MatchState, slot: int, id: StringName) -> void:
	_advance_slot(ms, slot, _cast_intent(_slot_of(_player(ms, slot), id)))


## P1 stages and activates Counterspell: the real two-press Mode 4 sequence, two ticks.
func _counter(ms: MatchState) -> void:
	_advance_slot(ms, 0, _stage_intent(_slot_of(ms.p1, ID_COUNTER)))
	_advance_slot(ms, 0, _activate_intent())


func _cast_intent(hand_slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = hand_slot
	i.card_mode = Enums.ModeKind.BASIC
	i.card_commit = true
	return i


func _stage_intent(hand_slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = hand_slot
	i.card_mode = Enums.ModeKind.PITCH
	i.card_commit = true
	return i


func _activate_intent() -> InputIntent:
	var i := InputIntent.new()
	i.card_mode = Enums.ModeKind.PITCH
	i.card_commit = true
	i.card_activate = true
	return i


func _press(action: StringName) -> InputIntent:
	var i := InputIntent.new()
	i.pressed[action] = true
	i.held[action] = true
	return i


func _slot_of(player: PlayerState, id: StringName) -> int:
	var hand := player.hand.to_array()
	for index in hand.size():
		if not player.hand.is_slot_empty(index) and hand[index] == id:
			return index
	assert_true(false, "fixture: %s is in the dealt hand" % id)
	return -1


## One tick in which `slot` plays `intent` and the other slot plays nothing.
func _advance_slot(ms: MatchState, slot: int, intent: InputIntent) -> void:
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	intents[slot] = intent
	ms.advance(intents)
	ms.drain_signals()


func _idle(ms: MatchState, n: int) -> void:
	for _t in n:
		var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
		ms.advance(intents)
		ms.drain_signals()
