---
baseline_commit: d6d5602d40fddbd24b3e442b78060dcc3c320659
---

# Story 6.5c: Hero Cast Framework and Honed Bolt

Status: review

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

### Live Smoke result (operator, 2026-09-25)

Two pads, flip config `Array[int]([3, 3])`. **ALL checks PASS:**

- Visible cast and commitment; target warning marker + sound for the whole cast.
- Precise roll dodges; block and deflect do not.
- Hit = 4 damage, dizzy stun, root ~2.5 s (no run, no roll, silent roll).
- Dizzy vs stunned poses read as distinct.
- An ordinary hit does not interrupt a cast; stun and unanswered-unblockable knockdown do (no bolt falls).
- A held block drops when the cast starts.
- A second bolt during the root re-stuns and extends it.
- Get-up dodges.
- Bloodlust doubles the bolt and Vampiric Aura heals from it.
- Regression clean; the round ends normally on a hero death -> **R-D6 SPENT**; fps stable.

Operator note: the bolt, cone, ring and alarm are placeholders -> a Tier B presentation story after 6-5f.

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

Dev pass: **Claude Opus 5 (1M context)** — the model shown in the operator's picker for this session.
Main session only, no subagents, no forks, no parallel sessions. Nothing committed or staged.

### Debug Log References

Suite and measurement outputs, all written OUTSIDE the repo:

| File | What it holds | Timestamp |
|---|---|---|
| `C:\dev\_65c-suite-1-state.txt` | before-baseline state harness (written before the first edit) | run 1 |
| `C:\dev\_65c-suite-1-integ.txt` | before-baseline integration (68 files) | run 1 |
| `C:\dev\_65c-golden-iso-A-nokeys.txt` | golden ISOLATION: all three new snapshot keys erased | iso A |
| `C:\dev\_65c-golden-iso-B-cast.txt` | golden ISOLATION: `cast` restored alone | iso B |
| `C:\dev\_65c-golden-iso-C-cast-root.txt` | golden ISOLATION: `cast` + `root` | iso C |
| `C:\dev\_65c-golden-iso-D-all.txt` | golden ISOLATION: all three restored (reproduces dev-2) | iso D |
| `C:\dev\_65c-dev-1..8.txt` | development runs (state harness only) | — |
| `C:\dev\_65c-suite-2-integ.txt` | integration after the state-layer work | 14:08:49 |
| `C:\dev\_65c-mut-M1..M14.txt` | one file per mutation proof (14 mutants) | — |
| `C:\dev\_65c-mutants\*.pre` + `*.sha` | every mutant's pre-mutation copy and SHA256 | — |
| `C:\dev\_65c-import.txt` | the headless `--editor --quit` FBX import scan | 14:44 |
| `C:\dev\_65c-measure-clips.txt` | the `cast` raise frame / `dizzy` fit measurement | — |
| `C:\dev\_65c-suite-final-state.txt` | state harness, end of pass 1 | 14:53:52 |
| `C:\dev\_65c-suite-final-integ.txt` | integration, end of pass 1 | 14:58:35 |

**PASS 2 (presentation: AC 25 second half, AC 26, AC 28), 2026-09-25.** The tree was UNCHANGED
between the two passes (`git status --short` at pass 2's start matched pass 1's File List exactly,
23 modified / 8 untracked, HEAD = origin/main = `6a4158c`), so **pass 1's final runs above are pass
2's BEFORE-BASELINE** and no fresh baseline run was taken.

| File | What it holds | Timestamp |
|---|---|---|
| `C:\dev\_65c-import2.txt` | headless `--editor --quit` scan run mid-pass (new `class_name BoltActor` had to reach the class cache before `match_runner.gd` would compile) | pass 2 |
| `C:\dev\_65c-mut-M15..M21.txt` | one file per mutation proof (7 mutants) | pass 2 |
| `C:\dev\_65c-mutants2\*.pre` + `*.sha` | pre-mutation copies + SHA256 for the two files pass 2 mutates | pass 2 |
| `C:\dev\_65c-suite-final2-state.txt` | **final state harness** | **15:19:49** |
| `C:\dev\_65c-suite-final2-integ.txt` | **final integration (69 files)** | **15:24:49** |
| `C:\dev\_65c-import3.txt` | the FINAL `--editor --quit` `.uid` scan | pass 2 |

**Machine-time budget (`PROC/R7` / `E5-R/R3`).** First before-baseline `13:14:01` -> last suite of
the WHOLE dev pass `15:24:49` = **130.8 min**, which is the FULL interval across BOTH passes and
INCLUDES the operator pause of **15m24s** (`14:08:49` -> `14:24:13`) inside pass 1, per the
operator's instruction that the pause counts, plus the operator gap between pass 1's last suite
(`14:58:35`) and pass 2's start. The interval covers the dev pass only; review is still to come, so
the story cycle is not closed and this figure is not the close-out number.
| `C:\dev\_65c-backups\*.bak` | pre-edit copies taken before each byte-level replace | — |
| `C:\dev\_65c-iso\*.pre` | pre-isolation copies + SHA256, used for copy-back restore | — |

**Suite cadence (`PROC/R1` disclosure).** The before-baseline was a full run (state + integration).
Beyond it, the STATE HARNESS ALONE was run repeatedly and is reported rather than absorbed:
**8 development runs** (two of which cost a 600 s timeout to the known parse-error HANG) and
**4 golden-isolation runs**. The integration half was run **once more** (`_65c-suite-2-integ.txt`), with
the stated reason that this pass changed two seams integration reads — `hero.stun.start` became
`HeroState.start_stun` and `_running_window_ticks` took a `PlayerState` — and that had to be checked
before reporting.

**PASS 2 cadence (`PROC/R1` disclosure), reported rather than absorbed.** Beyond the ONE final run
(state + integration, above), pass 2 ran: **1 run of the new integration file alone** to see it go
green, **7 mutant runs of that same file alone** (one per mutant, foreground, one at a time), **1
targeted batch of the 8 integration files most exposed to the `hero.tscn` edit** (`test_cast_
presentation_live`, `test_vertical_alignment`, `test_hero_reaction_clips`, `test_rig_clips`,
`test_defense_reactions_live`, `test_counter_reactions_live`, `test_orb_cue_live`,
`test_cast_success_cue_live` — all PASS), and **2 `--editor --quit` scans** (one mid-pass for the
class cache, one final for `.uid`s). The state harness was run **exactly once**, as the final run:
this pass changed no file under `src/state/` and no state test, so a mid-pass state run had nothing
to tell it. **Known flake `6-5b/R24` did not appear** in any pass-2 integration run.

### Mutation proofs (Task 11, second half)

FOURTEEN mutants, one at a time, each run FOREGROUND against the whole state harness (the harness
carries no per-file filter, the 6-5b finding). Every mutant was applied with the Edit tool, and every
restore was a **copy-back from `C:\dev\_65c-mutants\<file>.pre` with a SHA256 match verified against
the stored `.sha`** — never `git checkout` (the standing protocol). **All 14 killed; no guard
survived its mutant, so none needed strengthening.**

| # | Mutant | File | Guard it targets | Result | Restore SHA256 verified |
|---|---|---|---|---|---|
| M1 | delete the bolt's `set_action_state(STUNNED)` | `match_state.gd` | `test_action_state` x4 pin (`6-5c/R11`) — the story's own named mutation | RED (4 tests) | `C77D02DE…81B3` ✓ |
| M2 | latch -> bare `is_iframe_open()` | `match_state.gd` | AC 11 / `6-5c/R8` dodge | RED (1) | ✓ |
| M3 | delete the knockdown floor | `match_state.gd` | AC 16(a) / `R-STUNSTACK` | RED (1) | ✓ |
| M4 | drop STUNNED from `_cast_is_interrupted` | `match_state.gd` | AC 5 / `6-5c/R3`, `R7` | RED (2) | ✓ |
| M5 | drop `is_root_blocking_run()` | `match_state.gd` | AC 17 run block | RED (2) | ✓ |
| M6 | delete the roll refusal | `match_state.gd` | AC 17 / `6-5c/R14` | RED (1) | ✓ |
| M7 | delete the announced card lock | `match_state.gd` | AC 8 / `6-5c/R6`, `R15` | RED (1) | ✓ |
| M8 | delete the cast movement root | `match_state.gd` | AC 8 | RED (1) | ✓ |
| M9 | delete the step-3 action lock | `match_state.gd` | AC 8 silent drop, AC 9 | RED (2) | ✓ |
| M10 | bolt stun flavour `true` -> `false` | `match_state.gd` | `6-5c/R16` discriminator | RED (2) | ✓ |
| M11 | `starts_cast()` returns true for every effect | `card_effect_resolver.gd` | AC 2 classification | RED (16) | `BF550D13…6042` ✓ |
| M12 | cast duration `+ 1` tick | `match_state.gd` | AC 3 strike tick | RED (18) | ✓ |
| M13 | delete the debug reset's cast/root clears | `match_state.gd` | AC 24 | RED (1) | ✓ |
| M14 | bypass `_funnel_damage` | `match_state.gd` | AC 13 / `6-5c/R13` | RED (1) | ✓ |

**PASS 2: SEVEN MORE MUTANTS, all MEASURED this pass, all KILLED.** Same protocol: pre-mutation copy
+ SHA256 to `C:\dev\_65c-mutants2\`, one mutant at a time, applied with the Edit tool, each run
FOREGROUND against the affected integration file alone
(`test/integration/test_cast_presentation_live.gd` — an integration file IS individually runnable,
unlike the state harness), and every restore a **copy-back with a SHA256 match against the stored
`.sha`**, never `git checkout`. `match_runner.gd` restored to `4B93DB86…70AF` and
`animation_controller.gd` to `E07E9675…E4E5` after every single one. **No guard survived its mutant,
so none needed strengthening.**

| # | Mutant | File | Guard it targets | Result | Provenance | Restore SHA256 |
|---|---|---|---|---|---|---|
| M15 | bolt flight given `total - launch - 1` ticks | `match_runner.gd` | AC 25 arrival tick == strike tick | RED (3 checks) | MEASURED | `4B93DB86…70AF` ✓ |
| M16 | warning pushed to the CASTER, not the target | `match_runner.gd` | AC 26 target-anchoring | RED (3) | MEASURED | ✓ |
| M17 | falling edge never ends the warning | `match_runner.gd` | AC 26 "both end at the strike" | RED (1) | MEASURED | ✓ |
| M18 | `_root_in_force` drops the STUNNED term | `match_runner.gd` | AC 28 / AC 17 (root starts when the stun ENDS) | RED (2) | MEASURED | ✓ |
| M19 | `on_cast_started` never pushed | `match_runner.gd` | AC 25 cast pose | RED (1) | MEASURED | ✓ |
| M20 | `set_root_marker` never pushed | `match_runner.gd` | AC 28 root marker | RED (2) | MEASURED | ✓ |
| M21 | `cast_cut_start` returns 0 (sub-range not raise-anchored) | `animation_controller.gd` | AC 25 pacing arithmetic + the launch beat | RED (4) | MEASURED | `E07E9675…E4E5` ✓ |

**M18 IS THE ONE WORTH READING.** It did not merely fail a visibility check: the marker count moved
from **150 ticks to 174**, which is exactly the authored `stun_seconds` (0.4 s = 24 ticks) leaking
into a window that spans the stun AND the root. That number is the measurement proving the marker
tracks the ROOT rather than the window the root shares with the stun — the distinction AC 17 makes
by construction state-side and AC 28 has to make again presentation-side.

**M2 PRODUCED A MEASURED CORRECTION, and it is the most valuable single result here.** The mutant
died on `test_only_the_step3_latch_dodges_the_bolt`'s **same-tick-roll** case and left
`test_get_up_iframes_dodge_the_bolt_exactly_as_roll_iframes_do` **GREEN**. That test's first draft
CLAIMED the get-up case was the one the bare predicate would miss; **measured, that claim is false at
this seat** and the comment now says so. The reason is seat-specific: the strike runs at STEP 6C,
after step 3 has already written IDLE and armed `get_up_iframe`, so the live predicate is true by
then too. `_gets_up_this_tick` is load-bearing for the UNBLOCKABLE rung, which reads at step 3
*before* that arm. What the latch is still load-bearing for HERE is SEAT SYMMETRY — a roll pressed at
step 3 opens `roll_iframe` before step 6c could read it live — and that IS mutation-proven. So
`6-5c/R8`'s "read the latch, not the predicate" stands on the ROLL case, not the get-up one. The
guard was not weakened; the false claim about WHY it is needed was corrected in place.

### Asset import and clip measurements (Task 8)

**Headless import (`3-0a/R3`, `6-1c/R4` procedure).** `godot --headless --editor --quit --path .`
generated `cast.fbx.import` and `dizzy.fbx.import`. `project.godot` SHA256 was
`9C3089BC…95E2` **before and after — unchanged**; `src/main/main.tscn` `D102CA2A…0828` **unchanged**;
`git diff -- project.godot src/main/main.tscn` EMPTY; `physics/common/physics_ticks_per_second=60`
still present. No collateral, nothing reverted. The only new untracked files are the two `.import`
sidecars and `test/state/test_hero_cast.gd.uid`.

**Clips baked** by the new `tools/add_paladin_cast_clips.gd` (the `add_paladin_counter_clips.gd`
route, library LOADED and extended, never rebuilt): **27 -> 29**, both `LOOP_NONE`.

**MEASURED, not assumed** (`tools/measure_cast_clip_frames.gd`, the `measure_*_strike_frames.gd`
method, sword-joint probe):

| Clip | Length | Hips net / peak planar | Raise frame |
|---|---|---|---|
| `cast` | **2.9667 s** | 0.0008 / 0.1561 m (ceiling 0.25) | **peak sword 1.0423 m above hips at t=1.4092, fraction 0.4750** |
| `dizzy` | **4.2667 s** | 0.0000 / 0.1338 m | n/a (no weapon beat) |

Both are in place, so **neither needed a Hips pin** (`counter_slide` needed one only because STATE
carried its body). The bake tool REFUSES to write above the `3-0b/R27` 0.25 m ceiling rather than
silently flattening a track, because neither of these clips has state-side displacement to double.

**Open Question 8 ANSWERED BY MEASUREMENT.** `dizzy` is 4.2667 s against a 0.4 s bolt stun, so the
standing hold rule would play it at **10.67x** — a flicker, not a stagger. The question left cutting
open to the dev pass and the dev pass took it: `dizzy` plays a **SUB-RANGE at NATIVE rate** from a
measured `DIZZY_CUT_START = 1.0 s` (`AnimationController._play_dizzy`). Every other flavour keeps the
unchanged `held_clip_speed` rule, so `stunned` and `knockdown` are bit-identical. Legibility itself is
the operator's at smoke (`PROC/R8`, smoke step 16). `cast` would be **3.71x** under the hold rule; the
cast pose is not wired yet (see below), so no choice has been made for it.

**Process findings worth recording.**
1. The 6-5b HANG finding reproduced exactly: a parse error in a file `run_state_tests.gd` loads makes
   the harness hang rather than fail fast. `godot --headless --check-only --script <file>` names the
   error in ~2 s and should be the first thing run after any byte-level edit. Cost two 600 s timeouts
   before that habit was adopted.
2. **PowerShell array/`-join` construction of multi-line replacement text is unsafe through this
   harness** and silently produced two different corruptions — a space-joined single line
   (`test_action_state.gd`, `match_state.gd` window list) and per-`+`-operand line splitting
   (`test_spell_framework.gd`). Both were caught, and both were repaired from out-of-repo copies or by
   line-index splice, never `git checkout`. The reliable shapes are the **Edit tool** and a
   **line-index splice** whose replacement text was written to a scratchpad file by the Write tool.

### Completion Notes List

**STATUS after PASS 2: Tasks 1-11 are DONE and green — every AC 1-29 is built. Task 12 (live smoke
+ close-out) is the operator's and is the only thing left.** Pass 1 stopped on capacity, not on a
blocker, with AC 25's second half, AC 26 and AC 28 unbuilt; pass 2 built exactly those three and
touched nothing else.

**Final suite (pass 2): state 1064 / 0 failed / 10450 assertions — UNMOVED from pass 1, as a
presentation-only pass must leave it; integration 69 / 69 (68 + the new file).** Golden unchanged at
`97d52922…` (the state harness is green against the pass-1 baseline, and nothing under `src/state/`
was touched). No `6-5b/R24` exit flake appeared in any run of either pass.

**Done (state layer, AC 1-24), all green:**

1. **Data and schema (AC 1, 2, 20)** — SEVEN flat `@export`s on `CardEffect`. Four names are the
   spec's verbatim (`stun_seconds`, `root_seconds`, `root_blocks_run`, `root_blocks_roll`); the
   **three new names this pass records are `cast_seconds`, `damage_amount`, `repeat_landing_restuns`**
   (`6-5c/R19`). `damage_amount` follows `heal_amount`; `cast_seconds` follows `slow_duration_seconds`;
   `repeat_landing_restuns` follows the two spec-fixed booleans it sits beside rather than the
   project-wide `is_`/`has_` prefix, and the reason is recorded at the field.
2. **Resolver (AC 1, 6, 21)** — `OUTCOME_HONED_BOLT`, a `CAST_OUTCOMES` table, `starts_cast()` (which
   is where the `FeatureFlags.spells` gate lives, so AC 6's degrade is structural), `NEEDS_ENEMY_HERO`
   + `CAST_REQUIREMENTS`. `honed_bolt` left `DEFERRED_EFFECT_OWNERS` (5 -> 4).
3. **Cast window (AC 1, 3-9, 23, 24)** — `cast_window` + `cast_card_id` on `PlayerState` (the
   `charge_window`/`defense_window` seating argument), `is_casting()` as the ONE predicate all three
   commitment seats read, window-derived with no new `ActionState` (`6-5c/R18`).
4. **The strike (AC 10-13)** — step **6c**, immediately after `_apply_landing_packages`, in **two
   passes**: pass one reads eligibility for both slots, pass two mutates. That split is the
   `_iframe_open_at_step3` seat-symmetry doctrine applied to a third mutual case, and without it P1
   would win every simultaneous bolt exchange by virtue of being slot 0.
5. **Stun and root (AC 14-19)** — the FOURTH authored `STUNNED` write (`6-5c/R11`, guard 3 -> 4 with
   the argument); `root_window` armed with `stun_ticks + root_ticks` as ONE window, the
   `landing_window` shape, which makes AC 17's "root starts when the stun ends" true by construction.
6. **`6-5c/R16` discriminator** — `HeroState.stun_is_bolt`, set only by the bolt's own write and
   cleared at the stun's exit. Made unforgettable by routing **every** stun write through the new
   `HeroState.start_stun(ticks, is_bolt)`, which takes the flavour as a required argument.
7. **`FORMAT_VERSION` 14 -> 15** with hard refusal of v14 and a v14 refusal test.

**Two real defects the new tests caught, both in this pass's own code:**
* **The step-2 tick was missing.** `cast_window` / `root_window` were created, started, read and
  snapshotted but never advanced, so every cast hung forever. Twenty tests went red on it. Fixed.
* The i-frame/get-up dodge test's arithmetic was wrong (a negative `_idle`), which would have made
  `6-5c/R8`'s whole point pass vacuously.

**Design decisions made (implementation, not design — recorded for review):**
* The in-flight cast is identified by its **card id as a `String` VALUE**, reusing
  `last_resolved_card_id`'s measured constraint. This needed a **SECOND exemption** in
  `test_card_effect_resolution.gd`'s counts-only scan; the mechanism is unchanged and a note there
  records that a THIRD exemption is the signal to replace the mechanism, not extend the list
  (`3-0d/R20`).
* The root's two switches are honest `bool`s on `PlayerState`, NOT `rule_a`/`rule_b` floats on the
  timed-rule seat — that seat documents its slots as magnitudes, and a bool punned into a float would
  be a lie the snapshot then carries.
* The cast's movement root is seated **above** `ROLLING`/`ATTACKING`, diverging from the counter
  lock, because AC 8 says "does not move at all, at any tuning" in absolute terms where `6-6b` AC 1
  says the opposite for its own lock.
* Cast and root are cleared in **both** `_end_round` and `_reset_player`, following `clear_rules` /
  `clear_resolved_card` rather than the seven reset-only windows, because AC 18 and AC 24 both point
  at the timed-rule seat by name.

**Golden: ONE re-baseline, `962514b1...` -> `97d52922...`, three causes isolated and named
separately** (full arithmetic in `test_determinism.gd` at the constant):

| # | Cause | Hash after |
|---|---|---|
| — | before-baseline | `962514b1e40f95d4ebda3265bc85e48a6321209b6e064b2a43332964644136b9` |
| A | **all three keys erased, every other change in place** | `962514b1...` — **exact return** |
| 1 | `cast` (per-player) | `c4f42153b36869d4905e5a322dce8b35352c841175a7ff444fd2f14ed32ce3fa` |
| 2 | `root` (per-player) | `8736d846b6fb2432c319028e256945d8cf18b712f72ddc5798b5f0061a6c64ed` |
| 3 | `stun_is_bolt` (HERO) | `97d52922e4e6282b37582e8c3a9c424a02337162881c37a7f6a3394277efdc92` |

Run A is the measurement that discharges four predicted causes at once: the new refusable outcomes
(prediction cause 4), the authored `.tres` numbers and the seven new `CardEffect` defaults — the live
0.8 `cast_seconds` included (cause 5), the `FORMAT_VERSION` bump (cause 6) and intake (cause 7) are
**all MEASURED non-movers**, not assumed ones. The prediction deliberately refused to say which pin
the root would move; **measured, it is the PER-PLAYER one** (36 -> 38), and the discriminator moved
the HERO one instead.

**Done since (Tasks 8, 11, and AC 27):**

8. **Clips and tools (AC 29)** — both FBXs imported headlessly with no collateral, baked 27 -> 29 by
   the new `tools/add_paladin_cast_clips.gd`, measured by the new
   `tools/measure_cast_clip_frames.gd`, and `test_rig_clips.gd`'s `EXPECTED_LOOP` moved 27 -> 29 with
   both loop flags pinned `false` and the `dizzy` one-shot DECISION argued at the pin.
9. **AC 27 (the `6-5c/R16` consumer)** — `STUN_FLAVOR_BOLT`, `_play_stun` -> `dizzy`,
   `_play_dizzy`'s measured sub-range, and `match_runner._stun_flavor_for_slot` reading
   `stun_is_bolt` through the EXISTING seam: **no new signal, no new seam, no new intake**, which is
   what R16 requires. `test_hero_reaction_clips.gd` EXTENDED (never weakened) with the bolt case
   beside the untouched 0.4 s ORDINARY row whose duration it collides with.
   * **A real ordering defect was found and fixed here.** `_apply_honed_bolt` pushed `hit_landed`
     BEFORE the stun write, so the runner would have seen an IDLE-family target and played
     `hit_react` over the dizzy pose — which AC 27 forbids by name. `_apply_landing_packages`
     establishes the opposite order for exactly this reason; the bolt now matches it.
11. **Mutation proofs** — 14 mutants, all killed, table above; plus the M2 correction.

**PASS 2 — the three remaining presentation ACs, built (Task 9 completed):**

12. **AC 25 (second half): THE CAST POSE.** `AnimationController.on_cast_started(cast_seconds)` /
    `on_cast_ended()`, claimed through the per-tick locomotion push exactly as the counter claims
    the body (`_cast_running` / `_advance_cast`, the cut's end held as a pause). The cast owns no
    `ActionState` (`6-5c/R18`), so a casting hero is IDLE and hard-rooted and that push is reached
    on every tick of the window. The cast and the counter can never both claim it: a casting hero is
    refused every card press including the counter (`R6`/`R15`), and a countering hero's presses are
    refused by `REASON_COUNTERING`.
13. **AC 25 (second half): THE BOLT.** `src/actors/props/bolt_actor.gd` — `DaggerActor`'s precedent
    (script, no `.tscn`, no hitbox, no board entry, no `push_contact`, no `_physics_process`) with
    ONE deliberate divergence: **it counts TICKS where the dagger counts seconds.** AC 25 pins this
    prop's arrival to the strike TICK, so the flight is an integer count and cannot drift a tick on
    accumulated float error. Two legs: sword -> apex above the target -> down onto the target, with
    the apex recomputed from the target's LIVE position each tick (honest, because the state-side
    bolt cannot miss). An arrived bolt is freed one tick LATE, so the landing frame is actually
    drawn — and so the AC 25 test can observe the arrival at the instant `hit_landed` drains.
14. **AC 26: THE TARGET-SIDE WARNING.** `TelegraphController.on_cast_warning_started/ended` driving
    a new `CastWarning` above-head cone and a new `CueCastWarning` player, both SIBLINGS of
    `HitFlash` rather than children of `$Shapes` (`OrbFlash`'s stated reason: every transition hides
    `$Shapes`, and a target that rolls or blocks during the cast transitions constantly). The sound
    is generated by the new committed `tools/gen_cast_warning_audio.gd` on the
    `tools/gen_charge_audio.gd` precedent, and it **LOOPS** — the one design point worth naming: a
    fixed-length one-shot would either outlast a short cast or fall silent inside a long one, and
    the cue's length is authored data the generator must not learn. Distinct by ear by construction:
    every existing cue is a single 0.18 s tone at 320-880 Hz, this is a repeating 260 -> 190 Hz
    two-pulse alarm.
15. **AC 28: THE ROOT MARKER.** A `RootMark` ring at the feet, pushed LEVEL-TRIGGERED every tick
    from `_root_in_force(player)` = `root_window.is_running and not STUNNED and not DEAD`. Level,
    not an edge pair, deliberately: a root ends by expiry, the debug reset or a death, and an
    edge-driven marker can be stranded by whichever of those nobody remembered to push. The STUNNED
    term is what makes AC 17's "the root starts when the stun ends" true on screen as well as in
    state, since `root_window` spans both (M18 measures it: 150 marker ticks vs 174 without).
16. **One runner poll, one seat** — `_push_cast_presentation()` at step **3a-quater**, immediately
    after the counter poll, reading the `cast` and `root` facts right after `advance()`. **NO new
    signal, NO new seam, NO new intake** (`6-5c/R16`): the observation-seam family stays at TEN, and
    the story's "STOP and report if a presentation piece needs a state change" clause was never
    reached — nothing under `src/state/` was touched this pass.

**THE CLIP-PACING CHOICE (AC 25), made on the measured numbers and recorded as the story asks.**
`cast` is **2.9667 s** long with the raise (peak sword above Hips, 1.0423 m) at **t=1.4092**,
**fraction 0.4750**; the authored cast is **0.8 s**.
* The **hold rule** (`held_clip_speed`) would play the whole clip at **2.9667 / 0.8 = 3.7083x**. A
  sword raise at nearly 4x is a twitch, and AC 26/smoke step 4 need the opponent to READ that raise
  and time a roll against it. Rejected for the same reason the same rule was rejected for `dizzy`
  at 10.67x one pass earlier — the precedent the operator named.
* **TAKEN: a SUB-RANGE at NATIVE rate (1.0x)**, `dizzy`'s precedent. The window is placed so the
  raise sits at the clip's OWN proportion of it (`CAST_RAISE_FRACTION` = 0.4750), i.e.
  **[1.0292, 1.8292]** of the clip for an 0.8 s cast. The launch therefore fires **0.38 s** into the
  cast, ON the raise beat, leaving **0.42 s** of sky-to-target fall (25 ticks of the 48).
* **THE RETUNE CLAUSE IS STRUCTURAL, not promised.** Both numbers are functions of the authored
  duration (`cast_cut_start` / `cast_launch_seconds`), and every tuning up to the clip's full
  2.9667 s fits inside the clip without clamping; beyond that the range clamps to the clip and holds
  the final frame, `_play_stun`'s own degrade. The integration test reads `cast_seconds` LIVE from
  `data/effects/honed_bolt.tres`, so it re-times with a retune instead of pinning 0.8.
* **Legibility itself is the operator's at smoke** (`PROC/R8`, smoke steps 1, 3, 7).

**A measured harness finding worth keeping.** `AnimationPlayer` advances on the IDLE frame, not the
physics tick, so headlessly a held cut reaches its pause early — and a PAUSED player reports an
empty `current_animation` while `assigned_animation` still names the held clip. The pose assertion
reads `assigned_animation` for exactly that reason (`_advance_counter` states the same fact about a
finished `LOOP_NONE` clip; this is the second way to reach it).

**STILL THE OPERATOR'S — Task 12.** No live smoke, no close-out, no decision-log entry, no
`deck-1-spec.md` dated amendment (owed by the close-out per Discrepancy 5). Nothing is committed or
staged by either pass.

### Review fix pass (2026-09-25, main session, no subagents, nothing committed)

Work list: `C:\dev\_65c-review.md` (0 blocking / 3 major / 8 minor), every cited location verified BY CONTENT
before editing. Before-baseline: the dev pass's final runs (`_65c-suite-final2-state.txt` / `-integ.txt`), tree
verified unchanged since (`HEAD == origin/main == 6a4158c`, 26 modified + 17 untracked, no godot process).

**Findings applied**

| Finding | What changed | Proof |
|---|---|---|
| M2 | `_resolve_basic_cast`'s cast arm drops a running BLOCKING to IDLE on the same tick (`6-5c/R4`), mode 3's pattern; BLOCKING-only, ATTACKING/ROLLING untouched | `test_a_held_block_does_not_survive_the_start_of_a_cast`: block + bolt pressed on ONE tick, block held throughout, never BLOCKING for any tick of the cast, full damage from a hit during it; CONTROL (same block + same contact, no cast) IS mitigated. **M22** |
| M1 | `test_a_record_containing_a_bolt_replays_to_the_identical_hash` in `test_record_file.gd` (the fixture gained `bolt`/`spells` parameters, defaults leave every other test unchanged): a real `card_commit` press, run ending MID-CAST and run ending AFTER the strike, each replayed in memory and from the saved-and-reloaded file to the identical canonical hash; live non-vacuity asserted first | **M27** |
| M3 | `test_the_strike_seat_is_slot_symmetric`: P2 casting alone (the slot-1 mirror) and BOTH casting on one tick (both hit, both bolt-stunned, both rooted, both casts cleared, two `hit_landed` in P1-then-P2 order) | **M23** (fused passes) |
| N1 | TAB residue in the `match_state.gd` comment restored to `true` | content search |
| N2 | the runner frees the bolt on the falling edge when the caster reads STUNNED/DEAD, even if the prop already ARRIVED; new `test_cast_interrupt_live.gd` finds the strike tick ordering-free (`cast_window.remaining_ticks() == 1`) and stuns the caster there | **M28** |
| N3 | `_reset_player`'s comment now names the DEBUG RESET as the reason for its clear. **AC 5's text is NOT edited.** Actual behaviour, for the close-out log: **round end CLEARS the cast** (and the root) via `_end_round` — strictly stronger than "the freeze freezes it"; the freeze never holds a live cast | comment only |
| N4 | `test_start_stun_is_the_only_writer_of_the_stun_window`: source scan, exactly one `stun.start(` in `src/`, inside `start_stun` | **M25** |
| N5 | `test_a_knockdown_over_a_bolt_stun_clears_the_discriminator_and_leaves_the_root` (AC 16(c)); the knockdown is poked as a knockdown-length `start_stun(…, false)` like AC 16(a)'s test, not driven through an unblockable | **M26** |
| N6 | `test_a_knockdown_landing_at_6b_cancels_the_cast_on_its_strike_tick`: the package latch is set for the tick whose 6c would strike (`_landing_package_pending` poke — the precedent in `test_counter_reactions_live.gd`) | **M24** (6b/6c swapped) |
| N7 | File List reconciled (Docs heading, new integration file, test count 43 -> 48) | — |
| N8 | **ACCEPTED, no action, per the operator's ruling.** No single test spans press -> presentation; the press seat is proven headlessly and the presentation with a poked arm, and the composition is left to smoke step 1 | — |
| N9 | **MEASURED, bit-identical.** HEAD's `paladin_anims.res` was extracted with `git show` to a scratchpad path outside the repo and compared to the working copy: **all 27 pre-existing clips identical** (length, loop mode, step, track count, and per track type/path/interpolation/enabled and every key's time, value and transition), `stunned` (0.7 s, 53 tracks) and `hit_react` (0.9667 s, 53 tracks) included; the only difference is the two added clips, `cast` and `dizzy` (27 -> 29). Comparison script is scratch, not committed: it is against a moving HEAD, so it is a one-time measurement, not a durable test | measured |

**Mutation proofs, pass 3 — SEVEN more, all MEASURED, all KILLED.** Protocol: pre-mutation copy outside the repo
(`C:\dev\_65c-fixbak\`) with SHA256 recorded, one mutant at a time, applied with the Edit tool, run
FOREGROUND against the affected file alone (state files through a scratch single-file runner kept in the
scratchpad, NOT in the repo; the integration file directly), restored by copy-back with the SHA256 verified
each time, never `git checkout --`.

| # | Mutant | File | Guard it targets | Result | Provenance |
|---|---|---|---|---|---|
| M22 | cast arm's block-drop replaced by `pass` | `match_state.gd` | M2 `test_a_held_block_does_not_survive_the_start_of_a_cast` | RED (27 asserts) | MEASURED |
| M23 | the two 6c passes fused into one (strike inside pass one) | `match_state.gd` | M3 `test_the_strike_seat_is_slot_symmetric` | RED (4) — the P2-alone half stays green, as it should; only the simultaneous half can tell the loops apart | MEASURED |
| M24 | `_apply_landing_packages()` moved AFTER `_resolve_cast_strikes()` | `match_state.gd` | N6 `test_a_knockdown_landing_at_6b_cancels_the_cast_on_its_strike_tick` | RED (1); the pre-existing tests all stayed green, which is the gap N6 named | MEASURED |
| M25 | the deflect seat writes `attacker.hero.stun.start(…)` directly | `match_state.gd` | N4 `test_start_stun_is_the_only_writer_of_the_stun_window` | RED (1) | MEASURED |
| M26 | `start_stun` sets `stun_is_bolt = stun_is_bolt or is_bolt` (flag never cleared by a non-bolt stun) | `hero_state.gd` | N5 `test_a_knockdown_over_a_bolt_stun_clears_…` | RED (1) | MEASURED |
| M27 | `_resource_values` skips `cast_seconds` | `record_file.gd` | M1 `test_a_record_containing_a_bolt_replays_to_the_identical_hash` | RED (2, both SAVED-AND-RELOADED halves; the in-memory halves stay green because the record holds the effect objects, so the FILE is the seam this test measures) — the pre-existing `test_the_recorded_effect_row_carries_every_cast_field` also reds | MEASURED |
| M28 | runner's N2 clause disabled (`false and interrupted`) | `match_runner.gd` | N2 `test_cast_interrupt_live.gd` | RED (`bolt_after_end=1`) | MEASURED |

Restore SHA256, every mutant: all seven matched their stored value — `match_state.gd` x4 `111ACFD1…15D0`,
`hero_state.gd` `0CD59877…D5C9`, `record_file.gd` `310E84D4…B158`, `match_runner.gd` `7DD3E19C…2488`
(full values in `C:\dev\_65c-fixbak\cur.sha`).

**Golden, MEASURED IN BOTH DIRECTIONS — UNMOVED.** M2 changes no snapshot KEY and no recorded shape, and it
changes a VALUE only for a hero that is BLOCKING at the instant it casts, which no golden fixture does.
`test_determinism.gd` alone: M2 ON 21/0/94, M2 OFF (M22's mutant) 21/0/94, `GOLDEN` `97d52922…` in both. No
re-baseline was made. `FORMAT_VERSION` stays 15 and the snapshot key sets stay put (the pins in
`test_card_observation.gd` / `test_draw_delay_and_reshuffle.gd` / `test_debug_window_countdown.gd` are green
unedited).

**Suite** — ONE final run, two separate foreground calls, tree verified unchanged between them:
- state: `C:\dev\_65c-suite-fix-state.txt`, 2026-09-25 16:20:07 — **1070 tests, 0 failed, 10556 assertions**
  (before 1064/0/10450: +6 tests = M1, M2, M3, N4, N5, N6; +106 assertions)
- integration: `C:\dev\_65c-suite-fix-integ.txt`, 2026-09-25 16:25:03 — **70/70 PASS** (before 69/69: +1 =
  `test_cast_interrupt_live.gd`)
- the known 6-5b/R24 flake did NOT occur, so no rerun and nothing to record.

**Not fixed, listed per instruction.** (a) Three older TAB-residue instances in files this story does not touch:
`hud_root.gd:896`, `test_unblockable_defense.gd:1011,1013`, `add_paladin_locomotion.gd:172` (the review's
"worth a sweep sometime"). (b) The commit-trailer conflict (repo constant `Claude Opus 4.8` vs this session's
harness attribution) — advisory, the operator's call at the commit chain. (c) T4's recorded-not-a-finding note
that a hero bolt-stunned on the round-ending tick keeps `stun_is_bolt` through the freeze until
`_reset_player`.

**Collateral check.** `--editor --quit` scan run once to create the new `.uid`: `project.godot` (`9C3089BC…`)
and `src/main/main.tscn` (`D102CA2A…`) SHA256 identical before and after; the only new file was
`test_cast_interrupt_live.gd.uid`.

**Extra-run disclosure (`PROC/R1`).** Beyond the one final pair: single-file state runs through the scratch
runner (`test_hero_cast.gd` x8: two red first drafts of the M2 test — the contact needed an actual swing in
flight to register — one green, five mutant runs M22-M26; `test_record_file.gd` x2: green + M27;
`test_determinism.gd` x2: M2 on and off), the interrupt integration file x2 (green + M28), one N9 comparison
run and one `--editor --quit` scan. The FULL state harness ran exactly once, as the final run.

**Budget interval.** Dev pass started 13:14:01 (see the dev-pass block); this review-fix pass's final run ended
**16:25:03**. Raw elapsed 13:14:01 -> 16:25:03 = 191 min, which spans the dev pass (ended 15:24:49), the
separate code-review session and the operator's pauses — it is the running budget end-point, not a
close-out number.

### File List

Modified:
- `src/state/resources/card_effect.gd`
- `src/state/economy/card_effect_resolver.gd`
- `src/state/hero_state.gd`
- `src/state/player_state.gd`
- `src/state/match_state.gd`
- `src/systems/record_file.gd`
- `data/effects/honed_bolt.tres`
- `test/state/test_action_state.gd`
- `test/state/test_card_authoring.gd`
- `test/state/test_card_effect_resolution.gd`
- `test/state/test_card_observation.gd`
- `test/state/test_debug_window_countdown.gd`
- `test/state/test_determinism.gd`
- `test/state/test_draw_delay_and_reshuffle.gd`
- `test/state/test_record_file.gd`
- `test/state/test_replay_identity.gd`
- `test/state/test_spell_framework.gd`
- `src/actors/hero/animation_controller.gd` (AC 27: `STUN_FLAVOR_BOLT`, `_play_dizzy`, `DIZZY_CUT_START`;
  AC 25 pass 2: `CAST_CLIP_SECONDS`/`CAST_RAISE_SECONDS`/`CAST_RAISE_FRACTION`, `cast_cut_start`,
  `cast_launch_seconds`, `on_cast_started`/`on_cast_ended`/`_advance_cast`)
- `src/main/match_runner.gd` (AC 27: the bolt arm in `_stun_flavor_for_slot`; AC 25/26/28 pass 2:
  `_push_cast_presentation` at step 3a-quater, `_root_in_force`, `_spawn_bolt`/`_advance_bolt`/`_free_bolt`,
  `BOLT_LAUNCH_HEIGHT` and the five runner-local cast fields)
- `src/actors/hero/telegraph_controller.gd` (AC 26/28 pass 2: `on_cast_warning_started`/`_ended`,
  `set_root_marker`, `CAST_WARNING_COLOR`/`ROOT_MARK_COLOR`)
- `src/actors/hero/hero.tscn` (AC 26/28 pass 2: `CueCastWarning`, `CastWarning`, `RootMark` + their
  sub-resources; no other node touched)
- `assets/characters/paladin/paladin_anims.res` (27 -> 29 clips)
- `test/integration/test_rig_clips.gd` (`EXPECTED_LOOP` 27 -> 29)
- `test/integration/test_hero_reaction_clips.gd` (the bolt flavour case, extended not weakened)

Added:
- `test/state/test_hero_cast.gd` (+ `.uid`) — 48 tests, AC 1-24 (43 + five review-fix tests, see "Review fix pass")
- `test/integration/test_cast_interrupt_live.gd` (+ `.uid`) — review fix N2, the strike-tick interrupt frees the bolt
- `tools/add_paladin_cast_clips.gd` (+ `.uid`)
- `tools/measure_cast_clip_frames.gd` (+ `.uid`)
- `src/actors/props/bolt_actor.gd` (+ `.uid`) — AC 25, the bolt prop
- `tools/gen_cast_warning_audio.gd` (+ `.uid`) — AC 26, the cue generator
- `assets/audio/cue_cast_warning.tres` — its generated output (native `AudioStreamWAV`, no import step)
- `test/integration/test_cast_presentation_live.gd` (+ `.uid`) — AC 25/26/28, 16 checks

All `.uid` sidecars exist as of the final `--editor --quit` scan; `measure_cast_clip_frames.gd.uid`
and `add_paladin_cast_clips.gd.uid` were missing at the end of pass 1 and that scan generated them.

Untracked, generated by the headless import this pass ran, to be committed WITH the FBXs:
- `assets/characters/paladin/cast.fbx` + `cast.fbx.import`
- `assets/characters/paladin/dizzy.fbx` + `dizzy.fbx.import`

Docs (this record; review N7 — the two modified docs files the File List had omitted, which the commit chain
splits into the DOCS commit, never the code commit):
- `docs/implementation-artifacts/6-5c-hero-cast-honed-bolt.md` (this file)
- `docs/implementation-artifacts/sprint-status.yaml` (the `story_notes` row; the board status is still `ready-for-dev`)

Review fix pass additions to already-listed files: `src/state/match_state.gd` (M2, N1, N3),
`src/main/match_runner.gd` (N2), `test/state/test_hero_cast.gd` (M2, M3, N4, N5, N6),
`test/state/test_record_file.gd` (M1).

## Change Log

| Date | Author | Change |
|---|---|---|
| 2026-09-25 | Claude Sonnet 5 (gds-create-story, main session, no subagents) | Story authored against d6d5602 from the scope talk 2026-09-25. Status `authored`; board entry stays `backlog`. NOT cleared for a dev pass. Nothing committed. |
| 2026-09-25 | Claude Sonnet 5 (fix + promote pass, main session, no subagents) | Readiness gate (`_65c-gate.md`: 4 blocking / 4 major / 7 minor) applied without a second gate round; rulings `6-5c/R1`..`R19` recorded in the decision-log; Open Questions closed; broken-test table +5 rows; smoke steps 15-17 added. Status `ready-for-dev`. |
| 2026-09-25 | Claude Opus 5 (1M context) (dev pass 1, main session, no subagents) | State layer and clips: AC 1-24, 27, 29. Golden re-baselined ONCE, `962514b1` -> `97d52922`, three causes isolated; `FORMAT_VERSION` 14 -> 15; 14 mutants, all killed. Stopped on capacity with AC 25 (second half), 26 and 28 unbuilt. Nothing committed. |
| 2026-09-25 | Claude Opus 5 (1M context) (dev pass 2, main session, no subagents) | Presentation: AC 25 (cast pose + sky-to-target bolt + the arrival-tick pin), AC 26 (target warning marker + looping generated cue), AC 28 (root marker). New: `bolt_actor.gd`, `gen_cast_warning_audio.gd`, `cue_cast_warning.tres`, `test_cast_presentation_live.gd`; `hero.tscn` +3 nodes. NO `src/state/` edit, so state suite and golden UNMOVED (1064/0/10450, `97d52922`); integration 69/69. 7 more mutants, all killed. Status `review`. Nothing committed. |

| 2026-09-25 | Claude Sonnet 5 (review fix pass, main session, no subagents) | Review `_65c-review.md` (0 blocking / 3 major / 8 minor) applied: M2 (a cast drops a held block, `6-5c/R4`), M1 (bolt record replays to the identical hash), M3 (slot-symmetric 6c), N1-N7, N9 measured bit-identical, N8 accepted. Golden `97d52922` UNMOVED in both directions; FORMAT_VERSION 15. State 1064 -> 1070 tests, integration 69 -> 70. 7 more mutants (M22-M28), all killed. Status stays `review`. Nothing committed. |

Story 6-5c-hero-cast-honed-bolt is code-complete (Tier A); Status `review`, awaiting code review,
the operator's live smoke (Task 12) and the close-out chain.
