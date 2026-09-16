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

**Key stories.** ELEVEN, keyed and tiered at the E6 planning pass (decision-log Session 2026-09-08,
`E6-P/R2`); briefly merged to TEN at the `6-3-pitch-hud-and-activation` create pass (2026-09-14,
board items 5/6 combined), then split back to ELEVEN the same day at that story's readiness gate
(`6-3-split/R-SPLIT`) after the gate found the merge's forcing premise disproved. Keys are creation
order; the list below is **board order**
(the `4-3a`..`4-3e` precedent — the numeral is historical, not the board's). Tier per `E4-P/R9`;
every Tier B is contingent on a measured before/after showing golden and snapshot key set unmoved,
and tier may be raised, never lowered.

1. `6-0-card-hand-tint` (**Tier B**) — the four own-hand card faces carry their card's colour; the
   face-down opponent row is untouched. FIRST E6 story by ruling (`E5-C/R5`).
2. `6-1-hold-to-charge` (**Tier A**) — mode ② is held through the chargeup instead of press-edge; an
   early release needs a `CHARGING` teardown `src/state/` does not have (`5-7/R6`, `E5-C/R6`).
3. `6-1b-chargeup-presentation` (**Tier B**) — the chargeup animation: crouch/leap, short mid-air
   hover, auto-aim toward a target in radius (`E5-C/R9`).
4. `6-2-pitch-staging` (**Tier A**) — `PitchState` gains content: stage from hand, the fizzle
   `TimingWindow`, the fizzle exit, staged card still counts toward the hand of 4.
5. `6-3a-pitch-activation` (**Tier A**) — Y wired as the fourth card mode: staging, activation, both
   refusals (occupied-zone stage refusal, not-ready activation refusal), activation's consequence
   (`6-3-split/R-SPEND`: only the priced orbs are spent, surplus remains), the intent shape, the
   Y-guard retirement, the golden. Live smoke runs on surfaces that already ship (orb counters,
   in-flight caption, mana bar, the existing rejection cue, the existing cast-success cue) — no HUD
   work. Split from the merged `6-3-pitch-hud-and-activation` at that story's readiness gate
   (2026-09-14, `6-3-split/R-SPLIT`), after the gate disproved the merge's premise that activation
   could not be smoke-tested without a HUD.
6. `6-3b-pitch-hud` (**Tier A**) — the tenth observation seam, both pitch zones (own + opponent), the
   hand ghost, the cross-slot guard, retiring the `2-6` placeholder and its shared A/B switch, and
   the anchor A/B verdict. Driven live by `6-3a`'s Y, so it needs no scaffolding either. Same split,
   same ruling as `6-3a` above.
7. `6-7-locomotion-gaits` (**Tier A**) — the two-gait system ruled at planning: walk is new, slower,
   free and the default; run is the current speed, held, draining the same stamina bar. Walk speed
   and drain-per-second are authored here.
8. `6-7b-locomotion-presentation` (**Tier B**) — walk and turn-in-place animations, the presentation
   half of `6-7`.
9. `6-8-camera-freedom` (**Tier A**, raised at the 2026-09-16 scope talk) — lock-on cycling reaches ALL live targets
   including those behind the hero (full 360, not a front arc), and the camera can be unlocked and
   manually rotated when not locked on.
10. `6-6-defense-presentation` (**Tier B**, at risk of Tier A) — defence animation and sound synced
    to the incoming attack (`E5-C/R9`).
11. `6-5-spell-resolution` (**Tier A**) — the E6 CLOSE-OUT story: the three `spell_*` fixture cards
    stop taking the named no-op path. LAST by ruling — `R-SPELL`'s forcing point is the close-out,
    and the playtest block runs after it.

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
- **`6-5` (close-out) carries `R-SPELL` plus two deferred E4 review findings** given it as owner at
  E5 planning: M5 (the live homing test cannot tell steering-toward from steering-away) and M6
  (reordering `unit_kinds` at an X3 reload silently re-points every live record) —
  `deferred-work.md:232-233`. Three fixture cards carry `spell_*` ids today
  (`data/cards/{ember_lash,frost_dart,bramble_snare}.tres:9`).
- **`6-7b` has an ASSET PREREQUISITE:** the Mixamo walk clips for the paladin must physically be in
  the repo BEFORE that story's create pass. Operator-owned manual step, recorded here because E3
  learned it the hard way.
- `6-1b` and `6-6` are expected to discharge the "chargeup unreadable" and "defense feel reads as
  the defender did nothing" retune entries in passing (`deferred-work.md`, E5 residue). The rule
  that retune stays out of E6 bars slotting a retune ENTRY as a story; it does not forbid fixing one
  an E6 story lands on anyway.
- `6-7` SUPERSEDES the `5-3/R6(d)` retune entry (locomotion speed / walk-as-default /
  sprint-costs-stamina) — same ground, now ruled rather than deferred.
- `6-3b-pitch-hud` may NOT reach for a second `MatchState` direct-connect: `E5-C/R2` documents that
  exception at exactly one instance (`src/main/match_runner.gd:501`) and a third is the operator's
  call. The observation-seam family (nine members since `connect_orbs_changed`, `E5-C/R3`) is the
  route.

---

## E7 — Scripted Bot

**Goal.** Solo iteration without a second human.

**Key stories.**
- Scripted AI controller **implementation** (a config swap on the E0 controller abstraction — no hero/state changes): approach/circle, interval basic attacks, occasional roll, fixed unblockable pattern.
- Tunable via data where practical.

**Exit criteria.** Solo-playable vs the bot; achieved purely as a controller implementation.

**Note.** This is **not** the bluffing AI (deferred). It cannot lie, stage unaffordable pitches, or fold — and therefore cannot test P3.

---

## E8 — Equipment

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
