---
baseline_commit: 3f6be78074348a44e72794f60b8cf187b6d9456f
---

# Story 6.6b: Color Counters

Status: ready-for-dev

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

- [ ] Author the eligibility span, the three per-colour busy durations, BLUE's travel distance
      (`BalanceConfig`, `BalanceTicks`, `.tres`, authoring audit); one reused window, no new hashed member.
      (AC 1, 2, 9, 15)
- [ ] Busy gate at the three seats: card seat, step-3 input edges, movement root; BLUE's travel branch with
      the press-time direction lock and zero-fact fallback; new refusal token. (AC 2, 9)
- [ ] Judgement at the CHARGING-arm seat with the step-3 capture and the commit-tick no-latch rule; teardown +
      attacker knockdown at the new fourth STUNNED entry point; remove the landing rung; `deflect_landed`
      emit. (AC 3-8)
- [ ] Replace the `5-5`/`5-6` landing-negation tests; add AC 3-8 tests incl. adjacent-at-commit, both-slots,
      boundaries in ticks, stunned/getting-up gap, feint, wrong colour (observable-half mutation proof);
      move `test_action_state.gd` pin 3 -> 4 with its argument; direction-bounds test for the busy numbers;
      the tests listed in AC 16. (AC 5, 7, 8, 16)
- [ ] Tool + import: four clips into `paladin_anims.res` (23 -> 27), measure strike frames, cut, slide
      planar pin; `test_rig_clips.gd` matrix; name and diff the full import collateral. (AC 13)
- [ ] `AnimationController` counter playback (RED sequence), runner edge read, dagger presentation node,
      spark reuse. (AC 10-12, 14)
- [ ] Measure golden both directions; suite before/after; live smoke on `[3, 3]`. (AC 16, 17)
- [ ] Commit chain: asset commit (untracked FBX + `assets/props/dagger/` incl. `ReadMe.txt`, which carries the
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

## Change Log

| Date | Change |
|---|---|
| 2026-09-20 | Story authored (`gds-create-story`, Sonnet 5) at baseline `3f6be78`; Status `authored`; awaiting operator review. |
| 2026-09-20 | Readiness gate round 1 findings B1-B4 + operator rulings: commit-tick ordering ruled (AC 3, no new state); three per-colour busy durations over one reused window (AC 2); BLUE state travel with zero-fact fallback (new AC 9); attacker knockdown as a new fourth STUNNED entry point (AC 4, AC 16); AC merges, Open Questions retired. |
| 2026-09-20 | Readiness gate round 2 READY; promoted to ready-for-dev; AC 3 ordering clause made explicit. |
