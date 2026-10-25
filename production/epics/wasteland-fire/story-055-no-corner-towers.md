# Story 055: No corner towers on any Base

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**Requirement**: Martin, 2026-10-25, after his first Round on Map 03: "tie vysoke nerozbitne veze po rohoch bazy mozme dat prec, tie tam vobec nechcem. na ziadnej mape (the tall unbreakable towers at the Base corners can go, I do not want them at all, on no Map)".

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: No Base on any Map has a corner tower (Map 01's compound, so Map 01, Map 02 and Map 03's fortress).
- [x] AC-2: Each corner is closed by a low breakable corner Wall Panel (`wall_panel_corner.tscn`, 2.3 x 2 x 2.3 m), in the Base's structures and painted in its Team colour.
- [x] AC-3: The scenarios written before it play Map 01 as it was (`tools/evidence/frozen/map_01_story_054.tscn`) unless they declare `OPEN_BASES`.

---

## Implementation Notes

- `compound_base.tscn`: the four Tower nodes and their meshes and shapes gone, `Walls/Corners` with four corner panels; `color_meshes` and `structures` updated. `build_map_03.py` lists the fortress's corners.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `open_bases` O1; the regression.

**Status**: [x] Created 2026-10-25: `production/qa/evidence/story-058-maps-cleanup-evidence.md` (shared by stories 055 to 058)

---

## Dependencies

- Depends on: stories 053 and 054.
- Unlocks: none.
