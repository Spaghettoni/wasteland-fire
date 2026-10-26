# Evidence: Story 061 (rockets and Map 03 Turrets)

Date: 2026-10-26 · Godot 4.7.2.

- `fire_heights` H8_looks PASS: a Unit's high Shots ["shot_rocket.tscn"], low ["shot.tscn"]; the Turret's (3, high over the panel among them) ["shot.tscn"]. H1–H7 PASS as before.
- `map_03` A6_the_turrets PASS: Turrets per Base [6, 6], armed [6, 6]. A1–A5 PASS.
- `rockets_showcase` (windowed, Vulkan, --write-movie): SPLIT moment rockets_and_shots at frame 39 (1 rocket, 1 yellow Shot). Frames: `story-061/rockets-01-launch.png`, `rockets-02-flight.png`, `rockets-03-zoom.png` (Player 1's Buggy, frames 39–54 enlarged).
- `story-061/map-03-turrets.png`: the map choice picture: 5 Turrets round each fortress, 1 by each Garage.
- Full regression: see the commit.
