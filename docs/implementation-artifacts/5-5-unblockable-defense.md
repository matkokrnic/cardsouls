---
baseline_commit: c62fb36d3d86ad4ddf4eacd9af7a8ca6984023ec
---

# Story 5.5: Unblockable Defense

Status: ready-for-dev

## What this story supersedes

The task brief that seeded this story makes three claims the repo does not support. Measured
against the code rather than assumed:

1. **`HeroState` carries NO `defense` `TimingWindow`.** Its eight windows are `windup`, `active`,
   `recovery`, `chain`, `deflect`, `roll_iframe`, `roll_duration`, `stun` (`hero_state.gd:104-111`)
   — `deflect` is `1-8`'s block-timing parry window, fully owned by melee block, and there is no
   seventh/ninth field named `defense` anywhere. The brief's "I believe the `defense` window has no
   consumer... DO NOT TRUST THAT" hedge resolves to: **no such window exists to be trusted or
   distrusted.** This story DECLARES a new window, on `PlayerState` (not `HeroState`) — see AC 2 for
   why that home, the exact `charge_window` precedent (`5-2/R9`).
2. **`ModeKind.DEFENSE` IS ordinal 2**, confirmed against `enums.gd:27`:
   `enum ModeKind { BASIC, UNBLOCKABLE, DEFENSE, PITCH }` — `BASIC=0, UNBLOCKABLE=1, DEFENSE=2,
   PITCH=3`. The brief's own restatement of this is correct; recorded here because AC 1 depends on
   it precisely.
3. **`5-2/R17`'s "casting drops the block" is not currently reproducible by any shipped cast.**
   `_resolve_basic_cast` (mode ①) never calls `set_action_state` — its own comment says so in as
   many words ("A basic cast is an instant summon that interrupts nothing", `match_state.gd:2400`).
   `_resolve_unblockable_cast` (mode ②) DOES call `set_action_state(CHARGING)` unconditionally, but
   `_unblockable_refusal_reason` (`match_state.gd:2402-2409`) REFUSES the cast outright while
   `BLOCKING` (along with `ROLLING`/`ATTACKING`/`CHARGING`) — so mode ②'s state-clobbering write can
   never actually fire from a blocking hero. **`5-2/R17` describes a consequence that, as measured,
   has never yet been exercised by any shipped mode.** This story is the one that makes it real: mode
   ③ is the FIRST cast that is not state-gated against `BLOCKING` (R-D forbids gating it — the
   defender must be able to answer from any state) and therefore the first to genuinely drop an
   active block on cast, giving `5-2/R17` its ruling and its first test (AC 5).

## Story

As the operator implementing the RGB read exchange's answer half,
I want a defender to negate an incoming unblockable by playing a card of the matching colour
inside an authored reaction window that opens the instant they commit it,
so that colour becomes a real defensive tool — not merely a payout trigger — before `5-6`'s
three-tier ladder gives every colour combination its own consequence.

## Acceptance Criteria

**Dispatch (`match_state.gd:2222-2243` `_resolve_card_action`, `enums.gd:27`)**

1. **`Enums.ModeKind.DEFENSE` (ordinal 2, measured above) gains a real resolution arm**,
   `_resolve_defense_cast`, added to the `match intent.card_mode:` dispatch beside `BASIC` and
   `UNBLOCKABLE`. The `_` catch-all's `Invariant.check(false, ...)` stays, now guarding exactly ONE
   unreached mode (`PITCH`, `E6`'s) instead of two. `test_card_play.gd`'s `REACHABLE_MODES` widens
   to `["BASIC", "UNBLOCKABLE", "DEFENSE"]` (the `5-2/R8` precedent narrowed a second time, never
   deleted), and `test_the_reachable_mode_set_is_exactly_basic_and_unblockable` is RENAMED to name
   the widened set — the same "a test whose NAME asserts a stale count does not survive" discipline
   `5-4`'s deviation 2 already applied to `test_runner_observation_seams_are_exactly_eight`.

**The window and its colour (`player_state.gd`, the `charge_window`/`charge_color` precedent)**

2. **Two new `PlayerState` fields, `defense_window: TimingWindow` and
   `defense_color: int = NO_TELEGRAPH_COLOR`**, constructed in `_init` beside `charge_window`
   (`player_state.gd:218`) and ticked at `MatchState.advance()` step 2 beside `p1.charge_window.tick()`
   / `p2.charge_window.tick()` (`match_state.gd:388-389`). Seated on `PlayerState`, not `HeroState`,
   for the identical reason `charge_window` is (`5-2/R9`'s own comment, `player_state.gd:163-172`):
   this is a CARD-LAYER duration started by a cast, not a `TRANSITION_TABLE` edge, and belongs beside
   the other windows a cast starts. `NO_TELEGRAPH_COLOR` (`player_state.gd:190`, already `-1`) is
   REUSED verbatim as the resting sentinel — a THIRD context sharing the one "no colour" token
   (telegraph, the AC 5 orb-grant guard, now defense), never a second `-1` invented for the same fact.

**Casting (`_resolve_defense_cast`, the `_resolve_unblockable_cast` shape)**

3. **The layer gate is the SAME `flags.unblockable` flag mode ② already reads** — no new
   `FeatureFlags` field. Defending only matters where an unblockable exists to defend against, so a
   closed `unblockable` layer closes mode ③ too, read inline (CONSTRAINT C), `flags == null` reading
   CLOSED exactly as every other layer gate in this file does. `CastEvaluator.REASON_FLAG_CLOSED` is
   reused, the same borrow `_resolve_unblockable_cast` already makes.
4. **EXACTLY ONE state-based refusal: CHARGING.** New operator ruling — a defense cast is refused
   while the caster is CHARGING; `ROLLING`, `BLOCKING`, and `ATTACKING` remain allowed, and the
   defender must be able to answer from any of those three, mid-swing or mid-block included. The
   chargeup is a large committal attack by the operator's own ruling (souls grab/axe register) and a
   commitment coverable by a defense is not a commitment — the caster moved first and carries the
   risk. It also keeps the layers alternating rather than overlapping: the defender reads a
   telegraph and knows a charging hero can do nothing back. The refusal REUSES
   `MatchState.REASON_UNBLOCKABLE_COMMITTED` verbatim rather than inventing a new reason:
   `_resolve_defense_cast`'s own gate is the identical single-state check `_unblockable_refusal_reason`
   already makes for `CHARGING` on the mode ② path, and the existing name already reads true here —
   "an unblockable is committed" describes exactly why a CHARGING hero cannot also cast DEFENSE.
   `CastEvaluator` itself has no state-based reason at all (measured: its five `REASON_*` constants
   are `EMPTY_SLOT`/`UNKNOWN_CARD`/`FLAG_CLOSED`/`INSUFFICIENT_MANA`/`INSUFFICIENT_ORBS`, none of them
   state-shaped), so `MatchState`'s own sibling constant is the only candidate and it fits without
   qualification. The remaining gates are the S6-precedent layer check (AC 3), the empty-slot check
   (`CastEvaluator.REASON_EMPTY_SLOT`, reused verbatim), and the stamina spend (AC 7). The top-level
   `DEAD` guard already shared by every card mode (`match_state.gd:2225-2226`) is untouched and still
   applies.
5. **Casting mode ③ calls `player.hero.set_action_state(HeroState.ActionState.IDLE)` ONLY when the
   hero is `BLOCKING`.** `ATTACKING` and `ROLLING` are left untouched by the cast — the card is
   spent (AC 8), the defense window opens (AC 2), and the swing or roll finishes on its own contract
   exactly as if no card had been cast. (`CHARGING` no longer arises at this seat: AC 4 refuses the
   cast outright before any state write.) This corrects an unconditional-IDLE draft that was a live
   defect, not merely over-broad: from `ATTACKING` an unconditional `set_action_state(IDLE)` would
   leave the swing's `active` window running and still pushing contacts while the hero is no longer
   rooted and now moves at full speed, with the phase machine never reaching `attack_done`; from
   `CHARGING` it would leave `charge_window` running with no path to a landing, since the only caller
   of `_resolve_charge_landing` is gated on `action_state == CHARGING` — the chargeup would be
   silently voided with the card and stamina already spent. Restricting the write to the `BLOCKING`
   case is what ratifies `5-2/R17` (see "What this story supersedes" item 3): a hero `BLOCKING` who
   commits a defense cast is moved to `IDLE` on that same tick, dropping the block.
   `HeroState.TRANSITION_TABLE` gains NO row, the identical `5-2/R7`/AC 7-8 reasoning: the card layer
   drives this edge directly, not an inbound press the table maps. Three explicit tests are required:
   a `BLOCKING` hero's block drops on a defense cast (the first real, non-vacuous exercise of
   `5-2/R17`, which until this story described a consequence no shipped cast could ever trigger, see
   superseded item 3); an `ATTACKING` hero stays `ATTACKING` across the cast tick with `active`,
   `chain_index`, and the swing dedupe record all untouched; and a `ROLLING` hero stays `ROLLING`
   with its roll windows intact. The gate found the cast path never reads or writes any of the
   attack/roll fields — so "untouched by construction" is the claim to test, not argue, the exact
   discipline `5-4` learned to apply rather than assert. **The cast introduces no new action state
   and no new rooting or slowing of its own (R-D, negative AC, folded in from a cut AC 6):** no new
   `HeroState.ActionState` member is introduced (`IDLE` is the target of the `BLOCKING` transition
   above, not a new "DEFENDING" state), no movement-speed multiplier changes, and the defense window
   (AC 2) is a pure data timer, independent of `action_state`, exactly as `pending_draw` decides an
   outcome without owning an action state of its own (`player_state.gd:123`, `pending_draw`'s own
   header).
6. **Stamina spend is a NEW bespoke `BalanceConfig` field, `defense_stamina_cost: float`
   (provisional, smaller than `unblockable_stamina_cost`, per R-D)**, the fifth stamina seat
   (roll/attack/unblockable/deflect precede it), spent via `player.stamina.spend(...,
   stamina_regen_delay_ticks)` on the `1-4` FALLTHROUGH shape (unaffordable = refuse, nothing spent,
   nothing else mutates) — `_resolve_unblockable_cast`'s exact idiom, never deflect's degrade (there
   is no degraded defense to fall back to).
7. **The card leaves the hand and enters the discard on EVERY commit, hit or miss (R-D: "the card is
   always consumed").** `player.hand.remove_at`, `player.discard.add`, the replacement owed
   (`pending_draw_owed.append` + `pending_draw.start`), and `notify_cards_changed` /
   `card_cast_resolved` all fire — `_resolve_basic_cast`/`_resolve_unblockable_cast`'s ordering
   mirrored exactly, all inside this one tick, all UNCONDITIONAL on what happens later at landing.
8. **The colour is read from the SAME `_card_colors` injected map mode ② already reads**
   (`match_state.gd:2495-2496`'s exact idiom), copied into `player.defense_color`, guarded against a
   missing entry by degrading to `NO_TELEGRAPH_COLOR` (never an invented colour) — the identical
   unreachable-in-live-play sentinel family AC 5 of `5-4` already established for `charge_color`.

**The landing intercept (`_resolve_charge_landing`, `match_state.gd:2548-2564`)**

9. **The defense check sits INSIDE the existing `_charge_reach[slot] == CONTACT_CHARGE_REACH_INSIDE
   and target.hero.is_alive()` branch, BEFORE `target.hero.take_damage(damage)`.** The exact rung
   order, in the step-4-contact-ladder style: (a) reach+alive gate (existing, unchanged) → (b) NEW:
   is `target.defense_window.is_running` AND does `target.defense_color == player.charge_color`? →
   if BOTH true, negate (AC 10) and `return`-equivalent out of the branch, skipping (c)/(d); if
   EITHER false, fall through unchanged to (c) `take_damage` + `hit_landed` emit (existing) → (d)
   `_grant_landing_orbs` (existing, `5-4`). The unconditional
   `player.hero.set_action_state(HeroState.ActionState.IDLE)` exit (`match_state.gd:2564`) is
   UNTOUCHED and still runs on every outcome, negated or not — the attacker's own chargeup always
   ends the same way. **A fourth path through this gate, named for completeness: a DEAD defender
   cannot negate at all**, because the branch's own `target.hero.is_alive()` gate (existing, (a))
   precedes the AC 10 colour check — a dead hero's `defense_window`, however it got there, is never
   consulted.
10. **A colour match while the window is open negates completely (R-C).** Zero damage
    (`take_damage` never called), no `hit_landed` (the enemy was never hurt), and no orb grant
    (`_grant_landing_orbs` never called — the attacker earns nothing because there is no landing to
    pay for, R-C's own words). **The blind-spot pin owes a POSITIVE CONTROL in the same fixture**
    (the `5-4` "the pool sat at zero either way" family): before asserting the negated landing grants
    nothing, the SAME fixture must first show an UNDEFENDED landing (no window running, or a
    wrong-colour window) DOES grant — otherwise "no orb grant" can pass against a path that could
    never have granted in the first place, proving nothing. The window is CONSUMED:
    `target.defense_window.start(0)` stops it and `target.defense_color` resets to
    `NO_TELEGRAPH_COLOR`, the exact `charge_window.start(0)` / `charge_color = NO_TELEGRAPH_COLOR`
    pairing the debug reset already uses (`match_state.gd:3251-3252`) — one fact in two parts,
    cleared together. **No stun of any kind on either party (R-C, negative AC)** —
    `HeroState.stun` is not started, on either hero; `STUNNED` stays the zero-inbound-edge row it has
    been since E1 (`hero_state.gd:40-42`), untouched by this story.
11. **A DIFFERENT colour landing while the window is open does NOT defend AND does NOT consume the
    window (R-B).** The attack resolves exactly as it would with no defense in play — full damage,
    `hit_landed`, orb grant all fire — and `defense_window` is left running, ticking down at its own
    ordinary step-2 rate, available to answer a LATER same-colour landing before it expires. Nothing
    about a wrong-colour landing touches `defense_window` or `defense_color` at all; only the
    per-tick `.tick()` call (AC 2) ever advances it. **The blind-spot pin owes a FALLING MUTATION**:
    an implementation that checks colour correctly but consumes the window on every landing
    (colour-matched or not) passes every assertion named above unless one is built to catch it —
    the required test moves window consumption OUT of the colour-match branch and ONTO the landing
    branch unconditionally, and asserts the window SURVIVES a wrong-colour landing and goes on to
    answer a LATER same-colour landing before it expires; this assertion must go RED against that
    mutation, proving the "does not consume" claim is load-bearing and not merely present.

**Reset (`_reset_player`, `match_state.gd:3225-3267`)**

12. **`defense_window`/`defense_color` join the `_reset_player` "NOTHING else" exceptions as the
    FOURTH named exception, measured against the code's own ordinal comments.** The unit board is
    named FIRST (`4-1/R5`) — with the unit dedupe records and the projectile board clearing under
    that SAME exception, not separately numbered, since both key board state that a board clear would
    otherwise orphan. The chargeup (`charge_window`/`charge_color`) is named SECOND
    (`match_state.gd`'s own "SECOND named exception" comment, `5-3` fix pass). Orbs are THIRD
    (`match_state.gd`'s own "THIRD NAMED EXCEPTION" comment, `5-4` AC 13). Defense is the FOURTH,
    cleared together on the SAME `charge_window.start(0)` / `= NO_TELEGRAPH_COLOR` shape immediately
    beside the `charge_window`/`charge_color` clear (`match_state.gd:3251-3252`) — for the identical
    reason: a defense window frozen mid-count by the round-over freeze (step 1b returns before step
    2's `.tick()`, `match_state.gd:388-389`) would otherwise carry a live, unexpired window into the
    NEXT round, where a same-colour landing from an entirely new round could be negated by a card
    played in the round before. **The chargeup clear is THREE fields (`action_state`,
    `charge_window`, `charge_color`) because it owns an `ActionState`; the defense clear is TWO
    fields (`defense_window`, `defense_color`) because it owns none (AC 4/AC 5) — the asymmetry is
    deliberate, not a narrower copy.** **`_end_round` gains NO matching clear** — the identical `5-4`
    Dev-Notes finding (orbs' `_end_round` non-clear) applied to a second field: `_end_round` has never
    cleared per-player economy/timer state, the debug reset is this codebase's one round-boundary
    transition mechanism, and a clear inside `_end_round` itself would end a still-open defense the
    instant the OTHER hero dies, before the round-over freeze even displays anything — a needless
    behaviour with no precedent anywhere in this file.

**Legibility (`match_state.gd`, the EXISTING `deflect_landed` seam — no tenth observation channel)**

13. **The negation reuses the EXISTING `deflect_landed` signal, WIDENED to carry the answered colour
    as a THIRD argument** — `deflect_landed(attacker_slot: int, target_slot: int, defense_color:
    int)` — **and its already-wired `connect_deflect_landed` seam (`match_runner.gd:849-850`), whose
    own signature (`callback: Callable`) is unaffected by widening the signal it wraps.** The TWO
    EXISTING melee call sites pass `NO_TELEGRAPH_COLOR` (`-1`) as this third argument — an explicit
    "no colour to report" sentinel, not a fourth invented value, `NO_TELEGRAPH_COLOR` reused a FOURTH
    context over (telegraph, `5-4`'s AC 5 orb-grant guard, `defense_color`'s own resting value, now
    this).
    `_resolve_charge_landing` becomes the signal's SECOND emit site — measured: `deflect_landed` has
    exactly ONE existing emit site today (`match_state.gd:1416`, a single queued push already generic
    over both attacker kinds — hero melee and `4-3b`'s unit melee — not two separate call sites),
    passing the ACTUAL matched colour on the AC 10 negation path. `TelegraphController.on_deflect_landed`
    (`telegraph_controller.gd:219-229`) tints its existing spark/sting cue to that colour when it is
    not the sentinel; an ordinary melee parry (colour == sentinel) keeps today's untinted cue exactly
    as it renders now — the widening is additive, and no existing consumer's observable behaviour
    changes. `OBSERVATION_SEAMS` in `test_architecture_invariants.gd:291-306` (nine members, `5-4`'s
    own "FROZEN AT NINE" pin) is UNCHANGED by this story — a NEGATIVE AC, measured by re-running that
    exact test unedited; the pin's own regex counts `connect_*` WRAPPER FUNCTIONS declared in
    `match_runner.gd` (`test_architecture_invariants.gd:310`), not signal arity, so widening
    `deflect_landed`'s parameter list does not touch the count. No new `MatchState.card_defended`
    signal is built; that alternative is refused here, on `5-4/AC 15`'s own precedent of refusing a
    duplicate channel when an existing one already carries the shape.

**Balance authoring (`balance_config.gd`, `test_balance_authoring.gd`, `test_data_resources.gd`,
`test_balance_config.gd`)**

14. **Two new `BalanceConfig` fields join `E1_BALANCE_FIELDS`** (`test_data_resources.gd:33`):
    `defense_stamina_cost: float` (AC 6) and `defense_window_seconds: float` (AC 2's window
    duration, provisional ~1.5 s — deliberately longer than `unblockable_chargeup_seconds`, per R-A).
    **This field list is only HALF of `test_data_resources.gd`'s obligation.** Its reflective arm
    (`test_data_resources.gd`'s own "(b) EVERY `*_seconds` property must have a value DERIVED by
    `BalanceTicks.from_config()`" clause) independently requires a stem-matched `*_ticks` twin for
    ANY field named `*_seconds` — `defense_window_seconds` carries that suffix, so it is caught by
    this reflective probe regardless of the named-field list, via a new
    `BalanceTicks.defense_window_ticks = TimingWindow.seconds_to_ticks(config.defense_window_seconds)`
    (`timing/balance_ticks.gd`, beside the other `unblockable_*`-adjacent conversions).
    `defense_stamina_cost` carries no `_seconds` suffix and is untouched by that reflective arm. Both
    new fields carry a BESPOKE authored `> 0` bound in `test_balance_authoring.gd`, the
    `unblockable_stamina_cost`/`unblockable_chargeup_seconds` precedent verbatim (an unqualified
    `>= 0` loop bound passes on the script default and ships the story invisible). **No edit is
    forced in `test_balance_config.gd`**: its hand-written `test_conversion_covers_every_seconds_field`
    literal is ALREADY non-exhaustive — measured, `unblockable_chargeup_seconds` is itself absent
    from that literal today — so `defense_window_seconds` joining the same gap is consistent with the
    file's existing coverage, not a new hole this story opens; stated explicitly so a reviewer does
    not go looking for a forced edit that isn't there.

**Keyboard binding (`project.godot`, `keyboard_controller.gd`, the `5-3/R17`... `5-2/R15` precedent)**

15. **ONE new TEMPORARY Input Map action, `p2_cast_defense`, P2-ONLY, physical key `L`, adjacent to
    the P2 zone.** Measured before deciding: `project.godot` today gives P2 `cast_mode`/`card_1`-
    `card_4`/`cast_confirm` (the full BASIC scheme) but NO `cast_unblockable` — P2 cannot cast mode ②
    at all today, by the SAME Non-Goals scoping `5-3` gave `p1_cast_unblockable` ("the live-smoke
    human eye sits at P1"). Since P1 is the only prefix that can ever initiate mode ②, P1 is
    structurally the ATTACKER and P2 the DEFENDER for any smoke of this mechanic regardless of
    `slot_controller_kinds` order — so only the DEFENDER side needs a new key. `p2_cast_defense`,
    read in `KeyboardController._sample_card_scheme` on the `p1_cast_unblockable` precedent exactly
    (`InputMap.has_action` guarded, so a `p1`-prefixed instance silently skips the branch — the
    P1-only mirror of `5-3/R17`'s own `p2` skip): committing the armed slot as `DEFENSE` in place of
    `cast_confirm`'s `BASIC` commit. **The keyboard card scheme's branch priority is: defense checked
    ABOVE confirm, and the two are MUTUALLY EXCLUSIVE** — a tick that presses `p2_cast_defense` commits
    `DEFENSE` and never falls through to evaluate `cast_confirm`'s `BASIC` commit on the same press,
    the same one-commit-per-tick shape every other arm-then-confirm branch in this scheme already
    has. TEMPORARY, explicitly named for `5-7` to delete: ONE Input Map action (`p2_cast_defense`),
    ONE branch arm in `_sample_card_scheme`, its ONE backing field (`_cast_defense`), and its ONE
    action-string line — the exact four-part deletion inventory `5-3` itself named for
    `p1_cast_unblockable` — alongside `p1_cast_unblockable` when the pad scheme lands; the
    arm-then-confirm sequence itself survives unchanged. **The band this story's timing depends on
    has TWO edges, not one.** The defender may PRE-ARM (hold the key before the chargeup begins), so
    only the single defense KEYPRESS must land inside the band — but the band itself runs from
    `defense_window_seconds` before the chargeup lands back to the landing tick itself: casting
    EARLIER than the window length before the landing fails silently (the window expires before the
    hit arrives), exactly as casting AFTER the landing does (there is nothing left to answer). Both
    edges are symmetric failure modes of the same band, not one edge with a single-sided margin.

**Golden Prediction — the machine contract**

16. **THE GOLDEN MOVES, ONCE, with ONE measured cause — the new "defense" snapshot key.**
    `PlayerState.to_snapshot()` gains a fifth window-shaped key, following the "telegraph" precedent
    verbatim but gated DIFFERENTLY (named explicitly in Dev Notes): `"defense": [defense_color,
    defense_window.remaining_ticks()] if defense_window.is_running else [NO_TELEGRAPH_COLOR, 0]`.
    This is the `5-2` shape, not the `5-4` shape: `5-4`'s `orbs` key ALREADY EXISTED before that
    story, so adding a grant path behind it moved nothing; THIS key is genuinely NEW, so its resting
    value (`[-1, 0]`) still changes the snapshot dictionary's SHAPE on every tick of every match,
    reached or not — the same reason `5-2`'s telegraph key moved the golden even though the fixture
    never cast mode ②. The dev pass owes the SAME two reverse measurements `5-2`/`5-4` both ran:
    (a) stage the new key OUT of `to_snapshot()` and confirm the hash reads the INHERITED value
    exactly (proves the cause is the key's mere existence, not some other edit smuggled in); (b) with
    the key IN, confirm the resting value is genuinely `[-1, 0]` on the golden fixture (the fixture
    never casts mode ③, so `defense_window.is_running` is false at every hash tick — argued, not
    assumed: `test_determinism.gd`'s fixture builds intents from a fixed `MOVES` table and one single
    named cast at CAST_TICK, `test_determinism.gd:286`, which is mode ①/② content, never `DEFENSE`).
    **`FORMAT_VERSION` STAYS AT 7 — a CLOSED, gate-verified measured answer, not something the dev
    pass determines.** Unlike `5-2`'s bump (forced by `inject_card_colors`, a genuinely NEW
    `MatchState` injection seam the recorder had to learn), mode ③ reads the SAME `_card_colors` map
    mode ② already injects (AC 8): no new intake surface, no new injection seam, no new contact kind,
    no new `InputIntent` field (`card_slot`/`card_mode`/`card_commit` already carry everything mode ③
    needs, `enums.gd`'s four-member `ModeKind` was sized for this from `3-5a`). This is the `5-4`
    shape: a new BalanceConfig field and a new resolution arm over an EXISTING capture channel, not a
    new channel. State the measured confirmation in Completion Notes.

## Non-Goals

- **No stun of any kind** (AC 10) and **no resolution of the open attacker-consequence-on-deflect
  decision** (GDD decision-log, Session 2026-07-22, decision (a)) — both `5-6`'s.
- **No dodge rung / three-tier ladder** — every landed hit this story cannot negate resolves exactly
  as `5-4` shipped it (full damage, full orb grant); the three-tier outcome ladder is `5-6`'s.
- **No pad scheme, no hold-to-charge** — `5-7`'s. `p2_cast_defense` (AC 15) is explicitly temporary.
- **No orb SPEND path** — mode ④ (Pitch) is `E6`; nothing here reads `orbs` at all.
- **No colouring of the cards in hand** — the open `5-4`-smoke finding, still no owner.
- **No telegraph or chargeup retune** — `unblockable_chargeup_seconds`, the charge clips, and the
  charge cue are all untouched; AC 14's `defense_window_seconds` is a NEW, separate duration.
- **No edit to `game-architecture.md`** — the ARCH AMENDMENT QUEUE has two members (`5-3`'s
  `MatchState` direct-connect, `5-4`'s eight-to-nine seam-count prose) and is flushed at the E5
  close-out; this story adds no seam and therefore no third member.
- **No new `FeatureFlags` field** — AC 3 reuses `unblockable` verbatim.
- **No new `HeroState.ActionState` member** — AC 5 uses the existing `IDLE`.
- **No change to any `5-2` chargeup behaviour** — see Open Questions for what a `CHARGING` hero is
  measured to be able to do today; whatever that measurement finds is `5-2`'s inheritance, not this
  story's to fix.

## Deferred

- **Whether re-casting mode ③ while a defense window is already running should refuse or simply
  restart it** is left to the dev pass's judgment (`TimingWindow.start()` naturally restarts, the
  `charge_window` precedent for a fresh cast overwriting an in-flight one) — not specified by any
  ruling above, and not worth a new refusal reason without an operator ask for one.
- **Whether `p1_cast_defense` should ALSO ship** (letting P1 defend while P2 attacks) is measured OUT
  by AC 15's own reasoning: P2 can never initiate mode ②, so P1 is structurally always the attacker
  and a P1 defense key would never be exercised by the shipped scheme. If a future story gives P2 its
  own `cast_unblockable`, this decision is revisited then, not pre-built here.

## Live Smoke

1. **A same-colour defense negates completely.** P1 casts UNBLOCKABLE in a colour, P2 casts DEFENSE
   in the SAME colour before it lands: no damage, no orb for P1, the spark/sting cue fires on P2's
   hero, visible from both split-screen viewports.
2. **A wrong-colour defense does nothing to the outcome, and the window survives.** P2 defends in a
   DIFFERENT colour than P1's charge: the hit lands full damage, P1 earns the orb, and — inside the
   SAME window's remaining time — P2 can still defend a second same-colour attempt before it expires.
3. **An unanswered window just runs out.** P2 casts DEFENSE and nothing lands before the ~1.5 s
   window closes: the card is gone (discarded, replacement owed) and nothing else is observably
   different.
4. **Casting mode ③ drops an active block.** P2 holds BLOCK, then casts DEFENSE: the block visibly
   drops on the same tick (whatever cue signals BLOCKING today stops), and P2 is free to move
   immediately after — never rooted, never slowed.
5. **A cast from IDLE or while moving is free immediately; a cast mid-swing finishes the swing
   first, THEN is free.** Casting DEFENSE while `IDLE`, moving, or (per item 4) `BLOCKING` frees the
   defender on the very next tick — no visible lock persists. Casting it MID-SWING or MID-ROLL is
   DIFFERENT and must be smoked as its own case: the swing or roll visibly finishes UNALTERED on its
   own timing (AC 5 leaves `ATTACKING`/`ROLLING` untouched), and ONLY THEN is the defender free to
   act again — the root belongs to the swing or roll, not to the cast, and does not lift early.
6. **The flip proves the mechanism is symmetric.** With `slot_controller_kinds` flipped to
   `[KEYBOARD_P2, KEYBOARD_P1]`, repeat item 1: the negation still fires correctly regardless of
   which physical keyboard drives which hero slot.
7. **Nothing else in the match changes.** Movement, melee, blocking (independent of a defense cast),
   rolling, mode ① casting, mode ② damage/reach/rooting when undefended, orbs, minions, and totems
   all behave exactly as `5-4` shipped them — a regression smoke for everything except the new answer.
8. **FPS** — no visible frame-rate impact from the new per-tick window read or the reused cue.

## Open Questions (left to the gate / dev pass)

- **MEASURED: what a `CHARGING` hero is allowed to do TODAY, before this story.** The chargeup
  already hard-roots movement and already refuses a second unblockable cast (both CONFIRMED,
  `_unblockable_refusal_reason`'s own `CHARGING` arm) — the rest was unmeasured going into this
  story and is now measured against the code directly: `HeroState.transition_row()` maps `CHARGING`
  to the row key `&"charging"`, which has **NO entry in `TRANSITION_TABLE`** (`hero_state.gd`'s own
  comment: "CHARGING: reserved for E5 — no row, no inbound edge; deliberately absent, not stubbed"),
  and a press whose action has no entry in the current row is DROPPED, never buffered. So a
  `CHARGING` hero's attack/roll/block presses are ALL dropped today — **a CHARGING hero cannot
  swing, roll, or block.** A basic (mode ①) cast is DIFFERENT: `_resolve_basic_cast` never reads
  `hero.action_state` at all (its own comment: "an instant summon that interrupts nothing") — **a
  CHARGING hero CAN cast a basic card today**, unmodified by this story. **If any future finding
  contradicts this measurement — a swing, roll, or block somehow reaching a `CHARGING` hero — that is
  a defect INHERITED FROM `5-2`, not created by this story, and its owner is `5-6`**, where the
  ladder and the attacker-consequence decision already sit, so the attacker's and defender's sides of
  a chargeup get judged as one system instead of the chargeup being touched twice. This story fixes
  ONLY mode ③'s own refusal (AC 4); it changes NOTHING about `5-2`'s `CHARGING` behaviour.
- **Test file placement.** A new `test/state/test_unblockable_defense.gd` on the
  `test_orbs_economy.gd`/`test_unblockable_initiation.gd` sibling precedent for the state-level ACs
  (1-12, 14, 16), vs. extending `test_unblockable_initiation.gd` directly — `5-4`'s own close-out
  found the new-sibling-file choice worth a free regression (an unedited file whose fixture never
  changes stays proof the new story touched nothing in it); likely the same call here, dev's to name.
- **Whether an integration test is warranted for AC 13.** Unlike `5-4`'s AC 16 (a genuinely NEW seam
  with a real prime-on-connect risk), AC 13 rides an EXISTING, already-wired seam with existing
  runtime composition (`connect_deflect_landed` has been live since `1-8`) — the BLIND-SPOT PIN this
  story owes (see below) is satisfiable at the state level alone (assert the correct `deflect_landed`
  payload fires on a same-colour landing and does not on a different-colour one). A cheap
  `test/integration/` pin proving the CUE itself still fires, tinted, from the new emit site is a
  strictly lower-risk addition than `5-4`'s was; dev's call whether the marginal proof is worth a new
  file.
- **Exact provisional values** (`defense_window_seconds` ~1.5, `defense_stamina_cost` "smaller than
  `unblockable_stamina_cost`") are the operator's ratified STARTING POINTS, not final tuning — the
  live smoke is what actually judges feel.

## Dev Notes

- **The BLIND-SPOT PIN this story owes** (3-0b/R34 precedent, `test_totem_tint_live.gd`'s family):
  a cheap headless test must prove the negation actually fires for a MATCHING colour and does NOT
  fire for either of the other two — three colours, three assertions, one fixture varying only
  `defense_color` against a fixed `charge_color`. **The stated mutation that must go RED**: change
  AC 9's guard from `target.defense_color == player.charge_color` to a colour-blind
  `target.defense_window.is_running` (drop the colour comparison entirely) — this must turn the
  wrong-colour assertion RED, proving the colour check is load-bearing and not merely present. **Two
  further vacuity holes, both of the SAME `5-4` "the pool sat at zero either way" family, are named
  directly on AC 10 and AC 11 above** (the positive-control fixture for "no orb grant", and the
  falling window-consumption mutation) — repeated here only as a pointer so a reviewer scanning Dev
  Notes for the blind-spot pin's full shape finds all three holes named in one place.
- **The fourth path through the landing branch: a DEAD defender cannot negate.** Named on AC 9
  directly — the branch's own `is_alive()` gate precedes the AC 9 colour check, so a dead hero's
  `defense_window` is never consulted regardless of what it holds. Repeated here because the
  window-vs-state argument elsewhere in this document (the `.is_running` gate note below) does not
  itself enumerate this path, and a reader reasoning from that argument alone could miss it.
- **Why the "defense" snapshot key is gated on `.is_running`, not on an `action_state`, unlike
  "telegraph".** `charge_window`'s sibling key is gated on `hero.action_state ==
  ActionState.CHARGING` specifically because `CHARGING` is the ONE state a chargeup ever occupies,
  and gating on the state (rather than the window) is what makes a stale colour unrepresentable by
  construction (`player_state.gd:470-475`'s own reasoning). Mode ③ has NO analogous state — AC 5/AC 6
  (folded) are explicit that casting it never enters one — so there is no action-state to gate on,
  and the window's own `.is_running` flag is the only honest gate. This is not a weaker guarantee:
  the window goes non-running on EVERY path that ends it (natural expiry — R-A's second clause,
  covered by Live Smoke rather than a separate AC, see the cut window-expiry AC noted below;
  consumption on a successful defense, AC 10; the debug reset, AC 12) with no fifth path left uncovered beyond the
  dead-defender path named above, so a stale colour is exactly as unrepresentable as the telegraph's
  is — by a different mechanism, because there is a different shape underneath it. State this
  explicitly in Completion Notes; do not silently copy the `CHARGING` gate onto a state this story
  does not create.
- **A cut AC: "a window that expires with no landing simply ends" delivers nothing new.** The
  original story numbered this as its own AC (R-A's second clause); the gate found it merely restates
  `TimingWindow`'s existing contract, already covered observably by Live Smoke item 3, and cut it to
  this note rather than keep it as a numbered claim.
- **`_resolve_charge_landing`'s existing header comment** ("NO BLOCK, NO DEFLECT, NO ARC... The
  colour-matched answer is `5-5`'s", `match_state.gd:2534-2536`) is this story's own forward
  reference resolving. Update it once AC 9-11 land so it stops reading as still-open.
- **AC 13's signal reuse is a NAMED trade-off, not a free lunch.** `deflect_landed` is now shared by
  THREE conceptually distinct mechanisms (melee block-timing parry, a unit's melee swing parried, and
  now a card-cast colour-matched negation of an unblockable) under one name that literally says
  "deflect." The alternative — a new, more precisely named signal — was refused because the
  observation seam family is explicitly locked at nine and the payload shape is otherwise identical;
  if a future story finds the conflation genuinely confusing (e.g. a consumer that needs to
  distinguish WHICH kind of negation happened), that is a fresh finding for that story, not a defect
  this one leaves behind silently — name the trade-off in Completion Notes rather than letting it
  look incidental.
- **The tint answers the privacy objection rather than avoiding it.** The negation ALREADY reveals
  the answered colour deductively — only a matching colour negates, so the attacker learns it the
  instant the attack vanishes, tint or no tint. The AC 13 tint reveals nothing the attacker could not
  already infer; it only stops the cue from lying that an ordinary, colour-blind parry happened.
- **Do not conflate AC 11's "wrong colour does not consume the window" with AC 10's "same colour
  consumes it."** They read as one sentence in R-A/R-B and are two separate rungs of the SAME
  landing-branch logic with different outcomes — name them separately in Completion Notes, the
  `5-2/R8`/`5-4` "two findings, named separately" discipline applied here to two branches of one `if`.

### Project Structure Notes

- Touched files (dev pass to confirm exhaustively): `src/state/enums.gd` (no edit — `ModeKind`
  already sized), `src/state/match_state.gd` (`_resolve_card_action`'s new `DEFENSE` arm AC 1, the
  new `_resolve_defense_cast` AC 3-8, the two new `p1.defense_window.tick()`/
  `p2.defense_window.tick()` lines at step 2 beside `charge_window.tick()` AC 2, the landing intercept
  inside `_resolve_charge_landing` AC 9-11, the `_reset_player` fourth exception AC 12, the widened
  `deflect_landed` signal declaration and its reused `.emit.bind(slot, opposing_slot, color)` call
  AC 13), `src/state/player_state.gd` (`defense_window`/`defense_color` fields AC 2, the new
  `"defense"` `to_snapshot()` key AC 16), `src/state/resources/balance_config.gd`
  (`defense_stamina_cost`, `defense_window_seconds` AC 6/AC 14), `src/state/timing/balance_ticks.gd`
  (`defense_window_ticks` conversion AC 14), `data/balance/balance_config.tres` (the two authored
  values), `src/actors/hero/telegraph_controller.gd` (`on_deflect_landed`'s widened signature and the
  colour-tint branch, AC 13), `src/controllers/keyboard_controller.gd` (`_cast_defense` field, the
  `p2`-only `InputMap.has_action` guarded branch, above and mutually exclusive with confirm, AC 15),
  `project.godot` (the new `p2_cast_defense` Input Map action, key `L`, AC 15 — review the diff, no
  other entries move).
- Test files: `test/state/test_unblockable_defense.gd` (new — AC 1-12, 14, 16, likely; see Open
  Questions), `test/state/test_card_play.gd` (`REACHABLE_MODES` widened, the renamed reachable-set
  test, AC 1), `test/state/test_data_resources.gd` (`E1_BALANCE_FIELDS` gains the two new field
  names, AC 14), `test/state/test_balance_authoring.gd` (bespoke `> 0` bounds for both new fields,
  AC 14), `test/state/test_balance_config.gd` — referenced, NOT edited (AC 14's finding that its
  hand-written conversion literal is already non-exhaustive), `test/state/test_architecture_invariants.gd`
  — referenced, NOT edited (AC 13's negative proof that the nine-member seam set is unchanged),
  `test/state/test_replay_identity.gd` (REQUIRED edit — `defense_window`/`defense_color` join the
  `HASHED` bucket beside `player_state.charge_window`/`player_state.charge_color`, on the identical
  argument: both cross ticks, both decide an outcome, both reach the hash through one `PlayerState
  to_snapshot()` key; `UNHASHED_CROSS_TICK_MEMBERS` stays at THREE — its own `_declared_members` regex
  scans every `^var` in `player_state.gd`, so leaving the two new fields unclassified fails the
  zero-`unclassified` assertion), `test/state/test_draw_delay_and_reshuffle.gd`
  (`EXPECTED_PLAYER_SNAPSHOT_KEYS` gains `"defense"`, AC 16), `test/state/test_card_observation.gd`
  (its own expected key list gains `"defense"` AND its size assertion moves 29 → 30, AC 16) — both
  pins are ORDER-SENSITIVE literals, and the new key's sorted position is between `"deck_size"` and
  `"discard_size"`, NOT beside `"telegraph"`.
- No new top-level folder. No new `FeatureFlags` field, no new `HeroState.ActionState` member, no new
  `InputIntent` field.

### Project Context Rules

- **F1** — not implicated: no new `_physics_process`.
- **D3(a)** — implicated only at the Input Map / `KeyboardController` layer (AC 15); `Input.*` stays
  read exclusively under `src/controllers/`.
- **D3(b)/A2** — not implicated: the landing intercept (AC 9) and cast (AC 3-8) are pure state reads/
  writes and injected-flag/balance reads, no RNG/Time/OS/Engine.
- Docs and code never share a commit; commits are pure ASCII via `git commit -F <tempfile outside the
  repo>`; shell is PowerShell 5.1 (no `&&`); trailer `Co-Authored-By: Claude Opus 4.8
  <noreply@anthropic.com>`.
- Story tier: Tier A — full gate + review + live smoke ritual (touches `src/state/`, the golden, and
  determinism; the golden clause applies regardless of how small the change feels, per
  `docs/project-context.md`'s Story tiers section).

### References

- [Source: src/state/enums.gd:9-27] — `Enums.CardColor`/`Enums.ModeKind`, the ordinal measurement
  (superseded item 2) and the declaration-order contract AC 1 relies on.
- [Source: src/state/hero_state.gd:27,104-111,190-198,365-370] — `ActionState`, the eight
  `TimingWindow` fields (no `defense` among them, superseded item 1), `set_action_state`'s bare
  transition, `enter_block`'s deflect-window shape (untouched by this story).
- [Source: src/state/player_state.gd:163-190,216-218,460-485] — `charge_window`/`charge_color`'s
  full precedent: seating rationale, construction, the `"telegraph"` snapshot key and its
  action-state gate (Dev Notes' contrast with AC 16's `.is_running` gate).
- [Source: src/state/match_state.gd:2222-2243] — `_resolve_card_action`'s dispatch and the guarded
  stub, AC 1's exact edit site.
- [Source: src/state/match_state.gd:2380-2409] — `REASON_UNBLOCKABLE_COMMITTED` and
  `_unblockable_refusal_reason`, the ONE `CHARGING` state-gate AC 4 reuses for mode ③.
- [Source: src/state/match_state.gd:2450-2509] — `_resolve_unblockable_cast` in full, the shape
  AC 3-8 mirror.
- [Source: src/state/match_state.gd:2511-2609] — `_resolve_charge_landing` and `_grant_landing_orbs`
  in full, the exact rung order AC 9-11 intercept.
- [Source: src/state/match_state.gd:388-389] — the step-2 tick seat AC 2's new lines join.
- [Source: src/state/match_state.gd:1406-1418] — the melee `deflect_landed` emit site (measured: ONE
  existing site, not two), the payload shape AC 13 widens.
- [Source: src/state/match_state.gd:3225-3267] — `_reset_player` in full, the AC 12 fourth exception
  and the three it joins (units board FIRST — dedupe/projectiles under the same exception, orbs
  THIRD, chargeup SECOND).
- [Source: src/state/hero_state.gd:27,44,51-90,306-326] — `ActionState`, `TRANSITION_TABLE`'s absent
  `CHARGING` row and `transition_row()`'s own comment ("no table row -> accepts nothing"), the basis
  of Open Questions' measured swing/roll/block finding.
- [Source: src/main/match_runner.gd:849-850,764-770] — `connect_deflect_landed` (its wrapper
  signature unaffected by widening the signal it wraps), and `_make_controller`'s
  `KEYBOARD_P1`/`KEYBOARD_P2` mapping, the AC 15 flip mechanism.
- [Source: src/actors/hero/telegraph_controller.gd:216-229] — `on_deflect_landed`, the cue AC 13
  widens with a colour-tint branch.
- [Source: src/controllers/keyboard_controller.gd:1-153] — the full arm-then-confirm scheme, the
  `_cast_unblockable`/`p1`-only precedent AC 15's `p2_cast_defense` mirrors.
- [Source: project.godot:117-178] — the measured current P1/P2 Input Map action set (superseded
  item / AC 15's premise).
- [Source: src/state/resources/balance_config.gd:296-341] — the `unblockable_*` field family and the
  `Orbs` group, the naming precedent AC 14's two new fields follow.
- [Source: src/state/resources/feature_flags.gd:15-21] — the four independent E4-E6 flags, confirming
  no fifth is needed (AC 3).
- [Source: src/state/timing/balance_ticks.gd:109-123] — the seconds-to-ticks conversion family
  AC 14's `defense_window_ticks` joins.
- [Source: test/state/test_card_play.gd:233-296] — `REACHABLE_MODES`, `test_only_shipped_modes_are_
  reachable`, and the test AC 1 renames.
- [Source: test/state/test_balance_authoring.gd:86-138] — the bespoke `> 0` bound precedent AC 14
  follows for both new fields.
- [Source: test/state/test_data_resources.gd:33,131-183] — `E1_BALANCE_FIELDS` and the reflective
  `*_seconds`-to-`*_ticks` probe, AC 14's two obligations.
- [Source: test/state/test_balance_config.gd:46-71] — `test_conversion_covers_every_seconds_field`'s
  hand-written literal, measured already missing `unblockable_chargeup_seconds` — AC 14's "no forced
  edit" finding.
- [Source: test/state/test_architecture_invariants.gd:284-311] — `OBSERVATION_SEAMS` and its
  `connect_*`-wrapper-name regex, the nine-member set AC 13 leaves unchanged.
- [Source: test/state/test_block_deflect.gd:98-120,254-258] — existing `deflect_landed` consumers,
  confirming no test asserts an exclusive melee-only count that AC 13's reuse would break.
- [Source: test/state/test_replay_identity.gd:98-192,463-498] — the `HASHED`/`UNHASHED_CROSS_TICK`
  buckets and the `charge_window`/`charge_color` HASHED precedent AC 16's edit follows.
- [Source: test/state/test_draw_delay_and_reshuffle.gd:62-82,358-364] —
  `EXPECTED_PLAYER_SNAPSHOT_KEYS`, the sorted-position pin AC 16 edits.
- [Source: test/state/test_card_observation.gd:281,303] — the sibling expected-key list and its
  29 → 30 size assertion, AC 16 edits both.
- [Source: test/state/test_determinism.gd:286,938-1125] — `_golden_config`/`_golden_flags`/the
  fixture's cast content, the basis of AC 16's Golden Prediction.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8738-8743] —
  `5-2/R17` in full, the ruling this story's AC 5 gives its first real test.
- [Source: docs/implementation-artifacts/5-4-orbs.md] — the Tier A ritual shape, the reset-exception
  naming discipline, the observation-seam-reuse precedent, and the `_end_round` non-clear reasoning
  this story applies a second time.

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-09-06 | Story authored via gds-create-story, against baseline `c62fb36` | Claude Opus 4.8 |
| 2026-09-06 | Gate fix pass: applied the new CHARGING-refusal operator ruling (AC 4); corrected AC 5's `set_action_state` scope to BLOCKING-only and folded the old AC 6 negative claim into it; cut the old AC 13 (window-expiry restatement) and AC 15's smoke-duplicate tail; widened `deflect_landed` with a colour argument (AC 13); added the positive-control and falling-mutation blind-spot pins (AC 10/AC 11); corrected the reset-exception ordinal to fourth (AC 12); added the required `test_replay_identity.gd`/snapshot-key-set edits; renumbered AC 1-16 with no stale cross-references; promoted to ready-for-dev | Claude Opus 4.8 |
