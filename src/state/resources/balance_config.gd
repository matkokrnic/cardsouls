class_name BalanceConfig
extends Resource

## E1 melee balance schema (story 1-1). Authored as data/balance/balance_config.tres and
## loaded by BalanceConfigService (X3 hot-reloadable). State receives this resource by
## INJECTION via MatchState.apply_balance() and never reads the service.
##
## Defaults are all zero ON PURPOSE: gameplay numbers are never hardcoded in code — the
## authored .tres carries the real values (first-guess placeholders, TBD-in-playtest).
##
## `*_seconds` fields are AUTHORING units only. They are converted to integer ticks exactly
## once per load / X3 reload by BalanceTicks (A1); no `*_seconds` float reaches advance().

@export_group("Hero")
@export var max_hp: float = 0.0
@export var move_speed: float = 0.0

@export_group("Stamina")
@export var max_stamina: float = 0.0
@export var stamina_regen_per_second: float = 0.0
@export var stamina_regen_delay_seconds: float = 0.0
@export var roll_stamina_cost: float = 0.0
@export var deflect_stamina_cost: float = 0.0
## Stamina-cost corrective pass (E3-RG/R2; OPEN decision (d) RESOLVED at DP/R2): the basic
## attack's per-swing cost — an ANTI-SPAM lever, not an economy constraint (melee stays the
## 1-5 mana faucet). Charged per SWING, so a chain of N costs N x this. Spent at the step-3
## transition on the roll precedent (entry-time spend, reject-and-fall-through), never at
## landing like deflect. Zero default like every other field: an unauthored cost is a free
## attack, which the authoring audit forbids for the shipped .tres.
@export var attack_stamina_cost: float = 0.0

@export_group("Attack")
@export var attack_windup_seconds: float = 0.0
@export var attack_active_seconds: float = 0.0
@export var attack_recovery_seconds: float = 0.0
@export var attack_chain_window_seconds: float = 0.0
@export var attack_chain_length: int = 0
@export var attack_damage_percent_of_max_hp: float = 0.0
## Story 3-0b (AC5, DEBT E member 2): the per-phase successors to the single flat
## attack_move_speed_multiplier that story 1-5 (B6) shipped "uniform across windup/active/
## recovery (per-phase multipliers wait for animations)". The rig landed in 3-0a, so the
## deferral is paid: each field scales the hero's resolved velocity while ATTACKING during
## ITS OWN phase, selected by HeroState.attack_phase() in _resolve_movement and read inline
## at the moment of use (CONSTRAINT C). The flat field is REMOVED, not kept alongside — a
## half-migration would leave two sources of truth for the same scalar.
## Scalars, NOT tick-domain — never on BalanceTicks. Authored 0.0 = full root (a design
## value, not a missing one — exempt from the >0 authoring audit with that reason); the
## Pass 2 migration authored all three at the flat field's 0.0 so live feel is unchanged
## by the seat itself, leaving the per-phase VALUES to this story's AC8 tuning verdict.
@export var attack_windup_move_speed_multiplier: float = 0.0
@export var attack_active_move_speed_multiplier: float = 0.0
@export var attack_recovery_move_speed_multiplier: float = 0.0
## Story 3-0b (AC6): authored forward lunge DISPLACEMENT for one swing — the sanctioned
## form from the 1-7 close-out ("an authored lunge displacement in balance data, applied by
## the STATE layer as a velocity curve during the swing"), NEVER AnimationPlayer root
## motion (DECISION A / the in-place rule). The state layer derives a speed from it exactly
## the way the roll does (roll_distance / roll_duration_seconds): this distance divided by
## the swing's committed span (windup + active seconds), applied along HeroState.facing
## during WINDUP and ACTIVE only — recovery drift is a separate feel decision and is not
## this field's. Units, NOT tick-domain — never on BalanceTicks.
@export var attack_lunge_distance: float = 0.0

@export_group("Mana")
## Story 3-1 (AC 2, 3-1/R1): the mana cap — authored here as of this story, so BalanceConfig
## is now the single source of truth for it exactly as it already was for max_hp,
## move_speed and max_stamina (AC 3). Re-injected on every apply_balance() with
## set_maximum ONLY: current mana is re-clamped, NEVER refilled (3-1/R2).
@export var max_mana: float = 0.0
## Story 1-5 (DEBT D resolved): mana per CONFIRMED melee hit, read inline at the moment
## the hit is confirmed (CONSTRAINT C), gated on the injected
## FeatureFlags.melee_mana_generation. Per-event amount, NOT tick-domain — never on
## BalanceTicks. The flag is the off-switch; a zero amount is a dead flywheel (audited >0).
## RE-AUTHORED by story 3-1 as part of the coherent mana set (3-1/R1): the shipped 8.0 was a
## placeholder against an 80 cap, and the BC/R2 damage halving (6 -> 3) had silently doubled
## mana earned per point of damage. 1.0 per confirmed hit against the 10.0 cap re-bases both
## together and keeps per-hit bar fill identical (8/80 == 1/10 == 10% of the bar).
@export var melee_hit_mana: float = 0.0
## Story 3-1 (AC 2, 3-1/R1): passive mana regeneration, the second faucet beside the melee
## one. AUTHORING UNITS ONLY in this story — N7/E3-RG/R8 place the derived
## `mana_regen_per_tick` seat on BalanceTicks and the matching rung in the advance() ladder
## in story 3-4, so NOTHING consumes this field yet and no BalanceTicks field lands here.
## Named `*_per_second` (a RATE, the stamina_regen_per_second precedent), not `*_seconds` —
## it is not a duration and does not enter the A1 seconds->ticks conversion.
@export var mana_regen_per_second: float = 0.0

@export_group("Cards")
## Story 3-3 (AC 6): how many cards one deck holds. A COUNT, not a duration — it lives here
## and never on BalanceTicks (the A1 conversion is for `*_seconds` fields only). Read INLINE at
## its point of use (CONSTRAINT C), which is the RUNNER: it walks CardDatabase's sorted ids
## taking up to each card's max_copies until this many are collected, and injects the plain
## StringName ids into MatchState (AC 2/AC 4). The state layer never reads this field — it
## receives the composition already sized.
## PROVISIONAL FIXTURE composition, not the deckbuilding seat: real deck selection is E4/E5 or
## later. Audited > 0 (test_balance_authoring.gd): a zero deck is a match with no cards.
@export var deck_size: int = 0
## Story 3-3 (AC 6): how many cards the hand is filled to. A COUNT, same reasoning as
## deck_size, but THIS one is read by the state layer — inline at the single step-6 deal seat
## (MatchState._deal_player), on both the match-start and the debug-reset occasion.
## The hand does NOT vary in this story's first version. OPEN decision (e) — "does the number
## of cards in a hand ever vary?" — is CARRIED, not resolved: no variable-size path is built
## speculatively. Audited > 0 and <= deck_size (a hand bigger than the deck cannot be dealt).
## The `draw_replacement_delay_seconds` reservation this comment used to carry is DISCHARGED
## directly below — story 3-5b is the "3-5 WITH its consumer" the note was waiting for.
@export var hand_size: int = 0
## Story 3-5b (AC 1): how long a played card's REPLACEMENT takes to arrive. The reservation the
## `hand_size` comment above carried since 3-3, now discharged WITH its consumer: 3-5a shipped
## the instant refill, and this field is what turns it into a debt that is paid `delay` later.
## A DURATION, so it converts to ticks exactly once at load (A1) — `BalanceTicks
## .draw_replacement_delay_ticks`, read INLINE at the cast seat (CONSTRAINT C).
##
## AUDITED > 0 (test_balance_authoring.gd), NOT merely non-negative, and the distinction is the
## whole point: `field in config` and `>= 0.0` both pass on this script's 0.0 default, which
## would ship the delay INVISIBLE in the build and recreate exactly the dead field the
## reservation comment existed to prevent. Zero ticks is a legal in-test value (it degrades to
## 3-5a's instant refill, which is how the golden isolates the seat from its content) — it is
## the AUTHORED value that must be positive.
@export var draw_replacement_delay_seconds: float = 0.0
## Story 3-5b (AC 2): how long the reshuffling player stays "vulnerable" after their discard is
## folded back into the deck. The GDD's "~1.5-2s TBD" range.
##
## AUTHORED AND AUDITED > 0 like its sibling above, for the identical reason. What is NOT
## decided here is what vulnerable COSTS: OPEN decision (b) stays open, and the mechanism that
## keeps it open is a NEGATIVE GUARD (test_deck_and_hand.gd) asserting that nothing under `src/`
## READS the window this value sizes — no damage path, no mitigation path, no action-state path.
## A TimingWindow cannot exist without a duration, so the field ships; if nothing consults it,
## nothing has priced it. The renderer is 3-6's.
@export var reshuffle_vulnerable_window_seconds: float = 0.0

@export_group("Minions")
## Story 4-2 (AC 7, `4-2/R5`(a)): how often a unit RE-EVALUATES its target. The project-context
## Performance Rule made authorable — "target-acquisition scans must NOT run every frame for every
## unit. Use a shared, throttled tick (e.g. re-target every ~0.1-0.25 s)" — so the cadence is a
## tuning value, not a magic number in `advance()`.
##
## A DURATION, so it converts to ticks exactly once at load (A1), on the
## `draw_replacement_delay_seconds` -> `_ticks` precedent directly above: `BalanceTicks
## .minion_retarget_interval_ticks`, read INLINE at the step-7 seat (CONSTRAINT C).
##
## ONE MATCH-WIDE CADENCE, NOT A PER-POOL OR PER-PLAYER VALUE. `MatchState.apply_balance` is
## deliberately NOT touched by this story (`4-2/R5`(b)): the per-pool reload contract (`3-1/R2`)
## governs POOL BOUNDS, and a shared tick cadence is not one — a dev pass must not invent a
## per-player injection seat for it.
##
## THE DEGENERATE VALUE IS DEFINED RATHER THAN LEFT TO ROUNDING (`4-2/R5`(d)): the derived interval
## clamps to at least 1 tick ALWAYS, so an authored 0 means "every tick" instead of a modulo by zero.
## That makes 0 a legal in-test value, exactly as a 0 draw delay is. It is the AUTHORED value that
## is audited > 0 (test_balance_authoring.gd), for the `draw_replacement_delay_seconds` reason
## verbatim: a zero authored cadence would ship the whole THROTTLE invisible in the build — every
## unit re-scanning every frame is precisely the behaviour the Performance Rule forbids, and it
## would pass a `>= 0.0` existence check silently.
@export var minion_retarget_interval_seconds: float = 0.0
## Story 4-3 (AC 2): how fast a unit walks toward the target it acquired, in world units per
## second — the `move_speed` / `stamina_regen_per_second` precedent for a RATE.
##
## A SCALAR, NEVER TICK-DOMAIN, and the name carries the reason: `BalanceTicks.from_config()`
## converts `*_seconds` durations (A1), and a rate is not a duration. There is deliberately no
## `unit_move_speed_ticks` counterpart, exactly as there is no `move_speed_ticks` — the value is
## consumed per physics frame by `move_and_slide()`, whose delta the engine owns.
##
## READ INLINE AT POINT OF USE (CONSTRAINT C), from the config the RUNNER already applied
## (`MatchState.balance`, the replay-aware handle selected at `match_runner.gd:177-180`) — never
## `BalanceConfigService.get_config()` from the approach step, which during replay would walk
## units at the AUTHORED speed instead of the RECORDED one (the divergence `3-0c`'s AC 4 exists
## to prevent), and never a copy cached in a `UnitActor` field (`4-3/R11`).
##
## AUDITED > 0 (test_balance_authoring.gd), the `draw_replacement_delay_seconds` reason verbatim:
## `field in config` and the `>= 0.0` loop in test_data_resources.gd BOTH pass on this script's
## 0.0 default, and a zero speed ships the whole mechanic INVISIBLE in the build — a unit that
## rotates to face its target and never closes the distance is exactly 4-2's behaviour, which
## this story exists to replace. Zero stays a legal in-test value; it is the AUTHORED value that
## must be positive.
@export var unit_move_speed: float = 0.0
## Story 4-3 (AC 2/AC 3): how close a unit gets to its target before it halts and holds its
## facing — planar (XZ) centre-to-centre distance, the `attack_lunge_distance` precedent for a
## DISTANCE. Scalar, never tick-domain, for its sibling's reason directly above.
##
## AUDITED > 0 for the same class of failure: a zero stop distance would have a unit walk into
## its target until the two bodies wedge, which reads as a physics glitch rather than as an
## approach. Read inline at point of use, from the same runner-applied handle.
@export var unit_stop_distance: float = 0.0
## Story 4-3a (AC 1, `4-3a/R6`/`4-3a/R8`): a unit's MAXIMUM HP, and there is exactly one of it —
## the field is authored HERE and SHARED by every minion rather than stored per record, because no
## unit differs from another yet (the totem clause keeps the record type/kind-less, and the
## `4-2/R17(c)` permission is spent on the per-record `hp` alone). A freshly summoned unit enters at
## this value, on the `HeroState._init(... max_hp ...)` precedent.
##
## A SCALAR, NEVER TICK-DOMAIN — not a duration, so no `BalanceTicks` counterpart, exactly like
## `unit_move_speed` and `unit_stop_distance` above.
##
## READ INLINE AT POINT OF USE (CONSTRAINT C), at MatchState's step-6 cast dispatch — the one seat
## that calls `UnitBoard.add()`. The board itself never reads balance; it receives the maximum as an
## argument, which is what keeps `UnitBoard` a pure container with no config dependency.
##
## AUDITED > 0 (test_balance_authoring.gd) for a failure that would otherwise be silent: a zero
## maximum summons a unit that is ALREADY DEAD, so the first contact fact drops at the liveness rung
## and the whole story ships invisible in the build.
@export var unit_max_hp: float = 0.0
## Story 4-3a (AC 2, `4-3a/R8`, decided by Matko): the DEDICATED FLAT damage one confirmed hero
## swing takes off a unit. Deliberately NOT `attack_damage_percent_of_max_hp` recomputed against
## `unit_max_hp`: that field is a percentage of the TARGET's OWN maximum, so reusing it here would
## make hits-to-kill a CONSTANT (34, at the authored 3.0%) for EVERY possible authored unit maximum,
## and `unit_max_hp` would be a cosmetic number that decides nothing. A flat value is what makes the
## authored maximum load-bearing.
##
## FLAT, NOT A PERCENTAGE, and not scaled by anything: no block multiplier, no deflect, no facing
## arc — those are all properties of a HERO target (`4-3a/R20`), and a unit structurally lacks every
## one of them. Scalar, never tick-domain; read inline at the step-4 resolution seat (CONSTRAINT C).
##
## PROVISIONAL, AND ITS RETUNE HAS A NAMED OWNER: 3.0 against a 9.0 maximum is three swings to kill.
## Both values are tuned by the melee retune in `4-3b` (`E3-R/R3`, re-anchored by `4-3a/R5`), which
## is why test_balance_authoring.gd audits the hits-to-kill RATIO as a band rather than pinning 3.
##
## AUDITED > 0 for the opposite silent failure to its sibling above: a zero flat damage ships a unit
## that can be hit forever and never dies — the invulnerable box this story exists to replace.
@export var unit_damage_per_hit: float = 0.0
## Story 4-3b (AC 1): the THREE GLOBAL attack-rhythm durations every minion shares — the hero's
## own `attack_windup_seconds` / `attack_active_seconds` / `attack_recovery_seconds` triplet
## (33-35) applied to a unit, and authored ONCE here rather than per record for the reason
## `unit_max_hp` states directly above: no unit differs from another yet. `4-2/R17`(c) names the
## first story where units actually DIFFER as the only one allowed to add a differentiating field
## to the record, and this is not that story.
##
## NAMING IS LOAD-BEARING, which is why AC 1 spells these three identifiers out: the balance field
## guard is REFLECTION-BASED (test_data_resources.gd) and matches on the field NAME. Each needs all
## four of: the `<stem>_seconds` suffix; an exactly stem-matched `<stem>_ticks` twin on
## `BalanceTicks` FILLED by `from_config()`; an entry in `E1_BALANCE_FIELDS`; and a non-negative
## authored value. Miss any one and the guard fails — which IS the guard working.
##
## PROVISIONAL, NOT TUNED. This story ships a working rhythm; the melee retune block (`E3-R/R3`,
## re-anchored here by `4-3a/R5`) runs once this story closes and owns the real numbers. The
## authored 0.5 / 0.2 / 0.8 is deliberately SLOWER than the hero's 0.25 / 0.15 / 0.35 — a
## summon-tier swing a human can read and step out of (`4-3b/R9`).
@export var minion_attack_windup_seconds: float = 0.0
@export var minion_attack_active_seconds: float = 0.0
@export var minion_attack_recovery_seconds: float = 0.0
## Story 4-3b (AC 13, `4-3b/R17a`): how close a unit's ACQUIRED TARGET must be before the unit may
## begin a windup — planar (XZ) centre-to-centre, the `unit_stop_distance` precedent for a
## DISTANCE. Scalar, never tick-domain, for its siblings' reason above.
##
## MEASURED IN THE RUNNER, NEVER IN STATE (D3(b)/A2). The runner turns the acquired `[slot, index]`
## pair into two world positions it already owns and pushes the RELATION inward as a kind-marked
## REACH PROBE on the existing `push_contact` intake — state learns "in reach", never a position.
##
## AUDITED > 0 AND AUDITED >= `unit_stop_distance` (test_balance_authoring.gd), and the second bound
## is the one that matters: a unit HALTS at `unit_stop_distance` from its target, so a reach shorter
## than the stop distance leaves every minion parked just outside its own reach, never in reach,
## never winding up — the whole story shipped invisible in the build with nothing failing.
@export var minion_attack_reach_distance: float = 0.0
## Story 4-3c1 (AC 1, `4-3c/R19`): the minion's OWN three attack-phase move-speed multipliers —
## the unit-side parallel of the hero's `attack_<phase>_move_speed_multiplier` triplet (50-52),
## scaling a unit's approach speed while it is WINDUP / ACTIVE / RECOVERY. Authored 0.0 = full
## root, the same design value (not a missing one) the hero's three carry, so the audit bound is
## non-negative rather than > 0.
##
## THREE NEW FIELDS RATHER THAN REUSING THE HERO'S THREE, which is AC 1's whole content: sharing
## the hero's keys would permanently couple minion feel to hero feel — a later hero retune would
## silently retune every minion, with no way to diverge the two without a migration.
##
## NO LUNGE TWIN, and that is an explicit non-goal, not a forgotten field: the hero's
## `attack_lunge_distance` (61) is a SEPARATE additive velocity term, and mirroring it would
## reintroduce committed movement during the swing through a different door than the one this
## story closes.
##
## Scalars, NOT tick-domain — never on `BalanceTicks`. Carrying no `_seconds` suffix, half (b) of
## the reflective guard leaves them alone; the obligations that DO apply are the two AC 3 names:
## an entry apiece in `E1_BALANCE_FIELDS` (`test_data_resources.gd`, hand-maintained — half (a)
## fails until they are listed) and the minion-side non-negative audit in
## `test_balance_authoring.gd`.
@export var minion_attack_windup_move_speed_multiplier: float = 0.0
@export var minion_attack_active_move_speed_multiplier: float = 0.0
@export var minion_attack_recovery_move_speed_multiplier: float = 0.0

@export_group("Defense")
@export var block_damage_multiplier: float = 0.0
@export var deflect_window_seconds: float = 0.0
## Story 1-8 (R-D2): full width of the front arc within which a BLOCKING target counts as
## facing the attacker — the gate for BOTH block mitigation and deflect (R-D3). State
## compares the fact's target-to-attacker direction against HeroState.facing within
## +/- half this arc. Scalar degrees, NOT tick-domain — never on BalanceTicks.
@export var block_facing_arc_degrees: float = 0.0

@export_group("Roll")
@export var roll_iframe_seconds: float = 0.0
@export var roll_duration_seconds: float = 0.0
@export var roll_distance: float = 0.0

@export_group("Stun")
## DATA FIELD ONLY. No E1 code path enters STUNNED — attacker-stun-on-deflect is OPEN
## decision (a) in the GDD decision log, and authoring this duration does NOT resolve it.
@export var stun_seconds: float = 0.0
