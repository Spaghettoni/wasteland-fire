# The Motorbike, the Buggy and the Gyrocopter modelled in Blender (2026-10-10)

Asked by the developer on 2026-10-10, after judging the graphics test
(`graphics-test-2026-10-10-evidence.md`): "I like the new truck very much! The lighting is also
better. Do the other units the same way". Not a story: the follow-up to that test. Nothing is
committed.

## What changed

| Change | Files |
|---|---|
| Three new models, built in Blender by script | `tools/blender/build_motorbike.py`, `build_buggy.py`, `build_gyrocopter.py`; `assets/art/vehicles/wasteland_<type>/wasteland_<type>.glb` (+ `.import`) |
| Shared helpers: a ring shape (tyres, rims, the steering wheel), the skull emblem shared by all four, a dark leather, lug sizes for small wheels, the occlusion bake's reach and ground per model | `tools/blender/wasteland_kit.py`; `build_truck.py` takes the skull from it (the Truck rebuilds byte-identical) |
| The rise over cliffs and cover moved into a base class both kinds of model extend | `src/gameplay/units/models/unit_model.gd` (new, `UnitModel`), `kit_unit_model.gd`, `mesh_unit_model.gd` |
| A model scene per type, and the types use them | `src/gameplay/units/models/<type>_mesh_model.tscn`; `src/gameplay/units/data/<type>_stats.tres` (`model`) |
| The evidence casts the Gyrocopter's model to the base class | `tools/evidence/split_screen/gyro_cover.gd`, `flag_walls_over.gd`, `flag_walls_showcase.gd` |
| Comments that named `KitUnitModel` for the rise or the warm-up | `src/gameplay/maps/map_field.gd`, `src/gameplay/split_screen/split_screen.gd`, `kit_merge.gd` |
| The design record: the Units' models are built in Blender | `design/rules.md` (Teams and visual style), `design/game-brief.md` (Out of scope; Art & audio direction), `CONTEXT.md` (First Playable) |
| Docs and renders | `tools/blender/readme.md`; each vehicle's `readme.md`; `renders/wasteland_<type>_blender_*.png` (four views each) |

## The models

Each follows its panel of the concept sheet (`assets/art/vehicles/vehicle-design.png`) in the game's
rules, as the Truck does: one Team colour in two tones, neutral metal, rubber and leather, ambient
occlusion baked into the vertex colours, sized to the type's collider.

- **Motorbike** (MOTORKA): a dirt bike on fat knobby tyres with Team rims, a Team tank with a skull
  on each flank, a darker Team frame, Team fenders, a round headlamp in a Team bezel under three
  spikes, flat bars with hand guards, a dark V-twin, a low exhaust on the right and an upswept one
  on the left, a dark saddle and a Team tail with two spikes. Its cream heading cue (Story 007
  AC-12) is a lamp plate on the tank top, 0.28 x 0.28 m, where the kit model's tank-top plate was.
- **Buggy** (BUGINA): a low dune buggy on knobby tyres at its corners, a Team bonnet with a darker
  patch, three nose lamps in Team bezels behind a tube bull bar over a skid plate, an open tub with
  two seats and a skull on each door, a darker Team roll cage with a four-lamp light bar, exposed
  arms with Team coil springs, a rear deck with a strapped cargo box and an exhaust, and the
  pennant on a whip in the Team colour.
- **Gyrocopter** (GYROKOPTERA): a two-blade Team rotor with darker tips on a tripod mast, a Team
  nose pod with a darker cap and a windscreen, an open seat over a Team tank, a boxer engine under a
  Team cowl driving a three-blade pusher propeller, a Team fin with the skull on a darker diamond, a
  Team stabiliser, and tricycle gear on darker Team legs with small knobby wheels. The tube frame is
  dark metal, as on the sheet (the kit model's was orange). The rotor and the propeller stand still
  in the kit model's pose (rotor yawed 25°, tilted back 6°).

| | Kit model (before) | Blender model (after) |
|---|---|---|
| Motorbike | 4 surfaces, 8,208 triangles; 2.60 x 0.72 x 1.21 m | 3 surfaces, 9,578 triangles; 2.34 x 0.76 x 1.24 m |
| Buggy | 4 surfaces, 10,324 triangles; 2.99 x 1.80 x 2.02 m | 3 surfaces, 10,508 triangles; 2.97 x 1.86 x 2.00 m |
| Truck (kept from the test) | 4 surfaces, 9,896 triangles; 4.40 x 1.84 x 2.39 m | 3 surfaces, 12,174 triangles; 4.57 x 2.16 x 2.70 m |
| Gyrocopter | 4 surfaces, 4,120 triangles; 2.63 x 4.44 x 1.82 m with the rotor | 2 surfaces, 7,402 triangles; 2.42 x 4.23 x 1.80 m with the rotor |
| All four | 16 surfaces, 32,548 triangles | 11 surfaces, 39,662 triangles |

Sizes are length x width x height as drawn in the Unit's frame
(`measurements/probe_kits-output.txt`). The kit models' wheels sank 4 to 5 cm into the ground (their
lowest point below the floor); the Blender models' stand on it (0 to 4 mm).

## The Gyrocopter's rise

`KitUnitModel` held the rise over cliffs and cover (Story 007 AC-13, Story 009 AC-2). It moved,
unchanged, into the abstract base class `UnitModel`, which both `KitUnitModel` and `MeshUnitModel`
extend; each kind implements `_build_meshes()`, which adds its meshes and sets the hull the rise
reads. A mesh model's hull is the box of its file's vertices up to `hull_top`, read once per file:
1.4 m on the Gyrocopter's scene, above its body and propeller and below its rotor, whose blades
would make the footprint 4.6 m wide. The Gyrocopter's scene copies the kit scene's rise settings
and hovers 0.78 m up, where the kit model's lowest point stood, so its lowest point is where it was
and the shots at 0.5 m pass under it as before.

| | Kit model | Blender model |
|---|---|---|
| Hull across | -0.70 to 0.70 m | -0.69 to 0.69 m |
| Hull along (front -) | -1.19 to 1.21 m | -1.16 to 1.26 m |
| Lowest point over the floor | 0.780 m | 0.780 m |

## Judged in the game's cameras

The first version of each was recorded in the showcases and compared with the kit models, zoomed
in on the same frames. Two changes came from that, as the Truck's tailgate did in the test:

- The Motorbike read darker than the kit's from the camera above (its fenders were in the dark
  tone): both fenders took the full Team tone and the heading cue grew from 0.26 to 0.28 m.
- The Gyrocopter read darker than the kit's from behind (the dark frame, engine and stabiliser):
  the stabiliser, the engine cowl and the tank took the full Team tone and the main gear legs the
  dark Team tone (the kit's legs were Team-coloured too).

The Buggy compared well and did not change.

## Verification

- Import: `godot --headless --import` clean, no error or warning, after every export.
- The four models probed headless (`measurements/probe_units.gd.txt`, `probe_kits.gd.txt` and
  their outputs): each type's model is a `MeshUnitModel` with its meshes, Accent in the
  `team_colour` group, at scale 1; the Gyrocopter's rise is on with its hull read from the file.
- The helper changes leave the other models alone: the Truck and the Buggy rebuilt into a scratch
  folder are byte-identical to the files in the repository.
- Regression: the 54 retained headless outputs against the baselines captured before the graphics
  test (`measurements/regress-54-final.txt`):
  - the base class with the three Units still on their kit models: 54 of 54 byte-identical (the
    Gyrocopter's rise ran through it), so the refactor changed nothing;
  - the Motorbike wired: 54 of 54;
  - all four wired, first and final versions: 51 of 54 byte-identical, and every one of the 54
    ends `ok` with all 263 CHECK lines PASS. The three that differ are the Gyrocopter's rise,
    measured on a slightly different body box: `gyro_cover` (0.65 m instead of 0.55 m over the two
    middle-north wrecks, beside a taller piece; 18 ticks instead of 19 over the containers and
    scrap walls), `flag_walls` (26 ticks instead of 27 over the wall), `flag_walls_showcase` (the
    `gyro_over` moment one tick later, frame 908, not 907).
- gdUnit: 1 test, passed. The main scene launched windowed for 600 frames: no error or warning.
- Frame rate, `map_fps` windowed with vsync off on this Mac (Apple M4 Pro), the Blender models
  against a scratch copy with the kit models wired, alternating (`measurements/fps2-results.txt`),
  steady average and lowest: Blender 651 / 499, kit 466 / 361, Blender 380 / 226, kit 617 / 389.
  Two runs of the same build differ by more than the builds do, so the cost is not measurable here;
  the budget is 60. Draw calls at most 226 (kit 238), primitives 136,364 (kit 128,060).

## Retained frames

All from Movie Maker recordings at 1280x720 of the evidence showcases, with the graphics test's
lighting and the Blender Truck in both. "Before" is the kit models (the graphics test's final
recordings for `camera_showcase` and `map_showcase`; the other showcases recorded from a scratch
copy of the project with the three kit models wired back), "after" the Blender models. Zoomed rows
read kit, Blender, kit, Blender, left to right; the pairs show before above after.

| File | Shows |
|---|---|
| `blender-units-2026-10-10/motorbike-01-carrying-the-flag-from-above-zoomed-4x.png` | `camera_showcase` frame 453, from above: both Motorbikes carrying the enemy Flag, the cream heading cue in front of it |
| `blender-units-2026-10-10/units-01-motorbike-and-buggy-from-above-zoomed-4x.png` | From above: Player 2's Motorbike on the salt flat (`flag_walls_showcase` frame 907, 908 after), Player 1's Buggy just swapped in, in its Garage (`unit_swap_showcase` frame 117) |
| `blender-units-2026-10-10/gyrocopter-01-from-above-zoomed-3x.png` | From above: Player 1's Gyrocopter over a Flag Wall (`flag_walls_showcase` frame 907, 908 after), Player 2's Gyrocopter over a live Mine (`mines_showcase` frame 1284) |
| `blender-units-2026-10-10/chase-01-garages-motorbike-and-buggy-zoomed-3x.png` | Chase view: Player 1's Motorbike and Player 2's Buggy appearing in their Garages (`map_showcase` frame 123) |
| `blender-units-2026-10-10/chase-02-ford-buggy-and-motorbike-zoomed-3x.png` | Chase view: Player 1's Buggy and Player 2's Motorbike crossing the fords (`map_showcase` frame 717) |
| `blender-units-2026-10-10/chase-03-gyrocopters-zoomed-2_5x.png` | Chase view: both Gyrocopters at the start of their flight (`map_showcase` frame 1461) |
| `blender-units-2026-10-10/full-01-gyrocopters-chase-view-before-and-after.png` | The whole frame of the row above |
| `blender-units-2026-10-10/full-02-buggy-in-its-garage-from-above-before-and-after.png` | The whole frame of the Buggy in its Garage, from above |

The Blender previews of each model (front and rear three-quarter, side, top, the Team accent painted
orange) are in each vehicle's folder:
`assets/art/vehicles/wasteland_<type>/renders/wasteland_<type>_blender_*.png`.

## Going back

- A Unit's model: point `model` in `src/gameplay/units/data/<type>_stats.tres` at
  `<type>_kit_model.tscn` again (one line). The kit models and `KitUnitModel` are untouched in
  behaviour.
- All of today's work on the three models: the files listed under What changed.

## Open for the developer

1. The author's view: `design/rules.md` records the keep as the developer's decision, with a reading
   for the author that a model the repository builds from its own script is not a downloaded mesh
   (the source's reason for no meshes is that downloading is behind a subscription).
2. The rotor and the propeller stand still, as on the kit model. Spinning them is possible (they
   would become their own nodes) but is new behaviour, and a two-blade rotor turning at 60 frames a
   second strobes unless it is slow or blurred.
3. Performance on weaker PCs, such as the Windows build's players, is still unmeasured; on this Mac
   the models cost no measurable frame rate.
