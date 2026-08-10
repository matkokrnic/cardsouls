# Deferred Work

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
  change). OWNER: `4-3b-minion-attack-rhythm`.

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
