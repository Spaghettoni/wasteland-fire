# Story 062: The chase view first

> **Epic**: Wasteland Fire — First Playable
> **Status**: Done
> **Layer**: Presentation
> **Type**: Config/Data
> **Estimate**: XS
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-26

## Context

**Requirement**: Martin, 2026-10-26: "nech je ten sikmy pohlad zozadu default, nie ten zhora".

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: Every Player's camera starts a match in the chase view (chase_camera_settings.tres); the camera key still steps to the view from above and back.
- [x] AC-2: The evidence scenarios written on the view from above keep it: the runner gives SHIPPED_CAMERA scenarios, and Players 3 and 4 of every lineup scenario, the view from above unless the scenario declares CHASE_FIRST.

---

## Implementation Notes

- `split_screen.tscn`: both cameras' `settings` = `chase_camera_settings.tres` (Players 3 and 4 copy Player 2's). `split_screen_harness.gd`: `ABOVE_CAMERA_SETTINGS`, `CHASE_FIRST`.

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: `controls_check` C7 (the shipped flow: both cameras start in the chase view); the regression.

**Status**: [x] `production/qa/evidence/story-061-evidence.md` (shared)

---

## Dependencies

- Depends on: stories 010, 050.
- Unlocks: none.
