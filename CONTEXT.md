# Wasteland Fire

A two-player split-screen 3D vehicle game in the style of Return Fire, set in a post-apocalyptic wasteland. Working title "Wasteland Fire", project folder `ronin-ya`. Private, for playing with friends at home. Rules of record: `design/rules.md`. Slovak terms from the rules source are given in parentheses.

## Language

### Effort scope

**First Playable**:
The first version worth sitting a friend down for; the rules source calls it version 0.1. Two Players, split screen, Map 01, four Units, Tokens, Fuel, the Flag, win by delivery or the opponent losing their last Motorbike, and a coherent low-poly look built from Godot's built-in meshes.
_Avoid_: MVP, vertical slice, prototype, demo

**Game-Night Build**:
The version after the First Playable, charted as its own effort later. Holds everything the First Playable excludes. Not charted yet: meanwhile the work after the First Playable is filed in the First Playable epic, in sections after its eight stories (stories 009 to 011 after the first playtest, 012 to 014 since 2026-10-07; reading, 2026-10-07).
_Avoid_: full game, v2, release, final, backlog

### Players and objective

**Player**:
One of the two humans in a Round. Each owns a Base, defends one Flag, holds a stock of Tokens and has a Team colour.
_Avoid_: user, team, squad

**Base (základňa)**:
A Player's home on the Map: Base A for Player 1 and Base B for Player 2 on Map 01. It holds that Player's Flag at the start of a Round, has the Garage where the Player's Units appear, and is where the opponent's Flag must be delivered to win. Its Player's two Turrets stand outside its Gate and four Flag Walls box in its Flag (decided 2026-10-07).
_Avoid_: bunker, HQ, spawn point, camp

**Flag (vlajka)**:
The objective; it replaces the Water Canister of the earlier rules. One per Base. Only a Motorbike can carry it. When its Carrier is destroyed it stays where it fell. It sits inside its Base's Flag Walls, and the other Player cannot pick it up while any Turret of its Base stands; its owner can always pick up their own dropped Flag (decided 2026-10-07).
_Avoid_: Water Canister, canister, water, banner, standard, objective, token

**Carrier (nosič)**:
The Unit currently carrying a Flag. Only a Motorbike can be a Carrier; it can still shoot.
_Avoid_: flag bearer, runner

**Round**:
One match. The rules source calls it a match (zápas) and plays one match with no rounds, so a Round is the whole game from the first spawn to the end. It ends the moment a Player delivers the opponent's Flag to their own Base or loses their last Motorbike.
_Avoid_: game, match, level, battle, series

**Team colour**:
The colour of everything a Player owns: Units, Base (its Turrets included), UI and the Mines that Player's Trucks lay. Orange is Player 1 at Base A and Teal is Player 2 at Base B on Map 01; colours are never mixed within one model.
_Avoid_: player colour, faction colour, red, blue

### Units

**Unit (jednotka)**:
A controllable vehicle with hit points. Four types: the Motorbike, and the combat trio Buggy, Truck and Gyrocopter in a rock-paper-scissors triangle. A destroyed Unit costs one Token of its type; the Player then picks the next Unit from the remaining stock.
_Avoid_: vehicle, character, life, mech

**Motorbike (motorka)**:
The fast, weak Unit and the only one that can carry a Flag. It sits outside the combat triangle and deals and receives normal damage against every Unit type. Its shots cannot damage a Flag Wall (the author's board, 2026-10-07). A Player who loses their last Motorbike loses the Round.
_Avoid_: bike, jeep, cycle

**Buggy (bugina)**:
The agile combat Unit. Beats the Truck by circling it faster than the Truck can turn; loses to the Gyrocopter.
_Avoid_: armed buggy, car, tank, dune buggy

**Truck (truck)**:
The heavy, slow combat Unit with the most hit points and the hardest hits. Beats the Gyrocopter in a few hits; loses to the Buggy. The only Unit that lays Mines, 5 per Truck (the author's board, 2026-10-07).
_Avoid_: lorry, tank, van, heavy

**Gyrocopter (gyrokoptéra)**:
The flying combat Unit. Flying means only that it crosses cliffs, water, the cover and the Flag Walls, which ground Units cannot (the cover since the first playtest, 2026-10-03; the Flag Walls since the author's board of 2026-10-07), and that no Mine goes off under it (the board); it shoots and is shot at the same height as everyone, and the Turrets fire at it and stop it like a wall (reading, 2026-10-07). Burns Fuel fastest and crashes when its tank is empty. Beats the Buggy from across cliffs and water; loses to the Truck.
_Avoid_: helicopter, chopper, gyro, plane

**Token (token)**:
One Unit of one type in a Player's stock: a Player with five Motorbike Tokens can lose five Motorbikes. Each Player holds a stock per type, set by the Map (the rules source's example: Motorbike 5, Buggy 3, Truck 2, Gyrocopter 2). A Token is taken at the destruction of a Unit of its type, never at its spawn, so the Unit in play is not yet subtracted; a type with no Tokens left cannot be picked again, and a Player whose last Motorbike Token is gone has lost the Round.
_Avoid_: life, lives, credit, ticket, respawn, coin

**Garage (garáž)**:
The place at a Player's Base where the chosen Unit appears, at the start of a Round, after every destruction and after a Swap. It is the spawn point of stories 003 and 004. On Map 01 a new Unit appears on one of the Garage's two side spots, because the Flag Walls close the middle spot's lane to the Gate (reading, 2026-10-07), and no Mine can be laid in a Garage (decided 2026-10-07).
_Avoid_: spawn point, hangar, depot, pad

**Self-destruct**:
A Player's action that destroys their own Unit on purpose, so a stranded Unit can be replaced. It counts as a destruction and costs a Token. A Player whose ground Unit has run out of Fuel is shown the key. Inside the own Base the same key does the Swap instead (story 011), and a stranded Unit there is shown the key for that.
_Avoid_: suicide, reset, respawn button

**Swap**:
Putting a Player's Unit away inside its own Base with the Self-destruct key, so the Player chooses another type at once and at no cost (story 011, decided 2026-10-03 after the first playtest). It is not a destruction: no Token is taken and no respawn delay runs, and it takes no Flag with it. It acts only on a Unit in play standing inside its own Base's walls, the Garage included, whatever its type; anywhere else the key destroys.
_Avoid_: change, trade, repair

### Resources

**Fuel (benzín)**:
The resource every Unit burns, faster while moving than while standing, the Gyrocopter fastest. A Unit with no Fuel can neither drive nor fly.
_Avoid_: gas, petrol, energy, stamina

**Fuel Can (kanister)**:
A pickup on the Map that refills Fuel. Sits at fixed places and respawns after being taken. The rules source's word is kanister; now that the objective is the Flag, "canister" means only this.
_Avoid_: depot, jerrycan, gas can, water canister

### World

**Map (mapa)**:
A bounded playfield holding Base A, Base B, their Garages and the fixed Fuel Can places; it also sets each Player's Token stock. The First Playable has one, Map 01.
_Avoid_: level, arena, world, stage

**Gate**:
The one opening in a Base's wall, in the wall that faces the Map's centre; every Unit leaves and enters its Base through it. On Map 01 about 11 m wide (drawn at 10 m and widened so the Truck clears it). Its Base's two Turrets stand outside it, one on each side, and no Mine can be laid in it or on the approach about 10 m in front of it (decided 2026-10-07).
_Avoid_: door, entrance, exit

**Turret (vežička)**:
A Base's automatic gun, owned by that Base's Player. It turns its barrel on its own and fires only at the other Player's Unit, and only when nothing stands in the way; no Player controls it, and it cannot be built or captured, only destroyed (the author's board, 2026-10-07). Map 01 has two outside each Gate, and while any Turret of a Base stands, the other Player cannot pick up that Base's Flag (decided 2026-10-07). It fires at the Gyrocopter too, a cliff hides a target from it although shots pass through cliffs, and a destroyed Turret stays down until the restart (reading, 2026-10-07). It is not a Unit: it never moves and has no Token. As built (story 013, 2026-10-08): a dark drum 2 m across and 1.8 m tall with a turning head, one band in its Player's Team colour and a barrel; 100 hit points; one Shot every 0.8 s, aimed where the target will be; and the line "Destroy the turrets first" in the view of a Player whose Motorbike touches a Flag that only the Turrets' lock keeps from them.
_Avoid_: tower, gun tower, sentry, cannon

**Flag Wall (zničiteľný múr)**:
One of the four low panels that close the gaps between a Base's water-tower legs, a box around its Flag (decided 2026-10-07). It has few hit points, looks damaged as it loses them, in two steps, and falls apart when they are gone (decided 2026-10-08); every Unit but the Motorbike can break it, because it ignores the Motorbike's damage; the Gyrocopter flies over it (the author's board, 2026-10-07). It stops ground Units and shots, and a broken Flag Wall stays down until the restart (reading, 2026-10-07, kept on 2026-10-08). It is not a Base wall, which is never destroyed, and not Cover.
_Avoid_: barricade, fence, destructible wall, wall on its own

**Mine (mína)**:
A charge that only the Truck lays, 5 per Truck. For about 3 s it blinks in its owner's Team colour and is harmless; then it shines and is live, and it destroys at once any ground Unit that drives onto it, its owner's included; the Gyrocopter never sets it off (the author's board, 2026-10-07). It cannot be laid in or near a Base (decided 2026-10-07). It is laid just behind the Truck; every new Truck, after a spawn or a Swap, comes with 5; and a Mine lies until it goes off or the restart (reading, 2026-10-07). One key lays it, E for Player 1 and Comma for Player 2, and that Player's view shows the Mines left, "Mines 3 / 5", while a Truck is in play (story 014).
_Avoid_: bomb, trap, landmine, explosive

**Ford**:
A shallow creek crossing on the Map. A ground Unit inside a Ford drives at no more than a fraction of its top speed (Map 01: half, a starting value to tune); the Gyrocopter crosses at full speed. Map 01 has two, across the salt flat between the canyon and the ridge.
_Avoid_: creek, river, mud, shallows

**Cover**:
A static obstacle on the Map that stops every ground Unit and every shot and is never destroyed; the Gyrocopter flies over it (decided 2026-10-03, after the first playtest). On Map 01 the eight wrecks, the two long containers and the two scrap walls; the drawings' wrecks are cover, not destroyed Units. The depot's three Fuel tanks are not cover: they stop every Unit, the Gyrocopter included, like walls. Nor are the Flag Walls, although the Gyrocopter flies over them too: a Flag Wall can be destroyed. Nor are the Turrets (reading, 2026-10-07).
_Avoid_: obstacle, barricade, prop, destructible

**View**:
What a Player's camera shows, one of two: the view from above (the Round's start: high over the Unit, almost straight down with a slight forward tilt, turning with the Unit; the tops of the water towers are not drawn in it, so the Flag on its seat stays in sight) or the chase view (from behind and above). Each Player switches their own with one key, at any time; the other Player's view does not change (decided 2026-10-03, after the first playtest, as a trial the friends compare in one playtest).
_Avoid_: camera mode, zoom, perspective
