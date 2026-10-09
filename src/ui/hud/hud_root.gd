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
##     the instant a hit connects.
##   - Periphery (own-tempo): the three ORB totals (live since 5-4) and the DECK / reshuffle count
##     are read between exchanges, never mid-reaction, so they sit in the top corners.
##   - The 4-card HAND strip is the player's own-tempo action surface; it takes the
##     bottom-centre where it is visible without competing with the reactive focal centre. The two
##     PITCH ZONES (story 6-3b) flank it (7-6 moved them down beside the hand): this player's own zone
##     to its left, the opponent's to its right.
##   - Story 7-6 (R6): the PLAY HISTORY strip rides the viewport's OUTER edge (left in P1's half, right
##     in P2's), vertically centred -- a between-exchanges read, so periphery.
## (The centre "incoming telegraph" cue named in P4 is a WORLD-SPACE cue, not a HUD element —
## 2-4/R12 — so it is not built here.)
##
## Story 5-4 adds the FIFTH channel — connect_orbs_changed, the runner's ninth seam (AC 15) — feeding
## the three orb counters (AC 18-20). Per-slot and PRIVATE like the three economy ones and the card
## one. (Story 7-6, R7: orb counts are now ALSO shown publicly as world-space orbs around each hero --
## `OrbHalo`, not this root. This root still receives only its own slot's counts.)
##
## Story 6-3b adds the SIXTH channel — connect_pitch_changed, the runner's tenth seam (AC 1) — feeding
## BOTH pitch zones. Unlike every channel above it is MATCH-LEVEL: this root receives both players'
## zones and tells them apart by the payload's owner slot against the slot the runner BOUND at wiring
## (the on_round_ended shape). That is safe to receive because a zone is PUBLIC by GDD design and the
## payload carries no orb count or shortfall — the card, the countdown and READY only (operator
## ruling 2026-09-15, `6-3-split/R-INFO`).
##
## Story 7-6 (D1) adds two more ownerless bus events, EventBus.card_effect_resolved and
## card_effect_countered, feeding the play-history strip. Played effects are public (R6); the payload is
## the resolving player, the EFFECT id and the normal/pitch flag -- no card id, no hand content (AC 25).
##
## Story 7-6 (R1-R5): THE CARD FACE. No words: each own-hand card is two EQUAL halves split by a divider --
## the NORMAL effect's art and mana cost on top, the PITCH effect's art, mana cost and one pip per required
## orb below -- plus an empty reserved keyword slot top-right. The card's colour is its FRAME (`ColorSwatch`)
## and its two ART BACKINGS, never the plate a cost is printed on (AC 8). Art is keyed by the EFFECT id
## (`EffectIconSet`, R2). A card LIFTS when its normal cost is affordable, its pitch cost brightens when the
## pitch is affordable, each pip lights when an orb of its colour is held (R3); card mode and the armed card
## are a FRAME highlight drawn outside the card, never a lift (AC 17).

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
## Story 7-6 (operator ruling P20, 2026-10-06): the orb counters' row, kept so the debug layer (F3) can show it.
var _orb_counters: Control

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

## Story 6-5e (AC 4a/AC 24a, `6-5e/R26`/G7): the COLOURLESS hue -- Boulder's frame. A NEUTRAL GREY and
## deliberately NOT a fourth `ORB_COLORS` entry: that array is the ORB palette, read by the orb counters and
## the pitch pips, and a colourless card is never an orb colour (7-6 AC 9 pins it).
const COLORLESS_SWATCH := Color(0.62, 0.62, 0.66)

## Story 3-6 (AC 4): the authored vulnerable-window duration in SECONDS, handed over by the runner
## at construction (the `gamepad_profile` static-handoff precedent), before add_child.
## PRESENTATION-LOCAL AND FOR THE FLAG ONLY: it seeds the one-shot timer that turns the flag back
## off, so the HUD never reads PlayerState.vulnerable_window — which stays WRITE-ONLY unhashed
## state that nothing consults (3-5b/R20), the property keeping the window's mechanical cost a
## genuinely OPEN decision. If that window ever gains a cost, this number stops being the whole
## story and the render is revisited THEN, deliberately (`3-6/R3`).
var reshuffle_vulnerable_window_seconds := 0.0

## Story 7-6 (R6): which viewport edge is this root's OUTER edge, handed over by the runner before add_child
## (the static-handoff precedent above). P1's half is the left one, so its outer edge is the left.
var history_on_left := true

## Story 3-6 (AC 4): which reshuffle announcement the visible flag belongs to. Each event
## increments it and its own one-shot timer captures the value; a timer whose token is stale does
## nothing. Without this, a SECOND reshuffle landing while the flag is up would be switched off
## early by the FIRST one's timer — the flag would lie about a window that is still open.
var _reshuffle_token := 0

## Story 7-6 (R1): THE CARD FACE GEOMETRY, in the card panel's own space. Two EQUAL halves (AC 5) of
## `HALF_SIZE`, one `DIVIDER_PX` divider between them, inside a `CARD_FRAME_PX` colour frame. The art slot is
## SQUARE and the same size in both halves; the cost BADGE sits right of it, clear of the frame band and of the
## art backing -- the two coloured surfaces -- so the colour never covers a cost (AC 8). The keyword slot is the
## empty top-right reservation (AC 7). Every rect is fixed at build time and never written again, which is what
## makes an art swap a texture write only (AC 10).
## 7-6 POLISH (operator ruling P1, 2026-10-05): the card is AS LARGE AS THE HALF-SCREEN ALLOWS -- 92x118 -> 128x158.
## The binding limit is HEIGHT: the always-on debug InstrumentBox fills y[356,450] across both halves' inner sides,
## so the hand owns the band below it (y 452..648) ALONE -- the vitals, both pitch zones and the history strip moved
## to the OUTER column (operator answer in chat, 2026-10-05). In that band: 8 px bottom margin + 158 card +
## `CARD_MODE_ARMED_LIFT_PX` 24 + the armed frame's 4 px outset = 194 <= 196. Badges are solid, larger and
## high-contrast; pips are 13 px with 4 px gaps.
## 7-6 POLISH 2 (operator ruling P8, 2026-10-06): the card-colour FRAME is permanent and as thick as the armed
## frame (`ARMED_FRAME_PX`), drawn by `ColorSwatch` OUTSIDE the halves, so dimming a half never dims the colour and
## the frame ties the two halves together. The halves are re-derived inside it.
## 7-6 POLISH 3 (operator ruling P14, 2026-10-06, supersedes P8's separate armed frame): ONE frame per card,
## `CARD_FRAME_PX` 6 -- about the visual weight the armed state had -- in the card's own colour; ARMING TURNS THAT
## SAME FRAME GOLD (plus a soft gold glow and the lift), never a second frame. Halves re-derived inside it.
##   frame bands    x[0,6] x[122,128] y[0,6] y[152,158]
##   normal half    (6,6)   116x72 -- art backing (3,3) 64x64, art (5,5) 60x60, cost badge (70,20) 42x42
##   divider        (6,78)  116x2
##   pitch half     (6,80)  116x72 -- art backing (3,3) 64x64, art (5,5) 60x60, cost badge (70,3) 42x36,
##                                    pips (69,45) 46x20
##   keyword slot   (104,8) 14x14
const CARD_SIZE := Vector2(128.0, 158.0)
const CARD_GAP := 8.0
const CARD_FRAME_PX := 6
const DIVIDER_PX := 2.0
const HALF_SIZE := Vector2(116.0, 72.0)
const ART_BACK_RECT := Rect2(3.0, 3.0, 64.0, 64.0)
const ART_RECT := Rect2(5.0, 5.0, 60.0, 60.0)
const NORMAL_COST_RECT := Rect2(70.0, 20.0, 42.0, 42.0)
const PITCH_COST_RECT := Rect2(70.0, 3.0, 42.0, 36.0)
const PIPS_RECT := Rect2(69.0, 45.0, 46.0, 20.0)
const PIP_SIZE := 13.0
const MAX_PIPS := 3
const PIP_GAP := 3.0
const KEYWORD_SLOT_RECT := Rect2(104.0, 8.0, 14.0, 14.0)
## P1: the cost badge -- a solid near-black plate, a bone rim, a large white number with a black outline.
const COST_FONT_NORMAL := 30
const COST_FONT_PITCH := 26
const COST_BADGE_BG := Color(0.05, 0.045, 0.04, 0.96)
const COST_BADGE_RIM := Color(0.86, 0.80, 0.62)

## The float tolerance of every "is this mana cost affordable" read, and of the mana number's floor (F5).
const AFFORD_EPSILON := 0.0001

## 7-6 POLISH (operator ruling P2, supersedes R3's lift): AFFORDABILITY IS BRIGHTNESS, per HALF. A half whose mana
## cost you cannot pay is DIMMED (`UNAFFORDABLE_MODULATE` on the half) and DESATURATED (its art backing drops to
## `UNAFFORDABLE_SATURATION` of the hue); a payable half is full colour and shows `Rim`, a thin glowing rim. The
## normal and the pitch half are judged independently. Pips keep filling by count (F3).
const UNAFFORDABLE_MODULATE := Color(0.5, 0.5, 0.52, 1.0)
const UNAFFORDABLE_SATURATION := 0.15
const AFFORD_RIM_PX := 2
const AFFORD_GLOW_PX := 4
## 7-6 POLISH 2 (operator ruling P7): a pip is ALWAYS drawn in its full orb colour -- a HELD orb is a filled
## circle, a MISSING one a hollow ring `PIP_RING_PX` thick. Count-fill (F3) unchanged.
const PIP_RING_PX := 3

## Story 7-4 (AC 12/AC 13, placeholder look): the SORCERY marker and the zone's sockets. The hourglass sits in the
## top-left corner of the hand card's pitch-half art and of the zone; the sockets are rings in a centred row,
## filling as orbs are earned after staging.
const HOURGLASS_SIZE := Vector2(10.0, 14.0)
const HOURGLASS_COLOR := Color(1.0, 0.78, 0.30)
const HAND_HOURGLASS_POS := Vector2(7.0, 7.0)
const ZONE_HOURGLASS_POS := Vector2(6.0, 6.0)
## 7-4 SMOKE FIX, ROUND 2 (operator smoke, 2026-10-09). The first look put hand-pip-sized rings inside the art square
## above the countdown bar, which read small, crowded and on top of the art. Round 1 grew the zone instead, and the
## operator rejected that: the zone keeps its card-sized P15 geometry.
## The sockets now sit in the band BELOW the countdown bar (zone y 126-158). The row's left edge is flush with the bar's
## left edge, read off the built bar's `offset_left`, with no centring.
## ROUND 3 (operator, 2026-10-09): round 2's white outline is REMOVED. An EMPTY socket's coloured ring is
## `ZONE_SOCKET_RING_PX` thick, zone-only, so the hand pips' `PIP_RING_PX` is unchanged. A filled socket stays filled.
## READY shares that band and is neither moved nor resized. When the READY label's rect and the socket row overlap,
## the row hides while READY shows (READY means every socket is filled).
## Fill, colour order and visibility are otherwise unchanged.
const ZONE_SOCKET_SIZE := 24.0
const ZONE_SOCKET_RING_PX := 6
const ZONE_SOCKET_GAP := 4.0
## The band below the bar: the bar ends at zone y 126 and the card-sized zone at 158, so the 24 px row is centred in it.
const ZONE_SOCKET_BAND_TOP := 126.0
const ZONE_SOCKET_BAND_BOTTOM := 158.0

## 7-6 POLISH (operator ruling P3, supersedes R3's "mode/armed as a frame highlight"): ARMING IS A LIFT AGAIN. Card
## mode on lifts the whole row by `CARD_MODE_ROW_LIFT_PX`; the armed card rises to `CARD_MODE_ARMED_LIFT_PX` (the
## pre-7-6 knobs were 4 and 6) and carries a strong bright `ARMED_FRAME_PX` frame drawn OUTSIDE the card. As before
## 7-6, a card never lifts alone: the lifts apply only while card mode is on, the armed frame whenever a slot is
## armed. A Boulder-covered slot shows neither (AC 21).
const CARD_MODE_ROW_LIFT_PX := 6.0
const CARD_MODE_ARMED_LIFT_PX := 24.0
## P14: the armed card's frame IS its card frame turned gold -- so its width is `CARD_FRAME_PX` -- with a soft gold
## glow `ARMED_GLOW_PX` outside it.
const ARMED_FRAME_PX := CARD_FRAME_PX
const ARMED_FRAME_COLOR := Color(1.0, 0.84, 0.30)
const ARMED_GLOW_PX := 4

## Story 7-6 (R4, AC 20): the covered card's faintness under a Boulder.
const UNDER_MODULATE := Color(1.0, 1.0, 1.0, 0.32)
## The Boulder cover's rect in the card's own space: a slab across the middle, so the covered card's top and
## bottom edges stay visible around it. Its art and badge sit at the face's sizes.
const BOULDER_COVER_RECT := Rect2(5.0, 38.0, 118.0, 82.0)
const BOULDER_ART_BACK_RECT := Rect2(6.0, 8.0, 66.0, 66.0)
const BOULDER_ART_RECT := Rect2(8.0, 10.0, 62.0, 62.0)
const BOULDER_COST_RECT := Rect2(76.0, 19.0, 36.0, 44.0)

## Story 7-6 (R5, AC 22): the own-play flash -- a bright wash over the slot with a glow outside it, held for
## `PLAY_FLASH_HOLD_SECONDS` and then faded. 7-6 POLISH (operator ruling P4): stronger and longer (was 0.85 alpha
## over 0.4 s, no hold, no glow) so it reaches peripheral vision.
const PLAY_FLASH_SECONDS := 0.7
const PLAY_FLASH_HOLD_SECONDS := 0.12
const PLAY_FLASH_ALPHA := 1.0
const PLAY_FLASH_GLOW_PX := 8

## Story 7-6 (R6, AC 23): the play-history strip -- at most `HISTORY_SIZE` entries, newest on top.
## 7-6 POLISH 2 (P9): back at its fix-pass size and place -- the outer edge, vertically centred.
const HISTORY_SIZE := 5
const HISTORY_ENTRY_PX := 44.0
const HISTORY_GAP := 6.0
const HISTORY_WIDTH := 60.0
## The opponent's entries sit indented toward the screen centre and carry a crimson rim; the viewer's own sit
## flush on the outer edge with a bone rim (AC 24's "visually distinct").
const HISTORY_OPPONENT_INDENT := 14.0
const HISTORY_OWN_RIM := Color(0.86, 0.80, 0.64)
const HISTORY_OPPONENT_RIM := Color(0.86, 0.18, 0.18)
const HISTORY_POP_SCALE := 1.6
const HISTORY_POP_SECONDS := 0.3

## 7-6 POLISH 2 (operator ruling P9, 2026-10-06): THE ARC. Laid out for the SHIPPED fullscreen half, 960 x 1080
## (stretch mode `disabled`, so the HUD is in native pixels; the game starts fullscreen). Bottom-centre offsets:
##   outer cards (slots 1, 4)   bottom -24 (`HAND_BOTTOM_PX`), top -182
##   middle cards (slots 2, 3)  raised `ARC_RAISE_PX` 48 -> bottom -72, top -230 (the controller's button layout)
##   vitals                     x[-132,132] (the middle pair's width) y[-66,-8] -- beneath the middle pair; the lower
##                              bars reach below the outer cards' bottom edge
##   own / opponent pitch zone  x[-368,-292] / x[292,368]  y[-142,-24] -- beside the hand, a 24 px gap
## The history strip is back at its fix-pass size and place (outer edge, vertically centred).
const HAND_BOTTOM_PX := 24.0
## 7-6 POLISH 3 (operator ruling P18): the vitals bars, slightly thinner (18 -> 15 px). 7-6 POLISH 4 (operator ruling
## P19): each bar's number has no plate -- white, bold, a thick dark outline, inside the bar near its right end.
const VITALS_BAR_PX := 15.0
const VITALS_VALUE_WIDTH := 72.0
const VITALS_VALUE_INSET := 4.0
const VITALS_VALUE_OUTLINE := 6
const ARC_RAISE_PX := 48.0
const VITALS_OFFSETS := [-132.0, -66.0, 132.0, -8.0]   # left, top, right, bottom
## 7-6 POLISH 3 (operator ruling P15): each pitch zone is CARD-SIZED and sits midway between the hand and its edge of
## the half, so the zone-to-hand gap equals the zone-to-edge gap at ANY half width: anchored at 0.25 (own) / 0.75
## (opponent) of the width and centred on that anchor offset by `PITCH_ZONE_CENTER_SHIFT` -- the centre of the free
## band [0, W/2 - 268] is W/4 - 134. Bottom-aligned with the outer cards. At the shipped 960 half: zone x[42,170] /
## [790,918], gap 42 px on both sides.
const PITCH_ZONE_CENTER_SHIFT := 134.0
const OWN_PITCH_ANCHOR := 0.25
const OPPONENT_PITCH_ANCHOR := 0.75
const OWN_PITCH_OFFSETS := [-198.0, -182.0, -70.0, -24.0]
const OPPONENT_PITCH_OFFSETS := [70.0, -182.0, 198.0, -24.0]

## 7-6 POLISH 2 (operator ruling P13): THE SLOT REEL. While a slot waits for its replacement it spins through the
## arts of this player's own deck (presentation-local randomness, never the match RNG; the HUD never learns the
## next card) and lands, with a small settle, when the hand payload delivers the real card. On/off is the authored
## `EffectIconSet.slot_reel_enabled` knob (default on).
const REEL_STEP_SECONDS := 0.11
const REEL_SLIDE_PX := 26.0
const REEL_ART_SIZE := 76.0
const REEL_SETTLE_SCALE := 1.07
const REEL_SETTLE_SECONDS := 0.28

## Story 3-5a (AC 10): the OWN hand row's four panels. Own row only — the opponent row is never shown.
var _own_card_panels: Array[Panel] = []
## Story 7-6: the own hand row's container -- a plain Control (not a box container) so a card's lift is a
## position write nothing re-sorts away.
var _hand_strip: Control
var _card_mode_on := false
var _armed_slot := -1
## The card BODY style: the `_make_card_face_style(true)` face, shared across the four panels (2-5/R4's single
## seat). The colour lives on each slot's own frame, not here.
var _card_base_style: StyleBoxFlat

## Story 3-6 (AC 1/AC 6): the four slot CAPTIONS. Since 7-6 (R1, "no words") a caption RENDERS only the
## in-flight `"..."` glyph; for every other look it is hidden and holds the slot's card id as the slot's
## identity record (what the live tests read), dimmed with the ghost exactly as before.
var _own_card_labels: Array[Label] = []

## Story 6-0 (AC 1/AC 5): the four colour carriers. Since 7-6 each is the card's colour FRAME -- a full-rect
## overlay that draws only its border (no centre), so it never sits under a cost. One unshared style each.
var _own_card_swatches: Array[Panel] = []
var _own_card_swatch_styles: Array[StyleBoxFlat] = []

## Story 7-6 (R1): per-slot face parts, index-aligned with `_own_card_panels`. Each `*_half` array holds the
## two half containers ([normal, pitch]); the art/back/cost arrays hold [normal, pitch] pairs.
var _own_card_halves: Array = []
var _own_card_arts: Array = []
var _own_card_art_backs: Array = []
var _own_card_art_back_styles: Array = []
var _own_card_costs: Array = []
var _own_card_pips: Array = []
## Story 7-4 (AC 12): each slot's pitch-half hourglass, index-aligned with `_own_card_panels`.
var _own_card_hourglasses: Array[Control] = []
## 7-6 POLISH (P2): each half's glowing affordability rim, [normal, pitch] per slot.
var _own_card_rims: Array = []
var _own_card_flashes: Array[Panel] = []
## P13: each slot's reel overlay and its art, and whether it is spinning.
var _own_card_reels: Array[Control] = []
var _own_card_reel_arts: Array[TextureRect] = []
var _reeling: Array[bool] = [false, false, false, false]
var _reel_cards: Array[StringName] = []
var _reel_last: Array[StringName] = [&"", &"", &"", &""]
## Presentation-local randomness for the reel -- its own generator, never the match RNG.
var _reel_rng := RandomNumberGenerator.new()
var _own_card_covers: Array[Panel] = []
var _own_card_cover_arts: Array[TextureRect] = []
var _own_card_cover_costs: Array[Label] = []
var _own_card_cover_frames: Array[StyleBoxFlat] = []
## Story 7-6 (R3/P2): what each slot's face is, for the brightness/pip pass: the id painted on the face (`&""` =
## none), the id whose costs the PLAYER can pay from this slot (`&""` = nothing playable: in flight, ghost, blank;
## the Boulder on a covered slot) and whether the slot is covered (AC 21 suppresses its lift and frame).
var _slot_face_ids: Array[StringName] = [&"", &"", &"", &""]
var _slot_play_ids: Array[StringName] = [&"", &"", &"", &""]
var _slot_covered: Array[bool] = [false, false, false, false]
## Each half's base modulate (white, the ghost or the faint under-a-Boulder look) before P2's dimming.
var _half_tints: Array = [[Color.WHITE, Color.WHITE], [Color.WHITE, Color.WHITE], [Color.WHITE, Color.WHITE],
		[Color.WHITE, Color.WHITE]]
## Each half's card hue (null = no colour), for P2's desaturation of the art backing.
var _half_hues: Array = [[null, null], [null, null], [null, null], [null, null]]

## Story 6-5b (AC 23): the id -> price row map the runner derives ONCE at load and hands in through
## the existing cards-changed wrapper -- `_last_card_colors`' shape and lifetime verbatim. STATIC AUTHORED
## DATA THAT NEVER ENTERS GAME STATE. One entry per id: `[mode-1 mana, mode-1 orbs, mode-4 mana, mode-4 orbs]`.
var _last_card_prices: Dictionary = {}

## Story 7-6 (R2, D2): the card -> effect pairing and the effect -> icon table, handed over by the runner
## before add_child (`set_effect_art`). `_card_effects[id] = [normal effect id, pitch effect id]`.
var _card_effects: Dictionary = {}
var _icons: EffectIconSet

## Story 7-6 (R3): the latest own mana and orb readings, from the two seams this root already receives.
var _mana := 0.0
var _orbs: Array[int] = [0, 0, 0]

## Story 7-6 (R6): the play history, newest first: `{slot, effect_id, is_pitch, countered}` dictionaries.
var _history: Array = []
var _history_strip: Control
var _history_entries: Array[Panel] = []
var _history_my_slot := -1

## Story 4-6a (AC 13/AC 14): the locked-target dot. One per root, therefore one per SubViewport,
## therefore per-slot by construction -- see _build_lock_marker.
var _lock_marker: Panel

## Story 4-B1 (AC 1): the in-flight placeholder — visually distinct from both a real card id
## and from the permanent-hole blank (""). Since 7-6 it is the only caption that renders.
const IN_FLIGHT_CAPTION := "..."

## Story 4-6a (AC 13): the locked-target marker's pixel footprint.
const LOCK_MARKER_SIZE := Vector2(14.0, 14.0)

## Story 6-3b (AC 6): the staged-card GHOST -- the staged card's face DIMMED through this modulate, so the slot
## reads "that card is in your pitch zone" rather than "empty". Every other look writes `Color.WHITE` back.
const GHOST_MODULATE := Color(1.0, 1.0, 1.0, 0.35)

## Story 6-3b (AC 4): the two pitch zones' geometry -- since 7-6 POLISH 2 (P9) beside the hand, see
## `OWN_PITCH_OFFSETS` / `OPPONENT_PITCH_OFFSETS` above: own zone left of the hand, opponent's right of it.

## Review fix F4 / P15: the zone's contents, zone-local, scaled to the card-sized zone: a 100 px art square, the
## countdown bar and READY below it.
const PITCH_ZONE_ART_RECT := Rect2(14.0, 8.0, 100.0, 100.0)

## Story 6-3b (AC 4): the two zones, each a Panel holding a card caption, a countdown bar and a READY
## label -- the same three facts in both, and no number of any kind.
var _own_pitch: Panel
var _opponent_pitch: Panel

## Story 6-3b (AC 6): HUD-LOCAL MEMORY for the one shared hand-row render path. Both callbacks store their
## latest payload here and re-render the whole row from both, so the result does not depend on which arrives
## first.
var _last_hand_ids: Array = []
var _last_pending_draw_owed: Array = []
var _last_card_colors: Dictionary = {}
## Story 7-6 (R4): the CARD layer beneath any Boulder cover, from the same wrapper (`Hand.to_array()`).
var _last_under_ids: Array = []
## This root's OWN staged card and the hand slot it left, from the last OWN `pitch_changed` payload.
var _own_staged_card: StringName = PitchState.NO_CARD
var _own_staged_hand_slot: int = PitchState.NO_HAND_SLOT
## Story 7-6 (R5): each slot's previous look, for the play-flash diff (`_looks_before`).
var _slot_looks: Array[int] = [LOOK_BLANK, LOOK_BLANK, LOOK_BLANK, LOOK_BLANK]
## 7-6 review fix (operator ruling F2): the hand slot the own staged card left, remembered when the own zone
## CLEARS. An activation's own pitch resolution then flashes it; a fizzle resolves nothing, so it never flashes.
## -1 = none. Needed because the drain delivers the zone clear BEFORE the owed-slot hand payload.
var _cleared_stage_slot := -1
## 7-6 review fix (m5): the one running tween per animated node (flash panels, history entries), so a restart
## kills the previous one instead of racing it.
var _tweens: Dictionary = {}
## P14: each slot's frame hue (null = no frame) and whether it is armed (the frame then shows gold).
var _frame_hues: Array = [null, null, null, null]
var _slot_armed: Array[bool] = [false, false, false, false]
## 7-6 POLISH (P3): each slot's current lift, so the per-frame push writes a position only when it changes.
var _slot_lifts: Array[float] = [0.0, 0.0, 0.0, 0.0]

enum { LOOK_BLANK, LOOK_CARD, LOOK_COVERED, LOOK_IN_FLIGHT, LOOK_GHOST }


func _init() -> void:
	name = "HudRoot"


func _ready() -> void:
	# Fill the SubViewport: the HUD's real footprint IS the half-width viewport.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # the HUD never eats gameplay input
	_build_vitals()
	_own_pitch = _build_pitch_zone("OwnPitch", OWN_PITCH_ANCHOR, OWN_PITCH_OFFSETS)
	_opponent_pitch = _build_pitch_zone("OpponentPitch", OPPONENT_PITCH_ANCHOR, OPPONENT_PITCH_OFFSETS)
	# Story 3-6 (AC 1): ONE hand row — the owning player's, face-up. The opponent's face-down row is
	# DELETED (E3-RG/R4); `_make_card_face_style`'s face-down branch survives untouched for the deferred
	# reveal toggle (`3-6/R1`).
	_build_hand_row()
	_build_history_strip()
	_build_orb_counters()
	_build_deck_indicator()
	_build_round_label()
	_build_lock_marker()


## Story 7-6 (R2, D2): the art inputs, handed over by the runner BEFORE add_child (the static-handoff
## precedent). `card_effects` maps a card id to `[normal effect id, pitch effect id]` (`&""` for an absent
## half); `icons` maps an effect id to its art. Static authored content, derived load-once runner-side --
## this root never reads `CardDatabase` (6-0 AC 3).
func set_effect_art(card_effects: Dictionary, icons: EffectIconSet) -> void:
	_card_effects = card_effects
	_icons = icons


## 7-6 POLISH 2 (P13): the card ids of THIS player's own deck (authored, load-once; handed over before add_child)
## -- what the slot reel spins through. Composition only: nothing about draw order or the next card.
func set_reel_cards(card_ids: Array) -> void:
	_reel_cards.clear()
	for id: Variant in card_ids:
		_reel_cards.append(StringName(id))
	_reel_rng.randomize()


## P13: is slot `index` spinning? The test-facing read.
func is_slot_reeling(index: int) -> bool:
	return _reeling[index]


# --- Signal-driven consumers (AC 4) -------------------------------------------------------
# Each is a runner-wired seam callback for THIS root's own slot only. Payload is
# (current, maximum); no per-frame recompute, no polling.

## Seam callback (connect_hero_hp_changed, primed on connect).
## Story 7-6 (R8, AC 30/AC 31): HP DISPLAYS ROUNDED UP, so a living hero never reads 0.
func on_hp_changed(current: float, maximum: float) -> void:
	_apply_bar(_hp_bar, _hp_value, current, maximum, hp_display_value(current))


## Seam callback (connect_stamina_changed, primed on connect).
func on_stamina_changed(current: float, maximum: float) -> void:
	_apply_bar(_stamina_bar, _stamina_value, current, maximum, int(roundf(current)))


## Seam callback (connect_mana_changed, primed on connect). LIVE from E1 (2-4/R13): moves on
## every confirmed melee hit, blocked hits included.
## Story 7-6 (R3, AC 14/AC 15): the reading is also REMEMBERED -- it is the one input of every card's lift and
## pitch brightness, re-evaluated here rather than polled.
## 7-6 review fix (operator ruling F5): the number shown is the FLOOR of the live mana, with the lift's own
## epsilon, so "2" is on screen exactly when a cost-2 card lifts (regen makes mana fractional every tick).
func on_mana_changed(current: float, maximum: float) -> void:
	_apply_bar(_mana_bar, _mana_value, current, maximum, mana_display_value(current))
	_mana = current
	_apply_affordability()


## Story 7-6 (R8, AC 30/AC 31): the HP number shown for a live reading -- the CEILING, so 0 < hp < 1 reads 1
## and only a dead hero (hp == 0) reads 0. A reading within float noise of a whole number shows that number,
## so 49.0000001 is not displayed as 50.
static func hp_display_value(current: float) -> int:
	if current <= 0.0:
		return 0
	var nearest := roundf(current)
	if absf(current - nearest) < 0.0001:
		return maxi(1, int(nearest))
	return int(ceilf(current))


## 7-6 review fix (F5): the mana number -- the floor, sharing `AFFORD_EPSILON` with the lift test.
static func mana_display_value(current: float) -> int:
	return maxi(0, int(floorf(current + AFFORD_EPSILON)))


## Seam callback (connect_orbs_changed, the runner's NINTH seam — story 5-4, AC 15/AC 18-20).
## PRIMED ON CONNECT with the resting (0,0,0). OWN SLOT ONLY, structurally (AC 19). NO POLLING (AC 20).
## Story 7-6 (R3, AC 16): the counts are also remembered for the pitch pips.
func on_orbs_changed(red: int, blue: int, green: int) -> void:
	var counts := [red, blue, green]
	for i in _orb_labels.size():
		_orb_labels[i].text = str(counts[i])
	_orbs = [red, blue, green]
	_apply_affordability()


## Seam callback (connect_cards_changed, the runner's EIGHTH seam — story 3-6, AC 2). Primed on
## connect with an empty hand: the deal lands at step 6 of the first advance(), one tick later.
##
## `hand_ids` is a COPY of this player's VISIBLE hand (a Boulder cover on top of its slot), in hand order;
## the two counts are this player's OWN deck and discard (`3-6/R7`). EVERY slot is written on every call.
## Story 4-B1 (AC 1): `pending_draw_owed` -- this player's OWN owed-slot indices (the in-flight look).
## Story 6-0 (AC 1-3): `card_colors` -- the runner's id -> colour map. Story 6-5b (AC 23): `card_prices`.
## Story 7-6 (R4, AC 20): `under_ids` -- the CARD layer beneath the covers (`Hand.to_array()`), read inline
## by the same wrapper, so a covered slot can show its card faintly under the Boulder. A slot is COVERED
## when its visible id differs from its card-layer id. Every new parameter is defaulted, so every
## pre-existing 3- to 6-arg call site keeps exercising its branch unchanged.
func on_cards_changed(
		hand_ids: Array, deck_count: int, _discard_count: int, pending_draw_owed: Array = [],
		card_colors: Dictionary = {}, card_prices: Dictionary = {}, under_ids: Array = []) -> void:
	_last_hand_ids = hand_ids.duplicate()
	_last_pending_draw_owed = pending_draw_owed.duplicate()
	_last_card_colors = card_colors
	_last_card_prices = card_prices
	_last_under_ids = under_ids.duplicate()
	_render_hand_row()
	_deck_label.text = "DECK %d" % deck_count


## Seam callback (connect_pitch_changed, the runner's TENTH seam — story 6-3b, AC 1/AC 3/AC 4/AC 6),
## `my_slot` BOUND at wiring. MATCH-LEVEL: this root receives BOTH players' zones; ONLY an own payload touches
## the ghost memory. Not primed: both zones start empty.
## Story 7-4 (AC 13): `fresh_orbs` -- a sorcery's sockets, `Enums.CardColor` -> orbs earned since staging
## capped at the price (`{}` for an instant or an empty zone) -- renders in whichever zone the payload is for,
## so both players see the same sockets.
func on_pitch_changed(slot: int, card_id: StringName, hand_slot: int, ready: bool,
		remaining_ticks: int, duration_ticks: int, fresh_orbs: Dictionary, my_slot: int) -> void:
	var own := slot == my_slot
	_render_pitch_zone(_own_pitch if own else _opponent_pitch, card_id, ready, remaining_ticks,
			duration_ticks, fresh_orbs)
	if own:
		# Review fix F2: remember the slot a CLEARING zone's card was staged from, for THIS drain only -- an
		# activation's resolution arrives in the same drain; a fizzle's never does, so the memory is dropped by a
		# deferred call once the drain is over and a later resolution cannot flash a stale slot.
		if card_id == PitchState.NO_CARD and _own_staged_card != PitchState.NO_CARD:
			_cleared_stage_slot = _own_staged_hand_slot
			_forget_cleared_stage.call_deferred()
		elif card_id != PitchState.NO_CARD:
			_cleared_stage_slot = -1
		_own_staged_card = card_id
		_own_staged_hand_slot = hand_slot
		_render_hand_row()


## Story 6-3b (AC 6) / 7-6: THE ONE hand-row render path, from the remembered hand payload and the own pitch
## memory. Five looks, in precedence order: a COVERED slot (the Boulder over its faint card, 7-6 R4); a real
## card; the in-flight `"..."`; the GHOST of the own staged card -- only for a slot EMPTY in the hand
## payload, NOT owed, and equal to the own staged hand slot; otherwise blank.
func _render_hand_row() -> void:
	var looks_before := _slot_looks.duplicate()
	for i in _own_card_panels.size():
		var label := _own_card_labels[i]
		var visible_id: StringName = _last_hand_ids[i] if i < _last_hand_ids.size() else Hand.EMPTY
		var under_id: StringName = _last_under_ids[i] if i < _last_under_ids.size() else visible_id
		_set_cover(i, &"")
		_slot_covered[i] = false
		if visible_id != Hand.EMPTY and under_id != visible_id:
			# R4: the Boulder on top, the covered card (if any) faint beneath it. The caption records the
			# VISIBLE id (the Boulder), as before 7-6.
			_set_caption(label, str(visible_id), false, Color.WHITE)
			_paint_face(i, under_id, UNDER_MODULATE, false)
			_set_cover(i, visible_id)
			_set_swatch_color(i, _last_card_colors.get(visible_id, null))
			_slot_covered[i] = true
			_slot_play_ids[i] = visible_id
			_slot_looks[i] = LOOK_COVERED
		elif visible_id != Hand.EMPTY:
			_set_caption(label, str(visible_id), false, Color.WHITE)
			_paint_face(i, visible_id, Color.WHITE)
			# 6-0 AC 1: a slot holding a real card id is tinted; the untinted states (EMPTY, permanent hole,
			# in-flight) never reach this branch -- none of the three has a card id to look colour up by.
			_set_swatch_color(i, _last_card_colors.get(visible_id, null))
			_slot_play_ids[i] = visible_id
			_slot_looks[i] = LOOK_CARD
		elif _last_pending_draw_owed.has(i):
			# P13: the in-flight glyph stays the slot's identity record; it is hidden while the reel spins there.
			_set_caption(label, IN_FLIGHT_CAPTION, not _reel_on(), Color.WHITE)
			_paint_face(i, Hand.EMPTY, Color.WHITE)
			_set_swatch_color(i, null)
			_slot_play_ids[i] = &""
			_slot_looks[i] = LOOK_IN_FLIGHT
		elif _own_staged_card != PitchState.NO_CARD and i == _own_staged_hand_slot:
			_set_caption(label, str(_own_staged_card), false, GHOST_MODULATE)
			_paint_face(i, _own_staged_card, GHOST_MODULATE)
			_set_swatch_color(i, _last_card_colors.get(_own_staged_card, null), GHOST_MODULATE)
			_slot_play_ids[i] = &""
			_slot_looks[i] = LOOK_GHOST
		else:
			_set_caption(label, "", false, Color.WHITE)
			_paint_face(i, Hand.EMPTY, Color.WHITE)
			_set_swatch_color(i, null)
			_slot_play_ids[i] = &""
			_slot_looks[i] = LOOK_BLANK
	_flash_played_slots(looks_before)
	_update_reels(looks_before)
	_apply_affordability()
	_apply_selection()


## Story 7-6 (R1): the caption's one write seat. It renders only for the in-flight glyph; otherwise it is the
## hidden identity record of the slot.
func _set_caption(label: Label, text: String, shown: bool, tint: Color) -> void:
	label.text = text
	label.visible = shown
	label.modulate = tint


## Story 7-6 (R1/R2, AC 5/AC 10/AC 11): paint both halves of slot `index` for card `id` (`Hand.EMPTY` clears
## them), through `tint` (white, the ghost, or the faint under-a-Boulder look). Only TEXTURES, TEXT, COLOURS
## and VISIBILITY are written -- never a rect -- so what a slot holds can never move its layout (AC 10).
##
## The art is looked up by EFFECT id (R2, AC 11): `_card_effects[id]` names which effect is this card's
## normal and which its pitch; `_icons` holds the art per effect. Re-pairing an effect in data moves its art
## with it. A card with no pitch half (Boulder) shows an empty pitch half -- the 6-5e AC 4a "shown by
## absence" posture.
##
## `with_costs` false paints the ARTS ONLY -- the card faint beneath a Boulder (R4): its costs and pips would sit
## under the Boulder's own slab and cost, so they are not drawn at all (AC 8 holds for the covered slot too).
func _paint_face(index: int, id: StringName, tint: Color, with_costs := true) -> void:
	var halves: Array = _own_card_halves[index]
	var arts: Array = _own_card_arts[index]
	var costs: Array = _own_card_costs[index]
	var pips: Array = _own_card_pips[index]
	_slot_face_ids[index] = id
	for half: Control in halves:
		half.modulate = tint
	_half_tints[index] = [tint, tint]
	var effects: Array = _card_effects.get(id, [&"", &""]) if id != Hand.EMPTY else [&"", &""]
	var row: Variant = _last_card_prices.get(id, null) if id != Hand.EMPTY else null
	var color: Variant = _last_card_colors.get(id, null) if id != Hand.EMPTY else null
	var has_pitch := false
	if row != null:
		var entry: Array = row as Array
		has_pitch = not (is_zero_approx(float(entry[2])) and (entry[3] as Dictionary).is_empty())
	for h in 2:
		var shown := id != Hand.EMPTY and (h == 0 or has_pitch)
		var effect_id: StringName = effects[h] if shown else &""
		(arts[h] as TextureRect).texture = _icon(effect_id)
		(_half_hues[index] as Array)[h] = color if shown else null
		_set_art_back(index, h, color if shown else null)
		var cost_label := costs[h] as Label
		if row == null or not shown or not with_costs:
			cost_label.text = ""
		else:
			cost_label.text = _mana_text(float((row as Array)[h * 2]))
	# Story 7-4 (AC 12): the hourglass marks a SORCERY's pitch half wherever that half is drawn with its costs
	# (a real card or the ghost), never on the faint card beneath a Boulder.
	_own_card_hourglasses[index].visible = row != null and has_pitch and with_costs and _is_sorcery(id)
	# The pitch pips: one per required orb, sorted by colour ordinal (an `orb_costs` iteration order is never a
	# contract, `card_cast_condition.gd`), so two identical hands render identically.
	var pip_colors: Array[int] = []
	if row != null and has_pitch and with_costs:
		var orb_costs: Dictionary = (row as Array)[3]
		var colors: Array = orb_costs.keys()
		colors.sort()
		for c: Variant in colors:
			for _n in int(orb_costs[c]):
				pip_colors.append(int(c))
	# `orb_rank`: this pip's 1-based place among the pips of ITS colour (F3's count-fill).
	var seen_of_color: Dictionary = {}
	for p in pips.size():
		var pip := pips[p] as Panel
		if p < pip_colors.size() and pip_colors[p] >= 0 and pip_colors[p] < ORB_COLORS.size():
			var pip_style := pip.get_theme_stylebox("panel") as StyleBoxFlat
			pip_style.bg_color = ORB_COLORS[pip_colors[p]]
			pip_style.border_color = ORB_COLORS[pip_colors[p]]
			seen_of_color[pip_colors[p]] = int(seen_of_color.get(pip_colors[p], 0)) + 1
			pip.set_meta(&"orb_color", pip_colors[p])
			pip.set_meta(&"orb_rank", seen_of_color[pip_colors[p]])
			pip.visible = true
		else:
			pip.set_meta(&"orb_color", -1)
			pip.set_meta(&"orb_rank", 1)
			pip.visible = false


## The art for one effect id, or null for none (an empty art slot).
func _icon(effect_id: StringName) -> Texture2D:
	if effect_id == &"" or _icons == null:
		return null
	return _icons.texture_for(effect_id)


## Story 7-6 (R1): one half's art backing -- the card's colour, darkened, or hidden for no card. `saturation` < 1
## is P2's desaturation of a half the player cannot pay for.
func _set_art_back(index: int, half: int, color: Variant, saturation := 1.0) -> void:
	var back := (_own_card_art_backs[index] as Array)[half] as Panel
	if color == null:
		back.visible = false
		return
	var hue := _card_hue(int(color))
	if saturation < 1.0:
		hue = Color.from_hsv(hue.h, hue.s * saturation, hue.v)
	var style := (_own_card_art_back_styles[index] as Array)[half] as StyleBoxFlat
	style.bg_color = hue.darkened(0.55)
	style.border_color = hue.darkened(0.2)
	back.visible = true


## A card colour ordinal as a hue: the orb palette for RED/BLUE/GREEN, the neutral grey for COLORLESS.
func _card_hue(color: int) -> Color:
	if color >= 0 and color < ORB_COLORS.size():
		return ORB_COLORS[color]
	return COLORLESS_SWATCH


## Story 7-6 (R4, AC 20): show (`id` set) or hide (`&""`) the Boulder cover on one slot -- its own art (the
## covering card's normal effect) and its normal cost, on a dark plate inside a grey frame.
func _set_cover(index: int, id: StringName) -> void:
	var cover := _own_card_covers[index]
	if id == &"":
		cover.visible = false
		return
	var effects: Array = _card_effects.get(id, [&"", &""])
	_own_card_cover_arts[index].texture = _icon(effects[0])
	var row: Variant = _last_card_prices.get(id, null)
	_own_card_cover_costs[index].text = _mana_text(float((row as Array)[0])) if row != null else ""
	_own_card_cover_frames[index].border_color = _card_hue(int(_last_card_colors.get(id, Enums.CardColor.COLORLESS)))
	cover.visible = true


## Story 7-6 (AC 14-16) / 7-6 POLISH (operator ruling P2): the affordability reads, re-evaluated from the
## remembered mana and orbs whenever either moves or the row re-renders. EACH HALF IS JUDGED ON ITS OWN MANA COST:
## payable = full colour plus its glowing `Rim`; not payable = dimmed (`UNAFFORDABLE_MODULATE`) and desaturated
## art backing. Only a slot holding a real card is judged (a ghost, in-flight or blank slot keeps its own look); a
## Boulder-covered slot judges the COVER by the Boulder's cost and leaves the faint card beneath alone. Pips FILL
## BY COUNT (review fix F3): the n-th pip of a colour is lit iff at least n orbs of that colour are held.
func _apply_affordability() -> void:
	for i in _own_card_panels.size():
		var looks_card := _slot_looks[i] == LOOK_CARD
		var row: Variant = _last_card_prices.get(_slot_face_ids[i], null) if looks_card else null
		for h in 2:
			var half := (_own_card_halves[i] as Array)[h] as Control
			var rim := (_own_card_rims[i] as Array)[h] as Control
			var hue: Variant = (_half_hues[i] as Array)[h]
			var tint: Color = (_half_tints[i] as Array)[h]
			if row == null or hue == null:
				rim.visible = false
				half.modulate = tint
				_set_art_back(i, h, hue)
				continue
			var payable := float((row as Array)[h * 2]) <= _mana + AFFORD_EPSILON
			rim.visible = payable
			half.modulate = tint if payable else tint * UNAFFORDABLE_MODULATE
			_set_art_back(i, h, hue, 1.0 if payable else UNAFFORDABLE_SATURATION)
		var cover := _own_card_covers[i]
		var cover_row: Variant = _last_card_prices.get(_slot_play_ids[i], null) if _slot_covered[i] else null
		cover.modulate = Color.WHITE if cover_row == null 				or float((cover_row as Array)[0]) <= _mana + AFFORD_EPSILON else UNAFFORDABLE_MODULATE
		# Story 7-4 (AC 14, `7-4/R12`): a SORCERY's pips are never lit from the bank -- banked orbs do not count
		# toward it, so they stay hollow rings whatever the bank holds. An instant's fill by count is unchanged.
		var sorcery := _is_sorcery(_slot_face_ids[i])
		for pip: Panel in _own_card_pips[i]:
			var c := int(pip.get_meta(&"orb_color", -1))
			var rank := int(pip.get_meta(&"orb_rank", 1))
			var held := not sorcery and c >= 0 and c < _orbs.size() and _orbs[c] >= rank
			# P7: full colour always; held = a filled circle, missing = a hollow ring.
			(pip.get_theme_stylebox("panel") as StyleBoxFlat).draw_center = held


## Story 7-6 (AC 14/AC 15) / P2: is half `half` (0 normal, 1 pitch) of slot `index` shown as PAYABLE -- full colour
## with its rim lit? The test-facing read, off the live nodes.
func is_half_affordable(index: int, half: int) -> bool:
	return ((_own_card_rims[index] as Array)[half] as Control).visible 			and ((_own_card_halves[index] as Array)[half] as Control).modulate == (_half_tints[index] as Array)[half]


## P3: how far slot `index` is lifted, in pixels (0 at rest) -- measured from its ARC rest height (P9). The
## test-facing read, off the live node.
func card_lift(index: int) -> float:
	return -_own_card_panels[index].position.y - _arc_raise(index)



## Story 7-6 (R5, AC 22): flash every slot a card was just PLAYED from by a mode ①-③ cast -- a slot that showed a
## card and now shows the in-flight look, which is exactly a cast vacating it with its replacement owed.
## A PITCH ACTIVATION is flashed from its own resolution instead (`on_card_effect_resolved`, review fix F2): the
## drain clears the zone before the owed-slot payload arrives, so the ghost never reaches the in-flight look.
## A BOULDER CLEAR is not a played card (operator ruling F1, `6-5f/R7`) and does not flash.
func _flash_played_slots(looks_before: Array) -> void:
	for i in _own_card_panels.size():
		if _slot_looks[i] == LOOK_IN_FLIGHT and int(looks_before[i]) == LOOK_CARD:
			_flash_slot(i)


## P13: is the reel switched on (the authored knob) and is there anything to spin?
func _reel_on() -> bool:
	return _icons != null and _icons.slot_reel_enabled and not _reel_cards.is_empty()


## P13: start the reel on every slot now waiting for its card, stop it everywhere else, and LAND (a small
## settle) on a slot whose card the payload just delivered. A permanently empty slot (no card owed) never spins.
func _update_reels(looks_before: Array) -> void:
	for i in _own_card_panels.size():
		var waiting := _slot_looks[i] == LOOK_IN_FLIGHT and _reel_on()
		if waiting and not _reeling[i]:
			_reeling[i] = true
			_own_card_reels[i].visible = true
			_reel_step(i)
			var spin := _restart_tween(_own_card_reels[i]).set_loops()
			spin.tween_interval(REEL_STEP_SECONDS)
			spin.tween_callback(_reel_step.bind(i))
		elif not waiting and _reeling[i]:
			_reeling[i] = false
			var running: Variant = _tweens.get(_own_card_reels[i].get_instance_id(), null)
			if running != null and (running as Tween).is_valid():
				(running as Tween).kill()
			_own_card_reels[i].visible = false
			if _slot_looks[i] == LOOK_CARD and int(looks_before[i]) == LOOK_IN_FLIGHT:
				_settle_card(i)


## P13: one reel step -- the next art (a random card of this player's deck, never the same twice running) slides
## in from above, so the reel reads as motion rather than a flicker.
func _reel_step(index: int) -> void:
	if _reel_cards.is_empty():
		return
	var id: StringName = _reel_cards[_reel_rng.randi_range(0, _reel_cards.size() - 1)]
	if id == _reel_last[index] and _reel_cards.size() > 1:
		id = _reel_cards[(_reel_cards.find(id) + 1) % _reel_cards.size()]
	_reel_last[index] = id
	var art := _own_card_reel_arts[index]
	var effects: Array = _card_effects.get(id, [&"", &""])
	art.texture = _icon(effects[0])
	var rest_y := (CARD_SIZE.y - REEL_ART_SIZE) * 0.5
	art.position.y = rest_y - REEL_SLIDE_PX
	var slide := _restart_tween(art)
	slide.tween_property(art, "position:y", rest_y, REEL_STEP_SECONDS * 0.8) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## P13: the landing settle -- the delivered card pops a touch large and eases back (scale only, never a rect).
func _settle_card(index: int) -> void:
	var card := _own_card_panels[index]
	card.pivot_offset = CARD_SIZE * 0.5
	card.scale = Vector2.ONE * REEL_SETTLE_SCALE
	var tween := _restart_tween(card)
	tween.tween_property(card, "scale", Vector2.ONE, REEL_SETTLE_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash_slot(index: int) -> void:
	var flash := _own_card_flashes[index]
	flash.modulate = Color(1.0, 1.0, 1.0, PLAY_FLASH_ALPHA)
	flash.visible = true
	var tween := _restart_tween(flash)
	# P4: hold at full strength, then fade -- `PLAY_FLASH_SECONDS` in total.
	tween.tween_interval(PLAY_FLASH_HOLD_SECONDS)
	tween.tween_property(flash, "modulate:a", 0.0, PLAY_FLASH_SECONDS - PLAY_FLASH_HOLD_SECONDS)
	tween.tween_callback(flash.hide)


func _forget_cleared_stage() -> void:
	_cleared_stage_slot = -1


## Review fix (m5): one tween per node -- a restart kills the running one, so its tail (a `hide`, a scale-back)
## can never cut the new animation short.
func _restart_tween(node: Node) -> Tween:
	var running: Variant = _tweens.get(node.get_instance_id(), null)
	if running != null and (running as Tween).is_valid():
		(running as Tween).kill()
	var tween := node.create_tween()
	_tweens[node.get_instance_id()] = tween
	return tween


## An authored mana cost as text. WHOLE NUMBERS LOSE THEIR DECIMAL; a retuned fractional price renders to
## one place.
func _mana_text(mana: float) -> String:
	return str(int(round(mana))) if is_equal_approx(mana, round(mana)) else "%.1f" % mana


## Story 6-3b (AC 4): one zone's three facts. An empty zone (`NO_CARD`) renders blank: no caption, an
## empty bar, no READY. The bar is the countdown as `remaining / duration`; it moves only when a payload
## arrives (on the authored throttle, AC 5), never per frame.
func _render_pitch_zone(zone: Panel, card_id: StringName, ready: bool, remaining_ticks: int,
		duration_ticks: int, fresh_orbs: Dictionary = {}) -> void:
	var staged := card_id != PitchState.NO_CARD
	var caption: Label = zone.get_node("Card")
	var art: TextureRect = zone.get_node("Art")
	var bar: ProgressBar = zone.get_node("Countdown")
	var ready_label: Label = zone.get_node("Ready")
	# Review fix (operator ruling F4): the zone SHOWS the staged card's PITCH effect art, no words. The caption is
	# kept, hidden, as the zone's identity record (the 7-6 R1 hand-caption precedent) -- what the live tests read.
	caption.text = str(card_id) if staged else ""
	var effects: Array = _card_effects.get(card_id, [&"", &""]) if staged else [&"", &""]
	art.texture = _icon(effects[1])
	bar.max_value = maxi(1, duration_ticks)
	bar.value = remaining_ticks if staged else 0
	ready_label.visible = staged and ready
	# Story 7-4 (AC 12/AC 13): a SORCERY carries the hourglass and one socket per required orb, sorted by colour
	# ordinal; the n-th socket of a colour is filled iff at least n orbs of that colour were EARNED since staging
	# (the payload's count -- never the bank, so a socket is empty at staging whatever the bank holds). Speed is
	# read through the static price derive, the hand pips' source, so both zones mark the same card the same way.
	var sorcery := staged and _is_sorcery(card_id)
	(zone.get_node("Hourglass") as Control).visible = sorcery
	var socket_colors: Array[int] = []
	var row: Variant = _last_card_prices.get(card_id, null) if sorcery else null
	if row != null and (row as Array).size() > 3:
		var orb_costs: Dictionary = (row as Array)[3]
		var colors: Array = orb_costs.keys()
		colors.sort()
		for c: Variant in colors:
			for _n in int(orb_costs[c]):
				socket_colors.append(int(c))
	var seen_of_color: Dictionary = {}
	var sockets_row := zone.get_node("Sockets") as Control
	# 7-4 SMOKE FIX, ROUND 2: READY and the socket row share the band below the bar. Where their rects overlap, the row
	# hides while READY shows -- READY means every socket is filled, so nothing is lost.
	var hide_for_ready := ready_label.visible and ready_label.get_rect().intersects(sockets_row.get_rect())
	for socket: Panel in sockets_row.get_children():
		var s := socket.get_index()
		if s < socket_colors.size() and socket_colors[s] >= 0 and socket_colors[s] < ORB_COLORS.size():
			var c := socket_colors[s]
			seen_of_color[c] = int(seen_of_color.get(c, 0)) + 1
			var style := socket.get_theme_stylebox("panel") as StyleBoxFlat
			style.bg_color = ORB_COLORS[c]
			style.border_color = ORB_COLORS[c]
			style.draw_center = int(fresh_orbs.get(c, 0)) >= int(seen_of_color[c])
			socket.visible = not hide_for_ready
		else:
			socket.visible = false


## Story 7-4 (AC 12/AC 14, `7-4/R12`): is `id` a SORCERY? Read off the static price row's fifth element (the
## runner's `_derive_card_prices`); a row without one -- an older four-element fixture -- reads instant, as does
## an unknown id.
func _is_sorcery(id: StringName) -> bool:
	var row: Variant = _last_card_prices.get(id, null)
	if row == null or (row as Array).size() < 5:
		return false
	return int((row as Array)[4]) == Enums.PitchSpeed.SORCERY


## Story 7-4 (AC 12): the PLACEHOLDER hourglass marker -- two amber triangles meeting at a waist, drawn with
## `Polygon2D`s inside a small Control (no font glyph to depend on). Built hidden; a sorcery shows it.
func _make_hourglass(node_name: String, at: Vector2) -> Control:
	var glass := Control.new()
	glass.name = node_name
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.position = at
	glass.size = HOURGLASS_SIZE
	var w := HOURGLASS_SIZE.x
	var h := HOURGLASS_SIZE.y
	for points: PackedVector2Array in [PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w * 0.5, h * 0.5)]),
			PackedVector2Array([Vector2(w * 0.5, h * 0.5), Vector2(w, h), Vector2(0, h)])]:
		var tri := Polygon2D.new()
		tri.polygon = points
		tri.color = HOURGLASS_COLOR
		glass.add_child(tri)
	glass.visible = false
	return glass


## Story 6-0 (AC 1): the single write seat for the colour frame. `color` is an `Enums.CardColor` or `null`
## (no colour found / no card in the slot) -- `null` hides the frame rather than guessing a colour.
## Story 6-3b (AC 6): `tint_modulate` dims it for the ghost look.
## Story 6-5e (AC 4a): COLOURLESS renders the neutral grey, never an index past the orb palette.
func _set_swatch_color(index: int, color: Variant, tint_modulate := Color.WHITE) -> void:
	if index >= _own_card_swatches.size():
		return
	var swatch := _own_card_swatches[index]
	swatch.modulate = tint_modulate
	if color == null:
		swatch.visible = false
		_frame_hues[index] = null
		return
	var hue := COLORLESS_SWATCH if int(color) == Enums.CardColor.COLORLESS else ORB_COLORS[color as int]
	_frame_hues[index] = hue
	_paint_frame(index)
	swatch.visible = true


## P14: the card's ONE frame -- its own colour, or gold with a soft glow while the slot is armed.
func _paint_frame(index: int) -> void:
	var style := _own_card_swatch_styles[index]
	var armed := _slot_armed[index]
	var hue: Variant = _frame_hues[index]
	style.border_color = ARMED_FRAME_COLOR if armed else (hue if hue != null else COLORLESS_SWATCH)
	# The 6-0 colour RECORD stays the card's hue even while armed: the frame draws no centre, so `bg_color` is never
	# drawn -- only the BORDER turns gold (P14), and the card's colour identity is not lost by arming.
	style.bg_color = hue if hue != null else COLORLESS_SWATCH
	style.shadow_size = ARMED_GLOW_PX if armed else 0
	style.shadow_color = Color(ARMED_FRAME_COLOR.r, ARMED_FRAME_COLOR.g, ARMED_FRAME_COLOR.b, 0.6)


## EventBus.reshuffle_vulnerable_window_opened (slot bound at wiring, the on_round_ended shape —
## story 3-6, AC 4). BOTH viewports receive EVERY reshuffle: the event is ownerless and the fact
## is public (E3-RG/R3), so each root renders it against its own slot. The flag turns itself off through
## a ONE-SHOT SceneTreeTimer seeded by the authored duration; the token guards the overlapping case.
func on_reshuffle_vulnerable_window_opened(slot: int, my_slot: int) -> void:
	if reshuffle_vulnerable_window_seconds <= 0.0:
		return
	_reshuffle_token += 1
	var token := _reshuffle_token
	_reshuffle_label.text = "RESHUFFLE" if slot == my_slot else "OPP RESH"
	_reshuffle_label.visible = true
	# Review finding (3-6): the SceneTreeTimer outlives this HudRoot across a scene teardown
	# mid-window — is_instance_valid guards the freed case.
	var on_timeout := func() -> void:
		if is_instance_valid(self):
			_clear_reshuffle_flag(token)
	get_tree().create_timer(reshuffle_vulnerable_window_seconds).timeout.connect(on_timeout)


## Hides the flag IF the expiring timer is the one that raised the flag currently showing.
func _clear_reshuffle_flag(token: int) -> void:
	if token == _reshuffle_token:
		_reshuffle_label.visible = false


## Story 7-6 (D1, R6, AC 23-25): EventBus.card_effect_resolved, `my_slot` bound at wiring (the on_round_ended
## shape). BOTH roots receive EVERY resolution -- played effects are public -- and each renders it against its
## own slot: own entries flush on the outer edge, the opponent's indented and crimson-rimmed, and a NEW
## opponent entry pops in. The strip keeps the newest `HISTORY_SIZE`, newest on top.
func on_card_effect_resolved(slot: int, effect_id: StringName, is_pitch: bool, my_slot: int) -> void:
	_history_my_slot = my_slot
	_history.push_front({"slot": slot, "effect_id": effect_id, "is_pitch": is_pitch, "countered": false})
	if _history.size() > HISTORY_SIZE:
		_history.resize(HISTORY_SIZE)
	_render_history()
	if slot != my_slot:
		if not _history_entries.is_empty():
			_pop_history_entry(_history_entries[0])
		return
	# Review fix (m5): an own entry landing on Entry0 cancels any opponent pop still running there, so it never
	# inherits that pop.
	if not _history_entries.is_empty():
		_settle_history_entry(_history_entries[0])
	# Review fix F2: an own PITCH resolution is an activation -- flash the slot its card was staged from. A fizzle
	# queues no resolution, so it never reaches here.
	if is_pitch and _cleared_stage_slot >= 0 and _cleared_stage_slot < _own_card_flashes.size():
		_flash_slot(_cleared_stage_slot)
	_cleared_stage_slot = -1


## Story 7-6 (D1, R6): EventBus.card_effect_countered -- `slot`'s newest entry is struck through. Exact since the
## review fix F1: Boulder clears never enter the strip, so a player's newest entry is always their resolved-card
## record -- the card the counter reversed. If that card already left the strip, no entry of that slot is
## left either (every other entry of theirs is older), and nothing is struck.
func on_card_effect_countered(slot: int, my_slot: int) -> void:
	_history_my_slot = my_slot
	for entry: Dictionary in _history:
		if int(entry["slot"]) == slot:
			entry["countered"] = true
			break
	_render_history()


## The history as `[slot, effect_id, is_pitch, countered]` rows, newest first -- the test-facing read.
func history_rows() -> Array:
	var out: Array = []
	for entry: Dictionary in _history:
		out.append([entry["slot"], entry["effect_id"], entry["is_pitch"], entry["countered"]])
	return out


## The colour of the card carrying `effect_id` (the first in id order), or null if no known card carries it.
func _effect_color(effect_id: StringName) -> Variant:
	var ids: Array = _card_effects.keys()
	ids.sort()
	for id: Variant in ids:
		if (_card_effects[id] as Array).has(effect_id):
			return _last_card_colors.get(id, null)
	return null


func _render_history() -> void:
	if _history_strip == null:
		return
	for k in _history_entries.size():
		var entry_node := _history_entries[k]
		if k >= _history.size():
			entry_node.visible = false
			continue
		var entry: Dictionary = _history[k]
		var own := int(entry["slot"]) == _history_my_slot
		var indent := 0.0 if own else HISTORY_OPPONENT_INDENT
		var x := indent if history_on_left else HISTORY_WIDTH - HISTORY_ENTRY_PX - indent
		entry_node.position = Vector2(x, k * (HISTORY_ENTRY_PX + HISTORY_GAP))
		var style := entry_node.get_theme_stylebox("panel") as StyleBoxFlat
		style.border_color = HISTORY_OWN_RIM if own else HISTORY_OPPONENT_RIM
		var color: Variant = _effect_color(entry["effect_id"])
		style.bg_color = (_card_hue(int(color)) if color != null else COLORLESS_SWATCH).darkened(0.6)
		(entry_node.get_node("Icon") as TextureRect).texture = _icon(entry["effect_id"])
		(entry_node.get_node("PitchMark") as Control).visible = bool(entry["is_pitch"])
		(entry_node.get_node("Strike") as CanvasItem).visible = bool(entry["countered"])
		entry_node.set_meta(&"own", own)
		entry_node.visible = true


func _pop_history_entry(entry_node: Control) -> void:
	entry_node.pivot_offset = entry_node.size * 0.5
	entry_node.scale = Vector2.ONE * HISTORY_POP_SCALE
	entry_node.self_modulate = Color(2.0, 2.0, 2.0)
	var tween := _restart_tween(entry_node).set_parallel()
	tween.tween_property(entry_node, "scale", Vector2.ONE, HISTORY_POP_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(entry_node, "self_modulate", Color.WHITE, HISTORY_POP_SECONDS)


## Review fix (m5): put an entry node at rest -- any running pop killed, scale and brightness reset.
func _settle_history_entry(entry_node: Control) -> void:
	var running: Variant = _tweens.get(entry_node.get_instance_id(), null)
	if running != null and (running as Tween).is_valid():
		(running as Tween).kill()
	entry_node.scale = Vector2.ONE
	entry_node.self_modulate = Color.WHITE


## EventBus.round_ended (slot bound at wiring, mirroring TelegraphController). Minimal
## per-viewport round-over label. 2-4/R5: the 2-3/R10 named gap is visible here — the label
## reads while the surviving hero keeps moving; that is PRE-KNOWN, not owned by this story.
func on_round_ended(loser_index: int, my_slot: int) -> void:
	_round_label.text = "YOU WIN" if loser_index != my_slot else "YOU LOSE"
	_round_label.visible = true


## EventBus.round_started (story 2-6, AC 1, 2-6/R5): the single CLEAR seat for the round-over
## label — a debug reset hides it. No-argument and slot-independent. Story 7-6: a reset also clears the play
## history -- a new round's strip starts empty.
func on_round_started() -> void:
	_round_label.visible = false
	_history.clear()
	_render_history()


func _apply_bar(bar: ProgressBar, value_label: Label, current: float, maximum: float, shown: int) -> void:
	bar.max_value = maximum
	bar.value = current
	value_label.text = "%d/%d" % [shown, int(roundf(maximum))]


# --- Construction -------------------------------------------------------------------------

## HP / stamina / mana bars. 7-6 POLISH 2 (operator ruling P9): stacked beneath the arc's raised middle pair
## (`VITALS_OFFSETS`, the pair's full width), no caption labels -- colour names each bar -- and each bar keeps its
## numeric value. Rows 18 px, values 54 px wide.
func _build_vitals() -> void:
	var column := VBoxContainer.new()
	column.name = "Vitals"
	# P9: stacked under the arc's raised middle pair, bottom-centre.
	column.anchor_left = 0.5
	column.anchor_right = 0.5
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = VITALS_OFFSETS[0]
	column.offset_top = VITALS_OFFSETS[1]
	column.offset_right = VITALS_OFFSETS[2]
	column.offset_bottom = VITALS_OFFSETS[3]
	column.add_theme_constant_override("separation", 2)
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


## Returns [bar, value_label, row_control]. The bar is constructed EMPTY and WITHOUT a real maximum
## (value 0, max 1): the real (current, maximum) arrives ONLY through the seam's prime-on-connect call
## (2-4/R2), so nothing in this presentation layer duplicates an authored balance value (D2).
func _make_bar_row(caption: String, fill: Color) -> Array:
	var row := HBoxContainer.new()
	row.name = "%sRow" % caption
	row.custom_minimum_size = Vector2(0.0, VITALS_BAR_PX)
	row.add_theme_constant_override("separation", 4)
	# 7-6 POLISH 2 (P9): NO caption label -- the bar's colour names it; the numeric value stays.
	var bar := ProgressBar.new()
	bar.name = "%sBar" % caption
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = 0.0
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0.0, VITALS_BAR_PX)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	bar.add_theme_stylebox_override("fill", fill_style)
	row.add_child(bar)
	# 7-6 POLISH 4 (operator ruling P19, 2026-10-06; supersedes P18's plate): the number sits INSIDE the bar near its
	# RIGHT end, white and bold with a thick dark outline and NO background -- readable over both the filled and the
	# empty part.
	var value_label := Label.new()
	value_label.name = "%sValue" % caption
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.anchor_left = 1.0
	value_label.anchor_right = 1.0
	value_label.anchor_top = 0.5
	value_label.anchor_bottom = 0.5
	value_label.grow_vertical = Control.GROW_DIRECTION_BOTH  # its line box (taller than the bar) stays centred on it
	value_label.offset_left = -VITALS_VALUE_WIDTH - VITALS_VALUE_INSET
	value_label.offset_right = -VITALS_VALUE_INSET
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	value_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	value_label.add_theme_constant_override("outline_size", VITALS_VALUE_OUTLINE)
	var bold := SystemFont.new()
	bold.font_weight = 700
	value_label.add_theme_font_override("font", bold)
	bar.add_child(value_label)
	return [bar, value_label, row]


## Story 6-3b (AC 4): one pitch zone, a bordered panel at `offsets` ([left, top, right, bottom], bottom-centre --
## 7-6 POLISH 2 P9: beside the hand) holding three children, the same in the own and the opponent zone: `Card`, the
## staged id caption; `Countdown`, a bar; and `Ready`, hidden until a payload says READY. Built EMPTY. The
## bar shows no percentage: no number of any kind appears in a zone. Story 7-6: 76 x 118, beside the hand.
## 7-6 review fix F4: a fourth child, `Art` (the staged card's pitch effect), renders where the caption did; the
## caption stays as a HIDDEN identity record.
func _build_pitch_zone(node_name: String, anchor_x: float, offsets: Array) -> Panel:
	var zone := Panel.new()
	zone.name = node_name
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 7-6 POLISH 3 (P15): card-sized, midway between the hand and the half's edge (anchor 0.25 / 0.75).
	zone.anchor_left = anchor_x
	zone.anchor_right = anchor_x
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
	caption.offset_top = 8.0
	caption.offset_bottom = 108.0
	caption.visible = false  # review fix F4: the identity record only; the art below is what renders
	zone.add_child(caption)
	# Review fix F4: the staged card's PITCH effect art, a square in the band the caption used to fill.
	var art := TextureRect.new()
	art.name = "Art"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = PITCH_ZONE_ART_RECT.position
	art.size = PITCH_ZONE_ART_RECT.size
	art.self_modulate = Color(0.96, 0.92, 0.82)
	zone.add_child(art)
	var bar := ProgressBar.new()
	bar.name = "Countdown"
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = 0.0
	bar.anchor_right = 1.0
	bar.offset_left = 12.0
	bar.offset_right = -12.0
	bar.offset_top = 114.0
	bar.offset_bottom = 126.0
	zone.add_child(bar)
	var ready_label := Label.new()
	ready_label.name = "Ready"
	ready_label.text = "READY"
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.add_theme_font_size_override("font_size", 18)
	ready_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.30))
	ready_label.anchor_right = 1.0
	ready_label.offset_top = 128.0
	ready_label.offset_bottom = 154.0
	ready_label.visible = false
	zone.add_child(ready_label)
	# Story 7-4 (AC 12/AC 13): the sorcery marker and the socket row, both hidden until a sorcery is staged.
	zone.add_child(_make_hourglass("Hourglass", ZONE_HOURGLASS_POS))
	var sockets := Control.new()
	sockets.name = "Sockets"
	sockets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 7-4 SMOKE FIX, ROUNDS 2-3: the row sits in the band below the countdown bar, its left edge flush with the bar's,
	# vertically centred in the band. Each socket is one coloured ring (the `Socket%d` Panel whose stylebox
	# `_render_pitch_zone` fills), `ZONE_SOCKET_RING_PX` thick while empty.
	var row_width := MAX_PIPS * ZONE_SOCKET_SIZE + (MAX_PIPS - 1) * ZONE_SOCKET_GAP
	sockets.position = Vector2(bar.offset_left,
			ZONE_SOCKET_BAND_TOP + (ZONE_SOCKET_BAND_BOTTOM - ZONE_SOCKET_BAND_TOP - ZONE_SOCKET_SIZE) * 0.5)
	sockets.size = Vector2(row_width, ZONE_SOCKET_SIZE)
	zone.add_child(sockets)
	for s in MAX_PIPS:
		var socket := Panel.new()
		socket.name = "Socket%d" % s
		socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		socket.size = Vector2(ZONE_SOCKET_SIZE, ZONE_SOCKET_SIZE)
		socket.position = Vector2(s * (ZONE_SOCKET_SIZE + ZONE_SOCKET_GAP), 0.0)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(int(ZONE_SOCKET_SIZE * 0.5))
		style.set_border_width_all(ZONE_SOCKET_RING_PX)
		style.draw_center = false
		socket.add_theme_stylebox_override("panel", style)
		socket.visible = false
		sockets.add_child(socket)
	return zone


## The OWN hand row — the bottom-centre own-tempo action surface. 7-6 POLISH (P1): four `CARD_SIZE` (128 x 158)
## cards, `CARD_GAP` apart = 536, in a strip at -268..268, bottom -8, top -166 -- the band below the debug box is the
## hand's alone. A card lifts only for card mode / arming (P3, `_apply_selection`): the armed card's top plus its
## frame stays at y >= 454. The strip is a plain Control -- built ONCE (2-5/R6). The rendered count stays the
## presentation-local constant 4 (2-5/R1).
func _build_hand_row() -> void:
	var strip := Control.new()
	strip.name = "HandStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.anchor_left = 0.5
	strip.anchor_right = 0.5
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	var width := 4.0 * CARD_SIZE.x + 3.0 * CARD_GAP
	strip.offset_left = -width * 0.5
	strip.offset_right = width * 0.5
	strip.offset_top = -HAND_BOTTOM_PX - CARD_SIZE.y
	strip.offset_bottom = -HAND_BOTTOM_PX
	_hand_strip = strip
	add_child(strip)
	_card_base_style = _make_card_face_style(true)
	for i in 4:
		_build_card(strip, i)


## One card panel and its fixed children (R1). Every rect is set here and nowhere else (AC 10).
func _build_card(strip: Control, i: int) -> void:
	var card := Panel.new()
	card.name = "Card%d" % i
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = CARD_SIZE
	card.custom_minimum_size = CARD_SIZE
	card.position = Vector2(i * (CARD_SIZE.x + CARD_GAP), -_arc_raise(i))
	card.add_theme_stylebox_override("panel", _card_base_style)
	strip.add_child(card)
	var halves: Array = []
	var arts: Array = []
	var backs: Array = []
	var back_styles: Array = []
	var costs: Array = []
	var pips: Array = []
	var rims: Array = []
	for h in 2:
		var half := Control.new()
		half.name = "NormalHalf" if h == 0 else "PitchHalf"
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		half.position = Vector2(CARD_FRAME_PX, CARD_FRAME_PX + h * (HALF_SIZE.y + DIVIDER_PX))
		half.size = HALF_SIZE
		card.add_child(half)
		halves.append(half)
		var back := Panel.new()
		back.name = "ArtBack"
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.position = ART_BACK_RECT.position
		back.size = ART_BACK_RECT.size
		var back_style := StyleBoxFlat.new()
		back_style.set_corner_radius_all(3)
		back_style.set_border_width_all(1)
		back.add_theme_stylebox_override("panel", back_style)
		back.visible = false
		half.add_child(back)
		backs.append(back)
		back_styles.append(back_style)
		var art := TextureRect.new()
		art.name = "Art"
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.position = ART_RECT.position
		art.size = ART_RECT.size
		art.self_modulate = Color(0.96, 0.92, 0.82)  # bone-white silhouette on the coloured backing
		half.add_child(art)
		arts.append(art)
		var cost := Label.new()
		cost.name = "Cost"
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cost_rect := NORMAL_COST_RECT if h == 0 else PITCH_COST_RECT
		cost.position = cost_rect.position
		cost.size = cost_rect.size
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost.clip_text = true
		# P1: the SOLID BADGE -- the label draws its own dark plate and rim behind a large high-contrast number.
		cost.add_theme_stylebox_override("normal", _make_cost_badge())
		cost.add_theme_font_size_override("font_size", COST_FONT_NORMAL if h == 0 else COST_FONT_PITCH)
		cost.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		cost.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
		cost.add_theme_constant_override("outline_size", 3)
		half.add_child(cost)
		costs.append(cost)
		# P2: the glowing affordability rim -- a thin border round the half, glowing outward; shown while payable.
		var rim := Panel.new()
		rim.name = "Rim"
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rim.position = Vector2.ZERO
		rim.size = HALF_SIZE
		var rim_style := StyleBoxFlat.new()
		rim_style.draw_center = false
		rim_style.set_border_width_all(AFFORD_RIM_PX)
		rim_style.set_corner_radius_all(3)
		rim_style.border_color = Color(1.0, 0.93, 0.66, 0.95)
		rim_style.shadow_color = Color(1.0, 0.86, 0.45, 0.55)
		rim_style.shadow_size = AFFORD_GLOW_PX
		rim.add_theme_stylebox_override("panel", rim_style)
		rim.visible = false
		half.add_child(rim)
		rims.append(rim)
		if h == 1:
			# Story 7-4 (AC 12): the sorcery marker on the pitch half, over the art's top-left corner.
			var glass := _make_hourglass("Hourglass", HAND_HOURGLASS_POS)
			half.add_child(glass)
			_own_card_hourglasses.append(glass)
			var pip_row := Control.new()
			pip_row.name = "Pips"
			pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pip_row.position = PIPS_RECT.position
			pip_row.size = PIPS_RECT.size
			half.add_child(pip_row)
			var row_width := MAX_PIPS * PIP_SIZE + (MAX_PIPS - 1) * PIP_GAP
			for p in MAX_PIPS:
				var pip := Panel.new()
				pip.name = "Pip%d" % p
				pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
				pip.size = Vector2(PIP_SIZE, PIP_SIZE)
				pip.position = Vector2((PIPS_RECT.size.x - row_width) * 0.5 + p * (PIP_SIZE + PIP_GAP),
						(PIPS_RECT.size.y - PIP_SIZE) * 0.5)
				var pip_style := StyleBoxFlat.new()
				pip_style.set_corner_radius_all(int(PIP_SIZE * 0.5))
				pip_style.set_border_width_all(PIP_RING_PX)  # P7: the hollow ring's outline
				pip.add_theme_stylebox_override("panel", pip_style)
				pip.set_meta(&"orb_color", -1)
				pip.visible = false
				pip_row.add_child(pip)
				pips.append(pip)
	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.color = Color(0.80, 0.74, 0.60)
	divider.position = Vector2(CARD_FRAME_PX, CARD_FRAME_PX + HALF_SIZE.y)
	divider.size = Vector2(HALF_SIZE.x, DIVIDER_PX)
	card.add_child(divider)
	# R1 / AC 7: the reserved keyword slot -- an EMPTY node, top-right, rendering nothing today.
	var keyword := Control.new()
	keyword.name = "KeywordSlot"
	keyword.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keyword.position = KEYWORD_SLOT_RECT.position
	keyword.size = KEYWORD_SLOT_RECT.size
	card.add_child(keyword)
	# 6-0 / 7-6: the colour FRAME (border only, no centre), hidden until a real card is in the slot.
	var swatch := Panel.new()
	swatch.name = "ColorSwatch"
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.position = Vector2.ZERO
	swatch.size = CARD_SIZE
	var swatch_style := StyleBoxFlat.new()
	swatch_style.draw_center = false
	swatch_style.set_corner_radius_all(4)
	swatch_style.set_border_width_all(CARD_FRAME_PX)
	swatch.add_theme_stylebox_override("panel", swatch_style)
	swatch.visible = false
	card.add_child(swatch)
	# R4: the Boulder cover, hidden until a slot is covered.
	var cover := Panel.new()
	cover.name = "BoulderCover"
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.position = BOULDER_COVER_RECT.position
	cover.size = BOULDER_COVER_RECT.size
	var cover_style := StyleBoxFlat.new()
	cover_style.bg_color = Color(0.17, 0.16, 0.16)
	cover_style.set_border_width_all(CARD_FRAME_PX)
	cover_style.border_color = COLORLESS_SWATCH
	cover_style.set_corner_radius_all(4)
	cover.add_theme_stylebox_override("panel", cover_style)
	cover.visible = false
	card.add_child(cover)
	var cover_back := Panel.new()
	cover_back.name = "ArtBack"
	cover_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_back.position = BOULDER_ART_BACK_RECT.position
	cover_back.size = BOULDER_ART_BACK_RECT.size
	var cover_back_style := StyleBoxFlat.new()
	cover_back_style.bg_color = COLORLESS_SWATCH.darkened(0.55)
	cover_back_style.set_corner_radius_all(3)
	cover_back.add_theme_stylebox_override("panel", cover_back_style)
	cover.add_child(cover_back)
	var cover_art := TextureRect.new()
	cover_art.name = "Art"
	cover_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover_art.position = BOULDER_ART_RECT.position
	cover_art.size = BOULDER_ART_RECT.size
	cover_art.self_modulate = Color(0.96, 0.92, 0.82)
	cover.add_child(cover_art)
	var cover_cost := Label.new()
	cover_cost.name = "Cost"
	cover_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_cost.position = BOULDER_COST_RECT.position
	cover_cost.size = BOULDER_COST_RECT.size
	cover_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cover_cost.add_theme_stylebox_override("normal", _make_cost_badge())
	cover_cost.add_theme_font_size_override("font_size", COST_FONT_NORMAL)
	cover_cost.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	cover_cost.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	cover_cost.add_theme_constant_override("outline_size", 3)
	cover.add_child(cover_cost)
	# 3-6 / 4-B1: the caption -- renders only the in-flight glyph (see `_own_card_labels`).
	var caption := Label.new()
	caption.name = "CardName"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.clip_text = true
	caption.add_theme_font_size_override("font_size", 30)
	caption.add_theme_color_override("font_color", Color(0.80, 0.76, 0.66))
	caption.position = Vector2.ZERO
	caption.size = CARD_SIZE
	caption.visible = false
	card.add_child(caption)
	# R5: the own-play flash.
	var flash := Panel.new()
	flash.name = "PlayFlash"
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.position = Vector2.ZERO
	flash.size = CARD_SIZE
	var flash_style := StyleBoxFlat.new()
	flash_style.bg_color = Color(1.0, 0.97, 0.86)
	flash_style.set_corner_radius_all(4)
	# P4: a glow outside the card as well, so the flash reaches peripheral vision.
	flash_style.shadow_color = Color(1.0, 0.92, 0.6, 0.85)
	flash_style.shadow_size = PLAY_FLASH_GLOW_PX
	flash.add_theme_stylebox_override("panel", flash_style)
	flash.visible = false
	card.add_child(flash)
	_own_card_panels.append(card)
	_own_card_labels.append(caption)
	_own_card_swatches.append(swatch)
	_own_card_swatch_styles.append(swatch_style)
	_own_card_halves.append(halves)
	_own_card_arts.append(arts)
	_own_card_art_backs.append(backs)
	_own_card_art_back_styles.append(back_styles)
	_own_card_costs.append(costs)
	_own_card_pips.append(pips)
	_own_card_rims.append(rims)
	_own_card_flashes.append(flash)
	# P13: the reel overlay -- clipped to the card's inner area, hidden until the slot waits for a card.
	var reel := Control.new()
	reel.name = "Reel"
	reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel.clip_contents = true
	reel.position = Vector2.ZERO
	reel.size = CARD_SIZE
	reel.visible = false
	card.add_child(reel)
	card.move_child(reel, flash.get_index())
	var reel_art := TextureRect.new()
	reel_art.name = "ReelArt"
	reel_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reel_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reel_art.size = Vector2(REEL_ART_SIZE, REEL_ART_SIZE)
	reel_art.position = (CARD_SIZE - reel_art.size) * 0.5
	reel_art.self_modulate = Color(0.96, 0.92, 0.82, 0.8)
	reel.add_child(reel_art)
	_own_card_reels.append(reel)
	_own_card_reel_arts.append(reel_art)
	_own_card_covers.append(cover)
	_own_card_cover_arts.append(cover_art)
	_own_card_cover_costs.append(cover_cost)
	_own_card_cover_frames.append(cover_style)


## P1: a cost badge's plate -- solid, dark, rimmed, so the number reads against any art or colour behind it.
func _make_cost_badge() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = COST_BADGE_BG
	box.border_color = COST_BADGE_RIM
	box.set_border_width_all(2)
	box.set_corner_radius_all(7)
	return box


## The SINGLE SEAT of the face-up / face-down decision (2-5/R1, R4). `is_own` picks a card FACE
## (own hand, face-up: a dark iron body, thin frame -- 7-6 R1's serious tone; the card's colour is drawn by
## its own frame overlay) versus a card BACK (face-down: deep indigo, heavy gold frame). One StyleBoxFlat is
## shared across the row's four panels. This one `if is_own` is the only place styling branches on ownership.
##
## Story 3-6: the `false` branch HAS NO CALLER any more, and is kept deliberately for the deferred
## reveal-opponent-hand toggle (`3-6/R1`).
func _make_card_face_style(is_own: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(4)
	if is_own:
		box.bg_color = Color(0.13, 0.12, 0.11)      # dark iron face
		box.border_color = Color(0.05, 0.05, 0.05)  # thin dark frame
		box.set_border_width_all(2)
	else:
		box.bg_color = Color(0.10, 0.13, 0.34)      # deep-indigo back
		box.border_color = Color(0.78, 0.64, 0.24)  # heavy gold frame
		box.set_border_width_all(4)
	return box


## Story 3-5a (AC 10): THE selection indicator. `slot` is the armed hand slot, -1 for none; the mode rides
## along for the E5 modes and is currently always BASIC. PRESENTATION-LOCAL, and pushed rather than
## subscribed: no signal, no state handle. 7-6 POLISH (P3): the armed card LIFTS (while card mode is on) and
## carries the strong frame.
func set_card_selection(slot: int, mode: Enums.ModeKind) -> void:
	var _armed_mode := mode
	_armed_slot = slot
	_apply_selection()


## Story 6-10 (AC 16/AC 20): the mode-on flag, pushed by the runner each frame beside `set_card_selection`
## (outside the ticking gate). Presentation-local like the armed slot. 7-6 POLISH (P3): mode on lifts the row.
func set_card_mode(on: bool) -> void:
	_card_mode_on = on
	_apply_selection()


## 7-6 POLISH (operator ruling P3, AC 17/AC 19/AC 21): every slot's lift and frame. Card mode on lifts every card
## `CARD_MODE_ROW_LIFT_PX`; the armed card rises to `CARD_MODE_ARMED_LIFT_PX` -- lifts only while mode is on, so a
## card never lifts alone (the 6-10 rule). The armed slot's ONE frame turns gold (P14) whenever a slot is armed.
## 7-6 POLISH 3 (operator ruling P17): a Boulder-covered slot arms exactly like any other card. Writes a position or
## a frame only when it changes (review fix N2): the runner pushes every frame.
func _apply_selection() -> void:
	for i in _own_card_panels.size():
		var lift := 0.0
		if _card_mode_on:
			lift = CARD_MODE_ARMED_LIFT_PX if i == _armed_slot else CARD_MODE_ROW_LIFT_PX
		if lift != _slot_lifts[i] or _own_card_panels[i].position.y != -lift - _arc_raise(i):
			_slot_lifts[i] = lift
			_own_card_panels[i].position = Vector2(i * (CARD_SIZE.x + CARD_GAP), -lift - _arc_raise(i))
		var armed := i == _armed_slot
		if armed != _slot_armed[i]:
			_slot_armed[i] = armed
			_paint_frame(i)


## P9: the arc -- the two middle cards (slots 2 and 3, indices 1 and 2) sit `ARC_RAISE_PX` higher.
func _arc_raise(index: int) -> float:
	return ARC_RAISE_PX if index == 1 or index == 2 else 0.0


## Story 7-6 (AC 17/AC 21): the armed frame on one slot -- 0 when not armed, `ARMED_FRAME_PX` when its frame shows
## gold (P14: the card's own frame, turned). The test-facing read, off the live node.
func highlight_width(index: int) -> int:
	var swatch := _own_card_swatches[index]
	var style := _own_card_swatch_styles[index]
	if not swatch.visible or style.border_color != ARMED_FRAME_COLOR:
		return 0
	return style.get_border_width(SIDE_TOP)



## Story 7-6 (R6): the play-history strip on the outer edge, vertically centred (7-6 POLISH 2 P9: back at its
## fix-pass size and place).
## `HISTORY_SIZE` entry panels, built once and re-rendered from `_history`; each holds an `Icon`, a `PitchMark`
## and a `Strike` line (the countered tell).
func _build_history_strip() -> void:
	var strip := Control.new()
	strip.name = "HistoryStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var anchor_x := 0.0 if history_on_left else 1.0
	strip.anchor_left = anchor_x
	strip.anchor_right = anchor_x
	strip.anchor_top = 0.5
	strip.anchor_bottom = 0.5
	strip.offset_left = 8.0 if history_on_left else -8.0 - HISTORY_WIDTH
	strip.offset_right = strip.offset_left + HISTORY_WIDTH
	var height := HISTORY_SIZE * HISTORY_ENTRY_PX + (HISTORY_SIZE - 1) * HISTORY_GAP
	strip.offset_top = -86.0
	strip.offset_bottom = -86.0 + height
	_history_strip = strip
	add_child(strip)
	for k in HISTORY_SIZE:
		var entry := Panel.new()
		entry.name = "Entry%d" % k
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.size = Vector2(HISTORY_ENTRY_PX, HISTORY_ENTRY_PX)
		var style := StyleBoxFlat.new()
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		entry.add_theme_stylebox_override("panel", style)
		entry.visible = false
		strip.add_child(entry)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(4.0, 4.0)
		icon.size = Vector2(HISTORY_ENTRY_PX - 8.0, HISTORY_ENTRY_PX - 8.0)
		icon.self_modulate = Color(0.96, 0.92, 0.82)
		entry.add_child(icon)
		var mark := Panel.new()
		mark.name = "PitchMark"
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.size = Vector2(9.0, 9.0)
		mark.position = Vector2(HISTORY_ENTRY_PX - 12.0, HISTORY_ENTRY_PX - 12.0)
		mark.rotation = PI * 0.25
		var mark_style := StyleBoxFlat.new()
		mark_style.bg_color = Color(1.0, 0.86, 0.36)
		mark.add_theme_stylebox_override("panel", mark_style)
		mark.visible = false
		entry.add_child(mark)
		var strike := Line2D.new()
		strike.name = "Strike"
		strike.width = 4.0
		strike.default_color = Color(0.95, 0.12, 0.12)
		strike.points = PackedVector2Array([Vector2(3.0, 3.0),
				Vector2(HISTORY_ENTRY_PX - 3.0, HISTORY_ENTRY_PX - 3.0)])
		strike.visible = false
		entry.add_child(strike)
		_history_entries.append(entry)


## Story 4-6a (AC 13/AC 14): the LOCKED-TARGET MARKER -- a `HudRoot`-OWNED CONTROL, so it is per-viewport by
## construction (one `HudRoot` per SubViewport, each handed only its own slot's point). MOUSE-TRANSPARENT AND
## TOP-MOST: added last, so a target standing behind the hand row is still marked.
func _build_lock_marker() -> void:
	_lock_marker = Panel.new()
	_lock_marker.name = "LockMarker"
	_lock_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_marker.custom_minimum_size = LOCK_MARKER_SIZE
	_lock_marker.size = LOCK_MARKER_SIZE
	var box := StyleBoxFlat.new()
	# A DOT, not a reticle: full corner radius on a square makes a circle.
	box.bg_color = Color(0.95, 0.93, 0.85, 0.90)     # bone, near-opaque
	box.border_color = Color(0.08, 0.07, 0.06, 0.95) # dark rim, so it survives a pale background
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(LOCK_MARKER_SIZE.x * 0.5))
	_lock_marker.add_theme_stylebox_override("panel", box)
	_lock_marker.visible = false  # nothing is marked until the runner pushes a point
	add_child(_lock_marker)


## Story 4-6a (AC 13/AC 14): the runner's per-tick push -- this slot's locked target's position in THIS
## viewport, or null when it is not visible here and the marker must hide. CENTRED ON THE POINT.
func set_lock_marker(point: Variant) -> void:
	if point == null:
		_lock_marker.visible = false
		return
	_lock_marker.visible = true
	_lock_marker.position = (point as Vector2) - LOCK_MARKER_SIZE * 0.5


## Story 7-6 (P20): the debug layer's HUD half -- the runner's F3 push. Only the orb counters belong to it; the
## deck indicator stays always visible. The counters keep updating while hidden.
func set_debug_layer_visible(shown: bool) -> void:
	_orb_counters.visible = shown


## The three orb counters — story 5-4 (AC 18) fills the region 2-4 RESERVED here. Top-right periphery,
## own-tempo per P4. Story 7-6 (AC 29): unchanged in content; P20 puts the row under the debug layer (F3).
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
	_orb_counters = orbs
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


## Deck count + reshuffle flag (story 3-6, AC 4) — the 2-4 top-left periphery placeholder, now real. TWO
## stacked lines; the count line is written by the eighth seam's payload, the flag line by the ownerless bus
## event and hidden until one arrives.
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
	# Review finding (3-6): overflow protection.
	_deck_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_deck_label.clip_text = true
	column.add_child(_deck_label)
	_reshuffle_label = Label.new()
	_reshuffle_label.name = "ReshuffleFlag"
	_reshuffle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reshuffle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_reshuffle_label.clip_text = true
	# Loud enough to catch the eye in the periphery.
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
	# 7-6 POLISH (P1): narrowed to the centre and raised to y 160..220 -- its old full-width rect at y 294..354
	# crossed the outer column (pitch zones, history strip), and the P1 StateInspector ends left of x 178.
	_round_label.anchor_left = 0.5
	_round_label.anchor_right = 0.5
	_round_label.anchor_top = 0.5
	_round_label.anchor_bottom = 0.5
	_round_label.offset_left = -110.0
	_round_label.offset_right = 110.0
	_round_label.offset_top = -164.0
	_round_label.offset_bottom = -104.0
	_round_label.visible = false
	add_child(_round_label)
