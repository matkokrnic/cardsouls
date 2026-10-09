class_name Enums
extends RefCounted

## Shared gameplay enums for the state layer. State must never reference src/actors/ or
## src/ui/, so cross-layer enums live here (project-context §Naming). Referenced as
## Enums.CardColor.RED etc. Never bare strings for card color.

## First-class card color, used across unblockable attacks, defenses, and orbs (E5).
##
## STORY 6-5e (AC 4/AC 4a, `6-5e/R26`/G7 -- OPERATOR RULING, not a dev-pass choice): a FOURTH member,
## `COLORLESS`, APPENDED AFTER `GREEN`. The three existing ordinals (`RED` 0, `BLUE` 1, `GREEN` 2) are
## UNCHANGED, which is what keeps every authored `color = 0/1/2`, every `orb_costs` key and every
## recorded colour byte-identical -- appending is the only edit to this enum that is not a content
## migration.
##
## IT IS NEVER AN ORB COLOUR. `OrbPool`, `CastEvaluator.sorted_orb_colors`, `hud_root.ORB_COLORS` and
## `ORB_INITIALS` all stay THREE long and are indexed by an orb-COST colour, which a colourless card
## never authors (Boulder has no pitch effect and no orb cost anywhere, ruling 7). The one reader that
## indexed a 3-element array by a CARD's colour ordinal -- `hud_root._set_swatch_color` -- is guarded to
## render neutral grey for this member instead of reading out of range (AC 4a).
##
## THE ONLY COLOURLESS CARD IS BOULDER, and it is authored data like any other card, so
## `_derive_card_colors()` maps it as the real colourless ordinal rather than a silent default (its own
## "nothing is skipped here" header). Modes ② and ③ derive entirely from colour and this member names no
## unblockable and no defence, which is what makes ruling 7's "Boulder has exactly one legal action"
## true of the colour rather than of a list of exceptions.
enum CardColor { RED, BLUE, GREEN, COLORLESS }

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

## Story 7-4 (AC 1, `7-4/R14`): a card's PITCH SPEED -- how a staged card in the Pitch Zone counts orbs.
## `INSTANT` is READY as soon as the bank holds its orb price (the 6-2/6-3a rule, unchanged); `SORCERY`
## counts only orbs EARNED while it sits in the zone (`PitchState._fresh_orbs`). Authored per card on the
## pitch `CardCastCondition.pitch_speed`.
##
## INSTANT IS DELIBERATELY FIRST, so it is the zero value an unauthored field carries: a card that
## authors no speed reads instant (AC 1) with no default-handling code anywhere, the `ModeKind.BASIC`
## precedent directly above.
enum PitchSpeed { INSTANT, SORCERY }
