---
baseline_commit: b7b9c9c259dfdd4e475c2ea2adb53cd73cbfc468
---

# Story 4.3: Minion approach and collision

Status: authored

## What this story supersedes

The board originally carried a single `4-3-minion-combat` entry covering movement, collision,
unit HP, damage, death, and the melee retune at once. **Cut by `4-3/R1`** (decision-log Session
2026-08-10, "4-3 scope split"): this story ships approach movement and physical collision only.
A new `4-3a-minion-combat` (backlog) carries HP, damage, death, board removal, and the melee
retune (`E3-R/R3`). Nothing here presupposes `4-3a`'s content beyond the target-index addressing
convention `4-3/R3` already names.

## Story

As a player,
I want a summoned minion to walk toward the target it acquired and physically stand in a hero's
way,
so that a unit on the board is an obstacle a player must deal with, not a decorative box.

## Acceptance Criteria

1. **The actor drives its own approach (`4-3/R2`, CLOSED, not deferred again).** `UnitActor` reads
   its acquired target from the snapshot (`unit_targets`, key set 11, `[slot, index]`, index -1 =
   hero), looks up that target's live node, and moves toward it every tick the runner already
   drives actors — on the existing `_aim_unit_actors` / hero `.drive()` precedent, not a new
   `_physics_process` (`UnitActor` gains none; **F1** stays exactly one hit, in
   `match_runner.gd`). State never owns unit position: no `Vector3` field is added to `UnitBoard`
   or `PlayerState`, no new inward intake joins `push_contact` (1-8 stays the only one),
   `FORMAT_VERSION` stays 2.
2. **Approach speed and stop distance are balance-authored**, `@export_group("Minions")` on
   `BalanceConfig` beside `minion_retarget_interval_seconds`: `unit_move_speed` and
   `unit_stop_distance`. Both are scalars (a rate and a distance), **never tick-domain** — no
   `BalanceTicks` counterpart, on the `attack_lunge_distance` / `block_facing_arc_degrees`
   precedent of a scalar field that stays off `BalanceTicks`. Read inline at point of use
   (CONSTRAINT C, never cached). Audited `> 0` in `test_balance_authoring.gd`, the
   `draw_replacement_delay_seconds` reason verbatim: a zero speed or zero stop distance would ship
   the mechanic invisible in the build.
3. **A unit farther than `unit_stop_distance` from its target moves toward it, planar, at
   `unit_move_speed`, while continuing to face it** (the existing `aim_at()` yaw, unchanged). A
   unit within `unit_stop_distance` halts and holds its facing. A unit with no acquired target
   (both `TargetingService` "no target" reasons) does not move, on the `aim_at()` no-planar-
   direction precedent of holding still rather than picking an arbitrary heading.
4. **Minions physically block heroes** — a hero cannot walk through a unit standing in its path.
   Presentation-only, on `4-2/R15`'s reasoning (`Area3D` overlap rejected for anything
   determinism-relevant): the blocking mechanism reads no state and writes no state, and
   `advance()` makes no decision that depends on it. The concrete collision mechanism (body
   type, shape, collision layer/mask against the layer table `project-context.md:76-81`) is
   **RULED AT THE READINESS GATE, Open Question 4** — not decided by this AC.
5. **"No state decision reads physics" is measured, not asserted.** Extend the
   `test_architecture_invariants.gd` family with a guard scanning `src/state/` for physics-query
   tokens (`get_overlapping_areas`, `move_and_slide`, `CollisionShape3D`, `PhysicsDirectSpaceState3D`
   or equivalent) the same way D3(b)/A2 already scans for `Time.`/`OS.`/`Engine.`/global RNG —
   proven falling by a deliberate mutation, restored from an out-of-repo copy, never
   `git checkout --`.
6. **Golden and snapshot key set UNMOVED — the story's central prediction, measured in both
   directions at the dev pass, not asserted as already true (`4-1/R4` form).** No new
   `BalanceConfig` field enters the hash by construction (`BC/R3`: authored balance is isolated
   from both the golden and the unit suite); no new snapshot key ships (position stays
   actor-owned, AC 1). See Golden Prediction.
7. **A live integration test proves approach + stop + facing + blocking through the real runner**,
   on the `test_unit_aim_live.gd` shape (`3-0b/R34`'s blind spot: the headless state suite cannot
   see runtime composition, and `TargetingService`'s "acquired `[slot, index]`" contract says
   nothing about whether a node actually moved). At minimum: a summoned unit's `global_position`
   changes tick-over-tick while beyond `unit_stop_distance` of its live target; it stops changing
   (within a small epsilon) once within `unit_stop_distance`; the unit keeps facing the target
   throughout (the AC 3 non-vacuity pair — moved AND stopped, not just one).
8. **The `unit_actor.gd:16` header correction lands** (`4-3/R1` consequence): "Movement and AI are
   4-3's; HP, damage and death are 4-3's" → movement ships this story; HP, damage, and death move
   to `4-3a`. Comment-only, no behaviour change, tracked as its own task line.

## Open Questions — ruled at THIS story's readiness gate

### Open Question 1 — Do minions collide with each other, or only with heroes?

Operator-level design question, not decided by this authoring pass. Whatever AC 4's collision
mechanism turns out to be, this determines whether it applies unit-vs-unit or only unit-vs-hero.
Affects whether two units summoned into each other's path visibly overlap or separate.

### Open Question 2 — What happens when an approaching unit's target dies or leaves the board mid-approach (a stale index)?

`TargetingService` throttles re-acquisition (`minion_retarget_interval_ticks`, `4-2/R5`); between
boundaries a unit can hold `[slot, index]` pointing at a target that is no longer valid by the time
this story's approach step reads it for a live node lookup. Whether that needs any **state**
consequence (an early re-acquisition, a "no target" fallback) or is purely a presentation-side
null-check (hold position, wait for the next boundary) is not decided here.

### Open Question 3 — Is approach direction recomputed every physics frame, or only when the snapshot's target changes?

Interacts with the retarget throttle already shipped on `advance()` step 7
(`minion_retarget_interval_ticks`). Recomputing every frame from a fixed `[slot, index]` is cheap
(one node lookup, no `TargetingService` re-evaluation) but the exact seam — inside the runner's
existing per-tick drive step, or cached until the throttle boundary moves the pair — is left to the
gate.

### Open Question 4 — Collision layer and mask assignment; authored mass or a static body?

The hitbox/hurtbox convention (`project-context.md:76-81`) uses layers 1 (bodies), 2 (hurtbox), 3
(hitbox); "the next story that needs a layer starts at layer 4 and names it here." Whether
`UnitActor` becomes a `CharacterBody3D`, a `StaticBody3D`, or something else, and how it is
positioned in the mask table against the hero's existing `CharacterBody3D` + `move_and_slide()`,
is not decided by this authoring pass.

## Deferred / Out of scope

- **Minion combat** (`4-3a`, per `4-3/R1`/`R3`/`R6`) — no HP, no damage, no death, no board removal.
  The contact fact's `[slot, index]` addressing widens on the `4-2/R2` precedent, but that widening
  is `4-3a`'s task, not this story's.
- **The melee retune** (`E3-R/R3`) — anchors to `4-3a`, not this story (`4-3/R1`).
- **Per-unit priority field** (`4-4`, per `4-3/R6`) — the `4-2/R17(c)` permission to add a field to
  the unit record is not spent here.
- **Object pooling** (`4-5`) — units stay plain instantiated/`queue_free()`d nodes.

## Tasks / Subtasks

- [ ] Author `unit_move_speed` and `unit_stop_distance` on `BalanceConfig`
      (`@export_group("Minions")`), audited `> 0` — test: `test_balance_authoring.gd` (AC: 2)
- [ ] Add a runner-driven approach step for unit actors — a new method on `UnitActor` (e.g.
      `approach(target_position, speed, stop_distance, delta)`) called from the runner's existing
      per-tick drive step alongside `_aim_unit_actors`, reading the live target node the way
      `_aim_unit_actors` already does — test: headless-unreachable by construction (F1); covered
      by the live integration test only (AC: 1, 3, 7)
- [ ] Extend `test_architecture_invariants.gd` with the "`src/state/` reads no physics" scan
      (AC 5), mutation-proven — test: a deliberate mutation in a scratch copy proves the guard
      falls, restored from an out-of-repo SHA256-verified copy (AC: 5)
- [ ] Write `test/integration/test_unit_approach_live.gd`, the `test_unit_aim_live.gd` shape —
      moved-then-stopped non-vacuity pair, facing held throughout (AC: 7)
- [ ] Resolve Open Question 4 at the gate, then implement whatever collision mechanism it rules —
      test: a live check that a hero cannot walk through a unit standing in its path (AC: 4)
- [ ] Golden measured UNMOVED in both directions (add-then-revert), snapshot key set confirmed
      still eleven — test: `test_determinism.gd`, `test_card_observation.gd` (AC: 6)
- [ ] Comment-only: correct `unit_actor.gd:16`'s header per `4-3/R1` — test: none (prose-only,
      like the 4-2 comment re-point) (AC: 8)

## Dev Notes

- **Read before touching, `src/actors/minions/unit_actor.gd`**: currently `Node3D` +
  `MeshInstance3D`, one method (`aim_at`), no `_physics_process`, no collision node. The header
  states position is actor-owned (`4-1/R12`) and that movement is "4-3's" — this story is that
  consumer.
- **Read before touching, `src/main/match_runner.gd`**: `UNIT_SCENE` (line 120), `_unit_actors`
  (125), `UNIT_ROW_X` (131, the current spawn row `[-5.5, 5.5]`), `_spawn_missing_unit_actors`
  (625), `_aim_unit_actors` (647, the pattern the new approach step joins), `_target_world_position`
  (671, already resolves a `[slot, index]` pair to a live `global_position` — reuse it rather than
  re-deriving). The per-tick drive site (`_p1_hero.drive(...)`, `_p2_hero.drive(...)`, around line
  930) is where hero movement already happens each physics frame; the new unit approach step is a
  sibling call at the same site.
- **Read before touching, `src/state/unit_board.gd`**: `target_at`/`target_slot_at`/
  `target_index_at` (108-123) are the only reads this story needs; no write path changes.
- **`BalanceConfig`'s `@export_group("Minions")`** already holds `minion_retarget_interval_seconds`
  (129-151) with its own worked example of the scalar-vs-tick distinction and the `> 0` audit
  reasoning — the two new fields this story adds follow that comment's shape, not a fresh pattern.
- **Collision layers today**: layer 1 "bodies" (default, heroes + ground), layer 2 "hurtbox",
  layer 3 "hitbox" (`project-context.md:76-81`, `1-7`). No layer 4 is named anywhere in the repo
  yet — confirmed by grep. Whatever Open Question 4 rules is the first content there.

### Project Structure Notes

- `src/state/resources/balance_config.gd`: two new scalar fields (AC 2).
- `src/actors/minions/unit_actor.gd`: new approach method; header comment correction (AC 1, 3, 8);
  collision node(s) per Open Question 4's ruling (AC 4).
- `src/main/match_runner.gd`: new per-tick unit-approach call site beside `_aim_unit_actors` (AC
  1, 3).
- `test/state/test_architecture_invariants.gd`: new physics-token scan (AC 5).
- `test/state/test_balance_authoring.gd`: two new `> 0` audits (AC 2).
- `test/integration/test_unit_approach_live.gd`: new file (AC 7).
- `project.godot`: touched only if Open Question 4's ruling adds a `[layer_names]` entry — review
  the diff, per repo convention.

### Project Context Rules

- **F1 — one `_physics_process`, in the runner.** [Source: project-context.md; CLAUDE.md]
- **D3(b)/A2 — no physics query in `src/state/`.** [Source: project-context.md; this story's AC 5
  extends the existing scan family to this specific hazard]
- **CONSTRAINT C — read balance/injected values inline, never cache.** [Source: project-context.md]
- **Performance Rule — throttled targeting, not per-frame distance loops**; movement itself is a
  per-frame position update, which the rule does not forbid (only *acquisition* scans are
  throttled). [Source: project-context.md Performance Rules]
- **Data as Resources — no hardcoded gameplay numbers.** Both new fields are `.tres`-authored.
  [Source: project-context.md]

### References

- [Source: decision-log.md Session 2026-08-10 "4-3 scope split", `4-3/R1`-`R6`]
- [Source: decision-log.md Session 2026-08-10 "4-2 close-out", `4-2/R14`, `4-2/R15`, `4-2/R17(c)`]
- [Source: docs/implementation-artifacts/4-2-minion-ai-throttled-targeting.md — AC 9, 11; Open
  Question 1/2; Golden Prediction shape]
- [Source: docs/game-architecture.md D9 (E4-E6 seams); F1 (`game-architecture.md:966`)]
- [Source: src/actors/minions/unit_actor.gd:1-56]
- [Source: src/main/match_runner.gd:120-131, 625-690, 896-931 (`_target_world_position` at 671)]
- [Source: src/state/unit_board.gd:108-143]
- [Source: src/state/resources/balance_config.gd:129-151 (Minions group precedent)]
- [Source: test/integration/test_unit_aim_live.gd (shape precedent, AC 7)]
- [Source: docs/project-context.md:76-81 (collision layer table), :90-96 (Performance Rules)]
- [Source: test/state/test_determinism.gd:379 (GOLDEN); test/state/test_card_observation.gd:230-252
  (snapshot key set, eleven)]

## Golden Prediction

**Predicted UNMOVED, both directions — to be measured, not assumed, at the dev pass.** Two
independent reasons, each on its own precedent: (1) the two new `BalanceConfig` fields are
authored balance, isolated from both the golden and the unit suite by construction (`BC/R3`) — a
value edit needs no test or golden change, and adding the field itself is the same class of
non-event 4-2's `minion_retarget_interval_seconds` was; (2) position stays actor-owned (AC 1), so
no snapshot key is added and `unit_targets` (key set eleven, unchanged since 4-2) is the only
target-shaped key that exists. The candidate mover this story does NOT introduce is a new
observation seam or intake — `push_contact` remains the sole inward intake (1-8), untouched.

BEFORE, for this authoring pass: `GOLDEN := "73a86005f1f2c069306ed6504be9c99d109e7b96014f05b502224f658209d1b5"`
(`test/state/test_determinism.gd:379`, the value 4-2 shipped). Snapshot key set BEFORE: eleven
(`test_card_observation.gd:242`). Suite BEFORE: 443 state tests / 3450 assertions, 0 failed, plus
26 integration files, all PASS (measured at 4-2's close-out, `bash test/run_all.sh`) — the dev pass
re-measures this itself rather than trusting the figure carried here.

## Live Smoke

**REQUIRED**, Tier A default (`4-3/R5`: Tier A even though golden-neutral is predicted — tier may
be raised, never lowered, mid-story). `R-D6` is RE-INVOKED on this gate (last spent 4-2's smoke,
2026-08-10) and consumed on this story's kill, per the two-human kill-acceptance ritual.

Script, at minimum: a cast summons a unit against a live opposing hero; the unit walks toward the
opposing hero and stops at `unit_stop_distance`, still visibly facing it (the 4-2 rotation smoke,
now with actual approach); the opposing hero attempts to walk through the unit's position and
cannot — collision holds. The script includes a kill, on the existing hero-vs-hero melee system
(1-7) — this story ships no minion damage or death (`4-3a`'s), so the kill is what makes the
config a killable-human-slot smoke in R-D6's own sense, not evidence of anything this story adds.

## Review Findings

Pending — this section fills in at code review, after the dev pass. Not yet run.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 — authoring pass, 2026-08-10.

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Author | Change |
|---|---|---|
| 2026-08-10 | Claude Sonnet 5 | Story authored via `gds-create-story`, split from the boarded `4-3-minion-combat` per `4-3/R1`. |
