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
##   [TWO CONTROLS, EXACT SET] The panel's control set is asserted to be exactly the two shipped
##     2-6 switches plus SAVE and RELOAD (`3-0d/R13`): no start control and no load control ships
##     (`3-0d/R1`, `3-0d/R2`). **As of `3-0d/R20` this is the WHOLE pin, not half of one.** The
##     source-scan half in test/state/test_replay_surface_pins.gd is DELETED — it enumerated
##     declaration TEXT and six declaration forms were found that evaded it — and this check
##     replaces it because it enumerates INSTANTIATED CONTROLS at runtime and so cannot be evaded
##     by how a member is spelled. Its own `Button`-vs-`BaseButton` hole is fixed in the same
##     ruling; see _check_control_set.
##   [RELOAD REACHES THE RUNNER] Pressing RELOAD (the panel's own test pattern, same as SAVE) is
##     proven to reach `match_runner.gd::trigger_live_balance_reload()` in the LIVE scene: the
##     runner's recorded stream gains a second reload event, and P1's stamina — spent below max by
##     a real live roll input, the same live-input pattern test_debug_instruments.gd uses — is
##     observed REFILLING to the maximum through the StateInspector's own primed STAM label. This
##     is the operator-visible half AC 9 ratifies as correct (`3-0d/R10`), now proven wired rather
##     than merely proven reachable in principle.
##
## Run: godot --headless --path . --script res://test/integration/test_record_save_control.gd

const FIRST_PRESS_FRAME := 20
const SECOND_PRESS_FRAME := 60
const DONE_FRAME := 64

# Story 3-0d (AC 7, `3-0d/R13`): the RELOAD sequence, staged entirely inside the slack before
# FIRST_PRESS_FRAME so the pre-existing SAVE timeline is untouched. A live roll (roll_stamina_cost
# == 12.0 against the authored max_stamina == 50.0) spends P1's stamina below max; RELOAD is
# pressed and checked well inside stamina_regen_delay_seconds (0.8s == 48 ticks), so nothing but
# the reload itself can explain the refill observed at POST_RELOAD_CHECK_FRAME.
const ROLL_PRESS_FRAME := 4
const ROLL_RELEASE_FRAME := 5
const MOVE_RELEASE_FRAME := 6
const PRE_RELOAD_CHECK_FRAME := 9
const RELOAD_PRESS_FRAME := 10
const POST_RELOAD_CHECK_FRAME := 13

var _frames := 0
var _runner: Node
var _panel: Control
var _p1_stamina_label: Label
var _failures: Array[String] = []

var _first_path := ""
var _second_path := ""
var _first_ticks := 0
var _second_ticks := 0
var _runner_ticks_at_first := 0
var _runner_ticks_at_second := 0
var _first_size := 0
var _second_size := 0

var _reload_events_before := -1
var _reload_events_after := -1
var _pre_reload_stamina := ""
var _post_reload_stamina := ""


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
		_p1_stamina_label = root.get_node("Main/P1View/P1Viewport/StateInspector").find_child(
			"STAMValue", true, false)
		_check_control_set()
	if _frames == ROLL_PRESS_FRAME:
		Input.action_press(&"p1_move_up")
		Input.action_press(&"p1_roll")
	if _frames == ROLL_RELEASE_FRAME:
		Input.action_release(&"p1_roll")
	if _frames == MOVE_RELEASE_FRAME:
		Input.action_release(&"p1_move_up")
	if _frames == PRE_RELOAD_CHECK_FRAME:
		_pre_reload_stamina = _p1_stamina_label.text
		_reload_events_before = _runner.recorded_stream().reload_event_count()
	if _frames == RELOAD_PRESS_FRAME:
		_press_reload()
	if _frames == POST_RELOAD_CHECK_FRAME:
		_post_reload_stamina = _p1_stamina_label.text
		_reload_events_after = _runner.recorded_stream().reload_event_count()
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


## Story 3-0d (AC 7, `3-0d/R13`): the same real-signal pattern as SAVE, for RELOAD.
func _press_reload() -> void:
	var button: Button = _panel.find_child("ReloadBalance", true, false)
	if button == null:
		_failures.append("the panel has no ReloadBalance control")
		return
	button.pressed.emit()


## AC 7 (amended `3-0d/R13`, and THE ONLY PANEL PIN as of `3-0d/R20`): the panel ships EXACTLY the
## two 2-6 switches plus this story's TWO controls, SAVE and RELOAD — an exact set, not a count.
##
## THIS IS NOW THE WHOLE MECHANISM. The source scan that used to sit beside it in
## test/state/test_replay_surface_pins.gd — enumerating the panel's `Callable` MEMBERS by matching
## declaration text — is DELETED (`3-0d/R20`): six declaration forms were found that evaded it
## (`static var`, `@onready`, an inner-class member, a Callable inside an untyped Dictionary, one
## inside an untyped Array, an untyped member invoked through a local copy), and hardening the
## pattern a third time would only have moved the hole. THIS check is not evadable by declaration
## syntax, because it does not read source at all: it enumerates the controls a BUILT panel
## actually instantiated, in the live scene, after `_ready()` has run.
##
## `3-0d/R20` ALSO FIXES ITS OWN KNOWN HOLE. It used to query `"Button"`, so a `LinkButton` — which
## extends `BaseButton`, NOT `Button` — was invisible to it, and a `LinkButton` is a perfectly good
## thing to hang a load control on. The query is `"BaseButton"`, the common ancestor of every
## clickable control this panel could use (`Button`, `CheckButton`, `CheckBox`, `LinkButton`,
## `OptionButton`, `MenuButton`, `TextureButton`), so a third control fails here whatever class it
## is built from. Proven by mutation at this pass with a `LinkButton`.
##
## THE RESIDUE, STATED (`3-0d/R20` part 5): this pins the panel's instantiated CONTROL SET. It is
## not a claim that no control anywhere could enter replay — that property is carried by the
## runner consuming `replay_record` once at `_ready()` (test_replay_entry_is_inert.gd), which holds
## no matter what this panel grows.
func _check_control_set() -> void:
	var names: Array[String] = []
	for node in _panel.find_children("*", "BaseButton", true, false):
		names.append(String(node.name))
	names.sort()
	_check(names == ["NormalizeMagnitude", "PitchZoneLeftOfBars", "ReloadBalance", "SaveRecord"],
		"the panel's controls are the two switches plus SAVE and RELOAD — no start control and no "
		+ "load control (`3-0d/R1`, `3-0d/R2`): got %s" % str(names))
	# NON-VACUITY, in the form the old `"Button"` query was blind to: the query must SEE a
	# BaseButton subclass that is not a Button. Built, counted, freed — never added to the panel.
	var probe := LinkButton.new()
	var seen := _panel.find_children("*", "BaseButton", true, false).size()
	_panel.add_child(probe)
	_check(_panel.find_children("*", "BaseButton", true, false).size() == seen + 1,
		"the control query SEES a LinkButton — it extends BaseButton, not Button, and the `Button` "
		+ "query this replaced was blind to it (`3-0d/R20` part 4)")
	_panel.remove_child(probe)
	probe.free()


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
	_check(_pre_reload_stamina == "38/50",
		"P1 spent stamina on a live roll before the reload (roll_stamina_cost 12 off max_stamina "
		+ "50) — got %s" % _pre_reload_stamina)
	_check(_reload_events_before == 1,
		"before RELOAD is pressed, the stream carries only the match-start reload event (got %d)"
				% _reload_events_before)
	_check(_reload_events_after == _reload_events_before + 1,
		"pressing RELOAD reached the runner's trigger and the stream gained a SECOND reload event "
		+ "(%d -> %d)" % [_reload_events_before, _reload_events_after])
	_check(_post_reload_stamina == "50/50",
		"the RELOAD button's press reached LIVE STATE: P1's stamina refilled to the new maximum "
		+ "through the SAME per-pool contract AC 9 ratifies as correct (`3-0d/R10`) — got %s"
				% _post_reload_stamina)
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
	print("reload control: stamina=%s->%s reload_events=%d->%d" % [
		_pre_reload_stamina, _post_reload_stamina, _reload_events_before, _reload_events_after])
	for f in _failures:
		print("FAILED: " + f)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
