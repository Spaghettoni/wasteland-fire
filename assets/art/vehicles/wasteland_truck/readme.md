# Wasteland Truck — concept model and renders

Kitbashed low-poly concept matched to the "TRUCK" panel of the concept sheet
(`../vehicle-design.png`): a lifted pickup on big knobby tyres with orange
rims, an orange bonnet with a teal patch over a dark barred grille, a spiked
dark bumper over a skid plate, twin headlamps, a teal cab wearing the bone
skull on each door, a four-lamp light bar and a four-tube rocket pod on the
roof, a whip antenna, and a teal bed with orange rails, a cargo rack, crates
and a drum. Built entirely from engine primitives at runtime; textures are
seeded procedural noise, so a given seed always renders the same picture.

Made 2026-09-30 on request. The truck is not one of the three Units in
`design/game-brief.md`; it exists because it is on the sheet. Custom art is
out of scope for the First Playable, so treat this as a concept piece, not a
production asset.

## Files

- `wasteland_truck.tscn` / `wasteland_truck.gd` — the model. Exports:
  `pod_yaw_deg`, `pod_pitch_deg`, `steer_deg`, `rust_seed`. Faces -Z, metres,
  about 5.3 m long, 2.4 m wide, 2.2 m to the roof and 3.1 m to the pod.
- `renders/` — the three retained renders (front hero, rear, side), 1280×720.
- `../../showcase/wasteland_showcase.tscn` / `.gd` — shared desert backdrop,
  sun, haze, camera rig and PNG capture; its `MODELS` table holds this truck's
  framing and per-view pod yaw.
- `../../shared/wasteland_palette.gd` — the sheet's colours and materials,
  shared by every vehicle; `kitbash.gd` and `procedural_textures.gd` — helpers.

## Re-render

From the repo root. A window opens for a second and the scene quits itself
after writing the file:

```
godot --path . --windowed --resolution 1280x720 --quit-after 600 \
  res://assets/art/showcase/wasteland_showcase.tscn \
  ++ --model=truck --out=/absolute/path/out.png --view=front
```

`--view` takes `front`, `rear` or `side`. Without `++ --out=...` the scene just
opens for viewing. Headless mode cannot render, so the window is required.

## Cost

About 170 `MeshInstance3D` nodes sharing the palette's materials. Fine for a
concept render, too many draw calls for a game vehicle. If it is ever used in
play, bake it into one mesh or replace it with a kit model and keep only the
silhouette and palette.

## Blender model (2026-10-10)

`wasteland_truck.glb` is the Truck Unit rebuilt in Blender by
`tools/blender/build_truck.py` (how to rebuild it: `tools/blender/readme.md`):
the same pickup in the game's one-Team-colour rules, sized to the Truck's
collider, three meshes (Team accent, neutral parts, lamps) with ambient
occlusion baked into the vertex colours. The script is the source; never edit
the `.glb` by hand. `renders/wasteland_truck_blender_*.png` are its four
preview renders, the Team accent painted orange.

Made as a test, judged in the game and kept by the developer the same day; the
other three Units followed. `src/gameplay/units/data/truck_stats.tres` points at
`truck_mesh_model.tscn`, which draws this file; pointing it back at
`truck_kit_model.tscn` returns the game to the kit model above. The comparison
in the game: `production/qa/evidence/graphics-test-2026-10-10-evidence.md`.
