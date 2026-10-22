# Story 044 evidence: Secondaries recharge

> **Story**: `production/epics/wasteland-fire/story-044-secondaries-recharge.md`
> **Type**: Integration (headless scenario + windowed frames)
> **Written**: 2026-10-22, by `/dev-story` in a cloud session (Linux, Godot 4.7.2 official build)
> **Sign-off**: [ ] Martin, after playing `WastelandFire-2026-10-22-recharge.exe`

## Acceptance criteria, as measured (`secondary`, rewritten; an arena 400 m south of Map 01, the Flag at Map 01's Base 2)

| AC | Result | Check |
|---|---|---|
| AC-1 boost 15 s | PASS: 19.60 → 31.36 m/s; a press while it recharges does nothing; ready 15 s after the boost ends; bar 1.00 → 0.74 (draining) → 0.13 (filling) → 1.00 | X2 |
| AC-2 smoke ahead, 3 s, 15 s | PASS: the cloud 10.00 m ahead; a Turret 20 m ahead fired 3 Shots in the open, 0 while the cloud hung between them, 2 after it was gone; a press while recharging drops nothing, 15 s on one drops; a restart frees it | X3 |
| AC-3 Mines 15 s, unlimited | PASS: Mines on the field 0 → 1 (E) → 1 (E at once) → 2 (LT after the recharge); count stays 5 of 5; the Mines line hidden; bar 1.00 → 0.00 → 0.50 → 1.00 | X1 |
| AC-4 the Motorbike drops the Flag | PASS: no Flag, no bar and no drop; carrying, "Drop flag"; E: flag_dropped [1], DROPPED 1.70 m from the Motorbike, still lying there 0.5 s on with the Motorbike on it; picked up again once it had been away | X4 |
| AC-5 the bars | PASS: the names and values above | X1 to X4 |
| AC-6 Bushes, data | PASS: every Bush of Map 02 1.4 ×, sight radius 2.66 m; a Motorbike in a Bush drew no Shot from a Turret 15 m off, 1 Shot 8 m out of it; the data | X5, X6 |
| AC-7 the look | frames below | — |

`secondary` ran twice, byte-identical (`story-044-secondaries-recharge/secondary.txt`).

## Seeded defects

| Mutation | Caught by |
|---|---|
| The Mine ignores its recharge | X1 (0, 1, 2, 3) |
| The Motorbike may take back the Flag it dropped | X4 (CARRIED again) |

## Regression

Every scenario (104) was captured again. The runner gives every scenario that does not declare `SECONDARY` the Truck's count of Mines (no recharge), the Bushes of story 038 (size 1.0) and no FlagDroppers. Against story 043's capture only the frame-rate timings differ, a few lint counts that read files this story extended (`ammo_buildings` 63 → 82 numbers, all allowed; `fuel_building` 77 → 78 scripts; `tokens_data` lines), engine stack lines that name `match_controller.gd` line numbers, and `secondary`, rewritten for this story.

A first run of the drop showed the release rule too weak: a Motorbike teleported off the Flag was still reported touching it for a tick, so the rule now needs both 5 m and no touch before the Motorbike may take it back.

## Frames

`recharge_showcase`, windowed at 1280 x 720 (OpenGL compatibility on llvmpipe): `01-buggy-boost-bar-draining.png`, `02-gyrocopter-smoke-ahead.png` (the bar empty, the cloud ahead), `03-truck-mine-bar-filling.png`, `04-motorbike-drop-flag-bar.png` (yellow "Drop flag"), `05-motorbike-hidden-in-a-bush.png` (Player 1's Motorbike inside the bigger Bush, nothing of it showing; it dropped the Flag first).

## Human checks

1. Does 15 s feel right for all three, or should the Mine be slower?
2. Is the smoke 10 m ahead in the right place at the Gyrocopter's speed?
3. Is dropping the Flag useful (a decoy, a hand-over to another Motorbike)?
4. Can you hide in a Bush with the Motorbike as you imagined?
