# CardSouls

A 1v1 real-time hybrid — soulsborne melee **+** a Red/Blue/Green card economy. **Godot 4.6.3**
(GDScript only, Forward+/D3D12, Jolt physics), Windows desktop, local split-screen, **no networking**.

Design & architecture live in `docs/`:
- `docs/game-architecture.md` — the technical decision spine (decisions D1–D9, invariants, seams).
- `docs/project-context.md` — implementation rules AI agents must follow.
- `docs/planning-artifacts/gdds/.../gdd.md` — the canonical design (GDD).

## Requirements
- **Godot 4.6.3 stable** — GDScript only (no C#/Mono). On Windows the binary in this repo's flow
  is `C:\Godot\godot`.

## Running the state tests (headless)
The pure state layer (`src/state/`, `src/controllers/`) is tested without the engine runtime:

```
godot --headless --path . --script res://test/run_state_tests.gd
```

When reading the result through a pipe, take the exit code from the **godot** stage — set
`-o pipefail` or read `${PIPESTATUS[0]}`, or `grep`/`head` will mask a failing run.

### Fresh clone: build the class cache first
`class_name` resolution needs `.godot/global_script_class_cache.cfg`, which is **git-ignored** and
therefore absent on a fresh clone. If tests fail to load with *"Could not find type ..."*, build the
cache once, then re-run:

```
godot --headless --editor --quit --path .
```

(The test harness also prints this remedy if a test fails to load.)

## Architectural invariants
Enforced by `test/state/test_architecture_invariants.gd` (and greppable by hand):
- **F1** — exactly one `func _physics_process` in `src/`, in `src/main/match_runner.gd`.
- **D3(a)** — `Input.*` only under `src/controllers/`.
- **D3(b)/A2** — no global RNG / `Time.*` / `OS.*` / `Engine.*` in `src/state/` (the single seeded
  gameplay RNG owned by `MatchState` is the only randomness).

## What NOT to commit
`.godot/`, `/export/`, `export_presets.cfg`, `.claude/settings.local.json` are git-ignored — keep it so.
