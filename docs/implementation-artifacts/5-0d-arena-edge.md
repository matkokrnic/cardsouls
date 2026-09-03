---
baseline_commit: e6ec6a8dcd90799454208910ccb736ce97bb3455
---

# Story 5.0d: Arena edge

Status: ready-for-dev

## What this story inherits

`E5-P/R2` (decision-log Session 2026-09-01 "E5 planning",
`docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8152-8157`) ratifies this as
the FOURTH of twelve E5 stories (`E5-P/R5`, `decision-log.md:8184`), Tier B, quoted verbatim:

> ARENA EDGE SLOTTED as `5-0d-arena-edge` (Tier B): a ring of static collision in the scene
> (`main.tscn`), a hard wall the player slides along -- cornering is intentional gameplay, not an
> accident to hide. No state clamp, no `src/state/` edit; golden immobile by construction, confirmed
> by measurement at the story's own gate. Closes the gap `4-3e/R6` opened with no owner
> (`deferred-work.md:305-309`) and removes it from the playtest checklist per
> `deferred-work.md:334`'s own "unless E5 planning has already slotted it" clause.

`E5-P/R7` (`decision-log.md:8238-8239`) confirms this story now OWNS the gap: the "three remaining
named gaps" left for the post-E5+E6 playtest block explicitly exclude arena edge ("arena edge is
`E5-P/R2`, not out").

**Motivating gap**, closing the deferred-work.md checklist item this story replaces (verbatim,
`docs/implementation-artifacts/deferred-work.md:305-310`):

> **Arena has no edge** -- hero and minion fly off past the floor rather than being stopped.
> Recorded at `sprint-status.yaml:117` and `4-4-totems.md:135`; observed live,
> `docs/playtest-log.md` 28.8. **SLOTTED as `5-0d-arena-edge` (`E5-P/R2`, decision-log Session
> 2026-09-01 "E5 planning"):** a ring of static collision in the scene (`main.tscn`), a hard wall
> the player slides along -- no `src/state/` edit, golden immobile by construction. `4-3e`
> consciously left this open (deleted the last requirement-shaped reference to an arena bound at
> its third gate, finding B3).

The same document's playtest-block checklist already struck this item out and re-tagged it
(`deferred-work.md:336-337`: "~~Arena has no edge~~ -- REMOVED from this checklist: E5 planning
slotted it as `5-0d-arena-edge`"). Every element that checklist item named — ring collision,
slide-not-bounce, cornering intentional, no state clamp, golden immobile — is carried into this
story's Acceptance Criteria below; none of it is dropped silently.

**Measured today, before any change** (`src/main/main.tscn`, 59 lines): the `Ground` `StaticBody3D`
carries one `BoxShape3D` (`size = Vector3(40, 1, 40)`) and one matching `BoxMesh` — the 40x40 ruling
confirmed by direct measurement, world bounds x/z in `[-20, 20]`, top face at world `y = 0`
(`GroundCollision` offset `y = -0.5`). **No wall, ring, or edge collision of any kind exists in the
scene today, and no clamp exists anywhere in `src/state/` either** — an actor walking past
`x/z = ±20` currently just keeps going, unimpeded, off the floor mesh into open space. `P1Hero`
spawns at `(-3, 1, 0)`, `P2Hero` at `(3, 1, 0)`.

## Story

As a player,
I want the arena floor to end in a wall I slide along rather than empty space I can walk off,
so that combat stays contained to the visible floor and cornering against the wall is a readable,
intentional part of movement rather than an accident that lets me or a minion disappear off the
edge.

## Acceptance Criteria

**Ring geometry**

1. Static collision authored in `src/main/main.tscn` forms a CLOSED ring around the existing floor
   at the measured world bounds `x/z = ±20` — no gaps anywhere along the perimeter, and the four
   corners hold (two wall segments meet cleanly at each corner; a body approaching a corner is
   stopped on both axes, never able to slip through the joint). Whether the ring is authored as four
   straight `StaticBody3D` segments (one per side) or some other static-collision shape that achieves
   the same closed boundary is a dev-pass call — record which was built and why in the Completion
   Notes.
2. The wall's visible mesh is a plain grey-box mesh (the project's standing grey-box bar, per
   `5-0c-totem-projectile-models.md`'s own Motivating Gap section quoting `totem_actor.tscn`: "GREY
   BOX, and that is the standing bar rather than a placeholder awaiting art"). Height and thickness
   are UNTUNED authored values — the dev pass picks values that read as a solid boundary (e.g. tall
   enough to clear the tallest actor collision box currently authored: the hero's collision height is
   2.0, `3-0b-feel-and-timing-tuning.md` AC13; the unit body box is `Vector3(0.6, 1.2, 0.6)`,
   `unit_actor.tscn`) without treating the exact number as load-bearing. Art polish (texturing,
   material authoring beyond a flat color) is explicitly a later story (Non-Goals).

**Wall behavior**

3. The wall is a HARD collider a `CharacterBody3D` slides along via its own existing
   `move_and_slide()` call — no bounce, no damage, no teleport, no velocity zeroing beyond what
   `move_and_slide()`'s own tangential-slide behavior already produces. Cornering (a body running
   into a corner and being redirected along whichever face it contacts) is INTENTIONAL gameplay, not
   a defect to hide or smooth over.
4. The wall blocks ALL bodies equally: hero, minion, and totem `CharacterBody3D` actors all
   experience the same collision — one ring, no per-entity exception, no per-kind opt-out.
5. **Guarantee this story ships, stated plainly:** a body already positioned inside the ring cannot
   end up outside it via ordinary movement or sliding, including any existing velocity-additive
   movement mechanic that runs through the same `move_and_slide()` call (e.g. the hero's attack
   lunge, `match_state.gd:2445-2456`, `_attack_lunge_velocity` — it is ADDED into
   `player.hero.velocity` before the actor's own `move_and_slide()` consumes it, so it is subject to
   the same wall collision as ordinary input-driven movement, not a separate path that could bypass
   it).
6. **Guarantee this story does NOT ship, stated plainly (out of scope, not silently assumed):** a
   body that is already outside the ring at the moment it is placed there — for example, via
   `4-3e-summon-spawn-placement.md`'s explicitly UNBOUNDED outward rear-arc spawn search ("no cap, no
   arena test, no fallback branch") — is not guaranteed to be pushed back inside. Spawn placement
   math is `src/state/`-side; fixing it is excluded by this story's own "no `src/state/` edit" rule
   (AC 8). The dev pass MEASURES (does not assume) whether the existing spawn search or any other
   already-shipped movement path (knockback, lunge, or otherwise) can in practice place or push a
   body outside the ring under the story's authored arena size, and records the actual finding in
   Completion Notes — this AC fixes what the wall itself guarantees, not what every other system
   happens to do today.
7. Projectiles are UNAFFECTED by the wall. `projectile_actor.tscn` is a plain `Node3D`, not a
   `CharacterBody3D` — it carries no body collision at all, only its `Hitbox` `Area3D`
   (`collision_layer = 4`, `collision_mask = 2`) — so it is physically incapable of colliding with a
   new wall regardless of which collision layer the wall is authored on. Projectile flight is
   entirely `src/state/`-side (travel-budget expiry); giving it a world collision would itself be a
   `src/state/` change this story's own ruling excludes. **This is a known, accepted visual
   oddity** — a projectile can visually cross the wall's plane while every body stops at it — named
   here for the live smoke to judge, not hidden or treated as a defect to fix.

**Scope discipline**

8. No `src/state/` file is touched. No `BalanceConfig` field is added, removed, or renamed. No new
   determinism-snapshot key is introduced. No state-side position clamp is added anywhere. This
   story's touched files are confined to `src/main/main.tscn` (the new wall geometry) and one new
   integration test (AC 9); `project.godot` is touched only if a new collision layer is judged
   necessary for the wall (a dev-pass call — see Dev Notes; the simplest option needs no
   `project.godot` edit at all).
9. **Golden prediction: UNMOVED in both directions.** This story adds only static scene collision
   geometry — no `src/state/` file changes, no new snapshot key, no changed control flow anywhere
   under `src/state/`. State this prediction in the Completion Notes and have the dev pass measure
   `bash test/run_all.sh` before and after: golden, full suite pass/assertion counts, and
   `project.godot` byte-identity (or, if a new layer is authored, the exact byte diff), all reported
   as measured, not assumed.
10. **Headless test coverage.** A live integration test drives a `CharacterBody3D` (a spawned unit or
    hero actor, following the existing `test/integration/test_*_live.gd` pattern — e.g.
    `test_unit_approach_live.gd`, `test_summon_actor_live.gd`) into the wall via repeated
    `move_and_slide()` ticks and asserts it never leaves the `[-20, 20]` ring on either axis; the same
    test (or a second one) drives a body into a CORNER and asserts it is stopped on both axes rather
    than slipping through the joint. This is cheap to add on the existing pattern and is the
    headless-pinnable half of this story's testing — name it explicitly, mutation-proven per the
    project's standing test-authoring discipline.

## Non-Goals

- Camera collision or occlusion handling near the wall. Whether the camera clips into or through the
  wall under lock-on is a named **SMOKE-WATCH** item for the live smoke to observe and record, not an
  acceptance criterion — no camera code is touched by this story.
- Wall damage, knockback, or bounce effects on contact — the wall is a passive, silent collider.
- Art polish of the wall mesh beyond the plain grey-box bar (AC 2) — texturing, material variation, a
  distinct look per side, or anything beyond a flat authored color is a later story.
- Any `src/state/` change, including a position clamp, a new `BalanceConfig` field, or a new
  determinism-snapshot key (AC 8).
- Projectile-vs-wall collision or any change to projectile flight (AC 7 — named and accepted as-is).
- Arena size or floor layout changes — the 40x40 floor itself is untouched; only a boundary is added
  at its existing edge.
- Fixing `4-3e`'s unbounded spawn search, or authoring any new arena-bound check into spawn
  placement — that is `src/state/`-side and out of scope here (AC 6).

## Dev Notes

- **Tier B, confirmed by measurement, not assumed.** Per `CLAUDE.md`'s "Story tiers": "The golden
  clause is decisive: a story that moves the golden is Tier A regardless of how it feels." AC 9's
  before/after measurement is what actually confirms Tier B holds — if it ever shows the golden or
  snapshot key set moved, this story has silently become Tier A and must be treated that way, per
  `E4-P/R9`.
- **Collision-layer choice is a dev-pass call, not fixed here.** Measured convention across every
  actor scene (`hero.tscn`, `unit_actor.tscn`, `totem_actor.tscn`): every `CharacterBody3D` root
  carries NO explicit `collision_layer`/`collision_mask` — they all sit on Godot's implicit default
  layer 1 ("bodies"), which is what already makes them block each other for free via
  `move_and_slide()`, and is also the layer the `Ground` `StaticBody3D` sits on (also unset). Layers
  2 and 3 are already claimed and reused across every actor scene for "hurtbox"
  (`collision_layer = 2`) and "hitbox" (`collision_layer = 4`) `Area3D`s specifically so
  `project.godot` never needs a new layer definition — see e.g. `unit_actor.tscn`'s own
  `editor_description` on its `Hurtbox` node. Layers 4-20 are completely free. **The simplest wall
  placement is a `StaticBody3D` on the SAME default layer 1 as `Ground` and every body** — this needs
  NO `project.godot` edit and no mask changes anywhere, matching every prior 5-0x story's
  "`project.godot` byte-identical" pattern (e.g. `4-3-minion-approach-and-collision.md`'s own
  close-out note). A new dedicated layer is only worth authoring if the dev pass finds a concrete
  reason the wall must NOT interact with something already on layer 1 (no such reason is known at
  authoring time) — record whichever choice is made and why.
- **Spawn-placement interaction, flagged not fixed.** `4-3e-summon-spawn-placement.md` (status
  `review` as of this writing) implements an outward rear-arc spawn search for summoned units with
  "no cap, no arena test, no fallback branch" — unbounded in principle. Since spawn math is
  `src/state/`-side, this story cannot and does not touch it (AC 6/Non-Goals). The dev pass should
  still MEASURE — not assume — whether the search's typical behavior at the story's authored arena
  size ever actually produces an out-of-ring spawn in practice, and record the finding plainly.
  Whatever the finding, no code changes to spawn placement land in this story.
- **The attack lunge is not a separate movement path.** `match_state.gd:2445-2456`
  (`_attack_lunge_velocity`, story 3-0b AC6) adds a displacement velocity into `player.hero.velocity`
  BEFORE the actor's own `move_and_slide()` call consumes it — it is not a teleport and not applied
  outside the normal per-tick movement step. This means the wall's collision automatically covers it;
  no special-casing is needed, and AC 5's guarantee already covers this mechanism by construction.
  Confirm this by reading the call site rather than re-deriving it.
- **Existing floor collision has no layer/mask lines at all** (`main.tscn`'s `Ground` node) — this is
  the precedent AC 8's "simplest option needs no `project.godot` edit" note above rests on.
- **Testability, stated honestly.** Headless-pinnable (AC 10): a body driven into the wall face and
  into a corner, asserted to stay within `[-20, 20]` on both axes — cheap on the existing
  `test/integration/test_*_live.gd` pattern (see `test_unit_approach_live.gd` or
  `test_summon_actor_live.gd` for the scene-instantiation and tick-driving pattern this repo already
  uses). Smoke-only: the FEEL of sliding along the wall, and camera behavior near the wall under
  lock-on (named SMOKE-WATCH in Non-Goals, not an AC). The golden-unmoved prediction (AC 9) is stated
  now; the dev pass's own before/after `bash test/run_all.sh` run is what confirms it.
- **Baseline measured for this story (before any change):** HEAD
  `e6ec6a8dcd90799454208910ccb736ce97bb3455` == `origin/main`, tree clean. No assets and no manual
  operator steps are needed to start this story's dev pass.

### Project Structure Notes

- No new `src/` file is required by this story's fixed decisions — the wall is scene-authored static
  collision in `src/main/main.tscn`, plus one new integration test under `test/integration/`
  following the existing `test_*_live.gd` naming and pattern. No new top-level folder.

### Project Context Rules

- F1: exactly one `func _physics_process` in `src/`, in `match_runner.gd` — this story adds no new
  per-frame update loop; the wall is passive static collision, evaluated by the engine's own physics
  step via each actor's existing `move_and_slide()` call.
- D3(a): `Input.*` only under `src/controllers/` — not implicated, no input surface touched.
- D3(b)/A2: no global RNG / `Time` / `OS` / `Engine` in `src/state/` — not implicated; this story
  makes no `src/state/` change at all (AC 8).
- Docs and code never share a commit; commits are pure ASCII via `git commit -F <tempfile outside
  the repo>`; shell is PowerShell 5.1 (no `&&`); trailer `Co-Authored-By: Claude Opus 4.8
  <noreply@anthropic.com>`.
- Story tier: Tier B — lighter skill chain, no separate gate pass, but the measured before/after
  (AC 9) is what CONFIRMS the tier rather than assumes it (`CLAUDE.md`, "Story tiers"; `E4-P/R9`).

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8127-8249 —
  "Session 2026-09-01 -- E5 planning"] — `E5-P/R2`'s ruling text, `E5-P/R5`'s story order/tier
  ratification (`5-0d-arena-edge` fourth, Tier B), `E5-P/R7`'s confirmation this gap is now owned.
- [Source: docs/implementation-artifacts/deferred-work.md:303-310,328-340] — the named-gap record
  this story closes and the playtest-checklist item it replaces, verbatim.
- [Source: src/main/main.tscn] — current floor geometry (`Ground`, `BoxShape3D`/`BoxMesh` both
  `Vector3(40, 1, 40)`), the absence of any existing boundary, and the two hero spawn points.
- [Source: src/actors/hero/hero.tscn, src/actors/minions/unit_actor.tscn,
  src/actors/minions/totem_actor.tscn, src/actors/projectiles/projectile_actor.tscn] — collision
  layer/mask convention (default layer 1 for bodies, layer 2 "hurtbox", layer 3 "hitbox"; the
  projectile's lack of any body collision).
- [Source: src/state/match_state.gd:2445-2603] — `_attack_lunge_velocity`, the additive
  velocity mechanism this story's AC 5 confirms is covered by the wall's collision by construction.
- [Source: docs/implementation-artifacts/4-3e-summon-spawn-placement.md] — the unbounded rear-arc
  spawn search this story flags but does not fix (AC 6).
- [Source: docs/implementation-artifacts/4-3-minion-approach-and-collision.md] — the
  `project.godot`/scene byte-identity discipline this story's AC 8 default (no new layer) follows.
- [Source: docs/implementation-artifacts/5-0c-totem-projectile-models.md] — the grey-box visual-bar
  precedent AC 2 cites, and the Tier B golden-measurement discipline this story's AC 9 follows.
- [Source: docs/implementation-artifacts/3-0b-feel-and-timing-tuning.md] — hero collision height
  (2.0, AC13) cited as one of AC 2's untuned-height reference points.

## Dev Agent Record

### Agent Model Used

_Not yet run — this section is populated by the dev pass._

### Debug Log References

_Not yet run — this section is populated by the dev pass._

### Completion Notes List

_Not yet run — this section is populated by the dev pass._

### File List

_Not yet run — this section is populated by the dev pass._

### Change Log

| Date | Change |
| --- | --- |
| 2026-09-03 | Story authored via `gds-create-story`. |
