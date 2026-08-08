extends SceneTree

## Story 2-6 integration: the debug instrumentation and the round-lifecycle relay in the LIVE
## scene. One new integration file (the 8-file baseline grows to 9, a dev-pass decision — the
## inspector, the panel, and the round_started relay chain have no home in the existing files).
## All properties observed through the live scene tree only — never a state handle, never runner
## privates. The window is forced to the shipped 1152x648 so the anchored HUD layout resolves at
## real pixels (the headless default is 64x64, at which the fixed-offset HUD is meaningless).
##
##   [AC 2 inspector present + per-slot bound] A StateInspector exists under BOTH SubViewports;
##     its economy rows prime on connect (HP reads a real value, not "--"), and its action-state
##     row is bound per-slot — rolling P1 makes P1's STATE read ROLLING while P2's STATE, never
##     having transitioned, stays "--". A cross-wire would light P2's inspector instead.
##   [AC 4 magnitude switch] Flipping the panel's Normalize switch mutates
##     GamepadProfile.normalize_move_magnitude on the SHARED cached resource instance (the test
##     loads the same res:// path the runner handed the panel). In memory only.
##   [AC 5 pitch A/B shared] Flipping the panel's Pitch Zone switch moves BOTH viewports' PitchZone
##     placeholder together (dead-centre offset_left -70 -> left-of-bars -286), and back.
##   [Story 4-B1 AC 2/AC 3 reveal toggle] Unpressed by default and having produced NOTHING (never
##     reveals in the shipped default configuration, `4-B1/R2`); pressing it reads BOTH players'
##     real hand contents through the runner's read accessor and prints the two SNAP lines to the
##     console; un-pressing it clears them. Checked only after the deal (step 6 of the first
##     advance()) has landed. STRENGTHENED by the 4-B1 code review: both halves must carry a REAL
##     id and the P2 half must EQUAL the P2 HudRoot's own captions (an independent path), so an
##     accessor returning p1 twice or an empty p2 falls. `4-B1/R7` deleted the on-screen output
##     label after it clipped in TWO consecutive live smokes — the console is the reveal now, so
##     the lines are read back off the press instead of off a Label, and the round_started staleness
##     check went with the label (a log cannot go stale).
##   [PANEL LAYOUT — live-smoke S1/S2] The panel's InstrumentBox global rect (a) lies ENTIRELY
##     inside the window rect and (b) intersects the global rect of NO HudRoot child and NO
##     StateInspector in EITHER viewport (screen-mapped through the SubViewportContainer origins).
##     This machine-checks that the panel occludes neither HUD nor gameplay, so S1/S2 cannot
##     regress. Proven to BITE by temporarily moving the box back over the HUD (dev record).
##   [AC 1 round_started relay, END TO END THROUGH advance()] The round-over label is driven
##     visible (SET seat, story 1-7's round_ended path — scaffolding only), then CLEARED by
##     pressing the real p1_debug_reset input: the runner samples it, advance() runs
##     _apply_debug_reset (PUSHES round_started), drains, _relay_round_started emits
##     EventBus.round_started, both huds hide the label. The CLEAR is reached ENTIRELY THROUGH
##     advance() + the runner relay — never bus.round_started.emit(). A counter on
##     EventBus.round_started confirms the relay fired from the runner.
##
## Run: godot --headless --path . --script res://test/integration/test_debug_instruments.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

const RESET_FRAME := 6
const ROLL_FRAME := 14
const REVEAL_FRAME := 5  # after the deal (step 6 of the first advance()), before RESET_FRAME

var _frames := 0
var _p1_state: Label
var _p2_state: Label
var _p1_label: Label
var _p2_label: Label
var _bus: Node
var _bus_round_started_count := 0
var _panel: Node

var _inspectors_exist := false
var _primed_ok := false
var _pitch_ab_ok := false
var _magnitude_ok := false
var _panel_layout_ok := false
var _label_set_ok := false
var _label_cleared_via_advance := false
var _p1_saw_rolling := false
var _p2_state_stayed_blank := true
var _reveal_default_off := false
var _reveal_shows_real_hands := false
var _reveal_clears_on_untoggle := false


func _initialize() -> void:
	root.add_child(load("res://src/main/main.tscn").instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		root.size = Vector2i(1152, 648)  # shipped resolution; the HUD anchors resolve to real pixels
		_run_static_checks()
	if _frames == 3:
		# Layout has settled at 1152x648 — check the panel occupies an empty, on-screen region.
		_panel_layout_ok = _check_panel_layout()
	if _frames == REVEAL_FRAME:
		_check_reveal_toggle()
	if _frames == RESET_FRAME:
		Input.action_press(&"p1_debug_reset")   # clear the label THROUGH advance() + the runner relay
	if _frames == RESET_FRAME + 1:
		Input.action_release(&"p1_debug_reset")
	if _frames == RESET_FRAME + 3:
		_label_cleared_via_advance = (not _p1_label.visible and not _p2_label.visible
			and _bus_round_started_count >= 1)
	if _frames == ROLL_FRAME:
		Input.action_press(&"p1_move_up")
		Input.action_press(&"p1_roll")
	if _frames == ROLL_FRAME + 1:
		Input.action_release(&"p1_roll")
	if _frames > ROLL_FRAME:
		if _p1_state != null and _p1_state.text == "ROLLING":
			_p1_saw_rolling = true
		if _p2_state != null and _p2_state.text != "--":
			_p2_state_stayed_blank = false
	if _frames >= ROLL_FRAME + 20:
		Input.action_release(&"p1_move_up")
		var ok := (_inspectors_exist and _primed_ok and _pitch_ab_ok and _magnitude_ok
			and _panel_layout_ok and _label_set_ok and _label_cleared_via_advance
			and _p1_saw_rolling and _p2_state_stayed_blank and _reveal_default_off
			and _reveal_shows_real_hands and _reveal_clears_on_untoggle)
		print("instruments: inspectors=%s primed=%s pitch_ab=%s magnitude=%s panel_layout=%s label_set=%s label_cleared_via_advance=%s (bus_round_started=%d) p1_rolling=%s p2_blank=%s reveal_default_off=%s reveal_shows_hands=%s reveal_clears=%s" % [
			_inspectors_exist, _primed_ok, _pitch_ab_ok, _magnitude_ok, _panel_layout_ok,
			_label_set_ok, _label_cleared_via_advance, _bus_round_started_count,
			_p1_saw_rolling, _p2_state_stayed_blank, _reveal_default_off,
			_reveal_shows_real_hands, _reveal_clears_on_untoggle])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false


func _run_static_checks() -> void:
	var p1_view := root.get_node_or_null("Main/P1View/P1Viewport")
	var p2_view := root.get_node_or_null("Main/P2View/P2Viewport")
	var p1_insp := p1_view.get_node_or_null("StateInspector") if p1_view != null else null
	var p2_insp := p2_view.get_node_or_null("StateInspector") if p2_view != null else null
	var p1_hud := p1_view.get_node_or_null("HudRoot") if p1_view != null else null
	var p2_hud := p2_view.get_node_or_null("HudRoot") if p2_view != null else null
	var panel := root.get_node_or_null("Main/DebugInstrumentPanel")
	_panel = panel
	_inspectors_exist = p1_insp != null and p2_insp != null and panel != null
	if not _inspectors_exist:
		print("missing: p1_insp=%s p2_insp=%s panel=%s" % [p1_insp, p2_insp, panel])
		return

	# AC 2 prime + per-slot state rows.
	_p1_state = p1_insp.find_child("STATEValue", true, false)
	_p2_state = p2_insp.find_child("STATEValue", true, false)
	var p1_hp: Label = p1_insp.find_child("HPValue", true, false)
	var p2_hp: Label = p2_insp.find_child("HPValue", true, false)
	_primed_ok = (p1_hp != null and p1_hp.text != "--" and p2_hp != null and p2_hp.text != "--"
		and _p1_state != null and _p1_state.text == "--" and _p2_state != null and _p2_state.text == "--")

	# AC 5: the pitch A/B switch moves BOTH placeholders together. offset_left: A -70, B -286.
	var p1_pitch: Control = p1_hud.get_node("PitchZone")
	var p2_pitch: Control = p2_hud.get_node("PitchZone")
	var start_a: bool = is_equal_approx(p1_pitch.offset_left, -70.0) and is_equal_approx(p2_pitch.offset_left, -70.0)
	var pitch_switch: CheckButton = panel.find_child("PitchZoneLeftOfBars", true, false)
	pitch_switch.button_pressed = true
	var both_b: bool = is_equal_approx(p1_pitch.offset_left, -286.0) and is_equal_approx(p2_pitch.offset_left, -286.0)
	pitch_switch.button_pressed = false
	var both_a_again: bool = is_equal_approx(p1_pitch.offset_left, -70.0) and is_equal_approx(p2_pitch.offset_left, -70.0)
	_pitch_ab_ok = start_a and both_b and both_a_again

	# AC 4: the magnitude switch mutates the SHARED profile instance in memory.
	var profile: GamepadProfile = load("res://data/gamepad_profile.tres")
	var mag_switch: CheckButton = panel.find_child("NormalizeMagnitude", true, false)
	var default_on: bool = profile.normalize_move_magnitude == true
	mag_switch.button_pressed = false
	var flipped_off: bool = profile.normalize_move_magnitude == false
	mag_switch.button_pressed = true
	var flipped_back: bool = profile.normalize_move_magnitude == true
	_magnitude_ok = default_on and flipped_off and flipped_back

	# AC 1 relay scaffolding: SET the label visible via the round_ended path (not the link under
	# test), and connect a counter to EventBus.round_started so the CLEAR below is confirmed to
	# arrive THROUGH the runner relay. EventBus is an autoload reached via the tree.
	_p1_label = p1_hud.get_node("RoundOverLabel")
	_p2_label = p2_hud.get_node("RoundOverLabel")
	var start_hidden: bool = not _p1_label.visible and not _p2_label.visible
	_bus = root.get_node("/root/EventBus")
	_bus.round_started.connect(func() -> void: _bus_round_started_count += 1)
	_bus.round_ended.emit(1)
	_label_set_ok = start_hidden and _p1_label.visible and _p2_label.visible
	# The CLEAR is driven by the real p1_debug_reset press through advance() at RESET_FRAME.


## Story 4-B1 (AC 2/AC 3): the reveal toggle, driven through its REAL control (the same
## button_pressed-flip pattern the magnitude/pitch switches above use). Checked after the deal has
## landed (REVEAL_FRAME), so a real, non-empty pair of hands exists to read.
## THE OLD FORM OF THIS CHECK PROVED NOTHING, and the 4-B1 code review caught it: it asked only for
## a comma, but the commas come from the JOINER, not from real card ids. `Hand.to_array()` is the
## WIDTH view with `Hand.EMPTY` at every hole and `str(&"")` is "", so an all-holes pair rendered
## `P1 , , ,  | P2 , , , ` and satisfied every clause; gutting the accessor to
## `[p1.hand.to_array(), []]` — deleting the entire opponent read AC 2/AC 3 exist to deliver — also
## passed, because P1's commas carried the one substantive clause. Mutation row M3 had only ever
## tried `[[], []]`, the weakest adversary.
##
## THE FORM THAT PROVES IT: both halves must carry at least one REAL id (non-empty, not the hole
## marker), and P2's rendered ids must EQUAL the real p2 hand — read through a genuinely
## INDEPENDENT path, the P2 HudRoot's own card captions, which arrive via the cards_changed seam
## and never touch `debug_hand_contents`. An accessor that returned p1 twice, or an empty p2, now
## falls.
##
## THE OUTPUT LABEL IS GONE (`4-B1/R7`, second live smoke): the console carries the reveal now. The
## SUBSTANCE below is untouched — only the source of the two lines moved, from a Label's text to
## the two lines the press itself produced. The REAL CheckButton is still what drives it.
func _check_reveal_toggle() -> void:
	if _panel == null:
		print("REVEAL: panel missing — cannot drive the toggle")
		return
	var toggle: CheckButton = _panel.find_child("RevealOpponentHand", true, false)
	if toggle == null:
		print("REVEAL: missing toggle control")
		return
	_reveal_default_off = not toggle.button_pressed and _panel.last_reveal_lines().is_empty()
	toggle.button_pressed = true
	var lines: PackedStringArray = _panel.last_reveal_lines()
	if lines.size() != 2 or not lines[0].begins_with("SNAP P1: ") or not lines[1].begins_with("P2: "):
		print("REVEAL: unexpected output shape after toggling on: %s" % str(lines))
		return
	var p1_ids := _split_ids(lines[0].trim_prefix("SNAP P1: "))
	var p2_ids := _split_ids(lines[1].trim_prefix("P2: "))
	var p2_captions := _p2_hud_captions()
	_reveal_shows_real_hands = (_has_a_real_id(p1_ids) and _has_a_real_id(p2_ids)
		and p2_ids == p2_captions and p1_ids != p2_ids)
	if not _reveal_shows_real_hands:
		print("REVEAL: p1_ids=%s p2_ids=%s p2_captions=%s" % [p1_ids, p2_ids, p2_captions])
	toggle.button_pressed = false
	_reveal_clears_on_untoggle = _panel.last_reveal_lines().is_empty()


func _split_ids(segment: String) -> Array:
	var out: Array = []
	for part in segment.split(", "):
		out.append(String(part))
	return out


## A real id is a card id, never the empty string and never the hole marker — the distinction the
## old comma test could not draw.
func _has_a_real_id(ids: Array) -> bool:
	for id in ids:
		if id != "" and id != "-":
			return true
	return false


## The INDEPENDENT read of p2's hand: the P2 HudRoot's own captions, populated through the
## cards_changed seam. Holes render "" on the HUD and "-" in the reveal output, so they are mapped
## here — at REVEAL_FRAME the hand is freshly dealt and full, but the mapping keeps the comparison
## honest if that ever stops being true.
func _p2_hud_captions() -> Array:
	var out: Array = []
	var hud := root.get_node_or_null("Main/P2View/P2Viewport/HudRoot")
	var strip := hud.get_node_or_null("HandStrip") if hud != null else null
	if strip == null:
		return out
	for card in strip.get_children():
		var label := card.get_node_or_null("CardName") as Label
		out.append("-" if label == null or label.text == "" else label.text)
	return out


## Live-smoke S1/S2 guard: the panel's InstrumentBox lies fully inside the window and overlaps
## no HudRoot child and no StateInspector in either viewport. HUD rects are viewport-local, mapped
## to screen by adding each SubViewportContainer's origin; the panel is a root-viewport child, so
## its global rect is already screen space.
func _check_panel_layout() -> bool:
	var win := root.get_visible_rect()
	var panel := root.get_node("Main/DebugInstrumentPanel")
	var box: Control = panel.get_node("InstrumentBox")
	var panel_rect := box.get_global_rect()
	if not win.encloses(panel_rect):
		print("PANEL LAYOUT: box %s not inside window %s" % [panel_rect, win])
		return false
	for entry in _hud_screen_rects():
		if panel_rect.intersects(entry[1]):
			print("PANEL LAYOUT: box %s intersects %s %s" % [panel_rect, entry[0], entry[1]])
			return false
	return true


## Every HudRoot child + StateInspector footprint in BOTH viewports, mapped to screen coords.
func _hud_screen_rects() -> Array:
	var out: Array = []
	for view_name in ["P1View", "P2View"]:
		var container: Control = root.get_node("Main/%s" % view_name)
		var origin := container.global_position
		var vp := "P1Viewport" if view_name == "P1View" else "P2Viewport"
		var hud: Control = root.get_node("Main/%s/%s/HudRoot" % [view_name, vp])
		var insp: Control = root.get_node("Main/%s/%s/StateInspector" % [view_name, vp])
		for child in hud.get_children():
			if child is Control:
				var r: Rect2 = child.get_global_rect()
				out.append(["%s/%s" % [view_name, child.name], Rect2(r.position + origin, r.size)])
		for c in insp.get_children():
			if c is Control:
				var r: Rect2 = c.get_global_rect()
				out.append(["%s/StateInspector" % view_name, Rect2(r.position + origin, r.size)])
	return out
