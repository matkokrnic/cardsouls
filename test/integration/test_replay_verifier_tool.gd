extends SceneTree

## Story 3-0d (`3-0d/R24`, closing `3-0d/N5`): THE AC 8 VERIFIER IS RUN, AS A SUBPROCESS, BY THE
## SUITE — so AC 8 is self-verifying instead of operator-only.
##
## THE BLIND SPOT THIS CLOSES. `test/tools/replay_file.gd` is deliberately NOT globbed by
## `run_all.sh` (its input is a file an operator produced by playing), so nothing in the suite ever
## loaded it. The post-review pass discovered what that costs: a parse error — a shadowed `result`
## local introduced by the `3-0d/R17` extraction — shipped and was found only because a human ran
## the tool by hand. The suite structurally could not see it.
##
## THE OBVIOUS GUARD IS VACUOUS, WHICH IS WHY IT IS NOT THE ONE USED. `load("res://test/tools/
## replay_file.gd")` returns a NON-NULL GDScript for a file that does not compile; a test asserting
## non-null passes on a broken tool. `can_instantiate()` is the working discriminator and would
## have caught that parse error — but it proves only that the file COMPILES, which is a strictly
## weaker claim than the one AC 8 makes.
##
## SO THIS RUNS THE TOOL FOR REAL, THE WAY THE SMOKE RUNS IT: a fixture record is written through
## `RecordFile` (the same writer the SAVE control uses), the verifier is launched as a SUBPROCESS
## in a fresh headless Godot, and its stdout is read back. Asserted:
##
##   [IT RUNS] exit 0 and `RESULT: PASS` — which subsumes the parse-error case, since a file that
##     does not compile prints no RESULT line at all.
##   [IT ACCEPTS THE RECORD] the record this suite wrote is loaded, found structurally complete,
##     and replayed to completion — the tool's whole job.
##   [IT IS DETERMINISTIC] TWO invocations on the SAME file print the SAME CanonicalHash. That is
##     AC 8's actual claim, stated exactly (`3-0d/R18`: the hash is a function of the run that
##     PRODUCED the record, never a repo constant, so it is compared run-to-run and never to a
##     literal written down anywhere).
##   [IT HASHES THE REPLAY, AND NOT SOMETHING ELSE] a SECOND, DIFFERENT record produces a DIFFERENT
##     hash. Added at `3-0d/R25`, closing a hole in the assertion above: run-to-run equality is
##     satisfied by ANY deterministic function of nothing in particular, so a verifier that hashed
##     a FRESH `MatchState` instead of the replayed one passed every check in this file. The two
##     fixtures share seed, balance, flags, deck and costs and differ ONLY in the recorded INTENTS
##     — which is deliberate: it is exactly the difference a wrongly-hashed object cannot see, so
##     "the hash depends on the replay" is what this measures rather than "the hash depends on the
##     file". PROVEN BY MUTATION at `3-0d/R25` — see the story's Debug Log References.
##   [IT REFUSES] a corrupted file is refused with a reason and a NONZERO exit — so the PASS above
##     is a verdict the tool can actually withhold, not a line it always prints.
##
## Behaviour, not syntax: this guards what the tool DOES. It is the mechanism AC 8 lacked.
##
## Run: godot --headless --path . --script res://test/integration/test_replay_verifier_tool.gd

const FIXTURE_PATH := "user://test_3_0d_verifier_fixture.rec"
## `3-0d/R25`: the SECOND fixture, identical to the first in every injected channel and different
## only in its recorded intents — see [IT HASHES THE REPLAY] above for why that is the axis.
const FIXTURE_B_PATH := "user://test_3_0d_verifier_fixture_b.rec"
const CORRUPT_PATH := "user://test_3_0d_verifier_corrupt.rec"
const TOOL := "res://test/tools/replay_file.gd"

const SEED := 8675309
const TICKS := 12
const RELOAD_TICK := 5
const CONTACT_TICK := 7
const DECK_IDS: Array[StringName] = [&"verifier_card_0", &"verifier_card_1", &"verifier_card_2"]

## `3-0d/R25`: the two fixtures' ONLY difference. Opposite signs rather than a scaled magnitude, so
## P1 walks somewhere genuinely different and the divergence cannot be an accumulated rounding
## whisker. Both are non-zero, so neither record is a "player stood still" degenerate.
const MOVE_SCALE_A := 1.0
const MOVE_SCALE_B := -1.0

var _failures: Array[String] = []


func _initialize() -> void:
	_remove(FIXTURE_PATH)
	_remove(FIXTURE_B_PATH)
	_remove(CORRUPT_PATH)

	var record := _fixture_record(MOVE_SCALE_A)
	var write_error := RecordFile.save_record(record, FIXTURE_PATH)
	_check(write_error == "", "the fixture record was written through RecordFile: %s" % write_error)

	# [IT RUNS] / [IT ACCEPTS THE RECORD] — first invocation.
	var first := _run_verifier(FIXTURE_PATH)
	_check(first["exit"] == 0, "the verifier exited 0 (got %d)" % first["exit"])
	_check(first["text"].contains("RESULT: PASS"),
		"the verifier printed RESULT: PASS — a tool that does not COMPILE prints no RESULT line at "
		+ "all, which is how this subsumes the parse error the suite could not see. Output:\n%s"
				% first["text"])
	_check(first["text"].contains("replayed %d ticks to completion" % TICKS),
		"...having replayed the whole record (%d ticks)" % TICKS)
	var first_hash: String = first["hash"]
	_check(first_hash != "", "...and printed a CanonicalHash: `%s`" % first_hash)

	# [IT IS DETERMINISTIC] — second invocation, same file, fresh process.
	var second := _run_verifier(FIXTURE_PATH)
	_check(second["exit"] == 0, "the second invocation exited 0 (got %d)" % second["exit"])
	_check(second["text"].contains("RESULT: PASS"), "...and passed as well")
	_check(second["hash"] == first_hash,
		"TWO RUNS OF THE VERIFIER ON THE SAME FILE PRINT THE SAME HASH — AC 8's actual claim, "
		+ "measured run-to-run rather than against a literal (`3-0d/R18`): `%s` vs `%s`"
				% [first_hash, second["hash"]])

	# [IT HASHES THE REPLAY, AND NOT SOMETHING ELSE] — a DIFFERENT record, a DIFFERENT hash.
	var record_b := _fixture_record(MOVE_SCALE_B)
	var write_b_error := RecordFile.save_record(record_b, FIXTURE_B_PATH)
	_check(write_b_error == "", "the second fixture record was written: %s" % write_b_error)
	var other := _run_verifier(FIXTURE_B_PATH)
	_check(other["exit"] == 0, "the second fixture verified too (exit %d)" % other["exit"])
	var other_hash: String = other["hash"]
	_check(other_hash != "", "...and printed a CanonicalHash: `%s`" % other_hash)
	_check(other_hash != first_hash,
		"TWO RECORDS THAT DIFFER ONLY IN THEIR RECORDED INTENTS PRINT DIFFERENT HASHES — which is "
		+ "what makes the run-to-run equality above mean the hash came FROM THE REPLAY. A verifier "
		+ "hashing a fresh MatchState, or anything else not derived from the intents, satisfies "
		+ "equality and fails HERE (`3-0d/R25`). `%s` vs `%s`" % [first_hash, other_hash])

	# [IT REFUSES] — the PASS above is a verdict, not a constant.
	_write_corrupt_copy()
	var refused := _run_verifier(CORRUPT_PATH)
	_check(refused["exit"] != 0, "a corrupted record makes the verifier exit NONZERO (got %d)"
			% refused["exit"])
	_check(refused["text"].contains("REFUSED:"),
		"...saying REFUSED and why, rather than replaying it. Output:\n%s" % refused["text"])
	_check(not refused["text"].contains("RESULT: PASS"),
		"...and NOT printing PASS, which is what makes the PASS above load-bearing")

	_remove(FIXTURE_PATH)
	_remove(FIXTURE_B_PATH)
	_remove(CORRUPT_PATH)
	_finish(first_hash, other_hash)


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures.append(label)


## Launch the verifier in a FRESH headless Godot and capture its stdout. `OS.get_executable_path()`
## is the binary already running this suite, so the tool is exercised on the same engine build
## rather than on whatever happens to be on PATH.
func _run_verifier(path: String) -> Dictionary:
	var output: Array = []
	var exit := OS.execute(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", TOOL, "--", path,
	], output, true)
	var text := "\n".join(output)
	return {"exit": exit, "text": text, "hash": _hash_from(text)}


## The `CanonicalHash: <hex>` line's value, or "" if the tool never printed one.
func _hash_from(text: String) -> String:
	for line in text.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("CanonicalHash:"):
			return stripped.substr("CanonicalHash:".length()).strip_edges()
	return ""


## A record with every channel driven, built through the CAPTURE API in live order — the same
## discipline test/state/test_record_file.gd uses, so what the verifier reads is a record live play
## could have produced. Content and balance are IN-TEST LITERALS with opaque ids (golden isolation:
## a tuning pass moves neither this fixture nor the hash it produces).
##
## `3-0d/R25`: `move_scale` is the ONE axis the two fixtures differ on. Everything else — seed,
## balance, flags, deck, costs, camera bases, the contact fact, the tick count — is IDENTICAL by
## construction, so the hashes can only diverge through the REPLAYED INTENTS. That is the whole
## point: it is the difference a verifier hashing the wrong object is blind to.
func _fixture_record(move_scale: float) -> IntentRecorder:
	var record := IntentRecorder.new()
	record.capture_seed(SEED)
	record.capture_apply_balance(_config(7.0))
	record.capture_inject_feature_flags(_flags())
	record.capture_inject_deck(DECK_IDS)
	record.capture_inject_card_costs(_costs())
	record.capture_inject_card_effects(_effects())   # story 4-1: the third content channel
	record.capture_inject_card_colors(_colors())     # story 5-2: the fourth
	for t in range(1, TICKS + 1):
		if t == RELOAD_TICK:
			record.capture_apply_balance(_config(11.0))
		record.capture_set_camera_basis(0, Basis(Vector3.UP, deg_to_rad(90.0)))
		record.capture_set_camera_basis(1, Basis.IDENTITY)
		if t == CONTACT_TICK:
			record.capture_push_contact([0, -1], [1, -1], 0, Vector2(-1, 0), MatchState.CONTACT_STRIKE)
		record.capture_advance(_intents(t, move_scale))
	return record


func _intents(t: int, move_scale: float) -> Array[InputIntent]:
	var i1 := InputIntent.new()
	i1.move_dir = Vector2(t * 0.125, t * -0.0625) * move_scale
	i1.retarget_slot = 1
	i1.retarget_index = -1
	var i2 := InputIntent.new()
	i2.move_dir = Vector2(-1, 0)
	var out: Array[InputIntent] = [i1, i2]
	return out


## The fixture with one key removed — the `3-0d/R15` truncation path, which the verifier must
## report as REFUSED with a reason rather than replay.
func _write_corrupt_copy() -> void:
	var reader := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	var data: Dictionary = reader.get_var()
	reader.close()
	_check(data.erase("intents"), "the fixture carried `intents` before it was removed")
	var writer := FileAccess.open(CORRUPT_PATH, FileAccess.WRITE)
	writer.store_var(data)
	writer.close()


func _config(move_speed: float) -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = move_speed
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
	c.melee_hit_mana = 12.0
	c.deck_size = DECK_IDS.size()
	c.hand_size = 2
	c.block_damage_multiplier = 0.5
	c.deflect_window_seconds = 3.0 / 60.0
	c.block_facing_arc_degrees = 180.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	return f


## Story 4-1 (`4-1/R1`): the effect map for this fixture's composition, `_costs()`'s twin.
func _effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id in DECK_IDS:
		var e := CardEffect.new()
		e.effect_id = StringName("summon_%s" % id)
		out[id] = e
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in DECK_IDS:
		var c := CardCastCondition.new()
		c.mana_cost = 5.0
		out[id] = c
	return out


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish(measured_hash: String, other_hash: String) -> void:
	print("verifier tool: two subprocess runs agreed on CanonicalHash %s (this fixture's — never a "
			% measured_hash + "repo constant, `3-0d/R18`)")
	print("verifier tool: a second record differing ONLY in intents hashed %s — different, which is "
			% other_hash + "what makes the agreement above a property of the REPLAY (`3-0d/R25`)")
	for f in _failures:
		print("FAILED: " + f)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)


## Story 5-2 (`5-2/R1`): the FOURTH content channel's fixture half. Plain enum values, so unlike
## `_costs()` and `_effects()` this builds no Resource.
func _colors() -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	for i in DECK_IDS.size():
		out[DECK_IDS[i]] = Enums.CardColor.RED if i % 2 == 0 else Enums.CardColor.BLUE
	return out
