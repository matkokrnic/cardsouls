extends SceneTree

## Story 3-0d (AC 7), integration: PRESSING THE PANEL'S SAVE CONTROL WRITES THE RECORD TO THE
## EXPECTED `user://` PATH — the live scene, the live runner, the real signal.
##
## This cannot be decided in the state harness. The DebugInstrumentPanel builds itself in _ready(),
## which only runs once the node is in a PROCESSING tree, and the Callable it presses lives on the
## runner that owns the recorder. So the claim is about the wired scene or it is about nothing.
##
##   [SAVE writes] With no record file on disk, pressing SAVE (the panel's own test pattern:
##     invoke the control's signal programmatically) leaves a file at the path RecordFile names,
##     and that file LOADS BACK as a structurally complete record whose tick count is the runner's
##     own.
##   [RECORDING CONTINUES] Keep ticking, press SAVE again: the second file is a SECOND path (no
##     overwrite), carries MORE ticks, and is LARGER on disk. SAVE is a snapshot of an always-on
##     stream (AC 6), not a stop — and here that is measured on the LIVE runner rather than on a
##     fixture's imitation of it.
##   [ONE CONTROL] The panel's control set is asserted to be exactly the two shipped switches plus
##     SAVE: no start control and no load control ships (`3-0d/R1`, `3-0d/R2`). The structural
##     half of that pin (nothing else can REACH the runner) is
##     test/state/test_replay_surface_pins.gd; this is the scene-level half.
##
## Run: godot --headless --path . --script res://test/integration/test_record_save_control.gd

const FIRST_PRESS_FRAME := 20
const SECOND_PRESS_FRAME := 60
const DONE_FRAME := 64

var _frames := 0
var _runner: Node
var _panel: Control
var _failures: Array[String] = []

var _first_path := ""
var _second_path := ""
var _first_ticks := 0
var _second_ticks := 0
var _runner_ticks_at_first := 0
var _runner_ticks_at_second := 0
var _first_size := 0
var _second_size := 0


func _initialize() -> void:
	# Start from a clean slate, or "a file appeared" would be satisfied by an old run's leftovers.
	for index in [1, 2]:
		_remove(RecordFile.path_for(index))
	root.add_child(load("res://src/main/main.tscn").instantiate())


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures.append(label)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node("Main")
		_panel = root.get_node("Main/DebugInstrumentPanel")
		_check_control_set()
	if _frames == FIRST_PRESS_FRAME:
		_runner_ticks_at_first = _runner.recorded_stream().tick_count()
		_press_save()
		_first_path = RecordFile.path_for(1)
		_first_ticks = _loaded_tick_count(_first_path)
		_first_size = _file_size(_first_path)
	if _frames == SECOND_PRESS_FRAME:
		_runner_ticks_at_second = _runner.recorded_stream().tick_count()
		_press_save()
		_second_path = RecordFile.path_for(2)
		_second_ticks = _loaded_tick_count(_second_path)
		_second_size = _file_size(_second_path)
	if _frames >= DONE_FRAME:
		_evaluate()
	return false


## The panel's own test pattern (test_debug_instruments.gd flips a CheckButton's property to fire
## its `toggled`): here the Button's `pressed` signal is emitted directly, so the press travels
## the REAL path — the panel's handler, the runner's Callable, RecordFile — rather than the test
## calling the runner itself.
func _press_save() -> void:
	var button: Button = _panel.find_child("SaveRecord", true, false)
	if button == null:
		_failures.append("the panel has no SaveRecord control")
		return
	button.pressed.emit()


## AC 7: the panel ships EXACTLY the two 2-6 switches plus this story's ONE new control.
func _check_control_set() -> void:
	var names: Array[String] = []
	for node in _panel.find_children("*", "Button", true, false):
		names.append(String(node.name))
	names.sort()
	_check(names == ["NormalizeMagnitude", "PitchZoneLeftOfBars", "SaveRecord"],
		"the panel's controls are the two switches plus SAVE — no start control and no load "
		+ "control (`3-0d/R1`, `3-0d/R2`): got %s" % str(names))


func _loaded_tick_count(path: String) -> int:
	var result := RecordFile.load_record(path)
	if result["record"] == null:
		_failures.append("the saved file did not load: %s" % result["error"])
		return -1
	var record: IntentRecorder = result["record"]
	_check(record.has_complete_match_start(),
		"the saved record is structurally complete: missing %s"
				% ", ".join(record.missing_match_start_channels()))
	return record.tick_count()


func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var size := int(f.get_length())
	f.close()
	return size


func _evaluate() -> void:
	_check(FileAccess.file_exists(_first_path),
		"pressing SAVE wrote a file at the expected path %s" % _first_path)
	_check(_first_ticks > 0, "the saved record carries the ticks played so far (got %d)" % _first_ticks)
	_check(_first_ticks == _runner_ticks_at_first,
		"the saved record is the RUNNER's own stream: %d ticks saved vs %d recorded"
				% [_first_ticks, _runner_ticks_at_first])
	# RECORDING CONTINUED across the first SAVE — on the live runner, not on a fixture.
	_check(_runner_ticks_at_second > _runner_ticks_at_first,
		"the runner kept recording after SAVE (%d -> %d ticks)"
				% [_runner_ticks_at_first, _runner_ticks_at_second])
	_check(_second_path != _first_path, "the second SAVE wrote its own file, overwriting nothing")
	_check(FileAccess.file_exists(_second_path), "...which exists at %s" % _second_path)
	_check(_second_ticks == _runner_ticks_at_second,
		"the second file carries the whole stream so far: %d saved vs %d recorded"
				% [_second_ticks, _runner_ticks_at_second])
	_check(_second_ticks > _first_ticks,
		"the second save is CUMULATIVE (%d > %d ticks) — SAVE never restarted the recording"
				% [_second_ticks, _first_ticks])
	_check(_second_size > _first_size,
		"...and is larger on disk (%d > %d bytes), the operator-visible half"
				% [_second_size, _first_size])
	for index in [1, 2]:
		_remove(RecordFile.path_for(index))
	_finish()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish() -> void:
	print("save control: first=%d ticks (%d bytes) second=%d ticks (%d bytes) runner=%d/%d" % [
		_first_ticks, _first_size, _second_ticks, _second_size,
		_runner_ticks_at_first, _runner_ticks_at_second])
	for f in _failures:
		print("FAILED: " + f)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
