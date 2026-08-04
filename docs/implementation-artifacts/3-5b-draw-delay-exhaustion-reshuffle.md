# Story 3.5b: Draw-replacement delay, deck exhaustion, and the reshuffle vulnerable window

Status: backlog

> **Scope note.** This file is newly authored at the 3-5 readiness gate (2026-08-04, decision-log
> Session 2026-08-04 -- Story 3-5 readiness gate). It carries the half of the original `E3.S5`
> (`stories-manual-e3.md`) that is WHAT THE TRIGGER MAKES REACHABLE, split out from 3-5a, which
> delivers THE TRIGGER (a working cast path). This file also carries the four items 3-3's own gate
> ruled must "move to 3-5 together with their trigger -- not split from it" (decision-log Session
> 2026-08-03 -- Story 3-3 readiness gate, finding (v)): discard, reshuffle-on-exhaustion, the
> vulnerable window, and the draw-on-play delay. That ruling is HONOURED here, not reopened: its
> purpose was that no mechanism ships before its trigger exists. 3-5a delivers the trigger; this
> file lands after it exists, as its own story rather than a 3-5a task.
>
> **Status is HOLD pending this story's OWN readiness gate** -- matching the convention already used
> for every other E3 story: the machine field stays `backlog` in `sprint-status.yaml`, and this prose
> note carries the HOLD. Do not promote to `ready-for-dev` until that gate runs.
>
> **Reachability, measured, not assumed.** With the shipped fixture shape (`deck_size` 20,
> `hand_size` 4), deck exhaustion needs SIXTEEN successful Mode ① casts inside one round before the
> pile runs dry. That is reachable in principle -- a headless test can drive sixteen casts in a
> fixed-`delta` loop -- but is not a realistic live-smoke event. See Live Smoke below.

## Story

As a player,
I want a played card's replacement to arrive after an authored delay, and my deck to reshuffle from
the discard pile with a visible vulnerable window when it runs out,
so that draw timing and deck exhaustion carry real weight once cards are actually being cast, instead
of both being silently unreachable as they were in 3-3.

## Acceptance Criteria

1. `draw_replacement_delay_seconds` lands on `BalanceConfig`, in `E1_BALANCE_FIELDS`. The audit bound
   is `>= 0`, NOT `> 0` the way `deck_size`/`hand_size` are bound: the manual states zero means
   instant and instant-vs-delayed is an open feel question (`stories-manual-e3.md` E3.S3 item 3), and
   the existing `E1_BALANCE_FIELDS` loop in `test/state/test_data_resources.gd` already asserts every
   listed field `>= 0.0` -- so no bespoke audit is added for this field, unlike the bespoke `> 0`
   bounds 3-3 added for `deck_size`/`hand_size` in `test_balance_authoring.gd`. Converted once at load
   to a tick-domain field on `BalanceTicks` (the `stamina_regen_per_tick`/`mana_regen_per_tick`
   precedent), with the countdown living in exactly ONE seat.
2. Whether a pending replacement draw is snapshot-visible is an OPEN question this story decides, not
   an implementation detail left to whoever writes the code. Record both standing precedents honestly
   before deciding: `_deck_deal_pending` (3-3) is EXCLUDED from the hashed snapshot but never crosses
   a tick boundary -- it is armed and consumed within the same `advance()` whenever balance is
   present (3-3 Dev Notes). `StaminaPool`'s `_regen_delay` window, by contrast, DOES cross tick
   boundaries and IS snapshotted (`StaminaPool.to_snapshot()`: `"regen_delay": _regen_delay.to_snapshot()`).
   A pending replacement draw behaves like the latter, not the former -- it is armed on the cast tick
   and may still be running many ticks later -- so this AC's ruling must say explicitly which
   precedent it follows and why, not silently default to one.
3. Deck exhaustion triggers a reshuffle from the discard pile, landing in the SAME single step-6 RNG
   seat that shuffle and deal already use (`MatchState._deal_pending_decks`'s seat, or its 3-5a-era
   successor) -- NOT a second seat. "The seeded RNG is consumed only inside `advance()`" (F2) stays
   provable by inspection, the same discipline 3-3's AC7 established for the initial shuffle.
4. The reshuffle vulnerable window and its ownerless `EventBus` event ship, on the
   `round_started`/`round_ended` precedent (decision-log E3-RG/R3), payload carrying which player is
   vulnerable. This is NOT an eighth observation seam -- E3-RG/R3 is explicit that this rides the
   match-wide bus that already carries `round_started`/`round_ended`, a different mechanism from the
   frozen seven-seam per-slot observation family (2-6/R7, locked).
5. `reshuffle_vulnerable_window_seconds` is UNAUTHORED as of this scope note, and stays that way
   unless this story's own dev pass rules the still-OPEN question it would price: what the vulnerable
   window costs mechanically (decision-log, Session 2026-07-22, open decision (b); reaffirmed at the
   3-3 gate as "not the binding constraint here; the missing trigger was"). This story must do ONE of
   two things, stated explicitly rather than left ambiguous: rule decision (b) and author the field
   against that ruling, OR define a placeholder discipline (e.g. the window exists and is visible but
   costs nothing yet) that does NOT price the open decision by construction. Inventing a value here
   without either would silently close decision (b) as a side effect.

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

### Project Structure Notes

- New `BalanceConfig`/`BalanceTicks` fields alongside the existing `*_seconds`/`*_ticks` pairs
  (`src/state/resources/balance_config.gd`, `src/state/timing/balance_ticks.gd`); the reshuffle and
  delay countdowns seat inside `MatchState.advance()` step 6, beside `_deal_pending_decks()`; the
  `EventBus` signal follows `round_started`/`round_ended` (`src/main/event_bus.gd`), relayed by
  `match_runner.gd` after the queued drain (D5).

### Project Context Rules

- **Seeded RNG consumed only inside `advance()`; no bare global RNG in `src/state/`.** [Source:
  docs/project-context.md#Controllers & state-layer determinism, A2]
- **`EventBus` carries a small fixed typed set only, relayed by the runner after the drain.** [Source:
  docs/game-architecture.md#Standard Patterns & Consistency Rules; #D5]

### References

- [Source: stories-manual-e3.md#E3.S3 items 3-4]
- [Source: gdd.md#A Card System — Deck & hand]
- [Source: decision-log.md Session 2026-07-22 — open decision (b)]
- [Source: decision-log.md Session 2026-07-31 — E3 revisit gate (outcome), E3-RG/R3]
- [Source: decision-log.md Session 2026-08-03 — Story 3-3 readiness gate]
- [Source: decision-log.md Session 2026-08-04 — Story 3-5 readiness gate]

## Golden Prediction

**MANDATORY, TBD at this story's own readiness gate.** By the permanent rule established at the 3-3
gate ("a story's Golden Prediction baseline is re-derived from the `GOLDEN` constant in
`test_determinism.gd` at gate time, and never copied forward from whatever the story text already
says"), no baseline hash is recorded here -- one will be stale the moment 3-5a's own re-baseline
lands. Expected shape, named without a number: a snapshot-shape cause if AC2 rules the pending-draw
flag snapshot-visible; a discard-count-via-reshuffle cause, conditional on a fixture actually driving
the deck to exhaustion (sixteen casts, per the reachability note above); and a vulnerable-window-flag
cause if AC2/AC4 make the window state itself hash-visible. Each must be isolated and measured
separately, exactly as every prior multi-cause re-baseline in this project has been (1-5, 1-8, 1-9,
3-3, 3-4).

## Live Smoke

**NOT REQUIRED**, with the measured reason stated at the top of this file: reaching deck exhaustion
needs sixteen successful casts inside one round against the shipped fixture (`deck_size` 20,
`hand_size` 4), which is headless-provable (a fixed-`delta` test loop can drive sixteen casts in
milliseconds) but is not a realistic two-human live event -- a live smoke session would need to
manufacture an artificial, unrepresentative grind to ever observe a reshuffle at all. The
draw-replacement delay IS observable live (it fires on every single cast, not just the sixteenth),
but this story's smoke obligation is scoped to what is NEW and mechanically load-bearing here, and
the delay alone does not carry the same live-observation weight as the reshuffle/vulnerable-window
half. If this story's own gate finds the delay warrants its own smoke pass independent of exhaustion,
that gate records the change; this scope note does not pre-empt it.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
