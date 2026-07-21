class_name Enums
extends RefCounted

## Shared gameplay enums for the state layer. State must never reference src/actors/ or
## src/ui/, so cross-layer enums live here (project-context §Naming). Referenced as
## Enums.CardColor.RED etc. Never bare strings for card color.

## First-class card color, used across unblockable attacks, defenses, and orbs (E5).
enum CardColor { RED, BLUE, GREEN }
