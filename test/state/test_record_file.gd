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

const DECK_IDS: Array[StringName] = [
	&"file_card_0", &"file_card_1", &"file_card_2", &"file_card_3", &"file_card_4", &"file_card_5",
]
const HAND_SIZE := 3
const CAST_MANA_COST := 5.0
const MELEE_HIT_MANA := 12.0
const MOVE_SPEED := 7.0
const RETUNED_MOVE_SPEED := 11.0
const CAMERA_YAW_DEGREES := 90.0

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

	var loaded := _save_and_load(record, ROUND_TRIP_PATH)
	assert_eq(loaded.tick_count(), record.tick_count(), "every tick survived the file")
	assert_eq(loaded.replay_seed(), record.replay_seed(), "the seed channel survived")
	assert_eq(loaded.content_order(), record.content_order(), "the content ORDER survived")
	assert_eq(loaded.replay_deck_contents(), record.replay_deck_contents(), "the composition survived")
	assert_eq(loaded.replay_card_costs().keys(), record.replay_card_costs().keys(),
		"the cost map's ids survived")
	assert_eq(loaded.replay_card_costs()[DECK_IDS[0]].mana_cost, CAST_MANA_COST,
		"...and their VALUES, rebuilt as fresh CardCastConditions")
	assert_eq(loaded.replay_feature_flags().melee_mana_generation,
		record.replay_feature_flags().melee_mana_generation, "the flags channel survived")
	assert_eq(loaded.reload_event_count(), record.reload_event_count(), "both reload events survived")
	for index in record.reload_event_count():
		assert_eq(loaded.reload_event_tick(index), record.reload_event_tick(index),
			"reload event %d kept its TICK — the rebuild re-captures it at the same point in the "
					% index + "stream, which is the only way capture_apply_balance can stamp it")
		assert_eq(loaded.replay_balance_config(index).move_speed,
			record.replay_balance_config(index).move_speed, "...and its values")
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
			assert_eq(got.aim, want.aim, "t%d s%d aim" % [tick, slot])
			assert_eq(got.pressed, want.pressed, "t%d s%d pressed" % [tick, slot])
			assert_eq(got.held, want.held, "t%d s%d held" % [tick, slot])
			assert_eq(got.debug_reset, want.debug_reset, "t%d s%d debug_reset" % [tick, slot])
			assert_eq(got.card_slot, want.card_slot, "t%d s%d card_slot" % [tick, slot])
			assert_eq(int(got.card_mode), int(want.card_mode), "t%d s%d card_mode" % [tick, slot])
			assert_eq(got.card_commit, want.card_commit, "t%d s%d card_commit" % [tick, slot])
			fields += 8
	assert_eq(fields, TICKS * 2 * 8,
		"all eight intent fields were compared for both slots on every tick (got %d)" % fields)
	# ...and the driven values really were non-default, or the comparison above proves nothing.
	var loud := loaded.replay_intent(CAST_TICK, 0)
	assert_eq(loud.card_slot, CAST_SLOT, "the cast tick's card fields came back non-default")
	assert_true(loud.card_commit, "...including the commit edge")
	assert_true(loaded.replay_intent(ATTACK_TICK, 0).is_held(&"attack"), "held came back non-empty")
	assert_true(loaded.replay_intent(RESET_TICK, 0).debug_reset, "debug_reset came back set")
	assert_ne(loaded.replay_intent(1, 0).aim, Vector2.ZERO, "aim came back non-zero")
	_remove(ROUND_TRIP_PATH)


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
			record.capture_push_contact(0, 1, 0, Vector2(-1, 0))
			ms.push_contact(0, 1, 0, Vector2(-1, 0))
		_tick(driven, _intents(t))
	return driven


func _tick(driven: Dictionary, intents: Array[InputIntent]) -> void:
	(driven["record"] as IntentRecorder).capture_advance(intents)
	var ms: MatchState = driven["state"]
	ms.advance(intents)
	ms.drain_signals()


## Non-identity on slot 0, identity on slot 1 — both paths of the basis channel covered, and a
## dropped basis would land the same intent on a different world direction.
func _camera_pushes() -> Array:
	return [[0, Basis(Vector3.UP, deg_to_rad(CAMERA_YAW_DEGREES))], [1, Basis.IDENTITY]]


## Every one of InputIntent's eight fields is driven non-default somewhere in the run, so the
## round trip is compared against a stream that actually carries them.
func _intents(t: int) -> Array[InputIntent]:
	var i1 := InputIntent.new()
	i1.move_dir = _marked_move_dir(t)
	i1.aim = Vector2(0.5, -0.25)
	var i2 := InputIntent.new()
	i2.move_dir = Vector2(-1, 0)
	if t == RESET_TICK:
		i1.debug_reset = true
	if t == ATTACK_TICK:
		i1.pressed[&"attack"] = true
		i1.held[&"attack"] = true
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
	return c


## The mid-run reload's config — one moved value, so the event's effect on the replay is a single
## named number rather than a wall of them. move_speed is a snapshot key.
func _retuned_config() -> BalanceConfig:
	var c := _config()
	c.move_speed = RETUNED_MOVE_SPEED
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	return f


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
