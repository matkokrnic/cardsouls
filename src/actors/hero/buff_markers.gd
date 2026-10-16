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

## Story 7-5b (AC 23): THE DECK 2 BODIES' MARKERS, in the same manner on a SECOND line just above the buff
## line. Two CONDITIONS, level-triggered like the buffs (a slow -- Frostbite's, or Elemental Fury's blue shot,
## which applies the same rule -- and the Wrath stun), and two EVENTS that pop once and fade (a Healer's heal
## tick on its owner, an Elemental Fury green landing on its caster).
const TOKEN_SLOW := "SLOW"
const TOKEN_STUN := "STUN"
const TOKEN_HEAL := "+HEAL"
const TOKEN_GREEN := "+GREEN"

## KNOBS (feel values, tuned at smoke): where the line floats over the hero root, and how it is drawn.
const MARKER_HEIGHT := 1.45
const MARKER_PIXEL_SIZE := 0.006
const MARKER_FONT_SIZE := 48
const MARKER_COLOR := Color(1.0, 0.95, 0.7)
## Story 7-5b: the conditions line sits this far above the buff line; an event pops from there, rises this far
## and fades over this long.
const CONDITION_LIFT := 0.35
const POP_RISE := 0.6
const POP_SECONDS := 1.0
const CONDITION_COLOR := Color(0.75, 0.9, 1.0)
const POP_COLOR := Color(0.55, 1.0, 0.55)

var _label: Label3D
var _shown: Array = [0, 0, 0, 0, false]
var _conditions: Label3D
var _shown_conditions: Array = [false, false]
## The event pops still on screen (each frees itself when its fade ends; `clear()` frees the rest).
var _pops: Array[Label3D] = []


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
	_conditions = _make_label("Conditions", CONDITION_COLOR)
	_conditions.position = Vector3(0.0, MARKER_HEIGHT + CONDITION_LIFT, 0.0)
	add_child(_conditions)
	_render()
	_render_conditions()


func _make_label(label_name: String, color: Color) -> Label3D:
	var label := Label3D.new()
	label.name = label_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = MARKER_PIXEL_SIZE
	label.font_size = MARKER_FONT_SIZE
	label.outline_size = 12
	label.modulate = color
	return label


## Story 7-5b: the conditions line's text for one pair of values -- a static, pure builder like `text_for`.
static func conditions_text_for(slowed: bool, wrath_stunned: bool) -> String:
	var parts: PackedStringArray = []
	if slowed:
		parts.append(TOKEN_SLOW)
	if wrath_stunned:
		parts.append(TOKEN_STUN)
	return "  ".join(parts)


## Story 7-5b: the runner's per-tick push of the two conditions. Plain values, level-triggered.
func show_conditions(slowed: bool, wrath_stunned: bool) -> void:
	if _shown_conditions[0] == slowed and _shown_conditions[1] == wrath_stunned:
		return
	_shown_conditions = [slowed, wrath_stunned]
	_render_conditions()


## Story 7-5b: one EVENT pop (`TOKEN_HEAL`, `TOKEN_GREEN`): a label that rises from the conditions line and
## fades out, then frees itself. Its tween is bound to the label, so freeing the label stops it.
func pop(token: String) -> void:
	var label := _make_label("Pop", POP_COLOR)
	label.text = token
	label.position = Vector3(0.0, MARKER_HEIGHT + 2.0 * CONDITION_LIFT, 0.0)
	add_child(label)
	_pops.append(label)
	_refresh_visibility()
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + POP_RISE, POP_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, POP_SECONDS)
	tween.chain().tween_callback(_end_pop.bind(label))


func _end_pop(label: Label3D) -> void:
	_pops.erase(label)
	if is_instance_valid(label):
		label.queue_free()
	_refresh_visibility()


## The pops currently on screen, oldest first -- what a test reads.
func pop_texts() -> PackedStringArray:
	var out: PackedStringArray = []
	for label: Label3D in _pops:
		if is_instance_valid(label):
			out.append(label.text)
	return out


## The conditions line currently shown -- what a test reads.
func conditions_text() -> String:
	return _conditions.text if _conditions != null else ""


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
	show_conditions(false, false)
	for label: Label3D in _pops:
		if is_instance_valid(label):
			label.queue_free()
	_pops.clear()
	_refresh_visibility()


## The line currently shown -- what a test reads.
func text() -> String:
	return _label.text if _label != null else ""


func _render() -> void:
	if _label == null:
		return
	_label.text = text_for(_shown[0], _shown[1], _shown[2], _shown[3], _shown[4])
	_label.visible = _label.text != ""
	_refresh_visibility()


func _render_conditions() -> void:
	if _conditions == null:
		return
	_conditions.text = conditions_text_for(_shown_conditions[0], _shown_conditions[1])
	_conditions.visible = _conditions.text != ""
	_refresh_visibility()


## The whole marker node is hidden when it shows nothing at all (7-5a's contract for the buff line, kept).
func _refresh_visibility() -> void:
	visible = (_label != null and _label.text != "") or (_conditions != null and _conditions.text != "") \
			or not _pops.is_empty()
