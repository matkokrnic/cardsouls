# Story 3.6: Card HUD — hand, mana, deck and reshuffle indicators

Status: ready-for-dev

## Story

As a player,
I want the 4-card hand, mana bar, and deck/reshuffle indicators rendered in the real half-width HUD, signal-driven, with the opponent's hand face-down,
so that whether the card layer is readable during live combat is assessed and written down — a P4 finding, not a styling choice.

## Acceptance Criteria

1. `OpponentHandStrip` and its construction path are deleted from `hud_root.gd`. The own-hand row (`HandStrip`, reserved in 2-4) is populated with real cards, face-up, using the existing 2-5 privacy seat (`_make_card_face_style(true)`). No new rendering path for the own row.
2. A new per-slot observation seam — the runner's eighth `connect_*` method — delivers, as one payload: this player's hand contents (card ids, in hand order), deck count, and discard count. Queued and drained after `advance()`, exactly like the six existing per-slot seams. Card container contents/order still never enter `to_snapshot()` — this is a live push, not a state read. `test_runner_observation_seams_are_exactly_seven` becomes `test_runner_observation_seams_are_exactly_eight`.
3. The mode-select affordance (already shipped end-to-end by 3-5a via `HudRoot.set_card_selection`) is judged against P4 at half width during a live exchange: can the reactor read it without reading a menu? No new rendering code is expected for this AC — the work is the judgment call and the `docs/playtest-log.md` entry.
4. Deck-count and reshuffle indicators: deck count comes from AC2's seam. The reshuffle vulnerable-window flag renders from `EventBus.reshuffle_vulnerable_window_opened(slot)` alone, driving a presentation-local countdown seeded once by `BalanceConfig.reshuffle_vulnerable_window_seconds` (handed to `HudRoot` at construction, the `gamepad_profile`/`huds` static-handoff precedent) — no new state read, no new snapshot key. Both viewports subscribe to the same ownerless event; each renders it against its own slot.
5. The HUD stays signal-driven: everything updates from queued signals drained after `advance()`, no polling, no per-frame economy recompute.
6. This story owns final card-strip sizing/layout and may grow the own row's footprint beyond the 2-4 reservation (measured slack: 344px container / 320px content / 24px). Card ART and a card display-name field are out of scope for every scheduled story; render `CardData.id` as text.
7. Verified in the real half-width viewport during a live exchange: hand contents, mana level, and deck/reshuffle state are all identifiable at a glance. The result is written to `docs/playtest-log.md` by the operator's own hand — no agent writes that entry on the operator's behalf.

## Deferred

**Reveal-opponent-hand toggle — NOT in this story (3-6/R1).** `E3-RG/R4` deletes `OpponentHandStrip` outright; there is no opponent-hand rendering left for a toggle to flip, so building the toggle here means a whole new debug-only rendering path, not a flip of an existing seat as `E3-RG/R5` assumed. Deferred with a home, not cancelled: cheap once AC2's seam ships (hand ids become available for free), owned by the first future story that touches `src/ui/hud/` card rendering. Not an E3 exit criterion; no story number assigned yet.

## Tasks / Subtasks

- [ ] Delete `OpponentHandStrip` + construction path; populate `HandStrip` with real cards via AC2's seam (AC: 1)
- [ ] Add the eighth `connect_*` seam (hand ids + deck count + discard count, one payload); update the seven-seam guard to eight (AC: 2)
- [ ] Judge the already-shipped mode-select affordance against P4; log the finding (AC: 3)
- [ ] Deck-count indicator from AC2's seam; reshuffle flag from `EventBus.reshuffle_vulnerable_window_opened` driving a presentation-local timer seeded by `reshuffle_vulnerable_window_seconds` (AC: 4)
- [ ] Keep the HUD signal-driven; no polling (AC: 5)
- [ ] Finalize card-strip sizing; render `CardData.id` as text (AC: 6)
- [ ] Verify readability live; operator records `docs/playtest-log.md` by hand (AC: 7)

## Dev Notes

- The own row reuses the 2-5 privacy seat (`_make_card_face_style(true)`) and the 2-4 reserved footprint; the opponent row is deleted, not reused or hidden. [Source: decision-log.md E3-RG/R4, 3-6/R1]
- AC2 is a genuinely new seam. The runner's `connect_*` family was frozen at seven by `2-6/R7` and machine-checked by `test_runner_observation_seams_are_exactly_seven` — this story is the operator-approved exception (3-6/R2), not a refactor, and the guard's name/count must move with it.
- Reshuffle vulnerability stays public: both viewports subscribe to the same ownerless bus event (E3-RG/R3). The window itself stays WRITE-ONLY, unhashed state (3-5b/R20) — the HUD renders from the event plus an authored duration, never by reading the window's tick count (3-6/R3). Its mechanical cost remains a separate open decision, unresolved here.
- `CardData` carries no display-name or art field; `id` (e.g. `bramble_snare`) is the accepted text (3-6/R4). Card ART stays unowned by every scheduled story.
- AC3's rendering already exists (3-5a, `match_runner.gd` calling `HudRoot.set_card_selection`); this story adds no new code for it (3-6/R5) — only the P4 judgment and its log entry.
- Playtest-log entries are written by the operator's own hand; no AC here authorizes an agent to produce one. [Source: decision-log.md 2-6/R11, 2-4/R12, 2-5/R8]

### Project Structure Notes

- `src/ui/hud/hud_root.gd`: remove the opponent row; wire the new seam's callback; add the reshuffle presentation timer; accept `reshuffle_vulnerable_window_seconds` at construction.
- `src/main/match_runner.gd`: add the eighth `connect_*` method and its relay wiring (mirrors the six existing per-slot seams); hand the reshuffle duration to each `HudRoot` at construction.
- `test/state/test_architecture_invariants.gd`: `OBSERVATION_SEAMS` grows to eight; the guard test is renamed to match.

### Project Context Rules

- **Signal-driven HUD; no polling / per-frame economy recompute.** [Source: docs/project-context.md#Signals over polling]
- **Affordability read, not computed** (Reactor/Actor). [Source: gdd.md#Reactor / Actor principle]

### References

- [Source: stories-manual-e3.md#E3.S6]
- [Source: gdd.md#Legibility Principle; #P4]
- [Source: stories-manual-e2.md#E2.S4; #E2.S5]
- [Source: decision-log.md E3-RG/R3-R6; 3-5b/R20; 3-6 readiness gate]

## Golden Prediction

**UNMOVED, argued.** `CanonicalHash` is computed from `to_snapshot()` dictionaries only — no hash code path reads a signal emission. AC2's seam reads existing `Hand`/`Deck`/`DiscardPile` state and pushes it as a plain payload: it adds no snapshot key (card contents/order stay excluded, the pinned 3-0c AC11 rule), consumes no RNG, and reorders nothing inside `advance()`. Deleting `OpponentHandStrip` touches no state field either — it never read `hand` (2-5/R1). What WOULD move it: giving the reshuffle window a mechanical cost, the standing obligation carried from 3-5b — not done here. Baseline is whatever 3-5b leaves it at (`40eb5554...a322`).

## Live Smoke

**REQUIRED, full two-human, half-width viewport — `R-D6` re-invoked (3-6/R6).** Available since 3-5a spent it; correctly not re-invoked by 3-5b/3-0c/3-0d, which shipped no player-facing surface. This is the first HUD-facing story since. Confirm: the deleted opponent row leaves no visual gap; own-hand contents (rendered as `id` text), mana level, and deck/reshuffle state are identifiable at a glance during a live exchange; the reshuffle flag turns off on its own via the presentation-local timer, never sticking on; final card-strip sizing does not collide with the bars, pitch placeholder, or deck indicator. Record the readability verdict in `docs/playtest-log.md`, operator's own hand, before the commit chain.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
