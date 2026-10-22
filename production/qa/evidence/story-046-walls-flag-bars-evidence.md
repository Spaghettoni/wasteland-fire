# Story 046 evidence: Every wall for both sides, a smaller Flag, white bars

> **Story**: `production/epics/wasteland-fire/story-046-walls-flag-bars.md`
> **Type**: Integration (headless checks + windowed frames)
> **Written**: 2026-10-22, by `/dev-story` in a cloud session (Linux, Godot 4.7.2 official build)
> **Sign-off**: [ ] Martin, after playing `WastelandFire-2026-10-22-walls-flag.exe`

## Acceptance criteria, as measured

| AC | Result | Check |
|---|---|---|
| AC-1 walls for both sides | PASS: every wall of Map 01 uses `flag_wall_stats.tres`, spares false; Player 1's Buggy firing at Player 1's own wall Panel1: 40 → 0; at Player 1's own TurretLeft: 100 → 100 | `secondary` X7 |
| AC-2 a smaller Flag | PASS: both Flags 2.00 m tall (3.12 before); carried, the cloth 0.59 m behind its pole; frame 07: a Motorbike in a Bush shows only a sliver of cloth | `real_flag` F1, F3; frame |
| AC-3 white bars | frames 02 (Smoke) and 03 (Mine) | frames |
| AC-4 older outputs | PASS: against story 045's capture only timings, engine stack line numbers, `real_flag` (the new heights) and `secondary` (X7 added) differ | regression |

## The colours

Martin asked whether the colours look muted. They do, by the settings, not by impression: both Maps light the scene with a flat grey ambient light at 0.9 energy (with 0.6 from the sky), which fills the shadows, and a beige fog from 60 m, which washes out the far half of the view; the new unshaded supply zones make the rest look duller beside them. `colour-before-after-proposal.png` shows Map 02 as it is (left) and with ambient 0.55, the fog from 120 m at 0.12 and a saturation of 1.2 with a contrast of 1.06 (right), rendered with the compatibility renderer here; Martin's Metal / Forward+ picture will differ. Not changed in this story: it waits for Martin's choice.

## Frames

`recharge_showcase`, windowed 1280 x 720: `02-gyrocopter-smoke-ahead.png`, `03-truck-mine-bar-filling.png`, `07-motorbike-with-the-smaller-flag-in-a-bush.png`; `colour-before-after-proposal.png`.
