class_name HudRoot
extends Control

## Story 2-4: the per-player HUD root. ONE instance per SubViewport, constructed in code
## (the retired 1-3c debug overlay's code-construction pattern, reparented to a per-viewport
## SubViewport rather than a single global overlay). No companion .tscn (2-4/R6).
##
## Signal-driven per D5: it SUBSCRIBES through the runner's per-slot economy seams
## (connect_hero_hp_changed / connect_stamina_changed / connect_mana_changed) plus
## EventBus.round_ended, and it NEVER polls, NEVER writes, NEVER holds a MatchState handle.
## It has no _physics_process (INVARIANT F1) and no _process (event-driven — 2-4/R9 keeps
## that discipline review-checked, not machine-enforced). The runner binds each root to ONLY
## its own slot's callbacks (2-4/R7), so this root is handed only its player's payloads and
## is structurally incapable of reaching the opponent's — no slot argument, no state handle.
##
## The four combat seams (hit_landed, deflect_landed, action_state_changed, action_rejected)
## are NOT consumed here — they stay owned by TelegraphController (2-4/R4). The HUD reads
## exactly three economy channels plus the ownerless round-over event.
##
## P4 / Reactor-Actor layout (2-4/R6, GDD #P4 / Reactor-Actor principle). The split viewport
## is HALF width, so every element gets its true half-width footprint NOW — this is the layer
## where CardSouls discovers whether the full HUD fits the space at all, before E3-E6 give the
## reserved regions content. Placement rule: elements consulted UNDER REACTION PRESSURE sit in
## the focal band (screen centre and the glanceable lower-centre); elements consulted at the
## player's OWN TEMPO, between exchanges, sit at the periphery (corners).
##   - Focal (reaction-critical): the STAMINA bar gates the reactive roll/block, so it rides
##     the lower-centre band; the PITCH ZONE timer placeholder sits dead-centre where the
##     "incoming" read lands. HP rides with stamina — it is the other value a player checks
##     the instant a hit connects.
##   - Periphery (own-tempo): the three ORB totals and the DECK / reshuffle count are read
##     between exchanges, never mid-reaction, so they sit in the top corners.
##   - The 4-card HAND strip is the player's own-tempo action surface; it takes the
##     bottom-centre where it is visible without competing with the reactive focal centre.
## (The centre "incoming telegraph" cue named in P4 is a WORLD-SPACE cue, not a HUD element —
## 2-4/R12 — so it is not built here; only the pitch timer placeholder occupies the centre.)
##
## Every E3-E6 region below (hand strip, orb counters, pitch zone + timer, deck/reshuffle) is
## a RESERVED empty placeholder occupying its real footprint and consuming NO signal (AC 5).

# The pixel offsets below are tuned against the nominal half-width footprint ~576x648 (the
# default 1152x648 window split in two). Anchors keep every element attached to its viewport
# edge/centre, so the layout degrades gracefully if the real half-width differs — the numbers
# are reference dimensions, not a hard requirement.
var _hp_bar: ProgressBar
var _hp_value: Label
var _stamina_bar: ProgressBar
var _stamina_value: Label
var _mana_bar: ProgressBar
var _mana_value: Label
var _pitch_timer: Label
var _round_label: Label


func _init() -> void:
	name = "HudRoot"


func _ready() -> void:
	# Fill the SubViewport: the HUD's real footprint IS the half-width viewport.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # the HUD never eats gameplay input
	_build_vitals()
	_build_pitch_zone()
	# Story 2-5: both hand rows go through the ONE construction function below. `true` = the
	# owning player's face-up hand (the reserved 2-4 bottom-centre strip); `false` = the
	# opponent's face-down hand (new top-centre row). The parameter is the single seat of the
	# face-up / face-down decision (2-5/R4).
	_build_hand_row(true)
	_build_hand_row(false)
	_build_orb_counters()
	_build_deck_indicator()
	_build_round_label()


# --- Signal-driven consumers (AC 4) -------------------------------------------------------
# Each is a runner-wired seam callback for THIS root's own slot only. Payload is
# (current, maximum); no per-frame recompute, no polling.

## Seam callback (connect_hero_hp_changed, primed on connect).
func on_hp_changed(current: float, maximum: float) -> void:
	_apply_bar(_hp_bar, _hp_value, current, maximum)


## Seam callback (connect_stamina_changed, primed on connect).
func on_stamina_changed(current: float, maximum: float) -> void:
	_apply_bar(_stamina_bar, _stamina_value, current, maximum)


## Seam callback (connect_mana_changed, primed on connect). LIVE from E1 (2-4/R13): moves on
## every confirmed melee hit, blocked hits included.
func on_mana_changed(current: float, maximum: float) -> void:
	_apply_bar(_mana_bar, _mana_value, current, maximum)


## EventBus.round_ended (slot bound at wiring, mirroring TelegraphController). Minimal
## per-viewport round-over label. 2-4/R5: the 2-3/R10 named gap is visible here — the label
## reads while the surviving hero keeps moving; that is PRE-KNOWN, not owned by this story.
func on_round_ended(loser_index: int, my_slot: int) -> void:
	_round_label.text = "YOU WIN" if loser_index != my_slot else "YOU LOSE"
	_round_label.visible = true


func _apply_bar(bar: ProgressBar, value_label: Label, current: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = current
	value_label.text = "%d/%d" % [int(roundf(current)), int(roundf(maximum))]


# --- Construction -------------------------------------------------------------------------

## HP / stamina / mana bars, stacked in the lower-centre focal band (above the hand strip).
func _build_vitals() -> void:
	var column := VBoxContainer.new()
	column.name = "Vitals"
	column.anchor_left = 0.5
	column.anchor_right = 0.5
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = -180.0
	column.offset_right = 180.0
	column.offset_top = -196.0
	column.offset_bottom = -116.0
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var hp := _make_bar_row("HP", Color(0.85, 0.2, 0.2))
	_hp_bar = hp[0]
	_hp_value = hp[1]
	column.add_child(hp[2])
	var stam := _make_bar_row("STAM", Color(0.2, 0.75, 0.3))
	_stamina_bar = stam[0]
	_stamina_value = stam[1]
	column.add_child(stam[2])
	var mana := _make_bar_row("MANA", Color(0.25, 0.5, 0.9))
	_mana_bar = mana[0]
	_mana_value = mana[1]
	column.add_child(mana[2])


## Returns [bar, value_label, row_control]. The row is name | bar | value, sized for a
## legible half-width read. The bar is constructed EMPTY and WITHOUT a real maximum
## (value 0, max 1): the real (current, maximum) arrives ONLY through the seam's prime-on-
## connect call (2-4/R2), so nothing in this presentation layer duplicates an authored
## balance value (D2), and an empty bar until priming is a visible bug rather than a bar that
## looks correct by construction.
func _make_bar_row(caption: String, fill: Color) -> Array:
	var row := HBoxContainer.new()
	row.name = "%sRow" % caption
	row.custom_minimum_size = Vector2(0.0, 22.0)
	row.add_theme_constant_override("separation", 6)
	var name_label := Label.new()
	name_label.text = caption
	name_label.custom_minimum_size = Vector2(48.0, 0.0)
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.name = "%sBar" % caption
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = 0.0
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0.0, 22.0)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	bar.add_theme_stylebox_override("fill", fill_style)
	row.add_child(bar)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(72.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	return [bar, value_label, row]


## Pitch Zone slot + timer placeholder (E6). Dead-centre focal anchor. Reserved footprint
## only — consumes no signal.
func _build_pitch_zone() -> void:
	var panel := _make_placeholder_panel("PitchZone", "PITCH ZONE")
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -70.0
	panel.offset_right = 70.0
	panel.offset_top = -110.0
	panel.offset_bottom = -22.0
	add_child(panel)
	_pitch_timer = Label.new()
	_pitch_timer.name = "PitchTimer"
	_pitch_timer.text = "0.0"
	_pitch_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pitch_timer.anchor_left = 0.0
	_pitch_timer.anchor_right = 1.0
	_pitch_timer.anchor_top = 1.0
	_pitch_timer.anchor_bottom = 1.0
	_pitch_timer.offset_top = 2.0
	_pitch_timer.offset_bottom = 22.0
	panel.add_child(_pitch_timer)


## Story 2-5: the two per-viewport hand rows (E3 card widgets land later). BOTH rows are built
## by this ONE function — `is_own` is the SINGLE SEAT of the face-up / face-down decision
## (2-5/R1, R4): it alone selects front styling (own hand, face-up) versus back styling
## (opponent hand, face-down) through the one call to _make_card_face_style below, and nothing
## else anywhere re-decides styling. The epic-3 reveal toggle is a flip of this parameter, not a
## second rule; `src/ui/debug/` stays empty until then.
##
## The own row (`is_own` true) is the bottom-centre own-tempo action surface reserved by 2-4 —
## same node name, anchors, offsets and four Card0..Card3 panels at 74x84, NEITHER moved nor
## resized — now gaining a front style. The opponent row (`is_own` false) is new: top-centre,
## above the pitch-zone placeholder and between the deck indicator (top-left) and the orb
## counters (top-right), back-styled, with smaller panels because a card back carries nothing to
## read. Its placement and sizing are PROVISIONAL — the A/B tuning across HUD phases is story
## 2-6's, which owns the instrumentation (2-5/R3). Nothing else in the reserved layout moves.
##
## The rendered count is the presentation-local constant 4 (2-5/R1): hand size is 4 at all times
## per the GDD, and it is PUBLIC AND SYMMETRIC (2-5/R2), so rendering the opponent's count is not
## an opponent read — no read of PlayerState.hand, no hand_size field, no write to hand. Epic 3
## makes the count data-driven; that is a named follow-up here, not a passing remark. Both rows
## are built ONCE at setup: no _process, no _physics_process, no signal consumption (2-5/R6).
func _build_hand_row(is_own: bool) -> void:
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 8)
	strip.anchor_left = 0.5
	strip.anchor_right = 0.5
	var card_size: Vector2
	if is_own:
		# Own face-up hand: the 2-4 bottom-centre HandStrip footprint, unchanged.
		strip.name = "HandStrip"
		strip.anchor_top = 1.0
		strip.anchor_bottom = 1.0
		strip.offset_left = -172.0
		strip.offset_right = 172.0
		strip.offset_top = -104.0
		strip.offset_bottom = -20.0
		card_size = Vector2(74.0, 84.0)
	else:
		# Opponent face-down hand: new top-centre row between deck indicator and orb counters,
		# above the pitch-zone placeholder. Smaller panels — a back carries nothing to read.
		strip.name = "OpponentHandStrip"
		strip.anchor_top = 0.0
		strip.anchor_bottom = 0.0
		strip.offset_left = -118.0
		strip.offset_right = 118.0
		strip.offset_top = 10.0
		strip.offset_bottom = 74.0
		card_size = Vector2(52.0, 64.0)
	add_child(strip)
	var card_style := _make_card_face_style(is_own)
	for i in 4:
		var card := Panel.new()
		card.name = "Card%d" % i
		card.custom_minimum_size = card_size
		card.add_theme_stylebox_override("panel", card_style)
		strip.add_child(card)


## The SINGLE SEAT of the face-up / face-down decision (2-5/R1, R4). `is_own` picks a card FACE
## (own hand, face-up: light parchment, thin dark frame) versus a card BACK (opponent hand,
## face-down: deep indigo, heavy gold frame) — genuinely distinguishable at a glance in a
## half-width viewport, not two identical blank panels. One StyleBoxFlat is shared across a
## row's four panels (identical backs / blank faces this story). This one `if is_own` is the
## only place styling branches on ownership; a later reveal toggle flips this parameter.
func _make_card_face_style(is_own: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(4)
	if is_own:
		box.bg_color = Color(0.90, 0.87, 0.78)      # parchment face
		box.border_color = Color(0.24, 0.20, 0.16)  # thin dark frame
		box.set_border_width_all(2)
	else:
		box.bg_color = Color(0.10, 0.13, 0.34)      # deep-indigo back
		box.border_color = Color(0.78, 0.64, 0.24)  # heavy gold frame
		box.set_border_width_all(4)
	return box


## Three orb counters placeholder (E4 / E5). Top-right periphery own-tempo totals. Reserved
## footprint only.
func _build_orb_counters() -> void:
	var orbs := HBoxContainer.new()
	orbs.name = "OrbCounters"
	orbs.add_theme_constant_override("separation", 6)
	orbs.anchor_left = 1.0
	orbs.anchor_right = 1.0
	orbs.anchor_top = 0.0
	orbs.anchor_bottom = 0.0
	orbs.offset_left = -134.0
	orbs.offset_right = -10.0
	orbs.offset_top = 10.0
	orbs.offset_bottom = 46.0
	add_child(orbs)
	for i in 3:
		var orb := Panel.new()
		orb.name = "Orb%d" % i
		orb.custom_minimum_size = Vector2(36.0, 36.0)
		var count := Label.new()
		count.text = "0"
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		orb.add_child(count)
		orbs.add_child(orb)


## Deck / reshuffle indicator placeholder (E3). Top-left periphery own-tempo count. Reserved
## footprint only.
func _build_deck_indicator() -> void:
	var deck := _make_placeholder_panel("DeckIndicator", "DECK -- / RESH")
	deck.anchor_left = 0.0
	deck.anchor_right = 0.0
	deck.anchor_top = 0.0
	deck.anchor_bottom = 0.0
	deck.offset_left = 10.0
	deck.offset_right = 116.0
	deck.offset_top = 10.0
	deck.offset_bottom = 50.0
	add_child(deck)


## Minimal per-viewport round-over label. Hidden until EventBus.round_ended arrives.
func _build_round_label() -> void:
	_round_label = Label.new()
	_round_label.name = "RoundOverLabel"
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_round_label.add_theme_font_size_override("font_size", 40)
	_round_label.anchor_left = 0.0
	_round_label.anchor_right = 1.0
	_round_label.anchor_top = 0.5
	_round_label.anchor_bottom = 0.5
	_round_label.offset_top = -30.0
	_round_label.offset_bottom = 30.0
	_round_label.visible = false
	add_child(_round_label)


## A bordered Panel with a caption Label, for the reserved-region placeholders. The border
## makes the reserved footprint identifiable at half-width (AC 10 legibility).
func _make_placeholder_panel(node_name: String, caption: String) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(caption_label)
	return panel
