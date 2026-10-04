# Story 010 — The camera from above: test evidence

**Story:** `production/epics/wasteland-fire/story-010-camera-from-above.md` · **Type:** Visual/Feel · **Layer:** Presentation · **Estimate:** S
**Engine:** Godot 4.7.2.stable.official.ed1daf0bf, Jolt Physics, Forward+ (Metal 4.0), physics interpolation on, 60 physics ticks/s
**Machine:** macOS (Darwin 25.5.0) arm64, Apple M4 Pro, 120 Hz built-in display · **Date:** 2026-10-03 · **Run by:** the implementing session directly (no workflow), after the first playtest with friends
**Gate level:** Visual/Feel (BLOCKING by default): retained screenshots and the lead sign-off. Tests are waived at `qa.level: minimal`; none was written and nothing under `tests/` changed. The evidence is the ten frames below (all read), three evidence scenarios (`camera_views` and `camera_showcase` headless, `camera_smooth` windowed), 44 older outputs compared byte for byte, 25 seeded defects, and the human checks at the end.

## Run result

`Run result: OBSERVED — the main scene (godot --path . --windowed --resolution 1280x720, recorded with --write-movie --quit-after 70) opens Map 01 with both Players choosing in the view from above, the water towers drawn as legs and braces with the Flag between them (00); the windowed recording of camera_showcase on the shipped build shows both Units on their Bases (01), both Motorbikes on the open flat (02), each Motorbike coming in toward the other Player's tower and the Flag on its seat (03), both at the seats carrying the Flags (04), the canyon road (05), a Truck and a Buggy at the depot's tanks and Fuel Cans (06) and Player 1 switched to the chase view with Player 2 still above (07); frame 08 is the defect the story found on the way, the tank over the Flag seat.`

## The runs

- **Launch** (`commands.run` plus `--write-movie --quit-after 90`): rc 0, no ERROR or WARNING (`measurements/windowed-launch-recording.txt`); a headless launch of the main scene (120 frames) and of the driving toy (60 frames): rc 0, no ERROR or WARNING.
- **`camera_views`** (headless, `--fixed-fps 60`, every key a real event through the Input Map, run twice byte-identical, `scenario-outputs/split-camera_views.txt`): 9 checks, all PASS, `errors=0 warnings=0`.
- **`camera_showcase`** (headless twice byte-identical, `scenario-outputs/split-camera_showcase.txt`; windowed with `--write-movie`, 745 frames, rc 0, `measurements/camera_showcase-windowed-run.txt`): seven moments, each with its premise read (the view each camera is in, the Flag, Unit or Fuel Can inside its 640 × 720 view); no premise failed.
- **`camera_smooth`** (windowed, 120 Hz display, two full runs each of three runs per view, `measurements/camera_smooth-windowed-runs.txt`): the camera looks at the Unit's drawn place to 0.00001 degrees in every run of both views.
- **`map_fps`** on the view from above (windowed, twice, `measurements/windowed-map_fps-view-from-above-run-*.txt`).
- **The 44 older outputs** (the drive harness's four and 40 of the split-screen runner's; `fps`, `map_fps` and `camera_smooth` are windowed tools) compared with baselines captured before the first edit: see the regression section.

## Retained screenshots (`production/qa/evidence/story-010-camera-from-above/`)

All 1280 × 720 frames from `--write-movie` recordings on 2026-10-03 (Metal 4.0, Forward+), each opened and read. Player 1 (orange HUD) is on the left, Player 2 (teal) on the right.

| File | What it shows | Read |
|---|---|---|
| `00-launch-both-players-choosing.png` | The main scene at launch, both Units benched on their Bases, both Players choosing | The view from above from the first frame; the choice panel, the HUD band and the Team edges are where they were and fully readable; the tower top is not drawn, so the legs, the braces and the Flag between them show |
| `01-round-start-both-from-above.png` | Both Motorbikes in play on their pads | Each Unit about 12 × 45 px in the lower middle, the garage, the cover and the tower legs around it; the Flag is a small mark (about 10 px) between the legs, crossed by a brace |
| `02-open-flat-both-driving.png` | Both Motorbikes at 24 m/s on the salt flat | 31 m of ground ahead of each, 13 m behind; the wrecks, the ford and the cliffs in sight; the Units keep the lower middle |
| `03-water-tower-flag-on-its-seat.png` | Each Motorbike 10 m short of the other Player's seat | The Flag on its seat under the legs is in sight in both views; the Pad of the Unit's own side at the bottom |
| `04-flag-taken-at-the-seat.png` | Both Motorbikes stopped at the seats, each carrying the other's Flag | The Unit is in sight under the legs where the tank would have hidden it (frame 08), the carried Flag trails behind it; "You carry the enemy Flag" in the HUD |
| `05-canyon-road.png` | A Buggy and a Motorbike on the canyon road, facing each other | Both Units in sight between the rock walls; the other Player's Unit shows at the top of the view behind the HUD band |
| `06-depot-tanks-and-fuel-cans.png` | A Truck and a Buggy at the depot | The three tanks, the five red Fuel Cans between them and the Units all in sight; nothing hidden behind a tank |
| `07-player-1-chase-view-player-2-above.png` | Player 1 pressed Q (the chase view, horizon and the far towers in sight), Player 2 untouched | The two views side by side, the HUD identical in both |
| `08-defect-found-tank-over-the-flag-seat.png` | The same launch scene before the fix | The orange tank fills the top of the view over the Flag seat: the Flag and any Unit driving in to take it would be hidden |
| `09-crop-flag-on-its-seat-player-1-view.png` | A 200 × 160 px crop of frame 03 (Player 1's view), enlarged three times | The Flag on its seat is a round mark of about 10 px under the crossing of two braces: in sight, but small |

## Acceptance criteria — what was measured

- **AC-1 (the view).** `camera_views` T1: at the Round's start both cameras stand 26.11 m up and 2.73 m behind their Unit (the offset the pitch, distance and look-ahead give), look 75.000 degrees below the horizon at a point 26.000 m away and 4 m ahead of the Unit, and aim at it to 0.00001 degrees (the camera is within 0.0000 m of its place). T2: the Unit's whole footprint is inside its 640 × 720 view (261 px from the nearest edge), the view shows 31.3 m of ground ahead of the Unit and 13.5 m behind it, and the camera's heading is the Unit's (0.000 degrees). T3: Player 1's Unit turned 80.2 degrees on the spot and the camera's heading followed it to 0.000 degrees; Player 2, standing, did not change.
- **AC-2 (the promises of the chase camera).** Smooth: `camera_smooth`, windowed on the 120 Hz display (two frames to a 60 Hz tick), the Motorbike at 24 m/s: in all 12 runs (3 per view, two executions) the camera looks at the Unit's drawn place to 0.00001 degrees at most, against 0.34 to 0.59 degrees for a camera that reads the physics-tick transform (seeded defect 25); the camera's lag behind the Unit stays within 0.5 mm of a straight line. Snap: T4, the camera is 0.0000 m from its place at the Round's start, after a Self-destruct and a respawn, and after a loss and a restart (both cameras). No straight-down fault: T5, a view of 90 degrees raises no engine error, looks straight down (1.00000) and has the Unit's forward at the top of the screen with `follow_rotation` and the world's -Z without it.
- **AC-3 (nothing hidden).** The water towers' tank, roof, band and platform are on render layer 2 (`tower_top`) and the view from above does not draw them (T8: 16 sight lines from the camera of every heading of a Unit at the two seats to the Flag at 0.5 and 1.5 m and to the Unit: none crosses a tower piece; with the layer drawn, 16 of 16 do); the chase view's cull mask draws everything. The Flags on their seats and carried (03, 04, 09), the Unit anywhere (01 to 07), the Fuel Cans, the tanks (06) and the cover (02) are in sight in the frames. The Controls of both views are where they were whichever view the camera is in (T9: the same 40 rectangles). The Flag is small (frame 09): see the notes.
- **AC-4 (the switch).** T6: Q switches Player 1 to the chase view, `/` switches Player 2; two ticks after the key the camera had crossed 0.12 of the 21.7 m between the two places (a glide, not a snap) and 90 ticks later it was 0.0001 m from the chase place, aiming at the point 1 m over the Unit to 0.00000 degrees; a key held for 45 ticks made one step; the other Player's view did not change; the Round starts in the view from above (T1, T6). The choice stays through a restart (T4: Player 2 in the chase view before the loss, still in it after the restart).
- **AC-5 (data).** T7: `above_camera_settings.tres` holds pitch 75, distance 26, look-ahead 4, look height 1, sharpness 8, `hidden_layers` 2; `chase_camera_settings.tres` holds the old offset (0, 7, 13) and none of the new fields; each Player's list in `split_screen.tscn` is [above, chase]; `p1_camera` and `p2_camera` are in `project.godot` bound to one key each (Q and Slash); the driving toy's camera is on the chase settings. The 44 older outputs keep their bytes (next section).
- **AC-6 (frame rate).** `map_fps` on the build's camera, windowed on the 120 Hz display: `fps_avg_steady` 120.0 and 119.9, `fps_min_steady` 119.0 and 118.0, `draw_calls_max` 222 (the chase view's run of Story 009: 120.0, 120.0 and 262). The first second of each run (start-up) reads 61 and 64 fps in `fps_min`, as the first second of every windowed run before it (53 in Story 009's). 60 fps holds with both views from above across Map 01.

## Stories 001 to 009 regression

Baselines of all 44 retained outputs (the drive harness's four and 40 of the split-screen runner's) were captured at the working tree of the start of the story (`measurements/regress-44-baselines.txt`), twice, before the first edit; the two captures were byte-identical apart from one engine warning ("Jolt Physics job system exceeded the maximum number of jobs", a load warning of the parallel run that appeared once in a first capture and not in the second, the one kept). On the final code: 42 byte-identical, and `token_ui` and `tokens_data` identical after one exact rewrite (`measurements/normalizers.json`): both print an engine backtrace of an intended error, and one line of it names `split_screen_harness.gd:720` where `advance_ticks` now sits at line 750 because the runner gained the camera constants. All 44 exited 0 with `RESULT ok`. The older outputs keep their bytes because the runner gives every scenario that does not declare `SHIPPED_CAMERA` the chase settings on both cameras before the scene enters the tree (`_apply_chase_camera()`), and because a chase view computes exactly the expression it did before (the look height stays in the world's up, a look-ahead of zero adds nothing, `local_offset()` returns `offset` as it stands): the unchanged outputs are the proof that every new branch is inert with its data at zero. `destruction`, `map_legibility` and the drive harness read the camera, so they are the older outputs that would notice.

## Seeded defects

25 defects, each one exact text replacement in a scratch copy of the repo (`measurements/seeded-defects.py.txt`), each run against the scenario that guards it: 25 caught, 0 survived (`measurements/seeded-defects.txt`). Among them: a pitch of 60 degrees in the data; a distance ignored; no look-ahead, or a look-ahead behind the Unit; `follow_rotation` ignored; the straight-down guard removed, or using the Unit's frame when the camera follows the world's; a key that never steps, steps while held, or snaps; Player 2's key steering Player 1's camera; a Round that starts in the chase view; the tower top not hidden, the tank back on layer 1, or the cull mask never set; the chase view hiding the tower; the driving toy given the view from above; the camera key unbound; a look-ahead of 8 in the data; a chase aim a centimetre high; the runner giving the older scenarios no chase settings; `follow_rotation` defaulting to false; the chase offset changed by a centimetre; and a camera that reads the physics-tick transform instead of the drawn one (windowed, 6 runs of 6 failed).

Two defects of the checks themselves were found and replaced on the way, and they are why `camera_smooth` measures what it does. First, a check of the camera's place against time passed a camera driven by the physics tick in some runs: the camera's own smoothing (a lag of a tenth of a second) takes a 60 Hz staircase of 0.2 m down to 4 mm, so the camera's place is not where the interpolated transform matters. The look point is, because it comes unsmoothed from the Unit's transform, so the verdict is now the angle between the camera's forward direction and the Unit's drawn look point, sampled in the same frame. Second, the same check sampled the camera in the frame after the Unit and so measured the timestamp noise of the frames (about 1 ms, 2 cm at 24 m/s), which made it fail twice, in the first view, in runs made right after a long import and under a machine load of 3.6; the same-frame sample does not have that noise. A first list also held a defect that changed nothing (a shift of the vector used only for the straight-down test), replaced by a real one.

## Verification of the build itself

- Parse check of the ten changed or new scripts: ok, exit 0. The tracked class cache was rewritten by the import, never by hand (one new class, `PlayerCameraInput`; the `.uid` sidecar came from the import).
- The main scene for 120 frames and the driving toy for 60: rc 0, no ERROR or WARNING.
- The ghosting tool's self test with the three new combinations that hold the camera key: `GHOST SELF-TEST ok combos_seen=11/11` (`measurements/ghosting-self-test.txt`). Whether the real keyboard delivers them is a human check, below.
- `assets/` unchanged: no file under it is newer than the start of the story.

## Measured facts the code comments point at

- From 75 degrees the water tower's tank hides the Flag on its seat, and so any Unit that drives in to take it: the camera's sight line to the seat crosses the tank (radius 4 m, from 8.3 to 13.3 m up) for every heading, 16 of 16 lines with the layer drawn (T8). A data fix would need a tilt of about 65 degrees or a tank 15 m up; the developer chose to hide the tower's top in the view from above (decision log, 2026-10-03).
- Between two ticks the Unit is drawn up to a whole tick step away from the tick transform (v / 60: 0.4 m at 24 m/s), and the camera's unsmoothed aim shows it as a 0.34 to 0.59 degree step at 60 Hz; the interpolated transform removes it (`camera_smooth`).
- At 75 degrees and 26 m the view of 640 × 720 px covers about 36 m across and 44 m in depth; a Motorbike is about 12 × 45 px and the Flag about 10 px.
- A key set in a tick acts one tick later: the camera key is read in `_physics_process` like the others, so a press is seen on the tick after the event (`press_settled`).

## Notes for the author

1. **Starting values to tune by playing:** 75 degrees, 26 m, a look point 4 m ahead and 1 m up, sharpness 8, in `src/gameplay/camera/data/above_camera_settings.tres`. A lower pitch sees more ahead and less of the ground under you; a longer distance sees more of everything and makes the Units smaller (a Motorbike is already 12 px wide).
2. **The Flag is small from up there** (frame 09: about 10 px, crossed by a brace of the tower). It is in sight, but it is the first thing a friend may not find. Ways out if it matters: a bigger Flag, a brighter Team colour on it, or a beacon above the tower that the view from above does draw.
3. **The towers lose their top in the view from above** (your choice from the question): the legs, the braces and the shadow stay, so the tower still reads as a tower; the chase view is unchanged. One data edit undoes it (`hidden_layers = 0`).
4. **The view you chose stays through a restart.** The story says a Round starts in the new view; the launch does, and so does the first Round, but a Player who switched to the chase view stays in it after R. If every Round should start from above, it is one line in the Round start.
5. **The keys are Q (Player 1) and Slash (Player 2).** Slash is the key right of Period on a US layout; on other layouts it is the same physical position.
6. **The north-up view** (the source's camera test) is now one data edit away: `follow_rotation = false` in a settings file, with the controls and the arrow to the own Base the story left out.
7. **The HUD band covers the top 84 px of each view** and the other Player's Unit can show behind it (frame 05); nothing was changed there, as the story says.

## Human checks (confirmed at `/story-done`, 2026-10-04)

`/story-done` asked the four questions below and the developer answered **Yes — passes** to each (the Flag-size note of the first question was put to them in the question itself):

1. The look (AC-1, AC-3): "Starting a Round, is the view from above what you meant, almost straight down with a slight tilt forward, and can you see everything you need: your Unit, the Flags (on their seats, carried), the Fuel Cans, the depot, the cover?"
2. The feel (AC-1, AC-2): "Driving fast, does the camera follow smoothly with no shaking, and does it feel right that it turns with the Unit and looks ahead of it?"
3. The switch (AC-4): "Does Q switch your view to the chase camera and back, and Slash the other Player's, with the other Player's view unchanged?"
4. The keyboard (AC-4): run `godot --path . res://tools/evidence/input_ghosting_check.tscn`, hold the three new lines (throttle + left + right + camera for each Player, and both throttles with both camera keys) and paste the `GHOST` line.

## Sign-Off

A **Visual/Feel** story needs the lead sign-off below. A solo developer signs as themselves (`.claude/docs/templates/test-evidence.md`).

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Lead (art-director / designer) — solo developer | Tomas Kunzo | 2026-10-04 | [x] Approved |

*Sign-off recorded from the developer's answers to the `/story-done` Visual/Feel questions on 2026-10-04 (the look and the feel: Yes, no retune); not filled in by an agent on its own.*

---

*Template: `.claude/docs/templates/test-evidence.md`*
*Used for: Visual/Feel and UI story type evidence records*
*Location: `production/qa/evidence/story-010-camera-from-above-evidence.md`*
