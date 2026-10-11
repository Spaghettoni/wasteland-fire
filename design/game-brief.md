# Game Brief: Wasteland Fire

<!--
THE ONE-PAGE BRIEF. At the `minimal` workflow tier this is the ENTIRE design doc —
it replaces the full concept doc, systems decomposition, and per-system GDDs.
Rules of record: design/rules.md (translated from the author's Slovak source).
Vocabulary: CONTEXT.md — Player, Base, Flag, Carrier, Round, Team colour, Unit,
Motorbike, Buggy, Truck, Gyrocopter, Token, Garage, Self-destruct, Swap, Fuel,
Fuel Can, Map, Gate, Cover, Turret, Flag Wall, Mine, First Playable; since
2026-10-10 also Ammo, Supply building, Supply zone, Wall Panel, Height, Tall piece.
Engine is set separately (project.yaml / /setup-engine) — not restated here.
Written 2026-09-30 by /brainstorm (Lean Brief flow, autonomous run); rewritten
2026-10-01 for the author's artifact version 0.1 (archived under design/source/);
updated 2026-10-07 for the Turrets, Flag Walls and Mines (the developer's request
and the author's board, archived under design/source/); updated 2026-10-10 for
the author's comments after stories 012 to 014 (archived under design/source/).
-->

**One-sentence pitch:** Two friends on one couch drive wasteland Motorbikes, Buggies, Trucks and Gyrocopters across a split screen to steal each other's Flag and haul it home on a Motorbike, burning Fuel and firing ammo that they can restock only at the supply buildings, and paying a Token for every wreck.

## Core loop
- Spawn in the Garage from your remaining Tokens: pick a Unit type, drive out with a full tank and a full load of ammo, burning Fuel.
- Hunt the other Player with the Unit that beats theirs; stop in front of the Fuel building or an ammunition building to keep moving and firing; fly the Gyrocopter high over every wall and the cover, but not fast into a tower, a Fuel tank or a Turret, which destroys it; with a Truck, lay Mines on their routes (any ground Unit sets them off, yours too).
- Break into their Base with a combat Unit: destroy the two Turrets outside their Gate, which fire at you, and one of the Flag Walls around their Flag; every wall on the Map is a Wall Panel like the Flag Walls, so you can also breach their Base's walls, and a Turret or a panel shows its damage as it goes. The Motorbike cannot break a Wall Panel, and no Flag can be taken while a Turret of its Base stands.
- Reach their Base on a Motorbike, touch their Flag and carry it home while they chase you.
- Badly damaged, at or below 20% of its hit points, a Unit smokes and moves at half speed. Destroyed, it explodes, and a Token of that type is gone. Pick again from what is left and go again.

## Player goal & fail state — what "working" looks like
- Goal: deliver the opponent's Flag to your own Base; the Round ends the moment it arrives.
- Fail: your last Motorbike is destroyed, whatever destroyed it (a Turret or a Mine counts too), which leaves your Motorbike stock at 0; without a Motorbike you can never carry a Flag, so the opponent wins.
- Nothing else ends a Round. A stranded Unit can Self-destruct at the cost of a Token, and its replacement starts with full Fuel and ammo. A dropped Flag stays where it fell until a Motorbike touches it.

## MVP — what must exist to be the game
<!-- Each item becomes one story; numbered in build order. -->
1. **Driving toy**: one Motorbike on a greybox plane: keyboard throttle and steering, chase camera, arcade kinematic movement that is fun to drive for five minutes. Unchanged; story 001 is Complete.
2. **Split screen for two**: two side-by-side viewports, one Unit and one fixed keyboard layout per Player, both driving at once. Unchanged; story 002 is Complete.
3. **Bases, destruction and respawn**: two greybox Bases; a destroyed Unit respawns at its Player's Base after a delay of about 3 s (tuning value); a Self-destruct action so a stranded Unit can respawn. Unchanged; story 003 is Complete. Respawns become limited by the Tokens of item 8.
4. **Flag and the win**: the built item 4 under its new name. One Flag per Base; only a Motorbike picks it up, by touching it; it drops where the Carrier is destroyed and never returns home on its own; the owner may carry it back; delivering the opponent's Flag to your own Base wins the Round. Per-Player HUD (hit points, Flag status) and a Round-over screen with restart on R. Story 004 is Complete as "Water Canister and the win"; the loss condition arrives with item 8, which also renames the code.
5. **Four Units and the triangle**: Buggy, Truck and Gyrocopter beside the Motorbike, with the source's starting values (HP, DMG, speed, turn rate, flies) as data; one weapon each that fires straight ahead at one height, so turning is aiming; the damage-multiplier matrix as data: 1.5 against the Unit you beat, 0.5 against the one that beats you, 1.0 otherwise and for the Motorbike both ways; the Gyrocopter crosses cliffs and water and gains nothing else from flying; the Unit type is chosen at every spawn; the Carrier can shoot; only the Motorbike carries.
6. **Fuel and Fuel Cans**: as before, for four Units. Every Unit burns Fuel while moving, the Gyrocopter fastest; an empty ground Unit stops but can still turn and fire; an empty Gyrocopter crashes and counts as destroyed; a fresh Unit spawns with a fixed partial tank; Fuel Cans at fixed Map spots refill and respawn; a Fuel gauge on the HUD. Changed after the First Playable (2026-10-10): every new Unit starts with a full tank and a full load of ammo, and supply buildings replace Map 01's Fuel Cans (see the paragraph after the Build order).
7. **Map 01**: a small bounded Map built from Godot's built-in meshes with code-generated textures, laid out from the author's drawing of Map 01 (offered 2026-10-01) if it is under `design/source/`; Base A and Base B with their Garages; cliffs and water that only the Gyrocopter crosses; the Fuel Can spots; the Team colours Orange (Player 1, Base A) and Teal (Player 2, Base B) applied to Bases, Units and UI, replacing today's blue and red. Changed after the First Playable (2026-10-10): the Fuel building and the two ammunition buildings replace the Fuel Can spots, and every wall becomes a Wall Panel (see the paragraph after the Build order).
8. **Tokens, the Garage and the loss**: the per-Map Token stock; minus one per destruction, Self-destruct and Fuel crash included; the choice from the remaining stock at the start and after every destruction while the game keeps running; the chosen Unit appears in the Garage; the loss when the last Motorbike is gone; the Round-over screen naming the win or the loss. The code renames the Water Canister to the Flag here (WaterCanister, canister_rules, canister_*).

## Out of scope — not building this
- No online play, no AI bots or drones: no Unit is driven by the computer. Turrets and Mines are no longer excluded (decided 2026-10-07): each Base's two Turrets fire on their own and the Truck lays Mines, so the other Player is no longer the only threat (see the paragraph after the Build order).
- No second Map, no map editor, and no destructible buildings beyond the Turrets and the Wall Panels: the towers, the remaining cover and the buildings, the supply buildings among them, stand all Round. The Base walls are no longer excluded (the comments; decided 2026-10-10, the developer confirming the scope change): every wall on Map 01, the Base walls, the Garage walls and the two scrap walls, becomes a Wall Panel of the Flag Walls' kind (until then: "no destructible buildings beyond the Turrets and the Flag Walls: the Base walls, the towers and the cover stand all Round").
- No downloaded asset kits or meshes: Godot's built-in meshes and code-generated textures instead, and since 2026-10-10 the Units' models and Map 01's rocks, props and Base trim built in Blender by the repository's own scripts (decided by the developer; `design/rules.md`, Teams and visual style).
- No Unit swap at the own Base in the First Playable: a Unit type changes only through a destruction. After the first playtest the swap is back (decided 2026-10-03): a story after the playtest fixes (`design/rules.md`, Destruction and respawn).
- No camera or control-mode test in v0.1: the turning chase camera and the vehicle-relative keys of items 1 and 2 stay; the test, and the arrow or north-up minimap it may call for, come after v0.1.
- No water boost and no key repair: the source's backlog, not v0.1.
- Keyboard only: no gamepad support, no key-rebinding UI.
- No music or sound, no menus beyond the Round-over screen, no save or settings, no export or Steam work: run from the editor or a local build.
- Nothing from Return Fire that the rules dropped: no flag hunt in towers, no repair economy, no radar. Ammo is no longer excluded (the comments; decided 2026-10-10, the developer confirming the scope change): every Unit's gun carries a load of ammo that refills only at an ammunition building, while a Truck's Mines still come only with a new Truck and the Turrets never run out (until then: "no ammo or repair economy (Shots are unlimited, and a Truck's Mines come only with a new Truck)").

## Build order
1. Driving toy: done.
2. Split screen for two: done.
3. Bases, destruction and respawn: done.
4. Flag and the win: done. With 1 to 3 this is the vertical slice: two Motorbikes, two Bases, one Flag run. The sofa test belongs here, before the triangle exists; stories 001 to 004 are Complete as of 2026-10-01.
5. Four Units and the triangle.
6. Fuel and Fuel Cans.
7. Map 01: the greybox stays until the loop is proven; the built-mesh dressing and the Team colours come here.
8. Tokens, the Garage and the loss: last, because it changes how a Round ends and renames the Water Canister code to the Flag.

After the first playtest with friends (2026-10-03) the author listed seven changes; `production/epics/wasteland-fire/story-009-playtest-quick-fixes.md` quotes them. Quick fixes first (decided 2026-10-03): solid depot tanks, the Gyrocopter over the cover, turning on the spot, slower Fuel burn while standing and the out-of-Fuel Self-destruct hint (story 009); then the camera from almost straight above and the Unit swap at the own Base, each its own story, once the author has played 009.

After the First Playable (2026-10-07) the developer asked for Turrets, walls around the Flag and Mines laid by the Truck, and shared five cards of the author's board (`design/source/wasteland-fire-board-2026-10-07.en.md`; the rules are in `design/rules.md`, Turrets, Flag Walls and Mines). Built in this order, each its own story (reading, 2026-10-07: the Flag Walls first, as the passive target for the new way Shots damage what is not a Unit): story 012, Flag Walls (four panels close the gaps between each water tower's legs around the Flag; every Unit but the Motorbike breaks them and the Gyrocopter flies over them; new Units appear on the Garage's side spots); story 013, Turrets (two per Base outside the Gate fire at the other Player's Unit when they see it, and no Flag can be taken while a Turret of its Base stands); story 014, the Truck's Mines (5 per Truck, live after 3 s, destroying at once any ground Unit that drives onto them, its owner's included, never the Gyrocopter, and never laid in or near a Base). The board's other two cards, Bushes and a simpler Map 01, come later.

After playing stories 012 to 014 the author sent nine comments, pasted by the developer on 2026-10-10 (`design/source/wasteland-fire-comments-2026-10-10.sk.txt`, with the translation in `.en.md`; the author's board has no cards for them), and the developer answered the questions they raised the same day, taking the recommended option every time (the rules are in `design/rules.md`, mainly Units, Heights, Resources, Destruction and respawn, and Turrets, Flag Walls and Mines). Built in this order, one story per fresh session (decided 2026-10-10): story 015, the Turrets show their damage (two damaged looks, as the Flag Walls have, and the Turrets grow to about 3 m so that their heads reach the high Height, sized against the flying Gyrocopter's drawn band, which the story measures first); story 016, a destroyed Unit explodes (however it was destroyed, never at a Swap); story 017, badly damaged Units (at or below 20% of its hit points a Unit smokes and moves at half speed); story 018, the Base walls become Wall Panels (both Bases' back, side and Gate walls, 40 hit points each, the corner towers kept); story 019, the Garage walls and the two scrap walls become Wall Panels too; story 020, two Heights (the Gyrocopter flies only in the high one, at one constant height over every low piece, and every hit volume spans both); story 021, the Gyrocopter's crash (flown fast into a Tall piece, a tower, a water tower, a Fuel tank or a Turret, it is destroyed and explodes); story 022, ammo and the full start (a load of ammo per Unit type, and every new Unit starts with a full tank and a full load); story 023, the Fuel building replaces the Fuel Cans (the centre depot becomes the Fuel building, refilling the Fuel of a Unit that stops in the zone on either of its Base-facing sides, and the nine Fuel Cans leave Map 01); story 024, the ammunition buildings, and no Mines at the supply zones (an ammunition building on each half refills the ammo of a Unit that stops in the zone in front of it, and no Mine can be laid in or around any supply zone). The developer's "all eight" are ten stories: the wall story is built as two (decided 2026-10-10), and so is the supply story, because the drafts' review found it more than one build session (reading, 2026-10-10); until story 024, ammo comes back only with a new Unit.

---
**Who it's for / what they feel:** Two friends on one couch who want a ten-minute rivalry: the panic of being chased with the Flag and the grin of stealing it back.

**Art & audio direction:** Low-poly built from Godot's built-in meshes with code-generated textures in one flat-shaded palette, the Units' models and Map 01's rocks, props and Base trim built in Blender by the repository's scripts in the same palette, the ground drawn from generated noise (since 2026-10-10); the Team colours Orange and Teal on everything a Player owns, never mixed within a model; the concept art in Discord #wasteland-fire is the reference; no downloaded kits; no audio in the First Playable.

**Reference game:** Return Fire (1995): its two-player split-screen flag run with vehicle counters; the MVP keeps the flag run and the counters, now four vehicles (Buggy beats Truck, Truck beats Gyrocopter, Gyrocopter beats Buggy, the Motorbike apart for the Flag), and drops the flag towers, the hidden-flag hunt and the classical soundtrack. Its turrets and mines came back after the First Playable (2026-10-07) in this game's own form: two Turrets per Base and the Truck's Mines.
