# Wasteland Buggy — concept model and renders

Kitbashed low-poly concept for the Buggy Unit, matched to the "BUGINA" panel
of the concept sheet (`../vehicle-design.png`): a low teal and orange two-tone
body with rust flecks, an orange roll cage with a three-lamp light bar and a
pennant flag, three round headlamps in the nose, an orange tube bull bar over
a dark skid plate, exposed orange suspension arms and coil shocks, big knobby
tyres on orange rims, and a bone skull on each door. Built entirely from
engine primitives at runtime; textures are seeded procedural noise, so a given
seed always renders the same picture.

Made 2026-09-30 on request. Custom art is out of scope for the First Playable
(`design/game-brief.md` names ready-made kits), so treat this as a concept
piece and a proof of the render pipeline, not a production asset.

## Files

- `wasteland_buggy.tscn` / `wasteland_buggy.gd` — the model. Exports:
  `steer_deg`, `rust_seed`. Faces -Z, metres, about 4 m long, 2.4 m wide over
  the tyres, 1.9 m to the light bar and 2.8 m to the flag.
- `wasteland_buggy_armored.tscn` / `.gd` — the earlier build from a spoken
  brief (scrap hull, spike arrays, rocket-pod launcher, V plow), kept for
  reference. Exports: `pod_yaw_deg`, `pod_pitch_deg`, `steer_deg`, `rust_seed`.
- `renders/` — three retained renders of each build (front hero, rear, side),
  1280×720; the armoured ones carry `_armored_` in the name.
- `../../showcase/wasteland_showcase.tscn` / `.gd` — shared desert backdrop,
  sun, haze, camera rig and PNG capture; its `MODELS` table holds the framing
  for `buggy` and `buggy_armored`.
- `../../shared/wasteland_palette.gd` — the sheet's colours and materials,
  shared by every vehicle; `kitbash.gd` (primitives, tubes, decals) and
  `procedural_textures.gd` (rust, grime, paint chips, the pixel skull).

## Re-render

From the repo root. A window opens for a second and the scene quits itself
after writing the file:

```
godot --path . --windowed --resolution 1280x720 --quit-after 600 \
  res://assets/art/showcase/wasteland_showcase.tscn \
  ++ --model=buggy --out=/absolute/path/out.png --view=front
```

`--model` takes `buggy` or `buggy_armored`; `--view` takes `front`, `rear` or
`side`. Without `++ --out=...` the scene just opens for viewing. Headless mode
cannot render, so the window is required.

## Cost

A couple of hundred `MeshInstance3D` nodes sharing the palette's materials.
Fine for a concept render, too many draw calls for a game unit. If this
becomes the real Buggy model, bake it into one mesh or replace it with a kit
model and keep only the silhouette and palette.

## Blender model (2026-10-10)

`wasteland_buggy.glb` is the Buggy Unit rebuilt in Blender by
`tools/blender/build_buggy.py` (how to rebuild it: `tools/blender/readme.md`):
the same dune buggy in the game's one-Team-colour rules (the pennant in the Team
accent, as the kit model's flag remap made it), sized to the Buggy's collider,
three meshes (Team accent, neutral parts, lamps) with ambient occlusion baked
into the vertex colours. The script is the source; never edit the `.glb` by
hand. `renders/wasteland_buggy_blender_*.png` are its four preview renders, the
Team accent painted orange.

`src/gameplay/units/data/buggy_stats.tres` points at `buggy_mesh_model.tscn`,
which draws this file; pointing it back at `buggy_kit_model.tscn` returns the
game to the kit model above. The comparison in the game:
`production/qa/evidence/blender-units-2026-10-10-evidence.md`.
