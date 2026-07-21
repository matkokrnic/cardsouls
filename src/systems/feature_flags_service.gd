extends Node

## Autoload. Loads the FeatureFlags .tres ONCE at startup and exposes it read-only.
##
## HARD RULE: only actors / ui / systems may read this service. State-layer code
## receives the FeatureFlags resource by INJECTION from the Match Runner and never
## reads this autoload. FeatureFlags is load-once by design (NOT hot-reloadable;
## contrast BalanceConfigService, which is).

const FLAGS_PATH := "res://data/feature_flags.tres"

var _flags: FeatureFlags


func _ready() -> void:
	_flags = load(FLAGS_PATH) as FeatureFlags
	if _flags == null:
		push_error("FeatureFlagsService: could not load %s" % FLAGS_PATH)


func get_flags() -> FeatureFlags:
	return _flags
