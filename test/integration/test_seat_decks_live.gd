extends SceneTree

## Story 7-5a (AC 7-9, 11, 12; `7-5a/R26`): PER-SEAT DECKS ON THE REAL `main.tscn`, booted in sequence in one
## process (each runner freed before the next enters the tree), every boot on the same pinned seed:
##
##   A. the SHIPPED setting                 -> both seats Deck 1; the F3 text names both; each HUD reel is Deck 1's.
##   B. a setting file naming [deck_2, deck_1] -> P1 holds Deck 2, P2 holds Deck 1; P1's reel is Deck 2's; F3 says so.
##   C. B's recorded stream as the REPLAY, with the setting ABSENT and a conflicting test override
##                                          -> the RECORD wins: B's deal exactly, B's names in the F3 text (AC 11).
##   D. a MISSING setting file              -> the default, both seats Deck 1, and A's deal exactly (AC 9).
##   E. the one-list test override over B's setting file -> the override wins: both seats the override list (AC 8).
##   F. the per-seat test override           -> each seat its own override list.
##   G. a setting naming an UNKNOWN deck     -> the match REFUSES TO START with a named error (`7-5a/R26`).
##
## The setting tier is exercised through `deck_select_path` (a `user://` file this test writes and removes), so
## `data/deck_select.tres` on disk is never touched.
##
## Run: godot --headless --path . --script res://test/integration/test_seat_decks_live.gd

const READ_AFTER := 4
const SEED := 12345
const SETTING_PATH := "user://test_seat_decks_setting.tres"
const UNKNOWN_SETTING_PATH := "user://test_seat_decks_unknown.tres"
const MISSING_SETTING_PATH := "user://test_seat_decks_no_such_file.tres"
const WRONG_TYPE_SETTING_PATH := "user://test_seat_decks_wrong_type.tres"
const ONE_SEAT_SETTING_PATH := "user://test_seat_decks_one_seat.tres"
const THREE_SEAT_SETTING_PATH := "user://test_seat_decks_three_seats.tres"
const RUNNER_SCRIPT := "res://src/main/match_runner.gd"

var _frames := 0
var _phase := 0
var _phase_frame := 0
var _runner: Node
var _failures: Array[String] = []
var _checks := 0

var _deck_1: DeckList
var _deck_2: DeckList
var _hands_a: Array = []
var _hands_b: Array = []
var _stream_b: IntentRecorder


func _initialize() -> void:
	_deck_1 = load("res://data/decks/deck_1.tres") as DeckList
	_deck_2 = load("res://data/decks/deck_2.tres") as DeckList
	_check(_deck_1 != null and _deck_2 != null, "both authored deck lists load")
	_check(_expanded(_deck_1) != _expanded(_deck_2), "non-vacuity: the two decks are different compositions")
	_write_setting(SETTING_PATH, [&"deck_2", &"deck_1"])
	_write_setting(UNKNOWN_SETTING_PATH, [&"deck_1", &"deck_9_no_such_deck"])
	_write_setting(ONE_SEAT_SETTING_PATH, [&"deck_2"])
	_write_setting(THREE_SEAT_SETTING_PATH, [&"deck_1", &"deck_2", &"deck_1"])
	_check(ResourceSaver.save(DeckList.new(), WRONG_TYPE_SETTING_PATH) == OK, "the wrong-type setting was written")
	_check_static_resolution()
	_boot({})


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(label)


func _write_setting(path: String, names: Array[StringName]) -> void:
	var setting := DeckSelect.new()
	setting.seat_decks = names
	_check(ResourceSaver.save(setting, path) == OK, "the test setting %s was written" % path)


## The setting's two static halves, with no scene: a missing setting and a malformed one read as the default,
## and an unknown name (or an empty one) is a NAMED error.
func _check_static_resolution() -> void:
	var runner_script: GDScript = load(RUNNER_SCRIPT)
	_check(runner_script.seat_deck_names_from(null) == ["deck_1", "deck_1"],
		"AC 9: no setting at all means both seats Deck 1")
	_check(runner_script.setting_error(MISSING_SETTING_PATH) == "",
		"AC 9: a MISSING setting file is not an error -- it means the default")
	_check(runner_script.setting_error(SETTING_PATH) == "", "AC 9: a sound setting is not an error")
	var wrong_type: String = runner_script.setting_error(WRONG_TYPE_SETTING_PATH)
	_check(wrong_type.contains("not a DeckSelect"),
		"F2: a setting file that is not a DeckSelect is a named error: '%s'" % wrong_type)
	var one_seat: String = runner_script.setting_error(ONE_SEAT_SETTING_PATH)
	_check(one_seat.contains("1 decks") and one_seat.contains("(2)"),
		"F2: a setting naming one deck is a named error: '%s'" % one_seat)
	var three_seats: String = runner_script.setting_error(THREE_SEAT_SETTING_PATH)
	_check(three_seats.contains("3 decks"), "F2: a setting naming three decks is a named error: '%s'" % three_seats)
	_check(runner_script.unknown_deck_error(["deck_1", "deck_2"] as Array[String]) == "",
		"AC 9: both authored decks are known")
	var error: String = runner_script.unknown_deck_error(["deck_1", "deck_9_no_such_deck"] as Array[String])
	_check(error.contains("deck_9_no_such_deck") and error.contains("seat 2"),
		"R26: an unknown deck is a named error -- which seat, which name: '%s'" % error)
	_check(runner_script.unknown_deck_error(["", "deck_1"] as Array[String]).contains("seat 1"),
		"R26: an EMPTY name is an unknown deck too, never a silent default")
	_check(DebugInstrumentPanel.deck_text(["deck_2", "deck_1"] as Array[String]) == "P1 deck_2 | P2 deck_1",
		"AC 12: the F3 text builder names the deck each seat is on")
	_check(DebugInstrumentPanel.deck_text(["", ""] as Array[String]) == "P1 ? | P2 ?",
		"AC 12: a seat with no recorded name reads `?`, not a gap")


## `options`: setting (String path), record (IntentRecorder), override (DeckList), seat_overrides (Array[DeckList]).
func _boot(options: Dictionary) -> void:
	_runner = load("res://src/main/main.tscn").instantiate()
	_runner.seed_override = SEED
	if options.has("setting"):
		_runner.deck_select_path = options["setting"]
	if options.has("record"):
		_runner.replay_record = options["record"]
	if options.has("override"):
		_runner.deck_list_override = options["override"]
	if options.has("seat_overrides"):
		_runner.seat_deck_list_overrides = options["seat_overrides"]
	root.add_child(_runner)
	_phase_frame = _frames


func _expanded(list: DeckList) -> Array[String]:
	var out: Array[String] = []
	for index in list.card_ids.size():
		for _copy in list.copies[index]:
			out.append(String(list.card_ids[index]))
	out.sort()
	return out


## Everything a seat holds (pile + hand), sorted -- its composition as dealt.
func _holding(slot: int) -> Array[String]:
	var player: PlayerState = _runner._match_state.p1 if slot == 0 else _runner._match_state.p2
	var out: Array[String] = []
	for id: StringName in player.deck.to_array():
		out.append(String(id))
	for id: StringName in player.hand.occupied_ids():
		out.append(String(id))
	out.sort()
	return out


func _hands() -> Array:
	return [_runner._match_state.p1.hand.to_array(), _runner._match_state.p2.hand.to_array()]


func _reel(slot: int) -> Array:
	return (_runner._huds[slot] as HudRoot)._reel_cards.duplicate()


func _deck_label() -> String:
	var label := _runner.find_child("DeckLabel", true, false) as Label
	return label.text if label != null else "<no DeckLabel>"


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames - _phase_frame != READ_AFTER:
		return false
	match _phase:
		0:
			_hands_a = _hands()
			_check(_holding(0) == _expanded(_deck_1) and _holding(1) == _expanded(_deck_1),
				"A: the shipped setting deals BOTH seats Deck 1")
			_check(_deck_label() == "P1 deck_1 | P2 deck_1", "A: the F3 text names both decks: %s" % _deck_label())
			_check(_reel(0) == Array(_deck_1.card_ids) and _reel(1) == Array(_deck_1.card_ids),
				"A: each HUD's reel is Deck 1's list")
			_check(_runner.start_refusal() == "", "A: a known setting starts the match")
			_next(1, {"setting": SETTING_PATH})
		1:
			_hands_b = _hands()
			_stream_b = _runner.recorded_stream()
			_check(_holding(0) == _expanded(_deck_2), "B: seat 1 holds Deck 2 (%d cards)" % _holding(0).size())
			_check(_holding(1) == _expanded(_deck_1), "B: seat 2 holds Deck 1")
			_check(_deck_label() == "P1 deck_2 | P2 deck_1", "B: the F3 text says so: %s" % _deck_label())
			_check(_reel(0) == Array(_deck_2.card_ids), "B: seat 1's reel reads ITS OWN list (Deck 2)")
			_check(_reel(1) == Array(_deck_1.card_ids), "B: seat 2's reel reads its own list (Deck 1)")
			_check(_stream_b.replay_deck_names() == ["deck_2", "deck_1"],
				"B: the recording carries the assignment: %s" % [_stream_b.replay_deck_names()])
			_next(2, {"setting": MISSING_SETTING_PATH, "record": _stream_b, "override": _deck_1})
		2:
			_check(_hands() == _hands_b,
				"C: the REPLAY reproduces each seat's deal with the setting absent and an override set (AC 11)")
			_check(_holding(0) == _expanded(_deck_2) and _holding(1) == _expanded(_deck_1),
				"C: ...each seat on the deck the RECORD assigned it")
			_check(_deck_label() == "P1 deck_2 | P2 deck_1", "C: the F3 text reads the record: %s" % _deck_label())
			_check(_reel(0) == Array(_deck_2.card_ids), "C: seat 1's reel is rebuilt from its recorded composition")
			_next(3, {"setting": MISSING_SETTING_PATH})
		3:
			_check(_holding(0) == _expanded(_deck_1) and _holding(1) == _expanded(_deck_1),
				"D: a MISSING setting file means the default -- both seats Deck 1")
			_check(_hands() == _hands_a, "D: ...and the same seed deals exactly the shipped setting's hands")
			_next(4, {"setting": SETTING_PATH, "override": _deck_2})
		4:
			_check(_holding(0) == _expanded(_deck_2) and _holding(1) == _expanded(_deck_2),
				"E: the one-list test override outranks the setting and serves BOTH seats (AC 8)")
			_check(_deck_label() == "P1 override | P2 override", "E: the F3 text says override: %s" % _deck_label())
			_next(5, {"setting": SETTING_PATH, "seat_overrides": [_deck_1, _deck_2] as Array[DeckList]})
		5:
			_check(_holding(0) == _expanded(_deck_1) and _holding(1) == _expanded(_deck_2),
				"F: the per-seat test override gives each seat its own list, over the setting")
			_next(6, {"setting": UNKNOWN_SETTING_PATH})
		6:
			var refusal: String = _runner.start_refusal()
			_check(refusal.contains("deck_9_no_such_deck") and refusal.contains("seat 2"),
				"G: an unknown deck REFUSES the match with a named error: '%s'" % refusal)
			_check(_runner._match_state == null, "G: ...and no match was built -- never a silent Deck 1")
			_check(not _runner.is_physics_processing(), "G: ...and the tick loop is off")
			_check_refusal_on_screen("G", refusal)
			_next(7, {"setting": WRONG_TYPE_SETTING_PATH})
		7:
			_check_refusal("H: an existing setting that is not a DeckSelect", "not a DeckSelect")
			_next(8, {"setting": ONE_SEAT_SETTING_PATH})
		8:
			_check_refusal("I: a setting naming one deck", "1 decks")
			_next(9, {"setting": THREE_SEAT_SETTING_PATH})
		9:
			_check_refusal("J: a setting naming three decks", "3 decks")
			_finish()
	return false


## Review F2/F2b: the refusal is a named error, no match was built, the tick loop is off and the reason is
## on screen. Called only after READ_AFTER (> 1) frames have been pumped since the boot.
func _check_refusal(label: String, expected_fragment: String) -> void:
	var refusal: String = _runner.start_refusal()
	_check(refusal.contains(expected_fragment), "%s refuses to start with a named error: '%s'" % [label, refusal])
	_check(_runner._match_state == null and not _runner.is_physics_processing(),
		"%s: ...no match was built and the tick loop is off" % label)
	_check_refusal_on_screen(label, refusal)


func _check_refusal_on_screen(label: String, refusal: String) -> void:
	_check(_frames - _phase_frame >= 1, "%s: at least one frame was pumped after the refusal" % label)
	var shown := _runner.find_child("StartRefusalLabel", true, false) as Label
	_check(shown != null and refusal != "" and shown.text.contains(refusal) and shown.is_visible_in_tree(),
		"%s: the reason is ON SCREEN in a Label: '%s'" % [label, shown.text if shown != null else "<no label>"])


func _next(phase: int, options: Dictionary) -> void:
	_runner.free()
	_phase = phase
	_boot(options)


func _finish() -> void:
	_runner.free()
	_runner = null
	_stream_b = null
	for path: String in [SETTING_PATH, UNKNOWN_SETTING_PATH, WRONG_TYPE_SETTING_PATH, ONE_SEAT_SETTING_PATH,
			THREE_SEAT_SETTING_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _failures.is_empty():
		print("seat_decks: %d checks, all held" % _checks)
		print("RESULT: PASS")
		quit(0)
	else:
		for f in _failures:
			print("FAIL: " + f)
		print("RESULT: FAIL")
		quit(1)
