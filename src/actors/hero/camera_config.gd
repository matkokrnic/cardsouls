class_name CameraConfig
extends Resource

## Camera framing (story 1-2): third-person distance/height/pitch for the hero CameraRig.
## PRESENTATION config — deliberately NOT part of BalanceConfig and NOT on the X3
## hot-reload path. Authored as data/camera_config.tres (data-as-resources) and loaded
## ONCE at match setup, like FeatureFlags. Defaults are zero on purpose: framing numbers
## are authored in the .tres, never in code or scene-script literals.

@export var distance: float = 0.0        # metres behind the hero pivot (fixed — no zoom)
@export var height: float = 0.0          # metres above the hero pivot
@export var pitch_degrees: float = 0.0   # downward camera tilt; must never tilt movement
