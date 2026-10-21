# Story 038: Map 02, a map choice before the match, and the Bushes, wrecks and small buildings

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L (a new Map, a new mechanic, a new launch screen)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-21

## Context

**GDD**: `design/game-brief.md`, `design/rules.md` ("Heights"; "Turrets, Flag Walls and Mines"); `CONTEXT.md` (Map, Base, Turret, Wall Panel, Cover)
**Requirement**: Martin's request of 2026-10-21, made in a session: "vies spravit novu verziu mapy, co som s Tebou naposledy riesil, ze ju das do produkcie?" (can you take the new version of the map I last worked on with you and put it into production?). The map is Map 02, the schematic Martin drew and Claude drew up on 2026-10-16 in the artifact's section "Map 02" (`design/source/wasteland-fire-map-02-2026-10-16.svg`, archived with this story), with Martin's one correction of that day ("garaz mala byt vlavo", the Garage should be on the left of the Flag). His three answers of 2026-10-21:

1. How Map 02 gets into the game: **a map choice before the match**; both Maps stay playable.
2. The Bushes, car wrecks and small buildings of the left corridor: **all of them, the Bushes included** (the board's Bushes card of 2026-10-07, `design/source/wasteland-fire-board-2026-10-07.en.md`).
3. The Tokens on Map 02: **the same as Map 01** (`token_stock.tres`).

The schematic, in metres, x across (0 to 160) and z down (0 to 290), mirror-symmetric about z = 145:

- An impassable canyon round the edge; the floor inside is the rectangle 20..140 x 20..270 with corners rounded at 50 m.
- Each Base at the top (Orange, Player 1) and the bottom (Teal, Player 2), with its Garage left (west) of the Flag.
- A wall right across each half (z = 76 and 214) from the west edge to the ridge, with a gap between two Turrets of that half's Team at x = 44 and 56 (built 2.5 m in front of the wall's line, toward the other half: on the line the wall's own end panel cut the west Turret's sight, measured by the `bushes` scenario's first run).
- A rock ridge (x about 101..121, z 50..136 and 154..240) that only the Gyrocopter crosses, with a destructible wall in its gap (x 103..108, z 136..154); east of it a passage with water at both ends (z 80..98 and 192..210) that slows the Units.
- One Fuel building, shared, on the west side (z = 145) with its zone east of it; an ammunition building in each half (x 88..100, z 96..104 and 186..194) with its zone west of it.
- In the left corridor, mirrored: 4 Bushes, 3 car wrecks and 2 small buildings per half, and one Bush and one wreck in the middle. The wrecks and the buildings are cover that can be destroyed; a Buggy or a Truck flattens a Bush.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

- [x] AC-1: The game opens on a map choice: Map 01 and Map 02 side by side, each with a picture of it from above. Either Player chooses on the keyboard (A / D or Left / Right, then Space, Period or Enter) or on any pad (stick or D-pad, then A). The chosen Map is played as today; the restart (R / Menu) replays the same Map.
- [x] AC-2: Map 02 is a scene of its own (`src/gameplay/maps/map_02/map_02.tscn`) whose root is a MapField, built by a script from the schematic (`tools/maps/build_map_02.py`) and never edited by hand; the shipped launch scene and every older evidence scenario still play Map 01 unchanged.
- [x] AC-3: Map 02's layout follows the schematic within 2 m: the canyon stops every Unit, the Gyrocopter included; the ridge stops ground Units and lets the Gyrocopter over; the water slows ground Units as Map 01's fords do; the walls across the field and in the ridge's gap are Wall Panels of no Player.
- [x] AC-4: Each Base is Map 01's compound Base, turned so its Gate faces east and its Garage lies west of its Flag; both Units start and respawn there, and a Flag carried home wins as on Map 01.
- [x] AC-5: The two Turrets at each wall's gap are that half's Team's: they fire only at the other Player's Unit, take no damage from their own Player's Shots and are restored at every restart, like a Base's Turrets. They do not lock the Flag (only a Base's own Turrets do).
- [x] AC-6: A Bush hides a ground Unit behind it from a Turret, stops no Shot and no Unit; a Buggy or a Truck that drives into it flattens it (it no longer hides anything) until the restart; a Motorbike passes and leaves it standing; the Gyrocopter is never hidden by it.
- [x] AC-7: A car wreck and a small building stop Units and Shots, take damage from both Players' Shots (the Motorbike's too), show two damaged looks and fall into low rubble at 0 hit points; the restart stands them again.
- [x] AC-8: Every value is data: the Map's layout in the build script's tables, the Bush's and the wrecks' numbers in resources, which types flatten a Bush in the Unit stats.
- [x] AC-9: The Fuel building and the two ammunition buildings refuel and rearm as on Map 01, and no Mine can be laid in their zones.

---

## Implementation Notes

- The Map choice is a new launch scene (`src/ui/map_choice/map_choice.tscn`) that instances `split_screen.tscn` and, before it enters the tree, puts the chosen Map in place of its Map 01 (`SplitScreen.use_map()`), the way the evidence runner puts its greybox field there. `run/main_scene` points at the choice; the evidence runner keeps instancing `split_screen.tscn`.
- Outposts: `MapField.player_1_outposts` / `player_2_outposts` list Structures of a Player that stand outside the Base (the field Turrets). SplitScreen gives them their Player, arms their Turrets and restores them with the Base's pieces; FlagRules still reads only the Base's own list.
- Bushes: `Bush` (Area3D trigger for units, a sight-only body on the new physics layer 8 "sight"); `TurretStats.sight_extra_mask` gains layer 8 for ground targets; `UnitStats.crushes_bushes` (Buggy, Truck). `MapField.bushes` lists them for the restart.
- Wrecks and small buildings: two Structure scenes with their own `StructureStats` (type ids `wreck` and `shack`, absent from the damage matrix, so every Shot counts 1.0), written by `tools/maps/build_cover_pieces.py`.
- Map 02 is written by `tools/maps/build_map_02.py` from tables in the schematic's numbers; the canyon is drawn rock (CSG, no collider) with a ring of edge boxes on the map layer in the `map_edge` group at its foot, so a Gyrocopter is stopped there and never crashed; the floor's tyre tracks have their own settings.
- The map choice starts the match on the release of the confirm key, not its press: Space and Period are also the Players' fire and confirm keys, and a press would confirm Player 1's Unit in the match's first tick (the `map_choice` check K4).
- Evidence runner: a scenario declares `MAP_SCENE` to play Map 02; `BUSHES` and `MAP_CHOICE` keep the shipped sight layer and menu actions, which every older scenario runs without.

---

## Out of Scope

- Tyre tracks look and the ground's art beyond Map 01's materials (Map 02 reuses Map 01's materials).
- Going back from a Round to the map choice without restarting the game.
- Changes to Map 01.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `production/qa/evidence/story-038-map-02-and-map-choice-evidence.md` with the scenarios' outputs, frames of the map choice and of Map 02 from above, and Martin's checks in the game.

**Status**: [x] Created 2026-10-21: `production/qa/evidence/story-038-map-02-and-map-choice-evidence.md`, nine frames and the outputs of `map_02`, `bushes`, `cover_pieces` and `map_choice`

---

## Dependencies

- Depends on: None.
- Unlocks: None.
