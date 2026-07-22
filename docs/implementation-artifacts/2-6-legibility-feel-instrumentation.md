# Story 2.6: Legibility and feel validation instrumentation

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a solo developer running playtests,
I want the feature-flag overlay, deterministic step/pause, the per-player state inspector, a written telegraph-legibility protocol, and end-to-end split-screen record/replay,
so that a playtest can isolate layers, inspect a window frame by frame, and answer "I didn't see that happen" honestly.

## Acceptance Criteria

1. The runtime `FeatureFlags` toggle overlay (debug-flag gated) lands: a playtest can turn a layer off between rounds without a code edit. E1/E2 have few flags yet — the overlay is built now so E3 onward gets it free.
2. The deterministic step/pause debug control lands: pause the runner and advance N fixed ticks, so a deflect window or telegraph is inspected frame by frame — the only honest way to answer "I didn't see that happen."
3. The per-player state inspector (pools, active `TimingWindow`s, current telegraph) lands, reading signals only, never mutating. It lives in `src/ui/debug/`.
4. The **telegraph legibility protocol** is written into `docs/playtest-log.md` as a repeatable procedure (play at half width, sound on, naive observer, record whether the action was identified before it resolved) — not a vibe check. E1's melee telegraphs are the rehearsal; the protocol must exist and be trusted before E5's colour telegraphs.
5. Record/replay works end to end under split-screen: record a two-human round, replay via `ReplayController` on both slots, and confirm the seed, both intent streams, and any balance-reload events reproduce it exactly. Then hot-reload a balance value mid-round and confirm the reload event is captured and re-applied at the same tick.

## Tasks / Subtasks

- [ ] Build the runtime `FeatureFlags` toggle overlay (debug-flag gated) (AC: 1)
- [ ] Build deterministic step/pause (advance N fixed ticks) (AC: 2)
- [ ] Build the per-player state inspector (signals-only, no mutation) (AC: 3)
- [ ] Write the telegraph legibility protocol into `docs/playtest-log.md`; run it once vs E1 cues (AC: 4)
- [ ] Prove split-screen record/replay incl. a mid-round balance reload captured + re-applied at the same tick (AC: 5)

## Dev Notes

- Instrumentation is architecture (executive summary): the overload instrument (flag overlay), the frame-by-frame inspector, and deterministic record/replay are the tools the whole validation demo runs on. [Source: docs/game-architecture.md#Executive Summary; #Debug Tools]
- Balance hot-reload is recorded, not ignored: `IntentRecorder` records reload events; `ReplayController` re-applies them at the same tick. [Source: docs/game-architecture.md#Determinism & Replay — X3/X5 reconciliation]
- The legibility protocol is written now against E1 melee cues precisely so it is trusted before E5's colour telegraphs, which it exists to judge. [Source: stories-manual-e2.md#E2.S6 item 4]

### Project Structure Notes

- Debug overlays/inspector/step-pause in `src/ui/debug/` (no state mutation); `IntentRecorder` in `src/systems/`; `ReplayController` in `src/controllers/`; protocol in `docs/playtest-log.md`.

### Project Context Rules

- **Debug tools read signals only, never mutate.** [Source: docs/game-architecture.md#Debug Tools; #Architectural Boundaries]
- **Feature flags loaded once at startup;** the overlay toggles at runtime for isolation. [Source: docs/project-context.md#HARD RULE — Feature flags]

### References

- [Source: stories-manual-e2.md#E2.S6]
- [Source: docs/game-architecture.md#Debug Tools; #Instrumentation wiring; #Determinism & Replay]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
