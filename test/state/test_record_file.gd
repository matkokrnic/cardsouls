extends TestCase

## Story 3-0d (AC 4 / AC 5 / AC 6): `user://` PERSISTENCE FOR A RECORD — save, load, and the one
## element of the on-disk shape this story pins.
##
## AC 4 is the `3-0c` AC 10 identity shape driven TWICE: once from the in-memory IntentRecorder
## and once from an IntentRecorder rebuilt by loading the saved file. Both replays must reach the
## same CanonicalHash as the run that produced them, so BREAKING THE ROUND TRIP — dropping a
## channel on the way to disk, or rebuilding it in the wrong order — is what makes this fail.
##
## AC 5 pins the ONE thing about the format that is pinned: a FORMAT VERSION int, with a record
## whose version does not match REFUSED and told why rather than replayed (`3-0d/R7`). Everything
## else about byte layout, key naming and extension stays deliberately unpinned.
##
## AC 6 proves recording is ALWAYS-ON and CUMULATIVE across a SAVE: save, keep driving, save
## again, and the second file carries N + M ticks starting at tick 1 — SAVE is a snapshot of the
## stream, never a stop or a restart.
##
## GOLDEN ISOLATION: the config, the composition and the costs are all built IN-TEST with opaque
## ids (the _golden_config / _golden_deck discipline), so this fixture cannot move the golden and
## a tuning pass cannot move this fixture.
##
## POST-REVIEW ADDITIONS (`3-0d/R15`, `3-0d/R16`, `3-0d/R17`):
##   * R15 — the REFUSAL PATHS the shipped class got wrong or never exercised: a versioned but
##     TRUNCATED file (which used to come back as a refusal with an EMPTY reason, read as success
##     by any caller testing `error != ""`), the no-version-key branch, and a derivation guard
##     asserting RecordFile.REQUIRED_KEYS is the key set the writer actually emits.
##   * R16 — a save path outside `user://` is refused and writes nothing.
##   * R17 — `_replay()` below no longer transcribes the replay drive order: it calls
##     `ReplayDrive.drive()`, SHARED WITH AC 8's headless verifier, so AC 4's hash equalities now
##     genuinely cover the verifier's ordering. They did not before.

const ROUND_TRIP_PATH := "user://test_3_0d_round_trip.rec"
const VERSION_PATH := "user://test_3_0d_version.rec"
const FIRST_SAVE_PATH := "user://test_3_0d_cumulative_1.rec"
const SECOND_SAVE_PATH := "user://test_3_0d_cumulative_2.rec"
const MALFORMED_PATH := "user://test_3_0d_malformed.rec"
## Story 4-3a: the FORMAT_VERSION / contact-row-shape pin writes its own file, so it cannot race
## the round-trip fixture's path.
const FORMAT_PIN_PATH := "user://test_4_3a_format_pin.rec"
## Story 4-4 (`4-4/R15`): the byte-identity re-save and the retired-version refusal each write
## their own file, for the same no-racing reason.
const RESAVE_PATH := "user://test_4_4_resave.rec"
const RETIRED_VERSION_PATH := "user://test_4_4_retired_version.rec"
## Story 6-2 (AC 16): the v8-refusal test writes its own file, for the same no-racing reason.
const PRE_6_2_PATH := "user://test_6_2_pre_pitch_costs.rec"
## Story 6-3a (AC 4): the v9-refusal test writes its own file, for the same no-racing reason.
const PRE_6_3A_PATH := "user://test_6_3a_pre_card_activate.rec"
## Story 6-7 (AC 15): the v10-refusal test writes its own file, for the same no-racing reason.
const PRE_6_7_PATH := "user://test_6_7_pre_run_gait.rec"

## Story 4-4: the in-test `unit_kinds` list the recorded config carries, and the nested values the
## round trip is measured on. Deliberately THREE LEVELS DEEP (kind -> attack -> projectile),
## because that is the depth `store_var` could not carry and the depth the fix has to reach.
const KIND_NAME := &"file_kind"
const KIND_MAX_HP := 17.0
const KIND_DAMAGE := 2.5
const KIND_RANGE := 6.5
const PROJECTILE_BUDGET := 44.0

const SEED := 5150

## The driven sequence. Every channel is exercised, so a channel lost in the file has somewhere
## to show: a reset, an attack that lands, a mid-run reload, a cast, and a non-identity basis.
const TICKS := 18
const RESET_TICK := 2        # intent-carried debug reset — rides the record as an ordinary tick
const ATTACK_TICK := 5       # windup 5-7, active 8-11 at this fixture's authored windows
const CONTACT_TICK := 9      # a fact inside that active window -> a CONFIRMED hit
const RELOAD_TICK := 12      # the live mid-run apply_balance: reload event #1
const CAST_TICK := 15
const CAST_SLOT := 1
## Story 6-2 (AC 16): a Mode ④ STAGE rides the driven run, so the pitch-cost channel is LOAD-BEARING in
## every round trip below rather than a key that is written and never read. Slot 0 on P1 (the cast took
## slot 1); the countdown is authored long enough that the card is still STAGED on the final tick, so
## the staged record itself reaches the hashed snapshot every hash equality here compares.
const STAGE_TICK := 17
const STAGE_SLOT := 0
const PITCH_MANA_COST := 3.0
const PITCH_TIMER_TICKS := 30
## Story 6-3a (AC 4): ONE tick carries a bare-Y ACTIVATION commit (`card_activate = true`), so the tenth
## intent field is non-default in the recorded stream. Deliberately BEFORE `STAGE_TICK`: P1's zone is
## empty then, so the activation is refused (`empty_pitch_zone`) and the driven run's end state -- the
## card still waiting at the final tick -- is exactly what it was before this story.
const ACTIVATE_TICK := 16

const DECK_IDS: Array[StringName] = [
	&"file_card_0", &"file_card_1", &"file_card_2", &"file_card_3", &"file_card_4", &"file_card_5",
]
const HAND_SIZE := 3
const CAST_MANA_COST := 5.0
const MELEE_HIT_MANA := 12.0
const MOVE_SPEED := 7.0
const RETUNED_MOVE_SPEED := 11.0
const CAMERA_YAW_DEGREES := 90.0

## Story 4-6 (AC 11/AC 14): the ONE tick that carries a retarget address, and the address it
## carries. Slot 1's board index 4 -- a UNIT address, deliberately NOT the `[1, -1]` hero one, so a
## rebuild that blanket-wrote the index half to the hero sentinel fails rather than coinciding.
const RETARGET_TICK := 2
const RETARGET_SLOT := 1
const RETARGET_INDEX := 4

## Story 6-8: the tick a recorded run UNLOCKS on, and the file it round-trips through.
const UNLOCK_TICK := 2
const UNLOCK_ROUND_TRIP_PATH := "user://test_6_8_unlock_round_trip.rec"

# Story 5-1a (AC 4/AC 5): the ticks the contents corruptions land on. Both are inside the driven
# run's `TICKS`, so the rebuild loop really does reach them — a tick past `tick_count` would make
# every refusal below unfalsifiable.
const LOCK_CORRUPT_TICK := 3
const INTENT_CORRUPT_TICK := 4
const INTENT_CORRUPT_SLOT := 0

## AC 6: ticks driven before the first SAVE, and after it before the second.
const TICKS_BEFORE_FIRST_SAVE := 6
const TICKS_BETWEEN_SAVES := 7


# ---------------------------------------------------------------- AC 4

## AC 4: A RECORD SAVED TO `user://` AND LOADED BACK REPLAYS TO THE SAME HASH. Three measurements,
## not two: the live run, the replay of the in-memory record, and the replay of the record rebuilt
## from the file. The third is this story's claim; the second is `3-0c`'s, re-measured here so a
## divergence can be attributed to the FILE rather than to replay in general.
func test_a_saved_and_reloaded_record_replays_to_the_same_canonical_hash() -> void:
	var driven := _record_a_driven_run()
	var live_hash := CanonicalHash.of((driven["state"] as MatchState).to_snapshot())
	var record: IntentRecorder = driven["record"]
	var in_memory_hash := CanonicalHash.of(_replay(record).to_snapshot())
	assert_eq(in_memory_hash, live_hash,
		"sanity (`3-0c` AC 10): the in-memory record replays to the run that produced it, so any "
		+ "divergence below belongs to the FILE")
	var loaded := _save_and_load(record, ROUND_TRIP_PATH)
	assert_eq(CanonicalHash.of(_replay(loaded).to_snapshot()), live_hash,
		"a record written to user:// and loaded back replays BIT-IDENTICALLY — the round trip "
		+ "carries every channel the replay reads")
	_remove(ROUND_TRIP_PATH)


## AC 4, the half that makes the hash equality mean something: the rebuilt record is EQUAL TO THE
## SOURCE CHANNEL BY CHANNEL, including all EIGHT InputIntent fields per tick per slot. A hash
## comparison alone could pass on a record that lost a channel the hashed final tick happens not
## to read; this cannot.
## Story 4-3a (AC 3 / `4-3a/R10`): THE VERSION BUMP AND THE SHAPE IT EXISTS FOR, PINNED TOGETHER.
##
## Before this test nothing whatever pinned `FORMAT_VERSION`. The constant could be edited back to 2
## and every test in this file would still pass -- so the bump was an unguarded claim. The halves
## here are deliberately in ONE test, because any of them alone is a failure mode:
##
##   * the VERSION reads its current value. Alone this is a tautology a dev pass could satisfy by
##     editing a number.
##   * a UNIT-ADDRESSED fact survives the round trip AS a unit-addressed fact. That is what the
##     `4-3a` bump was FOR: a v2 contact row carried four elements and no target index, and
##     rebuilding one by assuming -1 would replay a hit on a UNIT as a hit on that slot's HERO -- a
##     replay that silently diverges from the match it claims to reproduce, at the exact seam
##     `record_file`'s refusal-with-a-reason exists to protect.
##
## THE PAIR that makes that half non-vacuous is the hero-addressed fact recorded beside it: if the
## index half were being dropped or defaulted, BOTH rows would come back reading -1 and the unit
## row's assertion would fail while the hero row's still passed. Two addresses, one channel.
##
## STORY 4-3b (AC 3 + AC 13, `4-3b/R21`): 3 -> 4, AND TWO MORE HALVES ON THE SAME PATTERN, because
## this bump exists for two more row elements and each has its own silent-divergence failure:
##
##   * a UNIT-SOURCED fact survives as unit-SOURCED. The attacker widened to a `[slot, index]`
##     address, and rebuilding the index by assuming -1 would replay a MINION's swing as its OWNER
##     HERO's -- which under the ladder means the owner's dedupe, the owner's liveness, and mana for
##     the owner that a unit hit must never generate (AC 7).
##   * a REACH PROBE survives as a PROBE. Rebuilding the kind marker by assuming STRIKE would replay
##     a harmless reach probe as a landed hit and DEAL DAMAGE on replay that the live match never
##     dealt.
##
## Each is paired against a row that must read the other value, for the reason the target half is:
## a blanket-written column passes a single-row assertion and fails a paired one.
func test_the_format_version_and_the_widened_contact_row_move_together() -> void:
	assert_eq(RecordFile.FORMAT_VERSION, 11,
		"FORMAT_VERSION is 11 as of story 6-7 (AC 15) -- a SILENT-DIVERGENCE bump on the `6-1` "
		+ "reasoning, not an intent-shape one: a v10 record carries no `run` held key and no "
		+ "`walk_speed` value, and would replay every hero at speed 0 from the tick gait selection "
		+ "lands (pinned by test_a_v10_record_is_refused_with_a_reason). "
		+ "It was 10 as of story 6-3a (AC 4) -- an INTENT SHAPE change, the tenth InputIntent "
		+ "field `card_activate`, which no v9 record carries (pinned by "
		+ "test_a_v9_record_without_card_activate_is_refused_with_a_reason). "
		+ "It was 9 as of story 6-2 (AC 16) -- a NEW CAPTURE CHANNEL, the fifth content "
		+ "channel `pitch_costs`, which a v8 record does not carry, so every staging it recorded would "
		+ "refuse on replay (pinned by test_a_v8_record_without_pitch_costs_is_refused_with_a_reason). "
		+ "It was 8 as of story 6-1 (`6-1/R4`), and that bump is a pure SEMANTICS bump -- "
		+ "the first one in this file's history that the SHAPE did not force. Mode ②'s new "
		+ "hold-through-chargeup reads a `card_cast` held key, and `held` is serialized "
		+ "generically by key at both ends, so the channel round-trips with zero serialization "
		+ "edits and the round-trip half of the measurement says 'no bump needed'. The bump is for "
		+ "what a round-trip inside one build cannot see: a v7 recording of a mode ② cast carries "
		+ "no such key, so the chargeup that LANDED when it was recorded now replays as an instant "
		+ "paid feint -- loaded without complaint, because the version is all the loader checks. "
		+ "It was 7 as of story 5-2 -- the FOURTH content channel (`inject_card_colors`, "
		+ "`5-2/R1`) joined the file and a v6 record carries no colours at all, so every "
		+ "unblockable telegraph would replay in the wrong colour and diverge on the hashed "
		+ "per-player `telegraph` key. 5-2's OTHER half forced nothing: its two new CHARGE-REACH "
		+ "contact kinds are new VALUES of the existing `kind` element, so the row is still SEVEN "
		+ "elements and the assertions below still pin it. It was 6 as of story 4-6 (AC 14) -- the "
		+ "intent shape changed (`aim` deleted, "
		+ "`retarget_slot`/`retarget_index` added) and a new per-tick `lock_pushes` channel joined "
		+ "the file, none of which a v5 record carries (it was 5 through 4-4, 4 through 4-3b, 3 "
		+ "through 4-3a, 2 through 4-1). The contact row's SHAPE is unchanged at seven elements, "
		+ "and the assertions below still pin it: the row and the version stopped moving together "
		+ "at 4-4's bump, so the row needs its own guard")
	var driven := _match_start()
	var record: IntentRecorder = driven["record"]
	var ms: MatchState = driven["state"]
	# THREE rows on the SAME tick, chosen so every widened column is pinned against a row
	# carrying the OTHER value -- a blanket-written column cannot pass all three:
	#   [0] hero attacker  -> UNIT target,  STRIKE
	#   [1] hero attacker  -> HERO target,  STRIKE
	#   [2] UNIT attacker  -> HERO target,  REACH PROBE
	# Both the tap and the seam receive each, in the paired order the runner uses.
	record.capture_push_contact([0, -1], [1, 2], 0, Vector2(-1, 0), MatchState.CONTACT_STRIKE)
	ms.push_contact([0, -1], [1, 2], 0, Vector2(-1, 0), MatchState.CONTACT_STRIKE)
	record.capture_push_contact([0, -1], [1, -1], 0, Vector2(-1, 0), MatchState.CONTACT_STRIKE)
	ms.push_contact([0, -1], [1, -1], 0, Vector2(-1, 0), MatchState.CONTACT_STRIKE)
	record.capture_push_contact([0, 3], [1, -1], 1, Vector2(-1, 0),
			MatchState.CONTACT_REACH_PROBE)
	ms.push_contact([0, 3], [1, -1], 1, Vector2(-1, 0), MatchState.CONTACT_REACH_PROBE)
	_tick(driven, _intents(1))
	var error := RecordFile.save_record(record, FORMAT_PIN_PATH)
	assert_eq(error, "", "the record saved: %s" % error)
	var loaded := RecordFile.load_record(FORMAT_PIN_PATH)
	var rebuilt: IntentRecorder = loaded["record"]
	assert_not_null(rebuilt, "the record loaded back (error: %s)" % loaded["error"])
	if rebuilt == null:
		_remove(FORMAT_PIN_PATH)
		return
	var facts := rebuilt.contacts_at(1)
	assert_eq(facts.size(), 3, "all three contact rows survived the round trip")
	if facts.size() == 3:
		assert_eq((facts[0] as Array).size(), 7,
			"a contact row is SEVEN positional elements now: attacker slot, attacker INDEX, target "
			+ "slot, target INDEX, attack index, direction, KIND (it was five through "
			+ "FORMAT_VERSION 3 and four through 2)")
		# --- the 4-3a half: the TARGET index, paired.
		assert_eq(int(facts[0][3]), 2,
			"the UNIT-addressed fact came back addressed to board index 2 -- NOT defaulted to -1, "
			+ "which would replay a hit on a unit as a hit on that slot's hero")
		assert_eq(int(facts[1][3]), -1,
			"...and the HERO-addressed fact beside it still reads -1, so the index half is being "
			+ "carried rather than blanket-written")
		# --- the 4-3b half (AC 3): the ATTACKER index, paired the same way.
		assert_eq(int(facts[2][1]), 3,
			"the UNIT-SOURCED fact came back sourced from board index 3 -- NOT defaulted to -1, "
			+ "which would replay a minion's swing as its owner HERO's: the owner's dedupe, the "
			+ "owner's liveness, and mana a unit hit must never generate")
		assert_eq(int(facts[1][1]), -1,
			"...and the HERO-sourced fact beside it still reads -1, so the attacker index is "
			+ "carried rather than blanket-written")
		# --- the 4-3b half (AC 13): the KIND marker, paired the same way.
		assert_eq(int(facts[2][6]), MatchState.CONTACT_REACH_PROBE,
			"the REACH PROBE came back a PROBE -- NOT defaulted to STRIKE, which would replay a "
			+ "harmless reach observation as a landed hit and deal damage the live match never did")
		assert_eq(int(facts[1][6]), MatchState.CONTACT_STRIKE,
			"...and the STRIKE beside it still reads STRIKE, so the kind column is carried rather "
			+ "than blanket-written")
	_remove(FORMAT_PIN_PATH)

func test_the_round_trip_carries_every_channel_verbatim() -> void:
	var driven := _record_a_driven_run()
	var live: MatchState = driven["state"]
	var record: IntentRecorder = driven["record"]
	# NON-VACUITY: the recorded run really did exercise the channels this test then compares.
	assert_eq(record.reload_event_count(), 2, "match start plus the ONE mid-run reload")
	assert_eq(record.contacts_at(CONTACT_TICK).size(), 1, "the contact channel carries the fact")
	assert_true(live.p2.hero.get_hp() < live.p2.hero.get_max_hp(),
		"...and it was CONFIRMED: P2 took damage, so the channel is load-bearing here")
	assert_true(live.p1.mana.get_current() > 0.0, "the flags channel is load-bearing (melee mana)")
	assert_eq(live.p1.discard.size(), 1, "the cast landed, so the cost map is load-bearing")
	assert_true(live.pitch.is_staged(0),
		"the stage landed and is still waiting, so the pitch-cost channel is load-bearing (story 6-2)")

	var loaded := _save_and_load(record, ROUND_TRIP_PATH)
	assert_eq(loaded.tick_count(), record.tick_count(), "every tick survived the file")
	assert_eq(loaded.replay_seed(), record.replay_seed(), "the seed channel survived")
	assert_eq(loaded.content_order(), record.content_order(), "the content ORDER survived")
	assert_eq(loaded.replay_deck_contents(), record.replay_deck_contents(), "the composition survived")
	assert_eq(loaded.replay_card_costs().keys(), record.replay_card_costs().keys(),
		"the cost map's ids survived")
	assert_eq(loaded.replay_card_costs()[DECK_IDS[0]].mana_cost, CAST_MANA_COST,
		"...and their VALUES, rebuilt as fresh CardCastConditions")
	# Story 6-2 (AC 16): the FIFTH content channel, on the cost map's footing -- ids, mana AND the typed
	# orb price, which is the half `_rebuilt`'s dictionary `assign` exists for.
	assert_eq(loaded.replay_pitch_costs().keys(), record.replay_pitch_costs().keys(),
		"the pitch-cost map's ids survived")
	assert_eq(loaded.replay_pitch_costs()[DECK_IDS[0]].mana_cost, PITCH_MANA_COST,
		"...their mana price")
	assert_eq(loaded.replay_pitch_costs()[DECK_IDS[0]].orb_costs, {Enums.CardColor.BLUE: 2},
		"...and their ORB price, rebuilt into the typed dictionary rather than dropped")
	# Story 4-1 (`4-1/R1`): the THIRD content channel, on the cost map's own footing -- "carries
	# EVERY channel" is this test's name, so a channel added to the writer is added here.
	assert_eq(loaded.replay_card_effects().keys(), record.replay_card_effects().keys(),
		"the effect map's ids survived")
	assert_eq(String(loaded.replay_card_effects()[DECK_IDS[0]].effect_id),
		"summon_%s" % DECK_IDS[0],
		"...and their VALUES, rebuilt as fresh CardEffects")
	assert_eq(loaded.replay_feature_flags().melee_mana_generation,
		record.replay_feature_flags().melee_mana_generation, "the flags channel survived")
	assert_eq(loaded.reload_event_count(), record.reload_event_count(), "both reload events survived")
	for index in record.reload_event_count():
		assert_eq(loaded.reload_event_tick(index), record.reload_event_tick(index),
			"reload event %d kept its TICK — the rebuild re-captures it at the same point in the "
					% index + "stream, which is the only way capture_apply_balance can stamp it")
		assert_eq(loaded.replay_balance_config(index).move_speed,
			record.replay_balance_config(index).move_speed, "...and its values")
		# Story 4-4 (`4-4/R15`): ...INCLUDING THE NESTED HALF, which is the whole reason the bump
		# exists. `move_speed` above is a float, and a float survived every shape this class ever
		# had; `unit_kinds` is an `Array[UnitKindProfile]` whose contents were being handed to
		# `store_var` as live references and coming back as an EMPTY ARRAY with nothing printed.
		# Asserted at all THREE levels, because each is a separate recursion the fix has to make.
		var config := loaded.replay_balance_config(index)
		assert_eq(config.unit_kinds.size(), 1,
			"reload event %d's config came back WITH its kind list — a size of 0 here is the "
					% index + "silent total loss `4-4/R15` bumped the format for")
		if config.unit_kinds.size() == 1:
			var kind := config.kind_at(0)
			assert_eq(String(kind.kind_name), String(KIND_NAME),
				"...level 1: the kind's own StringName, which `kind_index_of` addresses it by")
			assert_eq(kind.max_hp, KIND_MAX_HP, "...level 1: and its hp")
			assert_eq(kind.attacks.size(), 1, "...level 2: its attack list is a nested array")
			if kind.attacks.size() == 1:
				assert_eq(kind.attacks[0].damage, KIND_DAMAGE, "...level 2: and the attack's damage")
				assert_eq(kind.attacks[0].range, KIND_RANGE, "...level 2: and its range")
				assert_not_null(kind.attacks[0].projectile,
					"...level 3: the attack's projectile is a nested resource, not a lost null")
				if kind.attacks[0].projectile != null:
					assert_eq(kind.attacks[0].projectile.travel_budget, PROJECTILE_BUDGET,
						"...level 3: and the projectile's own authored budget")
			assert_eq(config.kind_index_of(KIND_NAME), 0,
				"...and the rebuilt list ANSWERS the lookup every summon goes through — "
				+ "NO_KIND_INDEX here is a replay in which nothing has a kind")
		assert_ne(config.kind_at(0), record.replay_balance_config(index).kind_at(0),
			"...and the rebuilt kind is a FRESH object, not the live authored one handed back: a "
			+ "record on disk carries numbers, never a path to a resource that can be re-tuned "
			+ "under it (the by-value discipline, now recursive)")
	var fields := 0
	for tick in range(1, record.tick_count() + 1):
		assert_eq(loaded.camera_pushes_at(tick), record.camera_pushes_at(tick),
			"tick %d's camera bases survived, in push order" % tick)
		assert_eq(loaded.contacts_at(tick), record.contacts_at(tick),
			"tick %d's contact facts survived, in push order" % tick)
		for slot in 2:
			var got := loaded.replay_intent(tick, slot)
			var want := record.replay_intent(tick, slot)
			assert_eq(got.move_dir, want.move_dir, "t%d s%d move_dir" % [tick, slot])
			assert_eq(got.pressed, want.pressed, "t%d s%d pressed" % [tick, slot])
			assert_eq(got.held, want.held, "t%d s%d held" % [tick, slot])
			assert_eq(got.debug_reset, want.debug_reset, "t%d s%d debug_reset" % [tick, slot])
			assert_eq(got.card_slot, want.card_slot, "t%d s%d card_slot" % [tick, slot])
			assert_eq(int(got.card_mode), int(want.card_mode), "t%d s%d card_mode" % [tick, slot])
			assert_eq(got.card_commit, want.card_commit, "t%d s%d card_commit" % [tick, slot])
			# Story 6-3a (AC 4): the TENTH field, and the count moves NINE -> TEN with FORMAT_VERSION 10.
			assert_eq(got.card_activate, want.card_activate, "t%d s%d card_activate" % [tick, slot])
			# Story 4-6 (AC 8/AC 11): `aim` is GONE from the intent and the two retarget-address
			# fields replace it -- so the per-field count moves EIGHT -> NINE with the format
			# bump, and this loop is where a field that silently stopped surviving a save fails.
			assert_eq(got.retarget_slot, want.retarget_slot, "t%d s%d retarget_slot" % [tick, slot])
			assert_eq(got.retarget_index, want.retarget_index, "t%d s%d retarget_index" % [tick, slot])
			fields += 10
	assert_eq(fields, TICKS * 2 * 10,
		"all ten intent fields were compared for both slots on every tick (got %d)" % fields)
	# ...and the driven values really were non-default, or the comparison above proves nothing.
	var loud := loaded.replay_intent(CAST_TICK, 0)
	assert_eq(loud.card_slot, CAST_SLOT, "the cast tick's card fields came back non-default")
	assert_true(loud.card_commit, "...including the commit edge")
	assert_true(loaded.replay_intent(ATTACK_TICK, 0).is_held(&"attack"), "held came back non-empty")
	assert_true(loaded.replay_intent(RESET_TICK, 0).debug_reset, "debug_reset came back set")
	var retargeted := loaded.replay_intent(RETARGET_TICK, 0)
	assert_eq(retargeted.retarget_slot, RETARGET_SLOT, "the retarget address came back non-default")
	assert_eq(retargeted.retarget_index, RETARGET_INDEX, "...both halves of it")
	assert_true(loaded.replay_intent(ACTIVATE_TICK, 0).card_activate,
		"card_activate came back SET on the activation tick, so its comparison above is load-bearing")
	_remove(ROUND_TRIP_PATH)


## Story 4-4 (`4-4/R15`): THE ROUND TRIP AS BYTE IDENTITY, which is the assertion the field-by-field
## test above could not make and the one the `unit_kinds` loss walked straight through.
##
## The test above names the channels it compares, and that naming is exactly its weakness: a field
## nobody thought to add is a field nobody compares. `unit_kinds` was the largest thing ever added
## to the recorded config and the test's own comment ("a channel added to the writer is added here")
## was not honoured — one float, `move_speed`, stood in for the whole config.
##
## SAVE -> LOAD -> SAVE AGAIN, AND COMPARE THE TWO FILES BYTE FOR BYTE. Nothing is named, so nothing
## can be forgotten: any value the writer emits and the rebuild drops changes the second file. The
## comparison is sound in both directions because `store_var` is deterministic over the same
## Dictionary and both files are written by the same function on the same build.
##
## NON-VACUITY IS ASSERTED, not assumed: the reloaded record is checked to CARRY the three-level
## kind list, because two files that both lost it would be byte-identical too.
func test_a_saved_record_reloads_and_re_saves_to_the_identical_BYTES() -> void:
	var record: IntentRecorder = _record_a_driven_run()["record"]
	assert_eq(RecordFile.save_record(record, ROUND_TRIP_PATH), "", "the first file was written")
	var reloaded := _loaded(ROUND_TRIP_PATH)
	assert_eq(RecordFile.save_record(reloaded, RESAVE_PATH), "",
		"the RELOADED record saved again — a record rebuilt from disk is a record")
	var first := _bytes(ROUND_TRIP_PATH)
	var second := _bytes(RESAVE_PATH)
	assert_eq(second.size(), first.size(),
		"the re-saved file is the same LENGTH (%d vs %d) — a dropped channel is shorter"
				% [second.size(), first.size()])
	assert_true(first == second,
		"...and the same BYTES: everything the writer emits survived load and came back out "
		+ "identical, named or not")
	# NON-VACUITY: the bytes being compared actually carry the nested list.
	assert_true(first.size() > 0, "sanity: the file is not empty")
	assert_eq(reloaded.replay_balance_config(0).unit_kinds.size(), 1,
		"...and the record whose bytes those are really does carry a kind list, so the identity "
		+ "above is a statement about the nested half and not about two empty configs")
	assert_not_null(reloaded.replay_balance_config(0).kind_at(0).attacks[0].projectile,
		"...three levels deep, so the identity covers the whole recursion")
	_remove(ROUND_TRIP_PATH)
	_remove(RESAVE_PATH)


## Story 4-4 (`4-4/R15`): the OTHER half of the bump, and the half a bump exists for. A v4 record
## predates `unit_kinds` entirely — it carries the retired flat keys and nothing this build can
## build a kind list from — so replaying one would put every summoned unit on the board with no
## speed, no hp, no damage, no attack and no priority. It is REFUSED with a reason naming both
## versions, never accepted and quietly diverged from.
##
## Written as a real v4-shaped file rather than a version-field edit alone: the config values it
## carries are stripped back to the pre-4-4 key set, so the refusal is measured against a body a
## v4 build would actually have written and not just against a relabelled v5 body.
func test_a_record_from_the_version_before_unit_kinds_is_refused_with_a_reason() -> void:
	var record: IntentRecorder = _record_a_driven_run()["record"]
	assert_eq(RecordFile.save_record(record, RETIRED_VERSION_PATH), "", "the record was written")
	_rewrite_as_pre_4_4(RETIRED_VERSION_PATH)
	var refused := RecordFile.load_record(RETIRED_VERSION_PATH)
	assert_null(refused["record"],
		"a v4 record is REFUSED — it carries no `unit_kinds`, and replaying it would put every "
		+ "summoned unit on the board kindless: no hp, no speed, no damage, no attack")
	assert_ne(refused["error"], "",
		"...with a REASON, never the empty-error refusal a caller reads as success")
	assert_true(refused["error"].contains("4"),
		"...naming the version found: %s" % refused["error"])
	assert_true(refused["error"].contains(str(RecordFile.FORMAT_VERSION)),
		"...and the version this build speaks: %s" % refused["error"])
	# The refusal is about the VERSION, not about the stripping: a CURRENT-version file of the same
	# shape loads. Story 4-6 reads the constant here rather than a literal, because the literal was
	# the version this build spoke at the time and that is what makes it drift silently.
	assert_eq(RecordFile.save_record(record, RETIRED_VERSION_PATH), "",
		"rewritten at the current version")
	assert_not_null(RecordFile.load_record(RETIRED_VERSION_PATH)["record"],
		"the same record at the CURRENT version loads, so the refusal above was the version")
	_remove(RETIRED_VERSION_PATH)


# ---------------------------------------------------------------- AC 5

## AC 5: THE FORMAT VERSION, falsifiable in BOTH directions. A record written by this build loads;
## the SAME file with only its version field rewritten is REFUSED, with a reason that names both
## versions rather than failing silently or replaying a shape it cannot know.
func test_a_record_whose_format_version_is_unknown_is_refused_with_a_reason() -> void:
	var record: IntentRecorder = _record_a_driven_run()["record"]
	assert_eq(RecordFile.save_record(record, VERSION_PATH), "", "the record was written")
	var matching := RecordFile.load_record(VERSION_PATH)
	assert_not_null(matching["record"], "a MATCHING version loads")
	assert_eq(matching["error"], "", "...with no error")
	assert_eq((matching["record"] as IntentRecorder).tick_count(), TICKS, "...and is the real record")

	# Rewrite ONLY the version field, leaving every other byte of meaning intact.
	var unknown := RecordFile.FORMAT_VERSION + 41
	_rewrite_format_version(VERSION_PATH, unknown)
	var refused := RecordFile.load_record(VERSION_PATH)
	assert_null(refused["record"],
		"a record whose format version is unknown is REFUSED — never replayed on a guess")
	assert_true(refused["error"].contains(str(unknown)),
		"...and the reason names the version found: %s" % refused["error"])
	assert_true(refused["error"].contains(str(RecordFile.FORMAT_VERSION)),
		"...and the version this build speaks: %s" % refused["error"])
	# The refusal is about the VERSION and nothing else: put it back and the same bytes load.
	_rewrite_format_version(VERSION_PATH, RecordFile.FORMAT_VERSION)
	assert_not_null(RecordFile.load_record(VERSION_PATH)["record"],
		"restoring the version makes the SAME file load again — the refusal was the version, not "
		+ "damage done by rewriting it")
	_remove(VERSION_PATH)


## Story 6-2 (AC 16): A v8 RECORD IS REFUSED WITH A REASON, NO SHIM -- the `4-4` pre-bump refusal's shape
## (`test_a_record_from_the_version_before_unit_kinds_is_refused_with_a_reason`), applied to this bump.
## The body is rewritten to what a v8 build actually wrote -- no `pitch_costs` key, no pitch channel in
## the content order -- so the refusal is measured against a real v8 body and not a relabelled v9 one.
##
## WHY REFUSED RATHER THAN MIGRATED: a v8 record has no pitch costs, so every stage it recorded would
## refuse on replay (`no_pitch_cost`) -- no mana spent, nothing in the zone -- and the replay would
## diverge on the hashed `"pitch"` key while loading without complaint. An unloadable record is a correct
## answer; a divergent one is not (the `6-1/R4` reasoning).
func test_a_v8_record_without_pitch_costs_is_refused_with_a_reason() -> void:
	var record: IntentRecorder = _record_a_driven_run()["record"]
	assert_eq(RecordFile.save_record(record, PRE_6_2_PATH), "", "the record was written")
	_rewrite_as_pre_6_2(PRE_6_2_PATH)
	var refused := RecordFile.load_record(PRE_6_2_PATH)
	assert_null(refused["record"],
		"a v8 record is REFUSED -- it carries no pitch costs, so its stagings would refuse on replay")
	assert_ne(refused["error"], "", "...with a REASON, never the empty-error refusal read as success")
	assert_true(refused["error"].contains("8"), "...naming the version found: %s" % refused["error"])
	assert_true(refused["error"].contains(str(RecordFile.FORMAT_VERSION)),
		"...and the version this build speaks: %s" % refused["error"])
	# The refusal is the VERSION: the same stripped body relabelled at the current version is refused
	# for its MISSING KEY instead, naming `pitch_costs` -- a v9 file cannot omit the channel either.
	_rewrite_format_version(PRE_6_2_PATH, RecordFile.FORMAT_VERSION)
	var truncated := RecordFile.load_record(PRE_6_2_PATH)
	assert_null(truncated["record"], "a current-version body without pitch_costs is refused too")
	assert_true(truncated["error"].contains("pitch_costs"),
		"...and that refusal names the missing key: %s" % truncated["error"])
	# ...and the intact record at the current version loads, so neither refusal was file damage.
	assert_eq(RecordFile.save_record(record, PRE_6_2_PATH), "", "rewritten intact")
	assert_not_null(RecordFile.load_record(PRE_6_2_PATH)["record"],
		"the intact record at the CURRENT version loads")
	_remove(PRE_6_2_PATH)


## Story 6-3a (AC 4): A v9 RECORD IS REFUSED WITH A REASON, NO SHIM -- the v8 refusal's shape directly
## above, applied to this bump. The body is rewritten to what a v9 build actually wrote -- NO
## `card_activate` key in ANY per-tick intent, version 9 -- so the refusal is measured against a real v9
## body and not a relabelled v10 one.
##
## THE SECOND HALF IS THE ONE THAT MATTERS: the SAME stripped body relabelled at v10 is refused again, for
## the missing per-intent field BY NAME. That is `REQUIRED_INTENT_FIELDS` doing its job -- without the
## `card_activate` entry the rebuild would reach `values["card_activate"]` on a key that is not there.
func test_a_v9_record_without_card_activate_is_refused_with_a_reason() -> void:
	var record: IntentRecorder = _record_a_driven_run()["record"]
	assert_eq(RecordFile.save_record(record, PRE_6_3A_PATH), "", "the record was written")
	_rewrite_as_pre_6_3a(PRE_6_3A_PATH)
	var refused := RecordFile.load_record(PRE_6_3A_PATH)
	assert_null(refused["record"],
		"a v9 record is REFUSED -- no intent in it carries card_activate")
	assert_ne(refused["error"], "", "...with a REASON, never the empty-error refusal read as success")
	assert_true(refused["error"].contains("9"), "...naming the version found: %s" % refused["error"])
	assert_true(refused["error"].contains(str(RecordFile.FORMAT_VERSION)),
		"...and the version this build speaks: %s" % refused["error"])
	_rewrite_format_version(PRE_6_3A_PATH, RecordFile.FORMAT_VERSION)
	var truncated := RecordFile.load_record(PRE_6_3A_PATH)
	assert_null(truncated["record"], "a current-version body with no card_activate is refused too")
	assert_true(truncated["error"].contains("card_activate"),
		"...and that refusal names the missing field: %s" % truncated["error"])
	assert_true(truncated["error"].contains("tick 1"),
		"...at the first tick that lacks it: %s" % truncated["error"])
	# ...and the intact record at the current version loads, so neither refusal was file damage.
	assert_eq(RecordFile.save_record(record, PRE_6_3A_PATH), "", "rewritten intact")
	assert_not_null(RecordFile.load_record(PRE_6_3A_PATH)["record"],
		"the intact record at the CURRENT version loads")
	_remove(PRE_6_3A_PATH)


## Story 6-7 (AC 15): A v10 RECORD IS REFUSED WITH A REASON, NO SHIM -- but on the SIMPLER
## `test_a_record_whose_format_version_is_unknown_is_refused_with_a_reason` shape (only the
## version FIELD is rewritten, the body left otherwise intact), not the v8/v9 stripped-content
## shape, because the round-trip SHAPE forces no bump here (`&"run"` walks the existing `held`
## dictionary like every prior held key, `6-7/R12`) -- there is no per-field strip to rehearse.
##
## THIS PROVES ONLY THE VERSION-REFUSAL HALF (AC 15's correction), DELIBERATELY: a relabelled-at-
## v11 body missing `run`/`walk_speed` loads WITHOUT complaint today -- `REQUIRED_INTENT_FIELDS`
## was never asked to cover `run` (a `held` dictionary key, round-tripped as a whole dictionary) or
## `walk_speed` (a config value `_rebuilt` sets only if present) -- so this test does not, and must
## not, also assert a field-strip refusal the way the v8/v9 tests above do.
func test_a_v10_record_is_refused_with_a_reason() -> void:
	var record: IntentRecorder = _record_a_driven_run()["record"]
	assert_eq(RecordFile.save_record(record, PRE_6_7_PATH), "", "the record was written")
	_rewrite_format_version(PRE_6_7_PATH, 10)
	var refused := RecordFile.load_record(PRE_6_7_PATH)
	assert_null(refused["record"],
		"a v10 record is REFUSED -- it carries no `run` held key and no `walk_speed` value, and "
		+ "would replay every hero at speed 0 from the tick gait selection lands")
	assert_true(refused["error"].contains("10"), "...naming the version found: %s" % refused["error"])
	assert_true(refused["error"].contains(str(RecordFile.FORMAT_VERSION)),
		"...and the version this build speaks: %s" % refused["error"])
	# The refusal is about the VERSION and nothing else: put it back and the same bytes load.
	_rewrite_format_version(PRE_6_7_PATH, RecordFile.FORMAT_VERSION)
	assert_not_null(RecordFile.load_record(PRE_6_7_PATH)["record"],
		"restoring the version makes the SAME file load again — the refusal was the version, not "
		+ "damage done by rewriting it")
	_remove(PRE_6_7_PATH)


## AC 5's neighbours: a file that is not a record at all is refused the same way, and a record
## that never completed match start is refused AT THE WRITE, so a malformed file cannot exist to
## be loaded later. Both are reasons, never crashes — a save is an operator action.
func test_a_non_record_file_and_a_malformed_record_are_both_refused_with_reasons() -> void:
	var missing := RecordFile.load_record("user://test_3_0d_does_not_exist.rec")
	assert_null(missing["record"], "a path with no file is refused")
	assert_true(missing["error"].length() > 0, "...with a reason: %s" % missing["error"])
	var file := FileAccess.open(MALFORMED_PATH, FileAccess.WRITE)
	file.store_var([1, 2, 3])
	file.close()
	var wrong_shape := RecordFile.load_record(MALFORMED_PATH)
	assert_null(wrong_shape["record"], "a file that is not a record Dictionary is refused")
	assert_true(wrong_shape["error"].contains("record"), "...with a reason: %s" % wrong_shape["error"])
	_remove(MALFORMED_PATH)
	# A recorder with no match start is refused at the WRITE, naming the missing channels.
	var empty := IntentRecorder.new()
	var error := RecordFile.save_record(empty, MALFORMED_PATH)
	assert_ne(error, "", "an incomplete record is refused rather than written")
	assert_true(error.contains("seed"), "...and the reason names what is missing: %s" % error)
	assert_false(FileAccess.file_exists(MALFORMED_PATH), "...and nothing was written to disk")
	assert_ne(RecordFile.save_record(null, MALFORMED_PATH), "",
		"a null record is refused with a reason too, not a crash")


## AC 5 / `3-0d/R15`: A VERSIONED BUT TRUNCATED RECORD IS REFUSED WITH A REASON NAMING WHAT IS
## MISSING. The review found this path returning `{"record": null, "error": ""}` — a refusal with
## NO reason, which contradicts this class's own documented contract and which a caller testing
## `error != ""` reads as SUCCESS. The keys are validated BEFORE the rebuild now, so the failure
## can never again be "whatever the rebuild happened to die on".
func test_a_versioned_but_truncated_record_is_refused_with_a_reason_naming_the_missing_keys() -> void:
	var record: IntentRecorder = _record_a_driven_run()["record"]
	assert_eq(RecordFile.save_record(record, VERSION_PATH), "", "the intact record was written")
	assert_not_null(RecordFile.load_record(VERSION_PATH)["record"], "...and loads intact")
	# Drop two keys the rebuild reads, leaving the version — and everything else — untouched.
	_rewrite_without(VERSION_PATH, ["intents", "camera_pushes"])
	var refused := RecordFile.load_record(VERSION_PATH)
	assert_null(refused["record"], "a truncated record is REFUSED, never half-rebuilt")
	assert_ne(refused["error"], "",
		"...WITH A REASON — the empty-error refusal the review found reads as SUCCESS to any "
		+ "caller testing `error != \"\"`")
	assert_true(refused["error"].contains("intents"),
		"...and the reason NAMES the missing key: %s" % refused["error"])
	assert_true(refused["error"].contains("camera_pushes"),
		"...every missing key, not just the first: %s" % refused["error"])
	assert_false(refused["error"].contains("seed"),
		"...and names ONLY what is missing — `seed` is still there: %s" % refused["error"])
	_remove(VERSION_PATH)


## AC 5 / `3-0d/R15`: THE NO-VERSION-KEY BRANCH, previously shipped untested. A Dictionary that is
## not a record at all — the shape a foreign `store_var` file or a pre-versioning record takes —
## is refused for the reason it is refused for, not for the first key that happens to be missing.
func test_a_dictionary_with_no_version_key_at_all_is_refused_with_a_reason() -> void:
	var file := FileAccess.open(MALFORMED_PATH, FileAccess.WRITE)
	file.store_var({"seed": SEED, "tick_count": 3})
	file.close()
	var refused := RecordFile.load_record(MALFORMED_PATH)
	assert_null(refused["record"], "a Dictionary carrying no format version is refused")
	assert_true(refused["error"].contains("format version"),
		"...for THAT reason, named: %s" % refused["error"])
	assert_true(refused["error"].contains(MALFORMED_PATH),
		"...and the reason names the file: %s" % refused["error"])
	_remove(MALFORMED_PATH)


## `3-0d/R16`: A SAVE PATH OUTSIDE `user://` IS REFUSED. The class asserts in its own docstring
## and in AC 7 that records go under `user://`; before this guard that was true of `path_for()`
## and of nothing else, and the review proved it by writing a record into the repo root. The API
## carries the claim now, so a future caller that builds its own path cannot quietly break it.
func test_a_save_to_a_path_outside_user_is_refused_and_writes_nothing() -> void:
	var record: IntentRecorder = _record_a_driven_run()["record"]
	for outside: String in ["res://test_3_0d_escape.rec", "test_3_0d_escape.rec",
			"C:/test_3_0d_escape.rec", "user_data/test_3_0d_escape.rec"]:
		var error := RecordFile.save_record(record, outside)
		assert_ne(error, "", "saving to `%s` is REFUSED — records go under user://" % outside)
		assert_true(error.contains("user://"), "...with a reason naming where they go: %s" % error)
		assert_false(FileAccess.file_exists(outside), "...and nothing was written to `%s`" % outside)
	# ...and the guard is about the PREFIX and nothing else: a user:// path still writes.
	assert_eq(RecordFile.save_record(record, VERSION_PATH), "",
		"a user:// path is unaffected — the refusal is the prefix, not a new blanket veto")
	assert_true(FileAccess.file_exists(VERSION_PATH), "...and the file really is there")
	assert_true(RecordFile.path_for(1).begins_with("user://"),
		"path_for() satisfies the guard it was the only thing carrying before (`3-0d/R16`)")
	_remove(VERSION_PATH)


## `3-0d/R15`, the derivation guard: REQUIRED_KEYS IS THE KEY SET THE WRITER ACTUALLY WRITES, not
## a transcription of it. A channel added to `_to_dictionary` without being added here would leave
## the truncation check silently blind to that channel; this fails the moment the two diverge.
##
## `3-0d/R21`: REQUIRED_KEYS is now a key -> TYPE map, so the guard derives BOTH halves from the
## same written file — the key set, and each key's actual type. A channel added to the writer with
## a type the loader does not expect fails here rather than at some caller's expense.
func test_the_required_key_set_is_exactly_what_a_saved_record_carries() -> void:
	var record: IntentRecorder = _record_a_driven_run()["record"]
	assert_eq(RecordFile.save_record(record, VERSION_PATH), "", "the record was written")
	var reader := FileAccess.open(VERSION_PATH, FileAccess.READ)
	var written: Dictionary = reader.get_var()
	reader.close()
	var keys: Array = written.keys()
	keys.erase("format_version")  # validated first and on its own — see RecordFile.REQUIRED_KEYS
	keys.sort()
	var required: Array = RecordFile.REQUIRED_KEYS.keys()
	required.sort()
	assert_eq(keys, required,
		"every key the writer emits (besides the version) is a key the loader REQUIRES, and vice "
		+ "versa — written %s, required %s" % [str(keys), str(required)])
	assert_true(keys.size() > 5, "...and the comparison is against a real key set (%d)" % keys.size())
	# `3-0d/R21`: the DECLARED type of each key is the type the writer really emits, so the type
	# check the loader runs is derived from shipped behaviour rather than guessed at.
	for key: String in RecordFile.REQUIRED_KEYS:
		assert_eq(typeof(written[key]), RecordFile.REQUIRED_KEYS[key],
			"`%s` is written as %s, the type the loader requires" % [
					key, type_string(RecordFile.REQUIRED_KEYS[key])])
	_remove(VERSION_PATH)


## `3-0d/R21`: PRESENCE IS NOT TYPE, AND `has()` IS TRUE FOR `null`. `3-0d/R15` validated that the
## required keys EXIST before the rebuild, which closed the truncated-file path — and left three
## inputs still reaching `_from_dictionary()`, still dying inside it, and still coming back as
## `{"record": null, "error": ""}`: THE SAME EMPTY-REASON REFUSAL, read as SUCCESS by any caller
## testing `error != ""`. All three are checked here, each against the key it corrupts.
func test_a_record_whose_required_keys_carry_the_wrong_types_is_refused_with_a_reason() -> void:
	var record: IntentRecorder = _record_a_driven_run()["record"]
	for corruption: Array in [
		[{"tick_count": "eighteen", "seed": [], "costs": 7}, "tick_count",
			"required keys present but carrying WRONG TYPES"],
		[{"reload_events": null}, "reload_events", "`null` under reload_events"],
		[{"intents": null}, "intents", "`null` under intents"],
	]:
		assert_eq(RecordFile.save_record(record, VERSION_PATH), "", "the intact record was written")
		assert_not_null(RecordFile.load_record(VERSION_PATH)["record"], "...and loads intact")
		_rewrite_values(VERSION_PATH, corruption[0])
		var refused := RecordFile.load_record(VERSION_PATH)
		assert_null(refused["record"], "%s: REFUSED, never half-rebuilt" % corruption[2])
		assert_ne(refused["error"], "",
			"%s: ...WITH A REASON — the empty-reason refusal `3-0d/R15` closed for MISSING keys was "
					% corruption[2] + "still open for present-but-wrong ones")
		assert_true(refused["error"].contains(corruption[1] as String),
			"%s: ...and the reason NAMES the key: %s" % [corruption[2], refused["error"]])
		_remove(VERSION_PATH)
	# NON-VACUITY: `has()` really is true for a null value, which is WHY the presence check alone
	# could not catch two of the three above. This is the engine semantics the ruling rests on.
	var probe := {"intents": null}
	assert_true(probe.has("intents"),
		"`has()` is TRUE for a key whose value is null — the gap `3-0d/R21` closes")


# ------------------------------------------- 5-1a AC 4/AC 5/AC 6: the CONTENTS of two channels

## Story 5-1a (AC 4/AC 6, `4-6` finding L7). `3-0d/R21` validated the top-level keys and their
## TYPES; it said nothing about what is INSIDE them. A record whose `lock_pushes` is a perfectly
## good Dictionary carrying a TRUNCATED pair got all the way into `_from_dictionary`'s rebuild loop
## and hit `int(push[0])` / `push[1] as Vector2` on it — a script error, or a silent coercion that
## replays WRONG. The same discipline now runs one level deeper, and BEFORE the rebuild (`5-1a/R10`).
##
## Each corruption is one an adversary or a hand-edit really produces, and the reason must NAME the
## tick: a refusal that says only "malformed" sends the operator through the whole file by hand.
##
## MUTATION PROOF: delete the `_lock_pushes_refusal` call from `_contents_refusal` and every case
## below goes RED — most of them by the load succeeding, and the first by the SCRIPT ERROR the
## unguarded dereference raises, which `run_all.sh` fails the suite on outright.
func test_a_record_whose_lock_pushes_carry_a_malformed_entry_is_refused_with_a_reason() -> void:
	var record: IntentRecorder = _record_a_driven_run()["record"]
	for corruption: Array in [
		["not an array", "a tick whose entry list is not an Array at all"],
		[[7], "an ENTRY that is not an Array — the pair is a bare int"],
		[[[0]], "a TRUNCATED pair, finding L7's own word"],
		[[[]], "an EMPTY pair"],
		[[[0, Vector2(1.0, 0.0), 5]], "an OVER-LONG pair, the other side of the arity check"],
		[[["zero", Vector2(1.0, 0.0)]], "a slot that is not an int"],
		[[[0, "north"]], "a direction that is not a Vector2"],
		[[[0, Vector2(1.0, 0.0)], [1, null]], "a good pair FOLLOWED by a null-carrying one"],
	]:
		assert_eq(RecordFile.save_record(record, VERSION_PATH), "", "the intact record was written")
		assert_not_null(RecordFile.load_record(VERSION_PATH)["record"], "...and loads intact")
		_rewrite_values(VERSION_PATH, {"lock_pushes": {LOCK_CORRUPT_TICK: corruption[0]}})
		var refused := RecordFile.load_record(VERSION_PATH)
		assert_null(refused["record"],
			"%s: the WHOLE record is refused, never partially rebuilt (AC 6)" % corruption[1])
		assert_ne(refused["error"], "", "%s: ...WITH A REASON" % corruption[1])
		assert_true(refused["error"].contains("lock_pushes"),
			"%s: ...naming the channel: %s" % [corruption[1], refused["error"]])
		assert_true(refused["error"].contains(str(LOCK_CORRUPT_TICK)),
			"%s: ...and the TICK it is on: %s" % [corruption[1], refused["error"]])
		_remove(VERSION_PATH)
	# THE PAIR, and it is what keeps every refusal above attributable to the corruption: a
	# WELL-FORMED entry written into the same channel at the same tick LOADS. Without this the
	# guard could be refusing every record that carries a lock push at all.
	assert_eq(RecordFile.save_record(record, VERSION_PATH), "", "the intact record was written")
	_rewrite_values(VERSION_PATH,
		{"lock_pushes": {LOCK_CORRUPT_TICK: [[0, Vector2(1.0, 0.0)], [1, Vector2(0.0, -1.0)]]}})
	assert_not_null(RecordFile.load_record(VERSION_PATH)["record"],
		"two WELL-FORMED [slot, direction] pairs at the same tick load fine — the refusals above "
		+ "are caused by the SHAPE and by nothing else")
	# `5-1a/R11`: SPARSENESS IS NOT MALFORMEDNESS. The writer omits every empty tick by design, so
	# an EMPTY channel — no tick keys at all — is the golden fixture's own shape and must load.
	_rewrite_values(VERSION_PATH, {"lock_pushes": {}})
	assert_not_null(RecordFile.load_record(VERSION_PATH)["record"],
		"a channel with NO tick keys is the normal write-path output, not a defect (`5-1a/R11`)")
	_remove(VERSION_PATH)


## Story 5-1a (AC 5/AC 6, `4-6` finding L8). `_intent_from_values` reads
## `values["retarget_slot"]`/`values["retarget_index"]` by DIRECT dict access, with neither a
## presence nor a type check — unlike `load_record`'s top-level loop, which checks both for every
## required key before the rebuild runs at all. A v6 intent dict that lost either field crashed the
## rebuild; one carrying a string coerced silently. Both are refused now, before the rebuild, with
## the tick, the slot and the FIELD named.
##
## `null` is in the table for `3-0d/R21`'s reason, one level down: `has()` is TRUE for a key whose
## value is null, so a presence check alone would pass it straight through to `int(null)`.
##
## MUTATION PROOF: delete the `_intents_refusal` call from `_contents_refusal` and every case goes
## RED — the two erasures by the SCRIPT ERROR the missing key raises, the rest by loading.
func test_a_record_whose_intent_dict_lacks_the_retarget_fields_is_refused_with_a_reason() -> void:
	var record: IntentRecorder = _record_a_driven_run()["record"]
	for corruption: Array in [
		[&"erase", "retarget_slot", null, "the field is MISSING outright"],
		[&"erase", "retarget_index", null, "...and the other one missing"],
		[&"set", "retarget_slot", "one", "a String where an int is read back"],
		[&"set", "retarget_index", null, "`null`, which `has()` reports as PRESENT (`3-0d/R21`)"],
		[&"set", "retarget_index", Vector2.ZERO, "a Vector2, the 4-6 `aim` field's old type"],
		[&"set", "retarget_slot", 1.5, "a float — `int()` would coerce it silently"],
	]:
		assert_eq(RecordFile.save_record(record, VERSION_PATH), "", "the intact record was written")
		assert_not_null(RecordFile.load_record(VERSION_PATH)["record"], "...and loads intact")
		_rewrite_intent_field(VERSION_PATH, INTENT_CORRUPT_TICK, INTENT_CORRUPT_SLOT,
				corruption[0] as StringName, corruption[1] as String, corruption[2])
		var refused := RecordFile.load_record(VERSION_PATH)
		assert_null(refused["record"],
			"%s: the WHOLE record is refused — not just that tick (AC 6)" % corruption[3])
		assert_ne(refused["error"], "", "%s: ...WITH A REASON" % corruption[3])
		assert_true(refused["error"].contains(corruption[1] as String),
			"%s: ...naming the FIELD: %s" % [corruption[3], refused["error"]])
		assert_true(refused["error"].contains("tick %d" % INTENT_CORRUPT_TICK),
			"%s: ...and the TICK: %s" % [corruption[3], refused["error"]])
		_remove(VERSION_PATH)
	# THE PAIR: the same field, at the same tick and slot, REWRITTEN TO A VALID int, loads — so the
	# refusals above are about the value and not about the seat rejecting every touched record.
	assert_eq(RecordFile.save_record(record, VERSION_PATH), "", "the intact record was written")
	_rewrite_intent_field(VERSION_PATH, INTENT_CORRUPT_TICK, INTENT_CORRUPT_SLOT, &"set",
			"retarget_slot", 1)
	assert_not_null(RecordFile.load_record(VERSION_PATH)["record"],
		"a rewritten but WELL-TYPED retarget_slot loads — the refusals above are caused by the "
		+ "value's shape and by nothing else")
	_remove(VERSION_PATH)


## STORY 6-1 (AC 5, `6-1/R4`): HALF (a) OF THE FORMAT MEASUREMENT — does mode ②'s new hold fact
## force a bump by the ROUND TRIP? MEASURED HERE: NO. `held` is walked generically by key at both
## ends (`copy_intent` on the way out, `_intent_from_values` on the way in), so a key no version of
## this file has ever heard of survives a save and a load untouched, with zero serialization edits.
##
## THIS TEST IS DELIBERATELY NOT AN ARGUMENT FOR THE BUMP — it is the measurement that says the
## SHAPE did not force one, recorded so a later reader does not mistake the version number for a
## serialization consequence. The bump's real cause is half (b), which no round trip inside a
## single build can see: a v7 record carries no such key at all, so a chargeup that LANDED when it
## was recorded replays as an instant paid feint. That divergence is what the exact-match refusal
## is for, and it is measured at the state layer by the pair
## `test_holding_the_confirm_through_the_whole_chargeup_lands_as_before` /
## `test_a_one_tick_tap_is_the_same_paid_feint` in test_unblockable_hold.gd — two runs whose
## card_slot/card_mode/card_commit streams are identical and which differ ONLY in the presence of
## this key, one landing and one feinting.
##
## THE GENERIC WALK IS PINNED IN BOTH DIRECTIONS: a key present survives as present, and a key
## ABSENT does not come back invented as `true` — which is exactly the read a v7 record gets.
func test_a_new_held_key_round_trips_without_any_serialization_edit() -> void:
	var driven := _match_start()
	var record: IntentRecorder = driven["record"]
	var holding := InputIntent.new()
	holding.held[&"card_cast"] = true
	var empty := InputIntent.new()
	var intents: Array[InputIntent] = [holding, empty]
	_tick(driven, intents)

	var loaded := _save_and_load(record, ROUND_TRIP_PATH)
	var back := loaded.intents_at(1)
	assert_true(back[0].is_held(&"card_cast"),
		"the `card_cast` held key survived save + load with NO serialization edit — the shape "
		+ "forces no bump (`6-1/R4` half (a), MEASURED)")
	assert_false(back[1].is_held(&"card_cast"),
		"...and an ABSENT key comes back absent, never invented — which is precisely how a v7 "
		+ "record reads under this build, and precisely why v7 is refused rather than migrated")
	_remove(ROUND_TRIP_PATH)


## Story 5-1a (AC 7, `5-1a/R4`/`5-1a/R12`): the story's own NON-goals, pinned. The stricter reading
## must not have arrived as a format bump or a widened top-level key set — a record well-formed
## under yesterday's rules still loads identically, which is the whole compatibility claim.
func test_the_contents_validation_bumped_no_version_and_widened_no_required_key() -> void:
	assert_eq(RecordFile.FORMAT_VERSION, 11,
		"`5-1a/R4`: the SHAPE was unchanged BY 5-1a — only its validation was made stricter. The "
		+ "version has since moved to 11 (5-2's colours channel, 6-1's mode ② hold semantics, "
		+ "6-2's pitch-cost channel, 6-3a's `card_activate` intent field, then 6-7's silent-divergence "
		+ "bump for `run`/`walk_speed`), which is a different "
		+ "story's bump and does not weaken 5-1a's own claim: what this asserts is that the number "
		+ "is whatever the last DELIBERATE bump set it to, and that 5-1a was not one")
	for field: String in RecordFile.REQUIRED_INTENT_FIELDS:
		assert_false(RecordFile.REQUIRED_KEYS.has(field),
			("`5-1a/R12`: `%s` is a PER-INTENT field inside each `intents` element, never a "
			+ "top-level key — REQUIRED_KEYS is not widened by this story") % field)
	assert_eq(RecordFile.REQUIRED_KEYS.size(), 14,
		"FOURTEEN top-level required keys: story 6-2 added `pitch_costs`, the fifth content channel, "
		+ "and story 5-2 added `colors`, the fourth -- both those stories' bumps and not this one's. "
		+ "It was THIRTEEN before 6-2, TWELVE before 5-2 and TWELVE "
		+ "before 5-1a too (`5-1a/R12` counted them at the "
		+ "readiness gate) — this story validates CONTENTS, never presence at the top level")


## `3-0d/R22`: A SAVE PATH IS CHECKED BY NORMALISATION, NOT BY PREFIX. `3-0d/R16` shipped
## `begins_with("user://")`, which a `user://../../…` path satisfies while writing anywhere it
## likes. Each traversal form below is resolved and refused, and NOTHING is written — checked at
## the resolved native path, so "nothing was written" is a claim about the filesystem rather than
## about the string that was refused.
func test_a_save_path_that_escapes_the_user_directory_is_refused_and_writes_nothing() -> void:
	var record: IntentRecorder = _record_a_driven_run()["record"]
	for traversal: String in [
		"user://../../test_3_0d_traversal.rec",
		"user://../test_3_0d_traversal.rec",
		"user://../../../dev/cardsouls/test_3_0d_traversal.rec",
		"user://sub/../../test_3_0d_traversal.rec",
		# The sibling-directory trap: this RESOLVES to a path having the user root as a STRING
		# prefix while being a different directory, so a naive begins_with(root) would allow it.
		"user://../CardSoulsEvil/test_3_0d_traversal.rec",
	]:
		var error := RecordFile.save_record(record, traversal)
		assert_ne(error, "", "`%s` ESCAPES user:// and is REFUSED" % traversal)
		assert_true(error.contains("user://"),
			"...with a reason naming where records go: %s" % error)
		var resolved := ProjectSettings.globalize_path(traversal).simplify_path()
		assert_false(FileAccess.file_exists(resolved),
			"...and NOTHING was written at the path it resolves to (%s)" % resolved)
	# ...and the guard still lets a legitimate path through, including one that only LOOKS like a
	# traversal and resolves back inside: the check is containment, not a ban on the characters.
	for allowed: String in [VERSION_PATH, "user://sub/../test_3_0d_traversal.rec"]:
		assert_eq(RecordFile.save_record(record, allowed), "",
			"`%s` resolves INSIDE user:// and is written" % allowed)
		assert_true(FileAccess.file_exists(allowed), "...and the file really is there")
		_remove(allowed)


# ---------------------------------------------------------------- `3-0d/R30`

## `3-0d/R30`: SAVE MUST NEVER OVERWRITE AN EXISTING RECORD. `_save_index` used to start at 0 in
## EVERY session, so a new session's first SAVE wrote `path_for(1)` again and silently destroyed
## whatever a prior session had already written there — measured live, against the operator, who
## lost the only recording that had ever exercised the contact channel to exactly this defect.
##
## THESE TESTS DRIVE `first_free_index` AGAINST REAL `path_for` PATHS, DELIBERATELY NOT INDEX 1.
## `RecordFile`'s naming scheme has no seam for a test-only prefix, and this machine's real
## `user://` directory carries genuine operator records RIGHT NOW (the live smoke this story's
## close-out records) — SPARSELY, not just at the low indices, because the very defect this
## ruling fixes already cost the operator index 1 and 2 before this pass restored index 4 from an
## out-of-repo backup. A single free `first_free_index(1)` result is therefore NOT enough license
## to touch its NEIGHBOURS too: `_free_run` scans for a whole CONTIGUOUS span of unoccupied
## indices before any test writes a byte, so a test can never land on ground a real record already
## occupies. **This safeguard exists because its absence bit this exact pass**: the first version
## of the gap test below used a bare `first_free_index(1)` as `base` and touched `base + 3`
## assuming it was free — it was not, `cardsouls_record_4.rec` (8.4 MB, a real operator file) was
## there, and the touch overwrote it before the test's own assertion failed and its cleanup never
## ran. Restored from the out-of-repo backup taken earlier this pass, SHA-256
## `2790d90f6045c6d0309f2ecacc94872a15b06082cc8832a277b83012ac00ea6e` verified identical. `_free_run`
## is what makes that class of mistake structurally unavailable to every test below.
func test_first_free_index_returns_the_starting_index_when_nothing_occupies_it() -> void:
	var base := _free_run(1)
	assert_eq(RecordFile.first_free_index(base), base,
		"an untouched directory (from `base` on) returns `base` itself")


func test_first_free_index_skips_a_single_occupied_path() -> void:
	var base := _free_run(2)
	_touch(RecordFile.path_for(base))
	assert_eq(RecordFile.first_free_index(base), base + 1,
		"index %d is occupied, so the first free one is %d" % [base, base + 1])
	_remove(RecordFile.path_for(base))


func test_first_free_index_finds_the_gap_not_the_index_past_the_last_occupied_one() -> void:
	var base := _free_run(4)
	_touch(RecordFile.path_for(base))
	_touch(RecordFile.path_for(base + 1))
	_touch(RecordFile.path_for(base + 3))
	# base+2 is the gap: occupied, occupied, FREE, occupied.
	assert_eq(RecordFile.first_free_index(base), base + 2,
		"the GAP at %d is returned, not %d (one past the LAST occupied index)"
				% [base + 2, base + 4])
	_remove(RecordFile.path_for(base))
	_remove(RecordFile.path_for(base + 1))
	_remove(RecordFile.path_for(base + 3))


## THE PROPERTY ITSELF, PROVEN RATHER THAN INFERRED FROM THE INDEX ARITHMETIC ABOVE: write a
## MARKER file — arbitrary bytes, not a real record, so any mutation to it is unambiguous — at the
## first free index, then run exactly the sequence `save_recorded_stream()` runs
## (`first_free_index` then `save_record`), and assert the marker survives BYTE-FOR-BYTE. Reverting
## `first_free_index` to a bare `start` (the pre-`R30` behaviour) makes this go RED: the "save"
## computes the OCCUPIED path and overwrites the marker.
func test_save_at_the_computed_free_index_never_overwrites_an_existing_file() -> void:
	var base := _free_run(2)
	var marker_path := RecordFile.path_for(base)
	var marker_bytes := PackedByteArray([1, 2, 3, 4, 5, 250, 251, 252, 0, 255])
	_touch(marker_path, marker_bytes)

	var record: IntentRecorder = _record_a_driven_run()["record"]
	var index := RecordFile.first_free_index(base)
	var save_path := RecordFile.path_for(index)
	assert_ne(save_path, marker_path,
		"the computed save path is NOT the occupied one — this is the property under test")
	assert_eq(RecordFile.save_record(record, save_path), "", "the record was written to the free index")

	var reader := FileAccess.open(marker_path, FileAccess.READ)
	var marker_after := reader.get_buffer(reader.get_length())
	reader.close()
	assert_eq(marker_after, marker_bytes,
		"the marker at %s is BYTE-UNCHANGED — SAVE found a free index instead of landing on it"
				% marker_path)
	_remove(marker_path)
	_remove(save_path)


# ---------------------------------------------------------------- AC 6

## AC 6: RECORDING IS ALWAYS-ON AND SAVE DOES NOT INTERRUPT IT. Drive N ticks, save, drive M more,
## save again: the second file carries N + M ticks and STILL STARTS AT TICK 1. A SAVE that stopped
## the stream would leave the second file at N; one that restarted it would leave the second file
## at M with a different tick 1.
##
## Each tick's intent carries a DISTINCT move_dir, so "starts at tick 1" is checked against the
## value the FIRST tick actually drove rather than against a bare non-emptiness.
func test_saving_does_not_stop_or_restart_the_recording() -> void:
	var driven := _match_start()
	var record: IntentRecorder = driven["record"]
	for t in range(1, TICKS_BEFORE_FIRST_SAVE + 1):
		_tick(driven, _marked_intents(t))
	assert_eq(RecordFile.save_record(record, FIRST_SAVE_PATH), "", "the first save was written")
	for t in range(TICKS_BEFORE_FIRST_SAVE + 1, TICKS_BEFORE_FIRST_SAVE + TICKS_BETWEEN_SAVES + 1):
		_tick(driven, _marked_intents(t))
	assert_eq(RecordFile.save_record(record, SECOND_SAVE_PATH), "", "the second save was written")

	var total := TICKS_BEFORE_FIRST_SAVE + TICKS_BETWEEN_SAVES
	assert_eq(record.tick_count(), total,
		"the LIVE recorder kept counting across both saves — SAVE touches no recorder state")
	var first := _loaded(FIRST_SAVE_PATH)
	var second := _loaded(SECOND_SAVE_PATH)
	assert_eq(first.tick_count(), TICKS_BEFORE_FIRST_SAVE, "the first file is the stream so far")
	assert_eq(second.tick_count(), total,
		"the second file is CUMULATIVE (%d + %d) — SAVE did not stop or restart the recording"
				% [TICKS_BEFORE_FIRST_SAVE, TICKS_BETWEEN_SAVES])
	assert_eq(second.replay_intent(1, 0).move_dir, _marked_move_dir(1),
		"...and it still begins at TICK 1, with the value the first tick actually drove — a "
		+ "restarted recording would begin at the tick the SAVE happened on")
	assert_eq(second.replay_intent(TICKS_BEFORE_FIRST_SAVE + 1, 0).move_dir,
		_marked_move_dir(TICKS_BEFORE_FIRST_SAVE + 1),
		"...and carries the ticks driven AFTER the first save in their own places")
	assert_ne(_marked_move_dir(1), _marked_move_dir(TICKS_BEFORE_FIRST_SAVE + 1),
		"sanity: the per-tick markers really are distinct, so the two assertions above differ")
	assert_eq(first.replay_intent(1, 0).move_dir, second.replay_intent(1, 0).move_dir,
		"both files agree about tick 1: the record is one stream, snapshotted twice")
	# The operator-visible half of the same fact: the second file is LONGER on disk.
	assert_true(_file_size(SECOND_SAVE_PATH) > _file_size(FIRST_SAVE_PATH),
		"the second save is larger on disk (%d > %d) — what the smoke observes at the keyboard"
				% [_file_size(SECOND_SAVE_PATH), _file_size(FIRST_SAVE_PATH)])
	_remove(FIRST_SAVE_PATH)
	_remove(SECOND_SAVE_PATH)


# ---------------------------------------------------------------- fixtures

func _save_and_load(record: IntentRecorder, path: String) -> IntentRecorder:
	assert_eq(RecordFile.save_record(record, path), "", "the record was written to %s" % path)
	return _loaded(path)


func _loaded(path: String) -> IntentRecorder:
	var result := RecordFile.load_record(path)
	assert_eq(result["error"], "", "loading %s reported no error" % path)
	assert_not_null(result["record"], "loading %s produced a record" % path)
	return result["record"]


## The RUNNER's role, played by the fixture: capture beside every call, in the live order.
func _match_start() -> Dictionary:
	var record := IntentRecorder.new()
	var params := MatchParams.new(SEED)
	record.capture_seed(params.seed_value)
	var ms := MatchState.new(params)
	var config := _config()
	record.capture_apply_balance(config)
	ms.apply_balance(config)
	var flags := _flags()
	record.capture_inject_feature_flags(flags)
	ms.inject_feature_flags(flags)
	record.capture_inject_deck(DECK_IDS)
	ms.inject_deck(DECK_IDS)
	var costs := _costs()
	record.capture_inject_card_costs(costs)
	ms.inject_card_costs(costs)
	# Story 4-1 (`4-1/R1`, `4-1/R8`): the THIRD content channel, captured and injected LAST -- the
	# order deck -> costs -> effects the live runner produces and SOUND_CONTENT_ORDER pins.
	var effects := _effects()
	record.capture_inject_card_effects(effects)
	ms.inject_card_effects(effects)
	# Story 5-2 (`5-2/R1`): the FOURTH content channel, captured and injected LAST -- the order
	# deck -> costs -> effects -> colours the live runner produces and SOUND_CONTENT_ORDER pins.
	var colors := _colors()
	record.capture_inject_card_colors(colors)
	ms.inject_card_colors(colors)
	# Story 6-2 (AC 16): the FIFTH content channel, captured and injected LAST -- the order the live
	# runner produces and SOUND_CONTENT_ORDER pins.
	var pitch_costs := _pitch_costs()
	record.capture_inject_pitch_costs(pitch_costs)
	ms.inject_pitch_costs(pitch_costs)
	ms.drain_signals()
	return {"record": record, "state": ms}


func _record_a_driven_run() -> Dictionary:
	var driven := _match_start()
	var record: IntentRecorder = driven["record"]
	var ms: MatchState = driven["state"]
	for t in range(1, TICKS + 1):
		if t == RELOAD_TICK:
			var retuned := _retuned_config()
			record.capture_apply_balance(retuned)
			ms.apply_balance(retuned)
		for push: Array in _camera_pushes():
			record.capture_set_camera_basis(int(push[0]), push[1] as Basis)
			ms.set_camera_basis(int(push[0]), push[1] as Basis)
		if t == CONTACT_TICK:
			record.capture_push_contact([0, -1], [1, -1], 0, Vector2(-1, 0), MatchState.CONTACT_STRIKE)
			ms.push_contact([0, -1], [1, -1], 0, Vector2(-1, 0), MatchState.CONTACT_STRIKE)
		_tick(driven, _intents(t))
	return driven


func _tick(driven: Dictionary, intents: Array[InputIntent]) -> void:
	(driven["record"] as IntentRecorder).capture_advance(intents)
	var ms: MatchState = driven["state"]
	ms.advance(intents)
	ms.drain_signals()


## Story 6-8 (AC 2, Golden Prediction cause 2 / Open Question 3): an UNLOCK survives SAVE and LOAD and
## replays to the live hash WITH NO FORMAT BUMP. The unlock rides the existing `retarget_slot`/
## `retarget_index` pair as the sentinel address `[PlayerState.UNLOCKED_SLOT, HERO_INDEX]` -- a new
## VALUE, not a new field -- so the intent codec and `REQUIRED_INTENT_FIELDS` carry it untouched.
##
## NON-VACUITY: the same run WITHOUT the unlock hashes differently (the unlocked hero's facing follows
## its moving stick; the locked one, with no lock fact pushed, holds its default), so the equality
## below is a claim about a value that actually reached the hash.
func test_an_unlock_saves_loads_and_replays_to_the_live_hash() -> void:
	var unlocked := _record_an_unlock_run(true)
	var ms: MatchState = unlocked["state"]
	assert_eq([ms.p1.lock_target_slot, ms.p1.lock_target_index],
		[PlayerState.UNLOCKED_SLOT, TargetingService.HERO_INDEX], "sanity: the live run ended unlocked")
	var live_hash := CanonicalHash.of(ms.to_snapshot())
	var loaded := _save_and_load(unlocked["record"], UNLOCK_ROUND_TRIP_PATH)
	var got := loaded.replay_intent(UNLOCK_TICK, 0)
	assert_eq([got.retarget_slot, got.retarget_index],
		[PlayerState.UNLOCKED_SLOT, TargetingService.HERO_INDEX], "the unlock address came back from the file")
	var replayed := _replay(loaded)
	assert_eq(CanonicalHash.of(replayed.to_snapshot()), live_hash,
		"the loaded record replays the unlocked run to the same canonical hash")
	assert_false(replayed.p1.is_locked(), "...and the replayed P1 is unlocked too")
	var still_locked: MatchState = _record_an_unlock_run(false)["state"]
	assert_ne(CanonicalHash.of(still_locked.to_snapshot()), live_hash,
		"the unlock is load-bearing on the hash, so the replay equality above is not vacuous")
	_remove(UNLOCK_ROUND_TRIP_PATH)


func _record_an_unlock_run(unlock: bool) -> Dictionary:
	var driven := _match_start()
	var record: IntentRecorder = driven["record"]
	var ms: MatchState = driven["state"]
	for t in range(1, TICKS + 1):
		for push: Array in _camera_pushes():
			record.capture_set_camera_basis(int(push[0]), push[1] as Basis)
			ms.set_camera_basis(int(push[0]), push[1] as Basis)
		var intents := _marked_intents(t)
		if unlock and t == UNLOCK_TICK:
			intents[0].retarget_slot = PlayerState.UNLOCKED_SLOT
			intents[0].retarget_index = TargetingService.HERO_INDEX
		_tick(driven, intents)
	return driven


## Non-identity on slot 0, identity on slot 1 — both paths of the basis channel covered, and a
## dropped basis would land the same intent on a different world direction.
func _camera_pushes() -> Array:
	return [[0, Basis(Vector3.UP, deg_to_rad(CAMERA_YAW_DEGREES))], [1, Basis.IDENTITY]]


## Every one of InputIntent's TEN fields is driven non-default somewhere in the run, so the
## round trip is compared against a stream that actually carries them. Story 4-6 replaces `aim`
## (driven every tick) with the retarget address, driven on ONE tick -- because that is what the
## field's resting value MEANS: `retarget_slot == NO_RETARGET` is a tick with no click and no
## flick, and driving it on every tick would model a gesture no player makes.
func _intents(t: int) -> Array[InputIntent]:
	var i1 := InputIntent.new()
	i1.move_dir = _marked_move_dir(t)
	if t == RETARGET_TICK:
		i1.retarget_slot = RETARGET_SLOT
		i1.retarget_index = RETARGET_INDEX
	var i2 := InputIntent.new()
	i2.move_dir = Vector2(-1, 0)
	if t == RESET_TICK:
		i1.debug_reset = true
	if t == ATTACK_TICK:
		i1.pressed[&"attack"] = true
		i1.held[&"attack"] = true
	if t == ACTIVATE_TICK:
		i1.card_mode = Enums.ModeKind.PITCH
		i1.card_commit = true
		i1.card_activate = true
	if t == STAGE_TICK:
		i1.card_slot = STAGE_SLOT
		i1.card_mode = Enums.ModeKind.PITCH
		i1.card_commit = true
	if t == CAST_TICK:
		i1.card_slot = CAST_SLOT
		i1.card_mode = Enums.ModeKind.BASIC
		i1.card_commit = true
	var out: Array[InputIntent] = [i1, i2]
	return out


## AC 6's per-tick marker: a DISTINCT move_dir per tick, so "the file starts at tick 1" is a
## claim about the value tick 1 drove rather than about the array being non-empty.
func _marked_intents(t: int) -> Array[InputIntent]:
	var i1 := InputIntent.new()
	i1.move_dir = _marked_move_dir(t)
	var out: Array[InputIntent] = [i1, InputIntent.new()]
	return out


func _marked_move_dir(t: int) -> Vector2:
	return Vector2(t * 0.125, t * -0.0625)


## The SECOND, independent MatchState — driven ONLY by the record, in the runner's replay order
## (reloads, bases, facts, then advance). Identical for the in-memory record and the loaded one,
## which is what makes the two hashes comparable.
##
## `3-0d/R17`: THE ORDER ITSELF NOW LIVES IN `ReplayDrive`, SHARED WITH AC 8's HEADLESS VERIFIER.
## It used to be transcribed here and again in `test/tools/replay_file.gd`, and the review found
## the verifier's copy guarded by nothing — this test proved the SAVE/LOAD path, never the
## verifier's ordering. Sharing the drive is what makes AC 4 cover it: every hash equality below
## is now measured through the same code the verifier runs.
func _replay(record: IntentRecorder) -> MatchState:
	var result := ReplayDrive.drive(record)
	assert_eq(result["error"], "",
		"the recorded content order replays (`3-0c/R11`): %s" % result["error"])
	return result["state"]


# ---------------------------------------------------------------- fixture content

func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = MOVE_SPEED
	# Story 6-7 (`6-7/R11`): authored EQUAL TO MOVE_SPEED -- no call site here presses `&"run"`,
	# so gait is a no-op and move_speed's round-trip assertions hold unchanged.
	c.walk_speed = MOVE_SPEED
	c.max_stamina = 30.0
	c.stamina_regen_per_second = 60.0
	c.stamina_regen_delay_seconds = 2.0 / 60.0
	c.roll_stamina_cost = 8.0
	c.attack_stamina_cost = 4.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 5.0 / 60.0
	c.attack_chain_window_seconds = 4.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 20.0
	c.max_mana = 60.0
	c.melee_hit_mana = MELEE_HIT_MANA
	c.deck_size = DECK_IDS.size()
	c.hand_size = HAND_SIZE
	c.block_damage_multiplier = 0.5
	c.deflect_window_seconds = 3.0 / 60.0
	c.block_facing_arc_degrees = 180.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	# Story 4-4 (`4-4/R15`): the recorded config's NESTED half. `_config()` is the object the
	# reload-event channel serialises, so putting the kind list here is what makes the round-trip
	# assertions measure the three-level nesting rather than a flat wall of floats.
	c.unit_kinds = [_ranged_kind()]
	# Story 6-2 (AC 16): long enough that the driven run's staged card is still in the zone at the end.
	c.pitch_stage_timer_seconds = PITCH_TIMER_TICKS / 60.0
	return c


## A kind carrying an attack carrying a projectile — the deepest shape `BalanceConfig` can hold,
## built in-test over opaque values (the `BC/R3` golden-isolation discipline) so a tuning pass
## cannot move it and it cannot move the golden.
func _ranged_kind() -> UnitKindProfile:
	var projectile := ProjectileProfile.new()
	projectile.launch_speed = 9.0
	projectile.travel_budget = PROJECTILE_BUDGET
	projectile.max_speed = 20.0
	var attack := UnitAttackProfile.new()
	attack.windup_seconds = 3.0 / 60.0
	attack.active_seconds = 2.0 / 60.0
	attack.recovery_seconds = 4.0 / 60.0
	attack.range = KIND_RANGE
	attack.damage = KIND_DAMAGE
	attack.projectile = projectile
	var kind := UnitKindProfile.new()
	kind.kind_name = KIND_NAME
	kind.max_hp = KIND_MAX_HP
	kind.move_speed = 3.0
	kind.stop_distance = 1.5
	kind.priority_name = &"standard"
	kind.attacks = [attack]
	return kind


## The mid-run reload's config — one moved value, so the event's effect on the replay is a single
## named number rather than a wall of them. move_speed is a snapshot key.
func _retuned_config() -> BalanceConfig:
	var c := _config()
	c.move_speed = RETUNED_MOVE_SPEED
	# Story 6-7 (Fact M5(d)): retune walk_speed alongside move_speed, unaffected by (a) but still
	# needed for consistency with this file's own mid-run retune.
	c.walk_speed = RETUNED_MOVE_SPEED
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	# Story 4-1: the minion layer ON, so this fixture's recorded `summon_` cast actually appends a
	# unit record. Without it the effects channel would ride the record while changing nothing in
	# the hash, and every proof that rests on it would be VACUOUS.
	f.minions = true
	# Story 6-2: the pitch layer ON, so the driven run's STAGE_TICK stage actually stages.
	f.pitch_zone = true
	return f


## Story 4-1 (`4-1/R1`): the effect map for this fixture's composition -- `_costs()`'s twin,
## built in-test over the same opaque ids. Every id carries a `summon_` prefix so the channel is
## exercised by a resolver that actually appends a unit record.
func _effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id in DECK_IDS:
		var e := CardEffect.new()
		e.effect_id = StringName("summon_%s" % id)
		out[id] = e
	return out


## Story 6-2 (AC 16): the pitch-cost map -- every id priced, each carrying an ORB price so the typed
## `orb_costs` dictionary is exercised through store_var and `_rebuilt`, not just a float.
func _pitch_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in DECK_IDS:
		var c := CardCastCondition.new()
		c.mana_cost = PITCH_MANA_COST
		c.orb_costs[Enums.CardColor.BLUE] = 2
		out[id] = c
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in DECK_IDS:
		var c := CardCastCondition.new()
		c.mana_cost = CAST_MANA_COST
		out[id] = c
	return out


# ---------------------------------------------------------------- file helpers

## AC 5: rewrite ONLY the version field of an existing record, leaving every other value as
## written. Reads the file back through the same store_var shape the writer used, so nothing but
## `format_version` differs between the two loads.
func _rewrite_format_version(path: String, version: int) -> void:
	var reader := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = reader.get_var()
	reader.close()
	data["format_version"] = version
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_var(data)
	writer.close()


## `3-0d/R15`: remove keys from an existing record, leaving every other value — and the version —
## exactly as written. The truncation a real partial write would produce, made deterministic.
func _rewrite_without(path: String, keys: Array) -> void:
	var reader := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = reader.get_var()
	reader.close()
	for key in keys:
		assert_true(data.has(key), "the record carried `%s` before it was removed" % key)
		data.erase(key)
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_var(data)
	writer.close()


## `3-0d/R21`: overwrite named values in an existing record, leaving the version and every other
## key EXACTLY as written — so the refusal under test is about the corrupted values and nothing
## else. The keys stay PRESENT, which is the whole point: `has()` still says yes.
func _rewrite_values(path: String, values: Dictionary) -> void:
	var reader := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = reader.get_var()
	reader.close()
	for key: String in values:
		assert_true(data.has(key), "the record carried `%s` before it was corrupted" % key)
		data[key] = values[key]
		assert_true(data.has(key), "...and STILL carries it afterwards — presence is not type")
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_var(data)
	writer.close()


## Story 5-1a (AC 5): corrupt ONE field of ONE per-tick, per-slot intent dictionary inside a saved
## record, leaving every other tick, every other slot and every other key EXACTLY as written — so
## the refusal under test is about that one field and nothing else. `mode` is `&"erase"` (the
## missing-key half of L8) or `&"set"` (the wrong-type half).
func _rewrite_intent_field(path: String, tick: int, slot: int, mode: StringName, field: String,
		value: Variant) -> void:
	var reader := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = reader.get_var()
	reader.close()
	var intents: Array = data["intents"]
	assert_true(tick - 1 < intents.size(), "tick %d is inside the recorded run" % tick)
	var pair: Array = intents[tick - 1]
	assert_true(slot < pair.size(), "slot %d exists on tick %d" % [slot, tick])
	var values: Dictionary = (pair[slot] as Dictionary).duplicate()
	assert_true(values.has(field), "the intent carried `%s` before it was corrupted" % field)
	if mode == &"erase":
		values.erase(field)
	else:
		values[field] = value
	pair[slot] = values
	intents[tick - 1] = pair
	data["intents"] = intents
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_var(data)
	writer.close()


## Story 4-4: the whole file as bytes, for the identity comparison. Read as a buffer rather than
## through `get_var`, so the assertion is about the FILE and not about the reader agreeing with
## itself.
func _bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var out := f.get_buffer(f.get_length())
	f.close()
	return out


## Story 4-4 (`4-4/R15`): rewrite a saved record into the shape a PRE-4-4 build would have written
## — version 4, and every recorded config stripped of `unit_kinds` and given back the flat keys the
## kind list replaced. That is the file the version check has to refuse.
func _rewrite_as_pre_4_4(path: String) -> void:
	var reader := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = reader.get_var()
	reader.close()
	data["format_version"] = 4
	for event: Dictionary in (data["reload_events"] as Array):
		var values: Dictionary = event["values"]
		values.erase("unit_kinds")
		values["unit_max_hp"] = KIND_MAX_HP
		values["unit_damage_per_hit"] = KIND_DAMAGE
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_var(data)
	writer.close()


## Story 6-2 (AC 16): turn a saved record into what a v8 build wrote -- version 8, no `pitch_costs` key,
## and no pitch channel in the recorded content order. Everything else exactly as written.
func _rewrite_as_pre_6_2(path: String) -> void:
	var reader := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = reader.get_var()
	reader.close()
	data["format_version"] = 8
	assert_true(data.has("pitch_costs"), "the record carried `pitch_costs` before it was stripped")
	data.erase("pitch_costs")
	var order: Array = data["content_order"]
	order.erase(IntentRecorder.CHANNEL_PITCH_COSTS)
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_var(data)
	writer.close()


## Story 6-3a (AC 4): turn a saved record into what a v9 build wrote -- version 9, and NO `card_activate`
## key in any per-tick, per-player intent. Everything else exactly as written.
func _rewrite_as_pre_6_3a(path: String) -> void:
	var reader := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = reader.get_var()
	reader.close()
	data["format_version"] = 9
	var stripped := 0
	for pair: Array in (data["intents"] as Array):
		for values: Dictionary in pair:
			if values.erase("card_activate"):
				stripped += 1
	assert_eq(stripped, TICKS * 2, "every intent carried `card_activate` before it was stripped")
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_var(data)
	writer.close()


func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var size := f.get_length()
	f.close()
	return int(size)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## `3-0d/R30`: write arbitrary bytes at `path` — a MARKER, never a real record, so a test asserting
## on its survival is not also depending on `RecordFile`'s own read/write pair being correct.
func _touch(path: String, bytes: PackedByteArray = PackedByteArray([1])) -> void:
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_buffer(bytes)
	writer.close()


## `3-0d/R30`: the first index whose `count`-LONG run, `[index, index + count)`, is ENTIRELY free —
## not merely `index` itself. Real operator records on this machine sit SPARSELY, so a single free
## `first_free_index` result says nothing about its neighbours; a test that then touches several
## consecutive indices on that assumption alone can land on one that is occupied. This scans past
## any occupied index it finds, checking the WHOLE candidate span again from there, until a run
## that long is genuinely empty.
func _free_run(count: int) -> int:
	var candidate := RecordFile.first_free_index(1)
	var found := false
	while not found:
		var offset := 0
		while offset < count and not FileAccess.file_exists(RecordFile.path_for(candidate + offset)):
			offset += 1
		if offset == count:
			found = true
		else:
			candidate = RecordFile.first_free_index(candidate + offset + 1)
	return candidate


## Story 5-2 (AC 4, `5-2/R1`): the FOURTH content channel's fixture half. Colours are plain enum
## values, so unlike `_costs()` and `_effects()` this builds no Resource -- which is exactly why the
## channel round-trips as ints and needed no new serialisation machinery.
func _colors() -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	for i in DECK_IDS.size():
		out[DECK_IDS[i]] = Enums.CardColor.RED if i % 2 == 0 else Enums.CardColor.BLUE
	return out
