---
baseline_commit: fd07ecd30bd38743ad0d4726f1832357137fb871
---

# Story 7.5b: Deck 2 bodies (Healer, Elemental Fury, Wrath of God)

Status: ready-for-dev

Tier **A** (new hashed facts, a new refusable outcome, a new same-side intake, a record-format bump, a new unit kind).
Authored 2026-10-14 against `fd07ecd`, gate-fixed and promoted the same day at HEAD `a9b52cb`; the only untracked entry is
`assets/characters/healer/` (six `.fbx`, no `.import` yet). Card text is `docs/planning-artifacts/deck-2-spec.md` (not restated
here). Behaviour below is the operator's rulings `7-5b/R1..R23` (decision log; see Rulings). Behaviour and acceptance, not
mechanism (E4-R/R4). Every number is a TEMP starting value in `.tres`, never a literal in `src/`.

## Story

As a Deck 2 player, I want the Healer, Elemental Fury and Wrath of God to do what their cards say, instead of three refused
halves. As the operator, I want all three smoke-legible with placeholder visuals, before any real art.

## Scope

- The three halves 7-5a left refused become real: **Healer** (Healer / Stoneskin), **Elemental Fury** (Manablossom's pitch
  half), **Wrath of God** (Manapulation's pitch half). `UNAVAILABLE_EFFECT_OWNERS` ends EMPTY (the mechanism may stay,
  `card_effect_resolver.gd:216-223`). The Healer rig is committed on this chain. Nothing else changes.

## What this story supersedes

- `7-5a` AC 13-15, AC 57 and smoke point 9 (the temporary refusal); `7-5a/R29`, `R33` discharged; the pins asserting it
  (`test_card_authoring.gd:868-908`, `test_seat_decks.gd:136-255`). The resolver comment `card_effect_resolver.gd:359-380` is
  rewritten at its own seat.
- `deck-2-spec.md` "launch" and "orbs you hold" wording: amended in the fix pass, docs-only (`7-5b/R15`). The Healer is the
  first WALKING unit with no attack record (until now only totems had none).

## Acceptance Criteria

`[M]` machine-checkable, `[S]` live smoke. "Owner" = the hero that summoned the unit. "Held orbs" = all colours.

1. **[M] Availability.** Healer (Mode 1) and staging / activating Elemental Fury and Wrath of God are no longer refused
   as `not_available_yet`; `UNAVAILABLE_EFFECT_OWNERS` is empty (pinned at size 0) and each effect resolves through a
   resolver family. Costs, colours, speeds, pairings and copies of all sixteen deck cards are unchanged (`7-5a` AC 1-4
   pins untouched); no balance value outside these three effects moves. Each effect is tested with its layer flag ON and
   OFF (Healer `minions`; the sorceries `spells`): OFF resolves the cast and applies nothing.
2. **[M] Healer, summon.** Healer costs its authored mana and summons ONE unit of a new authored kind, placed by the
   existing spawn rule (`4-3e`, plus the `7-3/R32` flank row if authored). No new placement rule. The effect id stays
   `healer` with a whole-id summon row unless the dev pass renames it at the cost the gate lists (`7-5b/R20`).
3. **[M] Healer, behaviour.** A WALKING unit, not a totem: it follows its OWNER, closes to an authored follow distance and
   stops, for as long as it lives. Move speed 3.0 (data): the hero walks 2.0 and runs 6.0, so a running owner outruns it
   (`7-5b/R21`). Follow-owner is a NEW runner branch (a unit with no target is stopped today, `match_runner.gd:3592-3632`).
   It never flees, never attacks, never acquires an enemy target and draws nothing from the match RNG at any tick: a
   Healer twin of `test_the_summon_consumes_no_rng` (that test summons the golden fixture's minion, not a Healer).
4. **[M] Healer, HP.** `max_hp = 18.0` (`7-5b/R2`): an unbuffed Healer dies to exactly six basic hero melee hits. A
   parametric test reads the authored values and asserts `ceil(max_hp / hero_damage_to_unit)` is 6 or 7 (the `7-3` AC 6
   shape, band `test_balance_authoring.gd:583-590`; with `hero_damage_to_unit = 3.0`, `max_hp` in (15.0, 21.0]).
5. **[M] Healer, as a unit.** `is_minion = true` (corpse <=> minion, `7-3/D4`, `7-5b/R19`). It is damaged by every source
   that damages a hound, dies, leaves a corpse with the global lifetime, may be targeted by enemy units and totems under
   the unchanged targeting rule, and is removed with no corpse by a Counterspell on the Healer card, exactly as existing
   summoned units (`6-5f`, `7-3` AC 4). It has NO hit reaction.
6. **[M] Healer, heal.** While alive, each Healer heals its owner by the authored amount (2 HP) every authored interval
   (5 s, integer ticks) if the owner is within the authored range (8 m) at that tick; out of range the clock keeps running
   and the tick heals nothing (`7-5b/R3`). Healing never exceeds max HP, is not damage and triggers nothing. Two Healers
   heal independently. A dead owner or a frozen round heals nothing. The range fact reaches state through a NEW same-side
   intake on the `push_drain_target` precedent (`match_state.gd:1659`), recorded and replayed; it is NOT a same-slot
   exemption in `push_contact` (`7-5b/R17`).
7. **[M] Healer, shot.** When its owner's unblockable chargeup BEGINS (the ACCEPTED press; a press refused for mana,
   stamina or state fires nothing), each living Healer of that owner fires exactly ONE homing projectile at the OPPOSING
   HERO: one per Healer per chargeup, whatever later happens to the unblockable. The spawn tick is a STATE fact, an
   authored delay after the chargeup begins (may be 0); a Healer dead before that tick fires nothing.
8. **[M] Healer, shot defences.** The projectile deals its authored damage (3), launches from the Healer
   (`add_minion_shot`), and meets every defence EXACTLY as a Rocksling stone does, through the same contact ladder with no
   new rung: a deflect negates and consumes it; roll or get-up i-frames drop the fact and end its homing; a BLOCK does not
   reduce it (every hero-sourced shot is exempt, `match_state.gd:3053-3057`, `7-5b/R23`; `6-5d/R4` is background); it passes
   through non-targets; Stoneskin absorbs it; Lifechain splits it. It plants NO Boulder. A Counterspell on the Healer card
   treats its shots as a stone's (in flight: removed; landed: damage refunded), under the existing last-resolved-card and
   window rules (`7-5b/R4`).
9. **[M] Healer, rig adoption.** `assets/characters/healer/` is adopted by the `4-3c` pattern: an `EditorScenePostImport`
   script strips the take embedded in `healer.fbx`; a headless tool builds ONE `AnimationLibrary` `.res` from `idle`,
   `walk`, `cast`, `shoot`, `death`; a presentation-layer controller is fed by the runner's existing per-tick unit push; a
   committed rig test pins EXACTLY five clips on the assembled scene, mutation-proven. The model is Mixamo (Adobe) "Knight D
   Pelegrini" with the clips Standing Idle 03 / Standing Walk Forward / Standing 2H Magic Area Attack 01 / Standing 1H Magic
   Attack 03 / Standing React Death Forward mapped to idle / walk / cast / shoot / death (`7-5b/R14`). Import is clean
   (`root_scale = 1.0`, no retarget); `healer.fbx.import` carries `import_script/path` and `animation/import=false` by the
   `4-3c` route (compare `skeletonzombie.fbx.import:31,36`), never hand-edited; the editor is not opened on the folder before
   the import hook exists.
10. **[M] Healer, clips.** `death` on liveness, checked first; `cast` on each heal tick that heals; `shoot` when a shot is
    owed; otherwise `walk` or `idle` by measured speed. Heal and shot reach the controller as POLLED state facts on the
    existing push (`match_runner.gd:3227-3246`); no observation seam is added (the family stays ten). The `shoot` release
    frame coincides with the state spawn tick of AC 7: measured by a committed `measure_strike_frame`-shaped tool, the clip
    rate-fitted to the authored delay (the `4-3d` mechanism), pinned by a live test of the
    `test_unit_strike_alignment_live.gd` shape.
11. **[M] Healer, body.** The body collider is at least the hero's height and stands on the ground (`7-3/R38`). It has a
    hurtbox on the convention's layers and NO hitbox. Scene, lock-mark lift and spawn look are runner tables keyed by kind
    name (`7-3/D5`, `match_runner.gd:169-175`). The owner tint rides the existing `owner_skins` / `skin_mesh_path`
    mechanism (`unit_actor.gd:620-638`, `7-5b/R13`): the model has ONE skinned mesh and each slot material keeps the
    Healer's texture. **[S]** It reads as a walking character at the right height, and the two seats' Healers differ in tint.
12. **[M] Elemental Fury, condition.** Judged at ACTIVATION before any orb is spent: after paying the blue orb at least one
    held orb must remain. Otherwise the activation is refused with a named reason, no orb is spent, and the card stays staged
    with its countdown running and the press repeatable (the `6-5b/R14` shape, `match_state.gd:6534-6557`). A NEW refusable
    outcome. Mana paid at staging stays spent (the standing no-refund rule); the card stays activatable later (`7-5b/R5`).
13. **[M] Elemental Fury, volley.** No cast time (`7-5b/R12`). It fires ONE projectile per orb still held after the blue orb
    is paid, in the fixed colour order red, blue, green, 0.15 s apart (integer ticks, `7-5b/R7`). Held orbs are NOT consumed:
    the pool after equals the pool before minus one blue orb. Each projectile's colour is a hashed fact fixed at launch.
14. **[M] Elemental Fury, flight.** Every projectile ALWAYS targets the OPPOSING HERO, like the Healer shot: no lock-target
    routing and no unit-target payload (`7-5b/R6`). Fireball's flight shape is its own data. It meets defences exactly as a
    Fireball: deflect negates and consumes, i-frames drop and end homing, block does not help, non-targets are passed
    through; a Counterspell removes shots in flight and reverses landed effects.
15. **[M] Elemental Fury, colours** (`7-5b/R7`). RED deals 3.0 damage. BLUE applies Frostbite's slow to the hero it hits, from
    its own authored multiplier and duration (starting at Frostbite's 0.5 for 4 s), through the existing slow rule (refresh,
    never stack). GREEN heals the CASTER by its authored amount (5) when it lands. Blue and green deal no damage. A
    projectile that does not land (deflected, i-frame-dropped, countered, expired) has no effect: a green one heals nothing,
    a blue one slows nothing.
16. **[M] Wrath, windup and pulse.** Activation starts a windup of the authored length (0.8 s) that is a normal cast
    commitment (`7-5b/R12`); ONE pulse resolves on its last tick. Not a lingering zone: a body entering the ring after the
    pulse is untouched. Radius = base 4.0 m + 1.0 m per orb still held after the blue orb is paid (`7-5b/R8`), FROZEN at
    activation; the ring is centred on the caster at the pulse.
17. **[M] Wrath, who is hit.** The opposing hero and every opposing unit and totem inside the ring at the pulse tick. The
    caster, the caster's own units and totems, and corpses are untouched. Ring membership and the direction away from the
    caster reach state only through the recorded contact intake (opposing-slot facts are legal; the self-contact refusal
    binds same-slot only).
18. **[M] Wrath, hero.** Unguarded: 6.0 damage, a knockback of 4.0 m directly away from the caster, and a stun of authored
    length (0.5 s) running while it slides (`7-5b/R8`). The stun interrupts a swing, a chargeup (the CHARGING teardown of
    `_apply_bolt_landing`, `match_state.gd:7595-7603`, Setup carry included, and NOT the whole function) and a block, and
    cancels a cast in progress, as the Honed Bolt stun does; it arms NO root, sets no bolt flag, and is not a knockdown (its
    length stays strictly below `knockdown_stun_seconds`, audited). It is the fifth direct `STUNNED` write (`7-5b/R18`). A
    hero already in a knockdown takes the damage only (the `R-STUNSTACK` floor).
19. **[M] Wrath, wall.** Knockback stops at the arena wall: a hero or unit pushed at a wall ends against it, never beyond it
    and never lifted off the floor. A live test pins all four walls.
20. **[M] Wrath, units.** Every walking unit takes the damage and the knockback; its attack is interrupted where its kind
    reacts to damage (`react_on_damage`: hounds do) (`7-5b/R9`). A TOTEM takes the damage only and never moves. Kills leave
    corpses.
21. **[M] Wrath, defences** (one test each). I-frames at the pulse (roll or get-up, the step-3 latch) avoid it entirely;
    being outside the ring at the pulse avoids it entirely; a held block FACING the caster takes half the damage with NO
    knockback and NO stun (an effect-owned number); a timed deflect takes nothing and costs the normal deflect cost, with
    nothing to the caster (`7-5b/R10`); Stoneskin absorbs the damage while knockback and stun still apply (`7-5b/R11`);
    Lifechain splits the hero's damage as for any instance.
22. **[M] Wrath, Counterspell.** During the windup: no pulse. After the pulse: the damage is reversed by the amount actually
    applied (hero and units, the general restore rule); positions are not moved back. A caster stunned or killed during the
    windup loses the pulse; card, mana and orb stay spent (the cast rule, `_cast_is_interrupted`).
23. **[S] Placeholder presentation**, on both viewports: the Healer shot and the Elemental Fury projectiles are visible in
    flight, the latter tinted by orb colour; the Wrath windup shows a ground ring at the frozen radius and a flash at the
    pulse; a heal tick, a green landing, a slow and the Wrath stun each show a text marker in the `7-5a` `BuffMarkers` manner.
    Existing projectile and telegraph presentation is reused. **[M]** geometry only (PROC/R8): the ring's drawn radius equals
    the state radius; the tint follows the colour fact; each effect has a presentation row; presentation writes no state; the
    icon audit stays green (icons exist: `assets/art/icons/game_icons/{healer,elemental_fury,wrath_of_god}.svg`).
24. **[M] Replay.** A recorded match (seats on different decks) replays to the identical final hash and record, exercising: a
    heal tick in range and one out of range, a Healer shot, an Elemental Fury with all three colours (one deflected), its
    refusal, a Wrath of God hitting a hero and a hound with a totem in the ring, a blocked pulse, and a Counterspell on
    Healer and on a Wrath windup (`6-5e` AC 41 precedent).
25. **[M] Teardown.** Every new hashed fact is listed in the Dev Agent Record and cleared at BOTH `_end_round`
    (`match_state.gd:8946`) and `_reset_player` (`:9094`), one test per fact in both directions (`test_deck_2_teardown.gd`
    shape). A pending pulse, an owed Healer shot and an owed volley projectile never cross a round end or a reset.
26. **[M] Gates.** F1, D3(a), D3(b)/A2 stay green. The golden and snapshot key set move only by named, separately measured
    causes with a reverse probe (E6-R/R8; Golden Prediction). Every new pin has a mutation proof, restored from an
    out-of-repo SHA-256-verified copy. Full gate green. **[S]** Live Smoke passes.

## Tasks / Subtasks

Two sessions (the `7-3` split): 1 state, data, unit tests, golden once at most; 2 rig, presentation, smoke, no new hashed fact.
- [ ] T1 Measure first (AC 9-11): import, clips, Hips displacement, `shoot` release frame, model height.
- [ ] T2 Data and audit bounds; empty the refusal table and move its pins (AC 1, 2, 4, 6, 13, 15, 16, 18).
- [ ] T3 Healer in state: follow, heal clock, same-side range intake, shot, reversal (AC 3-8).
- [ ] T4 Elemental Fury: activation gate, volley, colour payloads, reversal (AC 12-15).
- [ ] T5 Wrath of God: windup, pulse, knockback, stun, defences, reversal (AC 16-22).
- [ ] T6 Replay identity, teardown, both key-set pins, golden both directions, format bump (AC 24-26).
- [ ] T7 Rig, scene, controller, runner tables, owner tint, presentation rows (AC 9-11, 23).
- [ ] T8 Assets commit (first on the chain) with a new `assets/CREDITS.txt` Healer entry (model + the clip-to-file mapping of
  AC 9), full gate, Live Smoke, close-out docs.

## Dev Notes

### Measured facts at authoring (HEAD `fd07ecd`)

- Refusal: one table, two seats: `card_effect_resolver.gd:376-391`; Mode 1 gate `match_state.gd:4467`; staging ladder `:6416`.
  A summon outcome is reached only by the `summon_` prefix (`card_effect_resolver.gd:695`), so keeping `healer` needs a
  whole-id row. Renaming moves `test_card_authoring.gd:766` and `:926`, the icon audit (`test_card_face.gd:765-811`), the
  `healer.svg` CREDITS line and 12 integration `_summon_slots` pickers (e.g. `test_unit_attack_live.gd:534-538`).
- Units: `hero_damage_to_unit = 3.0`; hound and zombie `max_hp = 9.0`. Position is ACTOR-owned: state holds none; spatial
  facts enter through the tapped `push_contact` (`match_state.gd:1538`, kinds `:143-171`). Unit targets are hashed.
- Activation: `_resolve_pitch_activate` (`match_state.gd:6521`) refuses before the orb spend (`:6554-6557`), counts held orbs
  BEFORE paying (`:6560`, `7-5a/R18`) and spends ONLY the priced orbs (`:6561-6563`).
- Shots: `ProjectileBoard.add_hero_shot` / `add_minion_shot` (`projectile_board.gd:174, 216`). Rungs: pass-through
  `match_state.gd:2871-2877`, i-frames `:2913-2931`, deflect `:2960-2967`, block exemption `:3053-3057`, union flight lookup
  `:2695-2719`, Boulder only when `boulders_per_cast > 0` (`:3124`).
- Starting numbers: `frostbite.tres` slow 0.5 for 4.0 s (`:3863`); `fireball.tres` flight; `rocksling.tres` damage 3.
- Stun: `_apply_bolt_landing` (`match_state.gd:7584-7605`): knockdown floor, chargeup teardown, then a root. Spell dodge is the
  step-3 latch (`:831-832, 7379`); a dead or stunned caster loses a cast at `:971`; Stoneskin then Lifechain in
  `_deal_hero_damage` (`:3678`). Block is x0.3, so Wrath's "half" is effect-owned. Arena: four walls (`main.tscn:45`).
- Rig precedents: `skeletonzombie/strip_model_anim.gd`, `tools/build_zombie_anims.gd` (CLIPS table, `mixamo_com` take),
  `tools/measure_strike_frame.gd`, `unit_animation_controller.gd:158`, `test_unit_rig_clips.gd`. Folder: `healer.fbx` 10.9 MB.
- Record: `FORMAT_VERSION := 24` (`record_file.gd:429`). Per-player snapshot keys: 59 (`7-5a/R42`).

### Mechanism the repo forces (everything else is the dev pass's choice)

- No position enters `src/state/`. Heal range is a NEW same-side `push_*` intake with a capture channel, on the
  `push_drain_target` precedent (`7-5b/R17`); the self-contact invariant (`match_state.gd:1567`, `4-3a/R21b`) stays untouched.
  Ring membership and knockback direction are opposing-slot facts on the existing recorded contact intake (the reach-probe
  precedent), gathered event-scoped or throttled.
- Every duration is integer ticks converted once (A1): heal interval, shot delay, volley interval, windup, stun.
- Knockback is state-decided and actor-moved: state owns that it happens, its direction, length and stun; `move_and_slide`
  is what the wall stops (heroes: `match_state.gd:8354-8381`; units: `match_runner.gd:3586-3590`). No animation callback and
  no `Timer` decides any of it.
- The hero stun is the FIFTH authored direct `STUNNED` write (`6-5c/R11` counts them). It calls only the CHARGING teardown of
  `_apply_bolt_landing` (`:7595-7603`); no root, no bolt flag.
- Healer and Elemental Fury shots are hero-sourced records, so the ladder needs no new rung. Colour is the one new per-shot
  fact; a zero-damage landing spends neither Stoneskin nor Execute (`test_deck_2_charges.gd:465`). The `add_minion_shot`
  "nowhere else" comment (`projectile_board.gd:190-192`) is rewritten, as it stops being true.

### Tests that move

`test_card_authoring.gd:868-908` and `:925-926` (the three ids "author no number at all"); `test_seat_decks.gd:136-255` (deleted
or inverted, never left asserting a dead rule); `test_balance_authoring.gd` (completeness guard, new bounds, `:803-804` kind
list and order with Healer appended, `:832` minion membership gains Healer); `test_action_state.gd:161-188` (STUNNED census
`match_state.gd x4` -> `x5`, argued per its message); `test_intent_recorder.gd:121` (intake surface gains the new intake) and
`test_live_reload.gd:133-174` (the new capture channel); `test_spell_framework.gd` if a resolver table gains rows;
`test_record_file.gd` (version pin, NEW v24-refusal test); `test_replay_identity.gd`; BOTH snapshot key-set pins
(`test_card_observation.gd:378` and `test_draw_delay_and_reshuffle.gd:456`, 59 each today); `test_deck_2_teardown.gd`; a NEW
Healer no-RNG twin in `test_determinism.gd` (AC 3). Do NOT move: deck composition pins, the other eight halves' tests.

### Doc contradictions

- **X2.** "Blocked like a stone": in the repo a block does NOT reduce a stone; AC 8 follows the repo (`7-5b/R4`, `R23`).
- **X3.** Strike alignment was cut from 4-3c into `4-3d` (`4-3c/R2`); AC 10 cites `4-3d` (`7-5b/R15`). **X4.** `epics.md:347`
  still lists one item `7-5-deck-2`, "design pending"; left for the E7 close-out.

### Golden Prediction (prediction only; the dev pass measures both directions with a reverse probe)

- **Moves by SHAPE, once, in session 1.** Predicted causes, each measured alone: (1) new `UnitKindProfile` fields add keys to
  the `balance` channel (`7-3/R45`); (2) per-unit facts (heal clock, owed shot) add `unit_*` keys; (3) the per-shot colour adds
  a `projectile_*` key; (4) the pending pulse (window, frozen radius), the owed volley and any knockback fact add per-player
  keys. New `CardEffect` fields: mover at `7-3/R45`, NON-cause in `7-5a` Part A; measure.
- **No behaviour move expected:** the golden fixture exercises none of this; with every new key removed the hash must
  reproduce `fbad85ce...` exactly (a behaviour move is a defect, not a re-baseline). Session 2 moves nothing.
- **`FORMAT_VERSION` 24 -> 25 predicted:** a record carries effects and balance by value, so new script properties change its
  shape (`7-3/R23`); a new contact-kind VALUE changes no row shape (`match_state.gd:158-161, 169-170`). v24 is refused with a
  named reason, no shim.

### Project Context Rules (from `docs/project-context.md` and CLAUDE.md)

- No hardcoded balance; two full suite runs per pass, extras disclosed; a parse error in a new test hangs the harness. Edit
  tool only. Chain: C1 assets, C2 code / data / tests / tools, C3 docs. `playtest-log.md` is the operator's alone.

References: `deck-2-spec.md`; `7-5a-deck-2-core.md`; decision log `7-5a/R1..R43`, `7-5b/R1..R23`, `7-3/R16, R23, R32, R38, R45, D5`;
stories `7-3`, `4-3c`, `4-3d`, `4-3e`, `6-5c`, `6-5d`, `6-5e`, `7-1`.

## Deferred

- Real VFX, sound and art; Healer hit reaction. Shield Knight (the new Vanguard): own story. Retuning any card: 7-7 (inputs:
  Wrath's radius is uncapped, up to 14 orbs after paying; the heal against 100 HP; Healer's price).
- E7 close-out debt: `docs/project-context.md:166` says a pitch activation resets all three orb colours, but the repo spends
  only the priced orbs (`match_state.gd:6561-6563`) -- fix the line (`7-5b/R15`). `assets/CREDITS.txt` has no paladin or
  skeletonzombie model entries (`7-5b/R22`).

## Live Smoke

Solo `[0,3]`: add `slot_controller_kinds = Array[int]([0, 3])` to the Main node of `main.tscn`; DELETE it before any suite run
or commit. Seat decks via `data/deck_select.tres`, RELAUNCH between launches. The PAD casts both sorceries (the keyboard has
no pitch path); a pitch-half Counterspell, Stoneskin and totems are machine-only. PER-ITEM verdicts.

**Launch 1 - pad Deck 2, keyboard Deck 1 (keyboard is target and defender, and summons hounds)**
1. Healer: spawns by the placement rule, follows the pad hero, stops close, never flees, never attacks; idle / walk read.
2. Heal: +2 every 5 s near the hero, with `cast` and a marker; run away (the hero outruns the Healer) to more than 8 m: no heal.
3. Healer HP: dies on the sixth sword hit, plays `death`, leaves a corpse; no flinch.
4. Shot: each chargeup fires one shot per Healer, the `shoot` release matching the spawn; a refused press fires none.
   Keyboard deflects one (nothing), rolls one (it passes), blocks one (full 3), takes one (3).
5. Elemental Fury refusal: with only the blue orb held the activation is refused, the orb is kept, the card stays staged;
   after gaining another orb, the same staged card activates successfully.
6. Elemental Fury: one coloured shot per remaining orb, all at the keyboard hero; the orbs are still held afterwards. Red
   damages, blue slows, green heals the pad hero 5 on hit; a deflected green heals nothing.
7. Wrath telegraph: a ground ring for about 0.8 s; more held orbs give a visibly larger ring; one pulse, no zone.
8. Wrath on the hero: damage, a slide directly away, a short stun; a swing, a chargeup and a block are each interrupted.
9. Wrath at the wall: a hero and a hound pushed at a wall stop at it.
10. Wrath defences: roll through it (nothing); walk out in the windup (nothing); hold block facing it (half, no slide, no stun);
    timed deflect (nothing).
11. Wrath on units: the keyboard's hounds take damage, slide and drop their attack; the pad's own Healer is untouched.

**Launch 2 - pad Deck 1, keyboard Deck 2**
12. Counterspell: the keyboard plays Healer and the pad counters it: the Healer vanishes with no corpse.
13. The keyboard's Healer shoots on a keyboard unblockable (X / V / B); the pad seat blocks, deflects and rolls it.
14. Tint: the keyboard Healer's owner tint differs from the pad seat's Healer in a mirror (launch 1 vs 2 views).
15. R-D6: a round ends by a kill; Healers' owed shots, a pending pulse and every marker clear; the next round is clean.
16. fps stable throughout.

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 0.1 | 2026-10-14 | created (Status authored; board key stays backlog; not cleared for a dev pass).
- 0.2 | 2026-10-14 | gate fix-and-promote: `7-5b/R1..R23` seated (blockers B1-B4 and notes N1-N12), Open Questions replaced by
  Rulings, Status ready-for-dev.

## Rulings

`7-5b/R1..R23` (decision log session "2026-10-14 -- 7-5b gate rulings"). Seats: R2 AC 4; R3 AC 6; R4, R23 AC 8; R5 AC 12; R6 AC 14;
R7 AC 13, 15; R8 AC 16, 18; R9 AC 20; R10-R11 AC 21; R12 AC 13, 16; R13 AC 11; R14 AC 9; R15 Supersedes, Deferred; R17 AC 6; R18 AC 18;
R19 AC 5, Tests that move; R20 AC 2; R21 AC 3; R22 T8, Deferred. R1 and R16 have no seat.
