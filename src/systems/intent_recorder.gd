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

## The THREE CONTENT channels (story 4-1 adds the third), and the ONE order in which they may be
## applied. ORDER IS
## LOAD-BEARING, not stylistic: MatchState.inject_card_costs()'s totality check reads
## _deck_contents, so costs-before-deck validates against an EMPTY composition and passes
## vacuously — the check would still be there and would still mean nothing (`3-0c/R11`).
const CHANNEL_DECK := &"deck"
const CHANNEL_COSTS := &"costs"
## Story 4-1 (`4-1/R1`, `4-1/R8`): the THIRD content channel, and it sits at the END of the
## ordered contract for the same structural reason CHANNEL_COSTS sits after CHANNEL_DECK --
## MatchState.inject_card_effects()'s totality check reads _deck_contents too, so any order that
## puts effects before the composition validates against an EMPTY one and passes vacuously.
## SOUND_CONTENT_ORDER is what a LIVE match produces; replay_inject_content() refuses anything
## else rather than injecting in an order whose checks would mean nothing.
const CHANNEL_EFFECTS := &"effects"
## Story 5-2 (`5-2/R1`): the FOURTH content channel, and it sits at the END of the ordered contract
## for the reason both of its predecessors do -- MatchState.inject_card_colors()'s totality check
## reads _deck_contents too, so any order that puts colours before the composition validates against
## an EMPTY one and passes vacuously.
const CHANNEL_COLORS := &"colors"
## Story 6-2 (AC 16): the FIFTH content channel, and it sits at the END of the ordered contract. Unlike
## its predecessors its seam (`MatchState.inject_pitch_costs`) checks nothing against _deck_contents, so
## its position is not load-bearing for totality -- it goes last so the contract stays the one straight
## line the live runner produces.
const CHANNEL_PITCH_COSTS := &"pitch_costs"
const SOUND_CONTENT_ORDER: Array[StringName] = [CHANNEL_DECK, CHANNEL_COSTS, CHANNEL_EFFECTS,
		CHANNEL_COLORS, CHANNEL_PITCH_COSTS]

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

## The three content channels (AC 5 / AC 6; story 4-1 adds the third) plus the ORDER they were
## injected in.
var _deck_contents: Array[StringName] = []
var _cost_values: Dictionary = {}   # card id -> CardCastCondition property values
## Story 4-1 (`4-1/R1`): card id -> CardEffect property values. BY VALUE like its two siblings and
## for the identical reason (this file's header): a CardEffect is a Resource, so a retained handle
## would let a later data/cards/ edit -- or the resource cache handing back the same instance --
## silently re-write what a recording summons.
var _effect_values: Dictionary = {}
## Story 5-2 (`5-2/R1`): card id -> `Enums.CardColor` as a plain INT. UNLIKE its three siblings this
## channel stores no property dictionary and rebuilds no Resource, because a colour is not one: it
## is a single enum value read off `CardData` by the runner, and an int survives the round trip
## whole. The by-value discipline is therefore satisfied trivially rather than by machinery -- there
## is no live handle a later data/cards/ edit could re-colour a recording through.
var _color_values: Dictionary = {}
## Story 6-2 (AC 16): card id -> CardCastCondition property values for Mode ④'s price, BY VALUE for
## `_cost_values`'s reason exactly. A CAPTURED FLAG rides beside it, because unlike every other content
## channel this map may LEGALLY BE EMPTY (no card authoring pitch content is ordinary, AC 2) -- so
## "was it captured" cannot be read off emptiness the way `_cost_values.is_empty()` is.
var _pitch_cost_values: Dictionary = {}
var _pitch_costs_captured := false
var _content_order: Array[StringName] = []

## The per-tick, per-slot camera-basis channel (AC 8, `3-0c/R2`). Keyed by the tick the pushed
## value will be READ on (the runner pushes in step 2, before advance() increments the tick), and
## the per-tick entry keeps PUSH ORDER: [[slot, Basis], ...].
var _camera_pushes: Dictionary[int, Array] = {}

## Story 4-6 (AC 2, `4-6/R6`): the per-tick, per-slot LOCK-DIRECTION channel -- the SIXTH capture
## channel, and a sibling of `_camera_pushes` above in every respect: same keying (the tick the
## pushed value will be READ on), same push-order entry shape [[slot, Vector2], ...], same
## classification (a pushed spatial fact, not state).
##
## IT IS ITS OWN CHANNEL RATHER THAN A ROW ON AN EXISTING ONE because it is its own SEAM:
## `set_lock_direction` is a distinct call with a distinct payload, and the recorder's standing
## discipline is that a channel mirrors a seam one-for-one so the tap cannot record a
## differently-shaped fact from the one pushed.
##
## IT MUST BE RECORDED, and the argument is stronger than the basis's own. The direction is derived
## from ACTOR POSITIONS, which come from move_and_slide() and may drift between a recording and its
## replay -- and it lands directly in the HASHED `HeroState.facing`. Re-deriving it live during a
## replay is exactly the divergence the basis channel was built to prevent (`3-0c/R2`), except that
## here it is not a future risk: facing is target-derived from this story onward.
var _lock_pushes: Dictionary[int, Array] = {}

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


## The CARD-EFFECT channel (story 4-1, AC 2 / AC 10) -- MatchState.inject_card_effects(). Match
## start, before the first tick, the capture_inject_card_costs precedent directly above followed
## verbatim, including its NON-OPTIONAL record-side status: a record carrying a composition but no
## effect map is malformed and is rejected at the capture seam, by has_complete_match_start()'s
## Invariant.check in capture_advance().
##
## RECORD-SIDE MANDATORY, STATE-SIDE OPTIONAL (`4-1/R3`) -- two different obligations on one
## channel, deliberately not conflated. MatchState.inject_card_effects() may simply not be called
## (every fixture predating this story does exactly that, and its casts land on the resolver's
## honest missing-entry default); a RECORD that reaches its first tick without this channel is a
## recording defect, because a replay missing it would summon nothing where the live match summoned
## a unit -- a silent divergence, which is the whole reason the channel set is required at all.
func capture_inject_card_effects(effects: Dictionary[StringName, CardEffect]) -> void:
	Invariant.check(not effects.is_empty(),
		"a captured card-effect map must be non-empty (the inject_card_effects precedent)")
	var values: Dictionary = {}
	for id: StringName in effects:
		values[id] = _resource_values(effects[id])
	_effect_values = values
	_content_order.append(CHANNEL_EFFECTS)


## Story 5-2 (AC 4, `5-2/R1`): the CARD-COLOUR channel — MatchState.inject_card_colors(). Match
## start, before the first tick, the capture_inject_card_effects precedent directly above followed
## line for line: same non-empty guard, same content-order append, same by-value storage.
##
## `RecordFile.FORMAT_VERSION` BUMPS TO 7 for this channel. A v6 record carries no colours at all,
## and rebuilding one by assuming a colour would replay every telegraph as RED -- a value that
## reaches the HASHED per-player `telegraph` key (`player_state.gd`), so the replay would diverge
## from the match it claims to reproduce on the first mode (2) cast. `record_file` refuses a
## mismatched version outright with a reason and carries no migration path, and that refusal IS the
## design (`4-1/R1`, `4-3a/R10`, `4-3b/R21`, `4-4/R15`, `4-6`).
##
## THE CONTACT-KIND WIDENING THAT SHIPS WITH IT FORCES NOTHING. The two new charge-reach kinds ride
## the EXISTING seven-element contact row as new VALUES of an element that is already there, so the
## row shape, `capture_push_contact` and `REQUIRED_KEYS`'s contacts entry are all untouched. The
## bump is this channel's alone -- measured, not inherited.
func capture_inject_card_colors(colors: Dictionary[StringName, Enums.CardColor]) -> void:
	Invariant.check(not colors.is_empty(),
		"a captured card-colour map must be non-empty (the inject_card_colors precedent)")
	for id: StringName in colors:
		_color_values[id] = int(colors[id])
	_content_order.append(CHANNEL_COLORS)


## Story 6-2 (AC 16): the PITCH-COST channel -- MatchState.inject_pitch_costs(). Match start, before
## the first tick, the capture_inject_card_costs precedent directly above for storage (by value,
## content-order append) and for its RECORD-SIDE MANDATORY status: a record reaching its first tick
## without this channel is malformed, because a replay missing it would refuse every staging the live
## match performed -- a silent divergence on the hashed `"pitch"` key and the staging player's mana.
##
## NO NON-EMPTY GUARD, deliberately unlike all four siblings, and for the seam's own reason: an empty
## pitch-cost map is legal content (AC 2), so capturing one is a faithful record rather than a defect.
## `RecordFile.FORMAT_VERSION` BUMPS 8 -> 9 for this channel: a v8 file carries no pitch costs at all.
func capture_inject_pitch_costs(costs: Dictionary[StringName, CardCastCondition]) -> void:
	var values: Dictionary = {}
	for id: StringName in costs:
		values[id] = _resource_values(costs[id])
	_pitch_cost_values = values
	_pitch_costs_captured = true
	_content_order.append(CHANNEL_PITCH_COSTS)


## The CAMERA-BASIS channel — MatchState.set_camera_basis(). Per tick, per slot. Today the
## pushed basis is always identity in live play, but its value is READ during movement
## resolution and reaches HeroState.velocity, which IS hashed — so a replay that does not
## restore it can diverge the moment a look action ships (`3-0c/R2`).
func capture_set_camera_basis(slot: int, camera_basis: Basis) -> void:
	var tick := _tick + 1
	if not _camera_pushes.has(tick):
		_camera_pushes[tick] = []
	_camera_pushes[tick].append([slot, camera_basis])


## The LOCK-DIRECTION channel (story 4-6, AC 2) — MatchState.set_lock_direction(). Per tick, per
## slot, mirroring `capture_set_camera_basis` directly above line for line: the two are the same
## kind of fact and are captured the same way.
##
## `RecordFile.FORMAT_VERSION` BUMPS TO 6 for this channel and the intent-shape change that ships
## with it (AC 14). A v5 record has no lock channel at all, and replaying one against
## target-derived facing would leave every hero facing its construction default while the
## recording's heroes tracked their targets -- a replay that silently diverges from the match it
## claims to reproduce. `record_file` refuses a mismatched version outright with a reason and
## carries no migration path, and that refusal IS the design (`4-3a/R10`, `4-3b/R21`, `4-4/R15`).
func capture_set_lock_direction(slot: int, direction: Vector2) -> void:
	var tick := _tick + 1
	if not _lock_pushes.has(tick):
		_lock_pushes[tick] = []
	_lock_pushes[tick].append([slot, direction])


## The CONTACT-FACT channel — MatchState.push_contact(). The seam's fact verbatim, mirroring its
## signature exactly so the tap can never record a differently-shaped fact from the one pushed.
##
## STORY 4-3a (AC 3, `4-3a/R10`): THE TARGET IS NOW AN ADDRESS PAIR, so the recorded row grows from
## FOUR positional elements to FIVE -- the pair is FLATTENED into the row rather than nested,
## keeping every element a scalar exactly as the four-element row was. THIS SHAPE CHANGE IS WHY
## `RecordFile.FORMAT_VERSION` BUMPS TO 3: a v2 row has no target-index element, and rebuilding one
## by assuming -1 would silently replay a unit hit as a hero hit. `record_file` refuses a mismatched
## version outright with a reason and carries no migration path, and that refusal IS the design.
##
## STORY 4-3b (AC 3 + AC 13, `4-3b/R21`): THE ROW GROWS AGAIN, FIVE -> SEVEN, and for the same class
## of reason -- two more scalars on the same row, no new channel.
##   * AC 3 widens the ATTACKER from a bare slot to a `[slot, index]` ADDRESS, kind-agnostic exactly
##     as the target already is (`index == -1` is that slot's hero). FLATTENED into the row like the
##     target pair before it, so every element stays a scalar.
##   * AC 13 adds the KIND MARKER distinguishing a REACH PROBE from a STRIKE. Without it a probe
##     would replay as a landed hit and deal damage.
## `RecordFile.FORMAT_VERSION` BUMPS TO 4 for this: a v3 row has neither element, and rebuilding
## them by assuming `-1` and `CONTACT_STRIKE` would silently replay a MINION's swing as its owner
## HERO's, and a harmless probe as a real hit. `record_file` refuses a mismatched version outright
## with a reason and carries no migration path, and that refusal IS the design.
##
## THE CHANNEL SET IS UNCHANGED, and this story MEASURED that rather than inheriting it (its own
## Open Question 2 made the bump conditional on the answer). No new capture channel joins the
## recorder; `push_contact` remains the sole intake per 1-8, taking one more PARAMETER rather than
## gaining a sibling method -- which is what keeps `RecordFile.REQUIRED_KEYS` unmoved, since the
## marker rides the existing row. The reflective `_resource_values()` helper is untouched: it
## serialises RESOURCES (balance, flags, costs, effects), and a contact fact is not one.
func capture_push_contact(attacker: Array[int], target: Array[int], attack_index: int,
		target_to_attacker: Vector2, kind: int) -> void:
	var tick := _tick + 1
	if not _contacts.has(tick):
		_contacts[tick] = []
	_contacts[tick].append([attacker[0], attacker[1], target[0], target[1], attack_index,
			target_to_attacker, kind])


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
	# Story 4-1 (`4-1/R1`, `4-1/R3`): a v2 record missing the effects channel is MALFORMED -- the
	# cast-cost clause directly above, applied to the third content channel.
	if _effect_values.is_empty():
		missing.append("card effects")
	# Story 5-2 (`5-2/R1`): a v7 record missing the colours channel is MALFORMED -- the card-effects
	# clause directly above, applied to the fourth content channel, for the reason the version bump
	# states: without it a replay would silently telegraph every unblockable in the wrong colour.
	if _color_values.is_empty():
		missing.append("card colours")
	# Story 6-2 (AC 16): a v9 record missing the pitch-cost channel is MALFORMED -- keyed to CAPTURE, not
	# to emptiness, because an empty pitch-cost map is a legal capture.
	if not _pitch_costs_captured:
		missing.append("pitch costs")
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


func lock_pushes_at(tick: int) -> Array:
	return (_lock_pushes[tick] as Array).duplicate() if _lock_pushes.has(tick) else []


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


## The recorded card effects, each CardEffect rebuilt from values (story 4-1, AC 10) -- so a card
## RE-AUTHORED in data/cards/ after the recording cannot change what the replay summons, exactly
## as replay_card_costs() keeps a re-priced card from changing what the replay pays.
func replay_card_effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id: StringName in _effect_values:
		var effect := CardEffect.new()
		_apply_values(effect, _effect_values[id])
		out[id] = effect
	return out


## Replay-side content injection, IN THE RECORDED ORDER (AC 5 / AC 6). Returns false — injecting
## nothing — for a record whose order is not the sound one, because costs-before-deck would run
## the cost seam's totality check against an empty composition and pass vacuously. Returning
## rather than asserting is deliberate: an unsound ORDER is a property of the record, which a
## caller can inspect and report, unlike the malformed VALUES the seams themselves reject.
## The recorded card colours, as `Enums.CardColor` values (story 5-2, AC 4) -- so a card RECOLOURED
## in data/cards/ after the recording cannot change what the replay telegraphs, exactly as
## replay_card_costs() keeps a re-priced card from changing what the replay pays.
func replay_card_colors() -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	for id: StringName in _color_values:
		out[id] = int(_color_values[id]) as Enums.CardColor
	return out


## The recorded PITCH costs (story 6-2, AC 16), each CardCastCondition rebuilt from values -- so a card
## re-priced for Mode ④ in data/cards/ after the recording cannot change what the replay's staging pays,
## exactly as replay_card_costs() does for Mode ①.
func replay_pitch_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id: StringName in _pitch_cost_values:
		var cost := CardCastCondition.new()
		_apply_values(cost, _pitch_cost_values[id])
		out[id] = cost
	return out


func replay_inject_content(ms: MatchState) -> bool:
	if _content_order != SOUND_CONTENT_ORDER:
		return false
	for channel: StringName in _content_order:
		match channel:
			CHANNEL_DECK:
				ms.inject_deck(replay_deck_contents())
			CHANNEL_COSTS:
				ms.inject_card_costs(replay_card_costs())
			CHANNEL_EFFECTS:
				ms.inject_card_effects(replay_card_effects())
			CHANNEL_COLORS:
				ms.inject_card_colors(replay_card_colors())
			CHANNEL_PITCH_COSTS:
				ms.inject_pitch_costs(replay_pitch_costs())
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


## Re-push the recorded per-slot lock directions for `tick`, in recorded push order (story 4-6,
## AC 2). The `replay_push_camera_bases` sibling directly above, for the sibling channel.
func replay_push_lock_directions(ms: MatchState, tick: int) -> void:
	for push: Array in lock_pushes_at(tick):
		ms.set_lock_direction(int(push[0]), push[1] as Vector2)


## Drain the recorded contact facts for `tick` into push_contact, in recorded push order (AC 9).
## The seam is unchanged — it has accepted facts from whoever pushes them since 1-5.
func replay_push_contacts(ms: MatchState, tick: int) -> void:
	for fact: Array in contacts_at(tick):
		# Story 4-3a / 4-3b: the SEVEN-element row rebuilt into the seam's two `[slot, index]` pairs
		# plus its kind marker. The recorded row is FLAT and BOTH pairs are reassembled here, at the
		# one place that re-enters the seam -- so the record stays scalars-only and the seam stays
		# pair-shaped. Guaranteed seven by RecordFile's format_version check; a shorter v3 row never
		# reaches a replay.
		ms.push_contact([int(fact[0]), int(fact[1])], [int(fact[2]), int(fact[3])], int(fact[4]),
				fact[5] as Vector2, int(fact[6]))


## One slot's recorded intent for `tick`, as a FRESH InputIntent — never the retained instance.
## ReplayController emits these, so the D3 contract ("a Controller returns a fresh value object
## per sample()") holds for a replay exactly as it does for hardware. Past the end of the record
## the intent is a resting one: a replay that outlives its record coasts rather than crashing.
func replay_intent(tick: int, slot: int) -> InputIntent:
	var pair := intents_at(tick)
	if pair.is_empty():
		return InputIntent.new()
	return copy_intent(pair[slot])


## All TEN InputIntent fields, verbatim (AC 2). Written as explicit field assignments rather
## than a property-list walk so that adding an eleventh field to InputIntent leaves this function
## visibly incomplete instead of silently widening the contract.
##
## Story 4-6 (AC 8/AC 11): EIGHT -> NINE. `aim` is GONE (its free-rotation route is superseded,
## not supplemented) and the two retarget-address fields take its place -- so this is a shape
## change in both directions at once, which is half of why `RecordFile.FORMAT_VERSION` bumps to 6.
##
## Story 6-3a (AC 4): NINE -> TEN. `card_activate` joins, and `RecordFile.FORMAT_VERSION` bumps 9 -> 10.
static func copy_intent(src: InputIntent) -> InputIntent:
	var out := InputIntent.new()
	out.move_dir = src.move_dir
	for key: StringName in src.pressed:
		out.pressed[key] = src.pressed[key]
	for key: StringName in src.held:
		out.held[key] = src.held[key]
	out.debug_reset = src.debug_reset
	out.card_slot = src.card_slot
	out.card_mode = src.card_mode
	out.card_commit = src.card_commit
	out.card_activate = src.card_activate
	out.retarget_slot = src.retarget_slot
	out.retarget_index = src.retarget_index
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
