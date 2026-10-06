extends SceneTree

## Story 2-4 (AC 7 + AC 4 / 2-4/R7): the per-viewport HUD in the live scene. Replaces the
## retired test_debug_overlay.gd (integration baseline stays at 8, it does NOT drop to 7).
##
## Properties, all observed through the live scene tree only — never a state handle, never
## runner privates:
##   [existence] A HudRoot exists under BOTH SubViewports ($P1View/P1Viewport and
##     $P2View/P2Viewport) — the same class of property the deleted overlay test proved, now
##     per-viewport (AC 7).
##   [per-slot binding] Each HudRoot is wired to ONLY its own slot's economy callbacks
##     (2-4/R7 no-opponent-read). Proven by ASYMMETRY: prime-on-connect starts both stamina
##     bars full; rolling P1 (a stamina spend on slot 0 only) must move P1's HUD stamina bar
##     and leave P2's untouched. A cross-wire in either direction fails — if P1's HUD read
##     slot 1 it would stay full; if P2's HUD read slot 0 it would drop. Story 2-5 (AC 3):
##     this SAME asymmetry is the pin that "no HUD root is ever constructed with the opposing
##     slot's index" — a HudRoot takes no slot argument at all, and the runner's per-slot
##     wiring being uncrossed is exactly what this proves. The 2-5 rows below are EXTENSIONS
##     of this existing per-slot binding assertion, not a duplicate binding test.
##   [the one hand row + its styling] Story 2-5 (AC 7) AS AMENDED BY 3-6 (AC 1): each viewport
##     contains the own bottom-centre HandStrip with four card panels, and NO OpponentHandStrip —
##     the opponent row is DELETED (E3-RG/R4), not hidden, which is why the assertion is on
##     absence from the tree rather than on visibility. The own row is FRONT-styled, and the
##     privacy DIRECTION is still pinned: the face-down style the surviving `_make_card_face_style`
##     branch produces must be strictly heavier-framed than the face-up one the row carries, so
##     swapping the two branches — handing a player their own hand as a card back — still fails
##     here even though nothing renders a back today.
##
## Also checks prime-on-connect (AC 2): both stamina bars read full at frame 1, before any
## signal, so the bars are not empty until first change.
##
## Run: godot --headless --path . --script res://test/integration/test_hud_viewports.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

const ROLL_FRAME := 6

var _p1_stam: ProgressBar
var _p2_stam: ProgressBar
var _frames := 0

var _both_huds_exist := false
var _primed_ok := false
var _rows_ok := false
var _p1_dropped := false
var _p2_stayed_full := true
var _layout_ok := false


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	# Default ships [KEYBOARD_P1, KEYBOARD_P2]; the roll below drives slot 0 through it.
	root.add_child(scene.instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		# 7-6 POLISH 2: the SHIPPED resolution -- the game starts fullscreen at 1920x1080 (stretch mode `disabled`,
		# so each half's HUD is 960x1080 native pixels) and the layout check reads those real pixels.
		root.size = Vector2i(1920, 1080)
		# _ready has run (main loop started): both HUD roots and their primed bars exist.
		var p1_hud := root.get_node_or_null("Main/P1View/P1Viewport/HudRoot")
		var p2_hud := root.get_node_or_null("Main/P2View/P2Viewport/HudRoot")
		_both_huds_exist = p1_hud != null and p2_hud != null
		if not _both_huds_exist:
			print("HUD roots missing: p1=%s p2=%s" % [p1_hud, p2_hud])
			print("RESULT: FAIL")
			quit(1)
			return false
		_p1_stam = p1_hud.get_node("Vitals/STAMRow/STAMBar")
		_p2_stam = p2_hud.get_node("Vitals/STAMRow/STAMBar")
		# Prime-on-connect (AC 2), made to BITE: the bars are constructed EMPTY with max_value
		# == 1.0 (no authored max baked in, D2), so a REAL maximum on the bar can ONLY have
		# arrived through the seam's priming call. Assert HP + stamina primed to their real max
		# and FULL, and mana primed to its real max at current 0 (mana starts empty, E1) — on
		# BOTH huds. `max_value > 1.0` is the bite: strip the three priming calls and every bar
		# stays 0/1, so this fails. Values are read structurally (full == value==max_value,
		# empty == value 0), never hardcoded balance numbers.
		var p1_hp: ProgressBar = p1_hud.get_node("Vitals/HPRow/HPBar")
		var p2_hp: ProgressBar = p2_hud.get_node("Vitals/HPRow/HPBar")
		var p1_mana: ProgressBar = p1_hud.get_node("Vitals/MANARow/MANABar")
		var p2_mana: ProgressBar = p2_hud.get_node("Vitals/MANARow/MANABar")
		_primed_ok = (
			p1_hp.max_value > 1.0 and p1_hp.value == p1_hp.max_value
			and _p1_stam.max_value > 1.0 and _p1_stam.value == _p1_stam.max_value
			and p1_mana.max_value > 1.0 and p1_mana.value == 0.0
			and p2_hp.max_value > 1.0 and p2_hp.value == p2_hp.max_value
			and _p2_stam.max_value > 1.0 and _p2_stam.value == _p2_stam.max_value
			and p2_mana.max_value > 1.0 and p2_mana.value == 0.0
		)
		# Story 2-5 (AC 7): both hand rows present per viewport, own front-styled, opponent
		# back-styled, and the two stylings genuinely different — on BOTH huds.
		_rows_ok = _check_hand_rows(p1_hud) and _check_hand_rows(p2_hud)
	if _frames == 3:
		# 7-6 POLISH (P1, review fix F6 extended): the re-derived half-screen layout, once anchors have settled.
		_layout_ok = _check_layout("P1View", "P1Viewport") and _check_layout("P2View", "P2Viewport")
	if _frames == ROLL_FRAME:
		Input.action_press(&"p1_move_up")  # a move dir so the roll has a direction
		Input.action_press(&"p1_roll")     # spends stamina on SLOT 0 only
	if _frames == ROLL_FRAME + 1:
		Input.action_release(&"p1_roll")
	if _frames == ROLL_FRAME + 3:
		Input.action_release(&"p1_move_up")
	if _frames > 1:
		# P1's stamina must drop (its own slot's spend reached its own HUD); P2's must never
		# move (its HUD cannot reach slot 0's payload).
		if _p1_stam.value < _p1_stam.max_value - 0.5:
			_p1_dropped = true
		if _p2_stam.value != _p2_stam.max_value:
			_p2_stayed_full = false
	if _frames >= ROLL_FRAME + 20:
		var ok: bool = (_both_huds_exist and _primed_ok and _rows_ok and _layout_ok
			and _p1_dropped and _p2_stayed_full)
		print("hud: both_exist=%s primed_ok=%s rows_ok=%s layout_ok=%s p1_dropped=%s p2_stayed_full=%s (p1_stam=%.1f/%.1f p2_stam=%.1f/%.1f)" % [
			_both_huds_exist, _primed_ok, _rows_ok, _layout_ok, _p1_dropped, _p2_stayed_full,
			_p1_stam.value, _p1_stam.max_value, _p2_stam.value, _p2_stam.max_value])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false


## Story 2-5 (AC 7) as amended by story 3-6 (AC 1): one HUD contains exactly ONE hand row — the
## own bottom-centre HandStrip with four card panels — and NO opponent row. Styling is read
## structurally off the panels' "panel" stylebox override — no hardcoded colour values — so the
## guard survives a later palette change.
##
## Three properties, all required, all structural:
##   [deletion] OpponentHandStrip is absent from the tree. Asserted on ABSENCE, not on
##     visibility: E3-RG/R4 deletes the row, and a hidden row would still be a rendering path
##     carrying a count whose publicity was never decided.
##   [non-identity] the face-up style the row carries and the face-down style the surviving
##     branch produces differ (bg AND border width), so the privacy decision is still a real
##     distinction rather than two identical blanks. Collapsing the two branches onto one style
##     fails here.
##   [direction — the privacy invariant] the FACE-DOWN style carries the strictly HEAVIER frame
##     than the face-up card the player is shown. This is what pins WHICH styling is the back:
##     swapping the two branches — handing the player their own hand as a card back — FAILS here
##     even though no back is rendered today, which is what keeps the deferred reveal toggle
##     (3-6/R1) inheriting a decision rather than a coin flip. The comparison is made against a
##     TREE-LESS HudRoot instance calling the same seat, because there is no second row left to
##     read it off.
func _check_hand_rows(hud: Node) -> bool:
	var own := hud.get_node_or_null("HandStrip")
	if own == null:
		print("own hand row missing")
		return false
	if hud.get_node_or_null("OpponentHandStrip") != null:
		print("OpponentHandStrip still present — 3-6 AC 1 deletes it, it is not hidden")
		return false
	var own_style := _row_card_style(own)
	if own_style == null:
		print("card styling missing on the own row")
		return false
	# The face-down style, from the ONE seat that decides it (2-5/R4). Built off a tree-less
	# instance: _make_card_face_style is a pure function of its argument, so no _ready, no
	# viewport and no state are involved.
	var probe := HudRoot.new()
	var back_style := probe._make_card_face_style(false) as StyleBoxFlat
	probe.free()
	if back_style == null:
		print("the face-down styling branch is gone — the privacy decision has no seat")
		return false
	var own_border := own_style.get_border_width(SIDE_TOP)
	var back_border := back_style.get_border_width(SIDE_TOP)
	var differ: bool = own_style.bg_color != back_style.bg_color and own_border != back_border
	var back_is_heavier: bool = back_border > own_border
	if not (differ and back_is_heavier):
		print("hand-row styling wrong: differ=%s back_is_heavier=%s own_bg=%s back_bg=%s own_border=%d back_border=%d" % [
			differ, back_is_heavier, own_style.bg_color, back_style.bg_color, own_border, back_border])
	# Story 7-6: the 6-5b `_check_price_geometry` that stood here is RETIRED with the two-line price block it
	# measured (R1 replaced it with the two-half card face). The face's geometry -- equal halves, divider,
	# reserved slot, costs clear of the colour -- is asserted by test_card_face.gd (AC 5/7/8/10).
	# 7-6 review fix (operator ruling F6): the two checks that retirement LOST come back here, on the live tree.
	return differ and back_is_heavier and _check_face_geometry(own)


## 7-6 review fix (F6) -- what the retired `_check_price_geometry` guarded, re-stated for the two-half face and
## READ OFF THE LIVE SPLIT-VIEWPORT TREE (its own reason, verbatim: where the controls actually end up after
## anchors and offsets resolve). Every card panel: each `Cost` rect lies INSIDE the panel, and no cost rect
## overlaps the pitch half's `Pips` row or the `KeywordSlot`. Geometry only (`PROC/R8`).
func _check_face_geometry(row: Node) -> bool:
	var ok := true
	for card: Node in row.get_children():
		var panel := card as Control
		var origin := panel.get_global_rect().position
		var panel_rect := Rect2(Vector2.ZERO, panel.size)
		var pips := panel.get_node_or_null("PitchHalf/Pips") as Control
		var keyword := panel.get_node_or_null("KeywordSlot") as Control
		var costs: Array[Control] = []
		for path in ["NormalHalf/Cost", "PitchHalf/Cost"]:
			var c := panel.get_node_or_null(path) as Control
			if c != null:
				costs.append(c)
		if pips == null or keyword == null or costs.size() != 2:
			print("%s is missing a Cost, the Pips row or the KeywordSlot" % card.name)
			ok = false
			continue
		var pip_rect := Rect2(pips.get_global_rect().position - origin, pips.size)
		var key_rect := Rect2(keyword.get_global_rect().position - origin, keyword.size)
		for cost: Control in costs:
			var r := Rect2(cost.get_global_rect().position - origin, cost.size)
			if not panel_rect.encloses(r):
				print("%s: %s %s escapes the panel %s" % [card.name, cost.get_path(), r, panel_rect])
				ok = false
			if r.intersects(pip_rect):
				print("%s: %s %s overlaps the pip row %s" % [card.name, cost.get_path(), r, pip_rect])
				ok = false
			if r.intersects(key_rect):
				print("%s: %s %s overlaps the keyword slot %s" % [card.name, cost.get_path(), r, key_rect])
				ok = false
	return ok


## Returns the shared StyleBoxFlat applied to a row's four card panels, or null if the row does
## not have exactly four panels each carrying a "panel" stylebox override (proving the row is
## explicitly styled, not falling back to the default theme). Reads only the live scene tree.
func _row_card_style(row: Node) -> StyleBoxFlat:
	var cards := row.get_children()
	if cards.size() != 4:
		print("row %s has %d panels, expected 4" % [row.name, cards.size()])
		return null
	var style: StyleBoxFlat = null
	for card: Node in cards:
		if not (card is Panel) or not card.has_theme_stylebox_override("panel"):
			print("row %s child %s is not a styled Panel" % [row.name, card.name])
			return null
		style = card.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			return null
	return style


## 7-6 POLISH 2 (operator ruling P9; review fix F6 extended to whatever moved): THE HALF-SCREEN LAYOUT at the shipped
## 960x1080 half, read off the live tree. Every laid-out HUD element -- EACH CARD of the arc at its highest reach
## (its rest rect, middle pair raised, plus the armed lift and the armed frame's outset all round), the vitals under
## the middle pair, both pitch zones beside the hand, the history strip, the deck indicator, the orb counters and the
## round-over label -- lies fully inside the viewport and overlaps none of the others nor that viewport's
## StateInspector. The arc itself is checked: the middle pair rests higher than the outer cards, the vitals sit
## below the middle pair and reach below the outer cards' bottom edge, and each zone keeps a gap from the hand.
## The debug InstrumentBox is NOT checked: hidden by default and allowed to overlay the HUD (P12). Geometry only
## (`PROC/R8`).
func _check_layout(view_name: String, vp_name: String) -> bool:
	var ok := true
	var hud := root.get_node("Main/%s/%s/HudRoot" % [view_name, vp_name]) as Control
	var inspector := root.get_node("Main/%s/%s/StateInspector" % [view_name, vp_name]) as Control
	var vp_rect := Rect2(Vector2.ZERO, hud.size)
	var rects: Array = []
	for name in ["Vitals", "OwnPitch", "OpponentPitch", "HistoryStrip", "DeckIndicator", "OrbCounters",
			"RoundOverLabel"]:
		var c := hud.get_node_or_null(name) as Control
		if c == null:
			print("LAYOUT %s: %s missing" % [view_name, name])
			ok = false
			continue
		rects.append([name, c.get_global_rect()])
	var cards: Array[Rect2] = []
	for i in 4:
		var card := hud.get_node("HandStrip/Card%d" % i) as Control
		var r := card.get_global_rect()
		cards.append(r)
		# P14: the armed frame is the card's own (inside it); only its glow reaches outside.
		var glow := float(HudRoot.ARMED_GLOW_PX)
		var reach := HudRoot.CARD_MODE_ARMED_LIFT_PX + glow
		rects.append(["Card%d" % i, Rect2(r.position - Vector2(glow, reach),
				r.size + Vector2(2.0 * glow, reach + glow))])
	var vitals := (hud.get_node("Vitals") as Control).get_global_rect()
	if not (cards[1].position.y < cards[0].position.y and cards[2].position.y < cards[3].position.y):
		print("LAYOUT %s: the hand is not an arc %s" % [view_name, cards])
		ok = false
	if not (vitals.position.y >= cards[1].end.y and vitals.end.y > cards[0].end.y
			and vitals.position.x >= cards[1].position.x - 0.5 and vitals.end.x <= cards[2].end.x + 0.5):
		print("LAYOUT %s: the vitals %s are not beneath the middle pair %s %s" % [view_name, vitals, cards[1], cards[2]])
		ok = false
	for zone_name in ["OwnPitch", "OpponentPitch"]:
		var z := (hud.get_node(zone_name) as Control).get_global_rect()
		var gap := minf(absf(z.end.x - cards[0].position.x), absf(z.position.x - cards[3].end.x))
		if gap < 12.0:
			print("LAYOUT %s: %s sits %.1f px from the hand -- it would read as a card" % [view_name, zone_name, gap])
			ok = false
		# 7-6 POLISH 3 (operator ruling P15): CARD-SIZED, bottom-aligned with the outer cards, and the zone-to-hand gap
		# EQUALS the zone-to-edge gap.
		if not z.size.is_equal_approx(cards[0].size) or not is_equal_approx(z.end.y, cards[0].end.y):
			print("LAYOUT %s: %s %s is not card-sized and bottom-aligned with %s" % [view_name, zone_name, z, cards[0]])
			ok = false
		var to_edge := z.position.x - vp_rect.position.x if z.end.x <= cards[0].position.x else vp_rect.end.x - z.end.x
		var to_hand := cards[0].position.x - z.end.x if z.end.x <= cards[0].position.x else z.position.x - cards[3].end.x
		if absf(to_edge - to_hand) > 1.0:
			print("LAYOUT %s: %s gaps unequal -- %.1f to the edge, %.1f to the hand" % [view_name, zone_name, to_edge, to_hand])
			ok = false
	for c in inspector.get_children():
		if c is Control:
			rects.append(["StateInspector", (c as Control).get_global_rect()])
	for e: Array in rects:
		if e[0] != "StateInspector" and not vp_rect.encloses(e[1]):
			print("LAYOUT %s: %s %s leaves the viewport %s" % [view_name, e[0], e[1], vp_rect])
			ok = false
	for a in rects.size():
		for b in range(a + 1, rects.size()):
			# The ONE exempt pair: the debug StateInspector (y 60) and the deck indicator (bottom y 62) have shared a
			# 2 px band since 2-6; neither moved in 7-6. Disclosed here rather than silently excluded.
			if [rects[a][0], rects[b][0]] in [["DeckIndicator", "StateInspector"], ["StateInspector", "DeckIndicator"]]:
				continue
			if (rects[a][1] as Rect2).intersects(rects[b][1]):
				print("LAYOUT %s: %s %s overlaps %s %s" % [view_name, rects[a][0], rects[a][1], rects[b][0],
						rects[b][1]])
				ok = false
	return ok
