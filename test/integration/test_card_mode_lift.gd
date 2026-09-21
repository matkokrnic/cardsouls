extends SceneTree

## Story 6-10 (AC 16-20): the card-mode HUD LIFT, driven through the live scene's runner -> HUD push.
## Joypad reads are not headless-samplable, so each slot's controller is REPLACED by a fake whose
## `card_mode_on()` / `armed_slot()` the test sets; what is proven is the runner's per-frame poll-and-push
## (step 1b) and HudRoot's response -- the composition a unit test on `set_card_mode` cannot reach.
##
## DIRECTIONAL both ways: P2's mode on lifts P2's own row and leaves P1's viewport unchanged, and the
## reverse. The ARMED card rises further than its neighbours. The 6-0 tint swatches are compared before
## and after (visibility, colour, modulate) and the lift touches no `modulate`. The runner is PAUSED for
## the assertions, proving the push sits outside the `ticking` gate.
##
## The FORCED-OFF routes (AC 9a-c) are pinned here too, through the same fakes: each fake COUNTS the runner's
## `force_card_mode_off()` pushes. Knockdown is driven by writing the paused runner's hero directly (a test
## write; the runner does not advance while paused): an ORDINARY stun pushes nothing, a knockdown pushes
## exactly once on its rising edge (not once per frame), only to the knocked-down slot; `round_ended` and the
## debug-reset `round_started` relays push to both.
##
## Run: godot --headless --path . --script res://test/integration/test_card_mode_lift.gd

const FakeCtl := preload("res://test/integration/fake_mode_controller.gd")


const SETTLE := 4

var _frames := 0
var _main: Node
var _p1: Controller
var _p2: Controller
var _p1_hud: HudRoot
var _p2_hud: HudRoot
var _ok := true
var _rest_top := 0.0
var _rest_bottom := 0.0
var _tint_before: Array = []
var _p1_tint_before: Array = []


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _fail(msg: String) -> void:
	_ok = false
	print("FAIL: " + msg)


func _strip(hud: HudRoot) -> Control:
	return hud.get_node("HandStrip")


func _tint(hud: HudRoot) -> Array:
	var out: Array = []
	for card in _strip(hud).get_children():
		var sw := card.get_node("ColorSwatch") as Panel
		var st := sw.get_theme_stylebox("panel") as StyleBoxFlat
		out.append([sw.visible, st.bg_color, sw.modulate, (card as Control).modulate])
	return out


func _any_cue_playing() -> bool:
	for player in root.find_children("*", "AudioStreamPlayer", true, false):
		if (player as AudioStreamPlayer).playing:
			return true
	return false


func _card_y(hud: HudRoot, i: int) -> float:
	return (_strip(hud).get_child(i) as Control).position.y


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_main = root.get_node("Main")
		_p1_hud = root.get_node("Main/P1View/P1Viewport/HudRoot")
		_p2_hud = root.get_node("Main/P2View/P2Viewport/HudRoot")
		_p1 = FakeCtl.new()
		_p2 = FakeCtl.new()
		_main._p1_controller = _p1
		_main._p2_controller = _p2
		_main._paused = true  # the push must work while paused (outside the ticking gate)
	if _frames == SETTLE:
		_rest_top = _strip(_p1_hud).offset_top
		_rest_bottom = _strip(_p1_hud).offset_bottom
		_tint_before = _tint(_p2_hud)
		_p1_tint_before = _tint(_p1_hud)
		if not is_equal_approx(_strip(_p2_hud).offset_top, _rest_top):
			_fail("the two rows rest differently")
		_p2.mode_on = true
	if _frames == SETTLE + 2:
		# P2 mode on, nothing armed: P2's row lifted by exactly the knob, size unchanged, P1 untouched.
		var lifted := _rest_top - _strip(_p2_hud).offset_top
		if not is_equal_approx(lifted, HudRoot.CARD_MODE_ROW_LIFT_PX) or lifted <= 0.0:
			_fail("P2 row lift %s != knob %s" % [lifted, HudRoot.CARD_MODE_ROW_LIFT_PX])
		if not is_equal_approx(_strip(_p2_hud).offset_bottom, _rest_bottom - HudRoot.CARD_MODE_ROW_LIFT_PX):
			_fail("P2 row moved by different amounts top and bottom (a resize)")
		if not is_equal_approx(_strip(_p1_hud).offset_top, _rest_top):
			_fail("P1's viewport changed when only P2's mode was on")
		for i in 4:
			if not is_equal_approx(_card_y(_p2_hud, i), 0.0):
				_fail("a card lifted with nothing armed (%d)" % i)
		_p2.armed = 2
	if _frames == SETTLE + 4:
		# Armed stronger: only slot 2 rises further, on top of the row lift.
		for i in 4:
			var want := -HudRoot.CARD_MODE_ARMED_LIFT_PX if i == 2 else 0.0
			if not is_equal_approx(_card_y(_p2_hud, i), want):
				_fail("armed lift: card %d y=%s want %s" % [i, _card_y(_p2_hud, i), want])
		if _tint(_p2_hud) != _tint_before:
			_fail("the 6-0 tint (swatch visibility/colour/modulate) changed while lifted and armed")
		if _tint(_p1_hud) != _p1_tint_before or not is_equal_approx(_strip(_p1_hud).offset_top, _rest_top):
			_fail("P1 changed")
		_p2.mode_on = false
		_p2.armed = -1
	if _frames == SETTLE + 6:
		if not is_equal_approx(_strip(_p2_hud).offset_top, _rest_top) \
				or not is_equal_approx(_card_y(_p2_hud, 2), 0.0):
			_fail("P2 row did not return to rest when mode went off")
		# The reverse direction: P1's mode on lifts P1 only.
		_p1.mode_on = true
		_p1.armed = 1
	if _frames == SETTLE + 8:
		if not is_equal_approx(_rest_top - _strip(_p1_hud).offset_top, HudRoot.CARD_MODE_ROW_LIFT_PX):
			_fail("P1 row not lifted by the knob")
		if not is_equal_approx(_card_y(_p1_hud, 1), -HudRoot.CARD_MODE_ARMED_LIFT_PX):
			_fail("P1 armed card not lifted further")
		if not is_equal_approx(_strip(_p2_hud).offset_top, _rest_top) \
				or not is_equal_approx(_card_y(_p2_hud, 1), 0.0):
			_fail("P2's viewport changed when only P1's mode was on")
		# mode off but a slot still armed (keyboard hold shape): no lone card lift
		_p1.mode_on = false
	if _frames == SETTLE + 10:
		if not is_equal_approx(_card_y(_p1_hud, 1), 0.0):
			_fail("a card lifted alone with mode off")
	var k := SETTLE + 12
	if _frames == k:
		# ordinary stun on P1 (one tick short of the knockdown threshold)
		var ticks: BalanceTicks = _main._match_state.balance_ticks
		_main._match_state.p1.hero.action_state = HeroState.ActionState.STUNNED
		_main._match_state.p1.hero.stun.start(ticks.knockdown_stun_ticks - 1)
	if _frames == k + 3:
		if _p1.force_calls != 0 or _p2.force_calls != 0:
			_fail("an ORDINARY stun forced card mode off (p1=%d p2=%d)" % [_p1.force_calls, _p2.force_calls])
		var ticks: BalanceTicks = _main._match_state.balance_ticks
		_main._match_state.p1.hero.stun.start(ticks.knockdown_stun_ticks)  # escalation, same state
	if _frames == k + 6:
		if _p1.force_calls != 1:
			_fail("knockdown pushed %d force-offs to the knocked-down slot, want exactly 1 (edge, not level)" % _p1.force_calls)
		if _p2.force_calls != 0:
			_fail("P2 was forced off by P1's knockdown")
		_main._match_state.p1.hero.action_state = HeroState.ActionState.IDLE
	if _frames == k + 8:
		var ticks: BalanceTicks = _main._match_state.balance_ticks
		_main._match_state.p1.hero.action_state = HeroState.ActionState.STUNNED
		_main._match_state.p1.hero.stun.start(ticks.knockdown_stun_ticks)
	if _frames == k + 11:
		if _p1.force_calls != 2:
			_fail("a SECOND knockdown did not push again (%d)" % _p1.force_calls)
		_main._match_state.p1.hero.action_state = HeroState.ActionState.IDLE
		_main._relay_round_ended(0)
	if _frames == k + 12:
		if _p1.force_calls != 3 or _p2.force_calls != 1:
			_fail("round_ended did not push to both (p1=%d p2=%d)" % [_p1.force_calls, _p2.force_calls])
		_main._relay_round_started()
	if _frames == k + 13:
		if _p1.force_calls != 4 or _p2.force_calls != 2:
			_fail("the debug reset (round_started) did not push to both (p1=%d p2=%d)" % [_p1.force_calls, _p2.force_calls])
		# P2's own knockdown (the knock_slot == 1 branch): forces P2 off, and only P2.
		var ticks2: BalanceTicks = _main._match_state.balance_ticks
		_main._match_state.p2.hero.action_state = HeroState.ActionState.STUNNED
		_main._match_state.p2.hero.stun.start(ticks2.knockdown_stun_ticks)
	if _frames == k + 16:
		if _p2.force_calls != 3:
			_fail("P2's knockdown pushed %d total force-offs to P2, want 3" % _p2.force_calls)
		if _p1.force_calls != 4:
			_fail("P1 was forced off by P2's knockdown (%d)" % _p1.force_calls)
	# The round_ended relay starts the round-end cue; quitting while a stream is still playing is reported as a
	# leaked resource (an `ERROR:` line the harness treats as a failure). Wait, bounded, for every cue to end.
	if _frames >= k + 18 and (not _any_cue_playing() or _frames >= k + 900):
		if _any_cue_playing():
			_fail("a cue was still playing at the wait bound (%d frames); quitting now would leak a resource" % 900)
		print("lift: knobs row=%s armed=%s ok=%s" % [HudRoot.CARD_MODE_ROW_LIFT_PX,
			HudRoot.CARD_MODE_ARMED_LIFT_PX, _ok])
		print("RESULT: %s" % ("PASS" if _ok else "FAIL"))
		quit(0 if _ok else 1)
	return false
