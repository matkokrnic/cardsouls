# Story 3.5b: Draw-replacement delay, deck exhaustion, and the reshuffle vulnerable window

Status: done

> **Scope note.** This file was authored at the 3-5 readiness gate (2026-08-04, decision-log
> Session 2026-08-04 -- Story 3-5 readiness gate) and AMENDED at its own readiness gate the same day
> (Session 2026-08-04 -- Story 3-5b readiness gate, rulings `3-5b/R1`..`3-5b/R18`). It carries the
> half of the original `E3.S5` (`stories-manual-e3.md`) that is WHAT THE TRIGGER MAKES REACHABLE,
> split out from 3-5a, which delivers THE TRIGGER (a working cast path). This file also carries the
> four items 3-3's own gate ruled must "move to 3-5 together with their trigger -- not split from it"
> (decision-log Session 2026-08-03 -- Story 3-3 readiness gate, finding (v)): discard, reshuffle-on-
> exhaustion, the vulnerable window, and the draw-on-play delay. That ruling is HONOURED here, not
> reopened: its purpose was that no mechanism ships before its trigger exists. 3-5a delivers the
> trigger; this file lands after it exists, as its own story rather than a 3-5a task.
>
> **HOLD LIFTED.** The HOLD this file previously carried was pending its own readiness gate. That
> gate ran on 2026-08-04, returned NOT READY on first read, and every finding was ruled and applied
> the same session. Status is `ready-for-dev`; `sprint-status.yaml` is updated alongside.
>
> **REFRAME (`3-5b/R1`) -- exhaustion is ALREADY REACHABLE in shipped code. This story REPLACES a
> shipped silent behaviour; it does not create a new one.** Measured, not assumed:
> `MatchState._resolve_basic_cast` draws a replacement on EVERY cast --
> `if not player.deck.is_empty(): player.hand.add(player.deck.draw_top())` -- so the pile drains one
> card per cast regardless of any delay. With the authored config (`deck_size` 20, `hand_size` 4) the
> deal leaves SIXTEEN in the pile, so the SEVENTEENTH cast in a round hits the `is_empty()` floor: no
> replacement is drawn, the hand shrinks below four permanently, and nothing signals it. That is the
> behaviour this story replaces. The delayed draw does NOT make exhaustion reachable -- it was
> already reachable the moment 3-5a shipped -- it changes only WHEN a replacement arrives. The
> "sixteen casts" arithmetic this file previously carried is correct; the conclusion drawn from it
> ("both being silently unreachable as they were in 3-3") was not. 3-5a's own code says so in the
> same file: `_resolve_basic_cast`'s comment reads "with no reshuffle in this story a pile CAN RUN
> DOWN", and `discard_pile.gd` reads "the deck only ever shrinks within one round". The 3-5a fence
> comment asserting the opposite lives in a CLOSED story's test file and is not edited here; the
> supersession is recorded formally in the decision log (`3-5b/R1`).

## Story

As a player,
I want a played card's replacement to arrive after an authored delay, and my deck to reshuffle from
the discard pile with a visible vulnerable window when it runs out,
so that the moment my deck empties is a real, legible event with real timing weight, instead of the
silent floor it is today -- where the hand simply shrinks below four and never recovers.

## Acceptance Criteria

1. **The delay field ships AUTHORED.** `draw_replacement_delay_seconds` lands on `BalanceConfig`, is
   listed in `E1_BALANCE_FIELDS` (`test/state/test_data_resources.gd`, whose existing loop asserts
   every listed field `>= 0.0` -- no bespoke non-negativity audit is added), and is AUTHORED `1.0` in
   `data/balance/balance_config.tres`. A BESPOKE authoring bound in
   `test/state/test_balance_authoring.gd` asserts the authored value is `> 0.0` -- the
   `deck_size`/`hand_size` precedent. Existence alone is NOT sufficient and the AC fails if only
   existence is checked: `field in config` and `>= 0.0` both pass on the script default of `0.0`,
   which would ship this story invisible in the build and recreate exactly the dead field
   `balance_config.gd`'s reservation comment was written to prevent. The tick-domain value is derived
   ONCE at load on `BalanceTicks` (the `stamina_regen_delay_ticks` precedent).
2. **The vulnerable-window field ships AUTHORED, and nothing reads it but its emitter.**
   `reshuffle_vulnerable_window_seconds` lands on `BalanceConfig`, is listed in `E1_BALANCE_FIELDS`,
   is AUTHORED `1.5` in `data/balance/balance_config.tres` (the GDD's "~1.5-2s TBD" range,
   `gdd.md`), carries the same bespoke `> 0.0` authoring bound as AC 1, and derives a tick-domain
   value on `BalanceTicks`. A NEGATIVE GUARD asserts that no file under `src/` READS the vulnerable
   window except the code that starts it and the code that emits its event -- no damage path, no
   mitigation path, no action-state path consults it. That guard is what keeps open decision (b) --
   what "vulnerable" COSTS -- genuinely open rather than closed by construction.
3. **The pending replacement draw is a timer plus a debt counter, ticked at step 2, delivered at
   step 6.** On a successful cast the replacement is NOT drawn in the same tick (unless the derived
   delay is zero ticks); a `TimingWindow` is started and an owed counter is incremented. The window
   is advanced in `advance()` **step 2**, beside `hero.tick_timers()` / `stamina.tick_timers()`. On
   expiry, DELIVERY happens in **step 6** -- exactly one card is drawn and the counter decremented,
   and the window RESTARTS while the counter is still above zero. `hand_size` is permitted to reach
   0. A cast is NOT gated on a pending draw: **no new rejection reason and no new refusal path
   ships**, mana remains the only throttle. Pinned by tests in both directions (a card arrives at the
   authored tick and NOT one tick earlier; four casts in flight deliver four cards, one per expiry).
4. **The snapshot gains EXACTLY TWO keys**, both on `PlayerState.to_snapshot()`: `pending_draw` (the
   `TimingWindow.to_snapshot()` shape, on the shipped `StaminaPool.to_snapshot()`
   `"regen_delay": _regen_delay.to_snapshot()` precedent) and `pending_draw_owed` (int). Both cross
   tick boundaries, which is exactly why they are hashed -- the `_deck_deal_pending` exclusion
   precedent is available only to state consumed inside the same `advance()` that armed it, and a
   pending draw that never crosses a tick is an instant draw. No card IDENTITY enters the snapshot;
   the vulnerable window's own state is carried by these keys' sibling window per AC 6 and is
   likewise count/tick-only. A test asserts the snapshot key set is exactly the expected set, so a
   third key cannot ship quietly.
5. **Reshuffle is LAZY, at draw time, in the SAME single step-6 RNG seat.** When a delivery would
   draw from an empty deck and that player's discard is non-empty, the discard is reshuffled into the
   deck and the draw proceeds -- all inside the existing step-6 seat that `_deal_pending_decks()`
   already occupies, so "the seeded RNG is consumed only inside `advance()`" (F2) stays true and
   there is no second RNG seat. There is no eager path at `deck_size == 0`. The reshuffle draws from
   THIS player's own discard only. It ships with **no new `Deck` or `Hand` method** -- expressible as
   `set_contents(discard.to_array())` + a shuffle + `discard.clear()` -- which is what keeps the
   `Deck`/`Hand` method-name fence green (see Fence Inventory). **The shuffle is NOT called inline
   here:** it routes through the ONE private `MatchState` shuffle helper AC 16 requires, which the
   match-start/reset deal (`_deal_player`) also routes through. Two shuffle OCCASIONS, one call site
   (`3-5b/R18`).
6. **The vulnerable window ships, owner-only, on the ownerless `EventBus`.** A reshuffle starts a
   `TimingWindow` on the reshuffling player for the AC 2 duration and queues a signal owned by
   `MatchState`, relayed by `match_runner.gd` onto `EventBus` after the drain (D5) -- the
   `round_started` / `round_ended` mechanism exactly (`_match_state.round_started.connect(
   _relay_round_started)` -> `EventBus.round_started.emit()`), per E3-RG/R3. The payload carries the
   vulnerable player's slot index. This is NOT an eighth observation seam: the frozen family (2-6/R7)
   is per-slot CONNECT-seam observation and stays at SEVEN `connect_*` methods on the runner; this is
   a match-wide public fact on the bus. **`test_deck_and_hand.gd::
   test_event_bus_still_carries_exactly_the_two_declared_signals` is DELIBERATELY UPDATED from two
   signals to three** -- that test exists precisely so this cannot happen quietly, and the story
   naming it is the record that it did not.
7. **Death does not cancel an in-flight draw; it drops the DELIVERY.** No early-stop path ships.
   1-9/R3 stays locked -- an in-flight window "is NOT stopped or shortened ... it simply resolves to
   nothing" (`match_state.gd`). A DEAD player's pending window ticks out normally and the delivery is
   discarded at step 6, the 1-9/R1 fact-drop idiom applied literally. A source scan asserts no
   `stop()` / `clear()` / early-abort call is made against the pending-draw window anywhere in
   `src/`. The delivery-time DEAD check is DEFENSE IN DEPTH and is unreachable in natural play
   (3-5/R6: DEAD and `_round_over` are set together and cleared together, so a DEAD player is always
   also frozen and step 1b returns before step 2 ever runs) -- it is proven non-vacuous by the
   repo's established forced-DEAD idiom (`set_action_state(DEAD)` with `_round_over` left FALSE),
   exactly like its step-3/4/5/6 siblings.
8. **The pending-draw window does not tick on a frozen round-over tick**, and this is stated
   explicitly rather than inherited silently. It follows structurally from the seat AC 3 fixes: step
   1b (`if _round_over: ... return`) returns BEFORE step 2, so no window advances during the freeze.
   Pinned by a test that freezes the round, advances many ticks, and asserts the pending window's
   remaining count is unchanged.
9. **The debug reset KILLS a pending draw; the card is not restored.** `_apply_debug_reset` /
   `_deal_player` already re-lay the full injected composition and clear the discard, so conservation
   is restored by construction and 3-3's AC 9 post-reset count pin (`hand_size` / `deck_size -
   hand_size`) stays green with no special case. A test asserts that a reset landing with a draw in
   flight leaves zero pending, zero owed, and the exact post-reset counts.
10. **Deck AND discard both empty is a NO-OP DEGRADE, never a crash.** No `Invariant.check(false)`
    ships on this path: reachability depends on authored balance numbers, and a crash path reachable
    from authored data is not acceptable. The draw resolves to nothing, the owed counter is consumed,
    the hand stays short, and the vulnerable window does NOT open (there was nothing to reshuffle).
    Gets its own headless test constructing the case directly.
11. **The conservation property gains a FOURTH term.** The invariant pinned by
    `test_card_play.gd::test_cast_conserves_the_injected_multiset` and by
    `test_determinism.gd::test_golden_sequence_exercises_the_recorded_cast` becomes
    **deck + hand + discard + in-flight** is a permutation of the injected composition. In-flight is
    a COUNT, not a card -- the card is drawn at delivery, so nothing is held in limbo; the fourth
    term exists because the hand is one short while a draw is owed. Both existing conservation
    assertions are updated, and the property is asserted across a reshuffle and across the
    both-empty case.
12. **Headless integration proof of exhaustion, reshuffle, and both-empty.** A test drives sixteen
    successful casts in one round in a fixed-`delta` loop and asserts: the pile empties; the
    seventeenth delivery reshuffles from the discard; `rng_state` MOVES across that reshuffle (and
    does not across a plain draw); the vulnerable-window event fires exactly once with the correct
    slot payload; and the both-empty case degrades per AC 10. Live observation cannot reach any of
    this (see Live Smoke), so headless is the only proof and it is required, not optional.
13. **A REFLECTIVE completeness guard over `BalanceConfig` ships.** Today both lists are
    hand-maintained -- `E1_BALANCE_FIELDS` is a literal `const Array[String]` and
    `test_balance_config.gd::test_conversion_covers_every_seconds_field` is a literal dictionary of
    nine fields -- so a `*_seconds` field added to `BalanceConfig` and forgotten in either place
    fails nothing. A new test reflects over `BalanceConfig.get_property_list()` and asserts (a) every
    script-declared float/int property appears in `E1_BALANCE_FIELDS`, and (b) every `*_seconds`
    property has a corresponding derived value produced by `BalanceTicks.from_config()`. This story
    adds two fields and is the forcing point. Mutation-proven: removing either new field from either
    list must fail this guard.
14. **The fence inventory below is delivered exactly as stated**, and every narrowed guard RETAINS
    both its vacuity assertion (`assert_true(scanned > 0, ...)`) and its regex self-test
    (`assert_true(re.search("func _reshuffle_deck() -> void:") != null, ...)`), so a typo cannot
    silently disarm a fence that has just been narrowed. Each surviving half and each replacement
    guard is mutation-proven.
15. **Both new windows survive a mid-match `apply_balance()` in flight** (the per-pool reload
    contract / CONSTRAINT C): a window already running keeps its original duration, and the new tick
    counts take effect at its next `start()`. Every new balance value is read INLINE from
    `ms.balance` / `ms.balance_ticks` at the point of use -- never a cached `BalanceTicks` reference.
    Pinned by the `test_mid_match_reload_refills_stamina_to_max` idiom.
16. **F2 becomes MACHINE-CHECKED: exactly ONE seeded-shuffle call site ships, and BOTH shuffle
    occasions route through it.** `src/state/match_state.gd` gains ONE private shuffle helper. It is
    the only thing in `src/` that calls `Deck.shuffle_with_rng()`, and BOTH occasions go through it:
    the match-start/debug-reset deal (`_deal_player`) and AC 5's reshuffle. A source scan over `src/`
    then asserts that `shuffle_with_rng(` appears in EXACTLY TWO places -- its definition in
    `src/state/deck.gd`, and that single caller in `src/state/match_state.gd`. **That count is the
    POST-LANDING count, and it is the AC**: the same scan run against today's `src/` also yields two,
    but for a different reason (one occasion, one call site), so passing before the work starts
    proves nothing. What this AC pins is that the count is STILL two after AC 5's second shuffle
    occasion exists -- which is only achievable via the shared helper. The scan carries the same
    vacuity assertion the other fences carry (`scanned > 0`), and is mutation-proven in the FALLING
    direction: adding a second call site anywhere under `src/` must make it FAIL. Home:
    `test/state/test_architecture_invariants.gd`, which already houses F1, D3(a), D3(b)/A2 and every
    later architecture-invariant source scan, and whose header enumeration ("F1, D3a, D3b") is
    updated to name F2. This is where the AC 5 one-seat clause stops resting on review: F2 -- "the
    seeded RNG is consumed only inside `advance()`" -- is cited as a contract by 3-3, 3-5a and this
    story and has been REVIEW-ENFORCED ONLY, because the existing D3(b)/A2 guard bans GLOBAL RNG in
    `src/state/`, not a SECOND SEEDED SEAT. 3-5b is the first story that can actually introduce one
    (AC 5's reshuffle), so it is F2's forcing point. **ESCAPE HATCH, and it is a real one:** if the
    shared helper genuinely contorts the code -- if the two paths turn out to differ by more than
    which array they shuffle -- the dev pass **STOPS AND ASKS** rather than quietly adding a second
    call site and relaxing this AC to three. A second seeded seat is a DESIGN change, not an
    implementation detail (`3-5b/R18`).

## Tasks / Subtasks

- [ ] Add `draw_replacement_delay_seconds` (authored `1.0`) and `reshuffle_vulnerable_window_seconds`
      (authored `1.5`) to `BalanceConfig`, `E1_BALANCE_FIELDS`, `balance_config.tres` and
      `BalanceTicks.from_config()`; bespoke `> 0.0` authoring bounds (AC: 1, 2)
- [ ] Negative guard: nothing under `src/` reads the vulnerable window except its starter and its
      emitter -- the guard that keeps open decision (b) open (AC: 2)
- [ ] Pending-draw timer + owed counter on `PlayerState`; ticked at step 2, delivered at step 6;
      restart while owed > 0; no cast gating and no new rejection reason (AC: 3)
- [ ] Snapshot gains exactly `pending_draw` and `pending_draw_owed`; key-set pin test (AC: 4)
- [ ] Lazy reshuffle at draw time inside the existing step-6 seat, own discard only, no new
      `Deck`/`Hand` method (AC: 5)
- [ ] Vulnerable window + `MatchState`-owned signal + runner relay onto `EventBus`; update the
      two-signal pin to three (AC: 6)
- [ ] Death drops the DELIVERY, never the window; source scan for early-stop; forced-DEAD
      non-vacuity test (AC: 7)
- [ ] Frozen-tick no-tick test (AC: 8)
- [ ] Debug reset kills pending draws; post-reset count pin stays green (AC: 9)
- [ ] Both-empty no-op degrade, no `Invariant.check(false)`, own test (AC: 10)
- [ ] Conservation gains the in-flight term; update both existing conservation assertions (AC: 11)
- [ ] Headless integration proof: sixteen casts, exhaustion, reshuffle, `rng_state` movement,
      window event payload, both-empty (AC: 12)
- [ ] Reflective `BalanceConfig` completeness guard against `E1_BALANCE_FIELDS` and
      `BalanceTicks.from_config()`, mutation-proven (AC: 13)
- [ ] Apply the fence inventory; retain every vacuity assertion and regex self-test; mutation-prove
      each surviving half and each replacement guard (AC: 14)
- [ ] In-flight windows survive `apply_balance`; all new values read inline (CONSTRAINT C) (AC: 15)
- [ ] Route BOTH shuffle occasions (the deal and AC 5's reshuffle) through ONE private `MatchState`
      shuffle helper; machine-check F2 by scanning `src/` for `shuffle_with_rng(` and pinning it to
      exactly two sites POST-LANDING (definition + that single caller), with a vacuity assertion,
      mutation-proven falling; update the invariant file's header enumeration to name F2. If the
      shared helper contorts the code, STOP AND ASK -- do not add a second call site (AC: 16)

## Dev Notes

- **Inherited from 3-3, verbatim scope.** 3-3's gate (finding (v)) ruled: "all four (discard,
  reshuffle, vulnerable window, and the draw-on-play delay that would trigger them) move to 3-5
  together with their trigger -- not split from it." At the time of that ruling "3-5" was undivided;
  this file is where that ruling actually lands, now that 3-5 itself has split. [Source: decision-log
  Session 2026-08-03 -- Story 3-3 readiness gate]
- **Open decision (b) stays OPEN here too**, unless AC5's ruling closes it deliberately. It is not
  re-logged as though newly discovered -- it was logged 2026-07-22 and carried forward, untouched, by
  every story since (3-3's Dev Notes: "Open decision (b) ... stays OPEN and is not re-logged").
- **`Deck.draw_top()` takes the LAST element** -- "top is the back" is the fixed convention (3-3 Dev
  Notes), unobservable in 3-3 and inherited here as the meaning of "top" for a reshuffled pile.
- **Both players are dealt the SAME injected composition** (3-3, one seam, one fixture composition).
  A reshuffle draws from THIS player's own discard pile only -- it does not touch the opponent's deck
  or discard, and does not re-derive a fresh composition from `CardDatabase`.
- **Discard pile ownership.** 3-5a ships the discard pile as a third pure container on `PlayerState`
  (its own AC6) with a count-only snapshot key. This story's reshuffle reads FROM that container
  (moves its contents back into the deck, then clears it) rather than defining a second discard
  concept -- 3-5a must exist first, which is exactly why the trigger-vs-reachable split places this
  file after it.
- **CONSTRAINT C applies** to any newly-derived tick field (`draw_replacement_delay_seconds` ->
  its `BalanceTicks` counterpart, and the vulnerable-window duration if AC5 authors one): read inline
  at point of use, never cached across a reload.

### Added at this story's readiness gate (2026-08-04, `3-5b/R1`..`3-5b/R18`)

- **The reframe (`3-5b/R1`) is the most important thing in this file.** See the Scope note. A dev
  pass that believes it is making exhaustion reachable will build the wrong thing; it is replacing a
  shipped, silent floor. What that floor does today, exactly: `is_empty()` short-circuits the draw,
  the hand permanently loses a card, no signal fires, and nothing in the snapshot distinguishes it
  from a normal state. Open decision (b) is untouched by this reframe.
- **Where the ruling on decision (b) actually landed (`3-5b/R7`).** AC5 as previously written offered
  a false dilemma -- "author the price" versus "author nothing". A `TimingWindow` cannot exist
  without a duration, and `stories-manual-e3.md` E3.S5b item 4 requires the window open "for the
  authored ticks". So the field IS authored. What stays open is the window's mechanical COST, and
  AC 2's negative guard is the mechanism that keeps it open: if nothing reads the window, nothing has
  priced it. Decision (b) is NOT closed by this story.
- **The step-2 tick / step-6 delivery split (`3-5b/R3`, `3-5b/R5`) is not a compromise, it is the
  shipped idiom.** `StaminaPool._regen_delay` is already ticked at step 2 and READ at step 5. Putting
  the pending draw's tick at step 2 buys the frozen-tick contract (AC 8) for free, because step 1b
  returns before step 2. Putting its DELIVERY at step 6 keeps the reshuffle inside the one existing
  RNG seat (AC 5) instead of opening a second one at step 2 -- which is what a naive
  "tick and draw in the same place" reading would have done, and it would have broken F2's
  provability by inspection.
- **AC 7 is honest about being nearly vacuous, and says how it is proven anyway.** Because DEAD and
  `_round_over` are a total coupling (3-5/R6), a dead player's `advance()` returns at step 1b and
  neither the tick nor the delivery ever runs; a subsequent debug reset then kills the pending draw
  (AC 9). So the delivery-time DEAD check is unreachable in natural play. It ships as defense in
  depth in the same family as the DEAD branches at steps 3, 4, 5 and 6, each unreachable for the
  identical reason and guarded anyway, and it is proven non-vacuous by the same forced-DEAD idiom.
  This is recorded so a later reader does not file the guard as dead code.
- **`3-5/R8` is CLOSED by this story (`3-5b/R2`), and the log's self-contradiction is resolved by
  ruling rather than by editing.** The 3-5 gate's blocking finding 6 stated the no-cancel outcome as
  a requirement; the later 3-5/R8 recorded the same question as OPEN with 3-5b as owner. Both are
  now discharged the same way: the operator's sealed intent was about the OUTCOME (a corpse is not
  handed a card), not about the MECHANISM. Dropping the delivery satisfies the intent without an
  early-stop path, so 1-9/R3 is never reopened. Neither earlier entry is edited (append-only).
- **The golden fixture's nonzero delay breaks three existing non-golden assertions, and that is
  expected work, not a regression.** `test_determinism.gd` currently pins the INSTANT refill by name:
  `test_golden_sequence_exercises_the_recorded_cast` asserts `ms.p1.hand.size() == HAND_SIZE` with
  the message "INSTANT refill: the hand is back to full", and `ms.p1.deck.size() == DECK_SIZE -
  HAND_SIZE - 1`; `test_golden_sequence_exercises_deck_shuffle_and_hand_fill` asserts the same two
  counts. The fixture casts at t22 and hashes at t24, so an authored delay of one second (60 ticks)
  leaves the draw still pending at the hashed tick: the hand is one SHORT and the deck one HIGHER.
  All three must be rewritten to the new expected counts and to the AC 11 four-term conservation, and
  per the golden discipline they must be green and proven BEFORE the re-baseline is taken.
- **`test_the_recorded_cast_consumes_no_rng` stays green and stays kept.** `draw_top()` consumes no
  RNG whether it happens on the cast tick or sixty ticks later, so a delayed draw does not move
  `rng_state`. That test is the forward half of golden cause C4; the reverse half is new (see Golden
  Prediction).
- **Architecture-amendment queue, seventh member: its conditional clause FIRES on this story** -- "if
  a vulnerable-window signal lands with 3-5, the `EventBus` header and the seam registry both need
  reconciling against the bus's enumerated signal set". AC 6 lands that signal. Recorded, NOT flushed:
  the flush point remains the E3 close-out, unchanged.
- **3-0c obligation, extended (`3-5b/R14`).** The log previously recorded only that the injected deck
  COMPOSITION must enter the replay record alongside seed, intents and reload events. The injected
  COST MAP (`inject_card_costs`, 3-5a AC4) is in the identical position -- injected at match start,
  excluded from `to_snapshot()`, and outcome-changing -- so a replay against a re-priced card set
  diverges silently. The obligation now covers both. This story adds NO further replay-relevant
  injected state of its own: its two new values are `BalanceConfig` fields, already covered by DEBT
  B's reload-events-in-the-stream half.
- **F2 was REVIEW-ENFORCED ONLY until this story, and AC 16 (`3-5b/R17`, corrected by `3-5b/R18`) is
  where that ends.** This
  story's gate reported the one-seat clause as an uncovered gap and declined to invent an invariant
  to close it; the operator ruled that the guard SHIPS. Worth stating plainly for the dev pass,
  because it is easy to assume otherwise: the existing D3(b)/A2 scan bans the bare `randf`/`randi`
  family and the implicit-global-RNG collection APIs inside `src/state/` -- NOTHING in the suite
  today would fail if `_rng` were consumed from a second call site, which is exactly the mistake
  AC 5 is written to prevent and the one a lazy reshuffle makes easy to reach for. Measured at gate
  time, `src/` contained exactly two `shuffle_with_rng(` occurrences: the definition (`deck.gd`) and
  the single call in `_deal_player` (`match_state.gd`). AC 16 pins that count POST-LANDING -- see the
  next bullet, which is why that distinction is load-bearing. Note which direction the proof runs:
  FALLING -- a second call site must BREAK the guard -- because a guard that only confirms the
  current count is one refactor away from being vacuous.
- **`3-5b/R17`'s original two-occurrence form was SELF-CONTRADICTORY, and `3-5b/R18` corrects it.**
  Worth reading before writing any code, because the trap is subtle and the guard would have failed
  on its own story. R17 measured `shuffle_with_rng(` at two occurrences and pinned that number. But
  the measurement was taken PRE-IMPLEMENTATION, and AC 5 specifies a reshuffle that shuffles: with
  `_deal_player`'s existing call plus a reshuffle call, the post-landing count is THREE, so a guard
  pinned at two fails the moment the story it guards lands. Neither the ruling nor the gate that
  produced it caught this. The correction is not to relax the guard to three -- that would concede
  the second seat the guard exists to prevent -- but to remove the second CALL SITE while keeping
  both shuffle OCCASIONS: one private `MatchState` helper, called by the deal and by the reshuffle
  alike. "The seeded RNG is consumed in one seat" then becomes literally true rather than
  approximately true. **If the shared helper genuinely contorts the code, STOP AND ASK.** A second
  seeded seat is a design change and is the operator's call, not the dev pass's.

### Fence Inventory

Every guard 3-5b touches or is measured against, with its verdict. A fence that evaporates without
being named here is a defect (AC 14). All live in `test/state/test_deck_and_hand.gd` unless noted.

| Guard | Scope | Verdict for 3-5b |
|---|---|---|
| `test_no_reshuffle_exhaustion_or_draw_delay_surface_ships` -- tokens `reshuffle`, `vulnerab`, `draw_replacement` in code under `src/` (comments stripped) | src/ | **BAN DIES for these three.** 3-5b is the legitimate owner that introduces them. |
| ...the same guard's `exhaust` token | src/ | **STAYS BANNED.** Exhaustion is expressible as `is_empty()`, which is already how 3-5a expresses it. The narrowed guard keeps `exhaust` and keeps both its vacuity assertion and its regex self-test. |
| `test_no_card_effect_consumer_ships` -- `CardEffect` | src/, excluding `card_effect.gd`, `card_cast_condition.gd`, `card_data.gd` | **SURVIVES UNTOUCHED.** 3-5b resolves no effects. Correction of record: `CardEffect` is NOT banned from `src/` -- the class ships (`class_name CardEffect`) and `card_data.gd` exports it twice; the fence bans a CONSUMER and excludes those three files by name. |
| `test_no_pitch_stage_or_other_reserved_card_action_ships` -- Input Map names containing `play`, `draw`, `pitch`, `discard`, `hand`, `stage` | project.godot | **SURVIVES.** 3-5b adds no Input Map actions and does not touch `project.godot`. |
| `test_card_scheme_input_actions_ship_for_both_players` -- the positive Input Map pin | project.godot | **SURVIVES.** Unchanged by this story. |
| `test_hand_and_deck_expose_no_play_or_discard_path` -- method names on `Deck`/`Hand` containing `discard`, `play`, `reshuffle`, `refill`, `exhaust` | `deck.gd`, `hand.gd` | **STAYS GREEN via the no-new-method route** (AC 5): `set_contents(discard.to_array())` + a shuffle through AC 16's shared helper + `discard.clear()`. Adding a `Deck.reshuffle()` would kill it -- do not. |
| `test_event_bus_still_carries_exactly_the_two_declared_signals` | `src/systems/event_bus.gd` | **DELIBERATELY UPDATED, two -> three** (AC 6). The story naming it is the record that the change was intended. |
| `test/state/test_architecture_invariants.gd` -- F1, D3(a), D3(b)/A2 | src/ | **UNCHANGED and must stay green, and GAINS A SIBLING.** These ban GLOBAL RNG in `src/state/`, not a second SEEDED seat, so they never covered AC 5's one-seat discipline -- which is why the gate report named it an uncovered gap. **AC 16 CLOSES IT** (`3-5b/R17`, corrected by `3-5b/R18`): a new scan in this same file pins `shuffle_with_rng(` to exactly two occurrences POST-LANDING -- its definition plus ONE caller, the private `MatchState` helper both shuffle occasions route through. The count is only achievable via that helper: AC 5's reshuffle is a second shuffle OCCASION, and pinning two without the helper would fail on this story's own landing. F2 becomes machine-checked for the first time; the file's header enumeration gains it. |

### Project Structure Notes

- New `BalanceConfig`/`BalanceTicks` fields alongside the existing `*_seconds`/`*_ticks` pairs
  (`src/state/resources/balance_config.gd`, `src/state/timing/balance_ticks.gd`); the pending-draw
  window ticks at `MatchState.advance()` step 2 beside the existing `tick_timers()` calls, and its
  delivery plus the reshuffle seat inside step 6, beside `_deal_pending_decks()`; the vulnerable
  window is a `TimingWindow` on `PlayerState`; the new signal is owned by `MatchState` and relayed by
  `match_runner.gd` after the queued drain (D5) onto **`src/systems/event_bus.gd`** -- verified by
  content, this is the only `event_bus.gd` in the tree, and the fence test loads it at
  `res://src/systems/event_bus.gd`. (`src/main/event_bus.gd`, named in this section before the gate,
  does not exist; corrected per `3-5b/R15`.)

### Project Context Rules

- **Seeded RNG consumed only inside `advance()`; no bare global RNG in `src/state/`.** [Source:
  docs/project-context.md#Controllers & state-layer determinism, A2]
- **`EventBus` carries a small fixed typed set only, relayed by the runner after the drain.** [Source:
  docs/game-architecture.md#Standard Patterns & Consistency Rules; #D5]

### References

- [Source: stories-manual-e3.md#E3.S3 items 3-4; #E3.S5b items 1-4]
- [Source: gdd.md#A Card System — Deck & hand]
- [Source: decision-log.md Session 2026-07-22 — open decision (b)]
- [Source: decision-log.md Session 2026-07-31 — E3 revisit gate (outcome), E3-RG/R3]
- [Source: decision-log.md Session 2026-08-03 — Story 3-3 readiness gate]
- [Source: decision-log.md Session 2026-08-04 — Story 3-5 readiness gate]
- [Source: decision-log.md Session 2026-08-04 — 3-5a close-out, 3-5/R6, 3-5/R8]
- [Source: decision-log.md Session 2026-08-04 — Story 3-5b readiness gate, `3-5b/R1`..`3-5b/R18`]

## Golden Prediction

**Baseline, re-derived at write time from the `GOLDEN` constant in `test/state/test_determinism.gd`
(HEAD `2d944b6`), not copied forward from any earlier story text:**
`c4b9f897138a2b36dbce11f939b2892379919909c17df1696cde24a75c070e2e`.

**Prediction: MOVES. ONE re-baseline, FOUR separately named causes, each measured in BOTH
directions.**

- **C1 -- the `pending_draw` snapshot key. MOVER.** Forward: add the key alone, all-zero values,
  unconditional, with NO behaviour change and the fixture delay at `0.0` -- expect a move. This is
  the M1 shape from 3-5/R2 exactly ("cause 1, `discard_size` key, all-zero values, unconditional,
  moved the hash alone"). Reverse: remove that key only -- expect the exact baseline back.
- **C2 -- the vulnerable-window snapshot key. MOVER.** Forward: add on top of C1, still all-zero,
  still no behaviour change -- expect a further move. Reverse: remove only C2's key -- expect C1's
  measured hash BIT-IDENTICALLY. Adding ONE KEY AT A TIME is what separates C1 from C2; measuring
  them together would leave neither named.
- **C3 -- the authored delay, in TWO steps, isolating the SEAT from its CONTENT (the M2 precedent).**
  (a) Fixture priced `0.0`: the recorded cast refills instantly, i.e. exactly today's behaviour --
  expect C1+C2's hash BIT-IDENTICALLY, proving the mechanism alone moves nothing. (b) Fixture priced
  NONZERO and still running at the hashed tick: expect a further move, because that tick's
  `hand_size` is one LOWER and `deck_size` one HIGHER (the fixture casts at t22 and hashes at t24).
  Reverse: re-price to `0.0` -- expect (a)'s hash exactly. **The golden fixture MUST author a nonzero
  value in its final form**, per the standing lesson that a fixture which does not author its own
  content measures a false non-move.
- **C4 -- `rng_state`. NON-MOVER.** `_golden_config` authors `deck_size` 17 / `hand_size` 9, leaving
  EIGHT cards in each pile after the deal, against a recorded sequence landing ONE cast. The fixture
  therefore cannot reach exhaustion, `shuffle_with_rng` is never re-entered, and `draw_top()` consumes
  no RNG whether it fires on the cast tick or sixty ticks later. Forward half: keep
  `test_the_recorded_cast_consumes_no_rng` green. Reverse half, and it is REQUIRED -- prove that a
  reshuffle DOES move `rng_state`, in a SEPARATE, NON-GOLDEN fixture driven to exhaustion (AC 12).
  Without that reverse measurement C4 is a vacuous claim.

**The golden sequence is NOT widened to reach exhaustion.** Eight casts inside a ~24-tick recorded
window would rewrite the fixture around one cause. Exhaustion, reshuffle and the both-empty case are
proven in dedicated headless tests instead (AC 12), which is where they belong.

**Discipline, restated for the dev pass:** every non-golden test green and proven BEFORE the
re-baseline is taken -- including the three assertions the nonzero fixture delay breaks (see Dev
Notes); ONE re-baseline with its causes named separately; each cause measured in both directions;
every mutation target restored from an out-of-repo SHA256-verified copy, `git checkout --` never
used.

## Live Smoke

**NOT REQUIRED, and the reason previously given here was wrong.** The old reason -- that reaching
exhaustion would need an unrealistic grind -- is not the binding one, and it also assumed the false
premise corrected by `3-5b/R1`. The true reason is 3-3's: **this story ships NO player-facing
surface.** Measured by content:

- the HUD card row renders the presentation-local constant 4 and never reads the hand --
  `hud_root.gd`: "The rendered count is the presentation-local constant 4 (2-5/R1) ... no read of
  `PlayerState.hand`, no `hand_size` field" -- so a card leaving or arriving changes nothing on
  screen, and a delayed replacement is invisible;
- the deck readout is a literal placeholder string, `_make_placeholder_panel("DeckIndicator",
  "DECK -- / RESH")`, wired to nothing;
- the vulnerable window's renderer is **3-6** (E3.S6 item 3, "clearly flagged in both viewports"),
  which is precisely why the locked order is `3-5a -> 3-5b -> 3-0c -> 3-6`.

3-5a's own smoke already recorded this as finding **S5** ("no feedback on a cast at all") and waived
deck shrinkage as smoke-invisible. AC 12's headless proof is the whole verification story here.

**R-D6 smoke acceptance is NOT re-invoked by this story.** It was re-invoked and SPENT at 3-5a; it
remains **3-6's** to re-invoke, since 3-6 is where any of this becomes visible.

**S1/S2 ASTERISK -- CARRIED FORWARD, NOT SPENT.** The melee/mana retune was DELIBERATELY SKIPPED
(operator ruling, 4 Aug 2026): the criterion "a round funds 2-4 loop cycles" is arbitrary while the
cycle -- buildup -> bluff -> payoff -- does not exist. Today there is only BUILDUP: no bluff (no
hidden cards) and no payoff (effects do nothing; `card_cast_resolved` emits an id with no listener,
and no `CardEffect` consumer exists anywhere in `src/`). Tuning against that is fitting to noise, and
the real balance pass has its forcing point at **E4/E5**. The consequence is that the mana rate is
KNOWN too fast and the melee share KNOWN too large -- both recorded in the operator's own playtest
log ("cini se mozda malo prebrzo", "svaki udrac generira previse mane 10% je puno"). Because this
story runs no live smoke, that asterisk is **not spent here**: it is carried forward to **3-6** and
to the **E4/E5 balance pass**. Any future conclusion about the reachability of deck exhaustion drawn
from a LIVE session carries it, because casts per round is a direct function of mana income and mana
income is known miscalibrated in the direction that makes casts cheaper and more frequent.

## Dev Pass Record

Dev pass model: **Claude Opus 5**. This section records that pass's substance; the commit chain that
lands it (the code/tests commit, this doc commit, the board promotion and the decision-log
close-out) is a separate session. NOTHING IS COMMITTED OR STAGED BY THIS PASS.

- **Suite outcome.** State harness 287 tests / 1297 assertions / 0 failed -> **310 tests / 1463
  assertions / 0 failed**; **18/18** integration files PASS individually
  (`test_deck_reshuffle.gd` added this story); zero `SCRIPT ERROR` / `Parse Error` /
  `INVARIANT VIOLATED` lines. `project.godot` is BYTE-IDENTICAL start to finish
  (`8879DE49...070004`) — 3-5b adds no Input Map action. Two new `.gd` files, so two `.uid`
  siblings are owed from the editor scan at chain time.
- **Golden re-baseline (the SEVENTH)**, `c4b9f897` -> `40eb5554`, ONE re-baseline, measured one edit
  at a time. Every non-golden test was GREEN with the nonzero fixture delay in place BEFORE the
  sequence was started — including the three assertions that delay breaks (see below).

  | # | Step | Hash | Verdict |
  |---|------|------|---------|
  | M0 | both windows + the debt owned by `PlayerState`, mechanism present but INERT, fixture priced `0.0`, nothing snapshotted | `c4b9f897` | UNMOVED — the zero point |
  | M1 | + `pending_draw` key alone, all-zero, mechanism still inert | `9bcfcd7a` | MOVED — cause C1 |
  | M2 | + `pending_draw_owed` key, all-zero, mechanism still inert | `b5b4da8d` | MOVED — cause C2 |
  | M3a | mechanism RE-ENABLED (step-2 tick, step-6 delivery, debt, reshuffle, signal), fixture still `0.0` | `b5b4da8d` | UNMOVED — seat isolated from content |
  | M3b | + `DRAW_DELAY_TICKS` 11 | `40eb5554` | MOVED — cause C3(b) (FINAL) |
  | R1 | remove ONLY C2's key | `9bcfcd7a` | reproduced M1 exactly |
  | R2 | re-price the delay back to `0.0` | `b5b4da8d` | reproduced M2/M3a exactly |

  **C4 (`rng_state`) — predicted NON-MOVER, measured a non-mover, BOTH directions.** Forward:
  `test_the_recorded_cast_consumes_no_rng` stays green and stays kept — `draw_top()` consumes
  nothing whether it fires on the cast tick or eleven ticks later. Reverse, and the story is right
  that it is required: a reshuffle DOES move `rng_state`, measured in two separate non-golden
  fixtures (`test_draw_delay_and_reshuffle.gd` and, on the AUTHORED config,
  `test/integration/test_deck_reshuffle.gd`), each of which ALSO measures that a plain delivery
  draw does not.
- **The three assertions the nonzero delay breaks were rewritten and green before the re-baseline**,
  exactly as the Dev Notes require: `test_golden_sequence_exercises_the_recorded_cast`'s "INSTANT
  refill" hand assertion and its deck count, and the same two counts in
  `test_golden_sequence_exercises_deck_shuffle_and_hand_fill`. A FOURTH was found and rewritten too,
  not named in the story: `test_two_matches_with_a_populated_deck_hash_identically` carries the same
  `DECK_SIZE - HAND_SIZE - 1` sanity count. All four now read the in-flight counts, and both
  conservation sites gained AC 11's fourth term.
- **DISCREPANCY REPORTED, NOT SILENTLY RESOLVED — the Golden Prediction's C2 caption.** C2 is
  captioned "the vulnerable-window snapshot key", but that key does not exist in the delivered
  software, and it cannot: **AC 4** rules the snapshot gains EXACTLY TWO keys and names them both
  (`pending_draw`, `pending_draw_owed`) with a key-set pin so "a third key cannot ship quietly", and
  **AC 2** rules that nothing under `src/` may READ the vulnerable window — `to_snapshot()` is a
  read. The two ACs are followed as written. Everything else in C2's text describes the second
  pending-draw key exactly ("add on top of C1, still all-zero, still no behaviour change", "remove
  only C2's key — expect C1's measured hash BIT-IDENTICALLY", "adding ONE KEY AT A TIME is what
  separates C1 from C2"), so the four causes are all present and all measured; only the caption is
  wrong. Recorded in `test_determinism.gd`'s re-baseline record as well. **The consequence is
  stated plainly:** the vulnerable window is cross-tick state that is NOT hashed. That is safe only
  because nothing reads it — state no code consults cannot change an outcome or desync a replay —
  and AC 2's guard is precisely what keeps that premise true. If a later story prices the window,
  it must enter the snapshot at the same time.
- **AC 16's shared shuffle helper did NOT contort the code, so the escape hatch was not taken.**
  Both occasions were already "lay contents down, then shuffle", so the helper is one line
  (`MatchState._shuffle_deck`) and both call sites read better than before. `shuffle_with_rng(`
  stands at exactly TWO occurrences under `src/` post-landing — `deck.gd`'s definition and that one
  helper — and the guard additionally pins WHICH two files, so two calls plus a moved definition
  cannot pass on the count alone. Proven FALLING (row M-A).
- **The `EventBus` two-signal pin was DELIBERATELY UPDATED to three**, per AC 6. It is not a broken
  test; it is the mechanism working. Both it and the narrowed surface fence were RENAMED to stop
  their names asserting counts and tokens that are no longer true, and each records its OLD NAME
  verbatim in its docstring so the Fence Inventory stays greppable:
  `test_event_bus_still_carries_exactly_the_two_declared_signals` ->
  `..._the_three_declared_signals`, and
  `test_no_reshuffle_exhaustion_or_draw_delay_surface_ships` -> `test_no_deck_exhaustion_surface_ships`.
- **The runner stays at SEVEN `connect_*` seams.** The vulnerable-window signal is a match-wide fact
  relayed onto `EventBus` after the drain on the `round_started` mechanism (one `connect` in
  `_ready()`, one `_relay_*` method) — not an eighth observation seam.
- **CONSTRAINT C honoured:** both new values are read inline from `ms.balance_ticks` at the point of
  use (`_resolve_basic_cast`, `_deliver_pending_draw`, `_reshuffle_discard_into_deck`); no
  `BalanceTicks` reference is cached anywhere. Pinned for BOTH windows by AC 15's two tests.
- **AC 13's reflective guard found TWO REAL PRE-EXISTING DEFECTS on its first run**, which is the
  strongest possible evidence it is not vacuous. `attack_stamina_cost` (shipped by the stamina-cost
  corrective pass) and `block_facing_arc_degrees` (shipped by 1-8) were never added to
  `E1_BALANCE_FIELDS`, so neither live tunable was covered by the non-negativity audit and nothing
  failed. Both are now listed, with the finding recorded inline. This is reported rather than
  quietly repaired because it is a four-story and eleven-story hole in a hand-maintained list.
- **AC 10's reachability premise is STRICTER than the story states, and this is reported rather
  than deviated from.** The AC says reachability "depends on authored balance numbers". Measured:
  with `deck + hand + discard` conserved, a delivery finding both piles empty requires the hand to
  hold the entire composition, which forces successful draws to exceed casts — impossible. The
  both-empty case is therefore UNREACHABLE IN NATURAL PLAY at ANY authored numbers, in the same
  family as the DEAD branches. The AC is delivered exactly as written (no-op degrade, no
  `Invariant.check`, its own headless test); the test CONSTRUCTS the case directly, which the AC
  already anticipates ("constructing the case directly"). The no-op is if anything better justified
  than the story argues: a crash guard on an unreachable path fires only after some later story
  makes it reachable.
- **Mutation table.** Every target backed up OUTSIDE the repo and restored from that copy with a
  SHA256 equality check; `git checkout --` never used. Every new guard proven FALLING.

  | # | Mutation | File | Target guard | Fell |
  |---|---|---|---|---|
  | M-A | add a SECOND `shuffle_with_rng(` call site | `match_state.gd` | AC 16 / F2 count scan | `test_exactly_one_seeded_shuffle_call_site` (+2) |
  | M-B | a damage path reads `target.vulnerable_window.is_running` | `match_state.gd` | AC 2 negative guard | `test_nothing_in_src_reads_the_reshuffle_vulnerable_window` (1) |
  | M-C | `pending_draw.is_running = false` force-close | `match_state.gd` | AC 7 early-stop scan | `test_nothing_in_src_stops_or_clears_the_pending_draw_window` (1) |
  | M-D | drop the new field from `E1_BALANCE_FIELDS` | `test_data_resources.gd` | AC 13 half (a) | `test_balance_config_field_lists_are_complete_by_reflection` (1) |
  | M-E | delete the `from_config` derivation | `balance_ticks.gd` | AC 13 half (b) | same guard, + 15 behavioural (16) |
  | M-F | `var _deck_exhausted := false` in `src/` | `match_state.gd` | narrowed `exhaust` fence | `test_no_deck_exhaustion_surface_ships` (1) |
  | M-G | a FOURTH `EventBus` signal | `event_bus.gd` | updated bus pin | `test_event_bus_still_carries_exactly_the_three_declared_signals` (1) |
  | M-H | author the delay `0.0` | `balance_config.tres` | AC 1 bespoke bound | `test_authored_card_timing_values_are_positive` (1) |
  | M-I | author the vulnerable window `0.0` | `balance_config.tres` | AC 2 bespoke bound | same guard (1) |
  | M-J | ship a THIRD snapshot key | `player_state.gd` | AC 4 key-set pin | key-set pin + AC 2 read guard + golden (3) |
  | M-K | gate the cast on a pending draw | `match_state.gd` | AC 3 no-new-refusal | `test_a_cast_is_not_gated_on_a_pending_draw` (+3) |
  | M-L | delete the delivery-time DEAD check | `match_state.gd` | AC 7 | `test_a_dead_player_ticks_the_window_out...` (1) |
  | M-M | hoist the tick ABOVE the round-over freeze | `match_state.gd` | AC 8 | `test_the_pending_draw_window_does_not_tick_on_a_frozen...` (1) |
  | M-N | reset no longer kills a pending draw | `match_state.gd` | AC 9 | `test_a_debug_reset_kills_a_pending_draw...` (1) |
  | M-O | draw anyway when both piles are empty | `match_state.gd` | AC 10 | 2 tests + the exact `Out of bounds get index '-1'` crash |
  | M-P | add `Deck.reshuffle()` | `deck.gd` | Deck/Hand method fence | `test_hand_and_deck_expose_no_play_or_discard_path` (1) |
  | M-Q | seat the delivery BEFORE the cast dispatch | `match_state.gd` | AC 3 zero-delay degrade | `test_a_zero_derived_delay_degrades...` + 3-5a's instant-refill test (2) |

  M-J's FIRST run exposed a REAL BLIND SPOT IN A GUARD THIS STORY WROTE, and the guard was
  strengthened rather than the result banked: the AC 2 pattern was anchored on `.vulnerable_window`
  (a leading dot), so it saw every read through a handle but NOT an unqualified self-read inside
  `player_state.gd`, where the field is named bare — exactly the shape M-J used. A second pattern
  banning `vulnerable_window.(is_running|remaining_ticks|to_snapshot)` outright now closes it, and
  M-J was re-run: the AC 2 guard falls too.
- **Provability honesty.** Every guard in the table above is proven in the falling direction. NOT
  claimed mutation-proven in the FIRING sense: nothing new — this story adds no `Invariant.check`.
  AC 10's degrade is deliberately guard-free, and its correctness is proven by M-O producing the
  out-of-bounds access the degrade prevents.
- **Fence Inventory, delivered as stated.** Ban dies for `reshuffle` / `vulnerab` /
  `draw_replacement`; `exhaust` survives with its vacuity assertion (`scanned > 0`) and a regex
  self-test in BOTH directions (the pattern must match `var _deck_exhausted := false` and must NOT
  match `if player.deck.is_empty():`). `CardEffect`, the Input Map guards (positive and negative)
  and F1/D3(a)/D3(b)/A2 all survive UNTOUCHED and green. The Deck/Hand method fence stays green via
  the no-new-method route and is re-proven (M-P). The invariant file's header enumeration now reads
  "F1, D3a, D3b, F2".
- **Live Smoke: NOT REQUIRED**, and R-D6 is NOT re-invoked — it remains 3-6's. No smoke was run and
  no smoke record is invented. `docs/playtest-log.md` is untouched.

## Dev Agent Record

### Agent Model Used

Claude Opus 5

### Debug Log References

### Completion Notes List

- Dev pass (2026-08-04, Claude Opus 5): implemented AC 1-16. See the Dev Pass Record above for the
  suite outcome, the seventh golden re-baseline and its four measured causes, the seventeen-row
  mutation table, and the four items reported rather than silently resolved (the Golden Prediction's
  C2 caption, the two pre-existing `E1_BALANCE_FIELDS` omissions, AC 10's stricter-than-stated
  reachability, and the blind spot found in this story's own AC 2 guard).
- No AC was deviated from or left blocked. AC 16's stop-and-ask escape hatch was NOT triggered: the
  shared helper is one line and contorts nothing.
- Nothing is committed, staged or pushed by this pass.

### File List

**New — tests** (2 new `.gd` files; `.uid` siblings owed from the editor scan at chain time)
- `test/state/test_draw_delay_and_reshuffle.gd`
- `test/integration/test_deck_reshuffle.gd`

**Modified — source**
- `src/state/resources/balance_config.gd` (`draw_replacement_delay_seconds`,
  `reshuffle_vulnerable_window_seconds`)
- `src/state/timing/balance_ticks.gd` (both derived tick counts)
- `src/state/player_state.gd` (`pending_draw`, `pending_draw_owed`, `vulnerable_window`; two new
  snapshot keys)
- `src/state/match_state.gd` (`reshuffle_vulnerable_window_opened`; step-2 window ticks; step-6
  delivery, lazy reshuffle and the ONE `_shuffle_deck` helper; the cast now owes instead of draws;
  the deal seat kills a pending draw)
- `src/systems/event_bus.gd` (the third bus signal)
- `src/main/match_runner.gd` (the relay — no new `connect_*` seam)

**Modified — data**
- `data/balance/balance_config.tres` (authored `1.0` and `1.5`)

**Modified — tests**
- `test/state/test_determinism.gd` (fixture delay, re-baseline record, four rewritten count
  assertions, AC 11's fourth term)
- `test/state/test_deck_and_hand.gd` (surface fence narrowed + renamed, bus pin updated + renamed,
  AC 2 negative guard, AC 7 early-stop scan)
- `test/state/test_architecture_invariants.gd` (AC 16's F2 scan; header enumeration)
- `test/state/test_data_resources.gd` (two new fields, two PRE-EXISTING omissions repaired, AC 13's
  reflective guard)
- `test/state/test_balance_authoring.gd` (the bespoke `> 0.0` bounds)
- `test/state/test_card_play.gd` (AC 11's fourth term; the instant-refill test re-justified as the
  zero-delay degrade)

**`project.godot`** — UNCHANGED, verified by SHA256 at the start and end of the pass.

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-08-04 | 0.1 | File authored at the 3-5 readiness gate, splitting `E3.S5` into `3-5a` (THE TRIGGER) and `3-5b` (WHAT THE TRIGGER MAKES REACHABLE), and carrying the four items 3-3's gate ruled move to 3-5 with their trigger. Status backlog, HOLD pending this slot's own readiness gate. | Claude Sonnet 5 |
| 2026-08-04 | 0.3 | DEV PASS (implementation only — nothing committed, staged or pushed). All sixteen ACs implemented, none deviated from, none blocked. Two authored `BalanceConfig` durations with derived tick counterparts and bespoke `> 0.0` bounds; a pending-draw `TimingWindow` plus owed COUNTER on `PlayerState`, ticked at step 2 and delivered at the END of step 6 (after the cast dispatch, so a zero derived delay degrades exactly to 3-5a's instant refill); exactly two new snapshot keys with a key-set pin; a LAZY reshuffle inside the one existing step-6 RNG seat with no new `Deck`/`Hand` method; the vulnerable window and its owner-slot event relayed onto `EventBus` (two-signal pin DELIBERATELY updated to three, runner still at seven `connect_*` seams); death drops the DELIVERY and never the window; the frozen-tick, debug-reset, both-empty and four-term-conservation contracts; a required headless integration proof driven against the AUTHORED config; a REFLECTIVE `BalanceConfig` completeness guard; the fence inventory delivered as stated; both windows surviving a mid-match `apply_balance`; and F2 MACHINE-CHECKED — AC 16's shared helper did not contort the code, so the stop-and-ask escape hatch was not triggered and `shuffle_with_rng(` stands at exactly two occurrences post-landing. Suite 287/1297 -> **310 tests / 1463 assertions / 0 failed**, integration 17 -> **18/18**. SEVENTH golden re-baseline, `c4b9f897` -> **`40eb5554`**, four causes each measured in both directions with an M0 zero point proving the fields and the inert mechanism hash-neutral. Seventeen mutation proofs, every new guard shown FALLING. FOUR items reported rather than silently resolved: the Golden Prediction's C2 caption names a snapshot key that ACs 2 and 4 forbid (the ACs were followed; the cause itself is real and measured); AC 13's new guard found `attack_stamina_cost` and `block_facing_arc_degrees` missing from `E1_BALANCE_FIELDS` since their own stories, both repaired; AC 10's both-empty case is measurably unreachable at ANY authored numbers, not merely balance-dependent; and a blind spot in this story's own AC 2 guard, found by mutation and closed. `project.godot` byte-identical throughout. Live Smoke correctly not run; R-D6 not re-invoked. | Claude Opus 5 |
| 2026-08-04 | 0.2 | Readiness-gate fix pass (NOT READY on first read -> fixed and promoted, same session; NINETEENTH logged readiness-gate session, all nineteen NOT READY on first reading and all nineteen resolved the same session). Eighteen rulings applied, `3-5b/R1`..`3-5b/R18`. The central premise was corrected: deck exhaustion is ALREADY REACHABLE in shipped 3-5a code, so this story REPLACES a silent floor rather than creating a mechanism (`3-5b/R1`); Story Statement and Scope note reframed. AC set replaced with sixteen verifiable claims about delivered software -- two AUTHORED balance fields with bespoke `> 0.0` bounds plus a negative guard that keeps open decision (b) open; a pending-draw timer plus owed counter ticked at step 2 and delivered at step 6; exactly two new snapshot keys; a LAZY reshuffle inside the one existing step-6 RNG seat with no new `Deck`/`Hand` method; the owner-only vulnerable window on the ownerless `EventBus` with its two-signal pin deliberately updated to three; death dropping the DELIVERY and never the window (1-9/R3 untouched); the frozen-tick, debug-reset, both-empty and four-term-conservation contracts; a required headless proof of exhaustion/reshuffle/both-empty; a REFLECTIVE `BalanceConfig` completeness guard; the fence inventory; in-flight survival across `apply_balance`; and a source scan pinning `shuffle_with_rng(` to exactly two sites, which makes F2 MACHINE-CHECKED for the first time (`3-5b/R17` -- the gate reported the second-RNG-seat gap and declined to invent an invariant to close it; the operator ruled the guard ships, and 3-5b is F2's forcing point because it is the first story that can introduce a second seat). `3-5b/R18` then CORRECTED R17's original form, which was self-contradictory: the two-occurrence count was measured pre-implementation, and AC 5's reshuffle is a second shuffle occasion, so a guard pinned at two would have failed on its own story. The fix keeps the count and removes the second CALL SITE -- both occasions route through ONE private `MatchState` shuffle helper -- with an explicit STOP-AND-ASK escape hatch if that helper contorts the code, since a second seeded seat is a design change. The two previously unfailable ACs (a pending draw's snapshot visibility, and the vulnerable window's price) were instructions to this file's author, not claims about software, and are now RULED and rewritten as claims. Fence inventory table added with a per-guard verdict. Golden Prediction replaced (was "TBD at this story's own readiness gate"): baseline re-derived `c4b9f897...`, MOVES, one re-baseline, four separately named causes each measured in both directions, and the golden sequence explicitly NOT widened to reach exhaustion. Live Smoke kept NOT REQUIRED with the reason CORRECTED to 3-3's (no player-facing surface, evidenced by content), R-D6 confirmed not re-invoked here, and the S1/S2 asterisk carried forward to 3-6 and the E4/E5 balance pass rather than dropped. Dev Notes APPENDED to (all six original bullets retained verbatim) with the reframe, the decision-(b) landing, the step-2/step-6 split rationale, AC 7's honest near-vacuity, the closure of `3-5/R8`, the three existing assertions the nonzero fixture delay breaks, the architecture-amendment queue's seventh member firing, and the extended 3-0c obligation, plus F2's review-enforced-until-now status and the FALLING direction of AC 16's mutation proof. Tasks/Subtasks added, mirroring the sixteen ACs. Project Structure Notes corrected to `src/systems/event_bus.gd` (`src/main/event_bus.gd` does not exist). Status backlog -> ready-for-dev; `sprint-status.yaml` updated alongside. | Claude Opus 5 |
