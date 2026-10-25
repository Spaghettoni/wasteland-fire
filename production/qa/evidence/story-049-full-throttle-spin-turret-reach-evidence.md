# Story 049 evidence: Full throttle on a leaned stick, a faster spot turn, a longer Turret reach

> **Story**: `production/epics/wasteland-fire/story-049-full-throttle-spin-turret-reach.md`
> **Type**: Integration (headless scenarios, one windowed frame)
> **Written**: 2026-10-25, in a cloud session (Linux, Godot 4.7.2 official build)
> **Sign-off**: [ ] Martin, with a pad on Windows (`WastelandFire-2026-10-25-full-throttle.exe`)

## Acceptance criteria, as measured

| AC | Result | Check |
|---|---|---|
| AC-1 full throttle on a pad | PASS: after 20 ticks from standing a Motorbike reads 6.667 m/s with the stick straight up, half up, at 0.45 and leaned up and left at 45 degrees, the same as W; at 0.35 it does not move | `full_throttle` T1 |
| AC-1 still a spot turn | PASS: stick fully left with 0.30 up turns the standing Motorbike at 2.100 rad/s (its spot_turn_rate) and it rolls 0.000 m | `full_throttle` T2 |
| AC-2 spot turn 1.5 times | PASS: spot / turn rates 2.10/2.80, 1.73/2.29, 0.67/0.89, 1.16/1.53 (three quarters each); `spot_turn` measures every type pivoting, driving off and reversing at the new rates; empty-tank rates unchanged | `full_throttle` T3, `spot_turn` |
| AC-3 Turret reach 45 m | PASS: the Turret reaches 46.6 m to a target's centre, the Truck 43.8 m to the Turret's centre (Buggy 38.0, Gyrocopter 37.6, Motorbike 27.6); a Unit 44.85 m from the aimed muzzle is fired on and hit, one at 45.15 m never; a Truck 43.3 m out, where its own Shots just reach the drum, hits the Turret and draws its Shot | `full_throttle` T3, `turrets` reach and damage |
| AC-4 nothing else changed | PASS: see the regression | — |

## Regression

All 109 scenarios (the 108 of story 048 and `full_throttle`). The runner gives every scenario that does not declare `FULL_THROTTLE` the drive and numbers of before (partial throttle, the 0.2 dead zone on every pad action, the old spot turn rates, the Turret's 35 m), because many older scenarios drive at a partial throttle on purpose (a Truck crawling through a supply zone, a Gyrocopter pressed to a crash speed): the first capture without it failed 7 that passed before (`ammo_buildings`, `crash`, `fuel_building`, `pads`, `rotors`, `tyre_tracks`, `tyre_tracks_showcase`) and one more check of `tyre_tracks_fps`. `turrets`, `spot_turn`, `pads_stick` declare it. Against story 048's capture only frame-rate timings, stack line numbers and the lines these numbers show differ (`pads_stick` half up 0.167 from the throttle's 0.4 dead zone; `spot_turn` the new rates; `turrets` and `turret_looks` the reach check at 30 degrees; `teams`, `teams_three` lose two warnings fixed on the merge with story 027 after that capture).

Retained here: `full_throttle.txt`, `pads_stick.txt`, `spot_turn.txt`, `turrets.txt`, and `pads.txt`, `crash.txt`, `fuel_building.txt`, `ammo_buildings.txt` (the ones that failed without the opt-out, now as before).

## Frame

`turret_reach_showcase`, windowed 1280 x 720, Forward+ on Vulkan: `01-turret-answers-a-truck-at-its-reach.png`. Player 2's Truck (right) stands 43.3 m straight out from Base A's right Turret, as far as its own Shots reach the drum, and fires; the Turret's Shot (red) comes in 13.7 m ahead of it. The runner's older HUD shows (the scenario does not declare the later opt-ins).

## Human checks

- [ ] On a pad: drive with the stick straight up, then up and sideways: the Unit keeps its speed through the turn.
- [ ] The stick only sideways turns a standing Unit on the spot, faster than before; nothing feels twitchy.
- [ ] A Truck can no longer break a Turret from beyond its reach.
