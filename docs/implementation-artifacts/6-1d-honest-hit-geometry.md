---
baseline_commit: e50bc94705cfba8c5471731391806410f6e7a04e
---

# Story 6.1d: Honest Hit Geometry

Status: done

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

### Live Smoke Results (2026-09-13)

Source: `docs/playtest-log.md`, 6-1c/6-1d sessions of 11.9. and 13.9. (operator's own numbered
points, distinct from this list's numbering). Rulings recorded in decision-log session "6-1d
close-out": `6-1d/R14`-`R17`.

1. **PASS.** No damage across a visible gap; the 6-1c-carried gap defect is gone. Operator (13.9.,
   points 1-2): "mac sad radi stetu samo kada dira protivnika" (the sword now deals damage only
   when it touches the opponent).
2. **PASS**, same log line as item 1 — the blade-passing-through case was not separately
   distinguished in the log, and the operator judged the anchor read live and correct.
3. **PASS, functionally** — dodge during the swing still negates (AC 6 holds), but the operator
   flags it reads as too easy to escape by dodging after the commit and wants dodge stamina raised
   relative to unblockable initiation cost (13.9., point 3). Not a defect; carried to the retune
   block as `6-1d/R16(ii)`, alongside `6-1c/R11`'s reach note it restates.
4. **Not addressed this smoke pass.** The operator's log does not comment on the per-colour clamp
   case; not claimed here.
5. **Inconclusive, not a clean PASS.** GREEN's homing does not read as travelling toward the
   target during the pre-apex phase — it rises first, then flies to the enemy, where the operator
   expected roughly two-thirds of the travel toward the target by the apex (13.9., point 4:
   "green let uopce ne radi homing u djelu animacije prije nego je skakac u najvisoj toci"). Per
   `6-1d/R15`/`R16(iii)`, this is because GREEN's held pose is already airborne before the apex —
   a clip-knob problem, not this story's launch-velocity ramp. Carried to the retune block.
6. **Judged, no operator-observable effect.** The operator did not recognize what was being asked
   ("ne znam o kakvom gumbu pricamo", 13.9., point 5) — the knob's effect is not visible from play.
   `6-1d/R15`: ON has no observable effect on GREEN (classified: the held pose already sits past
   the takeoff, so re-timing WHEN it plays cannot move the takeoff out of the chargeup). Knob
   **stays OFF**. RED/BLUE not separately judged.
7. **PASS.** Regression clean — melee lunge, mode ③ defense/dodge, and the carried `6-1c` items all
   still hold. Operator (13.9., point 6): "ostalo radi" (the rest works).
8. **PASS.** fps stable. Operator (13.9., point 7): "fps stabilan".

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

## Dev Agent Record

### Implementation Plan (as built)

**One latch, no new field.** `MatchState._charge_reach` keeps its name, its type (`Array[int]`, two
entries) and its `REACH_UNKNOWN` third value; `push_contact` changes what it WRITES. Outside the
contact window it is CLEARED to `REACH_UNKNOWN`; inside it, `INSIDE` is ABSORBING and `OUTSIDE`
writes only over a non-`INSIDE` value. The contact window is
`PlayerState.is_contact_window_open()` == `landing_window.is_running and
charge_window.remaining_ticks() <= 1` — ONE definition, read by BOTH the runner (whether to run the
overlap query) and `push_contact` (whether the arriving fact may latch), so the two layers cannot
drift. `remaining_ticks() <= 1` rather than `not is_running` because both callers read BEFORE
`advance()` ticks the windows, and because with no authored launch span the chargeup-close tick is
the ONLY evaluated tick.

**N4 answered by not having a record.** `register_swing_hit` is NOT adopted (Open Question
resolved: a landing-specific twin, and not even a dictionary one). There is nothing to reap: the
store is a fixed two-element `Array[int]` that cannot grow, and the clearing arm means every
committed flight starts from "nothing measured" with no reset call anywhere. Proven directly by
`test_the_contact_verdict_rests_at_unknown_outside_a_committed_flight`, not by consequence.

**AC 2 as a PRE-filter** (Open Question resolved): `planar.length() <= reach` stays in the runner,
ahead of the overlap query — cheaper, and it mirrors the landing's own gate order.

**AC 7** rewrites `_charge_launch_velocity`: span from `BalanceTicks.unblockable_launch_ticks_for`
(P6 adopted), and launch tick `i` weighted `2 - (2i+1)/L` of the flat share. The weights sum to
exactly `L`, so the authored total distance is preserved. The index is derived from
`landing_window.remaining_ticks()`.

**AC 7 HALT CONDITION: NOT TRIGGERED.** No new hashed snapshot field and no change to
`landing_window`'s duration, start seat or close tick. `6-1c/R10(b)` is delivered in full, not
deferred.

**AC 8** adds `BalanceConfig.unblockable_swing_at_commit: bool = false` (also written `false` into
the authored `.tres`). ON composes `AnimationController.charge_commit_anchored_progress` over the
existing linear progress; OFF never reaches that line, so the pushed value is byte-identical to
`6-1c`'s — "OFF reproduces today exactly" is a property of the call site, not of arithmetic.

**Rejected shape, named:** unconditional stickiness in state with the phase gate only in the runner.
It would have flipped `test_unblockable_initiation::test_the_landing_reads_the_answer_from_the_expiry_tick_only`
(a launch-less fixture whose eleven pre-commit `INSIDE` pushes would have latched) for reasons
unrelated to AC 6's deliberate supersession. The state-side window gate preserves it.

### Debug Log

- Suite cadence: BEFORE baseline `C:\dev\_61d-dev-suite-before.txt` = **757 / 0 / 5993 + 58
  integration**, EXIT=0 — matching the prompt's expected baseline exactly. FINAL
  `C:\dev\_61d-dev-suite-after.txt` = **769 / 0 / 6251 + 59 integration, ALL TESTS PASSED**, EXIT=0.
- TWO EXTRA RUNS beyond the mandated two, named here as required: (a) a state-harness-only
  parse/logic probe before the first full run, which caught one real defect (a duplicate `attacker`
  parameter name in `push_contact`); (b) a re-run after fixing one NEW test's own fixture bug (it
  released on the commit tick, where a release is ignored by `6-1c` AC 2, so it never feinted).
  Two background runs were killed by host memory pressure, not by anything in the repo; the final
  run was taken in the foreground and completed.
- DEVIATION FROM THE SKILL, disclosed: this story file has **no `Tasks/Subtasks` section**.
  `gds-dev-story` Step 1 routes "no incomplete tasks" straight to the completion sequence, which
  would have ended the pass with nothing built. The ACs were treated as the task list and the work
  was executed; no checkbox was ticked because there are none to tick. Live Smoke's numbered items
  are not checkboxes and were left untouched.
- DEVIATION, disclosed: `sprint-status.yaml`'s `story_note` for this key is committed alongside the
  story file in the docs commit, rather than the story file strictly alone, because the skill's
  `on_complete` mandates that write and leaving it uncommitted would hand the operator a dirty tree.
  The board STATUS line is untouched — still `ready-for-dev  # Tier A` (CFG/R2).
- Full working notes: `C:\dev\_61d-dev.md`.

### Golden verdict — measured in inverse form, NOT MOVED

- `test_determinism.gd` UNEDITED through the whole pass; `GOLDEN` still
  `9679fa80f19358d15c9b33b1f9a3706264095ada871e5d2530cf29b6cbce8315` and the golden test PASSES.
- MEASURED THIS PASS, not cited: a temporary probe in `_play_sequence` printed on any tick where
  either hero was `CHARGING` or either `landing_window` was running. **Zero prints across the whole
  golden run.** NON-VACUITY: the same seat with the condition changed to `IDLE` printed **184**
  times. Backup + SHA256 `1d55b5c18bf07b76782feb18cb5637930ce41194931409bc3a3cb60b7f2c7e85` taken before the probe and re-verified after
  restoring by copying the backup back (never `git checkout`).
- The single named admissible exception did not arise: **no new TOP-LEVEL hashed field anywhere**.
  `_charge_reach` was already excluded from `to_snapshot()` and already listed in
  `test_replay_identity.gd`'s `UNHASHED_CROSS_TICK`; its name, type, size and exclusion are all
  unchanged, so `UNHASHED_CROSS_TICK_MEMBERS` stays at 3 and that file needed no edit.
- 31-key snapshot pin (`test_card_observation.gd:310`) PASSES unchanged. `FORMAT_VERSION` still 8.

### Mutation table

Every mutation: the CURRENT file copied to `C:\dev\_61d-mut\` with SHA256 first, mutated by python
byte-replace, run, restored by copying the backup back (never `git checkout --`), SHA re-verified.

| # | mutation | observed | provenance |
|---|---|---|---|
| M1 | `push_contact`: drop the `is_contact_window_open()` clearing arm (`INSIDE` absorbing always) | 3 RED: `test_contact_during_the_feintable_chargeup_credits_nothing`, `test_the_contact_verdict_rests_at_unknown_outside_a_committed_flight`, and `test_unblockable_initiation::test_the_landing_reads_the_answer_from_the_expiry_tick_only` | MEASURED |
| M2 | `push_contact`: drop the `INSIDE` stickiness (last write wins inside the window) | 1 RED: `test_a_defender_touched_on_one_launch_tick_is_hit_even_after_it_clears_the_blade` | MEASURED |
| M3 | `_charge_launch_velocity`: flatten the ramp (`share := 1.0`) | 2 RED: `test_the_launch_travel_is_front_loaded_and_still_sums_to_the_authored_distance`, `test_after_the_commit_a_release_does_not_feint_and_input_does_not_steer` | MEASURED |
| M4 | `_charge_launch_velocity`: restore `unblockable_launch_seconds_for` as the divisor | 1 RED: `test_the_launch_speed_derives_from_the_tick_span_not_the_seconds_float` | MEASURED |
| M5 | `charge_commit_anchored_progress`: identity on the first arm | 2 RED: `test_the_commit_fraction_maps_onto_the_clips_hold_end`, `test_the_commit_anchored_remap_is_monotonic` | MEASURED |
| M6 | `unblockable_swing_at_commit` script default flipped to `true` | 1 RED: `test_the_swing_at_commit_knob_is_authored_off` | MEASURED |
| M7a | runner: drop the `_blade_overlaps_body(...)` conjunct | `test_unblockable_reach_live` RED on `near` (hit across the gap) and `side`, all three colours; the new file PASSES | MEASURED |
| M7b | runner: drop the `planar.length() <= reach` pre-filter | `test_honest_hit_geometry_live` RED on `clamp`, all three colours; `test_unblockable_reach_live` PASSES | MEASURED |
| M7c | runner: drop `is_contact_window_open()` from the kind derivation, leaving the state gate standing | BOTH integration files PASS — **a real finding, recorded not papered over** | MEASURED |

**On M7c.** The runner's copy of the contact-window gate is a COST and CLARITY gate, not the
guarantee: M1 shows the load-bearing refusal is the state one, which is the right place for it
("guard mechanism over guard pattern"). The two cannot drift because both call the same
`PlayerState.is_contact_window_open()`; the runner's copy is what stops a physics query running on a
tick whose answer state would refuse anyway.

### Superseded tests (deliberate, named)

- `test_the_arc_never_widens_an_outside_kind` — the fixture now pushes `OUTSIDE` from the COMMIT
  tick on, not only across the launch. The claim is unchanged and not weakened (no touch, no hit,
  whatever the arc says); only the tick range the fixture must speak for grew, because contact is
  latched across the whole committed flight now.
- `test_after_the_commit_a_release_does_not_feint_and_input_does_not_steer` — compared against a
  CONSTANT launch velocity, now against the authored per-tick share (still written out from the
  authored distance and the tick span, never captured from the run under test).
- `test_unblockable_reach_live.gd` — `near` and `side` flip from HIT / arc-decides to MISS +
  latched `OUTSIDE`. This is AC 1 and AC 6 landing: both layouts leave visible daylight, and `near`
  is the exact layout the operator watched land across a gap at `6-1c`'s smoke.

### Completion Notes

- AC 1-11 satisfied. AC 2 proved by a TEST (`clamp`, the authored config duplicated in memory with
  its reaches pulled below body contact) rather than by a `.tres` diff; the authored file on disk
  gains only the AC 8 knob and no reach or speed number moved.
- AC 4's window opens AT the commit: proven both headless (M1) and live (the `charge` case, which
  also asserts a REAL overlap was observed during the chargeup, so it cannot pass vacuously).
- AC 6's supersession and its surviving half are a proved PAIR — neither test passes against an
  implementation that always lands or never lands.
- Live Smoke checkboxes deliberately left untouched; the operator runs that. Live Smoke item 6
  (the ON/OFF verdict on the swing-at-commit knob) is his call, as AC 8 says.

### Review fix pass (2026-09-13, rulings `6-1d/R8`-`R12`)

Source of findings: `C:\dev\_61d-review.md` (verdict CHANGES REQUESTED: HIGH-1, MEDIUM-1..3,
LOW-1..7). Source of rulings: the operator's fix-pass prompt, recorded in the decision-log session
2026-09-13. Working files, backups and mutation outputs: `C:\dev\_61d-fix\`.

**`6-1d/R8` -- the arc is judged against the bearing at the moment of contact (HIGH-1).**
- The CHARGING facing track's read was verified by content before any edit
  (`_resolve_movement`: `var aim := _charge_reach_dirs[slot]`, written to `facing` only while
  `charge_window.is_running`). `_charge_reach_dirs` is still written on every push, unchanged.
- New per-slot store `MatchState._charge_contact_dirs`, written in the arm of `push_contact` that
  latches `INSIDE` (and cleared with the verdict in the clearing arm). `_is_in_charge_arc` reads it.
  An `OUTSIDE` after an `INSIDE` writes neither half. With several contact ticks, an in-arc bearing
  is ABSORBING (`6-1d/R13`, review fix pass 2 below): a later `INSIDE` re-latches both halves only
  when the bearing already latched does not pass the arc, so any in-arc contact during the flight
  is a hit and an all-out-of-arc flight still misses. (As first built in this pass the bearing
  re-latched on every `INSIDE`, judging the last contact; R13 replaced that.)
- The arc still can only REMOVE a hit: it is consulted only behind `_charge_reach == INSIDE`.
- `_is_in_charge_arc`'s docstring is true again and says which commit broke it (`e7afe21`, the
  dev pass) and which ruling restored it.
- The new store is excluded from `to_snapshot()` and listed in `test_replay_identity.gd`'s
  `UNHASHED_CROSS_TICK`. **That test edit is EXPECTED and is not a golden move.** It joins
  argument (c) beside `_charge_reach` / `_charge_reach_dirs`, so `UNHASHED_CROSS_TICK_MEMBERS`
  stays at 3 -- see DEVIATIONS.
- **Consequence, stated plainly: AC 6's supersession is now FULLY delivered in live play, not
  partially.** A defender touched mid-flight who then leaves a narrow arc (BLUE 40, RED 120) is HIT.
  The mirror is closed too: a touch taken while OUTSIDE the arc is not credited because the defender
  drifted into the arc by the landing.
- Proved in BOTH directions with a NARROW-arc colour (BLUE, in-test 40):
  `test_a_narrow_arc_judges_the_bearing_at_contact_so_a_strafe_after_the_touch_is_hit` and
  `..._so_drifting_in_after_the_touch_is_missed`. Both go RED under the opposite mutation (M8).

**`6-1d/R9` -- the latch's clearing is owned, not emergent (MEDIUM-1 + round-over/reset leak).**
- `_charge_reach[slot]` and `_charge_contact_dirs[slot]` are cleared at the CAST SEAT
  (`_resolve_unblockable_cast`, beside the two window starts) and in `_reset_player` beside the
  three-part chargeup clear. No `chargeup_ticks >= 2` authoring assert was added.
- `_push_charge_reach_facts` returns while the round-over freeze holds (read through
  `to_snapshot()["round_over"]`, the `_physics_process` lock-marker precedent, taken only while a
  hero is CHARGING). Nothing is pushed and nothing is recorded, so replay sees the same silence.
- `C == 1` free hit proven dead: `test_a_one_tick_chargeup_does_not_inherit_the_previous_attacks_verdict`
  (attack #1 lands and leaves `INSIDE`; attack #2, reported OUTSIDE on every evaluated tick, misses).
- Reset clear: `test_the_debug_reset_clears_the_contact_verdict_and_its_bearing`.
- Freeze gate: new live case `frozen` in `test_honest_hit_geometry_live.gd` -- commit with the
  defender parked clear, force the round over mid-launch, move the defender onto the blade, observe
  real overlap (non-vacuity guard) for 20 frames with the contact window open, assert the verdict
  never becomes `INSIDE`; then a debug reset through the controller must leave `REACH_UNKNOWN`.

**`6-1d/R10` -- the launch index comes from the window (MEDIUM-3).**
- `_charge_launch_velocity` now takes `L = landing_window.duration - charge_window.duration` and
  `i = (landing_window.duration - landing_window.remaining) - charge_window.duration`. Both
  durations are snapshotted at the cast and survive a hot-reload (`TimingWindow.start`), so no
  refusal was added. A read-only `TimingWindow.duration_ticks()` accessor was added for this.
- AC 7's arithmetic re-proven: on in-phase tick `k = C + i` the landing window's elapsed count is
  `C + i`, so `i` runs `0..L-1` exactly as before; the weights `2 - (2i+1)/L` still sum to `L` and
  the flat speed is still `D * 60 / L`, so the total is `D`. With no reload, `L` and `i` are
  numerically identical to the dev pass's values -- every pre-existing AC 7 test passes unedited.
- New `test_a_mid_flight_span_retune_cannot_pin_the_launch_index` (GREEN L = 12 reloaded to 3
  after the commit tick): still 12 moving ticks, still strictly front-loaded, still the authored
  3.0 in total.

**`6-1d/R11` -- test-only repairs (MEDIUM-2 + LOW-2c).**
- `setup` heals P2 to max beside `apply_balance`.
- `clamp` now asserts `_contact_ticks > 0`.

**`6-1d/R12` -- LOW dispositions.**

| LOW | disposition |
|---|---|
| LOW-1 P6 worked example backwards | APPLIED: 0.26 s rounds UP (overshoot), 0.27 s named as the undershoot sign |
| LOW-2a "twice the flat share" | APPLIED: `2 - 1/L` at the start, `1/L` at the end |
| LOW-2b degenerate span "unchanged" | APPLIED (comment): returns the input CLAMPED to `[0, 1]`; code untouched |
| LOW-2c `clamp` non-vacuity | APPLIED under R11 |
| LOW-3 probe SHA transcription | APPLIED: corrected in place to the full hash, re-hashed this pass from `C:\dev\_61d-mut\test_determinism.gd` |
| LOW-4 commit trailer | NOT APPLIED: this pass's prompt fixes the trailer for its own commits; history not rewritten |
| LOW-5 helper comment over-claims independence | APPLIED: comment now names the transcription and points at the shape test |
| LOW-6 AC 8 ON path uncovered at the composition seat | NOT APPLIED: coverage expansion, not a one-line fix; stays a Live Smoke item 6 note |
| LOW-7 `hitbox` null-deref | OUT by ruling: inherited from `_gather_contact_facts` |

**Correction to the dev pass's M7c wording (review T3).** The runner's copy of the contact-window
conjunct is a cost, clarity AND RECORDING gate: `capture_push_contact` records the kind it
produced, so without it the recorded fact stream would carry `INSIDE` on chargeup ticks. State and
determinism are unaffected; the state arm is still the guarantee.

**Golden verdict -- predicted NO MOVE, measured NOT MOVED.** `test_determinism.gd`,
`test_card_observation.gd` and `record_file.gd` are absent from the diff; `GOLDEN` is still
`9679fa80f19358d15c9b33b1f9a3706264095ada871e5d2530cf29b6cbce8315` and the golden test passes in the
suite run. Every new write is either in the CHARGING-only paths the golden never enters (dev pass
probe: zero CHARGING ticks) or on unhashed stores (`_charge_reach`, `_charge_contact_dirs`) at the
cast seat / reset. The `test_replay_identity.gd` list edit is a classification, not a golden move.
31-key snapshot pin and `FORMAT_VERSION` 8 unchanged.

**Suite.** Before (review baseline at `d7f5b28`): 769 / 0 / 6251 + 59 integration. After (run 1,
all fixes in): **774 / 0 / 6293 + 59 integration, ALL TESTS PASSED, EXIT=0**
(`C:\dev\_61d-fix\suite1.txt`). Final run: see the Change Log entry.

**Mutation table (this pass).** Procedure: the current file copied to `C:\dev\_61d-fix\` with
SHA256 first, mutated by python byte-replace, run, restored by copying the backup back (never
`git checkout --`), SHA re-verified MATCH on every row. State rows ran the state harness; live rows
ran `test_honest_hit_geometry_live.gd`.

| # | mutation | observed | provenance |
|---|---|---|---|
| M8 | `_is_in_charge_arc` reads `_charge_reach_dirs` again | 2 RED: both narrow-arc R8 tests (774/2/6293) | MEASURED |
| M9a | delete the two cast-seat clears | 1 RED: `test_a_one_tick_chargeup_does_not_inherit_the_previous_attacks_verdict` | MEASURED |
| M9b | delete the two `_reset_player` clears | 1 RED: `test_the_debug_reset_clears_the_contact_verdict_and_its_bearing` | MEASURED |
| M9c | runner round-over gate disabled (`if false and ...`) | live `frozen` RED on all three colours: "latched INSIDE during the round-over freeze", 18 overlapping frames each | MEASURED |
| M10 | span/index read live off `balance_ticks` again | 1 RED: `test_a_mid_flight_span_retune_cannot_pin_the_launch_index` | MEASURED |
| M11a | in-memory damage retune to 55 %, heal KEPT | live PASS | MEASURED |
| M11b | same retune, heal REMOVED | live RED: `deadline: stuck in case 4 phase charging` | MEASURED |
| M11c | `clamp` parked clear of the blade | live RED on all three colours: the new `_contact_ticks > 0` guard fires | MEASURED |

A 30 % retune without the heal still PASSED: the new `frozen` case's debug reset heals P2 once per
colour, so two landing cases per colour (60 %) never kill it. 55 % (110 % per colour) was used to
reproduce MEDIUM-2's deadline, and the heal is still needed at that value.

### Review fix pass 2 (2026-09-13, ruling `6-1d/R13`)

Source of the ruling: the operator's fix-pass-2 prompt, recorded in the decision-log session
2026-09-13 (6-1d review fix pass). Working files, backups and mutation outputs: `C:\dev\_61d-r13\`.

**`6-1d/R13` -- an in-arc contact is absorbing; a later out-of-arc contact never overwrites it.**
- `push_contact`'s INSIDE arm latches the verdict and the bearing UNLESS the verdict is already
  `INSIDE` and the already-latched bearing passes `_is_in_charge_arc` against the attacker's facing.
  The arc is only ever asked of the bearing ALREADY latched, never of the push being latched; the
  code comment states why that makes the commit tick correct (nothing is latched on the commit
  push -- the R9 cast-seat clear -- and every later push arrives after the facing freeze).
- No new store: `_charge_contact_dirs` is reused. `UNHASHED_CROSS_TICK` unchanged.
- The two R8 tests pass unchanged.

**R3-superseded fixtures (named, not collateral).** Each reported an INSIDE contact dead ahead on
the COMMIT tick, then moved the defender off the line. Under R3 that commit-tick touch is a real
in-arc contact and, under R13, absorbing -- so each would have tested a hit. Each now pushes OUTSIDE
through the chargeup and the commit tick and INSIDE only from the sidestep onward (the
`test_the_arc_never_widens_an_outside_kind` correction), so the claim "with the ONLY contact off the
line, the authored arc decides" is unchanged and not weakened. All three went RED with the code
change alone (`C:\dev\_61d-r13\state_pre_fixture.txt`):
- `test_a_defender_who_leaves_the_frozen_line_after_the_commit_is_missed` -- commit-tick INSIDE dead
  ahead made the 90-degree sidestep a hit.
- `test_each_colour_judges_its_own_arc_against_the_committed_direction` -- commit-tick INSIDE dead
  ahead made the RED 65 / BLUE 25 just-outside cases hits.
- `test_the_colour_counter_still_answers_through_the_one_landing_seat` (`missed` half) -- commit-tick
  INSIDE dead ahead made the whiff land and consume the defense window.

**Proved both ways on BLUE (in-test arc 40).** Launch tick 0 is the commit tick (the
`_launch_velocity` index convention); a new helper `_charge_to_the_commit_tick` runs the feintable
chargeup OUTSIDE and stops one tick short of it.
- (a) `test_an_in_arc_touch_on_the_commit_tick_survives_later_out_of_arc_touches` -- in arc (10 deg)
  on tick 0, INSIDE at 90 deg on every later tick through the landing: HIT.
- (b) `test_any_in_arc_touch_during_the_flight_is_a_hit` -- 90 deg on tick 0, in arc on tick 3, 90 deg
  on every other tick (so neither the first nor the last contact is in arc): HIT.
- (c) `test_a_flight_touched_only_out_of_arc_still_misses` -- INSIDE at 90 deg on every tick: MISS,
  with the verdict asserted `INSIDE` so only the arc refuses it.

**Named-hazard finding, measured.** (a) and (b) assert the facing after the commit tick is still the
pre-commit aim. `advance()` ticks `charge_window` in step 2, before `_resolve_movement`, so the commit
tick's own push does NOT re-aim the facing -- the prompt's premise that it does is not what the code
does. The rule was implemented exactly as ruled and does not depend on this detail; see DEVIATIONS.

**Mutation table (this pass).** Procedure: `match_state.gd` copied to `C:\dev\_61d-r13\` with SHA256
first (`f925c4e2...`), mutated by python byte-replace, state harness run, restored by copying the
backup back (never `git checkout --`), SHA re-verified MATCH on both rows.

| # | mutation | observed | provenance |
|---|---|---|---|
| M12a | "always overwrite": the INSIDE arm's R13 guard replaced by `if true:` (the R8 behaviour) | 2 RED: (a) and (b); (c) passes (777/2/6305) | MEASURED |
| M12b | "always hit": `_is_in_charge_arc(player, slot)` in the landing gate replaced by `true` | 5 RED: (c), the three R3-superseded fixtures, and R8's drifting-in test (777/5/6305) | MEASURED |

**Golden verdict -- predicted NO MOVE, measured NOT MOVED.** The change is inside the CHARGING-only
charge-reach arm the golden fixture never enters, on the unhashed `_charge_reach` /
`_charge_contact_dirs`. `test_determinism.gd` is absent from the diff, `GOLDEN` is still
`9679fa80f19358d15c9b33b1f9a3706264095ada871e5d2530cf29b6cbce8315`, and the golden test passes in the
final suite run. 31-key snapshot pin and `FORMAT_VERSION` 8 unchanged.

**Suite.** Before: 774 / 0 / 6293 + 59 integration (previous pass final). After, one final run:
**777 / 0 / 6305 + 59 integration, ALL TESTS PASSED, EXIT=0** (`C:\dev\_61d-r13\suite_final.txt`).

## File List

- `src/state/player_state.gd` — new `is_contact_window_open()` predicate (AC 4).
- `src/state/match_state.gd` — `push_contact`'s charge-reach latch rule (AC 4/5/6);
  `_charge_launch_velocity` rewritten (AC 7); `_charge_reach` declaration comment; a note on the
  unedited landing gate.
- `src/main/match_runner.gd` — `_push_charge_reach_facts` derives the kind from the overlap (AC
  1/2/4); new `_blade_overlaps_body()`; `_push_charge_progress` composes the AC 8 knob.
- `src/actors/hero/animation_controller.gd` — new `charge_commit_anchored_progress()` and
  `charge_hold_end_for()` (AC 8).
- `src/state/resources/balance_config.gd` — new `unblockable_swing_at_commit` (AC 8); a note on
  `unblockable_launch_seconds_for` now having no production divisor caller (P6).
- `data/balance/balance_config.tres` — `unblockable_swing_at_commit = false` (one line).
- `test/state/test_unblockable_tracking_and_reach.gd` — seven new tests (AC 4/5/6/7), the
  `_cast_and_charge_kind` / `_launch_velocity` helpers, two superseded tests updated.
- `test/state/test_charge_playhead_mapping.gd` — four new tests (AC 8's remap).
- `test/state/test_balance_authoring.gd` — one new test (AC 8's default-OFF, both halves).
- `test/integration/test_honest_hit_geometry_live.gd` — NEW. Four live cases per colour: `touch`,
  `clamp`, `charge`, `flee` (AC 1/2/4/5/6).
- `test/integration/test_unblockable_reach_live.gd` — `near` and `side` reworked to the new
  semantics; the launch/playhead claims kept.

Review fix pass (2026-09-13):

- `src/state/match_state.gd` -- `_charge_contact_dirs` store; latch arm split (R8); arc reads the
  latched bearing; cast-seat and `_reset_player` clears (R9); `_charge_launch_velocity` span/index
  from the windows (R10); comment corrections (LOW-1, LOW-2a).
- `src/state/timing/timing_window.gd` -- read-only `duration_ticks()` accessor (R10).
- `src/main/match_runner.gd` -- `_push_charge_reach_facts` skips the round-over freeze (R9).
- `src/actors/hero/animation_controller.gd` -- comment only (LOW-2b).
- `test/state/test_unblockable_tracking_and_reach.gd` -- five new tests (R8 x2, R9 x2, R10);
  helper comment (LOW-5).
- `test/state/test_replay_identity.gd` -- `_charge_contact_dirs` classified in
  `UNHASHED_CROSS_TICK` (expected edit, not a golden move; MEMBERS stays 3).
- `test/integration/test_honest_hit_geometry_live.gd` -- P2 healed per case, `clamp`
  non-vacuity guard (R11); new `frozen` case (R9); controller can issue one debug reset.

Review fix pass 2 (2026-09-13):

- `src/state/match_state.gd` -- `push_contact` INSIDE arm: in-arc latch absorbing (R13); comment
  on `_is_in_charge_arc`'s history.
- `test/state/test_unblockable_tracking_and_reach.gd` -- three new tests (R13 a/b/c), helper
  `_charge_to_the_commit_tick`, three R3-superseded fixtures corrected.

Review LOW touch-ups (2026-09-13, review2 LOWs B/D/E):

- `test/integration/test_honest_hit_geometry_live.gd` -- the `frozen` case's placement gains a
  reach-sanity check beside its overlap check (LOW-B); the mangled tab-continuation line in the
  same teleport is un-mangled (LOW-E).
- `test/state/test_unblockable_tracking_and_reach.gd` -- corrected the copy-pasted sidestep
  language on `test_each_colour_judges_its_own_arc_against_the_committed_direction`, which has no
  sidestep (LOW-D).

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

- 2026-09-12: DEV PASS (`gds-dev-story`, Tier A). Honest hit geometry implemented: the charge-reach
  KIND is now derived from melee's own `get_overlapping_areas()` query against the defender's real
  Hurtbox shape, gated by a shared `PlayerState.is_contact_window_open()` predicate and latched
  across the whole committed flight; `_charge_launch_velocity` rewritten for P6 + a front-loaded
  travel ramp; the swing-at-commit knob built and left OFF. Suite 757/0/5993+58 before ->
  769/0/6251+59 after, all pass. Golden NOT MOVED, measured in inverse form (the fixture never
  enters CHARGING: zero probe hits against a 184-hit non-vacuity control). No new hashed field.
  AC 7's halt condition NOT triggered. Status `ready-for-dev` -> `review`.
- 2026-09-13: REVIEW FIX PASS (rulings `6-1d/R8`-`R12`, findings `C:\dev\_61d-review.md`). HIGH-1
  closed by latching the contact bearing with the verdict; MEDIUM-1 and the reset/round-over leak
  closed by owned clears plus a freeze gate on the runner push; MEDIUM-3 closed by deriving the
  launch span and index from the running windows; MEDIUM-2 and LOW-2c closed in the live fixture;
  LOWs dispositioned above. Suite 769/0/6251+59 -> 774/0/6293+59. Final run after the docs edit:
  774/0/6293+59, ALL TESTS PASSED, EXIT=0 (`C:\dev\_61d-fix\suite_final.txt`). Golden NOT MOVED. Status stays `review`; board untouched (CFG/R2).

- 2026-09-13: REVIEW FIX PASS 2 (ruling `6-1d/R13`). An in-arc contact is absorbing; a later
  out-of-arc contact never overwrites it. Three R3-superseded 6-1c fixtures corrected and named.
  Suite 774/0/6293+59 -> 777/0/6305+59, ALL TESTS PASSED. Golden NOT MOVED. Status stays
  `review`; board untouched.

- 2026-09-13: REVIEW LOW TOUCH-UPS (`C:\dev\_61d-review2.md`, LOWs B/D/E). The `frozen` live case
  gains a reach-sanity check beside its overlap check (LOW-B); a copy-pasted sidestep comment on a
  test with no sidestep is corrected (LOW-D); a mangled tab-continuation line is fixed (LOW-E).
  Suite 777/0/6305+59, unchanged in count (B adds an assertion, not a new test), ALL TESTS PASSED.
  Golden NOT MOVED. Status stays `review`; board untouched.

- 2026-09-13: CLOSE-OUT. Live smoke run against this story's ACs (operator's log,
  `docs/playtest-log.md`), rulings `6-1d/R14`-`R17` (decision-log session "6-1d close-out"): smoke
  PASS on damage-only-on-contact and regression/fps; the swing-at-commit knob stays OFF (no
  observable effect, R15); the retune block is unlocked for the next story to pick up (R16), and
  four small close-out candidates are recorded with no owner (R17). Status `review` -> `done`;
  board -> `done  # Tier A`.

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

### This pass (review fix, 2026-09-13)

- **`UNHASHED_CROSS_TICK_MEMBERS` NOT bumped; it stays at 3.** R8 asked for the count to be updated
  with the list edit. The test counts ARGUMENTS, not arrays (`4-6/R6`), and the 5-2 precedent added
  `_charge_reach_dirs` to argument (c) without a bump. `_charge_contact_dirs` is the same kind of
  member: a copy of a pushed fact, restored by replaying the pushes. A bump to 4 would contradict the
  pin's own doctrine. The list entry, the expected edit, WAS made. Operator to confirm.
- **Several contact ticks: the arc judges the LAST contact's bearing.** R8 put the bearing in the
  arm that latches `INSIDE`, and that arm runs on every `INSIDE` push. So a later out-of-arc touch
  replaces an earlier in-arc one. Latching only the FIRST contact would have flipped three 6-1c
  AC 3/AC 5 headless tests that push `INSIDE` on every tick. Named here as a design seam for Matko.
  **Resolved by `6-1d/R13`** (review fix pass 2): neither first nor last -- an in-arc contact is
  absorbing.
- **New read-only accessor `TimingWindow.duration_ticks()`.** R10 required reading the window's
  duration, and `TimingWindow` exposed only `remaining_ticks()`. There is no new write path.
- **New live case `frozen`**, not named in the rulings. It is the mutation evidence the house rule
  requires for the R9 freeze gate, and it also proves the reset clear through the real runner.
  The clearing arm in `push_contact` also clears the bearing, so the two halves stay one fact.
- **Commit trailer** follows this pass's prompt (`Claude Sonnet 5`), which differs from CLAUDE.md's
  constant; LOW-4 therefore not applied.
- No subagents, forks, or parallel sessions. No push.

### This pass (review fix 2, 2026-09-13)

- **The named hazard's premise did not match the code.** The prompt said the commit tick's
  `advance()` turns the facing toward the pushed direction. Measured: step 2 stops `charge_window`
  before `_resolve_movement`, so the facing on the commit tick is the last chargeup tick's aim and
  the commit push does not re-aim it. The rule was implemented as ruled (the arc is never asked of
  the push being latched) and the comment records both the reason and the measured ordering. (a)
  and (b) pin the ordering with a sanity assert.
- **(b)'s fixture adds an out-of-arc touch AFTER the in-arc one.** Taken literally ("out of arc on
  tick 0, in arc later"), a last in-arc touch passes under "always overwrite" too, so it could not
  meet the required mutation. The extra later out-of-arc touches make it fail there, and they test
  the ruling's own words: any in-arc contact wins.
- No subagents, forks, or parallel sessions. No push.

### This pass (close-out, 2026-09-13)

- No subagents, forks, or parallel sessions were used, per the chain prompt's own instruction.
- The Live Smoke Results section reports only what the operator's log states; where the log is
  silent (item 4, the per-colour clamp) it is marked not addressed rather than assumed passing.
- `docs/playtest-log.md` was staged and committed exactly as the operator wrote it; not edited.
