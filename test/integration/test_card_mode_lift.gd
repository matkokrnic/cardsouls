extends SceneTree

## Story 6-10 (AC 16-20): the card-mode HUD LIFT, driven through the live scene's runner -> HUD push.
## Joypad reads are not headless-samplable, so each slot's controller is REPLACED by a fake whose
## `card_mode_on()` / `armed_slot()` the test sets; what is proven is the runner's per-frame poll-and-push
## (step 1b) and HudRoot's response -- the composition a unit test on `set_card_mode` cannot reach.
##
## DIRECTIONAL both ways: P2's mode on lifts P2's own row and leaves P1's viewport unchanged, and the
## reverse. The ARMED card rises clearly higher and carries the strong frame. The 6-0 tint swatches are compared
## before and after (visibility, colour, modulate). The runner is PAUSED for the assertions, proving the push sits
## outside the `ticking` gate.
##
## STORY 7-6 history: R3 had moved card mode / arming to a frame highlight; 7-6 POLISH (operator ruling P3,
## 2026-10-05) moved them BACK TO A LIFT, much more visible than before 7-6 (row `CARD_MODE_ROW_LIFT_PX`, armed
## `CARD_MODE_ARMED_LIFT_PX`, was 4 and 6), plus the armed card's `ARMED_FRAME_PX` frame. Each card lifts by its
## own `position.y` (the strip itself never moves). The pushes, the directionality, the paused-runner proof, "no
## lone lift with mode off" and the forced-off half below are the 6-10 behaviour unchanged (AC 19's regression).
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


## Every card's lift in one row (0 = at rest), measured from its ARC rest height (7-6 POLISH 2, P9: the middle pair
## rests raised, so a raw `position.y` is no longer the lift).
func _lifts(hud: HudRoot) -> Array:
	var out: Array = []
	for i in 4:
		out.append(hud.card_lift(i))
	return out


## The four highlight widths of one row (0 = none).
func _rings(hud: HudRoot) -> Array:
	var out: Array = []
	for i in 4:
		out.append(hud.highlight_width(i))
	return out


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
	if _frames == SETTLE - 1:
		# 7-6 POLISH 3 (P14): paused AFTER the deal (the first advance), so every slot holds a card whose own frame
		# arming turns gold -- an empty slot has no frame to turn. The push still runs paused (outside the gate).
		_main._paused = true  # the push must work while paused (outside the ticking gate)
	var none := [0, 0, 0, 0]
	var rest := [0.0, 0.0, 0.0, 0.0]
	var row := HudRoot.CARD_MODE_ROW_LIFT_PX
	var high := HudRoot.CARD_MODE_ARMED_LIFT_PX
	var armed := HudRoot.ARMED_FRAME_PX
	if _frames == SETTLE:
		_rest_top = _strip(_p1_hud).offset_top
		_rest_bottom = _strip(_p1_hud).offset_bottom
		_tint_before = _tint(_p2_hud)
		_p1_tint_before = _tint(_p1_hud)
		if not is_equal_approx(_strip(_p2_hud).offset_top, _rest_top):
			_fail("the two rows rest differently")
		if _lifts(_p1_hud) != rest or _lifts(_p2_hud) != rest or _rings(_p1_hud) != none or _rings(_p2_hud) != none:
			_fail("a card is lifted or framed with mode off and nothing armed: %s %s %s %s" % [_lifts(_p1_hud),
					_lifts(_p2_hud), _rings(_p1_hud), _rings(_p2_hud)])
		_p2.mode_on = true
	if _frames == SETTLE + 2:
		# P2 mode on, nothing armed: every P2 card lifts by the row lift, no frame, P1 untouched.
		if _lifts(_p2_hud) != [row, row, row, row] or _rings(_p2_hud) != none:
			_fail("P2 mode-on lifts %s rings %s, want all %s and none" % [_lifts(_p2_hud), _rings(_p2_hud), row])
		if _lifts(_p1_hud) != rest or _rings(_p1_hud) != none:
			_fail("P1's viewport changed when only P2's mode was on: %s %s" % [_lifts(_p1_hud), _rings(_p1_hud)])
		if not is_equal_approx(_strip(_p2_hud).offset_top, _rest_top) \
				or not is_equal_approx(_strip(_p2_hud).offset_bottom, _rest_bottom):
			_fail("card mode moved P2's STRIP (each card lifts by its own position, the strip stays)")
		_p2.armed = 2
	if _frames == SETTLE + 4:
		# Armed: slot 2 rises clearly higher with the frame, the rest keep the row lift.
		if _lifts(_p2_hud) != [row, row, high, row] or _rings(_p2_hud) != [0, 0, armed, 0]:
			_fail("armed lifts %s rings %s, want [%s, %s, %s, %s] / [0, 0, %d, 0]" % [_lifts(_p2_hud), _rings(_p2_hud),
					row, row, high, row, armed])
		# 7-6 POLISH 3 (operator ruling P14, a NAMED change): arming turns the armed card's OWN frame gold, so the 6-0
		# tint is compared on every slot EXCEPT the armed one -- which must show gold instead.
		var tint_now := _tint(_p2_hud)
		var tint_was := _tint_before.duplicate()
		var armed_tint: Array = tint_now[2]
		tint_now.remove_at(2)
		tint_was.remove_at(2)
		if (_p2_hud.get_node("HandStrip/Card2/ColorSwatch").get_theme_stylebox("panel") as StyleBoxFlat).border_color 				!= HudRoot.ARMED_FRAME_COLOR or not bool(armed_tint[0]):
			_fail("P14: the armed card's own frame did not turn gold")
		if tint_now != tint_was:
			_fail("the 6-0 tint (swatch visibility/colour/modulate) changed while lifted and armed")
		if _tint(_p1_hud) != _p1_tint_before or _rings(_p1_hud) != none or _lifts(_p1_hud) != rest:
			_fail("P1 changed")
		_p2.mode_on = false
		_p2.armed = -1
	if _frames == SETTLE + 6:
		if _lifts(_p2_hud) != rest or _rings(_p2_hud) != none:
			_fail("P2 row did not return to rest when mode went off: %s %s" % [_lifts(_p2_hud), _rings(_p2_hud)])
		# The reverse direction: P1's mode on lifts P1 only.
		_p1.mode_on = true
		_p1.armed = 1
	if _frames == SETTLE + 8:
		if _lifts(_p1_hud) != [row, high, row, row] or _rings(_p1_hud) != [0, armed, 0, 0]:
			_fail("P1 lifts %s rings %s" % [_lifts(_p1_hud), _rings(_p1_hud)])
		if _lifts(_p2_hud) != rest or _rings(_p2_hud) != none:
			_fail("P2's viewport changed when only P1's mode was on")
		# mode off but a slot still armed (keyboard hold shape): the armed frame alone, no lone lift
		_p1.mode_on = false
	if _frames == SETTLE + 10:
		if _lifts(_p1_hud) != rest or _rings(_p1_hud) != [0, armed, 0, 0]:
			_fail("mode off with slot 1 armed: lifts %s rings %s, want rest and [0, %d, 0, 0]" % [_lifts(_p1_hud),
					_rings(_p1_hud), armed])
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
		print("lift: knobs row=%s armed=%s frame=%s ok=%s" % [HudRoot.CARD_MODE_ROW_LIFT_PX,
			HudRoot.CARD_MODE_ARMED_LIFT_PX, HudRoot.ARMED_FRAME_PX, _ok])
		print("RESULT: %s" % ("PASS" if _ok else "FAIL"))
		quit(0 if _ok else 1)
	return false
