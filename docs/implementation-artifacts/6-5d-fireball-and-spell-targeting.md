---
baseline_commit: 3c2d277fb13c8a171ce0a548f1d99e1907955dd1
---

# Story 6.5d: Fireball and Spell Targeting

Status: ready-for-dev

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
36. **The totem's shot is bit-identical** (`6-5d/R11`): damage, speed, acceleration, homing, i-frame drop,
    deflect, block multiplier, no Bloodlust, no Vampiric Aura, and it still lands on the first opposing
    body it touches (pass-through is Fireball-only). Every `test_projectile_flight*.gd` /
    `test_unit_combat_live.gd` assertion passes unchanged. NEW assertions (tests ADDED, in `test_fireball.gd`):
    with the totem's owner under Bloodlust (dealt), the target under Bloodlust (taken) and Vampiric Aura up,
    a Combat totem's shot deals its authored `attack_at(0).damage` unmultiplied and heals nobody; a BLOCKING
    hero still takes the block-mitigated damage from a totem shot.
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

- [ ] **Task 1: Baseline (before any edit).** Save outside the repo: suite counts, golden,
  `FORMAT_VERSION`, per-player key count (38), pitch snapshot shape, `git rev-parse HEAD`. (AC 30-33)
- [ ] **Task 2: Data.** `data/effects/fireball.tres`; swap the pairing and the pitch price in
  `bloodhound_step.tres`; the flat `CardEffect` fields (header comment updated, neutral defaults); move the
  Bloodhound rows, `DECK_1_PRICES` and the bucket census in `test_card_authoring.gd`, and the rows in
  `test_card_database.gd`, `test_deck_injection.gd`. (AC 1-4)
- [ ] **Task 3: Staging.** Per-staging mana figure on `PitchState` (snapshotted); spend
  `min(current, mana_cap)` for a variable-cost pitch effect only; keep the existing refusal. Resolve Open
  Question 1 (staging half) and 5. (AC 5-9)
- [ ] **Task 4: Pitch cast fork and cast identity.** The cast carries the effect it strikes (pitch vs
  basic), the captured target and the locked damage; `_resolve_pitch_activate` starts the cast (with the
  block drop); `CAST_OUTCOMES` gains the Fireball row; rewrite the two 6-5c comments (`_apply_honed_bolt`'s
  docstring and `_resolve_basic_cast`'s "NOT FORKED" note, correcting the pin citation) and the
  deferred-owner rows. Resolve Open Question 1 (cast half). (AC 10-13, 24, 30, 35)
- [ ] **Task 5: Hero-sourced projectile.** Per-shot damage, hero source, profile authored on the effect;
  funnel and lifesteal treat it as the hero's damage; target-only contact; homing ends on target death;
  launched only by the cast strike; totem shots untouched; runner profile/launch/gather seats; grey
  actor. Resolve Open Questions 2-4, 6. (AC 13-23, 36)
- [ ] **Task 6: Targeting.** Capture lock target (opposing hero when unlocked) at cast start; Honed Bolt
  resolves against it (hero arm bit-identical, unit arm damage only, dead target nothing); pre-spend
  requirement. (AC 24-27)
- [ ] **Task 7: Presentation minimum.** Warning marker/alarm on the captured target (placeholder cone on a
  unit), the cast prop flying to the captured target, Fireball cast pose and projectile placeholders;
  poll-shaped, no new seam. (AC 28)
- [ ] **Task 8: M5 and M6.** Direction-aware homing assertion with a sign-inversion mutation proof;
  reload-time `unit_kinds` reorder refusal with a named reason. Resolve Open Question 7. (AC 37, 38)
- [ ] **Task 9: Tests.** `test_fireball.gd` (AC 5-23, incl. the launch-tick dead target AC 22 and the ADDED
  totem-shot guards AC 36), `test_spell_targeting.gd` (AC 24-27), `test_fireball_live.gd` (AC 17/18/20/21/22/28),
  the ADDED M6 reload-refusal test (AC 38, asserting the reason string), the authoring audit, replay identity
  (AC 32); update the table below; mutation proofs restore from a copy outside the repo.
- [ ] **Task 10: Golden.** Isolate causes 1-3 by erasing the new keys with every other change in place;
  confirm the non-causes; ONE re-baseline; `FORMAT_VERSION` 16; record before/after.
- [ ] **Task 11: Close.** Second full suite run, invariants green, `git diff --stat`, Dev Agent Record. The
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
### Debug Log References
### Completion Notes List
### File List

## Change Log

| Date | Author | Change |
|---|---|---|
| 2026-09-26 | Claude Sonnet 5 (gds-create-story, main session, no subagents) | Authored against 3c2d277; board keys 6-5d/6-5e renamed; M5/M6 moved here; `deck-1-spec.md` amended. Status `authored`. |
| 2026-09-26 | Claude Sonnet 5 (fix + promote pass, main session) | Readiness gate applied (3 blocking / 4 major / 6 minor), rulings `6-5d/R1..R23`; new AC 22, ACs renumbered to 38; Operator Questions removed; test-only card dropped. Status `ready-for-dev`. |
