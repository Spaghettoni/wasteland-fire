# Story 001 — Driving toy: test evidence

**Story:** `production/epics/wasteland-fire/story-001-driving-toy.md` · **Type:** Visual/Feel · **Layer:** Foundation
**Engine:** Godot 4.7.2.stable.official.ed1daf0bf, Jolt Physics, Forward+, physics interpolation on, 60 physics ticks/s
**Machine:** macOS arm64, Apple M4 Pro, 120 Hz display · **Date:** 2026-09-30 · **Run by:** `/dev-story` (workflow `wf_6baa3d88-414`, then the orchestrator's own launch-and-look)
**Gate level:** Visual/Feel = BLOCKING (retained screenshot + lead sign-off); tests waived at `qa.level: minimal`.

## Run result

`Run result: OBSERVED — commands.run (no scene argument) opens 1280×720 straight into the greybox field: grey grid plane, dark perimeter wall at the horizon, sky-blue background, one orange Motorbike with a cream nose block on its front, chase camera behind and above it; no menu, no HUD. Retained: production/qa/evidence/story-001-driving-toy/01-launch-commands-run-no-menu.png.`

## Retained screenshots (`production/qa/evidence/story-001-driving-toy/`)

All 1280×720 frames from `--write-movie` recordings on 2026-09-30 (window: Metal 4.0, Forward+).

| File | Recording | What it shows | Inspected |
|---|---|---|---|
| `01-launch-commands-run-no-menu.png` | `godot --path . --windowed --resolution 1280x720 --write-movie … --quit-after 90` (the literal `commands.run`), frame 89 | AC-1: the launch surface — plane, walls, Motorbike, chase camera, no menu | yes |
| `02-idle-at-spawn.png` | harness `showcase`, frame 30 (t = 0.5 s, idle) | the Unit at rest at the scenario start position near a corner: two walls close on the left and right with the far corner ahead, the grid running diagonally, the orange Motorbike centred with its cream nose block on top | yes |
| `03-full-throttle-24ms.png` | harness `showcase`, frame 210 (t = 3.5 s, throttle, 24.0 m/s) | AC-2/AC-5: cruising straight, camera locked behind, grid gives the speed reference | yes |
| `04-turning-left.png` | harness `showcase`, frame 360 (t = 6.0 s, throttle+left) | AC-2: the body yawed, camera swung behind it, nose block shows the facing | yes |
| `05-reversing.png` | harness `showcase`, frame 660 (t = 11.0 s, reverse, −9.0 m/s) | AC-2: reversing at the data-limited reverse speed | yes |
| `06-coasted-to-stop.png` | harness `showcase`, frame 779 (t = 13.0 s, coast, 0.0 m/s) | AC-2: at rest after the coast, centred in frame, camera settled behind it, perimeter wall and grid as before | yes |

The showcase recording's RESULT line: `RESULT showcase ok t=13.000 ticks=780 end_speed=0.000 distance=203.45 speed_max=24.000 speed_min=-9.000 y_min=0.0000 y_max=0.0000 tilt_max_deg=0.0000 wall_ticks=0 camera_outside_ticks=0 violations=0`.

## Acceptance criteria — what was measured

Measurements come from the two verification lenses of the implementation workflow (headless with `--fixed-fps 60`, and windowed at 1280×720) after fix pass 2, re-run on the final code. Raw outputs sit beside the workflow transcripts (`scratchpad/dev-story-001/`).

| AC | Result | Evidence |
|---|---|---|
| AC-1 launch straight into the scene, no menu | **PASS** | `run/main_scene = res://src/gameplay/driving_toy.tscn`; `commands.run` exit 0 in 1.4 s, 0 ERROR/WARNING lines; node tree: 27 nodes, exactly one `Unit` (Motorbike), one current `Camera3D`, no `Control`; screenshot 01 |
| AC-2 W/S throttle and reverse, A/D steer, coast to stop | **PASS** — measured, and confirmed on the real keyboard by the developer (2026-09-30, `/story-done`) | Input Map: `p1_throttle` W (87), `p1_reverse` S (83), `p1_steer_left` A (65), `p1_steer_right` D (68). Throttle held 2 s → 24.000 m/s (100 % of `max_speed`, 90 % reached at 1.08 s). Release → 0 in exactly 120 ticks = 2.000 s = `max_speed / coast_deceleration`, drift 0.00000 m. Reverse floor −9.000 = `reverse_max_speed`. Brake from 24 m/s: 40 ticks = `max_speed / braking`. Steering at standstill: yaw 0.000°; W+A 1 s: +67.95° |
| AC-3 arcade kinematic, never tips/bounces/sticks | **PASS** | `class_name Unit extends CharacterBody3D`, all motion in `_physics_process` via `move_and_slide()`, GROUNDED mode. Over coast, walls (3840 ticks), soak (18000 ticks) and per-tick probes: y in [0.0000, 0.0010], rotation x/z 0.0000000, `velocity.y` 0.00000 every tick, `is_on_floor()` never false. Walls scenario: 8/8 wall and corner targets reached, 0 PINNED; escape from a corner ≥ 21.3 m within 3 s |
| AC-4 every feel value from a `.tres` | **PASS** | Only structural literals in `unit.gd`, `player_drive_input.gd`, `chase_camera.gd`. A scratch copy of `motorbike_stats.tres` with `max_speed` 48 doubles the measured top speed (24.000 → 48.000): the value is data |
| AC-5 smooth chase camera, no visible jitter at 60 fps | **PASS** — measured, and judged smooth by eye by the developer (2026-09-30, `/story-done`) | Camera updates in `_process` from `get_global_transform_interpolated()`; `physics/common/physics_interpolation = true`. Per-rendered-frame camera displacement while cruising: at native 120 Hz vsync CV 0.02–0.08, 0 identical consecutive frames; capped at 60 fps (`--max-fps 60`) CV 0.030; with irregular frame times (`--disable-vsync --max-fps 60`) CV 0.070. Screenshot 03 shows the framing |
| AC-6 cannot leave the playfield or fall through | **PASS** | Walls scenario: 0 violations, extremes x ∈ [−39.19, 39.17], z ∈ [−39.19, 39.19] (inner wall faces ±40). Soak: 300 simulated s, seed 20260930, 3978.8 m driven, 0 violations, y ≥ 0.0000, wall-clock 5.1 s |
| AC-7 60 fps at 1280×720 | **PASS** | Harness `fps` scenario windowed: per-second fps [76, 119, 119, 120, 120, 119, 119, 120, 119, 119] (first second is start-up), steady average 119.3 on the 120 Hz display; with vsync off 436 fps average (≈ 2.3 ms/frame); 0 ERROR/WARNING lines |
| AC-8 fun to drive for five minutes | **PASS** — human judgement | Confirmed by the developer at `/story-done` on 2026-09-30 ("Yes — passes"). No value was changed to get there: the tuned values below are the ones measured |

## Tuned values (the data the numbers above were measured with)

`src/gameplay/units/data/motorbike_stats.tres`: `max_speed` 24.0 m/s · `acceleration` 20.0 m/s² · `braking` 36.0 m/s² · `coast_deceleration` 12.0 m/s² · `reverse_max_speed` 9.0 m/s · `turn_rate` 2.8 rad/s · controller: `ground_snap_length` 0.1 m, `wall_min_slide_angle_degrees` 15, `blocked_speed` 0.5 m/s.
`src/gameplay/camera/data/chase_camera_settings.tres`: `offset` (0, 7, 13) m · `follow_sharpness` 8.0 /s · `look_height` 1.0 m.
Starting values came from the concept prototype (`prototypes/wasteland-fire-concept/REPORT.md`); nothing was re-tuned by a human yet — that is AC-8.

## Verification of the build itself

- `godot --headless --path . --import`: clean (only the expected note that `prototypes/` holds another `project.godot` and is ignored — `prototypes/.gdignore` makes that explicit).
- Parse check, exit 0, `ok:` for all eight scripts: `driving_toy.gd`, `maps/greybox_field.gd`, `camera/chase_camera.gd`, `camera/chase_camera_settings.gd`, `units/unit.gd`, `units/unit_stats.gd`, `units/player_drive_input.gd`, `tools/evidence/drive_harness.gd`.
- Main scene headless, 120 frames: exit 0, 0 ERROR/WARNING lines.
- Verification lenses after fix pass 2: engine review, standards review, headless AC measurement and windowed AC measurement all returned clean (0 open issues).

## Notes, gaps and decisions recorded here

- **Grid floor shader** (`src/gameplay/maps/spatial_env_grid_floor.gdshader`) was not in the story; it is accepted as the speed and jitter reference for AC-5/AC-8 — a featureless plane shows neither.
- **Slopes are not covered.** The field is flat by AC-1; a throwaway preflight probe (not retained) found the box collider climbs 20–30° ramps and stops at 35°+. Story 007 (the Map) must add a slope scenario to `tools/evidence` before any Map slope exceeds 30°, or use a chamfered collider.
- **`wall_min_slide_angle` applies in GROUNDED mode under Jolt on 4.7.2**, although the class reference says it only affects FLOATING (measured: a hit 10° off head-on stops dead at 15, slides at 0). It is a data value (`wall_min_slide_angle_degrees`), so the head-on "stop dead" feel is a knob for AC-8.
- **Blocked-speed rule:** a Unit pinned against a wall keeps its commanded speed (so it can steer itself free at full turn rate); if the throttle is then pushed the other way it drops that speed at once (moves after 2 ticks instead of 42). Same class of fix the prototype report asked for.
- **Keyboard ghosting** (two hands on one keyboard) is untested here — Story 002 owns it.
- **Tech debt to register with `/tech-debt add`:** `tools/evidence/drive_harness.gd` is 622 lines with ~40 instance variables across five scenarios and hardwires Player 1; split into one `RefCounted` per scenario when Story 002 needs a second Player (Category: Code Quality, Effort M, Impact Low, Backlog).
- **Out of this changeset:** `assets/art/**` (a Wasteland Buggy concept model made in another session on 2026-09-30) is not part of Story 001; commit it separately if at all.

## Sign-Off

A **Visual/Feel** story needs the lead sign-off below. A solo developer signs as themselves (`.claude/docs/templates/test-evidence.md`).

- **AC-8 five-minute drive — verdict:** fun as tuned, no retune (values above unchanged since 2026-09-30 12:05). Answered "Yes — passes" at `/story-done`, along with AC-2 (real keyboard) and AC-5 (look of the camera).

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Lead (art-director / designer) — solo developer | Tomas Kunzo | 2026-09-30 | [x] Approved |

*Sign-off recorded from the developer's answer to the `/story-done` Visual/Feel question on 2026-09-30; not filled in by an agent on its own.*

---

*Template: `.claude/docs/templates/test-evidence.md`*
*Used for: Visual/Feel and UI story type evidence records*
*Location: `production/qa/evidence/story-001-driving-toy-evidence.md`*
