---
title: CardSouls — Development Epics
parent: gdd.md
created: 2026-07-20
updated: 2026-07-30
status: draft
---

# CardSouls — Development Epics (Demo Scope)

Detailed breakdown of the epic sequence summarized in `gdd.md`. High-level-story granularity; full stories are produced downstream (`gds-create-epics-and-stories` / `gds-create-story`). Every gameplay layer sits behind a `FeatureFlags` toggle and must **degrade gracefully** when off. All balance numbers are TBD-in-playtest and authored as `.tres`.

**Sequencing invariants:** (1) the controller abstraction lands in **E0** so dummy/PvP/bot are config swaps; (2) split-screen lands in **E2** as a *constraint* on the HUD (build every HUD element in its real half-width space) and as the only way to validate <0.5 s telegraph legibility at soulsborne camera distance; (3) the buildup→bluff→payoff loop is not whole until **E6**.

---

## E0 — Foundations

**Goal.** Establish the architecture skeleton and invariants so every later layer is a data/config addition, not a refactor.

**Key stories.**
- Folder structure: `src/state/`, `src/systems/`, `src/actors/`, `src/ui/`, `data/`, `test/` (per project-context).
- Autoloads: `EventBus`, `FeatureFlags` (loads one `FeatureFlags` `.tres` once at startup), `CardDatabase`, thin `MatchState` wrapper (match logic lives in `src/state/` as a plain testable object — no scene deps).
- **Controller abstraction:** interface + local-keyboard implementation; hero is driven by a controller, and nothing in hero/state branches on "is this a human."
- Hero base stats in a balance `Resource` (`.tres`); `HeroState` in `src/state/` (no scene/visual deps).
- GUT setup; first headless state test; a smoke test that loads every `.tres` in `data/` and asserts required fields.

**Exit criteria.** Hero moves in the arena via the keyboard controller; headless state tests green; `FeatureFlags` autoload loads a `.tres`.

**Risks.** Getting the state/visual seam and controller abstraction right up front — they are the invariants everything else depends on.

---

## E1 — Melee Combat + Training Dummy

**Goal.** Build the soulsborne combat heartbeat in the state + actor layers.

**Key stories.**
- `CharacterBody3D` hero movement (`move_and_slide`); pulled-back soulsborne camera.
- Basic attack chain — state-driven; hitbox *reports contact*, state applies chip damage and grants mana on confirmed hits directly (the direct path is replaced by the data-defined economy evaluator in 3-4, not newly wired there).
- Block / Deflect — hold to block; precise-timing parry window; stamina cost.
- Roll — i-frame dodge in movement direction; stamina cost.
- Stamina economy — auto-regen; zero-stamina lockout of roll/deflect/unblockable.
- Hitbox → Hurtbox contact events → state decides damage; HP state; death at 0.
- Training dummy actor (HP, no retaliation).
- Headless tests: stamina economy, HP/damage, deflect window (driven by fixed `delta` steps).

**Exit criteria.** Timing-critical logic runs in `_physics_process`; state tests cover the economy; combat is exercisable against a dummy.

**Risks.** Souls-combat *feel* is the highest-risk unknown — but note feel is genuinely judged in **E2** (vs a moving opponent), not here (a dummy only tunes hitboxes).

---

## E2 — Local Split-Screen PvP

**Goal.** Make the build 2-player from week one; put the HUD in its real half-width space; enable combat-feel and telegraph-legibility validation.

**Key stories.**
- Two `SubViewport`s, per-player camera, split-screen layout.
- Per-player HUD root (bars) rendered at half width — every HUD element designed for its final real space from the start.
- P1/P2 input profiles; **gamepad controller implementation** (second controller-abstraction impl).
- Two hero instances, independent controllers, hidden per-player state.

**Exit criteria.** Two humans fight melee in split-screen; spacing/attack-weight/deflect feel is evaluable human-vs-human; the viewport size that later telegraphs must read in exists.

**Risks.** Two-profile input mapping; camera framing at half width.

**Note.** This is the **primary playtest tool.** Bluffing is *not* testable yet (needs E5/E6) and that is accepted — early PvP exists to validate combat feel and to keep the build playable with other people, both stated project goals.

---

## E3 — Card System + Mana Economy

**Goal.** The card-economy foundation and the aggression flywheel (P2).

**Key stories.**
- `CardData` Resource (color, Basic effect + cost, Pitch effect + cost, per-card copy cap); `CardDatabase` loads `.tres`.
- Deck (20), hand (4), draw at round start, draw-on-play (instant vs ~1 s delay — TBD), reshuffle + vulnerable window (~1.5–2 s TBD, flagged visually).
- **Card-mode selection UX** — real-time mode pick (radial / hold-modifier / per-mode bind — open, high P4 relevance); Basic mode (①) resolves (summon/spell hook; concrete actors in E4).
- Mana economy: passive auto-regen + melee-hit generation (wire the E1 hook). `FeatureFlag: melee-mana-gen` (off → passive only).
- HUD: 4-card hand display, mana bar + regen tick, deck/reshuffle indicators.

**Exit criteria.** Basic-mode cards playable at mana cost; melee hits fund mana; the flywheel is observable; both flag paths play.

**Risks.** Mode-select UX under real-time pressure must not become a parallel demand (P4).

**Committed obligations.**
- The rig-adoption story and the feel-and-timing-tuning story (the DEBT E split, decision-log
  E3-P/R2) take board slots ahead of the stories below, both preceding the E3 revisit gate.
- The `IntentRecorder` story (the X5 contact-fact contract + DEBT B's reload events, one stream
  contract — decision-log 2-6/R2) takes a board slot; the story file is deliberately not authored
  yet (decision-log E3-P/R3), written just-in-time at its own creation pass.
- **Ordering (updated 2026-08-04, decision-log Session 2026-08-04 — Story 3-5 readiness gate):** 3-5
  split into 3-5a (the mode-select/cast trigger) and 3-5b (draw delay, exhaustion, reshuffle, the
  vulnerable window); the locked order is 3-5a → 3-5b → `3-0c` (`IntentRecorder`) → 3-6. Reason: 3-6
  renders the reshuffle vulnerable window in the HUD, so it needs 3-5b to exist first.
- 3-1 (`MatchState` config object) folds the constructor/`apply_balance` double-injection quirk
  (`match_state.gd:544`) into one injected config object; reconciles `ManaPool`'s `apply_balance`
  refill behavior against `StaminaPool`'s (D9 full-refill ruling) once `max_mana` lands in
  `BalanceConfig` (currently the runner's constructor value only). OPEN decision (d) — does the
  basic attack cost stamina — is RESOLVED (DP/R2, decision-log:1037: YES); the value and its
  certain golden re-baseline are NOT a 3-1 seat — they land in a standalone corrective pass that
  precedes 3-1 (decision-log E3-RG/R2), so the re-baseline carries exactly one named cause.
- DEBT D (the D6 economy-evaluator full form) is committed to land at story 3-4's own gate, which
  reconciles 3-4's existing evaluator-framing text (decision-log:224); not resolved here.
- The deck story (3-3) is the forcing point for the open question of whether hand size ever varies
  (decision-log:801) — first version: always 4, refill on play.
- The reveal-opponent-hand toggle, deferred from 2-5 (2-5/R4), lands in E3 on the condition already
  met there: the face-down/face-up rule lives in exactly ONE seat.
- E3 art includes resolving 2-4's smoke finding S2 — "card slots look small for legibility"
  (decision-log:739) — once real card art exists.
- The opponent face-down top-centre row (2-5/R3) is PROVISIONAL — nothing built in E3 may anchor
  to it; it may be deleted outright (2-6/R9).

---

## E4 — Minions & Totems

**Goal.** Board presence via cards.

**Key stories.**
- Minion actor + autonomous AI; priority types **data-defined** (Standard, Hero-Seeker, Tank, Bomber/AoE) — new types addable via `.tres`, no code.
- Object pooling for minions/projectiles/VFX; throttled targeting tick (~0.1–0.25 s) and/or `Area3D` overlap queries (no per-frame distance loops).
- Totem/ward subtypes: **Combat Totem** (ranged fire, destructible), **Mana Accelerator** (sustained mana-regen layer), **Stamina Accelerator** (stamina-regen boost). All small/wardstone-like.
- Wire Basic-mode summons to real actors. `FeatureFlags: minions, totems` (degrade gracefully).

**Exit criteria.** Cards summon functioning minions/totems; 60 FPS holds with many units; flags toggle cleanly.

**Risks.** Targeting performance; minion AI feel in the small arena (arena size interacts — iterate).

**Committed obligations.** Per the GDD epic table (`gdd.md:412`): "Autonomous minion AI (data-defined
priorities), pooling, throttled targeting, 3 totem subtypes." Flags: `minions`, `totems`. The GDD
defines no further E4 commitments beyond what is already in Goal/Key stories/Exit criteria above.
- Camera/lock-on (`DP/R1`, `E4-P/R11`) is ADOPTED into E4 via `gds-correct-course`, 2026-08-30 --
  the board-full-of-minions forcing point `E4-P/R11` named has been met (4-4-totems done). Story
  `4-6-camera-lock-on` enters the backlog, board-ordered BEFORE `4-5-pooling-60fps-exit` per
  operator instruction; the numeral is historical/creation-order, not board order (existing
  precedent: `4-3a`..`4-3e` interleaving). Hard Tier A by the golden clause (`HeroState.facing`
  ownership migrates from input- to target-derived).

---

## E5 — Unblockable RPS + Orbs

**Goal.** The combat core of the vision — the RGB read exchange and its payout.

**Key stories.**
- Unblockable Initiation (Mode ②): chargeup + color telegraph (**shape + sound**, <0.5 s), stamina cost, generous auto-aim that does **not** absorb spacing (Reactor/Actor). (`5-2-unblockable-initiation`; telegraph presentation split into `5-3-telegraph-presentation`.)
- Unblockable Defense (Mode ③): instant, color-match, within the chargeup window. (`5-5-unblockable-defense`.)
- **Three-tier outcome ladder** — no-answer/wrong-color → full dmg + attacker orb; dodge/leave-range → none; correct color → none + attacker stun ~1 s. One fixed damage value for all three colors (balance `.tres`) — per-color damage was cut, `5-2/R10`. (`5-6-three-tier-ladder`.)
- Orb resource: acquisition on land, authored per-color storage cap (`max_orbs_per_color = 5`, provisional, `5-4/R8`), HUD counters, an all-color-reset hook (`OrbPool.reset_all()`) used at the round boundary and, optionally, by `6-2`'s staging-clear knob — NOT by `6-3a`'s activation spend, which spends only the priced orbs (`6-3-split/R-SPEND`). (`5-4-orbs`.)
- Color-as-defense: Mode ③ requires a matching-color card in the 4-card hand.
- Pad card-input and dual pad-mode select (mode ② initiation vs mode ③ defense on B/X). (`5-0b-pad-card-input` seats input; `5-7-pad-modes-2-3` ships modes 2/3.)
- `FeatureFlags: unblockable, orbs` (degrade).
- Headless tests: RPS outcomes, orb grant, three-tier resolution, timing via fixed `delta`.

**Exit criteria.** The RGB read loop plays and pays orbs; the ladder reads as fair (playtest); determinism verified in tests.

**Risks.** Defense-window length is the fairness core; telegraph legibility must be judged in the E2 half-width viewport.

**Committed obligations.**
- State takes ownership of the active telegraph fact for RPS; the fact→profile mapping stays
  presentation (1-10/R1, locked).
- Open decision (a) — attacker consequence on basic-attack deflect / stun — is RESOLVED
  (`E5-P/R1`, decision-log Session 2026-09-01): a deflected basic attack now costs the attacker
  both a stamina penalty (new authored balance field) and a short stun, authored markedly shorter
  than the color counter's ~1s so the three-tier ladder keeps its escalation gradient.
  Implementation seat: `5-6-three-tier-ladder`, which also removes the
  `test_balance_authoring.gd` stun exemption.
- `ActionState.CHARGING` is already reserved in the enum (`src/state/hero_state.gd:27`), unused
  until `5-2-unblockable-initiation` wires Mode ② chargeup. Reach is a large authored hit radius
  (provisional ~8 m, new balance field, `E5-P/R4`) that forces the defender to react within it;
  lock-on aims direction only and never extends reach.
- E5 opens with four Tier B presentation/setup stories, in order: `5-0a-hero-locomotion`,
  `5-0b-pad-card-input`, `5-0c-totem-projectile-models`, `5-0d-arena-edge` (the arena bound ships
  as scene collision in `main.tscn`, `E5-P/R2` — no `src/state/` edit, golden immobile by
  construction). `5-0a` and `5-0b` must land before the playtest block.
- `5-1a-intent-hardening` (Tier A) closes the retarget-hardening residue carried from E4: `4-6`
  M3 (a malformed retarget address is logged and then acted on, landing in a hashed key) and
  `4-6` L7/L8 (v6-record robustness), per the `4-1/R1` hard-rejection doctrine.
- `R-M9`: accelerators stack, LINEARLY, per totem, both seats — each accelerator pays its own
  grant per cadence tick (mana seat: Reading A, linear and player-countable, unchanged; stamina
  seat: `baseline x (1 + N x step)`, `step` authored so `N=1` is identical to today's shipped
  behaviour — `5-1/R1`, decision-log Session 2026-09-03, superseding `E5-P/R3`'s stamina clause
  and this line's prior "literal mult^N" reading). Ships in `5-1-accelerator-stacking` (Tier A),
  which also carries the `4-4` M2/M7 authoring-audit bounds.
- `R-SPELL`: spell resolution stays a named no-op through E5 (forcing point is the E6 close-out
  story). No E5 story may assume a spell card resolves; `5-5-unblockable-defense`'s hand-of-four
  math must tolerate three unresolvable cards.

---

## E6 — Pitch Zone (Vision Complete)

**Goal.** Close the buildup→bluff→payoff loop; make the Design Touchstone playable.

**Key stories.** TWENTY-THREE, all `done` (E6 close-out, 2026-10-01, `E6-C/R1`). Keyed and tiered at
the E6 planning pass (decision-log Session 2026-09-08, `E6-P/R2`) with three stories (`6-3`, `6-6`,
`6-5`) later split at their own readiness gates or scope talks — the numeral is historical, not the
board's (the `4-3a`..`4-3e` precedent). The list below is **board order**. Tier per `E4-P/R9`; every
Tier B discharged subject to a measured before/after showing golden and snapshot key set unmoved,
and tier may be raised, never lowered.

1. `6-0-card-hand-tint` (**Tier B**) — the four own-hand card faces carry their card's colour; the
   face-down opponent row is untouched. FIRST E6 story by ruling (`E5-C/R5`).
2. `6-1-hold-to-charge` (**Tier A**) — mode ② is held through the chargeup instead of press-edge; an
   early release needs a `CHARGING` teardown `src/state/` does not have (`5-7/R6`, `E5-C/R6`).
   SUPERSEDED in play terms by `6-9` below; the state shape it added stands.
3. `6-1b-chargeup-presentation` (**Tier B**) — the chargeup animation: crouch/leap, short mid-air
   hover, auto-aim toward a target in radius (`E5-C/R9`).
4. `6-1c-unblockable-tracking-and-reach` (**Tier A**) — tracked blade position and lock-on reach for
   mode ② in place of a fixed hitbox.
5. `6-1d-honest-hit-geometry` (**Tier A**) — the unblockable landing check measures real contact
   (tracked blade position against the defending model), closing the visible gap `6-1c`'s live
   smoke showed.
6. `6-2-pitch-staging` (**Tier A**) — `PitchState` gains content: stage from hand, the fizzle
   `TimingWindow`, the fizzle exit, staged card still counts toward the hand of 4.
7. `6-3a-pitch-activation` (**Tier A**) — Y wired as the fourth card mode: staging, activation, both
   refusals (occupied-zone stage refusal, not-ready activation refusal), activation's consequence
   (`6-3-split/R-SPEND`: only the priced orbs are spent, surplus remains), the intent shape, the
   Y-guard retirement, the golden. Live smoke runs on surfaces that already ship (orb counters,
   in-flight caption, mana bar, the existing rejection cue, the existing cast-success cue) — no HUD
   work. Split from the merged `6-3-pitch-hud-and-activation` at that story's readiness gate
   (2026-09-14, `6-3-split/R-SPLIT`), after the gate disproved the merge's premise that activation
   could not be smoke-tested without a HUD.
8. `6-3b-pitch-hud` (**Tier A**) — the tenth observation seam (`connect_pitch_changed`), both pitch
   zones (own + opponent), the hand ghost, the cross-slot guard, retiring the `2-6` placeholder and
   its shared A/B switch, and the anchor A/B verdict. Driven live by `6-3a`'s Y, so it needs no
   scaffolding either. Same split, same ruling as `6-3a` above.
9. `6-7-locomotion-gaits` (**Tier A**) — the two-gait system ruled at planning: walk is new, slower,
   free and the default; run is the current speed, held, draining the same stamina bar. Walk speed
   and drain-per-second are authored here.
10. `6-7b-locomotion-presentation` (**Tier B**) — walk and turn-in-place animations, the presentation
    half of `6-7`.
11. `6-8-camera-freedom` (**Tier A**, raised at the 2026-09-16 scope talk) — lock-on cycling reaches ALL live targets
    including those behind the hero (full 360, not a front arc), and the camera can be unlocked and
    manually rotated when not locked on.
12. `6-6a-defense-reactions` (**Tier A**) — hurt/knockdown/stun-pose/block-impact reactions, defence
    animation and sound synced to the incoming attack (`E5-C/R9`). First half of `6-6-defense-presentation`,
    SPLIT 2026-09-17 (`6-3-split/R-SPLIT` precedent, scope talk 2026-09-17).
13. `6-6b-color-counters` (**Tier A**) — three color counters per attack type. Second half of the
    `6-6` split.
14. `6-D1-solo-smoke-keys` (**Tier B**) — three P1 keyboard keys that cast an unblockable of a chosen
    colour and hold it through the chargeup, so a solo operator can smoke color counters.
15. `6-9-click-to-commit` (**Tier A**) — mode ② becomes click-and-commit, superseding `6-1`'s
    hold-to-charge: an accepted press locks in the cash-in; no held feint window.
16. `6-10-card-mode-toggle` (**Tier B**) — card mode switchable from "hold L3" to "click L3 on, click
    L3 off" by one authored line, so a pad player can judge which feels better without a code edit.
17. `6-5a-spell-framework-and-buffs` (**Tier A**) — a named, data-driven card-effect framework plus
    five working Deck 1 effects (Ruin Vanguard, Bloodlust, Vampiric Aura, Bloodhound Step,
    Frostbite) with Deck 1 as both players' deck. First of the `6-5` spell-resolution split.
18. `6-5b-corpses-and-own-minions` (**Tier A**) — Grave Ward, Culling, Drain and Raise Dead working
    end-to-end; a corpse becomes real game state, not a purely visual linger.
19. `6-5c-hero-cast-honed-bolt` (**Tier A**) — offensive spells gain a visible cast windup the
    opponent can react to, with Honed Bolt the first card to use it: a bolt that stuns, then roots.
20. `6-5d-fireball-and-spell-targeting` (**Tier A**) — Bloodhound Step's pitch is Fireball, a
    spend-everything homing projectile after a visible cast; offensive spells target the caster's
    lock-on.
21. `6-5e-rocksling-boom-and-corpse-bomb` (**Tier A**) — Rocksling plants Boulder cards face-up in
    the opponent's hand; Boom detonates every Boulder sitting there; Corpse Bomb turns every own
    living minion it targets into a bomb.
22. `6-5f-counterspell` (**Tier A**) — Counterspell reaches back and undoes the opponent's last
    resolved card, reversing what it did rather than merely stopping it.
23. `6-5g-counterspell-timed-and-in-flight` (**Tier A**) — Counterspell reaches back and undoes ANY
    of the opponent's last resolved cards, including the seven that resolve over time or through a
    projectile in flight. LAST E6 story by ruling (`R-SPELL`'s forcing point is the close-out); the
    playtest block runs after it.

- Pitch Zone ownership is **per-player**, both zones visible to both players, staging independent
  (simultaneous pitches legal) — `E6-P`, PROVISIONAL, judged at the post-E6 playtest. This replaces
  the overlap-with-lockout working assumption; the GDD's three disagreeing statements were
  reconciled to it in the same pass.
- Timer **20 s provisional**, an authored balance field (`E6-P`).
- `FeatureFlag: pitch-zone` (off → pitch modes unavailable; if orbs off, pitch cost is mana-only).
  The flag exists and defaults `false` (`src/state/resources/feature_flags.gd:18`); it is absent
  from `data/feature_flags.tres`, so it ships off by export default until a pitch story authors it.

**Exit criteria.** The full touchstone is playable in split-screen; buildup→bluff→payoff exists end-to-end.

**Milestone.** **The vision is now testable.** The go/no-go validation playtests (and the playtester-composition instrumentation from Success Metrics) begin here.

**Committed obligations.**
- `PitchState` gains content at `6-2`; it carries none until E6 (2-6/R9).
- Whether the Pitch Zone mechanic is shared between players or owned per-player was OPEN (2-6/R9 —
  NOT the 2-4 smoke, a citation corrected at E6 planning) and is now RULED per-player, provisional
  (above). Locked and unchanged: the pitched card is the sole public information, hands stay
  private otherwise.
- Pitch zone placement carries into `6-3b-pitch-hud`: the first A/B reading (2-6/R19, finding S4)
  found anchor B (left of the vitals bars) reads better than dead-centre anchor A — a first reading
  only, and that story owes the verdict.
- **Cancel has no owning story.** `6-2` deferred it into the (now-superseded)
  `6-3-pitch-hud-and-activation` slot at its 2026-09-13 readiness gate; neither `6-3a-pitch-activation`
  nor `6-3b-pitch-hud` picks it up at the 2026-09-14 split (`6-3-split/R-SPLIT`). OUT, with two open
  questions carried forward: does a future cancel refund staged mana; does it restore orbs cleared
  by `pitch_stage_clears_orbs` if that knob was ON at stage time.
- **`6-2` scope talk owes the pitch-cost authoring seat.** `CardData` has ONE `cast_condition`
  (`src/state/resources/card_data.gd:40`) shared across modes, `pitch_effect` (`:37`) is unauthored
  on all nine fixture cards, and `CardCastCondition.orb_costs` is empty everywhere by design
  (`src/state/resources/card_cast_condition.gd:29-35`) — so a Mode ④ cost of "mana (higher) + orbs"
  (`gdd.md:178`) has nowhere to live today. Adding a field is codebase-shaping, so it is decided at
  that story's scope talk, not by the implementing pass.
- **`6-3a-pitch-activation` owes the Y-guard question.** `5-7/R7` kept LOW-1/LOW-2 (the guard's
  untested evasion forms and its blanket ban on any future Y binding) as-is "until the E6 story that
  actually wires Y forces the question" — that story is this one. Y is a no-op BY OMISSION
  (`GamepadProfile` has no Y field; `GamepadController` reads Y on no line) and mode PITCH already
  has a live dispatch arm for STAGING (`match_state.gd`, since `6-2`) but activation itself has no
  dispatch at all yet — both must be revisited deliberately, not discovered.
- **`6-5` (split into `6-5a`..`6-5g`) carried `R-SPELL` plus two deferred E4 review findings** given
  it as owner at E5 planning: M5 (the live homing test cannot tell steering-toward from
  steering-away) and M6 (reordering `unit_kinds` at an X3 reload silently re-points every live
  record) — BOTH CLOSED, annotated in place at `deferred-work.md:302-303` (M5 by 6-5d AC 37,
  `6-5d/R14`; M6 by 6-5d AC 38, `6-5d/R12`). Three fixture cards carried `spell_*` ids
  (`data/cards/{ember_lash,frost_dart,bramble_snare}.tres:9`) before the split's effects replaced them.
- **`6-7b` has an ASSET PREREQUISITE:** the Mixamo walk clips for the paladin must physically be in
  the repo BEFORE that story's create pass. Operator-owned manual step, recorded here because E3
  learned it the hard way.
- `6-1b` and `6-6` (`6-6a`/`6-6b`) DISCHARGED the "chargeup unreadable" and "defense feel reads as
  the defender did nothing" retune entries in passing (`deferred-work.md`, E5 residue) — now facts,
  not expectations.
- `6-7` SUPERSEDED the `5-3/R6(d)` retune entry (locomotion speed / walk-as-default /
  sprint-costs-stamina) — same ground, now ruled rather than deferred.
- The direct-connect exception is now an enumerated list of **TWO** instances
  (`card_cast_resolved` at `match_runner.gd:644`, `counterspell_resolved` at `match_runner.gd:662`,
  `E6-C/R2`); a further instance needs same-story entries in both `game-architecture.md` and the
  RAW allow-list in `test_architecture_invariants.gd`. The observation-seam family is now **TEN**
  members since `connect_pitch_changed` (`6-3b`, `E6-P/R8`(2)).

---

## E7 — Presentation, Polish & Playtest Prep

**Goal.** Give E6's mechanics the presentation they are missing, work off the tooling and
smoke-claim debt E6 left behind, and reach the friends playtest. Operator rulings 2026-09-30 /
2026-10-01 (`E6-C/R11`); order below is the operator's stated order.

**Key stories.**
1. `7-T1-tooling-debt` (**Tier B**) — the m5 replay-drop coverage gap and the `6-5b/R24` flake,
   alongside the operator's asset gathering.
2. `7-1-effect-presentation` (**Tier B**) — Deck 1 effect visuals and sounds; absorbs the Grave Ward
   tint fix, the eleven effects with no bespoke visual, and the placeholder bolt/fireball/stones/
   skulls/Boulder art.
3. `7-2-animation-polish` (**Tier B**, raised to **A** if authored timing windows move) — upper/lower
   body split, hit-reaction sliding.
4. `7-3-minion-rework` (**Tier A**) — operator asset search first.
5. `7-4-pitch-speeds` (**Tier A**) — per-card instant/sorcery field; instant pays from banked orbs,
   sorcery needs orbs earned between pitch and fizzle; plus +1 mana for a defended unblockable.
6. `7-5-deck-2` (**Tier A**) — design pending.
7. `7-6-hud-and-card-presentation` (**Tier B**) — cost legibility, hand icons, per-effect cast
   feedback, new HUD.
8. `7-7-tuning-pass` (**Tier B**, raised to **A** if a seat is added or an action becomes
   refusable) — the retune block, carrying the `6-1d/R16` reach/homing, dodge-cost, and GREEN
   travel-profile inputs.

**Deferred until after the friends playtest:** counter-on-counter (`6-5g/R17`), the deck builder.

**Exit criteria.** The friends playtest is run with the presentation and tuning debt named above
discharged or explicitly carried into it.

**Note.** The E6 retrospective and the friends playtest itself get no board keys (precedent:
retrospectives have never been board keys).

---

## E8 — Scripted Bot

**Goal.** Solo iteration without a second human.

**Key stories.**
- Scripted AI controller **implementation** (a config swap on the E0 controller abstraction — no hero/state changes): approach/circle, interval basic attacks, occasional roll, fixed unblockable pattern.
- Tunable via data where practical.

**Exit criteria.** Solo-playable vs the bot; achieved purely as a controller implementation.

**Note.** This is **not** the bluffing AI (deferred). It cannot lie, stage unaffordable pitches, or fold — and therefore cannot test P3.

---

## E9 — Equipment

**Goal.** The equipment passive layer, toggleable.

**Key stories.**
- Four slots (head / chest / arms / legs); `EquipmentData` Resource with **data-defined** passive effects.
- Pre-match selection (placeholder stats; no on-hero visuals).
- Passive effect types applied via state: combat-timing, threshold-based, cooldown-immunity, resource modifiers, stat adjustments.
- `FeatureFlag: equipment` (off → none equipped).

**Exit criteria.** Equipment passives modify hero behavior; fully data-driven; flag toggles.

**Note.** Placeholder stats only; on-hero visual representation deferred (TDD §15).

---

## Deferred Epics (post-demo, if the demo validates)

- **Bluffing AI** — the hardest AI in the project; must decide when to lie, stage unaffordable cards, and fold. Its own epic; the only thing that truly tests P3 without a human.
- **Online netcode** — the state/visual separation and controller abstraction exist to make this an added layer, not a rewrite.
- **Best-of-3 + sideboard** — round format and between-round adaptation.
- **Equipment visuals** — on-hero representation (Elden Ring style).
- **Multiple arenas** — additional layouts.
