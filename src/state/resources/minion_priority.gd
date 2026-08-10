class_name MinionPriority
extends Resource

## D6 data vocabulary (story 4-2, AC 1): ONE authored minion TARGETING PRIORITY. The
## ResourceGenerationRule / CardCastCondition precedent applied unchanged (`E4-P/R5`) — pure
## schema, no logic (src/state/resources/ is the "Resource SCHEMA classes (.gd) — pure data
## vocabulary" tier); TargetingService is the one place these are read.
##
## PARAMETRIC, NOT TYPE-NAME-KEYED (`4-2/R16`). It is FALSE that "new priority types are addable
## with zero code changes", because selection POLICY is code. So the fields below carry
## PARAMETERS a GENERIC evaluator applies — which side to look at, whether the hero outranks a
## unit, how the candidate list is ordered — on the ResourceGenerationRule `amount_field`
## precedent, where the rule names a FIELD and the evaluator stays generic. No gameplay NUMBER is
## baked in here for the same reason a rule carries no float: every number lives in BalanceConfig
## and is read inline (CONSTRAINT C). The retarget CADENCE in particular is a shared balance field
## (`minion_retarget_interval_seconds`), never a per-priority value.
##
## AN UNRECOGNIZED PARAMETER IS A NAMED RETURNED REASON, NEVER A CRASH (AC 1, AC 6). Both enum
## fields below are authored as plain ints in a `.tres`, so a value outside the recognized
## vocabulary is REACHABLE from authored data — and that is precisely what makes AC 6's second
## reason (`TargetingService.REASON_NO_PRIORITY_DATA`) provable non-vacuously rather than a branch
## nothing can reach.
##
## EXACTLY TWO `.tres` FILES ARE AUTHORED THIS STORY (AC 1) — `standard.tres` and
## `hero_seeker.tres`, the two expressible today. `Tank` (needs HP, 4-3) and `Bomber`/AoE (needs
## position, 4-3/4-4) are named DEFERRED, not authored: a priority whose ordering mode cannot be
## evaluated because the facts it names do not exist yet would be reserved vocabulary authored
## ahead of its consumer.

## Which side the candidate set is drawn from. `OPPOSING` is the whole vocabulary today, and that
## is `4-2/R3`'s ruling rather than a placeholder: the candidate set is the OPPOSING side ONLY —
## the opposing hero plus the units on the opposing player's board — and own-side units are never
## candidates. A SELF or ALLY side needs a friendly-targeting mechanic that does not exist and no
## story owns; authoring the enum member now would be exactly the reserved vocabulary `E4-P/R2`
## names. An out-of-vocabulary authored int falls to AC 6's named no-target reason.
enum TargetSide {
	OPPOSING,  ## the opposing hero + the opposing board (`4-2/R3`)
}

## How the candidate list is ordered before one candidate is taken from it.
## `SLOT_THEN_INDEX_ASCENDING` is the whole vocabulary today, and it is THE tie-break `4-2/R3`
## fixed by name: slot ascending (the fixed P1 -> P2 order, match_state.gd:177) then board index
## ascending. `4-2/R3` deleted "or an equivalent stable, authored ordering", so this field may
## never be a way to change that total order — it names WHICH order, and there is one.
##
## The deferred siblings are named rather than authored, and each is deferred because the FACTS it
## would order by do not exist yet: a NEAREST mode needs unit position (`4-2/R14` defers position
## ownership to 4-3) and a LOWEST_HP mode needs unit HP (4-3). This is the same deferral AC 1
## applies to the `Tank` and `Bomber` priorities themselves, stated at the field that would carry
## them. An out-of-vocabulary authored int falls to AC 6's named no-target reason.
enum OrderingMode {
	SLOT_THEN_INDEX_ASCENDING,  ## the fixed total order (`4-2/R3`)
}

## The name this priority is resolved BY (`4-2/R17`). Selection is an EXPLICIT NAMED CONSTANT
## looked up in the sorted rule set — `TargetingService.PRIORITY_STANDARD` — and NEVER "whatever
## sorts first": a filename-order default would silently change which priority governs the game
## the moment a third `.tres` is authored. An absent name falls to AC 6's named
## missing-data reason; another rule is NEVER silently substituted.
@export var priority_name: StringName = &""

@export var target_side: TargetSide = TargetSide.OPPOSING

## Whether the opposing HERO outranks the opposing UNITS, or the other way round. This is the
## PRIORITY; `ordering_mode` above is only the tie-break WITHIN a rank, which is how the two
## coexist without contradicting `4-2/R3`: `prefer_hero` partitions the candidate set into
## hero-first or units-first, and the fixed total order picks inside whichever partition is taken.
##
## The two authored `.tres` differ in exactly this field, deliberately: without a differing pair
## there is no way to prove the evaluator is GENERIC rather than a hardcoded branch.
@export var prefer_hero: bool = false

@export var ordering_mode: OrderingMode = OrderingMode.SLOT_THEN_INDEX_ASCENDING
