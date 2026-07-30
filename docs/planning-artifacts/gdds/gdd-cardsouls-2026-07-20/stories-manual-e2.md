---
title: CardSouls — E2 Stories (Local Split-Screen PvP)
parent: epics.md
epic: E2
created: 2026-07-21
status: ready
depth: full
---

# E2 — Local Split-Screen PvP

**Epic goal.** Make the build 2-player from week one, put every HUD element in its real half-width
space, and create the viewport in which combat feel and <0.5 s telegraph legibility are actually
judged.

**Why this epic sits here and not later.** Split-screen is a *constraint*, not a feature. A HUD built
full-width and later squeezed is a HUD designed twice, and telegraph legibility claims made at full
width are claims made in the wrong viewport. E2 also delivers the first genuine feel signal: E1 tuned
hitboxes against something that does not move.

**Precondition.** E1 complete: melee heartbeat, contact pipeline, telegraph structure, and a second
player slot already instantiated and driven by `NullController`.

## Before you start (read this if you were not in the design conversations)

1. Same document precedence and invariants as E1 — see `stories-e1.md` §Before you start and
   `CLAUDE.md`. Nothing in this epic relaxes them.
2. **Additional architecture reading:** §Technical Requirements → *Information-model integrity under
   split-screen* (the face-down-hand capability is a required E2 structural capability, not a later
   feature), §D7 (legibility is architectural), §Debug Tools, §Instrumentation wiring (X5).
3. **One `MatchState`, two views.** Split-screen does not duplicate state. There is one match, one
   `advance()`, one signal queue; the split is two `SubViewport`s and two HUD roots subscribing to
   different players' signals.
4. **The information model is a design commitment, not a testing artefact.** Hands are private; the
   only public card is the one staged in the Pitch Zone. Because both players share a display, the
   HUD must be *able* to render the opponent's hand face-down. Skipping this makes bluffing
   unobservable under full information and invalidates the P3 playtests it exists to serve.

---

## E2.S1 — Two `SubViewport`s and the split-screen rig

**Depends on:** E1 complete.
**Read first:** architecture §Engine-Provided Architecture (scene mgmt), §Spatial Model (F1).

1. Restructure `main.tscn` into a split-screen root: two `SubViewportContainer` + `SubViewport`
   pairs laid out side by side, each hosting its own `Camera3D` following its own hero, with the
   shared 3D world rendered into both. Do not duplicate the world or the actors.
2. Keep the F1 boundary intact: neither viewport, camera, nor container acquires a
   `_physics_process`. The runner drives camera follow in its movement phase (step 4), after
   `advance()` and before signals drain, so camera position is a deterministic function of the tick.
3. Extend the per-slot camera-basis fact from E1.S2 to genuinely two entries: slot 0 reads camera 0,
   slot 1 reads camera 1, gathered in step 2 in fixed slot order. Verify a player's movement is
   relative to *their own* camera and unaffected by the other camera's rotation.
4. Re-check camera framing at half width against the GDD's requirement: fixed distance, no zoom,
   pulled back slightly further than Elden Ring's default, with the hero fully visible and enough
   terrain context to read spacing. Adjust the camera values authored in `data/camera_config.tres`
   — presentation-side, load-once, outside `BalanceConfig` and outside the X3 hot-reload path (2-1
   micro-decision, review-accepted); if the pulled-back framing does not survive half width, that is
   a finding worth logging in `decision-log.md`, not silently zooming in.
5. Measure the frame budget with both viewports live: capture frame time over a full melee exchange
   and confirm the 60 FPS target (~16.6 ms) holds. Record the measured number in
   `docs/playtest-log.md` — it is the baseline every later epic's performance claim is compared to.

**Exit criterion.** Two viewports render the one shared arena, each following its own hero at the
authored camera framing, movement is per-player camera-relative, the runner is still the only
`_physics_process`, and 60 FPS holds with both viewports active.

---

## E2.S2 — Gamepad controller and P1/P2 input profiles

**Depends on:** E2.S1.
**Read first:** architecture §D3 + Novel Pattern 3, `project-context.md` §Platform & Build Rules
(named actions only, one controller class with a `"p1"`/`"p2"` prefix).

1. Complete the P1/P2 Input Map action sets for every E1 action plus the actions E3 will need
   (play-card, stage-card, mode-select), using named actions and physical keycodes — never raw
   keycodes read inline, never a second controller class per player.
2. Implement `gamepad_controller.gd` as the second `Controller` implementation, mapping stick input
   to `move_dir` and buttons to the same named actions, with a deadzone value authored in config
   rather than hardcoded. It emits the identical `InputIntent` shape — the runner cannot tell it
   apart from keyboard.
3. Handle device assignment explicitly: which joypad device index maps to which slot, and what
   happens on disconnect (the intent goes neutral; the match does not crash and does not pause). Keep
   this logic in the controller, never in the runner or state.
4. Confirm the D3 invariant after adding the implementation: `grep -rn "Input\." src/` still matches
   only under `src/controllers/`, and the architecture invariant test still passes unmodified.
5. Add an integration test that a synthetic gamepad-style intent and an equivalent keyboard intent
   produce byte-identical `HeroState` outcomes over N ticks. Input source must be indistinguishable
   downstream — that equivalence is what makes E7's bot a config swap.

**Exit criterion.** A gamepad drives either slot through the same `InputIntent` path as the keyboard,
both profiles are named-action driven, and the input-source-equivalence test passes.

---

## E2.S3 — Opponent slot becomes a second human

**Depends on:** E2.S2.
**Read first:** epics E1/E2/E7 (dummy → PvP → bot is a config swap); E1.S6.

1. Change slot 1's controller from `NullController` to a real controller through the single
   configuration point built in E1.S6 — and confirm that this is the *entire* change required in
   `src/`. Any additional edit to hero, actor, or state code is a defect in the E1.S6 seam; fix the
   seam rather than the symptom.
2. Add a lightweight match-setup selection (a small pre-match scene or a config resource) choosing
   each slot's controller kind: keyboard-p1 / keyboard-p2 / gamepad / null. This is the same
   affordance E7 extends with `scripted`, so shape it as data now.
3. Keep per-player state genuinely separate and privately consumed: each HUD root subscribes only to
   its own player's signals. No HUD element may read the opponent's `PlayerState`, even for something
   currently harmless like HP — the habit is what protects the E3 hand.
4. Verify determinism survives two live controllers: record an `InputIntent` stream from a real
   two-human round and replay it through `ReplayController` on both slots, asserting the same final
   state hash. This is the first real exercise of the X5 path.
5. Play a full round human-vs-human and record first impressions of spacing, attack weight, deflect
   timing, and stamina pressure in `docs/playtest-log.md` — in prose, honestly, including what feels
   wrong. This log is the input to the E3 revisit gate.

**Exit criterion.** Two humans fight a full melee round in split-screen, achieved by a controller
configuration change alone, a recorded round replays to an identical hash, and the first feel notes
are written down.

---

## E2.S4 — Per-player HUD root in real half-width space

**Depends on:** E2.S1.
**Read first:** GDD §Legibility Principle, §Asset Requirements → UI/HUD; architecture §D5 (HUD
subscribes; never polls, never writes).

1. Build one HUD root per viewport (`src/ui/hud/`), rendered inside its own `SubViewport` at true
   half width. Every element is authored and evaluated at that size from the first commit — never
   designed full width with a resize planned later.
2. Implement HP, stamina, and mana bars as **signal-driven** consumers of the queued state signals
   (`hp_changed`, `stamina_changed`, `mana_changed`). No `_process` polling, no per-frame recompute of
   an economy value. The mana bar exists now and simply sits at its passive value until E3 gives it
   sources.
3. Reserve, size, and lay out the regions E3–E6 will fill: the 4-card hand strip, three orb counters,
   the Pitch Zone slot with its timer, and deck/reshuffle indicators. Empty placeholders that occupy
   their real footprint now are the point — this is the layer where CardSouls discovers whether the
   full HUD fits the space at all.
4. Apply P4 to the layout: the reactor must never hunt for information during a half-second read.
   Keep the elements that matter under reaction pressure (stamina, incoming telegraph, pitch timer)
   near the centre of attention, and the ones consulted at the player's own tempo (deck count, orb
   totals) at the periphery. Write the rationale into the HUD scene as a comment so a later change
   knows what it is breaking.
5. Confirm legibility at real size and distance: a screenshot at final resolution in which every
   reserved element is identifiable, plus a check that no element is clipped by the split boundary or
   by the pulled-back camera's arena view.

**Exit criterion.** Each player has a signal-driven HUD occupying its real half-width space, with
every E3–E6 element already reserved at its true footprint, and no polling anywhere in `src/ui/`.

---

## E2.S5 — Information-model integrity: face-down opponent hand

**Depends on:** E2.S4.
**Read first:** architecture §Technical Requirements → *Information-model integrity under
split-screen* (required capability); GDD §Card System (hands private; only the pitched card public).

1. Establish a per-viewport visibility rule in the HUD layer: each HUD root knows which player it
   belongs to and renders that player's hand face-up and the opponent's hand **face-down**. The rule
   lives in one place, so E3 cannot accidentally leak by adding a card widget.
2. Implement the face-down representation now against the reserved hand region from E2.S4 —
   placeholder card backs, correct count, correct footprint. E3 populates real cards into a slot
   whose privacy behaviour already works.
3. Model the exception explicitly rather than by omission: the Pitch Zone card is the *only* public
   card, and its slot renders face-up in both viewports. Write it as the single documented exception
   so E6 inherits the rule instead of re-deciding it.
4. Add the debug reveal-opponent-hand toggle behind the `debug` flag in `src/ui/debug/`. It changes
   only presentation and mutates nothing. It exists for diagnosis; it must default to off so that the
   default playtest condition is the real information model.
5. Verify by inspection and by test: with the debug toggle off, no face-up card data of the opponent
   is rendered in a player's viewport, and no HUD code path reads the opponent's `PlayerState`
   directly (grep the HUD layer for cross-player access).

**Exit criterion.** Each viewport shows its own hand face-up and the opponent's face-down by default,
the Pitch Zone slot is the single documented public exception, and the reveal toggle is debug-only
and off by default.

---

## E2.S6 — Legibility and feel validation instrumentation

**Depends on:** E2.S3, E2.S4, E2.S5.
**Read first:** architecture §Debug Tools, §Instrumentation wiring (X5); GDD §Success Metrics
(interpretation rules).

1. Land the runtime `FeatureFlags` toggle overlay (debug-flag gated). This is the GDD's overload
   instrument: a playtest must be able to turn a layer off between rounds without a code edit. E1/E2
   have few flags yet — build the overlay now so E3 onward gets it free.
2. Land the deterministic step/pause debug control: pause the runner and advance N fixed ticks. This
   is how a deflect window or a telegraph is inspected frame by frame, and it is the only honest way
   to answer "I didn't see that happen" — the GDD's stated legibility defect signal.
3. Land the per-player state inspector (pools, active `TimingWindow`s, current telegraph), reading
   signals only, never mutating. Keep it in `src/ui/debug/`.
4. Write the **telegraph legibility protocol** into `docs/playtest-log.md` as a repeatable procedure,
   not a vibe check: play at half width, sound on, with a naive observer, and record whether the
   action was identified before it resolved. E1's melee telegraphs are the rehearsal; E5's colour
   telegraphs are what this protocol exists to judge, and the protocol must already exist and be
   trusted by then.
5. Confirm record/replay works end to end under split-screen: record a two-human round, replay it
   with `ReplayController` on both slots, and confirm the seed, both intent streams, and any
   balance-reload events reproduce it exactly. Then hot-reload a balance value mid-round and confirm
   the reload event is captured and re-applied at the same tick.

**Exit criterion.** Flags, step/pause, and the state inspector are usable mid-playtest behind the
debug flag; a split-screen round records and replays exactly, including a mid-round balance reload;
and the telegraph legibility protocol is written down and has been run once against E1's melee cues.

---

## Epic exit criteria (E2 complete when all hold)

1. Two humans fight melee in split-screen; spacing, attack weight, and deflect feel are evaluable
   human vs human.
2. The half-width viewport that E5's telegraphs must read in exists, and the legibility protocol has
   been exercised in it.
3. Every HUD element — including those E3–E6 will fill — occupies its real final space.
4. Hands are private by default; the opponent's hand renders face-down.
5. 60 FPS holds with both viewports; the number is recorded.
6. A recorded round replays to an identical state hash.

## Explicitly out of scope for E2

Cards, mana sources, unblockables, orbs, the Pitch Zone, minions, the bot. Bluffing is **not**
testable in E2 and that is accepted — early PvP exists to validate combat feel and to keep the build
playable with other people, both stated project goals.
