# Story 050: More Tokens, and a chase view with the Unit low and the way ahead in sight

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**Requirement**: Martin, 2026-10-25, after testing story 049: "dajme viac kreditov pre kazde vozidlo, nech je ich 1,3x tolko aspon. dokopy." (more Tokens for every Unit type, at least 1.3 times as many in all); "ked sa pozeras zozadu, pri 4 hracov, vozidla su akesi male. asi fov nastavenie. + mam pocit ze su zbytocne v strede obrazovky. podla mna pohlad by mohol byt viac tak, ze vozidlo mas v spodnej casti a vidis skor veci pred sebou ako za sebou" (in the view from behind with four Players the Units look small, probably the field of view; they sit needlessly in the middle of the screen; the Unit should be in the lower part, with more of what is ahead in sight than behind).

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: Both Maps' stock is Motorbike 7, Buggy 4, Truck 3, Gyrocopter 3 (was 5, 3, 2, 2): more of every type and 17 in all, at least 1.3 times 12. Each Team starts with it.
- [x] AC-2: The chase view keeps its field of view across the width (68.6 degrees, the half view's width angle before), so a Unit in a quarter view of the four-way split is drawn as wide as in a half view.
- [x] AC-3: In the chase view the camera sits 9 m behind and 6.5 m above the Unit and looks 7 m ahead of it: standing, the Unit is drawn in the lower part of its view (its lower third in a quarter view); the way ahead takes most of the view.
- [x] AC-4: The view from above is unchanged; the earlier scenarios differ from story 049's outputs only in timings.

---

## Implementation Notes

- `ChaseCameraSettings.width_fov_degrees` (zero: the camera keeps the scene's own field of view, 75 degrees across the height); `ChaseCamera` applies it with the settings, as `Camera3D.KEEP_WIDTH`, and gives the camera its own back on settings without one (the view from above).
- `chase_camera_settings.tres`: offset (0, 6.5, 9), look_ahead 7, width_fov_degrees 68.6. `token_stock.tres`: 7 / 4 / 3 / 3 (shared by both Maps).
- The evidence runner gives scenarios that do not declare `CLOSE_CHASE` the old chase settings and those that do not declare `MORE_TOKENS` the old counts.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `chase_view` V1–V3; before / after frames of the chase view with four and with two Players in `production/qa/evidence/story-050-tokens-and-chase-view/`; Martin's look.

**Status**: [x] Created 2026-10-25: `production/qa/evidence/story-050-tokens-and-chase-view-evidence.md`

---

## Dependencies

- Depends on: story 010 (the camera's two views), story 048 (the four-way split).
- Unlocks: none.
