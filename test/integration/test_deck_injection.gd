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

## The nine authored ids in ASCENDING order — what sorted_ids() must return.
const EXPECTED_SORTED_IDS: Array[StringName] = [
	&"bramble_snare", &"ember_lash", &"frost_dart", &"hellforge_totem", &"imp_summoner",
	&"storm_kite", &"thornback_guardian", &"tidal_wardstone", &"verdant_wardstone",
]

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
	if state != null and config != null and db != null:
		seam_ok = state.p1.deck.size() > 0 and state.p2.deck.size() > 0
		if not seam_ok:
			_notes.append("live decks are EMPTY — the injection seam did not reach state")
		counts_ok = _check_counts(state, config)
		composition_ok = _check_composition(state, db, config)
	else:
		_notes.append("could not reach runner / MatchState / CardDatabase / authored config")

	var ok := sorted_ok and seam_ok and counts_ok and composition_ok
	print("deck_injection: sorted=%s seam=%s counts=%s composition=%s | %s" % [
		sorted_ok, seam_ok, counts_ok, composition_ok, "; ".join(_notes)])
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


## AC 4. Deck + hand is the injected composition; check the walk's rule on it directly.
func _check_composition(state: MatchState, db: Node, config: BalanceConfig) -> bool:
	var all: Array = state.p1.deck.to_array()
	all.append_array(state.p1.hand.occupied_ids())
	var counts: Dictionary = {}
	for id: StringName in all:
		counts[id] = int(counts.get(id, 0)) + 1
	var ok := true
	if all.size() != config.deck_size:
		_notes.append("composition holds %d, authored deck_size %d" % [all.size(), config.deck_size])
		ok = false
	# Every id honours its own max_copies, and at least one is AT the cap (non-vacuity: a walk
	# that ignored max_copies entirely would still pass the <= check if no card ever reached it).
	var any_at_cap := false
	for id: StringName in counts:
		var card := db.get_card(id) as CardData
		if card == null:
			_notes.append("composition holds unknown id %s" % id)
			ok = false
			continue
		if int(counts[id]) > card.max_copies:
			_notes.append("%s appears %d times, max_copies %d" % [id, int(counts[id]), card.max_copies])
			ok = false
		if int(counts[id]) == card.max_copies:
			any_at_cap = true
	if not any_at_cap:
		_notes.append("no card reached its max_copies — the cap is unproven on this data")
		ok = false
	# THE RULE ITSELF: sorted-order PREFIX fill. Walking sorted_ids(), no id may be taken unless
	# every id before it was already at its cap. A composition assembled in any other order (or
	# from an unsorted accessor) breaks this even when the totals happen to match.
	var exhausted_prefix := true
	for id: StringName in db.sorted_ids():
		var card := db.get_card(id) as CardData
		var taken := int(counts.get(id, 0))
		if taken > 0 and not exhausted_prefix:
			_notes.append("%s was taken while an earlier sorted id was below its cap" % id)
			ok = false
		if card == null or taken < card.max_copies:
			exhausted_prefix = false
	return ok
