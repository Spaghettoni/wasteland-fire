# Story 047 evidence: Canyon wall shadows; a pad's B back to the map choice

> **Story**: `production/epics/wasteland-fire/story-047-shadows-and-pad-back.md`
> **Type**: Visual/Feel (windowed frames, Forward+ on Vulkan) and a headless check
> **Written**: 2026-10-22, by `/dev-story` in a cloud session (Linux, Godot 4.7.2 official build; Mesa lavapipe for Vulkan)
> **Sign-off**: [ ] Martin, after playing `WastelandFire-2026-10-22-shadows.exe` on Windows

## The shadows

Every earlier frame of the evidence used the compatibility renderer (OpenGL), which does not show the fault. With `--rendering-driver vulkan` (Forward+, as the Windows build runs) `shadow_showcase` drove a Motorbike south past Map 02's Fuel building, the west wall on its right, as in Martin's picture: `before-17-chase-west-wall.png` shows the wall's shadow ending in a straight line a few metres ahead of the Motorbike, the ground near the camera lit. `variants-current-pancake0-orthogonal.png` compares the Sun as it was, with `directional_shadow_pancake_size = 0`, and with the orthogonal shadow mode; both fixes give an unbroken shadow, the orthogonal one blurrier. Pancake 0 is applied to both Maps: `after-17-chase-west-wall.png` and `after-08-above-west-wall.png`. Map 01 in Forward+ (the frames of `recharge_showcase`) shows no new artefacts.

## The pad's B

`pad_back`: Player 1 delivers Player 2's Flag on Map 01, the Round is over, pad 0 (connected through PadAssignment) presses B: the map choice is the current scene a few frames later. PASS twice. The binding is `round_back` (project.godot: Esc, and B on every pad, device -1), read by `MapChoiceReturn` (process mode Always) while the Round is over. What Martin met is not reproduced here; asked which screen, whether Esc works there, and which controller.

## Regression

`map_02`, `map_layout`, `bushes` and `cover_pieces` give the same headless output (the Sun setting changes only the drawing).
