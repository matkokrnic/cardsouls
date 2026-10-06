---
baseline_commit: c4c5981c93fcf5dc2c45fec1d279604daedf2f70
---

# Story 7-6: HUD / Card Presentation Redesign

Status: done

> **Scope note.** Seventh `epic-7` story (`E6-C/R11` board order; `epics.md:348`), **Tier B**
> (`E4-P/R9`): presentation, data and tooling only. `src/state/` stays byte-identical and the golden
> and the per-player snapshot key set are predicted UNMOVED, measured before and after, never
> assumed. The scope is the operator's nine rulings (R1-R9, 2026-10-05) carried verbatim below, plus
> four follow-up decisions (D1-D4, 2026-10-05) that resolve this story's two open questions and add
> one smoke-only AC. This story file is their only written record. It discharges the `7-6` share of
> the presentation debt `E6-C/R9` consolidated (`deferred-work.md:569-571`: cost legibility, hand
> icons, per-effect cast feedback, a new HUD) plus `7-1/R7`'s explicit deferral of Boulder hand-HUD
> cosmetics (`7-1-effect-presentation.md:452`) and `6-5e` AC 24a's cosmetic mode-cycle gap
> (`deferred-work.md:529-531`). **Cleared for a dev pass.**

## What this story discharges

Measured against the code at `c4c5981`.

1. **Cost legibility failed at smoke** (`6-5b` AC 23, `6-5b-corpses-and-own-minions.md` — the two-line
   mode-1/mode-4 text block is cramped at 22 px for two lines, font size 9, `hud_root.gd:792-795`).
   Replaced by R1's two-half card face.
2. **The hand row shows only an `id` caption, no art** (`3-6/R4`, `hud_root.gd:135-140`). Replaced by
   R2's per-effect icon.
3. **Eleven of fourteen Deck 1 effects show only the generic cast-success cue; no HUD echo of a cast
   at all** (`deferred-work.md:564`, `:569-571`). R5 adds the slot-flash echo; `7-1` already covers
   the in-world look (effects remain out of this story's scope — see Non-Goals).
4. **`6-5e` AC 24a's cosmetic half: "Boulder's own row cycles no mode."** Today a covered slot can
   still be toggled and is then refused at the commit through the ordinary `REASON_COVERED_SLOT`
   channel (behaviourally equivalent; `deferred-work.md:529-531`). R4 closes the cosmetic gap only —
   no rule changes.
5. **`6-3`'s orb-hiding reasoning** (orb counts kept off the opponent's read, superseded per R7). This
   story's AC 27 ships the public world-space read; the superseding ruling itself is recorded at this
   story's close-out, not here (operator instruction).
6. **`hud_root.gd:587`'s HP display can round a living hero down to "0/max."** R8/AC 30 fixes the
   display only.

## Story

As a player in a Deck 1 match,
I want my hand, the HUD and the match world to show every card's two effects, their live
affordability, what was just played (mine and my opponent's) and both players' orb counts clearly,
so that I can read the state of a match at a glance without needing to remember card text.

## Operator Rulings (2026-10-05) — carried as given

**R1 — Card face.** No words. Split into two EQUAL halves with a clear divider: top half = NORMAL
effect (art + mana cost), bottom half = PITCH effect (art + mana cost + one pip per required orb in
that orb's colour); both arts the same size. An empty reserved symbol slot top-right (future card
keywords — renders nothing today). Card colour clearly readable (frame + background); the colour
never covers a cost. Colourless Boulder is grey. Direction: Clash Royale-like layout with a serious
Elden Ring / WoW / MTG tone. Art slots are square and art swaps without layout changes.

**R2 — Art belongs to the effect, not the card.** Re-pairing normal/pitch in data carries the art
along; a new deck only adds art for its new effects. Hand and history-strip art is icon-style (a bold
silhouette must read at ~45 px). Placeholder art now: the dev pass picks icons from game-icons.net
(CC BY 3.0), one per Deck 1 effect (14) plus Boulder, tinted, credited in `assets/CREDITS.txt`. Final
icon set and deck-builder illustrations come later (non-goal here).

**R3 — Affordability.** A card lifts when its normal mana cost is affordable; the pitch mana cost
brightens on its own when the pitch is affordable; each orb pip is lit when you hold that orb. Card
mode (L3) and the armed card move from lift to a frame highlight, so the three states stay
distinguishable. Both `6-10` hold/toggle settings keep working.

**R4 — Boulder.** Shows its own art and its clear cost, sits over the covered card which stays faintly
visible. Fixes the `6-5e` deferred item "modes cycle on the Boulder card."

**R5 — Own play echo.** The slot of the card you just played flashes briefly.

**R6 — Play history strip.** On each half-screen (outer edge; exact placement judged on smoke): the
last ~5 resolved card effects of BOTH players, newest on top, each showing the art of the effect that
actually resolved (normal or pitch). A new opponent entry visibly pops in. The opponent's entries look
distinct from yours; a countered entry is crossed out. Only normal and pitch resolutions enter the
strip. Played effects are public; hands stay private.

**R7 — World orbs.** Orbs float around each hero in the 3D world, one per orb in its colour, visible
to both players in both halves. Orb counts are deliberately public (supersedes the `6-3` reasoning
that hid them; recorded as a ruling at this story's close-out, not now). HUD orb counters stay; smoke
decides whether they are redundant.

**R8 — HP floor.** HP never displays 0 while the hero is alive (display rounds up).

**R9 — No rule change.** Golden and `FORMAT_VERSION` expected UNMOVED, no new state field. If
anything in scope needs one, stop and report (`7-6/OQ-1`).

## Follow-up Decisions (2026-10-05) — resolve the two open questions

**D1 (resolves `7-6/OQ-1`).** Played effects are public by R6, so the history strip receives them
through the PUBLIC path the repo already uses for public match events — `EventBus`, the way
`reshuffle_vulnerable_window_opened` reaches both viewports today (`E3-RG/R3`, `3-6/R7`).
`MatchState`'s card resolution (normal casts AND pitch activations) and `counterspell_resolved` are
relayed onto `EventBus` as ownerless signals carrying only public facts (which player resolved which
effect, normal or pitch; whose last entry was countered); both `HudRoot`s subscribe. No new
`connect_*` seam (family stays ten), no cross-slot read of any per-slot seam, no new inline consumer
of the `A8`/`A9` kind. The pins that move, deliberately:
`test_event_bus_still_carries_exactly_the_three_declared_signals` (`test_deck_and_hand.gd:465`,
renamed with its count on every change per its own header) and the `RAW_MATCH_STATE_CONNECTS`
signal:shape list
(`test_architecture_invariants.gd:377-382`), which gains new `:relay` entries for the new raw
`_match_state.<signal>.connect(_relay_*)` sites — the SAME sanctioned `relay` shape
`_relay_reshuffle_vulnerable_window_opened`/`_relay_round_ended`/`_relay_round_started` already use
(`match_runner.gd:2038-2051`, `:2749-2750`), not a third/fourth `inline` consumer. Verified against
the repo before this pass (see M3, updated). Tier stays B: no state change, golden unmoved. Recorded
as an architecture-amendment candidate for the E7 close-out (see Dev Notes).

**D2 (resolves `7-6/OQ-2`).** How the icon is attached to an effect is the dev pass's choice,
constrained only by R2 (art keyed by effect, swappable without a layout change).

**D3 — Size.** Stays ONE story; the dev pass may span two sessions, resuming from the Dev Agent
Record.

**D4 — New smoke-only AC.** For Rocksling, Honed Bolt and Corpse Bomb the dev pass also draws its own
hand-authored SVG icon (no third-party source, no credit needed) and the game shows THOSE three; the
game-icons.net versions of the same three stay in the repo as one-line data swaps. Smoke judges
whether the three SVGs hold up next to the other twelve.

## Measured for this story (create pass, 2026-10-05)

### M1 — Hand/vitals/pitch-zone geometry (`src/ui/hud/hud_root.gd`)

Nominal half-viewport 576x648 (`1152x648` split in two). `_build_hand_row` (`:730-859`): `HandStrip`
368 wide (offset -184..184), anchored bottom-centre, top -112/bottom -20 (grows under the `6-10`
lift). Each of the 4 card panels is `84x92` (`:749`), 8 px separation — `4*84 + 3*8 = 360` inside 368.
Today's internal bands inside each 84x92 panel (exact arithmetic in-file, `:783-791` / `:823-834`):
caption `y=[4,57]`, price `y=[58,79]`, swatch `y=[80,86]`, armed-border bottom band `y=[87,92]`.
Vitals column: anchored bottom-centre, offset -180..180, top -196/bottom -116. Pitch zones
(`OWN_PITCH_OFFSETS`/`OPPONENT_PITCH_OFFSETS`, `:225-226`): 100x88 each, anchored bottom-centre,
±186..286, top -196/bottom -108. Orb counters: top-right, three 36x36 panels in a 124-wide band
(`:1017-1029`). Deck indicator: top-left, 118x52 (`:1055-1066`). 6-10 lift constants:
`CARD_MODE_ROW_LIFT_PX = 4.0`, `CARD_MODE_ARMED_LIFT_PX = 6.0` (`:222-223`).

**R1's two-equal-halves-plus-divider-plus-reserved-slot face, with square art slots, does not fit
inside the current 84x92 panel.** The panel must grow; every offset above that is anchored relative
to the hand strip or the vitals column (the lift constants, the strip's own top/bottom, the pitch
zones' flanking distance from vitals-centre) needs re-deriving against the new panel size. This is
the central geometry change the dev pass owns; this story's ACs state the outcome, not the new pixel
numbers.

### M2 — Cost/colour reach and the 6-10 lift seat

Cost and colour reach the HUD today through the 8th seam `connect_cards_changed`
(`match_runner.gd:2811`), carrying `card_colors` (`6-0`) and `card_prices` (`6-5b` AC 23) Dictionaries
the runner derives ONCE at load from `CardData`/`CardEffect` — `HudRoot` never reads `CardDatabase`
itself (`_last_card_colors`/`_last_card_prices`, `hud_root.gd:240`/`175`). The 6-10 lift knobs are
presentation-local consts in `hud_root.gd`, pushed per-tick by the runner through
`set_card_selection`/`set_card_mode` (`:903-918`) — no signal, no state handle.

**R3's affordability is not in `card_prices`' shape today.** The HUD renders prices as static text and
never compares them against the live mana/orb seams it already separately receives
(`on_mana_changed`, `on_orbs_changed`). Wiring that comparison is new presentation logic over two
already-arriving channels — it needs no new seam.

### M3 — The public resolution channel for the history strip (R6) — resolved by D1

`EventBus` (`src/systems/event_bus.gd`) carries exactly 3 global ownerless signals (`round_ended`,
`round_started`, `reshuffle_vulnerable_window_opened`) — nothing about card resolution.

The actual channel is a named, ENUMERATED exception list of exactly TWO direct `MatchState`-signal
connects (`game-architecture.md:396-405`, amendments A8/A9):
`card_cast_resolved(slot, card_id, mode)` -> `TelegraphController` (`match_runner.gd:700`, `5-3`
AC 13) and `counterspell_resolved(caster_slot, countered_slot)` -> `TelegraphController`
(`match_runner.gd:723`, `6-5f` AC 26, two-slot `or` guard). Both are read-only, per-slot-guarded, no
`connect_*` wrapper — the seam family stays at TEN
(`test_runner_observation_seams_are_exactly_ten`).

`match_runner.gd:690-695` and `:711-713`'s own comments explicitly flag that a third/fourth consumer
of this raw-connect shape would be "a de-facto seam family nobody voted for," and that "the next such
connection should" open the seam-family question. R6's history strip needs BOTH players' resolved
casts rendered inside EACH `HudRoot` — cross-slot, unlike every existing `connect_*` seam, which is
structurally per-slot-only by construction (`2-4/R7`, `3-6/R7`). This is exactly the third/fourth
raw-connect use the architecture doc told the next story to raise — and `7-6/OQ-1` raised it.

**Resolved by D1: the relay path, not a third inline consumer.** Played effects are public (R6), so
the history strip is wired exactly like `reshuffle_vulnerable_window_opened` — a runner-owned
`_relay_*` function (the SAME sanctioned shape as `_relay_round_ended`/`_relay_round_started`/
`_relay_reshuffle_vulnerable_window_opened`, `match_runner.gd:2038-2051`, `:2749-2750`) connects to
`MatchState.card_cast_resolved`/`counterspell_resolved` and re-emits their public facts onto two new
`EventBus` signals; both `HudRoot`s subscribe to the bus, exactly as they already do for
`on_reshuffle_vulnerable_window_opened`/`on_round_ended`/`on_round_started`. This needs no cross-slot
read of a per-slot seam and adds no `connect_*` wrapper (the family stays at ten) and no third
`inline` raw-connect (the relay shape is already sanctioned twice over and carries none of the
"nobody voted for" warning that gates `inline`). Two pins move, deliberately, and are named in this
story: `test_event_bus_still_carries_exactly_the_three_declared_signals`
(`test_deck_and_hand.gd:465`) gets renamed for its new count, and `RAW_MATCH_STATE_CONNECTS`
(`test_architecture_invariants.gd:377-382`) gains two new `:relay` entries for the two new
`_relay_*` source sites. Verified in the repo before this decision was applied (see D1's own
citations) — the reshuffle relay shape, the bus signal-count pin, the raw-connect shape pin and
`HudRoot`'s existing bus subscriptions all hold as described.

### M4 — Orb count source and the world presenter (R7)

9th seam `connect_orbs_changed(slot, ...)` (`match_runner.gd`, `OrbPool` at
`src/state/pools/orb_pool.gd`), per-slot, already consumed by `TelegraphController.on_orbs_changed`
(actor-local) and `HudRoot.on_orbs_changed` (HUD-local). Max per colour is AUTHORED BALANCE
(`OrbPool._max`, sentinel `NO_MAXIMUM = -1` until `BalanceConfig` injects a real ceiling,
`orb_pool.gd:28-35`) — no fixed code constant to cite.

**R7 needs no new channel.** A world-space presenter lives per-hero in the shared `World3D`
(`main.tscn`'s two `SubViewport`s render the same `World3D`, unlike the privacy-walled
per-viewport `HudRoot`). A hero-local presenter wired to that SAME hero's own `connect_orbs_changed`
— exactly `TelegraphController`'s existing wiring shape — is sufficient: no cross-slot read is
needed, because the world object itself is already visible to both halves by construction.

### M5 — HP display and the Boulder mode-cycle symptom

`hero_state.gd`: `_hp: float` (`:174`); `is_alive()` (`:237`) is `hp > 0`; `_set_hp` (`:550`) clamps to
`[0, max_hp]`. A hero can legitimately hold a small positive HP (e.g. 0.4) while alive, and
`HudRoot.on_hp_changed -> _apply_bar` formats with `int(roundf(current))` (`hud_root.gd:587`), which
rounds 0.4 DOWN to display "0" while truly alive. **This is a display-rounding defect (round vs.
ceil), not a state/rule bug** — no blocking open question for R8; AC 30 requires ceil-style display.

Boulder mode-cycle: `deferred-work.md:529-531` — "Boulder's own row cycles no mode" — today
behaviourally equivalent via `REASON_COVERED_SLOT` refusal at commit; this story closes the cosmetic
presentation gap (the covered slot visibly appearing to cycle) only.

### M6 — Skill coverage

No project skill under `.claude/skills/` implements HUD/UX design for this story's scope.
`gds-ux` ("Plan game UX, UI, and HUD design specifications") exists and would be the fitting tool for
a future design-specification pass, but per instruction it is reported here, not invoked.

### M7 — Rough file count and proposed cut line

Likely well over 15 files: `hud_root.gd` (major rewrite — card panel resize, affordability wiring,
history strip per D1, HP display fix, Boulder look); a new world-space orb presenter script plus
hero/`match_runner.gd` wiring; two new `_relay_*` sites on `match_runner.gd` plus two new `EventBus`
signals (D1); `CardEffect` gains an icon/art key export (an unused `visual_id` field already exists
at `card_effect.gd:289` and is a candidate the dev pass may reuse rather than add a new one — D2
leaves this HOW to the dev pass) plus 15 resource edits (14 Deck 1 effects + Boulder); three
hand-authored SVG icons (D4) alongside the game-icons.net versions of the same three rows;
`assets/CREDITS.txt` gains the icon-set entry; `deferred-work.md` loses the AC 24a cosmetic line;
new/extended integration tests for card-face geometry, affordability, Boulder look, HP display, the
history strip and world orbs.

**Proposed cut line, for the operator's call, not decided here:** hand + vitals (R1-R5, R8) is
self-contained; world + history (R6, R7) carries the new relay/bus wiring (D1) and the new
world-space presenter. One story is authored regardless, per instruction — the cut (if taken) would
be a sequel story's scope, not a change to this one.

## Acceptance Criteria

Each AC is tagged **(headless)** — provable by the automated suite — or **(smoke)** — provable only
by a human looking at the running game. Every AC states what must be true of the shipped behaviour,
not how to build it.

**Structure — Tier B holds**

1. **(headless)** `git diff --stat -- src/state/` is empty at the before-measurement and at the end
   of the pass.
2. **(headless)** The golden and the per-player snapshot key set are measured unmoved before and
   after. `FORMAT_VERSION` and `project.godot` are byte-identical. If either moves, the story is Tier
   A by the golden clause (R9): stop and report, do not re-baseline.
3. **(headless)** No new `connect_*` seam (`test_runner_observation_seams_are_exactly_ten` unedited,
   family stays ten). The only new raw `_match_state.<signal>.connect(` sites are the two `:relay`
   entries D1 sanctions (`test_raw_match_state_connects_are_pinned_by_shape` updated to add them,
   not to add a third `:inline` consumer).
4. **(headless)** No new field reaches `to_snapshot()` or the capture/replay path; `CardData`/
   `CardEffect` additions (e.g. an icon key) stay authored, unhashed resource data, exactly like
   `card_colors`/`card_prices` today.

**Card face (R1)**

5. **(headless)** Each own-hand card panel renders two regions of equal height, separated by a
   visible divider; the top region holds the normal effect's art and mana cost, the bottom region
   holds the pitch effect's art, mana cost, and one pip per required orb in that orb's colour.
6. **(smoke)** Both arts read as clearly belonging to their own half at a glance, at the shipped
   half-width viewport, with both costs and every orb pip legible.
7. **(headless)** A reserved slot exists in the top-right of the panel and renders no visible content
   today (an empty node, not a placeholder glyph).
8. **(headless)** The card's colour frame/background never occupies the same screen rect as either
   cost's text. Every card carries ONE permanent frame in its own card colour, 6 px thick, around the whole
   card; dimming a half never dims it. Arming turns that same frame gold; there is no second frame.
   *(Frame added by operator ruling P8; made one thicker frame by operator ruling P14, 2026-10-06.)*
9. **(headless)** Boulder's panel colour is the existing neutral grey (`COLORLESS_SWATCH`,
   `hud_root.gd:101`), not a fourth `ORB_COLORS` entry.
10. **(headless)** Swapping a slot's art (a different card drawn into it) changes no child's rect,
    size, or anchor on that panel — only the art texture/region changes.

**Art ownership and icons (R2)**

11. **(headless)** The art/icon shown for an effect is keyed by the effect's own identity, not by
    which card currently pairs it as normal or pitch — re-pairing the same effect onto a different
    card in data renders the same art with no new authoring.
12. **(headless)** `assets/CREDITS.txt` lists one entry per shipped icon (14 Deck 1 effects + Boulder)
    naming its game-icons.net source and the CC BY 3.0 licence.
13. **(smoke)** Hand-row and history-strip icons read as a legible bold silhouette at their shipped
    on-screen size.

**Affordability (R3)**

14. **(headless)** A card's NORMAL half is shown payable -- full colour with a thin glowing rim --
    exactly when its normal mana cost is currently affordable (driven by the hero's own live mana
    reading), and dimmed and desaturated otherwise. No affordability state moves a card. *(Rewritten
    by operator ruling P2, 2026-10-05: affordability is brightness, not the R3 lift.)*
15. **(headless)** A card's PITCH half is shown payable or dimmed and desaturated by the same rule
    against its pitch mana cost, independent of the normal half. *(Rewritten by P2.)*
16. **(headless)** Orb pips fill by count: the n-th pip of a colour is lit exactly when the player
    currently holds at least n orbs of that colour. Every pip is drawn in its full orb colour; a held
    orb is a filled circle, a missing one a hollow ring with a thick outline. *(Count-fill restated to
    the review fix F3's ruling, 2026-10-05; filled vs hollow by operator ruling P7, 2026-10-06.)*
17. **(headless)** Card mode on lifts the whole own hand row a little; the armed card lifts clearly
    higher and its own frame turns gold, with a soft glow (P14 -- no second frame). The lifts apply only
    while card mode is on (a card never lifts alone); the gold frame shows whenever a slot is armed. Affordability
    (AC 14/15), card mode and the armed card stay visually distinct and can be true at once without
    collapsing into one look. *(Rewritten by operator ruling P3, 2026-10-05: arming is a lift again,
    superseding R3's frame highlight for card mode.)*
18. **(smoke)** The three states (affordability brightness and rims, the card-mode row lift, the
    armed lift and frame) read as distinguishable from one another in the running game.
19. **(headless)** Both existing `6-10` hold-to-select and toggle settings still produce the same
    card-mode/armed behaviour as before this story (regression).

**Boulder (R4)**

20. **(smoke)** A Boulder in a hand slot shows its own art and a clearly readable cost; the card it
    covers remains faintly visible underneath.
21. **(headless)** A Boulder-covered slot arms exactly like any other card: in card mode it takes the
    row lift, and while armed it rises to the armed lift with its frame gold. The existing
    `REASON_COVERED_SLOT` refusal at commit is unchanged. *(Rewritten by operator ruling P17,
    2026-10-06; this supersedes the earlier "no mode-cycle tell" suppression and closes the review's
    deferred N8.)*

**Play echo (R5)**

22. **(smoke)** The hand slot a player just cast from flashes strongly enough, and long enough, to catch
    peripheral vision -- a full-strength wash with a glow, held briefly and then faded (pinned at a
    0.7 s total). Triggers: a mode ①-③ cast flashes its slot; a pitch activation flashes the slot its
    card was staged from; a fizzle and a Boulder clear never flash. *(Strengthened by operator ruling P4,
    2026-10-05; triggers per the review fixes F1/F2.)*

**History strip (R6, via D1)**

23. **(headless)** Each history strip holds at most 5 entries, newest on top, and only a resolved
    normal/pitch cast or a countered resolution ever enters it — no other game event does. The strip
    is driven entirely off `EventBus` (D1's two new relayed signals), never off a per-slot `connect_*`
    seam read cross-slot.
24. **(smoke)** Each entry shows the art of the effect that actually resolved (normal or pitch, never
    a generic placeholder); a new opponent entry visibly animates in; opponent entries are visually
    distinct from the viewer's own; a countered entry renders crossed out.
25. **(headless)** No hand content (card identity, mode, or orb state) is readable from either strip —
    only resolved-effect identity and its countered/not-countered flag cross `EventBus`.
26. **(headless)** `EventBus` carries exactly its new, larger set of declared signals (the signal-
    count pin, `test_deck_and_hand.gd:465`, renamed for its new count) and `RAW_MATCH_STATE_CONNECTS`
    (`test_architecture_invariants.gd:377-382`) gains exactly two new `:relay` entries — no new
    `:inline` entry, no new `connect_*` wrapper.

**World orbs (R7)**

27. **(smoke)** Each hero shows one soft glowing wisp per held orb, in that orb's colour, visible in both
    split-screen halves simultaneously. The wisps drift irregularly around their hero (no rigid ring)
    and follow it with inertia: they lag behind a moving hero and catch up. *(Restyled by operator
    ruling P5, 2026-10-05; made smaller for the closer camera by operator ruling P10, 2026-10-06.)*
28. **(headless)** The world orb presenter's displayed count for a hero always equals that hero's own
    live orb counts from `connect_orbs_changed`, per colour. This holds through a decrease, a debug
    reset and a round restart. The wisps are not carried rigidly by the hero: their spacing varies
    over time, and they lag behind a sudden move and then catch up. No wisp is ever inside its hero's
    body radius, through drift and through catch-up, including when the hero steps onto a wisp; wisps go
    around the body, not through it *(P16)*. No collision of any kind exists
    under any `OrbHalo` -- no `CollisionObject3D` (Area3D or physics body), `CollisionShape3D` or
    `CollisionPolygon3D`. *(The collision pin is from operator ruling P10.)*
29. **(headless)** The existing HUD orb counters (top-right, per-viewport) keep their content
    unchanged (regression) and keep updating. They are part of the debug layer: hidden by default and
    shown by F3 (AC 35). *(Placed under F3 by operator ruling P20, 2026-10-06.)*

**HP display (R8)**

30. **(headless)** For any hero with `0 < hp < 1` and `is_alive() == true`, the rendered HP text never
    reads an integer of 0; the display value is the ceiling of the live HP, not the nearest-rounded
    value.
31. **(headless)** For `hp == 0` (not alive) the display is unchanged from today (0 is correct once
    the hero is dead).

**Hand-authored icons (R2/D4)**

32. **(smoke)** Rocksling, Honed Bolt and Corpse Bomb show a hand-authored SVG icon (no third-party
    source, no credit entry) rather than their game-icons.net placeholder; the game-icons.net
    versions of the same three effects stay in the repo, reachable by a one-line data swap, and are
    not deleted.

**Polish round 2 (operator rulings P9, P11-P13, 2026-10-06)**

33. **(headless)** At the shipped fullscreen half (960x1080; stretch mode `disabled`, so the HUD is in
    native pixels, and the game starts fullscreen) the own hand is an ARC. The two middle cards sit
    raised. The vitals are three stacked bars beneath the middle pair, at that pair's full width, with
    no caption labels and with each bar's numeric value; the lower bars reach below the outer cards'
    bottom edge. The bars are 15 px *(P18)*. Each number sits inside its bar near the right end: white,
    bold, with a thick dark outline and no background *(P19)*. Both pitch zones are CARD-SIZED (128x158) and bottom-aligned with the outer cards;
    each zone's gap to the hand equals its gap to its edge of the half (42 px at 960), with contents
    scaled to the zone *(P15)*. The history strip is back at its fix-pass size and place. No laid-out element overlaps another or leaves the viewport,
    even at an armed card's highest reach. *(P9.)*
34. **(headless)** One authored camera knob (`CameraConfig.framing_scale`, 0.5) scales the camera's
    distance and height, so the hero is about twice as large on screen. Free camera and lock-on framing
    keep working. *(P11.)*
35. **(headless)** F3 (`debug_toggle_instruments`, a key no other binding uses) is the ONE debug-layer
    toggle. The layer is hidden by default, and F3 shows or hides all of it together. It holds the
    DebugInstrumentPanel, the StateInspector in both halves, the HUD orb counters, and every telegraph
    SHAPE: both heroes' TelegraphController shapes (attack, block and roll; the unblockable colour cue;
    deflect; hit; orb earn; the cast-target warning; the root marker) and the cast-target cone over a
    minion or totem. Every telegraph SOUND plays whether the layer is shown or hidden, exactly as before
    P21 -- the refusal sound included. Also kept on with the layer hidden: the deck indicator, the lock
    marker, the world orbs and every 7-1 effect look and sound. Everything in the layer keeps updating
    while hidden. When shown, it may overlay the HUD. *(P12; widened by operator rulings P20 and P21; P21's
    sound half superseded by operator ruling P22, 2026-10-06.)*
36. **(headless)** While a hand slot waits for its replacement card, it spins like a slot-machine reel
    through the arts of the player's own deck. The randomness is presentation-local and never the match
    RNG, and the HUD never learns the next card. The slot lands on the real card, with a small settle,
    when the hand payload delivers it. A permanently empty slot never spins. One authored on/off knob,
    `EffectIconSet.slot_reel_enabled`, controls it (default on). *(P13.)*

## Non-Goals

Deck builder / card text menu; final art and illustrations (placeholder icons only, R2); mana bar
redesign; number tuning (`7-7-tuning-pass`); opponent hand display; unblockable presentation; hit
reactions; the in-world effect look itself (that is `7-1`'s scope — this story only adds the HUD-side
echo named in R5 and the history strip named in R6).

## Golden Prediction

**PREDICTED UNMOVED — to be measured before and after, both directions, by the dev pass.** Every
ruling in scope reads public fields, authored resource data, or already-arriving/newly-relayed signal
payloads (`card_colors`/`card_prices`/`connect_orbs_changed`/`connect_mana_changed`, and — for R6 —
D1's two new `EventBus` relays of `card_cast_resolved`/`counterspell_resolved`), never a new state
field. No `to_snapshot()` shape changes, so the per-player snapshot key set cannot move (AC 4). If
the golden moves, the cause is not presentation by construction (R9) — find it (most likely an
accidental `src/state/` edit, or a `data/` edit that reaches the effect-injection channel the
recorder captures) and report it rather than re-baseline (AC 1, 2).

## Tasks / Subtasks

- [x] Before-measurement: suite, golden, snapshot key set, `git diff --stat -- src/state/` (AC 1, 2)
- [x] Resize the own-hand card panel to fit R1's two-equal-halves face; re-derive every offset anchored
      against it (vitals column, pitch zones, 6-10 lift constants) (AC 5-10, M1)
- [x] Source/ingest placeholder icons (game-icons.net, CC BY 3.0) for 14 Deck 1 effects + Boulder;
      tint; credit in `assets/CREDITS.txt` (AC 11-13, R2)
- [x] Hand-author three SVG icons (Rocksling, Honed Bolt, Corpse Bomb) and wire them as the shown
      icon, keeping the game-icons.net versions as a one-line data swap (AC 32, D4)
- [x] Key art lookup by effect identity, not card identity (AC 11); pick the icon-key field per D2
      (`visual_id` reuse vs. a new export)
- [x] Wire affordability: lift from live mana vs. normal cost, brighten from live mana vs. pitch cost,
      per-pip lit from live orb holdings; keep card-mode/armed as a frame highlight, distinguishable
      from both (AC 14-19, M2)
- [x] Boulder look (own art, faint covered card) and the AC 24a cosmetic fix: no mode-cycle tell on a
      covered slot (AC 20-21)
- [x] Own-play slot flash (AC 22)
- [x] Add the two `_relay_*` sites and `EventBus` signals per D1; wire both `HudRoot`s' history strip
      off them: both players' last ~5 resolutions, opponent pop-in, distinct opponent look, countered
      strike-through (AC 23-26)
- [x] World-space per-hero orb presenter wired to each hero's own `connect_orbs_changed`, visible in
      both viewports by construction (AC 27-28); keep the HUD orb counters unchanged (AC 29)
- [x] HP display: ceil instead of round in `HudRoot._apply_bar` (AC 30-31)
- [x] Discharge `deferred-work.md:529-531` (Boulder mode-cycle cosmetic line) once AC 21 is proven
- [x] Record D1's new `EventBus` signals as an architecture-amendment candidate for the E7 close-out
      (see Dev Notes)
- [x] After-measurement: full suite, golden, snapshot key set (AC 1, 2)
- [x] Live Smoke handed to the operator (AC 6, 13, 18, 20, 22, 24, 27, 32 — see Live Smoke below)

### Review Findings

The code review (`gds-code-review`, 2026-10-05, report `C:\dev\_76-review.md`) raised 0 blocker, 3 major, 5 minor
and 11 note findings. All were handled in a fix pass in the same session. F1-F7 are operator rulings of 2026-10-05.

- [x] [Review][Patch] M1: a counter struck the countered player's Boulder entry -- FIXED by operator ruling F1:
  Boulder clears never enter the strip (`_relay_card_cast_resolved` drops `CardEffectResolver.BOULDER_OUTCOMES`).
  The newest entry is therefore always the reversed card. A counter whose card has left the strip strikes nothing.
  [src/main/match_runner.gd `_relay_card_cast_resolved`]
- [x] [Review][Patch] M2: a pitch activation never flashed its slot -- FIXED by operator ruling F2: the activation
  flashes the slot its card was staged from; a fizzle never flashes. [src/ui/hud/hud_root.gd `on_pitch_changed`,
  `on_card_effect_resolved`]
- [x] [Review][Patch] M3 (known a): orb pips lit by presence -- FIXED by operator ruling F3: pip n of colour c is lit
  iff at least n orbs of c are held (`orb_rank`). `test_card_face` was flipped to `[true, false]` at one orb, and a
  two-orb case was added. [src/ui/hud/hud_root.gd `_apply_affordability`]
- [x] [Review][Patch] m1 (known b): the pitch zone showed the card id as text -- FIXED by operator ruling F4: an
  `Art` square shows the staged card's PITCH effect art. The caption is kept hidden as the identity record, and the
  layout is otherwise unchanged. [src/ui/hud/hud_root.gd `_build_pitch_zone`, `_render_pitch_zone`]
- [x] [Review][Patch] m2: the mana number disagreed with the lift -- FIXED by operator ruling F5: the number is the
  floor (`mana_display_value`, sharing `AFFORD_EPSILON` with the lift). HP keeps its R8 ceiling.
  [src/ui/hud/hud_root.gd `on_mana_changed`]
- [x] [Review][Patch] m3: card-face geometry coverage was lost -- FIXED by operator ruling F6: on the live
  split-viewport tree, every cost rect lies inside its panel and is disjoint from the pip row and the keyword slot.
  [test/integration/test_hud_viewports.gd `_check_face_geometry`]
- [x] [Review][Patch] m4: the halo was pinned only at its first grant -- FIXED by operator ruling F7: new phases
  cover a decrease, a mid-round debug reset, and a round restart (kill, then reset), each followed by a grant.
  [test/integration/test_history_and_orbs_live.gd]
- [x] [Review][Patch] m5: a second flash or pop could be cut short -- FIXED: one tween per node, so a restart kills
  the running tween, and an own entry settles any running opponent pop. [src/ui/hud/hud_root.gd `_restart_tween`,
  `_settle_history_entry`]
- [x] [Review][Patch] N2: highlight styles were re-applied every frame -- FIXED: the theme override is touched only
  when a slot's look changes. [src/ui/hud/hud_root.gd `_apply_highlights`]
- [x] [Review][Patch] N4: the two new test scripts had no `.uid` -- FIXED with one headless editor scan;
  `project.godot` SHA256 was unchanged (`9c3089bc...95e2`).
- [x] [Review][Patch] N5: the `test_debug_instruments.gd` header carried stale zone offsets -- FIXED.
- [x] [Review][Patch] N10: the CREDITS test did not require an author -- FIXED: `test_card_face` AC 12 now requires
  `" by <author>,"`.
- [x] [Review][Defer] N6: the highlight rings fill the 8 px gap exactly, and an armed lifted ring reaches 1 px into
  the vitals column -- deferred to smoke item 2 (`deferred-work.md`, 7-6 code-review block).
- [x] [Review][Defer] N8: a covered slot also hides the ARMED ring -- deferred to smoke (`deferred-work.md`).
- [x] [Review][Defer] N11: `_effect_color` takes the first card carrying an effect -- deferred to `7-5-deck-2`
  (`deferred-work.md`).
- [x] [Review][Dismiss] N1: a 99.2 HP hero reads 100/100 -- dismissed: this is R8's literal ceiling. The latent
  "100/99" case needs a non-integral authored max, and the hero max is 100.0.
- [x] [Review][Dismiss] N3: the affordability pass re-runs every regen tick -- dismissed: it is signal-driven
  (project-context compliant), allocation-free, and costs 4 cards' writes.
- [x] [Review][Dismiss] N7: the halo hues are the charge-telegraph colours, not the HUD's `ORB_COLORS` --
  dismissed: this is the 7-1 "no second colour table" rule, with the same hue family and the same RED/BLUE/GREEN
  order.
- [x] [Review][Dismiss] N9: the dev-pass-only budget figure and the harness-backgrounded suite run -- dismissed as
  code findings: they are process disclosures for the close-out log entry, not code.

## Live Smoke

Two pads, flip [3,3], launched with `C:\Godot\godot.exe --path C:\dev\cardsouls`.

1. Card faces readable at half width: both arts equally readable, both costs, orb pips, colour.
2. Lift vs. pitch-brighten vs. card-mode/armed-highlight are distinguishable from one another.
3. Boulder look correct (own art, faint covered card beneath) and no mode-cycle tell on a covered
   slot.
4. The slot just played flashes briefly and distinctly on each cast.
5. History strip shows both players' plays with the correct normal/pitch art; the opponent's new
   entry visibly pops in; a countered entry is crossed out.
6. Orbs orbit both heroes, visible in both halves.
7. The three hand-authored SVG icons (Rocksling, Honed Bolt, Corpse Bomb) hold up next to the other
   twelve placeholder icons.
8. A round ends normally on a kill.
9. fps stable.
10. Regression: melee, block, deflect, roll, a mode-2 unblockable, a mode-3 defence, a pitch
    activation are unchanged; both 6-10 hold/toggle settings still work.

## Live Smoke Result

Run by the operator over five smokes (2026-10-05/06; full text in `docs/playtest-log.md`, entry "2026-10-05/06 -- 7-6 HUD i karte"). **PASS after five rounds**, two failing rounds (smoke 1 and 2) fed the polish rounds.

- **Smoke 1 (2026-10-05):** Boulder, the pitch zone with art and the history strip were good from the first look. Failed: cards too small, arts and pips hard to tell apart, costs not prominent, the affordability lift confused against arming, arming too subtle, the flash unnoticed, orbs ugly, Honed Bolt must be lightning. Melee, block, deflect, roll, unblockable, colour defence and pitch fine; the round ends on a kill; fps stable. -> polish round 1 (P1-P6).
- **Smoke 2 (2026-10-06):** card size and art recognition good, arming and flash now noticed, hand good, orbs much better but slightly large. Failed: card colour suffers on dark cards, pitch zones and strips misplaced, camera too far, debug panel in the middle of the screen. -> polish rounds 2 and 3 (P7-P18).
- **Smoke 3 (2026-10-06):** fullscreen works, pips readable, the arc with bars under the middle cards good, camera hit, orb size good, F3 panel and slot reel good, fps stable. Remaining: thicker frame, card-sized pitch zones with equal gaps, Boulder not arming until played, thinner bars with unreadable numbers; an occasional short hero jerk against the orbs, not serious. -> P14-P18.
- **Smoke 4 (2026-10-06):** frame, pitch zones, orbs circling the hero and Boulder arming all excellent; thinner bars good but the dark plate under the number is ugly. -> removed (P19).
- **Smoke 5 (2026-10-06):** F3 toggles the whole debug layer (panel, inspectors, orb counters, telegraphs). Honed Bolt is much easier to read and dodge with the closer camera; unblockable colours read by animation, deflect by the attacker's stun. With the telegraph sounds gone too the operator felt blind, so the sounds were restored (P22) and F3 hides only the symbols. Accepted as temporary: subtler cues and sounds integrated into the animations come later.

Numbers of record (final tree): suite `C:\dev\_76-suite-final-state.txt` state 1248 tests / 0 failed / 11839 assertions (exit 0) and `C:\dev\_76-suite-final-integ.txt` integration 78/78 PASS, `INTEGRATION_FAIL=0` (exit 0, end 21:17:35). Golden and per-player snapshot key set unmoved; `src/state/` untouched.

## Dev Notes

### Guardrails (measured)

- `src/ui/hud/hud_root.gd` has no `_physics_process` and no `_process` (F1, event-driven per `2-4/R9`)
  — this story must not add either.
- `Input.*` stays out of `src/ui/`; none of this story's rulings need new input reads beyond what
  `match_runner.gd` already pushes (`set_card_selection`/`set_card_mode`).
- `src/state/` / `src/controllers/` invariants (D3(a), D3(b)/A2) are untouched by a presentation-only
  story by construction; the before/after `git diff --stat -- src/state/` (AC 1) is the proof, not an
  assumption.
- The observation-seam family is pinned at TEN and the raw-connect exception list at exactly two
  `:inline` + zero `:relay` instances today (`test_runner_observation_seams_are_exactly_ten`,
  `test_raw_match_state_connects_are_pinned_by_shape`). D1 adds two `:relay` entries to the second
  list and leaves both pins' shapes intact — the family and the `:inline` count are both unmoved.
- **Architecture-amendment candidate for the E7 close-out** (D1): two new `EventBus` signals relay
  public cast-resolution facts (normal/pitch resolution, countered-flag) off
  `MatchState.card_cast_resolved`/`counterspell_resolved`, through the same `_relay_*` shape as
  `reshuffle_vulnerable_window_opened`. Record this at close-out in `game-architecture.md`'s
  amendment-queue ledger (the `A6`-`A9` precedent, `game-architecture.md:1238-1251`) and in
  `epics.md`'s close-out note for E7, the way `A8`/`A9` were recorded for `5-4`/`6-3b`/E6.

### Files expected to change (illustrative, not exhaustive — see M7)

- `src/ui/hud/hud_root.gd` — card panel resize, affordability wiring, Boulder look, HP display fix,
  history strip (subscribed to the two new `EventBus` signals).
- `src/systems/event_bus.gd` — two new signals (D1).
- `src/main/match_runner.gd` — two new `_relay_*` sites connecting `MatchState.card_cast_resolved`/
  `counterspell_resolved` onto the new `EventBus` signals (D1).
- New world-space orb presenter (actor-local, hero-owned) + `src/main/match_runner.gd` wiring.
- `src/state/resources/card_effect.gd` — an icon/art key export (see D2).
- `data/effects/*.tres` (15 resources: 14 Deck 1 effects + Boulder) — icon key authored per row.
- Three new hand-authored SVG icon assets (Rocksling, Honed Bolt, Corpse Bomb) alongside their kept
  game-icons.net counterparts (D4).
- `assets/CREDITS.txt` — new icon-set entry.
- `docs/implementation-artifacts/deferred-work.md` — discharge the AC 24a cosmetic line.
- `test/state/test_deck_and_hand.gd` — rename the `EventBus` signal-count pin for its new count (D1).
- `test/state/test_architecture_invariants.gd` — add two `:relay` entries to `RAW_MATCH_STATE_CONNECTS`
  (D1).
- New/extended integration tests under `test/integration/` for card-face geometry, affordability,
  Boulder look, HP display, history strip and world orbs.

### References

- [Source: docs/implementation-artifacts/sprint-status.yaml#L147] — board key and Tier.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md#L348] — Epic 7 scope line.
- [Source: docs/implementation-artifacts/deferred-work.md#L522-L572] — AC 24a, E6 HUD residue.
- [Source: docs/implementation-artifacts/7-1-effect-presentation.md#L349-L452] — `7-1/R7` Boulder-HUD
  deferral to this story.
- [Source: docs/game-architecture.md#L370-L405] — observation-seam registry and the raw-connect
  exception list (resolved by D1).
- [Source: docs/game-architecture.md#L1238-L1251] — the amendment-queue ledger precedent (`A6`-`A9`)
  D1's close-out entry follows.
- [Source: src/ui/hud/hud_root.gd] — current geometry, seams consumed, HP display.
- [Source: src/main/match_runner.gd#L644-L726, L2038-L2051, L2749-L2750] — the two sanctioned
  `:inline` raw-connect sites and the three existing `_relay_*` sites D1's two new ones match.
- [Source: src/systems/event_bus.gd] — the three signals D1 grows to five.
- [Source: test/state/test_deck_and_hand.gd#L465] — the `EventBus` signal-count pin D1 renames.
- [Source: test/state/test_architecture_invariants.gd#L377-L421] — the raw-connect shape pin and its
  `relay` classification D1 relies on.
- [Source: src/state/pools/orb_pool.gd] — orb max/sentinel.
- [Source: src/state/hero_state.gd#L174,#L237,#L550] — HP type, liveness, clamp.
- [Source: src/state/resources/card_effect.gd#L289] — unused `visual_id` export (D2).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (1M context), `claude-opus-5-5[1m]`, via `gds-dev-story`, 2026-10-05. Single session, no
subagents. Nothing committed.

### Debug Log References

- **Preconditions (measured):** HEAD == origin/main == `4a44603`; `git status --short` empty; no godot process;
  story Status `ready-for-dev`. All held.
- **Before-baseline** (before the first edit; two foreground calls, scratchpad copies of the two halves of
  `test/run_all.sh`): `C:\dev\_76-suite-before-state.txt` (15:43:27 -> 15:43:59): **1248 tests / 0 failed / 11834
  assertions**, `test_state_matches_golden` ok, `test_the_player_snapshot_key_set_is_exactly_the_expected_set` ok;
  `C:\dev\_76-suite-before-integ.txt` (15:44:02 -> 15:50:29): **76/76 PASS**. `git diff --stat -- src/state/` empty;
  `project.godot` SHA256 `9c3089bc...95e2`.
- **After (final)**: `C:\dev\_76-suite-after-state.txt` (16:15:09 -> 16:15:29): **1248 tests / 0 failed / 11835
  assertions**; golden test ok, key-set test ok, `test_raw_match_state_connects_are_pinned_by_shape` ok,
  `test_event_bus_still_carries_exactly_the_five_declared_signals` ok. `C:\dev\_76-suite-after-integ.txt`
  (16:15:34 -> 16:30:06): **78/78 PASS** (76 + 2 new files). Assertions +1 = `test_data_resources`' every-`.tres`
  load over the new `data/presentation/effect_icons.tres` (no test failed). The integration half ran ~14.5 min vs
  ~6.5 min before and passed the 600 s tool timeout; the harness moved the SAME single call to the background
  and it completed with exit 0 (no second run). Not investigated; reported.
- **Golden and per-player key set, both directions: UNMOVED.** Before and after, `test_state_matches_golden`
  passes (computed hash == pinned `GOLDEN`, `941958c5...871f`) and the pinned constant itself is untouched
  (`git diff -- test/state/test_determinism.gd` empty); the key-set test passes before and after with its pin
  file untouched. `git diff --stat -- src/state/ project.godot` empty at the end; `project.godot` SHA256
  unchanged after both editor scans. `FORMAT_VERSION` lives in `src/state/` -> byte-identical.
- **Suite runs:** two full runs (before, after). No extra full run.
- **Engine launches outside the two suite runs** (each its own call): two headless `--editor --quit` scans (new
  `.uid`s + SVG imports; then re-import after setting `svg/scale=0.125` -> 64 px textures in all 18 `.import`
  files), `project.godot` untouched by both, nothing to restore; dev runs of `test_card_face` (x2: one AC 8
  failure on the covered slot, fixed), `test_history_and_orbs_live`, `test_card_mode_lift`,
  `test_card_selection_indicator`, `test_hud_viewports`, `test_debug_instruments`, `test_card_tint_live`,
  `test_pitch_ghost`, `test_card_hud`, `test_pitch_hud_live`, `test_boulder_and_skull_live`; filtered state runs of
  `architecture_invariants` and `deck_and_hand`; two WINDOWED capture runs (visual check, below); 20 mutation runs.
- **Icons fetched** from `https://game-icons.net/icons/ffffff/transparent/1x1/<author>/<name>.svg` (HTTP 200 each);
  the network was reachable, nothing substituted.

#### Mutation table (each run against its test file only; restored by copy-back from
`<scratchpad>/mutbak/`, SHA256 checked against `SHA256SUMS` taken before the first mutation -- all OK)

| # | mutation | file | expected RED | observed |
|---|---|---|---|---|
| M1 | lift needs mana strictly above cost | hud_root.gd | test_card_face AC 14 | RED (4 AC 14 fails) |
| M2 | pitch brightness reads the NORMAL cost | hud_root.gd | test_card_face AC 15 | RED |
| M3 | a pip needs >= 2 orbs to light | hud_root.gd | test_card_face AC 16 | RED |
| M4 | both halves show the card's first effect art | hud_root.gd | test_card_face AC 11 | RED |
| M5 | reserved slot gets a "*" Label child | hud_root.gd | test_card_face AC 7 | RED |
| M6 | normal cost rect moved over the art backing | hud_root.gd | test_card_face AC 8 | RED |
| M7 | covered slots keep their highlight | hud_root.gd | test_card_face AC 21 | RED |
| M8 | history never trimmed to 5 | hud_root.gd | test_card_face AC 23 | RED |
| M9 | HP shown rounded, not ceiled | hud_root.gd | test_card_face AC 30 | RED |
| M10 | relay's explicit mode-1/4 check removed | match_runner.gd | test_history_and_orbs_live AC 23 | **SURVIVED (equivalent)**: `_effect_id_by_card_mode` holds only mode-1/4 keys, so the lookup still drops modes 2/3; the explicit check is a second line of the same rule |
| M10b | modes 2/3 admitted as the normal effect (check removed AND lookup falls back) | match_runner.gd | test_history_and_orbs_live AC 23 | RED |
| M10c | counter relay names the caster | match_runner.gd | test_history_and_orbs_live AC 23 | RED |
| M11 | halo shows one orb fewer per colour | orb_halo.gd | test_history_and_orbs_live AC 28 | RED |
| M12 | Boulder frame drawn in ORB_COLORS[0] | hud_root.gd | test_card_face AC 9 | RED |
| M13 | an art swap resizes the art slot | hud_root.gd | test_card_face AC 10 | RED |
| M14 | card mode lifts the row again | hud_root.gd | test_card_face AC 17 | RED |
| M15 | a counter strikes every entry of the slot | hud_root.gd | test_card_face R6 | RED |
| M16 | one icon's CREDITS line removed | CREDITS.txt | test_card_face AC 12 | RED |
| M17 | pitch half 4 px shorter | hud_root.gd | test_card_face AC 5 | RED |
| M18 | card mode skips slot 0's ring | hud_root.gd | test_card_mode_lift (rewritten half) | RED |
| MF1 | relay's Boulder-clear exclusion removed (F1) | match_runner.gd | test_history_and_orbs_live F1 | RED (Boulder entered both strips; the counter struck it) |
| MF1b | a Boulder clear (covered -> card) flashes again (F1) | hud_root.gd | test_card_face F1 | RED |
| MF2 | the activation flash call removed (F2) | hud_root.gd | test_card_face F2 | RED |
| MF2b | the deferred forget of a cleared stage slot removed (F2, fizzle) | hud_root.gd | test_card_face F2 stale fizzle | RED |
| MF3 | pips lit at >= 1 orb again (F3) | hud_root.gd | test_card_face F3 | RED |
| MF4 | the pitch-zone art never set (F4) | hud_root.gd | test_card_face F4 | RED |
| MF4b | the zone caption visible again (F4) | hud_root.gd | test_card_face F4 "renders words" | RED |
| MF5 | mana number rounded again (F5) | hud_root.gd | test_card_face F5 | RED |
| MF6 | normal cost rect 8 px wider (escapes the panel) (F6) | hud_root.gd | test_hud_viewports F6 | RED |
| MF6b | pip row moved up over the pitch cost (F6) | hud_root.gd | test_hud_viewports F6 | RED (overlap reported) |
| MF6c | keyword slot moved down over the normal cost (F6) | hud_root.gd | test_hud_viewports F6 | RED (overlap reported) |
| MF7 | halo never shows a decrease (F7) | orb_halo.gd | test_history_and_orbs_live F7 | RED (decrease, debug reset, round restart) |
| Mm5a | the tween restart no longer kills the running tween (m5) | hud_root.gd | test_card_face m5 | RED -- see note |
| Mm5b | the own-entry pop settle removed (m5) | hud_root.gd | test_card_face m5 | RED |
| MN10 | one CREDITS line loses its author (N10) | CREDITS.txt | test_card_face AC 12 | RED |
| MP1 | cards 12 px taller, so the hand's reach enters the debug box and the outer column (P1) | hud_root.gd | test_hud_viewports layout | RED (overlaps reported) |
| MP2 | an unpayable half is not dimmed (P2) | hud_root.gd | test_card_face P2 | RED |
| MP3 | the armed card rises only to the row lift (P3) | hud_root.gd | test_card_mode_lift | RED |
| MP4 | the flash back to 0.4 s (P4) | hud_root.gd | test_card_face P4 | RED |
| MP5a | wisps snap to their target (no inertia) (P5) | orb_halo.gd | test_history_and_orbs_live P5 | RED |
| MP5b | the wisps' clock frozen (no drift: a rigid ring) (P5) | orb_halo.gd | test_history_and_orbs_live P5 | RED |
| MP6 | honed_bolt.svg back to the crossbow-bolt header (P6) | honed_bolt.svg | test_card_face P6 | RED |

**Review fix-pass mutations: killed 15 / 15.** Provenance: code-review fix pass, same session as the review
(Opus 5.5), 2026-10-05, all before the final suite (16:58). Each run was one foreground engine launch against its test file only, restored
by copy-back from `<scratchpad>/mutbak2/` and checked against the `SHA256SUMS` taken before the first mutation (all
OK). **Mm5a note:** its first two test forms SURVIVED and are disclosed here. The first was a wall-clock 300/520 ms
check, which early headless frames' large deltas made vacuous. The second was an alpha-keyed check, which the
unkilled tween's own writes satisfied. Neither form was kept. The shipped check fires on the frame the first tween
stops being valid, and Mm5a goes RED against it. There were 5 Mm5a launches: 3 test runs and 2 scratchpad probes.

| MQ7 | every pip filled regardless of holdings (P7) | hud_root.gd | test_card_face P7/F3 | RED |
| MQ8 | the colour frame back to 3 px (P8) | hud_root.gd | test_card_face P8 | RED |
| MQ9 | no arc raise (P9) | hud_root.gd | test_card_face P9 | RED |
| MQ9b | the own pitch zone moved into the hand (P9) | hud_root.gd | test_hud_viewports layout | RED (overlap reported) |
| MQ10 | an Area3D under every wisp (P10) | orb_halo.gd | test_history_and_orbs_live P10 | RED |
| MQ11 | the rig ignores `framing_scale` (P11) | camera_rig.gd | test_camera_relative | RED |
| MQ12 | the panel not hidden at setup (P12) | match_runner.gd | test_debug_instruments | RED |
| MQ13 | the reel never stops (P13) | hud_root.gd | test_card_face P13 | RED |

| MR14 | arming never turns the frame gold (P14) | hud_root.gd | test_card_face P14/P17 | RED |
| MR15 | own pitch zone anchored at 0.2 (unequal gaps) (P15) | hud_root.gd | test_hud_viewports layout | RED |
| MR16 | no body-radius push-out (P16) | orb_halo.gd | test_history_and_orbs_live P16 | RED (0.020 m < 0.42 m) |
| MR17 | a covered slot never arms (P17) | hud_root.gd | test_card_face P17 | RED |
| MR18 | the vitals number loses its dark plate (P18) | hud_root.gd | test_card_face P18 | RED |
| MS19 | the vitals number's outline removed (P19) | hud_root.gd | test_card_face P19 | RED -- see the P19 Change Log row |
| MT20a | the debug layer never touches the StateInspectors (P20) | match_runner.gd | test_debug_instruments P20/P21 | RED (both inspectors visible by default and after the second F3) |
| MT20b | the HUD orb counters never hidden (P20) | hud_root.gd | test_debug_instruments P20/P21 | RED (both OrbCounters visible by default) |
| MT21a | the TelegraphController never hides itself (P21) | telegraph_controller.gd | test_debug_instruments P20/P21 | RED (both controllers visible by default) |
| MT21b | the gated cue sounds play with the layer hidden (P21) | telegraph_controller.gd | test_cast_success_cue_live P21 | RED (the cast-success cue played) -- the gate it pinned was REMOVED by P22; the row is history |
| MT21c | F3 never touches a live target cone (P21) | match_runner.gd | test_fireball_live P21 | RED (the cone stayed shown with F3 off) |
| MT22 | the sound gate restored: the cast-success cue plays only while the layer is shown (P22) | telegraph_controller.gd | test_cast_success_cue_live P22 | RED (the cue did not play with the layer hidden) |

**Polish-round-6 mutation (MT22): killed 1 / 1.** Provenance: polish round 6 (operator ruling P22), the same session as
round 5 (Opus 5.5), 2026-10-06, before the round-6 suite. One foreground engine launch against
test_cast_success_cue_live only, restored by copy-back from `<scratchpad>/mutbak8/` and checked against its
`SHA256SUMS` (OK).

**Polish-round-5 mutations (MT20a-MT21c): killed 5 / 5.** Provenance: polish round 5 (operator rulings P20/P21),
a fresh session after `/clear` (Opus 5.5), 2026-10-06, before the round-5 suite. Each run was one foreground engine launch against its
test file only, restored by copy-back from `<scratchpad>/mutbak7/` and checked against its `SHA256SUMS` (all OK).

**Polish-round-3 mutations (MR14-MR18): killed 5 / 5.** Provenance: polish round 3, same session (Opus 5.5),
2026-10-06, before the polish-3 suite. Each run was one foreground engine launch against its test file only, restored
by copy-back from `<scratchpad>/mutbak5/` and checked against its `SHA256SUMS` (all OK).

**Polish-round-2 mutations (MQ7-MQ13): killed 8 / 8.** Provenance: polish round 2, same session (Opus 5.5),
2026-10-06, before the polish-2 suite. Each run was one foreground engine launch against its test file only, restored
by copy-back from `<scratchpad>/mutbak4/` and checked against its `SHA256SUMS` (all OK).

**Polish-pass mutations (MP1-MP6): killed 7 / 7.** Provenance: the polish pass (operator rulings P1-P6), same session
(Opus 5.5), 2026-10-05, before the polish suite. Each run was one foreground engine launch against its test file
only, restored by copy-back from `<scratchpad>/mutbak3/` and checked against its `SHA256SUMS` (all OK).

**Killed 19 / 20** (M10 an equivalent mutant, disclosed). Provenance: this session, 2026-10-05, between 16:00
and 16:14, one engine launch per call.

#### Visual check (windowed)

Windowed 1152x648 run (scratchpad `capture_76.gd`, never committed), PNGs `C:\dev\_76-visual.png` and
`C:\dev\_76-visual-boulder.png`. Set-up: mana/orbs added on the live pools, five history entries through the real
`_relay_*` functions (one countered), a staged `grave_ward` pushed through the HUDs' own `on_pitch_changed`
(visual only), P2's controller swapped for the test fake (mode on, slot 1 armed); second frame: a Boulder covered
over P1 slot 0 via `Hand.cover_at` and re-announced through `on_cards_changed`. Seen: both halves' full hands with
two-half faces, large legible costs, affordable cards lifted, affordable pitch costs gold and the rest grey, pips
under the pitch cost, the gold armed ring, the Boulder slab (rock art, cost 2, grey frame) with the covered card
faint around it, the history strips on both outer edges (opponent entries indented with crimson rims, the strike
line, the pitch diamond), both pitch zones beside the hand, world orbs on both heroes in both halves. **Fixed after
the first capture:** the world orbs floated ABOVE the heroes' heads (the hero root is body centre, feet at -0.99;
height 1.35 -> 0.25, radius 0.75 -> 0.6, orb 0.09 -> 0.1), and the pips were too small (8 -> 10 px). No clipping or
overlap. Left to smoke: the card-mode steel ring is faint against the grey floor; the pitch zones still caption the
staged card's id as text (out of this story's ACs).

### Completion Notes List

**Tier B held.** `src/state/` byte-identical; golden + key set unmoved both directions; `project.godot`
byte-identical; no new `connect_*` seam (`test_runner_observation_seams_are_exactly_ten` unedited).

**AC status.** Headless and proven: 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 14, 15, 16, 17, 19 (regression via the
rewritten `test_card_mode_lift` forced-off half + `test_card_selection_indicator`), 21, 23, 25, 26, 28, 29, 30, 31.
Smoke-only, handed over (the windowed capture is evidence, not the verdict): 6, 13, 18, 20, 22, 24, 27, 32. The
"Live Smoke handed to the operator" task box marks the hand-over, not a run.

**Implementation decisions (HOW, within locked rulings):**
- **D2 icon key:** NOT `CardEffect.visual_id` -- writing it would have edited the effect resources the state
  layer injects (the channel the golden prediction names) and `card_effect.gd` lives in `src/state/` (AC 1). Instead
  a presentation-only `EffectIconSet` (`src/ui/hud/effect_icon_set.gd`) authored at
  `data/presentation/effect_icons.tres`, keyed by `effect_id`, rows are path strings so a swap is one line (D4). The
  runner derives `card id -> [normal effect id, pitch effect id]` load-once (`_derive_card_effect_ids`) and hands it
  plus the icon set to each HUD before `add_child` (`set_effect_art`).
- **Icons:** 15 game-icons.net SVGs under `assets/art/icons/game_icons/<effect_id>.svg`; three hand-authored SVGs
  under `assets/art/icons/authored/`; imported at `svg/scale=0.125` (64 px, the hand slot draws 42 px).
- **D1 relays:** `_relay_card_cast_resolved` (admits mode 1 and 4 only; emits the EFFECT id, never the card id)
  and `_relay_counterspell_resolved` (emits the countered slot) onto `EventBus.card_effect_resolved(slot,
  effect_id, is_pitch)` / `card_effect_countered(slot)`. The test file's existing pin held THREE `:relay` entries
  (the Dev Notes said zero); it now holds five (rule: the test file wins).
- **Card face:** 92x118 cards, halves 86x55, 2 px divider, 3 px colour frame drawn as a border-only overlay
  (`ColorSwatch`, kept by name for the 6-0/6-3b tests), coloured art backings, costs on the dark body. Strip moved to
  a plain Control so the lift is a position no container resets. Vitals column re-derived to -196..-138 (rows 18 px);
  pitch zones moved beside the hand (±202..278, -126..-8); the debug-box clearance at -196 kept.
- **R1 "no words":** the `CardName` caption is kept as the slot's hidden identity record (what five live tests read)
  and renders only the in-flight `"..."` glyph.
- **R4 Boulder:** the wrapper also passes `player.hand.to_array()` (the card layer, read inline like
  `pending_draw_owed`); a slot is covered when its visible id differs. The covered card shows its ARTS faintly; its
  costs/pips are not drawn (they would sit under the Boulder slab -- AC 8).
- **R5 flash:** ~~a slot flashes when it goes from a card/ghost to the in-flight look (any mode's cast). A Boulder play
  leaves no owed slot, so it flashes on an uncover only when this player's own colourless effect resolved in the same
  drain (a deferred pairing) -- an opponent's Boom clearing a cover does not flash.~~ **CORRECTED BY THE CODE REVIEW
  (2026-10-05, `C:\dev\_76-review.md` M2): the "any mode's cast" claim was FALSE for mode ④.** The drain delivers
  the pitch-zone clear (`match_state.gd:5746`) BEFORE the owed-slot hand payload (`:5803-5805`), so the ghost went
  ghost -> blank -> in-flight and a pitch activation never flashed (an out-of-repo probe printed `pitch activation flash
  visible (live order): false`). Modes ①-③ were correct. Fixed by operator ruling F2: a mode ①-③ cast flashes on
  card -> in-flight; a pitch activation flashes the slot its card was staged from, off its own pitch resolution; a
  fizzle never flashes. The Boulder-uncover flash was REMOVED by ruling F1 (a Boulder clear is not a played card).
- **R6 strip:** five entry panels on the outer edge (`history_on_left` handed by the runner), own flush with a bone
  rim, opponent indented with a crimson rim and a scale/brightness pop-in tween; a counter strikes the countered
  slot's newest entry; a debug reset (`round_started`) clears the strip.
- **R7 halo:** `OrbHalo` (`src/actors/hero/orb_halo.gd`) child of each hero, wired to that hero's own
  `connect_orbs_changed` (ninth seam's third consumer), hues from the hero's charge telegraph profiles, orbit by a
  looping tween (no `_process`).
- **R8:** `HudRoot.hp_display_value` = ceiling (a reading within 1e-4 of a whole number shows that number); stamina
  and mana keep their rounding.

**Flags for the operator (not deviations from AC text):**
- AC 16 is built literally: a pip is lit when at least ONE orb of its colour is held, so Grave Ward's two RED pips
  both light at one red orb. If R3's "you hold that orb" means per-pip counting, that is a one-line change.
- Existing tests rewritten because R1/R3 deliberately move what they pinned: `test_card_mode_lift` (lift ->
  ring assertions; forced-off half unchanged), `test_card_selection_indicator` (reads the `Highlight` overlay),
  `test_hud_viewports` (6-5b price-geometry check retired; face geometry now in `test_card_face`),
  `test_debug_instruments` (pitch-zone offsets).
- **Architecture-amendment candidate for the E7 close-out (D1):** two new `EventBus` signals relaying public
  cast-resolution facts off `card_cast_resolved`/`counterspell_resolved` through the `_relay_*` shape -- to be recorded
  in `game-architecture.md`'s amendment-queue ledger and `epics.md`'s E7 close-out note at close-out (not done here,
  per the Dev Notes).
- `deferred-work.md:529-531` (AC 24a cosmetic half) marked DISCHARGED in place.
- Budget: start 15:43:27 (before-baseline state file created) -> end 16:30:06 (final integration file written) =
  46m39s for the dev pass; the full-cycle figure belongs to the close-out (`E5-R/R3`).

### File List

Modified:
- `src/ui/hud/hud_root.gd`
- `src/main/match_runner.gd`
- `src/systems/event_bus.gd`
- `assets/CREDITS.txt`
- `test/state/test_architecture_invariants.gd`
- `test/state/test_deck_and_hand.gd`
- `test/integration/test_card_mode_lift.gd`
- `test/integration/test_card_selection_indicator.gd`
- `test/integration/test_debug_instruments.gd`
- `test/integration/test_hud_viewports.gd`
- `docs/implementation-artifacts/deferred-work.md`
- `docs/implementation-artifacts/sprint-status.yaml` (story_notes line only)
- `docs/implementation-artifacts/7-6-hud-and-card-presentation.md`

Added:
- `src/ui/hud/effect_icon_set.gd`, `src/ui/hud/effect_icon_set.gd.uid`
- `src/actors/hero/orb_halo.gd`, `src/actors/hero/orb_halo.gd.uid`
- `data/presentation/effect_icons.tres`
- `assets/art/icons/game_icons/*.svg` + `.svg.import` (15 each)
- `assets/art/icons/authored/{rocksling,honed_bolt,corpse_bomb}.svg` + `.svg.import`
- `test/integration/test_card_face.gd`, `test/integration/test_card_face.gd.uid` (`.uid` added by the review fix pass)
- `test/integration/test_history_and_orbs_live.gd`, `test/integration/test_history_and_orbs_live.gd.uid` (`.uid`
  added by the review fix pass)

## Change Log

| date | change |
|---|---|
| 2026-10-06 | Close-out (Tier B), a fresh session (Sonnet 5.5): five smokes passed (Live Smoke Result), Status `review` -> `done`. Four commits: code, docs, decision-log and deferred-work, board. The final suite of the last polish round is cited, not re-run. |
| 2026-10-06 | Polish round 6, same session as round 5 (Opus 5.5). **Operator ruling P22 (2026-10-06), superseding P21's sound half** (after a live look with the layer off: playing without the telegraph sounds felt blind): F3 hides only the telegraph SHAPES and the cast-target cone. Every telegraph sound plays whether the layer is on or off, exactly as before P21; the refusal sound is unchanged. **Code:** `TelegraphController`'s sound gate (`_play_cue`) is removed and every sound call is back to its pre-P21 form; `set_cues_shown` now only sets visibility and starts or stops no sound, so the looping cast alarm still starts and ends on its own cast events.<br>**Text:** AC 35 updated; MT21b marked as history.<br>**Named test changes:** test_cast_success_cue_live expects the cast-success cue to PLAY with the layer hidden. The F3 opt-ins in test_cast_presentation_live and test_charge_telegraph_dispatch_live were REMOVED, so both files are back at HEAD: their sound checks no longer need the layer, and their shape checks read each mesh's own `visible`. test_fireball_live keeps its opt-in for the cone checks.<br>**Mutation:** MT22 (the gate restored) RED, 1/1.<br>**`main.tscn`:** it carried the operator's `[3,3]` smoke flip again; it was backed up to `<scratchpad>/main.tscn.p22-smoke` and restored to HEAD.<br>**Suite:** state 1248/0/11839; integration 78/78 (21:11:48-21:17:35). Golden and key set unmoved; `src/state/` and `project.godot` untouched. No extra full run. The previous `_76-suite-final-*.txt` files were renamed to `*-prev2.txt`.<br>**Status:** stays `review`; board untouched; nothing committed. |
| 2026-10-06 | Polish round 5, a fresh session after `/clear` (Opus 5.5). **Operator rulings P20-P21 (2026-10-06):**<br>**P20:** F3 is the one debug-layer toggle. Besides the DebugInstrumentPanel it shows and hides both StateInspectors and both HUDs' orb counters. All are hidden by default and F3 shows them together; the deck indicator stays visible.<br>**P21:** every telegraph cue is in the debug layer, inventoried first (the inventory table is in the chat report). Under F3: both heroes' TelegraphControllers -- the node hides, so all its shapes hide, and every sound except `CueReject` is gated -- and the cast-target cone. Kept on: `CueReject` (a refused press shows nowhere else), the lock marker, the world orbs, every 7-1 effect look and sound, and the dagger and bolt props. The runner seat is `set_debug_layer_visible`, called by the F3 edge.<br>**Text:** ACs 29 and 35 updated.<br>**Named test changes:** test_debug_instruments (debug layer: default, F3, F3 again), test_cast_success_cue_live (silent by default; refusal still plays), test_fireball_live (cone hidden and shown by F3 mid-cast), and test_cast_presentation_live and test_charge_telegraph_dispatch_live (they turn the layer on, because they assert cue sounds).<br>**Mutations:** 5/5 killed (MT20a-MT21c).<br>**Suite:** state 1248/0/11839; integration 78/78 (20:32:53-20:38:33). Golden and key set unmoved; `src/state/`, `project.godot` and `main.tscn` untouched (`main.tscn` was already at HEAD). No extra full run. Earlier `_76-suite-final-*.txt` files were renamed to `*-prev.txt`.<br>**Status:** stays `review`; board untouched; nothing committed. |
| 2026-10-06 | Polish round 4, same session (Opus 5.5). **Operator ruling P19 (2026-10-06), superseding P18's plate:** each vitals number has no background and sits inside its bar near the RIGHT end (72 px box, 4 px inset). It is white and bold (SystemFont weight 700) with a 6 px dark outline, and stays vertically centred on the bar. Bars stay 15 px. Disclosed: the label's line box is 18 px against the 15 px bar, so the check asserts horizontal containment, right of centre and vertical centring rather than full rect containment.<br>**Text:** AC 33's P18 sentence rewritten. **Test:** test_card_face's P18 checks moved to P19's truth.<br>**Mutation:** MS19 (the outline removed) RED. Provenance: this round, 2026-10-06, one foreground launch against test_card_face only, restored from `<scratchpad>/mutbak6/` and checked against its SHA256 (OK).<br>**`main.tscn`:** at HEAD.<br>**Status:** stays `review`; board untouched; nothing committed. |
| 2026-10-06 | Polish round 3 from the operator's re-smoke, same session (Opus 5.5). **Re-smoke PASS, kept as is:** fullscreen start, P7, the arc and vitals placement, P11, wisp size, P12, P13, fps.<br>**Operator rulings P14-P18 (2026-10-06):**<br>**P14:** one card frame, 4 -> 6 px, in the card's colour; arming turns it gold with a 4 px glow, and the separate Highlight node is removed (supersedes P8's armed frame). Halves are re-derived to 116x72, with art 60, badges 42 and pips 13+3.<br>**P15:** pitch zones are card-sized (128x158), anchored at 0.25/0.75 so the gap to the hand equals the gap to the edge (42 px at 960), bottom-aligned with the outer cards; art 100 px, READY 18 px.<br>**P16:** wisps are pushed out to a 0.42 m body radius every frame; the collision pin is unchanged.<br>**P17:** a covered slot arms like any card; deferred N8 is discharged.<br>**P18:** bars 18 -> 15 px; each number is centred on its bar on a dark plate with a 4 px outline.<br>**Text:** ACs 8, 17, 21, 28 and 33 updated.<br>**Named test changes:** test_card_mode_lift (pause after the deal; the 6-0 tint check excludes the armed slot, which must show gold), test_card_selection_indicator (reads `highlight_width`), test_debug_instruments (zones at 0.25/0.75), test_hud_viewports (glow reach; card size and equal gaps), test_card_face, test_history_and_orbs_live (body radius, including a hero-steps-onto-a-wisp forcing case).<br>**`main.tscn`:** it carried the operator's `[3,3]` smoke flip again; it was backed up to the scratchpad and restored to HEAD.<br>**Mutations:** 5/5 killed. The capture `C:\dev\_76-visual-polish3.png` was checked; nothing needed fixing.<br>**Suite:** state 1248/0/11839; integration 78/78 (5m42s, 14:31:16-14:36:58); golden and key set unmoved. **Disclosed extra runs:** integration run 1 failed `test_card_tint_live` -- P14 had also turned the frame's `bg_color` (the 6-0 colour record) gold. It was fixed so only the border turns gold, the colour record stays the card's hue, and the frame draws no centre. The fix was proved by one solo re-run of that file, then the whole integration half was re-run. Run 1 is kept at `C:/dev/_76-suite-polish3-integ-run1-FAILED.txt`. The fix landed after MR14-MR18 ran; none of their anchor lines moved.<br>**Status:** stays `review`; board untouched; nothing committed. |
| 2026-10-06 | Polish round 2 from the operator's re-smoke, same session (Opus 5.5). **Re-smoke PASS, kept as is:** P1-P4, P6, Boulder, pitch-zone art, regression.<br>**Operator rulings P7-P13 (2026-10-06):**<br>**P7:** pips are always in full colour -- held filled, missing a 3 px hollow ring.<br>**P8:** a permanent card-colour frame, 4 px like the armed frame; the halves re-derived to 120x74.<br>**P9:** an arc -- the middle pair raised 48 px, the vitals beneath them (264 wide, no captions, values 14 px), pitch zones beside the hand at +/-292..368, the history strip back at its fix-pass place. Laid out for 960x1080 per half: the operator confirmed in chat the game is played fullscreen; stretch mode was measured as `disabled`, so the HUD is native pixels.<br>**`project.godot`, two named changes, nothing else moved:** `[display] window/size/mode=3` (start fullscreen) and the `debug_toggle_instruments` F3 action.<br>**P10:** wisps 0.85 -> 0.5 m; no collision of any kind, pinned.<br>**P11:** `CameraConfig.framing_scale` 1.0 -> 0.5 (distance 6 -> 3, height 3 -> 1.5); lock-on framing holds.<br>**P12:** the panel is hidden by default and toggled by F3; the 4-B1 ergonomics deferral is discharged.<br>**P13:** the slot reel, with the `EffectIconSet.slot_reel_enabled` knob.<br>**Text:** ACs 8, 16, 27 and 28 updated; ACs 33-36 added.<br>**Named test changes:** test_camera_relative and test_lock_on_live (scaled framing), test_debug_instruments (shows the panel through F3; zones centre-anchored again; panel guard limited to the window and the inspectors), test_debug_step_pause (three debug keys), test_card_mode_lift (lift measured from the arc rest), test_hud_viewports (layout at 1920x1080, per-card arc check, debug-box check dropped).<br>**Mutations:** 8/8 killed. The capture `C:\dev\_76-visual-polish2.png` (1920x1200, this monitor's native fullscreen) was checked; the bar values were enlarged after the first capture.<br>**Suite:** state 1248/0/11839 + integration 78/78 (5m40s, 12:46:37-12:52:17), golden and key set unmoved. **Disclosed extra runs:** the first polish-2 state run failed on `test_shipped_input_map_action_set_is_exactly_pinned` (P12's new action), so the pin was moved as a named change (`test_deck_and_hand.gd`). The state harness then ran twice more: once to the console, once to `C:\dev\_76-suite-polish2-state.txt`. The integration half ran once.<br>**Status:** stays `review`; board untouched; nothing committed. |
| 2026-10-05 | Polish pass from the operator's live smoke, same session (Opus 5.5). **Smoke PASS, unchanged:** Boulder cover, pitch-zone art, history strip, regression, kill/fps. **Operator rulings P1-P6 (2026-10-05)**, superseding the parts of R3, R5 and R7 they name:<br>**P1:** cards 92x118 -> 128x158; solid cost badges (30/26 px numbers); pips 13 px with 4 px gaps. The always-on debug InstrumentBox (y 356-450) leaves the hand the 196 px band below it alone. By the operator's answer in chat (2026-10-05), the vitals, both pitch zones and the history strip moved to the OUTER column (left edge in P1's half, right in P2's, x < 236), and the round-over label was narrowed and raised to y 160-220.<br>**P2:** affordability is brightness per half -- dimmed and desaturated vs full colour with a glowing rim.<br>**P3:** card mode lifts the row 6 px; the armed card lifts 24 px with a 4 px gold frame.<br>**P4:** the flash is 1.0 alpha with a glow, held 0.12 s, 0.7 s in total.<br>**P5:** orbs are soft drifting wisps that follow with inertia -- the first `_process` in `src/`, in `src/actors/`; the ban is `src/ui/`'s.<br>**P6:** Honed Bolt's SVG is a lightning bolt.<br>**Text:** ACs 14-17, 18, 22, 27 and 28 rewritten to today's truth.<br>**Tests:** test_card_face, test_card_mode_lift, test_debug_instruments (outer-anchored zones), test_hud_viewports (live half-screen layout check: no overlaps, inside the viewport, clear of the debug box and the inspector; the deck/inspector 2 px band, present since 2-6, is the one disclosed exemption) and test_history_and_orbs_live (wisp probe).<br>**Mutations:** 7/7 killed. A windowed capture `C:\dev\_76-visual-polish.png` was checked and fixed before the suite (wisps enlarged and alpha-blended). Two capture-script bugs were found and fixed; they were in the scratch script, not the game.<br>**`src/main/main.tscn`:** it carried the operator's smoke edit `slot_controller_kinds = [3, 3]`, which broke the keyboard-driven tests. It was restored to HEAD on the operator's instruction, with a backup kept in the scratchpad.<br>**Status:** stays `review`; board untouched; nothing committed. |
| 2026-10-05 | Code review (`gds-code-review`, report `C:\dev\_76-review.md`) and fix pass, same session (Opus 5.5).<br>**Fixes:** operator rulings F1-F7 applied: Boulder clears leave the history strip; pitch-activation flash; pips fill by count; pitch-zone art; mana floor; live-tree geometry restored; halo reset and restart tests. Also m5, N2, N4, N5 and N10 fixed. N6, N8 and N11 deferred to `deferred-work.md`; N1, N3, N7 and N9 dismissed with reasons (Review Findings).<br>**Mutations:** 15/15 killed. Mm5a's two earlier test forms survived and were replaced (disclosed).<br>**Suite:** final run 1248/0/11835 + 78/78 (`C:\dev\_76-suite-fix-{state,integ}.txt`). The integration half took 5m38s (16:59:00-17:04:38). Golden and key set unmoved; `src/state/` and `project.godot` untouched.<br>**Records:** the false R5 "any mode's cast" Completion Note was corrected in place. Status stays `review`; board untouched. Nothing committed. |
| 2026-10-05 | Dev pass (`gds-dev-story`, Opus 5.5): R1-R9/D1-D4 implemented -- two-half card face, effect-keyed icons (15 game-icons.net + 3 hand-authored), affordability lift/brightness/pips, frame highlights, Boulder cover, play flash, history strip via two new EventBus relays, world orb halos, HP ceiling. Suite 1248/0/11834 + 76/76 -> 1248/0/11835 + 78/78; golden and key set unmoved; 19/20 mutations killed (1 equivalent). Status `ready-for-dev` -> `review` (story file only; board stays `ready-for-dev`). Nothing committed. |
| 2026-10-05 | Operator decisions D1-D4 applied: `7-6/OQ-1` resolved by D1 (the history strip relays `card_cast_resolved`/`counterspell_resolved` onto two new ownerless `EventBus` signals, the `reshuffle_vulnerable_window_opened` relay shape verbatim — verified against the repo before editing: the relay precedent, the `EventBus` signal-count pin, the raw-connect shape pin and `HudRoot`'s existing bus subscriptions all held as described); `7-6/OQ-2` resolved by D2 (icon-field HOW left to the dev pass); D3 confirms one story, span-two-sessions allowed; D4 adds AC 32 (three hand-authored SVG icons). ACs 23-25 rewritten from gated to definite; AC 26 added (the two pins D1 moves); AC 32 added (D4); renumbered 23-32 with no dangling gates. Open Questions section removed (both resolved). Scope note, M3 and Dev Notes rewritten from BLOCKING language to D1's resolution, measurements kept. Status `authored` -> `ready-for-dev`; board `backlog` -> `ready-for-dev`; story_note reduced to one true line. Cleared for a dev pass. |
| 2026-10-05 | Authored by `gds-create-story` against `c4c5981`: operator rulings R1-R9 carried verbatim; M1-M7 measured (geometry, cost/colour seam, the raw-connect channel gap for the history strip, orb seam, HP display defect, skill coverage, file-count estimate); `7-6/OQ-1` raised as a blocking open question (history strip needs a cross-slot read the architecture doc's own amendment trail says the next story should raise rather than build silently); `7-6/OQ-2` raised non-blocking (icon field HOW). Status `authored`; board stays `backlog`; NOT cleared for a dev pass. |
