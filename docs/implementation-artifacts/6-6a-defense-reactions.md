---
baseline_commit: 6a88b78e2ff1cc9ae5c25fefe3d664f6173ee246
---

# Story 6.6a: Defense Reactions

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want the paladin to visibly flinch on an ordinary hit, go down and get back up on an unblockable
that lands clean, show a held stunned pose on both existing stun kinds, and stop popping in and out
of the block guard,
so that the three defense/reaction moments the game already resolves mechanically (hurt, stun,
knockdown, block) finally READ as something happening to a body, not a silent state flip.

## Board note (deviation, report this to the operator)

The board key `6-6-defense-presentation` is SPLIT per operator ruling (scope talk 2026-09-17, the
`6-3a`/`6-3b` precedent, `6-3-split/R-SPLIT`) into `6-6a-defense-reactions` (this story, Tier A) and
`6-6b-color-counters` (placeholder, Tier A, three color counters per attack type). Both entered
`sprint-status.yaml` as `backlog` with one-line `story_notes`; `epics.md:234` (which still reads
`6-6-defense-presentation ... Tier B, at risk of Tier A`) is now stale and is deliberately NOT
edited here (close-out debt, the `6-8` precedent — `epics.md` is corrected only at a story's
close-out, not its create pass). Tracked in Docs Debt below.

## Acceptance Criteria

**Ordinary hit -> hurt reaction (Ruling 1)**

1. Any `hit_landed` where the target is a hero plays `hit_react.fbx` on that hero, presentation-only,
   fired from the EXISTING `hit_landed` seam (`connect_hit_landed`, `match_runner.gd:1010`), wiring a
   NEW consumer (`AnimationController`) onto it exactly the way `TelegraphController` already is
   (`match_runner.gd:506`) — no new seam, no widened payload; the existing `(attacker_slot, target_slot,
   damage, target_hp)` payload already lets a per-slot-bound consumer gate on `target_slot == slot`. It
   does NOT touch `src/state/` — hitstun on ordinary hits is a NAMED, DEFERRED item (post-E6
   playtest/retune block), not this story's scope.
2. `hit_react.fbx` plays ONLY when the victim is in an IDLE-family locomotion state at the moment the
   signal is consumed (the state `on_locomotion` itself drives). During ATTACKING, ROLLING, CHARGING or
   STUNNED, the victim's current action clip is NOT replaced — mid-action flinch is deferred to the
   hitstun/poise system (AC 1's Non-Goal). One-shots (`hit_react.fbx`, `get_up.fbx` — AC 7) get a
   locomotion-yield rule: `on_locomotion`'s per-tick `_play()` must not steal either clip while it is
   mid-play, even once the victim returns to an IDLE-family state before the one-shot naturally
   finishes.

**Unblockable landed -> knockdown (Ruling 2)**

3. An unblockable attack that LANDS UNANSWERED (not negated by the color counter, not dodged by the
   iframe rung — the third, "unanswered" tier of the `5-6` three-tier ladder) enters the VICTIM
   (`target`, never the caster) into a THIRD `STUNNED` inbound edge: knockdown, via its own SEPARATE
   write — `target.hero.stun.start(...)` + `target.hero.set_action_state(STUNNED)`. The caster's
   existing trailing `player.hero.set_action_state(IDLE)` exit from `CHARGING`
   (`match_state.gd:3475`) is UNTOUCHED — "one write per outcome" holds per hero, not by replacing that
   line. The write is gated on `target.hero.is_alive()` evaluated AFTER `take_damage` runs: a lethal
   landing writes `DEAD` only and never a phantom `STUNNED` that a later step-8 `DEAD` write would
   stomp. While down: all actions are refused, the hero is rooted, running windows tick out, there is
   no early-stop path, and no upper bound is imposed on knockdown duration — the existing `STUNNED`
   contract (`5-6/R3`), unchanged, applied to this third edge.
4. Knockdown duration is a new authored `BalanceConfig` field, provisional value chosen by the dev
   pass, with its DIRECTIONAL bound pinned by this story and asserted in TICKS (`BalanceTicks`, not
   seconds — two distinct authored second-values can round to the same tick count via
   `seconds_to_ticks`, so a seconds-only comparison would under-test the bound):
   `knockdown_stun_ticks > color_counter_stun_ticks (1.0 s) > deflect_stun_ticks (0.4 s)`. The exact
   provisional value is an implementation choice within that bound, not a design decision requiring a
   stop.
5. The victim's PRIOR state at the moment knockdown lands is enumerated, one test per state: IDLE,
   ATTACKING, BLOCKING, ROLLING (iframe closed at step 3), CHARGING, and STUNNED — which splits into
   two sub-cases, one test each (operator ruling **R-STUNSTACK**): a victim already in an ORDINARY
   stun (color-counter or deflect flavor) is KNOCKED DOWN — the knockdown write proceeds,
   `stun.start(knockdown ticks)` REPLACES the shorter window, and the flavor becomes knockdown (the
   Sekiro read: staggered + perilous = you go down); a victim already in the KNOCKDOWN flavor is
   governed by AC 7's floor rule instead (damage only, never restart/extend). This is a one-way
   escalation and cannot loop: once down, the floor rule holds, so no knockdown lock results (this is
   what resolves the round-1 gate's B5 lock concern, by construction, not by a separate guard).
   Presentation must prove the ordinary-stun -> knockdown escalation is visible (the clip switches to
   `knockdown.fbx` and the window visibly extends) with a test — the flavor change reaches
   presentation via the stun-reason forwarding mechanism (Open Question 3), NOT via a state-entry
   signal, since `set_action_state` on previous==current emits nothing (`hero_state.gd:211-212`), and
   an ordinary-stun-to-knockdown write is a same-state (`STUNNED` -> `STUNNED`) write. ATTACKING,
   ROLLING and BLOCKING are safe by construction (`is_hitbox_active` needs ATTACKING,
   `hero_state.gd:230-236`; the deflect path needs BLOCKING, `match_state.gd:1701`) but are still
   asserted, not merely argued. CHARGING is the one case with a real effect: a knockdown on a
   CHARGING victim ABANDONS their chargeup (operator ruling — the Sekiro read: eat a perilous, lose
   your attack). The card and stamina already spent on that charge stay spent; the interrupted
   charge's data is CLEANED on the knockdown write, mirroring the `6-1` feint-teardown exactly
   (`match_state.gd:1175-1179`): `charge_window`, `landing_window` and `charge_color` are cleared
   together as one fact, with the state write. `_charge_reach`/`_charge_contact_dirs` are NOT part of
   that cleanup — they follow their own `6-1d`/`R9` discipline ("CLEARED WITH THE VERDICT, never on
   its own," `match_state.gd:291-294`) and the feint path itself leaves them untouched, so the
   knockdown-abandonment write does the same.
6. Simultaneous unblockable landings — one per seat, same tick — are SEAT-SYMMETRIC (operator ruling):
   BOTH land, BOTH victims are knocked down. Neither landing is cancelled by the other's knockdown
   write within the same tick, even though tick order runs p1 actions -> p1 movement -> p2 actions ->
   p2 movement (`match_state.gd:534-537`) and a naive write would flip the second seat to `STUNNED`
   before its own `CHARGING` landing arm runs. Pinned by a both-slots test on the
   `_iframe_open_at_step3` shape — the latch is documented at `match_state.gd:298-325`, and the
   both-slots precedent this new test follows is `test_the_dodge_boundary_is_identical_on_both_slots`
   (`test_unblockable_defense.gd:701`).

   Same-tick PRESS semantics are SEAT-SYMMETRIC as well (operator ruling **R-PRESS**), superseding
   this AC's earlier "existing, unedited seat-order behavior" claim: this is the FIRST cross-player
   write to land in step 3, and `match_state.gd:300-308`'s own doc already calls seat-dependence "a
   seat-dependent mechanic, which nothing in this game is," so the two directions cannot simply
   inherit whatever the p1-before-p2
   tick order happens to produce. The pinned OUTCOME, identical for both seats and both directions: a
   press on the same tick as an incoming knockdown ALWAYS resolves first (stamina/card spent, action
   taken), and the knockdown write then overwrites the resulting state. Tests cover both seats:
   press-then-knockdown ordering, and the simultaneous double-landing trade above. The MECHANISM is a
   dev-pass choice (Open Question 8) — the implementation almost certainly needs a deferred-write
   latch so the knockdown write does not apply before the victim seat's own step-3 processing runs on
   that tick; if this latch lands, its unit of deferral is the WHOLE landing package — damage
   application, the knockdown `STUNNED` write, and the `hit_landed` push, deferred together with their
   internal order preserved (AC 12) — not the `STUNNED` write alone. If a no-new-storage ordering fix
   is found instead, the latch is unneeded and Golden Prediction cause 4's now-expected latch clause
   simply discharges.
7. A hit that lands on an ALREADY-knocked-down hero (victim is STUNNED via the knockdown flavor) deals
   its damage but does NOT restart or extend the running stun window — the original window ticks out
   on its own schedule, unaffected (the "floor rule," operator ruling **R-STUNSTACK**). The floor rule
   applies ONLY to a victim already in the KNOCKDOWN flavor; a victim in an ORDINARY stun
   (color-counter or deflect flavor) is NOT covered by the floor here — see AC 5's STUNNED
   prior-state row for that case, which is a one-way escalation, not a restart. A knockdown victim
   cannot be re-stunned into a longer or fresh window while still down. No visual change results from
   a second landing on a downed hero beyond the ordinary hurt/damage feedback (the knockdown clip's
   hold is not restarted).
8. `get_up.fbx` plays once, and ONLY once, on the ordinary timer-driven `STUNNED -> IDLE` exit from a
   knockdown-flavored stun (never on the debug-reset exit — AC 9). On that same exit, a NEW timing
   window opens: get-up iframes (operator ruling), reusing the `roll_iframe` mechanism's shape (`1-9`
   class: a fact-drop pre-dedupe rule, no damage taken, no orbs generated while it is open, the window
   ticks out on its own with no early-stop path). Its duration is a new authored `BalanceConfig` field
   tied to the measured length of the `get_up.fbx` clip (dev measures the value; live smoke judges the
   felt window). This is a real `src/state/` addition — a new `TimingWindow` (on `HeroState` or
   `PlayerState`; measure which owns it per the `5-5` `defense_window` precedent) — so the Golden
   Prediction and replay-identity sections below carry it as a definite new hashed or named-unhashed
   member, not a conditional one. **Operator ruling R-IFRAME-UNBLOCKABLE:** the get-up iframe window
   registers wherever `roll_iframe` does — the unblockable dodge rung (`is_iframe_open`/
   `_iframe_open_at_step3`) sees it too, so get-up iframes are valid against unblockables, not only
   against melee. A carve-out for unblockables would defeat the whole point of the window, which is
   that nothing can be timed into the get-up.
9. The debug-reset exit from a knockdown-flavored `STUNNED` does NOT play `get_up.fbx` and does NOT
   arm the get-up iframe window — reset snaps straight to `IDLE` (operator ruling). The stun-flavor
   discrimination used for presentation selection (AC 11) is NOT a stored "memory" field cleared on
   exit — as AC 5's escalation case shows, `set_action_state` on a same-state (`STUNNED` -> `STUNNED`)
   write emits nothing (`hero_state.gd:211-212`), so presentation cannot rely on an entry signal
   firing at every flavor change; it is derived at consumption time via the stun-reason forwarding
   mechanism (Open Question 3), reading the running `stun` window's own duration. The reset path
   additionally clears the AC 8 iframe window if it happens to be armed at reset time. This is the
   SEVENTH reset-exception line item, not the sixth: `6-2`'s pitch-zone clear
   (`match_state.gd:4313-4317`) is already the sixth of six named exceptions the header at
   `match_state.gd:4279-4317` currently enumerates (unit board `4-1/R5`, chargeup `5-3`, orb pool
   `5-4`, defense window `5-5` AC 12, stun window/`STUNNED` state `5-6` AC 13, pitch zones `6-2` AC
   14d) — this story's iframe-window clear is the seventh, added alongside those, and the header's
   "These are SIX named exceptions" line (`match_state.gd:4317`) must be updated to SEVEN by the dev
   pass. Traced the way `5-6` traced its own reset exception.

**Existing stuns get a pose (Ruling 3)**

10. Both pre-existing stun kinds — color-counter (1.0 s, attacker-side, `match_state.gd`'s
    negation-ladder rung) and deflect (0.4 s, attacker-side, the melee/unit deflect rung) — now play
    `stunned.fbx` instead of holding whatever pose the attacker was in when the stun struck (today's
    behavior: `STUNNED` is unmapped in `AnimationController._CLIP` and the pose is left untouched).
    `stunned.fbx` is a Mixamo "Impact" variant — measured as a short one-shot reaction, NOT a loop. It
    is held/stretched to cover the full stun duration (the `6-1b` single-frame-hold precedent,
    `animation_controller.gd:233`'s `_CHARGE_HOLD_KNOBS`/`charge_playhead_seconds` (`:249`) mechanism),
    never looped.
11. All three `STUNNED` flavors — knockdown (Ruling 2), color-counter and deflect (this ruling) — are
    presentation-DISTINCT: `knockdown.fbx`/`get_up.fbx` for the knockdown flavor, `stunned.fbx` (held)
    for color-counter and deflect. See Dev Notes for the measured mechanism that tells them apart
    (duration-threshold comparison in ticks, safe from collision because AC 4's directional bound
    keeps all three durations distinct). AC 7's floor rule is the one exception this AC must not
    contradict: a second landing on an already-downed hero never re-triggers or restarts the
    `knockdown.fbx` hold.

**Block stops popping (Ruling 4)**

12. A blocked hit (damage scaled by `block_damage_multiplier`, the non-deflect block branch) plays
    `block_impact.fbx` on the blocker, read from the ANIMATION CONTROLLER'S OWN mirrored `_state`
    (`animation_controller.gd:337,387`) at signal-consumption time — never a live read of
    `hero.action_state` from the runner (the `_charge_color_for_slot` shape,
    `match_runner.gd:984-990`, is live-and-post-advance, and is the wrong pattern to copy here). This
    matters on the unblockable path specifically: the knockdown `STUNNED` write precedes its
    `hit_landed` push WITHIN the landing package — damage application, the knockdown write, and the
    `hit_landed` push, in that internal order — whether or not the package is deferred (see AC 6/Dev
    Notes: the deferred package is the R-PRESS latch's unit of deferral), on both seats, so the mirror
    has already advanced off `BLOCKING` to `STUNNED` by the time clip selection runs on an unanswered
    unblockable landing on a BLOCKING victim — this internal ordering is what keeps `block_impact.fbx`
    from firing stale, not what makes `hit_react.fbx` fire. The actual selected outcome is KNOCKDOWN presentation
    (`knockdown.fbx`, via the `on_action_state_changed` path), NOT `hit_react.fbx`: AC 2 scopes
    `hit_react.fbx` to IDLE-family victims only, and the mirror at consumption time reads `STUNNED`,
    not IDLE, so AC 2's hit_react branch is never reached here — this AC's point is only that no stale
    `block_impact.fbx` fires. One non-blocking note for the dev pass: on a LETHAL unanswered
    unblockable landing on a blocker, the `is_alive()` gate (AC 3) skips the `STUNNED` write entirely,
    so the mirror still reads `BLOCKING` and would select `block_impact.fbx` — the step-8 `DEAD`
    transition arrives in the same drain, so this stale selection is not expected to be visible, but
    it should not surprise the dev pass. `hit_landed`'s signal arity is NOT widened for this AC or any
    other in this story (`TelegraphController.on_hit_landed` has fixed arity 4 + a bound slot,
    `telegraph_controller.gd:210`, bound at `match_runner.gd:506`, and an extra argument would break
    that call site).
13. Block EXIT — and ONLY exit, `BLOCKING -> IDLE` — gets a blend transition, reusing the existing
    locomotion crossfade machinery (`AnimationController._play()`/`LOCOMOTION_BLEND_SECONDS`,
    `animation_controller.gd:543-546`) in place of today's instant `_restart()` cut, on `3-0b/R24`'s
    pre-cleared terms: `block -> attack`/`block -> roll` stay instant (they start real mechanical
    content immediately), and the conditional lives in `on_action_state_changed`'s non-CHARGING branch
    (`animation_controller.gd:396-398`), not in a generic `_play()` change. Block ENTRY stays an
    instant, un-blended `_restart()` cut, per `3-0b/R23`'s standing mechanical ruling: `enter_block()`
    opens the 9-tick (0.15 s) deflect window on the entry tick itself, and a blend on entry would show
    a "shield still rising" pose while the deflect window is already live, corrupting the parry read.
    This resolves Open Question 1 (below): AC 11 (now AC 13)'s original "block ENTER and EXIT" text was
    drift from `R24`'s already-cleared exit-only shape, not an intentional re-opening of `R23` — ENTRY
    stays instant.

## Non-Goals

- **Hitstun on ordinary hits** (AC 1's second sentence) — named, deferred to the post-E6
  playtest/retune block. Not this story, not `6-6b`.
- **The three color counters and any change to Mode ③ defense timing.** The `5-5` pre-arm window
  ships EXACTLY as-is until `6-6b`, whose close-out owns that supersession. This story touches
  neither `CastEvaluator`'s defense dispatch nor `defense_window`/`defense_color`.
- **Minion hurt/stun reactions.** Minion liveliness is its own block; the `4-3b/R7` minion-deflect-
  no-stun guard (a unit's hitbox never enters `STUNNED` — it has no `ActionState`) re-runs UNEDITED
  as this story's own proof the gate still holds, exactly as `5-6` re-ran it.
- **Real audio.** Sting/audio work is a separate pass; this story is visual-only.
- **Retuning `deflect_stun_seconds`/`color_counter_stun_seconds`.** Both stay at their `5-6`-authored
  values (0.4 / 1.0); only the new third field is authored here.

## Golden Prediction

No value is predicted; the gate and the dev pass MEASURE the golden hash and the snapshot key set
before and after, per Tier A discipline. Candidate causes, each to be confirmed or ruled out
separately:

1. **The knockdown write itself (AC 3/AC 5/AC 6) is a `src/state/` change** — a third `STUNNED`
   inbound edge, added as the VICTIM's own separate write (`target.hero.stun.start(...)` +
   `target.hero.set_action_state(STUNNED)`) alongside the caster's existing, UNTOUCHED trailing
   `player.hero.set_action_state(IDLE)` exit from `CHARGING` (`match_state.gd:3475`) — not a
   replacement of that line (see B1's correction to the earlier draft of this cause, which had the
   knockdown landing on the wrong hero). This is the one candidate with any real golden-adjacency, and
   it is predicted a STRUCTURAL NON-MOVER: the golden fixture never enters `CHARGING` at all
   (`test_determinism.gd:699,722` — "no hero ever enters CHARGING... this fixture never casts mode
   (2)"), so no unblockable is ever cast, landed, or resolved by the fixture's scripted sequence. The
   unanswered-unblockable-landed code path this story edits — including the CHARGING-abandonment
   cleanup (AC 5) and the simultaneous-trade handling (AC 6) — is therefore UNREACHABLE from the
   golden's own script by construction, and its own coverage lives in `test_unblockable_defense.gd`/the
   three-tier-ladder tests, not the golden. Measured both directions at the dev pass per discipline,
   not assumed from this argument alone.
2. **The new `BalanceConfig` fields (`knockdown_stun_seconds` and the AC 8 get-up-iframe duration, or
   equivalents).** Authored balance is isolated from BOTH the golden and the unit suite (`BC/R3`,
   standing fact) — a new field, like a changed value, needs no golden re-baseline on its own.
   Confirmed applicable to `knockdown_stun_seconds` here: nothing on the golden's own path reads it, by
   cause 1 above. The get-up-iframe duration field is the same class of addition (an authored value,
   not a state variable) and carries no golden weight on its own — only the WINDOW it sizes (cause 4
   below) is state-layer.
3. **AC 1/2/10/11/12 (the presentation rulings) touch ONLY `src/actors/hero/animation_controller.gd`
   and the `match_runner.gd` wiring loop that connects consumers to existing seams** — no
   `src/state/` line changes, no new hashed field, no new snapshot key. The color-counter and deflect
   stun-ENTRY code paths (which the golden DOES exercise — `test_determinism.gd:813,1483,1494`, "p1:
   attack, DEFLECTED into STUNNED at t5") are read-only from the presentation side; playing
   `stunned.fbx` off the SAME `action_state == STUNNED` transition the golden already drives changes
   nothing hashed. AC 13's block-exit blend is the same shape, reading the golden's existing
   `BLOCKING -> IDLE` transitions without touching state. Predicted a structural non-mover, same
   reasoning as `6-8`'s Cause 3 (`set_camera_basis` called zero times) applied to a different consumer.
4. **A new snapshot key/hashed member IS expected, and it is not conditional: the AC 8 get-up-iframe
   `TimingWindow` is a real `src/state/` addition** (on `HeroState` or `PlayerState` — measured at the
   dev pass which owns it, per the `5-5` `defense_window` precedent), armed only on the
   timer-driven `STUNNED -> IDLE` exit from a knockdown flavor (never on reset, AC 9). This is a
   DEFINITE new hashed-or-named-unhashed member, unlike the knockdown `STUNNED`/`stun` reuse below, and
   the golden's own script must be re-measured against it even though the fixture never reaches
   knockdown by construction (an unarmed window still needs to round-trip through the snapshot
   machinery cleanly). Separately, and now UPGRADED FROM CONDITIONAL TO EXPECTED by operator ruling
   **R-PRESS** (AC 6): the dev pass almost certainly needs a deferred-package latch so a same-tick
   knockdown write does not apply before the victim seat's own step-3 processing runs — the
   `_iframe_open_at_step3` precedent — and that latch, if it lands, is ALSO a new `src/state/` var
   owing a definite replay-identity bucket classification at implementation time. If the dev pass
   instead finds a no-new-storage ordering/scheduling solution, this second obligation simply
   discharges (see Open Question 8). Aside from these two, no new snapshot key is expected: knockdown's
   `STUNNED` `ActionState` (already hashed) and `stun` `TimingWindow` (already hashed since `5-6/R7`)
   are REUSED — a third `start()` call site with a new duration is not itself a new field. No new
   player input, recorded fact, or `InputIntent` channel is added by this story (block/hurt/stun
   reactions consume existing state; nothing new is captured). `FORMAT_VERSION` is predicted to STAY
   11: `RecordFile.FORMAT_VERSION` (`record_file.gd:195`) moves only when a RECORDED INPUT CHANNEL
   changes (`:241-256`), and both `5-5`'s `defense_window` and `5-6`'s `STUNNED`/`stun` additions left
   it unmoved on the identical precedent — a new state/snapshot member is a replay-identity/hash-bucket
   question, never a format bump. Measured and stated at the dev pass, not assumed.

Baseline: current golden `71a7b45f...` (`6-8-camera-freedom` close-out, decision-log Session
2026-09-17), `FORMAT_VERSION` 11. Both are re-measured fresh at dev-pass start per the golden-clause
discipline.

**Fixture-coverage: RESOLVED at the round-1 gate (accept coverage-by-suite, no fixture extension).**
The golden never casts an unblockable and the knockdown write's own path is unreached by the fixture
by construction (cause 1 above); the gate ruled this acceptable on the `5-2`/`6-1c`/`5-5` precedent —
a chain unreachable by the fixture and proven in the suite instead (`test_determinism.gd:729-732,
773-774, 930-932`), rather than the `5-6` §1 shape (a fixture that already reached the path but was
hash-degenerate). Condition: today's suite does not cover knockdown at all beyond the caster's own
log (`test_unblockable_defense.gd:458-465`), so the suite must GAIN named, mutation-proven tests for
every AC in Ruling 2 — target state and duration, the target-only single write (AC 3), the
per-prior-state table (AC 5), both-slots trade symmetry (AC 6), the floor rule and get-up iframe
window (AC 7/AC 8), the lethal gate (AC 3), and the reset exception (AC 9) — since nothing existing
reaches any of these paths. The golden hash and snapshot key set are still measured both directions
per Tier A discipline; only the fixture's SCRIPT is not extended.

## Live Smoke

`[3, 3]` (two pads) is REQUIRED for the knockdown and color-counter items below — the keyboard
controller has no confirm key for mode 2 or mode 3 (`5-7` deleted both, `keyboard_controller.gd:41-45`),
so `[0, 3]` (P1 keyboard/P2 pad) cannot cast an unblockable or a defense card at all. Under `[0, 3]`
only the P2->P1 knockdown, the P2 melee-deflect stun, and the hurt/block items are reachable — name
this explicitly if `[3, 3]` is unavailable and skip the unreachable items rather than fake them.

- **Hurt reaction (AC 1/AC 2).** Land an ordinary basic-attack hit on each hero in turn; confirm
  `hit_react.fbx` plays on the VICTIM only when idle, the attacker's own pose is untouched, and the
  victim's current action (mid-attack, mid-roll if reachable) is NOT interrupted or scrubbed by
  `hit_react`.
- **Knockdown (AC 3-9), requires `[3, 3]`.** P1 casts an unblockable in a color P2 is not defending;
  confirm it lands unanswered, `knockdown.fbx` plays and holds for the authored duration on P2, all
  actions are refused while down (attempt a card cast, a roll, a block — all refused), and
  `get_up.fbx` plays once on exit back to idle, followed by a brief window where a follow-up hit does
  not land (the get-up iframe, AC 8). Confirm a color-countered unblockable and a dodged unblockable
  do NOT knockdown (the other two ladder rungs are unchanged).
- **Simultaneous trade (AC 6), requires `[3, 3]`.** Time both P1 and P2 unblockables to land on the
  same tick, unanswered on both sides; confirm BOTH players go down, not just one.
- **Floor hit (AC 7), requires `[3, 3]`.** While a hero is already knocked down, land a second hit on
  them (basic attack or another unblockable); confirm damage/hurt feedback plays but the knockdown
  duration does NOT visibly extend or restart.
- **Existing stuns get a pose (AC 10-11).** Trigger a color-counter stun (defend an unblockable in the
  matching color, `[3, 3]`) and a melee deflect (block-and-deflect a basic attack, reachable at
  `[0, 3]` as P2) in turn; confirm `stunned.fbx` plays and holds on the ATTACKER for each, distinct
  from the knockdown clip, and that the held pose does not look like a loop restarting.
- **Block impact and exit blend (AC 12-13).** Hold block and take a non-deflected melee hit; confirm
  `block_impact.fbx` plays (confirmed on an ordinary non-deflected melee hit only). Separately, on an
  unanswered unblockable landing on a blocking victim, confirm KNOCKDOWN presentation plays instead —
  `knockdown.fbx`, not `hit_react.fbx`, and not a stale `block_impact.fbx` — matching AC 12. Enter and
  exit block
  repeatedly; confirm ENTRY stays an instant, un-blended cut (per `3-0b/R23`) and EXIT is visibly
  softened by the blend (per `3-0b/R24`, this story's OQ 1 resolution) — record that this is the
  shipped shape, not the "enter and exit both blend" reading of the original AC text.
- **Deflect window legibility spot-check.** With block entry staying instant, hold block and attempt
  to deflect an incoming attack in the first few ticks after pressing block; confirm the parry still
  reads as available immediately (the `3-0b/R23` concern this story's entry-blend question directly
  revisits) — a felt judgment call, not a headless-provable one.

Record all items in `docs/playtest-log.md` by the operator's own hand, per `PROC/R8`.

## Dev Notes

- **Tier: A**, fixed at authoring per the board split (operator ruling, scope talk 2026-09-17).
  Author's rationale: AC 3/AC 6 add a third `STUNNED` inbound edge and a new branch in
  `src/state/match_state.gd`'s unblockable-ladder resolution — a real state-layer change,
  golden-clause-triggering by construction even though it is predicted unreachable by the golden's
  own script (Golden Prediction above). Tier may be raised, never lowered, mid-story (`CLAUDE.md`
  Story tiers).

- **RESOLVED at the round-1 gate: block entry stays instant, only exit blends (Open Question 1).**
  `3-0b/R23` (`decision-log.md:1688-1696`) ruled to KEEP the instant block-ENTRY pop, for a MECHANICAL
  reason, not an aesthetic one: `enter_block()` opens the 9-tick (0.15 s) deflect window on the entry
  tick itself, so a blend on entry would show a "shield still rising" pose while the deflect window is
  already live — "a legibility lie placed exactly where legibility is load-bearing" that would corrupt
  the parry read. `3-0b/R24` (`decision-log.md:1698-1707`), the SAME session, separately ruled that a
  blend on block EXIT is a "genuinely different, genuinely open case" and pre-recorded its conditions
  for a future story to pick up without re-deriving them: scoped to `block -> IDLE` ONLY
  (`block -> attack`/`block -> roll` must stay instant — they start real mechanical content
  immediately), and it requires amending `3-0a`'s "a transition arriving mid-clip wins immediately
  with NO blending" policy plus a conditional — living in `on_action_state_changed`'s non-CHARGING
  branch (`animation_controller.gd:396-398`, since that is where `BLOCKING -> IDLE` actually arrives),
  not a generic `_play()` change. The operator has ratified: AC 13 (originally AC 11)'s "block
  enter/exit gets transitions" text was DRIFT from R24's already-cleared exit-only shape, not an
  intentional supersession of R23 — ship EXIT-only blending on R24's pre-cleared terms and leave ENTRY
  instant. See AC 13 above for the settled text.

- **Hurt-reaction wiring (AC 1/AC 2).** `connect_hit_landed` (`match_runner.gd:1010`) already exists
  and is wired to `TelegraphController.on_hit_landed` at `match_runner.gd:506`
  (`.bind(slot)`, per-hero). `AnimationController` is NOT currently a consumer. Add a second
  subscription in the same per-slot wiring loop (`match_runner.gd:486-544`), gating on
  `target_slot == slot` exactly as the existing per-slot binds do — this grows the seam's CONSUMER
  count, not its member count; the ten-member `connect_*` family pin
  (`test_runner_observation_seams_are_exactly_ten`) is untouched. Payload
  `(attacker_slot, target_slot, damage, target_hp)` (`match_state.gd:30`) already carries enough:
  no widening needed for this AC.

- **`hit_react`/`get_up` cannot survive the controller as it stands without a state-scope rule (AC 2,
  round-1 gate B7).** `on_locomotion` calls `_play()` EVERY tick while `_state == IDLE`
  (`animation_controller.gd:448-458`), which would crossfade a freshly-started `hit_react` away one
  tick later on an IDLE victim, and a `_restart` over ATTACKING/ROLLING/CHARGING would replace the
  action clip with nothing to restore it afterward; during CHARGING, `on_charge_progress` seeks
  whatever animation is current (`:425`) and would scrub `hit_react` mid-play. AC 2 resolves this by
  scoping `hit_react` to IDLE-family victims only and giving both one-shots (`hit_react`, `get_up`) a
  locomotion-yield rule so `on_locomotion` does not steal them mid-play — no AnimationTree/additive/
  second-player layering (that would be a new pattern and a design question) is introduced by this
  story.

- **Distinguishing the three `STUNNED` flavors for presentation (AC 11) — the load-bearing "measure,
  don't assume" item.** `TimingWindow` (`src/state/timing/timing_window.gd`) carries NO reason field,
  only `_duration_ticks`/`_elapsed_ticks`/`is_running` — it is a pure counter by design (D4). Today
  `STUNNED` has exactly TWO inbound edges (`5-6/R3`'s own count), both direct `set_action_state`
  calls outside the `TRANSITION_TABLE`: the melee/unit deflect rung (`match_state.gd:1763`,
  `attacker.hero.stun.start(balance_ticks.deflect_stun_ticks)`) and the color-counter negation rung
  (`match_state.gd:~3418`, `player.hero.stun.start(balance_ticks.color_counter_stun_ticks)`). This
  story adds a THIRD (the knockdown rung, AC 3/AC 5/AC 6). The suite pins this count directly:
  `test_stunned_has_exactly_two_authored_non_table_entry_points`
  (`test_action_state.gd:122-147`) scans all of `src/`, strips comments, and asserts exactly two
  `res://src/state/match_state.gd` call sites — its own failure message already says a third site
  "must be argued, not merely added" (`:146`). This story's dev pass MUST amend that pin 2 -> 3, write
  the argument (this paragraph's own reasoning) into the test's doc-comment, and re-prove its falling
  mutation (delete the new write, confirm the count drops back to two and the assertion goes RED). No
  other `action_state == STUNNED`-keyed pin (the five refusal gates at `:2713,2886,2961,3054,3235`,
  the reset exception at `:4384-4386`, the movement root at `:3862`) needs changing — they key on
  state, not on stun kind, so knockdown passes through them unedited. `test_balance_authoring.gd`'s
  existing deflect-less-than-color-counter order pin (`balance_config.gd:326-331`'s comment) is the
  ASSERTION this story's dev pass must EXTEND to the full three-way bound (AC 4), pinned in TICKS. Two
  citation/wording sites drift, non-blocking, worth a Task line: the "SECOND (and last) authored
  inbound edge" comment (`match_state.gd:~1718`) and the "FIRST of exactly two" comment
  (`test_unblockable_defense.gd:433`; `match_state.gd:~3380`) both need updating for the third edge;
  and `balance_config.gd:320-332`'s own header comment reads as JUSTIFYING the two-durations-so-far
  naming precedent, not as anticipating a third — reword only if touched for the new field, not
  required on its own. `AnimationController.on_action_state_changed`
  (`animation_controller.gd:385-398`) is the seam that would select the clip, and it already receives
  a WIDENED, runner-computed, forwarded argument beyond the state-layer signal's own
  `(previous, current)` shape: `charge_color`, computed per-call by `_charge_color_for_slot`
  (`match_runner.gd:984`) and forwarded identically to both `cues.on_action_state_changed` and
  `anim.on_action_state_changed` at the two wiring closures (`match_runner.gd:501-504,541-544`) — the
  state-layer `action_state_changed` signal ITSELF never carries it (`hero_state.gd:15`,
  `(previous, current)` only). This is the exact, already-precedented, sanctioned shape the operator's
  scope named ("widening an existing signal's arity is the sanctioned shape — the `5-5`
  `deflect_landed` precedent — NEVER a new `MatchState` direct-connect"): a runner-side computed value
  forwarded as an extra positional argument, no new state signal, no new seam, no new hashed field.
  These closures alone, however, are INSUFFICIENT for the stun-reason forwarding mechanism: they fire
  only on a `STUNNED` entry (previous != STUNNED), never on the same-state (`STUNNED` -> `STUNNED`)
  escalation write AC 5 adds, since `set_action_state` on previous==current emits nothing
  (`hero_state.gd:211-212`).
  RECOMMENDED MECHANISM (dev-pass implementation choice, not a design decision — HOW, not WHAT): the
  mechanism must fire on BOTH triggers — a `STUNNED` entry (via the two closures above) AND a
  same-state escalation. The named candidate for the second trigger: since every knockdown arrives with
  a hit, re-check the stun flavor at `hit_landed` consumption, on the same FIFO drain that carries the
  (possibly deferred) landing package, whose internal order keeps the `STUNNED` write ahead of the
  `hit_landed` push (AC 6/AC 12) — comparing the
  running `stun.duration_ticks()` at that moment against the three
  known `BalanceTicks` constants (`deflect_stun_ticks`, `color_counter_stun_ticks`,
  `knockdown_stun_ticks`) and forwarding the matched reason as a widened argument, the same shape as
  `charge_color`. This is safe FROM COLLISION by construction because AC 4 already pins the three
  durations in strict directional order (knockdown > color-counter 1.0 s > deflect 0.4 s) — but note
  the fragility named honestly: if a future retune ever authors two of the three durations equal, a
  duration-only comparison breaks silently. Flagged, not solved, since retuning either existing value
  is out of this story's scope.

- **What plays today during `STUNNED` (measured, the `5-6` smoke never judged it).**
  `AnimationController._CLIP` (`animation_controller.gd:155-161`) maps `IDLE`/`ATTACKING`/
  `BLOCKING`/`ROLLING`/`DEAD` only. `on_action_state_changed`'s fallback
  (`clip: StringName = _CLIP.get(current, &"")`, then `if clip != &"": _restart(clip)`) means a
  transition INTO `STUNNED` selects an empty string and never calls `_restart` — the header comment
  says it outright (`animation_controller.gd:19`, "STUNNED alone stays unmapped (zero inbound edges)
  and leaves the current pose untouched"). Confirmed by `5-6/R10`'s own smoke-finding: "stun
  legibility (pose-hold, no dedicated clip) not assessed = retune/polish block" — this story is that
  discharge, per the epics.md committed-obligations line naming `6-6` as expected to discharge that
  entry (line 287-290, unedited here).

- **The hold/stretch mechanism for `stunned.fbx` (AC 10).** The `6-1b` precedent
  (`animation_controller.gd:175-226`) is PROGRESS-driven: a per-tick `on_charge_progress(color,
  progress)` push from the runner maps window progress to a held playhead second via
  `charge_playhead_seconds` and its per-clip `_CHARGE_HOLD_KNOBS`. `STUNNED` has no equivalent
  per-tick progress push today — it is a one-shot `on_action_state_changed` event. Two shapes fit
  "hold/stretch," both dev-pass calls within this story's scope (not a design question — the AC
  already commits to "held/stretched, never looped"): (a) play the clip once via `_restart`, then
  seek/pin to its own last frame once it naturally finishes and hold there for the remainder of the
  stun window (the simpler "hold" reading); or (b) compute a per-tick playback rate at entry —
  `clip_length_seconds / stun.duration_ticks() / TICK_HZ` — so the clip's own last frame lands
  exactly when `STUNNED` exits (the "stretch" reading, closer kin to `6-7b`'s per-family playback
  rate, `animation_controller.gd:497-502`). Knockdown's `knockdown.fbx` (AC 3) plausibly wants the
  same hold treatment while down, with `get_up.fbx` firing as an ordinary one-shot `_restart` — but
  ONLY on the timer-driven `STUNNED -> IDLE` exit (AC 8/AC 9): unlike the two existing stun kinds,
  where every `STUNNED` exit today fires the same unconditional `IDLE` re-entry with no distinction
  needed, knockdown's exit must distinguish the ordinary timer exit (plays `get_up.fbx`, arms the
  get-up iframe window) from the debug-reset exit (plays neither, per the operator's B9 ruling). The
  round-2 gate found this cannot be argued from "cleared on any exit / overwritten on every entry": the
  timer path (`match_state.gd:1112-1114`) and the reset path (`match_state.gd:4384-4386`) both queue an
  IDENTICAL `STUNNED -> IDLE` `set_action_state` write, and the controller holds the knockdown flavor
  across both — nothing in that write itself tells the two exits apart. The distinguishing mechanism is
  therefore a DEV-PASS FIND, not something this story's text can pin: a candidate is the reset path's
  own OTHER observable effects at the same drain (e.g. `round_started` also queued by
  `_apply_debug_reset`, or a controller-side marker set at reset time and consumed on the same drain) —
  not assumed here. Pinned by a REQUIRED controller integration test proving the timer exit plays
  `get_up.fbx` and arms the get-up iframes, while the reset exit plays neither (see Open Questions and
  Tasks below).

- **Block-impact wiring, and the mirror-vs-live-read pitfall (AC 12, round-1 gate B8).** The
  non-deflect block branch already exists (`match_state.gd:1766`,
  `damage *= balance.block_damage_multiplier`, immediately followed by the common
  `target.hero.take_damage(damage)` / `hit_landed` emit shared with every other hit). This branch is
  reached ONLY when `target.hero.action_state == BLOCKING` and facing (the guard at
  `match_state.gd:1701-1702`) and the deflect window did NOT open/spend — i.e. it is a SUBSET of the
  same `hit_landed` emissions AC 1's hurt-reaction wiring already observes. Clip selection MUST read
  the ANIMATION CONTROLLER'S OWN mirrored `_state` (`animation_controller.gd:337`, set at `:387`),
  never a live read of `hero.action_state` from the runner. The mirror is SAFE if it uses the
  controller's own FIFO-ordered queue (the runner forwards signals in the order emitted from ONE
  shared queue, `match_state.gd:408-412`, `player_state.gd:275` — a step-4 `hit_landed` drains before
  a step-8 `BLOCKING -> DEAD` write, so lethal chip damage still correctly selects `block_impact`). It
  is UNSAFE read live, the exact mistake `_charge_color_for_slot` makes for a different purpose
  (`match_runner.gd:984-990` — that value is the POST-advance state, wrong for this use). The mirror
  still misfires on the unblockable path specifically: the ladder's unanswered tier ignores block
  (`:3306-3307`), so an unanswered unblockable landing on a BLOCKING victim would emit `hit_landed`
  while the mirror still reads `BLOCKING`, selecting a stale `block_impact.fbx` for what is really a
  full-damage unblocked knockdown hit. FIX: the AC 3 knockdown `STUNNED` write precedes its
  `hit_landed` push WITHIN the landing package (damage application, the knockdown write, and the
  `hit_landed` push, internal order preserved), whether or not the package is deferred per the R-PRESS
  latch, on both seats, so the mirror has already advanced off `BLOCKING` by the
  time clip selection runs — do NOT widen `hit_landed`'s payload to carry a "this was unblockable"
  flag (`TelegraphController.on_hit_landed` has fixed arity 4 + a bound slot,
  `telegraph_controller.gd:210`, bound at `match_runner.gd:506`, and widening breaks that call site).
  "Mirrored `_state`, never a live read" is the wording to carry forward verbatim into both the Dev
  Notes here and the implementing Task. To be explicit about the R-PRESS latch's scope (AC 6): its
  unit of deferral is the WHOLE landing package, not the `STUNNED` write alone.

- **FBX import.** Five new source clips sit untracked in `assets/characters/paladin/`
  (`hit_react.fbx`, `stunned.fbx`, `knockdown.fbx`, `get_up.fbx`, `block_impact.fbx`) — the asset
  prerequisite is already met (precondition verified at this story's authoring). Follow the
  `tools/add_paladin_locomotion.gd` pattern exactly (EXTENDS the library, never rebuilds — 5-0a/6-7b
  precedent): a headless editor scan (`godot --headless --editor --quit --path .`) FIRST, to import
  the five FBX and generate their `.fbx.import` sidecars (no strip-hooks on any of the five — that
  wiring is reserved for the MODEL fbx only, `strip_model_anim.gd`, and none of the six existing clip
  FBXs carry one either); then a NEW headless tool (`tools/add_paladin_defense_reactions.gd` or
  similar), its own `NEW_CLIPS` matrix against the CURRENT clip library of eighteen —
  `EXISTING_CLIPS` there is TWELVE (`tools/add_paladin_locomotion.gd:70-74`) plus its own `NEW_CLIPS`
  of six (`:59-66`), eighteen total, not an eighteen-entry list at one citation — taking the library
  from eighteen to twenty-three. Loop flags (dev-pass call, not locked here): `hit_react` false
  (one-shot), `stunned` false (held, not
  looped — AC 10 pins this), `knockdown` false (held while down, same reasoning), `get_up` false
  (one-shot on exit), `block_impact` false (one-shot reaction). `git diff -- project.godot` after
  EVERY editor session, with surgical restore of any collateral drift (never a wholesale revert) —
  the `6-7b` precedent named six prior recorded incidents of the `physics_ticks_per_second` pin being
  silently deleted by an editor session. Record each clip's Hips translation/yaw findings per clip in
  the `6-7b` table shape (`6-7b-locomotion-presentation.md:594` onward) — measure, do not assume, that
  none of the five reaction clips carries an unwanted root translation/rotation that would fight
  `HeroActor.drive()`'s own single yaw write (DECISION A) or produce a root-slide artifact, exactly
  the check `3-0b`'s roll-Hips fix and `6-7b`'s turn-neutralization both existed to make.

- **Minion guard re-run (Non-Goals).** `4-3b/R7` ("deflecting a minion does NOT stun it, for now") is
  structural, not merely a gate — a unit has no `ActionState` and no `stun` window to enter. The
  existing negative test guarding it re-runs unedited as this story's own proof nothing here widens
  minion reach into the stun/reaction system.

### Project Structure Notes

- Of the thirteen ACs, presentation-only work (`src/actors/hero/animation_controller.gd` and the
  `match_runner.gd` wiring loop, no `src/state/` edit) covers AC 1, AC 2, AC 10, AC 11, AC 12 and
  AC 13. State-layer edits land in AC 3 (the knockdown write itself), AC 4 (the new authored
  `BalanceConfig`/`BalanceTicks` fields — `BC/R3`-isolated from the golden and unit suite, but still a
  `src/state/` addition, not presentation), AC 5 (the CHARGING-abandonment cleanup and the
  STUNNED-escalation write), AC 6 (the simultaneous-trade fix and its expected latch), AC 7 (the
  floor-rule guard) and AC 8 (the get-up-iframe `TimingWindow` addition and its arming). AC 9 (the
  reset exception) is also state-layer. The
  presentation half follows the `3-0a`/`5-0a`/`6-7b` split exactly: clip selection and hold/stretch
  logic in `src/actors/hero/animation_controller.gd`; new seam CONSUMERS (not new seams) wired in
  `src/main/match_runner.gd`'s existing per-slot loop. The state-layer edits
  (AC 3/AC 5/AC 6/AC 7/AC 8/AC 9) land in `src/state/match_state.gd`'s existing unblockable-ladder
  resolution function and its reset path, plus the AC 8 get-up-iframe `TimingWindow` addition on
  `HeroState`/`PlayerState`. AC 4's two new fields land in
  `src/state/resources/balance_config.gd`/`src/state/timing/balance_ticks.gd` —
  `knockdown_stun_seconds`/`knockdown_stun_ticks` and the get-up-iframe duration — on the
  `color_counter_stun_seconds`/`deflect_stun_seconds` naming precedent. Note the precedent's own
  comment (`balance_config.gd:320-332`) JUSTIFIES naming once two durations already exist; it does not
  itself anticipate a third — read it as precedent, not as forward anticipation. No new top-level
  folder is implied by anything measured above.

### Project Context Rules

- F1: exactly one `func _physics_process` in `src/`, in `match_runner.gd` — no new process callback;
  every new push (hurt/block/stun clip selection) rides an existing seam or the existing per-tick
  locomotion push.
- D3(a): `Input.*` only under `src/controllers/` — untouched by this story, no new input.
- D3(b)/A2: no global RNG / `Time` / `OS` / `Engine`, and no live scene/camera query, inside
  `src/state/` — the knockdown write (AC 3/AC 5/AC 6) is a plain
  `set_action_state`/`TimingWindow.start()` call, identical in shape to the two existing stun-entry
  sites; the AC 8 get-up-iframe window is the same plain `TimingWindow` shape. Nothing either adds
  needs a new scene/camera query from state.
- Docs and code never share a commit; commit messages are pure ASCII via `git commit -F <tempfile
  outside the repo>`; shell is PowerShell 5.1 (no `&&`); trailer per this repo's current convention —
  VERIFY at dev-pass time against the live `CLAUDE.md`/session attribution instructions, since the
  trailer identity has changed between stories in this project's history and `project-context.md`'s
  own text ("Claude Opus 4.8... a repo-wide constant") is not assumed current without a fresh check.
- Story tier: A, fixed at authoring (board split ruling, Dev Notes above) — full gate + review + live
  smoke ritual, may be raised, never lowered (`CLAUDE.md` Story tiers).
- Validation that proves something worth proving gets committed as a test, never written-then-deleted
  (`CLAUDE.md`).
- `PROC/R1`: two full suite runs (dev-pass start and end), mutation proofs run only the affected test
  file. `PROC/R7`: state the budget and its tripwire at dev-pass start. `PROC/R8`: legibility/feel
  claims (the block entry/exit question, the stun hold read) route to operator smoke — see Live
  Smoke section above.

### References

- [Source: decision-log.md, Session 2026-09-08 `E6-P/R2`, epics.md:234,287-290] — `6-6`'s key, tier,
  and the "expected to discharge the defense-feel retune entry in passing" obligation this story
  inherits.
- [Source: decision-log.md, Session 2026-09-14, `6-3-split/R-SPLIT`] — the split-story precedent this
  board edit follows (docs-only recording, split ruling shape, NOT the epics.md-edit half of that
  precedent — see Docs Debt).
- [Source: decision-log.md, Session 2026-09-07, `5-6/R1`-`R10` close-out] — the three-tier ladder,
  the two existing stun kinds and their authored durations, the `STUNNED` contract this story extends
  with a third entry.
- [Source: decision-log.md, `3-0b/R23`-`R24` (2026-08-02)] — the block-entry-pop KEEP verdict and its
  mechanical reasoning, and the pre-cleared exit-only blend conditions this story's AC 13 must be
  reconciled against.
- [Source: decision-log.md, Session 2026-08-31/2026-09-09, `6-1b` close-out] — the hold/stretch,
  single-frame-hold precedent for a non-looping reaction clip.
- [Source: src/state/hero_state.gd:15,27,118-131,352] — `ActionState` enum, `action_state_changed`
  signal shape, the `stun` `TimingWindow`, `STUNNED`'s movement-root entry.
- [Source: src/state/match_state.gd:1690-1764 (deflect stun entry), :3340-3430 (three-tier ladder,
  color-counter stun entry; the unanswered-tier exit write this story edits is at :3475), :2827,
  2713-2962 (`REASON_STUNNED`, the five cast-seat refusal gates at :2713,2886,2961,3054,3235),
  :4373-4386 (fifth reset exception; the header enumerating all six existing exceptions runs
  :4279-4317), :30 (`hit_landed` signal shape)] — every site this story's dev pass reads or edits.
- [Source: src/state/resources/balance_config.gd:307,320-332; src/state/timing/balance_ticks.gd:81-87,
  169-170; data/balance/balance_config.tres:123,127-128] — the existing two stun durations/ticks and
  the naming precedent the new field follows.
- [Source: src/state/timing/timing_window.gd] — confirms no reason field exists on the primitive; the
  duration-comparison mechanism this story's Dev Notes recommend works around that absence.
- [Source: src/actors/hero/animation_controller.gd:1-27 (header, STUNNED unmapped),
  155-161 (`_CLIP`), 175-226 (`6-1b` hold mechanism), 385-398 (`on_action_state_changed`),
  489-502 (`6-7b` playback-rate precedent), 543-558 (`_play`/`_restart`)] — the presentation seam
  this story's dev pass extends.
- [Source: src/main/match_runner.gd:486-544 (per-slot wiring loop), 984 (`_charge_color_for_slot`,
  the widened-forwarded-argument precedent), 1005-1029 (`connect_hit_landed`/`connect_deflect_landed`
  wrappers)] — the wiring shape new consumers follow.
- [Source: tools/add_paladin_locomotion.gd (whole file)] — the FBX-import tool pattern (`NEW_CLIPS`/
  `EXISTING_CLIPS`, extend-never-rebuild, headless invocation, idempotent replace).
- [Source: docs/implementation-artifacts/6-7b-locomotion-presentation.md:594-637 (Hips measurement
  table shape), 785 (FBX asset-prerequisite recording precedent)] — the measurement-table format this
  story's dev pass follows for the five new clips.
- [Source: docs/implementation-artifacts/3-0b-feel-and-timing-tuning.md:92] — the AC7 verdict text
  verbatim, cross-referenced against decision-log `3-0b/R23`/`R24`.

## Open Questions

1. **RESOLVED at the round-1 gate.** Block entry blending was DRIFT from `R24`'s exit-only shape, not
   an intentional supersession of `3-0b/R23` — ENTRY stays instant, only EXIT blends. See AC 13 and
   the resolved Dev Notes entry above.
2. **Hold vs. stretch for `stunned.fbx`/`knockdown.fbx` (AC 10/AC 3).** Two mechanisms sketched in Dev
   Notes (restart-then-pin-last-frame vs. a computed hold-duration playback rate); a dev-pass call,
   confirmed at live smoke against the felt read.
3. **The stun-reason forwarding mechanism's exact shape (AC 11).** The mechanism MUST fire both on a
   `STUNNED` entry AND on a same-state (`STUNNED` -> `STUNNED`) escalation — the two existing
   `on_action_state_changed` closures alone are insufficient, since `set_action_state` on
   previous==current emits nothing (`hero_state.gd:211-212`) and an ordinary-stun -> knockdown write is
   exactly such a same-state write (AC 5). The named candidate: since every knockdown arrives with a
   hit, re-check the stun flavor at `hit_landed` consumption (reading the forwarded reason/duration off
   the running `stun` window at that moment), on the same FIFO drain that also carries the (possibly
   deferred, AC 6/AC 12) landing package, whose internal order keeps the `STUNNED` write ahead of the
   `hit_landed` push. Duration-threshold comparison
   in ticks (recommended) vs. some other widened-argument shape achieving the same "no new hashed
   field, no new seam" property — exact wiring is a dev-pass call within the sanctioned widening-arity
   constraint; the escalation-visibility test (AC 5) is REQUIRED either way.
4. **RESOLVED at the round-1 gate.** Coverage-by-suite is accepted; the golden fixture is NOT
   extended. See the Golden Prediction section's fixture-coverage paragraph above.
5. **`knockdown_stun_seconds`'s exact provisional value**, subject only to the directional bound (AC
   4) — dev-pass/live-smoke tuning call, not a design decision.
6. **The get-up-iframe duration's exact provisional value (AC 8)**, tied to the measured length of
   `get_up.fbx` — dev-pass measurement, confirmed at live smoke.
7. **Which struct owns the AC 8 get-up-iframe `TimingWindow` — `HeroState` or `PlayerState`** — a
   dev-pass call on the `5-5` `defense_window` precedent, to be argued in the Golden Prediction/
   replay-identity rewrite at implementation time.
8. **The AC 6 same-tick press/knockdown ordering fix's exact mechanism** — operator ruling
   **R-PRESS** pins the OUTCOME (seat-symmetric: the press resolves first, the knockdown write then
   overwrites) but leaves the MECHANISM a dev-pass choice: an ordering/scheduling change needing no
   new storage, vs. a deferred-package latch (a new `src/state/` var owing its own replay-identity
   bucket classification, the `_iframe_open_at_step3` precedent). Golden Prediction cause 4's latch
   clause is now EXPECTED rather than conditional — if the dev pass instead finds a no-new-storage
   ordering fix, that expectation simply discharges and cause 4 is closed out as such.
9. **The reset-exit-vs-timer-exit distinguishing mechanism for `get_up.fbx`/iframe-arming (AC 8/AC
   9)** — round-2 gate finding: both exits queue an identical `STUNNED -> IDLE` write
   (`match_state.gd:1112-1114` and `:4384-4386`), so nothing in that write itself tells them apart.
   A dev-pass find (candidate: the reset path's own other observable effects at the same drain, or a
   controller-side marker consumed on the same drain), pinned by a REQUIRED controller integration
   test proving the timer exit plays `get_up.fbx` and arms iframes while the reset exit plays neither.

## Tasks / Subtasks

- [x] FBX import: headless editor scan for the five new clips; `git diff -- project.godot`,
      surgical restore of any collateral drift; Hips translation/yaw measurement table per clip
      (AC: asset prerequisite).
- [x] Build `tools/add_paladin_defense_reactions.gd` (or extend the existing tool) on the
      `add_paladin_locomotion.gd` pattern; library eighteen clips -> twenty-three (AC: asset
      prerequisite).
- [x] Wire `AnimationController` as a second `connect_hit_landed` consumer, gated on
      `target_slot == slot`; select `hit_react.fbx` vs `block_impact.fbx` by the CONTROLLER'S OWN
      mirrored `_state` at signal-consumption time, never a live `hero.action_state` read (AC 1, AC 2,
      AC 12). Add an integration test on the `test_hero_clip_selection.gd` shape covering the
      IDLE-family scoping and the locomotion-yield rule (round-2 gate B7, AC 2).
- [x] Give `hit_react.fbx`/`get_up.fbx` their locomotion-yield rule so `on_locomotion`'s per-tick
      `_play()` does not steal either clip mid-play; scope `hit_react` to IDLE-family victims only
      (AC 2).
- [x] Add the third `STUNNED` inbound edge (knockdown) at the unanswered-tier exit of the
      three-tier ladder in `match_state.gd`, as the VICTIM's own separate write (never replacing the
      caster's trailing `IDLE` exit at `:3475`), gated on `target.hero.is_alive()` after
      `take_damage` (AC 3).
- [x] Ensure the knockdown `STUNNED` write precedes its `hit_landed` push WITHIN the landing package
      (damage application, the knockdown write, and the `hit_landed` push, deferred or not, as one
      unit — the R-PRESS latch's unit of deferral, AC 6), so the mirrored `_state` block-impact
      selection (above) does not misfire on an unanswered unblockable landing on a blocking victim
      (AC 3, AC 6, AC 12).
- [x] Amend `test_stunned_has_exactly_two_authored_non_table_entry_points`
      (`test_action_state.gd:122-147`) 2 -> 3 call sites, write the argument into its doc-comment,
      and re-prove its falling mutation; update the two drifted "SECOND (and last)"/"FIRST of exactly
      two" comments (`match_state.gd:1717`, `test_unblockable_defense.gd:433`, `match_state.gd:~3380`)
      (AC 3, round-1 gate B2).
- [x] Enumerate the knockdown victim's prior-state results (IDLE, ATTACKING, BLOCKING, ROLLING,
      CHARGING, and STUNNED split into its two R-STUNSTACK sub-cases), one test per state/sub-case; on
      CHARGING, clear `charge_window`, `landing_window` and `charge_color` on the knockdown write, the
      `6-1` feint-teardown shape verbatim (`match_state.gd:1175-1179`) — leaving `_charge_reach`/
      `_charge_contact_dirs` untouched, per their own `6-1d/R9` discipline — while leaving the spent
      card/stamina unrefunded; on the ordinary-stun sub-case, prove the escalation to knockdown is
      visible (clip switches, window extends) (AC 5).
- [x] Implement the same-tick press/knockdown ordering fix (seat-symmetric outcome per R-PRESS: press
      resolves first, knockdown write then overwrites) and the simultaneous-landing trade fix
      (seat-symmetric, both land, both go down) with its both-slots test on the
      `_iframe_open_at_step3` shape (latch documented at `match_state.gd:298-325`, both-slots
      precedent `test_the_dodge_boundary_is_identical_on_both_slots`,
      `test_unblockable_defense.gd:701`); classify any new storage the press fix needs per Open
      Question 8, and resolve Golden Prediction cause 4's now-expected latch clause definitely one way
      or the other at close-out (AC 6).
- [x] Implement the floor rule (a hit on an already-downed hero deals damage, never restarts/extends
      the running window) and the get-up-iframe `TimingWindow` armed only on the timer-driven exit,
      reusing the `roll_iframe` mechanism's shape and registering wherever `roll_iframe` does so it
      also guards against unblockables (R-IFRAME-UNBLOCKABLE) (AC 7, AC 8).
- [x] Implement the reset exception: no `get_up.fbx`/iframe-arming on the debug-reset exit; clear the
      AC 8 window on that exit as the SEVENTH reset-exception line item alongside the existing six
      (`match_state.gd:4279-4317`, updating the header's "SIX named exceptions" line to SEVEN), traced
      the `5-6` way (AC 9).
- [x] Find and pin the reset-exit-vs-timer-exit distinguishing mechanism (Open Question 9, round-2
      gate finding): both exits currently queue an identical `STUNNED -> IDLE` write
      (`match_state.gd:1112-1114`, `:4384-4386`), so the distinction must come from something else
      (a candidate: the reset path's own other observable effects at the same drain, or a
      controller-side marker). REQUIRED controller integration test proving the timer exit plays
      `get_up.fbx` and arms iframes while the reset exit plays neither (AC 8, AC 9).
- [x] Add `knockdown_stun_seconds`/`knockdown_stun_ticks` and the get-up-iframe duration field to
      `BalanceConfig`/`BalanceTicks`; extend `test_balance_authoring.gd`'s deflect-less-than-
      color-counter pin to the full three-way bound, asserted in ticks (AC 4, round-1 gate B2/N9).
- [x] Wire the stun-reason forwarding mechanism (Open Question 3) so it fires on BOTH a `STUNNED`
      entry (alongside `charge_color` at the two existing `on_action_state_changed` closures) AND a
      same-state escalation (the `hit_landed`-driven flavor re-check is the named candidate); add the
      escalation-visibility test required by AC 5 (AC 5, AC 11).
- [x] Map `STUNNED` in `AnimationController._CLIP`/a parallel table to `stunned.fbx`
      (color-counter/deflect) or `knockdown.fbx` (knockdown), by the forwarded reason; resolve Open
      Question 2 (hold vs. stretch) (AC 10, AC 11).
- [x] Wire `get_up.fbx` on the timer-driven `STUNNED -> IDLE` exit transition only, when the exited
      flavor was knockdown (AC 8, AC 9).
- [x] Implement the AC 13 block-exit-only blend: the conditional in `on_action_state_changed`'s
      non-CHARGING branch, scoped to `block -> IDLE` only; leave block ENTRY as an instant `_restart`
      (AC 13).
- [x] Enumerate expected test fallout at dev-pass start-run: suites that land unblockables and keep
      driving the target may move once the target now stuns —
      `test_unblockable_hold.gd`, `test_unblockable_tracking_and_reach.gd`,
      `test_unblockable_initiation.gd`, `test_orbs_economy.gd` (grep for landing helpers); the Golden
      Prediction above names only `test_unblockable_defense.gd` as certain (round-1 gate N2).
- [x] Full suite before/after; golden hash and snapshot key set measured both directions (Golden
      Prediction); `FORMAT_VERSION` measured and stated, not assumed; mutation-proof every new
      knockdown-path test and the new `BalanceConfig` fields' bounds.
- [ ] `[3, 3]` two-pad live smoke (name the reachable `[0, 3]` subset if unavailable), recorded in
      `docs/playtest-log.md`, including the simultaneous-trade and floor-hit items.

### Review Findings

Code review 2026-09-17 (gds-code-review, Claude Opus 5; the Blind Hunter, Edge Case Hunter and
Acceptance Auditor layers all returned). The review covered `4507560..e356a2a`. Verdict: **CHANGES
REQUESTED**, on D1 alone. Everything else is approved with findings. Counts: 3 decision_needed,
6 patch (all fixed in this pass), 7 defer, 11 dismissed as noise.

- [x] [Review][Decision] **D1 (High) An unblockable can land on the knockdown's EXACT exit tick,
  knocking the hero straight back down.** All three layers found this independently. -- RESOLVED
  `880c63d`, operator ruling option (a), the exit tick is part of the get-up: the step-3 latch also
  reads `_gets_up_this_tick` (STUNNED, `stun` not running, `is_knockdown_stun`, `get_up_iframe_ticks >
  0`), no new storage; both-slots boundary test pins exit tick = dodged, one tick earlier = lands on
  the floor rule.
  - **Mechanism.** `_iframe_open_at_step3` latches for both seats (`match_state.gd:561-562`) before
    either seat's `_resolve_actions`. The get-up window only starts inside the victim's STUNNED arm,
    so a landing on the exit tick reads a false latch and is unanswered. At step 6b the victim is
    already IDLE, so `already_down` is false and the knockdown is written again.
  - **Consequences Dev Note 1 does not mention.**
    - The re-downed hero keeps its running get-up window, 122 of the next 150 ticks. `is_iframe_open()`
      then drops every melee and unit fact and dodges any unblockable while they are DOWN.
    - The two attack types disagree on the exit tick itself: step-4 melee reads the live predicate
      and is dropped, but the unblockable is not.
    - It repeats. An attacker who lands every exit tick keeps the victim down, taking unblockable
      damage each cycle. It is frame-exact and costs a card plus stamina per cycle.
  - **Why this is not outside the ACs.** It contradicts AC 5's "no knockdown lock results, by
    construction" and AC 8's R-IFRAME-UNBLOCKABLE rationale, "nothing can be timed into the get-up".
    The counter-precedent is `5-6`'s "roll pressed on the landing tick dodges on neither slot", but a
    get-up is a timer, not a press.
  - **Options.**
    - **(a) Recommended.** Widen the step-3 latch so a hero whose KNOCKDOWN stun ran out at this tick's
      step 2 counts as iframed: STUNNED, `stun` not running, `is_knockdown_stun(duration)`, and
      `get_up_iframe_ticks > 0`. This needs no new storage, stays seat-symmetric because it latches
      before both seats, and matches what step 4 already does for melee. It needs a both-slots
      boundary test (a landing on the exit tick is dodged; the exit tick minus one still lands and
      hits the floor rule).
    - **(b)** Accept and record the 1-tick seam as ruled.
  - **This review changed nothing here: it is a boundary-semantics call.**
- [x] [Review][Decision] **D2 (Med) `block_impact` plays on a FULL-damage hit from outside the block
  arc** (Dev Note 3). This is inside AC 12's scope, and the spec premise behind it is wrong. --
  RESOLVED `149da25` + `4fcf791`, operator ruling option (b), a runner-forwarded discriminator: the
  step-4 `hit_landed` is queued through `_emit_hit_landed`, which raises the PER_TICK
  `_hit_landed_blocked` for that one emission; the rig closure forwards `hit_landed_was_blocked()`
  beside the unchanged 4-arg payload. `block_impact` plays only for a blocked hit; an out-of-arc hit
  on a blocker plays NOTHING (BLOCKING is not IDLE-family, AC 2 -- the mid-action outcome).
  - AC 12 scopes `block_impact` to "a blocked hit (the non-deflect block branch)". The Dev Notes
    treat mirrored `BLOCKING` and the blocked branch as the same set, but the `_is_facing` guard
    (`match_state.gd:1744-1745`) splits them.
  - The player sees "blocked" feedback for an unblocked hit, which is exactly the read this story
    targets.
  - The controller cannot tell the two apart without the widened `hit_landed` that AC 12 forbids.
  - **Options.** (a) Accept for now and judge at smoke. (b) Rule a sanctioned discriminator: a
    runner-forwarded value, on the `stun_flavor` shape, forwarded beside the unchanged payload.
- [ ] [Review][Decision] **D3 (Med) The get-up iframes do not end when the hero acts** (Dev Note 5).
  - For 2.03 s the hero can attack, cast or charge while melee is dropped and unblockables are
    dodged.
  - This matches AC 8 as locked ("no early-stop path"), so it is not a defect. It is a feel and
    tuning call, and changing the shape re-opens AC 8's text.
  - Route: `[3, 3]` smoke first; if it is too strong, rule either a shorter window or an early stop
    on action.
- [x] [Review][Patch] The classifier's reload fragilities were named in one direction only
  [src/state/timing/balance_ticks.gd:143] -- fixed `e64286e` (comment only). A live reload can
  reclassify an IN-FLIGHT stun in either direction, on the state side and so in replay:
  - Lowering the knockdown count floors an ordinary stun and arms get-up iframes on its exit.
  - Raising or zeroing the count un-floors a knockdown.
  - The `get_up` clip is coupled to `get_up_iframe_ticks > 0`.
- [x] [Review][Patch] AC 5 CHARGING row never asserted that `_charge_contact_dirs` survives the teardown
  [test/state/test_unblockable_defense.gd] -- fixed `824438f`. Mutation MR1 (clear it in the teardown)
  turns the test RED.
- [x] [Review][Patch] AC 5 ATTACKING row had no landing-tick precondition; a shortened fixture windup
  would silently turn it into a second IDLE row [test/state/test_unblockable_defense.gd] -- fixed
  `824438f`.
- [x] [Review][Patch] AC 12 package order was pinned only for victim slot 1
  [test/state/test_unblockable_defense.gd] -- fixed `824438f` (both victim seats). Mutation MR2 (slot-1
  package pushes `hit_landed` before its write) turns it RED.
- [x] [Review][Patch] AC 8 melee fact drop during the get-up iframes was covered only indirectly, and
  its +1 grace term was UNPINNED [test/state/test_roll_iframes.gd] -- fixed `824438f`.
  - MR3 (get-up removed from `is_iframe_open`) turns this test plus two existing tests RED.
  - MR4 (grace term removed) turns ONLY the new test RED, which proves the gap was real.
- [x] [Review][Patch] AC 13 `block -> roll` instant cut unpinned; the `block -> attack` check lacked a
  distinguishability guard [test/integration/test_hero_reaction_clips.gd] -- fixed `5eee33e`
  (presentation, not mutation-run).
- [x] [Review][Defer] A defense card cast on (or before) the landing tick stays armed through the
  knockdown, so a downed hero can colour-counter [src/state/match_state.gd `_apply_landing_packages`] --
  deferred to smoke. It is consistent with the `5-6` STUNNED contract ("running windows tick out") and
  is asserted by the R-PRESS test.
- [x] [Review][Defer] `block_impact`'s held final frame stands in for the block pose for the rest of the
  hold. The only evidence that it matches is Hips-only (Y 0.6915 / yaw -67.03 at both ends); the arms
  and shield were not measured [src/actors/hero/animation_controller.gd:501] -- deferred to smoke.
- [x] [Review][Defer] A hero moving during `get_up`/`hit_react` slides in the one-shot pose until it
  ends. The yield is mandated by AC 2 [src/actors/hero/animation_controller.gd:533] -- deferred to smoke.
- [x] [Review][Defer] With `dodged_unblockable_damage_multiplier > 0` (authored 0.0), a landing dodged
  by the get-up iframes would deal chip damage and cut `get_up` with `hit_react`
  [src/state/match_state.gd dodge rung] -- deferred. This is a retune-only hazard; the dodge rung is
  `5-6`'s.
- [x] [Review][Defer] The knockdown-last / get_up-first Hips junction is measured (0.0067 planar) but
  not pinned [test/integration/test_clip_timing.gd] -- deferred.
- [x] [Review][Defer] `debug_window_ticks_remaining()` omits the get-up window (Dev Note 6)
  [src/state/match_state.gd:1085] -- deferred.
- [x] [Review][Defer] The `test_replay_identity.gd` `_iframe_open_at_step3` comment still says "STAYS AT
  THREE" beside the current 4 [test/state/test_replay_identity.gd] -- deferred, pre-existing.

**Special-attention items verified sound (no finding):**
- **R-PRESS seat symmetry at step 6b.**
  - The latch is taken before both seats.
  - There is no `return` between step 3 and 6b, so `_landing_package_pending` is truly PER_TICK.
  - Steps 4-6 see the pre-package victim on both seats.
  - The two packages are independent: each reads and writes only its own victim.
  - The only seat-ordered output is the P1-then-P2 `hit_landed` push order, which only per-slot
    consumers observe.
  - No other consumer of step-3 state observes a seat-dependent intermediate. Moving the damage off
    the caster's seat REMOVED one: a victim's step-3 liveness no longer depends on which seat cast.
- **AC 12 through the deferred package.** The order holds on both seats (now pinned). The lethal
  landing on a blocker behaves as the story's note predicts: `block_impact`, then `death`, on the
  same drain, never rendered.
- **AC 8/AC 9 `_get_up_armed_for_slot` ("running with nothing elapsed").** It is sound across every
  interleaving checked:
  - An ordinary stun ending inside a running get-up window. Live phase 6 genuinely sets this up: a
    deflect stun of about 24 ticks inside a 122-tick window, with a "still running" setup check, and
    P13 is a real mutation.
  - A re-knockdown on the exit tick: `get_up`, then `knockdown`, on one drain, and the final clip is
    correct.
  - A reset at step 1, which stops the window before any timer exit.
  - A round-over freeze after the exit tick.
  - A 1-tick window.
  - The runner drains once per `advance()` (`match_runner.gd:2749/2892`).

  Its only coupling is `get_up_iframe_ticks == 0`, now named in the doc and audit-pinned `> 0`.
- **`is_knockdown_stun`.**
  - The named fragilities are accurate. The UNNAMED ones were the lower and zero reload directions
    and the `get_up` coupling (fixed above, as documentation).
  - D4 guarantees in-flight windows keep their duration, which is exactly what makes a reload
    reclassify them.
  - Reloads are recorded, so replay stays deterministic.
- **Knockdown Hips pin.**
  - `duplicate(true)` precedes `_pin_hips_planar`, and the source FBX take is untouched.
  - `_66a-hips-after.txt` shows a non-zero `maxPosDiff` on `knockdown` only (0.695938, the removed
    travel) and 0 on every other clip.
  - `test_clip_timing.gd` would catch a rebuild without the pin (the source's peak planar travel,
    0.61, is over the 0.25 ceiling).
- **Golden accounting.**
  - 198 -> 206 key paths = 2 x (`get_up_iframe` + 3 children).
  - `FORMAT_VERSION` 11 was read in `_66a-golden-after.txt`.
  - The resting-key pin is in place.
  - The replay buckets are correct (`get_up_iframe` HASHED; `_get_up_iframe_closed_this_tick` and
    `_landing_package_pending` PER_TICK).
  - The isolation probe was a scratch run and was taken from the dev record, not re-derived.
- **Dev-flagged edge behaviours.**
  - Note 1 is INACCURATE BY OMISSION: see D1.
  - Note 2 (roll iframes continue while down) is accurate and harmless (`1-9/R3`).
  - Note 3 is inside AC 12: see D2.
  - Note 4 is accurate on HP but incomplete. On the landing tick, an ATTACKING victim's live hitbox
    still reaches the caster at step 4, and step-5 regen/mana is evaluated before the knockdown.
    Dodged-rung damage still applies at step 3 while unanswered damage applies at 6b. All of this is
    harmless to the ACs, and consistent with R-PRESS.
  - Note 5 is accurate: see D3.
  - Note 6 is accurate: deferred.

**Review runs, disclosed.**
- **Scratch runner.** Affected files only (`test_unblockable_defense.gd` + `test_roll_iframes.gd`, and
  `test_hero_reaction_clips.gd`), green before any mutation.
- **Mutations** MR1-MR4, each restored from an out-of-repo copy with SHA256 re-verified (log:
  `C:\dev\_66a-review-mutations.txt`). One run is DISCARDED: MR3's first substitution did not apply,
  so it ran unmutated code; it was re-run with a working edit.
- **Full suite, one pass on the final tree, two invocations.**
  - State harness: **891 / 0 / 7244** (`C:\dev\_66a-review-state.txt`).
  - Integration: **65 / 65** (`C:\dev\_66a-review-integration.txt`).
  - Delta from the dev pass's 890 / 7235: +1 test, +9 assertions.
- **Golden, snapshot keys and `project.godot`:** not touched by the review commits.
- **Board and status.** `sprint-status.yaml` is untouched (`CFG/R2`/`R4`: board promotion is the
  operator's). The story Status stays `review` pending the operator's rulings on D1-D3, rather than
  the skill's default `in-progress`.

## Change Log

| Date | Change | Author |
|---|---|---|
| 2026-09-17 | Story authored via gds-create-story from the board split of `6-6-defense-presentation` (operator ruling, scope talk 2026-09-17). Status `authored`, awaiting operator review before promotion to `ready-for-dev`. | Claude Sonnet 5 |
| 2026-09-17 | Readiness gate 1 findings B1-B10 applied, with operator rulings on B3 (simultaneous-trade seat-symmetry), B4 (CHARGING knockdown abandons the chargeup), B5 (floor rule, no knockdown upper bound, get-up iframes), B7 (hit_react state-scope, unvetoed), B9 (no get_up/iframe on debug reset, unvetoed). Acceptance Criteria rewritten and expanded 11 -> 13 (merges per N4, new ACs for B3-B9); Golden Prediction cause 1 corrected (target-side write, not a replacement of the caster's IDLE exit) and cause 4 rewritten (a definite new get-up-iframe `TimingWindow`, a conditional new var for a B3 latch); fixture-coverage flag (OQ 4) and block-entry OQ (OQ 1) resolved; Live Smoke rewritten for the `[0, 3]` deviation's reachable subset and the new trade/floor items; citation and line-number drift from the gate's N3 sweep corrected throughout. Status remains `authored`; not promoted. | Claude Sonnet 5 |
| 2026-09-17 | Readiness gate 2 residuals applied, plus three operator rulings (R-STUNSTACK, R-PRESS, R-IFRAME-UNBLOCKABLE): AC 5's STUNNED prior-state row split into the ordinary-stun-escalates and already-knocked-down sub-cases; AC 6's same-tick press paragraph rewritten seat-symmetric, deleting the false "existing, unedited seat-order behavior" claim; AC 7 scoped explicitly to the knockdown flavor only; AC 8 gains the get-up-iframe-vs-unblockable ruling; AC 9's reset exception corrected to the SEVENTH (not sixth) and its flavor-memory wording corrected to route through the stun-reason forwarding mechanism, not an entry signal; AC 12 rewritten to name the actual outcome (knockdown presentation, not hit_react) with a non-blocking lethal-chip note; Golden Prediction cause 4's latch upgraded from conditional to expected and FORMAT_VERSION corrected to a STAY-11 prediction; the AC 5 CHARGING cleanup corrected to mirror the actual `6-1` feint-teardown fields; a new Open Question and Task added for the reset-vs-timer-exit distinguishing mechanism (round-2 gate finding); an integration test added to AC 2's Task; Project Structure Notes and multiple citations (feint teardown, FIFO queue site, refusal-gate count, reset-exception line range, `on_action_state_changed`/`_state` line numbers, both-slots test) corrected throughout. Status remains `authored`; not promoted. | Claude Sonnet 5 |
| 2026-09-17 | Readiness gate 3 residuals applied: the escalation mechanism's dual-trigger shape (STUNNED entry and same-state escalation, with the hit_landed re-check named for the second trigger) written out explicitly in AC 11/Dev Notes/Open Question 3; AC 12, its Task, and AC 6 rewritten to the landing-package ordering (the STUNNED write precedes its hit_landed push WITHIN the landing package, not a standalone reorder); the smoke block-impact item's clip expectation corrected, a stale citation fixed, and Project Structure Notes wording aligned. Status remains `authored`; not promoted. | Claude Sonnet 5 |
| 2026-09-17 | Readiness gate 4 wording residuals applied: the Live Smoke block item's self-contradiction resolved (block_impact.fbx confirmed on an ordinary non-deflected melee hit only; the unblockable-on-blocker case split into its own sentence expecting knockdown presentation, matching AC 12); Dev Notes aligned to the landing-package deferral unit in three places (the forwarding paragraph, Open Question 3, and the block-impact paragraph's fix description), plus an explicit sentence stating the R-PRESS latch's unit of deferral is the whole landing package, not the STUNNED write alone; two leftover phrasings corrected ("its possible latch" -> "its expected latch"; "deferred-write latch" -> "deferred-package latch" at Golden cause 4 and Open Question 8). Promoted to `ready-for-dev`. | Claude Sonnet 5 |
| 2026-09-17 | Dev pass (gds-dev-story): five FBX imported, library 18 -> 23 (`knockdown` Hips planar pinned, `3-0b/R27` route); knockdown as the third `STUNNED` inbound edge on the victim, applied through a deferred per-tick landing package at a new step 6b (R-PRESS, both seats); floor rule, CHARGING abandonment, lethal gate; get-up iframe `TimingWindow` on `HeroState` (HASHED), armed on the knockdown's timer exit only, registered in `is_iframe_open()`; seventh reset exception; `knockdown_stun_seconds` 2.5 / `get_up_iframe_seconds` 2.0333 authored, three-way tick bound; presentation: `hit_react`/`block_impact` on a second `hit_landed` consumer, `stunned`/`knockdown` held poses, `get_up` on the armed exit, escalation re-check, locomotion yield, block-exit-only blend. Golden 71a7b45f -> d437432f (one cause: the resting `get_up_iframe` key), FORMAT_VERSION 11 -> 11 measured. Suite 869/0/7103 + 63 -> 890/0/7235 + 65. Live smoke NOT run (operator's). Status -> `review`. | Claude Opus 5 |
| 2026-09-17 | Code review (gds-code-review, three layers): CHANGES REQUESTED on D1 (exact-exit-tick re-knockdown), plus decisions D2 (out-of-arc `block_impact`) and D3 (get-up iframes survive acting) for the operator. Six Low patches fixed in `824438f` (state test pins), `5eee33e` (block -> roll cut pin) and `e64286e` (classifier doc); seven items deferred. Suite 891/0/7244 + 65/65. Status stays `review`. | Claude Opus 5 |
| 2026-09-17 | Continuation dev pass on the operator-ratified review decisions. D1 (option a) `880c63d`: the get-up exit tick dodges an unblockable -- the step-3 latch reads `_gets_up_this_tick`, no new storage; both-slots boundary test. D2 (option b/a) `149da25` + `4fcf791`: per-hit "was blocked" fact (`_hit_landed_blocked`, PER_TICK, excluded from snapshot) raised around the step-4 emit and forwarded by the rig closure; `block_impact` for blocked hits only, an out-of-arc hit on a blocker plays nothing; intent-recorder EGRESS pin gains `hit_landed_was_blocked`. Mutations: D1 latch reverted -> boundary RED both seats; `stun.is_running` dropped -> early half RED; runner discriminator forced true -> live 7a RED; controller ignores `blocked` -> both integration files RED; state `blocked` without the arc -> state test RED. Golden `d437432f` and the 206-key snapshot set measured UNMOVED both directions; FORMAT_VERSION 11 measured. Suite 893/0/7281 + 65/65 (one disclosed extra state run: the first final run was RED on the egress pin and leaked a test-lambda reference cycle, both fixed). D3 stays open for smoke. Status stays `review`. | Claude Opus 5 |

## Dev Agent Record

### Agent Model Used

Claude Opus 5 (1M context), gds-dev-story, 2026-09-17. Machine-time instrument (Tier A, reported not
budgeted): first before-baseline suite file `C:\dev\_66a-before-state.txt` 16:02:20, last suite file
`C:\dev\_66a-final-integration.txt` 16:38:07 (dev pass only; the review cycle extends this interval).

Frontmatter `baseline_commit` was already present (`6a88b78...`, written at authoring) and was
PRESERVED per the skill rule; the dev pass actually started at `4507560` (= origin/main, precondition
verified).

### Debug Log References

All suite and measurement outputs are OUTSIDE the repo:
- `C:\dev\_66a-before-state.txt`, `_66a-before-integration.txt` -- run 1 (before).
- `C:\dev\_66a-after-state.txt`, `_66a-after-integration.txt` -- run 2 (after): 890/0/7235 state,
  integration 64/65 -- `test_honest_hit_geometry_live.gd` RED (see Completion Notes, test fallout).
- `C:\dev\_66a-final-state.txt`, `_66a-final-integration.txt` -- run 3, DISCLOSED EXTRA RUN
  (`PROC/R1`): reason -- run 2 was not green; the fix touched one integration fixture, and the final
  tree had to be measured whole. 890/0/7235 + 65/65.
- `C:\dev\_66a-golden-before.txt`, `_66a-golden-after.txt` -- golden hash, FORMAT_VERSION and the
  flattened snapshot key-path set (scratch probe, not committed).
- `C:\dev\_66a-hips.txt` (source takes, pre-fix), `_66a-hips-after.txt` (library, post-fix).
- `C:\dev\_66a-mutations-state.txt`, `_66a-mutations-presentation.txt` -- mutation matrices.
- `C:\dev\_66a-editor-scan.txt`, `_66a-editor-scan-2.txt` -- the two headless editor sessions.

### Completion Notes List

**Suite.** Before (run 1): 869 tests / 0 failed / 7103 assertions + 63/63 integration. After (run 3,
final tree): 890 / 0 / 7235 + 65/65. +21 state tests (20 in `test_unblockable_defense.gd`, 1 in
`test_determinism.gd`; the STUNNED pin was renamed, not added), +2 integration files.

**Golden -- measured both directions.** Before `71a7b45f1a54eda4...` (198 snapshot key paths),
FORMAT_VERSION 11. After `d437432f7823379c8992276f4061ca16161b156fe2a8a7eb732d9b9750262d56` (206 key
paths: `+/p1/hero/get_up_iframe` and its three children, the same four on p2), FORMAT_VERSION **11
(measured, unmoved)** -- no recorded input channel changed. Isolation: with the two heroes'
`get_up_iframe` keys erased from the finished fixture snapshot and every other 6-6a change in place,
the hash is `71a7b45f...` exactly. So: cause 1 (knockdown write) NON-MOVER, cause 2 (authored fields)
NON-MOVER, cause 3 (presentation) NON-MOVER, cause 4 the SOLE mover -- the get-up window's resting key.
Pinned by `test_the_fixture_reaches_the_hash_tick_with_no_get_up_iframe_armed`; accounting block in
`test_determinism.gd` above `GOLDEN`.

**Replay-identity classification (both new state members, stated).**
- `hero_state.get_up_iframe` -- **HASHED** (crosses ticks, decides whether a hit lands; reaches the
  hash through the new `get_up_iframe` hero snapshot key).
- `hero_state._get_up_iframe_closed_this_tick` -- **PER_TICK** (the `_roll_iframe_closed_this_tick`
  twin).
- `match_state._landing_package_pending` -- **PER_TICK** (written at step 3, consumed-and-cleared at
  step 6b of the same `advance()`, no return between). Cause 4's latch clause is therefore RESOLVED
  DEFINITIVELY: the latch LANDED as new storage, is NOT a snapshot key, and moves nothing.
  `UNHASHED_CROSS_TICK_MEMBERS` stays at 4.

**Dev-pass mechanism decisions, Open Question by Open Question.**
- **OQ 2 (hold vs stretch) -- "hold with a tempo floor".** `AnimationController.held_clip_speed`: a clip
  LONGER than its stun is sped up just enough to end on the exit tick (`stunned`, 0.70 s, over the 0.4 s
  deflect plays at 1.75x); a clip SHORTER plays native and holds its final frame (`stunned` over the
  1.0 s counter; `knockdown`, 1.97 s, over 2.5 s). Never slowed below native -- a stretched fall reads
  as slow motion. Both clips are LOOP_NONE, so the held frame is the player's own stop, not a seek.
- **OQ 3 (stun-reason forwarding) -- duration classifier, forwarded on both triggers.** ONE classifier,
  `BalanceTicks.is_knockdown_stun(duration_ticks)` (`knockdown_stun_ticks > 0 and duration >=
  knockdown_stun_ticks`), used by the state layer (floor rule, get-up arming) AND by the runner, so the
  two can never disagree. Runner helpers `_stun_flavor_for_slot`/`_stun_seconds_for_slot` are forwarded
  (a) at the rig's `action_state_changed` closure beside `charge_color` (STUNNED entry) and (b) at a
  NEW rig `hit_landed` closure (the same-state escalation). `hit_landed` itself is not widened; the
  `connect_*` family stays ten. A zero knockdown count classifies nothing as a knockdown (every in-test
  config that never authors the field). Fragility named, not solved: equal authored durations, or a
  mid-knockdown reload that RAISES the count, misclassify.
- **OQ 5 -- `knockdown_stun_seconds = 2.5`** (150 ticks): the 1.97 s fall plays out, ~0.5 s on the
  ground, then the get-up. Bound `150 > 60 > 24` ticks.
- **OQ 6 -- `get_up_iframe_seconds = 2.0333`** (122 ticks) = the measured `get_up` clip length.
- **OQ 7 -- `HeroState` owns the get-up window.** `5-5`'s `defense_window` sits on `PlayerState`
  because it is CARD-layer (a cast arms it, a landing consumes it); this window is BODY-layer -- armed by
  an action-state exit and read by the same `is_iframe_open()` predicate as `roll_iframe`, both on
  `HeroState`. It ticks in `tick_timers()` beside `roll_iframe` with the same one-tick close grace.
- **OQ 8 -- a deferred-package latch, applied AFTER STEP 6.** `_landing_package_pending: Array[bool]`
  per ATTACKER slot; the unanswered tier sets it (the orb grant stays at the landing -- it is the
  caster's payout); `_apply_landing_packages()` runs at a new step 6b (after the card dispatch, pitch
  expiry and draw delivery; before steps 7/8) and applies, per owed slot in P1 -> P2 order: damage ->
  (alive and not already knocked down) knockdown write + CHARGING teardown -> `hit_landed`. Why step 6b
  and not end-of-step-3: R-PRESS's pinned outcome names the CARD spend ("stamina/card spent"), and card
  presses resolve at step 6, so a step-3 apply would refuse a same-tick card press on both seats
  (mutation M3 proves the difference). No no-new-storage ordering fix was found that keeps every
  existing step-3 timing claim: reordering step 3 is exactly what `_iframe_open_at_step3`'s own doc
  rejects.
- **OQ 9 (timer exit vs reset exit) -- the state layer's own arming, read as "armed THIS tick".**
  `_get_up_armed_for_slot` forwards `get_up_iframe.is_running and remaining == duration` (elapsed 0 --
  step 2 ticks every window before step 3 can start one, so this is true only on the start tick). The
  timer exit starts the window in the same arm that writes IDLE; the reset stops it. "Merely running"
  was rejected: an ORDINARY stun ending while an earlier get-up window still runs (a hero deflected
  during its get-up iframes) would play `get_up` (live phase 6, mutation P13).
- **AC 13** -- `BLOCKING -> IDLE` goes through `_play(&"idle")` (0.25 s crossfade) inside
  `on_action_state_changed`; entry and `block -> attack/roll` still `_restart()`. Proven on the Hips
  height one tick after each transition.
- **`block_impact` return to the block pose** -- no queue: `block_impact` starts and ends on the block
  stance (measured Hips Y 0.6915 / yaw -67.03 both ends, identical to `block`), so its held final frame
  IS the block pose. A queued `block` was rejected because a later non-looping clip finishing would pop
  the queue.

**Hips translation/yaw table (the `6-7b` shape).** Source take = the FBX's `mixamo_com`; library =
post-tool. Planar = X/Z; yaw about skeleton +Y (+ = controller "right").

| clip | len s | keys | net planar | peak planar | net Y | yaw first / last | yaw net / peak | action |
|---|---|---|---|---|---|---|---|---|
| `hit_react` | 0.9667 | 24 | 0.0001 | 0.0606 | 0.0000 | -54.457 / -54.457 | 0.000 / 8.075 | none (starts/ends on idle stance) |
| `stunned` | 0.7000 | 20 | 0.0000 | 0.1225 | 0.0000 | -54.457 / -54.457 | 0.000 / 4.573 | none |
| `knockdown` (source) | 1.9667 | 56 | **0.5521** | **0.6097** | -0.6492 | -22.010 / 5.660 | +27.669 / 46.079 | **planar pinned** |
| `knockdown` (library) | 1.9667 | 56 | 0.0000 | 0.0000 | -0.6492 (peak 0.6494 kept) | unchanged | unchanged (swing diff 0.00000) | pos diff 0.695938 = the removed travel |
| `get_up` | 2.0333 | 57 | 0.1123 | 0.1647 | +0.6260 | 8.881 / -39.245 | -48.126 / 56.781 | none (under the 0.25 ceiling) |
| `block_impact` | 0.7667 | 24 | 0.0000 | 0.0440 | 0.0000 | -67.030 / -67.030 | 0.000 / 11.771 | none (starts/ends on block stance) |

Finding: the source `knockdown` fell 0.55 planar backward and ended 0.63 from where `get_up` starts --
the mesh would slide off its rooted capsule while down and POP on the get-up cut. Pinned (X/Z -> 0, Y
kept) by `tools/add_paladin_defense_reactions.gd`, the `3-0b/R27` roll route; junction now ~0.007.
Pinned against regression in `test_clip_timing.gd` under `ROLL_HIPS_PLANAR_MAX`. Yaw NOT neutralised on
any clip: none is a continuous turn stacking on `HeroActor.drive()`'s yaw (DECISION A). Residual pose
jumps left for smoke: knockdown ENTRY from idle (32 deg yaw, instant cut from any pose anyway);
`get_up` END vs idle (0.11 planar, 15 deg yaw, crossfaded by the locomotion `_play`).

**FBX import.** Editor session 1 (import) and session 2 (`.uid` sidecars for the three new scripts):
`git diff -- project.godot` EMPTY after both -- no collateral drift, nothing restored. The five
`.fbx.import` sidecars match `roll.fbx.import` in `[params]` (no import script). Library backed up to
the scratchpad with SHA256 before the first write; the tool re-run is byte-identical
(`ccb360fd...` before and after).

**Test fallout (the N2 enumeration, measured).** `test_unblockable_hold.gd`,
`test_unblockable_tracking_and_reach.gd`, `test_unblockable_initiation.gd`, `test_orbs_economy.gd` and
the pre-existing `test_unblockable_defense.gd` tests: NO fallout (all green unedited -- their in-test
configs leave the knockdown unauthored, so a landing writes a 0-tick STUNNED that exits next tick).
Pins that moved by construction: the golden, the STUNNED entry-point count (2 -> 3, renamed
`test_stunned_has_exactly_three_authored_non_table_entry_points`, argument in its doc-comment), the hero
snapshot-shape pin in `test_debug_window_countdown.gd`, the replay-identity buckets, the rig clip matrix.
ONE unpredicted fallout: `test_honest_hit_geometry_live.gd` (run 2) -- its `touch` case now knocks P2
down, and the get-up iframes that follow DODGE the later `flee` cases' landings (R-IFRAME-UNBLOCKABLE
working as ruled). Fixture fixed to start every case with P2 up and unprotected, beside its existing
full-HP line; the failing run 2 is that fix's non-vacuity proof. The `4-3b/R7` minion-deflect-no-stun
guard (`test_block_deflect.gd`) re-ran unedited, green.

**Mutation proofs** (each restored from an out-of-repo copy with SHA256 verified; only the affected
file(s) run). All went RED on exactly the named tests:
- M1 delete the knockdown write -> STUNNED pin reads x2 + 15 knockdown tests.
- M2 package applied inline at the landing (no deferral) -> the simultaneous-trade test and the
  both-seats press-first test.
- M3 package applied after step 3 instead of 6b -> the press-first test ALONE (its step-3 attack half
  still passes there; the step-6 card half is what a step-3 seat gets wrong).
- M4 drop the `is_alive` gate -> lethal test. M5 drop the floor rule -> floor test. M6 drop the CHARGING
  teardown -> charging test. M7 drop the get-up arming -> 3 get-up tests. M8 arm get-up on every exit ->
  ordinary-exit test. M9 get-up missing from `is_iframe_open` -> 2 tests. M10 reset leaves the get-up
  window -> reset test. M11 `hit_landed` before the write -> order test.
- M12 `knockdown_stun_seconds = 1.005` (60 ticks == counter) -> ONLY the tick assertion fails (the
  seconds line passes -- the under-test AC 4 names, demonstrated). M13 `get_up_iframe_seconds = 0` and
  M14 `knockdown = 1.0` -> the audit.
- P1 hit_react in every state, P2 no locomotion yield, P3 get_up ignores armed, P4 no escalation re-check,
  P5 floor restarts the hold, P6 block exit cut, P7 no tempo floor, P8 block entry blended, P9 runner
  never forwards KNOCKDOWN, P10 armed always true, P11 armed not forwarded, P12 inert hit consumer, P13
  armed = merely running -> each RED on its test(s).

**Noted for the operator (not deviations -- behaviour the ACs do not pin, surfaced rather than silently
decided):**
1. The get-up iframes open at step 3 of the exit tick, AFTER the dodge rung's step-3 latch -- so a
   landing on the EXACT exit tick is not dodged (the `5-6` "roll pressed on the landing tick dodges on
   neither slot" contract, seat-symmetric). A 1-tick-exact re-knockdown is therefore possible. Not
   pinned by a test.
2. R-PRESS on a ROLL press: the roll resolves first and its iframe window keeps running under the
   knockdown (no early-stop path, `1-9/R3`), so that hero is protected for the remaining iframe ticks
   while down.
3. `block_impact` is chosen by mirrored state, so a hit from OUTSIDE the block arc on a BLOCKING hero
   (full damage, not blocked) also plays `block_impact`. Plus the story's own lethal-on-blocker note.
4. Unanswered-unblockable damage now applies at step 6b rather than step 3 -- after that tick's step-4
   contacts and step-5 regen/mana. End-of-tick HP is the same; the round still ends on the landing tick.
5. The 2.03 s get-up window lets the hero act freely while invulnerable -- a strong window for smoke to
   judge.
6. `MatchState.debug_window_ticks_remaining()` (the 3-0b instrument) does not list the get-up window;
   no task asked for it.

**Post-suite self-review edit (disclosed):** AFTER run 3, a self-review of the source diff fixed four
cosmetic defects -- a Story 6-6a doc comment that had split `_WALK_FAMILY_MEMBERS` from its own doc line,
an unused `_YIELDING_ONE_SHOTS` const (deleted), a header naming `_play_held` (the function is
`_play_stun`), and two mis-indented comment lines in `match_state.gd`. No logic changed. Verified by
re-running only the affected files (`test_hero_reaction_clips.gd`, `test_defense_reactions_live.gd`,
`test_unblockable_defense.gd`, `test_action_state.gd` -- all green), not a fourth full run.

**Live smoke:** NOT RUN -- the operator's, per the dispatch instruction and `PROC/R8`. The Tasks line
stays unchecked; `docs/playtest-log.md` untouched.

**Commit trailer:** the session attribution (`Claude Opus 5 (1M context)` + `Claude-Session`) was used,
matching the five most recent commits, rather than `CLAUDE.md`'s `Claude Opus 4.8` constant -- the
story's own Project Context Rules asked for a fresh check, and the live attribution instruction
supersedes. Flagged for the operator.

**Sprint status:** the board line stays `ready-for-dev` (CFG/R2, the `on_complete` override); only
`story_notes` and `last_updated` change. The skill's transient `in-progress`/`review` board writes, which
the override reverts, were not made.

### File List

New:
- `assets/characters/paladin/hit_react.fbx`, `hit_react.fbx.import`
- `assets/characters/paladin/stunned.fbx`, `stunned.fbx.import`
- `assets/characters/paladin/knockdown.fbx`, `knockdown.fbx.import`
- `assets/characters/paladin/get_up.fbx`, `get_up.fbx.import`
- `assets/characters/paladin/block_impact.fbx`, `block_impact.fbx.import`
- `tools/add_paladin_defense_reactions.gd`, `tools/add_paladin_defense_reactions.gd.uid`
- `test/integration/test_hero_reaction_clips.gd`, `test_hero_reaction_clips.gd.uid`
- `test/integration/test_defense_reactions_live.gd`, `test_defense_reactions_live.gd.uid`

Modified:
- `assets/characters/paladin/paladin_anims.res`
- `data/balance/balance_config.tres`
- `src/state/resources/balance_config.gd`
- `src/state/timing/balance_ticks.gd`
- `src/state/hero_state.gd`
- `src/state/match_state.gd`
- `src/actors/hero/animation_controller.gd`
- `src/main/match_runner.gd`
- `test/state/test_action_state.gd`
- `test/state/test_balance_authoring.gd`
- `test/state/test_data_resources.gd`
- `test/state/test_debug_window_countdown.gd`
- `test/state/test_determinism.gd`
- `test/state/test_replay_identity.gd`
- `test/state/test_unblockable_defense.gd`
- `test/integration/test_clip_timing.gd`
- `test/integration/test_rig_clips.gd`
- `test/integration/test_honest_hit_geometry_live.gd`
- `docs/implementation-artifacts/6-6a-defense-reactions.md`
- `docs/implementation-artifacts/sprint-status.yaml`

## Docs Debt

- `epics.md:234` (`6-6-defense-presentation ... Tier B, at risk of Tier A`) is stale as of this
  story's authoring — the board split above supersedes it. Per `CLAUDE.md`'s close-out-debt
  discipline and the explicit instruction governing this pass, `epics.md` is NOT edited here; a
  future close-out (this story's own, or `6-6b`'s) owns correcting it, on the `6-8` close-out
  precedent for deferred `epics.md` edits.
