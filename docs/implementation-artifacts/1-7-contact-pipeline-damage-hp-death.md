# Story 1.7: Contact pipeline — hitbox facts → damage → HP → death

Status: ready-for-dev

## Story

As a player,
I want my swings to land in the live game — the runner gathering real hitbox facts into the one 1-5 intake seam, a `hit_landed` signal telling presentation about confirmed hits, death at zero HP as a terminal `DEAD` state announced through `EventBus`, and an intent-carried debug reset that restores the round for tuning,
so that the contact layer proven headless in 1-5 finally has a live path, and damage stays decided exclusively in `advance()` from runner-pushed facts.

## Acceptance Criteria

1. **Hitbox/Hurtbox nodes + layer convention (N3).** `Hitbox` and `Hurtbox` `Area3D` nodes are added to `hero.tscn` with an explicit collision-layer/mask convention. Neither node contains gameplay logic; neither applies damage. The documentation duty spans THREE places: the scene itself (node comments/configuration), `project-context.md` (a **docs commit, separate from code** per CLAUDE.md), and named `3d_physics` layers in `project.godot` (none exist today — this is an intentional, reviewed `project.godot` diff).
2. **Runner gathering — direct query, sole intake, gather-time stamp, self-filter (B4/B5).** The runner gathers facts in step 2 by **direct query** (`get_overlapping_areas()` on hitboxes whose state reports `is_hitbox_active()`, `hero_state.gd:167`), never `area_entered` signals (their firing order is not guaranteed and would make replay order-dependent). Every fact enters through **`MatchState.push_contact` — the SOLE intake path** (the locked 1-5 obligation, decision-log 1-5 close-out; `match_state.gd:145`), stamped with the attacker's `hero_state.attack_index` **at gather time**, never at resolution. **Self-overlap filter (B5, affirmed):** the `push_contact` `attacker != target` invariant stays STRICT (`match_state.gd:150-151`, review R1); since both heroes instantiate the same `hero.tscn`, the runner must filter self-overlaps at gather via an **identity check** (the overlapping area's owner != the attacker) before pushing — fact *selection*, not rule evaluation. No per-slot layer reassignment.
3. **Step-4 delta: `hit_landed` only (B2/N1/B7).** The 1-5 resolution code — damage formula, per-swing dedupe, melee→mana hook (`match_state.gd:276-305`) — is **fixed substrate, unchanged**. This story's step-4 delta is exactly:
   - **(a)** a **MatchState-owned** `hit_landed(attacker_slot: int, target_slot: int, damage: float, target_hp: float)` signal (a two-player event, the `round_ended` analogy — not per-hero), queued during `advance()` when a contact is confirmed, drained by the runner per D5;
   - **(b)** a **`match_runner.connect_hit_landed(callback)`** read-only subscription seam following the `connect_hero_action_state_changed` pattern (`match_runner.gd:101-107` analog — consumers never hold a MatchState handle); its FIRST consumer is the **throwaway `DebugStateOverlay`** (E2 fence restated: the real HUD replaces it; its internals are never copied, and it is deletable when E2 lands);
   - **(c)** the B7 fence: **step-4 resolution semantics are otherwise untouched** — see Dev Notes.
4. **Death — three real deltas against the existing substrate (B3/D-3).** `_check_resolution()` at step 8, the `_round_over` latch, and the MatchState-owned `round_ended(loser_index)` signal already exist (`match_state.gd:368-376`, E0). This story adds exactly:
   - **(1) `ActionState.DEAD` (D-3):** a new enum value with an **empty transition-table row** (accepts no table edges), entered ONLY by the step-8 resolution (a non-table path), exited ONLY by this story's reset (AC 5). Presentation learns of death through the **locked observation seam** (`action_state_changed`). The STUNNED-style inbound-edge guard in `test_action_state.gd` is extended to DEAD.
   - **(2) Post-death fact-drop:** `_resolve_contacts()` drops any fact whose target's `action_state == DEAD` **before** resolution — this also closes the corpse-mana-farming defect found at the gate (post-death confirmed hits currently still generate mana for the attacker, `match_state.gd:283-292` → `:300-305`).
   - **(3) EventBus relay:** `round_ended` is declared on `EventBus` (`event_bus.gd` declares no signals today) and the **RUNNER** relays `MatchState.round_ended` → `EventBus` — state never touches an autoload (`match_state.gd:12-13`).
   Demo scope is a single round — no restart flow beyond **this story's debug reset** (AC 5; reconciles stories-manual E1.S7 item 4's "the debug reset from E1.S6" — the manual is never edited, the reset relocated here at the 1-6 gate).
5. **Debug reset — round-scoped, intent-carried (B1/D-1/D-2).**
   - **Semantics (D-1):** the reset is **ROUND-SCOPED** — restore ALL slots' HP to max and clear the `_round_over` latch; **nothing else**. Pools, dedupe records, running windows, and positions are untouched (a live hero mid-swing swings on through a reset). A `DEAD` hero returns to `IDLE` on reset — a "clear action state" entry which, per the pinned contract, **NEVER touches `attack_index`** (`hero_state.gd:72-76`; 1-6 gate constraint).
   - **Entry path (D-2, option a — intent-carried):** `InputIntent` gains a `debug_reset` bool (default `false`); `KeyboardController` samples it from a prefix-mapped Input Map debug action (`p1_`/`p2_` symmetric); `advance()` applies the round-scoped reset when **any** slot's intent carries it. The recorded stream carries it for free once the X5 recorder exists — no new mutation surface, no second recorded-event class, no `src/ui/debug/` involvement.
   - **DELIBERATE (recorded in the decision-log):** the debug action is **NOT gated behind a FeatureFlags flag** — it is an operator affordance, not a gameplay path; a conscious exception to the 1-5 B2 "behind a flag" precedent. Do not add a `debug` field to `FeatureFlags`.
   - **Consequence to test:** once the latch can clear, `round_ended` fires once **PER DEATH**, not once per match — the "exactly once" pin at `test_match_state.gd:36` is extended accordingly.
6. **Testing — inherit, never rewrite (N5/N4/N2).**
   - **Existing coverage is inherited, not rewritten:** damage arithmetic + dedupe (`test_contact_resolution.gd`, 1-5), death threshold (`test_economy_and_hero.gd:25`), round-ended-once (`test_match_state.gd:36`, extended per AC 5).
   - **New headless** (synthetic facts through `push_contact`): `hit_landed` emission and signal order; post-death fact-drop including the corpse-mana closure; reset semantics — HP restore on all slots, latch clear, `DEAD` → `IDLE`, `attack_index` survival, pools untouched, once-per-death `round_ended`.
   - **New integration** (`test/integration/`): an active hitbox over a hurtbox produces **exactly one fact per swing**; the facts-lag-movement-by-a-constant-one-tick relationship is recorded as an **asserted expectation**, not a comment (absorbed by the 1-5 dedupe grace, `hero_state.gd:100-110`); the first live swing→HP end-to-end; the self-overlap filter (a hero's own hurtbox never produces a fact).
   - **Golden (N2): prediction NONE, measured in both directions, never trusted** (1-5 cause-(c) / 1-6 NONE precedent): signals are not hashed; the `DEAD` enum value adds no snapshot shape; the fact-drop and reset never trigger in the recorded sequence (nobody dies, nothing resets); `InputIntent` is excluded from the snapshot, so `debug_reset` cannot move the hash; the golden path bypasses the runner, so gathering cannot reach it. **No sequence re-record.**

**OUT OF SCOPE (fences):** **no X5 recorder work** — the 1-5 obligation to record contact facts alongside intents is **RE-HOMED (D-4, moved not dropped)** to the story that lands `IntentRecorder` (E2.S3 or a dedicated X5 story); 1-7 owes only what is already true — facts remain plain recordable three-int data entering one seam. No iframe × contact coupling (1-9); no block mitigation (1-8) — see the Dev Notes fence. No HUD/readout (E2; the overlay consumer is throwaway). No new `BalanceConfig` field, no `max_mana`, and none of the 3-1 obligations absorbed (apply_balance refill reconciliation, constructor double injection, mana cap — the reset restores HP only, it refills no pool). No transition into STUNNED — it stays data-only; OPEN decision (a) stays open. No `FeatureFlags` field addition (the deliberate no-flag decision, AC 5). No positional reset (position is actor-owned, F1). The hero ROOT never rotates (DECISION A, locked) — see the Dev Notes facing rule.

## Tasks / Subtasks

- [ ] Add `Hitbox`/`Hurtbox` `Area3D` nodes to `hero.tscn`; name the `3d_physics` layers in `project.godot` (intentional, reviewed diff); document the convention in the scene and in `project-context.md` (docs commit, separate) (AC: 1)
- [ ] Runner step-2 gathering: direct query on `is_hitbox_active()` hitboxes; identity self-overlap filter (owner != attacker) BEFORE push; stamp `attack_index` at gather; `push_contact` as the sole intake (AC: 2)
- [ ] `hit_landed` on MatchState (queued, D5) + `connect_hit_landed` runner seam + `DebugStateOverlay` as first (throwaway) consumer (AC: 3)
- [ ] `ActionState.DEAD`: enum value + empty table row + step-8 entry (non-table path) + inbound-edge guard test extension (AC: 4.1)
- [ ] Post-death fact-drop in `_resolve_contacts()` (target `DEAD` → fact dropped pre-resolution; closes corpse-mana farming) (AC: 4.2)
- [ ] Declare `round_ended` on `EventBus`; runner relays `MatchState.round_ended` → `EventBus` (AC: 4.3)
- [ ] Debug reset: `InputIntent.debug_reset` + `KeyboardController` sampling of the prefix-mapped debug action + round-scoped reset applied in `advance()` (AC: 5)
- [ ] Tests (AC: 6)
  - [ ] Headless: `hit_landed` emission/order; post-death fact-drop + corpse-mana closure; reset semantics (HP/latch/`DEAD`→`IDLE`/`attack_index` survival/pools untouched/once-per-death `round_ended`)
  - [ ] Integration: one fact per swing; the +1-tick lag asserted as expectation; live swing→HP end-to-end; self-overlap filter
  - [ ] Golden: measure the NONE prediction both directions; no sequence re-record

## Dev Notes

- **Direct query over `area_entered`:** async signal firing order is not guaranteed and would make replay order-dependent. [Source: docs/game-architecture.md#D2 contacts note (line 236); #Spatial Model]
- **`advance()` step 4 is the ONLY place damage is decided; actors REPORT, state DECIDES.** The runner queries, filters, stamps, and pushes; it never evaluates a gameplay rule. [Source: docs/game-architecture.md#Spatial Model]
- **FENCE (B7, verbatim intent):** step-4 resolution semantics are unchanged by this story — **no iframe logic, no block-mitigation logic**. `roll_iframe` × contact is **1-9**; block mitigation (the `block_damage_multiplier` consumer) is **1-8**; until those land, confirmed contact = full damage through roll and through block (NAMED DECISION, decision-log 1-5 close-out). An agent editing step 4 for `hit_landed` must not "helpfully" add either.
- **The 1-5 substrate this story builds on (do not re-implement):** `push_contact` intake with strict invariants (`match_state.gd:137-156`), per-swing dedupe with the +1-tick grace absorbing the F1 fact lag (`hero_state.gd:100-110`, `:285-304`), derived `is_hitbox_active()` (`hero_state.gd:167`), formula `attack_damage_percent_of_max_hp / 100.0 * target max HP` inline (CONSTRAINT C, `match_state.gd:288-289`), `_generate_mana` behind the injected flag (`match_state.gd:300-305`), `_check_resolution` step-8 death check (`match_state.gd:368-376`).
- **One-tick lag is a documented, constant, replay-safe relationship** (facts gathered at tick N's step 2 reflect tick N−1's physics flush) — assert it; the dedupe grace was built to absorb it. [Source: docs/game-architecture.md#Spatial Model — Documented phase]
- **Facing (N6, DECISION A locked):** the hitbox is positioned/rotated as a **CHILD node**, actor-side, reading state (`HeroState.facing` — the allowed visuals→state direction); the hero **ROOT never rotates** while the camera is fixed (all of E1) — root rotation would fold into the pushed camera basis. [Source: decision-log.md#Session 2026-07-23 — Story 1-2 close-out]
- **Reset application seat:** step 1 of `advance()` ("Ingest intents", currently a no-op) is the natural seat for the intent-carried reset — it runs before timers/actions/contacts, so a reset tick resolves cleanly. Applying it anywhere inside `advance()` satisfies D2; applying it anywhere else does not.
- **X5 re-homing (D-4):** contact-fact recording moved to the `IntentRecorder` story (E2.S3 or a dedicated X5 story) — recorded in the decision-log 1-7 gate session. This story keeps facts recordable (plain ints, one seam) and builds no recorder.
- **This is the story where coverage moves partly to integration tests (X6).** [Source: docs/game-architecture.md#Testing & Runtime Boundary]

### Project Structure Notes

- `src/actors/hero/hero.tscn` (Hitbox/Hurtbox nodes); `project.godot` (3d_physics layer names + `p1_`/`p2_` debug reset actions — intentional reviewed diff); `src/main/match_runner.gd` (step-2 gathering + self-filter + gather-time stamp; `connect_hit_landed` seam; `round_ended` → EventBus relay); `src/state/match_state.gd` (`hit_landed` signal + queue; post-death fact-drop; `DEAD` entry in `_check_resolution`; reset application); `src/state/hero_state.gd` (`ActionState.DEAD` + empty table row); `src/state/input/input_intent.gd` (`debug_reset`); `src/controllers/keyboard_controller.gd` (debug action sampling); `src/systems/event_bus.gd` (`round_ended` declaration); `src/main/debug_state_overlay.gd` (first `hit_landed` consumer — throwaway). Tests: `test/state/` (headless additions) + `test/integration/` (contact wiring). `docs/project-context.md` layer-convention edit rides a **separate docs commit**.

### Project Context Rules

- **`round_ended` is a genuinely ownerless global event** → `EventBus` (via the runner relay), never a per-entity signal; per-entity `hp_changed`/`hit_landed` consumers subscribe through runner seams. [Source: docs/project-context.md#Signals over polling; #Autoloads]
- **Queued signals (D5):** `hit_landed` is enqueued during `advance()`, drained by the runner after it returns — never emitted mid-tick.
- Chip damage ~5–8% HP keeps chip a credible finisher (kill-source rule); authored `attack_damage_percent_of_max_hp = 6.0`. [Source: gdd.md#Combat & Death (line 138)]
- **Docs and code never share a commit** — the `project-context.md` layer documentation is a separate commit. [Source: CLAUDE.md#Commit conventions]

### References

- [Source: stories-manual-e1.md#E1.S7 — items 1–5; item 4's "debug reset from E1.S6" satisfied by THIS story's reset per decision-log Session 2026-07-25 — Story 1-6 readiness gate (relocation) and Session 2026-07-25 — Story 1-7 readiness gate (rulings D-1/D-2)]
- [Source: docs/game-architecture.md#D2; #Spatial Model; #Determinism & Replay; #Instrumentation wiring (X5); #Testing & Runtime Boundary]
- [Source: decision-log.md#Session 2026-07-25 — 1-5 close-out (1-7 obligations; NAMED DECISION iframe/block; R1 strict invariant); #Session 2026-07-25 — Story 1-6 readiness gate (reset relocation; attack_index pin); #Session 2026-07-25 — Story 1-7 readiness gate (D-1..D-4, B5 affirmation)]

## Readiness Gate

- 2026-07-25: gds-check-implementation-readiness run against this story (authored 2026-07-22 in the original Set B batch, before `push_contact`, the dedupe layer, `_check_resolution`, and the 1-6 reset relocation existed). Verdict **NOT READY** — seven blocking findings: (B1) the reset relocated here at the 1-6 gate was entirely absent, orphaning stories-manual E1.S7 item 4; (B2) AC3 assigned already-landed 1-5 work (damage/dedupe/mana) to this story — the real step-4 delta is `hit_landed` + consumer; (B3) AC4's delta vs existing code unstated — EventBus relay missing, post-death contacts unblocked (live corpse-mana-farming defect), "terminal state" undefined; (B4) the `push_contact` sole-path + gather-time-stamping obligations unnamed; (B5) self-contact at gather would crash the strict R1 invariant (shared `hero.tscn` → own hurtbox in the overlap set); (B6) the X5 contact-fact-recording obligation unaddressed and unbuildable (no recorder exists); (B7) the iframe/block scope fence absent while this story edits step 4. Plus seven notes (N1 `hit_landed` owner/seam/consumer shape, N2 golden NONE prediction, N3 layer convention starts from zero, N4 lag absorbed by the 1-5 grace design, N5 test plan inherits existing coverage, N6 hitbox facing via child node under DECISION A, N7 playtest-gap context). All findings resolved by **operator decision** (Matko, D-1..D-4 + B5 affirmation, recorded in decision-log Session 2026-07-25 — Story 1-7 readiness gate) and applied to this story file in the same-day fix pass. Status stays backlog — promotion is a separate step.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

### Change Log

- 2026-07-25: Story rewritten at the readiness gate (fix pass, operator decisions applied): round-scoped intent-carried debug reset added (D-1/D-2, reconciling stories-manual E1.S7 item 4; deliberate no-flag exception recorded), AC3 rescoped to the true step-4 delta (`hit_landed` + `connect_hit_landed` seam + throwaway overlay consumer; 1-5 code fixed substrate), AC4 rewritten to the three real deltas (`ActionState.DEAD`, post-death fact-drop closing corpse-mana farming, EventBus relay), `push_contact` named the sole intake with gather-time `attack_index` stamping, strict self-contact invariant affirmed with runner-side identity filter, X5 contact-fact recording re-homed to the `IntentRecorder` story (moved, not dropped), iframe/block fence added, test plan rebuilt to inherit existing coverage, golden NONE prediction stated for dev-time measurement. Status: backlog (unchanged).
- 2026-07-25: Promoted backlog -> ready-for-dev following the readiness-gate fix pass.
