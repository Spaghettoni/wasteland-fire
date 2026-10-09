# Story 012 — Flag Walls: test evidence

**Story:** `production/epics/wasteland-fire/story-012-flag-walls.md` · **Type:** Integration (touches screens) · **Layer:** Core · **Estimate:** L
**Engine:** Godot 4.7.2.stable.official.ed1daf0bf, Jolt Physics, Forward+ (Metal 4.0), 60 physics ticks/s
**Machine:** macOS (Darwin 25.5.0) arm64, Apple M4 Pro, 120 Hz built-in display · **Date:** 2026-10-08 · **Run by:** the implementing session directly for AC-1 to AC-8 (no workflow, as the usage-quota note asks), with one read-only engine-specialist review of the src diff (engine risk HIGH). AC-9, the damaged looks the developer asked for at `/story-done` on 2026-10-08 (question 1), was built by the session with two workflows: two technical-artist attempts at the look and an art-director judge (`measurements/look-attempts-and-judge.txt`), then three review lenses (engine, adversarial acceptance with its own seeded defects, docs).
**Gate level:** Integration: an integration test or a documented playtest, and this story touches screens, so retained frames. Tests are waived at `qa.level: minimal`; none was written for `tests/` and nothing under it changed. The evidence is the scenario `flag_walls` (sixteen checks, real keys through the Input Map), the windowed `flag_walls_showcase` (nine moments, all read), the main scene's launch, the look probe (eight frames of every look side by side), the 48 older outputs compared with baselines captured twice before the first edit, `map_fps` windowed, and 57 seeded defects.

## Run result

`Run result: OBSERVED — the main scene (godot --path . --windowed --resolution 1280x720, recorded with --write-movie --quit-after 90) opens Map 01 with both Players choosing and, under each water tower, the closed box of four dark Flag Walls with the Flag on its seat (00); the windowed recording of flag_walls_showcase on the shipped data shows both Units on their Garages' first spots (01), a Motorbike's tracer 2.1 m from a standing Flag Wall, which it ends on and takes nothing from (02), the Truck's first Shot leaving Base B's Gate-side Flag Wall in its first damaged look, pale cracks on a darker panel with chips at its foot (02a), its second Shot leaving rubble in the gap with the other three standing (03), Player 1's Motorbike in the box with "You carry the enemy Flag" and Player 2's "Your Flag is away" (04), "Player 1 wins!" after the delivery (05), both boxes whole again after R with both Players choosing (06), a Gyrocopter's two Shots leaving the same Flag Wall in its second damaged look, denser cracks and a bigger pile of chips (06a), and the Gyrocopter's model over that Flag Wall (07); the look probe shows every look side by side, from above and in the chase view (look-probe/); no ERROR or WARNING in any of these runs (production/qa/evidence/story-012-flag-walls/).`

The feel half (how the damaged looks and the rubble read at play speed) is for the human checks below; a still cannot show it.

## The runs

- **Launch** (`commands.run` plus `--write-movie --quit-after 90`, recorded again on the final build): rc 0, no ERROR or WARNING (`measurements/windowed-launch-recording.txt`); frame 89 is 00.
- **`flag_walls`** (headless, `--fixed-fps 60`, shipped rules and data with `BASE_DEFENCES`, `OWN_BASE_SWAP`, `SHIPPED_CAMERA` and `OWN_CHOICE`, a Token stock of 30 of each type, every key a real event through the Input Map; two runs byte-identical, `scenario-outputs/split-flag_walls.txt`): 16 checks, all PASS, `t=165.850` simulated seconds (about 5 s on this machine), and the four engine ERRORs the scenario causes on purpose (a Flag Wall with no stats, one whose list of damaged looks was cut short, one whose list has an empty slot, and stats with the fractions out of order) and none else.
- **`flag_walls_showcase`** (headless twice byte-identical, `scenario-outputs/split-flag_walls_showcase.txt`; windowed with `--write-movie`, 912 frames, rc 0, `measurements/flag_walls_showcase-windowed-run.txt`): nine moments, each with its premise read; no premise failed, `errors=0 warnings=0`.
- **The look probe** (`measurements/flag_walls_look_probe.gd.txt`, a scratch scenario registered only in a scratch copy of the repo whose look files are the repo's; rendered with `measurements/look-probe-render.sh.txt`; `measurements/look-probe-run.txt`): eight moments, rc 0, `RESULT ok`, no ERROR or WARNING.
- **`map_fps`** (windowed, 120 Hz, measured before AC-9): on the Map stripped of the new pieces, as every older scenario runs, `fps_min_steady=119 fps_avg_steady=120 draw_calls_max=222` (`measurements/windowed-map_fps-stripped.txt`); the same run in a scratch copy whose `map_fps` declared `BASE_DEFENCES`, so with all eight Flag Walls, `fps_min_steady=119 fps_avg_steady=120 draw_calls_max=223` (`measurements/windowed-map_fps-with-flag-walls.txt`). AC-9 shows nothing more while a Flag Wall is whole (its damaged looks are hidden); a damaged one draws its panel and four or eight chips in place of the panel. Not measured again: the frame rate with the new pieces is story 013's `turrets_fps`.
- **The 48 older outputs** (the drive harness's four and the split-screen runner's 44; `fps`, `map_fps` and `camera_smooth` are windowed tools) compared with baselines captured twice before the first edit (byte-identical to each other): see the regression section.

## Retained screenshots (`production/qa/evidence/story-012-flag-walls/`)

All 1280 × 720 frames from `--write-movie` recordings on 2026-10-08 (Metal 4.0, Forward+), recorded again on the final build after AC-9 and each opened and read. Player 1 (orange HUD) is on the left, Player 2 (teal) on the right, both in the view from above.

| File | What it shows | Read |
|---|---|---|
| `00-launch-both-boxes-closed-both-players-choosing.png` | The main scene at launch | Both choice panels open with x5 x3 x2 x2; under each water tower a closed dark box between the four legs with the Flag on its seat |
| `01-both-units-in-their-garages.png` | Player 1's Truck and Player 2's Motorbike on their first spots | Each Unit on the side spot of its Garage floor (Base A's left, Base B's right), both boxes closed, no panel |
| `02-motorbike-shot-tracer-at-a-standing-flag-wall.png` | Player 2's Motorbike fires at Base A's Gate-side Flag Wall from outside the Gate | The yellow tracer just short of the box; the Flag Wall stands whole; the moment's line and the hold after it read 40 of 40 hit points and the whole look |
| `02a-truck-first-shot-first-damaged-look.png` | Player 1's Truck after its first Shot at Base B's Gate-side Flag Wall | The Flag Wall darker with pale cracks on its top and face and two dark chips on the sand at its foot; the moment's line reads 15 of 40 hit points, look 1 |
| `03-truck-has-broken-a-flag-wall-rubble-in-the-gap.png` | The Truck's second Shot | Low rubble in the gap between the two legs on the Gate side, the teal Flag on its seat behind it, the three other Flag Walls standing; the moment's line reads the rubble shown |
| `04-motorbike-takes-the-flag-through-the-gap.png` | Player 1's Motorbike inside Base B's box | Player 1's HUD "You carry the enemy Flag", Player 2's "Your Flag is away" |
| `05-flag-delivered-player-1-wins.png` | The delivery at Base A | "Player 1 wins!" and "Press R to play again" in both views |
| `06-both-boxes-back-after-r-both-players-choosing.png` | R pressed | Both boxes whole again, both choice panels open; the moment's line reads 8 of 8 whole in the whole look |
| `06a-gyrocopter-two-shots-second-damaged-look.png` | Player 1's Gyrocopter after two Shots at Base B's Gate-side Flag Wall | The Flag Wall darker still, a denser network of pale cracks and a bigger pile of dark chips at its foot; the moment's line reads 10 of 40 hit points, look 2 |
| `07-gyrocopter-over-a-flag-wall.png` | Player 1's Gyrocopter at full speed over that Flag Wall | The model over the cracked wall with its shadow on the ground, the Flag in the box beyond (the moment's line: model bottom 2.25 m, wall top 2.00 m, look 2) |

The look probe (`look-probe/`, from `measurements/flag_walls_look_probe.gd.txt`; each frame opened and read): Player 1 faces Base B's box, Player 2 Base A's, every wall set by `apply_damage()` or `destroy()`.

| File | What it shows |
|---|---|
| `above_all_looks_from_gate.png`, `above_all_looks_from_side.png` | From above, from the Gate side and from the Left side: each box shows the whole look, both damaged looks and the rubble at once (Base B: Gate whole, Garage fallen, Left first look, Right second; Base A: Gate second, Garage first, Left fallen, Right whole). The damaged walls stand out by their pale cracks and the dark chips at their foot; the second has denser cracks and more chips |
| `above_near_first_look.png`, `above_near_second_look.png` | From above, the near Gate-side wall in each damaged look, the others whole |
| `chase_near_whole.png`, `chase_near_first_look.png`, `chase_near_second_look.png`, `chase_near_fallen.png` | The chase view of the near wall: whole as before, pale cracks on a darker face, denser cracks on a darker face with more chips, then the rubble with the Flag behind it |
| `runner-up-a/above_all_looks_from_gate.png`, `runner-up-a/chase_near_second_look.png` | The judge's runner-up (attempt A, soot-dark: darker panels, black fissures and dark chips), for the author's look check |

## Acceptance criteria — what was measured

- **AC-1 (four Flag Walls, a closed box; the Flag shows from above).** `walls_data`: four per Base under `Defences`, listed in `structures`, layer 64, mask 0, `flag_wall_stats.tres` (`flag_wall`, 40 hit points), drawn 2.0 m tall in the Base walls' material; the box spans world x -115.3 to -110.7 (Base A) and 110.7 to 115.3 (Base B), z -2.3 to 2.3, within 0.01 m; `map_kit.mirror()` pairs every collider, spot and seat within 0.1 m (worst 0.0000 m); each Unit's and each Flag Wall's `player_index` is the one SplitScreen set. `closed`: the other Player's Motorbike driven at full throttle at each of the four sides of both boxes stopped 3.60 m from the seat (the face and its half-length), `touching()` false on every tick, no pick-up, the owner's HUD "at home" throughout. `flag_visible`: in the view from above the Flag's top shows over every standing Flag Wall from every side of both boxes through 20 m (farthest shown at the worst side: top 25 m, middle 15 m; the story computed about 28 and 19 on the Flag's axis), and in the chase view the near Flag Wall hides the top in 48 of 48 views, so the check can fail.
- **AC-2 (what stops at a Flag Wall, what flies over).** `stops`: the Motorbike met the Gate-side Flag Wall at 23.3 m/s, the Buggy at 19.6, the Truck at 10.9, each stopped within one tick flush at the face (1.300, 1.500 and 2.202 m: the half-lengths), and a Shot fired pressed against it ended at the muzzle inside the wall; `damage`: a Shot of each of the four types ended on the face within 0.01 m. `gyro_over`: both Gyrocopters crossed the box on the Gate axis at 16.4 m/s on every tick their model was over a Flag Wall (27 ticks each), the model's lowest point at least the rise clearance (0.250 m) over the 2.0 m top, no wall contact, and out over the Garage side; one braking from 4 m/s inside the box stopped 0.28 m from the seat; one flown at the Gate-side leg was stopped by it (local z -10.50, the leg's face at -9.30). `walls_data`: every type's spot test (mask 18), both Base zones (mask 18) and both Flags' touch (mask 2) leave out layer 64.
- **AC-3 (40 hit points, the matrix, no damage to the own).** `damage`: one Shot of each type, from each Player, at the other Player's Gate-side Flag Wall took 12 (Buggy), 25 (Truck), 15 (Gyrocopter) and 0 (Motorbike, with no `hit_points_changed`), each the data's damage times the matrix's multiplier; each Player's own Shots of every type took nothing from its own; the Flag Wall fell on the 4th Buggy Shot, the 2nd Truck Shot and the 3rd Gyrocopter Shot, and 12 Motorbike Shots left it whole; a stand-in body with `apply_damage()` and no `type_id` stopped a Shot and was never asked to take damage; a Flag Wall instanced with no stats logged one error as it entered the tree and nothing for the Shot that ended on it. Damage between Units: `weapons` (the 16 pairs against its own table) is byte-identical to its baseline.
- **AC-4 (a fallen Flag Wall blocks nothing; one down opens the box).** `layer_timing` (the story's Measure first): see the measured facts below. `raids`: for each Player, a Truck broke the other Player's Gate-side Flag Wall with that Player's own fire key in two Shots (rubble shown, `Mesh` hidden, layer 0, a mask-83 ray through the gap reaching the seat, the other three standing); the Motorbike drove in, was handed the Flag ("You carry the enemy Flag"), backed out and delivered it ("Player 1 wins!", then "Player 2 wins!"). `breach`: each single Flag Wall down in turn, the four sides at both Bases, let the other Player's Motorbike drive in, be handed the Flag, reverse out and deliver it (8 cases).
- **AC-5 (stays down until R; R brings all eight back).** `reset`: a fallen Flag Wall stayed down (the rubble) and a hurt one stayed at 30 of 40 in its first damaged look through a destruction outside the own Base, a respawn and a Swap (and `owner_return`'s breach stayed open through two Flag drops); after Player 2's win, R brought back all eight whole (40 hit points, layer 64, mask 0, the whole look alone: the damaged looks and the rubble hidden), and when the Round started both Units were benched and both Flags seated (read in a `round_started` handler connected after SplitScreen's restore); the restored box stopped the Motorbike again.
- **AC-6 (the side spots).** `walls_data`: first spots at world (-125, 0, -4) and (125, 0, -4), spares mirrored, `first_spawn_problem()` empty for both. `spawn_and_exits`: every type from the first spot and the spare of both Bases drove straight out to Base-local z -30 on the throttle alone, 16 runs two at a time, no wall contact (Motorbike 2.05 s, Buggy 2.37, Truck 3.82, Gyrocopter 2.68, the same from every spot), and the Truck passed 0.300 m from a Gate post and 0.500 m from the box. `spots`: each Player's new Unit stood on the first spot after a respawn (its Unit destroyed outside its Base) and after a Swap, and on the spare while the other Player's Unit stood on the first; the Round start's spot is read in `walls_data` and R's in the flows' restarts.
- **AC-7 (delivery and the owner's return as before).** `raids` and `breach` delivered ten times with the Carrier's own box standing. `owner_return`: Player 1's Flag, dropped inside Base A's breached box when Player 2's Carrier Self-destructed there (Enter), was picked up by Player 1's Motorbike through the breach and seated on the same tick (tick 9113, `picked 0 by 0` then `seated 0`); dropped against the outside of the standing Gate-side Flag Wall (1.35 m out), it was not touched by Player 1's Unit at the seat inside the box in 30 ticks and was taken and seated from outside.
- **AC-8 (data, and the older outputs).** The hit points, the type id and AC-9's fractions are in `flag_wall_stats.tres`, the Motorbike's x0.0 is one row of `damage_matrix.tres` (`walls_data` reads it and the 1.0 default), the size, layer and every look are in `flag_wall.tscn` and its materials, the places in `compound_base.tscn` and the spots in `compound_base.tscn` and `map_01.tscn`; no number and no type is written in code and no new text is shown. The older outputs: the regression section.
- **AC-9 (the damaged looks).** `looks` (`flag_walls_looks.gd`): all eight Flag Walls read `damaged_below` [0.8, 0.35] from `flag_wall_stats.tres`; each has `MeshDamaged1` and `MeshDamaged2`, direct MeshInstance3D children listed in that order that draw `Mesh`'s box in `Mesh`'s place, with `albedo_color` 0.34 and 0.22 against `wall.tres`'s 0.55, 4 and 8 chunks, no collider, every chunk unshadowed, under 0.4 m and outside the panel, all hidden while the wall is whole. After every Shot of `damage`'s runs to the fall the one look shown, read from the nodes by name, is the one the data predict from the hit points: Buggy [1, 1, 2, -1], Truck [1, -1], Gyrocopter [1, 2, -1] and the Motorbike's twelve [0] (0 whole, 1 and 2 the damaged looks, -1 the rubble); in `damage`, one Shot of every type but the Motorbike leaves the other Player's Gate-side Flag Wall in its first damaged look, and the Motorbike's Shot and a Player's Shots at its own leave the whole look. The edges, by `apply_damage()` on Base B's Gate-side Flag Wall: exactly 80% (32 of 40) the whole look, just below it the first, exactly 35% (14 of 40) the first, just below it the second, `restore()` whole: [0, 1, 1, 2, 0]. Every `hit_points_changed` of the run so far (275) was emitted with the look its hit points call for, so the look changes before the signal. Each damaged look is drawn as `Mesh` is (render layers, transparency, shadow, visibility range), over `wall.tres`'s own texture with a crack layer of its own (the second look's mask is not the first's), and every chunk rests on the ground (bottom above -0.05 m) with its centre within 0.6 m of the panel's face and its whole box outside the panel; in the scene the damaged looks and the rubble are hidden. A Flag Wall whose stats hold other fractions, [0.6, 0.2], followed them ([0, 1, 2] after 10, 6.5 and 16 hit points). A Flag Wall whose list lost its second look and one whose list has an empty slot each logged one error, showed only the whole look at 0.5 of 40 hit points and then the rubble; stats with the fractions out of order were refused with one error and the piece showed its whole look; `first_problem()` refused fractions in percent ([80, 35]), at 1, at 0 or NaN, and a NaN maximum. `reset` and the showcase: above.

## Measured facts the code comments point at

- **A Structure's layer change acts in the same tick** (the story's Measure first; `layer_timing`): a ray on mask 83 through Base B's Gate-side Flag Wall is clear right after `destroy()` in the scenario's tick and still clear a tick later; right after `restore()` it is blocked at once. A Motorbike pressed against the Flag Wall with the throttle held moved 0.039 m in the first tick after it fell (and 0.044 m in the next), and one approaching at speed when it was restored was stopped flush at the face that tick. So "from the next tick at the latest" (AC-4) holds on the same tick, and the story's fallback (a second Shot of the same tick ending on the rubble) does not arise. `structure.gd`'s class doc points here.
- **A Unit put down where another stood in the same tick is perched on it**, and is carried along when the other is moved (it rides it like a platform). The Story 012 kit parks the other Player's Unit and lets the physics space settle before it puts a Unit down (`flag_walls_kit.gd` `park()`).
- **The Weapon is one node per Player**: after a retype the next shot waits for the interval of the type that fired last. The kit waits the longest cadence of the data after every placement.
- **The pressed Shots of `stops` (Buggy 12 and Truck 25) leave a Gate-side Flag Wall at 3 of 40 hit points**; a seeded defect showed a later check relied on it. Every check that damages a Flag Wall now restores all eight first.
- **The damaged look follows the hit in the hit's own tick** (AC-9; `looks`): the look is read right after each Shot has ended (the kit's `shoot()` returns once the Shot has left the tree), and `Structure.apply_damage()` updates it before it emits `hit_points_changed`.
- **The Gyrocopter rises over a damaged Flag Wall exactly as over a whole one** (`gyro_over` in the showcase: model bottom 2.25 m over the 2.00 m top with the wall in its second damaged look): the rise (`kit_unit_model.gd` `_drawn_top()`) reads every direct GeometryInstance3D child of a body, shown or hidden, and the damaged looks share the panel's mesh.
- **The fractions are 64-bit** (`Array[float]`): as 32-bit floats, 0.8 x 40 is 32.0000005, which would put a wall at exactly 32 hit points into its first damaged look; the edge test of `looks` (exactly 80% and 35%) would catch it.

## Stories 001 to 011 regression

Baselines of all 48 retained outputs (the drive harness's four and the split-screen runner's 44) were captured at the working tree of the start of the story, twice, before the first edit; the two captures were byte-identical. On the final code, AC-9 included (run again after the damaged looks landed): 45 byte-identical, and `token_ui`, `tokens_data` and `unit_swap` identical after the two exact rewrites the story planned before the first edit (`measurements/normalizers.json`, made from the source lines, not from the outputs): `advance_ticks (res://tools/evidence/split_screen_harness.gd:779)` becomes `:852` (the runner's new constants, strip and registrations; 2, 18 and 1 occurrences), and `destroy (res://src/gameplay/units/unit.gd:497)` becomes `:503` (`Unit.player_index` and its doc; 1 occurrence, in `tokens_data`). Every other cited line stayed (`match_controller.gd`, `token_ledger.gd`, `player_match_input.gd`, `token_kit.gd`, `check_kit.gd` and `unit_swap_flows.gd` are unchanged). Each older scenario runs with the Flag Walls stripped and the Story 007 spots (the runner's `_apply_defences_off()`); the greybox scenarios run the new Shot and the indices too, so `weapons`' unchanged output is the proof that damage between Units did not change. `measurements/regress-48-baselines.txt` lists every pair.

## Seeded defects

`measurements/seeded-defects.py.txt` (one exact replacement each in a scratch copy of the repo, one worker per copy, every copy diffed clean against the repo at the end; a run with no RESULT line would count as broken, not killed), output in `measurements/seeded-defects.txt`. The 29 of AC-1 to AC-8 run again on the final code, four of them keyed to Structure's new `_show_look()`, and 28 join for AC-9: 15 written with the build and 13 after the review, from the survivors of its adversarial acceptance lens and its engine lens (every one of those survived the evidence as it then stood; the checks were strengthened until each is killed):

| Seeded defect | Result | Caught by (failing checks) |
|---|---|---|
| matrix row deleted | killed | walls_data, damage, looks |
| apply damage does nothing | killed | damage, looks, raids, reset |
| zero amount accepted | killed | damage |
| fallen keeps its layer | killed | layer_timing, raids, breach, owner_return, reset |
| rubble never shown | killed | looks, raids, reset |
| drawn box stays after the fall | killed | damage, looks, raids, reset |
| restore keeps the hit points | killed | damage, looks, raids, reset |
| restore keeps it fallen | killed | layer_timing, spawn_and_exits, stops, gyro_over, damage, looks, flags_untouched, spots, closed, raids, reset |
| type id getter unguarded | killed | damage, looks, no_engine_noise |
| flag wall on layer 1 | killed | walls_data, gyro_over, reset |
| flag wall on layer 0 | killed | walls_data, layer_timing, spawn_and_exits, stops, gyro_over, damage, looks, flags_untouched, spots, closed, raids, reset |
| flag wall drawn taller than its collider | killed | walls_data, flag_visible |
| flag wall 120 hit points | killed | walls_data, damage, looks, raids, reset |
| base zone watches the flag walls layer | killed | walls_data |
| flag touch watches the flag walls layer | killed | walls_data |
| shot owner test removed | killed | damage |
| shot owner test inverted | killed | damage, looks, raids |
| shot type id test removed | killed | damage, no_engine_noise |
| launch passes no player | killed | damage |
| units get no player index | killed | walls_data, damage |
| structures get no player index | killed | walls_data, damage |
| restore not connected | killed | owner_return, reset |
| restore only player 1s base | killed | reset |
| compound spawn point back on the middle spot | killed | walls_data, spawn_and_exits |
| base b override removed | killed | walls_data, spots |
| one flag wall not listed | killed | walls_data, reset |
| one flag wall missing | killed | walls_data, gyro_over, flag_visible, damage, looks, closed, no_engine_noise |
| damaged looks never shown | killed | damage, looks, reset |
| damaged look stage off by one | killed | damage, looks, reset |
| intact kept beside a damaged look | killed | damage, looks, reset |
| below made inclusive | killed | looks |
| look not updated on a hit | killed | damage, looks, reset |
| fall keeps the damaged look | killed | looks, raids, reset |
| restore keeps the damaged look | killed | damage, looks, reset |
| looks list check removed | killed | looks, no_engine_noise |
| stats accept fractions out of order | killed | looks, no_engine_noise |
| fractions changed in the data | killed | damage, looks, reset |
| looks swapped in the scene | killed | damage, looks, reset |
| a chunk given a body | killed | walls_data, looks |
| damaged look drawn taller | killed | looks |
| a chunk casts a shadow | killed | looks |
| a chunk inside the panel | killed | looks |
| unassigned damaged look accepted | killed | looks, no_engine_noise |
| fractions typed into the code | killed | looks |
| stats accept fractions of one and more | killed | looks |
| nan fraction accepted | killed | looks |
| nan maximum accepted | killed | looks |
| refused piece shows a look | killed | damage, looks |
| signal before the look | killed | looks |
| first damaged look without cracks | killed | looks |
| first damaged look lighter than whole | killed | looks |
| first damaged look on no render layer | killed | looks |
| damaged look shown in the scene | killed | damage, looks |
| a chunk buried | killed | looks |
| a chunk three metres from the wall | killed | looks |
| runner leaves the flag walls in | killed | map_bases (output differs from the baseline) |
| runner leaves the side spots in | killed | map_bases (output differs from the baseline) |

57 seeded, 57 killed, none survived; the three scratch copies were equal to the repo at the end.

## Verification of the build itself

- **Parse:** `godot --headless --path . --import` exit 0 (it registers `Structure` and `StructureStats` in the class cache and writes the new scripts' `.uid` files); the parse check over every `.gd` under `src/` and `tools/evidence/`: `ok` for all 122, exit 0 (`measurements/parse-check.txt`). Engine risk is HIGH on this pin: the APIs used are `StaticBody3D` collision layers, `Object.get()`, `Object.call()`, `PhysicsRayQueryParameters3D`, typed node-path exports (an `Array[Node3D]` of them for the damaged looks) and `StandardMaterial3D`'s detail layer with world triplanar mapping over procedural `NoiseTexture2D`s; the review of the AC-1 to AC-8 src diff found no defects; it pointed at two doc comments, both fixed: a blank line that cut the Fuel Cans paragraph out of SplitScreen's class doc, and a sentence in Structure's doc that said a restored piece throws a Unit out (now marked as not measured, since the shipped game never restores a piece over a Unit).
- **AC-9 review** (workflow, three read-mostly lenses on the final build): the engine lens (godot-gdscript-specialist) found no defect in the AC-9 code; it ran the real scene in a scratch copy (exactly one look in every state, the exact edges, the four intended errors, the typed `Array[Node3D]` resolved at instantiate), checked every property of the scene and the seven resources against 4.7.2 (98 keys, none missing, the enums decoding as intended) and the Gyrocopter's rise (top 2.00 m for the whole and both damaged looks). It and the adversarial acceptance lens (qa-tester, nine mutants of its own in a scratch copy, all of which then survived) found gaps in what the evidence pinned, not in the build: the empty slot, the fractions typed into code, out-of-range and NaN fractions, the crack layer, the texture under "darker", render layers, buried or distant chunks, a damaged look shown in the scene, the look of a refused piece, and the order of the look and the signal. All were closed by the checks above and pinned by the 13 review mutants. One latent defect from before AC-9 was fixed in `StructureStats.first_problem()`: a NaN `max_hit_points` was accepted (`max_hit_points <= 0.0` is false for NaN); the test is now written as `not (max_hit_points > 0.0)`, as the fraction test already was (`UnitStats.first_problem()` has the same pattern, outside this story). The docs lens (lead-programmer) found ten points in the story, `design/rules.md` and two evidence headers (a stale reading, the hurt wall keeping its look until R, How to test never reaching the second look, the frame list missing the win frame, incomplete bullets and lists), all fixed. Cost, measured by the engine lens on this Mac: the three noise textures are generated once at load in about 93 ms in all (43.9, 44.5 and 4.7 ms; the existing 512 px `scrap.tres` takes 28.3 ms) and shared by all eight walls; nothing runs per frame.
- **Run:** the main scene launched windowed and recorded (00), the showcase windowed (01 to 07 with 02a and 06a), the look probe windowed, `map_fps` windowed twice before AC-9: rc 0 every time, no ERROR or WARNING.
- **Scenario sizes:** `flag_walls.gd` 275 lines, `flag_walls_kit.gd` 241, `flag_walls_looks.gd` 267, `flag_walls_moves.gd` 174, `flag_walls_over.gd` 222, `flag_walls_flows.gd` 164, `flag_walls_returns.gd` 158, `flag_walls_bodies.gd` 69, `flag_walls_showcase.gd` 190, each under the 280-line guideline of TD-006; the runner grew to 1,007 lines (the strip, four constants, two registrations).

## Notes for the author

- **The seven questions were answered by the developer at `/story-done` on 2026-10-08:** keep 2 m and the dark material; any one Flag Wall down opens the box; keep the Motorbike's x0.0; a Player's own Shots stop on their own Flag Walls; a fallen Flag Wall stays down until R; new Units on the north side spots; the Flag hidden from afar by a closed box is acceptable. And add a damaged look: built as AC-9 with the developer's default (two stages, at 80% and 35% of the hit points, darker and more cracked, with chips piling at the foot, the rubble at zero as before).
- **The damaged look:** of two attempts (A soot-dark, B fresh-break), the judge and the session both chose B for how it reads from above at play distance, and five of the judge's tweaks were applied (`measurements/look-attempts-and-judge.txt`): pale grey cracks on a panel darker at each stage, dark chips at the foot, a bigger pile in the second look. A's frames are kept in `look-probe/runner-up-a/` in case the author prefers it.
- The Flag Walls block the middle spawn spot's straight lane, so the Garage's middle marker (`SpawnPoint`) stays in the scene unused; the older scenarios still use it.
- `unit.gd` grew to 767 lines (+6: `player_index` and its doc); TD-010 carries the figure.

## Human checks

Confirmed by the developer at `/story-done` on 2026-10-08, before AC-9 was added: (1) the real keyboard with both Players (each breaks the other's box with the Truck, the Buggy and the Gyrocopter while the Motorbike's Shots do nothing, takes the Flag through the gap and delivers it), (2) a Gyrocopter over a Flag Wall, (3) R brings both boxes back, (4) the look of the Flag Walls and of the rubble: Yes to all four.

Confirmed by the developer at `/story-done` on 2026-10-08, for AC-9: (5) **the damaged looks in play**: a Truck's first Shot, a Buggy's Shots and a Gyrocopter's two Shots visibly hurt the other Player's Flag Wall in two steps before it falls, the Motorbike's change nothing, the looks read as the same dark wall cracked (frames 02a and 06a, `look-probe/`), and R brings back the whole look: Yes.

## Sign-Off

| Check | Result |
|---|---|
| Frames read against the acceptance criteria | [x] Done by the implementing session (00 to 07 with 02a and 06a, and the look probe) |
| Human checks 1 to 4 (keyboard, Gyrocopter, R, look) | [x] Confirmed by the developer at `/story-done`, 2026-10-08 |
| The seven questions for the author | [x] Answered by the developer at `/story-done`, 2026-10-08 (question 1 added AC-9) |
| Human check 5 (the damaged looks in play) | [x] Confirmed by the developer at `/story-done`, 2026-10-08 |
| Lead sign-off (solo developer: Tomas Kunzo) | [x] Approved by the developer at `/story-done`, 2026-10-08 |

*The unchecked rows are filled in from the developer's answers at `/story-done`, not by an agent on its own.*
