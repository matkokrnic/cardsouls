# Story 3.6: Card HUD — hand, mana, deck and reshuffle indicators

Status: ready-for-dev

> **⚠ E3 REVISIT GATE applies (see 3.1 for the full verbatim gate).** These E3 stories are provisional and must be reviewed against `docs/playtest-log.md` after the first E1/E2 playtest, before implementation — confirm, amend, or delete, and record the outcome in `decision-log.md`.
>
> **Revisit note (this story).** Provisional — confirm or amend against `docs/playtest-log.md` before implementing. Whether the hand is readable at half width during an exchange is a P4 finding, not a styling preference.

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want the 4-card hand, mana bar, and deck/reshuffle indicators rendered in the real half-width HUD, signal-driven, with the opponent's hand face-down,
so that whether the card layer is readable during live combat is assessed and written down — a P4 finding, not a styling choice.

## Acceptance Criteria

1. The hand strip reserved in 2.4 is populated with real cards inside the existing per-viewport privacy rule from 2.5 — own hand face-up, opponent's face-down. No new rendering path for cards; the slot whose privacy behaviour already works is used.
2. The mode-selection affordance from 3.5 is rendered in the HUD at half width and judged against P4: during an exchange the reactor must never be reading a menu. If it cannot be read at speed, that is a finding for `docs/playtest-log.md` and `decision-log.md`, not a font shrink.
3. Deck-count and reshuffle indicators are added, with the vulnerable window from 3.3 clearly flagged in **both** viewports — reshuffle vulnerability is public information by design.
4. The HUD stays signal-driven per D5: everything updates from queued signals drained after `advance()`, no polling, no per-frame economy recompute. Affordability is *read*, not computed by the player (the Reactor/Actor offload that E6's pitch affordability display inherits).
5. Verified in the real viewport: at final resolution and half width, identify hand contents, mana level, and deck state during an actual exchange, and record whether it was possible in `docs/playtest-log.md`.

## Tasks / Subtasks

- [ ] Populate the 2.4 hand strip with real cards inside the 2.5 privacy rule (AC: 1)
- [ ] Render the 3.5 mode-select affordance at half width; judge against P4, log findings (AC: 2)
- [ ] Add deck-count + reshuffle indicators; flag the vulnerable window in both viewports (AC: 3)
- [ ] Keep the HUD signal-driven; affordability read, not computed (AC: 4)
- [ ] Verify readability during a live exchange; record in `docs/playtest-log.md` (AC: 5)

## Dev Notes

- Reuses the 2.5 face-down privacy rule and the 2.4 reserved footprint — no new card rendering path. [Source: stories-manual-e2.md#E2.S4; #E2.S5]
- Reshuffle vulnerability is **public** — flagged in both viewports. (Its *mechanical cost* remains the open question logged in 3.3 / `decision-log.md`.) [Source: stories-manual-e3.md#E3.S6 item 3; #E3.S3 item 4]
- Readability at half width during an exchange is a P4 finding for the log, not a styling fix. [Source: gdd.md#P4; #Reactor / Actor principle]

### Project Structure Notes

- `src/ui/hud/` extends the reserved regions; consumes queued signals; log at `docs/playtest-log.md`.

### Project Context Rules

- **Signal-driven HUD; no polling / per-frame economy recompute.** [Source: docs/project-context.md#Signals over polling]
- **Affordability read, not computed** (Reactor/Actor). [Source: gdd.md#Reactor / Actor principle]

### References

- [Source: stories-manual-e3.md#E3.S6]
- [Source: gdd.md#Legibility Principle; #P4]
- [Source: stories-manual-e2.md#E2.S4; #E2.S5]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
