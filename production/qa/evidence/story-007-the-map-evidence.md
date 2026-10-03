# Story 007 — Map 01: test evidence

**Story:** `production/epics/wasteland-fire/story-007-the-map.md` · **Type:** Visual/Feel · **Layer:** Presentation · **Estimate:** XL, one story, built layout first and look last
**Engine:** Godot 4.7.2.stable.official.ed1daf0bf, Jolt Physics, Forward+ (Metal 4.0), physics interpolation on, 60 physics ticks/s
**Machine:** macOS 26.5.2 (Darwin 25.5.0) arm64, Apple M4 Pro, 120 Hz built-in display · **Date:** 2026-10-02 to 2026-10-03 · **Run by:** `/dev-story` in six workflows: the layout preflight (`wf_0e36fc46-eb5`, four engine probes A to D) and the look preflight (`wf_d4f62d46-f57`: textures and materials, the kit Unit models); the layout build (`wf_4769cd3a-b5f`: twelve slices, the architecture, standards and headless lenses, two fix rounds) with its engine review split in two (`wf_07eedb08-180`: code and scenes, measured physics); the look build (`wf_456fbf7d-201`: slices K1 to K7 and the first review round) and the look review (`wf_391ea8bd-3ab`: two fix rounds between three review rounds; the orchestrator stopped the third after its standards and engine lenses had reported). Then the orchestrator by hand: the last fixes (below), the final verification chain, the windowed recordings, the frames and this document.
**Gate level:** Visual/Feel = BLOCKING (retained screenshots and the lead sign-off at the end). Tests are waived at `qa.level: minimal`: none was written and nothing under `tests/` changed. The layout's rules (AC-2 to AC-9) are measured by evidence scenarios on Map 01 under `tools/evidence/`, as stories 005 and 006 did, with every older baseline still byte-identical on the greybox field.

## Run result

`Run result: OBSERVED — commands.run (godot --path . --windowed --resolution 1280x720, no scene argument, recorded with --write-movie --quit-after 90) opens Map 01 in the two views with both Players choosing: each view looks out of its own Garage (the rust hexagon floor, dark walls, the Team-coloured dashed rectangle) at its Base's water tower on dark legs, the tank in the Team colour (Orange left, Teal right) and the Flag on its seat under it, the corner towers in the Team colour, the salt flat beyond and the other Base's tower on the horizon; each view's HUD band and choice panel carry an Orange or a Teal edge (01-launch-garages-towers-and-choice-panels.png). The map_showcase and map_legibility recordings show the Units appearing in their Garages (02), under the water towers (03), each Base with its gate and tower (04), each tower from the salt flat's four corners and its centre (05 to 09), the depot (10), the fords (11), the eight bends of the canyon road with the Unit in view (12 to 19), the Gyrocopters over the canyon walls and the ridge (20, 21) and at the shore (22), each Motorbike carrying the opponent's Flag with its cream nose in view (23 to 25), the Gyrocopter of each Team colour over channel water at 40 m (26 to 29) and a Flag, a Fuel Can and a Unit at 40 m over sand, salt flat, canyon road and ford (30 to 33); 34 is the Map from above.`

## The runs

All on the final code on 2026-10-03, windowed at 1280 × 720 (`godot --path . --windowed --resolution 1280x720 ...`), the display woken before each (`caffeinate -u`), every Player key a real `InputEventKey` through the Input Map.

**Launch** (`commands.run` plus `--write-movie <dir>/f.png --quit-after 90`): 90 frames, rc 0, no ERROR or WARNING (`scenario-outputs/windowed-launch-recording.txt`). Nothing moves while both Players choose; frame 89 is 01.

**The Map showcase** (`res://tools/evidence/split_screen_harness.tscn -- --scenario=map_showcase` with `--write-movie`): 1,940 frames at 60 fps, 32.28 simulated seconds, rc 0, no ERROR or WARNING. Player 2 steps to the Buggy and both confirm; then each moment is staged by `map_kit.gd`'s `stage()` (a place, three ticks, a typed spawn of the Unit in play, three ticks, full tanks) and held still or driven by real keys (the canyon road by the pursuit controller; the Flags by `drive_to_flags()`). Its 15 moments and 16 events printed the same frames, places and headings windowed as headless (`scenario-outputs/windowed-map_showcase-recording.txt` against `split-map_showcase.txt`: the SPLIT, CHECK and RESULT lines are identical).

| Frame | Moment or event | Player 1 (Orange) | Player 2 (Teal) | Retained |
|---|---|---|---|---|
| 59 to 123 | the choice panels; both Units appear in their Garages at frame 63 | Motorbike at the SpawnPoint (−125, 0), heading 90 (out of the gate) | Buggy at (125, 0), heading 270 | 02 (frame 63) |
| 189 | under_towers | Gyrocopter at (−109.5, 0), 3.5 m past its Flag's seat, facing the gate | Motorbike at (109.5, 0) | 03 |
| 255 | gates | Buggy 15 m out of Base A's gate, facing it | Truck 15 m out of Base B's gate | 04 |
| 321, 387, 453, 519, 585 | towers_north_west, south_west, north_east, south_east, centre | Truck at the salt flat's corners (−92, −15), (−92, 15), (88, −15), (88, 15) and centre (0, −11), facing Base A | Buggy at the mirrored corners and (0, −16), facing Base B | 05 to 09 |
| 651 | depot | Motorbike at (−20, 0) facing the depot | Truck at (20, 0) | 10 |
| 717 | fords | Buggy in FordWest at (−40, −12) facing south | Motorbike in FordEast at (40, −12) | 11 |
| 880 to 1290 | the road: p2_bend_1 to 4 at frames 880, 929, 1002, 1053; p1_bend_1 to 4 at 979, 1067, 1198, 1290 | Truck through the four west bends, west to east | Buggy through the four east bends, east to west | 12 to 19 |
| 1553, 1568, 1597 | p1_over_rock and p2_over_rock (1553), p1_off_rock (1568), p1_over_rock again (1597) | Gyrocopter north from (−14, −4): over the canyon's south wall at z −20.04, over the road, over the north rock at z −32.07 | Gyrocopter south from (70, 6): over the ridge's north edge at z 22.04 and on | 20, 21 |
| 1705 | gyro_end | stopped at the north shore, z −44.89 | stopped at the south shore, z 44.62 | 22 |
| 1867, 1938 | p1_takes_flag_of_p2, p2_takes_flag_of_p1 (1867); flags_taken (1938) | Motorbike in through Base B's gate, takes the Teal Flag under the tower at x 110.98 | Motorbike in through Base A's gate, takes the Orange Flag | 23 (1938); crops 24, 25 |

`RESULT map_showcase ok checks=0 failed=0 t=32.283 moments=15 spawns=p1_motorbike,p2_buggy road_done=true,true rock_ticks=61,90 flag_ticks=167 destroyed=0`

**The legibility frames** (`--scenario=map_legibility` with `--write-movie`): 400 frames, 6.6 simulated seconds, rc 0, no ERROR or WARNING, the same SPLIT and RESULT lines windowed as headless (`windowed-map_legibility-recording.txt`, `split-map_legibility.txt`). The two Units face each other so each camera, 13 m behind and 7 m above its own Unit, sees the other about 40 m away; beside the other Unit stand a Fuel Can and the viewer's own Flag, so across the two views a Flag and a Unit of each Team colour and a Fuel Can stand 40 m from a camera.

| Frame | Moment | Distances (camera 1 / camera 2 to the far Unit, Can, Flag), metres | Retained |
|---|---|---|---|
| 68 | channel_p1_gyrocopter: Orange Gyrocopter over the west channel (−40, 36), Teal one in the west ford (−40, 9.6) looking south at it | 40.0 / 40.0 to the other Gyrocopter | 26, crop 28 |
| 134 | channel_p2_gyrocopter: the same with the colours swapped | 40.0 / 40.0 | 27, crop 29 |
| 200 | sand (west of Base A) | 40.6, 40.8, 40.8 / 40.6, 40.8, 40.8 | 30 |
| 266 | salt_flat | 40.6, 40.8, 40.8 / the same | 31 |
| 332 | canyon_road | 40.6, 40.7, 40.7 / the same | 32 |
| 398 | ford | 40.6, 40.7, 40.7 / the same | 33 |

`RESULT map_legibility ok checks=0 failed=0 t=6.600 moments=6 worst_miss_m=0.80 destroyed=0`

**The frame-rate route** (`--scenario=map_fps`, no movie, twice back to back; `windowed-map_fps-run1.txt`, `run2.txt`): Player 1's Motorbike drives out of Base A's gate and over the salt flat end to end while Player 2's Buggy drives the canyon road end to end; then each drives in through the other Player's gate. Both runs printed the same 17 one-second samples:

`RESULT map_fps ok checks=0 failed=0 t=17.500 fps_avg=117.9 fps_avg_steady=120.0 fps_min=84.0 fps_min_steady=120.0 refresh_hz=120.0 draw_calls_max=257 primitives_max=118796 samples=17 legs=flat_and_road:ok,into_bases:ok display=macOS`

The 84 fps is the first second of the run, left out as story 005 left it out; every later second is 120.0, the display's refresh. Draw calls per sample 146 to 257 for both views together (the peak in the first second), against the provisional budget of 1,000.

**The Map from above** (34): `map_01.tscn` alone, an orthographic camera 500 m up looking straight down, 330 m across (a scratch tool, not in the repo).

## Retained screenshots (`production/qa/evidence/story-007-the-map/`)

All from the final code on 2026-10-03: 01 is the literal `commands.run` plus `--write-movie --quit-after 90`; 02 to 23 are frames of the `map_showcase` recording and 26, 27 and 30 to 33 of the `map_legibility` recording, each the PNG the scenario's `frame=` names for its moment or event; 24, 25, 28 and 29 are 4 × enlargements (macOS `sips`, which smooths the pixels) of a 160 × 120 or 160 × 100 px crop of 23, 26 and 27; 34 is the scratch top-down tool's frame of `map_01.tscn`. Each view is 640 × 720: Player 1 (Orange, Base A, west) on the left, Player 2 (Teal, Base B, east) on the right. Every image below was opened and looked at before it was described.

| File | Source | What it shows | AC | Inspected |
|---|---|---|---|---|
| `01-launch-garages-towers-and-choice-panels.png` | launch, frame 89 | Both views from the Garages at the Round's start, both Players choosing: the rust Garage floor with its dark crack pattern, the dark Garage walls, the dashed rectangle in the Team colour, the water tower on dark steel legs with cross braces and its tank in the Team colour, the Flag (a small Team-coloured banded tank) on its seat under it, the corner towers in the Team colour, an olive container and black tyre stacks (dressing), the salt flat beyond and the other Base's tower on the horizon (Teal on the left, Orange on the right). HUD "HP 0 / 40", "Fuel 0 / 100", "Your Water Canister is at home" in an Orange-edged band (left) and a Teal-edged band (right); "Choose your Unit" panels with the same edges | 6, 10, 11, 12 | yes |
| `02-units-appear-in-the-garages.png` | showcase, frame 63 | The Orange Motorbike (from behind, its cream patch on top) on Base A's Garage floor and the Teal Buggy on Base B's, each in full view of its camera; the HUD's green "HP 40 / 40" and amber "Fuel 50 / 100" bars inside the Orange edge, "HP 100 / 100" and "Fuel 50 / 100" inside the Teal one: the amber bar reads yellow against the Orange edge | 11, 13 | yes |
| `03-units-under-the-water-towers-flags-on-their-seats.png` | showcase, frame 189 | Each camera looks between the water tower's legs toward the gate: the Orange Gyrocopter just past its Flag (the Orange tank on its seat in front), the Teal Motorbike just past the Teal Flag; both Units in view under the tanks; the Team-coloured dashes in the foreground | 12, 13 | yes |
| `04-both-bases-with-gate-and-water-tower.png` | showcase, frame 255 | Each Base from 15 m out of its gate: the gate between the dark walls, the four corner towers and the water tower's tank in the Team colour, the Garage at the back; the Orange Buggy facing Base A, the Teal Truck facing Base B, on the cracked salt flat | 6, 11, 12 | yes |
| `05-water-towers-from-the-salt-flat-north-west.png` | showcase, frame 321 | From the salt flat's north-west corner (the mirrored corner on the right) each Player's Truck or Buggy faces its own Base: the whole tower stands above the walls, the corner towers beside it; the canyon rock's south edge in the foreground | 13 | yes |
| `06-water-towers-from-the-salt-flat-south-west.png` | showcase, frame 387 | The same from the south-west corner; the ridge's edge at the side | 13 | yes |
| `07-water-towers-from-the-salt-flat-north-east.png` | showcase, frame 453 | From the far, north-east corner: each Base's tower on the horizon about 200 m away, in view over the wrecks, the fords and the depot's grey tanks | 13 | yes |
| `08-water-towers-from-the-salt-flat-south-east.png` | showcase, frame 519 | The same from the far south-east corner; red Fuel Cans on the flat; the ridge on the left | 13 | yes |
| `09-water-towers-from-the-salt-flat-centre.png` | showcase, frame 585 | From the centre: the Orange Truck faces Base A with the Teal Buggy beside it, the Teal Buggy faces Base B with the Orange Truck beside it, both towers in view; the depot's grey tanks, dark posts and red Cans close by | 11, 13 | yes |
| `10-the-depot.png` | showcase, frame 651 | The depot from 20 m each side: the three grey fuel tanks on rust bands and the dark posts (dressing), the five red Fuel Cans in their dice-five pattern, the dark dashed ring, the rust scrap walls behind; Base B's tower beyond on the left, Base A's on the right | 7, 8, 10, 11 | yes |
| `11-the-fords.png` | showcase, frame 717 | The Orange Buggy in FordWest's light-cyan water and the Teal Motorbike in FordEast, both facing south toward the ridge's navy channel between rust ridge blocks; wrecks and a red Fuel Can on the salt flat beside | 5, 10 | yes |
| `12-canyon-road-east-bend-1.png` | showcase, frame 880 | Right: the Teal Buggy at the first east bend (76.7, −28.5) between the 2 m rust walls, in full view; left: the Orange Truck entering the west straight, FuelCanCanyonWest just ahead of it | 4, 13 | yes |
| `13-canyon-road-east-bend-2.png` | showcase, frame 929 | The Teal Buggy at the second east bend (62.8, −36.0) | 4, 13 | yes |
| `14-canyon-road-west-bend-1.png` | showcase, frame 979 | The Orange Truck at the first west bend (−76.7, −28.5) | 4, 13 | yes |
| `15-canyon-road-east-bend-3.png` | showcase, frame 1002 | The Teal Buggy at the third east bend (39.3, −34.1) | 4, 13 | yes |
| `16-canyon-road-east-bend-4.png` | showcase, frame 1053 | The Teal Buggy at the fourth east bend (23.9, −28.0), the salt flat and Base A's tower beyond the rock | 4, 13 | yes |
| `17-canyon-road-west-bend-2.png` | showcase, frame 1067 | The Orange Truck at the second west bend (−62.9, −36.1) | 4, 13 | yes |
| `18-canyon-road-west-bend-3.png` | showcase, frame 1198 | The Orange Truck at the third west bend (−39.4, −34.1) | 4, 13 | yes |
| `19-canyon-road-west-bend-4.png` | showcase, frame 1290 | The Orange Truck at the fourth west bend (−24.0, −28.0); each view sees the other Unit at the far end of the road (the Buggy waits at its end) | 4, 13 | yes |
| `20-gyrocopters-over-canyon-wall-and-ridge.png` | showcase, frame 1553 | The Orange Gyrocopter risen over the canyon's south wall and the Teal Gyrocopter over the ridge's north edge: body and rotor above the rock, the shadow on the rock top | 4, 13 | yes |
| `21-gyrocopters-over-canyon-rock-and-ridge.png` | showcase, frame 1597 | The Orange Gyrocopter over the north canyon rock, the Teal one over the ridge, both above the rock with the sea beyond | 4, 13 | yes |
| `22-gyrocopters-at-the-north-and-south-shore.png` | showcase, frame 1705 | Both Gyrocopters at the island's edge, the north shore and the south shore, over the rock with the sea ahead; `map_edges` measures the stop | 3 | yes |
| `23-motorbikes-carry-the-flags.png` | showcase, frame 1938 | Each Motorbike inside the other Player's Base under its water tower, carrying that Flag; both HUDs read "You carry the enemy Water Canister"; the Base's corner towers and tank in its Team colour above | 6, 11, 12 | yes |
| `24-crop-orange-motorbike-carries-teal-flag-cream-nose.png` | crop of 23, left | The Teal Flag (banded tank, dark lid) on the Orange Motorbike's back; above it the bike's cream tank-top patch and handlebar: the cream nose in view; the carried Flag keeps its owner's colour | 11, 12 | yes |
| `25-crop-teal-motorbike-carries-orange-flag-cream-nose.png` | crop of 23, right | The Orange Flag on the Teal Motorbike, the cream patch above it | 11, 12 | yes |
| `26-40m-orange-gyrocopter-over-channel-water.png` | legibility, frame 68 | Right: from the ford, Player 2's camera looks south down the west channel at the Orange Gyrocopter over the navy channel water 40 m away; left: the Teal Gyrocopter over the light-cyan ford 40 m away | 13 | yes |
| `27-40m-teal-gyrocopter-over-channel-water.png` | legibility, frame 134 | The same with the colours swapped: left, the Teal Gyrocopter over the channel water 40 m away | 13 | yes |
| `28-crop-orange-gyrocopter-over-channel-40m.png` | crop of 26, right | The Orange Gyrocopter at 40 m over the channel water between the ridge walls: body and rotor tips clear | 13 | yes |
| `29-crop-teal-gyrocopter-over-channel-40m.png` | crop of 27, left | The Teal Gyrocopter at 40 m over the channel water: told apart, at a lower contrast than the Orange one (the weakest pair, notes below) | 13 | yes |
| `30-40m-flag-can-unit-over-sand.png` | legibility, frame 200 | On the sand west of Base A: 40 m from each camera the other Player's Motorbike, a red Fuel Can and the viewer's own Flag; nearer, the viewer's Motorbike with the other Flag and a Can (the other camera's trio) | 13 | yes |
| `31-40m-flag-can-unit-over-salt-flat.png` | legibility, frame 266 | The same over the salt flat | 13 | yes |
| `32-40m-flag-can-unit-over-canyon-road.png` | legibility, frame 332 | The same on the canyon road between the rock walls | 13 | yes |
| `33-40m-flag-can-unit-over-ford.png` | legibility, frame 398 | The same over the ford's light-cyan water | 13 | yes |
| `34-map-01-from-above.png` | top-down, 1650 × 600 | The whole Map: the island in the navy sea, the canyon rock with its road in the north, the cracked salt flat, the two cyan fords, the ridge cut by the two navy channels in the south, Base A in the west with Orange corner towers, dashed rectangle and tower dome, Base B in the east in Teal, the depot ring with three tanks, posts and five Cans, the eight wrecks, two long containers and two scrap walls, boulders on the sand; for comparison with `design/source/map01_colored.png` (AC-15) | 1, 10, 15 | yes |

Recording checks: the launch 90 PNGs for `--quit-after 90`; the showcase 1,940 PNGs (the engine's own count) for 32.28 s; the legibility recording 400 PNGs for 6.6 s; no ERROR or WARNING in any of them. The look review counted 0 magenta (missing-texture) pixels in every frame of its own recordings of both scenarios and found the first drawn frame fully textured (`measurements/look-review-measurements-extract.txt`).

## Acceptance criteria — what was measured

All Godot runs headless with `--fixed-fps 60` unless the row says windowed. "Final run" is the orchestrator's verification chain on the final code (`measurements/final-verification-chain.txt`); the scenario outputs are under `scenario-outputs/`; "the look review" is the look workflow's lenses (`measurements/look-review-measurements-extract.txt`), "the layout review" the layout workflow's (`measurements/layout-review-lenses-round1.txt`, `layout-review-and-fix-results.jsonl`).

| Criterion | What was measured | Result |
|---|---|---|
| AC-1: Map 01 replaces the greybox field in the main scene, laid out from the blueprint at 1 m = 1 m, every entry within 1 m of the positions table | `map_layout` `map_positions` (final run): Map 01 is World's child 0, 0 greybox nodes, the 9 Fuel Cans are the Map's; 129 table entries beside the built nodes (the table at the end): places and headings 0.000, extents at most 1.000 m (the gate edges 0.5 m: the 11 m gate; the channels' south ends 1.0 m: they run to the shore boxes), the island outline at most 0.9 m (made convex), the canyon rock's slanted ends 0.168 m, the ridge 0.032 m, the road and the depot ring 0.000; the canyon rock's north face built out to the shore, as the AC allows. Frame 34 | PASS |
| AC-2: mirror-symmetric about X = 0 within 0.1 m with mirrored headings; both halves listed | `map_mirror_data` (final run): 116 mirrored items (every collision shape, zone, `SpawnPoint` marker, Flag seat and Fuel Can spot, compared as sets of world-space shape vertices with x negated) and 6 on the axis, worst 0.0000 m; the positions table lists each west entry beside its east twin (headings −90 / 90, wreck yaws −30 / 30 and so on) | PASS |
| AC-3: the salt water is the edge and stops every Unit; the channels stop ground Units and the Gyrocopter crosses them; nothing at the edge does damage; the four Units on the four shores and at a channel | `map_edges` `edge_shore` (final run): 32 shore boxes on the map layer, thinnest 2.00 m; each of the four types driven at full throttle into the west, east, north and south shore (16 runs) stops with its centre its half-length inside the outline (Motorbike 1.30, Buggy 1.50, Truck 2.20, Gyrocopter 1.20 m), y 0.000, end speed 0.00, and the shot-layer ray ends on the outline (0.000); at a channel the Motorbike, Buggy and Truck stop flush with the water (at most 0.002 m in) and the Gyrocopter crosses 6.00 m into it. The layout review cast 672 rays at the shore chain: 0 misses. No damage, by construction: a Unit loses hit points only through `apply_damage()` (a Shot, the debug key), `destroy()` (Self-destruct, the Fuel crash) and `leave_play()` (the bench), nothing under `src/gameplay/maps/` calls them, and the shore, cliff and water bodies carry no script. The island's west and east tips have no 15 m straight run-up behind the Bases, so `map_edges` casts rays there (they hit the shore boxes) and the layout review's second round drove its own angled runs into all four tip shores with every type: no Unit left the island. Frame 22 | PASS |
| AC-4: the ridge and the canyon walls are cliffs (ground Units stop, the Gyrocopter crosses, shots pass through); each ground Unit drives the road end to end both ways; no way round the canyon's north side | `map_edges` `edge_cliffs` (final run): at the canyon's south wall, its north rock and the ridge every ground Unit stops (wall contact flush, at most 0.002 m in) and the Gyrocopter crosses (1.87, 26.13 and 12.92 m in); two shots fired north from z −6 and south from z 4 end at (−14.00, −46.10) and (40.00, 46.03): through the canyon rock and the ridge, stopped by the shore boxes. The road, throttle and steering only (the pursuit controller), no reverse: Motorbike 8.86 s, Buggy 10.84 s, Truck 19.50 s, the same west to east and east to west, lowest speed after the start 23.67 / 19.60 / 10.90 m/s, 0 wall-contact ticks; the road is open at X = 0. The north rock reaches the shoreline (`map_layout`). Frames 12 to 21 | PASS |
| AC-5: inside a ford a ground Unit's speed is clamped to 0.5 × its top speed (data in the Map); the Gyrocopter at full speed; asserted within 0.1 m/s from the 4th tick after the centre crosses in to the 4th after it leaves | `map_ford` `ford_speed` (final run): both fords read 0.50 from one shared `ford_settings.tres`; at top speed into each ford on a lane at z −16: the drive speed and the measured speed (the move in a tick × 60) held at 12.000 (Motorbike, 61 and 60 ticks in the window), 9.800 (Buggy, 74) and 5.450 m/s (Truck, 134); the cap bites 2 to 21 ticks before the centre crosses in and lifts 10 to 27 ticks after it leaves (the box's front reaches the ford before its centre and its back leaves after it, plus the zone's one tick of latency and the cap's one tick of grace), top speed again 45 to 62 ticks after leaving; 0 wall contacts; the Gyrocopter at 16.400 m/s across both fords, never capped. The turn rate keeps `stats.max_speed` as its denominator (`unit.gd`, unchanged turning law); Fuel burns per second as in story 006 | PASS (the cap lifts on the third tick after the box has left the ford, not the first after the centre: decision log 2026-10-02) |
| AC-6: walled compounds about 30 × 32 m with one gate about 10 m wide facing the centre; walls stop every Unit and shot; the Garage at the back, roofless, with its three `SpawnPoint` markers; the Flag's seat under the tank at (∓113, 0); each type drives out from every marker touching nothing; a Motorbike raids the opponent's Flag | `map_bases` `base_exits` (final run): 24 runs (4 types × 3 markers × 2 Bases), straight from standstill to Base-local z −30, no steer key: Motorbike 2.05 s, Buggy 2.37, Truck 3.82, Gyrocopter 2.68, 0 wall-contact ticks, least gap to a wall, a tower or a leg 0.800 / 0.600 / 0.300 / 0.700 m. `base_flag_run`: a Motorbike from Base 2-local z −50 drives in on the gate axis; the Round's own pick-up takes Player 2's Flag at local z −8.20 (seat −7.00, under the tank); **a reverse was needed**: no forward-only route exists at the Motorbike's 8.57 m turn radius inside the gate, so it backs 27.60 m straight out with no steer key, turns outside, drives home along z −15.5 at least 3.07 m from every cover box and delivers: won after 18.22 s, 0 wall contacts. The walls (outer faces X −135..−105, Z −16..16, 1.3 m thick) are map-layer boxes, the layer `map_cover` measured stopping the Gyrocopter and every shot; the gate is 11 m (decision log). Frames 01 to 04, 23 | PASS |
| AC-7: static cover (eight wrecks, two long containers, two scrap walls) stops every Unit, the Gyrocopter included, and every shot; every depot Can reachable by the Truck | `map_cover` `cover_stops` (final run): at a wreck, a long container and a scrap wall in each half, the Gyrocopter and a ground Unit (the Motorbike at the wreck, the Buggy at the container, the Truck at the scrap wall) drive head-on at full throttle, each firing one shot: every Unit meets the face at its top speed and stops within 1 tick with its centre its half-length from the face (gap at most 0.003 m, end speed 0.00); every shot ends on the face (12 runs, 12 shots). A Truck on its spawn tank then passes each of the five depot Cans and takes all five | PASS |
| AC-8: the nine Fuel Can spots; for each type on its spawn tank, how far it gets and whether it reaches its nearest Can, the depot and the opponent's Flag | Spots: the positions table (all 0.000 m). Reach: the table below | PASS |
| AC-9: the Map is a scene holding its Bases, Garages, Flag seats, Can spots, ford fraction and Token stock as data; one floor slab at one height under everything | `map_mirror_data` (final run): Tokens Motorbike 5, Buggy 3, Truck 2, Gyrocopter 2 (`data/token_stock.tres`, read through `count_of()`), the two fords share `ford_settings.tres` at 0.50, each Base its own 3 `SpawnPoint` markers, `first_spawn_problem()` none, loose start markers in Map 01 0; one floor box X −150..150, Z −50..50 on the map layer, top y 0.000, under the rock, the water and the island; only the scripts the story names in the Map (`map_field.gd`, `ford.gd`, `base.gd`, `water_canister.gd`, `fuel_can.gd`). `SplitScreen.field` is a `MapField` export and the Map is World's first child, so another Map scene needs no script change | PASS (the greybox field keeps its two loose markers: TD-005, below) |
| AC-10: everything built from built-in meshes with code-generated textures in one flat low-poly palette after the illustrated drawing; no imported kit or mesh; the drawing's props are dressing with no collision; the corner towers part of the walls | The Map's scenes, the Flag, the Fuel Can and the four model scenes hold only `BoxMesh`, `CylinderMesh`, `SphereMesh`, `PlaneMesh`, `TorusMesh` (in `MultiMesh`es) and `CSGPolygon3D`, and nine `NoiseTexture2D` files (`FastNoiseLite` and a `Gradient`) generated at load, byte-identical to the look preflight's recipes; no image or mesh file is referenced. The four Units are the author's concept kit (`assets/art/vehicles/`, itself built from built-in meshes and code textures), merged at load into 4 surfaces a Unit by `kit_merge.gd`, its triangles conserved (8,208 / 10,324 / 9,896 / 4,120), never edited. The dressing (`map_01_dressing.tscn`) has 0 collision nodes; the look review found the collision text of every scene the look edited unchanged. The corner towers are map-layer boxes of the walls. The look review: 0 magenta pixels and the first drawn frame textured. Frames 01 to 34 | PASS (coherence: AC-15) |
| AC-11: every model and Base in its owner's Team colour, none mixed; the Team materials as data, the older body materials untouched; the HUD and choice panel edged in the Team colour, the HP green and the Fuel amber kept and told apart from Orange; nothing neutral in a Team colour or the Fuel Can red; the Fuel Cans red | `team_orange_material.tres` (0.90, 0.45, 0.14) and `team_teal_material.tres` (0.18, 0.60, 0.58), roughness 0.7, metallic 0.05, vertex colour as albedo. Through the real `Unit.spawn()`, 8 of 8 (4 types × 2 Teams) paint only the model's Accent mesh; each Base paints 22 meshes in its colour (the hidden pad, the tank, the 4 corner towers, the 14 dashes, the tower's roof, the Flag's body) and 0 Team-coloured meshes are outside their Base. HUD bands and choice panels: `team_orange_edge.tres` / `team_teal_edge.tres`, 3 px; the Fuel amber (0.96, 0.70, 0.18) measures CIE76 dE 32.6 against the Orange edge in the frame. The 9 Fuel Cans (0.78, 0.08, 0.10); the walls dark, the Garage floor rust, the cover rust, the posts dark steel, the containers olive, the water navy and cyan. `player_1_body_material.tres` and `player_2_body_material.tres` unchanged, and `bases` (which prints their albedos) byte-identical. Frames 01 to 04, 09, 10, 23 to 25 | PASS |
| AC-12: the Flag a carryable tank about 1 m tall in its owner's colour, unlike any decoration, carried without hiding the Motorbike's cream nose; each Base's water tower the landmark at the Flag's seat, in the Team colour, replacing the Beacon | The Flag: a Team-coloured body r 0.28 m, h 0.72 m, steel bands r 0.30 m, a steel lid and base ring, 0.94 m tall in all; its pick-up zone unchanged. The cream heading cue: 60 px in the Motorbike's region from the chase camera with and without a carried Flag (38 to 60 px on every frame from 1860 to 1939 of the look review's recording, both views). The water tower: a Team-coloured tank r 4 m from y 8.3 to 13.3 with its roof dome, on four dark legs with braces from y 3.35; the tank is the Base's `beacon`. Frames 01, 03, 23 to 25 | PASS |
| AC-13: towers in view from the salt flat's corners and centre; Flag, Fuel Can and Unit of either colour told apart at 40 m over sand, salt flat, canyon road and ford, and the Gyrocopter over salt water; no Unit hidden from its own camera | Towers: frames 05 to 09, both views, tank and corner towers in view out to about 200 m. 40 m, the look review's CIE76 dE of each object against the ground beside it: sand: Teal Unit 54, Orange Unit 38, Orange Flag 35, Teal Flag 56, Can 58 to 65; salt flat: 47 / 63 / 61 / 54 / 82 to 85; canyon road: Orange Unit 28 (the weakest surface pair), Orange Flag 31, Teal Unit 56, Teal Flag 50, Can 49 to 52; ford: Teal Unit 35 to 39, Teal Flag 33 to 38, Orange 81 to 92, Can 95 to 105. Gyrocopter over channel water: Orange body 67 to 69, rotor 70; **Teal body 30 to 32, rotor blades 21 to 33**. Hidden: the Garage (02), under the towers (03), the eight bends (12 to 19), over rock (20, 21): the Gyrocopter's model rises so its lowest point stays 0.25 m above the 2.0 m rock on every tick over rock (10 crossing runs, 0 ticks with a vertex inside rock) | PASS (the Teal Gyrocopter over the channel recorded for AC-15) |
| AC-14: windowed 1280 × 720, both Units over the salt flat, the canyon road and into each Base: lowest one-second rate at least 60 fps, at most 1,000 draw calls for both views, the first second left out | `map_fps`, windowed, twice: lowest one-second rate after the first second 120.0 fps (the display's 120 Hz), average 120.0, first second 84.0; draw calls at most 257, primitives at most 118,796, both views together. The main scene standing at the Garages measured 299 to 318 draw calls (the look review's runtime lens) | PASS |
| AC-15: the look judged coherent by a human against the illustrated drawing and the concept art, with a frame from each viewport | Not an agent's call: the frames 01 to 34 and the notes for the author below, judged by the developer | PASS — confirmed by the developer at `/story-done` on 2026-10-03, no notes |

Untested criteria: none. The look (AC-15), the behaviour on a real keyboard (AC-3 to AC-6) and the reading of the Team colours and of each Unit's visibility (AC-11, AC-13) were confirmed by the developer at `/story-done` on 2026-10-03 (Human checks below).

### AC-8: Fuel reach on the spawn tank (50 of 100)

A tick-exact model of `unit.gd`'s movement and burn at 60 Hz (`measurements/fuel-reach-model.py.txt`, output `fuel-reach-model-out.txt`), with the fords' half speed on the routes that cross them, distances from the `SpawnPoint` marker (−125, 0) through the gate: the nearest Fuel Can (−88, −26) 59 m, the depot's nearest Can 122 m (through FordWest), the opponent's Flag (113, 0) 238 m (through both fords). Story 006's Fuel values, unchanged.

| Type | Open ground, full throttle | Nearest Fuel Can | The depot | The opponent's Flag | The Flag after the depot's Can (+40) |
|---|---|---|---|---|---|
| Motorbike | 610.0 m in 27.0 s | yes, 43.9 Fuel left | yes, 37.4 left | yes, 26.4 left | yes |
| Buggy | 400.2 m in 22.0 s | yes, 41.0 left | yes, 31.2 left | yes, 14.5 left | yes |
| Truck | 185.1 m in 18.5 s | yes, 31.9 left | yes, 10.9 left | **no**, stops at 162.8 m | yes |
| Gyrocopter | 155.2 m in 10.0 s (then it crashes) | yes, 29.2 left | yes, 10.2 left | **no**, crashes at 155.2 m | yes |

Checked in the engine on Map 01 (`fuel-reach-probe-out.txt`): a Gyrocopter on its spawn tank at full throttle from x −100 along z −16 crashes after 600 ticks 155.171 m on, as the model has it to the millimetre; a Truck the same way through both fords stops 147.0 m on where the model says 154.6, because the real zone holds the cap a little longer than the model's fords (the box's length and the zone's latency): the model is slightly optimistic for ground Units on routes through a ford, so the Truck's "no" stands and its 10.9 Fuel left at the depot is about 1 high.

## Stories 001 to 006 regression (on the greybox field)

- **Strict twenty, byte-identical, exit 0:** drive `coast`, `walls`, `showcase`, `soak`; split `layout`, `isolation`, `simultaneous`, `showcase`, `bases`, `destruction`, `countdown`, `respawn_showcase`, `units`, `weapons`, `gyro`, `choice`, `units_showcase`, `fuel`, `fuel_cans`, `fuel_showcase` (`dev07.py regress`, against outputs captured at HEAD 70b7320 before the story). **Soft four** (`canister_run`, `hud`, `round_over`, `canister_showcase`): `RESULT ok`, and all four byte-identical too.
- **How the older scenarios keep the greybox field:** the main scene now holds Map 01, so the runner rebuilds the old composition for the 21 split scenarios written before this story (`GREYBOX_SCENARIOS`, the 20 above plus story 002's `fps`): it instances `split_screen.tscn`, frees Map 01 under World, instances `greybox_field.tscn`, `terrain_stand_ins.tscn` and `greybox_fuel_cans.tscn` back at the same child indices under their old names, puts back the old blue and red body materials and the greybox Unit models in the cached data, and assigns `split.field`, all before `add_child(split)` (`_apply_greybox_composition()`; the preflight measured that both the tree order and the moment are load-bearing).
- **Frozen files** (the chase camera, its settings, `player_drive_input.gd`, `motorbike.tscn`, `driving_toy.gd` and `.tscn`, `drive_harness.gd` and `.tscn`): 9 of 9 byte-identical. The driving toy launches clean on the greybox field.
- **Unchanged:** `greybox_field.tscn`, `terrain_stand_ins.tscn`, `greybox_fuel_cans.tscn`, `base.tscn`, `player_1_body_material.tres`, `player_2_body_material.tres`, `match_controller.gd`, `garage_queue.gd`, `weapon.gd`, `shot.gd`, `player_match_input.gd`, `project.godot`. **`assets/`** unchanged (names, sizes and times against a snapshot taken before the story): the concept kit is read, never edited.

## Verification of the build itself

All run on the final code on 2026-10-03, 04:52 to 04:53 UTC, after the last edit (`measurements/final-verification-chain.txt`):

- **Import**: `dev07.py import` imports a scratch copy without `assets/`, `.git/`, `.godot/` and `production/` (the repo is never imported in place): rc 0, 235 classes, none new or gone since the repo's cache, no `.uid` sidecar to copy. The copy prints ERROR lines for the four kit scenes it does not hold (`res://assets/art/vehicles/*/wasteland_*.tscn`); the repo has them, and the launch below loads them clean. The class cache is written by the import only.
- **Parse**: the 24 `.gd` files the story added or changed: rc 0.
- **Launch**: the main scene for 120 frames and the driving toy for 60: rc 0, no ERROR or WARNING.
- **Scenarios**: `map_layout` (2 checks), `map_edges` (2), `map_ford` (1), `map_bases` (2) and `map_cover` (1) PASS; `map_showcase` and `map_legibility` `RESULT ok`; every output byte-identical to the outputs the evidence was written from (`scenario-outputs/`).
- **Windowed**: the three recordings and the two frame-rate runs above, rc 0, no ERROR or WARNING.
- **Standards counts** (`lint007.py`; counts, not verdicts): every top-level declaration has its `##` doc; no added `##` line over 100 columns. Four functions are flagged: `base.gd` `_ready` and `first_spawn_problem` at a rough complexity of 11 (the latter untouched by this story, the former one call longer), `kit_merge.gd` `_commit` as 45 lines (a counting artefact: the function is 16 lines and the tool counts the inner classes after it) and `kit_unit_model.gd` `_first_unset_rise_export` at 11 (four guard clauses joined by `or`). Sizes: `unit.gd` 735 lines (687 before, +48, TD-010), `kit_merge.gd` 365, `unit_choice.gd` 377, `player_hud.gd` 313, `base.gd` 255, `kit_unit_model.gd` 216, `split_screen.gd` 199; the runner 698 (542 before); the scenarios `map_edges` 454, `map_layout` 373, `map_cover` 303, `map_showcase` 298, `map_bases` 295, `map_ford` 280, `map_legibility` 203, `map_fps` 166 and the helper `map_kit.gd` 347 (TD-006).
- **Seeded defects**: the layout review's headless lens seeded 25 defects on scratch copies in each of its two rounds (a thin or missing shore box, the floor short of the channels, a wall without collision, the ridge or the channels or the containers on the wrong layer, the ford fraction or mask or lapse, a tower leg in a lane, a 6 m gate, the Flag's seat outside the zone, a dead delivery zone, a missing wreck or depot Can, Base 2 turned 90°, a Token count, a Fuel Can moved 2 m and more): every one made at least one CHECK fail, and in the second round each of the 9 checks was shown failing (`measurements/layout-review-and-fix-results.jsonl`). The look review's lenses probed the look code instead (the kit build's error paths with fake kits, the rise over rock tick by tick, the spawn cost and leaks).
- **Test evidence**: waived at `qa.level: minimal`. No test file was written and nothing under `tests/` changed.

## Measured engine facts the code comments point at ("the Story 007 evidence doc keeps the run")

1. **The ford zone's latency** (`ford.gd`, `map_ford.gd`): the zone lists a Unit on the tick after its box first overlaps and drops it on the tick after the box has left; with the ford before the Units in the tree (the Map is World's first child) the cap bites on the 2nd tick after the first overlap (the 3rd with the ford after the Units) and lifts on the 3rd tick after the box has wholly left; a Unit at 24 m/s is never skipped; the held speed is exactly 12.000000 / 9.800000 / 5.450000 m/s; 600 ticks of the patched Unit with `limit_speed(1.0)` every tick are hex-identical to the unpatched code (`measurements/layout-preflight-report.txt`, preflight C, lines 27 to 30, 85, 90 and 106). A position test of each Unit's centre in place of the zone lifts the cap 2 ticks after the centre leaves, so at the 4th tick after leaving the speed is 13.00 / 10.65 / 5.90 m/s against at most 12.1 / 9.9 / 5.55: it fails AC-5's window and is not used (the decision log's entry of 2026-10-02 says "at entry"; the measurement is after leaving). `map_ford` keeps the run: the cap bites 2 to 21 ticks before the centre crosses in and lifts 10 to 27 after it leaves.
2. **The typed Token stock** (`token_stock.gd`): a hand-written `Dictionary[StringName, int]` loads with its types; an untyped literal, String keys, a `Dictionary[String, int]` and a float 5.0 are converted; omitted counts give an empty typed dictionary; but one value that does not convert to an int (the probe's "five") prints `ERROR: Unable to convert value at key "motorbike" from "String" to "int".` and the whole dictionary loads empty, the Buggy's count lost too (preflight C2, line 48). So `map_mirror_data` asserts all four counts.
3. **`PrimitiveMesh.get_mesh_arrays()` is a read back from the GPU** (`kit_merge.gd`): 26 to 53 ms per model windowed against 0.3 to 0.5 ms headless; a whole rebuild 42.7 / 56.3 / 63.0 / 32.8 ms windowed (Motorbike, Buggy, Truck, Gyrocopter), a cached copy 0.1 ms (`look-preflight-report.txt`, lines 18, 57 and 97). Hence one build per kit, cached.
4. **The dark tone** (`kit_merge.gd` `DARK_TONE` 0.68), computed from the kit's palette constants: 0.68 × the Team albedo in sRGB gives Teal (0.122, 0.408, 0.394) against the kit's TEAL_DARK (0.11, 0.40, 0.40) and Orange (0.612, 0.306, 0.095) against ORANGE_DARK (0.62, 0.30, 0.10); in the linear space the renderer multiplies in (`vertex_color_is_srgb`) Teal (0.109, 0.401, 0.387) and Orange (0.610, 0.297, 0.081): at most 0.019 off in a channel. Measured: a mesh with no colour array renders the plain albedo under the same material (top (0.969, 0.502, 0.200), front (0.839, 0.431, 0.161) for Orange; `look-preflight-report.txt` line 33), so the Team materials paint the Bases, the Flags and the towers too.
5. **The neutral fold's roughness 0.8 and metallic 0.1** (`kit_merge.gd`) are a choice, not a measurement: the kit's own neutral materials range from roughness 0.25 (glass) to 1.0 and metallic 0.0 to 0.7 (steel) (`assets/art/shared/wasteland_palette.gd`), and 0.8 / 0.1 are the values the look preflight's merged variant was rendered and judged with.
6. **The first build of a kit model is a visible cost; the warm-up hides it** (`split_screen.gd`): with no warm-up, the cold builds windowed were Motorbike 107.9 ms, Buggy 54.5, Truck 60.5 and Gyrocopter 33.7 (256.7 ms); with it, `SplitScreen._ready()` (the Map plus the warm-up) took 254.5 ms and the cache held all four before `round_started`; after it the first `spawn()` of each type took 0.137 / 0.517 / 0.494 / 0.253 ms, ten respawns at most 0.696 ms, the frame after the first spawn 3.3 to 8.8 ms, and objects, nodes and orphans were unchanged over 40 respawns (the look review's runtime lens).
7. **The rise query returns the drawn cliff itself** (`kit_unit_model.gd`): a ray over the ridge reports `collider=RidgeCentre class=CSGPolygon3D is_GeometryInstance3D=true hit_y=2.000`, over the channel `collider=ChannelWest class=StaticBody3D is_GeometryInstance3D=false hit_y=1.500`, and the box query reports both canyon rocks as `CSGPolygon3D` (the K4 slice, `look-slice-reports.json`; `rise-ray-probe.gd.txt`); the round-3 engine lens measured the same and 0 rise violations in 5 cliffs × 4 headings.
8. **A CSG collider is reported once per overlapping piece** (`kit_unit_model.gd` `RISE_MAX_RESULTS` 64): with the Gyrocopter's real query box (a 1.40 × 2.40 m footprint, leads of 0 and 8 m, 8 headings, a 2 m grid over the island), of 89,040 queries 46,418 touched the cliffs layer; at most 11 results came back from one query, all one cliff; 203 queries returned 8 or more (the old cap); 266 had two cliff nodes in the box; at the old cap no second cliff was ever hidden and the top height never changed; no query reached 64 (`rise-query-cap-probe-out.txt`). The runtime lens saw at most 13 results in a tick of its crossings.
9. **The pursuit's look-ahead** (`map_kit.gd` `LOOK_AHEAD` 6 m): the Truck's largest distance from the centreline by look-ahead 4 / 6 / 8 / 10 / 12 m was 0.59 / 0.82 / 1.21 / 1.60 / 1.96 m; at 10 m or more it cuts the corners and touches even a 5 m road (preflight B, `layout-preflight-report.txt` lines 192 to 199). At 6 m every type drove the road 18 of 18 times with 0 contacts in each of four wall constructions.
10. **`map_edges`' watchdog** (300 simulated seconds): its runs take 136.5 (`RESULT ... t=136.517`).
11. **`map_edges`' penetration limit** (0.02 m): where a stop is flush a ground collider's corner goes at most 0.002 m into water or rock (the `pen=` values of `edge_shore` and `edge_cliffs`).
12. **The ford window** (`map_ford.gd`): the cap bites before the window opens and lifts after it closes, fact 1 and `scenario-outputs/split-map_ford.txt`.
13. **The layout's deviations from the positions table** (`map_layout.gd`): the table at the end of this document.

## Review rounds, and what became of each finding

- **Layout preflight** (`wf_0e36fc46-eb5`, four probes): binding corrections for every agent: a convex island outline with 32 separate 2 m shore boxes (a box chain on the drawn outline stopped angled Units in up to 172 of 428 runs per type; prisms and a trimesh ring leaked shots at seams); the canyon walls as CSG with mitred road edges (boxes overlapped past a bend trapped 18 of 18 wall-riding runs) and 2.0 m rock; the zone-polled ford over a position test (fact 1); the typed Token stock (fact 2); the greybox composition before `add_child`; the 11 m gate (at 10 m a Truck from a spare marker touched the gate wall in 4 of 6 runs); the reverse in the Flag run. Each is in the decision log of 2026-10-02.
- **Layout build** (`wf_4769cd3a-b5f`): twelve slices, then the architecture, standards and headless lenses and the engine review, which ran out of turns three times as one lens and was split into a code review and a measured-physics review (`wf_07eedb08-180`; the physics review measured everything clean, `measurements/layout-engine-physics-review.txt`). Rulings: the scenario sizes into TD-006; the exits end at Base-local z −30 because the wrecks at (±80, 5) stand in the spare lanes beyond; the water-tower legs stay 0.6 m posts (a Truck would keep 0.3 m of lane instead of 0.5 with 1 m legs; no Unit tunnels through 0.6 m at top speed). Two fix rounds; the headless lens's second round passed AC-1 to AC-9 with every seeded defect caught; one round-one gap (a missing depot Can passed `cover_stops`) was closed: the check now requires the five.
- **Look preflight** (`wf_d4f62d46-f57`): the nine noise texture recipes and their filters, the shadow distance (160 m cost 208 draw calls more than 100 m), and the kit: raw, two kit Units cost 2,330 draw calls in both views; merged one surface per material 234; folded to 4 surfaces a Unit (the variant built) 74, the greybox models' cost.
- **Look build** (`wf_456fbf7d-201`): slices K1 textures and materials, K2 Team materials, K3 the Flag, the tower and the Fuel Can, K4 the Unit models and the Gyrocopter's rise over rock, K5 the UI's Team edges, K6 the dressing, K7 the frames and the frame rate; then the first review round's architecture and engine lenses (10 issues; the others did not finish in this run).
- **Look review** (`wf_391ea8bd-3ab`, a new run with the first two lenses' results carried in): the rest of review round 1 (the standards, runtime, visual, art and headless lenses: 26 issues); fix round 1 split by area (gameplay, art, UI, tools); review round 2 (19 issues, the runtime lens clean); fix round 2; review round 3, stopped by the orchestrator once its standards and engine lenses had reported (11 issues). Rulings during the look: the tower's roof in the Team colour; the runner's TD-009 fix kept; the Truck's centring offset kept (a fix pass had removed it under a rule not meant for it, and the orchestrator put it back); the dark depot ring; no tint on the Garage floor; the `design/rules.md` edits kept; the scenario sizes and the 20-line growth of `map_kit.gd` accepted. Each is in the decision log of 2026-10-03.
- **Round 3's findings**, all closed by the orchestrator by hand: the `KIT_POSE` doc named the wrong kit (the Truck's kit exports `pod_yaw_deg`, the Gyrocopter's does not) — corrected; the rise exports were not validated (a scene with the rise on and its mask unset would hide the Gyrocopter in rock silently) — `_first_unset_rise_export()` now reports it; the neutral constants cited a scratch preflight — corrected, and then corrected again with fact 5; `map_showcase.gd` at 298 lines — TD-006; `design/rules.md`, the dark ring, the roof and the depot posts — kept and logged; the runner's TD-009 change — kept, TD-009 part 1 marked paid.
- **The orchestrator's own last pass**: the dressing's three inline materials confirmed moved into files; three doc comments corrected where the sources showed a computation or a narrower measurement than they claimed (`DARK_TONE`, the neutral constants, the Token stock's typed dictionary); the story's defaults for the sea edge, Base walls, cover and the canyon walls recorded in `design/rules.md` as built and still open, the ford fraction listed as a tuning value; Ford, Cover and Gate added to `CONTEXT.md` (the Slovak words left to the author); the final chain, the recordings and this document.

## Notes, gaps and decisions recorded here

- **TD-005 is paid for Map 01 only.** AC-9 says the loose `PlayerStart` and `Player2Start` markers are deleted. Map 01 has none: each compound Base points at its own three `SpawnPoint` markers. `greybox_field.tscn` keeps its two, because the frozen Story 001 drive harness writes `player_start.transform` as a field-space position and Story 007 may not edit that harness or that scene; the item stays open and closes with TD-001's split of the harness.
- **The ford's cap lifts on the third tick after the box leaves**, not "on the first physics tick after the Unit leaves" as AC-5 words it: the polled zone lists a Unit one tick late and the cap keeps one tick of grace. It lies inside AC-5's assertion window with ticks to spare; a position test lifting it sooner fails the window (fact 1; decision log 2026-10-02).
- **Deviations from the drawings and the positions table, each inside AC-1's 1 m or recorded:** the gate 11 m, not 10 (a Truck from a spare marker touched a 10 m gate); the island outline made convex (at most 0.9 m off the table); the channels run to the shore boxes (1.0 m); the canyon rock and the ridge run 1.9 to 2.9 m out over the sea past the shore (seen only from above); the water tower's legs 0.6 m posts, under the story's 1 m wall rule; the depot's first pair of posts at (±7.8, −3.36), 2.76 m from the drawn spot, which lies inside a dressing tank.
- **The Motorbike's raid needed a reverse** (AC-6 asks): no forward-only route exists at its 8.57 m turn radius inside the gate.
- **Built on the story's defaults, still open for the author** (recorded so in `design/rules.md`): the sea stops every Unit, the Gyrocopter included, so it crosses only the water inside the Map; Base walls and cover stop the Gyrocopter and every shot; the canyon walls are cliffs, so shots pass through them and the canyon gives no cover from fire.
- **Look decisions** (decision log 2026-10-03): the Sun's shadows reach 100 m; the water tower's roof dome wears the Team colour with the tank; the depot ring is the drawing's dark brown; the Garage floor keeps its rust; the Truck's model is centred on its collider (offset 0.1286 m), while the Motorbike's tail overhangs its collider by 0.06 m (the Flag's clearance was set with it); a Gyrocopter scene with the rise on and a rise value unset reports an error.
- **Departures from the illustrated drawing that no open question covers** (the look review's art lens): no pale shallow-water rim along the shore, no tyre tracks, every piece of cover in one rust material.
- **Fuel on Map 01** (AC-8): on its spawn tank the Truck and the Gyrocopter cannot reach the opponent's Flag without the depot's Cans; the Motorbike and the Buggy can. Story 006's values are unchanged; retuning is the author's call (open question 10).
- **The concept kit is a dependency.** The Units' models are the author's kit under `assets/art/vehicles/`, read and merged at load, never edited. The game relies on each kit script's `_m` palette and its keys, the `rust_seed`, `steer_deg` and `pod_yaw_deg` properties, the parts built in `_ready()` as `MeshInstance3D`s of built-in meshes, and the Motorbike's tank-top plate (0.36 × 0.02 × 0.28 m) as its cream heading cue. Most breaking edits are reported as an error naming the kit scene; a renamed property or a renamed `lamp`, `skull`, `screen`, `steel`, `flag` or `rust_orange` key is not, so check the Units in the game after editing the kit (`design/rules.md`, Teams and visual style).
- **Sizes**: `unit.gd` 735 lines (TD-010); the Map scenarios and their helper (TD-006).

## Notes for the author's coherence judgement (AC-15)

What the agents measured or saw that a person should judge, with the frames to look at:

1. **The Teal Gyrocopter over the channels' navy water** is the weakest pair: its body measures dE 30 to 32 against the water and one thin rotor blade 21 to 23 (frames 27 and 29; Orange over the same water 67 to 70, frames 26 and 28). The sea and the channels were darkened to navy from the drawing's teal-cyan so that water is never mistaken for Team Teal (open question 16).
2. **A Motorbike carrying the enemy Flag reads as the enemy's colour from its own camera**: the 0.94 m Flag rides between the chase camera and the bike, and the carrier's own Team-colour pixels fall from at least 221 to 14 in its view; the cream heading cue stays in view (frames 23 to 25). A shorter Flag or another carry offset would change it.
3. **The Orange Motorbike in its Garage** is a thin orange sliver from behind on the rust floor (dE 45 against the floor, the Teal Buggy more; frame 02). A darker floor was measured and not applied: it would move the floor away from the drawing.
4. **The Orange Unit on the canyon road at 40 m** is the weakest pair on the ground (dE 28, frame 32).
5. **Changes from the illustrated drawing the story made**: the navy sea, the water towers in the Team colours (the drawing paints both light blue), the Garage without a roof, the depot's three tanks as dressing at the ring's edge, the neutral things recoloured out of the Team colours and the Fuel Can red (the drawing paints some cover teal and orange).
6. **The Units are the concept sheet's models in one Team colour each**: the Buggy's pennant takes the Team colour, the Truck's drum is steel, and the Motorbike's cream tank-top patch is its heading cue (frames 02, 03, 09).
7. Frame 34 is the Map from above, to lay beside `design/source/map01_colored.png`.

## Human checks (confirmed at `/story-done`, 2026-10-03)

Asked of the developer on 2026-10-03, who answered Yes to each, with no notes (`godot --path .`; Player 1 W / S to drive, A / D to steer, Space to fire and confirm; Player 2 the arrows, Period to fire and confirm; Tab and Enter Self-destruct; R restarts after a win):

- [x] AC-15: Map 01 and the four Units look coherent against the illustrated drawing and the concept sheet (the notes above).
- [x] AC-3 to AC-6, driving on the real keyboard: the sea, the canyon walls and the ridge stop ground Units; the Gyrocopter crosses the rock and the channels and stops at the shore; the fords slow ground Units to half speed; every Unit leaves its Garage through the gate.
- [x] AC-11, AC-13: the Team colours read at a glance in both views (Bases, Units, Flags, the HUD and choice-panel edges, the Fuel amber apart from Orange), and each Unit stays visible to its own camera in the Garage, under the towers, on the canyon bends and over the rock.
- [ ] The Fuel numbers on a 300 m Map (the reach table above): not asked at `/story-done`. Whether the Truck and the Gyrocopter should reach the opponent's Flag on a spawn tank is a balance question for the author, carried in the story's Completion Notes.

## Sign-off

A **Visual/Feel** story needs the lead sign-off below. A solo developer signs as themselves (`.claude/docs/templates/test-evidence.md`).

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Lead (art-director / designer) — solo developer | Tomas Kunzo | 2026-10-03 | [x] Approved |

*Sign-off recorded from the developer's answer to the `/story-done` Visual/Feel question on 2026-10-03; not filled in by an agent on its own.*

## Appendix: the positions table beside the build (AC-1, AC-2)

`map_layout`'s 129 entries (`scenario-outputs/split-map_layout.txt`), world metres, X east and Z south, Base 1 west (Orange) and Base 2 east (Teal); west and east twins are listed in pairs (the road's centreline runs west to east, and entries on the axis stand alone), so both halves of AC-2 are listed. "Off" is the distance from the table to the build (degrees for headings); the non-zero ones are in bold and explained in the notes above. The sea panel is built far larger than the drawing's (±500 m) so no camera sees the world's edge.

| # | Entry | What | Table | Built | Off |
|---|---|---|---|---|---|
| 1 | `Base1/SpawnPoint` | position | (-125.00,0.00) | (-125.00,0.00) | 0.000 m |
| 2 | `Base2/SpawnPoint` | position | (125.00,0.00) | (125.00,0.00) | 0.000 m |
| 3 | `Base1/SpareSpawnLeft` | position | (-125.00,-4.00) | (-125.00,-4.00) | 0.000 m |
| 4 | `Base2/SpareSpawnRight` | position | (125.00,-4.00) | (125.00,-4.00) | 0.000 m |
| 5 | `Base1/SpareSpawnRight` | position | (-125.00,4.00) | (-125.00,4.00) | 0.000 m |
| 6 | `Base2/SpareSpawnLeft` | position | (125.00,4.00) | (125.00,4.00) | 0.000 m |
| 7 | `Base1/CanisterSeat` | position | (-113.00,0.00) | (-113.00,0.00) | 0.000 m |
| 8 | `Base2/CanisterSeat` | position | (113.00,0.00) | (113.00,0.00) | 0.000 m |
| 9 | `Base1/Walls/TowerGateLeft` | position | (-105.00,-16.00) | (-105.00,-16.00) | 0.000 m |
| 10 | `Base2/Walls/TowerGateRight` | position | (105.00,-16.00) | (105.00,-16.00) | 0.000 m |
| 11 | `Base1/Walls/TowerGateRight` | position | (-105.00,16.00) | (-105.00,16.00) | 0.000 m |
| 12 | `Base2/Walls/TowerGateLeft` | position | (105.00,16.00) | (105.00,16.00) | 0.000 m |
| 13 | `Base1/Walls/TowerBackLeft` | position | (-135.00,-16.00) | (-135.00,-16.00) | 0.000 m |
| 14 | `Base2/Walls/TowerBackRight` | position | (135.00,-16.00) | (135.00,-16.00) | 0.000 m |
| 15 | `Base1/Walls/TowerBackRight` | position | (-135.00,16.00) | (-135.00,16.00) | 0.000 m |
| 16 | `Base2/Walls/TowerBackLeft` | position | (135.00,16.00) | (135.00,16.00) | 0.000 m |
| 17 | `FuelCanCanyonWest` | position | (-88.00,-26.00) | (-88.00,-26.00) | 0.000 m |
| 18 | `FuelCanCanyonEast` | position | (88.00,-26.00) | (88.00,-26.00) | 0.000 m |
| 19 | `FuelCanFlatWest` | position | (-62.00,14.00) | (-62.00,14.00) | 0.000 m |
| 20 | `FuelCanFlatEast` | position | (62.00,14.00) | (62.00,14.00) | 0.000 m |
| 21 | `Depot/FuelCanDepot1` | position | (-3.00,-3.00) | (-3.00,-3.00) | 0.000 m |
| 22 | `Depot/FuelCanDepot2` | position | (3.00,-3.00) | (3.00,-3.00) | 0.000 m |
| 23 | `Depot/FuelCanDepot3` | position | (0.00,0.00) | (0.00,0.00) | 0.000 m |
| 24 | `Depot/FuelCanDepot4` | position | (-3.00,3.00) | (-3.00,3.00) | 0.000 m |
| 25 | `Depot/FuelCanDepot5` | position | (3.00,3.00) | (3.00,3.00) | 0.000 m |
| 26 | `Cover/Wrecks/WreckWestMiddleNorth` | position | (-53.00,-8.00) | (-53.00,-8.00) | 0.000 m |
| 27 | `Cover/Wrecks/WreckEastMiddleNorth` | position | (53.00,-8.00) | (53.00,-8.00) | 0.000 m |
| 28 | `Cover/Wrecks/WreckWestOuterSouth` | position | (-80.00,5.00) | (-80.00,5.00) | 0.000 m |
| 29 | `Cover/Wrecks/WreckEastOuterSouth` | position | (80.00,5.00) | (80.00,5.00) | 0.000 m |
| 30 | `Cover/Wrecks/WreckWestInnerNorth` | position | (-22.00,-10.00) | (-22.00,-10.00) | 0.000 m |
| 31 | `Cover/Wrecks/WreckEastInnerNorth` | position | (22.00,-10.00) | (22.00,-10.00) | 0.000 m |
| 32 | `Cover/Wrecks/WreckWestInnerSouth` | position | (-26.00,7.60) | (-26.00,7.60) | 0.000 m |
| 33 | `Cover/Wrecks/WreckEastInnerSouth` | position | (26.00,7.60) | (26.00,7.60) | 0.000 m |
| 34 | `Base1/SpawnPoint` | heading (deg) | -90.0 | -90.0 | 0.000 ° |
| 35 | `Base2/SpawnPoint` | heading (deg) | 90.0 | 90.0 | 0.000 ° |
| 36 | `Base1/SpareSpawnLeft` | heading (deg) | -90.0 | -90.0 | 0.000 ° |
| 37 | `Base2/SpareSpawnRight` | heading (deg) | 90.0 | 90.0 | 0.000 ° |
| 38 | `Base1/SpareSpawnRight` | heading (deg) | -90.0 | -90.0 | 0.000 ° |
| 39 | `Base2/SpareSpawnLeft` | heading (deg) | 90.0 | 90.0 | 0.000 ° |
| 40 | `Cover/Wrecks/WreckWestMiddleNorth` | heading (deg) | -30.0 | -30.0 | 0.000 ° |
| 41 | `Cover/Wrecks/WreckEastMiddleNorth` | heading (deg) | 30.0 | 30.0 | 0.000 ° |
| 42 | `Cover/Wrecks/WreckWestOuterSouth` | heading (deg) | 30.0 | 30.0 | 0.000 ° |
| 43 | `Cover/Wrecks/WreckEastOuterSouth` | heading (deg) | -30.0 | -30.0 | 0.000 ° |
| 44 | `Cover/Wrecks/WreckWestInnerNorth` | heading (deg) | 20.0 | 20.0 | 0.000 ° |
| 45 | `Cover/Wrecks/WreckEastInnerNorth` | heading (deg) | -20.0 | -20.0 | 0.000 ° |
| 46 | `Cover/Wrecks/WreckWestInnerSouth` | heading (deg) | -45.0 | -45.0 | 0.000 ° |
| 47 | `Cover/Wrecks/WreckEastInnerSouth` | heading (deg) | 45.0 | 45.0 | 0.000 ° |
| 48 | `Base1/Walls/WallLeft|Base1/Walls/WallRight` | extent | (x-135.00..-105.00,z-16.00..16.00) | (x-135.00..-105.00,z-16.00..16.00) | 0.000 m |
| 49 | `Base2/Walls/WallRight|Base2/Walls/WallLeft` | extent | (x105.00..135.00,z-16.00..16.00) | (x105.00..135.00,z-16.00..16.00) | 0.000 m |
| 50 | `Base1/Walls/GateWallLeft` | extent | (x-106.30..-105.00,z-16.00..-5.00) | (x-106.30..-105.00,z-16.00..-5.50) | **0.500 m** |
| 51 | `Base2/Walls/GateWallRight` | extent | (x105.00..106.30,z-16.00..-5.00) | (x105.00..106.30,z-16.00..-5.50) | **0.500 m** |
| 52 | `Base1/Walls/GateWallRight` | extent | (x-106.30..-105.00,z5.00..16.00) | (x-106.30..-105.00,z5.50..16.00) | **0.500 m** |
| 53 | `Base2/Walls/GateWallLeft` | extent | (x105.00..106.30,z5.00..16.00) | (x105.00..106.30,z5.50..16.00) | **0.500 m** |
| 54 | `Base1/Garage/GarageFloor` | extent | (x-132.00..-122.00,z-6.00..6.00) | (x-132.00..-122.00,z-6.00..6.00) | 0.000 m |
| 55 | `Base2/Garage/GarageFloor` | extent | (x122.00..132.00,z-6.00..6.00) | (x122.00..132.00,z-6.00..6.00) | 0.000 m |
| 56 | `Base1/Zone` | extent | (x-133.60..-106.10,z-14.70..14.70) | (x-133.60..-106.10,z-14.70..14.70) | 0.000 m |
| 57 | `Base2/Zone` | extent | (x106.10..133.60,z-14.70..14.70) | (x106.10..133.60,z-14.70..14.70) | 0.000 m |
| 58 | `Base1/WaterTower/Tank` | extent | (x-117.00..-109.00,z-4.00..4.00) | (x-117.00..-109.00,z-4.00..4.00) | 0.000 m |
| 59 | `Base2/WaterTower/Tank` | extent | (x109.00..117.00,z-4.00..4.00) | (x109.00..117.00,z-4.00..4.00) | 0.000 m |
| 60 | `Terrain/SaltFlat` | extent | (x-95.00..95.00,z-18.00..18.00) | (x-95.00..95.00,z-18.00..18.00) | 0.000 m |
| 61 | `FordWest` | extent | (x-46.00..-34.00,z-20.00..20.00) | (x-46.00..-34.00,z-20.00..20.00) | 0.000 m |
| 62 | `FordEast` | extent | (x34.00..46.00,z-20.00..20.00) | (x34.00..46.00,z-20.00..20.00) | 0.000 m |
| 63 | `Water/ChannelWest` | extent | (x-46.00..-34.00,z20.00..47.00) | (x-46.00..-34.00,z20.00..48.00) | **1.000 m** |
| 64 | `Water/ChannelEast` | extent | (x34.00..46.00,z20.00..47.00) | (x34.00..46.00,z20.00..48.00) | **1.000 m** |
| 65 | `Cover/Containers/ContainerWest` | extent | (x-64.00..-52.00,z-1.25..1.25) | (x-64.00..-52.00,z-1.25..1.25) | 0.000 m |
| 66 | `Cover/Containers/ContainerEast` | extent | (x52.00..64.00,z-1.25..1.25) | (x52.00..64.00,z-1.25..1.25) | 0.000 m |
| 67 | `Cover/ScrapWalls/ScrapWallWest` | extent | (x-13.25..-10.75,z6.00..18.00) | (x-13.25..-10.75,z6.00..18.00) | 0.000 m |
| 68 | `Cover/ScrapWalls/ScrapWallEast` | extent | (x10.75..13.25,z6.00..18.00) | (x10.75..13.25,z6.00..18.00) | 0.000 m |
| 69 | `Terrain/Island` | island outline | (0.00,-46.00) | (0.00,-46.10) | **0.100 m** |
| 70 | `Terrain/Island` | island outline | (-30.00,-47.00) | (-30.00,-46.10) | **0.900 m** |
| 71 | `Terrain/Island` | island outline | (30.00,-47.00) | (30.00,-46.10) | **0.900 m** |
| 72 | `Terrain/Island` | island outline | (-60.00,-45.00) | (-60.01,-45.90) | **0.900 m** |
| 73 | `Terrain/Island` | island outline | (60.00,-45.00) | (60.01,-45.90) | **0.900 m** |
| 74 | `Terrain/Island` | island outline | (-90.00,-46.00) | (-90.00,-45.70) | **0.300 m** |
| 75 | `Terrain/Island` | island outline | (90.00,-46.00) | (90.00,-45.70) | **0.300 m** |
| 76 | `Terrain/Island` | island outline | (-112.00,-43.50) | (-112.00,-43.50) | 0.000 m |
| 77 | `Terrain/Island` | island outline | (112.00,-43.50) | (112.00,-43.50) | 0.000 m |
| 78 | `Terrain/Island` | island outline | (-130.00,-38.00) | (-130.00,-38.00) | 0.000 m |
| 79 | `Terrain/Island` | island outline | (130.00,-38.00) | (130.00,-38.00) | 0.000 m |
| 80 | `Terrain/Island` | island outline | (-141.00,-28.00) | (-141.00,-28.00) | 0.000 m |
| 81 | `Terrain/Island` | island outline | (141.00,-28.00) | (141.00,-28.00) | 0.000 m |
| 82 | `Terrain/Island` | island outline | (-146.50,-14.00) | (-146.50,-14.00) | 0.000 m |
| 83 | `Terrain/Island` | island outline | (146.50,-14.00) | (146.50,-14.00) | 0.000 m |
| 84 | `Terrain/Island` | island outline | (-147.00,0.00) | (-147.00,0.00) | 0.000 m |
| 85 | `Terrain/Island` | island outline | (147.00,0.00) | (147.00,0.00) | 0.000 m |
| 86 | `Terrain/Island` | island outline | (-146.50,14.00) | (-146.50,14.00) | 0.000 m |
| 87 | `Terrain/Island` | island outline | (146.50,14.00) | (146.50,14.00) | 0.000 m |
| 88 | `Terrain/Island` | island outline | (-141.00,28.00) | (-141.00,28.00) | 0.000 m |
| 89 | `Terrain/Island` | island outline | (141.00,28.00) | (141.00,28.00) | 0.000 m |
| 90 | `Terrain/Island` | island outline | (-130.00,38.00) | (-130.00,38.00) | 0.000 m |
| 91 | `Terrain/Island` | island outline | (130.00,38.00) | (130.00,38.00) | 0.000 m |
| 92 | `Terrain/Island` | island outline | (-112.00,43.00) | (-112.00,43.00) | 0.000 m |
| 93 | `Terrain/Island` | island outline | (112.00,43.00) | (112.00,43.00) | 0.000 m |
| 94 | `Terrain/Island` | island outline | (-90.00,46.00) | (-90.00,45.70) | **0.300 m** |
| 95 | `Terrain/Island` | island outline | (90.00,46.00) | (90.00,45.70) | **0.300 m** |
| 96 | `Terrain/Island` | island outline | (-60.00,45.00) | (-60.01,45.90) | **0.900 m** |
| 97 | `Terrain/Island` | island outline | (60.00,45.00) | (60.01,45.90) | **0.900 m** |
| 98 | `Terrain/Island` | island outline | (-30.00,47.00) | (-30.00,46.10) | **0.900 m** |
| 99 | `Terrain/Island` | island outline | (30.00,47.00) | (30.00,46.10) | **0.900 m** |
| 100 | `Terrain/Island` | island outline | (0.00,46.00) | (0.00,46.10) | **0.100 m** |
| 101 | `Cliffs/RockCanyonNorth` | canyon rock edge | (-95.00,-44.00) | (-95.00,-44.00) | 0.000 m |
| 102 | `Cliffs/RockCanyonNorth` | canyon rock edge | (95.00,-44.00) | (95.00,-44.00) | 0.000 m |
| 103 | `Cliffs/RockCanyonNorth` | canyon rock edge | (-100.00,-30.50) | (-99.84,-30.44) | **0.168 m** |
| 104 | `Cliffs/RockCanyonNorth` | canyon rock edge | (100.00,-30.50) | (99.84,-30.44) | **0.168 m** |
| 105 | `Cliffs/RockCanyonNorth` | canyon rock edge | (-96.00,-20.00) | (-96.00,-20.00) | 0.000 m |
| 106 | `Cliffs/RockCanyonNorth` | canyon rock edge | (96.00,-20.00) | (96.00,-20.00) | 0.000 m |
| 107 | `Cliffs/RockCanyonNorth` | canyon rock edge | (-90.00,-22.00) | (-90.00,-22.00) | 0.000 m |
| 108 | `Cliffs/RockCanyonNorth` | canyon rock edge | (90.00,-22.00) | (90.00,-22.00) | 0.000 m |
| 109 | `Cliffs/RidgeWest` | ridge edge | (-95.00,22.00) | (-95.00,22.00) | 0.000 m |
| 110 | `Cliffs/RidgeWest` | ridge edge | (95.00,22.00) | (95.00,22.00) | 0.000 m |
| 111 | `Cliffs/RidgeWest` | ridge edge | (-100.00,32.00) | (-100.00,32.00) | 0.000 m |
| 112 | `Cliffs/RidgeWest` | ridge edge | (100.00,32.00) | (100.00,32.00) | 0.000 m |
| 113 | `Cliffs/RidgeWest` | ridge edge | (-95.00,45.00) | (-95.03,45.01) | **0.032 m** |
| 114 | `Cliffs/RidgeWest` | ridge edge | (95.00,45.00) | (95.03,45.01) | **0.032 m** |
| 115 | `Cliffs/RidgeWest` | ridge edge | (-70.00,22.00) | (-70.00,22.00) | 0.000 m |
| 116 | `Cliffs/RidgeWest` | ridge edge | (70.00,22.00) | (70.00,22.00) | 0.000 m |
| 117 | `Cliffs/RidgeWest` | ridge edge | (0.00,21.00) | (0.00,21.00) | 0.000 m |
| 118 | `Terrain/CanyonRoad` | road centreline | (-102.00,-26.00) | (-102.00,-26.00) | 0.000 m |
| 119 | `Terrain/CanyonRoad` | road centreline | (-80.00,-26.00) | (-80.00,-26.00) | 0.000 m |
| 120 | `Terrain/CanyonRoad` | road centreline | (-67.00,-36.00) | (-67.00,-36.00) | 0.000 m |
| 121 | `Terrain/CanyonRoad` | road centreline | (-43.00,-36.00) | (-43.00,-36.00) | 0.000 m |
| 122 | `Terrain/CanyonRoad` | road centreline | (-28.00,-28.00) | (-28.00,-28.00) | 0.000 m |
| 123 | `Terrain/CanyonRoad` | road centreline | (28.00,-28.00) | (28.00,-28.00) | 0.000 m |
| 124 | `Terrain/CanyonRoad` | road centreline | (43.00,-36.00) | (43.00,-36.00) | 0.000 m |
| 125 | `Terrain/CanyonRoad` | road centreline | (67.00,-36.00) | (67.00,-36.00) | 0.000 m |
| 126 | `Terrain/CanyonRoad` | road centreline | (80.00,-26.00) | (80.00,-26.00) | 0.000 m |
| 127 | `Terrain/CanyonRoad` | road centreline | (102.00,-26.00) | (102.00,-26.00) | 0.000 m |
| 128 | `Depot/RingMarking` | depot ring | (0.00,0.00) r=9.00 | (0.00,-0.00) r=9.000 | 0.000 m |
| 129 | `Water/Sea` | sea panel | (x-162.00..162.00,z-60.00..60.00) | (x-500.00..500.00,z-500.00..500.00) | 0.000 m |

---

*Template: `.claude/docs/templates/test-evidence.md` (adapted to the layout of the earlier stories' evidence docs)*
*Used for: Visual/Feel and UI story type evidence records*
