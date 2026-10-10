# Graphics test, 2026-10-10: lighting pass and the Truck modelled in Blender

Asked by the developer on 2026-10-10 ("install blender and do both"), after the question whether
Blender models could improve the graphics. Not a story: a test to judge in the game before
deciding whether more models are made this way. Nothing is committed.

## What changed

| Change | Files |
|---|---|
| Lighting of Map 01 | `src/gameplay/maps/map_01/map_01.tscn` (the Sun and the WorldEnvironment) |
| 4x MSAA in both Player views | `src/gameplay/split_screen/split_screen.tscn` (`msaa_3d` on each SubViewport) |
| The Truck's model, built in Blender | `tools/blender/` (the build script, the shared helpers, a readme), `assets/art/vehicles/wasteland_truck/wasteland_truck.glb` (+ `.import`) |
| Drawing a model from a mesh file | `src/gameplay/units/models/mesh_unit_model.gd` (`MeshUnitModel`), `src/gameplay/units/models/truck_mesh_model.tscn` |
| The Truck uses it | `src/gameplay/units/data/truck_stats.tres` (`model`: `truck_kit_model.tscn` became `truck_mesh_model.tscn`) |
| Preview renders from Blender | `assets/art/vehicles/wasteland_truck/renders/wasteland_truck_blender_*.png` |

Blender 5.2.2 LTS was installed with Homebrew (`brew install --cask blender`).

## Lighting

| Setting | Before | After |
|---|---|---|
| Sun | 55° high, white, energy 1.0 | 45° high (same direction), warm `(1, 0.93, 0.82)`, energy 1.3 |
| Shadow of a 1 m object | 0.70 m | 1.00 m (1.43x longer) |
| Background | flat colour | procedural desert sky, blue overhead, pale at the horizon |
| Ambient light | flat `(0.78, 0.82, 0.9)` x 0.7 | 60% from the sky (blue from above, warm sand bounce from below), 40% flat `(0.8, 0.8, 0.82)`, energy 0.9 |
| Ambient occlusion | off | SSAO, radius 2 m, intensity 3, light affect 0.4 |
| Distance haze | none | depth fog from 60 m to 260 m, at most 20%: only the chase view sees that far |
| Tone mapping | linear | linear (kept, see below) |
| Anti-aliasing | none | 4x MSAA in each Player view |

Seven versions were recorded with `camera_showcase` and compared. AgX tone mapping washed the
colours out; Filmic kept them but turned the Team orange toward amber. Measured on the Truck's
bonnet in the depot frame: hue 23.1° before, 30.2° under Filmic, 21.2° with linear tone mapping
and the final light levels. The Team colours must match the HUD's, so linear stayed. Final
samples against the original: orange value 0.88 (was 0.91), teal 0.65 (0.65), salt flat 0.83
(0.82).

Frame rate, `map_fps` windowed with vsync off on this Mac (Apple M4 Pro), average and minimum of
the steady samples: new lighting 400 / 314, old lighting 414 / 390, new lighting again 478 / 399.
The two runs of the same build differ by more than the builds do, so the cost is not measurable
here; the budget is 60. Draw calls at most 238 (were 222), primitives 128,060 (124,178).
Untested on weaker PCs, such as the Windows build's players.

## The Truck

`tools/blender/build_truck.py` builds the TRUCK of the concept sheet in the game's rules: one Team
colour in two tones, neutral metal, rubber and cargo. A lifted pickup on knobby tyres: a sloped
bonnet with a scoop, a darker stripe and a rust patch, a barred grille between two lamps, a spiked
bumper, a cab with a pixel skull on each door, mirrors and a four-lamp light bar, the rocket pod on
a turret ring, exhaust stacks and a headache rack behind the cab, and a bed with crates, a spare
wheel on a Team rim, a drum and jerrycans. Blender bakes ambient occlusion into the vertex colours.

| | Kit model (before) | Blender model (after) |
|---|---|---|
| Surfaces (draw calls per view) | 4 | 3 |
| Triangles | 9,896 | 12,174 (Accent 2,248, Neutral 9,710, Lamp 216) |
| Size | 4.4 m long, 1.8 m wide | 4.57 m with spikes and hitch, 2.16 m across the fenders |

The collider is 2.4 x 1.6 x 4.4 m; the Blender model hangs up to 0.13 m past its rear (the hitch)
and 0.04 m past its front (the spikes): drawn only, nothing collides with it.

The model was judged in the game's own cameras, and one change came from that: the tailgate's dark
inset made the rear read dark in the chase view, so it became a raised plate in the full Team
tone.

## Verification

- Import: `godot --headless --import` clean, no error or warning, after every export.
- The model, probed headless (`measurements/probe_model.gd.txt`): Accent in the `team_colour`
  group, front toward -Z, vertex colours arrive as written (1.0 and 0.68 Team tones, darkened by
  the occlusion). Blender's glTF exporter wrote no vertex colours in its `ACTIVE` mode; they are
  exported by name (`Col`).
- Regression: the 54 retained headless outputs, byte for byte against two baselines captured
  before the first edit: 54 identical after the lighting and the first Truck, and again at the end.
  The baselines differed once from each other by Jolt's job-system load warning (two lines), which
  the comparison drops (`measurements/regress.sh.txt`).
- The windowed showcases end with the same RESULT lines before and after (`camera_showcase` 7
  moments, `map_showcase` 15, `units_showcase`).

`units_showcase` runs on the greybox field with the old stand-in models, so it shows neither change
to the Truck nor to Map 01's lighting (only the anti-aliasing).

## Retained frames

All from Movie Maker recordings at 1280x720, before above, after below unless noted:

| File | Shows |
|---|---|
| `graphics-test-2026-10-10/lighting-01-garages-from-above.png` | Round start in both Garages, old Truck |
| `graphics-test-2026-10-10/lighting-02-depot-from-above.png` | The depot, old Truck |
| `graphics-test-2026-10-10/lighting-03-chase-view.png` | Player 1 in the chase view, Player 2 from above |
| `graphics-test-2026-10-10/lighting-04-canyon-from-above.png` | The canyon road |
| `graphics-test-2026-10-10/truck-01-from-above-zoomed-3x.png` | The Truck from above in play, zoomed 3x: kit left, Blender right |
| `graphics-test-2026-10-10/truck-02-own-truck-chase-view.png` | Player 1's Truck in the chase view, new lighting both |
| `graphics-test-2026-10-10/truck-03-canyon-road-chase-view.png` | The Truck on the canyon road, new lighting both |
| `graphics-test-2026-10-10/truck-04-teal-truck-from-behind.png` | Player 2's Truck from behind, new lighting both |
| `graphics-test-2026-10-10/both-01-depot-before-and-after.png` | The depot: original against both changes |

## Going back

- The Truck: point `model` in `src/gameplay/units/data/truck_stats.tres` at
  `truck_kit_model.tscn` again (one line). The kit model is untouched.
- The lighting: restore `map_01.tscn` and `split_screen.tscn` from git.

## Open for the developer

1. Keep the Blender Truck? If so, `design/rules.md` ("Teams and visual style": models built from
   Godot's built-in meshes; the four Units from the kit) and `design/game-brief.md` (Art & audio
   direction; Out of scope) each need a sentence, and `kit_unit_model.gd`'s doc still names
   `truck_kit_model.tscn` among the scenes the types use. The concept art is the author's, who may
   want a say.
2. The Motorbike, the Buggy and the Gyrocopter the same way? Each is a script like
   `build_truck.py`. The Gyrocopter also needs `KitUnitModel`'s rise over cliffs and cover carried
   over to `MeshUnitModel`, and the Motorbike its cream heading cue.
3. Keep the lighting? It is independent of the Truck.

## Decided (2026-10-10)

The developer, after judging the frames and the build: "I like the new truck very much! The
lighting is also better. Do the other units the same way". So all three questions above are
answered: the Truck and the lighting stay; `design/rules.md`, `design/game-brief.md` and
`CONTEXT.md` now say the Units' models are built in Blender, and `kit_unit_model.gd`'s doc calls
the kit scenes the fallback; the Motorbike, the Buggy and the Gyrocopter were modelled the same
way, with the Gyrocopter's rise carried over: `blender-units-2026-10-10-evidence.md` beside this
file.
