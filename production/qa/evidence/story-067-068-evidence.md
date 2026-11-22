# Evidence: Stories 067 (flat damage) and 068 (the Flame Tank looks like the picture)

Date: 2026-11-22 · Godot 4.7.2 · Linux, headless checks; renders with xvfb + OpenGL.

- `flame_tank` RESULT ok checks=6: F6 every Unit type against every Unit type 1.0 (the matrix keeps only `motorbike>flag_wall`); hit points still differ by type [40, 100, 220, 70]. F2 expects the burn at 1.0.
- `tyre_tracks` ok (the tracks now ±0.9 m, 0.6 m wide); `heights_scan` keeps the flying height at 2.5 m (the tank's tallest ground part 2.204 m).
- Renders: `story-067-068/tank_front.png`, `tank_back.png`, `tank_side.png` — tracks with four road wheels and toothed sprockets, riveted spiked body, Team hood with skull, grille and spike ram, twin brass-ringed flamers, the driver in the spiked cage behind a low rocket pod, the Team drum with skulls, flag pole with pennant, burning exhausts.
- Full regression (130 scenarios): the same exits as the run before (`tyre_tracks_fps` fails on fps_min in headless as before). Older scenarios keep the triangle unless they declare `FLAT_DAMAGE`.
