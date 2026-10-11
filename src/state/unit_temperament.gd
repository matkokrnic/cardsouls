class_name UnitTemperament
extends RefCounted

## Story 7-3, feel pass: a unit's TEMPERAMENT -- what makes one hound differ from its sibling for its
## whole life. A PURE FUNCTION OF THE UNIT'S ADDRESS (owner slot, board index) and a channel, by a
## fixed integer hash. Nothing is stored, nothing is drawn, nothing is hashed: the address already is
## state, so the same record has the same temperament in a live match and in its replay.
##
## TWO READERS. `MatchState` scales a unit's draw WEIGHTS by it (which option after a back-off, leap
## against bite); the runner scales its MOTION by it (move speed, circle radius, circle wobble). Both
## call `factor()` with the kind's authored spread, so the range is authored data and this file holds
## no tuning.
##
## THE HASH IS A FIBONACCI (GOLDEN-RATIO) STEP PER BOARD INDEX, on purpose. Two records one index
## apart land 0.382 or 0.618 of the range from each other on every channel, never close together --
## and the two hounds of one cast ARE one index apart. A mixing hash would make siblings alike by
## chance about one cast in five.
##
## INTEGER ARITHMETIC ONLY up to the final division, all of it below 2^63, so the answer is the same
## on every platform and build.

## One channel per trait, so a fast hound is not always also the wide-circling one.
const CHANNEL_SPEED := 0
const CHANNEL_RADIUS := 1
const CHANNEL_WOBBLE := 2
const CHANNEL_LEAP := 3
const CHANNEL_CIRCLE := 4
const CHANNEL_STALK := 5
const CHANNEL_FEINT := 6
const CHANNEL_RE_ENGAGE := 7
## Where in its wobble cycle a unit starts (a phase offset, read through `unit_value`).
const CHANNEL_WOBBLE_PHASE := 8
## Feel pass 2: the two new things a unit may do when its back-off ends, the three it may do when an
## attack ends, and (presentation only, read by the runner) the pitch of its voice.
const CHANNEL_REPOSITION := 9
const CHANNEL_RETREAT := 10
const CHANNEL_BACK_OFF := 11
const CHANNEL_PRESS := 12
const CHANNEL_RUN_ON := 13
const CHANNEL_VOICE := 14
## Feel pass 3: the long orbit's weight.
const CHANNEL_ORBIT := 15
## How many channels there are (the tests walk them all).
const CHANNEL_COUNT := 16

const _INDEX_STEP := 0x9E3779B9    # 2^32 / the golden ratio
const _SLOT_STEP := 0x7F4A7C15
const _CHANNEL_STEP := 0x632BE5AB
const _MASK := 0xFFFFFFFF
const _RANGE := 4294967296.0


## The unit's value on `channel`, in [0, 1).
static func unit_value(slot: int, index: int, channel: int) -> float:
	var mixed := ((index + 1) * _INDEX_STEP + slot * _SLOT_STEP + channel * _CHANNEL_STEP) & _MASK
	return float(mixed) / _RANGE


## The unit's multiplier on `channel` for an authored `spread`: in [1 - spread, 1 + spread). A spread
## of 0.0 is exactly 1.0 for every unit, which is every kind that authors none.
static func factor(slot: int, index: int, channel: int, spread: float) -> float:
	return 1.0 + spread * (2.0 * unit_value(slot, index, channel) - 1.0)
