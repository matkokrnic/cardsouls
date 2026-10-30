extends TestCase

## Story 7-11 (R5, R6, AC 10/AC 11/AC 12 data half): THE PER-SLOT GAMEPAD PROFILE and its `user://` override.
##
## NO TEST HERE READS OR WRITES THE REAL `user://` (AC 11). Every override file is written under an injected
## root in the OS temp directory -- outside `user://` AND outside the repo, both asserted by
## `test_the_test_root_is_outside_user_and_the_repo` through the same containment helper the loader uses --
## and removed again by the test that wrote it.
##
## FALLBACK (the dev call, stated in the loader's doc): a key ABSENT from the file keeps the default, field by
## field; ANY defect refuses the WHOLE file and the slot gets the shipped default. The wholesale half is made
## non-vacuous by putting one VALID line in every defective file -- a partial apply would show it.

const SUBDIR := "cardsouls_7_11_override_test"


func test_the_test_root_is_outside_user_and_the_repo() -> void:  # 7-11 AC 11
	var root := _root()
	assert_false(root.is_empty(), "a temp root resolves")
	assert_false(RecordFile.is_inside_root(root + "/slot_1.cfg", "user://"), "the test root is NOT inside user://")
	assert_false(RecordFile.is_inside_root(root + "/slot_1.cfg", "res://"), "the test root is NOT inside the repo")
	assert_true(RecordFile.is_inside_root(root + "/slot_1.cfg", root), "...and the override path IS inside it")


## AC 11 / M4: the lifted containment helper -- globalised, simplified, compared against the root plus its
## separator. `RecordFile`'s own guard calls it with `user://` (its tests are unchanged); this pins the
## helper with an injected root against the two measured traps of `3-0d/R22`.
func test_containment_is_by_normalisation_under_the_injected_root() -> void:  # 7-11 AC 11, 3-0d/R22
	var root := _root()
	assert_true(RecordFile.is_inside_root(root + "/slot_2.cfg", root), "a file directly under the root is inside")
	assert_true(RecordFile.is_inside_root(root + "/a/../slot_2.cfg", root), "`..` that stays inside is inside")
	assert_false(RecordFile.is_inside_root(root + "/../slot_2.cfg", root), "`..` that climbs out is refused")
	assert_false(RecordFile.is_inside_root(root + "Evil/slot_2.cfg", root),
		"a SIBLING directory sharing the root as a string prefix is refused (the trailing-separator trap)")
	assert_false(RecordFile.is_inside_root(root, root), "the root itself is not a file inside it")
	assert_eq(GamepadProfile.override_path(root + "/", 2), root + "/slot_2.cfg",
		"the override path is <root>/slot_<N>.cfg, a trailing separator on the root tolerated")
	assert_eq(GamepadProfile.override_path("user://controls", 1), "user://controls/slot_1.cfg",
		"the shipped path is user://controls/slot_<N>.cfg (named in M4)")
	assert_eq(GamepadProfile.OVERRIDE_ROOT, "user://controls", "the shipped root")


## AC 10: with no override file the slot gets the shipped default -- as its OWN instance, so one slot's
## profile can never move the other's (or the cached resource).
func test_a_missing_override_loads_the_shipped_default_as_a_fresh_instance() -> void:  # 7-11 AC 10
	var root := _root()
	_clear(root)
	var a := GamepadProfile.load_for_slot(1, root)
	var b := GamepadProfile.load_for_slot(2, root)
	var shipped: GamepadProfile = load(GamepadProfile.DEFAULT_PATH)
	assert_true(a != b and a != shipped and b != shipped, "three distinct instances")
	assert_eq(_values(a), _values(shipped), "slot 1 = the shipped default")
	assert_eq(_values(b), _values(shipped), "slot 2 = the shipped default")
	a.dpad_left_slot = 3
	assert_eq(b.dpad_left_slot, 0, "editing slot 1's profile leaves slot 2's")
	assert_eq(shipped.dpad_left_slot, 0, "...and the shipped resource")


## AC 10/AC 11: a PARTIAL file overlays exactly the keys it names (field by field); comments and blank lines
## are ignored; and each slot reads only its own file.
func test_an_override_overlays_only_its_own_slot_and_only_the_named_fields() -> void:  # 7-11 AC 10/AC 11
	var root := _root()
	_clear(root)
	_write(root, 2, "# swap left and right\n\ndpad_left_slot = 3\ndpad_right_slot = 0\n  hand_layout=2  \n")
	var p1 := GamepadProfile.load_for_slot(1, root)
	var p2 := GamepadProfile.load_for_slot(2, root)
	var shipped: GamepadProfile = load(GamepadProfile.DEFAULT_PATH)
	assert_eq(_values(p1), _values(shipped), "slot 1 has no file: the shipped default")
	assert_eq(p2.dpad_left_slot, 3, "slot 2: left now arms slot 3")
	assert_eq(p2.dpad_right_slot, 0, "slot 2: right now arms slot 0")
	assert_eq(p2.hand_layout, GamepadProfile.HandLayout.DIAMOND, "slot 2: the hand layout is data too")
	var expected := _values(shipped)
	expected["dpad_left_slot"] = 3
	expected["dpad_right_slot"] = 0
	expected["hand_layout"] = GamepadProfile.HandLayout.DIAMOND
	assert_eq(_values(p2), expected, "...and EVERY other field is the shipped default")
	_clear(root)


## AC 11: any defect refuses the WHOLE file -- never a crash, never a half-applied file. Each case carries
## a valid `hand_layout = 2` line first, so a partial apply would show as DIAMOND.
func test_a_defective_override_falls_back_wholesale() -> void:  # 7-11 AC 11
	var root := _root()
	var shipped: GamepadProfile = load(GamepadProfile.DEFAULT_PATH)
	var cases := {
		"malformed line": "dpad_left_slot 3",
		"unknown key": "cast_button = 7",
		"non-integer": "dpad_left_slot = left",
		"float": "deadzone = 0",
		"button out of range": "attack_button = 99",
		"negative": "attack_button = -1",
		"slot out of range": "dpad_left_slot = 4",
		"axis out of range": "trigger_axis_left = %d" % JOY_AXIS_SDL_MAX,
		"repeated key": "dpad_left_slot = 0\ndpad_left_slot = 1",
		"duplicate button": "run_button = 10",
		"system button": "attack_button = %d" % JOY_BUTTON_START,
		"two directions, one slot": "dpad_left_slot = 1",
		"duplicate axis": "look_axis_x = 0",
		"over-long literal": "attack_button = 99999999999999999999",
	}
	for label: String in cases:
		_clear(root)
		_write(root, 1, "hand_layout = 2\n" + cases[label] + "\n")
		var p := GamepadProfile.load_for_slot(1, root)
		assert_eq(_values(p), _values(shipped), "%s: the WHOLE file is refused, the shipped default loads" % label)
		var probe := (load(GamepadProfile.DEFAULT_PATH) as GamepadProfile).duplicate() as GamepadProfile
		assert_ne(probe.apply_override_text("hand_layout = 2\n" + cases[label] + "\n"), "",
			"%s: and the refusal names a reason" % label)
	var layout := (load(GamepadProfile.DEFAULT_PATH) as GamepadProfile).duplicate() as GamepadProfile
	assert_ne(layout.apply_override_text("hand_layout = %d" % GamepadProfile.HandLayout.size()), "",
		"a hand layout past the enum is refused")
	_clear(root)


## Review fix L1: the file shapes a Windows editor produces, through the REAL file path. Each applying file carries
## a valid line (so "applied" is observable); the lone-CR file is one long line to the parser and is refused
## wholesale; and an over-long integer literal is refused BEFORE `to_int()` (its reason names the length, which the
## conversion's own "out of range" refusal never would -- the engine's overflow ERROR print is what that avoids).
func test_file_shapes_crlf_empty_bom_lone_cr_and_over_long() -> void:  # 7-11 review fix L1
	var root := _root()
	var shipped: GamepadProfile = load(GamepadProfile.DEFAULT_PATH)
	_clear(root)
	_write(root, 1, "# crlf\r\nhand_layout = 2\r\ndpad_left_slot = 3\r\ndpad_right_slot = 0\r\n")
	var crlf := GamepadProfile.load_for_slot(1, root)
	assert_eq(crlf.hand_layout, GamepadProfile.HandLayout.DIAMOND, "a CRLF file applies")
	assert_eq(crlf.dpad_left_slot, 3, "...every line of it")
	assert_eq(crlf.dpad_right_slot, 0, "...including the last")
	for blank: String in ["", "  \n\t\n", "\r\n\r\n"]:
		_write(root, 1, blank)
		assert_eq(_values(GamepadProfile.load_for_slot(1, root)), _values(shipped),
			"an empty / whitespace-only file (%s) applies as the shipped default" % blank.c_escape())
	_write_bytes(root, 1, PackedByteArray([0xEF, 0xBB, 0xBF]) + "hand_layout = 2\r\n".to_utf8_buffer())
	assert_eq(GamepadProfile.load_for_slot(1, root).hand_layout, GamepadProfile.HandLayout.DIAMOND,
		"a UTF-8 BOM file applies through the real file path (the engine strips the BOM)")
	_write(root, 1, "hand_layout = 2\rdpad_left_slot = 3\r")
	assert_eq(_values(GamepadProfile.load_for_slot(1, root)), _values(shipped),
		"a lone-CR file is refused wholesale (one line to the parser)")
	var long := (load(GamepadProfile.DEFAULT_PATH) as GamepadProfile).duplicate() as GamepadProfile
	var reason := long.apply_override_text("hand_layout = 2\nattack_button = 99999999999999999999\n")
	assert_true(reason.contains("plausible"), "an over-long literal is refused before `to_int()`: %s" % reason)
	_clear(root)


## Review fix L2: a REFUSED text leaves the profile exactly as it was -- not even the valid lines before the
## defect land -- and a coherent text still applies to it.
func test_a_refused_text_leaves_the_profile_untouched() -> void:  # 7-11 review fix L2
	for text: String in ["hand_layout = 2\nrun_button = 4\nplay_basic_button = 5\n",  # a system button, after valid lines
			"hand_layout = 2\ndpad_left_slot = 1\n",                                   # a colliding slot map
			"hand_layout = 2\nbogus = 1\n",                                             # an unknown key
			"hand_layout = 2\nattack_button = 99999999999999999999\n"]:                # an over-long literal
		var p := (load(GamepadProfile.DEFAULT_PATH) as GamepadProfile).duplicate() as GamepadProfile
		var before := _values(p)
		assert_ne(p.apply_override_text(text), "", "the text is refused: %s" % text.c_escape())
		assert_eq(_values(p), before, "...and EVERY field equals its pre-call value: %s" % text.c_escape())
	var ok := (load(GamepadProfile.DEFAULT_PATH) as GamepadProfile).duplicate() as GamepadProfile
	assert_eq(ok.apply_override_text("hand_layout = 2\n"), "", "sanity: a coherent text applies")
	assert_eq(ok.hand_layout, GamepadProfile.HandLayout.DIAMOND, "...to this very instance")


## AC 11 sanity for the case above: the SAME valid line alone does apply, so the fallback is not a loader that
## never applies anything.
func test_a_valid_override_does_apply() -> void:  # 7-11 AC 11
	var root := _root()
	_clear(root)
	_write(root, 1, "hand_layout = 2\nplay_basic_button = %d\nrun_button = %d\n" % [JOY_BUTTON_A, JOY_BUTTON_X])
	var p := GamepadProfile.load_for_slot(1, root)
	assert_eq(p.hand_layout, GamepadProfile.HandLayout.DIAMOND, "the valid layout line applied")
	assert_eq(p.play_basic_button, JOY_BUTTON_A, "a role remap applied: BASIC on A")
	assert_eq(p.run_button, JOY_BUTTON_X, "...and run on X -- a swap is coherent")
	_clear(root)


## AC 10 through the runner: `_make_controller` builds each GAMEPAD slot its own profile from that PLAYER
## slot's file under the injected root. Off-tree, on the `test_gamepad_ordinal_is_pure_function_of_config`
## precedent (the factory touches no @onready node).
func test_the_runner_builds_each_gamepad_slot_its_own_profile() -> void:  # 7-11 AC 10
	var root := _root()
	_clear(root)
	_write(root, 2, "dpad_left_slot = 3\ndpad_right_slot = 0\n")
	var runner: Variant = load("res://src/main/match_runner.gd").new()
	runner.controls_override_root = root
	runner.slot_controller_kinds.assign([3, 3])  # [GAMEPAD, GAMEPAD]
	var c1: GamepadController = runner._make_controller(3, 0)
	var c2: GamepadController = runner._make_controller(3, 1)
	assert_true(c1._profile != c2._profile, "each pad slot holds its OWN profile instance")
	assert_eq(c1._profile.dpad_left_slot, 0, "slot 1 (no file): the default map")
	assert_eq(c2._profile.dpad_left_slot, 3, "slot 2: its own file's map")
	assert_eq(str(c2._dpad_slots), str([3, 1, 2, 0]), "...which the controller read at construction")
	runner.free()
	_clear(root)


## AC 12 (data half) / AC 10: the shipped profile AUTHORS every v2 field explicitly -- the ROW+GLYPH default
## included -- and its bindings are coherent under the same rule an override is held to.
func test_the_shipped_profile_authors_the_v2_fields_and_defaults_to_row_glyph() -> void:  # 7-11 AC 10/AC 12
	var shipped: GamepadProfile = load(GamepadProfile.DEFAULT_PATH)
	assert_eq(shipped.hand_layout, GamepadProfile.HandLayout.ROW_GLYPH, "the shipped hand layout is ROW+GLYPH")
	assert_eq(GamepadProfile.new().hand_layout, GamepadProfile.HandLayout.ROW_GLYPH, "...and so is the script default")
	assert_eq(shipped.binding_refusal(), "", "the shipped bindings are coherent (distinct, no system button)")
	var text := FileAccess.get_file_as_string(GamepadProfile.DEFAULT_PATH)
	for line: String in ["hand_layout = %d" % GamepadProfile.HandLayout.ROW_GLYPH,
			"run_button = %d" % JOY_BUTTON_A, "play_basic_button = %d" % JOY_BUTTON_X,
			"cast_pitch_button = %d" % JOY_BUTTON_Y,
			"dpad_left_button = %d" % JOY_BUTTON_DPAD_LEFT, "dpad_up_button = %d" % JOY_BUTTON_DPAD_UP,
			"dpad_down_button = %d" % JOY_BUTTON_DPAD_DOWN, "dpad_right_button = %d" % JOY_BUTTON_DPAD_RIGHT,
			"dpad_left_slot = 0", "dpad_up_slot = 1", "dpad_down_slot = 2", "dpad_right_slot = 3"]:
		assert_true(text.contains(line), "the shipped .tres authors `%s` explicitly" % line)
	for retired: String in ["cast_button", "card_mode_alt_button", "card_mode_toggle", "cast_basic_button",
			"cast_unblockable_button", "cast_defense_button"]:
		assert_false(text.contains(retired + " ="), "the shipped .tres carries no retired `%s` line" % retired)


## G5 (AC 10): no INPUT code path branches on the hand layout -- the controllers never name it. The HUD branches
## on it by design (PART B); the profile's loader only parses it as data.
func test_no_input_code_path_names_the_hand_layout() -> void:  # 7-11 AC 10 (G5)
	for path: String in ["res://src/controllers/controller.gd", "res://src/controllers/gamepad_controller.gd",
			"res://src/controllers/keyboard_controller.gd"]:
		var text := FileAccess.get_file_as_string(path)
		assert_false(text.is_empty(), "sanity: %s reads" % path)
		for token: String in ["hand_layout", "HandLayout", "ROW_GLYPH", "DIAMOND"]:
			assert_false(text.contains(token), "%s does not name `%s`" % [path.get_file(), token])


# --- helpers ---

## The injected override root: a fixed sub-directory of the OS temp directory, created on demand.
func _root() -> String:
	var temp := OS.get_environment("TEMP")
	if temp.is_empty():
		temp = OS.get_environment("TMP")
	if temp.is_empty():
		temp = "/tmp"
	var root := temp.replace("\\", "/").trim_suffix("/") + "/" + SUBDIR
	DirAccess.make_dir_recursive_absolute(root)
	return root


func _write(root: String, slot: int, text: String) -> void:
	var f := FileAccess.open(GamepadProfile.override_path(root, slot), FileAccess.WRITE)
	assert_true(f != null, "the test override file opens for writing (%d)" % FileAccess.get_open_error())
	if f != null:
		f.store_string(text)
		f.close()


func _write_bytes(root: String, slot: int, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(GamepadProfile.override_path(root, slot), FileAccess.WRITE)
	assert_true(f != null, "the test override file opens for writing (%d)" % FileAccess.get_open_error())
	if f != null:
		f.store_buffer(bytes)
		f.close()


func _clear(root: String) -> void:
	for slot in [1, 2]:
		var path := GamepadProfile.override_path(root, slot)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Every exported field of a profile, by name -- what "equals the shipped default" compares.
func _values(p: GamepadProfile) -> Dictionary:
	var out := {}
	for prop in p.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out[String(prop["name"])] = p.get(prop["name"])
	return out
