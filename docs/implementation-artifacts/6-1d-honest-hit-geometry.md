---
baseline_commit: e50bc94705cfba8c5471731391806410f6e7a04e
---

# Story 6.1d: Honest Hit Geometry

Status: ready-for-dev

> **Scope note.** Not on the E6 board from planning — no correct-course run. Named successor to
> `6-1c` in that story's close-out (`6-1c/R10`, decision-log.md:9770-9776). Tier A: touches the
> single unblockable landing seat and the golden's reachability. Board key inserted at `6-1c`'s
> own close-out (already present at `docs/implementation-artifacts/sprint-status.yaml:118`,
> `backlog  # Tier A`, with a `story_notes` entry at line 133 — no insertion needed this pass).
> **Readiness gate, round 1:** NOT READY, four blockers, closed by rulings `6-1d/R1`-`R7`
> (decision-log.md:9806-9859). Re-gate round 2 CLOSED all four blockers, promoted to `ready-for-dev` 2026-09-12.

## Measured Facts

1. **A live, tick-fresh weapon anchor already exists — built for melee, not yet read by mode ②.**
   `HeroActor._track_weapon_bone()` (`src/actors/hero/hero.gd:107-111`) assigns
   `hitbox_shape.position` every tick from the paladin's `mixamorig_Sword_joint` pose, composed by
   forward kinematics off `Skeleton3D.get_bone_pose()` up the parent chain and expressed in the
   Hitbox's local frame via `to_local()` (story 5-0a). It runs inside `HeroActor.drive()`
   (`hero.gd:74`), called from `match_runner.gd:2638-2639`, step 4 of the tick (AFTER `advance()`).
   `Hitbox.global_position` (or `HitboxShape.global_position`) is therefore a live, per-tick blade
   anchor today — just never consulted by the mode ② landing path, which instead uses
   `hero.global_position - enemy.global_position` (root-to-root, `match_runner.gd:691`).

2. **The blade-anchor read shares the standard one-tick lag; no new lag class.**
   `_push_charge_reach_facts` sits in the SAME step-2, pre-`advance()` seat
   (`match_runner.gd:2505`) as `_gather_contact_facts`, whose own header states the existing
   contract: "Facts reflect tick N-1's physics flush — F1 one-tick lag, absorbed by the dedupe
   grace" (`match_runner.gd:1672`). A blade-anchor read joining that seat inherits the identical
   lag, nothing new. (The determinism question this fact used to argue — whether a live rig read
   survives replay — does not arise: see the Dev Note below, `6-1d/R7`. Replay never re-derives
   the pose at all.)

3. **Today's landing path, end to end, confirmed unchanged since `6-1c`'s close-out.**
   Runner: `_push_charge_reach_facts()` (`match_runner.gd:674-704`) computes
   `planar := hero.global_position - enemy.global_position` (root-to-root, XZ), a per-colour radius
   KIND (`balance.unblockable_reach_for(color)`, `INSIDE`/`OUTSIDE`), and the planar direction —
   never `HeroState.facing` — pushed through `push_contact` before `advance()`. State:
   `_resolve_charge_landing` (`match_state.gd:2936` on) gates on
   `_charge_reach[slot] == CONTACT_CHARGE_REACH_INSIDE and _is_in_charge_arc(...) and
   target.hero.is_alive()`, where `_is_in_charge_arc` (`match_state.gd:2105-2109`) compares the
   FROZEN `player.hero.facing` against `-_charge_reach_dirs[slot]` within
   `balance.unblockable_arc_degrees_for(color) * 0.5`. One gate, one ladder (colour-match negation →
   iframe dodge → full hit + orb grant), fires exactly once, on the tick `landing_window` closes.
   The 12 per-colour fields (`unblockable_reach_*`, `unblockable_arc_degrees_*`,
   `unblockable_launch_distance_*`, `unblockable_launch_seconds_*`) are confirmed present, unchanged,
   at `data/balance/balance_config.tres:128-139`. Enumerating every fact producer in the runner
   (melee `_gather_contact_facts` :1675, minion `_gather_unit_facts` :1782, projectile
   `_gather_projectile_facts` :1980, targeting-only `_push_reach_probe` :2106) confirms mode ② is
   the ONLY family that credits damage off an authored centre-to-centre radius rather than an
   overlap query — the justification for this story existing at all (`6-1d/R1`).

4. **The melee contact pipeline is a per-tick, dedupe-safe pattern already built — but gated shut
   for CHARGING.** `_gather_contact_facts()` (`match_runner.gd:1675-1733`) runs a direct
   `hitbox.get_overlapping_areas()` query every tick `hero.is_hitbox_active()` is true, stamps
   `attack_index` at gather time, identity- and side-filters, and pushes `CONTACT_STRIKE` facts.
   Resolution dedupes through `_register_attacker_hit` (`match_state.gd:1839-1845`) calling
   `hero.register_swing_hit(attack_index, target_slot, target_index)` (`hero_state.gd:291-300`) —
   one registration per `[attack_index, target]` pair, the exact "1-5 dedupe ladder" shape the
   prompt names. But `HeroState.is_hitbox_active()` (`hero_state.gd:228-229`) returns
   `active.is_running and action_state == ActionState.ATTACKING` — **CHARGING never satisfies it**,
   so this whole per-tick/dedupe machinery is currently silent for mode ②. **Correction
   (`6-1d/R1`, withdrawing this fact's earlier "no shared seat between attack families" framing):
   that framing conflated GATHER with RESOLUTION.** `6-1c/R3` and `1-8/R-B3` govern what crosses
   the seam (geometry in as a KIND), not who is allowed to measure it — nothing there forbids the
   landing path from sharing melee's overlap query. The residue that DOES stand: `is_hitbox_active()`
   is melee's own phase gate and must not grow a CHARGING branch, so the launch-phase query needs
   its own gate (`landing_window` running post-commit), not a shared boolean.

5. **No new "body radius" field is needed — the Hurtbox box IS the body geometry (`6-1d/R1`).**
   The hero's `Collision` and `HurtboxShape` (`hero.tscn:27-28, 67-68, 100-101`) share a
   `BoxShape3D size = Vector3(1, 2, 1)` — the same box `get_overlapping_areas()` already returns
   for melee's overlap query (Fact 1). A per-colour landing check that shares that query needs no
   derived inradius constant and no `SPAWN_CLEARANCE_RADIUS`-style analogy: it measures against the
   `Hurtbox`/`HurtboxShape`'s actual `Shape3D` at the seam, the same shape melee already trusts.

6. **P6 (`6-1c/R12`, decision-log.md:9786-9792) is ADOPTED this story (`6-1d/R4`), not deferred.**
   `_charge_launch_velocity` (`match_state.gd:3641-3648`) derives launch speed as
   `launch_distance / launch_seconds` (a *_seconds float read as a pure speed divisor, CONSTRAINT
   C), exact only because today's authored spans are tick-aligned; a non-tick-aligned retune could
   overshoot by construction. Delivering `6-1c/R10(b)`'s GREEN travel-profile requirement (AC 7)
   already rewrites this function, so the fix — deriving speed from the TICK span
   (`launch_ticks / TimingWindow.TICK_HZ`) instead — is adopted in the same edit rather than filed
   separately.

## Story

As the operator who watched max-reach unblockable hits register with a visible gap between the
paladin's blade and the defending model at `6-1c`'s live smoke,
I want the unblockable landing check to measure real contact — the tracked blade position against
the defender's actual body — instead of an authored centre-to-centre radius,
so that damage on the tricky-to-time unblockable attack never lands on daylight, and each colour's
authored reach/arc act only as a ceiling on an honest measurement, never a substitute for one.

## Acceptance Criteria

**Geometry decides contact.**

1. A mode ② landing (RED/BLUE/GREEN) credits damage only when the tracked blade anchor
   (`HitboxShape`/`Hitbox` world position, Fact 1) overlaps the defending hero's actual body
   geometry (Fact 5) at the tick the check runs — via the SAME overlap query melee already trusts,
   never from an authored centre-to-centre radius alone (`6-1d/R1`). A visible gap between the
   models at the moment damage lands is a defect this AC forbids.
2. The per-colour authored REACH and HOMING SPEED fields remain live as an UPPER BOUND only: a
   configuration reachable by geometry but outside the authored per-colour reach or homing speed is
   NOT a hit. Neither number is raised by this story (hard constraint, `6-1c/R10`; `6-1d/R5`
   narrows this AC to reach and homing speed — arc, launch distance, and launch seconds are EXEMPT,
   since AC 7 requires moving the latter two). This is proven by a TEST — a configuration
   geometrically reachable but outside the authored bound MISSES — not only by a diff against
   `data/balance/balance_config.tres:128-139`.
3. The runner computes the blade-anchor and body-geometry facts from POSITIONS ONLY — mirroring
   the `1-8/R-B3` shape (Fact 3) — and never reads `HeroState.facing`; the frozen committed
   direction (arc test) stays STATE policy, unchanged in ownership from `6-1c`.

**Contact is checked continuously, not once.**

4. Contact is evaluated on every tick from the charge→launch commit through the tick
   `landing_window` closes (Fact 4's per-tick pattern, adapted — not the melee gate itself), not
   only on the window-close tick. The contact window OPENS AT COMMIT and never earlier: an attack
   still in the feintable chargeup never credits damage, even though the blade is already visibly
   in motion there (`6-1d/R2`; measured at `6-1c`, commit-frame swing progress RED ~64%,
   BLUE ~49%, GREEN ~31%) — an attack the attacker can still cancel never credits damage.
5. Exactly one resolution occurs per swing per target regardless of how many ticks report contact
   — a dedupe shape keyed the same way melee's is (`[attack_index, target]`, Fact 4) — through the
   SAME single ladder `_resolve_charge_landing` already owns (colour-match negation → iframe dodge
   → full hit + orb grant, Fact 3). No second landing check and no ladder bypass.
6. **Supersedes `6-1c` AC 3, explicitly (`6-1d/R3`).** Continuous contact means a dodge after
   commit is no longer an automatic escape: the defender must clear the blade's geometric path for
   the WHOLE flight, not merely be outside an authored radius on the window-close tick. The
   surviving half of `6-1c`'s guarantee stands: a defender who clears the blade's path on EVERY
   tick the check runs produces a MISS. Checking every tick must not turn "dodge after commit" into
   "dodge only the very last tick" — but a defender who was touching the blade at ANY evaluated
   tick before dodging away is no longer guaranteed a miss (this is the behavioural change AC 3
   guaranteed against; it is deliberately no longer guaranteed here).
7. **GREEN's travel profile, delivering `6-1c/R10(b)` properly (`6-1d/R4`).** Continuous sampling
   (AC 4) changes WHEN a hit can be detected, not how far the hero travels — AC 4 alone does not
   deliver `6-1c/R10(b)`. This AC does: per-colour launch travel is redistributed into a
   front-loaded profile across the launch span (more distance covered early/mid-airborne, less
   lurching onto the landing tick), GREEN the named subject. `_charge_launch_velocity`
   (Fact 6, `match_state.gd:3641-3648`) is rewritten to derive launch speed from the TICK span
   (`launch_ticks / TimingWindow.TICK_HZ`) rather than `launch_distance / launch_seconds`, adopting
   P6 (Fact 6) in the same edit. **Halt condition:** if the chosen travel-profile mechanism would
   require a new hashed snapshot field or any change to `landing_window`'s tick contract, the dev
   pass HALTS here and defers `6-1c/R10(b)` rather than growing scope.
8. **Swing-at-commit knob (`6-1d/R6`).** A `BalanceConfig` field exists (chargeup → `[0, hold_end]`,
   launch → `[hold_end, 1]`); its default is OFF; OFF reproduces today's behaviour exactly. This AC
   claims only that the knob is BUILT and inert by default — the ON verdict is judged at Live
   Smoke item 6, not decided in this story.

**Determinism, resolution seat, and regressions.**

9. `PlayerState.landing_window`'s existing tick contract (`6-1b/R6`/`6-1c`) is unaffected: the
   per-tick geometry check consumes no new window and introduces no new synchronous exit edge
   beyond the one `_resolve_charge_landing` already fires on.
10. The commit-time facing freeze (`6-1c` AC 2/AC 7) and its DEAD/round-over carve-out ladder
    (Fact 3 lineage) are unedited by this story's mechanism.
11. The full suite passes (`bash test/run_all.sh`).

## Non-Goals

- Melee swings (the `1-7` hitbox/hurtbox path) keep their existing box-overlap contact — this
  story does not touch `_gather_contact_facts` or `is_hitbox_active()`. An explicit NON-GOAL,
  named so a later story can adopt the same honest-geometry idea for melee without re-deriving it.
- Minions, totems, projectiles: untouched (mode ② is hero-only, unchanged ruling).
- No VFX (still zero, `6-1c` Non-Goals carried forward).
- No new clips or attack shapes.
- D3 (launch distance/seconds audited as a pair), F-9 (`ORB_COLORS` guard), the retune block
  (dodge stamina cost, dodge/roll coverage): out and unowned, untouched.
- The swing-at-commit knob's BUILT-not-decided status moved to AC 8 (`6-1d/R6`) — it is checkable
  delivered software (field exists, default OFF, OFF reproduces today), not a Non-Goal.
- P6 (Fact 6) moved to AC 7 — ADOPTED this story (`6-1d/R4`), not a Non-Goal.

## Golden Prediction

**Measure both directions — this is not a substitute for the measurement.** (Moved here from the
AC list per `6-1d/R7`/N7: this is a process obligation this section owns, not a separate
acceptance claim.)

- The golden fixture has never cast mode ② and no hero in it has ever entered `CHARGING`
  (`test_determinism.gd:699-700`, restated unchanged through every unblockable story to date,
  including `6-1c`). This story's mechanism — a blade-anchor read, a per-tick contact check, a
  dedupe key for the landing — is unreachable by the golden sequence for the same reason.
- **Net prediction: golden hash `9679fa80f19358d15c9b33b1f9a3706264095ada871e5d2530cf29b6cbce8315`
  and the 31-key snapshot set (`test_card_observation.gd:310`) NOT TO MOVE**, inverse form —
  UNLESS the chosen mechanism adds a NEW hashed field (e.g. a per-swing dedupe counter distinct
  from `attack_index`, or a stored "already hit this swing" flag that does not already exist on
  `HeroState`/`PlayerState`). A new field is a snapshot-key mover regardless of golden reachability
  (`5-2`/`5-5`/`6-1c` shape) — name it as the single cause if it happens, never "geometry" or
  "presentation" by assumption. `register_swing_hit`'s existing dedupe storage (Fact 4) may already
  cover this with no new field; the dev pass measures which. Sharpening this: `swing_dedupe` is
  ALREADY a hashed snapshot key nested inside the hero snapshot (`hero_state.gd:463-466`), so
  extending an existing record with a landing entry moves no snapshot key — only a genuinely new
  TOP-LEVEL field would (N5).
- **Suite level that catches the new behaviour:** a new/extended headless suite (likely alongside
  `test_unblockable_tracking_and_reach.gd`, Fact 3) plus `test/integration/` for live blade-vs-body
  geometry, mirroring the `6-1c` split.
- `FORMAT_VERSION` (8, `record_file.gd:171`) predicted UNCHANGED — no new recorded input channel;
  a blade-anchor read is derived state, not a player input.

## Live Smoke

Single physical pad, flip `slot_controller_kinds = Array[int]([0, 3])` textually with the editor
CLOSED. **R-D6 collateral procedure re-invoked (SPENT, per-story per `6-1c/R4`):**
- Flip `[0, 3]` edited TEXTUALLY, editor closed.
- `git diff` immediately after adding the flip, and again immediately after removing it.
- After any editor session: `git diff -- project.godot`; revert collateral with
  `git checkout -- src/main/main.tscn project.godot` (both full paths) if the editor touched
  `project.godot`.
- Editor reload dialog: always "Reload from disk", never "Ignore external changes".
- Re-check `git status` + the collateral diff immediately before any commit chain begins.

Items:
1. No damage across a visible gap — the blade must be seen touching the model when damage lands
   (AC 1).
2. The blade passing visibly through the target DOES register (confirms the anchor read is live,
   not still the old centre-to-centre substitute).
3. A dodge during the swing (any point in the flight, not only right after commit) can clear the
   blade and produce a miss (AC 6).
4. The per-colour clamp still shortens reach where authored to (AC 2) — a max-authored-reach hit
   should not read as reaching further than before.
5. GREEN homing reads naturally across the flight, not only at the very end of the leap (AC 7).
6. The swing-at-commit knob: judged ON vs OFF by the operator, verdict recorded in Live Smoke
   Results at dev-pass close-out — not decided in this story file.
7. Regression: melee lunge unchanged; mode ③ colour defense/dodge still answer via the same seat;
   `6-1c` items 1-4/6/8 (tracking, whiff-on-dodge, launch travel, no-escape-once-launched, no
   regression, fps) still hold.
8. fps stable.

Feel knobs (per-colour travel/reach/arc/geometry clamps) stay named, editable `.tres` values;
tests must not pin their numbers (`6-1b`/`6-1c` precedent).

## Dev Notes

### Open Questions for the dev pass (named, not pre-ruled)

- **The per-tick dedupe key's exact shape.** Whether the landing adopts `register_swing_hit`
  verbatim (Fact 4, keyed `[attack_index, target]`, already exists on `HeroState`) or a
  landing-specific twin. **`6-1d/R1` narrows why a twin is likely needed: LIFECYCLE, not ladder.**
  `register_swing_hit` (`hero_state.gd:291-300`) only opens a dedupe record from `_start_swing`
  (`hero_state.gd:394-396`), which a chargeup never calls, and reaps records off the grace counter
  driven by the `active` window closing (`hero_state.gd:434-443`) — a CHARGING landing has no
  `active` window, so a record opened for it would never be erased (an unbounded, snapshotted
  dictionary; `to_snapshot` deep-copies `_swing_dedupe`, `hero_state.gd:463-466`). Prefer the
  existing primitive only if its lifecycle can be adapted; otherwise name a landing-specific twin
  and why (N4).
- **Where the authored per-colour clamp (AC 2) is applied, as a pre- or post-filter** on the
  overlap query (skip the query entirely once out of authored reach/homing-speed bound — cheaper,
  mirrors today's gate order — versus filtering a geometric hit after the query runs). The target
  body geometry itself is settled (Fact 5, `6-1d/R1`): read the `Hurtbox`/`HurtboxShape`'s actual
  `Shape3D` directly at the seam, no derived constant. Behaviourally equivalent either way; a
  performance/clarity call for the dev pass.
- **Swing-at-commit knob's exact plumbing**: a `BalanceConfig` bool/enum default OFF (AC 8),
  consumed by whichever progress-curve or contact-window mechanism the dev pass picks.

### Recorded facts, not re-derived (`6-1d/R7`)

Replay identity depends only on the RECORDED `push_contact` facts (`match_runner.gd:78-82`,
`:1723-1726`), never on live position or animation recomputation. A blade-anchor read used to
derive a contact fact is therefore not a new determinism class: melee has depended on the rig pose
the same way since 5-0a, and an old recording is unaffected by a later clip swap — only live play
changes.

### Files expected to change

- `src/main/match_runner.gd`: `_push_charge_reach_facts` (or its per-tick successor) grows a
  blade-anchor read and/or a body-geometry read; still reports a KIND/fact, never a raw
  distance/position beyond the existing 1-8/R-B3 shape.
- `src/state/match_state.gd`: `_resolve_charge_landing` and/or `_is_in_charge_arc` adapt to
  consume a per-tick geometric fact instead of (or alongside) the single radius KIND; dedupe
  storage if a new one is needed (Open Questions).
- `src/state/player_state.gd` / `src/state/hero_state.gd`: only if a new per-swing dedupe field is
  needed (golden-mover candidate, see Golden Prediction).
- `src/state/resources/balance_config.gd` / `data/balance/balance_config.tres`: the swing-at-commit
  knob (AC 8). No body-geometry constant is added (Fact 5, `6-1d/R1`) — the Hurtbox shape is read
  directly.
- `src/actors/hero/hero.gd`: only if the blade-anchor read needs a new accessor beyond
  `hitbox`/`hitbox_shape`'s existing public surface.
- Tests: extend `test/state/test_unblockable_tracking_and_reach.gd` and
  `test/integration/test_unblockable_reach_live.gd` (both from `6-1c`), or new files mirroring
  their split.
- **NOT expected to change:** `_gather_contact_facts`/`is_hitbox_active` (Non-Goals — melee stays
  on its own path); `retime_clips.gd`; any VFX resource; `intent_recorder.gd`/`record_file.gd`
  (`FORMAT_VERSION` stays 8 per prediction).

### Project Context Rules

- **HARD RULE — State/visual separation.** The per-tick contact decision and the resolution ladder
  stay state-layer; the blade-anchor read is a runner-owned position fact crossing inward as a KIND,
  never a distance/angle (D3(b)/A2). [Source: CLAUDE.md; project-context.md]
- **D3(b)/A2 — no world coordinates in `src/state/`.** Whichever mechanism is chosen, the runner
  never hands `src/state/` a raw distance or position — only a KIND/boolean/direction fact, the
  `1-8/R-B3` shape this story explicitly measures against (Fact 3). [Source: CLAUDE.md]
- **CONSTRAINT C — read balance inline.** Any new per-colour clamp field reads fresh at point of
  use, never cached. [Source: project-context.md]
- **Data as Resources.** The commit-swing knob is a `.tres` value, isolated from the golden/unit
  suite per `BC/R3` unless it becomes a new hashed field (see Golden Prediction). No geometry clamp
  constant is authored (Fact 5, `6-1d/R1`). [Source: project-context.md]
- **Guard mechanism over guard pattern.** The per-tick dedupe must make "one resolution per swing
  per target" true BY CONSTRUCTION (a stored dedupe key, Fact 4's precedent), not by a flag an
  adversarial mutation could leave stale. [Source: project-context.md, "Testing Rules"]

### References

- [Source: decision-log.md:9770-9776 (`6-1c/R10`, this story's opening ruling);
  :9786-9792 (`6-1c/R12`, P6/D3, Fact 6); :9782-9784 (`6-1c/R11`, retune-block, unowned);
  :9806-9859 (`6-1d/R1`-`R7`, this story's readiness-gate rulings); :9860-9873 (gate disposition,
  B1-B4/N1-N8)]
- [Source: docs/implementation-artifacts/6-1c-unblockable-tracking-and-reach.md — Measured Facts
  1-8, ACs, Non-Goals, Live Smoke items 1/5/7 (the named defect this story owns), Dev Agent Record
  Open-Questions precedent style]
- [Source: src/actors/hero/hero.gd:57-122 (`drive()`, `_track_weapon_bone()`,
  `_bone_pose_global()`, Fact 1)]
- [Source: src/actors/hero/animation_controller.gd:166-215 (`charge_playhead_seconds`,
  `charge_attack_progress`), :279-289 (`on_charge_progress`, forced `seek()`)]
- [Source: src/main/match_runner.gd:674-704 (`_push_charge_reach_facts`, Fact 3), :1672-1733
  (`_gather_contact_facts`, one-tick-lag header, Fact 4), :2505 (`_push_charge_reach_facts` seat,
  before `advance()`), :2581 (`_push_charge_progress` seat, after `advance()`), :2638-2639
  (`drive()` seat, step 4), :178-189 (`SPAWN_CLEARANCE_RADIUS`, hero inradius precedent REJECTED by Fact 5)]
- [Source: src/state/match_state.gd:2105-2109 (`_is_in_charge_arc`), :2936-3013
  (`_resolve_charge_landing`), :1839-1845 (`_register_attacker_hit`, Fact 4),
  :3641-3648 (`_charge_launch_velocity`, Fact 6)]
- [Source: src/state/hero_state.gd:228-229 (`is_hitbox_active`, Fact 4), :291-300
  (`register_swing_hit`, Fact 4), :394-396 (`_start_swing`), :434-443 (dedupe grace reap),
  :463-466 (`_swing_dedupe` snapshot, Golden Prediction N5)]
- [Source: src/state/player_state.gd:176-233 (`charge_window`/`landing_window`/`charge_color`)]
- [Source: src/actors/hero/hero.tscn:27-28, 67-68, 100-101 (Collision/HurtboxShape, box geometry,
  Fact 5), :102-104 (HitboxShape)]
- [Source: src/state/resources/balance_config.gd:317-492 (per-colour unblockable fields + lookups)]
- [Source: data/balance/balance_config.tres:128-139 (the 12 per-colour fields, Fact 3/AC 2)]
- [Source: test/state/test_determinism.gd:699-700 (golden never casts mode ②), :934 (`GOLDEN`)]
- [Source: test/state/test_card_observation.gd:310 (31-key snapshot pin)]
- [Source: src/systems/record_file.gd:171 (`FORMAT_VERSION := 8`)]

## Change Log

- 2026-09-12: story authored (`gds-create-story`, measure-first pass; no dev work done). Board
  entry for `6-1d-honest-hit-geometry` was already present at `sprint-status.yaml:118/133` from the
  `6-1c` close-out — no Step 0 insertion needed. Status `authored`, awaiting operator review before
  a dev pass.
- 2026-09-12: readiness gate round 1 findings (`C:\dev\_61d-gate.md`) closed by operator rulings
  `6-1d/R1`-`R7` (decision-log.md:9806-9859). The A/B blade-source fork and the body-radius problem
  struck (Fact 5 rewritten); Fact 4's "no shared seat" reasoning withdrawn, residue kept; Fact 2
  shrunk (seek-determinism argument dropped, folded into a Dev Note); Fact 6/P6 flipped from
  deferred to adopted. AC 2 narrowed to reach/homing-speed and made test-provable; AC 4 gained the
  commit-window-open sentence; AC 6 reworded as a named supersession of `6-1c` AC 3; old AC 7
  struck and replaced with the GREEN travel-profile + P6 adoption + halt condition; a new AC 8
  built the swing-at-commit knob (moved out of Non-Goals); old AC 11 (golden measured both
  directions) moved to the Golden Prediction section as a process statement, ACs renumbered 1-11
  with no dangling cross-references. Two mis-cites fixed (`register_swing_hit` at
  `hero_state.gd:291`, `HurtboxShape` at `hero.tscn:100-101`). Status stays `authored`.

## DEVIATIONS

- Board Step 0 found the key already present at `sprint-status.yaml:118/133` from the `6-1c`
  close-out — not a deviation from the prompt's contingency branch (that branch applies only if
  the key were missing); disclosed for completeness.
- **Story budget overrun (original authoring pass), disclosed per house rule: 338 lines against
  the 270-line budget, +68.** Cause: six Measured Facts each carrying a full cite-by-content trail
  plus a same-length Dev Notes/References section citing the same trail a second time. Not
  absorbed by thinning citations or merging ACs.
- No subagents, forks, or parallel sessions were used; no commits were made; this file was the
  only edit.

### This pass (readiness-gate fix, 2026-09-12)

- **Story budget overrun against this pass's own 320-line target: 381 lines, +61, disclosed, not
  absorbed.** R1 deleted material (the A/B fork, the body-radius problem, two Open Questions,
  roughly 34 lines) but the corrections it required — the withdrawn-reasoning paragraph in Fact 4,
  the lifecycle framing in the dedupe Open Question, the new AC 7/AC 8 text, the Recorded-facts Dev
  Note, the expanded citation set fixing two mis-cites, and this DEVIATIONS entry itself — added
  more than it removed. Not absorbed by further cutting citations; the gate explicitly wants
  cite-by-content over remembered line numbers.
- **Decision-log append overrun against the ~55-line budget given in the prompt: 74 lines, +19,
  disclosed, not absorbed.** Verified pure append (`git diff --stat` shows 74 insertions, 0
  deletions) before committing. Condensing the seven rulings further risked losing the halt
  condition (R4) or the named supersession (R3), both load-bearing for the dev pass.
- No subagents, forks, or parallel sessions were used. No suite run. No push.
