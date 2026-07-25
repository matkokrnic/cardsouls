# Story 1.6: Second player slot as the training dummy (controller config swap)

Status: ready-for-dev

## Story

As a solo developer tuning hitboxes,
I want P2's already-live slot driven by a `NullController` selected at a single per-slot config point in the runner,
so that dummy → PvP → bot stays a controller swap and nothing in hero/actor/state ever branches on "is this the dummy."

## Acceptance Criteria

1. **NullController (B1).** `src/controllers/null_controller.gd` — a trivial `Controller` subclass whose `sample()` returns the base fresh `InputIntent.new()` null behavior (a fresh instance per tick, never a reused mutable one — the InputIntent LIFETIME contract, `input_intent.gd:7-10`). The class is deliberately behavior-free: it exists so the slot → controller-kind config can name a kind (AC 2), not to add logic. Nothing in the hero, actor, or `advance()` may branch on "is this the dummy" — dummy identity is settled by **architecture amendment A3** (game-architecture.md v1.2, commit d6ab666): the dummy is a NullController-driven standard slot, **not** a type.
2. **Per-slot controller config point (B1).** Controller assignment per slot becomes a single configuration point in `match_runner.gd` (a small exported/injected slot → controller-kind setup, replacing the two hardcoded `KeyboardController.new()` calls at `match_runner.gd:36-37`), so E2 (2-2/2-3) swaps in `KeyboardController("p2")`/`GamepadController` and E7 `ScriptedController`, each a one-line change.
3. **Default swap — this story SWAPS, it does not add (B1/N7).** P2's DEFAULT changes from `KeyboardController(&"p2")` to `NullController`: the default scene becomes P1 human vs P2 dummy. This is a **deliberately chosen default** — two-human play (exercised in the 1-3c hands-on playtest) returns only via the config point until 2-3. **No new `PlayerState`, no new actor, no new rig, no scene changes**: the second slot has been fully constructed and driven since E0 (`match_state.gd:70-71` constructs p1+p2 symmetrically; `match_runner.gd:91-92` drives both in fixed P1 → P2 order every tick).
4. **Invariants survive the swap (B1 restated).** With `NullController` live: **F1** holds — exactly one `func _physics_process` in `src/`, in `match_runner.gd`; **D3(a)** holds — `Input.*` only under `src/controllers/` (NullController itself reads no Input at all). Both grep-checked via the existing executable suite (`test/state/test_architecture_invariants.gd`). The fixed P1 → P2 sample/drive order is unchanged.
5. **Determinism, two parts (B4).**
   - **(a) Existing two-slot golden coverage HOLDS, hash unchanged:** `39564e83831819d4486d6216e9030535029de1298168ebeee720ab4812705353`. The golden path feeds fixed intents to both slots directly and bypasses controllers entirely, so this story predicts NO golden movement — per house golden discipline the prediction is **measured at dev time, not trusted** (the 1-5 cause-(c) lesson). **The golden sequence is NOT re-recorded.**
   - **(b) NEW non-golden headless test:** N ticks of `NullController`-produced intents leave the slot IDLE with velocity `Vector3.ZERO` throughout — the state-layer guarantee of an unmoved dummy (position itself is actor-owned per F1 and never in state).
6. **Repo hygiene (B6).** Delete `src/actors/dummy/.gitkeep` (verified tracked in git) — the vestigial folder amendment A3 removed from the architecture Directory Tree still persists in the repo. The deletion rides the **CODE commit**, per "docs and code never share a commit."

**OUT OF SCOPE (relocations + fences):** the **debug reset affordance is RELOCATED to 1-7** (operator decision, this gate) — until 1-7 lands the live `push_contact` feed nothing in live play can damage the dummy, so a 1-6 reset would be another headless-only artifact; reset semantics and its entry path (intent-carried event vs other) are decided at the 1-7 gate with the live damage loop in view, and the stories-manual E1.S7 item-4 wording ("the debug reset from E1.S6") is satisfied by 1-7 carrying its own reset (its gate reconciles the wording). Pinned constraint for that future reset: **`attack_index` never resets** — monotonic for the life of the match per the 1-5 dedupe contract (decision-log Session 2026-07-25 — Story 1-6 readiness gate). Also out of scope: no `GamepadController` (2-2); no `ScriptedController` (E7); no contact gathering, no `hit_landed`, no live `push_contact` caller (all 1-7); no iframe × contact coupling (1-9); no block mitigation (1-8); no HUD/readout (E2); no new `BalanceConfig` field, no `max_mana` (3-1); no transition into STUNNED (OPEN decision (a) stays open); no `src/ui/debug/` work of any kind this story.

## Tasks / Subtasks

- [ ] Add `src/controllers/null_controller.gd`: trivial `Controller` subclass, `sample()` returns fresh `InputIntent.new()` per tick (AC: 1)
  - [ ] Verify no "is dummy" branch exists anywhere in hero/actor/`advance()` (AC: 1)
- [ ] Add the single per-slot controller-kind config point in `match_runner.gd` (AC: 2)
- [ ] Swap P2's default from `KeyboardController(&"p2")` to `NullController` via the config point (AC: 3)
- [ ] Run the full suite: invariant greps (F1, D3(a), state purity) pass with `NullController` live; P1 → P2 order unchanged (AC: 4)
- [ ] Confirm the golden hash unchanged — measure, never trust; NO sequence re-record (AC: 5a)
- [ ] New headless test: N ticks of `NullController.sample()` intents fed to `advance()` → slot stays IDLE, velocity stays `Vector3.ZERO` (AC: 5b)
- [ ] Delete `src/actors/dummy/.gitkeep` in the code commit (AC: 6)

## Dev Notes

- **Dummy identity is settled by amendment A3** (game-architecture.md v1.2, commit d6ab666): the training dummy is NOT a distinct actor type — no `actors/dummy/`, no dummy class, no dummy scene; it is the standard slot (full `PlayerState` + `HeroActor`, both existing since E0) driven by a `NullController`. This is what makes E2 (second human) and E7 (bot) config swaps. (Replaces this story's original "DECISION (a)" citations — that label predates the 1-2 rename of seam choices to SEAM CHOICE and now collides with locked DECISION A, the unrelated 1-2 root-rotation decision.) [Source: docs/game-architecture.md#Post-Completion Amendments — A3; stories-manual-e1.md#E1.S6 item 1]
- **The base class already IS the null behavior:** `Controller.sample()` returns `InputIntent.new()` (`controller.gd:8-9`). `NullController` adds nothing on purpose — its value is being a nameable kind at the config point, keeping "dummy" purely a configuration fact.
- **The per-slot config point is the seam 2-2/2-3 and E7 extend; shape it as data now.** [Source: docs/game-architecture.md#D3; #Novel Pattern 3; epics.md#Sequencing invariants]
- **Default-swap consequence (N7), stated deliberately:** today's default scene is TWO keyboard-driven slots; after this story it is P1 human vs P2 dummy. Two-human play returns only via the config point until 2-3 realizes the swap-back. This is the intended epic order (dummy is the E1 opponent), recorded here so it reads as a swap, not an addition.
- **Debug reset relocation:** removed from this story entirely (see OUT OF SCOPE fence); 1-7 owns it, decided at the 1-7 gate. Do not add any reset method, debug UI, or `src/ui/debug/` file in this story's dev pass.
- **Architecture tree gap (minor docs debt, recorded at the gate):** the Directory Tree lists keyboard/gamepad/scripted/replay controllers but not `null_controller.gd`; A3's amendment text names `NullController` explicitly, so this is a tree omission to fold into the next architecture amendment, not a conflict — no architecture edit this story.

### Project Structure Notes

- `src/controllers/null_controller.gd` (new); `src/main/match_runner.gd` (config point + default swap); one new headless test under `test/state/`; DELETE `src/actors/dummy/.gitkeep`. **No `src/state/` changes, no scene changes, no `data/` changes, no `src/ui/` changes.**

### Project Context Rules

- **F1 / D3(a)(b):** greps must still pass after the swap; the executable guard is `test/state/test_architecture_invariants.gd`. [Source: docs/project-context.md#Single _physics_process; #Controllers & state-layer determinism]
- **Controller abstraction:** nothing branches on "is this a human." [Source: gdd.md#Controls — Input architecture]

### References

- [Source: stories-manual-e1.md#E1.S6 — items 1–3, 5; item 4's debug reset relocated to 1-7 per decision-log Session 2026-07-25 — Story 1-6 readiness gate]
- [Source: epics.md#E1; #E2; #E7; #Sequencing invariants]
- [Source: docs/game-architecture.md#D3; #Novel Pattern 3; #Post-Completion Amendments — A3 (v1.2, d6ab666)]
- [Source: decision-log.md#Session 2026-07-25 — Story 1-6 readiness gate (reset relocation; attack_index constraint; AC5 split)]

## Readiness Gate

- 2026-07-25: gds-check-implementation-readiness run against this story (authored 2026-07-22 in the original Set B batch, before any E1 code existed). Verdict **NOT READY** — six blocking findings: (B1) the story's core premise was stale — the second slot has been fully constructed and driven since E0 (both slots on KeyboardController, fixed P1→P2 order), so "instantiate a second PlayerState + HeroActor" described existing code and the real delta (NullController + config point + default swap) was unstated; (B2) the debug reset AC contradicted the architecture it cited (`src/ui/debug/` is "no state mutation"; boundaries table forbids ui mutating state; unrecorded reset = X5 replay hole; no `debug` flag carrier exists; D2 bypass); (B3) reset semantics were unspecified against post-1-3/1-5 machinery (running windows, monotonic `attack_index`, dedupe records, pools); (B4) the determinism AC was already satisfied by the existing two-slot golden and as written invited a pointless re-record; (B5) two stale pre-rename "DECISION (a)" labels colliding with locked DECISION A; (B6) the story argued against the pre-A3 architecture tree, and vestigial `src/actors/dummy/.gitkeep` is still tracked. Plus seven notes (N1 NullController API verified compatible, N2 runner/slot reality compatible, N3 STUNNED stays data-only, N4 no readout — observation seam untouched, N5 zero new authored values, N6 golden impact predicted NONE, N7 default-swap consequence). All findings accepted and resolved by **operator decision** (Matko, recorded in chat): B2/B3 resolved by RELOCATING the reset to 1-7; the `attack_index`-survives-reset constraint pinned; AC5 split into hold-golden + new non-golden test; A3 cited as settled authority; `.gitkeep` deletion assigned to the dev code commit. Cross-story entries recorded in decision-log Session 2026-07-25 — Story 1-6 readiness gate. Status stays backlog — promotion is a separate step.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

### Change Log

- 2026-07-25: Story rewritten at the readiness gate (fix pass, operator decisions applied): premise corrected to the actual delta (NullController + per-slot config point + P2 default swap — the second slot exists since E0), debug reset relocated to 1-7 with the `attack_index` constraint pinned in the decision log, determinism AC split (hold golden / new non-golden NullController test, no sequence re-record), stale "DECISION (a)" labels replaced by the A3 citation, `.gitkeep` deletion task added. Status: backlog.
