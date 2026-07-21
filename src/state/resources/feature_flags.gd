class_name FeatureFlags
extends Resource

## The overload-isolation instrument (project-context HARD RULE; arch Configuration).
## Every gameplay layer is INDEPENDENTLY toggleable so playtests can isolate which
## layer causes cognitive overload. Loaded ONCE at startup by FeatureFlagsService and
## INJECTED into the state layer by the Match Runner.
##
## INVARIANT: state-layer code receives this resource by injection and NEVER reads
## FeatureFlagsService. Only actors / ui / systems may read the service.
##
## Each E4–E6 layer defaults OFF until its epic builds it; systems must degrade
## gracefully when a layer is off (e.g. orbs off -> pitch cost is mana-only).

@export var melee_mana_generation: bool = true   # E1
@export var unblockable: bool = false            # E5
@export var orbs: bool = false                   # E5
@export var pitch_zone: bool = false             # E6
@export var minions: bool = false                # E4
@export var totems: bool = false                 # E4
@export var equipment: bool = false              # E8
