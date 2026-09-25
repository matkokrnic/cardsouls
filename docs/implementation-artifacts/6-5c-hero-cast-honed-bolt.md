---
baseline_commit: d6d5602d40fddbd24b3e442b78060dcc3c320659
---

# Story 6.5c: Hero Cast Framework and Honed Bolt

Status: ready-for-dev

<!-- Tier A. Split from 6-5-spell-resolution by operator ruling (2026-09-22) into six sub-stories
(6-5a..6-5f); this is the third. Depends on 6-5a (done); 6-5b (done) is upstream on the same board.
Scope locked by the operator in the scope talk of 2026-09-25; the rulings are numbered `6-5c/R1`..`R19`
in the decision-log session "6-5c scope + readiness gate (2026-09-25)" and cited below by label.
Golden PREDICTED to move, FORMAT_VERSION PREDICTED 14 -> 15. Authored 2026-09-25 by gds-create-story,
readiness-gated and fixed 2026-09-25 (main session, no subagents). Line numbers below are as of d6d5602. -->

## Story

As the operator (and later the friends playtest),
I want offensive spells to have a visible cast windup the opponent can react to -- with Honed Bolt the
first card to use it -- and a bolt that stuns and then roots whoever it lands on,
so that the Blue half of Deck 1 has its first hero-cast attack, the cast framework Rocksling, Fireball
and Corpse Bomb will reuse exists, and the "Honed Bolt stun+root into unblockable" combo named in
`deck-1-spec.md`'s balance risks can actually be played and judged.

## Board note

`sprint-status.yaml` key `6-5c-hero-cast-honed-bolt` (slug read from the file, unchanged),
`ready-for-dev` since the readiness-gate fix pass of 2026-09-25 (`6-5c/R1`..`R19`). `6-5d`, `6-5e`, `6-5f`
are untouched. Depends on `6-5a-spell-framework-and-buffs` (`done`).

## Repo-verified facts this story is authored against

- **Effects** are named `.tres` under `data/effects/`, referenced by cards via `ext_resource`; every
  effect number is a flat `@export` on `CardEffect` (`src/state/resources/card_effect.gd` -- flat, never a
  subclass or nested resource, so `RecordFile._card_effects` round-trips it generically). The resolver
  dispatches on the WHOLE `effect_id` and COMPUTES; `MatchState._apply_card_effect` (`match_state.gd:3324`)
  APPLIES (D6).
- **`honed_bolt` today** is a deferred no-op: `data/effects/honed_bolt.tres` authors only `effect_id`;
  `card_effect_resolver.gd:194-197` maps it in `DEFERRED_EFFECT_OWNERS` to this story's key, so a cast resolves
  as `REASON_DECK1_NOT_YET_RESOLVED` (mana spent, card discarded, replacement owed, nothing applied).
  `data/cards/honed_bolt.tres`: BLUE, `cast_condition.mana_cost = 4.0`, pitch = `counterspell`
  (4 mana + 1 blue orb), `max_copies = 3`. The 4-mana price is already authored and stays on the card.
- **The spec's names** (`docs/planning-artifacts/deck-1-spec.md:35`, verified): `stun_seconds` T[0.4],
  `root_seconds` T[2.5] "starting when stun ends", `root_blocks_run` T[true], `root_blocks_roll` T[true];
  "walk, block, deflect and colour counter still work"; damage T[4]. No name is given there for the cast
  duration or the repeat-landing switch.
- **Card resolution seat.** Card presses resolve at step 6 of `advance()`, AFTER step 3's actions
  (`match_state.gd:588`+). `_resolve_basic_cast` (`:3179`) is where a Mode 1 cast pays: state gates
  (CHARGING/STUNNED), empty-slot gate, `CastEvaluator.refusal_reason`, then the board-aware PRE-SPEND gate
  `_board_refusal_reason` (`:3601`, `6-5b/R14`), then spend, discard, `_apply_card_effect`,
  `record_resolved_card`, the owed replacement. `_resolve_card_action` (`:3097`) holds the two card-layer
  busy locks (`is_getting_up()` and `defense_window.is_running`), each announcing through
  `reject_action(&"card_cast", <reason>)` (`REASON_COUNTERING` and its get-up sibling). The ACTION seat
  is the opposite: `_resolve_actions` drops a locked press SILENTLY (`match_state.gd:1462-1464` states
  the rule: a table row that refuses has never emitted `action_rejected`; the card seat announces).
- **Busy locks are WINDOW-DERIVED, not `ActionState`s.** The get-up (`6-6a/R7`) and the counter (`6-6b`)
  each lock input at `_resolve_actions` (`:1451`, `:1469`, silent drop) and card play (announced), and root
  the body in `_resolve_movement` (`:4819`+) with a LITERAL zero (`5-2/R5`: a tunable "rooted" is not
  rooted). The cast lock is the same problem a third time.
- **STUNNED today is not "no inbound edges".** `TRANSITION_TABLE` has zero inbound STUNNED edges
  (`hero_state.gd:58-74`, `&"stunned": {}` at `:72`), but STUNNED is entered by exactly THREE authored direct
  `set_action_state(STUNNED)` writes, all in `match_state.gd`: the melee deflect against the attacker
  (`5-6`, `_resolve_contacts`), the knockdown on the victim of an unanswered unblockable (`6-6a`,
  `_apply_landing_packages` `:4303`) and the colour counter (`6-6b`, `_resolve_color_counter`). Pinned by
  `test_action_state.gd::test_stunned_has_exactly_three_authored_non_table_entry_points` (`:161`).
  The stun window is `hero.stun`, exit is the step-3 timer arm (`_resolve_actions` STUNNED case,
  `:1358`), natural expiry only. **`BalanceTicks.is_knockdown_stun(duration)` (`balance_ticks.gd:201`)
  tells a knockdown from an ordinary stun BY DURATION** (`>= knockdown_stun_ticks`, authored 2.5 s), and a
  knockdown-length stun opens get-up i-frames and plays the `knockdown` pose. The deflect stun is 0.4 s,
  the SAME length as the bolt stun.
- **Stun stacking is already ruled (`R-STUNSTACK`, 6-6a AC 5/AC 7):** a hit on an already-knocked-down
  hero deals damage but never restarts or extends the running window (the floor rule); a knockdown landing
  on an ordinary stun replaces it (one-way escalation).
- **Roll i-frames and the seat-symmetry latch.** `HeroState.is_iframe_open()` covers `roll_iframe` (with
  its one-tick close grace) AND the get-up window. The unblockable dodge rung does NOT read that predicate:
  it reads `MatchState._iframe_open_at_step3` (`:404`, written at `:713`, read at `:4226`), which is WIDER --
  `is_iframe_open() or _gets_up_this_tick(hero)`; the extra term exists because on a knockdown's exit tick
  the plain predicate reads false (`match_state.gd:4486-4490`). The latch captures each hero's reading
  BEFORE any press of the tick, so a roll pressed on the very tick of
  an unblockable landing dodges on neither seat and a roll from the previous tick dodges on both (`5-6`
  AC 7; `R-IFRAME-UNBLOCKABLE`). This is the precedent for "i-frames open on the strike tick".
- **Damage funnel.** `_funnel_damage` (`:2537`) is the one function every damage seat calls (Bloodlust's
  dealt/taken multipliers) and `_apply_lifesteal` heals the caster from HP actually removed (`6-5a/R3`,
  `R4`). The block multiplier and the deflect ladder live in `_resolve_contacts`, contact-fact-driven;
  a bolt is not a contact fact.
- **Movement.** `_resolve_movement` chooses gait: `actually_running` requires the run key AND stamina AND
  not `run_locked_out`; otherwise `walk_speed` (gait ladder `:5029-5039`, `actually_running` at `:5030`). Roll is the `ROLLING` `TRANSITION_TABLE` edge,
  charged at `_try_transition` (`:1489`) with the 1-4 fall-through on refusal.
- **Timed rules and windows.** `PlayerState` owns a six-slot timed-rule seat (`RULE_COUNT = 6`,
  cancelled at round end and debug reset) plus per-player windows (`charge_window`, `landing_window`,
  `defense_window`). `MatchState.debug_window_ticks_remaining` (`:1290`) lists hero windows for the debug
  panel. Hero snapshot key set is pinned in `test_debug_window_countdown.gd:105-118`; the per-player key
  set (36) in `test_draw_delay_and_reshuffle.gd:376`.
- **Clip pipeline.** The hero's clips live in ONE `AnimationLibrary`,
  `assets/characters/paladin/paladin_anims.res`, assembled from the per-clip Mixamo FBXs by committed
  tools (`tools/add_paladin_*.gd`), with strike/impact frames measured headlessly by committed tools
  (`tools/measure_*_strike_frames.gd`) and speed-mapped by the runner-fed
  `AnimationController._COUNTER_PRESENTATION` shape (6-6b). `test_rig_clips.gd::EXPECTED_LOOP` pins
  the clip set (27 today). `cast.fbx` and `dizzy.fbx` exist in `assets/characters/paladin/` UNTRACKED,
  with no `.import` files yet.
- **Audio.** Cues are `AudioStreamPlayer` children of the hero scene wired by `TelegraphController`
  (`hero.tscn` ext_resources: `sting_*.wav`, `cue_*.wav`) on the `CombatCues` bus; `tools/gen_charge_audio.gd`
  is the committed generator precedent.
- **REPORT (scope talk 2026-09-25): what uses `stunned.fbx` and `hit_react.fbx` today** (content search of
  `.gd/.tscn/.tres/.md/.sh/.cfg/.import`, this authoring pass; NOT changed by this story):
  - Neither FBX is referenced by path anywhere in code, scenes or tools -- only their own `.import`
    files name them. They are consumed BY CLIP NAME after `tools/add_paladin_defense_reactions.gd` (6-6a)
    baked them into `paladin_anims.res` as the `stunned` and `hit_react` clips.
  - `hit_react`: `AnimationController` (`animation_controller.gd:624-625`) plays it as a yielding one-shot
    on the `hit_landed` seam, ONLY for an IDLE-family target (never over ATTACKING/ROLLING/CHARGING/
    STUNNED/BLOCKING). Pinned by `test_hero_reaction_clips.gd`, `test_defense_reactions_live.gd`,
    `test_counter_reactions_live.gd`. `docs/implementation-artifacts/deferred-work.md:223-267` and `docs/playtest-log.md:466` record its
    slide-while-moving polish item (owner: the future animation-layering story -- a non-goal here).
  - `stunned`: `AnimationController._play_stun` (`:895-904`) for `STUN_FLAVOR_ORDINARY` -- today that is
    only the deflect stun on the attacker (the colour-counter stun still exists, `match_state.gd:4476-4477`,
    but since 6-6b it is knockdown-LENGTH, so `is_knockdown_stun()` classifies it `STUN_FLAVOR_KNOCKDOWN`);
    held to the stun window by `held_clip_speed`. Pinned by `test_hero_reaction_clips.gd:96,164-165,194`,
    `test_defense_reactions_live.gd:121`, `test_rig_clips.gd:38`.
  - The bolt stun takes its OWN pose (`dizzy`, `6-5c/R10`), so both existing clips stay bit-identical.
    `test_hero_reaction_clips.gd:164-165` pins `[ORDINARY, 1.0, &"stunned"]` AND `[ORDINARY, 0.4, &"stunned"]`:
    the 0.4 s collision with the bolt stun is already asserted in the suite.

## Discrepancies found against the prompt (repo wins)

1. **"Stun is the first inbound edge into STUNNED; the guard test enumerating zero inbound edges is
   changed deliberately."** Neither half matches the repo (facts above): STUNNED already has three
   authored direct entries, and the TABLE-edge scan (`test_table_has_no_inbound_stunned_charging_or_dead_edges`,
   `test_action_state.gd:93`) stays green unless someone adds a TABLE edge -- which nothing here calls for
   (no press maps to a bolt stun; the `6-6a` / `6-6b` arguments for non-table entries apply verbatim). The
   guard that DOES move is the positive count, `..._exactly_three_authored_non_table_entry_points`: a
   bolt stun write is a fourth authored site (3 -> 4), argued per that test's own failure message, OR
   the dev pass routes it through a shared helper and argues why the count does not move. Recorded as a
   deliberate change either way, as the operator intended; only the premise is corrected.
2. **"Ordinary hits, including unblockable hits, do NOT interrupt a cast. Being stunned DOES."** An
   UNANSWERED unblockable knocks its victim down (`_apply_landing_packages`) -- which is a stun. Ruled
   (`6-5c/R7`): hit DAMAGE never interrupts; STUN does, whatever inflicted it, so an unanswered
   unblockable landing on a casting hero cancels the cast through its knockdown (card and mana lost).
3. **"No-target refusal ... (target = enemy hero)".** The bolt's only target is the enemy hero, which
   exists and is alive for every tick on which a card can resolve (a dead hero freezes the round, step 1b).
   The no-target refusal is therefore structurally present (same pre-spend seat) but has no reachable
   player-facing case for Honed Bolt today; it exists for later cast effects that need a target the
   board may lack.
4. **"Cast duration authored per effect, default 0.8 s."** `CardEffect`'s standing convention is that an
   unused field keeps a NEUTRAL default so an unused number can never change an outcome. A 0.8 default
   is safe only because the field is read ONLY for effects the resolver classifies as casts; buffs and
   every existing effect never read it and stay instant. The dev pass must keep that true (AC 1, AC 2).
5. **`deck-1-spec.md:35` says the bolt lands "on the locked target".** Scope talk 2026-09-25 supersedes:
   the target is ALWAYS the enemy hero, never a minion, regardless of lock-on. The spec text is not
   edited by this pass (docs never share a commit with code; authoring commits nothing); a dated
   amendment to the spec is owed by the close-out, on the `6-5b` amendment precedent.

## Rulings carried as fixed inputs (decision-log session "6-5c scope + readiness gate (2026-09-25)")

Cited by label, `6-5c/Rn`. Everything under "Acceptance Criteria" that restates one of these is FIXED;
anything else in this file is authored default and reviewable.

- Offensive spells get a visible cast windup; buffs stay instant; the framework is reusable, Honed Bolt is
  the only user here (`R4`).
- Cast duration authored per effect in `.tres`, default 0.8 s (`R4`).
- Caster stands still the whole cast, cannot cancel, block, roll or attack (commitment, like a swing) and
  cannot play any card, the colour counter included (`R4`, `R6`, `R15`).
- Payment and the no-target refusal follow the existing pre-spend gate unchanged; target = enemy hero (`R4`).
- Ordinary hits do not interrupt a cast; ANY stun does -- the cast is lost, card and mana are NOT
  refunded (`R3`). That includes the knockdown of an unanswered unblockable (`R7`).
- The bolt strikes the enemy hero instantly at the end of the cast: no travel, no projectile; range,
  direction, minions in between are irrelevant; never a minion, regardless of lock-on (`R1`).
- ONLY avoidance: the target's roll i-frames open on the strike tick; get-up i-frames dodge identically
  (`R1`, `R8`). Block and deflect neither reduce nor negate (`R4`).
- On hit: 4 damage through the shared damage funnel (Bloodlust and Vampiric Aura apply, `R13`), then
  STUNNED 0.4 s, then root 2.5 s. Stun interrupts whatever the target is doing (swing, block, chargeup,
  cast); no movement or actions during stun (`R4`). On a knocked-down target: damage only (`R9`). On a
  deflect-stunned target: the stun restarts at full length and the root follows (`R12`).
- Root: cannot run or roll (a roll press is dropped silently, `R14`); walk, block, deflect, colour counter,
  attacking and card play all still work (`R4`).
- A second bolt during root stuns again and restarts the root (choice A). A `.tres` switch selects choice
  B (during root the bolt deals damage but neither stuns nor extends the root). Default A (`R2`).
- Every number and switch lives in `.tres`. Counterspell undo is NOT built here (6-5f).
- Presentation minimum is in scope (a stun you cannot read is a defect): cast pose, sky-to-target bolt
  aligned to the strike tick, target warning marker + sound for the whole cast, dizzy stun pose (`R10`),
  root marker at the target's feet (`R5`).

## Acceptance Criteria

### Cast framework (reusable, data-driven)

1. **A cast is a commitment window between the press and the effect.** For an effect the resolver
   classifies as a CAST, pressing its card pays at the press (AC 4) and starts a cast on the caster; the
   effect applies at the END of the cast, on a single, exactly-defined STRIKE TICK, not at the press. The
   cast duration is authored per effect in `.tres` in seconds, default 0.8, converted to whole ticks once
   (A1). A `.tres` retune changes the timing with no code edit. The framework names no card. Honed
   Bolt is the only effect that casts in this story.
2. **Buffs and every existing effect stay instant.** No effect other than Honed Bolt starts a cast, reads
   the cast duration, or changes timing. The 0.8 default is read only for cast-classified effects.
3. **The strike tick is pinned.** A cast pressed on tick T with duration N ticks strikes on the tick the
   cast countdown empties (T + N, the `landing_window` shape); a boundary test pins N-1, N and N+1 for a
   non-default authored duration.
4. **Payment and refusal are the existing pre-spend gate, unchanged.** A cast card is refused, with
   nothing spent, by every gate a basic cast already meets (dead caster, CHARGING, STUNNED, empty slot,
   unaffordable, get-up, counter-busy, closed-layer rules as today) plus the new ones below (already
   casting, AC 8). Payment at the press is the ordinary Mode 1 sequence: mana spent, card removed from the
   hand into the discard, replacement owed. The target requirement is evaluated at the same pre-spend seat
   (Discrepancy 3): for Honed Bolt it is the enemy hero.
5. **Interrupts.** Only being STUNNED interrupts a cast (`6-5c/R3`), whatever inflicted the stun: a bolt
   stun, a deflect stun, or the knockdown of an unanswered unblockable (`R7`). On interrupt the cast is
   lost: nothing applies, mana and card are NOT refunded, the replacement is still owed, and the cast
   state is cleared. Damage alone never interrupts, including the damage of an ordinary melee hit. Caster
   death and the debug reset also end it, and the round-over freeze freezes it.
6. **Spells layer closed.** With `FeatureFlags.spells` closed the card still resolves (spent, discarded,
   replacement owed), starts NO cast, applies nothing, and shows no cast presentation -- the standing
   closed-layer degrade of the other spell effects.
7. **The resolved-card record and `card_cast_resolved`** follow the press (the card is spent then); the
   effect's strike does not write a second record (`6-5c/R17`).

### Commitment

8. **The caster is committed for the whole cast.** From the press to the strike (or interrupt) the caster
   cannot walk, run, roll, attack or block, and cannot play any card -- every card mode, another cast and
   the colour counter included (`6-5c/R6`, `R15`). The caster does not move at all, at any tuning; their
   attack/roll/block presses produce no rejection cue; a card press is refused with an announced reason.
   Nothing the caster presses cancels the cast. Facing keeps tracking the lock like every other rooted
   state.
9. **Nothing is buffered.** A press dropped during the cast is not replayed when the cast ends.

### Honed Bolt strike

10. **Instant, unaimed strike on the enemy hero.** At the strike tick, if the caster is alive and
    unstunned, the bolt hits the enemy hero: no travel, no projectile, no range, direction or line-of-sight
    test, minions in between irrelevant, lock-on irrelevant (a lock on a minion or totem does not
    redirect it). It never targets a minion or totem.
11. **The only avoidance is the target's i-frames on the strike tick.** The bolt reads the step-3 latch
    array `_iframe_open_at_step3` (`6-5c/R8`; NOT the bare `HeroState.is_iframe_open()`, which lacks the
    get-up exit-tick term): a roll pressed on the strike tick itself dodges on NEITHER seat; a roll from
    the previous tick (its one-tick close grace included) dodges on BOTH, identically. Get-up i-frames
    dodge exactly as roll i-frames do, including on the knockdown's exit tick. A dodged bolt does no
    damage, no stun, no root and emits no `hit_landed`; the card and mana stay spent.
12. **Block and deflect neither reduce nor negate.** A blocking hero takes the full damage (the block
    multiplier is not applied), a deflect window neither negates the bolt nor costs the target stamina nor
    stuns the caster; facing is irrelevant.
13. **Damage.** The authored damage (default 4, absolute HP) is applied to the enemy hero through the
    shared damage funnel: Bloodlust's dealt/taken multipliers apply and Vampiric Aura heals the caster
    from the HP actually removed (`6-5c/R13`, the standing rule for every later spell). It does not
    consume Frostbite (melee-only trigger).
    It announces through the existing `hit_landed` seam. A lethal bolt ends the round through the normal
    resolution check on its own tick, and writes no stun or root onto a hero that just died.
14. **Stun.** After damage, if the target is alive, it is STUNNED for `stun_seconds` (default 0.4). The
    stun interrupts whatever the target is doing -- a swing (its orphaned hitbox stops gathering facts),
    a block, an unblockable chargeup (abandoned as a knockdown abandons it; card and stamina stay spent),
    a cast (AC 5) -- and, while it runs, the target cannot move or act (the STUNNED behaviour that exists:
    hard-rooted, presses dropped, cards refused, colour counter unavailable). Exit is natural expiry to IDLE,
    like every other stun.
15. **The bolt stun is not a knockdown.** It opens no get-up i-frames and plays no `knockdown` pose. The
    authored `stun_seconds` must stay below the authored knockdown duration, because the duration
    classifier would otherwise misread it; an authoring audit enforces that (AC 21).
16. **Stacking, per the standing rulings.** (a) Bolt on a hero already in a KNOCKDOWN: damage only -- no
    stun, no root (the `R-STUNSTACK` floor rule; `6-5c/R9`). (b) Bolt on a hero in an ordinary (deflect)
    stun: the stun restarts from zero at the bolt's full `stun_seconds` and the root follows, exactly as
    for a bolt on a rooted hero (`6-5c/R12`). (c) A knockdown landing on a bolt-stunned or
    rooted hero proceeds as the existing one-way escalation and does not cut a running root short.

### Root

17. **Root starts when the stun ends** and lasts `root_seconds` (default 2.5). While rooted, and only
    while, `root_blocks_run` (default true) makes the hero unable to run: a held run key gives walk pace,
    drains no run stamina and touches no gait latch; `root_blocks_roll` (default true) makes a roll press
    refused: no state change, NO stamina spent, and NOTHING is announced -- no rejection sound, no flash,
    no `action_rejected` (`6-5c/R14`; the root marker on the feet is the explanation) -- and a
    lower-priority same-tick press may still be considered per the existing fall-through. The two switches are independent. Walk, block, deflect, the colour counter,
    attacking (swing and unblockable initiation) and card play all still work.
18. **Root removes exactly run and roll.** It does not affect the rooted hero's own unblockable launch, its
    attack lunge, a counter's travel, or a knockdown's own root. Root ends by natural expiry, the debug reset
    and wherever the other per-player timed state is cleared at round end; the round-over freeze freezes it.

### Repeat landing (choice A, switch to B)

19. **A second bolt landing during the stun or the root:** with the switch at its default (choice A) the
    target is stunned again for `stun_seconds` and the root restarts in full afterwards; with the switch
    flipped in `.tres` (choice B) the bolt deals its damage and neither stuns nor extends the root. The
    switch is a `.tres` value read at the landing, and both settings have a test. AC 16(a)'s knockdown
    floor takes precedence over both.

### Data

20. **Every number and switch is authored data, never a literal in `src/`:** mana 4 (already on the card),
    damage 4, cast duration 0.8, `stun_seconds` 0.4, `root_seconds` 2.5, `root_blocks_run` true,
    `root_blocks_roll` true, the repeat switch (default A). The three names the spec fixes are used
    verbatim; the others follow the flat-export convention (`6-5c/R19`). New fields are flat exports
    on `CardEffect`, and an effect that does not use them keeps behaviour bit-identical.
21. **Authoring audit.** A test loads the REAL `data/effects/honed_bolt.tres` and asserts every field
    above, plus: `stun_seconds` and `root_seconds` non-negative, cast duration positive for a cast effect,
    and `stun_seconds` strictly below `knockdown_stun_seconds` from `data/balance/balance_config.tres`
    (AC 15). `honed_bolt` leaves `DEFERRED_EFFECT_OWNERS`; Counterspell, Rocksling, Boom and Corpse Bomb
    stay deferred and their no-op behaviour is unchanged.
22. **No undo data.** Nothing here records a per-cast rollback shape for Counterspell (6-5f owns undo).

### Determinism, replay, reset

23. **Everything that crosses a tick is integer-tick state under A1**: the cast countdown and whatever
    identifies the in-flight cast, and the root countdown. No `Time`/`OS`/`Engine`/global RNG in `src/state/`
    (D3(b), enforced by `test_architecture_invariants.gd`); no second `_physics_process` (F1). A record of a
    match containing a bolt replays to the identical final hash, and `RecordFile.FORMAT_VERSION` moves if
    and only if the recorded content shape changed, with hard refusal of the old version (the `6-5a`
    precedent). (Which members are hashed, and the isolation proof, are Golden Prediction / Task 11.)
24. **Reset and freeze.** The debug reset clears the cast and the root; the round-over freeze (step 1b)
    stops both countdowns; a new round clears both wherever the timed rules are cleared. The new windows
    appear in the debug countdown accessor on the stun window's precedent.

### Presentation (minimum, in scope)

25. **Cast pose and bolt.** The caster plays `cast` (Mixamo "Sword And Shield Casting": the hero raises the
    sword). The bolt visibly launches from the raised sword into the sky, then crashes down from the sky
    onto the target's position so that its ARRIVAL is the strike tick, and a retuned `cast` duration
    retimes the show with no code edit. A headless integration test pins the arrival tick to the state's
    strike tick (timing is machine-checkable; how it looks is not, `PROC/R8`).
26. **Target-side warning.** From the press to the strike (or the interrupt) the TARGET shows a warning
    marker AND plays a warning sound, so it can time the roll with the caster off-screen (the cue is
    anchored to the target, not the caster). Both end at the strike tick or on interrupt. The sound is
    distinct by ear from the existing stings and cues.
27. **Stun pose.** During the bolt stun the target plays `dizzy` (Mixamo "Dizzy Idle"), full body, no
    upper/lower split (the target does not move in stun). It is distinguishable from the deflect stun's
    `stunned` pose even though both last 0.4 s (`6-5c/R10`, `R16`). `hit_react` is not played over it.
28. **Root marker** at the target's feet for the root duration: appears when the root is in force, ends on
    expiry, reset or death, and never appears without a root.
29. **Clips adopted.** `cast` and `dizzy` are present in `paladin_anims.res` as one-shots;
    `test_rig_clips.gd`'s `EXPECTED_LOOP` grows 27 -> 29 with loop flags pinned; the existing `stunned` and
    `hit_react` clips are bit-identical. Presentation observes state only through existing observation
    seams (`6-5c/R16`); it never decides an outcome.

### Regression

30. **Nothing else moves.** Every 6-5a and 6-5b effect, every still-deferred effect, and every existing
    swing/roll/block/stun/knockdown/counter behaviour is unchanged; the full suite before and after differs
    only by the rows of the broken-test table below plus the new tests.

## Non-Goals

- Every other Deck 1 card: Rocksling, Fireball, Corpse Bomb (6-5d), Boom (6-5e), Counterspell and its undo
  (6-5f). The framework must let them adopt it by data plus their own apply outcome; only Honed Bolt does now.
- Upper/lower-body animation layering (the stunned target does not move, so it is not needed here; the
  `hit_react` slide item in `deferred-work.md` stays owned by the layering story).
- Card price legibility and HUD; the Grave Ward corpse-tint fix; E6 docs debt (all deferred by 6-5b to the
  Tier B presentation story); the `test_unit_combat_live.gd` exit flake (E6 close-out tooling debt).
- Changing `stunned.fbx` / `hit_react.fbx` or their clips.
- Minions being stunned or rooted (a unit has no `ActionState`; the bolt never targets one).
- Balance judgement of the stun+root into unblockable combo -- this story makes it playable; the
  operator judges it at smoke (`deck-1-spec.md` balance risk 2).

## Golden Prediction (predictions to MEASURE, not claims)

Baseline to measure and save outside the repo BEFORE any edit: golden `962514b1e40f95d4ebda3265bc85e48a6321209b6e064b2a43332964644136b9`,
`RecordFile.FORMAT_VERSION` 14, per-player snapshot keys 36, suite 1019 / 0 / 10091 + 68 integration
(the 6-5b close-out numbers; re-measure, do not trust).

**PREDICTED to MOVE.** Causes to be separated and measured each in isolation, on the `6-5a`/`6-5b` method
(erase the new keys from `to_snapshot()` with every other change in place; the hash must return to the
baseline exactly):

1. **New cross-tick cast state** (the cast countdown and the in-flight cast's identity) -- hashed under the
   standing rule, so at least one new snapshot key. The determinism fixture's one cast is a `summon_*`, so
   the key enters at REST: measure key-count +N and resting contents, not a content claim.
2. **New cross-tick root state** (the root countdown) -- a second cause on the same terms (per-player or
   hero-nested is the dev pass's call; the pins in `test_draw_delay_and_reshuffle.gd:376` and
   `test_debug_window_countdown.gd:105-118` say which, so neither pin can be predicted here: the dev pass
   RECORDS which one moved and why). A state-side bolt-stun discriminator, if the dev pass adds one
   (`6-5c/R16`), is a further cause on the same terms.
3. **Non-cause, to confirm:** the STUN window's snapshot key already exists, so the bolt stun's new write
   site adds no key.
4. **New refusable outcomes** (any card press refused while casting, `R6`; a roll press refused while
   rooted, silently, `R14`). Under
   the standing `SC/R6` boundary a change that makes a pressed action refusable moves the golden IF the
   recorded sequence presses one. Predicted NON-cause (the fixture presses neither; `6-5b` measured the same
   shape), but MEASURED, and the unit suite moves regardless.
5. **Non-cause, to confirm (`BC/R3`):** the authored `honed_bolt.tres` numbers and any new `CardEffect`
   field defaults. The golden builds its effects in-test and never loads `data/effects/`; state explicitly
   whether the effect INJECTION set's shape moved the hash and measure it separately from 1-2.
6. **`RecordFile.FORMAT_VERSION` PREDICTED 14 -> 15**, hard refusal of v14: recorded content (card effects)
   gains fields whose defaults would make an old record replay a bolt as an instant no-op -- exactly the
   silent divergence the version exists to refuse. A record carries inputs and content, never a hash, so
   the bump cannot itself move the golden. If measurement shows the recorded shape did not change, the
   version stays and the reason is recorded.
7. **Intake:** no new runner-pushed fact is predicted (the target is always the enemy hero, so nothing like
   Drain's pushed selection exists). Any new public `MatchState` method taking a parameter is an intake and
   needs a capture channel or a named exemption (`test_intent_recorder.gd`).

**Measure, do not assume:** full suite before any edit and after, golden hash / key counts /
`FORMAT_VERSION` in both runs, files saved outside the repo, per the standing Tier A discipline. Exactly
one re-baseline is expected; a second is a finding to explain.

## Live Smoke (operator, two pads, flip config `[3,3]`; the operator may reset it at the gate)

Flip `slot_controller_kinds = Array[int]([3, 3])` (two gamepads: two killable, human-driven slots).
**Honed Bolt damage can kill, so R-D6 is RE-INVOKED for this story** (its acceptance is spent on use and is
re-invoked per story against a killable human-driven slot: decision-log `R-D6` entries, `2-1/R2`,
`6-1c/R4`). The binding editor-collateral procedure (`6-1c/R4`), restated verbatim:

- Flip config edited TEXTUALLY with the editor closed.
- `git diff` immediately after adding the flip config, and again immediately after removing it.
- After any editor session, `git diff -- project.godot` and revert any collateral change:
  `git checkout -- src/main/main.tscn project.godot` (full paths, both files).
- Editor reload dialog: always "Reload from disk", never "Ignore external changes".
- Re-check `git status` + the collateral diff immediately before any commit chain begins -- not earlier in
  the session.

1. **The cast.** Press Honed Bolt: the caster raises the sword, the bolt visibly leaves the sword into the
   sky, and crashes onto the opponent exactly as the damage lands (~0.8 s after the press).
2. **Committed.** During the cast the caster cannot move, roll, block, attack or play any card, and
   cannot cancel; action presses are simply dropped, and a card press (another cast, a buff, a colour
   counter) is refused with an announced cue (`6-5c/R6`).
3. **Warning, caster off-screen.** Turn the camera away from / move far from the caster: the target still
   sees a marker and hears the warning for the whole cast.
4. **Dodge.** A roll timed so the i-frames cover the strike: no damage, no stun, no root. A roll too early
   (i-frames end before) and a roll pressed on the strike tick itself both get hit. A hero getting up
   from a knockdown when the bolt arrives dodges it exactly like a rolling one (`6-5c/R8`; step 15).
5. **Block and deflect do not help.** Blocking: full 4 damage. A perfectly timed deflect: still the full
   hit, no stun on the caster.
6. **Ignores minions and lock-on.** With minions between the heroes and lock-on set to a minion, the bolt
   still hits the enemy hero.
7. **The hit.** 4 damage; the target goes into the dizzy pose for ~0.4 s and cannot act; then the root marker
   shows at its feet for ~2.5 s. Legibility (marker, sound, dizzy pose at 0.4 s) is judged here (`PROC/R8`).
8. **Root.** While rooted: run gives walk pace (no run drain), roll does NOTHING -- no sound, no flash,
   no stamina spent (`6-5c/R14`);
   walk, block, deflect, colour counter, a swing and an unblockable, and card play all work.
9. **Interrupts.** A bolt on a swinging hero cancels the swing; on a blocking hero drops the block; on an
   unblockable chargeup abandons it (card stays spent); on a hero mid-cast cancels that cast (no strike, no
   refund).
10. **Ordinary hits do not interrupt a cast.** Hit a casting hero with a melee swing: the cast completes. An
    unanswered unblockable landing on a casting hero knocks it down and the cast is lost (`6-5c/R7`).
11. **Repeat bolt.** A second bolt during the root: stun again, root restarts (default A). Flip the switch to
    B in `.tres`: damage only. A bolt on a knocked-down hero: damage only (`R9`). A bolt on a hero in a
    deflect stun: the stun restarts at full length and the root follows (`R12`).
12. **Lethal.** Bring the target low and bolt it: the hero dies and the round ends normally (R-D6), with no
    stun/root left over on a corpse. A caster killed mid-cast never strikes.
13. **Combo.** Bolt into an unblockable chargeup on the rooted target: the counter is still the answer.
14. **Regression.** Every 6-5a/6-5b card and the still-deferred cards (Rocksling, Boom, Counterspell, Corpse
    Bomb) cast cleanly as before; buffs are instant; no crash, assert or visible regression.
15. **Get-up dodge.** Knock the target down (unanswered unblockable) and time a bolt to arrive while it is
    getting up: no damage, no stun, no root (`6-5c/R8`).
16. **Dizzy vs stunned, back to back.** Take a deflect stun and a bolt stun one after the other and judge
    whether the two poses read as different at the same 0.4 s (`6-5c/R10`, `PROC/R8`).
17. **Casting cannot counter; buffs apply.** Start a cast while the opponent charges an unblockable: the
    colour counter press is refused during the cast (`6-5c/R6`, `R15`). With Bloodlust up the bolt's damage
    doubles; with Vampiric Aura up the caster heals from it (`R13`).

## Tasks / Subtasks

**Existing tests expected to break (each repaired in the task that removes its cause; the dev pass records
the measured list, which may differ):**

| File | What breaks | Fix |
|---|---|---|
| `test/state/test_action_state.gd:161` `test_stunned_has_exactly_three_authored_non_table_entry_points` | Pins `["res://src/state/match_state.gd x3"]`; a bolt stun write is a fourth authored site | 3 -> 4 with the argued-not-merely-added justification its failure message demands (or a shared helper and the argument for why the count is unchanged). The TABLE scan at `:93` stays UNEDITED and green |
| `test/state/test_spell_framework.gd:114-123` | Literal `owners` dict holds five deferred rows; asserts count `== 5` | Five -> four (`honed_bolt` leaves); rename the count-in-the-name test per its own discipline |
| `test/state/test_card_authoring.gd:331`, `:432` | `deferred == 5` count, and the loop asserting every deferred effect authors NO number: `honed_bolt` leaves the dict, so its coverage silently vanishes | Count 5 -> 4; ADD positive assertions for `honed_bolt`'s authored numbers on the existing 6-5b pattern |
| `test/state/test_draw_delay_and_reshuffle.gd:376`; `test/state/test_debug_window_countdown.gd:105-118` | Per-player and hero snapshot key-set pins gain the new members | Named additions, on the `6-6a`/`6-7` precedent |
| `test/state/test_determinism.gd` (`GOLDEN` `:1111`, key-path count, the causes block) | Golden re-baseline | ONE re-baseline, causes isolated both directions and written at the constant |
| `test/state/test_record_file.gd:185,501,847` | `FORMAT_VERSION`, required-key set, unknown-version refusal | Move with the measured version and hard refusal of v14 |
| `test/integration/test_rig_clips.gd` `EXPECTED_LOOP` | Clip count 27 -> 29 | Add `cast` and `dizzy` as one-shots |
| `test/integration/test_hero_reaction_clips.gd` (`:164-165` pin `[ORDINARY, 0.4, &"stunned"]`) | Stun-flavor scoping gains a third flavor (`6-5c/R16`) | Extend, do not weaken |
| `test/integration/test_defense_reactions_live.gd` (`:17-22` stun scenario list) and `test_counter_reactions_live.gd` | Both pin the `stunned`/`hit_react` clips; the live scenario list must grow with the flavor enum | Add the bolt-stun scenario; existing scenarios unedited |
| CONDITIONAL: `test/state/test_intent_recorder.gd:160,205` | INTAKE/EGRESS classification (`egress == ["debug_window_ticks_remaining", "hit_landed_was_blocked", "to_snapshot"]`) | Predicted green (no new parametered public `MatchState` method); if one is added it needs a capture channel or a named exemption |
| CONDITIONAL: `test/state/test_debug_window_countdown.gd:26-63` | Exact-dict payload assertions (`{&"windup": 3}`, `{}` for idle) | Predicted green (the accessor lists only RUNNING windows and no scenario there casts or roots); breaks all six if a zero/absent key is emitted unconditionally |
| MUST STAY GREEN: `test/state/test_unblockable_defense.gd::test_the_cast_introduces_no_action_state_of_its_own` | The guard `match_state.gd:1467` names for the window-derived busy-lock precedent | Unedited (`6-5c/R18`); a new `ActionState` would break it |

1. **Measure first.** Full suite and the golden baseline saved outside the repo (Golden Prediction).
2. **Data and schema** (AC 1, 2, 20-22): flat `CardEffect` fields, `data/effects/honed_bolt.tres`, resolver
   cast classification and the `DEFERRED_EFFECT_OWNERS` row leaving, authoring-audit test.
3. **Cast window** (AC 1-9, 23, 24): cast countdown/identity on the caster, pre-spend seat, the commitment
   locks at `_resolve_actions`/`_resolve_movement`/`_resolve_card_action`, interrupt-by-stun, reset/freeze,
   debug-accessor entry. Boundary tests for AC 3.
4. **The strike** (AC 10-16): enemy-hero target, i-frame dodge with the seat-symmetric observation and its
   four-case two-seat boundary test, no-block/no-deflect, funnel + lifesteal, `hit_landed`, lethal path.
5. **Stun and stacking** (AC 14-16): the new authored STUNNED write (and its guard update), interrupts of
   swing/block/chargeup/cast, floor rule, ordinary-stun restart, knockdown escalation over a bolt stun.
6. **Root** (AC 17-19): the root window, run/roll refusal with independent switches, the repeat-landing
   switch A/B, "root removes exactly run and roll" tests.
7. **Replay** (AC 23): a recorded bolt match replays to the identical hash; `FORMAT_VERSION` per measurement.
8. **Clips and tools** (AC 29): `tools/add_paladin_cast_clips.gd` (name per the dev pass) baking `cast` and
   `dizzy`; a headless raise-frame measurement tool on the `tools/measure_*_strike_frames.gd` method;
   headless import of the two FBXs; `test_rig_clips` update.
9. **Presentation** (AC 25-28): cast pose time-scaled from the authored duration, sky-to-target bolt whose
   arrival equals the strike tick, target warning marker + sound, dizzy pose, root marker; the integration
   test pinning arrival to the strike tick.
10. **Test repairs**: apply every row of the table above, one edit per row.
11. **Golden isolation and mutation proofs** (Tier A ritual): each cause isolated both directions; every new
    guard proven non-vacuous by a mutation restored from an out-of-repo copy (never `git checkout --`).
12. **Live smoke** (operator), then the close-out chain per the story-tier policy.

## Open Questions (all closed by the readiness gate; the one left to the dev pass is 8)

1. **Card play during the caster's own cast.** CLOSED, `6-5c/R6`: no card of any mode, the colour counter
   included; refused with an announced reason for the whole cast.
2. **Does an unanswered unblockable landing cancel a cast?** CLOSED, `6-5c/R7`: yes, through its knockdown.
3. **Do get-up i-frames also dodge the bolt?** CLOSED, `6-5c/R8`: yes, via the `_iframe_open_at_step3` latch.
4. **Strike-tick fairness.** CLOSED, `6-5c/R8`: the same step-3 seat-symmetry latch the unblockable rung
   uses, so a same-tick roll press dodges on neither seat (AC 11).
5. **A bolt on a hero already knocked down.** CLOSED, `6-5c/R9`: damage only, no stun, no root.
6. **How presentation learns "this stun is a bolt stun".** CLOSED, `6-5c/R10` + `R16`: a third stun flavor
   computed by the runner from post-`advance()` state, no new signal or seam; the discriminator is the dev
   pass's to choose within the R16 constraint.
7. **`card_cast_resolved` and the resolved-card record at press or at strike.** CLOSED, `6-5c/R17`: at the
   press.
8. **`dizzy.fbx` length vs the 0.4 s window.** `held_clip_speed` speeds a longer clip up to fit the hold;
   a Dizzy Idle sped up several times may read badly. Presentation-only; the dev pass measures the clip and
   the operator judges it at smoke (`PROC/R8`). Cutting or easing it (a sub-range rather than a several-times
   speed-up if the measurement is bad) is presentation's call. OPEN to the dev pass, by design.
9. **Bloodlust and Vampiric Aura on the bolt.** CLOSED, `6-5c/R13`: both apply; the bolt uses the funnel.
10. **Field names** for the cast duration, the damage, and the repeat switch. CLOSED, `6-5c/R19`.
11. **Roll refusal reason and cue.** CLOSED, `6-5c/R14`: silent, no cue, no `action_rejected`.
12. **Window-derived vs new `ActionState`.** CLOSED, `6-5c/R18`: window-derived.

## Dev Notes

- **Read before touching:** `match_state.gd` -- `advance()` (`:588`), `_resolve_actions` (`:1321`),
  `_try_transition` (`:1489`), `_funnel_damage` (`:2537`), `_resolve_card_action` (`:3097`),
  `_resolve_basic_cast` (`:3179`), `_apply_card_effect` (`:3324`), `_board_refusal_reason` (`:3601`),
  `_apply_landing_packages` (`:4303`), `_resolve_movement` (`:4819`+); `hero_state.gd` (windows, `stun`,
  `is_iframe_open`); `player_state.gd` (windows, timed rules); `card_effect.gd`,
  `card_effect_resolver.gd`; `animation_controller.gd` (`_play_stun`, `_COUNTER_PRESENTATION`, the runner-fed
  one-shot shapes); `match_runner.gd` (`_stun_flavor_for_slot` and the runner-computed forwards).
- **The stun write** must reproduce what the existing entries do around it: `stun.start(ticks)` then
  `set_action_state(STUNNED)`, abandoning a chargeup as `_apply_landing_packages` does (`was_charging` ->
  `charge_window`/`landing_window` cleared, `charge_color` reset). One `set_action_state` per outcome (the `5-6`
  rule). A hero with an active defense window is protected by the existing STUNNED gate in
  `_counter_color_of`.
- **Seat order matters.** Card presses resolve at step 6, after step 3; a cast pressed on tick T cannot be
  seen by tick T's step 3. The strike must land inside `advance()` on a well-defined step, and the
  dodge observation must read the `_iframe_open_at_step3` latch itself (`6-5c/R8`) for both seats (the
  same seat-dependence problem that latch exists for), not `is_iframe_open()`.
- **Mechanism the ACs deliberately leave here.** (1) The cast classification lives in the resolver, the one
  place `effect_id` strings meet gameplay meaning (D6); the framework names no card. (2) The caster's
  movement is a LITERAL zero (`5-2/R5`: a tunable "rooted" is not rooted), and its locked action presses
  are dropped silently at `_resolve_actions` on the get-up (`:1451`) / counter (`:1469`) precedent; the card
  press is refused in `_resolve_card_action` with an announced reason. (3) Presentation timing: MEASURE the
  `cast` clip's raise frame with a committed headless tool on the `tools/measure_*_strike_frames.gd` method
  and time-scale the clip from the runner-fed authored duration (the `4-3d` strike-alignment principle).
  (4) Clips: `tools/add_paladin_cast_clips.gd` (name per the dev pass) bakes `cast` and `dizzy` into
  `paladin_anims.res` on the `tools/add_paladin_*.gd` precedent, both one-shots, `.import` files generated
  headlessly. (5) Which new members are hashed follows the standing rule (crosses ticks and decides an
  outcome -> hashed) and is proven by isolation measurement (Golden Prediction, Task 11).
- **Bolt-stun discriminator (`6-5c/R16`).** "Stun running AND root armed" is NOT sufficient: a rooted hero
  may still swing, be deflected and enter an ORDINARY stun while its root is armed. Use a fact only the
  bolt's own stun write sets and the stun's exit clears, and test the rooted-hero-deflect-stunned case
  (it must stay `stunned`).
- **Why a casting hero cannot colour-counter (`6-5c/R15`).** The cast is a commitment and timing decides:
  the cast is 0.8 s, an unblockable chargeup 1.0 s. A bolt started first lands first and its stun breaks
  the charge; a charge started first is visible, and the player should not start a cast into it.
  Consequence to recognise, not to "fix": casting into a live unblockable chargeup loses the cast (`R7`)
  with no counterplay for the caster.
- **Presentation reads, never decides** (HARD RULE). The bolt's arrival is timed FROM the state's strike
  tick; nothing an animation callback does changes an outcome. The runner is the only `_physics_process`
  (F1); no new `Input.*` (D3(a)).
- **Assets are prerequisites already in the tree** (untracked): `assets/characters/paladin/cast.fbx`,
  `dizzy.fbx`. The dev pass imports them headlessly (the editor is the one tool this project will not open,
  `3-0a/R3`) and commits them with their `.import` files; `git status` must show no other collateral
  (`project.godot`, `main.tscn`).
- **Commit hygiene** (CLAUDE.md): docs and code never share a commit; ASCII messages via
  `git commit -F <tempfile outside the repo>`; explicit paths; show the diff before staging; never push
  until the operator confirms the log. Tier A = full gate + review + live smoke ritual.

### Project Structure Notes

Expected touch set (indicative, not a mandate): `src/state/resources/card_effect.gd`,
`src/state/economy/card_effect_resolver.gd`, `src/state/hero_state.gd`, `src/state/player_state.gd`,
`src/state/match_state.gd`, `src/state/timing/balance_ticks.gd` (only if a shared conversion belongs there),
`src/systems/record_file.gd`, `data/effects/honed_bolt.tres`, `src/actors/hero/animation_controller.gd`,
`src/actors/hero/telegraph_controller.gd` and/or new presentation actors, `src/main/match_runner.gd`,
`src/actors/hero/hero.tscn`, `assets/characters/paladin/paladin_anims.res` + the two `.import` files,
`tools/` (clip assembly + raise-frame measurement), new `test/state/` and `test/integration/` files, and the
test files in the table. New folders are not expected; one would be a codebase-shape choice to ask about.

### Project Context Rules (extracted from `docs/project-context.md`)

- State/visual separation is a HARD RULE: animations, VFX and audio never decide state; contact/timing
  facts flow visual <- state.
- A1: integer ticks via `TimingWindow`, one tick per `advance()`, never a float accumulator; convert
  authored seconds to ticks once at the point of application.
- D3/A2: no `Input.*` outside `src/controllers/`; no global RNG, `Time`, `OS` or `Engine` in `src/state/`;
  `advance()` takes no `delta`. F1: one `_physics_process`, in `match_runner.gd`.
- D5: signals raised in `advance()` are queued and drained after it; state changes reach the HUD through
  signals, never polling. CONSTRAINT C: never cache `balance`/`balance_ticks`; read inline.
- Never hardcode balance or content; feature layers degrade gracefully when their flag is off.
- Data as Resources: content is `.tres`; new content should be addable with zero code changes wherever
  the spec says data-defined. Static typing everywhere; `snake_case` files, `PascalCase` classes.
- Tests: state layer headless with fixed integer ticks; load real `.tres` for authored content; golden
  isolation (`BC/R3`) covers `data/balance/*.tres` VALUES only, not new seats or refusable actions (`SC/R6`);
  mutation proofs restore from an out-of-repo copy; text fit is never machine-asserted (`PROC/R8`).
- Commit trailer, ASCII messages and the Git discipline in `CLAUDE.md` bind.

### References

- Scope: scope talk 2026-09-25 (operator); `docs/planning-artifacts/deck-1-spec.md` (card 6, Presentation,
  balance risk 2); `docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md`, `decision-log.md`.
- Precedents: `docs/implementation-artifacts/6-5a-spell-framework-and-buffs.md`,
  `6-5b-corpses-and-own-minions.md` (format and gate/pre-spend rules), `6-6a-defense-reactions.md`
  (`R-STUNSTACK`, `R-IFRAME-UNBLOCKABLE`, get-up lock), `6-6b-color-counters.md` (busy window, counter
  clips), `4-3d-minion-strike-alignment-and-corpse-lifecycle.md` (strike alignment), `5-6` (stun).
- Code: `src/state/match_state.gd`, `hero_state.gd`, `player_state.gd`, `economy/card_effect_resolver.gd`,
  `resources/card_effect.gd`, `timing/balance_ticks.gd`, `src/systems/record_file.gd`,
  `src/actors/hero/animation_controller.gd`, `tools/add_paladin_defense_reactions.gd`,
  `tools/measure_counter_strike_frames.gd`.
- Docs: `docs/game-architecture.md` (D2/D5/A1/F1), `docs/project-context.md`.

## Dev Agent Record

### Agent Model Used

(to be filled by the dev pass)

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Author | Change |
|---|---|---|
| 2026-09-25 | Claude Sonnet 5 (gds-create-story, main session, no subagents) | Story authored against d6d5602 from the scope talk 2026-09-25. Status `authored`; board entry stays `backlog`. NOT cleared for a dev pass. Nothing committed. |
| 2026-09-25 | Claude Sonnet 5 (fix + promote pass, main session, no subagents) | Readiness gate (`_65c-gate.md`: 4 blocking / 4 major / 7 minor) applied without a second gate round; rulings `6-5c/R1`..`R19` recorded in the decision-log; Open Questions closed; broken-test table +5 rows; smoke steps 15-17 added. Status `ready-for-dev`. |

Story 6-5c-hero-cast-honed-bolt is ready-for-dev (Tier A).
