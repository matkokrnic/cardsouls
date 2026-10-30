extends SceneTree

## Story 7-11 (AC 3/AC 4/AC 6, G1, M5): THE ARM'S LIFETIME THROUGH THE LIVE RUNNER -- the relays the state
## harness cannot reach. Real keyboard presses arm both seats (the shipped [KEYBOARD_P1, KEYBOARD_P2]); what is
## proven is the runner's wiring, never a controller rule (those are pinned headless in
## test/state/test_control_scheme_v2.gd and test_gamepad_controller.gd):
##   - KNOCKDOWN and an ORDINARY stun leave the arm (6-10/R3's knockdown force-off is REVERSED, AC 4);
##   - `round_ended` and the debug reset's `round_started` relays clear it on BOTH seats (AC 4);
##   - the runner's `cards_changed` wrapper pushes the BOUND hand ids, so the armed card leaving its slot
##     clears the arm (G1, M5) -- driven by a test write to the hand plus the real notify;
##   - the READY relay reaches the OWN slot's controller only (AC 6, M5).
## Re-pins the round-end / reset half of the retired `test_card_mode_lift.gd` (M2) onto the arm.
##
## Run: godot --headless --path . --script res://test/integration/test_arm_clear_live.gd

const SETTLE := 4

var _frames := 0
var _main: Node
var _state: MatchState
var _ok := true
var _pad: GamepadController


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	var runner := scene.instantiate()
	# Story 7-4 (`7-4/R15`): this test acts on the DEALT hand, so it fixes the deal -- set BEFORE the runner
	# enters the tree.
	runner.seed_override = 12345
	root.add_child(runner)


func _fail(msg: String) -> void:
	_ok = false
	print("FAIL: " + msg)


func _armed() -> Array:
	return [_main._p1_controller.armed_slot(), _main._p2_controller.armed_slot()]


func _any_cue_playing() -> bool:
	for player in root.find_children("*", "AudioStreamPlayer", true, false):
		if (player as AudioStreamPlayer).playing:
			return true
	return false


func _press(actions: Array) -> void:
	for a: StringName in actions:
		Input.action_press(a)


func _release(actions: Array) -> void:
	for a: StringName in actions:
		Input.action_release(a)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_main = root.get_node("Main")
		_state = _main._match_state
	var k := SETTLE
	# --- arm both seats with real key presses (P1 slot 1, P2 slot 2) ---
	if _frames == k:
		_press([&"p1_card_2", &"p2_card_3"])
	if _frames == k + 2:
		_release([&"p1_card_2", &"p2_card_3"])
	if _frames == k + 4:
		if _armed() != [1, 2]:
			_fail("the key presses did not arm [1, 2]: %s" % str(_armed()))
		# --- knockdown on P1, an ordinary stun on P2: neither clears (AC 4) ---
		var ticks: BalanceTicks = _state.balance_ticks
		_state.p1.hero.action_state = HeroState.ActionState.STUNNED
		_state.p1.hero.stun.start(ticks.knockdown_stun_ticks)
		_state.p2.hero.action_state = HeroState.ActionState.STUNNED
		_state.p2.hero.stun.start(ticks.knockdown_stun_ticks - 1)
		if _main._stun_flavor_for_slot(0) != AnimationController.STUN_FLAVOR_KNOCKDOWN:
			_fail("sanity: P1's write is not read as a knockdown")
	if _frames == k + 8:
		if _armed() != [1, 2]:
			_fail("a knockdown / an ordinary stun moved the arm: %s, want [1, 2]" % str(_armed()))
		# --- round end clears both seats (AC 4) ---
		_main._relay_round_ended(0)
		if _armed() != [-1, -1]:
			_fail("round_ended did not clear both seats: %s" % str(_armed()))
		_press([&"p1_card_4", &"p2_card_1"])
	if _frames == k + 10:
		_release([&"p1_card_4", &"p2_card_1"])
	if _frames == k + 12:
		if _armed() != [3, 0]:
			_fail("re-arming after the round end gave %s, want [3, 0]" % str(_armed()))
		# --- the debug reset's relay clears both seats (AC 4) ---
		_main._relay_round_started()
		if _armed() != [-1, -1]:
			_fail("round_started (debug reset) did not clear both seats: %s" % str(_armed()))
		_press([&"p1_card_2"])
	if _frames == k + 14:
		_release([&"p1_card_2"])
	if _frames == k + 16:
		if _armed()[0] != 1:
			_fail("P1 did not re-arm slot 1: %s" % str(_armed()))
		# --- the armed card LEAVES its slot: the runner's wrapper pushes the bound ids (G1, M5) ---
		if _state.p1.hand.is_slot_empty(1):
			_fail("sanity: P1's slot 1 is empty before the leave")
		else:
			_state.p1.hand.remove_at(1)
			_state.p1.notify_cards_changed()
	if _frames == k + 19:
		if _armed()[0] != -1:
			_fail("the armed card left its slot but the arm stayed: %s" % str(_armed()))
		# --- READY reaches the OWN slot only (AC 6): a pad on P1, the match-level seam emitted for each zone ---
		_pad = GamepadController.new(0, GamepadProfile.new())
		_main._p1_controller = _pad
		var id: StringName = _state.p1.hand.to_array()[0]
		_state.pitch_changed.emit(1, id, 0, true, 10, 10, {})
		if _pad._pitch_ready:
			_fail("P2's READY zone reached P1's controller")
		_state.pitch_changed.emit(0, id, 0, true, 10, 10, {})
		if not _pad._pitch_ready:
			_fail("P1's own READY zone did not reach P1's controller")
		_state.pitch_changed.emit(0, &"", -1, false, 0, 0, {})
		if _pad._pitch_ready:
			_fail("P1's zone going not-READY was not relayed")
		_state.pitch_changed.emit(1, &"", -1, false, 0, 0, {})
	# The round_ended relay starts the round-end cue; quitting while a stream still plays is reported as a leaked
	# resource. Wait, bounded, for every cue to end.
	if _frames >= k + 22 and (not _any_cue_playing() or _frames >= k + 900):
		if _any_cue_playing():
			_fail("a cue was still playing at the wait bound; quitting now would leak a resource")
		print("arm-clear live: ok=%s" % _ok)
		print("RESULT: %s" % ("PASS" if _ok else "FAIL"))
		quit(0 if _ok else 1)
	return false
