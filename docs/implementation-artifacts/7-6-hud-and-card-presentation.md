---
baseline_commit: c4c5981c93fcf5dc2c45fec1d279604daedf2f70
---

# Story 7-6: HUD / Card Presentation Redesign

Status: ready-for-dev

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
   cost's text.
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

14. **(headless)** A card's lift state is true exactly when its normal mana cost is currently
    affordable (driven by the hero's own live mana reading) and false otherwise.
15. **(headless)** A card's pitch-cost brightness state is true exactly when its pitch mana cost is
    currently affordable, independent of the normal-cost lift state.
16. **(headless)** Each orb pip's lit state is true exactly when the player currently holds at least
    one orb of that pip's colour.
17. **(headless)** Card-mode-on and the armed slot are rendered as a frame highlight, never as a
    lift — the lift state (AC 14) and the frame-highlight state are visually distinct and can be
    true simultaneously without collapsing into one look.
18. **(smoke)** The three states (affordability lift, pitch brighten, mode/armed highlight) read as
    distinguishable from one another in the running game.
19. **(headless)** Both existing `6-10` hold-to-select and toggle settings still produce the same
    card-mode/armed behaviour as before this story (regression).

**Boulder (R4)**

20. **(smoke)** A Boulder in a hand slot shows its own art and a clearly readable cost; the card it
    covers remains faintly visible underneath.
21. **(headless)** Toggling (pressing the card-mode key for) a Boulder-covered slot produces no
    visible mode-cycle indication on that slot — the existing `REASON_COVERED_SLOT` refusal at commit
    is unchanged, and this AC covers only the cosmetic symptom named in `deferred-work.md:529-531`.

**Play echo (R5)**

22. **(smoke)** The hand slot a player just cast from flashes briefly and distinctly after the cast.

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

27. **(smoke)** Each hero shows one floating orb per held orb, in that orb's colour, visible in both
    split-screen halves simultaneously.
28. **(headless)** The world orb presenter's displayed count for a hero always equals that hero's own
    live orb counts from `connect_orbs_changed`, per colour.
29. **(headless)** The existing HUD orb counters (top-right, per-viewport) are unchanged by this
    story (regression); whether they are kept, in light of R7, is a smoke judgement call per the
    ruling, not a removal this story performs.

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

- [ ] Before-measurement: suite, golden, snapshot key set, `git diff --stat -- src/state/` (AC 1, 2)
- [ ] Resize the own-hand card panel to fit R1's two-equal-halves face; re-derive every offset anchored
      against it (vitals column, pitch zones, 6-10 lift constants) (AC 5-10, M1)
- [ ] Source/ingest placeholder icons (game-icons.net, CC BY 3.0) for 14 Deck 1 effects + Boulder;
      tint; credit in `assets/CREDITS.txt` (AC 11-13, R2)
- [ ] Hand-author three SVG icons (Rocksling, Honed Bolt, Corpse Bomb) and wire them as the shown
      icon, keeping the game-icons.net versions as a one-line data swap (AC 32, D4)
- [ ] Key art lookup by effect identity, not card identity (AC 11); pick the icon-key field per D2
      (`visual_id` reuse vs. a new export)
- [ ] Wire affordability: lift from live mana vs. normal cost, brighten from live mana vs. pitch cost,
      per-pip lit from live orb holdings; keep card-mode/armed as a frame highlight, distinguishable
      from both (AC 14-19, M2)
- [ ] Boulder look (own art, faint covered card) and the AC 24a cosmetic fix: no mode-cycle tell on a
      covered slot (AC 20-21)
- [ ] Own-play slot flash (AC 22)
- [ ] Add the two `_relay_*` sites and `EventBus` signals per D1; wire both `HudRoot`s' history strip
      off them: both players' last ~5 resolutions, opponent pop-in, distinct opponent look, countered
      strike-through (AC 23-26)
- [ ] World-space per-hero orb presenter wired to each hero's own `connect_orbs_changed`, visible in
      both viewports by construction (AC 27-28); keep the HUD orb counters unchanged (AC 29)
- [ ] HP display: ceil instead of round in `HudRoot._apply_bar` (AC 30-31)
- [ ] Discharge `deferred-work.md:529-531` (Boulder mode-cycle cosmetic line) once AC 21 is proven
- [ ] Record D1's new `EventBus` signals as an architecture-amendment candidate for the E7 close-out
      (see Dev Notes)
- [ ] After-measurement: full suite, golden, snapshot key set (AC 1, 2)
- [ ] Live Smoke handed to the operator (AC 6, 13, 18, 20, 22, 24, 27, 32 — see Live Smoke below)

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

Not yet run — story is `ready-for-dev`, awaiting the dev pass.

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

Not yet run.

### Debug Log References

### Completion Notes List

### File List

## Change Log

| date | change |
|---|---|
| 2026-10-05 | Operator decisions D1-D4 applied: `7-6/OQ-1` resolved by D1 (the history strip relays `card_cast_resolved`/`counterspell_resolved` onto two new ownerless `EventBus` signals, the `reshuffle_vulnerable_window_opened` relay shape verbatim — verified against the repo before editing: the relay precedent, the `EventBus` signal-count pin, the raw-connect shape pin and `HudRoot`'s existing bus subscriptions all held as described); `7-6/OQ-2` resolved by D2 (icon-field HOW left to the dev pass); D3 confirms one story, span-two-sessions allowed; D4 adds AC 32 (three hand-authored SVG icons). ACs 23-25 rewritten from gated to definite; AC 26 added (the two pins D1 moves); AC 32 added (D4); renumbered 23-32 with no dangling gates. Open Questions section removed (both resolved). Scope note, M3 and Dev Notes rewritten from BLOCKING language to D1's resolution, measurements kept. Status `authored` -> `ready-for-dev`; board `backlog` -> `ready-for-dev`; story_note reduced to one true line. Cleared for a dev pass. |
| 2026-10-05 | Authored by `gds-create-story` against `c4c5981`: operator rulings R1-R9 carried verbatim; M1-M7 measured (geometry, cost/colour seam, the raw-connect channel gap for the history strip, orb seam, HP display defect, skill coverage, file-count estimate); `7-6/OQ-1` raised as a blocking open question (history strip needs a cross-slot read the architecture doc's own amendment trail says the next story should raise rather than build silently); `7-6/OQ-2` raised non-blocking (icon field HOW). Status `authored`; board stays `backlog`; NOT cleared for a dev pass. |
