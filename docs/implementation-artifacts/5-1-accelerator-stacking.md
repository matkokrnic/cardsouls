---
baseline_commit: 70af8e247a437c0e20c7ad9d3c879c4f3aae102b
---

# Story 5.1: Accelerator stacking

Status: ready-for-dev

## What this story inherits

`E5-P/R5` (decision-log Session 2026-09-01 "E5 planning",
`docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8176-8203`) ratifies this as
the FIFTH of twelve E5 stories, Tier A, quoted verbatim:

> `5-1-accelerator-stacking` -- Tier A (both seats per `E5-P/R3`; carries `4-4` M2 and M7 as
> authoring-audit bounds; changes shipped behaviour and moves the golden, so it runs first of the
> Tier A stories, before any unblockable work, per the `4-6` re-baseline discipline of isolating one
> measured cause at a time).

`E5-P/R3` (`decision-log.md:8159-8164`), the ruling this story was authored to unblock:

> `R-M9` MANA SEAT RESOLVED: Reading A -- each mana accelerator pays its own grant per cadence tick
> (two identical totems grant twice per tick); linear, player-countable, matching "each totem
> contributes its own effect where it sits." Reading B (compounding cadence) is rejected as
> superlinear and not what a player reading the board would expect. The stamina seat stays literal
> `mult^N`, as already ruled by `R-M9` itself (`deferred-work.md:209-213`). Unblocks
> `5-1-accelerator-stacking`.

The original `R-M9` (`deferred-work.md:209-213`, operator ruling 2026-09-01, recorded at E4
close-out): "accelerators STACK. Each accelerator totem contributes its own multiplier where it
sits; two identical totems apply two multipliers, multiplicative. This changes shipped behaviour.
Design ruling only; implementation touches the golden path, so it is Tier A -- slot assigned at E5
planning." Filed against `4-4` M9 (`_44-review.md:444`): "Accelerators do not stack; the second
identical totem silently does nothing."

`E5-P/R6` (`decision-log.md:8211-8213`) assigns the two authoring-audit findings this story also
carries:

> `4-4` M2, M7 -> `5-1-accelerator-stacking`, as authoring-audit bounds in
> `test_balance_authoring.gd` (same file, same pass that re-derives that line for stacking).

`deferred-work.md:228,233` (verbatim, `4-4` review residue table):

> | M2 | `_44-review.md:330` | `stamina_accelerator_regen_multiplier` defaults to 0.0, so an
> unauthored config inverts AC 21 | `5-1-accelerator-stacking` (`E5-P/R6`) |
> | M7 | `_44-review.md:416` | Zero or negative derived projectile speed makes a shot immortal |
> `5-1-accelerator-stacking` (`E5-P/R6`) |

### `5-1/R1` (Matko's ruling, recorded here, supersedes `E5-P/R3`'s stamina clause)

`E5-P/R3` kept the stamina seat at literal `mult^N` ("as already ruled by `R-M9` itself"). Matko has
now ruled that reading superseded for THIS story, by content:

> Accelerators stack LINEARLY, both kinds. Mana half keeps Reading A unchanged (already linear --
> each totem pays its own portion per cadence); `5-1` only removes the bool gate that currently
> makes a second identical mana totem do nothing. Stamina seat changes from
> `baseline x mult^N` to `baseline x (1 + N x step)`, where `step` is an authored value derived so
> that ONE totem is exactly identical to today's shipped behaviour -- the first totem must not
> change balance; only the second and third do. Rationale: readability (the player counts totems,
> not exponents), balance (`mult^N` explodes at the third totem), symmetry with mana.

This is `5-1/R1`. It is the AUTHORITATIVE stamina-seat ruling for this story; every stamina AC below
is written against it, not against `E5-P/R3`'s literal-`mult^N` text or the original `R-M9` text.

### Non-goal, ruled explicitly (no stacking cap)

Matko has also ruled there is NO mechanical stacking cap: N is bounded only by the deck's
`max_copies` cap and by totems being killable. This is stated as an explicit non-goal below so the
readiness gate does not invent a cap that was never asked for. `max_copies = 2` on
`data/cards/tidal_wardstone.tres` (mana accelerator) and `data/cards/verdant_wardstone.tres`
(stamina accelerator) is a PROVISIONAL fixture value from the `3-2` card-data pass, not a design
ruling this story makes or relies on.

### Non-goal, ruled explicitly (no new presentation)

Indirect visibility via bar behaviour (mana/stamina climbing faster with more totems alive) is
sufficient for this story. An explicit stacking indicator (e.g. "x3" on a totem, a HUD counter) is
playtest-block territory and out of scope here.

## Story

As a player,
I want each of my own accelerator totems -- mana or stamina -- to contribute its own share when I
have more than one of the same kind on my board,
so that summoning a second or third accelerator visibly and proportionally compounds my resource
advantage instead of the second copy silently doing nothing.

## Acceptance Criteria

**Counting (shared by both seats)**

1. A player's accelerator count for a kind, `N`, is the number of that player's OWN LIVE units of
   that exact kind (`mana_accelerator` or `stamina_accelerator`) on their OWN board --
   `player.units.is_alive_at(i) and player.units.kind_index_at(i) == kind_index`, the same liveness
   test `has_live_kind` already uses (`match_state.gd:1892-1900`), generalised from a bool to a
   count. Liveness is `UnitBoard.is_alive_at`, never a re-derived `hp > 0`, per `4-3a/R14` (inherited,
   not re-stated). The counting sibling MUST preserve the kind-lookup early-out `has_live_kind`
   already has (`5-1/R5`, readiness-gate finding F4): `balance.kind_index_of(kind_name) ==
   BalanceConfig.NO_KIND_INDEX` yields `N = 0` immediately, without scanning the board -- an
   unauthored kind name degrades to zero the same way `has_live_kind` degrades to `false`, per the
   PUBLIC, PURE-QUERY, PER-OWNER discipline `has_live_kind`'s own header documents (see Dev Notes).
2. Counting is PER-OWNER: an opponent's totems of the same kind never enter a player's own `N`, for
   either seat. Proven in BOTH directions in the same test run (owner accelerated proportionally to
   their own count; the opponent's own count, and therefore their own regen, is unaffected by the
   owner's totems) -- the same discipline `test_the_accelerator_is_owner_only` and
   `test_a_live_stamina_accelerator_raises_only_its_owners_regen` already apply to the N=1 case,
   extended to N>1.
3. Counting is PER-KIND: a live `stamina_accelerator` totem never enters a player's mana `N` and vice
   versa; a `combat_totem` or a `minion` enters neither. (This is the existing
   `test_a_minion_is_not_an_accelerator` guarantee, extended to the counted form.)
4. **Non-goal, stated as a guarantee this story does NOT add:** no stacking cap of any kind (no
   authored maximum-N field, no code-level clamp on `N`, no per-kind ceiling) is introduced anywhere
   in `src/`. `N` is bounded only by the deck's `max_copies` cap (currently 2 for both accelerator
   cards) and by each totem being killable — both facts that already exist outside this story and
   need no new code to hold.

**Mana seat (Reading A -- the bool gate removed, arithmetic already linear)**

5. `_generate_mana`'s third rung (`match_state.gd:1818-1825`) multiplies the authored per-cadence
   accelerator amount (`EconomyEvaluator.amount_for(..., SOURCE_MANA_ACCELERATOR, ...)`) by the
   player's own live `mana_accelerator` count `N`, replacing today's `if has_live_kind(...):
   _regen_mana(player, accelerated)` bool gate. `N = 0` pays nothing (unchanged from today);
   `N = 1` pays exactly the authored amount once, per cadence tick (BYTE-IDENTICAL to today's
   shipped behaviour -- the one-totem case must not move); `N = 2` pays exactly twice the
   one-totem amount on the SAME cadence tick, `N = 3` exactly three times, and so on with no upper
   bound coded anywhere (AC 4).
6. The mana rung still routes through `_regen_mana` (never `mana.add()` directly), so the standing
   `2-3/R5` "a corpse runs no economy" doctrine and the `totems` flag gate on the authored rule both
   continue to hold for the stacked case exactly as they do for `N <= 1` today -- no new suppression
   or flag logic is needed or added.

**Stamina seat (`5-1/R1` -- literal `mult^N` replaced by a linear step)**

7. `_regen_stamina`'s accelerator factor (`match_state.gd:1868-1871`) changes from
   `per_tick *= balance.stamina_accelerator_regen_multiplier` (applied once, gated by a bool, on
   `has_live_kind`) to `per_tick *= (1 + N x step)`, where `N` is the player's own live
   `stamina_accelerator` count and `step` is `BalanceConfig.stamina_accelerator_regen_step`, a NEW
   field that REPLACES `stamina_accelerator_regen_multiplier` -- this is a REQUIREMENT of this AC,
   not a dev-pass option: `stamina_accelerator_regen_multiplier` is REMOVED entirely (not left as an
   unread sibling) from `src/state/resources/balance_config.gd`, `data/balance/balance_config.tres`,
   `test/state/test_data_resources.gd`'s `E1_BALANCE_FIELDS` list, and every fixture/assertion that
   names it (see Dev Notes and Touched-files). `step`'s class default is `0.0` (AC 9's identity-safe
   default) and its authored value is DERIVED so that `N = 1` reproduces today's shipped factor
   EXACTLY. Today's authored `stamina_accelerator_regen_multiplier` is `1.5`
   (`data/balance/balance_config.tres:116`), so the derived `step` must satisfy
   `1 + 1 x step = 1.5` -> `step = 0.5`; record this exact arithmetic in Completion Notes rather than
   re-deriving it silently. `N = 0` yields factor `1` (identity, no change from the non-accelerated
   rate); `N = 2` yields `1 + 2 x 0.5 = 2.0` (linear, NOT `1.5^2 = 2.25` -- the explosive `mult^N`
   reading `5-1/R1` explicitly rejects); `N = 3` yields `1 + 3 x 0.5 = 2.5`, and so on with no upper
   bound coded anywhere (AC 4).
8. The stamina rung still routes through the existing `_regen_stamina` suppression (BLOCKING and DEAD
   both still regenerate nothing, accelerated or not -- `test_the_accelerator_does_not_reopen_a_
   suppressed_regen`'s guarantee) and the factor still returns to `1` (identity) the tick every
   accelerator totem the player owns has died, with nothing to tear down -- unchanged mechanism,
   only the arithmetic inside it changes.

**M2 discharge (`4-4` review finding, `_44-review.md:330`)**

9. The CLASS DEFAULT of whichever `BalanceConfig` field carries the stamina step/factor (today:
   `stamina_accelerator_regen_multiplier`, defaulting to `0.0`) can no longer invert AC 21's original
   intent: with the field UNAUTHORED (a fresh `BalanceConfig.new()`, or a `.tres` load that never
   sets it), the derived factor at any `N` must equal `1` (identity -- no boost, never a penalty). A
   default of `0.0` under the OLD `per_tick *= multiplier` mechanism silently zeroed stamina regen
   for an owner with a live accelerator; under the new `1 + N x step` mechanism this requires `step`'s
   own class default to be `0.0` (so `1 + N x 0.0 = 1` regardless of `N`), which is the natural
   identity-safe default for an ADDITIVE step field, not the dangerous one a MULTIPLICATIVE field's
   `0.0` default was. Add or extend `test_balance_authoring.gd` (or a state-layer test, dev's call)
   to assert the CLASS DEFAULT -- not the authored `.tres` -- yields the identity factor, closing the
   gap M2 named rather than merely re-testing the already-audited authored value (the existing
   `test_authored_accelerator_values_are_derived_and_effective`, `test_balance_authoring.gd:613-640`,
   already audits the AUTHORED value `> 1.0`; that test stays but does not, by itself, discharge M2).

**M7 discharge or explicit re-defer (`4-4` review finding, `_44-review.md:416`)**

10. "Zero or negative derived projectile speed makes a shot immortal" is DISCHARGED-AS-ALREADY-CLOSED
    (`5-1/R3`, readiness-gate finding F7, independently audited and confirmed, not left to the dev
    pass to re-decide): under the bounds `test_authored_projectile_profile_is_playable` already
    audits (`launch_speed > 0`, `acceleration_per_second_squared >= 0`, `max_speed >= launch_speed`,
    `test_balance_authoring.gd:554-599`), every branch of `_speed_at_flight_ticks`
    (`match_state.gd:1090-1099`, `minf(max_speed, launch_speed + acceleration * seconds)`) returns
    `>= launch_speed > 0`; the only `0.0` return is the null-profile branch, which `_advance_
    projectiles` (`match_state.gd:1015-1031`) already consumes before ever calling the speed
    function. No real gap exists to close. The dev pass MUST add an explicit authoring-audit
    assertion in `test_balance_authoring.gd` that the Combat totem's derived projectile speed cannot
    reach zero or below across its authored curve -- as a NAMED REGRESSION GUARD, not a fix -- and
    MUST record the outcome in Completion Notes as exactly `DISCHARGED-AS-ALREADY-CLOSED`, not
    `DISCHARGED` (that word is reserved for a finding where a real gap existed and was closed, which
    is not what happened here). This finding does not silently disappear -- do not re-defer it
    without a stated reason, and none is anticipated.

**Golden and testing**

11. **Golden Prediction, RESOLVED (not merely a caveat) for BOTH named causes, `5-1/R4`
    (readiness-gate findings F8/F9):** see Dev Notes' "Golden Prediction" subsection for the full
    reasoning. `_golden_config` (`test_determinism.gd`) authors EXACTLY ONE unit kind, `&"minion"`
    (`test_determinism.gd:988`, `test/unit_kind_fixture.gd:71-75`) -- so `kind_index_of(&"mana_
    accelerator")` and `kind_index_of(&"stamina_accelerator")` both return `NO_KIND_INDEX`, and
    `has_live_kind` (its counting successor, AC 1) returns `false` / `0` for BOTH players on EVERY
    tick, AT THE KIND LOOKUP, before the board is ever scanned. `N` is identically `0` for both
    players on every tick of the recorded sequence, and no accelerator -- duplicate or single, of
    either kind -- can exist in this fixture. BOTH the mana bool-gate removal and the stamina
    linearization are therefore PREDICTED non-movers, for this reason specifically (not the weaker
    "its one summoned unit is a MINION kind" -- the gate closes at the kind lookup itself, not at a
    board scan that happens to find nothing). This is a prediction to CONFIRM BY MEASUREMENT, isolated
    in two separately-measured steps in this order: (a) mana bool-gate removal, measured first as an
    intermediate step; (b) stamina linearization, measured second as the final step. **This story
    performs NO golden re-baseline.** If either measurement surprises the prediction (moves the
    golden in either direction), the dev pass STOPS and reports rather than re-baselining -- do not
    force a match to the prediction, and do not re-baseline a surprise away. The two causes are not
    symmetric in how they reach this fixture: the stamina linearization's new `1 + N x step` code
    executes on EVERY tick for both players, at exact identity (`1 + 0 x step = 1`) -- the prediction
    is REACHED, not vacuous. The mana change is inert THREE TIMES OVER on this fixture: `N = 0`, AND
    `mana_accelerator_mana` / `mana_accelerator_interval_seconds` are unauthored in `_golden_config`
    (defaulting to `0.0`), AND `ManaPool.add(0.0)` early-returns before mutating or signalling.
    Stacking behaviour (`N > 1`) is covered by the new `test/state/test_totem_accelerators.gd` tests
    regardless of what the golden shows, since the golden's own fixture never reaches `N > 1` for
    either kind.
12. **Headless test coverage**, added to `test/state/test_totem_accelerators.gd` (the existing owner
    of this coverage, `test/state/test_totem_accelerators.gd:1-306`) and following its established
    fixture pattern (`_config()`, `_make_match()`, `ms.p1.units.add(hp, kind)` per totem,
    `_drain_to_boundary_eve()` for the mana cadence): at minimum, one test proving `N=2` mana pays
    exactly `2x` the `N=1` payout on the same cadence tick; one proving `N=3` mana pays exactly `3x`;
    one proving `N=2` stamina yields the `1 + 2 x step` factor (not `mult^2`); one proving per-owner
    isolation still holds at `N=2` (opponent's own count and regen are unaffected by the owner
    summoning a second totem); one proving killing one of two live totems drops `N` from 2 to 1 and
    the payout/factor returns to the `N=1` value (not to zero) -- the return-to-`N=1` case a
    return-to-zero test would not catch. Mutation-proven per the project's standing test-authoring
    discipline (no test committed that a targeted mutation does not fail).

## Non-Goals

- A mechanical stacking cap of any kind (AC 4) -- deferred entirely to the deck's `max_copies` and to
  totems being killable in combat. No new authored bound, no code-level clamp.
- A stacking presentation/indicator on the totem or in the HUD (e.g. an "x2"/"x3" readout, a stacked
  bar segment) -- indirect visibility via bar/regen behaviour is accepted as sufficient for this
  story; an explicit indicator is playtest-block territory.
- Combat totem multi-instance firing behaviour. Each Combat totem already fires on its OWN authored
  cadence via the per-unit attack-tick loop (`4-4/R8`'s per-record priority/attack authoring), not
  through the bool-gated `has_live_kind` seat this story rewrites -- two Combat totems already fire
  independently today and this story changes nothing about that path. Only the mana and stamina
  accelerator seats are in scope (`R-M9`, `E5-P/R3`, `5-1/R1`).
- `5-1a-intent-hardening`'s scope: `4-6` M3 (malformed retarget address hard-rejection) and `4-6`
  L7/L8 (v6-record robustness) are that story's own findings, not this one's, per `E5-P/R6`.
- Any change to `data/economy/mana_accelerator.tres`'s RULE (its `source`/`resource`/`amount_field`
  wiring) -- the rule still names one field, dereferenced once per call; the multiplication by `N`
  happens at the call site (`_generate_mana`), not inside `EconomyEvaluator` or the rule schema.

## Dev Notes

- **Golden Prediction (full reasoning for AC 11, resolved by `5-1/R4`).** `test_determinism.gd:988`
  authors `_golden_config`'s one summoned unit via `UnitKindFixture.minion_only(...)`
  (`test/unit_kind_fixture.gd:71-75`), which authors EXACTLY ONE kind, `&"minion"` -- not merely "a
  MINION kind among others" but the ONLY kind entry that exists in this fixture at all. `has_live_kind`
  (`match_state.gd:1892-1901`) calls `balance.kind_index_of(kind_name)` FIRST and returns `false`
  immediately on `NO_KIND_INDEX`, before the per-index board scan ever runs
  (`match_state.gd:1896-1901`). Since neither `&"mana_accelerator"` nor `&"stamina_accelerator"` is an
  authored kind in this fixture, `kind_index_of` returns `NO_KIND_INDEX` for both, and the gate closes
  at that lookup -- the board scan is never reached, not merely "reached and finds nothing." `N` is
  therefore identically `0` for both players on every tick of the recorded sequence, by construction,
  not by a fixture accident that happens not to summon one. `mana_accelerator_mana` /
  `mana_accelerator_interval_seconds` / `stamina_accelerator_regen_multiplier` (soon `stamina_
  accelerator_regen_step`, `5-1/R2`) are additionally all left UNAUTHORED in `_golden_config`
  (defaulting to `0.0`) because the fixture never needs them -- a second, independent reason the mana
  path is inert here even before `N` is considered. Neither this story's mana change (bool -> count,
  multiplied by `N`) nor its stamina change (bool-gated single multiplication -> `1 + N x step`)
  alters behaviour when `N` is always `0` in the fixture that produces the hash -- both changes are
  arithmetically inert at `N = 0` by construction (`0 x anything = 0` for mana, reinforced by `ManaPool.
  add(0.0)`'s early return; `1 + 0 x step = 1`, the identity, for stamina -- and the stamina identity
  path is the one actually EXECUTED every tick, not skipped by a gate, so this prediction is reached
  rather than vacuous). This is the SAME "isolated by construction" argument `4-4`'s own entries use
  repeatedly (e.g. `test_determinism.gd:131-145`'s projectile pass). **This is a RESOLVED prediction,
  not an open caveat -- but the dev pass still MEASURES it rather than skipping the run on the strength
  of the reasoning above, and performs NO golden re-baseline for this story:** run
  `bash test/run_all.sh` before any change, then again after the mana change alone (intermediate), then
  again after the stamina change on top (final), recording all three golden/assertion-count triples in
  the Dev Agent Record exactly as `4-4`'s three-pass re-baseline did it (`decision-log.md`, `4-4`
  close-out entries) and as this story's own `E5-P/R5` line originally intended ("isolating one
  measured cause at a time") -- though `5-1/R1`'s decision-log entry (Session 2026-09-03) records that
  `E5-P/R5`'s "moves the golden" premise for running `5-1` first is itself contradicted by this
  reasoning; the ordering stands, the golden-movement premise does not. If either measurement surprises
  this resolved prediction (moves the golden in either direction), the dev pass STOPS and reports
  rather than re-baselining -- a surprise here would mean the reasoning above is wrong somewhere, which
  is a finding to report plainly, not a re-baseline to perform.
- **Where the bool gate lives today.** `match_state.gd:1818-1825` (mana rung) and
  `match_state.gd:1868-1871` (stamina rung) both call the same public
  `has_live_kind(player, kind_name) -> bool` (`match_state.gd:1892-1900`). The natural implementation
  is a sibling counting function -- e.g. `live_kind_count(player, kind_name) -> int` -- built on the
  exact same loop (`for index in player.units.size(): if is_alive_at and kind_index_at == kind_index:
  ...`), with `has_live_kind` either kept as `live_kind_count(...) > 0` (a one-line forward, cheapest,
  preserves every existing caller and its tests unchanged) or retired if nothing else calls it after
  this story's edits -- confirmed by grep before deciding. This is an implementation choice, not a
  design one; either is acceptable as long as the PUBLIC, PURE-QUERY, PER-OWNER discipline
  `has_live_kind`'s own header documents (`match_state.gd:1874-1891`: no mutation, nothing retained,
  an unauthored kind name degrades to the empty answer rather than tripping a guard) is preserved by
  its replacement or wrapper.
- **The stamina field REPLACES its predecessor; this is fixed, not a dev-pass call (`5-1/R2`).**
  `stamina_accelerator_regen_multiplier` is RENAMED to `stamina_accelerator_regen_step` and its
  semantics change from a direct multiplier to the additive-step term in `1 + N x step` -- the old
  field name is REMOVED from the codebase, not left as an unread sibling. Update
  `data/balance/balance_config.tres:116` to carry the DERIVED authored value (`0.5`, not `1.5`) under
  the new field name, and update the field's doc comment (`balance_config.gd:237-252`) to describe
  the new `1 + N x step` semantics, the new class default (`0.0`, AC 9), and the `> 0` audit bound
  this implies (replacing the old `> 1.0` audit). `test_authored_accelerator_values_are_derived_and_
  effective` (`test_balance_authoring.gd:613-640`) needs its stamina assertion updated to the new
  field name and the `> 0` bound.
  **Before removing the old field, grep `stamina_accelerator_regen_multiplier` across the WHOLE
  repo** (not just the files this story names) -- including `test/state/test_determinism.gd`'s
  `_golden_config()`, which the readiness gate did not audit for this name. If the grep turns up any
  hit this story's Touched-files list does not already account for, STOP and report it in Completion
  Notes rather than silently patching it in; do not assume the named consumer set (Touched-files,
  below) is exhaustive just because the readiness gate checked it once.
- **`test_totem_accelerators.gd` already documents exactly this discipline for the `N=1` case** —
  read its header (`test/state/test_totem_accelerators.gd:1-26`) before writing new tests: balance is
  constructed IN-TEST (`BC/R3`), the RULE SET is not (authored `data/economy/*.tres` content is
  load-bearing for the mana path by `3-4/R6`), owner-only claims are tested in BOTH directions, and
  effects are tested as "while alive" (killed and measured to return), not "once summoned". Every new
  `N>1` test in this story should extend that same discipline rather than introduce a second one —
  in particular, the "kill one of two, `N` drops to 1, not to zero" test (AC 12) is the stacking
  analogue of the file's existing `test_the_faucet_closes_when_the_accelerator_dies` /
  `test_the_owners_regen_returns_to_normal_when_the_accelerator_dies` tests, and should sit beside
  them.
- **M2's actual defect, restated precisely.** Today, `_regen_stamina` does
  `per_tick *= balance.stamina_accelerator_regen_multiplier` ONLY inside the `if has_live_kind(...)`
  branch — so an unauthored `0.0` default only ever bites a player who genuinely has a live stamina
  accelerator, zeroing their regen instead of leaving it alone (inverting AC 21's intent: the totem
  should help, and at worst do nothing, never actively harm). Under the new `1 + N x step` mechanism
  the multiplication happens for EVERY player on every tick (not gated behind an `if`), so the
  identity-safe default matters even more directly — confirm `step`'s class default is `0.0` before
  considering AC 9 discharged, and prove it with a test that constructs a bare `BalanceConfig.new()`
  (no `.tres` load) with a live stamina accelerator on the board and asserts the regen rate is
  UNCHANGED from the non-accelerated rate, not zeroed.
- **Existing `test_totem_accelerators.gd` tests WILL need arithmetic updates, not just new
  additions.** The fixture's `STAMINA_FACTOR := 2.5` (`test_totem_accelerators.gd:38`) is assigned
  directly to `c.stamina_accelerator_regen_multiplier` (line 72) and consumed by
  `test_a_live_stamina_accelerator_raises_only_its_owners_regen`
  (`p1_before + 1.0 * STAMINA_FACTOR * 10.0`, line 229) under the OLD multiplicative formula. Once
  the seat changes to `1 + N x step`, this fixture and every stamina assertion built on it must be
  re-derived against the new formula (e.g. re-author the fixture constant as a `step` and recompute
  the expected values as `1.0 * (1 + 1 * step) * ticks`) — a rename-only pass that leaves the old
  multiplicative arithmetic in the assertions would leave these tests silently wrong (still
  compiling, still green only because the fixture constant was tuned to make the old and new formula
  coincide by accident, which must not be allowed to happen unnoticed). Confirm the derivation
  explicitly in Completion Notes rather than trusting the existing numbers still apply.
- **M7's investigation starting point.** `_speed_at_flight_ticks` (`match_state.gd:1090-1099`) is the
  ONE place the curve is evaluated; walk it against the four bounds
  `test_authored_projectile_profile_is_playable` already asserts (`test_balance_authoring.gd:582-599`)
  before concluding whether a gap remains. `_advance_projectiles` (`match_state.gd:1015-1031`)
  already consumes a null profile by consuming the projectile rather than calling the speed function
  at all (a kind whose `unit_kinds` entry was removed by an X3 reload, per the file's own header
  comment at `match_state.gd:1012-1014`) — that path is not M7's "immortal shot" scenario; M7 is
  about a shot whose profile RESOLVES but whose DERIVED speed is non-positive.

### Project Structure Notes

- No new `src/` file is required by this story's fixed decisions. Touched files: `src/state/
  match_state.gd` (the two call sites, AC 5/AC 7, plus the counting function, Dev Notes), `src/state/
  resources/balance_config.gd` (the stamina field RENAMED `stamina_accelerator_regen_multiplier` ->
  `stamina_accelerator_regen_step`, its default and doc comment, AC 7/AC 9), `data/balance/
  balance_config.tres` (the derived authored value under the new field name), `test/state/
  test_totem_accelerators.gd` + `test/state/test_balance_authoring.gd` (new/extended coverage, AC
  9/AC 10/AC 12), and `test/state/test_data_resources.gd` (the `E1_BALANCE_FIELDS` hand-maintained
  list, `:70-71`, REQUIRED to drop the old name and add the new one -- `5-1/R2`, readiness-gate
  finding F10). No new top-level folder; no scene file is touched (this story is entirely
  `src/state/` + `data/` + `test/`).

### Project Context Rules

- F1: exactly one `func _physics_process` in `src/`, in `match_runner.gd` — not implicated; this
  story adds no new per-frame loop, only changes arithmetic inside two existing `MatchState` methods
  already called from the existing step-5 dispatch.
- D3(a): `Input.*` only under `src/controllers/` — not implicated, no input surface touched.
- D3(b)/A2: no global RNG / `Time` / `OS` / `Engine` in `src/state/` — not implicated; both changed
  seats already read only from injected `balance` / `player.units`, and this story adds no new
  dependency.
- Docs and code never share a commit; commits are pure ASCII via `git commit -F <tempfile outside the
  repo>`; shell is PowerShell 5.1 (no `&&`); trailer `Co-Authored-By: Claude Opus 4.8
  <noreply@anthropic.com>`.
- Story tier: Tier A, per `E5-P/R5`'s own text ("changes shipped behaviour and moves the golden") —
  full gate + review + live smoke ritual, per `CLAUDE.md`'s "Story tiers". AC 11's before/after
  measurement is what actually determines whether the golden moved on THIS fixture (predicted
  UNMOVED, per the Golden Prediction reasoning above) — a Tier A story predicting an unmoved golden
  is not a contradiction; the tier is fixed by what the story changes (shipped behaviour, a code
  path in `src/state/`), not by whether this particular fixture happens to exercise it.

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8127-8249 —
  "Session 2026-09-01 -- E5 planning"] — `E5-P/R3`'s mana-seat ruling, `E5-P/R5`'s story
  order/tier ratification (fifth, Tier A), `E5-P/R6`'s M2/M7 assignment.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md:180-183] — `R-M9`'s epics
  summary and this story's own committed-obligation line.
- [Source: docs/implementation-artifacts/deferred-work.md:199-243] — the `4-4` review residue table
  (M2, M7, M9 verbatim) and the `R-M9` operator ruling text this story's mana/stamina ACs both cite.
- [Source: src/state/match_state.gd:1781-1900] — `_generate_mana` (mana rung, AC 5/AC 6),
  `_regen_stamina` (stamina rung, AC 7/AC 8), `has_live_kind` (the bool this story generalises to a
  count, AC 1).
- [Source: src/state/resources/balance_config.gd:207-252] — the `Totems` export group carrying
  `mana_accelerator_mana`, `mana_accelerator_interval_seconds`, and
  `stamina_accelerator_regen_multiplier`, including the existing `AUDITED > 1.0` doc comment AC 9
  supersedes.
- [Source: data/balance/balance_config.tres:106-116] — today's authored values (`mana_regen_per_second
  0.25`, `mana_accelerator_mana 0.5`, `mana_accelerator_interval_seconds 1.0`,
  `stamina_accelerator_regen_multiplier 1.5`), the source of AC 7's `step = 0.5` derivation.
- [Source: data/cards/tidal_wardstone.tres, data/cards/verdant_wardstone.tres] — both authored
  `max_copies = 2`, the provisional fixture value AC 4's non-goal names.
- [Source: test/state/test_totem_accelerators.gd] — the existing `N=1` coverage and fixture
  discipline this story's new `N>1` tests (AC 12) extend rather than duplicate.
- [Source: test/state/test_balance_authoring.gd:554-640] — the existing projectile-playability and
  accelerator-value audit tests this story extends (AC 9, AC 10).
- [Source: test/state/test_determinism.gd:90-232] — the `4-4` re-baseline entries (three passes, one
  per named cause) whose "PASS 3 OF 3 (the accelerator faucets)" entry is this story's Golden
  Prediction evidence (AC 11), and whose three-separately-measured-causes discipline AC 11 follows.
- [Source: CLAUDE.md — "Story tiers"] — the golden-clause tier discipline this story's Dev Notes
  tier justification follows.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

### Change Log

| Date | Change |
| --- | --- |
| 2026-09-03 | Story authored via `gds-create-story`. |
| 2026-09-03 | Readiness-gate fix pass (`5-1/R2`-`5-1/R5`): AC 7 makes the stamina field rename/replace a requirement, not a dev-pass option (`stamina_accelerator_regen_step`, `test_data_resources.gd` added to Touched-files); AC 10 fixes the M7 outcome word to `DISCHARGED-AS-ALREADY-CLOSED`; AC 11 and the Golden Prediction Dev Note resolve the golden caveat (kind-lookup gate closes before the board scan; no re-baseline, stop-and-report on a surprise); AC 1 gains the kind-lookup early-out. Promoted to `ready-for-dev`. `5-1/R1` (linear stacking) recorded in decision-log Session 2026-09-03, `epics.md:180-183` corrected to match. |
