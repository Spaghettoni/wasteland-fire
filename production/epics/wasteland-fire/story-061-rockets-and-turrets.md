# Story 061: Red rockets up high, and more Turrets on Map 03

> **Epic**: Wasteland Fire — First Playable
> **Status**: Done
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-26

## Context

**Requirement**: Martin, 2026-10-26: "Rad by som spravil odlisenie medzi strielanim hore a dole. Dole budu tie zlte strely co mame. Hore budu cervene raketky. Veze budu mat len ten zlty typ. Tiez na najnovsej mape - pacia sa mi tie 2 veze pri brane, no dal by som po 1 vezi na kazdu dalsiu stranu stvorca. Cize +3 okolo pevnosti. A este +1 ku garazi."

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: A Unit's high Shot is drawn as a red rocket (body, dark nose, fins, a flame and a short trail), at the high Shots' height; its low Shot stays the yellow tracer. Only the look changes: damage, speed, range and what stops it are as before.
- [x] AC-2: A Turret's Shots, high ones included, stay the yellow tracer.
- [x] AC-3: On Map 03 each fortress has, besides its 2 Turrets at the Gate, 1 Turret outside each of its other three walls, and each Garage 1 Turret beside it: 6 per Team, all armed at the other Team, in the Team's colour, restored at a restart.

---

## Implementation Notes

- `src/gameplay/combat/shot_rocket.tscn` (shot.gd with a rocket as its tracer); `Weapon.high_shot_scene`, set on both Weapons of `split_screen.tscn` (Players 3 and 4 copy Player 2's). `turret.tscn` keeps `shot.tscn`.
- `tools/maps/build_map_03.py`: `FORTRESS_TURRETS`, `GARAGE_TURRETS`, listed in the Garage Base's `structures` and `color_meshes`. `map_03.tscn`, `flag_fortress.tscn`, `garage_base.tscn` and the preview regenerated.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `fire_heights` H8; `map_03` A6; `rockets_showcase` frames; the regression.

**Status**: [x] `production/qa/evidence/story-061-evidence.md`

---

## Dependencies

- Depends on: stories 041 (two Heights), 053, 054.
- Unlocks: none.
