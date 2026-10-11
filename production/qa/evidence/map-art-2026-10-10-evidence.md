# Map 01's ground, rocks, walls and props (2026-10-10)

Asked by the developer on 2026-10-10, after the Units were modelled in Blender: "okay, now do models
for the rocks, walls and other objects as well. Also do more thorough textures for the ground. Work
in separate worktree, because another work is in progress". Built in the worktree
`.claude/worktrees/map-art` (branch `worktree-map-art`, from `73de824`); the main checkout was not
touched. Nothing is committed.

## What changed

| Change | Files |
|---|---|
| The ground: a shader over generated noise textures | `src/gameplay/maps/spatial_env_ground.gdshader` (new); `src/gameplay/maps/map_01/materials/sand.tres`, `road.tres`, `salt_flat.tres` (ShaderMaterials now); `tools/blender/build_ground_textures.py` writes `src/gameplay/maps/map_01/textures/ground_*.png` (+ `.import`) |
| The rocks: modelled over the cliff colliders | `tools/blender/build_rocks.py` writes `assets/art/map_01/rocks/map_01_rocks.glb`; `src/gameplay/maps/spatial_env_rock.gdshader`, `materials/rock_face.tres` (new); `map_01_cliffs.tscn` (the CSG colliders drawn on no layer, `RockLooks` added) |
| The props: wrecks, containers, scrap walls, the dressing | `tools/blender/build_props.py` writes `assets/art/map_01/props/map_01_props.glb`; `map_01_cover.tscn`, `map_01_dressing.tscn` (the primitives' meshes replaced, the separate container ribs removed) |
| The Bases' walls: welded plates and steel trim | `tools/blender/build_wall_textures.py` writes `textures/wall_plates*.png`; `materials/wall.tres` and the Flag Walls' `flag_wall_damaged_1.tres`, `flag_wall_damaged_2.tres` (the plates); `tools/blender/build_base.py` writes `assets/art/map_01/base/map_01_base.glb`; `compound_base.tscn` (Trim nodes on the walls, towers and Garage; a ladder on the water tower) |
| Fuel tanks and Turrets: trim | `map_01_depot.tscn`, `src/gameplay/defences/turret.tscn` (Trim nodes) |
| Drawing a mesh from a Blender file | `src/gameplay/props/prop_mesh.gd` (`PropMesh`), `prop_multi_mesh.gd` (`PropMultiMesh`), `mesh_file.gd` (`MeshFile`, the shared cache, which `MeshUnitModel` now reads through), `materials/prop_neutral.tres` |
| Shared Blender helpers | `tools/blender/wasteland_kit.py`: named groups, per-face colours, `fit_to_box`, per-prop origins, a bake without ground; palette keys for faded paint, a container grey and concrete |
| The evidence's script list | `tools/evidence/split_screen/map_layout.gd` (`SCRIPTS` adds `PropMesh` and `PropMultiMesh`) |
| Docs | `tools/blender/readme.md`, `design/rules.md` (Teams and visual style), `design/game-brief.md`, `README.md`; renders under `assets/art/map_01/*/renders/` |

## The ground

Before: each surface was a StandardMaterial3D with one Godot noise texture. The sand's and the
road's (`textures/sand.tres`, `road.tres`) tiled every 32 m in world space; the salt flat's
(`salt_span.tres`) was one cellular noise stretched across its whole plane, which drew its cracks
metres wide. From both cameras the ground read as an evenly painted floor.

Now the sand, the canyon road and the salt flat are ShaderMaterials of one shader,
`src/gameplay/maps/spatial_env_ground.gdshader`. It reads five seamless 1024 x 1024 textures that
`tools/blender/build_ground_textures.py` generates from fixed seeds (periodic gradient noise and a
periodic cell pattern, computed with numpy in Blender's Python). The shader samples them in world
space, metres on X and Z, so the Island's, the road's and the salt flat's meshes meet without a
seam. Its layers, large to small:

| Layer | Tile | What it gives |
|---|---|---|
| Macro tone | 260 m | broad lighter and darker reaches, the same in all three materials, so the tones run on where two surfaces meet |
| Mottle | 36 m | patches tens of metres across; the stones gather in them |
| Streaks | 40 to 60 m | wind streaks along one direction, eight times longer than wide |
| Plates and cracks | 48 m, 24 cells a side | the salt flat's crust: plates about 2 m across, each its own tone, cracks with a groove and a raised rim |
| Fine cracks | 16 m (salt flat), 26 m (road) | thinner cracks inside the plates; the road's dried mud |
| Stones | 14 m (sand), 7 m (road) | pebbles in patches on the sand, dense gravel on the road, each a dome in the relief |
| Grain | 4 to 5 m | a fine speckle |

The relief under the low sun comes from relief maps of the same patterns: the swells, the stones'
domes, the cracks' grooves and rims. They are stored as world-oriented normals, so the meshes need
no tangents. The salt flat's tones blend into the sand's over its outer 3 m, along a line the
mottle wobbles, so its border is a soft, uneven line rather than a hard edge. The cost is one
pass and ten texture reads, with no loops and no branches.

## The rocks

Before: the canyon walls and ridges were the cliff colliders themselves: CSG outlines extruded to a
flat top 2.0 m up, drawn in two noise colours (`rock.tres`, `ridge.tres`).

Now `tools/blender/build_rocks.py` reads the five outlines from `map_01_cliffs.tscn` and wraps each
in layered desert rock:

- a buried foot flaring out at the ground;
- bands of harder and softer stone stepping in and out;
- a lip, then a broken, faceted top: a constrained Delaunay triangulation with points inside the
  outline raised or sunk by noise;
- fallen stones along the foot.

Each face has one colour: a red sandstone for the canyon walls and a darker stone for the ridges, as
the two old materials had. Cycles bakes ambient occlusion into the vertex colours.
`spatial_env_rock.gdshader` adds the detail smaller than a face: a grain on every face, streaks
along the strata on the walls and joint lines across the tops. The five meshes hold 21,730
triangles. The CSG colliders stay, drawn on no render layer (`layers = 0`), and a rerun of the
script follows any change to their outlines.

## The props

Before: the cover's wrecks (6 x 1.3 x 3 m), containers (12 x 2 x 2.5 m) and scrap walls (2.5 x 2 x
12 m) were boxes in the rust, container and scrap noise colours. The dressing was Godot primitives
too: box containers with a second set of thin boxes for their ribs, a torus per tyre, a sphere per
boulder and a cylinder per post.

Now `tools/blender/build_props.py` builds each prop to exactly the box of the primitive it
replaces, in rust, faded paint, steel, rubber and concrete. None wears a Team colour or the Fuel
Can's red.

| Prop | Box (x, height, z) | Placed | Triangles |
|---|---|---|---|
| `WreckPickup`: a gutted pickup on its belly, wheels gone, junk in the bed | 6 x 1.3 x 3 m | 4 wrecks of the cover | 1,064 |
| `WreckFlipped`: a car on its roof, chassis, axles and one tyre in the air | 6 x 1.3 x 3 m | the other 4 | 884 |
| `Container`: corrugated, doors at one end | 12 x 2 x 2.5 m | the cover's 2 | 1,344 |
| `ScrapWall`: a barricade of crushed car bodies, sheets leaning on both faces, posts, tyres and drums at its foot | 2.5 x 2 x 12 m | the cover's 2 | 3,680 |
| `DressingContainer7`, `DressingContainer8`: olive containers | 7 and 8 x 2.5 x 4 m | 2 in each Base | 900, 996 |
| `Tyre` (one of a stack), `Boulder`, `Post` (the depot's concrete bollards) | the primitives' sizes | 24, 8 and 6 copies (MultiMesh) | 512, 80, 436 |

## The Bases, the fuel tanks and the Turrets

The walls take a new texture from `tools/blender/build_wall_textures.py`: welded steel plates 2 m
wide and 1.6 m tall, each its own tone, with dark seams, rows of bolts and rust running down, and a
normal map that sinks the seams, raises the bolts and warps each plate a little. It replaces the
scrap noise in `wall.tres` and in the Flag Walls' two damaged looks, which keep their darker greys
and crack layers.

The boxes stay, and each piece of trim is a second mesh laid on its box (the `Trim` nodes, from
`tools/blender/build_base.py`):

- on the walls (both Bases): a gunmetal cap along the top, a concrete footing, I-beam posts on both
  faces and, on the outer walls, a run of barbed wire;
- on the corner towers: a parapet, corner guards, a band, window slits and a roof plate, all
  neutral steel, so the tower keeps its Team colour;
- on the Garage walls: the same cap, footing and posts;
- a ladder up one leg of the water tower;
- on the depot's fuel tanks: seams, a ladder, a railing round the dome, a vent and a valve
  (`FuelTankTrim`);
- on a Turret's drum, a bolt ring, ribs and a hatch; on its head, vents, a sight, an aerial, a
  muzzle brake and a sleeve on the barrel.

One Base's trim holds 19,020 triangles, a Turret's 388, a fuel tank's 1,320.

## What the evidence holds the art to

Every check that reads a mesh, a material or a collider was kept as it was. The art fits around
those checks:

- Colliders: every collider is still the scene's own primitive or CSG. The cliffs' CSGs are drawn
  on no layer. No rock rises above their 2.0 m top, so the Gyrocopter's model clears the rock it
  flies over, and no rock face stands more than 0.42 m outside its outline, so a Unit the collider
  stops touches the rock it sees.
- The cover: `map_cover` measures the runs against the drawn box (`Mesh.get_aabb()`). Each prop is
  fitted to its primitive's box (`fit_to_box`), so the box drawn and the box measured stay the same.
- Primitives a test reads: the Flag Walls' and the Base walls' shared albedo texture
  (`flag_walls_looks`), a fuel tank's cylinder and band (`depot_tanks`), a Turret's band
  (`turrets`), and the water tower's four pieces on render layer 2 (`camera_views`). These all stay,
  and the detail goes on a second mesh. A railing round the water tower would have been a fifth
  piece on layer 2, so it was left out; the ladder is on layer 1.
- The scripts Map nodes may carry: `map_layout` allows a fixed list, and `PropMesh` and
  `PropMultiMesh` were added to it.

## Verification

The scripts and results are in `map-art-2026-10-10/measurements/`, scripts saved as `.txt`.

- Import: `godot --headless --path . --import` ran clean after every export.
- Rebuilds: all 14 generated files (the three Map `.glb` files, the four Units' and the seven
  textures), rebuilt into a scratch folder, are byte-identical to the worktree's copies
  (`rebuild-results.txt`). So the scripts are the source, and the changes to the shared helpers
  left the Units' models alone.
- Regression: the 54 retained headless outputs against the baseline captured in the worktree before
  its first edit, at `73de824` (`regress-54-final.txt`). 53 are byte-identical. They include the
  cover's runs, the Flag Walls' looks, the depot's tanks, the Turrets, the camera's views and the
  Gyrocopter's rise over the cliffs and the cover. The 54th, `map_layout`, still passes; it differs
  only in its printed list of the scripts Map nodes carry, which now includes `prop_mesh.gd` and
  `prop_multi_mesh.gd` (`map_layout-diff.txt`).
- gdUnit: 1 test, passed. The main scene launched windowed for 600 frames with no error or warning
  (`main-scene-600-frames.txt`).
- Exit messages: the after recording of `map_showcase`, which Movie Maker cut at frame 1560,
  printed "30 ObjectDB instances were leaked" and "13 resources still in use at exit". The copy at
  `73de824` cut at the same frame prints the same two messages, naming the same 13 scripts, none
  of them this work's, and a full run in the worktree prints neither (`leak-check.txt`). The cut
  causes them, not the art.
- Frame rate, `map_fps` windowed at 1280 x 720 on this Mac (Apple M4 Pro), alternating the worktree
  and a copy at `73de824`:
  - On Metal with vsync off, all four runs held the display's 120 fps, steady minimum 120
    (`fps3-results.txt`). `tools/evidence/split_screen/fps.gd` notes that this display caps windowed
    runs, so the cap hides any difference.
  - So a scratch tool (`gpu_time.gd.txt`) measured the GPU's own time per frame, summed over the
    window and the two views. Metal reports no GPU time, so these runs used the Vulkan driver,
    five of each build. Average per run: after 2.08, 3.78, 2.06, 2.05, 2.07 ms; before 2.02,
    1.62, 2.10, 1.82, 1.63 ms (`gpu-time-results.txt`). The medians are 2.07 and 1.82 ms, so the
    art costs about a quarter of a millisecond a frame here, out of the 16.7 ms a frame has at
    60 fps. The GPU's clock changes under light load, which is why runs of the same build differ.
  - Per frame at most, over both views and the shadow passes: 401,000 primitives (before 136,000)
    and 258 draw calls (before 225).

## Retained frames

All are from Movie Maker recordings at 1280 x 720 of the evidence showcases. Before is `73de824`,
the Units session's final recordings (the turrets recorded from a copy at that commit), and after
is the worktree. Each pair shows before above after, with Player 1's view on the left.

| File | Shows |
|---|---|
| `map-art-2026-10-10/map-art-01-garages-from-above.png` | `camera_showcase` frame 102, from above: both Bases, with walls, towers, Garages, containers and tyre stacks |
| `map-art-2026-10-10/map-art-02-salt-flat-and-cover-from-above.png` | Frame 183: the salt flat between the canyon walls, a wreck and a container of the cover |
| `map-art-2026-10-10/map-art-03-base-and-water-tower-from-above.png` | Frame 279: the Bases again, with the water tower's legs (its top is hidden from above) |
| `map-art-2026-10-10/map-art-04-canyon-from-above.png` | Frame 549: the two canyon roads between their rock walls, the salt flat between them |
| `map-art-2026-10-10/map-art-05-depot-from-above.png` | Frame 645: the depot, with fuel tanks, a scrap wall, wrecks and Fuel Cans |
| `map-art-2026-10-10/map-art-06-fords-chase-view.png` | `map_showcase` frame 717, chase view: the fords, with wrecks and a container beyond and the rock in front |
| `map-art-2026-10-10/map-art-07-canyon-road-chase-view.png` | Frame 1067, chase view: the Truck and the Buggy on the canyon road |
| `map-art-2026-10-10/map-art-08-gyrocopters-over-the-rock-chase-view.png` | Frame 1553, chase view: both Gyrocopters over a ridge, the salt flat's crust in front |
| `map-art-2026-10-10/map-art-09-flag-walls-damaged-from-above.png` | `flag_walls_showcase` frame 821: damaged Flag Walls between a water tower's legs, the Base walls' plates and trim |
| `map-art-2026-10-10/map-art-10-turrets-from-above.png` | `turrets_showcase` frame 64: the Turrets outside both gates |
| `map-art-2026-10-10/map-art-11-canyon-road-from-above.png` | `mines_showcase` frame 531: a Truck and a live Mine on the canyon road's gravel; the Mine still stands out |

The Blender previews of each piece are under `assets/art/map_01/rocks/renders/`,
`props/renders/` and `base/renders/`.

## Going back

- A scene's pieces: `git checkout 73de824 -- <scene>` restores its primitives (`map_01_cover.tscn`,
  `map_01_dressing.tscn`, `map_01_cliffs.tscn`, `compound_base.tscn`, `map_01_depot.tscn`,
  `turret.tscn`). A single Trim node can simply be deleted.
- The rocks alone: delete `RockLooks` and give the five CSGs back their default `layers` (1).
- The ground or the walls: `git checkout 73de824 --` the material (`sand.tres`, `road.tres`,
  `salt_flat.tres`, `wall.tres`, the two damaged looks). The old noise textures are still in the
  repository.
- All of it: drop this branch's changes, the files listed under What changed.

## Open for the developer

1. Not modelled: the Fuel Cans, the Mines and the Flags. Their looks carry gameplay meaning (the
   Fuel Can's red; a Mine's disc and the Flag in the owner's Team colour, as the developer and the
   author settled in `design/rules.md`), so they are left for a separate decision. The Turrets'
   drum, dome and barrel and the fuel tanks' cylinders stay primitives under their trim.
2. The water tower has no railing: it would be a fifth piece on render layer 2, and `camera_views`
   counts four. Adding one means changing that check, which is your call.
3. Files nothing uses any more, left in place because deleting is your call:
   `src/gameplay/maps/map_01/materials/container.tres`, `dressing_container.tres`,
   `dressing_container_rib.tres`, `dressing_rubber.tres`, `scrap.tres`, and the old noise textures
   `src/gameplay/maps/map_01/textures/sand.tres`, `road.tres`, `salt_span.tres`
   (`measurements/unused-files.txt`).
4. A change to a cliff's outline in `map_01_cliffs.tscn` needs `build_rocks.py` run again, and a
   change to a prop's primitive box needs the size changed in `build_props.py`. Otherwise the drawn
   piece and its collider disagree.
5. Performance on weaker PCs, such as the Windows build's players, is still unmeasured, and the
   Windows build was not remade.
6. The branch starts at `73de824`. The main checkout's work in progress was not looked at, so any
   overlap with it shows only at the merge.
