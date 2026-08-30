class_name UnitAttackProfile
extends Resource

## D6 data vocabulary (story 4-4, AC 9 / `4-4/R7`): ONE authored ATTACK RECORD. Pure schema, no
## logic, on the `MinionPriority` / `ResourceGenerationRule` / `ProjectileProfile` precedent.
##
## `4-4/R7` IS THE SHAPE RULING: "a kind has a LIST of attack records (length one acceptable this
## story), never a single flat attack". This class is one element of that list; the list itself is
## `UnitKindProfile.attacks`. SELECTING among several entries is an explicit Non-Goal of story 4-4,
## so every kind ships exactly one record and the reader takes entry 0 — but the SHAPE is the list,
## which is what keeps a future moveset story from having to migrate every authored kind.
##
## "SHAPE" IS DELIBERATELY ABSENT (story Dev Notes, ratified at the 4-4 readiness gate): the story's
## first draft carried a `shape` field, no reader for it exists in `src/state/` and no ruling
## defines one, so it was dropped rather than authored ahead of its consumer (the `E4-P/R2` reserved
## vocabulary objection). It returns with a future moveset story.
##
## THE FIVE FIELDS AC 9 NAMES ARE WINDUP, ACTIVE, RECOVERY, RANGE AND DAMAGE. `cadence_seconds` is
## the sixth, added by AC 10 ("the Combat totem's one attack record authors ... its own firing
## cadence as a number on that record"), and `projectile` is the seventh, added by AC 14/AC 15 —
## both belong to the RECORD rather than to the kind for the same reason the first five do: a
## future second entry in the list is a different attack, with its own cadence and its own (or no)
## projectile.

## The three phase DURATIONS — the successors to `BalanceConfig`'s
## `minion_attack_windup_seconds` / `_active_seconds` / `_recovery_seconds` global triplet, which
## this story removes (story Dev Notes, the B5 correction: "minion attack durations remain GLOBAL --
## per-kind conversion is `4-4`'s opening act").
##
## THEY STILL CROSS THE SECONDS-TO-TICKS BOUNDARY AT THE SINGLE NAMED POINT (A1 / AC 11).
## `BalanceTicks.from_config()` walks `config.unit_kinds` and derives a `UnitAttackTicks` per
## record; no second conversion boundary is authored and no `*_seconds` float reaches `advance()`.
##
## AUDITED > 0 for the shipped kinds that swing (test_balance_authoring.gd), the reason each field's
## global predecessor carried verbatim: a zero derives 0 ticks and the phase never occupies a tick.
@export var windup_seconds: float = 0.0
@export var active_seconds: float = 0.0
@export var recovery_seconds: float = 0.0

## How close the acquired target must be before this attack may begin — the successor to
## `BalanceConfig.minion_attack_reach_distance`, now per record. Planar (XZ) centre-to-centre, the
## same geometry `stop_distance` is measured in, so "has it arrived" and "is it in range" stay ONE
## geometry compared against two authored numbers.
##
## FOR A MELEE ATTACK THIS IS THE REACH; FOR A PROJECTILE ATTACK IT IS THE FIRING RANGE
## (`4-4/R1`'s 8 m on the shipped Combat totem, AC 10/AC 13). They are the same authored field
## because they answer the same question — may this attack begin against the acquired target? —
## and `4-4/R10` rules that the out-of-range case is a POST-SELECTION GATE rather than a
## distance-based re-selection, which is exactly what one range field on one already-acquired
## target expresses.
##
## AUDITED > 0 and AUDITED >= the kind's `stop_distance` for a MELEE record: a unit halts at
## `stop_distance`, so a shorter reach parks it permanently just outside its own reach. The bound
## does NOT apply to a projectile record, where the range is deliberately far LONGER than the stop
## distance and the unit never approaches at all (speed 0, `4-4/R12`).
@export var range: float = 0.0

## What one confirmed hit from this attack takes off its target — the successor to
## `BalanceConfig.unit_damage_per_hit`, now per record (AC 6 lists it among the four fields that
## become per-kind; AC 9 puts it on the record, which is the same fact stated at finer grain).
##
## FLAT, NOT A PERCENTAGE, and `4-3a/R8`'s reasoning is unchanged by the move: a percentage of the
## target's own maximum would make hits-to-kill a constant for every possible authored maximum.
##
## AUTHORED AND NON-NEGATIVE FOR EVERY KIND, INCLUDING KINDS THAT NEVER HIT ANYTHING (AC 6's own
## clause: "every kind's value for a field it does not use ... is still authored and non-negative
## -- no field is left undefined for a kind"). A static accelerator totem authors 0.0 here; that is
## a DESIGN value, not a missing one.
@export var damage: float = 0.0

## AC 10: this attack's own FIRING CADENCE — the minimum interval between two consecutive attacks
## from this record, as a number ON the record.
##
## A DURATION, converted at the single named point like the three phases above.
##
## ZERO MEANS BACK-TO-BACK, which is the behaviour every minion had before this story: the swing
## cycle is windup + active + recovery and the next windup begins the instant reach permits. That
## is what keeps the shipped minion's rhythm bit-for-bit unmoved by this field's arrival — it is
## authored 0.0 for the minion, and the cooldown it seeds is therefore already expired when the
## previous swing's recovery ends. The Combat totem authors a real cadence, which is the whole
## reason the field exists.
##
## MEASURED FROM WINDUP START, not from the swing's end, so an authored cadence SHORTER than
## windup + active + recovery degrades to back-to-back rather than to overlapping swings.
@export var cadence_seconds: float = 0.0

## AC 14/AC 15: the projectile this attack FIRES, or `null` for a melee attack that opens a hitbox.
##
## A PRESENCE TEST ON AUTHORED DATA, NOT A BRANCH OVER KIND (`4-4/R3`). There is one homing
## implementation and one acceleration implementation, both parameterised by the resource this
## field points at; what varies per kind is whether an attack has one at all. That is the same
## shape `ResourceGenerationRule.required_flag` uses — behaviour selected by authored data, with
## the evaluator staying generic.
##
## THE SHIPPED COMBAT TOTEM IS THE ONLY AUTHORED USER. Minions author `null` here and keep the
## melee hitbox path they have had since 4-3b, unchanged.
@export var projectile: ProjectileProfile = null
