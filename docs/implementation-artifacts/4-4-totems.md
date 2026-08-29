---
baseline_commit: d5a83721e4a0a9762c63714df778beb0d6ca34ca
---

# Story 4.4: Totems

Status: authored

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
3. A totem blocks movement using the same `CharacterBody3D` + one `CollisionShape3D` pattern the
   existing unit actors use — no second collision pattern is authored.
4. A totem spawns using the existing hero-relative, rear-of-summoner placement rule (story 4-3e) —
   no second spawn rule is authored. This already covers totems (4-3e's own AC 1 says "minion or
   totem").
5. Both the Mana Accelerator and the Stamina Accelerator totem are authored with a movement speed
   of 0 and never leave their spawn position for as long as they are alive.

**Per-kind data**

6. `unit_move_speed`, `unit_stop_distance`, `unit_max_hp`, and `unit_damage_per_hit` are authored
   per kind (at minimum: minion, Combat totem, Mana Accelerator totem, Stamina Accelerator totem)
   instead of as four shared `BalanceConfig` globals. Every kind's value for a field it does not
   use for anything (e.g. a static totem's damage-per-hit, since it makes no melee contact) is
   still authored and non-negative — no field is left undefined for a kind.
7. Every kind's attack capability is authored as a LIST of attack records (length one is
   acceptable for this story), never a single flat attack. An attack record carries windup,
   active, recovery, range, damage, and shape. Selecting among multiple entries in a list is
   explicitly out of scope (Non-Goals).
8. The Combat totem's one attack record authors a range of 8 m and its own firing cadence as a
   number on that record.
9. `test/state/test_data_resources.gd`'s `E1_BALANCE_FIELDS` reflection list and
   `test/state/test_balance_authoring.gd`'s bespoke per-field bounds are updated to match
   whatever the per-kind field set becomes — both are named here because the per-kind conversion
   removes or reshapes the four fields they currently audit as flat `BalanceConfig` globals.
10. The determinism golden (currently
    `4a089063a8b3eff2274c0ca300dafe80e4eb4d3970ada352ca432a7e39844bdf`) is re-baselined, with the
    per-kind data conversion named as its own measured cause, separate from any cause introduced
    by the projectile or the accelerator faucets.

**Combat totem: firing and targeting**

11. A live Combat totem only fires at a target within its authored 8 m firing range; a target
    outside that range is never fired upon regardless of how long it remains in that state.
12. On firing, the Combat totem's projectile is a distinct entity in the world (not an instant
    hit) that travels from the totem toward its target rather than resolving contact immediately.

**Projectile: homing, acceleration, and avoidance**

13. A live projectile homes on its target (its heading updates toward the target's current
    position over the course of its flight) according to an authored homing profile, and
    separately accelerates at some point during flight according to an authored acceleration
    profile. Both profiles are authored data; no code branch selects between different homing or
    acceleration behaviors by kind.
14. When a projectile's flight would produce a contact fact against a target whose i-frame window
    is open, the existing i-frame drop rung in the target's contact ladder (`match_state.gd`,
    story 1-9's `1-9/R1`) drops that fact exactly as it does today for a melee hit, and dropping
    it is also the event that ends that projectile's homing: from that tick onward the projectile
    keeps its last heading and travels in a straight line for the remainder of its flight,
    updating its heading toward no target ever again.
15. A target merely leaving the projectile's flight path (without an i-frame window being open at
    the tick a contact fact would otherwise land) does not end homing — the projectile keeps
    steering toward that target's current position.
16. A projectile whose contact fact resolves as a block or a deflect is consumed on that contact —
    it does not continue flying past a blocked or deflected hit.
17. A projectile that never produces a contact fact against anything travels at most 60 m of
    total distance, after which it is removed from the world. This 60 m flight limit is a distinct
    authored number from the Combat totem's 8 m firing range and governs a different thing (total
    travel budget vs. whether the totem may fire at all).

**Accelerators**

18. While a Mana Accelerator totem is alive, it is a resource-generation source recognized by the
    existing `ResourceGenerationRule` / `EconomyEvaluator` seam (a new `.tres` under
    `data/economy/`, no new evaluator code), producing mana on some authored cadence.
19. While a Stamina Accelerator totem is alive, the stamina regeneration rate of at least the
    summoning player's hero is raised above its non-accelerated value, and returns to the
    non-accelerated value once that totem is no longer alive.

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
  annotation on `4-4-totems`: "Tier A (golden clause, not build weight — E4-P/R9)". The "totem
  clause" ratified at 4-1's close-out (decision-log, 4-1 Totem clause) states the unit record
  carries no type/kind field specifically so uniform `summon_*` treatment would not pre-commit
  this story's differentiation, and separately ratifies "4-4's second golden move" as its own Tier
  A reason, independent of 4-1. `CardEffectResolver`'s own header names this story explicitly:
  "the six `summon_*` ids ... this story treats every one of them IDENTICALLY (the ratified totem
  clause). A whole-id table would be the place `4-4`'s totem/minion split has to land, and writing
  it now would pre-commit that shape."
- **Baseline measured for this story (repo, before any change):** HEAD `d5a83721e4a0a9762c63714df778beb0d6ca34ca` == `origin/main`, clean tree. State suite `499 tests, 0 failed, 3895 assertions` (`bash test/run_all.sh`). Integration suite: 42 files, all `RESULT: PASS`. Determinism golden:
  `const GOLDEN := "4a089063a8b3eff2274c0ca300dafe80e4eb4d3970ada352ca432a7e39844bdf"`
  (`test/state/test_determinism.gd:458`), unmoved since story 4-3b and confirmed unmoved through
  4-3c/4-3c1/4-3d/4-3e per sprint-status.yaml's own close-out notes.
- **The four globals converting to per-kind data, and where they are read today:**
  `unit_move_speed` / `unit_stop_distance` are read together at `src/main/match_runner.gd:1079-1080`
  (the per-tick approach/movement resolution); `unit_max_hp` is read at `src/state/match_state.gd:1428`
  (`player.units.add(balance.unit_max_hp)`, the cast-time spawn seat); `unit_damage_per_hit` is
  read at `src/state/match_state.gd:1131` (`target.units.apply_damage_at(index,
  balance.unit_damage_per_hit)`, the unit half of the step-4 contact ladder). All four are declared
  on `BalanceConfig` (`src/state/resources/balance_config.gd:172,180,197,215`), authored once in
  `data/balance/balance_config.tres`, and shared by every unit today — `unit_board.gd`'s own header
  states this explicitly ("NO PER-UNIT MAXIMUM, deliberately... because no unit differs from
  another yet") and names 4-3/4-4 as the stories allowed to change it (`4-2/R17`(c)).
- **Tests measured as pinning these four globals today** (constructing a `BalanceConfig` fixture
  and setting one or more of the four fields, per the standing `BC/R3` isolation): only
  `test/state/test_data_resources.gd` (`E1_BALANCE_FIELDS` reflection guard) and
  `test/state/test_balance_authoring.gd` (bespoke `> 0.0` / hits-to-kill / reach-vs-stop-distance
  bounds) read the authored `.tres` directly. Twelve more construct in-test literals for one or
  more of the four fields and are unaffected in mechanism, only in whatever literal a fixture must
  set to stay valid under the new shape: `test/state/test_unit_damage_and_death.gd`,
  `test/state/test_unit_attack_rhythm.gd`, `test/state/test_contact_resolution.gd`,
  `test/state/test_mana_economy.gd`, `test/state/test_block_deflect.gd`,
  `test/state/test_roll_iframes.gd`, `test/integration/test_unit_swing_root_live.gd`,
  `test/integration/test_unit_approach_live.gd`, `test/integration/test_two_units_converge_live.gd`,
  `test/integration/test_unit_combat_live.gd`, `test/integration/test_unit_clip_selection.gd`,
  `test/integration/test_unit_attack_live.gd`.
- **The `ResourceGenerationRule` seam, already built for this.** `src/state/resources/resource_generation_rule.gd`
  names its own extension point in its header: `source` documents "&"mana_accelerator" (an E4
  totem — a new .tres, no code)"`. Two rules exist today, `data/economy/melee_hit.tres` and
  `data/economy/passive_tick.tres`, both `resource = &"mana"`. `EconomyEvaluator`
  (`src/state/economy/economy_evaluator.gd`) defines only one resource constant, `MANA`, and both
  its call sites in `match_state.gd` (`:1174-1187`) hardcode `EconomyEvaluator.MANA` — there is no
  existing `STAMINA` constant or stamina call site through this seam. AC 19 (Stamina Accelerator)
  therefore is not a drop-in `.tres` the way AC 18 (Mana Accelerator) is; see Open Questions.
- **The contact fact shape**, read at `src/state/match_state.gd:837-899` (`_resolve_contacts`), is a
  `Dictionary` with (at least) `attacker_index`, `attacker`, `target`, `target_index`, `kind`,
  `attack_index`, and `dir`. The hero-target ladder's i-frame drop is
  `if target.hero.is_iframe_open(): continue` (`:890`), placed after the dead-target and
  dead-attacker drops and before dedupe registration — dropped BEFORE any resolution, per
  `1-9/R1`. AC 14 rides this exact rung; it does not add a second i-frame check.
  `_resolve_unit_contact` (the unit-target half of the same ladder, `:863-864` dispatches into it)
  has no iframe concept today — units have no roll and no defense window
  (`match_state.gd:855-862`'s own comment says so) — so a projectile's target for AC 14 is
  necessarily a hero, not another unit.
- **CardEffectResolver's summon dispatch is uniform today** (`OUTCOME_SUMMON` for every `summon_*`
  prefix, `src/state/economy/card_effect_resolver.gd:41-45`); this story is where that resolver's
  own comment says the totem/minion split has to land.
- **FeatureFlags gating measured as-is:** `FeatureFlags` already has both a `minions` bool and a
  `totems` bool (`test/state/test_data_resources.gd:10`), but only `flags.minions` is read anywhere
  in `src/` (`targeting_service.gd:248`, `card_effect_resolver.gd:122`) — `flags.totems` is
  currently unread. Whether totem summon/behavior should gate on `flags.totems` instead of (or in
  addition to) `flags.minions` is not settled by any prior ruling; see Open Questions.
- **Arena measured directly from `src/main/main.tscn`:** the Ground `StaticBody3D`'s collision and
  mesh are both authored `size = Vector3(40, 1, 40)`, confirming the 40×40, y=0 ground plane,
  x/z in [-20, 20] figure against the shipped scene (also `gdd.md:334`).

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

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/gdd.md#L188,L334] — three totem
  subtypes and their one-line behaviors; 40×40 m arena.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md#L117-L133] — E4 goal,
  key stories, exit criteria, committed obligations.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md — "Totem clause"
  under the 4-1 close-out] — record stays type/kind-less; 4-4's golden move ratified separately.
- [Source: src/state/unit_board.gd — header comments on `_hp`, "NO PER-UNIT MAXIMUM"] — per-kind
  data permission and its owner (`4-2/R17`(c)).
- [Source: src/state/economy/card_effect_resolver.gd:36-45] — uniform `summon_*` dispatch, naming
  4-4 as where the split lands.
- [Source: src/state/resources/resource_generation_rule.gd:29-31] — `mana_accelerator` seam named
  in advance.
- [Source: src/state/match_state.gd:807-899] — contact fact shape and the i-frame drop rung.
- [Source: docs/implementation-artifacts/4-3e-summon-spawn-placement.md AC 1] — spawn rule reused
  verbatim, already scoped to "minion or totem".
- [Source: docs/implementation-artifacts/sprint-status.yaml — `4-4-totems`, 4-3e close-out] — Tier
  A annotation; arena-edge and standing-summoner non-goals.

## Open Questions

- **Stamina Accelerator's economy wiring.** `EconomyEvaluator` only defines a `MANA` resource
  constant and both its call sites in `match_state.gd` hardcode it — there is no existing stamina
  call site through the `ResourceGenerationRule` seam. Whether AC 19 is satisfied by extending that
  seam with a second resource constant and call site, or by some other mechanism entirely, is a
  dev-pass decision, not settled here.
- **`FeatureFlags.totems` is authored but unread.** Should totem summon/behavior gate on
  `flags.totems` now that totems are a distinct kind, on `flags.minions` as today, or on both? No
  prior ruling settles this.
- **Projectile addressing and storage.** Ruling 6 requires the projectile to be "a real flying
  entity" with authored homing/acceleration profiles; how it is represented in `src/state/` (and
  whether/how it appears in the determinism snapshot) is explicitly left to the dev pass.
- **Per-kind data's storage shape** (one `.tres` per kind vs. a single indexed resource vs.
  something else) is left to the dev pass; only the requirement that the four globals become
  per-kind, and that the two named test files are updated to match, is fixed here.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5)

### Debug Log References

### Completion Notes List

### File List
