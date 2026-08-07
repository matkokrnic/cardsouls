---
baseline_commit: 7510b5a05a3bfa870128065ec08fb5f0a790a1c2
---

# Story 4.0: Hand slot stability

Status: review

> **Scope note.** Newly authored at the E3 close-out's own ruling (2026-08-06, decision-log Session
> 2026-08-06 -- E3 close-out), on the just-in-time authoring precedent already used for
> `IntentRecorder` (`E3-P/R3`). The substance comes from a live-smoke finding recorded at the 3-6
> close-out (2026-08-06, decision-log Session 2026-08-06 -- Story 3-6 close-out): playing a card
> slides the remaining cards left and appends the replacement at the end, so `card_slot` 1 changes
> meaning under the player's fingers after every cast. The operator wants the replacement to refill
> the VACATED slot instead. That entry is the analysis; this story is the build. Where this file's
> prose disagrees with either decision-log entry, the log wins.
>
> **The readiness gate RAN (2026-08-07, decision-log Session 2026-08-07 -- Story 4-0 readiness
> gate).** Verdict NOT READY on first reading, eight blocking findings and three notes, resolved the
> same session by `4-0/R1`-`4-0/R8` (two with operator extensions). This file is the post-gate text
> and the HOLD is DISCHARGED: status is `ready-for-dev` here and in `sprint-status.yaml`. Where this
> file disagrees with those rulings, the rulings win.

## What this story supersedes of `3-5b/R8`

The gate ruled `3-5b/R8` clause by clause (`4-0/R5`) rather than declaring the whole ruling
partially superseded. The table is the authority; the dev pass does not re-derive it.

| `3-5b/R8` clause | Verdict |
| --- | --- |
| The snapshot gains EXACTLY TWO new keys (`pending_draw`, `pending_draw_owed`) | **SURVIVES** as a key COUNT -- this story adds no third key |
| `pending_draw_owed` is "a plain int COUNT and nothing more" | **SUPERSEDED** by AC 4: it must carry slot addresses |
| One timer plus a debt; ONE card per expiry; the window restarts while the debt is above zero | **SURVIVES INTACT** -- and is load-bearing, see `4-0/R6` below |
| Both keys cross tick boundaries, which is why they are hashed | **SURVIVES** -- a shape change does not touch the rationale |
| "`hand_size` is permitted to reach 0" | **SURVIVES**, and only because `4-0/R1` binds the snapshot key to OCCUPANCY; it would be meaningless against a fixed width |
| "NO new rejection reason" (the constant itself) | **SURVIVES IN FULL** -- `CastEvaluator.REASON_EMPTY_SLOT` is reused, no sibling token ships (AC 3) |
| "a cast is not gated on a pending draw" | **SURVIVES NARROWED**: no cast is gated on the DEBT. A cast against the slot whose OWN replacement is in flight is now refused -- a behavioural supersession, not merely a re-scoping |
| "mana stays the only throttle" | **SUPERSEDED**. Mana remains the only ECONOMIC throttle; slot occupancy is now a second, structural, player-observable precondition |

**`4-0/R6` -- the delivery shape is FORCED, not free.** The Dev Notes of this file's pre-gate draft
called the choice between one shared `TimingWindow` with an owed-slot queue and a per-slot window an
open implementation choice. It is not: it was pre-decided at 3-5b. Two shipped constraints close it.
(a) `3-5b/R8`'s one-timer, one-delivery-per-expiry cadence, which this file's own Deferred section
preserves -- per-slot windows deliver simultaneously by construction. (b) `3-5b/R8`'s two-key
snapshot bound, which this story relaxes only for `pending_draw_owed`'s SHAPE; `hand_size` per-slot
windows would put N `TimingWindow` dictionaries into the hash and make the window count a hash cause
every time `hand_size` is retuned. **The dev pass ships ONE shared `TimingWindow` plus an owed-slot
queue.** What remains genuinely free: the queue's internal representation (a FIFO `Array[int]`
versus a per-slot flag array) and the tie-break order, and the tie-break is already Deferred below.

## Story

As a player,
I want the card in the slot I cast to be the exact card its replacement refills -- not a rename of
whichever card happens to slide into that position -- so that a slot's identity under my fingers
survives a cast the way every other input binding on the controller does.

## Acceptance Criteria

1. **`Hand` gains an explicit empty-slot representation, distinct from "the hand is shorter."** The
   container is fixed-width: every one of its positions holds either a card id or an explicit empty
   marker, never fewer positions than its width. Casting the card in slot N changes only slot N --
   every other slot's contents and index are byte-for-byte unchanged by the cast, immediately and
   for as long as slot N stays a hole. **The WIDTH is established at the DEAL SEAT, never by `Hand`
   itself** (`4-0/R2`): `Hand` never learns of `BalanceConfig`, never holds a config reference and
   never names `hand_size`; the seat passes the width in, reading `balance.hand_size` INLINE at the
   moment of use per CONSTRAINT C, exactly as `_deal_player` reads it today (`match_state.gd:735-737,
   761`). A `Hand` that has never been dealt to has width 0, which is what keeps
   `test_economy_and_hero.gd:89`'s pre-deal `snap["hand_size"] == 0` true without a special case.
2. **`Hand.size()` means WIDTH; a new `occupied_count()` carries what `size()` means today**
   (`4-0/R1`). The two readings are irreconcilable under one method and the gate enumerated nine
   consumers that split across them, so the split is explicit rather than implied. **The snapshot key
   `hand_size` binds to `occupied_count()`**, which preserves its meaning unchanged, keeps 3-5b's
   four-term conservation identity (`occupied + owed == hand_size`) true, and keeps
   `3-5b/R8`'s "`hand_size` is permitted to reach 0" meaningful. `Hand.is_empty()` likewise means "no
   OCCUPIED slots" -- the backing array is never empty once dealt, so a bare `_cards.is_empty()`
   would be permanently false and silently wrong.
3. **A cast against an empty slot rejects through the existing seam, not a new one.** Committing a
   cast whose `card_slot` currently names no card -- out of range OR a hole -- refuses through the
   shipped `HeroState.reject_action` / `action_rejected` seam with `CastEvaluator.REASON_EMPTY_SLOT`,
   the same constant and the same per-slot observation seam 3-5a already ships. The bound check stays
   and is a WIDTH bound; the hole test is a SECOND path to the same reason, not a new one and not a
   replacement for the first.
4. **The owed replacement fills the vacated slot, not the end.** `PlayerState.pending_draw_owed`
   carries WHICH slot (or slots) a draw is owed to, not only a count, behind ONE shared
   `TimingWindow` per `4-0/R6`. `MatchState`'s delivery seat (today `_deliver_pending_draw` /
   `_draw_one_replacement`) writes the drawn card into the owed slot's own index rather than
   appending. Two casts against two different slots each owe their own slot; neither can ever land in
   the other's.
5. **Deal and debug-reset fill every slot front to back and leave no stray holes.** `_deal_player`
   still empties and refills the whole hand each occasion; its post-fill state for every case the
   authored balance reaches (`hand_size <= deck_size`) is unchanged from today -- every slot holds a
   card, none holds a hole, immediately after a deal. **Its fill loop IS REWRITTEN, not merely
   reviewed** (`4-0/R4`): `match_state.gd:761-764` fills via `player.hand.add(...)`, and against a
   `clear()` that pre-fills the width that would append PAST the width and produce a
   `2 * hand_size` array. An indexed in-place write is mandatory.
6. **The snapshot stays counts/indices-only.** No card identity crosses into `to_snapshot()` that
   was not already crossing (3-3 AC 5, 3-5a AC 6, 3-0c AC 11 all stand). `pending_draw_owed`'s new
   shape may grow or reshape the key it occupies, but carries slot indices or counts, never a
   `StringName` card id. The key COUNT does not grow (`3-5b/R8`, surviving clause).
7. **The empty marker is the empty `StringName` (`&""`), and a hole is never rendered as a card nor
   as an affordable one** (`4-0/R3`). Ruled explicitly so `hud_root.gd:159` renders a blank caption
   with no HUD change: that line is
   `_own_card_labels[i].text = str(hand_ids[i]) if i < hand_ids.size() else ""`, and against a
   fixed-width payload its `else ""` branch is DEAD -- the caption becomes `str(marker)`, so any
   marker but the empty `StringName` renders visible garbage in the vacated slot, which is exactly
   the defect 3-6 AC 1 shipped to prevent ("a caption left behind is a card the player can see and
   cannot cast"). Three parts, each with its shipped status named honestly:
   - **The marker/card-id collision is impossible BY CONSTRUCTION, and the guard ALREADY SHIPS.**
     `test/state/test_card_authoring.gd:66` `test_every_id_is_non_empty_and_unique` already asserts
     `card.id != &""` over every authored card. That assertion is hereby RE-POINTED as load-bearing
     for this story and gains a comment saying so, so a future pass cannot weaken it without meeting
     this AC. (The gate's ratification named `test_balance_authoring.gd`; by content that file loads
     only the `BalanceConfig` and cannot reach `data/cards/`, so the audit stays where the authored
     cards actually are. Recorded as a correction, not a scope change.)
   - **State side, shipped and required:** the hole rejects at the guard BEFORE the cost map is ever
     consulted -- `match_state.gd:840` returns at :842, and `_card_costs.get(id)` is :844. A hole
     therefore cannot reach the cost lookup at all. The dev pass keeps that ordering and pins it.
   - **HUD side, a FORWARD constraint:** there is no cost, affordability or greying rendering in
     `src/ui/` today (verified by content at the gate; `_card_costs` is `MatchState`-private and no
     seam relays it). When such rendering ships, the marker is uncastable by construction and is
     never looked up in the cost map. This AC binds that future work; it requires no HUD code now.
   - `test/integration/test_card_hud.gd:104-112`'s `vacated_cleared` / `refill_rewrote` proof is
     RE-POINTED to a marker-bearing FULL-WIDTH payload. Today it hand-builds a THREE-element array
     and asserts `after[3] == ""`; under fixed width no shipped seat can ever emit a short array, so
     left alone that fixture would keep passing while testing nothing the code can produce.
8. **Slot stability extends to EXHAUSTION: the permanent hole is the RULED design, not an
   observation** (`4-0/R8`). When a player's deck and discard are both empty, 3-5b AC 10's degrade
   consumes the owed slot's debt and draws nothing (`match_state.gd:913-916`). Under this story the
   consequence is stated as intent: **the debt is consumed, the hole PERSISTS, and that slot rejects
   through AC 3 for the rest of the round.** The same cards are lost as today; what changes is that
   the loss is now addressed to a specific, permanently-refusing slot rather than to a shorter hand.
   The dev pass pins this with its own test.
9. **Verified live: cast from a non-rightmost slot; the replacement lands in that same slot when it
   arrives; nothing else shifts.** Run it from at least two different starting slots (not only the
   leftmost) to rule out an off-by-one. Recorded in `docs/playtest-log.md` by the operator's own
   hand -- no agent writes that entry.

## Deferred

**Delivery ORDER across more than one simultaneously-owed slot -- not specified beyond preserving
3-5b's existing one-delivery-per-expiry cadence.** If two slots are owed at once and both come due on
the same tick, which fills first is an implementation choice (e.g. cast order) as long as **no
delivery ever lands in a slot it wasn't owed to.** Not P4-relevant at the shipped delay values -- no
home story, revisit only if a future balance pass makes simultaneous holes common enough to be
observable.

> Corrected at the gate (note N3): the pre-gate text said "every owed slot is eventually filled."
> That is FALSE against 3-5b AC 10's both-empty degrade, which consumes the debt and draws nothing
> (proven at `test_draw_delay_and_reshuffle.gd:409`). AC 8 now rules that outcome; the only clause
> that survives unconditionally is the no-misdelivery half above.

## Tasks / Subtasks

- [x] Give `Hand` a fixed-width, hole-aware representation. The width arrives FROM THE CALLER --
      `clear(width)` or an explicit resize -- so `Hand` never names `hand_size` and never sees a
      `BalanceConfig`; a never-dealt `Hand` has width 0 (AC: 1)
- [x] Split the length surface: `size()` returns the WIDTH, a new `occupied_count()` returns what
      `size()` means today, `is_empty()` means "no occupied slots" (AC: 2)
- [x] Replace `Hand.remove_at()`'s shift-left removal with an in-place hole write; add an in-place
      fill method that writes a card into a specific index (AC: 1, 4)
- [x] Re-point `hand.gd:62`'s `Invariant.check(index >= 0 and index < _cards.size())` to OCCUPANCY.
      Under fixed width every index is in range, so left alone that invariant goes silently VACUOUS
      -- it exists to catch a bypassed step-6 guard and must keep catching one (AC: 1, 3)
- [x] Wire the hole case into `MatchState._resolve_basic_cast`'s existing bound check so a hole slot
      takes `CastEvaluator.REASON_EMPTY_SLOT` the same way an out-of-range slot does; the bound check
      becomes a WIDTH bound and the hole test joins it (AC: 3)
- [x] Change `PlayerState.pending_draw_owed`'s shape to carry the owed slot(s) behind ONE shared
      `TimingWindow`; update `_deliver_pending_draw` / `_draw_one_replacement` to write into the owed
      index (AC: 4, and `4-0/R6` -- the shared-window shape is forced, not chosen)
- [x] REWRITE `_deal_player`'s fill loop (`match_state.gd:761-764`) from `hand.add()` to an indexed
      in-place write, and prove every slot occupied post-deal against the authored
      `hand_size <= deck_size` bound (AC: 5)
- [x] Update `to_snapshot()`'s `pending_draw_owed` key to the new shape and bind `"hand_size"` to
      `occupied_count()`; re-run the counts-only / no-card-identity guards (AC: 2, 6)
- [x] Add the comment re-pointing `test_card_authoring.gd:66`'s `card.id != &""` assertion as
      load-bearing for the marker choice; pin the cost-lookup ordering at
      `match_state.gd:840-844` (AC: 7)
- [x] Re-point `test_card_hud.gd`'s `vacated_cleared` / `refill_rewrote` to a marker-bearing
      FULL-WIDTH payload (AC: 7)
- [x] Pin the exhaustion outcome: both piles empty, debt consumed, hole persists, that slot rejects
      for the rest of the round (AC: 8)
- [x] Reconcile every test in the inventory below -- they are named individually because the gate
      found them by content, not so the dev pass can re-derive them (AC: 1, 2, 3, 4)
- [ ] Live smoke: cast from a non-rightmost slot at least twice, from different starting slots;
      record the outcome in `docs/playtest-log.md` (AC: 9)

### Review Findings

**Review layers: Blind Hunter (complete), Acceptance Auditor (complete, no AC violations found),
Edge Case Hunter (STALLED at 600s, same failure mode as 3-6 -- treated as failed, not run by
hand as a full walkthrough beyond what the three targeted checks below cover).**

**Targeted checks (run in the main session against the tree, not delegated):**
- Mutation survivors X6 (delivery-to-first-hole) and X8 (`Hand.EMPTY` value change) RE-PROVEN
  FALLING against a fresh mutation, backed up outside the repo to session scratchpad with SHA256
  before mutating and restored by copying the backup back with the checksum re-verified
  (`git checkout --` never used). Both guards hold.
- Width-vs-occupancy binding audited at every re-pointed site against the story's nine-consumer
  table, plus every additional `hand.size()`/`occupied_count()` call site the diff touches
  (`test_deck_and_hand.gd`, `test_deck_injection.gd`, `test_deck_reshuffle.gd`, `test_determinism.gd`,
  `test_discard_pile.gd`, `test_draw_delay_and_reshuffle.gd`, `test_card_play.gd`,
  `test_card_observation.gd`). No mismatched binding found.
- AC 7's cost-ordering pin (`test_the_empty_slot_guard_precedes_the_cost_lookup`, a source-scan
  test) and its behavioural twin (`test_a_cast_against_the_hole_its_own_replacement_is_owed_to_refuses`,
  asserting no mana spent) are non-vacuous: swapping the guard/lookup order in
  `match_state.gd::_resolve_basic_cast` fails the scan test; removing the guard fails the mana
  assertion. AC 8's exhaustion pins (headless
  `test_at_exhaustion_the_hole_persists_and_that_slot_refuses_for_the_rest_of_the_round`;
  integration `_check_both_empty_degrade`) are non-vacuous: either an invented card on the
  both-empty path, or a bypassed hole guard letting a later cast succeed against slot 2, breaks
  each.

- [x] [Review][Patch] `PlayerState.to_snapshot()`'s `pending_draw_owed` key aliases the live
      `Array[int]` instead of returning a copy [src/state/player_state.gd:185] -- every sibling
      container (`Hand.to_array()`, `Deck.to_array()`) in this same codebase returns a duplicate
      specifically so a held snapshot cannot silently mutate later; this key does not, and a caller
      holding an earlier `to_snapshot()` dict will see `pending_draw_owed` change under it as later
      `append()`/`pop_front()` calls run. No shipped test currently captures a `before` snapshot and
      re-reads it after further advance() calls, so nothing fails today, but the fix
      (`pending_draw_owed.duplicate()`) is a one-line, unambiguous change consistent with the
      project's own established discipline. FIXED -- `.duplicate()` added; golden confirmed
      UNMOVED at `312522d8...fb3c` (a copy of the same values is byte-identical for hashing).
- [x] [Review][Patch] `_draw_one_replacement(player: PlayerState, slot: int, owed_slot: int)`
      carries two differently-scoped concepts both named "slot" [src/state/match_state.gd:972],
      distinguished only by a prefix with no type-level distinction -- low risk, but a future edit
      could pass the wrong one. FIXED -- `owed_slot` renamed to `hand_slot`, matching
      `_resolve_basic_cast`'s existing convention for a hand index; `slot` (the board slot) is
      untouched and matches every sibling function in the file.
- [x] [Review][Defer] AC 8's permanent hole is visually indistinguishable from a slot mid-flight
      awaiting delivery -- both render the same blank caption, and nothing in this diff or its
      tests distinguishes "temporarily empty" from "dead for the round" to the player
      [src/ui/hud/hud_root.gd] -- deferred, the story's own AC 7 forward constraint already scopes
      HUD affordability/greying rendering out of this pass, and AC 9's outstanding live smoke is
      where this would first become player-visible.

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
  All six citations were verified by content at the readiness gate and hold.
- **The delivery-shape reconciliation is CLOSED, not open.** The pre-gate draft left the shared
  window versus per-slot window choice to the dev pass. `4-0/R6` (above) rules it forced by
  `3-5b/R8`'s surviving one-timer cadence and two-key snapshot bound. Do not re-open it; the free
  part is the queue's representation and the tie-break order only.
- **The nine consumers of the hand's length, enumerated by content at the gate.** AC 2's split is
  what each one binds to. This table is the reconciliation list, not background reading.

  | Consumer | Binds to |
  | --- | --- |
  | `player_state.gd:135` `"hand_size": hand.size()` (hashed) | `occupied_count()` |
  | `player_state.gd:121` `cards_changed` payload `hand.to_array()` | WIDTH -- fixed-length, marker at the hole |
  | `hud_root.gd:159` `i < hand_ids.size()` | branch goes DEAD; the marker value decides the caption (AC 7) |
  | `match_state.gd:840` `hand_slot >= player.hand.size()` | WIDTH bound, plus a separate hole test (AC 3) |
  | `match_state.gd:761` `for _slot in balance.hand_size` | unchanged -- reads `balance`, not `hand` |
  | `hand.gd:62` `Invariant.check(index < _cards.size())` | occupancy, else vacuous |
  | `hand.gd:37` `is_empty()` | "no occupied slots" |
  | 3-5b's four-term conservation identity (four sites) | `occupied_count()`, else all four invert |
  | `test_balance_authoring.gd:148` `hand_size <= 4` (`3-6/R8`) | unchanged, and MORE load-bearing: a width-5 hand emits a 5-element payload into a 4-label row |

- **Every test that pins the OLD shrink semantics, found by content at the gate.** The `_cast()`
  helper at `test_draw_delay_and_reshuffle.gd:536-541` always casts slot 0 and its own comment states
  the premise this story deletes: "always slot 0, because the hand shrinks under it and slot 0 is the
  one index guaranteed to exist while the hand is non-empty." Two fixtures loop it `HAND_SIZE` times
  with no delivery between, so under AC 3 every cast after the first REJECTS and they collapse to a
  single cast. **The multi-cast helper must cast a DIFFERENT slot per cast.**

  | Site | What breaks |
  | --- | --- |
  | `test_draw_delay_and_reshuffle.gd:96` `test_four_casts_in_flight_deliver_four_cards_one_per_expiry` | slot-0 repeat; four assertions fail |
  | `test_draw_delay_and_reshuffle.gd:409` `test_conservation_holds_across_the_both_empty_degrade` | same slot-0 repeat; also the AC 8 subject |
  | `test_draw_delay_and_reshuffle.gd:118` `test_a_cast_is_not_gated_on_a_pending_draw` | asserts ZERO rejections on a slot-0 double cast; RE-POINT to two DIFFERENT slots, preserving the rule it was written for (the DEBT gates nothing) |
  | `test_draw_delay_and_reshuffle.gd:100, 422` | "hand_size is PERMITTED to reach 0" -- `hand.size() == 0` becomes `occupied_count() == 0` |
  | `test_draw_delay_and_reshuffle.gd:59, 67, 70, 288, 311, 375-378` | `HAND_SIZE - 1` shrink assertions |
  | `test_draw_delay_and_reshuffle.gd:564` `_assert_conserved` | the four-term identity |
  | `test_card_play.gd:87` | the four-term identity |
  | `test_determinism.gd:731, 780, 801` | shrink pins and the identity, INSIDE the hashing fixture |
  | `test_deck_reshuffle.gd:201-208, 230` | integration degrade + conservation |
  | `test_card_observation.gd:74` | announced payload length `HAND_SIZE - 1` |
  | `test_discard_pile.gd:55-73` | `remove_at` shrink pins: "the hand shrank by exactly one", `remove_at(hand.size() - 1)` |
  | `test_deck_and_hand.gd:36-38` | `hand.size() == 0` after `clear()` |
  | `test_card_hud.gd:104-112` | goes VACUOUS (AC 7) |

- **`CardCastCondition`, `CastDatabase`, mana spend, and discard are unaffected.** The cast's
  economic half (`refusal_reason`, `ManaPool.spend`, `discard.add`) is untouched by this story; only
  WHICH index the removed/added card lives at changes. [Source: src/state/economy/cast_evaluator.gd;
  src/state/match_state.gd:839-872]
- **HUD: no new HUD CODE, but the claim needed AC 7 to become true.** `hud_root.gd`'s card rendering
  (3-6) draws purely from `cards_changed`'s `hand_ids` payload in array order and has no slot-shift
  logic of its own to fix. The pre-gate draft's "inherits this for free" was true only by accident:
  it holds if and only if the marker is `&""` (AC 7), and the 3-6 fixtures do not merely "need
  re-pointing" -- one of them goes vacuous. [Source: src/ui/hud/hud_root.gd;
  test/integration/test_card_hud.gd]

### Project Structure Notes

- `src/state/hand.gd`: fixed-width hole-aware container, width supplied by the caller; `remove_at`
  becomes an in-place write, an in-place fill method is added, `size()`/`occupied_count()` split,
  the `Invariant.check` at :62 re-pointed to occupancy.
- `src/state/player_state.gd`: `pending_draw_owed`'s declared shape changes from `int`;
  `to_snapshot()`'s `"hand_size"` binds to `occupied_count()`.
- `src/state/match_state.gd`: `_resolve_basic_cast`'s bound check gains the hole path;
  `_deliver_pending_draw` / `_draw_one_replacement` write into the owed slot instead of appending;
  `_deal_player`'s fill loop is REWRITTEN to an indexed write (AC 5).
- `src/ui/hud/hud_root.gd`: expected UNCHANGED. AC 7 is what makes that expectation safe.
- Test files this story touches, complete list (the pre-gate draft named three and missed four):
  `test/state/test_deck_and_hand.gd`, `test/state/test_card_play.gd`,
  `test/state/test_draw_delay_and_reshuffle.gd`, `test/state/test_discard_pile.gd`,
  `test/state/test_card_observation.gd`, `test/state/test_card_authoring.gd`,
  `test/state/test_determinism.gd`, `test/integration/test_card_hud.gd`,
  `test/integration/test_deck_reshuffle.gd`.

### Project Context Rules

- **Rejections ride the shipped `action_rejected` seam; no new signal, no new seam.**
  [Source: decision-log.md 3-5a AC 7, restated at 3-5b/R8]
- **Counts/indices only ever cross into `to_snapshot()` -- never a card id.**
  [Source: decision-log.md 3-3 AC 5, 3-5a AC 6, 3-0c AC 11]
- **CONSTRAINT C: authored balance is read INLINE at the moment of use**, never cached -- which is
  why the hand's width arrives from the deal seat rather than from a config reference on `Hand`.
  [Source: match_state.gd:735-737; AC 1]

### References

- [Source: decision-log.md Session 2026-08-06 -- Story 3-6 close-out (the finding)]
- [Source: decision-log.md Session 2026-08-06 -- E3 close-out (the ruling: "the operator RULES it is
  done NOW, not deferred... 4-0-hand-slot-stability")]
- [Source: decision-log.md Session 2026-08-07 -- Story 4-0 readiness gate (`4-0/R1`-`4-0/R8`)]
- [Source: decision-log.md 3-5b/R8]
- [Source: src/state/hand.gd; src/state/player_state.gd; src/state/match_state.gd]

## Golden Prediction

**MOVES.** Causes to be isolated the way every prior multi-cause re-baseline in this project has
been (1-5, 1-8, 1-9, 3-3, 3-4, 3-5a, 3-5b). The gate added cause 3 and MEASURED cause 2.

1. **Snapshot-shape cause.** `pending_draw_owed` changes shape (AC 4, AC 6) -- this alone moves the
   golden at an early tick, before any cast-order-dependent behaviour runs, the same way 3-5b's own
   two new keys each moved it by themselves.
2. **Behavioural cause -- MEASURED AT THE GATE, a NON-MOVER, and the dev pass does not re-derive
   it.** The concern was any fixture issuing a second cast against the SAME numeric `card_slot`
   before the first replacement lands: under the append model both casts resolved, under slot
   stability the second targets a hole and REJECTS (AC 3). The gate read all three hashing fixtures
   by content. **Each issues EXACTLY ONE cast:**

   | Fixture | Cast site | Casts | Slot / hand |
   | --- | --- | --- | --- |
   | `test_determinism.gd` (the golden) | `_play_sequence:879`, `if cast and t == CAST_TICK` | 1 | `CAST_SLOT` 3, `HAND_SIZE` 9 |
   | `test_record_file.gd` | `:567`, `if t == CAST_TICK` | 1 | slot 1, hand 3 |
   | `test_replay_identity.gd` | `:419`, `if t == CAST_TICK` | 1 | slot 1, hand 3 |

   No golden fixture issues a second cast against any slot, let alone the same slot, let alone before
   the first replacement lands. **Cause 2 is a measured non-mover.** The dev pass RECORDS this
   finding; it re-measures only if it changes a fixture's cast count, which nothing in this story
   requires.
3. **The `hand_size` KEY VALUE cause, added by the gate (`4-0/R7`), and a NON-MOVER if and only if
   AC 2 is honoured.** `"hand_size": hand.size()` (`player_state.gd:135`) is a hashed key. The golden
   hashes at t24 with a cast at t22 against an 11-tick delay, so a hole is LIVE at hash time: bound
   to the width the key would read 9 where it reads 8 today. Bound to `occupied_count()` per AC 2 it
   reads 8 and does not move. **The dev pass MEASURES this rather than asserting it** -- a
   Golden Prediction that misses a mover is precisely the failure mode the isolation discipline
   exists to catch, and this cause was missed by the pre-gate draft.

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

Claude Opus 5 (dev pass, 2026-08-07).

### Debug Log References

**Golden re-baseline, measured step by step, each cause isolated, both directions reproduced.**
Inherited value re-derived from `test_determinism.gd`'s `GOLDEN` constant at pass start per the
3-3 gate rule: `40eb5554...a322`. Preconditions: HEAD `7510b5a` (three docs commits past the
gate's recorded `69726a5`; no code between), clean tree, 362 tests / 2305 assertions / 0 failed
+ 23 integration green.

| # | Step | Prediction | Measurement | Result |
| --- | --- | --- | --- | --- |
| M1 | Causes 2 + 3 live, cause 1 STAGED OUT (`pending_draw_owed` still emitted as `.size()`) | non-movers | `40eb5554...a322` | **UNMOVED** — inherited value held |
| M2 | Cause 3 isolated: `hand_size` bound to `hand.size()` (WIDTH) | would-be mover | `2ce19380...5883` | **MOVED** — cause 3 is real |
| M3 | Cause 3 reverted to `occupied_count()` | non-mover | `40eb5554...a322` | **REVERSE REPRODUCED** |
| M4 | Cause 1: `pending_draw_owed` flipped to the slot-index array | the ONE mover | `312522d8...fb3c` | **MOVED** |
| M5 | Cause 1 reverted to `.size()`, all behaviour still live | returns to inherited | `40eb5554...a322` | **REVERSE REPRODUCED bit-identically** |

`GOLDEN` re-baselined ONCE: `40eb5554...a322` ->
`312522d8c597be8ba99f2beea56a8c7bdbfef48dd1f2eff1b8f6f49164c0fb3c`.

**Cause 2 (behavioural) — CONFIRMED BY MEASUREMENT, not re-derived.** The gate's finding (all
three hashing fixtures issue exactly one cast) was taken as given per this story's instruction.
This pass changed no hashing fixture's cast count, so the finding stands; M1 is its confirmation
— with cause 3 neutralised by AC 2 and cause 1 staged out, the entire behavioural change held the
inherited hash, leaving cause 2 the only remaining variable in an unmoved run.

**Cause 3 was NOT assumed.** `4-0/R7` required it measured, and it measured as a genuine would-be
mover (M2) neutralised precisely by AC 2's binding (M3). Had `Hand.size()` been left carrying both
readings, this story would have moved the golden for a reason unrelated to it.

**Mutation table — ten mutations, every guard proven FALLING.** Every target backed up OUTSIDE the
repo to the session scratchpad with SHA256 recorded before mutating, and restored by copying the
backup back with the checksum re-verified. `git checkout --` was never used (decision-log:799).

| # | Mutation | Falls |
| --- | --- | --- |
| X1 | `Hand.remove_at`'s occupancy Invariant reverted to a bound-only check (the vacuity AC 1 warns of) | `test_hand_guards_the_fill_and_the_removal...` |
| X2 | `Array.remove_at` left-shift reinstated in `Hand.remove_at` (the original defect) | **28 tests** across 5 files |
| X3 | `fill_at`'s occupied-slot Invariant deleted | `test_hand_guards_the_fill_and_the_removal...` |
| X4 | AC 3's hole guard deleted from `_resolve_basic_cast`, width bound kept | 3 tests |
| X5 | AC 7's cost lookup moved ABOVE the empty-slot guard | 6 tests |
| X6 | Delivery writes the FIRST HOLE instead of the OWED slot | `test_two_owed_slots_each_receive_their_own_replacement` |
| X7 | `_deal_player` fills back to front | `test_hand_fills_to_hand_size_from_the_top_of_the_shuffled_deck` |
| X8 | `Hand.EMPTY` changed to `&"__empty__"` | `test_the_empty_marker_is_the_empty_string_name...` |
| X9 | `is_empty()` reverted to the bare `_cards.is_empty()` | `test_hand_is_empty_means_no_occupied_slots...` |
| X10 | `Hand` caches a `BalanceConfig` (CONSTRAINT C breach) | `test_hand_never_names_hand_size_or_the_balance_config` + an inherited 3-0c guard |

**TWO MUTATIONS SURVIVED ON FIRST RUN AND FORCED NEW GUARDS — reported, not quietly patched:**

- **X6 survived.** `test_two_owed_slots_each_receive_their_own_replacement` originally cast slots
  0 then 3, where FIFO order and ascending-index order COINCIDE — so a delivery ignoring the owed
  address entirely still passed. The fixture now casts DESCENDING (3 then 0), making owed order
  `[3, 0]` disagree with first-hole order `[0, 3]` on the very first delivery. AC 4's central
  claim was under-guarded until this was found.
- **X8 survived.** Every site read `Hand.EMPTY` symbolically, so all of them followed the constant
  wherever it went and none could catch the constant itself changing. Closed by
  `test_the_empty_marker_is_the_empty_string_name_and_renders_as_a_blank_caption`, which pins the
  value as a LITERAL and states why `hud_root.gd:159` forces it.

### Completion Notes List

- **AC 1-8 delivered and pinned. AC 9 (live smoke) is NOT discharged — it is the operator's own
  hand by the story's own text and no agent writes that entry.** The story is at `review` with
  AC 9 outstanding, not at `done`.
- **`Hand.add()` was DELETED, not merely left unused.** Against a `clear(width)` that pre-fills
  the width, an appending method writes PAST it and produces a `2 * hand_size` array — the exact
  failure `4-0/R4` names. Removing the method makes that impossible BY CONSTRUCTION rather than
  detectable by inspection (project-context: guard mechanism over guard pattern, `3-0d/R20`).
  Two read accessors were added alongside the ruled `occupied_count()`: `occupied_ids()` (the
  occupancy view the four-term conservation proofs need, since the width view now carries markers
  that are not cards) and `is_slot_empty()` (which folds the WIDTH bound and the hole into ONE
  test, so AC 3's two paths cannot drift into two reasons).
- **`pending_draw_owed` is a FIFO `Array[int]` of owed slot indices** — the representation left
  free by `4-0/R6`. `CanonicalHash` preserves array ORDER, and that is correct here rather than
  incidental: the order IS the delivery order, and two owed slots delivering in the wrong order is
  a real divergence the hash should see. One shared `TimingWindow`, per `4-0/R6` — not re-opened.
- **The nine-consumer binding table was followed site by site, not re-derived.** `cards_changed`
  stays bound to WIDTH (a renderer laying out a fixed row needs holes positionally present);
  `hand_size`, `is_empty()`, `hand.gd`'s Invariant and all four conservation sites bind to
  OCCUPANCY. `match_state.gd`'s `for _slot in balance.hand_size` was left alone as the table says.
- **`src/ui/hud/hud_root.gd` is UNCHANGED**, and AC 7 is what makes that safe rather than lucky.
  Its `else ""` branch is now DEAD (no shipped seat can emit a short array) and the caption of a
  hole is literally `str(Hand.EMPTY)` — blank only because the marker is the empty StringName.
- **`project.godot` byte-identical throughout.** No new files, so no `.uid` scan was owed.
- **AC 8's permanent hole is pinned as DESIGN**, headless and in integration: the debt is
  consumed, the hole persists at full width, and that slot refuses through AC 3 repeatedly for the
  rest of the round while its neighbours are untouched.
- Suite: **362 tests / 2305 assertions / 23 integration -> 373 tests / 2397 assertions / 23
  integration, 0 failed**, zero SCRIPT ERROR / Parse Error / INVARIANT VIOLATED.
- One test RENAMED, old name recorded verbatim in its own docstring so the Fence Inventory stays
  greppable: `test_the_pending_draw_keys_carry_a_window_and_an_int_debt_only` ->
  `..._and_slot_indices_only`. One more effectively renamed by inversion:
  `test_hand_remove_at_returns_and_removes_the_named_slot` ->
  `test_hand_remove_at_leaves_a_hole_and_moves_no_other_slot` (its old assertion — "the remaining
  cards close up in order" — WAS the bug).
- **Correction recorded, not silently applied:** AC 7 ratified `test_balance_authoring.gd` as the
  marker-collision guard's home; by content that file cannot reach `data/cards/`, so the
  re-pointing landed on `test_card_authoring.gd:66` where the authored cards actually are. The
  story text already anticipates this; noting it here as executed.

### File List

- `src/state/hand.gd` — fixed-width hole-aware container; `clear(width)`, `size()` = WIDTH, new
  `occupied_count()` / `occupied_ids()` / `is_slot_empty()` / `fill_at()`; `remove_at` is an
  in-place hole write with its Invariant re-pointed to occupancy; `add()` deleted; `EMPTY` marker.
- `src/state/player_state.gd` — `pending_draw_owed` is `Array[int]`; snapshot `hand_size` binds
  `occupied_count()`; `pending_draw_owed` key carries the slot-index array.
- `src/state/match_state.gd` — `_deal_player` establishes the width inline and fills by indexed
  write; `_resolve_basic_cast` refuses holes through the shipped reason before the cost lookup;
  `_deliver_pending_draw` pops an owed SLOT; `_draw_one_replacement` fills that slot.
- `test/state/test_discard_pile.gd` — `remove_at` shrink pins inverted to hole pins; `fill_at`,
  `is_empty()`, marker-value and guard-scan tests added.
- `test/state/test_draw_delay_and_reshuffle.gd` — `_cast` helper takes a REQUIRED slot; multi-cast
  fixtures cast one slot each; debt assertions re-shaped; five slot-stability tests added (AC 1,
  AC 3 x2, AC 4, AC 8).
- `test/state/test_deck_and_hand.gd` — container test rebuilt on the shipped surface; deal
  fixtures assert occupancy AND width and no trailing hole; AC 1 structural fence added.
- `test/state/test_card_play.gd` — byte-for-byte unchanged-neighbour assertion; conservation
  re-pointed; AC 7 cost-ordering pin added.
- `test/state/test_card_observation.gd` — announced payload is FULL WIDTH with the marker at the
  hole.
- `test/state/test_card_authoring.gd` — `card.id != Hand.EMPTY` re-pointed as load-bearing for the
  marker choice, with the reason attached.
- `test/state/test_determinism.gd` — `GOLDEN` re-baselined; three-cause header recorded; hashing
  fixture asserts the live hole and the owed address.
- `test/integration/test_card_hud.gd` — `vacated_cleared` / `refill_rewrote` re-pointed to a
  marker-bearing FULL-WIDTH payload vacating a NON-rightmost slot.
- `test/integration/test_deck_reshuffle.gd` — debt assertions re-shaped; AC 8 persistence checked
  against the authored config.
- `test/integration/test_deck_injection.gd` — deal counts assert occupancy and width separately.

### Change Log

- 2026-08-07 — Story 4-0 implemented (AC 1-8). Hand becomes fixed-width and hole-aware; the owed
  replacement refills the vacated slot. Golden re-baselined once, `40eb5554...a322` ->
  `312522d8...fb3c`, one predicted mover, two measured non-movers. Ten-row mutation table, two
  survivors found and closed with new guards. Suite 362/2305 -> 373/2397, 23 integration green.
  AC 9 (live smoke) outstanding — operator's own hand.
