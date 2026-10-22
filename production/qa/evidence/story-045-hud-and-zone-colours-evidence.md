# Story 045 evidence: The secondary bar in the Tokens line's place, zone colours

> **Story**: `production/epics/wasteland-fire/story-045-hud-and-zone-colours.md`
> **Type**: UI (headless checks + windowed frames)
> **Written**: 2026-10-22, by `/dev-story` in a cloud session (Linux, Godot 4.7.2 official build)
> **Sign-off**: [ ] Martin, after playing `WastelandFire-2026-10-22-hud-zones.exe`

## Acceptance criteria, as measured

| AC | Result | Check |
|---|---|---|
| AC-1 no Tokens line, the bar in its place | PASS: the Tokens line shown false in both HUDs; the bar at y 47, the band's second row | `secondary` X6, frames |
| AC-2 "Drop flag" without a bar | PASS: name "Drop flag", no bar drawn | `secondary` X4, frame 04 |
| AC-3 boost white on grey | frames 01 and 05 (a dark edge added after frame 05 showed a full white bar vanishing on the salt flat) | frames |
| AC-4 zone colours | PASS: Map 01's Fuel zone #f5b32e = the fuel bar, its ammunition zone #3d8bff = the ammo bar, both unshaded | `secondary` X6, frame 06 |
| AC-5 older outputs | PASS: see the regression | — |

## Regression

All 104 scenarios captured again. Against story 044's capture only frame-rate timings, the `tokens_data` lint line count (1626 → 1640, passes) and `secondary` (its extended X4 and X6) differ. One run of `ammo_buildings` during the editor's import logged an extra warning; run again it passed, as it did in the regression.

## The export

A pack probe of the exported game (`--export-pack`, then `--main-pack` with a probe script) found the ammunition zone amber: `ammo_building.tscn` overrode its zone's Slab mesh without marking the instance editable, so the export dropped the override (the pitfall `tools/maps/readme.md` records). In every earlier build the ammunition zones were therefore drawn amber like the Fuel zones, never the pale yellow the evidence runs saw. `[editable path="AmmoZone"]` fixes it: the probe then reads #3d8bff, unshaded. `ammo_buildings` and `secondary` give the same output with it (one parallel run of `ammo_buildings` hit the known Jolt job-system warning; alone it matched).

## Frames

`recharge_showcase`, windowed 1280 x 720: `01-buggy-boost-bar-draining.png` (white on grey), `02-gyrocopter-smoke-ahead.png`, `03-truck-mine-bar-filling.png`, `04-motorbike-drop-flag-bar.png` (the name alone), `05-motorbike-hidden-in-a-bush.png`, `06-ammo-zone-blue-fuel-zone-amber.png`.
