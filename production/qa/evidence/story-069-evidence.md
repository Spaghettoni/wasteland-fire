# Evidence: Story 069 — burning vehicles show it; the stick keeps its direction

Date: 2026-11-22 · Godot 4.7.2 · Linux, headless checks; frames with xvfb + Vulkan --write-movie.

- `flame_tank` F7 the fire rides PASS: the burning Buggy at 19.6 m/s (still speeding up), its flames' middle 1.39 m from its middle across the ground, 1.83 m above it; glow lit. F1–F6 as before.
- `direction_lock` RESULT ok checks=3: L1 reversing −9.00 m/s, stick left and 0.60 up still −9.00, pushed up 0.95 → +8.67; L2 after a 0.35 s spot turn, left and 0.60 up → +4.67 (forward); L3 S −9.00 then W +8.60.
- `full_throttle` unchanged (T1–T3 PASS).
- Frames: `story-069/burning-buggy-driving.png` (the fire rides on the Buggy, orange, with its glow), `story-069/turret-afterburn.png`.
- Full regression (131 scenarios): the same exits as the run before; direction_lock new and passing. Older scenarios have the lock off unless they declare DIRECTION_LOCK.

## Follow-up 2026-11-22 evening: the fire at any frame rate

Martin: "tie plamene stale nevidi. hp klesa ale vozidla nehoria". The ride velocity was read between drawn frames, so above
60 fps (a fast screen, no vsync) it was zero on most frames and many times too fast on the rest; at 600 fps the flames
trailed 4 m behind a driving Buggy. Now Burning moves the living flames and smoke with the target's drawn (interpolated)
position each frame (FxParticles.shift), at ride_share 0.9, and emits them where the target is drawn.
- `flame_tank` F7 at 60 fps: flames' middle 0.81 m from the Buggy's middle; run with --fixed-fps 600: 0.73 m (was 4 m).
- Full regression (131): the same exits as the run before.
