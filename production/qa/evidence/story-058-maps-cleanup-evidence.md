# Stories 055 to 058 evidence: no towers, the turn ramp, the Flag to the Garage, round water and breakable buildings

> **Stories**: `production/epics/wasteland-fire/story-055-no-corner-towers.md`, `story-056-turn-ramp.md`, `story-057-flag-to-the-garage.md`, `story-058-maps-cleanup.md`
> **Type**: Logic + Visual/Feel (headless scenarios, windowed frames, previews)
> **Written**: 2026-10-25, in a cloud session (Linux, Godot 4.7.2 official build)
> **Sign-off**: [ ] Martin, on `WastelandFire-2026-10-25-cleanup.exe`

## Acceptance criteria, as measured

| AC | Result | Check |
|---|---|---|
| 055 no towers | PASS: both Bases of Map 01: 0 towers, 4 corner panels each, in structures, standing, in the Team colour | `open_bases` O1; frames, previews of all three Maps |
| 056 the ramp | PASS: a Buggy's first tick 0.433 rad/s (0.25 of 1.730), rising every tick, 1.730 from 0.5 s on; pressed again and the other way: 0.432 again; rolling at 17 m/s the first ticks of a steer 2.036 rad/s, the rolling rate | `turn_ramp` R1 to R3 |
| 057 to the Garage | PASS: Teal's Flag carried into Orange's fortress: no win; into Orange's Garage: Orange wins | `map_03` A4 |
| 058 water | PASS: Map 01's fords: rectangle hidden, a 40-point pool each; Map 03's fords cut by the shores, puddles round (frames, preview); Map 02's waters round (preview) | `open_bases` O3, frames |
| 058 buildings | PASS: Map 01's 10 wrecks and containers are Structures in neutral_structures, all fall to damage and stand again after R; Map 03's rocks are small buildings (preview) | `open_bases` O2 |

## Regression

All 114 scenarios. The runner plays Map 01 as story 054 left it (`tools/evidence/frozen/map_01_story_054.tscn`) for every scenario that names no `MAP_SCENE` and does not declare `OPEN_BASES`, and gives no turn ramp unless `TURN_RAMP` is declared: the first capture without the frozen Map failed 18 older scenarios that measure the towers, the old cover or the turn. Against story 054's capture only timings, stack line numbers, lint counts, Map 02's piece count (117 to 121: the four corner panels of each Base replace towers that were no pieces) and the renamed `map_03` A4 line differ.

## Frames

`martin-before-square-puddles.png` (Martin's screenshot of the square puddles), `map03-01..03` (`map_03_showcase`), `chase-2p-01-garage.png`, `chase-2p-02-driving-out.png` (Map 01's Bases without towers, from behind), `map01-preview.png`, `map02-preview.png`, `map03-preview.png`.

## Human checks

- [ ] Aiming standing feels better; a held steer is not too slow to start.
- [ ] The corners read as closed; nothing gets through.
