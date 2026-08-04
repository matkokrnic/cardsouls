extends TestCase

## Story 3-0c: the X5 record/replay STREAM CONTRACT — the capture channels themselves.
## The record-then-replay identity proof lives in its OWN fixture (test_replay_identity.gd,
## `3-0c/R6`); the live replay fork lives in test/integration/test_replay_contacts.gd (AC 9).
##
## Covers AC 1 (the channel set is DERIVED from MatchState's intake surface), AC 2 (all eight
## InputIntent fields verbatim), AC 3 (the seed, parameterised so no hardcoded constant can
## satisfy it), AC 5 / AC 6 (the two content channels and their load-bearing injection ORDER)
## and AC 7 (flags are a channel WITHOUT reopening load-once immutability).

const MATCH_STATE := "res://src/state/match_state.gd"
const RECORDER := "res://src/systems/intent_recorder.gd"
const REPLAY_CONTROLLER := "res://src/controllers/replay_controller.gd"
const FLAGS_SERVICE := "res://src/systems/feature_flags_service.gd"
const RUNNER := "res://src/main/match_runner.gd"

## AC 1: the ONE intake that is not a public method — the seed reaches MatchState through
## _init(params: MatchParams), so its channel cannot be named `capture__init`.
const SEED_INTAKE := "_init"
const SEED_CHANNEL := "capture_seed"

## AC 1: the ONE public member of MatchState's surface that is EXEMPT from needing a channel,
## named here and IN THE ASSERTION with its reason — drain_signals() takes no parameters and
## returns nothing, so it carries no data INWARD; it is the D5 emit half of a queue the runner
## empties every tick, not an intake.
const EXEMPT_CARRIES_NO_DATA_INWARD := "drain_signals"

## AC 1: the intake surface VERIFIED BY CONTENT at this story's pass. Pinned by exact set
## equality so a REMOVED intake is as loud as an added one — but the falling guard for the AC's
## actual claim is the channel check below, which fails for a new intake whether or not this
## list was updated.
const EXPECTED_INTAKE_SURFACE: Array[String] = [
	"_init", "advance", "apply_balance", "inject_card_costs", "inject_deck",
	"inject_feature_flags", "push_contact", "set_camera_basis",
]

const DECK_IDS: Array[StringName] = [&"rec_card_a", &"rec_card_b", &"rec_card_c"]


# ---------------------------------------------------------------- AC 1

## AC 1: THE CHANNEL SET IS DERIVED, NOT ENUMERATED BY HAND (`3-0c/R2` — "exactly five channels"
## is dead). MatchState's own source is scanned for every public way data enters the object from
## outside, and each derived intake must have its `capture_<intake>` channel on IntentRecorder.
## A new intake seam shipping without a channel FAILS HERE.
##
## THE DERIVATION RULE, stated so it can be checked rather than trusted: a public method that
## takes at least one PARAMETER carries data inward and is an intake; a public method that takes
## none either returns state (to_snapshot / debug_window_ticks_remaining — EGRESS) or is the
## named exemption above. _init is an intake because MatchParams carries the seed in.
func test_every_match_state_intake_has_a_capture_channel() -> void:
	var surface := _match_state_public_surface()
	assert_true(surface.size() > 0, "the scan must actually find MatchState's public surface")
	var intakes: Array[String] = []
	var egress: Array[String] = []
	var exempt: Array[String] = []
	for name: String in surface:
		if bool(surface[name]["has_params"]):
			intakes.append(name)
		elif name == EXEMPT_CARRIES_NO_DATA_INWARD:
			exempt.append(name)
		else:
			egress.append(name)
	intakes.sort()
	egress.sort()
	assert_eq(intakes, EXPECTED_INTAKE_SURFACE,
		"MatchState's intake surface changed — a new intake needs a capture channel (and this "
		+ "pin updated deliberately); a removed one needs its channel retired")
	assert_eq(exempt, [EXEMPT_CARRIES_NO_DATA_INWARD],
		"drain_signals() is EXEMPT and this is where that is recorded: it carries no data INWARD "
		+ "— it is the D5 emit half of a queue the runner empties every tick, not an intake")
	assert_eq(egress, ["debug_window_ticks_remaining", "to_snapshot"],
		"to_snapshot() and debug_window_ticks_remaining() are EGRESS, not intake — they return "
		+ "state and receive none")
	var channels := _recorder_method_names()
	var uncovered: Array[String] = []
	for intake in intakes:
		var channel := SEED_CHANNEL if intake == SEED_INTAKE else "capture_" + intake
		if not channels.has(channel):
			uncovered.append("%s -> %s" % [intake, channel])
	assert_eq(uncovered.size(), 0,
		"MatchState intake with no IntentRecorder capture channel — a replay would silently "
		+ "depend on whatever that seam receives live: %s" % ", ".join(uncovered))


# ---------------------------------------------------------------- AC 2

## AC 2: EVERY InputIntent FIELD RIDES THE STREAM VERBATIM, per tick, per slot. All eight fields
## are given a NON-DEFAULT value (asserted non-default, or the round-trip would pass against a
## recorder that dropped them and returned a fresh object), captured, and read back through the
## real ReplayController — the same path the runner uses, not a private accessor.
func test_all_eight_input_intent_fields_round_trip_per_tick_per_slot() -> void:
	var loud := InputIntent.new()
	loud.move_dir = Vector2(0.25, -0.75)
	loud.aim = Vector2(-0.5, 0.125)
	loud.pressed[&"attack"] = true
	loud.held[&"block"] = true
	loud.debug_reset = true
	loud.card_slot = 2
	loud.card_mode = Enums.ModeKind.PITCH
	loud.card_commit = true
	var resting := InputIntent.new()
	assert_ne(loud.move_dir, resting.move_dir, "move_dir is non-default")
	assert_ne(loud.aim, resting.aim, "aim is non-default")
	assert_ne(loud.pressed, resting.pressed, "pressed is non-default")
	assert_ne(loud.held, resting.held, "held is non-default")
	assert_ne(loud.debug_reset, resting.debug_reset, "debug_reset is non-default")
	assert_ne(loud.card_slot, resting.card_slot, "card_slot is non-default")
	assert_ne(int(loud.card_mode), int(resting.card_mode), "card_mode is non-default")
	assert_ne(loud.card_commit, resting.card_commit, "card_commit is non-default")

	var rec := _match_start_record()
	var slot1 := InputIntent.new()
	slot1.move_dir = Vector2(1, 0)
	var pair: Array[InputIntent] = [loud, slot1]
	rec.capture_advance(pair)

	# PER SLOT: read back through the shipped controller, one instance per slot.
	var got: InputIntent = ReplayController.new(rec, 0).sample()
	assert_eq(got.move_dir, loud.move_dir, "move_dir")
	assert_eq(got.aim, loud.aim, "aim")
	assert_eq(got.pressed, loud.pressed, "pressed")
	assert_eq(got.held, loud.held, "held")
	assert_eq(got.debug_reset, loud.debug_reset, "debug_reset")
	assert_eq(got.card_slot, loud.card_slot, "card_slot")
	assert_eq(int(got.card_mode), int(loud.card_mode), "card_mode")
	assert_eq(got.card_commit, loud.card_commit, "card_commit")
	assert_eq(ReplayController.new(rec, 1).sample().move_dir, slot1.move_dir,
		"slot 1 reads its OWN column of the stream, not slot 0's")
	# The D3 LIFETIME contract holds for a replay too: a FRESH value object per sample(), never
	# the retained instance — so nothing downstream can mutate the record by holding the intent.
	assert_false(got == loud, "sample() returns a FRESH InputIntent, never the recorded instance")


# ---------------------------------------------------------------- AC 3

## AC 3: the seed is captured EXACTLY ONCE, at match start, from the SAME value that reaches
## MatchParams. PARAMETERISED over two distinct seeds so the assertion cannot pass against a
## hardcoded constant, and the two runs are asserted to disagree so the parameterisation is real.
func test_the_seed_channel_captures_the_value_that_reaches_match_params() -> void:
	var captured: Array[int] = []
	for seed_value: int in [1337, 20260804]:
		var rec := IntentRecorder.new()
		assert_false(rec.seed_captured(), "a fresh record carries no seed")
		var params := MatchParams.new(seed_value)
		rec.capture_seed(params.seed_value)
		var ms := MatchState.new(params)
		assert_true(rec.seed_captured(), "the seed channel is filled at match start")
		assert_eq(rec.replay_seed(), params.seed_value,
			"the captured seed IS the value that reached MatchParams — never a second read")
		assert_eq(MatchState.new(MatchParams.new(rec.replay_seed())).to_snapshot()["rng_state"],
			ms.to_snapshot()["rng_state"],
			"a match rebuilt from the recorded seed starts on the same RNG state")
		captured.append(rec.replay_seed())
	assert_eq(captured, [1337, 20260804],
		"the two parameterised runs captured DIFFERENT seeds — no hardcoded constant satisfies both")


# ---------------------------------------------------------------- AC 5 / AC 6

## AC 5: the composition is the exact Array[StringName] passed to inject_deck, non-empty, and the
## record carries the INJECTION ORDER relative to the cost map. AC 6: replay applies that order,
## and a record whose order is INVERTED fails to replay — because inject_card_costs()'s totality
## check reads _deck_contents, so costs-before-deck validates against an empty composition and
## passes vacuously, leaving the check present and meaningless.
func test_content_channels_carry_the_composition_the_costs_and_their_injection_order() -> void:
	var rec := _match_start_record()
	assert_eq(rec.replay_deck_contents(), DECK_IDS,
		"the recorded composition is the exact array handed to inject_deck")
	assert_false(rec.replay_deck_contents().is_empty(), "and it is non-empty")
	assert_eq(rec.replay_card_costs().keys(), DECK_IDS,
		"the cost map is total over that composition on the record too")
	assert_eq(rec.content_order(), IntentRecorder.SOUND_CONTENT_ORDER,
		"the record carries the ORDER, captured from the calls rather than assumed")

	# Applied in the recorded order, the replayed match deals exactly as a live one does.
	var replayed := _bare_match()
	assert_true(rec.replay_inject_content(replayed), "the sound order replays")
	replayed.advance(_resting_pair())
	assert_eq(replayed.p1.hand.size(), 2, "the replayed content dealt: hand_size from the record's balance")
	assert_eq(replayed.p1.deck.size(), DECK_IDS.size() - 2, "...and the pile is the rest of the composition")

	# INVERTED: costs captured before the composition. The record is refused and injects NOTHING —
	# the refusal is total, not partial, so a replay cannot proceed on half a content set.
	var inverted := IntentRecorder.new()
	inverted.capture_seed(1337)
	inverted.capture_apply_balance(_config())
	inverted.capture_inject_feature_flags(FeatureFlags.new())
	inverted.capture_inject_card_costs(_costs())
	inverted.capture_inject_deck(DECK_IDS)
	assert_eq(inverted.content_order(),
		[IntentRecorder.CHANNEL_COSTS, IntentRecorder.CHANNEL_DECK],
		"sanity: the inverted record really did capture the two channels the other way round")
	var broken := _bare_match()
	assert_false(inverted.replay_inject_content(broken),
		"a record whose injection order is inverted FAILS to replay")
	broken.advance(_resting_pair())
	assert_eq(broken.p1.hand.size(), 0, "...and injected nothing: no composition reached state")
	assert_eq(broken.p1.deck.size(), 0, "...nor any pile")


## AC 6: the cost map is NON-OPTIONAL. A record carrying a composition but no cost map is
## MALFORMED and is rejected at the capture seam by Invariant.check — the inject_deck /
## push_contact precedent. The guard's CONDITION is a public predicate so it can be proven in
## both directions here (an Invariant.check cannot be triggered from a test without polluting the
## suite's output with a genuine engine error), and the wiring of that predicate INTO the seam is
## asserted by source scan directly below.
func test_a_record_missing_any_match_start_channel_is_malformed() -> void:
	assert_true(_match_start_record().has_complete_match_start(),
		"a fully captured match start is complete")
	assert_eq(_match_start_record().missing_match_start_channels(), [],
		"...and names nothing missing")
	# Each of the five match-start channels, omitted one at a time.
	var expected := {
		"seed": "seed",
		"balance": "reload event #0",
		"flags": "feature flags",
		"deck": "deck composition",
		"costs": "cast costs",
	}
	for omitted: String in expected:
		var rec := _match_start_record(omitted)
		assert_false(rec.has_complete_match_start(),
			"a record with no %s is malformed" % omitted)
		assert_eq(rec.missing_match_start_channels(), [expected[omitted]],
			"...and says exactly which channel is missing")


func test_the_match_start_completeness_guard_is_wired_at_the_capture_seam() -> void:
	# NON-VACUITY for the predicate proven above: it only guards anything if capture_advance
	# actually checks it. A guard that exists but is never called is the failure this catches.
	var wired := 0
	for line in _code_lines(RECORDER):
		if line.contains("Invariant.check(has_complete_match_start()"):
			wired += 1
	assert_eq(wired, 1,
		"intent_recorder.gd must reject a malformed record AT THE CAPTURE SEAM with "
		+ "Invariant.check(has_complete_match_start(), ...) — the inject_deck / push_contact precedent")


# ---------------------------------------------------------------- AC 7

## AC 7 (`3-0c/R3`): injected FeatureFlags ARE a channel — recorded once at match start, replayed
## from the record, and FeatureFlagsService never read. CAPTURE IS NOT RUNTIME MUTATION, and this
## is the half of the AC that says so: flags stay load-once and runtime-immutable.
func test_flags_are_a_capture_channel_replayed_by_value() -> void:
	var authored := FeatureFlags.new()
	authored.melee_mana_generation = true
	authored.unblockable = true
	var rec := IntentRecorder.new()
	rec.capture_inject_feature_flags(authored)
	var replayed := rec.replay_feature_flags()
	assert_true(replayed.melee_mana_generation, "the recorded flag values come back")
	assert_true(replayed.unblockable, "...all of them, not just the one E1 reads")
	assert_false(replayed == authored,
		"the replayed flags are a FRESH resource, never the recorded handle")
	# BY VALUE is the whole point: a replay against a DIFFERENT flags resource diverges silently,
	# so mutating the authored resource after the capture must not reach the record.
	authored.melee_mana_generation = false
	assert_true(rec.replay_feature_flags().melee_mana_generation,
		"a post-capture edit to the authored resource cannot reach back into the record")


func test_feature_flags_service_still_has_no_reload_path() -> void:
	var offenders: Array[String] = []
	for line in _code_lines(FLAGS_SERVICE):
		if line.contains("func reload"):
			offenders.append(line.strip_edges())
	assert_eq(offenders.size(), 0,
		"FeatureFlagsService must still have NO reload() method — load-once is structural "
		+ "(there is nothing to call), not a convention nobody has broken yet: %s" % ", ".join(offenders))
	var callers: Array[String] = []
	for path in _gd_files("res://src/"):
		var n := 0
		for line in _code_lines(path):
			n += 1
			if line.contains("FeatureFlagsService.reload"):
				callers.append("%s:%d" % [path, n])
	assert_eq(callers.size(), 0, "and no reload PATH anywhere in src/: %s" % ", ".join(callers))
	# NON-VACUITY: the token must be real. match_runner.gd is the ONE reader of the service, so a
	# rename there that silently empties this scan fails HERE instead of passing quietly.
	var service_hits := 0
	for line in _code_lines(RUNNER):
		if line.contains("FeatureFlagsService"):
			service_hits += 1
	assert_true(service_hits > 0,
		"match_runner.gd must still name FeatureFlagsService — otherwise this guard is vacuous")


func test_no_recorder_behaviour_is_gated_behind_a_flag_or_a_live_service() -> void:
	# The other half of AC 7: capture is not runtime mutation, so nothing in the record/replay
	# pair may branch on a flag — nor reach any load-once/hot-reloadable SERVICE, which is what
	# would let a replay consult something that can change out from under the recording.
	var banned: Array[String] = [
		"FeatureFlagsService", "BalanceConfigService", "CardDatabase", "ResourceLoader",
	]
	for prop: Dictionary in FeatureFlags.new().get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			banned.append(String(prop["name"]))
	var offenders: Array[String] = []
	for path in [RECORDER, REPLAY_CONTROLLER]:
		var n := 0
		for line in _code_lines(path):
			n += 1
			for token in banned:
				if line.contains(token):
					offenders.append("%s:%d [%s]" % [path, n, token])
	assert_eq(offenders.size(), 0,
		"the recorder / replay controller must name no flag and no live service — capture is not "
		+ "runtime mutation, and a replay that consulted a service is not a replay: %s"
				% ", ".join(offenders))
	# NON-VACUITY, the pattern half: these exact tokens are what the scan exists to catch.
	assert_true(banned.has("melee_mana_generation"),
		"the flag field names really were read off FeatureFlags (an empty ban list is vacuous)")
	assert_true("\t\tvar c := BalanceConfigService.get_config()".contains(banned[1]),
		"the service tokens match the form they exist to catch")


# ---------------------------------------------------------------- fixtures

## The record's balance — built IN-TEST, never loaded from data/balance/*.tres, the
## test_determinism.gd _golden_config discipline. Sized so the deal is legible against a
## three-card composition.
func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = 5.0
	c.max_stamina = 30.0
	c.max_mana = 50.0
	c.deck_size = DECK_IDS.size()
	c.hand_size = 2
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 3.0 / 60.0
	c.attack_recovery_seconds = 3.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	return c


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in DECK_IDS:
		var c := CardCastCondition.new()
		c.mana_cost = 4.0
		out[id] = c
	return out


func _bare_match() -> MatchState:
	var ms := MatchState.new(MatchParams.new(1337))
	ms.apply_balance(_config())
	ms.inject_feature_flags(FeatureFlags.new())
	return ms


func _resting_pair() -> Array[InputIntent]:
	var pair: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	return pair


## A record with every match-start channel captured, in the live order. `omit` drops exactly one
## channel by name, which is how the completeness guard is proven falling per channel.
func _match_start_record(omit := "") -> IntentRecorder:
	var rec := IntentRecorder.new()
	if omit != "seed":
		rec.capture_seed(1337)
	if omit != "balance":
		rec.capture_apply_balance(_config())
	if omit != "flags":
		rec.capture_inject_feature_flags(FeatureFlags.new())
	if omit != "deck":
		rec.capture_inject_deck(DECK_IDS)
	if omit != "costs":
		rec.capture_inject_card_costs(_costs())
	return rec


# ---------------------------------------------------------------- source scanning

## name -> {"has_params": bool}. A public method whose parameter list is non-empty carries data
## INWARD. _init is kept (it is how the seed arrives); every other underscore-prefixed member is
## private and outside the public intake surface by definition.
func _match_state_public_surface() -> Dictionary:
	var out: Dictionary = {}
	var re := RegEx.create_from_string("^func\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\((.*)$")
	for line in _code_lines(MATCH_STATE):
		var m := re.search(line)
		if m == null:
			continue
		var name := m.get_string(1)
		if name.begins_with("_") and name != SEED_INTAKE:
			continue
		out[name] = {"has_params": not m.get_string(2).begins_with(")")}
	return out


func _recorder_method_names() -> Dictionary:
	var out: Dictionary = {}
	var script: GDScript = load(RECORDER)
	for m: Dictionary in script.get_script_method_list():
		out[String(m["name"])] = true
	return out


func _gd_files(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(root + f)
	for d in dir.get_directories():
		out.append_array(_gd_files(root + d + "/"))
	return out


# Code portion of each line (everything before the first '#'), so comments can't false-positive.
func _code_lines(path: String) -> Array[String]:
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
	return out
