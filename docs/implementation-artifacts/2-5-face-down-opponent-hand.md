# Story 2.5: Information-model integrity — face-down opponent hand

Status: done

## Story

As a player sharing one display with my opponent,
I want each viewport to render its own hand face-up and the opponent's hand face-down by default, with the Pitch Zone card the single public exception,
so that bluffing stays observable under the real information model and E3 cannot accidentally leak by adding a card widget.

## Acceptance Criteria

1. Each HUD root renders its owning player's hand face-up and the opponent's hand face-down. The face-up / face-down decision is made in ONE SEAT: a single parameter of one private construction function in `src/ui/hud/hud_root.gd`, so a later reveal toggle is a flip of that parameter and not a second rule.
2. The rendered card count is a presentation-local constant `4`. `src/ui/` contains no read of `PlayerState.hand`, no read of a `hand_size` field, and no write to `hand`.
3. No HUD root instance is ever constructed with the opposing slot's index. Pinned by test in `test/integration/test_hud_viewports.gd` — extending the existing per-slot binding assertion from 2-4 if one already covers this shape, rather than adding a duplicate.
4. Layout: the opponent row sits top-centre, above the Pitch Zone placeholder, between the deck indicator and the orb counters. The bottom-centre `HandStrip` from 2-4 is neither moved nor resized. No other reserved 2-4 element moves.
5. `src/ui/` gains no new file. `src/ui/debug/` still contains only its `.gitkeep` after this story. No new observation seam. No `.tscn` edit. Both rows are built once at setup, with no `_process`, no `_physics_process`, and no signal consumption.
6. The Pitch Zone placeholder is explicitly excluded from the face-down rule and is the single documented public exception. 2-5 renders no pitched card — there is no card data to render.
7. `test/integration/test_hud_viewports.gd` gains assertions that each viewport contains both rows, that the own row is front-styled, that the opponent row is back-styled, and that the two stylings are genuinely different rather than two identical blank panels. The integration suite still globs to 8 files.
8. The operator's own playtest-log entry for 2-5 exists in `docs/playtest-log.md` before the commit chain begins, written by hand regardless of whether the smoke produced findings. No agent writes it on the operator's behalf.

## Tasks / Subtasks

- [x] Implement the single-seat face-up/face-down rule in `hud_root.gd`: one private construction function taking a parameter for whether a row belongs to the owning slot; own hand renders face-up, opponent hand renders face-down (AC: 1)
- [x] Implement the rendered card count as a presentation-local constant `4`; confirm no read of `PlayerState.hand`, no read of `hand_size`, no write to `hand` anywhere in `src/ui/` (AC: 2)
- [x] In `test/integration/test_hud_viewports.gd`, FIRST check whether an equivalent per-slot binding assertion already exists from 2-4 and extend it rather than duplicate it; the extended (or new) assertion must prove no HUD root instance is ever constructed with the opposing slot's index (AC: 3)
- [x] Lay out the opponent row top-centre, above the Pitch Zone placeholder, between the deck indicator and the orb counters, at its own real footprint; verify the bottom-centre `HandStrip` from 2-4 is neither moved nor resized and no other reserved 2-4 element moves (AC: 4)
- [x] Confirm zero new files under `src/ui/`; confirm `src/ui/debug/` still contains only its `.gitkeep`; confirm zero new observation seams and zero `.tscn` edits; build both rows once at setup with no `_process`, no `_physics_process`, no signal consumption (AC: 5)
- [x] Exclude the Pitch Zone placeholder from the face-down rule as the single documented public exception; confirm 2-5 renders no pitched card (AC: 6)
- [x] In `test/integration/test_hud_viewports.gd`, add assertions that each viewport contains both rows, the own row is front-styled, the opponent row is back-styled, and the two stylings are genuinely different; keep the integration suite globbing to 8 files; demonstrate the new assertion fails without the back-styling, then restore and verify byte-for-byte via SHA256 (AC: 7)
- [x] Confirm the operator has written the `docs/playtest-log.md` entry for 2-5 by hand before the commit chain begins (AC: 8)

## Dev Notes

- The information model is a **design commitment, not a testing artefact**. Because split-screen physically exposes both hands on one display, the HUD **must be able** to render the opponent's hand face-down — a required E2 structural capability, not a later feature. Skipping it makes bluffing unobservable under full information and invalidates the P3 playtests it exists to serve. [Source: docs/game-architecture.md#Technical Requirements — Information-model integrity; stories-manual-e2.md#E2.S5]
- One rule, one place → E3's real cards inherit privacy instead of re-deciding it. [Source: stories-manual-e2.md#E2.S5 item 1]
- **Ground truth from the gate, carried forward:** `src/state/player_state.gd` already declares `var hand: Array = []`, permanently empty until epic 3, and `to_snapshot()` already emits `"hand_size": hand.size()`, currently `0`. This is a golden trap — making the rendered count "real" by populating `hand` would move the golden hash AND breach the epic-3 hold. There is no `hand_size` field in balance data anywhere; the GDD states hand size is 4 at all times.
- The architecture doc sanctions both this story's features: the E2 HUD layer must be able to render the opponent's hand face-down in each player's own viewport, and a reveal-opponent-hand toggle is listed among debug tools gated behind a debug flag (not built this story — see 2-5/R4).
- No debug flag exists anywhere in code; `FeatureFlags` carries only gameplay-layer booleans (mana generation, unblockable, orbs, pitch zone, minions, totems, equipment). Adding a presentation-only member there would be the first non-gameplay member of a gameplay-layer flags resource, against established precedent.
- The Input-only-in-controllers invariant scan covers all of `src/` and skips only paths containing `/controllers/` — an `Input.` read inside `src/ui/debug/` WOULD fail the scan. Record this for whoever builds the epic-3 toggle: the trigger must arrive through a controller or a flag, never a direct input read in the UI layer.
- `src/ui/hud/hud_root.gd` reserves exactly one hand region from 2-4: an `HBoxContainer` named `HandStrip`, centre-aligned, anchored bottom-centre, holding four empty `Panel`s named `Card0..Card3` sized 74x84. Other 2-4 reserved placeholders — the Pitch Zone panel plus Pitch Timer dead-centre, three orb counter panels top-right, a deck indicator top-left, and a hidden round-over label centre — are unaffected by this story.
- Baseline: 156 state tests / 715 assertions, 8 integration files passing individually, golden `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` unmoved since story 1-9.

### Presentation-local constant (2-5/R1)

The rendered card count is a PRESENTATION-LOCAL CONSTANT `4`. No read of `PlayerState.hand`, no read of `hand_size`, no write to `hand`, no card widget bound to card data. Authority for the constant is the GDD statement that hand size is 4 at all times. Epic 3 makes it data-driven; that is a named follow-up here, not a passing remark. [Source: gdd.md#Card System]

### Public & symmetric — not an opponent read (2-5/R2)

Hand size is PUBLIC AND SYMMETRIC, therefore rendering the opponent's row is NOT an opponent read. Both hands always hold the same number of cards and that number is public by design, so a constant (and later a balance-authored value, still symmetric) carries zero bits of the opponent's state. The per-slot bind in `hud_root.gd` remains the mechanism that makes opponent reads structurally impossible. CONSEQUENCE for the acceptance criteria: the criterion that asked for a grep of the HUD layer for cross-player `PlayerState` access is REMOVED as a mechanism and replaced by the assertion that a HUD root never receives the opposing slot at all.

### Two hand rows per viewport (2-5/R3)

The own hand renders face-up on the bottom-centre strip already reserved by 2-4 (not moved or resized). The opponent hand renders face-down TOP-CENTRE, above the Pitch Zone placeholder, between the deck indicator on the left and the orb counters on the right. Opponent panels may be smaller than own panels, because card backs carry nothing to read. Nothing else in the reserved layout moves: not the bars, not the orb counters, not the pitch placeholder, not the deck indicator, not the round-over label. Rationale: the architecture doc requires the opponent hand to be renderable face-down in each viewport, and a single-row variant would leave the rule unexercised until epic 3; the design pillar of visible threat with uncertain delivery depends on seeing that the opponent holds resources. Exact placement and sizing are PROVISIONAL — the A/B comparison of HUD placement across development phases belongs to story 2-6, which owns the instrumentation.

### Reveal toggle deferred to epic 3 (2-5/R4)

The reveal-opponent-hand toggle is DEFERRED to epic 3, and the acceptance criterion requiring it is removed from 2-5. Reasons: there are no card faces to reveal, so the toggle could only flip blank placeholders to other blank placeholders; a guard test over it could not be proven to fail without it, and this project's standing rule is that every new guard must be demonstrated to FAIL when the thing it protects is removed (temporarily remove, measure the failure, restore byte-for-byte and verify with SHA256); and no debug flag exists, so gating it would mean adding the first non-gameplay member to a gameplay-layer flags resource, against the established precedent that presentation configuration lives in its own resource outside the gameplay/balance surface. CONDITION OF THE DEFERRAL: the face-down rule must live in ONE SEAT in 2-5 — a single parameter or branch that decides back-styling versus front-styling — so that the epic-3 toggle is a flip of that parameter and not a second rule. `src/ui/debug/` stays empty. Permanent constraint for whoever builds the toggle later: an `Input.` read inside `src/ui/debug/` FAILS the input-only-in-controllers invariant scan, so the trigger must arrive through a controller or a flag, never a direct input read in the UI layer.

### Zero new files — single construction function (2-5/R5)

ZERO new files under `src/ui/`. Both rows are built by `src/ui/hud/hud_root.gd` through one private construction function parameterised by whether the row is the owning slot's. The existing existence guard for `hud_root.gd` and the recursive banned-token scan over `src/ui/` already cover it; no new guard wiring is required. Extracting a separate file would be premature — if `hud_root.gd` becomes unwieldy during the dev pass, that is a review question, not a spec change.

### Zero new seams, static construction (2-5/R6)

ZERO new observation seams, ZERO `.tscn` edits, STATIC construction. The rows are built once during setup, with no `_process`, no `_physics_process`, and no signal consumption — exactly like the reserved footprint that preceded them. The seam family stays at seven plus the round-ended relay. Any `.tscn` edit is out of scope and would be a blocking review finding, because the Godot GUI editor is banned for this project.

### Tests (2-5/R7)

Tests go into the existing `test/integration/test_hud_viewports.gd`; the integration baseline stays at 8 files. Assertions: each viewport contains both rows; the own row is front-styled and the opponent row is back-styled; the two stylings are genuinely different rather than two identical blank panels. The new assertion must be PROVEN to fail without the back-styling — temporarily remove it, measure the failure, restore the file byte-for-byte and verify with SHA256 — otherwise the guard is vacuous.

### Golden hash and live smoke (2-5/R8)

The story carries a Golden Hash section and a Live Smoke section (below). The smoke runs on the SHIPPED configuration and therefore contains NO flip line; the committed main scene has no `slot_controller_kinds` line and the script default already gives two live killable human slots. The story RE-INVOKES the standing smoke-acceptance allowance (which was spent on the previous story) because the criteria can only be satisfied by an operator's live look: whether both rows fit inside a half-width viewport without overlapping the bars, the pitch zone, the orb counters or the deck indicator; and whether backs are distinguishable from fronts at a glance. The operator writes the playtest-log entry by hand, in `docs/playtest-log.md`, BEFORE the commit chain — no agent ever writes it on the operator's behalf.

### Pitch Zone criterion rephrased neutrally (2-5/R9)

The acceptance criterion naming the Pitch Zone is rephrased NEUTRALLY: the card staged in a Pitch Zone is the only public card. Whether the Pitch Zone is shared between players or owned per player is an epic-6 decision, undecided anywhere, and out of 2-5 scope. Decision-log labels for this story are 2-5/R1..R9; the previous story's descriptively named close-out entries are NOT corrected retroactively.

### Project Structure Notes

- Visibility rule and both hand rows live entirely in `src/ui/hud/hud_root.gd` — no new file under `src/ui/`.
- `src/ui/debug/` stays empty this story; the reveal toggle is deferred to epic 3.
- `test/integration/test_hud_viewports.gd` gains the new row/styling assertions; the integration suite baseline stays at 8 files.

### Project Context Rules

- **HUD never reads the opponent's `PlayerState`** (D5 presentation-only, and the privacy habit) — satisfied structurally, not by a grep mechanism. [Source: docs/game-architecture.md#D5; stories-manual-e2.md#E2.S3 item 3]
- Debug tools mutate nothing; this story adds none. [Source: docs/game-architecture.md#Debug Tools]
- **Signal-driven HUD, no per-frame recompute:** both rows are static constructions, not signal consumers. [Source: docs/project-context.md#Signals over polling]

### References

- [Source: stories-manual-e2.md#E2.S5]
- [Source: gdd.md#Card System; #Legibility Principle]
- [Source: docs/game-architecture.md#Technical Requirements — Information-model integrity; #Debug Tools]
- [Source: decision-log.md — 2-5 readiness gate, this session]

## Golden Hash

- **Current:** `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2`, unmoved since 1-9.
- **Prediction: NONE, to be MEASURED IN BOTH DIRECTIONS during the dev pass.** 2-5 is presentation-only under `src/ui/` — two placeholder hand rows per viewport driven by a presentation-local constant `4`, consuming no new seam and touching no state code. The snapshot already contains a `hand_size` field, currently `0`, and it must remain `0` on the golden path.
- **What would move the hash:** any write to `hand`, or any new state-side field added to back the count — both are epic-3-hold violations and are stop-and-report, never a re-baseline.
- **Measurement plan:** record the golden before implementation; re-run the determinism test after and confirm the hash is identical; as a positive control, confirm the snapshot's `hand_size` is still `0`.
- **Baseline to hold:** 156 state tests / 715 assertions plus 8 integration files run INDIVIDUALLY.

## Live Smoke

- Runs on the shipped default `slot_controller_kinds = [0, 1]` (two live killable humans) — no flip line, no manual `.tscn` edit of any kind.
- Measured in the HALF viewport, never full-width.
- What the operator checks: whether both rows fit inside a half-width viewport without overlapping the bars, the pitch zone, the orb counters or the deck indicator; and whether backs are distinguishable from fronts at a glance.
- **R-D6 smoke acceptance is RE-INVOKED by this story** (live smoke against killable human slots) and becomes SPENT again only on a pass.
- The operator writes the `docs/playtest-log.md` entry by hand, BEFORE the commit chain — no agent writes it on the operator's behalf.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8

### Debug Log References

### Completion Notes List

- **Constructor micro-decision.** `HudRoot._init()` (`src/ui/hud/hud_root.gd`) takes no
  arguments at all — it only sets `name = "HudRoot"`. AC3's requirement that "no HUD root
  instance is ever constructed with the opposing slot's index" is therefore satisfied
  STRUCTURALLY: the constructor makes passing any slot, own or opposing, impossible in the
  first place. The asymmetry assertion in `test_hud_viewports.gd` (rolling P1 moves only P1's
  HUD stamina bar) proves a different, and more useful, property — that the runner's per-slot
  wiring (in `match_runner.gd`) is uncrossed. The test does not, and should not be read to,
  prove the acceptance criterion itself; the criterion is closed by the constructor's shape.

- **Layout slack, measured from source.** The opponent row's `OpponentHandStrip` container is
  236 px wide (`offset_right - offset_left` = 118 - (-118)); its four 52x64 card panels plus
  three 8 px separations occupy 4*52 + 3*8 = 232 px of content, leaving 4 px of slack. The own
  row's `HandStrip` container is 344 px wide (172 - (-172)); its four 74x84 panels plus
  separations occupy 4*74 + 3*8 = 320 px, leaving 24 px of slack. Recorded so a later sizing or
  separation change has a documented margin before it collides with either container edge.

- **Styling-direction fix.** Review found the first styling assertion in
  `test_hud_viewports.gd` NON-DIRECTIONAL: it proved only that the two rows' stylings
  differed, so swapping them — showing the player's own hand as a back and the opponent's as a
  face — would still have passed, which is exactly the information leak this story exists to
  prevent. The fix (`_check_hand_rows`) pins the direction structurally: the face-down
  opponent back must carry the strictly heavier border than the face-up own card
  (`back_is_heavier`), in addition to the pre-existing difference check. Non-vacuity for this
  fix was proven by SWAPPING the two branches of `_make_card_face_style` (own vs. opponent
  colors/border widths exchanged) — the run showed the difference check still true but the
  direction check false, i.e. FAIL, demonstrating the old assertion would have passed the
  inversion. The file was restored from a copy taken outside the repo, not via `git checkout`,
  and verified byte-for-byte via SHA256 before re-running the suite.

### File List

- src/ui/hud/hud_root.gd
- test/integration/test_hud_viewports.gd

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-28 | 0.1 | Gate fixes: rulings 2-5/R1..R9 applied (presentation-local hand-count constant, opponent-read non-issue via public/symmetric hand size, two-row face-down/face-up layout, reveal toggle deferred to epic 3, Pitch Zone exception rephrased neutrally); promoted backlog -> ready-for-dev. | Claude Sonnet 5 |
| 2026-07-28 | 0.2 | Dev pass: both hand rows built through the single-seat `_build_hand_row(is_own)` function; face styling pinned directional (opponent back strictly heavier-framed) after review found the original assertion non-directional; suite 156/715 + 8 integration files unmoved, golden hash unmoved. | Claude Opus 4.8 |
