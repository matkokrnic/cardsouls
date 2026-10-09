extends SceneTree

## Story 4-B1 (code review, D1): THE HOLE-VS-IN-FLIGHT DISTINCTION, DRIVEN THROUGH THE REAL STATE
## MACHINE — the proof the story shipped without, and the reason its bug survived the dev pass.
##
## WHY THIS FILE EXISTS AT ALL. test_card_hud.gd proves the RENDERING contract by calling
## `HudRoot.on_cards_changed` directly with a hand-built payload: given an owed list containing the
## vacated slot, the caption is IN_FLIGHT_CAPTION; given one that does not, it is blank. Both
## halves are true and both stayed true while the feature was broken in play, because the bug was
## never in the renderer — it was in WHO SENDS THE PAYLOAD. The state layer popped the debt on two
## paths without announcing, so the last payload the HUD ever received still carried the slot as
## owed and the caption stayed "..." forever, on a slot that was by then the permanent hole. A test
## that never crosses the state boundary cannot see that, which is exactly what happened.
##
## So this drives the whole chain: real Input Map presses -> KeyboardController -> the runner's
## single _physics_process -> MatchState.advance() -> the queued cards_changed drain -> the eighth
## observation seam -> the real HudRoot's real caption. Nothing about the payload is hand-built.
##
## THE ONE FORCED STEP, AND WHY IT IS FORCED. The both-empty degrade cannot be reached by playing:
## card count is conserved (deck + discard + occupied hand), and a debt always has its own cast
## card sitting in the discard, which the lazy reshuffle hands straight back. A probe driving the
## real machine for 400 ticks across seven deck sizes and three delays reached the degrade's
## precondition ZERO times. It is defense-in-depth, like the DEAD branch beside it, and it is
## forced here the same way that branch is forced elsewhere: by emptying both piles between the
## cast and the delivery, through the deliberate `_match_state` exception test_deck_injection.gd
## already established (see its line 31). Every other step is real play.
##
## Run: godot --headless --path . --script res://test/integration/test_hole_vs_in_flight_live.gd

## Presses are HELD for several frames rather than pulsed for one: the runner's _physics_process
## and this script's are two separate callbacks in an unspecified order, so a one-frame pulse can
## be released before the runner ever samples the just_pressed edge. Holding costs nothing —
## just_pressed still fires exactly once — and removes the ordering assumption entirely.
const ARM_FRAME := 4
const ARM_RELEASE_FRAME := 8
const CONFIRM_FRAME := 10
const CONFIRM_RELEASE_FRAME := 14
const IN_FLIGHT_CHECK_FRAME := 16
const EMPTY_THE_PILES_FRAME := 17
# The authored delay is 1.0s = 60 ticks; the delivery lands after it expires, and the drain that
# repaints the HUD is the same tick. Generous margin, then assert.
const SETTLED_FRAME := 110

var _frames := 0
var _runner: Node
var _hud: Node
var _state: MatchState

var _cast_landed := false
var _in_flight_rendered := false
var _piles_emptied := false
var _debt_was_outstanding := false
var _hole_rendered_after_degrade := false
var _detail := ""


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	var runner := scene.instantiate()
	# Story 7-4 (`7-4/R15`): this test reads or acts on the DEALT hand, so it fixes the deal at the seed the
	# runner shipped as a constant before 7-4 -- set BEFORE the runner enters the tree.
	runner.seed_override = 12345
	root.add_child(runner)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_hud = root.get_node_or_null("Main/P1View/P1Viewport/HudRoot")
		_state = _runner._match_state if _runner != null else null
		if _runner == null or _hud == null or _state == null:
			print("missing: runner=%s hud=%s state=%s" % [_runner, _hud, _state])
			print("RESULT: FAIL")
			quit(1)
			return false
	if _frames == 2:
		# Mana, so the cast is affordable — the economy is not what this test is about. Everything
		# downstream of the press is real.
		_state.p1.mana.add(_state.p1.mana.get_maximum())
	# The real arm-then-confirm scheme, in the order the controller requires it: the cast-mode
	# modifier is HELD (keyboard_controller.gd:105 returns early without it — arming is impossible
	# otherwise), the card key arms the slot while it is down, and cast_confirm commits. Copied
	# beat for beat from test_card_selection_indicator.gd, the file that already drives this.
	if _frames == ARM_FRAME:
		Input.action_press(&"p1_cast_mode")
	if _frames == ARM_FRAME + 1:
		Input.action_press(&"p1_card_2")     # arm hand slot index 1
	if _frames == ARM_FRAME + 2:
		Input.action_release(&"p1_card_2")
	if _frames == CONFIRM_FRAME:
		Input.action_press(&"p1_cast_confirm")
	if _frames == CONFIRM_FRAME + 2:
		Input.action_release(&"p1_cast_confirm")
	if _frames == CONFIRM_RELEASE_FRAME:
		Input.action_release(&"p1_cast_mode")
	if _frames == IN_FLIGHT_CHECK_FRAME:
		# NON-VACUITY, state side: the cast really happened through advance(). Without this a
		# refused cast would leave a blank slot and the final assertion would pass for the wrong
		# reason — blank because nothing ever went in flight.
		_cast_landed = (_state.p1.hand.is_slot_empty(1)
			and not _state.p1.pending_draw_owed.is_empty())
		_in_flight_rendered = _caption(1) == HudRoot.IN_FLIGHT_CAPTION
		if not (_cast_landed and _in_flight_rendered):
			_detail += " hole=%s owed=%s caption=%s;" % [
				_state.p1.hand.is_slot_empty(1), str(_state.p1.pending_draw_owed), _caption(1)]
	if _frames == EMPTY_THE_PILES_FRAME:
		# THE FORCED STEP (see the header). Both piles empty with a debt still outstanding is the
		# degrade's precondition; conservation makes it unreachable by playing.
		var nothing: Array[StringName] = []
		_state.p1.deck.set_contents(nothing)
		_state.p1.discard.clear()
		_piles_emptied = _state.p1.deck.is_empty() and _state.p1.discard.is_empty()
		_debt_was_outstanding = not _state.p1.pending_draw_owed.is_empty()
	if _frames == SETTLED_FRAME:
		# The delivery has run: the debt was popped, no card could be drawn, and the slot is now
		# 4-0 AC 8's PERMANENT HOLE. It must no longer read as in flight.
		var caption := _caption(1)
		_hole_rendered_after_degrade = (caption == "" and _state.p1.pending_draw_owed.is_empty()
			and _state.p1.hand.is_slot_empty(1))
		if not _hole_rendered_after_degrade:
			_detail += " final_caption=%s owed=%s hole=%s;" % [
				caption, str(_state.p1.pending_draw_owed), _state.p1.hand.is_slot_empty(1)]
		var ok := (_cast_landed and _in_flight_rendered and _piles_emptied
			and _debt_was_outstanding and _hole_rendered_after_degrade)
		print("hole_vs_in_flight_live: cast_landed=%s in_flight_rendered=%s piles_emptied=%s debt_outstanding=%s hole_after_degrade=%s%s" % [
			_cast_landed, _in_flight_rendered, _piles_emptied, _debt_was_outstanding,
			_hole_rendered_after_degrade, _detail])
		# Story 7-1 (AC 33, named edit): the card this file casts now throws Rocksling stones whose `rock_throw`
		# can still be playing here, and a sound playing at quit leaves its playback held by the mixer --
		# "resources still in use at exit". Stop them and give the mixer a beat first, the
		# `test_cast_success_cue_live.gd` stop-then-wait (`EffectPresenter.stop_all_sounds`).
		if _runner != null and _runner._effects != null:
			_runner._effects.stop_all_sounds()
		OS.delay_msec(100)
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false


## The real caption of one own-hand slot, read off the real HudRoot the runner built.
func _caption(index: int) -> String:
	var strip := _hud.get_node_or_null("HandStrip")
	if strip == null:
		return "<no strip>"
	var cards := strip.get_children()
	if index >= cards.size():
		return "<no slot>"
	var label := cards[index].get_node_or_null("CardName") as Label
	return "<no label>" if label == null else label.text
