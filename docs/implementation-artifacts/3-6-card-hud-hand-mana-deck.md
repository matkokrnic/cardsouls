---
baseline_commit: c6357be918bbd16ee7ed91879a15d74d2b40803b
---

# Story 3.6: Card HUD — hand, mana, deck and reshuffle indicators

Status: in-progress

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

- [x] Delete `OpponentHandStrip` + construction path; populate `HandStrip` with real cards via AC2's seam (AC: 1)
- [x] Add the eighth `connect_*` seam (hand ids + deck count + discard count, one payload); update the seven-seam guard to eight (AC: 2)
- [ ] Judge the already-shipped mode-select affordance against P4; log the finding (AC: 3) — **operator's, pending the live smoke**
- [x] Deck-count indicator from AC2's seam; reshuffle flag from `EventBus.reshuffle_vulnerable_window_opened` driving a presentation-local timer seeded by `reshuffle_vulnerable_window_seconds` (AC: 4)
- [x] Keep the HUD signal-driven; no polling (AC: 5)
- [x] Finalize card-strip sizing; render `CardData.id` as text (AC: 6)
- [ ] Verify readability live; operator records `docs/playtest-log.md` by hand (AC: 7) — **operator's, R-D6 re-invoked**

### Review Findings

- [x] [Review][Patch] Reshuffle timer callback may fire against a freed `HudRoot` [src/ui/hud/hud_root.gd:on_reshuffle_vulnerable_window_opened] — fixed, `is_instance_valid` guard
- [x] [Review][Patch] Deck/reshuffle labels lack overflow protection unlike card captions [src/ui/hud/hud_root.gd:_build_deck_indicator] — fixed, `clip_text` + ellipsis trim added
- [x] [Review][Defer] Hand row hard-coded to 4 slots with silent truncation if `hand_ids` ever exceeds 4, no `Invariant.check` [src/ui/hud/hud_root.gd:on_cards_changed] — deferred, pre-existing (2-5/R1 constant-4 assumption predates this story); **CLOSED by `3-6/R8`** — `test_balance_authoring.gd::test_authored_deck_and_hand_counts_are_sane` gained `hand_size <= 4`, so an authored 5 now fails the suite loudly instead of the HUD truncating silently

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

Claude Opus 5 (dev pass, 2026-08-06).

### Rulings this pass

- **`3-6/R7` — the observation seam is OWN-SLOT ONLY; the reshuffle FLAG is the only public card
  fact.** Operator ruling, taken mid-pass against AC 4's "each renders it against its own slot".
  Both viewports subscribe to the ownerless event and each renders it in BOTH directions
  (`RESHUFFLE` for its own slot, `OPP RESH` for the other's) — the `on_round_ended`
  YOU WIN / YOU LOSE precedent, and the delivery of `E3-RG/R3`'s "vulnerability is public".
  But deck and discard COUNTS stay private: the eighth seam carries no slot index and each HUD is
  bound to one slot, so a root is structurally incapable of reading the opponent's counts. Reason
  given: this is exactly why `E3-RG/R4` deleted the opponent hand row — it rendered a count whose
  publicity was never decided, and the GDD makes the pitched card the only public card
  information.

### Debug Log References

Mutation table (every target backed up out-of-repo and SHA256-verified restored; `git checkout --`
never used). All twelve confirmed FALLING:

| # | Mutation | Guard that failed |
|---|---|---|
| M1 | drop the DEAL announcement seat | `test_card_observation.gd` deal / reset / queued-drain (3 tests) |
| M2 | drop the CAST announcement seat | `test_a_cast_announces_the_shortened_hand_and_the_grown_discard` |
| M3 | drop the DELIVERY announcement seat | `test_the_delayed_delivery_announces_the_refilled_hand` |
| M4 | announce every tick (the polling regression) | `test_a_tick_that_moves_no_card_announces_nothing` (+4 payload-count tests) |
| M5 | bind the LIVE hand array instead of a copy | `test_the_announced_hand_is_a_copy_...` |
| M6 | rename `connect_cards_changed` off the family | `test_runner_observation_seams_are_exactly_eight` |
| M7 | add `func _process` to `hud_root.gd` | `test_ui_layer_never_polls_per_frame` (new) |
| M8 | cross-wire the seam so both roots read slot 0 | `test_card_hud.gd` `hands_differ` |
| M9 | skip writing the VACATED caption ("ghost card") | *initially caught NOTHING* — see below |
| M10 | flag never clears itself | `test_card_hud.gd` `flag_cleared` |
| M11 | resurrect an `OpponentHandStrip` node | `test_card_hud.gd` `opp_row_deleted` + `test_hud_viewports.gd` |
| M12 | collapse the face/back privacy branches | `test_hud_viewports.gd` direction pin |

**M9 found a real coverage hole and the hole was closed, not excused.** Nothing in the suite
failed when the vacated hand slot kept its old caption — the state of the HUD after a cast, while
the replacement draw is in flight, was unproven. A caption left behind is a card the player can
see and cannot cast, which is worse than an empty slot. `test_card_hud.gd` gained
`vacated_cleared` / `refill_rewrote` and M9 was re-run against them: FAILS.

### Completion Notes List

- **AC 1 — done.** `OpponentHandStrip` and its construction path are deleted; `_build_hand_row`
  lost its `is_own` parameter and calls `_make_card_face_style(true)`, the unchanged 2-5/R4
  privacy seat. The `false` branch of that seat is KEPT with no caller, deliberately: it is what
  makes the deferred reveal toggle (`3-6/R1`) inherit a made decision instead of re-deciding
  privacy. `test_hud_viewports.gd`'s 2-5 two-row assertion is rewritten as a DELETION assertion
  (absence from the tree, not invisibility) plus the same direction pin, now taken against a
  tree-less `HudRoot` probe since there is no second row to read it off.
- **AC 2 — done, the eighth seam.** `PlayerState.cards_changed(hand_ids, deck_count,
  discard_count)`, queued on the shared `SignalQueue` and drained after `advance()`;
  `MatchRunner.connect_cards_changed(slot, callback)` wraps it per slot with the same slot guard
  and the same PRIME-ON-CONNECT as the three economy seams. `PlayerState` gained its first signal
  and therefore its first `_queue` reference — classified in `test_replay_identity.gd`'s PER_TICK
  bucket beside the four sibling `_queue` references, not as a fourth unhashed-cross-tick
  exclusion (that pin caught the new member and is what forced the classification to be stated).
  Three announcement seats, one per seat that moves a card: the deal, the cast, the delayed
  delivery. `test_runner_observation_seams_are_exactly_seven` → `..._eight`, list and message
  moved with it.
- **AC 3 — NOT DONE, and not doable by an agent.** The rendering already exists (3-5a); the work
  is the P4 judgment during a live exchange and the `docs/playtest-log.md` entry, which is the
  operator's own hand (2-6/R11, 2-4/R12, 2-5/R8).
- **AC 4 — done.** Deck count from the seam's payload. The reshuffle flag renders from
  `EventBus.reshuffle_vulnerable_window_opened` alone plus the authored
  `reshuffle_vulnerable_window_seconds`, handed to each `HudRoot` before `add_child` on the
  `gamepad_profile` / `huds` static-handoff precedent. The countdown is a ONE-SHOT
  `SceneTreeTimer` — no `_process`, no per-frame work, and no read of `PlayerState`
  `vulnerable_window`, which stays write-only unhashed state (3-5b/R20, 3-6/R3). A generation
  TOKEN guards the overlap: a second reshuffle inside the first one's window is not switched off
  early by the first one's timer.
- **AC 5 — done, and promoted from review-checked to machine-checked.** `2-4/R9` left "no
  `_process` in the HUD" to review; this story is the first to hand the HUD a time-varying
  element, so `test_ui_layer_never_polls_per_frame` now bans `func _process` under `src/ui/`
  (F1 already covers `_physics_process`). Proven falling by M7.
- **AC 6 — done.** Card strip finalized at 84x92 panels in a 368-wide container (4 * 84 + 3 * 8 =
  360 of content), grown UPWARD to `offset_top -112` — the vitals column's bottom edge is at
  -116 and the -20 bottom margin is unchanged, so nothing else in the reserved layout moves.
  A card renders `CardData.id` as word-wrapped, ellipsis-trimmed text (`3-6/R4`).
- **AC 7 — NOT DONE.** Requires the two-human half-width live smoke; `R-D6` is re-invoked
  (`3-6/R6`) and is the operator's to spend. Nothing in this pass writes the playtest log.
- **Golden UNMOVED**, exactly as predicted and for the predicted reason: the channel adds no
  snapshot key, consumes no RNG and reorders nothing inside `advance()`. Pinned executably by
  `test_the_observation_channel_adds_no_snapshot_key`, which fails if a later change folds hand
  contents into the snapshot.
- **Suite 352 tests / 2270 assertions + 22 integration files → 362 / 2304 + 23**
  (`test/integration/test_card_hud.gd` added). Zero SCRIPT ERROR / Parse Error / INVARIANT
  VIOLATED. `project.godot` untouched — this story adds no Input Map action and no autoload.
- **Board status not advanced.** `sprint-status.yaml` lifecycle is locked to
  backlog → ready-for-dev → done, so 3-6 stays `ready-for-dev` on the board until the smoke and
  the push; the story file carries the working status instead.

### File List

- `src/state/player_state.gd` (modified) — `cards_changed` signal, retained `_queue`,
  `notify_cards_changed()`.
- `src/state/match_state.gd` (modified) — three announcement seats (`_deal_player`,
  `_resolve_basic_cast`, `_draw_one_replacement`).
- `src/main/match_runner.gd` (modified) — `connect_cards_changed` (the eighth seam), its HUD
  wiring, the reshuffle-duration handoff, the per-viewport bus subscription.
- `src/ui/hud/hud_root.gd` (modified) — opponent row deleted, own row rebuilt with captions and
  final sizing, live deck indicator + reshuffle flag, `on_cards_changed`,
  `on_reshuffle_vulnerable_window_opened`, `_clear_reshuffle_flag`.
- `test/state/test_card_observation.gd` (new) — the channel's state-side contract, 9 tests.
- `test/integration/test_card_hud.gd` (new) — the live chain, 10 properties.
- `test/state/test_architecture_invariants.gd` (modified) — seam family 7 → 8 with the guard
  renamed; new `test_ui_layer_never_polls_per_frame`.
- `test/state/test_replay_identity.gd` (modified) — `player_state._queue` classified PER_TICK.
- `test/integration/test_hud_viewports.gd` (modified) — two-row assertion → deletion assertion +
  direction pin against a tree-less probe.
- `test/integration/test_deck_reshuffle.gd` (modified) — comment-only: its header's claim that the
  deck readout is a placeholder and the window has no renderer is now false.
- `docs/implementation-artifacts/3-6-card-hud-hand-mana-deck.md` (modified) — this record,
  `baseline_commit`, checkboxes, Status.

### Change Log

- 2026-08-06 — Dev pass: ACs 1, 2, 4, 5, 6 implemented and mutation-proven; ACs 3 and 7 left to
  the operator's live smoke. Golden unmoved. Suite 352/2270 + 22 → 362/2304 + 23.
