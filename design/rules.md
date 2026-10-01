# Wasteland Fire: rules and mechanics

Source: the "Wasteland Fire" artifact (https://claude.ai/artifact/3dVGdvULzywJvn8GDLEXDP), the author's design text in Slovak. The first rules were translated from the version pasted on 2026-09-29. This file follows the author's export of 2026-10-01 (the artifact's version 0.1), archived under `design/source/` as the HTML, the extracted Slovak text (`wasteland-fire-artifact-2026-10-01.sk.txt`) and the English translation (`wasteland-fire-artifact-2026-10-01.en.md`); where the two disagree the Slovak wins and the disagreement is noted here. The artifact's "versions and ideas" board is not in the export (its items live in the artifact's database), so only the prose sections are the source and nothing is guessed from the board. The source gives rules, mechanics, the visual style, technology choices and process rules; input devices and everything the source leaves open are decided in conversation. Items marked "decided 2026-09-29" or "decided 2026-10-01" were settled in conversation on that day; items marked "reading of the source" are this file's interpretation of a sentence the source leaves open, listed for the author. Numbers from the source are starting values to tune by playing, not rules, except where this file says otherwise. When the artifact changes, update this file in the same change.

## Objective

Two Players, each with their own Base: Base A and Base B on Map 01. Each Base holds one Flag. A Player wins the moment they deliver the opponent's Flag to their own Base. A Player loses the moment they lose their last Motorbike (see Destruction and respawn), because only a Motorbike can carry a Flag. Fuel is collected around the Map; without it nothing drives or flies. One match, no rounds: the source plays a single match (zápas) with no best-of series. Our word for that one match is Round (decided 2026-10-01): a Round is the whole game from the first spawn to the win or the loss, and nothing else ends it.

## Tokens and the Garage

- Each Player has a stock of Tokens, one count per Unit type. The source's example: Motorbike 5, Buggy 3, Truck 2, Gyrocopter 2. The counts are set by the Map and each Map may differ; the example is an example, not a rule.
- At the start of the Round and after every destruction the Player picks any Unit type with Tokens left, and the Unit appears in the Garage at their Base. The game keeps running meanwhile: the other Player is never paused while someone chooses.
- A destroyed Unit = minus 1 Token of its type. The Token is taken at the destruction, not at the spawn, so the Unit in play is not yet subtracted from the stock.
- A type with 0 Tokens cannot be picked again in this Round.
- The loss in Token terms (reading of the source, 2026-10-01): the destruction of a Motorbike that leaves the Player's Motorbike stock at 0 ends the Round with that Player's loss. A Player is never stranded without a loss: with Motorbike Tokens left they can always pick a Motorbike, and without any they have already lost.
- A Map gives every Player at least 1 Motorbike Token; with 0 the Player could neither carry a Flag nor lose (reading of the source, 2026-10-01).
- The choice and the respawn delay (decided 2026-10-01): the delay runs from the destruction; the Player may choose during the countdown, and the Unit appears in the Garage once the Player has chosen and the delay has passed, whichever is later. At the Round start there is no delay: the first Unit appears as soon as it is chosen.

## Units

Four Units: the combat trio Buggy, Truck and Gyrocopter, which beat one another as rock, paper, scissors, and the Motorbike apart, purely for Flags. Starting values from the source, to be tuned by playing:

| Unit | HP | DMG | Speed m/s | Turn deg/s | Flies |
|---|---|---|---|---|---|
| Motorbike (motorka) | 40 | 5 | 22 | 220 | no |
| Buggy (bugina) | 100 | 12 | 18 | 180 | no |
| Truck (truck) | 220 | 25 | 10 | 70 | no |
| Gyrocopter (gyrokoptéra) | 70 | 15 | 15 | 120 | yes |

- Buggy beats Truck: it circles the Truck, which cannot turn and aim in time.
- Truck beats Gyrocopter: the Gyrocopter has few HP; the Truck downs it in a few hits.
- Gyrocopter beats Buggy: it escapes over cliffs and water, where the Buggy cannot go, and shoots from safety.
- Weapons: every Unit has one weapon that fires straight ahead, so turning is aiming and the turn rate is the aiming speed; there is no aim independent of the heading. Shooting happens at one height only: the Gyrocopter shoots and is shot like everyone else. This replaces the 2026-09-29 rule that only the Buggy's gun could hit the Gyrocopter.
- Flying means only crossing cliffs and water. The Gyrocopter gains nothing else from the air: no height advantage for fire, no immunity, no extra reach. A Gyrocopter and a ground Unit never block each other: it passes through them and they through it (decided 2026-10-01), so only cliffs and water tell it apart.
- The Motorbike carries Flags; it still has its weak weapon, and the Carrier can shoot (decided 2026-09-29).
- Damage multipliers. From the raw parameters alone the triangle easily collapses into a "best Unit", so a damage-multiplier matrix goes with them. Attacker in the rows, target in the columns:

| Attacker ↓ / target → | Buggy | Truck | Gyrocopter |
|---|---|---|---|
| Buggy | 1.0 | 1.5 | 0.5 |
| Truck | 0.5 | 1.0 | 1.5 |
| Gyrocopter | 1.5 | 0.5 | 1.0 |

  The Motorbike deals and receives 1.0× against every type. Damage taken = the attacker's DMG × the multiplier. While the matrix is in use its shape is fixed: above 1.0 against the Unit you beat, below 1.0 against the one that beats you, 1.0 against your own type and 1.0 for the Motorbike both ways. The two off-diagonal values are starting values. If the triangle shows even without the matrix, every multiplier is set to 1.0.
- Data. The source gives each vehicle a VehicleStats resource (.tres) with max_hp, damage, speed, turn_rate, can_fly, fuel_use. Our resource is UnitStats (decided 2026-10-01): it already carries max_hit_points, max_speed, acceleration, braking, reverse_max_speed, turn_rate (stored in rad/s; the table's deg/s are converted when entered), can_carry and carry_offset; damage, can_fly and fuel_use are added beside them when the stories need them. The multiplier matrix is data too, never branches in code.

## Resources

- Fuel (benzín). Every Unit burns Fuel while moving, the Gyrocopter the most. Without Fuel nothing drives or flies. Fuel Cans (kanister) respawn at fixed places on the Map. Capacity, burn rates, the Fuel Can's amount, its places and its respawn time are tuning values; the source gives no numbers for them.
- The Flag (vlajka). One in each Base. Only the Motorbike carries it; when the Carrier is destroyed the Flag stays lying where it was. Handling (decided 2026-09-29, built in story 004 under the name Water Canister): a Motorbike picks a Flag up by touching it; a Player may carry their own Flag back to their Base after it was stolen and dropped; the Carrier can shoot; a dropped Flag never returns home on its own. The code keeps the names WaterCanister, canister_rules and canister_* until story 008 renames them (decided 2026-10-01).
- Backlog, not v0.1: water = a temporary boost; key = a repair.

## Destruction and respawn

- A destroyed Unit costs 1 Token of its type (see Tokens and the Garage). Every way of being destroyed counts: enemy fire, a Self-destruct, a Gyrocopter crash.
- The next Unit is chosen from the remaining stock and appears in the Garage at the Player's Base after a delay of about 3 s (decided 2026-09-29; the source gives no delay; tuning value, `MatchRules.respawn_delay_seconds`).
- Self-destruct (decided 2026-09-29): every Unit has an action that destroys it on purpose, so a stranded Player can get a new Unit. It costs a Token like any destruction (decided 2026-10-01).
- Running out of Fuel (decided 2026-09-29): a ground Unit with no Fuel stops but can still turn and fire. A Gyrocopter with no Fuel crashes and counts as destroyed.
- A fresh Unit spawns with a fixed partial tank of Fuel, so dying is never a free refuel (decided 2026-09-29).
- The Unit swap at the own Base (driving into your Base to change type without dying, decided 2026-09-29) is dropped: v0.1 does not have it (decided 2026-10-01). The only way to change Unit type is a destruction, at the cost of a Token.
- The loss: when the destroyed Motorbike was the Player's last (Motorbike stock 0 after the destruction), the Round ends and the opponent wins. If both Players lose their last Motorbike on the same tick, the Round ends with no winner (reading of the source, 2026-10-01).

## Teams and visual style

- Two team colours: Orange and Teal. On Map 01 Orange is Base A and Teal is Base B (the source). Player 1 is Orange at Base A and Player 2 is Teal at Base B (decided 2026-10-01; the author may still swap the Players). Today's build paints Player 1 blue and Player 2 red; the recolour is data and belongs to the story that next touches the Bases and the HUD (story 007, Map 01).
- Models, Bases and the UI are coloured by team; colours are not mixed within a model.
- The style is low-poly: the models are built from Godot's built-in meshes and the textures are generated in code. No downloaded meshes (the Slovak says "we do not use meshes" and gives the reason: downloading is behind a subscription; read with the previous sentence it means downloaded ones, as the translation says). This replaces the ready-made kits of the 2026-09-30 brief.
- The concept art in the Discord channel #wasteland-fire is the visual reference.

## Camera and controls

The source leaves this open for a test; v0.1 skips the test (decided 2026-10-01).

- The open question as the source states it. Camera: fixed vs turning with the vehicle. Return Fire had a fixed camera; the author is considering a camera that turns with the vehicle. Prepare both and play them in split screen. The camera is a separate node (PlayerCamera) that follows the vehicle, not a child of it, with the exports `follow_rotation: bool` (whether the camera takes the vehicle's heading), `rotation_smoothing: float` (so the camera does not turn with every small movement), `look_ahead: float` (the view shifted forward in the direction of travel) and `pitch_degrees: float` (90 = straight down, about 60 = angled from behind the vehicle). The settings may differ per Unit (the Gyrocopter is perhaps better with a fixed camera). Controls: relative to the vehicle vs relative to the screen, tied to the camera and tested the same way; `control_mode`: VEHICLE_RELATIVE (throttle + steering) or SCREEN_RELATIVE (the stick points the direction). With a turning camera the author expects VEHICLE_RELATIVE to be better, with a fixed one SCREEN_RELATIVE; to verify. If the turning camera wins, v0.1 also needs an arrow to your own Base or a minimap (north up). After the test, write down the decision and shorten the section.
- Decided 2026-10-01: v0.1 keeps the turning chase camera and the vehicle-relative keys of stories 001 and 002. The test stays recorded as open for after v0.1, with its consequence attached: if a turning camera is confirmed, an arrow to the own Base or a north-up minimap follows. No story for it in v0.1.
- Mapping: our camera is `ChaseCamera`, a separate node with a `target`, as the source wants; its `ChaseCameraSettings` resource (offset, follow sharpness, look height) does not have the source's four exports, which belong to the test. SCREEN_RELATIVE speaks of a stick; v0.1 is keyboard only (decided 2026-09-29).

## Hazards

None in v0.1, as before. The other Player is the only threat; turrets, mines, drones and AI units are excluded (decided 2026-09-29).

## Technology and conventions

The source's choices, and how the project already matches them:

- Godot 4.x, exact version to be written down (the source leaves the blank): the project pins Godot 4.7.2 (`project.yaml`, `docs/engine-reference/godot/VERSION.md`). GDScript with types (the source's example: `var speed: float = 10.0`).
- Split screen via SubViewportContainer + SubViewport, one camera per Player: built in story 002.
- Input through the Input Map with a Player prefix. The source's examples are p1_accelerate and p2_fire; the project's actions are p1_throttle, p1_reverse, p1_steer_left, p1_steer_right, p1_self_destruct and the p2_ set (stories 002 and 003); a fire action joins them with the weapons.
- Folder layout (decided 2026-10-01): the source's scenes/ (one scene = one thing: unit_bike.tscn, pickup_fuel.tscn, level_01.tscn), scripts/ (mirrors scenes/), assets/ (models, textures, sounds) and docs/ (backlog.md, decisions) is the author's layout and is not adopted. Ours stays: src/gameplay, src/ui, tools/, production/, the CCGS structure.
- VehicleStats is UnitStats here (decided 2026-10-01); see Units.
- File and variable names in English, snake_case; classes PascalCase with class_name: the `naming` block of `project.yaml` says the same.
- Tuning values (speed, consumption, HP, dmg) as @export, not hardcoded: ours live in `.tres` resources (UnitStats, MatchRules) whose fields are @export.
- Communication between objects through signals, not by searching the tree for nodes: the match controller already works by signals (stories 003 and 004).
- The source's Team section (Martin: design, balance, testing; Tomáš; who works on what in GitHub Issues) is the author's; this project tracks its stories in `production/epics/`.

## Process rules

The source's rules for Claude, adopted as project process (decided 2026-10-01):

- Before a bigger change, write a short plan (the source adds: and wait for confirmation).
- After a change, say how to test it in the game: which scene to run, what to press.
- Never edit the `.godot/` folder or `*.import` files by hand; the tracked class cache (`.godot/global_script_class_cache.cfg`) is written by the import only.
- No scope beyond version 0.1 without an explicit request.
- Not adopted: "edit .tscn files only lightly; describe a new scene (which nodes, in what order) for a human to assemble in the editor". Claude keeps writing scenes (.tscn) in text, as in stories 001 to 004 (decided 2026-10-01).
- The source asks that a design or rules change updates the shared context in the same PR; here that context is this file, `CONTEXT.md` and `design/game-brief.md`, updated in the same change.

## First Playable (the source's version 0.1)

The source's v0.1 board is not in the export; this list is the prose plus our decisions.

- Local split screen for two Players; keyboard only (decided 2026-09-29); no online play.
- Map 01 with Base A (Orange, Player 1) and Base B (Teal, Player 2), cliffs and water that only the Gyrocopter crosses, fixed Fuel Can places, and its Token stock. The author offered a drawing of Map 01 in conversation on 2026-10-01; it goes under `design/source/` when it arrives and is then the layout's input for story 007. The source itself gives no drawing of Map 01 and no Map size.
- Four Units with the triangle and the multiplier matrix; the Unit chosen at every spawn from the Token stock; the Garage.
- Fuel and Fuel Cans; the Flag.
- The win by delivery; the loss by losing the last Motorbike; the Round-over screen with restart (built in story 004).
- Not in v0.1: the water boost and the key repair (the source's backlog); the camera and control test; the own-Base Unit swap (dropped); hazards, bots, online play, further Maps.

## Tuning values to set during prototyping (not rules)

- Per Unit: HP, DMG, speed and turn rate (starting values in the Units table); fire rate, range and projectile speed (the source gives none).
- The multiplier matrix (its off-diagonal starting values; fallback all 1.0).
- Token counts per Map (the source's example in Tokens and the Garage).
- Fuel: capacity per Unit, burn rate per Unit (the Gyrocopter highest), the starting tank at spawn; Fuel Can amount, places and respawn time.
- The respawn delay (in Destruction and respawn).
- Map size.
- After v0.1: the camera exports and the control mode of the test.
