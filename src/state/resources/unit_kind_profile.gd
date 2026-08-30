class_name UnitKindProfile
extends Resource

## D6 data vocabulary (story 4-4, AC 6/AC 7/AC 9): ONE authored UNIT KIND — everything that
## differs between a minion, a Combat totem, a Mana Accelerator totem and a Stamina Accelerator
## totem. Pure schema, no logic, on the `MinionPriority` / `ResourceGenerationRule` precedent.
##
## ------------------------------------------------------------------------------------------
## THIS IS THE STORY THE `4-2/R17`(c) PERMISSION AND `unit_board.gd`'s HEADER WERE WAITING FOR.
## ------------------------------------------------------------------------------------------
## `unit_board.gd`'s own header says the unit record carries "NO PER-UNIT MAXIMUM, deliberately ...
## because no unit differs from another yet", and names 4-3/4-4 as the stories allowed to change
## it. `4-2/R17`(c) granted the per-unit priority field and `4-3/R6` assigned it here. `4-4/R8`
## spends both. Units differ now, so the eleven shared `BalanceConfig` globals the story's Dev Notes
## inventory (four named by AC 6, seven more by the B5 correction) become the fields below and the
## records in `attacks`.
##
## THE RECORD STILL CARRIES NO COPY OF ANY OF THIS. What `UnitBoard` gained is a single per-record
## KIND INDEX — one plain int naming which entry of `BalanceConfig.unit_kinds` governs that unit —
## and every value is read THROUGH that index, INLINE at the point of use (CONSTRAINT C), off the
## live `MatchState.balance` handle. Storing eleven copies per record would be N copies of one
## authored number and would go stale on the next X3 reload, which is precisely what CONSTRAINT C
## exists to prevent.
##
## THE KIND SET IS AUTHORED AS AN ORDERED LIST ON `BalanceConfig`, NOT SCANNED FROM A DIRECTORY,
## and the divergence from `data/minions/` and `data/economy/` is deliberate. Those two directories
## hold STRUCTURE — `EconomyEvaluator`'s header states in as many words that "a rule `.tres`
## carries no gameplay number" — which is exactly what lets them sit outside `apply_balance()`. A
## kind profile is nothing BUT gameplay numbers, so it belongs to the tuning object that travels
## through the X3 hot-reload seam. A scanned directory would put eleven live tunables beyond the
## reach of `apply_balance()` and beyond the standing `BC/R3` golden isolation.

## The name this kind is resolved BY, and the ONE identifier that crosses from a card's
## `effect_id` to a board record. `CardEffectResolver.kind_for()` maps an authored `summon_*` id to
## one of these names; `BalanceConfig.kind_index_of()` turns the name into the plain int the record
## stores.
##
## THE NAME NEVER REACHES THE SNAPSHOT — the INDEX does. `Array[StringName].sort()` orders by
## INTERNAL POINTER on this engine (player_state.gd:77, 206-207), which is deterministic within one
## process and NOT across runs or builds, so a StringName inside the hash would pass green while
## replay was already broken. The index is a plain int, hashes cleanly and is stable because the
## authored list's ORDER is authored.
##
## AN UNRECOGNISED NAME IS A NAMED OUTCOME, NEVER A CRASH: `kind_index_of()` returns
## `BalanceConfig.NO_KIND_INDEX` and the summon resolves with no record reaching the board, the
## `TargetingService.REASON_NO_PRIORITY_DATA` posture applied to a different lookup.
@export var kind_name: StringName = &""

## AC 6: how fast this kind walks toward its acquired target, world units per second — the
## successor to `BalanceConfig.unit_move_speed`, now per kind.
##
## AC 5 / `4-4/R12`: ALL THREE TOTEM KINDS AUTHOR 0.0 HERE, not only the two accelerators. The GDD
## describes a totem as a "small, unimposing static structure (wardstone, not tower)" and names the
## Combat totem among the three subtypes that line covers. Zero is therefore a DESIGN value here,
## not a missing one — which is why the authoring audit bounds this field NON-NEGATIVE per kind and
## asserts `> 0` for the minion kind specifically, rather than `> 0` for every kind (that bound
## would forbid the very authoring `4-4/R12` mandates).
@export var move_speed: float = 0.0

## AC 6: how close this kind gets to its target before it halts — the successor to
## `BalanceConfig.unit_stop_distance`, now per kind. Planar (XZ) centre-to-centre.
##
## STILL AUTHORED FOR A KIND THAT NEVER MOVES (AC 6's "no field is left undefined for a kind"): a
## speed-0 totem never closes any distance, so its stop distance decides nothing — but it is
## authored and non-negative rather than left at a default nobody chose, and the melee reach audit
## reads it.
@export var stop_distance: float = 0.0

## AC 6: this kind's MAXIMUM HP — the successor to `BalanceConfig.unit_max_hp`, now per kind. A
## freshly summoned unit of this kind enters at this value, read INLINE at the step-6 cast seat and
## handed DOWN to `UnitBoard.add()`, which is what keeps the board a pure container with no config
## dependency (the `4-3a/R6` shape, unchanged by the per-kind move).
##
## AUDITED > 0 FOR EVERY KIND: a zero maximum summons a unit that is ALREADY DEAD, so its first
## contact fact drops at the liveness rung and the kind ships invisible in the build.
@export var max_hp: float = 0.0

## AC 7 / `4-4/R8`: this kind's TARGETING PRIORITY, authored BY NAME — a reference to an existing
## `MinionPriority.priority_name` in `data/minions/`.
##
## THIS IS THE FIELD THAT REPLACES `MatchState._update_unit_targets`'s hardcoded
## `TargetingService.PRIORITY_STANDARD` LOOKUP. The rule set is still resolved by name from the
## sorted directory scan and another rule is NEVER silently substituted for a missing one: an
## absent name yields a null priority, which `TargetingService` reports as
## `REASON_NO_PRIORITY_DATA` and turns into a NO-TARGET pair. That contract carries forward
## unchanged (AC 7), as does `hero_seeker`'s test-only status — no file under `src/` names it, and
## the shipped Combat totem authors its own THIRD profile rather than reusing it (AC 8, `4-4/R9`).
##
## MINIONS KEEP `&"standard"`, so the shipped verdict for a minion is bit-for-bit unmoved by this
## field's arrival (AC 8's own clause).
@export var priority_name: StringName = &""

## AC 6 (B5 inventory): this kind's three attack-phase move-speed multipliers — the successors to
## `BalanceConfig.minion_attack_windup/active/recovery_move_speed_multiplier`, now per kind. Each
## scales this kind's approach speed while it is in that phase.
##
## AUTHORED 0.0 = FULL ROOT, the same DESIGN value (not a missing one) the globals carried, so the
## audit bound is non-negative rather than > 0. PER KIND rather than per RECORD, unlike the five
## fields on `UnitAttackProfile`: a multiplier scales this unit's MOVEMENT, which is a property of
## the kind's body, whereas windup/active/recovery/range/damage describe one particular attack.
@export var attack_windup_move_speed_multiplier: float = 0.0
@export var attack_active_move_speed_multiplier: float = 0.0
@export var attack_recovery_move_speed_multiplier: float = 0.0

## AC 9 / `4-4/R7`: this kind's attack capability as a LIST of records, never a single flat attack.
##
## LENGTH ONE IS ACCEPTABLE THIS STORY and every shipped kind authors exactly one entry; selecting
## among several is an explicit Non-Goal, so every reader takes entry 0 through `attack_at(0)`
## below. The LIST is what ships, because a future moveset story that adds a second entry must not
## have to migrate every authored kind first.
##
## AN EMPTY LIST IS THE HONEST AUTHORING FOR A KIND THAT NEVER ATTACKS, and the two accelerator
## totems author exactly that (AC 3: "the accelerators never attack"). It is not a missing value —
## `attack_at()` returns null for it and every attack-side seat reads that as "this kind has no
## attack", which is why no accelerator ever winds up, opens a hitbox or fires.
@export var attacks: Array[UnitAttackProfile] = []


## This kind's attack record at `index`, or NULL when it has none — the total-function shape
## `CastEvaluator.refusal_reason`'s null branch and `TargetingService.priority_named` both use, for
## the same reason: an honest default rather than a crash, so a kind that authors no attack simply
## never attacks instead of failing the tick.
##
## EVERY SHIPPED READER PASSES 0 (the Non-Goal above). The parameter exists so the seats read
## `attack_at(0)` rather than `attacks[0]` — the bound check lives in ONE place, and a future
## selection story changes the ARGUMENT rather than every call site's indexing.
func attack_at(index: int) -> UnitAttackProfile:
	if index < 0 or index >= attacks.size():
		return null
	return attacks[index]


## Whether this kind attacks at all — `attack_at(0) != null`, named so the seats express the
## question they are actually asking. A kind whose list is empty, or whose entry 0 is an
## unassigned null in the `.tres`, reads false through the one predicate rather than through a
## re-derived emptiness test at each seat (the `UnitBoard.has_index` / `is_alive_at` discipline:
## a guard consulting a copy is guarding the copy).
func has_attack() -> bool:
	return attack_at(0) != null
