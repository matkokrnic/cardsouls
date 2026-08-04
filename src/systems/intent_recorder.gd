class_name IntentRecorder
extends RefCounted

## Story 3-0c (X5): THE ONE RECORD/REPLAY STREAM CONTRACT. Every external input to MatchState
## rides one of the channels below, so a recorded round can be reconstructed FROM THE RECORD
## ALONE — never from the live CardDatabase, a re-tuned .tres, a re-priced card or a different
## flags resource, all of which can change out from under a recording without a trace.
##
## RUNNER-OWNED, src/systems/, NEVER src/state/ (AC 12, `3-0c/R9`). Three whole-directory scans
## in test_architecture_invariants.gd independently forbid the natural implementation of a
## state-resident recorder, and AC 12's own token scan closes the question.
##
## THE CHANNEL SET IS DERIVED, NOT ENUMERATED (AC 1, `3-0c/R2`). One capture method per public
## intake on MatchState, named `capture_<intake>`; the seed reaches state through
## MatchParams._init rather than a method, so its channel is `capture_seed`. A new intake seam
## shipping without a channel FAILS test_intent_recorder.gd::
## test_every_match_state_intake_has_a_capture_channel. `drain_signals()` is exempt and the test
## names it exempt with the reason: it carries no data inward.
##
## PASSIVE TAP. Nothing here is read by advance(); capture never mutates what it is handed.
## The E0 LIFETIME decision (a Controller returns a FRESH InputIntent per sample(), never a
## mutated cached one) is what makes retaining the reference safe — see input_intent.gd's header,
## which names this recorder directly.
##
## CONTENT IS CAPTURED BY VALUE, NEVER BY REFERENCE. BalanceConfig, FeatureFlags and every
## CardCastCondition are Resources: a live handle would let a later `.tres` edit (or the resource
## cache handing back the same instance) silently re-tune a recording. The channels store plain
## property dictionaries and rebuild fresh resources on replay, which is exactly what makes a
## recording survive a tuning pass.
##
## CLOCK-FREE AND CONTENT-BLIND BY CONSTRUCTION: no Time/OS/Engine, no user:// path, no
## CardDatabase, no BalanceConfigService, no FeatureFlagsService. Serialisation, `user://`
## persistence and the operator surface are `3-0d`'s (`3-0c/R5`), deliberately not here.

## The two CONTENT channels, and the ONE order in which they may be applied. ORDER IS
## LOAD-BEARING, not stylistic: MatchState.inject_card_costs()'s totality check reads
## _deck_contents, so costs-before-deck validates against an EMPTY composition and passes
## vacuously — the check would still be there and would still mean nothing (`3-0c/R11`).
const CHANNEL_DECK := &"deck"
const CHANNEL_COSTS := &"costs"
const SOUND_CONTENT_ORDER: Array[StringName] = [CHANNEL_DECK, CHANNEL_COSTS]

## The seed channel (AC 3) — captured ONCE, at match start, from the SAME value that reaches
## MatchParams. There is deliberately no second, independently-read seed anywhere: MatchState
## does not retain its params, so "never re-seeded" is structural (match_params.gd, `E3-RG/R9`).
var _seed_value := 0
var _seed_captured := false

## The reload channel (AC 4). Each event is {"tick": int, "values": Dictionary} where `tick` is
## the number of ticks ALREADY captured when apply_balance() ran — so the match-start injection
## is RELOAD EVENT #0 at tick 0, before the first tick, from the runner's single existing call
## site. No second injection path ships.
var _reload_events: Array[Dictionary] = []

## The flags channel (AC 7, `3-0c/R3`). CAPTURE IS NOT RUNTIME MUTATION: FeatureFlags stays
## load-once and runtime-immutable, FeatureFlagsService still has no reload() method and no
## reload path, and nothing in this file is gated behind a flag — all scanned by
## test_intent_recorder.gd.
var _flags_values: Dictionary = {}
var _flags_captured := false

## The two content channels (AC 5 / AC 6) plus the ORDER they were injected in.
var _deck_contents: Array[StringName] = []
var _cost_values: Dictionary = {}   # card id -> CardCastCondition property values
var _content_order: Array[StringName] = []

## The per-tick, per-slot camera-basis channel (AC 8, `3-0c/R2`). Keyed by the tick the pushed
## value will be READ on (the runner pushes in step 2, before advance() increments the tick), and
## the per-tick entry keeps PUSH ORDER: [[slot, Basis], ...].
var _camera_pushes: Dictionary[int, Array] = {}

## The contact-fact channel (AC 9), keyed by tick index exactly like the bases above, with the
## four-field fact stored in push order: [[attacker, target, attack_index, dir], ...].
var _contacts: Dictionary[int, Array] = {}

## The per-tick InputIntent stream (AC 2) — index t-1 holds tick t's [p1_intent, p2_intent].
## Every one of InputIntent's eight fields rides verbatim; none is dropped, summarised or
## re-derived.
var _intents: Array[Array] = []

## Ticks captured so far. Mirrors MatchState._tick: capture_advance() is what advances it, so a
## fact or basis captured before the next advance() belongs to tick _tick + 1.
var _tick := 0


# ---------------------------------------------------------------- capture channels (AC 1)

## The SEED channel — MatchState._init(params: MatchParams). Once per match, at match start.
func capture_seed(seed_value: int) -> void:
	Invariant.check(not _seed_captured, "the seed is captured exactly once, at match start")
	_seed_value = seed_value
	_seed_captured = true


## The RELOAD channel — MatchState.apply_balance(). Event #0 is the match-start injection
## (AC 4, `3-0c/R4`); every later call appends with the tick it landed after.
func capture_apply_balance(config: BalanceConfig) -> void:
	Invariant.check(config != null, "a captured balance reload must carry a config")
	_reload_events.append({"tick": _tick, "values": _resource_values(config)})


## The FLAGS channel — MatchState.inject_feature_flags(). Match start, before the first tick.
func capture_inject_feature_flags(value: FeatureFlags) -> void:
	Invariant.check(value != null, "a captured flags injection must carry a FeatureFlags")
	_flags_values = _resource_values(value)
	_flags_captured = true


## The DECK-COMPOSITION channel — MatchState.inject_deck(). Match start, before the first tick.
## The exact Array[StringName] handed to the seam, copied so a caller that reuses its array
## cannot rewrite the record.
func capture_inject_deck(contents: Array[StringName]) -> void:
	Invariant.check(not contents.is_empty(),
		"a captured deck composition must be non-empty (the inject_deck precedent)")
	_deck_contents = contents.duplicate()
	_content_order.append(CHANNEL_DECK)


## The CAST-COST channel — MatchState.inject_card_costs(). Match start, before the first tick,
## and NON-OPTIONAL (AC 6): a record carrying a composition but no cost map is malformed and is
## rejected at the capture seam, by has_complete_match_start()'s Invariant.check in
## capture_advance() below — the inject_deck / push_contact precedent, a plain static class, no
## autoload, export-surviving.
func capture_inject_card_costs(costs: Dictionary[StringName, CardCastCondition]) -> void:
	Invariant.check(not costs.is_empty(),
		"a captured cast-cost map must be non-empty (the inject_card_costs precedent)")
	var values: Dictionary = {}
	for id: StringName in costs:
		values[id] = _resource_values(costs[id])
	_cost_values = values
	_content_order.append(CHANNEL_COSTS)


## The CAMERA-BASIS channel — MatchState.set_camera_basis(). Per tick, per slot. Today the
## pushed basis is always identity in live play, but its value is READ during movement
## resolution and reaches HeroState.velocity, which IS hashed — so a replay that does not
## restore it can diverge the moment a look action ships (`3-0c/R2`).
func capture_set_camera_basis(slot: int, camera_basis: Basis) -> void:
	var tick := _tick + 1
	if not _camera_pushes.has(tick):
		_camera_pushes[tick] = []
	_camera_pushes[tick].append([slot, camera_basis])


## The CONTACT-FACT channel — MatchState.push_contact(). The four-field fact verbatim; the seam's
## own signature and its four Invariant.check guards are UNCHANGED by this story (`3-0c/R1`).
func capture_push_contact(attacker_slot: int, target_slot: int, attack_index: int,
		target_to_attacker: Vector2) -> void:
	var tick := _tick + 1
	if not _contacts.has(tick):
		_contacts[tick] = []
	_contacts[tick].append([attacker_slot, target_slot, attack_index, target_to_attacker])


## The INTENT channel — MatchState.advance(). Retains the two per-tick value objects by
## reference (the E0 LIFETIME decision makes that safe) and advances the recorder's tick.
##
## THE MATCH-START COMPLETENESS GUARD lives here because this is the moment match start is over:
## the first captured tick is the last point at which a missing seed, reload event #0, flags,
## composition or cost map is still a recording defect rather than a silent replay hole.
func capture_advance(intents: Array[InputIntent]) -> void:
	Invariant.check(intents.size() == 2, "the intent stream carries exactly two slots per tick")
	if _tick == 0:
		Invariant.check(has_complete_match_start(),
			"malformed record: %s — every match-start channel must be captured before the first tick"
					% ", ".join(missing_match_start_channels()))
	_intents.append([intents[0], intents[1]])
	_tick += 1


# ---------------------------------------------------------------- record shape

func tick_count() -> int:
	return _tick


func seed_captured() -> bool:
	return _seed_captured


## The match-start channels a record is REQUIRED to carry, by name — the predicate behind the
## Invariant.check in capture_advance(). Exposed (rather than inlined) so the guard's condition is
## directly testable in both directions, the way test_architecture_invariants.gd proves its own
## regex patterns against the exact strings they exist to catch.
func missing_match_start_channels() -> Array[String]:
	var missing: Array[String] = []
	if not _seed_captured:
		missing.append("seed")
	if _reload_events.is_empty():
		missing.append("reload event #0")
	if not _flags_captured:
		missing.append("feature flags")
	if _deck_contents.is_empty():
		missing.append("deck composition")
	if _cost_values.is_empty():
		missing.append("cast costs")
	return missing


func has_complete_match_start() -> bool:
	return missing_match_start_channels().is_empty()


## The content channels in CAPTURE order (AC 5). Live play produces SOUND_CONTENT_ORDER; a record
## that carries any other order cannot be replayed soundly — see replay_inject_content().
func content_order() -> Array[StringName]:
	return _content_order.duplicate()


func reload_event_count() -> int:
	return _reload_events.size()


func reload_event_tick(index: int) -> int:
	return int(_reload_events[index]["tick"])


## The per-tick reads a caller needs to rebuild or inspect a record. Copies, never live handles.
func intents_at(tick: int) -> Array[InputIntent]:
	var out: Array[InputIntent] = []
	if tick >= 1 and tick <= _intents.size():
		var pair: Array = _intents[tick - 1]
		out.append(pair[0])
		out.append(pair[1])
	return out


func camera_pushes_at(tick: int) -> Array:
	return (_camera_pushes[tick] as Array).duplicate() if _camera_pushes.has(tick) else []


func contacts_at(tick: int) -> Array:
	return (_contacts[tick] as Array).duplicate() if _contacts.has(tick) else []


# ---------------------------------------------------------------- replay side

func replay_seed() -> int:
	Invariant.check(_seed_captured, "cannot replay a record with no captured seed")
	return _seed_value


## The BalanceConfig for one recorded reload event, REBUILT from the captured values — never a
## retained handle and never a re-read of the on-disk .tres (AC 4). Index 0 is the match-start
## injection.
func replay_balance_config(index: int) -> BalanceConfig:
	var config := BalanceConfig.new()
	_apply_values(config, _reload_events[index]["values"])
	return config


## The recorded FeatureFlags, rebuilt from values (AC 7). FeatureFlagsService is never read.
func replay_feature_flags() -> FeatureFlags:
	Invariant.check(_flags_captured, "cannot replay a record with no captured feature flags")
	var flags := FeatureFlags.new()
	_apply_values(flags, _flags_values)
	return flags


func replay_deck_contents() -> Array[StringName]:
	return _deck_contents.duplicate()


## The recorded cast costs, each CardCastCondition rebuilt from values — so a card re-priced in
## data/cards/ after the recording cannot change what the replay pays (AC 6).
func replay_card_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id: StringName in _cost_values:
		var cost := CardCastCondition.new()
		_apply_values(cost, _cost_values[id])
		out[id] = cost
	return out


## Replay-side content injection, IN THE RECORDED ORDER (AC 5 / AC 6). Returns false — injecting
## nothing — for a record whose order is not the sound one, because costs-before-deck would run
## the cost seam's totality check against an empty composition and pass vacuously. Returning
## rather than asserting is deliberate: an unsound ORDER is a property of the record, which a
## caller can inspect and report, unlike the malformed VALUES the seams themselves reject.
func replay_inject_content(ms: MatchState) -> bool:
	if _content_order != SOUND_CONTENT_ORDER:
		return false
	for channel: StringName in _content_order:
		match channel:
			CHANNEL_DECK:
				ms.inject_deck(replay_deck_contents())
			CHANNEL_COSTS:
				ms.inject_card_costs(replay_card_costs())
	return true


## Reload events recorded MID-RUN, applied before tick `tick` runs. Event #0 is the match-start
## injection and is applied by the caller at match start, so it is deliberately skipped here — a
## record whose first event was re-applied at tick 1 would re-run first-injection hp restoration.
func replay_apply_reloads_before(ms: MatchState, tick: int) -> void:
	for index in range(1, _reload_events.size()):
		if int(_reload_events[index]["tick"]) == tick - 1:
			ms.apply_balance(replay_balance_config(index))


## Re-push the recorded per-slot camera bases for `tick`, in recorded push order (AC 8).
func replay_push_camera_bases(ms: MatchState, tick: int) -> void:
	for push: Array in camera_pushes_at(tick):
		ms.set_camera_basis(int(push[0]), push[1] as Basis)


## Drain the recorded contact facts for `tick` into push_contact, in recorded push order (AC 9).
## The seam is unchanged — it has accepted facts from whoever pushes them since 1-5.
func replay_push_contacts(ms: MatchState, tick: int) -> void:
	for fact: Array in contacts_at(tick):
		ms.push_contact(int(fact[0]), int(fact[1]), int(fact[2]), fact[3] as Vector2)


## One slot's recorded intent for `tick`, as a FRESH InputIntent — never the retained instance.
## ReplayController emits these, so the D3 contract ("a Controller returns a fresh value object
## per sample()") holds for a replay exactly as it does for hardware. Past the end of the record
## the intent is a resting one: a replay that outlives its record coasts rather than crashing.
func replay_intent(tick: int, slot: int) -> InputIntent:
	var pair := intents_at(tick)
	if pair.is_empty():
		return InputIntent.new()
	return copy_intent(pair[slot])


## All EIGHT InputIntent fields, verbatim (AC 2). Written as explicit field assignments rather
## than a property-list walk so that adding a ninth field to InputIntent leaves this function
## visibly incomplete instead of silently widening the contract.
static func copy_intent(src: InputIntent) -> InputIntent:
	var out := InputIntent.new()
	out.move_dir = src.move_dir
	out.aim = src.aim
	for key: StringName in src.pressed:
		out.pressed[key] = src.pressed[key]
	for key: StringName in src.held:
		out.held[key] = src.held[key]
	out.debug_reset = src.debug_reset
	out.card_slot = src.card_slot
	out.card_mode = src.card_mode
	out.card_commit = src.card_commit
	return out


# ---------------------------------------------------------------- by-value resource capture

## Every SCRIPT-DECLARED property of a Resource, by value. Container values are deep-copied, so
## a later edit to the authored resource cannot reach back into the record.
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


static func _apply_values(res: Resource, values: Dictionary) -> void:
	for name: String in values:
		res.set(name, values[name])
