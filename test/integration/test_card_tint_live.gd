extends SceneTree

## Story 6-0 (AC 1/AC 3/AC 5): CARD HAND TINT, driven end to end through the live scene, and on the
## HudRoot RENDERING side — the one gap `test_card_hud.gd` leaves open. That file proves the
## caption text reaches each panel; it says nothing about colour, and a runner that derived a
## colour map but never actually threaded it into the wrapper (or wired it to the wrong panel)
## would still pass every existing assertion in this repo. This file exists to close exactly that
## blind spot — the runtime-composition class (`3-0b/R34`): "the seam fires but the consumer
## swallows it."
##
## PER-PANEL, NOT MERELY A DERIVED MAP (the story's own extra test requirement). It is not enough
## that `_derive_card_colors()` returns a total map somewhere in the runner — a slot-shifted bug (
## panel 0 showing panel 1's colour) would still pass a test that only checked "every colour in the
## hand appeared somewhere". This test reads a given panel's swatch and compares it against THAT
## slot's real, database-sourced colour, index by index.
##
## WHY LIVE (not a hand-built payload only). The real deal exercises the full chain: match start ->
## `_derive_card_colors()` -> the `cards_changed` wrapper -> `on_cards_changed` -> the real swatch a
## player would see. The hand-built calls below (mirroring `test_card_hud.gd`'s own holed-payload
## technique) additionally prove the THREE untinted cases side-by-side with two REAL tinted ones in
## the SAME call, which a live deal alone cannot show (a live hand rarely holds a hole).
##
## THREE THINGS THE CODE REVIEW ADDED, each closing a way this file could have lied:
##  1. NO `get_card()` CALL EVER LANDS ON `Hand.EMPTY`. `Hand.to_array()` is a WIDTH view — it
##     returns a slot per hand position with `Hand.EMPTY` (`&""`) at every hole, and
##     `CardDatabase.get_card` is a bare dictionary read that returns null for an unknown id. The
##     old revision indexed `live[0]`/`live[2]` blind; a hole in either slot dereferenced null and
##     raised SCRIPT ERROR, which `run_all.sh` treats as a failure of the WHOLE suite. The card
##     slots under test are now chosen DYNAMICALLY from the occupied ones, and too few occupied
##     slots is a clean diagnostic FAIL, never a crash.
##  2. THE LIVE-TINT CHECK COUNTS ITS OWN COMPARISONS. It used to be a flag initialised `true` and
##     falsified only inside a loop that an all-empty hand skips entirely — zero comparisons made,
##     "PASS" reported. The comparison count is now folded into the verdict and printed, so a
##     vacuous run is indistinguishable from a failing one.
##  3. ONE HARD-CODED RGB PIN. Every other assertion computes its expectation with the same
##     `ORB_COLORS[color]` expression production uses, so a PERMUTED palette (red cards painted
##     blue) would satisfy all of them. `_check_palette_pin` writes one literal Color instead.
##
## Run: godot --headless --path . --script res://test/integration/test_card_tint_live.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

const OBSERVE_FRAME := 4
const HAND_SLOTS := 4

## The palette pin (see point 3 above). `ember_lash` is authored `color = 0` (RED) in
## `data/cards/ember_lash.tres`, and RED's hue is `ORB_COLORS[0]`. Both halves are written as
## LITERALS here on purpose: this is the one assertion that fails if the palette is reordered or
## the fixture is recoloured, so it must not be derived from either.
const PIN_ID := &"ember_lash"
const PIN_EXPECTED_COLOR := Color(0.95, 0.30, 0.30)

var _frames := 0
var _p1_hud: Node
var _p1_state: PlayerState

var _live_tint_correct := false
var _live_comparisons := 0
var _holed_payload_correct := false
var _armed_slot_keeps_tint := false
var _disarmed_slot_keeps_tint := false
var _palette_pin_correct := false
var _detail := ""


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var runner := root.get_node_or_null("Main")
		_p1_hud = root.get_node_or_null("Main/P1View/P1Viewport/HudRoot")
		_p1_state = runner._match_state.p1 if runner != null and runner._match_state != null else null
		if _p1_hud == null or _p1_state == null:
			print("missing: hud=%s p1_state=%s" % [_p1_hud, _p1_state])
			print("RESULT: FAIL")
			quit(1)
			return false
	if _frames == OBSERVE_FRAME:
		_check_live_tint()
	if _frames == OBSERVE_FRAME + 1:
		if not _check_holed_payload():
			return false
	if _frames == OBSERVE_FRAME + 2:
		if not _check_armed_disarmed():
			return false
	if _frames == OBSERVE_FRAME + 3:
		_check_palette_pin()
		_report()
	return false


## AC 1/AC 3, PER-PANEL: the real dealt hand, each OCCUPIED slot's swatch checked against that SAME
## id's real CardData.color — reading CardDatabase here only to build the EXPECTED value, never the
## map under test, which travelled through the wrapper on its own.
##
## `_live_comparisons` is the non-vacuity guard: an all-EMPTY hand makes zero comparisons, and the
## verdict in `_report()` requires the count to be nonzero. A flag alone would have reported PASS.
func _check_live_tint() -> void:
	var hand_ids: Array = _p1_state.hand.to_array()
	_live_tint_correct = true
	for i in hand_ids.size():
		var id: StringName = hand_ids[i]
		if id == Hand.EMPTY:
			continue
		var card := _card_database().get_card(id) as CardData
		if card == null:
			_live_tint_correct = false
			_detail += " slot%d id=%s not in database;" % [i, id]
			continue
		_live_comparisons += 1
		var expected := HudRoot.ORB_COLORS[card.color]
		var swatch := _swatch(i)
		var ok := (swatch.visible and _swatch_style(i).bg_color.is_equal_approx(expected))
		if not ok:
			_live_tint_correct = false
			_detail += " slot%d id=%s expected=%s visible=%s actual=%s;" % [
				i, id, expected, swatch.visible, _swatch_style(i).bg_color]


## The three UNTINTED cases (AC 1, "exhaustively") side-by-side with two REAL tinted slots in ONE
## call — proving the per-panel mapping survives a mixed payload, not just an all-real or all-empty
## one. Two occupied slots keep their real ids (and therefore real colours); of the two remaining
## slots one is Hand.EMPTY and unowed (the permanent hole) and the other is blank but OWED
## (in-flight).
##
## The four slot roles are assigned from the hand's ACTUAL occupancy rather than hard-coded to
## 0/1/2/3 — indexing a fixed slot blind is what made the previous revision crash on a hole.
## Returns false if it has already reported a terminal FAIL.
func _check_holed_payload() -> bool:
	var live: Array = _p1_state.hand.to_array()
	var occupied := _occupied_indices(live)
	if live.size() != HAND_SLOTS or occupied.size() < 2:
		print("card_tint_live: cannot run the holed-payload check — need %d slots with at least 2 occupied, got size=%d occupied=%d (hand=%s)" % [
			HAND_SLOTS, live.size(), occupied.size(), live])
		print("RESULT: FAIL")
		quit(1)
		return false
	var slot_a: int = occupied[0]
	var slot_b: int = occupied[1]
	var spare := _other_indices([slot_a, slot_b])
	var hole_slot: int = spare[0]
	var flight_slot: int = spare[1]

	var id_a: StringName = live[slot_a]
	var id_b: StringName = live[slot_b]
	var card_a := _card_database().get_card(id_a) as CardData
	var card_b := _card_database().get_card(id_b) as CardData
	if card_a == null or card_b == null:
		print("card_tint_live: occupied slot id missing from database — a=%s b=%s" % [id_a, id_b])
		print("RESULT: FAIL")
		quit(1)
		return false

	var colors: Dictionary = {}
	colors[id_a] = card_a.color
	colors[id_b] = card_b.color
	var holed: Array[StringName] = []
	for i in HAND_SLOTS:
		holed.append(Hand.EMPTY)
	holed[slot_a] = id_a
	holed[slot_b] = id_b
	_p1_hud.on_cards_changed(holed, 7, 1, [flight_slot], colors)

	var a_ok := (_swatch(slot_a).visible
		and _swatch_style(slot_a).bg_color.is_equal_approx(HudRoot.ORB_COLORS[card_a.color]))
	var b_ok := (_swatch(slot_b).visible
		and _swatch_style(slot_b).bg_color.is_equal_approx(HudRoot.ORB_COLORS[card_b.color]))
	var hole_ok := not _swatch(hole_slot).visible      # permanent hole
	var flight_ok := not _swatch(flight_slot).visible  # in-flight
	_holed_payload_correct = a_ok and b_ok and hole_ok and flight_ok
	if not _holed_payload_correct:
		_detail += " holed: a[%d]=%s b[%d]=%s hole[%d]=%s flight[%d]=%s;" % [
			slot_a, a_ok, slot_b, b_ok, hole_slot, hole_ok, flight_slot, flight_ok]

	# Refill so the next frame's armed-selection check reads real card slots, not the holes just
	# created above. The map is built TOTAL over the occupied slots (the earlier revision supplied
	# colours for only two of them, leaving genuinely-occupied slots hidden for no reason).
	_p1_hud.on_cards_changed(live, 6, 1, [], _colors_for(live))
	return true


## AC 5: arming a slot must not silently drop its tint. `set_card_selection` rewrites the WHOLE
## panel stylebox on every call (base<->armed swap) — the swatch is a sibling that call never
## touches, and this is the assertion that stays true in practice, not just by reading the code.
## Note `set_card_selection(-1, ...)` is the disarm: it compares `i == slot` rather than indexing
## by it, so -1 arms nothing rather than wrapping to the last panel.
func _check_armed_disarmed() -> bool:
	var live: Array = _p1_state.hand.to_array()
	var occupied := _occupied_indices(live)
	if occupied.is_empty():
		print("card_tint_live: cannot run the armed check — no occupied slot (hand=%s)" % [live])
		print("RESULT: FAIL")
		quit(1)
		return false
	var slot: int = occupied[0]
	var id: StringName = live[slot]
	var card := _card_database().get_card(id) as CardData
	if card == null:
		print("card_tint_live: armed-check slot id missing from database — %s" % [id])
		print("RESULT: FAIL")
		quit(1)
		return false
	var expected := HudRoot.ORB_COLORS[card.color]
	_p1_hud.set_card_selection(slot, Enums.ModeKind.BASIC)
	_armed_slot_keeps_tint = (_swatch(slot).visible
		and _swatch_style(slot).bg_color.is_equal_approx(expected))
	if not _armed_slot_keeps_tint:
		_detail += " armed[%d]: visible=%s color=%s;" % [
			slot, _swatch(slot).visible, _swatch_style(slot).bg_color]
	_p1_hud.set_card_selection(-1, Enums.ModeKind.BASIC)
	_disarmed_slot_keeps_tint = (_swatch(slot).visible
		and _swatch_style(slot).bg_color.is_equal_approx(expected))
	if not _disarmed_slot_keeps_tint:
		_detail += " disarmed[%d]: visible=%s color=%s;" % [
			slot, _swatch(slot).visible, _swatch_style(slot).bg_color]
	return true


## THE PALETTE PIN. Every other assertion in this file computes its expectation as
## `ORB_COLORS[card.color]` — exactly the expression production evaluates — so all of them survive a
## REORDERED palette that paints red cards blue. This one writes the literal RGB, against a card
## whose authored colour is also asserted literally, so a permutation of either fails here.
## Driven through a hand-built payload rather than the dealt hand: the pin must not depend on
## `ember_lash` happening to be in P1's opening hand.
func _check_palette_pin() -> void:
	var card := _card_database().get_card(PIN_ID) as CardData
	if card == null:
		_detail += " pin: fixture %s missing from database;" % [PIN_ID]
		return
	if card.color != Enums.CardColor.RED:
		_detail += " pin: fixture %s authored color=%d, expected RED(%d);" % [
			PIN_ID, card.color, Enums.CardColor.RED]
		return
	var payload: Array[StringName] = []
	for i in HAND_SLOTS:
		payload.append(Hand.EMPTY)
	payload[0] = PIN_ID
	_p1_hud.on_cards_changed(payload, 6, 1, [], {PIN_ID: Enums.CardColor.RED})
	var actual := _swatch_style(0).bg_color
	_palette_pin_correct = (_swatch(0).visible and actual.is_equal_approx(PIN_EXPECTED_COLOR))
	if not _palette_pin_correct:
		_detail += " pin: %s expected=%s visible=%s actual=%s;" % [
			PIN_ID, PIN_EXPECTED_COLOR, _swatch(0).visible, actual]


func _report() -> void:
	var compared_enough := _live_comparisons > 0
	if not compared_enough:
		_detail += " live: ZERO occupied slots compared — the live-tint check proved nothing;"
	var ok := (_live_tint_correct and compared_enough and _holed_payload_correct
		and _armed_slot_keeps_tint and _disarmed_slot_keeps_tint and _palette_pin_correct)
	print("card_tint_live: live_tint=%s compared=%d holed_payload=%s armed_keeps=%s disarmed_keeps=%s palette_pin=%s%s" % [
		_live_tint_correct, _live_comparisons, _holed_payload_correct, _armed_slot_keeps_tint,
		_disarmed_slot_keeps_tint, _palette_pin_correct, _detail])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


## The hand positions actually holding a card. `Hand.to_array()` is a width view, so a hole is a
## present-but-EMPTY element, not a missing one — every id read in this file is filtered through
## here first so no `get_card()` call can land on `Hand.EMPTY`.
func _occupied_indices(hand: Array) -> Array[int]:
	var out: Array[int] = []
	for i in hand.size():
		if hand[i] != Hand.EMPTY:
			out.append(i)
	return out


func _other_indices(taken: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for i in HAND_SLOTS:
		if not taken.has(i):
			out.append(i)
	return out


## A colour map total over the occupied slots of `hand` — the shape the runner's wrapper hands over.
func _colors_for(hand: Array) -> Dictionary:
	var out: Dictionary = {}
	for i in _occupied_indices(hand):
		var id: StringName = hand[i]
		var card := _card_database().get_card(id) as CardData
		if card != null:
			out[id] = card.color
	return out


## Reached through the tree, not the autoload identifier — a `--script` SceneTree run does not
## resolve autoload globals at compile time (`test_contact_pipeline.gd`'s mechanism, also used by
## `test_card_hud.gd`).
func _card_database() -> Node:
	return root.get_node("/root/CardDatabase")


## The real ColorSwatch panel of one own-hand slot, read off the real HudRoot the runner built.
func _swatch(index: int) -> Panel:
	var strip := _p1_hud.get_node("HandStrip")
	var card := strip.get_children()[index]
	return card.get_node("ColorSwatch") as Panel


func _swatch_style(index: int) -> StyleBoxFlat:
	return _swatch(index).get_theme_stylebox("panel") as StyleBoxFlat
