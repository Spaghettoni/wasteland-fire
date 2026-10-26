# Evidence: Stories 059 (ford shores) and 060 (the Controls screen)

Date: 2026-10-26 · Godot 4.7.2 · Linux, headless for checks, xvfb + Vulkan for frames.

## Story 059

- `map_03` A5_the_shores PASS: 10 ford ends (west fords 1–3, north and south channels, both ends each): on the island 2.5 m from the water the Buggy is in no ford 10 of 10; 3 m out on the water it is in the ford 10 of 10.
- `map_03` A1–A4 PASS (A3: a Buggy still crosses from the Garage island to the middle).
- Frame: `story-059-060/story-059-map-03-fords.png` (the map choice picture, regenerated): every channel reaches its islands.

## Story 060

`godot --headless --path . -s res://tools/evidence/lobby/controls_check.gd` — RESULT controls ok checks=7 failed=0:

- C1 the screen: C opens it; Fire ["Space", "Period", "A", "RT"]; Throttle ["W", "Up", "Stick up", "—"].
- C2 a key: Down ×4, Enter, F: Fire for Keyboard 1 = F.
- C3 a key in use: W → Fire W, Throttle F; Up → Fire Up, Keyboard 2's Throttle W.
- C4 the pad: X → Fire X; RT on Secondary → Secondary RT, Fire's second slot LT; Menu refused; Delete empties; Delete on the only input refused.
- C5 kept: read fresh from the file, the same.
- C6 Default: table and file back to the defaults.
- C7 into the match: Pick a side reads "Press A, F or Period…"; in the match Player 1's Fire is the key F, Player 2's (pad 0) the pad's X.

Frames in `story-059-060/`: defaults, listening, a moved key, the pad, Pick a side.

`pick_side_check` 6/6 and `map_choice_check` 6/6 pass. Full regression: see the commit (all scenarios ok).

## Story 060, update 2026-10-26 (Martin's defaults)

Martin, with a picture of his table: "chcem aby toto boli defaults a pri controleroch RT bol default pre fire". `ControlsSettings.default_keys` and `default_pad`; the Controls screen opens with F1 (C is now Keyboard 1's Fire). The file keeps only changes from the defaults, with a format mark; an older file is ignored.

- controls_check 7/7: C1 Fire ["C", "Slash", "RT", "A"], Secondary Space / Comma, Camera Q / Right Shift; C7 "Press A, F or Slash when you are ready".
- pick_side_check 6/6 (ready with C and Slash), map_choice_check 6/6; full regression again before the build.
- Frames in `story-059-060/` re-captured.
