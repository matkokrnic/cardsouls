class_name UnitKindFixture
extends RefCounted

## Story 4-4: the IN-TEST builder for `BalanceConfig.unit_kinds`. Test support only — nothing under
## `src/` names this file.
##
## IT EXISTS BECAUSE THE PER-KIND CONVERSION TOUCHED TWELVE FIXTURES AT ONCE. Before this story a
## test that needed a swinging minion set four flat `BalanceConfig` floats and three
## `minion_attack_*_seconds` durations; after it, the same fixture has to build a `UnitKindProfile`
## holding a `UnitAttackProfile`. Hand-rolling those two objects in twelve files would be twelve
## copies of one construction, and a later schema change would have to find all twelve.
##
## IT DOES NOT WEAKEN `BC/R3`'s GOLDEN ISOLATION — it strengthens it. Every VALUE still comes from
## the calling test as a literal argument; this file authors NO number of its own and never reads
## `data/balance/*.tres`. What it shares is the SHAPE, which is exactly the part that is not tuning.
## The three audit files that deliberately read the authored `.tres` (test_data_resources.gd,
## test_balance_authoring.gd, test_balance_config.gd) do not use this builder at all.
##
## SECONDS ARE TAKEN AS TICKS AND DIVIDED HERE, because every caller was already writing
## `float(UNIT_WINDUP) / 60.0` to express a phase length in ticks. Doing the division in one place
## keeps the callers' intent (a tick count) legible and stops a stray `/ 60.0` from being dropped.


## A minion-shaped kind: it walks, it swings a melee attack, it authors no projectile.
##
## `cadence_ticks` DEFAULTS TO 0, which is the shipped minion's authoring and the value that keeps
## the back-to-back swing cycle 4-3b established. A test that wants to exercise AC 10's firing
## cadence passes a real one.
static func melee(kind_name: StringName, max_hp: float, damage: float, windup_ticks: int,
		active_ticks: int, recovery_ticks: int, reach: float, move_speed: float = 3.0,
		stop_distance: float = 1.5, priority_name: StringName = &"standard",
		cadence_ticks: int = 0) -> UnitKindProfile:
	var attack := UnitAttackProfile.new()
	attack.windup_seconds = float(windup_ticks) / TimingWindow.TICK_HZ
	attack.active_seconds = float(active_ticks) / TimingWindow.TICK_HZ
	attack.recovery_seconds = float(recovery_ticks) / TimingWindow.TICK_HZ
	attack.cadence_seconds = float(cadence_ticks) / TimingWindow.TICK_HZ
	attack.range = reach
	attack.damage = damage
	var kind := UnitKindProfile.new()
	kind.kind_name = kind_name
	kind.max_hp = max_hp
	kind.move_speed = move_speed
	kind.stop_distance = stop_distance
	kind.priority_name = priority_name
	kind.attacks = [attack]
	return kind


## A kind that NEVER ATTACKS — the two accelerator totems' shape (AC 3). An EMPTY attack list, not a
## zeroed record: `UnitKindProfile.has_attack()` reads false, and every attack-side seat skips the
## unit rather than running it with zero-length phases.
static func inert(kind_name: StringName, max_hp: float,
		priority_name: StringName = &"standard") -> UnitKindProfile:
	var kind := UnitKindProfile.new()
	kind.kind_name = kind_name
	kind.max_hp = max_hp
	kind.move_speed = 0.0
	kind.stop_distance = 1.5
	kind.priority_name = priority_name
	kind.attacks = []
	return kind


## The DEFAULT single-kind list every pre-4-4 fixture needs: one minion kind at index 0, which is
## the index `UnitBoard.add()` is handed by every test that summons straight onto the board.
##
## INDEX 0 IS THE CONTRACT THOSE TESTS RELY ON, and it is why this returns a LIST rather than the
## kind alone: a fixture that appended its minion second would silently change what
## `add(hp, 0)` means.
static func minion_only(max_hp: float, damage: float, windup_ticks: int, active_ticks: int,
		recovery_ticks: int, reach: float, move_speed: float = 3.0,
		stop_distance: float = 1.5) -> Array[UnitKindProfile]:
	return [melee(&"minion", max_hp, damage, windup_ticks, active_ticks, recovery_ticks, reach,
			move_speed, stop_distance)]
