---
baseline_commit: cf7489bb49e3765af893eecf165b9aa559573271
---

# Story 6.1: Hold-to-Charge

Status: done

> **Scope note.** SECOND E6 story (`E6-P/R2` board order), and the first E6 story that touches
> `src/state/`. Tier A by the golden clause AND by content — `CHARGING` gets its first exit path
> besides natural expiry and death (`5-2/R3`). Carries two inherited obligations: the Sekiro
> hold-through-chargeup shape for mode ② (`5-7/R6`, debt carried since `5-3/R6`), and the
> undischarged `E5-R/R8` item 7 (the CHARGING-hero-can-cast-BASIC question `5-6` was given an
> owner for). Operator veto on the early-release shape stays open until this story's own
> gate/dev-pass conversation (`E5-C/R6`).

## What this story supersedes / measures against the brief

The operator's ratified scope (recorded below as the Acceptance Criteria) was checked against the
shipped code before any task was written. Two findings are load-bearing and correct the inherited
record; the rest confirm the brief's assumptions.

1. **`E5-R/R8` item 7's factual claim is WRONG against the shipped code, and this story must
   REVERSE a ruling, not merely "discharge an inherited item."** The retrospective entry (session
   2026-09-07, written the SAME day as `5-6` closed) states "A `CHARGING` hero still CAN cast a
   basic card: owner named as `5-6`, untouched there" (`decision-log.md:9245-9247`). This is false
   against the code `5-6` actually shipped. `5-6`'s own AC 16 — "THE CHARGING HOLE CLOSES" — added
   exactly the opposite gate: `_resolve_basic_cast` (`match_state.gd:2395-2434`) now REFUSES a
   BASIC cast while `CHARGING`, at lines `2426-2428`:
   ```
   if player.hero.action_state == HeroState.ActionState.CHARGING:
       player.hero.reject_action(&"card_cast", REASON_UNBLOCKABLE_COMMITTED)
       return
   ```
   pinned by `test/state/test_unblockable_defense.gd:837-846`,
   `test_a_charging_hero_cannot_cast_basic`. `5-6`'s own ruling record is self-consistent and
   explicit about doing this on purpose (`5-6/R3`, decision-log.md:8941-8945; the story file's own
   pre-analysis item 5, `5-6-three-tier-ladder.md:46-56`, and AC 16,
   `5-6-three-tier-ladder.md:415-422`) — `5-6` did take up the item, and ruled it closed rather than
   open. The retrospective's "untouched there" is the error, not the code.

   The retrospective's claim is therefore a RECORD ERROR, not a ruling this story executes. It is
   corrected in the decision-log at fix+promote (`6-1/R2`, Session 2026-09-09), citing both
   `E5-R/R8` item 7 (`:9245-9247`) and `E6-P/R2`'s repetition of the same claim (`:9311-9313`) —
   neither pushed entry is edited, per the standing meta-rule. `5-6`'s gate at
   `match_state.gd:2426-2428` STAYS, and `test_a_charging_hero_cannot_cast_basic`
   (`test_unblockable_defense.gd:837-846`) stays green, UNEDITED — see AC 6 below, now a
   regression pin rather than a reversal. (Structural note, recorded so a future reader does not
   re-derive it: `_resolve_basic_cast`'s two arms are `if CHARGING: ... elif STUNNED: ...`,
   `match_state.gd:2426-2431`, not two independent `if`s — this matters only if the gate is ever
   revisited, which this story does not do.) The sibling `STUNNED` arm immediately below
   it (`match_state.gd:2429-2431`, pinned by `test_a_stunned_hero_cannot_cast_basic`,
   `test_unblockable_defense.gd:883-...`) is a DIFFERENT gate, added for a different reason (H1, a
   stunned hero un-rooting itself by casting) and was never in scope either way.
   `_unblockable_refusal_reason` (mode ②'s OWN initiation gate, `match_state.gd:2585-2594`) and
   `_resolve_defense_cast`'s CHARGING/STUNNED gate (mode ③, `match_state.gd:2745-2758`) are both
   UNTOUCHED by this finding. CHARGING stays refused for modes ② and ③, and now also for BASIC,
   exactly as it is today (AC 6, AC 7).

2. **The early-release teardown has a DIRECT three-part precedent already in the file, used twice
   for the same reason (death/round-over, not release) — follow its shape rather than inventing a
   new one.** `_reset_player` (`match_state.gd:3706-3712`) clears a `CHARGING` (or `STUNNED` or
   `DEAD`) hero on exactly three fields, named as "ONE FACT in three parts":
   ```
   hero.set_action_state(HeroState.ActionState.IDLE)
   player.charge_window.start(0)
   player.charge_color = PlayerState.NO_TELEGRAPH_COLOR
   ```
   An early-release exit is a DIFFERENT trigger (a live intent edge, not a round reset) but clears
   the identical fact in the identical three parts — the telegraph (AC 2 of the ratified scope) is
   `charge_color` + `charge_window`'s running state, exactly the pair `_reset_player` already
   treats as one fact. `_resolve_charge_landing`'s own header (`match_state.gd:2819-2824`) is the
   second precedent for "the card and stamina stay spent on every exit" (death's exact shape, now
   extended to a THIRD exit path: natural landing, death, and now early release).

3. **The chargeup's only existing exit is a TIMER read, not an intent read** — `_resolve_actions`'s
   `CHARGING` arm (`match_state.gd:960-962`) fires `_resolve_charge_landing` only when
   `not player.charge_window.is_running`. An early release needs a SECOND condition on that same
   arm (or a sibling check ahead of it) that reads the live intent instead of the timer. `BLOCKING`
   is the one existing action state whose exit already reads a live intent this same way
   (`match_state.gd:944-946`, `if not intent.is_held(&"block"): set_action_state(IDLE)`) — it is the
   closest shape to mirror, not a new pattern, though `CHARGING`'s exit must ALSO run the
   three-part teardown above (clearing the telegraph) where `BLOCKING`'s exit clears nothing extra.

4. **No held-intent channel exists for either cast commit today, and this is the gap AC 3 below
   exists to close.** `InputIntent.card_commit` is documented as "the COMMIT EDGE... just-pressed
   semantics... Held commits do not re-cast" (`input_intent.gd:62-64`), and every existing
   CHARGING-driving test constructs its continuing ticks as a bare `InputIntent.new()`. This is not
   confined to one file — measured across the whole `test/` tree, THREE state test files carry
   their own private CHARGING-driving helpers, each building bare `InputIntent.new()` ticks:

   | File | Helpers |
   | --- | --- |
   | `test/state/test_unblockable_initiation.gd` | `_unblockable_intent` `:697`, `_run_chargeup` `:722` |
   | `test/state/test_unblockable_defense.gd` | `_run_chargeup_dodging` `:1074`, `_unblockable_intent` `:1127`, `_run_chargeup` `:1181` |
   | `test/state/test_orbs_economy.gd` | `_unblockable_intent` `:501`, `_run_chargeup` `:517`, `_cast_any` `:525` |

   **If the mechanism chosen reads a live "is the cast button still held" fact via
   `intent.is_held(...)` (the `BLOCKING` precedent), EVERY ONE of those helpers reads as an
   immediate release on the tick after the cast**, because a bare `InputIntent.new()` carries an
   empty `held` dictionary. This is not a sign the new behaviour is wrong — it is the expected,
   necessary consequence of adding a held semantics where only a press-edge existed, the same shape
   `intent.held[&"block"] = true` already carries through a sustained block
   (`test_mana_economy.gd:486`, `test_totem_accelerators.gd:290`). The dev pass owes updating all
   three files' helpers (and every direct call site that drives CHARGING past its first tick) to
   hold the new fact true throughout, exactly as those helpers would need to if `BLOCKING` itself
   had been built this way. Listed here so it is budgeted, not discovered mid-pass. Two drivers are
   correctly OUT of this radius, measured: `test/integration/test_charge_telegraph_dispatch_live.gd:127`
   enters `CHARGING` by a direct `set_action_state` with no intent at all, and `KeyboardController`
   can never reach mode ② (`keyboard_controller.gd:123` hardcodes `ModeKind.BASIC`), so no
   keyboard-driven hero enters `CHARGING`.

5. **The S6 gate (who may INITIATE mode ②/mode ③) is untouched and correctly excluded from this
   story's ratified scope.** `_unblockable_refusal_reason`'s four gated states
   (`match_state.gd:2585-2594`: ROLLING/BLOCKING/ATTACKING/CHARGING → `REASON_UNBLOCKABLE_COMMITTED`,
   STUNNED → `REASON_STUNNED`) and `_resolve_defense_cast`'s mirror of the same shape
   (`match_state.gd:2745-2758`) answer "may mode ②/③ be INITIATED right now" — a question this story
   does not reopen (`5-2/R11`, S6 CLOSED). What this story adds is a THIRD question neither gate
   answers: "given an already-initiated chargeup, what happens when the confirm is released early"
   — a new question, not a reopening of S6.

6. **A feint against an armed mode ③ defense window is measured clean at four seats — no
   window-clearing code is needed or permitted.** `defense_window` advances at step 2
   unconditionally, for both players, from the ONE line in the codebase that advances it
   (`match_state.gd:441-442`; the comment at `:436-441` states explicitly that no landing path,
   defended or not, touches it) — a feint changes nothing about its countdown; it self-expires. The
   window is CONSUMED at exactly one place, inside `_resolve_charge_landing`
   (`match_state.gd:2913-2919`); a feint never calls `_resolve_charge_landing`, so nothing is
   consumed, nothing is negated, no `deflect_landed` fires, and no rung resolves — exactly AC 2's
   "no defense-rung negation", reached structurally rather than by a new check. The colour-counter
   stun (`match_state.gd:2924-2925`) is written only inside that same branch, so a feint cannot stun
   either party. The defender's snapshot key stays honest with no new code: `"defense"` is gated on
   `defense_window.is_running` (`player_state.gd:301-303`). On the attacker's side, the telegraph
   key is gated on `action_state == CHARGING` (`player_state.gd:539-541`), so the instant the feint
   writes `IDLE` the snapshot reads `[NO_TELEGRAPH_COLOR, 0]` regardless — the three-part teardown
   is still required (it stops the WINDOW, not just the snapshot), but this gate means a half-done
   teardown cannot produce a stale telegraph in the hash. **No window-clearing code may be added for
   the feint path — see `6-1/R7`, decision-log.md.**

## Story

As the operator closing the Sekiro hold-through-chargeup debt carried since `5-7/R6`,
I want mode ② (UNBLOCKABLE) to require the cast confirm to stay held through the full 1.0s
chargeup, with an early release resolving the attack into nothing while the card and stamina stay
spent,
so that the unblockable telegraph reads as a real commitment the defender can bait a release out of,
rather than a single press that commits identically whether held or not.

## Acceptance Criteria

**Mode ② becomes hold-through-chargeup.**

1. **The cast confirm (the button that commits mode ②) must remain HELD for the full authored
   chargeup duration (`balance.unblockable_chargeup_seconds`, authored `1.0`s,
   `data/balance/balance_config.tres:127`) for the attack to launch.** In ticks, this is
   `balance_ticks.unblockable_chargeup_ticks`, DERIVED (not authored) at `balance_ticks.gd:142` via
   `TimingWindow.seconds_to_ticks` (`TICK_HZ := 60.0`): `1.0`s = **60** ticks. (Parenthetical:
   `test_unblockable_initiation.gd`'s own fixture runs its chargeup at `24` ticks — a deliberate
   `BC/R3` isolation value distinct from every other fixture quantity, not the authored number; do
   not conflate the two.) Once the chargeup completes
   while still held, the attack launches and commit-until-landing holds EXACTLY as today
   (`_resolve_charge_landing`, `match_state.gd:2852-...`, unchanged) — release at any point AFTER
   the chargeup completes has no effect of any kind; the landing resolves on the reach fact exactly
   as it does today.

2. **An early release (the confirm released before the chargeup's authored tick count elapses) is
   a PAID FEINT.** On the exact tick of release:
   - The attack resolves into nothing — no landing check runs, no damage, no orb grant, no
     `hit_landed` emission, no defense-rung negation (mirrors a miss's existing "no hit" shape, but
     reached by a different trigger than `_resolve_charge_landing`'s reach read).
   - The card and the 20 stamina (`balance.unblockable_stamina_cost`) REMAIN SPENT. Nothing is
     refunded through any path — no hand restoration, no discard reversal, no stamina credit. The
     spend-on-initiation contract (`_resolve_unblockable_cast`, AC 6/19 of `5-2`) is unchanged;
     this AC only governs what happens AFTER the spend.
   - The telegraph fact clears: `charge_color` resets to `PlayerState.NO_TELEGRAPH_COLOR` and
     `charge_window` stops running — the SAME three-part fact `_reset_player` already clears for
     `CHARGING` (`match_state.gd:3706-3712`), reused for this new trigger.
   - The hero returns to normal control (`ActionState.IDLE`) on the release tick itself — no
     residual root, no residual suppression of stamina regen or reach-fact pushes past that tick
     (both already self-terminate the instant `action_state` leaves `CHARGING`, per the MEASURED
     findings above; no new code is needed to stop them beyond the state transition itself). The
     regen half is cited at `match_state.gd:2131-2139` — `_regen_stamina` reads
     `player.hero.action_state` fresh each tick with no latch and no window. `_resolve_actions`
     runs at step 3 (`match_state.gd:466-469`) and `_regen_stamina` at step 5 (`:512-514`), so on
     the release tick the hero is already `IDLE` when regen is evaluated — regen resumes ON the
     release tick, not one tick later.

3. **A tap (the shortest possible press) is the SAME paid feint as any other early release.**
   Measured against the controller: `GamepadController.sample()` reads button state ONCE per tick
   (`gamepad_controller.gd:174`) and derives the commit from a rising edge against `_prev_held`
   (`:185`, `:209`). A press and release that both occur between two samples produces NO EDGE AT
   ALL — no commit, no spend, no `CHARGING` entry, and therefore no feint: nothing happened; this
   is an input-sampling fact, not a grace window. The minimum OBSERVABLE feint is therefore one
   held tick: commit on tick N (entering `CHARGING` inside that tick's `_resolve_unblockable_cast`,
   `match_state.gd:2689`), release observed at tick N+1's sample, exit arm fires at tick N+1 step
   3 — the tap case this AC tests. No grace window and no minimum hold beyond that one-tick floor.
   (Playtest judges whether a grace window is ever needed; it is explicitly out of this story's
   scope, AC 7.)

4. **No recovery window follows a release of any kind.** The instant the hero is IDLE (AC 2's last
   bullet), it is fully controllable — no added post-release lockout, root, or action refusal
   beyond what IDLE already permits. This is a STATE-layer guarantee; it does not override the
   pre-existing pad-layer L3-chord suppression (see the L3 Open Question below and
   `gamepad_controller.gd:352`, `:365-373`) — while `cast_held` (L3) stays true, `attack`/`block`/
   `roll` are suppressed on the emitted intent regardless of `action_state`, unchanged since `5-0b`.
   (Playtest candidate if feinting proves too strong; explicitly out of this story's scope, AC 7.)

5. **The determinism contract for this new exit is intent-stream-driven, not a local guess.** The
   release must reach state through the recorded tick-by-tick intent stream (the X5 contract every
   other player-visible decision already honors) rather than through a side channel, a timer
   heuristic, or a read of live hardware state from `src/state/`. The exact field/channel shape
   (a new `InputIntent.held[...]` key mirroring `BLOCKING`'s `&"block"` precedent, vs. some other
   shape) is a DEV-PASS DECISION — see Dev Notes/Open Questions — but whatever shape is chosen must
   replay identically from a recorded stream, with the same discipline `card_mode`/`card_slot`/
   `card_commit` already observe (no raw action name leaking past the controller boundary, per
   `input_intent.gd:20-23`'s key contract, if the chosen shape is a held-action key at all).

**BASIC-while-CHARGING stays refused — a regression pin, not a reversal.**

6. **A `CHARGING` hero still CANNOT cast BASIC — this is a standing guard, not new behavior.** The
   `5-6`/AC 16 gate in `_resolve_basic_cast` (`match_state.gd:2426-2428`) — the two-line
   `if action_state == CHARGING: reject_action(...); return` block — STAYS, unedited.
   `test_a_charging_hero_cannot_cast_basic` (`test_unblockable_defense.gd:837-846`) STAYS GREEN,
   UNEDITED, and joins the standing guard list (see Project Context Rules below). The sibling
   `STUNNED` arm (`match_state.gd:2429-2431`) is unaffected either way. This AC asserts the gate as
   a regression pin this story must not move — see finding 1 above and `6-1/R2` in the
   decision-log.

7. **Nothing else about mode ② initiation, mode ③, or the S6 gate changes.**
   `_unblockable_refusal_reason` (`match_state.gd:2585-2594`) and `_resolve_defense_cast`'s own
   CHARGING/STUNNED gate (`match_state.gd:2745-2758`) are UNTOUCHED — a `CHARGING` hero still
   cannot INITIATE a second unblockable or a defense cast, and per AC 6 still cannot cast BASIC
   either.

**Determinism and golden.**

8. **The full suite passes** (`bash test/run_all.sh`), including the CHARGING-driving test helpers
   in all three files this story's AC 5 mechanism touches: `test_unblockable_initiation.gd`
   (`_unblockable_intent` `:697`, `_run_chargeup` `:722`), `test_unblockable_defense.gd`
   (`_run_chargeup_dodging` `:1074`, `_unblockable_intent` `:1127`, `_run_chargeup` `:1181`), and
   `test_orbs_economy.gd` (`_unblockable_intent` `:501`, `_run_chargeup` `:517`, `_cast_any`
   `:525`) — see finding 4 above. `test_a_charging_hero_cannot_cast_basic` (AC 6) stays unedited
   and is not part of this blast radius.

9. **Golden Prediction is measured, both directions — see the Golden Prediction section below** —
   not assumed from `E6-P/R2`'s blanket "movement PREDICTED at `6-1`" line.

**Non-Goals (explicitly out of scope — do not implement, do not guess a shape for later stories).**

- No chargeup presentation/animation of any kind (crouch, leap, hover, auto-aim model swap) — that
  is `6-1b-chargeup-presentation`, the next story. Presentation may derive the paid-feint visual
  from the telegraph fact clearing (AC 2's third bullet) without any new seam — the observation-seam
  family stays at NINE (`E5-C/R3`; `test_runner_observation_seams_are_exactly_nine`).
- No pitch-zone work of any kind (`6-2` onward).
- Keyboard is untouched. Modes ②/③ are pad-only since `5-7/R4`; this story adds no keyboard path
  and no new `project.godot` Input Map action.
- No retune of `unblockable_chargeup_seconds`, `unblockable_stamina_cost`, or
  `unblockable_reach`/the charge-reach radius.
- No partial-charge release attack — a release before the authored tick count ALWAYS resolves to
  nothing (AC 2/3), never a weaker version of the hit.
- A grace window on tap (AC 3) and a post-release recovery window (AC 4) are explicitly NOT this
  story's call — playtest candidates only, recorded so a future story does not have to rediscover
  that they were considered and deliberately deferred.
- `src/state/` must not read `CardDatabase` at any point this story touches (standing rule,
  unaffected either way since no `CardData` content is needed for this story's behaviour).

## Golden Prediction

**MEASURED, one candidate cause — `E6-P/R2`'s blanket "movement PREDICTED at `6-1`" line does not,
by itself, establish that this story's single ratified state-layer change is a mover, and the
evidence below says it is not.** (This story now carries only one candidate cause: the AC 6
BASIC-while-CHARGING reversal that `E6-P/R2` anticipated is a RECORD ERROR per finding 1/`6-1/R2`
and never happened, so there is nothing left to name as a second candidate.)

- **Candidate cause — the AC 1/2/5 hold-through-chargeup mechanism.** Whatever shape the dev pass
  picks (a new `InputIntent.held[...]` key, most likely) is INPUT, and `InputIntent` is
  "deliberately excluded from the `to_snapshot()` determinism contract" (`input_intent.gd:12-13`)
  — the golden hash is a hash of STATE snapshots, not of the intent stream. A new intent CHANNEL
  changes what `RecordFile`/`IntentRecorder` can capture (a `FORMAT_VERSION` question — settled,
  see Dev Notes and `6-1/R4`) but cannot by itself move a snapshot hash unless the new mechanism
  also changes what `MatchState` WRITES to a snapshot on some tick the golden fixture's sequence
  actually reaches. The teardown (AC 2's three-part clear) writes to fields
  (`action_state`/`charge_window`/`charge_color`) that are ALREADY snapshot keys — it does not add
  a new key — and `test/state/test_determinism.gd` comments (`:699`, `:707`, `:729`, `:860`,
  `:887`) state, repeatedly and as a MEASURED fact from `5-2`'s and `5-5`'s own close-outs, that
  **the golden fixture never casts mode ② and no hero in it ever enters `CHARGING`** ("no hero ever
  enters CHARGING", `:699-700`) — so this teardown code is never exercised by the golden sequence
  either. The candidate therefore predicts NO movement.
- **Net prediction:** on the evidence above, **the golden hash is predicted NOT to move** for this
  story, because its one ratified change touches no code path the golden fixture's sequence ever
  reaches. This PREDICTION IS NOT A SUBSTITUTE FOR THE MEASUREMENT — run the full suite and record
  the golden hash (`test/state/test_determinism.gd`, the `GOLDEN` constant) and the per-player
  snapshot key set (`test/state/test_card_observation.gd`,
  `test_the_observation_channel_adds_no_snapshot_key`, currently THIRTY keys per `6-0`'s own
  BEFORE measurement) BEFORE touching any file, and AFTER the diff. The key set is predicted to
  stay at 30 for a STRUCTURAL reason, not merely an empirical one: the `telegraph` key is present
  on EVERY tick regardless of state, gated only in its VALUE (`player_state.gd:539-541`), so the
  feint teardown cannot add or remove a key. If either the hash or the key set moves, the cause is
  NOT the candidate named above by construction — find and name the actual cause rather than
  attributing the move to it by assumption. (A NEW `InputIntent` field — as opposed to a new
  `held` dictionary key, which is not a new field — and the `FORMAT_VERSION` bump, are
  replay-format questions, not golden-hash questions, and must not be conflated with this
  measurement; see Dev Notes.)

## Tasks / Subtasks

- [x] Read the full MEASURED findings section above and the cited line ranges in `match_state.gd`,
      `input_intent.gd`, `gamepad_controller.gd`, `gamepad_profile.gd`, and
      `test_unblockable_initiation.gd`/`test_unblockable_defense.gd` BEFORE writing any code (AC: all)
- [x] Decide the intent-stream shape for the release signal (Dev Notes/Open Questions) — the
      `BLOCKING` `intent.is_held(&"block")` precedent is the strongest candidate but is a dev-pass
      call, not pre-ruled (AC: 1, 2, 5)
- [x] Wire the chosen shape through `GamepadController` (`cast_unblockable_button`,
      `_prev_held`/reconnect-priming discipline, the L3 (`cast_button`) chord interaction named as
      an open question below) (AC: 1, 2, 5)
- [x] Add the early-release exit arm to `MatchState._resolve_actions`'s `CHARGING` case
      (`match_state.gd:960-962`), reading the new intent fact ahead of (or alongside) the existing
      timer read, and the three-part teardown (`set_action_state(IDLE)` /
      `charge_window.start(0)` / `charge_color = NO_TELEGRAPH_COLOR`) mirroring
      `_reset_player`'s exact shape (AC: 1, 2, 3, 4)
- [x] Update `_unblockable_intent()`/`_run_chargeup()` and every direct CHARGING-driving helper in
      all three files (`test_unblockable_initiation.gd`, `test_unblockable_defense.gd`,
      `test_orbs_economy.gd` — see finding 4/AC 8) to hold the new release fact true throughout,
      per the MEASURED finding on the existing tests' blast radius (AC: 1, 8)
- [x] Write new tests for: the paid feint on early release (card/stamina spent, no landing, no
      orb, telegraph cleared, IDLE immediately), the tap case (AC 3), and the commit-until-landing /
      release-after-completion-is-a-no-op case (AC 1) (AC: 1, 2, 3, 4). Each new test must be shown
      RED against the absence of the exit arm before it is shown green, per the dev-pass restore
      discipline (back up the mutated file to scratchpad + SHA256 before mutating; restore by
      copying back, never `git checkout`) — a test that would pass against the un-mutated code is
      not a test.
- [x] Confirm `test_a_charging_hero_cannot_cast_basic` (`test_unblockable_defense.gd:837-846`) and
      `test_table_has_no_inbound_stunned_charging_or_dead_edges`
      (`test_action_state.gd:91-105`) both stay green, UNEDITED, as regression pins (AC: 6, 8)
- [x] Measure and record the BEFORE golden hash + snapshot key set; implement; measure AFTER; fill
      in the Golden Prediction section's result (AC: 9)
- [x] Measure and record BOTH parts of the `FORMAT_VERSION` question (Dev Notes/Open Questions,
      `6-1/R4`): (a) does the chosen shape force a bump by the round-trip test alone, and (b) does
      an existing v7 recording of a mode ② cast replay to a DIFFERENT outcome under the new
      mechanism. Bump 7 -> 8 with hard v7 rejection is the settled answer; verify the round-trip
      and record both measurements (AC: 5)
- [x] Run the full suite (`bash test/run_all.sh`) and record BEFORE/AFTER counts (AC: 8)
- [x] Live smoke with a single physical pad, flip `[0,3]` — see the Live Smoke section below

## Live Smoke

Single physical pad, flip `[0,3]` (covers both slots — modes ②/③ are pad-only, keyboard untouched).

1. **Hold-through** — arm a slot, hold L3+B for the full second: the attack lands exactly as today
   (damage, orb, telegraph runs its full length). The regression that the shipped path is untouched.
2. **Early release** — release partway: the card is visibly gone from the hand, stamina is visibly
   down 20, the telegraph/charge marker clears on the release frame, and the hero is immediately
   controllable (move responds that frame).
3. **Tap** — shortest possible press: identical outcome to (2), no grace, no partial hit.
4. **BASIC while charging is still REFUSED** — mid-chargeup, attempt a Basic cast: refused, card
   stays in hand. Regression of the shipped `5-6` gate; smoke half of AC 6.
5. **Release after completion is a no-op** — release the instant the chargeup ends: the landing
   still resolves normally.
6. **Ordinary regression** — melee, roll, block, and a Basic cast from an IDLE hero all behave as
   before; the L3-held suppression from AC 4 observed and recorded as expected, not as a defect.
7. **fps** recorded.

## Live Smoke Results

Single physical pad, flip `[0,3]`; flip reverted after.

Items 1, 2, 3, 4, 6, 7: **PASS.**

Item 5: **NOT JUDGEABLE BY EYE.** The state boundary this item exercises — a release on or after the
expiry tick still lands — is machine-pinned by `test_a_release_on_the_landing_tick_itself_still_lands`
and mutation B (see the Mutation table in the Dev Agent Record below); it is not resting on this
smoke pass to prove it. The operator observed that the chargeup ANIMATION finishes before the
authored 1.0s window expires, so a release that looks late by eye, judged against the finished
animation, is state-wise still an early release and correctly feints. Recorded as a named
presentation finding assigned to `6-1b` — the chargeup clip under-runs the authored window; the
animation is not final regardless (Non-Goals) and `6-1b` is where presentation timing is owned. See
decision-log `6-1/R15`.

[Source: docs/playtest-log.md, 2026-09-09 entry]

## Dev Notes

### Open Questions for the dev pass (named, not pre-ruled)

- **Exact intent-stream shape for the release signal.** The strongest candidate, by direct
  precedent, is a new `InputIntent.held[...]` key (e.g. `&"card_cast"` or a more specific name)
  written every tick by `GamepadController` from `unblockable_raw` (read the same way
  `block_raw`/`attack_raw` already are, `gamepad_controller.gd:164-175`), read by `MatchState` via
  `intent.is_held(...)` exactly as `BLOCKING`'s exit does (`match_state.gd:944-946`). This is NOT
  ruled — it is the shape the codebase's own precedent points at most strongly, and the MEASURED
  findings above assume it only for illustration; if the dev pass picks something else, name why.
- **The L3 chord question, named for pinning, not answered.** `cast_unblockable_button` (B) only
  produces a commit while `cast_button` (L3, the card-select modifier) is also held
  (`gamepad_controller.gd:163` for the read; `resolve_card_tick`'s fork is at `:352`, committing at
  `:365`/`:369`/`:373`, and while `cast_held` is true `attack`/`block`/`roll` are suppressed on the
  emitted intent, `:382-387`). If a player releases L3 while continuing to hold B partway through a
  chargeup, does the release-signal read B's own raw state, or does it also require L3 to still be
  held? Both are defensible; this story must pick one, name it in the dev pass's completion notes,
  and add a direct test for exactly that case.
- **`FORMAT_VERSION` bumps 7 -> 8, with hard rejection of v7 records — SETTLED, `6-1/R4`.** Not
  forced by the serialization shape: `pressed`/`held` are ALREADY serialized generically by key
  (`intent_recorder.gd:516-523`'s `copy_intent`, `record_file.gd:699-705`'s
  `_intent_from_values` — both walk `src.held`/`values["held"]` by whatever keys are present, with
  no enumerated action list to extend), so a new `held` key round-trips with zero serialization
  edits. The bump is forced instead by SEMANTIC incompatibility: the version check is an
  exact-match refusal (`record_file.gd:303-306`), and its purpose is to make an incompatible
  recording UNLOADABLE rather than silently wrong. An existing v7 recording containing a mode ②
  cast carries no `card_cast` held key, so `is_held(...)` returns false on every subsequent tick
  and the recording replays as an instant feint instead of the landing it originally produced —
  loaded without complaint, because the format version still matches. That silent divergence is
  invisible to a round-trip test alone (which records and replays within one build). The dev pass
  measures BOTH parts and reports both: (a) does the shape force a bump by the round-trip test
  (measured: no), and (b) does an existing v7 recording of a mode ② cast replay to a different
  outcome under the new mechanism (predicted: yes) — do not let (a)'s "no" answer (b). Bump to 8
  with hard v7 rejection either way.
- **`_charge_reach` staleness across a feint-then-recharge sequence.** `_charge_reach[slot]` latches
  the runner's last-pushed value and is written only while `action_state == CHARGING`
  (`match_runner.gd:667`). An early release does not explicitly clear this latch. Measured: this is
  not a NEW exposure — the same latch already persists across any two chargeups today (a hero who
  charges, lands, then immediately re-charges) and `5-2/R6`'s own design absorbs it by the runner
  re-pushing every tick a NEW chargeup is active, well before that chargeup's OWN landing tick. The
  dev pass should confirm this reasoning still holds for the feint case specifically (a feint is
  shorter than a full chargeup, so the next chargeup has strictly MORE ticks of fresh pushes before
  its own landing than a full-length one did) rather than assume it from the non-feint case alone.

### Files expected to change

- `src/state/match_state.gd`: the `CHARGING` exit arm in `_resolve_actions` (`:960-962`) and the
  teardown's new call site. `_resolve_basic_cast` (`:2412-2428`) is NOT touched — see AC 6.
- `src/controllers/gamepad_controller.gd` / `gamepad_profile.gd`: whatever the chosen release-signal
  shape needs (likely a new `held` key write, no new `@export` field unless the dev pass's shape
  requires one).
- `src/state/input/input_intent.gd`: only if the chosen shape needs a NEW TYPED field rather than a
  `held` dictionary key (see Open Questions) — prefer the dictionary-key shape if it satisfies AC 5
  without one, per `BLOCKING`'s own precedent needing none.
- `test/state/test_unblockable_initiation.gd`, `test/state/test_unblockable_defense.gd`,
  `test/state/test_orbs_economy.gd`: per the Tasks above and finding 4/AC 8.
- `src/systems/intent_recorder.gd`, `src/systems/record_file.gd`: EXPECTED TO CHANGE —
  `FORMAT_VERSION` bumps 7 -> 8 with hard v7 rejection, settled per `6-1/R4` (see Open Questions).
- No `data/` file changes expected (no retune, Non-Goals).
- No `main.tscn` / `project.godot` Input Map changes expected (no new action name, pad-only reuse
  of existing authored buttons).

### Project Context Rules

- **D3(a) — `Input.*` only under `src/controllers/`.** The release signal must be READ from
  hardware only inside `GamepadController`; `src/state/` consumes it exclusively through
  `InputIntent`. [Source: CLAUDE.md, Load-bearing invariants; project-context.md]
- **D3(b)/A2 — no global RNG/`Time`/`OS`/`Engine` in `src/state/`.** The teardown and the new exit
  arm are both pure reads of `intent`/existing `PlayerState`/`HeroState` fields; nothing in this
  story's `src/state/` diff should need a new import of any forbidden global.
  [Source: CLAUDE.md, Load-bearing invariants]
- **CONSTRAINT C — never cache a reference that can go stale; read inline.** The release fact must
  be read fresh off the tick's `InputIntent`, exactly as `card_commit`/`is_held(&"block")` already
  are — never cached from a previous tick's intent.
  [Source: project-context.md, "Autoloads (singletons)"; match_state.gd's own CONSTRAINT C comments
  throughout]
- **Signals over polling; direct subscription is the default.** No presentation-side concern in
  this story (Non-Goals defer all of it to `6-1b`), but if the dev pass finds a runner-side read is
  needed for the release signal, it must ride the existing `InputIntent` path, never a new poll.
  [Source: project-context.md, "Signals over polling"]
- **Guard mechanism over guard pattern.** Three guards must stay green, UNEDITED: the nine-seam
  observation family guard (`test_runner_observation_seams_are_exactly_nine`,
  `test_architecture_invariants.gd:309`), the zero-inbound-CHARGING `TRANSITION_TABLE` guard
  (`test_table_has_no_inbound_stunned_charging_or_dead_edges`, `test_action_state.gd:91-105`), and
  — per AC 6 — `test_a_charging_hero_cannot_cast_basic` (`test_unblockable_defense.gd:837-846`),
  which JOINS this list rather than being deleted or inverted. This story's exit is a direct
  `_resolve_actions` arm exactly like `BLOCKING`'s, never a table row.
  [Source: project-context.md, "Testing Rules"; test/state/test_architecture_invariants.gd]

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md:205-206 (the `6-1` line),
  :242-280 (E6 obligations block)]
- [Source: decision-log.md Session 2026-09-08 — E6 planning, `E6-P/R2` (:9301-9316)]
- [Source: decision-log.md Session 2026-09-07 — 5-7 close-out, `5-7/R6` (:9022-9027)]
- [Source: decision-log.md Session 2026-09-07 — E5 close-out, `E5-C/R6` (:9086-9088)]
- [Source: decision-log.md Session 2026-09-07 — E5 retrospective, `E5-R/R8` item 1 (:9227-9231) and
  item 7 (:9245-9247) — item 7's factual claim is a RECORD ERROR, corrected by this story's own
  MEASURED finding 1 and `6-1/R2` (Session 2026-09-09), with no code consequence; `E6-P/R2`'s
  repetition of the same claim (:9311-9313) is corrected by the same entry]
- [Source: decision-log.md Session 2026-09-07 — 5-6 close-out, `5-6/R3` (:8941-8945)]
- [Source: decision-log.md Session 2026-09-04 — 5-2 gate rulings, `5-2/R3` (:8615-8617), `5-2/R4`
  (:8619-8622), `5-2/R6` (:8626-8629), `5-2/R7` (:8631-8634), `5-2/R11` (:8647-8653)]
- [Source: sprint-status.yaml story_notes, `6-1-hold-to-charge` line]
- [Source: src/state/match_state.gd:911-974 (`_resolve_actions`, the `CHARGING` timer-exit arm
  and `BLOCKING`'s intent-read exit it mirrors), :2395-2434 (`_resolve_basic_cast`, the AC 16 gate
  this story leaves untouched — see AC 6), :2585-2594 (`_unblockable_refusal_reason`, untouched), :2635-2693
  (`_resolve_unblockable_cast`, untouched spend/entry), :2696-2758 (`_resolve_defense_cast`,
  untouched CHARGING gate), :2809-2900ish (`_resolve_charge_landing`, untouched landing/teardown
  precedent), :3668-3716 (`_reset_player`, the three-part teardown precedent this story reuses for
  a new trigger)]
- [Source: src/state/player_state.gd:176-212 (`charge_window`/`charge_color`/`NO_TELEGRAPH_COLOR`)]
- [Source: src/state/input/input_intent.gd:20-23 (key contract), :44-64 (the card half, `card_commit`'s
  press-edge documentation)]
- [Source: src/controllers/gamepad_controller.gd:150-214 (`sample()`'s read/dispatch order, the
  `_prev_held` discipline), :263-... (`resolve_card_tick`)]
- [Source: src/controllers/gamepad_profile.gd:68-99 (`cast_button`/`cast_basic_button`/
  `cast_unblockable_button`/`cast_defense_button`, the L3-chord and Y-no-op precedents)]
- [Source: src/systems/intent_recorder.gd:509-529 (`copy_intent`, the generic held/pressed walk)]
- [Source: src/systems/record_file.gd:157 (`FORMAT_VERSION`, bumps 7 -> 8), :303-306 (the
  exact-match version-refusal check the bump exists to trigger), :699-709 (`_intent_from_values`,
  the generic held/pressed walk)]
- [Source: src/state/timing/balance_ticks.gd:142 (derives `unblockable_chargeup_ticks` from
  `unblockable_chargeup_seconds`), src/state/timing/timing_window.gd:10, :20-23
  (`seconds_to_ticks`, `TICK_HZ := 60.0`)]
- [Source: src/main/match_runner.gd:637-689 (`_push_charge_reach_facts`, the every-tick-while-
  CHARGING latch and its self-terminating guard)]
- [Source: test/state/test_unblockable_initiation.gd:36-37 (fixture constants, including the `24`
  tick isolation value), :54-357 (the commit-until-landing / hard-root / regen-suppression /
  exact-tick-exit pins this story's mechanism must coexist with), :697 (`_unblockable_intent`),
  :722 (`_run_chargeup`) — two of the three test blast-radius helpers, see finding 4]
- [Source: test/state/test_unblockable_defense.gd:814-890 (the `5-6` AC 15/16/H1 cast-seat gates,
  `test_a_charging_hero_cannot_cast_basic` at :837-846 — the test this story PINS, UNEDITED, as a
  standing guard, per AC 6), :1074 (`_run_chargeup_dodging`), :1127 (`_unblockable_intent`), :1181
  (`_run_chargeup`) — the third file's blast-radius helpers]
- [Source: test/state/test_orbs_economy.gd:501 (`_unblockable_intent`), :517 (`_run_chargeup`),
  :525 (`_cast_any`) — the third CHARGING-driving file, see finding 4/F5]
- [Source: test/state/test_action_state.gd:91-105
  (`test_table_has_no_inbound_stunned_charging_or_dead_edges`, the zero-inbound-CHARGING
  `TRANSITION_TABLE` guard this story's exit arm must NOT become a row of)]
- [Source: test/state/test_determinism.gd:699-700, :707, :729, :860, :887 (the golden fixture never
  casts mode ②/never enters CHARGING — the Golden Prediction's evidentiary basis); :891 (`GOLDEN`
  constant)]
- [Source: test/state/test_card_observation.gd (the 30-key snapshot-set pin, per `6-0`'s own BEFORE
  measurement — re-measure fresh rather than trusting that prior story's number to still be current)]
- [Source: data/balance/balance_config.tres:126-127 (`unblockable_stamina_cost = 20.0`,
  `unblockable_chargeup_seconds = 1.0`)]

## Dev Agent Record

### Agent Model Used

Opus 5 (operator-stated). The pass's full record is APPENDED below as "Dev Agent Record — appended by the dev pass (2026-09-09)"; this stub is left in place rather than replaced.

### Debug Log References

### Completion Notes List

### File List

---

## Dev Agent Record — appended by the dev pass (2026-09-09)

### Agent Model Used

Opus 5 (operator-stated)

### Debug Log References

Full-suite outputs were written OUTSIDE the repo, per the ratified suite mechanism, and read by
opening the file rather than tailing it:

| Run | File | mtime | Result |
| --- | --- | --- | --- |
| 1 — BEFORE baseline, before any edit | `C:\dev\_61-suite-before.txt` | 2026-09-09 11:46:52 | 720 tests / 0 failed / 5363 assertions; 56 integration PASS; ALL TESTS PASSED |
| 2 — AFTER the diff | `C:\dev\_61-suite-after.txt` | 2026-09-09 12:03:49 | 735 / 0 / 5430 state PASS; **1 integration FAIL** (`test_charge_telegraph_dispatch_live.gd`); SOME TESTS FAILED |
| 3 — final certification | `C:\dev\_61-suite-after2.txt` | 2026-09-09 12:08:49 | 735 tests / 0 failed / 5430 assertions; 56 integration PASS; ALL TESTS PASSED |

**THE THIRD RUN IS DISCLOSED WITH ITS REASON rather than folded into the second.** Run 2 surfaced a
GENUINE regression this story's own MEASURED finding 4 had mis-measured (see Completion Note 3); a
run after the fix was the only way to certify the final state. Budget interval: 11:46:52 to 12:08:49
(21m57s). Iteration between the runs used the state harness and single integration files directly,
which write no suite file and are not full-suite runs.

### Completion Notes List

**1. DEV CALL — the intent-stream shape for the release signal: a `held` dictionary key,
`&"card_cast"`, and NOT a new typed `InputIntent` field.** The `BLOCKING` precedent
(`match_state.gd:944-946`) is followed exactly as the story's Open Question expected: `held` is the
dictionary the state layer already reads live per tick, the key is PREFIX-FREE and names no pad
button (`input_intent.gd:20-23`'s contract), and `BLOCKING`'s own exit needed no new field either.
The name `&"card_cast"` is the token the codebase ALREADY uses for this action — it is the
`reject_action(&"card_cast", ...)` label at every cast refusal seat — so no new vocabulary enters
the system. `InputIntent` is UNCHANGED: not one line, which is the outcome the story's
Files-expected list preferred.

**2. DEV CALL — the L3 chord fork: the release signal reads B's OWN raw state, ALONE.**
`card_cast_held` is `unblockable_raw`, deliberately not `unblockable_raw and cast_held`. Reasoning,
recorded because the story asked for it to be named: L3 (`cast_button`) is the ARMING modifier and
its entire product is `armed_slot`, a job that is finished the instant the commit fires — the
chargeup it started belongs to B. Conjoining them would let the release of a MODIFIER destroy an
already-paid attack, and would do it on the one input the player has most reason to let go of
(`resolve_card_tick`'s own `else` arm resets `armed_slot` to -1 precisely because L3-up means "done
selecting"). AC 4's pad-layer suppression is unchanged either way. Pinned directly by
`test_resolve_card_tick_reports_the_unblockable_confirm_as_held`, whose third row IS this decision,
and mutation-proven against the rejected alternative (mutation D below). The other two confirms
(A/X) are excluded for the same class of reason: neither mode ① nor mode ③ has a hold contract, and
folding them in would let a held A keep a chargeup alive.

**3. MEASURED CORRECTION TO THIS STORY'S OWN FINDING 4 — `test_charge_telegraph_dispatch_live.gd`
IS inside the blast radius, and the story says it is not.** Finding 4 excluded it on the ground that
it "enters `CHARGING` by a direct `set_action_state` with no intent at all". That is true of the
ENTRY and is not the whole question: the poke must SURVIVE `CHECK_DELAY` frames to be measurable,
and each of those frames is a real `advance()` driven by real controllers, which with no pad
connected emit a neutral intent — a release. MEASURED (run 2, then reproduced in isolation): all
three colours read clip `idle`, a dark ChargeMarker and total silence. Fixed at the INPUT SEAM,
where the new fact lives: the test installs a `HoldingController` stand-in on P1 for the frames it
measures. Re-run in isolation: PASS, non-vacuously (`[swipe, thrust, jump_attack]`,
`[StingChargeRed, StingChargeBlue, StingChargeGreen]`). P2 keeps its real controller, so the file's
cross-slot claim is untouched. **The general lesson, recorded rather than left to be rediscovered:
finding 4's own sentence ("every direct call site that drives CHARGING past its first tick") is the
correct rule; its exclusion list applied that rule to entry points only.**

**4. AC 6's "UNEDITED" CLAUSE COULD NOT SURVIVE THE MECHANISM THE SAME STORY RATIFIES — three test
bodies gained one argument each, and this is flagged for the operator rather than absorbed.** The
gate at `match_state.gd:2426-2428` is UNTOUCHED and every assertion in every affected test is
UNCHANGED; what changed is the FIXTURE's expression of "the hero is still charging". Cause,
measured: `_resolve_actions` is step 3 and `_resolve_card_action` is step 6, so on a tick whose
intent carries no `card_cast` held key the feint fires BEFORE the cast is evaluated, and the hero
the gate is meant to refuse is already IDLE. This is finding 4's predicted blast radius reaching
three tests the story listed as outside it. Affected, in `test_unblockable_defense.gd`:
`test_a_charging_hero_cannot_cast_basic`, `test_a_charging_hero_cannot_cast_defense`,
`test_the_basic_cast_state_gate_precedes_the_empty_slot_gate`. Each now passes `[&"card_cast"]`
through the file's own established `held: Array = []` helper idiom (`_defense_intent` already had
that seat; `_basic_intent` gained it). On real hardware this is live-play truth — B stays down while
A or X is pressed. **The two guards named in Project Context Rules are genuinely UNEDITED and green:
`test_table_has_no_inbound_stunned_charging_or_dead_edges` and
`test_runner_observation_seams_are_exactly_nine` (their files carry no diff at all).**

**5. THE ARM'S ORDER IS THE WHOLE OF AC 1's LAST SENTENCE, and it is structural rather than a second
check.** The timer is the `if` and the release the `elif`, so once the window has stopped running
the chargeup is COMPLETE and a release observed on that same tick LANDS. There is no tick on which
both are true and the wrong one wins. Mutation-proven in both directions (B and C below).

**6. `_charge_reach` STALENESS ACROSS FEINT-THEN-RECHARGE — confirmed, not assumed from the
non-feint case.** The latch is written every tick a NEW chargeup is active (`match_runner.gd:667`),
and a feint is strictly SHORTER than a full chargeup, so the next chargeup has strictly MORE ticks
of fresh pushes before its own landing than a full-length one does. The feint case is therefore
strictly safer than the sequence `5-2/R6` already absorbs. No code needed;
`test_a_feint_frees_the_next_cast_while_the_charging_gate_stays_shut` drives feint-then-recharge and
the new chargeup behaves normally.

**7. `_reset_player` WAS NOT REFACTORED into a shared teardown helper.** The three lines are written
inline in the new arm, citing `_reset_player` by line. That function clears the action state only
under a three-state gate and clears `hero.stun` and the defense window in the same breath; the
SHARED shape is these three lines, not that function's body, and factoring it out would have made
the new arm depend on a gate it does not want.

**8. LIVE SMOKE IS NOT DONE — the one task left unchecked.** It needs a physical pad and the
operator; this pass ran headless only. All seven smoke items stand as written.

### FORMAT_VERSION — BOTH parts measured (`6-1/R4`)

**(a) Does the chosen shape force a bump by the round trip alone? MEASURED: NO.** `held` is walked
generically by key at both ends (`copy_intent`, `_intent_from_values`), so the new key round-trips
with ZERO serialization edits. Committed as a test rather than argued:
`test_a_new_held_key_round_trips_without_any_serialization_edit` (`test_record_file.gd`) saves and
loads a `card_cast` held key and gets it back — and asserts the other direction too, that an ABSENT
key comes back ABSENT and is never invented as `true`, which is exactly the read a v7 record gets.

**(b) Does an existing v7 recording of a mode ② cast replay to a DIFFERENT outcome? MEASURED: YES,
and (a)'s "no" does not answer it.** A v7 record carries no `card_cast` key, so `is_held` reads
false on every tick after the commit and a chargeup that LANDED when it was recorded replays as an
instant paid feint — loaded without complaint, because a matching version is all the loader checks.
The divergence is measured at the state layer by a pair of tests with identical per-tick
`card_slot`/`card_mode`/`card_commit` values; the tests differ in length:
`test_holding_the_confirm_through_the_whole_chargeup_lands_as_before` (lands 10.0 damage, one
`hit_landed`) versus `test_a_one_tick_tap_is_the_same_paid_feint` (no damage, nothing announced).

**Resolution: `FORMAT_VERSION` 7 -> 8 with HARD rejection of v7**, via the pre-existing exact-match
refusal (`record_file.gd:303-306`) — no migration shim, per the `4-1/R1` family reasoning. This is
the first bump in this file's history that the SHAPE did not force, and the constant's docblock says
so. Both version pins in `test_record_file.gd` were updated to 8 and mutation-proven (mutation E).

### Golden and snapshot key set — BEFORE and AFTER

| | BEFORE | AFTER | Moved? |
| --- | --- | --- | --- |
| `GOLDEN` (`test_determinism.gd:891`) | `d5bcb7e63423ada259c69be8276396db071bb0de1bcb55a2ce8c664ad07eb87d` | `d5bcb7e63423ada259c69be8276396db071bb0de1bcb55a2ce8c664ad07eb87d` | **NO** |
| Per-player snapshot key set (`test_card_observation.gd`) | 30 | 30 | **NO** |

**The prediction held, and it held for the structural reason the story gave rather than by luck.**
The golden fixture never casts mode ② and no hero in it ever enters `CHARGING`, so the new arm is
never evaluated by the golden sequence; the teardown writes only fields that were already snapshot
keys; and `telegraph` is present on every tick regardless of state (gated in its VALUE at
`player_state.gd:539-541`), so the feint can neither add nor remove a key. Neither
`test_determinism.gd` nor `test_card_observation.gd` carries a diff — both values above are read
from files this pass did not touch, and both files pass in run 3. **Nothing was re-baselined.**

### Mutation table

Every mutation was applied to a file first backed up to a scratchpad OUTSIDE the repo with its
SHA-256, and restored by COPY-BACK with the hash re-verified — never `git checkout`.

| # | Mutation | Effect |
| --- | --- | --- |
| A | `match_state.gd` — the early-release arm DELETED entirely | **8 of 13** new tests in `test_unblockable_hold.gd` RED: the IDLE-on-release-tick, three-part-teardown, paid-spend, no-landing, defense-window, tap, regen and no-recovery-window tests |
| B | `match_state.gd` — arm order INVERTED (release read before the timer) | **1** RED: `test_a_release_on_the_landing_tick_itself_still_lands` — the AC 1 boundary, and the only test that can see this |
| C | `match_state.gd` — the arm fires regardless of the hold (`elif true:`) | **46** RED suite-wide, including `test_holding_the_confirm_through_the_whole_chargeup_lands_as_before` and `test_the_same_armed_window_does_answer_a_chargeup_that_is_held_out` — proof the three sibling files' updated helpers now drive a REAL hold rather than decorating one |
| D | `gamepad_controller.gd` — `card_cast_held: unblockable_raw and cast_held` (the REJECTED L3 fork) | **1** RED: `test_resolve_card_tick_reports_the_unblockable_confirm_as_held` — the dev call of note 2 is pinned, not merely commented |
| E | `record_file.gd` — `FORMAT_VERSION` back to 7 | **2** RED: both version pins in `test_record_file.gd` |

Two tests were STRENGTHENED when mutation A found them green:
`test_an_early_release_is_paid_the_card_and_the_stamina_stay_spent` gained an IDLE precondition
(without it, "nothing was refunded" is trivially true of a chargeup still running) and
`test_releasing_after_the_chargeup_completed_changes_nothing` gained a landing-happened
precondition. They are RED under A and C respectively afterwards.
`test_a_new_held_key_round_trips_without_any_serialization_edit` is labelled honestly as a
MEASUREMENT of half (a), not a new-behaviour test — its subject is that the existing generic walk
needed no edit, and no mutation of this story's own code turns it red.

### File List

Production (3):

- `src/state/match_state.gd` — the early-release arm in `_resolve_actions`'s `CHARGING` case
- `src/controllers/gamepad_controller.gd` — `card_cast_held` in `resolve_card_tick`, written to `intent.held[&"card_cast"]` in `sample()`
- `src/systems/record_file.gd` — `FORMAT_VERSION` 7 to 8 and its reason

Tests (7, one new):

- `test/state/test_unblockable_hold.gd` — **NEW**, 13 tests, this story's own behaviour
- `test/state/test_unblockable_initiation.gd` — `_holding()`; chargeup-driving sites hold (two sites deliberately left bare, each with its reason in place)
- `test/state/test_unblockable_defense.gd` — `_holding()`; `_basic_intent` gains the `held` seat; three AC-6-family fixtures state the hold (see note 4)
- `test/state/test_orbs_economy.gd` — `_holding()`; chargeup-driving sites hold
- `test/state/test_record_file.gd` — two version pins to 8; the new round-trip measurement
- `test/state/test_gamepad_controller.gd` — the L3-chord fork pinned
- `test/integration/test_charge_telegraph_dispatch_live.gd` — `HoldingController` stand-in (see note 3)

NOT touched, verified by `git status`: `project.godot` (zero diffs, no new Input Map action),
`src/state/input/input_intent.gd`, `src/controllers/gamepad_profile.gd`, `data/`, `main.tscn`,
`test/state/test_determinism.gd`, `test/state/test_card_observation.gd`,
`test/state/test_action_state.gd`, `test/state/test_architecture_invariants.gd`. No new snapshot
key, no new observation seam (the family stays at NINE), no new `class_name` (so no editor scan was
run this pass; the new test file's `.uid` is left to the chain).
