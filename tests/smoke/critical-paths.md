# Smoke Test: Critical Paths

**Purpose**: Run these 10-15 checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches straight into the Map without crash (no main menu in the First Playable — `run/main_scene` is set once story 001 lands)
2. A new Round can be started (R on the Round-over screen, once story 004 lands)
3. Both keyboard layouts respond without freezing

## Core Mechanic (update per story)

<!-- Add the primary mechanic for each story here as it is implemented -->
4. [Story 001 — Motorbike drives with W/A/S/D, chase camera follows, 60 fps at 1280×720]
5. [Story 002 — two viewports, both Players drive at once]
6. [Story 004 — steal, drop, recover, deliver; Round-over screen]
7. [Story 008 — a destruction costs a Token of its type; the choice shows the counts and dims a type with none; the last Motorbike Token loses the Round; both Players losing it on one tick shows "Nobody wins!"]
8. [Story 009 — every Unit turns on the spot when standing; the depot's three Fuel tanks stop every Unit and every Shot; the Gyrocopter flies over the wrecks, containers and scrap walls while ground Units are stopped; a standing Unit's Fuel gauge falls slower than a moving one's; a ground Unit out of Fuel shows "Out of Fuel! Press Tab (Enter) to Self-destruct" in its own view]
9. [Story 012 — each Flag sits in a box of four Flag Walls: a Motorbike driven at any side is stopped and takes nothing; a Buggy (4 Shots), a Truck (2) or a Gyrocopter (3) breaks one and the Motorbike's Shots do nothing to it; a hit Flag Wall looks damaged (darker, cracked, chunks at its foot) from the first Shot of a Buggy, a Truck or a Gyrocopter, and worse below 35% of its hit points; through the gap the Motorbike is handed the Flag and can deliver it; a Gyrocopter flies over the walls; new Units appear on the Garage's two side spots, never the middle one]

10. [Story 013 — two Turrets stand outside each Gate, orange at Base A and teal at Base B: each turns its barrel on the other Player's Unit and fires ahead of it (a Motorbike crossing at speed 20 m off is hit every time), never at its own Player's Unit, and not at a Unit hidden behind a wall, the cover or a cliff; a Motorbike's Shots break one (20 Shots), a Buggy's 9, a Truck's 4, a Gyrocopter's 7, and a broken Turret is low rubble a Unit drives over; while either Turret of a Base stands the other Player's Motorbike on its Flag takes nothing and its view shows "Destroy the turrets first", and when the second falls the Flag is handed over at once; a Turret's kill costs a Token and a Carrier it destroys drops the Flag at the wreck; a Turret that kills a last Motorbike ends the Round]

11. [Story 014 — a Truck lays one Mine behind its tail with E (Player 1) or Comma (Player 2), five to a Truck, "Mines 4 / 5" in its Player's view only; a new Mine blinks in the Team colour for 3 s and is harmless, then shines steadily and is live; a live Mine destroys a Motorbike, a Buggy, a full Truck and the owner's own Truck at once, in a short flash, and never a Gyrocopter or a Shot; a press in or near a Base (the yard and about 10 m in front of a Gate), against a wall, the cover, a tank, a cliff or water lays nothing and says why on that Player's notice line for about 1.5 s; "No Mines left" after the fifth; a Mine stays when its Truck is destroyed or swapped; a Mine's kill costs a Token, drops a Carrier's Flag at the wreck and a last Motorbike lost ends the Round]

## Data Integrity

12. Restarting a Round resets Units, Flags, both Token stocks, HUD and every Flag Wall, Turret and Mine (R brings all eight Flag Walls back with 40 hit points and the whole look and all four Turrets back with 100 hit points, standing, solid, the barrel at rest and ready to fire; a fallen or damaged one stays as it is until then; every Mine, arming, live or flashing, is gone and the first Truck of the new Round comes with 5) (once story 014 lands)
13. Unit tuning values load from their `.tres` data, not code (once story 001 lands)

## Performance

14. No visible frame rate drops on the dev machine (60fps target, two viewports, with the Flag Walls and the Turrets in)
15. No memory growth over 5 minutes of play (once the core loop is implemented)
