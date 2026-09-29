extends TestCase

## STORY 6-5e: ROCKSLING, THE BOULDER, BOOM AND CORPSE BOMB -- the state-layer coverage for AC 1a, 7-19,
## 20-24, 25-28a, 29-34, 36-38, 40 and the two S1/M1/M2 measurements.
##
## ONE FILE RATHER THAN THE FOUR TASK 11 NAMES (`test_rocksling.gd`, `test_boulder.gd`, `test_boom.gd`,
## `test_corpse_bomb.gd`), and the deviation is recorded in the Dev Agent Record with this reason: all four
## need the SAME ~200-line fixture -- a match with Rocksling as a Mode ① effect, a Boulder card injected
## into the cost and effect maps, a stageable pitch effect and two kinds on the board -- and four copies of
## it would be four things to keep in agreement. `test_fireball.gd` is the shape this borrows; the sections
## below are the four files' contents, each headed by the ACs it covers.
##
## THE FIXTURE INJECTS BOULDER INTO THE LIVE MAPS ON PURPOSE (AC 16). `MatchState._boulder_card_id` is
## DERIVED by scanning the injected basic-effect map for the cover-clearing effect, and a Mode ① press on a
## covered slot prices through `_card_costs` -- so a fixture that injected only deck ids would plant nothing
## and every placement assertion below would pass vacuously on a no-op. The `boulder` entry in `_costs()`
## and `_basic_effects()` is therefore load-bearing, and
## `test_a_fixture_with_no_authored_boulder_plants_nothing` is the control that proves it.

const SEED := 6565
const DECK_SIZE := 8
const HAND_SIZE := 4
const CAST_COST := 4.0
const BOULDER_COST := 2.0
const PITCH_MINIMUM := 3.0
const MAX_MANA := 40.0
const PITCH_ORBS := 1
const PITCH_COLOR := Enums.CardColor.RED
const TIMER_TICKS := 30
const DELAY_TICKS := 3
const CAST_TICKS := 6
const INTERVAL_TICKS := 4
const STONES := 3
const STONE_DAMAGE := 3.0
const BOOM_DAMAGE := 6.0
const SKULL_DAMAGE := 5.0
const MAX_ORBS := 5
const CAST_SLOT := 2
const STAGE_SLOT := 2
const MAX_HP := 100.0
const UNIT_HP := 40.0
const STAMINA := 50.0
const BLOCK_MULTIPLIER := 0.5
const DEFLECT_COST := 5.0
const BUDGET := 60.0
const LAUNCH_SPEED := 8.0
const WALK_SPEED := 2.0
const SLOW_PER_BOULDER := 0.15

const ROCKSLING := &"rocksling"
const BOOM := &"boom"
const CORPSE_BOMB := &"corpse_bomb"
const BOULDER_EFFECT := &"boulder_discard"
const BOULDER_CARD := &"boulder"
const MINION_KIND := &"minion"
const TOTEM_KIND := &"combat_totem"


# ------------------------------------------------------------------ AC 1a: the widened mirror

## AC 1a: a Mode ① (BASIC) effect's flight profile resolves. Before this story the mirror was built from
## `_pitch_effects` alone, so a Rocksling stone read a NULL profile and `_advance_projectiles` consumed it
## on its first tick -- no launch speed, no homing, no budget. Asserted through the shot's own speed, which
## is the number the null profile would have made zero.
func test_a_basic_effects_flight_profile_reaches_the_one_reader() -> void:
	var ms := _in_flight()
	var profile := ms.projectile_profile_at(ms.p1.projectiles, 0)
	assert_not_null(profile,
		"a Mode (1) effect's shot resolves a profile -- the mirror covers the BASIC map (AC 1a)")
	assert_eq(profile.launch_speed, LAUNCH_SPEED, "...the authored launch speed")
	assert_eq(profile.travel_budget, BUDGET, "...and the authored budget")
	assert_true(ms.projectile_speed_at(ms.p1.projectiles, 0) > 0.0,
		"the stone actually moves -- a null profile would have consumed it on its first tick")


## AC 1a: the collision refusal, NARROWED to what is actually ambiguous -- two entries under one effect id
## carrying DIFFERENT mirrored values. The same object in both maps, and two objects with the same numbers,
## are both legal (measured: the literal reading failed 17 existing tests, the identity reading failed as
## many again -- both recorded in the Dev Agent Record).
func test_two_entries_under_one_id_with_different_flight_are_refused() -> void:
	var basic := CardEffect.new()
	basic.effect_id = ROCKSLING
	basic.launch_speed = LAUNCH_SPEED
	var pitch := CardEffect.new()
	pitch.effect_id = ROCKSLING
	pitch.launch_speed = LAUNCH_SPEED * 2.0
	assert_false(_mirror_accepts(basic, pitch),
		"two entries under one id with DIFFERENT launch speeds are refused (AC 1a)")
	var twin := CardEffect.new()
	twin.effect_id = ROCKSLING
	twin.launch_speed = LAUNCH_SPEED
	assert_true(_mirror_accepts(basic, twin),
		"...and two entries carrying the SAME mirrored values are legal -- an effect may be reachable "
		+ "in two modes, which is what the shipped data and every fixture already do")
	assert_true(_mirror_accepts(basic, basic),
		"...as is the very same object in both maps")


## AC 1a, the second half of the narrowing: `boulders_per_cast` is mirrored too (the contact ladder reads it
## through the effect-id handle), so a disagreement there is ambiguous exactly as a flight number is.
func test_a_disagreeing_burst_count_is_refused_like_a_disagreeing_flight_number() -> void:
	var three := CardEffect.new()
	three.effect_id = ROCKSLING
	three.boulders_per_cast = 3
	var one := CardEffect.new()
	one.effect_id = ROCKSLING
	one.boulders_per_cast = 1
	assert_false(_mirror_accepts(three, one),
		"`boulders_per_cast` is part of the mirrored set -- it decides whether a landing plants (AC 16)")


## AC 1a, added at the review fix (minor 2): THE COLLISION PREDICATE GUARDS FIELDS WHILE ITS READER HANDS
## BACK AN OBJECT, and until now nothing enforced the gap. `_mirrored_values_agree` compares seven NAMED
## fields; `_shot_effect_of` returns the WHOLE `CardEffect` to the contact ladder, so a later story reading
## an EIGHTH field through that handle would sit outside the comparison silently -- which is exactly the
## ambiguity AC 1a exists to prevent, one field along. The code comment states the obligation ("If a later
## story routes another field through an effect-id lookup, it belongs in this comparison in the same edit");
## this makes it a guard instead of a note.
##
## BOTH SIDES ARE SOURCE-SCANNED rather than transcribed, so neither can drift from the other: the compared
## set is read out of `_mirrored_values_agree`'s own body, and the read set out of every field access on a
## variable that `_shot_effect_of` was assigned into. `3-0d/R20`'s posture -- a mechanism, not a list.
func test_every_field_read_through_the_effect_id_handle_is_in_the_mirrored_set() -> void:
	var lines := _source_lines("res://src/state/match_state.gd")
	var mirrored := _fields_compared_by_the_mirror_predicate(lines)
	assert_true(mirrored.has("boulders_per_cast") and mirrored.has("launch_speed"),
		"sanity: the compared set really was scanned out of `_mirrored_values_agree` (found %s)"
				% ", ".join(mirrored))
	assert_eq(mirrored.size(), 7,
		"sanity: the seven fields the two mirrors carry -- six flight, plus `boulders_per_cast`")
	var handles := _handles_assigned_from(lines, "_shot_effect_of")
	assert_true(handles.size() > 0,
		"sanity: `_shot_effect_of`'s return is assigned somewhere -- a rename un-guards this test")
	var outside: Array[String] = []
	for handle: String in handles:
		var reader := RegEx.create_from_string("\\b%s\\.([A-Za-z_][A-Za-z0-9_]*)" % handle)
		for line in lines:
			for m: RegExMatch in reader.search_all(line):
				var field := m.get_string(1)
				if not mirrored.has(field) and not outside.has(field):
					outside.append(field)
	assert_eq(outside.size(), 0,
		("a field is read through the EFFECT-ID handle but is NOT in `_mirrored_values_agree`'s "
			+ "comparison, so two entries under one id could disagree on it silently (AC 1a): %s")
					% ", ".join(outside))


# ------------------------------------------------------- AC 7-11a: the cast and the committed burst

## AC 8: exactly `boulders_per_cast` stones, one per authored interval, each its own hero-sourced record
## carrying the burst's one captured address and the authored per-stone damage.
func test_the_cast_fires_the_authored_stones_at_the_authored_interval() -> void:
	var ms := _cast_rocksling()
	assert_eq(ms.p1.projectiles.size(), 0, "nothing launches during the cast")
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p1.projectiles.size(), 1, "stone 1 leaves AT the strike")
	assert_eq(ms.p1.burst_remaining, STONES - 1, "...and the rest are owed")
	# One tick short of the interval: still nothing.
	_idle(ms, INTERVAL_TICKS - 1)
	assert_eq(ms.p1.projectiles.size(), 1, "no stone before the interval has elapsed")
	_idle(ms, 1)
	assert_eq(ms.p1.projectiles.size(), 2, "stone 2 leaves exactly one interval later")
	_idle(ms, INTERVAL_TICKS)
	assert_eq(ms.p1.projectiles.size(), STONES, "and stone 3 one interval after that")
	assert_false(ms.p1.has_pending_burst(), "the burst is over -- nothing is owed")
	_idle(ms, INTERVAL_TICKS * 3)
	assert_eq(ms.p1.projectiles.size(), STONES, "and no fourth stone ever appears")
	for shot in STONES:
		assert_true(ms.p1.projectiles.is_hero_sourced_at(shot),
			"stone %d is a hero-sourced record (AC 8)" % shot)
		assert_eq(ms.p1.projectiles.effect_id_at(shot), String(ROCKSLING), "...authored by Rocksling")
		assert_eq(ms.p1.projectiles.damage_at(shot), STONE_DAMAGE, "...at the authored per-stone damage")
		assert_eq(ms.p1.projectiles.target_slot_at(shot), 1, "...aimed at the captured slot")
		assert_eq(ms.p1.projectiles.target_index_at(shot), TargetingService.HERO_INDEX,
			"...and the captured index")


## AC 7: a STUN during the cast interrupts it -- no stone fires, and the card and mana stay spent. The
## 6-5c/6-5d cast contract, unchanged and not re-implemented; asserted here because AC 7 names it.
func test_a_stun_during_the_cast_fires_nothing() -> void:
	var ms := _cast_rocksling()
	var mana_after_press := ms.p1.mana.get_current()
	ms.p1.hero.start_stun(20, false)
	ms.p1.hero.set_action_state(HeroState.ActionState.STUNNED)
	_idle(ms, CAST_TICKS + INTERVAL_TICKS * STONES + 2)
	assert_eq(ms.p1.projectiles.size(), 0, "a stunned caster fires NO stone (AC 7)")
	assert_false(ms.p1.has_pending_burst(), "...and no burst is owed")
	assert_eq(ms.p1.mana.get_current(), mana_after_press, "...and nothing is refunded")


## AC 7: an ORDINARY HIT does not interrupt -- the cast strikes on schedule. The negative control for the
## test above, without which "a stun interrupts" could be passing because ANY damage interrupted.
func test_an_ordinary_hit_during_the_cast_does_not_interrupt_it() -> void:
	var ms := _cast_rocksling()
	ms.p1.hero.take_damage(10.0)
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p1.projectiles.size(), 1, "an ordinary hit leaves the cast running (AC 7)")


## AC 9: the target is captured at the PRESS. A re-lock mid-cast and an unlock mid-burst both change
## nothing -- neither what is already in flight nor what is still to launch.
func test_the_captured_target_survives_a_relock_and_an_unlock() -> void:
	var ms := _make_match()
	ms.p1.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	_advance(ms, _cast_intent(CAST_SLOT), InputIntent.new())
	# Re-point the LIVE lock at this player's own minion mid-cast. The captured copy must not follow.
	ms.p1.lock_target_slot = 0
	ms.p1.lock_target_index = 0
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p1.projectiles.target_slot_at(0), 1, "stone 1 keeps the CAPTURED slot (AC 9)")
	# Now clear the lock entirely, mid-burst, and let the remaining stones launch.
	ms.p1.lock_target_slot = PlayerState.UNLOCKED_SLOT
	ms.p1.lock_target_index = TargetingService.HERO_INDEX
	_idle(ms, INTERVAL_TICKS * STONES)
	assert_eq(ms.p1.projectiles.size(), STONES, "every stone still launched")
	for shot in STONES:
		assert_eq(ms.p1.projectiles.target_slot_at(shot), 1,
			"stone %d keeps the burst's ONE captured address (AC 9)" % shot)


## AC 10: a stone whose captured target died before its own scheduled launch is STILL placed and launched --
## Fireball's own dead-target decision (6-5d AC 22), one tick later. It homes on nothing and hits nothing.
func test_a_stone_launched_at_an_already_dead_target_still_flies_and_homes_on_nothing() -> void:
	var ms := _cast_rocksling()
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p1.projectiles.size(), 1, "sanity: stone 1 is away")
	# Kill the captured target between stone 1 and stone 2. The round-over freeze would stop step 6d, so
	# the minion arm is used instead: retarget the burst at a minion and kill THAT.
	ms.p1.clear_burst()
	ms.p2.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	ms.p1.start_burst(ROCKSLING, 1, 0, 1, 0, STONE_DAMAGE)
	ms.p2.units.kill_at(0, 10)
	assert_false(ms.p2.units.is_alive_at(0), "sanity: the captured target is dead")
	_idle(ms, 1)
	assert_eq(ms.p1.projectiles.size(), 2, "the stone is STILL placed and launched (AC 10)")
	assert_eq(ms.p1.projectiles.target_index_at(1), 0, "...at the dead address, never re-acquired")
	# THE HOMING ENDS ON THE NEXT TICK, NOT THE LAUNCH TICK, and the one-tick lag is the step order rather
	# than a defect: the dead-target rung lives in `_advance_projectiles` at step 3c, and the burst seat
	# that places the record is step 6d of the SAME advance() -- so the record does not exist yet when the
	# rung runs, and the first rung it meets is the next tick's.
	_idle(ms, 1)
	assert_false(ms.p1.projectiles.is_homing_at(1),
		"...and its homing has ended by the next tick, so it flies straight to its budget")
	assert_true(ms.p1.projectiles.is_alive_at(1), "...it is not consumed -- it expires at the budget")


## AC 11a (`6-5e/R18`/C2): once the cast completes the burst is COMMITTED. A stun landing between stones
## stops none of them, and the caster is free -- no lock, no root.
func test_a_stun_between_stones_stops_none_of_them() -> void:
	var ms := _cast_rocksling()
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p1.projectiles.size(), 1, "sanity: stone 1 is away")
	ms.p1.hero.start_stun(200, false)
	ms.p1.hero.set_action_state(HeroState.ActionState.STUNNED)
	_idle(ms, INTERVAL_TICKS * STONES)
	assert_eq(ms.p1.projectiles.size(), STONES,
		"every remaining stone launched THROUGH the stun (AC 11a) -- the burst is committed")
	assert_false(ms.p1.is_casting(),
		"...and the caster is not casting: ruling 1's lock covers the CAST, not the burst")


## AC 11a, added at the review fix (minor 6): THE POSITIVE HALF OF "the caster is free to move and act".
## The test above asserts only `assert_false(is_casting())`, which is the absence of the cast lock and not
## the presence of freedom. Here the caster actually MOVES and actually SWINGS mid-burst, and the stones
## still arrive on schedule -- so "free" is measured rather than inferred from a negative.
func test_the_caster_moves_and_swings_mid_burst_and_every_stone_still_launches() -> void:
	var ms := _cast_rocksling()
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p1.projectiles.size(), 1, "sanity: stone 1 is away and two are owed")
	var move := InputIntent.new()
	move.move_dir = Vector2(1.0, 0.0)
	move.pressed[&"attack"] = true
	move.held[&"attack"] = true
	_advance(ms, move, InputIntent.new())
	assert_true(ms.p1.hero.velocity.length() > 0.0 \
			or ms.p1.hero.action_state == HeroState.ActionState.ATTACKING,
		"the caster ACTED mid-burst -- the press was not refused and the move was not rooted (AC 11a)")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ATTACKING,
		"...specifically: the swing was accepted while stones were still owed")
	_idle(ms, INTERVAL_TICKS * STONES)
	assert_eq(ms.p1.projectiles.size(), STONES,
		"...and every remaining stone launched anyway -- acting does not cancel a committed burst (AC 11a)")


## AC 11a: the THREE cancellations -- caster death, round end, debug reset. Each stops every stone not yet
## launched, and no further stone fires after any of them.
## STRENGTHENED AFTER A GREEN MUTANT, and both states are recorded because the first version was a test
## that could not fail. It killed the caster and advanced ONE tick -- but the interval had three ticks left,
## so no launch was due, and the burst was cleared by ROUND END (`_end_round`, which the caster's own death
## triggers at step 8) rather than by the death branch in `_advance_bursts`. Removing that branch entirely
## left the test GREEN.
##
## THE REACHABLE CASE IS THE KILL TICK ITSELF, and it is the only one: `_end_round` runs at step 8, AFTER
## step 6d, so on the tick the caster's hp reaches zero the burst seat still runs with `_round_over` false.
## Every LATER tick returns at step 1b and never reaches the seat at all. So the test now arranges for the
## launch to fall due on exactly that tick -- which is what the guard exists for, and what kills the mutant.
func test_caster_death_cancels_a_stone_due_on_the_kill_tick() -> void:
	var ms := _cast_rocksling()
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p1.projectiles.size(), 1, "sanity: stone 1 is away and two are owed")
	# One tick short of the next launch, so the NEXT advance is the launch tick.
	_idle(ms, INTERVAL_TICKS - 1)
	assert_eq(ms.p1.projectiles.size(), 1, "sanity: no stone yet -- the next tick is the due one")
	# ONE TICK LEFT, not a stopped window: step 2 of the NEXT advance is what empties the interval, and
	# step 6d of that same advance is the launch. So "the launch is due next tick" is `remaining == 1`.
	assert_eq(ms.p1.burst_window.remaining_ticks(), 1,
		"sanity: the interval empties on the next tick, so that tick's step 6d is the launch")
	ms.p1.hero.take_damage(MAX_HP)
	_idle(ms, 1)
	assert_eq(ms.p1.projectiles.size(), 1,
		"a stone DUE on the kill tick does not fire -- the dead-caster branch stops it (AC 11a)")
	assert_false(ms.p1.has_pending_burst(), "...and the burst is cancelled")


func test_round_end_cancels_every_stone_not_yet_launched() -> void:
	var ms := _cast_rocksling()
	_idle(ms, CAST_TICKS)
	ms.p2.hero.take_damage(MAX_HP)
	_idle(ms, 1)
	assert_false(ms.p1.has_pending_burst(), "round end cancels the burst (AC 11a)")
	_idle(ms, INTERVAL_TICKS * STONES)
	assert_eq(ms.p1.projectiles.size(), 1, "...and no further stone fires during the freeze")


func test_a_debug_reset_cancels_every_stone_not_yet_launched() -> void:
	var ms := _cast_rocksling()
	_idle(ms, CAST_TICKS)
	_advance(ms, _reset_intent(), InputIntent.new())
	assert_false(ms.p1.has_pending_burst(), "the debug reset cancels the burst (AC 11a)")
	assert_eq(ms.p1.projectiles.size(), 0, "...and clears the board it launched onto")
	_idle(ms, INTERVAL_TICKS * STONES)
	assert_eq(ms.p1.projectiles.size(), 0, "...with no further stone after it")


## AC 11a / AC 38 (`6-5e/R21`/G2): the pending-burst schedule is HASHED. Resting reads as no burst; a
## mid-burst tick reads the live schedule; and the hash MOVES between the two, which is what makes the key
## load-bearing rather than decorative.
func test_the_pending_burst_is_hashed_and_rests_empty() -> void:
	var ms := _make_match()
	var resting: Array = ms.p1.to_snapshot()["burst"]
	assert_eq(resting, ["", 0, 0, TargetingService.NO_TARGET_SLOT,
			TargetingService.HERO_INDEX, 0.0],
		"at rest the burst key is every element's own resting value (AC 38, cause 1a)")
	var idle_hash := CanonicalHash.of(ms.to_snapshot())
	_advance(ms, _cast_intent(CAST_SLOT), InputIntent.new())
	_idle(ms, CAST_TICKS)
	var mid: Array = ms.p1.to_snapshot()["burst"]
	assert_eq(mid[0], String(ROCKSLING), "mid-burst the key names the effect still throwing")
	assert_eq(mid[1], STONES - 1, "...how many stones are still owed")
	assert_eq(mid[2], INTERVAL_TICKS, "...and how long until the next one")
	assert_ne(CanonicalHash.of(ms.to_snapshot()), idle_hash,
		"a pending burst moves the hash -- the key decides outcomes across ticks (`4-3a/R17`)")


# ------------------------------------------------- AC 12-19: defence and Boulder placement

## AC 12 / AC 16: a BLOCKING hero takes FULL, unmitigated stone damage and STILL receives a Boulder.
## The block exemption is 6-5d's existing `is_hero_sourced_at` rung, which a stone inherits by being a
## hero-sourced record -- so this test is what proves the inheritance rather than a new rung.
func test_a_blocking_hero_takes_full_stone_damage_and_still_gets_a_boulder() -> void:
	var ms := _in_flight()
	# THE STATE IS ESTABLISHED FIRST AND HELD THROUGH THE RESOLVING TICK, and both halves are required:
	# without the `set_action_state` the hero is not BLOCKING when step 4 reads it, and without the held
	# intent step 3 releases the block before the ladder sees it. The first version of this test had
	# NEITHER and passed -- a full-damage unblocked hit on a hero that never blocked at all, which is
	# exactly the false green `test_fireball.gd::_land` warns about. The fixture assertion below is what
	# makes it impossible to pass that way again.
	ms.p2.hero.set_action_state(HeroState.ActionState.BLOCKING)
	var hits := _hits(ms)
	var hp_before := ms.p2.hero.get_hp()
	_land(ms, true, _block_intent())
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.BLOCKING,
		"fixture: the target really WAS blocking when the stone resolved")
	assert_eq(hp_before - ms.p2.hero.get_hp(), STONE_DAMAGE,
		"a blocking hero takes the FULL stone damage -- no block multiplier (AC 12)")
	assert_eq(hits.size(), 1, "one hit landed")
	assert_false(hits[0][3], "...and it is NOT recorded as blocked -- the block did nothing")
	assert_eq(ms.p2.hand.cover_count(), 1, "...and a Boulder is still planted (AC 16)")


## AC 12, THE OTHER HALF, added at the review fix (minor 10): "whether or not the blocking hero FACES the
## stone". The test above measures the facing half; this one measures the NON-FACING half, which is the
## reading that could have differed -- a block that only fails to mitigate while facing would still be a
## block multiplier applied from behind. Same fixture, `facing = false` on the pushed contact.
func test_a_blocking_hero_facing_away_also_takes_full_stone_damage() -> void:
	var ms := _in_flight()
	ms.p2.hero.set_action_state(HeroState.ActionState.BLOCKING)
	var hits := _hits(ms)
	var hp_before := ms.p2.hero.get_hp()
	_land(ms, false, _block_intent())
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.BLOCKING,
		"fixture: the target really WAS blocking when the stone resolved")
	assert_eq(hp_before - ms.p2.hero.get_hp(), STONE_DAMAGE,
		"a blocking hero struck from BEHIND still takes the FULL stone damage (AC 12)")
	assert_eq(hits.size(), 1, "one hit landed")
	assert_false(hits[0][3], "...and it is not recorded as blocked from that side either")
	assert_eq(ms.p2.hand.cover_count(), 1, "...and a Boulder is still planted (AC 16)")


## AC 13: a DEFLECT fully cancels -- no damage, no `hit_landed`, NO BOULDER, and the deflect is announced.
func test_a_deflected_stone_deals_nothing_and_plants_nothing() -> void:
	var ms := _in_flight()
	var hits := _hits(ms)
	var deflects := _deflects(ms)
	var hp_before := ms.p2.hero.get_hp()
	# A PERFECT deflect: BLOCKING, facing, the window OPEN, and the stamina to pay -- the four conditions
	# the ladder reads, armed explicitly so this differs from the block case above by the WINDOW alone.
	ms.p2.hero.set_action_state(HeroState.ActionState.BLOCKING)
	ms.p2.hero.deflect.start(10)
	_land(ms, true, _block_intent())
	assert_eq(deflects.size(), 1, "the deflect is announced (AC 13)")
	assert_eq(hits.size(), 0, "...no hit_landed")
	assert_eq(ms.p2.hero.get_hp(), hp_before, "...no damage")
	assert_eq(ms.p2.hand.cover_count(), 0, "...and NO Boulder is planted (AC 13)")
	assert_false(ms.p1.projectiles.is_alive_at(0), "...and the stone is consumed")
	# AC 13's LAST CLAUSE, added at the review fix (minor 9): "the caster is not stunned by the deflect".
	# A melee deflect stuns the attacker; a deflected PROJECTILE has no attacker standing there to stun, so
	# the clause is true by the ladder not reaching a stun write at all -- which is worth one assertion
	# rather than an argument, because it is the one half of AC 13 nothing else in this file measures.
	assert_false(ms.p1.hero.stun.is_running, "...and the CASTER is not stunned by the deflect (AC 13)")
	assert_ne(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "...nor left in a stunned state")


## AC 14: an i-frame drop is NOT a hit -- no damage, no Boulder, the stone survives, and its homing ends.
func test_an_iframed_stone_is_not_consumed_and_plants_nothing() -> void:
	var ms := _in_flight()
	var hp_before := ms.p2.hero.get_hp()
	ms.p2.hero.roll_iframe.start(30)
	_land(ms)
	assert_eq(ms.p2.hero.get_hp(), hp_before, "an i-framed stone deals nothing (AC 14)")
	assert_eq(ms.p2.hand.cover_count(), 0, "...plants nothing")
	assert_true(ms.p1.projectiles.is_alive_at(0), "...is NOT consumed")
	assert_false(ms.p1.projectiles.is_homing_at(0), "...and its homing ends on that tick")


## AC 15 / AC 11: a stone whose captured target IS a unit deals damage only and plants nothing -- Boulders
## exist only in a hero's hand. A unit target also proves the pass-through rung is not what suppressed it.
func test_a_stone_on_a_unit_target_damages_only_and_plants_no_boulder() -> void:
	var ms := _make_match()
	ms.p2.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = 0
	_advance(ms, _cast_intent(CAST_SLOT), InputIntent.new())
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p1.projectiles.target_index_at(0), 0, "sanity: the stone is aimed at the minion")
	var hp_before := ms.p2.units.hp_at(0)
	_land(ms)
	assert_eq(hp_before - ms.p2.units.hp_at(0), STONE_DAMAGE, "the unit takes the stone damage (AC 15)")
	assert_eq(ms.p2.hand.cover_count(), 0, "...and NO Boulder is planted (AC 15)")


## AC 16: the slot is drawn from the match's ONE seeded RNG. DETERMINISTIC across two runs of one seed, and
## PROVABLY not a constant: over a set of seeds the pick lands on more than one slot.
func test_the_boulder_slot_is_seeded_deterministic_and_not_a_constant() -> void:
	assert_eq(_planted_slot(SEED), _planted_slot(SEED),
		"one seed plants in the same slot every run (AC 16) -- the pick is the seeded stream's")
	var seen := {}
	for seed_value in [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233]:
		seen[_planted_slot(seed_value)] = true
	assert_true(seen.size() > 1,
		"different seeds reach different slots -- the pick is a real draw, not a fixed slot (AC 16)")
	for slot: int in seen:
		assert_true(slot >= 0 and slot < HAND_SIZE, "...and every pick is inside the hand's width")


## AC 17 / AC 17a: the covered card is UNPLAYABLE in every mode but ①, through its own new named refusal,
## with nothing spent -- and it stays in its own slot, unmoved, for as long as it is covered.
func test_a_covered_card_is_refused_in_every_other_mode_and_stays_put() -> void:
	var ms := _planted()
	var slot := ms.p2.hand.covered_indices()[0]
	var beneath := ms.p2.hand.to_array()[slot]
	var mana_before := ms.p2.mana.get_current()
	for mode: int in [Enums.ModeKind.UNBLOCKABLE, Enums.ModeKind.DEFENSE, Enums.ModeKind.PITCH]:
		var rejections := _rejections(ms.p2)
		var intent := InputIntent.new()
		intent.card_slot = slot
		intent.card_mode = mode
		intent.card_commit = true
		_advance(ms, InputIntent.new(), intent)
		assert_eq(rejections, [[&"card_cast", MatchState.REASON_COVERED_SLOT]],
			"mode %d on a covered slot is refused through its own named reason (AC 17a)" % mode)
	assert_eq(ms.p2.mana.get_current(), mana_before, "nothing was spent on any refusal (AC 17a)")
	assert_eq(ms.p2.hand.to_array()[slot], beneath,
		"the covered card is still in its OWN slot, unmoved (AC 17)")
	assert_eq(ms.p2.pending_draw_owed, [] as Array[int], "and nothing was owed")


## AC 18: a Boulder planted on a mid-draw-delay HOLE occupies it directly, and the owed replacement lands
## UNDERNEATH -- covered and unplayable -- rather than being blocked or redirected.
func test_a_boulder_on_a_hole_is_covered_directly_and_the_refill_lands_underneath() -> void:
	var ms := _in_flight()
	# Open a hole on P2 by casting from one of its slots; the replacement is owed for DELAY_TICKS.
	_advance(ms, InputIntent.new(), _cast_intent(0))
	assert_true(ms.p2.hand.is_slot_empty(0), "sanity: slot 0 is a hole with a refill owed")
	assert_eq(ms.p2.pending_draw_owed, [0] as Array[int], "sanity: owed for slot 0")
	# Cover every OTHER slot so the seeded pick has exactly the hole left.
	for other in [1, 2, 3]:
		ms.p2.hand.cover_at(other, BOULDER_CARD)
	_land(ms)
	assert_true(ms.p2.hand.is_covered(0), "the Boulder occupies the EMPTY slot directly (AC 18)")
	assert_true(ms.p2.hand.is_slot_empty(0), "...and the card layer is still empty")
	_idle(ms, DELAY_TICKS + 1)
	assert_false(ms.p2.hand.is_slot_empty(0), "the owed replacement landed (AC 18)")
	assert_true(ms.p2.hand.is_covered(0), "...UNDERNEATH the Boulder, which still covers the slot")
	assert_eq(ms.p2.hand.visible_id_at(0), BOULDER_CARD, "...so the visible layer is still the Boulder")


## AC 19: no eligible slot is a SUCCESSFUL hit with nowhere to plant -- the damage lands, nothing else
## happens, and no refusal cue fires. NO RNG IS DRAWN either, which is what keeps a replay in step.
func test_no_eligible_slot_deals_the_damage_only() -> void:
	var ms := _in_flight()
	for slot in HAND_SIZE:
		ms.p2.hand.cover_at(slot, BOULDER_CARD)
	var rejections := _rejections(ms.p2)
	var rng_before := ms.p1.to_snapshot()  # unused sentinel; the real read is below
	var state_before := ms._rng.state
	var hp_before := ms.p2.hero.get_hp()
	_land(ms)
	assert_eq(hp_before - ms.p2.hero.get_hp(), STONE_DAMAGE, "the damage still lands (AC 19)")
	assert_eq(ms.p2.hand.cover_count(), HAND_SIZE, "...no further Boulder is planted")
	assert_eq(rejections, [], "...and this is NOT a refusal -- no cue fires (AC 19)")
	assert_eq(ms._rng.state, state_before,
		"...and NO RNG is drawn, so an unplantable hit cannot desynchronise a replay")
	assert_true(rng_before.has("hand_covered"), "sanity: the cover mask is a snapshot key")


## AC 16 / AC 19 (`6-5e/R20`/G1): the STRUCK player's own staged pitch slot is NOT eligible -- and it is the
## struck player's, not the caster's. With every other slot covered, a landing plants nothing.
func test_the_struck_players_own_staged_slot_is_not_eligible() -> void:
	var ms := _in_flight()
	# P2 stages from slot 1. The zone holds the card and slot 1 is left empty and RESERVED -- no owed
	# refill -- which is the one case clause (b) protects.
	_advance(ms, InputIntent.new(), _stage_intent(1))
	assert_true(ms.pitch.is_staged(1), "sanity: P2 has a card staged")
	assert_eq(ms.pitch.staged_hand_slot(1), 1, "sanity: from slot 1")
	for other in [0, 2, 3]:
		ms.p2.hand.cover_at(other, BOULDER_CARD)
	_land(ms)
	assert_false(ms.p2.hand.is_covered(1),
		"the struck player's OWN staged originating slot is not eligible (AC 16, `6-5e/R20`)")
	assert_eq(ms.p2.hand.cover_count(), 3, "...so nothing was planted at all (AC 19)")


## The CONTROL for the whole placement section: with no Boulder authored anywhere, a landed stone plants
## nothing and nothing crashes. Without this, every placement assertion above could be passing against a
## fixture that silently planted nothing.
func test_a_fixture_with_no_authored_boulder_plants_nothing() -> void:
	var ms := _in_flight(_basic_effects_without_boulder())
	var hp_before := ms.p2.hero.get_hp()
	_land(ms)
	assert_eq(hp_before - ms.p2.hero.get_hp(), STONE_DAMAGE, "the hit still lands")
	assert_eq(ms.p2.hand.cover_count(), 0, "...and nothing is planted, honestly and without a crash")


# ----------------------------------------------------------------- AC 20-24: the Boulder card

## AC 20 / AC 21 / AC 21a: playing a Boulder costs its authored 2 mana, lifts the cover, makes the card
## beneath immediately playable in the SAME slot, owes NO replacement, engages NO draw delay, and puts
## nothing in the discard. It takes no cast frame -- it resolves on the press tick.
func test_playing_a_boulder_uncovers_in_place_and_owes_nothing() -> void:
	var ms := _planted()
	var slot := ms.p2.hand.covered_indices()[0]
	var beneath := ms.p2.hand.to_array()[slot]
	var mana_before := ms.p2.mana.get_current()
	var discard_before := ms.p2.discard.size()
	_advance(ms, InputIntent.new(), _cast_intent(slot))
	assert_false(ms.p2.hand.is_covered(slot), "the Boulder is gone (AC 21)")
	assert_eq(ms.p2.mana.get_current(), mana_before - BOULDER_COST, "...for its authored 2 mana")
	assert_eq(ms.p2.hand.to_array()[slot], beneath,
		"...and the card beneath is available in that SAME slot, unmoved (AC 21)")
	assert_eq(ms.p2.hand.visible_id_at(slot), beneath, "...and is what the slot now shows")
	assert_eq(ms.p2.pending_draw_owed, [] as Array[int], "NO replacement is owed (AC 21)")
	assert_false(ms.p2.pending_draw.is_running, "...and no draw delay is engaged")
	assert_eq(ms.p2.discard.size(), discard_before, "a Boulder is never discarded (AC 22)")
	assert_false(ms.p2.is_casting(), "and it took no cast frame -- it resolved on the press (AC 21a)")


## AC 21a: pressed without the mana it is refused exactly like any other unaffordable card -- nothing
## spent, the Boulder and the covered card both unchanged.
func test_an_unaffordable_boulder_is_refused_with_insufficient_mana() -> void:
	var ms := _planted()
	var slot := ms.p2.hand.covered_indices()[0]
	ms.p2.mana.spend(ms.p2.mana.get_current())
	var rejections := _rejections(ms.p2)
	_advance(ms, InputIntent.new(), _cast_intent(slot))
	assert_eq(rejections, [[&"card_cast", CastEvaluator.REASON_INSUFFICIENT_MANA]],
		"an unaffordable Boulder is refused through the ordinary reason (AC 21a)")
	assert_true(ms.p2.hand.is_covered(slot), "...and the Boulder is unchanged")
	assert_eq(ms.p2.mana.get_current(), 0.0, "...with nothing spent")


## AC 22: Boulder enters a hand ONLY as the consequence of a landed stone. It is in no deck, is never
## dealt, never drawn and never discarded -- proven over a whole match rather than by the deck list alone.
func test_a_boulder_never_reaches_a_deck_a_deal_or_a_discard() -> void:
	var ms := _make_match()
	assert_false(_deck_contents().has(BOULDER_CARD), "Boulder is in no deck composition (AC 22)")
	assert_false(ms.p1.hand.to_array().has(BOULDER_CARD), "...is not dealt into a hand")
	assert_false(ms.p1.deck.to_array().has(BOULDER_CARD), "...is not in the deck after the deal")
	var ms2 := _planted()
	var slot := ms2.p2.hand.covered_indices()[0]
	_advance(ms2, InputIntent.new(), _cast_intent(slot))
	assert_false(ms2.p2.discard.to_array().has(BOULDER_CARD),
		"...and a PLAYED Boulder does not reach the discard pile either (AC 22)")
	assert_false(ms2.p2.hand.to_array().has(BOULDER_CARD), "...nor the card layer of the hand")


## AC 23: round end and the debug reset each remove EVERY Boulder, restoring every covered card to normal
## playable status in its own slot, unmoved.
func test_round_end_removes_every_boulder_and_restores_every_card() -> void:
	var ms := _planted()
	var slot := ms.p2.hand.covered_indices()[0]
	var beneath := ms.p2.hand.to_array()[slot]
	ms.p1.hero.take_damage(MAX_HP)
	_idle(ms, 1)
	assert_eq(ms.p2.hand.cover_count(), 0, "round end removes every Boulder (AC 23)")
	assert_eq(ms.p2.hand.to_array()[slot], beneath, "...with the card beneath in its own slot, unmoved")


func test_a_debug_reset_removes_every_boulder() -> void:
	var ms := _planted()
	_advance(ms, _reset_intent(), InputIntent.new())
	assert_eq(ms.p2.hand.cover_count(), 0, "the debug reset removes every Boulder (AC 23)")


## AC 24: the ONLY channel is `cards_changed`, per player, and it carries the VISIBLE layer -- so a covered
## slot announces the Boulder and never the card beneath it. No new seam and no widened payload.
func test_the_cover_rides_the_existing_per_player_cards_changed_channel() -> void:
	var ms := _in_flight()
	var p1_payloads := _cards_changed(ms.p1)
	var p2_payloads := _cards_changed(ms.p2)
	_land(ms)
	assert_eq(p1_payloads.size(), 0, "the CASTER's hand did not change, so it announced nothing (AC 24)")
	assert_eq(p2_payloads.size(), 1, "the STRUCK player announced once, on its own channel")
	var ids: Array = p2_payloads[0][0]
	var slot := ms.p2.hand.covered_indices()[0]
	assert_eq(ids[slot], BOULDER_CARD,
		"the payload shows the BOULDER at the covered slot, never the card beneath (AC 24a)")
	assert_eq(ids.size(), HAND_SIZE, "...and is still the full-width view, arity unchanged (AC 24)")


# ---------------------------------------------------------------------- M1 / M2: measurements

## M2, MEASURED NOT ASSUMED: `hand_size` counts the CARD layer only. A covered card still counts (it never
## left the hand) and a Boulder never does (it is not a hand card, AC 22). The decisive reason is
## 3-5b's four-term conservation identity, which any other answer breaks -- asserted here too.
func test_hand_size_is_unmoved_by_a_cover_and_conservation_holds() -> void:
	var ms := _in_flight()
	var before: int = ms.p2.to_snapshot()["hand_size"]
	_land(ms)
	assert_eq(ms.p2.hand.cover_count(), 1, "sanity: a Boulder was planted")
	assert_eq(ms.p2.to_snapshot()["hand_size"], before,
		"`hand_size` is UNMOVED by a cover (M2) -- it binds to `occupied_count()`, the card layer")
	assert_eq(ms.p2.hand.occupied_count() + ms.p2.pending_draw_owed.size(), HAND_SIZE,
		"...and 3-5b's conservation identity still holds, which is why that answer was chosen")


## M1 / AC 37b: every placement is the SECOND consumer of `_rng` (`_shuffle_deck` was the only one). The
## placement advances the stream, `rng_state` moves with it, and a later reshuffle therefore produces an
## order the pre-story code would not have.
func test_a_placement_advances_the_one_seeded_rng_and_moves_rng_state() -> void:
	var ms := _in_flight()
	var state_before := ms._rng.state
	var hashed_before: int = ms.to_snapshot()["rng_state"]
	_land(ms)
	assert_eq(ms.p2.hand.cover_count(), 1, "sanity: a Boulder was planted")
	assert_ne(ms._rng.state, state_before, "the placement drew from the ONE seeded RNG (M1)")
	assert_ne(ms.to_snapshot()["rng_state"], hashed_before,
		"...and `rng_state` moves with it, so the hash sees the draw (M1, cause 5a)")


# ---------------------------------------------------------------------- S1: the Boulder slow

## AC 37a: the slow is `boulder_slow_per_boulder` per held Boulder, ADDITIVE, over walk and run and
## block-walk; three measured counts.
func test_the_boulder_slow_stacks_additively_over_one_two_and_three_boulders() -> void:
	var ms := _make_match()
	assert_eq(_walk_speed(ms), WALK_SPEED, "unslowed, the hero walks at the authored speed")
	for count in [1, 2, 3]:
		ms.p2.hand.clear_covers()
		for slot in count:
			ms.p2.hand.cover_at(slot, BOULDER_CARD)
		var expected := WALK_SPEED * (1.0 - SLOW_PER_BOULDER * float(count))
		assert_almost_eq(_walk_speed(ms), expected, 0.0001,
			"%d Boulder(s) slow the walk additively (AC 37a)" % count)


## AC 37a: `0.0` disables the slow entirely -- an explicit case, because a disabled knob that silently
## still applied would be invisible at the shipped 0.15.
func test_a_zero_per_boulder_value_disables_the_slow_entirely() -> void:
	var config := _config()
	config.boulder_slow_per_boulder = 0.0
	var ms := _make_match(null, config)
	for slot in 3:
		ms.p2.hand.cover_at(slot, BOULDER_CARD)
	assert_eq(_walk_speed(ms), WALK_SPEED,
		"`boulder_slow_per_boulder = 0.0` disables the slow entirely (AC 37a)")


## AC 37a, added at the review fix (minor 5): THE `state != ATTACKING` CARVE-OUT, which the AC names
## explicitly and nothing measured. It is latent at the shipped tuning -- the attack-phase move multipliers
## are authored 0.0, so an attacking hero is stationary either way -- which is exactly why a test is what
## would catch a retune that gave the attack phases movement back. Authored non-zero HERE so the carve-out
## has an observable consequence at all.
func test_the_boulder_slow_does_not_apply_while_attacking() -> void:
	var config := _config()
	config.attack_windup_move_speed_multiplier = 1.0
	config.attack_windup_seconds = 10.0 / TimingWindow.TICK_HZ
	var ms := _make_match(null, config)
	ms.p2.hand.cover_at(0, BOULDER_CARD)
	assert_almost_eq(_walk_speed(ms), WALK_SPEED * (1.0 - SLOW_PER_BOULDER), 0.0001,
		"sanity: not attacking, the held Boulder slows the walk")
	var swing := InputIntent.new()
	swing.pressed[&"attack"] = true
	swing.held[&"attack"] = true
	_advance(ms, InputIntent.new(), swing)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.ATTACKING,
		"fixture: P2 really is ATTACKING, so the carve-out is the branch under test")
	var walk := InputIntent.new()
	walk.move_dir = Vector2(1.0, 0.0)
	walk.held[&"attack"] = true
	_advance(ms, InputIntent.new(), walk)
	assert_almost_eq(ms.p2.hero.velocity.length(), WALK_SPEED, 0.0001,
		"while ATTACKING the Boulder slow does not apply -- the carve-out `RULE_FROSTBITE_SLOW` shares "
		+ "(AC 37a)")


## AC 37a, added at the review fix (minor 5): THE `maxf(0.0, ...)` CLAMP. A dev-pass addition beyond the
## ruling and the right call, but unmeasured -- at the shipped 0.15 over a 4-slot hand the product never
## reaches 1.0, so the clamp is unreachable without authoring past it. Authored past it here: the speed
## floors at zero rather than going NEGATIVE, which would have walked the holder BACKWARDS.
func test_the_boulder_slow_clamps_at_zero_rather_than_reversing() -> void:
	var config := _config()
	config.boulder_slow_per_boulder = 0.5
	var ms := _make_match(null, config)
	for slot in 3:
		ms.p2.hand.cover_at(slot, BOULDER_CARD)
	assert_true(1.0 - 0.5 * 3.0 < 0.0, "fixture: the unclamped product really is negative (-0.5)")
	assert_eq(_walk_speed(ms), 0.0,
		"three Boulders at 0.5 each clamp the walk to ZERO, never to a negative (reversed) speed (AC 37a)")


## AC 37a: the two slows COMBINE MULTIPLICATIVELY, and the Boulder slow does not ride Frostbite's timed
## seat -- it has no duration at all.
func test_the_boulder_slow_and_frostbite_combine_multiplicatively() -> void:
	var ms := _make_match()
	ms.p2.hand.cover_at(0, BOULDER_CARD)
	ms.p2.start_rule(PlayerState.RULE_FROSTBITE_SLOW, 600, 0.5, 0.0)
	var expected := WALK_SPEED * 0.5 * (1.0 - SLOW_PER_BOULDER)
	assert_almost_eq(_walk_speed(ms), expected, 0.0001,
		"Frostbite and the Boulder slow multiply (AC 37a, `6-5e/R28`)")


## AC 37a: the slow tracks the LIVE count and updates on the SAME tick as every add and remove path --
## planting, playing, Boom, round end, the debug reset. Proven through the count the gait seat reads, which
## is what makes "same tick" structural rather than five write sites to keep in sync.
func test_the_slow_follows_every_add_and_remove_path_on_the_same_tick() -> void:
	var ms := _in_flight()
	assert_eq(_walk_speed_of(ms, 1), WALK_SPEED, "before the plant, full speed")
	_land(ms)
	assert_almost_eq(_walk_speed_of(ms, 1), WALK_SPEED * (1.0 - SLOW_PER_BOULDER), 0.0001,
		"planting slows on the placement tick (AC 37a)")
	var slot := ms.p2.hand.covered_indices()[0]
	_advance(ms, InputIntent.new(), _cast_intent(slot))
	assert_eq(_walk_speed_of(ms, 1), WALK_SPEED, "playing it speeds the holder back up (AC 37a)")


# ------------------------------------------------------------------------- AC 25-28a: Boom

## AC 25 / AC 26 / AC 27: activation counts the OPPOSING hand's Boulders at that instant, deals the authored
## per-Boulder damage directly to the opposing hero, removes every counted Boulder and uncovers each card.
func test_boom_detonates_every_opposing_boulder_and_uncovers_each_card() -> void:
	var ms := _staged_boom()
	var beneath: Array[StringName] = []
	for slot in 3:
		ms.p2.hand.cover_at(slot, BOULDER_CARD)
		beneath.append(ms.p2.hand.to_array()[slot])
	var hits := _hits(ms)
	var hp_before := ms.p2.hero.get_hp()
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_eq(hp_before - ms.p2.hero.get_hp(), BOOM_DAMAGE * 3.0,
		"each counted Boulder deals the authored damage (AC 26)")
	assert_eq(hits.size(), 3, "...as three separate hits, not one summed hit")
	assert_eq(ms.p2.hand.cover_count(), 0, "every counted Boulder is removed (AC 27)")
	for slot in 3:
		assert_eq(ms.p2.hand.to_array()[slot], beneath[slot],
			"...and slot %d's card reappears in its own slot (AC 27)" % slot)
	assert_eq(ms.p2.pending_draw_owed, [] as Array[int], "...with no draw delay owed (AC 27)")
	assert_eq(ms.p1.projectiles.size(), 0, "Boom creates NO projectile (AC 26)")


## AC 26: Boom's damage is not a contact -- a ROLLING, i-framed, BLOCKING target takes it in full, because
## none of those seats is consulted at all.
func test_boom_damage_is_not_avoidable_by_iframes_or_a_block() -> void:
	var ms := _staged_boom()
	ms.p2.hand.cover_at(0, BOULDER_CARD)
	ms.p2.hero.roll_iframe.start(60)
	ms.p2.hero.set_action_state(HeroState.ActionState.BLOCKING)
	var hp_before := ms.p2.hero.get_hp()
	_advance(ms, _activate_intent(), _block_intent())
	assert_eq(hp_before - ms.p2.hero.get_hp(), BOOM_DAMAGE,
		"i-frames and a block do not reduce Boom -- it is not a contact (AC 26)")


## AC 28 (`6-5e/R27`/G8): zero Boulders refuses through the NEW board gate, BEFORE the orb spend. The card
## stays staged and READY, its countdown keeps running, and the staging mana is not refunded.
func test_boom_with_no_opposing_boulder_is_refused_before_the_orb_spend() -> void:
	var ms := _staged_boom()
	assert_eq(ms.p2.hand.cover_count(), 0, "sanity: the opposing hand is clean")
	var rejections := _rejections(ms.p1)
	var orbs_before: Dictionary = ms.p1.orbs.to_snapshot()
	var mana_before := ms.p1.mana.get_current()
	var remaining_before := _fizzle_remaining(ms)
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_OPPOSING_BOULDER]],
		"refused through its OWN named reason, not REASON_NO_TARGET (AC 28)")
	assert_eq(ms.p1.orbs.to_snapshot(), orbs_before, "...before the orb spend (AC 28)")
	assert_true(ms.pitch.is_staged(0), "...the card stays staged")
	assert_true(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags), "...and stays READY")
	assert_true(_fizzle_remaining(ms) < remaining_before, "...its countdown keeps running")
	assert_false(ms.pitch.is_expired(0), "...and has not fizzled on the refusal")
	assert_eq(ms.p1.mana.get_current(), mana_before, "...and the staging mana is not refunded")


## AC 28: the refusal reason is DISTINCT from every existing token and from the covered-slot reason -- the
## gate's own requirement, asserted rather than eyeballed.
func test_the_two_new_refusal_reasons_are_distinct_tokens() -> void:
	var tokens := [MatchState.REASON_COVERED_SLOT, MatchState.REASON_NO_OPPOSING_BOULDER,
			MatchState.REASON_NO_TARGET, MatchState.REASON_NO_OWN_MINION,
			MatchState.REASON_NO_OWN_CORPSE, MatchState.REASON_EMPTY_PITCH_ZONE,
			MatchState.REASON_PITCH_NOT_READY, MatchState.REASON_NO_PITCH_COST,
			MatchState.REASON_STUNNED, MatchState.REASON_CASTING,
			CastEvaluator.REASON_EMPTY_SLOT, CastEvaluator.REASON_INSUFFICIENT_MANA]
	var seen := {}
	for token: StringName in tokens:
		assert_false(seen.has(token),
			"refusal token %s is not a duplicate of another (AC 17a/AC 28)" % token)
		seen[token] = true
	assert_eq(seen.size(), tokens.size(), "every refusal token in this story's neighbourhood is distinct")


## AC 34: Boom's instant damage reaches the Bloodlust/Vampiric Aura funnel -- the first non-projectile seat
## the standing spell-damage rule is extended to.
func test_boom_damage_reaches_the_bloodlust_and_lifesteal_funnel() -> void:
	var ms := _staged_boom()
	ms.p2.hand.cover_at(0, BOULDER_CARD)
	ms.p1.start_rule(PlayerState.RULE_BLOODLUST, 600, 2.0, 1.0)
	ms.p1.start_rule(PlayerState.RULE_VAMPIRIC_AURA, 600, 0.5, 0.0)
	ms.p1.hero.take_damage(50.0)
	var caster_hp := ms.p1.hero.get_hp()
	var hp_before := ms.p2.hero.get_hp()
	_advance(ms, _activate_intent(), InputIntent.new())
	var dealt := hp_before - ms.p2.hero.get_hp()
	assert_eq(dealt, BOOM_DAMAGE * 2.0, "Bloodlust DOUBLES Boom's per-Boulder damage (AC 34)")
	assert_eq(ms.p1.hero.get_hp(), caster_hp + dealt * 0.5,
		"...and Vampiric Aura heals the caster from what it actually removed (AC 34)")


## AC 28a: Boulder's own effect has a resolver outcome row and is dispatched by id exactly as every other
## Deck 1 effect is.
func test_the_resolver_knows_boulders_effect_by_whole_id() -> void:
	var boulder := CardEffect.new()
	boulder.effect_id = BOULDER_EFFECT
	assert_eq(CardEffectResolver.outcome(boulder, _flags()),
		CardEffectResolver.OUTCOME_BOULDER_CLEAR, "Boulder's effect has its own outcome (AC 28a)")
	assert_true(CardEffectResolver.clears_cover(boulder), "...and answers the press-time question")
	var other := CardEffect.new()
	other.effect_id = ROCKSLING
	assert_false(CardEffectResolver.clears_cover(other), "...which no other effect answers true")
	assert_false(CardEffectResolver.clears_cover(null), "...and a null effect clears nothing")
	# The flag asymmetry, recorded at the resolver and asserted here: a closed spell layer must not leave a
	# Boulder stuck in a hand forever.
	var closed := FeatureFlags.new()
	assert_eq(CardEffectResolver.outcome(boulder, closed),
		CardEffectResolver.OUTCOME_BOULDER_CLEAR,
		"a CLOSED spells layer still lets a Boulder be cleared -- it is not a spell its holder chose")


# -------------------------------------------------------------------- AC 29-33: Corpse Bomb

## AC 29 / AC 30 / AC 31: activation kills every LIVING own minion, leaves each a normal corpse through the
## shared death seat, and launches one homing skull per converted minion FROM that minion's board index.
func test_corpse_bomb_converts_every_own_minion_and_launches_one_skull_each() -> void:
	var ms := _staged_corpse_bomb()
	var minion := _kind_index(ms, MINION_KIND)
	for _i in 3:
		ms.p1.units.add(UNIT_HP, minion)
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_eq(ms.p1.units.living_indices(), [] as Array[int], "every living own minion died (AC 29)")
	assert_eq(ms.p1.units.corpse_indices(), [0, 1, 2] as Array[int],
		"...each leaving a normal corpse through the shared seat (AC 30)")
	assert_eq(ms.p1.projectiles.size(), 3, "one skull per converted minion (AC 31)")
	for shot in 3:
		assert_true(ms.p1.projectiles.is_hero_sourced_at(shot),
			"skull %d is a hero-sourced record, so it inherits every stone rung (AC 32)" % shot)
		assert_eq(ms.p1.projectiles.effect_id_at(shot), String(CORPSE_BOMB), "...authored by Corpse Bomb")
		assert_eq(ms.p1.projectiles.damage_at(shot), SKULL_DAMAGE, "...at the authored per-skull damage")
		assert_eq(ms.p1.projectiles.source_index_at(shot), shot,
			"...and it NAMES THE MINION IT LEFT, which is what the runner resolves its launch "
			+ "position from (AC 3a/AC 31)")
		assert_eq(ms.p1.projectiles.kind_index_at(shot), BalanceConfig.NO_KIND_INDEX,
			"...while carrying no unit kind, exactly as a hero shot does")
		assert_eq(ms.p1.projectiles.target_slot_at(shot), 1, "...aimed at the captured target")


## AC 29: TOTEMS are not minions for this effect -- the `6-5b/R5`/`R6` reading, one decision shared rather
## than a second copy of it.
func test_corpse_bomb_spares_the_casters_totems() -> void:
	var ms := _staged_corpse_bomb()
	ms.p1.units.add(UNIT_HP, _kind_index(ms, TOTEM_KIND))
	ms.p1.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_true(ms.p1.units.is_alive_at(0), "the caster's TOTEM is untouched (AC 29)")
	assert_false(ms.p1.units.is_alive_at(1), "...while the minion beside it converted")
	assert_eq(ms.p1.projectiles.size(), 1, "...and exactly one skull launched, from the minion")
	assert_eq(ms.p1.projectiles.source_index_at(0), 1, "...naming the minion's own index")


## AC 30, added at the review fix (minor 7): the F2 rung -- a converted minion's SWING DEDUPE RECORD is
## discarded with it. Untested before, and it is the one line of `_apply_corpse_bomb` whose omission leaves
## no visible trace at the activation: a stale record keyed to a dead unit's board index would survive into
## whatever occupies that index next (a Raise Dead, `6-5b`) and could drop that unit's first legitimate
## contact as a duplicate. Arranged by opening a record directly, which is what the unit's own active
## window does.
func test_corpse_bomb_discards_a_converted_minions_swing_dedupe_record() -> void:
	var ms := _staged_corpse_bomb()
	var minion := _kind_index(ms, MINION_KIND)
	ms.p1.units.add(UNIT_HP, minion)
	ms.p1.units.add(UNIT_HP, minion)
	ms.p1.unit_dedupe.open(0, 1)
	ms.p1.unit_dedupe.open(1, 1)
	assert_eq(ms.p1.unit_dedupe.size(), 2, "fixture: both minions carry a live dedupe record")
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_eq(ms.p1.units.living_indices(), [] as Array[int], "sanity: both converted")
	assert_eq(ms.p1.unit_dedupe.size(), 0,
		"every converted minion's dedupe record is discarded with it (AC 30) -- a stale record would "
		+ "outlive its unit and drop the next occupant's first contact")


## AC 26, added at the review fix (minor 8): A LETHAL BOOM ends the round on its own tick. Structurally
## true (the damage lands at step 6, the resolution check runs at step 8 of the SAME `advance()`), but
## untested in state -- and "structurally true" is what the M5 green mutant in this same file was, before
## it turned out the branch under test was never reached.
func test_a_lethal_boom_ends_the_round_on_its_own_tick() -> void:
	var ms := _staged_boom()
	ms.p2.hand.cover_at(0, BOULDER_CARD)
	ms.p2.hero.take_damage(MAX_HP - BOOM_DAMAGE)
	assert_almost_eq(ms.p2.hero.get_hp(), BOOM_DAMAGE, 0.0001,
		"fixture: exactly one Boulder's worth of hp is left, so this Boom is lethal and only just")
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), 0.0, "the Boom killed the opposing hero (AC 26)")
	assert_true(bool(ms.to_snapshot()["round_over"]),
		"...and the round ended on that same tick -- step 6's damage, step 8's check (AC 26)")


## AC 33: no living own minion refuses through the SAME 6-5b no-target path, before the orb spend.
func test_corpse_bomb_with_no_own_minion_is_refused_on_the_shared_path() -> void:
	var ms := _staged_corpse_bomb()
	var rejections := _rejections(ms.p1)
	var orbs_before: Dictionary = ms.p1.orbs.to_snapshot()
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_OWN_MINION]],
		"refused through 6-5b's existing token, unchanged (AC 33)")
	assert_eq(ms.p1.orbs.to_snapshot(), orbs_before, "...before the orb spend")
	assert_true(ms.pitch.is_staged(0), "...and the card stays staged, counting toward fizzle")


## AC 32: a skull NEVER plants a Boulder -- ruling 6 is Rocksling-only, and it is true by the authored
## `boulders_per_cast` rather than by an exclusion list.
func test_a_landed_skull_plants_no_boulder() -> void:
	var ms := _staged_corpse_bomb()
	ms.p1.units.add(UNIT_HP, _kind_index(ms, MINION_KIND))
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_eq(ms.p1.projectiles.size(), 1, "sanity: a skull is away")
	var hp_before := ms.p2.hero.get_hp()
	_land(ms)
	assert_eq(hp_before - ms.p2.hero.get_hp(), SKULL_DAMAGE, "the skull deals its damage (AC 32)")
	assert_eq(ms.p2.hand.cover_count(), 0, "...and plants NO Boulder (AC 32)")


## AC 38 / AC 40 (ruling 14): the conversion record is present in hashed state and READ BACK -- owner
## (whose snapshot it is), the dead indices, and the activation tick.
func test_the_corpse_bomb_conversion_record_is_hashed_and_readable_back() -> void:
	var ms := _staged_corpse_bomb()
	var resting: Array = ms.p1.to_snapshot()["corpse_bomb"]
	assert_eq(resting, [PlayerState.NO_CORPSE_BOMB_TICK, [] as Array[int]],
		"at rest the record is empty (AC 38)")
	var before := CanonicalHash.of(ms.to_snapshot())
	var minion := _kind_index(ms, MINION_KIND)
	ms.p1.units.add(UNIT_HP, minion)
	ms.p1.units.add(UNIT_HP, minion)
	_advance(ms, _activate_intent(), InputIntent.new())
	var record: Array = ms.p1.to_snapshot()["corpse_bomb"]
	assert_eq(record[1], [0, 1] as Array[int],
		"the record names WHICH minions were converted, ascending (AC 40)")
	assert_true(int(record[0]) > 0, "...and the tick the activation landed on (AC 40)")
	assert_eq(int(record[0]), ms._tick, "...which is this tick")
	assert_ne(CanonicalHash.of(ms.to_snapshot()), before,
		"...and it is HASHED, so a replay cannot diverge on it (AC 38, cause 2)")
	assert_eq(ms.p2.to_snapshot()["corpse_bomb"], resting,
		"the OWNER is implicit: the other player's record is untouched")
	# Round end clears it, beside the rules and the cast.
	ms.p1.hero.take_damage(MAX_HP)
	_idle(ms, 1)
	assert_eq(ms.p1.to_snapshot()["corpse_bomb"], resting, "round end clears the record")


# ---------------------------------------------------------------------------- AC 36: the M6 guard

## AC 36: the 6-5d reload refusal (a same-length `unit_kinds` REORDER while any unit or live projectile
## record exists) still covers a live STONE and a live SKULL, not only a Fireball. Proven for both, and
## proven non-vacuous by the accepted reload on an empty board.
func test_the_kind_reorder_refusal_covers_a_live_stone_and_a_live_skull() -> void:
	var clean := _make_match()
	assert_eq(clean.apply_balance(_config_with_kinds_reordered()), "",
		"sanity: with nothing in flight the reorder is ACCEPTED -- the guard is not blanket")
	var with_stone := _in_flight()
	assert_ne(with_stone.apply_balance(_config_with_kinds_reordered()), "",
		"a live STONE refuses a same-length kind reorder (AC 36)")
	var with_skull := _staged_corpse_bomb()
	with_skull.p1.units.add(UNIT_HP, _kind_index(with_skull, MINION_KIND))
	_advance(with_skull, _activate_intent(), InputIntent.new())
	assert_eq(with_skull.p1.projectiles.size(), 1, "sanity: a skull is live")
	assert_ne(with_skull.apply_balance(_config_with_kinds_reordered()), "",
		"a live SKULL refuses it too (AC 36)")


# --------------------------------------------------------------------------------- helpers

## Code portion of each line (everything before the first `#`), so a doc comment NAMING a field can never
## false-positive the source scans above -- `test_card_effect_resolution.gd`'s own rule.
func _source_lines(path: String) -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		var hash_idx := line.find("#")
		if hash_idx >= 0:
			line = line.substr(0, hash_idx)
		out.append(line)
	f.close()
	return out


## The field names `_mirrored_values_agree` actually compares, read out of its body (`a.<field>`), bounded
## by the next `func` so a later neighbour cannot leak into the set.
func _fields_compared_by_the_mirror_predicate(lines: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var inside := false
	var reader := RegEx.create_from_string("\\ba\\.([A-Za-z_][A-Za-z0-9_]*)")
	for line in lines:
		if line.contains("func _mirrored_values_agree("):
			inside = true
			continue
		if inside and line.begins_with("func ") or (inside and line.begins_with("static func ")):
			break
		if not inside:
			continue
		for m: RegExMatch in reader.search_all(line):
			if not out.has(m.get_string(1)):
				out.append(m.get_string(1))
	return out


## Every local variable name that `<name>(` was assigned into -- the handles whose field reads the scan
## above must account for.
func _handles_assigned_from(lines: Array[String], name: String) -> Array[String]:
	var out: Array[String] = []
	var reader := RegEx.create_from_string(
			"var\\s+([A-Za-z_][A-Za-z0-9_]*)[^=]*=\\s*%s\\(" % name)
	for line in lines:
		var m := reader.search(line)
		if m != null and not out.has(m.get_string(1)):
			out.append(m.get_string(1))
	return out

## P1's staged card's remaining fizzle ticks, read off the snapshot PitchState already publishes (there is
## no public countdown accessor, and adding one for a test would be widening a shipped surface for a test's
## convenience).
func _fizzle_remaining(ms: MatchState) -> int:
	var zone: Dictionary = ms.pitch.to_snapshot()["p1"]
	var fizzle: Dictionary = zone["fizzle"]
	return int(fizzle["duration_ticks"]) - int(fizzle["elapsed_ticks"])


## Does the mirror ACCEPT these two entries under one id? Built as a real injection so the answer comes from
## the shipped seat rather than from a copy of its logic. `Invariant.check` is `push_error` + `assert`, and
## the assert is stripped in an exported build, so the OBSERVABLE consequence is asserted instead: a refused
## pair leaves the mirror disagreeing with one of the two, which `projectile_profile_at` would then read.
## Here the discriminator is the helper itself -- see `MatchState._mirrored_values_agree`.
func _mirror_accepts(basic: CardEffect, pitch: CardEffect) -> bool:
	return MatchState._mirrored_values_agree(basic, pitch)


## The slot a landed stone plants in, for one seed. A fresh match each call, so the stream position is the
## seed's alone.
func _planted_slot(seed_value: int) -> int:
	var ms := _in_flight(null, seed_value)
	_land(ms)
	var covered := ms.p2.hand.covered_indices()
	assert_eq(covered.size(), 1, "exactly one Boulder was planted for seed %d" % seed_value)
	return covered[0]


## A match with a Boulder already planted on P2.
func _planted() -> MatchState:
	var ms := _in_flight()
	_land(ms)
	assert_eq(ms.p2.hand.cover_count(), 1, "fixture: a Boulder is planted")
	return ms


## P1 mid-cast of Rocksling: the press has resolved, the cast window is running, nothing has launched.
func _cast_rocksling(basic: Variant = null) -> MatchState:
	var ms := _make_match(basic)
	_advance(ms, _cast_intent(CAST_SLOT), InputIntent.new())
	assert_true(ms.p1.is_casting(), "fixture: the cast is in flight")
	return ms


## P1 with stone 0 in the air, aimed at P2's hero, past the strike tick.
func _in_flight(basic: Variant = null, seed_value: int = SEED) -> MatchState:
	var ms := _make_match(basic, null, seed_value)
	_advance(ms, _cast_intent(CAST_SLOT), InputIntent.new())
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p1.projectiles.size(), 1, "fixture: stone 1 launched")
	return ms


## P1 with a BOOM staged and its orb banked, one press from activating.
func _staged_boom() -> MatchState:
	return _staged(_boom_pitch_effects())


## P1 with a CORPSE BOMB staged and its orb banked.
func _staged_corpse_bomb() -> MatchState:
	return _staged(_corpse_bomb_pitch_effects())


func _staged(pitch_effects: Dictionary[StringName, CardEffect]) -> MatchState:
	var ms := _make_match(null, null, SEED, pitch_effects)
	_advance(ms, _stage_intent(STAGE_SLOT), InputIntent.new())
	assert_true(ms.pitch.is_staged(0), "fixture: the pitch card is staged")
	ms.p1.orbs.add(PITCH_COLOR, PITCH_ORBS)
	ms.drain_signals()
	return ms


## Walk P2 one tick and report the speed it actually moved at. The gait seat is what AC 37a is about, so the
## measurement is the hero's own velocity rather than a re-derived product.
func _walk_speed(ms: MatchState) -> float:
	return _walk_speed_of(ms, 1)


func _walk_speed_of(ms: MatchState, slot: int) -> float:
	var walk := InputIntent.new()
	walk.move_dir = Vector2(1.0, 0.0)
	if slot == 0:
		_advance(ms, walk, InputIntent.new())
		return ms.p1.hero.velocity.length()
	_advance(ms, InputIntent.new(), walk)
	return ms.p2.hero.velocity.length()


func _cards_changed(player: PlayerState) -> Array:
	var out: Array = []
	player.cards_changed.connect(
		func(ids: Array[StringName], deck: int, discard: int) -> void:
			out.append([ids, deck, discard]))
	return out


func _make_match(basic: Variant = null, config: BalanceConfig = null, seed_value: int = SEED,
		pitch_effects: Variant = null) -> MatchState:
	var ms := MatchState.new(MatchParams.new(seed_value))
	ms.apply_balance(config if config != null else _config())
	ms.inject_feature_flags(_flags())
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	var effects: Dictionary[StringName, CardEffect] = _basic_effects()
	if basic != null:
		effects = basic
	ms.inject_card_effects(effects)
	ms.inject_pitch_costs(_pitch_costs())
	var pitch: Dictionary[StringName, CardEffect] = _boom_pitch_effects()
	if pitch_effects != null:
		pitch = pitch_effects
	ms.inject_pitch_effects(pitch)
	_tick(ms)
	ms.p1.mana.add(MAX_MANA - ms.p1.mana.get_current())
	ms.p2.mana.add(MAX_MANA - ms.p2.mana.get_current())
	ms.p1.stamina.refill()
	ms.p2.stamina.refill()
	ms.drain_signals()
	return ms


## The BASIC effect map: ROCKSLING for every deck id, plus the BOULDER CARD's own entry -- which is what
## `_boulder_card_id`'s derivation finds and what a Mode ① press on a covered slot resolves through.
func _basic_effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = _basic_effects_without_boulder()
	var boulder := CardEffect.new()
	boulder.effect_id = BOULDER_EFFECT
	out[BOULDER_CARD] = boulder
	return out


## The same map with NO Boulder authored -- the control fixture (see the file header).
func _basic_effects_without_boulder() -> Dictionary[StringName, CardEffect]:
	var rocksling := CardEffect.new()
	rocksling.effect_id = ROCKSLING
	rocksling.cast_seconds = float(CAST_TICKS) / TimingWindow.TICK_HZ
	rocksling.damage_amount = STONE_DAMAGE
	rocksling.boulders_per_cast = STONES
	rocksling.boulder_interval_seconds = float(INTERVAL_TICKS) / TimingWindow.TICK_HZ
	rocksling.launch_speed = LAUNCH_SPEED
	rocksling.homing_turn_rate_degrees_per_second = 120.0
	rocksling.max_speed = LAUNCH_SPEED
	rocksling.travel_budget = BUDGET
	var out: Dictionary[StringName, CardEffect] = {}
	for id in _deck_contents():
		out[id] = rocksling
	return out


func _boom_pitch_effects() -> Dictionary[StringName, CardEffect]:
	var boom := CardEffect.new()
	boom.effect_id = BOOM
	boom.damage_amount = BOOM_DAMAGE
	var out: Dictionary[StringName, CardEffect] = {}
	for id in _deck_contents():
		out[id] = boom
	return out


func _corpse_bomb_pitch_effects() -> Dictionary[StringName, CardEffect]:
	var bomb := CardEffect.new()
	bomb.effect_id = CORPSE_BOMB
	bomb.damage_amount = SKULL_DAMAGE
	bomb.launch_speed = LAUNCH_SPEED
	bomb.homing_turn_rate_degrees_per_second = 120.0
	bomb.max_speed = LAUNCH_SPEED
	bomb.travel_budget = BUDGET
	var out: Dictionary[StringName, CardEffect] = {}
	for id in _deck_contents():
		out[id] = bomb
	return out


func _land(ms: MatchState, facing := true, defender: InputIntent = null) -> void:
	_push_shot_contact(ms, [ms.p1.projectiles.target_slot_at(0),
			ms.p1.projectiles.target_index_at(0)], 0, facing)
	_advance(ms, InputIntent.new(), defender if defender != null else InputIntent.new())


func _push_shot_contact(ms: MatchState, target: Array, shot := 0, facing := true) -> void:
	var address: Array[int] = [int(target[0]), int(target[1])]
	var attacker: Array[int] = [0, MatchState.projectile_attacker_index(shot)]
	var target_side: PlayerState = ms.p1 if int(target[0]) == 0 else ms.p2
	var heading := target_side.hero.facing
	var dir := heading if facing else -heading
	ms.push_contact(attacker, address, ms.p1.projectiles.flight_ticks_at(shot), dir,
			MatchState.CONTACT_STRIKE)


func _block_intent() -> InputIntent:
	var i := InputIntent.new()
	i.held[&"block"] = true
	return i


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
	c.walk_speed = WALK_SPEED
	c.move_speed = WALK_SPEED * 2.0
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
	c.boulder_slow_per_boulder = SLOW_PER_BOULDER
	c.unit_kinds.append(_kind(MINION_KIND, 3.0))
	c.unit_kinds.append(_kind(TOTEM_KIND, 7.0))
	return c


## The SAME TWO KINDS in the OTHER ORDER -- a same-length reorder, M6's case.
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
	# THE UNBLOCKABLE LAYER IS OPEN SO THE COVERED-SLOT REFUSAL IS REACHABLE (AC 17a). Modes ② and ③ gate
	# on this flag FIRST (`5-2/R13`: "does this layer exist at all" precedes "may I use it right now"), so
	# with it closed a covered-slot press is refused as `flag_closed` and AC 17a's token is never reached --
	# measured, and the reason this line is load-bearing rather than tidy.
	f.unblockable = true
	return f


func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("rs_card_%02d" % i))
	return out


## The cost map carries the deck AND the Boulder card, at its own authored 2 mana (AC 20).
func _costs() -> Dictionary[StringName, CardCastCondition] :
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = CAST_COST
		out[id] = c
	var boulder := CardCastCondition.new()
	boulder.mana_cost = BOULDER_COST
	out[BOULDER_CARD] = boulder
	return out


func _pitch_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = PITCH_MINIMUM
		c.orb_costs[PITCH_COLOR] = PITCH_ORBS
		out[id] = c
	return out


func _rejections(player: PlayerState) -> Array:
	var out: Array = []
	player.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: out.append([action, reason]))
	return out


## See `test_fireball.gd::_hits` for why the match state is captured WEAKLY (a strong capture is a
## reference cycle that leaks every injected Resource and fails the suite as `resources still in use`).
func _hits(ms: MatchState) -> Array:
	var out: Array = []
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


func _cast_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.BASIC
	i.card_commit = true
	return i


func _stage_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.PITCH
	i.card_commit = true
	return i


func _activate_intent() -> InputIntent:
	var i := InputIntent.new()
	i.card_mode = Enums.ModeKind.PITCH
	i.card_commit = true
	i.card_activate = true
	return i


func _reset_intent() -> InputIntent:
	var i := InputIntent.new()
	i.debug_reset = true
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
