---
project_name: 'CardSouls'
user_name: 'Matko'
date: '2026-07-20'
sections_completed: ['technology_stack', 'engine_specific', 'performance', 'code_organization', 'testing', 'platform_build', 'critical_gotchas']
status: 'complete'
rule_count: 73
optimized_for_llm: true
aligned_with: 'game-architecture.md v1.1 (F1, D3/A2, A1, D5, advance-no-delta); folders + testing updated to observed E0 code (2026-07-21)'
---

# Project Context for AI Agents

_This file contains critical rules and patterns that AI agents must follow when implementing game code in this project. Focus on unobvious details that agents might otherwise miss._

---

## Technology Stack & Versions

- **Engine:** Godot **4.6.3 stable** — Forward+ renderer, Jolt Physics (3D), D3D12 driver on Windows.
- **Language:** **GDScript only.** This is NOT a C# / Mono project — there is no `.csproj`/`.sln`. Do not introduce C# scripts or `[Export]` C# attributes.
- **Scope:** Local single-machine demo. **No networking** — do not add `MultiplayerAPI`, RPCs, `@rpc`, or `ENetMultiplayerPeer`. (The legacy TDD's P2P/server-authoritative sections are obsolete.)
- **Design source of truth:** `docs/tdd-legacy-ue5.md` — a v0.3 TDD flagged **LEGACY REFERENCE**. It was written for UE5/C++/online. Treat its **mechanics as canon**; ignore all engine- and networking-specific implementation detail.
- **Repo hygiene:** LF line endings enforced (`.gitattributes`), UTF-8 (`.editorconfig`). `.godot/`, `/export/`, and `export_presets.cfg` are git-ignored — never commit them.
- **API baseline:** Assume the Godot 4.4+/4.6 API (typed dictionaries, `@export_tool_button`, `Node.get_tree()` etc.). Do NOT use Godot 3.x idioms (`export var`, `yield`, `KinematicBody`, `.instance()`).

## Critical Implementation Rules

### Engine-Specific Rules (Godot 4.6 / GDScript)

**Typing & style**
- Use **static typing everywhere**: `var hp: int = 0`, `func take_damage(amount: float) -> void:`. Prefer `:=` inferred typing only when the type is obvious.
- Always `class_name` reusable types. Prefer explicit node types over `Node`.
- Access exported node refs via `@onready var x: Type = $Path` or `@export` NodePaths — never `get_node()` in `_process`.

**Node lifecycle**
- `_ready()` runs once when the node AND its children are in the tree — do child wiring here, not in `_init()`.
- `_enter_tree()` fires before children are ready — do NOT touch `$Child` here.
- **Single `_physics_process` (INVARIANT F1):** the **Match Runner** (`src/main/match_runner.gd`) is the **only** `_physics_process` in the project. It drives every tick in a fixed order: sample controllers → gather spatial facts → `MatchState.advance(intents)` → drive actor `move_and_slide()` → drain signals. **Actors do NOT define their own `_physics_process`** — the runner drives them, and they read state (e.g. `HeroState.velocity`), never input. UI/HUD updates go in `_process` or, better, are signal-driven. Check: `grep -rn "func _physics_process" src/` returns exactly one hit, in `match_runner.gd`.
- Use `CharacterBody3D` + `move_and_slide()` for the hero (Godot 4 API). Jolt is the physics backend — do not assume Godot's default physics quirks.

**Signals over polling**
- Combat/economy state changes (HP, stamina, mana, orbs, card played, pitch staged) MUST emit **signals**; the HUD subscribes. Do not have the HUD poll hero state every frame.
- Declare typed signals: `signal hp_changed(current: float, max: float)`.
- **Direct subscription is the default:** consumers (HUD, etc.) subscribe directly to the **owning state object's** typed signals. `EventBus` is reserved for genuinely global, cross-system events with no clear owner (e.g. match started, round ended). Do NOT route per-entity state changes (hp, stamina, mana, orbs) through `EventBus`.
- **Queued signals (D5):** signals raised during `MatchState.advance()` are **enqueued** (a bound emit pushed onto the shared `SignalQueue`), then **drained by the runner AFTER `advance()` returns** — never emitted mid-tick, so no consumer observes half-advanced state. **No state object subscribes to another state object's signal** — state-to-state coupling goes only through the ordered `advance()` dispatch.

**Autoloads (singletons)**
- Global systems are Godot **autoloads** registered in `project.godot`. Autoloads are for **config, content, and global events only**: `FeatureFlagsService`, `BalanceConfigService`, `CardDatabase`, `EventBus`. Keep them minimal — no gameplay logic inside autoloads, and **never expose live mutable game state through an autoload**.
- **MatchState ownership:** the match logic lives in `src/state/` as a plain, testable object (`MatchState`) with **no scene dependency**. The **Match Runner** (`src/main/match_runner.gd`) creates and **owns** the single `MatchState` instance and wires references explicitly at match start — presentation/HUD receive read-only signal subscriptions or a read-only view, never a mutating handle. There is **no `MatchState` autoload**: a global mutable state singleton would let arbitrary code bypass the ordered state dispatch and the queued-signal discipline. Never put match logic in an autoload.
- **CONSTRAINT C:** `apply_balance()` swaps the whole `BalanceTicks`/`BalanceConfig` object on every reload — never cache a reference to it; read `ms.balance_ticks`/`ms.balance` inline at the point of use (decision-log:135).
- **Per-pool reload contract** (Matko's design call, `3-1/R2`): on `apply_balance()`, stamina gets `set_maximum` + full `refill`; mana gets `set_maximum` only, **never refilled**; hp is preserved and clamped, never re-healed mid-match.

**Controllers & state-layer determinism (D3 / A2 — INVARIANT)**
- **`Input.*` is read ONLY in `src/controllers/`.** A `Controller` samples input and returns a pure-data `InputIntent` (a **fresh instance each tick**); state and actors consume the intent and never touch the `Input` singleton. Check: `grep -rn "Input\." src/` matches only under `src/controllers/`.
- **`src/state/` contains NO nondeterministic source.** No global `randf()`/`randi()`/`randomize()`, no `Time.*`, no `OS.*`, no `Engine.*` frame/time query. The **single seeded gameplay RNG owned by `MatchState`** is the only randomness (consumed only inside `advance()`); cosmetic/VFX RNG is a separate stream. This is what makes the state layer deterministic and replay-safe.
- **`MatchState.advance(intents)` takes NO `delta`.** After integer-tick timing (below) and actor-owned position, the state layer has no wall-clock consumer; `delta` lives only in the runner (for `move_and_slide`). Never thread `delta` into `advance()` "just in case".

**Deterministic timing (A1 — INVARIANT)**
- **Gameplay-critical timing counts integer ticks, not float.** Chargeup / defense-window / stun / fizzle use the `TimingWindow` primitive (`src/state/timing/`), advanced **one tick per `advance()` call** — never a float `_elapsed += delta` accumulator, and never an engine `Timer`/`SceneTreeTimer` node (frame-coupled, untestable headless, delta-dependent). Seconds→ticks is converted **once at balance load**: `round()`, clamped to a minimum of 1 tick for any non-zero duration. `TimingWindow.TICK_HZ` must equal `physics/common/physics_ticks_per_second` (the runner `check_invariant`s this at startup).

**Data as Resources**
- Cards, minion AI priority types, equipment passives, orb costs, and balance values are **`Resource` subclasses saved as `.tres`** — NOT hardcoded (the TDD states this repeatedly). Define e.g. `CardData extends Resource` with `@export` fields; author instances as `.tres` assets.
- New card / minion-priority / equipment content should be addable by creating a `.tres`, with zero code changes wherever the TDD says "data-defined."

**Instancing & freeing**
- Instance scenes with `PackedScene.instantiate()`; free with `queue_free()` (never `free()` on nodes in the tree). Guard against use-after-free with `is_instance_valid()`.

**HARD RULE — State / visual separation**
- All gameplay flows **input → state change → visual reaction**, in that order.
- Animations, `AnimationPlayer` callbacks, UI nodes, and VFX **never decide game state**. Damage, stamina, mana, orbs, and card resolution are computed in the **state layer**; visuals and HUD only read from it and react to its signals.
- Hitboxes **report contact** (emit a signal / push a contact event) — they do **not** apply damage. The state layer decides what a contact means.
- Rationale: keeps future netcode a layer to *add* rather than a rewrite, and keeps gameplay testable without a scene.

**Collision layers (3D physics) — the hitbox/hurtbox convention (story 1-7)**
- Three named `3d_physics` layers exist in `project.godot` `[layer_names]` (authored from zero in 1-7 — there was no section before): **layer 1 "bodies"** (bit value 1) — the default layer; `CharacterBody3D` heroes and the ground sit here by not setting a layer. **Layer 2 "hurtbox"** (bit value 2). **Layer 3 "hitbox"** (bit value 4). The next story that needs a layer starts at layer 4 and names it here.
- **Hitbox** (`Area3D` in `hero.tscn`): `collision_layer = 4` (hitbox), `collision_mask = 2` (hurtbox), `monitorable = false` — it DETECTS hurtboxes and is detected by nothing. Hitboxes are not in each other's masks, so hitboxes never see hitboxes.
- **Hurtbox** (`Area3D` in `hero.tscn`): `collision_layer = 2` (hurtbox), `collision_mask = 0`, `monitoring = false` — it is DETECTED and detects nothing.
- **Neither node holds gameplay logic and neither applies damage** (the HARD RULE above, made concrete). The ONLY consumer is the runner's `_gather_contact_facts` (`match_runner.gd`): a direct `get_overlapping_areas()` query — never `area_entered` signals (their firing order is not guaranteed and would make replay order-dependent) — run only while the state flags the swing active (`HeroState.is_hitbox_active()`), stamping the attacker's `attack_index` at GATHER time, identity-filtering self-overlaps (the overlapping area's owning actor != the attacker — the attacker's own hurtbox is inside its hitbox's mask and reach on every swing), and pushing facts through `MatchState.push_contact`, the sole intake. `advance()` step 4 decides. Actors report, state decides.
- The hitbox is aimed by yawing the **CHILD node** from `HeroState.facing` in `HeroActor.drive()`; the hero ROOT never rotates (DECISION A).
- Current-scene fact, not part of the convention: only `hero.tscn` carries the pair today (the only actor). The layer/mask values are per-node scene properties, not project defaults — a new actor scene must set them per this table.

**HARD RULE — Feature flags**
- Every gameplay layer must be **independently toggleable** through a single `FeatureFlags` Resource loaded **once at startup**: melee mana generation, unblockable system, orbs, pitch zone, minions, totems, equipment.
- Systems read flags from that **one place** (the `FeatureFlagsService` autoload) and **degrade gracefully** when a layer is off (e.g. with orbs disabled, pitch costs require mana only).
- Rationale: playtests must isolate which layer causes cognitive overload; toggling must be a checkbox, not a code edit.

### Performance Rules

- **Target: 60 FPS** on a mid-range desktop (~16.6 ms/frame). The arena is small and flat; the frame budget is dominated by **many autonomous minions + totem targeting + VFX**, not world rendering.
- **Combat determinism over frame smoothing:** fixed logic (hit windows, unblockable chargeup/defense timing) runs in `_physics_process`. Never gate a timing-critical window on a variable `_process` delta.
- **Object pooling:** pool frequently spawned/despawned nodes — minions, projectiles (pseudo-shuriken), VFX, and orb/damage popups. Do not `instantiate()`/`queue_free()` per shot in a hot path.
- **Minion & totem targeting:** target-acquisition scans (nearest enemy, aggro/threat redirect, AoE clump detection) must NOT run every frame for every unit. Use a shared, throttled tick (e.g. re-target every ~0.1–0.25 s) and/or `Area3D` overlap queries rather than manual distance loops over all units each frame.
- **Signal-driven HUD (perf angle):** because state pushes via signals (see state/visual separation), the HUD must not poll or recompute economy values per frame.
- **No per-frame allocations in hot paths:** avoid building arrays/dictionaries or lambdas inside `_physics_process`. Reuse buffers.
- **Prefer `Area3D`/physics queries for hit detection** over manual geometry math; let Jolt do broadphase.

### Code Organization Rules

**Folder layout** (greenfield — establish this structure; `res://` root):
- `res://src/state/` — pure gameplay state layer (hero stats, mana/stamina/orb economy, card resolution, the `MatchState` object, shared gameplay enums). No scene/visual deps.
- `res://src/systems/` — autoloads & cross-cutting systems (`EventBus`, `CardDatabase`, `FeatureFlagsService`, `BalanceConfigService`, pooling). Autoloads own their config/content instances and expose them; they hold **no gameplay logic and never expose live mutable match state** (the Match Runner owns `MatchState` — see §Autoloads).
- `res://src/controllers/` — the Controller abstraction (`Controller`, `KeyboardController`). **The only place `Input.*` is read** (D3); produces `InputIntent` value objects.
- `res://src/actors/` — scene-bound nodes: hero, minions, totems, projectiles (each a `.tscn` + its script). Driven by the runner; read state, never `Input`.
- `res://src/ui/` — HUD and menus (read-only consumers of state signals).
- `res://src/main/` — root scene + the **Match Runner** (`match_runner.gd`): the single `_physics_process` that owns `MatchState` and drives the tick (F1/D2).
- `res://data/` — authored `.tres` content: `data/cards/`, `data/minions/`, `data/equipment/`, `data/balance/`.
- `res://assets/` — art, audio, models, materials.
- `res://test/` — tests mirroring `src/`: `test/state/` (headless state tests, bootstrap harness) + `test/integration/` (runtime scene tests). GUT added later (X6).

**Separation enforced by folders:** nothing in `src/state/` may `preload`/reference `src/ui/`, `src/actors/` scenes, or `AnimationPlayer`. Dependencies point visuals → state, never the reverse.

### Naming Conventions

- **Files:** `snake_case.gd`, `snake_case.tscn`, `snake_case.tres` (e.g. `imp_summoner.tres`, `hero_state.gd`).
- **Classes / `class_name`:** `PascalCase` (`CardData`, `HeroState`, `MinionActor`, `FeatureFlags`).
- **Functions / vars:** `snake_case`. **Private** members prefixed `_` (`_recompute_mana`).
- **Constants / enums:** `CONSTANT_CASE`; enum *type* is `PascalCase` (`enum CardColor { RED, BLUE, GREEN }`).
- **Signals:** past-tense `snake_case` (`hp_changed`, `card_played`, `pitch_staged`, `orb_gained`).
- **Booleans / flags:** `is_`/`has_`/`can_` prefix.
- **Node names in scenes:** `PascalCase` matching their role (`Hitbox`, `Hurtbox`, `AnimationPlayer`).
- **Card color is a first-class enum** (`RED`/`BLUE`/`GREEN`) used consistently across unblockable attacks, defenses, and orbs — never bare strings. Shared gameplay enums live in `src/state/` (e.g. `src/state/enums.gd`), since state must never reference `src/actors/` or `src/ui/`.

### Testing Rules

- **Framework:** **GUT is NOT yet installed** (X6 — not a prerequisite for E0). A bootstrap harness covers the state layer headless: `test/state/test_*.gd` extend `TestCase` (assert names mirror GUT for near-free later migration), run by `test/run_state_tests.gd` via `godot --headless --script`. Add GUT (`res://addons/gut/`) when convenient. Tests live in `res://test/`, mirroring `src/`.
- **State layer is tested headless — no scene, no visuals.** Because the state layer (`src/state/`) has no scene/visual dependencies, all economy and resolution logic (damage, stamina, mana, orbs, card resolution, unblockable RPS outcomes) must be covered by pure unit tests that instantiate state objects directly and assert on signals/return values. If a rule can't be unit-tested without a running scene, the state/visual separation has been violated — fix the code, not the test.
- **Assert on signals:** drain the `SignalQueue`, then verify state emitted the right signal (e.g. `hp_changed`, `orb_gained`) rather than reaching into private fields. (Once GUT lands: `watch_signals()` / `assert_signal_emitted_with_parameters()`.)
- **Feature-flag matrix:** for any layer with a `FeatureFlags` toggle, test both ON and OFF paths, and assert graceful degradation (e.g. orbs OFF → pitch cost is mana-only, no orb requirement).
- **Data-driven content is validated, not hand-mocked:** load real `.tres` card/minion/equipment resources in tests where practical, so authored content is exercised. Add a smoke test that loads every `.tres` in `data/` and asserts required fields are set.
- **Determinism:** timing-sensitive tests advance **fixed integer ticks** (call `advance()` / `TimingWindow.tick()` N times), never feed wall-clock `delta` or `await` real time (`advance()` takes no `delta` — A1). A **determinism regression** hashes a canonical **sorted-key** snapshot of `MatchState` against a golden value (never insertion-order `Dictionary` iteration).
- **Golden isolation:** authored `data/balance/*.tres` tuning is isolated from BOTH the golden and the unit suite (a value edit needs no test change) — but `data/economy/*.tres` rule CONTENT is load-bearing for the golden, since production code reads it on the golden's own path (`BC/R3`, narrowed `3-4/R6`).
- **Integration/scene tests** (actors moving, hitbox→state contact wiring) live in `res://test/integration/`, need the engine runtime, and run standalone; keep the bulk of coverage in the headless state tests.
- **Mutation-proof discipline:** a mutation made to prove a guard non-vacuous is restored from a copy taken OUTSIDE the repo, NEVER `git checkout --` (decision-log:799). The non-vacuity check must be proven against forms an adversary would use, not the author's own syntax (`3-0d/R14`).
- **Guard mechanism over guard pattern:** prefer making a property IMPOSSIBLE BY CONSTRUCTION over DETECTABLE BY INSPECTION (e.g. a source-text scan); a guard evaded twice gets its mechanism replaced, not its pattern widened a third time (`3-0d/R20`).
- **Adversarial review:** a pass must state what counts as FAILURE before it starts, not after (3-0d close-out, 2026-08-06).
- **Suite cadence (a DISCLOSURE rule, not a cap):** the full suite runs TWICE per pass by default — once at open, once at close; mutation proofs run ONLY the affected test file, never the full suite. A further run is legitimate WITH A STATED REASON, and every run beyond the second is ALWAYS REPORTED, never absorbed (`PROC/R1`, reclassified `E5-R/R5` — three epics of bends were all disclosed with their cause).
- **Review shape:** two parallel adversarial layers; the Acceptance Auditor's checks run INLINE in the main session as a mandatory checklist, including the Dev Agent Record evidence audit — a falsified record claim is annotated in place. Every review records a greppable `LAYER-COMPLETION:` line naming each declared layer with its terminal state; a report without it is REJECTED in the browser and re-run (`PROC/R2`, amended `E4-R/R2` — which also retires the `PROC/R6` stall counter that definition fed). The report is WRITTEN WITH THE WRITE TOOL to `C:\dev\_<story>-review.md` so the artifact survives its session, and the story's close-out log session carries ONE line naming each declared layer with its terminal state (`E5-R/R2` — ten of twelve E5 review reports existed nowhere afterwards, and one story cited a review file that never existed).
- **Edit fallback:** on the FIRST failed Edit match against a file carrying em-dashes or tabs, switch to a python byte-replace — no Edit retries (`PROC/R3`).
- **Machine-time budget (Tier B only):** ~1 h for a story of `4-B1`'s size (dev pass + code review). The OPERATOR sets the budget at the scope conversation — a story never states its own. Instrument: the timestamps of the two suite-output files (before-baseline and final, both written outside the repo), recorded in the close-out entry as start / end / delta. The interval is the FULL STORY CYCLE — the first before-baseline run to the LAST suite run of the whole story, review fixes included, never the dev pass alone — recorded in the close-out LOG entry, not the story file; an overrun is REPORTED, never blocking (`E5-R/R3` — every E5 delta stopped at the dev pass, and `5-0d` read "well inside" at 17m43s while the full cycle was ~74 min). On crossing, report the remaining work — never push through silently (`PROC/R7`, amended `E4-R/R3`, amended `E5-R/R3`).
- **Gate-round cap:** after a story's SECOND readiness gate returning NOT READY, the third round is a scope conversation with the operator, not another gate-and-fix pass. The create pass writes BEHAVIOUR and ACCEPTANCE, not mechanism — except where a ruling already put the mechanism in (`E4-R/R4`).
- **Promotion needs a close-out:** a story is not promoted to `done` on the board until a decision-log close-out session names it; the promotion prompt greps for that session before flipping the status (`E4-R/R7`).
- **Text fit is not machine-checkable:** machine checks assert GEOMETRY only; never assert on-screen text fit from character counts — any AC hinging on on-screen legibility goes to operator smoke at first render (`PROC/R8`).

### Platform & Build Rules

- **Primary platform: Windows desktop** (D3D12 / Forward+). No mobile/web targets in demo scope. Don't add platform `#if`-style branches or mobile renderer fallbacks.
- **Input:** define named actions in the Input Map (Project Settings) and read via `Input.is_action_*` **only inside `src/controllers/`** (D3) — never hardcode raw keycodes, and never touch `Input` from state or actors. The two local profiles (P1/P2) are **one** `KeyboardController` taking a `"p1"`/`"p2"` prefix, so split-screen/hot-seat is a config, not a second class.
- **Do not commit generated/local files:** `.godot/`, `/export/`, `export_presets.cfg`, `.claude/settings.local.json` are git-ignored — keep it that way.
- **Keep `project.godot` edits intentional:** autoload registration and Input Map live here; review diffs before committing.
- **Commit trailer:** `Co-Authored-By: Claude Opus 4.8` is a repo-wide constant on every commit, regardless of which model actually did the work — never the real model name.

### Critical Don't-Miss Rules (anti-patterns & gotchas)

- **NEVER let a visual drive state.** No applying damage from an `AnimationPlayer` call track, animation "hit frame" callback, VFX lifetime, or UI button handler. Visuals emit intent/contact → state decides. (See HARD RULE.)
- **NEVER hardcode a gameplay layer on.** Any of {melee mana gen, unblockable, orbs, pitch zone, minions, totems, equipment} must check the **injected `FeatureFlags` resource** and degrade gracefully when off. **State-layer code receives `FeatureFlags` by injection and never reads `FeatureFlagsService`;** only `actors` / `ui` / `systems` may read the service. (See HARD RULE.)
- **NEVER hardcode balance or content** (card costs, orb requirements, HP/stamina/mana values, unblockable damage, equipment passives, minion priority types). It lives in `.tres` / balance resources. The TDD flags most numbers as TBD-during-playtest — they must be tunable without recompiling.
- **NEVER implement networking.** No RPCs, no authoritative-server logic. The TDD's Section 14 is obsolete for the demo. (The state/visual split is what keeps netcode addable *later*.)
- **NEVER treat the legacy TDD's engine details as instructions** — it's UE5/C++. Mechanics = canon; implementation = Godot/GDScript per this file.
- **Orb reset is all-colors:** activating a Pitch Effect resets the orb pool for **all three colors** to 0, not just the spent color (TDD 8.2). Easy to get wrong.
- **Pitch Zone does not reduce hand size:** a staged card still counts toward the hand of 4 until activated/cancelled (TDD 5.6).
- **Unblockable damage is per-color, not per-card:** a single fixed value per color in balance config (TDD 7.5) — don't read it off `CardData`.
- **Free tree nodes with `queue_free()`**, not `free()`; validate with `is_instance_valid()` before touching pooled/possibly-freed nodes.
- **No Godot 3.x API.** `export var`, `yield`, `KinematicBody`, `.instance()`, `OS.get_ticks_msec` polling loops → use 4.x equivalents.
- **`Dictionary.has(key)` is TRUE for a key whose value is `null`** — presence is not type; check the value's type too before trusting it (`3-0d/R21`).
- **`load()` returns a NON-NULL `GDScript` for a file that fails to parse** — a non-null check is vacuous; `can_instantiate()` is the working (if weaker) discriminator (`3-0d/R24`).
- **`path.begins_with("user://")` is NOT a containment test** — the string can carry `..` and resolve outside it; normalise (`globalize_path().simplify_path()`) and compare against the resolved root plus separator (`3-0d/R22`).

---

## Usage Guidelines

**For AI Agents:**

- Read this file before implementing any game code in CardSouls.
- Follow ALL rules exactly. The two **HARD RULES** (state/visual separation, feature flags) are non-negotiable architectural invariants — violating them is a defect even if the feature "works."
- When in doubt, prefer the more restrictive option and keep logic in the state layer.
- `docs/tdd-legacy-ue5.md` is the mechanics source of truth; this file is the implementation source of truth. When they conflict on *how*, this file wins.

**For Humans:**

- Keep this file lean and focused on what agents miss — not a general Godot tutorial.
- Update when the stack changes (Godot version, adding a test framework, first real code establishing a pattern).
- Revisit once real `src/` code exists: convert "proposed conventions" here into "observed patterns," and delete any rule that has become obvious from the codebase.

Last Updated: 2026-09-07
