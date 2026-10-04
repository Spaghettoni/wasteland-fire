# Wasteland Fire

A two-player split-screen 3D vehicle game in the style of Return Fire, set in a post-apocalyptic wasteland. Working title "Wasteland Fire", project folder `ronin-ya`. Private, for playing with friends at home. Rules of record: `design/rules.md`. Slovak terms from the rules source are given in parentheses.

## Language

### Effort scope

**First Playable**:
The first version worth sitting a friend down for; the rules source calls it version 0.1. Two Players, split screen, Map 01, four Units, Tokens, Fuel, the Flag, win by delivery or the opponent losing their last Motorbike, and a coherent low-poly look built from Godot's built-in meshes.
_Avoid_: MVP, vertical slice, prototype, demo

**Game-Night Build**:
The version after the First Playable, charted as its own effort later. Holds everything the First Playable excludes.
_Avoid_: full game, v2, release, final, backlog

### Players and objective

**Player**:
One of the two humans in a Round. Each owns a Base, defends one Flag, holds a stock of Tokens and has a Team colour.
_Avoid_: user, team, squad

**Base (základňa)**:
A Player's home on the Map: Base A for Player 1 and Base B for Player 2 on Map 01. It holds that Player's Flag at the start of a Round, has the Garage where the Player's Units appear, and is where the opponent's Flag must be delivered to win.
_Avoid_: bunker, HQ, spawn point, camp

**Flag (vlajka)**:
The objective; it replaces the Water Canister of the earlier rules. One per Base. Only a Motorbike can carry it. When its Carrier is destroyed it stays where it fell.
_Avoid_: Water Canister, canister, water, banner, standard, objective, token

**Carrier (nosič)**:
The Unit currently carrying a Flag. Only a Motorbike can be a Carrier; it can still shoot.
_Avoid_: flag bearer, runner

**Round**:
One match. The rules source calls it a match (zápas) and plays one match with no rounds, so a Round is the whole game from the first spawn to the end. It ends the moment a Player delivers the opponent's Flag to their own Base or loses their last Motorbike.
_Avoid_: game, match, level, battle, series

**Team colour**:
The colour of everything a Player owns: Units, Base and UI. Orange is Player 1 at Base A and Teal is Player 2 at Base B on Map 01; colours are never mixed within one model.
_Avoid_: player colour, faction colour, red, blue

### Units

**Unit (jednotka)**:
A controllable vehicle with hit points. Four types: the Motorbike, and the combat trio Buggy, Truck and Gyrocopter in a rock-paper-scissors triangle. A destroyed Unit costs one Token of its type; the Player then picks the next Unit from the remaining stock.
_Avoid_: vehicle, character, life, mech

**Motorbike (motorka)**:
The fast, weak Unit and the only one that can carry a Flag. It sits outside the combat triangle and deals and receives normal damage against every type. A Player who loses their last Motorbike loses the Round.
_Avoid_: bike, jeep, cycle

**Buggy (bugina)**:
The agile combat Unit. Beats the Truck by circling it faster than the Truck can turn; loses to the Gyrocopter.
_Avoid_: armed buggy, car, tank, dune buggy

**Truck (truck)**:
The heavy, slow combat Unit with the most hit points and the hardest hits. Beats the Gyrocopter in a few hits; loses to the Buggy.
_Avoid_: lorry, tank, van, heavy

**Gyrocopter (gyrokoptéra)**:
The flying combat Unit. Flying means only that it crosses cliffs, water and the cover, which ground Units cannot (the cover since the first playtest, 2026-10-03); it shoots and is shot at the same height as everyone. Burns Fuel fastest and crashes when its tank is empty. Beats the Buggy from across cliffs and water; loses to the Truck.
_Avoid_: helicopter, chopper, gyro, plane

**Token (token)**:
One Unit of one type in a Player's stock: a Player with five Motorbike Tokens can lose five Motorbikes. Each Player holds a stock per type, set by the Map (the rules source's example: Motorbike 5, Buggy 3, Truck 2, Gyrocopter 2). A Token is taken at the destruction of a Unit of its type, never at its spawn, so the Unit in play is not yet subtracted; a type with no Tokens left cannot be picked again, and a Player whose last Motorbike Token is gone has lost the Round.
_Avoid_: life, lives, credit, ticket, respawn, coin

**Garage (garáž)**:
The place at a Player's Base where the chosen Unit appears, at the start of a Round, after every destruction and after a Swap. It is the spawn point of stories 003 and 004.
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
The one opening in a Base's wall, in the wall that faces the Map's centre; every Unit leaves and enters its Base through it. On Map 01 about 11 m wide (drawn at 10 m and widened so the Truck clears it).
_Avoid_: door, entrance, exit

**Ford**:
A shallow creek crossing on the Map. A ground Unit inside a Ford drives at no more than a fraction of its top speed (Map 01: half, a starting value to tune); the Gyrocopter crosses at full speed. Map 01 has two, across the salt flat between the canyon and the ridge.
_Avoid_: creek, river, mud, shallows

**Cover**:
A static obstacle on the Map that stops every ground Unit and every shot and is never destroyed; the Gyrocopter flies over it (decided 2026-10-03, after the first playtest). On Map 01 the eight wrecks, the two long containers and the two scrap walls; the drawings' wrecks are cover, not destroyed Units. The depot's three Fuel tanks are not cover: they stop every Unit, the Gyrocopter included, like walls.
_Avoid_: obstacle, barricade, prop, destructible

**View**:
What a Player's camera shows, one of two: the view from above (the Round's start: high over the Unit, almost straight down with a slight forward tilt, turning with the Unit; the tops of the water towers are not drawn in it, so the Flag on its seat stays in sight) or the chase view (from behind and above). Each Player switches their own with one key, at any time; the other Player's view does not change (decided 2026-10-03, after the first playtest, as a trial the friends compare in one playtest).
_Avoid_: camera mode, zoom, perspective
