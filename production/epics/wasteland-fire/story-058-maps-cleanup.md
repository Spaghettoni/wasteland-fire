# Story 058: Round water and breakable buildings on every Map

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**Requirement**: Martin, 2026-10-25, after his first Round on Map 03: "aby vodne mladky neboli hranate, bud maju byt orezane hranou ostrova, alebo ked su ako ojedinele, tak zaoblenych tvarov. v strede ostrova su nerozbitne budovy, tie tiez nechcem. ked tak, tak rozbitne. pre vsetky mapy co mame; his answer to the question which: Map 03's rocks and Map 01's wrecks and containers, not the Fuel tanks".

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: Map 03's fords between islands are cut by the islands' shores (their water lies under the islands' sand); its puddles are round pools with an uneven edge.
- [x] AC-2: Map 01's two fords and Map 02's two waters are drawn as round pools; their slowing areas stay.
- [x] AC-3: Map 03's rocks are breakable small buildings.
- [x] AC-4: Map 01's eight wrecks and two containers are breakable Structures, listed in the Map's neutral_structures, restored at a restart.
- [x] AC-5: The Fuel buildings stay unbreakable.

---

## Implementation Notes

- `tools/maps/shapes.py` (`pool_outline()`); `build_map_02.py`, `build_map_03.py`; `build_cover_pieces.py` writes `container.tscn`; `map_01_cover.tscn` instances `wreck.tscn` and `container.tscn`; `map_01.tscn` hides its fords' water and draws two pools.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `open_bases` O2, O3; frames; the regression.

**Status**: [x] Created 2026-10-25: `production/qa/evidence/story-058-maps-cleanup-evidence.md` (shared by stories 055 to 058)

---

## Dependencies

- Depends on: stories 053 and 054.
- Unlocks: none.
