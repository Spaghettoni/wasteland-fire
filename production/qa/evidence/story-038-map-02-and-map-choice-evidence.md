# Story 038 evidence: Map 02, the map choice, the Bushes, wrecks and small buildings

> **Story**: `production/epics/wasteland-fire/story-038-map-02-and-map-choice.md`
> **Type**: Integration (headless scenarios + windowed frames)
> **Written**: 2026-10-21, by `/dev-story` in a cloud session (Linux, Godot 4.7.2 official build)
> **Sign-off**: [ ] Martin, after playing `WastelandFire-2026-10-21-map-02-gate-west.exe` (stories 038 and 039)

## What was built

- **The map choice** (`src/ui/map_choice/map_choice.tscn`, `map_choice.gd`), now `run/main_scene`: one card per `MapEntry` (`src/gameplay/maps/map_entry.gd`; `map_01_entry.tres`, `map_02_entry.tres`) with its picture from above (`assets/art/ui/map_0N_preview.png`, rendered by `tools/maps/render_preview.gd`). Three new actions, `menu_left`, `menu_right`, `menu_confirm`, with keyboard keys and pad events on every device. The match starts on the confirm key's release; `SplitScreen.use_map()` swaps the Map in before the launch scene enters the tree.
- **Map 02** (`src/gameplay/maps/map_02/`), written by `tools/maps/build_map_02.py` from the schematic's numbers: the canyon (drawn rock plus a ring of `map_edge` boxes on the map layer), the two ridges (cliffs layer), the two waters (Map 01's ford, resized), both Bases (Map 01's compound turned Gate-east), 48 field wall panels and 6 in the ridge's gap (no Player), four field Turrets as Outposts, one Fuel building (`map_02_fuel_building.tscn`), two ammunition buildings, 4 small buildings, 7 wrecks, 9 Bushes, tyre tracks.
- **Outposts**: `MapField.player_1_outposts` / `player_2_outposts`; `SplitScreen._pieces_of()` gives them their Player, arms their Turrets and restores them; FlagRules still reads only `Base.structures`.
- **Bushes**: `src/gameplay/cover/bush.gd` / `bush.tscn`, a trigger on the units layer and a sight body on the new layer 8 "sight"; `UnitStats.crushes_bushes` (Buggy, Truck); `TurretStats.sight_extra_mask` 32 → 160; `MapField.bushes`, stood again at every restart.
- **Wrecks and small buildings**: `src/gameplay/cover/wreck.tscn`, `shack_long.tscn`, `shack_square.tscn` (Structures on the cover layer, written by `tools/maps/build_cover_pieces.py`) with `data/wreck_stats.tres` (60) and `data/shack_stats.tres` (100).

## Acceptance criteria, as measured

| AC | Result | Where |
|---|---|---|
| AC-1 map choice | PASS: the project opens on it, two cards with pictures; D/Right/A/Left and the pad's D-pad and stick move the cursor with wrapping; Space down leaves the screen up and its release starts Map 02; a second later both Players are still choosing (nothing carried over); Enter on the first card starts Map 01 | `map_choice` K1–K4, K6; frames choice-01 to 03 |
| AC-2 a scene of its own, older scenarios on Map 01 | PASS: Map 02 is written by the build script; every older scenario declares no MAP_SCENE and plays Map 01 | `map_02` M1; Regression |
| AC-3 layout | PASS: Bases at (72, 42) and (72, 248), all 81 listed nodes mirrored; a Buggy and a Gyrocopter stay inside the canyon in four directions and the Gyrocopter is never destroyed there; the ridge stops a Buggy (x 100.6) and lets the Gyrocopter over (x 138.5); the water halves a Buggy's speed (19.60 → 9.80 m/s); the ridge wall stops a Buggy at x 102.75 and with its 6 panels down it reaches x 125.8 | `map_02` M1–M5; frame map-02-05 |
| AC-4 Bases, win | PASS: Gate west (Martin, after the first build), so the Garage east of the Flag (x 3 against −11) in both; a Motorbike takes the other Flag and wins by bringing it home | `map_02` M1, M8; frame map-02-01 |
| AC-5 Outposts | PASS: Player 1's two field Turrets fire 6 Shots for 72 damage at Player 2's Buggy and none at Player 1's; Player 1's Shots leave one at 100, Player 2's take it to 64; with Player 2's Base Turrets down and its Outposts standing, Player 1 takes the Flag; the restart makes all 115 pieces whole | `map_02` M6, M8; frame map-02-02 |
| AC-6 Bushes | PASS: no Shot at a Motorbike 3.5 m behind a Bush 22.9 m from a Turret, 2 with the Bush flat; a Buggy's Shots pass a standing Bush and hit the Truck behind it (220 → 184); the Motorbike passes and the Bush stands; the Buggy and the Truck flatten it (sight layer 0); the Gyrocopter passes over and it stands; the restart stands all 9 | `bushes` B1–B6; frames map-02-02, 03 |
| AC-7 wrecks, small buildings | PASS: a Buggy stops at a wreck, a Gyrocopter flies over; a wreck takes a Buggy's Shots (60 → 24) and the Truck behind it none; a Motorbike's Shots take a building from 100 to 75; looks below 80% and 35%, rubble off every layer at 0 and a Buggy drives through; the restart stands both | `cover_pieces` C1–C6; frame map-02-04 |
| AC-8 data | PASS: layout in the build script's tables, numbers in the stats resources, `crushes_bushes` per type, the sight mask in `turret_stats.tres` | `bushes` B6, `cover_pieces` C6 |
| AC-10 back to the map choice | PASS: with the Round over the line "Esc or B: choose another map" shows in both views; Esc makes the map choice the current scene, frees the match and unpauses the tree | `map_choice` K5; frame choice-04 |
| AC-9 supplies | PASS: Fuel 20 → 94 in the Fuel zone in 3 s, ammo refilled in the ammunition zone, both MineLayers refuse a Mine at all three zones | `map_02` M7 |

Every scenario ran twice, byte-identical (outputs in `story-038-map-02-and-map-choice/scenario-outputs/`).

## Measured and changed while building

- **The field Turrets stand 2.5 m in front of the wall's line.** On the line, the first run of `bushes` B1 showed the west Turret seeing nothing 23 m away even with the Bush flat: its muzzle, 1.6 m out toward a target on its own side, was inside its wall's end panel. Moved toward the other half, they see and fire.
- **The match starts on the confirm key's release.** Space and Period are also the Players' fire and confirm keys; a press would reach the match's first tick as "just pressed" and confirm Player 1's Motorbike.

## Regression (AC-2)

All 97 older scenarios were captured on this tree, headless, two at a time, and compared with the capture of story 037's tree (main at 210434b, the same commit the story starts from), normalising the Jolt job warning and the runner's own line numbers. The same 3 window-only scenarios fail headless on both trees, as before. 87 are byte-identical; the other 10 differ only in:

- **the frame-rate scenarios' timings** (`fps`, `map_fps`, `ammo_buildings_fps`, `badly_damaged_fps`, `explosions_fps`, `fuel_building_fps`, `turret_looks_fps`: measured time, different on every run);
- **the lint counts that read files this story extended**: `ammo_buildings` counts the numbers in the Map's code lines (60 → 63, `map_field.gd`'s new checks) and a warning's line number in `map_field.gd` (106 → 141); `fuel_building` counts the scripts under `src/` (67 → 70: `bush.gd`, `map_entry.gd`, `map_choice.gd`); both still pass.
- **`tyre_tracks` ground_surfaces** failed at first: its lint allowed the ground materials in Map 01's terrain only, and Map 02's floor uses the sand. The lint now also allows Map 02's one `Ground` node (`OTHER_GROUNDS` in `tyre_tracks_data.gd`) and checks nothing else there uses a ground material; rerun, its output is byte-identical to story 037's.

The runner keeps every older scenario on its old data: `sight_extra_mask` 32 and no name for layer 8 unless `BUSHES`, no menu actions unless `MAP_CHOICE`, Map 01 unless `MAP_SCENE`.

## Seeded defects (each one mutation, run, restored)

| Mutation | Caught by |
|---|---|
| Any Unit flattens a Bush (the type check removed) | `bushes` B3 |
| Outposts left out of the Player's pieces (not armed, not restored) | `map_02` M6, M8 |
| The Bush's layer left out of the Turret's sight (32) | `bushes` B1, B6 |
| The match starts on the confirm key's press | `map_choice` K3, K4 |

## Frames

Captured windowed at 1280 x 720 under a virtual display with the OpenGL compatibility renderer on Mesa llvmpipe (no GPU), so the light differs from Forward+ on a real machine. Each was opened and read.

- `choice-01-map-choice-map-01.png`, `choice-02-map-choice-map-02.png` — the map choice, the cursor on each card.
- `choice-03-match-on-map-02.png` — the match a second after the start on Map 02, both choice panels up.
- `map-02-from-above.png` — the whole Map (the card's picture, turned a quarter: Orange left).
- `choice-04-round-over-back-line.png` — the Round-over screen with the line back to the map choice.
- `map-02-01-start-gates-west.png` … `map-02-05-gyrocopter-over-the-ridge-buggy-in-the-water.png` — the start, a Bush ahead with the Outposts firing at Player 2, the Bush flattened, a damaged wreck and building (staged), the Gyrocopter over the ridge and a Buggy in the water.

## Human checks (for `/story-done`, on Martin's PC)

1. The game opens on the map choice: do the pictures read, and do the keys and the pads choose and start?
2. Map 02: does it match your sketch (Garage left of the Flag, the gap with two Turrets, the passage, the water, the wall in the ridge)?
3. Do the Bushes feel right: hiding from the Turrets, flattened by a Buggy or a Truck, not by the Motorbike?
4. Are there enough wrecks, buildings and Bushes, and are their hit points (60 and 100) right?
5. The field Turrets stand 2.5 m in front of the wall: fine, or should they sit on its line?

## Questions for Martin (answered 2026-10-21)

1. **The Bases.** Map 02 uses Map 01's compound Base, turned so the Gate faces east and the Garage is west of the Flag. Your sketch draws a smaller square with a Turret in each corner; the compound has four corner towers and two Turrets at the Gate. Keep it, or build a Map 02 Base of its own? **Answer: keep it, with the Gate to the west** (built).
2. **Back to the map choice.** Today R replays the same Map; a different Map needs the game started again. A key for "back to the map choice" on the Round-over screen is a small next step. **Answer: yes** (built: Esc or B, AC-10).

## Story 039: no Turret locks a Flag, the Motorbike breaks walls

`production/epics/wasteland-fire/story-039-open-flag-and-motorbike-walls.md`, from Martin's request of 2026-10-21. Two data lines: `turret_stats.tres` `locks_flag` false; the pair `motorbike>flag_wall` gone from `damage_matrix.tres`.

| AC | Result | Where |
|---|---|---|
| AC-1 the Flag is open | PASS: with both of Player 2's Turrets standing, Player 1's Motorbike takes the Flag at once, the lock is never reported, and it wins at home | `flag_open` F1 |
| AC-2 the Motorbike breaks walls | PASS: 60 ticks of a Motorbike's fire take 25 hit points off Player 2's Wall Panel and off its Flag Wall, none off Player 1's own panel | `flag_open` F2 |
| AC-3 and Turrets | PASS: 25 off Player 2's Turret | `flag_open` F3 |
| AC-4 the older outputs | PASS: the runner puts the lock and the pair back unless a scenario declares `FLAG_OPEN`; see the regression below | Regression |

Seeded: `locks_flag` true → F1, F4 fail; the pair back at 0.0 → F2, F4 fail. `flag_open`, `map_02` and `map_choice` ran twice, byte-identical.

## Regression after the Gate turn, the way back and story 039

All 97 older scenarios and `bushes` and `cover_pieces` were captured again and compared with the capture above. `bushes` and `cover_pieces` give the same CHECK and RESULT lines. The older ones differ only in the frame-rate timings, in two lint counts (`fuel_building` 70 → 72 scripts under `src/`, `tokens_data` 16 → 18 files, 5 literals as before; both pass, the new files being `map_choice_return.gd` and `map_choice_hint.gd`) and in `loss`, which failed once on the Jolt job warning its engine-log check counts (the warning the story 032 evidence describes, random under load on this 2-core machine) and passed rerun alone, byte-identical to before. The runner takes the way back to the map choice (its node, its two lines and the `round_back` action) out of every scenario that does not declare `MAP_CHOICE`.
