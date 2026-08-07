# Story 4.0: Hand slot stability

Status: backlog

> **Scope note.** Newly authored at the E3 close-out's own ruling (2026-08-06, decision-log Session
> 2026-08-06 -- E3 close-out), on the just-in-time authoring precedent already used for
> `IntentRecorder` (`E3-P/R3`). The substance comes from a live-smoke finding recorded at the 3-6
> close-out (2026-08-06, decision-log Session 2026-08-06 -- Story 3-6 close-out): playing a card
> slides the remaining cards left and appends the replacement at the end, so `card_slot` 1 changes
> meaning under the player's fingers after every cast. The operator wants the replacement to refill
> the VACATED slot instead. That entry is the analysis; this story is the build. Where this file's
> prose disagrees with either decision-log entry, the log wins.
>
> **Status is HOLD pending this story's OWN readiness gate** -- the same convention every other E3/E4
> substrate story has used. The machine field stays `backlog` in `sprint-status.yaml`; this note
> carries the HOLD. Do not promote to `ready-for-dev` until that gate runs -- this authoring pass
> does not run it (operator instruction, this session).
>
> **This story SUPERSEDES parts of `3-5b/R8`.** `3-5b/R8` ruled the snapshot gains exactly two keys,
> `pending_draw` and `pending_draw_owed`, the second "a plain int COUNT and nothing more" -- and ruled
> **no new rejection reason**, because a cast was not gated on a pending draw. Both stand only
> partially once a hole is addressable: `pending_draw_owed` as a bare int cannot say WHICH slot a
> draw is owed to, so its shape must change (AC 3); and "no new rejection reason" survives in LETTER
> -- `CastEvaluator.REASON_EMPTY_SLOT` is reused, not joined by a sibling constant (AC 2) -- but not
> in SCOPE, because a hole is now a persistently addressable, always-empty target rather than an
> index that structurally could not be reached before. The same guard fires on a materially different
> condition than it did in 3-5a/3-5b. **Naming this is the authoring pass's job; reconciling it
> against the shipped code is the readiness gate's**, per the operator's instruction this session.

## Story

As a player,
I want the card in the slot I cast to be the exact card its replacement refills -- not a rename of
whichever card happens to slide into that position -- so that a slot's identity under my fingers
survives a cast the way every other input binding on the controller does.

## Acceptance Criteria

1. **`Hand` gains an explicit empty-slot representation, distinct from "the hand is shorter."** The
   container is fixed-width at `hand_size`: every one of its `hand_size` positions holds either a
   card id or an explicit empty marker, never fewer positions than that. Casting the card in slot N
   changes only slot N -- every other slot's contents and index are byte-for-byte unchanged by the
   cast, immediately and for as long as slot N stays a hole.
2. **A cast against an empty slot rejects through the existing seam, not a new one.** Committing a
   cast whose `card_slot` currently names no card -- out of range OR a hole -- refuses through the
   shipped `HeroState.reject_action` / `action_rejected` seam with `CastEvaluator.REASON_EMPTY_SLOT`,
   the same constant and the same per-slot observation seam 3-5a already ships. The out-of-range
   bound check stays; a hole is a second path to the same reason, not a new one.
3. **The owed replacement fills the vacated slot, not the end.** `PlayerState.pending_draw_owed`
   carries WHICH slot (or slots) a draw is owed to, not only a count. `MatchState`'s delivery seat
   (today `_deliver_pending_draw` / `_draw_one_replacement`) writes the drawn card into the owed
   slot's own index rather than appending. Two casts against two different slots each owe their own
   slot; neither can ever land in the other's.
4. **Deal and debug-reset fill every slot front to back and leave no stray holes.** `_deal_player`
   still empties and refills the whole hand each occasion; its post-fill state for every case the
   authored balance reaches (`hand_size <= deck_size`) is unchanged from today -- every slot holds a
   card, none holds a hole, immediately after a deal.
5. **The snapshot stays counts/indices-only.** No card identity crosses into `to_snapshot()` that
   was not already crossing (3-3 AC 5, 3-5a AC 6, 3-0c AC 11 all stand). `pending_draw_owed`'s new
   shape may grow or reshape the key it occupies, but carries slot indices or counts, never a
   `StringName` card id.
6. **Verified live: cast from a non-rightmost slot; the replacement lands in that same slot when it
   arrives; nothing else shifts.** Run it from at least two different starting slots (not only the
   leftmost) to rule out an off-by-one. Recorded in `docs/playtest-log.md` by the operator's own
   hand -- no agent writes that entry.

## Deferred

**Delivery ORDER across more than one simultaneously-owed slot -- not specified beyond preserving
3-5b's existing one-delivery-per-expiry cadence.** If two slots are owed at once and both come due on
the same tick, which fills first is an implementation choice (e.g. cast order) as long as every owed
slot is eventually filled and no delivery ever lands in a slot it wasn't owed to. Not P4-relevant at
the shipped delay values -- no home story, revisit only if a future balance pass makes simultaneous
holes common enough to be observable.

## Tasks / Subtasks

- [ ] Give `Hand` a fixed-width, hole-aware representation; `clear()` fills every position with the
      empty marker rather than leaving the array empty (AC: 1)
- [ ] Replace `Hand.remove_at()`'s shift-left removal with an in-place hole write; add an in-place
      fill method that writes a card into a specific index (AC: 1, 3)
- [ ] Wire the hole case into `MatchState._resolve_basic_cast`'s existing bound check so a hole slot
      takes `CastEvaluator.REASON_EMPTY_SLOT` the same way an out-of-range slot does (AC: 2)
- [ ] Change `PlayerState.pending_draw_owed`'s shape to carry the owed slot(s); update
      `_deliver_pending_draw` / `_draw_one_replacement` to write into the owed index (AC: 3)
- [ ] Confirm `_deal_player`'s fill-from-top loop still leaves every slot occupied post-deal against
      the authored `hand_size <= deck_size` bound (AC: 4)
- [ ] Update `to_snapshot()`'s `pending_draw_owed` key to the new shape; re-run the counts-only /
      no-card-identity guards (AC: 5)
- [ ] Live smoke: cast from a non-rightmost slot at least twice, from different starting slots;
      record the outcome in `docs/playtest-log.md` (AC: 6)

## Dev Notes

- **Current shape, read before touching it.** `Hand` (`src/state/hand.gd`) is a plain
  `Array[StringName]`; `remove_at(index)` calls `Array.remove_at`, which SHIFTS every later element
  left -- this is the literal mechanism of the bug. `add()` only appends. `MatchState._resolve_basic_cast`
  (`src/state/match_state.gd:839`) rejects `hand_slot < 0 or hand_slot >= player.hand.size()` with
  `CastEvaluator.REASON_EMPTY_SLOT` today -- that bound check is reachable ONLY because a cast slot
  is a shrinking array's index, never because a specific position is empty; under this story both
  reasons must reach the same branch. `PlayerState.pending_draw_owed` (`src/state/player_state.gd:65`)
  is a bare `int`; delivery (`_deliver_pending_draw`, `match_state.gd:892`) decrements it and calls
  `_draw_one_replacement`, which only ever appends (`player.hand.add(...)`, `match_state.gd:918`).
- **The open reconciliation this story does not pre-answer.** Today's single `TimingWindow` plus a
  scalar counter lets several casts stack (`3-5b/R8`'s "a cast is not gated on a pending draw") and
  delivers them one at a time in an order that was never tied to slot identity, because it didn't
  need to be -- the replacement always went to the end. Once a delivery must land in a SPECIFIC slot,
  a bare counter cannot carry more than one outstanding hole's address. Whether the shipped fix keeps
  one shared `TimingWindow` with an owed-slot queue, or moves to a per-slot window, is an
  implementation choice AC 3 requires be MADE, not a design call this story is pre-deciding here --
  the readiness gate is where it gets reconciled against 3-5b/R8's letter, per this file's header.
- **`CardCastCondition`, `CastDatabase`, mana spend, and discard are unaffected.** The cast's
  economic half (`refusal_reason`, `ManaPool.spend`, `discard.add`) is untouched by this story; only
  WHICH index the removed/added card lives at changes. [Source: src/state/economy/cast_evaluator.gd;
  src/state/match_state.gd:839-872]
- **HUD inherits this for free.** `hud_root.gd`'s card rendering (3-6) draws purely from
  `cards_changed`'s `hand_ids` payload in array order -- it has no slot-shift logic of its own to fix.
  3-6's `vacated_cleared` / `refill_rewrote` tests were proven against the OLD append model; they may
  need re-pointing at the new hole marker rather than "index past the shrunk length," but no new HUD
  code is expected. [Source: src/ui/hud/hud_root.gd; test/integration/test_card_hud.gd]

### Project Structure Notes

- `src/state/hand.gd`: fixed-width hole-aware container; `remove_at` becomes an in-place write, a new
  in-place fill method is added.
- `src/state/player_state.gd`: `pending_draw_owed`'s declared shape changes from `int`.
- `src/state/match_state.gd`: `_resolve_basic_cast`'s bound check gains the hole path;
  `_deliver_pending_draw` / `_draw_one_replacement` write into the owed slot instead of appending;
  `_deal_player`'s fill loop is reviewed against the new fixed-width container, not necessarily
  rewritten.
- `test/state/test_deck_and_hand.gd`, `test/state/test_card_play.gd`,
  `test/state/test_draw_delay_and_reshuffle.gd`: all touch `Hand`/`pending_draw_owed` directly and
  are the primary suites this story's dev pass will extend or reconcile.

### Project Context Rules

- **Rejections ride the shipped `action_rejected` seam; no new signal, no new seam.**
  [Source: decision-log.md 3-5a AC 7, restated at 3-5b/R8]
- **Counts/indices only ever cross into `to_snapshot()` -- never a card id.**
  [Source: decision-log.md 3-3 AC 5, 3-5a AC 6, 3-0c AC 11]

### References

- [Source: decision-log.md Session 2026-08-06 -- Story 3-6 close-out (the finding)]
- [Source: decision-log.md Session 2026-08-06 -- E3 close-out (the ruling: "the operator RULES it is
  done NOW, not deferred... 4-0-hand-slot-stability")]
- [Source: decision-log.md 3-5b/R8]
- [Source: src/state/hand.gd; src/state/player_state.gd; src/state/match_state.gd]

## Golden Prediction

**MOVES.** Two separately measured causes, each to be isolated the way every prior multi-cause
re-baseline in this project has been (1-5, 1-8, 1-9, 3-3, 3-4, 3-5a, 3-5b):

1. **Snapshot-shape cause.** `pending_draw_owed` changes shape (AC 3, AC 5) -- this alone moves the
   golden at an early tick, before any cast-order-dependent behaviour runs, the same way 3-5b's own
   two new keys each moved it by themselves.
2. **Behavioural cause.** Any fixture that issues a second cast against the SAME numeric `card_slot`
   before the first cast's replacement has landed used to resolve BOTH casts under the append model
   (the shift meant the same index named a different, still-live card by the second commit). Under
   slot stability that second commit now targets a hole and REJECTS (AC 2) instead of resolving --
   changing how much mana is spent, what enters the discard, and what is drawn from the deck in any
   fixture that exercises it. If no golden fixture currently drives that exact sequence, this cause
   is a non-mover in practice and the dev pass reports that measured result rather than assuming it.

No baseline hash is recorded here, per the standing rule (3-3 gate) that a Golden Prediction baseline
is re-derived from `test_determinism.gd`'s `GOLDEN` constant at gate time, never copied forward.

## Live Smoke

**REQUIRED.** The finding this story fixes came from a live smoke, not a headless test, and slot
identity surviving a cast is a claim about what the player's fingers experience -- it is judged the
same way. Cast from a slot that is not the rightmost; confirm the replacement lands in that exact
slot when it arrives, and that no other slot's contents or position moved. Repeat from a second,
different starting slot before calling it passed, to rule out an off-by-one hiding behind a single
lucky index. `R-D6`'s re-invocation status at the time this story reaches a dev pass is whatever the
decision-log records then -- not restated here to avoid going stale.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
