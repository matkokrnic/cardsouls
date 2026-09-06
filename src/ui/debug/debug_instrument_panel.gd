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

## Story 4-B1 (AC 2/AC 3, `4-B1/R1`/`4-B1/R2`) adds the panel's FIFTH control and its THIRD
## runner-reaching seam — REVEAL, a debug-only toggle that reads BOTH players' hand contents
## through a Callable read accessor (`reveal_opponent_hand`, the save_record/reload_balance
## Callable-handoff shape generalised from an action to a read) and prints them to the panel's own
## output Label. ON-DEMAND ONLY: the accessor is called from the toggle's own `toggled` handler,
## never per-frame and never a new observation seam — HudRoot never learns of it, and
## `test_runner_observation_seams_are_exactly_nine` stays untouched. The pinned control set in
## `test/integration/test_record_save_control.gd` IS amended to five names, a reviewed named
## exception on the `3-6/R2` precedent (`4-B1/R1`). Unpressed by default and reachable only by a
## manual mouse click (`4-B1/R2`): it never reveals anything in the shipped default configuration,
## and it changes no FeatureFlags member and no state-layer value.

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

## Story 4-B1 (AC 2/AC 3, `4-B1/R1`): THE THIRD RUNNER-REACHING SEAM — a READ accessor, not an
## action, for both players' hand contents. Same Callable-handoff shape as the two above: the
## panel receives a way to ASK, never a MatchState handle and never a HudRoot reference (it never
## reaches opponent data through either). Called ONLY from the reveal toggle's own handler below —
## never per-frame (F1) and never a new observation seam (`test_runner_observation_seams_are_
## exactly_eight` stays untouched, `4-B1/R1`).
var reveal_opponent_hand: Callable = Callable()

## Story 3-0b (AC 2): the two per-slot countdown value Labels, index 0 = P1, 1 = P2. Written
## ONLY by set_window_countdown below, from the runner's polled plain-integer payload.
var _countdown_values: Array[Label] = []

## Story 4-B1 (`4-B1/R7`, second live smoke): THE REVEAL HAS NO ON-SCREEN OUTPUT. Two label passes
## (one line, then two lines at 11px) both clipped at the box edge — a label locked inside the
## 94px band cannot legibly carry two hands, and the width it demanded made the mid-screen panel
## bulky. The CONSOLE is the reveal output now: each press prints the two SNAP lines, which is also
## copy-pasteable, is a log rather than a live view (so it cannot go stale), and does not duplicate
## what both HudRoots already render for their own halves.
##
## This member exists so the assertion can drive the REAL CheckButton and read what the press
## actually produced, rather than re-deriving it. Written only by _on_reveal_toggled: the two lines
## on press, emptied on release.
var _last_reveal_lines: PackedStringArray = []


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
	# inside the band. 3-0b's rect was x[276,876], y[356,450] — 2px clear of the band edges on both
	# sides. Machine-checked (both viewports) by test_debug_instruments.gd.
	#
	# Story 4-B1 (AC 2): the FOURTH column (reveal toggle + output) is the SAME horizontal-only
	# move again -- the band still has zero VERTICAL slack (this box's height is untouched, 32 to
	# 126), so a fifth control can only grow the box WIDER, never taller. 600 -> 800.
	#
	# The 4-B1 code review's rect was x[176,976], y[356,450]: the x half of 3-0b's figure above is
	# HISTORY, not a description of this code -- the 2px band clearance is the half that survives,
	# because only the width ever moves.
	#
	# The first live smoke drove it 800 -> 1000 (x[76,1076]) chasing a label that would not fit.
	# That is history too: `4-B1/R7` deleted the label instead, so the reveal column is now a bare
	# CheckButton and the box SHRINKS below even its pre-smoke width.
	#
	# THE SHIPPED RECT IS x[236,916], y[356,450]. The width is MEASURED, not estimated: the four
	# columns report a combined minimum of 658px at runtime, so 680 is that plus a small margin
	# against font-metric drift. HEIGHT UNTOUCHED for the fourth time and the same reason -- zero
	# vertical slack in the band. 236px clear of the window on both sides at 1152 wide, and the
	# narrowest this panel has been since 3-0b. Machine-checked the same way, in both viewports.
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -340.0
	box.offset_right = 340.0
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

	# Control 5 (story 4-B1, AC 2/AC 3, `4-B1/R1`/`4-B1/R2`): the reveal-opponent-hand toggle.
	# Debug-only, mouse-only, unpressed by default (never reachable in the shipped default
	# configuration unless the operator clicks it).
	_build_reveal_control(row)


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


## Story 4-B1 (AC 2/AC 3, `4-B1/R1`): the FIFTH control, in its OWN fourth column — the same
## horizontal-only geometry move as `_build_record_controls` above, for the same reason (zero
## vertical slack in the band). A CheckButton (the toggle) plus a read-only output Label, the
## same two-row shape as the columns beside it. Unpressed by default (`4-B1/R2`): the toggle
## never reveals anything unless the operator clicks it.
##
## SMOKE FINDINGS, TWICE (operator, live runs, 2026-08-08). First: one line could not carry two
## hands — the label clipped on "SNAP P1 storm_kite, imp_sun..." and the P2 half never appeared.
## Second: two lines at 11px clipped the SAME way ("...storm_kite, imp_summoner, stor"), and the
## width the label kept demanding had made the mid-screen panel bulky. `4-B1/R7` changed the
## MEDIUM rather than the font a third time: the label is GONE and the console carries the reveal.
## What is left here is the toggle alone — so this column is now the narrowest of the four, which
## is what let the box shrink back below its pre-smoke width.
func _build_reveal_control(row: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.name = "RevealColumn"
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)
	var toggle := CheckButton.new()
	toggle.name = "RevealOpponentHand"
	toggle.text = "Reveal opponent hand"
	toggle.button_pressed = false
	toggle.toggled.connect(_on_reveal_toggled)
	column.add_child(toggle)


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


## Story 4-B1 (AC 2/AC 3, `4-B1/R1`/`4-B1/R2`): pressed == read both hands ONCE, right now, and
## show them; unpressed == blank the output. This is a single ON-DEMAND read through the accessor,
## never a per-frame poll (F1) and never a subscription — toggling again re-reads the live
## containers fresh (CONSTRAINT C applies through the accessor, `debug_hand_contents` on the
## runner). Null-guarded exactly like SAVE/RELOAD: a panel built outside the runner is inert.
##
## Debug-only, DEFAULT-OFF (`4-B1/R2`, reaffirmed by the 4-B1 code review's D2 ruling): the only
## path into this method is a manual mouse click on this CheckButton — no Input Map action, no
## FeatureFlags read, no state-layer write, and the GDD privacy lock is untouched for every OTHER
## surface (HudRoot never learns of this method). Deliberately NOT gated behind a debug-build check:
## no export build exists for this same-screen local prototype, so such a gate could not be tested
## and a vacuous guard is worse than none here (the build gate is a named deferral in
## deferred-work.md, owned by the first story that produces a distributable build).
##
## IT IS A SNAPSHOT, AND IT SAYS SO: the read happens once, at the press, and the SNAP prefix says
## which moment it describes. `4-B1/R7` retired the round_started clear that used to sit beside
## this: it existed only because an on-screen label could rot into a silent lie across a reset, and
## console lines are a LOG — they are timestamped by their position in it and cannot go stale.
##
## THE CONSOLE IS THE OUTPUT (`4-B1/R7`). ON PRESS ONLY — this is inside the toggle handler, never
## a per-frame print, which would drown the log the operator is actually reading.
func _on_reveal_toggled(pressed: bool) -> void:
	if not pressed:
		_last_reveal_lines = []
		return
	if not reveal_opponent_hand.is_valid():
		return
	var hands: Array = reveal_opponent_hand.call()
	var p1_hand: Array = hands[0] if hands.size() > 0 else []
	var p2_hand: Array = hands[1] if hands.size() > 1 else []
	var line_1 := "SNAP P1: %s" % _render_hand(p1_hand)
	var line_2 := "P2: %s" % _render_hand(p2_hand)
	_last_reveal_lines = PackedStringArray([line_1, line_2])
	print(line_1)
	print(line_2)


## Story 4-B1 (code review): `Hand.to_array()` is the WIDTH view — `Hand.EMPTY` sits at every hole
## — and `str(&"")` is the empty string, so joining raw ids renders a holed hand as `a, , c, d`
## and a fully holed one as `, , , `: the one surface whose whole purpose is showing hand CONTENTS
## could not show which slot was empty. HOLE_MARKER makes the hole legible, which is the same
## complaint AC 1 fixes on the HUD side, fixed here too rather than reproduced.
const HOLE_MARKER := "-"


func _render_hand(ids: Array) -> String:
	var out := PackedStringArray()
	for id in ids:
		out.append(HOLE_MARKER if StringName(id) == Hand.EMPTY else str(id))
	return ", ".join(out)


## The reveal's read-back for the assertion — the two lines the LAST press produced, empty while
## the toggle is off. Not an output surface: nothing renders it, and the test uses it only so it
## can drive the real CheckButton rather than re-deriving what the press should have said.
func last_reveal_lines() -> PackedStringArray:
	return _last_reveal_lines
