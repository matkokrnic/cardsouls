---
baseline_commit: 690f162a4b508d4c3e3718277e452555d949078e
---

# Story 6.9: Click-to-Commit

Status: ready-for-dev

<!-- Tier A: touches src/state/ (match_state.gd CHARGING arm), FORMAT_VERSION, and replay. Full gate + review + live smoke ritual. -->

## Story

As a player casting an unblockable,
I want pressing the cast button to commit the attack, with nothing to hold and nothing to cancel,
so that the attack reads as a decision made at the press, and my opponent's colour read is the only
thing standing between me and the landing.

Tier A. Operator ruling, settled at authoring and not open for this story to relitigate: **mode 2
(UNBLOCKABLE) becomes click and commit.** The press commits. There is no holding, no early release,
no feint, paid or otherwise. The 1.0 s chargeup window stays as authored and the attack is
commit-until-landing, exactly as it was before `6-1`. Card and stamina are spent on the press and the
attack always resolves.

This story SUPERSEDES `6-1` (hold-to-charge / paid feint, `6-1/R1`..`R15`) on the operator's decision
recorded at the `6-6b` close-out (decision-log, "Deferred / next": *Click-to-commit superseding the
`6-1` hold/feint -> NEW story `6-9`*).

## Board note

`6-10-card-mode-toggle` (L3 toggle) follows this story and is NOT part of it.

## Acceptance Criteria

Behaviour, not mechanism, except where a ruling above fixed the mechanism (the release arm, the
`held[&"card_cast"]` key, the debug hold, FORMAT_VERSION).

1. **A press commits.** A mode 2 cast whose `card_commit` press is accepted carries the attack to its
   landing with NO further input from that player. A run in which every intent after the commit tick is
   a bare `InputIntent.new()` lands the attack on the same tick, with identical hero HP, orb, stamina,
   card and `hit_landed` outcomes, as a run whose every post-commit intent holds every LIVE held key
   (`&"attack"`, `&"block"`, `&"roll"`, `&"run"`) and carries a full move vector. Neither run sets
   `held[&"card_cast"]`, which no longer exists (AC 7).
2. **Nothing cancels it from input.** After the press, each of the following seven input rows leaves the
   hero `CHARGING` until the landing tick, except row 7, which is asserted as an EXIT:
   1. a bare `InputIntent.new()` (the release of everything);
   2. each live held key alone: `held[&"attack"]`, `held[&"block"]`, `held[&"roll"]`, `held[&"run"]`;
   3. each live pressed key alone: `pressed[&"attack"]`, `pressed[&"block"]`, `pressed[&"roll"]`;
   4. all of rows 2 and 3 at once (the "hold every button" chord);
   5. `move_dir` at each of `Vector2.ZERO`, a unit vector along +X, -X, +Y, -Y, and one diagonal;
   6. a second card press, `card_commit = true` with `card_mode = UNBLOCKABLE`, and again with `BASIC`,
      `DEFENSE` and `PITCH`: REFUSED with `REASON_UNBLOCKABLE_COMMITTED`, and the hero does not leave
      `CHARGING`;
   7. `debug_reset = true`, which DOES leave `CHARGING` (`_reset_player`, `match_state.gd:4987-4992`) and
      is asserted as an exit, not a stay. This row keeps the table non-vacuous: without a legitimate
      exit, "stays `CHARGING`" would be satisfied by a `_resolve_actions` that does nothing.

   The only exits from `CHARGING` are the four that already exist and are not input reads:
   the landing (`_resolve_charge_landing`), the colour counter judging it (`6-6b`), a knockdown
   abandoning it (`6-6a/R1`), and death / the debug reset (`_reset_player`). No input-driven exit remains.
3. **Costs unchanged.** The card is discarded and the stamina spent on the press exactly as today
   (`_resolve_unblockable_cast`). The attack always resolves: there is no path on which a paid chargeup
   ends without a landing verdict except the four exits in AC 2.
4. **The 1.0 s chargeup window is untouched.** `unblockable_chargeup_seconds = 1.0`
   (`data/balance/balance_config.tres`) stays a knob; `unblockable_chargeup_ticks` still derives to 60.
   The commit point (chargeup window closed, landing window running), the per-colour launch spans and the
   landing tick are unchanged. This story edits no `.tres` value.
5. **Telegraph clears on landing.** After this story the `telegraph` snapshot fact
   (`[charge_color, charge_window.remaining_ticks()]`) returns to its resting `[-1, 0]` because the hero
   leaves `CHARGING` at the landing, and NOT because of any release. Measured Fact 5 records which
   writers exist today; the release writer is deleted, and the knockdown / counter / reset clears are kept.
6. **The release arm is gone.** `_resolve_actions`' `CHARGING` branch has one attack-driven arm, the
   landing (after the `6-6b` counter check, which is not an input read). No `intent.is_held(...)` read of
   `&"card_cast"` remains in `src/state/`. The `_reset_player` three-part teardown (state,
   `charge_window`, `landing_window`, `charge_color`) is untouched and still serves death / reset (and the
   two abandonment sites that reuse the same three lines).
7. **The controller stops writing `held[&"card_cast"]`.** No controller and no fixture produces the key.
   `GamepadController.resolve_card_tick` no longer returns `card_cast_held`. Every producer and consumer
   listed in Measured Fact 2 is removed or rewritten. From `C:\dev\cardsouls` (PowerShell 5.1, no `&&`):
   `Get-ChildItem src,test -Recurse -Filter *.gd | Select-String -Pattern 'card_cast_held|held\[&"card_cast"\]|is_held\(&"card_cast"\)' | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" }`
   returns ZERO lines (comments included). Negative control: `(Get-ChildItem src -Recurse -Filter *.gd | Select-String -Pattern 'reject_action\(&"card_cast"').Count`
   reads 26 at HEAD `690f162` and reads 26 after the story (the action-name token on `action_rejected`
   is not the held key and is not touched).
8. **The feint suite is retired, and nothing that proved a real claim is lost.**
   `test/state/test_unblockable_hold.gd` is deleted. Before deletion the dev pass classifies each of its
   13 tests as FEINT-ONLY (drop) or SURVIVING (a claim that stays true, e.g. "a held-out chargeup is
   countered", "the landing tick lands"), and every surviving claim is confirmed covered by another suite
   or is moved there. The 13-row classification in Measured Fact 6 is the starting point; the dev pass
   confirms it and records the result in the Dev Agent Record.
9. **Fixtures go back to bare intents.** Every fixture that was given `card_cast` held on a commit or
   continuing tick to survive `6-1`'s release arm (Measured Fact 4) returns to a bare intent. The
   `_holding()` helpers and the `card_cast` uses of the held-key parameter are removed; the `held`
   parameter of `_basic_intent` / `_defense_intent` / `_cast_defense` stays wherever it carries `block`
   (that use is `3-0b`'s, not `6-1`'s).
10. **The debug keys simplify.** Story `6-D1`'s X / V / B (`p1_debug_unblockable_red/blue/green`) commit on
    a single tap with no auto-hold: `DEBUG_HOLD_TICKS`, `_debug_hold_left` and the `held[card_cast]` write
    are deleted, along with the test that pins the hold
    (`test_debug_key_holds_card_cast_after_release_for_the_debug_duration`); the `is_held(&"card_cast")`
    line inside each of the three tests that stay (`test_controller.gd:164`, `:191`, `:201`) is stripped.
    The one-commit-per-press edge, the
    first-card-of-colour pick and the no-card-neutral rule (`6-D1` AC 2, 4, 5) are unchanged.
11. **Format refusal.** `RecordFile.FORMAT_VERSION` 11 -> 12. A v11 record is REFUSED with a reason that
    names both versions; there is no shim and no migration. The refusal is pinned by a
    `test_a_v11_record_is_refused_with_a_reason` in the shape of `test_a_v10_record_is_refused_with_a_reason`,
    and a v12 round-trip inside this build is pinned (save then load returns the same intents).
12. **Presentation survives untouched.** The `6-1b` chargeup re-tempo (`_CHARGE_HOLD_KNOBS`, the
    `charge_playhead_seconds` mapping, `_push_charge_progress`) is unedited in behaviour. The only
    measured change is that the clip can no longer be cut short mid-window by input. The knob triples are
    not re-tuned (Non-Goals).
13. **`6-6b` state is untouched.** The counter judgement, the defence window and their seams are not
    edited. The defence window is the whole counter (`6-6b/R19`).
14. **Golden and snapshot unmoved.** See Golden Prediction. Any movement is STOP-and-report, never a
    re-baseline.
15. **Guards stay green.** `test_architecture_invariants.gd` (F1, D3(a), D3(b)/A2), the input-map pin
    (`SHIPPED_INPUT_ACTIONS`) and the physical-key collision guard stay green, and `project.godot` is not
    edited (the debug keys keep their existing actions).

## Non-Goals

- **Changing the chargeup duration.** It stays 1.0 s as authored (operator ruling). The value remains a
  knob in `data/balance/balance_config.tres`; tuning it is a later retune-block matter.
- **Re-tuning the `6-1b` `_CHARGE_HOLD_KNOBS` triples** (`src/actors/hero/animation_controller.gd:328`).
- **Any change to `6-6b` state.** The defence window is the whole counter (`6-6b/R19`); this story does
  not touch it.
- **Story `6-10`, the card-mode toggle (L3)**, which follows this one, including the "held L3 kills L2
  block" item.
- **Whether the colour counter rewards enough** — deferred to the playtest / retune block.
- The `unblockable_swing_at_commit` knob (`6-1d`, OFF): its doc wording ("the tick the attack becomes
  unfeintable", `balance_config.gd:411`) is a comment to reword, not a behaviour to touch.
- Any new public API, folder or intent field. This story only deletes and simplifies.

## Measured Facts (citations verified against HEAD `690f162`)

### 1. The release arm (named deletion 1)

`src/state/match_state.gd:1345-1354`:

```
1345  HeroState.ActionState.CHARGING:
1346      if _resolve_color_counter(player, slot):
1347          return
1348      if not player.landing_window.is_running:
1349          _resolve_charge_landing(player, slot)
1350      elif player.charge_window.is_running and not intent.is_held(&"card_cast"):
1351          hero.set_action_state(HeroState.ActionState.IDLE)
1352          player.charge_window.start(0)
1353          player.landing_window.start(0)
1354          player.charge_color = PlayerState.NO_TELEGRAPH_COLOR
```

The `elif` at `:1350` and its four-line body `:1351-1354` are the deletion; `if landing` survives. The
arm's justifying comment block is `match_state.gd:1288-1344` and is rewritten to describe only the
landing and the counter-first ordering (which is `6-6b`'s and is kept).

Comment sites elsewhere in `src/` that name the feint or the release as live behaviour and go stale (edit
as comments, no behaviour): `match_state.gd:1054`, `:3557`, `:3755-3757`, `:3791-3792`, `:3860-3864`,
`:3905`; `player_state.gd:217`, `:317-320`, `:629`; `balance_config.gd:411`; `match_runner.gd:847`,
`:863`; `animation_controller.gd:687`; `gamepad_controller.gd:486`. `record_file.gd:165-166` is history and
stays, but its comment currently spells the callable form `is_held(&"card_cast")` (`:165`), which AC 7's
zero-line search matches: reword it to name "the `card_cast` held key" so the history survives and the
search comes back empty. The `6-9` bump paragraph is added beside it. (Pre-existing, not this story's
defect, but Task 1's sweep passes over it: `record_file.gd:168` says "the exact-match refusal at
`:303-306`"; the refusal is at `:349-353`. Correct the reference while there.)

The writers of the teardown fact (`charge_window.start(0)`, `landing_window.start(0)`,
`charge_color = NO_TELEGRAPH_COLOR`): this arm (`:1352-1354`, DELETED), the knockdown abandonment
(`:3776-3778`, `6-6a/R1`, KEPT), the colour-counter teardown (`:3922-3924`, `6-6b`, KEPT) and
`_reset_player` (`:4987-4992`, KEPT). `charge_color` is otherwise assigned only at the cast (`:3416`).

### 2. Producers and consumers of `held[&"card_cast"]` (named deletion 2)

`InputIntent.held` is generic; the key is a plain `StringName`. Enumerated across `src/`, `test/`, `data/`.
The many `reject_action(&"card_cast", ...)` and `[&"card_cast", reason]` matches are the ACTION-NAME token
on `action_rejected`, a different thing, and are NOT touched.

**Producers in `src/`:**
- `src/controllers/gamepad_controller.gd:219` `intent.held[&"card_cast"] = result["card_cast_held"]`; the
  value is computed at `:489` `"card_cast_held": unblockable_raw` in `resolve_card_tick`, with its long
  `6-1` rationale comment (the L3 chord fork) at `:470-488`.
- `src/controllers/keyboard_controller.gd:164` `intent.held[&"card_cast"] = true` (the `6-D1` auto-hold),
  with `DEBUG_HOLD_TICKS` `:99`, `_debug_hold_left` `:102`, `:162-165` and the docblock `:93-98`.

**Consumers in `src/`:**
- `src/state/match_state.gd:1350` — the release arm (AC 6). It is the ONLY reader of the key in
  `src/state/`; `:4265` reads `&"run"` and `:1274` reads `&"block"`, both unrelated.
- No other reader. `src/systems/intent_recorder.gd:570-571` (`copy_intent`) and
  `src/systems/record_file.gd:604`, `:767` walk `held` by whatever keys are present, so the key
  round-trips with zero serialization edits (which is exactly why the bump below is a SEMANTIC bump,
  `6-1/R4`).

**Producers in `test/`:** `test_unblockable_hold.gd:375`; `test_unblockable_defense.gd:2420` (`_holding`),
`:213` and `:1481` (passing `[&"card_cast"]`), `:1544`; `test_unblockable_initiation.gd:709` (`_holding`);
`test_unblockable_tracking_and_reach.gd:1071` (`_holding`); `test_orbs_economy.gd:509` (`_holding`);
`test_pitch_changed.gd:339`; `test_pitch_staging.gd:124`, `:555`; `test_record_file.gd:852`;
`test_controller.gd` (the `6-D1` hold tests at `:164-201`); integration
`test_charge_telegraph_dispatch_live.gd:60`, `test_honest_hit_geometry_live.gd:53`,
`test_unblockable_reach_live.gd:55`.

**Consumers in `test/`:** every read of `["card_cast_held"]` (`test/state/test_gamepad_controller.gd:587-614`)
and every `is_held(&"card_cast")` (`test_controller.gd:164-201`, `test_record_file.gd:859-862`).

Helper-call counts (`_holding` and siblings, measured): 40 in `test_unblockable_tracking_and_reach.gd`, 28
in `test_unblockable_defense.gd`, 24 in `test_unblockable_initiation.gd`, 17 in `test_unblockable_hold.gd`,
5 in `test_orbs_economy.gd`, 4 in `test_pitch_changed.gd`, 1 in `test_gamepad_controller.gd`. That is the
size of the reverse blast radius; the dev pass re-measures rather than trusting these numbers.

### 3. Question (a): does any presentation-layer code read `held[&"card_cast"]`?

**No. The working hypothesis is CONFIRMED.**
- A search of `src/` for `is_held(` / `.held` / `held[` returns only `record_file.gd`, the two
  controllers, `input_intent.gd:104`, `intent_recorder.gd:570` and `match_state.gd:1274/1350/4265`. Nothing
  under `src/actors/`, `src/main/` or `src/ui/` reads the key.
- `animation_controller.gd:328` `_CHARGE_HOLD_KNOBS` is keyed by colour and holds only
  `hold_start` / `hold_end` / `hold_fraction` progress fractions. `on_charge_progress` (`:578`) takes
  `(charge_color, progress)` and calls `charge_playhead_seconds`; it reads no intent.
- `progress` is computed in `match_runner._push_charge_progress` (`match_runner.gd:865-892`) from
  `AnimationController.charge_attack_progress(player.landing_window.remaining_ticks(), chargeup_ticks,
  launch_ticks)`: window progress only. It is gated on `action_state == CHARGING` (`:871`).
- Consequence: the `6-1b` re-tempo is driven purely by `charge_window` / `landing_window` progress and
  survives this story untouched. The only behavioural change is that the clip can no longer be cut short
  mid-window by input. The `_early_release_leaves_no_stale_frame` case
  (`test/integration/test_charge_playhead_live.gd:78`) pins that a push arriving after a
  CHARGING -> IDLE cut is a no-op; that cut is still reachable via landing, knockdown and reset, so the
  assertion is KEPT and only its name and comment are reworded.

If the dev pass measures anything that contradicts this, STOP and report; do not start re-tuning knobs.

### 4. Reverse blast radius from `6-1` (named deletion 4)

- `test/state/test_unblockable_defense.gd`: three fixtures were made to hold on `6-1`'s account and go back
  to bare: the mode 3 commit-tick refusal (`:208-213`), the mode 1 commit-tick refusal (`:1479-1481`) and the
  out-of-range slot refusal (`:1542-1544`). Also the `_holding()` helper (`:2420`) and the
  `_unblockable_intent` built on it, `_basic_intent`'s doc on `held` (`:2434-2437`) and `_cast_defense`'s
  `p1_intent` parameter and its `6-6b` REVIEW note (`:2457-2461`). Two tests whose comment reads "P1
  releases: the paid feint ends the chargeup" (`:1087`, `:1178`) assert a feint to reach a state where
  nothing is charging at the press; they are REWRITTEN to reach that state another way (run the attack to
  its landing, or do not cast). The dev pass chooses the mechanism; the claim each test proves stays.
- `test_orbs_economy.gd`: `_holding()` (`:509`) and its comment (`:505`).
- `test_unblockable_initiation.gd`: `_holding()` (`:709`) and its comment (`:705`).
- `test_unblockable_tracking_and_reach.gd`: `_holding()` (`:1071`), 40 uses, plus FOUR tests that assert
  release / feint behaviour: `test_after_the_commit_a_release_does_not_feint_and_input_does_not_steer` (`:133`),
  `test_a_release_on_the_commit_tick_itself_is_ignored` (`:160`),
  `test_a_release_before_the_commit_still_feints_and_clears_the_landing_window` (`:182`) and
  `test_the_contact_verdict_rests_at_unknown_outside_a_committed_flight` (`:589`). The first two keep
  a surviving claim ("no input steers the launch") and are REFRAMED without a release; the third asserts a
  feint and is DELETED. The fourth is a REWRITE, not a reword: its docblock (`:585-586`) names "Three
  readings", and its middle one ("after a FEINT -- the path that resolves no landing at all") executes a
  feint in its body (`:592-593`, `:599`, `:603` "sanity: feinted", `:604`, `:610`), which no input can
  produce after this story. **Ruling `6-9/R3`: the middle reading is re-reached through the KNOCKDOWN
  ABANDONMENT** (`match_state.gd:3776-3778`, `6-6a/R1`), NOT the debug reset. The knockdown is a real
  in-match path that ends a paid chargeup with no landing verdict, which is exactly the condition the
  reading tests; the debug reset is an operator tool and would make the claim untestable in play. The
  test's three-reading claim and its other two readings stay.
- `test_pitch_changed.gd:339`; `test_pitch_staging.gd:117-124` (comment names "6-1's early-release arm")
  and `:555`; the three integration files in Fact 2.
- `_basic_intent`'s `held` parameter also carries `block` in the defence fixtures; only the `card_cast`
  uses go.

### 5. Question (b): what clears the telegraph fact, and did any of it hang off release?

- The snapshot fact is DERIVED from the state, not stored: `player_state.gd:613-615`
  `"telegraph": [charge_color, charge_window.remaining_ticks()] if hero.action_state == CHARGING else
  [NO_TELEGRAPH_COLOR, 0]`. The `6-1c` key beside it (`landing_window.remaining_ticks()`) is ungated
  (`player_state.gd:617-630`).
- On a normal LANDING nothing writes `charge_color`: `_resolve_charge_landing` writes `IDLE` / `STUNNED`
  synchronously and the `CHARGING` gate hides the stale colour by construction.
- Explicit clears exist at: the release arm (`match_state.gd:1352-1354`, the ONE release-driven writer,
  DELETED), the knockdown abandonment (`:3776-3778`), the colour-counter teardown (`:3922-3924`) and
  `_reset_player` (`:4987-4992`). The three that remain are not release edges.
- So exactly one clear hung off the release edge. After this story the telegraph clears at the landing (the
  state gate) plus the three non-input abandonments, and never on input.

### 6. Question (c): every test that asserts feint behaviour or reads the held key

Searched `test/` for the words `feint`, `feintable` and `release` and for the held key `card_cast`
(`held[&"card_cast"]`, `is_held(&"card_cast")`, `["card_cast_held"]`), by content. The list below covers
every test this search found that asserts feint / release behaviour or reads the held key, plus the wording
sites it found; it does NOT cover a feint reached through a differently-named helper, so the AC 7 search
and the suite run remain the backstop. By what the dev pass does:

- **Delete** (asserts feint / release): `test_unblockable_hold.gd` (whole file, 38 matches, THIRTEEN tests,
  classified in the table below); `test_unblockable_tracking_and_reach.gd:182`;
  `test_controller.gd:169` `test_debug_key_holds_card_cast_after_release_for_the_debug_duration` (it is
  also the only reader of `BalanceConfig.unblockable_chargeup_seconds` in `test_controller.gd`, so the
  `load("res://data/balance/balance_config.tres")` goes with it; not a lost claim, AC 4's knob is pinned in
  the balance and initiation suites).
- **Retire outright** (named deletion 5, see Deviations for the path):
  `test/state/test_gamepad_controller.gd:581` `test_resolve_card_tick_reports_the_unblockable_confirm_as_held`.
  All four of its readings (`:587`, `:594`, `:602`, `:614`) are of the returned key `card_cast_held`, which
  AC 7 removes, so they become uncompilable, not merely vacuous; there is no live key to re-point at and
  re-pointing would be the `6-1b/F4` defect in its purest form. Its one non-held claim (`:605-607`, L3's own
  product `armed_slot` still clears the same tick it releases) is independently covered by
  `test_resolve_card_tick_clears_armed_slot_the_same_tick_cast_releases` (`test_gamepad_controller.gd:666`,
  assertion at `:676-677`), which this story does not touch. **Ruling `6-9/R6`.**
- **Re-point** (do NOT retire): `test_record_file.gd:848`
  `test_a_new_held_key_round_trips_without_any_serialization_edit` (fixture at `:852`, assertions
  `:859-864`) is re-pointed at the live held key **`&"run"`**. The mechanism it guards is alive: `held` is
  walked generically by key at both ends (`intent_recorder.gd:570-571`, `record_file.gd:604`, `:767`), which
  is the reasoning Fact 8's "Why 11 -> 12" paragraph stands on, so retiring its only guard would be
  backwards. Only the example key dies. Both halves survive: a present key survives as present
  (`:859-861`), and an ABSENT key comes back absent rather than invented as `true` (`:862-864`), the half
  that justifies hard refusal over a shim. `run` over `block`: it is the NEWEST held key (`6-7`, the v10 ->
  v11 silent-divergence bump this file's history strings already narrate, `:876-877`), so "precisely how a
  pre-`6-7` record reads under this build" stays literally true, and it avoids confusion with `block`, which
  AC 9 keeps in `_basic_intent`'s `held` parameter. The docblock `:830-847` is rewritten off `6-1` / v7 onto
  `6-7` / v11, and its dangling `6-1/R4` citation at `:839-844` (it names
  `test_holding_the_confirm_through_the_whole_chargeup_lands_as_before` and
  `test_a_one_tick_tap_is_the_same_paid_feint` in `test_unblockable_hold.gd`, both deleted here) is resolved
  in the same edit, onto Fact 8's "Why 11 -> 12" reasoning. **Ruling `6-9/R6`.**
- **Reword** (comment or name only, claim survives): `test_charge_playhead_live.gd:78`;
  `test_charge_playhead_mapping.gd:86` (a comment naming "unfeintable"); `test_determinism.gd:758` (a
  comment naming "the reset/feint clears"; the fixture never enters `CHARGING`); `test_honest_hit_geometry_live.gd:43`
  and `:224` (comments); `test_unblockable_defense.gd:1828` (the docblock above
  `test_knockdown_from_charging_abandons_the_chargeup_and_keeps_the_spend`, `:1830`, reading "the `6-1`
  feint teardown runs with the write"; the test is a SURVIVING abandonment proof); the fixture comments at
  every site in Fact 4; and in `test_unblockable_tracking_and_reach.gd` the file header `:9` ("no release
  feints"), `:126`, `:560`, `:566` (the test NAME `test_contact_during_the_feintable_chargeup_credits_nothing`;
  its claim, that contact during the chargeup window credits nothing, is still true and reachable),
  `:572`, `:577`, `:964`, `:971`.
- **Rewrite** (claim survives, the mechanism to reach the state changes): the two "P1 releases" sites in
  `test_unblockable_defense.gd` (`:1087`, `:1178`), the two reframed tracking tests above, and
  `test_unblockable_tracking_and_reach.gd:589` (through the knockdown abandonment, `6-9/R3`, Fact 4).

**Classification of `test/state/test_unblockable_hold.gd` (13 tests), done at the gate.** FEINT-ONLY: the
claim is about the release / feint mechanism and dies with it. SURVIVING: the claim stays true after this
story. The dev pass confirms each row by content and records the result.

| # | Test (`test_unblockable_hold.gd`) | Class | Home for any surviving claim |
|---|---|---|---|
| 1 | `:63` `test_holding_the_confirm_through_the_whole_chargeup_lands_as_before` | **SURVIVING** | A full chargeup lands on the authored tick for the authored damage and exits IDLE: `test_unblockable_initiation.gd:266` `test_the_chargeup_exits_on_the_exact_authored_tick` and `:358` `test_inside_reach_at_expiry_lands_the_authored_damage`. Becomes the DEFAULT case; restated by Task 3(a). |
| 2 | `:84` `test_a_release_on_the_landing_tick_itself_still_lands` | FEINT-ONLY | Residual "the landing tick lands": `test_unblockable_initiation.gd:266` and `test_unblockable_tracking_and_reach.gd:431` `test_with_a_zero_launch_the_landing_is_the_chargeup_close_edge_as_before`. |
| 3 | `:101` `test_releasing_after_the_chargeup_completed_changes_nothing` | FEINT-ONLY | Residual "no post-commit input touches the flight": `test_unblockable_tracking_and_reach.gd:133` (reframed, Fact 4) and Task 3(b). |
| 4 | `:121` `test_an_early_release_returns_the_hero_to_idle_on_the_release_tick` | FEINT-ONLY | Pure release timing. No residual. |
| 5 | `:138` `test_an_early_release_clears_the_telegraph_fact_in_all_three_parts` | FEINT-ONLY | Residual "the three-part teardown fires on the surviving abandonments": knockdown `test_unblockable_defense.gd:1830` `test_knockdown_from_charging_abandons_the_chargeup_and_keeps_the_spend`; counter `:448` `test_a_counter_tears_the_attack_down_against_a_positive_control`; reset / round-over `test_unblockable_initiation.gd:502` `test_a_chargeup_does_not_survive_the_round_over_freeze_and_the_reset`; also Task 3(d), (e). |
| 6 | `:157` `test_an_early_release_is_paid_the_card_and_the_stamina_stay_spent` | FEINT-ONLY | Residual "the cast's spend is never refunded on any path": `test_unblockable_initiation.gd:75` `test_the_cast_spends_stamina_discards_the_card_and_owes_a_replacement` and `test_unblockable_defense.gd:1830` (spend kept across the abandonment). |
| 7 | `:182` `test_a_feint_lands_nothing_even_though_the_enemy_was_in_reach_throughout` | FEINT-ONLY | Pure feint. No residual. |
| 8 | `:209` `test_a_feint_neither_consumes_nor_is_answered_by_an_armed_defense_window` | FEINT-ONLY | `6-1/R7` and `6-6b` AC 6, both superseded. Residual "an armed window self-expires unanswered and the card stays spent": `test_unblockable_defense.gd:373` `test_the_card_is_consumed_even_when_the_window_answers_nothing` and `:551` `test_a_counter_that_ran_out_before_the_commit_counters_nothing`. |
| 9 | `:241` `test_the_same_fixture_does_counter_a_chargeup_that_is_held_out` | **SURVIVING** | A chargeup run to its close IS countered by a matching colour: `test_unblockable_defense.gd:448`, `:482` `test_a_counter_knocks_the_attacker_down_and_only_the_attacker`, `:578` `test_the_whole_busy_span_counters_and_its_end_is_exact_on_both_slots`, `:794` `test_only_a_matching_colour_counters`. |
| 10 | `:268` `test_stamina_regen_resumes_on_the_release_tick_itself` | FEINT-ONLY | Suppression half: `test_unblockable_initiation.gd:335` `test_stamina_does_not_regenerate_while_charging`. Resume-on-exit half: no suite asserts it today; kept as a NEW claim in Task 3(f) (`6-9/R7`). |
| 11 | `:291` `test_a_one_tick_tap_is_the_same_paid_feint` | FEINT-ONLY | No residual. |
| 12 | `:315` `test_no_recovery_window_follows_a_feint` | FEINT-ONLY | Residual "the chargeup adds no recovery lockout" is now structural (the landing writes IDLE / STUNNED directly, `_resolve_charge_landing`); the root-while-charging half is `test_unblockable_initiation.gd:284` `test_the_hero_is_hard_rooted_for_the_whole_chargeup`. |
| 13 | `:347` `test_a_feint_frees_the_next_cast_while_the_charging_gate_stays_shut` | **SURVIVING** (second half) | The `5-6` / `6-1/R2` gate, a hero still CHARGING may not cast mode 2: `test_unblockable_initiation.gd:230` `test_mode_two_is_refused_while_already_charging`. The first half (a feint frees the next cast) is feint-only. |

Result: three SURVIVING claims (rows 1, 9, 13), all with a home; no surviving claim is homeless. Row 10's
resume half is a new claim, not a surviving one.
- **Add:** the click-to-commit tests in Tasks.
- `test_gamepad_controller.gd` release-wording matches at `:141`, `:160`, `:171`, `:413-505`, `:635-718`
  are about `Input.action_release` and L3 cast-mode exit (roll / attack suppression), NOT feint, and stay.

### 7. Named deletion 5, the pad chord fork

`6-1/R9` (decision-log `:9528`): the hold read B ALONE, never conjoined with L3. With no hold there is no
fork to pin. `unblockable_raw` is still read for the commit press edge; only `card_cast_held` and the
`intent.held[&"card_cast"]` write go. Arming, the commit chord and "L3 release clears `armed_slot`" are
unchanged (`test_gamepad_controller.gd:666`).

### 8. FORMAT_VERSION and its refusal (settled, precedent `6-1/R4`)

- `src/systems/record_file.gd:195` `const FORMAT_VERSION := 11`; the refusal is `record_file.gd:349-353`
  (`if version != FORMAT_VERSION: return _refused(...)`, naming both versions). It exists.
- Coverage: a generic unknown version (`test_a_record_whose_format_version_is_unknown_is_refused_with_a_reason`,
  `test_record_file.gd:458`) and per bump: v8 `:493`, v9 `:526`, v10 `test_a_v10_record_is_refused_with_a_reason`
  `:562` (`_rewrite_format_version(PRE_6_7_PATH, 10)`). No v11 case exists; this story adds it.
- TWO constant pins assert `FORMAT_VERSION == 11` (a repo-wide search of `test/` for `FORMAT_VERSION, 11`
  returns exactly these two, both in `test/state/test_record_file.gd`):
  1. `test_the_format_version_and_the_widened_contact_row_move_together` (`:175`, assertion at `:176`)
     with a long history string; it moves to 12 and the string gains a `6-9` paragraph.
  2. `test_the_contents_validation_bumped_no_version_and_widened_no_required_key` (`:871`, assertion at
     `:872`), with its own history string at `:873-878` ("the version has since moved to 11 (5-2's colours
     channel, 6-1's mode 2 hold semantics, 6-2's pitch-cost channel, 6-3a's `card_activate` intent field,
     then 6-7's silent-divergence bump for `run` / `walk_speed`)"); it also moves to 12 and its history
     string gains the `6-9` clause. Missing it breaks the suite on the bump (`6-9/R2`).
- No committed record fixture exists: a recursive search of `test/` for `*.json`, `*.rec`, `*.dat` and
  `*.bin` returns zero files, and every `.rec` path in the suite is a `user://` constant written and
  removed by the test that reads it, at the live `FORMAT_VERSION`. A hard v11 refusal therefore breaks no
  fixture; the only v11 assertions in `test/` are the two pins above.
- **Why 11 -> 12.** The shape forces nothing. The SEMANTICS do: a v11 record of a mode 2 cast whose
  `card_cast` held key goes false (a feint) was authored under an arm that no longer exists, so under this
  build it would replay as a full attack where it was recorded as a feint, loaded without complaint. Hard
  refusal, no shim.

## Golden Prediction

Predict **golden `d437432f` UNMOVED** (`test/state/test_determinism.gd:1043`, `d437432f7823379c8992276f4061ca16161b156fe2a8a7eb732d9b9750262d56`)
and the **snapshot key-path set unchanged at 206**, `UNHASHED_CROSS_TICK_MEMBERS` unchanged at 4.

Reason: the determinism fixture never enters `CHARGING` (`test_determinism.gd:699`, `:773`: no hero casts
mode 2, `charge_color` is never written; it casts only `ModeKind.BASIC`). The deleted `elif` arm is
unreachable from it, no snapshot key is added or removed, and `FORMAT_VERSION` is not part of the hashed
snapshot.

Measure in BOTH directions:
1. **Before:** on the clean tree at `690f162`, run the state harness and record the golden hash, the
   snapshot key-path count and the suite counts.
2. **After:** same run on the finished tree. Golden byte-equal, key count 206, suite counts changed only by
   the deliberate test adds and removes (stated with the delta).

Any movement is a **STOP and report**, never a re-baseline. The stop conditions, from the gate:
1. the golden hash differs at all between Task 0's before-run and Task 8's after-run;
2. the snapshot key-path count is anything but 206 in either run;
3. `UNHASHED_CROSS_TICK_MEMBERS` is anything but 4 in `test_replay_identity.gd`;
4. any value in `data/balance/balance_config.tres` is edited (`BC/R3` isolates authored balance for VALUES
   only; `SC/R6` says that protection does not extend to a change that adds a seat or makes a pressed
   action refusable; this story REMOVES a refusal path, so the golden stays put only while no `.tres` is
   touched);
5. the Task 1 comment rewrite moves a line the arm's behaviour depends on (`match_state.gd:1346-1349`
   must come out byte-identical).

## Tasks / Subtasks

- [ ] **Task 0: pre-edit baseline** (AC 14). `bash test/run_all.sh` (state, then integration, each
      foreground, `GODOT=/c/Godot/godot.exe`) on the clean tree; record suite counts, golden hash, key
      count. Back up every file to be edited to the scratchpad WITH SHA-256 before mutating anything;
      restore by copy-back, never `git checkout`.
- [ ] **Task 1: state arm** (AC 1, 2, 5, 6). Delete the `elif` release arm; rewrite its comment block;
      reword the stale comments in Fact 1, including `record_file.gd:165` so AC 7's search is clean. The
      surviving `if not player.landing_window.is_running: _resolve_charge_landing(player, slot)`
      (`match_state.gd:1348-1349`) and the counter-first `return` (`:1346-1347`) come out byte-identical.
- [ ] **Task 2: controllers** (AC 7, 10). Remove `card_cast_held` from `resolve_card_tick` and the
      `intent.held[&"card_cast"]` write in `GamepadController`; remove `DEBUG_HOLD_TICKS`,
      `_debug_hold_left`, the hold write and the docblock in `KeyboardController`.
- [ ] **Task 3: click-to-commit tests** (AC 1, 2, 3, 5), a new `test/state/test_click_to_commit.gd`:
      (a) bare intents from the commit tick land on the same tick, with identical hero HP, orb, stamina,
      card and `hit_landed` outcomes, as a run whose every post-commit intent holds every LIVE held key
      (`attack`, `block`, `roll`, `run`) and a full move vector; neither run sets `held[&"card_cast"]`
      (AC 1); (b) the seven-row input table of AC 2, rows 1-6 as stays and row 7 (`debug_reset`) as an
      exit; (c) card and stamina stay spent and a landing verdict is emitted exactly once; (d) telegraph
      reads `[-1, 0]` after landing; (e) the four remaining exits still work (landing, counter, knockdown,
      reset); (f) NEW claim, not a surviving one (`6-9/R7`): `_regen_stamina` reads `action_state` fresh at
      step 5 with no latch, so stamina regen resumes on the tick the hero leaves `CHARGING` by landing
      (the landing-tick form of the retired `test_stamina_regen_resumes_on_the_release_tick_itself`; no
      suite asserts it today, `test_unblockable_initiation.gd:335` covers only the suppression half).
      Non-vacuity: (a) and (b) must FAIL against HEAD's release arm (against HEAD the bare-intent run
      feints on the tick after the commit and the two runs diverge); that is the before-claim.
- [ ] **Task 4: retire and reverse** (AC 8, 9, 10). Confirm the Fact 6 classification, then delete
      `test_unblockable_hold.gd`; delete / reframe / rewrite the tests in Fact 6 (including the tracking test
      at `:589` through the knockdown abandonment); take every fixture in Fact 4 back to bare intents;
      remove the helpers; retire the `6-1` chord-fork test (`test_gamepad_controller.gd:581`) and the `6-D1`
      hold test; re-point `test_record_file.gd:848` at `&"run"` (`6-9/R6`); strip the three `is_held` lines
      inside the kept `test_controller.gd` tests.
- [ ] **Task 5: format** (AC 11). `FORMAT_VERSION := 12`, the `6-9` paragraph beside the `6-1` one, the
      `== 12` pin and history string, `test_a_v11_record_is_refused_with_a_reason` (new
      `PRE_6_9_PATH` beside `PRE_6_7_PATH`; copy the eight-line shape of
      `test_a_v10_record_is_refused_with_a_reason`, `test_record_file.gd:562`), and a v12 round-trip. BOTH
      constant pins move to 12: `test_record_file.gd:176` and `test_record_file.gd:872` (inside
      `test_the_contents_validation_bumped_no_version_and_widened_no_required_key`), and the `:872` test's
      history string (`:873-878`) gains the `6-9` clause.
- [ ] **Task 6: presentation check** (AC 12, 13). Re-measure question (a) on the finished tree;
      `git diff --stat` shows only comments under `src/actors/` and `src/main/`, and nothing under `6-6b`
      state.
- [ ] **Task 7: mutation proofs** (backup outside the repo, SHA-256, restore by copy-back): (M1) reinstate
      the release arm, the (a)/(b) tests fail; (M2) reinstate `card_cast_held` on the pad path, the pad
      suite fails; (M3) reinstate the debug hold, the debug tap test fails; (M4) `FORMAT_VERSION` back to
      11, the pins fail; (M5) drop the explicit `charge_color` clear at `_reset_player` or the knockdown
      site, the existing reset / abandonment tests fail (proves the kept clears are still live).
- [ ] **Task 8: full gate** (AC 14, 15). Full suite after; golden unmoved, key count 206; architecture
      invariants green; `project.godot` untouched.
- [ ] **Task 9: live smoke** (below), then the operator's verdict.

## Live Smoke (operator, solo)

Config `[0, 3]`: P1 keyboard, P2 pad. The `6-D1` keys X / V / B cast a red / blue / green unblockable from
P1 (P1's hand must hold the colour pressed). Refine as the build shows what is judgeable.

1. **A tap commits and lands.** One tap each of X, V and B: the chargeup plays, the attack launches and
   lands with the key long released. Repeat holding the key the whole time: identical result.
2. **No way to cancel after the press.** Try to abort mid-chargeup: release, mash attack / block / roll /
   movement / a second colour key. The hero stays committed to the landing every time. (Roll and block are
   refused mid-chargeup by the standing gates; note any that are not.)
3. **The chargeup clip plays through to the strike every time.** No cut to idle mid-window on any of the
   three colours; the `6-1b` re-tempo reads as before.
4. **Costs.** Card and stamina drop on the press as before; no refund on any path.
5. **Counter still works** (`6-6b`, no change intended): pad P2 answers with the matching colour and the
   attacker is knocked down; a wrong colour is not answered.
6. **Stale-record refusal.** Load a recorded v11 file: it is refused with a clear reason naming both
   versions and is not replayed. If no v11 file survives on disk, the headless pin
   `test_a_v11_record_is_refused_with_a_reason` is the evidence and this item is recorded as
   machine-pinned.
7. **Regression:** melee chain, roll, block and deflect, and pitch stage / activate all still behave.
8. **fps** steady through a chargeup and a landing.

The pad-side click (B in cast mode) gets one confirming press if a pad is on hand; the solo path is the
keyboard keys.

## Supersession bookkeeping (recorded now, EXECUTED AT CLOSE-OUT, not in this pass)

- **`6-6b` AC 6** ("Hold-to-charge and the paid feint (`6-1`) are UNTOUCHED: a feinted chargeup never
  reaches a judged tick ... the bait the counter presentation exists to make possible",
  `6-6b-color-counters.md:153-156`) becomes dead on delivery. The same reasoning also kills `6-6b` AC 10's
  "a paid feint baits a full counter" clause (`:206`), the R-S6 sentence "the feint bait (AC 6) is
  unchanged" (`:45`, `:288`) and the code comments quoting them (`match_state.gd:3791-3792`,
  `:3860-3864`, `animation_controller.gd:687`). All are marked SUPERSEDED in the decision-log at
  close-out, recorded forward. Closed, pushed story files are NEVER edited (`E5-R/R7`).
- **`6-1` and `6-1b` close-out entries** stay exactly as written; the supersession is a NEW decision-log
  entry.
- **`6-1` rulings:** `R1` (paid feint), `R6` (minimum observable feint), `R7` (a feint leaves the defence
  window), `R8` (the `card_cast` key), `R9` (L3 chord fork), `R11`, `R12` (pad disconnect reads as a
  release) and `R13` (same-tick release + recommit) are superseded; `R2` (`5-6` basic-while-charging
  gate), `R3` (1.0 s = 60 ticks) and `R4` / `R14` (the bump precedent) STAND.
- `epics.md` bullet for `6-9` is owed at the E6 close-out (already recorded on the board).

## Deviations from the skill and from the brief

1. `_bmad/custom/gds-create-story.toml` `on_complete` governs, as instructed: Status `authored`, board
   entry stays `backlog`, `baseline_commit` in frontmatter.
2. **The gamepad test path in the brief is wrong.** The brief names
   `test/controllers/test_gamepad_controller.gd`; no `test/controllers/` directory exists. The file is
   `test/state/test_gamepad_controller.gd`. The chord-fork test is
   `test_resolve_card_tick_reports_the_unblockable_confirm_as_held` (`:581`).
3. **`_basic_intent`'s `held` parameter cannot simply be removed;** it also carries `block` in the
   defence fixtures. Only the `card_cast` uses go (AC 9).
4. The skill's web-research step is inapplicable (no library added). No subagents, forks or parallel
   sessions were used; the skill's subagent guidance was not followed, per the single-session rule.
5. The brief asked for a "Golden Prediction" and a "Live Smoke" section the template lacks; both are added.
6. `test/state/test_unblockable_defense.gd` holds more `6-1` fixtures than the brief's "three" once the
   `_holding()` helper and `_cast_defense`'s `p1_intent` parameter are counted; the measured list is Fact 4.
7. **Nothing was executed in this pass.** No suite run, no golden measurement: the golden and the key count
   are cited from `test_determinism.gd:1043` and the `6-6b` / `6-D1` close-out records, not re-measured. The
   dev pass measures them (Task 0, Task 8).
8. The story numbers its rulings only through the AC list; it does not mint new `6-9/R#` decision-log
   ids. Those are assigned at close-out.
9. **Gate round 1 (2026-09-21).** The readiness gate returned NOT READY on five text defects (B1-B5); the
   operator's rulings are recorded in the decision-log session "6-9 readiness gate" as `6-9/R1`..`R9` and
   applied above. This supersedes deviation 8 for those nine ids only: they exist in the log now, and
   close-out mints any further ones. Two cautions for the dev pass: the keyboard press edge
   (`keyboard_controller.gd:150-151`) exists because "the edge is taken from the level (`_debug_prev`, the
   GamepadController shape) rather than `is_action_just_pressed`, so it is a property of successive
   samples, not of the engine frame"; do not write any other rationale into a comment. And `test_controller.gd:164-201`
   is listed under both producers and consumers in Fact 2 for convenience: it produces the key only
   indirectly, through `KeyboardController.sample()`, and its own lines are assertions.

## Docs Debt

- `epics.md` bullets for `6-9` / `6-10` (E6 close-out).
- `docs/project-context.md` and `docs/game-architecture.md` were searched for hold-to-charge, feint and the
  held key and carry none, so no edit is owed there.
- The GDD (`gdd.md:100`, `:110`, `:182`, `:415`) frames the unblockable as "real cash-in or feint?", "throw
  or feint a colour" and lists "hold-to-charge" under E6. That is design-intent wording the operator ruling
  now overtakes. Flagged for the operator; NOT edited here, since the GDD is the highest authority and
  design wording is Matko's.

## Project Context Rules (embedded)

- F1: exactly one `func _physics_process` in `src/`, in `match_runner.gd`.
- D3(a): `Input.*` only under `src/controllers/`. D3(b)/A2: no global RNG / `Time` / `OS` / `Engine` in
  `src/state/`.
- Authored balance is isolated from the golden and the unit suite (`BC/R3`); this story edits no `.tres`
  value.
- Docs and code never share a commit. Validation that proves something is committed as a test. Commit
  messages are pure ASCII via `git commit -F <tempfile outside the repo>`. PowerShell 5.1, no `&&`.
- Show the diff before staging; `git add` and `git commit` are separate; explicit paths only; never push
  until the operator confirms the log.
- Tier A: the golden clause is decisive; tier may be raised, never lowered.

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md `6-1/R1..R15` (`:9475-9561`), `6-6b` close-out "Deferred / next" (`:10850`), `E5-R/R7` (`:9208`)]
- [Source: docs/implementation-artifacts/6-1-hold-to-charge.md, 6-1b-chargeup-presentation.md, 6-6b-color-counters.md, 6-D1-solo-smoke-keys.md]
- [Source: src/state/match_state.gd:1345-1354, 3776-3778, 3922-3924, 4987-4992]
- [Source: src/controllers/gamepad_controller.gd:219, 489; src/controllers/keyboard_controller.gd:93-165]
- [Source: src/systems/record_file.gd:195, 349-353]
- [Source: src/main/match_runner.gd:865-892; src/actors/hero/animation_controller.gd:328, 578]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
