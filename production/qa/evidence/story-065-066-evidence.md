# Evidence: Stories 065 (mines) and 066 (the Gyrocopter banks), and the Teammate's burn

Date: 2026-11-22 · Godot 4.7.2 · Linux, headless checks; frames with xvfb + Vulkan.

- `mines_gyro_065` RESULT ok checks=3: M1 the look (casing 0.50 m, trigger 0.80 m, Team light 0.225 m; the live light went [true, false, true] in a second); M2 its own Team (Player 1's Buggy over Player 1's live Mine: destroyed); G1 the Gyrocopter banks (rolled up to 18.7°, its model's origin off its hover height by 0.0000 m).
- `flame_tank` F5 a Teammate burns: 100.0 → 98.8 under half a second of flame, on fire, 90.0 a second later. F1–F4 as before.
- Frames: `story-065-066/mine-live-own-team.png`, `gyro-banks-into-turn.png`.
- Full regression (130 scenarios): the same exits as the run before, mines_gyro_065 new and passing. Older scenarios keep the disc Mines and the level Gyrocopter (MINE_LOOKS, GYRO_BANKS opt-ins).
