# Story 047: Canyon wall shadows near the camera; a pad's B back to the map choice

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-22

## Context

**Requirement**: Martin, 2026-10-22, with a picture of a Motorbike beside Map 02's west canyon wall: "ked idem pri zraze, tiene sa stracaju za vozidlom" (when I drive by the cliff, the shadows vanish behind the vehicle); "b na zvolenie dalsej mapy nefunguje" (B to choose another map does not work). He plays on Windows (not a Mac, as the session had assumed).

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: Beside a canyon wall the wall's shadow runs unbroken from the far end of the view to the camera, in the chase view and the view from above, with the Forward+ renderer (both Maps' Sun: `directional_shadow_pancake_size = 0`).
- [x] AC-2: On the Round-over screen a pad's B leaves for the map choice (measured: it does; Martin's case is still open, see the evidence).
- [x] AC-3: The headless outputs of the Map scenarios are unchanged.

---

## Implementation Notes

- Reproduced with the Forward+ renderer on Vulkan (Mesa's software lavapipe in the cloud session): with the default pancake size (20 m) the shadow of the 6.5 m canyon wall broke off a few metres ahead of the camera. Pancake size 0 fixes it; the orthogonal shadow mode fixed it too, but blurrier, so PSSM stays.
- `tools/maps/build_map_02.py` writes the setting; Map 01's Sun is edited by hand.
- `pad_back` (headless) and `shadow_showcase` (windowed, run with `--rendering-driver vulkan`) are new evidence scenarios.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: before / after frames in `production/qa/evidence/story-047-shadows-and-pad-back/`; `pad_back` B1, B2; Martin's look on Windows.

**Status**: [x] Created 2026-10-22: `production/qa/evidence/story-047-shadows-and-pad-back-evidence.md`

---

## Dependencies

- Depends on: story 038 (Map 02, the map choice and its way back).
- Unlocks: none.
