# Story 036 evidence: slower Fuel and the resource bars

> **Story**: `production/epics/wasteland-fire/story-036-slower-fuel-and-resource-bars.md`
> **Type**: UI
> **Written**: 2026-10-19, by `/dev-story` in a cloud session (Linux, Godot 4.7.2)
> **Sign-off**: [ ] pending — Martin's play of `WastelandFire-2026-10-19-fuel-bars.exe` is for `/story-done`

## Measured (`scenario-outputs/resource_bars.txt`, two runs byte-identical)

| AC | Result |
|---|---|
| AC-1 Fuel burns at half the old rate | PASS: every rate is half the old (Motorbike 1.0 / 0.25, Buggy 1.25 / 0.3125, Truck 1.5 / 0.375, Gyrocopter 2.5 / 0.625); 600 ticks on W burned 9.987 Fuel (10.0 at the new rate, 20.0 at the old), 600 ticks standing 4.0; a full tank lasts a Motorbike 100 s of driving, was 50 s. Built first at a third; Martin found it too slow and chose half (2026-10-19), and kept the lavender ammo colour |
| AC-2 two bars side by side | PASS: in both views HitPointsBar (16,16 300x24), FuelIcon (332,14 28x28), FuelBar (362,16 112x24), AmmoIcon (482,14 28x28), AmmoBar (512,16 112x24), on one row, in order, inside 640 px; the bars follow the Unit's Fuel and the Weapon's Shots, and Space lowered only Player 1's ammo bar (100 -> 97) |
| AC-3 no text, no Ammo line | PASS: no Fuel line, the only Label on the row is the hit points' line, no AmmoCount in either view; capacity 0 hides the ammo bar and its icon |
| AC-4 own icons, readable | PASS: `assets/art/ui/fuel_icon.svg` (a jerrycan) and `ammo_icon.svg` (three cartridges), drawn for the story; ammo colour #b98cff against #66d161 (HP), #f5b32e (Fuel), #e67324 and #2e9994 (Team edges); frames below |
| AC-5 data | PASS: rates in the four stats files, colours and sizes in `player_hud.tscn` |
| AC-6 older outputs | PASS with explained differences (below) |

## Frames (`story-036-slower-fuel-and-resource-bars/`, OpenGL compatibility renderer under Xvfb)

- `01-both-full.png` — both bands full.
- `02-player-1-after-driving-and-firing.png` — Player 1's Fuel and ammo bars lower, Player 2's full.
- `03-player-1-empty-gun-staged.png` — Player 1's ammo bar empty with its icon (staged: the Weapon announces 0 Shots of its load).

## Regression (AC-6)

All 89 scenarios on `main` at b1f9ee1 and again on the story's tree, headless: 87 pass on both (the windowed-only `camera_smooth` and one fps scenario fail headless on both). Differences after removing the Jolt load warning and the harness's line numbers: only the `*_fps` timings (measured time), `tokens_data`'s count of the HUD script's code lines (1469 -> 1484, still 5 literals, passes), and `token_ui`'s engine-warning count (the Jolt warning on the old run). No position, count or verdict changed.

## Human checks (for `/story-done`)

1. Do the two bars read at a glance, with the icons, in both views?
2. Does a tank now last long enough at half the old burn?
3. Lavender ammo colour: kept by Martin, 2026-10-19.
