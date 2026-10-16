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
The flying combat Unit. It moves only in the high Height and never descends into the low one (the comments), at one constant flying height, its lowest point at 2.5 m (the Truck's pod, 2.2 m, plus a 0.25 m clearance, rounded up to 0.05 m; its thin antenna is not counted, so it is drawn through the gear of a Gyrocopter that flies right over a Truck; measured in story 015, set in story 020), from the moment it appears in the Garage, never rising, settling, taking off or landing (reading, 2026-10-10). Flying means that it crosses every low piece, which ground Units cannot: cliffs, water, the cover and every Wall Panel (the cover since the first playtest, 2026-10-03; the Flag Walls since the author's board of 2026-10-07; the other Wall Panels since 2026-10-10), and that no Mine goes off under it (the board). Every Tall piece stops it, the Turrets included, and one it flies straight into faster than its crash speed (starting at 4 m/s, about a quarter of its top speed; decided 2026-10-10) destroys it, and it explodes (the comments); a graze, a slow nudge or a turn on the spot against one only stops it, as before (decided 2026-10-10). It shoots and is shot at the same height as everyone, because every hit volume spans both Heights: no height advantage for fire (decided 2026-10-10); the Turrets fire at it (reading, 2026-10-07). Burns Fuel fastest and crashes when its tank is empty. Beats the Buggy from across cliffs and water; loses to the Truck.
_Avoid_: helicopter, chopper, gyro, plane

**Rotor (rotor)**:
One of the Gyrocopter's two turning parts (the developer's request of 2026-10-15, "I want some sort of animation for the gyrocopter spinning blades. Something smooth. Blurred is fine, but it needs to be recognizable enough."; built in story 025): its main rotor, two blades in the Team colour with darker tips, and its pusher propeller, three blades. Each turns about its own hub, as a picture only: the main rotor at a steady rate, 4 turns a second, and the propeller at a rate that follows the Unit's speed, 2 turns a second standing and 5 at its top speed, forward or in reverse (both starting values to tune). Each blade trails a Smear. A new Gyrocopter appears with both at rest, they stand still under the Round-over screen, and nothing a Round does reads them. The other three types have no turning part.
_Avoid_: blades (a rotor's parts), fan, spinner, helicopter blades

**Smear**:
The soft see-through fan a turning blade trails behind it over about a quarter of a turn (decided 2026-10-15: blades and a smear, not a blur disc that replaces the blades and not plain blades, which strobe at 60 ticks a second at any rate that looks fast; built in story 025): strongest at the blade, fading to nothing behind it, in the Team colour (the propeller's in its metal, with Team-coloured tips). It hides the step between two frames so that the two blades can always be counted. It casts no shadow, though the blades cast theirs and turn with them. A picture only.
_Avoid_: blur, motion blur, blur disc, trail, tyre track

**Token (token)**:
One Unit of one type in a Player's stock: a Player with five Motorbike Tokens can lose five Motorbikes. Each Player holds a stock per type, set by the Map (the rules source's example: Motorbike 5, Buggy 3, Truck 2, Gyrocopter 2). A Token is taken at the destruction of a Unit of its type, never at its spawn, so the Unit in play is not yet subtracted; a type with no Tokens left cannot be picked again, and a Player whose last Motorbike Token is gone has lost the Round.
_Avoid_: life, lives, credit, ticket, respawn, coin

**Garage (garáž)**:
The place at a Player's Base where the chosen Unit appears, at the start of a Round, after every destruction and after a Swap. It is the spawn point of stories 003 and 004. On Map 01 a new Unit appears on one of the Garage's two side spots, because the Flag Walls close the middle spot's lane to the Gate (reading, 2026-10-07), and no Mine can be laid in a Garage (decided 2026-10-07). Every new Unit appears there with a full tank and a full load of ammo (the comments; decided 2026-10-10). Its back wall and two side walls are Wall Panels (decided 2026-10-10) of its Base's Player (reading, 2026-10-10).
_Avoid_: spawn point, hangar, depot, pad

**Self-destruct**:
A Player's action that destroys their own Unit on purpose, so a stranded Unit can be replaced. It counts as a destruction and costs a Token. Like every destroyed Unit it explodes (the comments), and since every new Unit starts full, a Self-destruct trades a Token for a full tank and a full load of ammo (decided 2026-10-10). A Player whose ground Unit has run out of Fuel is shown the key. Inside the own Base the same key does the Swap instead (story 011), and a stranded Unit there is shown the key for that.
_Avoid_: suicide, reset, respawn button

**Explosion (výbuch)**:
The picture a destroyed Unit leaves behind it (the comments: "bolo by fajn aby znicene vozidlo vybuchlo"; built in story 016): a short flash, a fireball that swells and then shrinks and darkens, a few dark chunks thrown up and out and some grey smoke, for about 2 s, at the Unit's drawn model (a Gyrocopter's in the air), in both views, sized from the Unit's type and in no Team colour. It plays for every destruction a Round counts (the other Player's Shots, a Turret, a Mine, a Self-destruct, a Gyrocopter's Fuel crash and, from story 021, its crash into a Tall piece) and never for a Swap or a bench. It is only a picture: it damages, pushes and stops nothing, leaves no wreck, keeps playing under the Round-over screen and is freed at R; a Mine keeps its own short flash and the explosion plays with it.
_Avoid_: blast, splash damage, wreck, debris field, detonation

**Badly damaged**:
The state of a live Unit at or below a fraction of its own maximum hit points, the edge included (the comments: "ked maju napr 20% ze sa z nich dymi a idu pomalsie. O polovicu napr."; built in story 017): thin dark grey smoke rises from the top of its drawn body (a column while it stands, a short trail while it moves, in both views, in no Team colour) and its top speed, forward and in reverse, is a share of its own, eased in at the Unit's own acceleration. Both numbers are data per type, 0.2 and 0.5 to start (8 of 40, 20 of 100, 44 of 220 and 14 of 70 hit points); a fraction of 0 means a type has no such state. It is read from the hit points and ends only with the Unit (a destruction, a Swap or R), so the next Unit starts whole; it changes nothing else (turning, the weapon, the Fuel burn and the HUD stay, and in a Ford the lower cap wins). A Mine, a Self-destruct and the Gyrocopter's Fuel crash destroy at once and pass through no state.
_Avoid_: crippled, critical, on fire, damaged (a Flag Wall or a Turret is damaged; a Unit is badly damaged)

**Hit flash**:
The short white flash that shows a hit (decided 2026-10-15; story 030): a Unit, a Turret, a Wall Panel or a Flag Wall that a Shot damages and that survives flashes white over its whole drawn model for a few ticks, in both views. A Shot that takes nothing, and the lethal hit, show none. A picture only.
_Avoid_: blink, damage flash, hit marker

**Charring**:
The dark patches a Unit gathers as it loses hit points (decided 2026-10-15; story 030): they appear after its first losses and grow to their most at the badly damaged edge, about half of the body, so the Team colour still reads; a new Unit starts clean. Only Units char: a Turret, a Flag Wall or a Wall Panel shows its damage by its two damaged looks. A picture only.
_Avoid_: burning, on fire, damaged (a Turret or a wall is damaged), scorch mark

**Swap**:
Putting a Player's Unit away inside its own Base with the Self-destruct key, so the Player chooses another type at once and at no cost (story 011, decided 2026-10-03 after the first playtest). It is not a destruction: no Token is taken and no respawn delay runs, it takes no Flag with it, and the Unit put away does not explode (reading, 2026-10-10). It acts only on a Unit in play standing inside its own Base's walls, the Garage included, whatever its type; anywhere else the key destroys. The new Unit appears with full hit points, a full tank and a full load of ammo, so a Swap is also a free full resupply at the own Base (decided 2026-10-10).
_Avoid_: change, trade, repair

### Resources

**Fuel (benzín)**:
The resource every Unit burns, faster while moving than while standing, the Gyrocopter fastest. A Unit with no Fuel can neither drive nor fly. Every new Unit starts with a full tank, and Fuel refills only in a supply zone of the Fuel building, for a Unit that has stopped there (the comments; decided 2026-10-10); the Fuel Cans left Map 01 (decided 2026-10-10; built in story 023).
_Avoid_: gas, petrol, energy, stamina

**Ammo (munícia)**:
What a Unit's gun fires, counted in Shots (each Shot spends one): the second supply (zásoby) beside Fuel (the comments, which write "ammo"; the author's board calls it munícia). A full load is 20 s of continuous fire at the type's own rate: Motorbike 100 Shots, Buggy 50, Truck 25, Gyrocopter 40 (reading, 2026-10-10; per-type data, 0 meaning unlimited). Every new Unit starts with a full load (the comments; decided 2026-10-10), and ammo refills only in a supply zone of an ammunition building (the comments; decided 2026-10-10); story 022 built the load (2026-10-14) and story 024 builds the ammunition buildings, so until story 024 ammo comes back only with a new Unit (reading, 2026-10-10). A Unit with no ammo fires nothing but can still drive, carry the Flag and lay Mines, and its Player's view shows "Ammo n / max" while the Unit has a load, as the Mines line does, and a short "Out of ammo" notice at zero (reading, 2026-10-10). The Turrets never run out (the board: "nekonečná munícia"), and the Truck's Mines are not ammo (reading, 2026-10-10).
_Avoid_: rounds (a Round is the match; ammo is counted in Shots), bullets, magazine, clip, ammunition (but the ammunition building)

**Supply building (budova)**:
A building on the Map meant for one supply, with a supply zone right in front of it (the comments). Two kinds: the Fuel building, whose zones give Fuel only, and the ammunition building, whose zones give ammo only (decided 2026-10-10). Map 01 has one Fuel building, the depot at its centre, with a zone on each of its two Base-facing sides, and one ammunition building on each half of the Map, the two mirrored across the Map's centre line near the old salt-flat Fuel Can spots (decided 2026-10-10). A supply building never runs dry (decided 2026-10-10) and cannot be destroyed (reading, 2026-10-10). The Fuel building is the depot, whose three Fuel tanks stay Tall pieces; only the two new ammunition buildings are low, so the Gyrocopter flies over them (decided 2026-10-10). The ammunition buildings are greybox buildings from Godot's built-in meshes, and each stops ground Units and every Shot like a piece of cover, so it blocks a Turret's sight the same way (at its places on Map 01 nothing behind it is within a Turret's reach); it is a building, not Cover (reading, 2026-10-10; story 024 asks the author). Story 023 built the Fuel building on 2026-10-14: the depot's two Fuel zones are areas 6 x 6 m on the ground, marked in amber with a dashed edge, that give a Unit that has stopped in one (its real speed about zero; a hovering Gyrocopter counts) its whole tank over about 4 s. Story 024 built the two ammunition buildings on the same day: each a low store of crates on a plinth (4 x 6 m, 1.8 m tall, a static body on the cover layer, so ground Units and every Shot stop at it and a Turret's sight ray too, and the Gyrocopter flies over it) centred at (-64, 0, 14) and (64, 0, 14), with its ammunition zone of 6 x 6 m on the side facing the centre, marked in the Shots' pale yellow with a dashed edge, that gives a Unit that has stopped in it its Weapon's whole load over about 4 s, a whole Shot at a time.
_Avoid_: station, gas station, shop, pickup, armoury

**Supply zone (zóna)**:
The zone right in front of a supply building where a Unit's supplies refill while it stands there (the comments: "a zone where, while you stand there, your supplies are topped up"; the Slovak "kde keď stojí" is third person, read here with the Unit as the subject, as the translation notes of `design/source/wasteland-fire-comments-2026-10-10.en.md` allow). Only a Unit that has stopped in it refills, gradually, about 4 s from empty to full (data), and a hovering Gyrocopter counts as stopped; Units of both Players can refill at the same zone at once; a Fuel building's zone gives Fuel only, an ammunition building's ammo only (decided 2026-10-10). Stopped means that the Unit really is not moving, so one held against its building with the throttle still refills, and a zone reaches through both Heights (reading, 2026-10-10). No Mine can be laid in or around a supply zone (decided 2026-10-10; built in story 024: a lay is refused where any part of the Mine would lie in a zone or within 3.0 m of one, with "No Mines at a supply building" on that Player's notice line). Built for Fuel in story 023 as `SupplyZone` with its `SupplySettings` (4.0 s from empty to full, stopped means a real horizontal speed of at most 0.1 m/s); story 024 added the ammunition kind (`ammo_seconds_to_full` 4.0 s, through `Weapon.rearm()` of the Weapon whose Unit the zone lists).
_Avoid_: pad, refill area, trigger, pit stop, station

**Fuel Can (kanister)**:
A pickup on the Map that refills Fuel. Sits at fixed places and respawns after being taken. The rules source's word is kanister; now that the objective is the Flag, "canister" means only this. The nine Fuel Cans leave Map 01, with their respawn and their restock at R, and Fuel refills only in the Fuel building's supply zones (the comments; decided 2026-10-10; built in story 023). The entry stays for the history and for the older evidence scenarios, which keep their Cans: the evidence runner puts the frozen Cans back on Map 01 for them (reading, 2026-10-10).
_Avoid_: depot, jerrycan, gas can, water canister

### World

**Map (mapa)**:
A bounded playfield holding Base A, Base B, their Garages and the supply buildings (decided 2026-10-10; the fixed Fuel Can places left with story 023); it also sets each Player's Token stock. The First Playable has one, Map 01.
_Avoid_: level, arena, world, stage

**Gate**:
The one opening in a Base's wall, in the wall that faces the Map's centre; every ground Unit leaves and enters its Base through it while the Base's Wall Panels stand, and the Gyrocopter flies over them (decided 2026-10-10). On Map 01 about 11 m wide (drawn at 10 m and widened so the Truck clears it). Its Base's two Turrets stand outside it, one on each side, and no Mine can be laid in it or on the approach about 10 m in front of it (decided 2026-10-07). It stays the Base's built opening now that the Base's walls are Wall Panels: a fallen panel is a breach, not a Gate (reading, 2026-10-10).
_Avoid_: door, entrance, exit

**Turret (vežička)**:
A Base's automatic gun, owned by that Base's Player. It turns its barrel on its own and fires only at the other Player's Unit, and only when nothing stands in the way; no Player controls it, and it cannot be built or captured, only destroyed (the author's board, 2026-10-07). Map 01 has two outside each Gate, and while any Turret of a Base stands, the other Player cannot pick up that Base's Flag (decided 2026-10-07). It fires at the Gyrocopter too, a cliff hides a target from it although shots pass through cliffs, and a destroyed Turret stays down until the restart (reading, 2026-10-07). It is not a Unit: it never moves and has no Token. As built (story 013, 2026-10-08): a dark drum 2 m across and 1.8 m tall with a turning head, one band in its Player's Team colour and a barrel; 100 hit points; one Shot every 0.8 s, aimed where the target will be; and the line "Destroy the turrets first" in the view of a Player whose Motorbike touches a Flag that only the Turrets' lock keeps from them. Since 2026-10-10 it shows its damage like a Wall Panel (the comments): two damaged looks below 80% and 35% of its hit points, the drum darker and cracked like a damaged Flag Wall with chunks at its foot, the head and barrel darker, its band keeping its Team colour and its head still turning and firing (reading, 2026-10-10). It grows to about 3 m so that its head reaches the high Height, and it is a Tall piece (decided 2026-10-10); its aim, its sight and its Shot height stay, and story 015 sizes its head to overlap the flying Gyrocopter's drawn band, past 3 m only if the band needs it (reading, 2026-10-10). Its 100 hit points may still be tuned (the comments) and stay for now (reading, 2026-10-10). As built (story 015, 2026-10-11): about 3 m tall on the same 2 m footprint (the drum 2.2 m, the dome's top 3.0 m, the collider 3.0 m), its head overlapping the band the Gyrocopter's model will fly in (2.454 m to 4.256 m, measured from the mesh files); the two looks are a drum in the Flag Walls' damaged materials with 4 and then 8 chunks at its foot and a dome and barrel in two darker untextured steels, below 0.8 and 0.35 of its hit points (data).
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

**Tyre track**:
The mark a ground Unit's tyres leave as they roll (decided 2026-10-15; story 026): darker, packed ground with a shallow rut, as wide as the tyre, on the sand, the canyon road and the salt flat only, never in the water, the fords, on the Base pads or in the Garages. A mark holds and then fades out over about a minute, and every Round starts on clean ground. The Gyrocopter leaves none. Only a picture: nothing in a Round reads it. As built (story 026): each tick the Map's `TyreTracks` makes one stroke for each tyre of a ground Unit, from where the tyre touched the ground the tick before to where it touches it now, and draws it into the Map's track map; a mark holds its full strength for 20 s of the Round's time and fades over the next 40 s.
_Avoid_: tire track (the code and the docs spell it tyre), skid mark, trail

**Track map**:
The one texture over a Map's ground in which its tyre tracks are drawn (story 026): a half-float image of 4096 x 1284 pixels over Map 01's island (7.18 cm a pixel), each pixel holding the coverage of a mark and the Round's time it was made, cleared when a Round starts and read by the ground shader through four global shader parameters. A later stroke replaces an earlier one; nothing about it is a place a Round reads.
_Avoid_: decal, splat map, trail texture

**Cover**:
A static obstacle on the Map that stops every ground Unit and every shot and is never destroyed; the Gyrocopter flies over it (decided 2026-10-03, after the first playtest). On Map 01 the eight wrecks and the two long containers; the drawings' wrecks are cover, not destroyed Units. The two scrap walls were cover too until story 019 made them Wall Panels of no Player (decided 2026-10-10; built 2026-10-12); they are no longer Cover (reading, 2026-10-10). The depot's three Fuel tanks are not cover: they stop every Unit, the Gyrocopter included, as Tall pieces (decided 2026-10-10). Nor are the Wall Panels, the Flag Walls among them, although the Gyrocopter flies over them too: a Wall Panel can be destroyed (reading, 2026-10-10). Nor is an ammunition building, although it stops ground Units and every Shot like cover and the Gyrocopter flies over it: it is a building (reading, 2026-10-10; story 024). Nor are the Turrets (reading, 2026-10-07).
_Avoid_: obstacle, barricade, prop, destructible

**Height (výšková úroveň)**:
One of the two heights the Map's pieces and the Units are sorted into, low and high (the comments). The ground Units and the walls are in the low Height (the comments), and so is every low piece, which stops ground Units but not the Gyrocopter: the Wall Panels, the cover, the cliffs and the water (reading, 2026-10-10). The Gyrocopter flies in the high Height and never descends into the low one, and the Turrets' heads reach it (the comments), as does every Tall piece (decided 2026-10-10). Every hit volume spans both Heights (the comments), so every Unit still hits every Unit at the one shooting height, and a wall or a piece of cover between shooter and target stops the Shot, even one the Gyrocopter fires from above it: no height advantage for fire (decided 2026-10-10). Written with a capital to tell it from a height in metres, such as the 0.5 m shooting height or the Gyrocopter's flying height (2.5 m); in the code a Height is not a physics layer of its own (reading, 2026-10-10).
_Avoid_: level (a Round and a Map are never a level either), layer (the physics layers), floor, tier, altitude

**Tall piece (vysoká prekážka)**:
A piece of the Map that reaches the high Height, so it stops every Unit, the Gyrocopter included (the comments: "a high obstacle"). On Map 01 the corner towers, the water towers (the legs and the tank), the depot's three Fuel tanks and the Turrets, grown to about 3 m (decided 2026-10-10). The water tower's tank stands 8.3 m to 13.3 m up with no collider, above the flying Gyrocopter (whose model is drawn from 2.5 m to 4.3 m): in play only the legs meet it, and it flies between them under the tank (story 021, question 4). Each kind reaches into that band: the corner towers' colliders stand 6.0 m tall, the legs 8.0 m, the depot's tanks 3.0 m (drawn to 4.15 m) and the Turrets 3.0 m (drawn to 3.8 m). A Gyrocopter that flies straight into one faster than its crash speed (starting at 4 m/s, about a quarter of its top speed; data) is destroyed in that tick and explodes, a destruction like any other that takes a Token; a graze, a slow nudge or a turn on the spot against one only stops it (decided 2026-10-10); backing into one at its full reverse speed, 6 m/s, crashes it too, the speed being read along the collision's normal whichever way the Unit travels (story 021, question 6). The piece takes no damage from it, and the Map's invisible edge over the sea, which also stops the Gyrocopter, is not a Tall piece and never crashes it (reading, 2026-10-10). The Fuel building is the depot, whose three Fuel tanks are Tall pieces; only the two new ammunition buildings are low, so the Gyrocopter flies over them (decided 2026-10-10). Built in story 021 (2026-10-13): the crash speed is each type's `UnitStats.crash_speed` (4.0 m/s for the Gyrocopter, 0 for the others), met along the collision's normal by the Unit's real velocity of the previous tick, and the sea edge's bodies are told apart by the node group `map_edge`.
_Avoid_: high obstacle, tall obstacle, solid piece, wall

**View**:
What a Player's camera shows, one of two: the view from above (the Round's start: high over the Unit, almost straight down with a slight forward tilt, turning with the Unit; the tops of the water towers are not drawn in it, so the Flag on its seat stays in sight) or the chase view (from behind and above). Each Player switches their own with one key, at any time; the other Player's view does not change (decided 2026-10-03, after the first playtest, as a trial the friends compare in one playtest).
_Avoid_: camera mode, zoom, perspective

**Silhouette**:
A Player's own Unit drawn through what hides it (decided 2026-10-15; story 027): where a Turret, a wall, a tower, a building, the cover or a cliff hides part of that Unit, the hidden part shows over it as a flat see-through shape in the Team colour, in its own Player's view only, from above and in the chase view. The other Player's Unit is never drawn through anything, so cover still hides a Unit from the other Player, as the Turrets' line of sight assumes. A picture only.
_Avoid_: x-ray, outline, ghost, wallhack

**Red edge**:
The red pulse at the edges of a Player's half of the screen when that Player's Unit is hit or destroyed (decided 2026-10-15; story 031): it fades within a fraction of a second, shows in that Player's half only and stays under the HUD's band; never at a spawn, a Swap or a restart. A picture only.
_Avoid_: vignette, damage overlay, blood, hit flash (that is on the model)
