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
const ID_BOLT := &"cs_bolt"
const BOULDER_CARD := &"cs_boulder"       # in the EFFECT MAP only, never in the deck

## Story 6-5g: the SEVEN newly counterable cards, each with its own opaque id (`ID_BOLT` above was already
## here as `6-5f`'s interim-rule fixture and becomes this story's Honed Bolt).
const ID_AURA := &"cs_aura"
const ID_HOUND := &"cs_hound"
const ID_FROST := &"cs_frost"
const ID_FIRE := &"cs_fire"
const ID_SLING := &"cs_sling"
const ID_BOMB := &"cs_bomb"
## REVIEW FIX (m2/m3, `6-5g/R22`): a SECOND live copy of Frostbite and of Rocksling, each its own opaque id --
## the two cards the review found under-driven for copy discrimination (`6-5g/R10`), each now exercised with
## a real second cast rather than argued from the mechanism alone.
const ID_FROST_B := &"cs_frost_b"
const ID_SLING_B := &"cs_sling_b"

const DECK: Array[StringName] = [ID_COUNTER, ID_COUNTER_B, ID_VANGUARD, ID_CULLING, ID_WARD,
		ID_RAISE, ID_DRAIN, ID_BOOM, ID_BOLT, ID_AURA, ID_HOUND, ID_FROST, ID_FIRE, ID_SLING, ID_BOMB,
		ID_FROST_B, ID_SLING_B]

## Story 6-5g's in-test numbers. Every one is distinct from every other and from `6-5f`'s above, so a value
## read off the wrong field lands on a number no assertion expects.
const AURA_TICKS := 40
const AURA_LIFESTEAL := 0.5
const HOUND_TICKS := 40
const HOUND_DISTANCE_MULT := 3.0
const HOUND_IFRAME_MULT := 2.0
const FROST_TICKS := 40
const FROST_SLOW := 0.5
const FROST_SLOW_TICKS := 25
const BOLT_CAST_TICKS := 8
const BOLT_DAMAGE := 7.0
const BOLT_STUN_TICKS := 14
const BOLT_ROOT_TICKS := 11
const FIRE_CAST_TICKS := 6
const FIRE_MANA_CAP := 4.0
const FIRE_DAMAGE_PER_MANA := 3.0         # 4 mana x 3 == 12.0 locked damage
const FIRE_DAMAGE := FIRE_MANA_CAP * FIRE_DAMAGE_PER_MANA
const SLING_CAST_TICKS := 4
const SLING_DAMAGE := 5.0
const SLING_STONES := 3
const SLING_INTERVAL_TICKS := 20
const BOMB_DAMAGE := 8.0
const LAUNCH_SPEED := 8.0
const TRAVEL_BUDGET := 2.0                # ~15 ticks of flight: long enough to counter, short enough to whiff
const ROLL_TICKS := 18
const ROLL_IFRAME_TICKS := 12
const ROLL_DISTANCE := 3.0
const ROLL_COST := 5.0

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


## STORY 6-5g (AC 2, `6-5g/R1`): `test_a_6_5g_card_is_refused_through_the_same_no_target_path` STOOD HERE
## and is DELETED, which is one of the exactly three textual artifacts the interim rule consisted of (the
## others are `6-5f` AC 13's own text and `6-5f`'s Live Smoke point 6). It asserted that a resolved Honed
## Bolt leaves `REVERSAL_NONE` and is refused; a Honed Bolt now writes `REVERSAL_HONED_BOLT` and is
## counterable in every phase, which this file's own Class 2 cases below prove in its place.


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


# ================================================================== STORY 6-5g
#
# THE SEVEN TIMED / IN-FLIGHT CARDS. Same standpoint as everything above: **P2 resolves the card, P1
# counters it.** The Class 2 cards are driven as Mode (1) presses except Fireball, whose damage is LOCKED AT
# STAGING (`6-5d` AC 7) and is therefore zero on a Mode (1) press -- so Fireball is driven through its real
# Mode (4) staging, which is also its shipped shape.

# ------------------------------------------------------------------ AC 4-8: Class 1, the timed buffs

## AC 4 (`6-5g/R2`): countering a Vampiric Aura ENDS the rule, and the hp it already healed STAYS healed.
## Both halves, because a reversal that also clawed the healing back would pass a rule-only test.
func test_countering_a_vampiric_aura_ends_the_rule_and_leaves_the_healing_done() -> void:
	var ms := _make_match()
	ms.p2.hero.take_damage(40.0)
	_victim_casts(ms, ID_AURA)
	assert_true(ms.p2.is_rule_active(PlayerState.RULE_VAMPIRIC_AURA), "sanity: the aura is running")
	var before_heal := ms.p2.hero.get_hp()
	_victim_hits_counterer(ms)
	var healed := ms.p2.hero.get_hp() - before_heal
	assert_true(healed > 0.0, "sanity: the aura healed off a real hit (%f)" % healed)
	var hp_at_counter := ms.p2.hero.get_hp()
	_counter(ms)
	assert_false(ms.p2.is_rule_active(PlayerState.RULE_VAMPIRIC_AURA),
		"the running rule ends immediately (AC 4)")
	assert_eq(ms.p2.hero.get_hp(), hp_at_counter,
		"...and the hp it already healed STAYS healed -- nothing is clawed back for a timed buff (AC 4)")
	var before_second := ms.p2.hero.get_hp()
	_victim_hits_counterer(ms)
	assert_eq(ms.p2.hero.get_hp(), before_second,
		"...and no FURTHER hit heals, which is what 'the rule ended' means behaviourally")


## AC 5 (`6-5g/R4`): countering a Frostbite whose trigger is still ARMED disarms it -- the caster's next
## confirmed hero melee hit applies no slow. Proven through the real trigger seat, not by reading the rule.
func test_countering_an_armed_frostbite_disarms_the_trigger() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_FROST)
	assert_true(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED), "sanity: the trigger is armed")
	_counter(ms)
	assert_false(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED),
		"the armed trigger is disarmed (AC 5)")
	_victim_hits_counterer(ms)
	assert_false(ms.p1.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW),
		"...so the next confirmed hero melee hit applies NO slow (AC 5)")


## AC 6 (`6-5g/R4`): countering a Frostbite whose trigger has already been CONSUMED ends the running slow --
## on the OTHER player, which is the cross-player read the ruling names.
func test_countering_a_consumed_frostbite_ends_the_running_slow_on_the_struck_hero() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_FROST)
	_victim_hits_counterer(ms)
	assert_true(ms.p1.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW),
		"sanity: the hit consumed the trigger and started the slow on P1")
	assert_false(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED), "sanity: the trigger is spent")
	_counter(ms)
	assert_false(ms.p1.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW),
		"the running slow ends immediately, on the STRUCK player's own rule slot (AC 6)")
	assert_eq(ms.p1.rule_a[PlayerState.RULE_FROSTBITE_SLOW], 0.0,
		"...through `cancel_rule`, the one stop point -- so the magnitude is gone too, not merely gated")


## REVIEW FIX m2 (`6-5g/R22`): the victim resolves Frostbite TWICE. The FIRST resolution's hit consumes its
## own trigger and starts the running slow; the SECOND resolution is countered while still ARMED. The
## counter disarms the second, and the slow the FIRST resolution placed keeps running -- the cross-resolution
## over-reach the review found (an unconditional cancel would end it regardless of which resolution placed
## it, since the two share one rule slot).
func test_countering_a_second_armed_frostbite_disarms_it_and_leaves_the_first_slow_running() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_FROST)
	_victim_hits_counterer(ms)
	assert_true(ms.p1.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW),
		"sanity: the FIRST resolution's hit consumed its trigger and started the slow on P1")
	assert_false(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED), "sanity: its own trigger is spent")
	_victim_casts(ms, ID_FROST_B)
	assert_true(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED),
		"sanity: the SECOND resolution re-arms the trigger")
	assert_true(ms.p1.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW),
		"sanity: re-casting did not touch the FIRST resolution's already-running slow")
	_counter(ms)
	assert_false(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED),
		"the SECOND (still-armed) resolution's trigger is disarmed (AC 5)")
	assert_true(ms.p1.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW),
		"...and the FIRST resolution's slow is LEFT RUNNING -- it is not this counter's to end (m2)")


## AC 7 (`6-5g/R5`): BOTH halves of the Bloodhound case in one test, because the second is only meaningful
## beside the first.
##   (a) countered while ARMED, before any roll -> the next roll is UNBOOSTED;
##   (b) countered MID-ROLL -> the roll is untouched.
##
## REVIEW FIX m1 (`6-5g/R23`): (b)'s equality holds BY CONSTRUCTION, not by comparison -- mid-roll there is no
## armed window left TO expire (`RULE_BLOODHOUND_ARMED` is already cancelled at roll ENTRY, before either
## fixture's own idle or counter runs), so nothing here measures "a counter equals a natural expiry". The
## `expired` fixture is an UNTOUCHED comparison arm (two idle ticks against a 40-tick window, with the armed
## trigger already gone before the idle even starts), not a natural expiry actually happening. What the
## three-way comparison (boost liveness, velocity, remaining i-frames) DOES prove is the AC's real claim: that
## Counterspell's own arm -- which deliberately never names `RULE_ROLL_BOOST` -- changes nothing a roll
## already under way would not also finish unchanged on its own.
func test_countering_a_bloodhound_step_disarms_it_and_leaves_a_running_roll_alone() -> void:
	var plain_speed := ROLL_DISTANCE / (float(ROLL_TICKS) / TimingWindow.TICK_HZ)
	# (a) countered while armed: the next roll is an ordinary roll.
	var armed := _make_match()
	_victim_casts(armed, ID_HOUND)
	assert_true(armed.p2.is_rule_active(PlayerState.RULE_BLOODHOUND_ARMED), "sanity: armed")
	_counter(armed)
	assert_false(armed.p2.is_rule_active(PlayerState.RULE_BLOODHOUND_ARMED),
		"the armed trigger is cancelled (AC 7)")
	_advance(armed, InputIntent.new(), _roll_intent())
	assert_almost_eq(armed.p2.hero.velocity.length(), plain_speed, 0.0001,
		"...so the next roll is UNBOOSTED (AC 7)")
	assert_eq(armed.p2.hero.roll_iframe.duration_ticks(), ROLL_IFRAME_TICKS,
		"...with ordinary i-frames, not the multiplied count")
	# (b) countered mid-roll, against the SAME fixture left to expire naturally instead.
	var countered := _make_match()
	var expired := _make_match()
	for ms: MatchState in [countered, expired]:
		_victim_casts(ms, ID_HOUND)
		_advance(ms, InputIntent.new(), _roll_intent())
		assert_almost_eq(ms.p2.hero.velocity.length(), plain_speed * HOUND_DISTANCE_MULT, 0.0001,
			"sanity: the roll entered BOOSTED")
		assert_false(ms.p2.is_rule_active(PlayerState.RULE_BLOODHOUND_ARMED),
			"sanity: roll entry already cancelled the armed trigger (`6-5g/R5`, re-measured)")
		assert_true(ms.p2.is_rule_active(PlayerState.RULE_ROLL_BOOST), "sanity: the boost is latched")
	_counter(countered)
	_idle(expired, 2)   # the same two ticks the stage-and-activate pair costs
	assert_eq(countered.p2.is_rule_active(PlayerState.RULE_ROLL_BOOST),
		expired.p2.is_rule_active(PlayerState.RULE_ROLL_BOOST),
		"a counter mid-roll leaves the latched boost exactly as the untouched comparison arm does -- BY "
		+ "CONSTRUCTION, since neither arm has an armed window left to touch (AC 7, m1)")
	assert_almost_eq(countered.p2.hero.velocity.length(), expired.p2.hero.velocity.length(), 0.0001,
		"...the roll's velocity is identical in both")
	assert_eq(countered.p2.hero.roll_iframe.remaining_ticks(),
		expired.p2.hero.roll_iframe.remaining_ticks(),
		"...and so are its remaining i-frames: the counter did nothing to the running roll")


## AC 8 (`6-5g/R3`): a timed buff whose window has ALREADY run out counts as no target and is refused
## through the standing gate -- AC 31's arms in the negative direction. Proven for the Aura (its window
## elapsed) and for Frostbite's armed-then-expired trigger, the two cases AC 8 names.
func test_a_timed_buff_whose_window_has_already_run_out_is_refused() -> void:
	for id: StringName in [ID_AURA, ID_FROST]:
		var ms := _make_match()
		_victim_casts(ms, id)
		_idle(ms, AURA_TICKS + 1)
		var rejections := _rejections(ms.p1)
		_counter(ms)
		assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_COUNTER_TARGET]],
			"%s with its window already elapsed is NO TARGET, refused through the standing gate with no "
			% id + "new reason (AC 8)")


# ------------------------------------------------------------------ AC 9-13: Class 2, cast and interrupt

## AC 9 (`6-5g/R6`): the target is named at CAST START and the window is measured from THAT tick, not from
## the strike. Proven by a window shorter than the cast: a counter fired two ticks AFTER the bolt struck is
## inside the window measured from the strike and outside it measured from the press -- and it is refused.
func test_the_class_2_window_is_measured_from_cast_start_and_not_from_the_strike() -> void:
	var window := 4
	var ms := _make_match(_windowed_effects(window))
	# The bolt is aimed at a MINION, not at P1's hero, and that is fixture necessity rather than colour: a
	# bolt that stunned P1 would leave P1 unable to press Counterspell at all (`REASON_STUNNED` at both
	# presses), so the refusal under test could not be told from a stun refusal.
	ms.p1.units.add(MINION_HP, MINION_KIND)
	ms.p2.lock_target_slot = 0
	ms.p2.lock_target_index = 0
	_victim_casts(ms, ID_BOLT)
	assert_eq((ms.p2.to_snapshot()["last_resolved_card"] as Array)[0], String(ID_BOLT),
		"the record names the bolt at the PRESS, before the cast frame (AC 9)")
	assert_eq(int((ms.p2.to_snapshot()["reversal"] as Array)[0]), PlayerState.REVERSAL_HONED_BOLT,
		"...and the packet already names its kind, which is what makes a mid-cast counter possible (AC 10)")
	_idle(ms, BOLT_CAST_TICKS)
	assert_false(ms.p2.is_casting(), "sanity: the cast has struck")
	assert_true(ms.p1.units.hp_at(0) < MINION_HP, "sanity: the bolt landed on the minion")
	var rejections := _rejections(ms.p1)
	_counter(ms)
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_COUNTER_TARGET]],
		"the age is measured from the CAST START, so a %d-tick window is already past (AC 9)" % window)


## AC 11/AC 12/AC 13 (`6-5g/R7`): countering a cast in progress ends it immediately, the caster is free to
## act that same tick, no damage lands and no projectile is ever created -- and the caster is NOT stunned,
## which is the test AC 12 asks for by name.
func test_countering_a_cast_in_progress_interrupts_it_with_no_strike_and_no_stun() -> void:
	var ms := _make_match()
	var mana_before := ms.p2.mana.get_current()
	_victim_casts(ms, ID_BOLT)
	assert_true(ms.p2.is_casting(), "sanity: the cast is running")
	var discard_before := ms.p2.discard.size()
	_counter(ms)
	assert_false(ms.p2.is_casting(), "the cast ends immediately (AC 11)")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE,
		"the interrupted caster is FREE the same tick and is NOT sent to STUNNED (AC 11/AC 12)")
	assert_false(ms.p2.hero.stun.is_running, "...with no stun window either")
	assert_eq(ms.p1.hero.get_hp(), MAX_HP, "...no damage landed (AC 11)")
	assert_eq(ms.p2.projectiles.size(), 0, "...and no projectile was ever created (AC 11)")
	assert_eq(ms.p2.discard.size(), discard_before,
		"the caster's CARD stays lost -- it is not returned to hand or deck (AC 13)")
	assert_eq(ms.p2.mana.get_current(), mana_before - CAST_MANA,
		"...and its mana stays spent (AC 13, `6-5c/R3` read from the counter's side)")
	# The caster really can act: a press on the very next tick resolves.
	_idle(ms, BOLT_CAST_TICKS + 2)
	assert_eq(ms.p1.hero.get_hp(), MAX_HP,
		"...and the cast that was interrupted never strikes later either")


## AC 18 (`6-5g/R3`): a Class 2 card that whiffed entirely leaves nothing to reverse. Both of the AC's
## shapes: a cast interrupted by a STUN before it struck, and a Fireball that expired at its travel budget
## without ever landing.
func test_a_whiffed_class_2_card_is_refused_as_no_target() -> void:
	var stunned := _make_match()
	_victim_casts(stunned, ID_BOLT)
	stunned.p2.hero.start_stun(4, false)
	stunned.p2.hero.set_action_state(HeroState.ActionState.STUNNED)
	_idle(stunned, 1)
	assert_false(stunned.p2.is_casting(), "sanity: the stun interrupted the cast before it struck")
	var stun_rejections := _rejections(stunned.p1)
	_counter(stunned)
	assert_eq(stun_rejections, [[&"card_cast", MatchState.REASON_NO_COUNTER_TARGET]],
		"a cast interrupted by a stun produced nothing: refused as no-target (AC 18)")
	var expired := _make_match()
	_victim_activates(expired, ID_FIRE)
	_idle(expired, FIRE_CAST_TICKS)
	assert_eq(expired.p2.projectiles.size(), 1, "sanity: the ball was launched")
	var ceiling := 0
	while expired.p2.projectiles.is_alive_at(0) and ceiling < 200:
		_idle(expired, 1)
		ceiling += 1
	assert_false(expired.p2.projectiles.is_alive_at(0),
		"sanity: the ball expired at its travel budget without landing")
	var flight_rejections := _rejections(expired.p1)
	_counter(expired)
	assert_eq(flight_rejections, [[&"card_cast", MatchState.REASON_NO_COUNTER_TARGET]],
		"a ball that expired in the air took nothing and left nothing: refused (AC 18)")


## AC 10: the packet is a LIVING RECORD -- what a counter DOES depends on how far the cast has progressed.
## One card (Fireball), all four states, each proven by its own observable consequence.
func test_the_class_2_packet_is_a_living_record_across_all_four_cast_states() -> void:
	# (1) STILL CASTING: the cast is interrupted and no ball is ever created.
	var casting := _make_match()
	_victim_activates(casting, ID_FIRE)
	assert_true(casting.p2.is_casting(), "sanity: mid-cast")
	_counter(casting)
	assert_false(casting.p2.is_casting(), "still casting -> the cast is interrupted (AC 10)")
	assert_eq(casting.p2.projectiles.size(), 0, "...and no ball exists")
	# (2) IN FLIGHT: the ball vanishes.
	var flying := _make_match()
	_victim_activates(flying, ID_FIRE)
	_idle(flying, FIRE_CAST_TICKS)
	assert_true(flying.p2.projectiles.is_alive_at(0), "sanity: the ball is in the air")
	_counter(flying)
	assert_false(flying.p2.projectiles.is_alive_at(0), "in flight -> the ball vanishes (AC 10/AC 16)")
	assert_eq(flying.p1.hero.get_hp(), MAX_HP, "...and nothing further happens on its account")
	# (3) LANDED: the hp it actually removed comes back.
	var landed := _make_match()
	_victim_activates(landed, ID_FIRE)
	_idle(landed, FIRE_CAST_TICKS)
	_victim_shot_lands(landed, 0)
	assert_almost_eq(landed.p1.hero.get_hp(), MAX_HP - FIRE_DAMAGE, 0.0001,
		"sanity: the ball landed for its locked damage")
	_counter(landed)
	assert_almost_eq(landed.p1.hero.get_hp(), MAX_HP, 0.0001,
		"landed -> the hp ACTUALLY removed is refunded (AC 10/AC 15)")
	# (4) NOTHING LEFT: covered by `test_a_whiffed_class_2_card_is_refused_as_no_target` above, which is the
	# same fourth state read as a refusal -- the only observable a state with nothing left HAS.


# ------------------------------------------------------------------ AC 14-17: the landed and in-flight arms

## AC 14 (`6-5g/R8`): countering a LANDED Honed Bolt refunds the hp it actually removed and ends the ROOT it
## placed.
##
## THE STUN HALF OF AC 14 IS NOT ASSERTED HERE, AND THE REASON IS STRUCTURAL RATHER THAN AN OMISSION: with
## two players, the bolt's target is the ONLY player who could counter it, and a bolt-STUNNED hero's
## Counterspell is refused at both presses (`REASON_STUNNED`) -- so no reachable state has a bolt stun
## running at the moment a counter resolves. The arm still stops the stun window (it is the same statement
## that clears `stun_is_bolt`, and a later story with a third party or a shorter refusal makes it
## observable); the dev pass reports that line as a deliberately unobservable mutation rather than claiming
## a proof it cannot have. The ROOT outlives the stun (14 + 11 ticks against 14), which is what makes the
## other half of the clause provable at all.
func test_countering_a_landed_honed_bolt_refunds_the_hp_and_ends_the_root() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_BOLT)
	_idle(ms, BOLT_CAST_TICKS)
	assert_almost_eq(ms.p1.hero.get_hp(), MAX_HP - BOLT_DAMAGE, 0.0001, "sanity: the bolt landed")
	assert_true(ms.p1.hero.stun.is_running, "sanity: it stunned")
	assert_true(ms.p1.root_window.is_running, "sanity: and rooted")
	_idle(ms, BOLT_STUN_TICKS)   # the stun runs out; the root has not
	assert_false(ms.p1.hero.stun.is_running, "sanity: the stun expired naturally")
	assert_true(ms.p1.root_window.is_running, "sanity: the root is still running")
	_counter(ms)
	assert_almost_eq(ms.p1.hero.get_hp(), MAX_HP, 0.0001,
		"the hp ACTUALLY removed is refunded (AC 14)")
	assert_false(ms.p1.root_window.is_running, "the root the strike placed ends immediately (AC 14)")
	assert_false(ms.p1.is_root_blocking_roll(),
		"...so the rooted hero may act again that same tick")


## AC 21: the hp refund is clamped at max hp and NEVER overheals -- the case a refund landing on a hero
## healed since would otherwise break. `HeroState.heal`'s own clamp, reused rather than re-derived.
func test_a_landed_bolt_refund_never_overheals_past_max() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_BOLT)
	_idle(ms, BOLT_CAST_TICKS)
	assert_almost_eq(ms.p1.hero.get_hp(), MAX_HP - BOLT_DAMAGE, 0.0001, "sanity: the bolt landed")
	ms.p1.hero.heal(BOLT_DAMAGE)   # healed back to full in between, so the refund has nowhere to go
	_counter(ms)
	assert_almost_eq(ms.p1.hero.get_hp(), MAX_HP, 0.0001,
		"a refund on a hero already at max hp stops at max -- no overheal (AC 21)")


## AC 17 (`6-5g/R9`/`R10`): ROCKSLING's whole set, in one resolution that has all four parts live at the
## moment of the counter -- one stone landed (and its Boulder planted), one stone in the air, one stone
## still owed. Every clause of AC 17 is asserted separately.
func test_countering_a_rocksling_refunds_landed_vanishes_flying_cancels_owed_and_lifts_its_boulder() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_SLING)
	_idle(ms, SLING_CAST_TICKS)
	assert_eq(ms.p2.projectiles.size(), 1, "sanity: the first stone left at the strike")
	_victim_shot_lands(ms, 0)
	assert_almost_eq(ms.p1.hero.get_hp(), MAX_HP - SLING_DAMAGE, 0.0001, "sanity: it landed")
	assert_eq(ms.p1.hand.cover_count(), 1, "sanity: and planted one Boulder in P1's hand")
	var covered_slot: int = ms.p1.hand.covered_indices()[0]
	_idle(ms, SLING_INTERVAL_TICKS)
	assert_eq(ms.p2.projectiles.size(), 2, "sanity: the second stone launched")
	assert_true(ms.p2.projectiles.is_alive_at(1), "sanity: and is in the air")
	assert_true(ms.p2.has_pending_burst(), "sanity: with the third still owed")
	_counter(ms)
	assert_almost_eq(ms.p1.hero.get_hp(), MAX_HP, 0.0001,
		"the landed stone's damage is refunded, summed and clamped once (AC 17)")
	assert_false(ms.p2.projectiles.is_alive_at(1), "the stone in the air vanishes (AC 16/AC 17)")
	assert_false(ms.p2.has_pending_burst(), "the unfired stone is cancelled (AC 17)")
	assert_eq(ms.p1.hand.cover_count(), 0,
		"the Boulder THIS cast planted is removed and its card is playable again (AC 17)")
	assert_false(ms.p1.hand.is_covered(covered_slot), "...from the very slot it covered")
	_idle(ms, SLING_INTERVAL_TICKS + 2)
	assert_eq(ms.p2.projectiles.size(), 2,
		"...and no further stone launches after the cancellation")


## AC 17's SUM: two landed stones refund ONE heal of the total, not two separate refunds -- the `amount`
## column's own convention (`REVERSAL_BOOM`'s, extended). Proven by the arithmetic: the hero is back to
## exactly full after two stones' worth of damage.
func test_two_landed_stones_refund_their_summed_total_once() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_SLING)
	_idle(ms, SLING_CAST_TICKS)
	_victim_shot_lands(ms, 0)
	_idle(ms, SLING_INTERVAL_TICKS)
	_victim_shot_lands(ms, 1)
	assert_almost_eq(ms.p1.hero.get_hp(), MAX_HP - 2.0 * SLING_DAMAGE, 0.0001,
		"sanity: two stones landed")
	assert_almost_eq(float((ms.p2.to_snapshot()["reversal"] as Array)[5]), 2.0 * SLING_DAMAGE, 0.0001,
		"the packet carries the SUMMED hp actually removed (AC 17)")
	_counter(ms)
	assert_almost_eq(ms.p1.hero.get_hp(), MAX_HP, 0.0001,
		"...and the refund is one heal of that total (AC 17/AC 21)")


## AC 17's LAST CLAUSE: a Boulder from this cast that is ALREADY GONE is left alone, and the mana paid to
## clear it is NOT refunded (`6-5f/R15` applied to the cover layer). Both halves.
func test_a_boulder_already_cleared_is_left_alone_and_its_clearing_mana_is_not_refunded() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_SLING)
	_idle(ms, SLING_CAST_TICKS)
	_victim_shot_lands(ms, 0)
	var covered_slot: int = ms.p1.hand.covered_indices()[0]
	# P1 plays the Boulder off the slot: its own separate spend, at its own price.
	var mana_before := ms.p1.mana.get_current()
	_advance(ms, _cast_intent(covered_slot), InputIntent.new())
	assert_false(ms.p1.hand.is_covered(covered_slot), "sanity: the Boulder was cleared by playing it")
	assert_eq(ms.p1.mana.get_current(), mana_before - CAST_MANA, "sanity: clearing it cost mana")
	var mana_at_counter := ms.p1.mana.get_current()
	_counter(ms)
	assert_eq(ms.p1.mana.get_current(), mana_at_counter - CAST_MANA,
		"the mana paid to clear a Boulder is NOT refunded by the reversal: P1 is down exactly the "
		+ "Counterspell's own staging cost and nothing came back (AC 17)")
	assert_false(ms.p1.hand.is_covered(covered_slot),
		"...and the cleared Boulder is not re-planted either -- reverse what is LEFT (AC 17)")


## REVIEW FIX m3 (`6-5g/R10`): TWO LIVE ROCKSLING COPIES, exercised rather than argued by reading. The
## victim casts Rocksling #1 (one stone lands and plants a Boulder, one is in flight, one still owed), then
## casts Rocksling #2 and is countered MID-CAST of #2. #2's cast is interrupted; #1's own products -- its
## pending burst, its in-flight stone and its planted Boulder -- are all untouched, because the fresh packet
## #2 opened at its own press holds no parts of #1's at all (`_reversal_kind_of_shot`'s recorded-index
## discrimination is the same mechanism; this is the Rocksling-specific half m3 found untested).
func test_countering_a_second_rocksling_mid_cast_leaves_the_first_casts_products_untouched() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_SLING)
	_idle(ms, SLING_CAST_TICKS)
	assert_eq(ms.p2.projectiles.size(), 1, "sanity: the first stone left at the strike")
	_victim_shot_lands(ms, 0)
	assert_eq(ms.p1.hand.cover_count(), 1, "sanity: and planted one Boulder in P1's hand")
	var covered_slot: int = ms.p1.hand.covered_indices()[0]
	_idle(ms, SLING_INTERVAL_TICKS)
	assert_eq(ms.p2.projectiles.size(), 2, "sanity: the second stone launched")
	assert_true(ms.p2.projectiles.is_alive_at(1), "sanity: and is in the air")
	assert_true(ms.p2.has_pending_burst(), "sanity: with the third still owed")
	_victim_casts(ms, ID_SLING_B)
	assert_true(ms.p2.is_casting(), "sanity: the SECOND copy's cast is running")
	assert_eq(int((ms.p2.to_snapshot()["reversal"] as Array)[0]), PlayerState.REVERSAL_ROCKSLING,
		"sanity: the packet now describes the SECOND cast, opened fresh at its own press")
	_counter(ms)
	assert_false(ms.p2.is_casting(), "the SECOND cast is interrupted (AC 11, m3)")
	assert_true(ms.p2.has_pending_burst(),
		"...the FIRST cast's pending burst is untouched: the fresh packet holds no PART_BURST of its own (m3)")
	assert_true(ms.p2.projectiles.is_alive_at(1),
		"...the FIRST cast's in-flight stone is untouched (m3)")
	assert_true(ms.p1.hand.is_covered(covered_slot),
		"...and the Boulder the FIRST cast planted stays covering (m3)")


# ------------------------------------------------------------------ AC 19-20: Class 3, Corpse Bomb

## AC 19/AC 20 (`6-5g/R12`): countering a Corpse Bomb vanishes the skulls still in flight, refunds what a
## landed skull actually removed, and raises every converted minion from its own corpse at its PRE-DEATH hp.
func test_countering_a_corpse_bomb_vanishes_skulls_refunds_landed_and_raises_the_minions() -> void:
	var ms := _make_match()
	ms.p2.units.add(MINION_HP, MINION_KIND)
	ms.p2.units.add(MINION_HP, MINION_KIND)
	ms.p2.units.apply_damage_at(1, 4.0, CORPSE_TICKS)   # so its pre-death hp is DISTINCT from the maximum
	var wounded_hp := ms.p2.units.hp_at(1)
	_victim_casts(ms, ID_BOMB)
	assert_false(ms.p2.units.is_alive_at(0), "sanity: both minions were converted")
	assert_false(ms.p2.units.is_alive_at(1), "sanity: including the wounded one")
	assert_eq(ms.p2.projectiles.size(), 2, "sanity: two skulls in the air")
	_victim_shot_lands(ms, 0)
	assert_almost_eq(ms.p1.hero.get_hp(), MAX_HP - BOMB_DAMAGE, 0.0001, "sanity: one skull landed")
	assert_true(ms.p2.projectiles.is_alive_at(1), "sanity: the other is still flying")
	_counter(ms)
	assert_false(ms.p2.projectiles.is_alive_at(1), "the skull still in flight vanishes (AC 19)")
	assert_almost_eq(ms.p1.hero.get_hp(), MAX_HP, 0.0001,
		"the landed skull's damage is refunded (AC 19)")
	assert_almost_eq(ms.p2.units.hp_at(2), MINION_HP, 0.0001,
		"the first converted minion rises again at its pre-death hp (AC 20)")
	assert_almost_eq(ms.p2.units.hp_at(3), wounded_hp, 0.0001,
		"...and the WOUNDED one at ITS pre-death hp, not at the kind's maximum (AC 20)")
	assert_false(ms.p2.units.has_corpse_at(0), "...each restore consumed its own corpse (AC 20)")
	assert_false(ms.p2.units.has_corpse_at(1), "...both of them")


## AC 20's EXCEPTION (`6-5g/R11`/`6-5f/R29`): a converted minion whose corpse has already expired is NOT
## restored, while a sibling whose corpse survives is -- the partial reversal, not a refusal.
func test_a_converted_minion_whose_corpse_expired_is_not_restored_but_its_sibling_is() -> void:
	var ms := _make_match()
	ms.p2.units.add(MINION_HP, MINION_KIND)
	ms.p2.units.add(MINION_HP, MINION_KIND)
	_victim_casts(ms, ID_BOMB)
	# One corpse is taken away under the reversal's feet; the other is left to survive.
	ms.p2.units.consume_corpse_at(0)
	assert_false(ms.p2.units.has_corpse_at(0), "sanity: the first corpse is gone")
	assert_true(ms.p2.units.has_corpse_at(1), "sanity: the second is not")
	var size_before := ms.p2.units.size()
	_counter(ms)
	assert_eq(ms.p2.units.size(), size_before + 1,
		"exactly ONE minion came back: the one whose corpse survived (AC 20)")
	assert_almost_eq(ms.p2.units.hp_at(size_before), MINION_HP, 0.0001,
		"...at its pre-death hp")


# ------------------------------------------------------------------ AC 22: the minion / totem split

## AC 22 (`6-5g/R11`): a MINION killed by a countered Honed Bolt comes back from its own corpse at its
## pre-death hp, through the SAME general restore rule AC 20 uses -- reached through the bolt's own non-hero
## branch, which is what makes the case real rather than hypothetical.
func test_a_minion_killed_by_a_countered_bolt_comes_back_from_its_corpse() -> void:
	var ms := _make_match()
	ms.p1.units.add(MINION_HP, MINION_KIND)
	ms.p1.units.apply_damage_at(0, MINION_HP - BOLT_DAMAGE, CORPSE_TICKS)   # one bolt is now lethal
	var pre_death := ms.p1.units.hp_at(0)
	ms.p2.lock_target_slot = 0
	ms.p2.lock_target_index = 0
	_victim_casts(ms, ID_BOLT)
	_idle(ms, BOLT_CAST_TICKS)
	assert_false(ms.p1.units.is_alive_at(0), "sanity: the bolt killed the minion")
	assert_true(ms.p1.units.has_corpse_at(0), "sanity: and it left a corpse")
	_counter(ms)
	assert_eq(ms.p1.units.size(), 2, "the killed minion is restored as a new record (AC 22)")
	assert_almost_eq(ms.p1.units.hp_at(1), pre_death, 0.0001,
		"...at its PRE-DEATH hp, through the same general restore rule (AC 22)")
	assert_false(ms.p1.units.has_corpse_at(0), "...consuming its own corpse")


## AC 22's other two clauses: a TOTEM killed by a countered spell stays dead (it leaves no corpse), while a
## SURVIVING totem that was merely damaged gets its hp back through the ordinary hp-refund path.
func test_a_killed_totem_stays_dead_and_a_damaged_surviving_totem_gets_its_hp_back() -> void:
	var totem_kind := 1
	# (a) KILLED: no corpse, so nothing to restore -- and the reversal says so by doing nothing.
	var killed := _make_match()
	killed.p1.units.add(BOLT_DAMAGE, totem_kind)   # exactly lethal to one bolt
	killed.p2.lock_target_slot = 0
	killed.p2.lock_target_index = 0
	_victim_casts(killed, ID_BOLT)
	_idle(killed, BOLT_CAST_TICKS)
	assert_false(killed.p1.units.is_alive_at(0), "sanity: the totem died")
	assert_false(killed.p1.units.has_corpse_at(0), "sanity: a totem leaves NO corpse (6-5b's own rule)")
	_counter(killed)
	assert_eq(killed.p1.units.size(), 1, "a killed totem stays dead: no record was added (AC 22)")
	assert_false(killed.p1.units.is_alive_at(0), "...and the dead one is still dead")
	# (b) SURVIVED: the hp actually removed comes back on the unit itself.
	var hurt := _make_match()
	hurt.p1.units.add(MINION_HP * 3.0, totem_kind)
	hurt.p2.lock_target_slot = 0
	hurt.p2.lock_target_index = 0
	_victim_casts(hurt, ID_BOLT)
	_idle(hurt, BOLT_CAST_TICKS)
	assert_almost_eq(hurt.p1.units.hp_at(0), MINION_HP * 3.0 - BOLT_DAMAGE, 0.0001,
		"sanity: the bolt wounded the totem without killing it")
	_counter(hurt)
	assert_almost_eq(hurt.p1.units.hp_at(0), MINION_HP * 3.0, 0.0001,
		"a surviving damaged unit gets its hp back through the ordinary refund path (AC 22)")
	assert_eq(hurt.p1.units.size(), 1, "...on the SAME record -- no restore, no new record (AC 22)")


# ------------------------------------------------------------------ REVIEW FIX B1/M1: the kill flag

## REVIEW FIX B1 (`6-5g/R21`): the review's own probe scenario, as a real test -- and MUTATION-EXERCISED. A
## minion that SURVIVED the first Rocksling stone and was later killed by an UNRELATED cause is NOT restored,
## and the corpse that OTHER cause wrote is left completely untouched -- the fabricated-resurrection blocker
## this fix closes.
##
## ROCKSLING, NOT HONED BOLT, IS THE FIXTURE, deliberately: a lone `PART_DAMAGE` (the bolt's own shape) is
## the packet's ONLY part, so the gate's own per-kind arm already refuses the whole counter once that one
## part's flag is false and the unit is dead -- the mutated line in `_reverse_recorded_parts` is then
## UNREACHABLE, and the mutation this fix's own proof requires would survive for the wrong reason. Rocksling's
## still-pending burst is a SECOND, genuinely surviving part (`PART_BURST`), so the gate admits the counter on
## its own merits and the reversal actually walks the flagged, unflagged-in-truth `PART_DAMAGE` element.
func test_a_minion_that_survived_a_stone_and_died_to_something_else_is_not_restored() -> void:
	var ms := _make_match()
	ms.p1.units.add(MINION_HP, MINION_KIND)
	ms.p2.lock_target_slot = 0
	ms.p2.lock_target_index = 0
	_victim_casts(ms, ID_SLING)
	_idle(ms, SLING_CAST_TICKS)
	assert_eq(ms.p2.projectiles.size(), 1, "sanity: the first stone left at the strike")
	_victim_shot_lands(ms, 0)
	assert_true(ms.p1.units.is_alive_at(0),
		"sanity: the stone wounded but did NOT kill (MINION_HP > SLING_DAMAGE)")
	assert_almost_eq(ms.p1.units.hp_at(0), MINION_HP - SLING_DAMAGE, 0.0001)
	assert_true(ms.p2.has_pending_burst(),
		"sanity: the burst is still owed -- a SECOND surviving part keeps the counter admitted")
	# A DIFFERENT, unrelated cause finishes the minion off.
	ms.p1.units.apply_damage_at(0, MINION_HP - SLING_DAMAGE, CORPSE_TICKS)
	assert_false(ms.p1.units.is_alive_at(0), "sanity: the minion is dead now, but not by the stone")
	assert_true(ms.p1.units.has_corpse_at(0), "sanity: and left a corpse -- the OTHER cause's own")
	var corpse_hp_before := ms.p1.units.hp_at_death_at(0)
	var size_before := ms.p1.units.size()
	var rejections := _rejections(ms.p1)
	_counter(ms)
	assert_eq(rejections, [], "sanity: the counter was ADMITTED -- the pending burst is a real target (B1)")
	assert_eq(ms.p1.units.size(), size_before,
		"no minion is restored: the stone did not kill this one, so its corpse is not the counter's to claim "
		+ "(B1)")
	assert_true(ms.p1.units.has_corpse_at(0), "...the corpse the OTHER cause wrote is left completely alone")
	assert_almost_eq(ms.p1.units.hp_at_death_at(0), corpse_hp_before, 0.0001,
		"...at the SAME pre-death hp it already held -- untouched, not overwritten")


## REVIEW FIX M1 (`6-5g/R21`): a minion the bolt itself KILLED, whose corpse has since EXPIRED, leaves
## nothing to reverse -- refused BEFORE the orb spend, silently, exactly as AC 12/AC 18 require. Before this
## fix the blanket `reversal_amount != 0.0` clause admitted this case as a pure no-op: orb spent, card gone,
## nothing undone.
func test_a_bolt_kill_whose_corpse_has_expired_is_refused_before_the_orb() -> void:
	var ms := _make_match()
	ms.p1.units.add(MINION_HP, MINION_KIND)
	ms.p1.units.apply_damage_at(0, MINION_HP - BOLT_DAMAGE, CORPSE_TICKS)   # one bolt is now lethal
	ms.p2.lock_target_slot = 0
	ms.p2.lock_target_index = 0
	_victim_casts(ms, ID_BOLT)
	_idle(ms, BOLT_CAST_TICKS)
	assert_false(ms.p1.units.is_alive_at(0), "sanity: the bolt killed the minion")
	assert_true(ms.p1.units.has_corpse_at(0), "sanity: leaving a corpse")
	_idle(ms, CORPSE_TICKS + 1)
	assert_false(ms.p1.units.has_corpse_at(0), "sanity: the corpse has since expired")
	_stage(ms, ID_COUNTER)
	var orbs_before := ms.p1.orbs.get_count(Enums.CardColor.GREEN)
	var rejections := _rejections(ms.p1)
	_activate(ms)
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_COUNTER_TARGET]],
		"a bolt kill whose corpse has expired leaves nothing to reverse: refused as no-target (M1)")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.GREEN), orbs_before, "...the orb is NOT spent")
	assert_true(ms.pitch.is_staged(0), "...the card STAYS staged")


## REVIEW FIX B1 (`6-5g/R21`): the flag is VISIBLE in the snapshot's `reversal` key -- the fifth element
## (`flags`), hashed -- proven directly rather than only through its behavioural consequence above.
func test_the_kill_flag_is_visible_in_the_snapshot() -> void:
	var ms := _make_match()
	ms.p1.units.add(MINION_HP, MINION_KIND)
	ms.p1.units.apply_damage_at(0, MINION_HP - BOLT_DAMAGE, CORPSE_TICKS)   # one bolt is now lethal
	ms.p2.lock_target_slot = 0
	ms.p2.lock_target_index = 0
	_victim_casts(ms, ID_BOLT)
	_idle(ms, BOLT_CAST_TICKS)
	assert_false(ms.p1.units.is_alive_at(0), "sanity: the bolt killed the minion")
	var flags: Array = (ms.p2.to_snapshot()["reversal"] as Array)[4]
	assert_eq(flags, [true] as Array[bool],
		"the PART_DAMAGE element's flag is TRUE: this resolution's own hit killed the struck unit")


# ------------------------------------------------------------------ AC 31: the per-kind gate arms

## AC 31 (`6-5g/R13`): `_reversal_has_anything_left` gains ONE ARM PER NEW KIND, and this is the arms'
## non-vacuity proof in the NEGATIVE direction for every one of the seven: with the kind written but
## nothing of it surviving, each is refused -- which is also what proves the packet's kind alone never
## admits a card. The three buffs' expired windows are AC 8's case; the four part-list kinds' empty cases
## are here.
##
## WHY ONE TEST FOR FOUR KINDS: the four share one arm over one part vocabulary (see
## `_reverse_recorded_parts`), so four separate tests would be four copies of one assertion.
func test_every_new_kind_with_nothing_left_is_refused_through_the_standing_gate() -> void:
	# HONED BOLT: cast interrupted, nothing landed (also AC 18's first shape, asserted there).
	# FIREBALL: the ball expired in the air (AC 18's second shape, asserted there).
	# ROCKSLING: every stone expired in the air with no Boulder planted and nothing landed.
	var sling := _make_match()
	_victim_casts(sling, ID_SLING)
	_idle(sling, SLING_CAST_TICKS)
	var ceiling := 0
	while (sling.p2.has_pending_burst() or _any_shot_alive(sling.p2)) and ceiling < 400:
		_idle(sling, 1)
		ceiling += 1
	assert_false(sling.p2.has_pending_burst(), "sanity: the whole burst fired")
	assert_false(_any_shot_alive(sling.p2), "sanity: and every stone expired in the air")
	assert_eq(sling.p1.hand.cover_count(), 0, "sanity: no Boulder was ever planted")
	var sling_rejections := _rejections(sling.p1)
	_counter(sling)
	assert_eq(sling_rejections, [[&"card_cast", MatchState.REASON_NO_COUNTER_TARGET]],
		"a Rocksling whose every stone missed with no Boulder planted is refused (AC 18/AC 31)")
	# CORPSE BOMB: every skull expired in the air and every corpse is gone.
	var bomb := _make_match()
	bomb.p2.units.add(MINION_HP, MINION_KIND)
	_victim_casts(bomb, ID_BOMB)
	bomb.p2.units.consume_corpse_at(0)
	var bomb_ceiling := 0
	while _any_shot_alive(bomb.p2) and bomb_ceiling < 400:
		_idle(bomb, 1)
		bomb_ceiling += 1
	assert_false(_any_shot_alive(bomb.p2), "sanity: the skull expired in the air")
	var bomb_rejections := _rejections(bomb.p1)
	_counter(bomb)
	assert_eq(bomb_rejections, [[&"card_cast", MatchState.REASON_NO_COUNTER_TARGET]],
		"a Corpse Bomb whose skull missed and whose corpse is gone is refused (AC 31)")


## AC 10/AC 23 (`6-5g/R10`): a SECOND copy's resolution takes over the packet, and the FIRST copy's shot --
## still in the air -- can no longer charge anything to it. The identity is the recorded PROJECTILE INDEX,
## which `ProjectileBoard` never reuses; without that, the older shot's landing would refund hp against the
## newer resolution's record.
func test_an_orphaned_shot_from_an_earlier_resolution_charges_nothing_to_the_new_packet() -> void:
	var ms := _make_match()
	_victim_activates(ms, ID_FIRE)
	_idle(ms, FIRE_CAST_TICKS)
	assert_true(ms.p2.projectiles.is_alive_at(0), "sanity: copy one's ball is in the air")
	# A SECOND resolution overwrites the packet -- a Vampiric Aura, so the new kind is unmistakable.
	_victim_casts(ms, ID_AURA)
	assert_eq(int((ms.p2.to_snapshot()["reversal"] as Array)[0]), PlayerState.REVERSAL_VAMPIRIC_AURA,
		"sanity: the packet now describes the Aura")
	_victim_shot_lands(ms, 0)
	assert_almost_eq(ms.p1.hero.get_hp(), MAX_HP - FIRE_DAMAGE, 0.0001, "sanity: the old ball landed")
	assert_almost_eq(float((ms.p2.to_snapshot()["reversal"] as Array)[5]), 0.0, 0.0001,
		"the orphaned shot charged NOTHING to the Aura's packet (`6-5g/R10`)")
	_counter(ms)
	assert_almost_eq(ms.p1.hero.get_hp(), MAX_HP - FIRE_DAMAGE, 0.0001,
		"...so countering the Aura refunds no hp: it reverses the Aura and nothing else")
	assert_false(ms.p2.is_rule_active(PlayerState.RULE_VAMPIRIC_AURA), "...and it did end the Aura")


## AC 23's regression half for this story's own seven: every one of them, played with NO Counterspell
## anywhere, still resolves exactly as its own story shipped it. A guard against the six new recorders and
## the two new press-seat writes having changed any card's ordinary behaviour.
func test_the_seven_new_cards_still_resolve_normally_when_no_counterspell_is_played() -> void:
	var aura := _make_match()
	_victim_casts(aura, ID_AURA)
	assert_true(aura.p2.is_rule_active(PlayerState.RULE_VAMPIRIC_AURA), "Vampiric Aura still arms")
	var hound := _make_match()
	_victim_casts(hound, ID_HOUND)
	_advance(hound, InputIntent.new(), _roll_intent())
	assert_almost_eq(hound.p2.hero.velocity.length(),
		ROLL_DISTANCE / (float(ROLL_TICKS) / TimingWindow.TICK_HZ) * HOUND_DISTANCE_MULT, 0.0001,
		"Bloodhound Step still boosts a roll")
	var frost := _make_match()
	_victim_casts(frost, ID_FROST)
	_victim_hits_counterer(frost)
	assert_true(frost.p1.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "Frostbite still slows")
	var bolt := _make_match()
	_victim_casts(bolt, ID_BOLT)
	_idle(bolt, BOLT_CAST_TICKS)
	assert_almost_eq(bolt.p1.hero.get_hp(), MAX_HP - BOLT_DAMAGE, 0.0001, "Honed Bolt still strikes")
	assert_true(bolt.p1.hero.stun.is_running, "...and still stuns")
	var fire := _make_match()
	_victim_activates(fire, ID_FIRE)
	_idle(fire, FIRE_CAST_TICKS)
	assert_eq(fire.p2.projectiles.size(), 1, "Fireball still launches one shot")
	assert_almost_eq(fire.p2.projectiles.damage_at(0), FIRE_DAMAGE, 0.0001,
		"...at its damage locked at staging")
	var sling := _make_match()
	_victim_casts(sling, ID_SLING)
	_idle(sling, SLING_CAST_TICKS)
	assert_eq(sling.p2.projectiles.size(), 1, "Rocksling still throws its first stone at the strike")
	assert_true(sling.p2.has_pending_burst(), "...and still schedules the rest")
	var bomb := _make_match()
	bomb.p2.units.add(MINION_HP, MINION_KIND)
	_victim_casts(bomb, ID_BOMB)
	assert_false(bomb.p2.units.is_alive_at(0), "Corpse Bomb still converts its own minion")
	assert_eq(bomb.p2.projectiles.size(), 1, "...and still throws its skull")


## AC 24: no reversal arm this story adds consumes RNG. The 6-5f test of the same name covers the six
## instant kinds; this covers the seven new ones at the arm with the strongest claim to draw -- Rocksling's,
## which walks a Boulder slot and cancels a burst (the Boulder PLANT does draw, at its own seat; the
## REMOVAL must not).
func test_no_new_reversal_arm_consumes_rng() -> void:
	var ms := _make_match()
	_victim_casts(ms, ID_SLING)
	_idle(ms, SLING_CAST_TICKS)
	_victim_shot_lands(ms, 0)
	var state_before: int = ms.to_snapshot()["rng_state"]
	_counter(ms)
	assert_eq(ms.to_snapshot()["rng_state"], state_before,
		"the reversal drew no random number: the stream is where it was (AC 24)")


func _any_shot_alive(player: PlayerState) -> bool:
	return not player.projectiles.living_indices().is_empty()


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
	# Story 6-5g: the ROLL (Bloodhound Step's own consumer, AC 7) and the melee windows Frostbite's trigger
	# rides (AC 5/AC 6). `stamina_regen_per_second` 0 so a roll's cost cannot be refunded by regen mid-test.
	c.roll_stamina_cost = ROLL_COST
	c.roll_duration_seconds = float(ROLL_TICKS) / TimingWindow.TICK_HZ
	c.roll_iframe_seconds = float(ROLL_IFRAME_TICKS) / TimingWindow.TICK_HZ
	c.roll_distance = ROLL_DISTANCE
	c.stamina_regen_per_second = 0.0
	# Long enough that no staged card fizzles inside any test here -- the AC 11 refusal test needs the
	# countdown RUNNING rather than closed, which is a different fact from being long.
	c.pitch_stage_timer_seconds = 30.0
	c.max_orbs_per_color = 99
	# Story 6-5g (AC 22): a TOTEM kind joins the fixture, because the minion-versus-totem restore SPLIT is an
	# AC and a fixture with one kind cannot express it. Index 0 stays the minion, so every `6-5f` test's
	# `MINION_KIND` is untouched.
	c.unit_kinds = [UnitKindFixture.melee(CardEffectResolver.KIND_MINION, MINION_HP, MINION_DAMAGE,
			2, 3, 4, 2.0),
			UnitKindFixture.inert(CardEffectResolver.KIND_COMBAT_TOTEM, MINION_HP)] as Array[UnitKindProfile]
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
		ID_AURA: &"vampiric_aura", ID_HOUND: &"bloodhound_step", ID_FROST: &"frostbite",
		ID_FIRE: &"fireball", ID_SLING: &"rocksling", ID_BOMB: &"corpse_bomb",
		# REVIEW FIX (m2/m3): the second copies resolve through the SAME effect id as their first, exactly
		# as `ID_COUNTER_B` already does for Counterspell -- two cards, one effect, real copy discrimination.
		ID_FROST_B: &"frostbite", ID_SLING_B: &"rocksling",
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
			# Story 6-5g: the seven. The three buffs need their windows; the three cast cards need a cast
			# frame; the three projectile throwers need a FLIGHT PROFILE (`launch_speed`/`travel_budget`),
			# without which `_advance_projectiles` finds a zero budget and consumes every shot on its first
			# tick -- which would make "in flight" untestable.
			&"vampiric_aura":
				e.duration_seconds = _seconds(AURA_TICKS)
				e.lifesteal_fraction = AURA_LIFESTEAL
			&"bloodhound_step":
				e.duration_seconds = _seconds(HOUND_TICKS)
				e.roll_distance_multiplier = HOUND_DISTANCE_MULT
				e.roll_iframe_multiplier = HOUND_IFRAME_MULT
			&"frostbite":
				e.duration_seconds = _seconds(FROST_TICKS)
				e.slow_speed_multiplier = FROST_SLOW
				e.slow_duration_seconds = _seconds(FROST_SLOW_TICKS)
			&"honed_bolt":
				e.cast_seconds = _seconds(BOLT_CAST_TICKS)
				e.damage_amount = BOLT_DAMAGE
				e.stun_seconds = _seconds(BOLT_STUN_TICKS)
				e.root_seconds = _seconds(BOLT_ROOT_TICKS)
			&"fireball":
				e.cast_seconds = _seconds(FIRE_CAST_TICKS)
				e.mana_cap = FIRE_MANA_CAP
				e.damage_per_mana = FIRE_DAMAGE_PER_MANA
				e.launch_speed = LAUNCH_SPEED
				e.max_speed = LAUNCH_SPEED
				e.travel_budget = TRAVEL_BUDGET
			&"rocksling":
				e.cast_seconds = _seconds(SLING_CAST_TICKS)
				e.damage_amount = SLING_DAMAGE
				e.boulders_per_cast = SLING_STONES
				e.boulder_interval_seconds = _seconds(SLING_INTERVAL_TICKS)
				e.launch_speed = LAUNCH_SPEED
				e.max_speed = LAUNCH_SPEED
				e.travel_budget = TRAVEL_BUDGET
			&"corpse_bomb":
				e.damage_amount = BOMB_DAMAGE
				e.launch_speed = LAUNCH_SPEED
				e.max_speed = LAUNCH_SPEED
				e.travel_budget = TRAVEL_BUDGET
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


func _seconds(ticks: int) -> float:
	return float(ticks) / TimingWindow.TICK_HZ


## Story 6-5g: P2 (THE VICTIM) lands one CONFIRMED HERO MELEE HIT on P1 -- Frostbite's own trigger seat
## (AC 5/AC 6). `test_spell_framework.gd`'s `_p1_hits_p2` with the slots swapped, and for its reason: a
## synthetic contact fact needs a real swing behind it, because `_register_attacker_hit` consults the
## attacker's live dedupe record.
func _victim_hits_counterer(ms: MatchState) -> void:
	_advance(ms, InputIntent.new(), _press(&"attack"))
	for _t in 2:
		_advance(ms, InputIntent.new(), InputIntent.new())
	ms.push_contact([1, TargetingService.HERO_INDEX], [0, TargetingService.HERO_INDEX],
			ms.p2.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms, InputIntent.new(), InputIntent.new())


## Story 6-5g: one of P2's SHOTS lands on the address it was thrown at. `test_fireball.gd`'s
## `_push_shot_contact` with the attacker on slot 1.
func _victim_shot_lands(ms: MatchState, shot: int) -> void:
	var board := ms.p2.projectiles
	var address: Array[int] = [board.target_slot_at(shot), board.target_index_at(shot)]
	var attacker: Array[int] = [1, MatchState.projectile_attacker_index(shot)]
	var target_side: PlayerState = ms.p1 if address[0] == 0 else ms.p2
	ms.push_contact(attacker, address, board.flight_ticks_at(shot), target_side.hero.facing,
			MatchState.CONTACT_STRIKE)
	_advance(ms, InputIntent.new(), InputIntent.new())


func _press(action: StringName) -> InputIntent:
	var i := InputIntent.new()
	i.pressed[action] = true
	i.held[action] = true
	return i


func _roll_intent() -> InputIntent:
	var i := _press(&"roll")
	i.move_dir = Vector2(1.0, 0.0)
	return i


func _idle(ms: MatchState, n: int) -> void:
	for _t in n:
		_advance(ms, InputIntent.new(), InputIntent.new())


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
