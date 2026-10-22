# Story 042 evidence: Secondary weapons on LT

> **Story**: `production/epics/wasteland-fire/story-042-secondary-weapons.md`
> **Type**: Integration (headless scenario + windowed frames)
> **Written**: 2026-10-22, by `/dev-story` in a cloud session (Linux, Godot 4.7.2 official build)
> **Sign-off**: [ ] Martin, after playing `WastelandFire-2026-10-22-secondary-flag.exe`

## Acceptance criteria, as measured (`secondary`, an arena 400 m south of Map 01, shipped data)

| AC | Result | Check |
|---|---|---|
| AC-1 the key; the Truck | PASS: Mines 5 → 4 (E) → 3 (a pad's LT); LT fired no Shot; LT is bound only to `lay_mine`, X to nothing | X1, X5 |
| AC-2 the nitro | PASS: Buggy top speed 19.60 m/s, 31.36 with the nitro (1.6 ×), 19.60 after; a press while cooling does nothing; ready again after the cooldown | X2 |
| AC-3 the smoke screen | PASS: a Turret 20 m off fired 3 Shots at the Gyrocopter in the open, 0 while the cloud hung, 5 after it was gone; 2 → 1 → 0 → 0 left; the restart freed the cloud still hanging | X3 |
| AC-4 the Motorbike | PASS: 24.00 → 24.00 m/s on the key, no line | X2 |
| AC-5 the HUD line | PASS: "Nitro ready", "Nitro!", "Nitro in 7 s" (its seconds left rounded up), "Smoke 2 / 2"; hidden for the Truck and the Motorbike | X1, X2, X3 |
| AC-6 data, older outputs | PASS: 2 s × 1.6, 8 s; 2 screens of 12 m, 6 s; Turret sight 416 / 256; see the regression | X5 |
| AC-7 the look | frames below | — |

`secondary` ran twice, byte-identical (`story-042-secondary-weapons/secondary.txt`). A ground Unit in a cloud is hidden through the same mask (416 holds the smoke layer 256); the scenario measures the Gyrocopter.

## Seeded defects

| Mutation | Caught by |
|---|---|
| The Turret's sight drops the smoke layer (160 / 0) | X3 (5 Shots while the cloud hung), X5 |
| The nitro never calls `boost_speed()` | X2 |

## Regression

Every older scenario (102) was captured again with `secondary` and `real_flag`. The runner gives a scenario that does not declare `SECONDARY` no nitro, smoke or status nodes, the Turret sight masks without the smoke bit, and, for a `STICK_DRIVE` scenario, the frozen pad layout of story 041 (LT fires). Against story 041's capture only the frame-rate timings differ, the `tokens_data` lint counts (18 → 19 files, 1533 → 1555 code lines; passes), and `mines`, whose README check wants the row "Lay a Mine (Truck) | E | Comma": the row stays and the nitro and smoke get a row of their own. The flag scenarios are byte-identical with story 043's new Flag.

## Frames

Windowed at 1280 x 720 under a virtual display, OpenGL compatibility renderer on llvmpipe (`secondary_flag_showcase`). `01-buggy-on-its-nitro.png`: Player 1's Buggy on its nitro, "Nitro!" under its HUD. `02-gyrocopter-in-its-smoke-screen.png`: Player 1's Gyrocopter inside its cloud, nothing of it showing, "Smoke 1 / 2"; the cloud is drawn opaque until its fade (a first take at 0.9 opacity let the Gyrocopter show through, so it went to 1.0).

## Human checks

1. Is 2 s of nitro at 1.6 × with 8 s to recharge fun, or too strong / too weak?
2. Is a 12 m cloud for 6 s the right size and time? Is 2 per Gyrocopter enough?
3. LT is no longer fire on the pad: does it feel right to have fire on RT / A / RB only?
