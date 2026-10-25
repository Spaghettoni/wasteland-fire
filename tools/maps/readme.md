# tools/maps

Scripts that write Map scenes and their pieces as Godot text scenes (story 038). The scenes they
write are never edited by hand: change the tables at the top of a script and run it again from the
repository root. Tooling only; nothing under `src/` imports these files.

| Script | Writes |
|---|---|
| `build_map_02.py` | `src/gameplay/maps/map_02/map_02.tscn` (Map 02 from the schematic `design/source/wasteland-fire-map-02-2026-10-16.svg`), `map_02_fuel_building.tscn`, `map_02_tyre_track_settings.tres` |
| `build_map_03.py` | `src/gameplay/maps/map_03/map_03.tscn` (Map 03, the islands, from `design/source/wasteland-fire-map-03-2026-10-25.svg`), `garage_base.tscn` and `flag_fortress.tscn` (cut from Map 01's compound), `map_03_tyre_track_settings.tres` |
| `build_cover_pieces.py` | `src/gameplay/cover/wreck.tscn`, `shack_long.tscn`, `shack_square.tscn` (the breakable car wreck and small buildings) |
| `tscn.py` | nothing: the small `.tscn` writer the two scripts share (transforms are written row by row, as Godot's text format stores a basis) |
| `render_preview.gd` | a Map's picture from above for its card on the map choice (`assets/art/ui/map_0N_preview.png`); run windowed |

```
python3 tools/maps/build_cover_pieces.py
python3 tools/maps/build_map_02.py
python3 tools/maps/build_map_03.py
xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s res://tools/maps/render_preview.gd -- \
  --map=res://src/gameplay/maps/map_02/map_02.tscn --out=assets/art/ui/map_02_preview.png --span=124x254 --height=820 --rotate=ccw
xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s res://tools/maps/render_preview.gd -- \
  --map=res://src/gameplay/maps/map_01/map_01.tscn --out=assets/art/ui/map_01_preview.png --span=300x110 --height=400
xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s res://tools/maps/render_preview.gd -- \
  --map=res://src/gameplay/maps/map_03/map_03.tscn --out=assets/art/ui/map_03_preview.png --span=244x244 --height=820
```

After a rebuild, open the project once in the editor (or run `godot --headless --editor --quit --path .`)
so the new scenes are imported, then run the evidence scenarios `map_02`, `bushes` and `cover_pieces`.

An override of a property of an instanced scene's child (a ford's water mesh, a Turret's band) survives the export only when
that instance is marked editable (`Scene.editable()`): without it the exported game shows the instanced scene's own value
(measured on 4.7.2, 2026-10-21). Check an exported pack with `godot --headless --main-pack <pack> -s <probe>` after changing them.
