extends Node

## Autoload. Loads the BalanceConfig .tres and exposes it. Unlike FeatureFlags,
## balance is HOT-RELOADABLE at runtime (X3): reload() re-reads the .tres so the
## Match Runner can re-apply values to live state mid-match without restarting.
## State receives BalanceConfig by INJECTION and never reads this autoload.
##
## E0: the BalanceConfig schema + .tres are authored in E3 (balance numbers are
## TBD-in-playtest content). Until then reload() is a safe no-op when the file is
## absent — the service and its hot-reload path exist from the start, not retrofitted.

const CONFIG_PATH := "res://data/balance/balance_config.tres"

var _config: Resource


func _ready() -> void:
	reload()


## Re-reads the balance .tres (X3 hot-reload). Safe no-op until E3 authors the file.
func reload() -> void:
	if not ResourceLoader.exists(CONFIG_PATH):
		push_warning("BalanceConfigService: no balance config at %s yet (authored in E3)" % CONFIG_PATH)
		return
	_config = load(CONFIG_PATH)


func get_config() -> Resource:
	return _config
