# Story 059: Map 03's fords reach the islands and slow only on the water

> **Epic**: Wasteland Fire — First Playable
> **Status**: Done
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-26

## Context

**Requirement**: Martin, 2026-10-26, with a picture of Map 03: "tie vodne cesty po obvode su obcas ustrihnute, nejdu celel az po ostrov. a co je este zvlastne, ze ta spomalovacia zona - tym ze vodne cesty idu pod ostrov - sa aktivuje este ked idem na ostrove. vieme to zarovnat tak aby sa aktivovali az ked vstupim realne na vodu?"

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: Every ford between islands runs on into each island until its whole end edge lies 1.5 m inside the shore, so no sea shows between a ford and a curved shore (the north and south channels and the sandbars included).
- [x] AC-2: A ford slows a ground Unit only over its water: its zone is seven strips across the ford, each between the shores and 0.5 m back from them. A Buggy on an island 2.5 m from the water, facing along the ford, is in no ford's zone; 3 m out on the water it is.
- [x] AC-3: The puddles on the islands keep their zone (a box inside the pool). The map choice's Map 03 picture shows the new fords.

---

## Implementation Notes

- `tools/maps/build_map_03.py`: `tucked_ford()`, `water_strips()` (the zone as several CollisionShape3D under one Ford Area3D), `inside()` / `on_land()` against the islands' outlines. `map_03.tscn` and `assets/art/ui/map_03_preview.png` regenerated.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `map_03` A5 (ten ford ends); `map_03` A3 (a Buggy still crosses a ford); the regression.

**Status**: [x] `production/qa/evidence/story-059-060-evidence.md`

---

## Dependencies

- Depends on: stories 054 and 058.
- Unlocks: none.
