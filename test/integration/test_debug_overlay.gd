extends SceneTree

## Story 1-3c: the debug overlay tracks hero action states in the real scene, end to end
## through the seam: press -> KeyboardController -> advance -> queued action_state_changed
## -> runner drain -> overlay label. The test observes ONLY the overlay's Label.text (its
## output) — never state, never runner privates; reading the label each frame is the test
## watching the screen, not the overlay polling.
##
## Press timing is DERIVED from the authored balance .tres (via BalanceTicks), so tuning
## durations reschedules the test instead of breaking it. Assumption: the authored chain
## window covers at least the first ~3 recovery ticks (currently 30 ticks; the 1-3b audit
## guarantees >= 1).
##
## Run: godot --headless --path . --script res://test/integration/test_debug_overlay.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

const PRESS1_FRAME := 5

var _p1_label: Label
var _p2_label: Label
var _frames := 0
var _press2_frame := 0
var _swing_ticks := 0
var _deadline := 0

var _init_idle_ok := false
var _saw_swing_0 := false
var _saw_swing_1 := false
var _p2_stayed_idle := true


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())
	var config: BalanceConfig = load("res://data/balance/balance_config.tres")
	var ticks := BalanceTicks.from_config(config)
	# Recovery (and the chain window) opens windup+active ticks after attack entry; press
	# the chain attack 2 ticks into it. One full swing is windup+active+recovery ticks.
	_press2_frame = PRESS1_FRAME + ticks.attack_windup_ticks + ticks.attack_active_ticks + 2
	_swing_ticks = ticks.attack_windup_ticks + ticks.attack_active_ticks + ticks.attack_recovery_ticks
	_deadline = _press2_frame + _swing_ticks + 60


func _physics_process(_delta: float) -> bool:
	_frames += 1
	# Labels are created by the overlay's _ready, which fires once the main loop starts.
	if _frames == 1:
		_p1_label = root.get_node_or_null("Main/DebugStateOverlay/P1Label")
		_p2_label = root.get_node_or_null("Main/DebugStateOverlay/P2Label")
		if _p1_label == null or _p2_label == null:
			# Fail FAST and clean — a silent per-frame error loop would hang the harness.
			print("overlay labels not found in the scene tree")
			print("RESULT: FAIL")
			quit(1)
			return false
	if _frames == 2:
		# Before any press: labels initialized to IDLE without waiting for a signal.
		_init_idle_ok = _p1_label.text == "P1: IDLE" and _p2_label.text == "P2: IDLE"
	if _frames == PRESS1_FRAME:
		Input.action_press(&"p1_attack")
	if _frames == PRESS1_FRAME + 2:
		Input.action_release(&"p1_attack")
	if _frames == _press2_frame:
		Input.action_press(&"p1_attack")  # lands in recovery, inside the chain window
	if _frames == _press2_frame + 2:
		Input.action_release(&"p1_attack")
	if _p1_label.text == "P1: ATTACKING (swing 0)":
		_saw_swing_0 = true
	if _p1_label.text == "P1: ATTACKING (swing 1)":
		_saw_swing_1 = true
	if _p2_label.text != "P2: IDLE":
		_p2_stayed_idle = false
	var back_to_idle: bool = _saw_swing_1 and _p1_label.text == "P1: IDLE"
	if back_to_idle or _frames >= _deadline:
		var ok: bool = _init_idle_ok and _saw_swing_0 and _saw_swing_1 and back_to_idle and _p2_stayed_idle
		print("overlay: init_idle=%s swing0=%s swing1=%s reset_to_idle=%s p2_idle=%s (frames=%d)" % [
			_init_idle_ok, _saw_swing_0, _saw_swing_1, back_to_idle, _p2_stayed_idle, _frames])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
