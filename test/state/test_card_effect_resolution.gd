extends TestCase

## Story 4-1: BASIC SUMMON RESOLUTION — `CardEffect`'s first consumer, the per-player board, and
## the four named outcomes a resolved cast can have.
##
## Fixture shape follows test_card_play.gd's: every card costs the SAME mana, so no test has to
## predict which id the shuffle put in which slot. Counts are chosen distinct from one another
## (deck 8, hand 4, cost 3.0, mana 30.0) so an off-by-one that read the wrong quantity lands on a
## different number instead of coinciding with one.
##
## THE EFFECT MAP IS BUILT IN-TEST OVER OPAQUE IDS, never loaded from data/cards/ — the
## _golden_deck / _golden_costs principle. Adding, renaming or re-authoring a real card must not
## reach these assertions.

const SEED := 4242
const DECK_SIZE := 8
const HAND_SIZE := 4
const CARD_COST := 3.0
const START_MANA := 30.0


# --- AC 1 / AC 4: a summon puts ONE record on the board --------------------------------------

## AC 4, the whole of it in one cast: a `summon_*` id creates exactly ONE unit record, on the
## CASTING player's board, and on nobody else's.
func test_a_summon_cast_appends_exactly_one_unit_record_to_the_caster() -> void:
	var ms := _make_match()
	assert_eq(ms.p1.units.size(), 0, "sanity: the board starts empty")
	assert_true(ms.p1.units.is_empty(), "...and says so")
	_advance(ms, _cast_intent(1), InputIntent.new())
	assert_eq(ms.p1.units.size(), 1, "the resolved summon appended ONE unit record")
	assert_eq(ms.p2.units.size(), 0,
		"...to the CASTING player's board only — the opponent's is untouched")


## AC 4: "one record per resolved cast, appended in cast order" — proven by casting repeatedly and
## watching the count track the casts one for one, rather than saturating at one or double-adding.
func test_each_resolved_summon_appends_one_more_record() -> void:
	var ms := _make_match()
	for expected in [1, 2, 3]:
		_advance(ms, _cast_intent(0), InputIntent.new())
		assert_eq(ms.p1.units.size(), expected,
			"cast %d has left exactly %d records on the board" % [expected, expected])


## AC 1: the resolver is reached with the id that was actually CAST, not with a fixed or
## first-in-map entry. Only ONE id in the composition carries a summon effect here; every other
## id carries a spell one, so the board moves if and only if the cast id's own effect was the one
## looked up.
func test_the_resolver_is_keyed_by_the_id_actually_cast() -> void:
	# The one summoning id is whichever card the deal puts in slot 2 — read off a first, discarded
	# match so the test states its subject instead of assuming what the shuffle did. The seed is
	# fixed, so the second match below deals identically.
	var summon_id: StringName = _make_match(_all_spell_effects()).p1.hand.to_array()[2]
	var ms := _make_match(_effects_where_only(summon_id))
	assert_eq(ms.p1.hand.to_array()[2], summon_id,
		"sanity: the same seed dealt the same card into slot 2")
	_advance(ms, _cast_intent(0), InputIntent.new())
	assert_eq(ms.p1.units.size(), 0,
		"casting a slot whose id carries a SPELL effect put nothing on the board")
	_advance(ms, _cast_intent(2), InputIntent.new())
	assert_eq(ms.p1.units.size(), 1,
		"...and casting the one slot whose id carries the SUMMON effect did")


# --- AC 5: a spell is a NAMED no-op, never a rejection ---------------------------------------

## AC 5 / `E4-P/R10`: the cast has already passed CastEvaluator, so EVERY consequence of a normal
## cast still happens — mana spent, card discarded, replacement owed — and the only thing that
## does not happen is a board mutation. Asserted as the four separate facts they are, because a
## spell branch that quietly swallowed the discard would otherwise read as a pass.
func test_a_spell_cast_resolves_completely_and_touches_no_board() -> void:
	var ms := _make_match(_all_spell_effects())
	var before_hand := ms.p1.hand.to_array()
	var played: StringName = before_hand[1]
	var mana_before := ms.p1.mana.get_current()
	_advance(ms, _cast_intent(1), InputIntent.new())
	assert_eq(ms.p1.units.size(), 0, "a spell put NOTHING on the board")
	assert_eq(ms.p1.mana.get_current(), mana_before - CARD_COST,
		"...and the mana was still spent, exactly as it is today")
	assert_eq(ms.p1.discard.to_array(), [played] as Array[StringName],
		"...and the card was still discarded")
	# This fixture authors no draw_replacement_delay, so the delay derives to ZERO ticks and the
	# replacement is delivered inside the cast tick (3-5b's own ruled degrade). The observable
	# consequence is therefore a REFILLED hand, not an outstanding debt.
	assert_eq(ms.p1.hand.occupied_count(), HAND_SIZE,
		"...and the replacement still arrived: the cast is complete in every respect but the board")


## AC 5 / `4-1/R10`: the spell branch's stated reason, as a RETURNED VALUE. This is the whole of
## that reason's contract — asserting it here is what `4-1/R10` means by "asserted in unit tests".
func test_a_spell_effect_id_returns_the_named_no_op_reason() -> void:
	assert_eq(CardEffectResolver.outcome(_effect(&"spell_ember_lash"), _flags()),
		CardEffectResolver.REASON_SPELL_NOT_YET_RESOLVED,
		"a spell_* id resolves to the named no-op reason, not to a summon and not to a refusal")


# --- AC 6: refusal by TWO distinct returned named values -------------------------------------

## AC 6(i), the MISSING-ENTRY HONEST DEFAULT, proven with a DIRECTED test as the AC requires: a
## fixture that injects NO effects at all — which is every MatchState fixture predating this
## story, so this is the naturally reachable branch, not a synthetic one.
func test_a_cast_with_no_injected_effect_entry_returns_the_missing_entry_reason() -> void:
	assert_eq(CardEffectResolver.outcome(null, _flags()),
		CardEffectResolver.REASON_NO_EFFECT_ENTRY,
		"no entry for the cast id reads as the missing-entry default, never as a summon")


## AC 6(i), the same branch reached THROUGH a live cast rather than through the evaluator alone —
## which is what makes "injection is state-side OPTIONAL" (`4-1/R3`) an executable claim rather
## than a promise. The board must stay empty and the cast must otherwise resolve normally.
func test_an_effects_less_match_casts_normally_and_puts_nothing_on_the_board() -> void:
	var ms := _make_match_without_effects()
	var mana_before := ms.p1.mana.get_current()
	_advance(ms, _cast_intent(1), InputIntent.new())
	assert_eq(ms.p1.units.size(), 0, "no effects injected -> no unit reaches the board")
	assert_eq(ms.p1.mana.get_current(), mana_before - CARD_COST,
		"...and the cast resolved anyway: this is a successful cast, not a refused one")
	assert_eq(ms.p1.discard.size(), 1, "...and the card was discarded")


## AC 6(ii), the UNKNOWN-PREFIX REFUSAL, proven with a SYNTHETIC map entry exactly as the AC
## requires. NO FIXTURE CARD PRODUCES THIS — the nine authored ids are six `summon_*` and three
## `spell_*` — so this is declared NOT naturally reachable and is never claimed to be.
func test_an_unrecognised_effect_prefix_returns_the_unknown_prefix_reason() -> void:
	assert_eq(CardEffectResolver.outcome(_effect(&"enchant_thornmail"), _flags()),
		CardEffectResolver.REASON_UNKNOWN_EFFECT_PREFIX,
		"an id matching neither prefix is refused BY NAME, never treated as a summon")
	assert_eq(CardEffectResolver.outcome(_effect(&""), _flags()),
		CardEffectResolver.REASON_UNKNOWN_EFFECT_PREFIX,
		"...and so is an EMPTY effect_id, which is CardEffect's own default")


## AC 6(ii), the same branch through a live cast: a synthetic map whose entries carry an
## unrecognised prefix leaves the board empty while the cast still resolves.
func test_an_unknown_prefix_cast_puts_nothing_on_the_board() -> void:
	var ms := _make_match(_effects_all(&"enchant_"))
	_advance(ms, _cast_intent(1), InputIntent.new())
	assert_eq(ms.p1.units.size(), 0, "an unrecognised prefix put nothing on the board")
	assert_eq(ms.p1.discard.size(), 1, "...and the cast still resolved")


## AC 6: the TWO reasons are DISTINCT and stay distinct. Folding them into one is the specific
## thing `4-1/R3` forbids ("two distinct reasons, never folded into one"), and a later
## simplification that collapsed them would pass every other test in this file.
func test_the_two_refusal_reasons_are_distinct_named_values() -> void:
	assert_ne(CardEffectResolver.REASON_NO_EFFECT_ENTRY,
		CardEffectResolver.REASON_UNKNOWN_EFFECT_PREFIX,
		"missing-entry and unknown-prefix are two different facts and carry two different names")
	var all_reasons := [
		CardEffectResolver.OUTCOME_SUMMON,
		CardEffectResolver.REASON_SPELL_NOT_YET_RESOLVED,
		CardEffectResolver.REASON_NO_EFFECT_ENTRY,
		CardEffectResolver.REASON_UNKNOWN_EFFECT_PREFIX,
		CardEffectResolver.REASON_MINIONS_FLAG_CLOSED,
	]
	var seen: Dictionary = {}
	for reason: StringName in all_reasons:
		assert_false(String(reason).is_empty(),
			"every outcome is NAMED — unlike CastEvaluator there is no empty success value here")
		assert_false(seen.has(reason), "outcome %s is declared twice" % reason)
		seen[reason] = true


## AC 5 / AC 6 / `4-1/R3` / `4-1/R10`: NO PATH RENDERS A REFUSAL TO THE PLAYER. A resolved cast is
## a successful cast whatever its effect outcome, so `reject_action` must not appear on any of
## them — the machine check is that the resolver dispatch in match_state.gd sits nowhere near the
## seam, and the behavioural check is that no action_rejected payload is queued by a spell, a
## missing entry or an unknown prefix.
func test_no_effect_outcome_rejects_the_action() -> void:
	var scanned := 0
	var offenders: Array[String] = []
	for line in _code_lines("res://src/state/economy/card_effect_resolver.gd"):
		scanned += 1
		if line.begins_with("#"):
			continue          # the header NAMES the seam it refuses to reach; that is not a call
		if line.contains("reject_action"):
			offenders.append(line.strip_edges())
	assert_true(scanned > 0, "the scan must actually read the resolver (guard would be vacuous)")
	assert_eq(offenders.size(), 0,
		"the resolver must never reach the refusal seam (`4-1/R10`): %s" % ", ".join(offenders))
	# ...and behaviourally, across all three non-summoning outcomes.
	for effects: Dictionary in [_all_spell_effects(), _effects_all(&"enchant_"), {}]:
		var ms := _make_match(effects) if not effects.is_empty() else _make_match_without_effects()
		var rejected: Array = []
		ms.p1.hero.action_rejected.connect(
			func(action: StringName, reason: StringName) -> void: rejected.append([action, reason]))
		_advance(ms, _cast_intent(1), InputIntent.new())
		assert_eq(rejected, [],
			"a resolved cast queued NO action_rejected — it succeeded, whatever its effect did")


# --- AC 2: the injection seam ----------------------------------------------------------------

## AC 2: both seam checks are still THERE, on the condition they exist for — the
## test_card_play.gd::test_cost_injection_seam_keeps_both_guards mechanism and rationale verbatim.
##
## Their FIRING cannot be tested: Invariant.check routes through assert(), which PRINTS AND
## CONTINUES at exit 0 rather than aborting (`3-0c/R15`), and run_all.sh greps for "INVARIANT
## VIOLATED", so a deliberately triggered one would fail the suite for the wrong reason. What IS
## provable is presence at the seam: delete either and this fails. Declared honestly in the dev
## record as NOT mutation-proven in the FIRING sense.
func test_effect_injection_seam_keeps_both_guards() -> void:
	var in_seam := false
	var seam_found := false
	var non_empty_guard := false
	var totality_guard := false
	for line in _code_lines("res://src/state/match_state.gd"):
		if line.begins_with("func inject_card_effects("):
			in_seam = true
			seam_found = true
			continue
		if in_seam and line.begins_with("func "):
			break
		if in_seam and line.contains("Invariant.check") and line.contains("is_empty()"):
			non_empty_guard = true
		if in_seam and line.contains("Invariant.check") and line.contains("effects.has("):
			totality_guard = true
	assert_true(seam_found,
		"match_state.gd must still declare inject_card_effects (a rename un-guards this)")
	assert_true(non_empty_guard,
		"inject_card_effects must Invariant.check that the injected map is non-empty")
	assert_true(totality_guard,
		"inject_card_effects must Invariant.check that the map is TOTAL over the composition")


## AC 2 / `E4-P/R4`: the injected effect map is what the resolver reads, and injecting a DIFFERENT
## map produces a different board — so the seam is genuinely the path the content travels, not a
## call whose result is ignored in favour of something else.
func test_the_injected_map_is_what_the_resolver_reads() -> void:
	var summoning := _make_match()
	_advance(summoning, _cast_intent(1), InputIntent.new())
	assert_eq(summoning.p1.units.size(), 1, "the summon map summons")
	var spelling := _make_match(_all_spell_effects())
	_advance(spelling, _cast_intent(1), InputIntent.new())
	assert_eq(spelling.p1.units.size(), 0,
		"...and the SAME fixture with a spell map does not — the injected map decides")


# --- Feature-flag matrix (project-context HARD RULE) -----------------------------------------

## The project-context HARD RULE on feature flags, both directions. `minions` is one of the seven
## named toggleable layers, so summon resolution checks it and DEGRADES GRACEFULLY when off:
## the cast resolves exactly as it does today and no unit reaches the board.
func test_the_minion_layer_off_degrades_to_a_cast_with_no_board_effect() -> void:
	var flags := FeatureFlags.new()   # minions defaults OFF
	assert_false(flags.minions, "sanity: the layer's authored default is off")
	assert_eq(CardEffectResolver.outcome(_effect(&"summon_imp"), flags),
		CardEffectResolver.REASON_MINIONS_FLAG_CLOSED,
		"with the layer off a summon reports the flag, by name")
	var ms := _make_match(_summon_effects(), flags)
	var mana_before := ms.p1.mana.get_current()
	_advance(ms, _cast_intent(1), InputIntent.new())
	assert_eq(ms.p1.units.size(), 0, "...and nothing reaches the board")
	assert_eq(ms.p1.mana.get_current(), mana_before - CARD_COST,
		"...while the cast still resolves: graceful degradation, not a refusal")
	assert_eq(ms.p1.discard.size(), 1, "...and the card is still discarded")


## The ON half of the matrix, and the guard that keeps the OFF half from being vacuous: with the
## same fixture and the layer ON, the unit DOES appear.
func test_the_minion_layer_on_summons() -> void:
	var flags := FeatureFlags.new()
	flags.minions = true
	assert_eq(CardEffectResolver.outcome(_effect(&"summon_imp"), flags),
		CardEffectResolver.OUTCOME_SUMMON, "with the layer on a summon summons")
	var ms := _make_match(_summon_effects(), flags)
	_advance(ms, _cast_intent(1), InputIntent.new())
	assert_eq(ms.p1.units.size(), 1, "...and the unit reaches the board")


## No flags injected at all reads as CLOSED — CastEvaluator._flag_open's own direction, and the
## reason a fixture that injects none cannot accidentally summon.
func test_no_injected_flags_reads_as_closed() -> void:
	assert_eq(CardEffectResolver.outcome(_effect(&"summon_imp"), null),
		CardEffectResolver.REASON_MINIONS_FLAG_CLOSED,
		"a layer that cannot be verified open stays shut")


## AC 6(ii) beats the flag: an UNKNOWN prefix reports itself as unknown whether the layer is on or
## off. Reading the flag first would hide an authoring error behind a switch, which is why the
## resolver's branch order is load-bearing rather than incidental.
func test_an_unknown_prefix_reports_itself_even_with_the_layer_off() -> void:
	assert_eq(CardEffectResolver.outcome(_effect(&"enchant_thornmail"), FeatureFlags.new()),
		CardEffectResolver.REASON_UNKNOWN_EFFECT_PREFIX,
		"the flag gate sits INSIDE the summon branch, so an unknown id is still unknown")


# --- AC 8: units clear on the RESET path only ------------------------------------------------

## AC 8 / `4-1/R5`, first half: the debug reset leaves both boards empty.
func test_the_debug_reset_clears_the_board() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(0), InputIntent.new())
	_advance(ms, _cast_intent(1), InputIntent.new())
	assert_eq(ms.p1.units.size(), 2, "sanity: two units are on the board before the reset")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_eq(ms.p1.units.size(), 0, "the debug reset left P1's board empty")
	assert_eq(ms.p2.units.size(), 0, "...and P2's")


## AC 8 / `4-1/R5`, SECOND half and the one that is easy to get wrong: ROUND END DOES NOT CLEAR.
## The board persists through the round-over freeze rather than blinking out at the instant of
## death. A clear that migrated into _end_round would pass the test above and fail here.
func test_round_end_leaves_the_board_standing() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(1), InputIntent.new())
	assert_eq(ms.p1.units.size(), 1, "sanity: a unit is on the board")
	ms.p2.hero.take_damage(ms.p2.hero.get_max_hp())
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.DEAD,
		"sanity: the round really did end")
	assert_eq(ms.p1.units.size(), 1,
		"the board SURVIVES round end (`4-1/R5`) — only the reset clears it")


## `4-1/R5` as a source fact as well as a behavioural one: _end_round must not so much as name the
## board. The behavioural test above proves today's outcome; this refuses the edit that would make
## a future round-end path clear it while some other change happened to keep that test green.
func test_end_round_never_touches_the_board() -> void:
	var in_seam := false
	var seam_found := false
	var offenders: Array[String] = []
	for line in _code_lines("res://src/state/match_state.gd"):
		if line.begins_with("func _end_round("):
			in_seam = true
			seam_found = true
			continue
		if in_seam and line.begins_with("func "):
			break
		if line.begins_with("#"):
			continue          # a doc comment NAMING the rule is not a violation of it
		if in_seam and (line.contains("units") or line.contains("UnitBoard")):
			offenders.append(line.strip_edges())
	assert_true(seam_found, "match_state.gd must still declare _end_round (a rename un-guards this)")
	assert_eq(offenders.size(), 0,
		"_end_round must stay UNTOUCHED by the board (`4-1/R5`): %s" % ", ".join(offenders))


# --- AC 9: the snapshot key is counts-only ---------------------------------------------------

## AC 9: the board's snapshot key carries a COUNT and nothing else — no identity, no effect id, no
## position. Asserted by TYPE as well as by value, because "counts only" is a statement about what
## can reach the canonical hash, and an int is the whole of what may.
func test_the_board_snapshot_key_is_a_plain_count() -> void:
	var ms := _make_match()
	assert_eq(ms.p1.to_snapshot()["unit_count"], 0, "an empty board snapshots as 0")
	_advance(ms, _cast_intent(1), InputIntent.new())
	var snap: Dictionary = ms.p1.to_snapshot()
	assert_eq(typeof(snap["unit_count"]), TYPE_INT,
		"the board key is a plain INT — no identity, no effect id, no position (AC 9)")
	assert_eq(snap["unit_count"], 1, "...and it is the board's count")
	assert_eq(snap["unit_count"], ms.p1.units.size(), "...read off the board itself")


## AC 9, the negative half: NOTHING resembling an identity, an effect id or a position appears
## anywhere in the per-player snapshot. Scanned over the whole flattened snapshot rather than the
## one key, so a second board key smuggled in elsewhere is caught too.
func test_no_effect_id_or_position_reaches_the_snapshot() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(1), InputIntent.new())
	var offenders: Array[String] = []
	_scan_snapshot(ms.p1.to_snapshot(), "", offenders)
	assert_eq(offenders.size(), 0,
		"a StringName or an object reached the per-player snapshot (AC 9 counts-only): %s"
				% ", ".join(offenders))


# --- helpers ---------------------------------------------------------------------------------

## IDENTITIES AND OBJECTS, the two kinds of value that must never reach the canonical hash. A
## StringName is the measured failure mode (Array[StringName].sort() orders by internal POINTER on
## this engine, deterministic within one process and NOT across runs); an object has no
## CanonicalHash branch at all and falls through to a per-allocation instance id.
##
## VECTORS ARE NOT BANNED HERE, deliberately: HeroState's velocity, facing and roll_direction are
## long-standing HASHED members and this scan is not the place to relitigate them. AC 9's "no
## position" claim is about THIS story's key, and it is proven directly by the TYPE_INT assertion
## in the test above — a Vector under `unit_count` would fail there.
func _scan_snapshot(value: Variant, path: String, offenders: Array[String]) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			for key: Variant in value:
				_scan_snapshot(value[key], "%s/%s" % [path, key], offenders)
		TYPE_ARRAY:
			var n := 0
			for item: Variant in value:
				_scan_snapshot(item, "%s[%d]" % [path, n], offenders)
				n += 1
		TYPE_STRING_NAME, TYPE_STRING, TYPE_OBJECT:
			offenders.append("%s (%s)" % [path, type_string(typeof(value))])


func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("effect_card_%02d" % i))
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = CARD_COST
		out[id] = c
	return out


func _effect(effect_id: StringName) -> CardEffect:
	var e := CardEffect.new()
	e.effect_id = effect_id
	return e


## Every id mapped to an effect carrying `prefix` plus the id — the shape all three whole-map
## helpers below share.
func _effects_all(prefix: StringName) -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id in _deck_contents():
		out[id] = _effect(StringName("%s%s" % [prefix, id]))
	return out


func _summon_effects() -> Dictionary[StringName, CardEffect]:
	return _effects_all(&"summon_")


func _all_spell_effects() -> Dictionary[StringName, CardEffect]:
	return _effects_all(&"spell_")


## A map in which exactly ONE id summons and every other id is a spell — the discriminating
## fixture behind test_the_resolver_is_keyed_by_the_id_actually_cast.
func _effects_where_only(summon_id: StringName) -> Dictionary[StringName, CardEffect]:
	var out := _all_spell_effects()
	out[summon_id] = _effect(StringName("summon_%s" % summon_id))
	return out


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.max_mana = 90.0
	c.max_stamina = 40.0
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	# Story 4-4 (AC 1): the cast seat resolves a summon's KIND before it appends a record, so a
	# fixture authoring no kinds would have every summon here resolve SUCCESSFULLY and put nothing on
	# the board — the honest behaviour for an unauthored kind (see the seat), but not what these
	# tests are measuring. One minion kind at index 0, which is what an unmapped `summon_*` id
	# resolves to (`CardEffectResolver.KIND_MINION`).
	c.unit_kinds = UnitKindFixture.minion_only(9.0, 3.0, 0, 0, 0, 2.0)
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.minions = true
	return f


## A match with a dealt hand, mana on the board, and effects injected in the runner's own order
## (deck -> costs -> effects, `4-1/R8`).
func _make_match(effects: Dictionary = {}, flags: FeatureFlags = null) -> MatchState:
	var ms := _bare_match(flags)
	ms.inject_card_effects(effects if not effects.is_empty() else _summon_effects())
	return _deal_and_fund(ms)


## The SAME fixture with the effects seam never called — the state of every MatchState fixture
## that predates this story, and the directed subject of AC 6(i).
func _make_match_without_effects() -> MatchState:
	return _deal_and_fund(_bare_match(null))


func _bare_match(flags: FeatureFlags) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_feature_flags(flags if flags != null else _flags())
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	return ms


## The deal happens at step 6 of the FIRST advance(), so one tick runs here and the mana is
## granted after it — the pool starts empty by ManaPool's own contract and the flywheel is not
## what these tests exercise.
func _deal_and_fund(ms: MatchState) -> MatchState:
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()
	ms.p1.mana.add(START_MANA)
	ms.p2.mana.add(START_MANA)
	ms.drain_signals()
	return ms


func _cast_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.BASIC
	i.card_commit = true
	return i


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()


func _code_lines(path: String) -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		out.append(f.get_line().strip_edges(true, false))
	f.close()
	return out
