# Story 054: Map 03, the islands

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**Requirement**: Martin, 2026-10-25: a set of varied Maps as in Return Fire, made by a builder so more can follow ("mechanizmus na genericke generovanie map"), each with ammunition and Fuel, puddles, Bushes and wrecks, one with the sea instead of a canyon; first "ostrovna mapa", Garage in one corner and the Flag to take in the opposite ("garaz bude v 1 rohu a vlajka co sa snazis ukradnut bude v protilahlom"). The layout: `design/source/wasteland-fire-map-03-2026-10-25.svg`, approved the same day ("Skusme to spravit").

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM (a new Map, CSG collision for the sea)

---

## Acceptance Criteria

- [x] AC-1: Map 03 loads and plays: each Player starts in its Garage in its north corner; each Team's Flag stands in its fortress in its south corner, over 100 m away (158 m); Teal's pieces mirror Orange's; the Flag a Team goes for is in the corner opposite its Garage.
- [x] AC-2: The sea stops a ground Unit at the shore; the Gyrocopter flies over it.
- [x] AC-3: The fords join the islands: a Buggy drives from the Garage island to the middle.
- [x] AC-4: Every island has supply: Fuel and ammunition by each Garage, ammunition by each fortress, two Fuel buildings in the middle; and cover: rocks, Bushes, wrecks, small buildings, puddles.
- [x] AC-5: The map choice shows a third card, Map 03, with its picture.
- [x] AC-6: The Map is written by `tools/maps/build_map_03.py` from tables at its top; the scenes are never edited by hand.

---

## Implementation Notes

- `garage_base.tscn` (the Base: spawn spots, Garage, Marking, a zone, a mast) and `flag_fortress.tscn` (walls, Gate, Turrets, water tower, Flag Walls, Flag, its zone as `FlagZone`) are cut by the script from Map 01's `compound_base.tscn`. The Map's Garage instance points `flag`, `flag_seat`, `flag_zone`, `color_meshes` and `structures` at its Team's fortress.
- The sea: a visual plane and an invisible 0.4 m slab on the cliffs_water layer (a `CSGCombiner3D` with the islands and fords cut out), lower than the shooting height so Shots and sight cross water. The Map's edge stops even the Gyrocopter at 120 m.
- Fords and puddles are Map 01's `ford.tscn`, sized and turned.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `map_03` A1–A4; `map_choice_check` with three cards; frames `production/qa/evidence/story-054-map-03-archipelago/`; the regression; Martin's Round on Map 03.

**Status**: [x] Created 2026-10-25: `production/qa/evidence/story-054-map-03-archipelago-evidence.md`

---

## Dependencies

- Depends on: story 053, story 038 (the map choice, Map 02's builder).
- Unlocks: Maps 04 to 06 on the same builder.
