class_name LockOnResolver
extends RefCounted

## Story 4-6 (AC 10/AC 11, `CC/R3`/`CC/R5`): the FLICK's candidate pick, and nothing else.
##
## PRESENTATION-SIDE BY RULING, NOT BY CONVENIENCE. A flick names a SCREEN-SPACE direction, so
## resolving it needs a camera and world positions -- neither of which may enter `src/state/`
## (D3(b)/A2). `CC/R5` puts the resolution out here and sends only the RESULT inward as an input
## fact, the same shape the contact fact has had since 1-8: the runner reports, state decides what
## the report means.
##
## PURE AND POSITION-FREE ANYWAY. This class never touches a camera, a node or the scene tree --
## the runner does the unprojection and hands in plain screen-space `Vector2`s. That is what makes
## the pick headlessly testable without a viewport, and it is why the file is a static helper
## beside the runner rather than logic inside it (the story's Project Structure Notes sanction "a
## new presentation-side helper"; no new folder is implied).
##
## IT IS NOT `TargetingService`. That evaluator answers "which enemy does this MINION attack" and
## is explicitly NOT reused here (the story's Non-Goals). The only thing borrowed from it is the
## `[slot, index]` ADDRESS convention, and the runner does that borrowing, not this file.

## The narrowest a flick may be and still count as pointing AT a candidate: cos(60 deg) = 0.5, so
## the accepted cone is 120 degrees wide, 60 either side of the flick. Written as the literal
## rather than `cos(deg_to_rad(60.0))` because a GDScript `const` must be a constant expression.
##
## WIDE ON PURPOSE. A flick is a coarse gesture made under pressure; a narrow cone turns "switch
## to the thing on my left" into a precision task. Ties inside the cone are broken by SCREEN
## PROXIMITY below, so a wide cone costs accuracy nothing -- it only decides what counts as a
## no-op (AC 10: a flick with no candidate in that direction changes nothing).
const MIN_ALIGNMENT := 0.5


## Returns the INDEX into `candidate_screens` of the best candidate in the flicked direction, or
## -1 when there is none -- which the caller turns into AC 10's no-op by sending no request at all.
##
## Parallel arrays, deliberately: the caller keeps `[slot, index]` addresses index-aligned with
## these screen positions, so this function stays a pure geometric pick over `Vector2`s and never
## learns what an address is.
##
## THE ORDER IS ALIGNMENT FIRST, PROXIMITY SECOND. Every candidate inside the cone is a legitimate
## answer to "that way", so the tie-break asks which one the player most plausibly meant, and on
## screen that is the nearest. Both comparisons are STRICT, so exact ties resolve to the LOWER
## index -- the caller gathers hero-then-units in board-index order, so an exact tie is broken
## deterministically and by the same total order the rest of the project uses (`4-3b/R5`).
static func best_candidate(hero_screen: Vector2, flick: Vector2,
		candidate_screens: Array[Vector2]) -> int:
	if flick.is_zero_approx():
		return -1
	var aim := flick.normalized()
	var best := -1
	var best_alignment := MIN_ALIGNMENT
	var best_distance := 0.0
	for i: int in candidate_screens.size():
		var offset := candidate_screens[i] - hero_screen
		if offset.is_zero_approx():
			continue  # a candidate sitting on the hero names no direction
		var distance := offset.length()
		var alignment := (offset / distance).dot(aim)
		if alignment < MIN_ALIGNMENT:
			continue
		if best == -1 or alignment > best_alignment \
				or (alignment == best_alignment and distance < best_distance):
			best = i
			best_alignment = alignment
			best_distance = distance
	return best
