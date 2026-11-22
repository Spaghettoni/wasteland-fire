# Evidence: Story 069 — burning vehicles show it; the stick keeps its direction

Date: 2026-11-22 · Godot 4.7.2 · Linux, headless checks; frames with xvfb + Vulkan --write-movie.

- `flame_tank` F7 the fire rides PASS: the burning Buggy at 19.6 m/s (still speeding up), its flames' middle 1.39 m from its middle across the ground, 1.83 m above it; glow lit. F1–F6 as before.
- `direction_lock` RESULT ok checks=3: L1 reversing −9.00 m/s, stick left and 0.60 up still −9.00, pushed up 0.95 → +8.67; L2 after a 0.35 s spot turn, left and 0.60 up → +4.67 (forward); L3 S −9.00 then W +8.60.
- `full_throttle` unchanged (T1–T3 PASS).
- Frames: `story-069/burning-buggy-driving.png` (the fire rides on the Buggy, orange, with its glow), `story-069/turret-afterburn.png`.
- Full regression (131 scenarios): the same exits as the run before; direction_lock new and passing. Older scenarios have the lock off unless they declare DIRECTION_LOCK.
