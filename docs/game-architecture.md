---
title: 'Game Architecture'
project: 'CardSouls'
date: '2026-07-21'
author: 'Matko'
version: '1.1'
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9]
status: 'complete'
amendments: ['A1 (2026-07-21): TimingWindow counts integer ticks', 'A2 (2026-07-21): D3 invariant widened to full state-layer determinism']
engine: 'Godot 4.6.3'
platform: 'Windows desktop (local split-screen, no networking)'

# Source Documents
gdd: 'docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/gdd.md'
epics: 'docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md'
brief: null
project_context: 'docs/project-context.md'
---

# Game Architecture — CardSouls

## Executive Summary

**CardSouls** is a 1v1 real-time hybrid — soulsborne melee **+** a Red/Blue/Green card economy —
built in **Godot 4.6.3** (GDScript, Forward+/D3D12, Jolt) for **Windows desktop, local split-screen,
no networking**. This architecture is a **decision spine for a validation demo**: full depth for
**E0–E3** (foundations, melee, split-screen PvP, cards+mana) with **named seams** for **E4–E6**
(minions/totems, unblockable RPS+orbs, pitch zone) — no speculative machinery, netcode deferred
indefinitely.

**Load-bearing decisions**
- **Deterministic single-tick state core** — one `MatchState.advance(intents)` call site with an
  enumerated sub-system order; the runner is the *only* `_physics_process` and drives movement
  explicitly (replay-safe phase); all gameplay-critical timing via a pure integer-tick
  `TimingWindow` (counts ticks, not accumulated float — A1).
- **Pure, headless-testable state layer** — `RefCounted` objects with no scene/`Input`/autoload deps;
  presentation subscribes to signals **queued during `advance()`, drained after**; state never reads a
  service (config injected).
- **Data-defined everything** — `.tres` schemas for cards, economy rules (`ResourceGenerationRule`,
  `CardCastCondition`), telegraphs, balance, feature flags; new content = a new `.tres`, no code.
- **Instrumentation is architecture** — feature-flag layer isolation, telegraph legibility
  (shape+sound, <0.5s), and deterministic InputIntent **record/replay** (seeded gameplay RNG + recorded
  balance-reload events).

**Organization:** role-layered (`state / systems / controllers / actors / ui / main`).
**Ready for:** E0 implementation, then epic/story breakdown.

---

## Document Status

**COMPLETE** — produced through the 9-step GDS Architecture Workflow.

**Steps Completed:** 9 of 9 (Initialize · Project Context · Engine · Architectural Decisions · Cross-cutting · Structure · Implementation Patterns · Validation · Completion)

This is a **decision spine**, not an implementation spec. It formalizes the invariants already
set in `docs/project-context.md` and resolves the technical choices the GDD raises but leaves open.

---

## Binding Constraints (set by Matko, Step 1)

These are non-negotiable and scope every decision below.

1. **Scope depth = E0–E3, seams for E4–E6.** Architect to sufficient depth for Foundations,
   Melee, Split-screen PvP, and Cards+Mana. For Minions/Totems (E4), Unblockable RPS+Orbs (E5),
   and Pitch Zone (E6): define **named extension points only** — no built machinery, no
   speculative abstractions for un-playtested systems. Named seams, not machinery.
2. **Netcode deferred indefinitely.** Drop any "network-ready" abstraction on sight — it is
   pure cost now. The state/visual separation is retained for *testability and legibility*,
   not as netcode scaffolding.
3. **Data-defined economy is its own concern.** `ResourceGenerationRule` and `CardCastCondition`
   are first-class `Resource` types covering mana generation and cast gating across the whole
   economy — not scoped to minion AI targeting.
4. **Fizzle timer = one shared deadline with one owner.** Distinct in kind from per-action
   timing windows (chargeup/defense/stun). One authoritative owner in the state layer so the
   logic cannot leak into three classes.
5. **Legibility is architectural.** The telegraph shape system and the audio bus are *structure*
   that must exist in E1/E2 (<0.5s recognition, shape+sound not hue, validated in a half-height
   split-screen viewport) — not UI polish retrofitted later.
6. **GUT not yet installed.** Flag which state-layer parts are testable *without* engine runtime,
   so test-framework setup does not block E0. **Carry-forward:** the "testable without engine
   runtime" boundary must be named concretely in the cross-cutting/testing step — not left as a
   risk note here.

---

## Project Context

### Game Overview
**CardSouls** — a 1v1 real-time hybrid fusing third-person soulsborne melee combat with a
real-time Red/Blue/Green card economy. Both layers are equally decisive (P1). Structured as
buildup → bluff → payoff over an always-on combat heartbeat.

### Technical Scope
**Platform:** Windows desktop only (Godot 4.6.3, Forward+/D3D12, Jolt, GDScript only)
**Genre:** Hybrid action-combat + real-time card economy
**Mode:** Local single-machine split-screen (PvP / vs-AI). No networking.
**Project Level:** High complexity, scoped to a validation demo (E0–E3 depth, E4–E6 seams).

### Core Systems (architected to depth vs. seamed)
| System | Epic | Depth |
|---|---|---|
| State layer / MatchState model | E0 | Full |
| Controller abstraction (kbd/gamepad/AI) | E0 | Full |
| Feature-flag system | E0 | Full |
| Data-defined economy (ResourceGenerationRule, CardCastCondition) | E0/E3 | Full |
| Deterministic timing core (_physics_process, fixed-delta) | E1 | Full |
| Legibility structure (telegraph-shape + audio bus) | E1/E2 | Full |
| Split-screen (2× SubViewport, shared state) | E2 | Full |
| Card system + 4-mode CardData + mana flywheel | E3 | Full |
| Fizzle shared-deadline owner | E6 | Seam in E0/E3 |
| Minion/totem AI · Unblockable RPS+orbs · Pitch Zone | E4–E6 | Named seams only |

### Technical Requirements
- 60 FPS sustained with two viewports, many autonomous minions, totem targeting, VFX.
- Combat determinism: timing-critical windows in `_physics_process`, fixed-delta, never `_process`.
- Object pooling + throttled targeting for the minion/totem layer (seamed).
- Signal-driven HUD; no per-frame economy recompute; state pushes via typed signals.
- All content/balance authored as `.tres`; zero hardcoded gameplay numbers.
- **Information-model integrity under split-screen (E2 HUD, required capability, not a later
  feature):** hands are private; the only public information is the card staged in the Pitch Zone.
  Because split-screen physically exposes both hands on one display — which would break the
  information model and make bluffing unobservable under full information during playtests — the
  E2 HUD layer **must be able to render the opponent's hand as face-down in each player's own
  viewport.** This is an instrumentation-driven structural requirement of the HUD, addressed in E2,
  not deferred.

### Complexity Drivers
- State/visual seam + controller abstraction (E0) — the invariants everything builds on.
- Four-modes-per-card resolution model — novel, no off-the-shelf pattern.
- Deterministic timing windows — the fairness core; solved structurally, verified headless.
- Legibility as structure (not polish) — telegraph-shape system + audio bus exist by E1/E2.

### Technical Risks
- Getting the E0 seams wrong forces a refactor (highest-impact risk).
- Telegraph legibility only truly judged in the E2 half-width viewport (validation gated on E2).
- GUT not yet installed — state-layer testability must be provable without engine runtime
  (boundary to be named concretely in the testing step).
- Netcode explicitly excluded; any "network-ready" abstraction is treated as a defect.

---

## Engine & Framework

### Selected Engine
**Godot 4.6.3 stable** — Forward+/D3D12 renderer, Jolt physics (3D), GDScript only.
(Confirmation only — pinned in project-context.md; not re-litigated in this workflow.)

**Rationale:** Local single-machine demo; GDScript learning goal; no networking; strong
`.tres`/Resource data-authoring fit; `SubViewport` split-screen; headless-testable via GUT.

### Engine-Provided Architecture
| Component | Solution | Notes |
|---|---|---|
| Rendering | Forward+ (D3D12) | Small flat arena; VFX/units dominate the budget |
| Physics | Jolt 3D | CharacterBody3D + move_and_slide; Area3D hit/overlap queries |
| Audio | AudioServer + bus layout | Legibility audio bus is architectural, defined in E1/E2 |
| Input | Input Map named actions | Backs controller abstraction; P1/P2 profiles; no raw keycodes |
| Scene mgmt | SceneTree / PackedScene / SubViewport | Two SubViewports = split-screen (E2) |
| Build | Windows export templates | Single target; no platform branches or fallbacks |

### Remaining Architectural Decisions (Steps 4–8)
State-layer / MatchState model · controller-abstraction interface · feature-flag structure ·
data-defined economy resources (ResourceGenerationRule, CardCastCondition) · deterministic
timing core · signal-vs-EventBus flow · legibility structure (telegraph-shape + audio bus) ·
split-screen state-sharing · pooling/targeting seams (E4) · fizzle shared-deadline owner (E6).

### Tooling (optional, non-architectural)
Godot MCP + Context7 recommended for AI-assisted development — add when convenient; not
required by this architecture.

---

## Architectural Decisions

Scope reminder: **full depth for E0–E3, named seams for E4–E6** (Binding Constraint #1).
Netcode is excluded (#2) — no decision below is justified by "network-readiness."

### Decision Summary

| # | Decision | Choice | Epic |
|---|----------|--------|------|
| D1 | State-layer object model | Composed plain `RefCounted` objects (MatchState → 2× PlayerState → pools/hand/hero) | E0 |
| D2 | Time-step ownership | Single ordered `MatchState.advance(intents)`; enumerated sub-system order | E0 |
| D3 | Controller abstraction | Per-tick `InputIntent` value object; `Input.*` confined to Controllers | E0 |
| D4 | Timing-window primitive | Pure state-layer timer/window type advanced by `tick(delta)` | E1 |
| D5 | Signal / event flow | State→presentation only; signals **queued during advance, drained after** | E0 |
| D6 | Data-defined economy | `ResourceGenerationRule` + `CardCastCondition` Resources + pure evaluator | E0/E3 |
| D7 | Legibility structure | Standalone `TelegraphProfile` Resource (any action, melee incl.) + `CombatCues` bus | E1/E2 |
| D8 | Fizzle shared-deadline owner | Sole owner `PitchState` in MatchState (seam in E0–E3, machinery E6) | E6 |
| D9 | E4–E6 seams | `TargetingService` + pool (E4); reserved `OrbPool` (E5); `PitchState` (E6) | E4–E6 |

**Quick confirmations:** Persistence = none (no meta-progression; only `FeatureFlags` + balance `.tres`).
Networking = excluded. Asset loading = preload `.tres` at startup + scene-based + pooling (no streaming).
UI = Godot `Control`, signal-driven, one HUD root per viewport. AI = a Controller implementation (E7),
not a subsystem; bluffing AI deferred.

---

### D1 — State-Layer Object Model

Composed plain objects, all `RefCounted` (no `Node`, no scene, fully headless):

```
MatchState
├── PlayerState (P1)
│   ├── HeroState          (HP, facing, action state)
│   ├── StaminaPool
│   ├── ManaPool
│   ├── OrbPool            (reserved; flag-off until E5)
│   └── Hand               (reserved; populated E3)
├── PlayerState (P2)  … same shape
└── PitchState             (reserved; sole fizzle-deadline owner, machinery E6 — see D8)
```

Each pool owns its value, its bounds, and its own typed signal surface. This gives every economy
resource a single owner and a testable unit, and lets a feature-flag degrade one pool without
touching others.

---

### D2 — Time-Step Ownership (Determinism Guarantee)

**One call site advances gameplay time:** `MatchState.advance(intents)`, invoked exactly once per
physics tick from a single `_physics_process`. **One physics tick = one `advance()` call**; tests
advance N fixed ticks and gameplay never reads wall-clock. This single ordered call *is* the
framerate-independence + headless-testability guarantee. (`advance()` takes **no `delta`** — see the
A1 follow-up note below.)

**Frame sequence (the Match Runner's `_physics_process`, per binding — sampling is OUTSIDE advance):**

```
_physics_process(delta):   # the ONLY _physics_process in the project — actors have none (F1)
  1. Sample every Controller   → InputIntent per player   # D3: ONLY Controllers touch Input.*
  2. Gather spatial facts       query state-active sensors/hitboxes → queue overlap/contact events
                                (reflect tick N-1's post-movement physics flush — F1)
  3. MatchState.advance(intents)                          # consumes facts + intents; enqueues signals
  4. Drive actor movement       each actor reads state velocity → move_and_slide() (F1)
  5. MatchState.drain_signals()                           # D5: flush queue AFTER advance returns
```

**Enumerated sub-system order INSIDE `advance(intents)`** (deterministic; player order P1→P2;
`[seam]` entries are reserved no-ops until their epic):

```
advance(intents):
  1. Ingest intents            apply each player's InputIntent → intended actions (P1 then P2)
  2. Advance timers            D4 windows: stamina/mana regen, chargeup, defense window, stun,
                               [fizzle deadline — E6 seam]
  3. Resolve actions           intended velocity + attack/block/roll transitions (physical
                               move_and_slide runs in the actor — see Spatial Model, F1)
  4. Resolve contacts          drain queued hitbox→contact events → apply damage/chip to HP
  5. Resource generation       evaluate ResourceGenerationRule (melee-hit mana, passive tick),
                               [orb grants — E5 seam], [accelerator totems — E4 seam]
  6. Card / economy resolution card play + draw, [pitch resolution — E6 seam]
  7. Board update              [minion throttled-tick + totems — E4 seam]
  8. Resolution check          HP ≤ 0 → death / round end
  # No signal emission here — steps 1–8 only ENQUEUE. Draining happens in the runner, step 3 above.
```

> **A1 follow-up — `advance()` takes no `delta` (decided 2026-07-21).** After A1 (all
> gameplay-critical timing is integer ticks) and F1 (position is actor-owned), the state layer has
> **no remaining consumer of wall-clock `delta`**: `TimingWindow.tick()` counts ticks, and per-tick
> resource generation (step 5) applies a **fixed per-tick amount** — a per-second balance value
> converted **once at load**, never `rate × delta`. `delta` therefore lives **only in the runner**,
> where `_drive_movement(delta)` feeds `move_and_slide()`. Threading `delta` into `advance()` "just in
> case" is prohibited — it would reintroduce the exact float-`delta` dependence A1 removed.
>
> **A1 follow-up — tick-rate invariant (runner-checked).** `TimingWindow.TICK_HZ` (`60.0`) must equal
> `project.godot` `physics/common/physics_ticks_per_second`, or every `seconds_to_ticks()` conversion
> is silently wrong. `match_runner` asserts this **once at startup** via `check_invariant()` (X1) —
> in the **runner, not state**, so INVARIANT D3(b) is not violated (state never reads `ProjectSettings`).

Contacts (step 2→4): the runner gathers `Area3D` overlaps for state-flagged-active hitboxes by
**direct query** (not async `area_entered` signals, whose firing order is not guaranteed) and pushes
**queued contact events**; hitboxes never apply damage. The queue is drained deterministically inside
`advance()` step 4. See §Implementation Patterns → *Spatial Model* for the fixed intra-tick order.

---

### D3 — Controller Abstraction (with enforceable invariant)

A `Controller` produces a pure-data `InputIntent` each tick (`move_dir`, pressed/held/released
actions, aim); the hero/state consumes it and never knows the source. Keyboard, gamepad, and
scripted AI all emit the **same** struct — dummy→PvP→bot is a config swap. Framed as AI-parity +
testability, **not** netcode (#2).

> **INVARIANT D3 (checkable, two parts) — widened by A2 to full state-layer determinism.**
>
> **(a) Input confinement.** No `Input.*` call — `Input.is_action_pressed`, `Input.get_vector`,
> `InputEvent` handling, etc. — appears anywhere outside a `Controller` implementation
> (`src/**/controllers/`). State (`src/state/`) and actor (`src/actors/`) code never touch the input
> singleton. **Check:** `grep -rn "Input\." src/ --include=*.gd` must return matches *only* under a
> controllers path. A hit elsewhere is an architectural defect.
>
> **(b) State purity — no nondeterministic source in `src/state/`.** The Input ban is one instance of
> a stronger rule: the state layer contains **no source of nondeterminism at all**. Forbidden in
> `src/state/`: the *global* RNG functions (`randf`, `randi`, `randf_range`, `randi_range`, `randfn`,
> `randomize`), and any `Time.*` (e.g. `Time.get_ticks_msec`), `OS.*`, or `Engine.*` frame/time query
> (`get_physics_frames`, `get_process_frames`, …). **The single seeded gameplay RNG owned by
> `MatchState` (F2) is the only permitted source of randomness** — sub-systems consume it as an
> injected instance (`_rng.randf()`, a method call, is fine; a bare `randf()` is not), and all
> gameplay-critical timing is integer ticks (A1), never a wall-clock read. **Check:** both greps below
> must return **zero** matches (the leading `(^|[^.[:alnum:]_])` excludes instance-method calls like
> `_rng.randf()`, matching only bare global calls):
> ```
> grep -rnE "(^|[^.[:alnum:]_])(randf|randi|randf_range|randi_range|randfn|randomize)[[:space:]]*\(" src/state/ --include=*.gd
> grep -rnE "(^|[^.[:alnum:]_])(Time|OS|Engine)\." src/state/ --include=*.gd
> ```
> The one `RandomNumberGenerator` constructed for the seeded gameplay RNG lives in `match_state.gd`;
> no other RNG is instantiated in `src/state/`. Any hit from either grep is an architectural defect.

---

### D4 — Timing-Window Primitive (Fairness Core)

A single pure state-layer timer/window value type (`RefCounted`) that **counts integer physics ticks**,
advanced one tick per call via `tick()`. No engine `Timer` / `SceneTreeTimer` nodes for
gameplay-critical timing (chargeup, defense window, stun, and later fizzle) — engine timers are
frame-coupled and untestable headless. All timing windows are one primitive, advanced in D2 step 2,
one tick at a time in tests. This same primitive backs the fizzle deadline (D8).

> **BINDING D4/A1 — count ticks, not accumulated float.** Replay determinism (F2/X5) rests on
> **seed + intents**. A float accumulator (`_elapsed += delta`) would silently make it *also* rest on
> `delta` being exactly `1/60` every tick, and float addition drifts across long windows regardless.
> The window therefore holds an **integer tick count**; seconds→ticks conversion happens **once, when a
> duration is loaded from balance `.tres`** (not per tick). Rules:
> - **Conversion uses `round()`** (not `floor`/`ceil`) and **clamps to a minimum of 1 tick for any
>   non-zero configured duration** — a window configured shorter than one tick must still *open*, never
>   become a window that never fires.
> - **X3 hot-reload re-converts on reload.** A window **already in flight** when a reload lands **keeps
>   its original duration**; the new value takes effect **the next time that window opens**. Do **not**
>   rescale remaining time proportionally — reload events are recorded in the intent stream (X3/X5), so
>   replay must reproduce what actually happened, not an interpolation.

---

### D5 — Signal / Event Flow (with timing discipline)

Direct typed signals on the owning state object; the HUD/presentation subscribes. `EventBus`
autoload is reserved for genuinely global, ownerless events only (`match_started`, `round_ended`).

> **BINDING D5 — signal timing & direction:**
> 1. **Queued, not mid-tick.** Signals raised during `advance()` are **enqueued**, then **drained
>    after `advance()` returns** (D2 runner step 3). A consumer can never observe half-advanced state.
> 2. **Presentation-only subscribers.** Signal subscribers are presentation-layer only (HUD, VFX,
>    audio, telegraph controller).
> 3. **No state-to-state signals.** No state object subscribes to another state object's signal.
>    State-to-state coupling goes exclusively through the **ordered dispatch in D2**, never through
>    signals.

---

### D6 — Data-Defined Economy (Binding Constraint #3)

Two first-class `Resource` base types, evaluated by a **pure evaluator in the state layer** (no
hardcoded per-source rule methods):

- **`ResourceGenerationRule`** (`source`, `resource`, `amount`, `trigger`) — drives *all* mana
  generation as data: passive tick, on-melee-hit, and the Mana Accelerator totem (E4 seam).
- **`CardCastCondition`** (`mana_cost`, per-color `orb_costs`, flags) — gates *every* cast and card
  mode.

E0 lands the **types + evaluator interface**; E3 authors the concrete `.tres`. Net: adding a mana
source or a cast rule is a new `.tres`, not a code change — economy-wide, not scoped to minion AI.

---

### D7 — Legibility Structure (Binding Constraint #5)

> **BINDING D7 — telegraph scope:** `TelegraphProfile` is a **standalone `Resource`**, referenced by
> **any telegraphing action — melee actions included** — not owned by `CardData`. It **exists in E1**
> so melee attacks carry telegraph structure from the start and the color-unblockable telegraphs in
> E5 reuse it rather than forcing a retrofit.

- **`TelegraphProfile`** fields: `shape_id`, `sting_id`, `color`, `pose_id`. **State owns *which*
  telegraph is active** (color + chargeup window); a presentation-side `TelegraphController` reads
  state and drives shape + sound. Hue is never the sole channel (colorblind-safe, <0.5s).
- **Audio:** a fixed bus layout with a dedicated **`CombatCues`** bus (per-color stings + outcome
  cues) separate from `Music` / `Ambience`, so functional cues are structurally un-maskable.
- Telegraph legibility is validated in the **E2 half-width split viewport**.

---

### D8 — Fizzle Shared-Deadline Owner (Binding Constraint #4)

A single `PitchState` object inside `MatchState` is the **sole owner** of the fizzle deadline (built
on the D4 primitive). Every system *queries* `PitchState`; none holds its own copy of fizzle time.

**In E0–E3 this is a named seam:** `MatchState` reserves the `PitchState` slot and the
deadline-owner contract now (D2 step 2 / step 6 reserve its tick + resolution slots); the machinery
lands in E6. This honors #4 (one owner, no leakage into three classes) without building E6 early (#1).

---

### D9 — E4–E6 Seams (named, no machinery)

- **Minions/totems (E4):** a `TargetingService` interface (throttled shared-tick provider) + an
  object-pool seam; `PlayerState` reserves a `units`/board collection. No AI built now.
- **RPS/orbs (E5):** `OrbPool` exists as a reserved, flag-off pool in `PlayerState`; resolution
  enters through the D2 command dispatch (steps 4–5). No RPS machinery now.
- **Pitch (E6):** the `PitchState` owner from D8. Reserved, not built.

---

## Cross-cutting Concerns

Patterns binding on ALL systems. (Event flow is specified in D5 and not restated here.)

### Error Handling

> **BINDING X1 — invariant checks must survive export.** Godot strips `assert()` in exported
> release builds, so a bare `assert()` gives exported playtest builds *no* invariant check at all —
> not a softer one. Invariants therefore route through an explicit `check_invariant(condition, msg)`
> helper built on a **normal runtime branch** (`if not condition:`), which survives export.

- `check_invariant(condition, msg)` behavior is mode-driven (mode from a config/build feature, not
  from `assert`):
  - **Dev mode** → fail fast (`push_error` + halt/breakpoint).
  - **Playtest build** → `Log.error(msg)` + continue.
- It guards the GDD's easy-to-break rules: all-color orb reset, hand ≤ 4, per-color orb cost never
  read off `CardData`.
- Recoverable/unexpected-but-handled → `push_warning`. **Feature-flag-OFF paths degrade, never
  error** (a disabled layer is a valid state).
- No player-facing error UI (dev-only demo). `assert()` may still be used for pure dev-time sanity,
  but **never** as the sole guard of a gameplay invariant that must hold in a playtest build.

### Logging

- Thin `Log` util, levels ERROR/WARN/INFO/DEBUG, tagged per system.
- HARD: no logging inside `advance()`'s steps or any per-frame hot path (allocation + determinism
  risk). Logging never reads/mutates state — it is a pure observer. Destination: console + optional
  file; plain tagged text.

### Configuration

- `FeatureFlags` `.tres` — loaded **once** at startup (the overload-isolation instrument).
- **Balance `.tres`** — every TBD-in-playtest number (hero stats, per-color unblockable damage, all
  timing windows, card/pitch costs, arena size). Zero hardcoded gameplay numbers.
- Godot **Input Map** (named actions) + `project.godot` (autoloads). No meaningful player settings
  in the demo.

> **BINDING X3 — runtime reload is a config-layer requirement, not a debug nicety.** Balance `.tres`
> must be **reloadable at runtime without restarting the match**. Tuning defense-window and chargeup
> values in the tens of milliseconds is the dominant activity for the coming months; a restart per
> iteration is a large hidden cost. The config layer exposes a reload that re-reads balance `.tres`
> and re-applies values to live state mid-match. (`FeatureFlags` is load-once by design; **balance
> values are hot-reloadable**.)

### Event System

- Per D5: owner-signals (state→presentation), drained after `advance()`. `EventBus` autoload carries
  a small fixed typed set only: `match_started`, `round_started`, `round_ended` (past-tense
  `snake_case`).

### Debug Tools (gated behind a `debug` flag)

1. **Runtime FeatureFlags toggle overlay** — live layer isolation (the GDD overload instrument).
2. **Per-player state inspector** — pools + active D4 timers + current telegraph; reads signals only.
3. **Deterministic step/pause** — pause the runner and advance N fixed ticks (timing-window debugging).
4. **Reveal-opponent-hand toggle** — debug counterpart to the E2 face-down-hand capability.
5. **InputIntent record & replay** — record the per-tick `InputIntent` stream **plus the gameplay RNG
   seed and any balance-reload events**; replay reproduces a round exactly from *seed + intents +
   recorded reload events* — **not** from the on-disk balance `.tres`. See §Implementation Patterns →
   *Determinism & Replay* for the rules (D2 + D3 make capture near-free). **Scope: record + replay only
   — no rewind, no scrubbing UI.** Rationale: the only actionable playtest report here is "I didn't see
   that happen," and diagnosing it requires replaying what actually happened tick by tick.

### Testing & Runtime Boundary (GUT not yet installed)

| Testable WITHOUT engine runtime (pure GDScript instantiation) | Needs engine runtime (scene / GUT integration) |
|---|---|
| All of `src/state/`: pools, `HeroState`, `MatchState.advance(delta)` with fixed δ, the D4 timer primitive, the D6 evaluators (`ResourceGenerationRule` / `CardCastCondition`), RPS **color-match** resolution & orb math, seeded gameplay RNG (draw/shuffle) | Actors (`CharacterBody3D` + `move_and_slide`), `Area3D` contact wiring, `SubViewport` split-screen, HUD `Control`, `CombatCues` bus, telegraph presentation, **spacing-dependent gameplay rules (Green thrust range, roll-to-close distance, dodge/leave-range) — F1** |

- **F1 — spacing-dependent rules are runtime, not headless.** Green thrust range, roll-to-close
  distance, and dodge/leave-range determination resolve from actor-reported spatial facts, so they sit
  on the runtime side above — a real reduction in headless coverage vs. an all-in-state model.
- **Dividing line = the D1/D5 state/visual seam.** State code needing a running tree to test is a
  *defect in the code, not the test* (project-context testing rule).
- **Bootstrapping before GUT:** run state tests as `godot --headless --script` — pure `RefCounted`
  objects instantiated + asserted directly. GUT is added when convenient (E0/E1), **not** a
  prerequisite for writing E0 state logic.

---

## Project Structure

Top-level layout and all naming conventions are inherited **verbatim** from `project-context.md`
(§Code Organization, §Naming Conventions). This section materializes the D-decisions and seams into
a concrete tree and adds **two** folders to the project-context list (both ratified): `src/controllers/`
and `src/main/`.

### Organization Pattern
Hybrid — layered by architectural role (state / systems / controllers / actors / ui), feature-grouped
*inside* each layer. Required by the state/visual seam and the D3 invariant; not a free stylistic choice.

### Directory Tree
(⚠️ = extends the project-context folder list — ratified. `(En)` = reserved seam for that epic.)

```
res://
├── project.godot                     # autoloads + Input Map (intentional, reviewed edits)
├── src/
│   ├── state/                        # PURE · headless · no scene/visual/Input deps — dependency SINK
│   │   ├── match_state.gd            # D2: advance(intents) ordered dispatch + drain_signals()
│   │   ├── player_state.gd           # D1: composes hero + pools + hand
│   │   ├── hero_state.gd
│   │   ├── pools/  stamina_pool.gd · mana_pool.gd · orb_pool.gd   # OrbPool reserved flag-off (E5)
│   │   ├── timing/ timing_window.gd  # D4 pure timer/window primitive (tick(delta))
│   │   ├── economy/ economy_evaluator.gd   # D6 pure evaluator
│   │   ├── input/  input_intent.gd   # D3 pure per-tick value object
│   │   ├── pitch/  pitch_state.gd     # D8 sole fizzle-deadline owner — reserved seam until E6
│   │   ├── enums.gd                  # CardColor {RED,BLUE,GREEN} + shared gameplay enums
│   │   └── resources/                # Resource SCHEMA classes (.gd) — pure data vocabulary
│   │       ├── card_data.gd · resource_generation_rule.gd · card_cast_condition.gd   # D6
│   │       ├── telegraph_profile.gd  # D7 standalone; used from E1 (melee incl.)
│   │       ├── balance_config.gd     # class_name BalanceConfig
│   │       ├── feature_flags.gd      # class_name FeatureFlags
│   │       └── minion_priority.gd (E4) · equipment_data.gd (E8)
│   ├── systems/                      # autoloads & cross-cutting — own instances, NO gameplay logic
│   │   ├── event_bus.gd              # D5 fixed set: match_started/round_started/round_ended
│   │   ├── feature_flags_service.gd  # autoload: loads FeatureFlags .tres ONCE; exposes flags
│   │   ├── balance_config_service.gd # autoload: loads BalanceConfig .tres; HOT-RELOAD (X3)
│   │   ├── card_database.gd          # autoload: loads all card .tres at startup
│   │   ├── intent_recorder.gd        # X5: captures InputIntent stream at the runner's sample step
│   │   ├── log.gd (X2) · invariant.gd (X1 check_invariant)
│   │   └── pool/ object_pool.gd      # pooling seam (E4)
│   ├── controllers/  ⚠️              # D3: the ONLY path where Input.* may appear
│   │   ├── controller.gd             # interface: sample() -> InputIntent
│   │   ├── keyboard_controller.gd (E0) · gamepad_controller.gd (E2)
│   │   ├── scripted_controller.gd    # E7 bot (gets an injected READ-ONLY state view) — reserved
│   │   └── replay_controller.gd      # X5: emits InputIntent from a recorded stream (indistinguishable
│   │                                 #     from hardware to the runner)
│   ├── actors/                       # scene-bound nodes (.tscn + .gd)
│   │   ├── hero/                      # CharacterBody3D + move_and_slide; Hitbox REPORTS contact
│   │   │   └── telegraph_controller.gd  # D7 presentation: reads state → shape+sound
│   │   ├── dummy/ (E1)
│   │   └── minions/ · totems/ · projectiles/   # reserved (E4/E5)
│   ├── ui/                           # HUD + menus (Control) — read-only state-signal consumers
│   │   ├── hud/                       # bars, 3 orb counters, hand (opponent face-down — E2 capability)
│   │   └── debug/                     # X5 toggles + overlays ONLY (no state mutation): flags · inspector
│   │                                 #     · step/pause · reveal-hand · record/replay start-stop-load
│   └── main/  ⚠️                     # root scene + Match Runner (the single _physics_process, D2)
│       └── match_runner.gd            # OWNS the MatchState instance; sample→advance→drain; wires refs
├── data/                             # authored .tres INSTANCES
│   ├── cards/ · minions/(E4) · equipment/(E8) · balance/ · telegraphs/   # telegraphs incl. melee (E1)
│   └── feature_flags.tres
├── assets/                           # art · audio (feeds CombatCues bus) · models · materials
├── test/                             # mirrors src/; test_*.gd + headless harness
│   ├── state/                         # PURE headless tests — no engine runtime (X6)
│   └── integration/                   # scene/actor tests — need runtime
└── addons/gut/                       # when installed (X6: not a prerequisite for E0)
```

### Schema vs Loader (class_name uniqueness)
Godot requires globally-unique `class_name`. Therefore:
- **`src/state/resources/`** holds **schema** types (`extends Resource`, authored as `.tres`):
  `FeatureFlags`, `BalanceConfig`, `CardData`, `ResourceGenerationRule`, `CardCastCondition`,
  `TelegraphProfile`, `MinionPriority`, `EquipmentData`.
- **`src/systems/`** holds **loaders/services** (`extends Node` autoloads), always `*Service`-suffixed:
  `FeatureFlagsService`, `BalanceConfigService`. (`CardDatabase` and `EventBus` need no suffix — no
  name-twin schema type.) A service loads its schema `.tres` and exposes it (`flags`, `config`).

### MatchState Ownership (no autoload for live state)
The **Match Runner** (`src/main/match_runner.gd`) creates and **owns** the single `MatchState`
instance, advances it (D2), and drains its signal queue (D5). References are wired **explicitly** at
match start:
- HUD / presentation ← **signal subscriptions** (or an injected read-only view); never a mutating handle.
- Scripted controller (E7) ← an injected **read-only state view**; it produces intents, never writes.

**No `MatchState` autoload.** A globally-exposed mutable state singleton would let arbitrary code
write state directly, bypassing the D2 ordered dispatch and D5 — the exact failure mode the seam
exists to prevent. Autoloads are reserved for **config / content / global events only**
(`FeatureFlagsService`, `BalanceConfigService`, `CardDatabase`, `EventBus`).

> ⚠️ **Refines `project-context.md`.** project-context currently prescribes a "thin `MatchState`
> autoload wrapper … exposes it globally." That predates D5 and creates the bypass risk above.
> project-context §Autoloads / §MatchState split should be updated to: *runner owns MatchState;
> autoloads never expose live mutable state.*

### Instrumentation wiring (X5 record/replay)
- **Record:** the runner's sample step feeds each tick's `InputIntent` to `IntentRecorder`
  (`src/systems/`), which also captures the gameplay RNG **seed** at start and any **balance-reload
  events** (tick + values applied). Recording is a passive tap — it never affects the tick.
- **Replay:** a `ReplayController` (`src/controllers/`) is swapped in for a hardware controller and
  emits the recorded `InputIntent` stream. The runner cannot tell the difference (D3). A round replays
  exactly from **seed + intent stream + recorded balance-reload events** (see §Implementation Patterns →
  *Determinism & Replay*) — not from the on-disk balance `.tres`. Scope: record + replay only — no
  rewind, no scrub UI.
- **UI:** only start/stop/load toggles live in `src/ui/debug/` (no state mutation there).

### Architectural Boundaries (enforceable dependency rules)

| Layer | May depend on | May NOT depend on | Enforces |
|---|---|---|---|
| `src/state/` | itself only | actors, ui, systems, controllers, `Input.*`, `Timer` nodes, `AnimationPlayer` | D1, D4, project-context HARD RULE |
| `src/controllers/` | `state/` (InputIntent, enums) | actors, ui | D3 — and is the **only** `Input.*` site |
| `src/actors/` | `state/`, `systems/` | ui | state/visual seam |
| `src/ui/` + `actors/**/telegraph_controller` | `state/` (read signals / read-only view) | mutating state | D5 (presentation subscribes; never writes) |
| `src/systems/` | `state/` | actors, ui | autoloads hold no gameplay logic |

Direction is always **visuals → state, never reverse**. Contacts flow: `Area3D` reports → queued →
drained in `advance()` step 4; hitboxes never apply damage.

### Naming Conventions
Per `project-context.md` §Naming Conventions verbatim. New types conform: `MatchState`, `PlayerState`,
`HeroState`, `InputIntent`, `TimingWindow`, `ResourceGenerationRule`, `CardCastCondition`,
`TelegraphProfile`, `PitchState`, `FeatureFlagsService`, `BalanceConfigService`, `ReplayController`,
`IntentRecorder`.

---

## Implementation Patterns

Concrete GDScript so agents implement the D-decisions identically. Full depth for E0–E3; E4–E6
branches are reserved seams (guarded by `check_invariant`/feature flag until their epic). All code is
Godot 4.6 GDScript, statically typed, per `project-context.md` conventions.

### Novel Pattern 1 — Tick + Signal-Queue (D2 + D5, the core loop)

A `SignalQueue` realizes D5's "enqueue during `advance()`, drain after." State objects push a bound
emit; nothing emits mid-tick, so no consumer can observe half-advanced state.

```gdscript
class_name SignalQueue extends RefCounted
var _pending: Array[Callable] = []
func push(emitter: Callable) -> void:
    _pending.append(emitter)
func drain() -> void:
    var batch := _pending
    _pending = []            # swap-out first: re-entrant safe
    for emit_call in batch:
        emit_call.call()
```

```gdscript
# src/main/match_runner.gd — the ONLY _physics_process in the project; actors have none (F1)
func _physics_process(delta: float) -> void:
    var intents: Array[InputIntent] = [_p1_controller.sample(), _p2_controller.sample()]  # D3, outside advance
    _gather_spatial_facts()                          # F1: query active sensors → queue overlap/contact facts
    _intent_recorder.capture(intents)                # X5 passive tap — never affects the tick
    _match_state.advance(intents)                    # consumes facts + intents; enqueues signals only
    _drive_movement(delta)                           # F1: actors move_and_slide here — delta lives ONLY here
    _match_state.drain_signals()                     # D5: emit AFTER advance returns
```

`MatchState.advance()` runs the enumerated D2 sub-system order (ingest → timers → actions → contacts
→ resource-gen → card/economy → board[E4 seam] → resolution-check); `drain_signals()` calls
`_queue.drain()`.

### Novel Pattern 2 — Pool + Queued Signal + Config Injection (D1, D5, boundary rule)

Load-bearing consistency rule: **state never reads an autoload.** Balance flows *in* by injection.
State may reference the `BalanceConfig` *schema* (it lives in `state/resources/`) but never
`BalanceConfigService` (a `systems/` autoload).

```gdscript
class_name ManaPool extends RefCounted
signal mana_changed(current: float, maximum: float)
var _current: float = 0.0
var _maximum: float
var _queue: SignalQueue
func _init(queue: SignalQueue, maximum: float) -> void:
    _queue = queue
    _maximum = maximum
func add(amount: float) -> void:
    var v := clampf(_current + amount, 0.0, _maximum)
    if is_equal_approx(v, _current):
        return
    _current = v
    _queue.push(mana_changed.emit.bind(_current, _maximum))   # queued, not emitted
func get_current() -> float:
    return _current
func set_maximum(maximum: float) -> void:                     # X3 hot-reload re-injection
    _maximum = maximum
    add(0.0)   # re-clamp + re-signal if bounds shrank
```

Hot-reload (X3), no restart: `BalanceConfigService` reloads the `.tres` → calls
`match_state.apply_balance(config)` → pools update bounds in place via `set_maximum` etc.

### Novel Pattern 3 — Controller / InputIntent (D3)

```gdscript
class_name InputIntent extends RefCounted        # pure per-tick value object
var move_dir := Vector2.ZERO
var pressed: Dictionary = {}      # StringName action -> bool, this tick
var held: Dictionary = {}
var aim := Vector2.ZERO

class_name Controller extends RefCounted          # interface
func sample() -> InputIntent:
    return InputIntent.new()                       # override per implementation
```

- `KeyboardController` / `GamepadController` are the **only** places `Input.*` may appear (D3 INVARIANT —
  grep-checkable under `src/controllers/`).
- `ReplayController` overrides `sample()` to return recorded intents; the runner cannot distinguish it
  from hardware (X5).
- `ScriptedController` (E7) receives an injected **read-only state view** at construction to make
  decisions — it never mutates state.

### Novel Pattern 4 — TimingWindow (D4, the fairness core)

```gdscript
class_name TimingWindow extends RefCounted
# A1: counts integer physics ticks, never accumulated float. Replay determinism (F2/X5) must not
# depend on delta being exactly 1/60, nor drift via float addition over long windows.
const TICK_HZ := 60.0

var _duration_ticks := 0
var _elapsed_ticks := 0
var is_running := false

# Convert a configured seconds duration to a tick count. Done ONCE at balance load / X3 reload,
# never per tick. round() (not floor/ceil); any non-zero duration clamps to >= 1 tick so a
# sub-tick window still opens rather than never firing.
static func seconds_to_ticks(seconds: float) -> int:
    if seconds <= 0.0:
        return 0
    return maxi(1, int(round(seconds * TICK_HZ)))

func start(duration_ticks: int) -> void:   # snapshots duration; an in-flight window keeps it across reload
    _duration_ticks = duration_ticks
    _elapsed_ticks = 0
    is_running = duration_ticks > 0

func tick() -> void:                        # one physics tick; magnitude-free by design
    if not is_running:
        return
    _elapsed_ticks += 1
    if _elapsed_ticks >= _duration_ticks:
        is_running = false

func remaining_ticks() -> int:
    return maxi(0, _duration_ticks - _elapsed_ticks)
```

Every chargeup / defense-window / stun / fizzle is *this one type*, advanced in `advance()` step 2,
**one tick per call** in tests. `start()` takes a tick count (pre-converted from balance via
`seconds_to_ticks`), so a window **already running keeps its original duration** when balance
hot-reloads — the new value is picked up only at the next `start()` (D4/A1). No engine `Timer` /
`SceneTreeTimer` nodes for gameplay-critical timing.

### Novel Pattern 5 — Data-Defined Economy Evaluator (D6)

```gdscript
class_name ResourceGenerationRule extends Resource
@export var source: StringName        # &"melee_hit" | &"passive_tick" | &"mana_accelerator" (E4)
@export var resource: StringName      # &"mana"
@export var amount: float

class_name EconomyEvaluator extends RefCounted    # PURE — the only place gen rules are applied
static func apply(rules: Array[ResourceGenerationRule], src: StringName,
                  player: PlayerState) -> void:
    for r in rules:
        if r.source == src and r.resource == &"mana":
            player.mana.add(r.amount)
```

`CardCastCondition` gates every cast/mode the same data-driven way (mana cost + per-color orb costs +
flags), evaluated against `PlayerState`. Adding a mana source or cast rule = a new `.tres`, no code.

### Novel Pattern 6 — Four-Mode Card Resolution (the gameplay novelty)

One `CardData` is summon **and** attack **and** defense **and** pitch. Modes ②/③ derive from `color`
(no per-card data); ①/④ carry effects.

```gdscript
class_name CardData extends Resource
@export var color: CardColor                 # drives Mode ②/③ unblockable identity
@export var basic_effect: CardEffect         # Mode ① (E3)
@export var pitch_effect: CardEffect         # Mode ④ (E6, reserved)
@export var cast_condition: CardCastCondition
```

```gdscript
enum ModeKind { BASIC, UNBLOCKABLE_INIT, UNBLOCKABLE_DEFENSE, PITCH }
func resolve(player: PlayerState, card: CardData, mode: ModeKind) -> void:
    match mode:
        ModeKind.BASIC:               _resolve_basic(player, card)               # E3
        ModeKind.UNBLOCKABLE_INIT:    _resolve_unblockable_init(player, card)    # E5 seam
        ModeKind.UNBLOCKABLE_DEFENSE: _resolve_unblockable_defense(player, card)  # E5 seam
        ModeKind.PITCH:               _resolve_pitch(player, card)               # E6 seam
```

E5/E6 branches are reserved stubs guarded by `check_invariant`/feature flag until their epic.
(`CardEffect` is a reserved effect-schema `Resource` in `state/resources/` — `basic_effect` authored
in E3, `pitch_effect` in E6.)

### Hero Action-State Representation (DECIDED: pure enum + transition table)

```gdscript
# In HeroState (src/state/hero_state.gd)
enum ActionState { IDLE, ATTACKING, BLOCKING, ROLLING, STUNNED, CHARGING }
var action_state: ActionState = ActionState.IDLE
# Transitions computed in advance() step 3 from InputIntent + TimingWindows. Fully headless-testable.
```

Chosen over the Node-based `StateMachine` from the Godot knowledge fragment, which is scene-coupled
and `_process`-driven — it **cannot** be tested headless and would violate D1 and X6. Souls action
states are few and timing-gated, so a pure enum in the state layer keeps them in the deterministic
tick and under headless test.

### Standard Patterns & Consistency Rules

| Concern | Rule |
|---|---|
| Communication | State→presentation via **signals** (drained post-`advance()`); the runner **injects** refs at match start; **no** service locator for state |
| Entity creation | `PackedScene.instantiate()` + `ObjectPool` for hot spawns (E4 seam); never instantiate/`queue_free` per shot in a hot path |
| Entity state | Pure enum + transitions **in the state layer**; never a scene `StateMachine` for gameplay state |
| Data access | Content/config via autoload **services**; **state receives schema `Resource`s by injection, never reads a `*Service`** |
| Invariants | `check_invariant()` (X1), never bare `assert()` as the sole guard of a playtest-critical rule |
| Timing | All gameplay-critical timing via `TimingWindow` advanced by fixed δ; never engine `Timer` nodes |
| Signals | Owner emits via `SignalQueue.push`; subscribers are presentation-only; no state-to-state signals (D5) |

### Spatial Model & the `_physics_process` boundary (validation F1)

- **One `_physics_process`, explicit order (option a).** `match_runner` is the **only**
  `_physics_process` in the project — **actors do not run their own.** The runner drives every tick in
  a fixed intra-tick order: `sample controllers → gather spatial facts → advance() → drive actor
  movement (move_and_slide) → drain signals`. Ordering is explicit code, matching D2's single-call-site
  philosophy; it never depends on scene-tree position, so a scene reorganization cannot shift the
  movement↔state phase by a tick.
- **Position is actor-owned; the state layer is non-spatial.** Transforms live on actors (Jolt /
  `move_and_slide`, driven by the runner). `MatchState` holds no world coordinates.
- **Fixed direction — actors REPORT, state DECIDES.** The runner queries each state-active
  sensor/hitbox and pushes spatial *facts* (overlaps, distances, contacts) into the queue consumed by
  `advance()` step 4. An actor **never** evaluates a gameplay rule ("is this in thrust range?", "did
  the dodge leave range?") and applies a result — it exposes the fact, and `advance()` decides.
- **Documented phase (replay-safe).** Godot's physics server resolves collisions/overlaps *after*
  `_physics_process` returns, so facts gathered at the top of tick N reflect the flush produced by tick
  N−1's movement — a **constant one-tick relationship, identical on every run.** State logic treats
  reported facts as "positions as of the last movement," never "live this instant." Because the
  relationship is fixed (not scene-order-dependent), it is deterministic and replay-safe — closing the
  same class of silent nondeterminism as the F2 RNG hole.
- **Coverage consequence (honest):** spacing-dependent rules (Green thrust range, roll-to-close
  distance, dodge/leave-range) resolve from runner-gathered facts and are therefore **integration-
  tested, not headless** — recorded in the X6 boundary table. Non-spatial logic (economy, timing, RPS
  color-match, orbs) stays fully headless.

### Determinism & Replay (validation F2 + X3/X5 reconciliation)

Replay (X5) is sound only if *every* non-input source of variation is captured. Three rules:

- **Seeded RNG, owned by `MatchState`, advanced only in `advance()` (F2a).** The match runs a single
  seeded **gameplay** RNG owned by `MatchState`, consumed **only** inside the ordered dispatch (e.g.
  deck shuffle/draw in step 6). Any draw from outside `advance()` breaks replay. The **seed is
  recorded** with the intent stream.
- **Separate gameplay vs cosmetic RNG streams (F2b).** VFX variation, audio pitch jitter, and
  animation selection use a **separate cosmetic RNG** and must **never** consume from the gameplay
  stream — otherwise a presentation-only change would silently desync replays.
- **Balance hot-reload is recorded, not ignored (X3/X5 reconciliation).** Because balance `.tres` is
  hot-reloadable mid-match (X3), a recording no longer corresponds to a single balance state.
  `IntentRecorder` therefore records each **balance-reload event in the stream** (tick index + values
  applied); `ReplayController` re-applies them at the **same tick**. Replay reproduces from **seed +
  intent stream + recorded reload events** — the on-disk balance `.tres` is not trusted for strict
  replay. With reload events captured, the X3 path can no longer produce an unreplayable recording.

**Snapshot contract (decided E0 item 3, for the item-4 determinism hash).** Every *persistent* state
class exposes `to_snapshot() -> Dictionary` — keys → plain values (int / float / bool / String, enums
as int, `Vector*`), nested state objects recurse via their own `to_snapshot()`. The determinism test
hashes a **canonical serialization with sorted keys** over `MatchState.to_snapshot()` (never
insertion-order `Dictionary` iteration). `MatchState`'s snapshot includes the **gameplay RNG state**
(`RandomNumberGenerator.state`) so the hash catches RNG desync. **Excluded from the contract:**
`InputIntent` (it is *input*, captured separately in the X5 stream) and `SignalQueue` (transient
plumbing) — the exclusion is deliberate. A state class that is awkward to snapshot is usually holding
something it shouldn't (a node ref, a service handle) — treat that as a design smell, not a
serialization problem.

**InputIntent lifetime (decided E0 item 3).** A `Controller` returns a **fresh `InputIntent` instance
per `sample()`** — an immutable-per-tick value object. It is never a reused mutable instance, so the
X5 recorder (which retains a reference each tick) can never end up holding N aliases of one
ever-changing object (a bug invisible until the first replay). Correctness is structural, not
dependent on the recorder copying on capture.

---

## Architecture Validation

Validated against `checklist.md`, the GDD systems, the E0–E8 epics, and the two scope guards
(no E4–E6 machinery; no network-ready abstraction). Date: 2026-07-21.

| Check | Result | Notes |
|---|---|---|
| No E4–E6 machinery (scope) | PASS | Only named seams — OrbPool flag-off, PitchState reserved, TargetingService named, `resolve()` E5/E6 stubs |
| No network-ready abstraction | PASS | Netcode excluded; state/visual seam framed as testability/legibility, not netcode |
| Decision compatibility (D1–D9, X1–X6) | PASS | Cohere; no conflicting guidance |
| GDD system coverage | PASS | Every GDD system maps to a decision, pattern, or named seam |
| Epic mapping E0–E8 | PASS | Each epic has a home + patterns; seams sit at their epic |
| Document completeness | PASS | No stray TBD/TODO; balance "TBD-in-playtest" is intentional data-driven content |
| Generic web/DB/auth/API/scale checks | N/A | Local single-machine game demo |

**Issues found and resolved this step:**
- **F1 — spatial model + `_physics_process` ordering.** Chose **option (a)**: the runner is the
  **only** `_physics_process` (actors have none) and drives movement explicitly at a fixed point
  relative to `advance()`, so the movement↔state phase is deterministic (not scene-tree-order-
  dependent). Position is actor-owned; actors report spatial facts and `advance()` decides; the fixed
  one-tick fact→advance relationship is documented; spacing rules are integration-tested per the X6
  boundary.
- **F2 — replay RNG hole.** Single seeded gameplay RNG owned by `MatchState`, advanced only in
  `advance()`, seed recorded; separate cosmetic RNG stream.
- **X3/X5 conflict — hot-reload vs replay.** `IntentRecorder` records balance-reload events in the
  stream; `ReplayController` re-applies them at the same tick.

**Quality:** Completeness — Complete (E0–E3 depth + E4–E6 seams). Version specificity — engine pinned
(Godot 4.6.3). Pattern clarity — Clear (concrete GDScript, enforceable invariants). AI-agent readiness
— Ready for E0–E3.

**Deliberately not overstated:** headless coverage excludes spacing-dependent gameplay
(integration-tested); strict replay requires captured seed + reload events, not the on-disk balance
`.tres`.

### Post-Completion Amendments

Changes made after the 9-step workflow closed. Each is compatible with the validated decision set and
strengthens an existing determinism guarantee rather than adding scope.

- **A1 (v1.1, 2026-07-21) — `TimingWindow` counts integer ticks, not accumulated float.** Closes a
  latent replay-determinism hole in D4: a float `_elapsed += delta` accumulator makes replay depend on
  `delta` being exactly `1/60` and drifts via float addition. The primitive now holds an integer tick
  count; seconds→ticks conversion happens once at balance load / X3 reload using `round()` with a
  `>= 1`-tick clamp for any non-zero duration; an in-flight window keeps its original duration across a
  hot-reload (no proportional rescale) so replay reproduces recorded reload events exactly. See D4 /
  §Implementation Patterns → *Novel Pattern 4*.
- **A2 (v1.1, 2026-07-21) — D3 invariant widened to full state-layer determinism.** The Input-`*`
  confinement rule is generalized: `src/state/` may contain **no** nondeterministic source — no global
  `randf`/`randi`/`randf_range`/`randi_range`/`randfn`/`randomize`, no `Time.*`/`OS.*`/`Engine.*`
  frame-or-time query — the single seeded gameplay RNG owned by `MatchState` (F2) being the only
  permitted randomness. Rewritten as two grep-checkable parts; see D3 INVARIANT (a)/(b).
- **A1 follow-ups (v1.1, 2026-07-21), both resolved before E0 item 3.**
  - **`advance()` signature drops `delta` → `advance(intents)`.** A1 (tick-based timing) + F1
    (actor-owned position) leave no deterministic `delta` consumer in state; per-tick regen is a fixed
    per-tick amount converted once at load. `delta` now lives only in the runner's `_drive_movement`.
    Applied across D2, Novel Pattern 1, the structure tree, and First Steps item 3.
  - **Tick-rate invariant is runner-checked.** `TimingWindow.TICK_HZ` must equal
    `physics/common/physics_ticks_per_second`; `match_runner` asserts it once at startup via
    `check_invariant()` (runner, not state — D3(b) intact). `project.godot` now sets the value explicitly.
- **Checklist (First Steps item 4) — determinism regression test added.** E0 test harness gains a test
  that runs N ticks from a fixed seed + fixed intent list and asserts a hash of the resulting state
  against a golden value. The hash is taken over a **canonical serialization with sorted keys** —
  iterating a `Dictionary` in insertion order yields a hash that is stable in practice but breaks
  silently when insertion order changes. This test is the executable guard for A1, A2, and F2.

---

## Development Environment

### Prerequisites
- **Godot 4.6.3 stable** (Forward+ / D3D12; Jolt physics) — **GDScript only**, no C#/Mono.
- **Windows desktop.** LF line endings + UTF-8 enforced (`.gitattributes` / `.editorconfig`).
- **Git** — never commit `.godot/`, `/export/`, `export_presets.cfg`, `.claude/settings.local.json`.
- **GUT** (Godot Unit Test) under `res://addons/gut/` — add when convenient (E0/E1); **not a
  prerequisite for E0 state logic** (state tests bootstrap via `godot --headless --script`, per X6).

### AI Tooling (MCP Servers)
None selected during this workflow. Optional, addable later: **GoPeak** (`npx -y gopeak`) for
scene/GDScript inspection and edit→run→inspect loops, and **Context7** for current Godot docs.
Verify a repo is still maintained before adopting (the MCP ecosystem moves fast).

### First Steps (E0 — Foundations)
1. Create the role-layered `src/` tree + `data/`, `assets/`, `test/` per §Project Structure.
2. Register autoloads in `project.godot`: `EventBus`, `FeatureFlagsService`, `BalanceConfigService`,
   `CardDatabase`; define named Input Map actions (P1/P2). **No `MatchState` autoload** — the runner
   owns it.
3. Implement the state core: `SignalQueue`, `MatchState.advance(intents)` + `drain_signals()`,
   `PlayerState` / `HeroState` / pools, `TimingWindow`, `InputIntent`, `KeyboardController`.
4. Stand up the headless test harness (`godot --headless --script`) + first `HeroState`/pool tests and
   the `.tres` smoke test. **Include a determinism regression test:** run N ticks from a fixed seed +
   fixed intent list and assert a hash of the resulting state against a golden value. Hash over a
   **canonical serialization with sorted keys** (never insertion-order `Dictionary` iteration, which is
   stable in practice but breaks silently when insertion order changes). This is the executable guard
   for A1, A2, and F2.
5. Wire `match_runner` (`src/main/`): sample → gather facts → `advance` → drive movement → drain. Exit
   criteria: hero moves via the keyboard controller; headless state tests green; `FeatureFlagsService`
   loads a `.tres`.

---

## Resume Point

**For the next session — assume no memory of the conversation that produced this document. Everything
needed to continue the `gds-game-architecture` workflow is in THIS file.**

### Workflow state
- Skill: `gds-game-architecture` (BMad/GDS micro-file workflow; steps in
  `.claude/skills/gds-game-architecture/steps/step-0N-*.md`).
- **Completed: ALL 9 steps — workflow COMPLETE** (frontmatter `stepsCompleted: [1..9]`,
  `status: complete`). This section is retained as an orientation map; no workflow step remains.
- **Next workflow (not this one):** `gds-create-epics-and-stories` (`epics.md` already exists) → E0
  implementation. See §Development Environment → First Steps.

### Facilitation contract (how the user, Matko, works — observed this run)
- Wants each choice as **prose + a clear recommendation**; he replies "**Option N** + a binding
  constraint," then expects the constraint recorded as a named rule. Do NOT dump option matrices via
  the question tool; present recommendations and let him steer.
- He catches divergences (naming collisions, engine-behavior gaps, boundary violations) — be precise;
  verify engine claims; never promise behavior the engine won't deliver.
- Config: `_bmad/gds/config.yaml` → user_name `Matko`, language English, output_folder `{project-root}/docs`.

### Canonical inputs (sources of truth)
- **GDD:** `docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/gdd.md` (+ `epics.md`, `decision-log.md`).
- **Implementation source of truth:** `docs/project-context.md` (47 rules; two HARD RULES:
  state/visual separation, feature-flag isolation).
- **Mechanics canon (engine-obsolete):** `docs/tdd-legacy-ue5.md`.

### Binding constraints & decisions already locked (do not re-litigate)
- The six **Binding Constraints** (top of this doc) + bindings **D2/D3/D5/D7** and **X1/X3/X5**.
- **Scope:** full depth E0–E3, **named seams only** for E4–E6; no speculative abstraction.
- **Netcode deferred indefinitely** — drop any "network-ready" abstraction as a defect.
- Decisions **D1–D9**, cross-cutting **X1–X6**, the project structure, and implementation patterns
  above are settled. **Validation (Step 8) applied fixes F1 (spatial model / `_physics_process`
  boundary), F2 (seeded gameplay RNG + separate cosmetic stream), and the X3/X5 replay reconciliation
  (balance-reload events recorded in the stream)** — see §Architecture Validation.

### Open items carried forward
1. **`project-context.md` §Autoloads refinement — DONE (applied 2026-07-21).** project-context
   §Autoloads, its MatchState paragraph, the `src/systems/` line, and the FeatureFlags schema/loader
   rename (line 65 → `FeatureFlagsService`; line 122 keeps the injected `FeatureFlags` resource per
   Pattern 2) now match this architecture. No further action.
2. **Workflow COMPLETE — no remaining steps.** Next is `gds-create-epics-and-stories`, then E0.

### Nothing else is being held only in context
All bindings, decisions, code patterns, validation fixes (F1 / F2 / X3-X5 reconciliation), the GUT
"testable-without-engine-runtime" boundary (X6), and the E2 face-down-hand capability are written
above. No un-applied actions remain; the workflow is complete.
