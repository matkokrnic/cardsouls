class_name DebugInstrumentPanel
extends Control

## Story 2-6 (AC 4 + AC 5, 2-6/R4/R8/R9): the GLOBAL debug instrument panel — ONE instance for
## the whole window (unlike the per-viewport HudRoot / StateInspector), built in code under
## src/ui/debug/ with NO .tscn. It is the narrowed heir of old AC1's FeatureFlags overlay: it
## flips ONLY presentation-local and controller-local switches, NEVER a FeatureFlags member
## (2-6/R4 — flags stay load-once and runtime-immutable so replay has no silent hole). No
## _process / _physics_process (F1); it is driven entirely by the two switches' toggled signals.
##
## Story 3-0b (AC 2) adds a third instrument — the per-slot window countdown — and RE-FITS the
## box to hold it (see _ready). It is a READ-ONLY display: the runner polls MatchState's
## read-only debug accessor after each advance() and pushes PLAIN INTEGERS here. No state
## handle, no signal, no eighth observation seam, no to_snapshot() extension.
##
## Two switches:
##   1. Analog magnitude (AC 4, 2-6/R8) — flips GamepadProfile.normalize_move_magnitude on the
##      SHARED in-memory resource instance the gamepad controllers already read fresh every tick
##      via sample(). IN MEMORY ONLY: it NEVER calls ResourceSaver and never writes the .tres back
##      to disk, so the authored default (true) returns on the next launch. In the shipped default
##      config (two keyboards) no gamepad controller exists, so the flip is inert on gameplay this
##      session — the AC delivers the toggle only; the feel verdict is animation-gated (rig story).
##   2. Pitch Zone A/B (AC 5, 2-6/R9) — moves BOTH viewports' Pitch Zone placeholder together
##      between its dead-centre anchor (A) and a left-of-the-vitals-bars anchor (B). The switch is
##      SHARED (one switch, both viewports) purely for A/B COMPARABILITY. This decides NOTHING
##      about whether the eventual pitch MECHANIC is shared or per-player (that stays open for E6);
##      it is placeholder geometry only.

## Story 3-0d (AC 7) adds the panel's THIRD and FOURTH controls, its first two runner-reaching
## ones — SAVE, which writes the record so far to `user://` (RECORDING CONTINUES AFTERWARDS: SAVE
## is a snapshot of an always-on stream, AC 6, never a stop), and RELOAD (`3-0d/R13`), which
## triggers a live mid-match balance reload on the SAME reload channel `3-0c` shipped. This panel
## holds no recorder handle, no state handle and no BalanceConfigService reference to do either
## with — only the two Callables below. There is deliberately NO start control and NO load control
## (`3-0d/R1`, `3-0d/R2`): the panel's INSTANTIATED control set is pinned at the exact four names
## {NormalizeMagnitude, PitchZoneLeftOfBars, SaveRecord, ReloadBalance} by
## test/integration/test_record_save_control.gd, which enumerates the real controls in a built
## panel at runtime.
##
## CORRECTED (`3-0d/R20`): this header used to point at a SOURCE SCAN over this file
## (`test_replay_surface_pins.gd`) and to say that AC 11's `replay_record` source scan is what
## keeps a load control impossible. BOTH SCANS ARE DELETED. They were evaded three times over
## three review rounds — a declaration form outside the pattern, a reader that truncated at a `#`
## inside a string literal, GDScript embedded in a `.tscn` the scan never read — and a guard
## believed to hold that does not is worse than no guard. What keeps a load control from doing
## anything now is that `MatchRunner` CONSUMES `replay_record` once in `_ready()` and never reads
## it again, so a mid-session assignment is inert by construction (`3-0d/R20`).

## Set by the runner BEFORE add_child (so _ready sees them). The shared gamepad profile instance
## (the runner loads it via the same res:// path, so the resource cache hands both the same object)
## and both per-viewport HudRoots (whose pitch placeholder the A/B switch repositions).
var gamepad_profile: GamepadProfile
var huds: Array[HudRoot] = []

## Story 3-0d (AC 7): THE FIRST OF THE PANEL'S TWO RUNNER-REACHING SEAMS — a runner-owned Callable
## handed over before add_child, exactly like the two references above (the `gamepad_profile` /
## `huds` precedent generalised, the Dev Note's first option). A Callable rather than a signal the
## runner connects to, because it is the shape this file already uses for "the runner hands the
## panel what it may touch".
var save_record: Callable = Callable()

## Story 3-0d (AC 7, `3-0d/R13`): THE SECOND RUNNER-REACHING SEAM — the live balance reload
## trigger. Same shape as save_record: the panel receives a way to ASK the runner, never a state
## handle and never the BalanceConfigService reference itself.
var reload_balance: Callable = Callable()

## Story 3-0b (AC 2): the two per-slot countdown value Labels, index 0 = P1, 1 = P2. Written
## ONLY by set_window_countdown below, from the runner's polled plain-integer payload.
var _countdown_values: Array[Label] = []


func _init() -> void:
	name = "DebugInstrumentPanel"


func _ready() -> void:
	# Fill the WINDOW so the box's CENTRE anchors resolve against the full window rect, not a
	# zero-size parent. This was the live-smoke S1/S2 bug: with the outer Control left at size 0,
	# the box's anchor 0.5 resolved to x=0 and offset -150 put it at x=-150 — clipping the title
	# ("TRUMENTS") off the left edge and overlapping the top-left deck/reshuffle + StateInspector.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # only the switches grab clicks; gaps fall through
	var box := PanelContainer.new()
	box.name = "InstrumentBox"
	# Placement DERIVED from the measured HUD geometry at the shipped 1152x648 (dev record, S1/S2):
	# the band y[354,452] — between the round-over label (bottom 354) and the vitals bars (top 452)
	# — is EMPTY across the full window width in both viewports (nothing else spans it).
	#
	# Story 3-0b RE-FIT. The band is 98px tall and the 2-6 box already used 89 of it, so the AC 2
	# countdown could not be added as two more ROWS (~50px more) without leaving the band and
	# colliding with the vitals bars. The band is empty across the FULL WIDTH, though, so the
	# spare room is horizontal: the box goes 300 -> 600 wide and the contents split into two
	# COLUMNS (switches | countdown), which keeps the content height at the same ~89 and the box
	# inside the band. New rect: x[276,876], y[356,450] — 2px clear of the band edges on both
	# sides. Machine-checked (both viewports) by test_debug_instruments.gd.
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -300.0
	box.offset_right = 300.0
	box.offset_top = 32.0
	box.offset_bottom = 126.0
	add_child(box)
	var column := VBoxContainer.new()
	column.name = "Instruments"
	column.add_theme_constant_override("separation", 2)
	box.add_child(column)
	var title := Label.new()
	title.text = "-- DEBUG INSTRUMENTS --"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var row := HBoxContainer.new()
	row.name = "InstrumentColumns"
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var switches := VBoxContainer.new()
	switches.name = "Switches"
	switches.add_theme_constant_override("separation", 2)
	row.add_child(switches)

	# Switch 1: analog magnitude. Pressed == normalize (the authored default true), so the button
	# starts pressed and toggling OFF selects variable magnitude.
	var magnitude := CheckButton.new()
	magnitude.name = "NormalizeMagnitude"
	magnitude.text = "Normalize analog magnitude"
	magnitude.button_pressed = gamepad_profile == null or gamepad_profile.normalize_move_magnitude
	magnitude.toggled.connect(_on_normalize_toggled)
	switches.add_child(magnitude)

	# Switch 2: Pitch Zone A/B. Pressed == the left-of-bars candidate (B); unpressed == dead-centre
	# (A, the shipped placement). Starts unpressed so both viewports begin at the current anchor.
	var pitch := CheckButton.new()
	pitch.name = "PitchZoneLeftOfBars"
	pitch.text = "Pitch Zone: left of bars"
	pitch.button_pressed = false
	pitch.toggled.connect(_on_pitch_placement_toggled)
	switches.add_child(pitch)

	# Instrument 3 (story 3-0b, AC 2): the per-slot window countdown, one read-only row per slot.
	_build_window_countdown(row)

	# Controls 3-4 (story 3-0d, AC 7, `3-0d/R13`): SAVE and RELOAD — the panel's two
	# runner-reaching controls. No start, no load.
	_build_record_controls(row)


## AC 2: the countdown column — ONE row per slot, whose Label the runner's polled payload writes
## into. Two rows and no column caption is a size decision, not a style one: the switch column is
## two rows tall, so a third row here would make the countdown column the tallest thing in the box
## and push it out of the empty band (measured: 98px content in a 98px band, zero slack). The
## caption rides in each row's own prefix instead. Every Label CLIPS rather than wrapping or
## growing (clip_text), so a long payload can never push the box's minimum size past the
## re-fitted rect either — which is exactly what the geometry assertion guards.
func _build_window_countdown(row: HBoxContainer) -> void:
	var countdown := VBoxContainer.new()
	countdown.name = "WindowCountdown"
	countdown.add_theme_constant_override("separation", 2)
	countdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(countdown)
	for slot: int in 2:
		var line := Label.new()
		line.name = "Slot%dCountdown" % slot
		line.text = _countdown_text(slot, "--")
		line.clip_text = true
		countdown.add_child(line)
		_countdown_values.append(line)


## Story 3-0d (AC 7, `3-0d/R13`): SAVE and RELOAD, STACKED in a THIRD COLUMN rather than added as
## rows in the switches column — a geometry decision with the same measurement behind it 3-0b's
## re-fit used. The box lives in the empty band y[356,450] (94px); a ROW here would push the box
## out of the band and over the vitals bars, exactly the S1/S2 regression
## test_debug_instruments.gd's layout assertion exists to catch. The band is empty across the FULL
## window width, so the spare room is horizontal — TWO buttons stacked in this one column measure
## the same height as the two-row Switches column beside it (test_debug_instruments.gd's layout
## assertion is the machine check, not this comment).
func _build_record_controls(row: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.name = "RecordControls"
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)
	var save := Button.new()
	save.name = "SaveRecord"
	save.text = "Save record"
	save.pressed.connect(_on_save_pressed)
	column.add_child(save)
	var reload := Button.new()
	reload.name = "ReloadBalance"
	reload.text = "Reload balance"
	reload.pressed.connect(_on_reload_pressed)
	column.add_child(reload)


## AC 2: the runner's per-tick push, called after each advance() with MatchState's read-only
## debug payload — an Array of per-slot Dictionaries of window name -> remaining TICKS, plain
## integers only. This panel holds no state handle and never asks state for anything; it is
## handed values, exactly like every seam-fed consumer. While the match is PAUSED the runner
## does not tick, so it does not poll, and the last stepped tick's values stay on screen — which
## is the whole point of pairing this instrument with AC 1's single-step.
func set_window_countdown(per_slot: Array) -> void:
	for slot: int in _countdown_values.size():
		var entry: Dictionary = per_slot[slot] if slot < per_slot.size() else {}
		_countdown_values[slot].text = _countdown_text(slot, _format_windows(entry))


## One row's text, built in ONE place so the built default and every polled update read the same.
static func _countdown_text(slot: int, windows: String) -> String:
	return "P%d windows  %s" % [slot + 1, windows]


## "windup 7  chain 12" — or "--" when no window is running for that slot.
static func _format_windows(windows: Dictionary) -> String:
	if windows.is_empty():
		return "--"
	var parts: Array[String] = []
	for key: StringName in windows:
		parts.append("%s %d" % [key, int(windows[key])])
	return "  ".join(parts)


## AC 4: flip the AUTHORED field on the shared in-memory GamepadProfile instance. IN MEMORY ONLY —
## no ResourceSaver, no .tres write (2-6/R8). `pressed` true == normalize (unit length), false ==
## variable magnitude. Null-guarded: in a config with no gamepad the field simply has no reader.
func _on_normalize_toggled(pressed: bool) -> void:
	if gamepad_profile != null:
		gamepad_profile.normalize_move_magnitude = pressed


## Story 3-0d (AC 7): hand the press to the runner and do nothing else. The panel does not know
## where the record goes, holds nothing to write it with, and cannot stop the recording — the
## same "act only on what you were handed" shape as the two switches above, with a Callable in
## place of a resource. Null-guarded so a panel built outside the runner is inert, not a crash.
func _on_save_pressed() -> void:
	if save_record.is_valid():
		save_record.call()


## Story 3-0d (AC 7, `3-0d/R13`): hand the press to the runner and do nothing else — the same
## "act only on what you were handed" shape as SAVE. The panel does not re-read
## BalanceConfigService, does not touch MatchState, and cannot enter replay — and that last one is
## true of ANY control this panel could grow (`3-0d/R20`): the runner consumes `replay_record` once
## at `_ready()`, so there is nothing a mid-session assignment could flip.
func _on_reload_pressed() -> void:
	if reload_balance.is_valid():
		reload_balance.call()


## AC 5: move BOTH viewports' pitch placeholder together (shared switch, A/B comparability). The
## left-of-bars anchor is computed by HudRoot from its own vitals-column geometry, independent of
## OpponentHandStrip (2-6/R9 — that provisional 2-5 row must not be anchored to).
func _on_pitch_placement_toggled(left_of_bars: bool) -> void:
	for hud in huds:
		hud.set_pitch_zone_placement(left_of_bars)
