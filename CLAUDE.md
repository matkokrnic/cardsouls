# CLAUDE.md — CardSouls

Router for AI agents working in this repo. It points to authoritative sources; it does **not**
restate their content (a second copy is how the two docs drift apart). **Read only what the current
task needs — do not read the whole architecture doc for a one-file change.**

## Authoritative documents — precedence when they disagree
1. **GDD** — `docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/gdd.md` (+ `epics.md`, `decision-log.md`). Design intent, mechanics, scope. Highest authority.
2. **`docs/game-architecture.md`** — the technical decision spine (decisions, invariants, seams). Authoritative on *how it is built*.
3. **`docs/project-context.md`** — condensed implementation rules for agents, derived from the two above. If it disagrees with them, **they win** — then fix project-context.
4. **`docs/tdd-legacy-ue5.md`** — LEGACY UE5/C++ reference. Mechanics are historical context only; **never** a source of truth for engine or implementation. Never cite it for how to build anything.

Pick by task: economy / combat / card rules → GDD; a structural or determinism question → architecture doc; "which rule am I about to break" → project-context.

## Load-bearing invariants — executable in `test/state/test_architecture_invariants.gd`
- **F1** — exactly one `func _physics_process` in `src/`, in `match_runner.gd`.
- **D3(a)** — `Input.*` only under `src/controllers/`.
- **D3(b)/A2** — no global RNG / `Time` / `OS` / `Engine` in `src/state/`.

These fail the suite if violated — the guard is the test, not review.

## Running tests
- All suites: `bash test/run_all.sh` (state harness + integration; exits nonzero if any fails).
- **Fresh clone:** build the class cache once — `godot --headless --editor --quit --path .` (`.godot/` is git-ignored). Details in `README.md`.

## Commit conventions (observed here)
- **Docs and code never share a commit** — separate them.
- **Validation that proves something worth proving gets committed as a test** (under `test/`), never written-then-deleted.
- Keep `project.godot` edits intentional (autoloads / Input Map / main scene); review the diff.

## Agent autonomy

- Implementation decisions are yours: make them and proceed without asking.
- DESIGN decisions are Matko's. STOP and ask before implementing whenever a
  choice would change what the game IS (mechanics, player-facing behavior,
  tuning semantics) or how the codebase is shaped for future stories (new
  public APIs, new folders, architectural patterns) — unless the current
  story, GDD, or decision-log already locks that choice. When unsure which
  kind it is, ask.
- Test: "am I choosing HOW to satisfy an already-locked requirement?" ->
  implementation, proceed. "Am I choosing WHAT the requirement is?" ->
  design, ask.

## Git discipline (applies regardless of permission mode)

- Show the full diff BEFORE staging. `git add` and `git commit` are separate
  commands, explicit paths only.
- NEVER push until Matko confirms the log in chat.
- Anything sent to the browser chat for review must be pasted in full —
  "the diff is above" is not review.
