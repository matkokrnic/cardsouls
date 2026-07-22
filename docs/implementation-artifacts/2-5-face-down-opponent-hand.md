# Story 2.5: Information-model integrity — face-down opponent hand

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player sharing one display with my opponent,
I want each viewport to render its own hand face-up and the opponent's hand face-down by default, with the Pitch Zone card the single public exception,
so that bluffing stays observable under the real information model and E3 cannot accidentally leak by adding a card widget.

## Acceptance Criteria

1. A per-viewport visibility rule in the HUD layer: each HUD root knows which player it belongs to and renders that player's hand face-up and the opponent's hand **face-down**. The rule lives in one place, so E3 cannot leak by adding a card widget.
2. The face-down representation is implemented now against the reserved hand region from 2.4 — placeholder card backs, correct count, correct footprint. E3 populates real cards into a slot whose privacy behaviour already works.
3. The exception is modelled explicitly, not by omission: the Pitch Zone card is the *only* public card and renders face-up in both viewports, written as the single documented exception so E6 inherits the rule.
4. A debug reveal-opponent-hand toggle is added behind the `debug` flag in `src/ui/debug/`. It changes only presentation and mutates nothing. It defaults **off** so the default playtest condition is the real information model.
5. Verified by inspection and test: with the toggle off, no face-up card data of the opponent is rendered in a player's viewport, and no HUD code path reads the opponent's `PlayerState` directly (grep the HUD layer for cross-player access).

## Tasks / Subtasks

- [ ] Implement the single per-viewport own-face-up / opponent-face-down rule (AC: 1)
- [ ] Render face-down card backs at the reserved 2.4 footprint (AC: 2)
- [ ] Model the Pitch Zone card as the single documented public exception (AC: 3)
- [ ] Add the `debug`-flag reveal toggle (presentation-only, default off) (AC: 4)
- [ ] Verify no opponent face-up leak and no HUD cross-player `PlayerState` read (AC: 5)

## Dev Notes

- The information model is a **design commitment, not a testing artefact**. Because split-screen physically exposes both hands on one display, the HUD **must be able** to render the opponent's hand face-down — a required E2 structural capability, not a later feature. Skipping it makes bluffing unobservable under full information and invalidates the P3 playtests it exists to serve. [Source: docs/game-architecture.md#Technical Requirements — Information-model integrity; stories-manual-e2.md#E2.S5]
- One rule, one place → E3's real cards inherit privacy instead of re-deciding it. [Source: stories-manual-e2.md#E2.S5 item 1]

### Project Structure Notes

- Visibility rule in `src/ui/hud/`; reveal toggle in `src/ui/debug/` (no state mutation).

### Project Context Rules

- **HUD never reads the opponent's `PlayerState`** (D5 presentation-only, and the privacy habit). [Source: docs/game-architecture.md#D5; stories-manual-e2.md#E2.S3 item 3]
- Debug tools mutate nothing. [Source: docs/game-architecture.md#Debug Tools]

### References

- [Source: stories-manual-e2.md#E2.S5]
- [Source: docs/game-architecture.md#Technical Requirements; #Debug Tools]
- [Source: gdd.md#Card System]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
