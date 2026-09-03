---
baseline_commit: 60b76e7826df6132657f1400d4fae7dfd735b861
---

# Story 5.0c: Totem and projectile models

Status: done

## What this story inherits

`E5-P/R5` (decision-log Session 2026-09-01 "E5 planning",
`docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8183`) ratifies this as the
THIRD of twelve E5 stories, Tier B: "static mesh swap, precondition for nothing." Unlike `5-0a` and
`5-0b`, no story downstream in the board order depends on this one landing first.

**Motivating gap**, measured against the shipped `4-4-totems` story (`done`,
`docs/implementation-artifacts/4-4-totems.md`): every totem kind and the Combat totem's projectile
are grey-box placeholders today, and AC 3's own scene comment says so in as many words —
`src/actors/minions/totem_actor.tscn`'s `Mesh` node docstring: "GREY BOX, and that is the standing
bar rather than a placeholder awaiting art... No material is authored." The three totem kinds
(Combat, Mana Accelerator, Stamina Accelerator) are visually IDENTICAL grey boxes today — nothing
on screen distinguishes which totem is which. The GDD (`gdd.md:188,349,391`) calls for totems to
read as "small wardstone-like models... intentionally unimposing" and names this exact undownloaded
art gap. An operator-downloaded obelisk model (`assets/props/totem/totem.glb`) now exists to close
it; this story wires it in with per-kind tint and swaps the projectile's grey ball for a procedural
glowing sphere.

## Story

As a player watching the board,
I want the three totem kinds to look like a shared wardstone model tinted red/blue/green by kind,
and the Combat totem's shot to look like a glowing projectile instead of a grey ball,
so that I can tell which totem is which at a glance and see a shot leave a totem clearly, without
any change to how totems or projectiles actually play.

## Acceptance Criteria

**Totem model and tint**

1. `totem_actor.tscn`'s `Mesh` node (currently `BoxMesh_totem`, a grey box) is replaced with an
   instance of the operator-downloaded model at `assets/props/totem/totem.glb`, scaled to fit the
   EXISTING totem body collision shape (`BoxShape3D_totembody`, `Vector3(0.8, 1.4, 0.8)`) — the
   model reads as filling roughly the same footprint and height the grey box did, not a different
   size. `Collision`, `Hurtbox`, and `HurtboxShape` (and their shared `BoxShape3D_totembody`
   sub-resource) are UNCHANGED — no new collision shape, no resize of the existing one. There is
   exactly one model asset; no per-kind model variant is authored (Non-Goals).
2. The same model, mounted once in `totem_actor.tscn`, is tinted per kind at spawn time: Combat
   totem RED, Mana Accelerator (tidal) BLUE, Stamina Accelerator (verdant) GREEN. The kind is
   already resolvable at the spawn site the same way `_unit_scene_for` resolves it
   (`src/main/match_runner.gd:773-783`): `balance.kind_at(player.units.kind_index_at(index))
   .kind_name`, one of `&"combat_totem"` / `&"mana_accelerator"` / `&"stamina_accelerator"`
   (`data/balance/balance_config.tres:50,62,74`). No new `src/state/` read is introduced — the kind
   index already flows through the existing per-record field `4-4` authored
   (`UnitBoard.kind_index_at`); this story only adds a presentation-side dispatch on the NAME the
   state layer already exposes.
3. **Tint mechanism, measured then applied (dev-pass call, not fixed here):** the model's runes are
   natively teal. If the importer exposes the rune glow as a separate material/emissive slot
   distinct from the crystal body, tint THAT slot per kind (closest reading to the source: red/
   blue/green runes, crystal body unchanged). If the color is baked into a single texture with no
   separable slot, tint the WHOLE crystal per kind as the fallback (`material_override` on the
   mesh instance, `StandardMaterial3D`, the same runtime-material mechanism
   `telegraph_controller.gd:129-130`'s `_flat_material()` already uses elsewhere in this codebase —
   reuse or mirror that pattern rather than inventing a second one). State which reading was found
   and applied in the Completion Notes. **The final legibility call — whether the chosen tint
   mechanism actually reads correctly at a glance across all three kinds — is the live smoke's**,
   not this AC's.

3a. **Appended by operator ruling, live smoke 2026-09-02 (overturns `4-4`'s 2026-08-30 smoke
    verdict "totem self-rotation, accepted as shipped" — that verdict was passed on the grey-box
    placeholder, not the real model):** a totem is a static structure and MUST NOT visually rotate
    to face its target, and this holds for the combat totem too — it still FIRES IN ALL DIRECTIONS
    (state-side targeting/heading, `ProjectileBoard`/`ProjectileActor`, is untouched by this), it
    just does not visually track. `_aim_unit_actors` (`match_runner.gd`) skips `aim_at`/`aim_along`
    for any actor under the totem scene shape (`Mesh/Totem` — the same shape `_apply_totem_tint`
    keys on), degrade-graceful: a minion is never skipped, an unresolvable kind never throws.

**Projectile visual**

4. The projectile's placeholder grey ball (`src/actors/projectiles/projectile_actor.tscn`'s `Mesh`
   node, currently `SphereMesh_projectile`, radius 0.25) is replaced with a PROCEDURAL, engine-built
   glowing sphere — an emissive `StandardMaterial3D` (`emission_enabled = true`, an authored
   emission color/energy) applied via `material_override` to the same `SphereMesh` geometry, or a
   newly authored one of similar size. No downloaded asset is used for the projectile. A simple
   trail effect (e.g. `GPUParticles3D` or a fading secondary mesh) is OPTIONAL — acceptable to ship
   without one.
5. The projectile's `Hitbox`/`HitboxShape` (`SphereShape3D_projectile`, radius 0.35) and its flight/
   homing/contact behavior (`src/actors/projectiles/projectile_actor.gd`,
   `src/state/match_state.gd`'s projectile advance) are UNCHANGED — this story touches only the
   `Mesh` node and its material.

**Scope discipline**

6. No `src/state/` file changes. No `BalanceConfig` field is added, removed, or renamed. No new
   determinism-snapshot key is introduced (per-player snapshot key set — currently 27, per `4-4`'s
   own measurement — is predicted UNMOVED). No signal or `connect_*` observation seam changes (the
   family stays at eight, per `4-4`'s own "untouched, deliberately" note). This story's touched
   files are confined to `src/actors/minions/totem_actor.tscn`,
   `src/actors/projectiles/projectile_actor.tscn`, `src/main/match_runner.gd` (the spawn-time tint
   dispatch only, near `_spawn_missing_unit_actors`, `match_runner.gd:729-759` — amended by operator
   ruling, live smoke 2026-09-02, to also name the totem aim skip in `_aim_unit_actors`), plus
   `test/integration/test_totem_tint_live.gd`, `assets/props/`, and any new `assets/materials/`
   resource the tint mechanism needs.
7. **Golden prediction: UNMOVED in both directions.** This story changes only `MeshInstance3D`
   geometry/material and adds a presentation-side read of an ALREADY-STATE-OWNED value (the kind
   index/name) at an ALREADY-EXISTING actor-spawn call site — no new state field, no new snapshot
   key, no changed control flow in `src/state/`. State this prediction in the Completion Notes and
   have the dev pass measure `bash test/run_all.sh` before and after: golden
   (`aa3566d7077c07cc90630d155924b620cf5c54e14e6d0f3809d154d31ded7e4f`,
   `test/state/test_determinism.gd:678`), full suite pass/assertion counts, and `project.godot`
   byte-identity, all unmoved.

## Non-Goals

- Totem model variants per kind — ONE model, tint only (AC 1/AC 2). A future story may author
  distinct meshes; this one does not.
- Any animation on the totem model (totems are static structures at move speed 0, `4-4/R12` —
  unchanged) or on the projectile beyond the optional simple trail.
- Particle effects beyond the optional simple projectile trail (AC 4).
- Any gameplay or balance change: firing range, travel budget, homing/acceleration profiles,
  damage, hp, targeting priority, or cadence are all untouched.
- Minion or hero visuals — out of scope; this story is totems and the totem's projectile only.
- Arena changes — `5-0d-arena-edge` is a separate, later story.

## Dev Notes

- **Tier B, not a precondition for anything.** Unlike `5-0a`/`5-0b`, nothing in the E5 board order
  waits on this story. The golden clause still applies in full: this story is Tier A "regardless of
  how it feels" if a measured before/after ever shows the golden or snapshot key set moved
  (`CLAUDE.md`, "Story tiers"); the AC 7 prediction is exactly that measurement's target, not a
  substitute for making it.
- **Asset precondition, verified before this story file was authored:** `assets/props/totem/
  totem.glb` exists, is the only file in `assets/props/totem/` (no `.fbx`/`.gltf`/`.usdz` siblings
  to clean up), and is already named to the `totem.glb` convention — no rename needed.
- **Where the totem's kind is already known to the presentation layer.** `_unit_scene_for`
  (`src/main/match_runner.gd:773-783`) already reads `balance.kind_at(player.units
  .kind_index_at(index))` at spawn time to choose between `TOTEM_SCENE` and `UNIT_SCENE` — but it
  dispatches on WHETHER the kind has a melee attack or a projectile attack, never on the kind's
  NAME, and the resolved `UnitKindProfile` is discarded once that scene choice is made. AC 2's tint
  dispatch needs the NAME (`kind.kind_name`), which the profile already carries
  (`src/state/resources/unit_kind_profile.gd`, `@export var kind_name: StringName`) but which
  nothing on the presentation side currently reads. The natural site to add the tint call is
  `_spawn_missing_unit_actors` (`match_runner.gd:729-759`), right after `unit.global_position =
  spot` — it already has `player` and `actors.size()` (the board index) in scope, the same two
  values `_unit_scene_for` takes.
- **Authored kind names, exact spelling** (`data/balance/balance_config.tres:38,50,62,74`):
  `&"minion"`, `&"combat_totem"`, `&"mana_accelerator"`, `&"stamina_accelerator"`. Only the latter
  three ever reach `TOTEM_SCENE`; a defensive default (e.g. unrecognized name / `NO_KIND_INDEX` —
  `balance_config.gd:278` — leaves the model at its native teal, or falls back to one of the three)
  is a dev-pass call, since this path is presentation-only and the same
  "unresolvable kind falls to `UNIT_SCENE`" degrade-gracefully spirit `_unit_scene_for`'s own header
  states (`match_runner.gd:770-772`) applies here too — a totem never disappears or throws for lack
  of a tint.
- **Current placeholder geometry, exact values** (`src/actors/minions/totem_actor.tscn`):
  `Collision`/`HurtboxShape` share `BoxShape3D_totembody`, `size = Vector3(0.8, 1.4, 0.8)`, offset
  `y = 0.7` (root at the box's FEET, half-height offset — the same convention `unit_actor.tscn` and
  `hero.tscn` use). The current `Mesh` node sits at the identical `y = 0.7` offset with the
  identical box mesh. AC 1's scale rule means the new model instance keeps this same offset
  discipline (visually fills roughly `0.8 x 1.4 x 0.8` centred on the collision box, root at feet)
  rather than introducing a new pivot convention.
- **Current placeholder projectile geometry** (`src/actors/projectiles/projectile_actor.tscn`):
  `Hitbox`/`HitboxShape` use `SphereShape3D_projectile`, `radius = 0.35`, offset `y = 0.7`. The
  current `Mesh` uses `SphereMesh_projectile`, `radius = 0.25`, `height = 0.5`, same offset. The
  scene's own docstring states the hitbox radius is DELIBERATELY larger than the visible mesh
  ("generous contact over frame-perfect geometry") — AC 5 preserves that gap; do not grow the
  visible mesh to match the hitbox.
- **Runtime-material precedent already in this codebase**, useful for AC 3 and AC 4:
  `telegraph_controller.gd:129-130`'s `_flat_material(color: Color) -> StandardMaterial3D`
  constructs a `StandardMaterial3D` and assigns it via `material_override` at runtime — the same
  mechanism this story's tint (AC 3) and glow (AC 4) both need. **Ruled (operator, review fix
  2026-09-02):** the three per-kind tint colors are NAMED CONSTANTS in presentation code, not a new
  `data/*.tres` resource — `data/telegraphs/*.tres` is a real precedent for authoring per-kind color
  in data, but AC 6's touched-files list does not include `data/`, and a new data resource would
  violate this story's own scope AC. A `.tres` tint profile arrives only if per-kind totem model
  variants ever become real (Non-Goals).
- **`.glb` import.** Godot 4.6 imports `.glb` natively (no `EditorScenePostImport` script is needed
  the way `assets/characters/skeletonzombie/strip_model_anim.gd` was needed for the minion's `.fbx`
  Mixamo strip, per `3-0a/R10` — that was for stripping a bundled animation take, and this model has
  none). Import with default settings unless the dev pass measures a reason not to; record the
  import settings actually used in the Completion Notes, per the `5-0a` precedent of naming every
  import parameter touched (`5-0a-hero-locomotion.md:157`, `root_scale = 1.0`, no manual scale
  correction).
- **Baseline measured for this story (before any change):** HEAD
  `60b76e7826df6132657f1400d4fae7dfd735b861` == `origin/main`, clean tree except the untracked
  `assets/props/` directory this story's asset lives in. Golden
  `aa3566d7077c07cc90630d155924b620cf5c54e14e6d0f3809d154d31ded7e4f`
  (`test/state/test_determinism.gd:678`), unmoved since `5-0a`/`5-0b` (both Tier B, both confirmed
  golden-unmoved at their own close-outs). Per-player snapshot key set: 27 (unchanged since `4-4`'s
  review fix pass).

### Project Structure Notes

- No new `src/` file is required by this story's fixed decisions — a tint dispatch is a few lines
  in `match_runner.gd` near the existing spawn site, and the projectile glow is a scene/material
  edit. If the dev pass finds a small per-kind color table clearer as its own `data/*.tres`
  resource (mirroring `data/telegraphs/`), that stays within the existing `data/` layout — no new
  top-level folder.
- `assets/props/totem/totem.glb` follows the existing per-asset-folder convention
  (`assets/characters/paladin/`, `assets/characters/skeletonzombie/`) — one folder per named asset.
  A new material resource, if authored standalone rather than constructed at runtime, belongs under
  the existing `assets/materials/` folder.

### Project Context Rules

- F1: exactly one `func _physics_process` in `src/`, in `match_runner.gd` — this story adds no new
  per-frame update loop (a spawn-time tint assignment runs once, at spawn).
- D3(a): `Input.*` only under `src/controllers/` — not implicated, no input surface touched.
- D3(b)/A2: no global RNG / `Time` / `OS` / `Engine` in `src/state/` — not implicated; this story
  makes no `src/state/` change at all (AC 6).
- Docs and code never share a commit; commits are pure ASCII via `git commit -F <tempfile outside
  the repo>`; shell is PowerShell 5.1 (no `&&`); trailer `Co-Authored-By: Claude Opus 4.8
  <noreply@anthropic.com>`.
- Story tier: Tier B — lighter skill chain, no separate gate pass, but the measured before/after
  (AC 7) is what CONFIRMS the tier rather than assumes it (`CLAUDE.md`, "Story tiers"; `E4-P/R9`).

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8127-8247 —
  "Session 2026-09-01 -- E5 planning"] — `E5-P/R5`'s story list, order, and tiers; this story's own
  one-line ruling at `:8183`.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/gdd.md:188,349,391] — totem/ward
  subtypes, "small wardstone-like models... intentionally unimposing", placeholder/grey-box art
  standing bar.
- [Source: docs/implementation-artifacts/4-4-totems.md] — where totem kinds and the projectile were
  built; the grey-box AC 3 scene docstring this story's motivating gap quotes; per-kind data shape
  (`UnitKindProfile`); the golden's most recent totem-relevant re-baseline history.
- [Source: src/actors/minions/totem_actor.tscn] — current grey-box `Mesh`, `Collision`/`Hurtbox`
  shapes and offsets this story must not touch except the mesh.
- [Source: src/actors/projectiles/projectile_actor.tscn] — current grey-ball `Mesh`, `Hitbox` shape
  and the deliberate hitbox-larger-than-mesh gap this story must preserve.
- [Source: src/main/match_runner.gd:729-783] — `_spawn_missing_unit_actors` (tint dispatch site) and
  `_unit_scene_for` (the existing kind-resolution precedent this story's tint lookup mirrors).
- [Source: src/state/resources/unit_kind_profile.gd] — `kind_name` field this story reads.
- [Source: src/state/resources/balance_config.gd:278] — `NO_KIND_INDEX`, the missing-kind contract.
- [Source: data/balance/balance_config.tres:38,50,62,74] — authored kind names, exact spelling.
- [Source: src/actors/hero/telegraph_controller.gd:129-130] — `_flat_material()`, the runtime
  `StandardMaterial3D`/`material_override` precedent for AC 3/AC 4.
- [Source: docs/implementation-artifacts/5-0a-hero-locomotion.md] — Tier B close-out precedent
  (golden-unmoved measurement discipline, import-settings recording discipline) this story follows.

## Dev Agent Record

### Agent Model Used

Sonnet 5 (operator-stated)

### Debug Log References

- Preconditions verified: HEAD `895d8f900562b4adb733b8d4926bedc64ec622c4` == `origin/main`, tree
  clean except untracked `assets/props/`, no running Godot processes, story Status
  `ready-for-dev`.
- Before-baseline `bash test/run_all.sh` (`C:\dev\_50c-suite-before.txt`): start
  2026-09-02 13:21:12, end 13:24:20, `=== 577 tests, 0 failed, 4433 assertions ===`, 48
  integration files, `ALL TESTS PASSED`, `EXIT_CODE=0`.
- Editor session 1 (`godot --headless --editor --quit --path .`), for the `totem.glb` import:
  `git diff -- project.godot` empty both before and after; `sha256sum project.godot`
  unchanged (`8879de49...79700`).
- Measured the imported model headlessly (throwaway `--script` runs, deleted after use, never
  committed): combined mesh AABB `position=(-0.133794, 0.002195, -0.164973)`,
  `size=(0.325282, 0.526651, 0.327314)`; one shared `StandardMaterial3D` ("obelisk") across
  both mesh instances (obelisk body + stand); `albedo_texture=totem_0.png`,
  `metallic_texture=totem_1.png`, `roughness_texture=totem_1.png`, `emission_texture=totem_2.png`,
  `normal_texture=totem_3.png`, `emission_energy_multiplier=1.0` (`totem_4.png` extracted but
  unreferenced by the measured `StandardMaterial3D` — corrected by review fix 2026-09-02: it is NOT
  an unused UV-set channel, it is the `KHR_materials_specular` extension's `specularTexture`,
  confirmed by grepping the raw `.glb` JSON chunk for `KHR_materials_specular`/`specularTexture`;
  Godot's glTF importer extracts it but `StandardMaterial3D` has no import path for that glTF
  extension, so it goes unreferenced. Left in place, untouched, per the "no rename/cleanup needed"
  Dev Notes precondition applying equally to import-generated siblings.)
- Editor session 2 (same command), for the new `test_totem_tint_live.gd.uid`: `git diff --
  project.godot` empty; hash unchanged.
- Headless scene-load sanity check (`totem_actor.tscn`, `projectile_actor.tscn` via throwaway
  `--script`, deleted after use): both load and instantiate without error; `Mesh/Totem` child
  present on the totem actor.
- `test/integration/test_totem_tint_live.gd` run individually: PASS (`actors=3`, all three
  measured emission colors match).
- Mutation proofs (table below) run individually against the same file; each mutation FAILED the
  test as expected, then `src/main/match_runner.gd` was restored by copying back the pre-mutation
  backup (`C:\dev\_50c_backups\match_runner.gd.orig`) and the SHA-256 verified identical to the
  pre-mutation hash, never `git checkout`.
- Regression spot-check after implementation: `test_projectile_flight_live.gd` and
  `test_summon_actor_live.gd` run individually — both PASS, unchanged behavior.
- After-baseline `bash test/run_all.sh` (`C:\dev\_50c-suite-after.txt`): start 2026-09-02
  13:31:23, end 13:34:30, `=== 577 tests, 0 failed, 4433 assertions ===` (identical to
  before-baseline — golden and per-player snapshot key set unmoved, both directions), 49
  integration files (48 + `test_totem_tint_live.gd`, new), `ALL TESTS PASSED`, `EXIT_CODE=0`.
- Tier B budget: 13:21:12 -> 13:34:30, ~13m18s elapsed, well inside the ~1h budget.
- **Review fix pass 2026-09-02 (operator-ruled review, corrective fix, no board write, Status stays
  `review`):** preconditions verified — HEAD `895d8f900562b4adb733b8d4926bedc64ec622c4` ==
  `origin/main`, tree matched the expected modified/untracked set exactly.
  - Fix 1 (one mechanism, review HIGH+MED+LOW): `totem_actor.tscn`'s `Mesh` node is a mesh-less
    `MeshInstance3D` container (confirmed via `editor_description` and a live tree dump —
    `Mesh (mesh=null) -> Totem -> ... -> RootNode -> {obelisk_1_Low, obelisk_stand_Low}`, each
    holding one real leaf `MeshInstance3D`), so both `_tint_mesh_recursive` and the test's
    `_collect_emissions` were tinting/measuring a node that never carries the model's real geometry.
    `_tint_mesh_recursive` now skips any `MeshInstance3D` with `mesh == null` (recurse into children
    only, no dead `material_override` allocation). `_collect_emissions` does the same skip;
    `_measured_emission` now returns `null` unless `colors.size() >= 2` (the model mounts body +
    stand, so a partial or container-only tint reads as failure, matching the docstring correction
    that also went in — dropped the false "null-on-missing-override-only" promise).
  - Mutation-proven live (table appended to Mutation Proof Table below): the review's mutation B
    ("early-return after the first tinted `MeshInstance3D`"), placed where it actually reproduces
    the described failure — `return` after the recursive call inside the sibling `for` loop, not
    right after the tint assignment itself (that placement was tried first and does NOT break
    anything, since the body and stand mesh instances are independent leaf siblings under
    `RootNode`, not nested — the `return` right after the assignment only ends that leaf's own empty
    child loop) — now FAILS (`got=<null>` for all three kinds, `colors.size() == 1`). Mutation 2 from
    the dev table (dispatch call replaced with `pass`) re-run against the fixed file: still FAILS.
    Unmutated fixed file: PASSES. Each mutation applied/reverted individually with a copy-back +
    SHA-256 restore against `C:\dev\_50c_backups\match_runner.gd.fixed`
    (`746660fc88da4dab03f7a7eaa0568372b49187d2c331caadccac2ebc39a64872`), never `git checkout`.
  - Fix 2 (docs-only, review MED): rewrote the AC 2/AC 3 Completion Note's unmeasured
    "red/blue/green runes, crystal body unchanged" claim. Measured directly off the live material
    (throwaway `--script` runs, deleted after use): `emission_operator = 1` (`MULTIPLY`), NOT the
    `StandardMaterial3D` default `ADD` (`0`) as this fix's own instructions assumed — checked the
    engine default separately (`StandardMaterial3D.new().emission_operator == 0`) to confirm the
    totem material was NOT left at default. Sampled `totem_2.png` (the `emission_texture`): a teal
    `(0.1725, 0.9059, 0.9059)` rune mask on a black `(0,0,0)` field. Under `MULTIPLY` the body reads
    correctly as unchanged (mask is black there, so the product is zero regardless of tint — true
    both before and after tinting, not because albedo was untouched), but the rune color is
    `tint * mask` component-wise, which for `combat_totem`'s red `(0.85, 0.1, 0.1)` crushes down to
    roughly `(0.15, 0.09, 0.09)` — dim and desaturated, since the mask's own red channel is only
    `0.17` against `0.91` green/blue — NOT the clean red the old note implied. Also corrected:
    `totem_4.png` is the `KHR_materials_specular` extension's `specularTexture` (confirmed by
    grepping the raw `.glb`'s JSON chunk for `KHR_materials_specular`/`specularTexture`, both
    present), not an unused UV-set channel; `StandardMaterial3D` has no import path for that glTF
    extension so it goes unreferenced regardless. Also corrected the "Presentation blind-spot pin
    (Dev Notes' own callout)" mislabel — re-read `## Dev Notes`: it names the presentation-side
    blind spot as motivating context, it does not order a dedicated test; the tint test was the dev
    pass's own initiative.
  - Nothing else touched: projectile glow stays unpinned, `_TOTEM_TINT_BY_KIND` dispatch and the
    tint-call-before-`actors.append` ordering are untouched, p1-only test coverage untouched, per
    this fix pass's own instruction.
  - Single blocking full-suite run at the end (`bash test/run_all.sh`, output
    `C:\dev\_50c-fix-suite.txt`): `=== 577 tests, 0 failed, 4433 assertions ===`, 49 integration
    files, `ALL TESTS PASSED`, `EXIT_CODE=0` — identical state-suite counts to both prior baselines
    (golden and snapshot key set held; no `src/state/` file touched by this fix pass).

### Completion Notes List

- **AC 1 (model + scale):** `totem.glb` imported with DEFAULT settings, no manual scale
  correction — `root_scale = 1.0`, `apply_root_scale = true`, `gltf/embedded_image_handling = 1`
  (extract), `nodes/import_as_skeleton_bones = false`, `animation/import = true` (the model
  carries none, so this is a no-op default rather than a touched setting). The model's own combined
  mesh AABB measured after import: `size (0.325282, 0.526651, 0.327314)`, origin near the model's
  own feet (`min y = 0.002195`) — unlike the `BoxMesh` it replaces (centred on its origin, needing
  the old `+0.7` node offset), so the new `Mesh` container's transform is a uniform scale of `2.5`
  plus a small centering/feet-alignment translation, not the old convention's bare `y=0.7`. Result:
  the model reads at roughly `(0.813, 1.317, 0.818)` in root space against the collision box's
  `(0.8, 1.4, 0.8)` — footprint within ~2%, height ~94% (a shade under, read as the GDD's
  "intentionally unimposing" rather than a mismatch). `Collision`/`Hurtbox`/`HurtboxShape` and
  `BoxShape3D_totembody` are byte-unchanged. The `Mesh` node mirrors the `hero.tscn`
  grounding-container pattern (a `MeshInstance3D` with no `mesh` of its own, holding only the
  transform; the model itself instanced as a plain child with no transform of its own) rather than
  inventing a new convention.
- **AC 2/AC 3 (tint mechanism, measured then applied, corrected by review fix 2026-09-02):** the
  imported material carries a SEPARATE `emission_texture` (`totem_2.png`) distinct from its
  `albedo_texture` (`totem_0.png`) — the importer DOES expose the rune glow as a separable slot, so
  AC 3's PREFERRED reading applies, not its single-texture fallback: `match_runner.gd`'s
  `_apply_totem_tint` duplicates each mesh instance's own material (`StandardMaterial3D.duplicate()`,
  so the two totem body/stand mesh instances and every other spawned totem each carry an independent
  runtime copy — no shared-state bleed between totems) and overwrites only `emission`/
  `emission_enabled`, leaving `albedo_texture` (and therefore the crystal body's LIT appearance)
  completely untouched. Tint colors are named constants (`_TOTEM_TINT_BY_KIND`) per the Dev Notes'
  review-fix ruling, not a `data/*.tres` resource. An unresolved kind (unrecognized name, or a
  non-totem spawn with no `Mesh/Totem` child) leaves the model at its native teal — no throw,
  matching `_unit_scene_for`'s own degrade-gracefully spirit.
  **The original Completion Note here claimed "red/blue/green runes, crystal body unchanged" — that
  was never measured, and a corrective pass (2026-09-02) measured it and found it wrong on one
  point.** The imported material's `emission_operator` is `MULTIPLY` (value `1`), NOT the
  `StandardMaterial3D` default `ADD` (value `0`) — measured directly off the live material, not
  assumed. The `emission_texture` (`totem_2.png`) is a teal `(0.17, 0.91, 0.91)` rune mask on a
  black `(0,0,0)` field (measured by sampling the loaded image). Under `MULTIPLY`, final emission is
  `tint_color * mask_sample` component-wise: at body pixels (mask is black) the product is always
  zero regardless of tint, so "crystal body unchanged" DOES hold — but not because albedo is
  untouched, rather because the body was never emissive in the first place, before or after tinting.
  At rune pixels the product is `tint * teal`, which is NOT a clean read of the tint color: the mask's
  own red channel is only `0.17` against `0.91` green/blue, so `combat_totem`'s red tint
  `(0.85, 0.1, 0.1)` reduces to roughly `(0.15, 0.09, 0.09)` — a dim, desaturated red-brown, not a
  bright red. `mana_accelerator`'s blue and `stamina_accelerator`'s green tints, whose dominant
  channels overlap the mask's own green/blue weighting, come through closer to their authored hue.
  **Smoke-watch (unresolved by this fix, needs a live look, not a further doc edit):** do the three
  totem kinds read as distinctly different colors at a glance, and — the specific risk this measured
  math raises — does the Combat totem's tint read as recognizably RED rather than washing out toward
  the mask's native teal-brown.
- **AC 3a (totem never rotates, second corrective fix pass 2026-09-02, operator ruling on live
  smoke):** confirmed from the code, before changing anything, that firing direction/homing is
  state-side and never reads an actor's rotation — `ProjectileActor.heading` is a private `Vector3`
  field driven by `launch_toward`/`turn_toward_this_tick` off world POSITIONS
  (`ProjectileBoard`/`_target_world_position`), and `_face_heading()`'s own doc-comment states
  "PRESENTATIONAL ONLY — nothing reads this rotation". So skipping a totem's `aim_at`/`aim_along`
  changes nothing about where or whether it fires; the Combat totem still fires in all directions.
  `_aim_unit_actors` (`match_runner.gd`) now skips the aim call for any actor whose scene carries a
  `Mesh/Totem` child — the same scene-shape test `_apply_totem_tint` and its live test already key
  on, not `_unit_scene_for`'s kind-data resolution, kept symmetrical with the existing 4-3c
  animation-controller guard immediately above it in the same loop. Degrade-graceful by
  construction: a minion never carries that child and is never skipped; an unresolvable kind falls
  to `UNIT_SCENE` (`_unit_scene_for`'s own fallback), which also never carries it.
- **AC 4 (projectile glow):** `projectile_actor.tscn`'s `Mesh` node keeps the exact same
  `SphereMesh_projectile` geometry (radius 0.25, same `+0.7` offset) and gains a
  `material_override` (a new `StandardMaterial3D_projectileglow` sub-resource, `emission_enabled =
  true`, warm amber `emission`, `emission_energy_multiplier = 3.0`) — the
  `telegraph_controller.gd:129-130` `_flat_material()` runtime mechanism mirrored as static scene
  authoring, since the glow never varies per kind or instance (only the Combat totem ever fires).
  No trail effect authored (AC 4's optional clause; acceptable to ship without one).
- **AC 5 (projectile hitbox/behavior):** `Hitbox`/`HitboxShape`
  (`SphereShape3D_projectile`, radius 0.35) and `projectile_actor.gd`/`match_state.gd`'s advance
  logic are untouched — confirmed by `test_projectile_flight_live.gd` passing unchanged
  (`no_hitbox=true body_and_hurtbox=true totem_static=true ... steered=true`).
- **AC 6 (scope discipline):** no `src/state/` file touched; touched files confined to the
  scene/runner/asset set AC 6 names, plus the new integration test.
- **AC 7 (golden):** predicted UNMOVED; measured UNMOVED. Both `bash test/run_all.sh` runs report
  `=== 577 tests, 0 failed, 4433 assertions ===` and `ALL TESTS PASSED` — identical counts before
  and after, which is what confirms `test_determinism.gd`'s hardcoded golden
  (`aa3566d7...ded7e4f`) held both times (a moved golden would have failed that one test, not
  merely changed a number). `project.godot` byte-identical (verified after both editor sessions).
- **Presentation blind-spot pin** (corrected by review fix 2026-09-02: this was the dev pass's OWN
  initiative — nothing in Dev Notes ordered it; the Dev Notes section names the presentation-side
  blind spot as context for why the tint dispatch is needed, it does not call for a dedicated test):
  `test/integration/test_totem_tint_live.gd` added — spawns all three totem kinds via direct
  `UnitBoard.add()` injection (not a card cast; `test_summon_actor_live.gd` already covers that
  resolver path) and asserts the measured `MeshInstance3D.material_override.emission` on the
  spawned actor's model matches the authored per-kind constant. Mutation-proven (table below): a
  wrong color and a disabled dispatch call both fail it; the unmutated file passes.
- **Tier stayed B**, confirmed rather than assumed: no `src/state/` file touched, no
  `BalanceConfig` field added/removed/renamed, no snapshot key added, golden and snapshot key set
  (27) measured unmoved both directions.

### Mutation Proof Table

Target: `test/integration/test_totem_tint_live.gd`, run individually
(`godot --headless --path . --script res://test/integration/test_totem_tint_live.gd`). Backup
outside the repo (`C:\dev\_50c_backups\match_runner.gd.orig`), restore by copy-back + SHA-256
verification. Provenance: MEASURED, both runs live this dev pass.

| # | Mutation | `src/main/match_runner.gd` change | Result | Restore verified (SHA-256) |
| --- | --- | --- | --- | --- |
| 1 | Wrong tint color | `combat_totem` constant swapped to the `mana_accelerator` color | FAIL — `combat_totem: want=(0.85, 0.1, 0.1, 1.0) got=(0.1, 0.35, 0.9, 1.0)` | `bfa9b040...45e737f15` identical pre/post |
| 2 | Dispatch never called | `_apply_totem_tint(unit, player, actors.size())` call at the spawn site replaced with `pass` | FAIL — all three kinds `got=<null>` | `bfa9b040...45e737f15` identical pre/post |

Unmutated file: PASS (`actors=3`, no mismatches) — confirmed immediately after each restore.

**Review-fix pass 2026-09-02** (mesh-less-container fix: `_tint_mesh_recursive` in `match_runner.gd`
now skips any `MeshInstance3D` whose `mesh == null`, and `test_totem_tint_live.gd`'s
`_collect_emissions` does the same plus `_measured_emission` requires `colors.size() >= 2`). Same
target and run command; backup `C:\dev\_50c_backups\match_runner.gd.fixed`
(`746660fc...39a64872`), restore by copy-back + SHA-256 verification each time. Provenance:
MEASURED, both runs live this fix pass.

| # | Mutation | `src/main/match_runner.gd` change | Result | Restore verified (SHA-256) |
| --- | --- | --- | --- | --- |
| 3 | Review mutation B — sibling branch truncated after the first real tint | `for child in node.get_children(): _tint_mesh_recursive(child, color)` gains a `return` right after the recursive call, so `_tint_mesh_recursive` only ever descends into the FIRST child at each tree level; the totem's obelisk-body and stand mesh instances live under separate sibling branches of `RootNode`, so this stops the walk after tinting the body and never reaches the stand. (A literal "return right after the tint assignment" placement was tried first and does NOT reproduce this — the totem's body/stand `MeshInstance3D`s are leaf nodes with no children of their own, and are visited as independent siblings, not nested, so that placement's `return` only ends the leaf's own empty child loop and has no effect. This sibling-loop placement is the one that actually matches "early-return after the first tinted MeshInstance3D".) | FAIL — all three kinds `got=<null>` (only the body mesh got tinted; `colors.size() == 1 < 2` in `_measured_emission`) | `746660fc...39a64872` identical pre/post |
| 4 | Dispatch never called (re-run against the fixed file) | `_apply_totem_tint(unit, player, actors.size())` call at the spawn site replaced with `pass` | FAIL — all three kinds `got=<null>` | `746660fc...39a64872` identical pre/post |

Unmutated (fixed) file: PASS (`actors=3`, no mismatches) — confirmed immediately after each restore.

**Second corrective fix pass 2026-09-02** (totem no-rotation, `3a` above): target
`test/integration/test_totem_no_rotation_live.gd`, run individually (`godot --headless --path .
--script res://test/integration/test_totem_no_rotation_live.gd`). Backup
`C:\dev\_50c_backups\match_runner.gd.fix2`
(`31cde1388f52e0bdee26a952d70e16c3602de7bdc49c3ce20518757cfa42fb06`), restore by copy-back +
SHA-256 verification. Provenance: MEASURED, both runs live this fix pass.

| # | Mutation | `src/main/match_runner.gd` change | Result | Restore verified (SHA-256) |
| --- | --- | --- | --- | --- |
| 5 | Aim skip removed | the `if unit.get_node_or_null("Mesh/Totem") != null: continue` guard in `_aim_unit_actors` gated behind `if false and ...` (never taken) | FAIL — `totem_still=false ... totem_rotated(spawn=0.0000 now=-1.5708)` | `31cde138...c9fa42fb06` identical pre/post |

Unmutated file: PASS (`totem_still=true minion_aimed=true`) — confirmed immediately after restore.
The same run also confirms the guard does not over-reach: `minion_aimed=true` in both the mutated
and unmutated runs, since the mutation only touched the totem branch.

### File List

- `src/actors/minions/totem_actor.tscn` (modified — AC 1/AC 2/AC 3)
- `src/actors/projectiles/projectile_actor.tscn` (modified — AC 4/AC 5)
- `src/main/match_runner.gd` (modified — AC 2/AC 3 tint dispatch near `_spawn_missing_unit_actors`;
  second fix pass adds the totem aim skip in `_aim_unit_actors`, AC 3a)
- `test/integration/test_totem_no_rotation_live.gd` (new — AC 3a presentation pin; no `.uid`
  companion yet — unlike `test_totem_tint_live.gd.uid`, this file was never opened in the editor
  this pass, only run headless via `--script`, which does not trigger the editor's filesystem scan)
- `assets/props/totem/totem.glb` (operator-downloaded, precondition asset; untracked, stays
  untracked per this dev pass's no-commit instruction)
- `assets/props/totem/totem.glb.import` (generated by import; untracked)
- `assets/props/totem/totem_0.png` .. `totem_4.png` (generated by import — texture extraction;
  untracked)
- `assets/props/totem/totem_0.png.import` .. `totem_4.png.import` (generated by import; untracked)
- `test/integration/test_totem_tint_live.gd` (new — AC 2/AC 3 presentation pin)
- `test/integration/test_totem_tint_live.gd.uid` (generated by editor scan; new)

### Change Log

| Date | Change |
| --- | --- |
| 2026-09-02 | Story authored via `gds-create-story`. Not yet cleared for a dev pass. |
| 2026-09-02 | Review fix: Dev Notes tint-color bullet ruled inline named constants, not a `data/*.tres` resource (resolves AC 6 <-> Dev Notes contradiction). Promoted authored -> ready-for-dev. |
| 2026-09-02 | Dev pass: `totem.glb` imported (default settings), totem model mounted per AC 1/AC 2, per-kind emission tint applied via `_apply_totem_tint` (AC 3, separable emission-slot reading measured and used), projectile given a procedural emissive glow (AC 4), `test_totem_tint_live.gd` added and mutation-proven. Golden and snapshot key set measured unmoved both directions (577/0/4433 identical before/after). Status -> review. |
| 2026-09-02 | Review fix pass: `_tint_mesh_recursive` and the test's measurement walk both now skip mesh-less `MeshInstance3D` containers (the totem's `Mesh` node), killing a dead material allocation and a test blind spot that let a real-model mutation pass GREEN; `_measured_emission` now requires >= 2 contributing mesh instances. Completion Notes corrected: measured `emission_operator = MULTIPLY` (not the assumed default `ADD`), rune color is `tint * teal-mask` (dims/desaturates `combat_totem`'s red), body-unchanged holds for a different reason than originally stated (mask is black there, not because albedo is untouched); `totem_4.png` corrected to the measured `KHR_materials_specular` `specularTexture`; tint-test attribution corrected to the dev pass's own initiative, not a Dev Notes order. Mutation-reproven against the fixed file (2 mutations, both FAIL as expected). Full suite re-run: 577/0/4433 + 49 integration, identical to both prior baselines. Status unchanged (`review`). |
| 2026-09-02 | Second corrective fix pass, from the operator's live smoke: overturns `4-4`'s 2026-08-30 smoke verdict that totem self-rotation was acceptable — that verdict was passed on the grey-box placeholder, not the real model. Confirmed from the code first that firing direction/homing is state-side and never reads actor rotation (`ProjectileActor.heading`, `_face_heading()`'s own "PRESENTATIONAL ONLY" note), so the fix is presentation-only: `_aim_unit_actors` (`match_runner.gd`) now skips `aim_at`/`aim_along` for any actor carrying the `Mesh/Totem` scene shape; the Combat totem still fires in all directions. New AC 3a appended (acceptance line + AC 6 scope-line amendment, both by operator ruling). Pinned by new `test/integration/test_totem_no_rotation_live.gd`, mutation-proven (guard removed -> FAIL, restored + SHA-256 verified). Status unchanged (`review`). |
| 2026-09-02 | Close-out: live smoke (pad, flip [0,3], flip reverted) passed with one same-day corrective fix (totem no-rotation, folded into this story as AC 3a) and two accepted DEFERRED polish findings (combat totem tint red-brown, projectile glow flatness). Status -> done. |

## Live Smoke Results

Operator, pad, flip `[0,3]`, flip reverted. Date 2026-09-02.

- All three totem kinds (combat, mana accelerator, stamina accelerator) are distinguishable by
  color at a glance.
- Combat totem's red tint reads dim red-brown rather than a clean red — matches the measured
  mechanism (`emission_operator = MULTIPLY` over a teal rune mask whose red channel is ~0.17, so
  red tints crush). Brighter would read better but is not essential. **DEFERRED polish**, not
  fixed this story.
- The totem model sits right in the world: grounded, fills the footprint the old grey box
  occupied, no float or sink.
- Projectile: a yellow glowing sphere, more noticeable at a glance than the old grey ball per two
  household observers, but the operator judged the old grey ball read more three-dimensional (flat
  emissive kills depth cues). Stays yellow; depth/shading is **DEFERRED polish**, not fixed this
  story.
- **New finding mid-smoke:** the totem visually tracked (rotated to face) its target. The operator
  ruled totems NEVER rotate — a static structure — overturning `4-4`'s "self-rotation, accepted as
  shipped" smoke verdict, which was passed on a grey-box placeholder rather than the real model.
  Fixed same day (AC 3a above): `_aim_unit_actors` now skips the totem's visual aim; firing itself
  is state-side and unaffected (the Combat totem still fires in all directions, including behind
  itself).
- Re-smoke after the fix, 3/3 PASS: totem stays put; still fires 360 degrees including behind
  itself; minions still aim normally.
- Gameplay untouched throughout — this story is presentation-only.
