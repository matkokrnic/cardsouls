# Story 3.5a: Card-mode selection input and Basic (Mode ①) resolution

Status: ready-for-dev

> **Scope note.** The E3 revisit gate has RUN (2026-07-31, decision-log Session 2026-07-31 — E3
> revisit gate (outcome), rulings E3-RG/R1..R12); this story was amended per that outcome in commit
> `10b96a1`. This story then split from the single `3-5` slot into `3-5a` (this file, THE TRIGGER)
> and `3-5b` (WHAT THE TRIGGER MAKES REACHABLE) at its own readiness gate (2026-08-04, commit
> `257e4d3`) and passed that same gate after the fixes recorded in this revision.

## Story

As a player,
I want to select a card and play it in Mode ① under real-time pressure, paying mana through `CardCastCondition`, with the E5/E6 modes left as guarded stubs,
so that the card layer resolves as far as E3 honestly goes without inventing minions, orbs, or pitch.

## Acceptance Criteria

1. The mode-select scheme lives entirely in `src/controllers/`. The state layer receives only:
   selected hand slot, selected mode, and a commit. Pinned by a negative guard — no card-scheme
   symbol appears outside `src/controllers/`. Keyboard only this story; no gamepad profile fields.
2. Card actions are READ at step 6 of `advance()`, not ingested at step 1 (step 1 ingests only the
   debug reset). Modes beyond the basic one are guarded stubs and are unreachable in E3, pinned by a
   negative-path test. Guard helper is `Invariant.check` — `check_invariant` names no real symbol
   anywhere in this repo.
3. Every cast is gated through `CardCastCondition`, evaluated by a new pure static evaluator at
   `src/state/economy/cast_evaluator.gd` — a SIBLING of the existing economy evaluator, not a second
   block inside it (that file declares itself the one place resource-generation rules are read, which
   is a generation-side identity). It COMPUTES and does not APPLY: it returns a `StringName` reason,
   empty meaning the cast is allowed. The pool applies the spend inside `advance()`'s ordered
   dispatch.
4. Card costs reach the state layer through a new one-shot injection seam on `MatchState`, on the
   deck-injection precedent: called once at match start, content only, no reload path. ONE
   match-wide map, not per player — 3-3 locked that both players receive the same injected
   composition. The seam validates at injection time with `Invariant.check` that every id in the
   injected composition has an entry, which makes an unknown id at cast time unreachable rather than
   a new crash guard. The map NEVER reaches `to_snapshot()`.
5. Basic-mode resolution, in one tick: the mana is spent through the pool's existing spend call, the
   card leaves the hand, it goes to the discard pile, a replacement is drawn immediately, and the card
   effect is emitted. Instant refill — no delay field, no countdown, this story.
6. Hand gains a removal method (today it exposes only add/clear/size/is_empty/to_array, and
   `to_array` returns a duplicate, so no caller can remove through it). A discard pile ships as a
   third pure container owned by `PlayerState` alongside `Deck` and `Hand`. The snapshot gains exactly
   one new key, the discard COUNT — no ids, no per-card structure.
7. An unaffordable cast is rejected through the SHIPPED action-rejected signal and the existing
   per-slot observation seam that already carries the insufficient-stamina rejections, with a card
   action name and a reason token. No new signal, no new seam, seam count unchanged.
8. A DEAD player cannot cast, and a cast submitted on a round-over frozen tick is dropped silently
   with no rejection signal — consistent with every other intent during the freeze, which returns
   before step 2. Both pinned by tests. NOTE for the second half: nothing in this story spans ticks,
   so there is nothing in flight to abort; when the delayed replacement draw arrives in 3-5b, it must
   tick out and deliver nothing rather than being cancelled, because an early-stop path would reopen
   the locked 1-9 invariant obligation that windows on a dead hero run to expiry and simply deliver
   nothing.
9. The mode enum lives in the state layer's existing enum file beside the card colour enum. The
   resolution dispatch is a PRIVATE `MatchState` function called at step 6 — not a free function and
   not a new class — because the mutation must stay inside `advance()`'s ordered dispatch where every
   other mutation lives.
10. A selection indicator is added to the existing placeholder card row: which slot is armed and
    which mode is armed. Presentation-local, no new seam, no read of `PlayerState.hand` (the row's
    count-of-four stays the presentation-local constant), no resize, no card identity, no cost
    display. Card contents, sizing and layout remain 3-6's.
11. New card actions are added to the Input Map textually with the editor CLOSED, `project.godot`
    SHA256 recorded before and after, and the diff reviewed. Action names carry the per-player prefix
    in the Input Map and are PREFIX-FREE by the time they reach the intent, per the existing key
    contract.
12. Negative guard: no pitch/stage action ships. The staging verb belongs to the pitch zone, which is
    an E6 flag and is off; a reserved action with no consumer is deleted, on the retired-pose-id
    precedent.

## Tasks / Subtasks

- [ ] Extend `InputIntent` with card fields (slot, mode, commit); implement ONE keyboard mode-select
      scheme entirely in `src/controllers/`; negative-guard test for no card-scheme symbol outside it
      (AC: 1)
- [ ] Read card actions at step 6 of `advance()`, never ingest at step 1; guard the E5/E6 `ModeKind`
      branches with `Invariant.check`; negative-path unreachability test (AC: 2)
- [ ] Build `src/state/economy/cast_evaluator.gd` as a pure static sibling of `EconomyEvaluator`,
      returning an empty-or-reason `StringName`; the pool applies the spend (AC: 3)
- [ ] Add the one-shot match-wide card-cost injection seam on `MatchState`, `Invariant.check` on
      every injected id at injection time, excluded from `to_snapshot()` (AC: 4)
- [ ] Resolve Basic mode in one tick: spend mana, discard, instant replacement draw, emit `CardEffect`
      (AC: 5)
- [ ] Add `Hand` removal method; add a third pure discard-pile container on `PlayerState`; snapshot
      gains a discard COUNT key only (AC: 6)
- [ ] Reject an unaffordable cast through the shipped `action_rejected` signal and its existing
      per-slot seam — no new signal, no new seam (AC: 7)
- [ ] DEAD cannot cast; a cast on a frozen round-over tick drops silently; both pinned by tests (AC: 8)
- [ ] Add the mode enum to `src/state/enums.gd` beside `CardColor`; dispatch as a private `MatchState`
      function at step 6 (AC: 9)
- [ ] Add a presentation-local selection indicator (armed slot, armed mode) to the existing card row;
      no new seam, no hand read, no resize (AC: 10)
- [ ] Add the new card actions to the Input Map textually, editor closed, `project.godot` SHA256
      before/after, diff reviewed; per-player prefix stripped before reaching the intent (AC: 11)
- [ ] Negative guard: delete the reserved pitch/stage action; no consumer ships this story (AC: 12)

## Dev Notes

- Only Mode ① lands in E3; ②/③ are E5 and ④ is E6 — their `resolve()` branches stay guarded stubs (a resolved summon queuing an unconsumed signal is the correct E3 state; a fake placeholder actor is not). [Source: stories-manual-e3.md#Before you start; #E3.S5a item 4; docs/game-architecture.md#Novel Pattern 6]
- Mode-select scheme is the controller's concern so swapping it touches only `src/controllers/`. The card-mode-select UX is an open, high-P4 question — implement one provisional scheme, do not treat it as settled. [Source: gdd.md#Controls — Card-mode selection UX; stories-manual-e3.md#E3.S5a item 1]
- Cast gating via `CardCastCondition`, never inline mana compare; orbs-off degrades to mana-only. [Source: docs/game-architecture.md#D6]
- **Input Map ownership.** The earlier ruling that new `project.godot` Input Map actions "land here and only here" bound only 3-0b's deterministic step/pause actions (E3-P/R2) — it was never meant to freeze the Input Map for the whole epic, and the E3 revisit gate amended that wording to read as scoped, not absolute (decision-log E3-RG/R7). This story may add its own card actions (play/stage/cancel, per-mode binds) under the same discipline already used for controller-facing actions elsewhere: named actions, textual edit with the editor closed, diff reviewed. [Source: decision-log.md E3-RG/R7]
- **Input shape the operator intends (INTENT, not a binding contract).** A held cast modifier on the
  left stick click so the right thumb stays free for the mode buttons, cards on the four shoulders,
  release exits instantly so the escape into a roll costs no extra press. The right stick click and
  the face buttons need the same thumb, which is exactly why the modifier cannot be held there
  either. Four cards on four buttons assumes a hand of exactly four, which is an OPEN decision — a
  named consequence of the intended layout, not an oversight.
- **Gamepad half deferred.** The shipped default is two keyboards and the smoke runs on the shipped
  default, so keyboard-only costs the smoke nothing. Gamepad card input is authored data on the
  gamepad profile, not Input Map entries, and its forcing point is the first smoke run on pads.
- **Two inherited obligations nobody had listed anywhere.** 3-3 fixed the meaning of "top" as the
  back of the pile and handed that meaning to this story. Both players receive the same injected
  composition through one seam, which constrains the cost-injection seam (AC4) to a single
  match-wide map, not a per-player one.
- **The melee tuning retune lands AFTER this smoke, not before**, as its own golden-neutral balance
  commit. Reason: the criterion (a round should finance 2-4 loop cycles) is unjudgeable until cycles
  per round can actually be counted, which is exactly why its forcing point was moved here.
- **The evaluator-sibling rationale.** `cast_evaluator.gd` sits beside `economy_evaluator.gd` rather
  than inside it because `EconomyEvaluator`'s own header declares it "THE one place
  `ResourceGenerationRule`s are read" — a generation-side identity a cost-gating read would
  contradict if folded in. The card price itself is a LITERAL on `CardCastCondition.mana_cost`, not a
  `BalanceConfig` field — per-card content, not a game-wide tunable, the same reasoning that keeps a
  card's copy cap off `BalanceConfig` (3-2 gate).
- **The eighth member of the architecture amendment queue.** The Novel Pattern 6 section
  (`docs/game-architecture.md`) is written as if it were shipped code and is wrong three ways: its
  card-data sketch omits the `id` and `max_copies` fields, both load-bearing (already the SIXTH queue
  member, recorded at the 3-2 gate, for the same sketch); it presents a mode enum and a `resolve()`
  function as free-standing with no owning class named, neither of which exists anywhere in `src/`
  (this story puts the enum on `Enums` and the dispatch as a private `MatchState` method, per AC9);
  and it names a guard helper, `check_invariant`, that names no real symbol — a defect already
  corrected in this story's own text (at the revisit gate) but NOT in the architecture document
  itself. The seventh member's conditional clause (if a vulnerable-window signal ever lands, the
  `EventBus` header and seam registry need reconciling) now attaches to 3-5b, not here, since the
  vulnerable window is 3-5b's scope.

### Project Structure Notes

- `InputIntent` in `src/state/input/`; card fields produced in `src/controllers/`; `resolve()` dispatch in `src/state/`; `CardEffect` seam in `src/state/resources/`.

### Project Context Rules

- **Card resolution computed in the state layer;** visuals never decide. [Source: docs/project-context.md#HARD RULE — State / visual separation]
- **Graceful degradation:** orbs off → mana-only cast. [Source: docs/project-context.md#HARD RULE — Feature flags]

### References

- [Source: stories-manual-e3.md#E3.S5a]
- [Source: gdd.md#Controls — Card-mode selection UX]
- [Source: docs/game-architecture.md#Novel Pattern 6]

## Golden Prediction

Baseline re-derived at gate time from the `GOLDEN` constant in `test_determinism.gd`:
`ad42841edcd549660de44a9cf1b6c916b2a090a9c973ec44ec8ecd1960434f08`.

**MOVES.** Three named causes plus one predicted non-mover:

1. **Snapshot shape** — the new discard count key. Moves at all-zero values, before any behaviour.
2. **Deck and hand counts moving**, from the discard and the replacement draw. Conditional on a
   fixture cast actually landing.
3. **Mana current moving**, from the price paid. Separable from cause 2 by pricing a fixture card at
   zero.
4. **`rng_state`** — predicted NON-MOVER, and MEASURED anyway precisely because the story previously
   claimed the opposite: `Deck.draw_top()` takes the last element and removes it, takes no rng
   argument and consumes nothing — the only RNG consumer in `Deck` is the shuffle (3-3). The prior
   version of this section claimed a refill draw consumes the seeded RNG and cited
   `match_state.gd:242` for `rng_state`; measured, `rng_state` is at `match_state.gd:292`, and the
   claimed cause does not exist.

**Isolation runs**, each reversed (a guard that does not fall without the thing it protects is
vacuous): shape-only with no cast; add fixture cost content and a zero-priced cast; set a non-zero
price; then strip the fixture's cost content and confirm a bit-identical return to the first
measurement.

The golden fixture builds its own `BalanceConfig` in test and its deck ids exist nowhere in the card
library, so THE FIXTURE MUST AUTHOR ITS OWN CAST-COST CONTENT or every card-side cause measures as a
false non-mover. One re-baseline, the sixth.

## Live Smoke

**REQUIRED.** Re-invokes the smoke acceptance obligation, which was spent at 3-4 and is re-invoked by
the first player-facing story with a live smoke since. Shipped default, two live killable human slots,
ZERO manual scene edits.

What it proves: whether a player can arm a card and commit it mid-exchange without it reading as
stopping to use a menu, and what it costs to enter the cast mode while an opponent is swinging.

What it explicitly CANNOT prove, recorded here so a later reader does not misread a PASS: whether
MODE-select is feasible under real-time pressure. Exactly one mode is reachable in E3; the others are
guarded stubs. The real forcing point for that question moves to E5, when the additional modes land.
A smoke PASS here must never later be read as having answered it.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-31 | 0.2 | E3 revisit-gate amendment (commit `10b96a1`): AC2 corrected so card actions are READ at step 6, not ingested at step 1 (matching the E2-CO/R3 precedent already applied to `move_dir`/attack/block/roll); guard helper corrected to `Invariant.check` (`check_invariant` names no real symbol); Golden Prediction and Live Smoke sections added. Status stayed backlog pending this story's own readiness gate. | Claude Opus 4.8 |
| 2026-08-04 | 0.3 | Split from the single `3-5` slot into `3-5a` (this file, THE TRIGGER) and `3-5b` (WHAT THE TRIGGER MAKES REACHABLE), honouring rather than reopening the 3-3 gate's ruling that discard/exhaustion/reshuffle/vulnerable-window move to 3-5 together with their trigger. File renamed via `git mv`, header retitled; `sprint-status.yaml` and `epics.md` updated alongside. `stories-manual-e3.md`'s E3.S5a section was CORRECTED, not copied forward verbatim: the staging verb dropped from item 1 (no consumer, the pitch zone is an E6 flag off), item 2 corrected to read card actions at step 6 rather than ingest at step 1, and the guard-helper name corrected to `Invariant.check` -- the manual was the source that seeded these three defects into the pre-gate story text, so leaving it uncorrected would have reseeded them at the next gate. Status stayed backlog pending this slot's own readiness gate. | Claude Sonnet 5 |
| 2026-08-04 | 0.4 | Readiness-gate fix pass (NOT READY on first read -> fixed and promoted, same session; eighteenth logged Set B readiness-gate session). Three defects removed: a Tasks/Subtasks line instructing step-1 ingestion that AC2 itself already forbade; the stale pre-revisit-gate banner, replaced with a Scope note in the 3-1/3-2/3-4 pattern; and a Golden Prediction section whose two named causes were both wrong (a refill draw consumes no RNG; the `rng_state` line citation had rotted from 242 to 292). AC set replaced with twelve verifiable claims about delivered software (the controller-only mode-select scheme; step-6 card-action reads; a `cast_evaluator.gd` sibling evaluator that computes and does not apply; a one-shot match-wide cost-injection seam; one-tick Basic-mode resolution with an instant refill; a discard pile as a third pure container with a count-only snapshot key; unaffordable-cast rejection through the shipped signal and seam; the DEAD/frozen-tick cast contract; the mode enum's home and the private step-6 dispatch; a presentation-local selection indicator fenced against 3-6; Input Map hygiene; and the deleted pitch/stage action). Golden Prediction rewritten: baseline re-derived (`ad42841e...`), three named causes (snapshot shape, deck/hand counts, mana spent) plus `rng_state` as a measured non-mover, isolation runs specified, the fixture-must-author-its-own-cast-cost-content warning added. Live Smoke kept REQUIRED with the P4 scope boundary made explicit (mode-select-under-pressure is NOT answered here). Dev Notes appended with the gamepad input intent, the gamepad-deferral reasoning, two previously unlisted inherited obligations, the retune-after-smoke ordering, the evaluator-sibling rationale, and the eighth architecture-amendment-queue member. Task list rewritten to mirror the twelve ACs. Status backlog -> ready-for-dev; `sprint-status.yaml` updated alongside. | Claude Sonnet 5 |
