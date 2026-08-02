# Story 3.1: `MatchState` config object + mana balance set

Status: ready-for-dev

> **Scope note.** The E3 revisit gate has RUN (2026-07-31, decision-log Session 2026-07-31 — E3
> revisit gate (outcome), rulings E3-RG/R1..R12); this story was amended per that outcome in commit
> `10b96a1`. DP/R3 waived the separate external playtest that the original revisit banner demanded.
> This story then passed its OWN readiness gate (2.8) after the fixes recorded in this revision. The
> story's scope is REDUCED from the amended version per the Q1 ruling — the card/deck fields leave
> 3-1 and are added just-in-time by their consuming stories (see Dev Notes).

## Story

As a solo developer about to add card and economy fields,
I want `MatchState`'s five positional constructor floats replaced by one match-scoped params object plus
the injected `BalanceConfig`, and the mana set authored as one coherent trio,
so that the refactor happens while call sites are still few, and every tunable number is authored data
re-applied on `apply_balance()` rather than a constructor constant.

## Acceptance Criteria

1. **Seed out of the tunables (E3-RG/R9).** `MatchState`'s constructor no longer takes five positional
   floats; it takes a match-scoped params object (`MatchParams`, holding the seed) injected once at
   construction. `apply_balance()` never reads or re-applies the seed.
2. **The mana set (E3-RG/R1).** `BalanceConfig` gains `max_mana` (NEW) and `mana_regen_per_second`
   (NEW); `melee_hit_mana` is RE-AUTHORED — it is an EXISTING field (`balance_config.gd:69`, authored
   at `data/balance/balance_config.tres:25`) and must not be added a second time under any name.
   Authored values in `data/balance/balance_config.tres`: `max_mana = 10.0`, `melee_hit_mana = 1.0`,
   `mana_regen_per_second = 0.25`. Class defaults for the two new fields stay `0.0` per the standing
   convention (the `.tres` authors, the class does not).
3. **Single injection.** `BalanceConfig` is the single source of truth for `max_hp`, `move_speed`,
   `max_stamina`, and `max_mana`: the constructor no longer carries any of them, and the runner's four
   tunable constants — `_MAX_HP`, `_MOVE_SPEED`, `_MAX_STAMINA`, `_MAX_MANA` (`match_runner.gd:14-17`)
   — are DELETED. `_SEED` (`match_runner.gd:13`) survives ONLY as the runner-side source feeding
   `MatchParams`, with a comment saying so. `test/state/test_architecture_invariants.gd` stays green.
4. **Per-pool reload contract.** On `apply_balance()` mid-match, per pool:
   - **stamina** — `set_maximum` + `refill` (D9, unchanged;
     `test_stamina_economy.gd::test_mid_match_reload_refills_stamina_to_max` survives untouched);
   - **mana** — `set_maximum` ONLY; the current value is clamped to the new maximum and is NEVER
     refilled. Pinned by a NEW test that is mutation-proven to fail if a refill is added;
   - **hp** — current hp is preserved and clamped to the new maximum, never refilled, exactly as
     `HeroState.set_max_hp` ships today (`hero_state.gd:176-178`).
   In-flight timing windows survive a reload (existing test untouched). Match start yields full hp,
   full stamina, and empty mana. Because `set_max_hp` only re-clamps, this contract does NOT fall out
   of one uniform rule once the constructor stops seeding hp — an explicit FIRST-INJECTION
   initialization is required and is a named task below (mechanism is the dev pass's choice; the two
   outcomes above are the contract). The hot-reload path remains TEST-ONLY: DEBT B is untouched and no
   live mid-match reload trigger is introduced.
5. **Pre-injection contract.** A `MatchState` constructed without `apply_balance()` is inert AND
   stat-less: no stamina regen, no contact resolution, and no round end — `_check_resolution()`
   (`match_state.gd:679-685`) joins the `balance_ticks == null` gated family. The three inertness
   tests — `test_action_state.gd::test_null_balance_ticks_guard_actions_inert`,
   `test_stamina_economy.gd::test_no_regen_without_apply_balance`,
   `test_contact_resolution.gd::test_contacts_inert_without_apply_balance` — are re-anchored from
   fixed-value assertions (`100.0` / `30.0`, both constructor-supplied today) to "unchanged from
   construction" assertions, and each is mutation-proven to fail without the guard it pins.
6. **Test surface.** `E1_BALANCE_FIELDS` in `test/state/test_data_resources.gd` is extended with
   `max_mana` and `mana_regen_per_second`; the authoring audit in `test/state/test_balance_authoring.gd`
   is extended likewise; `test/state/test_determinism.gd` receives a fixture SIGNATURE update ONLY —
   `_golden_config()` authors `max_mana = 90.0` (the value of the current in-test `MAX_MANA` constant,
   `test_determinism.gd:106`) and the test's `.tres` isolation is preserved (it never loads the
   authored `.tres`).

## Tasks / Subtasks

- [ ] Add `MatchParams` (seed-holding, match-scoped); change `MatchState._init` to take it; update the
      one `src/` call site (`match_runner.gd:77`) and all 25 test call sites across 13 files (AC: 1)
- [ ] `BalanceConfig`: add `max_mana` + `mana_regen_per_second` under the Mana group; re-author
      `melee_hit_mana` (existing field — no duplicate); author `10.0` / `1.0` / `0.25` in
      `data/balance/balance_config.tres`; update the "NO max_mana here" comment
      (`balance_config.gd:68`), which this story falsifies (AC: 2)
- [ ] Delete `_MAX_HP` / `_MOVE_SPEED` / `_MAX_STAMINA` / `_MAX_MANA` from `match_runner.gd`; keep
      `_SEED` with a comment naming it the `MatchParams` source; re-run the invariant suite (AC: 3)
- [ ] `_apply_balance_to_player`: add `player.mana.set_maximum(config.max_mana)` — set_maximum ONLY, no
      refill; add the first-injection hp/stamina/mana initialization that AC4's match-start outcome
      requires; new mutation-proven mana no-refill test (AC: 4)
- [ ] Gate `_check_resolution()` on `balance_ticks != null`; re-anchor the three inertness tests to
      "unchanged from construction" and mutation-prove each (AC: 5)
- [ ] Extend `E1_BALANCE_FIELDS` and the authoring audit; add `max_mana = 90.0` to `_golden_config()`;
      update `test_determinism.gd`'s `MatchState.new` call site (AC: 6)

## Dev Notes

- This refactor is explicitly scheduled for E3, while call sites are few; retrofitting after many callers exist is the failure mode. [Source: docs/game-architecture.md#Planned (E3) — MatchState config object]
- Reuses the 1.1 single conversion boundary and X3 re-injection pattern. [Source: stories-manual-e1.md#E1.S1; docs/game-architecture.md#Novel Pattern 2]
- **The constructor/`apply_balance` double injection.** Today `MatchState._init` sets `move_speed`/`max_stamina` (among others) from the five positional floats, and `apply_balance()` sets the SAME two fields again from the injected `BalanceConfig` (`_apply_balance_to_player`, `match_state.gd:670-676`) plus refills stamina to the new max (D9). Folding the constructor floats into the config object does not remove this double write by itself: AC3 names which injection survives — `BalanceConfig` — so there is exactly one write path per field, not two that happen to agree at match start. [Source: decision-log.md E3-RG/R9; match_state.gd:670-676]
- **The seed does NOT go into `BalanceConfig` or any hot-reloadable resource (decision-log E3-RG/R9, locked).** It lives in a separate match-scoped params object, injected once at construction, never re-applied by `apply_balance()` — a reload that re-seeds the RNG mid-match is a determinism hole. Do not fold `seed` into the same config object `apply_balance()` consumes, even though the "Planned (E3)" architecture note names it alongside the other four constructor floats. [Source: decision-log.md E3-RG/R9; match_state.gd:59,92-93,175-179; game-architecture.md#Planned (E3) — MatchState config object]
- **`ManaPool` vs `StaminaPool` refill-on-reload reconciliation.** Verified by content: `_apply_balance_to_player` calls `player.stamina.set_maximum()` THEN `player.stamina.refill()` (full refill to the new max, the D9 ruling) on every `apply_balance()` — but makes no corresponding call on `player.mana` at all today, because `BalanceConfig` has no `max_mana` field yet. AC4 rules that asymmetry explicitly: mana gets `set_maximum` and NOTHING else. A reload-refill would hand a free full bar mid-match and break the flywheel P2 depends on — `ManaPool`'s own doc comment states "Mana starts empty and is built by the flywheel" (`mana_pool.gd:4-5`). The two pools are not symmetric and must not be made so by accident. [Source: decision-log.md E3-RG/R1; match_state.gd:670-676; mana_pool.gd:4-5,44-47]
- **The basic-attack stamina cost is NOT this story's seat.** OPEN decision (d) is RESOLVED (DP/R2 — YES, the basic attack costs stamina), and E3-RG/R2 assigned the value plus implementation to a STANDALONE corrective pass that landed BEFORE this story (`attack_stamina_cost = 12.0`, decision-log Session 2026-08-01), precisely so its certain golden re-baseline carried exactly one named cause. This story consumes that state; it does not create it. [Source: decision-log.md E3-RG/R2; epics.md:96-99]

### Readiness-gate findings and rulings (2026-08-02)

- **Q1 ruling — SCOPE STRIP.** `hand_size`, `deck_size`, `draw_replacement_delay_seconds`,
  `reshuffle_vulnerable_window_seconds`, and `default_copies_per_card` are REMOVED from 3-1. Each is
  added just-in-time by its consuming story (3-2 / 3-3), which is where its value can be authored
  against something real. Two riders: `reshuffle_vulnerable_window_seconds` additionally PRICES OPEN
  decision (b), which is undecided — it is not authored anywhere until (b) is ruled; and
  `default_copies_per_card` is likely per-card data rather than a `BalanceConfig` field, which 3-2
  judges. Consequence for AC2: this story adds exactly TWO new fields, neither of them `*_seconds`, so
  no new tick conversion lands here at all.
- **The verified hp finding behind AC4.** Read this session, by content: `HeroState._init(queue, max_hp,
  move_speed_value)` sets BOTH `_max_hp` and `_hp = max_hp` — so "match start = full hp" comes from the
  CONSTRUCTOR today, not from `apply_balance()`. `set_max_hp(maximum)` (`hero_state.gd:176-178`) sets
  `_max_hp` and then calls `_set_hp(_hp)`, which CLAMPS the current value into `[0, new max]` and never
  raises it. One uniform `apply_balance` rule therefore CANNOT produce both required outcomes: once the
  constructor stops carrying `max_hp` (AC3), a stat-less pre-injection hero sits at `_hp = 0.0`, and
  `set_max_hp(100.0)` leaves it at `0.0` — a hero that starts the match dead. Hence AC4's explicit
  first-injection initialization task, and hence AC5's `_check_resolution()` guard: unguarded
  (`match_state.gd:679-685`, no `balance_ticks` check today) a 0-hp pre-injection hero would end the
  round on the first tick.
- **E3-RG/R1 criterion, recorded.** One round (~60-120 s of active play) funds ~2-4
  buildup->bluff->payoff cycles at card costs 3 (Imp Summoner, Basic) and 5 (Hellburst, Pitch).
  Arithmetic for the authored set: passive `0.25`/s is ~22 mana over 90 s; melee income (`1.0` per
  confirmed hit) adds the rest; that funds 3-5 cycles at 6-10 mana per cycle — slightly hot, inside the
  criterion, and cheaply retunable later as a `chore(balance)` edit that cannot move the golden.
- **BC/R2 reconciliation, recorded.** The melee damage halving (`attack_damage_percent_of_max_hp`
  6.0 -> 3.0) left `melee_hit_mana` at `8.0`, which DOUBLED mana earned per point of damage
  (8/6 ~= 1.33 -> 8/3 ~= 2.67). The new set re-bases both together: `1.0` mana per confirmed hit at
  damage 3 (~0.33 per hit-point), i.e. 10% of the 10-mana bar per hit. The shipped `80` cap and `8.0`
  per-hit value are PLACEHOLDERS REPLACED by this story, not values to carry across.
- **N7 — the derived per-tick seat belongs to 3-4.** This story authors `mana_regen_per_second` as an
  AUTHORING-UNIT field ONLY. The derived `mana_regen_per_tick` seat on `BalanceTicks` and the
  corresponding seat in the `advance()` ladder belong to story 3-4 (E3-RG/R8). NO `BalanceTicks` field
  lands here, and nothing consumes `mana_regen_per_second` until 3-4.
- **N1 — honest sizing.** `MatchState.new` has ONE `src/` call site (`match_runner.gd:77`) and 25 test
  call sites across 13 files (`test_action_state.gd` 2, `test_balance_config.gd` 1,
  `test_block_deflect.gd` 1, `test_camera_basis.gd` 1, `test/state/test_contact_pipeline.gd` 1,
  `test_contact_resolution.gd` 2, `test_debug_window_countdown.gd` 1, `test_determinism.gd` 1,
  `test_gamepad_controller.gd` 1, `test_match_state.gd` 8, `test_null_controller.gd` 1,
  `test_roll_iframes.gd` 1, `test_stamina_economy.gd` 4 — grep-verified this session). The signature
  change touches every one of them. `test_architecture_invariants.gd` also contains the STRING
  `"MatchState.new"` in its cues-layer banned-token list (`:114`) — that is a token, not a call site,
  and must not be edited.
- **N3 correction.** The `epics.md` decision-(d) staleness a previous revision of these notes described
  was SWEPT in the E3 revisit-gate amendment commit `10b96a1`: `epics.md:96-99` now reads correctly
  (decision (d) RESOLVED at DP/R2; the value and its golden re-baseline explicitly NOT a 3-1 seat). The
  stamina-cost disclaimer above stands, with that corrected evidence.

### Project Structure Notes

- `src/state/match_state.gd` constructor + `_apply_balance_to_player`; new `MatchParams` alongside the
  state layer's other pure data objects; schema in `src/state/resources/balance_config.gd`; authored
  values in `data/balance/balance_config.tres`; `ManaPool` re-inject via `set_maximum`
  (`src/state/pools/mana_pool.gd:44-47`).

### Project Context Rules

- **State receives schema by injection, never reads a `*Service`.** [Source: docs/project-context.md#Autoloads; docs/game-architecture.md#Novel Pattern 2]
- **Zero hardcoded numbers; hot-reloadable balance.** [Source: docs/project-context.md#Data as Resources]

### References

- [Source: stories-manual-e3.md#E3.S1]
- [Source: docs/game-architecture.md#Planned (E3) — MatchState config object]
- [Source: decision-log.md Session 2026-07-31 — E3 revisit gate (outcome), E3-RG/R1, R2, R8, R9]
- [Source: decision-log.md Session 2026-08-02 — Story 3-1 readiness gate]

## Golden Prediction

**Baseline going in:** `96ac5f6467ee8de5866391b1886c112794b89ee24f0ed56e6a5597bb6a5d966b`
(`test_determinism.gd:100`, current). The `33817201…` baseline this section previously named predates
TWO re-baselines (the stamina-cost corrective pass, then 3-0b Pass 2) and is dead text.

**Prediction: NONE** — conditional on two named things, both of which are MEASURED, not assumed:

1. **`_golden_config()` authors `max_mana = 90.0` exactly.** Any other value moves the hash, because
   `ManaPool.to_snapshot()` emits `{current, maximum}` (`mana_pool.gd:50-51`) and `90.0` is what the
   fixture's current `MAX_MANA` constant (`test_determinism.gd:106`) feeds through the constructor
   today. This is a fixture SIGNATURE move, not a value change.
2. **The double-injection reconciliation changes no value the golden run receives.** Before
   implementing, do a FIELD-BY-FIELD diff of the golden's constructor constants (`SEED`, `MAX_HP`,
   `MOVE_SPEED`, `MAX_STAMINA`, `MAX_MANA`) against `_golden_config()`'s corresponding authored values.
   Expected a no-op — measured, not assumed.

A third candidate cause — a mana refill on `apply_balance()` — is ELIMINATED by AC4's never-refill
ruling; if the golden moves and a refill is the reason, the implementation has violated AC4.

The fixture edit at `test_determinism.gd`'s `MatchState.new` call site (`:394`) is FORCED by AC1
regardless of the hash.

**Discipline:** measure in both directions; any movement = STOP, isolate, report — never a silent
re-baseline (the 1-5 cause-(c) lesson). The authored `.tres` values (`10.0` / `1.0` / `0.25`) CANNOT
move the golden: `_golden_config()` builds its fixture in-test and never loads
`data/balance/balance_config.tres` — proven at BC/R3 and re-confirmed by SC/R6 and the 3-0b gate.

## Live Smoke

**NOT REQUIRED.** This story touches only `src/state/` (the constructor/config refactor + the per-pool
reload contract), `src/state/resources/balance_config.gd` (two new fields), `data/balance/balance_config.tres`
(three authored values), and `src/main/match_runner.gd` (constant deletion). It adds no actor,
controller, or presentation code and consumes no observation seam.

- **R-D6 does not attach.** 3-1 ships no player-facing code path, so the two-human live-smoke
  acceptance is not invoked here; it stays AVAILABLE (last spent at 3-0a/R15) for the next story that
  ships player-facing behaviour.
- **Observability note.** The mana rescale keeps per-hit bar fill IDENTICAL — 8/80 == 1/10 == 10% of
  the bar — and the passive regen value has no consumer until 3-4. Nothing visibly changes until 3-4,
  whose smoke IS required and is the first live observation of the new scale.
- If the dev pass finds this untrue — e.g. a call site the story missed touches presentation — that is
  a scope finding for `decision-log.md`, not a reason to skip a smoke silently.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5

### Debug Log References

### Completion Notes List

- Readiness-gate fix pass (2026-08-02): the rulings applied in this revision were provided by the
  operator at this story's readiness gate; this pass rewrote the file around them.

### File List

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-31 | 0.2 | E3 revisit-gate amendment (commit `10b96a1`): duplicate mana-per-hit AC field renamed to the shipped `melee_hit_mana`; constructor/`apply_balance` double injection named; seed ruled out of the hot-reloadable config; `ManaPool`/`StaminaPool` reload-refill asymmetry flagged; hot-reload AC corrected to the test-only path it is; stale stamina-cost seat dropped; Golden Prediction and Live Smoke sections added. Status stayed backlog pending this story's own readiness gate. | Claude Opus 4.8 |
| 2026-08-02 | 0.3 | Readiness-gate fix pass (2.8, NOT READY on first read -> fixed -> promoted, same session). Scope REDUCED per the Q1 ruling: the five card/deck fields leave 3-1 for 3-2/3-3, so the story adds exactly two new `BalanceConfig` fields and no tick conversion. AC set replaced with six verifiable ACs (seed into `MatchParams`; the mana set 10.0/1.0/0.25 with `melee_hit_mana` re-authored not duplicated; single injection + runner constant deletion; per-pool reload contract; pre-injection stat-less contract incl. the `_check_resolution` guard; test-surface extension). Golden Prediction replaced wholesale — baseline corrected from the two-re-baselines-stale `33817201…` to `96ac5f64…`, prediction NONE conditional on `max_mana = 90.0` in `_golden_config()` and a measured no-op double-injection diff. Stale citations corrected to current anchors (`_apply_balance_to_player` `match_state.gd:670-676`; `melee_hit_mana` `balance_config.gd:69` / `.tres:25`). Dev Notes appended with the Q1 ruling, the verified `set_max_hp` clamp-only finding behind AC4, the E3-RG/R1 funding arithmetic, the BC/R2 reconciliation, N7 (no `BalanceTicks` seat here), N1 sizing (1 src + 25 test call sites across 13 files), and the N3 correction. Live Smoke kept NOT REQUIRED with the R-D6 and 8/80 == 1/10 notes added. Status backlog -> ready-for-dev; `sprint-status.yaml` flipped alongside. | Claude Opus 4.8 |
