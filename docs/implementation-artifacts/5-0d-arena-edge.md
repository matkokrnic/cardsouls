---
baseline_commit: e6ec6a8dcd90799454208910ccb736ce97bb3455
---

# Story 5.0d: Arena edge

Status: done

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

Sonnet 5 (operator-stated)

### Debug Log References

- Preconditions verified: HEAD `65cd9194a9e0e1661b7c0bfe1440e4354c7f2f04` == `origin/main`, tree
  clean, no running Godot processes, story Status `ready-for-dev`. The story's own frontmatter
  `baseline_commit` (`e6ec6a8`) predates two docs-only commits (`review fix + promote`,
  `promote to ready-for-dev`) that landed after authoring; per the skill's own rule the existing
  frontmatter value was preserved, not overwritten.
- Before-baseline `bash test/run_all.sh` (`C:\dev\_50d-suite-before.txt`): start
  2026-09-03 16:44:15, end 16:47:21 (~3m6s), `=== 577 tests, 0 failed, 4433 assertions ===`,
  50 integration files, `ALL TESTS PASSED`, `EXIT_CODE=0`. `test_determinism.gd`'s hardcoded
  `GOLDEN` constant read from source: `aa3566d7077c07cc90630d155924b620cf5c54e14e6d0f3809d154d31ded7e4f`
  (unchanged from the 5-0c close-out record).
- Measured before writing anything: `main.tscn`'s `Ground` `StaticBody3D`/`BoxShape3D`
  (`size = Vector3(40, 1, 40)`, no offset in x/z) confirms the authored world bounds
  `x/z = [-20, 20]`; `hero.tscn`'s `Collision` `BoxShape3D` is `Vector3(1, 2, 1)` (not the 2.0
  height alone the story's Dev Notes cites — the full box); `unit_actor.tscn`'s is
  `Vector3(0.6, 1.2, 0.6)`. Read `match_state.gd:2445-2456` directly: the attack lunge is
  `player.hero.velocity = world_dir * speed + lunge` — additive into the SAME velocity field
  `hero.gd:85`'s `move_and_slide()` consumes immediately after, confirming the story's AC 5 claim
  from the code rather than trusting it.
- Grepped `src/` for every non-input-driven position/velocity write (AC 6): two hits outside
  the input-driven movement path — `match_runner.gd:758` (`unit.global_position = spot`, the
  4-3e summon spawn placement) and `match_runner.gd:1592` (`shot.global_position = ...`, projectile
  launch — a plain `Node3D`, AC 7 exempt). No knockback, teleport, or push-back mechanism exists
  anywhere in `src/`. Read `_compute_spawn_positions` (`match_runner.gd:889-919`): the outward
  ring search has NO upper bound on `ring` (`while true`, radius grows by `SPAWN_RING_STEP = 0.6`
  each iteration with no cap) — confirmed unbounded by reading the loop, not assumed from the
  story's own description of it.
- Collision-layer choice (Dev Notes' own dev-pass call): all four wall `StaticBody3D` nodes carry
  no explicit `collision_layer`/`collision_mask` lines, matching `Ground`'s own convention exactly
  — layer 1 (default), same as every actor body. `project.godot` needed no edit; confirmed by
  hash below.
- Implementation: four `StaticBody3D` segments added to `src/main/main.tscn` (`WallNorth`,
  `WallSouth`, `WallEast`, `WallWest`), each with one `CollisionShape3D` + one `MeshInstance3D`
  child (grey-box `BoxMesh`, no material override, matching `Ground`'s own precedent exactly — no
  new material authored). North/South share one `BoxShape3D`/`BoxMesh` pair
  (`size = Vector3(42, 3, 1)`); East/West share another (`size = Vector3(1, 3, 40)`). Height 3.0
  clears the hero's 2.0-tall collision box with margin; thickness 1.0 reads as a solid boundary
  without being load-bearing (AC 2's own "untuned" framing). North/South are authored 2 units
  WIDER (42 vs the floor's 40) than the floor **(corrected on review):** measured directly from
  `main.tscn`, North/South end flush at `|x| = 21` — exactly 1 unit past the East/West walls'
  INNER face (`|x| = 20`), i.e. covering the East/West walls' own 1-unit thickness (`|x|` in
  `[20, 21]`), not their outer face. The two boxes share zero volume — West covers `x` in
  `[-21, -20]`, North covers `z` in `[20, 21]`, and for `x` in `[-21, -20]` their z-coverage is
  `[-20, 20]` union `[20, 21]`, contiguous with no gap — so the corner is sealed for any finite
  body. This is not an overlap margin: the seal rests on exact coordinate alignment
  (`20.5 - 0.5` and `0 + 20` both evaluate to exactly `20.0` in float), i.e. the walls abut
  exactly on the `z = ±20` plane with a precise butt-joint, not a deliberate overlap.
- `git diff -- project.godot`: empty, both before and after. `sha256sum project.godot`:
  `8879de490edda78051595f189fb9bb6f2e75384febaff142c8958ec107970004`, identical before and after
  the implementation edit and after the editor session below — byte-identical throughout, no new
  collision layer needed (Dev Notes' "simplest option" default taken, no concrete reason found to
  deviate).
- New integration test `test/integration/test_arena_edge_live.gd` authored (see Completion Notes
  for why it drives a STANDALONE third `hero.tscn` instance rather than P1/P2's own heroes — both
  the real Input-Map chain and the camera-relative movement basis turned out to be the wrong tool
  for this specific measurement, discovered by running a throwaway diagnostic `--script` probe,
  deleted after use, never committed). Individual run: PASS
  (`min_x=-19.5000 max_z=19.5000 out_of_ring=false`).
- Editor session (`godot --headless --editor --quit --path .`), to generate the new test's
  `.uid`: `git diff -- project.godot` empty; `sha256sum project.godot` unchanged
  (`8879de49...70004`, same hash as above). `test_arena_edge_live.gd.uid` generated.
- Regression spot-check after implementation, run individually: `test_unit_approach_live.gd`
  PASS, `test_summon_actor_live.gd` PASS, `test_totem_no_rotation_live.gd` PASS — all unchanged
  behavior, confirming the new wall geometry does not interfere with existing actor
  approach/spawn/aim paths at their much-closer-to-center authored distances.
- Mutation proofs (table below) run individually against
  `test/integration/test_arena_edge_live.gd`, backups outside the repo
  (`C:\dev\_50d_backups\main.tscn.orig`), restore by copy-back + SHA-256 verification, never
  `git checkout`. Mutation A (wall collision disabled) and Mutation B (corner gap) both FAILED as
  expected; the file was restored and hash-verified identical after each, and the unmutated file
  re-confirmed PASS after the final restore.
- After-baseline `bash test/run_all.sh` (`C:\dev\_50d-suite-after.txt`): start
  2026-09-03 16:58:45, end 17:01:58 (~3m13s), `=== 577 tests, 0 failed, 4433 assertions ===`
  (identical to before-baseline — golden and per-player snapshot key set unmoved, both
  directions), 51 integration files (50 + `test_arena_edge_live.gd`, new — the only line-diff
  between the before/after integration file lists), `ALL TESTS PASSED`, `EXIT_CODE=0`.
- Tier B budget: 16:44:15 -> 17:01:58, ~17m43s elapsed, well inside the ~1h budget.

**Fix pass (code review findings F1-F7):**

- Preconditions verified before touching anything: `HEAD` == `origin/main` == `65cd919`, working
  tree carried exactly the expected modified/untracked set, no running Godot processes.
- Story-file corrections (F2, F3): both false Dev Agent Record claims re-derived from measurement
  rather than trusted — the North/South-vs-East/West corner geometry is a precise butt-joint at
  exact float coordinates (`20.5 - 0.5 == 0 + 20 == 20.0`), not a deliberate overlap; the AC 6
  spawn note's crowding-only model was replaced with the cheaper, always-available near-wall path
  (`SPAWN_BEHIND_DISTANCE = 2.5` from a hero within 2.5 units of a wall reaches the ring/wall
  volume on the FIRST candidate with zero occupants). Both re-verified directly against
  `main.tscn` and `_compute_spawn_positions`/`_spot_is_clear` before writing the correction.
- Test hardening (F4-F7): `test/integration/test_arena_edge_live.gd` rewritten with four phases
  (West face, NW corner, East face, SE corner), `_max_x`/`_min_z` tracked alongside the existing
  `_min_x`/`_max_z`, the per-frame assertion tightened from `20.05` to `CENTER_BOUND + EPSILON`
  (`19.5 + 0.05`, the probe's own half-extent subtracted from the true wall face), phase boundaries
  derived from named `PHASE*_TICKS` constants (`PHASE1_END`, `PHASE2_END`, ... summed, not
  restated), and the end condition split into four independent named booleans
  (`reached_west`/`reached_east`/`reached_north`/`reached_south`) so a face failure and a corner
  failure report distinctly instead of through one dead composite conjunct. Individual run: PASS
  (`min_x=-19.5000 max_x=19.4999 max_z=19.5000 min_z=-19.4997`).
- Mutation (table below): `WallEastCollision.disabled = true`, backed up to
  `C:\dev\_50d_backups\main.tscn.fixpass.orig` (hash identical to the original dev-pass backup,
  confirming no drift between passes) before mutating; targeted run FAILED as expected; restored
  by copy-back, SHA-256 verified identical; unmutated re-run PASSED.
- Spawn containment (F1, operator-approved scope widening — see AC 6 Completion Note for the
  attribution and reasoning): read `_compute_spawn_positions` and `_spot_is_clear` first. Chose a
  CLAMP of the accepted candidate over a candidate-level bound in `_spot_is_clear`, because the
  search's outward-growth loop has no termination guarantee once a ring-inclusion filter is added
  (a hero positioned such that no candidate at any radius falls inside the ring would spin the
  `while true` loop forever) — a clamp on the already-accepted output carries no such risk and
  leaves the search itself, including its termination argument (4-3e AC 2), completely untouched.
  Added `SPAWN_ARENA_HALF_EXTENT`/`SPAWN_CONTAINMENT_MARGIN`/`SPAWN_CONTAINMENT_BOUND` constants
  and the clamp at the `placed.append(...)` call site.
- New integration test `test/integration/test_summon_spawn_containment_live.gd` authored, patterned
  off `test_summon_actor_live.gd`/`test_unit_spawn_placement_live.gd`'s real Input Map arm-then-
  confirm chain, with P1's hero pinned at `x = -19` (1 unit off the West wall's inner face) before
  casting. Individual run: PASS (`hero=(-19.0, 1.0, 0.0) spawn=(-19.6, 0.0, 0.0) contained=true`).
- Editor session (`godot --headless --editor --quit --path .`) to generate the new test's `.uid`:
  `git diff -- project.godot` empty; `sha256sum project.godot` unchanged
  (`8879de49...70004`, same hash as the dev pass's own record) — no collateral drift.
- Mutation (table below): reverted the containment clamp to the pre-fix un-clamped line, backed up
  `match_runner.gd` outside the repo first; targeted run FAILED as expected
  (`spawn=(-21.5, 0.0, 0.0) contained=false`); restored by copy-back, SHA-256 verified identical;
  unmutated re-run PASSED.
- After-fix-pass `bash test/run_all.sh` (`C:\dev\_50d-fix-suite.txt`, ONE blocking foreground run,
  ended 2026-09-03 17:58:36): `=== 577 tests, 0 failed, 4433 assertions ===` — IDENTICAL to both
  the dev pass's before- and after-baseline counts, confirming the golden and snapshot key set are
  still UNMOVED after the fix pass's additional `src/main/` change. 52 integration files (51 + the
  new `test_summon_spawn_containment_live.gd`), `test_arena_edge_live.gd` and
  `test_summon_spawn_containment_live.gd` both PASS in the full run, `ALL TESTS PASSED`,
  `EXIT_CODE=0`. Read from the file, not tailed.

**Cosmetic pass (operator-approved AC 2 deviation, F8 + live smoke):** review finding F8 and the
live smoke both flagged that under forced lock-on near a wall the camera can exit the ring while
the wall stays fully opaque, occluding the hero from view. Operator approved deviating from AC 2's
"grey-box, no material" for the four wall meshes only, to keep the hero visible through the wall
from an outside-the-ring camera. Preconditions reverified before touching anything: `HEAD` ==
`origin/main` == `65cd919`, `grep slot_controller_kinds src/main/main.tscn` empty, working tree
carried exactly the known 5-0d set, no running Godot processes. Added one shared
`StandardMaterial3D` sub-resource (`transparency = TRANSPARENCY_ALPHA`, `albedo_color = Color(0.6,
0.7, 0.85, 0.35)` — a light grey-blue at 0.35 alpha, inside the requested 0.30-0.40 band) and
assigned it via `surface_material_override/0` on all four wall `MeshInstance3D` nodes
(`WallNorthMesh`/`WallSouthMesh`/`WallEastMesh`/`WallWestMesh`). Left backface culling at its
default (enabled): the wall is a solid box, so the camera always sees a front-facing outer face
regardless of side; disabling culling would additionally render each box's inner (far) face through
the near one, double-blending the alpha and darkening the wall rather than helping the
outside-looking-in case. No `CollisionShape3D`, `StaticBody3D` transform, shape sub-resource,
`Ground`, or any other node touched — confirmed by diffing against the pre-edit file (only the new
material sub-resource and the four `surface_material_override/0` lines appear). Targeted run of
`test_arena_edge_live.gd`: PASS, identical numbers
(`min_x=-19.5000 max_x=19.4999 max_z=19.5000 min_z=-19.4997 out_of_ring=false`) — collision
untouched. Full suite (`C:\dev\_50d-transparency-suite.txt`, one blocking foreground run):
`=== 577 tests, 0 failed, 4433 assertions ===`, golden unmoved, 52 integration files, `ALL TESTS
PASSED`. Status remains `review`; no commit made.

### Completion Notes List

- **AC 1 (ring geometry, closed, corners hold):** four straight `StaticBody3D` segments, one per
  side (dev-pass call — the simplest static-collision shape that achieves a closed boundary on
  the existing rectangular floor; no reason found to prefer a single compound shape or a
  cylindrical/octagonal approximation for a square arena). North/South are authored 2 units wider
  than the floor (`size.x = 42` against the floor's 40) **(corrected on review):** measured
  directly from `main.tscn`, this makes North/South end flush at `|x| = 21` — exactly 1 unit past
  the East/West walls' INNER face (`|x| = 20`), covering the East/West walls' own 1-unit
  thickness. The two boxes share zero volume; the corner is sealed for any finite body because
  coverage over `x` in `[-21, -20]` is contiguous (West covers `z` in `[-20, 20]`, North covers
  `z` in `[20, 21]`). The seal rests on exact coordinate alignment (`20.5 - 0.5` and `0 + 20` both
  evaluate to exactly `20.0` in float) — a precise butt-joint on the `z = ±20` plane, not an
  overlap margin. This is what makes "two segments meet cleanly, a body approaching a corner is
  stopped on both axes" true BY CONSTRUCTION. Proven live: the
  new test drives a body diagonally into the North-West corner and never sees it leave
  `[-20, 20]` on either axis (measured `min_x=-19.5000 max_z=19.5000`, i.e. it reached within 0.5
  of both true wall faces — exactly the hero collision box's own half-extent — and no further).
  Mutation-proven non-vacuous (table below): shrinking one wall's far extent to open a real
  uncovered gap at a corner reliably fails the same assertion.
- **AC 2 (grey-box mesh, untuned height/thickness):** each wall segment's `MeshInstance3D` uses a
  plain `BoxMesh` with no material override — the exact same authoring choice as `Ground`'s own
  `GroundMesh` (no material anywhere on the existing floor either), so the wall matches the
  project's standing grey-box bar with zero new material authored, not merely a "flat color"
  approximation of it. Height 3.0 (comfortably above the hero's 2.0-tall collision box, the
  tallest authored actor collision height) and thickness 1.0 are UNTUNED authored values per the
  AC's own instruction — chosen to read as solid, not measured against any gameplay requirement.
- **AC 3 (hard collider, slides, cornering intentional):** no code was written for wall behavior
  at all — a `StaticBody3D` with a `CollisionShape3D` is exactly what `Ground` already is, and
  every `CharacterBody3D`'s own `move_and_slide()` call (unmodified, `hero.gd:85`,
  `unit_actor.gd:275`) already produces the engine's own tangential-slide response against it.
  Cornering was proven live, not merely asserted: the test's Phase 2 drives the probe body
  diagonally into a corner and it IS redirected along whichever face it contacts (visible in the
  measured trajectory: `x` pins near `-19.5` while `z` continues climbing to `19.5` under
  continuous diagonal input) — the intentional behavior AC 3 names, not a defect.
- **AC 4 (blocks all bodies equally):** the wall carries no `collision_layer`/`collision_mask`
  override, sitting on the same default layer 1 every `CharacterBody3D` (hero, minion, totem) and
  `Ground` already share — there is no per-entity exception to author, because nothing
  distinguishes any body from any other at the physics-layer level. Proven for the hero body
  directly (the test drives a `hero.tscn` instance); minion/totem bodies share the identical
  `CharacterBody3D` root convention and the identical default layer, so the same collision
  response applies to them by the same physics rule, not a separately-authored one — confirmed by
  reading `unit_actor.tscn`/`totem_actor.tscn`'s own `Collision` nodes, neither of which carries
  any layer/mask override either.
- **AC 5 (already-inside bodies cannot end up outside, including the attack lunge):** re-verified
  from the code rather than trusted from the story text — `match_state.gd:2445-2456` reads
  `player.hero.velocity = world_dir * speed + lunge`, the SAME `velocity` field `hero.gd:85`'s
  `move_and_slide()` consumes the very next line of `drive()`. There is no second write to
  `velocity` and no separate movement path for the lunge; it is additive into the one field the
  wall's collision already governs. The ROLLING branch (`match_state.gd:2441-2443`,
  `player.hero.velocity = player.hero.roll_direction * (...)`)  is the same story: one velocity
  field, one `move_and_slide()` consumer, covered by construction. No dedicated roll/lunge test
  was added — AC 5's guarantee is a property of `move_and_slide()` itself once ANY velocity value
  reaches it, which the wall-face and corner tests already exercise at values (10.0) exceeding
  every authored in-game speed (hero 3.0/5.0, roll-derived 6.0), so the physical guarantee is
  proven at a strictly harder case than the lunge or roll ever produce.
- **AC 6 (spawn placement measured, not fixed — the explicitly out-of-scope guarantee):**
  MEASURED, not assumed. `_compute_spawn_positions` (`match_runner.gd:889-919`) grows its search
  ring radius by `SPAWN_RING_STEP = 0.6` per step with NO upper bound (`while true`, no `ring`
  cap) — confirmed by reading the loop, matching the story's own "no cap, no arena test, no
  fallback branch" description. It sets `unit.global_position` DIRECTLY (`match_runner.gd:758`),
  bypassing `move_and_slide()` entirely, so a placement this search accepts is never subject to
  the wall's collision at all — this is the ONE path in `src/` that can place a body outside the
  ring, and it is `src/state/`-adjacent spawn math this story's own AC 8 rule forbids touching.
  **(corrected on review):** the Completion Note above modeled only the crowding path (many
  occupied candidate slots pushing the search outward) and is wrong as a conclusion — a much
  cheaper, always-available path reaches the ring boundary with ZERO occupants. Measured directly
  from `_compute_spawn_positions`/`_spot_is_clear`: the ring-0 candidate IS the base spot itself
  (`base := hero_position + away * SPAWN_BEHIND_DISTANCE`, `SPAWN_BEHIND_DISTANCE = 2.5`), and
  with an empty `occupied`/`placed` list `_spot_is_clear` accepts it immediately — one cast, no
  crowding required. So any hero within 2.5 units of a wall (measured along the away-from-opponent
  axis) places its very first candidate outside the ring on the first summon. Narrower still: a
  hero standing between 1.5 and 2.5 units off a wall places that first candidate INSIDE the wall's
  own collision volume (the East/West walls occupy `x` in `[20, 21]`/`[-21, -20]`; a hero at
  distance `d` from the wall plane produces a candidate at `d - 2.5` past it, which falls inside
  `[-21, -20]` for `d` in `[1.5, 2.5]`). The crowding path (150-200 rejected candidate slots to
  reach the boundary from near-center) is a real, separate way to reach the ring, but it is not
  the one that matters — the near-wall path requires no crowding and no unusual play, only a hero
  standing close to a wall when a summon is cast, which is an ordinary, easily reachable
  in-match state. No other movement path in `src/` (checked: no knockback,
  no push-back, no teleport of any `CharacterBody3D` exists anywhere) shares this property — the
  lunge and roll are both covered by construction per AC 5 above.
  **Fix pass (F1, operator-approved scope widening beyond AC 6/Non-Goals' original "measure, don't
  fix" text):** the original scope exclusion above stands as story history — this story's own text
  never asked for a fix. On review, the operator approved widening the story's scope to close the
  gap rather than leave it standing now that it was shown reachable with zero occupants.
  `_spawn_missing_unit_actors` (`match_runner.gd`) now clamps the accepted candidate's x/z into
  `[-SPAWN_CONTAINMENT_BOUND, SPAWN_CONTAINMENT_BOUND]` (`SPAWN_CONTAINMENT_BOUND = 19.6`, the
  arena half-extent 20.0 minus 0.4, the larger of the two spawnable actors' collision half-extents)
  before it is used to place the unit — a floor on the OUTPUT of the unchanged rear-arc search, not
  a change to the search's termination or "behind the hero" semantics. This is `src/main/`-side,
  not `src/state/` (AC 8/Non-Goals still hold: no `src/state/` file touched by this fix). Proven
  live by `test/integration/test_summon_spawn_containment_live.gd`: a hero pinned 1 unit off the
  West wall (`x = -19`) summons, and the spawned unit lands at `x = -19.6` (inside the ring) rather
  than at the un-clamped base spot's `x = -21.5` (inside the wall's own volume). Mutation-proven
  (table below): reverting the clamp reliably reproduces the out-of-ring spawn.
- **AC 7 (projectiles unaffected):** untouched by this story — `projectile_actor.tscn` was not
  edited, and no wall collision layer was authored that a `Node3D`-rooted projectile with no body
  collision could possibly interact with regardless. Confirmed by reading the wall's authoring
  (no layer/mask lines at all) rather than assumed from the story's own description.
- **AC 8 (scope discipline):** no `src/state/` file touched, no `BalanceConfig` field
  added/removed/renamed, no snapshot key introduced, no state-side clamp added anywhere. Touched
  files: `src/main/main.tscn` (wall geometry) and one new integration test + its generated `.uid`.
  `project.godot` untouched — confirmed byte-identical (`sha256sum`) before implementation, after
  implementation, and after the editor session that generated the new test's `.uid`.
- **AC 9 (golden UNMOVED):** predicted UNMOVED; MEASURED UNMOVED. Both `bash test/run_all.sh` runs
  report `=== 577 tests, 0 failed, 4433 assertions ===` and `ALL TESTS PASSED` — identical counts
  before and after, confirming `test_determinism.gd`'s hardcoded golden
  (`aa3566d7...ded7e4f`) held both times (a moved golden would have failed that one test, not
  merely changed a number). The only difference between the before/after integration file lists
  is the one new file this story adds. `project.godot` byte-identical throughout (see above).
- **AC 10 (headless test coverage, mutation-proven):** `test/integration/test_arena_edge_live.gd`
  added. **Design note, an implementation deviation from the AC's own suggested pattern, recorded
  with its reason:** driving movement through the real Input Map -> `KeyboardController` ->
  `MatchState` chain (the `test_unit_approach_live.gd` idiom the AC names) was tried FIRST via a
  throwaway diagnostic probe (deleted after use, never committed) and found unusable for this
  specific measurement for two independently-discovered reasons: (1) P1's and P2's heroes start
  only 6 units apart (`x = ±3`), so driving P1 straight at either the East or West wall (20 units
  away) runs it into P2's own hero body collision first, at roughly `x = ±2` — long before the
  wall; (2) camera-relative movement continuously RE-YAWS toward the live lock-on target every
  tick (`camera_rig.gd`'s `face_lock_direction`, confirmed `1.0` instant smoothing), so a held
  strafe direction curves into an arc around the (stationary) opponent rather than holding a
  stable line or diagonal — verified live by probing `p1_move_right` alone and watching the
  measured velocity vector rotate tick over tick from `(0, 0, 5)` toward `(4.8, 0, 1.5)` over 100
  frames while the hero was still 15+ units from any wall. Neither problem is a defect in
  anything this story touches (both are pre-existing hero-vs-hero collision and 4-6's own
  lock-relative movement design); they are simply the wrong tool for measuring a STATIC WALL's
  guarantee in isolation. **The test instead instantiates a THIRD, independent `hero.tscn` body**
  (answering to no input and no lock-on) into the real `main.tscn` scene, sets its `velocity`
  directly, and calls the inherited `CharacterBody3D.move_and_slide()` on it directly every tick
  — the exact same builtin method `hero.gd:85` calls, against the exact same collision shapes and
  world geometry, with P1/P2's own heroes left untouched and out of its path (start position
  offset in Z). This still satisfies AC 10's own text ("a spawned unit or hero actor... driven
  into the wall via repeated `move_and_slide()` ticks") — it is a real actor scene's real body,
  moved by the real engine method, against the real story-authored collision; only the DRIVER
  (direct velocity vs. input-chain) differs, and the wall's collision response has no way to tell
  the difference. Phase 1 drives it straight into the West wall's face (`x = -20`); Phase 2 adds a
  perpendicular component and drives it into the North-West corner. Both phases assert every tick
  that `|x|` and `|z|` never exceed `20 + 0.05`, and the end-of-run check requires the body to
  have actually gotten within 1.5 units of BOTH bounds (`NEAR_BOUND = 18.5`) — a non-vacuity
  guard, so a test that silently never reached the wall or corner would fail rather than
  false-pass. Individual run: PASS (`min_x=-19.5000 max_z=19.5000`).

### Mutation Proof Table

Target: `test/integration/test_arena_edge_live.gd`, run individually
(`godot --headless --path . --script res://test/integration/test_arena_edge_live.gd`). Backup
outside the repo (`C:\dev\_50d_backups\main.tscn.orig`,
`d0eb46f5d45a54a2333a210097f2d35b3047376686f3f50b027c7eff65e06e1a`), restore by copy-back +
SHA-256 verification, never `git checkout`. Provenance: MEASURED, both mutations run live this
dev pass.

| # | Mutation | `src/main/main.tscn` change | Result | Restore verified (SHA-256) |
| --- | --- | --- | --- | --- |
| 1 | Wall collision disabled | `WallWestCollision`'s `CollisionShape3D` gains `disabled = true` | FAIL — `min_x=-20.1667 max_z=8.0000 OUT_OF_RING at frame 122: pos=(-20.1667, 1.0000, 8.0000)` | `d0eb46f5...7ff65e06e1a` identical pre/post |
| 2 | Corner joint gap (first attempt, 1-unit gap) | `WallWestCollision` repointed to a new `BoxShape3D_wallew_mutation` sub-resource, `size = Vector3(1, 3, 38)` (2 units shorter, leaving a 1-unit uncovered strip at the North end) | PASS — did NOT reproduce a failure (`min_x=-19.5785 max_z=19.5002`); the probe body's own 1-unit-wide collision box is comparable in size to a 1-unit gap, so it stayed caught by the adjacent wall segments' overlap across the narrow opening. Recorded as a negative result, not discarded — it is what motivated widening the gap below. | `d0eb46f5...7ff65e06e1a` identical pre/post |
| 3 | Corner joint gap (widened, 10-unit gap) | Same sub-resource, `size = Vector3(1, 3, 30)` (10 units shorter, leaving a real 5-unit uncovered strip at the North end, `z` in roughly `[15, 20]`) | FAIL — `min_x=-20.1657 max_z=16.1667 OUT_OF_RING at frame 349: pos=(-20.1657, 1.0010, 16.1667)` | `d0eb46f5...7ff65e06e1a` identical pre/post |

Unmutated file: PASS (`min_x=-19.5000 max_z=19.5000 out_of_ring=false`) — confirmed immediately
after the final restore (mutation 3), matching the pre-mutation baseline run exactly.

**Fix pass (code review, all four faces/corners hardened) — same target and backup discipline,
new backup taken this pass (`C:\dev\_50d_backups\main.tscn.fixpass.orig`,
`d0eb46f5d45a54a2333a210097f2d35b3047376686f3f50b027c7eff65e06e1a` — identical hash to the original
dev-pass backup, confirming `main.tscn` was untouched between passes):**

| # | Mutation | `src/main/main.tscn` change | Result | Restore verified (SHA-256) |
| --- | --- | --- | --- | --- |
| 4 | Wall collision disabled (East face, review F4/F5) | `WallEastCollision`'s `CollisionShape3D` gains `disabled = true` | FAIL — `min_x=-19.5000 max_x=19.6677 max_z=19.5000 min_z=8.0000 OUT_OF_RING at frame 835: pos=(19.6677, 1.0000, 19.5000)` | `d0eb46f5...7ff65e06e1a` identical pre/post |

Unmutated file (post-hardening, all four faces/two corners): PASS
(`min_x=-19.5000 max_x=19.4999 max_z=19.5000 min_z=-19.4997 out_of_ring=false`) — confirmed
immediately after the mutation-4 restore.

**Spawn containment mutation (review F1, `src/main/match_runner.gd`) — new target
`test/integration/test_summon_spawn_containment_live.gd`, run individually.** Backup outside the
repo (`C:\dev\_50d_backups\match_runner.gd.fixpass.orig`,
`b8d0c590c71b8a336cd531857c777f5858694d65f2fc6cdb42a73278e84971ca`), restore by copy-back +
SHA-256 verification, never `git checkout`.

| # | Mutation | `src/main/match_runner.gd` change | Result | Restore verified (SHA-256) |
| --- | --- | --- | --- | --- |
| 5 | Containment clamp reverted | `_spawn_missing_unit_actors`'s accepted-candidate `placed.append(...)` reverted to the un-clamped pre-fix line | FAIL — `hero=(-19.0, 1.0, 0.0) spawn=(-21.5, 0.0, 0.0) contained=false out_of_ring(spawn=(-21.5, 0.0, 0.0) bound=19.600);` | `b8d0c590...e84971ca` identical pre/post |

Unmutated file: PASS (`hero=(-19.0, 1.0, 0.0) spawn=(-19.6, 0.0, 0.0) contained=true`) — confirmed
immediately after the mutation-5 restore.

### File List

- `src/main/main.tscn` (modified — AC 1/AC 2/AC 3/AC 4: four `StaticBody3D` wall segments +
  their `CollisionShape3D`/`MeshInstance3D` children and shared `BoxShape3D`/`BoxMesh`
  sub-resources; cosmetic pass, operator-approved AC 2 deviation (F8/smoke): shared
  semi-transparent `StandardMaterial3D` assigned to all four wall meshes)
- `test/integration/test_arena_edge_live.gd` (new — AC 10 headless coverage, mutation-proven;
  fix pass F4-F7: hardened with East-face/SE-corner phases, tightened center-bound assertion,
  named phase-boundary constants, distinct-failure end condition)
- `test/integration/test_arena_edge_live.gd.uid` (generated by editor scan; new)
- `src/main/match_runner.gd` (fix pass F1 — modified: `_spawn_missing_unit_actors` clamps the
  accepted spawn candidate into the ring; new `SPAWN_ARENA_HALF_EXTENT`/`SPAWN_CONTAINMENT_MARGIN`/
  `SPAWN_CONTAINMENT_BOUND` constants)
- `test/integration/test_summon_spawn_containment_live.gd` (fix pass F1 — new: proves the spawn
  containment clamp, mutation-proven)
- `test/integration/test_summon_spawn_containment_live.gd.uid` (fix pass — generated by editor
  scan; new)

### Change Log

| Date | Change |
| --- | --- |
| 2026-09-03 | Story authored via `gds-create-story`. |
| 2026-09-03 | Dev pass: four-segment `StaticBody3D` ring wall added to `src/main/main.tscn` (no `project.godot` edit — default layer 1, byte-identical confirmed), `test_arena_edge_live.gd` added and mutation-proven (2 mutations, one widened after a first attempt was too narrow to reproduce failure). AC 6 spawn-placement gap measured and found unbounded-by-construction but unreachable in normal play at this arena size; AC 5's lunge/roll claims re-verified from the code. Golden and snapshot key set measured unmoved both directions (577/0/4433 identical before/after, +1 integration file). Status -> review.|
| 2026-09-03 | Fix pass (code review F1-F7): corrected two false Dev Agent Record claims (F2 AC 6 spawn note understated risk — a near-wall summon reaches the ring/wall volume with zero occupants, not only via crowding; F3 corner-geometry description was a butt-joint not an overlap). Hardened `test_arena_edge_live.gd` (F4-F7): added East-face and SE-corner phases covering all four faces and both diagonals, tightened the ring assertion to the physically-correct `|19.5| + epsilon` center bound, removed dead end-condition conjuncts, named phase-boundary constants. Added runner-side spawn containment (F1, operator-approved scope widening) in `src/main/match_runner.gd` so a summoned unit's spawn position cannot land outside the ring, with new integration coverage and a mutation proof. Status remains `review`.|
| 2026-09-03 | Cosmetic pass (operator-approved AC 2 deviation, F8 + live smoke): assigned a shared semi-transparent `StandardMaterial3D` (grey-blue, alpha 0.35) to the four wall meshes in `src/main/main.tscn` so the hero stays visible through a wall when a forced-lock-on camera exits the ring, instead of being occluded by an opaque wall. Collision untouched; golden and snapshot key set measured unmoved (577/0/4433 identical, 52 integration files). Status remains `review`.|
