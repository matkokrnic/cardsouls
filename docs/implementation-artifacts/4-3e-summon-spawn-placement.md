---
baseline_commit: d3854ff12656b9f4c1a378519bc83ca282c0c090
---

# Story 4.3e: Summon spawn placement

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want a card that summons a unit to place it behind my own hero, on the side away from my
opponent, rather than in a scene-authored row that ignores where I actually am,
so that summoning reads as an action *I* took at *my* position, and I can never be denied a
summon just because a spot is occupied.

## Acceptance Criteria

1. **Placement is hero-relative, not scene-relative.** A summoned unit (minion or totem) appears
   BEHIND the summoning hero, on the side away from the opponent, at the hero's position AT CAST
   TIME — not at a fixed scene coordinate authored once in `main.tscn`. (Owner ruling.)

   **"BEHIND" WINS OVER PROXIMITY, AND THE PROPERTY HOLDS OF THE *ACCEPTED* CANDIDATE, NOT MERELY
   OF THE BASE SPOT. (Owner ruling, fourth gate.)** The outward search of AC 2 is CONSTRAINED TO
   THE REAR HALF-SPACE: every candidate it may accept lies on the far side of the summoning hero
   from the opponent, measured against the hero-to-opponent direction AT CAST TIME. A ring is
   therefore a rear ARC, not a full circle. A summoned unit NEVER appears between the summoning
   hero and the opponent, however crowded the rear is — when the near candidates are occupied the
   unit lands FURTHER BEHIND, never in front. Without this clause the search could clear an
   occupant by stepping around it and land the unit in the fighting space, which is exactly what
   this AC exists to forbid; it is also what makes Live Smoke point 1's "BEHIND the hero relative
   to P2" a judgement about a stated requirement rather than about an accident of the search order.

   **THE DEGENERATE DIRECTION HAS A DEFINED ANSWER, AND IT IS A REQUIREMENT, NOT LATITUDE (owner
   ruling, fifth gate.)** When the hero-to-opponent direction is too short to be reliable — the case
   AC 3 explicitly blesses, a hero summoning while standing on the opponent — the rear arc's axis is
   the SLOT'S FIXED AWAY-FROM-CENTRE AXIS: P1 places toward -x, P2 toward +x. This is the axis for
   the base spot AND for the arc, not merely for the base spot; before this ruling the fallback lived
   only in Implementation Latitude, predated the rear-arc clause, and left this AC with no defined
   meaning in exactly the case AC 3 blesses.
2. **The card is never rejected for want of space, and the outward search is UNBOUNDED IN CANDIDATE
   COUNT — it terminates because THE LIVE UNITS ARE FINITE.** If the computed spot is occupied,
   keep walking outward until a free candidate is found; the first free candidate wins and the walk
   stops there. There is no fixed candidate budget and no "use the last one anyway" early exit —
   that shape was an error introduced upstream of this story, not an owner ruling, and it is
   dropped.

   **TERMINATION IS BY FINITENESS PLUS AN UNBOUNDED RADIUS — AND THE SECOND HALF IS A REQUIREMENT
   ON THE SEARCH, NOT A CONSEQUENCE OF THE FIRST. (Owner ruling, third gate.)** Finiteness alone
   does NOT terminate the walk: a sequence that densifies inside a bounded region visits infinitely
   many candidates without ever leaving the occupied neighbourhood. So the candidate sequence MUST
   have the radius property below, and it is an acceptance criterion, not latitude. A sequence that
   densifies within a bounded region is FORBIDDEN.

   **THE RADIUS RULE IS PER RING, NOT PER CANDIDATE. (Owner ruling, fourth gate — the third gate's
   wording said the radius strictly increases per candidate, which forbade the very ring the story
   elsewhere mandates, since a ring by definition holds several candidates at one radius.)** The
   sequence is organised into RINGS. Each ring holds FINITELY MANY candidates at the SAME radius
   from the base spot, visited in a FIXED DETERMINISTIC ORDER. The radius is NON-DECREASING within
   a ring and STRICTLY INCREASES BETWEEN RINGS by a FIXED POSITIVE STEP (a compile-time constant,
   never adaptive and never shrinking), without bound. Each ring is a REAR ARC, not a full circle
   (AC 1).

   **The termination argument, unchanged in substance:** the radius grows without bound between
   rings, and the occupants (both heroes plus the live unit actors of both slots — see AC 3) are
   finitely many and each occupies a bounded neighbourhood; therefore some ring at a finite radius
   is entirely free, and the walk halts at or before it, in finitely many steps — each ring being
   finite, only finitely many candidates are visited before that ring is reached. The rear-arc
   constraint does not affect this: a rear arc at a large enough radius is still eventually free.
   There is NO fallback branch and NO candidate cap to fall back on, which is exactly why the radius
   property is mandatory: without it, this loop runs inside the runner's `_physics_process` seat
   forever.

   **THE ARENA BOUND IS OUT OF THIS AC ENTIRELY**: an earlier draft used
   "every candidate must lie in [-20, 20]" as the termination device, which was upstream error and
   the wrong device. There is NO arena test, NO [-20, 20] check, NO skipping of out-of-arena
   candidates, and NO "every candidate is occupied" fallback — that branch is unreachable by
   construction and is deleted along with the interpenetration outcome it used to name. The arena
   measurement survives in Dev Notes as context ONLY; it does not bound placement. There is no path
   where the card resolves and no unit appears.
3. **No minimum distance from the opponent.** A player may run up to the opponent and summon
   there deliberately; this story adds no proximity restriction of any kind. (Owner ruling.)

   **BOTH HEROES COUNT AS OCCUPANTS FOR THE SEARCH. (Owner ruling, third gate.)** The occupancy
   list the caller builds carries BOTH heroes' positions alongside the live unit actors of both
   slots — because this AC blesses summoning while standing on the opponent, which is precisely the
   case where "behind me" lands inside a body, and heroes are `CharacterBody3D` on the SAME default
   layer 1 as units (`unit_actor.tscn`'s `Collision` editor_description), so an unclear candidate is
   a real interpenetration. The consequence, and it is not a refusal: summoning in the opponent's
   face STILL RESOLVES — the unit simply appears FURTHER BEHIND the summoning hero, because the
   search steps clear of the opponent's body before it accepts a candidate, and AC 1's rear-arc
   constraint means it steps BACKWARD to do so, never around into the fighting space. This is what
   backs Live Smoke point
   1's "does not pop into view inside the hero's own body"; it is an AC now, not an unstated
   expectation.
4. **Several units from one card cluster at one spot — and N>1 IS UNREACHABLE THROUGH PLAY AT
   `d3854ff`.** When a growth batch contains more than one unit, they land clustered at their own
   spot near the hero, not distributed individually around the hero. A small in-cluster separation
   keeps them from overlapping/colliding into each other, but they read as one group, not a
   scatter. (Owner ruling.)

   **EVERY CLUSTER MEMBER IS CLEARED, NOT JUST THE FIRST. (Owner ruling, fourth gate.)** The helper
   places members ONE AT A TIME, and each member's position must clear EVERY occupant in the
   caller's list (AC 3) AND every member of the SAME BATCH already placed in this call. The
   third gate's shape (one searched base spot, members offset
   from it blind) would have placed every member after the first inside a hero or a live unit, the
   exact interpenetration AC 3's occupancy ruling exists to prevent. For N=1 this is precisely the
   behaviour already specified, unchanged.

   **STATED PLAINLY, BECAUSE THE MEASUREMENT SAYS SO: no card in the shipped game can produce a
   batch of more than one.** Summon resolution is a single unconditional `player.units.add(...)`
   per resolved cast (`match_state.gd:1428`), and a player commits at most one card per tick —
   `_resolve_card_action` consumes one `intent.card_commit` / `intent.card_slot`
   (`match_state.gd:1329-1344`). Two casts resolved on the same tick are therefore necessarily
   two DIFFERENT SLOTS, and the runner calls `_spawn_missing_unit_actors` once per slot
   (`match_runner.gd:1410-1411`), so a single batch never mixes them. The growth batch is always
   exactly one unit today.

   **THIS AC STAYS ANYWAY, and the owner's reason is forward compatibility: cards that summon
   several minions are planned, so the batch loop must be WRITTEN for N now rather than migrated
   later.** It has NO TEST, and the fifth gate says so plainly rather than inventing one: there is
   no gameplay path that reaches N>1, so correctness for N>1 is carried by REVIEW. A synthetic N=3
   test stood here until this gate and is DELETED along with the cluster mechanics it was invented
   to check — this story does not specify, guard or gate behaviour that nothing at `d3854ff` can
   execute.
5. **Facing is untouched.** This story authors no heading for a fresh unit. Minions still acquire
   a target on the next 4-2 aim-poll tick; totems (once they exist, 4-4) fire 360°. A fresh unit
   keeps whatever heading it spawns with today (see `match_runner.gd:722`). No change to
   `_aim_unit_actors` or any facing computation. (Owner ruling.)
6. **The TWO stale comments are corrected.**

   (a) `match_runner.gd:142-145` (the whole comment block; both stale claims sit on line 145)
   claims "no gameplay reads it" (false since 4-3: contact facts and
   the reach probe are computed from actor positions, so the distance from the row to the hero
   decides how long a minion runs before its first strike) and "4-3 replaces it with real
   placement" (false: 4-3 did not touch spawn placement; these constants have been the only spawn
   placement since 4-1). Replace the comment with an accurate one describing this story's
   hero-relative scheme.

   (b) `src/state/unit_board.gd:303` says "the locked count of seven `connect_*` seams is
   untouched". EIGHT is current and has been since `3-6/R2`: `test_architecture_invariants.gd:285-288`
   lists eight names and line 291 is `func test_runner_observation_seams_are_exactly_eight()`,
   with the `2-6/R7` -> `3-6/R2` amendment history recorded at lines 267-283. That sentence was
   written by 4-3a, one amendment behind, and it is the SAME CLASS OF DEFECT as (a) — a stale
   citation living in shipped code. It is a one-word correction (`seven` -> `eight`) and it is the
   ONLY edit this story makes under `src/state/`. **RECONCILED AGAINST WHAT AC 7 ACTUALLY SAYS**
   (an earlier draft quoted AC 7 as forbidding "no `src/state/` change" — AC 7 contains no such
   clause): AC 7's three clauses are NO POSITION FIELD on `UnitBoard`, NO NEW `connect_*` SEAM, and
   THE DEAD-UNIT HOLE UNTOUCHED. A one-word comment correction adds no field, adds no seam and
   touches no hole, so it satisfies all three literally, not by interpretation. It is also invisible
   to every guard: `test_architecture_invariants.gd`'s `src/state/` scanners strip comments at the
   first `#` before scanning (stated in that file's own header), and the golden and snapshot key set
   cannot see a comment.

7. **`_spawn_missing_unit_actors`'s only reader relationship is preserved**: `UnitBoard` stays a
   positionless count (no position field added to `src/state/`), no new `connect_*` observation
   seam is added (the family stays at eight), and the dead-unit HOLE at a stable index (`4-3a/R13`)
   is untouched — a freed slot's index is never reused by a later spawn or by the placement search.

8. **The spawn Y is GROUND-DERIVED and stays at ground level. It is NEVER taken from the hero's
   Y.** "Behind the hero" is a PLANAR relationship (X/Z) and nothing about it is vertical. The two
   roots do not agree on what Y means: the HERO root is the body CENTRE, authored at y 1
   (`main.tscn:30,34` — `P1Hero` at `(-3, 1, 0)`, `P2Hero` at `(3, 1, 0)`), while the UNIT root is
   the body's FEET, which is why the runner spawns units at y 0 today
   (`match_runner.gd:655-656`'s literal `0.0`, and `unit_actor.tscn`'s `Collision`
   editor_description states it in as many words: "the runner spawns units at y 0"). A dev pass
   that implements AC 1 literally — offset the hero's whole `global_position` backwards and assign
   it — spawns every minion 1.0 m in the air, which is the exact floating defect
   `test/integration/test_unit_vertical_alignment.gd` exists to catch.

   **"GROUND-DERIVED" MEANS THE GROUND-LEVEL CONSTANT THE RUNNER ALREADY USES — the literal `0.0`
   at `match_runner.gd:656` — NOT a raycast and NOT any physics query. (Owner ruling, third gate.)**
   A ground query inside the placement helper would put a physics read into a routine AC 9 requires
   to be a pure function of its arguments, and no guard under `src/main/` would catch it. The Y is
   that constant; only X/Z are computed.

   The vertical cross-check
   against `main.tscn`'s actual ground surface stays ALIVE through this story (see Task 1 and the
   impacted-tests note in Dev Notes) — it must not be weakened or deleted to accommodate the new
   placement.

9. **Placement is a PURE FUNCTION of (THE OCCUPIED POSITIONS, this hero's position, the opposing
   hero's position, slot, BATCH SIZE), RETURNING AN ORDERED LIST OF N POSITIONS — ONE CALL PER
   BATCH, NOT ONE PER MEMBER (fourth gate: this headline said "batch index", contradicting Task 1's
   signature; batch size is the ruling) — and this AC replaces the story's
   previously-deferred open
   question.** The occupancy list is an EXPLICIT ARGUMENT, not something the routine goes and
   fetches (third gate: the earlier headline omitted it while the search plainly depended on it,
   which made "same inputs, same output" unfalsifiable). The CALLER — inside
   `_spawn_missing_unit_actors` — builds that list; the helper reads no scene tree and holds no
   node reference. The gate's
   ruling: making placement depend on the hero's `global_position` is ACCEPTABLE AS-IS and needs
   no mitigation, because hero position is ALREADY the only unhashed geometric input gameplay
   reads — `test_architecture_invariants.gd:318-324` records exactly that ("blocking changes hero
   NODE positions, those positions are the sole geometric input to the runner's
   `_gather_contact_facts`, and the DERIVED facts enter through `push_contact`"), and
   `_target_world_position` (`match_runner.gd:919-927`), the reach probe and the approach loop all
   already sit on it. A replay reproduces those positions not because they are recorded but
   because identical intents through identical deterministic physics from an identical authored
   scene produce them. Spawn placement JOINS that existing chain; it opens no new class of
   divergence.

   That property only holds if placement is written a particular way, which is why this is an AC
   and not a latitude note. The placement computation must have: **no RNG (`randf`/`randi`/any
   seeded generator), no `Time`/`OS`/`Engine` read, no frame counter, no dependence on scene-tree
   iteration order, and NO DEPENDENCE ON THE ORDER of the occupancy list** — the same set of
   occupied positions in a different order must produce the same spot. **`null` HOLES NEVER REACH
   THE HELPER AT ALL**: the caller filters them with `is_instance_valid()` while building the list,
   so a hole is not an occupant by construction rather than by the helper remembering to ignore
   one. It runs at the EXISTING
   post-`advance()` seat inside the runner's `ticking` gate (`match_runner.gd:1410-1411`), never
   anywhere else. Same inputs, same spot, every run.

   **ITS GUARD, AND THE RESIDUAL GAP — NAMED, in the same style AC 7 uses for its own** (Task 5):
   the placement helper is called TWICE with identical arguments and the returned positions must be
   byte-identical, and called again with the SAME OCCUPANCY SET IN A DIFFERENT ORDER, which must
   return the same result. **BE HONEST ABOUT WHAT GUARD (ii) IS (fourth gate): it is a CHEAP
   REGRESSION PIN against a positionally-indexed occupancy read, not a strong property test.** The
   natural implementation — for each candidate, test min-distance against every entry of the list
   and accept the first that clears them all — is a CONJUNCTION OVER THE WHOLE LIST, and a
   conjunction is order-independent BY CONSTRUCTION, so this pin will normally pass on the first
   try. It only bites if someone later reads `occupied[0]`, breaks out of the occupancy loop early
   and uses the survivor, or otherwise lets array position matter. It replaces the
   hole-rearrangement assertion because holes no longer reach the helper (the caller filters them),
   which makes arrival ORDER the only remaining thing that could vary between two runs. Both are
   EFFECTS (two measured position lists compared), not identifiers. **WHAT THAT
   DOES NOT COVER:** the machine check for
   `randf`/`randi`/`Time`/`OS`/`Engine` reads is D3(b)/A2, and it scans `src/state/` ONLY —
   `match_runner.gd` lives in `src/main/` and is NOT scanned by it. A `randf()` added to this
   placement code trips NO guard; the repeat-call assertion would only catch it probabilistically,
   and a `Time`/frame-counter read would very likely slip past it entirely (both calls sit in one
   frame). Nothing anywhere in this story may count that assertion as broader coverage than this
   paragraph grants it. The rest of AC 9's
   purity list is therefore held by CODE REVIEW, not by a test, and this story says so rather than
   implying the guard is complete.

   **REJECTED MITIGATIONS, recorded so they are not re-proposed:** (i) hashing spawn position into
   `to_snapshot()` — it would put actor-owned geometry into hashed state and reverse `4-2/R14`'s
   deferral of position ownership; (ii) adding a position field to `UnitBoard` — it reverses the
   very positionless clause AC 7 exists to preserve, and `unit_board.gd:33-39` names three separate
   rulings keeping that record empty. Neither is taken. The gap between "replay reproduces the
   match" and "replay re-derives each landing spot from recorded state" is ACCEPTED AND NAMED here
   rather than closed.

## Non-Goals (explicitly out of scope)

- Per-kind spawn-data conversion (priority types, totem subtypes) — that is 4-4's job.
- Projectiles, and any totem behaviour of any kind.
- Any change to facing/heading computation (see AC 5).
- Any minimum-distance-from-opponent rule (see AC 3).
- Object pooling of unit actors (4-5, gated on its own fps criterion).
- **KEEPING ANYTHING INSIDE THE ARENA — INCLUDING THE HERO. A PRE-EXISTING GAP WITH NO OWNER, and
  this story neither fixes it nor pretends it is not there.** Measured at this gate: `hero.gd`
  drives the hero with `velocity = hero_state.velocity` then `move_and_slide()`
  (`hero.gd:32,48`) and there is NO positional clamp, NO arena bound, NO killplane and NO respawn
  anywhere — grepped for `clamp`, `bound`, `killplane`/`kill_plane`, `fall`, `respawn` across
  `src/actors/hero/hero.gd` and `src/main/match_runner.gd`, zero relevant hits. And `src/main/main.tscn`
  is 58 lines carrying exactly ONE `StaticBody3D` (`Ground`, `:19`) and ONE `CollisionShape3D`
  (`GroundCollision`, `:21`) — **there is no wall geometry in the scene at all**. So a hero can walk
  off the floor today, and because placement is hero-relative (AC 1), a hero standing off the floor
  gets its summon placed off the floor WITH IT. That is the consequence of the existing gap, not a
  defect this story introduces, and closing it (walls, a clamp, or a respawn) belongs to whoever
  owns arena bounds — nobody, today.

## Tasks / Subtasks

- [ ] Task 1 — Replace the frozen row constants with a hero-relative spawn scheme (AC 1, 6)
  - [ ] **EXTRACT A DIRECTLY-CALLABLE PLACEMENT HELPER — REQUIRED, NOT OPTIONAL (AC 4, AC 9).** The
        base-spot computation, the outward search (Task 2) and the in-batch cluster offset
        (Task 3) live in ONE private helper method on `MatchRunner` taking
        `(the occupied positions, this hero's position, the opposing hero's position, slot,
        batch size)` and RETURNING AN ORDERED LIST OF N POSITIONS — ONE CALL PER BATCH, NOT ONE PER
        MEMBER — it must not read the scene tree, hold a node
        reference, spawn anything, or mutate `_unit_actors`; the caller inside
        `_spawn_missing_unit_actors` does the instancing and the assignment. This is
        a required seam, not a style choice: AC 9's two purity
        assertions and Task 1's preferred measured-Y assertion CALL it, and neither can be
        written against three inline lines (`match_runner.gd:652-657` today).
  - [ ] **THE CALLER BUILDS THE OCCUPANCY LIST (AC 3, AC 9 — third gate).** Inside
        `_spawn_missing_unit_actors`, walk `_unit_actors` for BOTH slots with the same
        `is_instance_valid()` guard every other loop uses, take each live actor's
        `global_position`, and add BOTH heroes' positions (`_p1_hero`/`_p2_hero`, the
        `_target_world_position` accessor pattern). That plain array of positions is what the
        helper receives. Two consequences the earlier draft could not state: `null` holes never
        reach the helper at all, and the helper stays a pure function of its arguments with no
        scene-tree read of its own — which is what makes AC 9's two assertions writable.
  - [ ] Remove `UNIT_ROW_X`, `UNIT_ROW_SPACING`, `UNIT_ROW_Z_START` from `match_runner.gd:146-148`
        (or repurpose the surviving ones — e.g. an offset-behind-hero distance and a cluster
        separation distance — but they must no longer encode an absolute per-slot X coordinate).
  - [ ] At the point `_spawn_missing_unit_actors` currently runs (`match_runner.gd:1410-1411`,
        right after `advance()`), compute each slot's "behind hero, away from opponent" base spot
        from `_p1_hero`/`_p2_hero`'s *live* `global_position` (the same accessor pattern already
        used by `_target_world_position`, `match_runner.gd:919-927` — no new seam needed) and the
        opposing hero's position for that slot.
  - [ ] The spawn Y is GROUND-DERIVED and stays at ground level (AC 8) — the hero's `.y` is read
        for NOTHING. Only the hero's X/Z participate in "behind". **"Ground-derived" is the
        ground-level CONSTANT the runner already uses (`match_runner.gd:656`'s literal `0.0`), not
        a raycast and not any physics query** — a ground query inside the helper would break AC 9's
        purity and no `src/main/` guard would catch it.
  - [ ] Rewrite the `match_runner.gd:142-145` comment block to describe the new scheme and why
        gameplay (contact facts, the reach probe) reads the result of this placement.
  - [ ] **RE-AUTHOR `test/integration/test_unit_vertical_alignment.gd` (AC 8 / impacted test).**
        Its `_parse_spawn_ground_y()` scans `match_runner.gd` for the literal source string
        `"unit.global_position = Vector3(UNIT_ROW_X[slot],"` (line 63) and fails LOUDLY via
        `quit(1)` when the source no longer matches (lines 56-77, 140-147). Removing the constants
        turns it RED. PREFER REPLACING THE SOURCE PARSE WITH A REAL MEASURED-Y ASSERTION — spawn a
        unit through the runner (or call the placement routine) and measure the resulting
        `global_position.y` against `main.tscn`'s ground top — rather than porting the parse to a
        new magic string. A source-string parse is itself failure mode (a): it asserts the SHAPE OF
        A LINE, not the height a unit actually stands at, and it sits in shipped code today.
        Checks (1), (3) and (4) in that file are unrelated to placement and stay as they are.
  - [ ] Fix the one-word stale seam count at `src/state/unit_board.gd:303` (AC 6(b)): `seven` ->
        `eight`. Comment only — no behaviour, no signature, no field.
- [ ] Task 2 — Deterministic outward search for a free spot: UNBOUNDED IN CANDIDATES, TERMINATING
      BY FINITENESS (AC 2, 9)
  - [ ] Given a candidate base spot, walk a deterministically-ordered outward sequence of RINGS
        with NO fixed candidate budget, until a candidate is far enough from EVERY OCCUPIED
        POSITION IN THE LIST THE CALLER HANDED IN — the live unit actors of BOTH slots AND BOTH
        HEROES (AC 3) — and from every batch member already placed in this call (AC 4) — to not
        overlap on spawn. The FIRST free candidate wins and the walk stops.
  - [ ] **THE RADIUS PROPERTY IS A REQUIREMENT, AND IT IS WHAT MAKES THE WALK TERMINATE — AND IT IS
        PER RING, NOT PER CANDIDATE (AC 2, fourth gate).** The sequence is organised into RINGS:
        each ring holds FINITELY MANY candidates at the SAME radius from the base spot, visited in
        a FIXED DETERMINISTIC ORDER; the radius is NON-DECREASING WITHIN a ring and STRICTLY
        INCREASES BETWEEN rings by a FIXED POSITIVE STEP (a constant — never adaptive, never
        shrinking), without bound. A
        sequence that densifies within a bounded region is FORBIDDEN: it would visit infinitely many
        candidates without leaving the occupied neighbourhood, and with no cap and no fallback that
        is an infinite loop inside `_physics_process`. Termination argument: radius grows without
        bound between rings + finitely many occupants, each with a bounded neighbourhood => some
        ring is entirely free => the walk halts in finitely many steps, each ring being finite.
  - [ ] **EVERY CANDIDATE LIES IN THE REAR HALF-SPACE (AC 1, owner ruling, fourth gate).** A ring is
        a rear ARC, not a full circle: candidates on the opponent's side of the summoning hero,
        measured against the hero-to-opponent direction at cast time, are never offered and never
        accepted. A crowded rear pushes the unit FURTHER BEHIND, never in front. Termination is
        unaffected — a rear arc at a large enough radius is still eventually free.
  - [ ] **The offset-behind distance MUST EXCEED the occupancy clearance radius**, so the base spot
        is never inside the summoning hero's own clearance and the first candidate is not
        systematically rejected. Both numbers are the dev pass's to choose (Implementation
        Latitude); this relation between them is not.
  - [ ] **No arena test, no `[-20, 20]` check, no out-of-arena skip, no "everything is occupied"
        fallback branch.** Termination comes from the bullet above, not from a bound. Writing an
        unreachable fallback branch here is writing dead code — do not add one, and do not add a
        candidate-count cap "just in case".
  - [ ] The whole computation obeys AC 9's purity list: no RNG, no `Time`/`OS`/`Engine`, no frame
        counter, no scene-tree iteration order, and no dependence on the ORDER of the occupancy
        list (holes never reach the helper — the caller filters them, Task 1).
- [ ] Task 3 — Cluster same-batch units, separate them from each other (AC 4)
  - [ ] `_spawn_missing_unit_actors` is called once per tick with the slot's new total count
        (`match_runner.gd:650-657`); treat the growth batch it adds in one call (`actors.size()` at
        entry up to `count`) as ONE cluster sharing one searched base spot, placing members near it
        with a small per-member separation so they don't spawn stacked.
  - [ ] **EVERY MEMBER IS CLEARED, NOT JUST THE FIRST (AC 4, owner ruling, fourth gate).** Members
        are placed ONE AT A TIME, and each member's position must clear EVERY occupant in the
        caller's list AND every member of the same batch already placed in this call — run the same
        rear-arc ring search (Task 2) for each. Offsetting
        members from one searched spot blind would drop members 2..N inside a hero or a live unit.
        For N=1 this is exactly the behaviour Task 2 already specifies.
  - [ ] **The batch is exactly one unit in every reachable case at `d3854ff`** (AC 4's measurement:
        `match_state.gd:1428`, `match_state.gd:1329-1344`, `match_runner.gd:1410-1411`). Write the
        loop for N anyway — that is this task's whole content — and do NOT write a comment claiming
        several casts can share a batch today.
  - [ ] A later cast (a later tick, hero having possibly moved) must NOT read this batch's base
        spot — recompute the base spot fresh from the hero's current position every call.
- [ ] Task 4 — Preserve existing invariants (AC 7)
  - [ ] No position field added to `UnitBoard` or any `src/state/` type — position stays
        actor/runner-owned exactly as today.
  - [ ] No new `connect_*` method on `MatchRunner` — `test_runner_observation_seams_are_exactly_eight`
        (`test/state/test_architecture_invariants.gd:291`) must still pass unmodified.
  - [ ] The dead-unit hole convention (`4-3a/R13`, `match_runner.gd:660-693`) is untouched: a
        `null` at a freed index is never treated as "occupied" by the new search, and the search
        never assigns a freed index to a new unit (spawning is still purely additive — the
        `while actors.size() < count` shape at `match_runner.gd:652` stays the growth mechanism).
- [ ] Task 5 — Tests
  - [ ] A live integration test (pattern: `test/integration/test_unit_*_live.gd`) proving: a unit
        summoned from a hero standing at a non-origin, non-default-facing position spawns behind
        that hero on the side away from the opponent, not at the old fixed row coordinate.
  - [ ] A test proving the outward search: pre-occupy the computed base spot (and its immediate
        ring) with existing actors, summon again, and assert the new unit lands at a free
        candidate rather than overlapping — and that a cast is never silently dropped for want of
        space.
  - [ ] **THE AC 9 PURITY GUARD (two assertions, both effects).** (i) Call the placement helper
        TWICE with identical arguments and assert the returned positions are byte-identical. (ii)
        Call it with the SAME OCCUPANCY SET IN A DIFFERENT ORDER and assert the same result. **(ii)
        IS A CHEAP REGRESSION PIN, NOT A STRONG TEST, and its docstring must say so:** the natural
        implementation tests each candidate against every entry of the list — a conjunction over the
        whole list, order-independent BY CONSTRUCTION — so this pin normally passes on the first try.
        It exists to catch a LATER positionally-indexed occupancy read (`occupied[0]`, an early
        break out of the occupancy loop), not to prove anything about today's code.
        (`null` holes are not tested here and cannot be: the caller filters them
        while building the list, so they never reach the helper — Task 1.) AC 9 records what these
        two DO NOT cover (the D3(b)/A2 scan never reaches `src/main/`, so the rest of the purity
        list is review-held, and assertion (i) catches a `Time`/frame-counter read barely if at
        all); do not write a comment or docstring claiming this pair proves purity outright.
  - [ ] **NO TEST FOR N>1 (AC 4, fifth gate).** The batch loop is written for N, and there is no
        test for N>1 because no gameplay path reaches it (`match_state.gd:1428`,
        `match_state.gd:1329-1344`, `match_runner.gd:1410-1411`) — correctness for N>1 is carried
        by REVIEW, and this story says so rather than pretending otherwise.
  - [ ] **RE-MEASURE `test/integration/test_two_units_converge_live.gd` (impacted test).** Lines
        113-127 teleport P1's hero to `z = 8.0` specifically to get it OUT of the spawn lane
        ("units spawn in a row at z -2.1 / -0.7 and walk +x toward P2's hero; P1's hero stands at
        (-3, 0) — directly in that lane"), and its comment carries a MEASURED number (the trailing
        unit parking 6.82 from the target). Hero-relative placement INVERTS that setup: the units
        now spawn behind the hero at z ≈ 8, i.e. exactly where the teleport moved the hero to be
        alone. Re-derive the setup and re-measure every number in that file; do not assume the
        teleport is still needed, and do not leave a stale measured figure in the comment.
        (Checked at the gate: it is the only integration test that repositions a HERO before
        summoning. `test_unit_corpse_walkthrough_live.gd:209,228` repositions UNIT actors
        explicitly after spawn and is unaffected.)
  - [ ] Re-run `test_runner_observation_seams_are_exactly_eight`
        (`test/state/test_architecture_invariants.gd:291`) — unmodified — and the SNAPSHOT KEY-SET
        assertion in `test/state/test_card_observation.gd`, which is what actually guards AC 7's
        positionless clause (`test_determinism.gd:25`: "The key set moves TEN -> ELEVEN here,
        pinned by test_card_observation.gd"). NOTE THE RESIDUAL GAP: the key-set guard catches a
        new SNAPSHOTTED key; a private unhashed field on `UnitBoard` would slip past it, so AC 7's
        first clause is partly held by review. There is no `Vector3`-in-`src/state/` scan and no
        `test_unit_board.gd` — the earlier phrase "the `UnitBoard` positionless-count guards"
        named nothing that exists.
  - [ ] Full suite before/after per project convention (`test/run_all.sh`). See ## Golden
        Prediction below for what the golden can and cannot tell you here.

## Dev Notes

**What exists today (measured, cite these — do not re-derive from memory):**

- `match_runner.gd:146-148` — `const UNIT_ROW_X: Array[float] = [-5.5, 5.5]`,
  `UNIT_ROW_SPACING := 1.4`, `UNIT_ROW_Z_START := -2.1`. **THEY HAVE TWO READERS, NOT ONE.** The
  runtime reader is `_spawn_missing_unit_actors` (`match_runner.gd:650-657`). The SECOND reader is
  a TEST: `test/integration/test_unit_vertical_alignment.gd:63` scans the runner's source for the
  literal string `"unit.global_position = Vector3(UNIT_ROW_X[slot],"` in order to parse the spawn-Y
  literal off the following line, and appends a failure plus `quit(1)` when it does not match
  (lines 56-77, 140-147). Deleting or reformatting that statement turns that integration test red.
  Task 1 carries re-authoring it.

- **THE ARENA, MEASURED** (`src/main/main.tscn`): the `Ground` `StaticBody3D` sits at the scene
  origin with no transform (line 19); its `GroundCollision` `CollisionShape3D` is offset
  `(0, -0.5, 0)` (line 22) and carries `SubResource("BoxShape3D_jqarl")`, authored at
  `size = Vector3(40, 1, 40)` (lines 7-8). So the floor is 40 x 40 centred on the origin with its
  TOP SURFACE at y 0 (centre -0.5 plus half of height 1), giving a walkable extent of
  x in [-20, 20] and z in [-20, 20]. **THIS IS CONTEXT, NOT A BOUND ON PLACEMENT** — AC 2 no longer
  tests it and the search never consults it (the arena-as-termination-device was upstream error;
  termination is by finiteness). What the measurement IS still load-bearing for is the y 0 that
  AC 8's ground-derived spawn height agrees with, and for knowing how far the floor actually
  reaches. **There is no wall geometry in `main.tscn` at all** — 58 lines, one `StaticBody3D`, one
  `CollisionShape3D` — which, with no hero clamp anywhere, is the pre-existing gap named in
  Non-Goals: nothing keeps a hero on the floor, so nothing keeps a hero-relative summon on it
  either. Not this story's job, and not papered over.
- The spawn loop only GROWS: `while actors.size() < count: ... unit.global_position =
  Vector3(UNIT_ROW_X[slot], 0.0, UNIT_ROW_Z_START + UNIT_ROW_SPACING * actors.size())`. A unit
  that dies never has its row slot reused — the loop places by `actors.size()` at spawn time, and
  the dead-unit hole (`4-3a/R13`) leaves a `null` behind rather than shifting anything.
- `src/main/main.tscn:29-34` — `P1Hero` at `(-3, 1, 0)`, `P2Hero` at `(3, 1, 0)`. **2.5 IS THE X
  DIFFERENCE ONLY, NOT THE SPAWN DISTANCE** (an earlier draft of this story said "exactly 2.5 m
  behind", which is not what the constants produce). `UNIT_ROW_X[0]` is -5.5 against P1's hero x
  -3, so the X difference is 2.5 — but the row also carries a Z offset, so the actual PLANAR
  distances from P1's hero to the two row positions are:
  - first unit, at `(-5.5, 0, -2.1)`: `sqrt(2.5^2 + 2.1^2)` = `sqrt(6.25 + 4.41)` = `sqrt(10.66)`
    ≈ **3.27**
  - second unit, at `(-5.5, 0, -0.7)` (`Z_START -2.1` + `SPACING 1.4`): `sqrt(2.5^2 + 0.7^2)` =
    `sqrt(6.25 + 0.49)` = `sqrt(6.74)` ≈ **2.60**

  These are the FIRST and SECOND unit of ONE slot's row, not two per-slot values — the same pair of
  distances applies mirrored to P2. If the dev pass wants a starting value for "distance behind
  hero", 2.5 is the X component of the old scheme, and ~2.6-3.3 is what a player actually saw.
  The row was never hero-relative, just close enough to look that way while heroes stood still;
  heroes move freely (camera-relative movement, story 1-2), so the row and the hero drift apart the
  moment either hero moves.
- `match_runner.gd:919-927` (`_target_world_position`) already resolves `_p1_hero`/
  `_p2_hero.global_position` for the contact pipeline and the aim/approach polls. Reading a
  hero's position needs no new seam — reuse this pattern, do not add one.
- `match_runner.gd:650-657` is called from `match_runner.gd:1410-1411`, once per tick right after
  `advance()`, with each slot's CURRENT `UnitBoard` size. This call site is inside the runner's
  `ticking` gate (3-0b's deterministic step/pause), same seat as the existing spawn poll and the
  `_free_dead_unit_actors` poll immediately after it.
- `match_runner.gd:142-145` (comment; both stale claims sit on line 145) is stale in two ways this story must correct: it claims "no
  gameplay reads it" — false since 4-3, because contact facts and the reach probe are computed
  from actor positions, so the distance between spawn spot and hero decides how long a minion
  runs before its first strike; and it claims "4-3 replaces it with real placement" — false, 4-3
  did not touch spawn placement; these constants have been the only placement mechanism since 4-1.
- **THE GROWTH BATCH IS ALWAYS EXACTLY ONE UNIT AT `d3854ff`** — measured at the gate, and AC 4
  restates it: `match_state.gd:1422-1428` performs one unconditional `player.units.add(...)` per
  resolved cast; `_resolve_card_action` (`match_state.gd:1329-1344`) consumes a single
  `intent.card_commit`/`intent.card_slot` per player per `advance()`; and two same-tick casts are
  necessarily two different slots, which the runner spawns through two separate calls
  (`match_runner.gd:1410-1411`). No batch mixes casts. Any comment or test asserting otherwise is
  asserting something the code cannot do.
- **THE SECOND IMPACTED TEST: `test/integration/test_two_units_converge_live.gd:113-127`.** It
  teleports P1's hero to `z = 8.0` deliberately, to leave the spawn lane, and records the reason
  and a measured figure in its own comment. Hero-relative placement moves the lane ONTO the
  teleported hero, so the setup and every derived number in that file need re-measuring. Task 5
  carries it.
- `src/actors/minions/unit_actor.tscn` — root is a `CharacterBody3D` with a `0.6 x 1.2 x 0.6` body
  box offset `+0.6` in y, and its `Collision` editor_description states the reason: "the unit ROOT
  is at the box's FEET (the runner spawns units at y 0), unlike the hero root which is its body
  CENTRE". No layer/mask lines — units sit on default layer 1 with heroes. This is the geometry
  behind AC 8 (ground-derived Y), and it is what the search's "occupied" radius has to clear: a
  candidate closer than roughly one body width to an occupant — a live unit actor OR either hero
  (AC 3) — is an overlap, and nothing separates two interpenetrating character bodies on its own. **AC 2 no longer names an overlap OUTCOME** —
  with no bound and finite units the walk always reaches a free candidate, so the overlapping
  placement that outcome described cannot occur.

**Design already locked (do not re-litigate — implement as given):**

- Behind the hero, away from the opponent, at cast time (AC 1).
- Never reject a cast for lack of space (AC 2).
- No minimum distance from the opponent (AC 3).
- Multiple units from one card cluster together (AC 4), carried for the planned multi-summon cards
  even though N>1 is unreachable through play today — and EVERY member is cleared against the
  occupants and against the members already placed in the same call, not just the first.
- "Behind" wins over proximity: the search is confined to the REAR HALF-SPACE, so a summoned unit
  never appears between the summoning hero and the opponent, however crowded the rear is (AC 1).
- No facing change (AC 5).
- The spawn Y is ground-derived, never the hero's Y (AC 8).
- Both heroes count as occupants for the search, and a summon in the opponent's face still resolves
  (AC 3).
- Placement is a pure function of (the occupied positions, this hero's position, the opposing hero's
  position, slot, BATCH SIZE), returning an ORDERED LIST OF N POSITIONS — one call per batch, not
  one per member (AC 9); the replay gap is accepted and named, not mitigated.

**Implementation latitude (yours to decide — these are HOW, not WHAT):**

- The PATTERN of the outward search — **RING OR SPIRAL ONLY** (a grid was listed here and is
  WITHDRAWN at the third gate: a grid enumeration need not have an unbounded increasing radius,
  which AC 2 requires) — the number of candidates per ring and their order within it, the step size,
  and the exact separation radius used to decide "occupied." What is NOT latitude any more: the
  candidate count is UNBOUNDED; the radius is NON-DECREASING WITHIN A RING and STRICTLY INCREASES
  BETWEEN RINGS by a FIXED POSITIVE STEP, so the step size is free to choose but must be a constant,
  never adaptive (fourth gate: the per-CANDIDATE wording the third gate used forbade the ring this
  bullet mandates); each ring is a REAR ARC, never a full circle (AC 1);
  termination follows from that PLUS the finiteness of the
  occupants (AC 2) — no arena test, no candidate cap, no fallback branch — and there is no RNG
  anywhere in it (AC 9): this file has no RNG and must not gain one, and no guard would catch it if
  it did. The offset-behind distance must EXCEED the occupancy radius (AC 1 / Task 2) — the two
  numbers are yours, that relation is not.
- Where the surviving constants live and what they're called, now that they're no longer an
  absolute row (e.g. "distance behind hero," "cluster member separation," "search step size").
  They can stay as `const` in `match_runner.gd` — nothing requires moving them into a `.tres`;
  this is placement geometry, not balance data.
- The threshold below which the hero-to-opponent direction counts as "too short to be reliable"
  (AC 1). What happens past it is NOT latitude any more — the fifth gate promoted the fallback into
  AC 1 as a requirement: the arc's axis is the slot's fixed away-from-centre axis, P1 toward -x,
  P2 toward +x.

**RULED AT THE READINESS GATE (was an open question; now AC 9 — do not re-open):**

Spawn placement now depends on the hero's `global_position`, which is actor-owned, lives in the
runner (not `src/state/`) and is **not** part of hashed `MatchState`. **Ruling: ACCEPTABLE AS-IS,
no mitigation, with the purity constraint promoted to AC 9.**

The reasoning, measured rather than asserted: hero position is ALREADY the only unhashed geometric
input that gameplay reads. `test/state/test_architecture_invariants.gd:318-324` states it directly
— "blocking changes hero NODE positions, those positions are the sole geometric input to the
runner's `_gather_contact_facts`, and the DERIVED facts enter through `push_contact`" — and
`_target_world_position` (`match_runner.gd:919-927`), the reach probe and the approach loop all
already sit on that same value. A replay reproduces those positions not because they are recorded
but because identical intents through identical deterministic physics from an identical authored
scene produce them. Spawn placement joins that existing chain; it opens no NEW class of divergence,
which is why the answer is a constraint on HOW placement is written (AC 9's purity list) rather
than a change to what is recorded. Rejected mitigations and their reasons are recorded in AC 9.

**CORRECTION TO AN EARLIER DRAFT OF THIS PARAGRAPH:** it called the hashed-`MatchState` boundary
"the F1 boundary, guarded by `test_single_physics_process_owner`". That is a mislabel. **F1 is the
single-`_physics_process`-owner invariant** and has nothing to do with what is hashed — see
`CLAUDE.md`'s invariant list and `test/state/test_architecture_invariants.gd:9`
(`func test_single_physics_process_owner() -> void:  # INVARIANT F1`). The test name is real; the
attribution was not. What actually holds the hashed boundary is `to_snapshot()`'s key set and the
golden, not F1. This story's Project Context Rules section below uses F1 correctly.

### Project Structure Notes

- **The only PRODUCTION-CODE change is `src/main/match_runner.gd`, plus one COMMENT under
  `src/state/` and two EXISTING TEST FILES** (an earlier draft opened "all changes are confined to
  `src/main/match_runner.gd`" and then contradicted itself three lines later — the full edit set is
  the three bullets here). The runner already owns unit spawn placement (`4-1/R12`, cited in the
  very comment this story corrects). No new file is required: the placement helper Task 1 REQUIRES
  is a private method on `MatchRunner`, not a new class — extracting it is mandatory (AC 4 and
  AC 9's guards call it directly), but where it lives is settled: runner-owned, same file.
- **ONE `src/state/` edit, and it is a COMMENT**: the `seven` -> `eight` correction at
  `src/state/unit_board.gd:303` (AC 6(b)). No field, no signature, no behaviour — the golden and
  the snapshot key set cannot see it. Nothing else under `src/state/` is touched.
- No `src/actors/` scene changes (the actor scene and its hitbox/hurtbox layout are untouched —
  only where the runner places an instantiated actor changes).
- **TWO EXISTING TESTS ARE EDITED, not just re-run**: `test/integration/test_unit_vertical_alignment.gd`
  (its source-string parse dies with the constants — Task 1) and
  `test/integration/test_two_units_converge_live.gd` (its spawn-lane setup inverts — Task 5).
- New tests go under `test/integration/` (this needs the live hero/unit actor scene graph), named
  on the existing `test_unit_*_live.gd` convention (see `test_unit_swing_root_live.gd`,
  `test_unit_strike_alignment_live.gd`, `test_unit_corpse_linger_live.gd` for the pattern). AC 9's
  two purity assertions are the exception: they call the helper directly and need no live scene
  graph.

### Project Context Rules

- **F1 / no new `_physics_process`**: all new logic runs inside the runner's existing
  `_physics_process`, called from the existing post-`advance()` seat — do not add a second tick
  driver.
- **D3(b)/A2 (no nondeterministic source in `src/state/`)**: not directly engaged since this code
  lives in `src/main/`, but do not introduce `randf()`/`randi()` anywhere in the new search —
  keep it a deterministic function of the occupied positions, hero position, opponent position,
  slot and batch size.
- **Actors are instanced with `PackedScene.instantiate()` and freed with `queue_free()`** (never
  `free()`) — unchanged by this story, just don't regress it while touching
  `_spawn_missing_unit_actors`.
- **No per-frame allocations in hot paths** (project-context Performance Rules): the search runs
  once per tick per slot only when the count actually grew (the `while` loop's own guard), not
  every frame regardless — keep it that way; don't turn the search into an always-on per-frame
  scan.
- **Signals/HUD**: nothing here is HUD-observable data — no signal work needed.
- **Commit discipline**: docs and code never share a commit; commit messages pure ASCII via
  `git commit -F <tempfile outside the repo>`; trailer `Co-Authored-By: Claude Opus 4.8
  <noreply@anthropic.com>` regardless of which model actually implements it.

### References

- [Source: src/main/match_runner.gd#L142-L148] (stale comment block L142-L145 + constants L146-L148)
- [Source: src/main/match_runner.gd#L648-L657] (`_spawn_missing_unit_actors`)
- [Source: src/main/match_runner.gd#L919-L927] (`_target_world_position`, hero-position read
  pattern to reuse)
- [Source: src/main/match_runner.gd#L1396-L1411] (call site, tick seat)
- [Source: src/main/main.tscn#L29-L34] (P1Hero/P2Hero authored coordinates)
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md#E4] (E4 scope: "Wire
  Basic-mode summons to real actors")
- [Source: docs/implementation-artifacts/4-3d-minion-strike-alignment-and-corpse-lifecycle.md]
  (previous story in this chain — corpse lifecycle; no direct dependency, but establishes the
  `_unit_actors` hole/liveness conventions this story must not disturb)
- [Source: docs/project-context.md#Code-Organization-Rules] (folder ownership: `src/main/` owns
  the runner; `src/state/` stays positionless)
- [Source: src/main/main.tscn#L7-L8, #L19-L23] (the arena: `BoxShape3D_jqarl` `size = Vector3(40, 1, 40)`,
  `Ground` at origin, `GroundCollision` offset `(0, -0.5, 0)` -> floor top y 0, x/z in [-20, 20] —
  CONTEXT ONLY; placement does not test it)
- [Source: src/actors/hero/hero.gd#L32, #L48] (`velocity = hero_state.velocity` + `move_and_slide()`
  — the whole of hero movement; no clamp, no arena bound, no killplane, no respawn: the Non-Goals
  gap)
- [Source: src/actors/minions/unit_actor.tscn] (`CharacterBody3D` root at the body's FEET, "the
  runner spawns units at y 0", default layer 1, no mask lines)
- [Source: src/state/match_state.gd#L1422-L1428] (one `units.add()` per resolved cast)
- [Source: src/state/match_state.gd#L1329-L1344] (one `card_commit` per player per tick)
- [Source: src/state/unit_board.gd#L146-L163] (`add()` — the one way a unit enters, entering with
  the no-target pair)
- [Source: src/state/unit_board.gd#L303] (the stale "seven `connect_*` seams", AC 6(b))
- [Source: test/state/test_architecture_invariants.gd#L291] (`test_runner_observation_seams_are_exactly_eight`)
- [Source: test/state/test_architecture_invariants.gd#L285-L288] (the eight seam names)
- [Source: test/state/test_architecture_invariants.gd#L9] (`test_single_physics_process_owner`, the
  actual F1 guard — cited so the earlier mislabel cannot recur)
- [Source: test/state/test_architecture_invariants.gd#L318-L324] (hero NODE positions are the sole
  geometric input to `_gather_contact_facts` — the basis of AC 9's ruling)
- [Source: test/state/test_determinism.gd#L458] (the live golden, `4a089063...`)
- [Source: test/integration/test_unit_vertical_alignment.gd#L56-L77] (the source-string spawn-Y
  parse this story breaks and must re-author)
- [Source: test/integration/test_two_units_converge_live.gd#L113-L127] (the spawn-lane hero
  teleport this story inverts)

## Golden Prediction

**Predicted UNMOVED, measured in BOTH directions at the dev pass. Current golden:
`4a089063a8b3eff2274c0ca300dafe80e4eb4d3970ada352ca432a7e39844bdf`**
(`test/state/test_determinism.gd:458`). Beware the two SUPERSEDED hashes living in comments in that
same file — `7fbb4b7f...` appears at `:294` and `:313` as the pre-stamina-cost / 3-0b-era golden,
and `96ac5f64...` at `:308` as an intermediate step-2 measurement. Neither is the live value;
`:458` is.

The prediction is nearly free, and the story says so rather than banking it as evidence: **the
golden STRUCTURALLY CANNOT SEE PLACEMENT.** `test/state/test_determinism.gd` runs `MatchState`
alone — no runner, no scene tree, no `_physics_process`, no actor (`test_determinism.gd:454`, on a
different AC, states the general form of it: "there is no runner here"). Actor geometry reaches
state only through `push_contact`, which nothing in that fixture calls from a position. Placement
is runner-owned, never enters `to_snapshot()`, and this story adds no `src/state/` field — its one
`src/state/` edit is a comment (AC 6(b)). The snapshot key set is likewise unmoved (guarded by
`test/state/test_card_observation.gd`).

**Therefore the golden check here is NEAR-VACUOUS, and the REAL REGRESSION SURFACE IS
`test/integration/`.** A green golden proves this story did not accidentally touch hashed state; it
proves nothing whatsoever about whether placement is correct, ground-level, deterministic, clear of
the occupants, or clustered ("in-arena" stood in this list until the third gate; it is no longer a
property of this story — AC 2 has no arena test). The before/after that carries information is the integration suite — specifically the
two impacted files named above. If the golden DOES move, that is a finding to report, not to
absorb: it would mean something reached hashed state that this story never intended to.

**`project.godot` byte-identity is ALSO measured in both directions**, on the `3-0a`/R3 protocol
this project applies to every story that opens the editor.

## Live Smoke

**REQUIRED**, Tier A default. No `.tscn` flip needed — the shipped default
(`slot_controller_kinds = [0, 1]`) already gives two live human slots. Six things the operator must
judge by eye, none of which a test can settle:

- **Walk P1 out to the arena edge and summon.** The minion appears BEHIND the hero relative to P2 —
  not at the old row — and does not pop into view inside the hero's own body (AC 1, and the body
  clearance is now AC 3's occupancy ruling rather than an unstated expectation). **What is NOT
  judged here: whether the unit stays inside any bound.** Placement has no arena test (AC 2), and
  nothing keeps the HERO on the floor either (see Non-Goals) — a summon placed off the floor edge
  behind a hero standing at the edge is the shipped, expected behaviour of this story, not a smoke
  failure. Report it as an observation if you see it; do not treat it as a defect to fix here.
- **Summon while running.** The unit lands where the hero WAS at cast time, and does not visibly
  slide, drift or snap to a new spot on the following frames (AC 1).
- **Summon twice from two different hero positions, a few seconds apart.** Two separate spots, each
  behind the hero where it stood — the eye-proof that the base spot is RECOMPUTED per call and not
  cached from the first batch (Task 3's second bullet).
- **Run up to P2 and summon on top of them** (AC 3). The unit appears and the cast is not refused —
  it lands FURTHER BEHIND P1, never between P1 and P2, because both heroes are occupants and the
  rear-arc search (AC 1) steps backward to clear P2's body rather than around it. A unit appearing
  on P2's far side, or anywhere in the fighting space between the two heroes, IS a smoke failure.
  **EXCEPT with the heroes effectively on top of each other**, where the live direction is too short
  to be reliable and AC 1's fallback governs: "behind" is then defined by the SLOT AXIS (P1 toward
  -x, P2 toward +x) and the operator judges against THAT, not against the live hero-to-opponent
  direction. Nothing about bounds is judged here.
- **The minion is STANDING ON THE GROUND, not hovering** (AC 8). This is the check that catches the
  hero-Y mistake if the re-authored vertical-alignment test somehow misses it.
- **A lingering corpse is not displaced, reused or spawned-on-top-of by a new summon** (AC 7 /
  `4-3a/R13`) — summon, kill, then summon again while the corpse is still down.

The operator writes the `docs/playtest-log.md` entry by hand, BEFORE the commit chain — no agent
writes it on the operator's behalf.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Author | Change |
|---|---|---|
| 2026-08-27 | Claude Sonnet 5 | Story authored against `d3854ff`. Status `authored`. |
| 2026-08-27 | Claude Opus 5 (1M context) | FIFTH READINESS GATE FIX PASS — **THIS PASS REMOVED SPECIFICATION RATHER THAN ADDING IT**, docs-only, this file only. Three of the fifth gate's four blocking findings (B1, B2, B4) existed only because AC 4 had been inflated into a full specification of cluster mechanics for N>1 — mechanics the story itself measures as UNREACHABLE THROUGH PLAY at `d3854ff`. The owner's ruling: do not specify, guard or gate behaviour nothing can execute; delete the thing that needed the constraint rather than authoring the constraint. **AC 4 COLLAPSED TO ITS TWO SURVIVING CLAIMS**: members of a growth batch land NEAR ONE ANOTHER rather than scattered around the hero, and each member's position clears EVERY occupant and every member already placed in the same call. The unreachability measurement and its three citations (`match_state.gd:1428`, `match_state.gd:1329-1344`, `match_runner.gd:1410-1411`) are KEPT. **DELETED**: the named MINIMUM and MAXIMUM in-batch separation bounds and the "minimum must be at least the occupancy clearance radius" relation (AC 4 and Task 3) — with them go B1 (AC 2's first-free-candidate accept rule imposed no maximum, so a conforming search could fail the maximum the test asserted), B2 (four dev-chosen numbers with only two stated relations, so the feasible region could be empty) and NB1 (at equality the minimum re-asserted the clearance rule and falsified nothing); the per-member seeding rule "seeded near the cluster" in Task 3 (B4 — undefined, unlisted in latitude, and load-bearing only for the bounds now deleted); the MANDATORY SYNTHETIC N=3 TEST in AC 4 and Task 5, replaced by one line — the batch loop is written for N, there is no test for N>1 because no gameplay path reaches it, correctness for N>1 is carried by REVIEW and the story says so rather than pretending otherwise; the Implementation Latitude bullet naming the two separation distances; Task 1's reference to "AC 4's synthetic N=3 test" as a caller of the helper (AC 9's two purity assertions and the measured-Y assertion still require the extraction, so the seam stays MANDATORY); and Project Structure Notes' "the AC 4 clustering guard is the exception", now naming AC 9's purity assertions as the tests that need no live scene graph. **THE ONE PROMOTION (B3, owner ruling)**: the degenerate-direction fallback moved OUT of Implementation Latitude and INTO AC 1 as a requirement — when the hero-to-opponent direction is too short to be reliable, the rear arc's axis is the slot's fixed away-from-centre axis (P1 toward -x, P2 toward +x), for the ARC and not merely the base spot. It previously lived only in latitude and predated the rear-arc clause, leaving an AC with no defined meaning in the case AC 3 explicitly blesses. Live Smoke point 4 amended to exempt that case: with the heroes effectively on top of each other the operator judges "behind" against the SLOT AXIS, not the live direction. What stays latitude is only the threshold at which the direction counts as unreliable. **NB2**: the fourth-gate row's parenthetical claiming `test_architecture_invariants.gd:284` is the trailing `3-6/R2` comment is corrected in place — 284 is the `const OBSERVATION_SEAMS` declaration, 283 is the comment, 288 the closing `]`. NO NEW REQUIREMENT, RELATION OR NUMBER was added in this pass. Everything verified green at the fifth gate is UNTOUCHED: the nine ACs and their numbering, AC 2's ring/rear-arc termination argument (re-checked sound for any arc width, degenerate widths included), the citations `test_architecture_invariants.gd:285-288` and `:318-324`, the `sqrt` arithmetic and the 3.27/2.60 figures, the golden `4a089063...` at `test_determinism.gd:458`, and Live Smoke points 1, 2, 3, 5, 6. Status stays `authored`. No code, no test, no `sprint-status.yaml`; nothing staged, nothing committed. |
| 2026-08-27 | Claude Opus 5 (1M context) | FOURTH READINESS GATE FIX PASS — four blocking and four non-blocking findings applied on owner rulings, docs-only, this file only. **THE RADIUS RULE IS PER RING, NOT PER CANDIDATE (B1).** The third pass required the radius to STRICTLY INCREASE per candidate, which forbade the ring that Implementation Latitude simultaneously mandated — a ring holds several candidates at one radius by definition. AC 2, Task 2 and the latitude bullet now say: the sequence is organised into RINGS, each holding FINITELY MANY candidates at the SAME radius visited in a FIXED DETERMINISTIC ORDER; the radius is NON-DECREASING WITHIN a ring and STRICTLY INCREASES BETWEEN rings by a FIXED POSITIVE STEP, without bound. Termination argument unchanged in substance, with "each ring being finite" added so the per-ring candidate count cannot be read as unbounded. **THE HELPER TAKES BATCH SIZE AND RETURNS N POSITIONS (B2)** — one call per batch, not one per member. AC 9's headline and the "Design already locked" bullet both still said "batch INDEX", contradicting Task 1's signature and AC 4's N=3 guard; all three now read `(the occupied positions, this hero's position, the opposing hero's position, slot, BATCH SIZE)` returning an ORDERED LIST OF N POSITIONS, and Task 1's bullet states the one-call-per-batch shape explicitly. **"BEHIND" WINS OVER PROXIMITY (B3, owner ruling)** — the fourth gate found nothing constraining the ACCEPTED candidate's direction, so a crowded rear (or an opponent standing on the summoner, which AC 3 blesses) could put the unit in front. A new AC 1 paragraph makes the rear half-space a requirement OF THE ACCEPTED CANDIDATE: every candidate lies on the far side of the summoning hero from the opponent, measured against the hero-to-opponent direction at cast time; a ring is a rear ARC, not a full circle; a crowded rear pushes the unit FURTHER BEHIND, never in front. Restated in Task 2 as its own bullet, in the latitude bullet, in AC 3's consequence sentence ("further out" -> "FURTHER BEHIND … never around into the fighting space") and in Live Smoke point 4, which now names a unit in the fighting space as a smoke FAILURE. Termination is unaffected and says so. **EVERY CLUSTER MEMBER IS CLEARED (B4).** Task 3's "one searched base spot, offset the rest blind" would have dropped members 2..N inside a hero or a live unit — the exact interpenetration AC 3 exists to prevent. AC 4 and Task 3 now place members ONE AT A TIME, each clearing EVERY occupant in the caller's list AND every member of the same batch already placed in this call, running the same rear-arc ring search seeded near the cluster; the cluster's tightness is a preference for where to look FIRST, never a licence to skip the occupancy test. For N=1 the behaviour is unchanged. Task 2's first bullet gains the already-placed-members clause. **NON-BLOCKING**: AC 4's separation is now bounded on BOTH sides — a named MINIMUM (at least the occupancy clearance radius) and a named MAXIMUM, both authored by the dev pass — and Task 5's synthetic N=3 assertion tests both bounds, because "three distinct spots" is satisfied by 1e-6 m and falsifies nothing (NB5); AC 9's guard (ii) is KEPT but no longer described as "STRONGER" or "the real property" — it is restated as a CHEAP REGRESSION PIN against a later positionally-indexed occupancy read, with the reason stated plainly (a conjunction over the whole list is order-independent by construction, so the pin normally passes on the first try), and Task 5 carries the same wording into the test's docstring requirement (NB6); a new Task 2 bullet requires the offset-behind distance to EXCEED the occupancy clearance radius, so the base spot is never inside the summoning hero's own clearance, with the relation named in the latitude bullet as not-latitude (NB7); the two drifted line ranges corrected in AC 6(b), AC 9, the ruled-open-question paragraph and References — the eight seam names are at `test_architecture_invariants.gd:285-288` (corrected at the fifth gate: 284 is the `const OBSERVATION_SEAMS` DECLARATION, not a comment — 283 is the trailing `3-6/R2` comment line, and 288 is the closing `]`) and the hero-NODE-positions passage at `:318-324` (NB8). DELETED: only the superseded wordings named above — the per-candidate radius sentence, "batch index" in two places, "each within a named pairwise separation" as the sole cluster assertion, and guard (ii)'s "STRONGER … the real property" claim. Historical Change Log rows are left verbatim as the record of what each pass wrote, including their now-superseded line ranges. Everything verified green at the fourth gate is UNTOUCHED: the nine ACs and their numbering, the `sqrt` arithmetic and the 3.27/2.60 figures, the golden `4a089063...` at `test_determinism.gd:458` with its superseded-hash warnings, and every other citation re-verified at this gate (`match_runner.gd:656`'s literal `0.0`; the `142-145` comment block with both stale claims on line 145; `unit_board.gd:303`'s "seven"; `unit_actor.tscn`'s `Collision` editor_description and its default-layer-1 claim; `main.tscn:30,34`/`:19`/`:21`/58 lines; `match_state.gd:1428`/`:1329-1344`; `match_runner.gd:1410-1411`/`:919-927`; `test_architecture_invariants.gd:291`). Status stays `authored`. No code, no test, no `sprint-status.yaml`; nothing staged, nothing committed. |
| 2026-08-27 | Claude Opus 5 (1M context) | THIRD READINESS GATE FIX PASS — four blocking and four non-blocking findings applied on owner rulings, docs-only, this file only. **TERMINATION GAINS ITS MISSING REQUIREMENT (B1).** The second pass's finiteness argument was unsound as written: finitely many occupants do not halt a walk that densifies inside a bounded region, and the story had simultaneously forbidden the cap AND the fallback, leaving a possible infinite loop in the runner's `_physics_process` seat with no guard. AC 2 and Task 2 now REQUIRE the candidate sequence's radius from the base spot to STRICTLY INCREASE, UNBOUNDED, by a FIXED POSITIVE STEP (constant, never adaptive), and FORBID a densifying sequence; the argument is restated in corrected form (radius grows without bound + finitely many bounded occupants => some ring is entirely free => halts). **`grid` REMOVED from Implementation Latitude** — pattern latitude is RING OR SPIRAL only, step size still free but constant. **THE HELPER'S SIGNATURE GAINS OCCUPANCY (B2).** Task 1's bullet contradicted itself — a four-argument signature with no occupancy input, "must not read the scene tree", and "its occupancy input is the live actor positions, passed or read through `is_instance_valid()`" — which made AC 9's guard (ii), Task 5's hole test and the pre-occupied search test unwritable. The helper now takes `(the occupied positions, this hero's position, the opposing hero's position, slot, batch size)`; a NEW Task 1 bullet puts list-building on the CALLER inside `_spawn_missing_unit_actors` (walk `_unit_actors` both slots under `is_instance_valid()`, read each live actor's `global_position`, add both heroes); the helper reads no scene tree and holds no node reference. AC 9's headline restated to name occupancy as an input. **AC 9's GUARD (ii) REPLACED AND STRENGTHENED**: the hole-rearrangement assertion is gone — holes never reach the helper now, the caller filters them — and in its place, SAME OCCUPANCY SET IN A DIFFERENT ORDER must return the same result; order independence is the real property and is what an array-index or scene-tree-order dependence leaks through. AC 9's purity list swaps "no dependence on the arrangement of `null` holes" for "no dependence on the ORDER of the occupancy list". **BOTH HEROES ARE OCCUPANTS (B4, owner ruling)**: Task 2's "every other live unit actor (both slots)" becomes every occupied position in the caller's list, unit actors AND both heroes, with the reason recorded in AC 3 (AC 3 blesses summoning on the opponent, which is exactly when "behind me" lands inside a body; heroes are `CharacterBody3D` on the same default layer 1 as units) and the consequence stated in one sentence — the cast still resolves, the unit simply appears slightly further out. Live Smoke point 1's "does not pop into view inside the hero's own body" is now backed by an AC. **LIVE SMOKE POINT 4 TRIMMED (B3)**: DELETED "nothing is ejected through the floor or off the arena edge" — the last surviving requirement-shaped reference to the bound the second pass removed, contradicting AC 2, the new Non-Goal and point 1's own amendment. Point 4 now judges what AC 3 promises: the unit appears, the cast is not refused, no bound is judged. **NON-BLOCKING**: Golden Prediction's "in-arena" dropped from the list of things the golden cannot prove (NB1); **"GROUND-DERIVED" DEFINED (NB2, owner ruling)** in AC 8 and Task 1 as the ground-level CONSTANT the runner already uses (`match_runner.gd:656`'s literal `0.0`), never a raycast or physics query, which would put a physics read inside a helper AC 9 requires to be pure; the repeat-call assertion is left exactly as it was but AC 9 now says outright that nothing in the story may count it as broader coverage, and Task 5 records that it catches a `Time`/frame-counter read barely if at all since both calls sit in one frame (NB3); the stale-comment range corrected to `match_runner.gd:142-145` in AC 6(a), Task 1, Dev Notes and the References entry, noting both stale claims sit on line 145 (NB4). Everything verified green at this gate is UNTOUCHED: the nine ACs and their numbering, the `sqrt` arithmetic and the 3.27/2.60 figures, the golden `4a089063...` at `test_determinism.gd:458` with its superseded-hash warnings, every other line citation (`hero.gd:32,48`; `main.tscn` 58 lines / one `StaticBody3D` `:19` / one `CollisionShape3D` `:21`; `test_architecture_invariants.gd:9`/`:284-288`/`:291`/`:316-323` and its comment-stripping `_code_lines`; the D3(b)/A2 scan scoped to `src/state/` at `:36-47`; `unit_board.gd:303`; `match_state.gd:1428`/`:1329-1344`; `test_unit_vertical_alignment.gd:63`/`:56-77`/`:140-147`; `test_two_units_converge_live.gd:113-127` and its 6.82 at `:117`; `test_unit_corpse_walkthrough_live.gd:209,228`; and that it is the only integration test repositioning a hero — all re-verified against the repo at this gate), and Live Smoke points 2, 3, 5, 6. Status stays `authored`. No code, no test, no `sprint-status.yaml`; nothing staged, nothing committed. |
| 2026-08-27 | Claude Opus 5 (1M context) | SECOND READINESS GATE FIX PASS — three blocking and two non-blocking findings applied on owner rulings, docs-only, this file only. **THE ARENA BOUND IS OUT OF AC 2 ENTIRELY (owner ruling).** The second gate found AC 2 self-contradictory: `hero.gd:32,48` is `velocity = hero_state.velocity` + `move_and_slide()` with NO clamp, arena bound, killplane or respawn anywhere (grepped across `hero.gd` and `match_runner.gd`), and `main.tscn` is 58 lines with exactly one `StaticBody3D` and one `CollisionShape3D` — no walls — so a hero can stand at or past the floor edge, putting the BASE SPOT outside [-20, 20], collapsing the ring walk at radius 0 and driving the fallback to place a unit outside the arena, contradicting AC 2's own "nothing is ever placed outside the arena". Ruling: the bound was the wrong termination device and was upstream error. AC 2 REWRITTEN — unbounded outward walk, first free candidate wins, **terminates because the live units are FINITE** (a ring far enough out is always free). DELETED: the [-20, 20] test, the out-of-arena skip, the "every candidate occupied" fallback and the interpenetration outcome it named (unreachable by construction), Task 2's arena bullet and its fallback bullet, and Task 5's "no candidate is ever placed with |x| or |z| > 20" assertion. The arena MEASUREMENT stays in Dev Notes and References, restated as CONTEXT that does not bound placement. **NEW NAMED NON-GOAL**: keeping anything inside the arena, hero included — a PRE-EXISTING GAP WITH NO OWNER, with the measurement above cited; a hero standing off the floor gets its hero-relative summon placed off the floor with it, and this story neither fixes that nor pretends it is absent. Live Smoke point 1 amended to match: the operator judges the unit appears BEHIND the hero near the edge, explicitly NOT that it is kept inside any bound. **EXTRACTING THE PLACEMENT HELPER IS NOW REQUIRED, not optional** — the second gate found AC 4's synthetic N=3 guard unimplementable, because placement is three inline lines (`match_runner.gd:652-657`) and Project Structure Notes made extraction the dev's choice ("unless the dev agent chooses"). A mandatory Task 1 subtask now specifies a private, directly-callable `MatchRunner` helper taking (this hero's position, opposing hero's position, slot, batch size) and RETURNING positions — no scene-tree read, no spawn, no `_unit_actors` mutation — and Project Structure Notes is corrected to say extraction is mandatory and the location settled. **AC 9 GETS A GUARD AND NAMES ITS RESIDUAL GAP**: Task 5 now carries two effect-assertions — call the helper twice with identical inputs, assert byte-identical returned positions; call it with the same inputs but a different arrangement of `null` holes, assert the same result — and AC 9 states plainly what they do NOT cover: the D3(b)/A2 scan for `randf`/`randi`/`Time`/`OS`/`Engine` reads `src/state/` ONLY, `match_runner.gd` is `src/main/` and is NOT scanned, so an added `randf()` there trips no guard and the rest of the purity list is held by CODE REVIEW, in the same honest style AC 7 already uses for its own gap. **AC 6(b) MISQUOTE FIXED**: it claimed to reconcile with AC 7's "no `src/state/` change", a clause AC 7 does not contain; it is now reconciled against AC 7's actual three clauses (no position field, no new seam, hole untouched), all satisfied literally, with the comment-stripping in `test_architecture_invariants.gd`'s `src/state/` scanners cited. **Project Structure Notes' opening sentence corrected** — it claimed all changes are confined to `match_runner.gd` and contradicted itself three lines later; it now states the full edit set (runner + one `src/state/` comment + two existing test files). **DROPPED RATHER THAN CARRIED**: the gate's body-half-extent point (a candidate at exactly x = 20 hangs 0.3 m off the floor edge, `unit_actor.tscn:9`'s `0.6 x 1.2 x 0.6`) is MOOT now that no arena bound exists, and is deliberately not carried anywhere in the story. Verified-correct material left UNTOUCHED: the nine ACs and their numbering, `sqrt(2.5^2 + 2.1^2)` ≈ 3.27 / `sqrt(2.5^2 + 0.7^2)` ≈ 2.60 / `Z_START + SPACING` = -0.7, the golden `4a089063...` at `test_determinism.gd:458` (re-checked character by character) with its superseded-hash warnings at `:294`/`:313`/`:308`, every other line citation (all spot-checked green at this gate), and Live Smoke points 2-6. Status stays `authored`. No code, no test, no `sprint-status.yaml`; nothing staged, nothing committed. |
| 2026-08-27 | Claude Opus 5 (1M context) | FIRST READINESS GATE FIX PASS — 7 blocking, 4 non-blocking findings applied, docs-only, this file only. **AC 2 REWRITTEN** on the operator's ruling: the search is UNBOUNDED IN CANDIDATE COUNT and BOUNDED BY THE ARENA; the "bounded candidate set, use the last one anyway" shape was an upstream error, not an owner ruling, and is dropped. The overlap fallback now NAMES its observable outcome (interpenetrate, stand still until throttled targeting acquires a target, separate under their own approach), with the mechanism cited (`unit_actor.tscn`'s `CharacterBody3D` on default layer 1; `unit_board.gd:146-149`'s no-target entry). Arena MEASURED from `main.tscn:7-8`/`:19-23`: `BoxShape3D_jqarl size = Vector3(40, 1, 40)`, `Ground` at origin, `GroundCollision` at `(0, -0.5, 0)` -> floor top y 0, x/z in [-20, 20]; there is no wall geometry in the scene, so the bound IS the ground extent. **AC 4 RESTATED HONESTLY** on the operator's ruling: it STAYS (multi-summon cards are planned, the batch loop must be correct for N>1 now), but the story now states plainly that N>1 is UNREACHABLE THROUGH PLAY at `d3854ff` (one `units.add()` per resolved cast, `match_state.gd:1428`; one `card_commit` per player per tick, `match_state.gd:1329-1344`; two same-tick casts are different slots spawned through separate calls, `match_runner.gd:1410-1411`) and that its guard is therefore a SYNTHETIC N=3 test asserting three distinct spots within a named separation — an effect, not an identifier — with its synthetic nature stated in the test's own docstring. **TWO NEW ACs.** AC 8: the spawn Y is GROUND-DERIVED and never taken from the hero's Y (hero root is body centre at y 1, `main.tscn:30,34`; unit root is feet at y 0, `match_runner.gd:655-656` and `unit_actor.tscn`'s `Collision` description) — the naive implementation floats every minion 1.0 m, the exact defect `test_unit_vertical_alignment.gd` exists to catch. AC 9: placement is a PURE FUNCTION of (this hero's position, the opposing hero's position, slot, batch index) — no RNG, no `Time`/`OS`/`Engine`, no frame counter, no scene-tree iteration order, no dependence on the arrangement of holes in `_unit_actors`, computed at the existing post-`advance()` seat inside the `ticking` gate. **THE DEFERRED OPEN QUESTION IS RULED AND REPLACED** by AC 9: acceptable as-is, no mitigation, because hero position is ALREADY the only unhashed geometric input gameplay reads (`test_architecture_invariants.gd:316-323`) and placement joins that existing chain rather than opening a new one; rejected mitigations recorded (hashing position, reverses `4-2/R14`; a position field on `UnitBoard`, reverses the clause AC 7 preserves). **TWO IMPACTED TESTS NAMED**, where the story previously claimed a single reader: `test/integration/test_unit_vertical_alignment.gd:63` parses the runner's source for the literal `"unit.global_position = Vector3(UNIT_ROW_X[slot],"` and `quit(1)`s when it does not match (`:56-77`, `:140-147`), so deleting the constants turns it red — Task 1 carries re-authoring it, and PREFERS replacing the source parse with a real measured-Y assertion because a source-string parse is itself an identifier-asserting guard sitting in shipped code; `test/integration/test_two_units_converge_live.gd:113-127` teleports P1's hero to `z = 8.0` specifically to leave the spawn lane, and hero-relative placement moves the lane onto it, so its setup and its measured 6.82 figure need re-deriving. **AC 6 becomes "the two stale comments"**, adding `src/state/unit_board.gd:303`'s "seven `connect_*` seams" -> eight (`test_architecture_invariants.gd:284-291`, amended `3-6/R2`) — a stale citation in shipped code, same class as the comment AC 6 already fixed, and this story's only `src/state/` edit. **F1 MISLABEL FIXED**: the old open-question paragraph called the hashed-`MatchState` boundary "the F1 boundary"; F1 is the single-`_physics_process`-owner invariant (`test_architecture_invariants.gd:9`), the test name was real but the attribution was not. **THE 2.5 m CLAIM CORRECTED**: 2.5 is the X difference only (`UNIT_ROW_X[0]` -5.5 vs hero x -3); the actual planar distances from P1's hero to the row are `sqrt(2.5^2 + 2.1^2)` ~= 3.27 (first unit, z -2.1) and `sqrt(2.5^2 + 0.7^2)` ~= 2.60 (second, z -0.7) — first and second unit of ONE row, not two per-slot values — with the derivation shown. **"The `UnitBoard` positionless-count guards" REPLACED** with the guard that exists: the snapshot key-set assertion in `test/state/test_card_observation.gd` (`test_determinism.gd:25`), plus the residual gap stated — it catches a new snapshotted key, not a private unhashed field. **THREE MISSING SECTIONS ADDED** on `4-3d`'s shape (`:447`, `:459`, `:709`): Golden Prediction (UNMOVED at `4a089063...`, `test_determinism.gd:458`, with the explicit statement that the state harness has no actors so the golden STRUCTURALLY CANNOT see placement, making the golden check near-vacuous here and `test/integration/` the real regression surface — and a warning that `7fbb4b7f...` at `:294`/`:313` and `96ac5f64...` at `:308` are superseded values living in comments), Live Smoke (six operator-judged points), and this Change Log. References section extended with every file and line read at the gate. Status stays `authored` — promotion is the operator's act. No code touched, no test touched, `sprint-status.yaml` untouched; nothing staged, nothing committed. |
