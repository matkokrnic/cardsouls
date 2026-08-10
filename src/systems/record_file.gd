class_name RecordFile
extends RefCounted

## Story 3-0d (X5, AC 4 / AC 5): `user://` PERSISTENCE FOR AN IntentRecorder RECORD — the half
## `3-0c` deliberately did not ship ("Serialisation, `user://` persistence and the operator
## surface are `3-0d`'s", intent_recorder.gd:32-33).
##
## A SIBLING, NOT A RECORDER METHOD, AND THAT IS STRUCTURAL. IntentRecorder is CLOCK-FREE AND
## CONTENT-BLIND BY CONSTRUCTION — no `user://` path, no ResourceLoader, no service — and that
## property is machine-checked by test_intent_recorder.gd::
## test_no_recorder_behaviour_is_gated_behind_a_flag_or_a_live_service. File I/O therefore lands
## HERE. The recorder gains no new capture channel (AC 3) and no knowledge that files exist.
##
## IT TOUCHES ONLY THE RECORDER'S PUBLIC API — the replay-side reads to serialise, the capture
## channels to rebuild. That is the `_without_contacts` pattern of
## test/integration/test_replay_contacts.gd generalised to every channel, and it is what makes a
## loaded record a GENUINE record: it was built by the same capture calls a live match makes, so
## nothing can round-trip into a shape live play could not have produced.
##
## THE FORMAT IS DELIBERATELY UNPINNED EXCEPT FOR ITS VERSION INT (`3-0d/R7`). Byte layout, key
## naming and extension are free to change under a story that needs them; what IS pinned is the
## ROUND TRIP (AC 4) and FORMAT_VERSION with a REFUSAL CARRYING A REASON when it does not match
## (AC 5) — which is what makes schema evolution safe without freezing a shape that has exactly
## one consumer today.
##
## EVERY REFUSAL CARRIES A REASON ~~, AND THAT IS NOW TRUE OF EVERY PATH~~ (`3-0d/R15`). **THE
## STRUCK CLAUSE IS FALSE AND IS RETIRED AT `3-0d/R25`** — five inputs still refuse with an EMPTY
## reason; see THE RESIDUE at the end of this block, which is now where this class's actual
## boundary is written down. The review of
## this story found the one path where it was not: a file carrying a matching version but a
## TRUNCATED body reached the rebuild, failed inside it, and came back as
## `{"record": null, "error": ""}` — a refusal with an EMPTY reason, which a caller testing
## `error != ""` reads as SUCCESS. The required keys are validated BEFORE anything is rebuilt.
##
## ...AND THAT FIX WAS ITSELF INCOMPLETE, CLOSED AT `3-0d/R21`. Presence is not enough:
## `Dictionary.has()` is TRUE for a key whose value is `null` and says nothing about type, so three
## more inputs still reached the rebuild and still came back with an empty reason — required keys
## present but carrying WRONG TYPES, `null` under `reload_events`, `null` under `intents`. Each
## required key's TYPE is now validated before the rebuild, and the refusal names the key and what
## was found in it. See REQUIRED_KEYS, which is a key -> type map for exactly this reason.
##
## THE RESIDUE, STATED RATHER THAN PRETENDED AWAY (`3-0d/R25`). Twice now this docstring has
## claimed TOTALITY over refusal reasons and twice a narrower set of files has falsified it. It
## stops claiming totality. **WHAT THE CODE CARRIES:** each required key's TOP-LEVEL TYPE is
## validated before the rebuild (REQUIRED_KEYS, a key -> type map), and a file failing that is
## refused with a reason naming the key and what was found in it. **WHAT IT DOES NOT CARRY:**
## NESTED and CROSS-KEY consistency. Element types INSIDE the required containers, and array
## lengths measured AGAINST `tick_count`, are not validated at all — such a file still reaches
## `_from_dictionary()`, still dies inside it, and still comes back as
## `{"record": null, "error": ""}`. FIVE MEASURED at `3-0d/R25`, every one returning an empty
## reason: `intents` as an Array of DICTIONARIES; `intents` SHORTER than `tick_count`;
## `camera_pushes` values that are INTS; `contacts` values that are ARRAYS OF INTS; `tick_count`
## INFLATED past the intents array.
##
## NESTED VALIDATION IS DELIBERATELY NOT BUILT (`3-0d/R25`), and that is the ruling rather than an
## omission: it is a third round of the same widening for marginal benefit on a format with
## exactly one writer, and the lesson `3-0d/R20` already paid for is that the boundary gets WRITTEN
## DOWN instead of chased. **CONSEQUENCE FOR CALLERS, stated once so it is not re-derived:** test
## `result["record"] == null`, NEVER `error != ""` — the reason is a message for a human, not the
## verdict. MEASURED at `3-0d/R25` — all three shipped callers already do: `replay_file.gd:43` and
## `test_record_save_control.gd:191` branch on `result["record"] == null`, and
## `test/state/test_record_file.gd` asserts the record before it reads any reason.
##
## RECORDS GO UNDER `user://`, AND THE API SAYS SO (`3-0d/R16`), BY NORMALISATION (`3-0d/R22`).
## That claim used to be true only of `path_for()`; `save_record` accepted any path and would
## happily write into the repo tree. The first fix was a bare `begins_with("user://")`, which
## `user://../../…` satisfies while escaping the directory entirely — proven by writing a record
## into the project root. The path is now RESOLVED and required to land inside the `user://`
## directory; see `_outside_user_directory`.
##
## BINARY `store_var`, NOT JSON. The stream carries Basis, Vector2 and StringName values and the
## int/float distinction, none of which JSON round-trips. MEASURED on Godot 4.6.3 at this pass:
## store_var/get_var returns Basis and Vector2 equal, StringName keys still TYPE_STRING_NAME, and
## ints still ints. A text format would have needed a per-type re-parse for no gain — the file is
## an operator artefact handed to the AC 8 verifier, never something a human edits.

## AC 5: bump this the moment the shape below changes in a way an older file cannot satisfy. A
## file carrying any other value is REFUSED with a reason, never replayed on a guess.
## STORY 4-1 (`4-1/R1`): BUMPED 1 -> 2. The shape below gained a required `effects` key (the third
## content channel), and a v1 file cannot satisfy it -- it carries no effects at all, so replaying
## one would summon nothing where the recorded match summoned units. That is exactly the "an older
## file cannot satisfy it" condition this constant exists for.
##
## NO MIGRATION SHIM IS BUILT, AND THAT IS THE RULING RATHER THAN AN OMISSION (`4-1/R1`). A v1
## record is REFUSED WITH A REASON by the version check in load_record(), which is this class's
## own documented contract for every non-matching version. Records are DEBUG ARTEFACTS with exactly
## one writer; a shim that back-filled an empty effects map would be speculative machinery whose
## only output is a replay that silently diverges from the match it claims to reproduce.
## STORY 4-3a (`4-3a/R10`) BUMPS THIS TO 3, and the reason is a payload SHAPE change rather than a
## new channel. The contact fact's target widened from a bare slot to a `[slot, index]` ADDRESS
## (AC 3), so the recorded contact row grew from four positional elements to five. A v2 file carries
## no target-index element; rebuilding one by assuming -1 would silently replay a UNIT hit as a HERO
## hit -- a replay that diverges from the match it claims to reproduce, which is exactly what the
## version check exists to refuse. No migration shim, for the `4-1/R1` reason directly above: a v2
## record is REFUSED WITH A REASON, and that refusal is this class's documented contract.
##
## The channel SET is unchanged -- no new capture channel, `push_contact` still the sole intake --
## so REQUIRED_KEYS below does not move and `_resource_values` is untouched.
const FORMAT_VERSION := 3

## AC 7: the `user://` naming the SAVE control writes to. INDEXED rather than timestamped, and
## that is deliberate on both sides: the index makes the path a test can NAME in advance
## (`path_for(1)`), and two presses leave two files side by side, so "the second save is longer
## than the first" is directly observable rather than a remembered file size. **`3-0d/R30`: THAT
## GUARANTEE USED TO HOLD ONLY WITHIN ONE SESSION**, because the caller's own index started at 0
## every session and `path_for` alone names a path without checking whether it is occupied — a
## fresh session's first SAVE silently overwrote whatever a PRIOR session had already written at
## `path_for(1)`. See `first_free_index`, which is what makes the guarantee hold ACROSS sessions
## too, by asking the filesystem rather than trusting a counter that has no memory of a prior run.
const PATH_PREFIX := "user://cardsouls_record_"
const PATH_SUFFIX := ".rec"

## AC 5 / `3-0d/R15`: the keys `_to_dictionary` writes BESIDE the version, and therefore the keys
## `_from_dictionary` may read. Validated BEFORE any rebuild so a truncated or foreign file is
## REFUSED WITH A REASON NAMING WHAT IS MISSING, instead of dying inside the rebuild and returning
## a null record with an EMPTY error — which a caller testing `error != ""` reads as SUCCESS, the
## exact contradiction of this class's own documented contract that the review found.
##
## `format_version` is deliberately NOT a member: it is validated FIRST and on its own, because
## the version is what decides which key set is even expected. A future version 2 is free to carry
## a different set; it is refused by the version check long before it reaches here.
##
## DERIVED, NOT TRANSCRIBED: test_record_file.gd asserts this key set equals the key set an actual
## saved file carries minus `format_version`, so the two cannot drift apart.
##
## KEY -> EXPECTED TYPE, NOT A BARE KEY LIST (`3-0d/R21`). The presence check alone was not enough,
## and the reason is a property of `Dictionary.has()` rather than an oversight: **`has(key)` is TRUE
## for a key whose value is `null`, and says nothing whatever about type.** Three inputs therefore
## reached `_from_dictionary()` and came back as `{"record": null, "error": ""}` — the exact
## empty-reason refusal `3-0d/R15` was raised to close, still open on a narrower set of files:
## required keys present but carrying the WRONG TYPES, `null` under `reload_events`, and `null`
## under `intents`. Each key's type is checked here, before anything is rebuilt, and the refusal
## names the key and what was found in it.
const REQUIRED_KEYS: Dictionary[String, int] = {
	"seed": TYPE_INT,
	"reload_events": TYPE_ARRAY,
	"flags": TYPE_DICTIONARY,
	"content_order": TYPE_ARRAY,
	"deck": TYPE_ARRAY,
	"costs": TYPE_DICTIONARY,
	"tick_count": TYPE_INT,
	"intents": TYPE_ARRAY,
	"camera_pushes": TYPE_DICTIONARY,
	"contacts": TYPE_DICTIONARY,
	# Story 4-1 (`4-1/R1`): the third content channel, required from FORMAT_VERSION 2 onward. Its
	# arrival IS the version bump -- a v1 file lacks this key, and is refused by the version check
	# long before this map is consulted.
	"effects": TYPE_DICTIONARY,
}

## `3-0d/R16`: the ONE thing a save path must be. The class's own docstring and AC 7 both assert
## records go to `user://`; before this guard that was true only of `path_for()`, and the API
## accepted any path — proven at the review by writing a record into the repo root. Now the API
## carries the claim.
const REQUIRED_PATH_PREFIX := "user://"


static func path_for(index: int) -> String:
	return "%s%d%s" % [PATH_PREFIX, index, PATH_SUFFIX]


## `3-0d/R30`: THE INDEX A CALLER SHOULD ACTUALLY WRITE TO, NOT MERELY NAME. `path_for(index)`
## alone names a path; it says nothing about whether that path is already occupied, and a caller
## that increments its own counter from 0 EVERY SESSION collides with whatever a PRIOR session
## already wrote at `path_for(1)` — **this happened live, to the operator**: a new session's first
## SAVE wrote `cardsouls_record_1.rec` again and silently destroyed the only recording in which
## the contact channel had ever been exercised live. Returns the first index >= `start` whose
## `path_for(index)` does not already exist on disk, so a caller that always asks before writing
## can never clobber a file that is there — not within a session, not across sessions, not after a
## crash, because the answer comes from the FILESYSTEM, never from in-memory counter state.
static func first_free_index(start: int) -> int:
	var index := start
	while FileAccess.file_exists(path_for(index)):
		index += 1
	return index


## Writes `record` to `path`. Returns "" on success, or the REASON it was refused — never an
## Invariant.check: a save is an operator action on whatever state the session happens to be in,
## and the two ways it can legitimately have nothing to write (no record, or a replay's
## deliberately empty tap) are conditions to report, not programming errors.
static func save_record(record: IntentRecorder, path: String) -> String:
	if record == null:
		return "there is no record to save"
	var outside := _outside_user_directory(path)
	if outside != "":
		return outside
	if not record.has_complete_match_start():
		return ("refusing to save a malformed record — missing %s"
				% ", ".join(record.missing_match_start_channels()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "cannot open %s for writing (error %d)" % [path, FileAccess.get_open_error()]
	file.store_var(_to_dictionary(record))
	file.close()
	return ""


## Loads a record from `path`. Returns {"record": IntentRecorder, "error": ""} on success, or
## {"record": null, "error": <reason>} — the REFUSAL half of AC 5. A Dictionary result rather
## than a null-plus-last_error() pair so the reason travels WITH the failure and the loader keeps
## no static state between calls.
static func load_record(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _refused("no record file at %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _refused("cannot open %s for reading (error %d)" % [path, FileAccess.get_open_error()])
	var raw: Variant = file.get_var()
	file.close()
	if typeof(raw) != TYPE_DICTIONARY:
		return _refused("%s is not a CardSouls record (expected a Dictionary, found %s)"
				% [path, type_string(typeof(raw))])
	var data: Dictionary = raw
	if not data.has("format_version"):
		return _refused("%s carries no format version — it is not a CardSouls record" % path)
	var version := int(data["format_version"])
	if version != FORMAT_VERSION:
		return _refused(("record format version %d does not match this build's %d — refusing to "
				+ "replay %s rather than guessing at a shape it may not carry")
						% [version, FORMAT_VERSION, path])
	# `3-0d/R15`: EVERY key the rebuild reads is checked BEFORE the rebuild runs. A file carrying a
	# matching version but a truncated body used to reach _from_dictionary(), fail inside it, and
	# come back as {"record": null, "error": ""} — a refusal with NO reason, which a caller testing
	# `error != ""` reads as success. A refusal always carries its reason now, naming the keys.
	var missing: Array[String] = []
	for key in REQUIRED_KEYS:
		if not data.has(key):
			missing.append(key)
	if not missing.is_empty():
		return _refused(("%s carries format version %d but is missing %s — it is truncated or was "
				+ "not written by this class") % [path, version, ", ".join(missing)])
	# `3-0d/R21`: PRESENCE IS NOT ENOUGH, and the gap is `has()`'s own semantics —
	# it is TRUE for a key whose value is `null` and says nothing about type. A file with the right
	# keys carrying the wrong values got past the loop above, died inside the rebuild, and came back
	# as a refusal with an EMPTY error, which is the very thing `3-0d/R15` was raised to close.
	var wrong: Array[String] = []
	for key in REQUIRED_KEYS:
		var found := typeof(data[key])
		if found != REQUIRED_KEYS[key]:
			wrong.append("%s (expected %s, found %s)"
					% [key, type_string(REQUIRED_KEYS[key]), type_string(found)])
	if not wrong.is_empty():
		return _refused(("%s carries format version %d but %s — it was not written by this class, "
				+ "or was written by a build whose shape this one cannot read")
						% [path, version, ", ".join(wrong)])
	return {"record": _from_dictionary(data), "error": ""}


static func _refused(reason: String) -> Dictionary:
	return {"record": null, "error": reason}


## `3-0d/R22`: THE SAVE-PATH GUARD, BY NORMALISATION RATHER THAN BY PREFIX. Returns "" if `path`
## lands inside the `user://` directory, or the REASON it does not.
##
## The prefix test this replaces was `path.begins_with("user://")` and nothing else, which a
## `user://../../…` path satisfies while writing wherever it likes — MEASURED, not theorised:
## `user://../../escape.rec` globalises to `…/Roaming/Godot/escape.rec`, two directories above the
## app's user data, and the review had already used exactly that shape to drop a record in the
## project root. A prefix test on a string that can contain `..` is not a containment test.
##
## So the path is RESOLVED — globalised to a native path, then `simplify_path()`d, which is what
## collapses `..` — and required to sit under the equally-resolved user root. The trailing "/" on
## the comparison is load-bearing and is its own measured trap: `user://../CardSoulsEvil/x.rec`
## resolves to `…/app_userdata/CardSoulsEvil/x.rec`, which HAS `…/app_userdata/CardSouls` as a
## string prefix and is a different directory. Comparing against the root plus its separator is
## what refuses it.
static func _outside_user_directory(path: String) -> String:
	var user_root := ProjectSettings.globalize_path(REQUIRED_PATH_PREFIX).simplify_path()
	var resolved := ProjectSettings.globalize_path(path).simplify_path()
	if resolved.begins_with(user_root + "/"):
		return ""
	return ("refusing to write %s — it resolves to %s, which is not inside the %s directory (%s). "
			+ "Records go under %s, never into the project tree (`3-0d/R16`, normalised at "
			+ "`3-0d/R22`); use RecordFile.path_for()") % [
					path, resolved, REQUIRED_PATH_PREFIX, user_root, REQUIRED_PATH_PREFIX]


# ---------------------------------------------------------------- serialise

static func _to_dictionary(record: IntentRecorder) -> Dictionary:
	var reload_events: Array = []
	for index in record.reload_event_count():
		reload_events.append({
			"tick": record.reload_event_tick(index),
			"values": _resource_values(record.replay_balance_config(index)),
		})
	var costs: Dictionary = {}
	var recorded_costs := record.replay_card_costs()
	for id: StringName in recorded_costs:
		costs[id] = _resource_values(recorded_costs[id])
	# Story 4-1 (`4-1/R1`): the third content channel, serialised through the recorder's PUBLIC
	# replay-side read exactly as the costs directly above are -- this class touches only that API,
	# which is what makes a loaded record a genuine one.
	var effects: Dictionary = {}
	var recorded_effects := record.replay_card_effects()
	for id: StringName in recorded_effects:
		effects[id] = _resource_values(recorded_effects[id])
	var intents: Array = []
	var camera_pushes: Dictionary = {}
	var contacts: Dictionary = {}
	for tick in range(1, record.tick_count() + 1):
		var pair: Array = []
		for intent: InputIntent in record.intents_at(tick):
			pair.append(_intent_values(intent))
		intents.append(pair)
		var pushes := record.camera_pushes_at(tick)
		if not pushes.is_empty():
			camera_pushes[tick] = pushes
		var facts := record.contacts_at(tick)
		if not facts.is_empty():
			contacts[tick] = facts
	return {
		"format_version": FORMAT_VERSION,
		"seed": record.replay_seed(),
		"reload_events": reload_events,
		"flags": _resource_values(record.replay_feature_flags()),
		"content_order": record.content_order(),
		"deck": record.replay_deck_contents(),
		"costs": costs,
		"effects": effects,
		"tick_count": record.tick_count(),
		"intents": intents,
		"camera_pushes": camera_pushes,
		"contacts": contacts,
	}


## All EIGHT InputIntent fields, verbatim — written as explicit field reads for the same reason
## IntentRecorder.copy_intent is (intent_recorder.gd:325-327): a ninth field leaves this visibly
## incomplete instead of silently narrowing what survives a save.
static func _intent_values(intent: InputIntent) -> Dictionary:
	return {
		"move_dir": intent.move_dir,
		"aim": intent.aim,
		"pressed": intent.pressed.duplicate(),
		"held": intent.held.duplicate(),
		"debug_reset": intent.debug_reset,
		"card_slot": intent.card_slot,
		"card_mode": int(intent.card_mode),
		"card_commit": intent.card_commit,
	}


## Every SCRIPT-DECLARED property of a Resource, by value — the recorder's own by-value discipline
## (intent_recorder.gd:345-356) applied on the way to disk, so a record on disk carries numbers
## and never a path back to an authored resource that can be re-tuned under it.
static func _resource_values(res: Resource) -> Dictionary:
	var out: Dictionary = {}
	for prop: Dictionary in res.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var value: Variant = res.get(prop["name"])
		if value is Dictionary or value is Array:
			value = value.duplicate(true)
		out[prop["name"]] = value
	return out


# ---------------------------------------------------------------- rebuild

## THE REBUILD RUNS THROUGH THE CAPTURE API IN LIVE ORDER, which is what makes reload-event TICKS
## come back right: capture_apply_balance() stamps an event with the recorder's CURRENT tick, so
## an event recorded after N ticks has to be re-captured after N capture_advance() calls. Match
## start is every tick-0 event; each later event is re-captured immediately after its tick.
static func _from_dictionary(data: Dictionary) -> IntentRecorder:
	var record := IntentRecorder.new()
	var reload_events: Array = data["reload_events"]
	record.capture_seed(int(data["seed"]))
	_capture_reloads_at(record, reload_events, 0)
	record.capture_inject_feature_flags(_rebuilt(FeatureFlags.new(), data["flags"]) as FeatureFlags)
	# The recorded ORDER, not the sound one: a record whose content order is unsound must survive
	# the round trip AS UNSOUND, so replay_inject_content() can still refuse it (`3-0c/R11`).
	for channel: StringName in data["content_order"]:
		match channel:
			IntentRecorder.CHANNEL_DECK:
				record.capture_inject_deck(_deck_ids(data["deck"]))
			IntentRecorder.CHANNEL_COSTS:
				record.capture_inject_card_costs(_card_costs(data["costs"]))
			IntentRecorder.CHANNEL_EFFECTS:
				record.capture_inject_card_effects(_card_effects(data["effects"]))
	var intents: Array = data["intents"]
	var camera_pushes: Dictionary = data["camera_pushes"]
	var contacts: Dictionary = data["contacts"]
	for tick in range(1, int(data["tick_count"]) + 1):
		for push: Array in camera_pushes.get(tick, []):
			record.capture_set_camera_basis(int(push[0]), push[1] as Basis)
		for fact: Array in contacts.get(tick, []):
			# Story 4-3a: the FIVE-element row (attacker, target slot, target index, attack index,
			# dir) rebuilt into the recorder's pair-shaped seam. Guaranteed five here by the
			# format_version check above -- a four-element v2 row never reaches this line.
			record.capture_push_contact(int(fact[0]), [int(fact[1]), int(fact[2])], int(fact[3]),
					fact[4] as Vector2)
		record.capture_advance(_intent_pair(intents[tick - 1]))
		_capture_reloads_at(record, reload_events, tick)
	return record


static func _capture_reloads_at(record: IntentRecorder, reload_events: Array, tick: int) -> void:
	for event: Dictionary in reload_events:
		if int(event["tick"]) == tick:
			record.capture_apply_balance(_rebuilt(BalanceConfig.new(), event["values"]) as BalanceConfig)


static func _intent_pair(raw: Array) -> Array[InputIntent]:
	var out: Array[InputIntent] = []
	for values: Dictionary in raw:
		out.append(_intent_from_values(values))
	return out


static func _intent_from_values(values: Dictionary) -> InputIntent:
	var intent := InputIntent.new()
	intent.move_dir = values["move_dir"]
	intent.aim = values["aim"]
	for key: StringName in values["pressed"]:
		intent.pressed[key] = bool(values["pressed"][key])
	for key: StringName in values["held"]:
		intent.held[key] = bool(values["held"][key])
	intent.debug_reset = bool(values["debug_reset"])
	intent.card_slot = int(values["card_slot"])
	intent.card_mode = int(values["card_mode"]) as Enums.ModeKind
	intent.card_commit = bool(values["card_commit"])
	return intent


static func _deck_ids(raw: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in raw:
		out.append(StringName(id))
	return out


static func _card_costs(raw: Dictionary) -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id: StringName in raw:
		out[id] = _rebuilt(CardCastCondition.new(), raw[id]) as CardCastCondition
	return out


## Story 4-1 (`4-1/R1`): the effects half of _card_costs directly above, same shape, same reason.
static func _card_effects(raw: Dictionary) -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id: StringName in raw:
		out[id] = _rebuilt(CardEffect.new(), raw[id]) as CardEffect
	return out


static func _rebuilt(res: Resource, values: Dictionary) -> Resource:
	for name: String in values:
		res.set(name, values[name])
	return res
