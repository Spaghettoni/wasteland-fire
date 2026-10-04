# Story 010: The camera from above

> **Epic**: Wasteland Fire — First Playable
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: S (a day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-04

## Context

**GDD**: `design/game-brief.md`, `design/rules.md` ("Camera and controls")
**Requirement**: Item 1 of the author's list from the first playtest with friends (2026-10-03; `story-009-playtest-quick-fixes.md` quotes the whole list): *rad by som skusil pohlad viac zhora, skoro uplne zhora ale s jemnym naklonom dopredu* — "I'd like to try a view from higher up, almost straight down but with a slight forward tilt." It is a trial ("rad by som skusil"): the author wants to play it and compare, so the old view stays one key away. Decided 2026-10-03: the camera first, then the Unit swap (story 011), so the swap is judged in the new view.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From the author's playtest item 1, scoped to this story:*

- [x] AC-1: In a Round each Player's view looks down on that Player's Unit from almost straight above with a slight forward tilt: the camera stands high over the Unit, tilted a little from vertical so it sees more ground ahead of the Unit than behind it, and keeps the Unit in view. It still turns with the Unit, as the camera has since story 001 (decided 2026-10-01 for v0.1). Starting values, to tune by playing: 75 degrees below the horizon (15 degrees from straight down), 26 m from the point it looks at, that point 4 m ahead of the Unit.
- [x] AC-2: The view keeps every promise of the chase camera: it follows without visible jitter at 60 fps (story 001 AC-5: moved in `_process` from the target's interpolated transform), it snaps to the Unit at every spawn, respawn and restart, and it never ends up looking straight down where the look-at maths has no up direction (the existing guard).
- [x] AC-3: Nothing a Player must see is hidden from above: the Player's Unit anywhere on Map 01, both Flags wherever they are (on their seats under the water towers, carried or dropped), the Fuel Cans, the depot tanks and the cover. The HUD band, the choice panel, the respawn countdown, the Round-over screen and the out-of-Fuel hint stay where they are, readable, with nothing clipped in the 640 × 720 view.
- [x] AC-4: Each Player can switch their own view between the new camera and the chase camera of stories 001 to 009 with one key (an Input Map action per Player, like every other key), at any time in a Round, so the friends can compare in one playtest; the other Player's view does not change. A Round starts in the new view.
- [x] AC-5: Every camera value is data: each view is a settings `.tres` (the existing `chase_camera_settings.tres` for the chase view, a new one for the view from above), the list a Player's key steps through is data in `split_screen.tscn`, and the keys are in `project.godot`. The driving toy keeps the chase camera. The evidence scenarios written before this story run on the camera they were measured with and keep their outputs.
- [x] AC-6: The frame rate holds: with both views from above, the 60 fps target holds on the dev machine across Map 01 (`map_fps`, which sees more of the Map from up there).

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers, not decisions:*

- The camera today: `ChaseCamera` (`src/gameplay/camera/chase_camera.gd`, 105 lines) places itself at `settings.offset` in the target's frame, `(0, 7, 13)` (behind and above, since a Unit faces -Z), and looks at the point `look_height` above the target, with `follow_sharpness` smoothing; `chase_camera_settings.tres` is shared by `split_screen.tscn` and `driving_toy.tscn`. The rules of `_process`, `top_level`, the interpolated transform and the exponential smoothing stay as they are (its class doc lists the five).
- The view from above can be one more settings resource with the same fields: an offset of about `(0, 26, 3)` (25.1 m up from a look point 1 m high, 6.7 m behind it, which stands 4 m ahead of the Unit) gives the 75 degrees and 26 m of AC-1. Clearer for the author to tune are the source's own exports (`design/rules.md`, "Camera and controls": `follow_rotation`, `rotation_smoothing`, `look_ahead`, `pitch_degrees`, where 90 is straight down): add `pitch_degrees`, `distance` and `look_ahead` to `ChaseCameraSettings` (zero defaults, so the chase `.tres`, which has none of them, keeps computing the old offset exactly), and `follow_rotation` (true: turning, as now). With `follow_rotation` false the view would stay north-up; that is the source's camera test, not this story, but the field costs nothing and lets the author try it by data.
- The switch (AC-4): an Input Map action per Player (`p1_camera`, `p2_camera`) on a free physical key near each layout, checked against the keyboard's ghosting with `tools/evidence/input_ghosting_check.gd` as story 002 did, read edge-triggered in `_physics_process` by a small input node like the others (gameplay code names actions, never keys), stepping through an exported list of settings resources on that Player's camera and snapping nothing: the smoothing carries the camera from one view to the other.
- Watch the water towers (AC-3): each Flag sits on its seat under its Base's water tower (`Base1/WaterTower/Tank` is an 8 × 8 m tank over the seat), and from straight above the tank can hide the Flag. Measure it first; if it hides it, the smallest fixes are data (the tank higher, or the tilt), and a change to the tower's look is a question for the author before anything else.
- Shadows reach 100 m (`directional_shadow_max_distance` on Map 01's Sun), beyond the 26 m view, so they stay; check the frames anyway.
- The Gyrocopter's model rises over cliffs and cover (`KitUnitModel`) so the chase view sees it over the walls; from above that matters less but stays.
- The older scenarios (AC-5): `layout` and `destruction` read the cameras (the drive harness's four print the toy's camera, which keeps the chase view). As in stories 005 to 009, the runner gives every scenario written before this story the chase settings on both split-screen cameras before the scene enters the tree; capture all 44 retained outputs (the 38 of story 009's regression and its six) before the first edit and compare after.
- Process (`design/rules.md`, Process rules): after the change, say how to test it (the main scene, each Player's camera key, a drive past the water towers and the canyon).

---

## Out of Scope

- The camera and control test of the source (fixed vs turning camera, vehicle-relative vs screen-relative keys) and the arrow to the own Base or north-up minimap it may call for: open after v0.1 (decided 2026-10-01); the `follow_rotation` field only makes it possible by data.
- The Unit swap at the own Base: story 011.
- Per-Unit camera settings (the source suggests the Gyrocopter may want its own): after the author has played this.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Visual/Feel
**Required evidence**:
- Retained screenshots in `production/qa/evidence/story-010-camera-from-above/`: both views from above at the Round start, on the open flat, by a water tower with the Flag on its seat, over the canyon and at the depot, and one Player switched to the chase view while the other stays above.
- Sign-off in `production/qa/evidence/story-010-camera-from-above-evidence.md` (the test-evidence template's sign-off rows; for a solo developer every role may be signed by the same person), with the frame-rate run.

**Status**: [x] Created 2026-10-03; sign-off recorded at `/story-done` on 2026-10-04

---

## Dependencies

- Depends on: Story 009 (Complete).
- Unlocks: story 011 (the swap is judged in the new view); the author's next playtest.

## Completion Notes
**Completed**: 2026-10-04
**Criteria**: 6/6 passing. AC-1 to AC-6 measured on the real build by `camera_views` (9 checks, headless, every key a real event, run twice byte-identical), `camera_showcase` (7 moments, 10 frames retained and read), `camera_smooth` (windowed, the aim against the Unit's drawn place, 12 runs on the 120 Hz display) and `map_fps` (120 fps steady, 222 draw calls at most); 25 seeded defects, 25 caught; the 44 older outputs unchanged (42 byte-identical, 2 after one harness line-number rewrite). The developer confirmed the four human checks at `/story-done` ("Yes — passes" to all four): the look and the visibility of everything needed (AC-1, AC-3), the feel of the follow (AC-1, AC-2), the two keys on the real keyboard (AC-4) and the ghosting check with the camera keys (AC-4). Nothing deferred.
**Deviations**: ADVISORY only. (1) AC-4 says a Round starts in the new view: the launch and the first Round do, but a Player's chosen view stays through a restart (decision log 2026-10-03); one line at the Round start would reset it. (2) Beyond the AC text, the water towers' tank, roof, band and platform are on render layer 2 and the view from above does not draw them (`hidden_layers`), because the tank hid the Flag seat and the Unit taking the Flag; the developer chose it when asked at `/dev-story`. (3) Files touched beyond the notes' list: `compound_base.tscn` (the layer), `project.godot` (the layer name and the two actions), `input_ghosting_check.gd` (three camera combinations), `map_fps.gd` (it runs on the shipped camera), `design/rules.md`, `CONTEXT.md` (the term View) and `README.md`. (4) `camera_views.gd` is 411 lines, over the 280-line guideline (TD-006 amended). (5) `project.godot` also carries an earlier engine rewrite from before the story (a header comment, and the default `[rendering]` section dropped), which will land in the same commit.
**Test Evidence**: Visual/Feel: `production/qa/evidence/story-010-camera-from-above-evidence.md` (the run result, the runs, what each criterion measured, the regression of the 44 older outputs, the 25 seeded defects and the two flaws found in the checks themselves, the measured facts, the notes for the author, the human checks as confirmed, the sign-off row signed) and, in `production/qa/evidence/story-010-camera-from-above/`, ten screenshots with `scenario-outputs/` and `measurements/`. The tests are waived at `qa.level: minimal`: none was written and nothing under `tests/` changed.
**Code Review**: Skipped, Solo mode (LP-CODE-REVIEW); QL-TEST-COVERAGE skipped, `qa.level` minimal. No review lens ran inside `/dev-story`: the story was built directly and verified by the regression, the three scenarios and the seeded defects.
**Tech debt logged** (at close, in `docs/tech-debt-register.md`): TD-006 amended with the Story 010 scenario and runner sizes; nothing new.
**For the author** (not blocking): (1) The Flag is small from up there, about 10 px, with a tower brace crossing it; a bigger or brighter Flag, or a beacon the view from above does draw, is the way out if friends cannot find it. (2) The starting values to tune by playing are in `above_camera_settings.tres`: 75 degrees, 26 m, a look point 4 m ahead. (3) The north-up view of the source's camera test is one data edit away (`follow_rotation = false`), with the controls and the arrow to the own Base it would need left out. (4) The keys are Q (Player 1) and Slash (Player 2).
**Hand-off**: next is story 011, the Unit swap at the own Base (`story-011-unit-swap-at-own-base.md`, Ready): it asks the author two questions before it closes (a same-type swap as a free repair; a free change of the first choice), and the swap is judged in the new view. Stories 009, 010 and 011 are not committed.
