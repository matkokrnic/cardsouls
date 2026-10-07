---
baseline_commit: 73907e9aa526291e103bf24a14ac266a2150e3a3
---

# Story 7.8: Unblockable honest contact

Status: review

Tier **A** (touches `src/state/`: the landing seat, the dodge rule and the CHARGING arm). Authored 2026-10-07 against
HEAD == origin/main == `73907e9`, tree clean, suite 1248 tests / 0 failed / 11839 assertions + integration green
(measured this session). Operator rulings of 7.10.2026 are `7-8/R1..R7`; the readiness gate (round 1, NOT READY, B1-B5)
added `7-8/R8..R15`. All fifteen are in the decision-log, session "7-8 readiness gate (round 1)".

## Story

As the defender of an unblockable, I want the hit to land exactly when the blade touches my model, and only when it
really does, so that a knockdown never happens across a gap and a well-timed roll visibly beats the blade.
As the attacker, I want the charge-up to read as a held anticipation followed by a fast strike, so that the attack is
fair to read and satisfying to land.

## Operator rulings (settled 7.10.2026)

- **7-8/R1** Hit at the moment of touch, not at the landing; damage, knockdown and the attacker's orb grant on that tick;
  at most one hit per unblockable; the attacker then finishes its motion harmlessly.
- **7-8/R2** A touch while the defender's roll i-frames are open does not count; a blade still touching after they close
  counts on that tick; no touch in the whole attack = miss. Replaces "i-frames open on the landing tick".
- **7-8/R3** Damage only when the models really connect: the hero's hit shape matches the visible model, for EVERY hit on
  a hero (melee included). Accepted consequence: melee grazing the air beside a hero stops landing.
- **7-8/R4** Genichiro rhythm from EXISTING clips only: held anticipation, then the sweep plays only once the attack
  moves; the blade never visibly passes through the defender during the charge-up.
- **7-8/R5** GREEN crouches before take-off; about 2/3 of its travel happens on the way up to the apex.
- **7-8/R6** No visible pops between charge-up, attack and recovery.
- **7-8/R7** All feel numbers are knobs in `.tres` or presentation tables; tests pin only bounds and directions.

Gate rulings (round 1):

- **7-8/R8** (S1, B2) The colour arc no longer gates a counted touch: the arc exports, the `.tres` values,
  `unblockable_arc_degrees_for`, `_is_in_charge_arc` and its seat gate retire; `_charge_contact_dirs` retires with its
  classification entry (`UNHASHED_CROSS_TICK_MEMBERS` stays 4). A counted touch hits whatever the attacker's facing.
- **7-8/R9** (S2, B4) Body collision stays exactly today's 1x2x1. The hero HIT shape is a separate shape that FOLLOWS a
  trunk bone each tick (precedent: the sword hitbox following its bone, 5-0a `_track_weapon_bone`), sized from the dev
  pass's first measurement (skinned-vertex torso half-width and depth in idle, block, attack, roll, jump_attack). All four
  hit consumers move to it.
- **7-8/R10** (S3, N3) A touch counts only if the `_iframe_open_at_step3` predicate is closed on that tick (roll and
  get-up i-frames and the 1-9/R2 grace tick); the predicate is NOT edited (Honed Bolt reads it too). The INSIDE latch stops
  being absorbing and becomes this tick's fact.
- **7-8/R11** (S4, N1) `dodged_unblockable_damage_multiplier` retires.
- **7-8/R12** (S5, B1) FORMAT_VERSION 19 -> 20, hard refusal of v19, no shim.
- **7-8/R13** (S6, N2) Colour counter: judged from the commit tick up to the FIRST touch of the attack, counted or
  i-frame-dropped (any touch closes the span, as today); a counter on the commit tick beats a same-tick touch; never judged
  after. 7-9 reworks counter timing as a whole.
- **7-8/R14** (B3) The reach pre-filter stays as an upper bound (6-1d AC 2 unchanged). A real blade touch sits far inside
  every authored reach, so the bound never refuses one in play.
- **7-8/R15** (B5) The hit-once memory (AC 3, R13) is ONE NEW HASHED per-player snapshot key, classified `HASHED` in
  `test_replay_identity.gd`. The golden moves for exactly that cause.
- **7-8/R16** (round 2, C10) A lethal hit mid-flight leaves the attacker CHARGING, held mid-motion by the round-over freeze
  until `_reset_player`; accepted. Live Smoke item 9 is its check; any fix belongs to 7-2 polish, not this story.

## Acceptance Criteria

Behaviour and acceptance only (E4-R/R4). Mechanism choices are in Open Questions.

**Hit timing (R1, R8, R14)**
1. A blade that touches the defender's model during the attack, within the colour's authored reach bound (6-1d AC 2,
   unchanged), hits on the tick the touch is registered (the tick the runner's fact is processed; the fact reflects the
   previous tick's physics), for all three colours. Damage, knockdown and the attacker's orb grant occur on that tick and
   never later.
2. A defender who is visibly far from the blade is never knocked down. No hit is credited to a touch that ended before
   the attack started moving (charge-up touches still credit nothing, as today).
3. An unblockable hits at most once. After the hit the attacker completes its motion with no second damage, knockdown,
   orb grant or `hit_landed`, and returns to idle exactly as today at the end of the attack, except after a lethal hit, where the round-over freeze holds it mid-motion until reset (OQ9, R16).
4. The existing outcomes are unchanged in size: authored damage, the victim-knockdown package and the one-orb grant
   (`unblockable_orb_grant`) are applied once, in the existing order, and a lethal hit still writes no knockdown.
5. An attack that never touches is a miss, as today: card and stamina stay spent, no damage, no orb.
6. (R8) A counted touch hits whatever the attacker's facing; no colour arc gates it.

**Dodge (R2, R10, R11)**
7. A touch counts only on a tick the defender's i-frames are closed (roll i-frames, get-up i-frames and the 1-9/R2 grace
   tick all count as open). A touch while they are open does nothing: no damage, no knockdown, no orb, no signal, and the
   i-frame window is neither consumed nor shortened. The attack is NOT spent by that touch.
8. If the blade is still touching on the first tick after the i-frames close, the hit lands on that tick, in full. An
   earlier open-frame touch is not remembered: i-frames open on a touch and then closed with no touch on that tick is a miss unless a later counted touch follows (AC 1, AC 7).
9. The dodge rule is identical on both seats (seat symmetry), a roll that fully clears the blade path is a miss, and a
   dodged touch has no tunable cost (the dodged-damage multiplier no longer exists).

**Colour counter (R13)**
10. The colour counter answers an unblockable from the commit tick up to the attack's FIRST touch, whether that touch
    counted or was dropped by i-frames (any touch closes the span, as today). A counter on the commit tick beats a touch
    on that same tick. After the first touch it is never judged again for that attack.

**Hit shape (R3, R9)**
11. The hero's hit shape is its own authored shape (dimensions in `hero.tscn`), fitted to the measured trunk envelope and
    following a trunk bone each tick. A probe inside the old 1x2x1 box but outside that envelope does not overlap the hero
    hurtbox; a probe on the torso does. Proved live against `hero.tscn` with real frames in idle AND mid-roll
    (`test_honest_hit_geometry_live` precedent). All four consumers (melee, unblockable blade, minion swings,
    projectiles) read it. "Visibly misses" is Live Smoke item 3 only.
12. Heroes still collide with each other and the arena exactly as today: the body collision keeps its 1x2x1 box
    (`BoxShape3D_qp0e8`) and is not the hit shape.

**Presentation (R4, R5, R6, R7)** (`[M]` machine-provable, `[S]` smoke-only, `[R]` review against the File List)
13. `[M]` The blade's dangerous sweep starts at or after the commit (pure mapping, `test_charge_playhead_mapping`
    precedent). `[S]` Each colour holds a readable anticipation pose, and the blade does not visibly pass through the
    defender during the charge-up.
14. `[M]` GREEN covers at least a bound share of its launch travel before the mapped apex time (the bound derived from
    `_charge_launch_velocity`'s shares against the clip apex; target roughly two thirds). `[S]` GREEN visibly crouches
    before take-off.
15. `[S]` No visible pop at charge-up to attack, attack to hit, or attack to recovery, for all three colours (a structural
    test that the two cross-faded edges blend for more than 0 s is optional). The victim's knockdown entry edge is 7-2's.
16. `[R]` Every feel number added or moved (hold timings, blends, crouch lead, hit-shape dimensions) is a `.tres` field or a
    presentation-table constant.

**Records (R12)**
17. A record made by the previous build (FORMAT_VERSION 19) is refused with a reason; the new build writes 20.

**Regression**
18. The colour counter still answers an unblockable (6-6a knockdown / 6-6b counters). Melee, block, deflect, roll and the
    three-tier ladder behave as today apart from the AC 11 hit-shape consequence. The full suite and every integration
    file pass, with superseded tests replaced and named in the Dev Agent Record.

## Measured Facts

All verified by content this session (HEAD `73907e9`).

**M1 Where the unblockable resolves today.**
- Runner pushes a per-tick FACT, never a verdict: `match_runner.gd:1135` `_push_charge_reach_facts` builds `kind =
  CONTACT_CHARGE_REACH_INSIDE` only if `player.is_contact_window_open() and planar.length() <= reach and
  _blade_overlaps_body(hero, enemy)` (`:1181`); `_blade_overlaps_body` (`:1214`) is melee's `hitbox.get_overlapping_areas()`
  identity test against the defender. Called before `advance()` at `:4020`. It sends position-derived `fact_dir`, never
  facing (1-8/R-B3 intact).
- State LATCHES instead of queueing: `match_state.gd:1481` (`is_charge_reach_kind` arm of `push_contact`) writes
  `_charge_reach[slot]` / `_charge_contact_dirs[slot]` (declared `:335`/`:348`). Outside the contact window the latch is
  cleared (`:1540-1542`); inside, `INSIDE` is absorbing and an in-arc bearing is absorbing (`:1543-1549`, 6-1d/R8/R13).
- The single resolution seat is `_resolve_charge_landing` (`:6195`), reached only from the CHARGING arm of
  `_resolve_actions` (`:1810`): `if _resolve_color_counter(...): return` first, then `if not
  player.landing_window.is_running: _resolve_charge_landing(...)`. So today damage/knockdown/orb all happen on the
  LANDING tick (end of `landing_window`), which is why a touch early in the flight knocks the defender down far away.
- Inside the seat: gate `_charge_reach[slot]==INSIDE and _is_in_charge_arc(...) and target.hero.is_alive()` (`:6211`; the
  arc term retires, R8);
  dodge sub-rung `if _iframe_open_at_step3[opposing_slot]` (`:6254`) emits the dodged magnitude (0.0 shipped, so silent)
  with NO orb; else `_landing_package_pending[slot] = true` (`:6290`) and `_grant_landing_orbs(player)` (orb grant is
  applied AT the seat, damage+knockdown+`hit_landed` deferred to `_apply_landing_packages` at step 6b, `:881`/`:6331`).
  Trailing `set_action_state(IDLE)` ends the attack. `is_contact_window_open()` is `landing_window.is_running and
  charge_window.remaining_ticks() <= 1` (`player_state.gd:1064`), i.e. the commit tick through the last flight tick.
- Counter rungs: `_resolve_color_counter` (`:6939`) is judged from the commit tick through the landing tick and is skipped
  only when a non-commit-tick `INSIDE` latch exists (`:6948`), i.e. "after first contact the counter no longer answers".
  The knockdown package (6-6a) is the victim-side write at 6b and is already seat-independent; the colour counter returns
  from the CHARGING arm before the landing. Both sit upstream of / beside the seat R1 moves.

**M2 Dodge reads i-frames at the start of step 3.** `_iframe_open_at_step3[0|1] = hero.is_iframe_open() or
_gets_up_this_tick(hero)` (`match_state.gd:769-770`, field `:422`). `is_iframe_open` is `hero_state.gd:311`. So the
predicate today covers roll i-frames AND get-up i-frames, is read ONCE per tick for seat symmetry, and is consumed only
at the landing tick (`:6254`). Roll i-frames are read-only here (neither consumed nor shortened).

**M3 Hero hit shape vs model.**
- Hero `Hurtbox/HurtboxShape` is `BoxShape3D` 1x2x1 (`hero.tscn:28-29`, used at `:79` AND `:116`): THE SAME sub-resource
  is the body `Collision` shape, so resizing it moves the body collision too (see OQ3).
- Paladin skinned mesh rest AABB (headless, unposed, local): 1.70 x 1.72 x 0.34 (T-pose width from the arms; body DEPTH
  about 0.34 m). Hero root is the body centre with the model grounded at `Mesh` y -1.0, so the box (y -1..+1) is about 0.28 m
  taller than the 1.72 m model. Skeleton joint origins, trunk only (no arm/hand/sword chains), sampled over 9 phases:
  idle x[-0.31,0.13] y[-1.00,0.56]; block x[-0.28,0.07]; attack x[-0.32,0.42]; roll x[-0.62,0.27]; jump_attack x[-0.41,0.29]
  y up to 1.47. Joint origins are not skin surface: torso surface width was NOT measured (see DEVIATIONS D2).
- Consumers of the hero hurtbox: melee `_gather_contact_facts` (`match_runner.gd:2979`), the unblockable
  `_blade_overlaps_body` (`:1214`), minion swings `_gather_unit_facts` (`:3086`), and spell/totem projectiles
  `_gather_projectile_facts` (`:3331`). `test_vertical_alignment.gd:103,159-163` pins "HurtboxShape mirrors the body box".
- Minion hurtboxes (report only; rework is 7-3): unit 0.6x1.2x0.6 (`unit_actor.tscn:8-9`), totem 0.8x1.4x0.8
  (`totem_actor.tscn:6-7`); the unit hitbox is 1x1.2x1.4 (`:11-12`).

**M4 Sword hitbox.** One `Hitbox` Area3D (layer 4, mask 2) with ONE `BoxShape3D` 1x1x1 (`hero.tscn:31-32,105-107`) shared
by every colour and by melee; there is no per-colour shape. `hero.gd:139` `_track_weapon_bone` writes the shape's POSITION
every tick from the sword joint by forward kinematics (`:150ff`), never its rotation; the node yaw is the one shared
facing yaw. The overlap reflects tick N-1 (standing one-tick physics lag).

**M5 Presentation knobs today.** `unblockable_swing_at_commit` exists, OFF (`balance_config.gd:449`,
`balance_config.tres:146`); ON had no observable effect on GREEN (6-1d/R15). `_CHARGE_HOLD_KNOBS`
(`animation_controller.gd:419-423`): RED start .30 / end .45 / frac .15; BLUE .40 / .55 / .17; GREEN .40 / .55 / .5744;
strike frames 0.8450 / 0.9067 / 2.1542 s (`:~311-313`). GREEN's frac 0.5744 x 2.1542 = 1.237 s, which is `jump_attack`'s
measured apex (t=1.2375): the held pose is already airborne. Timing authored: chargeup 1.0 s, launch .25/.30/.45 s,
distance 2.5/3.0/4.5, reach 4/6/3.5, arc 140/40/360 (`balance_config.tres:133-145`; the arcs retire, R8). Clips are re-tempoed by playhead
`seek()` each tick (`on_charge_progress`, `:~696`), not by `tools/retime_clips.gd`, which rescales only `attack` and
`roll`; `tools/measure_charge_strike_frames.gd` is the measuring tool. Blends: `LOCOMOTION_BLEND_SECONDS = 0.25`
(`:103`) applies to locomotion clips only; evented transitions (including charge to idle) go through `_restart` with NO
blend (`:1258`, 3-0a/R5), except `BLOCKING -> IDLE`.

**M6 Blast radius (tests that name the landing, its latch, the arc, the multiplier, the version or the hero hit shape).**
State: `test_unblockable_initiation.gd` (358-466: landing reads the answer on the expiry tick only; arriving on the expiry
tick lands; `:544/562` pin the CHARGING-time `telegraph` value), `test_unblockable_tracking_and_reach.gd` (554-879: contact
credits nothing in chargeup, verdict rests, "exactly once", reset clears latch; ARC, outside that range: `:198`
`test_a_defender_who_leaves_the_frozen_line_after_the_commit_is_missed`, `:292`
`test_each_colour_judges_its_own_arc_against_the_committed_direction`, `:317` `test_the_arc_never_widens_an_outside_kind`,
`:734`, `:756`, `:785`, `:806`, `:826` (R8/R13), the `ARC_DEGREES` constants, `:1060-1062`), `test_unblockable_defense.gd`
(1220-1328 dodge rung at the landing, `get_up` iframes `:1978`, `:2185`; 1689-2217 package order, floors, simultaneous
landings; `:2316` comment; 2616/2639 funnel seats), `test_click_to_commit.gd:182-292`, `test_orbs_economy.gd:109-322`,
`test_hero_cast.gd` (`:426`, get-up dodge `:514`), `test_action_state.gd:343`, `test_balance_authoring.gd` (`:165` arcs,
`:337-338` the `<= 1.0` multiplier bound), `test_data_resources.gd` (`:123-126` and `:144` authoring lists),
`test_determinism.gd:1607` (comment only; `_golden_config` never sets the field), `test_pitch_*.gd`,
`test_replay_identity.gd` (`:142-146` entry retires; new key classified HASHED), `test_card_observation.gd:361-362`
(45 -> 46), `test_record_file.gd` (`:234`, `:1366` pins; new v19 refusal fixture).
Integration: `test_honest_hit_geometry_live.gd` (`:61`/`:64` `BODY := 1.0`, `:305` `BODY * 0.4`), `test_unblockable_reach_live.gd`
(`:132`), `test_counter_reactions_live.gd`, `test_defense_reactions_live.gd`, `test_charge_telegraph_dispatch_live.gd`,
`test_vertical_alignment.gd` (`_span` must handle a non-box shape), `test_contact_pipeline.gd` (reads the authored `.tres`),
`test_projectile_flight_live.gd`, `test_unit_combat_live.gd`, and the hit-shape-sensitive live files not yet named:
`test_unit_attack_live.gd`, `test_fireball_live.gd`, `test_live_attack.gd`, `test_chain_retrigger.gd`,
`test_cast_presentation_live.gd`, `test_boulder_and_skull_live.gd`, `test_hole_vs_in_flight_live.gd`,
`test_unit_strike_alignment_live.gd`. Presentation: `test_charge_playhead_mapping.gd` (`_CHARGE_HOLD_KNOBS`),
`test_charge_playhead_live.gd`, `test_rig_clips.gd`, `test_hero_reaction_clips.gd`, `test_clip_timing.gd`.
`test_arena_edge_live.gd:56-62` names `BoxShape3D_qp0e8` and passes while the body keeps that sub-resource. The dev pass runs
all of these first and lists each one actually moved (R-D6 discipline).

**M7 Golden.** `GOLDEN = "941958c52605abbcd1edf972e002543601325e5a9f98dfce569628c12f75871f"` (`test_determinism.gd:1307`);
`RecordFile.FORMAT_VERSION = 19` (`record_file.gd:330`); per-player snapshot key set = 45 keys (pinned
`test_card_observation.gd:361-362`, "FORTY-FIVE as of story 6-5f"). The fixture never enters CHARGING (its only cast is
`ModeKind.BASIC`, `test_determinism.gd:1609`, `:791`, `:2395`) and is built from in-test config only (BC/R3), so R1-R14 alone
would leave the hash unmoved; R15's new key does move it (Golden Prediction).
FORMAT_VERSION must move 19 -> 20 (R12). The documented posture is to bump on SILENT BEHAVIOURAL DIVERGENCE even when the
recorded shape did not change (`record_file.gd:158-170` 6-1, `:188-194` 6-7, `:196-209` 6-9, `:298-306` 6-5f, `:308-322`
6-5g, the last a pure behaviour change 18 -> 19). Measured: a v19 record containing a mode-2 charge replays to a different
outcome, because the charge-reach facts are recorded (`match_runner.gd:1191` `capture_push_contact`) and replayed verbatim,
so the whole divergence is state policy: (1) INSIDE on launch tick k with i-frames closed, then open on the landing tick:
v19 silent dodge (`:6254`, no orb), 7-8 a hit on tick k with damage, knockdown and orb; (2) INSIDE only while i-frames are
open, then clear: v19 a hit at the landing (absorbing latch, `:1543-1549`), 7-8 a miss; (3) INSIDE only out of arc (BLUE at
40 degrees): v19 a miss (`:6211`), 7-8 a hit; (4) when both hit, the damage and knockdown tick moves from the landing to
tick k, so every later hash differs. Second, shape cause: retiring `BalanceConfig` fields (arcs, multiplier) changes the
`balance` channel row (`_resource_values`, `record_file.gd:781-787` captures every script var), and a v19 file's retired keys
would be silently dropped by `_rebuilt`'s `res.set` (`:994`). Hard refusal of v19, no shim.

**M8 Supersessions (this story replaces, never edits the closed files, E5-R/R7).** `6-1c` AC 2/AC 4 (the landing fires when
the landing window closes; the single-resolution-at-landing language); `6-1c` AC 3 (already superseded by `6-1d` AC 6);
`6-1c` AC 5 (the per-colour arc) and the arc half of AC 3; `6-1d` AC 3's "the frozen committed direction (arc test) stays
state policy" clause; `6-1d` AC 4's "through the tick `landing_window` closes" (the span now ends at the first touch) and
`6-1d` AC 6 itself ("touched at ANY evaluated tick before dodging away" is no longer guaranteed a hit: an i-frame touch then
a clear is a miss); `6-1d` AC 5 and `6-1d/R8` + `6-1d/R13` (latch semantics: the bearing is latched with the verdict and an in-arc contact
is absorbing, both of which exist only because resolution waits for the landing); `6-1d/R9` holds (the latch stays as a per-tick fact, R10); `3-0a/R5` ("a transition wins immediately, no blend") for the two edges OQ7
cross-fades; the `1-7` hurtbox convention "Mirrors the body collision box" (`hero.tscn:113` editor_description); `3-0b`'s pin
(6) second half, `test_vertical_alignment.gd:161-163` (the `:159-160` body-box half STAYS and is AC 12's proof); `5-6` AC 7/AC 8 (the dodge rung reading the step-3 latch ON THE LANDING TICK, and
its silent multiplier path, `dodged_unblockable_damage_multiplier`); `5-6` Ruling 1b's "dodge = reduced damage" as a
live rung; `6-6b` AC 3's "judged through the landing tick"
(the judged span now ends at the first touch, R13); `6-6a` AC 3/R-PRESS wording "owed after the landing" (the package is owed
after the touch). Held unchanged: `6-6a` victim package contents, floors and order; `6-6b` colour match rules.

## Golden Prediction

The golden MOVES for exactly one named cause: R15's new per-player hit-once key (key set 45 -> 46; its at-rest value is
0, and the fixture hashes idle players every tick, so the key's presence alone changes the hash). Every other value is
unmoved: no RNG draw, no `_golden_config()` edit, no at-rest value of an existing key changes (`telegraph` stays
`[NO_TELEGRAPH_COLOR, 0]`, `landing` stays 0), and the paths the golden executes outside CHARGING are not edited
(`_iframe_open_at_step3` / `_gets_up_this_tick`, step-3 ordering, `_apply_landing_packages`' loop shape, `push_contact`'s
non-charge path, the step-4 melee ladder). One re-baseline, measured in BOTH directions: (a) with the new key removed the old
`941958c5...` reproduces; (b) with it restored the new literal is stable across two runs. FORMAT_VERSION moves (R12), which
the golden does not read (a record carries no hash). Hero-shape and presentation changes are not golden falsifiers.

## Live Smoke

Solo on flip `[0, 3]`: P1 keyboard casts with the 6-D1 keys X / V / B; the operator defends on the pad as P2. R-D6 is
re-invoked at the gate and SPENT at close-out (nothing is declared playable until the operator's own GREEN pass).
Flip procedure: with the Godot editor closed (`Get-Process *godot*` empty), text-edit the line `slot_controller_kinds =
Array[int]([0, 3])` under `script = ExtResource(...)` of node `Main` in `src/main/main.tscn`; revert with `git checkout --
src/main/main.tscn` before ANY suite run and before staging (7-8 makes no intentional `main.tscn` change, so the blanket
revert is allowed); inspect `git diff project.godot` for collateral.
1. Knockdown happens exactly when the blade touches, never from a distance, all three colours (GREEN first).
2. A roll whose i-frames cover the touch saves you; a blade still touching after the i-frames close hits.
3. A blade grazing the air beside you does not hit (unblockable and melee).
4. The charge-up reads as a held anticipation, then a fast strike (Genichiro rhythm), per colour.
5. GREEN travels on the way up, not straight up then across.
6. No pops between charge-up, attack and recovery.
7. Melee regression with the new hit shape; the colour counter still works.
8. fps stable.
9. A lethal hit mid-flight: the attacker freezes mid-leap at round over (OQ9), no crash, `_reset_player` restores it; the
   attacker's ChargeMarker stays lit from the hit to the landing (Shapes hide only on transitions).

## Non-Goals

All 7-9 unless noted: knockdown immunity after get-up; unblockable mana cost 1; damage 9 to 6; steering after the attack
starts; colour-counter timing tied to the strike moment; weapon glint before the strike; movement speed; +1 mana for a
counter. New Mixamo clips: none. Upper/lower body split and hit-reaction sliding: 7-2. Minion hurtbox rework: 7-3
(measured and reported only). Telegraph symbols: stay under F3. The 7-7 retune inputs (reach/homing, dodge cost, GREEN
profile numbers) are not retuned here; 7-8 only supplies the mechanism they will tune.

## Open Questions (mechanism; recommendation first)

Per the CLAUDE.md autonomy rule these are the operator's to confirm because they shape the codebase or behaviour at the edges.
1. **Where is "already hit" kept? (R15, closed.)** One new HASHED per-player snapshot key (small int, rest value 0, key name
   the dev pass's; two non-rest values, see OQ4), set on the first touch (a dropped touch then a counted touch moves the key from "touched" to "hit landed"), cleared at the cast seat, at `_reset_player` and at the landing exit; it gates
   AC 3 and R13's span. Classified `HASHED` in `test_replay_identity.gd`, NOT a fifth UNHASHED argument. Derivation from
   existing state is rejected: `landing_window.start(0)` ends the flight, and `_charge_launch_velocity` (`:7901-7914`) and
   `_is_commit_tick` (`:6879-6881`) both derive from the two windows' durations and remaining ticks, so any "spent" encoding
   in a window stops the travel or breaks the commit-tick rule. Reusing `_charge_reach` with a spent value is illegal (its
   `UNHASHED` argument (c) holds only because the tick never produces it, and the next `push_contact` would overwrite it).
   Riding the `telegraph` key is rejected: telegraph is a presentation-consumed fact. A lethal hit writes no knockdown and a
   knockdown can expire before a long flight ends, so neither is a usable proxy. The attacker stays CHARGING until
   `landing_window` closes.
2. **One seat, renamed or not.** Recommend: keep ONE resolution function (`_resolve_charge_landing`, renamed
   `_resolve_charge_contact`), called from the CHARGING arm on the first counted touch tick (no IDLE write there); the
   landing exit writes IDLE whether it hit or missed (5-6's one-write-per-outcome holds: the hit outcome has no attacker
   state write). Keeps the 1-8/R-B3 split: the runner pushes only position-derived kind and direction, damage stays in the
   deferred package at 6b. There is no arc (R8): `_charge_contact_dirs` and its clears (cast seat `:5989-5990`, `:8179-8180`)
   retire, since the arc was its only reader; the counter span and the facing track read `_charge_reach_dirs`, unaffected.
3. **Hit shape vs body collision. (R9, closed.)** The hurtbox gets its OWN sub-resource on `Hurtbox/HurtboxShape`; `Collision`
   keeps `BoxShape3D_qp0e8` (AC 12). The shape follows a trunk bone each tick (`_track_weapon_bone` precedent), so no second
   rotation source (1-7b): it takes `drive()`'s single yaw or is yaw-invariant. The dev pass MEASURES FIRST (D2): skinned-vertex
   torso half-width and depth in idle, block, attack, roll and jump_attack (not joint origins), plus where the defender's trunk
   sits during the roll excursion; the dimensions are chosen from that. All four consumers identify the hero via
   `area.get_parent()` on the layer-2 `Hurtbox`, so they re-point with no code change. `test_vertical_alignment.gd`'s
   "HurtboxShape mirrors the body box" pin (`:161-163`) is superseded and named in the Dev Agent Record.
4. **Colour counter. (R13, closed.)** Span: commit tick to the FIRST touch (counted or i-frame-dropped), today's rule kept.
   Today an i-frame touch closes the span because the absorbing INSIDE is read at `:6948`; with the latch now a per-tick fact
   the single key (OQ1) must therefore record two facts: a dropped touch closes the counter span (AC 10) but does NOT spend the
   attack (AC 7), while a counted touch does both. Without that a rolling hero (who may cast defense,
   `test_unblockable_defense.gd:223`) could roll through the blade and then counter. Hence the key is a small int, rest value 0
   (none), one value for "touched, span closed", one for "hit landed".
5. **Get-up i-frames in the dodge rule. (R10, closed.)** The `_iframe_open_at_step3` predicate (roll OR get-up, plus the
   1-9/R2 grace tick) is reused UNEDITED; it is read once per tick for seat symmetry, and Honed Bolt's strike seat reads it
   too (`:6588`). The INSIDE latch becomes this tick's fact, otherwise an i-frame touch would count after the i-frames close
   even with no touch (AC 8). The co-location no-push case (`match_runner.gd:1158`) then re-reads the previous tick's fact;
   accepted. The one-tick lag is fine: the fact pushed before `advance()` at tick N reflects tick N-1's physics, the seat runs
   at step 3 of N and the package applies at 6b of the same `advance()`.
6. **`dodged_unblockable_damage_multiplier`. (R11, closed.)** Retires, with no keep-at-0 alternative. List:
   `balance_config.gd:474` (and its doc block), `balance_config.tres:148`, `match_state.gd:6254-6277` (the dodged-magnitude
   branch collapses to nothing), `test_unblockable_defense.gd:1220` (renamed to the touch-tick rule), `:1236` (retuned-multiplier
   test, retired), `:2316` (comment), `:2639` (funnel test, retired), `test_balance_authoring.gd:337-338`,
   `test_data_resources.gd:123-126`, `test_determinism.gd:1607` (comment only).
7. **Charge-up rhythm.** Recommend measuring first (AC 13): tune `_CHARGE_HOLD_KNOBS` and `unblockable_swing_at_commit` ON
   for RED/BLUE; GREEN needs a clip-side crouch lead (M5, 6-1d/R15), expressed as a new per-colour entry in the same table
   (feel numbers in data/presentation tables per R7). Cross-fade at the charge to attack and attack to recovery edges
   replaces the unblended `_restart` for those two edges only (R6), authored as a knob.
8. **Record compatibility. (R12, closed.)** FORMAT_VERSION 19 -> 20, hard refusal of v19, no shim; causes in M7.
9. **Lethal mid-flight hit. (R16, closed.)** Today the landing writes IDLE before step 8 writes DEAD; under R1 a lethal hit
   mid-flight leaves the attacker CHARGING, held mid-motion by the round-over freeze (`telegraph` still reported) until
   `_reset_player`. Accepted. Live Smoke item 9 is its check; if it looks wrong on the smoke, the fix belongs to 7-2 polish,
   not this story.

## Tasks

- [x] T1 (AC 1-6, 10) Resolve the unblockable on the first counted touch tick in the one existing seat; spend once via the
  new hashed key; retire the arc (exports, `.tres`, `unblockable_arc_degrees_for`, `_is_in_charge_arc`, the seat gate,
  `_charge_contact_dirs` and its classification entry); keep the flight (OQ1, OQ2, OQ4).
- [x] T2 (AC 7-9) Replace the landing-tick dodge rule with the touch-tick rule, latch as this tick's fact; retire the
  multiplier (OQ5, OQ6).
- [x] T3 (AC 11-12) Hero hit shape: measure first, then the bone-following hit shape; re-pin `test_vertical_alignment.gd`,
  `test_honest_hit_geometry_live.gd`; live proof in idle and mid-roll (OQ3).
- [x] T4 (AC 13-16) Re-tempo charge-up, GREEN crouch lead and blends as authored knobs; measure before and after (OQ7).
- [x] T5 (AC 17-18) Run every file in M6 first, list each moved test, replace with its new behaviour test, mutation-prove the
  new guards, measure the golden in both directions (key removed reproduces `941958c5...`), re-baseline once, commit proofs
  under `test/`. FORMAT_VERSION 19 -> 20: new header paragraph in `record_file.gd`, both pins in `test_record_file.gd`
  (`:234`, `:1366`), and a v19 refusal fixture on the `test_a_v18_record_is_refused_with_a_reason` (`:900`) precedent.
- [ ] T6 Live Smoke per above; close-out rulings and supersession list into the decision-log.

## Dev Notes

- Read first: `match_state.gd:1481-1550` (latch arm), `:1810` (CHARGING arm), `:6195-6296` (seat), `:6331` (package),
  `match_runner.gd:1135-1220` (facts), `hero.tscn:28-32,79,105-116`, `animation_controller.gd:419ff`.
- Invariants to keep: F1 (one `_physics_process`, in `match_runner.gd`), D3(a) `Input.*` only in controllers, D3(b)/A2 no
  global RNG/`Time`/`OS`/`Engine` in `src/state/`; `bash test/run_all.sh` with `GODOT=/c/Godot/godot.exe` (about 6 minutes).
- BC/R3 boundary (SC/R6): authored balance values do not move tests, but a change that adds a seat or makes an action
  refusable does. A touched-during-i-frames "not spent" attack is new behaviour on an existing seat: expect moved tests.
- One-tick lag stands: the runner's overlap reflects tick N-1; "that tick" means the tick the fact is processed (AC 1).
- Do not edit the `_iframe_open_at_step3` predicate or `_gets_up_this_tick` (R10): Honed Bolt's strike seat reads them.
- A `hero.tscn` shape change can break live layouts sized to the 1 m box (`test_honest_hit_geometry_live.gd` `BODY`); run the
  M6 live list before and after.
- Git discipline: show full diff before staging; docs and code never share a commit; ASCII messages via a temp file outside
  the repo; trailer `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` (the repo constant, 6-1c/R7, E6-C/R4).

## Dev Agent Record

### Agent Model Used
Sonnet 5.5 (story authoring only); dev pass: Opus 5.5 (2026-10-07).

### Debug Log

**T0 before-baseline** (before the first edit, no stash): state 1248 tests / 0 failed / 11839 assertions, RESULT PASS;
integration 78 files, all PASS (`C:\dev\_78-suite-before-state.txt`, `C:\dev\_78-suite-before-int.txt`).

**T3a MEASURED FIRST (D2, R9)** -- recorded here before any hit-shape dimension was chosen. Tool:
`tools/measure_torso_envelope.gd` (headless, CPU-skinned vertices: per bind FK bone pose x Skin bind pose, weight-blended;
9835 vertices; a vertex is TRUNK when its dominant bone is Hips/Spine/Spine1/Spine2/Neck/Head; legs and arms reported
apart). Model frame: feet y 0, +z facing; skeleton->model transform measured identity. 25 phases per clip. Raw output
`C:\dev\_78-torso.txt`.

Absolute trunk extents (model frame, union over the clip), width = x span, depth = z span:

| clip | trunk x | trunk y | trunk z | per-phase width / depth range |
|---|---|---|---|---|
| idle | [-0.249, 0.174] | [0.735, 1.570] | [-0.186, 0.270] | 0.414-0.419 / 0.444-0.450 |
| block | [-0.251, 0.171] | [0.608, 1.426] | [-0.179, 0.329] | 0.414-0.419 / 0.500-0.504 |
| attack | [-0.276, 0.479] | [0.567, 1.564] | [-0.190, 0.892] | 0.390-0.641 / 0.422-0.650 |
| roll | [-0.646, 0.199] | [-0.130, 1.650] | [-0.496, 0.751] | 0.393-0.805 / 0.386-0.865 |
| jump_attack | [-0.461, 0.235] | [0.443, 2.649] | [-0.510, 0.657] | 0.390-0.636 / 0.371-0.800 |

So the standing torso is ~0.42 wide x ~0.45-0.50 deep (half-width ~0.21-0.25, half-depth ~0.22-0.33 around its own
centre), against the 1 x 1 footprint of the old box.

Relative to each candidate tracking bone (the shape follows a bone by POSITION only): trunk RADIAL max = largest planar
distance of a trunk vertex from the bone; trunk y and feet y relative to the bone:

| bone | idle | block | attack | roll | jump_attack | trunk y rel (all clips) | feet y rel (idle) |
|---|---|---|---|---|---|---|---|
| Hips | 0.268 | 0.338 | 0.592 | 0.758 | 0.660 | [-0.533, 0.763] | -0.817 |
| Spine | 0.262 | 0.329 | 0.547 | 0.658 | 0.619 | [-0.458, 0.657] | -0.923 |
| Spine1 | 0.247 | 0.297 | 0.458 | 0.541 | 0.535 | [-0.372, 0.535] | -1.044 |
| Spine2 | 0.237 | 0.277 | 0.422 | 0.489 | 0.412 | [-0.483, 0.443] | -1.183 |

Roll excursion: the Hips joint stays at the root planar origin (|x|,|z| <= 0.002) for the whole clip while the TRUNK
leaves it: trunk centroid at t=0.250 is (-0.421, 0.061, -0.213) (lying on the ground, beside and behind the root),
t=0.271 (-0.353, 0.253, -0.300); Spine2 there sits at (-0.278, 0.009, -0.140) / (-0.233, 0.143, -0.281), i.e. it travels
WITH the trunk while the hips do not. Trunk y drops to [-0.130, 0.309] at t=0.250. jump_attack carries its jump in the
clip: Hips y rises 0.81 -> 1.955 (t=1.222), trunk y up to 2.649.

**T4 AC 14 bound, FIXED BEFORE MEASURING:** GREEN must cover **>= 0.60** of its launch travel (the
`_charge_launch_velocity` front-loaded shares, summed over the launch ticks whose mapped playhead has not yet passed
the clip apex) before the mapped apex time. 0.60 sits below the ~2/3 target so the knob keeps tuning room.
Measured value recorded in the T4 knob table below.

**T3b hit shape CHOSEN FROM THE NUMBERS ABOVE:** a `CylinderShape3D` (`CylinderShape3D_hurt`), radius **0.30**, height
**1.65**, its centre `HURTBOX_DROP` = **0.375** below `mixamorig_Spine2`, moved by POSITION every tick
(`HeroActor._track_trunk_bone`, the `_track_weapon_bone` precedent). Why: Spine2 has the smallest radial trunk excursion in
block / attack / roll / jump_attack and travels with the trunk through the roll; a cylinder is yaw-invariant, so the
`Hurtbox` node is never rotated and there is no second rotation source (1-7b). 0.30 covers the standing trunk (radial max
0.237 idle, 0.277 block); the top (+0.45) covers the head (max +0.443 above Spine2 in any clip) and the bottom (-1.20) the
feet (-1.183 in idle). ACCEPTED, measured residue: in attack / roll / jump_attack the trunk's outer edge reaches 0.41-0.49
from Spine2, so up to ~0.19 m of extreme-pose trunk surface lies outside the cylinder; the body `Collision` keeps
`BoxShape3D_qp0e8` (AC 12). Live AC 11 proof (`test_hero_hit_shape_live.gd`): 10 idle + 5-7 mid-roll real frames, the shape
within 0.01 m of the trunk bone (body-relative, against the pose it was computed from -- mid-roll the trunk moves ~0.2 m per
rendered frame, so a same-frame comparison measures the standing `_track_weapon_bone` sub-frame lag, not the tracking), a
probe on the torso overlaps the hurtbox, and a probe inside the old box (proved by overlapping the body box) 0.64 m off the
trunk axis does not.

**T1/T2 state (OQ1/OQ2/OQ4/OQ5/OQ6):** the ONE seat is `_resolve_charge_contact` (renamed from `_resolve_charge_landing`),
called from the CHARGING arm on every committed tick whose fact is `INSIDE` until the hit-once key reads HIT; it writes no
action state. The landing exit (`landing_window` stopped) writes the one `IDLE` and rests the key. New hashed per-player key
`charge_contact` (`PlayerState.charge_contact`, small int: 0 NONE / 1 TOUCHED / 2 HIT), rest 0, cleared at the cast seat,
the landing exit, the knockdown abandonment (victim side, `_apply_landing_packages`) and `_reset_player`. A dropped touch
(`_iframe_open_at_step3` open, the predicate UNEDITED, `_gets_up_this_tick` UNEDITED) writes TOUCHED and returns; a counted
touch writes HIT, owes the 6b package and grants the orb at the seat. `push_contact`'s charge-reach arm is now
`_charge_reach[slot] = kind if window open else REACH_UNKNOWN` (this tick's fact, R10). Counter (R13, AC 10): judged while
`charge_contact == NONE`, and on non-commit ticks not on a tick whose fact is `INSIDE` (commit tick: counter beats a
same-tick touch, as before). Arc retired: three exports + `.tres` lines, `unblockable_arc_degrees_for`, `_is_in_charge_arc`,
the seat conjunct, `_charge_contact_dirs` + its replay-identity entry (UNHASHED members stay 4). Multiplier retired: export,
`.tres` line, the dodged branch. Implementation additions: the CHARGING arm also requires `not charge_window.is_running`
before offering a touch (defence in depth; `push_contact` already writes INSIDE only inside the window); the key is also
cleared at the knockdown abandonment so it rests at 0 whenever no attack flies (OQ1 named three clears; a fourth keeps the
rest value honest). AC 18 regression: counters, melee, block, deflect, roll and the ladder unchanged apart from AC 11 --
all 6-6a/6-6b files green unchanged.

**Golden (R15, both directions MEASURED):** with the new key present the hash is `1b1478ac310f...0e98` (two separate runs,
identical); with the key erased from `PlayerState.to_snapshot()` and every other 7-8 change in place, `941958c5...` is
reproduced exactly (the old literal passed). Restore by copy-back from `scratchpad/bak_player_state.gd`, SHA256
`ce9711c4...f954` before and after. ONE re-baseline: `941958c5...` -> `1b1478ac...`. No other movement. Key set 45 -> 46.

**FORMAT_VERSION** 19 -> 20 (R12): header paragraph in `record_file.gd`, both `test_record_file.gd` pins, new
`test_a_v19_record_is_refused_with_a_reason` on the v18 precedent. Moved tests were reversed BEFORE the bump (the golden
re-baseline ran with the version still at 19).

**T4 knob table (every feel number authored or moved; all presentation constants or `.tres`, AC 16):**

| knob | where | before | after |
|---|---|---|---|
| `unblockable_swing_at_commit` | `balance_config.tres` | false | **true** |
| RED `hold_start` / `hold_end` / `hold_fraction` | `_CHARGE_HOLD_KNOBS` | 0.30 / 0.45 / 0.15 | **0.15** / 0.45 / 0.15 |
| BLUE `hold_start` / `hold_end` / `hold_fraction` | `_CHARGE_HOLD_KNOBS` | 0.40 / 0.55 / 0.17 | **0.18** / 0.55 / 0.17 |
| GREEN `hold_start` / `hold_end` / `hold_fraction` | `_CHARGE_HOLD_KNOBS` | 0.40 / 0.55 / 0.5744 (apex) | **0.18** / 0.55 / **0.3559** (crouch) |
| GREEN `crouch_lead` (new) | `_CHARGE_HOLD_KNOBS` | -- | **0.42** |
| `JUMP_ATTACK_CROUCH_SECONDS` (clip fact) | `animation_controller.gd` | -- | 0.7667 (measured, hips min 0.5605) |
| `JUMP_ATTACK_APEX_SECONDS` (clip fact) | `animation_controller.gd` | -- | 1.2375 (6-1b measurement; 120 Hz hips scan peaks 1.2333) |
| `CHARGE_ENTRY_BLEND_SECONDS` (new) | `animation_controller.gd` | instant cut | 0.15 |
| `CHARGE_EXIT_BLEND_SECONDS` (new) | `animation_controller.gd` | instant cut | 0.2 |
| `CylinderShape3D_hurt` radius / height | `hero.tscn` | (box 1 x 2 x 1) | 0.30 / 1.65 |
| `HURTBOX_DROP` | `hero.gd` | -- | 0.375 |

Measured before/after: AC 14 GREEN launch travel before the mapped apex (authored C=60, L=27): **0.6914** with the new knobs
(bound 0.60 fixed beforehand); **0.0727** with the pre-7-8 GREEN knobs under the ON remap (M6, measured); under the
shipped pre-7-8 state (knob OFF, commit progress 0.69 > hold_end 0.55, playhead already past the apex at the commit) it is
0 -- DERIVED from the mapping, not run. AC 13: on the commit tick the shipped mapping puts each blade at
or before its held pose (RED 0.127 s, BLUE 0.154 s, GREEN 0.767 s); with the knob OFF (M7) at 0.584 / 0.521 / 1.115 s, i.e.
the sweep 6-1c measured as ~64 / 49 / 31 % spent by the commit.

**Mutation table (provenance MEASURED; each file copied to `scratchpad/mut_bak/` first, restored by copy-back, SHA256
verified both ways -- every restore printed MATCH; only the affected test file run, never the suite):**

| # | mutation | file(s) | run | result |
|---|---|---|---|---|
| M1 | hit-once key: drop `charge_contact != HIT` from the CHARGING arm | match_state.gd | `-- honest_contact` | RED: `test_an_unblockable_hits_at_most_once` (10 `hit_landed`, hp 0.0, 9 orbs), `..._first_closed_tick_hits` |
| M2 | i-frame drop: delete the `_iframe_open_at_step3` early return | match_state.gd | `-- honest_contact` | RED: 4 tests incl. `..._first_closed_tick_hits`, `..._iframe_touch_then_clear_is_a_miss` |
| M3 | latch absorbing again (6-1d `INSIDE` kept within the window) | match_state.gd | `-- honest_contact` | RED: `test_an_iframe_touch_then_clear_is_a_miss` (both slots hit 90.0, 1 `hit_landed`, 2 orbs) |
| M4 | counter span not closed by a dropped touch (no TOUCHED write) | match_state.gd | `-- honest_contact` | RED: `test_a_dropped_touch_closes_the_counter_span` (attacker STUNNED by a counter after the touch) + 2 key tests |
| M5 | hit shape reverted to the body box (scene) and tracking off (actor) | hero.tscn, hero.gd | `test_hero_hit_shape_live.gd` | RED: 51 failures, incl. "a probe inside the old 1x2x1 box but 0.64 m off the trunk axis overlaps the hurtbox (AC 11)" |
| M6 | GREEN knobs back to pre-7-8 (apex hold, no crouch lead) | animation_controller.gd | `-- charge_playhead` | RED: AC 14 travel 0.0727 < 0.60; held pose 1.2374 s after the crouch |
| M7 | `unblockable_swing_at_commit = false` | balance_config.tres | `-- balance_authoring` | RED: AC 13, all three colours past their held pose on the commit tick |

**Moved tests (each named with the AC that replaces it):**
- `test_unblockable_tracking_and_reach.gd`: RETIRED `test_a_defender_who_leaves_the_frozen_line_after_the_commit_is_missed`,
  `test_each_colour_judges_its_own_arc_against_the_committed_direction`,
  `test_a_narrow_arc_judges_the_bearing_at_contact_so_a_strafe_after_the_touch_is_hit`,
  `test_a_narrow_arc_judges_the_bearing_at_contact_so_drifting_in_after_the_touch_is_missed`,
  `test_an_in_arc_touch_on_the_commit_tick_survives_later_out_of_arc_touches`, `test_any_in_arc_touch_during_the_flight_is_a_hit`,
  `test_a_flight_touched_only_out_of_arc_still_misses` -> NEW `test_a_counted_touch_hits_whatever_the_attackers_facing` (AC 6,
  R8); RENAMED `test_the_arc_never_widens_an_outside_kind` -> `test_an_outside_fact_on_every_tick_never_lands` (AC 5);
  `test_launch_progress_is_below_one_until_the_landing_tick_and_one_exactly_on_it` touches on the landing tick only, "no damage
  before the landing" -> "no touch, no damage" (AC 1); `test_a_hero_killed_mid_launch_takes_the_round_over_freeze` and
  `test_a_forced_dead_hero_mid_launch_takes_the_dead_carve_out` touch nothing at the commit / death tick (AC 1: a commit touch
  now hits there); RENAMED `test_the_debug_reset_clears_the_contact_verdict_and_its_bearing` ->
  `test_the_debug_reset_clears_the_contact_fact` (R8 bearing retired); comment/message only:
  `test_a_defender_who_enters_the_frozen_line_after_the_commit_is_hit`,
  `test_a_defender_touched_on_one_launch_tick_is_hit_even_after_it_clears_the_blade`,
  `test_a_one_tick_chargeup_does_not_inherit_the_previous_attacks_verdict` (R10).
- `test_unblockable_defense.gd`: RENAMED `test_an_open_iframe_dodges_the_landing_silently_at_the_shipped_multiplier` ->
  `test_a_touch_during_open_iframes_does_nothing_at_all` (AC 7); RETIRED `test_a_retuned_dodge_multiplier_emits_at_the_surviving_magnitude`
  and `test_the_dodged_unblockable_seat_runs_through_the_damage_funnel` (AC 9, R11);
  `test_knockdown_from_charging_abandons_the_chargeup_and_keeps_the_spend` asserts the abandoned key rests instead of the
  retired bearing (OQ1); comment only `test_a_counter_outranks_an_open_iframe`, `test_a_dodge_stuns_nobody`.
- `test_balance_authoring.gd`: arc bound removed from `test_authored_unblockable_values_are_positive` (R8); RETIRED
  `test_authored_dodge_multiplier_is_bounded_above` (R11); REPLACED `test_the_swing_at_commit_knob_is_authored_off` ->
  `test_the_shipped_mapping_starts_each_sweep_at_or_after_the_commit` (AC 13).
- `test_data_resources.gd`: `E1_BALANCE_FIELDS` loses the three arc fields and the multiplier (R8, R11).
- `test_replay_identity.gd`: `_charge_contact_dirs` leaves the UNHASHED list, `player_state.charge_contact` joins HASHED (R15);
  FORMAT_VERSION pins 19 -> 20 in `test_a_saved_and_reloaded_boulder_run_replays_to_the_identical_hash`,
  `..._counterspell_run_...`, `..._timed_and_in_flight_run_...` (R12; NOT in the story's M6 list -- see dev-pass deviation DP2).
- `test_card_observation.gd` `test_the_observation_channel_adds_no_snapshot_key` and `test_draw_delay_and_reshuffle.gd`
  `EXPECTED_PLAYER_SNAPSHOT_KEYS`: 45 -> 46, `charge_contact` (R15; the second file is the first's twin pin, not in M6).
- `test_determinism.gd` `test_state_matches_golden`: GOLDEN re-baselined (R15); comment-only edits.
- `test_record_file.gd`: `test_the_format_version_and_the_widened_contact_row_move_together`,
  `test_the_contents_validation_bumped_no_version_and_widened_no_required_key` pin 20; NEW `test_a_v19_record_is_refused_with_a_reason` (AC 17).
- `test_charge_playhead_mapping.gd`: `_playhead` reads `charge_playhead_for` (GREEN knee); NEW
  `test_with_swing_at_commit_the_sweep_starts_at_or_after_the_commit` (AC 13), `test_green_covers_most_of_its_launch_travel_before_the_apex`
  (AC 14), `test_greens_held_pose_is_grounded_before_take_off` (AC 14), `test_the_two_cross_faded_charge_edges_blend` (AC 15).
- Integration: `test_vertical_alignment.gd` pin (6) second half superseded ("mirrors the body box" -> never shares the body's
  shape; `_span` reads a cylinder), first half kept as AC 12's proof; `test_honest_hit_geometry_live.gd` -- frozen placement
  re-derived (defender's hit-shape centre on the blade, AC 11), `charge` layout re-derived (defender parked on the blade with
  body pass-through: the re-tempo holds BLUE's pull-back away from an adjacent defender, AC 13), `flee` threshold 3 -> 2 (exact
  minimum under the one-tick lag; RED's swipe now reaches the body late), `BODY` comment re-derived (body collision, AC 12),
  NEW live AC 1 check in `touch` (damage already in on the first INSIDE tick, mid-flight); `test_unblockable_reach_live.gd` --
  arc read removed (R8), `_expected_playhead` composes the remap (AC 13); `test_charge_playhead_live.gd` -- expected playhead via
  `charge_playhead_for` (AC 14).
- NOT moved, as predicted: `test_unblockable_initiation.gd` (incl. `:544/562` CHARGING telegraph), `test_click_to_commit.gd`,
  `test_orbs_economy.gd`, `test_hero_cast.gd`, `test_action_state.gd`, `test_pitch_*`, and every other integration file in M6
  (`test_arena_edge_live.gd` unchanged and green with `BoxShape3D_qp0e8` on the body).

**New files:** `test/state/test_unblockable_honest_contact.gd` (9 tests: AC 1/4, AC 3, AC 7, AC 8 both halves, AC 9, AC 10
both halves, the key, R16), `test/integration/test_hero_hit_shape_live.gd` (AC 11/12 live), `tools/measure_torso_envelope.gd`
(the T3a instrument). Headless editor scan generated the three `.uid` files; `project.godot` SHA256 `0d0d3ccf...0c68` identical
before and after; no other collateral. `git diff -- project.godot` empty.

**Suite runs (three; the third NAMED):** run 1 before-baseline 1248 / 0 / 11839 + 78 integration PASS. Run 2 (the final run as
planned): state 1254 / 3 failed -- three FORMAT_VERSION pins in `test_replay_identity.gd` not listed in M6 -- integration 79/79
PASS (`C:\dev\_78-suite-run2-state.txt` / `-int.txt`). Run 3, EXTRA, reason: run 2's state half red on those three pins, fixed
(test-only edit): **1254 / 0 / 12462**, integration **79 / 79 PASS** (`C:\dev\_78-suite-after-state.txt` / `-int.txt`).
Budget interval: before-state file 2026-10-07 23:29:17 -> after-int file 2026-10-08 00:25:23 (56 min between the recorded
suite files; no gap > 2 h).

### Dev-pass deviations

- **DP1** The skill's step-4 board write (`in-progress`) and step-9 write (`review`) were not made: board statuses are locked to
  backlog / ready-for-dev / done (CFG/R2) and `on_complete` restores `ready-for-dev` anyway; the net board effect is identical.
- **DP2** Three FORMAT_VERSION pins in `test_replay_identity.gd` and the snapshot-key twin pin in
  `test_draw_delay_and_reshuffle.gd` were not in the story's M6 list; found by the suite and moved. The replay pins cost a third
  full run (named above).
- **DP3** A scratch measurement of `jump_attack`'s crouch frame ran from the scratchpad (not committed); its numbers are in the
  knob table.
- **DP4** T6 (Live Smoke + close-out rulings into the decision-log) is the operator's: left unchecked, Live Smoke boxes untouched.

### Completion Notes List

- T1-T5 implemented and green; T6 is the operator's Live Smoke and close-out.
- AC 1-10, 12, 17, 18 machine-proven headless (and AC 1/AC 11 live); AC 11 live in idle and mid-roll; AC 13 [M], AC 14 [M],
  AC 15 (optional structural half) proven; AC 13/14/15 [S] and Live Smoke items 1-9 await the operator; AC 16 is the knob
  table above.
- Golden `941958c5...` -> `1b1478ac...` for exactly one cause, measured both directions. FORMAT_VERSION 20.

### File List

Modified:
- `data/balance/balance_config.tres`
- `src/actors/hero/animation_controller.gd`
- `src/actors/hero/hero.gd`
- `src/actors/hero/hero.tscn`
- `src/main/match_runner.gd` (comments only)
- `src/state/hero_state.gd` (comments only)
- `src/state/match_state.gd`
- `src/state/player_state.gd`
- `src/state/resources/balance_config.gd`
- `src/systems/record_file.gd`
- `test/integration/test_charge_playhead_live.gd`
- `test/integration/test_honest_hit_geometry_live.gd`
- `test/integration/test_unblockable_reach_live.gd`
- `test/integration/test_vertical_alignment.gd`
- `test/state/test_balance_authoring.gd`
- `test/state/test_card_observation.gd`
- `test/state/test_charge_playhead_mapping.gd`
- `test/state/test_data_resources.gd`
- `test/state/test_determinism.gd`
- `test/state/test_draw_delay_and_reshuffle.gd`
- `test/state/test_record_file.gd`
- `test/state/test_replay_identity.gd`
- `test/state/test_unblockable_defense.gd`
- `test/state/test_unblockable_tracking_and_reach.gd`
- `docs/implementation-artifacts/7-8-unblockable-honest-contact.md`
- `docs/implementation-artifacts/sprint-status.yaml`

Added:
- `test/state/test_unblockable_honest_contact.gd` (+ `.uid`)
- `test/integration/test_hero_hit_shape_live.gd` (+ `.uid`)
- `tools/measure_torso_envelope.gd` (+ `.uid`)

### Change Log

- 2026-10-08 Dev pass (Opus 5.5): unblockable resolves on the first counted touch (hashed `charge_contact` key, per-tick
  contact fact, touch-tick dodge, counter span to the first touch); colour arc and dodged-damage multiplier retired; hero hit
  shape is a trunk-following cylinder, body keeps its box; Genichiro re-tempo (swing-at-commit ON, GREEN crouch lead, two
  blended edges); golden `941958c5` -> `1b1478ac`; FORMAT_VERSION 19 -> 20. Status -> review.

## DEVIATIONS

- **D1** Step 0: the board key did not exist; inserted `7-8-unblockable-honest-contact: backlog  # Tier A` between 7-1 and
  7-2 plus a story_note and `last_updated: 2026-10-07` (operator-ordered).
- **D2** M3 is partly measured: skinned mesh rest AABB, joint-origin extents and the shared-resource fact are measured;
  the torso SURFACE width in motion (skinned vertices) was not, because the headless fixture here reads joint origins only.
  The dev pass must measure it (T3) before choosing hit-shape dimensions.
- **D3** The suite was run once at authoring (6m10s, all pass) to confirm the baseline; no repo file other than
  `sprint-status.yaml` and this story was changed. Scratch scripts live outside the repo.
- **D4** The skill's step 4 web research was skipped: the story touches no external library.
- **D5** Gate round 1 fix pass: story length 379 lines against the 340-line budget; the overrun is the completed retirement lists (M6, OQ6)
  and the 18 ACs. Disclosed, not trimmed. Status stays `authored` and the board key stays `backlog` by the fix-pass order.

## Code Review Record

2026-10-08, Opus 5.5, gds-code-review run sequentially in one session (blind/adversarial, edge-case hunter and
acceptance auditor all COMPLETE, no failed layers). Scope `f8ad80b..2a3a60f`. Full report: `C:\dev\_78-review.md`.
**Verdict: APPROVE WITH FINDINGS.** No HIGH. Status stays `review`; board untouched.

**Fixed (`ed4b8ba` story 7-8: review fixes):**
- **F1 MED**: `_apply_bolt_landing` tore down a CHARGING target without resting `charge_contact`. This was a fifth
  CHARGING exit that OQ1's clears missed, so the hashed key read TOUCHED/HIT on a hero that was no longer attacking.
  The effect was hash-only, because the cast seat clears the key before any reader. Fixed with one line beside the
  teardown; the field doc now names the bolt. New
  `test_hero_cast.gd::test_the_bolt_stun_rests_an_abandoned_attacks_hit_once_memory` was RED before the fix and under
  the mutation; restored by copy-back with SHA-256 verified. Suite: state **1255 / 0 / 12466**, integration **79/79**.
  Golden unmoved at `1b1478ac...`.

**Re-derived (measured, not taken from the record):**
- Golden in both directions: key removed gives `941958c5...`; key restored gives `1b1478ac...`.
- M1 and M3 match the record exactly. M5 is RED with 48 `FAILED` lines vs the recorded 51; the number of mid-roll
  frames judged depends on frame timing.
- Commit-tick gate: step 2 stops `charge_window` before step 3, so commit-tick touches ARE offered. A mutation that
  drops them turned 41 tests RED, including the zero-launch fixtures.
- Both charge cross-fades work in-engine; the trailing `seek` does not cancel the blend.

**Report only / for the operator:**
- **F2 LOW**: the AC 15 test checks the constants only. Also, the debug reset's CHARGING->IDLE cross-fades too, which
  makes a third blended edge. QUESTION: accept, or restrict the blend to the landing exit?
- **F3 LOW**: the AC 10 span tests run on slot 0 only.
- **F4 LOW**: `test_honest_hit_geometry_live.gd` has a stale header for `charge`/`flee`. Under R1, `flee` now
  duplicates `touch`. No assertion was weakened.
- **F5 LOW**: the live "on the torso" probe sits on the bone axis.
- **F6 LOW, report only (R9 dimensions)**: residue outside r 0.30:
  - attack: chest front up to 0.032 m, back/side up to 0.12 m (clip t 0.33-0.63);
  - roll: up to 0.198 m, but 15 of the 18 residue ticks are inside the i-frames; after they close, at most 0.08 m for
    2-3 ticks;
  - GREEN post-apex: chest front up to 0.11 m.
  Options with their idle overshoot cost are in the report.
- **F7 deferred, pre-existing**: the `match_state.gd:1714` "FOUR EXITS" comment omits the bolt exit.
