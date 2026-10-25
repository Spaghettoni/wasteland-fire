# Story 051 evidence: The HUD in one row, with icons

> **Story**: `production/epics/wasteland-fire/story-051-one-row-hud.md`
> **Type**: UI (windowed frames, headless checks)
> **Written**: 2026-10-25, in a cloud session (Linux, Godot 4.7.2 official build)
> **Sign-off**: [ ] Martin, on `WastelandFire-2026-10-25-hud-teams.exe`

## Acceptance criteria, as measured

| AC | Result | Check |
|---|---|---|
| AC-1 one row | PASS: Flag icon (16, 12: 28 x 28), hit-point bar (54, 17: 130 x 18), Fuel icon (194) and bar (224: 90), ammunition icon (324) and bar (354: 90), secondary icon and bar (458 to 624); every element on the row, none overlapping, none past the view; the Team edge round the row | `resource_bars` R3, `secondary` X6 (the bar at y 12), frames |
| AC-2 no number | PASS: no visible text in the row | `resource_bars` R3 (row labels none) |
| AC-3 Flag icon | PASS: both at home: `flag_home_icon`; Player 1 takes Player 2's Flag: Player 1 `flag_carrying_icon` ("You carry the enemy Flag"), Player 2 `flag_away_icon` ("Your Flag is away") | `hud_showcase` S1, frames |
| AC-4 secondary icons | PASS: flame (Buggy), Mine (Truck), cloud (Gyrocopter), drop flag (Motorbike carrying) | frames |
| AC-5 earlier scenarios | PASS: two layout expectations updated (`resource_bars` R3 row labels none; `secondary` X6 bar row y 12); the rest as before | regression |

## Regression

All 111 scenarios (story 050's 110 and `teams_last_carrier` of story 052), on the tree of both stories. Against story 050's capture only frame-rate timings, stack line numbers, the lint count of `tokens_data` and the two updated layout lines differ.

## Frames

Windowed 1280 x 720, Forward+ on Vulkan: `hud-01-flags-home.png`, `hud-02-flag-taken.png` (`hud_showcase`, two Players, the view from above), `chase-4p-01-garage.png`, `chase-4p-02-driving-out.png` (`chase_showcase`, four Players: Boost, Mine, Smoke icons).

## Human checks

- [ ] The icons read at a glance on a TV at couch distance (they are 28 px).
