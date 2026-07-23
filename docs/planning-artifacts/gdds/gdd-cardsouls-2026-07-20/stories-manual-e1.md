---
title: CardSouls — E1 Stories (Melee Combat + Training Dummy)
parent: epics.md
epic: E1
created: 2026-07-21
status: ready
depth: full
---

# E1 — Melee Combat + Training Dummy

**Epic goal.** Build the soulsborne combat heartbeat in the state + actor layers, against a
non-retaliating opponent slot. Feel is *tuned* here; feel is *judged* in E2 against a moving human.

**Precondition.** E0 is complete and pushed: state core (`SignalQueue`, `MatchState.advance(intents)`
+ `drain_signals()`, `PlayerState`/`HeroState`/pools, `TimingWindow`, `InputIntent`), `Controller` +
prefix `KeyboardController`, `match_runner` as the single `_physics_process`, `HeroActor` driven by
`HeroState.velocity`, headless harness + determinism regression, three grep-checkable invariants
under `test/state/test_architecture_invariants.gd`.

## Before you start (read this if you were not in the design conversations)

1. **Document precedence:** `gdd.md` > `game-architecture.md` > `project-context.md` >
   `tdd-legacy-ue5.md` (legacy: mechanics reference only, engine details obsolete). See `CLAUDE.md`.
2. **Read before touching code:** architecture §D2 (tick order), §D3 (controller/state purity),
   §D4 + Novel Pattern 4 (`TimingWindow`, integer ticks), §D5 (queued signals), §D7 (telegraph),
   §Spatial Model & the `_physics_process` boundary (F1), §Testing & Runtime Boundary (X6).
3. **Non-negotiable invariants** (already enforced by `test_architecture_invariants.gd` — do not
   weaken the test to make a story pass):
   - `match_runner.gd` holds the project's only `_physics_process`. Actors never define one.
   - `Input.*` appears only under `src/controllers/`.
   - `src/state/` contains no nondeterministic source; the seeded RNG owned by `MatchState` is the
     only randomness.
   - Gameplay-critical timing counts integer ticks via `TimingWindow`. Never a float accumulator,
     never an engine `Timer`/`SceneTreeTimer`, never `await`.
   - Zero hardcoded gameplay numbers — every value is a field in a balance `.tres`.
4. **Tick order is fixed** and is the frame of reference for every story below:
   `sample controllers → gather spatial facts → advance(intents) → drive actor movement → drain signals`.
   Inside `advance()`: `ingest intents → advance timers → resolve actions → resolve contacts →
   resource generation → card/economy → board [E4 seam] → resolution check`.
5. **Tests:** headless state tests in `test/state/test_*.gd` (extend `TestCase`), runtime scene tests
   in `test/integration/`. Run everything with `bash test/run_all.sh`; it must exit zero.
   A fresh clone needs one `godot --headless --editor --quit` to build the class cache.

**Story order is the implementation order.** Each story is independently commitable and leaves the
repo green.

---

## E1.S1 — Melee balance schema + hot-reloadable seconds→ticks conversion

**Depends on:** E0 (complete).
**Read first:** architecture §Configuration + X3, §D4/A1, Novel Pattern 2 (`set_maximum` re-injection).

1. Extend `src/state/resources/balance_config.gd` with the E1 melee fields, all `@export`, grouped
   and named for authoring: hero (`max_hp`, `move_speed`), stamina (`max_stamina`,
   `stamina_regen_per_second`, `stamina_regen_delay_seconds`, per-action costs `roll_stamina_cost`,
   `deflect_stamina_cost`), attack (`attack_windup_seconds`, `attack_active_seconds`,
   `attack_recovery_seconds`, `attack_chain_window_seconds`, `attack_chain_length`,
   `attack_damage_percent_of_max_hp`), defense (`block_damage_multiplier`,
   `deflect_window_seconds`), roll (`roll_iframe_seconds`, `roll_duration_seconds`,
   `roll_distance`). Every value is authored in `data/balance/` — leave real numbers as first-guess
   placeholders and treat them as TBD-in-playtest.
2. Add a single conversion boundary: a `BalanceTicks` helper (or a `to_ticks()` block on the injected
   config wrapper) that converts every `*_seconds` field to a tick count **once**, at load and at
   X3 reload, via `TimingWindow.seconds_to_ticks()` (`round()`, clamped to `>= 1` for any non-zero
   duration). State code reads tick counts only; a `*_seconds` field must never reach `advance()`.
3. Wire the X3 hot-reload path end to end for the new fields: `BalanceConfigService` reloads the
   `.tres` and calls `MatchState.apply_balance(config)`, which re-injects bounds into the pools
   (`set_maximum`-style, re-clamping and re-signalling) and re-converts durations. A `TimingWindow`
   already in flight keeps its original duration; the new value takes effect at its next `start()`.
4. Extend the existing `.tres` smoke test so every new field is asserted present and non-negative,
   and add a headless test for the conversion rules: `0.0 s → 0 ticks`, a sub-tick non-zero duration
   → exactly 1 tick, and `round()` (not floor/ceil) at the halfway boundary.
5. Add a headless test that hot-reloading mid-match does not disturb an in-flight window: start a
   window, tick it partway, apply a config with a different duration, and assert the running window
   finishes on its original tick count while the next `start()` uses the new one.

**Exit criterion.** Every E1 melee number is authored in `data/balance/*.tres`, converted to ticks
exactly once at load/reload, and `bash test/run_all.sh` is green including the new conversion and
hot-reload tests.

---

## E1.S2 — Camera rig + camera-relative movement as a pushed spatial fact

**Depends on:** E1.S1.
**Read first:** architecture §Spatial Model → *Camera-relative movement is a pushed fact* (this
story implements the sanctioned approach; both shortcuts named there are defects).

1. Build the camera rig as an actor-side node attached to the hero scene: third-person, **fixed
   distance, no zoom**, pulled back slightly further than Elden Ring's default so the hero is fully
   visible with terrain context. Camera distance/height/pitch are balance-authored, not literals in
   the scene script. The rig has no `_physics_process`; the runner drives it.
2. Add a per-player camera-basis spatial fact to the runner's step 2: the runner reads each player's
   camera basis and pushes it into `MatchState` **indexed by player slot** (a small fixed-size array,
   not a single global basis). Sizing it per slot now is what keeps E2 a config change rather than a
   refactor — do not push one shared basis.
3. In `advance()` step 1/3, treat `intent.move_dir` as a **camera-space** direction: rotate it by the
   stored basis for that player (yaw component only; the camera's pitch must not tilt movement) and
   write the world-space result into `HeroState.velocity`. `HeroState.velocity` remains the actual
   world velocity the actor consumes — the runner never rotates it after reading.
4. Define the behaviour when no basis has been pushed yet (tick 0, headless tests, a controller with
   no camera): the stored basis defaults to identity and `move_dir` is treated as world-space. This
   keeps every existing E0 state test valid and keeps `advance()` free of null checks scattered
   through the movement path.
5. Cover it both ways: a headless test that a known basis rotates a known `move_dir` to the expected
   world velocity (and that pitch is ignored), and an integration test that rotates the camera, feeds
   a fixed forward intent, and asserts the actor's world displacement follows the camera.

**Exit criterion.** Holding "forward" moves the hero relative to where the camera looks, the camera
basis reaches state only as a runner-pushed per-slot fact, and neither shortcut (state reading the
camera, runner rotating velocity) exists anywhere in `src/`.

---

## E1.S3 — Hero action-state machine + action timing windows

**Depends on:** E1.S1, E1.S2.
**Read first:** architecture §Hero Action-State Representation, §D4, §D2 step 2/3.

1. Implement `ActionState { IDLE, ATTACKING, BLOCKING, ROLLING, STUNNED, CHARGING }` on `HeroState`
   as a pure enum plus an explicit transition table evaluated in `advance()` step 3 from
   `InputIntent` + the active `TimingWindow`s. `CHARGING` is reserved for E5 and is unreachable in
   E1 — leave the transition absent rather than stubbing a fake path.
2. Give `HeroState` its per-action windows as `TimingWindow` instances owned by the hero (windup,
   active, recovery, chain window, block/deflect window, roll i-frame, roll duration, stun), all
   advanced in `advance()` step 2, one tick per call, before any transition is evaluated. Timers
   advance first, transitions read the result — write this order down in the file so nobody flips it.
3. Define action cancellability explicitly as data on the transition table, not as scattered `if`s:
   which states accept a new attack, a roll, a block, or nothing. Souls convention for E1: recovery
   is roll-cancellable, active frames are not; `STUNNED` accepts no input. Any deviation is a
   playtest decision, so keep the table a single readable block.
4. Emit a queued `action_state_changed(previous, current)` signal on every transition, pushed to the
   `SignalQueue` (never emitted mid-tick). This is the single hook the presentation layer (E1.S10)
   and the HUD (E2) subscribe to — no other code path may tell visuals what the hero is doing.
5. Add headless tests driving fixed intent sequences over N ticks: each action reaches and leaves its
   states on the exact expected tick, inputs during a non-cancellable window are dropped rather than
   buffered, and the emitted signal sequence (after `drain_signals()`) matches the expected list.

**Exit criterion.** Every melee action in E1 is a transition in one table, all its timing is integer
ticks in `advance()` step 2, and the state sequence is asserted headless without a scene.

---

## E1.S4 — Stamina economy

**Depends on:** E1.S3.
**Read first:** GDD §Primary Mechanics → Hero resources; architecture Novel Pattern 2, §D6.

1. Extend the existing `StaminaPool` with regeneration: a **fixed per-tick amount** converted once
   at load from `stamina_regen_per_second` (never `rate × delta`), applied in `advance()` step 5,
   with a regen delay window that restarts on every stamina spend.
2. Route every stamina cost through one deduction path used by roll, deflect, and (reserved,
   flag-off until E5) unblockable initiation/defense. Costs come from the injected balance config;
   no action subtracts stamina inline.
3. Implement the zero-stamina lockout as a **precondition on the transition table**, not as a
   post-hoc failure: with insufficient stamina, the roll/deflect transition never fires and the hero
   stays in its current state. Emit a queued `action_rejected(action, reason)` so the HUD/audio can
   signal "you had nothing left" — loss legibility is mandatory (GDD §Success Metrics).
4. Prefer expressing generation as a `ResourceGenerationRule` `.tres` (`source: &"passive_tick"`,
   `resource: &"stamina"`) evaluated by the existing `EconomyEvaluator`, so the Stamina Accelerator
   totem (E4) is a new `.tres` rather than a code change. If the evaluator does not yet cover
   stamina, extend it here — this is exactly the economy-wide scope D6 was written for.
5. Headless tests: regen reaches max in the expected tick count and never overshoots; the delay
   window restarts on spend; an action at exactly the cost succeeds and at cost-minus-one is
   rejected with the signal; `stamina_changed` fires only on actual change.

**Exit criterion.** Stamina gates roll and deflect through one deduction path and one lockout rule,
regenerates a fixed per-tick amount from data, and the boundary cases are asserted headless.

---

## E1.S5 — Basic attack chain

**Depends on:** E1.S3, E1.S4.
**Read first:** GDD §Primary Mechanics → Basic Attack, §F (no combo system — chains, not links);
architecture §D2 steps 3–5.

1. Implement the attack chain in state: an attack index advancing while the input lands inside the
   chain window during recovery, capped at `attack_chain_length`, resetting to zero when the window
   expires. No links, no juggles, no cancels — souls-style chains only.
2. Expose the hitbox as **state data, not a scene decision**: `HeroState` carries
   `is_hitbox_active` (plus the chain index, so per-swing tuning is possible later), set true only
   during the active window. The actor reads this flag; the actor never decides when it can hit.
3. Attack costs no resource (GDD: basic attack is free) but must generate mana on hit. Land the
   generation **hook** now: on a confirmed contact, call the economy evaluator with
   `source: &"melee_hit"`. In E1 no such rule is authored, so the call is a no-op — E3 authors the
   `.tres` and the flywheel starts. Do not branch on a feature flag inside the hook; the absence of
   a rule is the graceful degradation.
4. Add per-swing contact deduplication in state: one swing may damage a given target at most once,
   tracked on the attack instance and cleared when the active window closes. Solving this in state
   (not by disabling an `Area3D`) keeps it headless-testable and replay-safe.
5. Headless tests: chain advances only inside the window and caps correctly; `is_hitbox_active` is
   true for exactly the active-window ticks; the same target contacted twice in one swing takes
   damage once; the economy hook is invoked once per confirmed hit.

**Exit criterion.** The attack chain runs entirely in the state layer with the hitbox lifetime and
per-swing dedupe as state facts, and the melee→mana hook is called on hit with no rule authored yet.

---

## E1.S6 — Second player slot as the training dummy (controller config swap)

**Depends on:** E1.S3.
**Read first:** GDD §Controls → *Input architecture (binding invariant)*; epics E1/E2/E7 — dummy →
PvP → bot must be a config swap, not three implementations.

1. Instantiate the opponent as a **full second `PlayerState` + `HeroActor`**, identical in every
   respect to P1, driven by a `NullController` (`src/controllers/null_controller.gd`) that returns a
   fresh empty `InputIntent` each tick. Nothing in the hero, the actor, or `advance()` may branch on
   "is this the dummy" — the dummy is a controller choice and nothing else.
2. Make the controller assignment per slot a single point of configuration in `match_runner` (a
   small exported/injected setup describing slot → controller kind), so E2 replaces
   `NullController` with `KeyboardController("p2")` / `GamepadController` and E7 with
   `ScriptedController`, each a one-line change.
3. Confirm the invariant survives: run the grep checks (`func _physics_process`, `Input.`,
   state-purity) after adding the second slot; the second actor must not acquire its own
   `_physics_process`, and the runner drives both actors' movement in step 4 in fixed slot order
   P1 → P2.
4. Give the dummy a reset affordance for tuning: a debug action (behind the `debug` flag,
   `src/ui/debug/`) that restores its HP and clears its action state through a state-layer method —
   the debug UI calls a method, it never writes fields.
5. Extend the determinism regression to two populated slots: N ticks from a fixed seed with a fixed
   intent list for both slots must reproduce the golden hash, and slot ordering must be stable
   (the existing key-order-independence guardrail still holds).

**Exit criterion.** A second hero stands in the arena driven by `NullController`, both actors are
driven by the one runner in fixed slot order, no code anywhere branches on the opponent being a
dummy, and the determinism test covers two slots.

---

## E1.S7 — Contact pipeline: hitbox facts → damage → HP → death

**Depends on:** E1.S5, E1.S6.
**Read first:** architecture §D2 (contacts, step 2→4), §Spatial Model (actors REPORT, state DECIDES),
§X6 (this is the story where coverage moves partly to integration tests).

1. Add `Hitbox` and `Hurtbox` `Area3D` nodes to the hero scene with an explicit collision-layer/mask
   convention documented in the scene and in `project-context.md`. Neither node contains gameplay
   logic and neither applies damage.
2. Implement fact gathering in the runner's step 2 by **direct query** (`get_overlapping_areas()` on
   hitboxes state-flagged active), never `area_entered` signals — their firing order is not
   guaranteed and would make replay order-dependent. Push contact facts (attacker slot, target slot,
   attack index) onto the queue consumed by `advance()` step 4.
3. Resolve contacts in `advance()` step 4 only: apply damage from balance (as a percentage of max HP
   per GDD's chip-damage rule), honour the per-swing dedupe from E1.S5, and route the confirmed hit
   into the melee→mana hook. Queue `hp_changed` and a `hit_landed` signal carrying enough
   information for the presentation layer to react.
4. Implement death in `advance()` step 8 (resolution check): at HP ≤ 0 the hero enters a terminal
   state, further contacts are ignored, and `round_ended` is raised through `EventBus` (the one
   genuinely ownerless global event). Demo scope is a single round — no restart flow beyond the
   debug reset from E1.S6.
5. Testing splits deliberately: damage arithmetic, dedupe, death threshold, and signal order are
   **headless** tests fed synthetic contact facts; the actual `Area3D` wiring (an active hitbox
   overlapping a hurtbox produces exactly one fact per swing, and facts lag movement by a constant
   one tick) is an **integration** test in `test/integration/`. Record the constant one-tick lag as
   an asserted expectation, not a comment.

**Exit criterion.** Swinging at the dummy reduces its HP by a data-authored amount and kills it at
zero, damage is decided exclusively in `advance()` step 4 from runner-pushed facts, and both the
headless and integration halves of the pipeline are asserted.

---

## E1.S8 — Block and Deflect

**Depends on:** E1.S7.
**Read first:** GDD §Primary Mechanics → Block/Deflect, §F (defensive layer, stamina as the currency
of survival).

1. Implement block as a held state: entering `BLOCKING` on hold, leaving on release, with damage
   multiplied by `block_damage_multiplier` when a contact resolves against a blocking target facing
   the attacker. Facing is a spatial fact — the runner reports the attacker's relative angle, state
   decides whether the block applies.
2. Implement deflect as a `TimingWindow` opened on the block press: a contact resolving inside the
   window is a **deflect** (no damage, stamina cost paid, `deflect_landed` queued); the same contact
   after the window is an ordinary block. The window length is the single most feel-sensitive number
   in E1 — it lives in balance and must be tunable by hot-reload without restarting the match.
3. Keep the attacker's consequence out of scope for E1. A deflect negates damage and emits its cue;
   attacker stagger/punish is not specified in the GDD for basic attacks and must not be invented
   here. Log the question in `decision-log.md` instead of guessing at it in code.
4. Deduct deflect stamina through the E1.S4 single deduction path and apply the same lockout rule:
   with insufficient stamina, the deflect window never opens and blocking degrades to plain block
   (with `action_rejected` emitted so the player can tell what happened).
5. Headless tests: a contact one tick inside the window deflects and one tick outside blocks (the
   exact boundary, both sides); block reduces damage by the authored multiplier; a back-facing block
   does not apply; deflect at zero stamina degrades to block and emits the rejection.

**Exit criterion.** Holding block reduces incoming damage, a press timed into the deflect window
negates it entirely at a stamina cost, both boundaries are asserted headless on exact ticks, and the
window length is hot-reloadable mid-match.

---

## E1.S9 — Roll with i-frames

**Depends on:** E1.S8.
**Read first:** GDD §Primary Mechanics → Roll; architecture §Spatial Model (F1 — the actor moves,
state decides).

1. Implement roll as a transition to `ROLLING` costing stamina, with direction taken from the
   camera-relative `move_dir` at the moment of input (falling back to the hero's facing when the
   stick is neutral). The roll's motion is written into `HeroState.velocity` in `advance()` step 3
   — the actor never applies its own displacement.
2. Implement invulnerability as **state**, not as a disabled node: an i-frame `TimingWindow` sets
   `HeroState.is_invulnerable`, and `advance()` step 4 discards contact facts targeting an
   invulnerable hero. Do not disable the hurtbox `Area3D` — the fact still arrives and state decides,
   which keeps the rule headless-testable.
3. Model the roll's three phases from balance: i-frames (a subset of the roll), roll duration, and
   the recovery during which no new action is accepted. The i-frame window may open on a later tick
   than the roll itself; keep both windows independent so the relationship is tunable.
4. Enforce the E1.S3 cancellability table: roll may cancel attack recovery, may not cancel active
   frames, and is unavailable while `STUNNED` or below the stamina cost (with `action_rejected`).
5. Headless tests: a contact during i-frames deals zero damage and one tick after i-frames deals
   full damage; roll direction resolves from `move_dir` and from facing when neutral; roll at
   insufficient stamina does not fire; roll during active frames is dropped. Add one integration test
   that a roll actually displaces the actor in the intended world direction.

**Exit criterion.** Rolling moves the hero in the camera-relative input direction, ignores damage for
exactly the authored i-frame ticks with the hurtbox left enabled, and the exact i-frame boundary is
asserted headless.

---

## E1.S10 — Telegraph structure and combat cues (presentation layer)

**Depends on:** E1.S3–E1.S9.
**Read first:** architecture §D7 (this is structure, not polish — it exists in E1 so E5 reuses it),
GDD §Legibility Principle, §Audio and Music.

1. Author `TelegraphProfile` `.tres` instances for the E1 melee actions in `data/telegraphs/`
   (`shape_id`, `sting_id`, `color`, `pose_id`), referenced by the action, not embedded in it.
   `TelegraphProfile` is standalone precisely so E5's colour telegraphs reuse the same type.
2. Define the audio bus layout with a dedicated **`CombatCues`** bus, separate from `Music` and
   `Ambience`, so functional cues are structurally impossible to mask. Route attack/hit/deflect/roll
   and the `action_rejected` cue through it. Placeholder sounds are fine; the bus layout is not.
3. Implement `telegraph_controller.gd` in `src/actors/hero/` as a **read-only** subscriber to the
   state signals from E1.S3–E1.S9. It reads which telegraph is active and drives shape + sound. It
   must never call a state method that mutates, and it must never decide an outcome — the dependency
   direction is visuals → state, always.
4. Land the deflect spark, hit reaction, and outcome cues now. GDD §Success Metrics makes loss
   legibility mandatory: after every exchange the player must be able to say what happened, and E1 is
   where that habit is established rather than retrofitted.
5. Verify the direction rather than the aesthetics: an integration test (or the architecture
   invariant test) asserting that nothing under `src/actors/**/telegraph_controller.gd` or `src/ui/`
   calls a state mutator, and a manual check that every E1 action produces a distinct audible cue on
   the `CombatCues` bus.

**Exit criterion.** Every E1 action carries a `TelegraphProfile` and an audible cue on a dedicated
`CombatCues` bus, driven entirely by queued state signals, with no presentation code able to mutate
state.

---

## Epic exit criteria (E1 complete when all hold)

1. Timing-critical melee logic runs inside `advance()` on integer ticks; `match_runner` is still the
   only `_physics_process`.
2. `bash test/run_all.sh` is green: the headless suite covers the stamina economy, HP/damage, the
   deflect window, and the i-frame boundary on exact ticks; integration tests cover the `Area3D`
   contact wiring and actor displacement.
3. Combat is fully exercisable against the dummy: chain, block, deflect, roll, kill.
4. Every E1 number is authored in `data/balance/` and tunable by hot-reload mid-match.
5. The determinism regression passes with two populated player slots.

## Explicitly out of scope for E1

Split-screen, a second human, HUD, cards, mana generation rules, unblockables, orbs, minions,
the scripted bot. The melee→mana hook is called but no rule is authored (E3). `CHARGING` exists in
the enum and is unreachable (E5).
