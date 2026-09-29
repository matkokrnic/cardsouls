extends TestCase

## Story 6-5f (AC 4-27): COUNTERSPELL end to end through `advance()` -- the target gate, the no-target
## refusal, the six instant reversals, the three clamps and the placeholder cue. The LAST deferred row
## this story retires.
##
## Covers AC 4-10 (target selection: the record, the resolution tick, the window in both directions, the
## Boulder-clear gate, Counterspell-as-target, the already-countered card), AC 11-13 (the one no-target
## refusal, its four clauses and the 6-5g interim rule), AC 14-16 (amount ACTUALLY applied, the three
## clamps, partial reversal), AC 17-23 (the six per-card reversals and the general restore rule), AC 24
## (no RNG), AC 26 (the cue on a reversal and never on a refusal) and AC 27 (the deferred table empty).
##
## THE DETERMINISM AND KEY-SET CONSEQUENCES ARE NOT HERE. The golden, its cause isolation and the two
## key-set pins live in `test_determinism.gd`, `test_draw_delay_and_reshuffle.gd` and
## `test_card_observation.gd`; the death seat's caller census is `test_corpses.gd`'s. This file is about
## BEHAVIOUR.
##
## WHO IS WHO, AND IT IS FIXED THROUGHOUT: **P2 resolves the card, P1 counters it.** `_apply_counterspell`
## derives its victim as `1 - slot`, so a Counterspell activated by P1 (slot 0) reaches P2. Every helper
## below is named from that standpoint (`_victim_casts`, `_counter`) so no test has to re-derive it.
##
## MODE MATTERS AND IS NOT INTERCHANGEABLE. Counterspell is a MODE ④ PITCH ACTIVATION (`6-5f/R1`), so it
## is always driven through the real stage-then-activate sequence -- which is what puts the no-target
## refusal at the pre-spend board gate where AC 11 requires it. The victim's cards are driven as MODE ①
## presses, which is the shorter path to the same `record_resolved_card` seat.
##
## GOLDEN ISOLATION (`BC/R3`): every config, effect and card below is built IN-TEST with opaque `cs_*`
## ids and in-test numbers; nothing reads `data/`, so a Deck 1 retune moves nothing here.

const SEED := 6561
const MAX_HP := 100.0
const MAX_STAMINA := 50.0
const START_MANA := 40.0
const MAX_MANA := 50.0
const MINION_HP := 9.0
const MINION_DAMAGE := 4.0
const MINION_KIND := 0
const CORPSE_TICKS := 40
const CORPSE_SECONDS := float(CORPSE_TICKS) / TimingWindow.TICK_HZ

## The in-test effect numbers, DISTINCT from each other so a value read off the wrong field cannot
## coincidentally produce the expected answer.
const CULLING_MANA_PER_KILL := 3.0
const WARD_TICKS := 10
const WARD_SECONDS := float(WARD_TICKS) / TimingWindow.TICK_HZ
const RAISE_PERCENT := 50.0
const DRAIN_HEAL := 12.0
const BOOM_DAMAGE := 6.0

const ID_COUNTER := &"cs_counter"
const ID_COUNTER_B := &"cs_counter_b"     # the SECOND copy, for AC 10
const ID_VANGUARD := &"cs_vanguard"
const ID_CULLING := &"cs_culling"
const ID_WARD := &"cs_ward"
const ID_RAISE := &"cs_raise"
const ID_DRAIN := &"cs_drain"
const ID_BOOM := &"cs_boom"
const ID_BOLT := &"cs_bolt"               # a 6-5g card, for AC 13's interim rule
const BOULDER_CARD := &"cs_boulder"       # in the EFFECT MAP only, never in the deck

const DECK: Array[StringName] = [ID_COUNTER, ID_COUNTER_B, ID_VANGUARD, ID_CULLING, ID_WARD,
		ID_RAISE, ID_DRAIN, ID_BOOM, ID_BOLT]

const CAST_MANA := 2.0
const ORB_PRICE := 1


# ------------------------------------------------------------------ AC 4-5: the target and its tick

## AC 4/AC 5 (`6-5f/R3`/`R31`): the record the gate reads -- id, mode and the RESOLUTION TICK, written at
## the Mode ① seat, and the tick is the tick the cast actually resolved on rather than a later one.
func test_a_resolution_records_its_own_tick_alongside_the_id_and_mode() -> void:
	var ms := _make_match()
	assert_eq(ms.p2.to_snapshot()["last_resolved_card"],
		["", PlayerState.NO_RESOLVED_MODE, PlayerState.NO_RESOLVED_TICK],
		"nothing resolved yet: all three members rest")
	_victim_casts(ms, ID_VANGUARD)
	var at_cast: Array = ms.p2.to_snapshot()["last_resolved_card"]
	assert_eq(at_cast.slice(0, 2), [String(ID_VANGUARD), Enums.ModeKind.BASIC],
		"the id and mode are recorded as before (6-5a AC 10, unchanged)")
	var recorded := int(at_cast[2])
	_idle(ms, 5)
	assert_eq(int((ms.p2.to_snapshot()["last_resolved_card"] as Array)[2]), recorded,
		"the tick is the RESOLUTION's own and does not drift as the match runs on (AC 5)")


## AC 4: a REFUSED card never resolved, so it never becomes a target. Driven through a real refusal --
## a Mode ① press with no mana -- rather than by asserting on an untouched fixture, which would pass
## against a build that recorded refusals too.
func test_a_refused_card_is_never_recorded_and_never_a_target() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_VANGUARD)
	var after_real: Array = ms.p2.to_snapshot()["last_resolved_card"]
	ms.p2.mana.spend(ms.p2.mana.get_current())
	_victim_casts(ms, ID_WARD)
	assert_eq(ms.p2.to_snapshot()["last_resolved_card"], after_real,
		"a cast refused for mana leaves the previous record untouched -- it never resolved (AC 4)")


# ------------------------------------------------------------------ AC 8: the Boulder-clear gate

## AC 8 (`6-5f/R7`): a Mode ① press on a COVERED slot plays the Boulder, and that is NOT a played card
## for Counterspell purposes -- it neither becomes a target nor shields the card before it.
##
## BOTH DIRECTIONS, because the ruling has two halves and a one-sided test would pass against a build
## that recorded the Boulder clear under a different id.
func test_a_boulder_clear_neither_records_nor_shields_the_previous_card() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_VANGUARD)
	var before: Array = ms.p2.to_snapshot()["last_resolved_card"]
	var packet_before: Array = ms.p2.to_snapshot()["reversal"]
	var covered := _slot_of(ms.p2, ID_WARD)
	ms.p2.hand.cover_at(covered, BOULDER_CARD)
	_advance(ms, InputIntent.new(), _cast_intent(covered))
	assert_false(ms.p2.hand.is_covered(covered), "sanity: the Boulder really was played off the slot")
	assert_eq(ms.p2.to_snapshot()["last_resolved_card"], before,
		"the Boulder clear did NOT overwrite the record -- it is not a played card (AC 8)")
	assert_eq(ms.p2.to_snapshot()["reversal"], packet_before,
		"...and it did not clear the reversal packet either, so the Vanguard is still reversible")


## AC 8's second half, end to end: a Counterspell fired immediately AFTER a Boulder clear still reaches
## the real card behind it. The behavioural consequence of the gate, not a second reading of the field.
func test_a_counterspell_after_a_boulder_clear_still_reaches_the_real_card() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_VANGUARD)
	assert_eq(ms.p2.units.size(), 1, "sanity: the Vanguard is on the board")
	var covered := _slot_of(ms.p2, ID_WARD)
	ms.p2.hand.cover_at(covered, BOULDER_CARD)
	_advance(ms, InputIntent.new(), _cast_intent(covered))
	_counter(ms)
	assert_false(ms.p2.units.is_alive_at(0),
		"the Counterspell reached PAST the Boulder clear to the Vanguard and un-summoned it (AC 8)")


# ------------------------------------------------------------------ AC 6-7: the window

## AC 6 (`6-5f/R4`): at the authored default `0.0` the window is NO LIMIT -- a card resolved long ago is
## still a valid target. Proven at a delay far longer than any window a test would author.
func test_with_the_default_window_any_resolved_card_is_still_a_target() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_VANGUARD)
	_idle(ms, 120)
	_counter(ms)
	assert_false(ms.p2.units.is_alive_at(0),
		"`counter_window_seconds` 0.0 means no limit: a 120-tick-old resolution is still counterable")


## AC 7: with a POSITIVE window, a target just INSIDE it is still valid and one just OUTSIDE is refused.
## The two cases are the same fixture with one tick of difference, which is the only form that proves a
## boundary rather than a direction.
func test_a_positive_window_admits_just_inside_and_refuses_just_outside() -> void:
	var window_ticks := 12
	for inside: bool in [true, false]:
		var ms := _make_match(_windowed_effects(window_ticks))
		_victim_casts(ms, ID_VANGUARD)
		# The stage press and the activate press are the last two of the gap, so the activation lands
		# `gap` ticks after the resolution. `gap == window_ticks` is INSIDE (`<=`), one more is outside.
		var gap := window_ticks if inside else window_ticks + 1
		_idle(ms, gap - 2)
		var rejections := _rejections(ms.p1)
		_counter(ms)
		if inside:
			assert_false(ms.p2.units.is_alive_at(0),
				"a resolution exactly `window` ticks old is INSIDE the window and is countered (AC 7)")
			assert_eq(rejections, [], "...with no refusal")
		else:
			assert_true(ms.p2.units.is_alive_at(0),
				"one tick older than the window is NO TARGET and nothing is reversed (AC 7)")
			assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_COUNTER_TARGET]],
				"...refused through the one no-target reason")


# ------------------------------------------------------------------ AC 11-13: the no-target refusal

## AC 11 (`6-5f/R10`): the refusal fires at the PRE-SPEND board gate, and every consequence the AC lists
## is asserted -- the orbs are NOT spent, the card stays staged and READY, its countdown keeps running,
## and the staging mana is NOT refunded.
func test_a_no_target_activation_is_refused_before_the_orb_spend_and_leaves_the_card_staged() -> void:
	var ms := _make_match()
	_stage(ms, ID_COUNTER)
	var orbs_before := ms.p1.orbs.get_count(Enums.CardColor.GREEN)
	var mana_before := ms.p1.mana.get_current()
	var elapsed_before := _fizzle_elapsed(ms)
	var rejections := _rejections(ms.p1)
	_activate(ms)
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_COUNTER_TARGET]],
		"the opponent has resolved nothing this round: refused as no-target (AC 11)")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.GREEN), orbs_before,
		"...the ORBS are not spent -- the gate is before the spend")
	assert_true(ms.pitch.is_staged(0), "...the card STAYS staged")
	assert_true(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags), "...and stays READY")
	assert_eq(ms.p1.mana.get_current(), mana_before,
		"...the staging mana is NOT refunded (it was spent at staging, which this refusal is not)")
	_idle(ms, 3)
	assert_true(_fizzle_elapsed(ms) > elapsed_before,
		"...and its fizzle countdown keeps running toward the ordinary expiry")


## AC 9 (`6-5f/R8`): a player whose OWN last resolved card is Counterspell is no target -- and there is
## no special case for it anywhere. Driven the way the AC describes: P2 counters first, then P1 tries to
## counter P2's Counterspell.
func test_counterspell_itself_is_never_a_target() -> void:
	var ms := _make_match()
	# P1 resolves something for P2 to counter, so P2's Counterspell has a real target and resolves.
	_caster_casts(ms, ID_VANGUARD)
	_counter_by(ms, 1)
	assert_eq((ms.p2.to_snapshot()["last_resolved_card"] as Array)[0], String(ID_COUNTER),
		"sanity: P2's own record now names Counterspell, on the ordinary unconditional write (AC 9)")
	var rejections := _rejections(ms.p1)
	_counter(ms)
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_COUNTER_TARGET]],
		"P1's Counterspell against a Counterspell is refused as no-target -- by the ordinary overwrite "
		+ "rule and the empty packet, with no special-case code (AC 9)")


## AC 10 (`6-5f/R5`): a card already countered once cannot be countered again. The reversal record that
## made it a target is cleared the instant the first Counterspell reverses it, so the SECOND copy reads
## no-target -- smoke item 5, as a unit test.
func test_a_second_copy_cannot_counter_an_already_countered_card() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_VANGUARD)
	_counter(ms)
	assert_false(ms.p2.units.is_alive_at(0), "sanity: the first Counterspell reversed the summon")
	assert_eq(ms.p2.to_snapshot()["reversal"], [PlayerState.REVERSAL_NONE, [], [], [], [], 0.0],
		"the packet is cleared the instant it is reversed (AC 10, `6-5f/R5`)")
	var rejections := _rejections(ms.p1)
	_counter_with(ms, ID_COUNTER_B)
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_COUNTER_TARGET]],
		"...so the SECOND copy reads no-target and is refused (AC 10)")


## AC 13 (`6-5f/R37`), THE INTERIM RULE: a Counterspell against a resolution one of the seven cards
## deferred to `6-5g` produced is refused through the SAME path and the SAME reason. Proven with a
## resolved Honed Bolt, which the AC names.
##
## IT IS REFUSED BY CONSTRUCTION, NOT BY A LIST: `honed_bolt` has no reversal arm, so its resolution
## leaves the packet at `REVERSAL_NONE` and the ordinary gate refuses it. A test that passed only because
## an id list happened to contain `honed_bolt` would be testing a different mechanism.
func test_a_6_5g_card_is_refused_through_the_same_no_target_path() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_BOLT)
	assert_eq((ms.p2.to_snapshot()["last_resolved_card"] as Array)[0], String(ID_BOLT),
		"sanity: the Honed Bolt really resolved and was recorded")
	assert_eq(ms.p2.to_snapshot()["reversal"], [PlayerState.REVERSAL_NONE, [], [], [], [], 0.0],
		"...and left NO reversal packet, because 6-5f builds no arm for it (AC 13)")
	var rejections := _rejections(ms.p1)
	_counter(ms)
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_COUNTER_TARGET]],
		"refused as no-target through the same path and the same reason -- no new refusal reason (AC 13)")


## AC 12 (`6-5f/R11`'s fourth clause): "everything the last card did has already expired or is gone" is
## its own refusal case, proven for BOTH cases the AC names -- a summoned Vanguard dead with its corpse
## expired, and a Grave Ward whose every touched corpse has naturally expired.
func test_a_resolution_whose_every_product_is_gone_is_refused() -> void:
	# (a) the Vanguard: summoned, killed, and its corpse expired.
	var vanguard := _make_match()
	_victim_casts(vanguard, ID_VANGUARD)
	vanguard.p2.units.kill_at(0, CORPSE_TICKS)
	_idle(vanguard, CORPSE_TICKS + 1)
	assert_false(vanguard.p2.units.has_corpse_at(0), "sanity: the corpse has expired")
	var vanguard_rejections := _rejections(vanguard.p1)
	_counter(vanguard)
	assert_eq(vanguard_rejections, [[&"card_cast", MatchState.REASON_NO_COUNTER_TARGET]],
		"a dead Vanguard with an expired corpse leaves nothing to reverse: refused (AC 12)")
	# (b) the Grave Ward: every corpse it touched has since expired naturally.
	var ward := _make_match()
	ward.p2.units.add(MINION_HP, MINION_KIND)
	ward.p2.units.kill_at(0, CORPSE_TICKS)
	_victim_casts(ward, ID_WARD)
	assert_true(ward.p2.units.has_corpse_at(0), "sanity: the ward extended a real corpse")
	_idle(ward, CORPSE_TICKS + WARD_TICKS + 1)
	assert_false(ward.p2.units.has_corpse_at(0), "sanity: even the extended corpse has expired")
	var ward_rejections := _rejections(ward.p1)
	_counter(ward)
	assert_eq(ward_rejections, [[&"card_cast", MatchState.REASON_NO_COUNTER_TARGET]],
		"a Grave Ward whose every touched corpse has expired leaves nothing to reverse: refused (AC 12)")


# ------------------------------------------------------------------ AC 17-23: the six reversals

## AC 17 (`6-5f/R16`): a countered summon VANISHES WITH NO CORPSE -- in BOTH of the AC's cases, whether
## the minion is still alive or has already died and left one.
func test_countering_a_summon_removes_the_minion_with_no_corpse_either_way() -> void:
	for already_dead: bool in [false, true]:
		var ms := _make_match()
		_victim_casts(ms, ID_VANGUARD)
		assert_true(ms.p2.units.is_alive_at(0), "sanity: the summon is on the board")
		if already_dead:
			ms.p2.units.kill_at(0, CORPSE_TICKS)
			assert_true(ms.p2.units.has_corpse_at(0), "sanity: it died and left a corpse")
		_counter(ms)
		assert_false(ms.p2.units.is_alive_at(0),
			"already_dead=%s: the summoned minion is gone (AC 17)" % already_dead)
		assert_false(ms.p2.units.has_corpse_at(0),
			"...and left NO corpse either way (AC 17) -- the corpse it had is taken with it")


## AC 18/AC 23 (`6-5f/R17`/`R29`): countering a Culling raises every minion it killed FROM ITS OWN
## CORPSE at the hp it held immediately before death, and claws the mana back.
##
## THE PRE-DEATH HP IS THE POINT AND IS MADE LOAD-BEARING: the two minions are damaged to DIFFERENT hp
## before the Culling, so a restore at the kind's maximum, at `raise_hp_percent`, or at a single shared
## number would all fail. That is what makes this a test of `6-5f/R32`'s field rather than of "a minion
## came back".
func test_countering_a_culling_restores_each_minion_at_its_own_pre_death_hp_and_claws_the_mana_back() -> void:
	var ms := _make_match()
	ms.p2.units.add(MINION_HP, MINION_KIND)
	ms.p2.units.add(MINION_HP, MINION_KIND)
	ms.p2.units.apply_damage_at(0, 2.0, CORPSE_TICKS)   # -> 7.0
	ms.p2.units.apply_damage_at(1, 5.0, CORPSE_TICKS)   # -> 4.0
	var mana_before := ms.p2.mana.get_current()
	_victim_casts(ms, ID_CULLING)
	assert_eq(ms.p2.units.living_indices(), [] as Array[int], "sanity: the Culling killed both")
	# The cast SPENDS `CAST_MANA` and then GRANTS per kill, both on the same tick -- so the net is the
	# grant minus the price, and the claw-back below must take back only the GRANT half.
	assert_eq(ms.p2.mana.get_current(), mana_before - CAST_MANA + 2.0 * CULLING_MANA_PER_KILL,
		"sanity: it granted mana for exactly two kills")
	_counter(ms)
	assert_eq(ms.p2.units.size(), 4, "two NEW records, appended -- holes are never reused (`4-1/R9`)")
	assert_eq(ms.p2.units.hp_at(2), 7.0,
		"the first restored minion enters at the hp it held immediately before death, not at the "
		+ "kind's maximum and not at `raise_hp_percent` (AC 23, `6-5f/R29`/`R32`)")
	assert_eq(ms.p2.units.hp_at(3), 4.0, "...and the second at ITS own different pre-death hp")
	assert_eq(ms.p2.units.raised_from_at(2), 0, "...each naming the corpse it rose from (AC 23)")
	assert_eq(ms.p2.units.raised_from_at(3), 1)
	assert_false(ms.p2.units.has_corpse_at(0), "...and that corpse is CONSUMED by the restoration")
	assert_false(ms.p2.units.has_corpse_at(1))
	assert_eq(ms.p2.mana.get_current(), mana_before - CAST_MANA,
		"...and the mana it GRANTED is taken back, leaving only the price it paid to cast -- the card, "
		+ "the mana and the orbs stay spent (`6-5f/R9`: the countered player gets nothing back)")


## AC 23's last clause: a corpse ALREADY GONE means that minion is NOT restored -- while its sibling,
## whose corpse survives, still is. Both halves in one fixture, which is the only form that proves the
## per-minion test rather than an all-or-nothing one.
func test_a_culled_minion_whose_corpse_is_gone_is_not_restored_but_its_sibling_is() -> void:
	var ms := _make_match()
	ms.p2.units.add(MINION_HP, MINION_KIND)
	ms.p2.units.add(MINION_HP, MINION_KIND)
	_victim_casts(ms, ID_CULLING)
	ms.p2.units.consume_corpse_at(0)   # one corpse is taken away (a Raise Dead, an expiry: same state)
	assert_false(ms.p2.units.has_corpse_at(0), "sanity: index 0's corpse is gone")
	assert_true(ms.p2.units.has_corpse_at(1), "sanity: index 1's survives")
	_counter(ms)
	assert_eq(ms.p2.units.size(), 3, "exactly ONE minion was restored, not two and not none")
	assert_eq(ms.p2.units.raised_from_at(2), 1,
		"...and it is the one whose corpse survived; the other is skipped SILENTLY (`6-5f/R15`)")


## AC 19 (`6-5f/R18`): countering a Grave Ward takes its extension back out of every corpse it touched,
## and a corpse left at `<= 0` disappears on that same tick.
##
## THE EXTENSION IS MEASURED, NOT ASSUMED: the surviving corpse's remaining time after the reversal must
## equal what it would have had with no ward at all, which is the only assertion that catches a reversal
## subtracting the wrong number.
func test_countering_a_grave_ward_removes_its_extension_and_expires_what_that_leaves_at_zero() -> void:
	var ms := _make_match()
	ms.p2.units.add(MINION_HP, MINION_KIND)
	ms.p2.units.add(MINION_HP, MINION_KIND)
	ms.p2.units.kill_at(0, CORPSE_TICKS)
	ms.p2.units.kill_at(1, 2)             # nearly gone: the ward is all that is keeping it alive
	_victim_casts(ms, ID_WARD)
	assert_true(ms.p2.units.is_corpse_extended_at(0), "sanity: the ward marked the corpse")
	var unwarded := ms.p2.units.corpse_ticks_at(0) - WARD_TICKS
	_counter(ms)
	assert_eq(ms.p2.units.corpse_ticks_at(0), unwarded - 2,
		"the extension is taken back out, leaving exactly the lifetime the corpse would have had "
		+ "with no ward (AC 19); the -2 is the two ticks the stage-and-activate sequence itself took")
	assert_false(ms.p2.units.is_corpse_extended_at(0),
		"...and the mark this cast set is taken back with it")
	assert_false(ms.p2.units.has_corpse_at(1),
		"...while the corpse the ward was keeping alive drops to <= 0 and DISAPPEARS on this tick (AC 19)")


## AC 16/AC 20 (`6-5f/R19`): countering a Raise Dead makes every raised minion vanish with no corpse and
## returns each ORIGINAL corpse with the lifetime it would have had -- EXCEPT one that would already have
## naturally expired.
##
## THIS IS AC 16's OWN PROOF CASE and both halves are in one fixture: a corpse with plenty of time left
## returns, while one that was nearly gone at the raise does not.
func test_countering_a_raise_dead_returns_the_surviving_corpses_and_not_the_expired_one() -> void:
	var ms := _make_match()
	ms.p2.units.add(MINION_HP, MINION_KIND)
	ms.p2.units.add(MINION_HP, MINION_KIND)
	ms.p2.units.kill_at(0, CORPSE_TICKS)   # 40 ticks: survives the gap comfortably
	ms.p2.units.kill_at(1, 4)              # 4 ticks: gone before the Counterspell lands
	_victim_casts(ms, ID_RAISE)
	assert_eq(ms.p2.units.size(), 4, "sanity: both corpses were raised into new records")
	assert_false(ms.p2.units.has_corpse_at(0), "sanity: and both corpses were consumed")
	assert_false(ms.p2.units.has_corpse_at(1))
	_idle(ms, 8)                            # the short corpse's remaining lifetime runs out here
	_counter(ms)
	assert_false(ms.p2.units.is_alive_at(2), "every raised minion VANISHES (AC 20)")
	assert_false(ms.p2.units.is_alive_at(3))
	assert_false(ms.p2.units.has_corpse_at(2), "...with NO corpse of its own")
	assert_false(ms.p2.units.has_corpse_at(3))
	assert_true(ms.p2.units.has_corpse_at(0),
		"the ORIGINAL corpse with time left RETURNS (AC 20)")
	# 29, not 30: the corpse was made with 40 ticks, step 2 of the CAST tick aged it to 39 before step 6
	# consumed it, and ten ticks have passed since (8 idle + the 2 of the stage-and-activate sequence).
	# The arithmetic is spelled out because an off-by-one here is exactly what a fresh-full-lifetime bug
	# would look like if the number were merely "about right".
	assert_eq(ms.p2.units.corpse_ticks_at(0), 29,
		"...with the remaining lifetime it WOULD have had -- its remaining AT CONSUMPTION (39) minus the "
		+ "ten ticks that have passed since the resolution, never a fresh full lifetime (40)")
	assert_false(ms.p2.units.has_corpse_at(1),
		"...while the one that would already have naturally expired does NOT return (AC 16/AC 20)")


## AC 21/AC 23 (`6-5f/R20`): countering a Drain raises the sacrificed minion from its own corpse and
## claws the healed hp back.
func test_countering_a_drain_restores_the_sacrifice_and_claws_the_heal_back() -> void:
	var ms := _make_match()
	ms.p2.units.add(MINION_HP, MINION_KIND)
	ms.p2.units.apply_damage_at(0, 3.0, CORPSE_TICKS)   # -> 6.0, so the pre-death hp is load-bearing
	ms.p2.hero.take_damage(30.0)
	var hp_before := ms.p2.hero.get_hp()
	_victim_casts(ms, ID_DRAIN)
	assert_false(ms.p2.units.is_alive_at(0), "sanity: the minion was sacrificed")
	assert_eq(ms.p2.hero.get_hp(), hp_before + DRAIN_HEAL, "sanity: and the hero healed")
	_counter(ms)
	assert_eq(ms.p2.units.size(), 2, "the sacrifice rises again as a NEW record")
	assert_eq(ms.p2.units.hp_at(1), 6.0, "...at its own pre-death hp (AC 23)")
	assert_eq(ms.p2.hero.get_hp(), hp_before, "...and the hp it healed is taken back (AC 21)")


## AC 22 (`6-5f/R23`): countering a Boom refunds the damage and returns every Boulder it detonated to the
## SAME SLOTS, covering the SAME underlying cards again.
##
## THE UNDERLYING CARDS ARE ASSERTED BY NAME, which is what makes this "covering the same cards" rather
## than "two slots are covered": the cover layer never touched `_cards`, so the identity beneath each
## restored Boulder must be exactly what it was before the Boom.
func test_countering_a_boom_refunds_the_damage_and_returns_the_boulders_to_the_same_slots() -> void:
	var ms := _make_match()
	var slot_a := _slot_of(ms.p1, ID_WARD)
	var slot_b := _slot_of(ms.p1, ID_DRAIN)
	ms.p1.hand.cover_at(slot_a, BOULDER_CARD)
	ms.p1.hand.cover_at(slot_b, BOULDER_CARD)
	var hp_before := ms.p1.hero.get_hp()
	_victim_activates(ms, ID_BOOM)
	assert_eq(ms.p1.hand.cover_count(), 0, "sanity: the Boom detonated both Boulders")
	assert_eq(ms.p1.hero.get_hp(), hp_before - 2.0 * BOOM_DAMAGE, "sanity: and dealt two hits")
	_counter(ms)
	assert_eq(ms.p1.hero.get_hp(), hp_before, "the damage it dealt is refunded (AC 22)")
	assert_true(ms.p1.hand.is_covered(slot_a), "...and both Boulders return to the SAME slots (AC 22)")
	assert_true(ms.p1.hand.is_covered(slot_b))
	assert_eq(ms.p1.hand.cover_count(), 2, "...exactly two, not more")
	assert_eq(ms.p1.hand.to_array()[slot_a], ID_WARD,
		"...covering the same underlying card again -- the card layer never moved (AC 22)")
	assert_eq(ms.p1.hand.to_array()[slot_b], ID_DRAIN)


# ------------------------------------------------------------------ AC 14-15: applied amounts, clamps

## AC 14: an instant effect is reversed by the amount ACTUALLY APPLIED, never the nominal authored number
## -- proven with the case the AC names, a mana grant CLAMPED by the pool cap.
##
## THE NOMINAL AND THE ACTUAL ARE DELIBERATELY FAR APART (6.0 authored, ~1.0 applied), so a claw-back of
## the nominal number would overshoot into a visibly different answer rather than a rounding difference.
func test_a_clamped_mana_grant_is_clawed_back_only_by_what_it_actually_granted() -> void:
	var ms := _make_match()
	ms.p2.units.add(MINION_HP, MINION_KIND)
	ms.p2.units.add(MINION_HP, MINION_KIND)
	ms.p2.mana.add(MAX_MANA)                      # the pool is FULL
	var at_cap := ms.p2.mana.get_current()
	assert_eq(at_cap, MAX_MANA, "sanity: the pool is at its cap, so the grant has nowhere to go")
	_victim_casts(ms, ID_CULLING)                 # spends CAST_MANA, then grants 2 x 3.0 into the cap
	var granted := ms.p2.mana.get_current() - (at_cap - CAST_MANA)
	assert_true(granted < 2.0 * CULLING_MANA_PER_KILL,
		"sanity: the grant really was CLAMPED below its nominal %s (applied %s)"
				% [2.0 * CULLING_MANA_PER_KILL, granted])
	var after_cast := ms.p2.mana.get_current()
	_counter(ms)
	assert_eq(ms.p2.mana.get_current(), after_cast - granted,
		"the claw-back takes exactly the CLAMPED amount the grant actually applied, never the nominal "
		+ "`mana_per_kill * killed` (AC 14)")


## AC 15: the MANA floor -- a claw-back stops at 0 rather than going negative. Driven by spending the
## granted mana before the counter, so the claw-back genuinely has more to take than there is.
func test_the_mana_claw_back_is_clamped_at_zero() -> void:
	var ms := _make_match()
	ms.p2.units.add(MINION_HP, MINION_KIND)
	_victim_casts(ms, ID_CULLING)
	ms.p2.mana.spend(ms.p2.mana.get_current())
	assert_eq(ms.p2.mana.get_current(), 0.0, "sanity: the pool is empty before the counter")
	_counter(ms)
	assert_eq(ms.p2.mana.get_current(), 0.0,
		"the mana claw-back is clamped at a floor of 0 and never goes negative (AC 15)")


## AC 15: the HP floor -- a counter NEVER KILLS (`6-5f/R14`). Driven with a victim whose hp is below the
## amount Drain healed, so an unclamped claw-back would take them to zero or past it.
func test_the_hp_claw_back_never_kills_and_stops_at_one() -> void:
	var ms := _make_match()
	ms.p2.units.add(MINION_HP, MINION_KIND)
	ms.p2.hero.take_damage(MAX_HP - 20.0)         # 20 hp
	_victim_casts(ms, ID_DRAIN)                   # heals 12 -> 32 hp
	ms.p2.hero.take_damage(27.0)                  # down to 5, below the 12 about to be taken
	assert_eq(ms.p2.hero.get_hp(), 5.0, "sanity: less hp remains than the claw-back would take")
	_counter(ms)
	assert_eq(ms.p2.hero.get_hp(), 1.0,
		"the hp claw-back stops at a floor of 1 -- a counter never kills (AC 15, `6-5f/R14`)")
	assert_true(ms.p2.hero.is_alive(), "...and the victim is still alive")


## AC 15: the HP-REFUND ceiling -- a refund never overheals past the caster's current maximum. Driven by
## healing the Boom's victim back to full before the counter, so the refund has nowhere to go.
func test_the_hp_refund_never_overheals_past_max() -> void:
	var ms := _make_match()
	ms.p1.hand.cover_at(_slot_of(ms.p1, ID_WARD), BOULDER_CARD)
	_victim_activates(ms, ID_BOOM)
	assert_true(ms.p1.hero.get_hp() < MAX_HP, "sanity: the Boom really removed hp")
	ms.p1.hero.heal(MAX_HP)                       # back to full before the counter
	assert_eq(ms.p1.hero.get_hp(), MAX_HP, "sanity: the refund now has nowhere to go")
	_counter(ms)
	assert_eq(ms.p1.hero.get_hp(), MAX_HP,
		"the hp refund is clamped at the current maximum and never overheals (AC 15)")


# ------------------------------------------------------------------ AC 24/26/27/28: shared

## AC 24: Counterspell's own resolution consumes NO RNG. Asserted on the hashed `rng_state`, which is the
## only observable the stream has -- a drawn number moves it, and nothing else in the tick does.
func test_a_counterspell_resolution_consumes_no_rng() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_VANGUARD)
	_stage(ms, ID_COUNTER)
	var rng_before: Variant = ms.to_snapshot()["rng_state"]
	_activate(ms)
	assert_false(ms.p2.units.is_alive_at(0), "sanity: the reversal really happened on this tick")
	assert_eq(ms.to_snapshot()["rng_state"], rng_before,
		"the reversal drew NO random number -- the Boulder restoration re-covers the RECORDED slots "
		+ "rather than re-running the eligible-slot draw (AC 24)")


## AC 26 (`6-5f/R35`): the placeholder cue fires on a REAL reversal, carrying BOTH slots -- and fires on
## NO refusal of any kind. Both halves, because a cue that also fired on a refusal would pass a
## positive-only test.
func test_the_cue_fires_on_a_real_reversal_and_never_on_a_refusal() -> void:
	var reversed_match := _make_match()
	var fired: Array = []
	reversed_match.counterspell_resolved.connect(
		func(caster: int, countered: int) -> void: fired.append([caster, countered]))
	_victim_casts(reversed_match, ID_VANGUARD)
	_counter(reversed_match)
	assert_eq(fired, [[0, 1]],
		"exactly one cue, carrying the CASTER's slot and the COUNTERED player's slot (AC 26)")
	var refused := _make_match()
	var refused_fired: Array = []
	refused.counterspell_resolved.connect(
		func(caster: int, countered: int) -> void: refused_fired.append([caster, countered]))
	_counter(refused)   # nothing resolved: the no-target refusal
	assert_eq(refused_fired, [],
		"a refusal plays NO cue of any kind beyond the existing refusal channel (AC 26)")


## AC 28 (`6-5f/R5`): the reversal packet is cleared at BOTH per-round teardown seats, alongside the
## resolved-card record it rides with -- so no reversal state carries into a fresh round (smoke item 7).
func test_round_end_and_the_debug_reset_both_clear_the_reversal_packet() -> void:
	var resting := [PlayerState.REVERSAL_NONE, [], [], [], [], 0.0]
	# (a) the DEBUG RESET.
	var reset := _make_match()
	_victim_casts(reset, ID_VANGUARD)
	assert_ne(reset.p2.to_snapshot()["reversal"], resting, "sanity: a packet exists going in")
	var press := InputIntent.new()
	press.debug_reset = true
	_advance(reset, press, InputIntent.new())
	assert_eq(reset.p2.to_snapshot()["reversal"], resting, "the debug reset clears the packet (AC 28)")
	assert_eq(reset.p2.to_snapshot()["last_resolved_card"],
		["", PlayerState.NO_RESOLVED_MODE, PlayerState.NO_RESOLVED_TICK],
		"...and the record it rides with, tick included")
	# (b) ROUND END.
	var ended := _make_match()
	_victim_casts(ended, ID_VANGUARD)
	assert_ne(ended.p2.to_snapshot()["reversal"], resting, "sanity: a packet exists going in")
	ended.p2.hero.take_damage(MAX_HP)
	_idle(ended, 1)
	assert_eq(ended.p2.hero.action_state, HeroState.ActionState.DEAD, "sanity: the round ended")
	assert_eq(ended.p2.to_snapshot()["reversal"], resting, "round end clears the packet too (AC 28)")


## AC 27: `counterspell` resolves to a REAL outcome and the deferred table is empty. The census and the
## empty table's own behaviour are `test_spell_framework.gd`'s; what is asserted here is the end-to-end
## consequence -- an activation that used to be a shared no-op now does work.
func test_counterspell_is_no_longer_a_no_op_activation() -> void:
	assert_true(CardEffectResolver.DEFERRED_EFFECT_OWNERS.is_empty(), "the deferred table is empty (AC 27)")
	var ms := _make_match()
	_victim_casts(ms, ID_VANGUARD)
	var units_before := ms.p2.units.living_indices().size()
	_counter(ms)
	assert_ne(ms.p2.units.living_indices().size(), units_before,
		"the activation did REAL WORK rather than the shared deferred no-op (AC 27)")


## AC 25's regression surface, asserted where it is cheapest to state: with Counterspell never played,
## the five 6-5b effects resolve exactly as they did. A guard against this story's moved
## `record_resolved_card` call or its six new recorders having changed any of them.
func test_every_victim_card_still_resolves_normally_when_no_counterspell_is_played() -> void:
	var summon := _make_match()
	_victim_casts(summon, ID_VANGUARD)
	assert_eq(summon.p2.units.size(), 1, "the summon still summons")
	var culling := _make_match()
	culling.p2.units.add(MINION_HP, MINION_KIND)
	var mana_before := culling.p2.mana.get_current()
	_victim_casts(culling, ID_CULLING)
	assert_false(culling.p2.units.is_alive_at(0), "Culling still kills")
	assert_eq(culling.p2.mana.get_current(), mana_before - CAST_MANA + CULLING_MANA_PER_KILL,
		"...and still grants its mana")
	var ward := _make_match()
	ward.p2.units.add(MINION_HP, MINION_KIND)
	ward.p2.units.kill_at(0, CORPSE_TICKS)
	_victim_casts(ward, ID_WARD)
	# 49, not 50: step 2 of the cast tick ages the fresh 40-tick corpse to 39 before step 6 extends it.
	assert_eq(ward.p2.units.corpse_ticks_at(0), CORPSE_TICKS - 1 + WARD_TICKS,
		"Grave Ward still extends, additively and by its authored number")
	var raise := _make_match()
	raise.p2.units.add(MINION_HP, MINION_KIND)
	raise.p2.units.kill_at(0, CORPSE_TICKS)
	_victim_casts(raise, ID_RAISE)
	assert_eq(raise.p2.units.hp_at(1), MINION_HP * RAISE_PERCENT / 100.0,
		"Raise Dead still raises at `raise_hp_percent`, NOT at the pre-death hp -- the two numbers stay "
		+ "different, which is `6-5f/R29`'s whole point")
	var drain := _make_match()
	drain.p2.units.add(MINION_HP, MINION_KIND)
	drain.p2.hero.take_damage(30.0)
	var hp_before := drain.p2.hero.get_hp()
	_victim_casts(drain, ID_DRAIN)
	assert_eq(drain.p2.hero.get_hp(), hp_before + DRAIN_HEAL, "Drain still sacrifices and heals")


# ------------------------------------------------------------------ fixture

func _make_match(effects: Dictionary[StringName, CardEffect] = {}) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_feature_flags(_flags())
	ms.inject_deck(DECK)
	ms.inject_card_costs(_costs())
	ms.inject_card_effects(effects if not effects.is_empty() else _effects())
	ms.inject_pitch_costs(_costs())
	ms.inject_pitch_effects(effects if not effects.is_empty() else _effects())
	_idle(ms, 1)   # the step-6 deal
	for player: PlayerState in [ms.p1, ms.p2]:
		player.mana.add(START_MANA)
		player.orbs.add(Enums.CardColor.GREEN, ORB_PRICE * 4)
	ms.drain_signals()
	return ms


## The effect map with a POSITIVE `counter_window_seconds` on both Counterspell copies (AC 7).
func _windowed_effects(window_ticks: int) -> Dictionary[StringName, CardEffect]:
	var out := _effects()
	for id: StringName in [ID_COUNTER, ID_COUNTER_B]:
		(out[id] as CardEffect).counter_window_seconds = float(window_ticks) / TimingWindow.TICK_HZ
	return out


## P2 (THE VICTIM) resolves `id` as a Mode ① press -- the short path to `record_resolved_card`.
func _victim_casts(ms: MatchState, id: StringName) -> void:
	_advance(ms, InputIntent.new(), _cast_intent(_slot_of(ms.p2, id)))


## P2 (THE VICTIM) resolves `id` as a Mode ④ ACTIVATION -- Boom's own path, since it acts on the
## opposing hand and its 6-5e seat is the activation.
func _victim_activates(ms: MatchState, id: StringName) -> void:
	_advance(ms, InputIntent.new(), _stage_intent(_slot_of(ms.p2, id)))
	_advance(ms, InputIntent.new(), _activate_intent())


## P1 (THE COUNTERER) resolves `id` as a Mode ① press -- used only to give P2 something to counter.
func _caster_casts(ms: MatchState, id: StringName) -> void:
	_advance(ms, _cast_intent(_slot_of(ms.p1, id)), InputIntent.new())


## P1 stages and activates Counterspell: the real two-press Mode ④ sequence, two ticks.
func _counter(ms: MatchState) -> void:
	_counter_with(ms, ID_COUNTER)


func _counter_with(ms: MatchState, id: StringName) -> void:
	_advance(ms, _stage_intent(_slot_of(ms.p1, id)), InputIntent.new())
	_advance(ms, _activate_intent(), InputIntent.new())


## The same sequence driven by P2 instead, for AC 9's Counterspell-against-a-Counterspell case.
func _counter_by(ms: MatchState, slot: int) -> void:
	var player: PlayerState = ms.p1 if slot == 0 else ms.p2
	var stage := _stage_intent(_slot_of(player, ID_COUNTER))
	if slot == 0:
		_advance(ms, stage, InputIntent.new())
		_advance(ms, _activate_intent(), InputIntent.new())
	else:
		_advance(ms, InputIntent.new(), stage)
		_advance(ms, InputIntent.new(), _activate_intent())


func _stage(ms: MatchState, id: StringName) -> void:
	_advance(ms, _stage_intent(_slot_of(ms.p1, id)), InputIntent.new())


func _activate(ms: MatchState) -> void:
	_advance(ms, _activate_intent(), InputIntent.new())


## How far P1's staged card's FIZZLE COUNTDOWN has run, read off the hashed snapshot -- the
## `test_own_minion_spells.gd` helper verbatim, and for its stated reason (`PitchState` exposes no public
## remaining-ticks reader, and adding one for a test would widen the production surface).
func _fizzle_elapsed(ms: MatchState) -> int:
	var zone: Dictionary = (ms.pitch.to_snapshot()["p1"] as Dictionary)
	return int((zone["fizzle"] as Dictionary)["elapsed_ticks"])


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.move_speed = 5.0
	c.walk_speed = 2.5
	c.max_stamina = MAX_STAMINA
	c.max_mana = MAX_MANA
	c.deck_size = DECK.size()
	c.hand_size = DECK.size()
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 3.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 6.0
	c.block_facing_arc_degrees = 180.0
	c.hero_damage_to_unit = 3.0
	c.minion_retarget_interval_seconds = 1000.0
	c.corpse_lifetime_seconds = CORPSE_SECONDS
	# Long enough that no staged card fizzles inside any test here -- the AC 11 refusal test needs the
	# countdown RUNNING rather than closed, which is a different fact from being long.
	c.pitch_stage_timer_seconds = 30.0
	c.max_orbs_per_color = 99
	c.unit_kinds = [UnitKindFixture.melee(CardEffectResolver.KIND_MINION, MINION_HP, MINION_DAMAGE,
			2, 3, 4, 2.0)] as Array[UnitKindProfile]
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.orbs = true
	f.pitch_zone = true
	f.minions = true
	f.totems = true
	f.spells = true
	return f


## `BOULDER_CARD` IS PRICED TOO, and it has to be: a Mode ① press on a covered slot resolves the VISIBLE
## id (6-5e AC 21a), so the Boulder itself reaches the cost lookup. An unpriced Boulder is refused before
## the cover fork and the AC 8 test would then be asserting about a press that never happened.
func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	var priced: Array[StringName] = DECK.duplicate()
	priced.append(BOULDER_CARD)
	for id in priced:
		var c := CardCastCondition.new()
		c.mana_cost = CAST_MANA
		c.orb_costs = {Enums.CardColor.GREEN: ORB_PRICE} as Dictionary[Enums.CardColor, int]
		out[id] = c
	return out


## THE EFFECT MAP, injected as BOTH the Mode ① and the Mode ④ map (the `test_own_minion_spells.gd`
## fixture shape): a card resolves the same effect whichever mode drives it, so each test can pick the
## shorter path without the map having to model two.
##
## `BOULDER_CARD` IS IN THE MAP AND NOT IN THE DECK, deliberately: `MatchState.inject_card_effects`
## derives `_boulder_card_id` by scanning the MAP for the cover-clearing effect, and the Boulder is never
## dealt -- it only ever arrives in a hand as a cover. That is exactly its production shape.
func _effects() -> Dictionary[StringName, CardEffect]:
	var ids := {
		ID_COUNTER: &"counterspell", ID_COUNTER_B: &"counterspell",
		ID_VANGUARD: &"summon_ruin_vanguard", ID_CULLING: &"culling", ID_WARD: &"grave_ward",
		ID_RAISE: &"raise_dead", ID_DRAIN: &"drain", ID_BOOM: &"boom", ID_BOLT: &"honed_bolt",
	}
	var out: Dictionary[StringName, CardEffect] = {}
	for id: StringName in ids:
		var e := CardEffect.new()
		e.effect_id = ids[id]
		match e.effect_id:
			&"grave_ward":
				e.duration_seconds = WARD_SECONDS
			&"culling":
				e.mana_per_kill = CULLING_MANA_PER_KILL
				e.kill_cap = 99
			&"raise_dead":
				e.raise_hp_percent = RAISE_PERCENT
			&"drain":
				e.heal_amount = DRAIN_HEAL
			&"boom":
				e.damage_amount = BOOM_DAMAGE
		out[id] = e
	var boulder := CardEffect.new()
	boulder.effect_id = &"boulder_discard"
	out[BOULDER_CARD] = boulder
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


func _slot_of(player: PlayerState, id: StringName) -> int:
	var hand := player.hand.to_array()
	for index in hand.size():
		if not player.hand.is_slot_empty(index) and hand[index] == id:
			return index
	assert_true(false, "fixture: %s is in the dealt hand" % id)
	return -1


func _rejections(player: PlayerState) -> Array:
	var out: Array = []
	player.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: out.append([action, reason]))
	return out


func _idle(ms: MatchState, n: int) -> void:
	for _t in n:
		_advance(ms, InputIntent.new(), InputIntent.new())


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
