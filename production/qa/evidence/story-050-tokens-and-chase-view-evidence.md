# Story 050 evidence: More Tokens, and a chase view with the Unit low and the way ahead in sight

> **Story**: `production/epics/wasteland-fire/story-050-tokens-and-chase-view.md`
> **Type**: Visual/Feel (headless checks, windowed frames)
> **Written**: 2026-10-25, in a cloud session (Linux, Godot 4.7.2 official build)
> **Sign-off**: [ ] Martin, after a Round in the chase view with four and with two Players (`WastelandFire-2026-10-25-chase-tokens.exe`)

## Acceptance criteria, as measured

| AC | Result | Check |
|---|---|---|
| AC-1 more Tokens | PASS: motorbike 7 (was 5), buggy 4 (3), truck 3 (2), gyrocopter 3 (2); 17 in all, 1.42 times 12; both Teams start with 7/4/3/3 | `chase_view` V1; `tokens` (now on the new counts) passes its 8 checks |
| AC-2 width field of view | PASS: every camera on the chase view keeps its width at 68.6 degrees; in 640 x 358 quarter views the Motorbike is drawn 61.8 px wide, the Buggy 79.5, the Truck 106.0, the Gyrocopter 70.6, each what the same Unit at the same depth measures in a 640 x 720 half view at 75 degrees across the height (within 0.2 percent) | `chase_view` V2 |
| AC-3 the Unit low | PASS: standing in its Garage, each of the four Units is drawn at 0.90 of its quarter view's height from the top (offset 0, 6.5, 9; look-ahead 7 m); driving, it rises a little (the camera trails) | `chase_view` V3, frames |
| AC-4 nothing else changed | PASS: see the regression | — |

## Regression

All 110 scenarios (story 049's 109 and `chase_view`). The runner gives every scenario that does not declare `CLOSE_CHASE` the chase settings of before and every one that does not declare `MORE_TOKENS` the counts of before. Against story 049's capture only frame-rate timings differ, and `tokens` T02, which compares the stock in play with the file on disk: it now declares `MORE_TOKENS` and passes on 7/4/3/3.

## Frames

`chase_showcase` (four Players, Map 01) and `chase_showcase_two` (two Players), windowed 1280 x 720, Forward+ on Vulkan, every camera on the chase view, a frame standing in the Garage and one after 2 s driving out: `before-chase-4p-*.png`, `before-chase-2p-*.png` (the settings of stories 001 to 049) and `after-chase-4p-*.png`, `after-chase-2p-*.png`. With four Players the Units are now as big as with two; with two the Unit is lower and nearer, more of the way ahead shows, and more sky.

## Human checks

- [ ] With four Players in the chase view the Units read well and the view does not feel cramped above and below.
- [ ] With two Players the Unit sits low enough and the camera is not too close.
- [ ] 17 Tokens per Team feel right for a Round's length.
