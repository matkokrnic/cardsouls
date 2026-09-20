---
baseline_commit: 3f6be78074348a44e72794f60b8cf187b6d9456f
---

# Story 6.6b: Color Counters

Status: review

## Story

As a player,
I want a card of the incoming unblockable's color, pressed in a short Sekiro-style window during the
attack's commit and launch, to make my hero visibly counter-move and knock the attacker out of the
air,
so that reading the telegraph and holding the right card is a timing skill with a legible payoff --
not a 1.5 s pre-arm that nothing on screen ever showed.

## Board note

Board key `6-6b-color-counters` already exists in `docs/implementation-artifacts/sprint-status.yaml`
(created on the `6-6` split, `6-6a` story "Board note"). It is `backlog # Tier A` and STAYS there
(project `gds-create-story` override: `authored` is a story-file value only). Only its `story_notes`
line and `last_updated` changed. Authored from the operator scope talk of 2026-09-17 and 2026-09-20
(rulings SETTLED -- restated below by content; numbers are assigned at close-out).

## Acceptance Criteria

**The press and the window**

1. Pressing card mode 3 with a card of color X consumes the card and spends `defense_stamina_cost`
   exactly as `5-5` does (`_resolve_defense_cast`, `match_state.gd:3350-3394`), and starts the ONE reused
   `PlayerState.defense_window` (with `defense_color`) at the COLOUR'S OWN busy tick count (AC 2). Inside
   that run, a SHORT counter-ELIGIBILITY span is read as elapsed ticks --
   `duration_ticks() - remaining_ticks() <= counter_eligibility_ticks` -- from a NEW authored value,
   provisional 0.3 s (18 ticks at 60 Hz). The `5-5` 1.5 s pre-arm value (`defense_window_seconds = 1.5`,
   `data/balance/balance_config.tres:150`) is superseded as a counter window (the supersession log entry is
   written at this story's close-out). The window expires silently when nothing answers it. Every existing
   refusal is unchanged: flag closed, CHARGING (`REASON_UNBLOCKABLE_COMMITTED`), STUNNED (`REASON_STUNNED`),
   empty slot, insufficient stamina. A press with a block held still drops the block (`5-5`,
   `match_state.gd:3395-3409`); a swing or roll in progress still finishes on its own contract (`5-5`'s
   existing tests at `test_unblockable_defense.gd` `test_rolling_blocking_and_attacking_heroes_may_all_defend`
   and siblings stay green).
2. THE PRESSER IS BUSY for the whole counter presentation, and busy = the window is running. THREE authored
   busy durations, one per colour, selected at the press from `defense_color`; provisional RED 1.5 s /
   BLUE 1.2 s / GREEN 0.7 s (fields `counter_busy_seconds_red/blue/green`, converted at the one
   `BalanceTicks` boundary). The presentation is mapped INTO the busy span, never the reverse (`6-1b`
   precedent: cut range plus playhead/speed): RED's jump-then-backflip sequence fits inside 1.5 s, GREEN
   starts from the 36-74 % cut of `counter_throw`, BLUE plays a run-up-cut `counter_slide`; the raw clip
   lengths stay measured data (Measured Fact 11). The numbers are feel knobs tuned at smoke and NEVER pinned
   by tests except the direction bounds `busy > eligibility > 0` per colour. While busy, every input
   (attack, roll, block, every card mode, unblockable initiation) is refused and the hero is rooted, exactly
   the `6-6a` get-up register (`HeroState.is_getting_up`, `hero_state.gd:303`; card seat gate
   `match_state.gd:2745`; movement root `match_state.gd:4085`), EXCEPT BLUE's authored travel (AC 9), which
   is state-driven, not input. Card presses announce a refusal with a new reason token naming the
   player-visible fact (the `REASON_GETTING_UP` convention, `match_state.gd:2961`); step-3 inputs drop
   silently, as they do during get-up and STUNNED. Busy is DERIVED FROM THE WINDOW -- no new `ActionState`
   (`6-6a`'s `is_getting_up()` precedent), and the standing pin
   `test_unblockable_defense.gd:268` (`test_the_cast_introduces_no_action_state_of_its_own`) must stay
   green. The `defense` snapshot key `[colour, remaining_ticks]`, its arity and its resting `[-1, 0]` are
   unchanged; only what `remaining` counts down changes (eligibility -> busy). Ticking stays the single
   step-2 line (`match_state.gd:552-553`). A missed counter's whole cost is the card, the stamina and this
   busy time.

**The judgement**

3. The counter is judged against the attacker's unblockable at the attacker's COMMIT tick and on every
   launch tick BEFORE the first honest contact (`6-1c` commit, `6-1d` contact latch). Measured seat: the
   CHARGING arm of `_resolve_actions` (`match_state.gd:1251-1258`), where the landing window is running and
   the chargeup window has stopped (`6-1c`). The counter lands iff, on a judged tick, ALL of: the
   defender's eligibility span is open; the window's colour equals the attacker's `charge_color` and neither
   is the `NO_TELEGRAPH_COLOR` sentinel (the `5-5` review-fix rule, `match_state.gd:3493-3500`, kept -- a
   degraded defense must never answer a degraded chargeup); the attacker's reach latch is not yet `INSIDE`
   (`_charge_reach`, `match_state.gd:1023-1033`); and the defender is alive, not STUNNED and not getting up
   (AC 7). ORDERING, ruled: the commit tick is judged BEFORE that tick's push is consulted -- an `INSIDE`
   present at the commit-tick judgement is DISCARDED (a defender already in reach at the commit tick can
   still be countered). Mechanism: the commit-tick judgement simply does not consult `_charge_reach`. That
   is sound because at that judgement any `INSIDE` is necessarily this tick's push (the cast seat clears the
   latch, `match_state.gd:3295-3296`; `push_contact` writes a verdict only inside the contact window and
   clears outside it, `:1023-1025`; the window's `remaining_ticks() <= 1` first reads true on the commit
   tick, `player_state.gd:327-328`), and it needs zero new state and no edit to `push_contact`. On every
   LATER launch tick the live latch read stands (a latch there means a contact has registered, whichever
   tick wrote it). Pinned by a test that has an adjacent attacker commit against an open matching window. The counter judgement runs BEFORE the landing resolution within the same CHARGING arm of `_resolve_actions` (`match_state.gd:1251-1258`, where `_resolve_charge_landing` is that arm's first branch), so a counter and a landing that fall on the same tick resolve as a counter.
4. THE COUNTER LANDS: the attack is torn down -- the `6-6a` CHARGING-abandonment form
   (`match_state.gd:3655-3661`): `charge_window` and `landing_window` stopped, `charge_color` reset, the card
   and stamina stay spent; the attacker leaves `CHARGING` by the knockdown write below in exactly one
   `set_action_state` call (no `IDLE` in between, the `5-6` one-write-per-outcome rule). THE ATTACKER IS
   KNOCKED DOWN via the existing knockdown PACKAGE (`stun.start(knockdown_stun_ticks)`, the
   `BalanceTicks.is_knockdown_stun` flavour classifier, the get-up lock and get-up iframes; no new stun kind,
   no new duration field) written at a NEW fourth authored STUNNED entry point at the attacker's own step-3
   seat, with no damage. It is not the `6-6a` seat: `_apply_landing_packages` writes the VICTIM at step 6b
   and applies damage unconditionally (`match_state.gd:3643-3662`); this writes the attacker's OWN hero, so
   the cross-player-write prohibition (`:334-347`) does not bite. The `already_down` floor rule does not
   apply (a CHARGING attacker is not down). The defender takes no damage, the attacker earns no orbs
   (`_grant_landing_orbs` never runs), and no `hit_landed` is emitted. The answered color is announced on
   the existing `deflect_landed(attacker_slot, target_slot, defense_color)` signal (`match_state.gd:76`).
5. TIMING FAILURES and the RETIRED LANDING RUNG. A window whose eligibility span ended before the commit
   (too early), or one opened after the first honest contact registered or after the landing (too late),
   leaves the attack to the `5-6` ladder untouched (reach -> dodge rung -> unanswered package). The card and
   stamina are spent regardless. The dodge rung stays the universal, card-less fallback. A WRONG-COLOUR
   press neither counters nor consumes anything (the `5-5` rule kept, now true by construction: nothing
   consumes the window, and 1v1 has one attacker that a success tears down and locks for 2.5 s knockdown +
   2.0333 s get-up). The mutation proof for it targets the OBSERVABLE half -- a later matching launch tick
   inside the eligibility span still counters -- not non-consumption. The `5-5` landing-tick negation rung
   (`match_state.gd:3541-3554`, including the attacker's `color_counter_stun_ticks` stun written there) no
   longer exists as a way to answer an unblockable: an eligible window on the landing tick with first
   contact already registered does NOT negate. The dodge rung and the unanswered-package tier below it are
   byte-untouched in behaviour. Two consequences follow from AC 3 as ruled and are recorded as decisions,
   not left to smoke: a correct press against an attack that would have MISSED (flying wide) still knocks
   the attacker down, and on the LANDING tick with no contact ever registered the counter lands rather than
   the attack whiffing (smoke items 5 and 12 confirm both live).

**Who can and cannot counter**

6. Counters answer ONLY the unblockable (mode 2). Ordinary melee keeps block / deflect / roll unchanged.
   Hold-to-charge and the paid feint (`6-1`) are UNTOUCHED: a feinted chargeup never reaches a judged tick
   past the release, so a counter pressed against it expires silently and the defender still pays the card,
   the stamina and the busy time -- the bait the counter presentation exists to make possible.
7. A defender that is STUNNED (colour-counter, deflect or knockdown flavour, lying on the floor included) or
   getting up can neither press mode 3 nor have a previously-armed window resolve. The measured gap:
   presses are already refused (`REASON_STUNNED`, `match_state.gd:3369`; `REASON_GETTING_UP` for all four
   modes, `match_state.gd:2745`), but an ALREADY-RUNNING window is deliberately left ticking through a stun
   (`match_state.gd:3360-3365`, pinned by `test_a_stun_does_not_disturb_an_already_running_defense_window`,
   which survives unedited: this AC changes RESOLUTION, not ticking) and the old rung read no defender-state
   at all (`match_state.gd:3541`). Closing that gap closes the `6-6a` deferred-work item "A downed hero keeps
   a defense window armed ... and can colour-counter while down" (`deferred-work.md`, "Deferred from: code
   review of 6-6a"). Tested: window armed, defender knocked down or deflect-stunned or getting up, attacker
   commits -> the counter does NOT land and the attack resolves on the `5-6` ladder.
8. SEAT SYMMETRY. The counter's inputs are read as captured at the START of step 3, the
   `_iframe_open_at_step3` shape (`match_state.gd:328`), per slot: window open + colour + eligibility + alive
   + not-STUNNED + not-getting-up, as they stood before either seat resolved. Without the capture, in the
   mutual case P1's seat would set P1 STUNNED and P2's seat would then see a stunned defender and refuse its
   own counter -- the outcome would be seat-dependent. Rule: both attackers are judged against the OTHER
   hero's captured facts, so if both heroes are committed and both hold a matching eligible window on the
   same tick, BOTH counters land and BOTH heroes are knocked down on that tick, regardless of which seat
   resolves first (the `6-6a` simultaneous-landing precedent). It is NOT a trade decided by seat order.
   Pinned by a both-slots test that arms the states by injection (DEVIATIONS 2: not reachable by real
   presses). Two further boundaries are pinned on BOTH slots identically: a press on the very tick of the
   commit is too late (card presses run at step 6, after step 3), and the last eligible tick / first
   ineligible tick are exact in ticks, on the `5-5` window's own start/tick convention.
9. BLUE TRAVELS AS STATE; RED AND GREEN DO NOT. BLUE's counter carries REAL defender travel toward the
   attacker as state, on the `1-9` `roll_direction` x distance precedent (velocity written inline in
   `_resolve_movement`, `match_state.gd:4046-4048`, from an authored distance over a time): authored
   distance, provisional 1.5 m spread over BLUE's busy span; direction locked at the press from the live
   charge-reach direction (`_charge_reach_dirs[attacker_slot]`, the hero-to-hero bearing pushed on every
   chargeup tick, `match_state.gd:969`, `:4189-4193`; NOT `_lock_directions`, which can legitimately point
   at a minion). The seat is a counter-busy movement branch sibling to the get-up branch (`:4085`), keyed on
   the window, with no new `ActionState`; RED and GREEN write zero velocity there (root fixed, mesh-only).
   The mesh Hips are planar-pinned for the slide via the existing `_pin_hips_planar` route
   (`tools/add_paladin_defense_reactions.gd`, `3-0b/R27`), so the body is carried by state and the clip
   contributes no second displacement. FALLBACK: when no attacker is charging at the press (early press, no
   live chargeup -- the reach direction rests at `Vector2.ZERO`, `match_state.gd:284`), travel is ZERO: the
   slide plays on the spot, planar-pinned; a counter that answers nothing also goes nowhere. What stops the
   travel is `HeroActor.drive()` / `move_and_slide()` (the attacker's collider, the 5-0d arena edge); state
   never learns a position (`4-3/R2` intact). The busy defender's hitbox never gathers anything (no swing
   window runs) -- asserted explicitly by the dev pass. A new snapshot KEY for the locked direction would be
   STOP-and-report class (Golden Prediction).

**Presentation** (mesh on the root; the one body travel is BLUE's, AC 9)

10. The counter presentation STARTS ON THE PRESS, not on the resolution, so a paid feint baits a full counter
    animation into nothing. RED plays `counter_jump` then `counter_backflip` as one sequence; BLUE plays
    `counter_slide`; GREEN plays `counter_throw` and the dagger prop. All are one-shots, cut and speed-mapped
    to fit the colour's busy span (AC 2). The runner reads the `defense` snapshot key `[colour, remaining]`
    per tick for the rising edge, the `on_charge_progress` call site's precedent (`match_runner.gd:865`);
    nothing new is added to the observation-seam family (AC 14).
11. GREEN's dagger (`assets/props/dagger/dagger.fbx` + the four PBR PNGs) flies from the defender to the
    attacker as PURE PRESENTATION: no state object, no hitbox, no board entry, no `push_contact`. The `4-4`
    totem projectile actor CANNOT be reused as measured -- `ProjectileActor` carries a gameplay `Hitbox`
    (`Area3D`), a runner-driven heading and a state-flagged liveness (`projectile_actor.tscn:20`, `:26`), and
    is spawned by the runner off the projectile board; the dagger is a separate plain `Node3D` visual that
    borrows only its "plain translation, no body" idea. It is launched at the throw clip's release frame and
    freed on arrival or on counter teardown; it never gates or changes an outcome.
12. The knocked-down attacker plays the existing `knockdown` / `get_up` reactions, chosen by the existing
    stun-flavour classifier (`BalanceTicks.is_knockdown_stun`, `balance_ticks.gd:160`;
    `_stun_flavor_for_slot`, `match_runner.gd`). The attacker's charge clip cuts straight to `knockdown` (the
    `6-6a` CHARGING-victim cut). No "knocked out of the air" clip and no per-counter fall variants
    (Non-Goal).
13. Import and library. The four `counter_*.fbx` clips are added to `paladin_anims.res` by extending a new
    tool on the `tools/add_paladin_defense_reactions.gd` route (extend, never rebuild; headless;
    `.fbx.import` sidecars matching `roll.fbx.import` `[params]`), library 23 -> 27 (`test_rig_clips.gd`
    matrix extended and mutation-proven; its count is derived from the dict, never a literal). Usable ranges
    are NOT trimmed in the files: the dev measures each clip's strike/impact frame with the existing tool
    (`tools/measure_strike_frame.gd`, the `6-1b` criterion) and cuts in Godot. Operator starting points, to be
    confirmed by measurement: `counter_throw` ~36%-74% of the clip; `counter_slide` has a run-up at the
    start. The Hips decision: `counter_slide` Hips planar-pinned via `_pin_hips_planar`, body carried by
    state (AC 9); `counter_jump`, `counter_backflip` and the cut `counter_throw` need no pin (Measured Fact
    11). Import collateral after EVERY editor session is named and diffed: the four `counter_*.fbx.import`
    sidecars, `dagger.fbx.import`, the four `dagger_*.png.import` sidecars and `project.godot`; `.godot/`
    (extracted textures) is git-ignored and not a commit concern.
14. LEGIBILITY WITHOUT A NEW SEAM. The runner's observation-seam family stays exactly TEN
    (`test_architecture_invariants.gd:339`, `OBSERVATION_SEAMS`; `connect_*` count re-measured: hero
    action-state, hit_landed, hero action-rejected, deflect_landed, pitch_changed, hp, stamina, mana, cards,
    orbs). What carries the counter: the press = the `defense` snapshot key (AC 10); success = the
    colour-carrying `deflect_landed` (already wired to `TelegraphController.on_deflect_landed`,
    `telegraph_controller.gd:240`, which tints its spark to the answered colour and plays on the DEFENDER --
    `target_slot == my_slot`); the attacker's fall = `action_state_changed` to STUNNED plus the flavour read.
    `deflect_landed` keeps TWO emit sites and the colour sentinel is what distinguishes them: the melee/unit
    parry (`match_state.gd:1818-1819`, `NO_TELEGRAPH_COLOR`, untinted cue) and the counter's coloured emit.
    If the dev pass finds any of these insufficient it STOPS: a seam is the operator's call.

**Reset, determinism, gates**

15. Reset/freeze coverage. The counter window (and busy, being the same window) is cleared by the debug
    reset and NOT by round-end, on the `5-5` fourth-exception shape; if the state design needs a member that
    is NOT the existing `defense_window`, it is an EIGHTH named exception (the seven now standing are
    enumerated in Measured Facts) and a hashed-member addition -- both are STOP-and-report class.
16. Gates. Golden `d437432f...` measured UNMOVED in both directions with the snapshot key-path set at 206
    and `RecordFile.FORMAT_VERSION` at 11 (see Golden Prediction); F1/D3(a)/D3(b)/A2 stay green untouched
    (standing suite contract). Suite before/after recorded. Tests that move, and why: MUST CHANGE
    `test_unblockable_defense.gd:952`
    (`...snapshot_key_reports_the_window_and_rests_at_the_sentinel`) and `:943`
    (`test_the_window_duration_converts_at_the_one_boundary`) -- new authored durations, per colour; the
    landing-rung removal (AC 5) moves `test_unblockable_defense.gd` `:383`, `:410`, `:424`, `:445`, `:481`,
    `:512`, `:537`, `:556`, `:590`, `:648`, `:1080` and `test_unblockable_hold.gd` `:209`, `:417`;
    `test_action_state.gd:144` (`test_stunned_has_exactly_three_authored_non_table_entry_points`, scanning
    all of `src/`, pinning `match_state.gd x3`) moves 3 -> 4 and is ARGUED, the way `6-6a` argued its third:
    a different subject (the attacker), a different seat (its own step 3), no damage. Tests that survive
    unedited: `:106`, `:121`/`:129`, `:268`, `:342`, `:356`/`:368`, `:722`/`:737`, `:925`,
    `test_card_observation.gd:287`, `test_draw_delay_and_reshuffle.gd:68`. The tests that encode the
    `5-5`/`5-6` landing-tick negation are REPLACED, not deleted, and each new negative test is proven
    non-vacuous by mutation (out-of-repo backup + SHA256 before mutating, restore by copy-back, never
    `git checkout`).
17. Live smoke, section below, run on `[3, 3]` with two pads; R-D6 (live smoke against a killable slot) is
    re-invoked on this gate.

## Non-Goals

Removing hold-to-charge or the feint (retune block); hitstun on ordinary hits (retune); knockdown/get-up
duration tuning (deferred N2); the `hit_react` layered blend (deferred N3); a "knocked out of the air"
attacker clip or per-counter fall variants (polish, judge at smoke); VFX; `6-5` spell resolution; any
reach/homing retune; three different counter MECHANICS (the three counters are mechanically identical --
only presentation, busy length and BLUE's travel differ); counters against ordinary melee.

## Measured Facts (citations verified against HEAD 3f6be78)

1. **5-5 window, where it lives.** `PlayerState.defense_window` (a `TimingWindow`, `player_state.gd:250`) and
   `defense_color` (`:254`). Snapshot key `defense = [colour, remaining_ticks]`, resting `[-1, 0]`
   (`player_state.gd:374-376`). Armed at `match_state.gd:3390-3394`; ticked at step 2 beside every D4 timer
   (`match_state.gd:552-553`); consumed today ONLY at `_resolve_charge_landing` (`:3541-3548`).
   `TimingWindow.duration_ticks()` already exists and is already read in state (`match_state.gd:3653`).
2. **What the 5-5 CHARGING refusal reuses.** `REASON_UNBLOCKABLE_COMMITTED` (`match_state.gd:3366-3368`); the
   STUNNED gate reuses `REASON_STUNNED` (`:3369-3371`). Both arms only PREVENT ARMING; an already-running window
   is untouched by design (`:3360-3365`).
3. **Commit tick, state-side.** The chargeup window ticks at step 2 (`match_state.gd:539`) and the landing
   window beside it (`:544`), so at step 3 the commit tick reads `charge_window` stopped + `landing_window`
   running, and the CHARGING arm's landing fires only when `landing_window` has stopped
   (`match_state.gd:1251-1258`).
4. **6-1d contact window.** `PlayerState.is_contact_window_open()` is
   `landing_window.is_running and charge_window.remaining_ticks() <= 1` (`player_state.gd:327-328`), so the
   COMMIT tick's own push (which arrives before that tick's `advance()`) is already inside the window and can
   latch `INSIDE`. `INSIDE` is absorbing (`match_state.gd:1004-1033`); the latch is cleared at the cast seat and
   in `_reset_player`. Consequence, resolved by ruling: the commit-tick judgement does not consult the latch
   (AC 3).
5. **6-6a knockdown seat.** Written on the VICTIM in `_apply_landing_packages` at step 6b, keyed off
   `_landing_package_pending`, damage applied unconditionally (`match_state.gd:3643-3662`); classifier
   `BalanceTicks.is_knockdown_stun(duration_ticks)` (`balance_ticks.gd:160-161`). The counter reuses the
   PACKAGE contents, not the seat: it writes the attacker's OWN hero at the attacker's own step-3 seat -- a new
   fourth `set_action_state(STUNNED)` call site -- so it is not the cross-player write the
   `_landing_package_pending` comment (`match_state.gd:334-347`) forbids. The floor rule (`already_down`,
   `:3652`) does not apply to a live CHARGING attacker. The CHARGING arm is the attacker's only step-3 work and
   `_resolve_movement` follows immediately, so the STUNNED movement branch (`:4070-4084`) roots it.
6. **R-CHARGING teardown fields.** `charge_window.start(0)`, `landing_window.start(0)`,
   `charge_color = NO_TELEGRAPH_COLOR` (`match_state.gd:3659-3661`, also `:1256-1258` and `_reset_player`).
   MEASURED: `landing_window` IS cleared by the existing teardown. `_charge_reach` / `_charge_contact_dirs`
   are deliberately NOT cleared there (`:3639-3640`, `6-1d/R9`); with `landing_window` stopped,
   `is_contact_window_open()` is false, so the very next push takes the clearing arm
   (`match_state.gd:1023-1025`) -- the contact bearing self-cleans one push later and the next cast seat resets
   it anyway (`:3296`).
7. **Reset/freeze -- the seven named exceptions** (`_apply_debug_reset` header, `match_state.gd:4531-4557`):
   (1) the unit board `4-1/R5`, (2) the chargeup `5-3`, (3) the orb pool `5-4`, (4) the defense window and
   colour `5-5`, (5) `stun` + STUNNED `5-6`, (6) the pitch zones `6-2`, (7) the get-up iframe `6-6a`. Step 1b
   returns before step 2's ticks, so a frozen window stays armed until the reset clears it. Reusing
   `defense_window` needs no eighth.
8. **Cast-seat refusals today.** DEAD returns silently (`match_state.gd:2734`); `REASON_GETTING_UP` for all four
   modes at one gate ahead of the dispatch (`:2745-2747`); mode 3 also refuses flag-closed, CHARGING, STUNNED,
   empty slot, insufficient stamina (`:3351-3378`). Gap: only armed-window resolution (AC 7).
9. **Golden fixture.** `test_determinism.gd` never casts mode 3 and no hero ever enters CHARGING (comments at
   `:699`, `:722`, `:895`, `:1042` `GOLDEN = "d437432f7823..."`); `RecordFile.FORMAT_VERSION = 11`
   (`src/systems/record_file.gd:195`); the 6-6a re-baseline set the key-path count to 206
   (`test_determinism.gd:1022`).
10. **Seam family.** Ten `connect_*` wrappers in `match_runner.gd` (lines 1053, 1067, 1075, 1085, 1098, 1733,
    1743, 1755, 1785, 1823); `6-6a` left it at ten; pinned by
    `test_runner_observation_seams_are_exactly_ten`. `deflect_landed` already carries the colour
    (`match_state.gd:76`) and `card_cast_resolved` carries nothing.
11. **Displacement and length of the four new clips (MEASURED, raw FBX Hips `Lcl Translation`, metres,
    first->last key; method reproduces `knockdown`'s recorded 0.5521 net / 0.6097 peak planar exactly, and
    was independently reproduced at the readiness gate):**

    | clip | len s | keys | net planar | peak planar | net Y | Y peak +/- | note |
    |---|---|---|---|---|---|---|---|
    | `counter_jump` | 0.8333 | 26 | 0.0000 | 0.0714 | 0.0000 | +0.675 / 0.000 | in place, jump arc only |
    | `counter_backflip` | 2.1667 | 66 | 0.0000 | 0.1719 | 0.0000 | +0.464 / -0.287 | in place; Hips pitch winds -360 deg over the clip |
    | `counter_slide` | 1.7667 | 54 | **4.3135** | **4.3135** | -0.0169 | 0.000 / -0.675 | run-up ~5 m/s to 0.4 s, then decelerating slide; 0.80-1.77 s alone still travels 0.98 (1.20-1.77: 0.52) |
    | `counter_throw` | 1.8333 | 56 | 0.3774 | 0.6476 | -0.1096 | 0.000 / -0.118 | inside the 36-74% cut (0.67-1.33 s): net 0.059, peak 0.108 |

    The `3-0b/R27` planar ceiling is 0.25 (`ROLL_HIPS_PLANAR_MAX`, per `tools/add_paladin_defense_reactions.gd`
    header). RED's raw sequence is 3.0 s and BLUE's slide 1.7667 s against busy spans of 1.5 s / 1.2 s
    (AC 2), so both are cut and speed-mapped; GREEN's cut (~0.67 s) fits 0.7 s. The backflip's -360 deg Hips
    pitch is continuous rotation: verify the imported track ends where it starts (quaternion track) rather
    than assume it.
12. **Authored numbers.** Chargeup 1.0 s; launch 0.25 / 0.30 / 0.45 s (R/B/G); knockdown 2.5 s; get-up
    iframes 2.0333 s; colour-counter stun 1.0 s (`balance_config.tres:127-144`). Launch is 15-27 ticks, so an
    18-tick eligibility span fits inside one launch and can straddle commit.
13. **Environment.** No `[3, 3]` today: `slot_controller_kinds` defaults to `[KEYBOARD_P1, KEYBOARD_P2]` in
    `match_runner.gd:31` and `main.tscn` overrides nothing (the root node carries only its script); the
    keyboard controller hardcodes `card_mode = BASIC` (`keyboard_controller.gd:177`), the gamepad controller
    carries the real mode (`gamepad_controller.gd:220-226`), so mode 3 and mode 2 both need pads.

## Golden Prediction

Predicted UNMOVED: golden `d437432f7823379c8992276f4061ca16161b156fe2a8a7eb732d9b9750262d56`, the 206-key
snapshot path set, and `FORMAT_VERSION` 11. Basis, in inverse form (what would have to be true for it to
move, and why it is not): the determinism fixture casts mode 1 only and never mode 3 or mode 2 (Measured
Fact 9), so the new judgement, the new authored durations, the busy gate and BLUE's displacement path are
UNREACHABLE from the golden's script (every path sits behind a mode-3 press the fixture never makes) -- the
`6-6a` cause-1 argument, applied again. New authored durations sit outside `GOVERNED_CLIPS` and cannot move
the golden (`BC/R3`, standing). FORMAT_VERSION stays because a mode-3 press is already an intent channel
(`InputIntent.card_mode`/`card_commit`, `gamepad_controller.gd:220-226`). The ONE way this prediction fails
is a NEW HASHED MEMBER or snapshot key: a per-tick unhashed latch (the `_iframe_open_at_step3` shape) does not
count, and the design adds no key (AC 2: one reused window, key meaning unchanged; AC 3: no new latch). Any
new hashed field is a NAMED EXCEPTION and a STOP-and-report for the dev pass. Measured both directions at the
dev pass, not assumed.

## Live Smoke (`[3, 3]`, two pads, second player)

Setup: flip `slot_controller_kinds = Array[int]([3, 3])` in `src/main/main.tscn` (root `Main` block) as a TEXT
edit with the editor closed; `git diff` after `add` and after the revert; the flip is never committed and
`project.godot` is diffed after every editor session. Each item names PASS/FAIL.

1. **RED / BLUE / GREEN, matching press in the window**: attacker drops mid-flight, defender takes no
   damage, no orb appears, `deflect_landed` cue tinted to the colour.
2. **Early press**: eligibility ends before commit -> card gone, full hit, orb granted.
3. **Late press**: pressed after first contact -> card gone, full hit.
4. **Wrong colour** passes through (a later correct launch tick inside the eligibility span still counters).
5. **Press against an attack that would miss** (attacker flying wide): the attacker is still knocked down
   (AC 5 consequence), judged as intended.
6. **Feint bait**: attacker feints (release during chargeup) after the defender presses; defender plays the
   full counter animation into nothing and is BUSY for it (no attack/roll/block/card).
7. **Downed defender**: knocked down / deflect-stunned / getting up with a window armed cannot counter.
8. **Dodge rung** still works with no card; ordinary melee, block and deflect regress clean.
9. **RED** two-clip sequence reads as jump then backflip inside its busy span (cut clean at the join); note
   the margin -- RED busy (provisional 1.5 s) against the attacker's 2.5 s knockdown + 2.0333 s get-up lock.
10. **BLUE** slide travels toward the attacker as state and reads as a slide, not a treadmill or a pop at clip
    end; **BLUE early press** (no live chargeup) slides on the spot with zero travel (AC 9).
11. **GREEN** dagger visibly flies defender -> attacker and the attacker is knocked down.
12. **Adjacent-at-commit and landing tick**: attacker starts a chargeup adjacent to the defender who holds a
    matching open window -> the counter lands at commit (AC 3 ordering); and a counter on the LANDING tick
    with no contact ever registered lands rather than the attack whiffing (AC 5).
13. fps stable through repeated counters.

## Dev-pass decision (no design content)

`color_counter_stun_seconds` after AC 5: nothing in the state layer reads `color_counter_stun_ticks` once the
landing rung is gone, but the `5-6`/`6-6a` ordering audit (`knockdown > color_counter > deflect`) still
asserts it. Keep the field and the audit untouched and note the orphan in Docs Debt; retiring it is a separate
call.

## Tasks / Subtasks

- [x] Author the eligibility span, the three per-colour busy durations, BLUE's travel distance
      (`BalanceConfig`, `BalanceTicks`, `.tres`, authoring audit); one reused window, no new hashed member.
      (AC 1, 2, 9, 15)
- [x] Busy gate at the three seats: card seat, step-3 input edges, movement root; BLUE's travel branch with
      the press-time direction lock and zero-fact fallback; new refusal token. (AC 2, 9)
- [x] Judgement at the CHARGING-arm seat with the step-3 capture and the commit-tick no-latch rule; teardown +
      attacker knockdown at the new fourth STUNNED entry point; remove the landing rung; `deflect_landed`
      emit. (AC 3-8)
- [x] Replace the `5-5`/`5-6` landing-negation tests; add AC 3-8 tests incl. adjacent-at-commit, both-slots,
      boundaries in ticks, stunned/getting-up gap, feint, wrong colour (observable-half mutation proof);
      move `test_action_state.gd` pin 3 -> 4 with its argument; direction-bounds test for the busy numbers;
      the tests listed in AC 16. (AC 5, 7, 8, 16)
- [x] Tool + import: four clips into `paladin_anims.res` (23 -> 27), measure strike frames, cut, slide
      planar pin; `test_rig_clips.gd` matrix; name and diff the full import collateral. (AC 13)
- [x] `AnimationController` counter playback (RED sequence), runner edge read, dagger presentation node,
      spark reuse. (AC 10-12, 14)
- [x] Measure golden both directions; suite before/after; live smoke on `[3, 3]`. (AC 16, 17)
- [x] Commit chain: asset commit (untracked FBX + `assets/props/dagger/` incl. `ReadMe.txt`, which carries the
      author credit, plus the generated sidecars) separate from code, code separate from docs.

## DEVIATIONS (from the skill and from the brief -- mandatory section)

1. **Skill**: no web research (engine is Godot 4.6.3, nothing external to look up); no subagents (per the
   brief); the story stays `authored`, the board entry stays `backlog # Tier A`, no import run and no Godot
   process started (the four clips were measured by a read-only binary parse of the raw FBX in Python, not
   through Godot; the parse reproduces `knockdown`'s recorded numbers).
2. **Brief, scope item 7**: "both heroes charging, both press a matching counter" is NOT reachable by real
   presses -- a CHARGING hero cannot cast mode 3 (`REASON_UNBLOCKABLE_COMMITTED`, `match_state.gd:3366`), and
   AC 2's busy gate refuses initiating a chargeup while a window runs. The rule is stated (AC 8) and the
   both-slots test arms the states by injection; the reachable near-simultaneous cases are pinned instead.
3. **Brief, scope item 3 vs the code**: "first contact registered" is tick-granular and the commit tick's push
   precedes its judgement -- resolved by ruling (AC 3): the commit tick is judged before that tick's push is
   consulted, at zero new state.
4. **GDD drift to correct at close-out (docs, not this pass)**: the ladder row "Correct color -> stun ~1s"
   becomes attacker knockdown; Mode 3 "must fire during the attacker's chargeup window" becomes "during the
   commit/launch window"; the GDD counter names (Red Headstomp, Blue Pseudo-Suriken intercept, Green
   Pseudo-Mikiri step-in) differ from the ruled clips (RED jump+backflip, BLUE slide, GREEN throw + dagger) --
   the ruling governs; `epics.md:234-237` gets the `6-8` close-out treatment.
5. **Tests expected to move** are enumerated in AC 16 from the readiness gate's blast-radius measurement,
   including `test_action_state.gd:144` (STUNNED entry points 3 -> 4, argued: different subject, different
   seat, no damage -- the shape `6-6a` used for its third). `test_contact_pipeline.gd` (integration,
   parametric, reads the authored `.tres`) is expected to need no edit. The exact edits stay with the dev
   pass.
6. **BLUE's locked direction** needs a stored value at the press; how it is stored (the `roll_direction`
   shape) is a dev-pass implementation choice, bounded by AC 9's STOP rule on any new snapshot key.

## Docs Debt

- Close-out: decision-log supersession entry (the `5-5` 1.5 s pre-arm window, the `5-6` landing-tick
  attacker stun); rulings numbered under the close-out convention; `deferred-work.md` "downed hero can
  colour-counter" item closed; GDD ladder table and Mode 3 text (DEVIATIONS 4); `epics.md` entry;
  `project-context.md` if the rule set moves.
- `color_counter_stun_seconds` orphan note (Dev-pass decision).

## Dev Agent Record

**Agent Model Used:** Opus 5 (operator-stated)

### Suite, golden and gates (MEASURED)

| | before | after |
|---|---|---|
| state harness | 897 tests, 0 failed, 7339 assertions | **909 tests, 0 failed, 7497 assertions** |
| integration | 65/65 PASS | **66/66 PASS** (`test_counter_reactions_live.gd` added) |
| golden | `d437432f7823379c…` | **`d437432f7823379c…` UNMOVED** |
| `RecordFile.FORMAT_VERSION` | 11 | **11** |
| snapshot key-path set | 206 | **206** |
| `UNHASHED_CROSS_TICK_MEMBERS` | 4 | **4** |

Exactly two full runs (`C:\dev\_66b-suite-before.txt`, `C:\dev\_66b-suite-after.txt`). The before run
was taken before any edit. Extra runs, each named: four interim state-harness runs during development
(`_66b-check1..4`), one parse-only `--check-only` per edited `src/` file, one targeted integration
sweep of the five clip/contact tests after the presentation landed, and fifteen mutation runs (below).

**Golden, measured both directions.** `test_state_matches_golden` is green in the before run and green
in the after run, against the same `GOLDEN` constant — no re-baseline, and none was needed. The
inverse-form argument the story predicted holds as written: the fixture casts mode 1 only and no hero
ever enters `CHARGING`, so the judgement, the four new authored durations, the busy gates and BLUE's
displacement all sit behind a mode-3 press the fixture never makes.

**Key set, measured structurally and confirmed by the hash.** `player_state.gd` and `hero_state.gd` are
not in the File List at all: no `to_snapshot()` anywhere was touched, so no key path can have moved —
and the 6-6a close-out's own argument applies unchanged (the hash is a function of the snapshot; a
changed key set cannot leave it fixed). `test_the_player_snapshot_key_set_is_exactly_the_expected_set`
survives unedited and green. `FORMAT_VERSION` stays 11: no intent channel was added.

**`UNHASHED_CROSS_TICK_MEMBERS` does not move.** Two members were classified, neither a new argument:
`_counter_travel_dirs` joins argument (c) as a FOURTH array (the `6-1d` `_charge_contact_dirs`
precedent — a copy of a runner-pushed spatial fact, restored on replay by replaying the pushes), and
`_counter_color_at_step3` classifies `PER_TICK` on `_iframe_open_at_step3`'s exact test. Arguments,
not arrays, is what the pin counts (`6-1d` precedent).

### DEVIATIONS measured against the story's own predictions

1. **The `STUNNED` entry-point pin stays at THREE, not 3 → 4** (AC 16 predicted a move).
   MEASURED: the retired landing rung (AC 5) took its own `set_action_state(STUNNED)` with it in the
   same pass, and the counter's arrived at a new seat — one site out, one site in. So the count is
   unchanged and only the ENUMERATION moves.
   `test_stunned_has_exactly_three_authored_non_table_entry_points` keeps its name and its number; its
   argument and its failure message are rewritten to describe a MOVE, in the shape 6-6a used for its
   third (different subject, different seat, no damage, still not a `TRANSITION_TABLE` edge). This is
   a weaker change than the story expected, not a stronger one: no fourth entry point was opened.
2. **Further blast radius beyond the gate's section-2 list**, all disclosed rather than absorbed:
   * `test_unblockable_defense.gd` `:82` and `:106` — assert the window's LENGTH, which is now the
     colour's busy span. Constant swap only.
   * `:368` `test_a_missing_colour_entry_degrades_to_the_sentinel` — the degraded cast now opens NO
     window (see decision D1). Its "the cast still resolved" assertion moves from the window to the
     discard, and two assertions are added for the ruled degrade.
   * `:824`/`:866`/`:891`/`:755`/`:784`/`:800` — six tests that produced their STUNNED hero through
     the retired landing rung. Each moves to `_kd_match()` + `_counter_run()`; every CLAIM is
     unchanged, because none of them is a test about the stun.
   * `test_unblockable_tracking_and_reach.gd`
     `test_the_colour_counter_still_answers_through_the_one_landing_seat` — not on the gate's list.
     The seat it names no longer exists. REPLACED (never deleted) by
     `test_a_counter_at_the_commit_beats_reach_and_beats_a_whiff_alike`, which is the natural home for
     AC 5's two RULED consequences: this is the only fixture that can express "the attack would have
     missed". That file's `_config` gains the two counter durations and its header's AC 6 line is
     corrected.
   * `test_data_resources.gd`, `test_balance_authoring.gd`, `test_replay_identity.gd`,
     `test_rig_clips.gd` — the four audit lists the five new authored fields, the two new members and
     the four new clips are owed to.
3. **`defense_window_seconds` is now an ORPHAN**, like `color_counter_stun_seconds` (the story's own
   Dev-pass decision). Nothing in `src/` reads it. It is KEPT authored and KEPT converted, and
   `test_authored_defense_values_are_positive_and_correctly_ordered` is left untouched and green —
   including its `> chargeup + longest_launch` relational bound, which is now a true statement about a
   field nothing consumes. Retiring the field and that bound is a separate call; recorded in Docs Debt.
4. **No STOP condition was reached.** No new snapshot key, no new hashed member, no eighth reset
   exception, no new observation seam, no AC found infeasible as written.

### Dev decisions (the four the story left open, plus one it did not)

**D1 — the degraded-colour busy span (not listed; decided and recorded).** `counter_busy_ticks_for`
answers ZERO for `NO_TELEGRAPH_COLOR`, on `unblockable_launch_ticks_for`'s shape. A colourless defense
can never counter anything (AC 3 excludes the sentinel on both sides) and has no presentation to be
busy for, so it opens no window at all: the card and the stamina are still spent and the `defense` key
reports its resting value, which is the truth about it. The two alternatives were both worse — a
substitute colour violates the `kind_at` refusal rule, and falling back to `defense_window_ticks`
would resurrect the superseded value as live behaviour on one path and make AC 1's supersession untrue.
Blast radius: `test_a_missing_colour_entry_degrades_to_the_sentinel`, disclosed above.

**D2 — BLUE's direction storage.** `_counter_travel_dirs`, a two-element `Array[Vector2]` on
`MatchState`, written at the press and read by the movement branch. NO SNAPSHOT KEY, so the story's
STOP rule is not triggered: it is a COPY of `_charge_reach_dirs`, which is itself excluded from
`to_snapshot()` as a runner-pushed fact restored on replay by replaying the pushes — exactly what
`_charge_contact_dirs` already is (`6-1d/R8`). The alternatives were a new hashed member (STOP class)
or reusing `hero.roll_direction` (which a concurrent roll would corrupt — AC 1 lets a ROLLING hero
cast).

**D3 — the busy refusal token.** `REASON_COUNTERING := &"countering"`, minted in `match_state.gd`
beside `REASON_GETTING_UP` and for its stated reason: the token names the player-visible fact, and a
countering hero is neither stunned nor getting up. Raised at ONE seat ahead of the mode dispatch, so
all four modes refuse identically.

**D4 — how the clips are cut and mapped.** A single per-colour table,
`AnimationController._COUNTER_PRESENTATION`, of ordered `{clip, from, to}` steps in the clip's own
native seconds, plus `COUNTER_DAGGER_RELEASE_FRACTION`. NOTHING there names a duration: the shared
playback rate is DERIVED from the total cut length against the colour's authored busy span
(`counter_clip_speed`, never slower than native — the 6-6a `held_clip_speed` rule). So the
presentation is mapped INTO the busy span and a `.tres` retune re-fits the clips with no code edit,
which is AC 2's requirement. The clips go into the library RAW and UNCUT (AC 13).

**D5 — the dagger's node shape.** `src/actors/props/dagger_actor.gd`, a `class_name DaggerActor`
extending `Node3D` with the imported model as its only child and a straight-line `advance()`. A SCRIPT
and no `.tscn`: the totem/projectile precedent is a scene because those actors compose a body, a
collision shape and a hurtbox a designer edits, and this one composes nothing. A scene file would be an
empty wrapper with a uid to maintain, and it would invite exactly the `Hitbox` AC 11 forbids being
added "just like the others". No `_physics_process` (F1): the runner advances it.

### Measured facts produced by this pass

**Import and library (AC 13).** `project.godot` SHA-256 `252ef7e9…640e` before the headless editor
scan and **byte-identical after it** — zero collateral, both scans. The four `counter_*.fbx.import`
sidecars generated with `[params]` VERIFIED IDENTICAL to `roll.fbx.import`. `dagger.fbx.import` and
the four `dagger_*.png.import` sidecars generated; extracted textures landed in git-ignored `.godot/`
and are not a commit concern. Library **23 → 27**.

**The backflip's -360° Hips winding, VERIFIED not assumed** (the story required this): the imported
quaternion track's first→last key angle is **0.0000°** for both `counter_jump` and `counter_backflip`
— a full revolution is not representable on a quaternion track and does not survive import. Residuals
on the other two are bounded and inside a one-shot (`counter_slide` 13.14°, `counter_throw` 9.36°),
the same class 6-6a accepted for `knockdown`/`get_up`. No yaw neutralisation on any of the four.

**Hips planar pin (AC 9/AC 13).** `counter_slide` ONLY, 50 position keys pinned via `_pin_hips_planar`
— its raw 4.3135 m of planar travel is seventeen times the `3-0b/R27` ceiling and BLUE's body is
carried by STATE, so the clip must not move it twice. The other three are inside the ceiling and are
left as authored.

**Impact frames (`tools/measure_counter_strike_frames.gd`, the 6-1b criterion).**

| clip | len s | hand reach max | peak speed | read |
|---|---|---|---|---|
| `counter_jump` | 0.8333 | 0.7917 @ 0.3646 | 2.6445 @ 0.6458 | Hips apex 1.531 @ 0.406; a complete in-place jump, no cut |
| `counter_backflip` | 2.1667 | 1.0592 @ 0.7042 | 5.1054 @ 0.5146 | flip completes ~1.90; last 0.27 s is a static hold, cut there |
| `counter_slide` | 1.7667 | 1.0125 @ 0.3312 | 5.1939 @ 0.0442 | Hips 0.892 → 0.218 between 0.265 and 0.574; cut at 0.3533, drop committed, no run stride left |
| `counter_throw` | 1.8333 | **0.9679 @ 0.6646** | 4.1861 @ 0.7563 | the reach peak IS the RELEASE (the retraction right after is the clip's peak speed) — 36.25 % of the clip, which CONFIRMS the operator's ~36 % starting point by measurement |

**The cut table that follows, and the rates it derives** (all NAMED, editable constants in
`AnimationController._COUNTER_PRESENTATION`; no test pins a value):

| colour | steps (cut s) | cut total | busy span | derived rate |
|---|---|---|---|---|
| RED | `counter_jump` [0, 0.8333] then `counter_backflip` [0, 1.9000] | 2.7333 | 1.5 | 1.822 |
| BLUE | `counter_slide` [0.3533, 1.7667] | 1.4134 | 1.2 | 1.178 |
| GREEN | `counter_throw` [0.6646, 1.3444] | 0.6798 | 0.7 | 1.000 (floored; holds the last cut frame 0.02 s) |

GREEN's dagger release offset is **0.0 s into the busy span** — the measured release frame IS the
cut's first frame, so the throw reads as instant, which a 0.7 s counter needs.

**Where the feel knobs live** (operator, for the smoke):
* the three busy spans, the eligibility span and BLUE's travel distance —
  `data/balance/balance_config.tres` (a one-line `.tres` edit; NO test edit and NO golden re-baseline,
  `BC/R3` standing, and the only thing pinned is the direction `busy > eligibility > 0`);
* the per-colour cut ranges, the shared-rate rule and the dagger release fraction —
  `AnimationController._COUNTER_PRESENTATION` / `counter_clip_speed` /
  `COUNTER_DAGGER_RELEASE_FRACTION`;
* the dagger's flight height — `match_runner.DAGGER_THROW_HEIGHT`.

### Mutation table (MEASURED this pass; every restore by copy-back + SHA-256, never `git checkout`)

Driver, backups and the raw log are outside the repo (`C:\dev\_66b-mut\`, `C:\dev\_66b-mutations*.txt`).
Every target was SHA-256'd before the edit and the restored file's SHA-256 verified equal afterwards.

| # | mutation | went RED |
|---|---|---|
| M1 | delete the counter's `set_action_state(STUNNED)` | 17 tests, incl. `…knocks_the_attacker_down_and_only_the_attacker` |
| M2 | consult `_charge_reach` on the commit tick too | 18, incl. `…adjacent_at_the_commit_is_still_countered` |
| M3 | drop the eligibility check | 2: `…eligibility_span_has_closed_counters_nothing`, `…boundary_is_exact_and_identical_on_both_slots` |
| M4 | read the defender LIVE instead of from the step-3 capture | 1: `test_both_counters_land_on_one_tick_regardless_of_seat_order` (and ONLY that one — the seat-symmetry pin is exact) |
| M5 | drop the colour comparison | 3, incl. `test_only_a_matching_colour_counters` |
| M6 | drop the STUNNED / getting-up defender gates | 1: `test_a_downed_or_getting_up_defender_cannot_counter` |
| M7 | make the counter CONSUME the window | 4, incl. `…later_judged_tick_inside_the_eligibility_span_still_counters` |
| M8 | remove the busy gate at the card seat | 1: `test_every_intent_is_refused_while_the_hero_is_countering` |
| M9 | remove the busy gate at the step-3 edges | 2, incl. `…input_is_accepted_on_the_first_tick_after_the_counter_window_expires` |
| M10 | remove the counter-busy movement branch | 3, incl. `test_blue_travels_toward_the_attacker_and_red_and_green_do_not` |
| M11 | read BLUE's bearing LIVE instead of from the press-time lock | 1: `test_blues_bearing_is_locked_at_the_press_and_never_re_read` |
| M12 | make the sentinel busy span fall back to `defense_window_ticks` | 2, incl. `…durations_convert_at_the_one_boundary` |
| M13 | drop `counter_slide` from the rig-clip matrix | `test_rig_clips.gd` FAIL |
| M14 | unwire `_push_counter_presentation()` from the runner tick | `test_counter_reactions_live.gd` FAIL |

**M11 FIRST CAME BACK VACUOUS, and that is recorded rather than quietly fixed.** The first draft of
the lock test asserted the travel survived the attacker's teardown, reasoning that `push_contact`'s
clearing arm zeroes the bearing. MEASURED: `_charge_reach_dirs` is written on EVERY push,
unconditionally, AHEAD of the contact-window check — only `_charge_reach` and `_charge_contact_dirs`
are cleared there. So a live read held the same value and the test passed under the mutation. The test
was rewritten to push a MOVED bearing after the press (the attacker circling), which is what actually
falsifies a live read; M11 then went RED. `Invariant.check` is nowhere proven by triggering it.

### Explicit assertions the story asked for by name

* **The busy defender's hitbox gathers nothing** (AC 9): a counter starts no `active` window and the
  busy gate refuses every new attack press, so `is_hitbox_active()` is never true for a countering
  hero that was not ALREADY mid-swing — and for that one case AC 1 requires the swing to finish on its
  own contract, which `test_a_swing_in_progress_finishes_across_the_busy_span` pins directly (it
  observes the `active` phase running INSIDE the busy span, which is the honest statement: the lock is
  on new presses, not on a swing already sold).
* **The seam family is still TEN**: `test_runner_observation_seams_are_exactly_ten` green, unedited.
  The press rides the `defense` snapshot key, success rides the colour-carrying `deflect_landed`
  (which keeps TWO emit sites, told apart by the colour sentinel), the fall rides
  `action_state_changed` plus the flavour read.
* **F1 / D3(a) / D3(b) / A2**: green, untouched. The new `DaggerActor` has no `_physics_process`; the
  runner advances it from the one existing loop.

### Live Smoke

NOT RUN — the operator's, on `[3, 3]` with two pads. Its checkboxes are deliberately left unchecked.

## File List

**Assets (new, untracked before this pass)**
- `assets/characters/paladin/counter_jump.fbx` (+ `.import`)
- `assets/characters/paladin/counter_backflip.fbx` (+ `.import`)
- `assets/characters/paladin/counter_slide.fbx` (+ `.import`)
- `assets/characters/paladin/counter_throw.fbx` (+ `.import`)
- `assets/props/dagger/dagger.fbx` (+ `.import`), `dagger_BaseColor.png`, `dagger_Metallic.png`,
  `dagger_Normal.png`, `dagger_Roughness.png` (+ their four `.import`s), `ReadMe.txt`
- `assets/characters/paladin/paladin_anims.res` (modified: 23 -> 27 clips)
- `tools/add_paladin_counter_clips.gd` (+ `.uid`) — new
- `tools/measure_counter_strike_frames.gd` (+ `.uid`) — new

**State**
- `src/state/match_state.gd`
- `src/state/resources/balance_config.gd`
- `src/state/timing/balance_ticks.gd`
- `data/balance/balance_config.tres`

**State tests**
- `test/state/test_unblockable_defense.gd`
- `test/state/test_unblockable_hold.gd`
- `test/state/test_unblockable_tracking_and_reach.gd`
- `test/state/test_action_state.gd`
- `test/state/test_balance_authoring.gd`
- `test/state/test_data_resources.gd`
- `test/state/test_replay_identity.gd`

**Presentation**
- `src/actors/hero/animation_controller.gd`
- `src/actors/props/dagger_actor.gd` (+ `.uid`) — new
- `src/main/match_runner.gd`

**Integration tests**
- `test/integration/test_counter_reactions_live.gd` (+ `.uid`) — new
- `test/integration/test_rig_clips.gd`


## Code Review Record

Ran 2026-09-20 over `0ea7183..9d30ee8` (`PROC/R2` form: Blind Hunter + Edge Case Hunter in parallel,
Acceptance Auditor inline). Full report: `C:\dev\_66b-review.md`. Verdict **APPROVE WITH FINDINGS**.

**Fixed by the review** (commit `d202265`, `fix(state)`, each mutation-proven, suite
909/0/7497 + 66 -> **911/0/7518 + 66**, golden `d437432f` UNMOVED and no gate moved):

- **H1 -- AC 9's zero-travel fallback was false in live play.** `_charge_reach_dirs` is written on
  every push and cleared NOWHERE, so its `Vector2.ZERO` rest holds only until the first chargeup of
  the process; an early BLUE press afterwards slid the defender along a stale bearing. The press now
  gates on the other hero actually being `CHARGING`. The two existing BLUE-travel fixtures had no
  live chargeup at the press either (the bare P1 intent feints at step 3, before step 6 arms the
  window) and were passing off the same stale store -- both corrected and now assert `CHARGING` at
  the press.
- **H2 -- the counter-busy movement branch preempted `ATTACKING`.** Its own comment claimed ROLLING
  and ATTACKING both won from above; ATTACKING is not a branch above but lives in the `else` arm
  with the phase multiplier and the `3-0b` lunge, so a swing that cast DEFENSE mid-flight kept its
  windows and lost its whole velocity -- AC 1's "finishes on its own contract" broken in its
  movement half. Now excluded in the branch's own condition.
- Comment/doc corrections in place: the `_counter_travel_dirs` sign claim, the branch's
  co-occurrence argument, the live test's "the dagger is released" header claim, a doc reference to
  a helper never written, and a stray UTF-8 BOM (the only one in the repo).

**Not fixed -- carried to the operator** (full argument in the report):

| # | finding | disposition |
|---|---|---|
| P1 | any `action_state` transition or `on_hit_landed` during the busy span kills the counter presentation permanently (`_counter_index = -1`, nothing re-arms); mid-swing/mid-roll it never advances at all, because `on_locomotion` returns before the cut enforcement when the state is not `IDLE` | operator ruling + smoke: what the body should do when a transition interrupts a counter is a design call |
| P2 | a counter re-cast on the window's LAST tick produces neither a rising nor a falling edge (step 2 stops the window, step 6 restarts it, the runner polls once), so the previous colour's paused frame is held for the new span | operator ruling; presentation only |
| P3 | a counter cast from `BLOCKING` is destroyed on the frame it starts -- the queued `IDLE` drains AFTER the presentation poll | same class as P1 |
| P4 | `_push_counter_presentation` builds two full `to_snapshot()` dictionaries per tick to read one key; the precedent it cites (`_push_charge_progress`) reads the fields directly | AC 10 names the snapshot key, so the cheaper read is the operator's call |
| P5 | `COUNTER_DAGGER_RELEASE_FRACTION` only shortens the flight; it never delays the spawn. Latent -- correct only because it is `0.0` today | accept as note; retuning it breaks AC 11's stated contract |
| P6 | the busy lock is not applied at the lock/retarget seat (`_resolve_lock`, step 1c), so a "takes no input" hero can still re-aim mid-counter | operator ruling against AC 2's "every input" |
| P7 | AC 16 predicted the `STUNNED` pin would move 3 -> 4; it stays at THREE because the retired landing rung took its own site. Independently re-grepped: exactly three sites, the rewritten argument matches | **accept as a docs amendment at close-out**; AC 4's word "fourth" is what needs correcting, not the code |
| P8 | `defense_window_seconds` is an orphan whose relational authoring bound now describes a field nothing consumes | already in Docs Debt; retire at close-out with `color_counter_stun_seconds` |

**Evidence re-derived by the review, not taken on report:** the before-claim suite (909/0/7497 + 66,
reproduced exactly); mutations M2, M4 and M11 re-run by hand with out-of-repo backups and SHA-256
verified copy-back restores (M2 17 RED incl. the adjacent-at-commit pin -- the record says 18; M4
exactly 1, the seat-symmetry pin; M11 exactly 1, the corrected bearing-lock pin); the five
`.import` sidecars' `[params]` blocks byte-identical to `roll.fbx.import`; `project.godot` absent
from the diff entirely; the File List complete against `git diff --name-only`; AC text unedited.

### Post-review fix pass (2026-09-20, `d9f4512`)

Operator rulings R-P1/P3, R-P2, R-P4 and R-P6 applied over the review's carried findings. Story AC and
Dev Notes text is UNCHANGED; three items are recorded for the close-out amendment instead. Status stays
`review`, board untouched, Live Smoke checkboxes still unchecked, nothing pushed.

| | before (`C:\dev\_66b-fix-suite-before-*.txt`) | after (`C:\dev\_66b-fix-suite-after-*.txt`) |
|---|---|---|
| state harness | **911 tests, 0 failed, 7518 assertions** | **911 / 0 / 7518**, RESULT: PASS |
| integration | **66/66 PASS** | **66/66 PASS** |

The before-claim run was taken BEFORE any edit and reproduces the review commit's numbers exactly. Gates
re-measured on the after run, none moved: golden `d437432f…` (`test_state_matches_golden` `[ok]`;
`test_determinism.gd` is not in the diff, and the inverse-form argument is untouched -- the fix is
presentation-only and no fixture casts mode 3), `FORMAT_VERSION` 11, the 206-key set
(`test_the_player_snapshot_key_set_is_exactly_the_expected_set` `[ok]`; `player_state.gd` not in the
diff), `UNHASHED_CROSS_TICK_MEMBERS` 4, observation seams TEN, the `STUNNED` pin at THREE, F1 re-scanned
by hand (`func _physics_process` appears exactly once in `src/`, in `match_runner.gd`). Extra runs, each
named: four mutation runs (below) and ONE re-run of the live test alone after a comment-only repair to a
header paragraph my first edit had split mid-sentence.

**The mechanism chosen, per ruling.**

* **R-P1/P3 -- the span is now a fact the controller keeps, and the clip is a separate one.**
  `_counter_running` is armed on the press and cleared ONLY by the falling edge the runner pushes;
  `_counter_index` means "a counter clip is playing right now" and nothing more. A transition therefore
  clears the clip and leaves the span, which is what makes (a)-(d) fall out of one change rather than
  four special cases. (a) `on_hit_landed`'s IDLE arm returns early while the span runs, so no
  `hit_react` -- and the frozen/skipped-join defect the review found goes with it, since that came from
  restarting a clip WITHOUT clearing the index. (b) the IDLE branch of `on_action_state_changed` calls
  the new `_resume_counter()`, which spends `elapsed * rate` seconds of CUT across the step list in
  order and seeks there, so a resumed RED rejoins at the backflip rather than restarting at the jump.
  (c) STUNNED and DEAD return before that branch and still win outright. (d) `on_counter_started` arms
  but only PLAYS when the mirrored state is IDLE, so a swing, roll or held block keeps its own clip.
  **What feeds the resume**: a new per-tick `on_counter_progress(elapsed_seconds)` push from the
  EXISTING poll, `on_charge_progress`'s shape exactly -- a plain float, no window handle, no balance
  read, no `connect_*`. The seam family is unmoved at TEN and pinned green.
  **One recorded consequence**: the get-up one-shot is seated AHEAD of the resume, because a get-up is
  the tail of a knockdown that ruling (c) already let win. With the authored numbers it is unreachable
  (the 2.5 s knockdown outlasts the 1.5 s longest span, so the falling edge has already fired).
* **R-P2 -- the restart is detected, not the edge.** The runner keeps the colour and the remaining
  count the key carried last tick; a re-cast is `colour changed OR remaining rose` (a window otherwise
  counts down monotonically, so only a fresh `start()` can raise it). The old presentation is ended and
  its dagger freed, then the new one starts -- the falling-then-rising semantics the ruling asked for,
  produced without a second poll.
* **R-P4 -- the two `to_snapshot()` builds are gone**, replaced by `defense_window.is_running`,
  `defense_color` and `remaining_ticks()`, which is what `player_state.gd` builds the key FROM (resting
  value included). No observable change; the live test is the pin.
* **R-P6 -- MEASURED FIRST, and the measurement answers it: NO CODE.** `_resolve_lock` (step 1c) and
  `_is_applicable_retarget`/`_validate_lock` carry NO `is_getting_up()` gate -- the get-up lock lives
  at step 3 (`match_state.gd:1372`) and refuses the input-driven table edges only, never lock/retarget.
  So by the parity the ruling sets, the busy lock does not gate that seat either, and `src/state/` is
  untouched by this pass (the `fix(state)` commit is skipped). **Close-out item: AC 2's "every input"
  is amended to "every input the get-up lock refuses".**

**Mutation table** (driver `<scratchpad>/fixmut.py`; backup OUTSIDE the repo in `C:\dev\_66b-fix-mut\`,
anchor count asserted `== 1`, restore by COPY-BACK with the restored SHA-256 verified EQUAL, never
`git checkout`). All four are pinned by the extended live test.

| # | mutation (the fix reverted) | went RED |
|---|---|---|
| MF1 | drop the IDLE-branch resume | 3 rows: the BLOCKING-drop cast, the mid-swing resume, the hit |
| MF2 | drop `on_hit_landed`'s countering guard | 1 row: the counter loses the body to the flinch |
| MF3 | `restarted := false` (the re-cast is invisible again) | 2 rows: RED never starts, the dagger is not freed |
| MF4 | let `on_counter_started` play regardless of state | 1 row: the counter played over the swing |

Restores verified: `animation_controller.gd`
`c9e542b7a9f88b4235c4f735335215bb4414cd788661aa3cca0bf0b1dc175142`, `match_runner.gd`
`150e878ad762fce65c386b6dc78edb1a2a17f8722873b5c1c1c085e58d8482b8`. `Invariant.check` is nowhere proven
by triggering.

**MF4 first came back GREEN, and the FIXTURE was corrected rather than the claim dropped.** The first
draft of phase 6 armed the counter in the SAME frame as `enter_attack`, so the rising edge reached the
controller while its mirrored state was still IDLE and the `attack` clip won simply by arriving second
-- which proves nothing about a counter pressed mid-swing. The cast now happens a few frames INTO the
swing, with `attack` asserted as the setup precondition; MF4 then went RED.

**Close-out items carried out of this pass** (docs only, no code owed):
1. AC 2's "every input ... is refused" becomes "every input the get-up lock refuses" (R-P6, measured).
2. AC 4's "a NEW fourth authored STUNNED entry point" -> the pin stays at THREE (review P7).
3. `defense_window_seconds` retired beside `color_counter_stun_seconds`, with the relational bound in
   `test_authored_defense_values_are_positive_and_correctly_ordered` (review P8).
4. AC 10's wording names the `defense` snapshot KEY as the fact the runner observes, not as the API it
   reads it through (R-P4) -- the runner now reads the three fields the key is built from.
5. Review P5 stands as a note: `COUNTER_DAGGER_RELEASE_FRACTION` shortens the flight and never delays
   the spawn; correct only while it is `0.0`.

## Change Log

| Date | Change |
|---|---|
| 2026-09-20 | Story authored (`gds-create-story`, Sonnet 5) at baseline `3f6be78`; Status `authored`; awaiting operator review. |
| 2026-09-20 | Readiness gate round 1 findings B1-B4 + operator rulings: commit-tick ordering ruled (AC 3, no new state); three per-colour busy durations over one reused window (AC 2); BLUE state travel with zero-fact fallback (new AC 9); attacker knockdown as a new fourth STUNNED entry point (AC 4, AC 16); AC merges, Open Questions retired. |
| 2026-09-20 | Readiness gate round 2 READY; promoted to ready-for-dev; AC 3 ordering clause made explicit. |
| 2026-09-20 | Dev pass complete (Opus 5). All ACs implemented; suite 897/0/7339 + 65 -> 909/0/7497 + 66; golden `d437432f` MEASURED UNMOVED both directions, no re-baseline; FORMAT_VERSION 11, 206-key set and `UNHASHED_CROSS_TICK_MEMBERS` 4 all unmoved; library 23 -> 27 with zero `project.godot` collateral; 14 mutations measured RED (M11 first came back vacuous and its test was corrected). DEVIATION: the `STUNNED` entry-point pin stays at THREE, not 3 -> 4 -- the retired landing rung took its own site with it, so the count holds and only the argument moves. Status -> review. |
| 2026-09-20 | Code review (`gds-code-review`, `PROC/R2` three layers) over `0ea7183..9d30ee8`: APPROVE WITH FINDINGS. Two state-layer defects fixed in `d202265` (H1 stale charge-reach bearing broke AC 9's zero-travel fallback and two fixtures were passing off the stale store; H2 the counter-busy movement branch preempted `ATTACKING` and ate the swing's lunge against AC 1), each mutation-proven; suite 909/0/7497 + 66 -> 911/0/7518 + 66, golden `d437432f` UNMOVED, no gate moved. Six presentation/seat findings and two docs amendments carried to the operator (Code Review Record above). |
| 2026-09-20 | Post-review fix pass (`d9f4512`, `fix(presentation)`): operator rulings R-P1/P3 (the counter owns the body for the whole busy span -- the span survives transitions, an action borrows the body, IDLE resumes at the elapsed point, no `hit_react` over a counter), R-P2 (a re-cast with no falling edge is detected as a new press) and R-P4 (the poll reads the `defense` key's three fields directly). R-P6 MEASURED to need no code: the get-up lock does not refuse lock/retarget either, so `src/state/` is untouched and the `fix(state)` commit was skipped. Suite 911/0/7518 + 66 before and after; golden `d437432f` UNMOVED and no gate moved; four mutations RED. Five close-out docs items recorded. Status stays `review`. |
