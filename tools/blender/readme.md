# Blender models

The four Units' models and Map 01's rocks, props and Base trim, built in Blender from Python with no
clicking: each script builds its models from code, bakes their shading, renders preview images and
exports a `.glb` that Godot imports; two more scripts write the ground's and the walls' textures.
The scripts are the source of truth. Edit one and run it again; never edit a `.glb` or a texture
by hand.

Started 2026-10-10 as a test: the Truck, judged in the game beside the kit model it replaced. The
developer kept it the same day, asked for the other three Units the same way, then for the Map's
rocks, walls and other objects and more thorough ground textures.
Blender 5.2.2 LTS (Homebrew: `brew install --cask blender`, which puts `blender` on the PATH).

## Files

| File | What it is |
|---|---|
| `wasteland_kit.py` | Shared helpers: the palette, the skull emblem, the shape builders (box, prism, loft, cylinder, cone, tube, torus, wheel, fender arch, pixel emblem), the occlusion bake, the join, the previews and the export. |
| `build_motorbike.py` | The Motorbike. Writes `assets/art/vehicles/wasteland_motorbike/wasteland_motorbike.glb`. |
| `build_buggy.py` | The Buggy. Writes `assets/art/vehicles/wasteland_buggy/wasteland_buggy.glb`. |
| `build_truck.py` | The Truck. Writes `assets/art/vehicles/wasteland_truck/wasteland_truck.glb`. |
| `build_gyrocopter.py` | The Gyrocopter. Writes `assets/art/vehicles/wasteland_gyrocopter/wasteland_gyrocopter.glb`. |
| `build_rocks.py` | Map 01's rocks, read from the cliff colliders of `map_01_cliffs.tscn` (rerun it after changing them). Writes `assets/art/map_01/rocks/map_01_rocks.glb`, one mesh per cliff. |
| `build_props.py` | Map 01's props, each built to the box of the primitive it replaces: wrecks, containers, scrap walls, the dressing's containers, tyres, boulders and posts, the fuel tanks' trim. Writes `assets/art/map_01/props/map_01_props.glb`. |
| `build_base.py` | The Bases' trim, laid on their wall, tower and Garage boxes; the water tower's ladder; the Turrets' trim (the head's, and the drum's twice: `TurretPedestalTrim` for the 1 m drum of Story 013, which only the evidence's frozen Turret still uses, and `TurretPedestalTrimTall` for the grown 2.2 m drum of Story 015). Writes `assets/art/map_01/base/map_01_base.glb`. |
| `build_ground_textures.py` | The ground's seamless noise textures (`src/gameplay/maps/map_01/textures/ground_*.png`), read by `src/gameplay/maps/spatial_env_ground.gdshader` and the rocks' `spatial_env_rock.gdshader`. |
| `build_wall_textures.py` | The Bases' welded steel plates (`src/gameplay/maps/map_01/textures/wall_plates*.png`), read by `wall.tres` and the Flag Walls' damaged looks. |

## Rebuilding a model

From the repository root, for example the Truck:

```sh
blender --background --factory-startup --python tools/blender/build_truck.py -- \
    --out assets/art/vehicles/wasteland_truck/wasteland_truck.glb --previews /tmp/truck-previews
godot --headless --path . --import
```

The other three take their own script and `.glb` path from the table above. `--previews DIR` is
optional: four EEVEE images (front and rear three-quarter, side, top) with the Team accent painted
orange; the ones kept are in each vehicle's folder as `renders/wasteland_<type>_blender_*.png`. A
run takes a few seconds. The second command makes Godot reimport the file; opening the editor does
the same. The same script always writes the same file, byte for byte, so a rebuild after an edit to
the shared helpers shows at once whether another model changed (`cmp` the old file against a
rebuild into a scratch folder).

## How the game draws a model

The `.glb` holds three meshes, and `src/gameplay/units/models/mesh_unit_model.gd` gives each the
material the kit models' merge (`kit_merge.gd`) gives its parts, so both kinds of model look alike:

| Mesh | Parts | Drawn with |
|---|---|---|
| `Accent` | the Team paint (`accent`, `accent_dark`, `rim`) | the Unit's Team material, which multiplies the vertex colour |
| `Neutral` | metal, rubber, glass, leather, cargo, the skulls | a vertex-coloured material (roughness 0.8, metallic 0.1) |
| `Lamp` | the lamp lenses and the Motorbike's cream heading cue | the palette's glowing lamp colour |

Each part is tagged with a palette key. The vertex colour is the key's colour (for the accent its
tone: 1.0, or 0.68 for `accent_dark`) times the ambient occlusion Blender bakes. The numbers are
sRGB, stored unchanged in a float attribute, so the game reads them with `vertex_color_is_srgb` as
it does the kit's. A model without lamps (the Gyrocopter) has no `Lamp` mesh.

Conventions a new model must keep:

- Metres; +Z up; the front toward +Y (the exporter turns it into Godot's −Z, a Unit's forward).
- The origin on the ground at the middle of the Unit's collider (its `collision_size` in the type's
  `UnitStats` file); build the model to that box, so `model_scale` stays 1.0.
- One Team colour only, through the accent keys. Neutral keys must not read as orange or teal
  (`rust` and `rust_orange` are left out of `PALETTE` for that reason, and `leather` is darker than
  the palette's).
- The Motorbike keeps a `lamp` plate on its tank top: its cream heading cue, so its front reads from
  the camera above (Story 007 AC-12).
- Export with vertex colours by name (`Col`): the exporter's `ACTIVE` mode wrote none here.

The Gyrocopter is built standing on its wheels. Its scene (`gyrocopter_mesh_model.tscn`) lifts it by
`hover_height` (0.78 m, where the kit model's lowest point stood) and turns on the rise over cliffs
and cover with the kit scene's values; the rise reads the box of the file's vertices up to
`hull_top` (1.4 m), which leaves out the rotor. Its occlusion bake has no ground plane, since it is
drawn in the air.

## Map 01's pieces

The Map's pieces follow the same scheme with one mesh per piece (`finish(groups=...)`), each drawn
by a `PropMesh` (`src/gameplay/props/prop_mesh.gd`: it takes the mesh named `mesh_name` from
`mesh_file`; the scene sets its `material_override`) or, for many copies, a `PropMultiMesh`. Rules
the evidence holds them to:

- What collides stays the scene's own collider. A piece that replaces a primitive is built to that
  primitive's box exactly (`fit_to_box`), so the box drawn and the box measured are the same: the
  cover's evidence measures runs against the drawn box.
- The rocks never rise above the cliff colliders' top (2.0 m), which stay as invisible colliders
  (`layers = 0`): the Gyrocopter's model rises over the collider's top as before.
- Where a test reads a primitive (the Flag Walls' and Base walls' shared `wall.tres`, a fuel tank's
  cylinders, a Turret's drum and band, the water tower's four top pieces on render layer 2), the
  primitive stays and the detail is a second mesh laid on it (the Trim nodes).
- A new script a Map node carries must be added to `tools/evidence/split_screen/map_layout.gd`'s
  `SCRIPTS`; `PropMesh` and `PropMultiMesh` are there.
- The generated textures import lossless, with mipmaps and with the 3D detection off (their
  `.import` files): the shaders read them as numbers.

## Wiring a model into the game

Make a scene like `src/gameplay/units/models/truck_mesh_model.tscn` (a `MeshUnitModel` root with
`mesh_scene` set to the `.glb`) and point the type's `model` in
`src/gameplay/units/data/<type>_stats.tres` at it. To go back to the kit model, point it at
`<type>_kit_model.tscn` again; the kit scenes and `KitUnitModel` stay for that. Both model classes
extend `UnitModel` (`unit_model.gd`), which places a model in its Unit and runs the rise.
