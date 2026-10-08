---
baseline_commit: 0a04558eca15c4e39e473cfb82b5e80bdb562c7a
---

# Story 7.9: Unblockable tempo

Status: ready-for-dev

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
4. **[M] Steering, state.** On every flight tick from the commit to the landing the attacker's facing turns toward the pushed
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
   bolt stun, death, reset), each from that tick on. An i-frame- or immunity-dropped touch does NOT end it (the attack is still
   flying).
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
refusable); steering, reward and the new window never run (nothing charges); damage 6 and run 5.0 are authored `.tres` values
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

- [ ] T1 Authoring (AC 3, 4, 6, 12, 14): new `.tres` fields and their tick twins, the R16 zero-degrades, the AC 14 audit bounds.
- [ ] T2 Price and refusal (AC 1, 2, 8, 9): mana seat on the unblockable cast, the R5 gate and its post-step-3 capture (R10).
- [ ] T3 Counter window and reward (AC 6, 7, 10).
- [ ] T4 Steering (AC 4, 5) and run speed (AC 12).
- [ ] T5 Immunity window (AC 11) and its snapshot, classification and reset.
- [ ] T6 Replay and golden (AC 13): `FORMAT_VERSION` 21, v20 refusal fixture, re-baseline with reverse probe, at-rest pin, census entries (M14).
- [ ] T7 Tests: sweep the suites that pin today's rules (list in D7), mutation-prove the new guards from out-of-repo copies.
- [ ] T8 Live smoke with the operator (AC 15).

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

### Debug Log

### Completion Notes List

### File List

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
