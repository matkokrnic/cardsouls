class_name UnitAttackTicks
extends RefCounted

## Story 4-4 (AC 11): the TICK-DOMAIN twin of one `UnitAttackProfile`. Derived exactly once per
## balance load / X3 reload, inside `BalanceTicks.from_config()` — THE single seconds-to-ticks
## conversion boundary (A1/D4).
##
## IT EXISTS SO THE PER-KIND CONVERSION DOES NOT OPEN A SECOND BOUNDARY, which is AC 11's actual
## requirement: "per-kind durations must still cross the seconds-to-ticks boundary through the
## single named `BalanceTicks.from_config()` point". Before this story the four unit durations were
## flat `BalanceConfig` fields with flat `BalanceTicks` twins; after it they are per-record, and the
## twin has to be per-record too or `advance()` would have to convert a `*_seconds` float at the
## point of use — precisely what A1 forbids.
##
## PLAIN INTS AND NOTHING ELSE. This object is DERIVED CONFIG, never state: it is rebuilt whole on
## every `apply_balance()` (CONSTRAINT C — never cache a reference to it; read
## `ms.balance_ticks.<...>` inline at the moment of use) and no field on it reaches the determinism
## snapshot. What reaches the snapshot is the COUNTDOWN a window was started with, on the board.
##
## NON-DURATION FIELDS OF THE ATTACK RECORD ARE DELIBERATELY ABSENT — `range`, `damage` and the
## projectile's speeds/distances stay on `UnitAttackProfile` and are read from `balance` directly.
## `BalanceTicks` is for values that are DERIVED at load (the `stamina_regen_per_tick` widening,
## story 1-4 / D3); a scalar that is authored and consumed unchanged has no business being copied
## into a second object that could go stale.

## `UnitAttackProfile.windup_seconds` / `_active_seconds` / `_recovery_seconds` in ticks.
##
## PLAIN `seconds_to_ticks()` CALLS WITH NO CLAMP OF THEIR OWN — the `minion_attack_*_ticks`
## triplet these replace carried exactly this note: unlike a modulo divisor these are DURATIONS,
## and `seconds_to_ticks()` already clamps any non-zero authored duration to >= 1 tick. A
## 0.0-authored phase derives 0 ticks, which the authoring audit forbids for a shipped kind that
## attacks at all.
var windup_ticks: int
var active_ticks: int
var recovery_ticks: int

## `UnitAttackProfile.cadence_seconds` in ticks (AC 10) — the minimum interval between two
## consecutive attacks from this record, measured from windup start.
##
## NO CLAMP EITHER, and here the degenerate value's meaning is the SHIPPED MINION'S BEHAVIOUR
## rather than an error: an authored 0 derives 0 ticks, the cooldown a swing seeds is already
## expired when that swing's recovery ends, and the unit returns to the back-to-back cycle it has
## had since 4-3b. That is what keeps the minion's rhythm bit-for-bit unmoved by this field's
## arrival.
var cadence_ticks: int

## `ProjectileProfile.acceleration_delay_seconds` in ticks, or 0 when this record authors no
## projectile. Zero for a melee record is not a special case that needs guarding — no melee code
## path ever reads it, and a projectile authored with a zero delay legitimately accelerates from
## launch.
var projectile_acceleration_delay_ticks: int
