extends TestCase

## Story 3-0c, PRIMARY ACCEPTANCE (AC 10, `3-0c/R6`): a driven run is recorded and replayed FROM
## THE RECORD ALONE to a BIT-IDENTICAL CanonicalHash.
##
## ITS OWN FIXTURE, and that is load-bearing. The golden determinism sequence
## (test_determinism.gd) gains NEITHER the mid-run apply_balance() nor the pushed contact facts
## this fixture drives, so this story's Golden Prediction of NONE stays structural rather than
## hopeful. Nothing here touches that file.
##
## WHY THIS ONE TEST MAKES ACs 1-9 FALSIFIABLE TOGETHER: dropping any single channel from the
## record makes the replay diverge, which is proven per channel below. The two ACs it replaces
## (run the golden sequence with and without a recorder; assert no captured channel moves the
## hash) were unfalsifiable by construction — both pass with capture() bodied as `pass`.
##
## Also carries AC 4 (balance comes from the record, never from disk), AC 8 (the camera-basis
## channel, driven NON-IDENTITY so the test is not the passive-tap tautology an identity basis
## would be) and AC 11 (replay equality is hash-only, and the unhashed cross-tick set is pinned
## to exactly three members).

const SEED := 4242

## The sequence. Every channel is driven: a mid-run reload (AC 4), a non-identity camera basis
## (AC 8), pushed contact facts (AC 9), an intent-carried debug reset, a melee swing that lands,
## and a card cast — so a dropped channel has somewhere to show.
const TICKS := 24
const RESET_TICK := 3        # intent-carried debug reset: re-lays and re-shuffles both piles
const ATTACK_TICK := 5       # windup 5-7, active 8-11 at this fixture's authored windows
const CONTACT_TICK := 9      # a fact inside that active window -> a CONFIRMED hit
const RELOAD_TICK := 14      # mid-run apply_balance: reload event #1
const CAST_TICK := 20
const CAST_SLOT := 1
## Story 6-2 (AC 16): a Mode ④ STAGE on P1, two ticks after the cast, so the pitch-cost channel's drop
## below has something to diverge ON. The countdown outlasts the run, so the staged record -- id, slot,
## the orb price copied off the INJECTED cost -- is still in the hashed zone on the final tick.
const STAGE_TICK := 22
const STAGE_SLOT := 0
const PITCH_MANA_COST := 3.0
const PITCH_TIMER_TICKS := 30

## The composition, built IN-TEST with OPAQUE ids — data/cards/ is unreachable from the state
## harness and these ids are nothing the card library contains, so card content can never reach
## this fixture (the _golden_deck discipline).
const DECK_IDS: Array[StringName] = [
	&"replay_card_0", &"replay_card_1", &"replay_card_2",
	&"replay_card_3", &"replay_card_4", &"replay_card_5",
]
const HAND_SIZE := 3
const CAST_MANA_COST := 5.0
const MELEE_HIT_MANA := 12.0
## Coverage, not feel, and deliberately DISTINCT from the authored data/balance/*.tres value
## (5.0) — AC 4's proof is that a replay lands on the RECORDED number rather than the on-disk one,
## which is unprovable if the two coincide.
const MOVE_SPEED := 7.0
## The mid-run reload's ONE moved value. move_speed lands directly in HeroState.move_speed, which
## IS a snapshot key, so the reload event is visible in the hash by itself.
const RETUNED_MOVE_SPEED := 11.0

## Movement pairs [p1, p2], cycled (tick t uses MOVES[(t - 1) % 4]). The final tick's P1 pair is
## NON-ZERO on purpose: velocity is a per-tick transient, so the camera basis is only visible in
## the hashed final snapshot if the last tick actually steers.
const MOVES := [
	[Vector2(1, 0), Vector2(-1, 0)],
	[Vector2(0, 1), Vector2(1, 1)],
	[Vector2(-1, 1), Vector2(0, -1)],
	[Vector2(0.5, -0.5), Vector2(1, 0)],
]

## AC 8: a 90-degree yaw pushed on SLOT 0 every tick; slot 1 stays identity, so the same fixture
## covers both the rotated and the short-circuit path. Under this basis _camera_relative_dir maps
## intent (x, y) to world (y, 0, -x) instead of the identity (x, 0, y) — a different world
## direction for every non-zero intent in MOVES, which is what makes the dropped-channel half of
## AC 8 a real divergence rather than a tautology.
const CAMERA_YAW_DEGREES := 90.0

## Story 4-6 (AC 2): the LOCK DIRECTIONS this fixture pushes, one per slot, every tick. Driven
## NON-ZERO on BOTH slots and on DIFFERENT headings -- an all-zero push would be the passive-tap
## tautology the camera basis avoids by driving non-identity, since a zero direction leaves facing
## untouched and a dropped channel would leave the same untouched facing behind. Chosen off the
## axes and distinct from every MOVES entry, so a facing write that regressed to the movement
## source lands on a different value rather than coinciding with these.
const LOCK_DIRS: Array[Vector2] = [Vector2(0.6, 0.8), Vector2(-0.8, 0.6)]

## AC 11: THE UNHASHED CROSS-TICK EXCLUSION SET — exactly three members, each with the argument
## that makes hash-only replay equality an HONEST claim. A FOURTH appearing later fails
## test_unhashed_cross_tick_state_is_exactly_three_members below.
##
##  (a) PlayerState.vulnerable_window — unhashed because NOTHING READS IT (`3-5b/R19`), with the
##      read decision handed to 3-6 by `3-5b/R20`. The first story that gives the window a
##      mechanical cost must bring it into the snapshot in the same pass.
##  (b) the card containers' CONTENTS and ORDER — the snapshot carries SIZES only, sound because
##      order "stays derivable from seed plus injected composition" (player_state.gd:84-87), which
##      is a REPLAY argument and holds only because ACs 1, 3 and 5 make it true across a replay.
##  (c) MatchState's PUSHED PER-TICK SPATIAL FACTS — `_camera_bases`, and from story 4-6
##      `_lock_directions` — captured by their own channels rather than hashed.
##
##      STORY 4-6 ADDS AN ARRAY TO ARGUMENT (c), NOT A FOURTH ARGUMENT, and the distinction is the
##      one this pin has always counted by: MEMBERS here means ARGUMENTS, which is why (b)'s three
##      containers have always counted as one. `_lock_directions` is `_camera_bases`' twin in every
##      respect the argument turns on -- pushed by the runner every tick through the same seam
##      family (`4-6/R6`), never produced by the tick, and captured by `capture_set_lock_direction`
##      exactly as the basis is by `capture_set_camera_basis`. Its own drop test below is what
##      makes that claim falsifiable rather than asserted (the 4-4 discipline: two new board
##      members, both HASHED, count stays at THREE).
const UNHASHED_CROSS_TICK: Array[String] = [
	"player_state.vulnerable_window",
	"deck._cards", "hand._cards", "discard_pile._cards",
	"match_state._camera_bases", "match_state._lock_directions",
	# Story 5-2 (AC 17, `5-2/R6`): TWO MORE ARRAYS ON ARGUMENT (c), NOT A FOURTH ARGUMENT -- the
	# 4-6 `_lock_directions` precedent applied unchanged. Both hold the runner's per-tick
	# CHARGE-REACH fact (the inside/outside answer, and the planar direction that answer was
	# measured along); neither is ever produced by the tick, and both are captured by
	# `capture_push_contact` -- the fact enters through `push_contact`, the sole intake, and a
	# replay restores them by replaying those pushes exactly as it restores a lock direction.
	# MEMBERS therefore STAYS AT THREE.
	"match_state._charge_reach", "match_state._charge_reach_dirs",
	# Story 6-1d review fix (`6-1d/R8`): A THIRD ARRAY ON ARGUMENT (c), still NOT A FOURTH ARGUMENT --
	# the 5-2 pair's precedent applied unchanged. `_charge_contact_dirs` holds the direction carried by
	# the push that latched `INSIDE`: a copy of a pushed fact, never produced by the tick, captured by
	# `capture_push_contact` and restored on replay by replaying those pushes. MEMBERS STAYS AT THREE.
	"match_state._charge_contact_dirs",
	# Story 6-2 review fix (H1): a FOURTH argument, not a member of any of the first three. Card
	# identity is PUBLIC by GDD design (AC 14b) and hashes; the staged card's ORB PRICE is card
	# `.tres` CONTENT, and `3-2`'s close-out ruled card content permanently out of the hashed run so
	# that repricing a card can never re-baseline the golden. `_orb_costs` genuinely CROSSES TICKS
	# (frozen from staging until `clear()`, read by `is_ready()` on every tick in between) so it
	# cannot be PER_TICK, and it is never injected so it cannot be INJECTED -- UNHASHED_CROSS_TICK is
	# its only honest home. UNHASHED_CROSS_TICK_MEMBERS THEREFORE MOVES FROM THREE TO FOUR below --
	# the first increase since this pin existed, disclosed here rather than slipped in quietly,
	# because the pin's own point is that a new argument is a real cost to notice.
	"pitch_state._orb_costs",
]
const UNHASHED_CROSS_TICK_MEMBERS := 4

## Reaches CanonicalHash through the to_snapshot() chain (MatchState -> PlayerState/PitchState ->
## HeroState/pools/TimingWindow). The card containers are here because their SIZES are hashed;
## their contents are exclusion (b) above, one level down in the container classes themselves.
const HASHED: Array[String] = [
	"match_state.p1", "match_state.p2", "match_state.pitch", "match_state._rng",
	"match_state._tick", "match_state._round_over",
	"player_state.hero", "player_state.stamina", "player_state.mana", "player_state.orbs",
	"player_state.deck", "player_state.hand", "player_state.discard",
	"player_state.pending_draw", "player_state.pending_draw_owed",
	# Story 4-6 (AC 2/AC 3): the LOCK-ON TARGET's two halves classify HASHED, for `4-3a/R17`'s test
	# rather than a weaker one -- they CROSS TICKS (the lock changes only on a click, a flick or the
	# target's death) and DECIDE AN OUTCOME (where the hero faces, hence the `_is_facing` block
	# arc). They reach the hash through `PlayerState.to_snapshot()`'s ONE `lock_target` key, so no
	# exemption is needed and UNHASHED_CROSS_TICK_MEMBERS STAYS AT THREE.
	#
	# THE DIRECTION IS THE OTHER HALF AND IS CLASSIFIED ELSEWHERE, deliberately: the ADDRESS is
	# state and is hashed here; the world-space DIRECTION to it is a pushed runner fact and sits in
	# exclusion (c) with the camera bases.
	"player_state.lock_target_slot", "player_state.lock_target_index",
	# Story 5-2 (AC 21, `5-2/R9`): the mode (2) chargeup's two halves classify HASHED, on
	# `lock_target`'s exact test rather than a weaker one -- they CROSS TICKS (the window counts
	# down over the whole chargeup) and DECIDE AN OUTCOME (when the landing check runs, hence
	# whether the hit lands at all). Both reach the hash through `PlayerState.to_snapshot()`'s ONE
	# `telegraph` key, so no exemption is needed and UNHASHED_CROSS_TICK_MEMBERS STAYS AT THREE.
	"player_state.charge_window", "player_state.charge_color",
	# Story 5-5 (AC 2/AC 16): the mode ③ defense window's two halves classify HASHED, on the
	# `charge_window`/`charge_color` line directly above's exact test rather than a weaker one -- they
	# CROSS TICKS (the window counts down from the cast until it expires or is consumed) and DECIDE
	# AN OUTCOME (whether an incoming unblockable lands at all). A replay whose defenders carried a
	# different window or a different colour would diverge the moment one chargeup landed.
	#
	# Both reach the hash through `PlayerState.to_snapshot()`'s ONE `defense` key, so no exemption is
	# needed and UNHASHED_CROSS_TICK_MEMBERS STAYS AT THREE. Leaving them UNCLASSIFIED is not a
	# neutral option: `_declared_members`'s regex scans every `^var` in `player_state.gd`, so two new
	# fields in neither bucket fail the zero-`unclassified` assertion outright.
	"player_state.defense_window", "player_state.defense_color",
	# Story 6-1c (AC 2/AC 4): the mode (2) LANDING WINDOW classifies HASHED, on the `charge_window` line's
	# exact test -- it CROSSES TICKS (cast to landing) and DECIDES AN OUTCOME (when the attack commits
	# and on which tick it lands). It reaches the hash through `PlayerState.to_snapshot()`'s ONE new
	# `landing` key, so no exemption is needed and UNHASHED_CROSS_TICK_MEMBERS STAYS AT THREE.
	"player_state.landing_window",
	# Story 4-1 (AC 4 / AC 9): the board, and it classifies HASHED rather than as a fourth
	# unhashed cross-tick exclusion — unlike its three container siblings above, whose CONTENTS
	# are excluded, a UnitBoard has no contents to exclude. It holds a count, the count IS the
	# snapshot key (`unit_count`), so all of it reaches the hash and none of it needs an
	# exemption. UNHASHED_CROSS_TICK_MEMBERS stays at THREE.
	# Story 4-2 (AC 9 / AC 11): the bare `_count` is GONE — UnitBoard is now an ordered collection,
	# and its two index-aligned arrays classify HASHED for the identical reason the count did. The
	# board's LENGTH is `unit_count` and its CONTENT is `unit_targets` (both snapshot keys), so all of
	# it reaches the hash and none of it needs an exemption. UNHASHED_CROSS_TICK_MEMBERS stays at
	# THREE, which is what makes AC 10's replay-parity claim honest for the new cross-tick state:
	# there is no fourth unhashed member to argue about.
	# Story 4-3a (AC 1 / AC 9, `4-3a/R17`): `_hp` classifies HASHED with its two index-aligned
	# siblings, and for a STRONGER version of their reason rather than a weaker one. A value that
	# CROSSES TICKS and DECIDES AN OUTCOME (whether the next swing kills) cannot sit outside the
	# hash: a replay whose units carried different hp would diverge the moment one of them died.
	# It reaches the hash through `PlayerState.to_snapshot()`'s `unit_hp` key, so no exemption is
	# needed and UNHASHED_CROSS_TICK_MEMBERS stays at THREE. This is also the HOLE representation
	# (AC 7) — a dead unit is a 0.0 at a stable index — so the hole is hashed too, by construction.
	# Story 4-3b (AC 16, `4-3b/R14` as amended): the five attack-rhythm arrays and the unit dedupe
	# records classify HASHED, for the SAME reason `_hp` did and not a weaker one. Every one of them
	# CROSSES TICKS AND DECIDES AN OUTCOME — the phase and countdown decide when the hitbox opens,
	# the locked direction decides where the swing points, the counter keys the dedupe records, the
	# in-reach flag is the cross-tick carrier between a probe and the windup it permits, and the
	# records decide whether a second fact lands. A replay whose units carried a different phase or
	# a different hit list would diverge the moment one of them swung.
	#
	# ALL SIX REACH THE HASH through `PlayerState.to_snapshot()`'s six new keys, so no exemption is
	# needed and UNHASHED_CROSS_TICK_MEMBERS STAYS AT THREE — which is what keeps AC 10's
	# replay-parity claim honest for this story's new cross-tick state: there is no fourth unhashed
	# member to argue about.
	#
	# `unit_swing_dedupe` IS THE UNIT TWIN OF `hero_state._swing_dedupe` BELOW, which has classified
	# HASHED since 1-5 for the identical reason ("mid-swing dedupe state excluded from the snapshot
	# would be a determinism/replay hole"). Two attacker kinds, one classification.
	"player_state.units", "unit_board._target_slots", "unit_board._target_indices",
	"unit_board._hp",
	"unit_board._attack_phase", "unit_board._attack_ticks", "unit_board._attack_dir",
	# Story 4-4 (`4-4/R14`): `_in_reach` became `_in_reach_ticks`, a COUNTDOWN of how long a reach
	# confirmation stays current, and it classifies HASHED for a STRONGER version of the bool's own
	# reason. `4-3a/R17`: a value that crosses ticks and decides an outcome cannot sit outside the
	# hash -- and how much freshness is LEFT is exactly what decides whether the next windup may
	# begin. Snapshotting only its predicate was measured and REFUSED by the operator: it would have
	# spared the golden and made this a FOURTH exclusion, so the golden was re-baselined instead
	# (`d94337cd` -> `a96b123e`, one cause) and UNHASHED_CROSS_TICK_MEMBERS STAYS AT THREE. It
	# reaches the hash through the same `unit_in_reach` key, now an int per unit.
	"unit_board._attack_count", "unit_board._in_reach_ticks",
	# Story 4-4 (AC 1/AC 10): the two new board members, BOTH HASHED, so
	# UNHASHED_CROSS_TICK_MEMBERS STAYS AT THREE and there is still no fourth exclusion to argue
	# about. `_kind_index` decides every authored number that governs a unit for its whole life and
	# cannot be recomputed from anything else on the record — the cast that chose it is gone.
	# `_attack_cooldown` is the cross-tick carrier between one shot and the next, the
	# `_in_reach` classification applied to a second countdown. They reach the hash through
	# `PlayerState.to_snapshot()`'s `unit_kind` and `unit_attack_cooldown` keys.
	"unit_board._kind_index", "unit_board._attack_cooldown",
	# Story 4-4 (AC 14-19): the PROJECTILE BOARD and all eight of its members, ALL HASHED — so
	# UNHASHED_CROSS_TICK_MEMBERS still stays at THREE and this story adds no fourth exclusion to
	# argue about either. Each passes `4-3a/R17`'s test on its own: the target decides where homing
	# steers, the kind decides every authored number governing the shot for its whole life (and is
	# what lets it outlive the totem that fired it), the source index is the launch position's only
	# route out of state, liveness IS the projectile's dedupe, the homing flag records whether
	# AC 16's i-frame drop has already fired, the clock decides the current speed, and the odometer
	# decides the 60 m end.
	"player_state.projectiles",
	"projectile_board._target_slots", "projectile_board._target_indices",
	"projectile_board._kind_index", "projectile_board._source_index",
	"projectile_board._alive", "projectile_board._homing",
	"projectile_board._flight_ticks", "projectile_board._travelled",
	"player_state.unit_dedupe", "unit_swing_dedupe._records",
	"hero_state.action_state", "hero_state.chain_index", "hero_state.attack_index",
	"hero_state.velocity", "hero_state.facing", "hero_state.roll_direction",
	"hero_state.move_speed", "hero_state.windup", "hero_state.active", "hero_state.recovery",
	"hero_state.chain", "hero_state.deflect", "hero_state.roll_iframe",
	"hero_state.roll_duration", "hero_state.stun", "hero_state._hp", "hero_state._max_hp",
	"hero_state._swing_dedupe",
	# Story 6-7 (AC 5, Fact M6 Direction B): the R6 gait-lockout latch classifies HASHED, on the
	# `lock_target_slot`/`charge_window` precedent's exact test -- it CROSSES TICKS (persists until
	# stamina crosses the resume threshold) and DECIDES AN OUTCOME (whether RUN may resume). Rides
	# the existing `"hero_state"` key through `player_state.hero`, so no exemption is needed and
	# UNHASHED_CROSS_TICK_MEMBERS stays at 4.
	"hero_state.run_locked_out",
	# Story 6-6a (AC 8): the GET-UP IFRAME window classifies HASHED, on `roll_iframe`'s exact test -- it
	# CROSSES TICKS (armed at the knockdown's timer exit, runs its authored span) and DECIDES AN OUTCOME
	# (whether a hit, or an unblockable, lands at all). It reaches the hash through `HeroState.to_snapshot()`'s
	# ONE new `get_up_iframe` key, so no exemption is needed and UNHASHED_CROSS_TICK_MEMBERS stays at 4.
	"hero_state.get_up_iframe",
	# Story 6-2 (AC 14b/AC 14c), narrowed by the review fix (H1): the Pitch Zone's card-identity and
	# hand-slot records classify HASHED beside the fizzle window they share an object with -- they
	# CROSS TICKS (staging to fizzle) and DECIDE AN OUTCOME (which card fizzles, into which slot the
	# replacement is owed). Card identity in the hash is RULED safe here: the staged card is PUBLIC by
	# GDD design. Both ride the existing `"pitch"` key, so no exemption is needed for them (AC 14c).
	# `_orb_costs` does NOT classify here any more -- it is card `.tres` CONTENT (H1), and moved to
	# UNHASHED_CROSS_TICK below.
	"pitch_state._card_ids", "pitch_state._hand_slots",
	"pitch_state._fizzle",
	"mana_pool._current", "mana_pool._maximum",
	"orb_pool._red", "orb_pool._blue", "orb_pool._green",
	"stamina_pool._current", "stamina_pool._maximum", "stamina_pool._regen_delay",
	"timing_window._duration_ticks", "timing_window._elapsed_ticks", "timing_window.is_running",
]

## PER-TICK: emptied before the next tick can observe it, so it is never cross-tick state at all.
## The D5 SIGNAL BUFFERS belong here and the classification is deliberate: `_queue` / `_pending`
## hold already-decided emissions that no gameplay path reads, and the runner drains them after
## every advance() exactly as advance() itself drains `_contact_queue` at step 4. Both are queues
## emptied every tick; one inside advance, one immediately after.
const PER_TICK: Array[String] = [
	"match_state._queue", "match_state._contact_queue", "match_state._deck_deal_pending",
	# Story 5-6 (AC 7): the dodge rung's OBSERVATION POINT, and it classifies PER_TICK on
	# `hero_state._deflect_closed_this_tick`'s exact test rather than a weaker one. It is written at
	# the top of step 3 on every tick that reaches step 3 and read only later within that same step,
	# so no tick can observe a previous tick's value — write-before-read within every advance(),
	# which is precisely what keeps it out of `to_snapshot()` with no determinism or replay hole
	# (a replay recomputes it identically inside each tick before any consumer runs).
	#
	# IT IS THEREFORE NOT A FOURTH UNHASHED CROSS-TICK EXCLUSION: it is not cross-tick state at all.
	# UNHASHED_CROSS_TICK_MEMBERS STAYS AT THREE.
	"match_state._iframe_open_at_step3",
	# Story 6-6a (AC 6, R-PRESS): THE DEFERRED LANDING PACKAGE classifies PER_TICK on
	# `_iframe_open_at_step3`'s exact test -- written only at step 3 (the landing) and consumed-and-cleared
	# at step 6b of the SAME advance(), with no return between the two, so no tick can observe a previous
	# tick's value. Not cross-tick state at all: UNHASHED_CROSS_TICK_MEMBERS stays at 4.
	"match_state._landing_package_pending",
	"hero_state._queue", "hero_state._deflect_closed_this_tick",
	"hero_state._roll_iframe_closed_this_tick",
	# Story 6-6a (AC 8): the get-up iframes' one-tick close grace, `_roll_iframe_closed_this_tick`'s twin.
	"hero_state._get_up_iframe_closed_this_tick",
	"mana_pool._queue", "orb_pool._queue", "stamina_pool._queue",
	# Story 3-6 (AC 2): the FIFTH `_queue` reference, and it classifies exactly like its four
	# siblings above — a shared reference to the ONE SignalQueue the runner drains after every
	# advance(), holding already-decided emissions no gameplay path reads. PlayerState gained it
	# because it gained a signal of its own (cards_changed); the classification argument is the
	# unchanged one, not a new exemption.
	"player_state._queue",
	"signal_queue._pending",
]

## INJECTED config / content: never produced by the tick, never changes except through a seam
## that IS a capture channel (AC 4 balance, AC 7 flags, AC 5/6 composition and costs).
## balance_ticks is derived from balance by BalanceTicks.from_config, so restoring one restores it.
const INJECTED: Array[String] = [
	"match_state.balance", "match_state.balance_ticks", "match_state.flags",
	# Story 4-1 (AC 2 / AC 10): the injected EFFECT map, classified INJECTED for exactly the
	# reasons its two neighbours are -- never produced by the tick, never changed except through
	# `inject_card_effects`, which IS a capture channel (`capture_inject_card_effects`).
	# Story 5-2 (AC 4, `5-2/R1`): the injected COLOUR map, classified INJECTED for its two
	# neighbours' reasons verbatim -- never produced by the tick, never changed except through
	# `inject_card_colors`, which IS a capture channel (`capture_inject_card_colors`).
	"match_state._deck_contents", "match_state._card_costs", "match_state._card_effects",
	"match_state._card_colors",
	# Story 6-2 (AC 14b/AC 16): the injected PITCH-COST map, classified INJECTED for its four neighbours'
	# reasons verbatim -- never produced by the tick, changed only through `inject_pitch_costs`, which IS
	# a capture channel (`capture_inject_pitch_costs`). UNHASHED_CROSS_TICK_MEMBERS STAYS AT THREE.
	"match_state._pitch_costs",
	# Story 5-4 (AC 8/AC 10/AC 12): the ORB POOL's per-colour MAXIMUM, and it lands in THIS bucket
	# rather than beside `mana_pool._maximum` in HASHED -- the one asymmetry between the two pools,
	# named here because this file is where it becomes checkable.
	#
	# `mana_pool._maximum` is HASHED because `ManaPool.to_snapshot()` carries it: mana's bound is
	# itself reloadable content a replay must reproduce identically. `OrbPool.to_snapshot()`
	# deliberately does NOT carry this one (5-4's AC 12, a NEGATIVE AC with its own non-vacuity
	# proof), so it cannot be HASHED -- and it is not a FOURTH unhashed cross-tick exclusion either,
	# because it is not cross-tick STATE at all. It is authored config: never produced by the tick,
	# and changed only through `OrbPool.set_maximum`, reached ONLY from
	# `MatchState._apply_balance_to_player`, i.e. through `apply_balance` -- which IS a capture
	# channel (`capture_apply_balance`, AC 4). Restoring the recorded BalanceConfig restores this
	# exactly as it restores `balance_ticks`. UNHASHED_CROSS_TICK_MEMBERS therefore STAYS AT THREE.
	"orb_pool._max",
]

## Files under src/state/ that carry no runtime match state, with the reason each is exempt from
## the classification above. A NEW file under src/state/ that is in neither list fails the scan.
const NOT_RUNTIME_STATE: Array[String] = [
	"enums",              # enum declarations only
	"match_params",       # construction params, consumed into the RNG and not retained
	"balance_ticks",      # derived from the injected BalanceConfig (A1)
	# Story 4-4 (AC 11): the two PER-KIND halves of `balance_ticks`, exempt for its reason verbatim
	# — both are built inside `BalanceTicks.from_config()` and hold nothing but tick counts derived
	# from the injected `BalanceConfig`. They are rebuilt WHOLE on every `apply_balance()`, so
	# restoring the config restores them exactly as it already restores `balance_ticks`, and no
	# member of either crosses a tick as match state. What crosses a tick is the COUNTDOWN a window
	# was started with, which lives on `UnitBoard` and is classified HASHED above.
	"unit_attack_ticks", "unit_kind_ticks",
	"input_intent",       # INPUT, snapshot-exempt by contract and captured by the X5 stream
	"cast_evaluator", "economy_evaluator",   # stateless evaluators
	"card_effect_resolver",                  # ditto (story 4-1) — fully static, retains nothing
	# Story 4-2 (AC 2): ditto again — fully static, retains nothing between calls. Its ONE static
	# member is the directory-scanned rule set, which is CONTENT loaded once with no reload path (the
	# EconomyEvaluator._authored classification verbatim), not runtime match state. It also would not
	# be seen by the member scan either way: `_declared_members` matches `^var`, and a `static var`
	# does not start there.
	"targeting_service",
]


# ---------------------------------------------------------------- AC 10, the primary

## AC 10: the whole story in one assertion. A run driven through EVERY channel, recorded, then a
## SECOND independent MatchState driven ONLY by the record — a ReplayController per slot for the
## intents, and the recorded seed, content, reload events, camera bases and contact facts for
## everything else — must reach a BIT-IDENTICAL CanonicalHash.
func test_a_driven_run_replays_from_the_record_alone_to_a_bit_identical_hash() -> void:
	var recorded := _record_a_driven_run()
	var live: MatchState = recorded["state"]
	var record: IntentRecorder = recorded["record"]
	assert_eq(record.tick_count(), TICKS, "the record carries every tick that ran")
	var replayed := _replay(record)
	assert_eq(CanonicalHash.of(replayed.to_snapshot()), CanonicalHash.of(live.to_snapshot()),
		"a replay driven from the record ALONE is bit-identical to the run that produced it")


## AC 10, the half that makes it mean anything: the fixture must actually EXERCISE every channel,
## or a bit-identical replay would be proving something about an empty stream. Each claim is
## pinned on the recorded run's own final state.
func test_the_recorded_run_exercises_every_channel() -> void:
	var recorded := _record_a_driven_run()
	var live: MatchState = recorded["state"]
	var record: IntentRecorder = recorded["record"]
	assert_eq(record.reload_event_count(), 2,
		"reload event #0 (match start, AC 4) plus the ONE mid-run apply_balance")
	assert_eq(record.reload_event_tick(0), 0, "event #0 lands at tick 0 — before the first tick")
	assert_eq(record.reload_event_tick(1), RELOAD_TICK - 1,
		"the mid-run event is keyed to the tick it was applied before")
	assert_eq(live.p1.hero.move_speed, RETUNED_MOVE_SPEED,
		"the mid-run reload REACHED state: move_speed is the retuned value, and it is hashed")
	assert_eq(record.contacts_at(CONTACT_TICK).size(), 1, "the contact channel carries the fact")
	assert_true(live.p2.hero.get_hp() < live.p2.hero.get_max_hp(),
		"the fact was CONFIRMED: P2 took damage, so the contact channel is load-bearing here")
	assert_true(live.p1.mana.get_current() > 0.0,
		"the flags channel is load-bearing: melee mana was generated, which the flag gates")
	assert_eq(live.p1.discard.size(), 1,
		"the cast LANDED, so the cost-map channel is load-bearing (an unpriced card is refused)")
	assert_true(live.pitch.is_staged(0),
		"the t22 STAGE landed and is still waiting, so the pitch-cost channel is load-bearing (story 6-2)")
	assert_eq(live.to_snapshot()["pitch"]["p1"]["card_id"], String(live.pitch.staged_card_id(0)),
		"...carrying the staged card's IDENTITY into the hash -- public by GDD design (AC 14b)")
	assert_false(live.to_snapshot()["pitch"]["p1"].has("orb_costs"),
		"...and NOT the price: card `.tres` content stays out of the hashed run (3-2), so an "
		+ "orb-price retune can never re-baseline the golden")
	assert_eq(record.camera_pushes_at(TICKS).size(), 2,
		"both slots' bases ride the record on every tick")
	assert_eq(record.intents_at(CAST_TICK)[0].card_slot, CAST_SLOT,
		"the intent stream carries the cast's card fields, not just movement")
	# Story 4-2 (AC 10): the new CROSS-TICK STATE is exercised by this fixture, asserted rather than
	# assumed. The t20 cast summons a unit, and `_config()` authors no retarget cadence, so the
	# derived interval clamps to 1 (`4-2/R5`(d)) and every tick is a boundary — the unit therefore
	# acquires the opposing hero on t20 itself and holds it to the hashed t24. Without this line the
	# story's replay-parity claim would rest on the new state happening to be covered.
	assert_eq(live.p1.to_snapshot()["unit_targets"], [[1, TargetingService.HERO_INDEX]],
		"the recorded run's summoned unit ACQUIRED a target, so the throttled-tick state this story "
		+ "adds is inside the replayed hash rather than sitting at an all-no-target no-op")


## AC 10: DROPPING ANY ONE CHANNEL MAKES THE REPLAY DIVERGE. This is what makes ACs 1-9
## falsifiable together — a channel that could be removed without moving the hash would be a
## channel the record does not need.
func test_dropping_any_single_channel_diverges_the_replay() -> void:
	var recorded := _record_a_driven_run()
	var live_hash := CanonicalHash.of((recorded["state"] as MatchState).to_snapshot())
	var record: IntentRecorder = recorded["record"]
	assert_eq(CanonicalHash.of(_replay(record).to_snapshot()), live_hash,
		"sanity: the undropped replay matches, so every divergence below is the DROP")
	# Story 4-1 (AC 10) adds "effects" -- the third content channel joins the falling proof on the
	# same footing as "costs". It diverges because the fixture's t20 cast carries a `summon_`
	# effect id and the minion flag is on, so a replay without the channel resolves that cast to
	# the missing-entry default and ends the run with unit_count 0 against the live run's 1.
	# Story 6-2 (AC 16) adds "pitch_costs" -- the fifth content channel. It diverges ONLY because the
	# driven run STAGES a card at STAGE_TICK (stated, not assumed): without the channel that stage refuses
	# with `no_pitch_cost`, so the replay ends with P1's zone empty and P1's mana unspent against the live
	# run's staged card. A run that never staged would leave this drop invisible.
	for channel in ["seed", "balance", "flags", "deck", "costs", "effects", "pitch_costs", "reload",
			"bases", "contacts", "intents"]:
		assert_ne(CanonicalHash.of(_replay(record, channel).to_snapshot()), live_hash,
			"dropping the %s channel must DIVERGE the replay" % channel)


# ---------------------------------------------------------------- AC 4

## AC 4: on replay, balance values come from the RECORD and BalanceConfigService is never read.
## Proven against the AUTHORED .tres, whose values are asserted to DIFFER from the recorded ones —
## so a replay that silently fell back to disk would land on different numbers, and the third
## measurement shows it would indeed diverge.
func test_replay_takes_balance_from_the_record_not_from_the_authored_tres() -> void:
	var authored: BalanceConfig = load("res://data/balance/balance_config.tres")
	assert_not_null(authored, "sanity: the authored balance .tres is loadable from here")
	assert_ne(authored.move_speed, MOVE_SPEED,
		"the fixture's recorded move_speed DIFFERS from the on-disk value — without that this "
		+ "test could not tell a record-driven replay from a disk-driven one")
	var recorded := _record_a_driven_run()
	var live_hash := CanonicalHash.of((recorded["state"] as MatchState).to_snapshot())
	var record: IntentRecorder = recorded["record"]
	assert_eq(record.replay_balance_config(0).move_speed, MOVE_SPEED,
		"the record replays the value that was APPLIED, not the one on disk")
	assert_eq(CanonicalHash.of(_replay(record).to_snapshot()), live_hash,
		"...and the replay reproduces the recorded run on those values")
	# The falsifying half: a replay that used the on-disk config instead would NOT reproduce it.
	assert_ne(CanonicalHash.of(_replay(record, "balance_from_disk").to_snapshot()), live_hash,
		"a replay that re-read the authored .tres instead of the record DIVERGES — which is "
		+ "exactly the failure a tuning pass between record and replay would cause")
	# By VALUE, not by handle: a post-capture edit to the resource cannot reach into the record.
	var mutable := _config()
	var solo := IntentRecorder.new()
	solo.capture_apply_balance(mutable)
	mutable.move_speed = 999.0
	assert_eq(solo.replay_balance_config(0).move_speed, MOVE_SPEED,
		"the reload channel captured VALUES — a later edit to the resource cannot re-tune the record")


# ---------------------------------------------------------------- AC 8

## AC 8: the camera basis is a per-tick, per-slot channel. Driven NON-IDENTITY on slot 0 — an
## identity-only test would be the passive-tap tautology, since MatchState short-circuits on
## identity and a dropped channel would leave the same identity behind.
func test_the_camera_basis_channel_is_driven_non_identity_and_is_load_bearing() -> void:
	var recorded := _record_a_driven_run()
	var live: MatchState = recorded["state"]
	var record: IntentRecorder = recorded["record"]
	var pushes := record.camera_pushes_at(TICKS)
	assert_eq(pushes.size(), 2, "both slots pushed on the hashed tick")
	assert_ne(pushes[0][1] as Basis, Basis.IDENTITY,
		"slot 0's recorded basis is NON-IDENTITY — without this the test proves nothing")
	assert_eq(pushes[1][1] as Basis, Basis.IDENTITY, "slot 1 stays identity (both paths covered)")
	var live_hash := CanonicalHash.of(live.to_snapshot())
	assert_eq(CanonicalHash.of(_replay(record).to_snapshot()), live_hash,
		"a replay that re-pushes the recorded bases reproduces the run")
	assert_ne(CanonicalHash.of(_replay(record, "bases").to_snapshot()), live_hash,
		"...and with the basis channel DROPPED the replay diverges")
	# WHERE it diverges, named rather than left to the hash: the basis reaches world_dir, which
	# reaches HeroState.velocity and facing — both snapshot keys.
	var dropped := _replay(record, "bases")
	assert_ne(dropped.p1.hero.velocity, live.p1.hero.velocity,
		"the divergence is P1's hashed velocity: an identity basis maps the same intent elsewhere")
	assert_eq(dropped.p2.hero.velocity, live.p2.hero.velocity,
		"...and slot 1 is unaffected, because its recorded basis WAS identity")


# ---------------------------------------------------------------- story 4-6, AC 2

## Story 4-6 (AC 2, `4-6/R6`): the LOCK-DIRECTION channel is the `camera_bases` test directly
## above, for the sibling channel, and it exists for the same reason: the direction is derived from
## ACTOR POSITIONS, which come from move_and_slide() and may drift between a recording and its
## replay, and it lands in the HASHED `HeroState.facing`. A replay that re-derived it live would
## diverge the first time a hero stood a hair off where it stood before.
##
## DRIVEN NON-ZERO ON BOTH SLOTS, which is what stops this being the passive-tap tautology: a zero
## direction is "no fact" and leaves facing untouched, so an all-zero fixture would pass with the
## channel dropped.
func test_the_lock_direction_channel_is_driven_non_zero_and_is_load_bearing() -> void:
	var recorded := _record_a_driven_run()
	var live: MatchState = recorded["state"]
	var record: IntentRecorder = recorded["record"]
	var pushes := record.lock_pushes_at(TICKS)
	assert_eq(pushes.size(), 2, "both slots pushed a lock direction on the hashed tick")
	assert_ne(pushes[0][1] as Vector2, Vector2.ZERO,
		"slot 0's recorded direction is NON-ZERO -- without this the test proves nothing")
	assert_ne(pushes[1][1] as Vector2, Vector2.ZERO, "...and so is slot 1's")
	assert_true(live.p1.hero.facing.is_equal_approx(LOCK_DIRS[0]),
		"the channel REACHED state: P1's hashed facing is the pushed direction")
	var live_hash := CanonicalHash.of(live.to_snapshot())
	assert_eq(CanonicalHash.of(_replay(record).to_snapshot()), live_hash,
		"a replay that re-pushes the recorded lock directions reproduces the run")
	assert_ne(CanonicalHash.of(_replay(record, "lock").to_snapshot()), live_hash,
		"...and with the lock channel DROPPED the replay diverges")
	# WHERE it diverges, named rather than left to the hash.
	var dropped := _replay(record, "lock")
	assert_ne(dropped.p1.hero.facing, live.p1.hero.facing,
		"the divergence is P1's hashed facing: with no fact pushed it never leaves its default")
	assert_ne(dropped.p2.hero.facing, live.p2.hero.facing, "...and P2's, for the same reason")


# ---------------------------------------------------------------- AC 11

## AC 11: replay equality is CanonicalHash-only, so the cross-tick state the hash does NOT cover
## has to be pinned or the equality claim is dishonest. Every declared member of every runtime
## state class under src/state/ is classified into exactly one bucket, and the unhashed cross-tick
## bucket must be exactly the three members named at the top of this file. A FOURTH fails here.
func test_unhashed_cross_tick_state_is_exactly_four_members() -> void:
	assert_eq(UNHASHED_CROSS_TICK_MEMBERS, 4,
		"the pin is FOUR arguments: the vulnerable window, the card containers' contents/order, "
		+ "MatchState's pushed per-tick spatial facts -- the camera bases (`3-0c/R8`), since story "
		+ "4-6 the lock directions, and since 5-2/6-1d the charge-reach facts, all sharing argument "
		+ "(c) rather than opening a fourth (`4-6/R6`) -- and, since the 6-2 review fix (H1), the "
		+ "staged card's orb price, which genuinely IS a fourth argument: card `.tres` content that "
		+ "`3-2` rules must never enter the hash, a reason none of the first three share")
	var classified: Dictionary = {}
	for bucket: Array in [HASHED, PER_TICK, INJECTED, UNHASHED_CROSS_TICK]:
		for key: String in bucket:
			assert_false(classified.has(key), "%s is classified twice" % key)
			classified[key] = true
	var declared: Array[String] = []
	var unclassified: Array[String] = []
	var unknown_files: Array[String] = []
	for path in _gd_files("res://src/state/"):
		var stem := path.get_file().trim_suffix(".gd")
		if path.contains("/resources/"):
			continue          # authored Resources: injected content/config, never runtime state
		if NOT_RUNTIME_STATE.has(stem):
			continue
		if not _known_runtime_state_file(stem):
			unknown_files.append(path)
			continue
		for member in _declared_members(path):
			var key := "%s.%s" % [stem, member]
			declared.append(key)
			if not classified.has(key):
				unclassified.append(key)
	assert_eq(unknown_files.size(), 0,
		"a new file under src/state/ is neither classified as runtime state nor exempt — its "
		+ "members must be placed in one of the four buckets before replay equality can stay an "
		+ "honest claim: %s" % ", ".join(unknown_files))
	assert_true(declared.size() > 40, "the scan must actually visit the state layer's members")
	assert_eq(unclassified.size(), 0,
		"unclassified state member(s) — each is either hashed, per-tick, injected, or a FOURTH "
		+ "unhashed cross-tick exclusion, and a fourth is what this pin exists to refuse: %s"
				% ", ".join(unclassified))
	# ...and every pinned key must be REAL, so a rename cannot silently empty a bucket.
	var stale: Array[String] = []
	for key: String in classified:
		if not declared.has(key):
			stale.append(key)
	assert_eq(stale.size(), 0, "classified member(s) that no longer exist: %s" % ", ".join(stale))


## AC 11 (b): the containers' order is unhashed, and the soundness argument is "derivable from
## seed plus injected composition". That is a REPLAY argument, so it is measured here rather than
## quoted: the replay's piles match the recorded run's card-for-card, in order, even though the
## hash only ever saw their sizes.
func test_container_order_is_reproduced_although_the_hash_never_saw_it() -> void:
	var recorded := _record_a_driven_run()
	var live: MatchState = recorded["state"]
	var replayed := _replay(recorded["record"])
	assert_true(live.p1.deck.size() > 1, "sanity: there is an ORDER to get wrong")
	assert_eq(replayed.p1.deck.to_array(), live.p1.deck.to_array(),
		"deck ORDER — invisible to the hash (sizes only) — is reproduced from seed + composition")
	assert_eq(replayed.p1.hand.to_array(), live.p1.hand.to_array(), "hand order likewise")
	assert_eq(replayed.p1.discard.to_array(), live.p1.discard.to_array(), "discard order likewise")
	assert_eq(replayed.p2.deck.to_array(), live.p2.deck.to_array(),
		"...and P2's, which the ONE-SEAT shuffle ordering makes a different permutation")
	assert_ne(live.p1.deck.to_array(), live.p2.deck.to_array(),
		"sanity: the two piles really are different permutations of one composition")


# ---------------------------------------------------------------- the driven run

## The fixture plays the RUNNER's role — capturing on every channel beside the call it taps,
## exactly as match_runner.gd does. Returns the recorded run's final state AND its record.
func _record_a_driven_run() -> Dictionary:
	var record := IntentRecorder.new()
	var params := MatchParams.new(SEED)
	record.capture_seed(params.seed_value)
	var ms := MatchState.new(params)
	var config := _config()
	record.capture_apply_balance(config)      # RELOAD EVENT #0 (AC 4)
	ms.apply_balance(config)
	var flags := _flags()
	record.capture_inject_feature_flags(flags)
	ms.inject_feature_flags(flags)
	record.capture_inject_deck(DECK_IDS)      # the composition, then the costs — the ORDER (AC 5)
	ms.inject_deck(DECK_IDS)
	var costs := _costs()
	record.capture_inject_card_costs(costs)
	ms.inject_card_costs(costs)
	# Story 4-1 (`4-1/R1`, `4-1/R8`): the THIRD content channel, captured and injected LAST -- the
	# order deck -> costs -> effects the live runner produces and SOUND_CONTENT_ORDER pins.
	var effects := _effects()
	record.capture_inject_card_effects(effects)
	ms.inject_card_effects(effects)
	# Story 5-2 (`5-2/R1`): the FOURTH content channel, captured and injected LAST -- the order
	# deck -> costs -> effects -> colours the live runner produces and SOUND_CONTENT_ORDER pins.
	var colors := _colors()
	record.capture_inject_card_colors(colors)
	ms.inject_card_colors(colors)
	# Story 6-2 (AC 16): the FIFTH content channel, captured and injected LAST.
	var pitch_costs := _pitch_costs()
	record.capture_inject_pitch_costs(pitch_costs)
	ms.inject_pitch_costs(pitch_costs)
	for t in range(1, TICKS + 1):
		if t == RELOAD_TICK:
			var retuned := _retuned_config()
			record.capture_apply_balance(retuned)
			ms.apply_balance(retuned)
		for push: Array in _camera_pushes():
			record.capture_set_camera_basis(int(push[0]), push[1] as Basis)
			ms.set_camera_basis(int(push[0]), push[1] as Basis)
		# Story 4-6 (AC 2): the lock channel is driven in the SAME per-tick seat the bases are, on
		# both slots, so a dropped channel has somewhere to show.
		for slot: int in 2:
			record.capture_set_lock_direction(slot, LOCK_DIRS[slot])
			ms.set_lock_direction(slot, LOCK_DIRS[slot])
		if t == CONTACT_TICK:
			record.capture_push_contact([0, -1], [1, -1], 0, Vector2(-1, 0), MatchState.CONTACT_STRIKE)
			ms.push_contact([0, -1], [1, -1], 0, Vector2(-1, 0), MatchState.CONTACT_STRIKE)
		var intents := _intents(t)
		record.capture_advance(intents)
		ms.advance(intents)
		ms.drain_signals()
	return {"state": ms, "record": record}


## The SECOND, independent MatchState — driven ONLY by the record. `drop` names one channel to
## withhold, which is how every capture AC is proven falling at once.
func _replay(record: IntentRecorder, drop := "") -> MatchState:
	var seed_value := 0 if drop == "seed" else record.replay_seed()
	var ms := MatchState.new(MatchParams.new(seed_value))
	if drop == "balance_from_disk":
		ms.apply_balance(load("res://data/balance/balance_config.tres") as BalanceConfig)
	elif drop != "balance":
		ms.apply_balance(record.replay_balance_config(0))
	if drop != "flags":
		ms.inject_feature_flags(record.replay_feature_flags())
	if drop == "costs":
		ms.inject_deck(record.replay_deck_contents())   # composition without its prices
	elif drop == "effects":
		# Story 4-1: composition and prices, but no effects -- the one channel withheld, so the
		# divergence below can only be the effects channel.
		ms.inject_deck(record.replay_deck_contents())
		ms.inject_card_costs(record.replay_card_costs())
	elif drop == "pitch_costs":
		# Story 6-2: every content channel but the pitch costs, in the sound order.
		ms.inject_deck(record.replay_deck_contents())
		ms.inject_card_costs(record.replay_card_costs())
		ms.inject_card_effects(record.replay_card_effects())
		ms.inject_card_colors(record.replay_card_colors())
	elif drop != "deck":
		assert_true(record.replay_inject_content(ms),
			"the recorded content order replays (deck, then costs, then effects)")
	var p1_controller := ReplayController.new(record, 0)
	var p2_controller := ReplayController.new(record, 1)
	for t in range(1, record.tick_count() + 1):
		if drop != "reload":
			record.replay_apply_reloads_before(ms, t)
		if drop != "bases":
			record.replay_push_camera_bases(ms, t)
		if drop != "lock":
			record.replay_push_lock_directions(ms, t)
		if drop != "contacts":
			record.replay_push_contacts(ms, t)
		var intents: Array[InputIntent] = [p1_controller.sample(), p2_controller.sample()]
		if drop == "intents":
			intents = [InputIntent.new(), InputIntent.new()]
		ms.advance(intents)
		ms.drain_signals()
	return ms


func _camera_pushes() -> Array:
	return [[0, Basis(Vector3.UP, deg_to_rad(CAMERA_YAW_DEGREES))], [1, Basis.IDENTITY]]


func _intents(t: int) -> Array[InputIntent]:
	var pair: Array = MOVES[(t - 1) % MOVES.size()]
	var i1 := InputIntent.new()
	i1.move_dir = pair[0]
	var i2 := InputIntent.new()
	i2.move_dir = pair[1]
	if t == RESET_TICK:
		i1.debug_reset = true
	if t == ATTACK_TICK:
		i1.pressed[&"attack"] = true
		i1.held[&"attack"] = true
	if t == STAGE_TICK:
		i1.card_slot = STAGE_SLOT
		i1.card_mode = Enums.ModeKind.PITCH
		i1.card_commit = true
	if t == CAST_TICK:
		i1.card_slot = CAST_SLOT
		i1.card_mode = Enums.ModeKind.BASIC
		i1.card_commit = true
	var out: Array[InputIntent] = [i1, i2]
	return out


# ---------------------------------------------------------------- fixture content

## Built IN-TEST, never loaded from data/balance/*.tres — the _golden_config discipline, and here
## it is doubly load-bearing: AC 4's proof rests on the recorded values DIFFERING from the
## authored ones.
func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = MOVE_SPEED
	# Story 6-7 (`6-7/R11`): authored EQUAL TO move_speed -- no call site here presses `&"run"`,
	# so gait is a no-op and every MOVE_SPEED-based assertion below (including the camera-basis
	# divergence proof, which needs a NON-zero velocity to diverge from) holds unchanged.
	c.walk_speed = MOVE_SPEED
	c.max_stamina = 30.0
	c.stamina_regen_per_second = 60.0
	c.stamina_regen_delay_seconds = 2.0 / 60.0
	c.roll_stamina_cost = 8.0
	c.attack_stamina_cost = 4.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 5.0 / 60.0
	c.attack_chain_window_seconds = 4.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 20.0
	c.attack_windup_move_speed_multiplier = 0.25
	c.attack_active_move_speed_multiplier = 0.5
	c.attack_recovery_move_speed_multiplier = 0.75
	c.attack_lunge_distance = 1.5
	c.max_mana = 60.0
	c.melee_hit_mana = MELEE_HIT_MANA
	c.deck_size = DECK_IDS.size()
	c.hand_size = HAND_SIZE
	c.block_damage_multiplier = 0.5
	c.deflect_window_seconds = 3.0 / 60.0
	c.deflect_stamina_cost = 10.0
	c.block_facing_arc_degrees = 180.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	c.roll_distance = 2.0
	# Story 4-4 (AC 1): the cast seat resolves a summon's KIND before appending a record, so without
	# an authored kind this fixture's recorded summon would put nothing on the board — and the
	# effects channel's divergence proof, which rests on that unit ACQUIRING a target, would go
	# vacuous. One minion kind at index 0, naming `standard` so the acquired verdict this file
	# asserts (`[1, -1]`) is exactly what the removed hardcoded lookup produced.
	c.unit_kinds = UnitKindFixture.minion_only(9.0, 3.0, 0, 0, 0, 2.0)
	c.hero_damage_to_unit = 3.0
	# Story 6-2 (AC 16): long enough that the t22 stage is still waiting on the hashed final tick.
	c.pitch_stage_timer_seconds = PITCH_TIMER_TICKS / 60.0
	return c


## The mid-run reload's config — identical except for move_speed, so reload event #1's effect on
## the hash is ONE named value rather than a wall of them.
func _retuned_config() -> BalanceConfig:
	var c := _config()
	c.move_speed = RETUNED_MOVE_SPEED
	# Story 6-7 (Fact M5(d)): retune walk_speed alongside move_speed, on the same `walk_speed ==
	# move_speed` no-op rule -- otherwise the reload would land but silently stop reaching
	# velocity (no call site here presses `&"run"`), passing the mid-run-reload assertion while
	# proving nothing about the reload it claims to test.
	c.walk_speed = RETUNED_MOVE_SPEED
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	# Story 4-1: the minion layer ON, so this fixture's recorded `summon_` cast actually appends a
	# unit record. Without it the effects channel would ride the record while changing nothing in
	# the hash, and every proof that rests on it would be VACUOUS.
	f.minions = true
	# Story 6-2: the pitch layer ON, so the t22 stage stages and the pitch-cost channel is load-bearing.
	f.pitch_zone = true
	return f


## Story 4-1 (`4-1/R1`): the effect map for this fixture's composition -- `_costs()`'s twin,
## built in-test over the same opaque ids. Every id carries a `summon_` prefix so the channel is
## exercised by a resolver that actually appends a unit record.
func _effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id in DECK_IDS:
		var e := CardEffect.new()
		e.effect_id = StringName("summon_%s" % id)
		out[id] = e
	return out


## Story 6-2 (AC 16), narrowed by the review fix (H1): every id priced for Mode ④, each with an ORB
## price. The price itself is NOT hashed (H1) -- what makes a replay whose rebuilt condition drops
## this channel diverge is that `condition == null` REFUSES the stage outright (`REASON_NO_PITCH_COST`),
## so the hashed `card_id`/`hand_slot` never land at all. The channel is load-bearing through the
## refusal, not through the price.
func _pitch_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in DECK_IDS:
		var c := CardCastCondition.new()
		c.mana_cost = PITCH_MANA_COST
		c.orb_costs[Enums.CardColor.GREEN] = 2
		out[id] = c
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in DECK_IDS:
		var c := CardCastCondition.new()
		c.mana_cost = CAST_MANA_COST
		out[id] = c
	return out


# ---------------------------------------------------------------- source scanning (AC 11)

## The runtime state carriers under src/state/, by file stem. Kept as an explicit list (rather
## than "everything not exempt") so a NEW state file cannot slip through unclassified.
func _known_runtime_state_file(stem: String) -> bool:
	# Story 4-3b: `unit_swing_dedupe` joins the list as a RUNTIME STATE file -- the unit-attacker
	# twin of `hero_state._swing_dedupe`, holding per-swing hit lists that cross ticks. It is NOT
	# exempt: its one member is classified HASHED above, reaching the snapshot through the
	# `unit_swing_dedupe` key.
	# Story 4-4: `projectile_board` joins the list as a RUNTIME STATE file — the fifth pure
	# container, holding per-shot flight state that crosses ticks. It is NOT exempt: all eight of
	# its members are classified HASHED above, reaching the snapshot through the seven
	# `projectile_*` keys.
	return ["match_state", "player_state", "hero_state", "deck", "hand", "discard_pile",
		"unit_board", "unit_swing_dedupe", "projectile_board",
		"pitch_state", "mana_pool", "orb_pool", "stamina_pool",
		"signal_queue", "timing_window"].has(stem)


func _declared_members(path: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string("^var\\s+([A-Za-z_][A-Za-z0-9_]*)")
	for line in _code_lines(path):
		var m := re.search(line)
		if m != null:
			out.append(m.get_string(1))
	return out


func _gd_files(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(root + f)
	for d in dir.get_directories():
		out.append_array(_gd_files(root + d + "/"))
	return out


# Code portion of each line (everything before the first '#'), so comments can't false-positive.
func _code_lines(path: String) -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		var hash_idx := line.find("#")
		if hash_idx >= 0:
			line = line.substr(0, hash_idx)
		out.append(line)
	return out


## Story 5-2 (AC 4, `5-2/R1`): the FOURTH content channel's fixture half. Colours are plain enum
## values, so unlike `_costs()` and `_effects()` this builds no Resource -- which is exactly why the
## channel round-trips as ints and needed no new serialisation machinery.
func _colors() -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	for i in DECK_IDS.size():
		out[DECK_IDS[i]] = Enums.CardColor.RED if i % 2 == 0 else Enums.CardColor.BLUE
	return out
