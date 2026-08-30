---
baseline_commit: d5a83721e4a0a9762c63714df778beb0d6ca34ca
---

# Story 4.4: Totems

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to summon Combat, Mana Accelerator, and Stamina Accelerator totems that stand where I
place them, block movement, take damage and die, and — for the Combat totem — fire an avoidable
projectile at a real target in range,
so that a totem is a distinct board object with its own stakes, not a minion wearing a different
card name.

## Acceptance Criteria

**Differentiation and lifecycle**

1. The three existing totem fixture cards (`hellforge_totem` / `summon_combat_totem`,
   `tidal_wardstone` / `summon_mana_accelerator`, `verdant_wardstone` / `summon_stamina_accelerator`)
   each resolve to a distinct on-board kind at cast time — no longer uniform `summon_*` handling
   indistinguishable from a minion or from one another.
2. A totem has hp, takes damage, and dies through the same mechanism a minion already uses
   (hp on the unit record, damage application, death-as-`hp <= 0`, a stable board index whose hole
   is never recycled) — no second hp/damage/death mechanism is authored.
3. A totem blocks movement using the same `CharacterBody3D` + `Collision` (`CollisionShape3D`)
   pattern the existing unit actors use, plus the `Hurtbox` (`Area3D` + `HurtboxShape`) member
   needed to take damage through the shipped `hitbox.get_overlapping_areas()` path — no second
   collision or damage-detection pattern is authored. No totem kind authors a `Hitbox`: the Combat
   totem attacks only via its projectile (AC 14); the accelerators never attack.
4. A totem spawns using the existing hero-relative, rear-of-summoner placement rule (story 4-3e) —
   no second spawn rule is authored. This already covers totems (4-3e's own AC 1 says "minion or
   totem").
5. All three totem kinds — Combat, Mana Accelerator, and Stamina Accelerator — are authored with a
   movement speed of 0 and never leave their spawn position for as long as they are alive. Cites
   `gdd.md`'s "small, unimposing static structure (wardstone, not tower)" description, which names
   the Combat totem among the three subtypes this line describes.

**Per-kind data**

6. `unit_move_speed`, `unit_stop_distance`, `unit_max_hp`, and `unit_damage_per_hit` are authored
   per kind (at minimum: minion, Combat totem, Mana Accelerator totem, Stamina Accelerator totem)
   instead of as four shared `BalanceConfig` globals. Every kind's value for a field it does not
   use for anything (e.g. a static totem's damage-per-hit, since it makes no melee contact) is
   still authored and non-negative — no field is left undefined for a kind.
7. Each kind authors its targeting priority BY NAME — a reference to an existing
   `MinionPriority.priority_name` — alongside the per-kind data AC 6 introduces.
   `MatchState._update_unit_targets`'s hardcoded `TargetingService.PRIORITY_STANDARD` lookup
   becomes a per-kind read. The missing-name contract (`REASON_NO_PRIORITY_DATA`, never a silent
   substitution) and `hero_seeker`'s test-only status (no `src/` file may name it) carry forward
   unchanged. Spends the permission `4-2/R17`(c) granted and `4-3/R6` assigned here (`4-4/R8`).
8. The shipped Combat totem authors a NEW hero-preferring priority `.tres` — a third profile
   alongside `standard` and the test-only `hero_seeker`, not a reuse of either. Minions keep
   `&"standard"` unchanged, so the shipped verdict for minions is unmoved. Rationale (`4-4/R9`):
   projectile avoidance is designed for a target that can roll; a unit cannot.
9. Every kind's attack capability is authored as a LIST of attack records (length one is
   acceptable for this story), never a single flat attack. An attack record carries windup,
   active, recovery, range, and damage. Selecting among multiple entries in a list is explicitly
   out of scope (Non-Goals). ("Shape" is dropped from the record — see Dev Notes.)
10. The Combat totem's one attack record authors a range of 8 m and its own firing cadence as a
    number on that record.
11. `test/state/test_data_resources.gd`'s `E1_BALANCE_FIELDS` reflection list,
    `test/state/test_balance_authoring.gd`'s bespoke per-field bounds, and
    `test/state/test_balance_config.gd`'s `test_conversion_covers_every_seconds_field` are all
    updated to match the per-kind field set — named because the per-kind conversion reshapes
    fields all three audit as flat globals today, and per-kind durations must still cross the
    seconds-to-ticks boundary through the single named `BalanceTicks.from_config()` point.
12. The determinism golden (currently
    `4a089063a8b3eff2274c0ca300dafe80e4eb4d3970ada352ca432a7e39844bdf`) is re-baselined, with the
    per-kind data conversion named as its own measured cause, separate from any cause introduced
    by the projectile or the accelerator faucets.

**Combat totem: firing and targeting**

13. A live Combat totem acquires a target by its authored priority (AC 7/AC 8) and holds fire
    while the acquired target is beyond its authored 8 m firing range — a post-selection gate, not
    a distance-based candidate filter or a NEAREST selection mode (that stays deferred work). A
    target held beyond range is never fired upon regardless of how long it remains in that state.
14. On firing, the Combat totem's projectile is a distinct entity in the world (not an instant
    hit) that travels from the totem toward its target rather than resolving contact immediately.

**Projectile: homing, acceleration, and avoidance**

15. A live projectile homes on its target (its heading updates toward the target's current
    position over the course of its flight) according to an authored homing profile, and
    separately accelerates at some point during flight according to an authored acceleration
    profile. Both profiles are authored data; no code branch selects between different homing or
    acceleration behaviors by kind.
16. When a projectile's flight would produce a contact fact against a target whose i-frame window
    is open, the existing i-frame drop rung in the target's contact ladder (`match_state.gd`,
    story 1-9's `1-9/R1`) drops that fact exactly as it does today for a melee hit, and dropping
    it is also the event that ends that projectile's homing: from that tick onward the projectile
    keeps its last heading and travels in a straight line for the remainder of its flight,
    updating its heading toward no target ever again. If the projectile's target is a unit (a
    reachable case once a future kind authors a unit-preferring priority), the unit ladder has no
    i-frame, block, or deflect concept, so homing simply never ends short of contact or the 60 m
    travel budget.
17. A target merely leaving the projectile's flight path (without an i-frame window being open at
    the tick a contact fact would otherwise land) does not end homing — the projectile keeps
    steering toward that target's current position.
18. A projectile whose contact fact resolves as a block or a deflect is consumed on that contact —
    it does not continue flying past a blocked or deflected hit.
19. A projectile that never produces a contact fact against anything travels at most 60 m of
    total distance, after which it is removed from the world. This 60 m flight limit is a distinct
    authored number from the Combat totem's 8 m firing range and governs a different thing (total
    travel budget vs. whether the totem may fire at all).

**Accelerators**

20. While a Mana Accelerator totem is alive, it is a resource-generation source recognized by the
    existing `ResourceGenerationRule` / `EconomyEvaluator` seam (a new `data/economy/*.tres` with
    `source = &"mana_accelerator"`), producing mana on some authored cadence. Reaching this rule
    needs a third `EconomyEvaluator.amount_for` call site in `MatchState._generate_mana` (gated on
    a live accelerator, at an authored cadence) alongside the two existing hardcoded sites, plus a
    `BalanceConfig`/`BalanceTicks` field naming the amount's home — `ResourceGenerationRule`
    forbids a rule carrying its own number.
21. While a Stamina Accelerator totem is alive, the stamina regeneration rate of the summoning
    player's hero — and only that hero, not the opponent's — is raised above its non-accelerated
    value by an authored factor, and returns to the non-accelerated value once that totem is no
    longer alive. The mechanism (a per-player derived rate vs. a multiplier applied at the regen
    seat vs. something else) stays a dev-pass call within the `3-1/R2` per-pool reload contract.

## Non-Goals

- `spell_*` cards remain named no-ops (`CardEffectResolver.REASON_SPELL_NOT_YET_RESOLVED`); the
  hero does not cast or otherwise use the projectile mechanism built here. This story ships the
  projectile as infrastructure fired by the Combat totem only.
- Attack SELECTION from a kind's attack list is not built. Every kind's list carries exactly one
  entry for this story.
- The arena has no edge, and an entity that leaves its bounds falls off rather than being stopped
  or clamped. Pre-existing (named in 4-3e's close-out), not a defect of this story, not fixed here.
- A totem (like a minion) does not resolve the case of a standing summoner permanently occupying
  the space between its own freshly spawned unit and the opponent. Known, deferred (4-3e
  close-out).

## Dev Notes

- **Golden clause, not build weight.** This story is Tier A by `E4-P/R9` and the sprint board's own
  annotation: "Tier A (golden clause, not build weight — E4-P/R9)". The "totem clause" ratified at
  4-1's close-out states the unit record carries no type/kind field specifically so uniform
  `summon_*` treatment would not pre-commit this story's differentiation, and separately ratifies
  "4-4's second golden move" as its own Tier A reason. `CardEffectResolver`'s own header names this
  story: a whole-id table is where the totem/minion split lands; writing it earlier would have
  pre-committed that shape.
- **Baseline measured for this story (repo, before any change):** HEAD `d5a83721e4a0a9762c63714df778beb0d6ca34ca` == `origin/main`, clean tree. State suite `499 tests, 0 failed, 3895 assertions` (`bash test/run_all.sh`). Integration suite: 42 files, all `RESULT: PASS`. Determinism golden:
  `const GOLDEN := "4a089063a8b3eff2274c0ca300dafe80e4eb4d3970ada352ca432a7e39844bdf"`
  (`test/state/test_determinism.gd:458`), unmoved since story 4-3b and confirmed unmoved through
  4-3c/4-3c1/4-3d/4-3e per sprint-status.yaml's own close-out notes.
- **The four globals converting to per-kind data, and where read today:** `unit_move_speed` /
  `unit_stop_distance` together in `_approach_unit_actors` (`match_runner.gd`); `unit_max_hp` at
  `player.units.add(balance.unit_max_hp)` (cast-time spawn seat); `unit_damage_per_hit` at
  `target.units.apply_damage_at(index, balance.unit_damage_per_hit)` (unit half of the step-4
  contact ladder), both in `match_state.gd`. All four declared on `BalanceConfig`
  (`src/state/resources/balance_config.gd`), authored once in `data/balance/balance_config.tres`,
  shared by every unit today — `unit_board.gd`'s header ("NO PER-UNIT MAXIMUM, deliberately...
  because no unit differs from another yet") names 4-3/4-4 as the stories allowed to change it.
- **The per-kind conversion is wider than those four (B5 correction).** AC 9's attack record also
  moves seven further `BalanceConfig` globals (same file, same `.tres`) off their shared-global
  shape: `minion_attack_windup_seconds` / `_active_seconds` / `_recovery_seconds` (read in
  `match_state.gd`'s unit-phase advance and `begin_windup_at`, via their `BalanceTicks`
  counterparts), `minion_attack_reach_distance` (`match_runner.gd`'s `_gather_unit_facts`), and
  `minion_attack_windup/active/recovery_move_speed_multiplier` (`match_state.gd`'s unit phase
  multiplier). Decision-log: "minion attack durations remain GLOBAL -- per-kind conversion is
  `4-4`'s opening act." Per-kind durations still cross seconds-to-ticks through the single named
  conversion point, `BalanceTicks.from_config()` — no second boundary is authored (AC 11).
  `minion_retarget_interval_seconds` STAYS shared, by operator ruling: no kind needs its own cadence yet; converts later when one does.
- **Tests measured as pinning these globals today** (constructing a `BalanceConfig` fixture, per
  the standing `BC/R3` isolation): only `test_data_resources.gd` (`E1_BALANCE_FIELDS` reflection
  guard), `test_balance_authoring.gd` (bespoke bounds), and `test_balance_config.gd`
  (`test_conversion_covers_every_seconds_field`) read the authored `.tres` directly. Twelve more —
  `test_unit_damage_and_death.gd`, `test_unit_attack_rhythm.gd`, `test_contact_resolution.gd`,
  `test_mana_economy.gd`, `test_block_deflect.gd`, `test_roll_iframes.gd`, and the integration
  suite's `test_unit_swing_root_live.gd`, `test_unit_approach_live.gd`,
  `test_two_units_converge_live.gd`, `test_unit_combat_live.gd`, `test_unit_clip_selection.gd`,
  `test_unit_attack_live.gd` — construct in-test literals and are unaffected in mechanism, only in
  whatever literal a fixture must set to stay valid under the new shape.
- **The `ResourceGenerationRule` seam is already built for the RULE, not the read path (B8
  correction).** `resource_generation_rule.gd`'s `source` docstring names `mana_accelerator` in
  advance, but that covers the rule schema only. `EconomyEvaluator` defines one resource constant,
  `MANA`; both its call sites are inside `MatchState._generate_mana`, hardcoding
  `SOURCE_MELEE_HIT` / `SOURCE_PASSIVE_TICK` — nothing scans authored rules by source. A new
  `data/economy/mana_accelerator.tres` is loaded and never asked for until AC 20's THIRD call site
  is added. No `STAMINA` constant or call site exists through this seam at all — AC 21 is a further
  step beyond AC 20, not a parallel drop-in.
- **The contact fact shape**, in `MatchState._resolve_contacts`, is a `Dictionary` with (at least)
  `attacker_index`, `attacker`, `target`, `target_index`, `kind`, `attack_index`, `dir`. The
  hero-target ladder's i-frame drop, `if target.hero.is_iframe_open(): continue`, sits after the
  dead-target/dead-attacker drops and before dedupe — dropped BEFORE resolution, per `1-9/R1`. AC
  16 rides this rung unchanged. `_resolve_unit_contact` has no iframe concept — units have no roll
  or defense window. Since the shipped Combat totem's priority is hero-preferring (AC 8, `4-4/R9`),
  its ordinary target is the opposing hero, so AC 16's homing-end event is reachable today; the
  unit-target case is AC 16's second sentence only, no synthetic test.
- **"Shape" was dropped from the attack record (AC 9)** — no reader exists in `src/state/` and no ruling defines one; it returns with a future moveset story.
- **CardEffectResolver's summon dispatch is uniform today** (`OUTCOME_SUMMON` for every `summon_*`
  prefix); this story is where its own header comment says the split has to land.
- **FeatureFlags gating (B11(b) closes this).** Both `minions` and `totems` bools exist, but only
  `flags.minions` is read anywhere in `src/` (`targeting_service.gd`, `card_effect_resolver.gd`) —
  `flags.totems` is unread. `epics.md`'s E4 goal commits `FeatureFlags: minions, totems`, so totem
  summon/behavior gates on `flags.totems`, the same read-pattern `flags.minions` uses today.
- **Arena measured from `src/main/main.tscn`:** the Ground's collision and mesh are both authored
  `size = Vector3(40, 1, 40)` (40×40, y=0, x/z in [-20, 20]; also `gdd.md`). The 8 m firing range
  (`4-4/R1`) and 60 m travel budget (`4-4/R2`) are both derived against this scale: 8 m keeps a
  totem's threat radius well inside the 40 m span; 60 m rounds up the ~56.57 m diagonal so a
  corner-to-corner shot can complete before the budget expires. Both remain working,
  playtest-tunable values.
- **Mana/Stamina accelerator numbers are derived relative to `passive_tick`, per `4-4/R13`.**
  `data/economy/passive_tick.tres` is the only precedent for "a totem produces a resource on some
  cadence" in this repo; the Mana Accelerator's cadence/amount are set relative to its values (same
  order of magnitude, stronger since totem-gated), and the Stamina Accelerator's regen factor is
  likewise stated as a multiple of the non-accelerated `stamina_regen_per_second` baseline. Exact
  figures are a dev-pass measurement against the live `.tres`, recorded at dev time; both remain
  working, playtest-tunable numbers. (`E4-P/R12`'s proposed `4-4a` epic cut was never decided and
  is not taken up here — see References.)

### Project Structure Notes

- Totem-specific code, if any is needed beyond data, follows the existing per-layer split: pure
  schema/data vocabulary under `src/state/resources/`, evaluators beside `economy_evaluator.gd`
  under `src/state/economy/`, unit board/record shape under `src/state/`, scene/actor nodes under
  `src/actors/`. No new top-level folder is implied.
- New per-kind `.tres` fixtures live under `data/` alongside `data/balance/`, `data/economy/`, and
  `data/cards/`, subject to the same golden discipline as existing authored content there.

### Project Context Rules

- F1: exactly one `func _physics_process` in `src/`, in `match_runner.gd` — a projectile's flight
  update must not add a second one.
- D3(a): `Input.*` only under `src/controllers/` — not implicated (no new input surface).
- D3(b)/A2: no global RNG / `Time` / `OS` / `Engine` in `src/state/` — a projectile's homing and
  acceleration state advances the same deterministic, injected-tick way every other `src/state/`
  timer already does; no wall-clock or engine-frame read.
- Docs and code never share a commit; commits are pure ASCII via `git commit -F`; shell is
  PowerShell 5.1 (no `&&`); trailer `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Story tiers: Tier A — full gate + review + live smoke ritual, per the board's own annotation and
  `E4-P/R9`.

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/gdd.md, Totem/Ward section] —
  three totem subtypes, their one-line behaviors including "static structure", and the 40×40 m
  arena.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md, E4 section] — E4 goal,
  key stories, exit criteria, committed obligations including `FeatureFlags: minions, totems`.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md — "Totem clause"
  under the 4-1 close-out] — record stays type/kind-less; 4-4's golden move ratified separately.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md — `4-2/R17`(c) /
  `4-3/R6`] — per-unit priority field permission, granted then assigned to this story (AC 7); also
  `src/state/unit_board.gd`'s own header ("NO PER-UNIT MAXIMUM") names the same owner.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md — `E4-P/R12`] —
  projectile flies, is shared infrastructure, outlives its source, needs its own attacker identity
  and dedupe; discharges `spell_*` forcing point `E4-P/R10`; PROPOSED but never decided a `4-4a`
  epic cut, not taken up here.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md — 4-4 rulings,
  `4-4/R1`-`4-4/R13`] — this story's own working values and mechanism rulings.
- [Source: src/state/economy/card_effect_resolver.gd, header + `OUTCOME_SUMMON` dispatch] — uniform
  `summon_*` dispatch, naming 4-4 as where the split lands.
- [Source: src/state/resources/resource_generation_rule.gd, `source` field docstring] —
  `mana_accelerator` seam named in advance.
- [Source: src/state/match_state.gd, `_resolve_contacts`] — contact fact shape, i-frame drop rung.
- [Source: docs/implementation-artifacts/4-3e-summon-spawn-placement.md AC 1] — spawn rule reused
  verbatim, already scoped to "minion or totem".
- [Source: docs/implementation-artifacts/sprint-status.yaml — `4-4-totems`, 4-3e close-out] — Tier
  A annotation; arena-edge and standing-summoner non-goals.

### Dev-pass decisions on the Open Questions (recorded as taken)

- **OQ-1, per-kind storage shape — DECIDED: two `Resource` schemas reached from `BalanceConfig`
  through one exported `Array[UnitKindProfile] unit_kinds`.** `UnitAttackProfile` carries AC 9's
  record (windup / active / recovery / range / damage / cadence, plus an optional
  `ProjectileProfile`); `UnitKindProfile` carries the kind (name, move speed, stop distance, max hp,
  priority name, the three phase multipliers, the attack LIST). *Why not a scanned directory like
  `data/minions/` or `data/economy/`:* those hold STRUCTURE — `EconomyEvaluator`'s header says in as
  many words that a rule carries no gameplay number, which is what lets them sit outside
  `apply_balance()`. Per-kind data is nothing but tuning, so it belongs to the object that travels
  through the X3 hot-reload seam; a scanned directory would put eleven live tunables beyond
  `apply_balance()` and beyond `BC/R3`'s isolation. *Why not flat suffixed globals:* four fields x
  four kinds plus the seven B5 additions is 44 flat fields, each audited individually with nothing
  enforcing that a kind carries a complete set — a resource per kind makes AC 6's "no field is left
  undefined for a kind" true by construction. *AC 11 holds* because `BalanceTicks.from_config()`
  walks `unit_kinds` and builds an index-aligned `UnitKindTicks`/`UnitAttackTicks` structure, so no
  second seconds-to-ticks boundary is authored.
- **OQ-2, Stamina Accelerator mechanism — DECIDED: a FACTOR applied at the existing
  `MatchState._regen_stamina` seat, not a per-player derived rate and not a pool change.** `3-1/R2`'s
  per-pool reload contract governs POOL BOUNDS at `apply_balance()`; a regen multiplier is not a
  bound. Deriving a per-player rate at reload time would make the accelerator's effect depend on
  WHEN a reload happened rather than on whether the totem is alive right now — a totem summoned
  mid-round would do nothing until the next reload, and a dead one would keep paying out. At the
  regen seat the factor tracks liveness exactly and returns to the non-accelerated value on the tick
  the totem dies, with nothing to tear down. Owner-only is structural rather than checked: the seat
  is already per-player and consults that player's OWN board. `StaminaPool` is untouched —
  `advance_regen(amount, suppressed)` already takes the amount per call, so the pool keeps the
  mechanism and this stays the D6 policy seat.
- **OQ-3, projectile representation — DECIDED: a per-player `ProjectileBoard` pure container
  (`PlayerState.projectiles`), built to the `UnitBoard` shape, holding no position and no heading.**
  It has to be state-owned because AC 16 makes a STATE decision (the i-frame drop) change an ACTOR
  behaviour (homing), and that flag must be snapshotted or a replay could diverge on it. Position
  stays actor-owned (`4-3/R2`, `4-1/R12` unchanged). The 60 m budget is tracked as an INTEGRATED PATH
  LENGTH the state layer computes from the same authored curve the actor moves by — a scalar of the
  same class as a timer, so no position travels inward and `push_contact` stays the only intake.
  **"The same curve" was TRUE and "the same value" was NOT, which is review finding H2 (fixed in the
  fix pass below).** The runner re-derived the SPEED after `advance()` had already incremented the
  flight clock, so the actor flew at speed(t+1) while the odometer had been charged speed(t) — one
  tick ahead, permanently. It now asks `MatchState.projectile_step_distance_at()` for the distance
  the odometer actually spent, which makes "one arithmetic, two readers" true by construction rather
  than by comment.
  `E4-P/R12`'s "its own attacker identity" is a THIRD PARTITION of the existing `[slot, index]` int
  space (`index <= -2`, `PROJECTILE_INDEX_BASE - i`) rather than a third element on the pair: the
  recorded contact ROW shape, every hero and unit call site, and every replay made before this story
  are all untouched. Its "own dedupe" is its LIVENESS — resolving consumes the shot, so it can never
  resolve twice and no hit list ships. A shot outlives its source by storing the FIRING KIND'S
  INDEX (config, not an instance) and reading every authored number through it live, so nothing goes
  stale on an X3 reload.

## Open Questions

- **Stamina Accelerator's economy wiring mechanism.** `4-4/R11` rules WHO (owner-only) and WHAT (an
  authored factor); HOW stays open within the `3-1/R2` per-pool reload contract — a per-player
  derived rate, a multiplier at the regen seat, or something else. AC 21 does not settle this.
- **Per-kind data's storage shape** (one `.tres` per kind vs. a single indexed resource vs.
  something else) is a dev-pass call; only that the eleven globals (AC 6 + B5 inventory) become
  per-kind, and the three named test files (AC 11) update to match, is fixed here.
- **Projectile representation in `src/state/`.** `E4-P/R12` rules the addressing PRINCIPLE (its own
  attacker identity and dedupe, not a `[slot, index]` unit-board address), not the representation —
  whether/how a live projectile appears in `src/state/` and the determinism snapshot is dev-pass.

## Dev Agent Record

### Agent Model Used

Claude Opus 5 (claude-opus-5[1m]). The story file was authored naming Sonnet 5; the dev pass was run
by Opus 5, corrected here rather than left stale. (The commit trailer stays the repo-wide constant
`Claude Opus 4.8` per the standing operator ruling — a different obligation from this field.)

### Debug Log References

Full build notes, every measurement and the three open findings: `C:\dev\_44-dev.md`.
Per-commit diffs: `C:\dev\_44-commitA.diff`, `_44-commitB.diff`, `_44-commitC.diff`.
Close-out suite log: `C:\dev\_44-close-suite.log`.

### Completion Notes List

**Four commits, code only; this docs commit is separate.**

1. `feat(state): 4-4 per-kind unit data, totem/minion split, kind index on the record` — AC 1, 2, 5,
   6, 7, 8, 9, 10, 11, AC 12 cause 1.
2. `feat(state): 4-4 the projectile - board, flight, homing and the totem actor` — AC 3, 4, 13, 14,
   15, 16, 17, 18, 19, AC 12 cause 2.
3. `feat(state): 4-4 the mana and stamina accelerator totems` — AC 20, 21, AC 12 cause 3.
4. `fix(test): bind % to the whole concatenated assertion message, not its tail` — a defect this
   pass introduced, found by the close-out suite run.

**Measurements.** State suite `499 / 3895 / 0` -> **`542 / 4211 / 0`**. Integration **42 -> 43
files**, all PASS. `bash test/run_all.sh` exits 0, `ALL TESTS PASSED`. Per-player snapshot key set
18 -> 27. `UnitBoard` bound guards 15 -> 17. Authored priorities 2 -> 3, authored economy rules
2 -> 3. `project.godot` byte-identical, no new collision layer (AC 3's "no second pattern" is why).

**AC 12, the three causes measured separately and in order.** The story requires the per-kind
conversion named as its own cause, separate from the projectile and from the accelerators, so the
golden was re-baselined once per build commit rather than once at the end with three causes
entangled:

| pass | cause | golden |
| --- | --- | --- |
| — | inherited from 4-3b | `4a089063` |
| 1a | SNAPSHOT SHAPE alone — `unit_kind` + `unit_attack_cooldown` at their zero payloads. Isolated by staging `GOLDEN_UNIT_MAX_HP` at 0.0, which reproduces the fixture's pre-4-4 behaviour exactly (`unit_max_hp` was never authored in `_golden_config`, so the t22 summon's record has entered dead-on-arrival since 4-3a) | `93ecf7e9` |
| 1b | THE CONVERSION'S CONTENT — the staged value restored to 7.0, record enters ALIVE, `unit_hp` `[0.0]` -> `[7.0]` | `836afc01` |
| 2 | THE PROJECTILE, snapshot shape — seven keys at empty arrays, isolated BY CONSTRUCTION (the fixture's kind is a minion that cannot launch) | `d94337cd` |
| 3 | THE ACCELERATOR FAUCETS — **measured a NON-MOVER**, all three candidate causes named | `d94337cd` |

*Corrected at the review (D3).* Pass 3's cause-1 wording said "the two rungs the fixture reaches ask
for `melee_hit` and `passive_tick`", which understates: the third `EconomyEvaluator.amount_for` call
IS reached on every tick — the cadence divisor clamps to >= 1 — it simply discards its result behind
the liveness gate. The non-mover argument is unchanged and if anything stronger; only the sentence
was loose.

Measured non-movers, named rather than assumed: AC 7's per-kind priority read (structural — the
fixture's kind authors `standard`, the same name the removed `PRIORITY_STANDARD` constant carried);
AC 10's cadence gate; the attacker-derived damage unification (`attack_damage_percent_of_max_hp`
3.0% x 100.0 == the minion record's authored 3.0, so it is bit-for-bit identical at the shipped
authoring); and `rng_state` at every step.

**One field split into two, and it is the notable ripple.** `unit_damage_per_hit` always had two
readers that were never one fact — the hero-versus-unit case `4-3a/R8` authored it for, and the
unit-versus-unit case `4-3b` AC 17 reused it for. AC 6 moves damage-per-hit per kind and AC 9 puts it
on the attack RECORD, which is the ATTACKER's property, so the two separate: a unit attacker deals
its own kind's record damage, a hero attacker deals the new flat `hero_damage_to_unit`. Damage
against a HERO became attacker-derived on the same reasoning, which is what makes a totem's shot
deal ITS authored damage rather than the hero's own swing percentage.

**Two live-behaviour consequences surfaced by integration tests, both real and both fixed.**
`test_unit_combat_live.gd` compared "enemy at full health" against the minion's maximum, but with
the split shipped the cast can now summon a TOTEM (12.0, not 9.0) — fixed by reading the summoned
unit's OWN kind off its record. More broadly, ten integration tests choose a summon card from the
dealt hand, and three cards now summon totems: a test measuring MINION behaviour must not have its
subject decided by the shuffle, so the shared chooser now excludes totem ids by reading the
resolver's own table. `test_unit_corpse_linger_live.gd` was already failing on exactly that
(`unit.animation` is null on a totem, which authors no rig).

**AC-by-AC.** 1 whole-id table + `SUMMON_KINDS` + per-record kind index; 2 `UnitBoard.add(max_hp,
kind_index)` — one mechanism, no second hp/damage/death path; 3 `totem_actor.tscn` (same script,
same layers, Hitbox deleted) + the runner picking the scene from authored data + the melee gather
skipped for a projectile kind; 4 spawn rule untouched (4-3e already scoped to "minion or totem");
5 all three totem kinds authored speed 0, machine-checked in `test_balance_authoring.gd` and
measured live; 6/9 eleven globals -> per-kind schemas; 7/8 per-kind priority + the new shipped
`hero_preferring.tres`; 10 `cadence_seconds` on the record + `_attack_cooldown` on the board; 11 all
three named test files updated, plus a NEW per-kind arm of the reflective guard (the eleven fields
left `BalanceConfig`'s reflection sight, so deleting them from the list would have been a silent
loss of audit); 12 above; 13 hold-fire falls out of the in-reach condition — a post-selection gate
with no timeout path and no distance re-selection anywhere; 14-19 the projectile; 20/21 the
accelerators.

**Known coverage boundary, reported rather than hidden — AND CORRECTED AT THE REVIEW (findings D1
and D2).** The projectile's BEHAVIOUR is not inside determinism coverage. Every previous board story
got its behaviour into the golden by construction, but the fixture summons at t22 and hashes at t24.

*The tick arithmetic was off by one (D2).* Measured against `advance()`'s actual step order — step 3b
`_advance_unit_attacks` runs BEFORE step 4 `_resolve_contacts`, and step 7 `_update_unit_targets`
runs last — at t23 step 4 the unit still holds the no-target pair, and the retarget that gives it one
happens at t23 step 7, AFTER. So the earliest scope-matching mark is t24, the windup begins t25, and
the launch transition is **t26**, not t25. The error ran against this pass's own margin, so the
conclusion held a fortiori; the number was still wrong.

*And the remedy sentence was FALSE (D1).* It said getting a shot into the golden "needs the recorded
sequence extended past t24". **It does not**, and a follow-up story starting from that sentence would
extend the fixture and measure nothing. Two independent structural reasons, either alone sufficient:
(i) `mark_in_reach_at` is reached only from `_mark_reach_from_fact`, which returns immediately for a
HERO attacker, and every fact this fixture pushes is hero-sourced — so the unit's reach flag is empty
at EVERY tick count and it can never wind up; (ii) the fixture's kind comes from
`UnitKindFixture.melee()`, which never sets `attack.projectile`, so the launch branch is dead
regardless. Reason (ii) is the same "isolated by construction" argument cause 2 above rests on, which
is why it is load-bearing here rather than a coincidence. Bringing a shot into this hash needs a
fixture that pushes a UNIT-sourced probe against a kind authoring a projectile — a redesign, not a
longer sequence. Guarded by `test/state/test_projectile_flight.gd` and
`test/integration/test_projectile_flight_live.gd` instead. Corrected in the determinism header too.

**An intermittent this pass introduced, unresolved** — *and RESOLVED at the review, `747ac31`; see
the fix-pass section below. The diagnosis recorded here was half wrong and is left standing as what
this pass actually knew.* `test/integration/test_debug_instruments.gd`
sometimes prints `ERROR: 1 resources still in use at exit`, and `run_all.sh` fails the suite on
`^ERROR:`. Measured against a worktree at the pre-pass baseline `500adef`: **0/18 runs at baseline,
3/18 (~17%) on this tree** — so it is attributable to this pass, not pre-existing. Twelve
`--verbose` runs never reproduced it, so there is a rate but no mechanism; the plausible candidates
are the two new `preload`s on `match_runner.gd` and the nested sub-resources
`balance_config.tres` now carries. No test asserts wrongly because of it. **Flagged for the review
gate.** The close-out `run_all.sh` run was clean (exit 0).

**Not done, and it is the operator's:** the Tier A LIVE SMOKE. `test_projectile_flight_live.gd`
proves the mechanism by machine (fires only in range, actor appears, travels 17.04 m, steers
1.55 rad toward a laterally-moving target over 89 samples), but AC 5's "stand where you place them",
the totem's on-screen legibility and whether a homing shot is actually dodgeable by a human are
`PROC/R8` matters for the operator's eye.

### Review fix pass — 2026-08-30 (`4-4/R14`, `4-4/R15`)

Driven by the review record at `_44-review.md` (verdict CHANGES REQUESTED: B1, B2 blocking, H2 open).
Baseline `747ac31`, which already carried the review's own two fixes (`638b307` H1, `747ac31` F1 —
so the "intermittent this pass introduced, unresolved" noted above IS resolved: the review localised
it to a 0.400 s audio cue outliving a quit 20 ms after `play()`, and silenced the cues the file never
asserts on; 40 consecutive runs, 0 leaks).

**Four commits, code only; this docs commit is separate.**

1. `fix(record): serialise nested resources and bump FORMAT_VERSION 4 -> 5` — B1.
2. `fix(state): a reach confirmation goes stale, so a totem cannot fire at a target that left` —
   B2, per `4-4/R14`. Carries the D1/D2/D3 corrections to `test_determinism.gd`'s header, because
   that commit rewrites the same block for the re-baseline.
3. `fix(state): the actor flies the distance the odometer was charged, on the same tick` — H2.
4. `chore: track generated .uid files from earlier stories` — the nine orphans (dev-pass F2).

**B1 — a saved record lost `unit_kinds` entirely.** `_resource_values` was a one-level capture, so
each `UnitKindProfile` reached `store_var` as a live reference and came back an `EncodedObjectAsID`;
assigning that untyped array into the typed property is rejected by the engine with NOTHING PRINTED.
Every replay from disk ran with no kinds at all. Both halves closed: the serialiser now recurses
(kind -> attack -> projectile) with a class-tagged dict per nested resource and rebuilds typed
containers with `Array.assign` / `Dictionary.assign` rather than `set()` (measured: `set()` with an
untyped array leaves size 0 even when every element is the right class); and `FORMAT_VERSION` goes
4 -> 5 so pre-4-4 records are refused with a reason rather than replayed kindless. Three tests,
mutation-proven — the extended round trip, a save/load/save BYTE-IDENTITY test (which names nothing,
so nothing can be forgotten — this is the assertion the `unit_kinds` loss walked straight through),
and a real v4-shaped record refused.

**B2 — AC 13 violated, and the fix cost the golden.** The cadence AND this story added turned a flag
consumed within a tick into one banked for a whole cooldown, so a totem fired at a target ~18 m away.
`4-4/R14` closes it without a negative probe: a confirmation stays CURRENT for one probe cadence plus
the F1 lag, derived not authored. **GOLDEN RE-BASELINED, `d94337cd` -> `a96b123e`, one cause**, on
the operator's explicit go — the freshness countdown is HASHED state by `4-3a/R17`, the key SET does
not move (still 27), and only `unit_in_reach`'s rendering changed (`false` -> `0`). The cheaper
option (hash only the boolean projection, keep `d94337cd`) was measured and REFUSED by name: it would
have made the remaining count a fourth unhashed cross-tick exclusion.
`UNHASHED_CROSS_TICK_MEMBERS` stays at THREE.

**H2 — the "one arithmetic" invariant was false as written.** See the OQ-3 note above. Fixed by
exposing the SPENT DISTANCE rather than a speed, with the curve refactored onto an explicit-tick core
so no path infers its tick from a clock any more. `EXEMPT_PURE_QUERIES` gains a fourth member with
its reason.

**Measurements.** State suite `542 / 4211 / 0` -> **`548 / 4270 / 0`**. Integration **43 files**, all
PASS. `bash test/run_all.sh` exits 0 after every commit. Golden `d94337cd` -> **`a96b123e`**, one
cause. `project.godot` untouched. Per-player snapshot key set unchanged at 27. `UnitBoard` bound
guards unchanged at 17. Five mutations, five kills, every restore from a SHA256-verified out-of-repo
copy and never `git checkout --`.

**Still the operator's, unchanged:** the Tier A LIVE SMOKE, and the review's non-blocking findings
M1-M9 and L1-L5, none of which this pass touched.

### Live smoke — 2026-08-30

Run by the operator's own hand, all six checklist points passed (point 6 only after the deck_size
20 -> 24 fix below — with the fixed seed, the two accelerator cards never entered the deck, so
point 6 could not be exercised until that was corrected). Verification re-review: CLOSED, 0
reopened.

Three feel findings, all deferred by the operator rather than actioned: roll i-frames / animation
speed; whether block should fully negate a totem's projectile; totem self-rotation, accepted as
shipped.

One comment nit owed from the review: `unit_board.gd`'s freshness docstring named
`MatchState._reach_freshness_ticks()` as the source of the `maxi(1, ...)` clamp, but that clamp
actually lives in `BalanceTicks.minion_retarget_interval_ticks` (`balance_ticks.gd`) — the helper
only adds 1 to it. Fixed as its own commit, comment-only, ahead of this docs commit.

### File List

**New — `src/`**
- `src/state/resources/unit_kind_profile.gd`
- `src/state/resources/unit_attack_profile.gd`
- `src/state/resources/projectile_profile.gd`
- `src/state/timing/unit_kind_ticks.gd`
- `src/state/timing/unit_attack_ticks.gd`
- `src/state/projectile_board.gd`
- `src/actors/projectiles/projectile_actor.gd`
- `src/actors/projectiles/projectile_actor.tscn`
- `src/actors/minions/totem_actor.tscn`

**New — `data/`**
- `data/minions/hero_preferring.tres`
- `data/economy/mana_accelerator.tres`

**New — `test/`**
- `test/unit_kind_fixture.gd`
- `test/state/test_projectile_flight.gd`
- `test/state/test_totem_accelerators.gd`
- `test/integration/test_projectile_flight_live.gd`

**Modified — `src/`**
- `src/state/resources/balance_config.gd`
- `src/state/timing/balance_ticks.gd`
- `src/state/unit_board.gd`
- `src/state/player_state.gd`
- `src/state/match_state.gd`
- `src/state/economy/card_effect_resolver.gd`
- `src/state/economy/economy_evaluator.gd`
- `src/actors/minions/unit_actor.gd`
- `src/main/match_runner.gd`

**Modified — `data/`**
- `data/balance/balance_config.tres`
- `data/feature_flags.tres`

**Modified — `test/state/`**
- `test_data_resources.gd`, `test_balance_authoring.gd`, `test_balance_config.gd`,
  `test_determinism.gd`, `test_replay_identity.gd`, `test_intent_recorder.gd`,
  `test_card_observation.gd`, `test_draw_delay_and_reshuffle.gd`, `test_card_effect_resolution.gd`,
  `test_targeting_service.gd`, `test_minion_authoring.gd`, `test_mana_economy.gd`,
  `test_match_state.gd`, `test_unit_attack_rhythm.gd`, `test_unit_damage_and_death.gd`,
  `test_contact_resolution.gd`, `test_block_deflect.gd`, `test_roll_iframes.gd`

**Modified — `test/integration/`**
- `test_summon_actor_live.gd`, `test_two_units_converge_live.gd`, `test_unit_aim_live.gd`,
  `test_unit_approach_live.gd`, `test_unit_attack_live.gd`, `test_unit_combat_live.gd`,
  `test_unit_corpse_linger_live.gd`, `test_unit_corpse_walkthrough_live.gd`,
  `test_unit_spawn_placement_live.gd`, `test_unit_strike_alignment_live.gd`,
  `test_unit_swing_root_live.gd`

**Untouched, deliberately:** `project.godot` (no new collision layer, no new autoload, no Input Map
change), `src/actors/hero/*`, `src/ui/*`, and every `connect_*` observation seam — the family stays
at EIGHT.

### Change Log

| Date | Change |
| --- | --- |
| 2026-08-30 | Dev pass executed via `gds-dev-story`. Four code commits (three build + one fix), golden re-baselined `4a089063` -> `d94337cd` across three separately measured causes, suite `499/3895` -> `542/4211`, integration 42 -> 43 files. Status -> `review`. Three open findings recorded for the review gate. |
| 2026-08-30 | Code review via `gds-code-review`: CHANGES REQUESTED, 2 blocking (B1, B2), 2 high (H1 fixed in-review as `638b307`, H2 open), 9 medium, 5 low. Golden chain and address partition both verified PASS. The F1 intermittent localised and fixed as `747ac31`. |
| 2026-08-30 | Review fix pass. Four code commits (B1, B2, H2, chore). Operator rulings `4-4/R14` (reach confirmations have a derived shelf life; no negative probe) and `4-4/R15` (`FORMAT_VERSION` 4 -> 5 with nested resource serialisation). Golden re-baselined `d94337cd` -> `a96b123e`, ONE cause, on the operator's explicit go; `UNHASHED_CROSS_TICK_MEMBERS` stays at three. Suite `542/4211` -> `548/4270`, integration 43 files. Findings D1/D2/D3 corrected here and in the determinism header. M1-M9 and L1-L5 deliberately untouched; live smoke still owed. |
