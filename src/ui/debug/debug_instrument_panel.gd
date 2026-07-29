class_name DebugInstrumentPanel
extends Control

## Story 2-6 (AC 4 + AC 5, 2-6/R4/R8/R9): the GLOBAL debug instrument panel — ONE instance for
## the whole window (unlike the per-viewport HudRoot / StateInspector), built in code under
## src/ui/debug/ with NO .tscn. It is the narrowed heir of old AC1's FeatureFlags overlay: it
## flips ONLY presentation-local and controller-local switches, NEVER a FeatureFlags member
## (2-6/R4 — flags stay load-once and runtime-immutable so replay has no silent hole). No
## _process / _physics_process (F1); it is driven entirely by the two switches' toggled signals.
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

## Set by the runner BEFORE add_child (so _ready sees them). The shared gamepad profile instance
## (the runner loads it via the same res:// path, so the resource cache hands both the same object)
## and both per-viewport HudRoots (whose pitch placeholder the A/B switch repositions).
var gamepad_profile: GamepadProfile
var huds: Array[HudRoot] = []


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
	# — is EMPTY across the full window width in both viewports (nothing else spans it). Centre the
	# 300x89 box there: x[426,726], y[359,448]. Collides with no HudRoot child and neither
	# StateInspector, and lies fully inside the window. Machine-checked by test_debug_instruments.gd.
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -150.0
	box.offset_right = 150.0
	box.offset_top = 35.0
	box.offset_bottom = 124.0
	add_child(box)
	var column := VBoxContainer.new()
	column.name = "Instruments"
	column.add_theme_constant_override("separation", 2)
	box.add_child(column)
	var title := Label.new()
	title.text = "-- DEBUG INSTRUMENTS --"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	# Switch 1: analog magnitude. Pressed == normalize (the authored default true), so the button
	# starts pressed and toggling OFF selects variable magnitude.
	var magnitude := CheckButton.new()
	magnitude.name = "NormalizeMagnitude"
	magnitude.text = "Normalize analog magnitude"
	magnitude.button_pressed = gamepad_profile == null or gamepad_profile.normalize_move_magnitude
	magnitude.toggled.connect(_on_normalize_toggled)
	column.add_child(magnitude)

	# Switch 2: Pitch Zone A/B. Pressed == the left-of-bars candidate (B); unpressed == dead-centre
	# (A, the shipped placement). Starts unpressed so both viewports begin at the current anchor.
	var pitch := CheckButton.new()
	pitch.name = "PitchZoneLeftOfBars"
	pitch.text = "Pitch Zone: left of bars"
	pitch.button_pressed = false
	pitch.toggled.connect(_on_pitch_placement_toggled)
	column.add_child(pitch)


## AC 4: flip the AUTHORED field on the shared in-memory GamepadProfile instance. IN MEMORY ONLY —
## no ResourceSaver, no .tres write (2-6/R8). `pressed` true == normalize (unit length), false ==
## variable magnitude. Null-guarded: in a config with no gamepad the field simply has no reader.
func _on_normalize_toggled(pressed: bool) -> void:
	if gamepad_profile != null:
		gamepad_profile.normalize_move_magnitude = pressed


## AC 5: move BOTH viewports' pitch placeholder together (shared switch, A/B comparability). The
## left-of-bars anchor is computed by HudRoot from its own vitals-column geometry, independent of
## OpponentHandStrip (2-6/R9 — that provisional 2-5 row must not be anchored to).
func _on_pitch_placement_toggled(left_of_bars: bool) -> void:
	for hud in huds:
		hud.set_pitch_zone_placement(left_of_bars)
