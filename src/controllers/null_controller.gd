class_name NullController
extends Controller

## D3 null controller (story 1-6): the training-dummy driver. `sample()` inherits the base
## Controller behavior UNCHANGED — a FRESH empty InputIntent every tick (no move, no
## presses, no holds), so a slot assigned this kind never acts and never moves. It adds no
## logic ON PURPOSE: its whole value is being a nameable controller KIND at the runner's
## per-slot config point, keeping "dummy" a configuration fact and nothing else. dummy ->
## PvP -> bot is therefore a one-line config swap (KeyboardController / GamepadController /
## ScriptedController), never a hero/actor/state edit.
##
## Dummy identity is settled by architecture amendment A3 (game-architecture.md v1.2, commit
## d6ab666): the dummy is a NullController-driven standard slot, NOT a distinct actor type —
## no actors/dummy/, no dummy class, no dummy scene.
