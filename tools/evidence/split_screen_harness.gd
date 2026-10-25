extends Node
## Evidence harness runner for the split screen launch scene (Story 002, and the scenarios Story 003 adds):
## runs one named scenario against split_screen.tscn and prints machine-readable lines, so the acceptance
## criteria are backed by a run.
##
## Implements: production/epics/wasteland-fire/story-002-split-screen.md, Acceptance Criteria and Test
## Evidence. Tooling only: nothing under src/ depends on this file; it couples to src/ by instancing
## split_screen.tscn and reading the exported members of SplitScreen.
##
## Scenarios, chosen with --scenario=NAME (after the "--"): layout, isolation, simultaneous, showcase, fps,
## bases, destruction, countdown, respawn_showcase, flag_run, hud, round_over, flag_showcase
## and, since Story 005, units, weapons, gyro, choice and units_showcase; since Story 006, fuel,
## fuel_cans and fuel_showcase; since Story 007, on Map 01, map_layout, map_edges, map_ford,
## map_bases, map_cover, map_showcase, map_legibility and map_fps; since Story 008, tokens,
## tokens_data, token_choice, loss, token_ui, token_layout and tokens_showcase; since Story 009, the
## scenarios its evidence doc lists; since Story 010, camera_views, camera_showcase and camera_smooth
## (windowed), and map_fps now runs on the shipped camera; since Story 011, unit_swap and
## unit_swap_showcase (windowed); since Story 012, flag_walls and flag_walls_showcase (windowed); since
## Story 013, turrets, turrets_showcase and turrets_fps (windowed); since Story 014, mines and
## mines_showcase (windowed); since Story 015, turret_looks, turret_looks_showcase and
## turret_looks_fps (windowed); since Story 016, explosions, explosions_off, explosions_showcase and
## explosions_fps (windowed); since Story 017, badly_damaged, badly_damaged_off, badly_damaged_showcase and
## badly_damaged_fps (windowed); since Story 018, base_walls and base_walls_showcase (windowed); since Story
## 019, garage_scrap_walls and garage_scrap_walls_showcase (windowed); since Story 020, heights and heights_showcase
## (windowed); since Story 021, crash and crash_showcase (windowed); since Story 022, ammo, ammo_alone and
## ammo_showcase (windowed); since Story 023, fuel_building, fuel_building_showcase and fuel_building_fps
## (windowed); since Story 024, ammo_buildings, ammo_buildings_showcase and ammo_buildings_fps
## (windowed); since Story 032, pads, pads_data and pads_showcase
## (windowed); since Story 036, resource_bars and resource_bars_showcase (windowed);
## since Story 037, turret_flying_sight and cliff_tops; since Story 038, map_02, bushes, cover_pieces and map_02_showcase (windowed); since Story 039, flag_open; since Story 040, pads_stick; since Story 041, fire_heights and fire_heights_showcase (windowed); since Story 042, secondary; since Story 043, real_flag; since Stories 042 and 043, secondary_flag_showcase (windowed); since Story 044, recharge_showcase (windowed); since Story 047, pad_back and shadow_showcase (windowed); since Story 048, teams, teams_three and teams_showcase (windowed); since Story 049, full_throttle and turret_reach_showcase (windowed); since Story 050, chase_view, chase_showcase and chase_showcase_two (windowed); since Story 051, hud_showcase (windowed); since Story 052, teams_last_carrier; since Story 054, map_03 and map_03_showcase (windowed). Each is a script under tools/evidence/split_screen/,
## a RefCounted with `func run(harness: Node) -> void`, a coroutine this runner awaits; its top says what it
## proves and how to run it. SCENARIOS maps the name to the script, so a new scenario is a script and one
## line there. A scenario reaches this script, DriveStep, UnitTrack and check_kit.gd through preload
## constants (nothing under tools/ declares a class_name, so they are PascalCase: the style guide's exception to
## SCREAMING_SNAKE for a constant that holds a class) and uses only the public members below.
##
## The harness plays the keyboard: every drive command is a real InputEventKey pushed through
## Input.parse_input_event with the physical keycode of the key, so the Input Map, PlayerDriveInput and
## the Unit run as under a real keyboard. Gameplay code names actions, never keys; tools are the only place
## key codes appear. Events carry InputEvent.DEVICE_ID_KEYBOARD (16), the id Godot 4.7 gives a keyboard, and
## Input.use_accumulated_input is off, so an event acts at once (measured on 4.7.2; Story 002 evidence doc).
## A window that loses focus makes the engine release every pressed key, so the runner checks its
## record of held keys against the engine's (Input.is_physical_key_pressed()) in set_key() and
## after every tick, and presses a dropped key again (TD-009); a headless run never loses focus.
##
## Time is simulated: scenarios await the physics_frame signal and count ticks, so the numbers are the same
## at any frame rate and a headless --fixed-fps 60 run is faster than real time. The continuation after
## physics_frame runs before the nodes' _physics_process of that tick (measured on 4.7.2), so a key pressed
## there reaches PlayerDriveInput in the same tick and what is read there is the previous tick.
##
## The Unit choice (Story 005): a Round now starts with both Units benched and both Players choosing
## a type, and a destroyed Unit comes back only once its Player has chosen again. The runner is the
## one place that makes the choice for a scenario, with real presses of the fire keys: before run()
## it confirms the type at the cursor's start, the Motorbike, for both Players and waits until both
## Units are in play (confirm_choices(); raw physics_frame awaits that do not count in ticks, so a
## scenario still starts at t=0 with both Units on their spawn points), unless the scenario script
## declares const OWN_CHOICE: bool = true; and for the scenarios written before the choice existed
## (LEGACY_SCENARIOS) it makes the choice again after every destruction, the first type of the data,
## by the controller's own choose() and with no key (an injected key acts one tick later, measured
## on 4.7.2 (the Story 005 evidence doc keeps the run), and a fire key still down on the tick the
## Unit appears fires its weapon; the direct call is in before any due frame), so their respawns
## come after the delay exactly as before the choice existed. Each fire key the runner holds for
## confirm_choices() is released on the tick the controller accepts the choice, so it is up again
## before the Unit appears a tick or more later (the bench settle), and no stray shot is fired at a
## spawn. A scenario of Story 005 or later chooses with its own keys after a destruction; round_over
## and flag_showcase, which restart the Round, call confirm_choices() after the restart key. The
## legacy scenarios also run on the data they were measured with (_apply_legacy_data(), on the
## shared resources before the scene is instanced): the Motorbike's placeholder 100 hit points, the
## debug damage of 25 and the Motorbike's old collision mask, which the shipped data changed in
## Story 005 (40 hit points, the debug keys off, the cliffs_water layer in the mask); a scenario of
## Story 005 or later runs on the shipped data. Since Story 006 the legacy scenarios and those of
## Story 005 (STORY_005_SCENARIOS) also run with no Fuel burn (_apply_no_fuel_data(): every type's
## fuel_use is LEGACY_FUEL_USE, zero, on the same shared resources), a guard for a run long enough
## for the shipped burn rate to empty a tank and stop or crash its Unit; their Units still get a
## tank at every spawn, and a scenario of Story 006 or later runs on the shipped Fuel data.
##
## The Map (Story 007). The launch scene's World now holds Map 01 as its first child (the node
## Map, src/gameplay/maps/map_01/map_01.tscn), and every scenario written before it was measured
## on the 80 m greybox composition: the greybox field with its two Bases, the terrain stand-ins
## and the five greybox Fuel Cans. For those (GREYBOX_SCENARIOS) the runner rebuilds that
## composition inside the freshly instanced launch scene, before it enters the tree and begins the
## Round (_apply_greybox_composition()), with the nodes, names and tree order their outputs were
## measured with, and gives every Unit type back its greybox model (_apply_greybox_models(), on
## the shared UnitStats before the scene is instanced), so the outputs stay what they were; a
## scenario of Story 007 or later is not listed and runs on Map 01. A scenario script may declare
## const WATCHDOG_SECONDS: float, in simulated seconds, for a watchdog of its own when a run across
## Map 01 needs longer.
##
## The Token stock (Story 008). A Round now ends by a loss when a Player's last Motorbike Token is
## spent, and Map 01's stock holds five. The scenarios written before it destroy Units over and over
## and choose the Motorbike again every time (destruction.gd destroys Player 1's Unit 18 times in
## one run: its RESULT line prints unit_destroyed=18/4), so the Map's stock would end those Rounds
## by a loss and change their outputs. As with the legacy Motorbike data, the runner therefore gives
## the launch scene a Token stock of its own before the scene enters the tree (_apply_token_stock(),
## on the field's token_stock only, never on the shared .tres): a scenario script that declares
## const STOCK_COUNTS: Dictionary (type_id to count) gets a TokenStock built from it; one that
## declares const USE_MAP_STOCK: bool = true keeps the Map's own stock; every other scenario gets
## LEGACY_TOKEN_COUNT of every type of match_rules.tres. A stock is built in code with
## TokenStock.new() and one assignment per key, because an untyped Dictionary assigned to counts is
## a script error and Resource.duplicate() of the shipped stock would share its counts dictionary
## (TokenStock's class doc).
##
## The playtest fixes (Story 009). The shipped data now turns a standing Unit on the spot
## (UnitStats.spot_turn_rate), burns Fuel while it stands (fuel_use_idle), stops Shots at a new
## cover layer (MatchRules.shot_collision_mask) and, on Map 01, puts the cover on that layer, so the
## Gyrocopter flies over it, and gives the depot's three tanks colliders. Every scenario written
## before Story 009 (GREYBOX_SCENARIOS and PRE_009_MAP_SCENARIOS) runs on the data it was measured
## with, as the legacy scenarios do: the runner sets the spot turn rate and the idle Fuel rate of
## every type to zero and the Shot mask back to its old value on the shared resources before the
## scene is instanced (_apply_pre_009_data()), and for the Map 01 ones it puts the cover back on the
## map layer and frees the tanks' colliders in the freshly instanced launch scene
## (_apply_pre_009_map()). A scenario of Story 009 or later is not listed and runs on the shipped
## data and Map.
##
## The camera (Story 010). The launch scene's cameras now start in the view from above, and every
## scenario written before it was measured on the chase view of Stories 001 to 009, whose settings
## are the second view of each Player's list. The runner therefore gives both cameras that chase
## settings before the scene enters the tree (_apply_chase_camera(): the instanced scene's
## ChaseCamera.settings, never the shared .tres), unless the scenario script declares
## const SHIPPED_CAMERA: bool = true, which keeps the camera the build ships with. A scenario of
## Story 010 declares it; any other scenario, now and later, runs on the chase view.
##
## The swap (Story 011). The shipped rules now swap a Unit at its own Base when its Player presses
## Self-destruct there (MatchRules.own_base_swap), and the scenarios written before it Self-destruct
## Units standing in their own Garage and count the destruction. The runner therefore turns the swap
## off on the shared match_rules.tres before the scene is instanced (_apply_swap_off()), unless the
## scenario script declares const OWN_BASE_SWAP: bool = true, which keeps the rules the build ships
## with. A scenario of Story 011 declares it; any other scenario, now and later, runs with the swap
## off. The Map's Base zones watch the gyrocopters layer now: no older output changed with that.
##
## The Flag Walls (Story 012). Map 01's Bases now close a box of four Flag Walls around their Flag
## (the Structures under each Base's Defences node, listed in its structures) and put a Unit on
## the Garage's side spots, not the middle one. Every scenario written before it was measured
## without them. The runner therefore strips them in the freshly instanced launch scene, before
## it enters the tree (_apply_defences_off()), unless the scenario script declares
## const BASE_DEFENCES: bool = true, which keeps the Map as it ships: each Map Base's Defences
## node is removed and freed at once, with its entries of color_meshes and structures dropped from
## those lists (a NodePath export is resolved to nodes when the scene is instanced, so a freed
## entry would be walked), and the Story 007 spots are given back (SpawnPoint with the two side
## spots as its spares). Only what stands under Defences is stripped, so a piece that a later story
## lists from elsewhere stays listed. A Base with no Defences node is left alone: the greybox
## composition has freed the Map before this runs, and its Bases keep their own spawn assignment.
## A scenario of Story 012 declares it; any other scenario, now and later, runs without the
## Flag Walls.
##
## The Turrets (Story 013). Map 01's Bases now stand two Turrets outside the Gate (the Structures
## under each Base's Turrets node, listed in its structures, each with an accent in its color_meshes)
## and each Player's view has a PlayerNotice Label. They change what a scenario sees (a Turret fires
## at the other Player's Unit, and while one stands the other Player cannot take the Flag), so the
## runner strips them from the freshly instanced launch scene, before it enters the tree
## (_apply_turrets_off()), unless the scenario script declares const TURRETS: bool = true: each Map
## Base's Turrets node is removed and freed, with its entries of color_meshes and structures dropped
## from those lists, and both PlayerNotice Labels are freed (camera_views counts every Control in
## each view). It is a constant of its own beside BASE_DEFENCES because the scenarios of Story 012
## declare BASE_DEFENCES and keep their outputs, which standing Turrets would change. Each strip
## takes out only its own pieces. A Base with no Turrets node is left alone (the greybox
## composition has none); there only the Labels go. The Labels are kept only by declaring TURRETS
## (and, from Story 014, MINES). A scenario of Story 013 declares it, with BASE_DEFENCES when it
## needs the Flag Walls and the side spawn spots; any other scenario runs without the Turrets.
##
## The Mines (Story 014). Every Player's view now has a MineCount Label and the Truck carries Mines
## (UnitStats.mine_capacity 5), and a lay key is part of the Input Map. A scenario written before it
## was measured with none of that, so the runner takes the Mines out before the scene enters the
## tree unless the scenario script declares const MINES: bool = true: every UnitStats of
## match_rules.tres's unit_types gets mine_capacity 0 on the shared resources before the scene is
## instanced (_apply_mines_off(): no type lays one, so no MineLayer ever emits or lays), and both
## MineCount Labels are freed in the instanced scene (_apply_mine_counts_off(): camera_views counts
## every Control in each view). The MineLayers and the lay inputs stay, inert. The PlayerNotice
## Labels follow the rule of Story 013, extended: they stay for a scenario that declares TURRETS or
## MINES and are freed for one that declares neither, while the Turrets stay only for TURRETS, so a
## scenario of Story 014 that needs the Turrets declares TURRETS as well. Each opt-in keeps only
## its own pieces.
##
## The Turret's looks (Story 015). The shipped Turret now grows to about 3 m and shows two damaged
## looks below the fractions of turret_stats.tres (damaged_below). The scenarios that keep the
## Turrets (turrets, turrets_showcase, turrets_fps and mines) were measured on the Turret of Story
## 013, 1.8 m tall with no damaged look, so for every scenario that does not declare
## const TURRET_LOOKS: bool = true the runner takes both away: damaged_below is emptied on the shared
## turret_stats.tres before the scene is instanced (_apply_turret_looks_data_off()), and each Turret
## under a Map Base's Turrets node is replaced, before the scene enters the tree, by an instance of
## the frozen scene of Story 013 (tools/evidence/frozen/turret_story_013.tscn) under the same name,
## child index and transform, the Base's structures and color_meshes entries pointed at it
## (_apply_turret_looks_off()). turret_scene is the scene a kit instances for a Turret of its own:
## the frozen one, or the shipped one for a scenario that declares TURRET_LOOKS, which declares
## TURRETS as well (that keeps the Turrets and the notice line). Each opt-in keeps only its own
## pieces.
##
## The explosions (Story 016). A Unit the Round counts as destroyed now plays an Explosion, which
## SplitScreen adds under World when the MatchController announces the destruction (unit_destroyed)
## and frees at every restart. It is a picture only and changes nothing the Round does, but it adds a
## node, a node group and a listener to the Round that no older scenario was measured with, so the
## runner takes it away from the freshly instanced launch scene before it enters the tree
## (_apply_explosions_off()) unless the scenario script declares const EXPLOSIONS: bool = true: it sets
## explosion_scene to null, so SplitScreen connects nothing for it and no Explosion is ever added. A
## scenario of Story 016 declares it, with the opt-ins of the pieces it needs; any other scenario, now
## and later, runs without explosions. The explosion puts nothing on the notice line, so the notice
## keep rule (TURRETS or MINES) does not read it.
##
## The badly damaged state (Story 017). A Unit at or below a fifth of its hit points now smokes and
## drives at half its top speed (UnitStats.badly_damaged_fraction and badly_damaged_speed_share, 0.2
## and 0.5 in the four shipped files). The older scenarios were measured with none of that, and
## several of them bring a Unit down to a few hit points and then drive it or aim at it, so the
## runner takes the state away before the scene is instanced unless the scenario script declares
## const BADLY_DAMAGED: bool = true (_apply_badly_damaged_off()): badly_damaged_fraction is 0 on
## every UnitStats of match_rules.tres's unit_types, the shared resources the Units spawn with, so
## no top speed changes, badly_damaged_changed is never emitted and no smoke node is ever instanced.
## The state puts nothing on the notice line, so the notice keep rule (TURRETS or MINES) does not
## read it. A scenario of Story 017 declares it, with the opt-ins of the pieces it needs.
##
## The Wall Panels (Story 018). Map 01's Bases now close their back, side and Gate walls with Wall Panels:
## 30 Structures a Base, each 2 m tall with 40 hit points on the cover layer, listed in its structures and
## standing in the five nodes under its Walls (WallBack, WallLeft, WallRight, GateWallLeft, GateWallRight),
## which were 3.2 m StaticBody3D on the map layer in Story 007. Every scenario written before it was
## measured with those walls (no Shot breaks them and the Gyrocopter cannot fly over them), so the runner
## puts them back in the freshly instanced launch scene, before it enters the tree
## (_apply_wall_panels_off()), unless the scenario script declares const WALL_PANELS: bool = true, which
## keeps the Map as it ships: for each Map Base whose Walls node holds the five runs, every Structure
## under a run is dropped from its structures, each run is removed and freed at once, and the StaticBody3D
## of the same name from the frozen scene of Story 007 (tools/evidence/frozen/base_walls_story_007.tscn)
## takes its child index, with the Base as the owner of every node of it, as the nodes of the Base's own
## scene have. Only what stands under those five nodes is stripped, so the corner towers stay. A Base with
## no Walls node (the greybox composition) is left alone. A scenario of Story 018 declares it, with the
## opt-ins of the pieces it needs; any other scenario, now and later, runs on the old walls. The panels put
## nothing on the notice line, so the notice keep rule (TURRETS or MINES) does not read it.
##
## The Garage and field Wall Panels (Story 019). Map 01's Garages now close their back and two side walls with
## Wall Panels too: 10 a Base, listed in its structures and standing in the three nodes under its Garage
## (GarageBack, GarageSideLeft, GarageSideRight), which were 2.5 m StaticBody3D on the map layer in Story 007.
## The two walls in the field are 8 more, listed in the Map's neutral_structures and standing in its
## FieldWalls node (FieldWallWest, FieldWallEast); they were two 12 m StaticBody3D on the cover layer under
## Cover/ScrapWalls, and Cover with them. Every scenario written before it was measured with those walls (no
## Shot breaks them, the Gyrocopter cannot fly over a Garage wall and the scrap walls are Cover), so the
## runner puts them back in the freshly instanced launch scene, before it enters the tree, unless the scenario
## script declares const GARAGE_SCRAP_PANELS: bool = true, which keeps the Map as it ships.
##
## _apply_garage_panels_off(): for each Map Base whose Garage node holds the three walls, every Structure
## under one of them is dropped from its structures, each wall is removed and freed at once, and the
## StaticBody3D of the same name from the frozen scene of Story 007
## (tools/evidence/frozen/garage_walls_story_007.tscn) takes its child index, with the Base as the owner of
## every node of it. _apply_field_panels_off(): for a Map with a FieldWalls node and a Cover node,
## neutral_structures is emptied, FieldWalls is freed and a ScrapWalls Node3D is added as the last child of
## Cover holding the two StaticBody3D of tools/evidence/frozen/scrap_walls_story_007.tscn, Cover as the owner
## of every node; it runs after the greybox composition and before _apply_pre_009_map(), so the frozen scrap
## walls get the layer Story 007 had as before. A Base or a Map without those nodes (the greybox composition)
## is left alone. A scenario of Story 019 declares it, with the opt-ins of the pieces it needs; any other
## scenario, now and later, runs on the old walls, those of Story 018 among them. The panels put nothing on
## the notice line, so the notice keep rule (TURRETS or MINES) does not read it.
##
## The Heights (Story 020). The shipped Gyrocopter model no longer rises: gyrocopter_mesh_model.tscn stands at the
## flying height (hover_height, 2.5 m) from the tick it is made and has no rise values. Every scenario written before
## it was measured on the model of Stories 007 to 019, which hovers 0.78 m up and rises over the cliffs and the cover
## (the Wall Panels among it), so the runner gives that model back unless the scenario script declares
## const HEIGHTS: bool = true, which keeps the model as it ships (_apply_heights_off()): every UnitStats of
## match_rules.tres's unit_types whose model is the shipped Gyrocopter scene takes the frozen copy of the earlier
## model (tools/evidence/frozen/gyrocopter_model_story_019.tscn, a byte copy taken at the start of Story 020) before
## the launch scene is instanced, after _apply_greybox_models(), so a greybox scenario keeps its greybox Gyrocopter. A
## scenario of Story 020 declares it, with the opt-ins of the pieces it needs; any other scenario, now and later,
## runs on the model that rises. The model puts nothing on the notice line, so the notice keep rule (TURRETS or
## MINES) does not read it.
##
## The crash (Story 021). The Gyrocopter's data now says it crashes: UnitStats.crash_speed is 4.0 in the shipped
## gyrocopter_stats.tres (0, never, for the other three), so a Gyrocopter that flies straight into a Tall piece at or above
## that speed is destroyed in the tick of the contact. Every scenario written before it flew a Gyrocopter into a Tall piece
## and kept it, stopped (depot_tanks, turrets, flag_walls_over, gyro_cover, gyro at the greybox field's wall, fuel's run_dry,
## heights), so the runner takes the crash out of the data before the scene is instanced unless the scenario script declares
## const GYRO_CRASH: bool = true (_apply_crash_off()): crash_speed is 0 on every UnitStats of match_rules.tres's unit_types,
## the shared resources the Units spawn with, so no type ever crashes. The sea edge's group on the Map's shore bodies stays,
## read by nothing then. A scenario of Story 021 declares it, with the opt-ins of the pieces it needs; any other scenario,
## now and later, runs without the crash. The crash puts nothing on the notice line, so the notice keep rule (TURRETS or
## MINES) does not read it.
##
## The ammunition and the full start (Story 022). The shipped data now gives every Unit type a load of ammunition
## (UnitStats.ammo_capacity: 100, 50, 25 and 40 Shots; each Shot spends one and a Weapon with none left fires nothing)
## and every new Unit starts with a full tank (spawn_fuel_fraction 1.0 in the four files, where Story 006 had a half);
## each Player's view has an AmmoCount Label and the notice line says "Out of ammo". Every scenario written before it
## fired without a count and spawned with the half tank, so the runner takes both out of the data before the scene is
## instanced unless the scenario script declares const AMMO: bool = true (_apply_ammo_off()): ammo_capacity is 0 and
## spawn_fuel_fraction is LEGACY_SPAWN_FUEL_FRACTION on every UnitStats of match_rules.tres's unit_types, the shared
## resources the Units spawn with, so no Weapon counts, spends or emits anything. Both AmmoCount Labels are freed in the
## instanced scene (_apply_ammo_counts_off(): camera_views counts every Control in each view). The notice line keeps its
## rule of Story 013 and 014, extended: the PlayerNotice Labels stay for a scenario that declares TURRETS, MINES or AMMO,
## and with ammo_capacity 0 the new out_of_ammo connection never fires in an older one. A scenario of Story 022
## declares AMMO, with the opt-ins of the pieces it needs; any other scenario, now and later, runs without the ammunition
## and with the half tank.
##
## The rotors (Story 025). The shipped Gyrocopter model now turns its main rotor and its pusher propeller: its mesh file
## (assets/art/vehicles/wasteland_gyrocopter/wasteland_gyrocopter.glb) holds four more meshes, the turning parts, and its model
## scene names them in rotor_settings, so a RotorPivot turns each about its hub on every physics tick and draws a see-through
## smear behind its blades. Every scenario written before it measured a model that draws only the Accent and the Neutral and
## stands still (drawn_box() merges the boxes of every visible mesh under a model, and a turning mesh or a smear changes them
## even at angle 0), so the runner gives that model back unless the scenario script declares const ROTORS: bool = true
## (_apply_rotors_off()): every UnitStats of match_rules.tres's unit_types whose model is the shipped Gyrocopter scene or its
## frozen copy of Story 019 (so after _apply_heights_off()) takes a scene packed from an instance of it with mesh_scene set to
## the byte copy of the mesh file taken at the start of Story 025 (tools/evidence/frozen/wasteland_gyrocopter_story_024.glb)
## and rotor_settings null, before the launch scene is instanced: no pivot, no smear, nothing that turns, and the vertices the
## older outputs were measured with. A scenario of Story 025 declares it, with the opt-ins of the pieces it needs (HEIGHTS
## among them: the frozen scene of Story 019 hovers 0.78 m up); any other scenario, now and later, runs on the model that
## stands still. The rotors put nothing on the notice line, so the notice keep rule (TURRETS or MINES) does not read them.
##
## The tyre tracks (Story 026). Map 01 now has a TyreTracks node, listed in its field's tyre_tracks: it draws a track under each
## ground Unit's tyres into one texture the ground shader reads, and it is a script on the Map (map_layout prints the Map's scripts),
## a clock the Round-over pause stops and a SubViewport, none of which any scenario written before it was measured with. So the
## runner removes the node from a freshly instanced launch scene unless the scenario script declares const TYRE_TRACKS: bool = true
## (_apply_tyre_tracks_off()): the field's export is cleared and the node freed before the scene enters the tree, SplitScreen then
## hands nothing and connects nothing, the ground shader's global parameters stay at the project's defaults (strength 0, which
## makes every term of the tracks in the shader exactly nothing) and the ground is drawn as before. The tyre data in the Units'
## stats is read by nothing but that node. A scenario of Story 026 declares it, with the opt-ins of the pieces it needs; any other
## scenario, now and later, runs on a Map with no tracks.
##
## The see-through silhouette (Story 027). The launch scene's Units now carry a SilhouetteSettings
## (src/gameplay/units/data/silhouette_settings.tres): every model a Unit is given is dressed with two invisible copies of each mesh it
## draws and one fill quad, on its Player's render layer; and SplitScreen gives each camera the layer it never draws
## (ChaseCamera.never_drawn_layers, from those settings), so their culling masks are not what every older output printed (camera_views
## and the scenarios that read cull_mask) and a model holds copies that drawn_box() merges. So the runner takes the silhouette away
## from a freshly instanced launch scene unless the scenario script declares const SEE_THROUGH: bool = true
## (_apply_see_through_off()): both Units' silhouette is null, so no model is dressed, no copy or quad is made, and SplitScreen has
## no layer to hand the cameras, so each keeps today's mask. A scenario of Story 027 declares it, with the opt-ins of the pieces it
## needs; any other scenario, now and later, runs with no silhouettes and today's camera masks. The tone mapper, the glow and the
## colour grade of Map 01's Environment are no opt-in: no scenario reads the Environment (a grep of tools/evidence for
## Environment, tonemap, glow_, fog_, sky and adjustment_ finds none) and a headless run draws nothing.
##
## The slower Fuel and the resource bars (Story 036). The shipped data now burns Fuel three times slower, and each Player's HUD
## shows the Fuel and the ammo as two bars with icons and no text (the Fuel line and the Ammo line are gone). Every scenario
## written before it was measured with the old rates and the old HUD, so unless the scenario script declares
## const RESOURCE_BARS: bool = true the runner gives every UnitStats of match_rules.tres its old fuel_use and fuel_use_idle on the
## shared resources, before any other data helper (_apply_fuel_burn_off(), LEGACY_036_FUEL_RATES), and, in the freshly instanced
## launch scene, replaces each PlayerHud by the frozen HUD of story 032 (tools/evidence/frozen/player_hud_story_032.tscn: the Fuel
## line, no icons, no ammo bar), with the same name, index and exports, and, for a scenario that declares AMMO, puts the Ammo line
## of story 022 back as each view's last child (_apply_resource_bars_off()). A scenario of Story 036 declares it.
##
## A Turret sees a Gyrocopter over a cliff (Story 037). The shipped turret_stats.tres now lets no cliff hide a flying target
## (flying_sight_extra_mask 0). Unless the scenario script declares const TURRET_SEES_FLYING: bool = true the runner gives the
## shared TurretStats the sight every older output was measured with, a cliff hiding every target alike
## (_apply_flying_sight_off(): flying_sight_extra_mask = sight_extra_mask).
##
## Map 02, the Bushes and the map choice (Story 038). A scenario script that declares const MAP_SCENE: String names a Map
## scene the runner puts in place of Map 01 in the freshly instanced launch scene before any other helper touches it
## (_apply_map_scene(): SplitScreen.use_map()); every scenario written before it declares none and plays Map 01. The shipped
## turret_stats.tres now adds the sight layer (layer 8, a Bush's sight body) to the sight of a ground target (sight_extra_mask
## 160), the project names that layer "sight" and declares the map choice's three menu actions with keyboard and pad events.
## Unless the scenario script declares const BUSHES: bool = true the runner gives the shared TurretStats the sight of stories
## 013 to 037 (sight_extra_mask 32, before _apply_flying_sight_off() copies it) and takes the layer's name away; unless it
## declares const MAP_CHOICE: bool = true it erases the three menu actions from the InputMap (_apply_bushes_off(),
## _apply_map_choice_off()): the scenarios that count layer names, pad events or keys were measured without them. Without
## MAP_CHOICE the launch scene also loses its way back to the map choice (_apply_map_choice_nodes_off()).
##
## The open Flag (Story 039). The shipped data no longer lets a Turret lock its Base's Flag (turret_stats.tres locks_flag
## false) and lets the Motorbike's Shots break Wall Panels (no motorbike>flag_wall pair in damage_matrix.tres). Unless the
## scenario script declares const FLAG_OPEN: bool = true the runner puts both back on the shared resources
## (_apply_flag_open_off()).
##
## The left stick drives (Story 040). The shipped pad layout now drives on the left stick (up throttle, down reverse, left and
## right steer) and fires on either trigger as well as A. Unless the scenario script declares const STICK_DRIVE: bool = true
## the runner gives the cached layout the bindings of stories 032 to 039 (tools/evidence/frozen/pad_layout_story_032.tres;
## _apply_stick_drive_off()).
##
## Fire in two Heights (Story 041). The shipped match_rules.tres now gives a low Shot the map, the units and the cover (67) and a
## high Shot the map and the gyrocopters (17), drawn 2.9 m higher; each Player has a high fire action (Left Shift, Right Shift,
## a pad's RB) and a Turret fires high at a Gyrocopter. Unless the scenario script declares const FIRE_HEIGHTS: bool = true
## the runner gives both Shots the old mask (83) and no lift, and erases the high fire actions (_apply_fire_heights_off()).
##
## Secondary weapons (Story 042). The secondary key (the lay_mine action: E, Comma, now a pad's LT, no longer X) also fires the
## Buggy's nitro and drops the Gyrocopter's smoke screen; the Turrets' sight holds the smoke layer (layer 9). Unless the scenario
## script declares const SECONDARY: bool = true the runner takes the nitro, smoke and status nodes out of the launch scene, the
## smoke layer out of the Turret's sight and its name away, and gives a STICK_DRIVE scenario story 041's pad layout
## (_apply_secondary_off(), _apply_secondary_nodes_off()). Since Story 044 the same opt-in keeps the recharging secondaries:
## without it the Truck counts its Mines again (mine_cooldown_seconds 0), the Motorbike's FlagDroppers go, and every Bush is
## the size of story 038 (Bush.size 1.0). Since Story 045 also: the HUD's Tokens line shows again and the supply zones' markings
## are lit, the ammunition zone's in the tracer's pale yellow (_restore_zone_look_044()); since Story 046 a Player's own Shots
## spare that Player's walls again (flag_wall_stats.tres spared_by_owner true).
##
## Teams (Story 048). The shipped mine_settings.tres now lets a Mine spare its own Team (spares_own_team). Unless the scenario
## script declares const TEAMS: bool = true the runner gives it back the rule of stories 014 to 047 (_apply_teams_off()). A
## scenario that declares const LINEUP_DEVICES and LINEUP_TEAMS (int arrays) plays that lineup: the runner hands it to
## SplitScreen.apply_lineup() before the scene enters the tree (_apply_lineup()); a lineup scenario declares the opt-ins of
## the shipped game, because the node opt-outs look for the views of two Players.
##
## Full throttle (Story 049). On a pad the throttle is full from 0.4 of the stick's travel (PlayerDriveInput rounds it, the
## pad layout gives the throttle and the reverse that dead zone), every type turns on the spot 1.5 times as fast and the
## Turret reaches 45 m. Unless the scenario script declares const FULL_THROTTLE: bool = true the runner gives it the drive and
## the numbers of stories 009 to 048: the partial throttle (every PlayerDriveInput's full_throttle off), the 0.2 dead zone on
## every pad action, the old spot_turn_rate of each type and the Turret's 35 m (_apply_full_throttle_off(), first, so the
## older opt-outs still set what they set, and _apply_full_throttle_nodes_off()).
##
## Chase view and Tokens (Story 050). The chase view sits closer (offset 0, 6.5, 9), looks 7 m ahead and keeps a 68.6 degree
## field of view across its width, and each Map's stock is 7 Motorbikes, 4 Buggies, 3 Trucks and 3 Gyrocopters. Unless the
## scenario script declares const CLOSE_CHASE: bool = true the runner gives the cached chase settings the view of stories 001
## to 049 (offset 0, 7, 13, no look-ahead, the camera's own field of view), and unless it declares const MORE_TOKENS: bool =
## true the shared token_stock.tres the counts 5, 3, 2, 2 (_apply_story_050_off(), first).
##
## Output: SPLIT <scenario> t=<seconds> key=value ... (progress), CHECK <scenario> <check name> PASS|FAIL
## <detail> and exactly one last RESULT <scenario> ok|fail checks=<n> failed=<n> key=value ...; then quit with
## exit code 0 when every check passed, 1 when one failed, 2 for a missing or unknown scenario. TD-003
## (docs/tech-debt-register.md) is paid by Story 003; this runner is still coroutine-based with run-wide counters (TD-001).

## The launch scene under test.
const SPLIT_SCENE: PackedScene = preload("res://src/gameplay/split_screen/split_screen.tscn")

## Prefix of the user argument that names the scenario.
const SCENARIO_ARGUMENT: String = "--scenario="

## The scenarios, name to script, in the order of the header. Each script is a RefCounted with
## run(harness: Node) -> void, a coroutine. A new scenario is its script and one line here.
const SCENARIOS: Dictionary[StringName, GDScript] = {
	&"layout": preload("res://tools/evidence/split_screen/layout.gd"),
	&"isolation": preload("res://tools/evidence/split_screen/isolation.gd"),
	&"simultaneous": preload("res://tools/evidence/split_screen/simultaneous.gd"),
	&"showcase": preload("res://tools/evidence/split_screen/showcase.gd"),
	&"fps": preload("res://tools/evidence/split_screen/fps.gd"),
	&"bases": preload("res://tools/evidence/split_screen/bases.gd"),
	&"destruction": preload("res://tools/evidence/split_screen/destruction.gd"),
	&"countdown": preload("res://tools/evidence/split_screen/countdown.gd"),
	&"respawn_showcase": preload("res://tools/evidence/split_screen/respawn_showcase.gd"),
	&"flag_run": preload("res://tools/evidence/split_screen/flag_run.gd"),
	&"hud": preload("res://tools/evidence/split_screen/hud.gd"),
	&"round_over": preload("res://tools/evidence/split_screen/round_over.gd"),
	&"flag_showcase": preload("res://tools/evidence/split_screen/flag_showcase.gd"),
	&"units": preload("res://tools/evidence/split_screen/units.gd"),
	&"weapons": preload("res://tools/evidence/split_screen/weapons.gd"),
	&"gyro": preload("res://tools/evidence/split_screen/gyro.gd"),
	&"choice": preload("res://tools/evidence/split_screen/choice.gd"),
	&"units_showcase": preload("res://tools/evidence/split_screen/units_showcase.gd"),
	&"fuel": preload("res://tools/evidence/split_screen/fuel.gd"),
	&"fuel_cans": preload("res://tools/evidence/split_screen/fuel_cans.gd"),
	&"fuel_showcase": preload("res://tools/evidence/split_screen/fuel_showcase.gd"),
	&"map_layout": preload("res://tools/evidence/split_screen/map_layout.gd"),
	&"map_edges": preload("res://tools/evidence/split_screen/map_edges.gd"),
	&"map_ford": preload("res://tools/evidence/split_screen/map_ford.gd"),
	&"map_bases": preload("res://tools/evidence/split_screen/map_bases.gd"),
	&"map_cover": preload("res://tools/evidence/split_screen/map_cover.gd"),
	&"map_showcase": preload("res://tools/evidence/split_screen/map_showcase.gd"),
	&"map_legibility": preload("res://tools/evidence/split_screen/map_legibility.gd"),
	&"map_fps": preload("res://tools/evidence/split_screen/map_fps.gd"),
	&"tokens": preload("res://tools/evidence/split_screen/tokens.gd"),
	&"tokens_data": preload("res://tools/evidence/split_screen/tokens_data.gd"),
	&"token_choice": preload("res://tools/evidence/split_screen/token_choice.gd"),
	&"loss": preload("res://tools/evidence/split_screen/loss.gd"),
	&"token_ui": preload("res://tools/evidence/split_screen/token_ui.gd"),
	&"token_layout": preload("res://tools/evidence/split_screen/token_layout.gd"),
	&"tokens_showcase": preload("res://tools/evidence/split_screen/tokens_showcase.gd"),
	&"depot_tanks": preload("res://tools/evidence/split_screen/depot_tanks.gd"),
	&"gyro_cover": preload("res://tools/evidence/split_screen/gyro_cover.gd"),
	&"spot_turn": preload("res://tools/evidence/split_screen/spot_turn.gd"),
	&"idle_burn": preload("res://tools/evidence/split_screen/idle_burn.gd"),
	&"fuel_hint": preload("res://tools/evidence/split_screen/fuel_hint.gd"),
	&"quick_fixes_showcase": preload("res://tools/evidence/split_screen/quick_fixes_showcase.gd"),
	&"camera_views": preload("res://tools/evidence/split_screen/camera_views.gd"),
	&"camera_showcase": preload("res://tools/evidence/split_screen/camera_showcase.gd"),
	&"camera_smooth": preload("res://tools/evidence/split_screen/camera_smooth.gd"),
	&"unit_swap": preload("res://tools/evidence/split_screen/unit_swap.gd"),
	&"unit_swap_showcase": preload("res://tools/evidence/split_screen/unit_swap_showcase.gd"),
	&"flag_walls": preload("res://tools/evidence/split_screen/flag_walls.gd"),
	&"flag_walls_showcase": preload("res://tools/evidence/split_screen/flag_walls_showcase.gd"),
	&"turrets": preload("res://tools/evidence/split_screen/turrets.gd"),
	&"turrets_showcase": preload("res://tools/evidence/split_screen/turrets_showcase.gd"),
	&"turrets_fps": preload("res://tools/evidence/split_screen/turrets_fps.gd"),
	&"mines": preload("res://tools/evidence/split_screen/mines.gd"),
	&"mines_showcase": preload("res://tools/evidence/split_screen/mines_showcase.gd"),
	&"turret_looks": preload("res://tools/evidence/split_screen/turret_looks.gd"),
	&"turret_looks_showcase": preload("res://tools/evidence/split_screen/turret_looks_showcase.gd"),
	&"turret_looks_fps": preload("res://tools/evidence/split_screen/turret_looks_fps.gd"),
	&"explosions": preload("res://tools/evidence/split_screen/explosions.gd"),
	&"explosions_off": preload("res://tools/evidence/split_screen/explosions_off.gd"),
	&"explosions_showcase": preload("res://tools/evidence/split_screen/explosions_showcase.gd"),
	&"explosions_fps": preload("res://tools/evidence/split_screen/explosions_fps.gd"),
	&"badly_damaged": preload("res://tools/evidence/split_screen/badly_damaged.gd"),
	&"badly_damaged_off": preload("res://tools/evidence/split_screen/badly_damaged_off.gd"),
	&"badly_damaged_showcase": preload("res://tools/evidence/split_screen/badly_damaged_showcase.gd"),
	&"badly_damaged_fps": preload("res://tools/evidence/split_screen/badly_damaged_fps.gd"),
	&"base_walls": preload("res://tools/evidence/split_screen/base_walls.gd"),
	&"base_walls_showcase": preload("res://tools/evidence/split_screen/base_walls_showcase.gd"),
	&"garage_scrap_walls": preload("res://tools/evidence/split_screen/garage_scrap_walls.gd"),
	&"garage_scrap_walls_showcase": preload("res://tools/evidence/split_screen/garage_scrap_walls_showcase.gd"),
	&"heights": preload("res://tools/evidence/split_screen/heights.gd"),
	&"heights_showcase": preload("res://tools/evidence/split_screen/heights_showcase.gd"),
	&"crash": preload("res://tools/evidence/split_screen/crash.gd"),
	&"crash_showcase": preload("res://tools/evidence/split_screen/crash_showcase.gd"),
	&"ammo": preload("res://tools/evidence/split_screen/ammo.gd"),
	&"ammo_alone": preload("res://tools/evidence/split_screen/ammo_alone.gd"),
	&"ammo_showcase": preload("res://tools/evidence/split_screen/ammo_showcase.gd"),
	&"fuel_building": preload("res://tools/evidence/split_screen/fuel_building.gd"),
	&"fuel_building_showcase": preload("res://tools/evidence/split_screen/fuel_building_showcase.gd"),
	&"fuel_building_fps": preload("res://tools/evidence/split_screen/fuel_building_fps.gd"),
	&"ammo_buildings": preload("res://tools/evidence/split_screen/ammo_buildings.gd"),
	&"ammo_buildings_showcase": preload("res://tools/evidence/split_screen/ammo_buildings_showcase.gd"),
	&"ammo_buildings_fps": preload("res://tools/evidence/split_screen/ammo_buildings_fps.gd"),
	&"rotors": preload("res://tools/evidence/split_screen/rotors.gd"),
	&"rotors_showcase": preload("res://tools/evidence/split_screen/rotors_showcase.gd"),
	&"rotors_fps": preload("res://tools/evidence/split_screen/rotors_fps.gd"),
	&"tyre_tracks": preload("res://tools/evidence/split_screen/tyre_tracks.gd"),
	&"tyre_tracks_showcase": preload("res://tools/evidence/split_screen/tyre_tracks_showcase.gd"),
	&"tyre_tracks_fps": preload("res://tools/evidence/split_screen/tyre_tracks_fps.gd"),
	&"see_through": preload("res://tools/evidence/split_screen/see_through.gd"),
	&"light_showcase": preload("res://tools/evidence/split_screen/light_showcase.gd"),
	&"light_fps": preload("res://tools/evidence/split_screen/light_fps.gd"),
	&"pads": preload("res://tools/evidence/split_screen/pads.gd"),
	&"pads_data": preload("res://tools/evidence/split_screen/pads_data.gd"),
	&"pads_showcase": preload("res://tools/evidence/split_screen/pads_showcase.gd"),
	&"resource_bars": preload("res://tools/evidence/split_screen/resource_bars.gd"),
	&"resource_bars_showcase": preload("res://tools/evidence/split_screen/resource_bars_showcase.gd"),
	&"turret_flying_sight": preload("res://tools/evidence/split_screen/turret_flying_sight.gd"),
	&"cliff_tops": preload("res://tools/evidence/split_screen/cliff_tops.gd"),
	&"map_02": preload("res://tools/evidence/split_screen/map_02.gd"),
	&"bushes": preload("res://tools/evidence/split_screen/bushes.gd"),
	&"cover_pieces": preload("res://tools/evidence/split_screen/cover_pieces.gd"),
	&"map_02_showcase": preload("res://tools/evidence/split_screen/map_02_showcase.gd"),
	&"flag_open": preload("res://tools/evidence/split_screen/flag_open.gd"),
	&"pads_stick": preload("res://tools/evidence/split_screen/pads_stick.gd"),
	&"full_throttle": preload("res://tools/evidence/split_screen/full_throttle.gd"),
	&"turret_reach_showcase": preload("res://tools/evidence/split_screen/turret_reach_showcase.gd"),
	&"map_03_showcase": preload("res://tools/evidence/split_screen/map_03_showcase.gd"),
	&"map_03": preload("res://tools/evidence/split_screen/map_03.gd"),
	&"teams_last_carrier": preload("res://tools/evidence/split_screen/teams_last_carrier.gd"),
	&"hud_showcase": preload("res://tools/evidence/split_screen/hud_showcase.gd"),
	&"chase_view": preload("res://tools/evidence/split_screen/chase_view.gd"),
	&"chase_showcase": preload("res://tools/evidence/split_screen/chase_showcase.gd"),
	&"chase_showcase_two": preload("res://tools/evidence/split_screen/chase_showcase_two.gd"),
	&"fire_heights": preload("res://tools/evidence/split_screen/fire_heights.gd"),
	&"fire_heights_showcase": preload("res://tools/evidence/split_screen/fire_heights_showcase.gd"),
	&"secondary": preload("res://tools/evidence/split_screen/secondary.gd"),
	&"real_flag": preload("res://tools/evidence/split_screen/real_flag.gd"),
	&"secondary_flag_showcase": preload("res://tools/evidence/split_screen/secondary_flag_showcase.gd"),
	&"recharge_showcase": preload("res://tools/evidence/split_screen/recharge_showcase.gd"),
	&"pad_back": preload("res://tools/evidence/split_screen/pad_back.gd"),
	&"shadow_showcase": preload("res://tools/evidence/split_screen/shadow_showcase.gd"),
	&"teams": preload("res://tools/evidence/split_screen/teams.gd"),
	&"teams_three": preload("res://tools/evidence/split_screen/teams_three.gd"),
	&"teams_showcase": preload("res://tools/evidence/split_screen/teams_showcase.gd"),
}

## The shared step class (drive_step.gd): keys held for a time.
const DriveStep: GDScript = preload("res://tools/evidence/split_screen/drive_step.gd")
## The shared track class (unit_track.gd): follows one Unit through a phase.
const UnitTrack: GDScript = preload("res://tools/evidence/split_screen/unit_track.gd")

## Exit code when a check failed.
const EXIT_FAILED: int = 1
## Exit code for a missing or unknown scenario.
const EXIT_USAGE: int = 2
## A scenario still running after this many simulated seconds has hung (a script error stops a
## coroutine without a word): the watchdog prints a failing RESULT and quits. A scenario script
## that declares its own (WATCHDOG_CONSTANT) gets that instead.
const WATCHDOG_SECONDS: float = 120.0
## The constant a scenario script may declare (const WATCHDOG_SECONDS: float = ...) for a watchdog
## of its own, in simulated seconds; a value that is not a number above zero is ignored.
const WATCHDOG_CONSTANT: StringName = &"WATCHDOG_SECONDS"

## Player 1's index, into the tracks and the layouts.
const PLAYER_1: int = 0
## Player 2's index, into the tracks and the layouts.
const PLAYER_2: int = 1
## Stands for both Players in a DriveStep: both layouts are held at once.
const BOTH: int = -1

## Physical keys of Player 1's layout, in the order of SLOT_*: the p1_ Input Map actions are bound to these.
const PLAYER_1_KEYS: Array[Key] = [KEY_W, KEY_S, KEY_A, KEY_D]
## Physical keys of Player 2's layout, in the order of SLOT_*: the p2_ Input Map actions are bound to these.
const PLAYER_2_KEYS: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
## Physical key of Player 1's fire action (p1_fire): the choice confirm, and the weapon's trigger.
const PLAYER_1_FIRE_KEY: Key = KEY_SPACE
## Physical key of Player 2's fire action (p2_fire).
const PLAYER_2_FIRE_KEY: Key = KEY_PERIOD
## The scenarios written before Story 005's Unit choice, which expect both Units in play when they
## start and a destroyed Unit back after the delay with no key of theirs: for them the runner makes
## a destroyed Player's choice again at once (_on_legacy_destroyed()). A scenario of Story 005 or
## later is not listed and chooses with its own keys after a destruction.
const LEGACY_SCENARIOS: Array[StringName] = [&"layout", &"isolation", &"simultaneous", &"showcase",
	&"fps", &"bases", &"destruction", &"countdown", &"respawn_showcase", &"flag_run", &"hud",
	&"round_over", &"flag_showcase"]
## The type the runner chooses for a legacy scenario's destroyed Player: the first of the data, the
## Motorbike, what every Unit was before Story 005.
const LEGACY_TYPE_INDEX: int = 0
## The shared Motorbike stats: the one resource motorbike.tscn and match_rules.tres both use (one
## cached object), so a value written here before the launch scene is instanced reaches the Units
## and the rules.
const MOTORBIKE_STATS_PATH: String = "res://src/gameplay/units/data/motorbike_stats.tres"
## The Motorbike's collision mask the legacy scenarios were measured with: the map and units layers,
## the scene's own, before the data added the cliffs_water layer that the typed spawn now applies
## (the destruction scenario prints the mask; the legacy lanes never reach that layer's bodies).
const LEGACY_MOTORBIKE_COLLISION_MASK: int = 3
## The Motorbike's hit points the legacy scenarios were measured with: Story 003's placeholder 100,
## before the shipped data took the design's 40 (Story 005 AC-2); their debug-key presses, respawns
## and HUD readings count on it, and two of them print it in a CHECK line.
const LEGACY_MOTORBIKE_HIT_POINTS: float = 100.0
## The shared match rules: the one resource split_screen.tscn hands the MatchController and both
## PlayerMatchInputs (one cached object), so a value written here before the launch scene is
## instanced reaches them all.
const MATCH_RULES_PATH: String = "res://src/gameplay/match/data/match_rules.tres"
## The debug damage the legacy scenarios were measured with: a quarter of the placeholder hit
## points, before the shipped data set it to zero, the gate of Story 003 AC-8 that switches the
## debug keys off now that Story 005 brings weapons. PlayerMatchInput reads the gate once, in its
## _ready(), so the value must be in before the scene is instanced.
const LEGACY_DEBUG_DAMAGE: float = 25.0
## The Fuel burn rate every scenario written before Story 006 was measured with (LEGACY_SCENARIOS
## and STORY_005_SCENARIOS; _apply_no_fuel_data()): their Units get a tank at every spawn and
## nothing burns it, so a long run never empties one, which would stop a ground Unit and crash a
## Gyrocopter (Story 006 AC-1 gave every type a fuel_use).
const LEGACY_FUEL_USE: float = 0.0
## The scenarios of Story 005, written after the Unit choice and before Fuel: they run on the
## shipped data except the Fuel burn rate, which the runner sets to LEGACY_FUEL_USE for them as for
## LEGACY_SCENARIOS (_apply_no_fuel_data()).
const STORY_005_SCENARIOS: Array[StringName] = [&"units", &"weapons", &"gyro", &"choice",
	&"units_showcase"]
## The constant a scenario script declares (const OWN_CHOICE: bool = true) to make the first choice
## of the Round itself: the runner then presses no fire key before run().
const OWN_CHOICE_CONSTANT: StringName = &"OWN_CHOICE"
## The constant a scenario script declares as true to run on the camera the launch scene ships
## with, the view from above, instead of the chase view (_apply_chase_camera()).
const SHIPPED_CAMERA_CONSTANT: StringName = &"SHIPPED_CAMERA"
## The constant a scenario script declares as true to run with the swap at the own Base the shipped
## rules turn on, instead of the swap off (_apply_swap_off()).
const OWN_BASE_SWAP_CONSTANT: StringName = &"OWN_BASE_SWAP"
## The constant a scenario script declares as true to keep the Flag Walls and the side spawn spots
## the shipped Map 01 has, instead of the Map without them (_apply_defences_off()).
const BASE_DEFENCES_CONSTANT: StringName = &"BASE_DEFENCES"
## The node of a Map Base that holds its Flag Walls (Story 012); the Turrets of Story 013 stand
## under a node of their own.
const DEFENCES_NODE_NAME: StringName = &"Defences"
## The constant a scenario script declares as true to keep the Turrets and the two PlayerNotice
## Labels the shipped Map 01 and launch scene have, instead of the scene without them
## (_apply_turrets_off()).
const TURRETS_CONSTANT: StringName = &"TURRETS"
## The node of a Map Base that holds its Turrets (Story 013).
const TURRETS_NODE_NAME: StringName = &"Turrets"
## The constant a scenario script declares as true to keep the Mines the shipped data and launch scene
## have (the Truck's load, the two MineCount Labels, and the notice line for the refusals), instead of
## the scene without them (_apply_mines_off(), _apply_mine_counts_off()).
const MINES_CONSTANT: StringName = &"MINES"
## The constant a scenario script declares as true to run on the shipped Turret of Story 015 (its
## damaged looks and its growth), instead of the Turret of Story 013 as it was measured
## (_apply_turret_looks_data_off(), _apply_turret_looks_off()).
const TURRET_LOOKS_CONSTANT: StringName = &"TURRET_LOOKS"
## The constant a scenario script declares as true to keep the explosion a destroyed Unit plays (Story
## 016), instead of the launch scene without it (_apply_explosions_off()).
const EXPLOSIONS_CONSTANT: StringName = &"EXPLOSIONS"
## The constant a scenario script declares as true to keep the badly damaged state the shipped data
## gives every Unit type (Story 017), instead of the data without it (_apply_badly_damaged_off()).
const BADLY_DAMAGED_CONSTANT: StringName = &"BADLY_DAMAGED"
## The constant a scenario script declares as true to keep the Wall Panels the shipped Map 01's Bases have
## for their back, side and Gate walls (Story 018), instead of the five Base walls of Story 007
## (_apply_wall_panels_off()).
const WALL_PANELS_CONSTANT: StringName = &"WALL_PANELS"
## The node of a Map Base that holds its walls and its four corner towers.
const WALLS_NODE_NAME: StringName = &"Walls"
## The five wall nodes under a Base's Walls node, in the child order they stand in: a StaticBody3D each in
## Story 007, a Node3D holding that wall's Wall Panels since Story 018.
const WALL_RUN_NAMES: Array[StringName] = [&"WallBack", &"WallLeft", &"WallRight", &"GateWallLeft", &"GateWallRight"]
## The five Base walls of Story 007 as the scene had them at 03ed864, before Story 018, cut out of
## compound_base.tscn into a scene of their own (tools/evidence/frozen/): 3.2 m tall StaticBody3D on the
## map layer, with the map art's trims. Evidence-only: nothing under src/ uses it.
const FROZEN_BASE_WALLS_SCENE: PackedScene = preload("res://tools/evidence/frozen/base_walls_story_007.tscn")
## The constant a scenario script declares as true to keep the Wall Panels the shipped Map 01 has for its
## Garages' walls and for the two walls in the field (Story 019), instead of the old walls
## (_apply_garage_panels_off() and _apply_field_panels_off()).
const GARAGE_SCRAP_PANELS_CONSTANT: StringName = &"GARAGE_SCRAP_PANELS"
## The node of a Map Base that holds its Garage: the floor, the three walls and the Marking.
const GARAGE_NODE_NAME: StringName = &"Garage"
## The three wall nodes under a Base's Garage, in the child order they stand in (1 to 3, after the floor): a
## StaticBody3D each in Story 007, a Node3D holding that wall's Wall Panels since Story 019.
const GARAGE_WALL_NAMES: Array[StringName] = [&"GarageBack", &"GarageSideLeft", &"GarageSideRight"]
## The node of the Map that holds the walls in the field since Story 019, the Wall Panels of no Player, and
## the node under the Map's cover that held them in Story 007, with the names of the two walls there.
const FIELD_WALLS_NODE_NAME: StringName = &"FieldWalls"
const SCRAP_WALLS_NODE_NAME: StringName = &"ScrapWalls"
const SCRAP_WALL_NAMES: Array[StringName] = [&"ScrapWallWest", &"ScrapWallEast"]
## The three Garage walls and the two scrap walls of Story 007 as the scenes had them at 03ed864, before Story
## 019, cut out of compound_base.tscn and map_01_cover.tscn into scenes of their own (tools/evidence/frozen/):
## the Garage walls 2.5 m tall StaticBody3D on the map layer, with the map art's trims, the scrap walls two 12
## m StaticBody3D on the cover layer. Evidence-only: nothing under src/ uses them.
const FROZEN_GARAGE_WALLS_SCENE: PackedScene = preload("res://tools/evidence/frozen/garage_walls_story_007.tscn")
const FROZEN_SCRAP_WALLS_SCENE: PackedScene = preload("res://tools/evidence/frozen/scrap_walls_story_007.tscn")
## The constant a scenario script declares as true to keep the Gyrocopter model the build ships with (Story 020): it
## stands at the flying height from the tick it is made and never rises, instead of the model of Stories 007 to 019
## that hovers 0.78 m up and rises over the cliffs and the cover (_apply_heights_off()).
const HEIGHTS_CONSTANT: StringName = &"HEIGHTS"
## The constant a scenario script declares as true to keep the crash the build ships with (Story 021): the Gyrocopter's
## crash speed, so that a Gyrocopter flown into a Tall piece at speed is destroyed instead of stopped (_apply_crash_off()).
const GYRO_CRASH_CONSTANT: StringName = &"GYRO_CRASH"
## The constant a scenario script declares as true to keep the ammunition and the full start the shipped data gives every Unit
## type (Story 022), instead of the unlimited Shots and the half tank every older output was measured with
## (_apply_ammo_off(), _apply_ammo_counts_off(), and the notice keep rule of _apply_turrets_off()).
const AMMO_CONSTANT: StringName = &"AMMO"
## The constant a scenario script declares as true to keep the slower Fuel and the HUD's resource bars of Story 036
## (_apply_fuel_burn_off(), _apply_resource_bars_off()).
const RESOURCE_BARS_CONSTANT: StringName = &"RESOURCE_BARS"
## The constant a scenario script declares as true to keep the shipped Turret sight of Story 037, no cliff hiding a flying target
## (_apply_flying_sight_off()).
const TURRET_SEES_FLYING_CONSTANT: StringName = &"TURRET_SEES_FLYING"
## The constant a scenario script declares as a res:// path to play another Map than Map 01 (Story 038, _apply_map_scene()).
const MAP_SCENE_CONSTANT: StringName = &"MAP_SCENE"
## The constant a scenario script declares as true to keep the shipped sight layer of Story 038 (_apply_bushes_off()).
const BUSHES_CONSTANT: StringName = &"BUSHES"
## The constant a scenario script declares as true to keep the map choice's menu actions (Story 038, _apply_map_choice_off()).
const MAP_CHOICE_CONSTANT: StringName = &"MAP_CHOICE"
## The Turret's sight of a ground target before Story 038: the cliffs_water layer only.
const LEGACY_037_SIGHT_EXTRA_MASK: int = 32
## The physics layer Story 038 named, and the project setting that names it.
const SIGHT_LAYER_SETTING: String = "layer_names/3d_physics/layer_8"
## The map choice's actions (project.godot, Story 038), the key back to it from a Round that is over among them.
const MENU_ACTIONS: Array[StringName] = [&"menu_left", &"menu_right", &"menu_confirm", &"round_back"]
## The launch scene's nodes of the way back to the map choice (Story 038).
const MAP_CHOICE_NODES: Array[String] = ["MapChoiceReturn", "Views/Player1View/SubViewport/Player1MapChoiceHint", "Views/Player2View/SubViewport/Player2MapChoiceHint"]
## The constant a scenario script declares as true to keep the shipped open Flag of Story 039: no Turret locks a Flag and the
## Motorbike's Shots break Wall Panels (_apply_flag_open_off()).
const FLAG_OPEN_CONSTANT: StringName = &"FLAG_OPEN"
## The damage matrix the Shots read, and its pair Story 039 took out.
const DAMAGE_MATRIX_PATH_039: String = "res://src/gameplay/combat/data/damage_matrix.tres"
const MOTORBIKE_WALL_PAIR: StringName = &"motorbike>flag_wall"
## The constant a scenario script declares as true to keep the shipped pad layout of Story 040 (the left stick drives, the
## triggers fire; _apply_stick_drive_off()).
const STICK_DRIVE_CONSTANT: StringName = &"STICK_DRIVE"
## The shipped pad layout, and the layout of stories 032 to 039 (triggers throttle and reverse), frozen.
const PAD_LAYOUT_PATH: String = "res://src/gameplay/input/data/pad_layout.tres"
const FROZEN_PAD_LAYOUT: PadLayout = preload("res://tools/evidence/frozen/pad_layout_story_032.tres")
## The constant a scenario script declares as true to keep the shipped fire in two Heights of Story 041 (_apply_fire_heights_off()).
const FIRE_HEIGHTS_CONSTANT: StringName = &"FIRE_HEIGHTS"
## The one Shot mask of stories 005 to 040 (the map, the units, the gyrocopters and the cover), for low and high alike.
const LEGACY_040_SHOT_MASK: int = 83
## The high fire's actions (project.godot, Story 041).
const FIRE_HIGH_ACTIONS: Array[StringName] = [&"p1_fire_high", &"p2_fire_high"]
## The constant a scenario script declares as true to keep the shipped secondary weapons of Story 042 (_apply_secondary_off()).
const SECONDARY_CONSTANT: StringName = &"SECONDARY"
## The pad layout of story 041 (the left stick drives, both triggers and A fire low, RB high, X lays a Mine), frozen.
const FROZEN_PAD_LAYOUT_041: PadLayout = preload("res://tools/evidence/frozen/pad_layout_story_041.tres")
## The smoke layer Story 042 named (layer 9, 256) and its setting.
const SMOKE_LAYER_BIT: int = 256
const SMOKE_LAYER_SETTING: String = "layer_names/3d_physics/layer_9"
## The launch scene's nodes of the secondary weapons (Story 042).
## The Truck's data, whose Mines recharge since Story 044 (mine_cooldown_seconds), and the Bush scene's size before it.
const TRUCK_STATS_PATH_044: String = "res://src/gameplay/units/data/truck_stats.tres"
const LEGACY_043_BUSH_SIZE: float = 1.0
## Story 048: the constants of a scenario's lineup and of its Team rules, and the Mines' data.
const LINEUP_DEVICES_CONSTANT: StringName = &"LINEUP_DEVICES"
const LINEUP_TEAMS_CONSTANT: StringName = &"LINEUP_TEAMS"
const TEAMS_CONSTANT: StringName = &"TEAMS"
## The constants a scenario script declares as true to keep Story 050's chase view and Tokens (_apply_story_050_off()).
const CLOSE_CHASE_CONSTANT: StringName = &"CLOSE_CHASE"
const MORE_TOKENS_CONSTANT: StringName = &"MORE_TOKENS"
const TOKEN_STOCK_PATH_050: String = "res://src/gameplay/maps/data/token_stock.tres"
const TOKEN_COUNTS_049: Dictionary = {&"motorbike": 5, &"buggy": 3, &"truck": 2, &"gyrocopter": 2}
const CHASE_OFFSET_049: Vector3 = Vector3(0.0, 7.0, 13.0)
## The constant a scenario script declares as true to keep the drive and the numbers of Story 049 (_apply_full_throttle_off()).
const FULL_THROTTLE_CONSTANT: StringName = &"FULL_THROTTLE"
## Each type's spot_turn_rate before Story 049, by stats path, and the Turret's range.
const SPOT_TURN_RATES_048: Dictionary = {
	"res://src/gameplay/units/data/motorbike_stats.tres": 1.4,
	"res://src/gameplay/units/data/buggy_stats.tres": 1.15,
	"res://src/gameplay/units/data/truck_stats.tres": 0.45,
	"res://src/gameplay/units/data/gyrocopter_stats.tres": 0.77,
}
const TURRET_RANGE_048: float = 35.0
const MINE_SETTINGS_PATH_048: String = "res://src/gameplay/mines/data/mine_settings.tres"
## Every wall's data, which since Story 046 no longer spares its owner's Shots (spared_by_owner false).
const WALL_STATS_PATH_046: String = "res://src/gameplay/defences/data/flag_wall_stats.tres"
## The ammunition zone's marking before Story 045: the Shots' tracer colour (ammo_building.tscn's paint).
const LEGACY_044_AMMO_ZONE_COLOUR: Color = Color(1, 0.95, 0.55, 1)
const SECONDARY_NODES: Array[String] = ["World/Player1NitroBooster", "World/Player2NitroBooster", "World/Player1SmokeLauncher",
	"World/Player2SmokeLauncher", "World/Player1FlagDropper", "World/Player2FlagDropper", "Views/Player1View/SubViewport/Player1SecondaryStatus", "Views/Player2View/SubViewport/Player2SecondaryStatus"]
## Each type's Fuel burn before Story 036, by type_id: [fuel_use, fuel_use_idle] per second.
const LEGACY_036_FUEL_RATES: Dictionary = {
	&"motorbike": [2.0, 0.5], &"buggy": [2.5, 0.625], &"truck": [3.0, 0.75], &"gyrocopter": [5.0, 1.25]}
## The HUD of stories 006 to 032, with the Fuel line and no resource bars (Story 036).
const FROZEN_HUD_SCENE: PackedScene = preload("res://tools/evidence/frozen/player_hud_story_032.tscn")
## The Ammo line of story 022, which the shipped launch scene no longer holds (Story 036).
const AMMO_COUNT_SCENE: PackedScene = preload("res://src/ui/hud/ammo_count.tscn")
## The share of the tank a new Unit started with in every output written before Story 022, the half of Story 006
## (_apply_ammo_off()), beside LEGACY_FUEL_USE: the data says 1.0 now.
const LEGACY_SPAWN_FUEL_FRACTION: float = 0.5
## The constant a scenario script declares as true to keep the Fuel building of Story 023: the two Fuel zones on Map 01 and no Fuel
## Can on it, instead of the nine Fuel Cans every older output was measured with (_apply_fuel_building_off()).
const FUEL_BUILDING_CONSTANT: StringName = &"FUEL_BUILDING"
## The constant a scenario script declares as true to keep the ammunition buildings of Story 024: the two ammunition buildings on Map
## 01, each with its ammunition zone, and the Map's supply zones handed to both MineLayers (a lay refused in or near any of them),
## instead of the Map every older output was measured on, with no ammunition building and no zone that refuses a Mine
## (_apply_ammo_buildings_off()).
const AMMO_BUILDINGS_CONSTANT: StringName = &"AMMO_BUILDINGS"
## The two ammunition buildings of Map 01 by node name under the Map, west before east: each holds its ammunition zone.
const AMMO_BUILDING_NAMES: Array[StringName] = [&"AmmoBuildingWest", &"AmmoBuildingEast"]
## The Map's depot, by path from the Map: the Fuel zones stand under it, and the five Fuel Cans of Story 007 stood under it.
const MAP_DEPOT_PATH: NodePath = ^"Depot"
## The nine Fuel Cans of Map 01 as Story 022 left them, in a byte-checkable scene (tools/evidence/frozen/): the four that were
## the Map's children, after the Depot, and the five that were the Depot's last children. Evidence-only: nothing under src/
## uses it.
const FROZEN_FUEL_CANS_SCENE: PackedScene = preload("res://tools/evidence/frozen/fuel_cans_story_022.tscn")
## The four Cans that were children of the Map, in their old order: the first right after the Depot.
const MAP_FUEL_CAN_NAMES: Array[StringName] = [&"FuelCanCanyonWest", &"FuelCanCanyonEast", &"FuelCanFlatWest", &"FuelCanFlatEast"]
## The five Cans that were the Depot's last children, in their old order.
const DEPOT_FUEL_CAN_NAMES: Array[StringName] = [&"FuelCanDepot1", &"FuelCanDepot2", &"FuelCanDepot3", &"FuelCanDepot4", &"FuelCanDepot5"]
## The shipped Gyrocopter model scene, by path: a UnitStats whose model is this scene takes the frozen copy below.
const SHIPPED_GYROCOPTER_MODEL_PATH: String = "res://src/gameplay/units/models/gyrocopter_mesh_model.tscn"
## The Gyrocopter's model scene as Story 019 left it, a byte copy taken at the start of Story 020
## (tools/evidence/frozen/): hover_height 0.78 m, the rise over the cliffs and the cover, and the smoke Story 017
## exports. Evidence-only: nothing under src/ uses it.
const FROZEN_GYROCOPTER_MODEL: PackedScene = preload("res://tools/evidence/frozen/gyrocopter_model_story_019.tscn")
## The constant a scenario script declares as true to keep the Gyrocopter model the build ships with since Story 025: the main
## rotor and the pusher propeller turn, each trailing a smear (_apply_rotors_off()).
const ROTORS_CONSTANT: StringName = &"ROTORS"
## The Gyrocopter's mesh file as Story 024 left it, a byte copy taken at the start of Story 025 (tools/evidence/frozen/): the
## Accent and the Neutral and nothing that turns. Evidence-only: nothing under src/ uses it.
const FROZEN_GYROCOPTER_MESH_FILE: PackedScene = preload("res://tools/evidence/frozen/wasteland_gyrocopter_story_024.glb")
## The constant a scenario script declares as true to keep the tyre tracks of Story 026: the Map's TyreTracks node stays, so the
## ground Units' tyres leave tracks, instead of the Map every older output was measured on, with none (_apply_tyre_tracks_off()).
const TYRE_TRACKS_CONSTANT: StringName = &"TYRE_TRACKS"
## The constant a scenario script declares as true to keep the see-through silhouette of Story 027: both Units dress their models
## with it and both cameras never draw the other Player's silhouette layer, instead of the Units and cameras every older output
## was measured with, which have none (_apply_see_through_off()).
const SEE_THROUGH_CONSTANT: StringName = &"SEE_THROUGH"
## The Turret of Story 013 as it was measured, kept as a byte copy (tools/evidence/frozen/): a drum
## 1 m tall, a collider 1.8 m tall and no damaged look. Evidence-only: nothing under src/ uses it.
const FROZEN_TURRET_SCENE: PackedScene = preload("res://tools/evidence/frozen/turret_story_013.tscn")
## The shipped Turret, the one Map 01's Bases instance and the scenarios of Story 015 fixture.
const SHIPPED_TURRET_SCENE: PackedScene = preload("res://src/gameplay/defences/turret.tscn")
## The shared Turret stats, where the fractions of the damaged looks are data.
const TURRET_STATS_PATH: String = "res://src/gameplay/defences/data/turret_stats.tres"
## The Story 007 spawn point of a compound Base and the two side spots that were its spares: the
## nodes _apply_defences_off() hands back to the Base.
const STORY_007_SPAWN_POINT: NodePath = ^"SpawnPoint"
## The two side spots of a compound Base's Garage, in the order of its spare_spawn_points.
const STORY_007_SPARE_SPOTS: Array[NodePath] = [^"SpareSpawnLeft", ^"SpareSpawnRight"]
## The chase view of Stories 001 to 009 (the second view of each Player's list in the launch scene):
## the settings every scenario that does not declare SHIPPED_CAMERA runs on.
const CHASE_CAMERA_SETTINGS: ChaseCameraSettings = preload("res://src/gameplay/camera/data/chase_camera_settings.tres")
## Raw physics ticks confirm_choices() waits for the chosen Units to appear before it gives up: the
## bench settle, the key's tick and margin.
const CHOICE_LIMIT_TICKS: int = 120
## The scenarios written before Story 007, each measured on the 80 m greybox composition (the
## greybox field with its two Bases, the terrain stand-ins and the five greybox Fuel Cans): the
## runner rebuilds that composition for them (_apply_greybox_composition()), so their outputs stay
## what they were. fps, Story 002's windowed frame-rate tool, was measured on the greybox field too
## and keeps it. A scenario that is not listed runs on the main composition, Map 01.
const GREYBOX_SCENARIOS: Array[StringName] = [&"layout", &"isolation", &"simultaneous",
	&"showcase", &"fps", &"bases", &"destruction", &"countdown", &"respawn_showcase",
	&"flag_run", &"hud", &"round_over", &"flag_showcase", &"units", &"weapons", &"gyro",
	&"choice", &"units_showcase", &"fuel", &"fuel_cans", &"fuel_showcase"]
## The greybox field the older scenarios were measured on: Story 001's flat 80 m field with the two
## Bases of Story 003. It extends MapField, so the launch scene takes it as its field.
const GREYBOX_FIELD_SCENE: PackedScene = preload("res://src/gameplay/maps/greybox_field.tscn")
## The terrain stand-ins of Story 005 (the 4 m cliff block and the water strip).
const TERRAIN_STAND_INS_SCENE: PackedScene = preload("res://src/gameplay/maps/terrain_stand_ins.tscn")
## The five greybox Fuel Cans of Story 006.
const GREYBOX_FUEL_CANS_SCENE: PackedScene = preload("res://src/gameplay/maps/greybox_fuel_cans.tscn")
## Tokens of every Unit type in the stock the runner gives a scenario that asks for none of its own
## (_apply_token_stock(); the class doc says why): enough that no older scenario runs out. A
## fixture of the tools, so it lives here and not in src/.
const LEGACY_TOKEN_COUNT: int = 99
## The constant a scenario script declares (const STOCK_COUNTS: Dictionary = {&"motorbike": 2, ...},
## type_id to count) for a Token stock of its own.
const STOCK_COUNTS_CONSTANT: StringName = &"STOCK_COUNTS"
## The constant a scenario script declares (const USE_MAP_STOCK: bool = true) to keep the Map's own
## Token stock.
const USE_MAP_STOCK_CONSTANT: StringName = &"USE_MAP_STOCK"
## Player 1's colour as the older scenarios were measured with it (Story 002's body material): the
## launch scene gives Player 1's Unit the Team Orange of Story 007, and the runner puts this back as
## its team_material for the greybox composition.
const PLAYER_1_BODY_MATERIAL: Material = preload("res://src/gameplay/split_screen/data/player_1_body_material.tres")
## Player 2's colour as the older scenarios were measured with it, put back in place of the Team
## Teal of Story 007 (see PLAYER_1_BODY_MATERIAL).
const PLAYER_2_BODY_MATERIAL: Material = preload("res://src/gameplay/split_screen/data/player_2_body_material.tres")
## The greybox model of each Unit type (by UnitStats.type_id) the older scenarios were measured
## with: the shipped data points UnitStats.model at the concept-kit models of Story 007, and the
## runner puts these back for GREYBOX_SCENARIOS (_apply_greybox_models()).
const GREYBOX_MODELS: Dictionary[StringName, PackedScene] = {
	&"motorbike": preload("res://src/gameplay/units/models/motorbike_model.tscn"),
	&"buggy": preload("res://src/gameplay/units/models/buggy_model.tscn"),
	&"truck": preload("res://src/gameplay/units/models/truck_model.tscn"),
	&"gyrocopter": preload("res://src/gameplay/units/models/gyrocopter_model.tscn"),
}
## The scenarios written on Map 01 before Story 009, those of Stories 007 and 008. With
## GREYBOX_SCENARIOS they are every scenario written before Story 009: the runner gives them the
## data they were measured with (_apply_pre_009_data()) and these the Map they were measured on
## (_apply_pre_009_map()). A scenario that is not listed runs on the shipped data.
const PRE_009_MAP_SCENARIOS: Array[StringName] = [&"map_layout", &"map_edges", &"map_ford",
	&"map_bases", &"map_cover", &"map_showcase", &"map_legibility", &"map_fps", &"tokens",
	&"tokens_data", &"token_choice", &"loss", &"token_ui", &"token_layout", &"tokens_showcase"]
## The spot turn rate every scenario written before Story 009 was measured with: none, so a standing
## Unit did not turn (UnitStats.spot_turn_rate, which Story 009 added).
const PRE_009_SPOT_TURN_RATE: float = 0.0
## The idle Fuel rate every scenario written before Story 009 was measured with: none, so a standing
## Unit burned nothing (UnitStats.fuel_use_idle, which Story 009 added).
const PRE_009_FUEL_USE_IDLE: float = 0.0
## The Shot mask every scenario written before Story 009 was measured with: the map, the units and
## the gyrocopters layers, before Story 009 added the cover layer (the units scenario prints it).
const PRE_009_SHOT_COLLISION_MASK: int = 19
## The physics layer Map 01's cover was on before Story 009 moved it to the cover layer: the map
## layer, which stops the Gyrocopter as well.
const PRE_009_COVER_LAYER: int = 1
## The cover layer Story 009 added (project.godot layer 7, value 64) to the ground types' collision
## masks, 35 to 99: taken out of every type's mask again for the scenarios written before it (the
## units scenario checks each mask).
const COVER_LAYER: int = 64
## Map 01's cover, by path from the Map: every CollisionObject3D under it is a piece of cover.
const MAP_COVER_PATH: NodePath = ^"Cover"
## Map 01's depot tanks, by path from the Map: each tank's TANK_COLLIDER_NAME child is Story 009's.
const MAP_TANKS_PATH: NodePath = ^"Depot/FuelTanks"
## The name of a depot tank's collider, a StaticBody3D child of the tank (Story 009 AC-1).
const TANK_COLLIDER_NAME: StringName = &"Collider"

## Position of the throttle key in a layout (PLAYER_1_KEYS, PLAYER_2_KEYS).
const SLOT_THROTTLE: int = 0
## Position of the reverse key in a layout.
const SLOT_REVERSE: int = 1
## Position of the steer-left key in a layout.
const SLOT_STEER_LEFT: int = 2
## Position of the steer-right key in a layout.
const SLOT_STEER_RIGHT: int = 3

## Window size AC-1 asks for, pixels. A headless run has no real window (it starts at 64 x 64), so
## there the harness sets the window to this size before a scenario looks.
const WINDOW_SIZE: Vector2i = Vector2i(1280, 720)
## Ticks each reset waits, with every key up, before the tracks start counting.
const SETTLE_TICKS: int = 5
## Corridor starts (isolation, simultaneous), metres. Player 1 faces -Z, Player 2 faces +Z.
const CORRIDOR_1_START: Vector3 = Vector3(-10.0, 0.0, 20.0)
## Player 2's corridor start, metres (see CORRIDOR_1_START).
const CORRIDOR_2_START: Vector3 = Vector3(10.0, 0.0, -20.0)
## Half the side of the playfield, metres (the inner faces of the four walls, greybox_field.tscn).
const FIELD_HALF_EXTENT: float = 40.0

## The scenario running, from --scenario=NAME: the second word of every SPLIT, CHECK and RESULT line.
var scenario: StringName = &""
## The launch scene under test: the field, both Units and both cameras a scenario reads.
var split: SplitScreen
## The scene a kit instances for a Turret of its own (a fixture): the frozen Turret of Story 013,
## or the shipped one for a scenario that declares TURRET_LOOKS (the class doc says why).
var turret_scene: PackedScene = FROZEN_TURRET_SCENE
## One track per Player, in the order of PLAYER_1 and PLAYER_2, updated after every tick.
var tracks: Array[UnitTrack] = []
## Name of the stretch running, printed in the SPLIT lines. apply() sets it from the step.
var phase: StringName = &"start"
## Ticks between SPLIT progress lines; 0 prints none.
var report_ticks: int = 0
## Physics ticks simulated so far. Simulated time is this over the tick rate; read it, do not set it.
var ticks: int = 0
## The Players whose unit_spawned signal arrived before the scenario started, in the order it came:
## the start of the Round. MatchController.begin() runs inside add_child(split), before any scenario
## exists to connect to it, and the spawns follow the runner's confirm_choices() a few ticks later,
## so the runner listens from before begin() until both spawns have arrived and keeps the log here.
## Empty for a scenario that declares OWN_CHOICE.
var round_start_spawns: Array[int] = []
## Closest the two Units' origins came since the run began, metres.
var separation_min: float = INF
## The least room any Unit's origin left to a wall since the run began, metres.
var wall_clearance_min: float = INF
## Which physical keys the harness holds down now, so an event is sent only on a change; set_key()
## and _reassert_held_keys() check it against the engine's own key state (TD-009).
var _held: Dictionary[int, bool] = {}
## One flag per Player: true while the runner itself holds that Player's fire key for a choice
## (confirm_choices()). That key is released on the tick the controller accepts the choice; a fire
## key a scenario holds is never touched.
var _choice_key_held: Array[bool] = [false, false]
var _ticks_per_second: int = 60
## The running scenario's watchdog, simulated seconds (_scenario_watchdog_seconds()).
var _watchdog_seconds: float = WATCHDOG_SECONDS
var _checks: int = 0
var _failed: int = 0
var _finished: bool = false


func _ready() -> void:
	_ticks_per_second = Engine.physics_ticks_per_second
	scenario = _read_scenario()
	if not SCENARIOS.has(scenario):
		# quit() only takes effect after the current frame, so nothing else may run first.
		_finished = true
		print("RESULT %s fail checks=0 failed=0 reason=unknown_scenario %s" % [
			"none" if scenario.is_empty() else String(scenario), _usage()])
		get_tree().quit(EXIT_USAGE)
		return
	Input.use_accumulated_input = false
	_watchdog_seconds = _scenario_watchdog_seconds(SCENARIOS[scenario])
	get_tree().create_timer(_watchdog_seconds).timeout.connect(_on_watchdog)
	_apply_story_050_off(SCENARIOS[scenario])
	_apply_full_throttle_off(SCENARIOS[scenario])
	_apply_fuel_burn_off(SCENARIOS[scenario])
	_apply_secondary_off(SCENARIOS[scenario])
	_apply_teams_off(SCENARIOS[scenario])
	_apply_bushes_off(SCENARIOS[scenario])
	_apply_map_choice_off(SCENARIOS[scenario])
	_apply_flag_open_off(SCENARIOS[scenario])
	_apply_stick_drive_off(SCENARIOS[scenario])
	_apply_fire_heights_off(SCENARIOS[scenario])
	_apply_flying_sight_off(SCENARIOS[scenario])
	if LEGACY_SCENARIOS.has(scenario):
		_apply_legacy_data()
	if LEGACY_SCENARIOS.has(scenario) or STORY_005_SCENARIOS.has(scenario):
		_apply_no_fuel_data()
	if GREYBOX_SCENARIOS.has(scenario):
		_apply_greybox_models()
	if GREYBOX_SCENARIOS.has(scenario) or PRE_009_MAP_SCENARIOS.has(scenario):
		_apply_pre_009_data()
	_apply_swap_off(SCENARIOS[scenario])
	_apply_mines_off(SCENARIOS[scenario])
	_apply_badly_damaged_off(SCENARIOS[scenario])
	_apply_heights_off(SCENARIOS[scenario])
	_apply_rotors_off(SCENARIOS[scenario])
	_apply_crash_off(SCENARIOS[scenario])
	_apply_ammo_off(SCENARIOS[scenario])
	_apply_turret_looks_data_off(SCENARIOS[scenario])
	turret_scene = SHIPPED_TURRET_SCENE if _keeps_turret_looks(SCENARIOS[scenario]) else FROZEN_TURRET_SCENE
	split = SPLIT_SCENE.instantiate() as SplitScreen
	_apply_map_scene(split, SCENARIOS[scenario])
	_apply_full_throttle_nodes_off(split, SCENARIOS[scenario])
	_apply_lineup(split, SCENARIOS[scenario])
	_apply_map_choice_nodes_off(split, SCENARIOS[scenario])
	_apply_secondary_nodes_off(split, SCENARIOS[scenario])
	_apply_chase_camera(split, SCENARIOS[scenario])
	if GREYBOX_SCENARIOS.has(scenario):
		_apply_greybox_composition(split)
	_apply_field_panels_off(split, SCENARIOS[scenario])
	_apply_ammo_buildings_off(split, SCENARIOS[scenario])
	_apply_fuel_building_off(split, SCENARIOS[scenario])
	_apply_tyre_tracks_off(split, SCENARIOS[scenario])
	_apply_see_through_off(split, SCENARIOS[scenario])
	if PRE_009_MAP_SCENARIOS.has(scenario):
		_apply_pre_009_map(split)
	_apply_defences_off(split, SCENARIOS[scenario])
	_apply_turrets_off(split, SCENARIOS[scenario])
	_apply_turret_looks_off(split, SCENARIOS[scenario])
	_apply_wall_panels_off(split, SCENARIOS[scenario])
	_apply_garage_panels_off(split, SCENARIOS[scenario])
	_apply_mine_counts_off(split, SCENARIOS[scenario])
	_apply_resource_bars_off(split, SCENARIOS[scenario])
	_apply_ammo_counts_off(split, SCENARIOS[scenario])
	_apply_explosions_off(split, SCENARIOS[scenario])
	_apply_token_stock(split, SCENARIOS[scenario])
	if split.match_controller != null:
		split.match_controller.unit_spawned.connect(_on_round_start_spawn)
		split.match_controller.unit_chosen.connect(_on_choice_confirmed)
	add_child(split)
	_run()


## Runs the chosen scenario as a coroutine: after the first frame, so the window and the layout
## exist, then the Players' first choice (confirm_choices(), unless the script declares OWN_CHOICE),
## then the scenario script's run(), which awaits physics ticks. The log of the Round's start
## (round_start_spawns) is closed before run(), so a respawn is never taken for it, and a legacy
## scenario gets its re-choice after every destruction from here on.
func _run() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		get_window().size = WINDOW_SIZE
	var script: GDScript = SCENARIOS[scenario]
	if not bool(script.get_script_constant_map().get(OWN_CHOICE_CONSTANT, false)):
		await confirm_choices()
	if split.match_controller != null:
		if split.match_controller.unit_spawned.is_connected(_on_round_start_spawn):
			split.match_controller.unit_spawned.disconnect(_on_round_start_spawn)
		if LEGACY_SCENARIOS.has(scenario):
			split.match_controller.unit_destroyed.connect(_on_legacy_destroyed)
	tracks.append(UnitTrack.new(split.player_1_unit))
	tracks.append(UnitTrack.new(split.player_2_unit))
	var entry: RefCounted = script.new()
	await entry.run(self)


## Gives the scenarios written before Story 005 (LEGACY_SCENARIOS) the data they were measured with,
## on the shared resources and before the launch scene is instanced, so that their outputs stay what
## they were while the shipped data changes: on motorbike_stats.tres the Motorbike's collision mask
## (LEGACY_MOTORBIKE_COLLISION_MASK) and hit points (LEGACY_MOTORBIKE_HIT_POINTS), on
## match_rules.tres the debug damage (LEGACY_DEBUG_DAMAGE), which the shipped data sets to zero so
## the debug keys are off in the game (the code stays, gated by the data). Each resource that fails
## to load is an error and is skipped. A scenario of Story 005 or later runs on the shipped data.
func _apply_legacy_data() -> void:
	var motorbike: UnitStats = load(MOTORBIKE_STATS_PATH) as UnitStats
	if motorbike == null:
		push_error("split_screen_harness: %s did not load as UnitStats, so the legacy Motorbike data is not applied." % MOTORBIKE_STATS_PATH)
	else:
		motorbike.collision_mask = LEGACY_MOTORBIKE_COLLISION_MASK
		motorbike.max_hit_points = LEGACY_MOTORBIKE_HIT_POINTS
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the legacy debug damage is not applied." % MATCH_RULES_PATH)
		return
	rules.debug_damage = LEGACY_DEBUG_DAMAGE


## Gives the scenarios written before Story 006 (LEGACY_SCENARIOS and STORY_005_SCENARIOS) the Fuel
## burn rate they were measured with, before the launch scene is instanced: LEGACY_FUEL_USE on every
## UnitStats of match_rules.tres's unit_types, the shared resources the Units spawn with (one cached
## object per type). Their Units still get a tank at every spawn and burn nothing, so their outputs
## stay what they were. Rules that fail to load are an error, and nothing is applied.
func _apply_no_fuel_data() -> void:
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the legacy Fuel burn rate is not applied." % MATCH_RULES_PATH)
		return
	for stats: UnitStats in rules.unit_types:
		if stats != null:
			stats.fuel_use = LEGACY_FUEL_USE


## Rebuilds the greybox composition inside a freshly instanced launch scene, for GREYBOX_SCENARIOS,
## before it enters the tree (SplitScreen._ready() begins the Round when it does): frees World's Map
## at once (remove_child() and free(), so none of its nodes stays in a node group for a frame),
## instances the greybox field, the terrain stand-ins and the greybox Fuel Cans under their old
## names at World child indices 0, 1 and 2 (the tree order the outputs were measured with), makes
## the new nodes owned by the launch scene and points split.field at the greybox field: the export
## was resolved to the Map when the scene was instanced, so it would dangle once the Map is freed.
## The field has no Token stock of its own; _apply_token_stock() gives it one, as for every
## scenario. It also gives both Units back the Player body materials the older outputs were measured
## with as their team_material (PLAYER_1_BODY_MATERIAL, PLAYER_2_BODY_MATERIAL), in place of the
## Team materials of Story 007 the launch scene sets (Story 007 AC-11: those two files stay as they
## are for the greybox composition).
func _apply_greybox_composition(root: SplitScreen) -> void:
	var world: Node3D = root.get_node("World") as Node3D
	var map: Node = world.get_node("Map")
	world.remove_child(map)
	map.free()
	var field: GreyboxField = GREYBOX_FIELD_SCENE.instantiate() as GreyboxField
	field.name = &"GreyboxField"
	field.unique_name_in_owner = true
	var terrain: Node = TERRAIN_STAND_INS_SCENE.instantiate()
	terrain.name = &"TerrainStandIns"
	var fuel_cans: Node = GREYBOX_FUEL_CANS_SCENE.instantiate()
	fuel_cans.name = &"FuelCans"
	var stand_ins: Array[Node] = [field, terrain, fuel_cans]
	for index: int in stand_ins.size():
		world.add_child(stand_ins[index])
		world.move_child(stand_ins[index], index)
		stand_ins[index].owner = root
	root.field = field
	root.player_1_unit.team_material = PLAYER_1_BODY_MATERIAL
	root.player_2_unit.team_material = PLAYER_2_BODY_MATERIAL


## Gives every UnitStats of match_rules.tres's unit_types back its greybox model (GREYBOX_MODELS,
## by type_id) for GREYBOX_SCENARIOS, on the shared resources before the launch scene is instanced,
## as _apply_no_fuel_data() does for the Fuel: the units scenario prints each model's bounds, and
## the launch scene's warm-up and every spawn then instance the models the outputs were measured
## with. A type with no greybox model keeps its own; rules that fail to load are an error.
func _apply_greybox_models() -> void:
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the greybox models are not applied." % MATCH_RULES_PATH)
		return
	for stats: UnitStats in rules.unit_types:
		if stats != null and GREYBOX_MODELS.has(stats.type_id):
			stats.model = GREYBOX_MODELS[stats.type_id]


## Gives every scenario written before Story 009 (GREYBOX_SCENARIOS and PRE_009_MAP_SCENARIOS) the
## data it was measured with, on the shared resources before the launch scene is instanced:
## PRE_009_SPOT_TURN_RATE and PRE_009_FUEL_USE_IDLE on every UnitStats of match_rules.tres's
## unit_types (one cached object per type, the one the Units spawn with), so a standing Unit neither
## turns nor burns, COVER_LAYER taken out of each type's collision mask (the ground types' 99 back
## to 35; nothing is on that layer in those scenarios, as the greybox composition has no cover and
## _apply_pre_009_map() puts Map 01's back on the map layer) and PRE_009_SHOT_COLLISION_MASK on
## match_rules.tres. Rules that fail to load are an error, and nothing is applied.
func _apply_pre_009_data() -> void:
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the pre-009 data is not applied." % MATCH_RULES_PATH)
		return
	rules.shot_collision_mask = PRE_009_SHOT_COLLISION_MASK
	for stats: UnitStats in rules.unit_types:
		if stats != null:
			stats.spot_turn_rate = PRE_009_SPOT_TURN_RATE
			stats.fuel_use_idle = PRE_009_FUEL_USE_IDLE
			stats.collision_mask = stats.collision_mask & ~COVER_LAYER


## Gives the Map 01 scenarios written before Story 009 (PRE_009_MAP_SCENARIOS) the Map they were
## measured on, in the freshly instanced launch scene before it enters the tree: every
## CollisionObject3D under the Map's cover back on PRE_009_COVER_LAYER, and each depot tank's
## collider, which Story 009 added, removed and freed at once (remove_child() and free(), as
## _apply_greybox_composition() frees the Map). A Map with no cover or no tanks is an error, and
## nothing is changed.
func _apply_pre_009_map(root: SplitScreen) -> void:
	var map: Node = root.field
	var cover: Node = map.get_node_or_null(MAP_COVER_PATH) if map != null else null
	var tanks: Node = map.get_node_or_null(MAP_TANKS_PATH) if map != null else null
	if cover == null or tanks == null:
		push_error("split_screen_harness: the launch scene's Map has no %s or no %s, so the pre-009 Map is not applied." % [MAP_COVER_PATH, MAP_TANKS_PATH])
		return
	for body: Node in cover.find_children("*", "CollisionObject3D", true, false):
		(body as CollisionObject3D).collision_layer = PRE_009_COVER_LAYER
	for tank: Node in tanks.get_children():
		var collider: Node = tank.get_node_or_null(NodePath(String(TANK_COLLIDER_NAME)))
		if collider != null:
			tank.remove_child(collider)
			collider.free()


## Turns the swap at the own Base off (MatchRules.own_base_swap = false) on the shared
## match_rules.tres, before the scene is instanced, unless the scenario script declares
## OWN_BASE_SWAP (the class doc says why). The resource is the one object the scene's controller and
## match inputs hold, so nothing else is needed; rules that fail to load are an error.
func _apply_swap_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(OWN_BASE_SWAP_CONSTANT, false)):
		return
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the swap is not turned off." % MATCH_RULES_PATH)
		return
	rules.own_base_swap = false


## Takes the Flag Walls and the side spawn spots of Story 012 off a freshly instanced launch scene,
## before it enters the tree, unless the scenario script declares BASE_DEFENCES (the class doc says
## why). For each Map Base with a DEFENCES_NODE_NAME child: every color_meshes entry under it and
## every Structure under it, and only those, is dropped from its list; the node is removed and
## freed at once (remove_child() and free(), as _apply_greybox_composition() frees the Map); and
## the Story 007 spots are given back. A Base with no such child is left alone.
func _apply_defences_off(root: SplitScreen, script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(BASE_DEFENCES_CONSTANT, false)):
		return
	if root.field == null:
		return
	for base: Base in [root.field.player_1_base, root.field.player_2_base]:
		var defences: Node = null if base == null else base.get_node_or_null(NodePath(String(DEFENCES_NODE_NAME)))
		if defences == null:
			continue
		var meshes: Array[MeshInstance3D] = []
		for mesh: MeshInstance3D in base.color_meshes:
			if mesh == null or not defences.is_ancestor_of(mesh):
				meshes.append(mesh)
		base.color_meshes = meshes
		var kept: Array[Structure] = []
		for structure: Structure in base.structures:
			if structure == null or not defences.is_ancestor_of(structure):
				kept.append(structure)
		base.structures = kept
		base.remove_child(defences)
		defences.free()
		_give_back_story_007_spots(base)


## Takes the Turrets of Story 013 off a freshly instanced launch scene, before it enters the tree,
## unless the scenario script declares TURRETS (the class doc says why), and the two PlayerNotice
## Labels unless it declares TURRETS, MINES or AMMO (the notice line also shows the Mine refusals of
## Story 014 and the "Out of ammo" of Story 022). The Labels are freed first, for every scenario that declares neither, greybox or not. Then,
## for each Map Base with a TURRETS_NODE_NAME child: every color_meshes entry under it and every
## Structure under it, and only those, is dropped from its list, and the node is removed and freed
## at once. A Base with no such child is left alone.
func _apply_turrets_off(root: SplitScreen, script: GDScript) -> void:
	var constants: Dictionary = script.get_script_constant_map()
	var keeps_turrets: bool = bool(constants.get(TURRETS_CONSTANT, false))
	if not keeps_turrets and not bool(constants.get(MINES_CONSTANT, false)) and not bool(constants.get(AMMO_CONSTANT, false)):
		for node: Node in root.find_children("*", "PlayerNotice", true, false):
			node.get_parent().remove_child(node)
			node.free()
	if keeps_turrets or root.field == null:
		return
	for base: Base in [root.field.player_1_base, root.field.player_2_base]:
		var turrets: Node = null if base == null else base.get_node_or_null(NodePath(String(TURRETS_NODE_NAME)))
		if turrets == null:
			continue
		var meshes: Array[MeshInstance3D] = []
		for mesh: MeshInstance3D in base.color_meshes:
			if mesh == null or not turrets.is_ancestor_of(mesh):
				meshes.append(mesh)
		base.color_meshes = meshes
		var kept: Array[Structure] = []
		for structure: Structure in base.structures:
			if structure == null or not turrets.is_ancestor_of(structure):
				kept.append(structure)
		base.structures = kept
		base.remove_child(turrets)
		turrets.free()


## Whether the scenario script declares TURRET_LOOKS as true (the class doc says why).
func _keeps_turret_looks(script: GDScript) -> bool:
	return bool(script.get_script_constant_map().get(TURRET_LOOKS_CONSTANT, false))


## Takes the damaged looks of Story 015 out of the data every scenario that does not declare
## TURRET_LOOKS runs on: damaged_below emptied on the shared turret_stats.tres (one cached object,
## the one every Turret scene references) before the launch scene is instanced, so the frozen
## Turret, which has no damaged look, matches its fractions. Stats that fail to load are an error,
## and nothing is applied.
func _apply_turret_looks_data_off(script: GDScript) -> void:
	if _keeps_turret_looks(script):
		return
	var stats: TurretStats = load(TURRET_STATS_PATH) as TurretStats
	if stats == null:
		push_error("split_screen_harness: %s did not load as TurretStats, so the Turret's damaged looks are not turned off." % TURRET_STATS_PATH)
		return
	var none: Array[float] = []
	stats.damaged_below = none


## Puts the Turret of Story 013 back on every Map Base of a freshly instanced launch scene, before
## it enters the tree, unless the scenario script declares TURRET_LOOKS (the class doc says why):
## each Turret under a Base's TURRETS_NODE_NAME node is removed and freed at once (remove_child() and
## free(), as _apply_greybox_composition() frees the Map) and replaced by an instance of
## FROZEN_TURRET_SCENE with its name, child index and transform, owned by the launch scene. The
## Base's structures entry for it and its color_meshes entry under it (the band) are pointed at the
## new Turret: a NodePath export is resolved to nodes when the scene is instanced, so an entry left
## on the freed Turret would be walked, and Base._paint_color_meshes() would warn and leave a band
## unpainted. A Base with no such node (the greybox composition, or Turrets that
## _apply_turrets_off() stripped) is left alone.
func _apply_turret_looks_off(root: SplitScreen, script: GDScript) -> void:
	if _keeps_turret_looks(script) or root.field == null:
		return
	for base: Base in [root.field.player_1_base, root.field.player_2_base]:
		var turrets: Node = null if base == null else base.get_node_or_null(NodePath(String(TURRETS_NODE_NAME)))
		if turrets == null:
			continue
		for child: Node in turrets.get_children():
			var turret: Turret = child as Turret
			if turret == null:
				continue
			var fresh: Turret = FROZEN_TURRET_SCENE.instantiate() as Turret
			var listed: Array[Structure] = []
			for structure: Structure in base.structures:
				listed.append(fresh if structure == turret else structure)
			base.structures = listed
			var meshes: Array[MeshInstance3D] = []
			for mesh: MeshInstance3D in base.color_meshes:
				if mesh != null and turret.is_ancestor_of(mesh):
					meshes.append(fresh.get_node_or_null(turret.get_path_to(mesh)) as MeshInstance3D)
				else:
					meshes.append(mesh)
			base.color_meshes = meshes
			var index: int = turret.get_index()
			var place: Transform3D = turret.transform
			var turret_name: StringName = turret.name
			turrets.remove_child(turret)
			turret.free()
			fresh.name = turret_name
			turrets.add_child(fresh)
			turrets.move_child(fresh, index)
			fresh.transform = place
			fresh.owner = root


## Puts the five Base walls of Story 007 back on every Map Base of a freshly instanced launch scene, before
## it enters the tree, unless the scenario script declares WALL_PANELS (the class doc says why). For each
## Map Base with a WALLS_NODE_NAME child that holds all of the WALL_RUN_NAMES: every Structure under a
## run, and only those, is dropped from the Base's structures; each run is removed and freed at once
## (remove_child() and free(), as _apply_greybox_composition() frees the Map); and the StaticBody3D of the
## same name from FROZEN_BASE_WALLS_SCENE is put in its place, at the same child index, with the Base as
## the owner of it and of every node under it (the owner the nodes of the Base's own scene have). A Base
## with no such node, or whose runs are not all there (the greybox composition), is left alone.
func _apply_wall_panels_off(root: SplitScreen, script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(WALL_PANELS_CONSTANT, false)) or root.field == null:
		return
	for base: Base in [root.field.player_1_base, root.field.player_2_base]:
		var walls: Node = null if base == null else base.get_node_or_null(NodePath(String(WALLS_NODE_NAME)))
		if walls == null:
			continue
		var runs: Array[Node] = []
		for run_name: StringName in WALL_RUN_NAMES:
			runs.append(walls.get_node_or_null(NodePath(String(run_name))))
		if runs.has(null):
			continue
		var kept: Array[Structure] = []
		for structure: Structure in base.structures:
			var under_a_run: bool = false
			for run: Node in runs:
				under_a_run = under_a_run or (structure != null and run.is_ancestor_of(structure))
			if not under_a_run:
				kept.append(structure)
		base.structures = kept
		var frozen: Node = FROZEN_BASE_WALLS_SCENE.instantiate()
		for index: int in WALL_RUN_NAMES.size():
			var old: Node = frozen.get_node(NodePath(String(WALL_RUN_NAMES[index])))
			var place: int = runs[index].get_index()
			walls.remove_child(runs[index])
			runs[index].free()
			frozen.remove_child(old)
			var parts: Array[Node] = old.find_children("*", "", true, false)
			parts.append(old)
			for part: Node in parts:
				part.owner = null
			walls.add_child(old)
			walls.move_child(old, place)
			for part: Node in parts:
				part.owner = base
		frozen.free()


## Puts the three Garage walls of Story 007 back on every Map Base of a freshly instanced launch scene, before
## it enters the tree, unless the scenario script declares GARAGE_SCRAP_PANELS (the class doc says why). For
## each Map Base with a GARAGE_NODE_NAME child (_put_back_frozen_walls()): every Structure under one of the
## GARAGE_WALL_NAMES, and only those, is dropped from the Base's structures; each wall is removed and freed at
## once; and the StaticBody3D of the same name from FROZEN_GARAGE_WALLS_SCENE is put in its place, at the same
## child index, with the Base as the owner of it and of every node under it. A Base with no such node, or
## whose Garage lacks one of the walls, is left alone.
func _apply_garage_panels_off(root: SplitScreen, script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(GARAGE_SCRAP_PANELS_CONSTANT, false)) or root.field == null:
		return
	for base: Base in [root.field.player_1_base, root.field.player_2_base]:
		var garage: Node = null if base == null else base.get_node_or_null(NodePath(String(GARAGE_NODE_NAME)))
		if garage != null:
			_put_back_frozen_walls(base, garage, GARAGE_WALL_NAMES, FROZEN_GARAGE_WALLS_SCENE)


## Swaps the named children of a Base's holder node, each a Node3D that holds Wall Panels, for the
## StaticBody3D of the same names from a frozen scene (Story 019; the way _apply_wall_panels_off() does it for
## the Base walls): the Structures under them are dropped from the Base's structures first (a NodePath export
## is resolved when the scene is instanced, so a freed entry would be walked), each Node3D is removed and
## freed at once, and the frozen body takes its child index with the Base as the owner of it and of every node
## under it, the owner the nodes of the Base's own scene have. Nothing is changed when the holder lacks one of
## the names.
func _put_back_frozen_walls(base: Base, holder: Node, names: Array[StringName], frozen_scene: PackedScene) -> void:
	var runs: Array[Node] = []
	for run_name: StringName in names:
		runs.append(holder.get_node_or_null(NodePath(String(run_name))))
	if runs.has(null):
		return
	var kept: Array[Structure] = []
	for structure: Structure in base.structures:
		var under_a_run: bool = false
		for run: Node in runs:
			under_a_run = under_a_run or (structure != null and run.is_ancestor_of(structure))
		if not under_a_run:
			kept.append(structure)
	base.structures = kept
	var frozen: Node = frozen_scene.instantiate()
	for index: int in names.size():
		var old: Node = frozen.get_node(NodePath(String(names[index])))
		var place: int = runs[index].get_index()
		holder.remove_child(runs[index])
		runs[index].free()
		frozen.remove_child(old)
		var parts: Array[Node] = old.find_children("*", "", true, false)
		parts.append(old)
		for part: Node in parts:
			part.owner = null
		holder.add_child(old)
		holder.move_child(old, place)
		for part: Node in parts:
			part.owner = base
	frozen.free()


## Puts the two scrap walls of Story 007 back in the Map's cover of a freshly instanced launch scene, before
## it enters the tree, unless the scenario script declares GARAGE_SCRAP_PANELS (the class doc says why). A Map
## with a FIELD_WALLS_NODE_NAME child and a cover node (MAP_COVER_PATH): neutral_structures is emptied, the
## walls in the field are removed and freed at once with the 8 Wall Panels under them, and a
## SCRAP_WALLS_NODE_NAME Node3D is added as the last child of the cover, as it was, holding the StaticBody3D
## of the SCRAP_WALL_NAMES from FROZEN_SCRAP_WALLS_SCENE at child indices 0 and 1, the cover as the owner of
## it and of every node under it (the owner the nodes of the cover's own scene have). It runs after the
## greybox composition, which frees the Map (a field without the walls is left alone), and before
## _apply_pre_009_map(), which gives every CollisionObject3D under the cover the layer it had before Story
## 009, the frozen walls included and no Wall Panel (they are not under the cover).
func _apply_field_panels_off(root: SplitScreen, script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(GARAGE_SCRAP_PANELS_CONSTANT, false)) or root.field == null:
		return
	var map: MapField = root.field
	var walls: Node = map.get_node_or_null(NodePath(String(FIELD_WALLS_NODE_NAME)))
	var cover: Node = map.get_node_or_null(MAP_COVER_PATH)
	if walls == null or cover == null:
		return
	var none: Array[Structure] = []
	map.neutral_structures = none
	map.remove_child(walls)
	walls.free()
	var scrap: Node3D = Node3D.new()
	scrap.name = SCRAP_WALLS_NODE_NAME
	cover.add_child(scrap)
	scrap.owner = cover
	var frozen: Node = FROZEN_SCRAP_WALLS_SCENE.instantiate()
	for wall_name: StringName in SCRAP_WALL_NAMES:
		var old: Node = frozen.get_node(NodePath(String(wall_name)))
		frozen.remove_child(old)
		var parts: Array[Node] = old.find_children("*", "", true, false)
		parts.append(old)
		for part: Node in parts:
			part.owner = null
		scrap.add_child(old)
		for part: Node in parts:
			part.owner = cover
	frozen.free()


## Takes the ammunition buildings of Story 024 off a freshly instanced launch scene, before it enters the tree, unless the scenario
## script declares AMMO_BUILDINGS (the constant's doc says why): both buildings of AMMO_BUILDING_NAMES, with their zones and markings,
## are removed and freed at once (remove_child() and free(), so nothing stays in a group for a frame), and the Map's supply_zones is
## emptied first (a NodePath export is resolved to nodes when the scene is instanced, so a freed entry would be walked): no zone is
## then handed to the MineLayers, so no lay is refused at any zone, a Fuel zone included, as before the story. The Fuel zones stand or go
## with FUEL_BUILDING and refuel wherever they stand, listed or not. It runs before _apply_fuel_building_off(), so the four frozen Cans
## land right after the Depot as they did at 73de824. A field without the buildings (the greybox composition) is left alone.
func _apply_ammo_buildings_off(root: SplitScreen, script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(AMMO_BUILDINGS_CONSTANT, false)) or root.field == null:
		return
	root.field.supply_zones = []
	for building_name: StringName in AMMO_BUILDING_NAMES:
		var building: Node = root.field.get_node_or_null(NodePath(String(building_name)))
		if building != null:
			root.field.remove_child(building)
			building.free()


## Takes the tyre tracks of Story 026 off a freshly instanced launch scene, before it enters the tree, unless the scenario script
## declares TYRE_TRACKS (the class doc says why): the field's tyre_tracks is cleared first (a NodePath export is resolved to the node
## when the scene is instanced, so SplitScreen would hand a freed node the Units) and the node is removed and freed at once
## (remove_child() and free(), so nothing stays in a group for a frame). A field with no tracks (the greybox composition) is left alone.
func _apply_tyre_tracks_off(root: SplitScreen, script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(TYRE_TRACKS_CONSTANT, false)) or root.field == null:
		return
	var tracks: TyreTracks = root.field.tyre_tracks
	if tracks == null:
		return
	root.field.tyre_tracks = null
	tracks.get_parent().remove_child(tracks)
	tracks.free()


## Takes the see-through silhouette of Story 027 off a freshly instanced launch scene, before it enters the tree, unless the
## scenario script declares SEE_THROUGH (the class doc says why): both Units' silhouette is cleared, so no model they are given is
## dressed and SplitScreen hands the cameras no layer, so each draws every layer its settings do not hide, as every older output
## was measured. A scene whose Units are not assigned is left alone.
func _apply_see_through_off(root: SplitScreen, script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(SEE_THROUGH_CONSTANT, false)):
		return
	for unit: Unit in [root.player_1_unit, root.player_2_unit]:
		if unit != null:
			unit.silhouette = null


## Takes the Fuel building of Story 023 off a freshly instanced launch scene, before it enters the tree, unless the scenario script
## declares FUEL_BUILDING (the class doc says why), and gives it the nine Fuel Cans the older outputs were measured with: every
## Fuel SupplyZone under the Map, its marking with it, is dropped from the Map's supply_zones, removed and freed at once (remove_child() and free(), as
## _apply_greybox_composition() frees the Map, so nothing stays in a group for a frame), and the Cans of FROZEN_FUEL_CANS_SCENE are
## put back under their old names and in their old order, with the owner the nodes of the Map's and the Depot's own scenes had:
## the four of MAP_FUEL_CAN_NAMES as the Map's children right after the Depot, so the Dressing follows them, and the five of
## DEPOT_FUEL_CAN_NAMES as the Depot's last children, because a Can ticks under the Map before the Units and tree order is tick
## order. A field without a Depot (the greybox composition, which freed the Map with its Depot and zones and keeps its own five
## Cans) is left alone.
func _apply_fuel_building_off(root: SplitScreen, script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(FUEL_BUILDING_CONSTANT, false)) or root.field == null:
		return
	var map: Node = root.field
	var depot: Node = map.get_node_or_null(MAP_DEPOT_PATH)
	if depot == null:
		return
	var listed: Array[SupplyZone] = []
	for zone: SupplyZone in root.field.supply_zones:
		if zone != null and zone.kind != SupplyZone.Kind.FUEL:
			listed.append(zone)
	root.field.supply_zones = listed
	for node: Node in map.find_children("*", "SupplyZone", true, false):
		if (node as SupplyZone).kind == SupplyZone.Kind.FUEL:
			node.get_parent().remove_child(node)
			node.free()
	var frozen: Node = FROZEN_FUEL_CANS_SCENE.instantiate()
	var place: int = depot.get_index()
	for can_name: StringName in MAP_FUEL_CAN_NAMES:
		var can: Node = frozen.get_node(NodePath(String(can_name)))
		frozen.remove_child(can)
		can.owner = null
		map.add_child(can)
		place += 1
		map.move_child(can, place)
		can.owner = map
	for can_name: StringName in DEPOT_FUEL_CAN_NAMES:
		var can: Node = frozen.get_node(NodePath(String(can_name)))
		frozen.remove_child(can)
		can.owner = null
		depot.add_child(can)
		can.owner = depot
	frozen.free()


## Takes the Mines out of the data every scenario that does not declare MINES runs on (Story 014),
## on the shared resources before the launch scene is instanced: mine_capacity 0 on every UnitStats
## of match_rules.tres's unit_types (one cached object per type, the one the Units spawn with), so no
## type lays a Mine and no MineLayer ever emits or lays. Rules that fail to load are an error, and
## nothing is applied.
func _apply_mines_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(MINES_CONSTANT, false)):
		return
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the Mines are not turned off." % MATCH_RULES_PATH)
		return
	for stats: UnitStats in rules.unit_types:
		if stats != null:
			stats.mine_capacity = 0


## Takes the badly damaged state out of the data every scenario that does not declare BADLY_DAMAGED
## runs on (Story 017), on the shared resources before the launch scene is instanced:
## badly_damaged_fraction 0 on every UnitStats of match_rules.tres's unit_types (one cached object
## per type, the one the Units spawn with), so no Unit is ever badly damaged, no top speed changes,
## badly_damaged_changed is never emitted and no smoke node is ever instanced. Rules that fail to
## load are an error, and nothing is applied.
func _apply_badly_damaged_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(BADLY_DAMAGED_CONSTANT, false)):
		return
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the badly damaged state is not turned off." % MATCH_RULES_PATH)
		return
	for stats: UnitStats in rules.unit_types:
		if stats != null:
			stats.badly_damaged_fraction = 0.0


## Gives every scenario that does not declare HEIGHTS the Gyrocopter model it was measured with (Story 020), on the
## shared resources before the launch scene is instanced: every UnitStats of match_rules.tres's unit_types whose
## model is the shipped Gyrocopter scene (SHIPPED_GYROCOPTER_MODEL_PATH) takes the frozen copy
## (FROZEN_GYROCOPTER_MODEL), which hovers 0.78 m up and rises over the cliffs and the cover. It runs after
## _apply_greybox_models(), so a greybox scenario, whose Gyrocopter is no longer the shipped scene, keeps its
## greybox model. Rules that fail to load are an error, and nothing is applied.
func _apply_heights_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(HEIGHTS_CONSTANT, false)):
		return
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the Gyrocopter's rise is not given back." % MATCH_RULES_PATH)
		return
	for stats: UnitStats in rules.unit_types:
		if stats != null and stats.model != null and stats.model.resource_path == SHIPPED_GYROCOPTER_MODEL_PATH:
			stats.model = FROZEN_GYROCOPTER_MODEL


## Gives every scenario that does not declare ROTORS the Gyrocopter model it was measured with (Story 025), on the shared
## resources before the launch scene is instanced: every UnitStats of match_rules.tres's unit_types whose model is the shipped
## Gyrocopter scene or the frozen copy of Story 019 (it runs after _apply_heights_off(), so a scenario that does not declare
## HEIGHTS holds the frozen one) takes a scene packed from an instance of it with mesh_scene set to the byte copy of the old mesh
## file (FROZEN_GYROCOPTER_MESH_FILE) and rotor_settings null: the model then adds no pivot and no smear and draws the Accent
## and the Neutral of the old file. One scene is packed for each model scene and shared by every type that holds it. A greybox
## scenario, whose Gyrocopter is neither scene, keeps its greybox model. Rules that fail to load are an error, and nothing is
## applied.
func _apply_rotors_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(ROTORS_CONSTANT, false)):
		return
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the Gyrocopter's rotors are not taken off." % MATCH_RULES_PATH)
		return
	var packed: Dictionary = {}
	for stats: UnitStats in rules.unit_types:
		if stats == null or stats.model == null:
			continue
		var path: String = stats.model.resource_path
		if path != SHIPPED_GYROCOPTER_MODEL_PATH and path != FROZEN_GYROCOPTER_MODEL.resource_path:
			continue
		if not packed.has(path):
			packed[path] = _without_rotors(stats.model)
		stats.model = packed[path]


## A scene packed from an instance of a Gyrocopter model scene with its mesh file swapped for the old one and no rotor settings.
func _without_rotors(scene: PackedScene) -> PackedScene:
	var model: MeshUnitModel = scene.instantiate() as MeshUnitModel
	model.mesh_scene = FROZEN_GYROCOPTER_MESH_FILE
	model.rotor_settings = null
	var copy: PackedScene = PackedScene.new()
	copy.pack(model)
	model.free()
	return copy


## Takes the crash out of the data every scenario that does not declare GYRO_CRASH runs on (Story 021), on the shared
## resources before the launch scene is instanced: crash_speed 0 on every UnitStats of match_rules.tres's unit_types (one
## cached object per type, the one the Units spawn with), so no type ever crashes and a Gyrocopter flown into a Tall piece,
## the depot's tanks among them, only stops, as it did before the story. Rules that fail to load are an error, and nothing
## is applied.
func _apply_crash_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(GYRO_CRASH_CONSTANT, false)):
		return
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the crash is not turned off." % MATCH_RULES_PATH)
		return
	for stats: UnitStats in rules.unit_types:
		if stats != null:
			stats.crash_speed = 0.0


## Takes the ammunition and the full start out of the data every scenario that does not declare AMMO runs on (Story 022), on
## the shared resources before the launch scene is instanced: ammo_capacity 0 and spawn_fuel_fraction
## LEGACY_SPAWN_FUEL_FRACTION on every UnitStats of match_rules.tres's unit_types (one cached object per type, the one the
## Units spawn with), so no Weapon counts, spends or emits anything and a new Unit starts with the half tank the older
## outputs were measured with. Rules that fail to load are an error, and nothing is applied.
func _apply_ammo_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(AMMO_CONSTANT, false)):
		return
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the ammunition and the full start are not turned off." % MATCH_RULES_PATH)
		return
	for stats: UnitStats in rules.unit_types:
		if stats != null:
			stats.ammo_capacity = 0
			stats.spawn_fuel_fraction = LEGACY_SPAWN_FUEL_FRACTION


## Gives every UnitStats of match_rules.tres the Fuel burn it had before Story 036 (LEGACY_036_FUEL_RATES), on the shared
## resources, unless the scenario script declares RESOURCE_BARS. Runs before every other data helper, so the legacy and pre-009
## helpers still set their own values over it.
func _apply_fuel_burn_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(RESOURCE_BARS_CONSTANT, false)):
		return
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the old Fuel burn is not applied." % MATCH_RULES_PATH)
		return
	for stats: UnitStats in rules.unit_types:
		if stats != null and LEGACY_036_FUEL_RATES.has(stats.type_id):
			stats.fuel_use = LEGACY_036_FUEL_RATES[stats.type_id][0]
			stats.fuel_use_idle = LEGACY_036_FUEL_RATES[stats.type_id][1]


## Gives the shared TurretStats the sight of stories 013 to 036, a cliff hiding a flying target as it hides a ground one
## (flying_sight_extra_mask = sight_extra_mask), unless the scenario script declares TURRET_SEES_FLYING (Story 037).
func _apply_flying_sight_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(TURRET_SEES_FLYING_CONSTANT, false)):
		return
	var stats: TurretStats = load(TURRET_STATS_PATH) as TurretStats
	if stats == null:
		push_error("split_screen_harness: %s did not load as TurretStats, so the old Turret sight is not applied." % TURRET_STATS_PATH)
		return
	stats.flying_sight_extra_mask = stats.sight_extra_mask


## Puts the Map the scenario script names in MAP_SCENE in place of Map 01 in a freshly instanced launch scene, before any other
## helper reads its field (Story 038): SplitScreen.use_map(). A script that names none keeps Map 01; a path that does not load
## as a scene is an error and keeps Map 01.
## Plays the lineup a scenario declares (Story 048): const LINEUP_DEVICES and LINEUP_TEAMS, two arrays of ints, one entry
## per Player (a pad id or Lineup.KEYBOARD_1 / KEYBOARD_2, and Lineup.ORANGE / TEAL), handed to SplitScreen.apply_lineup()
## before the scene enters the tree. A scenario without them plays the scene's two Players as before.
func _apply_lineup(root: SplitScreen, script: GDScript) -> void:
	var constants: Dictionary = script.get_script_constant_map()
	if not constants.has(LINEUP_DEVICES_CONSTANT):
		return
	var devices: Array[int] = []
	devices.assign(constants[LINEUP_DEVICES_CONSTANT])
	var teams: Array[int] = []
	teams.assign(constants.get(LINEUP_TEAMS_CONSTANT, []))
	root.apply_lineup(Lineup.of(devices, teams))


## Gives Mines back the rule of stories 014 to 047, unless the scenario script declares const TEAMS: bool = true (Story 048):
## a Mine goes off under any ground Unit, its own Team's too (MineSettings.spares_own_team false).
func _apply_teams_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(TEAMS_CONSTANT, false)):
		return
	var settings: MineSettings = load(MINE_SETTINGS_PATH_048) as MineSettings
	if settings != null:
		settings.spares_own_team = false


func _apply_map_scene(root: SplitScreen, script: GDScript) -> void:
	var path: String = String(script.get_script_constant_map().get(MAP_SCENE_CONSTANT, ""))
	if path.is_empty():
		return
	var map_scene: PackedScene = load(path) as PackedScene
	if map_scene == null:
		push_error("split_screen_harness: %s did not load as a scene, so the scenario plays Map 01." % path)
		return
	root.use_map(map_scene)


## Gives the shared TurretStats the ground sight of stories 013 to 037 (LEGACY_037_SIGHT_EXTRA_MASK) and takes the name of the
## sight layer away, unless the scenario script declares BUSHES (Story 038). Runs before _apply_flying_sight_off(), which copies
## the ground sight into the flying one for the scenarios written before Story 037.
func _apply_bushes_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(BUSHES_CONSTANT, false)):
		return
	ProjectSettings.set_setting(SIGHT_LAYER_SETTING, "")
	var stats: TurretStats = load(TURRET_STATS_PATH) as TurretStats
	if stats == null:
		push_error("split_screen_harness: %s did not load as TurretStats, so the old Turret sight is not applied." % TURRET_STATS_PATH)
		return
	stats.sight_extra_mask = LEGACY_037_SIGHT_EXTRA_MASK


## Erases the map choice's three actions from the InputMap, unless the scenario script declares MAP_CHOICE (Story 038): every
## scenario written before it counted the project's actions, keys and pad events without them.
func _apply_map_choice_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(MAP_CHOICE_CONSTANT, false)):
		return
	for action: StringName in MENU_ACTIONS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)


## Takes the way back to the map choice (MAP_CHOICE_NODES) out of a freshly instanced launch scene, unless the scenario script
## declares MAP_CHOICE (Story 038): each node is removed and freed at once, so the views hold the children they were measured with.
func _apply_map_choice_nodes_off(root: SplitScreen, script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(MAP_CHOICE_CONSTANT, false)):
		return
	for path: String in MAP_CHOICE_NODES:
		var node: Node = root.get_node_or_null(NodePath(path))
		if node != null:
			node.get_parent().remove_child(node)
			node.free()


## Gives the shared MatchRules the one Shot of stories 005 to 040, unless the scenario script declares FIRE_HEIGHTS (Story 041):
## the low and the high mask both LEGACY_040_SHOT_MASK, no lift for a high tracer, and the two high fire actions erased from the
## InputMap (PlayerFireInput then fires low only, and nothing is logged), so every Shot, the Turrets' at a Gyrocopter
## included, stops where it did and is drawn where it was.
func _apply_fire_heights_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(FIRE_HEIGHTS_CONSTANT, false)):
		return
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the old Shot is not applied." % MATCH_RULES_PATH)
	else:
		rules.shot_collision_mask = LEGACY_040_SHOT_MASK
		rules.high_shot_collision_mask = LEGACY_040_SHOT_MASK
		rules.high_shot_lift = 0.0
	for action: StringName in FIRE_HIGH_ACTIONS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)


## Gives the cached chase settings the view of stories 001 to 049 unless the scenario declares CLOSE_CHASE, and the shared
## Token stock the counts of stories 007 to 049 unless it declares MORE_TOKENS (Story 050). Before every other opt-out.
func _apply_story_050_off(script: GDScript) -> void:
	var constants: Dictionary = script.get_script_constant_map()
	if not bool(constants.get(CLOSE_CHASE_CONSTANT, false)):
		var chase: ChaseCameraSettings = CHASE_CAMERA_SETTINGS
		chase.offset = CHASE_OFFSET_049
		chase.look_ahead = 0.0
		chase.width_fov_degrees = 0.0
	if not bool(constants.get(MORE_TOKENS_CONSTANT, false)):
		var stock: TokenStock = load(TOKEN_STOCK_PATH_050) as TokenStock
		if stock != null:
			stock.counts.assign(TOKEN_COUNTS_049)


## Gives the shared data the numbers of stories 009 to 048, unless the scenario script declares FULL_THROTTLE (Story 049): the
## pad layout's throttle and reverse take the common dead zone (no full_throttle_suffixes), each type its old spot_turn_rate,
## the Turret its 35 m. On the cached resources, before every other opt-out, which may set them again.
func _apply_full_throttle_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(FULL_THROTTLE_CONSTANT, false)):
		return
	var layout: PadLayout = load(PAD_LAYOUT_PATH) as PadLayout
	if layout != null:
		layout.full_throttle_suffixes = PackedStringArray()
	for path: String in SPOT_TURN_RATES_048:
		var stats: UnitStats = load(path) as UnitStats
		if stats != null:
			stats.spot_turn_rate = SPOT_TURN_RATES_048[path]
	var turret: TurretStats = load(TURRET_STATS_PATH) as TurretStats
	if turret != null:
		turret.weapon_range = TURRET_RANGE_048


## Turns full_throttle off on every PlayerDriveInput of a freshly instanced launch scene, before it enters the tree, unless the
## scenario script declares FULL_THROTTLE (Story 049); the Players a lineup adds copy Player 2's.
func _apply_full_throttle_nodes_off(root: SplitScreen, script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(FULL_THROTTLE_CONSTANT, false)):
		return
	for node: Node in root.find_children("*", "", true, false):
		var drive: PlayerDriveInput = node as PlayerDriveInput
		if drive != null:
			drive.full_throttle = false


## Gives the shared pad layout the bindings of stories 032 to 039, the right trigger throttle and the left reverse, unless the
## scenario script declares STICK_DRIVE (Story 040): on the cached resource, before the launch scene is instanced, so its
## PadAssignment and every scenario that loads the layout by path read the old bindings.
func _apply_stick_drive_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(STICK_DRIVE_CONSTANT, false)):
		return
	var shipped: PadLayout = load(PAD_LAYOUT_PATH) as PadLayout
	if shipped == null:
		push_error("split_screen_harness: %s did not load as PadLayout, so the old pad layout is not applied." % PAD_LAYOUT_PATH)
		return
	shipped.bindings = FROZEN_PAD_LAYOUT.bindings.duplicate()
	shipped.deadzone = FROZEN_PAD_LAYOUT.deadzone


## Gives the shared data the Turret sight and the pad layout of stories 038 to 041, unless the scenario script declares SECONDARY
## (Story 042): the smoke layer out of both sight masks (before _apply_bushes_off() and _apply_flying_sight_off()), no name for
## layer 9, and for a scenario that declares STICK_DRIVE the layout of story 041 (X lays the Mine, LT fires low). A scenario
## without STICK_DRIVE gets story 032's layout from _apply_stick_drive_off().
func _apply_secondary_off(script: GDScript) -> void:
	var constants: Dictionary = script.get_script_constant_map()
	if bool(constants.get(SECONDARY_CONSTANT, false)):
		return
	ProjectSettings.set_setting(SMOKE_LAYER_SETTING, "")
	var truck: UnitStats = load(TRUCK_STATS_PATH_044) as UnitStats
	if truck != null:
		truck.mine_cooldown_seconds = 0.0
	var walls: StructureStats = load(WALL_STATS_PATH_046) as StructureStats
	if walls != null:
		walls.spared_by_owner = true
	var stats: TurretStats = load(TURRET_STATS_PATH) as TurretStats
	if stats != null:
		stats.sight_extra_mask &= ~SMOKE_LAYER_BIT
		stats.flying_sight_extra_mask &= ~SMOKE_LAYER_BIT
	if bool(constants.get(STICK_DRIVE_CONSTANT, false)):
		var shipped: PadLayout = load(PAD_LAYOUT_PATH) as PadLayout
		if shipped != null:
			shipped.bindings = FROZEN_PAD_LAYOUT_041.bindings.duplicate()
			shipped.deadzone = FROZEN_PAD_LAYOUT_041.deadzone


## Takes the secondary weapons' nodes (SECONDARY_NODES) out of a freshly instanced launch scene, unless the scenario script
## declares SECONDARY (Story 042): each is removed and freed at once.
func _apply_secondary_nodes_off(root: SplitScreen, script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(SECONDARY_CONSTANT, false)):
		return
	for path: String in SECONDARY_NODES:
		var node: Node = root.get_node_or_null(NodePath(path))
		if node != null:
			node.get_parent().remove_child(node)
			node.free()
	for node: Node in root.find_children("*", "", true, false):
		if node is Bush:
			(node as Bush).size = LEGACY_043_BUSH_SIZE
		elif node is PlayerHud:
			(node as PlayerHud).show_tokens_line = true
		elif node is SupplyZone:
			_restore_zone_look_044(node as SupplyZone)


## Gives a supply zone's marking its look before Story 045: lit, and an ammunition zone's in the Shots' tracer colour. The
## material is the scene's shared one, so every zone of the kind changes with it.
func _restore_zone_look_044(zone: SupplyZone) -> void:
	var slab: MeshInstance3D = zone.slab as MeshInstance3D
	if slab == null or slab.mesh == null:
		return
	var material: StandardMaterial3D = slab.mesh.surface_get_material(0) as StandardMaterial3D
	if material == null:
		return
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if zone.kind == SupplyZone.Kind.AMMO:
		material.albedo_color = LEGACY_044_AMMO_ZONE_COLOUR


## Gives the shared data the Flag rules of stories 013 to 038, unless the scenario script declares FLAG_OPEN (Story 039): the
## Turrets lock their Base's Flag again (TurretStats.locks_flag) and the Motorbike's Shots do nothing to a Wall Panel (the pair
## motorbike>flag_wall at 0 in the damage matrix).
func _apply_flag_open_off(script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(FLAG_OPEN_CONSTANT, false)):
		return
	var stats: TurretStats = load(TURRET_STATS_PATH) as TurretStats
	if stats == null:
		push_error("split_screen_harness: %s did not load as TurretStats, so the old Flag lock is not applied." % TURRET_STATS_PATH)
	else:
		stats.locks_flag = true
	var matrix: DamageMatrix = load(DAMAGE_MATRIX_PATH_039) as DamageMatrix
	if matrix == null:
		push_error("split_screen_harness: %s did not load as DamageMatrix, so the old Motorbike pair is not applied." % DAMAGE_MATRIX_PATH_039)
	else:
		matrix.multipliers[MOTORBIKE_WALL_PAIR] = 0.0


## Puts the HUD of story 032 back in a freshly instanced launch scene, before it enters the tree, unless the scenario script
## declares RESOURCE_BARS: each Player's PlayerHud is replaced by an instance of FROZEN_HUD_SCENE under the same name and index,
## with the same match_controller, unit, player_index and edge_style; for a scenario that declares AMMO each view also gets the
## Ammo line of story 022 back as its last child, where the launch scene held it (Story 036).
func _apply_resource_bars_off(root: SplitScreen, script: GDScript) -> void:
	var constants: Dictionary = script.get_script_constant_map()
	if bool(constants.get(RESOURCE_BARS_CONSTANT, false)):
		return
	var weapons: Array[Weapon] = [root.player_1_weapon, root.player_2_weapon]
	for index: int in weapons.size():
		var view: Node = root.get_node("Views/Player%dView/SubViewport" % (index + 1))
		var shipped: PlayerHud = view.get_node("Player%dHud" % (index + 1)) as PlayerHud
		if shipped == null:
			continue
		var frozen: PlayerHud = FROZEN_HUD_SCENE.instantiate() as PlayerHud
		frozen.match_controller = shipped.match_controller
		frozen.unit = shipped.unit
		frozen.player_index = shipped.player_index
		frozen.edge_style = shipped.edge_style
		var at: int = shipped.get_index()
		var hud_name: StringName = shipped.name
		view.remove_child(shipped)
		shipped.free()
		frozen.name = hud_name
		view.add_child(frozen)
		view.move_child(frozen, at)
		frozen.owner = root
		if bool(constants.get(AMMO_CONSTANT, false)):
			var line: AmmoCount = AMMO_COUNT_SCENE.instantiate() as AmmoCount
			line.weapon = weapons[index]
			line.name = "Player%dAmmoCount" % (index + 1)
			view.add_child(line)
			line.owner = root


## Frees both AmmoCount Labels of a freshly instanced launch scene, before it enters the tree, unless the scenario script
## declares AMMO (Story 022: camera_views counts every Control in each view, and the older outputs were measured without
## the line).
func _apply_ammo_counts_off(root: SplitScreen, script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(AMMO_CONSTANT, false)):
		return
	for node: Node in root.find_children("*", "AmmoCount", true, false):
		node.get_parent().remove_child(node)
		node.free()


## Frees both MineCount Labels of a freshly instanced launch scene, before it enters the tree, unless
## the scenario script declares MINES (Story 014: camera_views counts every Control in each view, and
## the older outputs were measured without the line).
func _apply_mine_counts_off(root: SplitScreen, script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(MINES_CONSTANT, false)):
		return
	for node: Node in root.find_children("*", "MineCount", true, false):
		node.get_parent().remove_child(node)
		node.free()


## Takes the explosion of Story 016 off a freshly instanced launch scene, before it enters the tree,
## unless the scenario script declares EXPLOSIONS (the class doc says why): explosion_scene is set to
## null, so SplitScreen connects nothing to unit_destroyed or round_started for it and no Explosion is
## ever added.
func _apply_explosions_off(root: SplitScreen, script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(EXPLOSIONS_CONSTANT, false)):
		return
	root.explosion_scene = null


## Gives a compound Base its Story 007 spawn assignment back: SpawnPoint as spawn_point and the two
## side spots as its spares. A spot the Base does not have is an error and nothing is changed.
func _give_back_story_007_spots(base: Base) -> void:
	var first: Marker3D = base.get_node_or_null(STORY_007_SPAWN_POINT) as Marker3D
	var spares: Array[Marker3D] = []
	for path: NodePath in STORY_007_SPARE_SPOTS:
		spares.append(base.get_node_or_null(path) as Marker3D)
	if first == null or spares.has(null):
		push_error("split_screen_harness: Base '%s' has no SpawnPoint or no side spot, so the Story 007 spawn spots are not given back." % base.name)
		return
	base.spawn_point = first
	base.spare_spawn_points = spares


## Gives both cameras of a freshly instanced launch scene the chase view's settings
## (CHASE_CAMERA_SETTINGS), before the scene enters the tree, unless the scenario script declares
## SHIPPED_CAMERA (the class doc says why). Only the two cameras' property is assigned: the shared
## .tres is never touched, and each Player's list of views in the scene is left as it is.
func _apply_chase_camera(root: SplitScreen, script: GDScript) -> void:
	if bool(script.get_script_constant_map().get(SHIPPED_CAMERA_CONSTANT, false)):
		return
	root.player_1_camera.settings = CHASE_CAMERA_SETTINGS
	root.player_2_camera.settings = CHASE_CAMERA_SETTINGS


## Gives the launch scene the Token stock the scenario asks for, on the field's token_stock and
## before the scene enters the tree (SplitScreen._ready() hands that stock to
## MatchController.begin() when it does): a TokenStock built from the script's STOCK_COUNTS, or the
## Map's own stock when it declares USE_MAP_STOCK = true, or else LEGACY_TOKEN_COUNT of every type
## (the class doc says why). A script that declares both is an error and keeps the Map's stock, and
## so is a STOCK_COUNTS that is not a Dictionary. Only the field's property is assigned: the shared
## .tres is never touched.
func _apply_token_stock(root: SplitScreen, script: GDScript) -> void:
	var constants: Dictionary = script.get_script_constant_map()
	var has_counts: bool = constants.has(STOCK_COUNTS_CONSTANT)
	var keeps_map_stock: bool = bool(constants.get(USE_MAP_STOCK_CONSTANT, false))
	if has_counts and keeps_map_stock:
		push_error("split_screen_harness: %s declares both STOCK_COUNTS and USE_MAP_STOCK, so the Map's own Token stock is kept." % scenario)
	if keeps_map_stock or root.field == null:
		return
	if not has_counts:
		root.field.token_stock = _legacy_stock()
	elif typeof(constants[STOCK_COUNTS_CONSTANT]) == TYPE_DICTIONARY:
		root.field.token_stock = _stock_from_counts(constants[STOCK_COUNTS_CONSTANT])
	else:
		push_error("split_screen_harness: %s declares STOCK_COUNTS as something other than a Dictionary, so the Map's own Token stock is kept." % scenario)


## A new TokenStock holding the given counts (type_id to count), one assignment per key: counts is
## typed, so an untyped Dictionary cannot be assigned to it as a whole. A pair whose key is not a
## text or whose count is not a number is an error and is left out.
func _stock_from_counts(declared: Dictionary) -> TokenStock:
	var stock: TokenStock = TokenStock.new()
	for type_id: Variant in declared:
		var key_is_text: bool = typeof(type_id) == TYPE_STRING or typeof(type_id) == TYPE_STRING_NAME
		var count_is_number: bool = typeof(declared[type_id]) == TYPE_INT or typeof(declared[type_id]) == TYPE_FLOAT
		if not key_is_text or not count_is_number:
			push_error("split_screen_harness: %s's STOCK_COUNTS pair %s: %s is not a type_id and a number, so it is left out." % [scenario, type_id, declared[type_id]])
			continue
		stock.counts[StringName(str(type_id))] = int(declared[type_id])
	return stock


## A new TokenStock holding LEGACY_TOKEN_COUNT of every type of match_rules.tres. Rules that fail to
## load are an error and leave the stock empty, which MatchController.begin() then refuses.
func _legacy_stock() -> TokenStock:
	var stock: TokenStock = TokenStock.new()
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the legacy Token stock holds no type." % MATCH_RULES_PATH)
		return stock
	for stats: UnitStats in rules.unit_types:
		if stats != null:
			stock.counts[stats.type_id] = LEGACY_TOKEN_COUNT
	return stock


## Logs a unit_spawned that arrives before the scenario starts: the start of the Round
## (round_start_spawns).
func _on_round_start_spawn(player_index: int) -> void:
	round_start_spawns.append(player_index)


## The physical key of a Player's fire action: Space for Player 1, Period for Player 2.
func fire_key(player: int) -> Key:
	return PLAYER_1_FIRE_KEY if player == PLAYER_1 else PLAYER_2_FIRE_KEY


## Makes every Player who is choosing confirm the type at its cursor (the Motorbike, where nothing
## has moved the cursor) with a real press of that Player's fire key, and waits, in raw physics
## ticks that do not count in ticks, until those Players' Units are in play, at most
## CHOICE_LIMIT_TICKS; each key is released on the tick the controller accepts the choice
## (_on_choice_confirmed()), a tick or more before the Unit appears (the bench settle), and any
## still held at the end is released then. A Player who is not choosing (in play, or with a standing
## choice) gets no key, so a weapon is never fired by this. The runner's one place for the first
## choice: before run(), unless the scenario declares OWN_CHOICE, and after a restart, where
## round_over and flag_showcase call it. A CHECK fails when the Units did not appear. A
## coroutine: await it.
func confirm_choices() -> void:
	var controller: MatchController = split.match_controller
	if controller == null:
		return
	var pending: Array[int] = []
	for player: int in [PLAYER_1, PLAYER_2]:
		if controller.is_choosing(player):
			pending.append(player)
			_choice_key_held[player] = true
			set_key(fire_key(player), true)
	var left: int = CHOICE_LIMIT_TICKS
	while left > 0 and not _all_alive(controller, pending):
		await get_tree().physics_frame
		left -= 1
	for player: int in pending:
		_choice_key_held[player] = false
		set_key(fire_key(player), false)
	if not _all_alive(controller, pending):
		check("choice", false, "the chosen Units did not appear within %d physics ticks: alive p1=%s p2=%s" % [
			CHOICE_LIMIT_TICKS, controller.is_alive(PLAYER_1), controller.is_alive(PLAYER_2)])


## True when every listed Player's Unit is in play.
func _all_alive(controller: MatchController, players: Array[int]) -> bool:
	for player: int in players:
		if not controller.is_alive(player):
			return false
	return true


## The controller accepted a choice: the fire key the runner held for it goes up on this very tick,
## before the fire input reads it. A key the runner does not hold for a choice is left alone.
func _on_choice_confirmed(player_index: int, _type_index: int) -> void:
	if player_index >= 0 and player_index < _choice_key_held.size() and _choice_key_held[player_index]:
		_choice_key_held[player_index] = false
		set_key(fire_key(player_index), false)


## A legacy scenario's Unit was destroyed: the runner makes that Player's choice at once,
## LEGACY_TYPE_INDEX (the Motorbike), by the controller's own choose() and with no key, inside the
## destruction's own tick. The choice is in before the due frame however short the delay, so the
## respawn comes exactly when it did before the choice existed, and no fire key is down when the
## Unit appears (a held one stays unarmed until released: PlayerFireInput). Connected to
## unit_destroyed for LEGACY_SCENARIOS only.
func _on_legacy_destroyed(player_index: int) -> void:
	if is_instance_valid(split) and split.match_controller != null:
		split.match_controller.choose(player_index, LEGACY_TYPE_INDEX)


## The scenario named by --scenario=NAME among the user arguments, or an empty name.
func _read_scenario() -> StringName:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SCENARIO_ARGUMENT):
			return StringName(argument.trim_prefix(SCENARIO_ARGUMENT))
	return &""


## The watchdog of a scenario, simulated seconds: the WATCHDOG_SECONDS constant its script
## declares (WATCHDOG_CONSTANT) when that is a number above zero, else the runner's own
## WATCHDOG_SECONDS.
func _scenario_watchdog_seconds(script: GDScript) -> float:
	var declared: Variant = script.get_script_constant_map().get(WATCHDOG_CONSTANT, WATCHDOG_SECONDS)
	if (typeof(declared) == TYPE_FLOAT or typeof(declared) == TYPE_INT) and float(declared) > 0.0:
		return float(declared)
	return WATCHDOG_SECONDS


## The usage line: the tool name, then SCENARIO_ARGUMENT and the names of SCENARIOS separated by "|".
func _usage() -> String:
	var names: PackedStringArray = []
	for scenario_name: StringName in SCENARIOS:
		names.append(String(scenario_name))
	return "usage: split_screen_harness.tscn -- " + SCENARIO_ARGUMENT + "|".join(names)


## Whole physics ticks in a time, at least one.
func ticks_in(seconds: float) -> int:
	return maxi(1, roundi(seconds * _ticks_per_second))


## Simulated seconds since the scenario began.
func time() -> float:
	return float(ticks) / float(_ticks_per_second)


## Waits the given number of physics ticks, sampling both Units after each one; each tick first
## presses again any held key the engine dropped (_reassert_held_keys(), TD-009). A coroutine:
## await it.
func advance_ticks(count: int) -> void:
	for _tick: int in count:
		await get_tree().physics_frame
		_reassert_held_keys()
		ticks += 1
		_sample()


## Waits the given simulated seconds. A coroutine: await it.
func advance(seconds: float) -> void:
	await advance_ticks(ticks_in(seconds))


## Updates both tracks and the run-wide minimums after a tick; prints a progress line when one is due.
func _sample() -> void:
	for track: UnitTrack in tracks:
		track.update()
		var at: Vector3 = track.unit.global_position
		wall_clearance_min = minf(wall_clearance_min, FIELD_HALF_EXTENT - maxf(absf(at.x), absf(at.z)))
	separation_min = minf(separation_min,
		tracks[PLAYER_1].unit.global_position.distance_to(tracks[PLAYER_2].unit.global_position))
	if report_ticks > 0 and ticks % report_ticks == 0:
		print_progress()


## Prints one SPLIT line with both Units' place, drive speed and turn since the phase began.
func print_progress() -> void:
	var first: UnitTrack = tracks[PLAYER_1]
	var second: UnitTrack = tracks[PLAYER_2]
	print("SPLIT %s t=%.3f phase=%s p1_x=%.2f p1_z=%.2f p1_speed=%.2f p1_yaw=%.1f "
		% [scenario, time(), phase, first.unit.global_position.x, first.unit.global_position.z,
			first.unit.current_speed, rad_to_deg(first.yaw_total)]
		+ "p2_x=%.2f p2_z=%.2f p2_speed=%.2f p2_yaw=%.1f"
		% [second.unit.global_position.x, second.unit.global_position.z,
			second.unit.current_speed, rad_to_deg(second.yaw_total)])


## Presses or releases one physical key by pushing a real key event through the Input singleton,
## the way the OS does. Sends nothing when the key is already in that state, both in the runner's
## record (_held) and in the engine (Input.is_physical_key_pressed()): a window that loses focus
## makes the engine release every pressed key while the record still holds them, and the
## comparison sends the key again instead of trusting the record (TD-009,
## docs/tech-debt-register.md). advance_ticks() re-asserts every held key after each tick too.
func set_key(key: Key, pressed: bool) -> void:
	if _held.get(key, false) == pressed and Input.is_physical_key_pressed(key) == pressed:
		return
	_held[key] = pressed
	_send_key(key, pressed)


## Pushes one real key event for a physical key through the Input singleton, on the keyboard's
## device (InputEvent.DEVICE_ID_KEYBOARD), as the OS would.
func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	event.device = InputEvent.DEVICE_ID_KEYBOARD
	Input.parse_input_event(event)


## Presses again every key the runner holds (_held) that the engine no longer reports as pressed
## (TD-009): a window focus change releases every pressed key in the engine, and a held throttle
## or steer would otherwise stay up for the rest of its step. Nothing is sent while the two agree,
## which is every tick of a run that never loses focus (every headless run), so such a run sends
## exactly the events it sent before. It runs right after each physics_frame of advance_ticks(),
## before the nodes' _physics_process of that tick, so a key pressed again acts in that tick.
func _reassert_held_keys() -> void:
	for key: int in _held.keys():
		if _held[key] and not Input.is_physical_key_pressed(key as Key):
			_send_key(key as Key, true)


## Holds one Player's throttle and steer keys: throttle 1 forward, -1 reverse; steer 1 left, -1
## right; 0 releases the pair.
func drive(player: int, throttle: int, steer: int) -> void:
	var keys: Array[Key] = PLAYER_1_KEYS if player == PLAYER_1 else PLAYER_2_KEYS
	set_key(keys[SLOT_THROTTLE], throttle > 0)
	set_key(keys[SLOT_REVERSE], throttle < 0)
	set_key(keys[SLOT_STEER_LEFT], steer > 0)
	set_key(keys[SLOT_STEER_RIGHT], steer < 0)


## Sets the whole key state of a step and names the phase after it: its Player (or both) holds the
## step's keys, the other has every key up.
func apply(step: DriveStep) -> void:
	phase = step.label
	for player: int in [PLAYER_1, PLAYER_2]:
		if step.player == BOTH or step.player == player:
			drive(player, step.throttle, step.steer)
		else:
			drive(player, 0, 0)


## Releases every key of both layouts.
func release_all() -> void:
	drive(PLAYER_1, 0, 0)
	drive(PLAYER_2, 0, 0)


## Holds the step's keys for its length. A coroutine: await it.
func run_step(step: DriveStep) -> void:
	apply(step)
	await advance(step.seconds)


## Teleports a Unit and snaps its camera, in the order a spawn uses: transform first, then
## reset_motion(), then snap_to_target().
func place(unit: Unit, where: Transform3D, camera: ChaseCamera) -> void:
	unit.global_transform = where
	unit.reset_motion()
	camera.snap_to_target()


## The corridor start of a Player: x = -10 facing -Z for Player 1, x = +10 facing +Z for Player 2.
func corridor_transform(player: int) -> Transform3D:
	if player == PLAYER_1:
		return Transform3D(Basis.IDENTITY, CORRIDOR_1_START)
	return Transform3D(Basis(Vector3.UP, PI), CORRIDOR_2_START)


## A reset of both Units to their corridors with every key up: teleport, wait SETTLE_TICKS, then
## start both tracks from where the Units stand. A coroutine: await it.
func reset_to_corridors() -> void:
	release_all()
	place(split.player_1_unit, corridor_transform(PLAYER_1), split.player_1_camera)
	place(split.player_2_unit, corridor_transform(PLAYER_2), split.player_2_camera)
	await advance_ticks(SETTLE_TICKS)
	for track: UnitTrack in tracks:
		track.begin()


## Prints one CHECK line and counts it.
func check(check_name: String, passed: bool, detail: String) -> void:
	_checks += 1
	if not passed:
		_failed += 1
	print("CHECK %s %s %s %s" % [scenario, check_name, "PASS" if passed else "FAIL", detail])


## Prints the one RESULT line, releases the keys and quits: exit code 0 when no check failed, 1
## otherwise. The fields are the scenario's own key=value numbers. A scenario ends with it, once.
func finish(fields: String) -> void:
	if _finished:
		return
	_finished = true
	release_all()
	var line: String = "RESULT %s %s checks=%d failed=%d t=%.3f" % [
		scenario, "ok" if _failed == 0 else "fail", _checks, _failed, time()]
	if not fields.is_empty():
		line += " " + fields
	print(line)
	get_tree().quit(0 if _failed == 0 else EXIT_FAILED)


## Fires when the scenario has not finished in its watchdog time (_watchdog_seconds, the runner's
## WATCHDOG_SECONDS unless the scenario declares its own): a hung coroutine fails loudly.
func _on_watchdog() -> void:
	if _finished:
		return
	check("watchdog", false, "the scenario did not finish within %.0f simulated seconds" % _watchdog_seconds)
	finish("reason=watchdog")
