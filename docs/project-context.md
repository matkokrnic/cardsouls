---
project_name: 'CardSouls'
user_name: 'Matko'
date: '2026-07-20'
sections_completed: ['technology_stack', 'engine_specific', 'performance', 'code_organization', 'testing', 'platform_build', 'critical_gotchas']
status: 'complete'
rule_count: 47
optimized_for_llm: true
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
- Physics/combat logic (movement, hit detection) goes in `_physics_process(delta)`, not `_process(delta)`. UI/HUD updates go in `_process` or, better, are signal-driven.
- Use `CharacterBody3D` + `move_and_slide()` for the hero (Godot 4 API). Jolt is the physics backend — do not assume Godot's default physics quirks.

**Signals over polling**
- Combat/economy state changes (HP, stamina, mana, orbs, card played, pitch staged) MUST emit **signals**; the HUD subscribes. Do not have the HUD poll hero state every frame.
- Declare typed signals: `signal hp_changed(current: float, max: float)`.
- **Direct subscription is the default:** consumers (HUD, etc.) subscribe directly to the **owning state object's** typed signals. `EventBus` is reserved for genuinely global, cross-system events with no clear owner (e.g. match started, round ended). Do NOT route per-entity state changes (hp, stamina, mana, orbs) through `EventBus`.

**Autoloads (singletons)**
- Global systems are Godot **autoloads** registered in `project.godot`. Anticipated: `EventBus`, `CardDatabase`, `FeatureFlags`, and a thin `MatchState` autoload wrapper. Keep them minimal — no gameplay logic inside autoloads.
- **MatchState split:** the match logic lives in `src/state/` as a plain, testable object with **no scene dependency**. The `src/systems/` autoload is only a thin wrapper that owns the instance and exposes it globally. Never put match logic in the autoload.

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

**HARD RULE — Feature flags**
- Every gameplay layer must be **independently toggleable** through a single `FeatureFlags` Resource loaded **once at startup**: melee mana generation, unblockable system, orbs, pitch zone, minions, totems, equipment.
- Systems read flags from that **one place** (the `FeatureFlags` autoload) and **degrade gracefully** when a layer is off (e.g. with orbs disabled, pitch costs require mana only).
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
- `res://src/systems/` — autoloads & cross-cutting systems (`EventBus`, `CardDatabase`, `FeatureFlags`, the thin `MatchState` autoload wrapper, pooling). Autoloads own instances and expose them; they hold no gameplay logic.
- `res://src/actors/` — scene-bound nodes: hero, minions, totems, projectiles (each a `.tscn` + its script).
- `res://src/ui/` — HUD and menus (read-only consumers of state signals).
- `res://data/` — authored `.tres` content: `data/cards/`, `data/minions/`, `data/equipment/`, `data/balance/`.
- `res://assets/` — art, audio, models, materials.
- `res://test/` — GUT tests, mirroring `src/` structure.

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

- **Framework:** **GUT** (Godot Unit Test) addon under `res://addons/gut/`. Tests live in `res://test/`, mirroring `src/`. Test files are `test_*.gd` extending `GutTest`.
- **State layer is tested headless — no scene, no visuals.** Because the state layer (`src/state/`) has no scene/visual dependencies, all economy and resolution logic (damage, stamina, mana, orbs, card resolution, unblockable RPS outcomes) must be covered by pure unit tests that instantiate state objects directly and assert on signals/return values. If a rule can't be unit-tested without a running scene, the state/visual separation has been violated — fix the code, not the test.
- **Assert on signals:** use GUT's `watch_signals()` / `assert_signal_emitted_with_parameters()` to verify state emits the right signal (e.g. `hp_changed`, `orb_gained`) rather than reaching into private fields.
- **Feature-flag matrix:** for any layer with a `FeatureFlags` toggle, test both ON and OFF paths, and assert graceful degradation (e.g. orbs OFF → pitch cost is mana-only, no orb requirement).
- **Data-driven content is validated, not hand-mocked:** load real `.tres` card/minion/equipment resources in tests where practical, so authored content is exercised. Add a smoke test that loads every `.tres` in `data/` and asserts required fields are set.
- **Determinism:** timing-sensitive tests drive logic by feeding fixed `delta` steps into the state layer, never by `await`-ing real wall-clock time.
- **Integration/scene tests** (actors moving, hitbox→state contact wiring) are separate and minimal; keep the bulk of coverage in the headless state tests.

### Platform & Build Rules

- **Primary platform: Windows desktop** (D3D12 / Forward+). No mobile/web targets in demo scope. Don't add platform `#if`-style branches or mobile renderer fallbacks.
- **Input:** define named actions in the Input Map (Project Settings) and read via `Input.is_action_*` / `InputEvent` actions — never hardcode raw keycodes. Demo is local; plan for two local input profiles (P1/P2) so a second player / hot-seat is a config, not a rewrite.
- **Do not commit generated/local files:** `.godot/`, `/export/`, `export_presets.cfg`, `.claude/settings.local.json` are git-ignored — keep it that way.
- **Keep `project.godot` edits intentional:** autoload registration and Input Map live here; review diffs before committing.

### Critical Don't-Miss Rules (anti-patterns & gotchas)

- **NEVER let a visual drive state.** No applying damage from an `AnimationPlayer` call track, animation "hit frame" callback, VFX lifetime, or UI button handler. Visuals emit intent/contact → state decides. (See HARD RULE.)
- **NEVER hardcode a gameplay layer on.** Any of {melee mana gen, unblockable, orbs, pitch zone, minions, totems, equipment} must check `FeatureFlags` and degrade gracefully when off. (See HARD RULE.)
- **NEVER hardcode balance or content** (card costs, orb requirements, HP/stamina/mana values, unblockable damage, equipment passives, minion priority types). It lives in `.tres` / balance resources. The TDD flags most numbers as TBD-during-playtest — they must be tunable without recompiling.
- **NEVER implement networking.** No RPCs, no authoritative-server logic. The TDD's Section 14 is obsolete for the demo. (The state/visual split is what keeps netcode addable *later*.)
- **NEVER treat the legacy TDD's engine details as instructions** — it's UE5/C++. Mechanics = canon; implementation = Godot/GDScript per this file.
- **Orb reset is all-colors:** activating a Pitch Effect resets the orb pool for **all three colors** to 0, not just the spent color (TDD 8.2). Easy to get wrong.
- **Pitch Zone does not reduce hand size:** a staged card still counts toward the hand of 4 until activated/cancelled (TDD 5.6).
- **Unblockable damage is per-color, not per-card:** a single fixed value per color in balance config (TDD 7.5) — don't read it off `CardData`.
- **Free tree nodes with `queue_free()`**, not `free()`; validate with `is_instance_valid()` before touching pooled/possibly-freed nodes.
- **No Godot 3.x API.** `export var`, `yield`, `KinematicBody`, `.instance()`, `OS.get_ticks_msec` polling loops → use 4.x equivalents.

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

Last Updated: 2026-07-20
