# Story 027 — The light and the colour, and your own Unit through cover: test evidence

**Story:** `production/epics/wasteland-fire/story-027-light-colour-and-silhouette.md` · **Type:** Visual/Feel · **Layer:** Presentation · **Estimate:** L
**Engine:** Godot 4.7.2.stable.official.ed1daf0bf, Jolt Physics, Forward+ (Metal 4.0; Vulkan 1.2 through MoltenVK for the GPU timings and the Vulkan check), 60 physics ticks/s
**Machine:** macOS (Darwin 25.5.0) arm64, Apple M4 Pro, 120 Hz built-in display · **Dates:** 2026-10-16 and 2026-10-22 · **Run by:** this session directly, no workflow (the usage-quota note: a workflow costs about eight times a direct build); one read-only engine review by `godot-gdscript-specialist` (see "Review").
**Four sittings.**
- 2026-10-16: the build began. It stopped at the weekly usage limit at 21:23, and the OS later purged its scratchpad (baselines, snapshot, probe notes; the notes were recovered from its transcript).
- 2026-10-22, 10:39 to 13:15: resumed from the tree. This sitting did the redesign of the silhouette (see measured fact 2), the scenario's missing modules, the measurements, the review and its fixes, and the final recordings. It stopped at the usage limit.
- 2026-10-22, 19:34 to 20:30: this close-out. The repeat recording compared, the AgX ladder recorded again, the Vulkan check, the frame-rate confirm, two windowed seeded defects and two more headless ones, the final chain, this document.
- 2026-10-22, 20:56 to 21:42: the commit, on top of `origin/main` (see "On top of origin/main").

Nothing else edited the tree between the last source edit (12:43) and the end. The sorted SHA manifest of `src`, `tools`, `project.godot` and `assets` (the Svaty Jur art left out; 952 files) is the same before the close-out's windowed runs, after them, and before and after the final chain (`measurements/close-out-2026-10-22/manifest-*.txt`, `final-chain-manifest-*.txt`). `git status` read 54 entries at the start of the close-out, with no Godot process running. One other Claude session, open since 2026-10-15, has this repo as its working directory, but no file in the repo was newer than the morning's last recording when the close-out began, and only the close-out's own files changed during it.
**Gate level:** Visual/Feel, BLOCKING by default (`testing.strict.visual` is unset): the retained frames and the lead's sign-off. The automated test is waived at `qa.level: minimal`. The evidence is the headless scenario `see_through` (20 checks, run twice byte-identical), the windowed `light_showcase` frames and premises, `light_fps`, the measurements, the regression of every older output and the seeded defects.
**Built on the committed tree.** Stories 025 and 026 were committed and pushed (bf9e12e) before this story began, so its baseline is bf9e12e and no other story's work is in its diff. The untracked Svaty Jur experiment (five paths) is no part of it.

Test evidence: the automated test is **waived** at `qa.level: minimal`. No test was required or written for this story; the scenarios are the evidence, as for stories 012 to 026. The retained frames are not waived, and are below.

## Run result

Run result: OBSERVED. The main scene launched windowed on 4.7.2:
- a 90-frame Movie Maker recording, whose last frame is frame 00 (frames 85 to 89 are byte-identical; it differs from story 026's launch frame because every frame now goes through the new look);
- a 600-frame run on the final tree, rc 0, no ERROR or WARNING.

`light_showcase` has 45 moments. It was recorded windowed with Movie Maker three times on the final tree:
- **finalA**, the build as it ships: 1,553 frames in 4 min 52 s, RESULT ok, no failing premise;
- **finalN**, the same moments with both Units' silhouettes taken away (`LIGHT_NO_SIL=1`, the runner's strip), for the difference masks;
- **finalA2**, finalA again: all 1,553 frames byte-identical to finalA's (`measurements/close-out-2026-10-22/cmp-finalA2-vs-finalA.txt`).

The frames show:
- the salt flat from above, a Base in shade, both Teams' Trucks close up in sun and in shade, and a ford, each under Linear (the look before the story), AgX as shipped, AgX without the grade, Filmic and ACES;
- the glow on three probes of emission 1.2, 4 and 8, with the glow on and off;
- each Player's own Unit behind a Turret, a corner tower, a water tower's leg, a container, a cliff and the depot's tank in the chase view; the Gyrocopters under their tanks; Player 1's Motorbike behind Player 2's Truck; and two moments from above. The other Player's view is in the same frame each time;
- difference masks: where the build differs from the same moment without the silhouettes;
- the turret moment on Vulkan, a seeded defect's frame, and the turret moment zoomed with and without the silhouette.

40 images are retained in `production/qa/evidence/story-027-light-colour-and-silhouette/`, each opened and read.

The feel half is for the human checks below, since stills cannot show it: whether the new look reads right in play, and how the silhouette looks while a Unit drives in and out of cover.

## The runs

- **Baseline** (the 81 retained headless outputs: the 79 of story 026's regression and story 026's own `tyre_tracks` and `tyre_tracks_showcase`; `measurements/jobs.txt.txt`) was captured from `pre27`, a `git archive` of bf9e12e with its import cache built, three at a time. It was taken as two pairs on 2026-10-22, 10:43 to 10:48 and 11:28 to 11:33 (`base-a` and `base-b`; only the filtered copies of the first pair were kept). All four are byte-identical after the Jolt load warning is filtered, **81 of 81 strict**, every exit code 0 (`measurements/close-out-2026-10-22/baselines-base-a-vs-base-b.txt`; `filter.sh.txt`). The baseline is the tree before the story whatever the live tree held, so the 10-16 sitting's edits do not touch it.
- **Measure first** (the story's list): see "Measured facts" below. The probes are `measurements/stencil_probe.gd.txt`, `flags_probe.gd.txt`, `flags_probe2.gd.txt`, `draw_check.gd.txt` and `measure.gd.txt`, with the notes of both sittings in `measurements/probe-notes-2026-10-16-and-22.md`.
- **`see_through`** (headless, `--fixed-fps 60`, the build as it ships: every earlier opt-in and the new `SEE_THROUGH`, Map 01, every Player's act a real key event; `scenario-outputs/split-see_through.txt`): **20 checks, 0 failed, 10.917 simulated seconds**. The final chain ran it twice in parallel, and the two outputs are byte-identical and equal to the output of 12:43 (`measurements/see_through-after-the-review.txt`). It is a kit (`see_through_kit.gd`, composition over the earlier kits) and five modules (`data`, `cameras`, `copies`, `life`, `lint`), each run alone first with `SEE_ONLY=name`. Its one ERROR line is expected: `settings_refused` gives a Unit a strength of 2, which logs its one named error and leaves the Unit drawn as before.
- **`light_showcase`** (headless: `scenario-outputs/split-light_showcase.txt`, 45 moments, no premise failure, the same `frame=` lines as the windowed finalA; windowed with `--write-movie`: finalA, finalN and finalA2 above, `measurements/recording-finalA.out`, `recording-finalN-without-silhouettes.out`, `close-out-2026-10-22/recording-finalA2.out`). Each silhouette moment asks, before its frame, that cover hides some of each Unit's box from its own camera (rays to the box's centre and corners). A light moment asks that the Environment holds the look it names. A premise that does not hold prints a failing CHECK, so a recording that does not show its moment cannot pass. Each full-size PNG retained is a byte copy of the PNG the recording wrote for its `frame=` line (`measurements/retain-output.txt`, by `retain27.py.txt`; frames 38 and 39 by `close-out-2026-10-22/retain_closeout.py.txt`).
- **The AgX ladder** (`LIGHT_MOMENTS=explore LIGHT_PASS=above`: eight AgX settings on the flat, used to choose the data). Recorded on the final tree in the close-out, it is byte-identical to the 11:22 recording in all 218 frames, so the ladder's numbers below stand on the final tree (`close-out-2026-10-22/recording-explore2.out`, `vulkan-check-and-ladder.txt` part 3).
- **`light_fps`** (windowed, real renderer, no `--write-movie`, both Units driving out of their Gates, over the salt flat and along the canyon road and into the other Player's Gate in both views): see "The frame rate" below.
- **The 81 older outputs** (headless, three at a time) against the baseline: **69 strict, 12 normalized, 0 bad of 81 compared** (`close-out-2026-10-22/regress-81-final-chain.txt`; its normalized rows and total equal `measurements/regress-81-final.txt` of 12:46). The rewrites are exact and were generated from the source by `measurements/mknorm27.sh.txt` (`normalizers.json`; regenerated in the final chain, byte-identical):
  - The runner's printed `advance_ticks` line moved from `:1671` to `:1703` (the strip, the constant and three registrations), in all 12 outputs.
  - `unit.gd`'s `spawn` line moved from `:661` to `:681` (in `badly_damaged`), and its `destroy` line from `:598` to `:618` (in `explosions` and `tokens_data`). Both moved because of the `silhouette` export and `_dress_silhouette()`.
  - `fuel_building` prints its count of scripts under `res://src`, 67 and now 69 (the two new scripts). `mklint27.py.txt` reads the old number from the pre-edit copy of `src` and checks it against the baseline's own.

  No other line moved.
- **The runner's strip, measured as the story asks** (`measurements/probe-strip-*.txt`; scratch copies whose strip is patched with a replacement that keeps the line count, `run_probes27.py.txt`):
  - With the strip's assignment kept (`sil_kept`: the Units keep their settings), **4 older outputs differ**.
  - With the strip bypassed (`strip_off`), **the same 4 differ**: `badly_damaged` and `camera_views` (they print the cameras' cull masks), and `gyro_cover` and `rotors` (they print model boxes, which merge the copies).

  Each is a killed regression defect below. An earlier probe, before the review's fix F2, kept only the cameras' masks: 2 outputs differed (`badly_damaged`, `camera_views`).
- **Parse check** (`.claude/scripts/godot-parse-check.gd` over the 20 `.gd` files the story added or changed, `close-out-2026-10-22/final-chain-parse.txt`): 20 `ok`, 0 `PARSE FAIL`. The import prints no ERROR or WARNING (`final-chain-import.txt`). The final chain, in the order manifest, import, parse, rewrites, regression, scenario twice, showcase, gdUnit, main scene, manifest, is `close-out-2026-10-22/final27.sh.txt`, and its output is `final-chain.txt` (19:58 to 20:01).
- **The main scene** (`godot --path . --windowed --resolution 1280x720`): 600 frames on the final tree, rc 0, no ERROR, WARNING or SCRIPT line (`final-chain-main-scene-600-frames.txt`). The 90-frame launch recording is `close-out-2026-10-22/recording-launch.out`. gdUnit (`final-chain-gdunit.txt`): 1 test, 0 failures.
- **Seeded defects:** 87 headless mutants, **87 killed, 0 survived, 0 broken**. 85 ran at 12:52 on the final tree (`measurements/seeded-defects.txt`, `run-mutants27.sh.txt`, `seeded-defects27.py.txt`, three workers, 1 min 46 s). Two more from the story's list were added in the close-out (`close-out-2026-10-22/seeded-defects-two-more.txt`). The scratch copies equal the repo at the end of each run. Two more were recorded windowed, as the story asks: see "Seeded defects".
- **The Vulkan check** (the review's F1, TD-019): see measured fact 12.
- **Review:** one read-only pass by `godot-gdscript-specialist` (about 248k tokens) while a timing run was live, so it read only. It reported eight findings and no blocker (`measurements/engine-review.txt`; see "Review").

## Acceptance criteria

| AC | Result | Where |
|---|---|---|
| AC-1 a tone mapper other than Linear (AgX to start), exposure and white as data in `map_01.tscn`; Linear, AgX, Filmic and ACES recorded at the same moments; the salt flat's clipped share in a fixed crop measured before and after and falling; the Team colours' hue in sun and shade measured | PASS with a finding (question 1) | `environment_data` (tone mapper 4, AgX, at exposure 1.3, AgX white 10 and contrast 1.5, read from `map_01.tscn`). Frames 01 to 20 (the five looks at the same moments). The flat's clipped share in two fixed crops falls from 0.062% under Linear to 0.000% under AgX. The Team hues are measured under every look: Orange and Teal stay 159 to 167 degrees apart (measured facts 6 and 7). The cracks' contrast falls too (0.054 and 0.071 to 0.031 and 0.052), and no AgX setting tried brings it back: question 1 |
| AC-2 glow on for what is brighter than white only; its HDR threshold (data) above the brightest lit surface, measured first; the flat, the sand and the Bases never bloom while a probe above the threshold does | PASS | `environment_data` (glow on, HDR threshold 2.0, scale 1.0, intensity 0.8, levels 3 to 5). The brightest lit value is 1.08 on the flat and 1.18 on the ford (an earlier probe saw 1.59 on a water glint): measured fact 5. With no probe, the glow on and off differ in **0 of 921,600** pixels. The probe of 1.2 has no halo of its own, and the probes of 4 and 8 do (frames 21 and 22, measured fact 8). The windowed defect with the threshold at 1.0 changes the flat by one level in 2,406 pixels: "Seeded defects" |
| AC-3 a colour grade (adjustments and a lookup texture written by a script of the repository, no downloaded file), warmer and dustier; Orange and Teal apart; the HUD's band the same pixels before and after | PASS | `grade_data` (from `colour_grade.json`: a mid grey reads (0.514, 0.504, 0.490) and white (1.0, 1.0, 0.935), redder than blue; the Team colours' hue moves 0.33 and 2.55 degrees and they stay 150.5 degrees apart). `lut_file` (`colour_grade_lut.res` holds all 32 layers, byte for byte what `tools/colour_grade/build_colour_grade_lut.gd` writes). `environment_data` (adjustments on: contrast 1.04, saturation 0.97, the 32-texel lookup). In frames the grade moves a Team hue by at most 0.82 degrees and warms the flat from (204, 199, 190) to (215, 201, 180). The HP and Fuel bars of both views are pixel for pixel the same under all five looks (4 x 3,920 pixels). Frames 02 against 05, and 11 against 14 |
| AC-4 the hidden part of a Player's own Unit drawn over the cover as a flat, see-through silhouette in its Team colour (strength data), in both of that Player's views; the parts in sight as today; never its own hidden parts over itself; never in the other Player's view; the other Player's Unit never drawn through anything; none out of play, none for the smear, the smoke or the explosion | PASS with a finding (question 6) | The checks:<br>- `settings_data` and `project_layers`: the data and the two named layers.<br>- `cameras`: in all four states of the two views, each camera draws its own Player's layer and never the other's.<br>- `copies`: 60 copies for 30 meshes over 8 Units, each on its Player's layer, with no shadow and never culled by occlusion, and one fill quad each.<br>- `passes`: no Map mesh and none of the Units' own materials uses the stencil.<br>- `turning_parts`: 16 copies under the four pivots turn with them; the smear is not copied.<br>- `small_things`: the 15 smoke puffs get none.<br>- `benched_at_start`, `life`, `retype`, `respawn_cost` and `undressed`: none out of play, after a destruction, a Swap or a change of type; none for a Unit with no Player.<br><br>Frames 23 to 32 show the silhouettes. The difference masks of all 13 silhouette moments (finalA against finalN) hold only the hidden part. A Unit's whole area shows only when the seeded defect `no_sight_copy` is in: frames 34 to 37 and 39, measured fact 11. Question 6: your silhouette also shows over the other Player's Unit (frame 30) |
| AC-5 every value is data (the tone mapper, the glow, the grade and the lookup's script parameters, the silhouette's strength and layers); no number in code but 0 and 1 | PASS | `settings_data`, `environment_data`, `grade_data` and `lut_file` (the values read from the data files). `project_layers`. `no_number_in_code`: 262 code lines of the two new scripts, the grade's tool and the five functions the story changed hold no number but 0, 1, 0.0 and 1.0, name no Unit type, and search no tree and ask no singleton. `settings_refused`: `first_problem()` names each of 41 faults with its own sentence |
| AC-6 both views keep the project budget windowed at 1280 x 720 with both Units driving behind cover (the lowest one-second rate 60 fps or more, a frame of at most 16.6 ms, at most 1,000 draw calls); the frame time with and without the glow and the silhouettes, and the draw calls the silhouettes add, recorded beside TD-016 and TD-017 | PASS with a finding (TD-016) | "The frame rate" below. The lowest steady second is 117 to 120 fps in every run on the final tree, with at most 301 draw calls against 1,000; the silhouettes add 14 draw calls. Single frames over 16.6 ms appear in steady seconds of every variant, the picture before the story among them: the pattern TD-016 holds, with this story's numbers added there |
| AC-7 the older scenarios keep their outputs byte for byte against the capture at the start; every scenario that does not declare the opt-in runs with no silhouettes and with today's camera masks | PASS | 69 strict, 12 normalized (exact rewrites generated from the source), 0 bad of 81. The strip probe: 4 outputs differ with the strip off, each a killed regression defect |

## Measured facts (the story's "Measure first")

1. **The Environment on 4.7.2.** `tonemap_mode` is 0 Linear, 1 Reinhard, 2 Filmic, 3 ACES, 4 AgX. Its exposure and white default to 1; AgX's white is 16.29 and its contrast 1.25. Reinhard with a white of 1 draws exactly as Linear. The glow's HDR threshold defaults to 1.0 and its scale to 2.0, with intensity 0.3, Screen blending and levels 0, 0.8, 0.4, 0.1, 0, 0, 0. `adjustment_color_correction` takes a Texture2D or a Texture3D. A new Environment reads Linear, no glow and no adjustments, so Map 01 drew through Linear before this story (`probe-notes-2026-10-16-and-22.md`).
2. **A material reads the stencil or writes it, never both.** `BaseMaterial3D.stencil_flags` READ and WRITE are mutually exclusive in one material. Setting 3 (READ and WRITE) reads back 1 from a fresh material, then 2, then 1: the newly added bit wins. READ also excludes WRITE_DEPTH_FAIL, while WRITE and WRITE_DEPTH_FAIL (6) coexist (`flags_probe2.gd.txt`). So the 10-16 design, copies that read "not equal" and write, only read. Where two hidden parts overlapped, its colour was blended twice.
3. **The silhouette's design, probed** (`stencil_probe.gd.txt`, windowed, two 640 x 360 SubViewports at 4x MSAA on one World3D, a wall and a Unit of three boxes):
   - **Copies that only read:** where two hidden parts overlap, the colour reads (72, 148, 146) against (94, 142, 144) for one. That is not flat.
   - **Three transparent passes ordered by `render_priority` (built):** (94, 142, 144) in both places, and the parts in sight are exactly the Unit's colour (229, 115, 36).
   - **Opaque markers drawn first by priority:** they fail. Everything turned magenta: an opaque material's priority is not a draw order.

   The 10-16 probe of the story's fallback, the depth test Inverted, tinted the parts in sight ((0.910, 0.463, 0.165) against (0.922, 0.471, 0.188)): it draws a Unit's own hidden parts over itself.
4. **The 3D lookup.** An `ImageTexture3D` works as `adjustment_color_correction`. The engine samples it with no half-texel correction:
   - Texel i written at i / (N - 1) is wrong: 60 for 64 at 0.25, and 195 for 191 at 0.75.
   - Texel i at (i + 0.5) / N, with the first and last texel exact, reproduces an identity within 1/255 in the middle. The end half-texel bands are off by up to 3/255 at N = 32, against 8/255 at N = 16. So N = 32.

   A hand-written `.import` with `importer="3d"` was rewritten to `importer="texture"` by `--import`, and the system Python has no numpy. So the lookup is written by a GDScript tool of the repository, `tools/colour_grade/build_colour_grade_lut.gd` (run windowed with `godot --path . --resolution 64x64 -s res://tools/colour_grade/build_colour_grade_lut.gd`, parameters in `colour_grade.json`), as an `ImageTexture3D` saved to `src/gameplay/maps/map_01/textures/colour_grade_lut.res`. The story suggested Blender's Python; the decision log says why not.
5. **The brightest lit value.**
   - The 10-16 exposure ladder (Linear, the output clamped at a lowered exposure) found 1.26 on the salt flat, 1.16 in the east crop and 0.73 on the ford's water, whose glints peak about 1.59.
   - The final recording's frames taken with Linear at a quarter of the exposure (`dark_a` to `dark_d`, where nothing clips) read the largest channel over the exposure: 1.08 and 1.05 on the flat, and 1.17 to 1.18 and 1.03 at the ford (`measurements/frames-measured.txt`).

   The threshold of 2.0 is above all of them. `see_through`'s sentence names 1.6, the glint.
6. **The tone mappers on the same frames** (the flat from above, crops (330, 160, 230, 260) and (700, 160, 230, 260), `frames-measured.txt`):

   | Look | Clipped (a channel at 255), left / right | Luma mean | Luma sd (the cracks' contrast) |
   |---|---|---|---|
   | Linear (before) | 0.062% / 0.062% | 0.808 / 0.804 | 0.054 / 0.071 |
   | AgX as shipped | 0.000% / 0.000% | 0.794 / 0.790 | 0.031 / 0.052 |
   | AgX without the grade | 0.000% / 0.000% | 0.780 / 0.777 | 0.030 / 0.051 |
   | Filmic (exposure 1.0) | 8.4% / 9.9% | 0.915 / 0.912 | 0.041 / 0.062 |
   | ACES (exposure 1.0) | 33.2% / 34.3% | 0.939 / 0.935 | 0.039 / 0.065 |

   **The AgX ladder** tried other settings on the same flat (byte-identical recordings at 11:22 and 19:40, `vulkan-check-and-ladder.txt` part 3). The shipped setting (exposure 1.3, contrast 1.5, white 10) reads 0.031 and 0.052. Contrast 1.8, 2.1 and 2.4 read 0.031 to 0.032 and 0.054 to 0.057. Exposures 1.2 and 1.4 read 0.033 and 0.030 against 0.057 and 0.055, and whites 6 and 16.29 read 0.032 against 0.056. None clips, and none brings the contrast back to Linear's. The higher contrasts raise the mean (0.816 to 0.851) more than the contrast. The 10-16 grid chose exposure 1.3, contrast 1.5 and white 10 as the creamy flat with no clipping; question 1 puts it to the author.
7. **The Team colours** (mean hue of the Trucks' Team-painted pixels in the close-ups, `frames-measured.txt`), in degrees:

   | Look | Orange, sun | Teal, sun | Orange, shade | Teal, shade |
   |---|---|---|---|---|
   | Linear | 21.4 | 185.2 | 20.9 | 186.2 |
   | AgX | 26.3 | 185.5 | 24.7 | 186.5 |
   | AgX, no grade | 26.0 | 184.8 | 24.5 | 185.7 |
   | Filmic | 24.5 | 185.9 | 21.7 | 186.9 |
   | ACES | 23.0 | 185.3 | 19.9 | 186.5 |

   The two are 159 to 167 degrees apart under every look, and the grade alone moves either by 0.2 to 0.8 degrees. AgX turns Orange about 5 degrees toward yellow. Saturation rises under AgX (Teal 0.64 to 0.84 in the sun).

   **The sky:** the sky above the horizon in the chase-view close-ups (`close-out-2026-10-22/sky.txt`, a 160 x 60 crop under the HUD) reads:
   - (155, 170, 194), blue, under Linear;
   - (171, 182, 195), a paler blue, under AgX without the grade;
   - (180, 183, 183), a neutral grey, under AgX with the grade, as shipped: the grade's warm highlights take the blue out;
   - (202, 205, 208) under Filmic and (212, 213, 213) under ACES.

   Question 2.
8. **The glow.** The flat with no probe, glow on against off, differs in 0 of 921,600 pixels. Three probes of emission 1.2, 4 and 8 stand in front of each Unit (frames 21 and 22). A profile across them, at y 272, takes the largest channel difference in columns of 12 pixels. The column over the 1.2 probe's centre differs by 0 levels, those over the 4 and 8 probes by up to 43, and the halo's faint edge reaches 1 level far to the side. The bottom third of the frame differs in 4 of 256,000 pixels by 1 level (`frames-measured.txt`). The 10-16 probe saw the threshold of 1.0 bloom the Base's orange by 0.014.
9. **The HUD is not graded.** The four HP and Fuel bars (rectangles of 280 x 14 pixels) are the same pixels under Linear, AgX, AgX without the grade, Filmic and ACES: 0 of 3,920 differ in each (`frames-measured.txt`). The HUD is a Control over the SubViewport's 3D picture, and the Environment's adjustments act on the 3D picture only.
10. **A windowed run can freeze unseen.** On 10-16 at 21:10, windowed Godot drew for about 3 s and then stopped, while the user's browser, playing a video, came to the front. Movie Maker still wrote one PNG a frame, of a frozen picture: a recording made then would have looked valid and been wrong. Since then every windowed step starts with `draw_check.gd.txt` (frames drawn a second and focus). In the close-out it read 120 frames a second, focused, on Metal and on Vulkan. Every recording was also checked to change from moment to moment.
11. **The silhouette covers only the hidden part.** Each moment of finalA was compared with the same moment of finalN, pixel by pixel (`close-out-2026-10-22/vulkan-check-and-ladder.txt` part 1, by `masks.gd.txt`). The pixels that differ, per view:

    | Moment | Player 1 | Player 2 | Box (P1) |
    |---|---|---|---|
    | Turret, chase (Motorbikes) | 655 | 655 | 21 x 49 |
    | Corner tower, chase (Buggies) | 3,006 | 3,006 | 64 x 64 |
    | Water tower leg, chase (Trucks) | 5,573 | 5,573 | 72 x 102 |
    | Container, chase (Trucks) | 2,349 | 2,349 | 80 x 32 |
    | Cliff, chase (Buggies) | 1,463 | 1,463 | 61 x 63 |
    | Depot tank, chase (Motorbikes) | 455 | 457 | 21 x 36 |
    | Gyrocopters under the tank, chase | 49 | 49 | 20 x 21 |
    | Behind the other Player's Truck, chase | 150 | 0 | 15 x 15 |
    | Corner tower, from above (Buggies) | 104 | 104 | 34 x 6 |
    | Water tower leg, from above (Trucks) | 106 | 106 | 25 x 7 |
    | Container, from above (Trucks) | 41 | 42 | 34 x 3 |
    | Cliff, from above (Buggies) | 1,057 | 1,069 | 35 x 48 |
    | Gyrocopters under the tank, from above | 38 | 38 | 31 x 91 |

    With the seeded defect `no_sight_copy` in, nothing marks the parts in sight (`defects-windowed-and-vulkan-light.txt` part 4a). Every mask then holds the build's mask and the visible rest of the Unit: the whole Unit, 769 pixels for a Motorbike, 3,006 for a Buggy, about 5,967 for a Truck and 1,418 for a Gyrocopter. Against those areas, the build's silhouette is 655 of the Motorbike's 769 behind the Turret, all 3,006 of the Buggy behind the tower (it is wholly hidden), 1,463 of 3,006 behind the cliff and 49 of the Gyrocopter's 1,418 under the tank. In Player 2's view behind the Truck the defect tints all 5,961 pixels of Player 2's own Truck, where the build changes none. So the parts in sight look as they did, a Unit never shows its own hidden parts over itself, and the other Player's view shows nothing of the first Player's Unit.
12. **The Vulkan check** (the review's F1, TD-019; `close-out-2026-10-22/vulkan-check-and-ladder.txt` part 2 and `defects-windowed-and-vulkan-light.txt` part 5). The silhouette moments were recorded with `--rendering-driver vulkan` (Vulkan 1.2.334 through MoltenVK on the M4 Pro) twice: with the silhouettes (`vk-sil`, 963 frames) and without (`vk-nosil`). The light moments were recorded on Vulkan too (`vk-light`).
    - **Masks:** the masks of all 13 moments are pixel for pixel the Metal masks above (the overlap: all pixels in both, 0 in either alone).
    - **Frames from above:** the five moments, which fall on the same frame numbers in both recordings, are pixel-identical between the drivers, with and without the silhouettes.
    - **Light frames:** the six light moments compared (the flat under Linear, AgX and AgX without the grade; the sun close-ups with and without the grade; the glow) are pixel-identical to Metal's, and the glow on and off differ in none.

    So on this Mac, Godot's Vulkan driver draws the three passes in order, keeps the stencil per viewport and MSAA sample, passes the sight copy's depth test where the part is in sight (F1: no speckle), and samples the lookup as Metal does. MoltenVK translates Vulkan to Metal on the same GPU, so this covers Godot's Vulkan driver code (render passes, stencil and depth state, MSAA) and not another shader compiler or GPU. D3D12, Windows' default since 4.6, and a Windows GPU's own Vulkan driver stay unobserved: TD-019, narrowed, and question 7.

## The frames

All 40 are in `production/qa/evidence/story-027-light-colour-and-silhouette/` and were opened and read. The sources:
- 01 to 32 are byte copies of finalA's PNGs, named by the recording's own `frame=` lines (`measurements/retain-output.txt`, 32 byte copies).
- 00 is the launch recording's last frame.
- 38 is `vk-sil`'s frame 469, and 39 is the defect recording's frame 400 (byte copies).
- 40 is composed by `measurements/close-out-2026-10-22/compose40.sh.txt` (`compose.gd`: a 4x crop of Player 1's view of frame 23 beside the same crop of finalN's frame 1059), and rebuilt byte for byte.
- 34 to 37 were composed at 13:04 from finalA and finalN (the frame scaled to 960 pixels wide above its difference mask). The composing command was not kept; its pixel counts were measured again in the close-out (measured fact 11). At `/story-done` they were found to be byte copies of the composites the morning sitting left (see Checks at `/story-done`).

The showcase picks Motorbikes with the choice keys at the start and puts each moment's type in play with a tool, so every HUD's Token line reads "Motorbike Tokens: 12".

The retain script also planned a 33, a Unit behind a Turret from above. The probe found that from above a 3 m Turret hides none of a Motorbike's box from the Turret's far face to 10 m behind it: 2 of 9 points hide only at -1.0 and -0.5 m, where the Motorbike would stand in the Turret. So that moment was never staged, and no 33 exists.

| File | What it shows |
|---|---|
| `00-launch-both-players-choosing.png` | The launch (the 90-frame recording's last frame): both Players choosing their Unit, the Bases, the water towers and the walls under AgX and the grade. |
| `01-flat-from-above-linear-before.png` | `light_flat_linear` (frame 408): both Trucks on the salt flat from above under Linear, the look before the story: a bright white flat with crisp cracks. |
| `02-flat-from-above-agx-as-shipped.png` | `light_flat_agx` (418): the same under AgX with the glow and the grade, as shipped: a creamier, warmer flat; the cracks softer but readable; no white patch. |
| `03-flat-from-above-filmic.png` | `light_flat_filmic` (438): Filmic at an exposure of 1.0: brighter and warmer, the middle of the flat near white. |
| `04-flat-from-above-aces.png` | `light_flat_aces` (448): ACES: the brightest, the flat's middle washing to white (a third of the crop clipped), the sand more saturated. |
| `05-flat-from-above-agx-without-the-grade.png` | `light_flat_agx_no_grade` (428): AgX without the grade: a cooler, greyer flat than 02. |
| `06-base-in-shade-linear-before.png` | `light_base_linear` (504): each Truck in the shade of its Base's water tower, from above, under Linear. |
| `07-base-in-shade-agx-as-shipped.png` | `light_base_agx` (514): the same as shipped: softer contrast, the corner towers' Team colours a little lighter. |
| `08-base-in-shade-filmic.png` | `light_base_filmic` (534). |
| `09-base-in-shade-aces.png` | `light_base_aces` (544): the sunlit sand the brightest of the four. |
| `10-close-in-sun-linear-before.png` | `light_sun_close_linear` (590): the two Trucks close up from behind in full sun on the flat, under Linear; a blue sky. |
| `11-close-in-sun-agx-as-shipped.png` | `light_sun_close_agx` (600): as shipped: the Orange a little yellower and the Teal deeper; the sky a neutral grey (measured fact 7). |
| `12-close-in-sun-filmic.png` | `light_sun_close_filmic` (620): a pale, bright sky and flat. |
| `13-close-in-sun-aces.png` | `light_sun_close_aces` (630): near-white sky and flat. |
| `14-close-in-sun-agx-without-the-grade.png` | `light_sun_close_agx_no_grade` (610): AgX alone: the sky a pale blue, the flat greyer than 11. |
| `15-close-in-shade-linear-before.png` | `light_shade_close_linear` (706): each Truck close up in its Base's shade, its corner tower and water tower behind it, under Linear. |
| `16-close-in-shade-agx-as-shipped.png` | `light_shade_close_agx` (716): the same as shipped. |
| `17-close-in-shade-filmic.png` | `light_shade_close_filmic` (736). |
| `18-close-in-shade-aces.png` | `light_shade_close_aces` (746). |
| `19-ford-from-above-linear-before.png` | `light_ford_linear` (822): both Trucks on their banks of a ford from above, the water with its pale glints, under Linear. |
| `20-ford-from-above-agx-as-shipped.png` | `light_ford_agx` (832): the same as shipped. The water is a pale grey-green (183, 199, 189; hue 140 to 143 degrees, saturation 0.08) where frame 19's was a light cyan (150, 200, 206; hue 187 degrees, saturation 0.27): measured at `/story-done`, see the findings. |
| `21-glow-three-probes-glow-on.png` | `glow_probes_on` (938): three white spheres of emission 1.2, 4 and 8 in front of each Truck, the glow on: soft halos round the 4 and the 8, none round the 1.2, nothing else glowing. |
| `22-glow-three-probes-glow-off.png` | `glow_probes_off` (948): the same with the glow off: three plain discs. |
| `23-silhouette-behind-a-turret-chase-view.png` | `sil_turret_chase` (1059): each Player's Motorbike 3 m behind the far face of its Base's left Turret, in the chase view. The Turret hides all of it but the handlebars. The hidden Motorbike shows over the Turret as a flat orange shape in Player 1's half and teal in Player 2's, and the handlebars above the Turret are drawn as always (frame 40 zooms in). |
| `24-silhouette-behind-a-corner-tower-chase-view.png` | `sil_tower_chase` (1125): each Buggy 9 m behind its Gate's corner tower, wholly hidden: the whole Buggy shows as a flat silhouette over the tower's dark wall. |
| `25-silhouette-behind-a-water-tower-leg-chase-view.png` | `sil_leg_chase` (1191): each Truck behind its water tower's Gate-side leg and the box of Flag Walls: the hidden Truck flat over the leg; the antenna above it drawn as always. |
| `26-silhouette-behind-a-container-chase-view.png` | `sil_container_chase` (1257): each Truck behind a container on the flat: the cab drawn as always, the lower body the container hides flat in the Team colour. |
| `27-silhouette-behind-a-cliff-chase-view.png` | `sil_cliff_chase` (1323): each Buggy below the canyon's south cliff: its top drawn as always, the part behind the cliff's edge flat. |
| `28-silhouette-both-behind-the-depot-tank-each-view-shows-only-its-own-chase-view.png` | `sil_leak_chase` (1389): both Motorbikes behind the depot's south tank, 2.6 m apart. Player 1's half shows only the orange Motorbike's hidden part over the tank and Player 2's only the teal one's; neither shows the other Player's Unit through the tank. |
| `29-silhouette-gyrocopters-under-the-tank-chase-view.png` | `sil_tank_chase` (1455): each Gyrocopter between its water tower's legs, under the tank: the part of its rotor the cross-braces hide drawn flat in the Team colour. |
| `30-silhouette-over-the-other-players-truck-chase-view.png` | `sil_unit_in_front_chase` (1521): Player 2's Truck stands between Player 1's camera and Player 1's Motorbike. Player 1's half shows the Motorbike's hidden part in orange over the teal Truck (question 6); Player 2's half shows its own Truck as always. |
| `31-silhouette-behind-a-corner-tower-from-above.png` | `sil_tower_above` (74): each Buggy just past its corner tower, from above: the tower's top hides only a sliver of its tail, so the silhouette is a band of 34 x 6 pixels at the tower's edge. |
| `32-silhouette-behind-a-cliff-from-above.png` | `sil_cliff_above` (272): each Buggy at the foot of the canyon's cliff, from above: the body the cliff's edge hides shows flat in the Team colour. |
| `34-difference-mask-turret-chase-view.png` | Frame 23 above its difference mask against the same moment without the silhouettes: white only where the Turret hides the Motorbike (655 pixels in each view). |
| `35-difference-mask-both-behind-the-depot-tank.png` | Frame 28 and its mask: only each Player's own Motorbike's hidden part, 455 and 457 pixels. |
| `36-difference-mask-cliff-chase-view.png` | Frame 27 and its mask: only the part below the cliff's edge, 1,463 pixels in each view. |
| `37-difference-mask-over-the-other-players-truck.png` | Frame 30 and its mask: 150 pixels in Player 1's view, none in Player 2's. |
| `38-vulkan-silhouette-behind-a-turret-chase-view.png` | `sil_turret_chase` on Vulkan through MoltenVK (`vk-sil`, frame 469): the same picture as frame 23; its mask equals Metal's pixel for pixel (measured fact 12). |
| `39-seeded-defect-no-sight-copy-behind-a-cliff-chase-view.png` | The seeded defect `no_sight_copy` (the defect recording, frame 400), at the moment of frame 27. With no copy marking the parts in sight, each whole Buggy is drawn as a flat silhouette, its sunlit top and wheels too. This is what a failing depth test would look like (the review's F1). |
| `40-silhouette-behind-a-turret-zoomed-4x-with-and-without.png` | Player 1's view of frame 23 at 4x (left) beside the same moment without the silhouettes (right): without it only the handlebars show above the Turret's head; with it the hidden Motorbike is a flat orange shape over the Turret, the handlebars unchanged. |

## The frame rate

AC-6's budget (`.claude/docs/technical-preferences.md`: the lowest one-second rate 60 fps or more, a frame of at most 16.6 ms, at most 1,000 draw calls, both views together), on the 120 Hz display. `light_fps` runs three legs in each view: out of both Gates, Player 1 over the salt flat while Player 2 drives the canyon road end to end, and into the other Player's Gate. The chase camera starts inside each Base, so the towers, legs, walls and Turrets are between it and the Unit, which is then drawn as its silhouette. The Turrets are taken down first and stay as wrecks. The first second, and every second in which a leg is staged, are left out of the steady figures. Every run on the final tree has 35 steady seconds, and all six legs of every run ended `ok`. The table is by `close-out-2026-10-22/fps_table.py.txt`; it also counts the seconds the display did not pace (over 125 fps on the 120 Hz screen: the window covered or out of focus).

**On the final tree** (the close-out, 19:46 to 19:51: three runs as shipped and three of the picture before the story, interleaved, every window kept on top; `close-out-2026-10-22/fps/`, `fps-table-final-tree.txt`):

| Run | Lowest steady second | Longest steady frame | Steady seconds over 16.6 ms | Draw calls at most | Unpaced seconds | At t = 8.083 s: draw calls / primitives |
|---|---|---|---|---|---|---|
| shipped 1 | 120 fps | 12.86 ms | 0 | 301 | 0 | 241 / 388,288 |
| before 1 | 120 fps | 12.55 ms | 0 | 287 | 0 | 227 / 342,256 |
| shipped 2 | 119 fps | 17.57 ms | 4 | 301 | 0 | 241 / 382,144 |
| before 2 | 118 fps | 24.56 ms | 2 | 287 | 0 | 227 / 342,256 |
| shipped 3 | 117 fps | 34.54 ms | 2 | 301 | 0 | 241 / 382,144 |
| before 3 | 120 fps | 12.64 ms | 0 | 287 | 0 | 227 / 342,256 |

The budget's per-second rate and draw calls hold in every run: the lowest steady second is 117 to 120 fps against 60. The draw calls are 301 at most with the silhouettes and 287 without, against 1,000. At the same sample, with the Units at the same places in every run, the silhouettes add 14 draw calls and 39,888 primitives. That is two copies of each drawn mesh, which draw nothing but stencil values, and one fill quad a Unit.

Single frames over 16.6 ms appear in steady seconds of both variants: as shipped in 2 of 3 runs (6 of 105 steady seconds), and before the story in 1 of 3 (2 of 105). That is the pattern TD-016 has recorded since story 023.

**The A/B of the morning** (11:52 to 12:19, 36 runs, before the review's fixes, which changed the silhouette's refusals, where the cameras' layers come from and the quad's size, not the passes that draw it; `measurements/fps/`, `fps-summary.txt`, and the table with the unpaced seconds `close-out-2026-10-22/fps-table-earlier-36.txt`). The variants:
- as shipped (5 runs);
- the picture before the story (5 + 5);
- the look with no silhouettes (3 + 5);
- the silhouettes with no look (3);
- no grade (5);
- no glow (5).

The lowest steady second was 113 to 120 fps in every run but one, which read a frame of 1,112.9 ms and a second of 27 fps (b2-3, the machine's). The draw calls were 301 at most with the silhouettes.

The share of steady seconds holding a frame over 16.6 ms differed more by run than by variant: the same picture read 1.1% and 6.3% in two batches of five. TD-016 has the numbers. Three things were found in the close-out that the morning's summary did not show:
- **Unpaced runs:** 8 of the 36 runs, all in the second batch (12:05 to 12:19), had stretches of 5 to 48 seconds the display did not pace (143 to 145 fps). The window was covered or out of focus while the machine was in use, so those seconds measured the machine's pacing.
- **b1-4:** one look-only run, with the silhouettes taken away and printing `no_sil=1`, read 14 more draw calls and about 38,000 more primitives in every second than its four siblings, with the Units at the same places at the samples compared. It is not explained, and its frame times are within the others'.
- **b2-4:** one run lasted 24 seconds longer with fewer draw calls, beside the 1,112.9 ms frame of b2-3.

So "287 at most without the silhouettes" holds in 26 of the 28 morning runs without them (b1-4 read 301, b2-4 288) and in all three runs before the story on the final tree.

**GPU time** (Vulkan; `measurements/gpu_time.gd.txt` sums every viewport's GPU time, over about 4,450 frames a run, two runs of each variant; `measurements/gpu/`):

| Variant | Average, run 1 / 2 | Median, run 1 / 2 | 95th percentile, run 1 / 2 |
|---|---|---|---|
| before the story (no silhouettes, Linear, no glow, no grade) | 3.338 / 3.373 ms | 3.348 / 3.399 ms | 4.202 / 4.212 ms |
| the look, no silhouettes | 2.859 / 2.844 ms | 2.785 / 2.772 ms | 3.738 / 3.593 ms |
| the silhouettes, no look | 3.366 / 3.293 ms | 3.323 / 3.262 ms | 4.092 / 4.078 ms |
| as shipped | 2.826 / 2.927 ms | 2.727 / 2.837 ms | 3.474 / 3.671 ms |

So the silhouettes cost no GPU time this measurement can see. The look reads about half a millisecond less than Linear with no glow and no grade. That is unexplained: a measurement, not a saving to count on. These runs were made before the review's fixes.

## Seeded defects

**87 headless mutants**, each one exact text replacement in a scratch copy, the scenario module that guards it run per mutant. All 87 were killed (79 by a check of `see_through`, and the strip's 8 regression ones by an older output through the strip), 0 survived, 0 broken. The groups:
- **Cameras:** both layers drawn, no layer handed over, the other's layer not hidden, the own layer hidden, the first Player's layer given to both, the settings' hidden layers forgotten.
- **Copies:** on one layer for both Players, casting a shadow, cullable by occlusion, not in the group, the transform not copied, not beside the mesh, a mesh of its own, no sight copy, no mask copy, the two materials swapped, no fill quad, a quad of 1 m, no cull margin, full strength, the template material written, the silhouette never reused, reused after a colour change, the model not dressed, dressed with no Player.
- **Data:** each refusal removed (13), the fill not equal, the fill reading the sight value, depth tested, not a billboard or shaded, the mask depth tested, visible or reading, the sight ignoring depth, writing the mask value, writing on a depth fail, drawn with the mask or after the fill, a strength of 0, a quad of 1 m, the layers equal, the second layer unnamed, the Unit without the settings, unusable settings not reported or still dressing, a mesh left out of the group.
- **Environment:** the tone mapper back to Linear, an exposure of 0, the threshold under the brightest lit value, the glow off, the grade off, no lookup, the grade's parameters changed with a stale lookup, a grade that makes the Teams alike, the greybox given the new look.
- **Lint:** a number in the silhouette, the hand-off or the camera's mask; a type named in the dressing; a tree searched.
- **Regression:** the runner keeping the silhouette, and the strip turned off, each killed by the 4 outputs the probe found.

**The story's list.** The list names ten defects, and each is in. Both cameras drawing both layers is `cameras_draw_both_layers`. The copy reading no stencil is, in this design, `no_sight_copy` and `fill_reads_not_equal`, both headless, and windowed below. A copy casting a shadow is `copy_casts_a_shadow`. A copy on the other Player's layer is `copy_on_one_layer_for_both_players`. The tone mapper back to Linear is `tone_mapper_back_to_linear`. The threshold under the brightest value is `glow_threshold_under_the_brightest_lit_value`, headless, and windowed below. A colour written in code is `a_number_in_the_silhouette`. The runner leaving the copies on is the 8 regression ones. Two more of the list were added in the close-out (`seeded-defects-two-more.txt`):

| Mutant | Killed by |
|---|---|
| `copies_left_in_the_world` (a copy added to the root instead of beside its mesh, so it stays drawn after a destruction) | `life`, `retype`, `respawn_cost` |
| `team_material_writes_the_stencil` (the Orange Team material writes the value 2: a Base piece of the same Team would cut its Unit's silhouette away) | `passes` |

**Two that the story asks to see in a window**, recorded windowed in a fresh scratch copy with one exact replacement each (`close-out-2026-10-22/windowed_mutants.sh.txt`, `wm.progress`; the copy equals the repo again at the end):

| Mutant | What the window shows |
|---|---|
| `no_sight_copy` (the chase moments) | the whole of each Unit drawn as its silhouette, the parts in sight too (frame 39). Every mask holds the build's and the rest of the Unit: 228 more pixels behind the Turret, 7,235 behind the container, 3,086 behind the cliff, 2,738 under the tank, and in Player 2's view behind the Truck all 5,961 pixels of its own Truck (measured fact 11). Killed headless too, by `copies`. |
| `glow_threshold_under_the_brightest_lit_value` (threshold 1.0, the light moments) | the flat with the glow on and off differs in 2,406 of 921,600 pixels, each by one level, against 0 in the build. The flat's mean colour is unchanged at (215, 201, 180). The light just over 1.0 adds too little to see, so the defect is visible to the measurement and not to the eye. Killed headless by `environment_data`. |

## Review

One read-only pass by `godot-gdscript-specialist` (about 248k tokens) over the silhouette's two scripts, its four data files, the camera's mask, the Unit's dressing, the model's `_add_mesh()`, the scene's settings, Map 01's Environment, the grade's tool and data, and the engine reference. It was told not to run anything, because a timing run was live, so it reasoned from the files and its memory of the renderer and said which was which (`measurements/engine-review.txt`). It reported no blocker and eight findings:

1. **F1, major: the sight copy needs the same depth as the Unit's own pass, from another shader program.** A copy a hair behind would leave its pixel marked as hidden, and the fill would tint the part in sight in speckles. It could not be observed on Metal, and Vulkan and D3D12 promise it only for invariant positions. **Open: TD-019.** The Vulkan check (measured fact 12) found no speckle and masks equal to Metal's on Godot's Vulkan driver through MoltenVK. D3D12 and a Windows GPU are unobserved.
2. **F2, minor: the layers were written in three places** (the settings and each camera in the scene). **Fixed.** `SplitScreen._hand_silhouette_layers()` gives each camera the other Player's layer from the settings the Units carry, so the layers are written in one file. `cameras_get_no_layer_from_split_screen` and `cameras_given_the_first_players_layer` are killed.
3. **F3, minor: `first_problem()` accepted a scissored or hashed pass**, which goes to the opaque pass, where `render_priority` orders nothing. **Fixed.** It now refuses a pass that is not alpha-blended, has a next pass, a grow or a depth write, and a fill that is not mixed or is textured. The scissored pass, the next pass, the grow, the depth write and the added fill each have a killed mutant; the textured fill has a sentence in `settings_refused` and no mutant.
4. **F4, minor: the copies are made once.** A source mesh that a script hides or moves on its own would leave its copy behind. **Checked, no change:** no script hides or swaps a mesh `_add_mesh()` returned. `RotorPivot` turns the pivot (the copies are its children, `turning_parts`), and the smear is its own mesh outside the group.
5. **F5, minor: no `ignore_occlusion_culling` on the copies.** With occlusion culling turned on, a wholly hidden Unit's copies would be culled exactly when they are needed. **Fixed** on the copies and the quad, with two killed mutants.
6. **F6, minor: the fill quad.** Nothing fails, but at 1,000 m both triangles are clipped by the guard band and their shared diagonal crosses the picture. **Fixed:** the quad is 150 m, more than the picture shows at a Unit's distance (`settings_data`: over 4 camera distances of 26 m).
7. **F7, minor: `render_priority` 90, 95 and 100 are within -128 to 127.** All three draw after every transparent of priority 0, so the fill blends over smoke, explosions, the smear and water wherever a hidden Unit is behind them. **Checked:** no other material under `src` sets a priority but the greybox floor's 0, so none sorts against a pass.
8. **F8, minor: the lookup's convention is the same on every driver**, by the reviewer's memory of the one tone-map shader. Two residuals: the darkest four codes all map to the graded black, and the scene's saturation of 0.97 stacks with the lookup's 0.94. **Checked:** the Vulkan frames of the light moments are pixel-identical to Metal's (measured fact 12). The stacked saturation is the mild grade measured in frames (question 2).

## Findings kept for the author

- **AgX keeps the flat from clipping but lowers the cracks' contrast.** The luma's spread falls from 0.054 and 0.071 to 0.031 and 0.052, and no AgX setting tried brings it back (measured fact 6). The flat is creamier and paler. **Question 1.**
- **Under the shipped grade the sky in the chase view is a neutral grey**, (180, 183, 183) where Linear's was blue, (155, 170, 194). AgX alone keeps a pale blue (171, 182, 195), so it is the grade's warm highlights that take the blue out (measured fact 7). **Question 2.**
- **The fords' water changes colour under the shipped look** (measured at `/story-done` in crops inside the water of each view, frames 19 and 20): a light cyan under Linear, (150, 200, 206) and (148, 199, 205), hue 187 degrees, saturation 0.27 and 0.28, and a pale grey-green as shipped, (183, 199, 189) and (182, 198, 188), hue 140 and 143 degrees, saturation 0.08. No frame of the ford without the grade exists, so how much of it is AgX and how much the grade is not measured; the sky's frames say the grade takes the blue out. The dev evidence did not name it; it was in the developer's question 2, kept as built, and story 028 (the water) is judged under it. **Question 2.**
- **Nothing the sun lights reaches the glow's threshold.** The brightest is 1.18 at the ford against 2.0. A threshold of 1.0 would change the flat by one level in 2,406 pixels: the glow is for the fire and tracers of stories 029 and 030. **Question 3.**
- **Your silhouette also shows over the other Player's Unit** when it stands between your camera and yours (frame 30): that Unit is cover like a wall, and the values are per view. **Question 6.**
- **From above, cover hides little.** A 3 m Turret hides nothing of a Unit standing behind it, and a corner tower a sliver of 34 x 6 pixels (frame 31). The silhouette matters mostly in the chase view.
- **The silhouette costs 14 draw calls and about 40,000 primitives** for both Units, and no GPU time measured on Vulkan ("The frame rate").
- **Observed on Metal, and on Godot's Vulkan driver through MoltenVK**, which drew every frame compared pixel for pixel as Metal did. D3D12 and a Windows GPU are unobserved (TD-019). **Question 7.**
- **The machine's single long frames (TD-016)** appear as shipped and before the story alike, in the morning's 36 runs and in the final tree's 6.
- **The morning's frame-rate A/B was partly disturbed:** 8 runs had unpaced stretches while the machine was in use, and one look-only run read the silhouettes' draw calls with them taken away (unexplained). The close-out's six runs on the final tree were all paced.
- **A windowed run can freeze while another app is in front.** Movie Maker then writes a frozen picture that looks valid (measured fact 10). Every windowed step here checked drawing first.

## Questions for the author (the story's seven; each built with its default, asked at `/story-done`)

1. Map 01 now goes through the AgX tone mapper instead of none (Linear), so the bright salt flat keeps from clipping. Keep AgX, or Filmic, ACES, or back to Linear? **Built at** AgX, exposure 1.3, contrast 1.5, white 10. **Measured** on the same frames (01 to 05): the flat's clipped share is 0.062% under Linear, 0.000% under AgX, 8.4% to 9.9% under Filmic and 33% to 34% under ACES. The cracks' contrast is 0.054 and 0.071 under Linear and 0.031 and 0.052 under AgX: paler and creamier, and no AgX setting tried brings it back. Orange and Teal stay 159 to 167 degrees apart under every look.
2. The colour grade makes the scene warmer and dustier. Keep, stronger, weaker or none? **Measured:** a grey of 0.5 reads (0.514, 0.504, 0.490) and white (1.0, 1.0, 0.935), and the grade moves a Team hue by at most 0.8 degrees. It also turns the chase view's sky from AgX's pale blue (171, 182, 195) to a neutral grey (180, 183, 183) (frames 11 and 14).
3. Glow only touches what is brighter than white: nothing today, and the fire and tracers of stories 029 and 030 later. The Units' lamps stay as they are by day. Keep, or let the lamps glow a little? **Measured:** the brightest lit value is 1.08 on the flat and 1.18 on the ford, against a threshold of 2.0. The glow on and off differ in none of 921,600 pixels, and a probe of 1.2 has no halo where probes of 4 and 8 do (frames 21 and 22).
4. Your own Unit shows through cover as a see-through silhouette in its Team colour, in your view only, from above and in the chase view. Keep, or only in the chase view, or an outline instead of a filled silhouette? **Built at** a strength of 0.55 (data). Each view shows only its own Player's silhouette, the parts in sight are untouched, and the other Player's Unit shows nothing through cover (frames 23 to 40).
5. Should the Flags (your own at home, and the one your Motorbike carries) show through cover too? New work.
6. Your own Unit's silhouette also shows over the other Player's Unit when that Unit stands between your camera and yours (frame 30). Keep, or hide your silhouette behind the other Player's Unit?
7. The silhouette, the 3D colour lookup and the AgX look were observed on Metal and, through MoltenVK, on Godot's Vulkan driver on this Mac, pixel for pixel alike. D3D12, the Windows default, and a Windows GPU's own Vulkan driver are untested. A Windows build is worth a look at the stencil passes before any release (TD-019).

## Checks at `/story-done`

Run on 2026-10-22, 20:19 to 20:36, before any question was asked: scripts in the closing session's scratchpad (`verify27.sh`, `rec27.sh`, `cmp27.sh`, `xcheck27.py`, `numscan27.py`, `regress.sh`, `cmp34_37.sh`, `compose34_37b.sh`, `halves.gd`, `water.sh`, copied to `measurements/story-done/` with their outputs), with a copy of the dev session's baseline `rg27/base-a` (the 81 outputs) used read-only; nothing was written under the repo but gdUnit's gitignored `reports/` and the files of `measurements/story-done/` written at the close.

- **The tree.** `src/`, `tools/`, `project.godot` and `assets/` (the Svaty Jur art left out) hash to the 952 files of the final chain's manifest (`close-out-2026-10-22/final-chain-manifest-after-chain.txt`) and of the morning's manifest of 12:51 (taken before the 85 seeded defects and the final recordings), sorted by path (`story-done/manifest-live.txt`, before and after the check: equal), so the live tree is the one the evidence ran on. At 20:36, when the answers were in, no file in the repo was newer than the verification script, `git status` read 55 entries as at the start, no Godot process was running and `ListAgents` showed one other interactive session of the developer's idle and the rest offline.
- **Re-run.** Parse of the 20 `.gd` files of `final-chain-gd-list.txt`: 20 `ok`, 0 `PARSE FAIL` (`story-done/parse.txt`). `see_through` twice in parallel: 20 checks, 0 failed, 10.917 simulated seconds, the two outputs byte-identical and equal to `scenario-outputs/split-see_through.txt`; `light_showcase` headless (45 moments) equal to `scenario-outputs/split-light_showcase.txt` (`story-done/verify27.out.txt`). The 81 older outputs against the baseline through `normalizers.json`: 69 strict, 12 normalized, 0 bad, row for row the table of `regress-81-final.txt` (`story-done/regress-81-live.txt`). gdUnit: 1 test, 0 failures. Each of the 17 check names the acceptance table cites in `see_through` (24 citations) is a PASS line of the re-run (`story-done/xcheck.txt`; the two names it cites that are not CHECK lines are a mutant, `no_sight_copy`, and a function, `first_problem`; the three CHECK names it does not cite are `greybox_untouched`, `modules_leave_a_fresh_round` and `no_engine_noise`).
- **The recordings.** Fresh windowed `--write-movie` recordings on the live tree (rc 0, no ERROR, WARNING or SCRIPT line): the main scene's 90 launch frames and the whole `light_showcase` as shipped (1,553 frames, recorded in 4 min 40 s). All 1,643 equal the dev recordings' same-numbered frames byte for byte (the launch against the morning's, the showcase against finalA), the windowed `SPLIT` and `RESULT` lines are identical to finalA's, and the 32 retained frames 01 to 32 are byte copies of the same-numbered frames of finalA, of the repeat finalA2 and of this fresh recording, and frame 00 is the launch's frame 89 in both (`story-done/cmp-frames.txt`). Frames 34 to 37 are byte copies of the composites the morning sitting left (`story-done/cmp34_37.txt`); rebuilt from the retained frames and the close-out's difference masks by `compose.gd`'s pair mode, their top halves are identical pixel for pixel and every white pixel of the retained mask halves lies inside the rebuilt masks (4,594 of 4,670, 4,364 of 4,419, 5,484 of 5,795 and 3,927 of 3,944), the morning's tool having used another threshold at the mask's edges (`story-done/halves-34-37.txt`). The frame-rate runs were not recorded again: the tree is unchanged since the six paced runs of 19:46 to 19:51, and they need an idle machine.
- **Frames.** All 40 opened and read again at their retained paths: the descriptions in the table above hold. One observation is new: in frame 20 the ford's water is a pale grey-green where frame 19's was a light cyan, measured in crops inside the water of each view (`story-done/water-measure.txt`: (150, 200, 206) and (148, 199, 205) against (183, 199, 189) and (182, 198, 188); hue 187 degrees against 140 and 143; saturation 0.27 and 0.28 against 0.08), a change the evidence did not name before; it is in the findings, in the developer's question 2 and in the story's, and story 028 (the water) is judged under it.
- **Code.** The new scripts, the grade's tool and the data files read. An independent tokenizing scan (checked first on synthetic lines: it flags 5 of 5 that must be flagged and passes 7 of 7 that must pass; `story-done/numscan.txt`) finds no number other than 0 and 1 outside declarations in the three new scripts (`unit_silhouette.gd`, `silhouette_settings.gd`, `build_colour_grade_lut.gd`: 421 lines) and in the 73 lines the story added to `unit.gd`, `unit_model.gd`, `chase_camera.gd` and `split_screen.gd`; on declaration lines the only numbers are the bounds of two `@export_range`s (0.0 to 1.0 in steps of 0.01 for the strength, 0.0 to 16384.0 for the quad's side) and the defaults 0 and 0.0. There is no player-facing string (the strings are `push_error` and `first_problem()` sentences and node and group names), and no branch names a Unit type (`see_through`'s lint says the same).
- **Not repeated.** The windowed frame-rate runs (AC-6's budget and TD-016's numbers) and the seeded defects (87 headless at `/dev-story`, the tree unchanged since). A recording is Movie Maker's fixed 60 fps, so it does not test pacing.
- **Timeline.** The verification ended at 20:33; the forms went out after that, in three at once (the two play checks and the sign-off, the questions 1 to 4, the questions 5 to 7), and the answers were in before 20:36: about a minute, so they do not tell which build, if any, the developer played. Nothing in the repo changed meanwhile.
- **After the edits.** The four scenarios that read `README.md` (`ammo_buildings`, `mines`, `ammo`, `ammo_alone`) were run again after the README row was added: 56, 45, 41 and 2 checks, each output byte-identical to the verification run's (`story-done/readers-after-the-edits.txt`, `readers.sh.txt`).

## Human checks at `/story-done`

The look in play (both views, both cameras, both Teams), the silhouette when your Unit drives behind cover with nothing in the other Player's view, and the seven questions above, then the sign-off below. How to try it:
- Launch the main scene (`godot --path .`). Each Player picks a Unit (A / D and Space; Left / Right and Period).
- Drive each Player's Unit out from behind a Turret, a corner tower and a water tower's legs, and behind a container and the canyon cliff, in the chase view and from above (Q for Player 1, / for Player 2), watching the other Player's half.
- Look at the salt flat in full sun from above, and at the sky in the chase view.

Answered by the developer on 2026-10-22 at `/story-done` (a still cannot show the feel): the look in play (both views, as smooth as before), Yes; the silhouette (your own half only, nothing of your Unit through cover in the other), Yes; the seven questions, all kept as built (AgX at an exposure of 1.3, a contrast of 1.5 and a white of 10; the grade as built, with the neutral grey sky and the pale grey-green water of the fords; the glow's threshold of 2.0 with the Units' lamps as they are; the filled silhouette in both views; no silhouette for the Flags; your silhouette also over the other Player's Unit; TD-019 open until a Windows build is looked at); the evidence, Approved, closed with no debt row. The answers came about a minute after the forms and do not tell which build, if any, was played.

## Sign-off

| Item | Status |
|---|---|
| The new look (AgX, the grade, the glow) reads right in play, in both views (frames 01 to 22) | [x] Yes (the developer, 2026-10-22) |
| Your own Unit shows through cover as its flat Team-colour silhouette, in your own view only, and the other Player's view shows nothing (frames 23 to 40) | [x] Yes (the developer, 2026-10-22) |
| The seven questions | [x] All seven kept as built (the developer, 2026-10-22) |
| Lead sign-off (Visual/Feel evidence) | [x] Approved, close, no debt row (the developer, 2026-10-22) |

## On top of origin/main (the commit, 2026-10-22)

While this story was built on bf9e12e, 21 commits reached `origin/main` from other sessions (6e7289a: stories 032 and 036 to 047, Martin's requests of 2026-10-18 to 2026-10-22, built in cloud sessions). The developer asked for this story to be committed on top of them. Its diff was put on a scratch worktree of 6e7289a, and everything below ran there, or on a copy of 6e7289a beside it, before the commit. The scripts and outputs are in `measurements/commit-2026-10-22/`; `compare.py` and `filter.sh` are the ones already retained in `measurements/`.

- **The merge.** Twelve files changed on both sides. Eight merged with no conflict, and each differs from origin's file by exactly this story's hunks (`CONTEXT.md`, `README.md`, `design/rules.md`, `EPIC.md`, `project.godot`, `map_01.tscn`, `split_screen.gd`, `unit.gd`). Four were joined by hand (`resolve.py.txt`). `split_screen.tscn`: origin removed the AmmoCount resource (id 36) where this story added the silhouette's settings as id 37, now `47_silhouette` after origin's 37 to 46. The runner: both sides added a class-doc paragraph and scenario names at the same place, kept in story order with this story's first. `tests/smoke/critical-paths.md`: origin's items 23 to 34 stay, this story's item is now 35, and the Data Integrity and Performance items follow as 36 to 39. The class cache, rebuilt by the import: origin's 280 classes and this story's `SilhouetteSettings` and `UnitSilhouette`, nothing else (`class-cache-check.txt`). The five files only this story changed and its 301 new files went in as they were. None of the new paths exists on origin, and origin's scenes use no render layer but 1 and 2, so the silhouette's layers 3 and 4 are free.
- **The older outputs.** All 103 checks of origin's tree that run headless were run on 6e7289a and on the merged tree: this story's list of 81, origin's 21 new split scenarios and the map choice's own runner, with the 12 windowed frame-rate scenarios left out as before. Result: 90 strict, 13 normalized, 0 bad (`cmp-origin.txt`). The rewrites are written from the source (`mk_norm.py.txt`): two lines of `unit.gd` and three of the runner that moved in backtraces, and the count of scripts under `res://src` (78 to 80: this story's two). Seven of origin's windowed showcases end with their watchdog when run headless, on 6e7289a as on the merged tree, so for them only that output is compared.
- **This story's outputs.** `light_showcase` (45 moments) on the merged tree is byte-identical to its output on the tree this story closed on. `see_through` (20 checks, 0 failed) is equal through five moved backtrace lines and one count in a PASS line: "none of the Map's 2260 meshes (48 of them drawn with a Team material)" reads 2264 (54). Origin's story 043 Flag has seven meshes, four of them in the Team colour (the stand, the pole, the finial and four cloth panels), where the old one had five with one, and Map 01 has two Flags: the rewrite is taken from `flag.tscn` and `flag.gd`, not from the output (`cmp-027.txt`).
- **Parse and tests.** The 370 `.gd` files under `src/`, `tools/` and `tests/` parse (`parse-all.txt`); gdUnit 1 test, 0 failures.
- **Windowed, on Metal.** `light_showcase`'s silhouette half in the chase pass was recorded on the merged tree and on this story's tree: 630 frames each, the same `SPLIT` lines, no error. No frame is byte-identical, the HUD band is the same at all eight moments, and the moments differ in 496 to 94,954 pixels (`sil-frame-diffs.txt`). The two largest were opened. The silhouettes are the same; the differences are origin's new Flag in the Flag Wall box (frame 43: this story's tree above, the merged tree below) and the Garage floor near the camera, lit on the merged tree where this story's tree drew a broken-off shadow (story 047 turned the Sun's shadow pancaking off). The map choice's runner, windowed on the merged tree (6 checks, ok), starts Map 02 (frame 44).
- **Map 02 keeps the Linear look.** Story 038's builder copies Map 01's light and air "so both Maps look alike" (`tools/maps/build_map_02.py`), from before this story, so Map 02 has no tone mapper, glow or grade. The developer chose Map 01 only for this commit (2026-10-22). Story 046's colour proposal for Martin (ambient 0.55, the fog from 120 m at 0.12, saturation 1.2, contrast 1.06) changes the same Environment and is still open.
- **Story 045's zones no longer match their bars on Map 01.** Story 045 draws the supply zones unshaded in the bars' colours, and on 6e7289a they match exactly. On the merged tree the tone mapper and the grade reach the zones and not the HUD (`recharge_showcase` frame 06 on both trees, `zone-colours.txt`; frames 41 and 42). The ammunition zone (61, 139, 255) becomes (113, 172, 212): hue 216 to 204 degrees, saturation 0.76 to 0.47. The Fuel zone (245, 178, 46) becomes (229, 186, 99): saturation 0.81 to 0.57. The bars stay (61, 139, 255) and (245, 178, 46). Found at this commit and not changed in it: for the developer and Martin.

## Files

- **src:** `src/gameplay/units/models/unit_silhouette.gd` and `silhouette_settings.gd` (with their `.uid` files); `src/gameplay/units/data/silhouette_settings.tres` and `silhouette_mask_material.tres`, `silhouette_sight_material.tres`, `silhouette_fill_material.tres`; `src/gameplay/units/unit.gd` (`silhouette`, `SILHOUETTE_GROUP`, `_dress_silhouette()`), `src/gameplay/units/models/unit_model.gd` (`_add_mesh()`), `src/gameplay/camera/chase_camera.gd` (`never_drawn_layers`), `src/gameplay/split_screen/split_screen.gd` (`_hand_silhouette_layers()`) and `split_screen.tscn` (the Units' settings); `src/gameplay/maps/map_01/map_01.tscn` (the Environment) and `textures/colour_grade_lut.res`; `project.godot` (two named render layers).
- **Tools:** `tools/colour_grade/build_colour_grade_lut.gd` and `colour_grade.json`; `tools/evidence/split_screen_harness.gd` (the `SEE_THROUGH` strip, three registrations); `tools/evidence/split_screen/see_through*.gd` (the scenario, its kit and five modules); `light_showcase.gd`, `light_showcase_light.gd`, `light_showcase_sil.gd`, `light_fps.gd`; `quick_fix_kit.gd` (`body_meshes()` leaves out the copies and the quad).
- **Docs:** `design/rules.md` (Teams and visual style, as built), `README.md`, `CONTEXT.md` (Silhouette), `tests/smoke/critical-paths.md` (item 23 when written, 35 after the merge onto origin), `docs/tech-debt-register.md` (TD-016, TD-019), the decision log, this document, its frames, `measurements/` (the 10-22 morning sitting's tooling and outputs; `close-out-2026-10-22/` for the close-out's) and `scenario-outputs/`.
