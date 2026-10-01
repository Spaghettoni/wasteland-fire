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
