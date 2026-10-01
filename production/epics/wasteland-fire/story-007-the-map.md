# Story 007: Map 01

> **Epic**: Wasteland Fire — First Playable
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: L (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-01

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 7 — *Map 01: a small bounded Map built from Godot's built-in meshes with code-generated textures, laid out from the author's drawing of Map 01 (offered 2026-10-01) if it is under `design/source/`; Base A and Base B with their Garages; cliffs and water that only the Gyrocopter crosses; the Fuel Can spots; the Team colours Orange (Player 1, Base A) and Teal (Player 2, Base B) applied to Bases, Units and UI, replacing today's blue and red.*

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (the **Player goal & fail state** field + the MVP feature this story implements), scoped to this story:*

- [ ] AC-1: Map 01 replaces the greybox field: one small, bounded Map laid out in this story, from the author's drawing of Map 01 (offered 2026-10-01; `design/rules.md`, First Playable) if it is under `design/source/`, with Base A (Orange, Player 1) and Base B (Teal, Player 2) and their Garages, the Fuel Can spots, and cliffs and water.
- [ ] AC-2: The cliffs and the water stop every ground Unit and the Gyrocopter crosses both (the collision layers of story 005), checked with each of the four Units at a cliff and at the water.
- [ ] AC-3: The ground, the cliffs, the water, the Bases, the Flags, the Fuel Cans and the four Units are built from Godot's built-in meshes (`BoxMesh`, `CylinderMesh`, `PrismMesh`, `SphereMesh` and the like) with textures generated in code, in one flat-shaded low-poly palette; no downloaded or imported asset kit or mesh is used (`design/rules.md`, Teams and visual style).
- [ ] AC-4: Every model, Base and UI element is in the Team colour of the Player who owns it (Orange for Player 1 and Base A, Teal for Player 2 and Base B) and no model mixes the two; the blue and red of stories 002 to 004 are replaced here as data (materials and theme colours), with no change to game logic.
- [ ] AC-5: Both Bases, both Flags and the Fuel Cans are readable at a glance from either viewport.
- [ ] AC-6: Map 01 is a scene: its Bases, Garages (each Base's `SpawnPoint`), Fuel Can spots and Token stock are data in it, not constants in code (the stock holds the source's example, Motorbike 5, Buggy 3, Truck 2, Gyrocopter 2, which story 008 reads); replacing the Map scene needs no script change.
- [ ] AC-7: Holds 60 fps with two viewports and Map 01 at 1280 x 720.
- [ ] AC-8: The look is judged coherent by a human against the concept art (the Discord channel #wasteland-fire; the concept sheet `assets/art/vehicles/vehicle-design.png`) and recorded in the evidence doc, with a frame from each viewport.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers into the pinned engine reference, not decisions:*

- The Map contract (story 004's Completion Notes): a Map exposes its two Bases as `player_1_base` and `player_2_base`, and each Base brings `canister`, `canister_seat`, `zone` and its spawn points; `SplitScreen.field` is typed `GreyboxField`, so Map 01 keeps that class or `SplitScreen` retypes one export.
- TD-005 is paid here: delete the loose `PlayerStart` and `Player2Start` markers and point each Base at its own `SpawnPoint` child. The Story 001 drive harness writes `player_start.transform` as a field-space position, so it changes with them (`tools/evidence/drive_harness.gd`; TD-001 asks to split that harness before its next scenario).
- Collision layers (`project.godot`): 1 map (the ground), 2 units, 3 zones, 4 canisters (the Flags, renamed in story 008), and the Gyrocopter's and the cliff and water layers story 005 added; the cliffs and the water sit on theirs, so ground Units collide with them and the Gyrocopter passes.
- Slopes (TD-002): the Unit's box collider climbs ramps up to 30 degrees and stops dead at the foot of 35 degrees and up; add a slope scenario before any Map 01 slope exceeds 30 degrees, or swap in a chamfered collider.
- The concept models under `assets/art/` (`kitbash.gd`, `procedural_textures.gd`, `wasteland_palette.gd` and the four models matched to the concept sheet) are already built from built-in meshes with code textures. They paint every model teal and orange together, which v0.1 replaces with one Team colour per model, and each is 90 to about 200 `MeshInstance3D` nodes, too many draw calls for a game Unit by their own readmes: merge each into one mesh per material before it goes into play. `assets/` is the user's folder: ask before moving or editing anything in it.
- "Colours are not mixed within a model" is read here as: no model wears both Team colours, and neutral parts (rust, rubber, bone, lamps, the Motorbike's cream nose that shows its heading) stay. Confirm the reading with the author before the recolour.
- The Buggy's pennant on the concept sheet could read as a carried Flag: keep the Flag's look unlike any decoration. The Flag's look is built here, in the scene that holds it (`water_canister.tscn` until story 008 renames it).
- `ChaseCamera` has no collision: check in both views that no cliff comes between a Player and their Unit. The turning chase camera itself stays (decided 2026-10-01).
- Performance: the draw-call budget is 1,000 per frame for both views together (`.claude/docs/technical-preferences.md`, provisional; story 004 measured at most 114). `docs/engine-reference/godot/modules/rendering.md` § 4.7 Changes: nearest-neighbour 3D scaling (`Viewport.SCALING_3D_MODE_NEAREST`) suits a low-poly look and cuts the cost of each view if 60 fps slips; `AreaLight3D` adds GPU cost to every object in a frustum that holds one: avoid it.
- Evidence frames: the run-and-observe capture (`--write-movie`) from both viewports; wake the display first (TD-009).
- Process (`design/rules.md`, Process rules, decided 2026-10-01): a short plan before the change; after it, say how to test it (the main scene `src/gameplay/split_screen/split_screen.tscn` and the keys to drive each Unit to a cliff and the water); the tracked class cache is written by the import only, never by hand.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- A second Map, a map editor, destructible buildings: out of scope in the brief.
- Music and sound: not in the First Playable.
- Story 008: what the Token stock does; this story only holds its counts as data.
- The camera and control test, and the arrow to the own Base or the north-up minimap it may call for: after v0.1 (decided 2026-10-01).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Visual/Feel
**Required evidence**:
- Retained screenshots of Map 01 from each viewport, with both Team colours and all four Units in view across the set, in `production/qa/evidence/story-007-the-map/`, plus sign-off in `production/qa/evidence/story-007-the-map-evidence.md` recording the coherence judgement (AC-8), the Team colour check (AC-4) and the 60 fps check (AC-7).
- Tests: waived at `qa.level: minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 must be DONE
- Input: the author's drawing of Map 01 (offered 2026-10-01), under `design/source/` once it arrives (AC-1). If it is still missing when story 006 closes, ask the author whether to wait for it or to lay the Map out without it; story 008 may run first meanwhile (its Dependencies allow it).
- Unlocks: Story 008
