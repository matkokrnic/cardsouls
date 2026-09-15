class_name StateInspector
extends Control

## Story 2-6 (AC 2, 2-6/R7): per-player DEBUG state inspector. ONE instance per SubViewport,
## mirroring HudRoot's per-player construction and runner wiring, built in code under
## src/ui/debug/ with NO companion .tscn. READ-ONLY (D5): it consumes queued state signals
## through the EXISTING observation seams only — it never mutates state, never polls (no
## _process / _physics_process, F1), and never holds a MatchState handle (the banned-token scan
## over src/ui/ enforces this).
##
## It reads FIVE of the seven locked observation seams (the 2-4/R1 seam family), all per-slot and
## bound by the runner to THIS inspector's own slot:
##   - action-state name        connect_hero_action_state_changed
##   - HP current/maximum        connect_hero_hp_changed        (primes on connect)
##   - stamina current/maximum   connect_stamina_changed        (primes on connect)
##   - mana current/maximum      connect_mana_changed           (primes on connect)
##   - most recent rejection     connect_hero_action_rejected
## It adds NO eighth seam. It deliberately shows NO active-TimingWindow countdown: that capability
## was DEFERRED to the rig story (2-6/R7 — streaming raw window ticks every tick would be a firehose
## through the D5 queued-drain path and would hand the state layer's internals to presentation).
## Story 3-0b (AC 2) landed it in DebugInstrumentPanel instead, and NOT as a seam: the runner polls
## a read-only MatchState accessor after advance() and pushes plain integers into the panel, so
## neither R7 objection applies — nothing rides the queued-drain path and no internals cross.
##
## The action-state channel does NOT prime on connect, so STATE reads "--" until the first
## transition; the three economy rows render immediately from their prime-on-connect calls.

var _state_value: Label
var _hp_value: Label
var _stamina_value: Label
var _mana_value: Label
var _reject_value: Label


func _init() -> void:
	name = "StateInspector"


func _ready() -> void:
	# Left edge, below the HUD's top-left deck indicator — a compact debug readout clear of the
	# lower-centre vitals, the two pitch zones flanking them (story 6-3b) and the centre telegraph band. Never eats gameplay input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.offset_left = 10.0
	panel.offset_top = 60.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var column := VBoxContainer.new()
	column.name = "Readout"
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var title := Label.new()
	title.text = "-- STATE --"
	column.add_child(title)
	_state_value = _make_row(column, "STATE")
	_hp_value = _make_row(column, "HP")
	_stamina_value = _make_row(column, "STAM")
	_mana_value = _make_row(column, "MANA")
	_reject_value = _make_row(column, "REJECT")


## A caption | value row; returns the value Label the seam callbacks write into.
func _make_row(column: VBoxContainer, caption: String) -> Label:
	var row := HBoxContainer.new()
	row.name = "%sRow" % caption
	row.add_theme_constant_override("separation", 6)
	var name_label := Label.new()
	name_label.text = caption
	name_label.custom_minimum_size = Vector2(64.0, 0.0)
	row.add_child(name_label)
	var value := Label.new()
	value.name = "%sValue" % caption
	value.text = "--"
	row.add_child(value)
	column.add_child(row)
	return value


# --- Signal-driven consumers (read-only) --------------------------------------------------

## Seam callback (connect_hero_action_state_changed). Names the entered state via the enum's
## own key table (HeroState.ActionState is a name->value Dictionary), so a new state needs no
## edit here. Does NOT prime on connect — STATE reads "--" until the first transition.
func on_action_state_changed(_previous: HeroState.ActionState, current: HeroState.ActionState) -> void:
	_state_value.text = str(HeroState.ActionState.find_key(current))


## Seam callback (connect_hero_hp_changed, primed on connect).
func on_hp_changed(current: float, maximum: float) -> void:
	_hp_value.text = "%d/%d" % [int(roundf(current)), int(roundf(maximum))]


## Seam callback (connect_stamina_changed, primed on connect).
func on_stamina_changed(current: float, maximum: float) -> void:
	_stamina_value.text = "%d/%d" % [int(roundf(current)), int(roundf(maximum))]


## Seam callback (connect_mana_changed, primed on connect).
func on_mana_changed(current: float, maximum: float) -> void:
	_mana_value.text = "%d/%d" % [int(roundf(current)), int(roundf(maximum))]


## Seam callback (connect_hero_action_rejected): the player's most recent refused action and
## the reason (e.g. roll: insufficient_stamina). Overwritten each rejection — latest only.
func on_action_rejected(action: StringName, reason: StringName) -> void:
	_reject_value.text = "%s: %s" % [action, reason]
