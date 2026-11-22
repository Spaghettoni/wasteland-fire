# Evidence: Stories 063 (the Flame Tank) and 064 (drivers)

Date: 2026-11-22 · Godot 4.7.2 · Linux (headless checks; frames with xvfb + Vulkan, model renders with OpenGL). Models rebuilt with bpy 5.2.2 (Python 3.13).

## Story 063: `flame_tank` — RESULT ok checks=4 failed=0

- F1 the reach PASS: reach 22.8 m from the Tank's middle (muzzle 2.8 + flame 20); the Buggy's back 1.5 m beyond it lost 0.0, 1 m inside it 3.3. The Tank lost none of its own.
- F2 the burn PASS: a second of flame: 10.4 lost; then 42.7 in the 5 s of fire (39.1 expected: 15.62 a second × matrix 0.50; the puffs still in flight at the release rekindle it); the fire went out after.
- F3 a Structure burns PASS: the Turret 100 → 81.7 at the release → 0 (fallen) by its fire.
- F4 the load PASS: a new Flame Tank 250 of 250; a puff 249; a rocket 239 (cost 10).

## Story 064

- Model renders: `story-063-064/models-three-quarter-orange.png`, `models-top-orange.png` (the four Units, Team-painted, drivers in each).
- In the game (Map 02, chase view): `drivers-pair-1-motorbike-buggy.png`, `drivers-pair-2-gyro-flame-tank-flaming.png` (Player 2's Flame Tank flaming a wreck, which burns).
- Effects: `flame-and-burning-test-render.png`, `flame-tank-arena-flames.png`.

## Regression

Full headless regression (129 scenarios): the same exits as the run before the changes (after merging effects/feel), with flame_tank and drivers_showcase new and passing. Changed to keep it so: `tyre_tracks_data` (the tracks' contacts), `ammo_data` (the Truck file's load 250), `rotors_file`/`rotors_destroy` (the Gyrocopter with its pilot, compared with an unsplit build of it), `light_showcase_sil` (two moments stage Buggies).
