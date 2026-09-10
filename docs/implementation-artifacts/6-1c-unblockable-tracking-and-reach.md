---
baseline_commit: c7676b3c4292b0307f0004cfb92146ccde99ce38
---

# Story 6.1c: Unblockable Tracking and Reach

Status: authored

> **Scope note.** Adopted into E6 immediately after `6-1b` by operator ruling — named successor
> `6-1c` in the `6-1b` close-out (decision-log.md:9658, :9684). Tier A: adds a new state-machine
> phase to mode ②. VFX is explicitly zero (Non-Goals) despite the close-out label naming it.

## Measured Facts

1. **Tracking during CHARGING already holds today — pinned, not built.** `_resolve_movement`'s
   `CHARGING` branch overrides the general lock with the enemy-HERO auto-aim direction every tick:
   `facing = -aim` where `aim := _charge_reach_dirs[slot]` (`match_state.gd:3421-3424`), written by
   `push_contact` (`:808`) from the runner's `_push_charge_reach_facts()` (`match_runner.gd:637-689`,
   BEFORE `advance()` every CHARGING tick, planar XZ, hero-to-hero only, Ruling 8/`5-2`). This is the
   `elif`-shadowed lock arm (5-2 Ruling 3/Ruling 8): while CHARGING, the enemy-hero auto-aim always
   wins, even when this slot's lock (which since 4-6 can legitimately be a minion) points elsewhere.
   A charging attacker already re-aims at the live enemy hero every tick, overriding its own lock.
   AC 1 is a regression pin, not new work (6-1c/R1).

2. **No launch phase or commit point exists today — new state-machine work.**
   `_resolve_charge_landing` (`match_state.gd:2885-3013`) fires from `_resolve_actions`'s `CHARGING`
   timer-exit arm the instant `charge_window.is_running` goes false (`:990-992`) and resolves landing
   + the `IDLE`/`STUNNED` exit on the SAME tick — no separate `ATTACKING` state for mode ②
   (`6-1b` finding 3). Commit point and launch travel (scope 2/3) need a NEW phase between chargeup
   expiry and landing — a state-machine addition, why this story is Tier A by content, not only golden.

3. **The landing check today is a circle in the runner, not an arc.** `_push_charge_reach_facts()`
   computes `kind := INSIDE if planar.length() <= balance.unblockable_reach else OUTSIDE`
   (`match_runner.gd:678-680`) — one radius for all colours, no angle, derived from positions only,
   never `HeroState.facing`. `_resolve_charge_landing` reads only the KIND (`_charge_reach[slot]`,
   read at `match_state.gd:2888`), never a distance/position (D3(b)/A2 intact). Per-colour geometry
   (scope 4) means `unblockable_reach` goes per-colour and a new arc check joins the radius check —
   but the arc mirrors the 1-8/R-B3 shape (`match_runner.gd:1680-1684`: the runner reports the
   spatial fact from positions only; the arc comparison is state policy), so the arc is evaluated in
   STATE against the frozen committed direction (AC 2), not computed in the runner. Only the runner's
   radius KIND and planar-direction fact cross inward; the arc test itself is a state-side consumer
   of that direction, same as the 1-8 strike path (6-1c/R3).

4. **Facing's existing carve-out ladder is exactly two entries, and the commit freeze is a third.**
   Facing is SKIPPED (held at last value) only on `DEAD` (`2-3/R14`, `:3308-3310`) and the round-over
   freeze (`2-6/R6`, step 1b). The commit freeze must join this ladder BY CONSTRUCTION — the CHARGING
   facing branch simply stops re-reading `_charge_reach_dirs` once committed — not a new flag bolted
   on beside the existing two.

5. **New per-colour fields sit outside `GOVERNED_CLIPS` — no retime triggered.**
   `tools/retime_clips.gd:34`: `GOVERNED_CLIPS := [&"attack", &"roll"]`, driven only by
   `attack_windup_seconds`/`attack_active_seconds`/`attack_recovery_seconds`/`roll_duration_seconds`
   (`3-0b/R26`). None of this story's new fields (travel/reach/arc) are among those four —
   `retime_clips.gd` does not run, no clip content changes, mirroring `6-1b` finding 6.

6. **The single resolution seat (5-5/5-6) is unchanged.** `_resolve_charge_landing`'s ladder —
   colour-match negation, then iframe-dodge, then unanswered full hit — is the ONLY consumer of a
   charge landing. This story's mechanism must resolve into the SAME `_charge_reach[slot]` KIND
   read at `match_state.gd:2888` — no second landing check, no ladder bypass.

7. **The `6-1b` charge-progress contract must survive whatever phase shape this story picks, AND
   this story's launch phase adds a channel `6-1b/R6` never had to cover.** `_push_charge_progress()`
   reads the JUST-TICKED `action_state` synchronously and relies on it leaving `CHARGING` on the
   exact window-close tick to structurally prevent a stale push (`6-1b/R6`). That contract is about
   the CHARGING→exit edge, not about what happens across the launch span this story inserts after
   it: today the last visible tick IS the strike frame IS the damage tick, so nothing plays "under"
   the strike; this story separates window-expiry from landing, so whichever phase shape is chosen
   must also drive a progress channel across the launch span that keeps the visible strike frame
   pinned to the resolution tick (the honesty rule, AC 11) — `animation_controller.gd` is in scope
   for this, not unchanged. Staying in `CHARGING` through commit+launch leaves the CHARGING-exit
   contract unchanged by construction; adding a new `ActionState` requires re-verifying it
   (DEV-PASS DECISION, Open Questions), with a direct test if touched, AND requires a new launch
   progress channel from scratch since the CHARGING guard in `_push_charge_progress` would no longer
   fire for it.

8. **A per-colour triplet is the RIGHT shape here — the opposite of `5-2` Ruling 2's reasoning for
   damage.** `unblockable_damage_percent_of_max_hp`/`unblockable_orb_grant` stay single global
   values on purpose: "no `unblockable_*_red/blue/green` triplet here to become a second source of
   truth for a value the LATER STORY will author properly" (`balance_config.gd:317-323`, :369-372).
   Reach/travel/arc ARE that later story's numbers.

## Story

As the operator closing the Sekiro-grammar commit debt named at `6-1b` close-out,
I want a charging unblockable to keep tracking its locked target through the chargeup, then freeze
its attack direction at the charge-to-launch transition and carry the attacker forward along that
frozen line with per-colour authored reach and travel,
so that dodging sideways after the attacker commits produces a real whiff, and each colour's honest
threat shape (thrust narrow/long, swipe wide, jump radial) reads correctly at its own authored
reach.

## Acceptance Criteria

**Tracking (regression pin, Fact 1).**

1. While `CHARGING`, facing tracks the ENEMY HERO via the charge-reach fact (`_charge_reach_dirs`)
   every tick, OVERRIDING this slot's general lock (`5-2` Ruling 3/Ruling 8) — a hero locked onto a
   MINION but charging still faces the enemy hero, not its lock. Regression pin, not new work; the
   pin must cover the locked-onto-a-minion case, since the hero-to-hero case alone cannot
   distinguish the override from the lock (6-1c/R1).

**Commit point.**

2. At the charge→launch transition, the attack direction is captured and held FIXED for the rest
   of the attack (launch + landing) — no further re-aim or steering from any input or target
   movement, until the attack resolves and the hero returns to `IDLE`/`STUNNED`.
3. A defender inside the committed line at the commit tick who has moved clear of it by the moment
   reach is evaluated (AC 5) produces a MISS — dodging after commit must whiff. A defender that
   enters the frozen line after commit and is INSIDE it at the moment reach is evaluated (AC 5) IS
   hit — the freeze is on direction, not a defender lock.

**Launch travel.**

4. The launch phase moves the attacker forward along the frozen direction (AC 2) at per-colour
   authored FIXED distances, never adaptive to target distance.

**Honest reach.**

5. Landing resolution uses per-colour authored geometry: RED (swipe) wide arc, BLUE (thrust)
   narrow/long line, GREEN (jump_attack) radial. The runner computes the per-colour radius KIND from
   positions and pushes the planar direction fact FROM POSITIONS ONLY — mirroring the 1-8/R-B3
   shape, the runner never reads `HeroState.facing`; the arc comparison is STATE policy, performed
   against the frozen committed direction (AC 2) using the per-colour authored arc field (6-1c/R3).
   Still crosses as a KIND only, never a distance/position/angle (D3(b)/A2). Numbers are feel knobs
   tuned at live smoke, not fixed here.

**Resolution seat and facing ladder (structural, Facts 4/6).**

6. The mechanism resolves through the EXISTING single seat (`_resolve_charge_landing`'s
   colour-match → dodge → full-hit ladder) — no second landing check, no ladder bypass.
7. The commit-time facing freeze joins the DEAD (`2-3/R14`) and round-over (`2-6/R6`) carve-outs
   without changing either — both regression-pinned, unedited.

**Determinism and golden.**

8. The full suite passes (`bash test/run_all.sh`).
9. `_push_charge_progress`'s tick-ordering contract (`6-1b/R6`, Measured Fact 7) is re-verified
   against whatever phase shape this story picks, with a direct test if the mechanism touches it,
   AND the new launch progress channel (AC 11) is proven to key off the SAME window-close edge so
   it cannot fire stale, mirroring the guarantee `6-1b/R6` gives the chargeup progress push.
10. Golden Prediction is measured, both directions — see the Golden Prediction section below.

**Honest strike timing (closes 6-1c/R2).**

11. The visible strike lands on the tick damage actually resolves, never before. The chargeup
    window continues to map to the pre-strike portion of the clip (`6-1b`'s progress-driven
    playhead); a new launch progress channel extends that mechanism across the launch span so the
    strike swing itself plays DURING the launch, arriving at the strike frame exactly on the tick
    `_resolve_charge_landing` fires — never a frozen strike-pose glide while the hero travels.
    `animation_controller.gd` is in scope for this AC (withdrawn from Non-Goals/"NOT expected to
    change"). The chosen phase shape (Open Questions) owns the mechanism; this AC is the
    verifiable claim it must satisfy.

## Non-Goals

- No VFX of any kind — default zero. If max-reach hits read as ghost hits on smoke (item 5, Live
  Smoke), that is a NAMED TRIGGER for a follow-up VFX story, not built here. (Corrects the `6-1b`
  close-out successor label, "aim/reach/travel + reach VFX" — VFX is explicitly out.)
- No new Mixamo/animation clips — the three existing charge clips (`swipe`/`thrust`/`jump_attack`)
  are unchanged; launch-travel feel comes from state-side displacement (AC 4), not new content.
- No new attack shapes — a lunging thrust or a 360° sweep are future card content, not this
  story's per-colour arc/reach parametrisation of the EXISTING three attacks.
- BLUE-gets-its-own-clip stays an open question inherited from `6-1b`, not decided here.
- Minions and totems untouched — mode ② is hero-only (Ruling 8, unchanged).
- F-9 (`ORB_COLORS` upper-bound guard, `6-0/R4`, decision-log.md:9447) remains unowned/unrelated.
- No retune of `unblockable_chargeup_seconds`, `unblockable_stamina_cost`, or
  `unblockable_damage_percent_of_max_hp`/`dodged_unblockable_damage_multiplier`.

## Golden Prediction

**Measure both directions — this is not a substitute for the measurement.**

- The golden fixture (`GOLDEN = d5bcb7e63423ada259c69be8276396db071bb0de1bcb55a2ce8c664ad07eb87d`,
  `test_determinism.gd:891`) has NEVER cast mode ② and no hero in it has ever entered `CHARGING`
  (`:699-700`, restated unchanged through `5-5`/`5-6`/`6-1`/`6-1b`). This story's mechanism — commit
  freeze, launch phase, per-colour geometry — is unreachable by the golden sequence, same reason.
- **Net prediction: golden hash and the 30-key snapshot set NOT TO MOVE**, inverse form (`4-6a`
  precedent) — UNLESS the chosen phase shape adds a NEW hashed field (e.g. a stored committed
  direction on `HeroState`/`PlayerState`, needed only if the freeze can't be reconstructed from
  existing fields). A new field is a snapshot-key mover by the `5-2`/`5-5` shape (presence alone
  moves the hash) regardless of whether the golden ever reaches `CHARGING` — name that as the cause
  if it happens, not "presentation" or "reach" by assumption.
- **Suite level that catches the new behaviour:** `test_unblockable_initiation.gd`/
  `test_unblockable_defense.gd`/a new `test_unblockable_tracking_and_reach.gd` (headless) plus
  `test/integration/` for live per-colour geometry, mirroring the `6-1`/`6-1b` split.
- `FORMAT_VERSION` (8, `record_file.gd:171`) predicted UNCHANGED — no new input channel; the
  commit direction is derived state, not a recorded input.

## Live Smoke

Single physical pad, flip `[0,3]` (KEYBOARD_P1 + GAMEPAD on slot 1 — a killable, human-driven
slot). **R-D6 smoke acceptance re-invoked at this gate (6-1c/R4):** the residual defects R-D6
originally accepted (a dead hero could walk; a corpse mid-swing could be credited) are fixed and
shipped since story 2-3 (`match_state.gd:3308-3310` zeroes velocity and returns on DEAD), so the
substantive acceptance is moot here — but its BINDING COLLATERAL PROCEDURE is not, and applies to
this smoke unchanged:

- Flip `[0,3]` edited TEXTUALLY with the editor closed.
- `git diff` immediately after adding the flip, and again immediately after removing it.
- After any editor session, `git diff -- project.godot` and revert any collateral change:
  `git checkout -- src/main/main.tscn project.godot` (full paths, both files).
- Editor reload dialog: always "Reload from disk", never "Ignore external changes".
- Re-check `git status` + the collateral diff immediately before any commit chain begins — not
  earlier in the session.

1. Strafe around a charging opponent — he keeps facing you the whole charge window (AC 1; the
   locked-onto-a-minion override variant is covered by the state regression pin, not smoke).
2. Dodge sideways just after launch, each colour — the attack whiffs past you (AC 2/3).
3. Each colour visibly covers ground on launch — GREEN reads as a real leap, not a step (AC 4).
4. Walking backward at mid range no longer escapes a committed unblockable once launch begins.
5. Max-reach hits do not read as ghost hits — if they do, note as a VFX follow-up trigger, don't fix here.
6. Regression: melee lunge unchanged; mode ③ defense-by-colour/dodge still answer via the same seat.
7. The blade arrives when the damage lands, not before (AC 11) — no frozen strike-pose glide
   during launch travel.
8. fps stable.

Feel knobs (per-colour travel/reach/arc) must be named, editable authored `.tres` values; tests
must NOT pin their numbers (`6-1b` precedent — operator tuning never requires a suite run).

Dev Note: the `6-1b` hold knobs (`_CHARGE_HOLD_KNOBS`) may need slight re-tune once the launch
progress channel (AC 11) is live and visible on smoke. The knobs themselves stay as `6-1b` closed
them; feel tuning reopens at retune per `6-1b/R9`, not as a change owed by this story.

## Dev Notes

### Open Questions for the dev pass (named, not pre-ruled)

- **Phase shape for commit+launch**: a new `ActionState` (e.g. `LAUNCHING`) versus a sub-phase flag
  kept inside `CHARGING`. A new state touches `TRANSITION_TABLE`'s zero-inbound-CHARGING guard and
  the `6-1b` progress-push contract (Fact 7/AC 9); a sub-phase flag avoids both but needs its own
  re-entry guard. Name the choice and why.
- **Where the committed direction is stored.** If not derivable from existing fields at the moment
  reach is evaluated, a new field is needed (the golden-mover candidate above). Prefer deriving it
  from `HeroState.facing` at the commit tick (read, not stored) if the phase shape allows.
- **Per-colour geometry authoring shape**: separate `@export` triplets vs. a small resource/array
  indexed by colour (the `unit_kinds` precedent, `balance_config.gd:187`). Name the choice.
- **Launch span** the travel distance divides by (the `3-0b` lunge precedent uses
  `attack_windup_seconds + attack_active_seconds`, authored distance over an authored span applied
  as velocity during the committed phase) — needs its own authored span, likely per-colour.
- **Launch progress channel (AC 11).** How the `6-1b` progress-driven playhead mechanism
  (`charge_playhead_seconds`) extends past the chargeup window to drive the strike swing across the
  launch span, so progress 1.0 lands at the resolution tick rather than at window-close. Whether the
  travel plays under the strike swing (retiming window/travel so progress 1.0 = resolution) or under
  a follow-through is Matko's call (design), not a dev-pass one — the mechanism that implements
  whichever is ruled is the dev's. The honesty rule itself (AC 11) is not open; only the mechanism is.

### Files expected to change

- `src/state/match_state.gd`: `CHARGING` exit arm / new launch phase, commit-time facing freeze;
  `_resolve_charge_landing`'s reach-kind consumption stays the same seat.
- `src/main/match_runner.gd`: `_push_charge_reach_facts` grows per-colour geometry, still a KIND.
- `src/state/resources/balance_config.gd` / `data/balance/balance_config.tres`: new per-colour
  travel/reach/arc fields.
- `src/state/timing/balance_ticks.gd`: only if a new *_seconds field needs tick conversion.
- `src/actors/hero/animation_controller.gd`: WITHDRAWN from "NOT expected to change" (6-1c/R2) —
  the launch progress channel (AC 11, Open Questions) is in scope here; no new clip, but the
  `charge_playhead_seconds` mapping extends past the chargeup window.
- Tests: new `test/state/test_unblockable_tracking_and_reach.gd` plus `test/integration/` coverage
  for live geometry against hero positions.
- **NOT expected to change:** `retime_clips.gd` (Fact 5); any new Mixamo clip content; any VFX
  resource (Non-Goals); `intent_recorder.gd`/`record_file.gd` (`FORMAT_VERSION` stays 8).

### Project Context Rules

- **HARD RULE — State/visual separation.** The commit freeze and launch travel are state-layer
  decisions; presentation only reacts to whatever `action_state`/phase facts result. [Source:
  CLAUDE.md; project-context.md]
- **D3(b)/A2 — no world coordinates in `src/state/`.** The per-colour geometry check stays in the
  runner (Measured Fact 3/6); state receives only the KIND. [Source: CLAUDE.md]
- **CONSTRAINT C — read balance inline.** All new per-colour fields read fresh at point of use,
  never cached. [Source: project-context.md]
- **Data as Resources.** Travel/reach/arc are authored `.tres` values, tunable without recompiling,
  isolated from the golden/unit suite per `BC/R3` (unless a new hashed field is added — see Golden
  Prediction). [Source: project-context.md]
- **Guard mechanism over guard pattern.** The commit freeze must be reached BY CONSTRUCTION (the
  facing branch stops re-reading the live aim once committed), not by a flag an adversarial mutation
  could leave stale. [Source: project-context.md, "Testing Rules"]

### References

- [Source: decision-log.md Session 2026-09-09 — `6-1b` close-out, named successor `6-1c`
  (:9658, :9684); :9447 (`6-0/R4`, F-9, unrelated/unowned)]
- [Source: docs/implementation-artifacts/6-1b-chargeup-presentation.md — finding 3 (no ATTACKING
  state for mode ②), AC 8 (no travel — this story's scope), Non-Goals]
- [Source: docs/implementation-artifacts/6-1-hold-to-charge.md — CHARGING exit-arm precedent, the
  paid-feint teardown this story's commit point must not disturb]
- [Source: src/state/match_state.gd:990-992 (CHARGING timer-exit arm), :2885-3013
  (`_resolve_charge_landing`), :3406-3424 (CHARGING facing branch, Fact 1), :3308-3310
  (DEAD carve-out), :3539 (`_attack_lunge_velocity`, header from :3509, 3-0b), :808 (`push_contact`
  writing `_charge_reach_dirs`)]
- [Source: src/main/match_runner.gd:637-689 (`_push_charge_reach_facts`), :678-680 (radius KIND
  compare), :1680-1684 (1-8/R-B3 rule: runner never reads facing, arc is state policy)]
- [Source: src/state/resources/balance_config.gd:317-378 (Unblockable group, Ruling 2, Fact 8),
  :187 (`unit_kinds` precedent)]
- [Source: tools/retime_clips.gd:34 (`GOVERNED_CLIPS`, Fact 5)]
- [Source: test/state/test_determinism.gd:699-700 (golden never casts mode ②); :891 (`GOLDEN`)]
- [Source: test/state/test_card_observation.gd:307 (THIRTY-key snapshot pin)]
- [Source: test/state/test_architecture_invariants.gd:309 (nine-seam guard)]
- [Source: src/systems/record_file.gd:171 (`FORMAT_VERSION := 8`)]
- [Source: src/actors/hero/animation_controller.gd:166-176 (`charge_playhead_seconds`), :92-96
  (strike-frame timestamp), :210-215 (CHARGING entry pins the playhead) — the mapping AC 11's
  launch channel extends]
- [Source: src/main/match_runner.gd:709-723 (`_push_charge_progress`, CHARGING guard, 6-1b/R6)]
- [Source: decision-log.md:456 (R-D6 acceptance, SPENT, must be re-invoked per-story, 6-1c/R4)]
- [Source: data/balance/balance_config.tres:126-130 (`unblockable_*` block, unchanged per Non-Goals)]

## Tasks / Subtasks

- [ ] Read all cited line ranges above before writing code (AC: all)
- [ ] Decide the commit+launch phase shape and committed-direction storage (Open Questions) (AC: 2, 3, 9)
- [ ] Write the regression-pin test for AC 1 (tracking already holds) (AC: 1)
- [ ] Implement the commit-time facing freeze, verified against DEAD/round-over (AC: 2, 3, 7)
- [ ] Implement per-colour launch travel off the 3-0b lunge shape (AC: 4)
- [ ] Extend the runner's reach-kind computation to per-colour geometry, still a KIND (AC: 5, 6)
- [ ] Author per-colour travel/reach/arc fields in `balance_config.gd` + `.tres` (AC: 4, 5)
- [ ] Confirm the `6-1b` progress-push contract against the new phase shape (AC: 9)
- [ ] Implement the launch progress channel so the strike swing lands at resolution, not before (AC: 11)
- [ ] Measure BEFORE/AFTER golden hash + 30-key snapshot set (AC: 10)
- [ ] Run the full suite (`bash test/run_all.sh`) (AC: 8)
- [ ] Live smoke with a single physical pad, flip `[0,3]` (see Live Smoke)

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
