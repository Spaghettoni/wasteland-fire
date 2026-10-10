# Wasteland Motorbike — concept model and renders

Kitbashed low-poly concept for the Motorbike Unit, matched to the "MOTORKA"
panel of the concept sheet (`../vehicle-design.png`): an orange tube frame and
fork, a teal tank wearing the bone skull, a round headlamp in an orange bezel,
flat black bars, a dark V-twin, big knobby tyres on orange rims, a brown
saddle with an orange tail, a small two-tone fender at each end and a pair of
spikes on the tail. Built entirely from engine primitives at runtime; textures
are seeded procedural noise, so a given seed always renders the same picture.

Made 2026-09-30 on request, after the buggy; reworked the same day to the
sheet. Custom art is out of scope for the First Playable
(`design/game-brief.md` names ready-made kits), so treat this as a concept
piece, not a production asset.

## Files

- `wasteland_motorbike.tscn` / `wasteland_motorbike.gd` — the model. Exports:
  `steer_deg` (front wheel about the fork axis), `lean_deg` (onto the
  kickstand side), `rust_seed`. Faces -Z, metres, about 2.3 m long and 1.15 m
  to the bars.
- `renders/` — the three retained renders (front hero, rear, side), 1280×720.
- `../../showcase/wasteland_showcase.tscn` / `.gd` — shared desert backdrop,
  sun, haze, camera rig and PNG capture; its `MODELS` table holds this bike's
  framing.
- `../../shared/wasteland_palette.gd` — the sheet's colours and materials,
  shared by every vehicle; `kitbash.gd` and `procedural_textures.gd` — helpers.

## Re-render

From the repo root. A window opens for a second and the scene quits itself
after writing the file:

```
godot --path . --windowed --resolution 1280x720 --quit-after 600 \
  res://assets/art/showcase/wasteland_showcase.tscn \
  ++ --model=motorbike --out=/absolute/path/out.png --view=front
```

`--view` takes `front`, `rear` or `side`. Without `++ --out=...` the scene just
opens for viewing. Headless mode cannot render, so the window is required.

## Cost

About 130 `MeshInstance3D` nodes sharing the palette's materials. Fine for a
concept render, too many draw calls for a game unit. If this becomes the real
Motorbike model, bake it into one mesh or replace it with a kit model and keep
only the silhouette and palette.

## Blender model (2026-10-10)

`wasteland_motorbike.glb` is the Motorbike Unit rebuilt in Blender by
`tools/blender/build_motorbike.py` (how to rebuild it: `tools/blender/readme.md`):
the same dirt bike in the game's one-Team-colour rules, sized to the
Motorbike's collider, three meshes (Team accent, neutral parts, lamps) with
ambient occlusion baked into the vertex colours. The cream plate on the tank
top is a lamp part: the heading cue that shows the Motorbike's front from the
camera above, as the kit model's remapped tank-top plate did. The script is the
source; never edit the `.glb` by hand. `renders/wasteland_motorbike_blender_*.png`
are its four preview renders, the Team accent painted orange.

`src/gameplay/units/data/motorbike_stats.tres` points at
`motorbike_mesh_model.tscn`, which draws this file; pointing it back at
`motorbike_kit_model.tscn` returns the game to the kit model above. The
comparison in the game: `production/qa/evidence/blender-units-2026-10-10-evidence.md`.
