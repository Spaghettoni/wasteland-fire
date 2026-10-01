# Wasteland Gyrocopter — concept model and renders

Kitbashed low-poly concept for the Gyrocopter Unit, matched to the
"GYROKOPTERA" panel of the concept sheet (`../vehicle-design.png`): an open
orange tube frame with a mast and braces, a two-blade teal rotor with orange
tips on a teetering head, a teal nose pod with an orange face and a pale
windscreen, a saddle behind an instrument panel, a dark engine driving a
three-blade pusher propeller, a tail boom ending in a teal and orange
stabiliser and a fin wearing the bone skull, and tricycle gear on orange
outriggers with small knobby wheels on orange rims. Built entirely from engine
primitives at runtime; textures are seeded procedural noise, so a given seed
always renders the same picture.

Made 2026-09-30 on request, third of the three Units. Custom art is out of
scope for the First Playable (`design/game-brief.md` names ready-made kits),
so treat this as a concept piece, not a production asset.

## Files

- `wasteland_gyrocopter.tscn` / `wasteland_gyrocopter.gd` — the model.
  Exports: `rotor_yaw_deg` (rotor about the mast), `rotor_tilt_deg` (disc
  rocked back), `rust_seed`. Faces -Z, metres, about 3.6 m long, 7.3 m across
  the rotor, 2.4 m to the rotor head. The rotor and the propeller are their own
  nodes (`RotorHead/Tilt/Rotor`, `Engine/Prop`) so they can be spun.
- `renders/` — the three retained renders (front hero, rear, side), 1280×720.
- `../../showcase/wasteland_showcase.tscn` / `.gd` — shared desert backdrop,
  sun, haze, camera rig and PNG capture; its `MODELS` table holds this
  aircraft's framing and per-view rotor yaw.
- `../../shared/wasteland_palette.gd` — the sheet's colours and materials,
  shared by every vehicle; `kitbash.gd` and `procedural_textures.gd` — helpers.

## Re-render

From the repo root. A window opens for a second and the scene quits itself
after writing the file:

```
godot --path . --windowed --resolution 1280x720 --quit-after 600 \
  res://assets/art/showcase/wasteland_showcase.tscn \
  ++ --model=gyrocopter --out=/absolute/path/out.png --view=front
```

`--view` takes `front`, `rear` or `side`. Without `++ --out=...` the scene just
opens for viewing. Headless mode cannot render, so the window is required.

## Cost

About 90 `MeshInstance3D` nodes sharing the palette's materials. Fine for a
concept render, too many draw calls for a game unit. If this becomes the real
Gyrocopter model, bake the frame into one mesh, keep the rotor and propeller
as separate meshes for animation, or replace it with a kit model and keep only
the silhouette and palette.
