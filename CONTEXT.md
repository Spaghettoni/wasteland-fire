# Wasteland Fire

A two-player split-screen 3D vehicle game in the style of Return Fire, set in a post-apocalyptic wasteland. Working title "Wasteland Fire", project folder `ronin-ya`. Private, for playing with friends at home. Rules of record: `design/rules.md`. Slovak terms from the rules source are given in parentheses.

## Language

### Effort scope

**First Playable**:
The first version worth sitting a friend down for; the rules source calls it version 0.1. Two players, split screen, one small map, three Units, Fuel and Water rules, win by delivery, and a coherent ready-made low-poly look.
_Avoid_: MVP, vertical slice, prototype, demo

**Game-Night Build**:
The version after the First Playable, charted as its own effort later. Holds everything the First Playable excludes.
_Avoid_: full game, v2, release, final, backlog

### Players and objective

**Player**:
One of the two humans in a Round. Each owns a Base and defends one Water Canister.
_Avoid_: user, team, squad

**Base (základňa)**:
A Player's home on the Map. It holds that Player's Water Canister at the start of a Round, is where the Player's Units respawn, and is where the opponent's Water Canister must be delivered to win.
_Avoid_: bunker, HQ, spawn point, camp

**Water Canister (voda, kanister)**:
The objective; the "flag". One per Base. Only a Motorbike can carry it. When its Carrier is destroyed it stays where it fell.
_Avoid_: flag, water (alone), objective, token

**Carrier (nosič)**:
The Unit currently carrying a Water Canister. Only a Motorbike can be a Carrier.
_Avoid_: flag bearer, runner

**Round**:
One match. It ends the moment a Player delivers the opponent's Water Canister to their own Base.
_Avoid_: game, match, level, battle

### Units

**Unit (jednotka)**:
A controllable vehicle with hit points. Three types, in a rock-paper-scissors triangle. A destroyed Unit respawns at its Player's Base.
_Avoid_: vehicle, character, life, mech

**Motorbike (motorka)**:
The fast, weak Unit and the only one that can carry a Water Canister. Beats the Buggy by agility; loses to the Gyrocopter.
_Avoid_: bike, jeep, cycle

**Buggy (ozbrojená bugina)**:
The heavy Unit with an anti-aircraft machine gun. Beats the Gyrocopter; loses to the Motorbike.
_Avoid_: armed buggy (as a separate term), car, tank, truck

**Gyrocopter (gyrokoptéra)**:
The flying Unit. Flies over terrain, shoots from above, burns Fuel fastest. Beats the Motorbike; loses to the Buggy.
_Avoid_: helicopter, chopper, gyro, plane

**Self-destruct**:
A Player's action that destroys their own Unit on purpose, so a stranded Unit can respawn.
_Avoid_: suicide, reset, respawn button

### Resources

**Fuel (benzín)**:
The resource every Unit burns while moving, the Gyrocopter fastest. A Unit with no Fuel can neither drive nor fly.
_Avoid_: gas, petrol, energy, stamina

**Fuel Can (kanister s benzínom)**:
A pickup on the Map that refills Fuel. Spawns at fixed places and respawns after being taken. Distinct from the Water Canister, although the source uses "kanister" for both.
_Avoid_: depot, jerrycan, gas can, canister (alone)

### World

**Map (mapa)**:
The single small arena of the First Playable. Holds both Bases and the fixed Fuel Can spawn points.
_Avoid_: level, arena, world, stage
