# Wasteland Fire — the author's artifact, English translation

Source: the "Wasteland Fire" artifact (https://claude.ai/artifact/3dVGdvULzywJvn8GDLEXDP), exported by the
author on 2026-10-01 as `wasteland-fire-artifact-2026-10-01.html` (beside this file, with the extracted
Slovak text as `.sk.txt`). Translated from Slovak on 2026-10-01. The artifact's "versions and ideas" board
is not in the export: its items live in the artifact's database, so only the prose sections are here.
This is the author's text; the project's rules of record are `design/rules.md`.

RoninYa · working title: Wasteland Fire

A 3D game in the style of Return Fire set in a Mad Max world. This is the shared context for Claude
Code (CLAUDE.md). When the design or the rules change, update it in the same PR.

## Pitch

Two players, each with their own base. The goal: steal the opponent's flag and bring it home. Fuel is
collected around the map; without it nothing drives or flies. One match, no rounds.

## Versions and ideas

What belongs to which version. Add ideas, move them between the tabs (also by dragging onto a tab) and
delete what was dropped. Everyone sees the changes at once. Only what is in the version currently being
worked on goes into code. The backlog holds ideas for later.

## Teams and visuals

- Teal: Base B on Map 01.
- Orange: Base A on Map 01.
- Models, bases and the UI are coloured by team; colours are not mixed within a model.
- The style is low-poly: Claude builds the models from Godot's built-in meshes and generates the textures
  in code. We do not use downloaded meshes (downloading is behind a subscription).
- We build on the concept art in the Discord channel #wasteland-fire.

## Match rules

- Each player has a stock of tokens for each vehicle type (for example motorbike 5, buggy 3, truck 2,
  gyrocopter 2). The counts are set by the map; each map may differ.
- At the start and after every destruction the player picks any vehicle from the remaining stock and
  appears in the garage. The game keeps running meanwhile.
- A destroyed vehicle = minus 1 token of that type.
- Only the motorbike can carry the flag. When the carrier is destroyed, the flag stays lying where it was.
- End of the game: you bring the opponent's flag home (a win), or you lose your last motorbike (a loss).

## Vehicles

Four vehicles: a combat trio (gyrocopter, truck, buggy) that beat one another as rock, paper, scissors,
and the motorbike apart, purely for flags. Shooting happens at one height only and the weapon fires
straight ahead, so turning is the aiming speed. Flying means only passing over cliffs and water.

| Vehicle | HP | DMG | Speed m/s | Turn °/s | Flies |
|---|---|---|---|---|---|
| Motorbike | 40 | 5 | 22 | 220 | – |
| Buggy | 100 | 12 | 18 | 180 | – |
| Truck | 220 | 25 | 10 | 70 | – |
| Gyrocopter | 70 | 15 | 15 | 120 | yes |

Starting values, to be tuned by playing. Each vehicle has its own VehicleStats resource (.tres): max_hp,
damage, speed, turn_rate, can_fly, fuel_use.

- Buggy > Truck: it circles the truck, which cannot turn and aim in time.
- Truck > Gyro: the gyrocopter has few HP; the truck downs it in a few hits.
- Gyro > Buggy: it escapes over cliffs and water where the buggy cannot go, and shoots from safety.

From the raw parameters alone the triangle easily collapses into a "best vehicle", so a damage-multiplier
matrix goes with them. The motorbike deals and receives 1.0×.

| Attacker ↓ / target → | Buggy | Truck | Gyro |
|---|---|---|---|
| Buggy | 1.0 | 1.5 | 0.5 |
| Truck | 0.5 | 1.0 | 1.5 |
| Gyro | 1.5 | 0.5 | 1.0 |

If the triangle shows even without the matrix, we set everything to 1.0.

## Resources and pickups

- Fuel: every unit consumes it while moving (the gyrocopter the most). Fuel cans respawn at fixed places.
- Flag: one in each base. Only the motorbike carries it; after the carrier is destroyed it stays lying.
- Backlog (not v0.1): water = a temporary boost, key = a repair.

## Technology

- Godot 4.x (write down the exact version: ______), GDScript with types (`var speed: float = 10.0`).
- Split screen via SubViewportContainer + SubViewport, one camera per player.
- Input through the Input Map with a player prefix: p1_accelerate, p2_fire, …

## Open questions · a test decides

- Camera: fixed vs turning with the vehicle. Return Fire had a fixed camera; we are considering a camera
  that turns with the vehicle. Prepare both options and play them in split screen.
- The camera is a separate node (PlayerCamera) that follows the vehicle, not a child of it.
- `@export var follow_rotation: bool` – whether the camera takes the vehicle's heading.
- `@export var rotation_smoothing: float` – smoothing, so the camera does not turn with every small movement.
- `@export var look_ahead: float` – the view shifted forward in the direction of travel.
- `@export var pitch_degrees: float` – 90 = straight down, about 60 = angled from behind the vehicle.
- The settings may differ per unit (the gyrocopter is perhaps better with a fixed camera).
- Controls: relative to the vehicle vs relative to the screen. Tied to the camera; the same approach.
- `@export var control_mode`: VEHICLE_RELATIVE (throttle + steering) or SCREEN_RELATIVE (the stick points
  the direction).
- With a turning camera we expect VEHICLE_RELATIVE to be better, with a fixed one SCREEN_RELATIVE – to verify.
- If the turning camera wins, v0.1 also needs an arrow to your own base or a minimap (north up).
- After the test, write down the decision and shorten this section.

## Folder structure

`scenes/` (.tscn – one scene = one thing: unit_bike.tscn, pickup_fuel.tscn, level_01.tscn) ·
`scripts/` (.gd – mirrors scenes/) · `assets/` (models, textures, sounds) · `docs/` (backlog.md, decisions).

## Conventions

- File and variable names in English, snake_case; classes PascalCase with class_name.
- Tuning values (speed, consumption, HP, dmg) as @export, not hardcoded.
- Communication between objects through signals, not by searching the tree for nodes.

## Rules for Claude

- Before a bigger change write a short plan and wait for confirmation.
- Edit .tscn files only lightly; rather describe a new scene (which nodes, in what order) and a human
  assembles it in the editor.
- Do not edit the .godot/ folder or *.import files.
- After a change, say how to test it in the game (which scene to run, what to press).
- Do not extend the scope beyond version 0.1 without an explicit request.

## Team

- Martin (Discord: oko) · design, balance, testing, …
- Tomáš (Discord: tomero) · …
- Who is working on what: GitHub Issues.
