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

## STORY 7-3 (`7-3/R21`): THE THREE ATTACK-PHASE MOVE-SPEED MULTIPLIERS LEFT THIS CLASS. They stood
## here as `attack_windup/active/recovery_move_speed_multiplier` since 4-4 and are now authored per
## ATTACK (`UnitAttackProfile.windup/active/recovery_move_speed_multiplier`), removed rather than kept
## alongside -- a hound's bite is rooted and its leap travels, so the kind can no longer answer.

## ------------------------------------------------------------------------------------------
## STORY 7-3: THE FACTS A SECOND MELEE KIND (the Hellhound) NEEDS. All flat exports, no nested
## resource, so `RecordFile._fresh_nested` needs no new tag.
## ------------------------------------------------------------------------------------------

## AC 5 (`7-3/D4`): IS THIS KIND A MINION -- the authored fact behind "leaves a corpse", Culling,
## Drain, Corpse Bomb, Raise Dead and Bloodlust, replacing the three literal `kind_name == &"minion"`
## tests. True for the zombie and the hound, false for the three totem kinds.
##
## DEFAULT FALSE: a kind that does not say it is a minion is covered by none of those rules, which is
## the totem exclusion's direction and the reason `RecordFile.FORMAT_VERSION` moved with this field
## (a v22 `minion` row would rebuild false and its zombie would leave no corpse).
@export var is_minion: bool = false

## AC 7 / AC 8 (`7-3/R19`): does DAMAGE this unit survives, or a DEFLECT of its own attack, interrupt
## whatever swing it is in and start the hit reaction. Both true for the hound, both false for the
## zombie, whose swing is still never interrupted (`4-3b` no-stagger, `4-3b/R7`).
@export var react_on_damage: bool = false
@export var react_on_deflect: bool = false

## AC 7 / AC 11: how long the hit reaction holds the unit before it backs off, in seconds. Converted
## once through `BalanceTicks` (`UnitKindTicks.reaction_ticks`). A zero reaction ends on the next tick.
@export var reaction_seconds: float = 0.0

## AC 16 (`7-3/R17`): the GET-UP lockout of a record that rose from a corpse (Raise Dead or a
## Counterspell restore), in seconds. During it the unit cannot attack and has no hit reaction. 0.0
## means no lockout at all -- the zombie's authoring, so a raised zombie is attack-ready as before.
@export var get_up_seconds: float = 0.0

## AC 12 (`7-3/R20`): THE BETWEEN-ATTACK BEHAVIOUR. After an attack's recovery, and after a hit
## reaction, the unit BACKS OFF for a duration drawn in [min, max], then CIRCLES for a duration drawn
## in [min, max] in a drawn direction, then re-engages. Every draw is on `MatchState._rng`, at step
## 3b, at phase entry.
##
## ALL FOUR AT 0.0 MEANS THE KIND HAS NO SUCH BEHAVIOUR AND DRAWS NOTHING (`has_between_attack_
## behaviour()` below) -- the zombie's authoring, which is what keeps `rng_state` unmoved by a zombie.
@export var back_off_min_seconds: float = 0.0
@export var back_off_max_seconds: float = 0.0
@export var circle_min_seconds: float = 0.0
@export var circle_max_seconds: float = 0.0

## The probability, in [0, 1], that a circle goes CLOCKWISE (seen from above). One draw per circle.
@export var circle_clockwise_chance: float = 0.5

## The probability, in [0, 1], that a unit leaving its circle re-engages with its LEAP (attack entry
## 1) rather than its BITE (entry 0). One draw per re-engage. At 0.0 it always comes back to bite; at
## 1.0 it always comes back to leap, and still bites if the close band is confirmed first. The first
## engagement after a summon or a get-up draws nothing and follows the two reach bands.
@export var leap_chance: float = 0.5

## STORY 7-3, FEEL PASS: WHAT A UNIT DOES WHEN ITS BACK-OFF ENDS. It draws ONE of four options by
## these weights: CIRCLE (as before), STALK (stand and watch for a drawn time), FEINT (dart partway in
## and back out without attacking) or RE-ENGAGE at once. Every option ends in the re-engage draw
## above. Weights are relative and need not sum to one.
##
## ALL FOUR AT 0.0 MEANS "ALWAYS CIRCLE" -- the rule that stood before this pass, and every fixture's
## default. The decision draws the same number of times whatever the weights are.
@export var circle_weight: float = 0.0
@export var stalk_weight: float = 0.0
@export var feint_weight: float = 0.0
@export var re_engage_weight: float = 0.0

## The stalk's drawn duration, in [min, max] seconds.
@export var stalk_min_seconds: float = 0.0
@export var stalk_max_seconds: float = 0.0

## The feint: the dart IN lasts a duration drawn in [min, max]; the retreat that follows it lasts
## `feint_retreat_seconds`, undrawn.
@export var feint_min_seconds: float = 0.0
@export var feint_max_seconds: float = 0.0
@export var feint_retreat_seconds: float = 0.0

## The probability, in [0, 1], that a circle REVERSES its direction once (drawn at circle entry), and
## how much of the circle is left, in seconds, when it does. A circle shorter than that reverses on
## its first tick; the authoring audit keeps it below `circle_min_seconds`.
@export var circle_flip_chance: float = 0.0
@export var circle_flip_remaining_seconds: float = 0.0

## TEMPERAMENT: each unit of this kind differs from its siblings by a factor in
## [1 - spread, 1 + spread], fixed for its life and derived from its owner slot and board index
## (`UnitTemperament`), never drawn. `temperament_weight_spread` scales the four option weights above
## and the leap-against-bite weight, and is the only one `advance()` reads; the other three scale
## actor-side motion (move speed, circle radius, circle wobble) and are read by the runner.
@export var temperament_weight_spread: float = 0.0
@export var temperament_speed_spread: float = 0.0
@export var temperament_radius_spread: float = 0.0
@export var temperament_wobble_spread: float = 0.0

## STORY 7-3, FEEL PASS 2: WHAT A UNIT DOES WHEN AN ATTACK ENDS (its recovery exit). It draws ONE of
## three by these weights: BACK OFF (the rule that stood before), PRESS (attack again at once, with no
## back-off -- a chain is at most three attacks, `UnitBoard.PRESS_LEVEL_MAX`) or RUN ON (keep running
## the way it landed for a drawn time; offered only after an attack that carried it past its target,
## one whose record authors a `travel_overshoot`). Relative weights, scaled by temperament.
##
## ALL THREE AT 0.0 MEANS "ALWAYS BACK OFF", every fixture's default. The decision draws the same
## number of times whatever the weights are.
@export var back_off_weight: float = 0.0
@export var press_weight: float = 0.0
@export var run_on_weight: float = 0.0

## The run-on's drawn duration, in [min, max] seconds.
@export var run_on_min_seconds: float = 0.0
@export var run_on_max_seconds: float = 0.0

## FEEL PASS 2: TWO MORE OPTIONS WHEN A BACK-OFF ENDS, beside circle / stalk / feint / re-engage.
## REPOSITION: run round the target for a duration drawn in [min, max], in a drawn direction, then
## re-engage from the new side. At the authored pace and radius the range is a quarter to a full lap
## (the authoring audit holds it there). RETREAT: go away from the target for a duration drawn in
## [min, max], then re-engage -- with the leap at `retreat_leap_chance` rather than `leap_chance`.
@export var reposition_weight: float = 0.0
@export var reposition_min_seconds: float = 0.0
@export var reposition_max_seconds: float = 0.0
@export var retreat_weight: float = 0.0
@export var retreat_min_seconds: float = 0.0
@export var retreat_max_seconds: float = 0.0
@export var retreat_leap_chance: float = 0.0

## FEEL PASS 3: ONE MORE OPTION WHEN A BACK-OFF ENDS, the ORBIT -- a circle in every respect state
## knows of (a countdown, a drawn direction, one drawn reversal; it faces its target and its radius
## breathes) except how long it lasts: a duration drawn in [min, max] here, several times a circle's.
## A small weight keeps it rare. It has its own two phases (`ORBIT`, `ORBIT_TURN`) so the body can
## STRAFE it: see `orbit_approach_share`.
@export var orbit_weight: float = 0.0
@export var orbit_min_seconds: float = 0.0
@export var orbit_max_seconds: float = 0.0

## ACTOR-SIDE, feel pass 3: the most of its orbiting speed a unit spends getting ONTO its orbit's
## radius (or following it as it breathes); the rest goes round. A circle steers straight at the next
## point of its ring, so a unit that starts inside it walks backwards until it is out there; an orbit
## is watched for seconds, and at 0.3 the body's motion stays within 18 degrees of sideways -- a strafe,
## even for a rig that came into the orbit walking backwards and holds that clip a margin past its edge.
@export var orbit_approach_share: float = 0.0

## ACTOR-SIDE, feel pass 2, read by the runner and never by `advance()`: the fraction of `move_speed`
## the body runs on, repositions and retreats at, and the planar distance from its target a retreating
## unit stops at however long its retreat lasts.
@export var run_on_move_speed_multiplier: float = 0.0
@export var reposition_move_speed_multiplier: float = 0.0
@export var retreat_move_speed_multiplier: float = 0.0
@export var retreat_distance: float = 0.0

## ACTOR-SIDE motion data for those two phases, read by the runner and never by `advance()`: the
## fraction of `move_speed` the body backs off and circles at, and the planar distance from the target
## it circles at ("how wide the circle is").
@export var back_off_move_speed_multiplier: float = 0.0
@export var circle_move_speed_multiplier: float = 0.0
@export var circle_radius: float = 0.0

## ACTOR-SIDE, feel pass: the circle is not a circle. Its radius breathes by `circle_wobble_amplitude`
## (a fraction of the radius) over `circle_wobble_seconds`, and its speed varies by
## `circle_speed_variation` (a fraction of the circle speed). All 0.0 is the plain circle.
@export var circle_wobble_amplitude: float = 0.0
@export var circle_wobble_seconds: float = 0.0
@export var circle_speed_variation: float = 0.0

## ACTOR-SIDE, feel pass: the feint's dart speed as a fraction of `move_speed`, and how close to the
## target the dart goes before it holds.
@export var feint_move_speed_multiplier: float = 0.0
@export var feint_closest_distance: float = 0.0

## ACTOR-SIDE, feel pass: a moving unit of this kind steers away from any other unit closer than
## `separation_distance`, at up to `separation_strength` times its own move speed. 0.0 distance means
## no steering (the zombie).
@export var separation_distance: float = 0.0
@export var separation_strength: float = 0.0

## ACTOR-SIDE, feel pass: how fast the body may turn to face its target outside a swing, in degrees
## per second. 0.0 means it snaps (the zombie). A swing still locks its heading exactly.
@export var turn_rate_degrees_per_second: float = 0.0

## AC 18: the minimum interval between two barks, in seconds. Presentation-only cadence data (the
## sound has no gameplay effect); 0.0 means the kind does not bark.
@export var bark_interval_seconds: float = 0.0

## Feel pass: the probability, in [0, 1], that a unit barks as it starts to back off, once the
## interval above has passed. Presentation-only, like the interval.
@export var bark_chance: float = 0.0

## ------------------------------------------------------------------------------------------
## STORY 7-5b (AC 6/AC 7): THE HEALER's FACTS. All flat exports, every default neutral, so a kind that
## authors none of them never heals and never fires on its owner's chargeup.
## ------------------------------------------------------------------------------------------

## AC 6 (`7-5b/R3`): each living unit of this kind heals its OWNER by `heal_amount` every
## `heal_interval_seconds` (converted once, `UnitKindTicks.heal_interval_ticks`) if the runner reports it
## within `heal_range` metres of the owner on that tick. Out of range the clock keeps running and the tick
## heals nothing. `heal_range` is read by the RUNNER only (the range fact enters through
## `MatchState.push_heal_range`); `advance()` never reads a distance.
##
## Smoke fix 1 (S1/S2): `heal_range` is ALSO the follow band's OUTER radius -- the runner keeps a follower still
## while its owner is within it and walks it after the owner beyond it, to `stop_distance` (the INNER radius) --
## so "in heal range" and "standing still" are one number, never two that could disagree.
@export var heal_amount: float = 0.0
@export var heal_interval_seconds: float = 0.0
@export var heal_range: float = 0.0

## AC 7: the EFFECT ID whose damage and flight a unit of this kind fires at the opposing hero when its
## owner's unblockable chargeup begins, and the delay from that tick to the shot's spawn tick, in seconds
## (converted once, `UnitKindTicks.shot_delay_ticks`; zero fires on the chargeup tick itself). Empty means
## the kind never fires on a chargeup.
@export var owner_chargeup_shot_effect: StringName = &""
@export var shot_delay_seconds: float = 0.0

## AC 9 / `4-4/R7`: this kind's attack capability as a LIST of records, never a single flat attack.
##
## STORY 7-3 (`7-3/R5`/`R20`): UP TO TWO ENTRIES ARE SELECTED AMONG. Entry 0 is the CLOSE attack and
## entry 1, when authored, the MID-RANGE one; each has its own reach probe and the windup gate picks
## the close one when both are confirmed (`MatchState._advance_unit_attacks`). A kind authoring one
## entry behaves exactly as it did when every reader took entry 0.
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
## THE PARAMETER IS THE SELECTION (story 7-3): a seat judging the swing in progress passes the record's
## chosen entry, the reach probes pass 0 and 1, and a seat that only asks "does this kind attack at
## all" passes 0. The bound check lives in ONE place — here — never at a call site as `attacks[i]`.
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


## Story 7-3 (AC 12): does this kind back off and circle between attacks. THE ONE PREDICATE the
## seeded draws are gated on -- a kind answering false never reaches `MatchState._rng`.
func has_between_attack_behaviour() -> bool:
	return back_off_max_seconds > 0.0 or circle_max_seconds > 0.0


## Feel pass: the option weights in `MatchState.OPTION_*` order (circle, stalk, feint, re-engage and,
## since feel pass 2, reposition and retreat), as authored. All zero reads as "always circle" at the
## one seat that draws against them.
func between_attack_weights() -> Array[float]:
	return [circle_weight, stalk_weight, feint_weight, re_engage_weight, reposition_weight,
			retreat_weight, orbit_weight]


## Feel pass 2: the three weights of what a unit does when an attack ends, in `MatchState.AFTER_*`
## order (back off, press, run on), as authored. All zero reads as "always back off".
func after_attack_weights() -> Array[float]:
	return [back_off_weight, press_weight, run_on_weight]
