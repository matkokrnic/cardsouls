# Deferred Work

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
- **AC6(b)'s "one-word correction" claim (`unit_board.gd:303`) understates its own diff** — three
  lines of `3-6/R2` citation commentary were also appended. Still comment-only, still satisfies AC7.

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
| M5 | `_44-review.md:381` | Live homing test cannot tell steering toward from steering away | DEFERRED (`E5-P/R6`), owner: next story touching `test_projectile_homing`-class coverage (likely the E6 spell story) |
| M6 | `_44-review.md:398` | Reordering `unit_kinds` at an X3 reload silently re-points every live record | DEFERRED (`E5-P/R6`), owner: the E6 close-out spell story (next to add a `unit_kinds` entry); determinism-adjacent note kept |
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
| M5 | `_46-review.md:276` | Keyboard slots can no longer face anything but the opposing hero | (b) |
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
  richer minion behaviour" language above.
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

## Playtest block after E5+E6 -- checklist

Per operator ruling `R-SPELL` (2026-09-01, decision-log E4 close-out session), the melee retune +
playtest block deferred on 2026-08-30 runs AFTER the E6 close-out story that gives spell resolution
its own forcing point, so the playtest sees working spells rather than named no-ops. When that
window opens, this checklist is the block's scope:

- Every **(b)**-tagged finding above (4-5 D8; 4-6 M1, M2, M5, L5, L6, L10; 4-6a M2, M3).
- ~~Arena has no edge~~ -- REMOVED from this checklist: E5 planning slotted it as `5-0d-arena-edge`
  (named gap above, `E5-P/R2`).
- **Minions freeze in front of an obstacle** (named gap, above).
- **`standard` priority gives a dead arena at 10v10** (named gap, above).
- **AC 11 flicker cause** (named gap, above).
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
