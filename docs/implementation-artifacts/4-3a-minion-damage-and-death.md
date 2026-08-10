---
baseline_commit: dab229178985f9532b181224421ba086328fac9b
---

# Story 4.3a: Minion damage and death

Status: ready-for-dev

## What this story supersedes

The board previously carried `4-3a-minion-combat`, a single backlog entry for all minion combat
consequences (HP, damage, death, board removal, and the melee retune). **Cut by `4-3a/R1`**
(decision-log Session 2026-08-10, "4-3a scope split"): this story ships the unit as TARGET only —
hp, damage, death, board removal, and the contact-fact target addressing that makes a unit
hittable at all. A new `4-3b-minion-attack-rhythm` (backlog) carries the unit as ATTACKER —
windup/active/recovery, unit hitbox, unit-vs-unit damage — and inherits the melee retune
(`E3-R/R3`), re-anchored from this story by `4-3a/R5`.

## Story

As a player,
I want a hero's landed attack to damage and eventually kill a summoned minion, removing it from
the board,
so that summoning has a real combat cost and killing a unit is a legible, decisive event rather
than a no-op against an invulnerable box.

## Acceptance Criteria

1. **`hp` joins the unit record.** `UnitBoard` gains an `hp: float` per record, spending the
   `4-2/R17(c)` permission on exactly this one field (`4-3a/R6`) — no per-unit max, since maximum
   HP is authored on `BalanceConfig` and shared by every minion. A freshly summoned unit (`add()`)
   enters at that authored maximum, on the `HeroState._init(... max_hp ...)` precedent
   (`hero_state.gd:147-150`).
2. **Damage against a unit is applied through the shipped 1-8 contact pipeline
   (`match_runner.gd:807-844` gather, `match_state.gd:665-708` `_resolve_contacts`), never as an
   abstract cadence or a separate resolution path invented for units.** A hero's confirmed swing
   against a unit reduces `hp` by a DEDICATED FLAT damage-to-unit value, balance-authored and read
   at point of use (CONSTRAINT C) — NOT `attack_damage_percent_of_max_hp` (`match_state.gd:695`)
   recomputed against the unit's own authored maximum (`4-3a/R8`, decided by Matko). Reason:
   `attack_damage_percent_of_max_hp` is a percentage of the TARGET's own maximum, so reusing it
   against a unit's own authored maximum would make hits-to-kill a constant (34, at the authored
   3.0%) for EVERY possible authored unit maximum, and the authored unit HP field would be
   cosmetic. Authored provisionally at unit maximum HP = 9.0, flat damage to a unit = 3.0 (three
   swings to kill); both values are tuned by the melee retune in `4-3b`. This AC names one
   implementation, not two.
3. **The contact fact widens to carry a TARGET ADDRESS `[slot, index]`, on the `unit_targets`
   precedent `4-2/R2` already set** (`index >= 0` addresses a board unit at that index, `index ==
   -1` addresses that slot's hero — the exact convention `unit_board.gd`'s own target pair already
   uses for what a unit has acquired, so the contact fact's target and a unit's acquired target
   share one addressing scheme rather than two that could drift). `push_contact`
   (`match_state.gd:429-444`) and `_resolve_contacts`'s per-fact target lookup change shape
   together; every existing hero-vs-hero call site continues to pass `[target_slot, -1]` and must
   resolve identically to today's bare-slot behaviour (a non-vacuous regression pin, not just a
   type change). A swing that overlaps multiple targets in the same active window CLEAVES THROUGH
   them: the dedupe key widens from `attack_index` alone to the full target address,
   `[attack_index, slot, index]` — today's slot-only key is an artefact of a world where only
   heroes existed, and under it one swing overlapping a unit and the enemy hero would resolve only
   the first (`4-3a/R16`, closing the Open Question about the dedupe key). The regression pin
   named: same damage value, same dedupe outcome, same membership of the confirmed-hit list, and
   same `hit_landed` payload for a hero target (`4-3a/R19`), covering the shipped contact tests —
   `test/state/test_contact_resolution.gd`, `test/state/test_contact_pipeline.gd`,
   `test/state/test_block_deflect.gd`, `test/state/test_roll_iframes.gd`,
   `test/state/test_mana_economy.gd`, `test/state/test_replay_identity.gd`,
   `test/state/test_intent_recorder.gd`, `test/integration/test_contact_pipeline.gd`,
   `test/integration/test_replay_contacts.gd` — and the determinism fixture's own contact payloads
   (`test/state/test_determinism.gd`).
4. **The drop at `match_runner.gd:825-827` (every overlapping area whose `_slot_of` is -1) is
   deliberately opened.** Today `_gather_contact_facts` silently discards any overlap that is not a
   hero hurtbox — that is precisely what makes a unit invisible to the contact pipeline. This story
   extends the identity resolution so a unit hurtbox resolves to a real `[slot, index]` target
   instead of being dropped. The unit hurtbox goes on the EXISTING layer 2 "hurtbox" (bit value
   2) — the same layer the hero Hurtbox already occupies (`4-3a/R11`, decided by Matko). Measured:
   the hero Hitbox already declares `collision_layer = 4` / `collision_mask = 2`
   (`hero.tscn:73-75`), and the entire repo contains exactly four layer/mask declarations, all in
   `hero.tscn` — so a unit hurtbox on layer 2 is visible to the hitbox's mask with NO change to
   either `hero.tscn` or `project.godot`; both stay BYTE-IDENTICAL, and nothing other than the
   hero hitbox masks layer 2. The Open Question about which layer to use is CLOSED with this
   answer and its measurement (no unit carries an `Area3D` at all today — `unit_actor.tscn`
   currently ships a body only, no hurtbox, per `4-3/R17`).
5. **A confirmed hit against a unit generates NO mana** (`4-3a/R3`, decided by Matko). Step 5's
   `_generate_mana` (`match_state.gd:733-750`, runs through the passive rung, not just the melee
   grant) awards `melee_hit_mana` on every confirmed hit (`match_state.gd:706`'s
   `confirmed.append`) — a unit-target confirmation must not enter that list, or killing minions
   becomes a mana source.
6. **No friendly fire.** A hero's hitbox does not damage a unit owned by that hero's own slot
   (`4-3a/R4`, decided by Matko) — the identity filter that already excludes self-overlap
   (`match_runner.gd:823-824`) extends to same-slot units. This filter sits at GATHER time, in
   `_gather_contact_facts`, rather than as a state-side check: the contact seam itself asserts
   that attacker and target slots differ, so a same-slot fact reaching `push_contact` would trip
   that invariant (`4-3a/R21b`).
7. **Death removes a unit from the board by leaving a HOLE at a stable index, never by compacting
   the array** (`4-3a/R2`). `unit_targets` is `[slot, index]` under throttled retargeting
   (`match_state.gd` step 7), so compaction would silently re-point a stale reference at a
   DIFFERENT live unit. Precedent: `4-0-hand-slot-stability`'s hole-not-compaction discipline. A
   dead unit's record becomes inert but its index does not shift and no other record's index
   changes. **A hole is NEVER REUSED** (`4-3a/R9`): `UnitBoard.add()` is an unconditional append
   today and stays one — a summon following a death lands at a NEW index, never in the dead
   unit's hole. Reason: reuse would silently re-point a stale throttled `unit_targets` reference at
   a DIFFERENT live unit, the exact aliasing the hole discipline exists to prevent, and a future
   pooling story is precisely the change that would introduce a free list "for free." **Liveness
   gates at two NAMED seats** (`4-3a/R14`): the retarget loop in `TargetingService`'s candidate
   scan (advance()'s targeting seat) and the approach loop in `match_runner.gd`'s DRIVE phase both
   drive every index unconditionally today, and this story's liveness check lands at both — a dead
   unit's record becomes "no longer walking" only because the approach seat is taught to skip it,
   and "no longer a targeting candidate" only because the targeting seat is.
8. **Board removal is measured, not asserted**: a unit driven to `hp <= 0` stops being a
   candidate for `TargetingService` (`4-2/R3`'s candidate scan must skip a dead unit's index) and
   stops being addressable as an attack target by a later swing. `TargetingService.target_for`/
   `reason_for` TAKE AN `Array[int]` OF LIVING INDICES in place of `opposing_unit_count: int`
   (`4-3a/R15`, `src/state/targeting/targeting_service.gd`). Measured: today the candidate set
   reaches this file as three ints and a bool and `target_for` always returns index 0, so it
   structurally CANNOT skip a dead unit's index — with a hole at index 0 it would hand back the
   corpse, and its `REASON_NO_LIVING_CANDIDATE` branch tests a count that a hole keeps non-zero.
   An array of ints is still a plain fact, so the file's stated contract ("plain facts, never a
   `PlayerState`") is preserved. The file's docstring claiming "a unit is always a living
   candidate this story" is FALSIFIED by this story and must be corrected in the same pass.
9. **Golden and snapshot key set are measured in both directions, not assumed unmoved** — see
   Golden Prediction. This AC is the regression harness around the positive claim, on the `4-1/R4`
   shape.
10. **The deferred unit-vs-unit machine coverage item is discharged**
    (`deferred-work.md`, "Unit-vs-unit body collision is unmeasured", `4-3/R21` finding 1,
    OWNER `4-3a-minion-damage-and-death`) — a live test drives two or more units at the same
    acquired target simultaneously and measures no jitter/wedging/pass-through, closing the gap
    between the 4-3 close-out's by-hand observation and machine coverage. This is body collision
    only; it is not a combat AC and does not require either unit to be able to damage the other
    (that is `4-3b`'s). **This AC gets a positive half** (`4-3a/R18`): as written it is three
    negative claims (no jitter, no wedging, no pass-through) and would pass against two units that
    never spawned or never moved. It must additionally require that BOTH units are measured to
    have MOVED and to have CONVERGED within a bounded distance of the SAME acquired `[slot,
    index]` pair, with the frame samples and tolerances DERIVED AT RUNTIME from the authored
    balance so the test survives the retune. The existing live test's single-actor helper returns
    the first `UnitActor` in tree order and cannot be reused for two units — whoever writes this
    test needs a helper that resolves both.
11. **A dead unit's actor is FREED.** On death the unit's actor leaves the scene (`queue_free()`,
    the shipped answer until the 60fps-at-16-units criterion fails per `4-5`'s pooling gate — this
    is NOT the pooling question), and its position in the runner's per-slot actor array is
    preserved as a HOLE so indices stay aligned with the record (`4-3a/R13`). Measured: the actor
    spawn loop only ever grows and the free path is reached from the debug reset alone, so without
    this AC the killed minion stays a visible, solid grey box forever — contradicting this story's
    own "removed from the board."

## Non-Goals (explicit — all of this is `4-3b-minion-attack-rhythm`)

- Units do not attack. No unit hitbox, no unit-originated contact fact, no unit-vs-hero or
  unit-vs-unit damage.
- Units have no action state and no phase timers — no windup, no active window, no recovery.
- No attack-range logic of any kind.
- `approach()` is NOT taught to distinguish "arrived" from "physically blocked" — that
  distinction's only consumer is attack range, which lands in `4-3b` (the other half of the item
  this story splits in `deferred-work.md`).

## Open Questions — ruled at the readiness gate (2026-08-10, `4-3a/R8`-`R21`)

All five closed except Q4, which stays open in a narrower, measured form.

1. **CLOSED by `4-3a/R20`.** The unit-target path through the step-4 ladder SHARES the rungs a
   unit actually has (dead-attacker drop, dedupe) and SKIPS the ones it structurally lacks
   (iframe, deflect, block — all properties of a hero target). The implementation may express this
   as a branch inside `_resolve_contacts`'s existing ladder or a helper alongside it; either
   satisfies this AC as long as the ORDER of the shared rungs is identical to today's.
2. **CLOSED by `4-3a/R16`.** The dedupe key widens from `attack_index` alone to the full target
   address, `[attack_index, slot, index]`, so one swing landing on three units in the same active
   window produces three separate confirmations instead of resolving only the first.
3. **CLOSED by `4-3a/R11`.** The unit hurtbox uses the EXISTING layer 2 "hurtbox" — the hero
   Hitbox's mask already includes it, so `project.godot` and `hero.tscn` both stay
   byte-identical; no new layer is authored.
4. **PARTIALLY OPEN, in measured form (`4-3a/R21a`).** The story's claim is that death is resolved
   in the contact step immediately after damage is applied, and that the step-1b round-over freeze
   precedes that step and therefore needs no special case — but this is A CLAIM TO BE MEASURED in
   the dev pass, not asserted as settled fact.
5. **CLOSED by `4-3a/R17`.** `hp` goes into the snapshot — a value that crosses ticks and decides
   an outcome does not sit outside the hash. See Golden Prediction for the two separately named
   movers this produces.

## Deferred / Out of scope

- **Minion attack rhythm** (`4-3b-minion-attack-rhythm`, per `4-3a/R1`) — windup/active/recovery,
  unit hitbox, unit-vs-unit damage.
- **The melee retune** (`E3-R/R3`) — re-anchored to `4-3b` by `4-3a/R5`, not this story.
- **`approach()` distinguishing "arrived" from "physically blocked"** — `4-3b`'s, its only
  consumer is attack range (`deferred-work.md`).
- **Per-unit priority field** (`4-4`) — the `4-2/R17(c)` permission is spent here on `hp` only;
  `4-3b` obtains its own advance permission at its own scope ruling, it does not inherit this
  story's.
- **Object pooling** (`4-5`) — a dead unit's node lifecycle (whether it `queue_free()`s immediately
  or is later pooled) is unaffected by this story's scope.
- **Per-hit feedback on a damaged (not yet dead) unit** (`deferred-work.md`, OWNER
  `4-3b-minion-attack-rhythm`, `4-3a/R12`) — `hit_landed` is NOT emitted for a unit target this
  story; the legible event here is DEATH. See AC-adjacent Live Smoke note and `4-3a/R12` for the
  two rejected alternatives.

## Tasks / Subtasks

- [ ] Add `hp: float` to `UnitBoard`'s per-record arrays, initialized at `add()` from the
      balance-authored unit maximum HP (AC 1)
- [ ] Author the unit maximum-HP field (9.0 provisional) AND a dedicated flat unit-damage field
      (3.0 provisional) on `BalanceConfig` (`@export_group("Minions")` precedent), both audited
      `> 0` in `test_balance_authoring.gd`, both extend `E1_BALANCE_FIELDS` (AC 1, AC 2, `4-3a/R8`)
- [ ] Widen the contact fact's target field to `[slot, index]` in `push_contact` and
      `_resolve_contacts`, preserving today's hero-vs-hero behaviour under the `[slot, -1]`
      convention (AC 3) — a unit-target branch/helper sharing the dead-attacker-drop and dedupe
      rungs, skipping iframe/deflect/block (AC 3, `4-3a/R20`)
- [ ] Widen `register_swing_hit`'s per-attacker dedupe key from `attack_index` alone to
      `[attack_index, slot, index]`, so a cleaving swing produces one confirmation per target
      (AC 3, `4-3a/R16`)
- [ ] Extend `_gather_contact_facts`'s identity resolution so a unit hurtbox resolves to
      `[slot, index]` instead of being dropped at the `_slot_of == -1` check. NO hero Hitbox or
      `project.godot`/`hero.tscn` edit — the unit hurtbox lands on the EXISTING layer 2 "hurtbox"
      (AC 4, `4-3a/R11`)
- [ ] Add a unit hurtbox (`Area3D`, `collision_layer = 2`, `collision_mask = 0`) to
      `unit_actor.tscn`, mirroring `hero.tscn`'s Hurtbox node shape and its layer/mask discipline
      (AC 4, `4-3a/R11`)
- [ ] Apply unit damage inside the widened `_resolve_contacts`, the dedicated flat field read
      inline (CONSTRAINT C) (AC 2, `4-3a/R8`)
- [ ] Gate step 5's `_generate_mana` so a unit-target confirmation contributes no mana (AC 5)
- [ ] Add the GATHER-time same-slot identity filter (`_gather_contact_facts`) so a hero's hitbox
      does not confirm against that slot's own units (AC 6, `4-3a/R21b`)
- [ ] Implement death: a unit reaching `hp <= 0` becomes inert at a stable index — no compaction,
      no shift to any other record's index; a hole is never reused by `UnitBoard.add()` (AC 7,
      `4-3a/R9`) — seat inside `advance()`, immediately after damage is applied in the contact
      step (`4-3a/R21a`, a claim to be MEASURED against the step-1b round-over freeze)
- [ ] Add a live/unit test pinning that a summon following a death lands at a NEW index, never in
      the dead unit's hole (AC 7, `4-3a/R9`)
- [ ] Teach the retarget loop (`TargetingService`'s candidate scan seat) and the approach loop
      (`match_runner.gd`'s DRIVE phase) to skip a dead unit's index — the two named liveness seats
      (AC 7, AC 8, `4-3a/R14`)
- [ ] Change `TargetingService.target_for`/`reason_for` to take an `Array[int]` of living indices
      in place of `opposing_unit_count: int`; correct the file's docstring claiming a unit is
      always a living candidate (AC 8, `4-3a/R15`)
- [ ] On death, `queue_free()` the unit's actor and leave a HOLE in the runner's per-slot actor
      array so indices stay aligned with the record (AC 11, `4-3a/R13`)
- [ ] Bump `FORMAT_VERSION` to 3 in `record_file.gd` — the widened contact-fact target changes the
      recorded payload's shape (`4-3a/R10`); no migration path, `record_file`'s refusal-with-reason
      is the design. Search the tree for a committed recording fixture; if one exists, re-record
      it, if none exists, note that in Dev Notes.
- [ ] Extend `to_snapshot()`/the golden fixture for `hp` and for the hole-representation key —
      `hp` is snapshotted (AC 9, `4-3a/R17`)
- [ ] Write a live integration test driving two-plus units at the same acquired target
      simultaneously, measuring MOVEMENT and CONVERGENCE on the same `[slot, index]` pair in
      addition to no jitter/wedging/pass-through, tolerances derived at runtime from authored
      balance — discharges the `4-3/R21` deferred-work item (AC 10, `4-3a/R18`)
- [ ] Golden measured in both directions with two separately named causes (the `hp` key; the
      widened dedupe key shape); snapshot key set measured (AC 9) — see Golden Prediction
- [ ] Correct the two citation drifts: `unit_board.gd` is 147 lines, not 143;
      `_generate_mana` runs to the passive rung (`match_state.gd:733-750`), not to line 739
      (`4-3a/R21c`)

## Dev Notes

- **Read before touching, `src/state/unit_board.gd`**: two parallel `Array[int]` today
  (`_target_slots`, `_target_indices`), no hp, no type/kind field. `add()` takes no argument;
  `clear()` empties both arrays together on debug reset only, never round end. `targets_snapshot()`
  is the existing `[slot, index]` pair precedent this story's contact-fact widening reuses.
- **Read before touching, `src/state/match_state.gd`**: `push_contact` (429-444, Invariant-checked
  slots and non-zero direction), `_resolve_contacts` (665-708, the hero-shaped ladder: DEAD target
  drop, DEAD attacker drop, iframe drop, dedupe via `register_swing_hit`, block/deflect branch,
  `take_damage`, `hit_landed` signal, confirmed-attacker list for step 5), `_generate_mana`
  (733-750, reads the `confirmed_hits` list `_resolve_contacts` returns and runs through the
  step-5 PASSIVE mana rung — corrected from the pre-gate citation of 733-739, `4-3a/R21c`).
- **Read before touching, `src/main/match_runner.gd`**: `_gather_contact_facts` (807-844) queries
  `actor.hitbox.get_overlapping_areas()`, filters self-overlap, resolves the owning actor via
  `_slot_of` (847-852, returns -1 for anything that is not `_p1_hero`/`_p2_hero` — this is the
  function this story must extend, not replace, since heroes must keep resolving exactly as
  today), computes the target-to-attacker direction, and calls `_recorder.capture_push_contact`
  before `push_contact` (the record/replay tap, `3-0c` AC 9 — both calls must stay paired).
- **Read before touching, `src/actors/hero/hero.tscn`**: Hitbox (`Area3D`, `collision_layer = 4`,
  `collision_mask = 2`) and Hurtbox (`Area3D`, `collision_layer = 2`, `collision_mask = 0`) at
  lines 73-89. The hitbox's mask (2) ALREADY sees layer 2 — the unit hurtbox is authored on that
  same layer (`4-3a/R11`), so this file is read-only reference, never edited by this story.
- **Read before touching, `src/actors/minions/unit_actor.gd` / `unit_actor.tscn`**: `4-3` shipped
  `CharacterBody3D` + one body `CollisionShape3D` on the default layer/mask, deliberately with NO
  hurtbox and NO `Area3D` — "a unit takes no damage until 4-3a ships one" (the scene's own
  `editor_description`). This story is that consumer.
- **Read before touching, `src/state/hero_state.gd`**: the hp pattern to mirror — `_hp`/`_max_hp`
  private floats, `take_damage`/`heal`/`_set_hp` (clamps, no-ops on an unchanged value, pushes
  `hp_changed` through the SignalQueue), `is_alive()` as `_hp > 0.0`. A unit's hp field should
  follow this shape where it applies, adjusted for `UnitBoard` being a plain-array container
  rather than an object with its own signals (units have no per-record signal today).
- **`4-2/R2` (decision-log:6151)**: "The applied target is a HASHED INDEX PAIR, `[slot, index]`...
  both plain ints, `index >= 0` a board unit, `index == -1` that player's hero." This is the exact
  convention AC 3 extends to the contact fact's target field — read it before designing the
  widening so the two addressing schemes stay the same fact.
- **`4-0-hand-slot-stability`** is the hole-not-compaction precedent AC 7 cites: read that story's
  closing note (`sprint-status.yaml` story_notes) before choosing how a dead unit's record goes
  inert.
- **`FORMAT_VERSION` bumps to 3** (`4-3a/R10`). Searched the tree for a committed recording
  fixture (any `user://`-saved `RecordFile` output checked into the repo): NONE exists — recorded
  matches are saved under `user://`, which is not version-controlled, and no `.json`/binary
  fixture under `test/` or `data/` carries a `format_version` key. So there is nothing to
  re-record; this note exists so the dev pass does not re-derive that search.
- **`src/state/targeting/targeting_service.gd`** (`4-3a/R15`): fully static/stateless, the D6 pure
  evaluator sibling of `EconomyEvaluator`/`CastEvaluator`. `target_for`/`reason_for` currently take
  `opposing_hero_alive: bool, opposing_unit_count: int` and always resolve a unit-side pick to
  index 0 (`return [opposing_slot, 0]`); `REASON_NO_LIVING_CANDIDATE`'s docstring states "a unit
  is always a living candidate this story" — both are the exact gaps AC 8 closes.
- **`hit_landed` is NOT emitted for a unit target** (`4-3a/R12`, decided by Matko). The signal
  carries a slot only, and its shipped consumer flashes and stings the hero of that slot — so
  emitting it on a unit hit would flash an untouched hero whose hp did not change. The legible
  event this story ships is DEATH: the unit disappears (AC 11). Per-hit feedback on a damaged unit
  is deferred to `4-3b` (see Deferred / Out of scope) — the two rejected alternatives were
  widening the signal payload (same screen, more plumbing) and a real unit feedback channel (a new
  observation seam, which the locked count of seven `connect_*` seams makes an architecture
  amendment, not this story's to spend).

### Project Structure Notes

- `src/state/unit_board.gd`: new `hp` per-record array (or equivalent), death/inert predicate, hole
  never reused by `add()` (AC 1, 7, 8).
- `src/state/resources/balance_config.gd`: new unit-maximum-HP field AND a dedicated flat
  unit-damage field (AC 1, 2, `4-3a/R8`).
- `src/state/match_state.gd`: `push_contact` / `_resolve_contacts` widened for `[slot, index]`
  targets and the widened `[attack_index, slot, index]` dedupe key; mana gate; death handling seat
  (AC 2, 3, 5, 7, `4-3a/R16`).
- `src/main/match_runner.gd`: `_gather_contact_facts` identity resolution extended for unit
  hurtboxes; the same-slot friendly-fire filter (AC 4, 6, `4-3a/R21b`); the DRIVE-phase approach
  loop taught to skip a dead unit's index (AC 7, `4-3a/R14`); the per-slot actor array gains a
  `queue_free()`d hole on death (AC 11, `4-3a/R13`).
- `src/actors/minions/unit_actor.tscn`: new hurtbox `Area3D` on layer 2 "hurtbox" (AC 4,
  `4-3a/R11`).
- `src/state/targeting/targeting_service.gd`: `target_for`/`reason_for` take an `Array[int]` of
  living indices in place of `opposing_unit_count`; docstring correction (AC 8, `4-3a/R15`).
- `src/systems/record_file.gd`: `FORMAT_VERSION` 2 -> 3 (`4-3a/R10`).
- `test/state/test_balance_authoring.gd`, `test/state/test_data_resources.gd`: new field audits
  (AC 1, 2).
- `test/integration/`: new live test for AC 10 (two-plus units, one target, moved and converged,
  no jitter/wedging, `4-3a/R18`); new/extended test pinning that `UnitBoard.add()` never reuses a
  hole (AC 7, `4-3a/R9`).
- `test/state/test_determinism.gd`, `test/state/test_card_observation.gd`: golden and key-set
  measurement (AC 9, `4-3a/R17`).

**NOT in Project Structure Notes: `src/actors/hero/hero.tscn`, `project.godot`.** Both stay
byte-identical (`4-3a/R11`).

### Project Context Rules

- **F1 — one `_physics_process`, in the runner.** No new tick source; death/removal is decided
  inside `advance()`, never by a scene node. [Source: project-context.md; CLAUDE.md]
- **D3(b)/A2 — no physics query in `src/state/`.** The widened contact-fact target is still
  produced entirely from the runner's spatial query; `src/state/` continues to receive it as a
  pure-data fact and never queries physics itself. [Source: project-context.md]
- **CONSTRAINT C — read balance/injected values inline, never cache.** Both the unit maximum HP
  and any unit damage value follow the `_match_state.balance` / `_match_state.balance_ticks`
  reads already used throughout `match_state.gd`, never a cached copy. [Source: project-context.md]
- **HARD RULE — state/visual separation.** The unit hurtbox reports contact; it never applies
  damage. The state layer decides what a unit-target contact means, exactly as it already does for
  a hero target. [Source: project-context.md]
- **Data as Resources — no hardcoded gameplay numbers.** Unit maximum HP (and any unit damage
  value) is `.tres`-authored, not a literal in `match_state.gd`. [Source: project-context.md]
- **Collision layers (3D physics) convention** — RULED at the readiness gate: the unit hurtbox
  fits the EXISTING layer 2 "hurtbox", so no new layer is authored and `project.godot` is
  untouched (`4-3a/R11`). [Source: project-context.md:76-81]

### References

- [Source: decision-log.md Session 2026-08-10 "4-3a scope split", `4-3a/R1`-`R7`]
- [Source: decision-log.md Session 2026-08-10 "4-2 close-out", `4-2/R2`, `4-2/R3`, `4-2/R17(c)`]
- [Source: docs/implementation-artifacts/4-3-minion-approach-and-collision.md — Open Question 4,
  AC 4/8, Deferred/Out of scope, `4-3/R17`, `4-3/R21`]
- [Source: docs/implementation-artifacts/deferred-work.md — "Unit-vs-unit body collision is
  unmeasured" (`4-3/R21` finding 1); "`approach()` does not distinguish..." item, owner 4-3b]
- [Source: docs/implementation-artifacts/4-0-hand-slot-stability.md — hole-not-compaction
  precedent]
- [Source: decision-log.md Session 2026-08-10 "4-3a readiness gate", `4-3a/R8`-`R21`]
- [Source: src/state/unit_board.gd:1-147 (`4-3a/R21c`, corrected from the pre-gate citation of
  1-143)]
- [Source: src/state/match_state.gd:429-444 (push_contact), 665-708 (_resolve_contacts), 733-750
  (_generate_mana, `4-3a/R21c`, corrected from the pre-gate citation of 733-739)]
- [Source: src/state/targeting/targeting_service.gd (`4-3a/R15`)]
- [Source: src/systems/record_file.gd (FORMAT_VERSION, `4-3a/R10`)]
- [Source: src/main/match_runner.gd:807-852 (_gather_contact_facts, _slot_of)]
- [Source: src/actors/hero/hero.tscn:73-89 (Hitbox/Hurtbox)]
- [Source: src/actors/minions/unit_actor.gd; src/actors/minions/unit_actor.tscn]
- [Source: src/state/hero_state.gd:113-178, 381-392 (hp pattern)]
- [Source: docs/project-context.md:39, 55-57, 76-81 (F1, D3/A2, collision layers)]
- [Source: test/state/test_determinism.gd:379 (GOLDEN); test/state/test_card_observation.gd
  (snapshot key set, eleven)]

## Golden Prediction

**Predicted MOVER, both directions, with TWO SEPARATELY NAMED CAUSES** (`4-3a/R17`, closing the
Open Question about how a hole is represented in the snapshot). This is a positive prediction, not
a regression check (contrast `4-3/R12`'s demoted AC 6, which had nothing to move because position
stayed actor-owned). The two causes:

1. **The unit `hp` key.** `hp` goes into the snapshot — a value that crosses ticks and decides an
   outcome does not sit outside the hash, the same reasoning the dedupe record's own docstring
   gives for why mid-swing dedupe state is snapshotted. `hp` initializing away from zero at
   `add()` alone is enough to change `UnitBoard`'s snapshot content.
2. **The widened dedupe key shape**, `attack_index` alone -> `[attack_index, slot, index]`
   (`4-3a/R16`) — that dedupe record is itself snapshotted, so widening its key is a SECOND golden
   cause, independent of whether any unit is ever damaged inside the golden's own fixture.

**The golden fixture is NOT extended to injure a unit** — that would be a third cause and is out
of scope for this story's re-baseline. Both causes above are measured in both directions, ONE
re-baseline, the same discipline `4-3`'s sibling stories have followed every time the golden
actually moves (e.g. `3-4`'s one-named-cause re-baseline, `3-5a`'s three-separately-measured-causes
re-baseline).

`FORMAT_VERSION` **moves from 2 to 3** (`4-3a/R10`) — REVERSED from this story's original
authoring-pass prediction that it would stay 2. The contact fact is on the replay tap
(`capture_push_contact` in the runner, the positional four-element array the recorder appends, the
fixed-position rebuild in `record_file`), so widening the target field changes the recorded
payload's SHAPE, even though no new capture channel joins `IntentRecorder` and `push_contact`
remains the sole intake per 1-8. `record_file` refuses a mismatched version outright with a reason
and carries no migration path, and that refusal is the design (`4-1` precedent) — so no shim is
written. The dev pass must confirm `intent_recorder.gd`'s reflective `_resource_values()` and the
record/replay identity test still pass unchanged (the channel SET is unchanged, only the
`push_contact` payload's shape moves), on the `4-3/R19/N4` replay-safety precedent. No committed
recording fixture exists in the tree to re-record (see Dev Notes).

BEFORE, for this authoring pass: `GOLDEN := "73a86005f1f2c069306ed6504be9c99d109e7b96014f05b502224f658209d1b5"`
(`test/state/test_determinism.gd:379`, unmoved since 4-2 and confirmed unmoved again by 4-3).
Snapshot key set BEFORE: eleven (`test_card_observation.gd`). Suite BEFORE: 445 state tests / 3464
assertions, 0 failed, plus 27 integration files, all PASS (measured at 4-3's close-out, `bash
test/run_all.sh`) — the dev pass re-measures this itself rather than trusting the figure carried
here.

## Live Smoke

**REQUIRED**, Tier A default. `R-D6` is **NOT** spent by this story (`4-3a/R7`): the live smoke is
"P1 summons, P2's hero kills it", and the shipped default `slot_controller_kinds` is already
`[0,1]` — two live killable human slots, per `2-3` — so no temporary flip is required to exercise a
real kill. Same reasoning as `4-3/R14`. `R-D6` stays AVAILABLE (last spent `4-2`'s smoke, carried
through `4-3` unspent) for `4-3b`, which ships unit-originated damage and has something new to
prove with it.

Script, at minimum, corrected per `4-3a/R12` (decided by Matko — `hit_landed` is NOT emitted for a
unit target, so this script must NOT claim a hero's attack "visibly reduces" a unit's HP; nothing
flashes or stings on the first two swings, at the authored 3.0 damage / 9.0 max): a cast summons a
unit; a hero lands three swings against it and nothing flashes or stings on the first two; the
third swing kills it and it is removed from the board; a hero cannot then walk into empty air
where the unit stood or attack a target that no longer exists; a kill against a unit generates no
mana; two units driven at the same target show no jitter or mutual pushing, and are observed to
converge on it (the discharged deferred-work item, AC 10).

## Review Findings

_Not yet run — story is `authored`, not `ready-for-dev`._

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 — authoring pass, 2026-08-10.

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Author | Change |
|---|---|---|
| 2026-08-10 | Claude Sonnet 5 | Story authored via `gds-create-story`, split from the boarded `4-3a-minion-combat` per `4-3a/R1`. Five Open Questions left unruled for the readiness gate; Golden Prediction states a positive mover claim with `FORMAT_VERSION` staying 2 as a claim to be measured. |
| 2026-08-10 | Claude Sonnet 5 | Readiness gate rulings `4-3a/R8`-`R21` applied: AC 2 names one damage implementation (dedicated flat field, `4-3a/R8`); AC 3 gains the widened dedupe key and a named regression pin (`4-3a/R16`/`R19`); AC 4 rewritten to close the layer question at layer 2, `hero.tscn`/`project.godot` byte-identical (`4-3a/R11`); AC 6 gains its gather-time-filter rationale (`4-3a/R21b`); AC 7 gains hole-never-reused and the two named liveness seats (`4-3a/R9`/`R14`); AC 8 gains the `TargetingService` array-of-living-indices contract (`4-3a/R15`); AC 10 gains a positive movement/convergence half (`4-3a/R18`); new AC 11 for actor freeing on death (`4-3a/R13`). All five Open Questions ruled (four closed, one narrowed to a measured claim, `4-3a/R21a`). Golden Prediction now a two-named-cause mover; `FORMAT_VERSION` reversed to a predicted 3 (`4-3a/R10`), no committed recording fixture found. Live Smoke script corrected to not claim per-hit visible feedback on a unit (`4-3a/R12`); the deferred per-hit-feedback item added, owner `4-3b`. Two citation drifts fixed (`4-3a/R21c`). Status promoted to `ready-for-dev`. |
