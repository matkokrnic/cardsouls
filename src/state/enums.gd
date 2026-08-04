class_name Enums
extends RefCounted

## Shared gameplay enums for the state layer. State must never reference src/actors/ or
## src/ui/, so cross-layer enums live here (project-context §Naming). Referenced as
## Enums.CardColor.RED etc. Never bare strings for card color.

## First-class card color, used across unblockable attacks, defenses, and orbs (E5).
enum CardColor { RED, BLUE, GREEN }

## Story 3-5a (AC 9): the four ways a card can be played — the GDD's modes ①②③④. Seated HERE,
## beside CardColor, because the architecture doc's Novel Pattern 6 sketch presents a mode enum
## as free-standing with no owning class named, and nothing named ModeKind existed anywhere in
## src/ before this story (recorded as the EIGHTH architecture-amendment-queue member; no edit
## to that doc here).
##
## ONLY `BASIC` RESOLVES IN E3. The other three are declared — and NOT authored — for one
## reason: AC 2 requires the modes beyond the basic one to be GUARDED STUBS, and a stub cannot
## be guarded against a value that does not exist. Their resolution branches are
## `Invariant.check` failures in MatchState._resolve_card_action, pinned unreachable by
## test_card_play.gd::test_non_basic_modes_are_guarded_stubs. UNBLOCKABLE (②) and DEFENSE (③)
## are E5 and derive entirely from CardData.color; PITCH (④) is E6 and is the pitch zone's.
##
## Declaration order is a CONTRACT once it is snapshot-adjacent: BASIC is deliberately FIRST so
## it is the zero value an unset intent field carries, which is why InputIntent.card_mode can
## default to it without naming a "none" member the state layer would then have to reject.
enum ModeKind { BASIC, UNBLOCKABLE, DEFENSE, PITCH }
