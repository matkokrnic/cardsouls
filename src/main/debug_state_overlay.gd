class_name DebugStateOverlay
extends CanvasLayer

## Story 1-3c: on-screen debug overlay showing each hero's current action state, fed
## EXCLUSIVELY by the runner-wired action_state_changed seam (the D5 queued channel).
## Everything displayed is derived from the signal's (previous, current) arguments alone —
## no MatchState handle, no polling, no runner privates, no Input reads.
##
## FENCE (story 1-3c): E2 builds the real HUD. This overlay is a THROWAWAY debug tool and
## may be deleted or replaced then — E2 stories must consume the seam
## (match_runner.connect_hero_action_state_changed), never copy these internals.

const _SLOT_COUNT := 2

var _labels: Array[Label] = []
## 0-based swing index per slot, derived purely from the transition stream: increments on
## the ATTACKING -> ATTACKING self-transition, resets on any exit from ATTACKING. Mirrors
## the chain_index contract (1-3) without ever reading it.
var _swings: Array[int] = [0, 0]
var _states: Array[HeroState.ActionState] = [HeroState.ActionState.IDLE, HeroState.ActionState.IDLE]


func _init() -> void:
	name = "DebugStateOverlay"


func _ready() -> void:
	for slot in range(_SLOT_COUNT):
		var label := Label.new()
		label.name = "P%dLabel" % (slot + 1)
		label.position = Vector2(16.0 + 240.0 * slot, 8.0)
		add_child(label)
		_labels.append(label)
		# Initialize to IDLE: the signal only fires on transitions, so the first frame must
		# not wait for an emission to show something sane.
		_refresh(slot)


## Seam callback. The runner wires it per slot with
## connect_hero_action_state_changed(slot, on_hero_transition.bind(slot)).
func on_hero_transition(previous: HeroState.ActionState, current: HeroState.ActionState, slot: int) -> void:
	if previous == HeroState.ActionState.ATTACKING and current == HeroState.ActionState.ATTACKING:
		_swings[slot] += 1  # chain self-transition — made visibly distinguishable (AC 1)
	elif previous == HeroState.ActionState.ATTACKING:
		_swings[slot] = 0   # any exit from ATTACKING ends the sequence
	_states[slot] = current
	_refresh(slot)


func _refresh(slot: int) -> void:
	# Name decoded directly from the enum — no parallel string table to drift (story 1-3c).
	var state_name: String = HeroState.ActionState.keys()[int(_states[slot])]
	var text := "P%d: %s" % [slot + 1, state_name]
	if _states[slot] == HeroState.ActionState.ATTACKING:
		text += " (swing %d)" % _swings[slot]
	_labels[slot].text = text
