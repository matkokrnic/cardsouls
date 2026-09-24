extends TestCase

## Story 6-5b (AC 8-22, AC 24): CULLING, GRAVE WARD, RAISE DEAD and DRAIN end to end through
## `advance()` -- the four effects whose deferred rows this story retired.
##
## Covers AC 8-10 (Culling: kill-all, `kill_cap`, the refusal, the totem/opponent exclusion),
## AC 11-13 (Grave Ward: per-corpse extension, additive stacking, the refusal), AC 14-17 (Raise Dead:
## raise-and-consume at a new index, the refusal, never the opponent's, a raised minion dies again),
## AC 18-22 (Drain: the pushed target, the shared death path, the clamped heal, the refusal) and
## AC 24's per-corpse mark. The CORPSE and the DEATH SEAT they are all built on are
## test_corpses.gd's; the ANGLE RULE itself is test/integration/test_drain_selection.gd's, because it
## is the runner's and needs positions.
##
## MODE MATTERS AND IS NOT INTERCHANGEABLE HERE. Grave Ward and Drain are MODE ① casts; Culling and
## Raise Dead are MODE ④ PITCH ACTIVATIONS (Vanguard's and Grave Ward's pitches). `6-5b/R14` gives the
## two modes DIFFERENT refusal mechanics -- mode ① refuses before the mana spend, mode ④ before the orb
## spend and leaves the card staged -- so each is driven through its own real path.
##
## GOLDEN ISOLATION (`BC/R3`): every config, effect and card below is built IN-TEST with opaque `om_*`
## ids and in-test numbers; nothing reads `data/`, so a Deck 1 retune moves nothing here.

const SEED := 6521
const MAX_HP := 100.0
const HERO_TO_UNIT := 3.0
const MINION_HP := 9.0
const MINION_DAMAGE := 4.0
const MAX_STAMINA := 50.0
const START_MANA := 40.0
const MAX_MANA := 50.0
const CORPSE_TICKS := 8
const CORPSE_SECONDS := float(CORPSE_TICKS) / TimingWindow.TICK_HZ
const MINION_KIND := 0
const TOTEM_KIND := 1

## The in-test effect numbers, DISTINCT from each other and from Deck 1's where it matters -- so a
## value read off the wrong field cannot coincidentally produce the expected answer.
const CULLING_MANA_PER_KILL := 2.0
const WARD_SECONDS := 10.0 / TimingWindow.TICK_HZ   # 10 ticks: short, so a stack is countable
const WARD_TICKS := 10
const RAISE_PERCENT := 50.0                          # NOT 100, so the percentage is load-bearing
const DRAIN_HEAL := 12.0

## Mode ① cards (cast for mana) and mode ④ cards (staged, then activated for orbs).
const ID_WARD := &"om_ward"
const ID_DRAIN := &"om_drain"
const ID_CULLING := &"om_culling"
const ID_RAISE := &"om_raise"
const DECK: Array[StringName] = [ID_WARD, ID_DRAIN, ID_CULLING, ID_RAISE, ID_WARD, ID_DRAIN,
		ID_CULLING, ID_RAISE]
const CAST_MANA := 2.0
const ORB_PRICE := 1


# ------------------------------------------------------------------ the resolver's four new rows

## AC 8/11/14/18: each of the four resolves to its OWN named outcome now, and `owner_story_for` no
## longer claims any of them. The other direction of `test_spell_framework.gd`'s deferred-table pin.
func test_the_four_effects_resolve_to_real_outcomes_and_own_no_deferred_row() -> void:
	var expected := {
		&"culling": CardEffectResolver.OUTCOME_CULLING,
		&"grave_ward": CardEffectResolver.OUTCOME_GRAVE_WARD,
		&"raise_dead": CardEffectResolver.OUTCOME_RAISE_DEAD,
		&"drain": CardEffectResolver.OUTCOME_DRAIN,
	}
	for id: StringName in expected:
		var effect := CardEffect.new()
		effect.effect_id = id
		assert_eq(CardEffectResolver.outcome(effect, _flags()), expected[id],
			"%s resolves to its own outcome, not the deferred no-op" % id)
		assert_eq(CardEffectResolver.owner_story_for(id), &"",
			"...and no longer names an owning story: 6-5b built it")
		assert_eq(CardEffectResolver.outcome(effect, null),
			CardEffectResolver.REASON_SPELLS_FLAG_CLOSED,
			"...and no flags injected reads CLOSED, exactly as the four buffs do")


## AC 8/11/14/18: with the SPELL LAYER CLOSED all four still CAST -- mana spent, card discarded -- and
## apply nothing. The project-context feature-flag HARD RULE, and the 6-5a buffs' posture verbatim.
func test_a_closed_spell_layer_casts_the_card_and_applies_nothing() -> void:
	var closed := _flags()
	closed.spells = false
	var ms := _make_match(closed)
	ms.p1.units.add(MINION_HP, MINION_KIND)
	var mana_before := ms.p1.mana.get_current()
	var rejections := _rejections(ms.p1)
	_cast(ms, ID_DRAIN)
	assert_eq(rejections, [], "no refusal: the layer being closed is not a refusal")
	assert_eq(ms.p1.mana.get_current(), mana_before - CAST_MANA, "the mana is spent")
	assert_true(ms.p1.units.is_alive_at(0), "...and the minion is NOT sacrificed")
	assert_eq(ms.p1.hero.get_hp(), MAX_HP, "...and nothing healed")


## Review fix (6-5b review, MAJOR-1): the board-aware refusal gate must not refuse when the SPELL
## LAYER IS CLOSED, on an EMPTY board -- the flags-OFF x empty-board cell of the matrix the test above
## left untested (it adds a minion before casting, so `_board_refusal_reason`'s gate is never taken
## with the layer closed). Mode ①: the cast RESOLVES exactly like the buffs -- mana spent, card
## discarded, replacement owed -- and applies nothing, with no rejection.
func test_a_closed_spell_layer_with_an_empty_board_casts_and_applies_nothing_mode_1() -> void:
	var closed := _flags()
	closed.spells = false
	var ms := _make_match(closed)
	var mana_before := ms.p1.mana.get_current()
	var hp_before := ms.p1.hero.get_hp()
	const P1_SLOT := 0
	var rejections := _rejections(ms.p1)
	var resolutions := _resolutions(ms)
	_cast(ms, ID_DRAIN)
	assert_eq(rejections, [], "no refusal -- an empty own board is irrelevant when the layer is closed")
	assert_eq(resolutions, [[P1_SLOT, ID_DRAIN, Enums.ModeKind.BASIC]],
		"the cast RESOLVES like any other -- the card leaves the hand into the discard")
	assert_eq(ms.p1.mana.get_current(), mana_before - CAST_MANA, "the mana IS spent")
	assert_eq(ms.p1.units.size(), 0, "...and nothing was raised, killed or added to the board")
	assert_eq(ms.p1.hero.get_hp(), hp_before, "...and no heal happened")


## The mode ④ twin, on an EMPTY board: the activation RESOLVES -- orbs spent, card leaves the pitch
## zone -- and applies nothing, with no rejection.
func test_a_closed_spell_layer_with_an_empty_board_activates_and_applies_nothing_mode_4() -> void:
	var closed := _flags()
	closed.spells = false
	var ms := _make_match(closed)
	_advance(ms, _stage_intent(_slot_of(ms.p1, ID_CULLING)), InputIntent.new())
	assert_true(ms.pitch.is_staged(0), "fixture: Culling reached the zone")
	var orbs_before := ms.p1.orbs.get_count(Enums.CardColor.GREEN)
	var rejections := _rejections(ms.p1)
	_activate(ms)
	assert_eq(rejections, [], "no refusal -- an empty own board is irrelevant when the layer is closed")
	assert_true(ms.p1.orbs.get_count(Enums.CardColor.GREEN) < orbs_before, "the orbs ARE spent")
	assert_false(ms.pitch.is_staged(0), "...and the card LEAVES the zone")
	assert_eq(ms.p1.units.size(), 0, "...and nothing was killed or raised")


# ------------------------------------------------------------------ AC 8-10: Culling

## AC 8: Culling kills EVERY one of the caster's own living minions and grants mana PER KILL.
func test_culling_kills_every_own_living_minion_and_pays_per_kill() -> void:
	var ms := _staged_match(ID_CULLING, 3)
	ms.p1.mana.spend(ms.p1.mana.get_current())     # start from zero, so the grant is the reading
	var mana_before := ms.p1.mana.get_current()
	_activate(ms)
	for index in 3:
		assert_false(ms.p1.units.is_alive_at(index), "minion %d died" % index)
		assert_true(ms.p1.units.has_corpse_at(index), "...and left its own corpse (AC 1/AC 3)" )
	assert_eq(ms.p1.mana.get_current(), mana_before + CULLING_MANA_PER_KILL * 3.0,
		"three kills grant three times the authored rate")


## AC 8: `kill_cap` AT, BELOW and ABOVE the living-minion count -- and above it, Culling kills in
## BOARD-INDEX ORDER (oldest first) and pays for EXACTLY the ones it killed.
func test_culling_respects_its_kill_cap_in_board_index_order() -> void:
	# BELOW the count: 2 of 4 die, the OLDEST two, and exactly two are paid for.
	var capped := _staged_match(ID_CULLING, 4, 2)
	capped.p1.mana.spend(capped.p1.mana.get_current())
	_activate(capped)
	assert_false(capped.p1.units.is_alive_at(0), "index 0 died (oldest first)")
	assert_false(capped.p1.units.is_alive_at(1), "index 1 died")
	assert_true(capped.p1.units.is_alive_at(2), "index 2 SURVIVED -- the cap stopped the walk")
	assert_true(capped.p1.units.is_alive_at(3), "...and so did index 3")
	assert_eq(capped.p1.mana.get_current(), CULLING_MANA_PER_KILL * 2.0,
		"...and exactly TWO kills were paid for, not four")
	# AT the count: all die.
	var exact := _staged_match(ID_CULLING, 2, 2)
	_activate(exact)
	assert_false(exact.p1.units.is_alive_at(0), "at the cap, index 0 dies")
	assert_false(exact.p1.units.is_alive_at(1), "...and so does index 1")
	# ABOVE the count: the cap is slack and all die.
	var slack := _staged_match(ID_CULLING, 2, 99)
	_activate(slack)
	assert_false(slack.p1.units.is_alive_at(0), "above the cap, index 0 dies")
	assert_false(slack.p1.units.is_alive_at(1), "...and so does index 1")
	# EXACTLY ONE minion, the positive case AC 8 names explicitly.
	var single := _staged_match(ID_CULLING, 1)
	single.p1.mana.spend(single.p1.mana.get_current())
	_activate(single)
	assert_false(single.p1.units.is_alive_at(0), "with exactly ONE own minion, that one dies")
	assert_eq(single.p1.mana.get_current(), CULLING_MANA_PER_KILL, "...and is paid for once")


## AC 8 (`6-5b/R5`): mana above the pool's maximum is LOST TO THE EXISTING CLAMP. No second ceiling is
## authored here, which is exactly what makes this worth asserting -- the number is the pool's.
func test_culling_mana_above_the_pool_maximum_is_lost_to_the_existing_clamp() -> void:
	var ms := _staged_match(ID_CULLING, 4)
	ms.p1.mana.add(MAX_MANA)      # already full
	_activate(ms)
	assert_eq(ms.p1.mana.get_current(), MAX_MANA,
		"the grant is clamped by `ManaPool`'s own maximum (`6-5b/R5`), never by a cap in the effect")


## AC 9 (`6-5b/R14`, mode ④): Culling with no own living minion is REFUSED -- and everything the AC
## lists as untouched is asserted, not just the absence of a kill.
func test_culling_with_no_own_minion_is_refused_and_leaves_the_card_staged() -> void:
	var ms := _staged_match(ID_CULLING, 0)
	var orbs_before := ms.p1.orbs.get_count(Enums.CardColor.GREEN)
	var mana_before := ms.p1.mana.get_current()
	var rejections := _rejections(ms.p1)
	var resolutions := _resolutions(ms)
	var countdown_before := _fizzle_elapsed(ms)
	_activate(ms)
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_OWN_MINION]],
		"the press is REFUSED, with its own token naming the player-visible fact")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.GREEN), orbs_before,
		"the ORB COST IS NOT SPENT -- the gate fires before the spend (`6-5b/R14`)")
	assert_eq(ms.p1.mana.get_current(), mana_before, "no mana moves either")
	assert_true(ms.pitch.is_staged(0), "the card STAYS STAGED")
	assert_true(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags), "...and stays READY")
	assert_eq(resolutions, [], "nothing RESOLVED: no `card_cast_resolved` was queued")
	assert_true(_fizzle_elapsed(ms) > countdown_before,
		"...and its countdown KEEPS RUNNING toward the normal fizzle, never frozen by the refusal")
	# THE POSITIVE COMPANION: the identical press, one minion later, kills and pays.
	ms.p1.units.add(MINION_HP, MINION_KIND)
	_activate(ms)
	assert_false(ms.p1.units.is_alive_at(0),
		"the IDENTICAL press once a target exists kills it -- the refusal was the board, not the press")
	assert_false(ms.pitch.is_staged(0), "...and NOW the card leaves the zone")


## AC 10 / AC 16: the SHARED EXCLUSION FIXTURE -- a totem and a minion on the caster's own board, a
## minion and a corpse on the opponent's. Culling touches only the caster's own minion; Raise Dead
## raises only the caster's own corpse. Asserted on BOTH SIDES in the same test, which is what AC 10
## asks for and what a pair of one-sided tests could not give.
func test_culling_and_raise_dead_never_reach_a_totem_or_the_opponent() -> void:
	var ms := _staged_match(ID_CULLING, 0)
	ms.p1.units.add(MINION_HP, TOTEM_KIND)     # index 0: the caster's TOTEM
	ms.p1.units.add(MINION_HP, MINION_KIND)    # index 1: the caster's MINION
	ms.p2.units.add(MINION_HP, MINION_KIND)    # the opponent's minion
	ms.p2.units.add(MINION_HP, MINION_KIND)
	ms.p2.units.kill_at(1, CORPSE_TICKS)       # ...and the opponent's CORPSE
	var p2_hp_before := ms.p2.units.hp_at(0)
	_activate(ms)
	assert_true(ms.p1.units.is_alive_at(0), "the caster's own TOTEM is UNTOUCHED (AC 10)")
	assert_false(ms.p1.units.is_alive_at(1), "...while the minion beside it dies")
	assert_true(ms.p1.units.has_corpse_at(1), "...and drops a corpse")
	assert_false(ms.p1.units.has_corpse_at(0), "...and the totem drops none (`6-5b/R10`)")
	assert_true(ms.p2.units.is_alive_at(0), "the OPPONENT's minion is UNTOUCHED (AC 10)")
	assert_eq(ms.p2.units.hp_at(0), p2_hp_before, "...not even scratched")
	# AC 16, the same fixture's other half: a Raise Dead now raises ONE corpse, the caster's.
	var p2_size_before := ms.p2.units.size()
	_stage_and_activate(ms, ID_RAISE)
	assert_eq(ms.p2.units.size(), p2_size_before,
		"RAISE DEAD never raises the OPPONENT's corpse (AC 16) -- a board belongs to one player")
	assert_true(ms.p2.units.has_corpse_at(1), "...and never consumes it either")
	assert_false(ms.p1.units.has_corpse_at(1), "the caster's own corpse WAS consumed")
	assert_true(ms.p1.units.is_alive_at(2), "...and raised at a NEW index")


# ------------------------------------------------------------------ AC 11-13: Grave Ward

## AC 11: Grave Ward extends EVERY corpse the caster owns at the moment of resolution -- and a corpse
## created AFTER that resolution is untouched by it.
func test_grave_ward_extends_every_own_corpse_that_exists_at_resolution() -> void:
	var ms := _match_with_corpses(2)
	var before := ms.p1.units.corpse_ticks_at(0)
	assert_eq(ms.p1.units.corpse_ticks_at(1), before, "sanity: both corpses are the same age")
	_cast(ms, ID_WARD)
	# The cast tick itself also ticks the countdown down by one (step 2 precedes step 6), so the
	# expected value is stated as an arithmetic rather than as a literal.
	assert_eq(ms.p1.units.corpse_ticks_at(0), before - 1 + WARD_TICKS, "corpse 0 was extended")
	assert_eq(ms.p1.units.corpse_ticks_at(1), before - 1 + WARD_TICKS, "...and so was corpse 1")
	assert_true(ms.p1.units.is_corpse_extended_at(0), "both carry the mark (AC 24)")
	assert_true(ms.p1.units.is_corpse_extended_at(1), "...")
	# A LATER CORPSE IS UNAFFECTED (AC 11's second sentence): nothing stored says "wards are active".
	ms.p1.units.add(MINION_HP, MINION_KIND)
	ms.p1.units.kill_at(2, CORPSE_TICKS)
	assert_eq(ms.p1.units.corpse_ticks_at(2), CORPSE_TICKS,
		"a corpse created AFTER the cast gets the plain authored lifetime, not the extension")
	assert_false(ms.p1.units.is_corpse_extended_at(2), "...and carries no mark")


## AC 12 (`6-5b/R7`): two casts STACK ADDITIVELY -- the second adds one extension to whatever remained,
## rather than refreshing to a single extension's worth. Asserted as the DELTA across the second cast,
## which is the only form that distinguishes additive from refresh.
func test_two_grave_wards_stack_additively_rather_than_refreshing() -> void:
	var ms := _match_with_corpses(1)
	_cast(ms, ID_WARD)
	_idle(ms, 3)
	var before_second := ms.p1.units.corpse_ticks_at(0)
	_cast(ms, ID_WARD)
	assert_eq(ms.p1.units.corpse_ticks_at(0), before_second - 1 + WARD_TICKS,
		("the SECOND cast adds exactly ONE extension to what REMAINED (`6-5b/R7`). A refresh would "
		+ "have set this to one extension's worth (%d); additive makes it %d")
				% [WARD_TICKS, before_second - 1 + WARD_TICKS])
	assert_true(ms.p1.units.corpse_ticks_at(0) > WARD_TICKS,
		"...so two casts genuinely outlast one, which is what the smoke observes")


## AC 13 (`6-5b/R14`, mode ①): Grave Ward with no own corpse is REFUSED, BEFORE the mana spend.
func test_grave_ward_with_no_own_corpse_is_refused_before_the_mana_spend() -> void:
	var ms := _make_match()
	ms.p1.units.add(MINION_HP, MINION_KIND)      # a LIVING minion is not a corpse
	var mana_before := ms.p1.mana.get_current()
	var hand_before := ms.p1.hand.to_array()
	var rejections := _rejections(ms.p1)
	_cast(ms, ID_WARD)
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_OWN_CORPSE]],
		"REFUSED with its own token -- an empty board and a board with no corpses are the same fact "
		+ "here, and both differ from having no living minion")
	assert_eq(ms.p1.mana.get_current(), mana_before,
		"NOTHING IS SPENT -- the gate precedes the spend (`6-5b/R14` superseding `4-1/R3` for these four)")
	assert_eq(ms.p1.hand.to_array(), hand_before, "...the card stays in the hand")
	assert_eq(ms.p1.pending_draw_owed, [] as Array[int], "...and no replacement is owed")
	# THE POSITIVE COMPANION: one corpse later, the identical cast extends it.
	ms.p1.units.kill_at(0, CORPSE_TICKS)
	_cast(ms, ID_WARD)
	assert_true(ms.p1.units.is_corpse_extended_at(0),
		"the IDENTICAL cast with exactly ONE own corpse extends it")
	assert_eq(ms.p1.mana.get_current(), mana_before - CAST_MANA, "...and NOW the mana is spent")


# ------------------------------------------------------------------ AC 14-17: Raise Dead

## AC 14: Raise Dead turns every own corpse into a live minion at a NEW index, at the authored
## percentage of its own kind's maximum, and CONSUMES the corpse.
func test_raise_dead_raises_every_own_corpse_at_a_new_index_and_consumes_it() -> void:
	var ms := _match_with_corpses(2)
	assert_eq(ms.p1.units.size(), 2, "sanity: two records, both corpses")
	_stage_and_activate(ms, ID_RAISE)
	assert_eq(ms.p1.units.size(), 4, "two NEW records were appended")
	for hole in 2:
		assert_false(ms.p1.units.is_alive_at(hole), "the dead record at %d stays a hole" % hole)
		assert_false(ms.p1.units.has_corpse_at(hole), "...and its corpse is CONSUMED")
	for raised in [2, 3]:
		assert_true(ms.p1.units.is_alive_at(raised), "the raised minion at %d is alive" % raised)
		assert_eq(ms.p1.units.hp_at(raised), MINION_HP * RAISE_PERCENT / 100.0,
			"...at the authored percentage of its own kind's maximum")
		assert_eq(ms.p1.units.kind_index_at(raised), MINION_KIND, "...as a minion")
	# THE HOLES ARE NEVER REUSED (`4-1/R9`, unchanged since 4-3a), which is what AC 14 means by "a NEW
	# board index": the raise APPENDS, so the raised records land after every existing one.
	assert_eq(ms.p1.units.raised_from_at(2), 0, "the raise records WHICH corpse it came from...")
	assert_eq(ms.p1.units.raised_from_at(3), 1, "...for the runner's placement read (AC 14)")


## AC 15 (`6-5b/R14`, mode ④): Raise Dead with no own corpse is REFUSED -- orbs unspent, card staged
## and READY, countdown running, and the STAGING MANA STAYS SPENT.
func test_raise_dead_with_no_own_corpse_is_refused_and_the_staging_mana_stays_spent() -> void:
	var ms := _staged_match(ID_RAISE, 1)      # a LIVING minion, no corpse
	var mana_after_staging := ms.p1.mana.get_current()
	var orbs_before := ms.p1.orbs.get_count(Enums.CardColor.GREEN)
	var rejections := _rejections(ms.p1)
	var countdown_before := _fizzle_elapsed(ms)
	_activate(ms)
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_OWN_CORPSE]], "REFUSED")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.GREEN), orbs_before, "the ORBS are not spent")
	assert_eq(ms.p1.mana.get_current(), mana_after_staging,
		"the STAGING MANA STAYS SPENT and is never refunded -- it was paid at staging for a chance, "
		+ "and this refusal is not that chance expiring (`match_state.gd`'s standing no-refund rule)")
	assert_true(ms.pitch.is_staged(0), "the card stays STAGED")
	assert_true(ms.pitch.is_ready(0, ms.p1.orbs, ms.flags), "...and READY")
	assert_true(_fizzle_elapsed(ms) > countdown_before, "...with its countdown still running")
	assert_eq(ms.p1.units.size(), 1, "and nothing was raised")
	# THE POSITIVE COMPANION: one corpse later, the identical activation raises it.
	ms.p1.units.kill_at(0, CORPSE_TICKS)
	_activate(ms)
	assert_eq(ms.p1.units.size(), 2, "the IDENTICAL activation with exactly ONE own corpse raises it")
	assert_false(ms.p1.units.has_corpse_at(0), "...consuming the corpse")
	assert_true(ms.p1.orbs.get_count(Enums.CardColor.GREEN) < orbs_before, "...and NOW the orbs go")


## AC 17: a minion raised by Raise Dead that dies again leaves a FRESH corpse like any other -- it is
## not exempt from the death path just because it came from one.
func test_a_raised_minion_that_dies_again_leaves_a_fresh_corpse() -> void:
	var ms := _match_with_corpses(1)
	_stage_and_activate(ms, ID_RAISE)
	assert_true(ms.p1.units.is_alive_at(1), "sanity: the raised minion is alive at a new index")
	ms.p1.units.kill_at(1, CORPSE_TICKS)
	assert_true(ms.p1.units.has_corpse_at(1),
		"the raised minion leaves a corpse of its own (AC 17) -- it is an ordinary board record, so "
		+ "its death goes through the same seat with no exemption to write")
	assert_eq(ms.p1.units.corpse_ticks_at(1), CORPSE_TICKS, "...at the full authored lifetime")
	# ...and THAT corpse can be raised again, which is the Culling -> Raise Dead loop's second lap.
	_stage_and_activate(ms, ID_RAISE)
	assert_true(ms.p1.units.is_alive_at(2), "...and can itself be raised, at another new index")


# ------------------------------------------------------------------ AC 18-22: Drain

## AC 18: Drain sacrifices the minion the RUNNER PUSHED, and state never recomputes the choice.
func test_drain_sacrifices_the_pushed_target() -> void:
	var ms := _make_match()
	for _i in 3:
		ms.p1.units.add(MINION_HP, MINION_KIND)
	ms.push_drain_target(0, 2)          # the runner's answer: index 2, not the lowest
	_cast(ms, ID_DRAIN)
	assert_false(ms.p1.units.is_alive_at(2), "the PUSHED index is the one sacrificed (AC 18)")
	assert_true(ms.p1.units.is_alive_at(0), "...and the lowest index is untouched")
	assert_true(ms.p1.units.is_alive_at(1), "...as is the middle one")
	assert_true(ms.p1.units.has_corpse_at(2), "the sacrifice leaves a corpse like any death (AC 19)")


## AC 18: a pushed index that is NOT a living own minion falls back to the board's lowest living own
## minion rather than refusing a cast the gate already allowed. The three ways that happens -- nothing
## pushed, a dead index, a totem index -- all land on the same rung.
func test_an_unusable_pushed_target_falls_back_to_the_lowest_living_own_minion() -> void:
	for pushed in [MatchState.NO_DRAIN_TARGET, 99, 0]:
		var ms := _make_match()
		ms.p1.units.add(MINION_HP, TOTEM_KIND)     # index 0: a TOTEM, never a valid sacrifice
		ms.p1.units.add(MINION_HP, MINION_KIND)    # index 1: the lowest living own MINION
		ms.p1.units.add(MINION_HP, MINION_KIND)
		if pushed != MatchState.NO_DRAIN_TARGET:
			ms.push_drain_target(0, pushed)
		_cast(ms, ID_DRAIN)
		assert_true(ms.p1.units.is_alive_at(0), "pushed %d: the totem is never sacrificed" % pushed)
		assert_false(ms.p1.units.is_alive_at(1),
			"pushed %d: the LOWEST LIVING OWN MINION is the degrade (AC 18)" % pushed)
		assert_true(ms.p1.units.is_alive_at(2), "pushed %d: and only one dies" % pushed)


## AC 22's first sentence: with exactly ONE own living minion, that minion is always the one
## sacrificed -- whatever was pushed, because the angle rule is trivially satisfied.
func test_with_exactly_one_own_minion_that_minion_is_always_sacrificed() -> void:
	for pushed in [MatchState.NO_DRAIN_TARGET, 0]:
		var ms := _make_match()
		ms.p1.units.add(MINION_HP, MINION_KIND)
		if pushed != MatchState.NO_DRAIN_TARGET:
			ms.push_drain_target(0, pushed)
		_cast(ms, ID_DRAIN)
		assert_false(ms.p1.units.is_alive_at(0),
			"pushed %d: with exactly one own living minion it is the sacrifice (AC 22)" % pushed)


## AC 20: the heal is the authored amount, CLAMPED at the caster's own maximum -- never overhealing.
func test_drain_heals_the_authored_amount_clamped_at_max_hp() -> void:
	var injured := _make_match()
	injured.p1.units.add(MINION_HP, MINION_KIND)
	injured.p1.hero.take_damage(30.0)
	_cast(injured, ID_DRAIN)
	assert_eq(injured.p1.hero.get_hp(), MAX_HP - 30.0 + DRAIN_HEAL, "an injured caster heals in full")
	# AT FULL HP the heal is absorbed by the clamp -- the hp does not exceed the maximum, and the
	# minion still dies (the sacrifice is not conditional on the heal landing).
	var full := _make_match()
	full.p1.units.add(MINION_HP, MINION_KIND)
	_cast(full, ID_DRAIN)
	assert_eq(full.p1.hero.get_hp(), MAX_HP, "a full caster NEVER OVERHEALS (AC 20)")
	assert_false(full.p1.units.is_alive_at(0), "...and the minion is sacrificed all the same")


## AC 21 (`6-5b/R14`, mode ①): Drain with no own living minion is REFUSED, nothing spent, no heal.
func test_drain_with_no_own_minion_is_refused_with_nothing_spent() -> void:
	# A board holding ONLY A TOTEM is the interesting form of "no own living minion": it proves the
	# gate reads the MINION exclusion rather than merely "is the board empty".
	var ms := _make_match()
	ms.p1.units.add(MINION_HP, TOTEM_KIND)
	ms.p1.hero.take_damage(30.0)
	var mana_before := ms.p1.mana.get_current()
	var hp_before := ms.p1.hero.get_hp()
	var rejections := _rejections(ms.p1)
	_cast(ms, ID_DRAIN)
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_NO_OWN_MINION]],
		"REFUSED -- a TOTEM is not an own living MINION, the same exclusion Culling applies")
	assert_eq(ms.p1.mana.get_current(), mana_before, "NOTHING IS SPENT")
	assert_eq(ms.p1.hero.get_hp(), hp_before, "no heal happened")
	assert_true(ms.p1.units.is_alive_at(0), "and the totem is untouched")
	# THE POSITIVE COMPANION: one minion later, the identical cast sacrifices and heals.
	ms.p1.units.add(MINION_HP, MINION_KIND)
	_cast(ms, ID_DRAIN)
	assert_false(ms.p1.units.is_alive_at(1), "the IDENTICAL cast with one own minion sacrifices it")
	assert_eq(ms.p1.hero.get_hp(), hp_before + DRAIN_HEAL, "...and heals")
	assert_eq(ms.p1.mana.get_current(), mana_before - CAST_MANA, "...and NOW the mana is spent")


# ------------------------------------------------------------------ AC 8 + AC 14: the loop

## THE STORY'S WHOLE POINT (AC 8 + AC 14, the smoke's item 8): Culling fills the board with corpses and
## Raise Dead brings them all back. Asserted end to end because each half passing separately does not
## prove the loop closes.
func test_the_culling_then_raise_dead_loop_closes() -> void:
	var ms := _staged_match(ID_CULLING, 3)
	_activate(ms)
	assert_eq(ms.p1.units.corpse_indices(), [0, 1, 2] as Array[int], "Culling left three corpses")
	_stage_and_activate(ms, ID_RAISE)
	assert_eq(ms.p1.units.corpse_indices(), [] as Array[int], "...Raise Dead consumed all three")
	for raised in [3, 4, 5]:
		assert_true(ms.p1.units.is_alive_at(raised), "...and raised one at index %d" % raised)
	assert_eq(ms.p1.units.size(), 6, "three holes plus three raised minions: holes are never reused")


# ------------------------------------------------------------------ helpers

## A match with `count` living minions on P1's board and no staged card.
func _make_match(flags: FeatureFlags = null) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_feature_flags(flags if flags != null else _flags())
	ms.inject_deck(DECK)
	ms.inject_card_costs(_costs())
	ms.inject_card_effects(_effects())
	ms.inject_pitch_costs(_costs())
	ms.inject_pitch_effects(_effects())
	_idle(ms, 1)   # the step-6 deal
	ms.p1.mana.add(START_MANA)
	ms.p2.mana.add(START_MANA)
	# The orb price for every mode ④ activation below, banked up front so READY is satisfied and the
	# refusal tests are refusing on the BOARD rather than on an unaffordable price.
	ms.p1.orbs.add(Enums.CardColor.GREEN, ORB_PRICE * 4)
	ms.drain_signals()
	return ms


## A match with `count` living minions and `id` STAGED in P1's pitch zone, ready to activate.
## `kill_cap` overrides Culling's authored cap for the tests that exercise it.
func _staged_match(id: StringName, count: int, kill_cap: int = 99) -> MatchState:
	var ms := _make_match()
	if kill_cap != 99:
		var effects := _effects()
		(effects[ID_CULLING] as CardEffect).kill_cap = kill_cap
		ms.inject_pitch_effects(effects)
	for _i in count:
		ms.p1.units.add(MINION_HP, MINION_KIND)
	_advance(ms, _stage_intent(_slot_of(ms.p1, id)), InputIntent.new())
	assert_true(ms.pitch.is_staged(0), "fixture: %s is staged" % id)
	return ms


## A match with `count` CORPSES on P1's board, made through the death seat.
func _match_with_corpses(count: int) -> MatchState:
	var ms := _make_match()
	for _i in count:
		ms.p1.units.add(MINION_HP, MINION_KIND)
	for index in count:
		ms.p1.units.kill_at(index, CORPSE_TICKS)
	return ms


## Stage `id` from the hand and activate it on the next tick -- the two-press mode ④ sequence.
func _stage_and_activate(ms: MatchState, id: StringName) -> void:
	_advance(ms, _stage_intent(_slot_of(ms.p1, id)), InputIntent.new())
	assert_true(ms.pitch.is_staged(0), "fixture: %s reached the zone" % id)
	_activate(ms)


func _activate(ms: MatchState) -> void:
	_advance(ms, _activate_intent(), InputIntent.new())


## How far P1's staged card's FIZZLE COUNTDOWN has run, read off the hashed snapshot.
##
## READ THROUGH `to_snapshot()` RATHER THAN A NEW ACCESSOR, and deliberately: `PitchState` exposes no
## public remaining-ticks reader (the HUD is told the countdown through the `pitch_changed` payload),
## and adding one for a test would widen the production surface to observe something the snapshot
## already carries. The ELAPSED count is what rises as the countdown runs, which is why the refusal
## tests assert this GREW rather than that a remaining count shrank.
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
	c.hero_damage_to_unit = HERO_TO_UNIT
	c.minion_retarget_interval_seconds = 1000.0
	c.corpse_lifetime_seconds = CORPSE_SECONDS
	# Long enough that no staged card fizzles inside any test here -- the refusal tests need the
	# countdown to be RUNNING rather than closed, which is a different fact from being long.
	c.pitch_stage_timer_seconds = 10.0
	c.max_orbs_per_color = 99
	var kinds: Array[UnitKindProfile] = [
		UnitKindFixture.melee(CardEffectResolver.KIND_MINION, MINION_HP, MINION_DAMAGE, 2, 3, 4, 2.0),
		UnitKindFixture.inert(CardEffectResolver.KIND_COMBAT_TOTEM, MINION_HP),
	]
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


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in DECK:
		var c := CardCastCondition.new()
		c.mana_cost = CAST_MANA
		c.orb_costs = {Enums.CardColor.GREEN: ORB_PRICE} as Dictionary[Enums.CardColor, int]
		out[id] = c
	return out


func _effects() -> Dictionary[StringName, CardEffect]:
	var ids := {ID_WARD: &"grave_ward", ID_DRAIN: &"drain", ID_CULLING: &"culling",
			ID_RAISE: &"raise_dead"}
	var out: Dictionary[StringName, CardEffect] = {}
	for id in DECK:
		var e := CardEffect.new()
		e.effect_id = ids[id]
		match e.effect_id:
			&"grave_ward":
				e.duration_seconds = WARD_SECONDS
			&"drain":
				e.heal_amount = DRAIN_HEAL
			&"culling":
				e.mana_per_kill = CULLING_MANA_PER_KILL
				e.kill_cap = 99
			&"raise_dead":
				e.raise_hp_percent = RAISE_PERCENT
		out[id] = e
	return out


func _cast(ms: MatchState, id: StringName) -> void:
	_advance(ms, _cast_intent(_slot_of(ms.p1, id)), InputIntent.new())


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


func _resolutions(ms: MatchState) -> Array:
	var out: Array = []
	ms.card_cast_resolved.connect(
		func(slot: int, id: StringName, mode: int) -> void: out.append([slot, id, mode]))
	return out


func _idle(ms: MatchState, n: int) -> void:
	for _t in n:
		_advance(ms, InputIntent.new(), InputIntent.new())


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
