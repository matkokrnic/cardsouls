---
baseline_commit: 7f4c67c55a223c64b818e9ce2c0bcf2b74c45319
---

# Story 7.3: Minion rework: the Hellhound

Status: ready-for-dev

Tier **A** (touches `src/state/`: a new summon count and kind, a new kind of per-unit behaviour with seeded draws, a damage and deflect
interrupt, a get-up lockout, and the minion-membership rule). Authored 2026-10-10 against HEAD == origin/main == `7f4c67c`; the only
untracked entry is `assets/characters/hellhound/`. The operator's asset search (`E6-C/R11`) is complete: the Hellhound pack is in the
tree, uncommitted. Readiness gate 2026-10-10 (NOT READY, 4 blocking / 9 major / 9 minor) fixed and promoted in the same-day fix pass.
Rulings are recorded in the decision-log session "7-3 scope, gate and rulings" as `7-3/R1..R24` and `7-3/D1..D5`; this story cites those
labels. Numbers marked "to be measured" are NOT thresholds; they are authored data the dev pass fixes and the live smoke tunes.

## Story

As a player, I want the green card to summon two Hellhounds that bite and leap, flinch when hit or deflected, back off, circle and bark
between attacks, so that a minion is a fast, aggressive, readable pack animal rather than a slow zombie that walks up and swings.
As the operator, I want the zombie shelved rather than deleted and the card's two halves recombinable by editing data, so that Deck 1
tuning and Deck 2 reuse never need code.

## Rulings (decision-log `7-3/R1..R24`, `7-3/D1..D5`)

Scope (operator, 2026-10-10):

- **R1** The skeletonzombie minion is SHELVED, not deleted (the totem fixture cards' treatment): its kind, assets, the Vanguard effect
  and the `ruin_vanguard` card file stay in the repo and load; they leave Deck 1.
- **R2** New effect Hellhound replaces Vanguard as the NORMAL half of the green card; the pitch half stays Culling. Cost starts at
  Vanguard's. The halves recombine by data only. `deck-1-spec.md` carries a dated 10.10.2026 amendment (written in the fix pass, `R24`).
- **R3** One Hellhound cast summons TWO hounds. A hound dies to exactly three unbuffed basic hero melee hits.
- **R4** Damage to a hound interrupts its current attack and plays the Hit clip. Re-opens the `4-3b` no-stagger non-goal for the hound
  kind only.
- **R5** Two attacks: bite (close) and leap (from mid range; the hound travels forward). Both blockable and deflectable like the current
  minion strike.
- **R6** Between attacks the hound backs off and circles while facing its target, and barks (placeholder acceptable). Chaotic and
  aggressive. Randomness from the match seed. Every distance, duration, speed and probability is authored data.
- **R7** P1 hounds purple (`T_HellHound_Pe_D`), P2 hounds red (`T_HellHound_Rd_D`). Cyan (`T_HellHound_Cn_D`) does not enter the repo.
- **R8** Raise Dead: a revived hound plays its Death clip in reverse as the get-up.

Claude defaults (vetoable): **D1** target rule unchanged (`priority_name = &"standard"`). **D2** hound speed strictly between the zombie's
authored `move_speed` and the hero's authored run `move_speed`. **D3** the R4 reaction triggers on damage from any source (amended by `R12`:
a deflect also triggers it). **D4** a hound is a MINION for every rule that keys on "minion": corpse on death, Culling, Drain, Corpse Bomb,
Raise Dead, Bloodlust. Vampiric Aura is NOT in that list (gate M5; see AC 5). **D5** scene selection, lock-mark lift and spawn look are
runner-owned presentation tables keyed by kind name (the `_TOTEM_TINT_BY_KIND` precedent), falling back to today's attack-shape rule.

Operator rulings on the former open questions: **R9** (OQ1) new card file `hellhound` (normal Hellhound, pitch Culling) replaces
`ruin_vanguard` in `deck_1`. **R10** (OQ2) a reviving hound cannot attack until its get-up ends and can be damaged during it. **R11** (OQ3)
after a hit reaction the hound backs off / circles before re-engaging. **R12** (OQ4) a deflect of a hound attack triggers the reaction, a
block does not (re-opens `4-3b/R7` for the hound only). **R13** (OQ5) no coordination: each hound draws its own decisions. **R14** (OQ6)
price stays at Vanguard's, flagged for 7-7. **R15** (OQ7) the hound's corpse lifetime is the existing global one.

Claude rulings on the gate: **R16** `CardEffect.summon_count: int = 1` and `summon_kind: StringName = &""`, no `SUMMON_KINDS` row.
**R17** the get-up is an authored duration and a state-owned attack lockout, one rule for every hound that rises from a corpse. **R18** the
same-tick outcome is a seat-symmetric TRADE. **R19** two kind flags `react_on_damage` / `react_on_deflect`. **R20** a second reach probe;
back-off / circle transitions are state tick timers; fixed draws at step 3b. **R21** leap travel is actor-owned, authored per ATTACK, the
move-multiplier triplet moves from the kind to the attack. **R22** the speed band stands. **R23** `FORMAT_VERSION` cause corrected.
**R24** the `deck-1-spec.md` amendment.

## Acceptance Criteria

Behaviour and acceptance only; the mechanism is the dev pass's, within Dev Notes.

1. **Shelving (R1).** The `minion` kind (skeletonzombie), `assets/characters/skeletonzombie/`, `summon_ruin_vanguard`, and the
   `ruin_vanguard` card file still load and still resolve a cast to ONE zombie exactly as before, with unchanged authored values (the
   zombie's three phase move-multipliers included, bit for bit, `R21`). No Deck 1 card has Vanguard as its normal half. A test summons the
   Vanguard effect from the shelved card and proves one zombie lands.
2. **The green card (R2, R9).** A new card file `data/cards/hellhound.tres` (id `hellhound`) holds Hellhound as its normal half
   (3.0 mana, Vanguard's, `data/cards/ruin_vanguard.tres:10`) and Culling as its pitch half (3.0 mana + 1 green orb,
   `ruin_vanguard.tres:14-16`; instant, the speed Culling's card has had since `7-4/R6`), `max_copies = 3` (`:27`).
   `data/decks/deck_1.tres:7` lists `hellhound` in the place of `ruin_vanguard`, same copy count. Deck 1 copy counts, total size and
   colour census do not change. The library pins move with it: `data/cards/` holds 18 authored cards, not 17; the dormant fixtures
   are ten, not nine (`ruin_vanguard` joins them); `data/effects/` holds 17, not 16 (`test_card_authoring.gd:112, 122, 551` and the Deck 1
   tables at `:53, 61, 76, 250`).
3. **Recombination by data (R2).** A card file whose `basic_effect` is Vanguard and one whose `basic_effect` is Hellhound, each with
   Culling or with any other existing pitch effect, all resolve with no code edit. A committed test builds all four combinations from
   authored `.tres` resources and casts them.
4. **Two hounds per cast (R3, R16).** `CardEffect` gains `summon_count: int = 1` and `summon_kind: StringName = &""` (empty = the existing
   fallback to the minion kind). The Hellhound effect authors count 2 and the hound kind. The defaults keep every existing summon
   effect (Vanguard, the three fixture summon cards, the golden's synthesized `summon_<id>` effects) summoning exactly what it summons
   today. `SUMMON_KINDS` gains no row; totem-ness stays derived from it, so a Hellhound cast gates on `FeatureFlags.minions`, not
   `FeatureFlags.totems` (a test closes each flag in turn). One Hellhound cast puts exactly two live hound records on the caster's board
   on the cast tick; one Vanguard cast still puts exactly one zombie. Both hounds appear in non-overlapping spawn positions that avoid
   each other and the heroes (the `4-3e` batch rule). The reversal stays one packet whose `indices` array already holds N entries: the
   apply seat writes both, and the column doc (`player_state.gd:891`, "[the summoned record's board index]") is updated. A Counterspell
   against the cast removes both hounds with no corpse, alive or dead (the `6-5f` reversal extended to a batch, including the
   dead-with-expired-corpse arm).
5. **Minion membership (D4).** "Minion" becomes an authored fact on the kind (true for `minion` and the hound, false for the three totem
   kinds), replacing the literal-kind-name tests. A hound leaves a corpse when killed; Culling kills it and pays its mana; Drain may
   sacrifice it; Corpse Bomb consumes it; Raise Dead revives it as a hound; Bloodlust doubles its damage dealt and taken. With ONLY hounds
   out, Culling, Drain and Corpse Bomb are not refused by the pre-spend gate `NEEDS_OWN_LIVING_MINION`. Each is pinned by a test that
   fails if hounds stop counting. Totems remain excluded from all of these exactly as today. **Vampiric Aura is not changed:** its
   lifesteal gate stays the hero or a hero-thrown shot (`_apply_lifesteal`, `match_state.gd:3228-3232`; "minion, totem and projectile
   damage never heal", `:3207-3208`; spec "all damage YOU deal"). A hound's own hits never heal; the caster's hits on a hound heal as on
   any unit.
6. **Three hits (R3).** An unbuffed hound at full health dies to exactly three basic hero melee hits: the third kills, two leave it alive
   with positive hp. Derived: the hero deals the flat `hero_damage_to_unit = 3.0` (`balance_config.tres:116`), so a hound's authored max
   hp lies in (6.0, 9.0], and 9.0 matches the zombie's (`:41`). A parametric test reads the authored values and asserts
   `ceil(max_hp / hero_damage_to_unit) == 3` (`BC/R3`: the integration-level reader, like `test_contact_pipeline.gd`).
7. **Hit reaction (R4, D3, R18, R19).** The kind flag `react_on_damage` is true for the hound, false for the zombie. When a hound that
   survives is damaged by any source (hero melee, projectiles and totem shots through the contact seat `match_state.gd:3039`, Honed
   Bolt's unit arm `:6499`; `apply_damage_at` has exactly these two callers), whatever swing or leap it is in stops at once: the hitbox
   goes inactive the same tick, the open swing-dedupe record is discarded (`UnitSwingDedupe.discard`), and it plays the Hit clip. A
   damaging hit that kills it plays Death, not Hit; `kill_at` paths (Culling, Drain, Corpse Bomb, reversal) play Death. **Same-tick
   TRADE:** a hound attack whose hitbox was active at the step-3 latch lands even if the hound is damaged in that same tick, on BOTH
   seats (a P1 hero hitting a P2 hound and a P2 hero hitting a P1 hound with mirrored inputs give the same outcome). Pinned by one test
   per seat. After the reaction the hound enters back-off / circle before re-engaging (`R11`; AC 12). No reaction fires while the hound is
   getting up (AC 16). The reaction is a POLLED per-record state fact read through the existing `rig.on_unit_tick(alive, phase, speed)`
   path; it adds no observation seam (the family stays ten). A zombie damaged mid-swing still finishes its swing (`4-3b` Non-Goal,
   `4-3b-minion-attack-rhythm.md:392`). Pinned both ways, by a test per kind.
8. **Deflect reaction (R12, R19).** The kind flag `react_on_deflect` is true for the hound, false for the zombie. A deflect of a hound
   attack triggers the same reaction as a hit (AC 7, including the swing-dedupe discard); a block does not. The seat is the deflect
   branch (`match_state.gd:2561-2624`; the unit exclusion is written out at `:2584-2588`, the hero-only gate at `:2620`). `4-3b/R7` is
   re-opened for the hound only: `test_block_deflect.gd:685-708` (the zombie negative guard) stays green and gains a hound counterpart
   (deflect reacts, block does not).
9. **Two attacks (R5, R20, R21).** A hound has a bite and a leap. Bite versus leap is decided by TWO reach bands, fed to state by a second
   reach probe on the existing intake (the `4-3b/R17a` precedent, `match_runner.gd:3743-3750`; tapped, so replay-safe); the bands and the
   choice between them are authored data and their edges are "to be measured". Each attack's windup, active and recovery windows, damage,
   and travel are authored data. The leap's travel is actor-owned movement authored per ATTACK: the three phase move-multipliers move from
   the kind profile (`unit_kind_profile.gd:101-103`) to each attack profile, the zombie's values preserved bit for bit, so the zombie's
   swing root and the hound's bite stay rooted (`4-3c1`) and the leap's multipliers let it travel. The leap follows the LOCKED attack
   direction, not the live target (it is not homing). It ends closer to its target than it began, when unobstructed. This re-opens the
   `4-3c/R19` swing commitment for the leap only.
10. **Same defence as today (R5).** A bite or a leap that connects with a blocking hero is mitigated by the block multiplier, a deflect
    inside the window deflects it, and a rolling hero's i-frames dodge it, all through the SAME contact ladder a zombie strike uses. No new
    defence rule, no new refusal reason. Pinned by one test per defence per attack.
11. **Authored data (R6).** Every distance, duration, speed and probability the hound uses lives in an authored resource and is changed by
    editing that file only: ranges, windows, damage, move speed, back-off and circle parameters, bark cadence, reaction recovery, get-up
    duration. No such number is a literal in `src/`. The authoring audit (`test_balance_authoring.gd`) bounds each one.
12. **Chaotic, aggressive, deterministic (R6, R11, R13, R20).** Between attacks, and after a hit or deflect reaction, a hound backs off and
    circles its target while facing it, and barks. Observable properties, each "to be measured" for its value and authored for tuning: how
    long it holds the back-off, how wide the circle is, which way it circles, how long before it re-engages. Each hound draws its own
    decisions; the two hounds of one cast do not coordinate. Every back-off / circle / re-engage transition is a state tick timer drawn at
    phase entry (never an actor "reached a distance" decision). Draw discipline: a fixed number of draws per decision, no rejection
    sampling, at step 3b, P1 then P2, in board-index order, on the single `_rng`. A Hellhound cast draws nothing on the cast tick, so
    `test_the_summon_consumes_no_rng` (`test_determinism.gd:2276`) stays true; its scope is stated if that changes. Two runs of the same
    seed and intents produce the same decisions (same hash trace, same replay); two seeds produce visibly different hound play. Nothing
    depends on wall-clock time, frame rate or animation playback.
13. **Targeting and speed (D1, D2, R22).** Hounds acquire targets by the same rule as zombies. The authored hound `move_speed` is strictly
    between the zombie's authored `move_speed` and the hero's authored run `move_speed`; the test READS both from the authored config (a
    retune of either must not silently unpin the rule).
14. **Ownership colours (R7).** A P1-owned hound shows the purple skin and a P2-owned hound the red one, in every state, including lingering
    corpse and revived. The cyan skin and its file are absent from the committed tree. Colour follows the slot that owns the record, not the
    card or the camera; a Raise Dead revival keeps the owner's colour.
15. **Presentation rows (gate M6).** The new card and effect have what Deck 1 requires of every effect id: an icon
    `assets/art/icons/game_icons/summon_hellhound.svg` with its line in `assets/CREDITS.txt` (`test_card_face.gd:758-771` enforces both), a
    row in `data/presentation/effect_icons.tres` (today `:22` maps `summon_ruin_vanguard` only) and a presentation row for the resolution
    look and sound (the `vanguard` row, `data/presentation/effect_presentation.tres:27-30`, lists the Vanguard effect id only). The
    spawn look and sound fire ONCE per cast, from the Hellhound row, not once per hound with the Vanguard crack and `vanguard` sound
    (`_present_unit_spawn`, `match_runner.gd:2122-2125`). The lock mark sits at the hound's own height (per-kind lift, not the zombie
    chest's `LOCK_MARK_UNIT_LIFT = 1.53`, `match_runner.gd:4163-4173`; measured, T1). The icon is player-facing art: the operator picks it
    (the dev pass proposes candidates from the already-credited game-icons set and the operator chooses before the commit).
16. **Get-up (R8, R10, R17).** A hound that rises from a corpse, by Raise Dead or by a Counterspell restore (one rule for both), is
    locked out of attacking for an authored duration on the hound kind (seconds, converted once through `BalanceTicks`), a STATE fact.
    During it the hound is rooted, can be damaged, and has no hit reaction. Its Death clip plays in reverse, rate-fitted to that
    duration, at the corpse's position, in the owner's colour; nothing in state depends on playback, so a replay that never runs the rig is
    identical. The corpse it came from is consumed as today. The hound's kind survives the raise (it is read off the dead record,
    `match_state.gd:4316, 4325`), so it revives as a hound.
17. **Rig adoption.** The hound is a skinned, animated actor using the Hellhound pack, with the clips the behaviour needs: idle, walk, run,
    attack/leap, hit, death (the death clip also drives the get-up reversal). T_Pose is stripped at import (`3-0a`/`4-3c` precedent). A
    committed rig test pins the clip set on the assembled scene, mutation-proven (`test_unit_rig_clips.gd` shape). The strike frame of
    each attack and its alignment to the authored active window are measured and aligned by the `4-3d` mechanism (custom playback rate)
    or a better one the dev pass rules, each strike pinned by a live test (`test_unit_strike_alignment_live.gd` shape); the controller
    holds one constant pair today (`unit_animation_controller.gd:92, 102`), so alignment becomes per attack.
18. **Placeholder bark (R6).** A bark sound plays from the hound at the authored cadence, positioned at the hound, from a placeholder
    asset with a row and a `assets/CREDITS.txt` line. The cadence is derived from phase transitions and authored timers (no extra
    draw). The sound has no gameplay effect; the final sound is the art phase.
19. **Repo hygiene.** `assets/characters/hellhound/` enters the repo through the `4-3c` precedent (no LFS, binary attributes), minus the
    cyan skin. `.gitattributes` gains a `*.tga binary` line (M12). The committed size delta is MEASURED and reported (`du`/`git
    count-objects -vH` before and after). The editor is not opened on the pack before the import hooks exist; `project.godot` diffs are
    reviewed line by line.
20. **Determinism and gates (Tier A).** The full suite passes (`bash test/run_all.sh`), the architecture invariants pass (F1, D3(a),
    D3(b)/A2), and the golden is handled per the Golden Prediction: measured both directions, re-baselined once if it moves,
    `FORMAT_VERSION` bump explained by cause (`R23`).
21. **No state in presentation.** Presentation reads state; it never writes it. No new observation seam (the family stays ten); the hit
    reaction, get-up and bark are polled or derived facts. If the reaction is represented as an `AttackPhase` value, the four seats that
    mishandle an added phase are updated and pinned (Dev Notes), and the zombie path is proven unchanged by a per-kind test.
22. **Docs.** `docs/planning-artifacts/deck-1-spec.md` carries the 10.10.2026 amendment (written in the fix pass, `R24`; the dev pass
    implements against it and does not write it). `epics.md` Epic 7 item 4 is left alone until close-out. Docs and code never share a
    commit (CLAUDE.md).

## Tasks / Subtasks

Two dev sessions. Session 1 is all state, data and unit tests, with the golden re-baselined once (T2-T6, T9). Session 2 is rig, scene,
presentation, assets and smoke, with NO new hashed fact (T7, T8, T10). A behaviour gap found at smoke that needs a new state fact moves
the golden a second time and is a stop-and-ask.

- [ ] T1: Measure before building (ACs 9, 12, 15, 17). No code until these are written into Measured Facts "dev-pass measurements".
  - [ ] Import the pack headlessly (no editor), per the `3-0a`/`4-3c` route; list the clips the importer actually yields; record root
    motion vs in place per clip; decide which of `attack`/`Attack01` reads as the leap, else compose the leap from
    `JumpStart/JumpLoop/JumpEnd`.
  - [ ] Measure each attack's strike frame with a `tools/measure_strike_frame.gd`-shaped tool (commit it).
  - [ ] Measure the model's real height and foot offset (`LOCK_MARK_UNIT_LIFT` derivation, `match_runner.gd:4147-4163`, redone for the hound).
  - [ ] Measure the cost of the second reach probe (Performance Rule, `project-context.md`).
- [ ] T2: Data shape (ACs 1-4, 11, R16, R21). `CardEffect.summon_count` / `summon_kind`; the kind-membership fact; the `react_on_damage` /
  `react_on_deflect` flags; the get-up duration; the per-attack move-multiplier triplet (zombie values preserved); the `hellhound` kind,
  bite and leap attack records and behaviour parameters in `BalanceConfig.unit_kinds`; `data/effects/summon_hellhound.tres`;
  `data/cards/hellhound.tres`; `deck_1.tres`.
- [ ] T3: Minion membership (AC 5, D4). Replace every literal-kind-name minion test with the data fact (full list under Dev Notes). Keep
  zombie behaviour byte-identical.
- [ ] T4: Summon batch (ACs 3, 4). N records per cast, one reversal packet covering all of them, batch spawn placement.
- [ ] T5: Hit and deflect reaction, get-up lockout (ACs 6-8, 16). At the damage seats and the deflect branch, the per-kind flags select the
  interrupt; the same-tick trade; the swing-dedupe discard; the lockout.
- [ ] T6: Behaviour (ACs 9, 12, 13). Second reach probe, attack choice, back-off / circle / re-engage timers, seeded draws at step 3b.
- [ ] T7: Rig, scene, colours, bark, get-up reversal, presentation rows (ACs 14, 15, 17, 18).
- [ ] T8: Assets and hygiene (AC 19). Move the cyan skin out of the tree (out-of-repo backup + SHA-256 match first, `C4`), add
  `*.tga binary`, commit assets in their own commit.
- [ ] T9: Tests (all ACs), including the "Tests expected to break" list below; mutation-prove the load-bearing ones.
- [ ] T10: Golden, `FORMAT_VERSION`, full suite, architecture invariants, live smoke (Live Smoke section).

## Measured Facts

Measured 2026-10-10 at `7f4c67c` by reading source (path:line), corrected by the 2026-10-10 readiness gate. Items the dev pass must
still measure are marked "to be measured".

**M1. The card already separates its halves.** `data/cards/ruin_vanguard.tres:23-24` holds `basic_effect = ExtResource("3_basic")` (the
Vanguard effect) and `pitch_effect = ExtResource("4_pitch")` (Culling) as two independent references with two independent conditions
(`:10` `mana_cost = 3.0`; `:14-16` pitch `mana_cost = 3.0` + `orb_costs {2: 1}`). `data/decks/deck_1.tres:7` lists the card by id with
`copies` 3. The effect is one line of data: `data/effects/summon_ruin_vanguard.tres`. Swapping an effect reference is a data edit; the
new card file `hellhound` (`R9`) uses it.

**M2. How a summon effect becomes a kind, and why a row is the wrong tool.** `CardEffectResolver.SUMMON_KINDS`
(`card_effect_resolver.gd:85-88`) maps three totem ids; an unmapped `summon_*` id falls to `KIND_MINION` (`:81`, `:678-681`), a deliberate
default. `SUMMON_KINDS` is ALSO the totem test: `_is_totem()` is `SUMMON_KINDS.has(effect_id)` (`:688-689`), and `outcome()` reads
`flags.totems` for a mapped id and `flags.minions` otherwise (`:602-605`). A `summon_hellhound` row would gate the hound cast on
`FeatureFlags.totems` (invisible while both flags are true, `data/feature_flags.tres`) and make a new kind a code edit, which `R2`
forbids. `CardEffect` has no kind field today (`card_effect.gd:42-289`); non-zero neutral defaults have precedent (`kill_cap = 99`,
`raise_hp_percent = 100.0`, `:90, 99`). The apply seat is the `OUTCOME_SUMMON` arm of `MatchState._apply_card_effect`
(`match_state.gd:4094-4125`): it reads the kind index and that kind's `max_hp`, calls `player.units.add(...)` ONCE (`:4106`) and records
the reversal (`:4123-4125`). A kind the config does not author puts nothing on the board. Ruling: `R16`.

**M3. "Minion" is a kind NAME, not a data fact.** Three places test `kind_index_at(i) == balance.kind_index_of(KIND_MINION)`:
`match_state.gd:3189` (`_is_bloodlust_body`), `:3281` (`_is_own_minion`) and `match_runner.gd:3918-3927` (`_gather_drain_target`). Without a
fix a `hellhound` kind leaves no corpse, is immune to Culling, undrainable, unbombable and outside Bloodlust, silently. Raise Dead
(`:4316-4325`) and Grave Ward (`:4266`) are corpse-keyed, not kind-keyed, and follow from `_is_own_minion`. The full set is in Dev Notes.

**M4. One summon, one record; the reversal packet is already plural.** `UnitBoard.add` appends one record (`unit_board.gd:352`).
`REVERSAL_VANGUARD` (`player_state.gd:813`) takes `reversal_indices`, an ARRAY (`:910`); `_reverse_summon` loops it
(`match_state.gd:4740-4743`) and so does the pre-check (`:5385-5387`). Only the apply seat writes one element, and the column doc
(`:891`) says "[the summoned record's board index]". No packet growth is needed. Reverse arms: `:4650` and `:5382` (dead-with-expired-corpse).
`test_determinism.gd:1868` pins `[0]` for a one-zombie cast and does not move.

**M5. State is position-free; the runner moves bodies; reach is the only geometry that comes in.** `unit_board.gd` header: a record
carries no `Vector3` (`4-2/R14`). `MatchRunner._approach_unit_actors` (`match_runner.gd:2986`) reads the acquired target pair and calls
`UnitActor.approach(...)` (`:3081`; `unit_actor.gd:327-331`), which walks at the LIVE target and stops at `stop_distance`. A swinging unit
is aimed along its locked direction (`:2957-2958`). The only inward intake is `push_contact`, which rejects unknown kinds by Invariant
(`match_state.gd:1517-1519`); reach arrives as a throttled probe against `attack_at(0).range` (`match_runner.gd:3432-3435, 3774-3803`) and
lands in ONE flag per unit (`unit_board.gd:178, 837`). One probe and one flag cannot express "close" and "mid" (AC 9). Consequence for R6:
a decision the replay must reproduce is state, seeded; the body motion that follows is the runner's.

**M6. The seeded RNG is the single gameplay RNG.** `match_state.gd:5` calls `_rng` "the single seeded gameplay RNG (F2)"; `:239` "the
ONLY randomness source in the state layer (F2/A2)"; `:640` seeds it from `params.seed_value`; `:1648` hashes `rng_state`. Existing
consumers: the deck shuffle seat (`:7179`) and the Boulder placement (`_place_boulder`, draw at `:5035`), whose doc (`:4984-4992`) records
that the Boulder is the SECOND consumer, that every draw moves `rng_state` and every later reshuffle, and the fixed-draw-count rule. The
hound is the THIRD consumer: deterministic, but it shifts later reshuffles. A second RNG instance is an F2 violation (`R20`).

**M7. Damage reaches a unit through exactly two `apply_damage_at` callers**, both in `match_state.gd`: `:3039` (`_resolve_unit_contact`,
step 4: hero melee, unit strike, projectiles incl. Fireball, Rocksling stones, skulls, totem shots) and `:6499` (Honed Bolt's unit arm,
step 6c, after step 4). Boom damages a hero only. `kill_at` callers (`:4224, 4356, 4430, 4742, 4927`) kill without damage. Contact facts
resolve in canonical order, attacker slot ascending then board index ascending (a hero is index -1) (`:2757-2759`), which is why the
same-tick outcome would be seat-asymmetric without `R18`; the codebase latches at step 3 to avoid exactly this (`_iframe_open_at_step3`,
`_counter_color_at_step3`, `:812-822`). Leaving ACTIVE makes `is_hitbox_active_at` false so the runner gathers nothing after that
`advance()` (`match_runner.gd:3436`); the open swing-dedupe record must also be discarded (`unit_swing_dedupe.gd:138`, `:94-110`).
Today a damaged unit's swing is never interrupted (`4-3b-minion-attack-rhythm.md:392`) and units emit no `hit_landed`
(`match_state.gd:2994-2996, 6513-6517`).

**M8. Actor scene and clip selection are single-kind.** `MatchRunner._unit_scene_for` (`match_runner.gd:2577-2588`) returns `UNIT_SCENE`
for every melee kind and `TOTEM_SCENE` otherwise, deciding by attack shape; the only per-kind presentation table keys on the kind NAME
(`_TOTEM_TINT_BY_KIND`, `:2594-2598`). `UnitAnimationController` selects among four clips (`idle`, `walk`, `attack`, `death`) from
`rig.on_unit_tick(alive, phase, speed)` polled every frame (`match_runner.gd:2917-2920`; `unit_animation_controller.gd:158-174`), in the
order dead, phase != IDLE, moving. Strike alignment is a constant pair for ONE attack (`:92, 102`). No unit has a `hit` clip and no actor
has an owner colour.

**M9. Raise Dead makes a NEW record and a new actor, and a Counterspell restore looks the same.** `_apply_raise_dead`
(`match_state.gd:4310`) calls `player.units.add(kind.max_hp * raise_hp_percent / 100, kind_index_at(index), index)`
(`unit_board.gd:352`; `match_state.gd:4324-4325`): a new record, IDLE and attack-ready, whose `raised_from_at` is the corpse index
(`unit_board.gd:288`). A Counterspell-restored minion carries the same marker; the runner can tell them apart only after the drain
(`match_runner.gd:2116-2148`). The get-up is therefore a state fact keyed on "this record rose from a corpse" (`R17`), never on playback.

**M10. Authored numbers the story derives from.** Hero: `move_speed = 4.6` (`balance_config.tres:87`; the run gait, `match_state.gd:7567-7568`;
`walk_speed = 2.2`, `:88`), `hero_damage_to_unit = 3.0` (`:116`). Zombie kind: `move_speed 3.0` (`:39`), `max_hp 9.0` (`:41`), one attack
record with windup 0.9 s, active 0.2 s, recovery 0.8 s, range 1.8 (`:10-13`), `cadence_seconds 0.0`, phase move-multipliers authored 0.0 in
all phases (`:43-45`; fields `unit_kind_profile.gd:101-103`; used as `kind.move_speed * unit_attack_phase_multiplier(phase, kind_index)`,
`match_runner.gd:3079-3083`; `match_state.gd:7810-7823`, whose default arm returns full speed for "any phase added later"). The corpse
lifetime is ONE global field (`balance_config.tres:117`, read `match_state.gd:3261`). `UnitKindProfile.attacks` is already a LIST and every
reader takes entry 0 via `attack_at(0)`; selecting among several was a `4-4` Non-Goal that `R5` ends for hounds.

**M11. Golden fixture contains a summoned minion and loads no authored data.** `test_determinism.gd` summons one unit at t22 under
`_golden_config` (`GOLDEN_UNIT_MAX_HP := 7.0`, `:1364`; `GOLDEN := 43449bd9...` `:1355`), the kind from `UnitKindFixture.minion_only(...)`
(`:1709`) and effects synthesized as `summon_<id>` (`:1775`). It never loads `deck_1` or `data/` (`BC/R3`), so a deck swap cannot touch it.
The fixture's unit is never damaged ("t22 summon never dies", `:1285`), so the golden alone does NOT prove the zombie reaction path
unchanged (AC 7's per-kind test does). `RecordFile.FORMAT_VERSION := 22` (`src/systems/record_file.gd:384`).

**M12. The asset pack (operator-measured 2026-10-10, byte sizes re-read by `ls -l`, re-verified by the gate).** `SK_Hellhound.fbx`
10,340,896 B; textures `T_HellHound_Cn_D.tga`, `_Pe_D`, `_Rd_D`, `_N` each 12,582,956 B, `_E` 4,194,348 B. Total 64.9 MB with Cn, 52.3 MB
without. 22 takes by string-scan: T_Pose, attack, Attack01, Death, hit, idle, Idle01, JumpStart, JumpLoop, JumpEnd, run, Run_Left,
Run_Right, walk, Walk_Backwards, Walk_Left, Walk_Right, Swim*, Idle_Swim. `Walk_Backwards`, `Walk_Left/Right`, `Run_Left/Right` are the
natural back-off and circle clips. There is no bark or howl take; the bark is sound only. No `.import` files exist (the editor was not
opened). Repo today: 65.10 MiB (`git count-objects -vH`). Skeletonzombie precedent: 36 MB committed without LFS (`4-3c-minion-rig-adoption.md`
AC 1). `.gitattributes` marks `*.fbx` binary but has no rule for `*.tga`; `git check-attr text` on a pack texture reports `text: auto`.

### Contradictions between the prompt and the repo (flagged, not reinterpreted)

- **C1. R2 "verify halves recombine by data" is half true.** True for the effect references (M1). False for what a recombined hound card
  needs: no summon count and no kind field (M2, M4) and a hound kind is not a minion for any minion rule (M3). Made true by `R16` and AC 5.
- **C2. R6 "randomness from the match seed" meets a position-free state layer (M5).** The seeded draw can only live in `src/state/`; the
  movement it steers lives in the runner. The decisions are state facts and the motion follows them; a presentation-only circling that
  "looks random" would break replay identity.
- **C3. "D1 same rule as current minions" holds trivially** (`priority_name` is per kind); the standard priority picks the nearest target,
  so whether two hounds of one cast pick the same enemy is a consequence, not a decision (`R13`: no coordination).
- **C4. The cyan skin is already on disk** inside the untracked directory. R7 says it does not enter the repo, so the dev pass moves it
  out of the tree (not into git history), and does not delete the operator's only copy without an out-of-repo backup and a SHA-256 match.
- **C5. The operator's "walk 2.0 / run 6.0" is the 6-7b dev-pass value**, superseded by `6-7b/R6` (5.5 / 2.2, commit `f5f3631`) and then
  by story 7-9 (run 4.6, commit `6311a31`). The band is (zombie 3.0, hero run 4.6) (`R22`).

### Dev-pass measurements (to be filled by T1; every row is "to be measured" now)

| What | Why |
|---|---|
| Clips the importer yields, names and lengths | AC 17 |
| Root motion vs in place per clip | AC 9, 12 (DECISION A: state owns position, the `3-0a`/`4-3c` posture) |
| Which of `attack`/`Attack01` is the leap, or leap composed from Jump clips | AC 9 |
| Strike frame of bite and leap; leap travel in the clip | AC 17 |
| Model height, foot offset, collision size, hit/hurtbox size, lock-mark lift | AC 9, 15, 17 |
| Hound speed, ranges and the two reach bands, windows, back-off and circle parameters, bark cadence, get-up duration | AC 9, 11, 12, 16, 18 (authored; tuned at smoke) |
| Committed size delta | AC 19 |
| Cost of the second reach probe | Performance Rule in `project-context.md` |

## Dev Notes

### Mechanism rails (what is decided, so the dev does not re-decide it)

- **State decides, runner moves, actor animates (M5).** State (hashed, plain ints on `UnitBoard` in index-aligned arrays, snapshotted the
  way existing records are; never StringName keys in the hash; no `Vector3`): behaviour phase per record (approach / chosen attack /
  back-off / circle / hit reaction / get-up), that phase's tick countdown, circle direction, chosen attack index, and the reaction and
  get-up lockouts. Actor-owned (unhashed, replay-safe because reach and strike facts are tapped): position, velocity, the path actually
  walked, yaw, clip choice and playback rate, skin, bark audio.
- **Reach intake.** A second probe on the existing intake (`R20`); the leap follows `attack_dir_at` during its authored phase and the
  runner drives that velocity (the `4-3c1/R1` split: state hands the rule out, the actor owns velocity, `match_state.gd:7774-7781`).
- All time in ticks via `BalanceTicks` (A1); seconds cross at the one named conversion point (`balance_ticks.gd:252-363`). No `*_seconds`
  float reaches `advance()`.
- One RNG, `_rng` (M6, F2). Draws only inside `advance()`, only for hound records, at step 3b (`match_state.gd:837-838`), P1 then P2,
  board-index order, a fixed number per decision, no rejection sampling. No iteration over a Dictionary or a StringName sort.
- Content is injected once, recorded by value, never hashed (7-4 posture). The kind flags and durations are content.
- Presentation reads state; it never writes it. The reaction is a polled state fact through `rig.on_unit_tick`; a new observation seam
  needs a same-story entry in `game-architecture.md` and the RAW allow-list in `test_architecture_invariants.gd:319-341` (the ten are
  `match_runner.gd:2359-2405, 3182-3273`). Avoid one. If the reaction becomes an `AttackPhase` value, update and pin the four seats that
  mishandle an added phase: `unit_attack_phase_multiplier`'s default arm (`match_state.gd:7821-7823`), `_advance_unit_attacks` (no arm; the
  unit stays in it forever, `:2083-2119`), `_aim_unit_actors` (treats any non-IDLE phase as a locked swing, `match_runner.gd:2957`), and the
  controller (plays `attack` for any non-IDLE phase, `unit_animation_controller.gd:172`).
- The zombie path stays byte-identical in behaviour: every new code path is gated on authored data the `minion` kind authors as "off"
  (`react_on_damage`, `react_on_deflect` false; get-up duration irrelevant), and the per-attack multiplier triplet carries the zombie's
  values. The golden's t22 minion is a canary for the draw path, not for the reaction path (M11).
- **Known non-goal (gate m8):** round-over returns at step 1b before step 3b (`match_state.gd:684-687`), so hound behaviour timers freeze
  while the runner keeps driving bodies. Inherited from 4-3 (`4-3b-minion-attack-rhythm.md:390-391`); more visible with a circling hound.
- **Flag only (gate m6):** `_reverse_summon`, `_apply_culling` and `_apply_drain` kill without discarding the swing-dedupe record
  (`match_state.gd:4742, 4224, 4356`) while the contact seat and Corpse Bomb do (`:3065-3066, 4433`). Pre-existing; out of scope.

### Minion-membership sites (the complete set, gate M4)

State: `card_effect_resolver.gd:81` `KIND_MINION` and `:678-681` fallback (`R16`); `:688-689` + `:602-605` totem-versus-minion flag gate (not
changed: `SUMMON_KINDS` gains no row); `match_state.gd:3189` `_is_bloodlust_body`; `:3281` `_is_own_minion` and its callers `:3259`
(corpse lifetime), `:4222` (Culling), `:4375, 4378` (Drain target), `:4428` (Corpse Bomb) and `:5238` (the pre-spend gate
`NEEDS_OWN_LIVING_MINION`); Raise Dead `:4316-4325` and Grave Ward `:4266` (corpse-keyed, follow). NOT sites: `live_kind_count` (`:3606`,
the mana accelerator only) and `TargetingService` (gates on `flags.minions` for every unit, `targeting_service.gd:179, 247-248`).
Runner and presentation: `match_runner.gd:3918-3927` `_gather_drain_target`; `:2577-2587` `_unit_scene_for` (D5: a runner-owned table keyed
by kind name, falling back to the attack-shape rule); `:2122-2125` `_present_unit_spawn` ("has a Hitbox" means "is a minion", so each hound
would get the Vanguard crack and sound; AC 15); `:4172-4173` lock-mark lift (AC 15); `:2944` totem test by `Mesh/Totem` node (preserved as
long as the hound scene has no such node). The totem exclusion is preserved if the membership fact is authored false on the three totem kinds.

### Files expected to change

`src/state/economy/card_effect_resolver.gd` (summon count outcome; kind from the effect), `src/state/match_state.gd` (summon arm, membership,
damage and deflect interrupt, same-tick trade, hound behaviour step, get-up lockout, batch reversal), `src/state/unit_board.gd` (new
per-record facts, snapshot), `src/state/player_state.gd` (the reversal column doc), `src/state/resources/card_effect.gd`
(`summon_count`, `summon_kind`), `src/state/resources/unit_kind_profile.gd` and `unit_attack_profile.gd` (membership fact, reaction flags,
get-up duration, behaviour data, the move-multiplier triplet moves to the attack), `src/state/timing/balance_ticks.gd` (conversion),
`src/state/resources/balance_config.gd` (if the kind audit changes), `src/systems/record_file.gd` (`FORMAT_VERSION` 22 -> 23; `_fresh_nested`
at `:861-869` needs a tag for any new nested resource class or it rebuilds as null), `data/balance/balance_config.tres` (hound kind; zombie
triplet moved, values preserved), `data/effects/summon_hellhound.tres` (new), `data/cards/hellhound.tres` (new), `data/decks/deck_1.tres`,
`data/presentation/effect_icons.tres`, `data/presentation/effect_presentation.tres`, `assets/art/icons/game_icons/summon_hellhound.svg`
and `assets/CREDITS.txt`, `src/main/match_runner.gd` (scene choice, spawn look, lock-mark lift, second probe, circle / back-off / leap
motion, colour, bark, get-up, `_gather_drain_target`), `src/actors/minions/unit_actor.gd` (movement modes),
`src/actors/minions/unit_animation_controller.gd` (or a hound-specific controller), a new hound scene, `assets/characters/hellhound/*`,
`.gitattributes`, `tools/` (strike-frame and import helpers), tests (below). Docs (deck-1-spec, decision-log) are already written by the
fix pass. Preserve: the zombie path, totems, the single `_physics_process` (F1), `Input.*` only in controllers (D3(a)).

### Golden Prediction (prediction only; the dev pass measures both directions)

- **Golden: MOVES, one re-baseline, expected cause SHAPE.** Per-record hound facts on `UnitBoard` add snapshot key paths even at resting
  zero (precedent: `unit_board.gd:222-224`), so the key-path set grows (count it) and the hash moves. If the dev pass keeps every new
  fact out of the hash it does not move and the story is still Tier A; measure rather than assume.
- **Behaviour on the golden fixture: unmoved.** Its one unit is a `minion` summoned at t22 (M11); every new rule is gated by data the
  `minion` kind authors off; `_rng` is drawn only for hound records, so `rng_state` does not move on the fixture. This holds only while
  the `R16` defaults (count 1, empty kind) hold. Both claims are to be measured, with a two-direction proof (a mutation that enables hound
  draws on a zombie moves `rng_state`).
- **Authoring the hound in `balance_config.tres` moves nothing** (`BC/R3`); a NEW seat does (`SC/R6`): the summon count, the interrupt, the
  lockout and the behaviour step are new seats, so tests that pin them move.
- **FORMAT_VERSION: 22 -> 23, predicted, cause per `R23`.** SHAPE: every script property is captured (`record_file.gd:835-841`), so the new
  `CardEffect`, `UnitKindProfile` and `UnitAttackProfile` fields add keys to the `effects`, `pitch_effects` and `balance` channels. BEHAVIOUR
  through a default: a v22 `minion` kind row has no membership fact, rebuilds with it false, and its zombie then leaves no corpse and is
  immune to Culling. A record carries effects and balance BY VALUE (`:733-756`), so a v22 file replaying its own Vanguard as the zombie it
  recorded is a correct replay, not a divergence. To be confirmed by the pre-change recording test.

### Tests expected to break

| File | Why |
|---|---|
| `test/state/test_determinism.gd` (`GOLDEN` `:1355`, key-path count) | New hashed per-record facts. `:1868` (`REVERSAL_VANGUARD` `[0]`, one-zombie cast) does not move. |
| `test/state/test_record_file.gd` (`FORMAT_VERSION` pins; `unit_kinds.size() == 1` at `:488`/`:583` are in-test configs, expected unaffected) | Predicted bump. |
| `test/state/test_replay_identity.gd` (`UNHASHED_CROSS_TICK` list and member count) | New cross-tick state classified HASHED or UNHASHED by the dev. |
| `test/state/test_card_authoring.gd` (`:30, 53, 61, 76, 112, 122, 250, 551`) | 18 cards, ten dormant fixtures, 17 effects, Deck 1 tables naming `ruin_vanguard`. |
| `test/state/test_card_face.gd:758-771` | Every Deck 1 effect id needs an icon and a CREDITS line (AC 15). |
| `test/state/test_block_deflect.gd:685-708` | The zombie negative guard must stay green; hound counterpart added (AC 8). |
| `test/unit_kind_fixture.gd` (`melee()` `:30-33`; 20 files use it) | The shared builder builds a kind called `minion`; membership becomes a data fact. |
| `test_fireball.gd`, `test_rocksling_and_boulder.gd`, `test_spell_targeting.gd`, `test_data_resources.gd`, `test_balance_config.gd`, `test_record_file.gd` | Hand-built `UnitKindProfile.new()` outside the fixture. |
| `test_corpses.gd`, `test_own_minion_spells.gd`, `test_card_effect_resolution.gd`, `test_match_state.gd`, `test_hero_cast.gd`, `test_totem_accelerators.gd` | Reference `KIND_MINION` or `&"minion"`. |
| `test/state/test_spell_framework.gd`, `test_counterspell.gd` | Name the Vanguard card/effect and its reversal; batch reversal. |
| `test/state/test_balance_authoring.gd` (kind audits `:526-533`, `:576-578`, `:655`, `:750`) | A fifth kind; new bounded fields; the triplet moves to the attack. |
| `test/state/test_balance_config.gd:312-316` | Reload of `unit_kinds`. |
| `test/integration/test_card_database.gd`, `test_deck_injection.gd`, `test_history_and_orbs_live.gd`, `test/live_summon_deck.gd` | Name `ruin_vanguard`. `LiveSummonDeck` stays on `ruin_vanguard` (`test/live_summon_deck.gd:16`), so live unit tests using it keep summoning zombies. |
| `test_boulder_and_skull_live.gd:37` | Loads `deck_1.tres` directly, not `LiveSummonDeck`; its Corpse Bomb path now gets hounds if it summons through the green card. |
| `test_fireball_live.gd`, `test_totem_no_rotation_live.gd`, `test_unit_swing_root_live.gd` | Name `minion`; `test_unit_swing_root_live.gd` also pins the root `R21` reopens for the leap. |
| `test_unit_rig_clips.gd`, `test_unit_clip_selection.gd`, `test_unit_strike_alignment_live.gd`, `test_unit_model_facing.gd`, `test_unit_vertical_alignment.gd`, `test_unit_corpse_linger_live.gd` | Instantiate `unit_actor.tscn` or pin its constants; must still pass for the zombie scene and gain hound counterparts. |
| `test_unit_attack_live.gd`, `test_unit_combat_live.gd`, `test_unit_spawn_placement_live.gd`, `test_two_units_converge_live.gd`, `test_unit_approach_live.gd` | Run the real runner; expected unaffected if they use `LiveSummonDeck`; confirm, do not assume. |
| `test_effect_presentation_live.gd`, `test_animation_polish_live.gd:50` | Presentation row `&"vanguard"` (`effect_presentation_set.gd:12`) and the reversal-kind list. |
| `test/state/test_architecture_invariants.gd` | Expected green; the RNG draw stays in `src/state/` via `_rng`. Confirm the scan scope. |

State tests that build in-test `BalanceConfig` literals (`BC/R3`) are expected unaffected for values and affected only where they pin a seat
this story adds.

### Project Context Rules (from `docs/project-context.md` and CLAUDE.md, applicable here)

- F1 one `_physics_process` (`match_runner.gd`); D3(a) `Input.*` only in `src/controllers/`; D3(b)/A2 no global RNG, `Time`, `OS`, `Engine`
  in `src/state/`. Static typing everywhere; GDScript only; no networking. Hash keys are ASCII strings, never StringName keys;
  `Array[StringName].sort()` orders by pointer, never sort StringNames that reach the hash.
- Tier A: full gate, review, live smoke. Docs and code never share a commit. Validation worth proving is committed as a test. Commit
  messages pure ASCII via `git commit -F <tempfile outside the repo>`; the trailer is the session's attribution reminder.
- Git discipline: show the full diff before staging; `git add` and `git commit` are separate commands with explicit paths; never push until
  the operator confirms the log in chat. Dev-pass restores come from out-of-repo copies with SHA-256, never `git checkout`.
- Implementation decisions are the dev's; design decisions are the operator's (CLAUDE.md "Agent autonomy"). All questions this story
  carried are ruled (`R9..R15`); a NEW design question found in the dev pass is a stop-and-ask.

### Docs debt for close-out

- `epics.md` Epic 7 key stories item 4 and the board note "operator asset search first" are stale after this story closes. The decision-log
  session for 7-3 already carries the R-labels; the close-out adds the dev, review and smoke labels after `7-3/R24`.
- Flagged for 7-7 (tuning, no action here): two hounds for Vanguard's price (`R14`); Raise Dead's price (`7-4/R17`).
- Stale comment, flagged not edited: `animation_controller.gd:108` says "at the retuned 6.0" (`R22`).

### References

- Decision-log session "7-3 scope, gate and rulings" (`7-3/R1..R24`, `D1..D5`); `E6-C/R11` (asset search first); `4-3b/R7` and `4-3b/R9`
  with `4-3b-minion-attack-rhythm.md:392` (no-stagger non-goal); `4-3b/R17a` (second probe precedent); `4-3c-minion-rig-adoption.md`,
  `4-3c1/R1`, `4-3c/R19`; `4-3d-minion-strike-alignment-and-corpse-lifecycle.md` (`4-3d/R11`); `4-3e-summon-spawn-placement.md`;
  `4-4-totems.md` (`4-4/R7`); `6-5b-corpses-and-own-minions.md`; `6-5e` (Boulder, second `_rng` consumer); `6-5f-counterspell.md`
  (`6-5f/R16`); `7-4-pitch-speeds.md` (Tier A story shape; `7-4/R6`); decision-log `BC/R3`, `SC/R6`, `E4-P/R9`.
- `docs/planning-artifacts/deck-1-spec.md`, amendment 10.10.2026.

## Live Smoke

One smoke covers R1..R15. Solo `[0,3]` (operator on the pad as P2, P1 on the keyboard as target) or two pads. Add `slot_controller_kinds =
Array[int]([0, 3])` under `script =` in the Main node of `src/main/main.tscn` only for the session and **delete it before any suite or chain
run**. Pin the seed for steps 1-11 and unpin for step 12.

1. (R1, R2, R9) Deck 1 deals the green card; its normal half is Hellhound at 3.0 mana; its pitch half is Culling. No zombie appears from
   any Deck 1 card. The Vanguard fixture card, summoned through `LiveSummonDeck`, still produces a zombie.
2. (R3) One cast shows exactly two hounds, spread apart, on the board; one spawn look and sound, not two.
3. (R3) Hit one hound three times with plain light attacks: it survives two, dies on the third.
4. (R4, D3) Hit a hound mid-bite and mid-leap: the attack stops and the Hit clip plays. Hit one with a spell (Honed Bolt): same. A zombie
   (fixture) hit mid-swing still finishes its swing.
5. (R5, R12) Stand at close range: a bite. Stand at mid range: a leap that visibly carries the hound forward along its locked direction.
   Hold block and take the reduced hit (no flinch); time a deflect inside the window (the hound flinches); roll through one.
6. (R6, R11, R13) Watch a hound for 30 s without engaging: it backs off, circles facing you, barks, re-engages; chaotic and aggressive, not
   metronomic; the two hounds do not move in lockstep. After a hit it backs off before re-engaging. Restart with the same seed and the
   same inputs: same decisions. Different seed: visibly different.
7. (R7) P1 hounds are purple, P2 hounds red, including their corpses.
8. (R8, R10) Kill both hounds, cast Raise Dead: each stands up by playing its death in reverse, at its corpse, in its owner's colour;
   it does not attack until up; hitting it during the get-up damages it without a flinch.
9. (R17) Counter a Raise Dead on hounds so they are restored: they get up the same way.
10. (Culling, D4) Cast Culling with two hounds out: both die, mana paid for both, corpses drop. With ONLY hounds out, Drain and Corpse Bomb
    are castable. Counter a Hellhound cast: both vanish, no corpse.
11. (lock-on) The lock mark sits at the hound's height, not floating.
12. (feel) Free-for-all with the seed unpinned. Record: do the hounds feel too fast, too clingy, too silent? (Tuning, not a defect list;
    goes to 7-7.)

## Open Questions

None. OQ1..OQ7 are ruled as `7-3/R9..R15`. A design question the dev pass finds is a stop-and-ask (CLAUDE.md "Agent autonomy").

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
