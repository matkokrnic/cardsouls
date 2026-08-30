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

**Camera framing (FULL variant, camera half, `4-6/R1`)**

1. Each slot's camera rig ROOT (`src/actors/hero/camera_rig.gd`) yaws every tick to keep that
   slot's own hero and its locked target framed, driven by the same lock-on target used for facing
   (AC 2). Authored framing values (distance/height/pitch, `data/camera_config.tres`) and the
   load-once pattern (`camera_rig.gd:26-27`) are UNCHANGED: `apply_config()` continues to write only
   the CHILD camera's `position`/`rotation_degrees`; the new per-tick yaw is a separate write, to the
   rig root, not the child. No second `_physics_process` is added (F1) — the yaw update lands at the
   runner's existing per-tick seat (`match_runner.gd:1798`), beside the existing basis push at
   `match_runner.gd:1857-1860`.

**Facing ownership (FULL variant, `CC/R1`(i))**

2. `HeroState.facing` (`src/state/hero_state.gd:87`, world-space planar `Vector2`, snapshot field
   at `to_snapshot()` line 450) is driven from the locked target's position, not from movement
   input. It is set unconditionally every tick a target is locked (no zero-guard on movement, the
   opposite of today's `if not dir.is_zero_approx(): player.hero.facing = ...` at
   `match_state.gd:2335-2336`), so a hero can strafe or stand still while always facing the target —
   EXCEPT on two existing branches, which keep their current facing-skip behavior unchanged: the
   DEAD early return (`match_state.gd:2272-2282`, `2-3/R14`) and the round-over step-1b freeze
   (`match_state.gd:255-258`, `2-6/R6`). On both, facing is left at its last value, per the existing
   "a display-only field may be skipped" rule; whether that classification still holds now that
   facing feeds `_is_facing` is a pre-existing tension this story inherits, not resolves (Dev Notes).
   The default/fallback target is always the opposing hero (`CC/R2`) — there is no unlocked state.
3. Locked-target death resolves as follows (`4-6/R4`, `4-6/R5`): when the locked target is a minion
   or totem and it dies, the lock snaps IMMEDIATELY, same tick, to the opposing hero — no
   corpse-hold window, despite the corpse lingering on the board for several ticks post-`4-3d`
   (`test_unit_corpse_linger_live.gd`). When the opposing hero itself is dead, the round is already
   over and the step-1b freeze (AC 2's carve-out) makes target resolution inert — nothing moves or
   turns on a frozen tick regardless of what the lock references.
4. The determinism golden (`test_determinism.gd:608`,
   `a96b123e67ef8330b5bb07c1bafefaf5204e9bf9982eded936f8d69b29afa522`) and the snapshot key set are
   expected to move for TWO SEPARATELY MEASURED CAUSES, each confirmed and re-baselined in isolation
   per the `4-3a/R17`/`4-4` AC 12 multi-cause precedent (`4-6/R2`): (a) facing ownership migrating
   from input- to target-derived (this story's own cause, AC 2); (b) the rig's new per-tick yaw
   (AC 1) making the pushed camera basis (`match_runner.gd:1857-1860` -> `MatchState.set_camera_basis`
   -> `match_state.gd:2292-2296`) non-identity in live play for the first time, which changes
   `world_dir` and therefore the HASHED `HeroState.velocity` (`match_state.gd:2329`) — the divergence
   `3-0c/R2` predicted. Both accepted consequences, not defects (`DP/R1`(i), `CC/R1`).
5. `_is_facing` (`match_state.gd:1630-1632`) and `block_facing_arc_degrees`
   (`balance_config.gd:261`) keep their existing mechanism unchanged — target-derived facing feeds
   the same gate. Named consequence, accepted with eyes open: against the locked target the arc can
   no longer be dodged by turning away, so block becomes pure timing (Sekiro-style); orientation as
   a defensive dimension migrates into target *selection* instead (`DP/R1`(i)).
6. The single-yaw-source contract at `hero.gd:31-42` (one `atan2(hero_state.facing.x,
   hero_state.facing.y)`, assigned to both `hitbox.rotation.y` and `mesh.rotation.y`) is preserved
   — target-derived facing still reaches the actor through the existing `facing` field and the
   existing one yaw computation. No second yaw site is added.
7. DECISION A (`test_root_rotation_isolation.gd`) is unaffected for the FACING half: the hero root
   still never rotates; target-derived facing rotates the same child nodes (Hitbox, Mesh) the
   input-derived facing rotated, through the same field. The rig-yaw half (AC 1) is a separate
   concern: `test_camera_relative.gd` and `test_root_rotation_isolation.gd` both currently assume a
   fixed or only-programmatically-rotated rig (their own file headers) and are RE-EXAMINED, not
   merely re-run, by the dev pass against the new live yaw driver — whether their fixtures need
   updating is dev-pass terrain, but that re-examination is required (not assumed clean) is locked
   here (`4-6/R2`).

**Lock/retarget controls (`CC/R2`, `CC/R3`)**

8. The `InputIntent.aim` field (`input_intent.gd:20`) is retired from the free-rotation route named
   at the 1-2 gate — that route is SUPERSEDED, not supplemented, per `DP/R1`'s own wording and
   `CC/R2`. Whether `aim` is repurposed, replaced, or left unused is dev-pass terrain (Open
   Questions).
9. Right-stick CLICK instantly re-locks onto the opposing hero, regardless of current target
   (`CC/R3`). This is the only way to resolve an off-screen opposing hero back into lock.
10. Right-stick FLICK switches lock to the best on-screen candidate in that screen-space direction,
    among minions, totems, and the opposing hero (`CC/R3`). No unlock state exists at any point —
    a flick with no on-screen candidate in that direction is a no-op (target unchanged).
11. Retarget resolution follows the contact-fact precedent (`1-8`/`4-1` `R7` lineage, `CC/R5`):
    screen-space candidate resolution happens in presentation, outside `src/state/`; the RESULT (a
    `[slot, index]` unit/hero address, using the `4-3a/R16`-lineage convention whose home is
    `TargetingService.HERO_INDEX` — `index == -1` means that slot's hero) is pushed into the intent
    stream as an input fact. Replay records the outcome of a flick/click, never the raw stick
    deflection.
12. `GamepadProfile` (`src/controllers/gamepad_profile.gd`, `data/gamepad_profile.tres`) gains new
    authored fields for the right-stick axes and the stick-click button, following the existing
    `move_axis_x`/`move_axis_y`/`*_button` pattern (named `JoyAxis`/`JoyButton` exports, not raw
    ints) — today's file has no right-stick or stick-click field at all (measured: `gamepad_profile.gd`
    lines 24-28 cover only the left stick and three face/shoulder buttons; line 29 is `deadzone`).
    `GamepadController` (`src/controllers/gamepad_controller.gd`) reads them the same device-filtered
    way it already reads `move_axis_x`/`_y` and the three buttons (`2-2` precedent — no Input Map
    action).
13. A keyboard binding is PROPOSED (documentation deliverable, not a testable behavior claim) for
    click/flick equivalents, consistent with keyboard parity elsewhere (`2-2/R5`); controller is
    primary and carries the live smokes (`CC/R4`). Same item as Open Question 6; not filed twice as
    a behavior claim.
14. `RecordFile.FORMAT_VERSION` (currently 5, `record_file.gd:131`, pinned by
    `test_record_file.gd:139`) bump is DECIDED at dev time by a single measured fact: does the
    retarget result fit inside the existing `InputIntent`/recorded-fact channels? If yes, no bump
    (per the `4-3a/R10`/`4-3b/R21`/`4-4/R15` no-shim precedent, a fitting shape never bumps); if a new
    element is needed, bump to 6, hard-rejecting older records, no migration shim. Same item as Open
    Question 4; the measurement, not the outcome, is decided here.

## Non-Goals

- Off-screen telegraph legibility for an out-of-lock opposing hero stays sound-only. Whether that
  is adequate warning under the Legibility Principle's <0.5s visual-read assumption is a NAMED
  PLAYTEST QUESTION (`DP/R1`(ii), `CC/R1`(ii)) — not resolved or built around in this story.
- No free camera and no camera-rotation input route is added or revived; `InputIntent.aim`'s
  original free-rotation purpose stays superseded, not reintroduced in another form.
- `TargetingService`'s EVALUATOR (`src/state/targeting/targeting_service.gd`, `target_for(...)`) —
  the minion-AI target-acquisition algorithm — is a different system (which enemy a *minion*
  attacks) and is not reused, extended, or touched by the player's lock-on target selection built
  here. Referencing the same file's `HERO_INDEX` address convention (AC 11) is not reuse of the
  evaluator.
- No change to the AUTHORED FRAMING VALUES (distance/height/pitch, `data/camera_config.tres`) or to
  the load-once, non-hot-reloaded loading pattern in `camera_rig.gd:26-27` — both are the CHILD
  camera's concern (`apply_config()`, lines 36-37) and stay untouched. This does not exempt the rig
  ROOT: AC 1's per-tick yaw lives there, on a separate write path (`4-6/R1`).

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
- **Camera-relative MOVEMENT is a separate seam from facing, at the `world_dir` split.**
  `_resolve_movement` computes velocity and facing from the same `world_dir` today
  (`match_state.gd:2329` velocity, `2336` facing); AC 2 breaks that coupling for facing only —
  velocity keeps deriving from camera-relative input via `_camera_bases[slot]`, facing switches to
  target-relative. What this note previously called "camera-relative movement... this story does
  not touch it" was true only for the movement HALF; AC 1's rig yaw touches the BASIS that same
  movement reads (see AC 4's second cause), so `test_camera_relative.gd`'s displacement assertions
  are re-examined by the dev pass under AC 7, not assumed unaffected.
- **CORRECTED (was: "Camera rig / config, unaffected"; falsified by `4-6/R1`, gate B1):** the rig
  root gains a per-tick lock-on yaw (AC 1). What stays true from the original note: the CHILD
  camera's `apply_config()` load-once path (`camera_rig.gd:26-27`, lines 36-37) is untouched, and
  DECISION A's LOCAL-basis reading point (`test_root_rotation_isolation.gd`) still applies to
  whatever the rig's local basis ends up being — it is just no longer always identity in live play.
- **`camera_rig.gd`'s own header is now stale** (D3(a) route sentence: "When a later story adds a
  look action it MUST flow controller -> `InputIntent.aim` -> runner -> rig") — AC 8 retires that
  route. Corrected in the same pass the header goes stale, per `4-3a/R15` precedent.
- **D3(b)/A2 boundary, CONFIRMED at this gate (`CC/R5`, `4-6/R6`):** target-derived facing needs the
  LOCKED TARGET'S DIRECTION each tick. Position is actor-owned (`hero.gd`'s own header: "position is
  actor-owned, F1"; `src/state/` holds no world coordinates — grepped, its four `position` hits are
  unrelated error strings and a loop variable) — so the target's position cannot be a live
  scene/camera query made from inside `src/state/`. CONFIRMED MECHANISM: a per-tick lock-direction
  fact, pushed into `src/state/` through the same seam family as `set_camera_basis` (AC 1's basis)
  and `push_contact` — never a live query. Precedent already shipped: `_is_facing(hero,
  target_to_attacker)` (`match_state.gd:1630-1632`) already consumes a runner-gathered `Vector2`
  direction fact this exact way (call site `match_state.gd:1199`). OPEN, NOT DECIDED HERE: the
  exact fact SHAPE (direction vector vs. position; which struct/field carries it) — Open Question 1.
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
  `src/state/` — target-derived facing is computed from an injected per-tick direction fact, pushed
  through the `set_camera_basis`/`push_contact` seam family, CONFIRMED at this gate (`4-6/R6`); only
  the fact's exact shape is dev-pass terrain (Open Question 1).
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
- [Source: test/integration/test_camera_relative.gd] — camera-relative movement assertions,
  re-examined under AC 7.
- [Source: src/actors/hero/camera_rig.gd, data/camera_config.tres] — rig yaw driver (AC 1); load-once
  framing on the child camera stays unaffected.
- [Source: src/controllers/gamepad_profile.gd, data/gamepad_profile.tres] — current authored fields
  (no right-stick/click fields exist yet); `src/controllers/gamepad_controller.gd` — device-filtered
  read pattern new fields follow.
- [Source: src/state/input/input_intent.gd] — current intent shape, `aim` field being superseded.
- [Source: src/systems/record_file.gd:131, test/state/test_record_file.gd:139] — `FORMAT_VERSION`
  history and pin.
- [Source: src/state/targeting/targeting_service.gd] — the distinct minion-AI targeting evaluator,
  named to rule out reuse.

## Open Questions

1. **Where the lock target lives in state, and the injected direction fact's exact shape**
   (`[slot, index]` pair vs. a resolved direction vector; which struct/field on `PlayerState`/
   `HeroState` or a sibling) — dev-pass call, confirmed against D3(b)/A2 (boundary MECHANISM is
   settled, `4-6/R6`) and the determinism snapshot contract.
2. **What happens to `InputIntent.aim`** — repurposed for the retarget result, replaced by new
   field(s), or left present-but-unused now that its original free-rotation purpose is superseded.
   `DP/R1`'s own text (decision-log:1029-1031) leans "repurposed, still flowing through `aim`" —
   read against that before deciding, not a hard ruling.
3. **`RecordFile.FORMAT_VERSION` bump** — same measurement as AC 14; recorded here only to avoid a
   second open item, not a second decision.
4. **`_roll_world_direction`'s neutral-stick fallback** (`match_state.gd:1063-1065`) — rolling
   toward/away from the lock target is a NEW PLAYER-FACING BEHAVIOR once `facing` is target-derived,
   not an implementation detail (CLAUDE.md: changes to what the game IS are design, not dev-pass,
   decisions). **This is the operator's call, to be made before or during the dev pass — not a
   default the dev pass may assume.**
5. **Keyboard binding proposal for click/flick** — same item as AC 13; recorded here only to avoid a
   second open item, not a second decision. The exact keys are a dev-pass proposal.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5), story authored via `gds-create-story`.

### Debug Log References

### Completion Notes List

### File List
