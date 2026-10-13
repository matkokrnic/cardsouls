---
baseline_commit: fd07ecd30bd38743ad0d4726f1832357137fb871
---

# Story 7.5b: Deck 2 bodies (Healer, Elemental Fury, Wrath of God)

Status: authored

Tier **A** (new hashed facts, a new refusable outcome, new spatial facts on the contact intake, a record-format bump, a new
unit kind). Authored 2026-10-14 against HEAD == origin/main == `fd07ecd`; the only untracked entry is
`assets/characters/healer/` (six `.fbx`, no `.import` yet). Card text is `docs/planning-artifacts/deck-2-spec.md` (costs,
colours, pairings and speeds are NOT restated here). Behaviour below is the operator's scope rulings of 2026-10-14 (create
prompt), not yet in the decision log, so no `7-5b/R..` label is cited (E6-R/R10, OQ-0). Behaviour and acceptance, not
mechanism (E4-R/R4). Every number is a TEMP starting value in `.tres`, never a literal in `src/`.

## Story

As a Deck 2 player, I want the Healer, Elemental Fury and Wrath of God to do what their cards say, so that the "tall"
deck has its body, its orb payoff and its area answer instead of three refused halves.
As the operator, I want all three smoke-legible with placeholder visuals, so that I can judge them before any real art.

## Scope

- The three halves 7-5a left refused become real: **Healer** (normal half of Healer / Stoneskin), **Elemental Fury**
  (pitch half of Manablossom's card), **Wrath of God** (pitch half of Manapulation's card).
- `CardEffectResolver.UNAVAILABLE_EFFECT_OWNERS` ends EMPTY; the mechanism may stay (the `DEFERRED_EFFECT_OWNERS` resting
  state, `card_effect_resolver.gd:216-223`). The Healer rig is committed on this story's code chain. Nothing else changes.

## What this story supersedes

- `7-5a` AC 13-15, AC 57 and smoke point 9 (the temporary refusal; "nothing of Healer's body ... is built"); `7-5a/R29`
  and `7-5a/R33` are discharged. The "refused halves get no resolver-known id" rule ends here.
- The pins asserting the refusal: `test_card_authoring.gd:868-908`, `test_seat_decks.gd:136-255`.
- `deck-2-spec.md:28-29` (the `[7-5b]` note), `:41-42` ("whenever you launch an unblockable" becomes "when the chargeup
  BEGINS", the accepted press; body and numbers are now decided), `:60-61` ("per orb you hold" becomes "per orb still
  held after the blue orb is paid"). The spec amendment is a gate or close-out docs task, not this commit.
- The resolver comment `card_effect_resolver.gd:359-380`, rewritten at its own seat. The Healer is also the first
  WALKING unit with no attack record (until now only totems had none).

## Acceptance Criteria

`[M]` machine-checkable, `[S]` live smoke. "Owner" = the hero that summoned the unit. "Held orbs" = all colours.

1. **[M] Availability.** Healer (Mode 1) and staging / activating Elemental Fury and Wrath of God are no longer refused
   as `not_available_yet`; `UNAVAILABLE_EFFECT_OWNERS` is empty (pinned at size 0) and each effect resolves through a
   resolver family. Costs, colours, speeds, pairings and copies of all sixteen deck cards are unchanged (`7-5a` AC 1-4
   pins untouched); no balance value outside these three effects moves. Each effect is tested with its layer flag ON and
   OFF (Healer `minions`; the sorceries `spells`): OFF resolves the cast and applies nothing.
2. **[M] Healer, summon.** Healer costs its authored mana and summons ONE unit of a new authored kind, placed by the
   existing spawn rule (`4-3e`, plus the `7-3/R32` flank row if authored). No new placement rule.
3. **[M] Healer, behaviour.** A WALKING unit, not a totem: it follows its OWNER, closes to an authored follow distance
   and stops, for as long as it lives. It never flees, never attacks, never acquires an enemy target and draws nothing
   from the match RNG at any tick (`test_the_summon_consumes_no_rng` stays true).
4. **[M] Healer, HP.** An unbuffed Healer dies to six or seven basic hero melee hits: a parametric test reads the
   authored values and asserts `ceil(max_hp / hero_damage_to_unit)` is 6 or 7 (the `7-3` AC 6 shape; with
   `hero_damage_to_unit = 3.0` that is `max_hp` in (15.0, 21.0]; starting value 20.0, OQ-1).
5. **[M] Healer, as a unit.** It is damaged by every source that damages a hound, dies, leaves a corpse with the global
   lifetime, may be targeted by enemy units and totems under the unchanged targeting rule, and is removed with no corpse
   by a Counterspell on the Healer card, exactly as existing summoned units (`6-5f`, `7-3` AC 4). It has NO hit reaction.
6. **[M] Healer, heal.** While alive, each Healer heals its owner by the authored amount (2 HP) every authored interval
   (5 s, integer ticks) if the owner is within the authored range (8 m) at that tick; out of range the tick heals nothing
   (OQ-2). Healing never exceeds max HP, is not damage and triggers nothing. Two Healers heal independently. A dead owner
   or a frozen round heals nothing. The range test reaches state only through the recorded contact intake.
7. **[M] Healer, shot.** When its owner's unblockable chargeup BEGINS (the ACCEPTED press; a press refused for mana,
   stamina or state fires nothing), each living Healer of that owner fires exactly ONE homing projectile at the OPPOSING
   HERO: one per Healer per chargeup, whatever later happens to the unblockable. The spawn tick is a STATE fact, an
   authored delay after the chargeup begins (may be 0); a Healer dead before that tick fires nothing.
8. **[M] Healer, shot defences.** The projectile deals its authored damage (3), launches from the Healer, and meets every
   defence EXACTLY as a Rocksling stone does, through the same contact ladder with no new rung: a deflect negates and
   consumes it; roll or get-up i-frames drop the fact and end its homing; a BLOCK does not reduce it (`6-5d/R4`, X2); it
   passes through non-targets; Stoneskin absorbs it; Lifechain splits it. It plants NO Boulder. A Counterspell on the
   Healer card treats its shots as a stone's (in flight: removed; landed: damage refunded), under the existing
   last-resolved-card and window rules (OQ-3).
9. **[M] Healer, rig adoption.** `assets/characters/healer/` is adopted by the `4-3c` pattern: an `EditorScenePostImport`
   script strips the take embedded in `healer.fbx`; a headless tool builds ONE `AnimationLibrary` `.res` from `idle`,
   `walk`, `cast`, `shoot`, `death`; a presentation-layer controller is fed by the runner's existing per-tick unit push;
   a committed rig test pins EXACTLY five clips on the assembled scene, mutation-proven. Import is clean (`root_scale =
   1.0`, no retarget, no hand-edited `.import`); the editor is not opened on the folder before the import hook exists.
10. **[M] Healer, clips.** `death` on liveness, checked first; `cast` on each heal tick that heals; `shoot` when a shot is
    owed; otherwise `walk` or `idle` by measured speed. Heal and shot reach the controller as POLLED state facts on the
    existing push; no observation seam is added (the family stays ten). The `shoot` release frame coincides with the
    state spawn tick of AC 7: measured by a committed `measure_strike_frame`-shaped tool, the clip rate-fitted to the
    authored delay (the `4-3d` mechanism), pinned by a live test of the `test_unit_strike_alignment_live.gd` shape.
11. **[M] Healer, body.** The body collider is at least the hero's height and stands on the ground (`7-3/R38`). It has a
    hurtbox on the convention's layers and NO hitbox. Scene, lock-mark lift and spawn look are runner tables keyed by
    kind name (`7-3/D5`). **[S]** It reads as a walking character at the right height.
12. **[M] Elemental Fury, condition.** Judged at ACTIVATION before any orb is spent: after paying the blue orb at least
    one held orb must remain. Otherwise the activation is refused with a named reason, no orb is spent, and the card
    stays staged with its countdown running (the `6-5b/R14` shape). A NEW refusable outcome. Mana paid at staging stays
    spent (the standing no-refund rule, OQ-4).
13. **[M] Elemental Fury, volley.** It fires ONE projectile per orb still held after the blue orb is paid, in a fixed
    colour order with an authored interval between launches (0 = same tick). Held orbs are NOT consumed: the pool after
    equals the pool before minus one blue orb. Each projectile's colour is a hashed fact fixed at launch.
14. **[M] Elemental Fury, flight.** Every projectile targets the OPPOSING HERO (OQ-5) with Fireball's flight shape as its
    own data, and meets defences exactly as a Fireball: deflect negates and consumes, i-frames drop and end homing, block
    does not help, non-targets are passed through; a Counterspell removes shots in flight and reverses landed effects.
15. **[M] Elemental Fury, colours.** RED deals its authored damage (starting 3.0, OQ-6). BLUE applies Frostbite's slow to
    the hero it hits, from its own authored multiplier and duration (starting at Frostbite's 0.5 for 4 s), through the
    existing slow rule (refresh, never stack). GREEN heals the CASTER by its authored amount (5) when it lands. Blue and
    green deal no damage (OQ-6). A projectile that does not land (deflected, i-frame-dropped, countered, expired) has no
    effect: a green one heals nothing, a blue one slows nothing.
16. **[M] Wrath, windup and pulse.** Activation starts a windup of the authored length (0.8 s); ONE pulse resolves on its
    last tick. Not a lingering zone: a body entering the ring after the pulse is untouched. Radius = authored base +
    authored per-orb x orbs still held after the blue orb is paid, FROZEN at activation; the ring is centred on the
    caster at the pulse.
17. **[M] Wrath, who is hit.** The opposing hero and every opposing unit and totem inside the ring at the pulse tick. The
    caster, the caster's own units and totems, and corpses are untouched. Ring membership and the direction away from
    the caster reach state only through the recorded contact intake.
18. **[M] Wrath, hero.** Unguarded: authored damage, a knockback of authored distance directly away from the caster, and
    a stun of authored length (0.5 s) running while it slides. The stun interrupts a swing, a chargeup (the
    `_apply_bolt_landing` teardown, Setup carry included) and a block, and cancels a cast in progress, as the Honed Bolt
    stun does; it arms NO root and is not a knockdown (its length stays strictly below `knockdown_stun_seconds`,
    audited). A hero already in a knockdown takes the damage only (the `R-STUNSTACK` floor, OQ-7).
19. **[M] Wrath, wall.** Knockback stops at the arena wall: a hero or unit pushed at a wall ends against it, never beyond
    it and never lifted off the floor. A live test pins all four walls.
20. **[M] Wrath, units.** A walking unit takes the damage and the knockback; its attack is interrupted where its kind
    reacts to damage (hounds do; OQ-8 for the zombie). A TOTEM takes the damage only and never moves. Kills leave corpses.
21. **[M] Wrath, defences** (one test each). I-frames at the pulse (roll or get-up, the step-3 latch) avoid it entirely;
    being outside the ring at the pulse avoids it entirely; a held block facing the caster takes the authored fraction
    (half) of the damage with NO knockback and NO stun; a timed deflect takes nothing (OQ-9); Stoneskin absorbs the damage
    like any instance (OQ-10); Lifechain splits the hero's damage as for any instance.
22. **[M] Wrath, Counterspell.** During the windup: no pulse. After the pulse: the damage is reversed by the amount
    actually applied (hero and units, the general restore rule); positions are not moved back. A caster stunned or
    killed during the windup loses the pulse; card, mana and orb stay spent (the cast rule, OQ-11).
23. **[S] Placeholder presentation**, on both viewports: the Healer shot and the Elemental Fury projectiles are visible in
    flight, the latter tinted by orb colour; the Wrath windup shows a ground ring at the frozen radius and a flash at the
    pulse; a heal tick, a green landing, a slow and the Wrath stun each show a text marker in the `7-5a` `BuffMarkers`
    manner. Existing projectile and telegraph presentation is reused. **[M]** geometry only (PROC/R8): the ring's drawn
    radius equals the state radius; the tint follows the colour fact; each effect has a presentation row; presentation
    writes no state; the icon audit stays green.
24. **[M] Replay.** A recorded match (seats on different decks) replays to the identical final hash and record,
    exercising: a heal tick in range and one out of range, a Healer shot, an Elemental Fury with all three colours (one
    deflected), its refusal, a Wrath of God hitting a hero and a hound with a totem in the ring, a blocked pulse, and a
    Counterspell on Healer and on a Wrath windup (`6-5e` AC 41 precedent).
25. **[M] Teardown.** Every new hashed fact is listed in the Dev Agent Record and cleared at BOTH `_end_round` and
    `_reset_player`, one test per fact in both directions (`test_deck_2_teardown.gd` shape). A pending pulse, an owed
    Healer shot and an owed volley projectile never cross a round end or a reset.
26. **[M] Gates.** F1, D3(a), D3(b)/A2 stay green. The golden and snapshot key set move only by named, separately
    measured causes with a reverse probe (E6-R/R8; Golden Prediction). Full gate green. **[S]** Live Smoke passes.

## Tasks / Subtasks

Two sessions (the `7-3` split): 1 state, data, unit tests, golden at most once; 2 rig, presentation, smoke, NO new hashed fact.

- [ ] T1 Measure first (AC 9-11): headless import, clips yielded, Hips displacement, `shoot` release frame, model height, size delta.
- [ ] T2 Data and audit bounds for every new field; empty the refusal table and move its pins (AC 1, 2, 4, 6, 13, 15, 16, 18).
- [ ] T3 Healer in state: follow, heal clock, range fact, shot on chargeup, reversal (AC 3-8).
- [ ] T4 Elemental Fury: activation gate, volley, colour payloads, reversal (AC 12-15).
- [ ] T5 Wrath of God: windup, frozen radius, pulse, knockback, stun, defences, reversal (AC 16-22).
- [ ] T6 Replay identity, teardown, key-set pins, golden both directions, format bump (AC 24-26).
- [ ] T7 Rig, scene, controller, runner tables, placeholder presentation rows (AC 9-11, 23).
- [ ] T8 Assets commit (its own, first on the chain), full gate, Live Smoke, close-out docs incl. the spec amendment.

## Dev Notes

### Measured facts at authoring (HEAD `fd07ecd`)

- Refusal: one table, two seats: `card_effect_resolver.gd:376-391`; Mode 1 gate `match_state.gd:4467`; staging ladder
  `:6416`. The three effect files hold an `effect_id` only, with no `summon_` / `spell_` prefix on purpose (`7-5a/R29`);
  the summon shape `summon_count` / `summon_kind` exists (`7-3/R16`). An id change is the dev pass's call; pins follow.
- Units: `hero_damage_to_unit = 3.0`; hound and zombie `max_hp = 9.0` (`balance_config.tres:212, 117, 47`). Only the
  accelerators have no attack (`:68, 77`), at `move_speed = 0.0`. Position is ACTOR-owned: state holds none; spatial
  facts enter through the tapped `push_contact` (`match_state.gd:1538`, kinds `:143-171`). Unit targets are hashed.
- Activation: `_resolve_pitch_activate` (`match_state.gd:6521`) refuses before the orb spend (`:6554-6557`), counts held
  orbs BEFORE paying (`:6560`, `7-5a/R18`) and spends ONLY the priced orbs (`:6561-6563`, `6-3-split/R-SPEND`), so held
  orbs already survive an activation. `pitch_stage_clears_orbs = false` (`balance_config.tres:261`).
- Shots: `ProjectileBoard.add_hero_shot` / `add_minion_shot` (`projectile_board.gd:174, 216`; the latter launches from a
  unit's board index, otherwise hero-sourced). Inherited rungs: pass-through `match_state.gd:2871-2877`, i-frames
  `:2913-2931`, deflect `:2960-2967`, block exemption `:3053-3057`, Boulder only when `boulders_per_cast > 0` (`:3124`).
- Numbers reused as starting points: `frostbite.tres` slow 0.5 for 4.0 s (applied at `_consume_frostbite`, `:3863`);
  `fireball.tres` flight (launch 8, homing 120, accel 12 after 0.4 s, max 20, budget 60); `rocksling.tres` damage 3.
- Stun: `_apply_bolt_landing` (`match_state.gd:7584-7605`): knockdown floor, chargeup teardown, then a root. A spell's
  dodge is the step-3 latch (`:831-832, 7379`); a stunned or dead caster loses a cast at step 6c (`:971`); Stoneskin then
  Lifechain are asked in `_deal_hero_damage` (`:3678`). Block is x0.3 (`balance_config.tres:218`), so Wrath's "half" is
  an effect-owned number. The arena is four `StaticBody3D` walls (`main.tscn:45`).
- Rig precedents: `assets/characters/skeletonzombie/strip_model_anim.gd`, `tools/build_zombie_anims.gd`,
  `tools/measure_strike_frame.gd`, `src/actors/minions/unit_animation_controller.gd:158` (`on_unit_tick`), the hound
  controller beside it, `test/integration/test_unit_rig_clips.gd`; push seat `match_runner.gd:3227-3246`; runner tables
  `:169-175`. `*.fbx` is already binary in `.gitattributes`. Folder: `healer.fbx` 10.9 MB, five clips 3.4 MB.
- Record: `FORMAT_VERSION := 24` (`record_file.gd:429`). Per-player snapshot keys: 59 (`7-5a/R42`,
  `test_draw_delay_and_reshuffle.gd:456`).

### Mechanism the repo forces (everything else is the dev pass's choice)

- No position enters `src/state/`: heal range, ring membership and knockback direction are facts on the recorded contact
  intake (the reach-probe precedent), gathered event-scoped or throttled; `test_intent_recorder.gd`'s intake guard moves.
- Every duration is integer ticks converted once (A1): heal interval, shot delay, volley interval, windup, stun.
- Knockback is state-decided and actor-moved: state owns that it happens, its direction, length and stun; the body's
  `move_and_slide` is what the wall stops. No animation callback and no `Timer` node decides any of it.
- The hero stun is one more authored direct `STUNNED` entry (`6-5c/R11` counts them); reuse the bolt teardown verbatim.
- Healer and Elemental Fury shots are hero-sourced records, so the ladder needs no new rung. Colour is the one new
  per-shot fact; a zero-damage landing spends neither Stoneskin nor Execute (pinned in `test_deck_2_charges.gd`).

### Tests that move

`test_card_authoring.gd:868-908`; `test_seat_decks.gd:136-255` (deleted or inverted, never left asserting a dead rule);
`test_spell_framework.gd` if a resolver table gains rows; `test_balance_authoring.gd` (completeness guard, new bounds);
`test_record_file.gd` (version pin, NEW v24-refusal test); `test_replay_identity.gd`; `test_intent_recorder.gd`; both
snapshot key-set pins; `test_deck_2_teardown.gd`. Do NOT move: deck composition pins, the other eight halves' tests.

### Doc contradictions (flagged, not reinterpreted)

- **X1.** `project-context.md:166` says a pitch activation resets all three orb colours. The repo spends only the priced
  orbs (`match_state.gd:6561-6563`) and this story depends on that. The line is stale: docs debt.
- **X2.** The ruling says the Healer shot is "blocked ... exactly like a Rocksling stone"; in the repo a block does NOT
  reduce a stone (`6-5d/R4`). AC 8 follows the repo (OQ-3a).
- **X3.** "4-3c strike-alignment precedent": that work was cut from 4-3c into `4-3d` (`4-3c/R2`); AC 10 cites `4-3d`.
  **X4.** `epics.md:347` still lists one item `7-5-deck-2`, "design pending"; left for the E7 close-out.

### Golden Prediction (prediction only; the dev pass measures both directions with a reverse probe)

- **Moves by SHAPE, once, in session 1.** Predicted causes, each measured alone: (1) new `UnitKindProfile` fields add
  keys to the `balance` channel (a measured mover at `7-3/R45`); (2) per-unit facts (heal clock, owed shot) add `unit_*`
  keys; (3) the per-shot colour adds a `projectile_*` key; (4) the pending pulse (window, frozen radius), the owed volley
  and any knockback fact add per-player keys. New `CardEffect` fields: mover at `7-3/R45`, NON-cause in `7-5a` Part A; measure.
- **No behaviour move expected:** the golden fixture injects its own deck and exercises none of this. With every new key
  removed the hash must reproduce `fbad85ce...` exactly; a behaviour move is a defect to explain, not a re-baseline.
- **`FORMAT_VERSION` 24 -> 25 predicted:** a record carries effects and balance by value, so new script properties change
  its shape (`7-3/R23`), and new contact kinds change the `contacts` rows. v24 is refused with a named reason, no shim.
- **Session 2 moves nothing:** rig, scene and presentation add no hashed fact; measured unmoved before and after.

### Project Context Rules (from `docs/project-context.md` and CLAUDE.md)

- Never hardcode balance or content; state is headless-tested; signals raised inside `advance()` are queued. Suite: two
  full runs per pass, extras disclosed, one foreground engine launch per call; a parse error in a new test hangs the harness.
- Edit tool only; mutation proofs restore from an out-of-repo SHA-256-verified copy. Chain: C1 assets, C2 code / data /
  tests / tools, C3 docs; repo trailer. `playtest-log.md` is the operator's alone. A design choice stops and asks.

### References

`deck-2-spec.md`; `7-5a-deck-2-core.md`; decision log `7-5a/R1..R43`, `7-3/R16, R23, R32, R38, R45, D5`; stories `7-3` (unit
with a rig), `4-3c` (import, pin test), `4-3d` (rate-fit), `4-3e`, `6-5c` (stun), `6-5d`, `6-5e` (stones), `6-5g`, `7-1` (rows).

## Deferred

- Real VFX, sound and art for all three; Healer hit reaction; owner colours for Healers (OQ-12). Shield Knight (the new
  Vanguard): own story. Retuning any existing card: 7-7.
- 7-7 inputs, not acted on: Wrath's radius is uncapped (up to 14 orbs after paying); the heal against 100 HP; Healer's price.

## Live Smoke

Solo `[0,3]`: add `slot_controller_kinds = Array[int]([0, 3])` to the Main node of `main.tscn`; DELETE it before any suite
run and any commit. Seat decks via `data/deck_select.tres`, RELAUNCH between launches. The keyboard seat has no pitch
path, so the PAD casts both sorceries; a Counterspell on a pitch half, Stoneskin and totems are machine-only. PER-ITEM verdicts.

**Launch 1 - pad Deck 2, keyboard Deck 1 (keyboard is target and defender, and summons hounds)**
1. Healer: spawns by the placement rule, follows the pad hero, stops close, never flees, never attacks; idle / walk read.
2. Heal: +2 every 5 s near the hero, with `cast` and a marker; more than 8 m away: no heal.
3. Healer HP: dies on the sixth or seventh sword hit, plays `death`, leaves a corpse; no flinch.
4. Shot: each chargeup fires one shot per Healer, the `shoot` release matching the spawn; a refused press fires none.
   Keyboard deflects one (nothing), rolls one (it passes), blocks one (full 3), takes one (3).
5. Elemental Fury refusal: with only the blue orb held the activation is refused, the orb is kept, the card stays staged.
6. Elemental Fury: one coloured shot per remaining orb; the orbs are still held afterwards. Red damages, blue slows,
   green heals the pad hero 5 on hit; a deflected green heals nothing.
7. Wrath telegraph: a ground ring for about 0.8 s; more held orbs give a visibly larger ring; one pulse, no zone.
8. Wrath on the hero: damage, a slide directly away, a short stun; a swing, a chargeup and a block are each interrupted.
9. Wrath at the wall: a hero and a hound pushed at a wall stop at it.
10. Wrath defences: roll through it (nothing); walk out in the windup (nothing); hold block (half, no slide, no stun);
    timed deflect (nothing).
11. Wrath on units: the keyboard's hounds take damage, slide and drop their attack; the pad's own Healer is untouched.

**Launch 2 - pad Deck 1, keyboard Deck 2**
12. Counterspell: the keyboard plays Healer and the pad counters it: the Healer vanishes with no corpse.
13. The keyboard's Healer shoots on a keyboard unblockable (X / V / B); the pad seat blocks, deflects and rolls it.
14. R-D6: a round ends by a kill; Healers' owed shots, a pending pulse and every marker clear; the next round is clean.
15. fps stable throughout.

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 0.1 | 2026-10-14 | created (Status authored; board key stays backlog; not cleared for a dev pass).

## Open Questions

Each lists the default this story was written to; the operator confirms or overrides before promotion.

- **OQ-0** The 2026-10-14 rulings have no decision-log session, so no `7-5b/R..` label exists. Record them at the gate?
- **OQ-1** Healer HP 20.0 (dies on the seventh hit)? 18.0 is exactly six. **OQ-2** Out of range the heal clock keeps
  running and the tick is skipped (default); or it pauses, or resets?
- **OQ-3** A Counterspell on Healer also removes its shots in flight and refunds landed shot damage (default)?
  **(a)** "Blocked like a stone": a block does not reduce the shot (default, the repo's rule), or the 0.3 block applies?
  **OQ-4** An Elemental Fury refused at activation keeps its staging mana spent (default, the standing rule)?
- **OQ-5** "Opposing hero" vs "Fireball's targeting" (the lock target, maybe a unit). Default: always the opposing hero.
- **OQ-6** Red damage is unruled (default 3.0); blue and green deal none; volley 0.15 s apart, red, blue, green (defaults)?
- **OQ-7** Wrath numbers not ruled: damage (default 6.0), base radius (4.0 m), per orb (1.0 m), knockback (4.0 m). A hero
  already knocked down: damage only, no slide (default)?
- **OQ-8** "Dogs": default every walking unit slides (zombie, opposing Healer); interruption per `react_on_damage` (hound only)?
- **OQ-9** A deflect of the pulse costs normal deflect stamina, no caster stun; a block must FACE the caster (defaults)?
- **OQ-10** Stoneskin absorbs the damage; knockback and stun still apply (default, the absorbed-unblockable precedent)?
- **OQ-11** Wrath's windup is a normal cast commitment (stun or death cancels it); Elemental Fury has NO cast time (defaults)?
- **OQ-12** Whose Healer is whose in a mirror match: no owner tint in this story (default), or a placeholder tint?
  **OQ-13** Source and licence of the Healer model and clips, for `assets/CREDITS.txt`.
