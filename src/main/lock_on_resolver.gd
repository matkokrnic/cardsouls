class_name LockOnResolver
extends RefCounted

## Story 4-6 (AC 10/AC 11, `CC/R3`/`CC/R5`): the FLICK's candidate pick, and nothing else.
## Story 4-6a (AC 1-AC 7) replaced 4-6's 120-degree cone with ADJACENT-BY-SCREEN-X cycling.
## Story 6-8 (AC 13-AC 18) REPLACES THE ALGORITHM AND KEEPS THE SEAT a second time, on 4-6a's own
## precedent: the pick is now BEARING-BASED 360-DEGREE CYCLING around the locking hero. Candidates
## are no longer filtered to what is on screen (AC 13), the anchor is the current target's BEARING
## rather than its screen X (AC 14), and the order WRAPS (AC 16, superseding 4-6a AC 2's no-wrap).
##
## WHY BEARING RATHER THAN SCREEN X: a screen coordinate only exists for what the camera can see,
## so a target behind the hero had no place in 4-6a's order at all, and neither did an off-screen
## current target (4-6a AC 5's null-anchor no-op). A bearing around the hero exists for every live
## candidate regardless of camera, which is what makes "cycle to the thing behind me" reachable
## and what makes that no-op moot.
##
## PRESENTATION-SIDE BY RULING, NOT BY CONVENIENCE. The bearing needs world positions, which may
## not enter `src/state/` (D3(b)/A2). `CC/R5` puts the resolution out here and sends only the RESULT
## inward as an address on the intent -- the runner reports, state decides what the report means.
##
## PURE AND POSITION-FREE ANYWAY. This class never touches a camera, a node or the scene tree -- the
## runner turns positions into planar offsets and hands in plain floats. That is what keeps the pick
## headlessly testable.
##
## IT IS NOT `TargetingService`. That evaluator answers "which enemy does this MINION attack" and
## is explicitly NOT reused here (the story's Non-Goals). The only thing borrowed from it is the
## `[slot, index]` ADDRESS convention, and the runner does that borrowing, not this file.


## Story 6-8 (AC 15, Open Question 5): the bearing of a WORLD-SPACE PLANAR offset `(x, z)` from the
## locking hero, in radians in [0, TAU), INCREASING TOWARD SCREEN-RIGHT of a camera looking along
## that offset.
##
## THE MAPPING, stated once: the rig looks along its local -Z, and for a lock direction `d = (x, z)`
## `CameraRig.face_lock_direction` yaws it to `atan2(-x, -z)`, whose local +X -- screen-right --
## lies along world `(-z, x)`. `atan2(x, -z)` of `d` and of `(-z, x)` differ by exactly +PI/2, so a
## sweep toward screen-right is a sweep of INCREASING bearing. Viewed from above with -Z up the page
## and +X to the right, that is clockwise: -Z (0) -> +X (PI/2) -> +Z (PI) -> -X (3PI/2). Pinned
## against the real rig basis by `test/integration/test_camera_freedom_live.gd`.
static func bearing_of(planar: Vector2) -> float:
	return fposmod(atan2(planar.x, -planar.y), TAU)


## Story 6-8 (AC 13-AC 18): returns the INDEX into `bearings` that a horizontal flick cycles to from
## `current`, or -1 for a no-op -- which the caller turns into "send no request at all".
##
## `bearings` HOLDS EVERY CANDIDATE, THE CURRENT TARGET INCLUDED, gathered in board-index order
## (opposing hero first, then units ascending); `current` is the current target's index into it.
## This is the inverse of 4-6a's contract (which excluded the current target and passed its screen
## position alongside) and it is what AC 17 needs: the current target HOLDS ITS OWN PLACE in the
## circle, ordered against a candidate at its exact bearing by the same tie-break as any other pair.
##
## THE CIRCLE: every index sorted by (bearing, index). Sorting on the index as the second key IS
## AC 17's lower-board-index tie-break, because the caller's gather order is board order. A RIGHT
## flick takes the SUCCESSOR of `current` in that order and a LEFT flick its PREDECESSOR, both
## modulo the size (AC 16's wrap). The successor of the last element is the first, so one full
## sweep in either direction visits every candidate exactly once before returning to `current`
## (G2's no-ping-pong rule, by construction rather than by a visited-set).
##
## A SUCCESSOR THAT IS `current` ITSELF -- the only live candidate is the one already locked -- is
## a no-op (-1), never a "retarget" onto the standing lock.
##
## HORIZONTAL-ONLY, DECIDED BY MAGNITUDE (AC 18, 4-6a AC 3/AC 6, unchanged): a flick is horizontal
## when `abs(x) > abs(y)`; a vertical flick and an exact 45-degree diagonal are no-ops. The threshold
## that decides whether a deflection is a flick at all stays in the controller layer
## (`GamepadProfile.flick_threshold`, AC 19).
static func cycle_candidate(flick: Vector2, bearings: Array[float], current: int) -> int:
	if flick.is_zero_approx():
		return -1
	if absf(flick.x) <= absf(flick.y):
		return -1  # vertical (or exactly diagonal) names no cycling direction -- AC 18
	if current < 0 or current >= bearings.size():
		return -1
	var order: Array[int] = []
	for i: int in bearings.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if bearings[a] != bearings[b]:
			return bearings[a] < bearings[b]
		return a < b)
	# Stick X and screen X share a sign (`controller.gd`), so +x sweeps toward screen-right, which
	# `bearing_of` makes the INCREASING direction.
	var step := 1 if flick.x > 0.0 else -1
	var pick := order[posmod(order.find(current) + step, order.size())]
	return -1 if pick == current else pick
