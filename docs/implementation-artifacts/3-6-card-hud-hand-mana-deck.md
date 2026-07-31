# Story 3.6: Card HUD — hand, mana, deck and reshuffle indicators

Status: backlog

> **⚠ E3 REVISIT GATE applies (see 3.1 for the full verbatim gate).** These E3 stories are provisional and must be reviewed against `docs/playtest-log.md` after the first E1/E2 playtest, before implementation — confirm, amend, or delete, and record the outcome in `decision-log.md`.
>
> **Revisit note (this story).** Provisional — confirm or amend against `docs/playtest-log.md` before implementing. Whether the hand is readable at half width during an exchange is a P4 finding, not a styling preference.

## Story

As a player,
I want the 4-card hand, mana bar, and deck/reshuffle indicators rendered in the real half-width HUD, signal-driven, with the opponent's hand face-down,
so that whether the card layer is readable during live combat is assessed and written down — a P4 finding, not a styling choice.

## Acceptance Criteria

1. **The opponent face-down row (`OpponentHandStrip`) is DELETED, not populated.** It was PROVISIONAL from 2-5 on and was never to be anchored by anything built in E3 (2-5/R3; `epics.md:110-111`: "nothing built in E3 may anchor to it; it may be deleted outright"; 2-6/R9); the E3 revisit gate rules it deleted outright (decision-log E3-RG/R4) — it carries no information while hand size is fixed, crowds an already-tight half-width viewport, and rendered a count whose publicity was never decided. The own hand strip reserved in 2.4 IS populated with real cards, face-up, inside the existing per-viewport privacy rule from 2.5. No new rendering path for the OWN row; the slot whose privacy behaviour already works is used for it alone.
2. The mode-selection affordance from 3.5 is rendered in the HUD at half width and judged against P4: during an exchange the reactor must never be reading a menu. If it cannot be read at speed, that is a finding for `docs/playtest-log.md` (operator's own hand, never an agent — see Dev Notes) and `decision-log.md`, not a font shrink.
3. Deck-count and reshuffle indicators are added, with the vulnerable window from 3.3 flagged in **both** viewports over the ownerless `EventBus` event ruled at the E3 revisit gate (decision-log E3-RG/R3) — NOT via the deleted opponent-hand row and NOT via any per-slot HUD seam, which is structurally opponent-blind. Reshuffle vulnerability is public information by design.
4. The HUD stays signal-driven per D5: everything updates from queued signals drained after `advance()`, no polling, no per-frame economy recompute. Affordability is *read*, not computed by the player (the Reactor/Actor offload that E6's pitch affordability display inherits).
5. **The reveal-opponent-hand toggle** (deferred from 2-5, per 2-5/R4) is a named acceptance criterion of this story. Its trigger rides the `DebugInstrumentPanel` (2-6's presentation-local switch mechanism) — not a new Input Map action, not a `FeatureFlags` member — flipping the SAME single seat that already decides face-up/face-down styling, `HudRoot._make_card_face_style(is_own)` (decision-log E3-RG/R5).
6. **Card strip sizing.** This story owns final sizing/layout of the card strip and MAY grow its footprint beyond what 2-4 reserved — 2-4 reserved the space, this story finalizes it. Measured slack to design against: own row (`HandStrip`) 344px container / 320px content / 24px slack; the deleted opponent row's 236px/232px/4px no longer constrains anything (decision-log E3-RG/R6). Card ART stays unowned by this or any other scheduled story.
7. Verified in the real viewport: at final resolution and half width, identify hand contents, mana level, and deck state during an actual exchange. The result is written to `docs/playtest-log.md` **by the operator's own hand** — no agent writes into that log on the operator's behalf (2-6/R11, 2-4/R12, 2-5/R8 precedent, all restated at the E3 revisit gate); this AC requires the operator entry exist, it does not authorize an agent to produce it.

## Tasks / Subtasks

- [ ] Delete `OpponentHandStrip` and its construction path; populate the 2.4 own-hand strip with real cards inside the 2.5 face-up rule (AC: 1)
- [ ] Render the 3.5 mode-select affordance at half width; judge against P4, log findings (AC: 2)
- [ ] Add deck-count + reshuffle indicators; subscribe to the E3-RG/R3 EventBus event for the vulnerable-window flag in both viewports (AC: 3)
- [ ] Keep the HUD signal-driven; affordability read, not computed (AC: 4)
- [ ] Wire the reveal-opponent-hand toggle to `DebugInstrumentPanel`, flipping `HudRoot._make_card_face_style`'s existing seat (AC: 5)
- [ ] Finalize card-strip sizing/layout against the measured slack; may grow beyond the 2.4 reservation (AC: 6)
- [ ] Verify readability during a live exchange; operator records the result in `docs/playtest-log.md` by hand (AC: 7)

## Dev Notes

- Reuses the 2.5 face-up privacy rule and the 2.4 reserved footprint for the OWN row only — no new card rendering path for it. The opponent row is deleted, not reused. [Source: stories-manual-e2.md#E2.S4; #E2.S5; decision-log.md E3-RG/R4]
- Reshuffle vulnerability is **public** — flagged in both viewports over the ownerless `EventBus` event (E3-RG/R3), not the deleted opponent-hand row. (Its *mechanical cost* remains OPEN decision (b), logged since 2026-07-22 — this story does not resolve it.) [Source: stories-manual-e3.md#E3.S6 item 3; #E3.S3 item 4; decision-log.md E3-RG/R3]
- Readability at half width during an exchange is a P4 finding for the log, not a styling fix. [Source: gdd.md#P4; #Reactor / Actor principle]
- **The presentation-local hand COUNT is retired; hand contents become data-driven.** 2-5's `OpponentHandStrip` rendered a presentation-local constant 4 (2-5/R1) — that constant, and the row itself, are retired by this story. The OWN row's card count was never a separate constant; it becomes driven by real `PlayerState.hand` contents as of this story.
- **No seam exists yet for own-hand CONTENTS (not just size).** Verified by content: the seven-plus-`round_started` observation-seam family (2-4/R1, 2-6/R7 "no eighth seam") exposes HP/stamina/mana/action-state/hit/deflect/round events — nothing carries card identity, and the HUD may never hold a `PlayerState`/state handle (the banned-token/no-handle rule, 2-4/R1's rejected-alternatives list). Designing that seam is NOT done in this docs pass — it is recorded here as a FINDING for this story's own readiness gate to resolve, not invented now.
- Playtest-log entries are written by the operator's own hand; no AC in this story authorizes an agent to produce one. [Source: decision-log.md 2-6/R11, 2-4/R12, 2-5/R8]

### Project Structure Notes

- `src/ui/hud/` extends the reserved regions (own-hand row only — the opponent row is removed from `hud_root.gd`); consumes queued signals + the E3-RG/R3 EventBus event; log at `docs/playtest-log.md` by the operator's hand.

### Project Context Rules

- **Signal-driven HUD; no polling / per-frame economy recompute.** [Source: docs/project-context.md#Signals over polling]
- **Affordability read, not computed** (Reactor/Actor). [Source: gdd.md#Reactor / Actor principle]

### References

- [Source: stories-manual-e3.md#E3.S6]
- [Source: gdd.md#Legibility Principle; #P4]
- [Source: stories-manual-e2.md#E2.S4; #E2.S5]

## Golden Prediction

**NONE, measured in both directions — conditional.** This story is `src/ui/` presentation plus the
`DebugInstrumentPanel` reveal-toggle wiring; it consumes existing seams (economy signals, the new
E3-RG/R3 EventBus event) and reads `PlayerState.hand`/mode-select state for rendering only. Deleting
`OpponentHandStrip` touches no state field (2-5/R1: the row never read `hand`, only a presentation
constant) and adding the reveal toggle touches no `FeatureFlags` member (2-6/R4). What WOULD move it: any
state-side field added to back the reveal toggle or the deleted row (both prohibited, same as 2-5's own
golden note). Baseline is whatever 3-1 through 3-5 leave it at.

## Live Smoke

**REQUIRED, full two-human, half-width viewport, never full-width** — the reason split-screen was pulled
forward to E2 (2-4/R11 precedent). Confirm: the deleted opponent row leaves no visual gap or dead space;
own-hand contents, mana level, and deck/reshuffle state are all identifiable at a glance during a live
exchange; the reveal-opponent-hand toggle flips visibly and only the intended row; final card-strip sizing
does not collide with the bars, pitch placeholder, or deck indicator (2-5/R12 slack precedent). Record the
readability verdict in `docs/playtest-log.md`, operator's own hand, before the commit chain — an AC-level
obligation, not something this section itself satisfies.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
