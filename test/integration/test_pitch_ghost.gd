extends SceneTree

## Story 6-3b (AC 6): THE STAGED-CARD GHOST, on the live-scene HudRoot, driven by DIRECT CALLS to its two
## callbacks -- the `test_card_hud.gd` precedent: the seam-to-callback path is proven elsewhere
## (test_pitch_hud_live.gd, AC 3), and what is under test here is the hand-row RENDER RULE and the
## HUD-local memory behind it, which a direct call reaches exactly and a live staging cannot vary.
##
##   (i)   the ghost is DISTINGUISHABLE from all three existing looks -- full card, in-flight "...",
##         blank -- by caption text and modulate together;
##   (ii)  an OPPONENT payload naming a hand slot never ghosts this HudRoot's row (it drives the
##         opponent zone only);
##   (iii) the ghost SURVIVES a later unrelated `cards_changed` that rewrites all four slots (the other
##         slot's refill) -- the real failure mode, since `on_cards_changed` rewrites every slot;
##   (iv)  the rendered row is IDENTICAL whichever callback arrives first, on a staging tick and on an
##         activation tick (where the slot then shows "...");
##   (v)   an own NO_CARD payload after a debug reset clears the ghost.
##
## Every case runs inside ONE physics frame after the deal, so no live payload can land between two
## direct calls. The HudRoot under test is P1's, so `my_slot` is 0 and an opponent payload is slot 1.
##
## Run: godot --headless --path . --script res://test/integration/test_pitch_ghost.gd

const OBSERVE_FRAME := 4
const MY_SLOT := 0
const OPP_SLOT := 1
const STAGED := 1
const OTHER := 3

var _frames := 0
var _hud: Node
var _failures: Array[String] = []


func _initialize() -> void:
	var runner: Node = load("res://src/main/main.tscn").instantiate()
	# Story 7-4 (`7-4/R15`): this test reads or acts on the DEALT hand, so it fixes the deal at the seed the
	# runner shipped as a constant before 7-4 -- set BEFORE the runner enters the tree.
	runner.seed_override = 12345
	root.add_child(runner)


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures.append(label)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_hud = root.get_node_or_null("Main/P1View/P1Viewport/HudRoot")
		if _hud == null:
			_finish(["P1 HudRoot missing"])
			return false
	if _frames == OBSERVE_FRAME:
		_run()
		_finish(_failures)
	return false


func _run() -> void:
	var live := _row()
	var ids: Array[StringName] = []
	for cell: Array in live:
		ids.append(StringName(cell[0]))
	_check(ids.all(func(id: StringName) -> bool: return id != Hand.EMPTY),
		"precondition: the deal landed and every slot shows a real card: %s" % str(live))
	var x: StringName = ids[STAGED]
	var y := StringName("opponent_card")
	var holed := ids.duplicate()
	holed[STAGED] = Hand.EMPTY
	# The same id->colour map `on_cards_changed`'s real caller derives, so the ghost's swatch half
	# (the id it looks up, per `hud_root.gd:335`) is exercised the way it is in the live match --
	# omitting it leaves `_last_card_colors` empty and the swatch invisible in every case below.
	var colors := _colors_for(ids)

	# (i) the four looks, side by side on one row.
	_stage(holed, [], x, colors)
	var ghost: Array = _row()[STAGED]
	_check(ghost[0] == String(x) and ghost[1] < 1.0
			and is_equal_approx(ghost[1], HudRoot.GHOST_MODULATE.a),
		"(i) the staged slot shows the DIMMED ghost of the staged card: %s" % str(ghost))
	_check(ghost[2] == true and is_equal_approx(ghost[3], HudRoot.GHOST_MODULATE.a),
		"(i) the ghost's swatch is DRAWN and DIMMED: %s" % str(ghost))
	# The FULL look is the SAME card in the SAME slot, as the deal rendered it -- so the ghost must differ
	# from it by look, not merely by caption text.
	var full: Array = live[STAGED]
	_hud.on_cards_changed(holed, 7, 0, [STAGED], colors)
	var in_flight: Array = _row()[STAGED]
	_hud.on_pitch_changed(MY_SLOT, PitchState.NO_CARD, PitchState.NO_HAND_SLOT, false, 0, 0, {}, MY_SLOT)
	_hud.on_cards_changed(holed, 7, 0, [], colors)
	var blank: Array = _row()[STAGED]
	_check(full[0] == String(x) and is_equal_approx(full[1], 1.0),
		"(i) the full look of the same card: its id at full opacity %s" % str(full))
	_check(full[2] == true and is_equal_approx(full[3], 1.0),
		"(i) the full look's swatch is drawn at full opacity %s" % str(full))
	_check(in_flight[0] == HudRoot.IN_FLIGHT_CAPTION and is_equal_approx(in_flight[1], 1.0),
		"(i) in-flight: the caption at full opacity %s" % str(in_flight))
	_check(blank[0] == "" and is_equal_approx(blank[1], 1.0), "(i) blank: no caption %s" % str(blank))
	for other: Array in [full, in_flight, blank]:
		_check(ghost.slice(0, 2) != other.slice(0, 2), "(i) the ghost %s differs from %s" % [ghost, other])

	# (ii) an opponent payload naming THIS row's empty slot does not ghost it.
	_hud.on_pitch_changed(OPP_SLOT, y, STAGED, true, 600, 1200, {}, MY_SLOT)
	_check(_row()[STAGED][0] == "", "(ii) an opponent payload never ghosts this row: %s" % str(_row()))
	_check(_zone_card("OpponentPitch") == String(y) and _zone_card("OwnPitch") == "",
		"(ii) it drives the OPPONENT zone only")
	_hud.on_pitch_changed(OPP_SLOT, PitchState.NO_CARD, PitchState.NO_HAND_SLOT, false, 0, 0, {}, MY_SLOT)

	# (iii) the ghost survives a later rewrite of all four slots (a DIFFERENT slot's refill).
	_stage(holed, [], x, colors)
	var refilled := holed.duplicate()
	refilled[OTHER] = StringName("refilled_card")
	_hud.on_cards_changed(refilled, 6, 1, [], colors)
	var after: Array = _row()
	_check(after[STAGED][0] == String(x) and is_equal_approx(after[STAGED][1], HudRoot.GHOST_MODULATE.a),
		"(iii) the ghost survived an unrelated cards_changed: %s" % str(after))
	_check(after[OTHER][0] == "refilled_card", "(iii) ...which did rewrite the other slot")

	# (iv) order independence -- staging tick, then activation tick.
	var resting := func() -> void:
		_hud.on_pitch_changed(MY_SLOT, PitchState.NO_CARD, PitchState.NO_HAND_SLOT, false, 0, 0, {}, MY_SLOT)
		_hud.on_cards_changed(ids, 7, 0, [], colors)
	resting.call()
	_hud.on_cards_changed(holed, 7, 0, [], colors)
	_hud.on_pitch_changed(MY_SLOT, x, STAGED, false, 1200, 1200, {}, MY_SLOT)
	var stage_cards_first := _row()
	resting.call()
	_hud.on_pitch_changed(MY_SLOT, x, STAGED, false, 1200, 1200, {}, MY_SLOT)
	_hud.on_cards_changed(holed, 7, 0, [], colors)
	var stage_pitch_first := _row()
	_check(stage_cards_first == stage_pitch_first and stage_cards_first[STAGED][0] == String(x),
		"(iv) staging tick renders the same row in either order: %s vs %s"
				% [stage_cards_first, stage_pitch_first])
	_hud.on_cards_changed(holed, 7, 1, [STAGED], colors)
	_hud.on_pitch_changed(MY_SLOT, PitchState.NO_CARD, PitchState.NO_HAND_SLOT, false, 0, 0, {}, MY_SLOT)
	var act_cards_first := _row()
	_stage(holed, [], x, colors)
	_hud.on_pitch_changed(MY_SLOT, PitchState.NO_CARD, PitchState.NO_HAND_SLOT, false, 0, 0, {}, MY_SLOT)
	_hud.on_cards_changed(holed, 7, 1, [STAGED], colors)
	var act_pitch_first := _row()
	_check(act_cards_first == act_pitch_first and act_cards_first[STAGED][0] == HudRoot.IN_FLIGHT_CAPTION,
		"(iv) activation tick renders the same row in either order, the slot in flight: %s vs %s"
				% [act_cards_first, act_pitch_first])

	# (v) a debug reset's own NO_CARD payload clears the ghost (before the redeal lands).
	_stage(holed, [], x, colors)
	_hud.on_pitch_changed(MY_SLOT, PitchState.NO_CARD, PitchState.NO_HAND_SLOT, false, 0, 0, {}, MY_SLOT)
	_check(_row()[STAGED][0] == "" and _zone_card("OwnPitch") == "",
		"(v) an own NO_CARD payload clears the ghost and the own zone: %s" % str(_row()))

	# Leave the HUD as the live match had it.
	_hud.on_cards_changed(ids, 7, 0, [], colors)


## Put this root in the "own card `card` staged from STAGED" state from a known hand payload.
func _stage(hand: Array, owed: Array, card: StringName, card_colors: Dictionary) -> void:
	_hud.on_cards_changed(hand, 7, 0, owed, card_colors)
	_hud.on_pitch_changed(MY_SLOT, card, STAGED, false, 1200, 1200, {}, MY_SLOT)


## A colour map total over `hand`'s real card ids, the shape `on_cards_changed`'s `card_colors`
## expects -- the runner's wrapper derives the same map (`test_card_tint_live.gd`'s precedent).
func _colors_for(hand: Array) -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in hand:
		if id != Hand.EMPTY:
			var card := _card_database().get_card(id) as CardData
			if card != null:
				out[id] = card.color
	return out


func _card_database() -> Node:
	return root.get_node("/root/CardDatabase")


## Each hand slot as [caption text, caption modulate alpha, swatch visible, swatch modulate alpha].
func _row() -> Array:
	var out: Array = []
	var strip: Node = _hud.get_node("HandStrip")
	for i in 4:
		var card: Node = strip.get_node("Card%d" % i)
		var caption: Label = card.get_node("CardName")
		var swatch: Control = card.get_node("ColorSwatch")
		out.append([caption.text, caption.modulate.a, swatch.visible, swatch.modulate.a])
	return out


func _zone_card(zone_name: String) -> String:
	return (_hud.get_node("%s/Card" % zone_name) as Label).text


func _finish(failures: Array) -> void:
	for f in failures:
		print("FAIL: %s" % f)
	print("pitch_ghost: %d failure(s)" % failures.size())
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
