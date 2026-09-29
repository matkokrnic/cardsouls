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
##     the lower-centre band. HP rides with stamina — it is the other value a player checks
##     the instant a hit connects. The two PITCH ZONES (story 6-3b) flank those bars in the same
##     band: this player's own zone to their left, the opponent's to their right.
##   - Periphery (own-tempo): the three ORB totals (live since 5-4) and the DECK / reshuffle count
##     are read between exchanges, never mid-reaction, so they sit in the top corners.
##   - The 4-card HAND strip is the player's own-tempo action surface; it takes the
##     bottom-centre where it is visible without competing with the reactive focal centre.
## (The centre "incoming telegraph" cue named in P4 is a WORLD-SPACE cue, not a HUD element —
## 2-4/R12 — so it is not built here.)
##
## Story 5-4 adds the FIFTH channel — connect_orbs_changed, the runner's ninth seam (AC 15) — feeding
## the three orb counters (AC 18-20). Per-slot and PRIVATE like the three economy ones and the card
## one; no orb fact about the opponent reaches this root.
##
## Story 6-3b adds the SIXTH channel — connect_pitch_changed, the runner's tenth seam (AC 1) — feeding
## BOTH pitch zones. Unlike every channel above it is MATCH-LEVEL: this root receives both players'
## zones and tells them apart by the payload's owner slot against the slot the runner BOUND at wiring
## (the on_round_ended shape). That is safe to receive because a zone is PUBLIC by GDD design and the
## payload carries no orb count or shortfall — the card, the countdown and READY only (operator
## ruling 2026-09-15, `6-3-split/R-INFO`).
##
## Story 3-6: the hand strip and the deck/reshuffle indicator are NO LONGER PLACEHOLDERS — they
## are the first two reserved regions to gain real content, and this story owns their final
## sizing (AC 6). Story 5-4 spends the THIRD reservation, the orb counters, and story 6-3b the last,
## the pitch zones. Card ART and a display-name field are out of scope for every scheduled story, so
## a card renders as its `CardData.id` text (`3-6/R4`).

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
var _round_label: Label
## Story 3-6 (AC 4): the deck-count read-out and the reshuffle flag beside it. The count comes
## from the eighth seam's payload; the flag comes from the ownerless bus event alone.
var _deck_label: Label
var _reshuffle_label: Label

## Story 5-4 (AC 18): the three orb count labels, index-aligned with `Enums.CardColor`
## (RED, BLUE, GREEN) -- the SAME order the ninth seam's payload arrives in, so the write is a
## positional copy with no lookup to get wrong. Filling the region 2-4 reserved, not a new layout.
var _orb_labels: Array[Label] = []

## Story 5-4 (AC 18): PER-COLOUR display was chosen over a fused one. Three counts of a
## three-colour RPS resource are three separate reads a player makes ("can I answer RED yet?"), and
## the reserved footprint already held three panels since 2-4 -- fusing them would have been a
## layout change dressed as a fill. Presentation-local hues, deliberately NOT read off
## data/telegraphs/: src/ui/ owns its own palette and the HUD loads no telegraph resource. They are
## the same three hues the charge telegraph uses, so the counter a player watches and the orb that
## flashed over the hero read as one colour.
const ORB_COLORS: Array[Color] = [
	Color(0.95, 0.30, 0.30),
	Color(0.40, 0.55, 0.98),
	Color(0.35, 0.90, 0.45),
]

## Story 6-5e (AC 4a/AC 24a, `6-5e/R26`/G7): the COLOURLESS hue -- Boulder's hand-row swatch. A NEUTRAL GREY
## and deliberately NOT a fourth `ORB_COLORS` entry: that array is the ORB palette, read by the orb counters
## and the price tags, and a colourless card is never an orb colour. A fourth entry there would make every
## orb reader three-and-a-bit long for a card that authors no orb cost anywhere.
##
## IT IS ALSO THE STONE/SKULL/BOULDER PLACEHOLDER'S OWN DISTINCTNESS ARGUMENT (AC 37) on the HUD side: grey
## is the one hue none of the three card colours occupies, so a Boulder in a hand row is distinguishable
## from every other card at a glance without a new asset.
const COLORLESS_SWATCH := Color(0.62, 0.62, 0.66)

## Story 3-6 (AC 4): the authored vulnerable-window duration in SECONDS, handed over by the runner
## at construction (the `gamepad_profile` static-handoff precedent), before add_child.
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
## Story 6-10 (AC 16-18): the own hand row's container, the card-mode flag pushed each frame, and the armed
## slot last pushed -- the three facts the LIFT is a pure function of.
var _hand_strip: HBoxContainer
var _card_mode_on := false
var _armed_slot := -1
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

## Story 6-0 (AC 1/AC 5): the four colour SWATCHES, one per own-row panel, index-aligned with
## `_own_card_panels`/`_own_card_labels`. A SEPARATE child control, not a mutation of
## `_card_base_style`/`_card_armed_style` -- `set_card_selection` (below) rewrites the WHOLE panel
## stylebox on every call for whichever style it picks, so a tint painted INTO that stylebox would
## be silently dropped on the next arm/disarm. A sibling control `set_card_selection` never
## touches survives every call by construction, which is the deliberate answer to AC 5 (see the
## Dev Notes' "styling crux is AC 5, not AC 1").
var _own_card_swatches: Array[Panel] = []
## One UNSHARED `StyleBoxFlat` PER swatch (unlike `_card_base_style`/`_card_armed_style`, which are
## deliberately shared across all four panels) -- each panel's swatch needs an INDEPENDENT colour,
## so mutating this instance in place is the correct move here, not the shared-instance bug
## `_make_card_armed_style`'s docstring warns against.
var _own_card_swatch_styles: Array[StyleBoxFlat] = []

## Story 6-5b (AC 23, `6-5b/R11`): the four PRICE captions, one per own-row panel, index-aligned with
## `_own_card_labels`. A SEPARATE Label rather than more lines appended to the id caption, for the
## swatch's own stated reason one field up applied to text: the id caption is rewritten wholesale by
## `_render_hand_row` on four different branches (real card, in-flight, ghost, blank), and folding the
## price into it would mean every branch had to remember to re-append it. A sibling label written from
## one place cannot fall out of step.
var _own_card_prices: Array[Label] = []

## Story 6-5b (AC 23): the id -> price row map the runner derives ONCE at load and hands in through
## the existing cards-changed wrapper -- `_last_card_colors`' shape and lifetime verbatim.
##
## THE PRICES ARE STATIC AUTHORED DATA AND NEVER ENTER GAME STATE (operator ruling, this story's one
## open question): they are read off `CardData.cast_condition` / `pitch_condition`, which no tick
## mutates, so there is nothing for the record or `FORMAT_VERSION` to carry and nothing for the hash to
## see. That is the `card_colors` precedent exactly, and it is why AC 23 costs this story no state, no
## capture channel and no snapshot key.
##
## One entry per id: `[mode-1 mana, mode-1 orbs, mode-4 mana, mode-4 orbs]`, the orbs as their own
## `Dictionary[Enums.CardColor, int]` exactly as authored.
var _last_card_prices: Dictionary = {}

## Story 4-6a (AC 13/AC 14): the locked-target dot. One per root, therefore one per SubViewport,
## therefore per-slot by construction -- see _build_lock_marker.
var _lock_marker: Panel

## Story 4-B1 (AC 1): the in-flight placeholder — visually distinct from both a real card id
## (always a snake_case CardData.id, never punctuation-only) and from the permanent-hole blank
## (""). Cheapest legible treatment at half-width: a caption swap on the existing
## `_own_card_labels` machinery, no new StyleBox and no border/style change.
const IN_FLIGHT_CAPTION := "..."

## Story 6-5b (AC 23): the two MODE MARKERS the price block prefixes each line with. AC 23's format
## requirement is exactly that the two numbers be "visibly distinguishable as belonging to mode 1 vs.
## mode 4", and these are what carry that -- the GDD's own mode numbers, so the label a player reads
## matches the mode they press. Presentation-local strings, never read by state.
const MODE_1_LABEL := "1:"
const MODE_4_LABEL := "4:"

## Story 6-5b (AC 23): the one-letter orb tags, index-aligned with `Enums.CardColor` (RED, BLUE, GREEN)
## exactly as `ORB_COLORS` above is -- so a price's orb tag and the orb counter's hue come from two
## lists that cannot drift, because both are positional reads of the same enum.
const ORB_INITIALS: Array[String] = ["R", "B", "G"]

## Story 4-6a (AC 13): the locked-target marker's pixel footprint. Square, because the dot is drawn
## as a fully-rounded Panel. Small on purpose -- it marks an enemy at half-width without occluding
## the enemy it marks; its final legibility is an OPERATOR SMOKE surface (`PROC/R8`), not a number
## this pass may declare correct.
const LOCK_MARKER_SIZE := Vector2(14.0, 14.0)

## Story 6-3b (AC 6): the staged-card GHOST -- a FOURTH hand-slot look, distinct from the full card
## (id caption at full opacity, swatch shown), the in-flight `"..."` and the blank hole. It shows the
## staged card's id and swatch DIMMED through this modulate, so the slot reads "that card is in your
## pitch zone" rather than "empty". Every other look writes `Color.WHITE` back, so a ghost never
## lingers on a slot that has moved on. Whether it reads at a glance is operator smoke (`PROC/R8`).
const GHOST_MODULATE := Color(1.0, 1.0, 1.0, 0.35)

## Story 6-3b (AC 4): the two pitch zones' fixed geometry, both anchored bottom-centre
## (`anchor 0.5,0.5,1,1`) and flanking the vitals column (centre ± 180). OWN is the 2-6 "anchor B"
## gutter LEFT of the bars; OPPONENT is its mirror RIGHT of them. 100 x 88 each. `offset_top` stays at
## -196: above -198 a zone would intersect the debug InstrumentBox (test_debug_instruments.gd's
## `_check_panel_layout`), which the -196 top clears by 2 px at the shipped 1152x648 window.
## Story 6-10 (AC 18): the LIFT knobs, in pixels. While card mode is on the whole own hand row rises
## CARD_MODE_ROW_LIFT_PX (4 = exactly the 4 px gap between the strip's -112 top and the vitals column's
## -116 bottom, so the lifted row does not overlap the vitals); the ARMED card rises a further
## CARD_MODE_ARMED_LIFT_PX on top of that. Pure position: no modulate, no swatch or caption write, no resize.
## Exact amounts are a smoke call (AC 18).
const CARD_MODE_ROW_LIFT_PX := 4.0
const CARD_MODE_ARMED_LIFT_PX := 6.0

const OWN_PITCH_OFFSETS := [-286.0, -196.0, -186.0, -108.0]   # left, top, right, bottom
const OPPONENT_PITCH_OFFSETS := [186.0, -196.0, 286.0, -108.0]

## Story 6-3b (AC 4): the two zones, each a Panel holding a card caption, a countdown bar and a READY
## label -- the same three facts in both, and no number of any kind.
var _own_pitch: Panel
var _opponent_pitch: Panel

## Story 6-3b (AC 6): HUD-LOCAL MEMORY for the one shared hand-row render path (the `_reshuffle_token`
## precedent for memory held here; nothing is added to state). `on_cards_changed` rewrites every slot
## on every call, so a ghost painted by `on_pitch_changed` alone would be wiped by the next unrelated
## hand payload (a refill of a DIFFERENT slot) -- instead both callbacks store their latest payload here
## and re-render the whole row from both, so the result does not depend on which arrives first.
var _last_hand_ids: Array = []
var _last_pending_draw_owed: Array = []
var _last_card_colors: Dictionary = {}
## This root's OWN staged card and the hand slot it left, from the last OWN `pitch_changed` payload.
## An opponent payload never writes these.
var _own_staged_card: StringName = PitchState.NO_CARD
var _own_staged_hand_slot: int = PitchState.NO_HAND_SLOT


func _init() -> void:
	name = "HudRoot"


func _ready() -> void:
	# Fill the SubViewport: the HUD's real footprint IS the half-width viewport.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # the HUD never eats gameplay input
	_build_vitals()
	_own_pitch = _build_pitch_zone("OwnPitch", OWN_PITCH_OFFSETS)
	_opponent_pitch = _build_pitch_zone("OpponentPitch", OPPONENT_PITCH_OFFSETS)
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


## Seam callback (connect_orbs_changed, the runner's NINTH seam — story 5-4, AC 15/AC 18-20).
## PRIMED ON CONNECT with the resting (0,0,0), so the reserved region renders real zeroes from frame
## one rather than a placeholder dash.
##
## OWN SLOT ONLY, structurally (AC 19). The runner binds this root to ONE slot's channel at
## construction and the payload carries NO slot index — there is nothing here to read the opponent's
## counts WITH, which is the `2-4/R7` / `3-6/R7` doctrine applied to orbs rather than a rule this
## function has to remember to obey.
##
## NO POLLING (AC 20). The counts CLEAR to zero on the debug reset and at match start through this
## same channel — `MatchState._reset_player` calls `OrbPool.reset_all()`, which signals — so this
## function is the single write seat for every direction the number can move.
func on_orbs_changed(red: int, blue: int, green: int) -> void:
	var counts := [red, blue, green]
	for i in _orb_labels.size():
		_orb_labels[i].text = str(counts[i])


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
## Story 6-0 (AC 1/AC 2/AC 3): `card_colors` is the SAME id->colour map `_derive_card_colors()`
## builds runner-side (AC 3, reused rather than re-derived a second time here), riding this
## existing wrapper alongside `pending_draw_owed` rather than a tenth `connect_*` seam (AC 2).
## `HudRoot` never reads `CardDatabase` itself -- the runner hands a plain
## `Dictionary[StringName, Enums.CardColor]` (AC 3). Defaulted to an empty Dictionary so the
## pre-existing 3-arg and 4-arg test call sites keep exercising their branches unchanged.
##
## Story 6-3b (AC 6): the payload is REMEMBERED and the row rendered through `_render_hand_row`, the one
## path `on_pitch_changed` shares, so a staged card's ghost survives this call rewriting every slot.
## Story 6-5b (AC 23): `card_prices` is the SAME id -> price-row map the runner derives once at load
## and hands in beside `card_colors`, riding this existing wrapper rather than an eleventh `connect_*`
## seam -- `card_colors`' own arrangement verbatim, and for its reason: this root never reads
## `CardDatabase` itself. Defaulted to an empty Dictionary so every pre-existing 3-, 4- and 5-arg test
## call site keeps exercising its branch unchanged (a slot with no price entry renders no price).
func on_cards_changed(
		hand_ids: Array, deck_count: int, _discard_count: int, pending_draw_owed: Array = [],
		card_colors: Dictionary = {}, card_prices: Dictionary = {}) -> void:
	_last_hand_ids = hand_ids.duplicate()
	_last_pending_draw_owed = pending_draw_owed.duplicate()
	_last_card_colors = card_colors
	_last_card_prices = card_prices
	_render_hand_row()
	_deck_label.text = "DECK %d" % deck_count


## Seam callback (connect_pitch_changed, the runner's TENTH seam — story 6-3b, AC 1/AC 3/AC 4/AC 6),
## `my_slot` BOUND at wiring (the on_round_ended shape). MATCH-LEVEL: this root receives BOTH players'
## zones. The payload's owner is compared with `my_slot` to pick the zone it drives -- own zone left of
## the bars, opponent zone right of them -- and ONLY an own payload touches the ghost memory, so an
## opponent's staged hand slot can never ghost this player's row. Not primed: both zones start empty.
##
## Both zones render the same three facts and nothing else: the card id, the countdown as a bar, and
## READY. No orb count and no shortfall exists in the payload to render (`6-3-split/R-INFO`).
func on_pitch_changed(slot: int, card_id: StringName, hand_slot: int, ready: bool,
		remaining_ticks: int, duration_ticks: int, my_slot: int) -> void:
	var own := slot == my_slot
	_render_pitch_zone(_own_pitch if own else _opponent_pitch, card_id, ready, remaining_ticks,
			duration_ticks)
	if own:
		_own_staged_card = card_id
		_own_staged_hand_slot = hand_slot
		_render_hand_row()


## Story 6-3b (AC 6): THE ONE hand-row render path, from the remembered hand payload and the own pitch
## memory. Four looks, in precedence order: a real card (full opacity, tinted); the in-flight `"..."`;
## the GHOST of the own staged card -- only for a slot EMPTY in the hand payload, NOT owed, and equal
## to the own staged hand slot; otherwise blank (the permanent hole and the ordinary empty slot).
##
## Story 6-5b (AC 23): the PRICE BLOCK is written on the SAME four branches and from the same one
## place, which is the whole reason it is a sibling Label rather than extra lines on the id caption
## (see `_own_card_prices`). Two of the four looks carry a price and two do not, and each follows the
## caption's own precedent exactly:
##   * a REAL CARD shows both prices at full opacity;
##   * the GHOST shows both prices DIMMED through the same `GHOST_MODULATE` its caption and swatch use
##     -- the staged card IS still shown in this row, so AC 23's "every card shown in a player's own
##     hand row" covers it;
##   * the IN-FLIGHT slot holds no card id to price, exactly as it holds no colour to tint;
##   * a BLANK slot has nothing to price.
## A card whose id the derived map does not carry renders NO price rather than a guessed one -- the
## `_set_swatch_color(i, null)` posture verbatim.
func _render_hand_row() -> void:
	for i in _own_card_labels.size():
		var label := _own_card_labels[i]
		if i < _last_hand_ids.size() and _last_hand_ids[i] != Hand.EMPTY:
			var id: StringName = _last_hand_ids[i]
			label.text = str(id)
			label.modulate = Color.WHITE
			# AC 1: a slot holding a real card id is tinted; AC 1's "exhaustively" list of
			# untinted states (EMPTY, permanent hole, in-flight) all fall out of this branch never
			# running for them -- none of the three has a card id to look colour up by.
			_set_swatch_color(i, _last_card_colors.get(id, null))
			_set_price_text(i, id, Color.WHITE)
		elif _last_pending_draw_owed.has(i):
			label.text = IN_FLIGHT_CAPTION
			label.modulate = Color.WHITE
			_set_swatch_color(i, null)
			_set_price_text(i, Hand.EMPTY, Color.WHITE)
		elif _own_staged_card != PitchState.NO_CARD and i == _own_staged_hand_slot:
			label.text = str(_own_staged_card)
			label.modulate = GHOST_MODULATE
			_set_swatch_color(i, _last_card_colors.get(_own_staged_card, null), GHOST_MODULATE)
			_set_price_text(i, _own_staged_card, GHOST_MODULATE)
		else:
			label.text = ""
			label.modulate = Color.WHITE
			_set_swatch_color(i, null)
			_set_price_text(i, Hand.EMPTY, Color.WHITE)


## Story 6-5b (AC 23): the single write seat for one slot's price block -- `_set_swatch_color`'s twin,
## and deliberately its shape: one function, called on every branch of `_render_hand_row`, so a slot
## can never keep a previous card's price the way it could if only the card branch wrote here.
##
## `Hand.EMPTY` (or an id the derived map does not carry) CLEARS the block rather than hiding the
## label: the Label keeps its rect either way, so clearing the text is what keeps the four panels
## geometrically identical whatever they hold -- which is the property `test_hud_viewports.gd` asserts
## and `PROC/R8` leaves legibility out of.
func _set_price_text(index: int, id: StringName, tint: Color) -> void:
	if index >= _own_card_prices.size():
		return
	var price_label := _own_card_prices[index]
	price_label.modulate = tint
	var row: Variant = _last_card_prices.get(id, null) if id != Hand.EMPTY else null
	if row == null:
		price_label.text = ""
		return
	var entry: Array = row as Array
	# Story 6-5e (AC 4a): A CARD WITH NO MODE ④ SHOWS THE MODE ① LINE ONLY. Boulder authors no
	# `pitch_condition` at all (ruling 7 gives it no pitch effect), so `_derive_card_prices` maps its pitch
	# mana to 0.0 -- and rendering that as a "④0" line would advertise a staging the card refuses. The
	# absent Mode ④ is shown by ABSENCE, which is the honest reading and the `_set_swatch_color(i, null)`
	# posture (a fact the data does not carry is not guessed at).
	#
	# ZERO IS THE DISCRIMINATOR AND THAT IS SAFE HERE rather than a punned sentinel: a zero-mana pitch with
	# a real orb price is still a Mode ④, so the orb half is checked too -- only a card with NEITHER is
	# treated as having no Mode ④. `test_card_authoring.gd`'s per-card census guarantees every Deck 1 card
	# authors a positive orb price, so no shipped Mode ④ card can fall into this branch.
	var mode_4 := _mode_price_text(MODE_4_LABEL, entry[2], entry[3] as Dictionary)
	if is_zero_approx(float(entry[2])) and (entry[3] as Dictionary).is_empty():
		price_label.text = _mode_price_text(MODE_1_LABEL, entry[0], entry[1] as Dictionary)
		return
	price_label.text = "%s\n%s" % [
		_mode_price_text(MODE_1_LABEL, entry[0], entry[1] as Dictionary),
		mode_4,
	]


## Story 6-5b (AC 23): ONE mode's price line -- its mode marker, its mana and its orb price.
##
## THE MODE MARKER IS WHAT AC 23 ACTUALLY REQUIRES of the format: "both numbers (and any orb
## icon/count) must be visibly distinguishable as belonging to mode 1 vs. mode 4". A bare pair of
## numbers would not be, so each line names its mode. Everything else about the layout is an
## implementation choice the AC leaves open, and whether it READS at a glance is the smoke's call.
func _mode_price_text(marker: String, mana: Variant, orb_costs: Dictionary) -> String:
	var out := "%s%s" % [marker, _mana_text(float(mana))]
	# SORTED BY COLOUR ORDINAL, never by Dictionary iteration order: the authored `orb_costs` is a
	# `Dictionary[Enums.CardColor, int]`, and this project's standing rule is that its iteration order
	# is never a contract (`card_cast_condition.gd`). Two identical hands must render identically.
	var colors: Array = orb_costs.keys()
	colors.sort()
	for color: Variant in colors:
		var count := int(orb_costs[color])
		if count > 0:
			out += " %d%s" % [count, ORB_INITIALS[int(color)]]
	return out


## An authored mana cost as text. WHOLE NUMBERS LOSE THEIR DECIMAL, because every authored Deck 1
## price is an integer and "3" in a 74px-wide band is worth two characters against "3.0". A retuned
## fractional price still renders, to one place.
func _mana_text(mana: float) -> String:
	return str(int(round(mana))) if is_equal_approx(mana, round(mana)) else "%.1f" % mana


## Story 6-3b (AC 4): one zone's three facts. An empty zone (`NO_CARD`) renders blank: no caption, an
## empty bar, no READY. The bar is the countdown as `remaining / duration`; it moves only when a payload
## arrives (on the authored throttle, AC 5), never per frame.
func _render_pitch_zone(zone: Panel, card_id: StringName, ready: bool, remaining_ticks: int,
		duration_ticks: int) -> void:
	var staged := card_id != PitchState.NO_CARD
	var caption: Label = zone.get_node("Card")
	var bar: ProgressBar = zone.get_node("Countdown")
	var ready_label: Label = zone.get_node("Ready")
	caption.text = str(card_id) if staged else ""
	bar.max_value = maxi(1, duration_ticks)
	bar.value = remaining_ticks if staged else 0
	ready_label.visible = staged and ready


## Story 6-0 (AC 1): the single write seat for the colour swatch. `color` is an
## `Enums.CardColor` or `null` (no colour found / no card in the slot) -- `null` hides the
## swatch rather than guessing a colour for a card the runner's map does not carry.
## Story 6-3b (AC 6): `tint_modulate` dims the swatch for the ghost look; every other look passes the
## default, so a slot leaving the ghost look is restored to full opacity.
func _set_swatch_color(index: int, color: Variant, tint_modulate := Color.WHITE) -> void:
	if index >= _own_card_swatches.size():
		return
	var swatch := _own_card_swatches[index]
	swatch.modulate = tint_modulate
	if color == null:
		swatch.visible = false
		return
	# Story 6-5e (AC 4a, `6-5e/R26`/G7): THE COLOURLESS GUARD. `ORB_COLORS` is an ORB palette and stays
	# THREE long (a colourless card never authors an orb cost, so nothing else here needs a fourth entry),
	# but this one expression indexes it by a CARD's colour ordinal -- so Boulder's new `COLORLESS` ordinal
	# would read PAST THE END. It renders NEUTRAL GREY instead, which is a positive design answer rather than
	# a bounds patch: a colourless card has a swatch (it is a real card in the row) and that swatch must not
	# be a positional accident of the orb palette.
	#
	# WITHOUT THIS THE GATE'S OWN FINDING BITES: an "unread colour field" plan would have shipped Boulder as
	# a silent RED swatch, because `_derive_card_colors()` maps the whole library including Boulder.
	if int(color) == Enums.CardColor.COLORLESS:
		_own_card_swatch_styles[index].bg_color = COLORLESS_SWATCH
	else:
		_own_card_swatch_styles[index].bg_color = ORB_COLORS[color as int]
	swatch.visible = true


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


## Story 6-3b (AC 4): one pitch zone -- REPLACING the 2-6 dead-centre pitch panel and its placement
## switch, both deleted. A bordered 100x88 panel at `offsets` ([left, top, right, bottom], anchored
## bottom-centre) holding exactly three children, the same in the own and the opponent zone: `Card`,
## the staged id caption; `Countdown`, a ~80 px bar (so one throttle move is ~2 px at the authored
## 20 s / 30-tick cadence); and `Ready`, hidden until a payload says READY. Built EMPTY -- no caption,
## an empty bar, no READY -- which is the correct render until the first staging, because the seam does
## not prime. The bar shows no percentage: no number of any kind appears in a zone.
func _build_pitch_zone(node_name: String, offsets: Array) -> Panel:
	var zone := Panel.new()
	zone.name = node_name
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.anchor_left = 0.5
	zone.anchor_right = 0.5
	zone.anchor_top = 1.0
	zone.anchor_bottom = 1.0
	zone.offset_left = offsets[0]
	zone.offset_top = offsets[1]
	zone.offset_right = offsets[2]
	zone.offset_bottom = offsets[3]
	add_child(zone)
	var caption := Label.new()
	caption.name = "Card"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.clip_text = true
	caption.add_theme_font_size_override("font_size", 12)
	caption.anchor_right = 1.0
	caption.offset_left = 4.0
	caption.offset_right = -4.0
	caption.offset_top = 4.0
	caption.offset_bottom = 44.0
	zone.add_child(caption)
	var bar := ProgressBar.new()
	bar.name = "Countdown"
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = 0.0
	bar.anchor_right = 1.0
	bar.offset_left = 10.0
	bar.offset_right = -10.0
	bar.offset_top = 48.0
	bar.offset_bottom = 60.0
	zone.add_child(bar)
	var ready_label := Label.new()
	ready_label.name = "Ready"
	ready_label.text = "READY"
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.add_theme_font_size_override("font_size", 14)
	ready_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.30))
	ready_label.anchor_right = 1.0
	ready_label.offset_top = 62.0
	ready_label.offset_bottom = 84.0
	ready_label.visible = false
	zone.add_child(ready_label)
	return zone


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
	_hand_strip = strip
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
		# Story 6-0: -13.0, was -4.0. The caption's bottom inset was PULLED UP to open a band for
		# the colour swatch below it. See the swatch's own comment for the arithmetic -- the short
		# version is that the old -4.0 left no room at all: the swatch needs a band, and the armed
		# style's 5px inward border owns the bottom 5px, so the caption had to give some back.
		# Story 6-5b (AC 23): -35.0, was -13.0. The caption's bottom inset is PULLED UP AGAIN to open a
		# band for the two-line price block below it, exactly as 6-0 pulled it up from -4.0 to open the
		# swatch's band. The id is still the panel's dominant element and still word-wraps and
		# ellipsises inside its own rect.
		caption.offset_bottom = -35.0
		card.add_child(caption)
		# Story 6-5b (AC 23, `6-5b/R11`): THE PRICE BLOCK -- both modes' prices, on two lines, in the
		# band the caption just gave back. A sibling of `caption` and of `swatch`, never a child of
		# either (see `_own_card_prices`).
		#
		# THE REAL RECTS, in the panel's own 84x92 space, computed rather than asserted -- the same
		# arithmetic 6-0's own comment got wrong by 5px once, so it is stated in full:
		#   caption   y in [4, 57]   (PRESET_FULL_RECT, offset_top 4 / offset_bottom -35)
		#   price     y in [58, 79]  (anchored to the bottom, offset_top -34 / offset_bottom -13)
		#   swatch    y in [80, 86]  (anchored to the bottom, offset_top -12 / offset_bottom -6)
		#   armed border, bottom band  y in [87, 92]  (set_border_width_all(5), grows INWARD)
		# One pixel of clearance above and below: the price block touches neither the caption's text
		# rect nor the swatch. Horizontally it takes the caption's own 5px insets, which clear the armed
		# border's side bands ([0,5] and [79,84]) the same way the swatch's 6px insets do.
		#
		# 22px FOR TWO LINES AT FONT SIZE 9 IS TIGHT BY CONSTRUCTION, and that is the honest state of
		# it: `PROC/R8` puts on-screen legibility at the operator's smoke (item 12) and machine checks
		# assert GEOMETRY only. `clip_text` means an over-long price TRUNCATES inside its own rect
		# rather than overflowing into the neighbouring card.
		var price := Label.new()
		price.name = "CardPrice"
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price.autowrap_mode = TextServer.AUTOWRAP_OFF
		price.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		price.clip_text = true
		price.add_theme_font_size_override("font_size", 9)
		price.add_theme_color_override("font_color", Color(0.24, 0.20, 0.16))
		price.anchor_left = 0.0
		price.anchor_right = 1.0
		price.anchor_top = 1.0
		price.anchor_bottom = 1.0
		price.offset_left = 5.0
		price.offset_right = -5.0
		price.offset_top = -34.0
		price.offset_bottom = -13.0
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(price)
		# Story 6-0 (AC 1/AC 5): the colour swatch -- a thin bar along the panel's bottom edge.
		# A sibling of `caption`, not a child of it and not a mutation of `card_style` -- see the
		# swatch fields' own doc comment for why it must stay outside the swapped stylebox. Hidden
		# by default: nothing is tinted until on_cards_changed says so, so a slot that never
		# receives a real card id (Hand.EMPTY, permanent hole, in-flight) stays untinted by
		# construction rather than by remembering to skip a colour lookup.
		#
		# THE REAL RECTS, in the panel's own 84x92 space (custom_minimum_size above; the HandStrip
		# is 92 tall and the HBox gives each child the full height). These numbers are computed,
		# not asserted -- an earlier revision of this comment claimed the swatch sat "BELOW the
		# caption's -4.0 inset so it never overlaps", which was arithmetically FALSE by 5px:
		#   caption   y in [4, 79]   (PRESET_FULL_RECT, offset_top 4 / offset_bottom -13)
		#   swatch    y in [80, 86]  (anchored to the bottom, offset_top -12 / offset_bottom -6)
		#   armed border, bottom band  y in [87, 92]  (set_border_width_all(5), grows INWARD)
		# One pixel of clearance on each side: the swatch touches neither the caption's text rect
		# above it nor the armed tell's gold band below it. Horizontally x in [6, 78] clears the
		# armed border's side bands ([0,5] and [79,84]) the same way, which is why the 6.0/-6.0
		# insets are not merely decorative. Whether the resulting bar READS at a glance is the
		# operator smoke's call (PROC/R8), not this arithmetic's.
		var swatch := Panel.new()
		swatch.name = "ColorSwatch"
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.anchor_left = 0.0
		swatch.anchor_right = 1.0
		swatch.anchor_top = 1.0
		swatch.anchor_bottom = 1.0
		swatch.offset_left = 6.0
		swatch.offset_right = -6.0
		swatch.offset_top = -12.0
		swatch.offset_bottom = -6.0
		var swatch_style := StyleBoxFlat.new()
		swatch_style.set_corner_radius_all(2)
		swatch.add_theme_stylebox_override("panel", swatch_style)
		swatch.visible = false
		card.add_child(swatch)
		# Story 3-5a (AC 10): the panels are retained for the selection indicator; story 3-6 adds
		# the index-aligned captions for the hand contents.
		_own_card_panels.append(card)
		_own_card_labels.append(caption)
		_own_card_swatches.append(swatch)
		_own_card_prices.append(price)
		_own_card_swatch_styles.append(swatch_style)
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
	_armed_slot = slot
	_apply_card_lift()


## Story 6-10 (AC 16/AC 20): the mode-on flag, pushed by the runner each frame beside `set_card_selection`
## (outside the ticking gate). Presentation-local like the armed slot: no signal, no state read.
func set_card_mode(on: bool) -> void:
	_card_mode_on = on
	_apply_card_lift()


## Story 6-10 (AC 18/AC 19): the LIFT. Row: the strip's top/bottom offsets shift together (position only,
## size unchanged). Armed card: its own `position.y`, applied only while mode is on, so a card is never
## lifted alone. Written every call, so a container re-sort that reset a child position is corrected on the
## next frame's push. No `modulate`, no swatch or caption touched, so the 6-0 tint is untouched.
func _apply_card_lift() -> void:
	if _hand_strip == null:
		return
	var row_lift := CARD_MODE_ROW_LIFT_PX if _card_mode_on else 0.0
	_hand_strip.offset_top = -112.0 - row_lift
	_hand_strip.offset_bottom = -20.0 - row_lift
	for i in _own_card_panels.size():
		_own_card_panels[i].position.y = -CARD_MODE_ARMED_LIFT_PX 				if (_card_mode_on and i == _armed_slot) else 0.0


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


## The three orb counters — story 5-4 (AC 18) fills the region 2-4 RESERVED here, so this is the
## reservation being spent rather than a new layout decision. Top-right periphery, own-tempo per P4:
## an orb total is read BETWEEN exchanges ("can I answer RED yet?"), never mid-reaction, so it stays
## in the corner rather than moving toward the focal band.
##
## The footprint, the three panels and the "0" captions all predate this story; what it adds is the
## per-colour TINT that says WHICH count each panel is, and keeping the labels so the ninth seam can
## write them. Legibility of a small digit at half-width is an OPERATOR SMOKE surface (`PROC/R8`),
## not a number this pass may declare correct.
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
		count.name = "OrbCount%d" % i
		count.text = "0"
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		count.add_theme_color_override("font_color", ORB_COLORS[i])
		orb.add_child(count)
		orbs.add_child(orb)
		_orb_labels.append(count)


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
