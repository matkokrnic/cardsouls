---
baseline_commit: 3c2d277fb13c8a171ce0a548f1d99e1907955dd1
---

# Story 6.5d: Fireball and Spell Targeting

Status: done

<!-- Tier A; fourth of six 6-5 sub-stories. Board keys reshuffled at authoring on operator instruction
(2026-09-26). Scope = the operator's scope talk of 2026-09-26; rulings are `6-5d/R1..R23` in the
decision-log session "2026-09-26 -- 6-5d scope + readiness gate" and are cited by label below. Readiness
gate `C:\dev\_65d-gate.md` applied (3 blocking / 4 major / 6 minor). Golden PREDICTED to move,
FORMAT_VERSION PREDICTED 15 -> 16. Cite by CONTENT (grep strings given); line numbers are as of 3c2d277. -->

## Story

As the operator (and later the friends playtest),
I want Bloodhound Step's pitch to be Fireball -- a spend-everything homing projectile the caster throws
after a visible cast -- and I want offensive spells to go where the caster is looking,
so that the Red half of Deck 1 has its big finisher, the first hero-sourced projectile exists on the 4-4
projectile infrastructure for Rocksling and Corpse Bomb to reuse, and "lock a minion, then bolt it" and
"lock the hero, then Fireball it" are things a player can actually do.

## Board note

`sprint-status.yaml` key `6-5d-fireball-and-spell-targeting` (renamed from
`6-5d-hero-and-corpse-projectiles` at authoring, position and `# Tier A` kept), board status
`ready-for-dev` (promoted at the gate pass on the operator's decision). Depends on
`6-5c-hero-cast-honed-bolt` (`done`).
`6-5e-rocksling-boom-and-corpse-bomb` (was `6-5e-boulder-injection`) reuses the hero projectile source
built here. **M5 and M6** (`deferred-work.md` rows M5/M6, `_44-review.md`) move
here: both are defects of the 4-4 projectile infrastructure this story first extends (AC 37, AC 38).
The board reshuffle is `6-5d/R14`.

## What this story supersedes

1. **The 6-5c target rule.** `deck-1-spec.md` (amendment 2026-09-25) says Honed Bolt's target "is
   always the enemy hero, never a minion, regardless of lock-on". SUPERSEDED: the bolt (and Fireball)
   target the caster's lock-on target (AC 24-28; `6-5d/R6`). The dated amendment to `deck-1-spec.md` is written in
   THIS pass (docs-only, separate from code by the commit convention).
2. **The Bloodhound Step -> Bloodlust pairing** in Deck 1 (`data/cards/bloodhound_step.tres`
   references `data/effects/bloodlust.tres` as `4_pitch`). Bloodlust stays as an effect definition
   (destined for deck 2); only the Deck 1 pairing changes, as data (AC 1, AC 2), as the
   `deck-1-spec.md` amendment of 2026-09-22 already says.
3. **Two 6-5c code comments that state the opposite of the new behaviour** and must be rewritten by the
   dev pass, not left to lie: `_apply_honed_bolt`'s docstring ("INSTANT AND UNAIMED ... LOCK-ON is
   irrelevant ... It can never hit a minion or a totem") and `_resolve_basic_cast`'s "THE OTHER APPLY
   SEAT (`_resolve_pitch_activate`) IS DELIBERATELY NOT FORKED. No card's PITCH effect is a cast id
   today" (grep both strings). Fireball is the first PITCH cast id. The disjointness pin that says so
   is `test_hero_cast.gd::test_no_authored_pitch_effect_is_a_cast_id` (it scans `data/cards/`); the
   `_resolve_basic_cast` comment wrongly cites `test_spell_framework.gd` for it, and the rewrite corrects
   the citation.
4. **`DEFERRED_EFFECT_OWNERS`** in `card_effect_resolver.gd` names the OLD board slugs as data
   (`&"rocksling": &"6-5d-hero-and-corpse-projectiles"`, `&"boom": &"6-5e-boulder-injection"`,
   `&"corpse_bomb": &"6-5d-hero-and-corpse-projectiles"`), pinned verbatim by
   `test_spell_framework.gd` (grep `6-5d-hero-and-corpse-projectiles`). The board rename makes them stale:
   all three rows move to `6-5e-rocksling-boom-and-corpse-bomb` (AC 35; `6-5d/R14`).

## Repo-verified facts this story is authored against

Content citations (grep the quoted string).

- **Pitch staging pays at staging, reads no effect.** `MatchState._resolve_pitch_stage`
  (`func _resolve_pitch_stage`): flag gate, CHARGING/STUNNED gates, empty-slot, zone-occupied, then
  `var condition: CardCastCondition = _pitch_costs.get(id)`, then
  `CastEvaluator.flag_and_mana_refusal_reason(condition, player.mana.get_current(), flags)`; a non-`ALLOWED`
  reason goes to `player.hero.reject_action(&"card_cast", reason)` and `return`s BEFORE
  `player.mana.spend(condition.mana_cost)`. **That is the existing refusal path the below-3 rule uses:**
  `CastEvaluator.REASON_INSUFFICIENT_MANA`, nothing spent, nothing staged. The fixed spend is
  `Invariant.check(player.mana.spend(condition.mana_cost), "an ALLOWED staging must be affordable ...")`.
- **`PitchState` per-slot storage** (`src/state/pitch/pitch_state.gd`): `_card_ids`, `_hand_slots`,
  `_orb_costs`, `_fizzle` -- no per-staging mana figure exists. `stage(slot, card_id, hand_slot,
  orb_costs, timer_ticks)`; snapshot via `to_snapshot()` / `_zone_snapshot`.
- **Pitch activation** (`func _resolve_pitch_activate`): flag gate, STUNNED gate (`REASON_STUNNED`),
  `REASON_EMPTY_PITCH_ZONE`, `REASON_PITCH_NOT_READY` (`pitch.is_ready`), then the board gate
  `var gate := _board_refusal_reason(player, pitch_effect)` BEFORE the orb spend, then orbs spent, card to
  discard, `pitch.clear`, `_apply_card_effect(player, pitch_effect, slot)`, `record_resolved_card(card_id,
  Enums.ModeKind.PITCH)`, replacement owed. The pitch-effect map is read EXACTLY ONCE
  (`var pitch_effect: CardEffect = _pitch_effects.get(pitch.staged_card_id(slot))`), a pin in
  `test_deck_and_hand.gd`.
- **The cast is keyed by CARD ID and resolves off the BASIC effect map.** `PlayerState.start_cast(card_id,
  duration_ticks)` stores `cast_card_id`; the strike seat reads
  `var effect: CardEffect = _card_effects.get(StringName(player.cast_card_id))`
  (`func _resolve_cast_strikes`). For Bloodhound Step that key names the BASIC effect
  (`bloodhound_step`, the roll buff), not the pitch effect -- **a pitch cast cannot be told apart from a basic
  cast of the same card by the current key.** (Open Question 1.)
- **Cast fork today is Mode 1 only.** `_resolve_basic_cast`: `CardEffectResolver.starts_cast(cast_effect,
  flags)` -> `player.start_cast(...)`, plus the review-fix block drop
  (`if player.hero.action_state == HeroState.ActionState.BLOCKING: ... set_action_state(IDLE)`).
  `CardEffectResolver.CAST_OUTCOMES` holds one row (`&"honed_bolt"`); `CAST_REQUIREMENTS` holds
  `&"honed_bolt": NEEDS_ENEMY_HERO`, evaluated at the pre-spend seat `_board_refusal_reason`.
- **The cast lock** is `player.is_casting()`: silent drop at the action seat, announced
  `REASON_CASTING` at the card seat (`_resolve_card_action`), body rooted in `_resolve_movement`. Only
  `_cast_is_interrupted` ends a cast without a strike (stunned / dead / not alive); round end and debug
  reset clear it through `clear_cast()`. `cast` is a hashed per-player snapshot key
  (`"cast": [cast_card_id, cast_window.remaining_ticks()]`).
- **Honed Bolt today** targets by slot arithmetic only: `var target_slot := 1 - slot` in
  `_apply_honed_bolt`, dodge via `_iframe_open_at_step3[target_slot]`, damage via `_funnel_damage(caster,
  HERO_INDEX, target, HERO_INDEX, effect.damage_amount)`, then `_apply_bolt_landing` (stun + root).
  Nothing reads `lock_target`.
- **Lock-on storage.** `PlayerState.lock_target_slot` / `lock_target_index` (one hashed key
  `lock_target: [slot, index]`); `is_locked()` is `lock_target_slot != UNLOCKED_SLOT` (6-8). The resting lock
  is the opposing hero; a locked unit's death snaps the lock back to the opposing hero
  (`_reset_lock` / the snap-back block near `player.lock_target_index == TargetingService.HERO_INDEX`).
  Address convention `[slot, index]`, `TargetingService.HERO_INDEX == -1`, units `>= 0` (totems are units
  with a non-default kind).
- **The 4-4 projectile is a unit-kind projectile.** `ProjectileBoard.add(target_slot, target_index,
  kind_index, source_index)`; the record stores the firing unit's KIND INDEX and nothing authored:
  damage comes from `_attacker_attack_damage` -> `balance.kind_at(kind_index).attack_at(0).damage`, the
  profile from `_projectile_profile_at` / the runner twin `_projectile_profile` (both through
  `kind.attack_at(0).projectile`). `add` is called from exactly one seat (`_advance_unit_attacks`, grep
  `player.projectiles.add(`). Hero attackers cannot fire one today. Snapshot keys: `projectile_alive`,
  `_flight_ticks`, `_homing`, `_kind`, `_source`, `_targets`, `_travelled` (7 of the 38).
- **Totem shot profile (the starting numbers)**, `data/balance/balance_config.tres`
  `Resource_combat_projectile`: `launch_speed = 8.0`, `homing_turn_rate_degrees_per_second = 120.0`,
  `acceleration_delay_seconds = 0.4`, `acceleration_per_second_squared = 12.0`, `max_speed = 20.0`,
  `travel_budget = 60.0`.
- **Contact address and the pass-through gap.** `_gather_projectile_facts` (`match_runner.gd`) pushes a
  contact fact for EVERY opposing hurtbox the shot's `Hitbox` overlaps (`if address[0] == attacker_slot:
  continue  # a shot never hits its own side` is the only filter). **A 4-4 shot therefore already hits
  whatever opposing body it overlaps first, not only its target**, and a landing on a unit consumes it
  (`_consume_projectile_attacker` at the end of `_resolve_unit_contact`, "Story 4-4 (AC 16 second sentence
  / AC 18)"). "Non-target minions do not absorb Fireball" is a NEW rule, not the shipped behaviour
  (Open Question 3; `6-5d/R5`); the totem's shot keeps the shipped first-body behaviour (`6-5d/R11`).
- **The hero contact ladder** (`_resolve_contacts`), in order: dead-attacker drop; **`if
  target.hero.is_iframe_open():` -> `attacker.projectiles.end_homing_at(...)` and `continue`** (homing ends,
  shot NOT consumed, "4-4 (AC 16, `4-4/R4`)"); dedupe; damage from the attacker; then `if
  target.hero.action_state == BLOCKING and _is_facing(...)`: an open deflect window with a successful
  `stamina.spend(balance.deflect_stamina_cost, ...)` negates, calls `_consume_projectile_attacker`, pushes
  `deflect_landed`, and the attacker-stun consequence is gated on `attacker_index ==
  TargetingService.HERO_INDEX` (a projectile index is not); otherwise the block multiplier applies.
- **Rise (get-up) i-frames ARE covered by the contact rung.** `HeroState.is_iframe_open()` is
  `roll_iframe.is_running or _roll_iframe_closed_this_tick or get_up_iframe.is_running or
  _get_up_iframe_closed_this_tick` (`hero_state.gd`). The contact rung reads that LIVE predicate. The
  step-3 latch (`_iframe_open_at_step3`, "`is_iframe_open() or _gets_up_this_tick(hero)`", written before
  any press of the tick) is the WIDER reading used by the unblockable dodge rung and the bolt; it is NOT
  what the projectile contact rung reads. So for Fireball: roll and rise i-frames both drop the contact
  and end homing (verified), with the projectile rung's own live-predicate timing (a roll pressed on the
  contact tick is judged by the live predicate at step 4, not the step-3 latch). Recorded so the two
  seats' different tick semantics are not "fixed" into each other.
- **Damage funnel.** `_funnel_damage(attacker, attacker_index, target, target_index, damage)` -- Bloodlust
  dealt/taken multipliers; `_is_bloodlust_body` returns FALSE for a projectile attacker index ("never a
  projectile, which today only a totem fires"); `_apply_lifesteal` heals only when
  `attacker_index == TargetingService.HERO_INDEX`. **Contradiction to solve:** a hero-fired Fireball
  carries a projectile index, so as shipped neither Bloodlust's dealt multiplier nor Vampiric Aura would
  apply to it, contradicting the standing rule that both reach every spell (AC 14, Open Question 2).
- **Presentation seats.** `_push_cast_presentation` (runner) arms the cast pose, the bolt prop
  (`BoltActor`) and `on_cast_warning_started()` on the OTHER hero's `telegraph_controller`; reads only
  `is_casting()` and the `cast` window. The warning is currently hero-to-hero by slot arithmetic.
  Projectile actors: `PROJECTILE_SCENE` (`projectile_actor.tscn`), spawned by
  `_spawn_missing_projectile_actors`, launched at `board.source_index_at(index)`'s unit or "the owner
  hero as fallback" (`_projectile_launch_position`).
- **Mana.** `data/balance/balance_config.tres` `max_mana = 10.0`. The 6-5d cap (10) equals the pool
  maximum today, so the cap is INERT (Dev Notes). `ManaPool.get_current()` / `.spend()`.
- **Golden and key set** (verified at authoring): `test_determinism.gd` `const GOLDEN :=
  "97d52922e4e6282b37582e8c3a9c424a02337162881c37a7f6a3394277efdc92"`; `src/systems/record_file.gd`
  `const FORMAT_VERSION := 15`; the per-player key set
  `EXPECTED_PLAYER_SNAPSHOT_KEYS` in `test_draw_delay_and_reshuffle.gd` has **38** keys (counted;
  alphabetical, from `cast` to `unit_targets`, includes `root`).

## Discrepancies found against the prompt (repo wins)

1. **"Reuses the 4-4 projectile ... with the hero as source."** The 4-4 record is a KIND-INDEX record
   whose damage and profile are read through a unit kind; a hero has no kind, and Fireball's damage is
   per-shot (locked X). The reuse is of the flight machinery (homing, acceleration, odometer, contact
   rungs, i-frame drop, deflect consumption), not of the record's data source (Open Questions 2, 4).
2. **"Non-target minions do not absorb it."** Not shipped behaviour for ANY projectile (facts above).
3. **"Uses the 6-5c visible-cast frame" for a PITCH effect.** The frame is Mode 1 only and keyed by card id;
   the strike would resolve Bloodhound Step's basic effect (Open Question 1).
4. **"Roll i-frames (and rise i-frames, if the step-3 latch covers them)".** The projectile rung does not
   use the latch; it uses `is_iframe_open()`, which itself includes the get-up window. Both are covered;
   the reading is different from the bolt's (facts above).
5. **Bloodlust and Vampiric Aura "apply - standing rule for every spell"** conflicts with two shipped
   projectile exclusions (facts above). The standing rule wins; the exclusions are the thing to change,
   for a HERO-sourced shot only (a totem shot stays unbuffed, AC 36).

## Operator scope talk of 2026-09-26, carried as behaviour

The whole scope is carried by the Acceptance Criteria below: pairing swap (AC 1-4), X cost and lock
(AC 5-9), cast (AC 10-13), flight and defence (AC 14-23), targeting (AC 24-29). What the operator FIXED
there is behaviour (`6-5d/R1..R8`); every number marked `.tres` and every placeholder visual (fireball,
trail, cone on a minion, feeding the Tier B presentation story after 6-5f) is an authored default the
operator did not veto. The three questions the first authoring left open (totem pass-through, M6 on
detection, launch-tick dead target) are closed at the gate as `6-5d/R11..R13` and are flat ACs (36, 38, 22).

## Acceptance Criteria

### Data and pairing

1. `data/cards/bloodhound_step.tres` references a NEW `data/effects/fireball.tres` as its pitch effect;
   its basic effect, colour (RED), `cast_condition`, `max_copies = 3` and the 20-card composition are
   unchanged; its `pitch_condition` changes (AC 3). No Deck 1 card references `bloodlust.tres`.
2. `data/effects/bloodlust.tres` still exists, loads, and is field-for-field unchanged (`duration_seconds
   10`, both multipliers 2.0), pinned by the effect-file pin in `test_card_authoring.gd`. Every behaviour
   test of Bloodlust still passes on its existing in-test fixtures; no card is added for it.
3. `fireball.tres` authors, as flat `CardEffect` fields (no subclass, no nested resource): `effect_id
   = &"fireball"`, `damage_per_mana = 1.5`, `mana_cap = 10.0`, `cast_seconds`, and the flight numbers
   `launch_speed = 8.0`, `homing_turn_rate_degrees_per_second = 120.0`, `acceleration_delay_seconds = 0.4`,
   `acceleration_per_second_squared = 12.0`, `max_speed = 20.0`, `travel_budget = 60.0` (names are the dev
   pass's; the values start from the totem shot's profile). The minimum (3) and the orb price (1 red) are the
   card's `pitch_condition` (`mana_cost = 3.0`, orb `RED: 1`), the existing fields: the pitch mana cost
   MOVES 4.0 -> 3.0 (Fireball's own minimum; Bloodlust's 4 leaves with Bloodlust; `6-5d/R9`). No number in
   `src/` is a literal for any of these (authoring audit, on the `test_card_authoring.gd` precedent).
4. Neutral defaults: every new `CardEffect` field's default leaves every other effect's behaviour
   bit-identical (an unused number cannot change an outcome).

### Staging (the X cost)

5. (`6-5d/R1`) Staging Fireball with current mana X >= 3 spends min(X, `mana_cap`) mana (all of it, at the authored
   cap 10 and max mana 10), stages the card, and leaves the pool at X - spent (0 today). The staged card
   remembers the spent amount.
6. Staging with current mana below 3 is REFUSED through the existing refusal path
   (`CastEvaluator.REASON_INSUFFICIENT_MANA` via `reject_action(&"card_cast", ...)`): mana untouched, the
   card stays in hand, nothing staged, no orb change, no replacement owed.
7. (`6-5d/R2`) The damage is locked at staging: it equals `damage_per_mana` x the mana spent, with NO rounding (X = 3 ->
   4.5; X = 7.3 -> 10.95). Mana gained or lost after staging cannot change a staged card's damage. Whether
   an authored `damage_per_mana` retune between staging and activation is seen is Open Question 5;
   whichever side the dev pass picks is pinned by a test and recorded.
8. The pitch-zone rules are otherwise unchanged: one card per zone, the fizzle countdown runs
   at the authored length; a Fireball that fizzles goes to the discard with its mana NOT refunded and
   casts nothing; a staged Fireball never affects the pool after staging.
9. Staging any other pitch card (fixed cost) is bit-identical to today.

### Activation and cast

10. (`6-5d/R3`) A staged Fireball activates ONLY through the existing pitch-activation flow, requires and spends the 1
    red orb (unchanged refusals: stunned, empty zone, not ready, closed flag); it waits in the zone until
    then. Activation spends the orb, discards the card, clears the zone, owes the replacement, records
    the resolved card as PITCH -- and then STARTS A CAST instead of applying an instant effect.
11. The cast is the 6-5c frame: `cast_seconds` per effect from `.tres`; the caster stands and every
    action and card press is refused/dropped exactly as for Honed Bolt; starting the cast drops a held
    block on the same tick; only being stunned interrupts, and then the card and the mana are LOST (no
    refund, no projectile); a caster who dies mid-cast never fires; round end and debug reset clear the
    cast.
12. The cast's strike resolves the card's PITCH effect (Fireball), never the same card's basic effect: a
    Bloodhound Step Fireball never arms a roll buff, and a Bloodhound Step BASIC cast still arms it and
    starts no cast.
13. At cast end (the strike tick) a Fireball projectile is placed on the CASTER's projectile board, sourced
    at the caster's hero, addressed at the target captured at cast start (AC 24), and launches from the
    hero. Spells layer flag closed -> no cast starts (the resolver's existing degrade, unchanged).

### Flight, contact, defence

14. **Damage.** A Fireball that lands deals exactly the locked damage through `_funnel_damage`: the
    CASTER's Bloodlust dealt multiplier and the TARGET's Bloodlust taken multiplier both apply, and
    Vampiric Aura heals the caster from the HP actually removed (the hero-sourced shot counts as the hero's
    own damage for both). A TOTEM's shot is unaffected (AC 36).
15. **A hit is damage only:** no stun, no root, no `STUNNED` write, no state change on the target beyond
    HP; `hit_landed` is announced as for any hero hit.
16. **Block does not help** (`6-5d/R4`). A BLOCKING target takes the full damage (no block multiplier), whether or not
    it faces the shot. A DEFLECT (blocking, facing, deflect window open, stamina paid as today) negates it
    entirely and CONSUMES it (no damage, no `hit_landed`, `deflect_landed` announced); the caster is NOT
    stunned by the deflect.
17. **Roll and rise i-frames.** While the target's `is_iframe_open()` (roll window incl. its one-tick grace,
    and the get-up window) the contact drops: no damage, the shot is NOT consumed, its homing ENDS on that
    tick and never resumes, and it flies straight on its last heading until it is consumed elsewhere or its
    60 m budget expires.
18. **Running away does not escape it.** A live homing Fireball keeps steering toward a moving target at the
    authored turn rate until contact, an i-frame drop, or budget expiry; nothing else ends its homing.
19. **Minion and totem targets** have no defence: the shot always lands on them, consumed on impact, damage
    through the funnel's unit seat (a minion target counts for Bloodlust as any minion), a lethal hit
    leaves a corpse through the same death seat as every other combat kill (6-5b), no stun, no root.
20. **Non-target bodies do not absorb it** (`6-5d/R5`). A Fireball overlapping any opposing body that is not its
    captured target produces no damage, is not consumed and has no i-frame effect. (Fireball only; see
    AC 36.)
21. **Target dead before impact** (`6-5d/R15`). The Fireball ends its homing when its target dies, flies
    straight and expires at 60 m; it deals no damage to a corpse and does not re-acquire a new target.
22. **Target dead on the launch tick** (`6-5d/R13`). A Fireball whose captured target is already dead at the
    strike tick is still placed and launched, flies straight on its launch heading from the hero, homes on
    nothing, damages nothing and expires at `travel_budget`; it never re-acquires and never falls on the
    lock's snap-back hero. Test: `test_fireball.gd`.
23. **Budget.** A Fireball that hits nothing expires exactly at the authored `travel_budget` (60 m), is
    removed from the world (actor freed) and never damages anything afterwards. The projectile board's
    indices are never reused (`ProjectileBoard.add` stays an unconditional append).

### Spell targeting (Fireball AND Honed Bolt)

24. The target is the caster's lock-on target AT CAST START (the press tick; `6-5d/R6`): a locked caster's
    `lock_target` address (opposing hero, minion or totem); an UNLOCKED caster (6-8) targets the opposing
    hero (`6-5d/R7`). It is fixed for the whole cast and the flight (`6-5d/R15`): a re-lock or unlock after
    cast start changes nothing. The captured address is hashed state (AC 30), not re-derived from the actor.
25. **Honed Bolt on a minion or totem** (`6-5d/R8`): 4 damage through the funnel (Bloodlust and Vampiric Aura apply,
    a lethal hit leaves a corpse), NO stun, NO root, no dodge test (a unit has none). **On a hero:**
    exactly the 6-5c behaviour -- damage, stun, root, the knockdown floor, the repeat-landing switch, the
    step-3 latch dodge, block/deflect irrelevance (every 6-5c test on a hero target passes UNCHANGED).
26. **Bolt target dead before impact** (`6-5d/R15`): the bolt hits nothing -- no damage, no `hit_landed`, no
    stun -- and the card and mana are lost (never refunded). A target that died and was then snapped back to the
    opposing hero (the lock snap-back) is NOT the captured target: the bolt still hits nothing.
27. The pre-spend target requirement (`board_requirement_for`, `NEEDS_ENEMY_HERO`) keeps working and
    reads the CAPTURED-target rule: a card whose target cannot exist is refused before any spend. It has no
    player-reachable case today (the lock always snaps back to a live hero) and is proven with a
    synthetic fixture, as 6-5c did.
28. The presentation reads the captured target (`6-5d/R10`): the target-warning marker and alarm are placed
    on the CAPTURED target (a hero -> today's marker; a minion or totem -> a placeholder cone on that unit)
    for the whole cast, on both Honed Bolt and Fireball; the marker never appears on a non-target. The
    visible cast prop (the bolt) travels to the CAPTURED target, a minion or totem included (a placeholder
    look is acceptable, a wrong destination is not). The Fireball actor follows its projectile record, so
    its visible flight matches its state target. (Legibility is judged at live smoke, `PROC/R8`.)
29. The caster's facing and cast pose follow the locked-target facing rule already in force
    (world-space planar, target-derived only while locked, 6-8 AC 3); this story adds no facing rule.

### Determinism, replay, format

30. Every new cross-tick fact is snapshotted and hashed (or is a pure function of hashed facts, argued):
    the mana spent at staging, the captured cast target and the pitch/basic identity of the in-flight
    cast, the locked damage carried to the launch, and each hero-sourced projectile's per-shot damage and
    source identity. The per-player key set and the pitch snapshot are pinned by their existing tests,
    which move deliberately.
31. `RecordFile.FORMAT_VERSION` moves 15 -> 16 with a HARD refusal of a v15 file (recorded content gains
    fields whose defaults would replay a Fireball as a no-op); if measurement shows the recorded shape did
    not move, it stays and the reason is recorded.
32. A recorded match containing a Fireball (staged, activated, flown, landing or expiring) and a targeted
    Honed Bolt on a minion replays to the identical final hash and the identical record
    (`test_replay_identity.gd`'s discipline).
33. The single `_physics_process`, the `Input.*` seam and the no-global-RNG/`Time`/`OS`/`Engine` rules stay
    green (`test_architecture_invariants.gd`); no new runner-pushed fact is predicted, and any new public
    `MatchState` method taking a parameter has a capture channel or a named exemption
    (`test_intent_recorder.gd`).

### Regression and carried findings

34. Every 6-5a/6-5b/6-5c behaviour not named above is unchanged: buffs instant, the own-minion/corpse
    spells, the Mode 1 Honed Bolt cast on a hero, the deferred cards (Rocksling, Boom, Counterspell, Corpse
    Bomb) still resolving as the named deferred no-op.
35. `DEFERRED_EFFECT_OWNERS` names `6-5e-rocksling-boom-and-corpse-bomb` for `rocksling`, `boom` and
    `corpse_bomb` and `6-5f-counterspell` for `counterspell`; `fireball` is not a deferred row; the pin in
    `test_spell_framework.gd` moves with it.
36. **The totem's shot is bit-identical except where Bloodlust already reached every hero target**
    (`6-5d/R11`, corrected by the AC 36 operator ruling 2026-09-27): damage, speed, acceleration, homing,
    i-frame drop, deflect and the block multiplier are all unchanged, and it still lands on the first
    opposing body it touches (pass-through is Fireball-only). A totem shot gets neither its owner's
    Bloodlust DEALT multiplier nor Vampiric Aura -- the two exclusions 6-5d had to widen for a
    hero-sourced shot without breaking them for a totem's. A Bloodlusted TARGET still takes double, as it
    always has (`_is_bloodlust_body` returns true for any hero target on its first line; this story never
    touches that branch). Every `test_projectile_flight*.gd` / `test_unit_combat_live.gd` assertion passes
    unchanged. NEW assertions (tests ADDED, in `test_fireball.gd`): with the totem's OWNER under Bloodlust
    (dealt) and Vampiric Aura up, a Combat totem's shot deals its authored `attack_at(0).damage`
    UNMULTIPLIED and heals nobody; with the TARGET under Bloodlust (taken), the same shot deals DOUBLE; a
    BLOCKING hero still takes the block-mitigated damage from a totem shot.
37. **M5:** the homing test `test/integration/test_projectile_flight_live.gd` asserts the shot's angle to
    its target does not grow (bearing compared to the shot->target vector, monotonic non-increasing or
    smaller at the last sample than the first) and is mutation-proven against a sign-inverted
    `steer_toward`; the Fireball live test carries the same direction-aware assertion.
38. **M6** (`6-5d/R12`): a reload whose `unit_kinds` is a same-length reorder of the running config's,
    while any unit or projectile record is live, is REFUSED: the running config is kept unchanged, no
    record is re-pointed, and the refusal names the reordered kind (a reason string a test asserts). Every
    other reload (unchanged, appended, X3-legal) is unaffected.

## Non-Goals

- Rocksling stones, Boulder injection, Boom, Corpse Bomb, corpse projectiles -- `6-5e`.
- Counterspell and undo of anything 6-5a..6-5e ships -- `6-5f`.
- Real VFX, clips, audio for the fireball / trail / cone on a minion -- placeholders owed to the Tier B
  presentation story after `6-5f`; the dev pass reuses the 6-5c cast pose and a grey projectile actor.
- Any change to melee, unblockables, the colour counter, roll or stamina beyond the cast lock reuse.
- Deck 2, any change to Bloodlust's numbers, retuning `max_mana`, any new HUD or cue vocabulary.

## Golden Prediction (predictions to MEASURE, not claims)

Baseline to measure and save outside the repo BEFORE any edit: golden
`97d52922e4e6282b37582e8c3a9c424a02337162881c37a7f6a3394277efdc92`, `RecordFile.FORMAT_VERSION` 15,
per-player snapshot keys 38, the pitch snapshot shape, suite (state + integration counts) -- re-measure;
do not trust any figure in this file.

**PREDICTED to MOVE.** Causes to be separated and measured each in isolation, on the 6-5a/6-5b/6-5c method
(erase the new keys from `to_snapshot()` with every other change in place; the hash must return to the
baseline exactly):

1. **Pitch snapshot: the mana spent per staging** (new per-slot field on `PitchState`). At rest the zone is
   empty in the determinism fixture unless it stages -- measure key/shape change and resting contents.
2. **Cast snapshot: the captured target and the effect-mode identity of the in-flight cast** (extends the
   `cast` key or adds keys; the dev pass records which and why). At rest empty.
3. **Cast/projectile: the locked damage in flight and the per-shot damage/source identity** (new
   `ProjectileBoard` field(s) and/or new snapshot arrays). At rest empty.
4. **Which pins move** (predicted, not claimed): `EXPECTED_PLAYER_SNAPSHOT_KEYS` (38) in
   `test_draw_delay_and_reshuffle.gd` and `test_card_observation.gd`'s copy if a per-player key is added;
   `test_debug_window_countdown.gd` if a window key moves; `test_pitch_staging.gd` /
   `test_pitch_changed.gd` for the pitch shape. The dev pass RECORDS which moved.
5. **New refusable outcomes.** No NEW refusal is added: the below-3 staging refusal reuses
   `REASON_INSUFFICIENT_MANA`, the cast lock reuses `REASON_CASTING`. Under the standing `SC/R6` boundary
   (a pressed action made refusable moves the golden if the recorded sequence presses it) this is a
   PREDICTED NON-cause, MEASURED anyway.
6. **Non-causes to confirm (`BC/R3`):** the authored `fireball.tres` numbers, the `bloodhound_step.tres`
   pairing swap and any new `CardEffect` field defaults -- the golden builds its effects in-test and never
   loads `data/effects/`; state whether the effect INJECTION shape moved the hash and measure it apart
   from 1-3.
7. **Behaviour causes:** the Honed Bolt target capture is a behaviour change on a hero target of NOTHING
   (locked on the hero is the resting lock), so the golden's existing bolt/no-bolt content is predicted
   unmoved by AC 25's hero arm; measure it.
8. **`FORMAT_VERSION` PREDICTED 15 -> 16** (AC 31). A record carries inputs and content, never a hash.
9. **Intake:** none predicted; the lock target is already a hashed per-player key fed by the recorded
   retarget intent.

**Measure, do not assume:** full suite before any edit and after, golden hash / key counts /
`FORMAT_VERSION` in both runs, files saved outside the repo. Exactly one re-baseline is expected; a
second is a finding to explain.

## Live Smoke (operator, two pads, flip config `[3,3]`; the operator may reset it at the gate)

Flip `slot_controller_kinds = Array[int]([3, 3])` (two gamepads: two killable, human-driven slots).
**Fireball and the targeted bolt can kill, so R-D6 is RE-INVOKED for this story** (its acceptance is spent
on use and is re-invoked per story against a killable human-driven slot: decision-log `R-D6` entries,
`2-1/R2`, `6-1c/R4`). The binding editor-collateral procedure (`6-1c/R4`), restated verbatim as 6-5b and
6-5c did:

- Flip config edited TEXTUALLY with the editor closed.
- `git diff` immediately after adding the flip config, and again immediately after removing it.
- After any editor session, `git diff -- project.godot` and revert any collateral change:
  `git checkout -- src/main/main.tscn project.godot` (full paths, both files).
- Editor reload dialog: always "Reload from disk", never "Ignore external changes".
- Re-check `git status` + the collateral diff immediately before any commit chain begins -- not earlier in
  the session.

1. **Stage and cost.** With < 3 mana the pitch press on Bloodhound Step is refused (cue), nothing spent.
   With N >= 3 mana all N is spent and the mana bar drops to 0 (cap inert at max 10).
2. **Activation and cast.** With 1 red orb press activate: orb spent, the visible cast, the caster stands
   and cannot act; a held block drops at cast start; a card press during the cast is refused with the
   announced cue.
3. **The shot.** The projectile leaves the caster at cast end, homes on the target with the totem-shot
   feel (accelerating), and lands for 1.5 x the mana spent (compare a 3-mana and a 10-mana Fireball).
4. **Defence.** Blocking: full damage. A perfect deflect: no damage, the shot vanishes, the caster is
   not stunned. A roll timed into it: no damage, the shot then flies straight past and out at 60 m. A hero
   getting up dodges it the same way. Running away does not escape.
5. **Hit is damage only.** No stun pose, no root marker on the target.
6. **Locked target and minions.** Lock a minion (right stick) and Fireball / Honed Bolt it: it lands on the
   minion (no stun, no root) and a lethal hit leaves a corpse. Lock the hero with minions in between:
   the shot passes through the minions and hits the hero. Unlock (6-8) and cast: it goes to the opposing
   hero.
7. **Target dies mid-flight.** Kill the locked minion while the Fireball flies: it flies straight and is
   gone at 60 m. Kill it during a Honed Bolt cast: the bolt falls on nothing, the card and mana are gone.
8. **Warning marker and prop on the target.** During a cast the alarm/marker sits on the captured target (a
   hero, or a placeholder cone on the minion), for both spells, and the visible bolt / Fireball flies to that
   same target (a minion included; placeholder look acceptable, wrong destination not). Legibility is
   judged here (`PROC/R8`).
9. **Buffs.** Vampiric Aura heals the caster from the hit. (Bloodlust has left Deck 1, so its doubling is
   covered by the suite's in-test fixtures, not by the smoke.)
10. **Interrupts.** A stun on the caster mid-cast (deflect stun / unanswered unblockable): no Fireball;
    ordinary hits do not interrupt.
11. **Lethal.** Fireball a low target: the round ends normally (R-D6), no stun/root leftovers.
12. **Regression.** A Combat totem's shot, every 6-5a/6-5b card, the Mode 1 Honed Bolt on a hero and the
    still-deferred cards behave as before; no crash or assert; fps stable.
13. **Fizzle.** Stage a Fireball with mana and let the zone timer run out: the card goes to the discard, the
    mana is NOT refunded, nothing is cast (the one path where a player loses a full pool for nothing).

## Tasks / Subtasks

- [x] **Task 1: Baseline (before any edit).** Save outside the repo: suite counts, golden,
  `FORMAT_VERSION`, per-player key count (38), pitch snapshot shape, `git rev-parse HEAD`. (AC 30-33)
- [x] **Task 2: Data.** `data/effects/fireball.tres`; swap the pairing and the pitch price in
  `bloodhound_step.tres`; the flat `CardEffect` fields (header comment updated, neutral defaults); move the
  Bloodhound rows, `DECK_1_PRICES` and the bucket census in `test_card_authoring.gd`, and the rows in
  `test_card_database.gd`, `test_deck_injection.gd`. (AC 1-4)
- [x] **Task 3: Staging.** Per-staging mana figure on `PitchState` (snapshotted); spend
  `min(current, mana_cap)` for a variable-cost pitch effect only; keep the existing refusal. Resolve Open
  Question 1 (staging half) and 5. (AC 5-9)
- [x] **Task 4: Pitch cast fork and cast identity.** The cast carries the effect it strikes (pitch vs
  basic), the captured target and the locked damage; `_resolve_pitch_activate` starts the cast (with the
  block drop); `CAST_OUTCOMES` gains the Fireball row; rewrite the two 6-5c comments (`_apply_honed_bolt`'s
  docstring and `_resolve_basic_cast`'s "NOT FORKED" note, correcting the pin citation) and the
  deferred-owner rows. Resolve Open Question 1 (cast half). (AC 10-13, 24, 30, 35)
- [x] **Task 5: Hero-sourced projectile.** Per-shot damage, hero source, profile authored on the effect;
  funnel and lifesteal treat it as the hero's damage; target-only contact; homing ends on target death;
  launched only by the cast strike; totem shots untouched; runner profile/launch/gather seats; grey
  actor. Resolve Open Questions 2-4, 6. (AC 13-23, 36)
- [x] **Task 6: Targeting.** Capture lock target (opposing hero when unlocked) at cast start; Honed Bolt
  resolves against it (hero arm bit-identical, unit arm damage only, dead target nothing); pre-spend
  requirement. (AC 24-27)
- [x] **Task 7: Presentation minimum.** Warning marker/alarm on the captured target (placeholder cone on a
  unit), the cast prop flying to the captured target, Fireball cast pose and projectile placeholders;
  poll-shaped, no new seam. (AC 28)
- [x] **Task 8: M5 and M6.** Direction-aware homing assertion with a sign-inversion mutation proof;
  reload-time `unit_kinds` reorder refusal with a named reason. Resolve Open Question 7. (AC 37, 38)
- [x] **Task 9: Tests.** `test_fireball.gd` (AC 5-23, incl. the launch-tick dead target AC 22 and the ADDED
  totem-shot guards AC 36), `test_spell_targeting.gd` (AC 24-27), `test_fireball_live.gd` (AC 17/18/20/21/22/28),
  the ADDED M6 reload-refusal test (AC 38, asserting the reason string), the authoring audit, replay identity
  (AC 32); update the table below; mutation proofs restore from a copy outside the repo.
- [x] **Task 10: Golden.** Isolate causes 1-3 by erasing the new keys with every other change in place;
  confirm the non-causes; ONE re-baseline; `FORMAT_VERSION` 16; record before/after.
- [x] **Task 11: Close.** Second full suite run, invariants green, `git diff --stat`, Dev Agent Record. The
  `deck-1-spec.md` amendment was written at authoring; discharge the `deferred-work.md` rows M5 and M6 (both
  still read "OWNER NAMED: `6-5-spell-resolution`") as closed by AC 37/38; the decision-log close-out and
  the board promotion to done are the operator's gate.

## Tests expected to break (moves deliberately, not regressions)

| Test | Why it moves |
|---|---|
| `test_card_authoring.gd` (`&"bloodhound_step": [&"bloodhound_step", &"bloodlust"]`; `DECK_1_PRICES`; the Deck-1 bucket census) | Deck 1 pairing is now `[..., &"fireball"]`; a new Fireball row; Bloodlust leaves the Deck 1 rows (its effect-file pin stays); `DECK_1_PRICES` `bloodhound_step` 4.0 -> 3.0; census `buffs` 4 -> 3 and `cast` 1 -> 2 (`deferred` stays 4) |
| `test_spell_framework.gd` (deferred-owner dict; `[&"bloodlust", &"vampiric_aura", &"bloodhound_step", &"frostbite"]` list; the `ID_HOUND` fixture) | owners renamed to the 6-5e key; `fireball` is not deferred |
| `test_hero_cast.gd` | bolt "never hits a minion / ignores lock-on" tests are replaced by the targeted rules; the hero-target tests stay; `test_no_authored_pitch_effect_is_a_cast_id` is deliberately reversed for `fireball` |
| ADDED: `test_fireball.gd` totem-shot guards (AC 36); reload-refusal test (AC 38, file named by the dev pass) | new tests, not moved ones |
| `test_determinism.gd` | golden re-baseline (once) |
| `test_draw_delay_and_reshuffle.gd`, `test_card_observation.gd`, `test_debug_window_countdown.gd` | key-set / window-list pins, if a per-player key or a window is added |
| `test_pitch_staging.gd`, `test_pitch_changed.gd`, `test_deck_and_hand.gd` | pitch snapshot shape; the "pitch effect map read exactly once at activation" pin (a second read at staging is Open Question 1) |
| `test_record_file.gd`, `test_replay_identity.gd` | `FORMAT_VERSION` 16; the new content round-trip |
| `test_intent_recorder.gd` | only if an intake method is added (predicted: none) |
| `test/integration/test_card_database.gd`, `test_deck_injection.gd` | `bloodhound_step`'s pitch is Fireball |
| `test/integration/test_cast_presentation_live.gd`, `test_cast_interrupt_live.gd` | warning marker is target-addressed |
| `test_projectile_flight_live.gd` | M5 assertion added |

## Open Questions (MECHANISM ONLY -- the dev pass decides; gameplay questions are the operator's)

1. **How does staging know a card is variable-cost, and how does the cast know which effect it strikes?**
   Staging reads only `_pitch_costs`: a field on the pitch effect (a second `_pitch_effects` read, against the
   "read once" activation pin) or on `CardCastCondition`. `cast_card_id` cannot tell pitch from basic; it
   needs the effect id or a mode. Prefer the option that leaves the shared cost schema unshaped; record it.
2. **How does a hero-sourced projectile carry its damage and profile?** The 4-4 record holds a kind index
   only: a synthetic `unit_kinds` entry (reload-fragile, M6) or per-shot damage on the board with the profile
   read off the effect. The funnel must treat the shot as the HERO's damage for Bloodlust/Aura
   (`_is_bloodlust_body`, `_apply_lifesteal`'s hero-index gate) without changing a totem shot.
3. **How is target-only contact expressed** (gather filter vs a state drop) so it applies to a hero-sourced
   shot and leaves the totem shot's first-body-touched behaviour untouched, and still replays?
4. **Where does the effect's projectile profile live?** `CardEffect` forbids nested resources (flat fields
   round-trip through `RecordFile._card_effects`), so flat mirror fields of `ProjectileProfile` are the
   likely answer; keep ONE reader for `_projectile_profile_at` and the runner twin `_projectile_profile`.
5. **Damage lock boundary.** Freeze the PRODUCT (`damage_per_mana` x X) into the staged record unless a
   reason is found (the scope says "locked at staging"), and pin the choice.
6. **Dead-target homing end** must be state-decided (a replay cannot depend on the runner).
7. **M6 mechanism:** where the reload-time validation runs and what "reorder" is compared against.

## Dev Notes

- **Why AC 36 has its own tests:** AC 14 deliberately breaks two shipped exclusions (`_is_bloodlust_body`
  returns false for a projectile index; `_apply_lifesteal` gates on `HERO_INDEX`). Measured at the gate: no
  existing test exercises a projectile under Bloodlust or Vampiric Aura, so "existing tests pass unchanged"
  proves nothing about a totem shot. A dev pass that just deletes the early-return would keep every old
  test green and silently double a totem's shot. The block multiplier is in AC 36's list because AC 16
  removes exactly that rung for Fireball.
- **Bloodlust fixture card (only if a test truly needs one):** the shipped precedent is a dormant fixture card
  in `data/cards/`, added to `FIXTURE_IDS` and absent from the deck list. Today every Bloodlust behaviour test
  builds its effects in-test (`test_spell_framework.gd` `_authored()`/`_pitch_effects()`, `ID_HOUND`), so none
  is expected to need one. No resource is ever added under `test/`.
- **Pitch price:** `bloodhound_step.tres` `pitch_condition.mana_cost` is 4.0 today and `DECK_1_PRICES` in
  `test_card_authoring.gd` pins `[RED, 2.0, 4.0, {RED: 1}]`; AC 3 moves it to 3.0 (`6-5d/R9`).
- **Pitch-cast disjointness:** the pin is `test_hero_cast.gd::test_no_authored_pitch_effect_is_a_cast_id`;
  the `_resolve_basic_cast` comment's citation of `test_spell_framework.gd` is wrong and is corrected when
  the comment is rewritten (Task 4).
- **Cast prop:** `_push_cast_presentation` addresses the bolt actor at the opposing hero by slot arithmetic,
  the same arithmetic AC 24 replaces for the damage; it must read the captured target instead (AC 28).
- **M6 refusal:** compare the incoming `unit_kinds` against the running config by kind identity in order;
  "live" means any unit or projectile record exists. Name the reordered kind in the reason string.

- **Max mana is 10 today** (`data/balance/balance_config.tres` `max_mana = 10.0`), so the Fireball cap of 10 is
  currently INERT: the whole pool is always spent. The field exists so a future pool raise does not silently
  raise Fireball's ceiling; it is authored data, never a literal.
- **Refusal path cited:** below the minimum, `_resolve_pitch_stage` refuses through
  `CastEvaluator.flag_and_mana_refusal_reason(...)` (`pitch_condition.mana_cost = 3.0` is the minimum) ->
  `reject_action(&"card_cast", REASON_INSUFFICIENT_MANA)` and `return` BEFORE `player.mana.spend`.
- **Order at activation** stays: gates -> board gate -> orb spend -> discard -> `pitch.clear` -> apply
  (now a cast start) -> resolved-card record -> replacement owed at activation, not at the strike (the
  6-5c "record and signal at the press" precedent).
- **Rise i-frames** are covered by the contact rung; do NOT swap `is_iframe_open()` for the step-3 latch.
  A cast starts from Mode 4 only when `starts_cast` says so (no card is named in `match_state.gd`).
- **Read first** (UPDATE files): `match_state.gd` (`_resolve_pitch_stage`, `_resolve_pitch_activate`,
  `_resolve_basic_cast`, `_resolve_cast_strikes`, `_apply_honed_bolt`, `_resolve_contacts`,
  `_funnel_damage`, `_apply_lifesteal`, `_advance_projectiles`, the snapshot), `pitch_state.gd`,
  `player_state.gd`, `projectile_board.gd`, `card_effect.gd`, `card_effect_resolver.gd`, `src/systems/record_file.gd`,
  `match_runner.gd` (`_spawn_missing_projectile_actors`, `_gather_projectile_facts`, `_projectile_profile`,
  `_push_cast_presentation`), `telegraph_controller.gd`.
- **Suite:** `bash test/run_all.sh` with `GODOT=/c/Godot/godot.exe` via the Bash tool (WSL is broken).
### Project Structure Notes

- Effect data under `data/effects/`; tests under `test/state/` and `test/integration/`. No card is added
  for Bloodlust (AC 2). A new public API or `src/` folder is a design decision: stop and ask.

### Project Context Rules (extracted from `docs/project-context.md`)

- State / visual separation; integer-tick timing (A1: durations converted once at application); every
  number a `.tres` field; feature flags injected into `src/state/`, never read from the service.
- Golden isolation (`BC/R3`): `data/balance/*.tres` is isolated; a NEW seat or a pressed action made
  refusable is not covered.
- Mutation proofs restore from a copy taken outside the repo (SHA256 first), never `git checkout --`;
  full suite at open and close, mutation proofs run only the affected file.
- Edit tool only (line-index splice as fallback, never PowerShell `-join`). Docs and code never share a
  commit; ASCII messages via `git commit -F`; never push before the operator confirms the log.

### References

- `docs/planning-artifacts/deck-1-spec.md` (Fireball amendment 2026-09-22; Honed Bolt amendment
  2026-09-25; the amendment of 2026-09-26 added by this pass).
- `docs/implementation-artifacts/6-5c-hero-cast-honed-bolt.md` (cast framework, strike seat, latch),
  `6-5b-corpses-and-own-minions.md` (death seat, Deferred section), `6-5a-spell-framework-and-buffs.md`
  (funnel, injection channels).
- `docs/implementation-artifacts/deferred-work.md` rows M5/M6; `C:\dev\_44-review.md` sections M5, M6.
- `docs/game-architecture.md` (D3, A1, A2, F1, D5); `docs/project-context.md`.
- GDD decision-log `R-D6`, `6-1c/R4`, `SC/R6`, `BC/R3`, `E4-P/R12` (projectile identity).

## Dev Agent Record

### Agent Model Used

Claude Opus 5 (two main sessions, no subagents, no forks, no parallel sessions).

### Debug Log References

Full record: `C:\dev\_65d-dev.md`. Suite outputs outside the repo:
`C:\dev\_65d-suite-before-state.txt`, `C:\dev\_65d-suite-before-int.txt`,
`C:\dev\_65d-suite-after-state.txt`, `C:\dev\_65d-suite-after-int.txt` (the session-1 close, reused as
session 2's before-baseline), `C:\dev\_65d-suite-final-state.txt`, `C:\dev\_65d-suite-final-int.txt`.

### Completion Notes List

**Preconditions** (all pass): HEAD == origin/main == 9ed39e8, tree clean, no godot processes, Status
`ready-for-dev`. Frontmatter `baseline_commit` preserved at 3c2d277 (pre-existing, not overwritten).

**Before-baseline (MEASURED, before any edit):** state **1070 / 0 failed / 10556 assertions**,
integration **70/70** — exactly the figures the prompt expected, no difference. Golden
`97d52922…`, `FORMAT_VERSION` 15.

**Open Question decisions (mechanism — the dev pass's own):**

1. *Variable-cost signal + cast effect identity.* Staging reads the pitch effect **once**, at a new
   seat in `_resolve_pitch_stage` (the `test_deck_and_hand.gd` "read once" pin is scoped to
   ACTIVATION; that pin was moved deliberately to require exactly one read at each of the two
   seats and to keep asserting that staging APPLIES nothing). The discriminator is the authored
   number, not an id row and not a new bool: `CardEffectResolver.spends_variable_mana(effect)` is
   `effect.mana_cap > 0.0`. Chosen over a field on `CardCastCondition` because that shapes the
   shared cost schema for one card. Cast identity: `cast_effect_mode` (an `Enums.ModeKind`
   ordinal) picks `_pitch_effects` vs `_card_effects` at the strike seat — AC 12 is that member.
2. *How a hero-sourced shot carries damage and profile.* `ProjectileBoard` gains `_effect_ids`
   (`String`) and `_damage` (`float`), plus `add_hero_shot()`. The EFFECT ID is the profile handle:
   a pitch effect is injected once with no reload path, so reading the numbers through it live is
   `E4-P/R12`'s own "store config identity, copy no authored number" argument applied to a second
   kind of config. `_damage` genuinely must be stored — it is `damage_per_mana × mana spent`, not
   derivable from config. `is_hero_sourced_at(i) := _effect_ids[i] != ""` is the single
   discriminator; `_kind_index` is `NO_KIND_INDEX` and `_source_index` is `HERO_INDEX`, both
   written in the one seat so the three cannot disagree. A synthetic `unit_kinds` entry was
   rejected as reload-fragile — M6 exists because `unit_kinds` reordering already re-points records.
3. *Target-only contact.* A **state rung** in `_resolve_contacts`, not a gather filter: the runner
   keeps pushing a fact for every overlap (untouched, replay-identical, no new intake). The rung
   sits immediately after the reach-probe drop and BEFORE the unit branch and the i-frame rung,
   because AC 20 asks for all three of "no damage, not consumed, no i-frame effect". Gated on
   `is_hero_sourced_at`, so a totem shot never reaches it (AC 36).
4. *Where the effect's projectile profile lives.* Flat mirror fields on `CardEffect` with
   `ProjectileProfile`'s own names, mirrored into one real `ProjectileProfile` per effect ONCE at
   `inject_pitch_effects` — so `_projectile_profile_at` stays a SINGLE reader for both shot kinds
   with no per-tick allocation, and `4-4/R3`'s one-homing-one-acceleration rule survives a second
   source of authoring. The acceleration delay converts seconds→ticks at the same seat (A1: read
   every tick, so the point of use is injection). The runner twin `_projectile_profile` is
   **deleted** in favour of the now-public `projectile_profile_at`; it could not have learned the
   effect path without being taught the same lookup twice.
5. *Damage lock boundary.* Freeze the PRODUCT. `PitchState` stores **both** `_mana_spent` (AC 5's
   "remembers the spent amount", recorded for every staging, fixed or variable, so the seat has no
   is-this-variable branch) and `_locked_damage` (the frozen product). They are independent facts
   after a `damage_per_mana` retune, which is exactly why the question existed: a retune between
   staging and activation is deliberately **not** seen.
6. *Dead-target homing end.* State-decided in `_advance_projectiles`, inside the ordered dispatch —
   the runner must not decide it, because `_drive_projectiles` merely stops steering when it finds
   no actor and would leave `_homing` true in the hash.
7. *M6 mechanism.* `apply_balance()` compares incoming `unit_kinds` against the running config by
   kind name in order; same length + any position difference + any live unit or projectile record
   on either board ⇒ REFUSED, running config kept, no record re-pointed. "Live" means `size() > 0`,
   not `living_indices()`, because a CORPSE's kind index still decides what it renders as.

**Two decisions a guard changed, recorded rather than smoothed over:**

* `cast_mode` → **`cast_effect_mode`**. The first spelling tripped
  `test_architecture_invariants.gd::test_card_scheme_only_in_controllers`: `cast_mode` is a reserved
  controller-scheme token (3-5a AC 1). The guard was right — this is a which-effect discriminator,
  a different fact from the press that produced it.
* M6's reason is a **return value, not a member**. A `last_balance_refusal` member would have been a
  FIFTH unhashed cross-tick exclusion in `test_replay_identity.gd`, a pin that exists to make one
  expensive. `apply_balance` now returns the reason (`""` on success); existing callers are
  unaffected, and a string that lives only for the call is not state a replay must reproduce.

**Editor class-cache scan (3-0c/R13)** — run for the new `class_name TargetConeActor`. Zero
collateral: `project.godot` SHA256 `9C3089BC…1695E2` and `src/main/main.tscn`
`D102CA2A…D30828` **identical before and after**, and `git status --short` showed only the intended
edits plus the new script and its generated `.uid`.

**Golden: ONE re-baseline, `97d52922…` → `de3589ff…`, three causes, each measured in isolation.**
With all new keys erased from `to_snapshot()` and every other 6-5d change in place the hash is
`97d52922…` **exactly** — so every cause is snapshot shape and none is behavioural. Then each group
alone, from that erased base:

| Cause | What | Hash from `97d52922…` |
|---|---|---|
| 1 | pitch zone's `mana_spent` + `locked_damage` (live 3.0 at hash time via the fixture's t22 staging) | `ea53044adf20d7e9185b62056fddd8044da54e7050cb5fe2bb613de58990c4e7` |
| 2 | the `cast` key EXTENDED 2 → 6 elements | `057f9da61517536372c8636baacaa39b3b195c401f2869d9440f91bb234851ca` |
| 3 | `projectile_effect` + `projectile_damage` | `892fe0257fb79a8f0d05833216632174827d8d2fb702d60c16cabd2b7d662f95` |

All three together = `de3589ff…`. Predicted causes 5 (new refusable outcomes — no new token ships
at all), 6 (authored `fireball.tres`, the pairing swap and the eight new `CardEffect` defaults —
`BC/R3` holds a third time), 7 (the bolt target capture — the resting lock IS the opposing hero, so
`[1,-1]` is arithmetically the `1 - slot` it replaces), 8 (`FORMAT_VERSION`) and 9 (intake) are all
**MEASURED non-movers**. The probe files were backed up outside the repo with SHA256 and restored
**by copy**, verified byte-identical afterwards with zero residual markers.

**Per-player snapshot key set: 38 → 40** (`projectile_effect`, `projectile_damage`). The `cast`
extension deliberately adds no key, which is what kept cause 2 and the key-set move separately
measurable. Pins moved: `test_draw_delay_and_reshuffle.gd`, `test_card_observation.gd` (list and
count).

**`FORMAT_VERSION` 15 → 16, hard refusal of v15, no shim.** ONE measured cause: the recorded
per-effect ROW shape moves — `CardEffect` gains eight flat exports and `_resource_values` captures
every script variable, so every row in the `effects`/`pitch_effects` channels gains eight keys
(`REQUIRED_KEYS`, the channel set, is unmoved). **AC 31's stated reason is corrected in the code
rather than repeated:** a v15 file cannot contain a Fireball, and the pairing swap creates no
misresolution either (a record carries its own injected content, so a v15 file replays Bloodhound
Step's pitch as the `bloodlust` buff it was recorded with, and the new staging path reads
`mana_cap` 0.0 off that rebuilt buff and takes the unchanged fixed-price branch). Cause (1) is
sufficient alone and is the same cause that carried 14 → 15.

**Deliberate test moves (all predicted by the story's own table):** `test_card_authoring.gd`
(pairing → `fireball`, `DECK_1_PRICES` 4.0 → 3.0, bucket census buffs 4→3 / cast 1→2,
`data/effects/` 14→15 because Bloodlust STAYS per AC 2), `test_spell_framework.gd` (three owner rows
→ the 6-5e key, plus a new negative assertion that `fireball` is not deferred),
`test_hero_cast.gd` (the disjointness pin **reversed** into
`test_the_authored_castable_pitch_effects_are_exactly_the_forked_set`, which also asserts the
activation seat really forks; the lock-agnostic bolt test replaced by the targeted rules),
`test_deck_and_hand.gd` (staging now reads the pitch map exactly once and still applies nothing),
`test_pitch_staging.gd` (two empty-zone records), `test_intent_recorder.gd`
(`projectile_profile_at` exempt as the third projectile pure query), `test_replay_identity.gd`
(eight new members classified: six HASHED, two INJECTED — `UNHASHED_CROSS_TICK_MEMBERS` STAYS AT
FOUR), `test_cast_presentation_live.gd` / `test_cast_interrupt_live.gd` (`start_cast` signature).

**Mutation proofs (MEASURED; every mutation restored from an out-of-repo copy, never `git checkout`):**

| # | Guard | Mutation | Killed by | Verdict |
|---|---|---|---|---|
| 1 | M5 direction-aware homing (AC 37) | sign-invert `ProjectileActor.steer_toward` | `test_projectile_flight_live.gd` (`aim_last=3.1225` rad, late mean 3.1238 vs early 1.3133) | **KILLED** |
| 2 | `_is_bloodlust_body` widening (AC 14/36) | `return true` for every projectile index | `test_fireball.gd::test_a_totem_shot_is_unbuffed_by_its_owners_bloodlust_and_heals_nobody` | **KILLED** |
| 3 | target-only contact rung (AC 20/36) | drop the `is_hero_sourced_at` gate | `test_fireball.gd::test_a_totem_shot_still_lands_on_the_first_body_it_touches` | **KILLED** |
| 4 | block exemption (AC 16) | always apply the block multiplier | `test_fireball.gd::test_block_does_not_reduce_a_fireball_facing_or_not` | **KILLED** |
| 5 | M6 reorder refusal (AC 38) | never refuse | `test_fireball.gd`, all three reorder tests | **KILLED** |
| 6 | the warning's DESTINATION (AC 28) | `match_runner.gd`: `if true:` on the hero-target branch — arm the hero's marker and alarm whatever the captured target is, and never spawn the cone | `test_fireball_live.gd` — cone up on **0** of 47 cast-2 ticks, the hero behind the minion marked on **47** and alarmed on **47** | **KILLED** |
| 7 | the cast prop's destination (AC 28) | `match_runner.gd`: `_cast_target_position` returns `_target_world_position(1 - slot, HERO_INDEX)` — the slot arithmetic `6-5d` replaced | `test_fireball_live.gd` — cone off the marked body on **47** ticks, prop's closest approach to the captured minion **2.108 m** (tolerance 1.0; the opposing hero sat 17.94 m away) | **KILLED** |
| 8 | the CAPTURED copy, not the live lock (AC 24/`6-5d/R15`) | `match_state.gd`: `_resolve_cast_strikes` reads `_captured_target_address(player)` at the STRIKE instead of the four carried facts | `test_replay_identity.gd`'s new spell run — the bolt left the minion at **9.0** HP instead of 5.0 (it hit the hero the lock had moved to); independently also `test_fireball.gd::…dead_on_the_launch_tick` and two `test_spell_targeting.gd` tests | **KILLED** |

Mutation 1 is the load-bearing one of the first five: it proves the PRE-6-5d assertion was **vacuous**
against exactly the adversary M5 named — under the inverted steer the old bearing-spread check still
read `steered=true` (spread 1.6755 rad, *larger* than the honest 1.5581) while the new aim-error check
failed decisively. Restores verified byte-identical by SHA256 (`projectile_actor.gd` `A1FFAB36…`,
`match_state.gd` `5412827C…`, and the two golden-probe files `7B7F7AC4…` / `7D7FCF14…`), zero
residual markers.

Mutations **6-8** are the two Task 9 tests' own proofs, and **mutation 8 is the one worth reading
twice:** a replay-identity assertion ALONE can never kill it — the live run and its replay would read
the mutated live lock identically and still agree — which is why the new driven fixture moves the lock
MID-CAST and asserts the captured/live disagreement directly (`hp_after_bolt`,
`lock_at_bolt_strike`). A fixture that left the lock still would have been the passive tautology this
file's header warns about. Session-2 restores verified byte-identical by SHA256:
`src/main/match_runner.gd` `2B91E8CE…84E7E2`, `src/state/match_state.gd` `5412827C…584F3A` (the same
value session 1 recorded, so `match_state.gd` ends this pass exactly where session 1 left it), zero
residual markers.

**Suite (MEASURED):**

| Run | State harness | Integration | Timestamp |
|---|---|---|---|
| Before (pre-edit) | 1070 / 0 / 10556, PASS | 70/70 | 2026-09-26 **23:55:45** |
| Session-1 close | 1123 / 0 / 10958, PASS | 70/70 | 2026-09-27 **01:59:02** |
| **Final (Task 9 complete)** | **1125 / 0 / 10975, PASS** | **71/71** | 2026-09-27 **11:23:35** / **11:28:33** |

The session-1 close run is REUSED as session 2's before-baseline, and the reuse was checked rather
than assumed: the newest `LastWriteTime` under `src/`, `test/` and `data/` was
`test/state/test_card_authoring.gd` at **2026-09-27 01:52:15**, i.e. before both close-run
timestamps, so nothing changed after the measurement. Files: `C:\dev\_65d-suite-final-state.txt`,
`C:\dev\_65d-suite-final-int.txt`.

Budget interval (first before-baseline → last suite run): **2026-09-26 23:55:45 → 2026-09-27
11:28:33**, elapsed **11 h 32 m 48 s** across two sessions (the gap between them is not work time).
Tier A story; the operator sets the budget, so this is reported, not judged.

Golden **HOLDS** at `de3589ff…` — `test_determinism.gd`'s `GOLDEN` constant is unmoved and its 21
tests are green in the final run, so the one re-baseline is still the only one. No `ERROR:` /
`SCRIPT ERROR:` / `Parse Error` / `INVARIANT VIOLATED` line and no non-zero exit in either output;
the architecture invariants (F1, D3(a), D3(b)/A2) run inside the state suite and are green.
Integration is **71** files now (70 + `test_fireball_live.gd`), all `RESULT: PASS`, all `exit=0`.

**Suite-run disclosure (`E5-R/R5`):** 21 state-harness invocations across the two sessions, not 2.
Session 1: **17** (2 mandated, 4 for the golden cause-isolation the story requires, 5 for mutation
proofs 1-5, 6 for dev iteration — one of which hit the 600 s tool timeout on a warning-as-error
parse failure and left a stray godot process, killed before continuing). Session 2: **4** — one
mandated final run, **1 for mutation 8** (which lives in `match_state.gd`, so the whole harness is
the only way to run the affected pins), and **2** of dev iteration on the new replay fixture (the
first found the SPELLS flag closed in the reused `_flags()`, the second was a diagnostic pass that
printed the fixture's per-tick state and was removed afterwards). The new live test was iterated with
**4** single-file integration runs, which cost seconds rather than minutes.

**DISCREPANCY FOUND IN AC 36 — reported, not silently resolved.** Its two halves contradict each
other. The opening sentence demands the totem shot be bit-identical ("no Bloodlust, no Vampiric
Aura", "every `test_projectile_flight*.gd` assertion passes unchanged"); the NEW-TEST clause
(`6-5d/R17`) then describes a shot dealing "its authored `attack_at(0).damage` unmultiplied" *with
the target under Bloodlust (taken)*. Both cannot hold, and the cause is a factual error about
shipped behaviour rather than a design choice: `_funnel_damage`'s target branch asks
`_is_bloodlust_body(target, target_index)`, which returns `true` on its first line for any hero
target — so a Bloodlusted hero has **always** taken double from a totem's shot, and this story
provably does not touch that branch. The clause could only be written because, as `6-5d/R17` itself
says, no shipped test ever exercised a projectile under a buff. **Implemented the `bit-identical`
reading** (the conservative one, changing no gameplay): the attacker-side DEALT multiplier does not
reach a totem shot and Aura heals nobody off it — the two exclusions 6-5d had to widen for a
hero-sourced shot without breaking for a totem — while the target-side TAKEN multiplier applies as
it always has. Both facts are pinned in `test_fireball.gd`. **This is gameplay-adjacent and is the
operator's call:** if the intent really is that a Bloodlusted hero takes single damage from a totem
shot, that is a new behaviour change needing its own ruling.

**OPERATOR RULING ON THE AC 36 DISCREPANCY (2026-09-27), recorded and not re-litigated.** The
bit-identical reading implemented above is **CORRECT**. `6-5d/R17`'s "unmultiplied *with the target
under Bloodlust (taken)*" was an error in the ruling: Bloodlust by design doubles damage TAKEN from
every source, and that has always applied to totem shots. A totem shot gets neither its owner's
Bloodlust DEALT multiplier nor Vampiric Aura; a Bloodlusted TARGET still takes double. The AC 36 text
is left alone here — the close-out corrects the log and the AC.

### Task 9 completed (session 2, 2026-09-27)

**`test/integration/test_fireball_live.gd` (NEW) — AC 28, AC 20, AC 36, AC 37 through the REAL
runner.** Both AC 28 arms in ONE run and on the SAME hero, which is what makes each the other's
non-vacuity: cast 1 (a PITCH Fireball) is aimed at P2's HERO and P2 shows today's marker and alarm with
no cone anywhere; cast 2 (a BASIC bolt) is aimed at a P2 MINION and that same hero shows NOTHING while
the placeholder cone hovers over the minion (47 of 47 ticks, never off-body) and the prop's closest
approach to the captured minion is **0.000 m** with the hero 17.94 m away. Then the flight: the shot
appears 1.035 m from the caster, really overlaps the NON-TARGET minion for **9 ticks** (the overlap is
read from the shot's own `Hitbox.get_overlapping_areas()`, the same query
`_gather_projectile_facts` makes, so it is a fact the runner pushed), leaves it at 9.00 HP, flies on
for 77 more alive ticks and lands on the captured hero for exactly the carried 12.00. AC 37's
direction-aware clauses are carried for the hero's shot (`late 0.0000 < early 0.0039`, `last <= first +
0.01`). Finally AC 36 in the same scene: a Combat totem's shot addressed at the **HERO** is consumed by
the first body it touches, that body loses HP (5.00 → 2.00) and the hero it was aimed at loses none.
Every phase advances on an OBSERVED EDGE rather than a frame count, and the determinism pad is the
usual one — no joypad, so the shipped controllers emit a neutral intent and the only inputs are the two
pokes.

**A REAL DEFECT THE LIVE TEST FOUND, and the one thing in this pass that changed `src/` after session
1: `_projectile_launch_position` launched a hero-sourced shot a METRE TOO HIGH.** A unit's root is its
FEET (`unit_actor.tscn`), a hero's root is its body CENTRE (`hero.tscn`, 1x2x1 box spanning root y
[-1,+1]), and `projectile_actor.tscn` offsets its hitbox +0.7 "to fly at roughly chest height on both a
hero and a totem" — i.e. against the FEET convention. MEASURED: launched from a hero's root the hitbox
sphere spanned y 1.35..2.05 while a minion's hurtbox spans 0..1.2, so a Fireball flew **0.15 m over a
minion's head** and `overlap=0` — it could not touch a unit at all, and AC 19's "the shot always lands
on a minion or totem" was live-unreachable. Nothing headless could see it (both a landing and a
pass-through are synthetic facts at the seam) and no existing live test could (the only shipped shot is
unit-sourced): exactly the runtime-composition blind spot `3-0b/R34` names. FIXED by lowering the hero
branch to the caster's feet, **read from the authored body box** rather than a literal 1.0, which also
gives the better answer for the pre-existing "source unit already freed" fallback — that shot was a
unit's, at unit height. The state layer owns no position, so this cannot move the golden, and it did
not.

**`test/state/test_replay_identity.gd` — AC 32, a SIBLING driven run (`_record_a_spell_run`).** A
second fixture rather than an extension of the 3-0c one, for the reason that file's header gives its
own fixture: every channel-drop proof above is calibrated to what that run does. The spell run drives
everything through RECORDED CHANNELS and pokes nothing into state — which is the whole difficulty, and
why the `test_fireball.gd` conveniences (`mana.add`, `orbs.add`, `units.add`, a written
`lock_target_slot`) are all unavailable: a replay performs none of them. So mana comes from a melee hit
on each side (attack press + pushed contact), the minion from a real `summon_` cast by P2, the lock from
`retarget_slot`/`retarget_index` on the intent, the landing from a contact fact pushed at the
projectile's own attacker address — and the ORB gate is authored away (no orb price) rather than
choreographed, because orbs are banked only by an unblockable landing and the gate itself is AC 10's,
pinned in `test_fireball.gd`. MEASURED end to end: t16 bolt cast on the locked minion, t18 the live
lock moves to the hero, t22 the bolt lands on the CAPTURED minion (9.0 → 5.0), t26 staging spends the
CAP (mana 10 → 2) and freezes 8 × 1.5 = 12.0, t28 orb-less activation, t34 the strike places the shot
addressed at `[1, 0]`, t38 it lands and kills the minion. Replay from the record alone is
**bit-identical**, and with the contacts channel dropped it diverges.

**Card slots are chosen by reading the LIVE hand, and that is replay-sound:** the chosen slot travels
in the recorded intent, so the replay presses the slot that was pressed and never re-chooses. It is
also what keeps the fixture independent of the deal instead of hard-coding a shuffle's output.

**Two fixture facts worth recording because they cost a run each.** (1) `_flags()` in that file leaves
`spells` CLOSED — correctly, the 3-0c run has no spell content — so the first spell run silently
resolved nothing at all; the spell run has its own `_spell_flags()`. (2) Its draw pile is empty by the
second press, so a resolved card is RESHUFFLED out of the discard and `discard.size()` is 0 for a run
that did everything: the "both presses spent" assertion reads the MANA POOL instead, which cannot be
reshuffled and which also pins the `min(X, cap)` branch.

### Review fix pass (2026-09-27, Claude Sonnet 5, no subagents/forks)

Contract: `C:\dev\_65d-review.md` (VERDICT: APPROVE WITH FINDINGS, 0 blocking / 1 major / 7 minor).
Preconditions matched (HEAD == origin/main == 9ed39e8, tree unchanged by the review, no godot
processes, Status `review`). Before-baseline accepted from the review's SHA256-verified restores
rather than re-measured.

1. **MAJOR-1.** `trigger_live_balance_reload` now binds `apply_balance`'s return value and surfaces a
   refusal with `push_warning`, matching the neighbouring replay refusal. Guarded by a new source-scan
   test, `test_fireball.gd::test_trigger_live_balance_reload_reads_apply_balances_return_value`.
2. **MINOR-2.** `_kind_reorder_refusal`'s projectile half now reads `living_indices().is_empty()`
   instead of `size() == 0` -- the corpse argument for "any record, not just a living one" holds for
   `UnitBoard` only. New test:
   `test_a_consumed_projectile_does_not_refuse_a_reorder_but_a_live_one_still_does`.
3. **MINOR-3.** The stale `PlayerState.cast_mode` citation in `CardEffectResolver`'s
   `OUTCOME_FIREBALL` docstring corrected to `PlayerState.cast_effect_mode`.
4. **MINOR-5.** AC 19's TOTEM arm, unproven until now: added
   `test_a_fireball_on_a_totem_lands_for_its_locked_damage_and_leaves_no_corpse` beside the minion
   test.
5. **Record accuracy (MINOR-6/MINOR-7), below.** MINOR-4 and MINOR-8 and the AC 31/36 text
   corrections are left for the close-out pass, per the review contract's own scoping.

**MINOR-6 -- the four predicted-but-unmoved test pins, as a measured non-move.** The story's own
"Tests expected to break" table predicted `test/integration/test_card_database.gd`,
`test_deck_injection.gd`, `test_pitch_changed.gd` and `test_debug_window_countdown.gd` might move.
**None of the four moved.** Verified rather than assumed: `grep bloodlust` returns 0 hits in all four
(the pairing swap and price move are read through `bloodhound_step.tres`'s own fields, which those
tests don't pin directly), no debug-window key changed shape, and the pitch-changed payload does not
carry the pitch zone's new `mana_spent`/`locked_damage` facts.

**MINOR-7 -- Task 9's stated live-test coverage vs the delivered file.** Task 9's text says
"`test_fireball_live.gd` (AC 17/18/20/21/22/28)". The delivered file's header and assertions actually
cover **AC 20, 28, 36, 37**; ACs 17, 18, 21 and 22 are each covered **headlessly** in `test_fireball.gd`
(confirmed in the review's T12 AC-coverage map). Task text is left as authored (Open Questions and Task
text are not amended after the fact); recorded here so a future reader does not go looking for AC 22 in
the live file.

**Mutation proof (MINOR-2, folded together with MAJOR-1's guard to cost one extra run instead of two).**
Backed up `match_runner.gd` and `match_state.gd` (the fixed versions) to `C:\dev\_65d-fix-backup\` with
SHA256 first. Reverted both to their pre-fix shape and ran the full state harness ONCE: **exactly 2 of
1128 tests failed** -- the two new guard tests above, nothing else. Restored both files **by copy**,
SHA256-verified byte-identical, zero residual markers (`mutation_major1`, `mutation_minor2`).
`git checkout --` never used.

**Final suite (ONE run, two foreground calls):**

| Run | State harness | Integration | Timestamp |
|---|---|---|---|
| **Final** | **1128 / 0 / 10987, PASS** | **71/71**, all `exit=0` | 2026-09-27 **15:41:37** / **15:46:36** |

+3 tests / +12 assertions over the review's baseline (1125/10975) -- exactly the three tests added
above. Golden **HOLDS** at `de3589ff...`. `git status --short` unchanged: 26 modified + 6 untracked,
the same set as at the review's open. Files: `C:\dev\_65d-suite-fix-state.txt`,
`C:\dev\_65d-suite-fix-int.txt`. Story Status stays `review`; board stays `ready-for-dev`; nothing
committed.

### Smoke fix pass (2026-09-28, Claude Sonnet 5, no subagents/forks)

**Operator smoke finding (two pads, 2026-09-28).** Activating a FIREBALL played the HONED BOLT
presentation first: the cast pose and the target warning were correct for both spells, but the bolt
prop (lightning sword-to-sky-to-target) was ALSO spawned and flown, and only then did the Fireball fly.
State was unaffected (the fake bolt did no damage and no root) -- a pure presentation defect.

**Cause, verified (not merely reproduced from the report).** `match_runner.gd::_push_cast_presentation`
spawned and advanced `BoltActor` for EVERY cast, reading only `is_casting()` and the cast window --
never which effect a cast resolves to. Confirmed by reading the function before touching it, not
assumed from the operator's description.

**Fix.** The classification is the resolver's (D6). Added a PURE QUERY,
`MatchState.cast_outcome(player) -> StringName` (returns `&""` when not casting, otherwise
`CardEffectResolver.outcome(_cast_effect_of(player), flags)` -- the same two reads
`_resolve_cast_strikes` already makes at the strike), and joined it to `EXEMPT_PURE_QUERIES` in
`test_intent_recorder.gd` on `projectile_profile_at`'s footing (touches no board, mutates nothing, no
capture channel needed). The runner caches `_cast_shows_bolt[slot]` on the same rising edge as the
captured target (`_cast_target_slots`), reading `cast_outcome(player) == CardEffectResolver.OUTCOME_HONED_BOLT`,
and gates every `_spawn_bolt`/`_advance_bolt` call (including the offset-0 launch case) on it. No card
id is named in the runner -- `CardEffectResolver.OUTCOME_HONED_BOLT` is an outcome constant, referenced
in the runner exactly as `CardEffectResolver.KIND_MINION` already was (`match_runner.gd:3087`).

**AC 15 check (verified independently, not just reported).** Read `_apply_fireball` (places the
projectile only) and the hero arm of `_resolve_contacts` (the ladder a hero-sourced projectile's
landing actually resolves through): neither calls `start_stun`, `_apply_bolt_landing` or writes
`stun_is_bolt`/`STUNNED`/the root window. Only `_apply_honed_bolt`'s own hero arm calls
`_apply_bolt_landing`. **HOLDS**, confirmed by code reading and now also live (below).

**Live check (operator addition): AC 15 through the REAL runner.** Extended
`test/integration/test_fireball_live.gd` with a new phase, `cast1_aftermath`, sampling
`POST_LAND_TICKS` (65, >= 1.0 s at 60 Hz) after the Fireball lands on the hero: the dizzy clip, the
stunned clip (`AnimationController.animation_player.assigned_animation`, the
`test_cast_presentation_live.gd::_sample()` read path, cited and reused verbatim for why
`assigned_animation` and not `current_animation`), the root ring (`TelegraphController`'s `RootMark`
mesh via `_root_marker_visible`, `test_cast_presentation_live.gd`'s own helper, cited and reused), and
the state side (`stun_is_bolt`, `action_state != STUNNED`, `root_window.is_running`) -- all asserted
false/absent for the whole window. **Non-vacuity**: a THIRD poked cast, cast 3 (a Honed Bolt aimed at
the HERO, not the minion cast 2 targets), proves the same six reads really can show a positive --
dizzy, the root marker and `stun_is_bolt` all true in the same run, ended on an OBSERVED EDGE (the
window the bolt opened running its course) rather than a frame count.

**Also added:** a bolt-prop-absence check across the whole of cast 1
(`_cast1_bolt_seen`), and a pre-cast baseline check that no bolt or root marker exists before any cast
-- the `test_cast_presentation_live.gd` baseline-check precedent applied to this file.

**Mutation proofs (two, both single-file live-test runs, both restored from an out-of-repo copy with
SHA256 first, `git checkout --` never used):**

| # | Guard | Mutation | Killed by | Verdict |
|---|---|---|---|---|
| 1 | the presentation gate | `match_runner.gd`: `if _cast_shows_bolt[slot]:` -> `if true:` (prop spawns for every cast again) | `test_fireball_live.gd` -- `cast1_bolt_seen=true`, "SMOKE FIX: a BoltActor existed during the Fireball cast" | **KILLED** |
| 2 | AC 15's no-stun guarantee | `match_state.gd`: after `target.hero.take_damage(damage)` in the hero contact ladder, `target.hero.stun_is_bolt = true` when the attacker is a hero-sourced projectile | `test_fireball_live.gd` -- "AC 15: a Fireball landing set stun_is_bolt" | **KILLED** |

Both mutations were applied and reverted ONE AT A TIME; each run showed exactly the one expected
failure and nothing else moved. Restores verified byte-identical by SHA256
(`match_runner.gd` `785cf647...726a6a`, `match_state.gd` `7ee7c377...afccb15`), zero residual markers
(`mutation_smokefix`, `mutation_ac15`).

**Preconditions matched.** HEAD == origin/main == 9ed39e8, tree = the dev pass + review-fix changes
(26 M + 6 ??), `src/main/main.tscn` untouched (`git diff --stat` empty -- its `LastWriteTime` had moved
from the operator's smoke session but its content had not), no godot processes, story Status `review`.
Before-baseline accepted from `_65d-suite-fix-state.txt` / `_65d-suite-fix-int.txt` (1128/0/10987 PASS,
71/71): nothing under `src/`, `test/`, `data/` had a newer `LastWriteTime` than that baseline's, except
`main.tscn` itself (touched, not modified).

**Operator smoke result, recorded.** 14 of 15 items PASS on two pads (R-D6 re-invoked and passed: the
round ended normally on a spell kill). Item 10 (target dies before impact) was not verifiable by hand
-- the caster is locked during the 0.8 s cast and cannot kill the target in time -- and is covered
headlessly (`test_spell_targeting.gd` dead-mid-cast, `test_fireball.gd` AC 21 and AC 22).

**Final suite (ONE run, two foreground calls):**

| Run | State harness | Integration | Timestamp |
|---|---|---|---|
| **Final** | **1128 / 0 / 10987, PASS** | **71/71**, all `exit=0` | 2026-09-28 **21:32:37** / **21:37:43** |

Same counts as the review-fix baseline (no new state test was added by this pass; the new coverage
lives in the live test, which is not counted by the state harness). Golden **HOLDS** at `de3589ff...`.
`git status --short` unchanged: 26 modified + 6 untracked, the same set as at open; `main.tscn` still
shows zero diff. Files: `C:\dev\_65d-suite-smokefix-state.txt`, `C:\dev\_65d-suite-smokefix-int.txt`.
Story Status stays `review`; board stays `ready-for-dev`; nothing committed.

### File List

**New**
- `data/effects/fireball.tres`
- `src/actors/props/target_cone_actor.gd` (+ `.uid`)
- `test/state/test_fireball.gd`
- `test/state/test_spell_targeting.gd`
- `test/integration/test_fireball_live.gd`

**Modified — data**
- `data/cards/bloodhound_step.tres`

**Modified — src**
- `src/state/resources/card_effect.gd`
- `src/state/pitch/pitch_state.gd`
- `src/state/player_state.gd`
- `src/state/projectile_board.gd`
- `src/state/economy/card_effect_resolver.gd`
- `src/state/match_state.gd`
- `src/systems/record_file.gd`
- `src/main/match_runner.gd`

**Modified — test**
- `test/state/test_card_authoring.gd`
- `test/state/test_card_observation.gd`
- `test/state/test_deck_and_hand.gd`
- `test/state/test_determinism.gd`
- `test/state/test_draw_delay_and_reshuffle.gd`
- `test/state/test_hero_cast.gd`
- `test/state/test_intent_recorder.gd`
- `test/state/test_pitch_staging.gd`
- `test/state/test_replay_identity.gd`
- `test/state/test_spell_framework.gd`
- `test/state/test_record_file.gd`
- `test/integration/test_cast_interrupt_live.gd`
- `test/integration/test_cast_presentation_live.gd`
- `test/integration/test_projectile_flight_live.gd`

**Modified — docs**
- `docs/implementation-artifacts/deferred-work.md` (M5/M6 discharged as closed by AC 37/38)
- `docs/implementation-artifacts/sprint-status.yaml` (board status kept at `ready-for-dev` per the
  project's `gds-dev-story` on_complete override — the promotion to `done` is the operator's gate; the
  `story_notes` entry shrunk back to one line at close)
- `docs/implementation-artifacts/6-5d-fireball-and-spell-targeting.md` (this record)

## Change Log

| Date | Author | Change |
|---|---|---|
| 2026-09-26 | Claude Sonnet 5 (gds-create-story, main session, no subagents) | Authored against 3c2d277; board keys 6-5d/6-5e renamed; M5/M6 moved here; `deck-1-spec.md` amended. Status `authored`. |
| 2026-09-26 | Claude Sonnet 5 (fix + promote pass, main session) | Readiness gate applied (3 blocking / 4 major / 6 minor), rulings `6-5d/R1..R23`; new AC 22, ACs renumbered to 38; Operator Questions removed; test-only card dropped. Status `ready-for-dev`. |
| 2026-09-27 | Claude Opus 5 (dev pass, session 1, main session, no subagents) | Tasks 1-8 and 10: data, staging, the cast fork, the hero-sourced projectile, targeting, presentation, M5/M6; golden re-baselined ONCE `97d52922` -> `de3589ff` (three isolated causes), `FORMAT_VERSION` 15 -> 16, key set 38 -> 40; mutations 1-5 killed. Two Task 9 items left open; Status stayed `ready-for-dev`. |
| 2026-09-27 | Claude Opus 5 (dev pass, session 2, main session, no subagents) | Task 9 completed: `test_fireball_live.gd` (AC 28 both arms, AC 20 in real physics, AC 36 in-scene, AC 37) and the AC 32 sibling replay run in `test_replay_identity.gd`; mutations 6-8 killed; a real live-composition defect found and fixed (`_projectile_launch_position` launched a hero-sourced shot a metre high, so a Fireball could not touch a unit); AC 36 discrepancy settled by operator ruling. Suite 1125/0/10975 + 71/71, golden `de3589ff` HOLDS. Status `review`. |
| 2026-09-27 | Claude Sonnet 5 (review fix pass, main session, no subagents) | Review contract `C:\dev\_65d-review.md` (APPROVE WITH FINDINGS, 0/1/7): MAJOR-1 (`apply_balance`'s refusal surfaced with `push_warning`) and MINOR-2 (the reorder refusal's projectile half reads `living_indices()`, not `size()`) fixed and mutation-proven; MINOR-3, MINOR-5 fixed; MINOR-6 (four predicted test pins, measured unmoved) and MINOR-7 (Task 9 text vs delivered live-test coverage) recorded. Suite 1128/0/10987 + 71/71, golden `de3589ff` HOLDS. Status stays `review`. |
| 2026-09-28 | Claude Sonnet 5 (smoke fix pass, main session, no subagents) | Operator smoke finding fixed: the bolt prop played for every cast, Fireball included. Added `MatchState.cast_outcome` (exempt pure query) and a runner gate so the prop plays only for a Honed Bolt cast; live AC 15 check added (`test_fireball_live.gd`: no dizzy, no root ring, no stun state after a Fireball landing) with a bolt-on-hero non-vacuity twin; two mutations killed. Live smoke 14/15 PASS, R-D6 re-invoked and passed (round ended normally on a spell kill), item 10 covered headlessly. Suite 1128/0/10987 + 71/71, golden `de3589ff` HOLDS. AC 36 text corrected to the operator ruling. Status stays `review`. |
