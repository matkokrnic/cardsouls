---
baseline_commit: dab229178985f9532b181224421ba086328fac9b
---

# Story 4.3a: Minion damage and death

Status: done

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
5. **CLOSED by `4-3a/R17`, corrected by `4-3a/R27`.** `hp` goes into the snapshot — a value that
   crosses ticks and decides an outcome does not sit outside the hash. See Golden Prediction: this
   is the ONE measured mover; the dedupe-key-shape cause originally predicted alongside it was
   falsified.

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

- [x] Add `hp: float` to `UnitBoard`'s per-record arrays, initialized at `add()` from the
      balance-authored unit maximum HP (AC 1)
- [x] Author the unit maximum-HP field (9.0 provisional) AND a dedicated flat unit-damage field
      (3.0 provisional) on `BalanceConfig` (`@export_group("Minions")` precedent), both audited
      `> 0` in `test_balance_authoring.gd`, both extend `E1_BALANCE_FIELDS` (AC 1, AC 2, `4-3a/R8`)
- [x] Widen the contact fact's target field to `[slot, index]` in `push_contact` and
      `_resolve_contacts`, preserving today's hero-vs-hero behaviour under the `[slot, -1]`
      convention (AC 3) — a unit-target branch/helper sharing the dead-attacker-drop and dedupe
      rungs, skipping iframe/deflect/block (AC 3, `4-3a/R20`)
- [x] Widen `register_swing_hit`'s per-attacker dedupe key from `attack_index` alone to
      `[attack_index, slot, index]`, so a cleaving swing produces one confirmation per target
      (AC 3, `4-3a/R16`)
- [x] Extend `_gather_contact_facts`'s identity resolution so a unit hurtbox resolves to
      `[slot, index]` instead of being dropped at the `_slot_of == -1` check. NO hero Hitbox or
      `project.godot`/`hero.tscn` edit — the unit hurtbox lands on the EXISTING layer 2 "hurtbox"
      (AC 4, `4-3a/R11`)
- [x] Add a unit hurtbox (`Area3D`, `collision_layer = 2`, `collision_mask = 0`) to
      `unit_actor.tscn`, mirroring `hero.tscn`'s Hurtbox node shape and its layer/mask discipline
      (AC 4, `4-3a/R11`)
- [x] Apply unit damage inside the widened `_resolve_contacts`, the dedicated flat field read
      inline (CONSTRAINT C) (AC 2, `4-3a/R8`)
- [x] Gate step 5's `_generate_mana` so a unit-target confirmation contributes no mana (AC 5)
- [x] Add the GATHER-time same-slot identity filter (`_gather_contact_facts`) so a hero's hitbox
      does not confirm against that slot's own units (AC 6, `4-3a/R21b`)
- [x] Implement death: a unit reaching `hp <= 0` becomes inert at a stable index — no compaction,
      no shift to any other record's index; a hole is never reused by `UnitBoard.add()` (AC 7,
      `4-3a/R9`) — seat inside `advance()`, immediately after damage is applied in the contact
      step (`4-3a/R21a`, a claim to be MEASURED against the step-1b round-over freeze)
- [x] Add a live/unit test pinning that a summon following a death lands at a NEW index, never in
      the dead unit's hole (AC 7, `4-3a/R9`)
- [x] Teach the retarget loop (`TargetingService`'s candidate scan seat) and the approach loop
      (`match_runner.gd`'s DRIVE phase) to skip a dead unit's index — the two named liveness seats
      (AC 7, AC 8, `4-3a/R14`)
- [x] Change `TargetingService.target_for`/`reason_for` to take an `Array[int]` of living indices
      in place of `opposing_unit_count: int`; correct the file's docstring claiming a unit is
      always a living candidate (AC 8, `4-3a/R15`)
- [x] On death, `queue_free()` the unit's actor and leave a HOLE in the runner's per-slot actor
      array so indices stay aligned with the record (AC 11, `4-3a/R13`)
- [x] Bump `FORMAT_VERSION` to 3 in `record_file.gd` — the widened contact-fact target changes the
      recorded payload's shape (`4-3a/R10`); no migration path, `record_file`'s refusal-with-reason
      is the design. Search the tree for a committed recording fixture; if one exists, re-record
      it, if none exists, note that in Dev Notes.
- [x] Extend `to_snapshot()`/the golden fixture for `hp` and for the hole-representation key —
      `hp` is snapshotted (AC 9, `4-3a/R17`)
- [x] Write a live integration test driving two-plus units at the same acquired target
      simultaneously, measuring MOVEMENT and CONVERGENCE on the same `[slot, index]` pair in
      addition to no jitter/wedging/pass-through, tolerances derived at runtime from authored
      balance — discharges the `4-3/R21` deferred-work item (AC 10, `4-3a/R18`)
- [x] Golden measured in both directions with two separately named causes (the `hp` key; the
      widened dedupe key shape); snapshot key set measured (AC 9) — see Golden Prediction
- [x] Correct the two citation drifts: `unit_board.gd` is 147 lines, not 143;
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

**MEASURED MOVER, ONE CAUSE** (`4-3a/R27`, correcting the authoring pass's `4-3a/R17` two-cause
prediction after the dev pass measured it). This is a positive prediction, not a regression check
(contrast `4-3/R12`'s demoted AC 6, which had nothing to move because position stayed
actor-owned). The one measured cause:

1. **The unit `hp` key.** `hp` goes into the snapshot — a value that crosses ticks and decides an
   outcome does not sit outside the hash, the same reasoning the dedupe record's own docstring
   gives for why mid-swing dedupe state is snapshotted. `hp` initializing away from zero at
   `add()` alone is enough to change `UnitBoard`'s snapshot content. Measured alone (other cause
   off): golden moves to `35c38c0e…`.

**FALSIFIED — the widened dedupe key shape was predicted as a second, independent golden cause**
(`attack_index` alone -> `[attack_index, slot, index]`, `4-3a/R16`) and was measured to move the
golden by exactly nothing (alone, with the `hp` key off: golden stays `73a86005…`, the unmoved
original). The mechanism was measured, not guessed: at the golden fixture's hash tick (t24) both
heroes' `swing_dedupe.records` dictionaries are empty — every record opened by the t5/t13/t19/t20
facts has passed its grace tick and been erased by then — so a widened key over an empty record
set has nothing to hash. The key's shape change IS proven, just not here: it is proven by
`test_contact_resolution.gd`'s mid-swing dedupe snapshot pin, which moved from `[1]` to
`[[1, -1]]`. See Dev Agent Record, "Golden — TWO CAUSES PREDICTED, ONE MEASURED AS A MOVER", for
the full four-row both-directions table.

**The golden fixture is NOT extended to injure a unit** — that would be a further cause and is out
of scope for this story's re-baseline. The measured cause above was confirmed in both directions,
ONE re-baseline, the same discipline `4-3`'s sibling stories have followed every time the golden
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

### R22 — the swing-dedupe hit list hashed an unpinned physics ordering (fixed)

**THE ONE WITH REAL WEIGHT.** `HeroState.register_swing_hit` (`src/state/hero_state.gd`) appends
each accepted target address to the swing's `hit` list in the order `_resolve_contacts` drains the
contact queue — which is the order `match_runner.gd`'s `_gather_contact_facts` happened to receive
addresses from `actor.hitbox.get_overlapping_areas()`, a physics query that pins no ordering. This
story is the first to let ONE swing append SEVERAL entries to that list (the cleave, AC 3,
`4-3a/R16`), and the list is snapshotted (`to_snapshot()`) and therefore hashed — so the hash now
depended on an unpinned physics ordering, a determinism hole the shipped golden fixture cannot see
because it never cleaves.

**Fix**: `register_swing_hit` now sorts `hit` on every insertion (`hit.sort()`, Godot 4's
element-wise `Array` comparison sorts `[slot, index]` pairs lexically for free), keeping the stored
hit list in CANONICAL ORDER by target address rather than arrival order. Sorting on insertion
(chosen over sorting at snapshot time) keeps the stored state itself canonical.

**Proof**: `test/state/test_unit_damage_and_death.gd::test_the_hit_list_is_canonically_ordered_regardless_of_fact_arrival_order`
feeds two `MatchState`s the identical set of three contact facts (two units + the enemy hero) in
FORWARD and REVERSE push order and asserts identical `hit` lists, identical `[[1,-1],[1,0],[1,1]]`
content, and identical `CanonicalHash.of(snapshot)`. Mutation-proven: file backed up to
`C:\Users\matko\AppData\Local\Temp\claude\C--dev-cardsouls\...\scratchpad\hero_state.gd.bak`
(SHA256 `e35f8489...` throughout) BEFORE removing the `hit.sort()` line — the mutated build turned
this one test red (`[XX] test_the_hit_list_is_canonically_ordered...`) and nothing else; restored
by copying the backup back, SHA256-verified equal after restore, never `git checkout --`.

**Golden measured in both directions, as a claim, not a fact**: with the fix in place, the shipped
`test_state_matches_golden` PASSES (unmoved) — hash unchanged. With the fix REMOVED (arrival-order
hit list, the pre-fix behaviour), `test_state_matches_golden` ALSO passes (unmoved) — 465 tests, 1
failed (only the new canonical-order test, which does not read the golden). So the golden is
UNMOVED in both directions, exactly as predicted: the golden fixture's own dedupe records are empty
at its hash tick (t24, per the story's own recorded Golden Prediction mechanism), so this ordering
change has nothing to hash there. NO re-baseline needed or performed.

### R23 — `is_alive_at`'s docstring cited an unreachable justification (fixed)

The docstring on `UnitBoard.is_alive_at` justified its lenient out-of-range read ("reads as NOT
ALIVE rather than tripping the bound") by citing a runner/board desync at the two named liveness
seats (`living_indices()` / the DRIVE-phase approach loop). Traced and found UNREACHABLE: spawn
resyncs the actor array's size against the board in the same tick, and both named seats already
bound their loop by a size/`has_index` check before ever calling `is_alive_at` —
`_approach_unit_actors` loops `actors.size()` and additionally guards `player.units.has_index(index)`
before the liveness check (`src/main/match_runner.gd:721-731`); `living_indices()` iterates the
board's own size. Neither can hand `is_alive_at` an out-of-range index. The REAL justification is
the contact-fact path: `MatchState._resolve_unit_contact`'s dead-target rung calls `is_alive_at` on
`fact["target_index"]`, an index sourced from a contact fact that can legitimately be stale or
malformed (pinned by
`test_a_fact_naming_a_nonexistent_index_is_dropped_not_a_crash`). Docstring corrected to cite that
caller instead.

### R24 — the duplicated dead-attacker check is accepted, not refactored (recorded)

The two-line dead-attacker check (`attacker.hero.action_state == HeroState.ActionState.DEAD`) is
duplicated between the hero ladder in `_resolve_contacts` (`src/state/match_state.gd`, ~line 724)
and the unit branch in `_resolve_unit_contact` (~line 793). ACCEPTED as-is: the short separate path
for a unit target was a deliberate ruling (`4-3a/R20`), and extracting a shared helper for one
two-line condition adds indirection to the most sensitive shipped code in the project. Both sites
now carry a comment recording this reasoning and the forward rule: a THIRD copy appearing in a
future story is the signal to replace the mechanism (e.g. a shared dead-attacker guard both ladders
call into), not to keep tightening this two-copy pattern.

### R25 — minion-blocked-by-own-summoner annotates the existing deferred-work item (recorded)

No new deferred-work item opened. `docs/implementation-artifacts/deferred-work.md`'s existing item
("`approach()` does not distinguish 'arrived' from 'physically obstructed'", owner
`4-3b-minion-attack-rhythm`) already covers this generically and has been ANNOTATED, not
duplicated, with the measured instance: writing `test_two_units_converge_live.gd` (AC 10), the
trailing unit's first run parked 6.82 units from its target, wedged against P1's own hero (which
stands at `(-3, 0)`, directly in the unit spawn lane) rather than against its sibling unit. The test
now relocates the hero off the lane as an explicit setup step so it scopes itself to unit-vs-unit
collision, per its own inline comment (`test_two_units_converge_live.gd:115-127`). The item stays
OPEN; the annotation is a measurement, not a discharge.

### R26 — false positive: the "malformed-target fallback" in `push_contact` (rejected)

**Claim reviewed**: that `push_contact`'s `var target_slot := target[0] if target.size() == 2 else
-1` (and the matching `target_index` line, `src/state/match_state.gd:448-449`) is a silent
malformed-target fallback — that a target array of the wrong size would be coerced to `[-1, -1]`
and waved through rather than rejected.

**Disproved against the actual invariant chain**: the line immediately above,
`Invariant.check(target.size() == 2, ...)` (`match_state.gd:446-447`), already runs and fails LOUDLY
(`push_error` + `assert`) for any `target.size() != 2`, before the ternary is ever evaluated — in
every debug and test build, which is every build this pipeline is ever exercised under
(`run_all.sh`'s headless harness never disables asserts), a malformed target array never reaches the
`else -1` branch at all; execution halts at the `Invariant.check` first. The ternary's false branch
is dead code under the same invariant discipline every other seam in this file trusts elsewhere. No
code change made; recorded here so a future review does not rediscover and re-litigate this same
non-defect.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 — authoring pass, 2026-08-10.
Claude Opus 5 (1M context) — dev pass, 2026-08-10, via `gds-dev-story`.

### Debug Log References

- Full suite run 1 of 2 (open): **445 state tests / 3464 assertions / 0 failed, + 27 integration
  files, ALL PASS** — exactly the figure the Golden Prediction carried, re-measured rather than
  trusted.
- Full suite run 2 of 2 (close): **464 state tests / 3617 assertions / 0 failed, + 29 integration
  files, ALL TESTS PASSED** (exit 0). Deltas: +19 state tests, +153 assertions, +2 integration
  files. NOTE: the run-2 log was captured through `tail -45`, so only the last 22 of the 29
  integration RESULT lines are in it; `run_all.sh` exits nonzero on ANY failure and exited 0, and
  its own `ALL TESTS PASSED` line is the authoritative verdict. `PROC/R1` honoured — the full suite ran
  EXACTLY twice.
- **Deviation, recorded rather than hidden**: `test/run_state_tests.gd` has no per-file filter, so
  a mutation proof against a STATE test runs the whole state harness (44 files, ~10 s) rather than
  one file. It never runs the full suite (the 27→29 integration files are excluded), so `PROC/R1`'s
  actual constraint holds; the granularity is the harness's, not a choice. Integration mutations
  DO run exactly one file (`--script res://test/integration/<file>.gd`).
- Baseline commit in the frontmatter is `dab2291` (the story-split commit) while the pass ran on
  `afa37c6` (the readiness-gate commit). The skill preserves an existing `baseline_commit` and does
  not overwrite it, so it was left as authored.
- **Review-ruling pass (2026-08-10), `4-3a/R22`-`R26` — golden re-measured, NOT re-baselined**: with
  `register_swing_hit`'s canonical-order fix (`4-3a/R22`) in place, an isolated state-harness run
  (465 tests, 0 failed, 3621 assertions) shows `test_state_matches_golden` PASSING against the
  unchanged `35c38c0e...` constant already in `test_determinism.gd` — the golden is UNMOVED. The
  reverse direction (fix removed, arrival-order hit list) was also measured, outside the file's
  permanent state, purely to attribute the non-move: same run shape, 465 tests / 1 failed (only the
  new canonical-order test itself, which asserts hash EQUALITY between two in-test matches rather
  than reading the golden), so the golden constant is unmoved there too. Both directions confirm the
  mechanism already on record for the widened dedupe key (Golden — TWO CAUSES PREDICTED section
  above): every `swing_dedupe` record has expired by the golden fixture's t24 hash tick, so an
  ordering change over an empty record set has nothing to hash. See Review Findings, R22, for the
  mutation proof and backup/restore discipline.

### Completion Notes List

#### Golden — TWO CAUSES PREDICTED, ONE MEASURED AS A MOVER

Measured in BOTH directions, each cause independently, BEFORE the single re-baseline. Every
non-golden test was green first (446 tests, 1 failed — the golden alone).

| unit `hp` key | widened dedupe key | hash | verdict |
|---|---|---|---|
| OFF | OFF | `73a86005…` | the ORIGINAL golden — the reverse direction |
| ON | OFF | `35c38c0e…` | cause 1 alone moves it |
| OFF | ON | `73a86005…` | **cause 2 alone moves NOTHING** |
| ON | ON | `35c38c0e…` | the re-baselined value |

- **BEFORE** `73a86005f1f2c069306ed6504be9c99d109e7b96014f05b502224f658209d1b5`
- **AFTER** `35c38c0ef8008258a5c7ee614487ff92ca825866681f53636f865b83659321b9`
- **Snapshot key set: ELEVEN → TWELVE** per player (the one new key is `unit_hp`). Both pins moved
  together — `test_card_observation.gd` and `test_draw_delay_and_reshuffle.gd`.

**THE STORY'S GOLDEN PREDICTION IS HALF FALSIFIED, and this is a measurement result, not a
judgement call.** Cause 2 (the widened `[attack_index, slot, index]` dedupe key) was predicted a
SECOND golden cause "independent of whether any unit is ever damaged inside the golden's own
fixture". It moves the golden by exactly nothing. The MECHANISM was measured rather than guessed: at
the golden's hash tick (t24) BOTH heroes' `swing_dedupe.records` dictionaries are **empty** — every
record opened by the t5/t13/t19/t20 facts has passed its grace tick and been erased — so a widened
key over an empty record set has nothing to hash. It would move a fixture that hashed MID-SWING, and
that is exactly where the shape change IS proven: `test_contact_resolution.gd`'s mid-swing dedupe
snapshot pin moved from `[1]` to `[[1, -1]]`.

The reverse direction is what makes the single cause attributable: with both causes off the file
hashed the original golden, so the widened `push_contact` target address, the `TargetingService`
array-of-living-indices signature, both liveness seats, unit damage, death, actor freeing and
`FORMAT_VERSION 3` are all MEASURED golden non-movers.

#### FORMAT_VERSION and the replay contract

- `FORMAT_VERSION` reads **3**.
- **The recorder's reflective `_resource_values()` needed NO change**, and the reason is structural:
  it serialises RESOURCES (balance, flags, costs, effects) and a contact fact is not one.
- **The replay identity test needed no behavioural change** — it passes unchanged. Its ONE edit is a
  classification: `unit_board._hp` is declared HASHED alongside its two index-aligned siblings, so
  `UNHASHED_CROSS_TICK_MEMBERS` stays at THREE. Without that line the file's own "unclassified state
  member" guard fails, which is the guard working.
- The channel SET is unchanged; `REQUIRED_KEYS` did not move. The recorded contact ROW grew from
  four positional elements to five (the pair flattened, every element still a scalar).
- **The bump had nothing pinning it before this pass** — `FORMAT_VERSION` could have been edited
  back to 2 with the whole suite green. `test_record_file.gd::test_the_format_version_and_the_
  widened_contact_row_move_together` now ties the version to the shape it exists for: a
  UNIT-addressed fact must round-trip as unit-addressed, with a HERO-addressed fact beside it so a
  blanket `-1` fails.

#### R-D6 is NOT spent

Nothing in this pass required flipping `slot_controller_kinds`, and it was not touched. The live
tests drive the shipped default `[0, 1]` and cast for both slots through the real Input Map.

#### `project.godot` and `hero.tscn`

`git diff -- project.godot src/actors/hero/hero.tscn` is **EMPTY**. The unit hurtbox went on the
EXISTING layer 2 (`4-3a/R11`), and mutation I1 proves that layer is load-bearing rather than
incidental. No new `.gd` file declares a `class_name`, so no editor class-cache scan was needed.

#### RED-GREEN ORDERING, reported honestly per AC

- **GENUINELY RED FIRST**: AC 1 / AC 2's authored-balance audits. The two audits were added to
  `test_data_resources.gd` and `test_balance_authoring.gd` BEFORE the `BalanceConfig` fields existed
  and were run failing (`assert_true failed (BalanceConfig has 'unit_max_hp')`, plus a `SCRIPT
  ERROR` that `run_all.sh` greps for independently).
- **RED PROVEN BY THE EXISTING SUITE, before any new test was written**: AC 3's regression pin, AC 9,
  and the two key-set pins. Widening the seam turned the shipped suite red in exactly six places
  (golden, both key-set pins, the mid-swing dedupe pin, the replay-identity classification pin, the
  board bound-guard count) and nowhere else — every one predicted, none a defect.
- **RETROACTIVELY RED, by mutation only**: everything else. `test_unit_damage_and_death.gd`, both
  live files and the `FORMAT_VERSION` pin were written AFTER the code they cover and passed on their
  first run. Their RED state exists only in the mutation table below. Stating this plainly because a
  test that has never been observed failing is a claim, not evidence — the table is the evidence.

#### A test weakness the mutation pass found and fixed

`test_a_dead_unit_is_not_addressable_by_a_later_swing` was **VACUOUS as first written** (mutation
M10 killed nothing). `apply_damage_at` CLAMPS at zero, so a corpse that wrongly RESOLVED the fact
still read `hp == 0.0` afterwards — the assertion could not tell "dropped" from "resolved for
nothing". It now asserts on the DEDUPE RECORD instead: the drop is PRE-dedupe, so a dropped fact must
not have consumed the swing's resolution against that address. M10 and M10b (which REORDERS the
rungs, putting dedupe ahead of the liveness checks) both kill it now — so `4-3a/R20`'s "identical
order of the shared rungs" requirement is guarded, not just asserted.

#### Open Question 4 (`4-3a/R21a`) — MEASURED, claim upheld

The story's claim that the step-1b round-over freeze precedes the contact step and so needs no
special case is **measured true**: a unit one hit from death, with a fact queued, survives the freeze
indefinitely, while the IDENTICAL fact on an unfrozen match kills it. Mutation M11 (hoisting
`_resolve_contacts()` into the freeze branch) kills the test.

#### AC 10 — a scope finding worth recording

The first run of `test_two_units_converge_live.gd` failed with the trailing unit parked **6.82** from
the target. It was not wedged on its sibling: it was wedged against **P1's own hero**, which stands
at (-3, 0), directly in the unit spawn lane. That is the shipped 4-3 approach behaviour this story's
own Non-Goals preserve ("`approach()` is NOT taught to distinguish 'arrived' from 'physically
blocked'" — owner `4-3b`), and AC 10 is UNIT-VS-UNIT body collision. The test now moves P1's hero off
the lane as a setup step, with that reasoning recorded in the file. With the lane clear both units
converge (1.46 / 2.08 against a derived bound of 3.30) and the measured minimum separation is
**0.681** against a pass-through floor of 0.6 — the two bodies genuinely touch and genuinely do not
overlap, so the deferred item is discharged against real contact rather than against two units that
never met.

### Mutation Proof Table

Every mutation: file copied OUTSIDE the repo first, restored by copying back (never `git checkout
--`), SHA256 verified equal to the backup after each restore — all 20 restores clean.

| # | AC | Mutation | Test that FAILED |
|---|---|---|---|
| M1 | 1 | cast seat passes `0.0` instead of `balance.unit_max_hp` | `test_a_summoned_unit_enters_at_the_authored_maximum`; `test_a_summon_following_a_death_lands_at_a_new_index…` |
| M2 | 2 | damage uses `attack_damage_percent_of_max_hp × unit_max_hp` (the rejected formula) | 4 tests incl. `test_a_hero_swing_takes_the_dedicated_flat_damage_off_a_unit` |
| M3 | 3 | dedupe key narrowed back to slot-only | `test_one_swing_cleaves_through_two_units_and_the_hero`; `test_swing_dedupe_tracking_is_snapshotted_mid_swing` |
| M4 | 3 | hero targets routed through the UNIT branch (regression pin) | **41 tests** across block/deflect, iframes, mana, contact, determinism, record, replay |
| M5 | 5 | unit confirmation leaks into the confirmed-hits list | 5 tests incl. the golden and two targeting seats |
| M6 | 7 | death COMPACTS the arrays instead of leaving a hole | `test_death_leaves_a_hole_at_a_stable_index_and_shifts_nothing` + 2 |
| M7 | 7 | `add()` fills the first hole (the `4-5` pooling regression) | `test_a_summon_following_a_death_lands_at_a_new_index…` + 2 |
| M8 | 8 | `target_for` returns the constant index `0` again | `test_the_evaluator_skips_a_hole…`; `test_the_step_7_seat_never_acquires_a_dead_unit` |
| M9 | 8 | step-7 seat passes ALL indices instead of living ones | `test_the_step_7_seat_never_acquires_a_dead_unit` |
| M10 | 8 | dead-target rung weakened to a bare bounds check | `test_a_dead_unit_is_not_addressable_by_a_later_swing` |
| M10b | 3 | rung ORDER changed — dedupe hoisted ahead of the liveness rungs | `test_a_dead_unit_is_not_addressable_by_a_later_swing` |
| M11 | 7 | `_resolve_contacts()` hoisted into the step-1b freeze branch | `test_the_round_over_freeze_precedes_the_contact_step…` |
| M12 | 1 | authored `unit_max_hp = 0.0` | `test_authored_minion_combat_values_are_positive` |
| M13 | 2 | authored `unit_damage_per_hit = 0.0` | `test_authored_minion_combat_values_are_positive` |
| I1 | 4 | unit Hurtbox moved off layer 2 (`collision_layer = 0`) | `test_unit_combat_live` — 12 swings, enemy never dies |
| I2 | 6 | gather-time same-slot friendly-fire filter deleted | `test_unit_combat_live` — the hero's OWN unit drops to 0.00 |
| I3 | 11 | `_free_dead_unit_actors` calls deleted | `test_unit_combat_live` — corpse's actor still in the tree |
| I4 | 10 | `_approach_unit_actors(0, …)` deleted | `test_two_units_converge_live` — `moved=false/false` |
| I5 | 10 | unit body `collision_layer/mask = 0` | `test_two_units_converge_live` — `min_sep=0.23` (pass-through) |
| F1 | 3 | `FORMAT_VERSION` reverted to 2 | `test_the_format_version_and_the_widened_contact_row_move_together` |
| F2 | 3 | replay rebuild defaults the target index to `-1` | same test — the unit-addressed row comes back as a hero hit |
| A | 9 | `unit_hp` key removed from the snapshot | golden reverts to `73a86005…`; both key-set pins fail |

### File List

**Production — state**
- `src/state/unit_board.gd` — `_hp` third parallel array; `add(max_hp)`; `hp_at`, `is_alive_at`,
  `apply_damage_at`, `living_indices`, `hp_snapshot`; `clear()` clears all three
- `src/state/hero_state.gd` — `register_swing_hit(index, target_slot, target_index)`; hit list holds
  target ADDRESSES
- `src/state/match_state.gd` — `push_contact` takes an `Array[int]` target pair; `_resolve_contacts`
  unit branch + `_resolve_unit_contact`; cast seat reads `balance.unit_max_hp`; step-7 seat passes
  living indices; `_generate_mana` docstring (AC 5's gate is upstream)
- `src/state/player_state.gd` — new `unit_hp` snapshot key
- `src/state/targeting/targeting_service.gd` — `target_for`/`reason_for` take `Array[int]` living
  indices; falsified docstring corrected; ascending-first LIVING index
- `src/state/resources/balance_config.gd` — `unit_max_hp`, `unit_damage_per_hit`

**Production — runner / systems / scene**
- `src/main/match_runner.gd` — `_address_of`; gather resolves unit hurtboxes; friendly-fire filter;
  `_free_dead_unit_actors` + its call seat; approach-loop liveness seat
- `src/systems/intent_recorder.gd` — pair-shaped `capture_push_contact`, five-element row,
  `replay_push_contacts` rebuild
- `src/systems/record_file.gd` — `FORMAT_VERSION` 2 → 3; five-element rebuild
- `src/actors/minions/unit_actor.tscn` — Hurtbox `Area3D` (layer 2 / mask 0) + HurtboxShape

**Data**
- `data/balance/balance_config.tres` — `unit_max_hp = 9.0`, `unit_damage_per_hit = 3.0`

**Tests — new**
- `test/state/test_unit_damage_and_death.gd`
- `test/integration/test_unit_combat_live.gd`
- `test/integration/test_two_units_converge_live.gd`

**Tests — modified**
- `test/state/test_determinism.gd` — golden re-baselined, both causes recorded
- `test/state/test_card_observation.gd`, `test/state/test_draw_delay_and_reshuffle.gd` — key set 11→12
- `test/state/test_contact_resolution.gd` — mid-swing dedupe pin now holds addresses
- `test/state/test_replay_identity.gd` — `unit_board._hp` classified HASHED
- `test/state/test_targeting_service.gd` — `_living()` helper, `LIVING_HP`, bound-guard count 4→6
- `test/state/test_minion_authoring.gd` — `_living()` helper
- `test/state/test_data_resources.gd`, `test/state/test_balance_authoring.gd` — the two new audits
- `test/state/test_record_file.gd` — the FORMAT_VERSION / row-shape pin
- `test/state/test_block_deflect.gd`, `test/state/test_contact_pipeline.gd`,
  `test/state/test_mana_economy.gd`, `test/state/test_roll_iframes.gd`,
  `test/integration/test_replay_entry_is_inert.gd`,
  `test/integration/test_replay_verifier_tool.gd` — 42 `push_contact` call sites widened to
  `[slot, -1]` (the AC 3 regression pin's broad half)

**Board**
- `docs/implementation-artifacts/sprint-status.yaml`

## Change Log

| Date | Author | Change |
|---|---|---|
| 2026-08-10 | Claude Sonnet 5 | Story authored via `gds-create-story`, split from the boarded `4-3a-minion-combat` per `4-3a/R1`. Five Open Questions left unruled for the readiness gate; Golden Prediction states a positive mover claim with `FORMAT_VERSION` staying 2 as a claim to be measured. |
| 2026-08-10 | Claude Sonnet 5 | Readiness gate rulings `4-3a/R8`-`R21` applied: AC 2 names one damage implementation (dedicated flat field, `4-3a/R8`); AC 3 gains the widened dedupe key and a named regression pin (`4-3a/R16`/`R19`); AC 4 rewritten to close the layer question at layer 2, `hero.tscn`/`project.godot` byte-identical (`4-3a/R11`); AC 6 gains its gather-time-filter rationale (`4-3a/R21b`); AC 7 gains hole-never-reused and the two named liveness seats (`4-3a/R9`/`R14`); AC 8 gains the `TargetingService` array-of-living-indices contract (`4-3a/R15`); AC 10 gains a positive movement/convergence half (`4-3a/R18`); new AC 11 for actor freeing on death (`4-3a/R13`). All five Open Questions ruled (four closed, one narrowed to a measured claim, `4-3a/R21a`). Golden Prediction now a two-named-cause mover; `FORMAT_VERSION` reversed to a predicted 3 (`4-3a/R10`), no committed recording fixture found. Live Smoke script corrected to not claim per-hit visible feedback on a unit (`4-3a/R12`); the deferred per-hit-feedback item added, owner `4-3b`. Two citation drifts fixed (`4-3a/R21c`). Status promoted to `ready-for-dev`. |
| 2026-08-10 | Claude Opus 5 (1M context) | DEV PASS via `gds-dev-story`. All 11 ACs shipped; 19/19 tasks complete. Golden RE-BASELINED ONCE, `73a86005` -> `35c38c0e`, snapshot key set ELEVEN -> TWELVE (`unit_hp`). Both predicted causes measured independently and in both directions: the `hp` key is the ONLY mover; the widened dedupe key shape MEASURED A NON-MOVER (at the golden's hash tick every `swing_dedupe` record has expired and been erased), so the Golden Prediction's cause 2 is FALSIFIED as a golden claim and is proven instead by the mid-swing dedupe pin. `FORMAT_VERSION` 2 -> 3, and newly PINNED to the row shape it exists for (nothing guarded it before). `_resource_values()` and the replay identity test needed no behavioural change; the latter's one edit classifies `unit_board._hp` as HASHED. Open Question 4 (`4-3a/R21a`) MEASURED and upheld. `project.godot` and `hero.tscn` byte-identical; `R-D6` NOT spent. Suite 445/3464 + 27 -> 464/3617 + 29, all green. 22 mutations, 22 kills, all restores SHA-verified; one test found VACUOUS by mutation (M10) and repaired. Three new test files. |
