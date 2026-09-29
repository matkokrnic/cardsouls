extends SceneTree

## Story 3-3 integration: the RUNNER-SIDE half of the deck, in the LIVE boot path. The state
## harness proves the shuffle, the deal and the containers; none of it ever touches CardDatabase
## or the authored config, because src/state/ structurally cannot (AC 1/AC 8). This file is the
## only place the other side is exercised: the sorted accessor, the max_copies composition walk,
## and the injection seam actually running at match start.
##
## THIS IS ALSO THE WHOLE OF THE STORY'S LIVE-RUN PROOF, and the story says so: Live Smoke is
## NOT REQUIRED because nothing player-facing ships (no HUD, no input, no visible actor
## behaviour) and a shuffle's determinism is not observable by a human at all. What the story
## DOES put in the live boot path is the runner-side injection, and the honest proof of that is
## headless — run_all.sh greps for SCRIPT ERROR / Parse Error / INVARIANT VIOLATED, plus the
## non-empty-injected-deck assertion below.
##
##   [AC 3 sorted accessor] CardDatabase.sorted_ids() returns every loaded id exactly once, in
##     ASCENDING order, and each one still resolves through the unchanged get_card. The expected
##     list is LITERAL on purpose (the test_card_database.gd precedent): re-deriving it by
##     scanning the same directory the loader scans would make this test agree with the loader
##     about a set both got wrong.
##   [AC 4 composition walk] The live deck's multiset honours max_copies for every id, never
##     exceeds the authored deck_size, and is a PREFIX of the sorted order — that is, no id
##     appears unless every id before it in sort order was already taken to its cap. That prefix
##     property IS the composition rule, expressed without hardcoding a tunable. Non-vacuity:
##     at least one card must actually be AT its cap, or "honours max_copies" is unproven.
##   [AC 2/AC 10 the seam ran, Live Smoke] The live MatchState's decks are NON-EMPTY after the
##     boot path — the injection reached state and step 6 dealt.
##   [AC 9 counts in the live match] Both players hold hand_size cards with deck_size -
##     hand_size left, against the AUTHORED values, not repeated literals.
##
## Reaching the runner's private _match_state is a DELIBERATE exception to the
## observe-through-the-scene-tree discipline the other integration files keep, and the reason is
## the story's own: this story ships no presentation surface at all, so there is no node, label
## or signal to observe. The alternative is not a cleaner test — it is no test.
##
## Run: godot --headless --path . --script res://test/integration/test_deck_injection.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

## STORY 6-5a (AC 11-14) REWRITES THE COMPOSITION HALF OF THIS FILE, each rewrite named where it happens.
## The composition is no longer a sorted-prefix walk of the library up to each `max_copies`: it is the
## AUTHORED DECK LIST (`data/decks/deck_1.tres`) expanded in list order. The sorted ACCESSOR is still a
## library-wide CardDatabase fact and is still pinned below, now over sixteen ids.

## The authored ids in ASCENDING order — what sorted_ids() must return. REWRITTEN BY STORY 6-5a
## (AC 13): nine -> sixteen, the whole library (Deck 1's seven plus the nine dormant fixtures, R1).
## STORY 6-5e (AC 4/AC 22): SIXTEEN -> SEVENTEEN. `boulder` sorts between `bloodhound_step` and
## `bramble_snare`. It is in the LIBRARY (and therefore in every derived map the runner injects, which is
## what makes a planted Boulder priceable and clearable at all) and in NO DECK -- the composition comes from
## the authored `DeckList`, so the exclusion is by construction rather than by a list this test would have
## to keep in agreement. `test_the_deck_list_is_exactly_deck_1` and this file's own composition check are
## what prove it never reaches a deck.
const EXPECTED_SORTED_IDS: Array[StringName] = [
	&"bloodhound_step", &"boulder", &"bramble_snare", &"drain", &"ember_lash", &"frost_dart",
	&"frostbite", &"grave_ward", &"hellforge_totem", &"honed_bolt", &"imp_summoner", &"rocksling",
	&"ruin_vanguard", &"storm_kite", &"thornback_guardian", &"tidal_wardstone", &"verdant_wardstone",
]

## Story 6-5a (AC 13/AC 14): Deck 1's seven ids and their copies, in LIST order -- LITERAL on purpose,
## the same don't-re-derive-from-the-thing-under-test reason as the list above. The injected
## composition must be exactly these, each repeated its copies, in this order.
const DECK_1_IDS: Array[StringName] = [
	&"ruin_vanguard", &"grave_ward", &"drain", &"rocksling", &"bloodhound_step", &"honed_bolt",
	&"frostbite",
]
const DECK_1_COPIES: Array[int] = [3, 3, 3, 3, 3, 2, 3]

var _frames := 0
var _notes: Array[String] = []


func _initialize() -> void:
	root.add_child(load("res://src/main/main.tscn").instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false  # let _ready() and the first advance() land
	var sorted_ok := _check_sorted_accessor()
	var db: Node = root.get_node_or_null("/root/CardDatabase")
	var runner: Node = root.get_node_or_null("Main")
	var state: MatchState = runner._match_state if runner != null else null
	var config := load("res://data/balance/balance_config.tres") as BalanceConfig
	var seam_ok := false
	var counts_ok := false
	var composition_ok := false
	var pitch_ok := false
	if state != null and config != null and db != null:
		seam_ok = state.p1.deck.size() > 0 and state.p2.deck.size() > 0
		if not seam_ok:
			_notes.append("live decks are EMPTY — the injection seam did not reach state")
		counts_ok = _check_counts(state, config)
		composition_ok = _check_composition(state, db, config)
		pitch_ok = _check_pitch_costs(runner, state, db) and _check_pitch_effects(runner, state, db)
	else:
		_notes.append("could not reach runner / MatchState / CardDatabase / authored config")

	var ok := sorted_ok and seam_ok and counts_ok and composition_ok and pitch_ok
	print("deck_injection: sorted=%s seam=%s counts=%s composition=%s pitch=%s | %s" % [
		sorted_ok, seam_ok, counts_ok, composition_ok, pitch_ok, "; ".join(_notes)])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true


## AC 3. Reached through /root/CardDatabase — the REAL autoload the project boots, never a
## private instance the test constructs (a test that instantiated the script itself would pass
## even if the autoload registration were removed from project.godot).
func _check_sorted_accessor() -> bool:
	var db: Node = root.get_node_or_null("/root/CardDatabase")
	if db == null:
		_notes.append("CardDatabase autoload missing")
		return false
	var ids: Array = db.sorted_ids()
	if ids != EXPECTED_SORTED_IDS:
		_notes.append("sorted_ids() = %s, expected %s" % [ids, EXPECTED_SORTED_IDS])
		return false
	if ids.size() != db.card_count():
		_notes.append("sorted_ids() size %d != card_count() %d" % [ids.size(), db.card_count()])
		return false
	for id: StringName in ids:
		if not (db.get_card(id) is CardData):
			_notes.append("sorted id %s does not resolve through the unchanged get_card" % id)
			return false
	# A COPY, not the backing store: mutating the result must not disturb the next read.
	ids.clear()
	if db.sorted_ids().size() != db.card_count():
		_notes.append("sorted_ids() handed out its backing array")
		return false
	return true


## AC 9, against the AUTHORED values rather than repeated literals, so a legitimate tuning edit
## to deck_size / hand_size moves this test's expectations with it instead of breaking it.
func _check_counts(state: MatchState, config: BalanceConfig) -> bool:
	var ok := true
	for slot: Array in [[0, state.p1], [1, state.p2]]:
		var player: PlayerState = slot[1]
		# Story 4-0 (AC 5): occupancy AND width. Post-deal both equal hand_size — every slot holds
		# a card and none holds a hole — and asserting them separately is what makes a deal that
		# left a trailing hole fail here rather than pass on a coincidence of counts.
		if player.hand.occupied_count() != config.hand_size:
			_notes.append("p%d hand %d != authored hand_size %d" % [
				int(slot[0]) + 1, player.hand.occupied_count(), config.hand_size])
			ok = false
		if player.hand.size() != config.hand_size:
			_notes.append("p%d hand WIDTH %d != authored hand_size %d" % [
				int(slot[0]) + 1, player.hand.size(), config.hand_size])
			ok = false
		if player.deck.size() != config.deck_size - config.hand_size:
			_notes.append("p%d deck %d != deck_size - hand_size %d" % [
				int(slot[0]) + 1, player.deck.size(), config.deck_size - config.hand_size])
			ok = false
	return ok


## Story 6-2 (AC 2/AC 16): the runner DERIVES the pitch-cost map from the live CardDatabase, INJECTS it
## into MatchState and CAPTURES it on the recorder -- all three checked against the library itself: an
## entry for exactly the cards that author a `pitch_condition` (all nine today, AC 1a), the SAME authored
## condition reaching state, and the same ids on the record. Private `_pitch_costs` is read for this
## file's stated reason: no presentation surface exists for pitch content until 6-3.
func _check_pitch_costs(runner: Node, state: MatchState, db: Node) -> bool:
	var expected: Array[StringName] = []
	for id: StringName in db.sorted_ids():
		var card := db.get_card(id) as CardData
		if card != null and card.pitch_condition != null:
			expected.append(id)
	if expected.is_empty():
		_notes.append("no authored card carries a pitch_condition -- the check below would be vacuous")
		return false
	# Compared as sorted STRINGS: Array[StringName].sort() orders by internal POINTER on this engine.
	var injected := _sorted_strings(state._pitch_costs.keys())
	if injected != _sorted_strings(expected):
		_notes.append("injected pitch-cost ids %s != authored %s" % [injected, expected])
		return false
	for id: StringName in expected:
		if state._pitch_costs[id] != (db.get_card(id) as CardData).pitch_condition:
			_notes.append("injected pitch cost for %s is not the authored condition" % id)
			return false
	var recorded := _sorted_strings((runner.recorded_stream() as IntentRecorder).replay_pitch_costs().keys())
	if recorded != _sorted_strings(expected):
		_notes.append("recorded pitch-cost ids %s != authored %s" % [recorded, expected])
		return false
	return true


func _sorted_strings(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in ids:
		out.append(String(id))
	out.sort()
	return out


## Story 6-5a (AC 6): the PITCH-EFFECT map, derived from the live library, injected, and captured -- the
## pitch-cost check directly above verbatim: exactly the cards that author a `pitch_effect` (Deck 1's
## seven), the SAME authored resource reaching state, and the same ids on the record.
func _check_pitch_effects(runner: Node, state: MatchState, db: Node) -> bool:
	var expected: Array[StringName] = []
	for id: StringName in db.sorted_ids():
		var card := db.get_card(id) as CardData
		if card != null and card.pitch_effect != null:
			expected.append(id)
	if _sorted_strings(expected) != _sorted_strings(DECK_1_IDS):
		_notes.append("library pitch effects %s != Deck 1's seven" % [expected])
		return false
	var injected := _sorted_strings(state._pitch_effects.keys())
	if injected != _sorted_strings(expected):
		_notes.append("injected pitch-effect ids %s != authored %s" % [injected, expected])
		return false
	for id: StringName in expected:
		if state._pitch_effects[id] != (db.get_card(id) as CardData).pitch_effect:
			_notes.append("injected pitch effect for %s is not the authored effect" % id)
			return false
	var recorded := _sorted_strings((runner.recorded_stream() as IntentRecorder).replay_pitch_effects().keys())
	if recorded != _sorted_strings(expected):
		_notes.append("recorded pitch-effect ids %s != authored %s" % [recorded, expected])
		return false
	return true


## AC 4. Deck + hand is the injected composition; check the walk's rule on it directly.
## REWRITTEN BY STORY 6-5a (AC 13/AC 14): the rule is now the DECK LIST's. The composition's size is the
## list's copy sum (and the authored `deck_size`, 20); its multiset is exactly the list's per-entry
## copies -- each within `max_copies` -- and it holds no id the list does not name; and the PRE-SHUFFLE
## order (the recorded composition, which is what reached `inject_deck`) is the list expanded in list
## order. That last clause REPLACES 3-3's sorted-prefix fill rule, which the deck list abolishes.
func _check_composition(state: MatchState, db: Node, config: BalanceConfig) -> bool:
	var all: Array = state.p1.deck.to_array()
	all.append_array(state.p1.hand.occupied_ids())
	var counts: Dictionary = {}
	for id: StringName in all:
		counts[id] = int(counts.get(id, 0)) + 1
	var ok := true
	var list_sum := 0
	for copies in DECK_1_COPIES:
		list_sum += copies
	if all.size() != list_sum or all.size() != config.deck_size:
		_notes.append("composition holds %d; Deck 1's copy sum %d, authored deck_size %d" % [
			all.size(), list_sum, config.deck_size])
		ok = false
	# Re-derived from the DECK LIST's per-entry copies (was: max_copies / at-cap): every listed id
	# appears exactly its listed copies, within its own max_copies, and nothing unlisted appears.
	for index in DECK_1_IDS.size():
		var id := DECK_1_IDS[index]
		var card := db.get_card(id) as CardData
		if card == null:
			_notes.append("Deck 1 id %s is not in the library" % id)
			ok = false
			continue
		if int(counts.get(id, 0)) != DECK_1_COPIES[index]:
			_notes.append("%s appears %d times, the list says %d" % [id, int(counts.get(id, 0)),
				DECK_1_COPIES[index]])
			ok = false
		if DECK_1_COPIES[index] > card.max_copies:
			_notes.append("%s lists %d copies over its max_copies %d" % [id, DECK_1_COPIES[index],
				card.max_copies])
			ok = false
	for id: StringName in counts:
		if not DECK_1_IDS.has(id):
			_notes.append("composition holds %s, which Deck 1 does not list (a fixture leaked?)" % id)
			ok = false
	# THE RULE ITSELF, rewritten: the composition that reached `inject_deck` -- the RECORDED one, taken
	# before the seeded shuffle -- is the list expanded IN LIST ORDER. Both players receive it.
	var expected_order: Array[StringName] = []
	for index in DECK_1_IDS.size():
		for _copy in DECK_1_COPIES[index]:
			expected_order.append(DECK_1_IDS[index])
	var runner: Node = root.get_node_or_null("Main")
	var recorded: Array[StringName] = (runner.recorded_stream() as IntentRecorder).replay_deck_contents()
	if recorded != expected_order:
		_notes.append("injected composition %s is not Deck 1 in list order" % [recorded])
		ok = false
	var p2_all: Array = state.p2.deck.to_array()
	p2_all.append_array(state.p2.hand.occupied_ids())
	if _sorted_strings(p2_all) != _sorted_strings(all):
		_notes.append("P2's composition differs from P1's -- both players get Deck 1 (AC 11)")
		ok = false
	return ok
