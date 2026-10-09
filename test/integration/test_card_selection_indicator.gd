extends SceneTree

## Story 3-5a (AC 10): the card SELECTION INDICATOR, driven end to end through the live scene —
## real Input Map presses -> KeyboardController -> the runner's push -> HudRoot's panel styling.
##
## WHY THIS TEST EXISTS AT ALL, and why it is an integration test rather than a unit one. The
## suite's standing blind spot is that it tests authored data AT REST and never RUNTIME
## COMPOSITION, so it is blind to "the seam fires but the consumer swallows it". A unit test on
## HudRoot.set_card_selection would prove the styling function works and would still pass if the
## runner never called it, or called it with the wrong controller's slot. This drives the real
## chain and would catch either.
##
## THE ASSERTION IS DIRECTIONAL, which is the point (prompt ruling G): it does not merely check
## that SOMETHING is highlighted. It pins that the armed panel is EXACTLY the one matching the
## pressed key. `p1_card_3` is pressed deliberately — index 2 of 0..3 — so it is neither the first
## nor the last panel: an off-by-one in either direction, a reversed row, and a
## highlight-everything regression all FAIL here. Swapping the slot mapping fails (proven by
## SHA256-verified swap in the dev record).
##
## Also pinned: RELEASING the modifier clears the selection the same tick (the "release exits
## instantly" half of the scheme), and the OPPONENT viewport is never indicated by P1's press —
## the 2-4/R7 no-opponent-read discipline extended to the indicator.
##
## Styling is read STRUCTURALLY through `HudRoot.highlight_width` (7-6 P14: the card's own frame turned gold), never
## against hardcoded colours, so a later palette change does not break the guard.
##
## Run: godot --headless --path . --script res://test/integration/test_card_selection_indicator.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

const ARM_FRAME := 6
## Which Input Map card key is pressed, and the panel index it must arm. Deliberately a MIDDLE
## slot — see the header.
const PRESSED_CARD_ACTION := &"p1_card_3"
const EXPECTED_PANEL := 2

var _frames := 0
var _p1_hud: Node
var _p2_hud: Node

var _huds_exist := false
var _baseline_uniform := false
var _armed_correct := false
var _opponent_untouched := false
var _cleared_on_release := false
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
		_p1_hud = root.get_node_or_null("Main/P1View/P1Viewport/HudRoot")
		_p2_hud = root.get_node_or_null("Main/P2View/P2Viewport/HudRoot")
		_huds_exist = _p1_hud != null and _p2_hud != null
		if not _huds_exist:
			print("HUD roots missing: p1=%s p2=%s" % [_p1_hud, _p2_hud])
			print("RESULT: FAIL")
			quit(1)
			return false
		# BASELINE: with nothing armed, all four own panels share ONE styling. This is what makes
		# the armed assertion below mean something — without it, a row that was always
		# heterogeneous could satisfy "exactly one differs" by accident.
		_baseline_uniform = _distinct_border_count(_p1_hud) == 1
	if _frames == ARM_FRAME:
		Input.action_press(&"p1_cast_mode")
	if _frames == ARM_FRAME + 1:
		Input.action_press(PRESSED_CARD_ACTION)
	if _frames == ARM_FRAME + 2:
		Input.action_release(PRESSED_CARD_ACTION)
	if _frames == ARM_FRAME + 3:
		# THE DIRECTIONAL ASSERTION: exactly one panel is armed, and it is EXACTLY the one the
		# pressed key names.
		var armed := _armed_panel_index(_p1_hud)
		_armed_correct = armed == EXPECTED_PANEL
		if not _armed_correct:
			_detail += " armed_panel=%d expected=%d;" % [armed, EXPECTED_PANEL]
		# The opponent's viewport must show nothing: P1's selection is P1's.
		_opponent_untouched = _armed_panel_index(_p2_hud) == -1
	if _frames == ARM_FRAME + 6:
		Input.action_release(&"p1_cast_mode")
	if _frames == ARM_FRAME + 8:
		# Releasing the modifier exits instantly and disarms — nothing stays lit.
		_cleared_on_release = _armed_panel_index(_p1_hud) == -1
	if _frames >= ARM_FRAME + 10:
		var ok: bool = (_huds_exist and _baseline_uniform and _armed_correct
			and _opponent_untouched and _cleared_on_release)
		print("selection: huds=%s baseline_uniform=%s armed_correct=%s opponent_untouched=%s cleared_on_release=%s%s" % [
			_huds_exist, _baseline_uniform, _armed_correct, _opponent_untouched,
			_cleared_on_release, _detail])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false


## The index of the single panel whose styling differs from the row's majority, or -1 if the row
## is uniform. Structural: an "armed" panel is the one carrying a DIFFERENT border width, so the
## test never encodes which colours the palette happens to use.
##
## Returns -1 if more than one panel differs — a highlight-everything regression is a failure,
## not a pass with an arbitrary index.
func _armed_panel_index(hud: Node) -> int:
	var borders := _panel_borders(hud)
	if borders.is_empty():
		return -1
	# The base style is the one the majority carries; with four panels and at most one armed, the
	# minimum border width is the base (the armed style is strictly heavier).
	var base: int = borders.min()
	var armed := -1
	var count := 0
	for i in borders.size():
		if borders[i] != base:
			armed = i
			count += 1
	if count != 1:
		return -1
	return armed


func _distinct_border_count(hud: Node) -> int:
	var seen: Dictionary = {}
	for b in _panel_borders(hud):
		seen[b] = true
	return seen.size()


## Story 7-6 (AC 17) / 7-6 POLISH 3 (P14): the armed tell is the card's OWN frame turned gold -- read through
## `HudRoot.highlight_width` (0 = not armed, the frame width = armed). The directional logic above is unchanged.
func _panel_borders(hud: Node) -> Array[int]:
	var out: Array[int] = []
	if hud.get_node_or_null("HandStrip") == null:
		return out
	for i in 4:
		out.append((hud as HudRoot).highlight_width(i))
	return out
