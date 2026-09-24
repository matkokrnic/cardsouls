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


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	# Default ships [KEYBOARD_P1, KEYBOARD_P2]; the roll below drives slot 0 through it.
	root.add_child(scene.instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
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
		var ok: bool = (_both_huds_exist and _primed_ok and _rows_ok
			and _p1_dropped and _p2_stayed_full)
		print("hud: both_exist=%s primed_ok=%s rows_ok=%s p1_dropped=%s p2_stayed_full=%s (p1_stam=%.1f/%.1f p2_stam=%.1f/%.1f)" % [
			_both_huds_exist, _primed_ok, _rows_ok, _p1_dropped, _p2_stayed_full,
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
	return differ and back_is_heavier and _check_price_geometry(own)


## Story 6-5b (AC 23): THE PRICE BLOCK'S GEOMETRY -- every own card panel carries a `CardPrice` label,
## and it occupies its own band without overlapping the id caption above it or the colour swatch below.
##
## GEOMETRY ONLY, AND THAT IS `PROC/R8` RATHER THAN A CHOICE: "machine checks assert GEOMETRY only;
## never assert on-screen text fit from character counts -- any AC hinging on on-screen legibility goes
## to operator smoke at first render". So this asserts the RECTS ARE DISJOINT and the band is tall
## enough to hold two lines at all; whether both prices READ at a glance in a half-width viewport is
## smoke item 12.
##
## THE OVERLAP CHECK IS THE POINT. `hud_root.gd` computes three stacked bands in an 84x92 panel, and the
## 6-0 story's own comment got that arithmetic WRONG BY 5px once and said so -- the swatch was claimed
## to sit below a caption it actually overlapped. A comment cannot catch that twice; this can.
##
## READ OFF THE LIVE TREE, never off the constants: the assertion is about where the controls ACTUALLY
## end up after anchors and offsets resolve, which is exactly what a constant comparison would miss.
func _check_price_geometry(row: Node) -> bool:
	var ok := true
	for card: Node in row.get_children():
		var caption := card.get_node_or_null("CardName") as Control
		var price := card.get_node_or_null("CardPrice") as Control
		var swatch := card.get_node_or_null("ColorSwatch") as Control
		if price == null:
			print("%s carries no CardPrice label -- AC 23's both-prices block is missing" % card.name)
			ok = false
			continue
		if caption == null or swatch == null:
			print("%s is missing the caption or swatch the price band sits between" % card.name)
			ok = false
			continue
		var caption_rect := caption.get_rect()
		var price_rect := price.get_rect()
		var swatch_rect := swatch.get_rect()
		# The price band must be BELOW the caption and ABOVE the swatch, touching neither.
		if price_rect.position.y < caption_rect.end.y:
			print("%s: the price band (top %.1f) overlaps the id caption (bottom %.1f)"
					% [card.name, price_rect.position.y, caption_rect.end.y])
			ok = false
		if price_rect.end.y > swatch_rect.position.y:
			print("%s: the price band (bottom %.1f) overlaps the colour swatch (top %.1f)"
					% [card.name, price_rect.end.y, swatch_rect.position.y])
			ok = false
		# ...and it must be tall enough for the TWO LINES AC 23 requires. Two lines at the authored
		# font size 9 need at least 18px; the authored band is 22.
		if price_rect.size.y < 18.0:
			print("%s: the price band is %.1f px tall -- too short for two price lines"
					% [card.name, price_rect.size.y])
			ok = false
		# The band must also sit INSIDE the panel, horizontally and vertically.
		if price_rect.position.x < 0.0 or price_rect.end.x > card.get_rect().size.x:
			print("%s: the price band escapes the panel horizontally" % card.name)
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
