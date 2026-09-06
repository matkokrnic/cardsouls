---
baseline_commit: a492bdacc5e6781813a9ad2f58e5befafb60ed95
---

# Story 5.4: Orbs

Status: review

## What this story supersedes

`decision-log.md:8197-8198` (Session 2026-09, E5 planning) assigns `5-4-orbs` Tier A, notes
`OrbPool` "enters `to_snapshot()`" as if that were this story's own act, and carries forward
`4-5` D1 as "forced by that story's own `unblockable`/`orbs` flag-matrix split"
(`decision-log.md:8214`). Measured against the repo rather than assumed:

1. **`OrbPool` is ALREADY IN `to_snapshot()`, and has been since before this story.**
   `player_state.gd:36,209,240` construct and expose it unconditionally; `orb_pool.gd`'s own
   header calls it a "D1 economy pool... RESERVED / flag-off until E5 — the RPS grant/spend
   machinery is deferred, but the storage exists now so E5 wiring is trivial." `test_replay_
   identity.gd:119` already classifies `player_state.orbs` HASHED. **This story adds NO new
   snapshot key.** It wires a grant path INTO an existing, already-hashed, resting-at-zero
   container. `decision-log.md:8197`'s "`OrbPool` enters `to_snapshot()`" line is therefore
   corrected here rather than carried forward uncritically — see Golden Prediction.
2. **The `4-5` D1 flag-matrix split is ALREADY BUILT, on the SPEND side.**
   `feature_flags.gd:17` declares `orbs: bool = false` as its OWN flag, independent of
   `unblockable` (`:16`); `cast_evaluator.gd:76-105`'s `_orbs_affordable` already reads
   `flags.orbs` (not `flags.unblockable`) to decide whether an authored orb cost degrades to
   free (E6's graceful-degradation contract, already live and already tested, `orb_costs`
   just empty on every authored card today). **The D1 finding is not "build a flag matrix" —
   it already exists.** This story's job is the missing GRANT half: gate the new orb-earning
   rule on `flags.orbs`, the SAME flag the spend side already reads, so the matrix the D1
   finding named is symmetric rather than half-real. `unblockable` gates whether mode ②
   exists at all; `orbs` gates whether landing one pays out. Four real combinations, no code
   branch — see AC 6.
3. **`epics.md:151`'s "per-color storage (no cap)" is SUPERSEDED, operator-decided, by this
   story's own scope (matching `5-2/R10`'s precedent for overriding an epics.md line by
   named operator ruling).** The maximum this story adds (AC 9) is a NEW authored bound this
   line did not anticipate. Recorded here as the supersession; not a decision-log edit (docs
   and code never share a commit, and this file is the story record, not the log).
4. **`epics.md:150`'s three-tier ladder ("no-answer/wrong-color -> full dmg + attacker orb")
   is NOT yet reachable — 5-5/5-6 do not exist yet.** This story treats every landed
   unblockable hit as that ladder's "no-answer" branch, the ONLY branch reachable before a
   defense exists, exactly as `5-2`'s Ruling 2 shipped one fixed damage value for all three
   colours ahead of `5-6`'s tiering. This is sequencing, not a contradiction of the GDD.

## Story

As the operator implementing the RGB read exchange's payout half,
I want a landed unblockable hit to grant the attacker orbs of the spent card's colour,
immediately and from the same data-driven economy path that already grants mana on a melee
hit, clamped at an authored per-colour maximum and cleared with everything else that resets
at a round boundary,
so that `5-5`/`5-6` have real earned orbs to answer against and consume, the `orbs` flag
degrades gracefully exactly as its `cast_evaluator.gd` spend-side twin already does, and the
owning player (never the opponent) can see their own count and a shared earn cue confirms it
landed.

## Acceptance Criteria

**The economy path (`match_state.gd:2545` `_resolve_charge_landing`, `economy_evaluator.gd`)**

1. **The grant is computed by `EconomyEvaluator.amount_for`, the SAME pure evaluator
   `_generate_mana` already calls (`match_state.gd:1934-1937`) — no second evaluator, no
   inline formula.** `EconomyEvaluator` gains a new resource constant `ORBS := &"orbs"`
   beside the existing `MANA` (`:34`), and a new source constant
   `SOURCE_UNBLOCKABLE_LANDING := &"unblockable_landing"` beside the existing three
   (`:38-47`), on the file's own established naming convention. A regression test proves the
   grant path never calls `CastEvaluator._orbs_affordable` and that evaluator's own existing
   tests stay green unedited (the checkable residue of the spend-side non-goal, AC 21's
   old text folded here rather than kept as its own AC — see Non-Goals).
2. **A new authored rule, `data/economy/unblockable_landing.tres`, joins the
   `melee_hit.tres`/`mana_accelerator.tres` family.** The load-bearing half, spelled out
   here because it is this AC's whole point and closes the D1 flag-matrix (see "What this
   story supersedes" item 2): `source = &"unblockable_landing"`, `resource = &"orbs"`,
   `required_flag = &"orbs"`. The remaining field-by-field spelling (`amount_domain`,
   `amount_field`, matching `melee_hit.tres`'s own per-event `BALANCE` domain shape) is the
   dev pass's business, not re-litigated here. `EconomyEvaluator.load_rules`'s directory scan
   picks the new `.tres` up with no code change at the loader (the `mana_accelerator.tres`
   precedent's own header: "a new `.tres` in `data/economy/` and NO code change here" — true
   here for loading, not for the call site, exactly as it was half-true there).
3. **A new authored `BalanceConfig` field, `unblockable_orb_grant: int` (provisional `1`),
   joins the `unblockable_*` family (`balance_config.gd:300-313`) beside
   `unblockable_damage_percent_of_max_hp`.** It is the per-event GRANT amount; it carries no
   per-colour scaling (Non-Goals) — one value for RED, BLUE and GREEN alike, `5-2` Ruling 2's
   fixed-damage precedent applied to the payout side.
4. **The grant is read and applied ONLY inside `_resolve_charge_landing`'s landed branch**
   (`match_state.gd:2548`, `_charge_reach[slot] == CONTACT_CHARGE_REACH_INSIDE and
   target.hero.is_alive()`), immediately after the damage application and before the
   unconditional `set_action_state(IDLE)` exit (`:2560`). **No orb evaluation runs at cast**
   — `5-2/R2`'s "no mana or orb evaluation runs at all" exclusion on the cast path
   (`match_state.gd:94-99` AC 5 of `5-2`) is RE-PROVEN, not merely inherited: this story
   gives that exclusion its first real consumer to be exclusive OF. **The float-to-int
   conversion happens ONCE, at this landing seat, via `roundi`** — `EconomyEvaluator.
   amount_for` returns `float`, `OrbPool` stores `int`. `roundi` is named explicitly (not
   `int()`/truncation) and why: the summed float of authored ints is exact at these
   magnitudes today, but `roundi` avoids a silent truncation if a second `orbs` rule is ever
   authored and the sum stops being a whole number. Negative results are impossible (every
   authored `orbs` rule's amount is non-negative) and are therefore not guarded for.
5. **The colour credited is `player.charge_color`** (the attacker's own spent-card colour,
   already resident from the cast, `player_state.gd:185`), **read at the landing seat, never
   recomputed.** Guarded against `PlayerState.NO_TELEGRAPH_COLOR` (`-1`) exactly as every
   other defense-in-depth branch in this file is guarded against its own unreachable case
   (`_resolve_charge_landing`'s own header names this family): a landing whose colour reads
   as the sentinel grants NOTHING rather than crediting an invented colour. This mirrors the
   EXISTING unreachable-in-live-play comment at `match_state.gd:2490-2494` for the identical
   sentinel case at cast time, one recorded family, not two.
6. **Zero orbs when the flag is closed, measured behaviourally, not merely by code
   inspection.** With `flags.orbs == false`, a landed hit still deals full damage (AC's
   pre-existing behaviour, untouched) and credits **zero** orbs — `EconomyEvaluator.
   _flag_open` (`:110-116`) returns closed and `amount_for` sums to `0.0` over the one
   matching rule, with no second gate written at the call site (the `melee_mana_generation`
   precedent verbatim, `economy_evaluator.gd:105-109`'s own stated doctrine: "a faucet that
   cannot be verified open stays shut," never a duplicated check downstream). Note AC 14
   ships the shipped default as `orbs == true`; this AC is proven with the flag forced
   closed regardless of the shipped default.
7. **`OrbPool.add` is called with a strictly positive amount only** — a `0` grant (flag
   closed, or an authored `unblockable_orb_grant` of `0`) calls neither `add` nor emits
   `orbs_changed`, so a closed-flag landing produces no observable orb event at all. (This is
   a caller-side guard, distinct from `add`'s own internal no-op-on-no-change short circuit,
   AC 8.)

**The clamp (`orb_pool.gd`)**

8. **`OrbPool` gains an authored per-colour MAXIMUM, on the `ManaPool._maximum` precedent,
   with a sentinel for the genuinely unbounded pre-injection state** (`mana_pool.gd:9-17`
   adapted, not copied verbatim): a new `_max: int` field defaulting to `-1` at
   construction — the same sentinel family as `PlayerState.NO_TELEGRAPH_COLOR` (`-1`, AC 5):
   `-1` means "no bound," not zero. `add(color, amount)` clamps via
   `clampi(_x + amount, 0, _max)` per colour INDEPENDENTLY **only when `_max >= 0`**; a
   pre-injection `OrbPool` (`_max == -1`) is genuinely UNBOUNDED, not inert —
   `test/state/test_economy_and_hero.gd:77-79` and `test/state/test_cast_evaluator.gd:110-
   119` already exercise this real pre-injection behaviour and are **NOT edited by this
   story**; they document a fact about the pre-injection container, not a defect to fix. A
   `set_maximum(max_count: int)` method re-clamps every colour's CURRENT count into the new
   bound and re-signals if any colour actually changed (the `ManaPool.set_maximum -> add(0.0)`
   re-clamp idiom, `:63-65`); injection (AC 10) always supplies the real, non-negative bound,
   so `_max` reads `-1` only before the very first injection. **`add` also gains the
   no-op-on-no-change short circuit**: it computes the clamped value and returns WITHOUT
   touching state or emitting `orbs_changed` when that value equals the colour's current
   count, mirroring `ManaPool.add`'s own short circuit (`mana_pool.gd:22-23`) exactly.
   Without it, `set_maximum`'s per-colour re-clamp call would emit up to three spurious
   `orbs_changed` events per player per injection into the new HUD channel (AC 15) — silently
   wrong the moment that channel exists, not merely untidy.
9. **A new authored `BalanceConfig` field, `max_orbs_per_color: int` (provisional `5`),
   joins the `max_hp` / `max_stamina` / `max_mana` naming family** (`balance_config.gd:15,
   19,68`) — a generic cap on the CONTAINER, not an `unblockable_*` field, since `5-5`/`5-6`
   will read and clamp the same pool later.
10. **`_apply_balance_to_player` (`match_state.gd:3066-3080`) injects the new maximum on
    EVERY injection, including the first** (`player.orbs.set_maximum(config.
    max_orbs_per_color)`), the `mana.set_maximum` line directly above it as the shape —
    **never a refill.** Orbs, like mana, start at their PRE-injection value re-clamped into
    the new bound, never reset to a fresh maximum the way stamina refills; a match start
    still yields EMPTY orbs because a fresh `PlayerState` constructs `OrbPool` at all-zero
    (`player_state.gd:209`), not because injection zeroes it.
11. **The clamp holds under repeated landings**: a second, third, ... landing against a
    colour already AT the authored maximum grants that colour nothing further (AC 8's
    `add`-level no-op-on-no-change fires here — `add` computes the same clamped value,
    changes nothing, signals nothing), while a DIFFERENT colour still below its own maximum
    is unaffected by the first colour's ceiling (the independent-per-colour clamp, AC 8).
12. **`OrbPool.to_snapshot()` is UNCHANGED — a NEGATIVE AC.** It returns exactly
    `{red, blue, green}`; the new `_max` is authored config, not state, and never enters the
    hash. This DIVERGES from `ManaPool.to_snapshot()`, which DOES carry `"maximum"` — a
    deliberate divergence, not an oversight: mana's maximum is itself injectable/reloadable
    content the replay must reproduce identically, while orbs' maximum here is a fixed
    authored constant with no reload path this story adds. Proved by the dev pass, not
    merely asserted: stage `"maximum": _max` into `to_snapshot()`, run the suite, confirm the
    golden MOVES, then restore `orb_pool.gd` by copying the pre-mutation file back with a
    SHA-256 check — never `git checkout`, which would wipe the whole uncommitted pass.

**Reset (the two existing per-player reset seats, `match_state.gd:3162-3204`,
`match_state.gd:3103-3106`)**

13. **Orbs clear to zero at the debug reset (`_reset_player`, reached from
    `_apply_debug_reset` on the `debug_reset` intent, `:330-331`), joining the units board /
    unit dedupe / projectile board / mode-② chargeup as a named exception to the reset's
    "NOTHING else" contract** (`4-1/R5` for the board, the `5-3` fix pass for the
    chargeup — this story's `player.orbs.reset_all()` call is the pool's OWN existing
    `reset_all()` method, `orb_pool.gd:39-45`, authored for E6's Pitch Effect activation and
    reused here rather than duplicated). Seated in `_reset_player` beside those four, in the
    same per-player helper, for the same reason: this is per-player state and the debug
    reset is the seat that already clears everything else that must not survive a round
    boundary. (`_end_round` gains no matching clear — see the Dev Notes finding below; that
    reasoning is kept as a measured finding, not as its own AC, since it asserts nothing new
    to test.)

**The flag (`data/feature_flags.tres`)**

14. **`data/feature_flags.tres` opens `orbs = true`**, on the precedent of turning a flag on
    once its own mechanism ships (`unblockable`/minions/totems). A new pin asserts the
    authored resource loads with `orbs == true`. Measured blast radius, stated not assumed:
    no authored card carries an `orb_costs` entry, already pinned at
    `test/state/test_card_authoring.gd:186` — opening the flag changes nothing for
    `CastEvaluator._orbs_affordable` (Non-Goals); only the grant path (AC 1-11) newly fires
    in real play.

**Observation (`match_runner.gd`, the ninth seam)**

15. **ONE new observation channel — a NINTH seam, not a second `MatchState` direct-connect.**
    `MatchRunner` gains `connect_orbs_changed(slot, callback)`, a line-for-line clone of
    `connect_mana_changed` (`match_runner.gd:1489-1494`) including prime-on-connect (the
    callback fires immediately on connect with the CURRENT three counts, not only on the
    next change). A pool-owned source signal (`OrbPool.orbs_changed`) is already the norm
    for this shape — mana and stamina both work this way — and the story's earlier worry
    about that shape is wrong; the Open Question naming the wiring shape is CLOSED by this
    ruling, not carried forward. No `MatchState.orb_granted` signal is built. This is its
    own AC because it moves a pinned count: `OBSERVATION_SEAMS` in
    `test/state/test_architecture_invariants.gd:284-288` and the "FROZEN AT EIGHT" failure
    text at `:311-313` both move from eight to nine as part of this story.
    `docs/game-architecture.md:371-372`'s "there are now eight" line is **NOT edited by this
    story** — it goes to the ARCH AMENDMENT QUEUE for the E5 close-out flush, joining the
    existing member from `5-3` (the `MatchState` direct-connect left unresolved there); the
    dev pass must say so plainly in Dev Notes, nothing disappears quietly. A second
    `MatchState` direct-connect is explicitly REFUSED as an alternative shape — `5-3` left
    that form unresolved in the queue and it must not be settled by accident here. Both the
    HUD counter (AC 18-20) and the earn cue (AC 17) consume THIS SAME channel; the earn cue
    fires on increase, no separate signal is added for it.
16. **NEW: pin the prime-on-connect false-fire.** The seam (AC 15) primes on connect with the
    resting `(0,0,0)` count. A flash cue derived naively as "the seam fired, so flash" — reacting
    to ANY `orbs_changed` payload rather than only to an INCREASE over the previous triple —
    would misfire at match start, on the priming call itself. An integration test under
    `test/integration/` (the `test_charge_telegraph_dispatch_live.gd` family) proves NO flash
    fires on the priming emission and a flash DOES fire on a real subsequent increase, with a
    mutation that makes the cue fire on any change rather than on an increase driving the
    priming case RED. (A weaker mutation — deleting the priming guard but leaving the
    "increase over the previous triple" check in place — does NOT drive this test red, because
    the previous triple then zero-initialises to the pool's own resting `(0,0,0)` and the guard's
    marginal value over that zero baseline is unreachable in the shipped composition; that
    finding is recorded, not re-litigated, in Completion Notes.) This is runtime composition of
    `MatchRunner` + `TelegraphController`; no state-level test can satisfy this AC.

**Presentation — the shared earn cue (`telegraph_controller.gd`, the `5-3` ChargeMarker
pattern)**

17. **The earn cue is a BEHAVIOURAL requirement only**: a one-shot above-head flash, in the
    spent colour, on the SAME one-shot idiom the existing hit flash already uses
    (`on_hit_landed`'s shape — show, interrupt any running tween, hold briefly, hide) — NOT
    the persistent toggle-on-state-entry idiom `ChargeMarker` uses, because the earn cue is a
    one-shot EVENT, not an ongoing state. It fires on BOTH players' screens because it is a
    WORLD-SPACE cue on the attacker's own hero actor, visible in both split-screen viewports
    exactly as `ChargeMarker` itself already is. No node names, no tween call order, no
    material helper are specified here — that is the dev pass's business, following the
    file's own existing shape family.

**HUD — the owner's own count (`hud_root.gd`, per-slot bind pattern)**

18. **Each player's HUD half shows that player's own current orb counts** (the three colours,
    or a fused representation — dev's call, named in Completion Notes), in the ALREADY
    RESERVED periphery region `hud_root.gd:35,44` names ("the three ORB totals... sit in the
    top corners," "The orb counters... stay reserved (E4/E5)") — this story is what fills
    that reservation, not a new layout decision.
19. **Reading the opponent's count is structurally impossible**, the `2-4/R7` /
    `3-6/R7` own-slot-only doctrine applied to orbs: the runner binds each `HudRoot` instance
    to ONLY its own slot's data at construction via the AC 15 `connect_orbs_changed(slot,
    ...)` seam, exactly as the three existing economy seams and the eighth card seam are
    bound (`match_runner.gd:371-378`) — no slot argument threads through to the HUD, no
    shared handle, no read of the opponent's `PlayerState`.
20. **The displayed count updates live as orbs are earned (via the AC 15 seam) and clears to
    zero on both the round-boundary reset (AC 13) and match start**, without polling
    (`hud_root.gd`'s own documented invariant, `:8-11`: "NEVER polls, NEVER writes, NEVER
    holds a MatchState handle").

## Non-Goals

- **No spend path** (regression-proven inside AC 1, not its own AC) — Mode ④ (Pitch) is
  `E6`. `CastEvaluator._orbs_affordable` (`cast_evaluator.gd:92-105`) is UNCHANGED and
  untouched by this story; it already reads `orbs.get_count` and `flags.orbs` for E6's future
  Pitch cost, and this story's grant path does not call it, extend it, or duplicate its flag
  read.
- **No mode ④ wiring** — no card gains `orb_costs`; no new targeting or cast dispatch arm is
  added. `CardCastCondition.orb_costs` stays authored empty on every shipped card, exactly as
  `cast_evaluator.gd:82-84`'s own comment already documents as "currently a no-op on real
  content."
- **No world pickup, no positional orb state** — the grant is a pure economy-path credit
  (AC 1-7), never a spawned object, never a position, never a `src/state/` coordinate.
- **No per-colour scaling of the GRANT AMOUNT** — `5-6` owns tiering; `unblockable_orb_grant`
  is one value for all three colours (AC 3), the `5-2` Ruling 2 precedent applied to payout.
- **No telegraph changes** — `5-3`'s chargeup shape/sound is untouched; the AC 17 earn cue is
  a NEW, separate, one-shot event fired at LANDING, not a change to the ongoing CHARGING cue.
- **The observation seam is DECIDED, not open** — AC 15 adds the ninth `connect_orbs_changed`
  seam; see Open Questions for what genuinely remains open (HUD display shape, test file
  placement).
- **The three-tier ladder itself** — `5-5`/`5-6`. Every landed hit in this story is that
  ladder's "no-answer" branch by default, since no defense exists yet (see "What this story
  supersedes" item 4).

## Golden Prediction

**PREDICTION: THE GOLDEN DOES NOT MOVE.** This corrects the task brief's "MOVED (new snapshot
fields)" assumption — see "What this story supersedes" item 1: `orbs` is ALREADY a snapshot
key (`player_state.gd:240`), added before this story and already classified HASHED
(`test_replay_identity.gd:119`), so there is no new key for this story to add. The measured
reason the golden's VALUE also does not move: the golden fixture records no mode ② cast at
all (`5-2`'s Dev Notes, reconfirmed here — no `ModeKind.UNBLOCKABLE` cast appears in
`test_determinism.gd`'s fixture, only a prose comment referencing the dispatch arm at
`:706`), and the fixture's own in-test `FeatureFlags` leaves BOTH `unblockable` and `orbs`
false — so the new landing-seat grant code (AC 1-11) is never entered by the hashed replay,
regardless of what `data/feature_flags.tres` ships (AC 14 opens the SHIPPED default; the
golden's own fixture builds its own flags in-test and never reads that file). This is the
identical "5-1a shape" `5-2`'s own telegraph key landed in: new machinery, unreached by the
fixture, key unaffected because the key was never new to begin with.

Measure `bash test/run_all.sh` before and after regardless; if the golden moves for ANY
reason, that is a finding, not a pass, and no re-baseline is pre-authorised by this story.

The dev pass owes two REVERSE measurements, proving the prediction is falsifiable rather than
assumed:
(a) stage `orbs = true` into the golden's OWN in-test flag builder and prove the hash still
reads `dc2c9ffa` (proves the fixture truly never casts mode ②, independent of the flag);
(b) stage the AC 12 forbidden key — `"maximum": _max` in `to_snapshot()` — and prove the hash
MOVES (proves the golden is actually sensitive to a real snapshot-shape change, so (a)'s
non-move is not a golden that silently stopped hashing anything). Any OTHER movement is a
defect, not a re-baseline.

**`FORMAT_VERSION` prediction: NO BUMP.** No new public `MatchState` intake or injection seam
is added (the `mana_accelerator.tres` precedent: a new rule `.tres` is picked up by the
existing directory scan with no new call surface for the RECORDER to track), no new contact
kind, no new intent field. `RecordFile.REQUIRED_KEYS` and `IntentRecorder.
EXPECTED_INTAKE_SURFACE` are both predicted unchanged. State the measured answer in
Completion Notes regardless — this is a prediction, not a given.

## Deferred

- **`4-5` D1** — addressed IN THIS STORY, not deferred further: see "What this story
  supersedes" item 2. The grant rule's `required_flag = &"orbs"` is the closing half of the
  flag-matrix split the spend side already had.
- The parked "mana survives reset" finding (`match_state.gd:3150-3152`) is UNCHANGED and
  stays parked; this story does not touch mana's reset behaviour and orbs deliberately does
  NOT follow mana's precedent here (AC 13 clears orbs on reset; mana is not cleared on reset
  at all) — a NAMED divergence between the two pools' reset behaviour, not an inconsistency:
  orbs are a per-round stake in the RPS exchange (GDD `epics.md:151`'s "all-color-reset hook"
  language anticipates exactly this), mana is a persistent flywheel resource. If a future
  story wants them to agree, that is a fresh operator ruling, not a bug this story leaves
  behind.

## Live Smoke

1. **Count rises on a landed unblockable, and ONLY then.** A charged, landed hit with `orbs`
   flag open increases the attacker's own-colour count by the authored grant; no other action
   (basic attack, block, roll, a MISSED unblockable, mode ② while `orbs` is closed) moves it.
2. **Clamp holds at the authored maximum.** Repeated landings of the same colour past the cap
   stop increasing that colour; a different colour still climbs.
3. **Count is zero at the start of the next round and after pressing R.** Earn some orbs,
   trigger a round end (kill a hero) or press the debug reset, confirm zero on both players.
4. **The opponent sees the earn cue.** Both split-screen viewports show the above-head flash
   on the attacker's hero at the moment of landing, from either player's screen.
5. **Nothing else in the match changes.** Movement, melee, blocking, rolling, mode ① casting,
   the draw delay, minions, totems, and mode ② damage/reach/rooting all behave exactly as
   before this story — this is a regression smoke for everything except the new grant.
6. **FPS** — no visible frame-rate impact from the new shape node, tween, or per-tick economy
   read (the evaluator call is already per-confirmed-hit cost, not new per-tick cost).

## Live Smoke Results

Operator smoke, 2026-09-06, recorded verbatim in `docs/playtest-log.md`'s "6.9. / 5-4" block.
**Overall verdict: SMOKE PASS, all eight items, no findings.**

1. **Counters present from frame one — PASS.** Both players' orb counters render real zeroes at
   match start, not a placeholder.
2. **No opponent read — PASS.** Each HUD shows only its own player's counts; the opponent's
   counts never leak across.
3. **Earn raises the counter and flashes above the attacker — PASS.** A landed unblockable
   raises the attacker's own-colour count and fires the above-head flash on the attacker's hero,
   visible in both split-screen viewports.
4. **Colour matches — PASS.** The flash and the counter it fills are the same hue as the spent
   card's charge telegraph.
5. **A miss pays nothing — PASS.** An unblockable that misses its target grants no orb and fires
   no cue.
6. **A killing landing pays, and the orbs survive the freeze — PASS.** A landing that kills its
   target still credits the orb, and the grant is visible through the round-over freeze rather
   than being cleared before it displays.
7. **R clears all three with no flash — PASS.** The debug reset zeroes all three colours on both
   players with no earn cue firing on the way down.
8. **FPS stable — PASS.** No visible frame-rate impact from the new shape node, tween, or
   landing-time economy read.

One non-blocking follow-up recorded by the operator: the cards in hand are not yet coloured to
match their card colour — out of this story's scope, left for a later pass.

## Open Questions (left to the gate / dev pass)

- **Fused vs. per-colour HUD display (AC 18).** Three small counters vs. one fused
  presentation — implementation detail, not design, left to the dev pass's layout judgment
  within the already-reserved periphery region.
- **Test file placement** — a new `test_orbs_economy.gd` on the `test_mana_economy.gd`
  sibling precedent for the evaluator-level rule/flag/clamp coverage, vs. extending
  `test_unblockable_initiation.gd` for the landing-integration/reset/cue coverage — likely
  BOTH, split by concern; dev's call, name the choice.

## Dev Notes

- **The `orbs` key already existing is the single most load-bearing fact in this story.**
  Every AC above that touches the golden (see Golden Prediction) or the reset (AC 13, and the
  `_end_round` finding immediately below) reasons from it. Do not re-derive "does adding orbs
  move the golden" from first principles during the dev pass — the answer is already measured
  here as UNMOVED, contingent only on the golden fixture still never casting mode ②;
  re-confirm that premise, don't re-litigate the logic.
- **`_end_round` (`match_state.gd:3103-3106`) gains NO new clear — a measured finding, kept
  here rather than as its own AC because it asserts an absence, not a new behaviour to test.**
  `_end_round` today does exactly two things: mark the loser `DEAD` and emit `round_ended`.
  It clears NOTHING — not HP (which only heals at the NEXT debug reset), not mana (the
  standing "parked mana-survives-reset" finding, `match_state.gd:3150-3152`), not units, not
  the board. There is no precedent anywhere in this file for `_end_round` clearing per-player
  economy state, and this codebase has exactly ONE round-boundary transition mechanism
  today — the debug reset — which is also how "the next round" begins in practice (there is
  no separate automatic round-restart path). Adding a clear inside `_end_round` itself would
  delete the WINNER's freshly-earned orbs the instant the loser dies, before the round-over
  freeze even displays them — a regression against the freeze-survives-until-reset behaviour
  every OTHER piece of round-crossing state already has (the `5-3` fix pass's own words for
  why the frozen round-over telegraph is left alone: "cosmetic... it ends HERE" at the reset,
  not at `_end_round`). **"Nothing carries into the next round" (the scope's own stated
  outcome) is satisfied by AC 13 alone**, because the debug reset IS this codebase's
  round-boundary. If the operator wants orbs to visibly vanish at the moment of death rather
  than survive to be seen during the freeze, that is a NEW round-lifecycle behaviour with no
  precedent anywhere in this file and belongs in front of the operator as its own ruling, not
  silently added here.
- **`_resolve_charge_landing`'s own header (`match_state.gd:2521-2537`) already documents
  "no orb" as a NAMED absence** ("A miss is a miss -- no damage, no orb (`5-4`), no HP change
  on either side") — this story is that citation's own referent. Update that comment's
  framing once the grant lands, so it no longer reads as a still-open forward reference.
- **`EconomyEvaluator`'s own header (`:9-13`) states the PURE/APPLY split as doctrine**: the
  evaluator computes, `MatchState` applies. AC 4's placement (apply inside
  `_resolve_charge_landing`, not inside the evaluator) is not a free choice, it is this
  story's instance of an already-decided architectural constraint.
- **`5-2/R2`'s cast-time exclusion (AC 4) is worth re-reading in full** before assuming "no
  orb evaluation at cast" is this story's own new rule — it is a FIVE-STORIES-OLD ruling this
  story finally gives a real body to enforce against, not a new constraint.
- **Do not conflate the AC 13 debug-reset clear with the `_end_round` non-clear finding
  above.** They read as one sentence in the task brief ("cleared at round end and on debug
  reset") and are TWO SEPARATE FINDINGS with different reasoning — name them separately in
  Completion Notes, the `5-2/R8` "two pin edits, named separately" discipline applied to two
  reset findings instead of two test edits.
- **`OrbPool.reset_all()` already exists and is reused, not reinvented** (AC 13) — it was
  authored for `E6`'s Pitch-activation reset and its own doctring comment ("Activating a
  Pitch Effect resets ALL three colors to 0, not just the spent color") describes a DIFFERENT
  call site than this story's, but the same method serves both without modification.
- **The docs/architecture-doc asymmetry is deliberate, name it in Completion Notes**: the
  pinned test count moves from eight to nine (AC 15, `test_architecture_invariants.gd`) in
  this story's own commit, while `docs/game-architecture.md:371-372`'s prose does NOT move
  until the E5 close-out flush. The test is load-bearing and must stay accurate; the prose
  amendment is queued deliberately so multiple E5 stories' amendments land together.
- **When staging the AC 12 non-vacuity mutation (adding `"maximum"` to `to_snapshot()`) or
  the Golden Prediction reverse measurement (b), back up the mutated file to scratch and
  verify its SHA-256 before mutating, and restore by copying the backup back — never
  `git checkout`, which discards the whole uncommitted dev pass, not just the one file.**

### Project Structure Notes

- Touched files (dev pass to confirm exhaustively): `src/state/economy/economy_evaluator.gd`
  (`ORBS`, `SOURCE_UNBLOCKABLE_LANDING` constants, AC 1), `data/economy/unblockable_landing.tres`
  (new rule, AC 2), `src/state/resources/balance_config.gd` (`unblockable_orb_grant`,
  `max_orbs_per_color`, AC 3/9), `data/balance/balance_config.tres` (their authored values),
  `data/feature_flags.tres` (`orbs = true`, AC 14), `src/state/match_state.gd`
  (`_resolve_charge_landing`'s grant call AC 4-7, `_apply_balance_to_player`'s new injection
  line AC 10, `_reset_player`'s new `reset_all()` call AC 13 — no `orb_granted` signal is
  added), `src/state/pools/orb_pool.gd` (`_max` sentinel-defaulted to `-1`, `set_maximum`, the
  clamped and short-circuited `add`, AC 8, `to_snapshot()` left untouched per AC 12),
  `src/main/match_runner.gd` (the new `connect_orbs_changed(slot, callback)` ninth seam AC 15,
  the earn-cue wiring AC 17, and the HUD counter wiring AC 18-20 — all three consumers of the
  same seam), `src/actors/hero/telegraph_controller.gd` (the AC 17 flash-tween handler),
  `src/actors/hero/hero.tscn` (the new `Shapes/OrbFlash` node, sibling of `ChargeMarker`),
  `src/ui/hud/hud_root.gd` (the AC 18 counter display, filling the already-reserved region).
- Test files (in addition to the above): `test/state/test_architecture_invariants.gd`
  (`OBSERVATION_SEAMS` and the "FROZEN AT EIGHT" text move to nine, AC 15), `test/state/
  test_data_resources.gd` (`unblockable_orb_grant` and `max_orbs_per_color` join
  `E1_BALANCE_FIELDS`, AC 3/9), `test/state/test_balance_authoring.gd` (a bespoke authored
  `> 0` bound for each of the two new fields, the `5-2` precedent — an unqualified `>= 0`
  bound passes on the script default and would ship the story invisible), an integration
  test in the `test_charge_telegraph_dispatch_live.gd` family (AC 16), and the placement
  decision from Open Questions (`test_orbs_economy.gd` and/or `test_unblockable_initiation.gd`
  extension) for the remaining AC coverage. `test/state/test_economy_and_hero.gd:77-79` and
  `test/state/test_cast_evaluator.gd:110-119` are explicitly NOT edited (AC 8).
  `test/state/test_card_authoring.gd:186` is referenced, not edited (AC 14).
- **`docs/game-architecture.md:371-372` is NOT edited by this story** — queued for the E5
  close-out flush alongside the existing `5-3` ARCH AMENDMENT QUEUE member. The pinning test
  (`test_architecture_invariants.gd`) IS edited to nine in this story's own commit; the
  prose is not, deliberately (see Dev Notes).
- No new top-level folder.

### Project Context Rules

- **F1** — not implicated: no new `_physics_process`. The grant resolves inside the existing
  `advance()` step-3(a)/step-4 landing seat.
- **D3(a)** — not implicated: no new `Input.*` read.
- **D3(b)/A2** — not implicated: `EconomyEvaluator.amount_for` is already the RNG/Time/OS/
  Engine-free pure-evaluator seat; this story adds a resource/source pair to an existing
  call, not a new kind of call.
- Docs and code never share a commit; commits are pure ASCII via `git commit -F <tempfile
  outside the repo>`; shell is PowerShell 5.1 (no `&&`); trailer `Co-Authored-By: Claude Opus
  4.8 <noreply@anthropic.com>`.
- Story tier: Tier A — full gate + review + live smoke ritual, per `decision-log.md:8197`.

### References

- [Source: decision-log.md:8197-8198,8214] — the story's Tier A slot and the `4-5` D1
  assignment this story closes.
- [Source: epics.md:143-168] — E5 goal, key stories, the three-tier ladder line and the
  "(no cap)" line this story supersedes (item 3 above).
- [Source: src/state/player_state.gd:36,209,240,185,472-484] — `OrbPool` field, construction,
  the existing `orbs` snapshot key, `charge_color`'s residency and clearing contract.
- [Source: src/state/pools/orb_pool.gd] — `OrbPool`'s existing shape: per-colour storage,
  `add`, `reset_all`, `to_snapshot`; the clamp this story adds (AC 8) and the snapshot this
  story does NOT change (AC 12).
- [Source: src/state/pools/mana_pool.gd:9-25,63-65] — the `_maximum`/`set_maximum`/clamped-`add`
  precedent this story's `OrbPool` clamp follows.
- [Source: src/state/pools/mana_pool.gd:22-23] — `ManaPool.add`'s own no-op-on-no-change short
  circuit, the exact precedent AC 8's `add` short circuit mirrors.
- [Source: src/state/economy/economy_evaluator.gd] — the D6 pure evaluator; `MANA`,
  `SOURCE_MELEE_HIT`/`SOURCE_PASSIVE_TICK`/`SOURCE_MANA_ACCELERATOR`, `amount_for`,
  `_flag_open`, `_amount` — the whole mechanism this story's `ORBS`/
  `SOURCE_UNBLOCKABLE_LANDING` join.
- [Source: data/economy/melee_hit.tres, mana_accelerator.tres] — the authored rule shape AC 2
  follows.
- [Source: src/state/economy/cast_evaluator.gd:76-105] — `_orbs_affordable`, the ALREADY-BUILT
  spend-side flag matrix half this story's grant-side rule completes (AC 2, AC 1's regression
  proof, Non-Goals).
- [Source: src/state/resources/feature_flags.gd:15-21] — `unblockable`/`orbs` as two
  independent flags, already declared, already documented as independently toggleable.
- [Source: test/state/test_card_authoring.gd:186] — the pin that no authored card carries
  `orb_costs`, AC 14's measured blast radius.
- [Source: src/state/match_state.gd:2511-2560] — `_resolve_charge_landing` in full, the exact
  seat AC 4-7 add to; its own header's "no orb (`5-4`)" citation this story resolves.
- [Source: src/state/match_state.gd:1934-1950] — `_generate_mana`, the sibling call shape
  AC 1 follows.
- [Source: src/state/match_state.gd:3066-3080] — `_apply_balance_to_player`, the injection
  seat AC 10 joins.
- [Source: src/state/match_state.gd:3103-3106,3135-3204] — `_end_round` and
  `_apply_debug_reset`/`_reset_player` in full, the AC 13 reset finding and the `_end_round`
  Dev Notes finding.
- [Source: test/state/test_replay_identity.gd:116-121] — the HASHED classification `player_
  state.orbs` already carries, the basis of the Golden Prediction's corrected reading.
- [Source: test/state/test_determinism.gd:706] — the fixture's own lack of a mode ② cast,
  the second basis of the Golden Prediction.
- [Source: src/systems/record_file.gd:157] — `FORMAT_VERSION` current value (7), the Golden
  Prediction's `FORMAT_VERSION` baseline.
- [Source: src/actors/hero/telegraph_controller.gd:32-153] — the `ChargeMarker`
  toggle-on-state idiom (`on_action_state_changed`) vs. the `HitFlash` one-shot tween idiom
  (`on_hit_landed`) — AC 17 follows the SECOND, not the first.
- [Source: src/actors/hero/hero.tscn:174-183] — `RollDisc`/`ChargeMarker`'s `Shapes/` sibling
  shape, the node AC 17's `OrbFlash` joins.
- [Source: src/main/match_runner.gd:441-487] — the per-hero wiring loop.
- [Source: src/main/match_runner.gd:1489-1494] — `connect_mana_changed`, the exact shape AC 15's
  `connect_orbs_changed` clones (per-slot guard, prime-on-connect).
- [Source: decision-log.md:8769-8773] — `5-3/R4` itself, the ARCH AMENDMENT QUEUE entry AC 15
  joins rather than duplicates.
- [Source: docs/game-architecture.md:365-398] — the eight-seam registry and D5's signal-timing
  bindings, the family AC 15 grows to nine (test only; prose deferred, see Project Structure
  Notes).
- [Source: test/state/test_architecture_invariants.gd:284-288,311-313] — `OBSERVATION_SEAMS`
  and the "FROZEN AT EIGHT" failure text, both moved to nine by AC 15.
- [Source: test/state/test_economy_and_hero.gd:77-79] and
  [Source: test/state/test_cast_evaluator.gd:110-119] — the real pre-injection `OrbPool`
  behaviour AC 8 leaves unedited.
- [Source: src/ui/hud/hud_root.gd:1-46] — the per-slot bind doctrine (`2-4/R7`) and the
  ALREADY-RESERVED orb-counter region AC 18 fills.
- [Source: src/state/enums.gd:6-9] — `Enums.CardColor { RED, BLUE, GREEN }`, the colour
  vocabulary AC 5's guard and AC 8's per-colour clamp both address.
- [Source: test/state/test_data_resources.gd:87-91] — `E1_BALANCE_FIELDS`'s existing
  `unblockable_*` entries, the list AC 3/AC 9's new fields join.

## Dev Agent Record

### Agent Model Used

Opus 5 (operator-stated).

### Debug Log References

- Before-baseline: `C:\dev\_54-suite-before.txt` — 629 tests, 0 failed, 4809 assertions; 53
  integration files PASS; `ALL TESTS PASSED`. Written 2026-09-06 02:17:44.
- Close-out: `C:\dev\_54-suite-after.txt` — 648 tests, 0 failed, 4893 assertions; 54 integration
  files PASS; `ALL TESTS PASSED`. Written 2026-09-06 02:41:50. Delta 24 min.
- **The close-out suite ran TWICE, and the first run is a real finding, not a retry.** Attempt 1
  read `648 tests, 1 failed` —
  `test_replay_identity.gd::test_unhashed_cross_tick_state_is_exactly_three_members`, on the new
  `orb_pool._max` member being classified into none of the four buckets. That is the AC 11 pin
  working exactly as built (a new `src/state/` member must be bucketed before replay equality stays
  an honest claim). Fixed by classifying `_max` as **INJECTED** — see Completion Notes — and attempt
  2 is the file recorded above. Both attempts are counted; the `PROC/R1` budget was overrun by one
  full-suite run and it is reported rather than absorbed.
- Iteration and every mutation proof ran the AFFECTED TEST FILE ONLY, via a temporary single-file
  runner (`test/run_one_state_test.gd`) created for this pass and **DELETED before the close-out
  run** — `git status --short` shows no residue.

### Completion Notes List

**Golden: UNMOVED, as predicted.** `dc2c9ffa11387e99f47150b90a8449a101104f5a555c7254c14cc8d0d339019b`
before and after, with `test_state_matches_golden` green in both suite runs. The prediction's premise
was re-confirmed rather than re-derived: the fixture still casts no mode ②, so the new landing-seat
grant is never entered. Both reverse measurements were taken (Mutation Table rows a/b): staging
`orbs = true` into `_golden_flags` left the hash at `dc2c9ffa` (so the non-move comes from the
fixture never landing a charge, not from a closed flag), and staging the AC 12 forbidden key MOVED
it to `4cc02623` (so the harness really is sensitive to a snapshot-shape change). No re-baseline.

**`FORMAT_VERSION`: NO BUMP, measured.** `RecordFile.FORMAT_VERSION` stays 7, `REQUIRED_KEYS` and
`IntentRecorder.EXPECTED_INTAKE_SURFACE` are unchanged and untouched. The prediction held for the
stated reason: the new rule `.tres` is picked up by the existing directory scan and adds no call
surface for the recorder, and no new intake, contact kind or intent field ships.

**The two reset findings, named SEPARATELY (the `5-2/R8` discipline applied here).**
1. *The AC 13 debug-reset clear.* `player.orbs.reset_all()` joins the units board / unit dedupe /
   projectile board / mode-② chargeup as the THIRD named exception to the reset's "NOTHING else"
   contract, seated in `_reset_player` beside them, and `_apply_debug_reset`'s header now names it.
   Pinned by `test_the_debug_reset_clears_orbs_on_both_players`.
2. *The `_end_round` NON-clear.* `_end_round` gains nothing, deliberately: a clear there would
   delete the WINNER's freshly-earned orbs at the instant of death, before the round-over freeze
   displays them. This is a different claim with different reasoning, and it is now ASSERTED rather
   than left as prose — `test_orbs_survive_the_round_over_freeze_and_are_cleared_only_at_the_reset`
   drives the kill, checks the orbs survive it, then checks the reset ends them.

**`orb_pool._max` is classified INJECTED, and that is the one asymmetry with `ManaPool`.**
`mana_pool._maximum` sits in `test_replay_identity.gd`'s HASHED bucket because
`ManaPool.to_snapshot()` carries it. AC 12 forbids the orb twin from entering the snapshot, so it
cannot be HASHED — and it is not a FOURTH unhashed cross-tick exclusion either, because it is not
cross-tick state: it is authored config, changed only through `set_maximum`, reached only from
`apply_balance`, which IS a capture channel. `UNHASHED_CROSS_TICK_MEMBERS` stays at THREE.

**The docs/test asymmetry, named as the story asked.** `test_architecture_invariants.gd` moves to
NINE in this pass (`OBSERVATION_SEAMS`, the failure text, and the function name).
**`docs/game-architecture.md:371-372`'s "there are now eight" prose is NOT edited** — it is queued
for the E5 close-out flush, joining `5-3/R4`'s existing ARCH AMENDMENT QUEUE member, so several E5
amendments land together. Nothing disappeared quietly.

**Open Question answers (the story asked for both to be named).**
- *HUD display shape (AC 18): PER-COLOUR, three counters.* Three counts of a three-colour RPS
  resource are three separate reads a player makes, and the reserved footprint has held three panels
  since 2-4 — fusing them would have been a layout change dressed as a fill. Each label is tinted its
  own colour from a presentation-local `HudRoot.ORB_COLORS` (src/ui owns its palette; the HUD loads
  no telegraph resource), matching the hues the charge telegraph and the earn cue use. Digit
  legibility at half-width is an OPERATOR SMOKE surface (`PROC/R8`), not a number this pass may
  declare correct.
- *Test file placement: ONE new `test_orbs_economy.gd`, and `test_unblockable_initiation.gd` is NOT
  edited.* The new file carries every state-level AC (1-13) on its own mode-② fixture. Leaving 5-2's
  file alone is worth the one duplicated fixture: its `_flags()` opens `unblockable` alone, so all of
  its landings now run with the orbs layer CLOSED and its assertions stand unmoved — a free
  regression that this story changed nothing about 5-2.

**AC 1's regression is behavioural, not an absence.**
`test_the_grant_path_never_consults_the_spend_side_orb_gate` authors an orb cost NO player can pay
onto every card, casts mode ②, and shows the cast is allowed, the hit lands and the grant pays out —
because mode ② never calls `CastEvaluator.refusal_reason` (`5-2/R2`) and this story did not make it
start. `cast_evaluator.gd` is unchanged; `test_cast_evaluator.gd` is unedited and green.

**Files the story named as NOT-EDITED, confirmed unedited:** `test/state/test_economy_and_hero.gd`,
`test/state/test_cast_evaluator.gd`, `test/state/test_card_authoring.gd`,
`test/state/test_unblockable_initiation.gd`, `src/state/economy/cast_evaluator.gd`,
`docs/game-architecture.md`. `project.godot` is untouched.

**No editor session was run** (`3-0c/R13`): no new file declares a `class_name`
(`test_orbs_economy.gd` and `test_orb_cue_live.gd` are harness-discovered scripts;
`unblockable_landing.tres` is a resource). `project.godot` therefore carries no risk of the known
reorder/deletion signature and shows clean in `git status`. **CONSEQUENCE: the two new `.gd` files
ship WITHOUT a `.uid` sibling** (`test/state/test_orbs_economy.gd`,
`test/integration/test_orb_cue_live.gd`), where every other `.gd` in the repo has one. `.uid`
generation is left to the chain, as instructed. `.tres` files carry no `.uid` in this repo, so
`data/economy/unblockable_landing.tres` is consistent with its three siblings.

**DEVIATIONS AND DECISIONS — read these.**
1. **`OrbFlash` is a SIBLING of `HitFlash`, not `Shapes/OrbFlash`.** The story's Project Structure
   Notes name `Shapes/OrbFlash`; that placement does not work and AC 17 is what governs.
   `TelegraphController.on_action_state_changed` hides EVERY child of `$Shapes` on every transition,
   and the landing queues `set_action_state(IDLE)` in the SAME signal drain as the grant — an
   OrbFlash under `Shapes` would be switched off in the frame it was lit. AC 17 asks for "the SAME
   one-shot idiom the existing hit flash already uses", and `HitFlash`/`DeflectSpark` are both direct
   children of the controller for exactly this reason. Recorded in the node's own
   `editor_description`.
2. **The seam test was RENAMED** `test_runner_observation_seams_are_exactly_eight` →
   `..._exactly_nine`. The brief named only the list and the failure text; the rename follows the
   direct `3-6` precedent (`..._seven` → `..._eight` in that story's own commit) and refuses to leave
   a test whose NAME asserts eight while its body asserts nine. **Consequence, also done:** six
   citations of the old name were updated so no dangling reference ships — `match_runner.gd` (×4),
   `telegraph_controller.gd`, `debug_instrument_panel.gd`, `unit_board.gd`. The last two are files
   this story otherwise does not touch; each is a one-line comment edit and no code moved. Both the
   rename and those two out-of-set edits are the operator's to reverse if unwanted.
3. **`test_mana_economy.gd` was edited, which the story did not list.** It had to be: the new rule
   `.tres` moves the authored rule count 3 → 4, and that file asserts the count in two places. Kept
   minimal — the count moves, the fourth rule's identity is asserted as ORBS so no mana assertion can
   be answering about it, and its field-by-field pin lives in `test_orbs_economy.gd`. The test
   function was renamed `..._is_the_three_mana_faucets` → `..._is_the_four_authored_faucets` for the
   reason in deviation 2.
4. **`test_replay_identity.gd` was edited, which the story did not list.** Forced by the AC 11 pin —
   see Debug Log References and the `orb_pool._max` note above.
5. **AC 16's NAMED mutation does not go red, and a stronger one does. This is a finding.** The story
   asks for "a mutation (removing the priming guard) driving the test RED". MEASURED (Mutation Table
   row c1): deleting the `_orb_counts.is_empty()` early return and zero-initialising the previous
   triple to `[0, 0, 0]` leaves `test_orb_cue_live.gd` **GREEN** — because the pool genuinely rests
   at `(0,0,0)` at match start, so a zero baseline sees no increase on the priming payload. The
   guard's extra value over a zero baseline (correctness for a NON-zero priming) is not reachable in
   the shipped composition, where nothing connects to the seam after orbs exist. The hazard AC 16
   describes IS real for the naive form an adversary would actually write — "the seam fired, so
   flash" — and that form drives case (a) RED (row c2), which is the proof recorded. The empty-guard
   spelling is kept because it is the truthful one (it distinguishes "not seen" from "seen as zero"),
   not because a mutation forced it. **Operator's call whether AC 16's mutation wording should be
   amended.**

**QUESTIONS FOR THE OPERATOR (visible gameplay consequences, not implementation).**
- *The authored numbers are the story's own provisionals, unplaytested:* `unblockable_orb_grant = 1`,
  `max_orbs_per_color = 5`. At 1 per landing against a 5 cap, a player needs five landed
  unblockables to saturate one colour. Confirm at smoke or retune — it is a one-line `.tres` edit
  with no test edit and no golden re-baseline (`BC/R3`; the story adds no new seat and makes no
  action refusable, so `SC/R6`'s boundary is not crossed).
- *The earn cue's hold is 0.25 s*, in the spent colour, on a 0.16-radius sphere at root +1.35 (clear
  of the box top at +1.0 and of `ChargeMarker` at +0.5). Legibility and duration are smoke surfaces.
- *The reset clears orbs silently.* AC 13 clears them at the debug reset, and the earn cue correctly
  does NOT fire on that decrease — so a player watching the hero sees nothing; only the HUD counters
  drop to zero. If the round boundary should ANNOUNCE the loss of a stake, that is a new cue and a
  new ruling, not something this pass added.

### Mutation Table (MEASURED)

Every proof below ran the AFFECTED TEST FILE ONLY. Every mutated file was copied OUTSIDE the repo and
SHA-256'd before mutation, then restored by copying the backup BACK (never `git checkout`); the
post-restore SHA-256 is re-read and matched in each row.

| # | Mutation | File | Observed | Restore |
|---|---|---|---|---|
| a | `f.orbs = true` staged into `_golden_flags()` | `test/state/test_determinism.gd` | **GREEN** — hash still `dc2c9ffa…`, 17/17 pass. Proves UNMOVED comes from the fixture never landing a charge, not from a closed flag. | copy-back, sha `9f6b41c26de6e993` |
| b | `"maximum": _max` staged into `to_snapshot()` (the AC 12 forbidden key) | `src/state/pools/orb_pool.gd` | **RED** — `test_state_matches_golden`: got `4cc026238a1efdf4…`, expected `dc2c9ffa…`. Proves the harness measures snapshot shape. | copy-back, sha `0fc5c06a325f35ac` |
| c0 | priming-guard body replaced with `if false:` (previous triple never populated) | `src/actors/hero/telegraph_controller.gd` | **RED** on half (b) — "no OrbFlash after a REAL increase — the cue never fires at all". Proves half (b) is non-vacuous. | copy-back, sha `39c433c71273b7f5` |
| c1 | priming guard DELETED, `_orb_counts` zero-initialised `[0, 0, 0]` | `src/actors/hero/telegraph_controller.gd` | **GREEN** — the finding in deviation 5. AC 16's literally-named mutation is not reachable in the shipped composition. | copy-back, sha `39c433c71273b7f5` |
| c2 | diff removed entirely: the cue fires on EVERY `orbs_changed` payload (the naive "the seam fired, so flash" form) | `src/actors/hero/telegraph_controller.gd` | **RED** on half (a) — "OrbFlash is LIT after the priming emission — the cue fired on a connect, not on an earn" (plus the cross-slot and decrease cases). This is AC 16's proof. | copy-back, sha `39c433c71273b7f5` |
| d | `if updated == current: return` (AC 8's no-op short circuit) removed from `add` | `src/state/pools/orb_pool.gd` | **RED**, 3 tests — injection emitted `[[0,0,0],[0,0,0],[0,0,0]]` instead of nothing; 4 events instead of 1; a saturated-colour landing signalled `[[0,3,0]]`. | copy-back, sha `0fc5c06a325f35ac` |
| e | `"connect_orbs_changed"` dropped from `OBSERVATION_SEAMS` | `test/state/test_architecture_invariants.gd` | **RED** — the nine-name scan vs. the eight-name list, naming the ninth. Proves the pin sees the new seam. | copy-back, sha `8313e4f07832e543` |
| f | `player.orbs.reset_all()` removed from `_reset_player` | `src/state/match_state.gd` | **RED**, 2 tests — the reset left P1 at `{blue: 2}` and P2 at `{green: 1}`; the round-boundary test got 2, expected 0. | copy-back, sha `1ef29b33cb3dc0c1` |
| g | `"unblockable_orb_grant"` dropped from `E1_BALANCE_FIELDS` | `test/state/test_data_resources.gd` | **RED** — reflection half (a): "BalanceConfig field missing from E1_BALANCE_FIELDS — it ships unaudited: unblockable_orb_grant". | copy-back, sha `24ee51f61861c98d` |
| h | authored `unblockable_orb_grant = 0`, `max_orbs_per_color = 0` | `data/balance/balance_config.tres` | **RED** — both bespoke `> 0` bounds fire. Proves the `>= 0` loop alone would have shipped the story invisible. | copy-back, sha `b80cefa2559bd181` |
| i | `"orb_pool._max"` absent from `INJECTED` (the state as first written — measured in the wild by close-out attempt 1) | `test/state/test_replay_identity.gd` | **RED** — `test_unhashed_cross_tick_state_is_exactly_three_members`. Proves the AC 11 classification pin sees a new `src/state/` member. | fixed forward (classified INJECTED) |
| j | `is_alive()` guard staged around the `_grant_landing_orbs` call in `_resolve_charge_landing` (the review fix's own non-vacuity proof for the new kill-case test) | `src/state/match_state.gd` | **RED**, 1 test — `test_a_landing_that_kills_its_target_still_pays_the_grant`: got `0`, expected `2` on both the grant assertion and the survives-the-freeze assertion; no other test in the file moved. | copy-back, sha `1ef29b33cb3dc0c1` |

### File List

**New**
- `data/economy/unblockable_landing.tres` — the fourth authored rule (AC 2)
- `test/state/test_orbs_economy.gd` — 17 tests, AC 1-13 (no `.uid`; see Completion Notes). Now 18
  tests after the review fix pass's kill-case addition (see Change Log, 2026-09-06 review fixes).
- `test/integration/test_orb_cue_live.gd` — AC 16 (no `.uid`; see Completion Notes)

**Modified**
- `src/state/economy/economy_evaluator.gd` — `ORBS`, `SOURCE_UNBLOCKABLE_LANDING` (AC 1)
- `src/state/resources/balance_config.gd` — `unblockable_orb_grant`, `max_orbs_per_color` + a new
  `Orbs` export group (AC 3/9)
- `data/balance/balance_config.tres` — the two authored values (1, 5)
- `data/feature_flags.tres` — `orbs = true` (AC 14)
- `src/state/pools/orb_pool.gd` — `NO_MAXIMUM` sentinel, `_max`, clamped + short-circuited `add`,
  `set_maximum`, `get_maximum`; `to_snapshot()` UNCHANGED (AC 8/12)
- `src/state/match_state.gd` — `_grant_landing_orbs` + its call in the landed branch (AC 1/4-7),
  `_apply_balance_to_player`'s injection line (AC 10), `_reset_player`'s `reset_all()` (AC 13), and
  three header corrections (`_resolve_charge_landing`'s "no orb (`5-4`)" forward reference,
  `_apply_debug_reset`'s named-exception count)
- `src/main/match_runner.gd` — `connect_orbs_changed` (AC 15) and its two wirings (AC 17, AC 18-20);
  four seam-test citations
- `src/actors/hero/telegraph_controller.gd` — `on_orbs_changed`, `_orb_flash`, `_orb_flash_tween`,
  `_orb_counts` (AC 17); one seam-test citation
- `src/actors/hero/hero.tscn` — the `OrbFlash` node + its mesh sub-resource (AC 17)
- `src/ui/hud/hud_root.gd` — `on_orbs_changed`, `_orb_labels`, `ORB_COLORS`, the filled
  `_build_orb_counters` (AC 18-20)
- `src/ui/debug/debug_instrument_panel.gd` — seam-test citation only (comment)
- `src/state/unit_board.gd` — seam-test citation only (comment)
- `test/state/test_architecture_invariants.gd` — `OBSERVATION_SEAMS` and the failure text to NINE,
  test renamed (AC 15)
- `test/state/test_data_resources.gd` — the two new fields in `E1_BALANCE_FIELDS`, plus the AC 14
  authored-flag pin
- `test/state/test_balance_authoring.gd` — bespoke `> 0` bounds for both new fields (AC 3/9)
- `test/state/test_mana_economy.gd` — authored rule count 3 → 4 (see deviation 3)
- `test/state/test_replay_identity.gd` — `orb_pool._max` classified INJECTED (see deviation 4)
- `docs/implementation-artifacts/5-4-orbs.md` — this record

**Not committed by this pass:** nothing is staged and nothing is committed, per the operator's
instruction.

### Change Log

- 2026-09-06 — Story authored (this file). NOT cleared for a dev pass — a separate readiness
  gate runs before promotion to ready-for-dev.
- 2026-09-06 — Readiness gate fixes applied (nine rulings: pre-injection `OrbPool` unbounded
  via a `-1` sentinel, not inert; `add`'s no-op-on-no-change short circuit; a new negative AC
  pinning `to_snapshot()` unchanged with a named non-vacuity proof; the observation channel
  resolved to a ninth `connect_orbs_changed` seam, `MatchState.orb_granted` deleted from the
  plan; the shipped flag opened to `orbs = true` with its own blast-radius pin; two new
  balance-field test-file obligations named explicitly; the float-to-int grant conversion
  named as `roundi` with its reasoning; a new AC pinning the prime-on-connect false-fire; the
  AC count trimmed from 24 to 20 by deleting/folding six ACs into Non-Goals/Dev
  Notes/Golden Prediction and trimming two further ACs to their load-bearing or
  behavioural half). Promoted to ready-for-dev.
- 2026-09-06 — Dev pass complete. All twenty ACs implemented; golden UNMOVED at `dc2c9ffa`, proven
  falsifiable in both directions; `FORMAT_VERSION` unbumped (7); the observation-seam family moved
  eight → nine in the test only, with the arch-doc prose queued for the E5 close-out flush. Suite
  629/4809 → 648/4893, all green. Eleven measured mutation proofs recorded. Status → `review`;
  nothing staged, nothing committed. Deviations and two operator questions are in Completion Notes.
- 2026-09-06 — Review fixes applied (two findings). MED: `test_orbs_economy.gd` gains
  `test_a_landing_that_kills_its_target_still_pays_the_grant`, driven through a new
  `_make_lethal_match`/`_lethal_config` fixture (100 %% damage instead of the shared 10 %%) so
  the SAME landing that kills the target is the one that pays the grant, and the grant is then
  proven to survive the round-over freeze until the debug reset — closing the prior gap where the
  kill and the grant were only ever proven separately. Non-vacuity: an `is_alive()` guard staged
  around the `_grant_landing_orbs` call drove the new test RED (Mutation Table row j), then
  restored by SHA-256-verified copy-back. LOW/docs-only: AC 16's named mutation is reworded to the
  form that actually drives the priming case red (a cue that fires on any `orbs_changed` payload
  rather than only on an increase); the originally-named mutation (deleting the priming guard
  alone) is kept on record as a vacuous finding, not deleted. No code changed for this second fix.
  Status stays `review`; nothing staged, nothing committed.
