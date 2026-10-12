class_name BuffMarkers
extends Node3D

## Story 7-5a (AC 50/AC 51, `7-5a/R25`): THE PLACEHOLDER BUFF MARKERS -- one line of text floating over a
## hero that names every Deck 2 / Lifechain buff the hero currently holds, with a COUNT for the ones that
## stack: `SET 2  EXE 1  STN 1  ENR 2  LIFE`. A child of the hero actor in the one shared `World3D`, so both
## split-screen viewports see it by construction (the `OrbHalo` / `ImmunityShimmer` precedent).
##
## MINIMAL ON PURPOSE. This is the readable placeholder the story asks for, not the buff's art: each buff is
## a distinct token, a stacked buff reads as its count, and a token disappears when its state ends. Real
## per-buff visuals are a later presentation story.
##
## PRESENTATION ONLY: built in code, no collision shape, no `Area3D`, no signal into state, no
## `_physics_process` (F1). LEVEL-TRIGGERED: the runner pushes the five plain values every tick from its
## post-`advance()` poll (`show_counts`), so a marker ends on whatever path ends its state -- a spend, a
## Counterspell, round end, the reset -- with no falling edge of its own to remember. It holds no state
## handle; the text is rebuilt only when a pushed value actually changed.

## The tokens, in display order. Each is distinct from the others (AC 50).
const TOKEN_SETUP := "SET"
const TOKEN_EXECUTE := "EXE"
const TOKEN_STONESKIN := "STN"
const TOKEN_ENRAGE := "ENR"
const TOKEN_LIFECHAIN := "LIFE"

## KNOBS (feel values, tuned at smoke): where the line floats over the hero root, and how it is drawn.
const MARKER_HEIGHT := 1.45
const MARKER_PIXEL_SIZE := 0.006
const MARKER_FONT_SIZE := 48
const MARKER_COLOR := Color(1.0, 0.95, 0.7)

var _label: Label3D
var _shown: Array = [0, 0, 0, 0, false]


func _ready() -> void:
	_label = Label3D.new()
	_label.name = "Line"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = MARKER_PIXEL_SIZE
	_label.font_size = MARKER_FONT_SIZE
	_label.outline_size = 12
	_label.modulate = MARKER_COLOR
	_label.position = Vector3(0.0, MARKER_HEIGHT, 0.0)
	add_child(_label)
	_render()


## THE TEXT FOR ONE SET OF VALUES -- a static, pure builder, so the wording is checkable without a scene.
## The four stacking buffs read `TOKEN n` (their charge or window COUNT) and are absent at zero; Lifechain
## reads its bare token while the hero is covered. Empty when the hero holds none.
static func text_for(setup: int, execute: int, stoneskin: int, enrage: int, lifechain: bool) -> String:
	var parts: PackedStringArray = []
	if setup > 0:
		parts.append("%s %d" % [TOKEN_SETUP, setup])
	if execute > 0:
		parts.append("%s %d" % [TOKEN_EXECUTE, execute])
	if stoneskin > 0:
		parts.append("%s %d" % [TOKEN_STONESKIN, stoneskin])
	if enrage > 0:
		parts.append("%s %d" % [TOKEN_ENRAGE, enrage])
	if lifechain:
		parts.append(TOKEN_LIFECHAIN)
	return "  ".join(parts)


## The runner's per-tick push: Setup charges, Execute charges, Stoneskin charges, running Enrage windows,
## and whether Lifechain covers the hero. Plain values, never a state handle.
func show_counts(setup: int, execute: int, stoneskin: int, enrage: int, lifechain: bool) -> void:
	if _shown[0] == setup and _shown[1] == execute and _shown[2] == stoneskin \
			and _shown[3] == enrage and _shown[4] == lifechain:
		return
	_shown = [setup, execute, stoneskin, enrage, lifechain]
	_render()


## Nothing held -- the reset's clear, `ImmunityShimmer.set_fraction(0.0)`'s twin.
func clear() -> void:
	show_counts(0, 0, 0, 0, false)


## The line currently shown -- what a test reads.
func text() -> String:
	return _label.text if _label != null else ""


func _render() -> void:
	if _label == null:
		return
	_label.text = text_for(_shown[0], _shown[1], _shown[2], _shown[3], _shown[4])
	visible = _label.text != ""
