# Wasteland Fire

A two-player split-screen 3D vehicle game in the style of Return Fire, set in a post-apocalyptic wasteland. Working title "Wasteland Fire", project folder `ronin-ya`. Private, for playing with friends at home. Rules of record: `design/rules.md`. Slovak terms from the rules source are given in parentheses.

## Language

### Effort scope

**First Playable**:
The first version worth sitting a friend down for; the rules source calls it version 0.1. Two Players, split screen, Map 01, four Units, Tokens, Fuel, the Flag, win by delivery or the opponent losing their last Motorbike, and a coherent low-poly look built from Godot's built-in meshes (the Units' models built in Blender by the repository's scripts since 2026-10-10).
_Avoid_: MVP, vertical slice, prototype, demo

**Game-Night Build**:
The version after the First Playable, charted as its own effort later. Holds everything the First Playable excludes. Not charted yet: meanwhile the work after the First Playable is filed in the First Playable epic, in sections after its eight stories (stories 009 to 011 after the first playtest, 012 to 014 since 2026-10-07; reading, 2026-10-07), and so are stories 015 to 024, after the author's comments of 2026-10-10 (reading, 2026-10-10).
_Avoid_: full game, v2, release, final, backlog

### Players and objective

**Player**:
One of the two humans in a Round. Each owns a Base, defends one Flag, holds a stock of Tokens and has a Team colour.
_Avoid_: user, team, squad

**Base (základňa)**:
A Player's home on the Map: Base A for Player 1 and Base B for Player 2 on Map 01. It holds that Player's Flag at the start of a Round, has the Garage where the Player's Units appear, and is where the opponent's Flag must be delivered to win. Its Player's two Turrets stand outside its Gate and four Flag Walls box in its Flag (decided 2026-10-07). Its walls, the back wall, the two side walls and the two Gate walls, and its Garage's walls become Wall Panels (the comments; decided 2026-10-10; stories 018 and 019 build them) of its Player (reading, 2026-10-10): the other Player can break them with any Unit but the Motorbike, and the Gyrocopter flies over them. Its corner towers are Tall pieces and stand all Round (decided 2026-10-10).
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
A controllable vehicle with hit points. Four types: the Motorbike, and the combat trio Buggy, Truck and Gyrocopter in a rock-paper-scissors triangle. A destroyed Unit costs one Token of its type; the Player then picks the next Unit from the remaining stock. A destroyed Unit explodes, however it was destroyed (the comments); the explosion is a picture only, which damages nothing near it and leaves no wreck (reading, 2026-10-10). Every new Unit starts with a full tank of Fuel and a full load of ammo (the comments; decided 2026-10-10: the first spawn, every respawn and every Swap). At or below 20% of its own maximum hit points (Motorbike 8, Buggy 20, Truck 44, Gyrocopter 14) a Unit is badly damaged: smoke rises from it and it moves at half its top speed (the comments; decided 2026-10-10: all four types, both numbers per-type data). The state lasts until the Unit is gone, destroyed or put away in a Swap, and changes nothing but its top speed and the smoke; in a Ford the lower cap wins (reading, 2026-10-10).
_Avoid_: vehicle, character, life, mech; for the badly damaged state, crippled, critical, on fire

**Motorbike (motorka)**:
The fast, weak Unit and the only one that can carry a Flag. It sits outside the combat triangle and deals and receives normal damage against every Unit type. Its shots cannot damage a Flag Wall (the author's board, 2026-10-07), nor any other Wall Panel (decided 2026-10-10). A Player who loses their last Motorbike loses the Round.
_Avoid_: bike, jeep, cycle

**Buggy (bugina)**:
The agile combat Unit. Beats the Truck by circling it faster than the Truck can turn; loses to the Gyrocopter.
_Avoid_: armed buggy, car, tank, dune buggy

**Truck (truck)**:
The heavy, slow combat Unit with the most hit points and the hardest hits. Beats the Gyrocopter in a few hits; loses to the Buggy. The only Unit that lays Mines, 5 per Truck (the author's board, 2026-10-07). Its Mines are not ammo: every new Truck brings 5, and an ammunition building never refills them (reading, 2026-10-10).
_Avoid_: lorry, tank, van, heavy

**Gyrocopter (gyrokoptéra)**:
The flying combat Unit. It moves only in the high Height and never descends into the low one (the comments), at one constant flying height, its lowest point at about 2.5 m (the Truck's pod plus a clearance; its thin antenna is not counted; measured in story 015, set in story 020), from the moment it appears in the Garage (reading, 2026-10-10). Flying means that it crosses every low piece, which ground Units cannot: cliffs, water, the cover and every Wall Panel (the cover since the first playtest, 2026-10-03; the Flag Walls since the author's board of 2026-10-07; the other Wall Panels since 2026-10-10), and that no Mine goes off under it (the board). Every Tall piece stops it, the Turrets included, and one it flies straight into faster than its crash speed (starting at 4 m/s, about a quarter of its top speed; decided 2026-10-10) destroys it, and it explodes (the comments); a graze, a slow nudge or a turn on the spot against one only stops it, as before (decided 2026-10-10). It shoots and is shot at the same height as everyone, because every hit volume spans both Heights: no height advantage for fire (decided 2026-10-10); the Turrets fire at it (reading, 2026-10-07). Burns Fuel fastest and crashes when its tank is empty. Beats the Buggy from across cliffs and water; loses to the Truck.
_Avoid_: helicopter, chopper, gyro, plane

**Token (token)**:
One Unit of one type in a Player's stock: a Player with five Motorbike Tokens can lose five Motorbikes. Each Player holds a stock per type, set by the Map (the rules source's example: Motorbike 5, Buggy 3, Truck 2, Gyrocopter 2). A Token is taken at the destruction of a Unit of its type, never at its spawn, so the Unit in play is not yet subtracted; a type with no Tokens left cannot be picked again, and a Player whose last Motorbike Token is gone has lost the Round.
_Avoid_: life, lives, credit, ticket, respawn, coin

**Garage (garáž)**:
The place at a Player's Base where the chosen Unit appears, at the start of a Round, after every destruction and after a Swap. It is the spawn point of stories 003 and 004. On Map 01 a new Unit appears on one of the Garage's two side spots, because the Flag Walls close the middle spot's lane to the Gate (reading, 2026-10-07), and no Mine can be laid in a Garage (decided 2026-10-07). Every new Unit appears there with a full tank and a full load of ammo (the comments; decided 2026-10-10). Its back wall and two side walls are Wall Panels (decided 2026-10-10) of its Base's Player (reading, 2026-10-10).
_Avoid_: spawn point, hangar, depot, pad

**Self-destruct**:
A Player's action that destroys their own Unit on purpose, so a stranded Unit can be replaced. It counts as a destruction and costs a Token. Like every destroyed Unit it explodes (the comments), and since every new Unit starts full, a Self-destruct trades a Token for a full tank and a full load of ammo (decided 2026-10-10). A Player whose ground Unit has run out of Fuel is shown the key. Inside the own Base the same key does the Swap instead (story 011), and a stranded Unit there is shown the key for that.
_Avoid_: suicide, reset, respawn button

**Swap**:
Putting a Player's Unit away inside its own Base with the Self-destruct key, so the Player chooses another type at once and at no cost (story 011, decided 2026-10-03 after the first playtest). It is not a destruction: no Token is taken and no respawn delay runs, it takes no Flag with it, and the Unit put away does not explode (reading, 2026-10-10). It acts only on a Unit in play standing inside its own Base's walls, the Garage included, whatever its type; anywhere else the key destroys. The new Unit appears with full hit points, a full tank and a full load of ammo, so a Swap is also a free full resupply at the own Base (decided 2026-10-10).
_Avoid_: change, trade, repair

### Resources

**Fuel (benzín)**:
The resource every Unit burns, faster while moving than while standing, the Gyrocopter fastest. A Unit with no Fuel can neither drive nor fly. Every new Unit starts with a full tank, and Fuel refills only in a supply zone of the Fuel building, for a Unit that has stopped there (the comments; decided 2026-10-10); the Fuel Cans leave Map 01 (decided 2026-10-10; story 023 removes them).
_Avoid_: gas, petrol, energy, stamina

**Ammo (munícia)**:
What a Unit's gun fires, counted in Shots (each Shot spends one): the second supply (zásoby) beside Fuel (the comments, which write "ammo"; the author's board calls it munícia). A full load is 20 s of continuous fire at the type's own rate: Motorbike 100 Shots, Buggy 50, Truck 25, Gyrocopter 40 (reading, 2026-10-10; per-type data, 0 meaning unlimited). Every new Unit starts with a full load (the comments; decided 2026-10-10), and ammo refills only in a supply zone of an ammunition building (the comments; decided 2026-10-10); story 022 builds the load and story 024 the ammunition buildings, so until story 024 ammo comes back only with a new Unit (reading, 2026-10-10). A Unit with no ammo fires nothing but can still drive, carry the Flag and lay Mines, and its Player's view shows "Ammo n / max" while the Unit has a load, as the Mines line does, and a short "Out of ammo" notice at zero (reading, 2026-10-10). The Turrets never run out (the board: "nekonečná munícia"), and the Truck's Mines are not ammo (reading, 2026-10-10).
_Avoid_: rounds (a Round is the match; ammo is counted in Shots), bullets, magazine, clip, ammunition (but the ammunition building)

**Supply building (budova)**:
A building on the Map meant for one supply, with a supply zone right in front of it (the comments). Two kinds: the Fuel building, whose zones give Fuel only, and the ammunition building, whose zones give ammo only (decided 2026-10-10). Map 01 has one Fuel building, the depot at its centre, with a zone on each of its two Base-facing sides, and one ammunition building on each half of the Map, the two mirrored across the Map's centre line near the old salt-flat Fuel Can spots (decided 2026-10-10). A supply building never runs dry (decided 2026-10-10) and cannot be destroyed (reading, 2026-10-10). The Fuel building is the depot, whose three Fuel tanks stay Tall pieces; only the two new ammunition buildings are low, so the Gyrocopter flies over them (decided 2026-10-10). The ammunition buildings are greybox buildings from Godot's built-in meshes, and each stops ground Units and every Shot like a piece of cover, so it blocks a Turret's sight the same way (at its places on Map 01 nothing behind it is within a Turret's reach); it is a building, not Cover (reading, 2026-10-10; story 024 asks the author). Story 023 builds the Fuel building, story 024 the ammunition buildings.
_Avoid_: station, gas station, shop, pickup, armoury

**Supply zone (zóna)**:
The zone right in front of a supply building where a Unit's supplies refill while it stands there (the comments: "a zone where, while you stand there, your supplies are topped up"; the Slovak "kde keď stojí" is third person, read here with the Unit as the subject, as the translation notes of `design/source/wasteland-fire-comments-2026-10-10.en.md` allow). Only a Unit that has stopped in it refills, gradually, about 4 s from empty to full (data), and a hovering Gyrocopter counts as stopped; Units of both Players can refill at the same zone at once; a Fuel building's zone gives Fuel only, an ammunition building's ammo only (decided 2026-10-10). Stopped means that the Unit really is not moving, so one held against its building with the throttle still refills, and a zone reaches through both Heights (reading, 2026-10-10). No Mine can be laid in or around a supply zone (decided 2026-10-10; story 024).
_Avoid_: pad, refill area, trigger, pit stop, station

**Fuel Can (kanister)**:
A pickup on the Map that refills Fuel. Sits at fixed places and respawns after being taken. The rules source's word is kanister; now that the objective is the Flag, "canister" means only this. The nine Fuel Cans leave Map 01, with their respawn and their restock at R, and Fuel refills only in the Fuel building's supply zones (the comments; decided 2026-10-10; story 023 removes them). The entry stays for the history and for the older evidence scenarios, which keep their Cans: the evidence runner puts the frozen Cans back on Map 01 for them (reading, 2026-10-10).
_Avoid_: depot, jerrycan, gas can, water canister

### World

**Map (mapa)**:
A bounded playfield holding Base A, Base B, their Garages and the supply buildings (decided 2026-10-10; the fixed Fuel Can places until story 023 removes the Cans); it also sets each Player's Token stock. The First Playable has one, Map 01.
_Avoid_: level, arena, world, stage

**Gate**:
The one opening in a Base's wall, in the wall that faces the Map's centre; every ground Unit leaves and enters its Base through it while the Base's Wall Panels stand, and the Gyrocopter flies over them (decided 2026-10-10). On Map 01 about 11 m wide (drawn at 10 m and widened so the Truck clears it). Its Base's two Turrets stand outside it, one on each side, and no Mine can be laid in it or on the approach about 10 m in front of it (decided 2026-10-07). It stays the Base's built opening now that the Base's walls are Wall Panels: a fallen panel is a breach, not a Gate (reading, 2026-10-10).
_Avoid_: door, entrance, exit

**Turret (vežička)**:
A Base's automatic gun, owned by that Base's Player. It turns its barrel on its own and fires only at the other Player's Unit, and only when nothing stands in the way; no Player controls it, and it cannot be built or captured, only destroyed (the author's board, 2026-10-07). Map 01 has two outside each Gate, and while any Turret of a Base stands, the other Player cannot pick up that Base's Flag (decided 2026-10-07). It fires at the Gyrocopter too, a cliff hides a target from it although shots pass through cliffs, and a destroyed Turret stays down until the restart (reading, 2026-10-07). It is not a Unit: it never moves and has no Token. As built (story 013, 2026-10-08): a dark drum 2 m across and 1.8 m tall with a turning head, one band in its Player's Team colour and a barrel; 100 hit points; one Shot every 0.8 s, aimed where the target will be; and the line "Destroy the turrets first" in the view of a Player whose Motorbike touches a Flag that only the Turrets' lock keeps from them. Since 2026-10-10 it shows its damage like a Wall Panel (the comments): two damaged looks below 80% and 35% of its hit points, the drum darker and cracked like a damaged Flag Wall with chunks at its foot, the head and barrel darker, its band keeping its Team colour and its head still turning and firing (reading, 2026-10-10). It grows to about 3 m so that its head reaches the high Height, and it is a Tall piece (decided 2026-10-10); its aim, its sight and its Shot height stay, and story 015 sizes its head to overlap the flying Gyrocopter's drawn band, past 3 m only if the band needs it (reading, 2026-10-10). Its 100 hit points may still be tuned (the comments) and stay for now (reading, 2026-10-10).
_Avoid_: tower, gun tower, sentry, cannon

**Wall Panel (múr)**:
A breakable panel of the Flag Walls' kind: the author's múr, which the comments ask for in place of every wall on the Map. Every wall on Map 01 becomes one (decided 2026-10-10; stories 018 and 019 build them): both Bases' walls (the back wall, the two side walls and the two Gate walls), both Garages' walls (the back and the two sides) and the two scrap walls in the field, beside the Flag Walls, the four around each Flag, which are Wall Panels already. A Wall Panel is a low piece 2 m tall with 40 hit points; it looks damaged below 80% and again below 35% of them, falls into low rubble at 0, ignores the Motorbike's Shots, stops ground Units and every Shot while it stands, lets the Gyrocopter fly over it and stands again at the restart (R) (decided 2026-10-10). A Base's and its Garage's panels belong to that Base's Player, whose own Shots and Turrets never damage them, while the scrap walls' panels belong to no Player and both Players' Shots break them; a fallen panel is a breach, not a Gate (reading, 2026-10-10). The corner towers are not Wall Panels: they are Tall pieces and stand all Round (decided 2026-10-10).
_Avoid_: wall on its own, destructible wall, barricade, fence, segment

**Flag Wall (zničiteľný múr)**:
One of the four low panels that close the gaps between a Base's water-tower legs, a box around its Flag (decided 2026-10-07): the Flag Walls are the four Wall Panels around each Flag (reading, 2026-10-10). It has few hit points, looks damaged as it loses them, in two steps, and falls apart when they are gone (decided 2026-10-08); every Unit but the Motorbike can break it, because it ignores the Motorbike's damage; the Gyrocopter flies over it (the author's board, 2026-10-07). It stops ground Units and shots, and a broken Flag Wall stays down until the restart (reading, 2026-10-07, kept on 2026-10-08). It is not Cover. Until 2026-10-10 it was also told apart from the Base walls, which were never destroyed; since then every wall on Map 01 becomes a Wall Panel of its kind (the comments; decided 2026-10-10; stories 018 and 019 build them).
_Avoid_: barricade, fence, destructible wall, wall on its own

**Mine (mína)**:
A charge that only the Truck lays, 5 per Truck. For about 3 s it blinks in its owner's Team colour and is harmless; then it shines and is live, and it destroys at once any ground Unit that drives onto it, its owner's included; the Gyrocopter never sets it off (the author's board, 2026-10-07). It cannot be laid in or near a Base (decided 2026-10-07), nor in or around a supply zone, where a lay is refused like one on a Gate approach, with a short reason on that Player's notice line (decided 2026-10-10). It is laid just behind the Truck; every new Truck, after a spawn or a Swap, comes with 5; and a Mine lies until it goes off or the restart (reading, 2026-10-07). One key lays it, E for Player 1 and Comma for Player 2, and that Player's view shows the Mines left, "Mines 3 / 5", while a Truck is in play (story 014). Mines are not ammo: an ammunition building never refills them (reading, 2026-10-10).
_Avoid_: bomb, trap, landmine, explosive

**Ford**:
A shallow creek crossing on the Map. A ground Unit inside a Ford drives at no more than a fraction of its top speed (Map 01: half, a starting value to tune); the Gyrocopter crosses at full speed. Map 01 has two, across the salt flat between the canyon and the ridge.
_Avoid_: creek, river, mud, shallows

**Cover**:
A static obstacle on the Map that stops every ground Unit and every shot and is never destroyed; the Gyrocopter flies over it (decided 2026-10-03, after the first playtest). On Map 01 the eight wrecks and the two long containers; the drawings' wrecks are cover, not destroyed Units. The two scrap walls are cover too until story 019 makes them Wall Panels (decided 2026-10-10); then they stop being Cover (reading, 2026-10-10). The depot's three Fuel tanks are not cover: they stop every Unit, the Gyrocopter included, as Tall pieces (decided 2026-10-10). Nor are the Wall Panels, the Flag Walls among them, although the Gyrocopter flies over them too: a Wall Panel can be destroyed (reading, 2026-10-10). Nor is an ammunition building, although it stops ground Units and every Shot like cover and the Gyrocopter flies over it: it is a building (reading, 2026-10-10; story 024). Nor are the Turrets (reading, 2026-10-07).
_Avoid_: obstacle, barricade, prop, destructible

**Height (výšková úroveň)**:
One of the two heights the Map's pieces and the Units are sorted into, low and high (the comments). The ground Units and the walls are in the low Height (the comments), and so is every low piece, which stops ground Units but not the Gyrocopter: the Wall Panels, the cover, the cliffs and the water (reading, 2026-10-10). The Gyrocopter flies in the high Height and never descends into the low one, and the Turrets' heads reach it (the comments), as does every Tall piece (decided 2026-10-10). Every hit volume spans both Heights (the comments), so every Unit still hits every Unit at the one shooting height, and a wall or a piece of cover between shooter and target stops the Shot, even one the Gyrocopter fires from above it: no height advantage for fire (decided 2026-10-10). Written with a capital to tell it from a height in metres, such as the 0.5 m shooting height or the Gyrocopter's flying height; in the code a Height is not a physics layer of its own (reading, 2026-10-10).
_Avoid_: level (a Round and a Map are never a level either), layer (the physics layers), floor, tier, altitude

**Tall piece (vysoká prekážka)**:
A piece of the Map that reaches the high Height, so it stops every Unit, the Gyrocopter included (the comments: "a high obstacle"). On Map 01 the corner towers, the water towers (the legs and the tank), the depot's three Fuel tanks and the Turrets, grown to about 3 m (decided 2026-10-10). The water tower's tank stands 8.3 m to 13.3 m up with no collider, above the flying Gyrocopter: in play only the legs meet it (story 021, question 4). A Gyrocopter that flies straight into one faster than its crash speed (starting at 4 m/s, about a quarter of its top speed; data) is destroyed in that tick and explodes, a destruction like any other that takes a Token; a graze, a slow nudge or a turn on the spot against one only stops it (decided 2026-10-10). The piece takes no damage from it, and the Map's invisible edge over the sea, which also stops the Gyrocopter, is not a Tall piece and never crashes it (reading, 2026-10-10). The Fuel building is the depot, whose three Fuel tanks are Tall pieces; only the two new ammunition buildings are low, so the Gyrocopter flies over them (decided 2026-10-10).
_Avoid_: high obstacle, tall obstacle, solid piece, wall

**View**:
What a Player's camera shows, one of two: the view from above (the Round's start: high over the Unit, almost straight down with a slight forward tilt, turning with the Unit; the tops of the water towers are not drawn in it, so the Flag on its seat stays in sight) or the chase view (from behind and above). Each Player switches their own with one key, at any time; the other Player's view does not change (decided 2026-10-03, after the first playtest, as a trial the friends compare in one playtest).
_Avoid_: camera mode, zoom, perspective
