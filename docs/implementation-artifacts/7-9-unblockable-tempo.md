---
baseline_commit: 0a04558eca15c4e39e473cfb82b5e80bdb562c7a
---

# Story 7.9: Unblockable tempo

Status: review

Tier **A** (touches `src/state/`: the cast seats, the counter judgement, the contact seat, the facing/launch movement, a new
hashed window). Authored 2026-10-08 against HEAD == origin/main == `0a04558`, tree clean, no godot process (verified this
session). Rulings R1..R7 below are the operator's of 7.-8.10.2026, R8..R18 the readiness-gate rulings of 8.10.2026; all are
logged as `7-9/R1..R18` in decision-log session "7-9 readiness gate + fixes (2026-10-08)" (gate report `C:\dev\_7-9-gate.md`).
Numbers marked TEMP are authored placeholders that 7-7 tunes.

## Story

As the defender of an unblockable, I want a knockdown to be followed by a breather, a counter to demand a read and a
well-timed press, and the attack to follow me the way Genichiro's does, so that escaping is earned, not free.
As the attacker, I want the attack to cost something, so that I think before I click it.

## Operator rulings (settled 7.-8.10.2026)

- **R1 Knockdown loop.** After a knocked-down hero has stood up (after the 7-8 getting-up iframes) they are immune to
  unblockables for 1.5 s (TEMP): an unblockable touching them in that span passes through, no damage, no knockdown. Melee and
  every other damage source hit normally. Casting an unblockable is NEVER refused because the target is immune; nothing refunded.
- **R2 Price.** An unblockable costs 1 mana on top of its stamina, charged at the click. Not enough mana = refused exactly like
  any other unaffordable action, nothing spent. A countered, missed or immune-blocked unblockable refunds nothing. Damage 9 -> 6
  (TEMP; 7-7 decides 5 or 6).
- **R3 Steering after launch.** Once the attack leaves its charge it keeps turning toward the defender until contact, travel
  direction and facing both, at a capped per-colour turn rate (TEMP): GREEN most, RED between, BLUE least. Felt result: an early
  roll or early sidestep is followed and hit; a roll whose iframes cover the contact saves; a late sidestep up close can still beat
  the cap, from far away it cannot. Reach and distance unchanged (re-judged after this story).
- **R4 Counter timing** (amended by R8). A colour counter succeeds only if pressed inside a window anchored at the commit (the
  moment the fast blow starts): it opens W before the commit (W = 0.25 s TEMP, authored per colour) and stays open until the
  attack's first touch, or until the flight ends if nothing is touched. Too early or wrong colour: the card is spent and the hit
  lands. Replaces today's window.
- **R5 When a colour defence may be played.** Only from the opponent's click on an unblockable until it resolves (hit, landing or
  interruption). Outside it the defence is refused and NOTHING is spent: card stays in hand, no mana, no stamina.
- **R6 Reward.** A successful colour counter gives the defender +1 mana. Rolling through, a miss, or R1 immunity gives nothing.
- **R7 Movement** (amended, OQ8). Hero run speed 5.5 -> 4.6 (TEMP); walk 2.2 unchanged. Heroes only (DEVIATIONS D1).

## Gate rulings (settled 8.10.2026, `C:\dev\_7-9-gate.md`)

- **R8 (OQ1 overridden).** The counter window is anchored at the commit, as R4 now reads: the same at every distance, and the
  7-10 launch flash lands on it.
- **R9 (OQ2).** "Busy window still running" stays the precondition of the counter capture; a press-age test is added (press tick
  >= commit tick - W); an authoring audit pins busy > W per colour. Busy is NOT lengthened.
- **R10 (OQ3 + F1).** The R5 span is "opponent CHARGING and its hit-once memory not HIT", read from a capture taken after step 3
  and before either seat's step-6 card action. A press on the hit or landing tick is refused; the click tick is refused for both
  seats. One new refusal token.
- **R11 (OQ4).** R1 immunity follows ANY knockdown, including the attacker knocked down by a counter.
- **R12 (OQ5).** Steering rates GREEN 240, RED 150, BLUE 90 deg/s (TEMP).
- **R13 (OQ6).** Mana tested before the stamina spend; `REASON_INSUFFICIENT_MANA` reused.
- **R14 (OQ7).** Reward `mana.add(1.0)` at the counter landing, clamped at max, credited to the defender.
- **R15 (OQ9).** The busy lock after a too-early press is unchanged.
- **R16 (F4).** Zero-degrades of the new knobs: mana cost 0 = free; turn rate 0 = no turning; W 0 = the window opens at the
  commit; immunity 0 = none.
- **R17 (F2-F16).** Every proposed fix in the gate report is accepted as written; F15 is recorded as Measured Fact M13.
- **R18 (F16(d)).** The Live Smoke re-invokes R-D6 (P2 is a killable human slot; `7-8/R17` spent it).

## Acceptance Criteria

Behaviour and acceptance only; mechanism is in Open Questions (E4-R/R4). `[M]` = machine-checkable, `[S]` = live smoke.

1. **[M] Price.** With at least the authored mana cost (1, TEMP), an unblockable click spends exactly that mana and the unchanged
   stamina cost on that tick, and the card leaves the hand as today. With less, the click is refused through the existing
   refusal feedback (`action_rejected` on `card_cast`, reason `insufficient_mana`), and card, hand, stamina and mana are all
   untouched. Short of both mana and stamina, the reason is `insufficient_mana`.
2. **[M] No refund.** Mana is never returned on a counter, a miss, an i-frame dodge or an R1-immune pass-through.
3. **[M] Damage.** A landed unblockable removes the authored amount, 6 (TEMP), of a 100-hp hero; the value is a `.tres` knob.
4. **[M] Steering, state.** On every flight tick from the commit to the attack's first touch (counted, i-frame- or
   immunity-dropped), or to the landing if nothing touches, the attacker's facing turns toward the pushed
   hero-to-hero bearing by at most the colour's authored rate (per tick), and the launch travel follows that facing. A tick with
   no pushed bearing keeps the facing. A bearing exactly behind turns in one fixed direction. GREEN > RED > BLUE comes from the
   config, not the code; a rate of 0 turns nothing.
4b. **[M, live] Steering, geometry** (`test_unblockable_reach_live.gd`). A defender displaced early in the flight is followed
   and hit; one displaced late and close beats the cap; one displaced late and far cannot.
5. **[M] Reach and distance unchanged.** The launch's path length (the sum of its per-tick travel) equals the authored distance;
   the displacement may differ once the path bends. The authored reach and the hit shape are as today.
6. **[M] Counter window.** A colour counter lands only if the defender's matching-colour defence was pressed no earlier than W
   before the commit (W authored per colour, 0.25 s TEMP) and before the attack's first touch, or before the flight's end if
   nothing touches. Pressed earlier, or in another colour: the card is spent and the hit lands as if undefended. A press made
   before the commit lands the counter on the commit tick. The counter's consequences (attacker knocked down, defender
   undamaged, no orb grant to the attacker) are unchanged.
7. **[M] Counter span.** A counter is still never judged after the attack's first touch, counted or i-frame-dropped (`7-8/R13`).
   A press on the touch tick or the landing tick is never judged.
8. **[M] Defence legality.** A colour defence pressed while no opposing unblockable is between click and resolution is refused
   with feedback (one new reason token), and spends nothing: card stays in hand, stamina and mana unchanged, the hero is not
   locked busy. A press on the very tick of the opponent's click is refused for BOTH seats alike. A press on the tick the attack
   hits or lands is refused. A presser who is CHARGING their own unblockable is refused with `unblockable_committed`, as today.
9. **[M] End of the span.** The span ends on a counted hit, on the landing or a miss, and on any interruption (counter, knockdown,
   bolt stun, death, reset). Interruptions landing after step 6 (knockdown 6b, bolt stun 6c, death 8) close the span from the
   next tick (the R10 capture seat). An i-frame- or immunity-dropped touch does NOT end it (the attack is still flying).
10. **[M] Reward.** A successful colour counter gives its defender +1 mana (clamped at max, nothing if full). Nothing else does.
11. **[M] Immunity.** After ANY knockdown (the victim of a hit, or the attacker knocked down by a counter), from the close of the
    getting-up iframes for 1.5 s (TEMP, `.tres`), an unblockable touching that hero does nothing: no damage, no knockdown, no
    attacker orb grant. The attack is not spent by it: a touch after the span ends, in the same flight, hits. Melee, spells and
    every other source hit normally. The attack is not refused at cast, and not refunded. With no get-up iframes authored there
    is no immunity. Outside that span nothing changes.
12. **[M] Run speed.** Hero run speed is 4.6 (TEMP); walk speed 2.2, roll distance and every non-hero speed unchanged.
13. **[M] Determinism and replay.** `FORMAT_VERSION` 20 -> 21, a v20 record is refused hard, the golden re-baselines once per the
    Golden Prediction with the reverse probe, the new key hashes at rest in the golden fixture, F1 / D3(a) / D3(b) invariants
    hold, full suite and integration green.
14. **[M] Knobs.** Every new number is authored in `data/balance/balance_config.tres`; tests pin bounds and directions only and
    build their own in-test configs (`BC/R3`). Unauthored, each new knob degrades as R16 states. The authoring audit pins, on the
    real `.tres`: W < chargeup; counter busy > W for every colour; every turn rate > 0.
15. **[S] Feel.** The twelve Live Smoke items pass.
16. **[M] Supersessions** (below, DEVIATIONS D7) are listed here and logged at close-out; no closed story file is edited (E5-R/R7).

## Measured Facts

Verified by CONTENT at HEAD `0a04558` this session (path:line, then what the line says).

- **M1 Price today.** `match_state.gd:5882` spends only `balance.unblockable_stamina_cost`; the header at `:5825` says "NO MANA
  AND NO ORB EVALUATION RUNS". Stamina 20.0 (`balance_config.tres:132`). Mana starts EMPTY and is never refilled
  (`match_state.gd:7773-7779`), max 10.0 (`balance_config.tres:107`), income 0.25/s passive (`:109`) and 1.0 per melee hit (`:108`).
  The refusal vocabulary exists: `CastEvaluator.REASON_INSUFFICIENT_MANA` (`cast_evaluator.gd:35`).
- **M2 Damage today.** `unblockable_damage_percent_of_max_hp = 9.0` (`balance_config.tres:144`), applied against the victim's own
  max at `match_state.gd:6160`; at 100 hp that is 9. So 9 -> 6 is a `.tres` edit to 6.0 percent.
- **M3 Direction today.** The aim is re-read ONLY while the chargeup window runs (`match_state.gd:7550-7553`), so facing freezes
  at the commit; the launch goes along that frozen facing (`:7736-7749`, front-loaded ramp, total distance exactly authored).
  The hero-to-hero bearing is pushed by the runner for every CHARGING hero each tick (`match_runner.gd:1150-1195`, latched at
  `match_state.gd:1475`), including flight ticks; the contact window verdict follows at `:1493`.
- **M4 Counter today.** The defender's busy span (RED 1.0, BLUE 0.8, GREEN 0.5 s, `balance_config.tres:147-149`) is armed at the
  press (`match_state.gd:6035`) and IS the counter window (`_counter_color_of`, `:6671-6680`). It is judged at the attacker's
  CHARGING arm (`:1763`) from the commit tick up to the first touch (`:6767-6784`). So a press is accepted from `busy` before the
  commit THROUGH the flight until first touch, not only inside the charge. Chargeup 1.0 s (`:133`); a RED press before the click
  cannot survive to the commit (busy 1.0 == chargeup 1.0).
- **M5 Defence legality today.** `_resolve_defense_cast` (`match_state.gd:5976`) refuses only: flag closed (`:5977`), CHARGING
  (`:5992`), STUNNED (`:5995`), covered slot (`:6000`), empty slot (`:6002`), stamina (`:6005`, cost 10.0 `:146`). Nothing asks
  whether an attack exists. Every press discards the card and owes a replacement (`:6013-6014`, `:6071-6072`), then locks the
  hero busy for the span (step-3 half `:1812` "if player.defense_window.is_running: return"). This is the hand-cycling `7-8/R20`
  names. Before the mode dispatch `_resolve_card_action` already refuses every card press while getting up (`:3680`
  "REASON_GETTING_UP"), countering (`:3693` "REASON_COUNTERING", the busy lock's card-half REFUSAL, nothing spent) and casting
  (`:3713` "REASON_CASTING"). So after a too-early press the defender cannot re-press for the whole busy span (RED 1.0 s).
- **M6 Who reads the defence window.** Only `_counter_color_of` (`:6671`) changes an outcome. The rest is presentation and
  travel: counter travel (`match_state.gd:7266-7330`, zero when nothing is charging), the facing lock (`:7548-7549`), the runner
  poll (`match_runner.gd:1310`). Counterspell is a different mechanism (`counter_window_seconds` on a spell effect, `:5226`).
  Conclusion for R5: no other legal use of a colour-defence card exists today beyond the cycling and the busy lock.
- **M7 Contact seat.** `_resolve_charge_contact` (`:6112`) drops a touch when `_iframe_open_at_step3` is open (`:6117`), writing
  `CHARGE_CONTACT_TOUCHED` (attack not spent, counter span closed); otherwise `HIT`, orb grant, package owed (`:6120-6122`).
  The package applies damage then knockdown at `:6160-6173` (the `already_down` floor at `:6168`). The predicate is computed at
  `:760-761` and is read by Honed Bolt (`:6413`), so it must not be edited (`7-8/R10`).
- **M8 Get-up.** `get_up_iframe` 2.0333 s (`balance_config.tres:131`) is started at `match_state.gd:1691`, hashed in the hero
  snapshot (`hero_state.gd:590`); its close tick is already tracked (`_get_up_iframe_closed_this_tick`, `hero_state.gd:195-198`,
  `:537`). Knockdown 2.5 s (`:130`). No existing state spans past the close, so a 1.5 s immunity needs new state. With
  `get_up_iframe_ticks == 0` no get-up window runs (`match_state.gd:6812` "get_up_iframe_ticks > 0"), so no close tick exists;
  `get_up_iframe_seconds` defaults to 0.0 (`balance_config.gd:371`).
- **M9 Strike moment candidates** (background only since R8 anchors the window at the commit). The held pose ends at the commit and the sweep plays across the launch
  (`animation_controller.gd:427-431`, hold ends 0.45/0.55/0.55, `:443-447`); the blade-arrival frames are measured at
  `animation_controller.gd:317-319`. Launch spans RED 0.25, BLUE 0.30, GREEN 0.45 s (`balance_config.tres:140-142`). The hit
  itself lands at touch (`7-8/R1`), usually before the visual arrival unless the defender is at full reach.
- **M10 Speeds.** Run `move_speed = 5.5`, walk `walk_speed = 2.2` (`balance_config.tres:87-88`); applied at
  `match_state.gd:7787` and `:7386-7390`. `move_speed` is HASHED on the hero (`hero_state.gd:575`); the golden's
  `MOVE_SPEED := 6.0` (`test_determinism.gd:1332`, set at `:1525`) is an in-test literal. Minions have their own speed
  (`balance_config.tres:39`).
- **M11 Feedback that exists.** A refused press raises `action_rejected(&"card_cast", reason)` (`reject_action` used throughout
  `:5864-6007`); `telegraph_controller.gd:289-292` consumes it. No new cue is needed (Non-Goals).
- **M12 Golden fixture.** `test_determinism.gd` casts mode BASIC only (`:1620-1624`), never UNBLOCKABLE or DEFENSE, never
  charges, never counters. Golden `1b1478ac...` (`:1318`), key set 46, `RecordFile.FORMAT_VERSION = 20` (`record_file.gd:351`).
- **M13 Mana pool edges (F15).** `ManaPool.add` clamps into `[0, max]` and pushes no signal when the value does not change
  (`mana_pool.gd:21-23` "if is_equal_approx(v, _current): return"); `spend` refuses on `amount > _current` (`:30`), a raw
  float compare. The step-5 passive regen runs after the step-3 counter judgement, so the R6 reward and the tick never race.
- **M14 Pins that see the new key (F5, F14).** Hero snapshot key set: `test_debug_window_countdown.gd:105-123` (sorted list,
  "get_up_iframe", ..., "stun_is_bolt"). Per-player count 46: `test_card_observation.gd:363`. MatchState member census:
  `test_replay_identity.gd:178` (`UNHASHED_CROSS_TICK_MEMBERS := 4`, plus the HASHED / PER_TICK lists).
- **M15 Live tests that pin today's direction (F2).** `test_unblockable_reach_live.gd:218-223` "a sidestep after the commit must
  WHIFF" and `:23` "travelled the colour's authored distance along the frozen line"; `test_honest_hit_geometry_live.gd`
  teleport cases (`:237-294`).

## Golden Prediction

The golden MOVES for exactly ONE named cause: the new hashed R1-immunity window on the hero snapshot (presence alone moves the
hash, the `7-8/R15` precedent; every hero hashes it at rest 0). It cannot be derived from existing state (M8: nothing spans the
close), so deriving it is not a way to keep the golden still. Hero-level snapshot key count +1; the per-player key set stays 46
unless the dev pass seats it per player (then 47, and the pin tells). One re-baseline, reverse probe both directions: remove the
key and reproduce `1b1478ac...`, restore and get one stable new literal on two runs; report the probe's own side effects.
Measured NON-causes (to be re-measured, not assumed): the mana cost field (`_golden_config` leaves it unauthored, the fixture
never casts mode 2); the R5 refusal (the SC/R6 boundary: the fixture never presses DEFENSE, so no recorded action becomes
refusable); steering, reward and the new window never run (nothing charges); damage 6 and run 4.6 are authored `.tres` values
(`BC/R3`); no RNG draw. `RecordFile.FORMAT_VERSION` 20 -> 21, hard refusal of v20, no shim: causes are the behaviour changes a
v20 record would replay wrongly (mana spend and refusal, defence refusal, counter timing, steering, immunity) and the `balance`
row shape change (new fields). The golden does not read the version. If the dev pass finds a SECOND mover, STOP and report.
The key is seated on the HERO (R11), so `test_debug_window_countdown.gd`'s hero key list moves and `test_card_observation.gd:363`
stays 46 (M14); a `test_determinism` pin asserts the key hashes at rest at the hash tick (the `:2501` get-up precedent). The
prediction holds only with R16's zero-degrades (a turn rate of 0 turns nothing; mana cost 0 is free).

## Live Smoke

Solo, `slot_controller_kinds` flipped to `[0, 3]` (P1 keyboard casts X/V/B per 6-D1, operator defends on the pad as P2); flip
procedure and revert as in `7-8` (editor closed, text-edit `main.tscn`, revert before any suite run, check `git diff project.godot`).
**R-D6 is re-invoked** (R18): P2 is a killable human slot; spent at close-out. Sound ON: the refusal cue is audio only
(`telegraph_controller.gd:292` "_cue_reject.play()"). Mana is read on the StateInspector (`state_inspector.gd:102`, rounded
integer). Each cast costs 1 mana (about 4 s of passive regen); items 5-6 alone take about five P1 casts, so earn mana with
melee hits between items.
1. **Price (R2).** At match start P1 presses X with 0 mana: refused with the existing cue, hand/stamina unchanged. After mana
   reaches 1 (passive, or melee hits), X spends exactly 1 mana and 20 stamina at the click.
2. **No refund (R2).** P2 outruns or rolls through a cast: mana stays spent.
3. **Defence needs an attack (R5).** P2 presses a colour defence with nothing charging: refused with a cue, card stays, no mana or
   stamina spent, P2 is not locked busy and can move at once.
4. **Too early (R4, R5).** P1 clicks; P2 presses the matching colour at once, well before the commit: card is gone, hit lands
   for 6, P2 is knocked down.
5. **Right press (R4, R6).** P2 presses the matching colour just before the sweep starts, per colour RED, BLUE, GREEN: P1 is
   knocked down, P2 takes no damage and P2's mana rises by exactly 1 on the inspector. Wrong colour: card spent, hit lands.
6. **Press in flight (R4).** P2 presses the matching colour after the sweep has started, before the blade arrives (GREEN, the
   longest flight): the counter lands.
7. **Roll through (R6).** P2 rolls so the iframes cover the contact: saved, mana unchanged.
8. **Steering (R3).** P2 sidesteps early, then rolls early: followed and hit. Late sidestep up close beats it, from far it does not.
   GREEN turns most, BLUE least.
9. **Knockdown loop (R1).** After a hit P2 stands up; within 1.5 s of standing P1 casts: the attack passes through, no damage, no
   knockdown, P1's mana is gone; melee in that span hits P2 normally. After the span a cast hits again.
10. **Countered attacker is immune too (R11).** After P2 counters, P1 stands up; within 1.5 s P2 casts an unblockable on the pad
    (B in cast mode): it passes through P1, no damage, no knockdown. P2's melee in that span hits P1 normally.
11. **Movement (R7).** P1 runs a marked distance: visibly slower than before (4.6); walk and roll unchanged; watch the run clip
    for foot-slide.
12. **Regression.** Melee, block, deflect and Counterspell behave as before; fps stable.

## Non-Goals

Routed elsewhere. 7-10: attacker eyes blinking in the unblockable colour; counter presentation polish (weight, hitstop, knife
trail); any visual cue for R1 immunity or an R5 refusal beyond feedback that exists (an immunity cue is a 7-10 candidate if smoke
asks). 7-2: orbs pushing each other. 7-7: slower melee attacks, wider deflect window, nobody using block, the TEMP numbers, reach
and homing distances (re-judged after this story). The hit cylinder radius 0.30 stays. No new clip. No change to Counterspell,
the pitch zone, or the 20 stamina / 10 stamina costs.

## Open Questions (mechanism; all ruled)

All ruled 8.10.2026 (R8..R16). Kept as the mechanism record; the ruling wins where the text differs.
1. **Strike moment (R4) -- OVERRIDDEN by R8.** The window is anchored at the commit, not at the end of the launch: it opens W
   (0.25 s TEMP, per colour) before the commit and stays open to the first touch or the flight's end. The end-of-launch anchor was
   rejected: a close-range GREEN touches early and its window shrank to ~0.05 s.
2. **How the press time is judged -- RULED R9.** Keep judging on every committed tick at the attacker's CHARGING arm (`:1763`,
   `:6768`); "busy window still running" stays the capture's precondition, and the press-age test is added: press tick >=
   commit tick - W, i.e. press elapsed (`defense_window` duration minus remaining) minus ticks since the commit (`landing_window`
   elapsed minus `charge_window` duration) <= W ticks. Both come from snapshotted durations, so no new key. Audit: busy > W
   for every colour (30/48/60 ticks GREEN/BLUE/RED vs 15). Busy is not lengthened.
3. **Deriving the R5 span -- RULED R10 (amended by F1).** Opponent CHARGING with the hit-once memory not HIT (existing hashed
   state, no new key), read from a capture taken AFTER step 3 and BEFORE either seat's step-6 card action, so it sees this
   tick's hit and landing and still refuses the click tick for both seats (P1's click resolves in step 6). One NEW token (for
   example `&"nothing_to_answer"`), placed after the empty-slot guard and before the stamina spend so nothing is spent; the
   existing `CHARGING` gate (`:5992`) still answers first for a charging presser. Adds a refusable press, the SC/R6 class.
4. **Where R1 lives -- RULED R11.** A new hashed hero `TimingWindow`, started at step 2 on the get-up close
   (`_get_up_iframe_closed_this_tick`, `hero_state.gd:537`), never in one seat's step-3 arm; consulted in
   `_resolve_charge_contact` beside the iframe branch and treated the same way (`TOUCHED`: attack not spent, counter span
   closed, no orb grant). NOT folded into `_iframe_open_at_step3` (Bolt reads it, M7). Any knockdown (one classifier,
   `is_knockdown_stun`); resets with `_reset_player`; classified `HASHED` in `test_replay_identity.gd`.
5. **Steering mechanism (R3) -- RULED R12.** Three per-colour turn rates (deg/s) in `.tres`, applied to `hero.facing` toward
   the pushed bearing on each flight tick (M3); the launch velocity reads the steered facing, so travel and facing agree. No new
   key. GREEN 240, RED 150, BLUE 90 deg/s (TEMP). The ramp and path length are untouched (AC 5).
6. **Mana charge order (R2) -- RULED R13.** Mana tested first, then the stamina spend, then the mana spend, so a refusal leaves
   both untouched; a new mana seat, the SC/R6 class. Reuse `REASON_INSUFFICIENT_MANA`.
7. **Mana reward at cap (R6) -- RULED R14.** `mana.add(1.0)` at the counter landing in `_resolve_color_counter`, credited to
   the defender read from the capture; clamps, no signal when full (M13).
8. **Run speed value (R7) -- RULED.** 4.6 (TEMP), R7 amended.
9. **The busy lock after a too-early press -- RULED R15.** Unchanged (0.5-1.0 s): the card, 10 stamina and the lock are the
   price of a bad read; a re-press is refused with `countering` (M5).

## Tasks

- [x] T1 Authoring (AC 3, 4, 6, 12, 14): new `.tres` fields and their tick twins, the R16 zero-degrades, the AC 14 audit bounds.
- [x] T2 Price and refusal (AC 1, 2, 8, 9): mana seat on the unblockable cast, the R5 gate and its post-step-3 capture (R10).
- [x] T3 Counter window and reward (AC 6, 7, 10).
- [x] T4 Steering (AC 4, 5) and run speed (AC 12).
- [x] T5 Immunity window (AC 11) and its snapshot, classification and reset.
- [x] T6 Replay and golden (AC 13): `FORMAT_VERSION` 21, v20 refusal fixture, re-baseline with reverse probe, at-rest pin, census entries (M14).
- [x] T7 Tests: sweep the suites that pin today's rules (list in D7), mutation-prove the new guards from out-of-repo copies.
- [x] T8 Live smoke with the operator (AC 15): smoke 1-13 PASS, 2026-10-08.

### Review Findings

Code review 2026-10-08 (Opus 5.5, gds-code-review, three layers run sequentially in one session; report
`C:\dev\_7-9-review.md`).

- [x] [Review][Decision] RESOLVED `7-9/R20`: AC 9 amended to the R10 seat. AC 9 vs R10 seat: 6b/6c interruptions close the span one tick late. A knockdown (6b) or bolt stun (6c) of the charging attacker lands after the post-step-3 capture, so a defence pressed on that tick is accepted and spent. AC 9 says "from that tick on"; `7-9/R10` locks the seat. The chain amends AC 9 to R10's seat, or the operator rules otherwise.
- [x] [Review][Decision] RESOLVED `7-9/R21`: accepted. DV1: the reward is the `.tres` knob `counter_mana_reward` (authored 1.0), not R14's literal `mana.add(1.0)`. The operator accepts or rejects it.
- [x] [Review][Patch] RESOLVED `7-9/R19`. R3: steering ran to the landing; ruled to end at the first touch (counted or dropped) [src/state/match_state.gd:7870] -- fixed in review, test `test_a_touch_dropped_by_iframes_ends_the_steering`, mutation-proven
- [x] [Review][Patch] RESOLVED `7-9/R22`: tied to the authored GREEN numbers; a 7-7 retune re-measures the file or makes it self-rescheduling. AC 4b live thresholds are tuned to the authored GREEN numbers (`STEP` 1.5, shares 0.22 / 0.46, cap window flight ticks 12-13 of 27). A 7-7 retune of GREEN's turn rate, launch span/distance or reach fails `test_unblockable_reach_live.gd`, so BC/R3's "a tuning change needs no test edit" does not hold for it. 7-7 must re-measure the file or make it self-rescheduling [test/integration/test_unblockable_reach_live.gd:90]
- [x] [Review][Defer] Mana affordability is a raw float compare (M13): mana earned by passive regen can read "1" while sitting a hair below 1.0 [src/state/match_state.gd:5961] -- deferred, pre-existing

## Dev Notes

Read first: `match_state.gd` `:5852`, `:5976`, `:6112`, `:6153`, `:6671`, `:6767`, `:7550`, `:7736`; `hero_state.gd:195`, `:537`,
`:590`; `balance_config.gd` (Unblockable group); `balance_ticks.gd`; `test_unblockable_defense.gd`,
`test_unblockable_honest_contact.gd`, `test_click_to_commit.gd`, `test_unblockable_tracking_and_reach.gd`. Authored balance is
isolated from the golden and the unit suite (`BC/R3`), but a new seat or a refusable press is not (`SC/R6`): run the full suite
before and after. Project rules that bite here: every new duration is an integer-tick `TimingWindow` converted once at balance load
(A1, no `delta` into `advance()`); no global RNG/`Time`/`OS` in `src/state/` (D3b); a mid-flight balance reload must not move a
running window (CONSTRAINT C, read inline); state decides, visuals only react. Commit rules: docs and code in separate commits, ASCII message via `-F`, trailer per CLAUDE.md.

Gate additions (8.10.2026, `C:\dev\_7-9-gate.md`):
- Why OQ2 needs no busy change (R9): the counter lands on the FIRST qualifying committed tick, so a pre-commit press is read at
  the commit tick (age <= W) and a later press on the next tick; busy only has to outlive W. Lengthening busy would lengthen the
  defender's lock, root and counter travel (a feel change); judging without busy would let a counter land after its
  presentation ended.
- Why the R5 capture sits after step 3 (R10, F1): a capture before step 3 (the `_counter_color_at_step3` seat, `:766-767`)
  predates this tick's hit (`:6120`) and landing (`:1771`), so a press on that tick was accepted and spent.
- W and the turn rates are thresholds, not running windows: read inline at use (CONSTRAINT C); a mid-flight reload moves the
  judgement, which is accepted. The turn rate becomes a per-tick angle once at balance load (A1).
- Steering edges (F11): co-located ticks push no bearing (`match_runner.gd:1157`), so facing is kept; a bearing exactly behind
  turns one fixed way (a fixed sign, never a coin). The arena edge is not a risk (steering only turns toward the defender); the
  reach pre-filter (`match_runner.gd:1180`) and the 0.30 hit shape are untouched.
- Seed mana in tests with `mana.add` (exact), never with passive regen: `spend` is a raw float compare (M13).
- Expected movers from R16: with W unauthored (0) every existing pre-commit counter press is "too early" (`test_click_to_commit.gd:206-212`,
  `test_unblockable_defense`); with mana cost 0 and turn rate 0 the other in-test mode-2 tests stay green.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (`claude-opus-5-5`), gds-dev-story, 2026-10-08. One session, no subagents, nothing committed.

### Debug Log

**Preconditions (all verified before the first edit):** HEAD `42bdc3d`, origin/main `0a04558`, tree clean, no godot
process; `git diff 0a04558 42bdc3d -- sprint-status.yaml` moves only the 7-9 key line and the 7-9 story_note line.
Customization resolved with `python` (on_complete present, applied at the end). `baseline_commit` preserved as written (`0a04558`).

**Suite runs (one foreground call each, output outside the repo, counters read by opening the file):**

| Run | File | Result |
|---|---|---|
| before, state | `C:\dev\_7-9-suite-before-state.txt` (15:44:23) | 1255 tests, 0 failed, 12475 assertions, PASS |
| before, integration | `C:\dev\_7-9-suite-before-integration.txt` (15:52:11) | 79 files, 79 PASS, ALL TESTS PASSED |
| EXTRA 1, state (discovery) | `C:\dev\_7-9-suite-discovery-state.txt` (16:14:59) | 1287 / 5 failed (golden + 4 movers, all fixed) |
| final1, state | `C:\dev\_7-9-suite-final1-state.txt` (16:43:30) | 1287 tests, 0 failed, 13113 assertions, PASS |
| final, integration | `C:\dev\_7-9-suite-final-integration.txt` (16:49:29) | 79 files, 79 PASS, ALL TESTS PASSED |
| EXTRA 2, state (final) | `C:\dev\_7-9-suite-final-state.txt` (16:51:19) | **1288 tests, 0 failed, 13119 assertions, PASS** |

Full-suite run count: state half 4 (default 2 + 2 extra), integration half 2 (default). EXTRA 1 reason: discover every
mover outside D7's list before the golden step, which needs all non-golden tests green first (the alternative was ~10
filtered runs that still could not see an unlisted mover). EXTRA 2 reason: an AC 9 test (interruption ends of the span)
was added after final1, so final1 no longer described the final tree; nothing under `src/` or `test/integration/` changed
after the integration final. Beside the full runs: targeted single-file dev runs (state filter: tempo x5, unblockable x2,
click_to_commit x1, replay_identity x1, test_determinism x3 = golden probe (a) + (b) twice; integration single files:
reach_live x3, honest_hit_geometry x1, counter_reactions x1, charge_playhead x1, defense_reactions x1), 26 mutation runs
(table below), and 4 throwaway probe launches from the scratchpad (never in the repo): two steering-geometry sweeps and two
signed-zero measurements.

**Golden:** `1b1478ac310fd163411f8ea71900fbb5524766dd80874227a3fd740848890e98` -> `9d5d4fadce063bcd8832243513eaa732c442a146e37c1390ae7419db1638e86f`,
ONE re-baseline, ONE cause, exactly the predicted one: the hero snapshot key `unblockable_immunity`. Reverse probe:
(a) key erased from `HeroState.to_snapshot()` with every other 7-9 change live -> `test_state_matches_golden` passes against
`1b1478ac...` EXACTLY; (b) key restored (copy-back from `C:\dev\_7-9-mut\hero_state.gd.bak`, SHA256 `203ee5ed...` both
ways) -> `9d5d4fad...` on two separate runs (23/23 each). Probe side effect, measured: during (a) the new at-rest pin
raised `SCRIPT ERROR: Invalid access ... 'unblockable_immunity'` (the harness printed `[ok]`, the function aborted before its
assert; `run_all.sh`'s grep would fail the suite on that line). `test_debug_window_countdown`'s key list was not run during
the probe. No second mover: (a) reproduces the old hash with the mana seat, R5 refusal, lead, reward, steering and immunity
arming all live.

**FORMAT_VERSION:** 20 -> 21, hard refusal of v20, no shim; new fixture `test_a_v20_record_is_refused_with_a_reason` (its
path deliberately carries no "20", so the `contains("20")` check can only be answered by the message).

**Key-set pins moved:** hero snapshot key list (`test_debug_window_countdown.gd`) +1 `unblockable_immunity`. Per-player key
set stays **46** (`test_card_observation.gd` unmoved, as predicted: the key is on the hero). Top-level key set unmoved.
Replay census (`test_replay_identity.gd`): HASHED +`hero_state.unblockable_immunity`; PER_TICK +`_counter_press_age_at_step3`,
+`_defense_answerable_at_step6`, +`_charge_reach_pushed`; `UNHASHED_CROSS_TICK_MEMBERS` stays 4. Three saved-file version
pins (`_saved_format_version(...) == 20`) moved to 21.

### Completion Notes List

**What was built (production):**
- `BalanceConfig`: nine knobs -- `unblockable_mana_cost`, `unblockable_immunity_seconds`, `unblockable_turn_rate_degrees_per_second_{red,blue,green}`,
  `counter_lead_seconds_{red,blue,green}`, `counter_mana_reward`; all default 0 (R16 degrades). `BalanceTicks`: `unblockable_immunity_ticks`,
  `counter_lead_ticks_*` + `counter_lead_ticks_for`, `unblockable_turn_radians_per_tick_*` + `unblockable_turn_radians_per_tick_for` (A1).
- `.tres` (TEMP): mana cost 1.0, immunity 1.5 s, turn rates RED 150 / BLUE 90 / GREEN 240, leads 0.25 x3, reward 1.0, damage 9.0 -> 6.0,
  run 5.5 -> 4.6. Walk, roll and every non-hero speed unchanged (diff is those lines only).
- AC 1/2: `_resolve_unblockable_cast` tests mana (`cost > current`, `spend`'s own compare) before the stamina spend, spends it after;
  `REASON_INSUFFICIENT_MANA` reused; `Invariant.check` on the spend. No refund path exists anywhere.
- AC 8/9 (R5/R10): `_defense_answerable_at_step6` captured after step 3 and before step 6's card actions from
  `_opposing_unblockable_in_flight` (CHARGING and hit-once memory not HIT, existing hashed state); `_resolve_defense_cast`
  refuses with the one new token `REASON_NOTHING_TO_ANSWER` after the empty-slot guard, before the stamina spend.
- AC 6/7 (R4/R8/R9): `_counter_press_age_at_step3` captured beside `_counter_color_at_step3`; `_resolve_color_counter` adds
  `press_age - ticks_since_commit <= lead(colour)` on top of the unchanged busy precondition and first-touch gate.
- AC 10 (R6/R14): `defender.mana.add(balance.counter_mana_reward)` at the counter landing.
- AC 4/5 (R3/R12): `_steer_charge_facing` runs on every flight tick before `_charge_launch_velocity`; `_charge_reach_pushed`
  (set by `push_contact`, cleared after step 3's movement seats) tells a pushed bearing from a stale one; exactly-behind pinned
  to +PI; within one step it snaps to the bearing. Ramp, distance and reach untouched.
- AC 11 (R1/R11): `HeroState.unblockable_immunity` (hashed, key `unblockable_immunity`), ticked in `tick_timers`, armed at step 2
  by `_arm_unblockable_immunity` on `get_up_iframe_closed_this_tick()`; `_resolve_charge_contact` drops a touch inside it as
  `TOUCHED` on its own branch (not folded into `_iframe_open_at_step3`); `_reset_player` stops it (eighth named exception).
- AC 13: `RecordFile.FORMAT_VERSION` 21 with the cause paragraph.

**Tests:** new `test/state/test_unblockable_tempo.gd` (32 tests). Re-pointed: `test_unblockable_defense.gd`
(`_cast_defense` arms an opposing chargeup first; in-test lead == busy; 3 "nothing charging" tests now pin the refusal; the
judged-tick press now pins the refusal; the R-PRESS card half uses a BASIC cast; 2 R-S6 tests retired, see DV3),
`test_unblockable_tracking_and_reach.gd` and `test_click_to_commit.gd` (in-test lead == busy), `test_unblockable_reach_live.gd`
(AC 4b, see DV4), plus the pins above and the AC 14 audit `test_authored_tempo_values_are_bounded`.

**AC verification:** AC 1, 2, 4, 5, 6, 7, 8, 9, 10, 11 -- `test_unblockable_tempo.gd` (and mutation table). AC 3 -- `.tres` diff
(6.0) plus `test_honest_hit_geometry_live.gd`'s `touch` cases asserting exactly one authored-percent instalment against the live
`.tres` at 100 max hp (PASS). AC 4b -- `test_unblockable_reach_live.gd`. AC 12 -- `.tres` diff (move_speed only). AC 13 -- golden,
version, v20 fixture, at-rest pin, census, F1/D3(a)/D3(b) (`test_architecture_invariants.gd` green in both finals). AC 14 -- audit
+ R16 zero-degrade tests (mana 0 free, turn 0 none, lead 0 at the commit, immunity 0 / no get-up none). **AC 15 [S] NOT DONE**
(T8, DV2). AC 16 -- the supersessions are listed in D7 (unchanged); logging them is the close-out's job, not this pass's.

**Mutation table** (backups in `C:\dev\_7-9-mut\`, restored by copy, never git; SHA256 after restore: `match_state.gd`
`bce27176...`, `hero_state.gd` `203ee5ed...`, `balance_config.tres` `e3ea3d6d...`, `record_file.gd` `e1251da0...` -- each equal
to its backup on every row):

| # | AC | Mutation | Run | Failing test(s) | Restore |
|---|---|---|---|---|---|
| M1 | 1 | delete the mana affordability refusal | tempo | `short_of_mana...`, `short_of_both...` | ok |
| M2 | 8 | delete the R5 refusal | tempo | `nothing_to_answer...`, `click_tick...`, `hit_tick_or_landing...` | ok |
| M3 | 8/R10 | read the opponent LIVE at the press instead of the capture | tempo | `click_tick...` (slot 0 only: the seat asymmetry) | ok |
| M4 | 6 | delete the lead comparison | tempo | `window_opens_the_lead...`, `zero_lead...` | ok |
| M5 | 10 | delete the reward | tempo | `successful_counter_pays...` | ok |
| M6 | 4 | delete the steering call | tempo | 5 steering / path-length tests | ok |
| M6b | 4b | delete the steering call | reach_live | `early`, `late_far`, `late_close_uncapped` | ok |
| M6c | 4b | remove the cap (`step := PI`) | reach_live | `early_rigid`, `late_far_rigid`, `late_close` | ok |
| M7 | 4 | drop the push-flag guard | tempo | `no_pushed_bearing...` | ok |
| M8 | 4 | bare `atan2` (no fixed sign) | tempo | `exactly_behind...` pairs A and D, both slots | ok |
| M9 | 11 | delete the contact-seat breather branch | tempo | `breather_drops...`, `countered_attacker...` | ok |
| M10 | 11 | delete the step-2 arming | tempo | 5 breather tests | ok |
| M11 | 11 | delete the reset clear | tempo | `reset_clears_the_breather...` | ok |
| M12 | 9 | drop the HIT conjunct of the span | tempo | `hit_tick_or_landing...`, `span_ends...` | ok |
| M13 | 13 | arm the breather every tick at the authored length | determinism | **SURVIVED** -- equivalent: `_golden_config` authors no immunity, so `start(0)` == rest | ok |
| M13b | 13 | arm `start(7)` every tick | determinism | `state_matches_golden`, `no_unblockable_immunity_armed` | ok |
| M14 | 14 | `.tres`: lead RED 1.0, lead BLUE 0.8, turn GREEN 0, mana 0, immunity 0, reward 0 | balance_authoring | all seven bound assertions, each its own message | ok |
| M15 | 13 | `FORMAT_VERSION := 20` | record_file | `v20_record_is_refused...` + 2 version pins | ok |
| M16 | 11 | fold the breather into `is_iframe_open()` | tempo | `melee_hits_normally...` + 3 | ok |
| M17 | 4 | steer AFTER the velocity | tempo | `facing_turns...travel_follows_it` | ok |
| M18 | 9/R10 | capture moved BEFORE step 3 | tempo | `hit_tick_or_landing...`, `counter...knockdown...`, `span_ends...` | ok |

Two of my own tests were caught vacuous by these proofs and fixed (re-proven above): **M8** survived twice -- a facing and a
bearing that are each other's plain negation always cross to +0, and GDScript constant-folds a source `-0.0` to +0.0, so the
pairs now build their negative zeros at runtime and assert the cross sign as fixture. **M6c** first left `late_close` green --
its whiff was geometric, not the cap's; a second probe found GREEN's cap-attributable window (flight ticks 12-13 of 27 for a
1.5 m step), the share moved there, and a `late_close_uncapped` control (must HIT) now makes the whiff the cap's.

**DEVIATIONS (mine, against the story; the story's own DEVIATIONS section is unedited):**
- **DV1 Reward knob.** R14 writes the literal `mana.add(1.0)`; AC 14 puts every new number in the `.tres` and project-context
  forbids hardcoded economy values. Shipped as `counter_mana_reward` (authored 1.0, R14's number; 0 = no reward). A fifth knob
  beside R16's four; flagged for review.
- **DV2 T8 / AC 15 not done; Status `review` anyway.** The pass's hard rule forbids touching `main.tscn` (no smoke flip). The
  skill would HALT on an incomplete task at step 9; the operator's rules win and the story Status is set to `review` as
  instructed. The live smoke (twelve items, R-D6 re-invoked per R18) is owed before close-out.
- **DV3 Two retired tests** in `test_unblockable_defense.gd` (`..._ran_out_before_the_commit...`, `..._whole_busy_span_counters...`):
  both pinned `6-6b/R-S6` with a press made BEFORE the cast, which 7-9 makes unreachable (R5) and whose claim it supersedes
  (R4/R8). Replacements in the tempo file (lead edge; `test_the_busy_span_stays_the_precondition`). Comment left in place.
- **DV4 AC 4b pinned on GREEN only,** with rate-0 and unbounded-rate controls; RED/BLUE show the same shape at their caps
  (measured) and the per-colour order is proven headless off the config. The `side` case (`must WHIFF for every colour`) is
  retired as the M15 flip R3 supersedes. The thresholds are measured against the authored rates: a 7-7 retune of GREEN's turn
  rate or launch may move the window and fail this file loudly (the far/close distances are asserted) -- unlike the file's
  other cases, these are not self-rescheduling.
- **DV5 D7's expected movers that did NOT move (confirmed by running):** `test_action_state`, `test_card_observation` (46, as the
  Golden Prediction says), `test_unblockable_honest_contact`, `test_counter_reactions_live`, `test_charge_playhead_live`,
  `test_defense_reactions_live` (all poke state directly), `test_honest_hit_geometry_live` (confirmed). Movers outside D7: none.

**Readings and flags for the review (no ruling taken; the contract was followed):**
- **AC 9 vs R10 seat.** R10 locks the capture after step 3 and before step 6, so interruptions that land LATER in the tick
  (6b knockdown, 6c bolt stun, step-8 death) close the span from the NEXT tick's capture; a same-tick press resolves first (the
  R-PRESS order). Pinned by `test_the_span_ends_on_a_counter_at_once_and_on_a_knockdown_from_the_next_tick`. In practice the
  presser is itself charging (6b) or casting (6c) on such a tick and is refused by those gates first.
- **R3 "until contact" vs AC 4 "to the landing".** Implemented per AC 4 (and R12/OQ5 "each flight tick"): steering continues after
  a dropped touch, so a rolling defender is still followed through its i-frames. Smoke item 7 ("a roll whose iframes cover the
  contact saves") is where this will be felt.
- **Golden Prediction typo.** It says "damage 6 and run 5.0"; R7/AC 12 say 4.6, which is what is authored.
- **Small API additions beyond the named ones:** public `HeroState.get_up_iframe_closed_this_tick()` (the step-2 arming R11 names
  needs to read the private marker from `MatchState`), two `BalanceTicks` lookups on the existing `*_for` pattern, and two
  per-tick `MatchState` members beyond the story's capture (`_counter_press_age_at_step3`, `_charge_reach_pushed`). No new hashed
  key besides the predicted one; no new folder; no new `class_name` (so no editor scan was needed; `project.godot` untouched).
- **git status at halt:** 18 modified + 1 untracked (`test/state/test_unblockable_tempo.gd`); nothing staged, nothing committed.

### File List

- `src/state/match_state.gd` (modified)
- `src/state/hero_state.gd` (modified)
- `src/state/resources/balance_config.gd` (modified)
- `src/state/timing/balance_ticks.gd` (modified)
- `src/systems/record_file.gd` (modified)
- `data/balance/balance_config.tres` (modified)
- `test/state/test_unblockable_tempo.gd` (new)
- `test/state/test_unblockable_defense.gd` (modified)
- `test/state/test_unblockable_tracking_and_reach.gd` (modified)
- `test/state/test_click_to_commit.gd` (modified)
- `test/state/test_balance_authoring.gd` (modified)
- `test/state/test_data_resources.gd` (modified)
- `test/state/test_debug_window_countdown.gd` (modified)
- `test/state/test_determinism.gd` (modified)
- `test/state/test_record_file.gd` (modified)
- `test/state/test_replay_identity.gd` (modified)
- `test/integration/test_unblockable_reach_live.gd` (modified)
- `docs/implementation-artifacts/7-9-unblockable-tempo.md` (this record; Status, task boxes)
- `docs/implementation-artifacts/sprint-status.yaml` (board: in-progress during the pass, then restored per on_complete)

### Change Log

- 2026-10-08 -- Dev pass (Opus 5.5): mana price, defence legality (R5/R10), commit-anchored counter window with per-colour lead,
  counter mana reward, post-launch steering, post-get-up unblockable immunity, damage 6 / run 4.6, FORMAT_VERSION 21, golden
  `1b1478ac` -> `9d5d4fad` (one cause). T1-T7 done; T8 live smoke not run in this pass (DV2). Uncommitted.

## DEVIATIONS

- **D1 Speeds.** Operator assumed run 6.0 / walk 2.0; the repo has run 5.5 and walk 2.2 (`balance_config.tres:87-88`). R7 is applied
  as the same ~1/6 (OQ8). Walk is untouched.
- **D2 Counter window.** Assumed "last second of the charge, last half second for GREEN". Measured: the defender's busy span
  (RED 1.0, BLUE 0.8, GREEN 0.5) judged from the commit THROUGH the flight to the first touch (M4). BLUE is 0.8, and a press after
  the commit also counts today.
- **D3 Mana.** Assumed "no mana cost" holds. It does (M1), but mana starts empty and refills slowly, so R2 makes the first
  ~4 s of a match unblockable-free for both players unless melee hits land; the smoke includes a mana-earning step.
- **D4 Damage.** The knob is a percent of the victim's max hp, not hit points (M2); 6 hit points equals 6.0 only at 100 max hp.
- **D5 Defence "free".** Free in mana only; today it already costs 10 stamina, the card and a 0.5-1.0 s lock (M5).
- **D6 Travel direction.** As assumed: frozen at launch (M3). R3 changes it.
- **D7 Supersessions (listed here, logged at close-out; no closed file edited).** `7-8/R13` (counter span and "7-9 reworks counter
  timing"); `6-6b/R-S6` ("the whole busy span is the counter window", "as long as you initiate before the attack touches you");
  `5-5` AC 4 (defence castable at any time except CHARGING) and `5-5`'s no-mana rule for the unblockable (`5-2/R2`); `6-1c` AC 2
  (the commit freeze of facing); the `7-8` Non-Goals line for this story; `5-5` AC 7 (the card leaves the hand on EVERY commit,
  `:6009`); `6-1c` AC 4 direction half ("nothing here reads where the defender is", `:7691-7692`); `6-1d` AC 7 direction clause
  (`:7698-7699`); `6-6b` AC 9's zero-travel fallback (`:6042-6054`), now unreachable by a press and kept as defence in depth. Tests expected to move: `test_unblockable_defense`,
  `test_click_to_commit`, `test_unblockable_honest_contact`, `test_unblockable_tracking_and_reach`, `test_action_state`,
  `test_balance_authoring`, `test_data_resources`, `test_replay_identity`, `test_record_file`, `test_determinism`, and the
  integration `test_counter_reactions_live`, `test_charge_playhead_live`, `test_defense_reactions_live`, `test_unblockable_reach_live` (M15, flips), `test_honest_hit_geometry_live`
  (confirm), and `test_debug_window_countdown`, `test_card_observation` (M14) (dev pass confirms by running).
- **D8 Board note.** `story_notes` for this key still described "empty-defense cost"; replaced (R5 supersedes that idea).
