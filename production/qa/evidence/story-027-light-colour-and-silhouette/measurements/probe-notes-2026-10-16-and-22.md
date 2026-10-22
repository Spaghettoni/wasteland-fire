# Story 027 probe notes (2026-10-16, this session; scratchpad probes27/)

Baselines: rg27/base-a, base-b (81 outputs, strict equal twice, tree manifest 918 files unchanged; capture 2.5 min each). pre27/ = pre-edit
snapshot of src tools project.godot. Tooling: rg27/{capture,run_one,filter,compare,mk_normalizers,regress,manifest,start}.sh/py (copied from rg26).

## Engine facts (4.7.2, probed)
- Environment: tonemap_mode 0 Linear,1 Reinhard,2 Filmic,3 ACES,4 AgX; tonemap_exposure (def 1), tonemap_white (1), tonemap_agx_white (16.29), tonemap_agx_contrast (1.25).
  Reinhard with white 1 == Linear (identical output). glow_*: glow_hdr_threshold 1.0 def, glow_hdr_scale 2.0 def, glow_hdr_luminance_cap 12, intensity .3, strength 1, mix .05, bloom 0, blend Screen(1), levels/1..7 = 0,.8,.4,.1,0,0,0.
  adjustment_*: enabled, brightness, contrast, saturation, color_correction (Texture2D or Texture3D).
- BaseMaterial3D: stencil_mode (0 off,1 outline,2 xray,3 custom), stencil_flags (1 read,2 write,4 write depth fail), stencil_compare (0 always,1 less,2 equal,3 le,4 greater,5 not equal,6 ge), stencil_reference 0..255 (def 1), depth_test (0 default, 1 inverted), no_depth_test.
- depth prepass default true (rendering/driver/depth_prepass/enable); project msaa_3d 0, SubViewports msaa_3d=2 (4x).
- doctool XML has no descriptions in this build (stubs only).
- `-s` SceneTree scripts: nodes added in _initialize are not in the tree yet (look_at fails: use Basis.looking_at); two Units added at the origin throw each other up (112 m) so give each its position before add_child; wait 90 physics ticks for CSG colliders.
- A ChaseCamera with a marker target still shifts the frame sub-pixel between frames (physics interpolation of the marker): use a static Camera3D for pixel-exact A/B (off-vs-off noise 0.0000 then).

## Stencil probe (stencil_probe.gd, windowed, SubViewports 640x720 msaa 4x, one World3D)
- Unit mesh material: stencil custom, WRITE, compare ALWAYS, ref per Player (1, 2). Copy (shares Mesh, own render layer 4 / 8, cast_shadow off): unshaded, ALPHA, albedo.a .5, disable_fog,
  render_priority 100, no_depth_test, stencil custom READ|WRITE, compare NOT_EQUAL, ref = its Player's.
- RESULT: P1's view shows its hidden part through the wall as orange 50 percent (0.725,0.471,0.392 over wall .471,.490,.525), the part in sight unchanged (0.922,0.471,0.188 = the no-copy frame), P2's Unit not shown through in P1's view, and vice versa.
  Same numbers with the depth pre-pass off. msaa 4x edges clean.
- Multi-part Unit (pillar in front of body): stencil variant leaves the visible pillar/body EXACTLY as without the copy; the depth_test Inverted fallback tints the visible parts (0.910,0.463,0.165 vs 0.922,0.471,0.188):
  it draws the Unit's own hidden parts over itself. Chosen: stencil (the Unit's own materials write, per Unit; the copy reads NOT_EQUAL and writes, so overlapping copies draw once, alpha uniform).
- Frames in probes27/out/ (stencil-player1/2.png, multi-stencil-player1.png, multi-inverted-player1.png).

## Light probe (light_probe.gd, Map 01, ChaseCamera above/chase settings, window 1280x720)
- Exposure ladder (Linear, output = clamp(hdr*e)): salt flat (left crop) hdr_max 1.255; east crop 1.156; the ford's water 0.73 (its glints peak about 1.59 in some frames); nothing else brighter.
  Brightest lit value of the Map about 1.26 on the flat, about 1.6 on moving water glints.
- Tone mappers on the same flat frame (crop 800x360 at (240,180)): Linear mean .711 sd .154 clipped .0001; Filmic .8125/.163/.0001; ACES .832/.189/.0001; AgX(1.0, c1.25, w16.29) .644/.134/0.
  Chase view crop: Linear .756 sd .036 clipped .0004; Filmic .861; ACES .892; AgX .6875 sd .019 clipped 0.
- AgX grid: exposure 1.3, contrast 1.5, agx_white 10: above mean .7104 sd .1510 clipped 0 max 219 ; chase mean .7590 sd .0176 clipped 0 max 222. Chosen: AgX exposure 1.3 contrast 1.5 white 10.
- Team hue on close shots (n about 18k px each), sun / shade, hue deg, sat, val:
  Linear orange 21.2/.728/.741 teal 177.9/.590/.523 | shade orange 20.5/.683/.457 teal 189.0/.695/.371
  Filmic 25.7/.705/.806, 178.7/.588/.636 | shade 20.7/.701/.576, 188.9/.719/.472
  ACES   25.0/.709/.796, 180.7/.789/.492 | shade 17.9/.774/.537, 188.4/.970/.420
  AgX(1.0,1.25,16.29) 23.6/.700/.659, 181.6/.619/.400 | shade 21.6/.765/.441, 188.7/.770/.358   (Team hues stay ~160 degrees apart under all)
- Glow (static camera, AgX 1.3, spheres emission 1.2/1.9/2.5/4/8): threshold 2.0 scale 1.0 intensity .8: E1.2 halo 0.0000 outside 0.0000; E8 halo .24; scene outside the spheres' halo <= .0036.
  threshold 1.0 blooms the scene by .0142 (the Base's orange). Chosen threshold 2.0 (brightest lit 1.26 flat, 1.6 water glints).

## LUT probe (lut_probe.gd)
- ImageTexture3D works as adjustment_color_correction; sampled WITHOUT half-texel compensation (position = c*N - 0.5): texel i = i/(N-1) is wrong (60 vs 64 at .25, 195 vs 191 at .75),
  texel i = (i+0.5)/N with the two END texels exact (0 and 1) reproduces an identity within 1/255 mid-range (errors up to 3/255 in the end half-texel bands at N=32, 8 at N=16): use N=32.
- A hand-written .import with importer="3d" was overwritten to importer="texture" by --import (not pursued): ship an ImageTexture3D saved as .res by a GDScript tool.
- system python3 has no numpy (Blender's python has).


## Environment problem found 2026-10-16 21:10 (after a 4.5 h gap)
- Windowed Godot draws for about 3 s after launch, then Arc (the user's browser, playing a video: "Video Wake Lock") becomes frontmost, the Godot window loses focus and
  Engine.get_frames_drawn() stops (draw_check2.gd: drawn+=60/s for 2-3 s, then 0). Movie Maker still writes one PNG per frame but the CONTENT freezes (draw_check4.gd: frames 300, 400, 590
  identical): a recording made now would look valid and be wrong. always-on-top and --position did not help. No assistive access for osascript (cannot inspect Arc's windows).
- Headless work is unaffected. Re-test with draw_check2.gd (probes27/) before every windowed step; every windowed capture must be checked for frozen frames (frames_drawn advancing, or frames differing).
- Grade look probe (grade_probe.gd) did work once at 21:10 (before the freeze): variant a (the shipped colour_grade.json) warms the flat by R/B 1.228 -> 1.332, Team hues move <= 0.4 deg (orange 25.3->25.6, teal 181.2->180.8), sat -0.03/-0.06. Variants b and c (variants/b.json, c.json, stronger tints and haze) are untested by eye.

## 2026-10-22 (this session, 288bd9fe): facts found
- The 10-16 session's scratchpad (rg27 baselines, pre27, probes27/NOTES.md) was PURGED from /private/tmp. Rebuilt: rg27 tooling from story 026's retained measurements, pre27 = git archive HEAD (+import), base-a/base-b captured again (81 outputs, strict equal after filter.sh: 10:43 to 10:48). This NOTES.md was recovered from the old transcript (5cff7ba7 row 914 + 1379).
- The old session stopped at the weekly limit 2026-10-16 21:23 (reset Oct 21 3am). Tree at that time: src (silhouette_settings.gd, unit_silhouette.gd, unit/unit_model/chase_camera edits), Environment data, LUT .res (+tool), runner SEE_THROUGH strip, see_through.gd + kit + copies module; the data/cameras/life/lint modules were MISSING (the runner could not parse). Written this session.
- ENGINE FACT (4.7.2, probe flags_probe2.gd): BaseMaterial3D.stencil_flags READ and WRITE are mutually exclusive in one material. Setting 3 (READ|WRITE) reads back 1 from a fresh material, then 2, then 1 (toggles: the newly added bit wins); READ is also exclusive with WRITE_DEPTH_FAIL (5 -> 1 or 4); WRITE|WRITE_DEPTH_FAIL (6) coexist. So the old design (copies that read NOT_EQUAL and write) was reading only: overlapping hidden parts double-blended.
- PROBE stencil_probe.gd (windowed, 640x360, MSAA 4x, wall + a Unit of 3 boxes, 3 designs): naive (read-only copies): the overlap of two hidden parts reads (72,148,146) against (94,142,144) for one: NOT flat. mask3: flat (94,142,144 in both), visible parts exactly the Unit colour (229,115,36). opaque_m (opaque M-writers at priority -100): FAILS (magenta everywhere: opaque priority is not an order).
  mask3 = three transparent passes by render_priority: (90) invisible mask copy per mesh, no depth test, WRITE ref M; (95) invisible sight copy per mesh, depth tested, WRITE ref V (V over M where the part is in sight); (100) ONE billboard quad 1000 m, READ EQUAL M, Team colour at strength, no depth test, no fog. The Unit's own meshes stay untouched (no writing materials).
- windowed run works now (draw_check.gd: 120 fps steady 12 s, focus true, Metal, M4 Pro).
