# Game Brief: Wasteland Fire

<!--
THE ONE-PAGE BRIEF. At the `minimal` workflow tier this is the ENTIRE design doc —
it replaces the full concept doc, systems decomposition, and per-system GDDs.
Rules of record: design/rules.md (translated from the author's Slovak source).
Vocabulary: CONTEXT.md — Player, Base, Flag, Carrier, Round, Team colour, Unit,
Motorbike, Buggy, Truck, Gyrocopter, Token, Garage, Self-destruct, Fuel, Fuel Can,
Map, First Playable.
Engine is set separately (project.yaml / /setup-engine) — not restated here.
Written 2026-09-30 by /brainstorm (Lean Brief flow, autonomous run); rewritten
2026-10-01 for the author's artifact version 0.1 (archived under design/source/).
-->

**One-sentence pitch:** Two friends on one couch drive wasteland Motorbikes, Buggies, Trucks and Gyrocopters across a split screen to steal each other's Flag and haul it home on a Motorbike, burning Fuel they must keep finding and paying a Token for every wreck.

## Core loop
- Spawn in the Garage from your remaining Tokens: pick a Unit type, drive out, burning Fuel.
- Hunt the other Player with the Unit that beats theirs; grab Fuel Cans to keep moving.
- Reach their Base on a Motorbike, touch their Flag and carry it home while they chase you.
- Destroyed: a Token of that type is gone. Pick again from what is left and go again.

## Player goal & fail state — what "working" looks like
- Goal: deliver the opponent's Flag to your own Base; the Round ends the moment it arrives.
- Fail: your last Motorbike is destroyed, which leaves your Motorbike stock at 0; without a Motorbike you can never carry a Flag, so the opponent wins.
- Nothing else ends a Round. A stranded Unit can Self-destruct at the cost of a Token. A dropped Flag stays where it fell until a Motorbike touches it.

## MVP — what must exist to be the game
<!-- Each item becomes one story; numbered in build order. -->
1. **Driving toy**: one Motorbike on a greybox plane: keyboard throttle and steering, chase camera, arcade kinematic movement that is fun to drive for five minutes. Unchanged; story 001 is Complete.
2. **Split screen for two**: two side-by-side viewports, one Unit and one fixed keyboard layout per Player, both driving at once. Unchanged; story 002 is Complete.
3. **Bases, destruction and respawn**: two greybox Bases; a destroyed Unit respawns at its Player's Base after a delay of about 3 s (tuning value); a Self-destruct action so a stranded Unit can respawn. Unchanged; story 003 is Complete. Respawns become limited by the Tokens of item 8.
4. **Flag and the win**: the built item 4 under its new name. One Flag per Base; only a Motorbike picks it up, by touching it; it drops where the Carrier is destroyed and never returns home on its own; the owner may carry it back; delivering the opponent's Flag to your own Base wins the Round. Per-Player HUD (hit points, Flag status) and a Round-over screen with restart on R. Story 004 is Complete as "Water Canister and the win"; the loss condition arrives with item 8, which also renames the code.
5. **Four Units and the triangle**: Buggy, Truck and Gyrocopter beside the Motorbike, with the source's starting values (HP, DMG, speed, turn rate, flies) as data; one weapon each that fires straight ahead at one height, so turning is aiming; the damage-multiplier matrix as data: 1.5 against the Unit you beat, 0.5 against the one that beats you, 1.0 otherwise and for the Motorbike both ways; the Gyrocopter crosses cliffs and water and gains nothing else from flying; the Unit type is chosen at every spawn; the Carrier can shoot; only the Motorbike carries.
6. **Fuel and Fuel Cans**: as before, for four Units. Every Unit burns Fuel while moving, the Gyrocopter fastest; an empty ground Unit stops but can still turn and fire; an empty Gyrocopter crashes and counts as destroyed; a fresh Unit spawns with a fixed partial tank; Fuel Cans at fixed Map spots refill and respawn; a Fuel gauge on the HUD.
7. **Map 01**: a small bounded Map built from Godot's built-in meshes with code-generated textures, laid out from the author's drawing of Map 01 (offered 2026-10-01) if it is under `design/source/`; Base A and Base B with their Garages; cliffs and water that only the Gyrocopter crosses; the Fuel Can spots; the Team colours Orange (Player 1, Base A) and Teal (Player 2, Base B) applied to Bases, Units and UI, replacing today's blue and red.
8. **Tokens, the Garage and the loss**: the per-Map Token stock; minus one per destruction, Self-destruct and Fuel crash included; the choice from the remaining stock at the start and after every destruction while the game keeps running; the chosen Unit appears in the Garage; the loss when the last Motorbike is gone; the Round-over screen naming the win or the loss. The code renames the Water Canister to the Flag here (WaterCanister, canister_rules, canister_*).

## Out of scope — not building this
- No online play, no AI bots or drones, no turrets or mines: the other Player is the only threat.
- No second Map, no map editor, no destructible buildings.
- No downloaded asset kits or meshes: Godot's built-in meshes and code-generated textures instead.
- No Unit swap at the own Base: a Unit type changes only through a destruction.
- No camera or control-mode test in v0.1: the turning chase camera and the vehicle-relative keys of items 1 and 2 stay; the test, and the arrow or north-up minimap it may call for, come after v0.1.
- No water boost and no key repair: the source's backlog, not v0.1.
- Keyboard only: no gamepad support, no key-rebinding UI.
- No music or sound, no menus beyond the Round-over screen, no save or settings, no export or Steam work: run from the editor or a local build.
- Nothing from Return Fire that the rules dropped: no flag hunt in towers, no ammo or repair economy, no radar.

## Build order
1. Driving toy: done.
2. Split screen for two: done.
3. Bases, destruction and respawn: done.
4. Flag and the win: done. With 1 to 3 this is the vertical slice: two Motorbikes, two Bases, one Flag run. The sofa test belongs here, before the triangle exists; stories 001 to 004 are Complete as of 2026-10-01.
5. Four Units and the triangle.
6. Fuel and Fuel Cans.
7. Map 01: the greybox stays until the loop is proven; the built-mesh dressing and the Team colours come here.
8. Tokens, the Garage and the loss: last, because it changes how a Round ends and renames the Water Canister code to the Flag.

---
**Who it's for / what they feel:** Two friends on one couch who want a ten-minute rivalry: the panic of being chased with the Flag and the grin of stealing it back.

**Art & audio direction:** Low-poly built from Godot's built-in meshes with code-generated textures in one flat-shaded palette; the Team colours Orange and Teal on everything a Player owns, never mixed within a model; the concept art in Discord #wasteland-fire is the reference; no downloaded kits; no audio in the First Playable.

**Reference game:** Return Fire (1995): its two-player split-screen flag run with vehicle counters; the MVP keeps the flag run and the counters, now four vehicles (Buggy beats Truck, Truck beats Gyrocopter, Gyrocopter beats Buggy, the Motorbike apart for the Flag), and drops towers, turrets, mines, the hidden-flag hunt and the classical soundtrack.
