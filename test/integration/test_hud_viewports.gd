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
##   [both hand rows + styling] Story 2-5 (AC 7): each viewport contains BOTH the own
##     bottom-centre HandStrip and the opponent top-centre OpponentHandStrip, each with four
##     card panels; the own row is front-styled and the opponent row is back-styled, and the
##     two stylings are GENUINELY different (distinct StyleBoxFlat bg + border width), not two
##     identical blank panels. Made non-vacuous: stripping the back styling collapses the two
##     styles onto one and the "differ" assertion fails (proven by SHA256-verified removal).
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


## Story 2-5 (AC 7): one HUD contains BOTH hand rows — the own bottom-centre HandStrip and the
## opponent top-centre OpponentHandStrip — each with four card panels; the own row is
## front-styled, the opponent row is back-styled, and the two are GENUINELY different, not two
## identical blank panels. Styling is read structurally off the panels' "panel" stylebox
## override — no hardcoded colour values — so the guard survives a later palette change.
##
## Two properties, both required, both structural:
##   [non-identity] the own and opponent styles differ (bg AND border width), so the rows are
##     not two identical blanks. Made non-vacuous by collapse: strip the back styling and both
##     rows share one style, so this fails (SHA256-verified removal in the dev record).
##   [direction — the privacy invariant] the FACE-DOWN opponent back carries the strictly
##     HEAVIER frame than the face-up own card. This pins WHICH row is the back: swapping the
##     two stylings — handing the player their own hand as a back and showing the opponent's
##     face — FAILS here. That inversion is exactly the information leak this story exists to
##     prevent, so a difference-only check is not enough; direction must be pinned. Made
##     non-vacuous by swap: exchanging the two branches inverts the border relation and this
##     fails (SHA256-verified swap in the dev record).
func _check_hand_rows(hud: Node) -> bool:
	var own := hud.get_node_or_null("HandStrip")
	var opp := hud.get_node_or_null("OpponentHandStrip")
	if own == null or opp == null:
		print("hand rows missing: own=%s opp=%s" % [own, opp])
		return false
	var own_style := _row_card_style(own)
	var opp_style := _row_card_style(opp)
	if own_style == null or opp_style == null:
		print("card styling missing: own_style=%s opp_style=%s" % [own_style, opp_style])
		return false
	var own_border := own_style.get_border_width(SIDE_TOP)
	var opp_border := opp_style.get_border_width(SIDE_TOP)
	# Non-identity: the two rows are genuinely different, not two blank panels.
	var differ: bool = own_style.bg_color != opp_style.bg_color and own_border != opp_border
	# Direction (INVARIANT, not incidental): the opponent's face-down back has the strictly
	# heavier frame than the own face-up card. Swapping the two stylings inverts this and fails.
	var back_is_heavier: bool = opp_border > own_border
	if not (differ and back_is_heavier):
		print("hand-row styling wrong: differ=%s back_is_heavier=%s own_bg=%s opp_bg=%s own_border=%d opp_border=%d" % [
			differ, back_is_heavier, own_style.bg_color, opp_style.bg_color, own_border, opp_border])
	return differ and back_is_heavier


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
