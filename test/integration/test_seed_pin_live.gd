extends SceneTree

## Story 7-4 (AC 16-19, `7-4/R13`/`R15`): THE PER-LAUNCH SHUFFLE SEED, on the real `main.tscn`, booted five times
## in sequence in one process (each runner freed before the next enters the tree):
##
##   A. knob 0, no override       -> a RANDOM seed, non-zero, captured by the recorder; P1 and P2 dealt different
##                                   hands (each player's own order, C3).
##   B. A's recorded stream as the replay record, WITH a conflicting `seed_override`
##                                -> the RECORD's seed wins, and the deal is A's exactly (AC 19, precedence 1 > 2).
##   C. `seed_override` = A's seed -> the same seed deals the same hands live (AC 16).
##   D. knob 0, no override again -> a DIFFERENT random seed from A (AC 16: two boots draw different seeds).
##   E. the knob pinned IN MEMORY -> the pin wins over the draw; an override still wins over the pin (AC 17/19).
##
## The knob is pinned through Godot's resource cache -- `load(SEED_PIN_PATH)` hands the runner the same SeedPin
## instance this test edits -- so `data/seed_pin.tres` on disk is never written, and the pin is reset to 0 before
## the test ends. The F3 label (AC 18) is read on boot A: it shows the seed in use, hidden with the debug layer.
##
## Run: godot --headless --path . --script res://test/integration/test_seed_pin_live.gd

const READ_AFTER := 4
const OVERRIDE := 999
const PIN := 2468
const PIN_OVERRIDE := 1357

var _frames := 0
var _phase := 0
var _phase_frame := 0
var _runner: Node
var _failures: Array[String] = []
var _checks := 0

var _seed_a := 0
var _hands_a: Array = []
var _stream_a: IntentRecorder
## HELD for the whole pinned boot: Godot drops a resource from its cache once nothing references it, and the next
## `load()` would then read the file on disk (pin 0) instead of this edited instance.
var _pin: SeedPin


func _initialize() -> void:
	_boot(0, null)


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(label)


func _boot(override: int, record: IntentRecorder) -> void:
	_runner = load("res://src/main/main.tscn").instantiate()
	_runner.seed_override = override
	if record != null:
		_runner.replay_record = record
	root.add_child(_runner)
	_phase_frame = _frames


func _seed() -> int:
	return int(_runner._seed_in_use)


func _hands() -> Array:
	return [_runner._match_state.p1.hand.to_array(), _runner._match_state.p2.hand.to_array()]


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames - _phase_frame != READ_AFTER:
		return false
	match _phase:
		0:
			_seed_a = _seed()
			_hands_a = _hands()
			_stream_a = _runner.recorded_stream()
			_check(_seed_a != 0, "A: a random launch seed is drawn and is non-zero (got %d)" % _seed_a)
			_check(_runner._recorder.replay_seed() == _seed_a,
				"A: the recorder captured the seed in use (%d vs %d)" % [_runner._recorder.replay_seed(), _seed_a])
			_check(not (_hands_a[0] as Array).is_empty(), "A: P1 was dealt a hand (non-vacuity)")
			_check(_hands_a[0] != _hands_a[1], "A: each player has their own deck order (C3): %s" % [_hands_a])
			_check_seed_label()
			_next(1, OVERRIDE, _stream_a)
		1:
			_check(_seed() == _seed_a, "B: the REPLAY record's seed (%d) outranks seed_override %d -- got %d"
				% [_seed_a, OVERRIDE, _seed()])
			_check(_hands() == _hands_a, "B: a replay of a random-seed game deals the same hands: %s vs %s"
				% [_hands(), _hands_a])
			_next(2, _seed_a, null)
		2:
			_check(_seed() == _seed_a, "C: seed_override fixes the seed (%d)" % _seed())
			_check(_hands() == _hands_a, "C: the same seed deals the same hands live: %s vs %s" % [_hands(), _hands_a])
			_next(3, 0, null)
		3:
			_check(_seed() != 0 and _seed() != _seed_a,
				"D: a second launch with the knob at 0 draws a DIFFERENT seed (%d vs %d)" % [_seed(), _seed_a])
			_pin = load(_runner.SEED_PIN_PATH) as SeedPin
			_pin.pinned_seed = PIN
			_next(4, 0, null)
		4:
			_check(_seed() == PIN, "E: a non-zero pin is the seed when nothing outranks it (got %d)" % _seed())
			var probe: Node = load("res://src/main/main.tscn").instantiate()
			probe.seed_override = PIN_OVERRIDE
			_check(int(probe._resolve_seed()) == PIN_OVERRIDE, "E: seed_override outranks the pin")
			probe.free()
			_pin.pinned_seed = 0
			_pin = null
			_finish()
	return false


func _check_seed_label() -> void:
	var label := _runner.find_child("SeedLabel", true, false) as Label
	_check(label != null, "AC 18: the debug panel carries a SeedLabel")
	if label == null:
		return
	_check(label.text == "seed %d" % _seed_a, "AC 18: the label shows the seed in use (%s vs %d)" % [label.text, _seed_a])
	_check(not label.is_visible_in_tree(), "AC 18: the label is hidden while the debug layer is")
	_runner.set_debug_layer_visible(true)
	_check(label.is_visible_in_tree(), "AC 18: F3 shows the label with the debug layer")
	_runner.set_debug_layer_visible(false)
	_check(not label.is_visible_in_tree(), "AC 18: ...and hides it again")


func _next(phase: int, override: int, record: IntentRecorder) -> void:
	_runner.free()
	_phase = phase
	_boot(override, record)


func _finish() -> void:
	_runner.free()
	_runner = null
	_stream_a = null
	if _failures.is_empty():
		print("seed_pin: %d checks, all held" % _checks)
		print("RESULT: PASS")
		quit(0)
	else:
		for f in _failures:
			print("FAIL: " + f)
		print("RESULT: FAIL")
		quit(1)
