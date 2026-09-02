---
baseline_commit: 60b76e7826df6132657f1400d4fae7dfd735b861
---

# Story 5.0c: Totem and projectile models

Status: ready-for-dev

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
   dispatch only, near `_spawn_missing_unit_actors`, `match_runner.gd:729-759`), `assets/props/`,
   and any new `assets/materials/` resource the tint mechanism needs.
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

Sonnet 5 (claude-sonnet-5)

### Debug Log References

### Completion Notes List

### File List

### Change Log

| Date | Change |
| --- | --- |
| 2026-09-02 | Story authored via `gds-create-story`. Not yet cleared for a dev pass. |
| 2026-09-02 | Review fix: Dev Notes tint-color bullet ruled inline named constants, not a `data/*.tres` resource (resolves AC 6 <-> Dev Notes contradiction). Promoted authored -> ready-for-dev. |
