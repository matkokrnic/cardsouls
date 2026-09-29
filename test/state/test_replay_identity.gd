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
	# Story 6-5e (AC 38): `hand._covers` is the ONE container member this story adds and it classifies
	# HASHED, NOT as part of exclusion (b) beside `hand._cards` one line up -- the asymmetry is the whole
	# point of the cause-1 argument. The CARD layer's contents are excluded because they are derivable from
	# seed plus injected composition plus the replayed intents; the COVER layer is not derivable that way
	# at all in the (b) sense -- it is produced by the tick, from a seeded pick at a landing -- so it is
	# hashed directly, through `PlayerState.to_snapshot()`'s `hand_covered` key. Listed HERE only as a
	# pointer to where it is classified; it is a member of `HASHED`.
	# (see HASHED: "hand._covers")
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
	# Story 6-6b (AC 9): A FOURTH ARRAY ON ARGUMENT (c), still NOT A FIFTH ARGUMENT -- the `6-1d`
	# `_charge_contact_dirs` precedent applied unchanged, one story later. `_counter_travel_dirs` holds a
	# COPY of `_charge_reach_dirs` taken at a mode-3 press: a runner-pushed spatial fact, never produced
	# by the tick, captured by `capture_push_contact` and restored on a replay by replaying those pushes
	# -- the press falls on the same tick with the same pushes behind it, so the copy is identical. It
	# decides BLUE's counter travel, which is exactly the class of consequence `_charge_contact_dirs`
	# already has (it decides the landing arc). MEMBERS STAYS AT FOUR.
	"match_state._counter_travel_dirs",
	# Story 6-5b (AC 18, `6-5b/R6`): A FIFTH ARRAY ON ARGUMENT (c), still NOT A FIFTH ARGUMENT -- the
	# `6-6b` `_counter_travel_dirs` precedent applied unchanged, and the `_lock_directions` precedent
	# it descends from. `_drain_targets` holds the runner's per-tick answer to "which own minion is
	# this hero facing most directly": chosen from actor positions and a hero facing that `src/state/`
	# may not read, never produced by the tick, and captured by its OWN channel
	# (`capture_push_drain_target`) exactly as a lock direction is by `capture_set_lock_direction`. A
	# replay restores it by replaying those pushes.
	#
	# IT IS AN INDEX WHERE ITS FOUR SIBLINGS ARE DIRECTIONS, and that does not change the argument --
	# it strengthens it. The pushed value is already the RESOLVED answer rather than the geometry the
	# answer was computed from, so even less spatial data crosses inward than for a direction. What
	# makes it belong here rather than in HASHED is the same thing that puts `_camera_bases` here: it
	# is not state the tick produces, it is a fact the tick is HANDED, and its record channel is what a
	# replay reproduces it from. MEMBERS THEREFORE STAYS AT FOUR.
	"match_state._drain_targets",
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
	# Story 6-5e (AC 38, Golden Prediction cause 1): the COVER LAYER classifies HASHED -- see the note
	# beside `hand._cards` in UNHASHED_CROSS_TICK for why it does NOT share its sibling's exclusion. It
	# CROSSES TICKS and DECIDES OUTCOMES (which slots the next stone may pick, which presses are refused,
	# what Boom detonates, how slow its holder walks) and reaches the hash through the ONE `hand_covered`
	# key. MEMBERS STAYS AT FOUR.
	"hand._covers",
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
	# Story 6-5a (AC 8): the TIMED-RULE SEAT's three index-aligned arrays classify HASHED, on
	# `defense_window`'s exact test -- every rule CROSSES TICKS (a buff's duration, an armed trigger's
	# window) and DECIDES AN OUTCOME (a damage multiplier, a heal, a roll's reach, a slow). All three
	# reach the hash through `PlayerState.to_snapshot()`'s ONE `timed_rules` key, so no exemption is
	# needed and UNHASHED_CROSS_TICK_MEMBERS stays at 4.
	"player_state.rule_windows", "player_state.rule_a", "player_state.rule_b",
	# Story 6-5a (AC 10): the LAST RESOLVED CARD's two halves classify HASHED -- they CROSS TICKS and
	# 6-5f's Counterspell decides an outcome from them. Card identity in the hash is ruled safe here on
	# the `pitch_state._card_ids` precedent (a resolved card is public), held as a String VALUE. Both
	# ride the ONE `last_resolved_card` key: UNHASHED_CROSS_TICK_MEMBERS stays at 4.
	"player_state.last_resolved_card_id", "player_state.last_resolved_card_mode",
	# Story 6-5f (AC 5, `6-5f/R31`): the RESOLUTION TICK classifies HASHED beside the two halves it was
	# added to -- it CROSSES TICKS by definition (it names a tick already past) and DECIDES AN OUTCOME
	# (whether the card is still inside `counter_window_seconds`, and how much lifetime a Raise Dead's
	# returning corpse has left). It rides the SAME `last_resolved_card` key as its third member, so no
	# exemption is needed and UNHASHED_CROSS_TICK_MEMBERS stays at 4.
	"player_state.last_resolved_card_tick",
	# Story 6-5f (AC 2/AC 28, Open Question 1): the REVERSAL RECORD's six members classify HASHED, on
	# `burst`'s exact test and for a sharper version of it -- the packet is written at ONE player's
	# resolution and read, if ever, at a LATER activation by the OTHER player, so every column CROSSES
	# TICKS and DECIDES AN OUTCOME (whether there is a target at all, which minions rise and at what hp,
	# which corpses shorten, which hand slots re-cover, how much hp and mana come back). A replay whose
	# packets differed would diverge the moment a Counterspell resolved.
	#
	# NONE OF THEM IS AN IDENTITY OR A POSITION, which is the classification a reader might expect to have
	# to argue and does not: `reversal_indices` holds board indices and hand SLOTS (the `unit_targets` /
	# `corpse_bomb` class, `4-2/R2`'s counts-and-indices rule), and Boom's Boulder ids are deliberately NOT
	# carried -- they are read back from `MatchState._boulder_card_id` at the restore. So no `StringName`
	# and no `String` reaches the hash from this packet and `SNAPSHOT_ID_PATHS` gains no member.
	#
	# All six ride `PlayerState.to_snapshot()`'s ONE `reversal` key, so no exemption is needed and
	# UNHASHED_CROSS_TICK_MEMBERS STAYS AT FOUR.
	"player_state.reversal_kind", "player_state.reversal_indices", "player_state.reversal_a",
	"player_state.reversal_b", "player_state.reversal_flags", "player_state.reversal_amount",
	# Story 6-5e (AC 11a/AC 38, `6-5e/R21`/G2): the PENDING BURST's six members classify HASHED, on
	# `charge_window`'s exact test rather than a weaker one -- they CROSS TICKS (the schedule outlives the
	# cast that armed it, by ruling 6a) and DECIDE OUTCOMES (how many stones still exist, when each
	# appears, what each may hit, for how much). All six ride `PlayerState.to_snapshot()`'s ONE `burst`
	# key, so no exemption is needed and UNHASHED_CROSS_TICK_MEMBERS STAYS AT FOUR.
	"player_state.burst_effect_id", "player_state.burst_remaining", "player_state.burst_window",
	"player_state.burst_target_slot", "player_state.burst_target_index",
	"player_state.burst_damage",
	# Story 6-5e (ruling 14, AC 38/AC 40): CORPSE BOMB's conversion record, both halves, on
	# `last_resolved_card`'s exact footing -- round-crossing state `6-5f`'s Counterspell decides an
	# outcome from, riding ONE `corpse_bomb` key. Plain ints only, so not even the id argument is needed.
	# MEMBERS STAYS AT FOUR.
	"player_state.corpse_bomb_tick", "player_state.corpse_bomb_indices",
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
	# Story 6-5b (AC 1/AC 14, `6-5b/R17`): the THREE new board members, ALL HASHED -- so
	# UNHASHED_CROSS_TICK_MEMBERS stays at 4 and this story adds no fifth exclusion to argue about.
	# Each passes `4-3a/R17`'s test on its own: `_corpse_ticks` decides whether a corpse can still be
	# extended or raised, and is the carrier between the death that made it and the Raise Dead that
	# consumes it -- events that may be a thousand ticks apart; `_corpse_extended` decides what that
	# corpse renders as for the rest of its life and CANNOT be recomputed from anything else on the
	# record (remaining-exceeds-the-authored-default is true for one tick and false ever after);
	# `_raised_from` decides where the raised minion is placed and names a death already gone.
	#
	# NONE OF THE THREE IS A POSITION, which is the classification a reader might expect to have to
	# argue here and does not: the corpse's LOCATION never enters state at all (`6-5b/R1`), so
	# `_raised_from` is a board INDEX the runner resolves against its own actors -- the `unit_targets`
	# class exactly, `4-2/R2`'s counts-and-indices rule. All three reach the hash through
	# `PlayerState.to_snapshot()`'s `unit_corpse_ticks`, `unit_corpse_extended` and `unit_raised_from`
	# keys, so no exemption is needed for any of them.
	"unit_board._corpse_ticks", "unit_board._corpse_extended", "unit_board._raised_from",
	# Story 6-5f (AC 23/AC 28, `6-5f/R32`): the PRE-DEATH HP classifies HASHED, on its three corpse
	# siblings' exact test and with the strongest case of any of them for NOT being recomputable: the death
	# seat overwrites the living hp with `0.0`, so a replay whose records carried a different pre-death hp
	# would diverge the moment a Counterspell restored one -- and there is nothing left on the record to
	# derive the right number from. It reaches the hash through `PlayerState.to_snapshot()`'s
	# `unit_hp_at_death` key, so no exemption is needed and UNHASHED_CROSS_TICK_MEMBERS STAYS AT FOUR.
	#
	# A PLAIN FLOAT PER RECORD, `_hp`'s own type and class: no position, no identity, no StringName.
	"unit_board._hp_at_death",
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
	# Story 6-5d (AC 30): the HERO-SOURCED shot's two members classify HASHED with their eight
	# index-aligned siblings, for the same `4-3a/R17` test and not a weaker one. `_effect_ids` CROSSES
	# TICKS and DECIDES AN OUTCOME (every authored number governing the flight, and whether the
	# target-only / no-block / Bloodlust-inclusive rules apply at all); `_damage` decides what the shot
	# hits for and is the one value on this board a replay cannot re-derive from config, because the
	# staging that computed it is ticks in the past. Both reach the hash through
	# `PlayerState.to_snapshot()`'s new `projectile_effect` / `projectile_damage` keys, so no exemption is
	# needed and UNHASHED_CROSS_TICK_MEMBERS STAYS AT FOUR.
	#
	# THE ID IS A `String` VALUE, never a StringName and never a key -- `player_state.cast_card_id`'s own
	# measured reason, carried to a second container.
	"projectile_board._effect_ids", "projectile_board._damage",
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
	# Story 6-5c (`6-5c/R16`): the BOLT-STUN DISCRIMINATOR classifies HASHED. It CROSSES TICKS (set by
	# the bolt's own stun write, cleared at that stun's exit) and, although its only consumer today is
	# PRESENTATION -- which clip the runner plays -- it is read ACROSS the `advance()` boundary, so
	# `vulnerable_window`'s unhashed-because-nothing-reads-it argument does not apply to it and the
	# `run_locked_out` direction is taken instead. It rides `HeroState.to_snapshot()`'s ONE new
	# `stun_is_bolt` key, so no exemption is needed and UNHASHED_CROSS_TICK_MEMBERS stays at 4.
	"hero_state.stun_is_bolt",
	# Story 6-5c (AC 1/AC 8/AC 23): THE CAST WINDOW AND THE IN-FLIGHT CAST'S IDENTITY classify HASHED
	# on `charge_window`/`defense_window`'s exact test -- both CROSS TICKS (press to strike) and DECIDE
	# AN OUTCOME (when the strike lands, and therefore whether it lands at all; and, through
	# `is_casting()`, whether every press in between is refused). The identity is a plain `String`
	# VALUE, never a `StringName` -- `last_resolved_card_id`'s measured constraint, because
	# `Array[StringName].sort()` orders by internal POINTER on this engine. Both ride
	# `PlayerState.to_snapshot()`'s ONE new fused `cast` key, so neither needs an exemption and
	# UNHASHED_CROSS_TICK_MEMBERS stays at 4.
	"player_state.cast_window", "player_state.cast_card_id",
	# Story 6-5d (AC 30): the FOUR facts a cast now CARRIES classify HASHED with the two above, on their
	# exact test. `cast_effect_mode` DECIDES AN OUTCOME in the strongest sense this pin knows -- it
	# decides WHICH EFFECT the strike resolves, so a replay that lost it would arm a roll buff where the
	# recorded match threw a Fireball (AC 12). The captured target decides where the strike lands and is
	# deliberately NOT derivable from the live `lock_target`, which may have moved or snapped back since
	# (`6-5d/R15`). The locked damage decides what it hits for and cannot be recomputed at all: the mana
	# pool it was measured against was emptied at staging.
	#
	# ALL FOUR RIDE THE ONE EXTENDED `cast` KEY, so no exemption is needed and
	# UNHASHED_CROSS_TICK_MEMBERS STAYS AT FOUR.
	"player_state.cast_effect_mode", "player_state.cast_target_slot",
	"player_state.cast_target_index", "player_state.cast_damage",
	# Story 6-5c (AC 17/AC 18): THE ROOT and its two INDEPENDENT switches classify HASHED on the same
	# test -- the window CROSSES TICKS (it spans the stun plus the root) and each switch DECIDES AN
	# OUTCOME (whether RUN, and whether ROLL, is gone while it runs). All three ride the ONE new fused
	# `root` key, gated on the window so a stopped root cannot hash a stale switch, and
	# UNHASHED_CROSS_TICK_MEMBERS stays at 4 -- this story argues no fifth exclusion.
	"player_state.root_window", "player_state.root_blocks_run", "player_state.root_blocks_roll",
	# Story 6-2 (AC 14b/AC 14c), narrowed by the review fix (H1): the Pitch Zone's card-identity and
	# hand-slot records classify HASHED beside the fizzle window they share an object with -- they
	# CROSS TICKS (staging to fizzle) and DECIDE AN OUTCOME (which card fizzles, into which slot the
	# replacement is owed). Card identity in the hash is RULED safe here: the staged card is PUBLIC by
	# GDD design. Both ride the existing `"pitch"` key, so no exemption is needed for them (AC 14c).
	# `_orb_costs` does NOT classify here any more -- it is card `.tres` CONTENT (H1), and moved to
	# UNHASHED_CROSS_TICK below.
	"pitch_state._card_ids", "pitch_state._hand_slots",
	"pitch_state._fizzle",
	# Story 6-5d (AC 30): the variable cost's two frozen facts classify HASHED, NOT beside their
	# `_orb_costs` neighbour in exclusion (d). The distinction is the one `3-2`'s close-out actually drew:
	# `_orb_costs` is excluded because it is card `.tres` CONTENT, and repricing a card must never
	# re-baseline the golden. Neither of these is content -- both are the OUTCOME of a player action
	# against a live pool (what was paid, and the product frozen from it), the same class of fact as
	# `mana` itself. Both CROSS TICKS (frozen from staging until `clear()`) and DECIDE AN OUTCOME (what
	# the Fireball hits for), and both ride the pitch zone snapshot's new `mana_spent` / `locked_damage`
	# keys -- so UNHASHED_CROSS_TICK_MEMBERS STAYS AT FOUR rather than becoming five.
	"pitch_state._mana_spent", "pitch_state._locked_damage",
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
	# Story 6-6b (AC 8): THE COUNTER'S OBSERVATION POINT classifies PER_TICK on
	# `_iframe_open_at_step3`'s exact test, which is the member it is modelled on: written at the top of
	# step 3 on every tick that reaches step 3, read only later within that same step, and never carried
	# across an `advance()` boundary. A round-over tick returns at step 1b and neither writes nor reads
	# it, and the next tick that does reach step 3 overwrites it before any read.
	"match_state._counter_color_at_step3",
	# Story 6-6a review (D2): the "this `hit_landed` was blocked" fact, raised and lowered around ONE queued
	# emission inside the drain -- false at every point a tick or a snapshot can observe. Not cross-tick
	# state at all: UNHASHED_CROSS_TICK_MEMBERS stays at 4.
	"match_state._hit_landed_blocked",
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
	# Story 6-5a (AC 6): the injected PITCH-EFFECT map, classified INJECTED for `_pitch_costs`'s reasons
	# verbatim -- changed only through `inject_pitch_effects`, which IS a capture channel
	# (`capture_inject_pitch_effects`). UNHASHED_CROSS_TICK_MEMBERS stays at 4.
	"match_state._pitch_effects",
	# Story 6-5d (AC 3, Open Question 4): the FLIGHT-PROFILE MIRROR and its tick twin, classified
	# INJECTED for `_pitch_effects`' reasons and one more that makes the case stronger rather than weaker:
	# they are not merely changed only through `inject_pitch_effects`, they are REBUILT WHOLESALE inside
	# it, from the map that call just took. So restoring the injection restores them exactly, the way
	# restoring `balance` restores `balance_ticks` -- this block's own stated precedent for a derived
	# member. Nothing else in the project writes either one, and no tick produces either.
	# UNHASHED_CROSS_TICK_MEMBERS STAYS AT FOUR.
	"match_state._effect_projectiles", "match_state._effect_projectile_delay_ticks",
	# Story 6-5e (AC 1a/AC 16): TWO MORE DERIVED-FROM-INJECTED-CONTENT MEMBERS, on the pair directly
	# above's argument verbatim and rebuilt in the same pass. `_effects_by_effect_id` is the effect-keyed
	# handle a live shot resolves through, and `_boulder_card_id` is the card whose basic effect clears a
	# cover -- both are pure functions of `_card_effects` and `_pitch_effects`, both are rebuilt WHOLESALE
	# inside an injection seam with a capture channel, and neither is ever written by a tick. A replay that
	# reproduces the injected content reproduces both exactly. UNHASHED_CROSS_TICK_MEMBERS STAYS AT FOUR.
	"match_state._effects_by_effect_id", "match_state._boulder_card_id",
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


# ---------------------------------------------------------------- story 6-5d, AC 32

## Story 6-5d (AC 32): A SECOND DRIVEN RUN -- THE SPELL RUN -- replayed to a bit-identical hash.
##
## A SIBLING FIXTURE RATHER THAN AN EXTENSION OF THE ONE ABOVE, and the reason is the same one that gave
## that fixture its own existence (this file's header): the driven run above is the pin for ACs 1-11 and
## every one of its channel-drop proofs is calibrated to what it does. Bolting a two-cast spell
## choreography onto it would re-time every constant in it and put two unrelated stories' proofs in one
## sequence. This run drives ONLY what AC 32 names and leaves that one alone.
##
## WHAT IT DRIVES, all of it through RECORDED CHANNELS and nothing poked into state -- which is the whole
## difficulty of writing this fixture and the reason it earns a place here. The state-side pokes
## `test_fireball.gd` uses freely (`mana.add`, `orbs.add`, `units.add`, a written `lock_target_slot`) are
## all unavailable: a replay never performs them, so any one of them would diverge the hash for a reason
## that has nothing to do with the spells. Every fact below therefore arrives the way the runner would
## deliver it:
##   * MANA comes from a MELEE HIT on each side -- an attack press, then a contact fact pushed inside the
##     active window, exactly as the fixture above earns its own mana.
##   * THE MINION comes from a real CAST: P2 presses a card whose basic effect is a `summon_`.
##   * THE LOCK comes from `retarget_slot`/`retarget_index` on the intent (`_resolve_lock`), the channel
##     the Golden Prediction's "intake: none" clause named as already sufficient for AC 24.
##   * THE ORB REQUIREMENT IS AUTHORED AWAY rather than choreographed: this fixture's pitch condition
##     costs NO orb. Orbs are banked only by landing an unblockable (`_grant_landing_orbs`), which is an
##     entire chargeup choreography, and the orb GATE is AC 10's and is pinned in `test_fireball.gd`.
##     What AC 32 asks for is the replay round trip of a Fireball, not a second proof of the gate.
##   * THE LANDING comes from a contact fact pushed at the projectile's own attacker address, the fact
##     `_gather_projectile_facts` would gather -- so the record carries the landing rather than the
##     replay re-deriving it.
##
## THE LOCK IS MOVED MID-CAST, TWICE, ON PURPOSE (`6-5d/R15`): each cast starts with the lock on the
## MINION and the lock is then moved to the HERO while the cast runs. So the CAPTURED copy and the LIVE
## lock disagree at both strikes, and the non-vacuity test below asserts that disagreement directly --
## which is what makes this fixture kill a strike seat that read the live lock instead of the captured
## one, a mutation a replay-identity assertion alone could never see (both runs would read it alike).
const SPELL_SEED := 6565
const SPELL_TICKS := 44
const SPELL_ATTACK_TICK := 5     # both heroes swing; the windows are `_config()`'s
const SPELL_CONTACT_TICK := 9    # a fact inside both active windows -> mana on both sides
const SPELL_SUMMON_TICK := 12    # P2's basic cast: the minion this story's spells aim at
const SPELL_LOCK_MINION_TICK := 14
const SPELL_BOLT_TICK := 16      # P1's BASIC cast -> a Honed Bolt cast on the locked minion
const SPELL_RELOCK_HERO_TICK := 18   # mid-cast: the live lock leaves the captured target behind
const SPELL_RELOCK_MINION_TICK := 24
const SPELL_STAGE_TICK := 26     # the PITCH press: the variable mana cost, the locked damage
const SPELL_ACTIVATE_TICK := 28  # the orb-less activation -> the Fireball cast starts
const SPELL_RELOCK_HERO_AGAIN_TICK := 36
const SPELL_LAND_TICK := 38      # the Fireball's contact fact, on the CAPTURED minion
const SPELL_CAST_TICKS := 6

## THREE CARDS AND A HAND THAT HOLDS ALL THREE, so the press seats need no knowledge of the deal: the
## deck is dealt out entirely and each id is findable by name. Opaque ids, the `DECK_IDS` discipline --
## `data/cards/` is unreachable from the state harness and no card library contains these.
const SPELL_SUMMON_CARD := &"spell_run_summon"
const SPELL_BOLT_CARD := &"spell_run_bolt"
const SPELL_SPARE_CARD := &"spell_run_spare"
const SPELL_DECK: Array[StringName] = [SPELL_SUMMON_CARD, SPELL_BOLT_CARD, SPELL_SPARE_CARD]
const SPELL_MANA_COST := 2.0
const SPELL_PITCH_MANA_COST := 3.0
## The Fireball shape: a cap BELOW the mana P1 will hold at staging, so the `min(X, cap)` branch is the
## one exercised and the locked damage is a number no other fact in the run could produce.
const SPELL_MANA_CAP := 8.0
const SPELL_DAMAGE_PER_MANA := 1.5
const SPELL_BOLT_DAMAGE := 4.0
const SPELL_UNIT_HP := 9.0


## AC 32, the primary: a recorded match containing a Fireball (staged, activated, flown and LANDED) and
## a targeted Honed Bolt on a minion replays FROM THE RECORD ALONE to a bit-identical hash.
func test_a_recorded_fireball_and_targeted_bolt_replay_to_the_identical_hash() -> void:
	var recorded := _record_a_spell_run()
	var live: MatchState = recorded["state"]
	var record: IntentRecorder = recorded["record"]
	assert_eq(record.tick_count(), SPELL_TICKS, "the record carries every tick that ran")
	var replayed := _replay(record)
	assert_eq(CanonicalHash.of(replayed.to_snapshot()), CanonicalHash.of(live.to_snapshot()),
		"AC 32: a replay of the spell run, driven from the record ALONE, is bit-identical")
	# The falsifying half, on the channel this fixture leans on hardest: without the contact facts
	# neither hero earns mana, nothing is cast and nothing lands.
	assert_ne(CanonicalHash.of(_replay(record, "contacts").to_snapshot()),
		CanonicalHash.of(live.to_snapshot()),
		"...and with the contact channel dropped it DIVERGES, so the landing rides the record")


## AC 32's other half: the run must actually DO the four things, or a bit-identical replay would be
## proving something about a sequence of refusals. Each clause is pinned on the recorded run's own
## final state.
func test_the_spell_run_stages_activates_flies_and_lands_a_fireball_at_a_locked_minion() -> void:
	var recorded := _record_a_spell_run()
	var live: MatchState = recorded["state"]
	# THE MINION EXISTED AND WAS BOLTED. Its HP is read at the end, so the bolt's damage is asserted
	# against a body the Fireball then killed -- the corpse is what proves both landings.
	assert_eq(live.p2.units.size(), 1, "P2's basic cast summoned the minion the spells aim at")
	assert_false(live.p2.units.is_alive_at(0),
		"the Fireball's landing killed the bolted minion, so both spells reached the same body")
	# THE FIREBALL: staged, activated, launched, flown and consumed by its landing.
	assert_eq(live.p1.projectiles.size(), 1, "exactly one Fireball was launched")
	assert_true(live.p1.projectiles.is_hero_sourced_at(0),
		"...by the cast strike, hero-sourced (AC 13)")
	assert_almost_eq(live.p1.projectiles.damage_at(0), SPELL_MANA_CAP * SPELL_DAMAGE_PER_MANA, 0.0001,
		"...carrying the damage the STAGING froze: the capped spend times damage_per_mana (AC 7)")
	assert_false(live.p1.projectiles.is_alive_at(0),
		"...and it was CONSUMED by the landing rather than still being in the air (AC 32's 'landing')")
	assert_false(live.pitch.is_staged(0), "the zone is empty: the staged card was ACTIVATED, not fizzled")
	# BOTH P1 PRESSES SPENT, read off the pool rather than off the discard: this fixture's draw pile is
	# empty by the second press, so a resolved card is RESHUFFLED back out of the discard and a discard
	# count would be 0 for a run that did everything. The pool cannot be reshuffled: 12 earned, 2 for the
	# bolt's basic cast and the CAPPED 8 for the staging, which is also the `min(X, cap)` branch's proof.
	assert_almost_eq(live.p1.mana.get_current(),
		MELEE_HIT_MANA - SPELL_MANA_COST - SPELL_MANA_CAP, 0.0001,
		"the bolt press spent its mana cost and the staging spent the CAP, not the whole pool (AC 5)")
	# THE BOLT, measured as it struck (see `_record_a_spell_run`): AC 32's "a targeted Honed Bolt on a
	# minion", and it landed on the CAPTURED minion while the live lock had already left it.
	assert_almost_eq(float(recorded["hp_after_bolt"]), SPELL_UNIT_HP - SPELL_BOLT_DAMAGE, 0.0001,
		"the bolt landed on the captured MINION for its authored damage (AC 25's unit arm)")
	assert_eq(recorded["lock_at_bolt_strike"], [1, TargetingService.HERO_INDEX],
		"...while the LIVE lock had already moved to the hero, so a strike reading the live lock "
		+ "would have hit the hero instead (`6-5d/R15`)")
	# THE CAPTURED COPY, NOT THE LIVE LOCK (`6-5d/R15`) -- and the two genuinely disagree here, which is
	# what makes the claim falsifiable at all.
	assert_eq(live.p1.projectiles.target_index_at(0), 0,
		"the shot is addressed at the captured MINION (AC 24)")
	assert_eq(live.p1.lock_target_index, TargetingService.HERO_INDEX,
		"...while the LIVE lock ended on the hero -- a strike that read the live lock would have "
		+ "aimed somewhere else, so this fixture can tell the two apart")


## The spell run itself. Plays the RUNNER's role exactly as `_record_a_driven_run` does -- capturing on
## every channel beside the call it taps -- and reads the live hand to choose its card slots, which is
## sound for a replay BECAUSE the chosen slot travels in the recorded intent: the replay presses the slot
## that was pressed, it never re-chooses.
func _record_a_spell_run() -> Dictionary:
	var record := IntentRecorder.new()
	var params := MatchParams.new(SPELL_SEED)
	record.capture_seed(params.seed_value)
	var ms := MatchState.new(params)
	var config := _spell_config()
	record.capture_apply_balance(config)
	ms.apply_balance(config)
	var flags := _spell_flags()
	record.capture_inject_feature_flags(flags)
	ms.inject_feature_flags(flags)
	# The six content channels, in `SOUND_CONTENT_ORDER`.
	record.capture_inject_deck(SPELL_DECK)
	ms.inject_deck(SPELL_DECK)
	var costs := _spell_costs()
	record.capture_inject_card_costs(costs)
	ms.inject_card_costs(costs)
	var effects := _spell_effects()
	record.capture_inject_card_effects(effects)
	ms.inject_card_effects(effects)
	var colors := _spell_colors()
	record.capture_inject_card_colors(colors)
	ms.inject_card_colors(colors)
	var pitch_costs := _spell_pitch_costs()
	record.capture_inject_pitch_costs(pitch_costs)
	ms.inject_pitch_costs(pitch_costs)
	var pitch_effects := _spell_pitch_effects()
	record.capture_inject_pitch_effects(pitch_effects)
	ms.inject_pitch_effects(pitch_effects)
	var hp_after_bolt := -1.0
	var lock_at_bolt_strike: Array[int] = []
	for t in range(1, SPELL_TICKS + 1):
		if t == SPELL_CONTACT_TICK:
			# One fact each way, inside both active windows: mana for both sides, captured and pushed
			# with IDENTICAL arguments so the replay pushes the same fact rather than a rebuilt one.
			for fact: Array in [[[0, -1], [1, -1], Vector2(-1.0, 0.0)],
					[[1, -1], [0, -1], Vector2(1.0, 0.0)]]:
				var attacker: Array[int] = [int(fact[0][0]), int(fact[0][1])]
				var target: Array[int] = [int(fact[1][0]), int(fact[1][1])]
				record.capture_push_contact(attacker, target, 0, fact[2] as Vector2,
						MatchState.CONTACT_STRIKE)
				ms.push_contact(attacker, target, 0, fact[2] as Vector2, MatchState.CONTACT_STRIKE)
		if t == SPELL_LAND_TICK and ms.p1.projectiles.size() > 0:
			# The Fireball's own contact, at its projectile attacker address and on the address the
			# RECORD says it is aimed at -- `test_fireball.gd::_push_shot_contact`, through the recorder.
			var attacker: Array[int] = [0, MatchState.projectile_attacker_index(0)]
			var target: Array[int] = [ms.p1.projectiles.target_slot_at(0),
					ms.p1.projectiles.target_index_at(0)]
			var flight := ms.p1.projectiles.flight_ticks_at(0)
			record.capture_push_contact(attacker, target, flight, Vector2(-1.0, 0.0),
					MatchState.CONTACT_STRIKE)
			ms.push_contact(attacker, target, flight, Vector2(-1.0, 0.0), MatchState.CONTACT_STRIKE)
		var intents := _spell_intents(ms, t)
		record.capture_advance(intents)
		ms.advance(intents)
		ms.drain_signals()
		# THE BOLT'S STRIKE TICK, READ AS IT PASSES. The Fireball kills the same minion twelve ticks
		# later, so the bolt's own damage is invisible in the final state -- and AC 32 asks for the bolt
		# as well as the Fireball. Exactly two facts are taken here and nowhere else: the HP the bolt
		# left behind, and where the LIVE lock had already moved to by the time it struck.
		if t == SPELL_BOLT_TICK + SPELL_CAST_TICKS:
			hp_after_bolt = ms.p2.units.hp_at(0)
			lock_at_bolt_strike = [ms.p1.lock_target_slot, ms.p1.lock_target_index]
	return {"state": ms, "record": record, "hp_after_bolt": hp_after_bolt,
		"lock_at_bolt_strike": lock_at_bolt_strike}


## One tick's intents. The card slots are found by NAME in the live hand (see `_record_a_spell_run`);
## a missing card leaves `card_slot` at its no-press default, so a fixture whose deal changed fails on
## the non-vacuity assertions rather than pressing the wrong card silently.
func _spell_intents(ms: MatchState, t: int) -> Array[InputIntent]:
	var i1 := InputIntent.new()
	var i2 := InputIntent.new()
	if t == SPELL_ATTACK_TICK:
		i1.pressed[&"attack"] = true
		i1.held[&"attack"] = true
		i2.pressed[&"attack"] = true
		i2.held[&"attack"] = true
	if t == SPELL_SUMMON_TICK:
		_press_card(i2, ms.p2.hand.to_array().find(SPELL_SUMMON_CARD), Enums.ModeKind.BASIC)
	if t == SPELL_LOCK_MINION_TICK or t == SPELL_RELOCK_MINION_TICK:
		i1.retarget_slot = 1
		i1.retarget_index = 0
	if t == SPELL_RELOCK_HERO_TICK or t == SPELL_RELOCK_HERO_AGAIN_TICK:
		i1.retarget_slot = 1
		i1.retarget_index = TargetingService.HERO_INDEX
	if t == SPELL_BOLT_TICK:
		_press_card(i1, ms.p1.hand.to_array().find(SPELL_BOLT_CARD), Enums.ModeKind.BASIC)
	if t == SPELL_STAGE_TICK:
		# ANY occupied slot: every id in this fixture carries the SAME pitch effect, so the pitch press
		# needs no identity -- the deliberate twin of `test_fireball.gd`'s uniform pitch map.
		_press_card(i1, _first_occupied_slot(ms.p1.hand), Enums.ModeKind.PITCH)
	if t == SPELL_ACTIVATE_TICK:
		i1.card_mode = Enums.ModeKind.PITCH
		i1.card_commit = true
		i1.card_activate = true
	var out: Array[InputIntent] = [i1, i2]
	return out


func _press_card(intent: InputIntent, slot: int, mode: Enums.ModeKind) -> void:
	if slot < 0:
		return
	intent.card_slot = slot
	intent.card_mode = mode
	intent.card_commit = true


func _first_occupied_slot(hand: Hand) -> int:
	for i in hand.size():
		if not hand.is_slot_empty(i):
			return i
	return -1


## `_flags()` with the SPELLS layer opened, which is what `CardEffectResolver.outcome` reads before it
## will return either cast outcome. Its own function rather than an edit to `_flags()`: the run above
## carries no spell content and must stay exactly the fixture its channel-drop proofs are calibrated on.
func _spell_flags() -> FeatureFlags:
	var f := _flags()
	f.spells = true
	return f


## `_config()` with the three values this run needs moved: a three-card deck dealt out entirely, so
## every id is in hand, and a fizzle countdown that outlasts the two ticks between the stage and the
## activation. Everything else -- the attack windows the contact tick is keyed to, the minion kind the
## summon resolves, `melee_hit_mana` -- is deliberately the SAME fixture the run above is calibrated on.
func _spell_config() -> BalanceConfig:
	var c := _config()
	c.deck_size = SPELL_DECK.size()
	c.hand_size = SPELL_DECK.size()
	c.unit_kinds = UnitKindFixture.minion_only(SPELL_UNIT_HP, 3.0, 0, 0, 0, 2.0)
	return c


func _spell_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in SPELL_DECK:
		var c := CardCastCondition.new()
		c.mana_cost = SPELL_MANA_COST
		out[id] = c
	return out


## NO ORB PRICE -- see the section header for why that is authored away rather than choreographed.
func _spell_pitch_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in SPELL_DECK:
		var c := CardCastCondition.new()
		c.mana_cost = SPELL_PITCH_MANA_COST
		out[id] = c
	return out


func _spell_colors() -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	for id in SPELL_DECK:
		out[id] = Enums.CardColor.RED
	return out


## The BASIC effects: one summon, one Honed Bolt, and a spare that resolves a summon too. Named by the
## shapes the resolver recognises -- the `summon_` prefix and the whole-id `honed_bolt` row.
func _spell_effects() -> Dictionary[StringName, CardEffect]:
	var summon := CardEffect.new()
	summon.effect_id = &"summon_spell_run_minion"
	var bolt := CardEffect.new()
	bolt.effect_id = &"honed_bolt"
	bolt.cast_seconds = float(SPELL_CAST_TICKS) / TimingWindow.TICK_HZ
	bolt.damage_amount = SPELL_BOLT_DAMAGE
	var out: Dictionary[StringName, CardEffect] = {}
	out[SPELL_SUMMON_CARD] = summon
	out[SPELL_BOLT_CARD] = bolt
	out[SPELL_SPARE_CARD] = summon
	return out


## The PITCH effect: ONE Fireball, on every id, so the pitch press needs no card identity.
func _spell_pitch_effects() -> Dictionary[StringName, CardEffect]:
	var fireball := CardEffect.new()
	fireball.effect_id = &"fireball"
	fireball.cast_seconds = float(SPELL_CAST_TICKS) / TimingWindow.TICK_HZ
	fireball.mana_cap = SPELL_MANA_CAP
	fireball.damage_per_mana = SPELL_DAMAGE_PER_MANA
	fireball.launch_speed = 8.0
	fireball.homing_turn_rate_degrees_per_second = 120.0
	fireball.max_speed = 8.0
	fireball.travel_budget = 60.0
	var out: Dictionary[StringName, CardEffect] = {}
	for id in SPELL_DECK:
		out[id] = fireball
	return out


# ---------------------------------------------------------------- story 6-5e, AC 41

## Story 6-5e (AC 41), BUILT AT THE REVIEW FIX (BLOCKER 1): A THIRD DRIVEN RUN -- THE BOULDER RUN --
## recorded, SAVED TO A `user://` FILE AT FORMAT_VERSION 17, LOADED BACK, and replayed FROM THE LOADED
## RECORD ALONE to a bit-identical hash.
##
## IT GOES THROUGH THE REAL RECORD PATH, and that is the difference from its two siblings above, which
## replay an in-memory `IntentRecorder`. `RecordFile` is where the version lives and where every channel
## is serialised and rebuilt, so a fixture that never touches disk cannot tell a v17 file from a recorder
## that happens to be in the right shape. This story's own `FORMAT_VERSION` 16 -> 17 argument rests on a
## v16 file replaying a Rocksling as a cast that fires nothing -- the POSITIVE half of that argument (a v17
## file replaying one correctly) is measured here and nowhere else.
##
## WHY THIS RUN EXISTS AT ALL, rather than the member classification the story shipped with. Three facts
## make it load-bearing beyond the usual:
##   1. THREE new hashed keys landed (`hand_covered`, `burst`, `corpse_bomb`), key set 40 -> 43.
##   2. `_rng` GAINED ITS SECOND CONSUMER IN THE PROJECT'S HISTORY (`_place_boulder`). A Boulder placement
##      shifts the seeded stream and therefore every LATER `_reshuffle_discard_into_deck`. The golden
##      fixture lands no stone, so the dev pass measured that a golden NON-cause -- which is true and says
##      nothing about replay. This run plants TWO Boulders and reshuffles across them, so the stream's
##      position is exercised on both sides of the draw.
##   3. The burst SCHEDULE outlives the cast that armed it, so a replay carries cross-tick state no earlier
##      fixture produced.
##
## WHAT IT DRIVES, all through RECORDED CHANNELS and nothing poked into state -- the `_record_a_spell_run`
## discipline, which is what makes the fixture hard and what makes it worth having:
##   * MANA comes from a MELEE HIT on each side (an attack press plus a pushed contact inside the active
##     window), never `mana.add`.
##   * THE BOULDERS come from real Rocksling stones landing on the opposing hero, each through a pushed
##     contact fact at the projectile's own attacker address -- so the SEEDED SLOT PICK runs inside the
##     recorded run and has to be reproduced by the replay from the seed alone.
##   * THE MINIONS come from real Mode (1) summon casts by P1.
##   * THE ORB REQUIREMENT IS AUTHORED AWAY rather than choreographed, exactly as the spell run authors it
##     away: banking an orb is a whole unblockable choreography, and the orb GATE is not what AC 41 asks for.
##
## THE SEQUENCE, in order, and every step is asserted to have actually HAPPENED by the non-vacuity test
## below -- a replay that matched on a run where the stones missed would prove nothing:
##   t12 P1 casts Rocksling -> t18 strike, stone 0 away, stone 1 owed
##   t19 stone 0 lands on P2's hero -> BOULDER 1 planted in a seeded slot
##   t20 P2 presses Mode (1) on that covered slot -> BOULDER 1 cleared, the card beneath restored
##   t22 stone 1 launches (one authored interval later) -> t23 it lands -> BOULDER 2 planted
##   t26 P1 stages Boom -> t28 activates it -> BOULDER 2 detonates
##   t31/t33 P1 summons two minions -> t36 stages Corpse Bomb -> t38 activates it -> BOTH convert, two
##   skulls launch and are still in flight on the hashed final tick.
const BOULDER_RECORD_PATH := "user://test_6_5e_boulder_run.rec"
const BOULDER_SEED := 7777
const BOULDER_TICKS := 44
const BOULDER_ATTACK_TICK := 5       # both heroes swing; the windows are `_config()`'s
const BOULDER_CONTACT_TICK := 9      # a fact inside both active windows -> mana on both sides
const BOULDER_CAST_TICK := 12        # P1's Mode (1) Rocksling press
const BOULDER_CAST_TICKS := 6
const BOULDER_INTERVAL_TICKS := 4
const BOULDER_STONES := 2
const BOULDER_LAND_ONE_TICK := 19    # one tick after the strike at t18
const BOULDER_CLEAR_TICK := 20       # P2's Mode (1) press on the covered slot
const BOULDER_LAND_TWO_TICK := 23    # stone 1 launched at t22
const BOOM_STAGE_TICK := 26
const BOOM_ACTIVATE_TICK := 28
const SUMMON_ONE_TICK := 31
const SUMMON_TWO_TICK := 33
const CORPSE_BOMB_STAGE_TICK := 36
const CORPSE_BOMB_ACTIVATE_TICK := 38

## TWO CARD IDS AND A BOULDER, all opaque -- the `DECK_IDS` discipline, so `data/cards/` can never reach
## this fixture. The ROCK card carries Rocksling in Mode (1) and Boom in Mode (4); the SUMMON card carries a
## `summon_` in Mode (1) and Corpse Bomb in Mode (4). The composition is dealt out ENTIRELY (deck_size ==
## hand_size), so every id is in hand and the press seats need no knowledge of the deal.
const BOULDER_ROCK_CARD := &"boulder_run_rock"
const BOULDER_SUMMON_CARD := &"boulder_run_summon"
## The Boulder CARD's id is opaque too, and it never enters the composition: `MatchState._boulder_card_id`
## is DERIVED by finding the card whose basic effect the resolver's cover table names, so what makes this
## entry load-bearing is its EFFECT id (`boulder_discard`), not its own spelling.
const BOULDER_PLANT_CARD := &"boulder_run_boulder"
const BOULDER_DECK: Array[StringName] = [
	BOULDER_ROCK_CARD, BOULDER_ROCK_CARD,
	BOULDER_SUMMON_CARD, BOULDER_SUMMON_CARD, BOULDER_SUMMON_CARD, BOULDER_SUMMON_CARD,
]
const BOULDER_MANA_COST := 2.0
const BOULDER_PITCH_MANA_COST := 3.0
const BOULDER_MELEE_MANA := 40.0
const BOULDER_STONE_DAMAGE := 3.0
const BOOM_DAMAGE := 6.0
const SKULL_DAMAGE := 5.0
const BOULDER_SLOW_PER_BOULDER := 0.15


## AC 41, the primary: a recorded match carrying a Rocksling burst that plants a Boulder, a Mode (1) clear,
## a second Boulder, a Boom that detonates it and a Corpse Bomb that converts two minions, SAVED and
## RELOADED, replays from that file alone to the identical final hash.
func test_a_saved_and_reloaded_boulder_run_replays_to_the_identical_hash() -> void:
	var recorded := _record_a_boulder_run()
	var live: MatchState = recorded["state"]
	var record: IntentRecorder = recorded["record"]
	var live_hash := CanonicalHash.of(live.to_snapshot())
	assert_eq(record.tick_count(), BOULDER_TICKS, "the record carries every tick that ran")
	# THE REAL RECORD PATH: `user://` file out, file in, replay from what came back.
	assert_eq(RecordFile.save_record(record, BOULDER_RECORD_PATH), "", "the record was written to disk")
	assert_eq(_saved_format_version(BOULDER_RECORD_PATH), 18,
		"...at FORMAT_VERSION 18, read out of the FILE rather than off the constant (6-5f AC 29; 17 as of 6-5e AC 39)")
	var result := RecordFile.load_record(BOULDER_RECORD_PATH)
	assert_not_null(result["record"],
		"...and it loads back: %s" % str(result["error"]))
	var loaded: IntentRecorder = result["record"]
	assert_eq(CanonicalHash.of(_replay(loaded).to_snapshot()), live_hash,
		"AC 41: a replay driven from the SAVED AND RELOADED record alone is bit-identical")
	# The falsifying half, on the three channels this run leans on hardest. Without the contacts neither
	# hero earns mana and no stone ever lands; without the effects there is no Rocksling to cast; without
	# the intents nothing is pressed at all.
	for channel in ["contacts", "effects", "intents"]:
		assert_ne(CanonicalHash.of(_replay(loaded, channel).to_snapshot()), live_hash,
			"dropping the %s channel must DIVERGE this replay too" % channel)
	_remove_record(BOULDER_RECORD_PATH)


## AC 41's other half, and the one the review asked for BY NAME: the recorded run must actually DO each of
## the five things, or a bit-identical replay would be proving something about a sequence of refusals.
## Every clause is measured on the LIVE run as it passed, not inferred from the final state.
func test_the_boulder_run_plants_clears_replants_detonates_and_converts() -> void:
	var recorded := _record_a_boulder_run()
	var live: MatchState = recorded["state"]
	# (a) THE BURST LAUNCHED AT LEAST TWO STONES, each a hero-sourced record at the authored damage.
	assert_eq(int(recorded["stones_launched"]), BOULDER_STONES,
		"the Rocksling burst launched every authored stone (AC 8)")
	assert_true(int(recorded["stones_launched"]) >= 2,
		"...and AC 41's 'at least two stones' is met by the burst rather than by two casts")
	assert_true(bool(recorded["stones_hero_sourced"]),
		"...each one hero-sourced, so the cover placement rung is the one that ran")
	# (b) THE FIRST STONE LANDED ON THE OPPOSING HERO AND PLANTED A BOULDER.
	assert_almost_eq(float(recorded["stone_one_damage"]), BOULDER_STONE_DAMAGE, 0.0001,
		"stone 0 LANDED on P2's hero for the authored per-stone damage (AC 16)")
	assert_eq(int(recorded["covers_after_first_landing"]), 1,
		"...and planted exactly one Boulder in P2's hand (AC 16)")
	assert_true(int(recorded["rng_draws_moved"]) > 0,
		"...through the SEEDED pick, so `_rng`'s second consumer really ran inside the recorded run (M1)")
	# (c) THE MODE (1) PRESS CLEARED IT, with the card beneath restored in its own slot.
	assert_eq(int(recorded["covers_after_clear"]), 0, "the Mode (1) press cleared that Boulder (AC 21)")
	assert_eq(recorded["card_beneath_before_clear"], recorded["card_beneath_after_clear"],
		"...and the card beneath came back in its OWN slot, unmoved (AC 21)")
	# (d) A SECOND BOULDER WAS PLANTED AND BOOM DETONATED IT.
	assert_eq(int(recorded["covers_after_second_landing"]), 1, "stone 1 planted a second Boulder (AC 16)")
	assert_almost_eq(float(recorded["boom_damage"]), BOOM_DAMAGE, 0.0001,
		"Boom dealt its authored per-Boulder damage to the opposing hero (AC 26)")
	assert_eq(int(recorded["covers_after_boom"]), 0, "...and removed the Boulder it counted (AC 27)")
	# (e) CORPSE BOMB CONVERTED AT LEAST TWO MINIONS, and its record is readable on the hashed final state.
	var conversion: Array = live.p1.to_snapshot()["corpse_bomb"]
	assert_eq(conversion[1], [0, 1] as Array[int],
		"the Corpse Bomb activation converted BOTH of P1's minions and recorded which (AC 40)")
	assert_eq(int(conversion[0]), CORPSE_BOMB_ACTIVATE_TICK,
		"...on the activation tick, which is inside the replayed hash (AC 38)")
	assert_eq(live.p1.units.corpse_indices(), [0, 1] as Array[int],
		"...each leaving a normal corpse through the shared death seat (AC 30)")
	assert_eq(live.p1.projectiles.size(), BOULDER_STONES + 2,
		"...and one skull per converted minion joined the two stones on the board (AC 31)")
	assert_true(live.p1.projectiles.is_alive_at(BOULDER_STONES),
		"...with the skulls still IN FLIGHT on the hashed final tick, so their state is replayed")
	# THE HASHED KEYS THIS STORY ADDED ARE ALL NON-RESTING SOMEWHERE IN THE RUN, which is what makes the
	# replay assertion above a test of them rather than a test of three resting literals.
	assert_true(int(recorded["max_covers_seen"]) > 0, "`hand_covered` left its resting all-false state")
	assert_true(int(recorded["max_burst_remaining"]) > 0, "`burst` left its resting empty state")
	assert_ne(int(conversion[0]), PlayerState.NO_CORPSE_BOMB_TICK, "`corpse_bomb` left its resting state")


## The boulder run itself. Plays the RUNNER's role exactly as its two siblings do -- capturing on every
## channel beside the call it taps -- and reads the live hand (and the live COVER layer) to choose its card
## slots, which is sound for a replay BECAUSE the chosen slot travels in the recorded intent: the replay
## presses the slot that was pressed, it never re-chooses.
func _record_a_boulder_run() -> Dictionary:
	var record := IntentRecorder.new()
	var params := MatchParams.new(BOULDER_SEED)
	record.capture_seed(params.seed_value)
	var ms := MatchState.new(params)
	var config := _boulder_config()
	record.capture_apply_balance(config)
	ms.apply_balance(config)
	var flags := _boulder_flags()
	record.capture_inject_feature_flags(flags)
	ms.inject_feature_flags(flags)
	# The six content channels, in `SOUND_CONTENT_ORDER`.
	record.capture_inject_deck(BOULDER_DECK)
	ms.inject_deck(BOULDER_DECK)
	var costs := _boulder_costs()
	record.capture_inject_card_costs(costs)
	ms.inject_card_costs(costs)
	var effects := _boulder_basic_effects()
	record.capture_inject_card_effects(effects)
	ms.inject_card_effects(effects)
	var colors := _boulder_colors()
	record.capture_inject_card_colors(colors)
	ms.inject_card_colors(colors)
	var pitch_costs := _boulder_pitch_costs()
	record.capture_inject_pitch_costs(pitch_costs)
	ms.inject_pitch_costs(pitch_costs)
	var pitch_effects := _boulder_pitch_effects()
	record.capture_inject_pitch_effects(pitch_effects)
	ms.inject_pitch_effects(pitch_effects)
	var seen := {
		"stones_launched": 0, "stones_hero_sourced": true, "stone_one_damage": 0.0,
		"covers_after_first_landing": 0, "covers_after_clear": -1, "covers_after_second_landing": 0,
		"card_beneath_before_clear": &"", "card_beneath_after_clear": &"",
		"boom_damage": 0.0, "covers_after_boom": -1,
		"max_covers_seen": 0, "max_burst_remaining": 0, "rng_draws_moved": 0,
	}
	var rng_state_before := ms._rng.state
	for t in range(1, BOULDER_TICKS + 1):
		if t == BOULDER_CONTACT_TICK:
			# One fact each way, inside both active windows: mana for both sides, captured and pushed with
			# IDENTICAL arguments so the replay pushes the same fact rather than a rebuilt one.
			for fact: Array in [[[0, -1], [1, -1], Vector2(-1.0, 0.0)],
					[[1, -1], [0, -1], Vector2(1.0, 0.0)]]:
				var attacker: Array[int] = [int(fact[0][0]), int(fact[0][1])]
				var target: Array[int] = [int(fact[1][0]), int(fact[1][1])]
				record.capture_push_contact(attacker, target, 0, fact[2] as Vector2,
						MatchState.CONTACT_STRIKE)
				ms.push_contact(attacker, target, 0, fact[2] as Vector2, MatchState.CONTACT_STRIKE)
		if t == BOULDER_LAND_ONE_TICK:
			_push_stone_contact(ms, record, 0)
		if t == BOULDER_LAND_TWO_TICK:
			_push_stone_contact(ms, record, 1)
		# THE TWO TRANSIENT READS, taken IMMEDIATELY BEFORE the tick that destroys what they name: the card
		# under the Boulder (the Mode (1) press uncovers it) and P2's hp (the Boom press removes some).
		var hp_before_tick := ms.p2.hero.get_hp()
		if t == BOULDER_CLEAR_TICK and not ms.p2.hand.covered_indices().is_empty():
			var slot: int = ms.p2.hand.covered_indices()[0]
			seen["card_beneath_before_clear"] = ms.p2.hand.to_array()[slot]
		var intents := _boulder_intents(ms, t)
		record.capture_advance(intents)
		ms.advance(intents)
		ms.drain_signals()
		seen["max_covers_seen"] = maxi(int(seen["max_covers_seen"]), ms.p2.hand.cover_count())
		seen["max_burst_remaining"] = maxi(int(seen["max_burst_remaining"]), ms.p1.burst_remaining)
		if t == BOULDER_LAND_ONE_TICK:
			seen["stone_one_damage"] = hp_before_tick - ms.p2.hero.get_hp()
			seen["covers_after_first_landing"] = ms.p2.hand.cover_count()
			seen["rng_draws_moved"] = 1 if ms._rng.state != rng_state_before else 0
		if t == BOULDER_CLEAR_TICK:
			seen["covers_after_clear"] = ms.p2.hand.cover_count()
			seen["card_beneath_after_clear"] = ms.p2.hand.to_array()[_slot_of(ms.p2.hand,
					seen["card_beneath_before_clear"] as StringName)]
		if t == BOULDER_LAND_TWO_TICK:
			seen["covers_after_second_landing"] = ms.p2.hand.cover_count()
		if t == BOOM_ACTIVATE_TICK:
			seen["boom_damage"] = hp_before_tick - ms.p2.hero.get_hp()
			seen["covers_after_boom"] = ms.p2.hand.cover_count()
		if t == BOULDER_LAND_TWO_TICK:
			seen["stones_launched"] = ms.p1.projectiles.size()
			for shot in ms.p1.projectiles.size():
				if not ms.p1.projectiles.is_hero_sourced_at(shot):
					seen["stones_hero_sourced"] = false
	var out := {"state": ms, "record": record}
	out.merge(seen)
	return out


## One tick's intents for the boulder run. Card slots are found by NAME in the live hand (the spell run's
## own rule); a missing card leaves `card_slot` at its no-press default, so a fixture whose deal changed
## fails on the non-vacuity assertions rather than pressing the wrong card silently.
func _boulder_intents(ms: MatchState, t: int) -> Array[InputIntent]:
	var i1 := InputIntent.new()
	var i2 := InputIntent.new()
	if t == BOULDER_ATTACK_TICK:
		i1.pressed[&"attack"] = true
		i1.held[&"attack"] = true
		i2.pressed[&"attack"] = true
		i2.held[&"attack"] = true
	if t == BOULDER_CAST_TICK:
		_press_card(i1, ms.p1.hand.to_array().find(BOULDER_ROCK_CARD), Enums.ModeKind.BASIC)
	if t == BOULDER_CLEAR_TICK:
		# THE COVERED SLOT, read LIVE because the seeded pick chose it -- and sound for a replay because the
		# slot travels in the recorded intent rather than being re-chosen on the way back.
		var covered := ms.p2.hand.covered_indices()
		_press_card(i2, covered[0] if not covered.is_empty() else -1, Enums.ModeKind.BASIC)
	if t == BOOM_STAGE_TICK:
		_press_card(i1, ms.p1.hand.to_array().find(BOULDER_ROCK_CARD), Enums.ModeKind.PITCH)
	if t == SUMMON_ONE_TICK or t == SUMMON_TWO_TICK:
		_press_card(i1, ms.p1.hand.to_array().find(BOULDER_SUMMON_CARD), Enums.ModeKind.BASIC)
	if t == CORPSE_BOMB_STAGE_TICK:
		_press_card(i1, ms.p1.hand.to_array().find(BOULDER_SUMMON_CARD), Enums.ModeKind.PITCH)
	if t == BOOM_ACTIVATE_TICK or t == CORPSE_BOMB_ACTIVATE_TICK:
		i1.card_mode = Enums.ModeKind.PITCH
		i1.card_commit = true
		i1.card_activate = true
	var out: Array[InputIntent] = [i1, i2]
	return out


## The stone's own contact, at its projectile attacker address and on the address the BOARD says it is
## aimed at -- `test_rocksling_and_boulder.gd::_push_shot_contact`, routed through the recorder so the
## landing rides the record instead of being re-derived by the replay.
func _push_stone_contact(ms: MatchState, record: IntentRecorder, shot: int) -> void:
	if ms.p1.projectiles.size() <= shot:
		return
	var attacker: Array[int] = [0, MatchState.projectile_attacker_index(shot)]
	var target: Array[int] = [ms.p1.projectiles.target_slot_at(shot),
			ms.p1.projectiles.target_index_at(shot)]
	var flight := ms.p1.projectiles.flight_ticks_at(shot)
	var dir := ms.p2.hero.facing
	record.capture_push_contact(attacker, target, flight, dir, MatchState.CONTACT_STRIKE)
	ms.push_contact(attacker, target, flight, dir, MatchState.CONTACT_STRIKE)


func _slot_of(hand: Hand, id: StringName) -> int:
	var found := hand.to_array().find(id)
	return found if found >= 0 else 0


## The `format_version` an actual SAVED FILE carries, read out of the file rather than off the constant --
## which is the only reading that makes "saved at FORMAT_VERSION 17" a measurement.
func _saved_format_version(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var raw: Variant = f.get_var()
	f.close()
	if typeof(raw) != TYPE_DICTIONARY:
		return -1
	return int((raw as Dictionary).get("format_version", -1))


func _remove_record(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## `_config()` with what the boulder run needs moved, and nothing else: the composition dealt out entirely
## (so every id is in hand), enough melee mana for P1's five presses, and the S1 Boulder slow authored
## non-zero so that knob rides the balance channel and reaches P2's hashed velocity while it holds one.
func _boulder_config() -> BalanceConfig:
	var c := _config()
	c.deck_size = BOULDER_DECK.size()
	c.hand_size = BOULDER_DECK.size()
	c.melee_hit_mana = BOULDER_MELEE_MANA
	c.boulder_slow_per_boulder = BOULDER_SLOW_PER_BOULDER
	c.corpse_lifetime_seconds = 10.0
	return c


func _boulder_flags() -> FeatureFlags:
	var f := _flags()
	f.spells = true
	return f


## Priced for Mode (1). THE BOULDER CARD IS PRICED TOO and is not in the composition: a Mode (1) press on a
## covered slot prices through `_card_costs` at the BOULDER's own id, so without this entry the clear at
## t20 would refuse and step (c) of the sequence would silently not happen.
func _boulder_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in BOULDER_DECK:
		var c := CardCastCondition.new()
		c.mana_cost = BOULDER_MANA_COST
		out[id] = c
	var boulder := CardCastCondition.new()
	boulder.mana_cost = BOULDER_MANA_COST
	out[BOULDER_PLANT_CARD] = boulder
	return out


## NO ORB PRICE -- authored away for `_spell_pitch_costs`' reason verbatim.
func _boulder_pitch_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in BOULDER_DECK:
		var c := CardCastCondition.new()
		c.mana_cost = BOULDER_PITCH_MANA_COST
		out[id] = c
	return out


func _boulder_colors() -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	for id in BOULDER_DECK:
		out[id] = Enums.CardColor.RED
	out[BOULDER_PLANT_CARD] = Enums.CardColor.COLORLESS
	return out


## The BASIC effects: Rocksling on the ROCK card, a `summon_` on the SUMMON card, and the BOULDER card's own
## `boulder_discard` -- which is what `MatchState._boulder_card_id`'s derivation finds and what the Mode (1)
## clear at t20 resolves through.
func _boulder_basic_effects() -> Dictionary[StringName, CardEffect]:
	var rocksling := CardEffect.new()
	rocksling.effect_id = &"rocksling"
	rocksling.cast_seconds = float(BOULDER_CAST_TICKS) / TimingWindow.TICK_HZ
	rocksling.damage_amount = BOULDER_STONE_DAMAGE
	rocksling.boulders_per_cast = BOULDER_STONES
	rocksling.boulder_interval_seconds = float(BOULDER_INTERVAL_TICKS) / TimingWindow.TICK_HZ
	rocksling.launch_speed = 8.0
	rocksling.homing_turn_rate_degrees_per_second = 120.0
	rocksling.max_speed = 8.0
	rocksling.travel_budget = 60.0
	var summon := CardEffect.new()
	summon.effect_id = &"summon_boulder_run_minion"
	var boulder := CardEffect.new()
	boulder.effect_id = &"boulder_discard"
	var out: Dictionary[StringName, CardEffect] = {}
	out[BOULDER_ROCK_CARD] = rocksling
	out[BOULDER_SUMMON_CARD] = summon
	out[BOULDER_PLANT_CARD] = boulder
	return out


## The PITCH effects: Boom on the ROCK card, Corpse Bomb on the SUMMON card. Two DIFFERENT pitch effects in
## one map, unlike the spell run's uniform one, which is why each stage press names its card by id.
func _boulder_pitch_effects() -> Dictionary[StringName, CardEffect]:
	var boom := CardEffect.new()
	boom.effect_id = &"boom"
	boom.damage_amount = BOOM_DAMAGE
	var corpse_bomb := CardEffect.new()
	corpse_bomb.effect_id = &"corpse_bomb"
	corpse_bomb.damage_amount = SKULL_DAMAGE
	corpse_bomb.launch_speed = 8.0
	corpse_bomb.homing_turn_rate_degrees_per_second = 120.0
	corpse_bomb.max_speed = 8.0
	corpse_bomb.travel_budget = 60.0
	var out: Dictionary[StringName, CardEffect] = {}
	out[BOULDER_ROCK_CARD] = boom
	out[BOULDER_SUMMON_CARD] = corpse_bomb
	return out


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
	# Story 6-5a (AC 6): the SIXTH content channel, captured and injected LAST (empty is legal).
	var pitch_effects: Dictionary[StringName, CardEffect] = {}
	record.capture_inject_pitch_effects(pitch_effects)
	ms.inject_pitch_effects(pitch_effects)
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


# ---------------------------------------------------------------- 6-5f: the Counterspell run (AC 30)

## Story 6-5f (AC 30): THE SECOND FULL-CONTENT RECORDED RUN, and it exists because AC 30 names two
## reversals BY CARD -- "a Counterspell that reverses a Boom (HP and Boulders restored) AND a Counterspell
## that reverses a Culling (minions and mana restored)".
##
## IT IS A SEPARATE RUN RATHER THAN AN EXTENSION OF THE BOULDER RUN, deliberately: 6-5e's run is that
## story's own AC 41 evidence, and threading two Counterspells through it would move its hash, its damage
## readings and its five sequence assertions -- making one story's proof depend on the next story's content.
## Two runs, two records, two files, neither able to break the other.
##
## WHO IS WHO: **P1 is the aggressor and P2 counters.** P1 throws the Rocksling that plants Boulders in P2's
## hand, Booms them, summons two minions and Cullings them; P2 counters the Boom and then the Culling. That
## puts both reversals on the side that SUFFERED them, which is the live shape.
const COUNTER_RECORD_PATH := "user://test_6_5f_counterspell_run.rec"
const COUNTER_SEED := 8181
const COUNTER_TICKS := 52
const COUNTER_ATTACK_TICK := 5        # both heroes swing
const COUNTER_CONTACT_TICK := 9       # a fact each way -> melee mana on both sides
const COUNTER_CAST_TICK := 12         # P1's Mode (1) Rocksling press
const COUNTER_CAST_TICKS := 6
const COUNTER_INTERVAL_TICKS := 4
const COUNTER_STONES := 2
const COUNTER_LAND_ONE_TICK := 19     # one tick after the strike at t18
const COUNTER_LAND_TWO_TICK := 23     # stone 1 launched at t22
const COUNTER_BOOM_STAGE_TICK := 26
const COUNTER_BOOM_ACTIVATE_TICK := 28
const COUNTER_BOOM_COUNTER_STAGE_TICK := 31
const COUNTER_BOOM_COUNTER_TICK := 33
const COUNTER_SUMMON_ONE_TICK := 36
const COUNTER_SUMMON_TWO_TICK := 38
const COUNTER_CULLING_STAGE_TICK := 41
const COUNTER_CULLING_ACTIVATE_TICK := 43
const COUNTER_CULL_COUNTER_STAGE_TICK := 46
const COUNTER_CULL_COUNTER_TICK := 48

## THREE CARD IDS AND A BOULDER, all opaque -- `BOULDER_DECK`'s discipline, so `data/cards/` can never
## reach this fixture either. ROCK carries Rocksling in Mode (1) and Boom in Mode (4); SUMMON carries a
## `summon_` in Mode (1) and Culling in Mode (4); COUNTER carries Counterspell in BOTH modes (its Mode (1)
## press is never made -- one effect is simpler than an unused filler whose behaviour would need arguing).
const COUNTER_ROCK_CARD := &"counter_run_rock"
const COUNTER_SUMMON_CARD := &"counter_run_summon"
const COUNTER_COUNTER_CARD := &"counter_run_counter"
const COUNTER_PLANT_CARD := &"counter_run_boulder"
## SEVEN, and every count is load-bearing: TWO ROCKs (one spent on the Rocksling cast, one on the Boom
## activation), THREE SUMMONs (two spent summoning, one on the Culling activation) and TWO COUNTERs (one
## per reversal). The composition is dealt out ENTIRELY (deck_size == hand_size), so every id is in hand
## and no press depends on a replacement arriving.
const COUNTER_DECK: Array[StringName] = [
	COUNTER_ROCK_CARD, COUNTER_ROCK_CARD,
	COUNTER_SUMMON_CARD, COUNTER_SUMMON_CARD, COUNTER_SUMMON_CARD,
	COUNTER_COUNTER_CARD, COUNTER_COUNTER_CARD,
]
const COUNTER_CULLING_MANA_PER_KILL := 4.0


## AC 30, the primary: a recorded match carrying a Counterspell that reverses a Boom and a Counterspell
## that reverses a Culling, SAVED and RELOADED, replays from that file alone to the identical final hash.
func test_a_saved_and_reloaded_counterspell_run_replays_to_the_identical_hash() -> void:
	var recorded := _record_a_counterspell_run()
	var live: MatchState = recorded["state"]
	var record: IntentRecorder = recorded["record"]
	var live_hash := CanonicalHash.of(live.to_snapshot())
	assert_eq(record.tick_count(), COUNTER_TICKS, "the record carries every tick that ran")
	assert_eq(RecordFile.save_record(record, COUNTER_RECORD_PATH), "", "the record was written to disk")
	assert_eq(_saved_format_version(COUNTER_RECORD_PATH), 18,
		"...at FORMAT_VERSION 18, read out of the FILE rather than off the constant (AC 29)")
	var result := RecordFile.load_record(COUNTER_RECORD_PATH)
	assert_not_null(result["record"], "...and it loads back: %s" % str(result["error"]))
	var loaded: IntentRecorder = result["record"]
	assert_eq(CanonicalHash.of(_replay(loaded).to_snapshot()), live_hash,
		"AC 30: a replay driven from the SAVED AND RELOADED record alone is bit-identical")
	# The falsifying half, on the three channels this run leans on hardest. Without the contacts neither
	# hero earns mana and no stone ever lands; without the PITCH channels nothing can be staged, so the
	# Boom, the Culling and both Counterspells all fail to happen; without the intents nothing is pressed.
	#
	# `pitch_costs` IS THE CHANNEL NAME AND IT WITHHOLDS BOTH PITCH CHANNELS -- see `_replay`'s `elif`
	# chain, which stops before `inject_pitch_costs` AND `inject_pitch_effects`. There is deliberately no
	# `pitch_effects` name: `_replay` silently drops NOTHING for an unrecognised drop, so naming a channel
	# that does not exist would make this loop assert that a full replay diverges from itself -- which is
	# exactly how it failed on its first run here, and why the name is stated rather than guessed.
	for channel in ["contacts", "pitch_costs", "intents"]:
		assert_ne(CanonicalHash.of(_replay(loaded, channel).to_snapshot()), live_hash,
			"dropping the %s channel must DIVERGE this replay too" % channel)
	_remove_record(COUNTER_RECORD_PATH)


## AC 30's other half, on the boulder run's own standard: the recorded run must actually DO both reversals,
## or a bit-identical replay would be proving something about a sequence of refusals. Every clause is
## measured on the LIVE run as it passed, not inferred from the final state.
func test_the_counterspell_run_really_reverses_a_boom_and_a_culling() -> void:
	var seen: Dictionary = _record_a_counterspell_run()["seen"]
	# (a) THE BOOM LANDED: Boulders were planted and it detonated them for real damage.
	assert_true(int(seen["covers_before_boom"]) > 0,
		"the Rocksling really planted at least one Boulder in P2's hand (got %s)"
				% seen["covers_before_boom"])
	assert_eq(int(seen["covers_after_boom"]), 0, "...and the Boom detonated every one of them")
	assert_true(float(seen["boom_damage"]) > 0.0,
		"...for real damage (got %s)" % seen["boom_damage"])
	# (b) THE FIRST COUNTERSPELL REVERSED IT: hp back, Boulders back in the same slots.
	assert_eq(int(seen["covers_after_boom_counter"]), int(seen["covers_before_boom"]),
		"the Counterspell returned every detonated Boulder to P2's hand (AC 22/AC 30)")
	assert_eq(seen["boom_slots"], seen["restored_slots"],
		"...to the SAME slots they occupied before the Boom")
	assert_true(float(seen["boom_refund"]) > 0.0,
		"...and refunded the hp it removed (got %s)" % seen["boom_refund"])
	# (c) THE CULLING LANDED: two minions killed, mana granted.
	assert_eq(int(seen["minions_before_culling"]), 2, "P1 really had two living minions to cull")
	assert_eq(int(seen["minions_after_culling"]), 0, "...and the Culling killed both")
	assert_true(float(seen["culling_mana"]) > 0.0,
		"...granting mana for them (got %s)" % seen["culling_mana"])
	# (d) THE SECOND COUNTERSPELL REVERSED IT: minions restored, mana clawed back.
	assert_eq(int(seen["minions_after_counter"]), 2,
		"the second Counterspell raised both culled minions from their own corpses (AC 18/AC 30)")
	assert_true(float(seen["culling_claw_back"]) > 0.0,
		"...and took the granted mana back (got %s)" % seen["culling_claw_back"])
	# (e) NON-VACUITY on the cue seam: both reversals really reached `_apply_counterspell`.
	assert_eq(seen["cues"], [[1, 0], [1, 0]],
		"exactly TWO real reversals fired the cue, both by P2 against P1 (AC 26)")


## The fixture plays the RUNNER's role -- capturing on every channel beside the call it taps, exactly as
## `_record_a_boulder_run` does. Returns the recorded run's final state, its record and the live readings.
func _record_a_counterspell_run() -> Dictionary:
	var record := IntentRecorder.new()
	var params := MatchParams.new(COUNTER_SEED)
	record.capture_seed(params.seed_value)
	var ms := MatchState.new(params)
	var config := _counter_config()
	record.capture_apply_balance(config)
	ms.apply_balance(config)
	var flags := _boulder_flags()
	record.capture_inject_feature_flags(flags)
	ms.inject_feature_flags(flags)
	record.capture_inject_deck(COUNTER_DECK)
	ms.inject_deck(COUNTER_DECK)
	var costs := _counter_costs()
	record.capture_inject_card_costs(costs)
	ms.inject_card_costs(costs)
	var effects := _counter_basic_effects()
	record.capture_inject_card_effects(effects)
	ms.inject_card_effects(effects)
	var colors := _counter_colors()
	record.capture_inject_card_colors(colors)
	ms.inject_card_colors(colors)
	var pitch_costs := _counter_pitch_costs()
	record.capture_inject_pitch_costs(pitch_costs)
	ms.inject_pitch_costs(pitch_costs)
	var pitch_effects := _counter_pitch_effects()
	record.capture_inject_pitch_effects(pitch_effects)
	ms.inject_pitch_effects(pitch_effects)
	var cues: Array = []
	ms.counterspell_resolved.connect(
		func(caster: int, countered: int) -> void: cues.append([caster, countered]))
	var seen := {
		"covers_before_boom": 0, "covers_after_boom": -1, "boom_damage": 0.0,
		"boom_slots": [] as Array[int], "restored_slots": [] as Array[int],
		"covers_after_boom_counter": -1, "boom_refund": 0.0,
		"minions_before_culling": 0, "minions_after_culling": -1, "culling_mana": 0.0,
		"minions_after_counter": -1, "culling_claw_back": 0.0, "cues": cues,
	}
	for t in range(1, COUNTER_TICKS + 1):
		if t == COUNTER_CONTACT_TICK:
			for fact: Array in [[[0, -1], [1, -1], Vector2(-1.0, 0.0)],
					[[1, -1], [0, -1], Vector2(1.0, 0.0)]]:
				var attacker: Array[int] = [int(fact[0][0]), int(fact[0][1])]
				var target: Array[int] = [int(fact[1][0]), int(fact[1][1])]
				record.capture_push_contact(attacker, target, 0, fact[2] as Vector2,
						MatchState.CONTACT_STRIKE)
				ms.push_contact(attacker, target, 0, fact[2] as Vector2, MatchState.CONTACT_STRIKE)
		if t == COUNTER_LAND_ONE_TICK:
			_push_stone_contact(ms, record, 0)
		if t == COUNTER_LAND_TWO_TICK:
			_push_stone_contact(ms, record, 1)
		# THE TRANSIENT READS, each taken IMMEDIATELY BEFORE the tick that destroys what it names.
		var hp_before_tick := ms.p2.hero.get_hp()
		var mana_before_tick := ms.p1.mana.get_current()
		if t == COUNTER_BOOM_ACTIVATE_TICK:
			seen["covers_before_boom"] = ms.p2.hand.cover_count()
			seen["boom_slots"] = ms.p2.hand.covered_indices()
		if t == COUNTER_CULLING_ACTIVATE_TICK:
			seen["minions_before_culling"] = ms.p1.units.living_indices().size()
		var intents := _counter_intents(ms, t)
		record.capture_advance(intents)
		ms.advance(intents)
		ms.drain_signals()
		if t == COUNTER_BOOM_ACTIVATE_TICK:
			seen["boom_damage"] = hp_before_tick - ms.p2.hero.get_hp()
			seen["covers_after_boom"] = ms.p2.hand.cover_count()
		if t == COUNTER_BOOM_COUNTER_TICK:
			seen["boom_refund"] = ms.p2.hero.get_hp() - hp_before_tick
			seen["covers_after_boom_counter"] = ms.p2.hand.cover_count()
			seen["restored_slots"] = ms.p2.hand.covered_indices()
		if t == COUNTER_CULLING_ACTIVATE_TICK:
			seen["minions_after_culling"] = ms.p1.units.living_indices().size()
			seen["culling_mana"] = ms.p1.mana.get_current() - mana_before_tick
		if t == COUNTER_CULL_COUNTER_TICK:
			seen["minions_after_counter"] = ms.p1.units.living_indices().size()
			seen["culling_claw_back"] = mana_before_tick - ms.p1.mana.get_current()
	return {"state": ms, "record": record, "seen": seen}


func _counter_intents(ms: MatchState, t: int) -> Array[InputIntent]:
	var i1 := InputIntent.new()
	var i2 := InputIntent.new()
	if t == COUNTER_ATTACK_TICK:
		i1.pressed[&"attack"] = true
		i1.held[&"attack"] = true
		i2.pressed[&"attack"] = true
		i2.held[&"attack"] = true
	if t == COUNTER_CAST_TICK:
		_press_card(i1, ms.p1.hand.to_array().find(COUNTER_ROCK_CARD), Enums.ModeKind.BASIC)
	if t == COUNTER_BOOM_STAGE_TICK:
		_press_card(i1, ms.p1.hand.to_array().find(COUNTER_ROCK_CARD), Enums.ModeKind.PITCH)
	if t == COUNTER_SUMMON_ONE_TICK or t == COUNTER_SUMMON_TWO_TICK:
		_press_card(i1, ms.p1.hand.to_array().find(COUNTER_SUMMON_CARD), Enums.ModeKind.BASIC)
	if t == COUNTER_CULLING_STAGE_TICK:
		_press_card(i1, ms.p1.hand.to_array().find(COUNTER_SUMMON_CARD), Enums.ModeKind.PITCH)
	if t == COUNTER_BOOM_ACTIVATE_TICK or t == COUNTER_CULLING_ACTIVATE_TICK:
		i1.card_mode = Enums.ModeKind.PITCH
		i1.card_commit = true
		i1.card_activate = true
	# P2's two stages read an UNCOVERED Counterspell slot, live. A restored Boulder can sit on top of a
	# Counterspell card (the seeded plant picks any eligible slot), and a Mode (4) press on a covered slot
	# is refused by `REASON_COVERED_SLOT` -- so the slot is chosen from the VISIBLE layer rather than the
	# card layer. Sound for a replay because the chosen slot travels in the recorded intent rather than
	# being re-picked on the way back, exactly as the boulder run's own clear press does.
	if t == COUNTER_BOOM_COUNTER_STAGE_TICK or t == COUNTER_CULL_COUNTER_STAGE_TICK:
		_press_card(i2, _uncovered_slot_of(ms.p2.hand, COUNTER_COUNTER_CARD), Enums.ModeKind.PITCH)
	if t == COUNTER_BOOM_COUNTER_TICK or t == COUNTER_CULL_COUNTER_TICK:
		i2.card_mode = Enums.ModeKind.PITCH
		i2.card_commit = true
		i2.card_activate = true
	var out: Array[InputIntent] = [i1, i2]
	return out


## The first slot holding `id` in the CARD layer that nothing is covering -- see `_counter_intents`.
func _uncovered_slot_of(hand: Hand, id: StringName) -> int:
	var cards := hand.to_array()
	for index in cards.size():
		if cards[index] == id and not hand.is_covered(index):
			return index
	return -1


func _counter_config() -> BalanceConfig:
	var c := _config()
	c.deck_size = COUNTER_DECK.size()
	c.hand_size = COUNTER_DECK.size()
	c.melee_hit_mana = BOULDER_MELEE_MANA
	c.boulder_slow_per_boulder = BOULDER_SLOW_PER_BOULDER
	c.corpse_lifetime_seconds = 10.0
	return c


func _counter_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in COUNTER_DECK:
		var c := CardCastCondition.new()
		c.mana_cost = BOULDER_MANA_COST
		out[id] = c
	var boulder := CardCastCondition.new()
	boulder.mana_cost = BOULDER_MANA_COST
	out[COUNTER_PLANT_CARD] = boulder
	return out


func _counter_pitch_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in COUNTER_DECK:
		var c := CardCastCondition.new()
		c.mana_cost = BOULDER_PITCH_MANA_COST
		out[id] = c
	return out


func _counter_colors() -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	for id in COUNTER_DECK:
		out[id] = Enums.CardColor.RED
	out[COUNTER_PLANT_CARD] = Enums.CardColor.COLORLESS
	return out


func _counter_basic_effects() -> Dictionary[StringName, CardEffect]:
	var rocksling := CardEffect.new()
	rocksling.effect_id = &"rocksling"
	rocksling.cast_seconds = float(COUNTER_CAST_TICKS) / TimingWindow.TICK_HZ
	rocksling.damage_amount = BOULDER_STONE_DAMAGE
	rocksling.boulders_per_cast = COUNTER_STONES
	rocksling.boulder_interval_seconds = float(COUNTER_INTERVAL_TICKS) / TimingWindow.TICK_HZ
	rocksling.launch_speed = 8.0
	rocksling.homing_turn_rate_degrees_per_second = 120.0
	rocksling.max_speed = 8.0
	rocksling.travel_budget = 60.0
	var summon := CardEffect.new()
	summon.effect_id = &"summon_counter_run_minion"
	var counterspell := CardEffect.new()
	counterspell.effect_id = &"counterspell"
	var boulder := CardEffect.new()
	boulder.effect_id = &"boulder_discard"
	var out: Dictionary[StringName, CardEffect] = {}
	out[COUNTER_ROCK_CARD] = rocksling
	out[COUNTER_SUMMON_CARD] = summon
	out[COUNTER_COUNTER_CARD] = counterspell
	out[COUNTER_PLANT_CARD] = boulder
	return out


func _counter_pitch_effects() -> Dictionary[StringName, CardEffect]:
	var boom := CardEffect.new()
	boom.effect_id = &"boom"
	boom.damage_amount = BOOM_DAMAGE
	var culling := CardEffect.new()
	culling.effect_id = &"culling"
	culling.mana_per_kill = COUNTER_CULLING_MANA_PER_KILL
	culling.kill_cap = 99
	var counterspell := CardEffect.new()
	counterspell.effect_id = &"counterspell"
	var out: Dictionary[StringName, CardEffect] = {}
	out[COUNTER_ROCK_CARD] = boom
	out[COUNTER_SUMMON_CARD] = culling
	out[COUNTER_COUNTER_CARD] = counterspell
	return out
