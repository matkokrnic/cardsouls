---
title: CardSouls — E3 Stories (Card System + Mana Economy)
parent: epics.md
epic: E3
created: 2026-07-21
updated: 2026-08-06
status: ready
depth: intentionally thinner than E1/E2
---

# E3 — Card System + Mana Economy

**Epic goal.** The card-economy foundation and the aggression flywheel (P2): melee hits fund mana,
mana plays cards.

> ## ✅ Revisit gate — RAN 2026-07-31, and E3 is COMPLETE
>
> **The gate this block demanded has been executed and E3 has since shipped.** The gate ran
> 2026-07-31 (`decision-log.md` Session 2026-07-31 — E3 revisit gate (outcome), `E3-RG/R1`-`E3-RG/R12`),
> verdict **E3 proceeds AMENDED**: five of six stories amended, none deleted, the epic's shape and
> exit criteria unchanged. Every story in this file has since passed its own readiness gate, been
> implemented, and been closed `done` (`3-1`, `3-2`, `3-3`, `3-4`, `3-5a`, `3-5b`, `3-6`, alongside the
> substrate stories `3-0a`-`3-0d`); E3 closed 2026-08-06.
>
> **Nothing in this file is provisional any longer, and no story below is awaiting a gate.** It is now
> a historical record of the epic's authored intent. Read it as such — where it disagrees with
> `decision-log.md` or the shipped `src/`, they win.
>
> The original gate text is kept below for the record, unedited.
>
> ---
>
> **These stories are provisional and must be reviewed after the first E1/E2 playtest, before
> implementation.** They were written before anyone had played the melee layer against a human, and
> they rest on assumptions about how melee actually feels — attack cadence, how much downtime a
> player has between exchanges, whether there is any attention left over for a hand of cards at all.
> That is exactly the P4 question this project exists to answer, and it cannot be answered from a
> document.
>
> The gate is a real step, not a formality: after the E2 playtest, re-read this file against
> `docs/playtest-log.md` and either confirm each story, amend it, or delete it. Record the outcome in
> `decision-log.md`. Each story below repeats this instruction in its own text so it survives being
> read in isolation.
>
> Specific assumptions most likely to break: the draw-replacement delay, whether a mode-select input
> is viable under real-time pressure at all, how large a mana pool the melee cadence justifies, and
> whether the 4-card hand reads at half width during an exchange.

**Precondition.** E1 and E2 complete, and the first two-human playtest has happened and is written up.

## Before you start

1. Same document precedence and invariants as E1/E2 — see `stories-e1.md` §Before you start and
   `CLAUDE.md`.
2. **Additional architecture reading:** §D6 (`ResourceGenerationRule` / `CardCastCondition` + pure
   evaluator), Novel Pattern 5 (evaluator), Novel Pattern 6 (four-mode card resolution),
   §Project Structure → *Planned (E3) — `MatchState` config object*, §Determinism & Replay (the
   seeded RNG is consumed only inside `advance()`).
3. **Hand size is balance, not a constant.** The hand of 4 is a defensive lever (colour-as-defense,
   Mode ③), so it lives in balance `.tres` like every other number.
4. **Only Mode ① lands in E3.** Modes ②/③ are E5 and Mode ④ is E6. The `resolve()` branches for them
   stay guarded stubs.

---

## E3.S1 — `MatchState` config object + card/economy balance schema

**Depends on:** E1, E2, and the revisit gate.
**Read first:** architecture §Project Structure → *Planned (E3) — `MatchState` config object* (this
refactor is explicitly scheduled for E3, while call sites are still few).

> **Revisit note — CLOSED 2026-08-06.** Shipped as `3-1-matchstate-config-object`, `done` 2026-08-02
> (`decision-log.md` Session 2026-08-02 — Story 3-1 readiness gate, and 3-1 close-out). The seed was
> deliberately kept OUT of the hot-reloadable config and put in a separate `MatchParams`
> (`E3-RG/R9`) — a plain reading of item 1 below would have got that wrong.

1. Fold `MatchState`'s five positional constructor floats (`seed`, `max_hp`, `move_speed`,
   `max_stamina`, `max_mana`) into a single injected config/params object, and update the small number
   of existing call sites. Doing this before E3 adds card and economy fields is the entire point of
   the scheduled timing — retrofitting it after many callers exist is the failure mode.
2. Extend the balance schema with the E3 fields: `hand_size`, `deck_size`, `max_mana`,
   `mana_regen_per_second`, `mana_per_melee_hit`, `draw_replacement_delay_seconds`,
   `reshuffle_vulnerable_window_seconds`, `default_copies_per_card`. All values TBD-in-playtest.
3. Convert every new `*_seconds` field to ticks once at load through the E1.S1 conversion boundary,
   and confirm the X3 hot-reload path re-converts them and re-injects the new bounds into `ManaPool`.
4. Extend the `.tres` smoke test and the determinism regression to cover the new config shape, so a
   missing or renamed field fails a test rather than surfacing as a mysterious zero mid-playtest.
5. Keep the state layer's injection discipline: state receives the config object and the
   `FeatureFlags` resource by injection and never reads `BalanceConfigService` or
   `FeatureFlagsService`. Re-run the architecture invariant test after the refactor.

**Exit criterion.** `MatchState` takes one injected config object, every E3 balance field is authored
and tick-converted at load, hot-reload re-applies them, and the invariant and smoke tests are green.

---

## E3.S2 — Card schemas, `CardDatabase`, and the first authored cards

**Depends on:** E3.S1.
**Read first:** architecture Novel Pattern 6, §D6; GDD §Card System (card anatomy, worked example
*Imp Summoner*).

> **Revisit note — CLOSED 2026-08-06.** Shipped as `3-2-card-schemas-carddatabase`, `done` 2026-08-03
> (`decision-log.md` Session 2026-08-03 — Story 3-2 readiness gate, and 3-2 close-out). Item 1's
> `CardData` field list is superseded by the shipped six-export schema (`id` and `max_copies` added),
> recorded as architecture-amendment queue member 6, flushed into `docs/game-architecture.md` at
> ledger entry A5.

1. Implement the schema resources in `src/state/resources/`: `CardData` (`color`, `basic_effect`,
   `pitch_effect`, `cast_condition`, `max_copies`), `CardEffect` as the reserved effect schema, and
   `CardCastCondition` (`mana_cost`, per-colour `orb_costs`, flags). Modes ②/③ derive from `color`
   and carry no per-card data.
2. Author a small starter set of cards as `.tres` in `data/cards/` — enough to fill a deck with a
   roughly balanced colour ratio, including the GDD's *Imp Summoner* as the worked example. Only the
   Mode ① effect needs a real value in E3; `pitch_effect` is authored as a placeholder for E6.
3. Complete `CardDatabase` (the existing autoload) so it preloads every card `.tres` at startup and
   exposes lookup by id. Content is loaded by a `systems/` service; the state layer receives card
   resources by injection and never reads the autoload.
4. Keep the per-colour unblockable damage out of `CardData` entirely. It is a fixed value per colour
   in balance (GDD §C, TDD §7.5) — a documented easy-to-get-wrong rule. Add an `Invariant.check` or a
   test that fails if a per-card damage field ever appears. (Symbol corrected 2026-08-06: this item
   read `check_invariant`, which names nothing in this repo; the shipped helper is `Invariant.check`,
   `src/systems/invariant.gd`. Same defect as the one corrected in E3.S5a's amendment note below and
   in `docs/game-architecture.md` at ledger entry A5 — this was its last live instance.)
5. Extend the `.tres` smoke test to load every authored card and assert required fields, a valid
   colour enum, and a copy cap within bounds.

**Exit criterion.** Cards are authored as `.tres`, loaded by `CardDatabase` at startup, validated by the
smoke test, and adding a new card requires no code change. Injection into state has no consumer until
E3.S5 (the card-play story), which is where that clause is discharged.

---

## E3.S3 — Deck, hand, draw, and reshuffle

**Depends on:** E3.S2.
**Read first:** GDD §Card System → Deck & hand; architecture §Determinism & Replay (RNG consumed
only inside `advance()`).

> **Revisit note — CLOSED 2026-08-06.** Shipped as `3-3-deck-hand-draw-reshuffle`, `done` 2026-08-03
> (`decision-log.md` Session 2026-08-03 — Story 3-3 readiness gate, and 3-3 close-out). Items 3 and 4
> (draw-replacement delay, exhaustion/reshuffle/vulnerable window) did NOT land here: the 3-3 gate
> ruled they move to 3-5 together with their trigger, and they shipped in E3.S5b. `Deck`/`Hand` and the
> seeded step-6 shuffle are 3-3's. Open decision (b) — what "vulnerable" costs mechanically — is still
> OPEN and deliberately unpriced (`3-5b/R7`).

1. Implement `Deck` and `Hand` in `src/state/` as pure objects owned by `PlayerState`: shuffle, draw,
   discard, and reshuffle-on-exhaustion, sized from balance (`deck_size`, `hand_size`).
2. Draw exclusively from the seeded gameplay RNG owned by `MatchState`, consumed only inside
   `advance()` step 6. A draw from anywhere else silently breaks replay — this is the F2 hole the
   architecture closed, so add a test that two matches with the same seed draw identical sequences.
3. Implement draw-on-play with the delay as **data**: `draw_replacement_delay_seconds` converted to a
   `TimingWindow`, where zero means instant. Instant vs delayed is an open feel question (GDD:
   "affects strategic tension") — build it so a playtest answers it by editing a `.tres`.
4. Implement deck exhaustion → reshuffle with the vulnerable window as a `TimingWindow` on the
   player, flagged visually to both players via a queued signal. What "vulnerable" costs mechanically
   is not specified in the GDD; do not invent it — emit the state and log the question in
   `decision-log.md`.
5. Headless tests: hand refills to `hand_size` at round start; playing a card draws exactly one after
   the authored delay; a staged-card slot (reserved for E6) would still count toward the hand;
   exhaustion reshuffles the discard pile and opens the vulnerable window for the authored ticks;
   same-seed draw sequences match.

**Exit criterion.** Each player's hand fills to `hand_size` at match start and on debug reset from a
deck shuffled by the seeded RNG inside `advance()`. Draw-on-play, exhaustion-reshuffle, and the
vulnerable window have no consumer until E3.S5 (the card-play story), which is where those clauses are
discharged.

---

## E3.S4 — Mana economy and the melee→mana flywheel

**Depends on:** E3.S1.
**Read first:** GDD §B Mana Economy, pillar P2; architecture §D6 + Novel Pattern 5;
`project-context.md` HARD RULE — feature flags.

> **Revisit note — CLOSED 2026-08-06.** Shipped as `3-4-mana-economy-flywheel`, `done` 2026-08-02
> (`decision-log.md` Session 2026-08-02 — Story 3-4 readiness gate, and 3-4 close-out). Item 2's "the
> hook already exists" framing was correct and item 2's "no new call site" held: the evaluator FULLY
> REPLACED the direct mana path under `E3-RG/R8`'s proof obligation rather than sitting behind it.
> Whether the flywheel reads as a flywheel or as bookkeeping is still an open FEEL question — its
> criterion (a round finances 2-4 loop cycles) became judgeable only once the full loop shipped, and
> the melee retune it feeds is scheduled, not resolved (`decision-log.md` Session 2026-08-06 — E3
> retrospective ruled).

1. Author the mana sources as `ResourceGenerationRule` `.tres`: `passive_tick` (a fixed per-tick
   amount converted once at load, never `rate × delta`) and `melee_hit` (a burst on a confirmed
   contact). The Mana Accelerator totem (E4) must be addable later as a third `.tres` with no code
   change — that is the test of whether this story was done right.
2. Wire the melee-hit rule into the hook E1.S5 already calls on confirmed contact. No new call site,
   no new branch in the combat code — the rule now simply exists where before there was none.
3. Implement `FeatureFlag: melee_mana_generation` as graceful degradation: off → the passive rule
   alone applies and the game remains playable, with no error and no special-case path. The flags
   resource is injected into state; state never reads `FeatureFlagsService`.
4. Complete `ManaPool` regen and bounds through the injected config, with a queued `mana_changed`
   signal, and connect it to the mana bar the E2 HUD already renders.
5. Headless tests covering the flag matrix (project-context testing rule): with the flag on, N landed
   hits produce the authored mana; with it off, only passive accrues; the pool clamps at max; the
   evaluator applies exactly the rules matching a source and ignores the rest.

**Exit criterion.** Melee hits fund mana through an authored `.tres` rule with no new call site, the
flag toggles cleanly in both directions, and both paths are asserted headless.

---

## E3.S5a — Card-mode selection input and Basic (Mode ①) resolution

**Depends on:** E3.S3, E3.S4.
**Read first:** GDD `[NOTE FOR DESIGNER]` *Card-mode selection UX — open, high P4 relevance*;
architecture Novel Pattern 6.

> **Revisit note — CLOSED 2026-08-06.** Shipped as `3-5a-card-mode-select-basic-resolution`, `done`
> 2026-08-04. Item 4's "emit the effect through the `CardEffect` seam" did NOT ship as written: AC5
> emits the resolved card ID, not a `CardEffect`, an accepted deviation because the cost-injection
> seam injects costs only. `CardEffect` therefore still has NO consumer in `src/` — E4's business.
> The 2026-08-04 note below stands unedited as the record.
>
> **Revisit note (2026-08-04, historical).** The E3 revisit gate RAN 2026-07-31 (decision-log Session 2026-07-31 — E3 revisit
> gate (outcome), E3-RG/R1-R12) and this section's own readiness gate RAN 2026-08-04 (decision-log
> Session 2026-08-04 — Story 3-5 readiness gate). "Confirm or amend before implementing" no longer
> applies to this section — both gates have already run and their outcomes are recorded in
> `decision-log.md`. Whether a real-time mode selection is viable at all under the full mode set still
> depends on how much attention the melee layer leaves free; that question is not settled by either
> gate and its forcing point is E5, when the additional modes land (only Mode ① ships in E3).
>
> **Split note (2026-08-04).** This section was `E3.S5` until this story's own readiness gate split it
> into E3.S5a (THE TRIGGER — this section) and E3.S5b (WHAT THE TRIGGER MAKES REACHABLE, below), on
> the 3-3 gate's ruling that discard/exhaustion/reshuffle/vulnerable-window "move to 3-5 together with
> their trigger — not split from it." That ruling is honoured, not overturned: E3.S5b lands after
> E3.S5a's trigger exists. See `decision-log.md` Session 2026-08-04 — Story 3-5 readiness gate.
>
> **Amended 2026-08-04.** Items 1 and 2 below carried three defects forward from the pre-gate story
> text into this manual section: item 1 named a staging verb that does not ship this story (the pitch
> zone is an E6 flag and is off; 3-5a's AC12 deletes the reserved action as unconsumed, on the
> retired-`pose_id` precedent); item 2 said card actions are ingested at `advance()` step 1, when they
> are READ at step 6 (step 1 ingests only the debug reset); and item 2 named a guard helper,
> `check_invariant`, that names no real symbol (the shipped helper is `Invariant.check`). Corrected
> below so this manual does not reseed the same defects at the next gate.

1. Extend `InputIntent` with the card fields (selected hand slot, selected mode, play/cancel
   actions) and produce them in the controllers only. Choose **one** provisional mode-select scheme
   (radial, hold-modifier + slot, or per-mode bind) and implement it as the controller's concern, so
   swapping schemes touches `src/controllers/` and nothing else.
2. Card actions are READ at step 6 of `advance()` — not ingested at step 1, which ingests only the
   debug reset — and resolved there through the `resolve()` dispatch of Novel Pattern 6.
   `ModeKind.BASIC` resolves; `UNBLOCKABLE_INIT`, `UNBLOCKABLE_DEFENSE`, and `PITCH` remain stubs
   guarded by `Invariant.check` / feature flag.
3. Gate every cast through `CardCastCondition` evaluated against `PlayerState` — never an inline mana
   comparison at the call site. With orbs flagged off, a condition's orb costs degrade to
   mana-only, which is the documented graceful-degradation example.
4. Resolve Mode ① as far as E3 honestly goes: pay the mana, discard, trigger the draw from E3.S3, and
   emit the effect through the `CardEffect` seam. Real minions and totems are E4 — a resolved summon
   that queues a signal nothing consumes yet is correct here; a fake placeholder actor is not.
5. Headless tests: a cast at exactly the cost succeeds and one below is rejected with a signal the
   HUD can show; the card leaves the hand and a replacement is drawn; the E5/E6 modes are unreachable
   in E3; the RNG state after a cast is identical for the same seed and inputs.

**Exit criterion.** A player selects a card and plays it in Mode ① under real-time pressure, mana is
paid through `CardCastCondition`, the card is discarded and replaced, and the E5/E6 modes remain
guarded stubs.

---

## E3.S5b — Draw-replacement delay, deck exhaustion, and the reshuffle vulnerable window

**Depends on:** E3.S3, E3.S5a.
**Read first:** GDD §Card System → Deck & hand; architecture §Determinism & Replay (RNG consumed
only inside `advance()`).

> **New section, authored 2026-08-04** at this story's own readiness gate, splitting `E3.S5` into THE
> TRIGGER (E3.S5a, above) and WHAT THE TRIGGER MAKES REACHABLE (this section). Carries the four items
> 3-3's own gate ruled move to 3-5 together with their trigger — not split from it (`decision-log.md`
> Session 2026-08-03 — Story 3-3 readiness gate, finding (v)) — reachable only once E3.S5a's cast path
> exists.
>
> **CLOSED 2026-08-06.** Shipped as `3-5b-draw-delay-exhaustion-reshuffle`, `done` 2026-08-04
> (`decision-log.md` Session 2026-08-04 — Story 3-5b readiness gate, and 3-5b close-out). Both
> durations are authored data (`draw_replacement_delay_seconds`,
> `reshuffle_vulnerable_window_seconds = 1.5`), so the remaining feel question is answered by editing
> a `.tres`, exactly as item 1 intended. Open decision (b) stays OPEN by construction: nothing in
> `src/` reads the vulnerable window except the code that starts it and the code that emits its event
> (`3-5b/R7`), so nothing has priced it.

1. Implement draw-on-play with the delay as **data**: `draw_replacement_delay_seconds` converted to a
   `TimingWindow`, where zero means instant. Instant vs delayed is an open feel question (GDD:
   "affects strategic tension") — build it so a playtest answers it by editing a `.tres`.
2. Implement deck exhaustion → reshuffle-from-discard, landing in the same single step-6 RNG seat that
   the E3.S3 shuffle and deal already use — not a second seat.
3. Implement the reshuffle vulnerable window as a `TimingWindow` on the player, flagged visually to
   both players via the ownerless `EventBus` event ruled at the E3 revisit gate (E3-RG/R3), on the
   `round_started`/`round_ended` precedent. What "vulnerable" costs mechanically is not specified in
   the GDD; do not invent it unless this story's own gate rules open decision (b) — emit the state and
   keep the question open otherwise.
4. Headless tests: playing a card draws exactly one after the authored delay; exhaustion reshuffles
   the discard pile and opens the vulnerable window for the authored ticks; the vulnerable-window
   event fires with the correct player payload; same-seed draw sequences match across the delay and
   the reshuffle.

**Exit criterion.** A played card's replacement arrives after the authored (possibly zero) delay; a
deck that runs out reshuffles from its own discard pile inside the same seeded-RNG seat as the initial
shuffle; the reshuffle vulnerable window is visible in both viewports via the `EventBus`; and
`bash test/run_all.sh` is green including the delay and reshuffle determinism tests.

---

## E3.S6 — Card HUD: hand, mana, deck and reshuffle indicators

**Depends on:** E3.S5, E2.S4, E2.S5.
**Read first:** GDD §Legibility Principle, pillar P4 and the Reactor/Actor principle; E2.S4/E2.S5.

> **Revisit note — CLOSED 2026-08-06.** Shipped as `3-6-card-hud-hand-mana-deck`, `done` 2026-08-06
> (`decision-log.md` Session 2026-08-06 — Story 3-6 readiness gate, and 3-6 close-out). The P4 finding
> item 2 demanded was made and PASSED at the live smoke, written up by the operator's own hand in
> `docs/playtest-log.md` 6.8. Item 1's "opponent's face-down" did NOT ship: `E3-RG/R4` deleted the
> opponent hand row outright — it rendered a count whose publicity was never decided — so the
> reveal-opponent-hand toggle is deferred with a home and no story number (`3-6/R1`). Item 3's
> "public information" survives: the reshuffle flag renders in both viewports, while deck and discard
> counts stay private (`3-6/R7`).

1. Populate the hand strip reserved in E2.S4 with real cards, inside the existing per-viewport
   privacy rule from E2.S5 — own hand face-up, opponent's face-down. Do not add a new rendering path
   for cards; use the slot whose privacy behaviour already works.
2. Render the mode-selection affordance from E3.S5 in the HUD at half width, and judge it against P4:
   during an exchange the reactor must never be reading a menu. If it cannot be read at speed, that
   is a finding for `docs/playtest-log.md` and `decision-log.md`, not something to shrink the font
   for.
3. Add the deck-count and reshuffle indicators, with the vulnerable window from E3.S3 clearly flagged
   in **both** viewports — reshuffle vulnerability is public information by design.
4. Keep the HUD signal-driven per D5: everything updates from queued signals drained after
   `advance()`, with no polling and no economy recomputation per frame. Affordability is *read*, not
   computed by the player — the Reactor/Actor offload, which E6's pitch affordability display
   inherits.
5. Verify in the real viewport: at final resolution and half width, identify hand contents, mana
   level, and deck state during an actual exchange, and record whether it was possible in
   `docs/playtest-log.md`.

**Exit criterion.** The 4-card hand, mana bar, and deck/reshuffle indicators render in the real
half-width HUD, driven by signals, with the opponent's hand face-down, and their readability during
live combat has been assessed and written down.

---

## Epic exit criteria (E3 complete when all hold) — ALL HOLD, E3 CLOSED 2026-08-06

1. Mode ① cards are playable at a mana cost, gated by `CardCastCondition`.
2. Melee hits fund mana through an authored rule; the flywheel is observable in play.
3. Both `melee_mana_generation` flag paths play acceptably with graceful degradation.
4. Deck, hand, draw, and reshuffle run in the state layer from the seeded RNG inside `advance()`.
5. `bash test/run_all.sh` is green, including the flag matrix and same-seed draw determinism.
6. The revisit gate has been executed and its outcome recorded in `decision-log.md`.

## Explicitly out of scope for E3

Minions and totems as real actors (E4), unblockable modes and orbs (E5), the Pitch Zone and Mode ④
(E6). Mode ① summons resolve through the effect seam and queue a signal that nothing consumes yet;
that is the correct E3 state.
