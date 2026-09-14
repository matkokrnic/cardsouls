---
baseline_commit: 74c1ddd6568fead41705c591646a3eda741de187
---

# Story 6.2: Pitch Staging

Status: done

> **Scope note.** E6 planning pass, board order item 4 (decision-log Session 2026-09-08,
> `E6-P/R2`). Tier A by the golden clause (`E4-P/R9`) — `E6-P/R2` itself predicts the golden
> moves "by construction": `MatchState.to_snapshot()` already carries the `"pitch"` key
> (`match_state.gd:953`), so any field `PitchState` gains moves the hash. Per-player, independent
> staging is RULED, provisional, at `E6-P/R4`; the 20s timer is RULED, provisional, at `E6-P/R5`.
> **`E6-P/R9` names this exact scope talk as the place a pitch-cost authoring seat gets decided**
> ("Adding a field is codebase-shaping under CLAUDE.md's autonomy test, so it is DECIDED AT THAT
> SCOPE TALK and not by the implementing pass") — AC 1/2 below discharge it.
>
> **Cancel deferred to `6-4`, named not silent.** `epics.md:209` lists 6-2 as owning "cancel and
> fizzle exits". This story does NOT author a cancel exit: cancel is a player-triggered action and
> 6-2 wires no player input at all (the stage/activate/cancel buttons are `6-4`'s, per
> `epics.md:212`/`E6-P/R8`(8) and the Y-guard obligation at `6-4`). A state transition with no way
> to trigger it is an unreachable branch this project has repeatedly refused to author (the cast
> evaluator held back until it had a consumer at `3-2`/`3-5`; `pose_id` retired for the same
> reason; `6-1d` shipped a button whose effect could not be classified). `6-4` inherits the cancel
> exit as committed scope from `epics.md:209`, not as new scope this story invents.

## Measured Facts

1. **`PitchState` is a single, never-started reserved object, not per-player.** `PitchState`
   (`src/state/pitch/pitch_state.gd`) holds one `_fizzle := TimingWindow.new()` and
   `to_snapshot()` returns `{"fizzle": _fizzle.to_snapshot()}` — the entire class, six lines of
   logic. `MatchState` owns ONE instance (`var pitch: PitchState`, `match_state.gd:173`),
   constructed once in `_init()` (`match_state.gd:377`) and never started. Nothing else in
   `src/` constructs, starts, or reads it besides `to_snapshot()`
   (`match_state.gd:953`). `E6-P/R4` rules the zone PER-PLAYER — this story reshapes `PitchState`
   (or its ownership) to carry two independent records; the exact shape (two `PitchState`
   instances, one per `PlayerState`, vs. one object with per-slot internal arrays — the
   `_lock_directions[slot]` precedent) is an implementation choice, not decided here.

2. **The `"pitch"` snapshot key IS in the hashed run today, and its current payload is fixed.**
   `MatchState.to_snapshot()` includes `"pitch": pitch.to_snapshot()` (`match_state.gd:953`),
   which is `{"fizzle": {"duration_ticks": 0, "elapsed_ticks": 0, "is_running": false}}` on every
   run today (`TimingWindow.to_snapshot()`, `timing_window.gd`) — CONSTANT, because nothing starts
   the window. **Golden prediction: MOVED.** Any field `PitchState` gains — even an empty/null
   per-player staged-card record — changes the SHAPE of the `"pitch"` dict, which moves the hash
   regardless of whether the golden's own sequence ever stages a card. This is certain by
   construction, not by reachability (`E6-P/R2`'s own prediction, decision-log.md ~line 9313).

3. **`_resolve_card_action`'s PITCH arm is a guarded `Invariant.check(false, ...)` crash stub.**
   `match_state.gd:2512-2539`: the `match intent.card_mode` block has real arms for `BASIC`
   (`Enums.ModeKind.BASIC`, story 3-5a), `UNBLOCKABLE` (story 5-2) and `DEFENSE` (story 5-5); the
   `_` arm — PITCH's only path today — calls
   `Invariant.check(false, "card mode %d is a guarded stub and is unreachable in E3 (only BASIC
   resolves)" % int(intent.card_mode))`. Reaching it crashes the match; this story gives PITCH its
   own arm, calling a new `_resolve_pitch_stage(player, intent.card_slot, slot)`, the `BASIC`/
   `UNBLOCKABLE`/`DEFENSE` sibling precedent exactly (each mode added its own arm in turn — 5-2,
   then 5-5 — narrowing `test_card_play.gd`'s three reachability-guard tests
   (`test_only_shipped_modes_are_reachable`, `test_the_reachable_mode_set_is_exactly_basic_
   unblockable_and_defense`, `test_the_mode_dispatch_carries_a_guard`) rather than deleting them,
   the `5-2/R8` discipline this story repeats a third time — see AC 17a, which retires the guard
   outright instead of narrowing it a fourth time.

4. **`FeatureFlags.pitch_zone` defaults `false` and is absent from `data/feature_flags.tres` —
   and `5-2/R14` is the direct precedent for flipping it in THIS story.** `feature_flags.gd:18`:
   `@export var pitch_zone: bool = false  # E6`. `data/feature_flags.tres` sets `unblockable`,
   `orbs`, `minions`, `totems` — no `pitch_zone` line, so it ships OFF by export default
   (`test_data_resources.gd:10` pins it present-by-name via reflection, not present-by-value).
   `test_cast_evaluator.gd:64/71/73/89` already exercises `required_flag = &"pitch_zone"` against
   in-test `FeatureFlags` literals — the pitch mode's gate name is already anticipated in the test
   suite, unauthored in shipped data. **Measured, verbatim, `decision-log.md` (`5-2/R14`): "THE
   `unblockable` LAYER GOES ON IN AUTHORED DATA WITH THE STORY THAT BUILDS IT" — `data/
   feature_flags.tres` flipped `unblockable` true the same story that built the layer, for two
   reasons: the `4-4`/`minions` precedent, and "a flag left `false` is a SECOND CLOSED GATE that
   [the wiring story] would have to remember to open... the mechanic does nothing while every test
   in the suite is green, because the tests inject their own `FeatureFlags`." The same two reasons
   apply here verbatim** — `6-2` builds the `pitch_zone` layer; `6-4` (not `6-2`) is the first story
   that wires a player-reachable path to it (Fact 3), so flipping the flag now changes no live
   behaviour, exactly as `5-2/R14` measured before flipping `unblockable`. **This story flips
   `data/feature_flags.tres`'s `pitch_zone` to `true`** (AC 2a below); tests continue to build their
   own `FeatureFlags` literal per the established convention, since no test pins the authored
   file's VALUES (only presence, `test_data_resources.gd:10`, the same `5-2/R14` measurement).

5. **`OrbPool` (`src/state/pools/orb_pool.gd`) already has ONE real `reset_all()` caller, the
   debug reset.** `get_count(color)`, `add(color, amount)` (clamped
   per-colour, short-circuited on no change), `set_maximum(max_count)` / `get_maximum()`
   (`NO_MAXIMUM := -1` sentinel, unbounded pre-injection), `reset_all()` — grepped and measured:
   `MatchState._reset_player` (`match_state.gd:4052`) already calls `player.orbs.reset_all()`, the
   THIRD named exception in that reset's "nothing else" contract (`5-4`'s AC 13), commented there
   as "REUSED, not reinvented: OrbPool authored it for E6's Pitch-Effect activation... different
   call site, same method." So `reset_all()` is not zero-caller today — this story's optional rule
   (AC 12/13) is its SECOND caller, not its first. `to_snapshot()` returns `{"red", "blue", "green"}`
   (no maximum — deliberately not hashed, AC 12 of `5-4`). Orbs are granted today exclusively by
   landing an unblockable (`5-4`'s unblockable-landing seat) — this story changes NOTHING about how
   orbs are earned or capped; it only READS `get_count()` to decide the READY transition, and — for
   the optional rule (AC 13) — calls the existing `reset_all()` at a second, mid-round call site.

6. **`CardData.cast_condition` is explicitly Mode ①'s cost, and there is no Mode ④ cost anywhere.**
   `card_data.gd:36-40`: `cast_condition: CardCastCondition` is documented "What Mode ① costs" —
   NOT shared across modes. `pitch_effect: CardEffect` (`:33-34`) is "reserved for E6... Left
   UNAUTHORED (null) on every card this story ships — the pitch mode is not designed yet and its
   cost side (mana + orbs) is not authored here." No `data/cards/*.tres` has a `pitch` line
   (grepped, confirmed empty). `imp_summoner.tres` authors `cast_condition.mana_cost = 3.0` for
   Mode ①, matching the GDD's own worked example (`gdd.md:207`: Mode ④ "Hellburst" costs "5 Mana +
   2 Green orbs", strictly different from the 3-mana basic cast) — **the cost genuinely differs
   per mode, and today's schema cannot express that. This is `E6-P/R9`'s named gap; AC 1/2 below
   are its discharge, decided at this scope talk.**
   `CardCastCondition` itself (`card_cast_condition.gd`) is a pure, mode-agnostic schema —
   `mana_cost: float`, `orb_costs: Dictionary[Enums.CardColor, int]` (empty on every card today,
   "the field exists because the pitch mode (E6) is what fills it" — its own header says so),
   `required_flag: StringName`. `CastEvaluator.refusal_reason(condition, mana_current, orbs,
   flags)` (`cast_evaluator.gd`) is ALSO mode-agnostic already — it takes a `CardCastCondition` and
   knows nothing about which mode it belongs to. **Minimal seat: reuse `CardCastCondition`
   verbatim as a SECOND per-card field on `CardData` (e.g. `pitch_condition`), not a new class.**
   `CastEvaluator.refusal_reason`'s mana+flag checks are directly reusable at staging time — its
   ORB check is NOT (see AC 4's note: staging must not be gated on orb affordability).
   `test_card_authoring.gd:186` pins `cast_condition.orb_costs.size() == 0` — a Mode ① fixture
   assertion, untouched by adding a sibling Mode ④ field. **This scope talk RULES the pitch costs
   authored (not left null) on all nine cards, provisionally (AC 1a)** — the existing test that
   asserts `pitch_effect` stays null is EXTENDED, not left as-is, to cover the new field being
   authored, per Dev Notes.

7. **Hand refill is a debt + a delayed timer, writing INTO the vacated slot, never appended — and
   staging vacates the slot the SAME way, but owes the replacement only when the card LEAVES the
   zone, never at staging time.** `_resolve_basic_cast` (`match_state.gd:2560-2660` area): removes
   the card (`player.hand.remove_at(hand_slot)`), discards it (`player.discard.add(played)`), then
   — per `4-0`'s correction of `3-5a` — appends the slot index to `player.pending_draw_owed`
   (`match_state.gd:2679` et al.) rather than drawing instantly. `_deliver_pending_draw`
   (`match_state.gd:3242-3264`), called every tick from `advance()` (`:570-571`), pops the OLDEST
   owed slot (FIFO) once `pending_draw.is_running` is false, draws into that exact slot (never
   appended), and restarts `pending_draw` at `balance_ticks.draw_replacement_delay_ticks` if more
   debt remains. A DEAD hero's debt is popped silently (consumed, no draw) but still announces via
   `notify_cards_changed()` so the HUD's in-flight caption does not hang forever.

   **RULED: staging uses the SAME `hand.remove_at()` hole mechanism a cast uses, but does NOT
   append to `pending_draw_owed` at staging time.** The vacated slot is held EMPTY and RESERVED —
   the staged-card record stores that hand slot index (hashed, AC 14b below), not a flag on a card
   still sitting in the hand array. The replacement is owed only when the card LEAVES the Pitch
   Zone; in this story the only exit is timer expiry (AC 11 — cancel and activation are `6-4`'s), so
   `_resolve_pitch_expiry` (the fizzle handler) is where `pending_draw_owed.append(staged_slot)`
   happens, through the existing FIFO, at the normal `draw_replacement_delay_ticks` delay — the
   identical mechanism `_resolve_basic_cast` already uses, just triggered at a different tick than a
   cast's own removal. **This means `hand.occupied_count()` — which `hand_size` in the snapshot
   binds to (`hand.gd:74`) — reads ONE LOWER while a card is staged**, exactly as it does during any
   in-flight `pending_draw_owed` delay after an ordinary cast: the slot is empty either way. `epics.
   md:210`'s "staged card still counts toward the hand of 4" is satisfied at the STRUCTURAL level —
   the slot is reserved for that card's eventual replacement and cannot be dealt into or read as a
   second hole — not by the `hand_size` snapshot number itself staying at 4 while staged (see Dev
   Notes for the explicit statement this AC discharges).

8. **`TimingWindow`/`BalanceTicks` conversion is a single load-time boundary; the precedent for a
   new duration field is exact and repeated eight times already.** `TimingWindow.seconds_to_ticks`
   (`timing_window.gd`) is the ONLY seconds→ticks path — `round()`, clamped to a minimum of 1 tick
   for any non-zero duration. `BalanceTicks.from_config()` (`balance_ticks.gd`) is the ONE seat
   that calls it, once per field, e.g. `defense_window_ticks = TimingWindow.seconds_to_ticks(
   config.defense_window_seconds)`. A new `pitch_stage_timer_seconds` field on `BalanceConfig`
   (provisional `20.0`, `E6-P/R5`) gets a plain, unclamped-beyond-the-1-tick-floor conversion
   into a new `pitch_stage_timer_ticks` on `BalanceTicks`, the `defense_window_ticks`/
   `unblockable_chargeup_ticks` shape exactly (a window duration, not a modulo divisor). **This
   field addition is MACHINE-CHECKED, not optional:** `test_data_resources.gd
   ::test_balance_config_field_lists_are_complete_by_reflection` (`:185-222`) fails unless (a) the
   new field's name is added to the hand-maintained `E1_BALANCE_FIELDS` list and (b) a
   stem-matched `_ticks` twin exists and is actually derived by `BalanceTicks.from_config()` (the
   probe sets every `*_seconds` field to `0.5` and asserts the twin reads `30`).

9. **The observation-seam family is pinned at NINE, machine-checked, and this story adds none —
   and how `6-3`/`6-4` will eventually READ this state is RULED, not this story's to decide.**
   `test_architecture_invariants.gd:267-` (the "SEVEN-SEAM FAMILY" guard, moved to eight at `3-6`
   and to nine at `5-4`) fails if a TENTH `connect_*` appears anywhere under `src/main/`. This
   story's staged-card / READY state has no HUD consumer yet (6-3), so nothing here needs a live
   push. `decision-log.md`, Session 2026-09-08,
   `E6-P/R8`(2) (ratified) rules it — "the pitch HUD gets a NEW MEMBER of the
   observation-seam family (the `connect_orbs_changed` precedent, `E5-C/R3`), never a second
   `MatchState` direct-connect." `6-3` adds the tenth seam member when it lands; `6-2` adds none.
   The staged card lives in the
   existing hashed `"pitch"` snapshot key (Fact 2), consistent with the GDD-declared-PUBLIC status
   of the staged card (unlike hand contents). **Seam count prediction: unchanged at nine, for THIS
   story only** — `6-3` moves it to ten, which is that story's scope, not this one's to decide.

10. **`FORMAT_VERSION` is 8 today; `Enums.ModeKind.PITCH` and the intent shape need no bump, but the
    new pitch-cost injection map does.** `record_file.gd:171`. `Enums.ModeKind` (`enums.gd:27`)
    already declares `PITCH` as the fourth mode value, and `InputIntent` already carries
    `card_commit`/`card_mode`/`card_slot` generically for all four modes (the same fields `BASIC`/
    `UNBLOCKABLE`/`DEFENSE` already resolve through) — staging a card is "cast mode PITCH", not a
    new kind of intent, and the INTENT shape alone would not force a bump. **This story's
    separately-injected pitch-cost map (AC 1/2) IS a new recorded content channel by the
    `record_file.gd`/`intent_recorder.gd` convention** (every injected content map gets its own
    capture channel — `_card_costs` at `3-5a`, `unblockable` at `5-2`, the widened contact row at
    `6-1`), so `FORMAT_VERSION` moves 8 → 9 (AC 16 below) even though the mode enum and intent
    shape themselves are unchanged.

11. **Copies cap: a 20-card deck of 6×3 + 1×2 is legal today, reported only, nothing changed.**
    Authored `max_copies` (`data/cards/*.tres`): `bramble_snare`, `ember_lash`, `frost_dart`,
    `imp_summoner`, `storm_kite`, `thornback_guardian` = 3 each; `hellforge_totem`,
    `tidal_wardstone`, `verdant_wardstone` = 2 each. Six of the nine cards support ×3
    (18) plus any one ×2 card (2) = 20, legal — e.g. the six named ×3 cards plus
    `hellforge_totem` ×2.

## Story

As the player staging a threat in a real-time exchange,
I want to move a card from my hand into my own Pitch Zone — spending its mana, starting its public
countdown, and letting it silently earn READY as I bank the right orbs — while my opponent watches
the clock and the cost but never learns whether I intend to see it through,
so that the buildup half of the pitch's open-information bluff (`P3`) exists in the state layer for
`6-4` to wire a player's finger to.

## Acceptance Criteria

**The pitch-cost authoring seat (discharges `E6-P/R9`).**

1. `CardData` gains a second `CardCastCondition` field — the same schema `cast_condition` already
   uses, reused verbatim, not a new Resource type — naming what Mode ④ costs for that card
   (mana + orb combination, `gdd.md:170`).
1a. **RULED: the pitch cost IS authored on all nine `data/cards/*.tres` fixtures this story,
   provisionally.** Mana: the same value as that card's own Mode ① `cast_condition.mana_cost`.
   Orbs, of the card's own colour: 1 orb on every 2-mana and 3-mana card (six cards: `bramble_snare`,
   `ember_lash`, `frost_dart`, `imp_summoner`, `storm_kite`, `thornback_guardian`), 2 orbs on the
   three 5-mana totems (`hellforge_totem`, `tidal_wardstone`, `verdant_wardstone` — measured,
   `data/cards/*.tres:13`: all three are `mana_cost = 5.0`). These numbers are PROVISIONAL retune, not final
   balance — a `.tres` edit alone changes them, no test edit, no golden re-baseline (the standing
   `BC/R3` isolation, decision-log), and the post-E6 playtest judges them (Dev Notes). This is
   NARROWER than `pitch_effect` (Fact 6), which stays null — this story authors the COST side of
   Mode ④ only, never its EFFECT; `E6-P/R9`'s "largest unpriced piece of E6" (authoring the effects
   themselves) stays explicitly OUT of this story (Non-Goals).
1b. `test_card_authoring.gd`'s existing assertion that `pitch_effect` stays null on every card is
   EXTENDED (not replaced) to also assert the new pitch-cost field is NON-null on every card, the
   inverse of `pitch_effect`'s own assertion on the same fixtures.
2. The new field reaches `src/state/` through the SAME injection discipline `_card_costs` already
   uses (`inject_card_costs`, Fact 6) — runner-only, once at match start, content-only, no reload
   path. Because AC 1a authors the field on every card, totality IS satisfied in shipped data as a
   consequence of authoring — but the injection seam itself must NOT enforce totality by
   `Invariant.check` the way `inject_card_costs` does for Mode ① costs, because AC 1a's numbers are
   explicitly provisional and a future card added without an authored pitch cost is a legal,
   ordinary state (pitch content simply unauthored for that card), not a load-time crash.
2a. `data/feature_flags.tres` flips `pitch_zone` to `true` in this story, per the `5-2/R14`
   precedent (Fact 4) — a `data_resources` test pins the authored `.tres` reads `pitch_zone == true`
   (the `unblockable`/`5-2` pin's sibling).

**Staging.**

3. A `card_commit` intent with `card_mode == Enums.ModeKind.PITCH` against a non-empty hand slot
   whose card has an injected pitch cost, an open `required_flag` gate, and affordable
   `mana_cost`: spends `mana_cost` from the casting player's `ManaPool` (the `_resolve_basic_cast`
   `ManaPool.spend()` + `Invariant.check` pairing, Fact 6), vacates the hand slot through the SAME
   `hand.remove_at()`-produced hole a cast uses (Fact 7) WITHOUT appending to
   `player.pending_draw_owed` at this tick, and creates that player's staged-card record — card id,
   the injected `orb_costs`, and the HASHED staged hand-slot index (Fact 7/AC 14b below) — not yet
   READY. The replacement is owed only when the card LEAVES the zone (AC 11).
4. **Staging is NOT gated on orb affordability.** Unlike a full `CastEvaluator.refusal_reason` call
   (which also checks `REASON_INSUFFICIENT_ORBS`), the staging refusal path checks only the flag
   gate and the mana price — a player with zero of the required orbs can still stage; the orb
   requirement is evaluated continuously afterward (AC 10), never as a precondition to stage.
   `CastEvaluator.refusal_reason` is NOT called whole for staging (its orb check would wrongly
   block it); the dev pass picks ONE shape for the flag+mana-only check — a new entry point, a
   skip parameter, or a caller that tolerates and discards the orb refusal — and states which, and
   why, in Dev Notes (Fact 6/`refusal_reason`'s fixed check order and single production caller mean
   none of the three is free).
5. A refusal — the flag closed, insufficient mana, an empty hand slot, or an already-staged zone
   (AC 6) — rejects through the existing `HeroState.reject_action("card_cast", <reason>)` seam
   (Fact 6/7's precedent) exactly as Mode ① does today: no crash, no silent no-op, no card removed,
   no mana spent. **A card with no injected pitch entry** refuses through a NEW module-level reason
   constant (the AC 6 precedent below), never `CastEvaluator.REASON_UNKNOWN_CARD` — that constant's
   own header (`cast_evaluator.gd:43-48`) documents it "UNREACHABLE BY CONSTRUCTION... kept as a
   total function's honest default, not as a live path... declared NOT mutation-proven for that
   reason," a guarantee `inject_card_costs`'s totality check earns and this story's pitch injection
   (AC 2) deliberately does NOT — reaching it here would be a real, reachable path (any card whose
   pitch cost is unauthored, which is legal per AC 2), contradicting the constant's own documented
   invariant. A sibling constant (e.g. `REASON_NO_PITCH_COST`) is minted instead.
6. Exactly one staged card per player at a time: a stage attempt while that player already has a
   staged card (any state — waiting or READY) refuses via a new reason (module-level constant, the
   `REASON_UNBLOCKABLE_COMMITTED`/`REASON_STUNNED` precedent, `match_state.gd:2693`/`2708`) —
   never a crash, never a silent overwrite of the existing staged card.
7. The two players' Pitch Zones are fully independent (`E6-P/R4`): staging, the timer, and the
   READY transition for P1 never read, block, or mutate P2's zone, and both players may hold a
   staged card simultaneously.
8. **The five-term conservation identity, pinned by a test that actually stages.** The existing
   `occupied + owed == hand_size` identity (`hand.gd`, `test_draw_delay_and_reshuffle.gd`,
   integration `test_deck_reshuffle.gd::_is_conserved`) and the deck+hand+discard permutation
   (`test_card_play.gd::test_cast_conserves_the_injected_multiset`) are all measured to stay green
   under this story UNCHANGED — because no existing test ever stages a card, so the two-term
   identity's blind spot (a staged card is neither occupied, owed, nor accounted for) is currently
   silent. This story adds a FIFTH term: `occupied + owed + staged == hand_size`, where `staged` is
   1 while that player holds a staged card and 0 otherwise, and pins it with a NEW test that
   actually stages a card and checks the five-term form across staging, the wait, and fizzle. The
   vacated hand slot refills through the EXISTING debt + delayed-draw path (Fact 7,
   `pending_draw_owed` / `_deliver_pending_draw` / `draw_replacement_delay_ticks`) ONLY once the
   card leaves the zone (AC 11) — no new refill mechanism, no instant draw, and no draw owed at the
   staging tick itself.
8a. `notify_cards_changed()` fires at staging (the hand's occupied count changed, even though the
   card did not go to discard) AND at expiry (the discard pile and the owed-draw count both
   changed) — two separate call sites, both pinned by tests, neither reused from the other.

**Timer and READY.**

9. Staging starts that player's fizzle countdown at `balance_ticks.pitch_stage_timer_ticks`,
   derived once at load time from a new `pitch_stage_timer_seconds` `BalanceConfig` field
   (provisional `20.0`, `E6-P/R5`) through the single `TimingWindow.seconds_to_ticks` boundary
   (Fact 8) — never a raw seconds value reaching `advance()`.
10. **READY is DERIVED every tick, never latched.** Mana is already spent at staging (AC 3), so the
    only remaining condition is orbs, and orbs only GROW inside the staging window (nothing this
    story ships can reduce a player's own orb count mid-window except the optional rule's clear at
    the moment of staging itself, AC 12 — never after). Because nothing can fall once true, a
    per-tick check of "does the staging player's `OrbPool` satisfy every colour in the staged
    card's `orb_costs` right now" (an empty `orb_costs`, or the `orbs` layer flag off, both read as
    immediately satisfied — the existing `_orbs_affordable` graceful-degrade rule, Fact 6) IS the
    READY state — no stored `READY` flag, no hashed member for it, nothing to latch. The staged-card
    record carries no boolean; a consumer (a test, `6-3`, `6-4`) asks "is this staged card ready"
    and gets the live per-tick answer. Reaching the affordable state fires no signal, consumes
    nothing, and does not itself resolve the card — the activation button is `6-4`'s.
11. **If the timer closes — whether or not the card currently reads READY — the staged card is
    removed from the Pitch Zone and moved to the staging player's discard pile**
    (`player.discard.add`, the `_resolve_basic_cast` precedent, `gdd.md:265`: fizzle "card
    discarded"). It does NOT return to the hand. `gdd.md`'s
    "fizzle → discarded + draw" describes exactly ONE draw — the replacement this story now owes
    AT THIS EXPIRY TICK (AC 8), through `pending_draw_owed.append(staged_slot)` and the existing
    FIFO delivery path, at the normal `draw_replacement_delay_ticks` delay — never a second, earlier
    draw at staging time (staging owes nothing, AC 3/8) and never a second, LATER draw on top of
    this one. The mana spent at staging is NOT refunded — a card that fizzles takes its mana with
    it, in words: the player paid for a chance, the chance expired, the mana is gone either way.

**Optional rule — orb pool clears on stage (default OFF).**

12. A `BalanceConfig` bool field (NOT a `FeatureFlags` entry — it is a rule inside a live system,
    the `unblockable_swing_at_commit` precedent, `6-1d/R6`), default `false`. **UNLIKE that
    presentation-only precedent, this bool gates HASHED state** (whether orbs are zeroed at a new
    mid-round call site) — it needs the full treatment (both branches tested, both branches
    live-judgeable), not the light one `6-1d/R6` used for a presentation knob. When `true`, the
    staging player's `OrbPool.reset_all()` (Fact 5, its SECOND call site — `_reset_player` is the
    first) fires at the moment of staging. **The rule is "pitching clears", not "the price
    clears"**: staging ALWAYS clears all three colours when the switch is ON, including staging a
    card whose own `orb_costs` needs no orbs at all — the clear is keyed to the act of staging, not
    to the staged card's cost.
13. Both branches are test-covered, and the ON-branch test is shown to fail if the ON branch is
    removed (a default-off branch is exactly what rots silently otherwise). Named EXPECTED VISIBLE
    EFFECT per branch, so a future smoke can classify it (the `6-1d` lesson — a knob whose effect
    can't be judged is not a testable AC):
    - **OFF (default):** orbs already banked before staging count immediately toward the READY
      requirement — a player who pre-banked the exact orbs can go READY on the SAME tick they
      stage. Zero-orb-cost cards are immediately satisfied (AC 10), as always.
    - **ON:** staging empties the pool first, THEN checks READY (AC 10) on the same tick — a card
      whose own `orb_costs` needs at least one orb can never reach READY on the staging tick itself,
      even with the exact orbs already banked; the window must be re-filled from zero regardless of
      prior banking. **A ZERO-orb-cost card is UNAFFECTED by the switch either way** — clearing
      orbs a card never needed changes nothing about that card's own READY check, so it is still
      immediately satisfied even with the switch ON (the `_orbs_affordable` graceful-degrade rule,
      Fact 6, reads an empty `orb_costs` as satisfied regardless of the pool's contents).
    An authored-off pin ships in the shape of the existing knob's authored-off test
    (`test_balance_authoring.gd:927/933-934`, `unblockable_swing_at_commit` ships `false`).
    Deadline, recorded where it actually applies (not as a pointer to a section that lacks it): the
    post-E6 playtest decides the branch; the losing branch AND this bool are BOTH deleted then, the
    `6-1d/R6` precedent exactly. `6-4`'s activation reset (a SECOND orb-clear site, on the GDD's own
    "all orbs reset to 0" at Mode ④ activation, `gdd.md:170`) is inherited scope for that story, not
    authored here.

**Determinism and regressions.**

14. `PitchState.to_snapshot()`'s shape changes to carry both players' zone state. **Golden: MOVED**
    (Fact 2) — measured in both directions, single re-baseline, the one named cause being the
    `"pitch"` key's new shape (never "presentation" or a bundled cause). Current golden `9679fa80`
    (Fact 1's citation, `6-1c` close-out).
14a. **The zone stays inside `MatchState`'s existing `"pitch"` snapshot key — NOT a `PitchState` on
    each `PlayerState`.** A per-player `PitchState` field would REMOVE
    `"pitch"` from the top-level key set and add two new per-player keys, breaking the pinned
    top-level key set (Golden Prediction below); the one-object-with-per-slot-records shape (the
    `_lock_directions[slot]` precedent, Fact 1) keeps the single `"pitch"` key and grows only its
    nested shape.
14b. **New `PitchState` IDENTITY members are HASHED; the ORB PRICE is NOT; the new pitch-cost map
    is INJECTED** (the `flags`/`_card_costs` split, Fact 6) — the replay-identity scan
    (`test_replay_identity.gd`) fails on any unclassified member, so all three need explicit
    classification in the same pass. The staged hand-slot index and the staged card id are HASHED
    members despite being "identity" data — a departure from `3-3`'s "counts-only" rule for hashed
    card identity — RULED safe and intended here, in words: the staged card is PUBLIC information
    by GDD design (unlike hand contents, which stay excluded from `to_snapshot()` by three separate
    prior rulings), so hashing its id leaks nothing a replay observer couldn't already see live.
    **The orb PRICE is a separate question from identity, and answers differently (review fix H1):**
    it is card `.tres` CONTENT, not identity, and `3-2`'s close-out ruled card content permanently
    out of the hashed run — a `.tres` reprice must never re-baseline the golden. `PitchState` still
    caches the price per slot (copied by value at staging) so `is_ready()` can keep reading it live
    across ticks, but that cache is UNHASHED and excluded from `to_snapshot()`; the "frozen at
    staging" guarantee comes from the injection discipline (the price is copied off a map injected
    once at match start, no reload path), not from being hashed.
14c. `UNHASHED_CROSS_TICK_MEMBERS` (`test_replay_identity.gd`) MOVES FROM THREE TO FOUR (review fix
    H1). The staged card id and its slot index ride the existing `"pitch"` snapshot key and add no
    new top-level `MatchState` member, exactly as originally pinned. The orb price is the new,
    fourth argument: it genuinely crosses ticks (frozen at staging until `clear()`, read by
    `is_ready()` on every tick in between) so it cannot be PER_TICK, and it is never injected
    per-call so it cannot be INJECTED — UNHASHED_CROSS_TICK is its only honest home, and the count
    pays for that rather than being held at three by construction.
14d. The debug reset clears the Pitch Zone (both players') as part of its existing "nothing else"
    contract (Fact 5's `_reset_player`) — an unclear zone would have the next deal duplicate the
    staged card's id into the freshly-dealt hand while the same id also sits staged. Pinned by a
    test.
14e. **Tick-ladder seat, named:** the fizzle timer ticks and expiry resolves BEFORE the pending-draw
    delivery step in `advance()`'s per-tick order (the `3-5b` ordering) — so a `pitch_stage_timer_
    ticks` of 0 (a degenerate/test config) fizzles and its replacement draw is delivered on the
    SAME tick it fizzles, not the next one. The fizzle timer freezes at round-over because it ticks
    after the round-over freeze step (the `2-6/R14` precedent, Fact-cited above), the same reason
    every other per-tick countdown in this codebase freezes there.
15. The observation-seam count stays at NINE (Fact 9) — no new `connect_*` signal ships.
16. **`FORMAT_VERSION` goes 8 → 9: the new pitch-cost map is a NEW RECORDED CHANNEL,** the same
    reasoning that bumped it at `5-2` (unblockable) and `6-1` (the widened contact row, Fact 10's
    own citation, `test_record_file.gd:152-159`) — every injected content map gets its own capture
    channel, and this story adds one. `record_file.gd:171`'s constant moves 8 → 9; a v8 record is
    REFUSED with a reason, no shim, the exact shape `6-1` used (`test_record_file.gd::test_a_record_
    whose_format_version_is_unknown_is_refused_with_a_reason` / `test_the_format_version_and_the_
    widened_contact_row_move_together`). New ACs the dev pass discharges under this bump: the
    recorder captures the new map at match start (the `inject_card_costs`/`intent_recorder.gd`
    precedent); the record file gains a new top-level key for it; the drop-test suite gains an
    entry — and the drop test only actually exercises the new channel if the driven replay it plays
    back stages a card with an authored pitch cost, which must be stated, not assumed; and the
    runner derives the injected map from the record on load the same way it derives `_card_costs`
    today.
17. `test_data_resources.gd`'s reflective guard (Fact 8) passes for the new `pitch_stage_timer_seconds`
    field, deriving a `pitch_stage_timer_ticks` twin. The optional-rule bool does NOT need an entry
    in `E1_BALANCE_FIELDS` to pass the guard — reflection only collects `TYPE_FLOAT`/`TYPE_INT`
    declared properties (`test_data_resources.gd`'s own loop, `if kind != TYPE_FLOAT and kind !=
    TYPE_INT: continue`), so a `bool` field is invisible to that scan by construction; the existing
    `unblockable_swing_at_commit` presentation bool is proof — it is absent from `E1_BALANCE_FIELDS`
    today and the guard still passes. The optional-rule bool is still authored as a real
    `.tres`-backed `BalanceConfig` field (AC 12/13); it is simply not part of THIS reflective list.
17a. **The mode guard is RETIRED, not narrowed a third time.** With PITCH shipping, all four
    `Enums.ModeKind` values are reachable and `test_only_shipped_modes_are_reachable`'s reachability
    scan (Fact 3) becomes vacuous by its own documented reasoning — it exists to catch an
    UNREACHABLE mode authored in `src/`, and none remains. The dev pass retires the scan rather than
    narrowing it a third time, and renames/re-values `test_the_reachable_mode_set_is_exactly_basic_
    unblockable_and_defense` (the `5-5` renaming discipline — rename to match what the set now says,
    don't leave a stale name describing a narrower set than the code allows). The default `_` arm's
    crash message (Fact 3) still names "E3 (only BASIC resolves)" and is three stories stale
    (`5-2`, `5-5`, and now `6-2` each added a real arm without touching it) — reworded to a
    mode-agnostic message, and `test_the_mode_dispatch_carries_a_guard` (which pins a substring of
    that message, Fact 3's citation) is updated in the SAME change, not a follow-up. No
    Invariant guard is proven by deliberately tripping it (project-context standing rule).
18. The full suite passes (`bash test/run_all.sh`).

## Non-Goals

- Any HUD or visual presentation of the zone, cost, timer, or READY state — `6-3`'s (`E6-P/R8`(2):
  the pitch HUD gets its own new observation-seam member, `connect_orbs_changed`'s precedent, when
  it lands).
- The activation input, any gamepad binding, and the Y-guard question — `6-4`'s (`E6-P/R8`(8);
  `5-7/R7` held the Y-guard open explicitly until "the E6 story that actually wires Y").
- **The cancel exit path** — named committed scope for `6-2` at `epics.md:209`, deliberately
  deferred to `6-4` in this pass (see the Scope note above) because it is a player-triggered action
  and `6-2` wires no player input.
- Any spell effect or resolution of Mode ④ — `6-5`'s.
- **How orbs are EARNED or CAPPED, and round-end orb behaviour** — `5-4`'s, untouched. This story
  DOES add a new mid-round orb-clear site (the optional rule, AC 12/13); the Non-Goal covers only
  the earn/cap mechanism and the round-end clear, neither of which this story touches.
- Authoring real per-card `pitch_effect` (the EFFECT, not the cost) on the nine fixture cards — the
  cost-side seat ships authored (AC 1/1a); the effect side is `E6-P/R9`'s "largest unpriced piece
  of E6", unpriced here too.
- Any new observation seam (Fact 9) — `6-3`'s scope talk owns the tenth member; this story adds
  none.
- Retune of any existing number outside the fields this story authors (the nine cards' pitch
  `mana_cost`/`orb_costs`, `pitch_stage_timer_seconds`, the optional orb-clear bool).
- The activation-time orb reset (all three colours, on the GDD's own Mode ④ activation cost,
  `gdd.md:170`) — `6-4`'s, a SECOND clear site inheriting this story's `reset_all()` reuse but not
  authored here.

## Golden Prediction

**Measure both directions — this is not a substitute for the measurement.**

- MOVED, certain by construction (Fact 2): `PitchState.to_snapshot()`'s shape changes the moment
  it carries per-player zone fields, independent of whether the golden's fixed input sequence ever
  stages a card. Single named cause: "`PitchState.to_snapshot()` gained per-player staged-card
  fields." Never bundle this with any other cause.
- The golden's own sequence has never played a card in PITCH mode (no pad Y wiring exists yet to
  produce one even if it tried, Fact 10) — so nothing beyond the snapshot SHAPE change is expected
  to move. If any OTHER field the golden's fixed sequence actually exercises reads differently,
  that is a real regression, not an artifact of this story's schema change.
- Snapshot key SET: the top-level key set is unchanged (`"pitch"` already exists); only its nested
  shape grows. `test_card_observation.gd`'s pinned key-set assertion should therefore see no
  top-level delta — confirm this by measurement, not assumption, since a wrongly-nested new
  top-level field would be a second, avoidable golden mover.
- **Flipping `data/feature_flags.tres`'s `pitch_zone` to `true` (AC 2a) CANNOT move the golden**,
  confirmed by the same measurement `5-2/R14` already made for `unblockable`: `test_determinism.gd`'s
  `_golden_flags()` (`:1353`) constructs its own in-test `FeatureFlags` literal and never reads the
  authored `.tres`, and no test pins the authored file's VALUES (`test_data_resources.gd` pins
  presence only). Replays record the flags used at record time as part of the record's own content
  (not re-read from the live authored file at replay time), so an authored-file flip after a replay
  was recorded cannot retroactively change what that replay resolves to either.

## Live Smoke

**Not required, deferred to `6-3`.** Nothing this story delivers has a HUD or visual presentation
(Non-Goals) — the staged card, its cost, its timer and its READY state are all invisible on screen
until `6-3` lands. A live smoke of an invisible mechanism cannot be judged (the `6-1d/R15` lesson:
an effect a smoke can't perceive can't be classified pass/fail). State-layer correctness is proven
by the headless suite (AC 18) and any new integration test the dev pass adds.

### Live Smoke Results (2026-09-14)

Source: `docs/playtest-log.md`, 14.9. entry (one line, the operator's own words). This story defines
no numbered Live Smoke items of its own (above: deferred to `6-3`, nothing pitch-specific is
perceivable) — the pass actually run is REGRESSION-ONLY, confirming the existing systems still work
with the fix-pass changes in place, not a pitch-specific checklist.

**PASS, no findings.** Operator (14.9.): "nakon pocinjanja impemetacije pitcha [i]ako ga jos ne
vidimo ostatak postojecih stvari radi kako spada" (after starting the pitch implementation, although
we still can't see it, the rest of the existing stuff works as it should). No regression against any
prior story's carried Live Smoke items; nothing pitch-specific was or could be judged, matching this
section's own prediction above.

## Dev Notes

### Open Questions for the dev pass (named, not pre-ruled)

1. **Cancel's mana/orb-reset semantics**, for `6-4`'s scope talk, not this story's: does cancel
   refund the mana spent at staging? If the orb-clearing optional rule (AC 12) is ON, does cancel
   restore the cleared orbs? Operator decision, explicitly not taken here (per the answer that
   deferred cancel itself).
2. **The exact injection-seam mechanics for the new pitch-cost map** (Fact 6/AC 2): mirror
   `inject_card_costs` as a second dictionary (`inject_pitch_costs`), or fold both costs into one
   wider per-card injected record. Either is "the minimal form" as long as totality is NOT
   `Invariant.check`-enforced (AC 2) and the flag+mana-only check stays reusable for staging without
   reusing `refusal_reason`'s orb check (AC 4).
3. **A STRONGER reason for the cancel deferral than the Scope note currently gives.** Cancel needs
   an `intent` field that does not exist — `InputIntent`'s `card_commit`/`card_mode`/`card_slot`
   shape (Fact 10) names WHAT to stage or cast, never "abandon what is already staged," so a cancel
   path needs a new intent shape, which is a RECORDED-INPUT change (touching `FORMAT_VERSION` and
   the recorder/replay machinery, Fact 10/AC 16's own territory) — not merely "a state transition
   with no player-triggered consumer yet" as the Scope note currently frames it. Both reasons hold;
   the recorded-input one is the stronger, more durable one and belongs in `6-4`'s own scope talk
   when it takes cancel (`epics.md`'s `6-4` line, F8 of the 2026-09-13 readiness gate).

### Reuse and precedent map (do not re-derive these)

- `_resolve_basic_cast`'s ordered dispatch (`match_state.gd:2560+`) is the shape for
  `_resolve_pitch_stage`: state gate (mirror the `CHARGING`/`STUNNED` guards) → empty-slot guard →
  already-staged guard (AC 6) → cost lookup (missing entry refuses, AC 5) → refusal check (mana +
  flag ONLY, AC 4) → `ManaPool.spend()` + `Invariant.check` → `hand.remove_at()` (the hole, WITHOUT
  `pending_draw_owed.append()` — that append moves to the NEW `_resolve_pitch_expiry`, AC 3/8/11) →
  optional-rule orb clear if ON (AC 12) → create the staged-card record (card id, `orb_costs`,
  staged slot index) → start the fizzle `TimingWindow`.
- A NEW `_resolve_pitch_expiry` (or equivalent, called once the fizzle `TimingWindow` closes,
  the same per-tick seat `_deliver_pending_draw` is called from) is where the AC 11 exit lives:
  move the staged card to discard, THEN `pending_draw_owed.append(staged_slot)` — the debt is owed
  at THIS tick, not at the original staging tick.
- `CastEvaluator.refusal_reason` (Fact 6) is directly reusable for the mana+flag half; do NOT call
  it whole for staging (its orb check would wrongly block staging, AC 4) — pick and state the exact
  reuse shape (AC 4).
- `_orbs_affordable`'s per-colour, SORTED-keys iteration (`cast_evaluator.gd`, currently `_`-private
  static) is the shape for the READY-transition check (AC 10) — either expose it or mirror its
  exact iteration-order discipline (sorted `Enums.CardColor` ints, never `StringName` — the
  pointer-ordering hazard this repo avoids everywhere, `cast_evaluator.gd`'s own header).
- `BalanceTicks.from_config()` (Fact 8) is the ONLY place `pitch_stage_timer_seconds` may be
  converted; never let the raw seconds value reach `advance()` or the per-tick fizzle check.
- New rejection reason constant: follow `REASON_UNBLOCKABLE_COMMITTED`/`REASON_STUNNED`
  (`match_state.gd:2693`/`2708`) — a module-level `const ... := &"..."` beside
  `_resolve_pitch_stage`, not a `CastEvaluator` constant (those name evaluator VERDICTS; this one
  names a state-side occupancy conflict the evaluator never sees).

### Project Context Rules

- `D3(a)`/`D3(b)`/`A2`/`F1` (CLAUDE.md load-bearing invariants) are machine-checked by
  `test_architecture_invariants.gd` — nothing in this story's mechanism (a state-only cost gate,
  timer, and orb read) touches `Input.*`, global RNG, `Time`, `OS`, or `Engine`, and adds no
  `_physics_process`.
- Commit discipline: docs and code never share a commit; PowerShell has no `&&`; commit messages
  are pure ASCII via `git commit -F <tempfile outside the repo>`; trailer
  `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` (this session's attribution — confirm
  against the live system reminder at commit time, it supersedes any trailer named in prior
  stories' Dev Notes).
- Tier A: full gate + review + live-smoke ritual applies, EXCEPT the live smoke itself, which this
  story's own Live Smoke section defers to `6-3` with a named reason (nothing to perceive).

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/gdd.md#E. Pitch Zone (the signature bluff system — P3)]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/gdd.md#C. Card System — four modes table]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/gdd.md#D. Economy Layers — Orbs]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md#Epic 6 — key stories 4/committed obligations]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md — Session 2026-09-08, `E6-P/R1` through `E6-P/R11`]
- [Source: src/state/pitch/pitch_state.gd]
- [Source: src/state/match_state.gd:173,339,377,668-674,953,2512-2539,2560-2660,3242-3264]
- [Source: src/state/resources/card_data.gd]
- [Source: src/state/resources/card_cast_condition.gd]
- [Source: src/state/economy/cast_evaluator.gd]
- [Source: src/state/pools/orb_pool.gd — corrected path, not src/state/economy/]
- [Source: src/state/resources/feature_flags.gd, data/feature_flags.tres]
- [Source: src/state/resources/balance_ticks.gd]
- [Source: src/state/enums.gd:27]
- [Source: src/systems/record_file.gd:171]
- [Source: test/state/test_data_resources.gd:185-222]
- [Source: test/state/test_architecture_invariants.gd:267-]
- [Source: test/state/test_cast_evaluator.gd:55-89]
- [Source: test/state/test_card_authoring.gd:186]
- [Source: test/state/test_card_play.gd — reachability guard tests (Fact 3 correction) and
  test_cast_conserves_the_injected_multiset]
- [Source: test/state/test_balance_authoring.gd:927-934 — the authored-off pin precedent]
- [Source: test/state/test_record_file.gd:152-159,411-430 — the FORMAT_VERSION bump/refusal shape]
- [Source: test/state/test_replay_identity.gd:116 — UNHASHED_CROSS_TICK_MEMBERS]
- [Source: decision-log.md — `5-2/R14` (flag-in-data precedent)]
- [Source: docs/implementation-artifacts/6-1d-honest-hit-geometry.md — house style + `6-1d/R6` optional-knob precedent]

## Dev Agent Record

### Agent Model Used

Claude Opus 5 (1M context), single main session, no subagents / forks. No commits made.

### Debug Log References

Suite output files (outside the repo), counters read by opening the files:

| Run | File | Written | Result |
|---|---|---|---|
| 1 before-baseline (before any edit) | `C:\dev\_62-suite-before.txt` | 2026-09-14 01:02:09 | state **777 tests, 0 failed, 6305 assertions**; integration **59/59 PASS**; exit 0 |
| 2 EXTRA (disclosed) pre-re-baseline proof | `C:\dev\_62-suite-prebaseline.txt` | 2026-09-14 01:29:57 | state 808 tests, **3 failed**, 6551 assertions; integration 59/59 PASS; exit 1 |
| 3 final | `C:\dev\_62-suite-after.txt` | 2026-09-14 01:35:24 | state **808 tests, 0 failed, 6551 assertions**; integration **59/59 PASS**; exit 0 |

**Cadence disclosure.** THREE full runs, one over the default two. Reason for run 2: the prompt's golden
discipline requires every non-golden test to be proven green BEFORE the single re-baseline, and that
needs a full run with the golden still un-rebaselined. Run 2 was NOT clean: besides the expected
`test_determinism.gd::test_state_matches_golden`, it caught two failures in `test_live_reload.gd`
(`test_the_recorder_still_ships_exactly_eleven_capture_channels`, and
`test_the_replay_side_consumes_the_live_event_with_no_new_code` via the new match-start completeness
Invariant) — a recorder fixture I had missed. Fixed (count 11 -> 12, renamed, fixture captures the
channel), proven green by running that file alone, then re-baselined. I did NOT spend a fourth full run
to re-prove "non-golden green" after that one-file fix; run 3 (after the re-baseline) is the complete
proof. No host OOM; all runs backgrounded. Development and mutation runs used a scratchpad
single-file runner (`run_files.gd`, outside the repo) over only the affected files.

**Golden measurement (both directions).** Old `9679fa80`, new
**`72d3cc6ed5caeeff8b1dded3a054faefa479bc371117c82982bccf04af6a9595`**. Named cause:
`PitchState.to_snapshot()`'s nested shape (`{"fizzle": ...}` -> `{"p1": {card_id, hand_slot,
orb_costs, fizzle}, "p2": {...}}`).
- G0 — all 6-2 changes in place: `test_state_matches_golden` got `72d3cc6e…`, expected `9679fa80…`.
- G1 (reverse) — ONLY `PitchState.to_snapshot()` returned to its pre-story shape
  (`{"fizzle": _fizzle[0].to_snapshot()}`), everything else 6-2 in place: `test_determinism.gd`
  19 tests, **0 failed** — i.e. hash == `9679fa80` exactly. Restored by copy-back, SHA-256
  `16fe7c36…aa88b0` before == after.
- G2 (flag claim) — `pitch_zone = true` line removed from `data/feature_flags.tres`, all code 6-2:
  got `72d3cc6e…`, identical to G0. **The story's claim holds by measurement: the flag flip does not
  move the golden.** Restored, SHA-256 `56b8d9c6…6e23e6` before == after.
- ONE re-baseline, in `test_determinism.gd`, with the cause block above `const GOLDEN`.
- Top-level snapshot key set unchanged: `test_debug_window_countdown.gd`'s top-level pin
  (`["p1","p2","pitch","rng_state","round_over","tick"]`) and `test_card_observation.gd` green.

**Mutation table — ALL rows MEASURED by this dev pass (6-2), single affected file(s) only.** Every
mutated file was copied to the scratchpad before mutation and restored by copy-back; SHA-256 compared
before/after, all RESTORED-OK.

| ID | File / mutation | Guard(s) that went RED | Restore SHA-256 (before == after) |
|---|---|---|---|
| M1 | `match_state.gd`: ON-branch `player.orbs.reset_all()` -> `pass` (AC 13) | `test_orb_clear_on_staging_empties_every_colour_before_ready_is_read`, `test_orb_clear_on_a_zero_orb_card_still_clears_the_pool_and_is_still_ready` | e385cf9d…4b89f2 |
| M2 | `match_state.gd`: `Enums.ModeKind.PITCH:` arm deleted (AC 17a) | `test_card_play.gd::test_every_declared_mode_has_its_own_dispatch_arm` | e385cf9d…4b89f2 |
| M3 | `intent_recorder.gd`: `missing.append("pitch costs")` -> `pass` | `test_a_record_missing_any_match_start_channel_is_malformed`, `test_an_empty_pitch_cost_capture_is_a_complete_match_start` | 10c94f2a…0d641 |
| M4 | `test_replay_identity.gd` fixture: the STAGE_TICK commit made `false` (driven run no longer stages) | `test_dropping_any_single_channel_diverges_the_replay` ("dropping the pitch_costs channel must DIVERGE"), `test_the_recorded_run_exercises_every_channel` — proves AC 16's stated dependency: the drop only bites because the run stages. (A first M4 attempt inserted the `false` BEFORE the existing `= true` and was therefore a no-op mutation — green; re-done correctly, recorded here rather than dropped.) | 5c576f0f…6e3a |
| M5 | `match_state.gd`: `pitch.clear(reset_slot)` -> `pass` (AC 14d) | `test_the_debug_reset_clears_both_zones` | e385cf9d…4b89f2 |
| M6 | `match_state.gd`: fizzle seat moved AFTER `_deliver_pending_draw` (AC 14e) | `test_a_zero_tick_countdown_fizzles_and_refills_on_the_staging_tick` | e385cf9d…4b89f2 |
| M7 | `match_state.gd`: `pitch.tick()` hoisted above the step-1b freeze (AC 14e freeze). (First attempt's sed also hit `_check_resolution`'s `if _round_over:` — 7 reds, noisy; re-done on the first occurrence only.) | `test_the_countdown_freezes_on_round_over_ticks` | e385cf9d…4b89f2 |
| M8 | `match_state.gd`: staging calls full `CastEvaluator.refusal_reason` (orb-gated) (AC 4) | 12 staging tests incl. `test_staging_is_not_gated_on_orb_affordability` | e385cf9d…4b89f2 |
| M9 | `match_state.gd`: `pending_draw_owed.append(hand_slot)` added at staging (the ruled-out mechanism, AC 3/8) | 6 incl. `test_the_five_term_conservation_identity_holds_across_stage_wait_and_fizzle`, `test_staging_pays_the_mana_vacates_the_slot_and_owes_no_draw` | e385cf9d…4b89f2 |
| M10 | `record_file.gd`: writer omits `"pitch_costs"` | 12 `test_record_file.gd` tests (round trip, byte identity, required keys …) | d7808714…088c1 |
| M11 | `match_runner.gd`: `_match_state.inject_pitch_costs(...)` -> `pass` | integration `test_deck_injection.gd` (`pitch=false`, RESULT: FAIL) | b4cb0b43…a3b7e8 |
| M12 | `intent_recorder.gd`: `replay_inject_content` skips the pitch channel | 6 `test_replay_identity.gd` tests + `test_record_file.gd::test_a_saved_and_reloaded_record_replays_to_the_same_canonical_hash` | 10c94f2a…0d641 |
| M13 | `match_state.gd`: `flags.pitch_zone` layer gate -> `if false:` (AC 5) | `test_a_closed_pitch_zone_layer_refuses_with_flag_closed` | e385cf9d…4b89f2 |
| M14 | `data/feature_flags.tres`: `pitch_zone = true` deleted (AC 2a) | `test_data_resources.gd::test_feature_flags_tres_opens_the_pitch_zone_layer` | 56b8d9c6…6e23e6 |
| M15 | `balance_config.tres`: `pitch_stage_clears_orbs = true` (AC 13 authored-off) | `test_the_pitch_orb_clear_rule_is_authored_off` | 88e7a3f2…7e5229 |
| M16 | `balance_config.tres`: `pitch_stage_timer_seconds = 0.0` | `test_authored_pitch_stage_timer_is_positive` | 88e7a3f2…7e5229 |
| M17 | `storm_kite.tres`: `pitch_condition` line deleted (AC 1b) | `test_card_authoring.gd::test_basic_mode_only_pitch_and_orbs_left_unauthored` | 5a6dd1d2…f0cc9 |
| M18 | all nine `data/cards/*.tres`: orb-price entries deleted (the "orb_costs really parses" sanity) | same test, the `priced_in_orbs > 0` sanity. (A first single-card M18 — malformed dict syntax on ONE card — stayed GREEN: the sanity is library-wide by design, so one card cannot trip it. Recorded, not dropped.) | 9/9 files `sha256sum -c` OK |
| M19 | `record_file.gd`: `FORMAT_VERSION := 8` | `test_the_format_version_and_the_widened_contact_row_move_together`, `test_the_contents_validation_bumped_no_version_and_widened_no_required_key` | d7808714…088c1 |
| M20 | `record_file.gd`: `"pitch_costs"` removed from `REQUIRED_KEYS` | `test_a_v8_record_without_pitch_costs_is_refused_with_a_reason`, `test_the_required_key_set_is_exactly_what_a_saved_record_carries`, `test_the_contents_validation_...` | d7808714…088c1 |

**Finding from M19, reported not hidden:** `test_a_v8_record_without_pitch_costs_is_refused_with_a_reason`
stays GREEN when `FORMAT_VERSION` is reverted to 8, because a stripped v8 body is then refused for its
missing key and `"8"` satisfies both "names the version" substrings. That test alone does NOT guard the
bump; the version pin tests do (M19), and it does guard the required key (M20). No Invariant.check was
proven by deliberately tripping it; M9 may incidentally print a `Hand.fill_at` invariant while its
behaviour assertions fail — the red verdict rests on the assertions.

### Completion Notes List

**The three choices the story left open.**
1. *Per-slot record shape* — ONE `PitchState` (ruled), INDEX-ALIGNED top-level arrays, slot 0 = P1:
   `_card_ids: Array[StringName]` (`NO_CARD := &""`), `_hand_slots: Array[int]` (`NO_HAND_SLOT := -1`),
   `_orb_costs: Array[Dictionary]` (price copied by value at staging), `_fizzle: Array[TimingWindow]`
   (the existing member name kept). Why: the `_lock_directions[slot]` / `UnitBoard` precedent, and
   top-level `var`s stay visible to `test_replay_identity.gd`'s `^var` member scan — an inner record
   class would have hidden its fields from the classification guard. Snapshot:
   `{"p1": {card_id (String value), hand_slot, orb_costs (int colour keys), fizzle}, "p2": {...}}`.
   Methods: `stage`, `clear`, `tick`, `is_staged`, `is_expired`, `staged_card_id`, `staged_hand_slot`,
   `is_ready(slot, orbs, flags)`. READY lives on `PitchState`, not `MatchState`, so no sixth
   `EXEMPT_PURE_QUERIES` entry was needed on the intake scan.
2. *Flag+mana-only check* — a NEW ENTRY POINT, `CastEvaluator.flag_and_mana_refusal_reason(condition,
   mana_current, flags)`; `refusal_reason` now calls it, so the two share the flag/mana half by
   construction. Rejected: a skip parameter (a second behaviour on Mode ①'s single caller) and
   tolerate-and-discard (correct only while the orb check stays last). The READY check reuses the orb
   loop via a new public `CastEvaluator.orb_costs_affordable(orb_costs, orbs, flags)`, which
   `_orbs_affordable` forwards to.
3. *Injection mechanics* — a SECOND DICTIONARY mirroring `inject_card_costs`:
   `MatchState.inject_pitch_costs` / `_pitch_costs` (NO Invariant.check at all — not total, empty
   legal), `IntentRecorder.capture_inject_pitch_costs` / `replay_pitch_costs` / `CHANNEL_PITCH_COSTS`
   (last in `SOUND_CONTENT_ORDER`), `RecordFile` key `pitch_costs`, runner `_derive_pitch_costs()`.
   Why: the four-seam precedent verbatim; a wider per-card record would have reshaped the Mode ① costs
   channel and its record key. Record completeness is keyed to a `_pitch_costs_captured` bool, not
   emptiness, because an empty map is a legal capture.

**State counts (as asked).** `FORMAT_VERSION` 8 -> **9**, v8 refused with a reason, no shim (6-1's
shape verified by content first: 6-1 moved the version-pin literals and relied on the generic
unknown-version refusal; 6-2 does the same plus a dedicated stripped-v8 test). Observation seams stay
**nine** (`test_runner_observation_seams_are_exactly_nine` green; no `connect_*` added).
`UNHASHED_CROSS_TICK_MEMBERS` stays **three** (new members classified: `pitch_state._card_ids /
_hand_slots / _orb_costs` HASHED, `match_state._pitch_costs` INJECTED). No new `class_name` —
no editor scan run, no `.uid` sidecars generated, `project.godot` untouched.

**AC status.** 1 ✔ (`CardData.pitch_condition`, same `CardCastCondition`). 1a ✔ (nine cards: mana =
Mode ① mana; 1 own-colour orb on the six 2/3-mana cards, 2 on the three 5-mana totems; also authored
`required_flag = &"pitch_zone"` — see deviations). 1b ✔. 2 ✔ (no totality check). 2a ✔. 3 ✔. 4 ✔.
5 ✔ (`REASON_NO_PITCH_COST := &"no_pitch_cost"`). 6 ✔ (`REASON_PITCH_ZONE_OCCUPIED :=
&"pitch_zone_occupied"`). 7 ✔. 8 ✔ (five-term identity + staged-inclusive permutation, new test). 8a ✔.
9 ✔. 10 ✔ (no stored READY; hash of `"pitch"` unchanged when READY flips). 11 ✔. 12 ✔
(`BalanceConfig.pitch_stage_clears_orbs`). 13 ✔ (both branches; ON proven by M1; authored-off pin).
14 ✔ (golden moved, one cause, both directions). 14a ✔. 14b ✔. 14c ✔. 14d ✔. 14e ✔. 15 ✔. 16 ✔ (drop
test stages — stated in the test, proven by M4). 17 ✔. 17a ✔ (scan retired, set test renamed, message
reworded, pinned substring updated). 18 ✔ (run 3).

**Deviations and false premises found (reported, not silently adapted).**
- *No Tasks/Subtasks section exists in the story.* The dev-story workflow assumes one; the ACs were used
  as the task list. Nothing was checked off because there is nothing to check.
- *A hard layer gate was added* (`flags.pitch_zone`, first check, `REASON_FLAG_CLOSED`) in ADDITION to
  the condition's `required_flag`. The story's AC 3/4 describe only the `required_flag` gate; the
  project-context HARD RULE and the `5-2/R13` mode ②/③ precedent require the layer itself to be
  switchable regardless of data. The nine cards also author `required_flag = &"pitch_zone"`, which
  AC 1a does not rule — harmless redundancy, easy to drop at review if unwanted.
- *`test_card_authoring.gd::CARD_DATA_FIELDS` had to move six -> seven* (`pitch_condition`) — the story
  does not name that pin; it fails otherwise by design.
- *AC 1b's test name is now partly stale* (`test_basic_mode_only_pitch_and_orbs_left_unauthored`) —
  kept, because AC 1b says EXTEND not replace; flag for review under the `5-5` rename discipline.
- *AC 17's premise verified true*: the reflection loop skips bools (`if kind != TYPE_FLOAT and kind !=
  TYPE_INT: continue`); `pitch_stage_clears_orbs` needs no `E1_BALANCE_FIELDS` entry.
- *Unnamed ripple*: `test_live_reload.gd` pins the capture-channel COUNT (11 -> 12, renamed); four other
  recorder fixtures (`test_intent_recorder`, `test_record_file`, `test_replay_identity`, integration
  `test_replay_contacts` / `test_replay_entry_is_inert` / `test_replay_verifier_tool`) had to capture
  the new channel. The story named only the drop test.
- *The v8-refusal test does not guard the version bump by itself* (M19 finding above).
- *Fix-pass note, not fixed (review finding M2, record only):* `_resolve_pitch_stage`'s CHARGING
  guard reuses `REASON_UNBLOCKABLE_COMMITTED` verbatim for a staging refusal, the same token every
  prior use describes for mode ②'s own commitment state. This is INTENTIONAL, not a copy-paste
  reuse to tidy up later: the token names the CAUSE (the hero IS committed to an unblockable,
  regardless of what it just tried to do next), not the attempted action, and that cause is
  identical whether the refused action was a mode ② cast or a mode ④ stage. A future consumer that
  reads this reason string as implying "mode ② was attempted" would misclassify a staging refusal —
  named here so a later reader does not "fix" it into a pitch-specific reason without cause.
- *Script default of `pitch_stage_timer_seconds` is 0.0* (authored 20.0), sibling-duration convention,
  with a bespoke `> 0` authored bound — the story said "provisional 20.0" without saying where.
- *No `card_cast_resolved` is queued at staging* (nothing resolved); staging's only announcement is
  `notify_cards_changed()` (AC 8a).
- *Presentation note for 6-3*: a staged slot is a hole that is NOT in `pending_draw_owed`, so the HUD
  would currently paint it like a permanent hole. Unreachable live until 6-4 wires the input.
- Board: see the Change Log entry — only the custom `on_complete` wrote `sprint-status.yaml`.

### File List

Modified:
- `data/balance/balance_config.tres`
- `data/cards/bramble_snare.tres`, `data/cards/ember_lash.tres`, `data/cards/frost_dart.tres`,
  `data/cards/hellforge_totem.tres`, `data/cards/imp_summoner.tres`, `data/cards/storm_kite.tres`,
  `data/cards/thornback_guardian.tres`, `data/cards/tidal_wardstone.tres`,
  `data/cards/verdant_wardstone.tres`
- `data/feature_flags.tres`
- `src/main/match_runner.gd`
- `src/state/economy/cast_evaluator.gd`
- `src/state/match_state.gd`
- `src/state/pitch/pitch_state.gd`
- `src/state/resources/balance_config.gd`
- `src/state/resources/card_data.gd`
- `src/state/timing/balance_ticks.gd`
- `src/systems/intent_recorder.gd`
- `src/systems/record_file.gd`
- `test/integration/test_deck_injection.gd`
- `test/integration/test_replay_contacts.gd`
- `test/integration/test_replay_entry_is_inert.gd`
- `test/integration/test_replay_verifier_tool.gd`
- `test/state/test_balance_authoring.gd`
- `test/state/test_card_authoring.gd`
- `test/state/test_card_play.gd`
- `test/state/test_cast_evaluator.gd`
- `test/state/test_data_resources.gd`
- `test/state/test_determinism.gd`
- `test/state/test_intent_recorder.gd`
- `test/state/test_live_reload.gd`
- `test/state/test_record_file.gd`
- `test/state/test_replay_identity.gd`
- `docs/implementation-artifacts/6-2-pitch-staging.md` (this record)
- `docs/implementation-artifacts/sprint-status.yaml` (custom `on_complete` only: `story_notes` +
  `last_updated`)

New (untracked, dev pass's own):
- `test/state/test_pitch_staging.gd`

### Fix Pass Record (post-review, code review report `C:\dev\_62-review.md`)

Fresh Sonnet 5 session, `/clear` done before this pass, no subagents/forks. Status stayed `review`;
no commits made; board untouched.

**Fix 1 (H1) — the orb PRICE came out of the hash; identity stays in.** `PitchState._zone_snapshot()`
no longer emits `"orb_costs"`; `_orb_costs` stays a per-slot member but is now an UNHASHED cache
read only by `is_ready()`, frozen at staging by the injection discipline (a map injected once at
match start, no reload path), not by being hashed. AC 14b/14c reworded above to address identity and
price separately (see those ACs for the full reasoning); `PitchState`'s class doc and `_orb_costs`'s
own doc updated to match. `test_replay_identity.gd`: the driven-run assertion now asserts
`card_id` IS in the hashed zone and `orb_costs` is NOT; `_orb_costs` moved from the `HASHED` bucket
to `UNHASHED_CROSS_TICK`, and `UNHASHED_CROSS_TICK_MEMBERS` moves from **3 to 4** (the pin's first
increase, disclosed not hidden — the orb price is a genuinely new argument, not a member of the
existing three). `test_pitch_staging.gd`'s two snapshot assertions that pinned `orb_costs` (a keyed
value and an empty-zone equality) now assert its ABSENCE from the zone dict instead.

**Golden — SECOND re-baseline, cause named separately from the first.** Old
`72d3cc6ed5caeeff8b1dded3a054faefa479bc371117c82982bccf04af6a9595`, new
`9ed4c9035a89b3219623dc129d73693e6871049bc9c48f672bc5554d49f5d5b2`. THE CAUSE:
`PitchState.to_snapshot()`'s per-zone dict shape shrinks from four keys (`card_id`, `hand_slot`,
`orb_costs`, `fizzle`) to three (`card_id`, `hand_slot`, `fizzle`) — a SHAPE change, moving the hash
even though this fixture's zones hash empty on every tick (the same "shape is the mover, values
never leave the empty record" reasoning the FIRST re-baseline's cause block already established).
Measured in both directions: forward (all fix-pass changes in place) hashed `9ed4c903…`; reverse
(ONLY `_zone_snapshot()` returned to its four-key shape, every other fix-pass change left in place)
hashed `72d3cc6e…` exactly, reproducing the pre-fix-pass golden. `pitch_state.gd` was copied to the
scratchpad before the reverse mutation and restored by copy-back, SHA-256
`5cf13c9514029570b3a452ed1c3e8c7fab6498d5b4e252fde9fa1fdc596ef3fc` before == after. Full cause block
in `test_determinism.gd` above `const GOLDEN`.

**Fix 2 (M1) — the redundant per-card flag dropped.** `required_flag = &"pitch_zone"` removed from
all nine `data/cards/*.tres` (line 21 in each, the shared authored shape). Verified BEFORE deleting,
by content, that no test reads the authored `pitch_condition.required_flag` value: the only tests
touching `required_flag` build in-test `CardCastCondition`/`ResourceGenerationRule` fixtures
(`test_card_authoring.gd`'s own shape-mirror test reads `cast_condition.required_flag`, a DIFFERENT
field, always `""`; `test_cast_evaluator.gd`, `test_mana_economy.gd`, `test_orbs_economy.gd`,
`test_totem_accelerators.gd` all construct their own conditions/rules in-test;
`test_pitch_staging.gd`'s own `required_flag` test sets `&"totems"` on an in-test fixture to prove
the mechanism is general-purpose, never reading the shipped `.tres`). The mechanism on
`CardCastCondition` itself is untouched.

**Fix 3 (M3) — the orb-price guard moved inside the per-card loop.** `test_card_authoring.gd::
test_basic_mode_only_pitch_and_orbs_left_unauthored`'s library-wide `priced_in_orbs > 0` (survived a
single card regressing to an empty price) replaced with a per-card `card.pitch_condition.orb_costs.
size() > 0` assertion inside the loop that already visits every card. Non-vacuity proof below.

**Suite (see Suite Mechanism results below for the actual counts/hashes filled in after the runs).**

**Judgment calls made, not pre-scripted by the fix prompt:**
- Kept `_orb_costs` as PitchState's own internal member (an unhashed cache) rather than deleting it
  and having `is_ready()` re-derive the price from `MatchState._pitch_costs` on every call. Both
  satisfy "stop hashing the price"; the cache keeps `is_ready(slot, orbs, flags)`'s signature and
  every one of its ~14 existing call sites (tests included) unchanged, and `PitchState` stays a pure
  container that never reads `MatchState`'s injected map directly — a smaller, lower-risk diff for
  the same architectural outcome. Recorded so a reader does not mistake the cache for an oversight.
- `test_replay_identity.gd`'s identity assertion (card_id present) is now proven against
  `live.pitch.staged_card_id(0)` rather than a hardcoded literal card id, since the staged card at
  STAGE_TICK is a fixture-shuffle outcome not previously pinned by name in that test.

Added:
- `test/state/test_pitch_staging.gd`

## Change Log

- 2026-09-13: Story authored (`gds-create-story`). Cancel exit path deferred to `6-4` per operator
  decision (see Scope note); all other content per the operator's create-story brief, measured
  against the repo before authoring.
- 2026-09-13: Readiness-gate fix pass. Promoted `authored` -> `ready-for-dev`. Rulings applied: the
  hand conservation identity grows a fifth term and the vacated slot is not appended to
  `pending_draw_owed` until fizzle (AC 3/8/11, Open Question 3 answered NO); mana is paid at
  staging with no refund on fizzle; READY is derived every tick, never latched (AC 10); the
  `pitch_zone` flag opens in `data/feature_flags.tres` THIS story per the `5-2/R14` precedent (AC
  2a, Open Question 4 closed); pitch costs are authored (not null) on all nine cards, provisionally
  (AC 1a); a new recorded channel bumps `FORMAT_VERSION` 8 -> 9 (AC 16a); the mode-reachability
  guard is retired, not narrowed a third time (AC 17a); the orb-clear switch (AC 12/13) is ruled
  "pitching clears, not the price clears" with both branches tested; the cancel deferral is now
  recorded as `6-4`'s committed scope in `epics.md`. Four gate-premise corrections applied: `Orb
  Pool.reset_all()` already has a real caller (`_reset_player`) and lives at `src/state/pools/`, not
  `economy/`; the cited guarded-stub test name did not exist, replaced with the three real names;
  Fact 9/Open Question 2 reopened an already-settled seam-ownership question and was deleted; the
  Hellburst citation was verified correct as-is. Reviewed against the repo by content throughout.
- 2026-09-14: Dev pass (`gds-dev-story`, Opus 5, no commits). Mode ④ staging built per ACs 1-18; golden
  9679fa80 -> 72d3cc6e (one cause, both directions measured); FORMAT_VERSION 8 -> 9; seams stay nine;
  unhashed cross-tick members stay three; 20-row mutation table in the Dev Agent Record; three full
  suite runs (one extra, disclosed). Status -> `review` (story-file-only). Board: the dev-story skill's
  own in-progress/review writes were NOT made (operator instruction: board not this pass's); the custom
  `on_complete` then set only `story_notes` and `last_updated`, entry left at `ready-for-dev # Tier A`.
