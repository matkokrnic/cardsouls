# Deferred Work

## Deferred from: code review of 6-0-card-hand-tint (2026-09-08)

- **`ORB_COLORS[color as int]` has no upper-bound guard** (`src/ui/hud/hud_root.gd`,
  `_set_swatch_color`). `ORB_COLORS` holds exactly three entries and `Enums.CardColor` has exactly
  three members, so the index domain is closed today and this is NOT reachable. It is recorded
  because the function's two failure modes are asymmetric: the `null` case (no colour for this
  slot) degrades gracefully to a hidden swatch, while an out-of-domain colour is an
  index-out-of-bounds raised inside a signal handler, mid-frame. A fourth `CardColor` member, or
  any map value >= 3 reaching the HUD through the deliberately untyped `Dictionary` the wrapper
  hands over, turns a presentation concern into a crash. OWNER: the first story that touches the
  `CardColor` enum or the shared `ORB_COLORS` palette — whichever comes first; the guard costs one
  line and should be added by whoever widens the domain, not before.

## Deferred from: code review of 4-3e-summon-spawn-placement (2026-08-27)

- **`test_unit_spawn_placement_live.gd`'s `_actor_at(index)` indexes `_unit_actors[0]` by raw
  position without a hole guard** — would null-deref if a hole ever preceded the first live unit at
  the sampling frame. Not reachable in this file's current no-death scenario.
- **The sidestep/clear direction helpers added to `test_unit_approach_live.gd`,
  `test_unit_strike_alignment_live.gd`, `test_unit_swing_root_live.gd` normalize a `Vector2` with no
  degenerate-length guard**, unlike production `_rear_direction`'s explicit epsilon fallback. Not
  reachable given the authored scene's hero/unit positions.
- **`test_unit_swing_root_live.gd`'s 6.0 m sidestep vs `test_unit_strike_alignment_live.gd`'s 4.0 m
  is undocumented.** Plausibly explained by swing-root's additional zero-neighbour-contact
  assertion, but neither the file's comment nor the Dev Agent Record states or measures the reason.
- **4-3e's Dev Agent Record overstates the necessity of its one recorded deviation** (replacing
  Task 4's `while actors.size() < count` with a batch-size-plus-`for` shape). A `while` loop
  consuming a pre-computed `Array[Vector3]` from one `_compute_spawn_positions(..., batch_size)`
  call would have satisfied both the literal `while` shape and AC9's one-call-per-batch requirement
  — they were not actually in conflict. The underlying growth/no-reuse property is independently
  verified intact; this is a self-report rigor gap in future dev-pass write-ups, not a code defect.
- **AC6(b)'s "one-word correction" claim (`unit_board.gd:404-407`, moved from `:303` since this
  entry was written) understates its own diff** — three lines of `3-6/R2` citation commentary were
  also appended. Still comment-only, still satisfies AC7.

## Deferred from: readiness gate of 4-3a-minion-damage-and-death (2026-08-10)

- **Per-hit feedback on a damaged (not yet dead) unit (`4-3a/R12`, decided by Matko).**
  `hit_landed` is NOT emitted for a unit target in `4-3a`: the signal carries a slot only, and its
  shipped consumer flashes and stings the hero of that slot -- emitting it on a unit hit would
  flash and sting an untouched hero whose HP did not change. The legible event `4-3a` ships is
  DEATH: the unit disappears. A hero landing two non-lethal swings on a unit produces no visible
  or audible feedback at all today. Two alternatives were considered and rejected at the gate:
  widening the signal payload to carry a unit target (same screen, more plumbing, no new seam) and
  a real unit feedback channel (a new observation seam, which the locked count of seven
  `connect_*` seams on `match_runner.gd` makes an architecture amendment, not a story-scoped
  change). ~~OWNER: `4-3b-minion-attack-rhythm`.~~

  **Update from 4-3b close-out (2026-08-12, `4-3b/R32`): NOT addressed.** `4-3b` confirms the
  asymmetry stays as designed (`hit_landed` fires on unit-damages-hero, not on unit-damages-unit)
  and does not touch this item's substance -- see `4-3b-minion-attack-rhythm.md`, Non-Goals. The
  item stays OPEN. OWNER: unassigned -- the next story that gives unit-vs-unit combat a real
  feedback channel.

## Deferred from: 4-3b-minion-attack-rhythm close-out (2026-08-12)

- **The general case of the harness leak (`4-3b/R29`).** Two live SceneTree tests
  (`test_live_attack.gd`, `test_unit_attack_live.gd`) leaked Jolt/engine resources from `quit()`
  firing the same physics frame as the last measurement read; both fixed by deferring `quit()`
  30 frames past assertions. Whether other live tests share this shape is unexamined and was not
  this story's work. OWNER: the next story or pass that touches a live SceneTree test -- check the
  file for the same "quit immediately after the last read" shape before adding to it.

## Deferred from: code review of 4-3-minion-approach-and-collision (2026-08-10)

- **CLOSED by `4-3a-minion-damage-and-death`, `test_two_units_converge_live.gd` (AC 10).**
  Unit-vs-unit body collision is unmeasured (`4-3/R21`, finding 1). The shipped comments
  claimed the shared default layer makes a unit block "a hero (and another unit)", but
  `test_unit_approach_live.gd` only drives a hero into a parked unit -- two units driven at the
  same acquired target simultaneously is not exercised anywhere: the wedge/jitter risk of two
  `CharacterBody3D`s converging on the same point. OWNER: `4-3a-minion-damage-and-death`.

  **Update from 4-3 close-out live smoke (2026-08-10):** OBSERVED CLEAN by hand -- several units
  driven at the same target showed no jitter, no mutual pushing, normal movement, no passing
  through each other, normal tracking (`docs/playtest-log.md`, 10.8). This lowers the risk read on
  the item. It does NOT close it: the item is about machine coverage (`4-3a`'s test still owes a
  live check with two-plus units converging on one target), and a single by-hand observation is not
  a substitute for that.

- **`approach()` does not distinguish "reached `unit_stop_distance`" from "physically obstructed
  short of it" (`4-3/R21`, finding 1).** A unit blocked by another body before it reaches its stop
  distance has no distinct code path, so its behaviour there is whatever `move_and_slide()`
  happens to do, not a designed outcome. ~~OWNER: `4-3b-minion-attack-rhythm` (its only consumer is
  attack range, which lands in 4-3b).~~

  **REWRITTEN at the 4-3b readiness gate (2026-08-11). The stated rationale is FALSIFIED, and the
  item is not closed.** "Its only consumer is attack range" no longer holds: `4-3b/R10` and
  `4-3b/R17a` gave the attack trigger a REACH TEST instead (mechanised by `4-3b/R17b` as a throttled
  probe on the existing `push_contact` intake),
  which REMOVED that consumer rather than building the distinction. So the reason this item was
  parked on `4-3b` has evaporated while the item itself has not.

  **The residual gap is real and REMAINS: an obstructed unit still has no designed behaviour.**
  Nothing in `4-3b` gives it one — `approach()` is explicitly not edited there — and the measured
  own-side instance below is still reproducible.

  **NEW OWNER: the later story on richer minion behaviour** (per `4-3b/R11`, which keeps own-side
  collision deferred with a new owner; the same story that replaces "wedged into the first thing in
  its path" with real steering, as `4-3a/R29`'s own operative reason anticipated). Named rather
  than left unassigned, because an unowned item is one nobody re-reads.

  **Supersession recorded:** `4-3a/R29` named `4-3b` as this item's FORCING POINT ("`4-3b` teaches
  `approach()` to distinguish 'arrived' from 'physically obstructed'"). That assignment is
  SUPERSEDED by the operator's two newer rulings, `4-3b/R10`/`R17a` (the reach trigger removes the
  consumer) and `4-3b/R11` (own-side collision stays deferred under a new owner).

  **Annotated from 4-3a review (2026-08-10, `4-3a/R25`): a measured instance, not a new item --
  a summoned minion can be blocked by its OWN summoner.** Writing
  `test_two_units_converge_live.gd` (the AC 10 live test), the trailing unit's first run parked
  6.82 units from its acquired target: it was wedged not against its sibling but against P1's own
  hero, which stands at (-3, 0), directly in the unit spawn lane -- the same "arrived" vs.
  "physically obstructed" gap this item already names, just triggered by a hero body instead of
  another unit. The test now relocates the hero off the lane as a setup step precisely so it scopes
  itself to unit-vs-unit collision instead. This item stays OPEN; this is a measurement of an
  existing gap, not a discharge of it. (Its owner was `4-3b` when this annotation was written — see
  the 2026-08-11 rewrite above for the reassignment.)

## Deferred from: readiness gate of 4-3-minion-approach-and-collision (2026-08-10)

- **Merge the aim and approach loops into one per-unit pass.** `_aim_unit_actors`
  (`match_runner.gd:647`, seated at tick-phase 3d) and the new approach step (seated at the DRIVE
  phase, `4-3/R10`) both resolve the same `[slot, index]` target to a `global_position` for the
  same unit, once each, at two different points in the tick. Not merged by this story because
  re-seating shipped code across a tick-phase boundary is not a refactor (`4-3/R10`). Measured
  cost of leaving them split: one extra `_target_world_position` call per unit per frame, a
  value-type return, zero heap allocation -- cheap, not urgent. OWNER: unassigned.

## Deferred from: close-out of 4-2-minion-ai-throttled-targeting (2026-08-10)

- **CLOSED by `4-3/R17`.** Units have no collision shape -- heroes pass through them. `UnitActor`
  (`src/actors/minions/unit_actor.gd`) is a `Node3D` with a `MeshInstance3D` and nothing else; no
  `CollisionShape3D`, no `Area3D`, no physics body. Noticed live during this story's smoke
  (`docs/playtest-log.md`, 10.8: "vidjim da heroji mogu proralziti kroz te pravokutnike ne znam
  jel to namjerno tako zasad"). Deferred because 4-2 adds no movement or combat consequence to
  units at all (`4-2/R4`) -- a unit a hero can already walk through is not yet a unit anything
  can collide WITH in a way that matters. OWNER: `4-3-minion-approach-and-collision`'s readiness
  gate, which is where movement first makes collision a real question (`4-3/R1`, the split of the
  boarded `4-3-minion-combat` into approach/collision and a separate `4-3a-minion-combat`).

## Deferred from: code review of 4-0-hand-slot-stability (2026-08-07)

- **AC 8's permanent hole is visually indistinguishable from a slot mid-flight awaiting
  delivery.** Both render the same blank caption (`Hand.EMPTY` -> empty string), and nothing in
  the 4-0 diff or its tests distinguishes "temporarily empty, refilling soon" from "dead for the
  round" to the player [src/ui/hud/hud_root.gd]. Deferred because the story's own AC 7 forward
  constraint already scopes HUD affordability/greying rendering out of this pass ("no cost,
  affordability or greying rendering in src/ui/ today... this AC binds that future work; it
  requires no HUD code now"), and AC 9's outstanding live smoke is where this would first become
  player-visible in practice.

## Deferred from: code review of 3-6-card-hud-hand-mana-deck (2026-08-06)

- **CLOSED by `3-6/R8`.** Hand row hard-coded to 4 slots with silent truncation.
  `HudRoot.on_cards_changed` (`src/ui/hud/hud_root.gd`) writes `_own_card_labels[i]` for
  exactly 4 indices and silently drops any `hand_ids` entries beyond index 3, with no
  `Invariant.check`. Pre-existing since 2-5/R1 fixed the row at the presentation-local
  constant 4 (hand size is 4 at all times per the GDD) — 3-6 populated the row with content
  but did not introduce or change this assumption. Real only if `BalanceConfig.hand_size` is
  ever authored above 4 — which is exactly the window the next (playtest-tuning) phase opens.
  Closed by adding a fourth bound to `test_balance_authoring.gd::test_authored_deck_and_hand_counts_are_sane`
  (`hand_size <= 4`), so an authored 5 fails the suite loudly instead of the HUD truncating
  silently. History kept here per instruction rather than deleted.

## Deferred from: code review of 4-B1-card-hud-debt-discharge (2026-08-08)

- **The DebugInstrumentPanel box leaves the window at any width below 800px.**
  `debug_instrument_panel.gd:130-131` centres a fixed 800-wide box (`offset_left -400`,
  `offset_right 400`, widened from 600 by 4-B1 for its fourth column). `project.godot` carries no
  `[display]` block, so the window is the resizable 1152x648 default with no stretch mode, and the
  layout guard in `test_debug_instruments.gd` only ever runs at that default size. Deferred as a
  pre-existing class rather than a 4-B1 defect: the 600-wide box had the same unguarded shape and
  the same "only ever validated at one resolution" blind spot; 4-B1 widened the exposed range
  (600-800px window widths) without introducing the mechanism. At the tested 1152x648 the widening
  is genuinely clear -- x[176,976], y[356,450] against RoundOverLabel bottom y354 and Vitals top
  y452, machine-checked in BOTH viewports and green.

- **`hand_ids` is bound at push time while `pending_draw_owed` is read at drain time.**
  `player_state.gd:137-138` binds the hand copy into the queued emit; the 4-B1 wrapper at
  `match_runner.gd:255` reads `player_for_slot.pending_draw_owed` when the SignalQueue drains,
  after the whole tick has resolved -- so every payload is rendered against the END-OF-TICK owed
  set rather than the set that was true when it was pushed. Deferred because the mismatching
  intermediate renders are all overwritten within the same drain and never reach the screen, and
  because the shape belongs to the D5 queued-signal channel rather than to this story. The one
  case where it IS visible is tracked separately as this review's HIGH decision item (the
  both-empty exhaustion degrade popping the debt with no announcement, leaving the permanent hole
  painted with `IN_FLIGHT_CAPTION`).

- **A build gate for the reveal-opponent-hand toggle (code review D2, RULED deferred
  2026-08-08).** `DebugInstrumentPanel` is added unconditionally by the runner
  (`match_runner.gd:283, 298`) with no `OS.is_debug_build()` / export-build branch, so the
  `RevealOpponentHand` CheckButton -- which shows both players' hand contents, the information the
  GDD privacy lock protects -- is mouse-reachable in any build that ships the panel. The operator
  RULED that default-off is sufficient today: this is a same-screen local prototype, no export
  build exists, and a gate that no test could exercise would be a vacuous guard, which this repo
  treats as worse than none (`3-0d/R20`, guard mechanism over guard pattern). OWNER: the first
  story that produces a distributable / export build. That story must gate the whole panel, not
  just this control -- SaveRecord and ReloadBalance ship the same way.

- **DebugInstrumentPanel ergonomics -- size, placement, collapsibility (operator finding
  2026-08-08).** Live-smoke observation during 4-B1: the mid-screen panel has grown bulky. It sits
  dead-centre in the band between the round-over label and the vitals bars, and every story that
  adds a control has widened it (2-6: 300 -> 3-0b: 600 -> 4-B1: 800 -> 1000, then back to 680 once
  `4-B1/R7` deleted the reveal's output label). Width is the only axis available, because the band
  has zero vertical slack -- which means the panel can only ever get wider across the middle of the
  screen, and the next control repeats the argument. Worth revisiting as a whole: a smaller or
  repositioned box, a collapsible panel, or moving the instruments out of the gameplay band
  entirely. OWNER: the next story that touches `src/ui/debug/debug_instrument_panel.gd`. Not urgent
  -- the machine check in `test_debug_instruments.gd` keeps the box provably clear of both HUDs and
  both StateInspectors at 1152x648, so this is ergonomics, not occlusion.
  **DISCHARGED by `7-6-hud-and-card-presentation` (polish round 2, operator ruling P12, 2026-10-06):** the panel
  is HIDDEN by default and toggled by F3 (`debug_toggle_instruments`, read through `DebugInputReader`). While it
  is hidden the HUD may use its space; when shown it may overlay the HUD. `test_debug_instruments.gd` shows it
  through F3 and now guards only the window and the StateInspectors.

## Deferred from: code review of 6-6a-defense-reactions (2026-09-17)

- **CLOSED by 6-6b AC 7 (2026-09-20, decision-log session 6-6b close-out): a downed hero cannot counter.**
  ~~A downed hero keeps a defense window armed on or before the landing tick, and can colour-counter
  while down.~~ `_apply_landing_packages` tears down only the chargeup. This is consistent with the
  `5-6` STUNNED contract ("running windows tick out") and asserted by the R-PRESS test. Judge at the
  `[3, 3]` smoke.
- **`block_impact`'s held final frame stands in for the block pose for the rest of the hold.** The
  only evidence of a match is the Hips, which are identical at both ends (Y 0.6915, yaw -67.03). The
  arms and shield were never measured. Smoke.
- **A hero moving during `get_up`/`hit_react` slides in the one-shot pose until it ends.** AC 2
  mandates the locomotion yield. Smoke.
- **Retune hazard: `dodged_unblockable_damage_multiplier > 0` (authored 0.0).** The dodge rung would
  then deal chip damage during the get-up iframes and cut `get_up` with `hit_react`. The rung is
  `5-6`'s, and it still applies at step 3 while the unanswered tier applies at 6b.
- **The knockdown-last / get_up-first Hips junction is measured but not pinned** (0.0067 planar after
  the `knockdown` planar pin). `test_clip_timing.gd` pins only the knockdown's own excursion.
- **`MatchState.debug_window_ticks_remaining()` does not list the get-up iframe window** (6-6a Dev
  Note 6).
- **`test_replay_identity.gd`'s `_iframe_open_at_step3` comment still reads "STAYS AT THREE"** beside
  the current count of 4. Pre-existing, not introduced by 6-6a.

## Deferred from: live smoke of 6-6a-defense-reactions (2026-09-19)

Two notes from the `[3, 3]` two-pad smoke. The smoke's THIRD finding -- the hero able to act the
instant `get_up` starts -- was ruled a code fix and shipped in that story's post-smoke pass; it is
NOT deferred and is not listed here. See `6-6a-defense-reactions.md`, Post-Smoke Amendment.

- **TUNING: the knockdown lie and the get-up both feel somewhat too long.** Authored
  `knockdown_stun_seconds = 2.5` (150 ticks) and `get_up_iframe_seconds = 2.0333` (122 ticks, the
  measured `get_up` clip length). In live play both read as slightly overlong -- the operator's own
  smoke note. SHORTEN BOTH SLIGHTLY, RATIO PRESERVED; the exact values are a retune-block decision,
  not this pass's. Deliberately NOT changed now: a felt duration judged once, mid-smoke, is exactly
  the kind of value the retune block exists to set with the rest of the combat clock in front of it.
  Note the coupling when it is retuned: `get_up_iframe_seconds` is tied to the `get_up` CLIP's length
  (shortening the window below it leaves the clip still playing past the window, which is now also the
  input lock -- see the post-smoke ruling), and `knockdown_stun_seconds` must stay above
  `color_counter_stun_seconds` (1.0) for AC 4's directional bound AND for
  `BalanceTicks.is_knockdown_stun`, the duration classifier that tells the three stun flavours apart.
  Both are ordinary authored values -- `BC/R3` isolation holds, so this is a `.tres` edit with no test
  edit and no golden re-baseline. OWNER: the post-E5/E6 playtest/retune block; added to its checklist
  below.

- **POLISH: `hit_react` (and one-shot reaction poses generally) SLIDE when the victim moves during
  the clip.** The hero keeps its locomotion velocity while a one-shot reaction pose plays, so the mesh
  glides across the floor in a static pose. This is AC 2's locomotion-yield rule working as specified
  -- the one-shot must not be stolen mid-play -- rather than a defect in it, which is why the fix is
  not "stop yielding". THE PROPER FIX IS A LAYERED / PARTIAL-BODY BLEND: the upper body plays the
  reaction while the legs keep the locomotion clip. That is an `AnimationTree` (or additive/second
  `AnimationPlayer`) pattern, which `6-6a` explicitly refused to introduce as a new architectural
  pattern inside a reaction story. Deferred as presentation polish. The same shape reaches `get_up`,
  though the post-smoke lock now roots the hero for that window, so `get_up` no longer slides --
  `hit_react` is the live case. OWNER: the story or pass that introduces a real animation-layering
  pattern for the hero rig. This SUPERSEDES the narrower 6-6a review deferral of the same
  observation ("A hero moving during `get_up`/`hit_react` slides in the one-shot pose", recorded
  above) -- same fact, now with the smoke's confirmation and a named fix shape.
  **DONE in 7-2** (the `LegLayer` upper/lower split; `7-2/R1`).

## E4 review residue (recorded at E4 close-out, 2026-09-01)

Forty-eight findings from the four out-of-repo E4 review files (`_44-review.md`, `_45-review.md`,
`_46-review.md`, `_46a-review.md`) were previously recorded nowhere a future reader would look --
as a block reference (`decision-log.md:7432`) or not at all. Recorded here by id, source, content,
and disposition tag. Tags: **(a)** closed/accepted as-is, no further action; **(b)** playtest-block
candidate (gameplay-visible); **(c)** candidate for E5-planning judgment (design/process/coverage);
**(d)** open, no owner. Two findings (M9, M4 below) got their own operator rulings
instead of a bare tag and are recorded first.

**4-4 M9 (`_44-review.md:444`) -- accelerators do not stack; the second identical totem silently
does nothing.** Operator ruling `R-M9` (2026-09-01): accelerators STACK. Each accelerator totem
contributes its own multiplier where it sits; two identical totems apply two multipliers,
multiplicative. This changes shipped behaviour. Design ruling only; implementation touches the
golden path, so it is Tier A -- slot assigned at E5 planning.

**4-4 M4 (`_44-review.md:362`) -- the append-only projectile/unit board grows all match, never
reclaimed.** Closed by measurement, log line only, no story: `4-5/R1`'s board-growth observation
(21 -> 64 records) showed a frame-time trend of +0.3% early-vs-late, but `4-5/R2` withdrew that
figure as run-dependent (a re-run measured +6.7%, and the quarters dilute per-tick drift roughly
4x) -- the surviving claim is "no cost separable from run-to-run noise with this instrument"
(`decision-log.md:7781-7783`). Re-measure trigger: unit population above 20, or matches materially
longer than the 4-5 harness measured.

### 4-4 (`_44-review.md`) -- 14 open

| id | Source | Content | Disposition |
|---|---|---|---|
| M1 | `_44-review.md:308` | `push_contact` attacker-index invariant is now vacuous | (d) |
| M2 | `_44-review.md:330` | `stamina_accelerator_regen_multiplier` defaults to 0.0, so an unauthored config inverts AC 21 | `5-1-accelerator-stacking` (`E5-P/R6`) |
| M3 | `_44-review.md:347` | `_is_totem` means "has a non-default kind", not "is a totem" | (d) |
| M4 | `_44-review.md:362` | Projectile board grows all match, never reclaimed | closed by measurement, see above |
| M5 | `_44-review.md:381` | Live homing test cannot tell steering toward from steering away | **CLOSED by `6-5d-fireball-and-spell-targeting` AC 37** (`6-5d/R14` moved it here from `6-5-spell-resolution`) -- `test_projectile_flight_live.gd` now samples the AIM ERROR (the angle between the shot's heading and the vector to its target) every tick and asserts it does not grow and that the last third averages better than the first. MUTATION-PROVEN against a sign-inverted `steer_toward`: the old bearing-SPREAD assertion still passed on the inverted steer (`steered=true`, spread 1.68 rad), the new one fails it decisively (`aim_last=3.12` rad, late mean 3.12 vs early 1.31) |
| M6 | `_44-review.md:398` | Reordering `unit_kinds` at an X3 reload silently re-points every live record | **CLOSED by `6-5d-fireball-and-spell-targeting` AC 38** (`6-5d/R12`; `6-5d/R14` moved it here) -- `MatchState.apply_balance()` now REFUSES a same-length `unit_kinds` reorder while any unit or projectile record is live: the running config is kept, no record is re-pointed, and the returned reason names the reordered kind and its position. "Live" means any record, not a living one (a corpse's kind index still decides its corpse behaviour). Every other reload -- unchanged, appended, shortened, or a reorder on an empty board -- is unaffected. Tested in `test_fireball.gd` (four tests) and mutation-proven |
| M7 | `_44-review.md:416` | Zero or negative derived projectile speed makes a shot immortal | `5-1-accelerator-stacking` (`E5-P/R6`) |
| M8 | `_44-review.md:432` | The budget's final tick is charged but never flown | (d) |
| M9 | `_44-review.md:444` | Accelerators do not stack; the second silently does nothing | `R-M9`, see above |
| L1 | `_44-review.md:461` | A no-target projectile homes on P2's hero | (d) |
| L2 | `_44-review.md:492` | The projectile gather hard-fails on a missing `Hitbox` | (d) |
| L3 | `_44-review.md:499` | The hits-to-kill authoring band now constrains kinds it was not written for | (d) |
| L4 | `_44-review.md:508` | Projectiles resolve newest-first, ahead of their own hero, on an unproven rationale | (d) |
| L5 | `_44-review.md:485` | `projectile_speed_at` is public and unguarded against a null `balance` | (d) |

The leftover agent worktree noted at `_44-review.md:759` (`.claude/worktrees/agent-a9f2be623cd1e0ac0`)
self-resolved: the path does not exist in the repo today.

### 4-5 (`_45-review.md`) -- 9 open, all "reported, not fixed"

| id | Content | Disposition |
|---|---|---|
| D1 | `flags_off_live.gd` collapses two independent flags into one boolean | `5-4-orbs` (`E5-P/R6`) |
| D2 | Counts cast STARTS before any input frame is driven | DEFERRED as a set with D3/D6 (`E5-P/R6`), owner: whoever next runs the `4-5` perf harness (re-measure trigger already written above: unit population above 20, or materially longer matches) |
| D3 | Fixed frame list `CAST_STARTS`, no retry -- a missed start is silent | DEFERRED as a set with D2/D6 (`E5-P/R6`), same owner |
| D4 | Header justifies a real renderer but every condition it checks is headless-satisfiable | (d) |
| D5 | Per-tick instrumentation (repeated `living_indices()` allocations) sits inside the measured window | (d) |
| D6 | `_split_by_tick`'s `maxi(count, 1)` turns an empty population into a plausible 0.0 | DEFERRED as a set with D2/D3 (`E5-P/R6`), same owner |
| D7 | The first wall sample spans the build->measure transition; the first GPU samples likewise | (d) |
| D8 | The corrected re-run showed 2 frames over 33.3 ms (max 48.6) where the authoritative run had 0 | (b) perf tail, gameplay-visible as the flicker/stutter class |
| D9 | The decision-log entry's narrative register vs `E4-P/R9` (Tier B = rulings only) | (a) CLOSED as process (`E5-P/R6`) -- superseded by `E4-R/R2`'s `LAYER-COMPLETION:` mechanism, which already replaced the enforcement this finding was about |

### 4-6 (`_46-review.md`) -- 16 open. No 4-6 close-out session exists in the decision log; none of
these ids were previously recorded anywhere in the repo.

| id | Content | Disposition |
|---|---|---|
| M1 | `_46-review.md:211` | The retarget tick still faces the PREVIOUS target | (b) |
| M2 | `_46-review.md:227` | The flick edge is magnitude-only, so a rim sweep never re-fires | (b) |
| M3 | `_46-review.md:236` | A malformed retarget address is logged and then acted on, and lands in a HASHED key | `5-1a-intent-hardening` (`E5-P/R6`) |
| M4 | `_46-review.md:262` | `UNHASHED_CROSS_TICK_MEMBERS` counts arguments a human maintains, not entries a machine finds | (d) |
| M5 | `_46-review.md:276` | Keyboard slots can no longer face anything but the opposing hero | CLOSED by `6-8-camera-freedom` AC 23 -- keyboard parity implements lock/unlock, camera-rotate-left/right and cycle-left/right on the ratified key table |
| L4 | `_46-review.md:301` | `best_candidate`'s tie-break uses exact float equality | (d) |
| L5 | `_46-review.md:307` | Reconnecting a pad with R3 held fires a spurious relock | (b) |
| L6 | `_46-review.md:314` | Flick candidates are unprojected against LAST tick's camera | (b) |
| L7 | `_46-review.md:320` | A v6 record with a sparse or truncated `lock_pushes` channel replays wrong | `5-1a-intent-hardening` (`E5-P/R6`) |
| L8 | `_46-review.md:326` | A v6 intent dict missing `retarget_slot` / `retarget_index` crashes | `5-1a-intent-hardening` (`E5-P/R6`) |
| L9 | `_46-review.md:330` | `flick_threshold` is unvalidated authored data with a silent dead zone at 0.0 | (d) |
| L10 | `_46-review.md:334` | R3 and flick edges are consumed and discarded under the 3-0b debug pause | (b) |
| L11 | `_46-review.md:339` | The lock-on test's final assertion | (d) |
| L12 | `_46-review.md:344` | The `is_position_behind` seat | (d) |
| L13 | `_46-review.md:347` | `_gather_flick_candidates`'s loop bound | (d) |
| L14 | `_46-review.md:353` | The rig yaw is written unguarded | (d) |

(L1-L3 were fixed inside the review itself, `_46-review.md:289-301`, plus three further corrections
landed as `c5bad2a` -- not open, not listed above.)

### 4-6a (`_46a-review.md`) -- 9 open (about 9 of 14; five discharged: M1/L1/M5 by comment corrections
`c831ef9`, L4/L5 by marker fixes `854c0d4`/`3a2ecc4`, ratified `4-6a/R2`)

| id | Content | Disposition |
|---|---|---|
| M2 | `_46a-review.md:280` | Smoothing lengthens the AC 5 dead window after a click-relock onto an off-frame hero | (b) |
| M3 | `_46a-review.md:297` | The AC 7 tie-break is close to unreachable in live play; near-ties are the real case | (b) |
| M4 | `_46a-review.md:320` | Rig smoothing memory survives a DEBUG RESET | (a) adjudicated ACCEPTABLE |
| L2 | `_46a-review.md:366` | `rotation.y` is left unwrapped by the eased branch | (d) |
| L3 | `_46a-review.md:377` | `apply_config` writes the smoothing rate after dereferencing `_camera` | (d) |
| L6 | `_46a-review.md:416` | `_count_markers` cannot see a third marker added as a SIBLING | DEFERRED (`E5-P/R6`), owner: the next story editing `src/actors/camera/`-class code or its tests |
| L7 | `_46a-review.md:425` | The `>= 1.0` fast path is not discriminated by the test that covers it | DEFERRED (`E5-P/R6`), same owner |
| L8 | `_46a-review.md:434` | Two guards that no longer guard, and one unreachable mismapping | (d) |
| L9 | `_46a-review.md:457` | Two stale doc lines outside this story's code (`sprint-status.yaml:2` header) | self-resolved -- the header text the review quotes has already been overwritten by later commits (4-5 close-out), and this close-out's board commit corrects it again |

One further 4-6a deferral is already in the repo, not repeated here: `sprint-status.yaml:121` (the
lock marker drifts slightly outside the minion silhouette during the walk gait), matching the
operator's own 1.9. playtest note.

### 6-8 (`_6-8-review.md`) -- 3 open, deferred hardening

| id | Source | Content | Disposition |
|---|---|---|---|
| M1 | `_6-8-review.md:21` | No upper bound or NaN guard on the free-yaw rate or axis (`camera_rig.gd:79,159-162`); a NaN permanently corrupts rig yaw, and relock does not recover it | deferred hardening |
| M2 | `_6-8-review.md:57` | `_target_world_position` resolves any non-zero slot to P2's hero (`match_runner.gd:1630-1633`); not reachable today, since both lock callers guard on `is_locked()` | deferred hardening |
| L2 | `_6-8-review.md:107` | `resolve_camera_rotate` has no guard against a negative authored deadzone (`gamepad_controller.gd:283-289`) | deferred hardening |

## Named gaps without an owner (recorded at E4 close-out, 2026-09-01)

- **Arena has no edge** -- hero and minion fly off past the floor rather than being stopped.
  Recorded at `sprint-status.yaml:117` and `4-4-totems.md:135`; observed live, `docs/playtest-log.md`
  28.8. **SLOTTED as `5-0d-arena-edge` (`E5-P/R2`, decision-log Session 2026-09-01 "E5 planning"):**
  a ring of static collision in the scene (`main.tscn`), a hard wall the player slides along -- no
  `src/state/` edit, golden immobile by construction. `4-3e` consciously left this open (deleted the
  last requirement-shaped reference to an arena bound at its third gate, finding B3).
- **Minions freeze in front of an obstacle** (`approach()`'s arrived-vs-blocked gap). Fullest record
  above at "Deferred from: readiness gate of 4-3-minion-approach-and-collision" and its rewrite;
  re-observed live `docs/playtest-log.md` 28.8. and 1.9. (point 4). **OWNER: the playtest block
  after E5+E6** -- the operator's own placement on 1.9., superseding the unslotted "later story on
  richer minion behaviour" language above. RE-CONFIRMED at E6 planning (`E6-P/R11`): the operator's
  "smarter, more natural minions" input (`E5-C/R9`) is THIS item, and it keeps this owner rather
  than becoming an E6 nav story.
- **`standard` priority gives a dead arena at 10v10.** The authored `standard` priority is
  `prefer_hero = false` with first-living-index ordering, so every minion on a side acquires the
  opposing board's index 0; two walls meet in the middle and jam, nobody swings or dies, while each
  Combat totem acquires the enemy hero at ~11.5 m, outside its authored 8 m firing range
  (`4-5-pooling-60fps-exit.md:335-345`, independently confirmed by `_45-review.md:79-84`). A
  content/design finding, not a harness bug. **OWNER: playtest block after E5+E6** -- a design
  lever on authored minion priorities, judged once real play exists.
- **AC 11 flicker cause stays UNNAMED** (`4-5/R2`/`4-5/R3`, `decision-log.md:7757-7793`; three
  candidates recorded: physics push jitter, overlapping live meshes, the 600-tick collision-off
  corpse). **OWNER: the playtest block**, the only one of the four gaps with an explicit prior
  assignment (`4-5/R3`).

## E5 residue (recorded at E5 close-out, 2026-09-07)

Findings and retune items from the twelve E5 stories that had no durable home before this pass —
each was previously reachable only by walking the decision log story by story.

**Retune entries (feel calls, not defects; judge with a pad in hand):**

- **Deflect stun (0.4 s) vs the full colour-counter stun (~1.0 s) — possibly too short a
  gradation.** `5-6/R2` authored deflect stun at 0.4 s against the colour counter's 1.0 s;
  `5-6/R10` flags the deflect value as possibly a touch short. Retune block.
- **Stun legibility — pose-hold only, no dedicated clip, NOT ASSESSED.** `5-6/R10`. Retune/polish
  block.
- **Defense feel reads as "the defender did nothing."** `5-5/R10`. Retune/polish block — EXPECTED
  DISCHARGE by `6-6-defense-presentation` (`E6-P/R8` amendment (i)).
- **Chargeup unreadable.** `5-5/R10`. Retune/polish block — EXPECTED DISCHARGE by
  `6-1b-chargeup-presentation` (`E6-P/R8` amendment (i)).
- **Charge audio is placeholder sine tones; cast-vs-deflect discrimination is marginal.**
  `5-3/R6(c)`. Deferred to a real audio pass.

**Other E5 items with no durable home:**

- **`5-0a` diagonal strafe tie-break never resolves.** Review LOW, recorded only at
  `decision-log.md:8267-8270` / `sprint-status.yaml:149`. Retune block.
- **`5-0c` tint dispatch is a hardcoded name table; a 4th kind ships untinted with no test
  failure.** `decision-log.md:8365-8366`. Accepted, no owner.
- **`5-0c` tint test coverage is p1-only; p2 is reasoned-sound but unmeasured.**
  `decision-log.md:8366`. Accepted, no owner.
- **Attack/defense windows unclear.** `5-5/R10`. Retune/polish block.
- **`5-3/R6(b)` — the strike stabs air; damage lands at roughly 8 m (attacker delivery).**
  Post-E5/E6 playtest block.
- ~~**`5-3/R6(d)` — locomotion speed / walk-as-default / sprint-costs-stamina.**~~ SUPERSEDED by
  `E6-P/R3` (two gaits, walk the new default, run drains stamina) — seat `6-7-locomotion-gaits`;
  the walk / turn-in-place animations are its presentation half, `6-7b-locomotion-presentation`
  (`E6-P/R8` amendment (ii)). Ruled, no longer deferred.
- **Per-attack-type counter ideas (sweep/jump/thrust, ranges, auto-aim).** `5-5/R10`
  handed these to the `5-6` ladder scope talk; the `5-6` close-out session (`decision-log.md:8928-8992`)
  contains no ruling on them. No longer orphaned — **OWNER: the post-E6 playtest block, judged with
  a pad** (`E6-P/R6`). See the checklist below.

**Standing exception to the tuning-isolation fact (`5-3/R2`).** The repo's operating guidance says a
tuning change is a one-line `.tres` edit with no test edit and no golden re-baseline (`BC/R3`). As
of `5-3`, `unblockable_chargeup_seconds` is a **named exception**: `5-3/R2` records that retuning it
is no longer a one-line `.tres` edit. This contradicts the standing fact for that one field only —
do not assume it generalizes to other authored values without checking the specific ruling.

## Playtest block after E5+E6 -- checklist

Per operator ruling `R-SPELL` (2026-09-01, decision-log E4 close-out session), the melee retune +
playtest block deferred on 2026-08-30 runs AFTER the spell-resolution close-out that gives spell
resolution its own forcing point -- that story split into `6-5a`..`6-5g`, all done -- so the
playtest sees working spells rather than named no-ops. The window is now open (E6 close-out,
2026-10-01). This checklist is the block's scope:

- Every **(b)**-tagged finding above (4-5 D8; 4-6 M1, M2, M5, L5, L6, L10; 4-6a M2, M3).
- ~~Arena has no edge~~ -- REMOVED from this checklist: E5 planning slotted it as `5-0d-arena-edge`
  (named gap above, `E5-P/R2`).
- **Minions freeze in front of an obstacle** (named gap, above).
- **`standard` priority gives a dead arena at 10v10** (named gap, above).
- **AC 11 flicker cause** (named gap, above).
- **Two-pad mode-2/mode-3 exchange (`5-7`) — NOT RUN, no second physical pad.**
  `decision-log.md:9050-9052`; mirrored at `sprint-status.yaml:138` and
  `5-7-pad-modes-2-3.md:282+`. The whole point of this item is two humans on two pads.
- **Per-attack-type counter ideas (sweep/jump/thrust, ranges, auto-aim)** — `E6-P/R6`, ruled OUT of
  E6 and given this block as their first named owner. See `## E5 residue` above.
- **Knockdown lie (2.5 s) and get-up (2.0333 s) durations both read slightly too long** -- shorten
  both, ratio preserved (6-6a live smoke, 2026-09-19; full entry and its couplings above).
- See also `## E5 residue` above for the E5 retune entries this block should also pick up —
  `chargeup unreadable` and `defense feel reads as the defender did nothing` are now DISCHARGED
  facts, by `6-1b` and `6-6a`/`6-6b` respectively, and `5-3/R6(d)` is SUPERSEDED outright, by `6-7`
  (`E6-P/R3`).
- The three `6-1d/R16` retune inputs (decision-log.md:9967-9973), not previously on this checklist:
  (i) homing range and unblockable reach are tuned TOGETHER, not independently; (ii) dodge-after-commit
  must cost more stamina than initiating an unblockable, or it escapes too easily; (iii) the GREEN
  travel profile needs its clip knob authored first, then should cover ~2/3 of its travel by the apex.
- **`6-5g` corpse lifetime (`corpse_lifetime_seconds`, 20 s) as a playtest knob** (`6-5g/R27`,
  `6-5g-counterspell-timed-and-in-flight.md:887`) -- a minion killed by the countered card is
  restored only while its corpse still lies; the counter window itself is unlimited, so the 20 s
  corpse lifetime effectively caps minion restore. Judge the feel, then price it.
- The operator's own feel notes already recorded in `docs/playtest-log.md` -- read them there, not
  copied here.

**Two open design decisions are answered here too, as QUESTIONS rather than defects** -- operator
ruling `E4-R/R1` (2026-09-01, decision-log E4 retrospective session). Neither is implementation work;
both are feel calls that cannot be judged headless, the same reason `E3-R/R3` gave for the melee
retune. Owner for both: the operator, with a pad in hand.

- **Open decision (b) -- does the reshuffle vulnerable window cost anything mechanically?** It ships
  at an authored 1.5 s with NO mechanical cost, behind `3-5b/R7`'s negative guard (nothing in `src/`
  may read it except the code that starts it and the code that emits its event). The question is the
  window's PRICE, not its existence. Open since 2026-07-22; re-fenced out of E3 and then out of E4
  (`E4-P/R11`), which is two epics with no owner -- the failure `E4-R/R1`'s rule exists to stop.
- **Open decision (e) -- does hand size ever vary?** `3-3` shipped `hand_size` as balance data and
  `3-6/R8` bounded the AUTHORED value at `<= 4` against the HUD's four fixed slots. It got MORE
  expensive to change during E4: `4-0/R1` bound the `hand_size` snapshot KEY to occupancy, and its
  N2 finding records the `<= 4` audit bound becoming more load-bearing. If it ever varies, whether
  the count is public becomes a NEW design question (`E3-RG/R4`). Judge the feel first, then price it.

## Deferred from: close-out of 6-6b-color-counters (2026-09-20)

Owners in decision-log session "6-6b-color-counters close-out (Tier A)".

- **Click-to-commit superseding the 6-1 hold/feint** -> new story `6-9` (Tier A, next on the board).
- **Card mode as a toggle (click L3), and "held L3 kills L2 block"** (live smoke item 8b) -> new story
  `6-10` (Tier B).
- **Homing range and attack readability** -> retune block.
- **Attacker mid-air pop into the knockdown** -> polish.
- **Suspicious hitboxes** (operator, solo re-smoke) -> playtest block.
- **A hold/pause on the attacker's head before RED's bounce** (presentation knob at the jump -> backflip
  join, `6-1b` hold precedent) -> retune block.
- **Dagger impact alignment** (the "hit" is the knockdown moment; align it to the dagger's arrival) -> polish.
- **"Countering an unblockable may not reward enough"** (levers: the attacker's knockdown length, a
  defender reward such as orb/mana) -> retune block, judged at the friends playtest.

## Deferred from: close-out of 6-5e-rocksling-boom-and-corpse-bomb (2026-09-29)

- **The two-Boulders `Invariant.check` in `inject_card_effects` is untested** (review-fix minor 4). It
  cannot be exercised from the headless harness: `Invariant.check` is `push_error` + `assert`, and the
  assert HALTS the harness rather than failing an assertion. Making it testable needs a new `MatchState`
  predicate (the same shape the neighbouring AC 1a collision check used, `_mirrored_values_agree`) -- a
  new public surface, i.e. a SHAPE decision for the operator, not a HOW.
- ~~**AC 24a's cosmetic half** -- the "Boulder's own row cycles no mode" mode-cycle suppression on a Boulder
  slot~~ -- DISCHARGED by `7-6-hud-and-card-presentation` (AC 21, dev pass 2026-10-05): a Boulder-covered
  slot shows neither the armed nor the card-mode frame highlight (`HudRoot._apply_highlights`, pinned by
  `test/integration/test_card_face.gd`); the `REASON_COVERED_SLOT` refusal at commit is unchanged.

## E6 residue (close-out 2026-10-01)

Owner: E6 close-out session, `E6-C/R9` (decision-log.md). Items below lived only in log prose or a
story file, with no `deferred-work.md` home, across the 23 E6 close-out sessions.

- **6-5g AC 14 stun half** (`6-5g/R25`, `6-5g-counterspell-timed-and-in-flight.md:323,735,739,770`)
  -- implemented, ROOT half proven, but the STUN half is structurally unobservable in a two-player
  match (mutation M8 GREEN accepted at close-out). Owner: none yet -- needs a test scenario with a
  third live unit; nearest candidate is `7-T1-tooling-debt` if it is picked up as a harness gap
  rather than a playtest question.
- **6-5g corpse lifetime as a playtest knob** (`6-5g/R27`, `:887`) -- see the Playtest checklist
  above, now carried there.
- **6-5g counter-on-counter** (`6-5g/R17`, `decision-log.md:11959-11961`; `deck-1-spec.md:236-239`)
  -- its own story, after the friends playtest. No board key yet (operator ruling, `E6-C/R11`).
- **Deck builder** -- after the friends playtest. No board key yet (operator ruling, `E6-C/R11`).
- **`5-1a/R14` exported-build `Invariant.check`, plus its `5-1a/R15` `camera_pushes` twin** -- owner
  `7-7-tuning-pass`, forcing point the FIRST EXPORTED BUILD for the friends playtest (`E6-R/R16`
  item 4, Claude ruling, operator veto open). `Invariant.check` is non-load-bearing EVERYWHERE in an
  exported build, not just the one seat `5-1a` fixed; recorded with no owner by `E5-R/R8` item 6 and
  again by `E6-P/R11`, so this closes a two-epic orphan -- a fence does not discharge a queue, a
  forcing point does (`E5-R/R1`).

The misplaced `### 6-8` subsection above (filed inside the `## E4 review residue` block) is a
findability defect, not moved here (`E5-R/R7` precedent against touching closed-record placement).

### Presentation debt, consolidated

Every item below was owned only by "the Tier B presentation story after 6-5f/6-5g" -- no board key,
no file. Now split and keyed (`E6-C/R11`):

- **`7-1-effect-presentation`** -- Grave Ward tint not visible (`6-5b-corpses-and-own-minions.md:401`);
  11 of 14 Deck 1 effects show only the generic cast-success cue; placeholder
  bolt/fireball/stones/skulls art (`bolt_actor.gd`, `projectile_actor.gd`); dizzy/root legibility
  (shipped in scope, read quality unmeasured); Boulder mode-cycle cosmetic suppression (above).
- **`7-2-animation-polish`** -- upper/lower body split (`6-5c/R5`, "OUT, Tier B presentation story
  after `6-5f`"); hit-reaction sliding while walking. **DONE in 7-2** (both).
- **`7-6-hud-and-card-presentation`** -- cost legibility (`6-5b` AC 23, failed at smoke); hand shown
  as text, no icons; no per-effect cast feedback (generic cue only); a new HUD (the shipped HUD is
  the 2-4 one, extended in place through `6-10`).

### Tooling, to `7-T1-tooling-debt`

- **m5 -- `_replay`'s unknown-channel drop is unfalsified for `colors`** (`6-5f/R45`,
  `test/state/test_replay_identity.gd:1618-1659`). Needs a `KNOWN_DROPS` guard, `colors` and
  `pitch_effects` drop branches, and a derived-coverage test against `IntentRecorder`'s surface.
- **`6-5b/R24` flake** -- "resources still in use at exit", three tests
  (`test_unit_combat_live.gd`, `test_charge_telegraph_dispatch_live.gd`, `test_card_mode_lift.gd`),
  six occurrences since 2026-09-05; FAILED-vs-warning split is the harness's, not the engine's.
- **`6-5b/R24` flake still open after 7-T1**: 0/4 full-suite runs with `-v` (2026-10-02); `run_all.sh`
  now captures details on the next occurrence; owner unassigned, E7 close-out assigns.
- **Stale comment at `src/main/match_runner.gd:2460`** -- still calls the 5-3 direct connect
  "standing but UNRESOLVED in the architecture amendment queue"; resolved by `E5-C/R2` (comment-only
  fix, SKIPPED by this close-out: it is a `src/` edit and this chain is docs-only).
- **`_replay` never replays push drain targets** (`replay_push_drain_targets` unused) -- found
  authoring `7-T1`; owner unassigned, E7 close-out assigns.

### 7-1 smoke and review residue (close-out 2026-10-04)

- **P9** lifesteal droplet heuristic false-fires on Counterspell HP refunds -- needs a state fact
  (Tier A). Owner: E7 close-out.
- **P10** shot-ending pairing counts a melee and a minion hit on the same tick together -- needs a
  state fact (Tier A). Owner: E7 close-out.
- **P11** concurrent identical one-shots have no limiter. Owner: operator's sound pass.
- **P12** Corpse Bomb first-use hitch -- watch. Owner: E7 close-out.
- **P14** Frostbite refresh is silent. Owner: E7 close-out.
- **P16** replay reads today's `CardDatabase` for effect rows, not the authored-at-cast row.
  Owner: E7 close-out.
- **P19** Rocksling lift-to-throw hard cut. Owner: `7-2`. **DONE in 7-2** (lift -> throw cross-fade).
- Smoke leftovers: Culling, Vampiric Aura and Bloodhound sounds (owner: operator's sound pass);
  root shackles read like a dress (owner: E7 close-out); stun pose transition and foot sliding
  during casts (**DONE in 7-2**); cast speed (owner: `7-7`, `7-2/R5`).
- `assets/CREDITS.txt` lacks the skull author's name (CC-BY). Owner: E7 close-out.
- New folders `src/actors/effects/`, `data/presentation/`, `assets/models/`, `assets/vfx/`,
  `assets/audio/effects/` are not yet in `game-architecture.md`'s directory tree. Owner: E7
  close-out.
- **P18**: update the existing `6-5b/R24` flake entry with the evidence -- a hero cue
  (`cue_hit.wav`) was named still playing at quit in a live test; `stop_all_sounds` covers only
  presenter sounds. Hypothesis, not a fix. Owner: E7 close-out.

## Deferred from: code review of 7-6-hud-and-card-presentation (2026-10-05)

Review artifact `C:\dev\_76-review.md`; fix pass in the same session.

- **N6** Card highlight rings are tight: an armed ring (5 px outset) and a neighbour's mode ring (3 px) fill the
  8 px card gap exactly, and an armed lifted card's ring reaches 1 px into the vitals column. Owner: 7-6 live
  smoke item 2 (operator judgement), then E7 close-out.
- **N8** A Boulder-covered slot shows no ARMED ring either, not only no mode ring (`HudRoot._apply_highlights`);
  whether arming a Boulder slot should show selection feedback is a smoke judgement. Owner: 7-6 live smoke.
  **DISCHARGED by operator ruling P17 (7-6 polish round 3, 2026-10-06):** a Boulder-covered slot arms exactly like
  any other card -- lifted, with its frame gold, while armed.
- **N11** `HudRoot._effect_color` colours a history entry by the FIRST card (sorted id) carrying the effect --
  exact for Deck 1 (each effect on one card), alphabetical accident once a deck shares an effect across colours.
  Owner: `7-5-deck-2`.

## 7-6 close-out (2026-10-06)

- **HUD scaling on smaller screens.** The HUD is native pixels (stretch disabled) and laid out for 960x1080 per half.
  Owner: before any build goes to other machines.
- **Telegraph shapes and tones are placeholders.** Replace the placeholder telegraph shapes and tones with subtler
  cues integrated into the animations and effects. Owner: the art phase (moved from `7-2`, which did not take it). Until then
  the shapes sit under F3 and the tones stay on (`7-6/P22`).

### 7-6 architecture-amendment candidates (E7 close-out flush)

For `game-architecture.md`'s amendment ledger at the E7 close-out; the doc is NOT edited by 7-6.

- **D1 relays:** two new `EventBus` signals (`card_effect_resolved`, `card_effect_countered`) and two new `:relay`
  raw `_match_state.<signal>.connect` sites, pinned in `test_architecture_invariants.gd` (`:inline` count stays 2,
  seam family stays ten).
- **First `_process` under `src/`:** `OrbHalo` (`src/actors/hero/orb_halo.gd`); the F1 pin is `_physics_process`
  only, and the HUD still has neither.
- **`project.godot`:** the fullscreen start (`window/size/mode=3`) and the F3 `debug_toggle_instruments` action.
- **Debug layer seat:** `MatchRunner.set_debug_layer_visible`, called by the F3 edge.
- **HUD in native pixels:** stretch disabled, the layout is per-half pixel geometry.

## Deferred from: code review of 7-9-unblockable-tempo (2026-10-08)

- Mana affordability is a raw float compare (`ManaPool.spend` and the 7-9 unblockable price at `match_state.gd:5961`, M13): mana earned by passive regen (0.25/s summed per tick) can sit a hair below 1.0 while the inspector rounds it to 1, which delays the first affordable click by about a tick. Pre-existing semantics; worth an epsilon or integer mana if smoke notices it.

## Deferred from: 7-10 close-out (2026-10-09)

- Eye tick sound reads like bubbles (`assets/audio/effects/sfx_eye_tick.wav` is a byte copy of `sting_attack.wav`). Owner: the operator's manual sound pass.
- The eye flash could be more striking (`FLASH_SCALE`, `FLASH_LIGHT_ENERGY` in `src/actors/hero/unblockable_eyes.gd`). Owner: polish, in the real-art phase.
- The RED jump/rebound tempo feels slightly slow (RED rate 1.587x, `counter_busy_seconds_red` 1.0 s, `counter_travel_forward_fraction_red` 0.49). Owner: 7-7.
- The dagger trail is cut off on arrival (review F7: it is a child of the dagger and is freed with it, rather than fading). Owner: polish.
- New files missing from the `game-architecture.md` tree: `src/actors/hero/unblockable_eyes.gd`, `src/actors/hero/immunity_shimmer.gd`, `src/actors/effects/unblockable_presentation.gd`, `tools/measure_head_visor.gd`. Owner: E7 close-out docs debt.

## Deferred from: 7-4 close-out (2026-10-09)

- Authoring test: every card's summed orb price must be <= `HudRoot.MAX_PIPS` (review MINOR-5). Owner: 7-7 or the next card-authoring story.
- Hourglass marker contrast on cards with large art is weak (operator smoke note). Owner: art phase.
- `test_unblockable_reach_live`: PRE-EXISTING intermittent failure (GREEN `late_close`; 1/8 at 690d5f0, 2/5 at HEAD with seed pinned 12345), likely the frame-counted defender teleport against the state tick at the 12-13 edge. Harden the test (sidestep on a state-tick count) with 7-7, which re-measures this test per 7-9/R22; add it to `run_all.sh` VERBOSE_FILES at the E7 close-out.
- `epics.md` 7-4 text still names "+1 mana for a defended unblockable" (delivered by 7-9/R6, not 7-4). Owner: E7 close-out.
- Commit trailer drift: `CLAUDE.md:32` says Claude Sonnet 5, recent commits carry Claude Sonnet 5.5. Owner: E7 close-out decides.
- The keyboard controller has no pitch path (pad only). Owner: E7 close-out decides whether parity is owed.
- Raise Dead's two-orb price as a sorcery (the 7-4 scope ruling on OQ5). Owner: 7-7 tuning input.

## Deferred from: 7-2 close-out (2026-10-09)

- **Bloodlust and Boulder-discard get no card gesture.** Neither writes a reversal kind, so a gesture needs a new state
  fact (Tier A). Owner: E7 close-out assigns.
- **Open question: replace the two Rocksling clips (lift, throw) with a single clip.** The lift -> throw junction is
  cross-faded (P19) and stones 2/3 fly without a swing (`7-2/R8`); a single authored clip would remove the seam.
  Owner: art phase.
- **Done in 7-2:** P19, stun pose transition, foot sliding during casts, hit-reaction sliding, upper/lower split.
