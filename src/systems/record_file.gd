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
## STORY 4-3b (`4-3b/R21`) BUMPS THIS TO 4, and it is again a payload SHAPE change rather than a new
## channel -- the third bump in the same family, for the third time on the contact row. The fact's
## ATTACKER widened from a bare slot to a `[slot, index]` ADDRESS (AC 3) and the fact gained a KIND
## marker separating a REACH PROBE from a STRIKE (AC 13), so the recorded row grew from five
## positional elements to seven. A v3 file carries neither: rebuilding the attacker index by assuming
## -1 would silently replay a MINION's swing as its owner HERO's, and rebuilding the marker by
## assuming STRIKE would replay a harmless reach probe as a landed hit that deals damage. Both are
## replays that diverge from the match they claim to reproduce, which is exactly what the version
## check exists to refuse. HARD REJECTION, NO SHIM, for the `4-1/R1` reason above.
##
## The channel SET is unchanged and this story MEASURED it rather than assuming (its own Open
## Question 2 left the bump conditional on the answer): the marker RIDES THE EXISTING ROW and
## `push_contact` gained a parameter rather than a sibling method, so REQUIRED_KEYS below does not
## move and `_resource_values` is untouched.
##
## STORY 4-4 (`4-4/R15`) BUMPS THIS TO 5, and this one is neither a new channel nor a contact-row
## shape change -- it is the RECORDED BALANCE CONFIG's own shape. `4-4` gave `BalanceConfig` an
## `Array[UnitKindProfile] unit_kinds`, and `_resource_values` below was a ONE-LEVEL capture: it
## read the property by value and handed the live `Resource` references straight to `store_var`,
## which encodes each of them as an `EncodedObjectAsID` because `full_objects` defaults to false.
## On load, assigning that untyped array of ids into the typed `Array[UnitKindProfile]` property
## is REJECTED BY THE ENGINE WITH NOTHING PRINTED, so the field stayed at its `[]` default --
## MEASURED, not theorised: `rebuilt unit_kinds size = 0` against the shipped `.tres`.
##
## The consequence is the exact condition every bump above exists to refuse, in its worst form: a
## record loaded from disk replays with NO UNIT KINDS AT ALL -- `kind_at()` null everywhere,
## `kind_index_of()` -> `NO_KIND_INDEX`, so every summon puts a unit on the board with no speed, no
## hp, no damage, no attack and no priority. `_resource_values` / `_rebuilt` now RECURSE (see
## NESTED_CLASS_KEY), which fixes the post-4-4 half; the bump fixes the PRE-4-4 half. A v4 record
## carries the retired flat keys (`unit_max_hp`, `unit_damage_per_hit`) and no `unit_kinds` at all,
## so rebuilding one would set dead keys onto nothing and replay every unit as kindless. HARD
## REJECTION, NO SHIM, for the `4-1/R1` reason above.
## STORY 4-6 BUMPS 5 -> 6 (AC 14), and the bump is a MEASUREMENT rather than a habit: AC 14 asks
## whether the retarget result fits inside the existing `InputIntent` / recorded-fact channels, and
## it does not. The only unoccupied intent field was `aim`, whose resting `Vector2.ZERO` is a VALID
## `[slot, index]` address (slot 0's unit 0) -- so repurposing it has no "no retarget" sentinel
## without moving its resting value, and moving that makes every v5 record decode a resting `aim`
## as a live retarget onto `[0, 0]`. A new element is needed, so the format bumps, and it carries
## THREE shape changes at once: `aim` DELETED, `retarget_slot`/`retarget_index` ADDED, and the new
## per-tick `lock_pushes` channel required beside `camera_pushes`. A v5 record has none of them,
## and replaying one against target-derived facing would leave every hero facing its construction
## default while the recording's heroes tracked their targets. HARD REJECTION, NO SHIM, the
## `4-3a/R10` / `4-3b/R21` / `4-4/R15` discipline unbroken.
const FORMAT_VERSION := 6

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
	# Story 4-6 (AC 2/AC 14): the per-tick LOCK-DIRECTION channel, required from FORMAT_VERSION 6
	# onward. Its arrival IS half the version bump -- a v5 file lacks this key, and is refused by
	# the version check long before this map is consulted, exactly as `effects` was at v2.
	"lock_pushes": TYPE_DICTIONARY,
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
	var lock_pushes: Dictionary = {}
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
		# Story 4-6 (AC 2): the lock channel rides the same loop, the same sparse
		# only-if-non-empty rule and the same tick keying as its `camera_pushes` sibling.
		var locks := record.lock_pushes_at(tick)
		if not locks.is_empty():
			lock_pushes[tick] = locks
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
		"lock_pushes": lock_pushes,
	}


## All NINE InputIntent fields, verbatim — written as explicit field reads for the same reason
## IntentRecorder.copy_intent is: a tenth field leaves this visibly incomplete instead of silently
## narrowing what survives a save.
##
## Story 4-6 (AC 8/AC 11/AC 14): `aim` is GONE and the two retarget-address fields replace it —
## half of the FORMAT_VERSION 5 -> 6 bump (see the constant's own block).
static func _intent_values(intent: InputIntent) -> Dictionary:
	return {
		"move_dir": intent.move_dir,
		"pressed": intent.pressed.duplicate(),
		"held": intent.held.duplicate(),
		"debug_reset": intent.debug_reset,
		"card_slot": intent.card_slot,
		"card_mode": int(intent.card_mode),
		"card_commit": intent.card_commit,
		"retarget_slot": intent.retarget_slot,
		"retarget_index": intent.retarget_index,
	}


## Every SCRIPT-DECLARED property of a Resource, by value — the recorder's own by-value discipline
## (intent_recorder.gd:345-356) applied on the way to disk, so a record on disk carries numbers
## and never a path back to an authored resource that can be re-tuned under it.
##
## STORY 4-4 (`4-4/R15`): BY VALUE IS NOW RECURSIVE, and the reason is that "by value" was never
## true of a Resource-valued property. It used to read the property and hand whatever came back to
## `store_var`, which is exactly right for a float and silently wrong for a `Resource`: with
## `full_objects` false, a live reference is encoded as an `EncodedObjectAsID` — an int in a
## trenchcoat — and rebuilding from it produces nothing. `BalanceConfig.unit_kinds` was the first
## property to have that shape, and it lost its entire contents on every save. See `_captured`.
static func _resource_values(res: Resource) -> Dictionary:
	var out: Dictionary = {}
	for prop: Dictionary in res.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		out[prop["name"]] = _captured(res.get(prop["name"]))
	return out


## The two keys a NESTED resource rides under, and the reason they are two rather than one: the
## rebuild has to know WHICH class to construct before it can set anything, and a plain values dict
## carries no class. Prefixed so they cannot collide with a script property name — GDScript
## identifiers cannot begin with a digit, but they CAN begin with `_`, so the names below are
## deliberately shapes no `@export` would ever take.
const NESTED_CLASS_KEY := "__resource_class"
const NESTED_VALUES_KEY := "__resource_values"

## Every script class a saved record can carry NESTED inside another resource, tag -> constructor.
## WRITTEN OUT RATHER THAN DERIVED, for `_intent_values`'s reason one function up: a fourth nesting
## level added to `BalanceConfig` leaves this VISIBLY incomplete (the value comes back null and the
## round-trip test fails loudly) instead of silently narrowing what survives a save.
##
## RESIDUE, on `3-0d/R25`'s footing: an unknown tag rebuilds as `null` rather than as a named
## refusal. A v5 file can only carry these three, because this build's writer is the only thing
## that writes v5 and it emits exactly what it can read; a file carrying a foreign tag is corrupt
## input of the same family as the five cases `3-0d/R25` writes down.
static func _fresh_nested(tag: String) -> Resource:
	match tag:
		"UnitKindProfile":
			return UnitKindProfile.new()
		"UnitAttackProfile":
			return UnitAttackProfile.new()
		"ProjectileProfile":
			return ProjectileProfile.new()
	return null


## One property value, captured by value all the way down: a Resource becomes a tagged dict, a
## container is rebuilt element by element (which is also what makes the old `duplicate(true)`
## unnecessary — nothing here shares a reference with the live object), everything else is already
## a value and rides as itself.
static func _captured(value: Variant) -> Variant:
	if value is Resource:
		return {
			NESTED_CLASS_KEY: _class_tag(value as Resource),
			NESTED_VALUES_KEY: _resource_values(value as Resource),
		}
	if value is Array:
		var elements: Array = []
		for element: Variant in (value as Array):
			elements.append(_captured(element))
		return elements
	if value is Dictionary:
		var entries: Dictionary = {}
		var source: Dictionary = value
		for key: Variant in source:
			entries[key] = _captured(source[key])
		return entries
	return value


## The script class name a nested resource is tagged with. `get_global_name()` is the `class_name`
## line itself, which is the same string `_fresh_nested` matches on; a Resource with no script (none
## reachable from a record today) falls back to its engine class so the tag is never empty.
static func _class_tag(res: Resource) -> String:
	var script := res.get_script() as Script
	if script != null and String(script.get_global_name()) != "":
		return String(script.get_global_name())
	return res.get_class()


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
	var lock_pushes: Dictionary = data["lock_pushes"]
	for tick in range(1, int(data["tick_count"]) + 1):
		for push: Array in camera_pushes.get(tick, []):
			record.capture_set_camera_basis(int(push[0]), push[1] as Basis)
		# Story 4-6 (AC 2): the lock channel is re-captured in the SAME per-tick seat and the same
		# order relative to `capture_advance` as the bases above -- both are pushed before a tick
		# advances, live and on rebuild alike.
		for push: Array in lock_pushes.get(tick, []):
			record.capture_set_lock_direction(int(push[0]), push[1] as Vector2)
		for fact: Array in contacts.get(tick, []):
			# Story 4-3a / 4-3b: the SEVEN-element row (attacker slot, attacker index, target slot,
			# target index, attack index, dir, kind) rebuilt into the recorder's pair-shaped seam.
			# Guaranteed seven here by the format_version check above -- a five-element v3 row
			# never reaches this line.
			record.capture_push_contact([int(fact[0]), int(fact[1])],
					[int(fact[2]), int(fact[3])], int(fact[4]), fact[5] as Vector2, int(fact[6]))
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
	for key: StringName in values["pressed"]:
		intent.pressed[key] = bool(values["pressed"][key])
	for key: StringName in values["held"]:
		intent.held[key] = bool(values["held"][key])
	intent.debug_reset = bool(values["debug_reset"])
	intent.card_slot = int(values["card_slot"])
	intent.card_mode = int(values["card_mode"]) as Enums.ModeKind
	intent.card_commit = bool(values["card_commit"])
	intent.retarget_slot = int(values["retarget_slot"])
	intent.retarget_index = int(values["retarget_index"])
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


## `_resource_values`'s inverse. TYPED ARRAYS ARE ASSIGNED, NOT SET, and that is the half of
## `4-4/R15` that is easy to get wrong twice: `res.set("unit_kinds", <untyped Array>)` is REJECTED
## WITH NOTHING PRINTED even when every element is the right class, so a rebuild that recursed
## correctly and then `set()` the result would still have landed an empty array. MEASURED both ways
## on Godot 4.6.3 — `set()` leaves size 0, `Array.assign()` onto the property's own typed array
## converts in place and reads back size 1. The array `get()` returns IS the property's array
## (arrays are reference values), so assigning into it is assigning into the resource.
static func _rebuilt(res: Resource, values: Dictionary) -> Resource:
	for name: String in values:
		var value: Variant = _restored(values[name])
		var existing: Variant = res.get(name)
		if value is Array and existing is Array:
			(existing as Array).assign(value as Array)
			continue
		# The same trap on the other container: `orb_costs` is a `Dictionary[CardColor, int]`, and
		# an untyped Dictionary `set()` onto it is refused as quietly as the array case.
		if value is Dictionary and existing is Dictionary:
			(existing as Dictionary).assign(value as Dictionary)
			continue
		res.set(name, value)
	return res


## `_captured`'s inverse, one value at a time: a tagged dict becomes a fresh resource rebuilt
## through this same function, a container is restored element by element, everything else is
## already the value it was written as.
static func _restored(value: Variant) -> Variant:
	if value is Dictionary and (value as Dictionary).has(NESTED_CLASS_KEY):
		var entry: Dictionary = value
		var fresh := _fresh_nested(String(entry[NESTED_CLASS_KEY]))
		if fresh == null:
			return null
		return _rebuilt(fresh, entry[NESTED_VALUES_KEY])
	if value is Array:
		var elements: Array = []
		for element: Variant in (value as Array):
			elements.append(_restored(element))
		return elements
	if value is Dictionary:
		var entries: Dictionary = {}
		var source: Dictionary = value
		for key: Variant in source:
			entries[key] = _restored(source[key])
		return entries
	return value
