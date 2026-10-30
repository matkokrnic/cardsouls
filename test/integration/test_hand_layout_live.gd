extends SceneTree

## Story 7-11 (R6, G3, G4, AC 12/AC 14/AC 15): THE HAND LAYOUT AND THE ARM-HINT BLINK THROUGH THE LIVE RUNNER -- the
## wiring the standalone `test_hand_layouts.gd` cannot reach. P1 on the keyboard, P2 on a GAMEPAD slot whose override
## file (under an injected root outside `user://` and the repo, AC 11) swaps only the LEFT and RIGHT slots:
##   - P2's root renders ROW+GLYPH -- the SHIPPED default layout, end to end (the file does not name a layout) -- with
##     badges following ITS map: slot 1 shows RIGHT, slot 4 shows LEFT (the runner pushes the slot's own profile);
##   - P1's root, a keyboard slot, renders ROW with no badge (G4);
##   - a P1 card play with NOTHING armed is refused by state and blinks P1's root -- never P2's (secret, 2-4/R4);
##   - a P1 play refused while a slot IS armed does not blink (AC 14 keys on `armed_slot() == -1`).
## The refusals are observed on state's own `action_rejected` (a test may subscribe; the HUD may not), so neither
## blink check can pass vacuously.
##
## Run: godot --headless --path . --script res://test/integration/test_hand_layout_live.gd

const SUBDIR := "cardsouls_7_11_layout_live"
const GAMEPAD := 3   # MatchRunner.ControllerKind.GAMEPAD
const KEYBOARD_P1 := 0

var _frames := 0
var _main: Node
var _state: MatchState
var _ok := true
var _root := ""
var _huds: Array[HudRoot] = []
var _phase := 0
var _clock := 0.0
var _p1_blinked := false
var _p2_blinked := false
var _refusals: Array = []   # [armed slot at the refusal]


func _initialize() -> void:
	_root = _override_root()
	var f := FileAccess.open(GamepadProfile.override_path(_root, 2), FileAccess.WRITE)
	f.store_string("# left and right swapped; the layout is NOT named, so the shipped default applies\n"
			+ "dpad_left_slot = 3\ndpad_right_slot = 0\n")
	f.close()
	var runner := (load("res://src/main/main.tscn") as PackedScene).instantiate()
	runner.seed_override = 12345
	runner.slot_controller_kinds.assign([KEYBOARD_P1, GAMEPAD])
	runner.controls_override_root = _root
	root.add_child(runner)


func _fail(msg: String) -> void:
	_ok = false
	print("FAIL: " + msg)


func _override_root() -> String:
	var temp := OS.get_environment("TEMP")
	if temp.is_empty():
		temp = OS.get_environment("TMP")
	if temp.is_empty():
		temp = "/tmp"
	var path := temp.replace("\\", "/").trim_suffix("/") + "/" + SUBDIR
	DirAccess.make_dir_recursive_absolute(path)
	return path


func _any_cue_playing() -> bool:
	for player in root.find_children("*", "AudioStreamPlayer", true, false):
		if (player as AudioStreamPlayer).playing:
			return true
	return false


func _on_p1_rejected(action: StringName, _reason: StringName) -> void:
	if action == &"card_cast":
		_refusals.append(_main._p1_controller.armed_slot())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_main = root.get_node("Main")
		_state = _main._match_state
		_state.p1.hero.action_rejected.connect(_on_p1_rejected)
		_huds.assign([root.get_node("Main/P1View/P1Viewport/HudRoot"), root.get_node("Main/P2View/P2Viewport/HudRoot")])
		_check_layouts()
	if _frames == 4:
		# --- nothing armed: the play is refused and the OWN root blinks ---
		if _main._p1_controller.armed_slot() != -1:
			_fail("sanity: P1 has a slot armed before the nothing-armed press")
		Input.action_press(&"p1_cast_confirm")
		_phase = 1
		_clock = 0.0
	if _frames == 6:
		Input.action_release(&"p1_cast_confirm")
	if _phase == 1 or _phase == 3:
		_p1_blinked = _p1_blinked or _huds[0].arm_hint_blinking()
		_p2_blinked = _p2_blinked or _huds[1].arm_hint_blinking()
	if _phase == 1 and _clock >= HudRoot.ARM_HINT_BLINK_SEC + 0.3 and not _huds[0].arm_hint_blinking():
		if _refusals != [-1]:
			_fail("sanity: the nothing-armed press was not refused exactly once with nothing armed: %s" % [_refusals])
		if not _p1_blinked:
			_fail("AC 14: a refused nothing-armed play did not blink P1's own root")
		if _p2_blinked:
			_fail("AC 14: P1's refusal blinked P2's root (the blink is own-half only)")
		# --- armed: arm slot 1 with its key, stun P1 so the play is refused, then play ---
		_p1_blinked = false
		_p2_blinked = false
		Input.action_press(&"p1_card_1")
		_phase = 2
	elif _phase == 2 and _main._p1_controller.armed_slot() == 0:
		Input.action_release(&"p1_card_1")
		_state.p1.hero.action_state = HeroState.ActionState.STUNNED
		_state.p1.hero.stun.start(_state.balance_ticks.knockdown_stun_ticks)
		Input.action_press(&"p1_cast_confirm")
		_phase = 3
		_clock = 0.0
	elif _phase == 3 and _clock >= HudRoot.ARM_HINT_BLINK_SEC + 0.3:
		Input.action_release(&"p1_cast_confirm")
		if _refusals.size() != 2 or _refusals[1] != 0:
			_fail("sanity: the armed play was not refused while slot 1 stayed armed: %s" % [_refusals])
		if _p1_blinked or _p2_blinked:
			_fail("AC 14: a play refused WHILE ARMED blinked (p1 %s, p2 %s)" % [_p1_blinked, _p2_blinked])
		_phase = 4
	if _phase == 4 and (not _any_cue_playing() or _frames >= 2000):
		if _any_cue_playing():
			_fail("a cue was still playing at the wait bound; quitting now would leak a resource")
		DirAccess.remove_absolute(GamepadProfile.override_path(_root, 2))
		print("hand layout live: ok=%s" % _ok)
		print("RESULT: %s" % ("PASS" if _ok else "FAIL"))
		quit(0 if _ok else 1)
	return false


func _process(delta: float) -> bool:
	_clock += delta
	return false


## P2 (pad, override swaps left/right, shipped layout): ROW+GLYPH badges [RIGHT, UP, DOWN, LEFT]. P1 (keyboard): ROW,
## no badge. Both rest on the arc.
func _check_layouts() -> void:
	var p1: Array = []
	var p2: Array = []
	for i in 4:
		p1.append(_huds[0].badge_direction(i))
		p2.append(_huds[1].badge_direction(i))
	if p2 != [3, 1, 2, 0]:
		_fail("AC 12: P2's badges %s, want the shipped ROW+GLYPH following its swapped map [3, 1, 2, 0]" % [p2])
	if p1 != [-1, -1, -1, -1]:
		_fail("AC 12 / G4: the keyboard slot shows badges %s, want ROW (none)" % [p1])
	for hud: HudRoot in _huds:
		for i in 4:
			if not is_equal_approx(hud.card_lift(i), 0.0) \
					or not is_equal_approx((hud.get_node("HandStrip/Card%d" % i) as Control).position.y,
					-HudRoot.ARC_RAISE_PX if i in [1, 2] else 0.0):
				_fail("AC 12: %s slot %d is not on the arc" % [hud.get_path(), i])
