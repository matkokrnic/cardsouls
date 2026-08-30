---
baseline_commit: d5a83721e4a0a9762c63714df778beb0d6ca34ca
---

# Story 4.4: Totems

Status: ready-for-dev

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

Claude Sonnet 5 (claude-sonnet-5)

### Debug Log References

### Completion Notes List

### File List
