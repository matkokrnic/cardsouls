---
baseline_commit: 0141179a96c39b9d02e52b99b6ba6933781a25f2
---

# Story 5.2: Unblockable initiation

Status: ready-for-dev

## What this story inherits

`E5-P/R5` (`decision-log.md:8192-8194`) ratifies this as the SEVENTH of twelve E5 stories: Tier A,
authored WHOLE — `CHARGING`'s first inbound edge, the chargeup timer on the D4 primitive,
per-colour damage (deferred to a later story; THIS story ships one damage value for all colours,
see Non-Goals), and the S6 mid-roll/mid-block cast gate named in the 3-5a smoke residue. The
per-colour-damage deferral is a superseding operator scope ruling, `5-2/R10`
(`decision-log.md`, Session 2026-09-04) — `E5-P/R5`'s line assigning per-colour damage to this
story is overridden on that point; `epics.md:150` already agrees. Reach is
fixed by `E5-P/R4` (`decision-log.md:8166-8174`): a large authored hit radius (provisional ~8 m)
that IS the boundary — being or getting outside it during the chargeup is the escape; lock-on
(`4-6`) aims direction only and never extends reach. `epics.md:169-172` states the same binding.
The readiness gate measured the story and ruled it ships WHOLE (`5-2/R12`): the auto-aim cut is
NOT taken, since auto-aim is the cheapest AC in the story (one write beside the existing facing
write) and cutting it would remove the least work while deleting the pillar `epics.md:148` names
("generous auto-aim"). The Cut Line below is retained as a record of the option that was
considered and declined, not as a live escape hatch.

## Operator rulings (the contract)

1. **Mode ② goes live at initiation, not at landing.** The hero spends the selected card and
   stamina THE MOMENT the cast resolves and enters `CHARGING` for an authored duration; the attack
   lands when the chargeup ends.
2. **Colour selects telegraph, not damage.** The spent card's colour is the attack's colour for
   `5-3`'s telegraph and `5-5`/`5-6`'s later colour-match resolution; damage is one fixed value
   for all three colours in this story (per-colour damage is `5-6`'s ladder).
3. **Rooted for the whole chargeup.** Auto-aim rotates the hero to face the enemy hero; it never
   adds range — reach is fixed by `E5-P/R4` regardless of facing.
4. **Fully committal.** No cancel exists. Taking damage during the chargeup does not interrupt it
   — the hero takes the hit and the attack still lands on schedule.
5. **Landing is a reach check at the moment the chargeup ends**, not at initiation: enemy hero
   inside the authored reach → hit; outside → nothing happens. The card and stamina stay spent
   either way (E5-P/R4's "spacing still matters" reading — the boundary is real, not decorative).
6. **No distance refusal on start.** Initiating while the enemy hero is far outside reach is
   allowed; the miss is discovered at landing, not preempted at the press.
7. **S6 gate (closes the named open from the `3-5a` smoke).** Mode ② may not be initiated while
   `ROLLING`, while `BLOCKING`, or during the hero's own `ATTACKING`. A rejected attempt goes
   through the existing `reject_action` seam with a named reason — never `Invariant.check`, never a
   silent drop. `BASIC` casts (`_resolve_basic_cast`) are UNCHANGED by this story; the gate is
   specific to mode ②.
8. **Target is the enemy hero only.** Minions are neither targets nor obstacles for this attack.
9. **State publishes the active telegraph as a fact** (colour + remaining time), consumed
   presentation-side by `5-3` per `1-10/R1` (locked): the `ActionState -> TelegraphProfile` mapping
   stays controller-owned; state never references a `TelegraphProfile`.

## Story

As the operator implementing the RGB read exchange's opening half,
I want a card cast in mode ② to spend its card and stamina immediately, root the hero into a
timed, uncancellable chargeup with auto-aim toward the enemy hero, and land a fixed-damage hit
only if the enemy hero is still within the authored reach when the timer ends,
so that `5-3` has a real telegraph fact to render, `5-5`/`5-6` have a real chargeup window to
answer against, and initiating while rolling, blocking, or mid-swing is refused rather than
silently accepted or crashing the invariant guard mode ② hits today.

## Acceptance Criteria

**Dispatch and the S6 gate (`match_state.gd:_resolve_card_action`, `:2097-2103`)**

1. A committed intent with `card_mode == Enums.ModeKind.UNBLOCKABLE` (`src/state/enums.gd`,
   `enum ModeKind { BASIC, UNBLOCKABLE, DEFENSE, PITCH }`, ordinal `1`) no longer reaches
   `Invariant.check(false, ...)`. It gets its own arm in the same `match`.
2. **S6 is closed by `5-2/R11`: mode ② is refused, via `HeroState.reject_action` with a named
   reason (e.g. `&"unblockable_committed"` or similar — name it in Completion Notes, follow the
   `REASON_EMPTY_SLOT`-style vocabulary), when the casting hero's `action_state` is `ROLLING`,
   `BLOCKING`, or `ATTACKING` at the moment the cast is evaluated.** This gate is specific to
   `UNBLOCKABLE` and does not extend to `BASIC` (see AC 3). No `Invariant.check` anywhere on this
   path (`5-1a/R7`'s general finding — `Invariant.check` is stripped in exported builds — applies
   here too: this is a player-reachable refusal, not a programming-error guard).
3. `BASIC` mode dispatch (`_resolve_basic_cast`) is untouched and stays UNGATED during `ROLLING`
   and `BLOCKING`: same guard order, same reasons, same behaviour as before this story. This is not
   a residual gap — `5-2/R11` ratifies it as correct: a `BASIC` cast is an instant summon that
   interrupts nothing, the card layer runs deliberately parallel to melee, and only a duration
   effect (rooting the hero, `UNBLOCKABLE`'s case) needs a reachability gate. The behaviour the
   operator observed at the `3-5a` smoke (a `BASIC` cast succeeding mid-roll and mid-block) is
   therefore expected and stays shipped. A regression test proves `BASIC` is unaffected (existing
   `test_card_play.gd` coverage must still pass unedited in its `BASIC`-mode assertions).
4. **Card colour reaches the state layer through a third injection seam (`5-2/R1`)**:
   `inject_card_colors` (card_id -> `Enums.CardColor`), mirroring `inject_card_costs`
   (`match_state.gd:505`) and `inject_card_effects` (`:538`) exactly — load-once, injected at the
   same point, same dictionary shape. `src/state/` still never reads a `CardData`
   (`card_data.gd:5`). This is the source AC 21's telegraph colour reads from.

**Spend and entry (mode-agnostic spend path precedent, `match_state.gd:2141-2229`)**

5. **On an unrefused mode ② cast, no mana/orb/feature-flag evaluation runs at all (`5-2/R2`):**
   `CastEvaluator.refusal_reason` is NOT called on this path. The empty-slot guard runs first
   (same shape as `_resolve_basic_cast`'s guard order); stamina affordability is the ONLY cost
   refusal. Insufficient stamina refuses through `reject_action` with a named reason, same
   mechanism as insufficient mana does for `BASIC` casts, but via a separate check, not
   `CastEvaluator`.
6. On an affordable, unrefused cast: stamina is spent via `StaminaPool.spend(amount,
   regen_delay_ticks)` (new `unblockable_stamina_cost` balance field, provisional `20.0`, passed
   with `balance_ticks.stamina_regen_delay_ticks` — the spend restarts the regen delay exactly as
   the three existing seats do, `5-2/R4`), the card leaves the hand and enters the discard
   (`hand.remove_at` + `discard.add`), a replacement is owed on the vacated slot
   (`pending_draw_owed.append` + `pending_draw.start`), and `notify_cards_changed()` fires — all in
   the same tick, mirroring `_resolve_basic_cast`'s ordering exactly.
7. **The hero's `action_state` transitions to `CHARGING` this same tick via a direct
   `set_action_state` call at the cast seat (`5-2/R7`).** `HeroState.TRANSITION_TABLE` gains NO
   new row — `CHARGING` has no `&"attack"`-style inbound press to map from, so the card layer
   drives entry directly rather than through the table's input-priority rows. Name this mechanism
   explicitly in Completion Notes.
8. **`test/state/test_action_state.gd:82-95`'s zero-inbound-CHARGING assertion STAYS INTACT and is
   re-proven, not edited (`5-2/R7`).** Because AC 7's mechanism never touches `TRANSITION_TABLE`,
   the pin remains true and the test passing unedited is itself part of this story's proof.
9. **The forced pin edit is `test/state/test_card_play.gd:246`'s `test_non_basic_modes_are_
   unreachable_in_e3` (`5-2/R8`).** This test regex-scans all of `src/` and fails if any
   `Enums.ModeKind.<X>` names anything but `BASIC`; AC 1 trips it immediately. It is narrowed so it
   still fails on `DEFENSE` and `PITCH` (mode ③ and mode ④ stay unreachable) while permitting
   `UNBLOCKABLE`. This is the story's one deliberate, named pin change — call it out in the diff
   and in Completion Notes. (`test_the_mode_dispatch_carries_a_guard`, `:300`, is unaffected — the
   `_:` arm keeps `Invariant.check(false` and the "guarded stub" string for the two modes that
   remain unreachable.)

**Chargeup window and rooting**

10. A chargeup timer runs for the authored `unblockable_chargeup_seconds` (provisional `1.0`),
    converted to ticks at load through `BalanceTicks.from_config()` (the `D3` precedent —
    `draw_replacement_delay_ticks` is the closest sibling), never compared against a raw seconds
    float inside `advance()`.
11. **While `CHARGING`, the hero is hard-rooted (`5-2/R5`): `_resolve_movement`'s phase dispatch
    (`match_state.gd:2469-2527`) gains a `CHARGING` arm in which velocity from move input is a
    hard zero.** No new balance field is added for movement — a multiplier field is explicitly not
    taken, since a non-zero multiplier is not rooted.
12. Facing rotates toward the enemy hero for the duration of `CHARGING` (AC 3, auto-aim, kept per
    `5-2/R12` — the story ships whole). The exact mechanism (reuse the existing
    `_lock_directions[slot]` fact the runner already pushes for lock-on facing,
    `match_state.gd:2549-2551`, vs. a new hero-only auto-aim fact) is an OPEN QUESTION (below) —
    whichever is chosen, it must aim at the enemy HERO specifically (Ruling 8, target-only), not
    at whatever the existing lock-on target happens to be (which can be a minion).
13. Being hit while `CHARGING` does not interrupt it (AC 4): no transition out of `CHARGING` is
    wired to the contact-resolution/damage path. The existing HP/damage application runs exactly as
    it does for any other action state; only the exit-on-hit branch is what this story omits.
14. **Stamina regeneration is SUPPRESSED for the whole of `CHARGING` (`5-2/R4`): it joins
    `BLOCKING` and `DEAD` in `_regen_stamina`'s (`match_state.gd:1877-1879`) suppression list.**

**Death during the chargeup (`5-2/R3`)**

15. **If the charging hero dies mid-chargeup, the chargeup resolves to nothing: no landing check
    runs, and the hero stays `DEAD`.** The step-3(a) `CHARGING`-timer-exit arm (named per AC 20)
    must not return a corpse to `IDLE` — a `DEAD` hero's exit from `CHARGING` is a no-op, mirroring
    the existing `DEAD` branches at `match_state.gd:2478`/`:2091` and step 4/step 5. Card and
    stamina stay spent (AC 6 already ran).
16. **If the enemy hero dies before the chargeup timer expires, landing is skipped: no damage is
    applied to a dead hero.** Card and stamina stay spent (AC 6 already ran) on the charging
    hero's side regardless of the enemy's death.

**Landing**

17. **When the chargeup timer expires, reach is read from an untethered, every-tick hero-to-hero
    fact (`5-2/R6`), not a throttled probe.** The runner pushes an explicit inside/outside-reach
    value every tick while either hero is `CHARGING` — reusing `_push_reach_probe`'s cadence
    (`match_runner.gd:1821-1851`, every 12 ticks at the authored 0.2s) is disqualified, since a
    fact fresh on at most 1 tick in 12 cannot answer an exact-expiry-tick landing check, and the
    probe's absence-means-outside-reach convention is ambiguous (absent could also mean
    not-yet-probed or actor-not-spawned). The new fact is planar (XZ), computed runner-side,
    pushed into state through the existing `push_contact`-style seam under a NEW contact kind
    (widening the `kind == CONTACT_STRIKE or CONTACT_REACH_PROBE` guard at `match_state.gd:622`
    is expected and in scope). State never pulls from the runner mid-`advance()` — the fact must
    already be present when the landing check reads it (named seat: AC 20). `F1` stays untouched;
    positions never enter `src/state/`. Distance is compared to the authored `unblockable_reach`
    (provisional `8.0`) at the moment the timer expires, not at initiation (`E5-P/R4`).
18. Inside reach at expiry AND the enemy hero alive (AC 16) → the attack lands: fixed damage of
    `unblockable_damage_percent_of_max_hp` (provisional `9.0`, following the
    `attack_damage_percent_of_max_hp` convention) applied to the enemy hero's HP, same shape as the
    existing basic-attack contact resolution.
19. Outside reach at expiry → nothing happens. Card and stamina stay spent (AC 6 already ran); no
    damage, no orb, no HP change on either side.
20. **The hero exits `CHARGING` back to `IDLE` when the timer ends, on the same tick the landing
    check resolves, regardless of hit or miss — EXCEPT when the charging hero is `DEAD` (AC 15),
    in which case the exit is a no-op.** This resolves at step 3(a)'s timer-exit arm
    (`match_state.gd:746-761`), reading the AC 17 reach fact directly rather than through the
    contact queue, so the timer exit and the landing check land in the same step.

**Telegraph fact (`5-3`'s input)**

21. **While `CHARGING`, `PlayerState.to_snapshot()` (the pinned 28-key set, `player_state.gd:205`)
    exposes the active telegraph as a fact readable by the presentation layer (`5-2/R9`): the
    spent card's colour (AC 4's injection seam) and the remaining chargeup time (ticks or seconds
    — name the unit chosen).** Seating this on `HeroState.to_snapshot()` instead does not satisfy
    this AC, even though it would move the golden — it would not move the pinned 28-key set, and
    AC 22's prediction would be false while the story still appeared to pass. This is a NEW
    per-player snapshot field, not a signal-only fact, since `5-3` must be able to read it on a
    frame that did not just change (the same reasoning `to_snapshot()`'s existing window fields
    already follow). `1-10/R1` stays intact: state owns the fact, nothing in `src/state/`
    references a `TelegraphProfile`.

**Golden Prediction (measured, not asserted)**

22. **Prediction (`5-2/R9`): the golden MOVES, with the 28-key `PlayerState` snapshot set growing
    by one key per new fact actually added (28 → 29 if colour and remaining-time share one
    field/dictionary key, 28 → 30 if they are two separate keys), each key named as its own cause
    in Completion Notes.** Measure `bash test/run_all.sh` before and after; if the golden moves for
    any OTHER reason, or the key count does not match the number of keys actually added, that is a
    finding, not a pass.
23. **Whether `FORMAT_VERSION` bumps 6 → 7 is a MEASURED dev-pass question, not assumed here.**
    `4-3b` bumped it on a key-set change; `5-1a/R4` did NOT bump it when no key changed. This story
    DOES add a key (AC 21/AC 22), which is the `4-3b` precedent's shape — but the dev pass must
    check whether the new fact is derived read-only from existing recorded intents (in which case
    old records still replay correctly without a bump) or requires a new record channel (AC 17's
    new contact kind, in which case `record_file.gd:284-287`'s mismatch refusal forces the bump)
    before deciding either way. State the measured answer, with reasoning, in Completion Notes.

## Non-Goals

- **Orbs** (`5-4`) — no orb is granted on land or on any outcome in this story.
- **Colour defence / colour-match answering** (`5-5`) — mode ③ is not touched; nothing reads the
  telegraph fact to negate anything yet.
- **Stun and the three-tier outcome ladder** (`5-6`) — landing always does full fixed damage; there
  is no dodge/leave-range vs. correct-colour distinction, no stun, and `STUNNED` gets no inbound
  edge here.
- **Telegraph visuals and audio** (`5-3`) — this story produces the state-owned fact only; no
  shape, sound, or HUD element consumes it.
- **Pad button wiring** (`5-7`) — how a player triggers mode ② on the controller is out of scope;
  this story assumes `card_mode`/`card_slot` already arrive correctly on the intent (already true,
  `record_file.gd:522-523/678-679`).
- **Per-colour damage** — all three colours deal identical damage in this story (Ruling 2).
- **Cancel** — fully committal by design (Ruling 4); no cancel input, no early-exit branch.
- **Minions as targets or obstacles** — the enemy hero is the only target (Ruling 8); minion
  positions play no role in the reach check.
- **Camera work** — no camera behaviour changes for the chargeup.

## Cut Line

`5-2` is authored WHOLE (`E5-P/R5`) and the readiness gate has RULED it stays whole (`5-2/R12`):
the auto-aim cut is declined, not taken. The cut is recorded below only as the option the gate
considered — it is not available to a dev pass without a fresh operator ruling. Had it been taken,
the attack would instead use the hero's current facing at initiation (no rotation during
`CHARGING`), the story would ship without AC 12, AC 12 would become a Non-Goal, and the open
question below about the facing-fact mechanism would be moot.

## Open Questions (left to the gate / dev pass, `E4-R/R4`)

- **Whether the charge window reuses an existing window primitive or needs a new one (AC 10).**
  `HeroState` already has windup/active/recovery/deflect/roll-duration windows on the same D4
  primitive; whether `CHARGING` gets its own named window field or reuses the existing primitive
  under a new name is implementation detail, not design.
- **Whether the S6 gate (AC 2) reads `action_state` directly or via a separate dedicated guard
  ahead of `CastEvaluator`.** `CastEvaluator.refusal_reason` itself is ruled OUT for this path
  (AC 5, `5-2/R2`), so the only remaining dev-pass choice is where the `ROLLING`/`BLOCKING`/
  `ATTACKING` check lives structurally — inline in `_resolve_card_action`, or as a small sibling
  guard function — not whether it goes through `CastEvaluator`. Either satisfies `5-2/R11` as long
  as no `Invariant.check` is used and the reason is named.
- **Where AC 12's facing mechanism is seated.** Reuse the existing `_lock_directions[slot]` fact
  the runner already pushes for lock-on facing (`match_state.gd:2549-2551`) vs. a new hero-only
  auto-aim fact — either satisfies the requirement as long as it aims at the enemy hero
  specifically (Ruling 8) and not whatever the existing lock-on target happens to be.

## Dev Notes

- **Golden Prediction reasoning (AC 17/AC 18).** Every prior E5 story either moved the golden for
  one named structural reason (`5-1`: linear stacking changes shipped output) or predicted and
  measured NO movement (`5-1a`: new refusal branches never triggered by the well-formed fixture).
  This story is the first E5 story whose own fixture-driving recorded intents (if the golden replay
  ever casts mode ②) would actually exercise the new code — check whether the golden's recorded
  session includes ANY mode ② cast before assuming AC 17's single-cause prediction; if it does not,
  the reasoning is closer to `5-1a`'s (new branches untouched by the fixture) and the new snapshot
  KEY still appears even though its VALUE never leaves the default for that particular replay. Say
  which case actually held, measured, in Completion Notes.
- **Card colour → attack colour (Ruling 2).** The card played (`hand.to_array()[hand_slot]`) already
  carries an id from which colour is presumably derivable (fixture card ids, `src/data/` schema);
  confirm the colour lookup path exists before inventing a new one — this story consumes it, it
  does not define card colour as a concept.
- **`_resolve_card_action`'s existing DEAD guard and frozen-tick contract (`match_state.gd:2063
  -2103`) apply unchanged to mode ②** — a mode ② cast on a frozen tick is dropped silently, exactly
  as a BASIC cast is, for the same structural reason (step 1b never reaches card intent on a frozen
  tick). No new AC needed; name this explicitly as inherited behaviour in Completion Notes rather
  than re-deriving it.
- **`reject_action`'s existing shape** (`hero_state.gd:200-203`, queued `action_rejected` signal,
  `HeroState.reject_action(action: StringName, reason: StringName)`) is the seat AC 2/AC 4 reuse —
  no new signal, no new seam, consistent with `5-1a`'s and `3-5a`'s own framing of this rule.
- **Readiness gate fix pass, 2026-09-04 — superseding notes on the three bullets above.** The gate
  (`C:\dev\_52-gate.md`) measured that no colour lookup path exists today: `card_data.gd:5` states
  outright that nothing in `src/state/` reads a `CardData`, and neither `inject_card_costs` nor
  `inject_card_effects` carries colour. The "Card colour → attack colour" bullet's instruction to
  "confirm the colour lookup path exists before inventing a new one" is therefore answered: it does
  NOT exist, and `5-2/R1`'s third injection seam (AC 4 now) is the new path, not an invention to be
  second-guessed. The AC numbers in the "Golden Prediction reasoning" and `reject_action` bullets
  above (`AC 17/AC 18`, `AC 2/AC 4`) refer to the PRE-gate numbering; post-gate the same content is
  AC 22/AC 23 and AC 2/AC 5 respectively — the reasoning stands, only the numbers moved. The Golden
  Prediction reasoning bullet's own dev-pass question (whether the golden's recorded session
  includes any mode ② cast) still applies unchanged and gates which half of AC 22's 28→29-or-30
  prediction is the live one.
- **Death during the chargeup (`5-2/R3`, AC 15/AC 16).** Every sibling resolution path in
  `match_state.gd` already carries an explicit DEAD branch for this exact reason
  (`:2478`, `:2091`, step 4, step 5) — AC 15/AC 16 are not a new pattern, they are this story's
  instance of an existing one. The risk the gate flagged (F3) was a corpse resurrected to `IDLE` by
  a chargeup-exit arm that runs "regardless" with no aliveness test; AC 20 names the exact seat
  (step 3(a), `match_state.gd:746-761`) where that test belongs.
- **Reach fact cadence (`5-2/R6`, AC 17).** The disqualification of `_push_reach_probe`'s cadence
  is a measured fact, not a design preference: the probe fires on `_probe_counter %
  minion_retarget_interval_ticks == 0` (`match_runner.gd:2234-2244`), i.e. 1 tick in 12 at the
  authored 0.2s, and `MatchState` only tolerates that gap for its existing consumer via the
  freshness window in `is_in_reach_at`/`mark_in_reach_at` (`match_state.gd:970`, `:1447`) — "confirmed
  RECENTLY", not "confirmed now". A landing check has no such tolerance to spend, hence the
  untethered every-tick fact.
- **The forced pin edit (`5-2/R8`, AC 9) is unrelated to the deliberate pin edit this story
  originally planned (AC 7/AC 8, `5-2/R7`).** Two different tests are affected for two different
  reasons: `test_action_state.gd:82-95` was expected to move and, per the ruling, does not;
  `test_card_play.gd:246` was not named at authoring time and, per the ruling, must. Do not conflate
  the two in Completion Notes — name them separately.

### Project Structure Notes

- Touched files (dev pass to confirm exhaustively): `src/state/hero_state.gd` (no
  `TRANSITION_TABLE` edit, `5-2/R7` — the CHARGING chargeup window field, AC 10),
  `src/state/match_state.gd` (`_resolve_card_action`'s new arm AC 1-2, the colour injection seam
  AC 4, the spend/entry sequence AC 5-7, `_regen_stamina`'s CHARGING suppression AC 14, the death
  guards AC 15-16, `_resolve_movement`'s new CHARGING arm AC 11, the facing/auto-aim mechanism
  AC 12, landing resolution AC 17-20, the telegraph fact in `to_snapshot()` AC 21, the widened
  `push_contact` kind guard at `:622` for AC 17's new contact kind), `src/main/match_runner.gd`
  (the untethered every-tick reach-fact production, AC 17), a small dedicated S6 guard ahead of
  `_resolve_card_action`'s dispatch (AC 2/AC 5 — dev's call per the Open Question;
  `src/state/economy/cast_evaluator.gd` itself is NOT called on this path per `5-2/R2`),
  `src/state/resources/balance_config.gd` schema + `data/balance/balance_config.tres` (repo-root
  `data/`, not `src/data/` — four new fields: `unblockable_stamina_cost`,
  `unblockable_chargeup_seconds`, `unblockable_reach`, `unblockable_damage_percent_of_max_hp`),
  `src/state/timing/balance_ticks.gd` (`unblockable_chargeup_ticks`, D3 precedent),
  `test/state/test_action_state.gd` (re-proven unedited, AC 8), `test/state/test_card_play.gd:246`
  (AC 9's forced pin narrowing), `test/state/test_data_resources.gd` (`E1_BALANCE_FIELDS` gains the
  four new fields), `test/state/test_balance_authoring.gd` (new fields' audit bounds), and new or
  extended test coverage for the whole dispatch/chargeup/landing chain — dev's call which existing
  file (closest sibling: wherever `test_card_play.gd`'s BASIC-mode tests live) vs. a new file; name
  the choice in Completion Notes.
- No new top-level folder. No scene file is required by anything ruled here (AC 12's facing
  mechanism may or may not need a runner-side helper, not a scene change).

### Project Context Rules

- **F1** — not implicated: no new `_physics_process`. The reach check runs inside the existing
  runner tick / state `advance()` cycle, not a second loop.
- **D3(a)** — not implicated: no new `Input.*` read; mode ② already arrives via the existing
  card-intent fields.
- **D3(b)/A2** — not implicated by anything ruled here: the reach fact crosses through the same
  kind of runner-side-computed, state-pushed seam `_push_reach_probe` established (a NEW,
  untethered every-tick fact per `5-2/R6`, not a reuse of the throttled probe itself), so no
  RNG/Time/OS/Engine call enters `src/state/`.
- Docs and code never share a commit; commits are pure ASCII via `git commit -F <tempfile outside
  the repo>`; shell is PowerShell 5.1 (no `&&`); trailer `Co-Authored-By: Claude Opus 4.8
  <noreply@anthropic.com>`.
- Story tier: Tier A, full gate + review + live smoke ritual, per `E5-P/R5`'s own text.

### References

- [Source: decision-log.md:8166-8194] — `E5-P/R4` (chargeup reach ruling) and `E5-P/R5` (story
  slot, tier, break line).
- [Source: decision-log.md, Session 2026-09-04 "5-2 gate rulings"] — `5-2/R1`-`5-2/R12`, the
  readiness-gate fix pass this revision of the story carries into its AC text.
- [Source: epics.md:148,169-172] — the E5 epic summary line and the `CHARGING`/reach committed
  obligation.
- [Source: src/state/hero_state.gd:23-67] — `ActionState` enum (`CHARGING` at ordinal 5, `:27`),
  `TRANSITION_TABLE` (no `charging` row, `:44`), the inbound-edge doctrine comments.
- [Source: src/state/enums.gd] — `ModeKind` enum (`BASIC, UNBLOCKABLE, DEFENSE, PITCH`,
  `UNBLOCKABLE` at ordinal 1, AC 1).
- [Source: src/state/resources/card_data.gd:5,30] — `CardData.color` (`Enums.CardColor`) and the
  "nothing in src/state/ reads a CardData" contract the AC 4 injection seam preserves.
- [Source: src/state/resources/balance_config.gd] — `BalanceConfig`, the authored resource schema
  the four new balance fields (AC 6, AC 10, AC 17-18) join; authored at repo-root
  `data/balance/balance_config.tres`.
- [Source: test/state/test_action_state.gd:74-98] — the zero-inbound-CHARGING guard this story
  re-proves unedited (AC 8).
- [Source: test/state/test_card_play.gd:246,300] — the forced pin edit (`test_non_basic_modes_are_
  unreachable_in_e3`, AC 9) and the unaffected guarded-stub test (`test_the_mode_dispatch_carries_
  a_guard`).
- [Source: src/state/match_state.gd:2088-2103] — `_resolve_card_action`'s guarded-stub dispatch
  (AC 1-2), `:622` `push_contact`'s kind guard (AC 17), `:1877-1879` `_regen_stamina`'s suppression
  list (AC 14), `:2478`/`:2091` the existing DEAD branches (AC 15-16 precedent), `:746-761` step
  3(a)'s timer-exit match (AC 20's named seat).
- [Source: src/state/match_state.gd:2124-2229] — `_resolve_basic_cast`, the spend-path precedent
  (AC 5-7).
- [Source: src/state/match_state.gd:2469-2551] — `_resolve_movement`'s phase dispatch and the
  existing `_lock_directions`-driven facing write (AC 11-12).
- [Source: src/main/match_runner.gd:1821-1851] — `_push_reach_probe`, the runner-side
  planar-distance-as-fact precedent the AC 17 untethered fact follows (`5-2/R6`) without reusing
  the probe's throttled cadence.
- [Source: src/main/match_runner.gd:2234-2244] — the probe's `_probe_counter %
  minion_retarget_interval_ticks` cadence (1 tick in 12) that disqualifies its direct reuse for
  landing (AC 17, `5-2/R6`).
- [Source: src/state/match_state.gd:970,1447] — `is_in_reach_at`/`mark_in_reach_at`'s freshness
  window, the tolerance mechanism a landing check does not have (`5-2/R6`).
- [Source: src/systems/record_file.gd:522-525,678-681] — `card_mode`/`card_slot` already on the
  intent wire format.
- [Source: src/systems/record_file.gd:284-287] — `FORMAT_VERSION` mismatch refusal, the condition
  that forces a version bump if AC 17's new contact kind needs a new record channel (AC 23).
- [Source: src/state/timing/balance_ticks.gd] — the D3 seconds-to-ticks conversion boundary
  precedent for `unblockable_chargeup_ticks` (AC 10).
- [Source: src/state/targeting/targeting_service.gd:59-64] — `HERO_INDEX`/`NO_TARGET_SLOT`
  addressing convention (Ruling 8's enemy-hero-only target).
- [Source: src/state/resources/player_state.gd:205] — `PlayerState.to_snapshot()`, the pinned
  28-key set the AC 21 telegraph fact must ride (`5-2/R9`).
- [Source: src/state/economy/cast_evaluator.gd:31-58] — the `REASON_*`/`ALLOWED` refusal
  vocabulary the S6 gate's new reason should match (AC 2).
- [Source: decision-log.md Session 2026-08-07, ruling E4-P/R9] — Tier B predictions verified by
  measurement, never lowered; cited here since this story's own golden prediction (AC 22) follows
  the same discipline.
- [Source: test/state/test_data_resources.gd:14-20,84-131] — `E1_BALANCE_FIELDS` and its two-way
  reflection audit, which the four new balance fields must join.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
