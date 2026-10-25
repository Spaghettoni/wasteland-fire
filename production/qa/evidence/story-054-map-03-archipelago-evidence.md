# Stories 053 and 054 evidence: the Garage and the Flag fortress; Map 03, the islands

> **Stories**: `production/epics/wasteland-fire/story-053-garage-and-flag-fortress.md`, `story-054-map-03-archipelago.md`
> **Type**: Logic + Integration (headless scenarios, windowed frames)
> **Written**: 2026-10-25, in a cloud session (Linux, Godot 4.7.2 official build)
> **Sign-off**: [ ] Martin, after a Round on Map 03 (`WastelandFire-2026-10-25-map-03.exe`)

## Acceptance criteria, as measured

| AC | Result | Check |
|---|---|---|
| 054 AC-1 the Map | PASS: Garages at (-86, -76) and (86, -76); each Flag 158 m from its Garage, in its fortress; mirrored; Orange's Garage north-west, the Flag it goes for south-east | `map_03` A1 |
| 054 AC-2 the sea | PASS: a Buggy driven north from (-80, -96) for 4 s stops at z -112.8 (the shore); a Gyrocopter the same way flies on to z -118.8 (the Map's edge) | `map_03` A2 |
| 054 AC-3 a ford | PASS: a Buggy from (-54, -56) along the ford for 5 s ends at (-24, -26), on the middle island | `map_03` A3 |
| 054 AC-4 supply and cover | PASS: 8 supply zones, 18 cover pieces, 24 Bushes, 6 rocks, 16 fords and puddles | the builder's count, frames |
| 054 AC-5 map choice | PASS: three cards; Right from card 1 now goes to card 2 (Map 03) | `map_choice_check` K1, K2 (one run of six had K4 fail once, a Unit already chosen a second in; the next two and the run before the change passed) |
| 054 AC-6 the builder | PASS: `python3 tools/maps/build_map_03.py` writes the four files | — |
| 053 AC-1, AC-2 | PASS: a Motorbike with Teal's Flag in Orange's Garage zone: no win; in Orange's fortress: Orange wins; the Swap answers in the Garage, not in the fortress | `map_03` A4 |
| 053 AC-3, AC-4 | PASS: `mines`, `flag_open`, `teams` pass; Maps 01 and 02 unchanged | regression |

## Regression

All 112 scenarios (story 052's 111 and `map_03`). Against story 052's capture only timings, stack line numbers and two lint counts differ, and `tyre_tracks` ground_surfaces, which lists the scenes whose ground draws tracks: it now names Map 03's islands and ford beds (prefixes `Island`, `BedFord`) beside Map 02's Ground, and passes.

## Frames

`map03-layout-approved.png` (the layout Martin approved), `map03-00-preview.png` (the map choice's picture, rendered from above), and from `map_03_showcase`, windowed 1280 x 720, Forward+ on Vulkan: `map03-01-garages.png`, `map03-02-out-of-the-garages.png`, `map03-03-at-teal-fortress.png` (Orange's Buggy before Teal's Gate, its Turrets firing).

## Human checks

- [ ] The distances feel right (Garage to the Flag across the Map, 158 m to the own fortress).
- [ ] The Gyrocopter is not too strong here (it alone crosses the sea).
- [ ] The fords and puddles read as shallow water, the sea as deep.
