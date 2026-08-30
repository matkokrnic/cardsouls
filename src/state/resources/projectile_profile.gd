class_name ProjectileProfile
extends Resource

## D6 data vocabulary (story 4-4, AC 15 / `4-4/R3`): ONE authored projectile — its speed, its
## HOMING profile and its ACCELERATION profile, plus the travel budget that ends its flight.
## Pure schema, no logic (`src/state/resources/` is the "Resource SCHEMA classes (.gd) — pure data
## vocabulary" tier), on the `MinionPriority` / `ResourceGenerationRule` precedent.
##
## `4-4/R3` IS WHY EVERY NUMBER HERE IS AUTHORED RATHER THAN BRANCHED ON. The ruling states that a
## live projectile's heading updates per an authored homing profile and it accelerates per an
## authored acceleration profile, and that NO CODE BRANCH SELECTS BETWEEN BEHAVIOURS BY KIND. So
## there is exactly ONE homing implementation and ONE acceleration implementation in the codebase,
## and both read their parameters from this resource. A second kind that wants to home differently
## authors different numbers here; it does not get a branch.
##
## IT HANGS OFF AN ATTACK RECORD, NOT OFF A KIND (`UnitAttackProfile.projectile`). An attack that
## authors no projectile is a MELEE attack — that is a presence test on authored data, which is
## what makes "the Combat totem attacks only via its projectile, the accelerators never attack"
## (AC 3) an authoring fact rather than a code branch over kind names.
##
## NO GAMEPLAY NUMBER IS DUPLICATED FROM `BalanceConfig`. This resource IS balance — it reaches the
## state layer only inside `BalanceConfig.unit_kinds`, through `apply_balance()`, and its durations
## cross the seconds-to-ticks boundary at the single named point (`BalanceTicks.from_config()`,
## A1/AC 11) exactly as every other authored duration does.

## World units per second at LAUNCH. The projectile's speed before any acceleration has been
## applied — the `unit_move_speed` precedent for a RATE, and a scalar rather than a tick-domain
## value for that field's stated reason: the actor consumes it per physics frame, whose delta the
## engine owns.
##
## AUDITED > 0 (test_balance_authoring.gd): a zero launch speed with a zero acceleration is a
## projectile that never leaves the totem, which would ship AC 14's "distinct entity that travels"
## invisible in the build while every test stayed green.
@export var launch_speed: float = 0.0

## How fast the heading may turn toward the target, in DEGREES PER SECOND — the homing profile
## (AC 15, `4-4/R3`). A turn RATE rather than a "snap to the target" flag is what makes homing
## AVOIDABLE: the projectile steers, so a target that keeps moving laterally can out-turn it.
##
## A rate, so it is scaled by the tick length at the point of use and never enters the
## seconds-to-ticks conversion (it is not a duration).
##
## ZERO IS A LEGAL AUTHORED VALUE and means "no homing" — a projectile that flies dead straight
## from launch. That is not the shipped Combat totem's authoring, but it is the honest degenerate
## meaning of a zero turn rate, so it is audited NON-NEGATIVE rather than > 0.
@export var homing_turn_rate_degrees_per_second: float = 0.0

## How long after launch the acceleration begins — the acceleration profile's first half (AC 15).
## A DURATION, so it converts to ticks exactly once at load (A1) through
## `BalanceTicks.from_config()`, like every other `*_seconds` field in this project.
##
## Zero is legal and means "accelerating from launch".
@export var acceleration_delay_seconds: float = 0.0

## World units per second SQUARED, applied once the delay above has elapsed — the acceleration
## profile's second half. Non-negative; zero means "flies at `launch_speed` for its whole life",
## which is the honest degenerate meaning rather than a missing value.
@export var acceleration_per_second_squared: float = 0.0

## The ceiling the acceleration converges on, in world units per second. Without it an authored
## acceleration would grow the speed without bound over a long flight and the projectile would
## cross the whole arena inside a couple of ticks, skipping every hurtbox on the way (a fast enough
## step tunnels straight through an `Area3D`). Audited >= `launch_speed`.
@export var max_speed: float = 0.0

## AC 19 / `4-4/R2`: the TOTAL TRAVEL BUDGET in world units — 60 m at the shipped authoring, which
## rounds up the 40x40 m arena's ~56.57 m diagonal so a corner-to-corner shot can complete. A
## projectile that has travelled this far without producing a contact fact is removed from the
## world.
##
## A DISTINCT AUTHORED NUMBER FROM THE FIRING RANGE, and AC 19 says so in as many words: the range
## (`UnitAttackProfile.range`, 8 m) governs whether the totem may fire AT ALL; this governs how far
## the shot may travel once fired. They are audited separately and neither is derived from the
## other.
##
## AUDITED > 0: a zero budget expires the projectile on its launch tick, which ships the whole
## mechanism invisible in the build.
@export var travel_budget: float = 0.0
