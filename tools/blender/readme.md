# Blender models

The four Units' models, built in Blender from Python with no clicking: each script builds a model
from code, bakes its shading, renders preview images and exports a `.glb` that Godot imports.
The script is the source of truth. Edit it and run it again; never edit the `.glb` by hand.

Started 2026-10-10 as a test: the Truck, judged in the game beside the kit model it replaced. The
developer kept it the same day and asked for the other three the same way.
Blender 5.2.2 LTS (Homebrew: `brew install --cask blender`, which puts `blender` on the PATH).

## Files

| File | What it is |
|---|---|
| `wasteland_kit.py` | Shared helpers: the palette, the skull emblem, the shape builders (box, prism, loft, cylinder, cone, tube, torus, wheel, fender arch, pixel emblem), the occlusion bake, the join, the previews and the export. |
| `build_motorbike.py` | The Motorbike. Writes `assets/art/vehicles/wasteland_motorbike/wasteland_motorbike.glb`. |
| `build_buggy.py` | The Buggy. Writes `assets/art/vehicles/wasteland_buggy/wasteland_buggy.glb`. |
| `build_truck.py` | The Truck. Writes `assets/art/vehicles/wasteland_truck/wasteland_truck.glb`. |
| `build_gyrocopter.py` | The Gyrocopter. Writes `assets/art/vehicles/wasteland_gyrocopter/wasteland_gyrocopter.glb`. |

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

## Wiring a model into the game

Make a scene like `src/gameplay/units/models/truck_mesh_model.tscn` (a `MeshUnitModel` root with
`mesh_scene` set to the `.glb`) and point the type's `model` in
`src/gameplay/units/data/<type>_stats.tres` at it. To go back to the kit model, point it at
`<type>_kit_model.tscn` again; the kit scenes and `KitUnitModel` stay for that. Both model classes
extend `UnitModel` (`unit_model.gd`), which places a model in its Unit and runs the rise.
