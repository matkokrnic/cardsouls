extends TestCase

## Story 6-5a: the card-effect framework and the five Deck 1 effects it implements -- whole-id dispatch,
## the timed-rule seat, the damage funnel, the hashed last-resolved-card record, the pitch-effect
## channel, and Bloodlust / Vampiric Aura / Bloodhound Step / Frostbite end to end through `advance()`.
## (Ruin Vanguard is the unchanged `summon_*` path, covered by test_card_effect_resolution.gd.)
##
## GOLDEN ISOLATION (`BC/R3`): every config, effect and card below is built IN-TEST with opaque `sf_*`
## ids and in-test numbers; nothing reads data/, so a Deck 1 retune moves nothing here.
##
## Most combat tests set a buff DIRECTLY on the timed-rule seat (`start_rule`) so each proves ONE SEAT;
## the cast path that starts each rule is proven separately, from a real cast.

const SEED := 6505
const MAX_HP := 100.0
const HIT_DAMAGE := 6.0          # 6 % of 100
const BLOCK_MULT := 0.25
const HERO_TO_UNIT := 3.0
const MINION_DAMAGE := 4.0
const MINION_HP := 9.0
const WALK_SPEED := 4.0
const RUN_SPEED := 8.0
const ROLL_IFRAME_TICKS := 18
const ROLL_TICKS := 30
const ROLL_DISTANCE := 3.0
const MAX_STAMINA := 50.0
const ROLL_COST := 10.0
const START_MANA := 50.0
const LONG := 100000             # a rule window outlasting every test here

## REVIEW N4/N5: two numbers the SHARED fixture deliberately leaves at their `0.0` defaults, authored
## IN TEST by the one test that needs each. Both would make their test vacuous at zero -- a zero phase
## multiplier roots the attacking hero, so nothing could show the slow failing to scale it, and a zero
## drain rate makes "the drain is unscaled" true of two zeroes. They are set on a COPY of `_config()`
## handed to `_make_match`, never in `_config()` itself, so no other test in this file moves.
const ATTACK_PHASE_MULT := 0.5
const RUN_DRAIN_PER_SECOND := 6.0

## The fixture's in-test effect numbers, DISTINCT from each other and from Deck 1's where it matters.
const BLOODLUST_SECONDS := 10.0
const AURA_SECONDS := 15.0
const AURA_FRACTION := 0.5
const HOUND_SECONDS := 5.0
const HOUND_DISTANCE := 3.0
const HOUND_IFRAMES := 2.0
const FROST_SECONDS := 6.0
const FROST_SLOW := 0.5
const FROST_SLOW_SECONDS := 4.0

const ID_BLOODLUST := &"sf_bloodlust"
const ID_AURA := &"sf_aura"
const ID_HOUND := &"sf_hound"
const ID_FROST := &"sf_frost"
## Story 6-5b: WAS `ID_CULLING := &"sf_culling"`, carrying the `culling` effect id. That id is no
## longer deferred -- 6-5b builds Culling, so it left `DEFERRED_EFFECT_OWNERS` and now resolves to a
## real outcome that REFUSES with no own living minion (`6-5b/R14`). The two tests here that need a
## STILL-DEFERRED effect (the no-op cast, and the last-resolved-card record on a no-op) are repointed
## at `rocksling`, which 6-5d owns -- so each keeps testing what it was written to test rather than
## being rewritten around Culling's new behaviour. Culling's own behaviour is tested in
## test_own_minion_spells.gd.
const ID_DEFERRED := &"sf_deferred"
## Two copies of the Bloodlust card, so the REFRESH test can recast while the first is still running.
const DECK: Array[StringName] = [ID_BLOODLUST, ID_BLOODLUST, ID_AURA, ID_HOUND, ID_FROST, ID_DEFERRED]


# ------------------------------------------------------------------------ resolver (AC 4, 15, 16)

## AC 4: each buff resolves on its WHOLE id -- and a prefix-alike of one does not.
func test_the_resolver_dispatches_each_buff_on_its_whole_id() -> void:
	var flags := _flags()
	var expected := {
		&"bloodlust": CardEffectResolver.OUTCOME_BLOODLUST,
		&"vampiric_aura": CardEffectResolver.OUTCOME_VAMPIRIC_AURA,
		&"bloodhound_step": CardEffectResolver.OUTCOME_BLOODHOUND_STEP,
		&"frostbite": CardEffectResolver.OUTCOME_FROSTBITE,
	}
	for id: StringName in expected:
		assert_eq(CardEffectResolver.outcome(_effect(id), flags), expected[id], "%s resolves by whole id" % id)
	assert_eq(CardEffectResolver.outcome(_effect(&"bloodlust_extra"), flags),
		CardEffectResolver.REASON_UNKNOWN_EFFECT_PREFIX,
		"a PREFIX of a buff id is not that buff -- the match is on the whole id")
	assert_eq(CardEffectResolver.outcome(_effect(&"summon_ruin_vanguard"), flags),
		CardEffectResolver.OUTCOME_SUMMON, "Ruin Vanguard takes the unchanged summon_* path")


## AC 16: the four buffs gate on `spells`; Ruin Vanguard keeps gating on `minions`.
func test_a_closed_spell_layer_closes_the_buffs_and_not_ruin_vanguard() -> void:
	var closed := _flags()
	closed.spells = false
	for id: StringName in [&"bloodlust", &"vampiric_aura", &"bloodhound_step", &"frostbite"]:
		assert_eq(CardEffectResolver.outcome(_effect(id), closed),
			CardEffectResolver.REASON_SPELLS_FLAG_CLOSED, "%s is closed with the spell layer" % id)
	assert_eq(CardEffectResolver.outcome(_effect(&"summon_ruin_vanguard"), closed),
		CardEffectResolver.OUTCOME_SUMMON, "Ruin Vanguard does not read the spell flag")
	var no_minions := _flags()
	no_minions.minions = false
	assert_eq(CardEffectResolver.outcome(_effect(&"summon_ruin_vanguard"), no_minions),
		CardEffectResolver.REASON_MINIONS_FLAG_CLOSED, "...it gates on minions, as it always has")
	assert_eq(CardEffectResolver.outcome(_effect(&"bloodlust"), null),
		CardEffectResolver.REASON_SPELLS_FLAG_CLOSED, "no flags injected reads CLOSED")


## AC 15 (`6-5a/R19`): every deferred effect maps to its owning story, and each resolves as the named
## no-op. The table holds exactly these rows and no more.
##
## STORY 6-5b: NINE -> FIVE, and the four that left are the four this story BUILT. That is the deferred
## table's mechanism working exactly as designed -- a row names the story that owns building the
## effect, and the story that builds it retires the row. The four are asserted the other way round in
## `test_own_minion_spells.gd`: `owner_story_for` answers `&""` for each of them now, and each resolves
## to a real outcome rather than the no-op. RENAMED from
## `test_the_nine_deferred_effects_name_their_owning_story` for the count-in-the-name discipline this
## repo applies to every pin (the `test_the_recorder_still_ships_exactly_N_capture_channels`
## precedent); the old name is recorded here verbatim so the pin stays greppable.
## STORY 6-5c: FIVE -> FOUR, and the one that left is the one this story BUILT. The same mechanism
## 6-5b exercised, one row at a time: `honed_bolt` named 6-5c as its owner, 6-5c builds it, the row
## retires. Asserted the other way round in `test_hero_cast.gd`: `owner_story_for(&"honed_bolt")`
## answers `&""` now and it resolves to `OUTCOME_HONED_BOLT`. RENAMED from
## `test_the_five_deferred_effects_name_their_owning_story` for the count-in-the-name discipline;
## the old name is recorded here verbatim so the pin stays greppable.
## STORY 6-5d: THE COUNT DOES NOT MOVE AND THREE OWNERS DO (AC 35, `6-5d/R14`). No row leaves -- 6-5d
## builds `fireball`, which was never a row here, because Bloodhound Step's pitch was the `bloodlust`
## BUFF until this story. What moved is the BOARD: `6-5d-hero-and-corpse-projectiles` was renamed
## `6-5d-fireball-and-spell-targeting` and `6-5e-boulder-injection` was renamed
## `6-5e-rocksling-boom-and-corpse-bomb`, so all three rows named stories that no longer exist. All three
## now name the 6-5e key -- the story that actually builds them.
func test_the_four_deferred_effects_name_their_owning_story() -> void:
	var owners := {
		&"rocksling": &"6-5e-rocksling-boom-and-corpse-bomb",
		&"boom": &"6-5e-rocksling-boom-and-corpse-bomb",
		&"counterspell": &"6-5f-counterspell",
		&"corpse_bomb": &"6-5e-rocksling-boom-and-corpse-bomb",
	}
	assert_eq(CardEffectResolver.DEFERRED_EFFECT_OWNERS.size(), 4,
		"exactly FOUR deferred rows -- FIVE before 6-5c, which retired the one naming itself; "
		+ "NINE before 6-5b, which retired the four naming itself. 6-5d retired NONE: it built "
		+ "`fireball`, which was never deferred (it is a NEW effect, not a re-pointed row)")
	# Story 6-5d (AC 35): `fireball` is NOT a deferred row -- the negative half of the rename, asserted so
	# a future pass cannot add one and quietly turn a shipped cast back into a no-op.
	assert_eq(CardEffectResolver.owner_story_for(&"fireball"), &"",
		"fireball is BUILT by 6-5d and has no deferred-owner row")
	for id: StringName in owners:
		assert_eq(CardEffectResolver.owner_story_for(id), owners[id], "%s is owned by %s" % [id, owners[id]])
		assert_eq(CardEffectResolver.outcome(_effect(id), _flags()),
			CardEffectResolver.REASON_DECK1_NOT_YET_RESOLVED, "%s resolves as the named no-op" % id)
	assert_eq(CardEffectResolver.owner_story_for(&"bloodlust"), &"", "an implemented buff has no owner row")


# ------------------------------------------------------------------------ casting (AC 5, 8, 15, 16)

## AC 8 / AC 5: each buff's CAST starts its rule on the caster's seat with its authored numbers, the
## seconds converted to ticks at the application.
func test_each_buff_cast_starts_its_rule_with_its_authored_numbers() -> void:
	var ms := _make_match()
	_cast(ms, ID_BLOODLUST)
	_assert_rule(ms.p1, PlayerState.RULE_BLOODLUST, _ticks(BLOODLUST_SECONDS), 2.0, 2.0, "Bloodlust")
	_cast(ms, ID_AURA)
	_assert_rule(ms.p1, PlayerState.RULE_VAMPIRIC_AURA, _ticks(AURA_SECONDS), AURA_FRACTION, 0.0, "Aura")
	_cast(ms, ID_HOUND)
	_assert_rule(ms.p1, PlayerState.RULE_BLOODHOUND_ARMED, _ticks(HOUND_SECONDS), HOUND_DISTANCE,
			HOUND_IFRAMES, "Bloodhound")
	_cast(ms, ID_FROST)
	_assert_rule(ms.p1, PlayerState.RULE_FROSTBITE_ARMED, _ticks(FROST_SECONDS), FROST_SLOW,
			float(_ticks(FROST_SLOW_SECONDS)), "Frostbite")
	assert_false(ms.p2.is_rule_active(PlayerState.RULE_BLOODLUST), "...on the CASTER's seat only")


## AC 16: with the spell layer closed a buff card still CASTS -- mana spent, card discarded, replacement
## owed, no refusal -- and applies nothing.
func test_a_closed_spell_layer_casts_the_card_and_applies_nothing() -> void:
	var closed := _flags()
	closed.spells = false
	var ms := _make_match(closed)
	_assert_successful_no_op_cast(ms, ID_BLOODLUST, "spells closed")


## AC 15: a deferred Deck 1 effect is a SUCCESSFUL cast that applies nothing (`4-1/R3`/`4-1/R10`).
func test_a_deferred_effect_is_a_successful_cast_that_applies_nothing() -> void:
	var ms := _make_match()
	_assert_successful_no_op_cast(ms, ID_DEFERRED, "deferred Rocksling")
	assert_eq(ms.p1.units.size(), 0, "...and puts nothing on the board")


## N10: re-casting a running buff REFRESHES its duration and never stacks -- the second Bloodlust sets
## the window back to full and leaves the multiplier at 2x, not 4x.
func test_recasting_a_running_buff_refreshes_it_and_never_stacks() -> void:
	var ms := _make_match()
	_cast(ms, ID_BLOODLUST)
	_idle(ms, 100)
	assert_eq(ms.p1.rule_windows[PlayerState.RULE_BLOODLUST].remaining_ticks(),
		_ticks(BLOODLUST_SECONDS) - 100, "sanity: the first Bloodlust has run 100 ticks")
	_cast(ms, ID_BLOODLUST)
	_assert_rule(ms.p1, PlayerState.RULE_BLOODLUST, _ticks(BLOODLUST_SECONDS), 2.0, 2.0,
		"the recast REFRESHED the window to full and kept the 2x magnitude")
	var loss := _p1_hits_p2(ms)
	assert_eq(loss, HIT_DAMAGE * 2.0, "...so two Bloodlusts still deal 2x, never 4x")


## AC 8: a rule ends by expiry -- at its last tick it stops, and a stopped rule applies nothing.
func test_a_buff_expires_after_its_window() -> void:
	var ms := _make_match()
	ms.p1.start_rule(PlayerState.RULE_BLOODLUST, 5, 2.0, 2.0)
	_idle(ms, 5)
	assert_false(ms.p1.is_rule_active(PlayerState.RULE_BLOODLUST), "five ticks later the rule has stopped")
	assert_eq(ms.p1.to_snapshot()["timed_rules"][PlayerState.RULE_BLOODLUST], [0, 0.0, 0.0],
		"...and snapshots at rest, whatever it last held")
	assert_eq(_p1_hits_p2(ms), HIT_DAMAGE, "...and damage is back to the base number")


## N10: round end and the debug reset clear every running rule and armed trigger, on both players.
##
## REVIEW B1 (operator ruling): ...and the LAST-RESOLVED-CARD record with them, at BOTH SEATS, on BOTH
## paths -- the ninth named reset exception. The dev pass cleared it on neither path and pinned neither
## direction, which left the only round-crossing hashed field added since 4-1 that a later story could
## flip in either direction with the full suite still green. Both halves are asserted here so that
## cannot happen: the clear is the behaviour, and the resting pair is what it clears to.
func test_round_end_and_the_debug_reset_clear_every_rule() -> void:
	var reset := _make_match()
	for player: PlayerState in [reset.p1, reset.p2]:
		for kind in PlayerState.RULE_COUNT:
			player.start_rule(kind, LONG, 1.5, 1.5)
		player.record_resolved_card(ID_BLOODLUST, Enums.ModeKind.BASIC)
	for player: PlayerState in [reset.p1, reset.p2]:
		assert_eq(player.to_snapshot()["last_resolved_card"],
			[String(ID_BLOODLUST), Enums.ModeKind.BASIC],
			"sanity: both seats carry a resolved-card record going into the reset")
	var press := InputIntent.new()
	press.debug_reset = true
	_advance(reset, press, InputIntent.new())
	for player: PlayerState in [reset.p1, reset.p2]:
		for kind in PlayerState.RULE_COUNT:
			assert_false(player.is_rule_active(kind), "the debug reset cleared rule %d" % kind)
		assert_eq(player.to_snapshot()["last_resolved_card"], ["", PlayerState.NO_RESOLVED_MODE],
			"...and the last-resolved-card record, back to its resting pair (B1)")
	var ended := _make_match()
	ended.p1.start_rule(PlayerState.RULE_BLOODLUST, LONG, 2.0, 2.0)
	ended.p2.start_rule(PlayerState.RULE_FROSTBITE_SLOW, LONG, 0.5, 0.0)
	ended.p1.record_resolved_card(ID_AURA, Enums.ModeKind.PITCH)
	ended.p2.record_resolved_card(ID_FROST, Enums.ModeKind.BASIC)
	ended.p2.hero.take_damage(MAX_HP)
	_idle(ended, 1)
	assert_eq(ended.p2.hero.action_state, HeroState.ActionState.DEAD, "sanity: the round ended")
	assert_false(ended.p1.is_rule_active(PlayerState.RULE_BLOODLUST), "round end cleared the winner's buff")
	assert_false(ended.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "...and the loser's slow")
	for player: PlayerState in [ended.p1, ended.p2]:
		assert_eq(player.to_snapshot()["last_resolved_card"], ["", PlayerState.NO_RESOLVED_MODE],
			"...and round end clears the last-resolved-card record at BOTH seats too (B1)")


## REVIEW N3 (operator ruling): `start_rule` with a NON-POSITIVE duration CANCELS the slot instead of
## writing live magnitudes onto a window `start(0)` leaves stopped. The dev pass assigned `rule_a`/
## `rule_b` unconditionally; the stale pair was invisible in the HASH (`_rules_snapshot` masks a stopped
## slot) but really present in the STATE, and 6-5f's undo reads through this same seat.
func test_starting_a_rule_with_a_non_positive_duration_cancels_it_and_clears_its_magnitudes() -> void:
	var ms := _make_match()
	for duration: int in [0, -5]:
		ms.p1.start_rule(PlayerState.RULE_BLOODLUST, LONG, 2.0, 2.0)
		assert_true(ms.p1.is_rule_active(PlayerState.RULE_BLOODLUST), "sanity: a real duration runs")
		ms.p1.start_rule(PlayerState.RULE_BLOODLUST, duration, 9.0, 9.0)
		assert_false(ms.p1.is_rule_active(PlayerState.RULE_BLOODLUST),
			"a %d-tick duration leaves the rule stopped" % duration)
		assert_eq(ms.p1.rule_a[PlayerState.RULE_BLOODLUST], 0.0,
			"...and magnitude a is CLEARED, never left live on a stopped window (N3)")
		assert_eq(ms.p1.rule_b[PlayerState.RULE_BLOODLUST], 0.0, "...and magnitude b with it")
	assert_eq(_p1_hits_p2(ms), HIT_DAMAGE, "...so the hit is the unbuffed base number")


# ------------------------------------------------------------------------ pitch channel (AC 6, 7, 10)

## AC 6: the PITCH effect resolves at ACTIVATION, never at staging -- and the activation is announced as
## a PITCH resolution (AC 7) and recorded as one (AC 10).
func test_the_pitch_effect_resolves_at_activation_never_at_staging() -> void:
	var ms := _make_match()
	var resolved := _resolutions(ms)
	_advance(ms, _stage_intent(_slot_of(ms.p1, ID_AURA)), InputIntent.new())
	assert_true(ms.pitch.is_staged(0), "sanity: the Aura card is staged")
	assert_false(ms.p1.is_rule_active(PlayerState.RULE_VAMPIRIC_AURA), "STAGING applies no effect")
	assert_eq(ms.p1.to_snapshot()["last_resolved_card"], ["", PlayerState.NO_RESOLVED_MODE],
		"...and records nothing: a staged card has not resolved")
	assert_eq(resolved, [], "...and announces no resolution")
	_advance(ms, _activate_intent(), InputIntent.new())
	_assert_rule(ms.p1, PlayerState.RULE_VAMPIRIC_AURA, _ticks(AURA_SECONDS), AURA_FRACTION, 0.0,
		"ACTIVATION applies the card's PITCH effect")
	assert_eq(resolved, [[0, ID_AURA, Enums.ModeKind.PITCH]], "...announced as a PITCH resolution (AC 7)")
	assert_eq(ms.p1.to_snapshot()["last_resolved_card"], [String(ID_AURA), Enums.ModeKind.PITCH],
		"...and recorded as one (AC 10)")


## AC 6: the activation reads the PITCH map, not the Mode ① one -- a card whose pitch effect differs
## from its basic effect applies the pitch one.
func test_activation_reads_the_pitch_map_not_the_basic_one() -> void:
	var pitch_effects: Dictionary[StringName, CardEffect] = {}
	for id in DECK:
		pitch_effects[id] = _authored(&"frostbite")
	var ms := _make_match(null, pitch_effects)
	_advance(ms, _stage_intent(_slot_of(ms.p1, ID_BLOODLUST)), InputIntent.new())
	_advance(ms, _activate_intent(), InputIntent.new())
	assert_false(ms.p1.is_rule_active(PlayerState.RULE_BLOODLUST), "the BASIC effect did not apply")
	assert_true(ms.p1.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED), "the PITCH effect did")


## AC 10: the last-resolved-card record at the Mode ① seat -- `[id, BASIC]`, the id a String VALUE --
## and it is overwritten by each later resolution.
func test_the_last_resolved_card_is_recorded_at_the_basic_seat() -> void:
	var ms := _make_match()
	assert_eq(ms.p1.to_snapshot()["last_resolved_card"], ["", PlayerState.NO_RESOLVED_MODE], "rests empty")
	_cast(ms, ID_HOUND)
	var record: Array = ms.p1.to_snapshot()["last_resolved_card"]
	assert_eq(record, [String(ID_HOUND), Enums.ModeKind.BASIC], "a Mode ① cast records [id, BASIC]")
	assert_eq(typeof(record[0]), TYPE_STRING, "...the id a String VALUE, never a StringName")
	_cast(ms, ID_DEFERRED)
	assert_eq(ms.p1.to_snapshot()["last_resolved_card"], [String(ID_DEFERRED), Enums.ModeKind.BASIC],
		"...and a no-op cast is still a resolution, so it overwrites the record")
	assert_eq(ms.p2.to_snapshot()["last_resolved_card"], ["", PlayerState.NO_RESOLVED_MODE],
		"the other player's record is untouched")


## AC 6: the pitch-effect channel is LOAD-BEARING for replay. A run that activates a Bloodlust replays
## from its record to the live hash; the same record replayed WITHOUT the pitch-effect channel diverges.
func test_the_pitch_effect_channel_is_load_bearing_for_replay() -> void:
	var record := IntentRecorder.new()
	var ms := MatchState.new(MatchParams.new(SEED))
	record.capture_seed(SEED)
	var config := _config()
	record.capture_apply_balance(config)
	ms.apply_balance(config)
	var flags := _flags()
	record.capture_inject_feature_flags(flags)
	ms.inject_feature_flags(flags)
	record.capture_inject_deck(DECK)
	ms.inject_deck(DECK)
	record.capture_inject_card_costs(_costs())
	ms.inject_card_costs(_costs())
	record.capture_inject_card_effects(_basic_effects())
	ms.inject_card_effects(_basic_effects())
	var no_colors: Dictionary[StringName, Enums.CardColor] = {}
	for id in DECK:
		no_colors[id] = Enums.CardColor.RED
	record.capture_inject_card_colors(no_colors)
	ms.inject_card_colors(no_colors)
	# FREE to stage: a match starts at zero mana, and a direct grant would not ride the record.
	var free: Dictionary[StringName, CardCastCondition] = {}
	for id in DECK:
		free[id] = CardCastCondition.new()
	record.capture_inject_pitch_costs(free)
	ms.inject_pitch_costs(free)
	record.capture_inject_pitch_effects(_pitch_effects())
	ms.inject_pitch_effects(_pitch_effects())
	var stage_slot := -1
	for t in range(1, 8):
		var p1 := InputIntent.new()
		if t == 2:
			stage_slot = _slot_of(ms.p1, ID_BLOODLUST)
			p1 = _stage_intent(stage_slot)
		elif t == 3:
			p1 = _activate_intent()
		var intents: Array[InputIntent] = [p1, InputIntent.new()]
		record.capture_advance(intents)
		ms.advance(intents)
		ms.drain_signals()
	assert_true(ms.p1.is_rule_active(PlayerState.RULE_BLOODLUST), "sanity: the live run activated Bloodlust")
	var live := CanonicalHash.of(ms.to_snapshot())
	assert_eq(CanonicalHash.of(_replay(record, false).to_snapshot()), live,
		"the record replays to the live hash with the pitch-effect channel")
	assert_ne(CanonicalHash.of(_replay(record, true).to_snapshot()), live,
		"...and DIVERGES without it -- the channel carries what the activation applied")


# ------------------------------------------------------------------------ damage funnel (AC 9, R3)

## AC 9, the MELEE seat: at rest the hit is the base number; a Bloodlusted attacker deals its dealt
## multiplier, a Bloodlusted target takes its taken multiplier, both compound, and a blocked hit is
## funnelled AFTER the block multiplier.
func test_the_melee_seat_runs_through_the_damage_funnel() -> void:
	assert_eq(_p1_hits_p2(_make_match()), HIT_DAMAGE, "at rest the hit is the unchanged base number")
	var dealt := _make_match()
	dealt.p1.start_rule(PlayerState.RULE_BLOODLUST, LONG, 2.0, 5.0)
	assert_eq(_p1_hits_p2(dealt), HIT_DAMAGE * 2.0, "a Bloodlusted attacker deals its DEALT multiplier")
	var taken := _make_match()
	taken.p2.start_rule(PlayerState.RULE_BLOODLUST, LONG, 5.0, 3.0)
	assert_eq(_p1_hits_p2(taken), HIT_DAMAGE * 3.0, "a Bloodlusted target takes its TAKEN multiplier")
	var both := _make_match()
	both.p1.start_rule(PlayerState.RULE_BLOODLUST, LONG, 2.0, 2.0)
	both.p2.start_rule(PlayerState.RULE_BLOODLUST, LONG, 2.0, 2.0)
	assert_eq(_p1_hits_p2(both), HIT_DAMAGE * 4.0, "both sides buffed compound (2x out, then 2x in)")
	var blocked := _make_match()
	blocked.p1.start_rule(PlayerState.RULE_BLOODLUST, LONG, 2.0, 2.0)
	# REVIEW N1: the claim here was "never reordered with it", which nothing can falsify -- both steps
	# are scalar multiplies, so the two orders give the same number and a mutant that hoists the funnel
	# above the block multiply stays green. What this line actually pins is the VALUE: a blocked hit is
	# funnelled, and it is funnelled on the post-block number rather than on the full swing.
	assert_eq(_p1_hits_p2(blocked, true), HIT_DAMAGE * BLOCK_MULT * 2.0,
		"a BLOCKED hit is funnelled on what the block let through (the ORDER of the two scalar "
			+ "factors is unobservable -- see the funnel's own N1 note)")


## AC 9, the UNIT seat, and R3's body rule: a hero's hit on a unit is funnelled; a Bloodlusted side's
## MINION takes 2x; its TOTEM does not; a Bloodlusted hero still deals 2x to a totem.
func test_the_unit_seat_runs_through_the_funnel_and_a_totem_is_never_a_bloodlust_body() -> void:
	assert_eq(_p1_hits_p2_unit(_make_match(), 0), HERO_TO_UNIT, "at rest a hero hit on a minion is the base")
	var minion := _make_match()
	minion.p2.start_rule(PlayerState.RULE_BLOODLUST, LONG, 2.0, 2.0)
	assert_eq(_p1_hits_p2_unit(minion, 0), HERO_TO_UNIT * 2.0, "a Bloodlusted side's MINION takes 2x")
	var totem := _make_match()
	totem.p2.start_rule(PlayerState.RULE_BLOODLUST, LONG, 2.0, 2.0)
	assert_eq(_p1_hits_p2_unit(totem, 1), HERO_TO_UNIT, "...its TOTEM does not (R3: a totem is no minion)")
	var hero_out := _make_match()
	hero_out.p1.start_rule(PlayerState.RULE_BLOODLUST, LONG, 2.0, 2.0)
	assert_eq(_p1_hits_p2_unit(hero_out, 1), HERO_TO_UNIT * 2.0,
		"a Bloodlusted HERO still deals 2x -- to a totem too; it is the attacking body that is buffed")


## R3: a Bloodlusted player's MINION deals 2x (the melee seat, a unit attacker).
func test_a_bloodlusted_players_minion_deals_double() -> void:
	assert_eq(_p1_minion_hits_p2(_make_match()), MINION_DAMAGE, "at rest the minion deals its own damage")
	var buffed := _make_match()
	buffed.p1.start_rule(PlayerState.RULE_BLOODLUST, LONG, 2.0, 2.0)
	assert_eq(_p1_minion_hits_p2(buffed), MINION_DAMAGE * 2.0, "a Bloodlusted player's minion deals 2x")


# ------------------------------------------------------------------------ Vampiric Aura (R4, N10)

## R4 / N10: the caster's HERO heals 50% of the damage it ACTUALLY removed -- after block, capped by the
## target's remaining hp -- off a hero hit and off a hero hit on a unit.
func test_vampiric_aura_heals_half_the_damage_actually_removed() -> void:
	var full := _aura_match()
	_p1_hits_p2(full)
	assert_eq(full.p1.hero.get_hp(), MAX_HP - 20.0 + HIT_DAMAGE * AURA_FRACTION, "a full hit heals 50%")
	var blocked := _aura_match()
	_p1_hits_p2(blocked, true)
	assert_eq(blocked.p1.hero.get_hp(), MAX_HP - 20.0 + HIT_DAMAGE * BLOCK_MULT * AURA_FRACTION,
		"a BLOCKED hit heals 50% of what the block let through")
	var capped := _aura_match()
	capped.p2.hero.take_damage(MAX_HP - 2.0)
	capped.drain_signals()
	_p1_hits_p2(capped)
	assert_eq(capped.p1.hero.get_hp(), MAX_HP - 20.0 + 2.0 * AURA_FRACTION,
		"a hit that kills heals 50% of the 2.0 the target HAD, not of the 6.0 swing")
	var unit := _aura_match()
	_p1_hits_p2_unit(unit, 0)
	assert_eq(unit.p1.hero.get_hp(), MAX_HP - 20.0 + HERO_TO_UNIT * AURA_FRACTION,
		"a hero hit on a UNIT heals too -- it is damage the caster's hero dealt")


## R4: a MINION's damage never heals the caster, even though Bloodlust would buff it.
func test_vampiric_aura_never_heals_off_a_minion_hit() -> void:
	var ms := _aura_match()
	var dealt := _p1_minion_hits_p2(ms)
	assert_true(dealt > 0.0, "sanity: the minion's hit landed")
	assert_eq(ms.p1.hero.get_hp(), MAX_HP - 20.0, "...and the caster healed NOTHING from it (R4)")


## REVIEW N9: the three Vampiric Aura cases the dev pass left uncovered -- a hero hit that KILLS a unit,
## a heal that would take the caster ABOVE max hp, and a DEAD caster.
func test_vampiric_aura_on_a_lethal_unit_hit_at_the_max_hp_clamp_and_with_a_dead_caster() -> void:
	# (1) A KILLING hit on a unit heals off what the unit HAD, not off the full swing. The unit seat
	# measures `hp before - hp_at(index)` and `UnitBoard.apply_damage_at` clamps at zero and never
	# compacts, so the corpse stays at its index and the measurement is exact.
	var lethal := _aura_match()
	var unit_hp := HERO_TO_UNIT - 1.0
	lethal.p2.units.add(unit_hp, 0)
	_advance(lethal, _press(&"attack"), InputIntent.new())
	for _t in 2:
		_idle(lethal, 1)
	lethal.push_contact([0, -1], [1, 0], lethal.p1.hero.attack_index, Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_idle(lethal, 1)
	assert_false(lethal.p2.units.is_alive_at(0), "sanity: the hero's hit killed the minion")
	assert_eq(lethal.p1.hero.get_hp(), MAX_HP - 20.0 + unit_hp * AURA_FRACTION,
		"a KILLING hit on a unit heals 50%% of the %s the unit HAD, not of the full swing" % unit_hp)

	# (2) THE MAX-HP CLAMP: an oversized fraction cannot take the caster above its maximum, and the
	# seat reports the heal it ACTUALLY applied (R6) rather than the one it was asked for.
	var clamped := _make_match()
	clamped.p1.start_rule(PlayerState.RULE_VAMPIRIC_AURA, LONG, 10.0, 0.0)
	clamped.p1.hero.take_damage(1.0)
	clamped.drain_signals()
	var applied := clamped._apply_lifesteal(clamped.p1, TargetingService.HERO_INDEX, HIT_DAMAGE)
	assert_eq(clamped.p1.hero.get_hp(), MAX_HP, "a heal past max hp CLAMPS at max hp")
	assert_eq(applied, 1.0, "...and the seat returns the 1.0 it actually applied, not the 60.0 asked for")

	# (3) A DEAD CASTER heals nothing. The gate is hp-based on purpose -- see N8 below.
	var dead := _aura_match()
	dead.p1.hero.take_damage(MAX_HP)
	dead.drain_signals()
	assert_eq(dead._apply_lifesteal(dead.p1, TargetingService.HERO_INDEX, HIT_DAMAGE), 0.0,
		"a caster at zero hp heals nothing, and the seat says so by returning zero")
	assert_eq(dead.p1.hero.get_hp(), 0.0, "...and its hp is untouched")


## REVIEW N8: THE hp-BASED LIVENESS GATE IS DELIBERATE, and this is what it buys. `_attacker_is_dead`
## tests `action_state == DEAD` while `_apply_lifesteal` tests `hp > 0`; they disagree for exactly one
## tick, because `DEAD` is not written until step 8. On a MUTUAL-KILL tick the hero already at zero hp
## still resolves its queued fact and deals full damage -- but it must NOT heal, or the heal would put
## it back above zero before step 8 reads liveness and would flip the round's outcome.
##
## Contact order is attacker SLOT ascending, so P1's fact always resolves first: the Aura is on P2, the
## hero that is already dead when its own fact resolves. A "consistency fix" switching the gate to
## `action_state != DEAD` leaves P2 alive at 3.0 hp here and fails every assertion below.
func test_vampiric_aura_never_revives_its_caster_on_a_mutual_kill() -> void:
	var ms := _make_match()
	ms.p2.start_rule(PlayerState.RULE_VAMPIRIC_AURA, LONG, AURA_FRACTION, 0.0)
	ms.p1.hero.take_damage(MAX_HP - HIT_DAMAGE)
	ms.p2.hero.take_damage(MAX_HP - HIT_DAMAGE)
	ms.drain_signals()
	_advance(ms, _press(&"attack"), _press(&"attack"))
	for _t in 2:
		_idle(ms, 1)
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	ms.push_contact([1, -1], [0, -1], ms.p2.hero.attack_index, Vector2.UP, MatchState.CONTACT_STRIKE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.get_hp(), 0.0,
		"sanity: the Aura caster's own fact still resolved from zero hp and dealt its full damage")
	assert_eq(ms.p2.hero.get_hp(), 0.0,
		"the Aura caster is at ZERO -- the heal did not revive it before step 8 (N8)")
	assert_false(ms.p2.hero.is_alive(), "...so it is dead, and the kill it took stands")


# ------------------------------------------------------------------------ Bloodhound Step (R2)

## R2: the next roll within the window covers 3x the distance in the SAME duration, its i-frames are 2x
## CLAMPED to the roll (min(2 x 18, 30) = 30), and the trigger is consumed.
func test_bloodhound_boosts_the_next_roll_and_is_consumed() -> void:
	var ms := _make_match()
	ms.p1.start_rule(PlayerState.RULE_BLOODHOUND_ARMED, LONG, HOUND_DISTANCE, HOUND_IFRAMES)
	_advance(ms, _roll_intent(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ROLLING, "sanity: the roll started")
	assert_eq(ms.p1.hero.velocity.length(), ROLL_DISTANCE * HOUND_DISTANCE / (ROLL_TICKS / 60.0),
		"the boosted roll travels 3x the distance over the SAME duration")
	assert_eq(ms.p1.hero.roll_iframe.duration_ticks(), ROLL_TICKS,
		"2x i-frames CLAMPED to the roll's duration -- the whole roll is invulnerable")
	assert_eq(ms.p1.hero.roll_duration.duration_ticks(), ROLL_TICKS, "the roll's duration is unchanged")
	assert_false(ms.p1.is_rule_active(PlayerState.RULE_BLOODHOUND_ARMED), "the trigger was consumed")
	_idle(ms, ROLL_TICKS)
	assert_false(ms.p1.is_rule_active(PlayerState.RULE_ROLL_BOOST), "the boost ends with the roll")
	_advance(ms, _roll_intent(), InputIntent.new())
	assert_eq(ms.p1.hero.velocity.length(), ROLL_DISTANCE / (ROLL_TICKS / 60.0),
		"the NEXT roll is an ordinary one")
	assert_eq(ms.p1.hero.roll_iframe.duration_ticks(), ROLL_IFRAME_TICKS, "...with ordinary i-frames")


## R2: a roll REFUSED for stamina does not consume the armed trigger -- it persists for the next attempt.
func test_a_roll_refused_for_stamina_keeps_bloodhound_armed() -> void:
	var ms := _make_match()
	ms.p1.start_rule(PlayerState.RULE_BLOODHOUND_ARMED, LONG, HOUND_DISTANCE, HOUND_IFRAMES)
	ms.p1.stamina.spend(ms.p1.stamina.get_current(), 0)
	_advance(ms, _roll_intent(), InputIntent.new())
	assert_ne(ms.p1.hero.action_state, HeroState.ActionState.ROLLING, "sanity: the roll was refused")
	assert_true(ms.p1.is_rule_active(PlayerState.RULE_BLOODHOUND_ARMED),
		"a stamina-refused roll leaves Bloodhound ARMED (R2)")
	ms.p1.stamina.refill()
	_advance(ms, _roll_intent(), InputIntent.new())
	assert_eq(ms.p1.hero.velocity.length(), ROLL_DISTANCE * HOUND_DISTANCE / (ROLL_TICKS / 60.0),
		"...and the next roll that actually starts is the boosted one")


## REVIEW N10 (operator ruling): THE STALE-BOOST GUARD, `else: cancel_rule(RULE_ROLL_BOOST)` at the roll
## seat, which the dev pass neither tested nor mutated -- and deleting it DID come back green (mutation
## M17, first state). The Edge Case layer found no reachable stale-boost path in today's timings
## (knockdown stun is 150 ticks against a 30-tick roll), so the guard is correct but was unproven; this
## is the test that proves it, and it proves the GUARD rather than a path to it.
##
## The stale boost is therefore SEATED DIRECTLY, this file's standing idiom -- a `ROLL_BOOST` outliving
## its roll, which is exactly the state the guard exists to erase. Without the guard the next ORDINARY
## roll reads that leftover multiplier and travels 3x.
func test_an_unboosted_roll_cancels_a_stale_roll_boost_instead_of_riding_it() -> void:
	var ms := _make_match()
	ms.p1.start_rule(PlayerState.RULE_ROLL_BOOST, LONG, HOUND_DISTANCE, 0.0)
	assert_false(ms.p1.is_rule_active(PlayerState.RULE_BLOODHOUND_ARMED),
		"sanity: no trigger is armed, so this roll takes the guard's branch")
	_advance(ms, _roll_intent(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ROLLING, "sanity: the roll started")
	assert_false(ms.p1.is_rule_active(PlayerState.RULE_ROLL_BOOST),
		"an unboosted roll CANCELS a stale boost rather than inheriting it (N10)")
	assert_eq(ms.p1.hero.velocity.length(), ROLL_DISTANCE / (ROLL_TICKS / 60.0),
		"...so it travels the ordinary distance, not the stale 3x")


## R2: a roll taken after the window has closed is unaffected.
func test_a_roll_after_the_bloodhound_window_is_unaffected() -> void:
	var ms := _make_match()
	_cast(ms, ID_HOUND)
	_idle(ms, _ticks(HOUND_SECONDS))
	assert_false(ms.p1.is_rule_active(PlayerState.RULE_BLOODHOUND_ARMED), "sanity: the window closed")
	_advance(ms, _roll_intent(), InputIntent.new())
	assert_eq(ms.p1.hero.velocity.length(), ROLL_DISTANCE / (ROLL_TICKS / 60.0), "an ordinary roll")


# ------------------------------------------------------------------------ Frostbite (R5)

## R5: the caster's next CONFIRMED hero melee hit on the enemy hero -- blocked included -- slows the
## ENEMY for the authored ticks and consumes the trigger.
func test_frostbite_slows_the_enemy_on_the_next_confirmed_melee_hit() -> void:
	for blocked: bool in [false, true]:
		var ms := _make_match()
		ms.p1.start_rule(PlayerState.RULE_FROSTBITE_ARMED, LONG, FROST_SLOW, float(_ticks(FROST_SLOW_SECONDS)))
		_p1_hits_p2(ms, blocked)
		var label := "blocked" if blocked else "unblocked"
		_assert_rule(ms.p2, PlayerState.RULE_FROSTBITE_SLOW, _ticks(FROST_SLOW_SECONDS), FROST_SLOW, 0.0,
			"an %s confirmed hit slows the ENEMY hero" % label)
		assert_false(ms.p1.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED), "...and consumes the trigger")
		assert_false(ms.p1.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "...never slowing the caster")


## R5: a DEFLECTED hit is not confirmed -- it neither slows nor consumes the trigger. Nor does a hit on a
## unit.
func test_a_deflected_hit_or_a_unit_hit_neither_slows_nor_consumes_frostbite() -> void:
	var ms := _make_match()
	ms.p1.start_rule(PlayerState.RULE_FROSTBITE_ARMED, LONG, FROST_SLOW, float(_ticks(FROST_SLOW_SECONDS)))
	var deflects: Array = []
	ms.deflect_landed.connect(func(a: int, t: int, _c: int) -> void: deflects.append([a, t]))
	_p1_hits_p2_deflected(ms)
	assert_eq(deflects.size(), 1, "sanity: the hit was DEFLECTED")
	assert_false(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "a deflected hit slows nothing")
	assert_true(ms.p1.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED), "...and the trigger stays armed")
	var unit := _make_match()
	unit.p1.start_rule(PlayerState.RULE_FROSTBITE_ARMED, LONG, FROST_SLOW, float(_ticks(FROST_SLOW_SECONDS)))
	_p1_hits_p2_unit(unit, 0)
	assert_true(unit.p1.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED), "a hit on a UNIT does not consume it")


## REVIEW N2 (operator ruling), case (b): a hit that would carry a ZERO-TICK slow neither slows nor
## consumes the trigger. An effect authored with a `slow_duration_seconds` that converts to <= 0 ticks
## would otherwise burn a 4-mana card for nothing -- `start_rule` cancels the slot (N3) while the
## trigger is spent regardless. The trigger stays armed for the next hit, the refused roll's precedent.
func test_a_zero_duration_slow_neither_slows_nor_consumes_frostbite() -> void:
	var ms := _make_match()
	ms.p1.start_rule(PlayerState.RULE_FROSTBITE_ARMED, LONG, FROST_SLOW, 0.0)
	assert_eq(_p1_hits_p2(ms), HIT_DAMAGE, "sanity: the hit landed at the base number")
	assert_false(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "a zero-tick slow starts nothing")
	assert_true(ms.p1.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED),
		"...and the trigger is NOT spent on it (N2)")
	assert_eq(ms.p1.rule_b[PlayerState.RULE_FROSTBITE_ARMED], 0.0, "...with its zero duration intact")


## REVIEW N2 (operator ruling), case (a): a KILLING blow does not spend the trigger. `_end_round` clears
## every rule on both sides on the very tick the enemy dies, so a slow started here would be deleted the
## same tick and the card's whole payload lost.
##
## MEASURED AT THE SEAT, not through `advance()`, and that is forced rather than convenient: because
## `_end_round` clears BOTH players' rules on the killing tick, the armed trigger and the slow are both
## gone at the end of that tick whichever way this branch goes -- the behaviour is observable ONLY
## before step 8 runs. This file already proves seats directly (`start_rule` throughout) for the same
## reason.
func test_a_killing_blow_does_not_spend_the_frostbite_trigger() -> void:
	var ms := _make_match()
	ms.p1.start_rule(PlayerState.RULE_FROSTBITE_ARMED, LONG, FROST_SLOW, float(_ticks(FROST_SLOW_SECONDS)))
	ms.p2.hero.take_damage(MAX_HP)
	ms.drain_signals()
	assert_false(ms.p2.hero.is_alive(), "sanity: the target is at zero hp, as it is after a lethal hit")
	ms._consume_frostbite(ms.p1, ms.p2)
	assert_false(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "a corpse is not slowed")
	assert_true(ms.p1.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED),
		"...and the trigger is NOT spent on the killing blow (N2)")
	var live := _make_match()
	live.p1.start_rule(PlayerState.RULE_FROSTBITE_ARMED, LONG, FROST_SLOW,
			float(_ticks(FROST_SLOW_SECONDS)))
	live._consume_frostbite(live.p1, live.p2)
	assert_true(live.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW),
		"control: the same call against a LIVING target does slow it")
	assert_false(live.p1.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED), "...and does spend the trigger")


## REVIEW N4 (operator ruling): THE SLOW NEVER SCALES THE ATTACKING GAIT. R5 names three gaits -- walk,
## run, block-walk -- and the attack is not one of them, but an ATTACKING hero falls through to
## `walk_speed` and would be scaled with them. It is invisible at shipped tuning only because all three
## `attack_*_move_speed_multiplier` values are authored `0.0`; this test authors them NON-ZERO IN TEST
## (never in data/, `BC/R3`) so the fourth gait is actually moving and the assertion can bite.
func test_the_frostbite_slow_never_scales_the_attacking_gait() -> void:
	var config := _config()
	config.attack_windup_move_speed_multiplier = ATTACK_PHASE_MULT
	config.attack_active_move_speed_multiplier = ATTACK_PHASE_MULT
	config.attack_recovery_move_speed_multiplier = ATTACK_PHASE_MULT
	var ms := _make_match(null, null, config)
	ms.p1.start_rule(PlayerState.RULE_FROSTBITE_SLOW, LONG, FROST_SLOW, 0.0)
	var steer := InputIntent.new()
	steer.move_dir = Vector2(1.0, 0.0)
	_advance(ms, steer, InputIntent.new())
	assert_eq(ms.p1.hero.velocity.length(), WALK_SPEED * FROST_SLOW,
		"sanity: the slow is live -- an ordinary walk in this match IS slowed")
	_advance(ms, _press(&"attack"), InputIntent.new())
	_advance(ms, steer, InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ATTACKING, "sanity: mid-swing")
	assert_true(ms.p1.hero.velocity.length() > 0.0,
		"sanity: the in-test phase multiplier is non-zero, so the attacking gait actually moves")
	assert_eq(ms.p1.hero.velocity.length(), WALK_SPEED * ATTACK_PHASE_MULT,
		"the ATTACKING gait is the phase multiplier ALONE -- the slow does not touch it (N4)")
	assert_true(ms.p1.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW),
		"...and the slow is still running, so this is a gate and not an expiry")


## REVIEW N5 (operator ruling): the slow halves the run's SPEED and leaves its STAMINA PRICE alone -- a
## slowed hero pays full stamina for half the distance, and that compounding is the ruled behaviour
## rather than an oversight. The drain was already unscaled in the dev pass; this is its pin. The drain
## rate is authored IN TEST (the shared fixture leaves it at zero, which would make this vacuous).
func test_the_frostbite_slow_halves_run_speed_and_not_run_stamina_drain() -> void:
	var config := _config()
	config.run_stamina_drain_per_second = RUN_DRAIN_PER_SECOND
	var run := InputIntent.new()
	run.move_dir = Vector2(1.0, 0.0)
	run.held[&"run"] = true
	var control := _make_match(null, null, config)
	var control_before := control.p1.stamina.get_current()
	_advance(control, run, InputIntent.new())
	var control_drain := control_before - control.p1.stamina.get_current()
	assert_eq(control.p1.hero.velocity.length(), RUN_SPEED, "control: an unslowed run is full speed")
	assert_true(control_drain > 0.0, "sanity: running drains stamina at the in-test rate")
	var slowed := _make_match(null, null, config)
	slowed.p1.start_rule(PlayerState.RULE_FROSTBITE_SLOW, LONG, FROST_SLOW, 0.0)
	var slowed_before := slowed.p1.stamina.get_current()
	_advance(slowed, run, InputIntent.new())
	var slowed_drain := slowed_before - slowed.p1.stamina.get_current()
	assert_eq(slowed.p1.hero.velocity.length(), RUN_SPEED * FROST_SLOW, "a slowed run is half the speed")
	assert_eq(slowed_drain, control_drain,
		"...and pays exactly the SAME stamina for that half distance -- the slow taxes distance, "
			+ "never the pool (N5)")


## R5: the slow scales walk, run AND block-walk; a roll is NOT slowed.
func test_the_frostbite_slow_scales_walk_run_and_block_walk_but_not_a_roll() -> void:
	var ms := _make_match()
	ms.p1.start_rule(PlayerState.RULE_FROSTBITE_SLOW, LONG, FROST_SLOW, 0.0)
	var walk := InputIntent.new()
	walk.move_dir = Vector2(1.0, 0.0)
	_advance(ms, walk, InputIntent.new())
	assert_eq(ms.p1.hero.velocity.length(), WALK_SPEED * FROST_SLOW, "walk is slowed")
	var run := InputIntent.new()
	run.move_dir = Vector2(1.0, 0.0)
	run.held[&"run"] = true
	_advance(ms, run, InputIntent.new())
	assert_eq(ms.p1.hero.velocity.length(), RUN_SPEED * FROST_SLOW, "run is slowed")
	var block := InputIntent.new()
	block.move_dir = Vector2(1.0, 0.0)
	block.pressed[&"block"] = true
	block.held[&"block"] = true
	_advance(ms, block, InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.BLOCKING, "sanity: blocking")
	assert_eq(ms.p1.hero.velocity.length(), WALK_SPEED * FROST_SLOW, "block-walk is slowed (R5's widening)")
	var release := InputIntent.new()
	_advance(ms, release, InputIntent.new())
	_advance(ms, _roll_intent(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ROLLING, "sanity: rolling")
	assert_eq(ms.p1.hero.velocity.length(), ROLL_DISTANCE / (ROLL_TICKS / 60.0), "a roll is NOT slowed")
	var unslowed := _make_match()
	_advance(unslowed, walk, InputIntent.new())
	assert_eq(unslowed.p1.hero.velocity.length(), WALK_SPEED, "control: an unslowed walk is the base speed")


# ------------------------------------------------------------------------ helpers

func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.move_speed = RUN_SPEED
	c.walk_speed = WALK_SPEED
	c.max_stamina = MAX_STAMINA
	c.max_mana = 90.0
	c.deck_size = DECK.size()
	c.hand_size = DECK.size()
	c.draw_replacement_delay_seconds = 60.0
	c.pitch_stage_timer_seconds = 60.0
	c.stamina_regen_per_second = 0.0
	c.stamina_regen_delay_seconds = 1.0
	c.roll_stamina_cost = ROLL_COST
	c.roll_iframe_seconds = ROLL_IFRAME_TICKS / 60.0
	c.roll_duration_seconds = ROLL_TICKS / 60.0
	c.roll_distance = ROLL_DISTANCE
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 6.0
	c.block_damage_multiplier = BLOCK_MULT
	c.deflect_stamina_cost = 8.0
	c.deflect_window_seconds = 4.0 / 60.0
	c.block_facing_arc_degrees = 180.0
	c.deflect_stun_seconds = 5.0 / 60.0
	c.hero_damage_to_unit = HERO_TO_UNIT
	c.minion_retarget_interval_seconds = 1000.0
	var kinds: Array[UnitKindProfile] = [
		UnitKindFixture.melee(CardEffectResolver.KIND_MINION, MINION_HP, MINION_DAMAGE, 2, 3, 4, 2.0),
		UnitKindFixture.inert(CardEffectResolver.KIND_COMBAT_TOTEM, MINION_HP),
	]
	c.unit_kinds = kinds
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	f.pitch_zone = true
	f.minions = true
	f.totems = true
	f.spells = true
	return f


## REVIEW N4/N5: `config` overrides the shared fixture config for the two tests that must author a
## number `_config()` leaves at zero. Null -- every other caller -- is `_config()` exactly as before.
func _make_match(flags: FeatureFlags = null, pitch_effects: Variant = null,
		config: BalanceConfig = null) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(config if config != null else _config())
	ms.inject_feature_flags(flags if flags != null else _flags())
	ms.inject_deck(DECK)
	ms.inject_card_costs(_costs())
	ms.inject_card_effects(_basic_effects())
	ms.inject_pitch_costs(_pitch_costs())
	var effects: Dictionary[StringName, CardEffect] = _pitch_effects()
	if pitch_effects != null:
		effects = pitch_effects
	ms.inject_pitch_effects(effects)
	_idle(ms, 1)   # the step-6 deal
	ms.p1.mana.add(START_MANA)
	ms.p2.mana.add(START_MANA)
	ms.drain_signals()
	return ms


## P1 at 80 hp with Vampiric Aura running, so a heal is observable.
func _aura_match() -> MatchState:
	var ms := _make_match()
	ms.p1.start_rule(PlayerState.RULE_VAMPIRIC_AURA, LONG, AURA_FRACTION, 0.0)
	ms.p1.hero.take_damage(20.0)
	ms.drain_signals()
	return ms


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in DECK:
		var c := CardCastCondition.new()
		c.mana_cost = 1.0
		out[id] = c
	return out


func _pitch_costs() -> Dictionary[StringName, CardCastCondition]:
	return _costs()


## Each fixture card's Mode ① effect: the buff its id names (Rocksling a deferred no-op, repointed
## from Culling by 6-5b).
func _basic_effects() -> Dictionary[StringName, CardEffect]:
	var ids := {ID_BLOODLUST: &"bloodlust", ID_AURA: &"vampiric_aura", ID_HOUND: &"bloodhound_step",
			ID_FROST: &"frostbite", ID_DEFERRED: &"rocksling"}
	var out: Dictionary[StringName, CardEffect] = {}
	for id in DECK:
		out[id] = _authored(ids[id])
	return out


## The same effects on the pitch side, unless a test injects its own map.
func _pitch_effects() -> Dictionary[StringName, CardEffect]:
	return _basic_effects()


## One in-test CardEffect carrying this file's numbers for `effect_id`.
func _authored(effect_id: StringName) -> CardEffect:
	var e := _effect(effect_id)
	match effect_id:
		&"bloodlust":
			e.duration_seconds = BLOODLUST_SECONDS
			e.damage_dealt_multiplier = 2.0
			e.damage_taken_multiplier = 2.0
		&"vampiric_aura":
			e.duration_seconds = AURA_SECONDS
			e.lifesteal_fraction = AURA_FRACTION
		&"bloodhound_step":
			e.duration_seconds = HOUND_SECONDS
			e.roll_distance_multiplier = HOUND_DISTANCE
			e.roll_iframe_multiplier = HOUND_IFRAMES
		&"frostbite":
			e.duration_seconds = FROST_SECONDS
			e.slow_speed_multiplier = FROST_SLOW
			e.slow_duration_seconds = FROST_SLOW_SECONDS
	return e


func _effect(effect_id: StringName) -> CardEffect:
	var e := CardEffect.new()
	e.effect_id = effect_id
	return e


func _ticks(seconds: float) -> int:
	return TimingWindow.seconds_to_ticks(seconds)


func _assert_rule(player: PlayerState, kind: int, remaining: int, a: float, b: float, label: String) -> void:
	assert_true(player.is_rule_active(kind), "%s: the rule is running" % label)
	assert_eq(player.rule_windows[kind].remaining_ticks(), remaining, "%s: remaining ticks" % label)
	assert_eq(player.rule_a[kind], a, "%s: magnitude a" % label)
	assert_eq(player.rule_b[kind], b, "%s: magnitude b" % label)


## `4-1/R3`/`4-1/R10`: a cast that resolves to no applied effect is still a SUCCESSFUL cast.
func _assert_successful_no_op_cast(ms: MatchState, id: StringName, label: String) -> void:
	var rejections := _rejections(ms.p1)
	var mana_before := ms.p1.mana.get_current()
	var slot := _slot_of(ms.p1, id)
	_advance(ms, _cast_intent(slot), InputIntent.new())
	assert_eq(rejections, [], "%s: no refusal on any path" % label)
	assert_eq(ms.p1.mana.get_current(), mana_before - 1.0, "%s: the mana is spent" % label)
	assert_true(ms.p1.discard.to_array().has(id), "%s: the card is discarded" % label)
	assert_eq(ms.p1.pending_draw_owed, [slot] as Array[int], "%s: its replacement is owed" % label)
	for kind in PlayerState.RULE_COUNT:
		assert_false(ms.p1.is_rule_active(kind), "%s: no rule was started (%d)" % [label, kind])


## P1's hero lands ONE melee hit on P2's hero (swing pressed, the contact pushed inside its active
## window); returns the hp P2 lost. `blocked` has P2 hold block with no stamina to deflect.
func _p1_hits_p2(ms: MatchState, blocked := false) -> float:
	var p2 := InputIntent.new()
	if blocked:
		ms.p2.stamina.spend(ms.p2.stamina.get_current(), 0)
		p2.pressed[&"block"] = true
		p2.held[&"block"] = true
	_advance(ms, _press(&"attack"), p2)
	for _t in 2:
		_advance(ms, InputIntent.new(), _held(&"block") if blocked else InputIntent.new())
	var before := ms.p2.hero.get_hp()
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms, InputIntent.new(), _held(&"block") if blocked else InputIntent.new())
	return before - ms.p2.hero.get_hp()


## P1's hero swings into P2's DEFLECT window (block pressed on the swing's own tick).
func _p1_hits_p2_deflected(ms: MatchState) -> void:
	_advance(ms, _press(&"attack"), _press(&"block"))
	for _t in 2:
		_advance(ms, InputIntent.new(), _held(&"block"))
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_advance(ms, InputIntent.new(), _held(&"block"))


## P1's hero hits P2's board unit of kind `kind_index` (0 minion, 1 totem); returns the hp it lost.
func _p1_hits_p2_unit(ms: MatchState, kind_index: int) -> float:
	ms.p2.units.add(MINION_HP, kind_index)
	_advance(ms, _press(&"attack"), InputIntent.new())
	for _t in 2:
		_idle(ms, 1)
	ms.push_contact([0, -1], [1, 0], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_idle(ms, 1)
	return MINION_HP - ms.p2.units.hp_at(0)


## P1's MINION lands one strike on P2's hero, through the real reach trigger and phase ladder (the
## test_block_deflect.gd 4-3b shape); returns the hp P2 lost.
func _p1_minion_hits_p2(ms: MatchState) -> float:
	ms.p1.units.add(MINION_HP, 0)
	ms.p1.units.set_target_at(0, 1, -1)
	ms.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
	_idle(ms, 4)
	var before := ms.p2.hero.get_hp()
	ms.push_contact([0, 0], [1, -1], ms.p1.units.attack_count_at(0), Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_idle(ms, 1)
	return before - ms.p2.hero.get_hp()


## Replay `record` into a fresh MatchState; `drop_pitch_effects` withholds the sixth content channel.
func _replay(record: IntentRecorder, drop_pitch_effects: bool) -> MatchState:
	var ms := MatchState.new(MatchParams.new(record.replay_seed()))
	ms.apply_balance(record.replay_balance_config(0))
	ms.inject_feature_flags(record.replay_feature_flags())
	if drop_pitch_effects:
		ms.inject_deck(record.replay_deck_contents())
		ms.inject_card_costs(record.replay_card_costs())
		ms.inject_card_effects(record.replay_card_effects())
		ms.inject_card_colors(record.replay_card_colors())
		ms.inject_pitch_costs(record.replay_pitch_costs())
	else:
		assert_true(record.replay_inject_content(ms), "the recorded content order replays")
	var p1 := ReplayController.new(record, 0)
	var p2 := ReplayController.new(record, 1)
	for _t in record.tick_count():
		var intents: Array[InputIntent] = [p1.sample(), p2.sample()]
		ms.advance(intents)
		ms.drain_signals()
	return ms


func _slot_of(player: PlayerState, id: StringName) -> int:
	var hand := player.hand.to_array()
	for index in hand.size():
		if not player.hand.is_slot_empty(index) and hand[index] == id:
			return index
	assert_true(false, "fixture: %s is in the dealt hand" % id)
	return -1


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


func _roll_intent() -> InputIntent:
	var i := _press(&"roll")
	i.move_dir = Vector2(1.0, 0.0)
	return i


func _press(action: StringName) -> InputIntent:
	var i := InputIntent.new()
	i.pressed[action] = true
	i.held[action] = true
	return i


func _held(action: StringName) -> InputIntent:
	var i := InputIntent.new()
	i.held[action] = true
	return i


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
