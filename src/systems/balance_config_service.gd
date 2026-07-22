extends Node

## Autoload. Loads the BalanceConfig .tres and exposes it. Unlike FeatureFlags,
## balance is HOT-RELOADABLE at runtime (X3): reload() re-reads the .tres so the
## Match Runner can re-apply values to live state mid-match without restarting —
## reload() -> MatchState.apply_balance(get_config()) re-injects bounds and
## re-converts durations (story 1-1). State receives BalanceConfig by INJECTION
## and never reads this autoload.
##
## The schema (src/state/resources/balance_config.gd) and the authored .tres
## exist since E1 story 1-1; reload() remains a safe no-op if the file is absent.

const CONFIG_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig


func _ready() -> void:
	reload()


## Re-reads the balance .tres (X3 hot-reload). Safe no-op if the file is absent.
func reload() -> void:
	if not ResourceLoader.exists(CONFIG_PATH):
		push_warning("BalanceConfigService: no balance config at %s" % CONFIG_PATH)
		return
	_config = load(CONFIG_PATH) as BalanceConfig


func get_config() -> BalanceConfig:
	return _config
