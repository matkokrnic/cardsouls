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
## Story 3-6 adds the FOURTH channel — connect_cards_changed, the runner's eighth seam (AC 2) —
## and a second ownerless bus event, EventBus.reshuffle_vulnerable_window_opened (AC 4). The card
## channel is per-slot and PRIVATE like the three economy ones; the reshuffle event is public and
## is the only card fact this root learns about the opponent (`3-6/R7`).
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
## Story 3-6: the hand strip and the deck/reshuffle indicator are NO LONGER PLACEHOLDERS — they
## are the first two reserved regions to gain real content, and this story owns their final
## sizing (AC 6). The orb counters and the pitch zone stay reserved (E4/E5, E6). Card ART and a
## display-name field are out of scope for every scheduled story, so a card renders as its
## `CardData.id` text (`3-6/R4`).

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
var _pitch_panel: Panel
var _pitch_timer: Label
var _round_label: Label
## Story 3-6 (AC 4): the deck-count read-out and the reshuffle flag beside it. The count comes
## from the eighth seam's payload; the flag comes from the ownerless bus event alone.
var _deck_label: Label
var _reshuffle_label: Label

## Story 3-6 (AC 4): the authored vulnerable-window duration in SECONDS, handed over by the runner
## at construction (the `gamepad_profile` / `huds` static-handoff precedent), before add_child.
## PRESENTATION-LOCAL AND FOR THE FLAG ONLY: it seeds the one-shot timer that turns the flag back
## off, so the HUD never reads PlayerState.vulnerable_window — which stays WRITE-ONLY unhashed
## state that nothing consults (3-5b/R20), the property keeping the window's mechanical cost a
## genuinely OPEN decision. If that window ever gains a cost, this number stops being the whole
## story and the render is revisited THEN, deliberately (`3-6/R3`).
var reshuffle_vulnerable_window_seconds := 0.0

## Story 3-6 (AC 4): which reshuffle announcement the visible flag belongs to. Each event
## increments it and its own one-shot timer captures the value; a timer whose token is stale does
## nothing. Without this, a SECOND reshuffle landing while the flag is up would be switched off
## early by the FIRST one's timer — the flag would lie about a window that is still open.
var _reshuffle_token := 0

## Story 3-5a (AC 10): the OWN hand row's four panels, kept so the selection indicator can
## restyle exactly one of them. Own row only — the opponent row is never indicated (a selection
## is the owning player's, and 2-4/R7's no-opponent-read discipline is not weakened by a
## highlight either).
var _own_card_panels: Array[Panel] = []
## The two styles the indicator swaps between. `_card_base_style` is the SHARED StyleBoxFlat the
## row already used for all four panels (2-5/R4's single seat, unchanged); `_card_armed_style` is
## the one new affordance this story ships. Held as references so the swap is an override write
## and never a rebuild — no resize, no re-layout, no node churn.
var _card_base_style: StyleBoxFlat
var _card_armed_style: StyleBoxFlat

## Story 3-6 (AC 1/AC 6): the four card CAPTIONS, one per own-row panel, index-aligned with
## _own_card_panels. A card renders as its id text and nothing else — there is no art and no
## display-name field on CardData, and neither is owned by any scheduled story (`3-6/R4`). A slot
## with no card in it renders EMPTY rather than being hidden, so the row keeps its four-slot shape
## while a replacement draw is in flight.
var _own_card_labels: Array[Label] = []

## Story 4-6a (AC 13/AC 14): the locked-target dot. One per root, therefore one per SubViewport,
## therefore per-slot by construction -- see _build_lock_marker.
var _lock_marker: Panel

## Story 4-B1 (AC 1): the in-flight placeholder — visually distinct from both a real card id
## (always a snake_case CardData.id, never punctuation-only) and from the permanent-hole blank
## (""). Cheapest legible treatment at half-width: a caption swap on the existing
## `_own_card_labels` machinery, no new StyleBox and no border/style change.
const IN_FLIGHT_CAPTION := "..."

## Story 4-6a (AC 13): the locked-target marker's pixel footprint. Square, because the dot is drawn
## as a fully-rounded Panel. Small on purpose -- it marks an enemy at half-width without occluding
## the enemy it marks; its final legibility is an OPERATOR SMOKE surface (`PROC/R8`), not a number
## this pass may declare correct.
const LOCK_MARKER_SIZE := Vector2(14.0, 14.0)


func _init() -> void:
	name = "HudRoot"


func _ready() -> void:
	# Fill the SubViewport: the HUD's real footprint IS the half-width viewport.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # the HUD never eats gameplay input
	_build_vitals()
	_build_pitch_zone()
	# Story 3-6 (AC 1): ONE hand row — the owning player's, face-up. The opponent's face-down
	# row 2-5 built here is DELETED, not hidden and not repointed (E3-RG/R4): it rendered a
	# four-card COUNT whose publicity was never decided, and the GDD makes the pitched card the
	# only public card information. Deleting it is also why the reveal toggle E3-RG/R5 assumed
	# would be a flip of `_make_card_face_style`'s parameter is DEFERRED rather than built here
	# — with no opponent row left, a toggle would be a whole new debug-only rendering path
	# (`3-6/R1`). The face-down branch of that function survives untouched for it.
	_build_hand_row()
	_build_orb_counters()
	_build_deck_indicator()
	_build_round_label()
	_build_lock_marker()


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


## Seam callback (connect_cards_changed, the runner's EIGHTH seam — story 3-6, AC 2). Primed on
## connect with an empty hand: the deal lands at step 6 of the first advance(), one tick later.
##
## `hand_ids` is a COPY of this player's hand, in hand order; the two counts are this player's
## OWN deck and discard (`3-6/R7` — card counts are private, only the reshuffle flag is public).
## The parameter is typed as a plain `Array` because Callable binding does not narrow the
## `Array[StringName]` on the wire; the elements are StringName ids either way.
##
## EVERY slot is written on every call, not just the occupied ones, so a hand that shrank (a cast
## with its replacement still in flight) clears the vacated caption instead of leaving a ghost
## card the player might try to cast. Discard count is accepted and deliberately NOT rendered:
## no AC asks for it and the deck read-out is the own-tempo periphery element P4 places here —
## it rides the payload so the channel does not need widening the first time a story wants it.
##
## Story 4-B1 (AC 1): `pending_draw_owed` — this player's OWN owed-slot indices, read fresh at the
## runner's wiring seat (match_runner.gd) off `PlayerState.pending_draw_owed` and handed in here
## alongside the seam's own three values, never through a new signal or a cached reference
## (CONSTRAINT C). A blank slot whose index appears here has a delivery in flight and renders the
## IN_FLIGHT_CAPTION; a blank slot that does NOT appear here is 4-0 AC 8's permanent hole and stays
## truly blank — the deferred-work.md finding this discharges. Defaulted to an empty Array so the
## two pre-existing test call sites (3-arg) keep exercising the permanent-hole branch unchanged.
func on_cards_changed(
		hand_ids: Array, deck_count: int, _discard_count: int, pending_draw_owed: Array = []) -> void:
	for i in _own_card_labels.size():
		if i < hand_ids.size() and hand_ids[i] != Hand.EMPTY:
			_own_card_labels[i].text = str(hand_ids[i])
		elif pending_draw_owed.has(i):
			_own_card_labels[i].text = IN_FLIGHT_CAPTION
		else:
			_own_card_labels[i].text = ""
	_deck_label.text = "DECK %d" % deck_count


## EventBus.reshuffle_vulnerable_window_opened (slot bound at wiring, the on_round_ended shape —
## story 3-6, AC 4). BOTH viewports receive EVERY reshuffle: the event is ownerless and the fact
## is public (E3-RG/R3), so each root renders it against its own slot — "RESHUFFLE" when the
## window is this player's, "OPP RESH" when it is the other's. That is the whole of what crosses
## the privacy line: the FLAG only, never the opponent's counts (`3-6/R7`).
##
## The flag turns itself off through a ONE-SHOT SceneTreeTimer seeded by the authored duration —
## no _process, no per-frame countdown, no read of the state-side window (AC 5, machine-checked by
## test_architecture_invariants.gd::test_ui_layer_never_polls_per_frame). The token guards the
## overlapping case: a second reshuffle inside the first one's window must not be switched off by
## the first one's timer. A non-positive authored duration would leave a flag that never clears,
## so it is refused here rather than rendered — the authoring audit already keeps the value above
## zero, and this is the presentation-side floor under that.
func on_reshuffle_vulnerable_window_opened(slot: int, my_slot: int) -> void:
	if reshuffle_vulnerable_window_seconds <= 0.0:
		return
	_reshuffle_token += 1
	var token := _reshuffle_token
	_reshuffle_label.text = "RESHUFFLE" if slot == my_slot else "OPP RESH"
	_reshuffle_label.visible = true
	# Review finding (3-6): the SceneTreeTimer outlives this HudRoot across a scene teardown
	# mid-window — this root can be freed before the timer fires. is_instance_valid guards the
	# freed case; calling a method on a freed Object would otherwise error.
	var on_timeout := func() -> void:
		if is_instance_valid(self):
			_clear_reshuffle_flag(token)
	get_tree().create_timer(reshuffle_vulnerable_window_seconds).timeout.connect(on_timeout)


## Hides the flag IF the expiring timer is the one that raised the flag currently showing. A
## stale token means a newer reshuffle owns the flag and this timer has nothing to say.
func _clear_reshuffle_flag(token: int) -> void:
	if token == _reshuffle_token:
		_reshuffle_label.visible = false


## EventBus.round_ended (slot bound at wiring, mirroring TelegraphController). Minimal
## per-viewport round-over label. 2-4/R5: the 2-3/R10 named gap is visible here — the label
## reads while the surviving hero keeps moving; that is PRE-KNOWN, not owned by this story.
func on_round_ended(loser_index: int, my_slot: int) -> void:
	_round_label.text = "YOU WIN" if loser_index != my_slot else "YOU LOSE"
	_round_label.visible = true


## EventBus.round_started (story 2-6, AC 1, 2-6/R5): the single CLEAR seat for the round-over
## label — a debug reset hides it, closing the 2-4 close-out MICRO-DECISION 1 gap (the label
## previously survived a reset because nothing signalled it). on_round_ended above stays the
## single SET seat. No-argument and slot-independent: the reset is ownerless, so both viewports
## clear on the one event. No prime-on-connect — the label is built hidden, so this only ever
## HIDES in response to a real reset event.
func on_round_started() -> void:
	_round_label.visible = false


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
	_pitch_panel = panel
	add_child(panel)
	set_pitch_zone_placement(false)  # start at anchor A (dead-centre, the shipped placement)
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


## Story 2-6 (AC 5, 2-6/R9): move THIS viewport's Pitch Zone placeholder between the two A/B
## candidate anchors. `false` = anchor A, the shipped dead-centre focal position; `true` = anchor
## B, just LEFT of the lower-centre vitals bars. The B anchor is derived from the vitals column's
## own geometry (that column spans centre ± 180, see _build_vitals) — NOT from OpponentHandStrip
## (2-5's provisional face-down row, which may be deleted in E3 and must never be anchored to).
## The instrument panel drives BOTH viewports through this one method (shared switch). The
## _pitch_timer child rides along automatically (its anchors are relative to this panel).
func set_pitch_zone_placement(left_of_bars: bool) -> void:
	_pitch_panel.anchor_left = 0.5
	_pitch_panel.anchor_right = 0.5
	if left_of_bars:
		# Anchor B: a 100x88 panel in the gutter just LEFT of the vitals column. The column's left
		# edge is at centre-180 (see _build_vitals); the panel's right edge sits 6px left of it
		# (centre-186) and it is 100 wide, fitting the ~108px gutter to the viewport's left edge at
		# the nominal half-width. Derived from the vitals geometry — NOT from OpponentHandStrip.
		_pitch_panel.anchor_top = 1.0
		_pitch_panel.anchor_bottom = 1.0
		_pitch_panel.offset_left = -286.0
		_pitch_panel.offset_right = -186.0
		_pitch_panel.offset_top = -196.0
		_pitch_panel.offset_bottom = -108.0
	else:
		# Anchor A: the shipped dead-centre focal placement.
		_pitch_panel.anchor_top = 0.5
		_pitch_panel.anchor_bottom = 0.5
		_pitch_panel.offset_left = -70.0
		_pitch_panel.offset_right = 70.0
		_pitch_panel.offset_top = -110.0
		_pitch_panel.offset_bottom = -22.0


## The OWN hand row — the bottom-centre own-tempo action surface reserved by 2-4, face-up since
## 2-5, and given real content here (story 3-6, AC 1/AC 6). The opponent row 2-5 also built from
## this function is DELETED (E3-RG/R4); the function therefore takes no parameter any more, and
## `_make_card_face_style(true)` — the 2-5/R4 privacy seat — is still the ONE place the face-up /
## face-down decision is made, called with the only ownership this HUD renders.
##
## THIS STORY OWNS FINAL SIZING (AC 6), which is why the 2-4 reservation moves here and nowhere
## else. The row grows from 74x84 panels in a 344-wide container to 84x92 in a 368-wide one:
## 4 * 84 + 3 * 8 separation = 360 of content, inside 368. It grows UPWARD (top -112 instead of
## -104) into the 4px gap above, never downward past the -20 bottom margin and never into the
## vitals column, whose own bottom edge sits at -116. The extra width buys the card CAPTION room:
## an id like `bramble_snare` has to be readable at half width, and it is the only thing a card
## renders (`3-6/R4`).
##
## The rendered count stays the presentation-local constant 4 (2-5/R1) — hand size is 4 at all
## times per the GDD. What changed is that the four slots now carry CONTENT, pushed through the
## eighth seam; the row itself is still built ONCE at setup and consumes no per-frame work
## (2-5/R6, AC 5).
func _build_hand_row() -> void:
	var strip := HBoxContainer.new()
	strip.name = "HandStrip"
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 8)
	strip.anchor_left = 0.5
	strip.anchor_right = 0.5
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_left = -184.0
	strip.offset_right = 184.0
	strip.offset_top = -112.0
	strip.offset_bottom = -20.0
	add_child(strip)
	var card_style := _make_card_face_style(true)
	for i in 4:
		var card := Panel.new()
		card.name = "Card%d" % i
		card.custom_minimum_size = Vector2(84.0, 92.0)
		card.add_theme_stylebox_override("panel", card_style)
		strip.add_child(card)
		# The caption. Inset by the frame width plus a hair so the text never touches the border,
		# word-wrapped and shrunk to fit because ids are snake_case compounds of unbounded length;
		# an id too long for the panel truncates visibly rather than overflowing into its
		# neighbour. Dark on the parchment face — legibility at half width is the whole point.
		var caption := Label.new()
		caption.name = "CardName"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.clip_text = true
		caption.add_theme_font_size_override("font_size", 12)
		caption.add_theme_color_override("font_color", Color(0.16, 0.13, 0.10))
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caption.offset_left = 5.0
		caption.offset_right = -5.0
		caption.offset_top = 4.0
		caption.offset_bottom = -4.0
		card.add_child(caption)
		# Story 3-5a (AC 10): the panels are retained for the selection indicator; story 3-6 adds
		# the index-aligned captions for the hand contents.
		_own_card_panels.append(card)
		_own_card_labels.append(caption)
	_card_base_style = card_style
	_card_armed_style = _make_card_armed_style()


## The SINGLE SEAT of the face-up / face-down decision (2-5/R1, R4). `is_own` picks a card FACE
## (own hand, face-up: light parchment, thin dark frame) versus a card BACK (face-down: deep
## indigo, heavy gold frame) — genuinely distinguishable at a glance in a half-width viewport,
## not two identical blank panels. One StyleBoxFlat is shared across the row's four panels. This
## one `if is_own` is the only place styling branches on ownership.
##
## Story 3-6: the `false` branch HAS NO CALLER any more, and is kept deliberately rather than
## deleted with the opponent row it used to style. It is what makes the deferred reveal-opponent-
## hand toggle (`3-6/R1`) cheap when its owning story arrives: the styling decision stays made,
## in one place, and that story adds a rendering path rather than re-deciding privacy. Deleting
## it would move the decision into whatever code re-invents it.
## Story 3-5a (AC 10): the ARMED card style — the own face style with a loud gold border and a
## warmer fill, so which slot is armed reads at a glance in a half-width viewport. Built from
## scratch rather than by mutating the shared base: the base StyleBoxFlat is shared across all
## four panels (2-5/R4), so mutating it in place would highlight the whole row.
##
## BORDER WIDTH ONLY GROWS INWARD in Godot's StyleBoxFlat, so a thicker armed border cannot
## change the panel's layout footprint — the 74x84 size and the row's offsets are untouched,
## which is what keeps sizing and layout with 3-6 as ruled.
func _make_card_armed_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(4)
	box.bg_color = Color(1.00, 0.96, 0.80)      # warmed parchment
	box.border_color = Color(0.96, 0.78, 0.22)  # loud gold — the armed tell
	box.set_border_width_all(5)
	return box


## Story 3-5a (AC 10): THE selection indicator. `slot` is the armed hand slot, -1 for none; the
## mode rides along for the E5 modes and is currently always BASIC.
##
## PRESENTATION-LOCAL, and pushed rather than subscribed. The runner reads the armed slot off the
## CONTROLLER after sample() and calls this — the same runner-polls-then-pushes-plain-values shape
## already shipped for the debug window countdown (3-0b, AC 2). It is therefore NOT a new
## observation seam and NOT an eighth: no signal, no state handle, no read of PlayerState.hand,
## and to_snapshot() never learns the indicator exists. The row's count-of-four stays the
## presentation-local constant it has been since 2-5/R1.
##
## Every panel is written on every call, not just the armed one, so the previously armed slot is
## always cleared — a "highlight the new one" that forgot to clear the old one would leave two lit
## and is exactly the failure the directional test below pins.
func set_card_selection(slot: int, mode: Enums.ModeKind) -> void:
	# The mode is accepted now so the call site is stable across E5, when the indicator gains a
	# per-mode tell. One mode resolves in E3, so it currently selects nothing.
	var _armed_mode := mode
	for i in _own_card_panels.size():
		var style: StyleBoxFlat = _card_armed_style if i == slot else _card_base_style
		_own_card_panels[i].add_theme_stylebox_override("panel", style)


## Story 4-6a (AC 13/AC 14): the LOCKED-TARGET MARKER -- the Souls/Sekiro/Elden Ring dot on the
## enemy you are locked to, requested at the 4-6 smoke ("svakako bi dodao marker tockicu na
## neprijatelju koji je trenutno targetan", playtest-log 31.8. item 6).
##
## A `HudRoot`-OWNED CONTROL, which is Open Question 3's answer. AC 13 required per-viewport
## visibility under EITHER branch -- P1's marker must never render in P2's view -- and this branch
## delivers it BY CONSTRUCTION: one `HudRoot` per SubViewport (see this file's header), each handed
## only its own slot's point by the runner. The world-space alternative (`2-4/R12`'s carve-out)
## would have needed fresh cull-mask/layer discipline, because `main.tscn`'s two SubViewports share
## one root `World3D` and declare neither `own_world_3d` nor any `cull_mask` -- new machinery whose
## only job would be to re-establish a property this branch cannot lose.
##
## IT IS NOT A "FOCAL / PERIPHERY" ELEMENT and does not contradict this file's layout doctrine.
## Every other element here is anchored to a viewport edge or centre and consulted at a known
## screen location; this one has no resting place at all -- it is a WORLD cue that happens to be
## drawn with a Control, positioned per tick from an unprojection. That is why it is built last and
## sized in absolute pixels rather than joining a band.
##
## MOUSE-TRANSPARENT AND TOP-MOST: `MOUSE_FILTER_IGNORE` matches the root's own no-input-eating
## rule, and being added last puts it above the vitals/hand siblings, so a target standing behind
## the hand row is still marked.
func _build_lock_marker() -> void:
	_lock_marker = Panel.new()
	_lock_marker.name = "LockMarker"
	_lock_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_marker.custom_minimum_size = LOCK_MARKER_SIZE
	_lock_marker.size = LOCK_MARKER_SIZE
	var box := StyleBoxFlat.new()
	# A DOT, not a reticle: full corner radius on a square makes a circle, which reads as a marker
	# at this size without needing an art asset the project does not have.
	box.bg_color = Color(0.95, 0.93, 0.85, 0.90)     # bone, near-opaque
	box.border_color = Color(0.08, 0.07, 0.06, 0.95) # dark rim, so it survives a pale background
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(LOCK_MARKER_SIZE.x * 0.5))
	_lock_marker.add_theme_stylebox_override("panel", box)
	_lock_marker.visible = false  # nothing is marked until the runner pushes a point
	add_child(_lock_marker)


## Story 4-6a (AC 13/AC 14): the runner's per-tick push -- this slot's locked target's position in
## THIS viewport, or null when it is not visible here and the marker must hide.
##
## THE SAME PLAIN-VALUE PUSH AS `set_card_selection` ABOVE (3-5a AC 10): no signal, no state
## handle, no `MatchState` reachable from this file. `Variant` rather than an overload pair because
## null IS the hide case and the runner's `_screen_position` already speaks it -- translating it
## into a sentinel `Vector2` here would invent a screen point that means "nowhere".
##
## CENTRED ON THE POINT, not anchored to it: `position` is a Control's TOP-LEFT, so the marker is
## offset by half its own size. Without that the dot would sit down-right of the enemy by its own
## radius, which at this size is exactly the kind of small constant error that reads as "the marker
## is on the wrong thing" at a smoke.
func set_lock_marker(point: Variant) -> void:
	if point == null:
		_lock_marker.visible = false
		return
	_lock_marker.visible = true
	_lock_marker.position = (point as Vector2) - LOCK_MARKER_SIZE * 0.5


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


## Deck count + reshuffle flag (story 3-6, AC 4) — the 2-4 top-left periphery placeholder, now
## real. Own-tempo per P4: a deck count is read BETWEEN exchanges, never mid-reaction, so it stays
## in the corner rather than moving toward the focal band.
##
## TWO stacked lines in the reserved footprint, grown just enough to hold them (40px -> 52px tall,
## 106 -> 118 wide). The count line is written by the eighth seam's payload; the flag line is
## written by the ownerless bus event and is hidden until one arrives — so an empty second line is
## the normal state and a visible one means a window is open right now. The count text is a
## placeholder dash until the first payload lands, which is one tick after construction.
func _build_deck_indicator() -> void:
	var deck := Panel.new()
	deck.name = "DeckIndicator"
	deck.anchor_left = 0.0
	deck.anchor_right = 0.0
	deck.anchor_top = 0.0
	deck.anchor_bottom = 0.0
	deck.offset_left = 10.0
	deck.offset_right = 128.0
	deck.offset_top = 10.0
	deck.offset_bottom = 62.0
	add_child(deck)
	var column := VBoxContainer.new()
	column.name = "DeckColumn"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	deck.add_child(column)
	_deck_label = Label.new()
	_deck_label.name = "DeckCount"
	_deck_label.text = "DECK --"
	_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Review finding (3-6): overflow protection, matching the card captions' pattern — the
	# 118px-wide column is narrower than "RESHUFFLE" can guarantee to fit at every font/DPI.
	_deck_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_deck_label.clip_text = true
	column.add_child(_deck_label)
	_reshuffle_label = Label.new()
	_reshuffle_label.name = "ReshuffleFlag"
	_reshuffle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reshuffle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_reshuffle_label.clip_text = true
	# Loud enough to catch the eye in the periphery — the flag is a state a player must NOTICE
	# without being asked to watch the corner for it.
	_reshuffle_label.add_theme_color_override("font_color", Color(0.98, 0.72, 0.20))
	_reshuffle_label.visible = false
	column.add_child(_reshuffle_label)


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
