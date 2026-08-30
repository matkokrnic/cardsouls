---
baseline_commit: 6cd6dd187824c211ae2ed804f8cd2276585cde55
---

# Story 4.6: Camera Lock-On

Status: authored

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want the camera always locked on a target, with my hero always facing that target and a
right-stick click/flick to re-lock or retarget,
so that spacing and orientation read the way a Souls/Sekiro lock-on does now that the board can
carry more than one thing worth aiming at.

## Acceptance Criteria

**Facing ownership (FULL variant, `CC/R1`(i))**

1. `HeroState.facing` (`src/state/hero_state.gd:87`, world-space planar `Vector2`, snapshot field
   at `to_snapshot()` line 450) is driven from the locked target's position, not from movement
   input. It is set unconditionally every tick a target is locked (no zero-guard on movement, the
   opposite of today's `if not dir.is_zero_approx(): player.hero.facing = ...` at
   `match_state.gd:2335-2336`), so a hero can strafe or stand still while always facing the target.
   The default/fallback target is always the opposing hero (`CC/R2`) — there is no unlocked state.
2. The determinism golden (`test_determinism.gd:608`,
   `a96b123e67ef8330b5bb07c1bafefaf5204e9bf9982eded936f8d69b29afa522`) and the snapshot key set are
   expected to move and are re-baselined as this story's own measured cause — accepted consequence,
   not a defect (`DP/R1`(i), `CC/R1`).
3. `_is_facing` (`match_state.gd:1630-1632`) and `block_facing_arc_degrees`
   (`balance_config.gd:261`) keep their existing mechanism unchanged — target-derived facing feeds
   the same gate. Named consequence, accepted with eyes open: against the locked target the arc can
   no longer be dodged by turning away, so block becomes pure timing (Sekiro-style); orientation as
   a defensive dimension migrates into target *selection* instead (`DP/R1`(i)).
4. The single-yaw-source contract at `hero.gd:31-42` (one `atan2(hero_state.facing.x,
   hero_state.facing.y)`, assigned to both `hitbox.rotation.y` and `mesh.rotation.y`) is preserved
   — target-derived facing still reaches the actor through the existing `facing` field and the
   existing one yaw computation. No second yaw site is added.
5. DECISION A (`test_root_rotation_isolation.gd`) is unaffected: the hero root still never rotates;
   target-derived facing rotates the same child nodes (Hitbox, Mesh) the input-derived facing
   rotated, through the same field.

**Lock/retarget controls (`CC/R2`, `CC/R3`)**

6. The `InputIntent.aim` field (`input_intent.gd:20`) is retired from the free-rotation route named
   at the 1-2 gate — that route is SUPERSEDED, not supplemented, per `DP/R1`'s own wording and
   `CC/R2`. Whether `aim` is repurposed, replaced, or left unused is dev-pass terrain (Open
   Questions).
7. Right-stick CLICK instantly re-locks onto the opposing hero, regardless of current target
   (`CC/R3`). This is the only way to resolve an off-screen opposing hero back into lock.
8. Right-stick FLICK switches lock to the best on-screen candidate in that screen-space direction,
   among minions, totems, and the opposing hero (`CC/R3`). No unlock state exists at any point —
   a flick with no on-screen candidate in that direction is a no-op (target unchanged).
9. Retarget resolution follows the contact-fact precedent (`1-8`/`4-1` `R7` lineage, `CC/R5`):
   screen-space candidate resolution happens in presentation, outside `src/state/`; the RESULT (a
   `[slot, index]` unit/hero address, using the `4-3a/R16` convention where `index == -1` means that
   slot's hero) is pushed into the intent stream as an input fact. Replay records the outcome of a
   flick/click, never the raw stick deflection.
10. `GamepadProfile` (`src/controllers/gamepad_profile.gd`, `data/gamepad_profile.tres`) gains new
    authored fields for the right-stick axes and the stick-click button, following the existing
    `move_axis_x`/`move_axis_y`/`*_button` pattern (named `JoyAxis`/`JoyButton` exports, not raw
    ints) — today's file has no right-stick or stick-click field at all (measured: `gamepad_profile.gd`
    lines 24-29 cover only the left stick and three face/shoulder buttons). `GamepadController`
    (`src/controllers/gamepad_controller.gd`) reads them the same device-filtered way it already
    reads `move_axis_x`/`_y` and the three buttons (`2-2` precedent — no Input Map action).
11. A keyboard binding is proposed for click/flick equivalents, consistent with keyboard parity
    elsewhere (`2-2/R5`); controller is primary and carries the live smokes (`CC/R4`).
12. `RecordFile.FORMAT_VERSION` (currently 5, `record_file.gd:131`, pinned by
    `test_record_file.gd:139`) is expected to bump if the intent stream's shape changes to carry a
    retarget result — confirmed, not assumed, at dev time; a shape that fits inside the existing
    `InputIntent`/recorded-fact channels without a new element would not require it.

## Non-Goals

- Off-screen telegraph legibility for an out-of-lock opposing hero stays sound-only. Whether that
  is adequate warning under the Legibility Principle's <0.5s visual-read assumption is a NAMED
  PLAYTEST QUESTION (`DP/R1`(ii), `CC/R1`(ii)) — not resolved or built around in this story.
- No free camera and no camera-rotation input route is added or revived; `InputIntent.aim`'s
  original free-rotation purpose stays superseded, not reintroduced in another form.
- `TargetingService` (`src/state/targeting/targeting_service.gd`) — the minion-AI target-acquisition
  evaluator — is a different system (which enemy a *minion* attacks) and is not reused, extended,
  or touched by the player's lock-on target selection built here.
- No change to `data/camera_config.tres` framing values (distance/height/pitch) or to the
  load-once, non-hot-reloaded loading pattern in `camera_rig.gd:26-27`.

## Dev Notes

- **Baseline measured for this story (repo, before any change):** HEAD
  `6cd6dd187824c211ae2ed804f8cd2276585cde55` == `origin/main`, clean tree. Determinism golden
  currently `a96b123e67ef8330b5bb07c1bafefaf5204e9bf9982eded936f8d69b29afa522`
  (`test/state/test_determinism.gd:608`) — the value AC 2 expects to change. Full-suite counts:
  run `bash test/run_all.sh` fresh at dev-pass start and record the actual numbers there; this
  story's own authoring pass did not need to re-run it (docs-only) but the dev pass MUST, per the
  golden-clause discipline every prior Tier A story in this epic has followed.
- **Facing is currently set in exactly one place**, `MatchState._resolve_movement`
  (`match_state.gd:2271`, the assignment at lines 2335-2336), zero-guarded on movement input. The
  target-derived replacement lives at the same seat or a sibling one under `src/state/` — this
  story does not relocate the movement seam itself, only what feeds `facing`.
- **`_roll_world_direction`** (`match_state.gd:1063-1065`) falls back to `hero.facing` when the
  stick is neutral at roll entry. Once `facing` is target-derived this fallback direction changes
  meaning (roll defaults toward/away from the lock target rather than the old input-derived
  heading) — worth a dev-pass read, not a cited defect.
- **Camera-relative movement is a separate seam from facing** and this story does not touch it:
  `test_camera_relative.gd` exercises the per-slot camera BASIS feeding `_resolve_movement`'s
  `world_dir` (movement direction), not `facing`. The two are computed from the same `world_dir` in
  today's code (`match_state.gd:2329` velocity, `2336` facing) but AC 1 breaks that coupling for
  facing only — velocity keeps deriving from camera-relative input, facing switches to
  target-relative. `test_camera_relative.gd`'s own assertions are about displacement, not facing,
  and are expected to stay green unchanged.
- **D3(b)/A2 boundary, confirmed not assumed (`CC/R5`):** target-derived facing needs the LOCKED
  TARGET'S POSITION each tick. Position is actor-owned (`hero.gd`'s own header: "position is
  actor-owned, F1"; `src/state/` holds no world coordinates) — so the target's position cannot be a
  live scene/camera query made from inside `src/state/`. The mechanism for getting a
  position-derived direction into `src/state/` without violating D3(b)/A2 (an injected per-tick
  fact, pushed the way the camera basis or contact facts are, vs. some other shape) is dev-pass
  terrain, not decided here.
- **`GamepadProfile` today** (`data/gamepad_profile.tres`, `src/controllers/gamepad_profile.gd:24-39`):
  `move_axis_x`/`move_axis_y` (left stick only), `attack_button`, `block_button`, `roll_button`,
  `deadzone`, `normalize_move_magnitude`. No right-stick axis field and no stick-click/button field
  exist today — both are new authored data, not a rename or widening of an existing field.
- **`InputIntent` today** (`src/state/input/input_intent.gd`): `move_dir`, `aim`, `pressed`/`held`
  dictionaries (prefix-free action names), `debug_reset`, and the three card-half fields
  (`card_slot`, `card_mode`, `card_commit`). `aim` (line 20) is the field `DP/R1`'s free-rotation
  route was named against and that `CC/R2` supersedes; no lock/retarget field exists yet.
- **`RecordFile.FORMAT_VERSION` history** (`record_file.gd:131`, currently 5): every prior bump was
  a shape-only change with hard rejection of older records, no migration shim (`4-3a/R10`,
  `4-3b/R21`, `4-4/R15`) — the same discipline applies here if a retarget result needs a new
  recorded element.
- **F1 confirmed:** `match_runner.gd:1798` is the sole `_physics_process` in `src/` (grepped; every
  other file's header explicitly disclaims one). A camera-rig or lock-on presentation node must not
  add a second.
- **Camera rig / config, unaffected:** `camera_rig.gd` loads `data/camera_config.tres` once in
  `_ready()` (line 27); the rig's local basis is what `match_runner.gd` reads and pushes into
  per-slot camera state (`test_root_rotation_isolation.gd`'s own header: reading the LOCAL, not
  global, basis is DECISION A's enforcement point). Lock-on facing does not change camera framing
  or this load-once pattern.

### Project Structure Notes

- New lock-on/retarget code follows the existing per-layer split: pure target-selection state (if
  any lives in `src/state/`) beside `hero_state.gd`/`match_state.gd`; screen-space candidate
  resolution (presentation) under `src/controllers/` or a new presentation-side helper, never under
  `src/state/`; new `GamepadProfile` fields stay on the existing resource script
  (`src/controllers/gamepad_profile.gd`). No new top-level folder is implied by anything measured
  above.

### Project Context Rules

- F1: exactly one `func _physics_process` in `src/`, in `match_runner.gd` (confirmed above) — a
  camera/retarget presentation node must not add a second.
- D3(a): `Input.*` only under `src/controllers/` — the new right-stick axes and stick-click read
  through `GamepadController` alongside the existing device-filtered reads, never a new Input Map
  action (`2-2` precedent).
- D3(b)/A2: no global RNG / `Time` / `OS` / `Engine`, and no live scene/camera query, inside
  `src/state/` — target-derived facing must be computed from an injected per-tick fact, confirmed
  at the dev pass per `CC/R5`, not assumed here.
- Docs and code never share a commit; commit messages are pure ASCII via `git commit -F`; shell is
  PowerShell 5.1 (no `&&`); trailer `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Story tier: Tier A, by the golden clause — `HeroState.facing` ownership migrates from input- to
  target-derived, golden and snapshot WILL move (`epics.md` E4 committed-obligations bullet,
  `CC` session close-out). Full gate + review + live smoke ritual; live smokes run primarily on
  controller from here forward (`CC/R4`).

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md, `DP/R1`
  (Session 2026-07-31)] — original always-locked-camera decision, the two open sub-questions (facing
  ownership, off-frame handling) this story's ACs resolve.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md, `E4-P/R11`
  (Session 2026-08-07)] — camera/lock-on named OUT of E4 with the board-full-of-minions
  forcing-point note that licenses this story's adoption.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md, `CC/R1`-`CC/R6`
  (Session 2026-08-30, "gds-correct-course: camera/lock-on adopted into E4")] — this story's
  controlling rulings: FULL variant, always lock-on with opposing-hero fallback, controls, live
  smoke platform, delegated mechanism direction, board mechanics.
- [Source: docs/planning-artifacts/sprint-change-proposal-2026-08-30.md] — adoption rationale,
  impact analysis, and the D3(b)/A2 confirmation flagged for this story's own readiness gate.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md, E4 committed-obligations
  bullet] — Tier A declaration and board ordering (before `4-5-pooling-60fps-exit`).
- [Source: src/state/hero_state.gd:83-92, 450] — `facing` field contract, snapshot inclusion.
- [Source: src/state/match_state.gd:2271-2336] — `_resolve_movement`, current input-derived facing
  assignment.
- [Source: src/state/match_state.gd:1630-1632, src/state/resources/balance_config.gd:261] —
  `_is_facing` / `block_facing_arc_degrees` consumption at contact resolution.
- [Source: src/actors/hero/hero.gd:31-48] — single-yaw-source contract (`1-7b`), `drive()`.
- [Source: test/integration/test_root_rotation_isolation.gd] — DECISION A guard.
- [Source: test/integration/test_camera_relative.gd] — camera-relative movement assertions, unaffected
  by this story.
- [Source: src/actors/hero/camera_rig.gd, data/camera_config.tres] — load-once camera framing,
  unaffected.
- [Source: src/controllers/gamepad_profile.gd, data/gamepad_profile.tres] — current authored fields
  (no right-stick/click fields exist yet); `src/controllers/gamepad_controller.gd` — device-filtered
  read pattern new fields follow.
- [Source: src/state/input/input_intent.gd] — current intent shape, `aim` field being superseded.
- [Source: src/systems/record_file.gd:131, test/state/test_record_file.gd:139] — `FORMAT_VERSION`
  history and pin.
- [Source: src/state/targeting/targeting_service.gd] — the distinct minion-AI targeting evaluator,
  named to rule out reuse.

## Open Questions

- **Where the lock target lives in state**, and its snapshot field shape (e.g. a `[slot, index]`
  pair on `PlayerState`/`HeroState`, or elsewhere) — dev-pass call, confirmed against D3(b)/A2 and
  the determinism snapshot contract.
- **How target-derived facing is computed from an injected fact without a live camera/scene query
  inside `src/state/`** — `CC/R5` names this as the story's own readiness-gate question; the shape
  of the injected fact (a direction vector, a position, something else) is not decided here.
- **What happens to `InputIntent.aim`** — repurposed for the retarget result, replaced by new
  field(s), or left present-but-unused now that its original free-rotation purpose is superseded.
- **`RecordFile.FORMAT_VERSION` bump** — whether the retarget-result shape needs a new recorded
  element (bump required) or fits inside existing channels (no bump), per AC 12.
- **`_roll_world_direction`'s neutral-stick fallback** — whether rolling toward/away from the lock
  target (the new meaning of `hero.facing` at roll entry) needs a ruling of its own or is accepted
  as a natural consequence of AC 1.
- **Keyboard binding proposal for click/flick** — AC 11 asks for one; the exact keys are a dev-pass
  proposal, not fixed here.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5), story authored via `gds-create-story`.

### Debug Log References

### Completion Notes List

### File List
