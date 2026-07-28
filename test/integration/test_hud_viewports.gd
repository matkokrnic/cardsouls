extends SceneTree

## Story 2-4 (AC 7 + AC 4 / 2-4/R7): the per-viewport HUD in the live scene. Replaces the
## retired test_debug_overlay.gd (integration baseline stays at 8, it does NOT drop to 7).
##
## Two properties, both observed through the live scene tree only — never a state handle,
## never runner privates:
##   [existence] A HudRoot exists under BOTH SubViewports ($P1View/P1Viewport and
##     $P2View/P2Viewport) — the same class of property the deleted overlay test proved, now
##     per-viewport (AC 7).
##   [per-slot binding] Each HudRoot is wired to ONLY its own slot's economy callbacks
##     (2-4/R7 no-opponent-read). Proven by ASYMMETRY: prime-on-connect starts both stamina
##     bars full; rolling P1 (a stamina spend on slot 0 only) must move P1's HUD stamina bar
##     and leave P2's untouched. A cross-wire in either direction fails — if P1's HUD read
##     slot 1 it would stay full; if P2's HUD read slot 0 it would drop.
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
		var ok: bool = _both_huds_exist and _primed_ok and _p1_dropped and _p2_stayed_full
		print("hud: both_exist=%s primed_ok=%s p1_dropped=%s p2_stayed_full=%s (p1_stam=%.1f/%.1f p2_stam=%.1f/%.1f)" % [
			_both_huds_exist, _primed_ok, _p1_dropped, _p2_stayed_full,
			_p1_stam.value, _p1_stam.max_value, _p2_stam.value, _p2_stam.max_value])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
