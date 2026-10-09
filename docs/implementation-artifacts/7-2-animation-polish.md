---
baseline_commit: 4e451ee881cb90df7db8d09697bf7dca8e00076f
---

# Story 7.2: Animation polish (upper/lower body split, hit-reaction sliding, orbs as ghosts)

Status: review

Tier **B**, presentation only. Authored 2026-10-09 against HEAD == origin/main == `4e451ee`, tree clean; promoted the same day
after the browser review (Change Log). Golden predicted
UNMOVED (`43449bd9`, FORMAT_VERSION 22); `src/state/` diff predicted EMPTY. **Raised to Tier A** if any authored timing window or
any `src/state/` file has to change; the items that would need that are listed under Non-goals and Open Questions and are NOT authored here.
No budget is stated. No new R labels: rulings are described in words and numbered at close-out.

## Story

As a player, I want my hero's legs to keep walking while the upper body blocks, flinches or casts a gesture, so that nothing
glides across the floor in a static pose; and I want the orbs around each hero to be harmless ghosts, so that they never shove
anyone and never turn into one blob.

## Scope (operator, 2026-10-09)

1. **Split.** While the hero translates from player locomotion, the legs play the locomotion clip the hero already selects
   (idle, walk, run, strafe, backpedal) and the upper body plays the action: the block pose and deflect, the hit reaction, card
   gestures, a swing for Rocksling stones 2 and 3, and every other moment where the hero moves while a clip that does not walk is
   playing. A hero standing still looks exactly as today.
2. **Whole body stays** for actions that carry the hero themselves: the melee attack with its lunge, roll, unblockables, colour
   counters, knockdown and get-up, death, and standing casts (Honed Bolt, Fireball, the Rocksling lift).
3. **Gestures.** Every card effect without its own clip gets the existing `cast_buff` gesture, upper body only while moving.
4. **Hit reaction while walking or running no longer slides** (`deferred-work.md:260-269`).
5. **Owned deferred items:** P19 Rocksling lift-to-throw hard cut (`:605`); the stun pose transition and foot sliding during
   casts (`:607-608`). Cast speed is out of this story (Non-goals).
6. **Orbs are ghosts.** They never push each other, the heroes or minions and pass through everything; each keeps its own path,
   two may overlap briefly but never settle into one; they stay public and the count stays readable; they keep orbiting with
   inertia as 7-6 shipped them.

## Acceptance Criteria

**Split (scope 1, 2)**

1. A hero translating under player locomotion while BLOCKING shows the block pose on the upper body and the locomotion clip the
   hero would play unblocked (walk family: block is forced to walk pace, `match_state.gd:7562-7566`) on the legs. **The split
   rule for every AC below:** while split, `mixamorig_Hips` belongs to the legs and the upper layer is the `mixamorig_Spine`
   subtree; a hero standing still keeps the whole-body clip as today. If an upper half looks wrong without its own Hips motion,
   the dev pass reports it and does not change this rule. Block ENTRY
   remains an instant cut of the block pose (`3-0b/R23`: the deflect window opens on the entry tick); block EXIT still blends as
   `3-0b/R24` set it. A block pressed while standing looks as today.

   **Amended (operator live smoke 2026-10-09).** In every split (block, block_impact, hit_react, gestures, spell
   follow-through) the upper body keeps the facing it has in its own action clip, in the character's own frame,
   whatever the legs' clip does to the Hips: under lock-on the chest and shield point at the opponent while walking
   forward, backward and strafing left and right, and through a direction change; without lock-on they face the
   hero's own facing, as today. The walk may still add its bob and small sway.
2. A `block_impact` (the blocked-hit reaction) and the deflect read on the upper body while the hero moves, legs keep walking.
3. A `hit_react` taken while walking or running plays on the upper body, legs keep the locomotion clip, and the hero no longer
   appears to slide (item 4). Standing still: today's full-body `hit_react`, unchanged.
4. A card gesture (`cast_buff`, and the Counterspell swing) plays on the upper body while the hero moves, instead of being
   refused (`animation_controller.gd:1397-1399`) or cut by movement (`:913-919`). Standing still: full body as today.
5. Rocksling stones 2 and 3 each get a throwing swing on the upper body, whether the hero is moving or standing still. Each
   swing's RELEASE FRAME lands on that stone's spawn (`match_runner.gd:3509`): authored timing wins and the animation serves it
   (the strike-alignment rule used elsewhere). The swing therefore STARTS BEFORE the spawn, is timed from the authored stone
   interval (`boulder_interval_seconds` in `data/effects/rocksling.tres`), and fits inside that interval; nothing is stretched.
   If no usable swing fits in the interval, the dev pass reports it. If the hero enters an AC 7 action during the burst, the
   remaining swings are dropped and the stones fly anyway. Stone 1 keeps the existing cast throw.

   **Amended (operator live smoke 2026-10-09).** Stones 2 and 3 fly WITHOUT a swing, as before 7-2: the re-played
   swings looked worse than none and are removed. Stone 1's lift -> throw keeps the AC 10 cross-fade, and after the
   strike the throw follows through at native rate (on the upper body while the hero moves, AC 6); no later stone
   re-seeks or restarts it.
6. The follow-through of a struck Rocksling/Fireball cast (`animation_controller.gd:1305-1315`) plays on the upper body when the
   hero walks off during it, so a hero that moves after the strike does not slide in the throw pose.
7. These stay WHOLE BODY with no split: attack (with lunge), roll, CHARGING (chargeup and launch), colour counters including the
   victim's held pose, STUNNED/knockdown/dizzy, get-up, death, and the casts Honed Bolt, Fireball and the Rocksling lift/throw
   window (the hero is rooted for all of them, `match_state.gd:7376-7377`).
8. A hero that is split and then enters one of the AC 7 actions (a roll pressed mid-block, a death mid-flinch) shows that action
   on the whole body with no leftover upper-body layer on the next frame; and a split that ends (flinch finished, gesture
   finished) returns the upper body to the locomotion clip without a hard cut larger than today's locomotion blend. A gesture
   whose effect resolves while one of these whole-body actions is playing is DROPPED, not queued: the action wins.

**Gestures (scope 3)**

9. Every instantly-resolving hero card effect that has no clip of its own plays `cast_buff` on resolution: see M4 for the list.
   Vampiric Aura, Frostbite and Counterspell keep what they play today. The list is the effects with a reversal kind (M4);
   Bloodlust and Boulder discard are excluded (Non-goals).

**Deferred items (scope 5)**

10. **P19.** The Rocksling lift-to-throw junction no longer hard-cuts: the two clips cross-fade, or the throw begins from the
    lift's pose, with the release frame still landing on the strike tick (`spell_cast_pose`, `:1346-1359`, is pinned by its
    existing tests and its timing does not change).
11. **Stun pose transition.** Entering `stunned`/`knockdown`/`dizzy` (`:1226`, instant `_restart`) and leaving a non-knockdown
    stun for idle (`:788`, instant) blend instead of cutting. The entry blend is short enough that the hit still reads at once;
    its length is a named presentation knob judged at the smoke, and the dev pass picks the starting value. A counter victim's
    held pose keeps its 7-10 behaviour.
12. **Foot sliding during casts.** The hero is rooted for the whole cast window, so the remaining slide is the post-strike
    follow-through (AC 6). Done when no cast clip plays under a translating hero.

**Orbs (scope 6)**

13. No orb is pushed by, or pushes, anything. The hero-body push-out in `OrbHalo._outside_body` (`orb_halo.gd:138-144`) is removed
    so an orb passes through its own hero as it does through everything else. This supersedes 7-6/P16 on the operator's
    instruction of 2026-10-09; its pin, `test_history_and_orbs_live.gd:152-267`, is replaced by a ghost pin.
14. No two orbs ever settle onto one position: across a probe long enough for every pair to cycle, no pair stays within overlap
    distance continuously. Brief overlap is allowed. Orb count per colour stays exact (`shown_counts()`), orbs of both heroes are
    visible in both halves, and the P10 no-collision pin (`test_history_and_orbs_live.gd:101-111`) still passes unchanged.
15. Orbs keep 7-6's behaviour otherwise: own orbit speed, radius and height wobble, exponential follow with inertia, newly shown
    orb appears at its target.

**Tier B proof**

16. Before/after measured: the golden (`43449bd9`) and the snapshot key set unmoved, `git diff --stat src/state/` empty,
    `FORMAT_VERSION` 22. Existing suite counts before == after except the named replaced/added tests.
17. `connect_*` seam family does not grow (TEN, per `animation_controller.gd:969`); no `_physics_process` added (F1); `Input.*` untouched (D3a).
18. The layered blend is recorded as an **ARCH AMENDMENT QUEUE** member for the E7 close-out (a new architectural pattern that
    `6-6a` refused, `deferred-work.md:264-267`). `game-architecture.md` is NOT edited in this story.

## Tasks / Subtasks

- [x] Task 1 (AC 1-4, 6-8): layer the rig. Re-measure each candidate clip's upper half first (M3); decide per clip whole vs split.
  - [x] 1.1 Pick the layering mechanism (M1 shows none exists); keep it hero-local and presentation-only.
  - [x] 1.2 Route block / block_impact / hit_react / gestures / follow-through to the upper layer when `_last_planar_speed` > `RUN_SPEED_EPS`.
  - [x] 1.3 Keep block entry an instant cut and block exit on the existing blend.
  - [x] 1.4 Hips to the legs, upper layer = `mixamorig_Spine` subtree; drop a gesture that resolves during a whole-body action.
- [x] Task 2 (AC 5, 9): Rocksling stones 2/3 swing (release on spawn, from the authored interval); `cast_buff` for the effects with a reversal kind (M4).
- [x] Task 3 (AC 10-12): P19 junction, stun in/out blends with a named entry-length knob, cast follow-through.
- [x] Task 4 (AC 13-15): orbs: remove `_outside_body`, replace the P16 pin, add the no-merge probe.
- [x] Task 5 (AC 16-18): before/after golden + key set + `src/state/` diff; amendment-queue entry; tests committed under `test/`.

## Dev Notes

### Measurements (taken from the repo at `4e451ee`)

**M1 - how clips are chosen today; AnimationTree.**
- One `AnimationPlayer` on the paladin (`hero.tscn:91`, library `paladin_anims.res`), one controller (`hero.tscn:235-237`).
  `AnimationTree` / blend nodes: **none anywhere in `src/`** (grep: 0 hits). No second player.
- Evented path: `on_action_state_changed` (`animation_controller.gd:724-788`) maps ActionState -> one clip through `_CLIP`
  (`:271-277`: IDLE, ATTACKING, BLOCKING, ROLLING, DEAD) via instant `_restart` (`:1438-1440`), CHARGING by colour (`:772-780`),
  STUNNED through `_play_stun` (`:1199-1226`).
- Polled path: `hero.gd:163-198` pushes velocity + facing every tick to `on_locomotion` (`:884-925`). **`:889` returns at once unless
  the state is IDLE**, so BLOCKING never reaches the locomotion choice. In IDLE: cast/counter/one-shot yields (`:903-919`), then
  turn-in-place, then `_locomotion_clip` (`:1157-1173`, five-way split x walk/run family) through idempotent `_play` (`:1185-1188`,
  0.25 s blend).
- One-shots (`hit_react`, `block_impact`, gesture, follow-through) are held by the `_one_shot` yield (`:913-919`).

**M2 - hero moves while a non-walking clip plays.**

| Moment | Clip today | Slides? | Source |
|---|---|---|---|
| BLOCKING, move held | `block` | **Yes** - walk pace, state never reaches the locomotion pick | `match_state.gd:7562-7566`, `animation_controller.gd:889` |
| `block_impact` (blocked hit) | `block_impact` | **Yes** while block-walking | `:850-852` |
| IDLE `hit_react`, walking/running | `hit_react` | **Yes** - the deferred item | `:848-849`, yield `:913-919` |
| Gesture (Aura/Frostbite/Counterspell) | `cast_buff`/`cast_counterspell` | No - refused if moving, cut by movement (this is the gap) | `:1397-1399`, `:913-919` |
| Rocksling/Fireball follow-through | throw/fireball clip | **Yes** - cast window ends, hero free, clip plays on | `:1305-1315`, `match_runner.gd:1806` |
| Rocksling stones 2/3 | none (fly with no swing) | n/a | `:1344-1345` |
| ATTACKING with lunge | `attack` | No - the clip belongs to the lunge | `match_state.gd:7626-7629` |
| ROLLING | `roll` | No - roll carries the hero | `:7378` |
| CHARGING | swipe/thrust/jump_attack | No - chargeup rooted `:7406`, launch is state travel `:7412` | |
| Colour counter RED/BLUE | counter clips | No - state travel `:7506-7522`; GREEN rooted | |
| STUNNED / get-up / DEAD | stun clips / `get_up` / `death` | No - literal zero velocity `:7413-7445`, `:7318` | |
| Cast window (Bolt/Fireball/Rocksling) | `cast*` | No - rooted `:7376-7377` | |
| Block pose during the 7-10 victim hold | held charge clip | No - STUNNED, rooted | `:640-646` |

**M3 - where to split; usable upper halves.** The skeleton uses the Mixamo chain `mixamorig_Hips` -> `mixamorig_Spine` ->
`Spine1` -> `Spine2` -> `Neck`/`Head` + both shoulders/arms; legs are `mixamorig_{Left,Right}UpLeg` -> `Leg` -> `Foot` -> `Toe`
(names confirmed in `tools/measure_torso_envelope.gd:27-31` and `effect_presenter.gd:63`; `paladin_anims.res` is binary, so the
full track list is NOT read here). The natural cut is at `mixamorig_Spine`: upper = the Spine subtree, lower = both UpLeg chains,
and **`mixamorig_Hips` goes to the legs (ruled)** - it carries the root bob/lean, and its planar excursion is what `3-0b/R27` caps at
0.25 m and what the 3-0b smoke saw as the roll ring. Measured Hips planar travel, peak: cast_buff 0.1059, cast_counterspell 0.0750,
cast_fireball 0.0515, rocksling lift 0.1894, throw 0.1537 (`animation_controller.gd:221-223`, `:238`) - all inside 0.25. **Not
measured in the repo: `block`, `block_impact`, `hit_react`.** The dev pass runs `tools/measure_hips_displacement.gd` on them FIRST
and decides per clip whether its upper half is usable (a stagger step or crouch lives in the legs/hips). A clip whose upper half is
not usable stays whole-body and is listed in the close-out.

**M4 - effects without their own clip.** Clips of their own: Honed Bolt (`cast`), Fireball, Rocksling (lift + throw), Counterspell
(`cast_counterspell`), Vampiric Aura and Frostbite (`cast_buff`, `animation_controller.gd:260-264`). **No clip:** summon
(`ruin_vanguard`/totem summons), Culling, Grave Ward, Raise Dead, Drain, Boom, Corpse Bomb, Bloodhound Step, Bloodlust,
Boulder discard (`data/effects/*.tres`; `card_effect_resolver.gd:105-390`). The hook that exists today is the runner's
reversal-kind switch (`match_runner.gd:1938-1965`), keyed on `PlayerState.REVERSAL_*` (`player_state.gd:812-825`): Vanguard,
Culling, Grave Ward, Raise Dead, Drain, Boom, Bloodhound, Corpse Bomb have a kind. **Bloodlust has none** - `match_state.gd:4126-4129`
sets the rule and records no reversal - and Boulder discard maps to `OUTCOME_BOULDER_CLEAR` (`card_effect_resolver.gd:331`) whose
visibility was not traced. Both are excluded from 7-2 (Non-goals).

**M5 - Rocksling cadence vs throw clip.** Three stones, `boulder_interval_seconds = 0.3` (`data/effects/rocksling.tres:9-10`).
Throw clip 2.7 s, release at 1.3275 s (`animation_controller.gd:225-226`), so after stone 1 leaves at the release the clip has
1.37 s left: stone 2 launches +0.3 s, stone 3 +0.6 s, both inside the clip's own follow-through. A swing for them is therefore a
RE-PLAY of the throw's forward swing on the upper body, not a new clip. The release frame lands on each stone's spawn
(`match_runner.gd:3509`), so the swing starts before it and must fit in the 0.3 s interval; the throw's backswing-to-release
(about 0.4 s: backswing deepest at ~0.92 s, release 1.3275 s, `animation_controller.gd:220-221`) is longer than that, so the dev
pass measures what part of the swing fits and reports if none does. Cast window authored 0.8 s; the throw takes `ROCKSLING_THROW_SHARE` 0.55 of it (`:231`).

**M6 - orbs.** `OrbHalo` is a `Node3D` child of its hero, wisps are `top_level` `Node3D` holding two `MeshInstance3D` quads
(`orb_halo.gd:158-173`). **No `CollisionObject3D`, `Area3D`, body or shape, no collision layer or mask** (pinned by
`test_history_and_orbs_live.gd:101-111`, P10). Hero physics layers/masks (`hero.tscn:104-115`: bodies 4/2, hurtbox 2/0) never see
a wisp. There is **no orb-vs-orb separation or avoidance code** (each wisp's target is a pure function of its index and the halo
clock, `:149-155`); inertia is a per-wisp exponential approach (`:131`). The ONLY displacement logic is `_outside_body`
(`:138-144`, `7-6/P16`): a visual clamp that bends a wisp's path around its OWN hero's body radius `0.42 m`. It moves the wisp, never
a body. **The operator premise (orbs push things) is not true of the code; nothing an orb does can touch a body the state owns,
so item 6 stays Tier B.** The real delta is removing P16's push-out (AC 13) and proving no merge (AC 14). The state side
(`OrbPool`, `orb_pool.gd`) holds counts only, no positions.

**M7 - P19 and the stun transition.**
- P19: `spell_cast_pose` (`:1346-1359`) returns `cast_rocksling_lift` for `t < lift_part` and `cast_rocksling_throw` after; the
  controller applies it by `_restart(clip, 0.0)` + seek (`on_cast_progress`, `:1322-1331`). `_restart` has no blend by default
  (`:1429-1440`), so the clip changes on one tick: the hard cut. The release frame must keep landing on the strike tick.
- Stun transition: entry `_play_stun` -> `_restart(clip, speed, blend=-1)` (`:1226`); `blend` is only passed by 7-10's victim
  release (`:1046`). Exit: `STUNNED -> IDLE` falls to `_restart(&"idle", 1.0, -1.0)` (`:781-788`). Only `get_up` follows a knockdown
  (`:753-759`). Both edges are instant today.

### Implementation guardrails

- Presentation-only: `animation_controller.gd`, `hero.gd`/`hero.tscn`, `orb_halo.gd`, `match_runner.gd` call sites. Never `src/state/`.
- The controller reads `_last_planar_speed` (`:669`), already pushed per tick; reuse it for "is the hero translating". Do not add a
  `connect_*` seam, a `_process` to the controller, or a state read.
- Hitstop (`set_frozen`, `:1016`) must freeze both layers. The 7-8/7-10 charge/counter presentations stay as they are.
- Left/right naming convention in the controller header (`:74-77`) applies to any new strafe-aware leg choice.

### Project Context Rules (from `docs/project-context.md` and CLAUDE.md)

- F1 one `_physics_process` (match_runner); D3(a) `Input.*` only in `src/controllers/`; D3(b)/A2 no global RNG/Time/OS/Engine in `src/state/`.
- Golden unmoved is the Tier B proof; measure before/after, never assert. Tests for anything worth proving go under `test/`.
- Authored balance values are isolated from the unit suite (BC/R3): nothing here edits a `.tres` timing value.
- Docs and code never share a commit; commit messages ASCII via `git commit -F`; trailer per the harness reminder.

### References

- `deferred-work.md:260-269, :605-608, :637-638`; GDD `epics.md` E7 item 3; sprint-status `story_notes`.
- `3-0b/R23`, `3-0b/R24`, `3-0b/R27`, `6-6a` (layering refused), `7-6/P10`, `7-6/P16`, `7-1` polish round, `7-10`.

## Non-goals

- **Cast speed.** Playback is already native for every cast clip (`6-5c`, `7-1`); the only remaining knob is the authored 0.8 s cast
  window, a timing window that belongs to `7-7` (and would make this Tier A). Owner: `7-7`. The deferred-work owner line is
  rewritten at close-out, not here.
- **Bloodlust and Boulder discard get no gesture.** Neither has a fact the runner can read (`match_state.gd:4126-4129` records no
  reversal kind); a gesture there needs a new state fact, which is Tier A.
- Minions (`7-3`); turn in place; speed transitions and any number tuning (`7-7`); telegraph cues integrated into animations
  (`deferred-work.md:637`, owner line rewritten at close-out); new Mixamo clips.

## Open Questions

1. **Per-clip upper-half fitness** of `block`, `block_impact`, `hit_react` is unmeasured (M3). A clip with an unusable upper half
   stays whole body and the dev pass reports it; the Hips rule is not changed.

## Live Smoke - solo [0,3] (P2 on the pad performs, P1 on the keyboard is the target)

**Setup flip.** In the `Main` node block of `src/main/main.tscn`, add `slot_controller_kinds = Array[int]([0, 3])` directly under
its `script =` line. Revert with `git checkout -- src/main/main.tscn` before any suite or chain. P2 = pad, P1 = keyboard.

One human, two devices. P1 is the target and acts only where a step says so, with the keyboard hand; P2's hand stays on the pad.
Items marked **(luck)** depend on a P1 attack landing at the right moment: try three times, and if it will not line up, mark the
item [3,3].

| # | Item | P2 (pad) | P1 (keyboard) |
|---|---|---|---|
| 1 | Block-walk (AC 1) | holds block and walks all four directions; then stands blocking | idle |
| 2 | Hit react walking (AC 3) | walks and runs across the floor; once stands still | casts Fireball at P2 (homing, lands mid-walk, always hits, no timing luck) |
| 3 | Block impact / deflect walking (AC 2) **(luck)** | holds block and walks toward P1 | taps the basic attack as P2 comes into reach; repeat for the deflect by pressing block just before P2's swing |
| 4 | Gestures moving (AC 4, 9) | plays Vampiric Aura, Frostbite and each effect with a reversal kind while walking, then standing | idle |
| 5 | Gesture dropped (AC 8) | presses a gesture card while rolling or attacking; the action must stay whole body | idle |
| 6 | Counterspell moving (AC 4) | counters while walking | casts Fireball at P2 |
| 7 | Rocksling stones 2/3 (AC 5) | casts Rocksling, walks away right after the strike, then repeats standing; then rolls mid-burst | idle |
| 8 | Follow-through (AC 6) | casts Fireball, walks off at the strike | idle |
| 9 | Whole-body actions (AC 7) | attack with lunge, roll, charge, then dies | holds attack to charge-and-launch at P2 (hold-to-charge); kills P2 by repeated hits |
| 10 | Mid-state change (AC 8) **(luck)** | rolls mid-block; takes a hit and rolls mid-flinch | Fireball P2, then attack |
| 11 | Lift-to-throw junction (AC 10) | casts Rocksling standing and watches the junction | idle |
| 12 | Stun blends (AC 11) | deflect-stun: swings into P1's block. Bolt stun: stands. Colour-counter stun and knockdown: holds a charge | deflect: holds block just before P2's swing **(luck)**. Bolt: casts Honed Bolt at P2. Counter and knockdown: plays the colour counter against P2's charge |
| 13 | Orbs (AC 13-15) | banks several orbs of one colour, walks through P1 and through a minion | summons a minion and stands in the way |

Nothing here needs two humans acting at the same instant. No item is marked [3,3] up front; any **(luck)** item that will not line
up in three tries is reported as needing [3,3].

## DEVIATIONS

1. **Orb premise.** The operator wrote that the orbs "become ghosts"; they are already collision-free (M6). The story therefore
   removes the hero-body push-out and pins no-merge. The push-out removal supersedes 7-6/P16 on the operator's instruction of
   2026-10-09; its pin test is replaced, not deleted silently.
2. **Template.** `template.md`'s `### Project Structure Notes` is folded into Implementation guardrails.
3. **Epic status** was not touched: the skill's first-story rule does not apply (7-1 exists and is done).
4. **Not read at authoring:** the binary `paladin_anims.res` track list and any clip's per-bone motion (M3), and Boulder-discard
   visibility (M4, now a Non-goal). Both are dev-pass first steps.

## Change Log

| Date | Change |
|---|---|
| 2026-10-09 | Authored (Status `authored`), M1-M7 measured against `4e451ee`. |
| 2026-10-09 | Browser review rulings applied and promoted to `ready-for-dev`: orbs pass through their own hero (supersedes 7-6/P16); cast speed and the Bloodlust/Boulder-discard gestures moved to Non-goals (old AC 13 and Open Questions 1-2 removed, ACs renumbered to 18); Hips goes to the legs; gestures during whole-body actions are dropped; Rocksling swings release on the stone spawn; stun-entry blend length is a named knob; Live Smoke made concrete with the controller flip. |
| 2026-10-09 | Dev pass (Tier B held): `LegLayer` lower-body modifier + split routing, Rocksling stone swings off the state's burst window, `cast_buff` for every reversal kind, P19 cross-fade, stun entry/exit blends, orb push-out removed. Golden/key set/FORMAT_VERSION unmoved, `src/state/` diff empty. Status `review`; Live Smoke not run. |
| 2026-10-09 | Operator live smoke (solo [0,3]): block-walk split, block release, hit while walking/running, blocked hit while walking, gestures while running, Fireball follow-through, stun edges, orbs as ghosts and fps passed; two findings fixed in the same session -- torso facing (Spine yaw compensation in `LegLayer`; AC 1 amended) and the Rocksling stone 2/3 swings removed (AC 5 amended). The operator's chat checklist numbers are not this story's Live Smoke numbering; see Live Smoke Results. Golden unmoved; Status stays `review`. |
| 2026-10-09 | Review fixes (`_7-2-review.md`, operator dispositions): F1 gesture dropped during the `get_up` one-shot, F2 contact-pose pin committed (GREEN on the real code: the layer does not reach the contact facts), F4 steep-chest guard in the facing compensation. F3/F5/F6/F7 accepted, no change. Golden unmoved; Status stays `review`. |

## Live Smoke Results

Recorded by content (the operator's chat checklist numbering is not this section's table). Solo [0,3]. 2026-10-09; the operator's
own entry is in `docs/playtest-log.md`.

**First round.** PASSED: block-walk split, block release, hit while walking and running, blocked hit while walking, gestures while
running, Fireball follow-through, stun edges (in and out), orbs as ghosts, fps. FAILED: torso facing (under lock-on the shield
pointed about 45 deg to the left while walking; the torso turned with the legs). The Rocksling stone 2 and 3 swings looked worse
than no swing at all.

**Re-smoke after the fix pass.** PASSED: torso facing under lock-on in all four directions and through direction changes; stones
2 and 3 without a swing; lift -> throw; the roll mid-flinch. Operator: "sve je kako treba biti".

## Review Findings

`C:\dev\_7-2-review.md`, verdict **APPROVE WITH FINDINGS**. F1 (gesture not dropped during `get_up`), F2 (contact-pose pin) and
F4 (steep-chest guard) were fixed in the review-fix pass. F3 (facing pin skips the influence ramp), F5 (debug reset mid-split
unpinned), F6 (AC 14 worst overlap 14.73 s) and F7 (smoke coverage by playtest-log prose) were accepted without change.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (`claude-opus-5-5`), Claude Code, gds-dev-story. No subagents.

### Debug Log References

| Run | File (outside the repo) | Result |
|---|---|---|
| before, state | `C:\dev\_7-2-suite-before-state.txt` (mtime 18:13:50) | 1317 tests, 0 failed, 13350 assertions |
| before, integration | `C:\dev\_7-2-suite-before-int.txt` (mtime 18:20:09) | 82/82 PASS |
| after, state | `C:\dev\_7-2-suite-after-state.txt` (mtime 18:46:09) | 1317 tests, 0 failed, 13350 assertions |
| after, integration | `C:\dev\_7-2-suite-after-int.txt` (mtime 18:52:27) | 84/84 PASS (82 + 2 new files) |

Two full runs, no extra; `test_unblockable_reach_live` passed both times. Golden probe (scratch script calling
`test_determinism.gd`'s own `_make_match`/`_play_sequence`): `C:\dev\_7-2-probe-before.txt` and `_7-2-probe-after.txt`
are byte-identical: `43449bd9e513e900...`, top keys 6, per-player keys 46, 258 key paths, `FORMAT_VERSION` 22.
`git diff --stat src/state/` empty; `git diff -- project.godot` empty after both headless editor scans
(`--headless --editor --quit`, for `class_name LegLayer` and the two new test files' `.uid`). Scratch engine probes:
`probe_m3.gd` (M3 measurement), `probe_engine.gd` x2 (pinned-blend and `SkeletonModifier3D` behaviour). Targeted
single-file runs during development: test_hero_reaction_clips, test_spell_cast_clips (x2), test_unblockable_presentation_live,
test_defense_reactions_live, test_cast_presentation_live, test_upper_lower_split (x4), test_history_and_orbs_live,
test_animation_polish_live (x2), plus the mutation runs below.

### Completion Notes List

**M3 / Open Question 1, measured FIRST** (criteria fixed before reading: usable iff Hips planar peak <= 0.25 m, drop
<= 0.15 m, swing <= 25 deg): `block` 0.0055 / 0.0001 / 0.37, `block_impact` 0.0440 / 0.0000 / 10.92, `hit_react` 0.0606 /
0.0050 / 13.08 -- all USABLE, so **no clip stayed whole-body**. For the record the throw clip measures 0.1537 / 0.0866 /
29.53 over its whole length; it is upper-body by AC 5/AC 6, not by this test.

**Mechanism (Task 1.1).** `LegLayer` (`src/actors/hero/leg_layer.gd`), a `SkeletonModifier3D` the controller adds to
the paladin's `Skeleton3D` in `_ready`. The one `AnimationPlayer` keeps playing the action whole-body exactly as before;
the modifier overwrites `mixamorig_Hips` + both UpLeg chains (every Hips descendant not under `mixamorig_Spine`) with a
locomotion clip sampled at its own playhead, weighted by the skeleton's own `influence`. Measured on 4.6.3: a modifier's
output is restored after the frame, so `HeroActor`'s sword/trunk followers (contact facts) never see it. Split starts on
an event snap the legs on at the stride's own phase; a split that ends hands the legs' clip back to the body at that
phase on the locomotion blend; whole-body states drop the layer on the same call; hitstop freezes it.

**Rocksling (AC 5, ruling 2 applied).** The runner pushes `on_burst_progress(owed, ticks_to_stone)` every tick from
`burst_remaining` / `burst_window.remaining_ticks()`. Spawn ticks (owed drops; stone 1 = the strike) show the release
frame; ticks between show `stone_swing_playhead = 1.3275 - ticks/60`, pinned (speed 0). Swing used: one authored
interval (18 ticks = 0.3 s) back from the release, first drawn frame 1.0442 (17 ticks), i.e. starting ~0.12 s past the
backswing's deepest point (~0.92), unstretched. After the last stone the throw follows through at native rate. Any
transition, hit, gesture or cast drops the remaining swings. Smoke item: the upper body snaps from the release pose back
to 1.0442 between stones (inherent to re-playing the swing; no blend added).

**AC 14 (orbs).** Paths unchanged (AC 15). The pin is AC 14's wording: across 2x the slowest pair's relative cycle
(608 s, 15 wisps = 3 x authored cap, the halo's own static path/follow functions at 1/30 s) every pair parts at least
once. MEASURED for the smoke: longest continuous overlap < 0.25 m is **14.73 s (pair 1/6)** -- whether that is "brief" is
the operator's call at smoke item 13.

**Knobs (one block, `animation_controller.gd` "STORY 7-2: EVERY NEW PRESENTATION KNOB"):** `SPLIT_BLEND_SECONDS` =
`LOCOMOTION_BLEND_SECONDS` (0.25); `STUN_ENTRY_BLEND_SECONDS` 0.08; `STUN_EXIT_BLEND_SECONDS` 0.2;
`ROCKSLING_JUNCTION_BLEND_SECONDS` 0.12. The stone swing has no knob (authored interval).

**Replaced pins (named):** `test_spell_cast_clips.gd` 7-1 interim "movement cuts the gesture" / "a moving hero plays no
buff gesture" / "...the clip does not start" -> the AC 4 behaviour; `test_history_and_orbs_live.gd` P16 body-radius pin
-> the AC 13 ghost pin (+ AC 14 probe, + AC 15 appear-at-target check).

**Mutations** (each file backed up outside the repo, run against the one test file, restored by copy-back, SHA-256
matched every time): M1 Spine on the legs' layer, M2 `_begin_split` no-op, M3 `_drop_legs` no-op, M4 7-1 moving refusal
(both test files), M5 swing playhead pinned to release, M6 P19 hard cut, M7 stun entry cut, M8 hitstop doesn't freeze
legs, M9 layer writes no rotations, M10 Grave Ward unmapped, M11 runner gesture call removed, M12 runner burst push
removed, M13 P16 push-out re-added, M14 wisps 1/6 share a path, M15 stun exit cut, M16 no hand-back, M17 new wisp off its
target, M18 swing legs not forced, M20 legs stay on standing, M21 split while standing, M22 BLOCKING ignores the push (run
twice: before and after the AC 2 pin was strengthened), M23 gesture during a roll, M24 follow-through not upper, M25 7-1
movement cut re-added (both files), M26 legs never thaw -- **all KILLED**.

**AC 17:** no `connect_*` added, no `_physics_process`, no `Input.*` (suite invariants green). **AC 18 -- ARCH AMENDMENT
QUEUE entry text for the E7 close-out** (not written to `game-architecture.md` or the decision log here): "7-2: layered
rig presentation -- a per-hero `SkeletonModifier3D` (`LegLayer`) overrides Hips + legs with a locomotion clip under an
upper-body action; the one `AnimationPlayer` stays the action source; modifier output is render-only (restored after the
frame), so contact facts never read it. Refused at `6-6a`; adopted here."

**Deviations:** (1) The board was not written `in-progress`/`review` (its STATUS DEFINITIONS lock
backlog/ready-for-dev/done and on_complete restores it anyway); only on_complete's story_notes/last_updated were applied.
(2) `orb_halo.gd` was edited by a python byte-replace without a prior Edit miss (one multi-hunk replace), and the new test
file `test_upper_lower_split.gd` got one python multi-hunk replace -- both outside the "Edit first" rule. (3) The prompt's
"Open Question 3" is this story's Open Question 1 (renumbered at the browser review); there is no Task 6 -- the Live
Smoke is a section and nothing was ticked for it. (4) The runner's Vampiric Aura / Frostbite arms were folded into the
one `gesture_for_reversal` call (same clip as before). (5) On the Rocksling strike tick the release frame is now HELD
(pinned) for that tick when the swings arm, instead of starting the follow-through at once.

**FIX PASS (operator live smoke 2026-10-09; supersedes the Rocksling paragraph above and its M5/M12/M18 rows).**
- **F1 torso facing.** `LegLayer` reads the action's own Hips and Spine rotations before it writes the legs, then
  re-sets the Spine (root of the upper body) to `upper_facing_spine(...)`: a pure yaw about skeleton +Y, in the
  skeleton frame, so the Spine's forward yaw under the legs' Hips equals what the action's Hips gave it; the walk's
  pitch/roll (bob, sway) still pass through. Applies to every split, since it lives in the layer. Pinned on the
  rendered pose (inside `skeleton_updated`, 40 frames per case): chest (Hips*Spine*Spine1*Spine2) forward yaw vs the
  block clip standing still (its own tracks), tolerance 5.0 deg. Worst error BEFORE -> AFTER: walk 69.36 -> 1.02,
  walk_backpedal 77.78 -> 1.12, walk_strafe_left 7.72 -> 2.12, walk_strafe_right 15.31 -> 0.99, walk -> strafe_right
  change 67.16 -> 1.03.
- **F2 Rocksling.** Removed `on_burst_progress`, `stone_swing_playhead`, `_seek_swing`, `_burst_owed`, `_swing_running`
  (and every reset of it), `_drive_legs`' `forced` parameter, the knob-block note, and the runner's per-tick burst push.
  Stone 1's P19 cross-fade and the native-rate follow-through (upper body when moving) are unchanged. The swing pins are
  replaced: `test_upper_lower_split.gd` `_rocksling_follow_through` (release, native rate, legs on while running) and
  `test_animation_polish_live.gd` Part B (from the strike, through both later spawn ticks, the throw keeps playing and
  its playhead never goes back).
- **Mutations** (one test file each, copy-back restore, SHA-256 matched): F1M compensation removed -> KILLED (all five
  facing cases, 7.7-77.8 deg); F2M runner seeks the throw to the release on a later stone's spawn tick -> KILLED
  ("playhead jumped BACK on stone 2's tick 1.6335 -> 1.3414").
- **Runs.** Single files: test_upper_lower_split x2 (before / after compensation), test_animation_polish_live,
  test_spell_cast_clips, plus the two mutation runs. ONE full suite: `C:\dev\_7-2-fix-suite-state.txt` (21:40:44)
  1317 tests, 0 failed, 13350 assertions; `C:\dev\_7-2-fix-suite-int.txt` (21:46:56) 84/84 PASS. Golden probe
  `C:\dev\_7-2-probe-fix.txt` byte-identical to before (`43449bd9...`, 258 key paths, FORMAT_VERSION 22).
  `src/state/` and `project.godot` diffs empty; no editor scan needed (no new class or file).

**REVIEW-FIX PASS (2026-10-09, operator dispositions of `C:\dev\_7-2-review.md`).** No subagents, nothing committed.
- **F1.** `AnimationController.play_gesture` refuses while `_one_shot == get_up` and that clip is playing (get-up is whole body, AC 7/8; the gesture is dropped, never queued). Pin `test_upper_lower_split.gd::_get_up_gesture`: a moving hero in a knockdown get-up keeps `get_up`, no layer target/weight. Mutation (guard replaced by `if false:`) -> RED, 5 failures; restored.
- **F2.** Pin `test_upper_lower_split.gd::_contact_poses_untouched`, run from the physics tick after rendered frames with the walk-under-block split on and the F1 compensation active: sword, trunk (Spine2), Hips and Spine as `HeroActor._bone_pose_global` (the `drive()` follower FK) equal the AnimationPlayer's own pose composed from the clip tracks. **GREEN on the real code** (so the layer does not reach the contact facts; no Tier A matter). Mutation (the layer re-applies its output on `physics_frame` and `frame_post_draw`, i.e. persists past the frame) -> RED on all four bones (0.22-0.49 m, 1.07 rad); restored.
- **F4.** `LegLayer.upper_facing_spine` returns the action's own Spine when either chest's `|forward.y|` > `STEEP_FORWARD_Y` (0.9). Pin `_steep_facing`: an 80 deg pitch keeps the Spine, a 20 deg one is still compensated. Mutation (guard replaced by `if false:`) -> RED, 1 failure; restored. A first attempt, `if false and A or B`, left B live (operator precedence) and stayed PASS; it was discarded as a flawed mutation, not as evidence.
- Backups outside the repo, restored by copy-back, SHA-256 matched: `animation_controller.gd` `ff18126a...`, `leg_layer.gd` `c2db0e43...`.
- Runs: `test_upper_lower_split` (PASS, facing worst 1.02-2.12 deg), `test_spell_cast_clips` (PASS), three mutation runs; then ONE full suite: `C:\dev\_7-2-revfix-suite-state.txt` (22:22:32) 1317 tests, 0 failed, 13350 assertions; `C:\dev\_7-2-revfix-suite-int.txt` (22:28:56) 84 pass / 0 fail. `test_state_matches_golden` ok, GOLDEN `43449bd9...` unchanged. `git diff --stat src/state/` empty; `project.godot` and `main.tscn` no diff.

### File List

- `src/actors/hero/leg_layer.gd` (new)
- `src/actors/hero/leg_layer.gd.uid` (new, editor scan)
- `src/actors/hero/animation_controller.gd`
- `src/actors/hero/orb_halo.gd`
- `src/main/match_runner.gd`
- `test/integration/test_upper_lower_split.gd` (new)
- `test/integration/test_upper_lower_split.gd.uid` (new, editor scan)
- `test/integration/test_animation_polish_live.gd` (new)
- `test/integration/test_animation_polish_live.gd.uid` (new, editor scan)
- `test/integration/test_spell_cast_clips.gd`
- `test/integration/test_history_and_orbs_live.gd`
- `docs/implementation-artifacts/7-2-animation-polish.md`
- `docs/implementation-artifacts/sprint-status.yaml` (story_notes / last_updated only)

Fix pass (2026-10-09) touched only files already listed: `leg_layer.gd`, `animation_controller.gd`, `match_runner.gd`
(the burst push removed again), `test_upper_lower_split.gd`, `test_animation_polish_live.gd`, this story file.
Review-fix pass (2026-10-09) touched only files already listed: `leg_layer.gd`, `animation_controller.gd`, `test_upper_lower_split.gd`, this story file.
