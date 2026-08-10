---
baseline_commit: 8c511e5995514f046fcb74384c71783576dda9c6
---

# Story 4.3b: Minion attack rhythm

Status: ready-for-dev

## What this story inherits

`4-3a-minion-damage-and-death` shipped the unit as TARGET only — hp, damage, death, board
removal, and the contact-fact TARGET addressing that made a unit hittable
(`docs/implementation-artifacts/4-3a-minion-damage-and-death.md`, "What this story supersedes").
That story's own scope split (`4-3a/R1`) named this one as the unit's other half: the unit as
ATTACKER — windup/active/recovery, a unit hitbox, unit-vs-unit damage — and re-anchored the melee
retune (`E3-R/R3`) here (`4-3a/R5`). The operator ratified eleven scope/behaviour rulings for this
story in the browser (decision-log Session 2026-08-10, "4-3b story authoring rulings",
`4-3b/R1`-`R11`); the READINESS GATE then ruled eleven more (Session 2026-08-11, "4-3b readiness
gate", `4-3b/R12`-`R22`), which closed every open question this story was authored with except
the provisional tuning values. This story's ACs are built FROM those rulings, not re-derived.

## Story

As a player,
I want a summoned minion to periodically attack whatever it has acquired, landing real damage
through the same contact pipeline a hero's swing uses,
so that a minion is a genuine combat participant — a threat I must respect and a target I can use
against my opponent's other minions — rather than a passive body a hero can farm for free.

## Acceptance Criteria

1. **A unit gains a windup/active/recovery attack rhythm, owned by state, in the tick domain, on
   the hero's own `windup`/`active`/`recovery` `TimingWindow` precedent
   (`hero_state.gd:104-106`).** The three duration scalars are GLOBAL and shared by every minion,
   and the two rulings that establish that are `4-2/R17` condition (c) — the first story where
   units actually DIFFER is the only story allowed to add a differentiating field to the unit
   record — and `4-3a/R6` — `4-3b` receives NO advance permission and must obtain its own grant at
   its own scope ruling. This story is not that story: minions do not differ here, so the
   durations are authored once on `BalanceConfig`, not per unit.

   The three field identifiers, named explicitly because NAMING IS LOAD-BEARING (the balance field
   guard is reflection-based, `test/state/test_data_resources.gd:85-131`, and matches on the field
   NAME):
   `minion_attack_windup_seconds`, `minion_attack_active_seconds`, `minion_attack_recovery_seconds`.
   Each must ship with all four of: (i) the `<stem>_seconds` suffix; (ii) an exactly stem-matched
   `<stem>_ticks` twin on `BalanceTicks`, FILLED at load by `from_config()` (half (b) of the guard
   reads the twin back and fails on a field `from_config` forgot); (iii) an entry in
   `E1_BALANCE_FIELDS` (half (a) fails any script-declared float/int missing from the audited
   list); (iv) a non-negative authored value in `data/balance/balance_config.tres`
   (`test/state/test_balance_authoring.gd`). Precedent, verbatim:
   `attack_windup_ticks`/`attack_active_ticks`/`attack_recovery_ticks` (`balance_ticks.gd:46-48,
   70-72`).

   **Authored values are PROVISIONAL** — this story ships a working rhythm, not a tuned one; the
   melee retune (`E3-R/R3`, re-anchored here by `4-3a/R5`) runs as its own non-story block once
   this story closes and owns the real numbers.

   PROVEN BY: `test_data_resources.gd` (both reflection halves), `test_balance_config.gd`
   (`test_conversion_covers_every_seconds_field`), `test_balance_authoring.gd` (sane authored
   values), and a new `test/state/test_unit_attack_rhythm.gd` phase-progression pin driving a unit
   through windup -> active -> recovery at the authored tick counts.

2. **A unit's attack hitbox resolves through the SAME `advance()` step-4 contact pipeline a hero's
   swing uses — never an abstract cadence that damages the acquired target without a real
   hitbox/hurtbox overlap** (`4-3b/R1`). Reason: an abstract resolution is an unavoidable hit —
   the mob-feel finding `4-3` already made one layer up, now repeating at the minion's own attack
   if this story took the shortcut.

   PROVEN BY: `test/integration/test_unit_combat_live.gd` extended — a unit whose active window is
   open but whose hitbox does NOT overlap its target deals zero damage (the non-vacuous half: an
   abstract implementation passes a "damage lands" test and fails this one).

3. **The contact fact's ATTACKER address widens from a bare `attacker_slot: int` to a
   `[slot, index]` pair, on the SAME `4-2/R2` convention `4-3a` already spent on the TARGET half**
   (`push_contact`, `match_state.gd:442-464`; `capture_push_contact`,
   `intent_recorder.gd:194-199`). **The widened attacker address must be KIND-AGNOSTIC** — `index
   == -1` addresses that slot's hero (every existing hero-attacker call site keeps resolving
   identically under `[slot, -1]`, a non-vacuous regression pin, not just a type change) and `index
   >= 0` addresses a board unit at that index, on the identical shape `target` already uses. This
   is NOT a hero/minion two-case enum: totems and hero-cast projectiles are already known future
   users of this exact opening, and a two-case shape would need re-widening the moment either
   lands.

   **THE WIDENING IS SCOPED TO THE FACT DICTIONARY. THE SIGNALS DO NOT WIDEN** (`4-3b/R15`, and
   the measurement below is the ruling's own).
   Measured: `hit_landed(attacker_slot: int, target_slot: int, damage: float, target_hp: float)`
   (`match_state.gd:30`) and `deflect_landed(attacker_slot: int, target_slot: int)`
   (`match_state.gd:37`) both carry a typed BARE INT attacker, and both shipped consumers
   UNDERSCORE it and gate solely on the target slot (`telegraph_controller.gd:93-95, 108-110`:
   `_attacker_slot`, then `if target_slot != my_slot: return`). So a minion damaging a hero already
   flashes and stings the correct hero with no change at all. Widening the signal payload would
   break two typed callbacks for zero behavioural gain — a dev pass reading AC 3 literally must not
   do it.

   PROVEN BY: `test_contact_resolution.gd` (every hero-attacker case re-expressed as `[slot, -1]`
   and unmoved), `test_intent_recorder.gd` / `test_record_file.gd` (row shape), and a signal-arity
   pin in `test_architecture_invariants.gd`'s `connect_*` surface list asserting `hit_landed` and
   `deflect_landed` still take a bare int attacker.

4. **A unit's swing CLEAVES**, on the hero swing precedent (`4-3a/R16`): it slides through every
   target its hitbox touches in the same active window, not just the first (`4-3b/R2`). The
   append order into the unit's dedupe hit list is HASH-SIGNIFICANT and rests on unpinned physics
   query order (the `4-3a/R22` review finding, `hero_state.gd:254-273`) — the new attacker surface
   must sort canonically on insertion, following that exact precedent, not reinvent a different
   ordering discipline.

   **CLEAVING THROUGH A BYSTANDER DAMAGES IT BUT DOES NOT REFRESH THE IN-REACH FLAG** — only a fact
   against the unit's own ACQUIRED TARGET does that (AC 13). The two are independent: this AC scopes
   what a swing may HIT, AC 13 scopes what may set the flag, and wiring flag-set on every registered
   hit would keep a unit swinging at a target it has lost.

   PROVEN BY: `test_unit_attack_rhythm.gd` — one unit swing over three targets registers three
   addresses and no address twice, and the same three overlaps fed in reversed order produce an
   identical stored hit list.

5. **Ordering ACROSS attackers is canonical, not incidental.** AC 4 pins order WITHIN one swing;
   nothing today pins the order in which facts from DIFFERENT attackers enter the queue, and the
   outcome is player-visible: deflect spends stamina PER FACT (`match_state.gd:739-742`), so with
   two minions landing on one hero in one tick the first fact in the queue is deflected and the
   second falls through to blocked damage once stamina runs out. Which minion is which must not be
   decided by unpinned iteration order. Required: a canonical gather order across attackers —
   **slot ascending, then board index ascending**, the tie-break precedent `4-2/R3` already
   established for minion targeting — AND a FIXED position for the unit gather pass relative to
   the two existing hero gathers (`match_runner.gd:1009-1010`), stated in the code at that seat.

   PINNED NON-VACUOUSLY: the same set of facts fed in different gather orders must produce
   identical resolution AND an identical `to_snapshot()` hash. A test that only feeds them in one
   order proves nothing.

   PROVEN BY: `test_unit_attack_rhythm.gd` (order-permutation hash equality) plus
   `test_contact_pipeline.gd` for the live gather seat.

6. **No friendly fire on the ATTACKER side either**: a unit never damages the hero or the units of
   its own slot (`4-3b/R3`, substance unchanged; `4-3b/R16` corrects its location word).
   **Filtering happens at GATHER time, by OWNER SLOT, never by collision layer.** Measured reason
   it cannot sit on the resolution ladder: `push_contact` asserts `attacker_slot != target_slot`
   and HALTS on violation (`match_state.gd:454-455`, `Invariant.check`), so a same-slot fact must
   never reach that seam at all — a ladder-side check would be dead code behind a build halt. The
   shape to follow is the hero-attacker filter `4-3a/R21b` already shipped at gather time
   (`match_runner.gd:882-889`).

   PROVEN BY: `test_unit_combat_live.gd` — a unit's active hitbox overlapping its own summoner and
   its own sibling produces no fact, no damage, and no halt.

7. **A confirmed hit sourced from a unit generates ZERO mana for its owner** (`4-3b/R4`), on the
   `4-3a/R3` unit-TARGET precedent applied to the unit-ATTACKER side: a unit-sourced confirmation
   must stay out of the `confirmed_hits` list `_resolve_contacts` returns (`match_state.gd:747`),
   which is the list `_generate_mana` (`match_state.gd:846-862`) awards per entry. There is no
   second gate inside `_generate_mana` to keep in agreement with this one. Reason: otherwise
   summoning becomes a mana engine, and a blocked hit still confirms.

   PROVEN BY: `test_mana_economy.gd` extended — a unit-attacker hit on a hero (full, blocked) adds
   nothing to either mana pool, while the identical hero-attacker hit still does.

8. **`hit_landed` IS emitted when a unit damages a HERO** (`4-3b/R5`) — the hero is really hurt, so
   the telegraph flash/sting on that hero is correct. This is a DELIBERATE ASYMMETRY against
   `4-3a/R12`'s suppression of `hit_landed` for unit TARGETS (a unit hit by a hero); the two are
   not the same rule and this AC exists so a later gate does not re-litigate the asymmetry as an
   inconsistency. Per AC 3 the payload is UNCHANGED — the bare-int attacker slot is enough, because
   the consumer gates on the target.

   PROVEN BY: `test_contact_resolution.gd` (emitted for a unit attacker on a hero target; still
   suppressed for a unit target) and `test_unit_combat_live.gd` (the flash observed live).

9. **The hero's existing defensive ladder applies to a minion's attack unchanged**: roll iframes
   drop the fact, deflect fully negates (queues `deflect_landed`, spends the deflect cost),
   block applies `block_damage_multiplier` — the exact hero-ladder rungs `_resolve_contacts`
   already runs for a hero attacker (`match_state.gd:726-746`), now also reached when the
   ATTACKER address names a unit instead of a hero (`4-3b/R6`).

   PROVEN BY: `test_roll_iframes.gd` and `test_block_deflect.gd` extended with a unit attacker —
   each rung asserted to reach the same outcome it reaches for a hero attacker.

10. **Deflecting a minion does NOT stun it, for now** (`4-3b/R7`), with the explicit intent to
    revisit if it proves worthwhile once minions have movesets. The `stun` field keeps ZERO inbound
    edges (`HeroState.TRANSITION_TABLE`, `hero_state.gd:65` — "accepts no input — and nothing may
    transition IN (E1)"); this story does not open one. The open decision on stun stays open.

    PROVEN BY: `test_block_deflect.gd` negative guard — a deflected unit attack leaves the unit's
    phase state and countdown exactly where the undeflected case leaves them.

11. **Units pay no stamina and no resource to attack** (`4-3b/R8`). Their only limiter is the
    attack rhythm itself — the windup/active/recovery cycle from AC 1 — never a `StaminaPool.spend`
    call or any other economy gate.

    PROVEN BY: `test_unit_attack_rhythm.gd` negative guard — a full unit attack cycle leaves both
    players' stamina and mana pools numerically untouched.

12. **A unit's attack direction LOCKS when its windup begins; it does not keep tracking the target
    until the strike lands** (`4-3b/R9`). Reason: at this stage minions are summon-tier, not
    boss-tier — a swing that misses when the target steps aside during windup/active is the
    intended feel. Late-locking tracking (track until the strike) is explicitly deferred to
    per-kind movesets (`4-4` and beyond), not built here even as a toggle.

    A swing whose target dies or is retargeted mid-windup **COMPLETES INTO EMPTY AIR** (`4-3b/R18`)
    — there is no cancel path, because a cancel would add a second way a swing can end, against the
    no-interruption Non-Goal.

    **THE DIRECTION HAS EXACTLY ONE LEGAL SOURCE, and it is RULED here rather than left to the dev
    pass: the `dir` carried by the SAME fact that most recently set the in-reach flag** (AC 13).
    Measured reason no alternative exists — the direction is needed BY the windup-start decision,
    which happens inside `advance()`; the runner cannot read fresh at that moment because it learns a
    windup began only by polling AFTER `advance()` returns (`match_runner.gd:1020-1064`), a tick
    late, and this story adds no signal that would tell it sooner; the inward channels are
    `push_contact` and `set_camera_basis` and nothing else; and state cannot derive a direction
    itself, because position is actor-owned (`4-3/R2`). **Consequence, by construction: the locked
    direction is up to one throttle interval stale** — the same staleness AC 13's consequence (i)
    names, not a second one. PRECISION, measured: the fact's field is TARGET-to-ATTACKER
    (`"dir": target_to_attacker`, `match_state.gd:463`; computed `attacker - target` at
    `match_runner.gd:896`), so the unit's attack direction is its NEGATION — do not lock a backwards
    swing. IMPLEMENTATION NOTE: because the source fact arrives before the windup, the granted
    "locked attack direction" field holds the LATEST known direction to the acquired target while the
    unit is idle and FREEZES from windup start until the swing ends — that freeze IS the lock, and it
    needs no sixth field. Its encoding is the dev pass's to choose, subject to the board's
    scalar-only rule (`unit_board.gd:43-48`) and to `CanonicalHash` having a branch for whatever type
    is used.

    PROVEN BY: `test_unit_attack_rhythm.gd` — the locked direction is unchanged by moving the
    target after windup start, it matches the negated `dir` of the flag-setting fact, and a swing
    whose target is killed during windup still runs its windows to completion and lands nothing.

13. **A unit begins its windup ONLY when its acquired target is within REACH** (`4-3b/R17a`,
    decided by Matko) — never on a free-running cycle, and never off an "arrived" flag.

    THE MECHANISM (`4-3b/R17b`, ruled at the gate by measurement, NOT an operator decision): the
    reach relation enters state as a fact on the EXISTING `push_contact` intake, carrying a kind
    marker that distinguishes a REACH PROBE from a STRIKE, dropped at the very top of
    `_resolve_contacts` ahead of every other rung — a probe yields no damage, no dedupe
    registration, no `confirmed_hits` entry, no mana and no signal. Its only effect is to permit a
    windup to start. This is legal under `4-3/R2` because it adds NO new inward channel and delivers
    no position and no velocity into state — see Dev Notes for the full measurement.

    **THE PROBE IS THROTTLED, not gathered every tick**: it rides the SAME cadence the minion
    retargeting already uses, off the SAME authored field — `minion_retarget_interval_ticks`, **12
    ticks at the authored `minion_retarget_interval_seconds = 0.2`**
    (`data/balance/balance_config.tres:32`; derivation pinned at `test_balance_config.gd:88-90`).
    No new balance field is authored for it, so the audited field list and its guard are untouched.

    **THE PROBE IS GATHERED REGARDLESS OF THE UNIT'S PHASE — NOT only while it is idle — and state
    keeps a per-unit IN-REACH FLAG** (the fifth granted field, AC 16): the flag is SET by a fact, a
    windup START CONSUMES it, and a unit begins its windup when it is **idle AND the flag is set**.
    This shape is required, not incidental. An idle-only probe would make a unit finishing recovery
    wait up to a full interval for the next probe, so the effective cycle would be
    windup+active+recovery+up-to-one-interval, JITTERING with where the swing happened to land
    relative to the cadence — meaning the authored durations of AC 1 would not describe the observed
    attack rate. A performance decision must not silently retune combat. Stream volume is UNCHANGED
    by this: the throttle, not the idle narrowing, is what buys the reduction.

    **THE FLAG IS SET BY ANY CONTACT FACT THIS UNIT SOURCES AGAINST ITS ACQUIRED TARGET, OF EITHER
    KIND — PROBE OR STRIKE** (`4-3b/R17b` as amended, closing a refresh hole). Gathering through the
    swing is NOT sufficient on its own, and this is the trap: the fact's KIND is decided by PHASE —
    while the active window is open, the same overlap produces a **STRIKE, not a probe** — so a
    throttle tick landing inside a unit's active window would refresh nothing, and after recovery the
    unit would wait for the next probe. That is the same jitter the flag exists to remove, merely
    less often. A landed strike is PROOF of reach, and stronger proof than a probe since it is the
    same overlap test, so counting it closes the hole with no new mechanism and no extra stream
    volume.

    **SCOPED TO THE ACQUIRED TARGET**: only a fact whose TARGET ADDRESS is this unit's own acquired
    target sets the flag. AC 4's cleave makes a swing through a BYSTANDER reachable, and letting that
    refresh "in reach" would keep a unit swinging at a target it has actually lost. Stated
    explicitly because it does NOT follow from AC 4 or AC 13 read in isolation — AC 4 deliberately
    lets a swing touch entities the unit never aimed at, and only the FLAG is scoped here, never
    which targets a cleave may damage.

    TWO CONSEQUENCES, named rather than discovered:
    (i) **The flag can be up to one interval stale** (0.2 s authored, 0.5 s at the authoring band's
    ceiling, `test_balance_authoring.gd:202-212`), so a minion may begin a windup against a target
    that has just left reach and whiff. Consistent with `4-3b/R9` and `4-3b/R18`, which already rule
    a summon-tier swing missing to be the intended feel.
    (ii) **Absence of overlap is NOT a fact and CANNOT clear the flag.** Consumption at windup start
    is the ONLY clearing path — there is no negative probe, and a dev pass must not go looking for
    one.

    PROVEN BY: `test_unit_attack_rhythm.gd` — a unit with an acquired target and NO reach fact
    never leaves idle (the non-vacuous half: a free-running implementation fails exactly here); a
    probe fact alone applies zero damage; the cadence is pinned by a test that counts probes over a
    span of ticks and asserts one per interval, not one per tick (a test that only asserts "a probe
    eventually arrives" would pass against the unthrottled version); **and the back-to-back cycle is
    pinned by measuring the tick gap between two consecutive swings and asserting it equals
    windup+active+recovery exactly, with no throttle remainder added** — the pin that would fail
    against the idle-only variant, and which must be run with the throttle tick falling INSIDE the
    active window, since that is the arrangement the refresh hole lives in. Plus a scoping pin: a
    cleave that touches only a bystander must NOT refresh the flag.

14. **The attacker-side rungs DISPATCH ON ATTACKER KIND, and both current failures are SILENT.**
    Measured: two derived reads in `_resolve_contacts` / `_resolve_unit_contact` assume the
    attacker is a hero, and neither errors for a unit attacker —
    (a) the dead-attacker drop tests `attacker.hero.action_state == DEAD`
    (`match_state.gd:724`, `798`), so a LIVE minion owned by a DEAD hero has every one of its facts
    dropped; and
    (b) dedupe registration calls the OWNER HERO's registrar, `attacker.hero.register_swing_hit(...)`
    (`match_state.gd:733`, `800`), which returns false because a unit never starts a hero swing and
    so never opens a record under that `attack_index` — **every unit hit vanishes with no damage,
    no signal and no error.**
    Both must resolve the ATTACKER'S OWN identity from the widened address of AC 3: a unit
    attacker's liveness is its own board record's, and its dedupe is its own (AC 16).

    PINNED TO FAIL LOUDLY: silent failure is the defect, so each is pinned by a test that asserts
    the POSITIVE outcome (damage applied, `hit_landed` emitted) in exactly the configuration that
    silently swallows it today — a live minion under a dead owner hero, and a unit's first
    registered hit.

    PROVEN BY: `test_contact_resolution.gd` (both rungs, both attacker kinds) and
    `test_unit_damage_and_death.gd` extended.

15. **A unit killed mid-swing lands NOTHING.** Contact facts carry the F1 one-tick lag
    (`match_runner.gd:857`), so a fact gathered while the attacker was alive can arrive after it
    died. The hero ladder already has a dead-attacker drop for exactly this case (`2-3/R6`,
    `match_state.gd:708-725`); the unit side has none — AC 14(a) supplies it, and this AC is what
    proves it does the job.

    THIS IS A POSITIVE PIN, NOT A NEGATIVE CLAIM: the test must show the unit's fact WOULD have
    landed (an identical run where the unit survives applies damage) and then show that killing the
    unit between gather and resolution drops it. A test that would also pass against a unit that
    never attacked at all is vacuous and does not discharge this AC.

    PROVEN BY: `test_unit_damage_and_death.gd` extended (the paired survive/killed runs).

16. **The shipped field shape on the unit record** (`4-3b/R14` as AMENDED at the gate for the
    in-reach flag — the grant is FIVE fields, not four; this story obtains it for itself under
    `4-3a/R6`). **FIVE SCALAR fields** land on `UnitBoard` as PARALLEL ARRAYS on the
    `_hp: Array[float]` precedent (`unit_board.gd:80`), index-aligned, plain scalars, no Dictionary
    and no nested typed array: **phase state, tick countdown, locked attack direction, monotonic
    attack counter, and the in-reach flag** (AC 13). The **DEDUPE HIT LIST does NOT go on the
    board** — it lives in a separate unit-owned state class beside the board, because the board's own
    header rule (`unit_board.gd:43-48`) forbids non-scalar per-record fields and exists to keep
    objects out of the hash. Cost accepted by the ruling: one small new state class. Per-field
    reasons are in Project Structure Notes.

    Accessors match the shape of the existing per-record accessors (`add()` 100-104,
    `is_alive_at()` 203-204, `living_indices()` 240-245) — non-allocating single-value reads, no
    pair-allocating getter in a hot path.

    **THE SNAPSHOT KEY SET MOVES; BY HOW MUCH IS A DEV-PASS MEASUREMENT, NOT A NUMBER THIS STORY
    ASSERTS.** Measured reason it cannot be derived here: the board does NOT nest under one key —
    `PlayerState.to_snapshot()` (`player_state.gd:157-279`) emits three separate top-level board
    keys, and their precedent runs BOTH ways. `unit_hp` is ONE array -> ONE key
    (`hp_snapshot()`, `unit_board.gd:260`), but `unit_targets` fuses **TWO** parallel arrays
    (`_target_slots` + `_target_indices`) into **ONE** key of pairs (`targets_snapshot()`,
    `unit_board.gd:269-270`). So five arrays plus a dedupe structure could legitimately surface as
    anywhere from two keys upward, depending on which fields the dev pass groups as one logical
    fact. The floor is twelve -> at least thirteen; no ceiling is claimed. The contributing fields,
    named so the dev pass measures against a list rather than a guess: **phase state, tick
    countdown, locked attack direction, monotonic attack counter, in-reach flag, and the unit dedupe
    records.** Each must either surface as a key or have a stated reason it does not.

    PROVEN BY: `test_card_observation.gd` — the key set extension recorded as its own deliberately
    named change with the measured count written in, never a number quietly edited in place (that
    file's own standing discipline, `test_card_observation.gd:225-248`);
    `test_unit_attack_rhythm.gd` (round-trip of every new field through `to_snapshot()`); and
    `test_architecture_invariants.gd` (the new class sits under `src/state/` and consults no
    `Input`/`Time`/`OS`/global RNG).

17. **Unit-versus-unit damage falls out of the same opening, with no separate resolution path.** A
    minion dies to another minion in the same number of hits it takes from a hero — both read the
    same `balance.unit_damage_per_hit` / `unit_max_hp` fields `4-3a` authored
    (`resources/balance_config.gd:197, 215`), applied through the same
    `_resolve_unit_contact`-shaped ladder regardless of whether the ATTACKER address names a hero
    or a unit.

    PROVEN BY: `test_unit_damage_and_death.gd` extended (hits-to-kill equal for both attacker
    kinds at the authored values) and `test_unit_combat_live.gd` (two units trading live).

## Non-Goals (explicit)

- **Minion movesets, multiple attacks per minion, or any per-kind differentiation.** Minions still
  share ONE set of attack-rhythm scalars, authored once on `BalanceConfig`. Converting those to
  per-kind data (per the `4-2/R17` forcing point already naming `4-3`/`4-4` as the stories allowed
  to differentiate units) belongs to `4-4`, not here.
- **Totems and projectiles.** Both are named future consumers of the widened, kind-agnostic
  attacker address (AC 3) but neither is built or wired in this story.
- **The melee retune.** Runs as its own non-story block once this story closes (`E3-R/R3`,
  re-anchored by `4-3a/R5`); this story's authored durations/damage values are provisional inputs
  to it, not its output. It also owns the stamina number the multi-minion deflect drain exposes
  (`4-3b/R19`).
- **Fixing own-side body collision.** The `4-3a`-measured case of a minion getting stuck on its
  own summoner (deferred-work.md, annotated by `4-3a/R25`) is ACCEPTED as-is (`4-3b/R11`) and
  stays deferred with a new owner — NOT discharged here.
- **`approach()` gaining an "arrived vs. physically obstructed" distinction.** AC 13's reach-fact
  trigger removes this story's NEED for that distinction rather than building it — `approach()` is
  not edited by this story. The residual gap (an obstructed unit still has no designed behaviour)
  stays open in `deferred-work.md` under a new owner.
- **A round-over gate on the runner's unit polls.** Measured and recorded as `4-3b/R20`, owner
  unassigned: the runner's `_physics_process` gates only on the DEBUG pause
  (`match_runner.gd:951-953`), so `_aim_unit_actors` / `_approach_unit_actors` keep running after a
  round ends and units keep walking. Inherited from `4-3`, not introduced here; this story makes it
  visibly odd (a frozen swing on a walking body) but does not fix it.
- **Stagger, poise, or interrupting a minion's swing by damage.** A minion's windup/active/recovery
  cycle runs to completion regardless of damage taken mid-swing; no hero attack (or another
  minion's attack) can cancel it. DISTINCT from AC 15: damage does not interrupt a swing, but
  DEATH ends the attacker.
- **Per-hit feedback on a damaged (not yet dead) unit, deferred from `4-3a`
  (`deferred-work.md`, `4-3a/R12`).** Still not this story's — a unit hitbox and unit-vs-unit
  damage are a different surface than a HUD/VFX signal for "this unit was hit but did not die,"
  which stays a separate, still-open item.
- **A third scope split.** Ruled out by `4-3b/R12`: the split criterion named in advance was "only
  if the hero dedupe must relocate", and measurement says it must not.

## Open Questions

The readiness gate ruled four of the five this story was authored with; their answers are now
statements in the ACs and Dev Notes above (`4-3b/R12`-`R22`), not questions the dev pass re-asks.
What genuinely remains:

1. **The exact windup/active/recovery durations, the reach distance, and the unit-vs-unit damage
   numbers.** AC 1 authors PROVISIONAL values. The real numbers belong to the melee retune block
   that runs after this story closes (Non-Goals, `E3-R/R3`); the dev pass authors something
   playable and does not treat it as tuning.
2. **Conditional, and only if Part 0's measurement turns out wrong at the dev pass:** if the reach
   fact ends up changing the CHANNEL SET rather than the row shape, `RecordFile`'s required-key set
   moves too and `4-3b/R21`'s `FORMAT_VERSION` ruling is amended at the dev pass rather than
   applied. Measured expectation: it does not — the kind marker rides the existing row.

## Tasks / Subtasks

- [ ] Author three provisional `BalanceConfig` fields (`minion_attack_windup_seconds`,
      `minion_attack_active_seconds`, `minion_attack_recovery_seconds`) plus the reach distance, and
      their `BalanceTicks` counterparts; extend `E1_BALANCE_FIELDS` (AC 1)
- [ ] Add the five parallel scalar arrays to `UnitBoard` and the new unit-owned dedupe state class
      beside it, with non-allocating accessors; MEASURE the resulting snapshot key count rather than
      assuming it, and record it as a named extension in `test_card_observation.gd` (AC 16)
- [ ] Widen `push_contact` / `capture_push_contact` / `replay_push_contacts` / `_rebuild_contacts`
      so the ATTACKER parameter is a kind-agnostic `[slot, index]` pair; preserve every existing
      hero-attacker call site under `[slot, -1]` with a non-vacuous regression pin (AC 3)
- [ ] Add the kind marker to the fact row and the top-of-ladder probe drop, and gather the probe on
      the EXISTING `minion_retarget_interval_ticks` cadence (12 ticks authored) via a runner-local
      counter — no new balance field, no new public tick accessor (AC 13, `4-3b/R17b`)
- [ ] Wire the in-reach flag: SET by ANY fact this unit sources against its ACQUIRED TARGET, probe
      or strike (a bystander cleave must not set it), CONSUMED at windup start, cleared by nothing
      else; windup begins on idle AND flag set. Pin the back-to-back cycle at exactly
      windup+active+recovery with no throttle remainder, with the throttle tick inside the active
      window (AC 13)
- [ ] Add a per-unit attack state machine (windup -> active -> recovery, no chain, no input —
      AI-driven) seated in `advance()`'s existing step-3 family, triggered by the reach fact
      (AC 1, AC 13)
- [ ] Add a unit Hitbox `Area3D` to `unit_actor.tscn` on the EXISTING layer 3 "hitbox" / mask 2
      "hurtbox" convention (`hero.tscn:73-77`); no `project.godot` or `hero.tscn` edit (AC 2)
- [ ] DEV PASS CORRECTION, same file: the `Collision` node's `editor_description`
      (`unit_actor.tscn:20`) still asserts "there is deliberately NO hurtbox and NO Area3D on this
      scene" — false since `4-3a` shipped the `Hurtbox` node directly below it (lines 22-31), whose
      own description already records that it discharged that promise. Correct the stale sentence
- [ ] Extend `_gather_contact_facts` (or add a unit-attacker sibling) so a unit's active hitbox and
      its reach probe enter through the SAME `push_contact` intake, stamped with the widened
      attacker address, in the canonical cross-attacker order (AC 2, AC 3, AC 5, AC 13)
- [ ] Implement cleave + canonical-order dedupe registration for a unit attacker, on the
      `4-3a/R22` sort-on-insertion precedent (AC 4)
- [ ] Dispatch the dead-attacker drop and dedupe registration on ATTACKER KIND, both ladders
      (AC 14), and pin the killed-mid-swing drop positively (AC 15)
- [ ] Add the gather-time friendly-fire filter for the unit-attacker side (owner-slot based,
      never collision-layer based) (AC 6)
- [ ] Keep unit-sourced confirmations out of `confirmed_hits` so step 5 pays no mana (AC 7)
- [ ] Confirm `hit_landed` fires when a unit damages a hero and not when a unit damages a unit —
      the `4-3a/R12` asymmetry — WITHOUT widening either signal payload (AC 3, AC 8)
- [ ] Route a unit-attacker fact against a hero target through the hero's full defensive ladder
      (iframe, deflect, block) unchanged (AC 9)
- [ ] Confirm no stun edge opens on a deflected minion attack (AC 10, negative guard)
- [ ] Confirm/guard that no `StaminaPool.spend` or resource cost gates a unit's attack (AC 11,
      negative guard)
- [ ] Implement direction-lock-at-windup, and the complete-into-empty-air path for a target that
      dies or is retargeted mid-windup (AC 12)
- [ ] Bump `FORMAT_VERSION` 3 -> 4 per `4-3b/R21`, hard rejection of older records, no shim
- [ ] DEV PASS CORRECTION: `hero_state.gd:134-144`, the `_swing_dedupe` docstring still documents
      each record as `{"hit": Array[int] of target slots}` — false since `4-3a` widened the key to
      full `[slot, index]` addresses, and the neighbouring `register_swing_hit` docstring already
      states the correct shape ("THE HIT LIST THEREFORE HOLDS PAIRS, NOT INTS", line 244). This
      story rewrites that mechanism for a second attacker kind, so it is the right place to fix it
- [ ] Extend `to_snapshot()` for the new unit attack state; measure the golden and the snapshot key
      set in both directions per Golden Prediction
- [ ] Measure `project.godot` / `hero.tscn` byte-identity (Golden Prediction)
- [ ] Write unit-vs-unit damage tests: same hits-to-kill from a unit attacker as from a hero
      attacker, at the authored values (AC 17)
- [ ] Write live integration coverage for a minion's live attack against a hero and against
      another minion, discharging the R-D6 re-invocation (Live Smoke)

## Dev Notes

- **THE REACH TRIGGER IS LEGAL UNDER `4-3/R2`, MEASURED AT THIS GATE, NOT ASSUMED** (AC 13,
  `4-3b/R17b`). `4-3/R2` closed unit position ownership and rejected two alternatives BY NAME: an
  inward direction-fact channel feeding a state-owned per-unit VELOCITY, and state-owned position
  floats. It also AFFIRMED that "`push_contact` remains the only inward intake (1-8)". Measured
  against this tree:
  - The contact fact's fourth field is already position-DERIVED spatial data:
    `match_runner.gd:895-904` computes `actor.global_position - target_actor.global_position`,
    planarises it to `Vector2(x, z)`, drops the degenerate case and normalises; `push_contact`'s
    own docstring (`match_state.gd:421-422`) says "computed by the runner FROM POSITIONS ONLY". So
    position-derived spatial data ALREADY enters state legally through this intake. What R2 bans is
    state OWNING position (or a velocity derived inward through a NEW channel).
  - No other runner-to-state channel carries spatial information. The throttled targeting
    (`_update_unit_targets` / `_retarget_units`, `match_state.gd:1280-1330`) consumes a
    `MinionPriority`, an opposing slot int, an `opposing_hero_alive` bool, an `Array[int]` of living
    indices, and `FeatureFlags` — nothing spatial, as that function's own header states.
  - VERDICT: a narrow "this unit's reach volume overlaps its acquired target" fact on the EXISTING
    `push_contact` intake falls INSIDE the ruling. It pays no new intake, and it delivers neither a
    position nor a velocity — state learns a relation, not a location.
  - COSTS, named so the dev pass does not discover them: (i) STREAM VOLUME, **and this is why the
    probe is THROTTLED** (`4-3b/R17b`). A strike fact exists only during an active window; an
    UNTHROTTLED probe would exist on every tick a unit stands in range — one row per tick per
    in-range unit, i.e. **up to 16 rows/tick, ~960 rows/second** at `4-5`'s 16-unit criterion,
    against today's sparse per-swing bursts. On the existing 12-tick interval that falls to
    **~1.33 rows/tick, ~80 rows/second** — a 12x reduction, and both figures are recorded here so
    the dev pass sees what the throttle buys. **The probe runs regardless of the unit's phase, and an
    idle-only narrowing is REJECTED** (`4-3b/R17b`): it would leave a unit waiting up to a full
    interval after recovery, retuning the observed attack rate behind AC 1's authored durations. The
    throttle, not the idle narrowing, is what buys the reduction, so nothing is lost by dropping it.
    IMPLEMENTATION NOTE: the probe pass is gathered in
    the RUNNER, which has no public accessor for the state tick (`_tick` is private,
    `match_state.gd:91`, surfaced only inside `to_snapshot()`), so the cadence is a runner-local
    counter reading the SAME authored interval — a new public tick accessor on `MatchState` is NOT
    taken for this. That is replay-safe for exactly the reason today's overlap facts are: the fact
    is TAPPED and replayed from the record, never regenerated through physics on replay
    (`match_runner.gd:900-906`, the `3-0c` AC 9 fork). (ii) A KIND
    MARKER IS REQUIRED — `_resolve_contacts` treats every queue entry as a landed strike, so an
    unmarked probe would deal damage; the fact dictionary gains a sixth field and the recorded row
    grows from five positional elements to six. (iii) DROP RUNG — the probe is dropped at the TOP
    of `_resolve_contacts`, ahead of the dead-target drop: no damage, no `register_swing_hit`, no
    `confirmed_hits` entry, no mana, no `hit_landed`/`deflect_landed`, never reaching
    `_resolve_unit_contact`. The F1 one-tick lag applies to a probe exactly as to a strike, so a
    windup starts the tick AFTER reach is observed. (iv) FORMAT VERSION — one shape-only bump,
    3 -> 4; the marker rides the existing row, so the channel set and `RecordFile`'s required-key
    set do NOT move.
- **THE FOUR SITES THAT READ `fact["attacker"]`, re-derived by content search against this tree**
  (this is the dev pass's work list for the widening, and the pre-gate list was wrong in both
  directions): `match_state.gd:693` (`var attacker := p1 if int(fact["attacker"]) == 0 else p2` —
  the one that resolves the attacker at all, and the one both ladders inherit), `741` (the
  `deflect_landed` emit bind), `746` (the `hit_landed` emit bind), `747`
  (`confirmed.append(int(fact["attacker"]))` — the mana list). The pre-gate list also named `707`
  and `724`: NEITHER reads that field — `707` is the `continue` of the dead-TARGET drop and `724`
  is `attacker.hero.action_state == DEAD`, which reads the resolved `PlayerState` from `693`, not
  the fact. Note that `733` and `800` read `fact["target"]`, not `fact["attacker"]`.
- **Read before touching, `src/state/hero_state.gd`**: `windup`/`active`/`recovery` `TimingWindow`
  triplet (104-106), `attack_phase()` (283-294) deriving the phase from which window runs, never a
  stored enum, `is_hitbox_active()` (201-202, `active.is_running`), the `_swing_dedupe` field and
  its docstring (134-144), and `register_swing_hit()` — **the FUNCTION is 264-273; 223-263 is its
  doc block**, which is where `4-3a/R22`'s canonical-order sort-on-insertion is explained
  (`hit.append(address)` then `hit.sort()`, 271-272). A unit's own attack-rhythm state mirrors this
  SHAPE (windows, phase derived not stored) adjusted for `UnitBoard` being a plain-array container
  rather than an object with its own signals (units have no per-record signal today,
  `unit_board.gd`'s own header).
- **Read before touching, `src/state/match_state.gd`**: `advance()`'s full step order (178-306);
  `_resolve_actions` (541-577) and `_try_transition` (584-641) — the hero's INPUT-DRIVEN transition
  evaluation, which a unit's AI-driven rhythm does NOT reuse wholesale (no `InputIntent`, no
  `TRANSITION_TABLE` row, no stamina spend, no chain) but whose WINDOW-ADVANCE SHAPE
  (`match hero.attack_phase(): &"windup_done": ... &"active_done": ...`, 552-559) is the precedent
  for driving a unit's own phase transitions once its windows exist. `push_contact` (442-464);
  `_resolve_contacts` (**the function is 685-749**, doc block 663-684) and `_resolve_unit_contact`
  (**789-812**, doc block 752-788) — the TARGET-side widening `4-3a` shipped; this story widens the
  ATTACKER side of the same fact dictionary. `_generate_mana` is at **846-862** (doc block
  827-845) — the pre-gate AC 6 cited `733-750`, which is inside `_resolve_contacts`, not this
  function at all.
- **Read before touching, `src/main/match_runner.gd`**: `_gather_contact_facts` (858-906) — hero
  attacker only today (`attacker_slot: int` param, called at 1009-1010 for `_p1_hero`/`_p2_hero`
  ONLY); a unit attacker needs an analogous gather pass over every spawned, alive `UnitActor` whose
  own hitbox is active, in the SAME physics-frame family (`_physics_process`, 944+), seated at a
  FIXED position relative to those two calls (AC 5). `_address_of` (925-933) already resolves
  `owner_actor` -> `[slot, index]` for BOTH heroes and units — this is the exact function AC 3's
  kind-agnostic ATTACKER address should reuse for identifying the attacker, not a new hero/minion
  branch. `_target_world_position` (753-761) is the one place a `[slot, index]` becomes a world
  position and is the natural seat for the reach measurement; `_approach_unit_actors` (715-743) is
  the existing distance-computation precedent — do not reintroduce a second distance computation if
  one can be shared. `_free_dead_unit_actors` (657-666), `_aim_unit_actors` (681-695) — the
  existing per-frame unit polls this story's own poll should match in shape (bounded by the actor
  array, board-index checked, `is_instance_valid` guarded, no allocation in the hot path per
  project-context's Performance Rule).
- **Read before touching, `src/actors/hero/hero.tscn`**: Hitbox (`Area3D`, `collision_layer = 4`,
  `collision_mask = 2`) at lines 73-77 — the EXACT layer/mask a unit's new Hitbox should be
  authored on. This file is READ-ONLY reference; predicted byte-identical.
- **Read before touching, `src/actors/minions/unit_actor.tscn` / `unit_actor.gd`**: `4-3a` shipped
  a `Hurtbox` (`Area3D`, `collision_layer = 2`, `collision_mask = 0`, `monitoring = false`) as the
  node at lines 22-26, with its `CollisionShape3D` child at 28-31. **The STALE claim is on a
  DIFFERENT node**: the `Collision` node's `editor_description` (line 20) still ends "there is
  deliberately NO hurtbox and NO Area3D on this scene - a unit takes no damage until 4-3a ships
  one", which the `Hurtbox` directly below it falsified — and that `Hurtbox`'s own description
  already says it "discharges the promise the Collision node's own description made". Correcting
  line 20 is DEV PASS work (Tasks), not this docs pass's. This story adds the HITBOX half on layer
  3 (`collision_layer = 4`, `collision_mask = 2`), mirroring `hero.tscn`'s Hitbox node shape
  exactly including its `monitorable = false` and child `CollisionShape3D`. `unit_actor.gd` carries
  NO gameplay logic today (`aim_at`/`approach`, pure geometry) — this story's own state stays in
  `src/state/`, not here (HARD RULE, state/visual separation).
- **Read before touching, `src/state/unit_board.gd`**: the file's own header states the `hp`
  permission (`4-3a/R6`) was spent on EXACTLY ONE FIELD; this story's own grant is `4-3b/R14`
  (AC 16). `_hp: Array[float]` (80) is the shape precedent for the four new parallel arrays (plain
  scalar, index-aligned, no Dictionary, no nested typed array, no StringName — the file's own
  header reasoning, 43-48), and that same header rule is WHY the dedupe hit list may not join them.
  `add()` (100-104), `living_indices()` (240-245), `is_alive_at()` (203-204) are the existing
  per-record accessors a new field's accessors should match in shape.
- **WHY THE UNIT'S DEDUPE DOES NOT MOVE OFF HERO STATE, measured** (`4-3b/R12`, and the reason
  this story does not split a third time). A unit cannot SHARE the hero's monotonic
  `attack_index`: it is incremented only when a hero starts a swing and it is snapshotted, so
  driving it from unit swings would change hero-observed values — an unnamed golden cause. A unit
  cannot SHARE the hero's `_swing_dedupe` records either: their grace lifetime is driven by the
  HERO's own active window (`grace` -1 while the hero's window runs, 1 for one tick after it
  closes, erased at 0 — `hero_state.gd:134-144`), which has nothing to do with a unit's window. So
  the unit gets its OWN counter and its OWN records, and the hero side is untouched.
- **Read before touching, `src/state/resources/balance_config.gd`**: `attack_windup_seconds` /
  `attack_active_seconds` / `attack_recovery_seconds` (33-35) — the exact precedent AC 1's three
  new minion fields mirror; `unit_max_hp` / `unit_damage_per_hit` (197, 215) — the existing
  `@export_group("Minions")` fields AC 17 reuses without a new damage value.
- **Read before touching, `src/state/timing/balance_ticks.gd`**: `attack_windup_ticks` /
  `attack_active_ticks` / `attack_recovery_ticks` and their `from_config()` conversion (46-48,
  70-72) — the load-time-derived tick-domain precedent AC 1's counterparts follow verbatim (plain
  `TimingWindow.seconds_to_ticks()`, no special clamp needed unless the gate rules otherwise).
- **Read before touching, `src/systems/intent_recorder.gd`**: `capture_push_contact` (194-199) —
  the five-element positional row (`[attacker_slot, target[0], target[1], attack_index, dir]`)
  which AC 3 widens by the attacker's own index and AC 13 widens again by the kind marker;
  `replay_push_contacts` (372-380) is the matching rebuild that must widen in lockstep.
  `FORMAT_VERSION` documentation at 187-193 is the precedent for how a shape-only bump (no new
  capture channel) is worded — including its explicit "THE CHANNEL SET IS UNCHANGED" clause, which
  this story's bump can reuse verbatim.
- **Read before touching, `src/systems/record_file.gd`**: `FORMAT_VERSION := 3` (99), the refusal
  path at version mismatch (218-221), `_rebuild_contacts`'s fixed-position row rebuild (389-394)
  that must widen with `capture_push_contact`.
- **`4-2/R2` / `4-3a` target-address widening** is the ONE precedent to imitate structurally for
  AC 3 — read `4-3a-minion-damage-and-death.md` AC 3 and its Dev Notes in full before designing the
  attacker-side widening; the two widenings should read as one convention applied twice, not two
  different conventions.
- **THE MULTI-MINION DEFLECT DRAIN IS AN ACCEPTED, NAMED CONSEQUENCE** (`4-3b/R19`), not a
  discovery for live smoke. AC 9 keeps the hero's defensive ladder unchanged, and deflect spends
  the deflect cost PER FACT (`match_state.gd:739-742`), so several minions attacking one hero in
  the same tick drain stamina several times and the later facts degrade to blocked damage once the
  spend fails (the R-N7 multi-deflect edge, already shipped). Nobody CHOSE this number; it is
  recorded rather than left to surface live. Owner of the number: the melee retune block.
- **THE OWN-SIDE COLLISION CITATION, corrected, and a RATIFIED RULING REVERSED.** The deferred
  own-side collision item is annotated by `4-3a/R25`. The ruling that named `4-3b` as the FORCING
  POINT to teach `approach()` the "arrived vs. physically obstructed" distinction is a LATER one
  from the same close-out — **`4-3a/R29`** ("The cheaper fix has an owner: `4-3b` teaches
  `approach()` to distinguish 'arrived' from 'physically obstructed' … Forcing point: `4-3b`").
  That assignment is **REVERSED** by the operator's two newer rulings: `4-3b/R10`/`R17a` remove the
  distinction's only consumer from the attack path instead of building it, and `4-3b/R11` keeps
  own-side collision deferred with a NEW owner. Recorded explicitly here and in `deferred-work.md`
  because an unrecorded reversal of a ratified ruling is how the log stops being authority.
- **`FeatureFlags.minions`** already gates whether units exist at all (`4-1`/`4-2`); this story
  adds no new flag — a minion with the flag on but no reach fact yet is simply idle, matching the
  unit's existing pre-`4-3` "does nothing" default.

### Project Structure Notes

- `src/state/resources/balance_config.gd`: three new minion attack-rhythm duration fields plus the
  reach distance (AC 1, AC 13).
- `src/state/timing/balance_ticks.gd`: three new derived tick counterparts (AC 1).
- `src/state/unit_board.gd`: five new parallel scalar arrays (AC 16, `4-3b/R14` as amended), each
  with its own reason —
  - **phase state**: which of windup/active/recovery (or idle) a unit is in. On the board rather
    than derived, because unlike the hero there are no per-unit `TimingWindow` OBJECTS to derive
    from — objects on a per-record field are what `unit_board.gd:43-48` forbids.
  - **tick countdown**: ticks remaining in the current phase. Crosses ticks and decides an outcome,
    so it is snapshotted (`4-3a/R17`'s standing reasoning).
  - **locked attack direction**: the direction captured at windup start (AC 12). Stored because
    the whole point of the lock is that it must NOT be recomputed later.
  - **monotonic attack counter**: the unit's own `attack_index` equivalent, keying its dedupe
    records. Its own, not the hero's — see the measurement in Dev Notes.
  - **in-reach flag**: set by a throttled reach probe, consumed when a windup starts (AC 13,
    `4-3b/R17b`). Stored because the probe and the windup happen on DIFFERENT ticks — the flag is
    precisely the cross-tick carrier between them — and because it is what lets the next swing begin
    the instant recovery ends instead of waiting on the next probe. No negative probe clears it.
- `src/state/` (new, small): the unit-owned dedupe records class holding the per-swing HIT LIST,
  beside the board rather than on it — the board's own header rule forbids non-scalar per-record
  fields, and that rule exists to keep objects out of the hash.
- `src/state/match_state.gd`: `push_contact` attacker-address widening and kind marker (AC 3,
  AC 13); the probe drop at the top of `_resolve_contacts`; a unit-attacker phase-advance seat
  inside `advance()`; attacker-kind dispatch on the dead-attacker drop and dedupe registration in
  BOTH ladders (AC 14, AC 15); unchanged `_generate_mana` with the gate staying upstream (AC 7).
- `src/state/hero_state.gd`: no mechanism change — the `_swing_dedupe` docstring correction only
  (Tasks).
- `src/main/match_runner.gd`: a unit-attacker gather pass (new function or `_gather_contact_facts`
  extension) reusing `_address_of`, at a fixed seat in canonical cross-attacker order (AC 2, AC 3,
  AC 5, AC 6); the reach measurement, sharing `_target_world_position` math (AC 13).
- `src/actors/minions/unit_actor.tscn`: new Hitbox `Area3D` on the EXISTING layer 3 "hitbox"
  (AC 2), plus the stale `Collision` `editor_description` correction (Tasks).
- `src/systems/intent_recorder.gd` / `src/systems/record_file.gd`: widened contact row,
  `FORMAT_VERSION` 3 -> 4 (`4-3b/R21`).
- `data/balance/balance_config.tres`: the new provisional values (AC 1).
- `test/state/`, `test/integration/`: new and extended tests per AC, following the `4-3a`
  mutation-proof and live-test conventions.

**NOT expected in Project Structure Notes: `src/actors/hero/hero.tscn`, `project.godot`.** Both
predicted byte-identical — a claim to be MEASURED, see Golden Prediction.

### Project Context Rules

- **F1 — one `_physics_process`, in the runner.** A unit's attack-rhythm advance is decided inside
  `advance()`; the runner's `_physics_process` only gathers facts and drives actors, exactly as it
  already does for the hero. [Source: project-context.md:39; CLAUDE.md]
- **D3(b)/A2 — no physics query, no nondeterministic source in `src/state/`.** The unit hitbox
  overlap query AND the reach measurement stay in `match_runner.gd`; `src/state/` receives only the
  resulting pure-data facts, exactly as the hero's contact fact already works.
  [Source: project-context.md:56]
- **A1 — gameplay-critical timing counts integer ticks.** The unit attack rhythm counts ticks,
  advanced one per `advance()`, never a float accumulator or engine `Timer`.
  [Source: project-context.md:60]
- **CONSTRAINT C — read balance/injected values inline, never cache.** The new durations, the reach
  distance and their `BalanceTicks` counterparts are read at point of use exactly like every
  existing balance field. [Source: project-context.md:51]
- **HARD RULE — state/visual separation.** The unit Hitbox reports contact; it never applies
  damage. `unit_actor.gd` gains no gameplay logic. [Source: project-context.md:69-73]
- **HARD RULE — feature flags.** No new flag is introduced; the existing `minions` flag already
  gates unit existence. [Source: project-context.md:83-86]
- **Data as Resources — no hardcoded gameplay numbers.** The new durations and reach distance are
  `.tres`-authored on `BalanceConfig`, never literals in `match_state.gd`.
  [Source: project-context.md:62-64]
- **Collision layers (3D physics) convention** — the unit Hitbox is authored on the EXISTING layer
  3 "hitbox" (bit value 4) / mask layer 2 "hurtbox" (bit value 2); no new layer, no
  `project.godot` edit. [Source: project-context.md:75-81]
- **Performance Rules** — no per-frame allocation in the unit-attacker gather / reach hot path;
  minion target acquisition stays on the existing throttled tick, unaffected by this story. The
  reach probe RIDES that same throttle rather than running per-tick (`4-3b/R17b`), which is what
  keeps its stream volume at ~1.33 rows/tick instead of ~16 at the 16-unit criterion — both figures
  measured in Dev Notes. [Source: project-context.md:88-96]

### References

- [Source: decision-log.md Session 2026-08-10 "4-3b story authoring rulings", `4-3b/R1`-`R11`]
- [Source: decision-log.md Session 2026-08-11 "4-3b readiness gate", `4-3b/R12`-`R22`; note `R17`
  is split — `R17a` is the operator's BEHAVIOURAL call, `R17b` is this gate's MECHANISM ruling,
  including the probe throttle]
- [Source: decision-log.md Session 2026-08-10 "4-3 scope split", `4-3/R2` (unit position ownership
  CLOSED — the ruling Part 0's reach-trigger measurement is tested against), `4-3/R6`]
- [Source: decision-log.md Session 2026-08-10 "4-2 close-out", `4-2/R2`, `4-2/R3` (slot-then-index
  tie-break), `4-2/R17` (condition (c), the differentiating-field permission)]
- [Source: decision-log.md Session 2026-08-10 "4-3a scope split", `4-3a/R1`, `4-3a/R5`]
- [Source: decision-log.md Session 2026-08-10 "4-3a readiness gate", `4-3a/R6` (permission spent on
  `hp`; `4-3b` receives NO advance permission), `4-3a/R8`-`R21`]
- [Source: decision-log.md Session 2026-08-10 "4-3a close-out", `4-3a/R22` (canonical-order
  dedupe), `4-3a/R25` (own-side collision, annotated deferred-work item), `4-3a/R29` (named `4-3b`
  as the `approach()` forcing point — REVERSED, see Dev Notes), `4-3a/R27` (falsified dedupe-key
  golden cause)]
- [Source: docs/implementation-artifacts/4-3a-minion-damage-and-death.md — full file, especially
  AC 3, Dev Notes, Golden Prediction, "What this story supersedes", story_note in
  sprint-status.yaml]
- [Source: docs/implementation-artifacts/deferred-work.md — the rewritten `approach()`
  obstruction item and its new owner]
- [Source: src/state/hero_state.gd:104-111 (windows), 134-144 (`_swing_dedupe`), 264-273
  (`register_swing_hit`), 283-294 (`attack_phase`)]
- [Source: src/state/match_state.gd:30, 37 (signal signatures), 178-306 (advance() step order),
  442-464 (push_contact), 541-641 (_resolve_actions/_try_transition), 685-749 (_resolve_contacts),
  789-812 (_resolve_unit_contact), 846-862 (_generate_mana), 1280-1330 (throttled targeting)]
- [Source: src/main/match_runner.gd:657-761 (unit actor polls, `_target_world_position`), 858-941
  (_gather_contact_facts, _address_of, _slot_of), 944-1098 (_physics_process)]
- [Source: src/actors/hero/telegraph_controller.gd:93-95, 108-110 (both signal consumers gate on
  target slot and underscore the attacker)]
- [Source: src/actors/hero/hero.tscn:73-91 (Hitbox/Hurtbox)]
- [Source: src/actors/minions/unit_actor.tscn:20 (the stale Collision description), 22-31
  (the shipped Hurtbox)]
- [Source: src/state/unit_board.gd:43-48 (the scalar-only header rule), 80 (`_hp` shape)]
- [Source: src/state/resources/balance_config.gd:33-35, 197, 215]
- [Source: src/state/timing/balance_ticks.gd:46-48, 70-72]
- [Source: src/systems/intent_recorder.gd:181-199, 372-380; src/systems/record_file.gd:99,
  218-221, 389-394]
- [Source: test/state/test_data_resources.gd:15-131 (the reflection-based balance field guard)]
- [Source: docs/project-context.md (F1, D3/A2, A1, CONSTRAINT C, HARD RULEs, collision layers,
  Performance Rules)]

## Golden Prediction

**THE GOLDEN FIXTURE STRUCTURALLY CANNOT REACH A UNIT ATTACK, and that changes what is even
measurable here.** Measured against `test/state/test_determinism.gd`: the fixture runs `MatchState`
ALONE — no runner, no physics, no `Area3D`, no overlap query; its contact facts are HAND-AUTHORED
literals pushed straight through the seam (`ms.push_contact(fact[0], [fact[1], -1], fact[2],
fact[3])`, line 1232 — note every authored attacker is a HERO and every authored target is a hero);
and its single unit is summoned by the t22 cast, two ticks before the hash at t24. A unit in that
fixture has no hitbox to overlap, nothing to overlap with, and no reach fact, so it cannot windup,
cannot swing and cannot register a hit.

CONSEQUENCES, recorded rather than left to be rediscovered:

- **The ONLY reachable cause in the fixture is a snapshot KEY or SHAPE change** — the new unit
  attack state (AC 16: five parallel arrays plus the unit dedupe records). A value that crosses
  ticks and decides an outcome does not sit outside the hash (`4-3a/R17`), so the fixture's one
  summoned unit contributes its idle-but-present attack state to the hash from t22. **This is the
  expected mover.**
- **The per-player snapshot key set is EXPECTED TO MOVE UPWARD FROM TWELVE, and this story
  deliberately does NOT assert the new number** — it is a dev-pass measurement. Measured reason:
  the board's own precedent runs both ways, one array -> one key for `unit_hp` but TWO arrays -> ONE
  fused key for `unit_targets` (`unit_board.gd:260, 269-270`), so the count depends on how the dev
  pass groups fields into logical facts. Six candidate contributors, named in AC 16: phase state,
  tick countdown, locked attack direction, monotonic attack counter, in-reach flag, unit dedupe
  records. At least one new key (floor thirteen); no ceiling claimed. The measured count is recorded
  as its own deliberately named extension in `test_card_observation.gd`, never a number quietly
  edited in place.
- **The widened attacker parameter is a predicted NON-MOVER, and that is provable rather than
  asserted**: every hand-authored fact in the fixture is a hero attacker, and `[slot, -1]` resolves
  through the widened form to the identical `PlayerState` and the identical hashed outcomes the
  bare int produced. The kind marker on the fact row is likewise a non-mover — facts are per-tick
  and never snapshotted.
- **The dedupe cause `4-3a` measured and falsified is predicted FALSIFIED AGAIN, for a STRONGER
  reason than there.** `4-3a/R27` falsified it because every `swing_dedupe` record had EXPIRED by
  t24. Here the reason is stronger: the unit's dedupe records **cannot exist at all** by the hash
  tick, because the fixture's unit never swings. **Measure it anyway and say so** — a prediction
  recorded and then not measured is how `4-3a`'s own gate got its prediction reversed.
- **Causes UNREACHABLE in the fixture, and therefore proven by unit and integration tests
  instead**: the phase progression through real tick counts, cleave and its canonical order (AC 4),
  cross-attacker ordering (AC 5), the friendly-fire gather filter (AC 6), attacker-kind dispatch
  (AC 14), the killed-mid-swing drop (AC 15), and the reach trigger INCLUDING ITS THROTTLED CADENCE
  (AC 13 — the fixture has no runner, so the probe pass never runs there at all). Named here so
  nobody reads a green golden as coverage of them.
- **THE FIXTURE IS NOT EXTENDED** (`4-3b/R22`) — the same reasoning `4-3a` used when it declined.
  Extending it to reach a unit attack would mean giving the fixture physics or a synthetic hitbox,
  which makes the determinism golden depend on the very machinery `D3(b)`/`A2` keep out of
  `src/state/`.

ALSO MEASURED IN BOTH DIRECTIONS AT THE DEV PASS, beside the golden claim: **`project.godot` and
`src/actors/hero/hero.tscn` byte-identity.** Expectation: both stay byte-identical — layer 3
"hitbox" already exists (`hero.tscn:73-75`) and a unit's Hitbox is authored on it exactly as
`4-3a`'s unit Hurtbox was authored on the existing layer 2 (`4-3a/R11`); `unit_actor.tscn` is the
file that changes. A claim to be measured, not asserted.

`FORMAT_VERSION` 3 -> 4 (`4-3b/R21`), shape-only, hard rejection of older records, no shim.

BEFORE, for this gate pass: `GOLDEN := "35c38c0ef8008258a5c7ee614487ff92ca825866681f53636f865b83659321b9"`
(`test/state/test_determinism.gd:408`, unmoved since `4-3a`'s single re-baseline). Per-player
snapshot key set BEFORE: twelve (`test_card_observation.gd:249-252`). Suite BEFORE: 465 state tests
/ 3621 assertions, 0 failed, plus 29 integration files, all PASS (measured at `4-3a`'s close-out) —
the dev pass re-measures this itself rather than trusting the figure carried here.

## Live Smoke

**REQUIRED**, Tier A default. `R-D6` is RE-INVOKED by this story and is currently UNSPENT
(`4-3a`'s story_note: "R-D6 NOT spent, stays available"). **A minion killing a hero is the FIRST
hero death this project has not caused with a hero** — the shipped default `slot_controller_kinds`
is already `[0, 1]` (two live killable human slots, per `2-3`), so no temporary flip is required to
exercise it live.

Script, at minimum (subject to correction once the dev pass's actual behaviour is measured, on the
`4-3a/R12` precedent of correcting the script against measured reality): a summoned unit stands
idle until it closes to reach, then begins its rhythm; its windup/active/recovery is visually
legible even on the grey box; a unit's attack against a hero who does nothing lands and the hero's
hp visibly drops (`hit_landed` fires, per AC 8); a hero rolling through a minion's active window
takes no damage; a hero blocking/deflecting a minion's attack behaves exactly as it does against
another hero; **two minions attacking one hero in the same window — the stamina drain of deflecting
both is watched deliberately (`4-3b/R19`), not discovered**; a unit whose target dies mid-windup
completes its swing into empty air; two units set against each other trade damage and one dies in
the same number of hits a hero would need; a unit's attack generates no mana for its owner; a hero
left undefended against a summoned unit can actually be killed by it. Also worth a look, though
this story does not own it (`4-3b/R20`): what units do after the round ends.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 — authoring pass, 2026-08-11.
Claude Opus 5 — readiness gate pass, 2026-08-11.

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Author | Change |
|---|---|---|
| 2026-08-11 | Claude Sonnet 5 | Story authored via `gds-create-story`, inheriting the `4-3b` scope split from `4-3a-minion-combat` (`4-3a/R1`) and the eleven pre-ratified authoring rulings (`4-3b/R1`-`R11`, decision-log Session 2026-08-10). Five Open Questions left explicitly unruled for the readiness gate, most expensive named as the unit-record field shape / dedupe location. Golden Prediction states a preliminary mover claim, TBD pending the gate. Status left at `authored`, NOT promoted to `ready-for-dev` — a readiness gate runs next. |
| 2026-08-11 | Claude Opus 5 | Readiness gate applied (`4-3b/R12`-`R22`). Four non-criteria deleted from the AC list (the undecided field-permission ask, the golden/key-set measurement obligation, the byte-identity obligation, the live-smoke re-invocation) and their content relocated to a real field-shape AC, Golden Prediction and Live Smoke. Three new ACs added: attacker-kind dispatch on the two silently-failing attacker-side rungs, canonical ordering across attackers, and the killed-mid-swing drop. Attack trigger changed from pure distance to a reach test (`R17a`, operator) mechanised as a THROTTLED kind-marked probe on the existing `push_contact` intake (`R17b`, this gate's own ruling by measurement, not the operator's), measured legal under `4-3/R2` and riding `minion_retarget_interval_ticks` so its stream cost is ~1.33 rows/tick instead of ~16. Signal-widening scoped OUT of AC 3. Friendly-fire filter corrected to gather time. Four Dev Notes citation errors corrected against this tree (the `fact["attacker"]` read list, `_generate_mana`, `register_swing_hit`, and the `4-3a/R29` label) and `4-3a/R29`'s forcing-point assignment recorded as REVERSED. Open Questions reduced to the provisional tuning values. Field grant amended to FIVE scalars: the throttle needs a per-unit in-reach flag, set by a probe and consumed at windup start, so a unit finishing recovery does not wait a further interval and the authored durations still describe the observed attack rate. Snapshot key count deliberately NOT asserted — measured that the board emits three separate top-level keys with precedent running both ways (one array -> one key for `unit_hp`, two arrays -> one fused key for `unit_targets`), so the six contributing fields are named and the count is left to the dev pass. Status promoted to `ready-for-dev`. |
