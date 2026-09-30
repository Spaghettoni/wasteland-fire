# Story 007: The Map

> **Epic**: Wasteland Fire — First Playable
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: M (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 7 — *The Map: one small arena holding both Bases and the Fuel Can spawn points, dressed with a ready-made low-poly kit so it reads as one coherent wasteland.*

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (the **Player goal & fail state** field + the MVP feature this story implements), scoped to this story:*

- [ ] AC-1: One small bounded arena replaces the greybox plane, with the two Bases at opposite ends and the Fuel Can spawn points placed between them; a Motorbike crosses it in tens of seconds, not minutes.
- [ ] AC-2: Obstacles that ground Units must drive around and the Gyrocopter flies over, so the Motorbike's agility and the Gyrocopter's flight both matter.
- [ ] AC-3: The arena, the obstacles and the three Units use ready-made low-poly kit assets (CC0 — Kenney, Quaternius, or equivalent) with one flat-shaded palette in rust, dust and sun-bleached bone; nothing reads as a mismatched kit.
- [ ] AC-4: Both Bases, both canisters and the Fuel Cans are readable at a glance from either viewport (Player colours / markers).
- [ ] AC-5: The Map is a scene: Base positions, spawn points and Fuel Can spots are `Marker3D`s in it, not constants in code; swapping the Map scene needs no script change.
- [ ] AC-6: Holds 60 fps with two viewports and the dressed arena at 1280×720.
- [ ] AC-7: Every imported asset's source and licence is recorded in `assets/LICENSES.md`.
- [ ] AC-8: The look is judged coherent by a human and recorded in the evidence doc, with a screenshot from each viewport.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers into the pinned engine reference, not decisions:*

- Kits: Kenney's assets are CC0, attribution not required (research note, Part 2 §F); import glTF `.glb` directly; a hand-placed scene is enough for one Map (`GridMap` optional).
- Keep the Map's collision on the ground layer; the Gyrocopter's layer passes over obstacles (story 005).
- Performance: `docs/engine-reference/godot/modules/rendering.md` § 4.7 Changes — nearest-neighbour 3D scaling (`Viewport.SCALING_3D_MODE_NEAREST`) suits a low-poly look and halves per-viewport cost if 60 fps slips; `AreaLight3D` adds GPU cost to every object in a frustum that holds one — avoid.
- Use the run-and-observe capture (`--write-movie`) from both viewports for the evidence frames.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- A second Map, a map editor, destructible buildings — out of scope in the brief.
- Music and sound — not in the First Playable.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Visual/Feel
**Required evidence**:
- Retained screenshots of the dressed arena from each viewport in `production/qa/evidence/story-007-the-map/`, plus sign-off in `production/qa/evidence/story-007-the-map-evidence.md` recording the coherence judgement (AC-8) and the 60 fps check (AC-6).
- Tests: waived at `qa.level: minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 must be DONE
- Unlocks: None — the First Playable is complete; the Game-Night Build is charted later
