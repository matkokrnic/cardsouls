---
baseline_commit: 1ddff872cdbc677b78d06992c61928b58730d9b6
---

# Story 4.3c: Minion rig adoption

Status: review

## What this story inherits

This is the presentation half of the minion, on the same split shape `3-0a-rig-adoption` already
executed for the hero. `4-3`, `4-3a` and `4-3b` built the minion entirely in state — approach,
collision, hp, damage, death, and a windup/active/recovery attack rhythm — and it has been playtested
and reviewed as a grey box the whole time. `4-3b`'s own close-out named this story's forcing point
explicitly (`4-3b/R27`, decision-log Session 2026-08-12): "the rig/model/animation work (DEBT E) …
[has] NO OWNER AND NO SLOT — the binding constraint on reaching intended enemy behaviour. The rig
story gets an owner and a slot at the E4 close-out, ahead of the attack selector." `4-3b/R25` recorded
why: "the attack has no visual telegraph, so the operator could not see a swing begin or test evading
it" — two of the six live-smoke points he could not measure. The melee retune (`E3-R/R3`) was
therefore CUT to a single field edit (`4-3b/R26`, executed 2026-08-13: `minion_attack_windup_seconds`
`0.5 -> 0.9`) rather than opened in full, with the rest of the feel checklist deferred until "real
models and animations exist" — this story.

`3-0a-rig-adoption` did the identical job for the hero and is `done`, pushed, reviewed. Its solved
problems are inherited BY NAME, not rediscovered — see Dev Notes for exactly which ruling each one
follows.

This story touches presentation only. Every field, seat, and mechanism `4-3b` built in
`src/state/` is read, never added to or changed.

## Story

As a player,
I want the summoned minion to be an animated creature — standing, walking, winding up and striking,
dying and falling — instead of a grey box,
so that I can see a minion's attack coming and read its rhythm, the way `3-0a` already let me read the
hero's.

## Acceptance Criteria

1. **Assets committed to the repo.** `assets/characters/skeletonzombie/` contains `skeletonzombie.fbx`
   (skinned, textured) plus four clip files without skin — `idle.fbx`, `walk.fbx`, `attack.fbx`,
   `death.fbx` — all Mixamo, all on the same skeleton, committed directly to git (no LFS, the `3-0a`
   precedent). **Measured inventory, sizes recorded rather than assumed** (Dev Notes has the full
   table with per-file sizes). Import is clean — `root_scale = 1.0`, no `BoneMap`/retarget, no
   hand-edited scale in any `.import` — on the `3-0a` AC2 precedent applied verbatim. **Per-clip Hips
   displacement is MEASURED, not trusted from the operator's visual check**, on the `3-0a` AC6/R9
   measurement discipline (`mixamorig_Hips` position track, first key vs. last key, via the same
   headless-script method `3-0a` used against `paladin_anims.res`): `idle` and `walk` are expected
   net-zero; `attack` is expected to carry a mid-clip forward step that RETURNS to net-zero by the
   last key (measured, not assumed — a clip that does not return needs the same accepted/rejected
   judgment `3-0a` AC6 applied to `death`); `death` is expected to carry a net topple that HOLDS by
   the last key (measured, not assumed). **This AC measures and records that topple; it accepts
   nothing — corrected at this fix pass (`4-3c/R10`)** — acceptance and its reasoning are `4-3d`'s (see
   `4-3d-minion-strike-alignment-and-corpse-lifecycle.md` AC 2, `4-3d/R3`). Source and licence
   recorded in Dev Notes: Mixamo, commercial use
   permitted.

2. **The model replaces the grey box in `unit_actor.tscn`, parented under the ROOT — not under
   `Mesh` — on the readiness gate's ruling (`4-3c/R3`).** **Measured, not assumed, unlike `3-0a`'s
   case**: a content search of `test/` and `src/` for any reference to the `Mesh` node under
   `unit_actor.tscn` (`get_node("Mesh")`, `$Mesh`, or a typed `MeshInstance3D` binding) finds **none**
   — `test_visible_facing.gd` reads the HERO's `Mesh`/`Hitbox` only (`test_visible_facing.gd:31-32`),
   and `unit_actor.gd` holds no `@onready` reference to its own `Mesh` node at all. **This is a real
   difference from `3-0a`'s hero case, named rather than silently carried over**: the hero's `Mesh`
   node is a fixed yaw sink `HeroActor.drive()` rotates directly, and `3-0a`/R1 ruled the node a fixed
   point for exactly that reason. The minion has no equivalent dependency — its yaw sink is the
   `UnitActor` **ROOT** itself (`aim_at()`/`aim_along()` both write `global_rotation.y` on the whole
   `CharacterBody3D`, `unit_actor.gd`), and the `Mesh` child is a plain undecorated grey-box visual
   with nothing else naming it.

   **The `3-0a`/R1 discipline (box geometry deleted, node survives, model parented under it) does
   NOT transfer here, and the story's earlier discretionary framing pointed the wrong way — corrected
   by the gate.** Measured against `unit_actor.tscn`: `Mesh` carries `transform` origin
   `(0, 0.6, 0)` — an offset of **+0.6 upward** — because the unit ROOT sits at the body box's FEET
   (`Collision`, `Hurtbox`/`HurtboxShape`, `Hitbox`/`HitboxShape` all carry the identical `+0.6` y
   offset for the same stated reason, `unit_actor.tscn`'s own node descriptions). This is the mirror
   image of the hero's geometry, not the same shape: `hero.tscn`'s root sits at the body CENTRE, so
   its `Mesh` node needed a COMPENSATING DOWNWARD offset (`Mesh.position.y = -1.0`, added in `3-0b`
   Pass 3b) to ground a feet-origin Mixamo model whose own origin already sits at its feet. Parenting
   this story's feet-origin model under the minion's `Mesh` node would ADD its `+0.6` offset a second
   time on top of the model's own already-zeroed origin, hovering the model 0.6 units above the
   ground — the same class of defect `3-0b` had to fix on the hero, reintroduced here by following a
   precedent that does not apply to this actor's geometry.

   **Correct mechanism: the skinned model parents DIRECTLY UNDER THE ROOT** (`self`, the
   `CharacterBody3D`), where the origin already sits at the feet with no offset to counteract. The
   placeholder's `BoxMesh_unitbox` geometry and the `Mesh` node's `+0.6` transform both go — the dev
   pass records whether `Mesh` survives as an empty, retargeted parent for the model (renamed or not)
   or is deleted outright with the model parented straight under `UnitActor`; either is acceptable,
   the choice is a recordable micro-decision (the `3-0a` AnimationPlayer-parenting-micro-decision
   precedent), but the model's own origin gets NO added offset either way. The skinned model imports
   at its native Mixamo scale (`root_scale = 1.0`, no manual correction, the `3-0a` AC2 rule applied
   verbatim) — the minion's final on-screen size is explicitly **not** decided by this story
   (Non-Goals).

   **Machine contract (`4-3c/R3`): a minion counterpart of the hero's vertical-alignment test.** The
   hero's floating defect shipped for a whole story (`3-0a`) before anyone noticed, because nothing
   asserted an absolute spatial relationship — `test_vertical_alignment.gd` (`3-0b`) closed that hole
   for the hero. This story ships the same class of test for the minion, pinning the imported model's
   lowest vertex to the body box's floor (`Collision`'s `BoxShape3D_unitbody` bottom, world-space,
   cross-checked against the ground plane the runner itself spawns minions onto — **corrected at this
   fix pass (`4-3c/R13`)**: minions have no spawn scene node the way the hero's `main.tscn` spawn point does; they
   are placed from code, `_spawn_missing_unit_actors`'s own `unit.global_position = Vector3(UNIT_ROW_X[slot],
   0.0, ...)` call (`match_runner.gd:650-657`) — the cross-check target is that `0.0` world-Y ground
   constant, not a spawn node). A relative measure (e.g. the clips' own
   Hips-track excursion, AC 1) is mathematically blind to a constant offset the way `3-0b`'s Dev Notes
   found for the hero; only an absolute assertion catches it.

3. **Four clips in one `AnimationLibrary`, with a mutation-proven headless integration test.** The
   test instantiates `unit_actor.tscn` (or the scene the model is assembled into) and asserts: exactly
   four animations; the four names `idle`, `walk`, `attack`, `death`; loop **enabled** for
   `idle`/`walk`, **disabled** for `attack`/`death`; and the absence of the model's own bundled Mixamo
   take (`mixamo_com`) anywhere in the instantiated scene. The exclusion route is `3-0a`/R10's
   sanctioned `EditorScenePostImport` substitution (`strip_model_anim.gd`, `assets/characters/paladin/`),
   applied to `skeletonzombie.fbx` — the named `animation/import = false` route is **not** attempted
   first and then found broken again; `3-0a` already measured it broken on this engine build (4.6.3)
   and that finding travels forward rather than being re-discovered. The test is proven by mutation on
   the `3-0a` AC3 precedent: a deleted clip and a re-added `mixamo_com` clip must each independently
   fail it, proven against a SHA256-verified out-of-repo backup of the assembled library resource,
   restored by copy-back, never `git checkout --`.

4. **A presentation controller selects the clip, PUSHED from an existing per-tick seat — the one
   genuinely new problem in this story.** The hero's `animation_controller.gd` listens on
   `action_state_changed`, a signal fired on state TRANSITION (`3-0a` AC4). The minion has no such
   signal: `4-3b`'s attack rhythm lives as a plain scalar per board index
   (`UnitBoard.attack_phase_at(index)`, `unit_board.gd:101` for the `AttackPhase` enum), units carry no
   per-record signal at all (`unit_board.gd`'s own header, cited in `4-3b`'s Dev Notes), and the runner
   already reads that scalar every frame. **The seat is `MatchRunner._aim_unit_actors`**
   (`match_runner.gd:706-734`), which today reads `player.units.attack_phase_at(index)` at line 725 to
   decide whether to aim from the live target or the locked swing direction — it already touches every
   spawned, alive unit actor once per physics frame, in the same tick-phase family
   `_free_dead_unit_actors`/`_approach_unit_actors` sit in. This story's controller is PUSHED the
   phase (and, for the idle/walk split, the unit's own velocity magnitude — see below) from that
   existing call, on the identical reasoning `3-0a`/R2 used for the hero's `run` clip: no new
   `_process`, no second `_physics_process` (F1 intact), no new seam, no state handle, no polling.

   **`_aim_unit_actors` gains a liveness gate it has none of today (`4-3c/R4`).** Measured: today the
   loop is invisible to this gap only because a dead unit's actor is freed the same tick death is
   observed (`_free_dead_unit_actors`, immediately above it in the frame) — so `_aim_unit_actors`
   never sees a corpse. `4-3d`'s corpse-linger change (see the split note above) changes that seat to
   linger a corpse's actor instead of freeing it immediately, so after this story a dead-but-lingering
   actor DOES reach `_aim_unit_actors` on later ticks with no liveness check guarding it. This gate
   belongs in `4-3c` even though the corpse linger itself ships in `4-3d`: it is correct on its own
   regardless of when a corpse exists, and `4-3d` depends on it rather than adding it — a seat `4-3d`
   did not change should not become `4-3d`'s obligation to fix.

   **Ordering requirement, made explicit — the operator's ruling (`4-3c/R15`), the reason this fix
   pass exists.** The controller PUSH (phase + velocity, described above) and this liveness gate are
   two separate things in the same loop body, and their ORDER is a machine contract, not prose a dev
   pass could read either way: **the push happens FIRST, unconditionally, for every actor index the
   loop reaches; the liveness check that governs AIMING comes AFTER.** An early per-actor
   `if not is_alive_at(index): continue` placed at the TOP of the loop body, ahead of the push, would
   also skip the push for a dead unit — the presentation controller would never be told the unit died.
   In `4-3c` alone this is invisible (a dead unit's actor is freed the same tick, so the loop never
   reaches a dead index at all); in `4-3d`, where the corpse LINGERS and `4-3c` builds no liveness
   gate of its own, a controller that never received the push would freeze on whatever clip it last
   held — a corpse frozen in a half-raised claw instead of playing `death`. Mechanism, corrected:
   `_aim_unit_actors` pushes phase/velocity to the controller for the index FIRST; only then does it
   check `player.units.is_alive_at(index)` to decide whether to compute a live-target aim or leave the
   unit at its last-aimed heading, on the identical `is_alive_at`-first-unconditionally precedent
   `_advance_unit_attacks` (`match_state.gd`) and `_approach_unit_actors` (`match_runner.gd:770`)
   already both established for their own reads — applied here to the AIM decision only, never to
   whether the push happens; a dead unit is left at its last-aimed heading,
   exactly as `aim_along`'s own zero-heading precedent already does for a unit with no locked
   direction yet.

   **Clip selection**, stated as the rule this story requires (the dev pass wires it, does not
   re-derive it): `idle` when the unit is idle (`AttackPhase.IDLE`) and not moving; `walk` when idle
   and moving; `attack` across the WHOLE windup/active/recovery cycle (`AttackPhase.WINDUP`,
   `.ACTIVE`, and `.RECOVERY` all select the same clip — there is one attack clip, not three); `death`
   whenever `UnitBoard.is_alive_at(index)` is false, **checked before phase**, because a unit killed
   mid-swing keeps its frozen `attack_phase` value forever (`_advance_unit_attacks`,
   `match_state.gd:748-775`, "skips dead units" — the phase is never reset to `IDLE` on death; only
   liveness tells the controller the swing is over). **"Moving" is read the same way `3-0a` read the
   hero's `run` threshold**: presentation-locally, off the actor's own `CharacterBody3D.velocity`
   magnitude (set every drive-phase tick by `UnitActor.approach()`), against a small epsilon constant
   on the `RUN_SPEED_EPS` precedent (`3-0a` Completion Notes) — **not** authored or tuned in this
   story, adoption only needs a working idle/walk split. `walk`, not `run`, is chosen deliberately
   (see Live Smoke) because the minion's authored move speed is slow; this is stated as a design
   choice already made by this AC, not left for the dev pass to pick a clip name.

   **The velocity signal is corrected, not carried as stated — the path list REWRITTEN against the
   measured code, not the earlier description (`4-3c/R5`, corrected at this fix pass, `4-3c/R12`).**
   `CharacterBody3D.velocity` is a persistent physics property that holds whatever it was last set to
   across ticks; it is not implicitly zeroed by Godot between frames. Measured against
   `_approach_unit_actors` (`match_runner.gd:754-782`), the ONLY two paths that (a) never reach
   `UnitActor.approach()` AND (b) have a live, valid unit node in scope to write to are:
   - `match_runner.gd:776-777` — `if target_slot == TargetingService.NO_TARGET_SLOT: continue`.
   - `match_runner.gd:780` — the implicit fall-through when `target_position is Vector3` is false (no
     explicit `continue`; the `if` simply does not match and the loop iteration ends). This is the
     non-Vector3 case the story's own prose already names as a defect source, and it needs the same
     fix even though it is not a `continue` statement.

   **Explicitly NOT in scope, and why — three paths the earlier version of this AC wrongly implied
   were covered:**
   - `match_runner.gd:758-759` — `if balance == null: return`. An EARLY RETURN for the whole slot,
     before the per-actor loop even starts; there is no single actor's velocity to zero here.
   - `match_runner.gd:762-763` — `if not player.units.has_index(index): continue`. This runs BEFORE
     `var unit: Node = actors[index]` (line 772) — no node reference exists yet at this point.
   - `match_runner.gd:770-771` — `if not player.units.is_alive_at(index): continue`. Also runs BEFORE
     line 772 — same reason, no node in scope.

   A unit that stops acquiring a resolvable target after having moved (target lost or out of range)
   therefore keeps its LAST nonzero `velocity` forever without this fix, and this story's `walk` clip
   would play on a standing-still minion indefinitely — the defect the gate named. **Fix: zero the
   actor's own velocity at exactly the two paths listed above** — the same "holds still rather than
   drifting" contract `UnitActor.approach()` already applies for the within-`stop_distance` case,
   extended to the paths that never reach `approach()` at all. This is a presentation/actor
   bookkeeping change (the actor's own built-in physics property), not a `src/state/` write, so it
   stays inside this story's Non-Goals.

**AC 5 and AC 6 are CUT to a new story, `4-3d-minion-strike-alignment-and-corpse-lifecycle`
(`4-3c/R2`, ratified by the operator).** The gate's own recommendation: AC 5 (strike-to-active-window
alignment) is a feel-and-timing requirement of exactly the kind the hero's own rig story (`3-0a`)
deferred into its successor (`3-0b`) — this story's own Dev Notes already quote the rule that
animation durations are left untouched at adoption. AC 6 (corpse lifecycle) is not presentation at
all: it changes actor LIFETIME, reaching four separate runner loops, invalidating two shipped
comments (one of them inside `src/state/`), changing what the intent recorder's contact tap sees,
and interacting with both the debug pause and the debug reset — a change class this story's own
scope statement ("presentation only… reads state, writes nothing to state, adds no snapshot field")
does not fit. `4-3d` is `backlog`, placed directly after this story on the board, and depends on it
(most directly on AC 4's new liveness gate above). See `4-3d-minion-strike-alignment-and-corpse-lifecycle.md`
for the full AC text, measurements, and the rulings that travel with it.

## Non-Goals (explicit)

- **A hit-reaction clip.** There is no event telling presentation a minion was damaged (`4-3a/R12`'s
  standing asymmetry, reaffirmed unaddressed by `4-3b/R32`), and `4-3b` AC 10/Non-Goals rule that
  damage never interrupts a swing. Both would have to change first; neither does here.
- **Blending between clips, cancel windows, or tempo tuning.** The `3-0a` "clip-end and mid-clip
  policy (adoption level only)" applies verbatim: a non-looping clip that ends while its state
  persists holds its final pose; a state transition mid-clip wins immediately, with no blending.
- **Strike-to-active-window alignment and corpse lifecycle** — CUT to `4-3d` (`4-3c/R2`), not built
  in this story at all. See the note above AC 5's former position.
- **Scaling the minion down.** The operator wants it visually smaller so heroes stand out, but the
  collision shape (`BoxShape3D_unitbody`/`BoxShape3D_unithitbx`, `unit_actor.tscn`) and reach
  (`minion_attack_reach_distance`, authored balance) do **not** follow a visual scale change — this is
  one decision about three numbers (visual scale, collision size, reach) and it is taken at the Live
  Smoke, with Matko as the named owner, not silently decided here. **Named deferral, recorded rather
  than left implicit**: if the operator rules for a smaller minion at smoke, that is a follow-up story
  or fix-pass, not a same-pass edit landed under this AC list.
- **Per-kind data, totems, projectiles, movesets.** Minions still run one shared set of attack-rhythm
  scalars (`4-3b` AC1); this story adds no new `BalanceConfig` field of any kind — it is presentation
  only. Per-kind conversion is `4-4`'s opening act (`4-3b`'s own close-out, "Leaves LIVE for
  successors").
- **Any change under `src/state/`.** This story reads `UnitBoard.attack_phase_at`,
  `UnitBoard.is_alive_at`, and the actor's own `velocity` — it writes nothing to state and adds no
  snapshot field.

## Tasks / Subtasks

- [x] `.gitattributes` — RESOLVED, not opened at dev (`4-3c/R8`). Confirmed by `git check-attr -a`
      against a synthetic path under `assets/characters/skeletonzombie/`: the existing rules are bare
      extension wildcards (`*.fbx`, `*.png`), not directory-scoped, so they already cover the new
      directory with no edit needed. (AC: 1)
- [x] Confirm the asset inventory against git status and record exact file sizes in Dev Notes;
      measure Hips-track displacement for all four clips via the same headless-script method `3-0a`
      used, record the full table (AC: 1)
- [x] Search `src/` and `test/` for any dependency on `unit_actor.tscn`'s `Mesh` node before touching
      it; record the finding (expected: none) rather than assuming `3-0a`'s hero case transfers (AC: 2)
- [x] Delete the placeholder's `BoxMesh_unitbox` geometry and `Mesh`'s `+0.6` transform; parent the
      skinned model DIRECTLY UNDER THE ROOT, not under `Mesh` (`4-3c/R3`) — `Mesh` may survive empty
      as the model's parent node or be deleted outright, dev pass's choice, but the model's own origin
      gets no added offset either way; import at native scale, no manual correction (AC: 2)
- [x] Add the minion vertical-alignment test, the `3-0b`/`test_vertical_alignment.gd` counterpart:
      pin the imported model's lowest vertex to the body box's floor, absolute world-space. **Named
      mutation (`4-3c/R11`)**: re-parenting the model under `Mesh`, or restoring `Mesh`'s upward
      offset onto the model's own parent, must turn the test red — the exact defect it exists to
      catch (AC: 2)
- [x] Add `strip_model_anim.gd` (or a copy adapted for this model) as `skeletonzombie.fbx`'s
      `EditorScenePostImport` hook, on the `3-0a`/R10 sanctioned route; assemble the four clips into
      one `AnimationLibrary` via the editor under the `3-0a`/R3 protocol (git diff / project.godot
      hash check after every editor session) (AC: 3)
- [x] Add the mutation-proven headless integration test pinning four clips, their names, the loop
      matrix, and `mixamo_com` absence (AC: 3)
- [x] Add the presentation controller (new file under `src/actors/minions/`); wire it as a per-unit
      read-only node, pushed from `_aim_unit_actors`'s existing per-tick call, UNCONDITIONALLY FIRST
      in the loop body, before the liveness check below — no new seam, no `_process`, no
      `_physics_process` (AC: 4)
- [x] Add a liveness gate to `_aim_unit_actors` AFTER the controller push above, never before
      (`is_alive_at` before its existing `attack_phase_at` read, gating the AIM decision only —
      operator's ordering ruling, `4-3c/R15`) — belongs here regardless of the corpse linger's own
      `4-3d` timing, because the seat is wrong on its own and `4-3d` depends on this fix rather than
      re-doing it (`4-3c/R4`) (AC: 4)
- [x] Zero the actor's own `velocity` at exactly the two paths named in AC 4 (the `NO_TARGET_SLOT`
      continue and the non-`Vector3` fall-through, both `match_runner.gd:754-782`) so a lost/unresolved
      target does not leave a stale nonzero velocity driving the walk clip forever (`4-3c/R5`,
      path list corrected `4-3c/R12`) (AC: 4)
- [x] Implement clip selection: death-checked-first, then attack (any of windup/active/recovery), then
      idle/walk split on the actor's own velocity magnitude against a named, untuned epsilon constant
      (AC: 4)
- [x] Add the mutation-proven headless test for clip selection: liveness checked before phase is a
      NAMED mutation target — swapping the liveness check below the phase check must turn the
      killed-mid-swing case red (`4-3c/R6`) (AC: 4)
- [x] Measure the golden BOTH directions (before/after); confirm the hash unmoved (AC: Golden
      Prediction)
- [x] Measure `project.godot` byte-identity both directions; name `unit_actor.tscn` (and, if the
      editor scan registers a new `class_name`, that collateral) as the file(s) that legitimately
      change (AC: Golden Prediction)
- [x] Hash `project.godot` before and after every editor session in this pass (not only at the
      bookends) and restore on any deletion of the `physics_ticks_per_second` pin or `config/features`
      reordering — the sixth recorded instance of this editor collateral, per this story's own
      corrected precondition finding (Dev Notes)

## Dev Notes

- **Measured asset inventory (precondition check, this story's authoring pass, 2026-08-14).**
  `assets/characters/skeletonzombie/` currently holds, verified by `ls -la` against the untracked
  directory: `skeletonzombie.fbx` (16.7 MB, skinned + embedded texture references), `idle.fbx`
  (694 KB), `walk.fbx` (433 KB), `attack.fbx` (551 KB), `death.fbx` (710 KB), plus FIVE extracted
  textures the importer pulled from the model's embedded material (`skeletonzombie_0.png` 4.2 MB
  through `skeletonzombie_4.png` 3.0 MB — the largest, `_1.png`, is 4.9 MB) and a `.import` sidecar
  for every one of the above ten files. **This is the expected shape, on the `3-0a` precedent**
  (paladin.fbx also embedded its own textures and the importer extracted three PNGs the same way) —
  not a manual asset-prep step this story owns. **Total on-disk size, all `.fbx`/`.png` source
  assets, CORRECTED at this fix pass (`4-3c/R7`): approximately 35 MB, not the ~34 MB this story
  first estimated** — measured directly (`du -sb` sum of the ten `.fbx`/`.png` files, excluding
  `.import` sidecars): 36,707,750 bytes, ≈35.0 MB. Recorded here so the dev pass commits the measured
  figure, not a guess, on the `3-0a`/R6 precedent of correcting an earlier wrong estimate rather than
  carrying it forward. Committed directly to git, no LFS, on the standing `3-0a` ruling that this
  repo does not use LFS for character assets, restated at the corrected ~35 MB figure rather than
  cited at the older, smaller one.
- **The `Mesh`-node dependency search, measured for this story's authoring pass.** Content search
  (`get_node("Mesh")`, `$Mesh`, any typed `MeshInstance3D` binding) against `src/` and `test/` for
  anything scoped to `unit_actor.tscn` or `UnitActor`: zero hits. `unit_actor.gd` holds no `@onready`
  reference to its own `Mesh` node — the two `@onready`/direct references it does hold are
  `@onready var hitbox: Area3D = $Hitbox` and the two yaw calls (`aim_at`/`aim_along`), both of which
  write `global_rotation.y` on the ROOT (`self`), never on `$Mesh`. `test_visible_facing.gd:31-32`
  reads `_p1.get_node("Mesh")`/`get_node("Hitbox")` — `_p1` is a HERO (`HeroActor`), not a
  `UnitActor`; this test has no minion-scoped assertion at all. **Conclusion: unlike `3-0a`'s hero
  case, nothing forces the minion's `Mesh` node to survive as a fixed point.** The absence of a
  dependency is confirmed, but **the `3-0a`/R1 discipline itself does NOT transfer, corrected at this
  fix pass (`4-3c/R3`/AC 2)** — `Mesh` carries a `+0.6` upward transform (measured, `unit_actor.tscn`)
  that a feet-origin model parented under it would inherit a second time, hovering the model above
  the ground exactly as the hero's own pre-`3-0b` defect did, in mirror. The model parents directly
  under the ROOT instead; see AC 2 for the full measurement and the vertical-alignment test that
  machine-checks it.
- **The yaw sink is the ROOT here, not a child node — the one structural difference from `3-0a` worth
  naming explicitly.** `unit_actor.gd`'s `aim_at()`/`aim_along()` both assign `global_rotation.y` on
  `self` (the `CharacterBody3D` root), documented in the script's own comment: "ROTATING THIS ROOT IS
  SAFE, unlike the hero's (DECISION A) … this scene's only child is a mesh, it carries no camera and
  nothing reads its basis." So wherever the skinned model and its `AnimationPlayer` end up parented,
  they inherit the root's yaw automatically — there is no equivalent of `3-0a`'s "which node does
  `drive()`'s single `atan2` rotate" constraint to satisfy here, because the whole root already is
  that node.
- **The phase-push seat, measured against this tree (AC 4).** `MatchRunner._aim_unit_actors`
  (`match_runner.gd:706-734`) is called once per physics frame per slot
  (`match_runner.gd:1304-1305`), walks every spawned actor bounded by the actor array
  (`for index: int in actors.size()`), and at line 725 already reads
  `player.units.attack_phase_at(index)` to decide whether to aim from the live target or the locked
  swing direction (`4-3b` AC 12). This is the one seat that already touches every live unit actor
  every tick with the exact scalar this story needs — pushing the phase (and, for idle/walk, the
  actor's own velocity) to the new controller from inside this same loop needs no new call, no new
  loop, and no new seam, on the identical reasoning `3-0a`/R2 used for the hero's `run` clip (the
  seat that "already runs once per tick regardless" gets an extra payload on its existing call).
  **Ordering note, CORRECTED at this fix pass (`4-3c/R4`):** `_free_dead_unit_actors` runs BEFORE
  `_aim_unit_actors` in the frame (`match_runner.gd:1287-1288` vs `1304-1305`) — today that means a
  unit that died THIS tick has already had its actor freed before `_aim_unit_actors` would see it, so
  `_aim_unit_actors` has NO liveness check today and the gap is invisible. This story's own AC 4 now
  adds that liveness gate (checking `is_alive_at(index)` to decide the aim path) regardless of corpse
  lingering, because the seat is wrong on its own; `4-3d`'s own corpse-linger change (moved out of
  this story, see the split note above) is what makes a dead-but-lingering actor actually REACH this
  seat on later ticks, and it depends on this gate already existing rather than adding it itself.
  **Ordering, corrected at this fix pass — the operator's ruling (`4-3c/R15`): the controller push
  comes FIRST, unconditionally; the `is_alive_at(index)` check that gates the aim path comes AFTER.**
  A liveness check placed ahead of the push would also skip the push, and a lingering corpse in
  `4-3d` would then never be told it died — see AC 4 above for the full reasoning.
- **The push seat reads the PREVIOUS tick's velocity, not this tick's — worth recording, not a bug.**
  `_aim_unit_actors` (`match_runner.gd:1304-1305`) runs BEFORE the drive phase's
  `_approach_unit_actors` (`match_runner.gd:1324-1325`) in the same frame's `_physics_process`, and
  `_approach_unit_actors` is the seat that calls `UnitActor.approach()`, the only place a unit
  actor's `velocity` is set. So the velocity the controller reads via this tick's push is whatever
  `approach()` set on the PREVIOUS tick, one frame stale. Harmless for an idle/walk split at 60 Hz —
  a one-tick-old speed reading does not visibly change which clip is selected — but written down here
  so it is not later rediscovered as a bug.
- **Why a dead unit's `attack_phase` cannot be trusted as "not attacking," measured (AC 4).**
  `MatchState._advance_unit_attacks` (`match_state.gd:748-775`) is the sole writer of a unit's phase;
  its own guard at **line 753** (paraphrased: acts only while the unit is alive — CORRECTED at this
  fix pass, `4-3c/R7`, from an earlier "line 755" off by two) means a unit killed
  mid-windup/active/recovery has its phase FROZEN at whatever value it held at the kill tick, forever
  — nothing ever resets it to `IDLE` on death. A controller that checked phase before liveness would
  show a corpse still winding up or swinging. Checking `is_alive_at` first, unconditionally, is not
  an optimization — it is the only correct read.
- **Source and licence (AC 1).** The zombie model, its skeleton, and the four clips come from
  Mixamo; commercial use is permitted — the identical provenance and licence `3-0a` recorded for the
  paladin.
- **`walk`, not `run` (AC 4) — a deliberate choice, not a naming accident.** The minion's authored
  move speed (`unit_move_speed`, `balance_config.gd`) is slow relative to a hero's run — a walk clip
  reads correctly at that speed where a run clip would look like the feet are skating. This is named
  explicitly as a Live Smoke watch item because it is a judgment call about how the clip reads, not a
  measured fact the way the Hips-displacement table is.
- **Golden Prediction reasoning, stated rather than assumed.** This story touches no `src/state/`
  file, adds no `BalanceConfig` field, and writes no `MatchState`/`UnitBoard` field — every AC above
  is scoped to `assets/`, `src/actors/minions/`, and `src/main/match_runner.gd`'s existing
  `_aim_unit_actors`/`_approach_unit_actors` seats (presentation reads only, no new state write; the
  `_free_dead_unit_actors` corpse-linger change moved to `4-3d`). The
  golden fixture (`test/state/test_determinism.gd`) runs `MatchState` alone with no runner and no
  physics (the same structural fact `4-3b`'s own Golden Prediction measured), so it cannot even reach
  an actor, an `AnimationPlayer`, or a collision-disable call. **Predicted UNMOVED — to be MEASURED IN
  BOTH DIRECTIONS at the dev pass, not asserted from this reasoning alone.**
- **`project.godot` byte-identity — the corrected precondition finding for this story, carried
  forward as a mandatory obligation, not a background nicety.** During this story's own authoring
  pass (2026-08-14), opening the Godot editor to let the operator inspect the newly-added assets
  reordered `config/features` and DELETED the `common/physics_ticks_per_second=60` pin from
  `project.godot` — **the SIXTH recorded instance** of this exact editor collateral (`3-0a`'s Dev
  Notes named it the fifth). The deletion was caught and the file restored before this story was
  authored. Because this story's own dev pass necessarily opens the editor at least once (asset
  import verification, `AnimationLibrary` assembly, AC 3), **the dev pass MUST hash `project.godot`
  before and after every single editor session in this story, not only at the story's opening and
  closing bookends**, and restore immediately on any deletion of the tick pin or reordering of
  `config/features`, reporting each check. This is the `3-0a`/R3 protocol applied with the session
  granularity this story's own precondition check just demonstrated is necessary.

### Project Structure Notes

- `assets/characters/skeletonzombie/` — new asset directory: `skeletonzombie.fbx`, `idle.fbx`,
  `walk.fbx`, `attack.fbx`, `death.fbx`, five extracted `.png` textures, all `.import` sidecars, a
  `strip_model_anim.gd`-shaped `EditorScenePostImport` hook, and the assembled
  `skeletonzombie_anims.res` `AnimationLibrary` — the identical artifact shape `3-0a` established and
  `docs/game-architecture.md`'s Directory Tree already itemizes generically (`characters/<name>/`,
  amendment A5) — **no further architecture amendment is needed**, unlike `3-0a` which had to queue
  one.
- `src/actors/minions/unit_actor.tscn` — placeholder box geometry and `Mesh`'s `+0.6` transform
  removed; skinned model parented DIRECTLY UNDER THE ROOT (`4-3c/R3`), not under `Mesh`; four-clip
  `AnimationPlayer` added; the two existing `Hurtbox`/`Hitbox` `Area3D`s and the `Collision` shape
  are UNCHANGED in layer/mask (this story adds no collision geometry and no collision-disable
  behaviour — that moved to `4-3d`).
- `src/actors/minions/` — NEW presentation controller file, a per-unit read-only node on the
  `telegraph_controller.gd`/`3-0a` `animation_controller.gd` pattern, scene-authored in
  `unit_actor.tscn` and DRIVEN (not wired) by the runner per tick — corrected, L7: Deviation 2 (Dev
  Notes) already found there is no spawn-seat wiring call; NEW vertical-alignment integration test
  (`4-3c/R3`).
- `src/main/match_runner.gd` — `_aim_unit_actors` gains the controller push and a liveness gate
  (AC 4, `4-3c/R4`); `_approach_unit_actors` gains velocity-zeroing on its skip paths (`4-3c/R5`).
  `_free_dead_unit_actors` is UNTOUCHED by this story — its collision-disable + linger change moved to
  `4-3d`.
- `src/state/` — UNTOUCHED, byte-identical (Golden Prediction, Non-Goals).

### Project Context Rules

- **F1 — exactly one `_physics_process`, in `match_runner.gd`.** The new controller adds none; it is
  pushed a payload from an existing per-tick call. [Source: docs/project-context.md; CLAUDE.md]
- **HARD RULE — state/visual separation.** The controller reads `UnitBoard.attack_phase_at`/
  `is_alive_at` and the actor's own velocity; it writes nothing to state and never applies damage —
  it selects a clip and nothing else. [Source: docs/project-context.md:69-73]
- **Presentation reads state through a runner-pushed payload, never a state handle, never a mutator
  call.** [Source: docs/project-context.md; 3-0a/R2 precedent]
- **`.tscn`/config edits are textual with the editor closed; the editor is explicitly authorized only
  for asset import and `AnimationPlayer`/library assembly, under the `3-0a`/R3 protocol (git diff /
  `project.godot` hash check after every session).** [Source: CLAUDE.md; 3-0a/R3]
- **Data as Resources — no hardcoded gameplay numbers.** This story authors no new `BalanceConfig`
  field; the untuned idle/walk velocity epsilon is a presentation-only constant on the `3-0a`
  `RUN_SPEED_EPS` precedent, not a balance field. [Source: docs/project-context.md]

### References

- [Source: docs/implementation-artifacts/3-0a-rig-adoption.md — full file: AC1-7, Dev Notes,
  Dev Agent Record (assembly route, mutation proof, R9-R12 Hips-displacement measurement and
  correction, `EditorScenePostImport` substitution R10, run-clip push R2, Mesh-node-survives R1)]
- [Source: docs/implementation-artifacts/4-3b-minion-attack-rhythm.md — AC 1 (attack-rhythm balance
  fields and their line numbers), AC 12/13 (locked attack direction, `_aim_unit_actors`'s existing
  phase read), AC 16 (`UnitBoard` field shape, `AttackPhase` enum), Dev Notes (`_advance_unit_attacks`
  skips dead units), Golden Prediction (the fixture's unit never swings)]
- [Source: decision-log.md Session 2026-08-12 "4-3b close-out", `4-3b/R25` (two smoke points
  unmeasurable — no visual telegraph), `4-3b/R26` (melee retune CUT), `4-3b/R27` (this story's own
  forcing-point ruling, DEBT E owner and slot assigned here), `4-3b/R32` (hit-reaction stays
  unaddressed)]
- [Source: decision-log.md Session 2026-08-13 "melee retune executed, CUT form" — the authored
  0.9/0.2/0.8 rhythm `4-3d`'s strike alignment aligns against]
- [Source: docs/implementation-artifacts/3-0b-feel-and-timing-tuning.md — `Mesh.position.y = -1.0`
  hero grounding fix, `test_vertical_alignment.gd`, the SUITE BLIND SPOT note (Dev Notes/Completion
  Notes, Pass 3b)]
- [Source: src/actors/minions/unit_actor.gd — `aim_at`, `aim_along`, `approach`, the root-is-the-
  yaw-sink comment]
- [Source: src/actors/minions/unit_actor.tscn — the grey-box `Mesh` node's `+0.6` transform,
  `Collision`/`Hurtbox`/`Hitbox` layer/mask convention and their matching `+0.6` offsets]
- [Source: src/main/match_runner.gd:682-691 (`_free_dead_unit_actors`, untouched by this story),
  706-734 (`_aim_unit_actors`), 754-782 (`_approach_unit_actors`), 1280-1325 (`_physics_process`
  unit-poll ordering)]
- [Source: src/state/unit_board.gd:101 (`AttackPhase` enum), 220 (`has_index`), 286 (`is_alive_at`)]
- [Source: src/state/match_state.gd:748-775 (`_advance_unit_attacks`, skips dead units, liveness
  guard at line 753)]
- [Source: src/state/resources/balance_config.gd:129, 180, 197, 215, 233-235, 248 (Minions export
  group, the three attack-rhythm durations, reach)]
- [Source: data/balance/balance_config.tres:32-40 (currently authored values, including the
  `4-3b/R26` cut-form retune)]
- [Source: docs/game-architecture.md:627-641 (assets/ Directory Tree, amendment A5 — already
  itemizes the `characters/<name>/` + import-hook + assembly-artifact pattern generically)]
- [Source: docs/project-context.md — F1, HARD RULE state/visual separation, Data as Resources]

## Golden Prediction

**Predicted UNMOVED, measured in BOTH directions at the dev pass.** This story is presentation only:
it touches no file under `src/state/`, adds no `BalanceConfig`/`BalanceTicks` field, and writes no
`MatchState`/`UnitBoard`/`PlayerState` snapshot field. `test/state/test_determinism.gd` runs
`MatchState` in isolation with no runner, no physics, and no actor of any kind (the same structural
fact `4-3b`'s own Golden Prediction measured), so nothing this story ships is even reachable from that
fixture. Suite baseline to hold (measured at this story's authoring pass, 2026-08-14, via the
untouched tree): golden `4a089063a8b3eff2274c0ca300dafe80e4eb4d3970ada352ca432a7e39844bdf`, snapshot
key set eighteen, suite 497 state tests / 3878 assertions / 0 failed. **Integration baseline
CORRECTED at this fix pass (`4-3c/R7`): 31/31 integration files PASS, not 30/30** — measured directly
against the current `test/integration/` directory (`4-3b` added two integration files,
`test_probe_counter_reset_live.gd` and `test_unit_attack_live.gd`, but its own close-out recorded
only 30; the true count carried forward is 31. Any deviation is named separately, not silently
absorbed.

**`project.godot` byte-identity is ALSO measured in both directions, per the corrected precondition
finding in Dev Notes** — this story's own authoring pass already caught the editor deleting the
`physics_ticks_per_second` pin once; the dev pass hashes the file before and after every editor
session, not only at the story's bookends.

**The file that legitimately changes is `src/actors/minions/unit_actor.tscn`** (model parented in,
`AnimationPlayer` added), on the identical shape `4-3b` used when it named `unit_actor.tscn` as its
own one legitimately-changing scene file while `project.godot` and `hero.tscn` stayed byte-identical.
`hero.tscn` is not touched by this story at all and is not expected to move either — recorded so the
dev pass measures it rather than assuming "presentation story" implies every actor scene is fair game.
If the editor's class-cache scan registers a new `class_name` for the presentation controller (the
`3-0a`/`4-3b` precedent for a brand-new `class_name` script), that is named collateral, not a
violation, on the `4-3b` Debug Log precedent ("The new `class_name UnitSwingDedupe` required
registering the global class cache in THIS pass").

## Live Smoke

**REQUIRED**, Tier A default (this story touches presentation for a live-killable actor class and is
the direct successor to `4-3b`'s `R-D6`-spending pass). No `.tscn` flip needed — the shipped default
(`slot_controller_kinds = [0, 1]`) already gives two live human slots.

Script, scoped to what the operator can actually judge with his own eyes (this is the whole reason the
story exists — `4-3b/R25` named exactly these points as unmeasurable on the grey box):

- The minion reads as the creature, not a box, and it **stands and breathes** when idle.
- It **walks rather than skates** while approaching. **Named watch item**: `walk`, not `run`, was
  chosen because the minion moves slowly (AC 4/Dev Notes) — confirm this reads correctly rather than
  looking like the legs are cycling too fast or too slow for the actual ground speed.
- The **windup is VISIBLE**, and the operator can see the swing coming in time to step aside — this is
  the point `4-3b/R25` recorded as unmeasurable before this story; it is the primary thing this story
  exists to make measurable. **Whether the visible strike lands exactly when the damage lands is
  `4-3d`'s question, not this one** — this story only ships the clip playing across the full
  windup/active/recovery cycle, not the frame-accurate alignment.
- **The mid-clip forward step during the attack**: does the claw visibly land somewhere the damage
  does not? **Name this precedent explicitly**: this is the same class of finding as `3-0a`'s roll-
  telegraph finding (the hero's roll ring reading as beside the hero once a real mesh replaced the
  box and made a pre-existing Hips excursion visible, `3-0a` Live Smoke Results, finding 1) — a
  displacement that was always there but only becomes legible once a real body replaces the
  placeholder. If found, it is recorded the same way: not a regression this story introduced, a
  pre-existing measurement made visible. **This finding, if any, feeds `4-3d`'s alignment work.**
- **Deferred, watched but not ruled on here**: whether the minion should be visually scaled down
  (Non-Goals) — the operator's own call, taken live if he wants to make it, recorded as a follow-up
  item either way.

The operator writes the `docs/playtest-log.md` entry by hand, BEFORE the commit chain — no agent
writes it on the operator's behalf.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 — authoring pass, 2026-08-14.
Claude Opus 5 (1M context) — dev pass, 2026-08-14.

### Debug Log References

- **Full suite, EXACTLY TWICE**, both under the tightened harness (`test/run_all.sh`, which fails on
  any `^ERROR:`/`SCRIPT ERROR`/`Parse Error`/`INVARIANT VIOLATED` line):
  - BEFORE any change: `497 tests, 0 failed, 3878 assertions` + `31/31` integration files PASS →
    `ALL TESTS PASSED`. Matches this story's stated baseline exactly, including the `4-3c/R7`-corrected
    integration count of 31 (counted directly: 31 `test_*.gd` files in `test/integration/`).
  - AFTER: `497 tests, 0 failed, 3878 assertions` + `34/34` integration files PASS →
    `ALL TESTS PASSED`. The state harness is UNMOVED in all three figures; integration grows by
    exactly the three files this story adds.
- **Three editor sessions, `project.godot` hashed BEFORE AND AFTER EACH ONE** (not only at the
  bookends), per this story's own corrected precondition obligation. Hash constant at
  `8879de490edda78051595f189fb9bb6f2e75384febaff142c8958ec107970004` at all six measurements; the
  `common/physics_ticks_per_second=60` pin and the `config/features` ordering survived every session,
  and `project.godot` never once appeared in `git status`. **NO collateral this pass — the seventh
  exposure did not become the seventh incident.**
  1. Reimport of `skeletonzombie.fbx` after installing the `EditorScenePostImport` hook. Before
     `8879de49…` / after `8879de49…`. (`Running Custom Script...` in the import log is the hook firing.)
  2. Class-cache scan registering the new `class_name UnitAnimationController` — the named collateral
     the Golden Prediction section predicted. Before `8879de49…` / after `8879de49…`. Needed: without
     it, `unit_actor.gd:81` fails to parse (`Could not find type "UnitAnimationController"`), measured.
  3. (No third session was required. The library assembly, which `3-0a` did in the editor, was done
     headlessly instead — see Completion Notes, deviation 1. Two sessions, six hash measurements.)
- **Golden measured in BOTH directions: UNMOVED at
  `4a089063a8b3eff2274c0ca300dafe80e4eb4d3970ada352ca432a7e39844bdf`.** The measurement is the state
  suite itself — `test_determinism.gd` recomputes the hash and compares it to the `GOLDEN` constant,
  so a PASS in both runs IS the both-directions measurement. The constant was never edited (still
  `test_determinism.gd:458`) and the snapshot key set stays at eighteen. As predicted: `src/state/`
  is byte-identical this pass (it does not appear in `git status`).
- **Asset probe (headless, no editor).** A throwaway `SceneTree` script measured the four clips'
  `mixamorig_Hips` position tracks and the model's merged mesh AABB, on the same method `3-0a` used
  against `paladin_anims.res`. Deleted at the end of the pass rather than committed, matching `3-0a`
  (a measurement instrument, not a guard; the guards this story does ship are committed tests). The
  measured tables it produced are transcribed in full below.

### Completion Notes List

#### Measured Hips displacement, ALL FOUR CLIPS (AC 1)

`mixamorig_Hips` position track, read off each imported clip FBX. `NET` is last key minus first key;
`planar excursion` is the mid-clip XZ swing (the legibility figure `3-0a`'s own table recorded, and
the one that turned out to matter at the hero's smoke).

| clip | length | keys | NET (x, y, z) | net planar | mid-clip planar excursion | expectation |
|---|---|---|---|---|---|---|
| `idle` | 4.0333 s | 39 | (0.0000, -0.0000, 0.0000) | 0.0000 | 0.0319 | net-zero — **MET** |
| `walk` | 1.4333 s | 44 | (0.0001, 0.0000, 0.0000) | 0.0001 | 0.1567 | net-zero — **MET** |
| `attack` | 2.6667 s | 80 | (-0.0000, 0.0000, -0.0000) | 0.0000 | **1.1722** | mid-clip forward step RETURNING to net-zero — **MET** |
| `death` | 4.6000 s | 81 | (-0.0562, -0.7959, -1.0988) | 1.1003 | 1.1392 | net topple that HOLDS — **MET** |

- Every one of the four matched its stated expectation, so no clip needed the accepted/rejected
  judgment AC 1 held in reserve for an `attack` that failed to return.
- **`attack`'s mid-clip excursion is 1.1722 planar and it is recorded, not judged here.** This is the
  same class of figure as the hero `roll` clip's ~1.09 (`3-0a` Dev Notes) which read at smoke as the
  hero standing beside his own telegraph ring — a displacement that was always there and only became
  legible once a real body replaced the box. Peak forward reach is z +0.8357. This story's Live Smoke
  already names watching for it; **if the operator sees the claw land where the damage does not, that
  finding feeds `4-3d`, and it is a pre-existing measurement made visible, not a regression this story
  introduced.**
- **`death`'s topple is MEASURED AND RECORDED ONLY. This story accepts nothing** (`4-3c/R10`) —
  acceptance and its reasoning belong to `4-3d` AC 5 (`4-3d/R3`), which has its own, differently-argued
  basis (liveness-gated driving, not the hero's round-over freeze). Recorded for it: the topple is
  -1.0988 on Z, -0.0562 on X, -0.7959 on Y, and it HOLDS to the last key.
- **Clip lengths are recorded as measured collateral, deliberately WITHOUT drawing `4-3d`'s
  conclusion.** `attack` is 2.6667 s against an authored 1.9 s full cycle (0.9 + 0.2 + 0.8). `4-3d`
  AC 1 requires this measurement as its own first step and explicitly forbids assuming the
  ~2.7 s figure that had circulated (`4-3d/R8`); it is now measured rather than estimated, and which
  alignment mechanism follows from it remains `4-3d`'s open question for the operator. **No alignment
  work was done here.**
  **Annotation (append), 2026-08-26, fifth `4-3d` fix pass.** The clause above is untouched and stands
  as the record of what this pass knew on 2026-08-15. It has since been superseded: the operator
  DECIDED the alignment mechanism (custom `AnimationPlayer` playback rate), `4-3d/R11`,
  decision-log Session 2026-08-26 — see `4-3d-minion-strike-alignment-and-corpse-lifecycle.md` AC 1.

#### Measured asset inventory (AC 1)

Ten source assets, `stat`-measured, `.import` sidecars excluded — **36,707,750 bytes = 35.0072 MiB**,
confirming the `4-3c/R7`-corrected ~35 MB figure to the byte (the pre-correction ~34 MB estimate would
have been wrong). Committed directly to git, no LFS, on the standing `3-0a` ruling.

| file | bytes | file | bytes |
|---|---|---|---|
| `skeletonzombie.fbx` | 17,508,416 | `skeletonzombie_0.png` | 4,407,327 |
| `idle.fbx` | 710,736 | `skeletonzombie_1.png` | 5,103,379 |
| `walk.fbx` | 443,008 | `skeletonzombie_2.png` | 26,952 |
| `attack.fbx` | 564,688 | `skeletonzombie_3.png` | 4,022,541 |
| `death.fbx` | 727,104 | `skeletonzombie_4.png` | 3,193,599 |

Import cleanliness verified against all five `.fbx.import` files: `nodes/root_scale=1.0`,
`nodes/apply_root_scale=true`, no `BoneMap`, no retarget, no hand-edited scale anywhere. The four clip
imports are byte-for-byte the same parameter set the paladin's clips use. Only the MODEL's `.import`
differs, by exactly the two lines AC 3 requires: `animation/import=false` and the
`import_script/path` hook. Source and licence: Mixamo, commercial use permitted.

#### The `Mesh`-node dependency search, re-measured at dev (AC 2)

Zero hits, confirming the authoring pass. Every `$Mesh` / `get_node("Mesh")` / `MeshInstance3D`
binding in `src/` and `test/` is hero-scoped: `hero.gd:18` (`$Mesh`, the hero's own yaw sink),
`test_visible_facing.gd:31` (`_p1` is a `HeroActor`), `test_vertical_alignment.gd:73` and
`test_chain_retrigger.gd:60` (both `Mesh/Paladin…`), and `telegraph_controller.gd`'s own shape nodes.
**Nothing anywhere named the minion's `Mesh` node.**

#### Micro-decision recorded: `Mesh` DELETED, not kept as an emptied parent (AC 2)

AC 2 leaves this to the dev pass. `Mesh` is deleted outright and the skinned model parents straight
under `UnitActor` as `SkeletonZombie`, with **no transform of its own**. Reasoning: nothing references
the node (measured above), its `+0.6` would have to be zeroed anyway, and an emptied `MeshInstance3D`
kept as a pass-through parent would be a misleadingly-typed node retained for nothing. The
`BoxMesh_unitbox` and `StandardMaterial3D_unitgrey` sub-resources go with it.

Measured result: model merged mesh AABB is y `[-0.0162, 2.0456]` in root space; the body box floor is
y `0.0000`; `main.tscn`'s ground top is `0.0000`; the runner spawns units at world y `0.0000`. The
model stands ON the floor. **The `-0.0162` is the imported mesh's own bind-pose AABB dipping 1.6 cm
below its origin** — which is why the minion's alignment test cannot use the hero test's `EXACT_EPS`
of 0.001 and uses a derived `MODEL_FEET_AGREEMENT` of 0.05 instead (~3x headroom over the measured
slop, still rejecting the 0.6 double-offset defect by more than an order of magnitude). That
difference is stated in the test file itself rather than left as an unexplained looser number.

Note for the Live Smoke, not a defect: the model is **2.06 units tall against a 1.2-tall body box**.
This story does not scale it (Non-Goals — one decision about three numbers, owner Matko, taken live).

#### THE FINAL LINE ORDER OF THE AIM LOOP BODY (AC 4) — recorded explicitly, as required

`MatchRunner._aim_unit_actors`, code lines only (comments elided), in file order:

```
func _aim_unit_actors(slot: int, player: PlayerState) -> void:
    var actors: Array = _unit_actors[slot]
    for index: int in actors.size():
        if not player.units.has_index(index):            # 1. board-index guard (pre-existing)
            continue
        var unit: Node = actors[index]                   # 2. the node comes into existence HERE
        if not is_instance_valid(unit):                  # 3. instance-validity guard (pre-existing)
            continue
        (unit as UnitActor).animation.on_unit_tick(      # 4. >>> THE PUSH — FIRST, UNCONDITIONAL <<<
                player.units.is_alive_at(index),
                player.units.attack_phase_at(index),
                (unit as UnitActor).velocity.length())
        if not player.units.is_alive_at(index):          # 5. >>> THE LIVENESS GATE — AFTER <<<
            continue
        if player.units.attack_phase_at(index) != UnitBoard.AttackPhase.IDLE:   # 6. (pre-existing)
            (unit as UnitActor).aim_along(player.units.attack_dir_at(index))
            continue
        var target_slot := player.units.target_slot_at(index)
        if target_slot == TargetingService.NO_TARGET_SLOT:
            continue
        var target_index := player.units.target_index_at(index)
        var target_position: Variant = _target_world_position(target_slot, target_index)
        if target_position is Vector3:
            (unit as UnitActor).aim_at(target_position)
```

The push is at `match_runner.gd:740-741`; the liveness gate at `:753-754`; the phase read at `:766`.

- **The push is NOT hoisted above the point where a node exists, and that is not a weakening of
  `4-3c/R15`.** Guards 1 and 3 structurally precede it — `has_index` bounds the board read and
  `is_instance_valid` is what makes `unit` a node at all — and there is no controller to push to until
  both have passed. AC 4's own wording is the exact one and it is satisfied verbatim: the push happens
  *"for every actor index the loop REACHES"*. The TASK line's *"unconditionally first in the loop
  body"*, read literally, would place the push above the line that defines `unit` and is
  unimplementable; that is recorded here rather than silently reconciled.
- **The liveness check was NOT folded into the push, and the push was NOT folded into a combined
  condition.** They are two separate statements in the order above. The gate governs the AIM decision
  only; it never governs whether the push happens.
- **A dead unit is left at its last-aimed heading**, on `aim_at`/`aim_along`'s own established
  no-usable-direction answer.

#### The runner-side ordering IS pinned by a test — and here is exactly what that test can and cannot see

**This was the story's most dangerous blind spot and it is closed rather than papered over.** The
clip-selection test's Part A proves liveness-before-phase INSIDE the controller and is
**structurally blind to the runner-side ordering**: in `4-3c` a dead unit's actor is freed by
`_free_dead_unit_actors` earlier in the same frame, so `_aim_unit_actors` never reaches a dead index,
and a push wrongly seated behind an early liveness skip **would pass every behavioural test this
story can write** — surfacing only in `4-3d` as a corpse frozen mid-swing.

So the ordering is pinned the only way it can be pinned today: **Part B of
`test/integration/test_unit_clip_selection.gd` is a SOURCE-ORDER assertion.** It isolates
`_aim_unit_actors`' own body, finds the `on_unit_tick(` push line and the
`if not …is_alive_at(index)` gate line, and asserts push-line < gate-line; it also fails if either is
absent entirely. This is not a novel liberty in this repo — `test/state/test_architecture_invariants.gd`
already enforces F1 and D3(a)/D3(b) by scanning `src/` source text, for the identical reason (the
property is structural and no runtime state exhibits it). **It is cheap, it is real, and it was proven
by mutation** (mutation 4 below). When `4-3d` ships the corpse linger, a behavioural test becomes
possible and this becomes belt-and-braces; until then it is the sole guard, and the test file says so
in its own header.

#### MUTATION TABLE — every new guard proven to fall

Protocol on every row: the target was copied **outside the repo** and SHA256-recorded BEFORE mutating;
restored by **copying the backup back**, never `git checkout --`; the SHA256 was **re-verified equal**
to the pre-mutation record and the test re-run GREEN. All ten restores verified byte-identical.

| # | Guard | Mutation applied | Result | Restore verified |
|---|---|---|---|---|
| 1a | `test_unit_rig_clips.gd` (AC 3) | `death` clip removed from `skeletonzombie_anims.res` | **RED, exit 1** — two failures at once: `expected exactly 4 clips, found 3` and `missing expected clip 'death'` | SHA `1943a43a…` re-verified, GREEN exit 0 |
| 1b | `test_unit_rig_clips.gd` (AC 3) | a `mixamo_com` clip re-added to the library | **RED, exit 1** — `forbidden clip present: 'mixamo_com' (model take leaked in)` + `expected exactly 4 clips, found 5` | SHA `1943a43a…` re-verified, GREEN exit 0 |
| 2 | `test_unit_vertical_alignment.gd` (AC 2, `4-3c/R11`) | the old `Mesh` `+0.6` restored onto the model's own parent — the exact named mutation | **RED, exit 1** — model's lowest vertex 0.5838 vs box floor 0.0000, and world feet 0.5838 vs ground 0.0000 | SHA `d2a5b1e9…` re-verified, GREEN exit 0 |
| 3 | `test_unit_clip_selection.gd` Part A (AC 4, `4-3c/R6`) | liveness check swapped BELOW the phase check in the controller — the exact named mutation | **RED, exit 1** — all three killed-mid-swing cases: `expected clip 'death', got 'attack'` | SHA `fe63c0aa…` re-verified, GREEN exit 0 |
| 4 | `test_unit_clip_selection.gd` Part B (AC 4, `4-3c/R15`) | the controller push moved BEHIND the aim loop's liveness gate | **RED, exit 1** — `ORDERING VIOLATION (4-3c/R15): the controller push is at line 753, BEHIND the liveness gate at line 751` | SHA `e9d57b53…` re-verified, GREEN exit 0 |
| 5 | `test_unit_model_facing.gd` (post-smoke fix pass, a TRANSFORM guard — M5) | `SkeletonZombie`'s compensating PI-yaw `transform` removed | **RED, exit 1**, both directions, dot -1.0000 | SHA `bc62101c…` re-verified, GREEN exit 0 |
| 6 | `test_unit_attack_retrigger.gd` (defect B1 fix pass) — provenance **MEASURED** | the re-trigger condition reverted to plain `phase != IDLE` (`force`/`_prev_phase` edge dropped) — the exact named mutation | **RED, exit 1** — `DEFECT B1: swing #2 did not re-trigger the attack clip. Playback ran on from 1.0000 to 1.0000 across a RECOVERY->WINDUP transition with no IDLE between`; `test_unit_clip_selection.gd` stayed **GREEN** under the same mutation, which is why a second file exists | SHA `28403f6c…` re-verified, GREEN exit 0 |
| 7 | `test_unit_clip_selection.gd` Part B indentation check (H2 fix pass) — provenance **MEASURED** | `match_runner.gd`'s push WRAPPED in `if player.units.is_alive_at(index):` — text order unchanged (push_line still < gate_line), only indentation moved — the exact reviewer-named mutation | **RED, exit 1** — `ORDERING VIOLATION (4-3c/R15): the controller push at line 741 is indented past the loop body's base indentation (push at 4, base 2) - it has been WRAPPED inside a conditional` | SHA `e9d57b53…` re-verified, GREEN exit 0 |
| 8 | `test_unit_vertical_alignment.gd`'s parsed `SPAWN_GROUND_Y` (M3 fix pass) — provenance **MEASURED** | `match_runner.gd`'s spawn literal `0.0` changed to `0.3` — the drift the old hardcoded constant was blind to | **RED, exit 1** — `the runner spawns units at world y 0.3000 but main.tscn's ground top is 0.0000 - delta 0.3000` + feet-vs-ground failure | SHA `e9d57b53…` re-verified, GREEN exit 0 |
| 9 | `test_unit_clip_selection.gd`'s content-change check (M4 fix pass) — provenance **MEASURED** | every track removed from the `idle` clip in `skeletonzombie_anims.res` (empty-content clip) — passes all six AC 3 guards | **RED, exit 1** — `content check: clip 'idle' - mixamorig_Hips pose did not change after advancing 2.0167s` | SHA `1943a43a…` re-verified, GREEN exit 0 |

#### POST-SMOKE FIX PASS (2026-08-14): backwards model mount
Hero precedent (`hero.tscn`/`hero.gd:40`): no copyable correction exists — `hero.gd`'s yaw
(`atan2(x,y)`, no `+PI`) already matches the Mixamo model's native +Z front. `unit_actor.gd`'s
`aim_at`/`aim_along` add a `+PI` the hero lacks, so `SkeletonZombie` alone gets a yaw-only, zero-origin
`transform = Transform3D(-1,0,0, 0,1,0, 0,0,-1, 0,0,0)`. New guard `test_unit_model_facing.gd` asserts
model world-forward against aim direction directly, which `test_visible_facing.gd`'s yaw-vs-yaw pin
cannot catch. Defect B measured, left INCONCLUSIVE: the one-tick lag is RETRACTED as the cause — one
stale read (`match_runner.gd:741` before `:795`-`855`) is a single-frame flicker, not the sustained
slide observed. `match_runner.gd:839`/`:855` and `unit_actor.gd:147-149` zero velocity and skip
`move_and_slide()` together, and no push/platform code exists anywhere in `src/`; whether
`move_and_slide()` can passively displace a second, zero-velocity `CharacterBody3D` cannot be settled
by source trace alone — B needs live instrumentation, not fixed here.

#### Red-green, reported honestly

**None of the three new tests was written before the thing it guards, and none of them went red on
first run.** The assets, the assembled library, the scene re-parenting and the controller all had to
exist before a test against them could say anything at all — a test asserting four clips in a library
that does not yet exist fails on "did not load", which is not a meaningful red. So all three passed
**first time**, and **the mutation table above is their only red**. That is the honest report; it is
also exactly the shape `3-0a` recorded for its own AC 3 guard.

Two genuine reds did occur during the pass, both real defects caught by the tests and fixed:
1. `Could not find type "UnitAnimationController"` — the new `class_name` needed the class-cache scan
   (editor session 2). Named collateral, predicted by the story's own Golden Prediction section.
2. `unit_actor.tscn did not yield a wired AnimationController` — measured cause: **a node added to the
   tree from inside a `SceneTree._initialize()` does NOT get `_ready()` called there**
   (`is_node_ready()` was still false immediately after `add_child`), so the controller's exported
   AnimationPlayer path was unresolved. Fixed by deferring Part A to `_process`, the same shape the
   `*_live.gd` tests already use; the cause is written into the test file so it is not rediscovered.

#### Deviations from the skill's steps and from this prompt's defaults

1. **The `AnimationLibrary` was assembled HEADLESSLY, not in the editor.** The task line says "via the
   editor under the `3-0a`/R3 protocol". `3-0a`/R3 **authorizes** the editor for assembly; it does not
   mandate it. Every editor session is a measured hazard here (six recorded collateral incidents), so
   the assembly that could avoid one did. It is done by `tools/build_zombie_anims.gd`, a committed,
   re-runnable tool in `tools/retime_clips.gd`'s shape — which also makes the artifact reproducible
   from its four source FBXs, unlike `paladin_anims.res`, which nobody can rebuild without repeating a
   manual GUI session. The reimport that installs the hook still needed the editor and used it.
2. **No spawn-seat wiring call was added to `_spawn_missing_unit_actors`.** The Project Structure Notes
   describe the runner as wiring the controller at that seat. There is nothing to wire: the controller
   is scene-authored in `unit_actor.tscn` with its AnimationPlayer path exported (the hero's own
   `AnimationController` precedent), so `$AnimationController` is correct the moment the scene
   instantiates. `UnitActor` exposes it exactly as it already exposes `$Hitbox`, and the runner DRIVES
   it per tick from `_aim_unit_actors` — which is the substance of the requirement. Adding a
   spawn-seat call that did nothing would have been a no-op seat for a future reader to puzzle over.
3. **The skill's red-green-refactor step (step 5) could not be honoured in its literal order** for the
   asset/scene/library work, for the reason given under "Red-green, reported honestly" above. Reported
   rather than faked.
4. **The skill's step 9 writes a board status of `review`;** the team override in
   `_bmad/custom/gds-dev-story.toml` corrects it back to `ready-for-dev` (CFG/R2). That override ran
   as designed and is not a deviation — recorded because the prompt asked for it to be let run.
5. **No commits were made and nothing was staged**, per the prompt. The chain pass owns every commit.
   `docs/playtest-log.md` was not read, edited, staged or reverted.

#### Byte-identity and blast radius, measured

- **`project.godot`: byte-identical both directions**, `8879de49…`, across six measurements spanning
  two editor sessions. Never appeared in `git status`.
- **`src/state/`: byte-identical.** Does not appear in `git status` at all — the Non-Goal held.
- **`hero.tscn`: untouched**, as the Golden Prediction section asked to be measured rather than
  assumed. Does not appear in `git status`.
- **The one scene that legitimately changes is `src/actors/minions/unit_actor.tscn`**, exactly as
  predicted.
- **`.gitattributes`: not opened** (`4-3c/R8`), as the task line already resolved.
- **Orphaned `godot` processes: NONE at the start of the pass, NONE at the end** (`4-3b/R31`); every
  subprocess this pass launched ran to completion under an explicit timeout and none was abandoned.

#### DEFECT B1 FIX PASS (2026-08-15): "frozen in idle while attacking"

**Root cause, measured.** The live phase cycle runs WINDUP 54 ticks (0.9s) -> ACTIVE 12 (0.2s) ->
RECOVERY 48 (0.8s) -> WINDUP with **zero IDLE ticks between chained swings** — seven swings were one
unbroken 743-tick non-IDLE stretch. The controller selected on the LEVEL `phase != IDLE`, so `_select`
fired ONCE for all seven and its dedup (`unit_animation_controller.gd:101-102`) blocked every
re-trigger; the clip ran to completion and then HELD its final near-neutral pose for ~9.7s while real
swings and real damage continued underneath. **Fix shape:** the controller now remembers the previous
tick's phase (`_prev_phase`, same shape as the existing `_selected` memory) and re-triggers on the
**EDGE into WINDUP** — from IDLE *or* from RECOVERY. No signature change, no pushed `attack_count_at`,
no `src/state/`, no `match_runner.gd`, ordering untouched. **New guard:**
`test/integration/test_unit_attack_retrigger.gd` drives two consecutive swings across a
RECOVERY->WINDUP transition with no IDLE between and asserts on **playback position restarting**, not
on the clip name (the name is `attack` on both sides and never changes — which is exactly why the
existing `test_unit_clip_selection.gd` is GREEN through the whole defect). Mutation row 6 above.

**CONSEQUENCE, stated plainly and NOT fixed here.** The swing cycle is 1.9s and the attack clip is
2.6667s, so each chained swing now **truncates the final ~0.767s (28.7%) of the clip**. That is
**expected**, it is strictly better than the held-pose defect it replaces, and aligning the visible
strike to the authored ACTIVE window is owned by **`4-3d` AC 1** (`4-3c/R2`) — deliberately not
addressed in this pass.

### File List

**Added**
- `assets/characters/skeletonzombie/skeletonzombie.fbx` (+ `.import`) — skinned, textured model
- `assets/characters/skeletonzombie/idle.fbx`, `walk.fbx`, `attack.fbx`, `death.fbx` (+ `.import` each)
- `assets/characters/skeletonzombie/skeletonzombie_0.png` … `_4.png` (+ `.import` each) — importer-extracted
- `assets/characters/skeletonzombie/strip_model_anim.gd` (+ `.uid`) — the `EditorScenePostImport` hook (`3-0a`/R10 route)
- `assets/characters/skeletonzombie/skeletonzombie_anims.res` — the assembled four-clip `AnimationLibrary`
- `src/actors/minions/unit_animation_controller.gd` (+ `.uid`) — the presentation controller (`class_name UnitAnimationController`); amended by the defect B1 fix pass (`_prev_phase` WINDUP edge, `_select(clip, force)`)
- `tools/build_zombie_anims.gd` (+ `.uid`) — headless, re-runnable library assembly
- `test/integration/test_unit_rig_clips.gd` (+ `.uid`) — AC 3 guard
- `test/integration/test_unit_vertical_alignment.gd` (+ `.uid`) — AC 2 guard
- `test/integration/test_unit_clip_selection.gd` (+ `.uid`) — AC 4 guard (Part A selection, Part B source-order)
- `test/integration/test_unit_model_facing.gd` — post-smoke fix pass guard: a TRANSFORM guard (per its own header) pinning `SkeletonZombie`'s compensating yaw against aim direction, not a general facing guard (M5)
- `test/integration/test_unit_attack_retrigger.gd` — defect B1 fix pass guard, chained-swing clip re-trigger (playback restart, not clip name)

**Modified**
- `src/actors/minions/unit_actor.tscn` — box geometry + `Mesh` node deleted; `SkeletonZombie` model parented under the ROOT; `AnimationPlayer` + `AnimationController` added
- `src/actors/minions/unit_actor.gd` — exposes `$AnimationController` as `animation`, beside the existing `$Hitbox`
- `src/main/match_runner.gd` — `_aim_unit_actors` gains the controller push (first) and the liveness gate (after); `_approach_unit_actors` zeroes actor velocity on its two named skip paths
- `docs/implementation-artifacts/4-3c-minion-rig-adoption.md` — Status, task checkboxes, Dev Agent Record, File List, Change Log
- `docs/implementation-artifacts/sprint-status.yaml` — promotion to `ready-for-dev`, then the CFG/R2 board write-back

**Unchanged and measured so** — `project.godot`, `src/state/**`, `src/actors/hero/hero.tscn`,
`.gitattributes`, `test/state/test_determinism.gd`.

## Change Log

| Date | Author | Change |
|---|---|---|
| 2026-08-14 | Claude Sonnet 5 | Story authored. Presentation-only rig adoption for the minion, the `3-0a` counterpart for the hero, six ACs against the grey box `4-3`/`4-3a`/`4-3b` shipped. Golden and `project.godot` predicted unmoved, to be measured at the dev pass. |
| 2026-08-14 | Claude Sonnet 5 | READINESS GATE FIX PASS (`4-3c/R1`-`R9`, decision-log Session 2026-08-14, "4-3c readiness gate, fix pass"). `4-3c/R1`: the rig story's slot/owner assignment, previously only DEFERRED by `4-3b/R27` and never made, is assigned here by the operator — a new decision, superseding the deferral. `4-3c/R2`: AC 5 (strike alignment) and AC 6 (corpse lifecycle) CUT to a new story, `4-3d-minion-strike-alignment-and-corpse-lifecycle`, on the gate's own recommendation: both are the kind of feel/timing and actor-lifetime work `3-0a` itself deferred into `3-0b`, not adoption. `4-3c/R3`: AC 2 corrected — the model parents DIRECTLY UNDER THE ROOT, not under `Mesh`, because `Mesh` carries a measured `+0.6` upward transform that would double-offset a feet-origin model and hover it, the mirror image of the hero's own pre-`3-0b` floating defect; AC 2 gains a mutation-proven minion vertical-alignment test, the `3-0b`/`test_vertical_alignment.gd` counterpart. `4-3c/R4`: AC 4 gains a liveness gate on `_aim_unit_actors` it had none of before, needed regardless of `4-3d`'s corpse linger and depended on by it. `4-3c/R5`: AC 4's idle/walk velocity signal corrected — `_approach_unit_actors`'s skip paths now zero the actor's own velocity so a lost target does not leave a stale nonzero value driving the walk clip forever. `4-3c/R6`: AC 4 gains a mutation-proven clip-selection test with the liveness-below-phase swap named as the falling mutation. `4-3c/R7`: three measured figures corrected — integration baseline 30 -> 31 files, asset total ~34 MB -> ~35 MB (measured, `du -sb`), and a Dev Notes line citation off by two (753, not 755). `4-3c/R8`: `.gitattributes` task marked RESOLVED, not opened at dev — existing bare extension wildcards already cover the new asset directory. `4-3c/R9`: this Change Log section added. No code touched — docs only. |
| 2026-08-14 | Claude Sonnet 5 | POST-SMOKE FIX PASS: fixed the backwards-mounted minion model (`SkeletonZombie` compensating PI yaw, new mutation-proven `test_unit_model_facing.gd`) and measured defect B (sliding instead of walking), left INCONCLUSIVE — see Dev Agent Record. |
| 2026-08-14 | Claude Sonnet 5 | SECOND READINESS GATE FIX PASS (`4-3c/R10`-`R17`, decision-log Session 2026-08-14, "4-3c/4-3d second readiness gate, fix pass"). Operator's ruling (`4-3c/R15`): AC 4's controller push and its liveness gate are ORDERED — push happens FIRST, unconditionally, then the liveness check that gates the aim decision; a liveness check placed ahead of the push would silently skip the push too, which `4-3d`'s lingering corpse would expose as a corpse frozen mid-swing. `4-3c/R10`: AC 1's death-topple acceptance clause struck (this AC measures and records only; acceptance is `4-3d`'s, per `4-3d/R3`) along with its dangling `AC 6 (below)` pointer and its two stale citations (one superseded, one about a different clip). `4-3c/R12`: AC 4's velocity-zeroing path list rewritten against the measured code — exactly two paths qualify (`match_runner.gd:776-777`, `:780`); the `balance == null` early return and the pre-node `has_index`/`is_alive_at` continues do not. `4-3c/R13`: AC 2's cross-check re-specified against the runner's own spawn constant (`match_runner.gd:650-657`, ground Y = 0.0) — minions have no spawn scene node. `4-3c/R11`: the vertical-alignment test gets a named mutation (re-parent under `Mesh`, or restore `Mesh`'s offset onto the model's parent, must go red). `4-3c/R14`: the unmeasurable corpse item removed from Live Smoke, not replaced. `4-3c/R16`/`R17`: stale `AC 6 (below)` pointer and a new Dev Note (the push seat reads the previous tick's velocity, harmless for idle/walk) recorded, non-blocking. No code touched — docs only. |
| 2026-08-14 | Claude Opus 5 (1M context) | DEV PASS. Story promoted `authored` -> `ready-for-dev` (third readiness gate READY, zero blocking findings), then implemented. All four ACs satisfied; no AC amended and none found unimplementable. Assets committed (36,707,750 bytes measured, confirming the `4-3c/R7` ~35 MB correction to the byte); all four clips' Hips displacement MEASURED and tabulated, every one matching its stated expectation (`idle`/`walk` net-zero, `attack` net-zero with a 1.1722 mid-clip planar excursion recorded as a Live Smoke watch item on the `3-0a` roll-ring precedent, `death`'s topple measured and recorded ONLY -- acceptance left to `4-3d` per `4-3c/R10`). Model parented DIRECTLY UNDER THE ROOT with `Mesh` deleted outright (micro-decision recorded); four clips assembled into one `AnimationLibrary`; the model's bundled `mixamo_com` stripped via the `3-0a`/R10 `EditorScenePostImport` route, the broken `animation/import=false` route not re-attempted. `_aim_unit_actors` now pushes phase/liveness/velocity to the new controller FIRST and gates the AIM decision on liveness AFTER (`4-3c/R15`), with the final line order recorded explicitly in Completion Notes; `_approach_unit_actors` zeroes actor velocity at exactly the two `4-3c/R12` paths. Three new guards, all four named mutations proven to fall (backup-outside-repo + SHA256, restore by copy-back, never `git checkout`). The runner-side ordering -- which NO behavioural test in this story can see, and which would surface only in `4-3d` -- is pinned by a SOURCE-ORDER assertion on the `test_architecture_invariants.gd` precedent, itself mutation-proven. Suite 497/3878/0 UNMOVED, integration 31 -> 34 all PASS; golden `4a089063...` UNMOVED measured both directions; `project.godot` byte-identical across six hashes spanning two editor sessions, tick pin intact, NO collateral; `src/state/` and `hero.tscn` byte-identical. Deviations recorded in Completion Notes (headless library assembly instead of the editor; no no-op spawn-seat wiring call; red-green order). No commits, nothing staged. |
| 2026-08-15 | Claude Opus 5 (1M context) | DEFECT B1 FIX PASS. Root cause MEASURED: chained swings never pass through IDLE (WINDUP 54 -> ACTIVE 12 -> RECOVERY 48 -> WINDUP, seven swings = one 743-tick non-IDLE stretch), so the controller's level selection `phase != IDLE` fired once for all seven and the `_select` dedup held the finished clip's final pose for ~9.7s. Fixed by remembering the previous tick's phase and re-triggering on the EDGE into WINDUP; `on_unit_tick`'s signature, `src/state/`, `match_runner.gd`, the death-before-phase ordering and `4-3c/R15`'s push-before-liveness ordering all untouched. New guard `test/integration/test_unit_attack_retrigger.gd` asserts playback RESTART across a RECOVERY->WINDUP transition (the clip name never changes, which is why `test_unit_clip_selection.gd` is green through the whole defect -- measured); mutation table row 6, provenance MEASURED. CONSEQUENCE recorded, not fixed here: 1.9s cycle vs 2.6667s clip truncates the last ~0.767s (28.7%) of each chained swing -- expected, better than the held pose it replaces, owned by `4-3d` AC 5. Suite 497/3878/0 UNMOVED, integration 35 -> 36 all PASS, golden `4a089063...` UNMOVED, `project.godot` byte-identical with the 60-tick pin intact. Status stays `review`; no commits, nothing staged. |
| 2026-08-15 | Claude Sonnet 5 | LIVE SMOKE (docs-only). Defect A confirmed fixed and defect B1 confirmed improved, both by eye; remaining swing slide attributed to the unimplemented rooted-during-swing scope (decision-log, this session), not a `4-3c` defect. Open observation (truncation readability) carried to `4-3d`. No code touched. |
| 2026-08-26 | Claude Sonnet 5 | DOCS-ONLY CORRECTION PASS (`4-3d`'s fifth readiness-gate fix pass, scope-overrun correction). Two 2026-08-26 edits this DONE/PUSHED story's record had received from `4-3d`'s fourth fix pass (`:628-629`'s rewrite of the alignment-mechanism sentence, and this Change Log's own `:894` row's `AC 1` wording) exceeded stale-AC-number correction and rewrote what a closed pass said it knew at the time; both REVERTED to original wording. `:628-629` gains an inline appended annotation pointing to `4-3d/R11` (operator decided the alignment mechanism 2026-08-26, eleven days after this story closed) instead of being rewritten. This row is the record of that revert. `:622` ("acceptance and its reasoning belong to `4-3d` AC 5") and `:856` ("aligning the visible strike to the authored ACTIVE window is owned by `4-3d` AC 1" — cited as `:852` when this row was written, before the `:631-634` annotation above shifted this file by +4; re-resolved by content) (bare AC-number corrections only, made the same fourth pass) and `sprint-status.yaml:112` stand as corrected. No behavioural change; status/board unchanged. |

**H1 FIX PASS (2026-08-15):** `death` is UNREACHABLE end-to-end live — `_free_dead_unit_actors` frees
a unit's actor the same tick death is observed (`match_runner.gd:690-691`), before `_aim_unit_actors`
can ever push `alive=false`, so every `death` assertion above is contract-only, not effect; live proof
is owed by `4-3d`'s lingering corpse.

## Live Smoke Results (post-fix-pass check, 2026-08-15)

- Defect A (backwards-mounted model) CONFIRMED FIXED, by eye.
- Defect B1 (held near-neutral pose across chained swings) CONFIRMED IMPROVED, by eye, after the
  re-trigger fix.
- The remaining slide during a swing is NOT a `4-3c` defect — it is the ungated-movement scope
  covered by the decision-log's rooted-during-swing ruling (Session 2026-08-15), unimplemented here.
- **Open observation, carried to `4-3d`**: the readability of the ~0.767s truncation at the end of
  each chained swing has NOT yet been rated by eye.
