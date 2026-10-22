# Story 041 evidence: Shots in two Heights

> **Story**: `production/epics/wasteland-fire/story-041-fire-in-two-heights.md`
> **Type**: Integration (headless scenario + windowed frames)
> **Written**: 2026-10-22, by `/dev-story` in a cloud session (Linux, Godot 4.7.2 official build)
> **Sign-off**: [ ] Martin, after playing `WastelandFire-2026-10-22-fire-heights.exe`

## Acceptance criteria, as measured (`fire_heights`, an arena 400 m south of Map 01, shipped data)

| AC | Result | Check |
|---|---|---|
| AC-1 low at ground, high at the Gyrocopter | PASS: a Buggy's low fire leaves a Gyrocopter at 70 of 70, its high fire takes it to 58; at a Truck the high fire does nothing and the low fire takes 36 | H1, H2 |
| AC-2 Turrets through both | PASS: a Turret 100 → 76 (low) → 52 (high) | H5 |
| AC-3 over low pieces, stopped by Tall ones | PASS: a high Shot passes over a Wall Panel (panel 40 of 40) and hits the Gyrocopter behind (70 → 58); the low fire stops at the panel (40 → 16) and the Truck behind keeps 220; a block on the map layer stops the high fire (Gyrocopter 70 → 70) | H3, H4 |
| AC-4 a Turret fires high at a Gyrocopter | PASS: 3 Shots over a Wall Panel at a Gyrocopter 20 m off (70 → 34), none at a Buggy behind the same panel | H5 |
| AC-5 inputs | PASS: Left Shift (H1), Right Shift and a pad's RB each fire high | H1, H6 |
| AC-6 the drawing | PASS: a high Shot's tracer at 2.9 m above its line, a low one's at 0 | H6 |
| AC-7 data, older outputs | PASS: masks 67 and 17, lift 2.9, the Shift keys with their locations; see the regression | H7 |

`fire_heights` ran twice, byte-identical (`story-041-fire-in-two-heights/fire_heights.txt`).

## Seeded defects

| Mutation | Caught by |
|---|---|
| The low mask keeps the gyrocopters (83) | H1, H7 |
| A Turret always fires low | H5 |

## Regression

Every older scenario (97, `bushes`, `cover_pieces`, `map_02`, `flag_open`, `pads_stick`) was captured again. The runner gives every scenario that does not declare `FIRE_HEIGHTS` the one mask of before (83), no tracer lift and no high fire actions. `map_02`, `flag_open` and `pads_stick` are byte-identical to their stored outputs. Against story 039's capture the rest differ only in the frame-rate timings, in two lint line counts that read files this story extended (`ammo` 243 → 249 lines of the Weapon, `tokens_data` 1529 → 1533 code lines; both pass), and in `bushes` and `cover_pieces`, whose numbers changed with Map 02's narrower floor the day before (their stored outputs of story 038 match). `loss` passed this time (its Jolt warning failure of the previous capture was the known flake).

## Frames

Windowed at 1280 x 720 under a virtual display, OpenGL compatibility renderer on llvmpipe. `01-high-fire-over-the-panel-at-the-gyrocopter.png`: Player 1's Buggy firing high, the Wall Panel in front of it whole, Player 2's Gyrocopter hit (64 of 70 in its HUD). `02-low-fire-into-the-panel.png`: the same Buggy firing low, the panel cracked with chunks at its foot. The tracers themselves are small and pale yellow and barely show on the salt flat from above; story 030's glowing tracers would make them readable.

## Human checks

1. Does a Buggy under a Gyrocopter need Shift / RB to hit it, and does it feel right?
2. Can you shoot a Gyrocopter over a wall, and does a Turret now get you over a wall when you fly?
3. Is the Gyrocopter still worth flying now that it is no longer hit by the low fire?
