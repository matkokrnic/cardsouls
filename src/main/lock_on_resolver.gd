class_name LockOnResolver
extends RefCounted

## Story 4-6 (AC 10/AC 11, `CC/R3`/`CC/R5`): the FLICK's candidate pick, and nothing else.
## Story 4-6a (AC 1-AC 7) REPLACES THE ALGORITHM AND KEEPS THE SEAT: the 120-degree alignment cone
## with its proximity tie-break is gone; the pick is now ADJACENT-BY-SCREEN-X CYCLING relative to
## the CURRENT TARGET. The 4-6 live smoke (playtest-log 31.8., item DODATNO) asked whether literal
## left/right-by-screen-position would suit better than a best-match cone, and the ruling
## (`sprint-status.yaml` 4-6a `story_notes`, 2026-08-31) says it does.
##
## WHY THE ANCHOR MOVED, which is the whole of the change: the cone measured direction FROM THE
## HERO, so "flick left" meant "something lying leftward of me" -- which on a bunched board is
## whatever happens to be most aligned, not the next thing over. Cycling measures FROM THE CURRENT
## TARGET, so "flick left" means "the next one to the LEFT of what I have", which is the property a
## player can actually predict from the screen. That is why this function takes an `anchor` rather
## than a `hero_screen`, and it is the only reason the parameter was renamed.
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


## Returns the INDEX into `candidate_screens` of the candidate immediately ADJACENT to `anchor`
## along the flicked horizontal direction, or -1 when there is none -- which the caller turns into
## the AC 2 no-op by sending no request at all.
##
## RENAMED FROM `best_candidate` (story 4-6a, Open Question 4 -- the signature question was
## delegated to this dev pass). The parallel-array/index-return SHAPE survives unchanged, because
## it is what keeps this function a pure geometric pick that never learns what an address is; the
## NAME did not survive, because nothing here is "best" any more. There is no ranking left -- the
## pick is the nearest thing in one direction, which is a different question from the one the old
## name asked, and a stale name on a replaced algorithm is how a reader ends up trusting a cone
## that is no longer there.
##
## `anchor` IS THE CURRENT TARGET'S SCREEN POSITION, not the hero's. The caller must NOT include
## the current target in `candidate_screens` (AC 4: the exclusion is what makes a flick a SWITCH);
## the anchor is passed alongside the pickable set, never inside it. A caller that has no anchor --
## the current target is behind the camera or off the viewport rect -- must not call this at all
## (AC 5, `4-6a/R1`: that is a no-op, and it is the CALLER's guard because only the caller can tell
## "no anchor" apart from "no candidate").
##
## HORIZONTAL-ONLY, DECIDED BY MAGNITUDE (AC 3/AC 6). A flick is horizontal when `abs(x) > abs(y)`;
## anything else -- a purely vertical flick, and a perfect 45-degree diagonal -- is a no-op. The
## comparison is STRICT in favour of the vertical no-op on purpose: an exact diagonal names no
## horizontal intent any more than it names a vertical one, and refusing it is the reading that
## cannot surprise a player, since the alternative silently retargets on a gesture they did not aim.
## The threshold that decides whether a deflection is a flick AT ALL lives in the controller layer
## (`GamepadProfile.flick_threshold`, 0.7, UNCHANGED by AC 8) -- this only sorts a flick that
## already happened into an axis.
##
## NO WRAP (AC 2): a flick past the last candidate in that direction finds nothing and returns -1.
## The standing lock is left alone rather than jumping to the far side of the screen, which is the
## behaviour every Souls-family lock-on has and the one a player can steer without looking away.
##
## THE DIRECTION FILTER IS STRICT (`> 0`), so a candidate sharing the anchor's screen X EXACTLY
## lies neither left nor right of it and is not reachable by a flick from that anchor. That is the
## honest reading of "adjacent in the flicked direction": including it would make a left flick and
## a right flick pick the SAME candidate, and -- because the current target is excluded from the
## pickable set -- would trap cycling in a two-element loop between co-X candidates instead of
## letting it travel outward across the board.
##
## TIES BREAK ON THE LOWER INDEX (AC 7), delivered by the STRICT `<` below rather than by a second
## comparison: the caller gathers hero-then-units in board-index order, so the first candidate
## found at a given distance wins and the tie resolves deterministically by the same total order
## the rest of the project uses (`4-3b/R5`). This is the tie-break the replaced resolver enforced
## the same way (`lock_on_resolver.gd:40-44` before this pass), carried forward verbatim in
## mechanism as well as in outcome.
static func adjacent_candidate(anchor: Vector2, flick: Vector2,
		candidate_screens: Array[Vector2]) -> int:
	if flick.is_zero_approx():
		return -1
	if absf(flick.x) <= absf(flick.y):
		return -1  # vertical (or exactly diagonal) names no cycling direction -- AC 3/AC 6
	# Screen X and stick X share the same sign convention (`controller.gd:43`), so the SIGN of x
	# IS the direction: +1 cycles right, -1 cycles left. No camera, no basis, no world axis.
	var direction := signf(flick.x)
	var best := -1
	var best_gap := 0.0
	for i: int in candidate_screens.size():
		# Signed distance along screen X ONLY (review L1: `flick.y` is discarded once the axis
		# test above passes -- this is not a projection along the flick vector). Positive means
		# "further in the direction I flicked".
		var gap := (candidate_screens[i].x - anchor.x) * direction
		if gap <= 0.0:
			continue  # behind the anchor, or exactly on its screen X -- not "that way"
		if best == -1 or gap < best_gap:
			best = i
			best_gap = gap
	return best
