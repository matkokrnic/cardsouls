---
baseline_commit: b7b9c9c259dfdd4e475c2ea2adb53cd73cbfc468
---

# Story 4.3: Minion approach and collision

Status: ready-for-dev

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

1. **The actor drives its own approach (`4-3/R2`, CLOSED, not deferred again).** The RUNNER reads
   the throttled `[slot, index]` pair through the shipped non-allocating accessors
   (`unit_board.gd`'s `target_slot_at` / `target_index_at`), resolves it through
   `_target_world_position` (`match_runner.gd:671` — still the only place that translation
   happens), and hands `UnitActor` a `Vector3`: `approach(target_position: Vector3, speed: float,
   stop_distance: float, delta: float)`. The actor owns the move, the runner owns the lookup — the
   word "snapshot" leaves this AC, since nothing calls `to_snapshot()` per frame (`4-3/R8`
   corrects the literal wording, which contradicted `unit_actor.gd:15`). On the existing
   `_aim_unit_actors` / hero `.drive()` precedent, not a new `_physics_process` (`UnitActor` gains
   none; **F1** stays exactly one hit, in `match_runner.gd`). State never owns unit position: no
   `Vector3` field is added to `UnitBoard` or `PlayerState`, no new inward intake joins
   `push_contact` (1-8 stays the only one), `FORMAT_VERSION` stays 2.
2. **Approach speed and stop distance are balance-authored**, `@export_group("Minions")` on
   `BalanceConfig` beside `minion_retarget_interval_seconds`: `unit_move_speed` and
   `unit_stop_distance`. Both are scalars, **never tick-domain** — no `BalanceTicks` counterpart, on
   the `move_speed` / `stamina_regen_per_second` precedent for the rate and `attack_lunge_distance`
   for the distance (`4-3/R19`: `block_facing_arc_degrees` dropped as the weakest citation;
   `E1_BALANCE_FIELDS` half (b) keys the `BalanceTicks` obligation on the `_seconds` suffix, which
   neither new name carries). **Read inline at point of use** (CONSTRAINT C, never cached): the
   approach step reads the RUNNER's own replay-aware config handle, the selection already made at
   `match_runner.gd:177-180` (`replay_balance_config` during replay, `BalanceConfigService`
   otherwise) — never `BalanceConfigService.get_config()` directly (during replay that moves units
   at the authored speed instead of the recorded one, the divergence `3-0c`'s AC 4 exists to
   prevent) and never a copy cached in a `UnitActor` field (`4-3/R11`: CONSTRAINT C bars caching in
   a private field, not reading the runner-held config). Audited `> 0` in
   `test_balance_authoring.gd`, the `draw_replacement_delay_seconds` reason verbatim: a zero speed
   or zero stop distance would ship the mechanic invisible in the build.
3. **A unit farther than `unit_stop_distance` from its target moves toward it, planar, at
   `unit_move_speed`, while continuing to face it** (the existing `aim_at()` yaw, unchanged). A
   unit within `unit_stop_distance` halts and holds its facing. A unit with no acquired target
   (both `TargetingService` "no target" reasons) does not move, on the `aim_at()` no-planar-
   direction precedent of holding still rather than picking an arbitrary heading.
4. **Minions physically block heroes** — a hero cannot walk through a unit standing in its path.
   The claim is `4-2/R15`'s and no stronger (`4-3/R7`): no code under `src/state/` reads a physics
   API and no state decision branches on a collision result — AC 5 measures it. NOT claimed:
   collision has no effect on state. Collision DOES change what `advance()` receives — blocking
   changes hero node positions, which are the sole geometric input to `_gather_contact_facts`
   (`match_runner.gd:776-804`), and the derived facts enter state through `push_contact`, the sole
   intake (1-8). That indirection is the shipped design; hero-vs-hero body collision already
   exercises it on the default layer 1 (`hero.tscn:49`, no layer/mask lines) — a unit body on layer
   1 joins that path, it does not create one. The concrete collision mechanism (body type, shape,
   layer/mask against `project-context.md:76-81`) is **RULED AT THE READINESS GATE, Open Question
   4** — not decided by this AC.
5. **"No state decision reads physics" is measured, not asserted.** Extend
   `test_architecture_invariants.gd` with a guard scanning `src/state/` for the exact physics-query
   token set — `get_overlapping_areas`, `move_and_slide`, `CollisionShape3D`,
   `PhysicsDirectSpaceState3D`, no "or equivalent" (`4-3/R13`) — the same way D3(b)/A2 already scans
   for `Time.`/`OS.`/`Engine.`/global RNG. Carries the two parts every scan in that file already has
   and this AC must not omit: a regex self-test pair (precedent `:333-338` — must match the banned
   form AND not match a named near-miss, so a regex typo fails here instead of passing quietly) and
   a vacuity assert, `assert_true(scanned > 0, ...)` (precedent `:306`, `:348`) — this guard is
   green today against a `src/state/` with no physics token and would stay green at zero files
   scanned, so the vacuity assert matters more than usual. Proven falling by a deliberate mutation,
   restored from an out-of-repo copy, never `git checkout --`.
6. **Golden and snapshot key set UNMOVED — a REGRESSION check, demoted from the story's central
   prediction (`4-3/R12`).** True but zero-information alone: the golden fixture instantiates no
   actor and no state code reads either new field, so the hash is structurally incapable of moving
   — `4-2/M1`'s mutation does NOT transfer (M1 sat on the snapshot path; this story adds none).
   Still measured both directions at the dev pass, not asserted (`4-1/R4` form): no new
   `BalanceConfig` field enters the hash by construction (`BC/R3`); no new snapshot key ships
   (position stays actor-owned, AC 1). The actual positive control is a CONJUNCTION, all four
   required, not this AC: (a) a live moved-then-stopped `global_position` delta on a real
   `UnitActor` found by walking the tree (AC 7); (b) the two fields read from the authored `.tres`
   at the live seat, failing if either were 0 (`test_balance_authoring.gd`'s audit is
   load-bearing); (c) the physics-token guard under mutation (AC 5); (d) `E1_BALANCE_FIELDS`
   extended (Tasks). See Golden Prediction.
7. **A live integration test proves approach + stop + facing + blocking through the real runner**,
   on the `test_unit_aim_live.gd` shape (`3-0b/R34`'s blind spot: the headless state suite cannot
   see runtime composition, and `TargetingService`'s "acquired `[slot, index]`" contract says
   nothing about whether a node actually moved). At minimum: a summoned unit's `global_position`
   changes tick-over-tick while beyond `unit_stop_distance` of its live target; it stops changing
   (within a small epsilon) once within `unit_stop_distance`; the unit keeps facing the target
   throughout (the AC 3 non-vacuity pair — moved AND stopped, not just one).
8. **The `unit_actor.gd` header corrections land, TWO stale sites** (`4-3/R1` consequence,
   corrected by `4-3/R19`): lines 16-17 ("Movement and AI are 4-3's; HP, damage and death are
   4-3's" — the second clause is `4-3a`'s under `4-3/R1`) AND line 32 ("Movement is still 4-3's; a
   rotation is not a move"), both false the moment this story lands. Comment-only, no behaviour
   change, one task line covers both.

## Open Questions — ruled at THIS story's readiness gate

### Open Question 1 — RULED (`4-3/R17`): minions DO collide with each other.

_Decided by Matko._ Falls out of Open Question 4's body type at zero cost: a `CharacterBody3D` on
the shared default layer/mask collides with every other body on that layer, unit or hero — no
unit-vs-unit special case to write.

### Open Question 2 — RULED AND DEFERRED (`4-3/R15`), not open: a presentation null-check, no state consequence.

`_target_world_position` already returns null for an out-of-range index or a freed instance and the
caller already skips; approach does the same and holds position. This story cannot produce the
interesting case — nothing removes an individual unit from the board in 4-3 (death is `4-3a`'s),
and the only board-shrink path (debug reset) clears both actor arrays wholesale via
`_free_unit_actors()`. Re-acquisition belongs to `4-3a`.

### Open Question 3 — RULED (`4-3/R16`): recomputed every frame, through the non-allocating accessors.

`project-context.md:93` throttles target-ACQUISITION scans; a node lookup from a fixed pair is not
an acquisition scan. Caching to the throttle boundary would lag up to
`minion_retarget_interval_ticks` (12 at the authored 0.2 s) and walk the unit at where the hero used
to be.

### Open Question 4 — RULED (`4-3/R17`): `CharacterBody3D` + `move_and_slide()`, default layer/mask, no new layer.

_Decided by Matko._ `collision_layer 1` / `collision_mask 1` by default (no explicit lines, matching
`hero.tscn:49`), one `CollisionShape3D` child sized to the existing 0.6 x 1.2 x 0.6 box. No new
layer: `project-context.md:76`'s "next story that needs a layer starts at 4" is NOT triggered,
`project.godot` untouched. The unit gets NO hurtbox this story — that is `4-3a`'s, with `4-3/R3`'s
`[slot, index]` widening. Two shipped guards keep a unit body out of the contact pipeline: the hero
Hitbox is layer 4 / mask 2 (`hero.tscn:73-75`, hurtboxes only), and `_gather_contact_facts:785-787`
drops any actor whose `_slot_of` is -1. The base-type change costs zero edits at all six consumers
(`match_runner.gd:628, :630, :661, :679`; `test_summon_actor_live.gd:168`;
`test_unit_aim_live.gd:181`); `D9` (`game-architecture.md:452-456`) reserves the path but no body
type.

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
- [ ] Extend `E1_BALANCE_FIELDS` (`test_data_resources.gd:15`) with the two new fields — the
      reflection-completeness check at line 80 fails until this lands (`4-3/R9`) — test:
      `test_data_resources.gd` (AC: 2, 6)
- [ ] Add a runner-driven approach step for unit actors — `UnitActor.approach(target_position:
      Vector3, speed: float, stop_distance: float, delta: float)` called from the runner's DRIVE
      phase, alongside the hero drive call (`match_runner.gd` ~930-931, `4-3/R10`) — NOT alongside
      `_aim_unit_actors` (3d stays put; loop-merge is `deferred-work.md`'s) — target via
      `target_slot_at`/`target_index_at` resolved by `_target_world_position` — test:
      headless-unreachable by construction (F1); live integration test only (AC: 1, 3, 7)
- [ ] Extend `test_architecture_invariants.gd` with the "`src/state/` reads no physics" scan, exact
      token set, regex self-test pair, vacuity assert (AC 5, `4-3/R13`) — test: a mutation in a
      scratch copy proves the guard falls, restored from an out-of-repo SHA256-verified copy (AC: 5)
- [ ] Write `test/integration/test_unit_approach_live.gd`, the `test_unit_aim_live.gd` shape —
      moved-then-stopped non-vacuity pair, facing held throughout (AC: 6, 7)
- [ ] Implement Open Question 4's ruling (`4-3/R17`): `CharacterBody3D` + `move_and_slide()`,
      default layer/mask, one `CollisionShape3D` — test: a live check that a hero cannot walk
      through a unit standing in its path (AC: 4)
- [ ] Golden measured UNMOVED in both directions (add-then-revert), snapshot key set confirmed
      still eleven — test: `test_determinism.gd`, `test_card_observation.gd` (AC: 6)
- [ ] Comment-only: correct `unit_actor.gd`'s TWO stale header sites (lines 16-17 and 32) per
      `4-3/R1`/`R19` — test: none (prose-only, like the 4-2 comment re-point) (AC: 8)

## Dev Notes

- **Read before touching, `src/actors/minions/unit_actor.gd`**: currently `Node3D` +
  `MeshInstance3D`, one method (`aim_at`), no `_physics_process`, no collision node. The header
  states position is actor-owned (`4-1/R12`) and movement is "4-3's" — this story is that consumer.
- **Read before touching, `src/main/match_runner.gd`**: `UNIT_SCENE` (120), `_unit_actors` (125),
  `UNIT_ROW_X` (131, spawn row `[-5.5, 5.5]`), `_spawn_missing_unit_actors` (625),
  `_aim_unit_actors` (647, the target-lookup pattern reused — the call site is the drive phase
  below, not this loop, `4-3/R10`), `_target_world_position` (671, resolves `[slot, index]` to a
  live `global_position` — reuse, don't re-derive). The per-tick drive site (`_p1_hero.drive(...)`,
  `_p2_hero.drive(...)`, ~930) is where hero movement already happens; approach is a sibling call
  there.
- **Read before touching, `src/state/unit_board.gd`**: `target_slot_at`/`target_index_at`
  (117-123) are the only reads the per-frame path may use — `target_at()` (108) allocates an
  `Array[int]` per call, banned by `_aim_unit_actors`' docstring for this loop (`4-3/R19/N6`); no
  write path changes.
- **`BalanceConfig`'s `@export_group("Minions")`** already holds `minion_retarget_interval_seconds`
  (129-151) with its own worked example of the scalar-vs-tick distinction and `> 0` audit
  reasoning — the two new fields follow that comment's shape, not a fresh pattern.
- **Collision layers today**: layer 1 "bodies" (default, heroes + ground), layer 2 "hurtbox",
  layer 3 "hitbox" (`project-context.md:76-81`, `1-7`). No layer 4 is named anywhere in the repo
  yet — confirmed by grep. Whatever Open Question 4 rules is the first content there.

### Project Structure Notes

- `src/state/resources/balance_config.gd`: two new scalar fields (AC 2).
- `src/actors/minions/unit_actor.gd`: new approach method; header correction (AC 1, 3, 8); collision
  node(s) per Open Question 4's ruling (AC 4).
- `src/main/match_runner.gd`: new drive-phase unit-approach call site (AC 1, 3, `4-3/R10`).
- `test/state/test_architecture_invariants.gd`: new physics-token scan (AC 5).
- `test/state/test_balance_authoring.gd`: two new `> 0` audits (AC 2).
- `test/state/test_data_resources.gd`: `E1_BALANCE_FIELDS` extended by two (AC 2, 6; `4-3/R9`).
- `test/integration/test_unit_approach_live.gd`: new file (AC 6, 7; `4-3/R9`).
- `project.godot`: touched only if Open Question 4's ruling adds a `[layer_names]` entry — review
  the diff, per repo convention.

### Project Context Rules

- **F1 — one `_physics_process`, in the runner.** [Source: project-context.md; CLAUDE.md]
- **D3(b)/A2 — no physics query in `src/state/`.** [Source: project-context.md; AC 5 extends the
  existing scan family to this hazard]
- **CONSTRAINT C — read balance/injected values inline, never cache.** [Source: project-context.md]
- **Performance Rule — throttled targeting, not per-frame distance loops**; movement itself is a
  per-frame update, not forbidden (only *acquisition* scans are throttled). [Source:
  project-context.md Performance Rules]
- **Data as Resources — no hardcoded gameplay numbers.** Both new fields are `.tres`-authored.
  [Source: project-context.md]

### References

- [Source: decision-log.md Session 2026-08-10 "4-3 scope split", `4-3/R1`-`R6`; "4-3 readiness
  gate", `4-3/R7`-`R20`]
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
`_golden_config()` must NOT author the two new fields (`4-3/R19/N3`): no state code reads them, so
authoring them would be noise in a fixture whose every line documents why its value is what it is.
Replay safety is MEASURED, not assumed (`4-3/R19/N4`): `intent_recorder.gd:401`'s
`_resource_values()` is reflective over `PROPERTY_USAGE_SCRIPT_VARIABLE`, so both fields ride
`apply_balance` automatically, `_apply_values` restores them, no `FORMAT_VERSION` change, no test
pins that dict's key set (checked: `test_record_file.gd`, `test_intent_recorder.gd`).

BEFORE, for this authoring pass: `GOLDEN := "73a86005f1f2c069306ed6504be9c99d109e7b96014f05b502224f658209d1b5"`
(`test/state/test_determinism.gd:379`, the value 4-2 shipped). Snapshot key set BEFORE: eleven
(`test_card_observation.gd:242`). Suite BEFORE: 443 state tests / 3450 assertions, 0 failed, plus
26 integration files, all PASS (measured at 4-2's close-out, `bash test/run_all.sh`) — the dev pass
re-measures this itself rather than trusting the figure carried here.

## Live Smoke

**REQUIRED**, Tier A default (`4-3/R5`: Tier A even though golden-neutral is predicted — tier may
be raised, never lowered, mid-story). `R-D6` is **NOT** spent by this story (`4-3/R14`): collision
is layer-based and slot-agnostic, so AC 4 is falsifiable with P1's own hero walking into P1's own
unit, shipped defaults — no `slot_controller_kinds` flip, no kill, no `project.godot`/`main.tscn`
collateral. `R-D6` stays AVAILABLE (last spent 4-2's smoke) for `4-3a`, which ships death and has
something to prove with it.

Script, at minimum: a cast summons a unit; the box walks toward its acquired target and stops at
`unit_stop_distance`, still visibly facing it (the 4-2 rotation smoke, now with actual approach);
the hero cannot walk through it.

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
| 2026-08-10 | Claude Sonnet 5 | Readiness gate rulings `4-3/R7`-`4-3/R20` applied (operator-ratified). AC 1 corrected off the snapshot literal to the runner-reads/actor-owns-the-move contract (`R8`); AC 2 names the replay-aware config source and fixes its precedent citations (`R11`, `R19/N2`); AC 4 bounded to `4-2/R15`'s claim with the contact-pipeline indirection stated explicitly (`R7`); AC 5 fixes the exact physics-token set plus the regex self-test and vacuity-assert pair (`R13`); AC 6 demoted to a regression check, the four-part positive control named (`R12`); AC 8 covers both stale header sites (`R19/N1`). Both remaining Open Questions ruled (unit-vs-unit collision, recompute-every-frame). Open Question 4 ruled: `CharacterBody3D` + `move_and_slide()`, default layer/mask, no `project.godot` change (`R17`). Tasks gain `test_data_resources.gd` and pin the approach call to the drive phase, not `_aim_unit_actors` (`R9`, `R10`). Golden Prediction gains the authoring-ban and measured replay-safety notes (`R19/N3`, `R19/N4`). Live Smoke rewritten: `R-D6` NOT spent, no kill required (`R14`). Status `authored` -> `ready-for-dev`. |
