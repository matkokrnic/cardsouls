---
baseline_commit: 6cd6dd187824c211ae2ed804f8cd2276585cde55
---

# Story 4.6: Camera Lock-On

Status: review

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
    primary and carries the live smokes (`CC/R4`). Same item as Open Question 5; not filed twice as
    a behavior claim.
14. `RecordFile.FORMAT_VERSION` (currently 5, `record_file.gd:131`, pinned by
    `test_record_file.gd:139`) bump is DECIDED at dev time by a single measured fact: does the
    retarget result fit inside the existing `InputIntent`/recorded-fact channels? If yes, no bump
    (per the `4-3a/R10`/`4-3b/R21`/`4-4/R15` no-shim precedent, a fitting shape never bumps); if a new
    element is needed, bump to 6, hard-rejecting older records, no migration shim. Same item as Open
    Question 3; the measurement, not the outcome, is decided here.

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
  (`test/state/test_determinism.gd:608`) — the value AC 4 expects to change. Full-suite counts:
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
Claude Opus 5 (claude-opus-5), dev pass via `gds-dev-story` (2026-08-30).

### Debug Log References

Full dev-pass log: `C:\dev\_46-dev.md` (preconditions, both full-suite runs, the golden
measurement ladder with every intermediate hash, the AC 7 re-examination, and the mutation table
reproduced below).

### Open Question decisions (dev-pass calls)

**OQ 1 - where the lock lives, and the injected fact's SHAPE.** Three shapes, each copied from an
already-shipped sibling rather than invented:

1. The lock TARGET is `PlayerState.lock_target_slot` / `lock_target_index`, two plain ints,
   surfacing as ONE snapshot key `lock_target` holding a `[slot, index]` pair - the `unit_targets`
   shape verbatim, and `4-2/R2`'s counts-and-indices rule intact. HASHED, not excluded: it crosses
   ticks and decides where the hero faces, which decides the `_is_facing` arc (`4-3a/R17`).
   Two ints rather than a pair for `UnitBoard`'s own reason (the read is per-tick and a pair
   allocates); the opposing-slot default is seeded by `MatchState`, which is the only place that
   knows a `PlayerState`'s index.
2. The injected DIRECTION fact is a world-space planar `Vector2` per slot, pushed through
   `MatchState.set_lock_direction(slot, dir)` - the `set_camera_basis` shape verbatim, which is
   what `4-6/R6` mandates. `Vector2.ZERO` means NO FACT and leaves facing at its last value: the
   direct analogue of the identity-basis short-circuit. UNHASHED and captured by its own record
   channel, exactly as `_camera_bases` is.
3. The retarget REQUEST rides `InputIntent` as `retarget_slot` / `retarget_index`, with
   `retarget_slot == NO_RETARGET` (-1) meaning no request - the `card_slot == -1` shape verbatim.

**OQ 2 - `InputIntent.aim`.** DELETED, not repurposed and not left present-but-unused. `DP/R1`'s
"repurposed, still flowing through `aim`" lean was read against and rejected on a measured fact
(see OQ 3), not on taste. A field kept alive for a purpose that no longer exists is rot; a
repurposed one is a lie about its own name.

**OQ 3 / AC 14 - `RecordFile.FORMAT_VERSION`.** MEASURED: the retarget result does NOT fit the
existing channels. **BUMPED 5 -> 6**, hard rejection of older records, no migration shim
(`4-3a/R10` / `4-3b/R21` / `4-4/R15`). The measurement, in three findings:

1. The occupied intent channels are `move_dir`, `pressed`/`held`, `debug_reset` and the three card
   fields. The only free one was `aim`.
2. `aim` is a `Vector2` and a `[slot, index]` address is two small ints, so it fits DIMENSIONALLY -
   and fails on the SENTINEL: `Vector2.ZERO`, `aim`'s resting value, is the legal address `[0, 0]`
   (slot 0's unit 0). There is no "no retarget" value inside the field's current value space.
3. So the resting value would have to move, and then every v5 record on disk decodes its resting
   `aim` as a live retarget - a replay that silently diverges from the match it claims to
   reproduce, which is the exact failure `record_file.gd`'s header says the version check exists to
   refuse.

The one bump carries three shape changes at once, which is free: `aim` deleted, the retarget pair
added, and the new per-tick `lock_pushes` channel beside `camera_pushes`.

**OQ 4 - the roll's neutral-stick fallback.** NOT a dev-pass call: **operator ruling `4-6/R7`**,
applied verbatim (see the decision log). One operator, one line.

**OQ 5 / AC 13 - the keyboard binding PROPOSAL** (a documentation deliverable by AC 13's own
wording, deliberately NOT implemented):

| action | P1 | P2 |
|--------|----|----|
| re-lock onto the opposing hero (the R3 click) | `Q` | `Numpad 0` |
| retarget flick LEFT / RIGHT | `Z` / `C` | `Numpad 1` / `Numpad 3` |

Not built, for two reasons that pull the same way: AC 13 files it as a proposal rather than a
behaviour claim, and new Input Map actions are `project.godot` edits - a board surface, not
dev-pass terrain. Controller stays primary and carries the live smokes (`CC/R4`). A keyboard slot
is never left without a target: `CC/R2`'s always-on default lock holds, so what a keyboard player
lacks is RETARGETING, not lock-on.

### Golden re-baseline - FOUR causes, measured separately and in order

`a96b123e` -> **`aa3566d7`**. Method: the 4-3b REVERSE-DIRECTION staging - one thing held off the
fully-shipped tree at a time, both staged files backed up out of repo and SHA256-verified
byte-identical after restoration.

| # | cause | staged how | hash |
|---|-------|-----------|------|
| 0 | inherited (4-4 review fix pass) | - | `a96b123e...` |
| 1 | AC 4(a) FACING OWNERSHIP, behaviour half | `lock_target` held off the snapshot AND the `4-6/R7` sign held off `_roll_world_direction` | `cd21eac5a93f6772275d1ebc18603807fc0a83db385ffbf691270900bd4a3a76` |
| 2 | AC 4(a) FACING OWNERSHIP, shape half (`lock_target`; key set 27 -> 28) | key restored | `9a71e68abc4d8697b6c6ce0c8d44c9410628f6e6b0e8f7ee25a0f342af66d122` |
| 3 | `4-6/R7` NEUTRAL-STICK BACKSTEP | sign restored | **`aa3566d7077c07cc90630d155924b620cf5c54e14e6d0f3809d154d31ded7e4f`** |
| 4 | AC 4(b) LIVE CAMERA BASIS | - | **NON-MOVER, measured and structural** |

AC 4 names causes (a) and (b); `4-6/R7` adds the third. Cause (a) is SPLIT into behaviour and shape
because this project's standing discipline separates a snapshot-shape mover from a behavioural one
(4-1, 4-2 and 4-4 all did), and fusing them would have made the pair unattributable.

Cause 4's non-move is structural rather than lucky: the state harness instantiates no scene, so
there is no rig to yaw, and `test_determinism.gd` calls `set_camera_basis` ZERO times (grepped) -
every tick resolves through the identity short-circuit exactly as it always has. Cause (b) is real
and it LANDED, but on the INTEGRATION suite (see AC 7 below), not on this hash. Causes 1-3 fully
explain the final value, and NO UNEXPECTED MOVE occurred at any rung.

`4-6/R7`'s measure-it-either-way clause is discharged in the affirmative: a golden-fixture tick
DOES roll with a neutral stick - t17, whose move pair is `MOVES[16 % 6] = (0, 0)` - so the
inversion is a real third cause. `roll_direction` moves `(-1, 0, 0)` -> `(-0.6, 0, -0.8)` on the
hashed record.

**Snapshot key set: 27 -> 28**, one key (`lock_target`). `UNHASHED_CROSS_TICK_MEMBERS` STAYS AT
THREE: `_lock_directions` joins argument (c) beside `_camera_bases` - the same argument now
covering two pushed spatial arrays, the 4-4 "both hashed, count stays at three" discipline - and it
ships with its own falsifying drop test.

### AC 7: the two named files were RE-EXAMINED, and both needed rewriting

Both were falsified by the live yaw. This is AC 4 cause (b) landing.

- **`test_camera_relative.gd`** staged rig rotations in `_initialize()`. That is no longer
  possible: the runner overwrites the rig yaw every tick, so a staged value is gone before the
  first measurement. THE DRIVER REPLACED THE FIXTURE - each rig now looks at its own locked target,
  and with P1 at x -3 and P2 at x +3 the expected signs are the exact INVERSE of the pre-4-6 ones
  (P1 -> +X, P2 -> -X). What the file proves is unchanged, and is now proved against the shipping
  path rather than a test-only one. Measured: P1 dx +2.500, P2 dx -2.500, both dz 0.000.
- **`test_root_rotation_isolation.gd`** - DECISION A comes through STRONGER. The runner writes the
  lock yaw into the rig's LOCAL rotation, which is precisely what keeps the pushed LOCAL basis
  correct under a (forbidden) rotated root. The expected displacement moves from "world -Z" to
  "world +X, the direction of P1's locked target"; the property - a 60-degree ROOT yaw must not
  rotate that - is untouched, and the test is sharper, because a global-basis read now produces a
  bigger wrong answer against the same tight band. Measured: dx +2.500, dz 0.000.

Six further live fixtures moved for the same cause, each a fixture update and not a defect:
`test_visible_facing.gd` (expected yaw now derived live from the locked target; a `LOCK_YAW_EPS` of
0.05 covers the F1 one-tick lag, measured at 0.014 rad, while the mesh==hitbox pin stays at 0.001),
`test_hero_movement.gd` (velocity AXIS -> velocity MAGNITUDE, which is what was always being
claimed), `test_roll_displacement.gd` (magnitudes plus a new `away_from_lock` assertion - it is now
the live proof of `4-6/R7`), and `test_step_pause.gd` / `test_unit_approach_live.gd` /
`test_unit_corpse_walkthrough_live.gd` (`p1_move_right` -> `p1_move_up`, because camera-forward is
world +X now; in `test_step_pause.gd` that also keeps the path a straight LINE, which matters
because the file compares four steps against four times a one-axis per-tick displacement and
camera-right ORBITS the target).

### Mutation-proof table

Provenance: every row **MEASURED** in this dev pass. Each mutation was applied to the shipped tree,
the affected suites run, and the file restored and SHA256-verified byte-identical.

| id | mutation | RED |
|----|----------|-----|
| M-A | facing write reverts to `world_dir` (input-derived) | `test_camera_basis` x2, `test_match_state`, `test_determinism` x3, `test_replay_identity` lock channel; integration `test_visible_facing` |
| M-B | re-add the movement zero-guard to the facing write | `test_camera_basis::test_facing_tracks_the_lock_with_no_movement_and_freezes_with_no_lock_fact` |
| M-C | drop the `-` in `_roll_world_direction` (`4-6/R7`) | `test_roll_iframes` backstep, `test_determinism` golden + iframe_negation; integration `test_roll_displacement` |
| M-D | delete the step-4b `_validate_lock` pair | `test_lock_on::test_a_locked_units_death_snaps_the_lock_to_the_opposing_hero_on_the_kill_tick` |
| M-F | rig yaw `atan2(-x,-y)` -> `atan2(x,y)` | integration `test_lock_on_live`, `test_camera_relative` (no state test goes red, and that is correct: the rig is presentation and the headless harness has no scene) |
| M-G | remove the resolver's proximity tie-break | `test_lock_on::test_the_flick_breaks_an_alignment_tie_on_screen_proximity` |
| M-H | remove the flick EDGE (fire while held) | `test_lock_on::test_the_flick_edge_fires_once_per_crossing` |
| M-I | remove the `lock_target` snapshot key | golden ladder cause 2 (`9a71e68a` -> `cd21eac5`) plus both key-set pins |
| M-J | remove the click's flick suppression | `test_lock_on::test_a_lock_click_suppresses_the_flick_it_would_have_produced` |

### Completion Notes List

- **All 14 ACs satisfied.** AC 13 is a documentation deliverable and is delivered as the OQ 5
  proposal above, by its own wording ("not a testable behavior claim").
- **Suite, both full runs.** Start: 548 state tests / 4270 assertions, 43 integration files. End:
  **565 state tests / 4370 assertions, 0 failed; 44 integration files, every one PASS.** Delta
  +17 tests, +100 assertions, +1 integration file.
- **PRE-EXISTING OPEN FINDING, not this story's.** `test/integration/test_unit_attack_live.gd`
  prints `RESULT: PASS` but intermittently also emits `ERROR: 1 resources still in use at exit`,
  which `run_all.sh` greps for - so the harness verdict line reads `SOME TESTS FAILED` while every
  assertion passes. MEASURED AT THE UNTOUCHED BASELINE before a byte was written: three consecutive
  isolated runs, PASS/PASS/PASS, exit 0 every time, with the ERROR line present on run 2 only. A
  non-deterministic engine-shutdown resource-release warning. Reproduced identically at the end of
  the pass. Filed for the operator; not a regression and not a state or golden fact.
- **F1 / D3(a) / D3(b)/A2 all intact**, machine-checked by
  `test_architecture_invariants.gd`: no second `_physics_process` (the rig yaw is a value PUSHED
  into `CameraRig.face_lock_direction` from the runner's existing seat), `Input.*` stays inside
  `src/controllers/` (the right stick and R3 are device-filtered reads in `GamepadController`, no
  Input Map action - the `2-2` precedent), and `src/state/` performs no live scene or camera query:
  the lock direction arrives as a pushed per-tick fact through the `set_camera_basis` /
  `push_contact` seam family, exactly as `4-6/R6` confirmed.
- **AC 1's separate-write claim is machine-checked**, not merely asserted: `test_lock_on_live.gd`
  pins that the CHILD camera still carries the authored distance/height/pitch and stays pitch-only
  while the ROOT yaws every tick.
- **AC 11's replay claim rests on one line's SEAT**: `_resolve_retarget` runs IMMEDIATELY BEFORE
  `_recorder.capture_advance(intents)`, in the LIVE branch only, so the record carries the OUTCOME
  of a gesture and never the stick deflection - and a replay cannot re-resolve it, because
  `ReplayController` inherits the neutral accessors and the resolution is structurally inside the
  `else` of the replay fork.
- **AC 3's "same tick" cost a second seat**, and it is named as such rather than hidden:
  `_validate_lock` runs at step 1c AND at step 4b. Step 4 is the only seat that can kill a unit, so
  validating only at 1c would leave the hashed end-of-tick snapshot pointing at a corpse for
  exactly one tick - a one-tick corpse-hold window under another name. The function is idempotent
  by construction, which is what makes two call sites honest.
- **NAMED CONSEQUENCE, shipped with eyes open (AC 5, `DP/R1`(i))**: against the locked target the
  block arc can no longer be dodged by turning away, so block is pure timing. `_is_facing` and
  `block_facing_arc_degrees` are mechanically untouched; what changed is what feeds `facing`.
- **INHERITED TENSION, not resolved (AC 2's own wording)**: the DEAD early return and the
  round-over freeze still SKIP the facing write under the standing "a display-only field may be
  skipped" rule, which is now in tension with facing feeding `_is_facing`. Both branches also
  freeze everything that could act on it, so nothing observable rides on it today. Carried, named
  in `match_state.gd` at the write itself, and left for the story that owns the round lifecycle.
- **One new `class_name`**: `LockOnResolver` (`src/main/lock_on_resolver.gd`), a pure static helper
  beside the runner, sanctioned by this story's Project Structure Notes. Editor scan run in-pass;
  `project.godot` SHA256 unchanged before and after (no collateral). It is NOT `TargetingService`
  and reuses none of its evaluator - only the runner borrows that file's `HERO_INDEX` address
  convention, which the Non-Goals explicitly permit.
- **Not done, by scope**: the keyboard bindings (AC 13, proposal only), off-screen telegraph
  legibility (Non-Goal, a named playtest question), and the LIVE SMOKE ritual, which is the
  operator's - `CC/R4` puts it on the controller, and this pass has no pad.

### File List

**Source (11 modified, 1 added)**
- `src/state/input/input_intent.gd`
- `src/state/player_state.gd`
- `src/state/match_state.gd`
- `src/main/match_runner.gd`
- `src/main/lock_on_resolver.gd` *(added)*
- `src/actors/hero/camera_rig.gd`
- `src/controllers/controller.gd`
- `src/controllers/gamepad_controller.gd`
- `src/controllers/gamepad_profile.gd`
- `src/systems/intent_recorder.gd`
- `src/systems/record_file.gd`
- `data/gamepad_profile.tres`

**Tests (15 modified, 2 added)**
- `test/state/test_lock_on.gd` *(added)*
- `test/integration/test_lock_on_live.gd` *(added)*
- `test/state/test_camera_basis.gd`
- `test/state/test_card_observation.gd`
- `test/state/test_contact_resolution.gd`
- `test/state/test_determinism.gd`
- `test/state/test_draw_delay_and_reshuffle.gd`
- `test/state/test_intent_recorder.gd`
- `test/state/test_live_reload.gd`
- `test/state/test_match_state.gd`
- `test/state/test_record_file.gd`
- `test/state/test_replay_identity.gd`
- `test/state/test_roll_iframes.gd`
- `test/integration/test_camera_relative.gd`
- `test/integration/test_hero_movement.gd`
- `test/integration/test_replay_verifier_tool.gd`
- `test/integration/test_roll_displacement.gd`
- `test/integration/test_root_rotation_isolation.gd`
- `test/integration/test_step_pause.gd`
- `test/integration/test_unit_approach_live.gd`
- `test/integration/test_unit_corpse_walkthrough_live.gd`
- `test/integration/test_visible_facing.gd`

## Change Log

| date | change |
|------|--------|
| 2026-08-30 | Dev pass via `gds-dev-story`. All 14 ACs implemented; operator ruling `4-6/R7` applied; Open Questions 1, 2, 3 and 5 decided and recorded above. Golden re-baselined `a96b123e` -> `aa3566d7` across FOUR separately measured causes (three movers, one measured non-mover). `RecordFile.FORMAT_VERSION` 5 -> 6. Snapshot key set 27 -> 28. Suite 548 -> 565 state tests, 43 -> 44 integration files, all green. Status -> `review`. |
