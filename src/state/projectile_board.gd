class_name ProjectileBoard
extends RefCounted

## Story 4-4 (AC 14-19, `E4-P/R12`): the per-player collection of LIVE PROJECTILES — the FIFTH pure
## container, built to `UnitBoard`'s shape and to the same rules: PURE `RefCounted`, owned by
## `PlayerState`, no RNG, no `SignalQueue`, no scene reference, and nothing here names
## `CardDatabase`, `CARDS_DIR` or `data/cards`.
##
## ------------------------------------------------------------------------------------------
## WHY A PROJECTILE IS STATE AT ALL, WHEN POSITION IS ACTOR-OWNED.
## ------------------------------------------------------------------------------------------
## `4-3/R2` and `4-1/R12` keep POSITION actor-owned and this container does not touch that: it holds
## no `Vector3` and no heading. What it holds is the part of a projectile that CROSSES TICKS AND
## DECIDES AN OUTCOME (`4-3a/R17`'s test), and AC 16 is why that part cannot live on the actor: a
## STATE decision — the i-frame drop on the contact ladder — must change an ACTOR behaviour, the
## homing. A flag the state layer sets and the runner reads is exactly the shape that requires, and
## it must be snapshotted or a replay could silently diverge on whether a shot was still homing.
##
## THE SAME ARGUMENT COVERS LIVENESS AND THE BUDGET. Whether a shot has been consumed (AC 18) and how
## far it has flown (AC 19) both decide later ticks and neither can be recomputed for free.
##
## ------------------------------------------------------------------------------------------
## IT OUTLIVES ITS SOURCE, AND IT DOES SO WITHOUT COPYING ONE AUTHORED NUMBER (`E4-P/R12`).
## ------------------------------------------------------------------------------------------
## The ruling requires a projectile to survive the totem that fired it. The obvious reading — snapshot
## the damage, speed, homing rate and budget onto the record at launch — is REJECTED, because it
## would be five copies of authored data per shot, each of them stale the moment an X3 reload landed,
## which is exactly what CONSTRAINT C forbids. What is stored instead is the firing unit's KIND INDEX:
## a kind is CONFIG, not an instance, so it outlives the totem by construction and every authored
## number is read through it INLINE at the point of use, live, on every tick.
##
## `_source_index` IS NOT HOW THE PROFILE IS FOUND — it exists only so the runner can place the fresh
## actor at the firing totem's position on the launch tick. Nothing reads it afterwards, and a shot
## whose source has since died or been freed is unaffected.
##
## ------------------------------------------------------------------------------------------
## ITS OWN ATTACKER IDENTITY: A THIRD PARTITION OF ONE ADDRESSING SCHEME, NOT A THIRD ELEMENT.
## ------------------------------------------------------------------------------------------
## `E4-P/R12` says a projectile "needs its own attacker identity and dedupe, not a `[slot, index]`
## unit-board address". `MatchState.push_contact`'s address space already partitions the INDEX half:
## `-1` is the hero, `>= 0` is a unit on that slot's board. A projectile takes the negative range
## BELOW the hero — `PROJECTILE_INDEX_BASE - i` — so the fact's shape, the recorder's plain-int rows
## and every existing hero/unit call site are all untouched. One scheme, three partitions, rather than
## a widened tuple every caller would have to learn.
##
## ITS DEDUPE IS ITS LIVENESS, and that is why no `ProjectileSwingDedupe` sibling ships. A unit's
## swing may land on several targets and must refuse to hit any ONE of them twice, which needs a hit
## list; a projectile resolves AT MOST ONCE because resolving CONSUMES it (AC 18 and the full-damage
## path alike). "Has it already resolved" and "is it still alive" are the same question, so they are
## one field.

## The target this shot was fired at, as the `[slot, index]` pair (`4-2/R2`'s convention). FIXED AT
## LAUNCH and never re-acquired: AC 15 has the projectile home on "the target's CURRENT position",
## which is a live position lookup against a fixed address, not a re-selection. A projectile that
## outlived its target simply stops finding a position and flies on.
var _target_slots: Array[int] = []
var _target_indices: Array[int] = []

## Which entry of `BalanceConfig.unit_kinds` governs this shot — see the header for why this, and not
## a copy of the numbers, is what makes a projectile outlive its source.
var _kind_index: Array[int] = []

## The board index of the unit that fired, read ONCE by the runner on the launch tick to place the
## actor. See the header: nothing else reads it, and it is deliberately not how the profile is found.
var _source_index: Array[int] = []

## Liveness. A STORED BOOL rather than a value derived from the budget, and the divergence from
## `UnitBoard`'s hp-derived `is_alive_at` is deliberate: a unit has exactly one way to die (hp
## reaching zero), so deriving is what stops a corpse being simultaneously dead and alive. A
## projectile has TWO ways to end — the budget expiring (AC 19) and being CONSUMED by a contact
## (AC 18) — and consumption is not derivable from any other field here. One stored fact is honest;
## deriving from the budget alone would make a consumed shot read as still flying.
var _alive: Array[bool] = []

## Whether this shot is still steering toward its target (AC 15), or holding its last heading and
## flying straight (AC 16). SET TRUE AT LAUNCH and cleared by exactly ONE event — the i-frame drop
## rung, `4-4/R4` — with no path back to true.
##
## `4-4/R5` IS THE ASYMMETRY THIS FIELD ENCODES: a target merely leaving the flight path does NOT
## clear it. There is deliberately no "lost the target" test anywhere in this file or its callers,
## because absence of a hit is not an event — the same reasoning `UnitBoard._in_reach` records for
## why there is no negative probe.
var _homing: Array[bool] = []

## Ticks since launch — the ACCELERATION CLOCK (AC 15). Counted one per `advance()` beside every
## other D4 timer.
var _flight_ticks: Array[int] = []

## World units flown so far — the TRAVEL-BUDGET ODOMETER (AC 19).
##
## THIS IS A SECOND FIELD ALONGSIDE `_flight_ticks` AND THAT IS NOT TWO EXPRESSIONS OF ONE FACT. Time
## and distance coincide only at a CONSTANT speed, which is precisely the case an acceleration profile
## excludes: after the authored delay the same tick buys more distance than the one before it. The
## clock decides the SPEED, the odometer decides the END. Deriving either from the other would mean
## re-integrating the whole flight on every read.
##
## IT IS A PATH LENGTH, NOT A POSITION. No coordinate, no heading and no velocity enters this
## container, so `4-3/R2`'s "position is actor-owned" is untouched and `push_contact` remains the only
## inward intake — nothing is pushed in to maintain this, because the state layer INTEGRATES it from
## the same authored profile the actor moves by.
var _travelled: Array[float] = []

## ------------------------------------------------------------------------------------------
## STORY 6-5d (AC 13/AC 14/AC 19-23, Open Question 2): THE HERO-SOURCED SHOT.
## ------------------------------------------------------------------------------------------
## THE HEADER'S ARGUMENT IS NOT WEAKENED, IT IS APPLIED TO A SECOND KIND OF CONFIG. `E4-P/R12`
## rejected snapshotting five authored numbers per shot and stored the firing unit's KIND INDEX
## instead, because a kind is CONFIG and outlives the instance. A hero has no kind -- but the thing a
## hero's shot is authored by, the PITCH EFFECT, is config in exactly the same sense: `_pitch_effects`
## is injected ONCE at match start and has no reload path. So the record stores the EFFECT ID and every
## authored number (launch speed, homing rate, acceleration, ceiling, budget) is read through it INLINE
## at the point of use, live, on every tick -- the same discipline, the same reason, one more handle.
##
## THE ID IS A `String`, NEVER A `StringName`, on `PlayerState.cast_card_id`'s stated and measured
## reason: `Array[StringName].sort()` orders by INTERNAL POINTER on this engine, and this array reaches
## the canonical hash. The reader converts back with `StringName()` to index the injected map.
##
## `""` MEANS "FIRED BY A UNIT", AND IT IS THE SINGLE DISCRIMINATOR (`is_hero_sourced_at`). No sibling
## bool ships: "which effect authors this shot" and "was this fired by a hero" are one fact, and a
## second member could disagree with it -- `PitchState`'s no-ready-flag argument verbatim. A
## hero-sourced record carries `_kind_index` `BalanceConfig.NO_KIND_INDEX` and `_source_index`
## `TargetingService.HERO_INDEX`, both written in the one `add_hero_shot` seat below so the three can
## never fall out of agreement.
var _effect_ids: Array[String] = []

## THE LOCKED DAMAGE this shot deals, frozen at STAGING and carried through the cast (AC 7/AC 14). THE
## ONE AUTHORED-DATA COPY ON THIS BOARD, and the header's prohibition does not reach it because IT IS
## NOT AUTHORED DATA: it is `damage_per_mana x the mana the player actually spent`, an outcome of a
## player action against a live pool. There is no config to re-read it from -- the staged record that
## held it was cleared at the activation press -- so storing it is the only honest option, and an X3
## retune of `damage_per_mana` correctly does NOT move a shot already in the air (Open Question 5).
##
## 0.0 FOR A UNIT-FIRED SHOT, and never read for one: `MatchState._attacker_attack_damage` dispatches
## on `is_hero_sourced_at`, so a totem's shot still reads its own kind's attack record and AC 36's
## bit-identical damage is true by construction rather than by a value that happens to be zero.
var _damage: Array[float] = []


## The ONE way a projectile enters the board — the `UnitBoard.add()` discipline (one seat, inside
## the ordered dispatch). Called from `MatchState._advance_unit_attacks` at the windup-to-active
## transition of an attack whose record authors a projectile, and nowhere else.
##
## AN UNCONDITIONAL APPEND, NEVER FILLING A HOLE, on `4-3a/R9`'s ruling applied to a second container
## and for its reason verbatim: an index reused by a later shot would silently re-point a contact fact
## already in flight — under the F1 one-tick lag there is always such a fact — at a DIFFERENT
## projectile. If this function ever grows a free-list branch, that ruling is being reversed.
func add(target_slot: int, target_index: int, kind_index: int, source_index: int) -> void:
	_target_slots.append(target_slot)
	_target_indices.append(target_index)
	_kind_index.append(kind_index)
	_source_index.append(source_index)
	_alive.append(true)
	_homing.append(true)
	_flight_ticks.append(0)
	_travelled.append(0.0)
	# Story 6-5d: a UNIT-fired shot is hero-sourced-by-absence. The empty id is what
	# `is_hero_sourced_at` reads, so this seat needs no flag and the totem path is untouched.
	_effect_ids.append("")
	_damage.append(0.0)


## Story 6-5d (AC 13): THE SECOND WAY A PROJECTILE ENTERS THE BOARD -- a HERO-SOURCED shot, placed by
## the cast strike seat (`MatchState._apply_fireball`) and nowhere else.
##
## A SECOND NAMED SEAT RATHER THAN TWO MORE ARGUMENTS ON `add()`, and the reason is that every caller of
## `add()` would then have to pass `""` and `0.0` to mean "not that kind of shot" -- the two seats author
## DIFFERENT records (one identified by a kind index, one by an effect id) and naming them apart is what
## makes a hero shot impossible to create with a kind index by accident. Both still append
## unconditionally, so `4-3a/R9`'s no-index-reuse ruling holds for both (AC 23).
##
## `NO_KIND_INDEX` AND `HERO_INDEX` ARE WRITTEN HERE, not left to a caller: a hero-sourced record must
## never resolve a unit kind, and `_source_index` must land on the runner's existing owner-hero fallback
## in `_projectile_launch_position` so the shot leaves the caster (AC 13) with no runner edit.
func add_hero_shot(target_slot: int, target_index: int, effect_id: StringName,
		damage: float) -> void:
	Invariant.check(effect_id != &"",
		"a hero-sourced projectile needs an effect id -- the empty id means unit-fired")
	_target_slots.append(target_slot)
	_target_indices.append(target_index)
	_kind_index.append(BalanceConfig.NO_KIND_INDEX)
	_source_index.append(TargetingService.HERO_INDEX)
	_alive.append(true)
	_homing.append(true)
	_flight_ticks.append(0)
	_travelled.append(0.0)
	_effect_ids.append(String(effect_id))
	_damage.append(damage)


## Emptied by the DEBUG RESET ONLY, never by round end — `UnitBoard.clear()`'s contract (`4-1/R5`)
## applied to the second board, so the two are cleared together by one caller and cannot drift into
## a state where units are gone but their shots are still flying.
##
## All TEN arrays are cleared TOGETHER (eight before story 6-5d): they are ONE collection expressed as
## ten, and an index present in one but not the others would be a shot with a target but no liveness.
func clear() -> void:
	_target_slots.clear()
	_target_indices.clear()
	_kind_index.clear()
	_source_index.clear()
	_alive.clear()
	_homing.clear()
	_flight_ticks.clear()
	_travelled.clear()
	_effect_ids.clear()
	_damage.clear()


func size() -> int:
	return _target_slots.size()


func is_empty() -> bool:
	return _target_slots.is_empty()


## THE PUBLIC BOUND PREDICATE every guard below is wired to — `UnitBoard.has_index`'s contract
## verbatim, including its reason: a guard that re-derives the bound inline is guarding a copy.
func has_index(index: int) -> bool:
	return index >= 0 and index < size()


## LENIENT, on `UnitBoard.is_alive_at`'s precedent and for its exact reason: the caller this leniency
## exists for is the contact ladder's dead-attacker rung, which judges UNTRUSTED fact data. A fact can
## name a stale or malformed projectile index — the F1 one-tick lag guarantees facts from shots that
## have since been consumed — and for that caller "there is no such record" and "that shot is over"
## lead to the same correct action: DROP the fact.
func is_alive_at(index: int) -> bool:
	return has_index(index) and _alive[index]


## Also lenient, and for the same caller: the i-frame rung asks this of a fact's attacker before
## ending its homing, and a fact naming a shot that no longer exists must not trip a guard.
func is_homing_at(index: int) -> bool:
	return has_index(index) and _homing[index]


func target_slot_at(index: int) -> int:
	Invariant.check(has_index(index),
		"projectile board index %d is out of range (board holds %d)" % [index, size()])
	return _target_slots[index]


func target_index_at(index: int) -> int:
	Invariant.check(has_index(index),
		"projectile board index %d is out of range (board holds %d)" % [index, size()])
	return _target_indices[index]


func kind_index_at(index: int) -> int:
	Invariant.check(has_index(index),
		"projectile board index %d is out of range (board holds %d)" % [index, size()])
	return _kind_index[index]


func source_index_at(index: int) -> int:
	Invariant.check(has_index(index),
		"projectile board index %d is out of range (board holds %d)" % [index, size()])
	return _source_index[index]


## Story 6-5d: WAS THIS SHOT FIRED BY A HERO? The one discriminator between the two `add*` seats, and
## the gate on every 6-5d-only behaviour (per-shot damage, the effect-authored profile, target-only
## contact, the Bloodlust/Aura inclusion, the block-multiplier exemption, the dead-target homing end).
##
## LENIENT ON THE INDEX, on `is_alive_at`'s precedent and for its exact reason: the callers include the
## contact ladder, which judges untrusted fact data, and "there is no such record" must not trip a
## guard. A record that does not exist was not fired by a hero.
func is_hero_sourced_at(index: int) -> bool:
	return has_index(index) and _effect_ids[index] != ""


## Story 6-5d: the EFFECT ID authoring this shot's flight, or `""` for a unit-fired one. A `String`, as
## stored -- the reader converts to `StringName` to index the injected pitch-effect map.
func effect_id_at(index: int) -> String:
	Invariant.check(has_index(index),
		"projectile board index %d is out of range (board holds %d)" % [index, size()])
	return _effect_ids[index]


## Story 6-5d (AC 14): the LOCKED DAMAGE this shot deals. 0.0 for a unit-fired shot, which never reads
## it (see `_damage`).
func damage_at(index: int) -> float:
	Invariant.check(has_index(index),
		"projectile board index %d is out of range (board holds %d)" % [index, size()])
	return _damage[index]


func flight_ticks_at(index: int) -> int:
	Invariant.check(has_index(index),
		"projectile board index %d is out of range (board holds %d)" % [index, size()])
	return _flight_ticks[index]


func travelled_at(index: int) -> float:
	Invariant.check(has_index(index),
		"projectile board index %d is out of range (board holds %d)" % [index, size()])
	return _travelled[index]


## AC 16 / `4-4/R4`: END HOMING. The ONE clearing path, called from the i-frame drop rung and nowhere
## else, with NO inverse — nothing in this file or any caller sets `_homing` back to true.
##
## IDEMPOTENT, deliberately: the same shot can produce a dropped fact on more than one tick while it
## keeps flying through a target whose i-frames are still open, and each of those drops ends homing
## that is already ended. A guard here would be a guard against correct behaviour.
##
## LENIENT ON THE INDEX for `is_alive_at`'s reason: the caller is judging untrusted fact data.
func end_homing_at(index: int) -> void:
	if not has_index(index):
		return
	_homing[index] = false


## AC 18 and the full-damage path alike: CONSUME this shot. The projectile's whole dedupe mechanism
## (see the header) — a resolved contact ends the shot, so it can never resolve twice, and no hit list
## is needed to say so.
##
## LENIENT AND IDEMPOTENT for `end_homing_at`'s reasons.
func consume_at(index: int) -> void:
	if not has_index(index):
		return
	_alive[index] = false


## AC 19: advance ONE live shot by this tick's flown distance, and END IT if that spends the budget.
## The caller computes the distance (it is authored-profile policy, and this is a container) and hands
## it in — the `UnitBoard.add(max_hp)` discipline: the container never reads `BalanceConfig`.
##
## THE BUDGET IS SPENT, NOT COMPARED AGAINST A POSITION. A shot ends when its ODOMETER reaches the
## authored budget, which is why AC 19's "at most 60 m of total distance" is true of a homing arc as
## well as of a straight line — an arc is longer than the chord, and this counts the arc.
##
## THE CLOCK ADVANCES EVEN ON THE ENDING TICK, so a shot that expires has a coherent final record
## rather than one whose time and distance disagree.
func advance_at(index: int, distance: float, budget: float) -> void:
	Invariant.check(has_index(index),
		"projectile board index %d is out of range (board holds %d)" % [index, size()])
	if not _alive[index]:
		return
	_flight_ticks[index] += 1
	_travelled[index] += distance
	if _travelled[index] >= budget:
		_alive[index] = false


## The LIVING indices, ascending, freshly built each call — `UnitBoard.living_indices()`'s shape and
## its reason: ascending BY CONSTRUCTION, so any caller that needs a deterministic order gets it at
## the source rather than from a sort it would have to trust.
func living_indices() -> Array[int]:
	var out: Array[int] = []
	for i in _alive.size():
		if _alive[i]:
			out.append(i)
	return out


## Snapshot payloads. SEVEN keys, on the split `UnitBoard` already established: the TARGET fuses its
## two ints into one key because a target IS one fact in two halves, and the other five are
## independent facts that would hide which one moved if they were fused.
##
## EVERY VALUE IS A PLAIN INT, BOOL OR FLOAT — types `CanonicalHash` has an explicit branch for. No
## StringName (whose `sort()` orders by internal POINTER on this engine), no object, and no position:
## `_travelled` is a path LENGTH the state layer integrated itself, not a coordinate anything pushed
## in. The ORDER IS MEANINGFUL and CanonicalHash preserves it — a heading state held by the wrong shot
## is a real divergence.
##
## Each is freshly built, so no caller receives a handle into this container.
func targets_snapshot() -> Array:
	var out: Array = []
	for i in _target_slots.size():
		out.append([_target_slots[i], _target_indices[i]])
	return out


func kind_index_snapshot() -> Array:
	return _kind_index.duplicate()


func source_index_snapshot() -> Array:
	return _source_index.duplicate()


func alive_snapshot() -> Array:
	return _alive.duplicate()


func homing_snapshot() -> Array:
	return _homing.duplicate()


func flight_ticks_snapshot() -> Array:
	return _flight_ticks.duplicate()


func travelled_snapshot() -> Array:
	return _travelled.duplicate()


## Story 6-5d (AC 30): TWO MORE KEYS, seven -> nine. ONE ARRAY -> ONE KEY APIECE, on this block's own
## stated precedent: the effect id and the damage are INDEPENDENT facts -- two Fireballs of the SAME
## effect id carry DIFFERENT damage, because the damage is the mana the player happened to have -- so
## fusing them would hide which one moved.
##
## THE TYPES ARE STILL ONES `CanonicalHash` HAS AN EXPLICIT BRANCH FOR: plain `String` VALUES (never
## keys, never StringNames -- see `_effect_ids`) and plain floats. Still no object and still no position.
## THE ORDER IS MEANINGFUL and `CanonicalHash` preserves it: damage held by the wrong shot is a real
## divergence.
func effect_id_snapshot() -> Array:
	return _effect_ids.duplicate()


func damage_snapshot() -> Array:
	return _damage.duplicate()
