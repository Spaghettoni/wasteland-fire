class_name SplitScreen
extends Control
## The launch scene: two side-by-side views of one shared 3D world, one Unit (the type its Player
## chooses), one chase camera and one keyboard layout per Player, both Players driving at once, each
## starting the Round at their own Base and respawning there when destroyed.
##
## Implements: design/game-brief.md build-order item 2 (Split screen for two: two side-by-side
## viewports, one Unit and one fixed keyboard layout per Player, both driving at once) and
## production/epics/wasteland-fire/story-002-split-screen.md AC-1 to AC-7. Since Story 003
## (production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-1, AC-3, AC-5 and
## AC-7) it also composes the Round: the MatchController and each Player's PlayerMatchInput.
## Vocabulary: CONTEXT.md (Player, Unit, Motorbike, Base, Map).
##
## The scene holds the pieces. This script only hands them to the MatchController, once, when the
## scene is ready: begin() gets the two Units, the two Bases from the field, the two cameras, in
## Player order, and the field's Token stock. Putting a Unit on its Base, at the start of the Round
## and at every respawn, is the MatchController's job (AC-1, AC-3); until Story 003 it was this
## script's (Story 002 put each Unit on its start marker: the spawn of DrivingToy, done for two
## Players). This scene stays the composition root because it is the one place that sees the field,
## both Units, both cameras and the controller together: it injects them, so the MatchController
## needs no node path and no singleton and can be built from stand-ins in a test. The world and the
## views stay here for the same reason: they are how the pieces are laid out and seen on the screen,
## which is this scene's business, and none of them depends on the Round. The layout of the scene:
##   SplitScreen (this Control, filling the window)
##     World (Node3D): the Map first (map_01.tscn: its ground, its two Bases, its Fuel building and its two
##       ammunition buildings),
##       then both Units, both PlayerDriveInputs, both PlayerMatchInputs, both Weapons with their
##       PlayerFireInputs, both MineLayers with their PlayerMineInputs, both PlayerChoiceInputs and
##       both PlayerCameraInputs
##     Views (HBoxContainer): a SubViewportContainer per Player, each holding a SubViewport that
##       holds that Player's ChaseCamera, respawn countdown, HUD, Unit choice panel and Round-over
##       screen
##     Divider (ColorRect): a thin line drawn over the seam between the two views
##     MatchController (Node): who is alive, who is choosing or waiting to respawn and the Round's
##       Flags
##     RoundRestartInput (Node): the restart key of a Round that is over; the last child
##
## The Map (production/epics/wasteland-fire/story-007-the-map.md AC-9 and its Map contract). field
## is typed MapField, the class every Map's root carries, so any Map scene can be World's field and
## replacing the Map scene needs no change here. This scene reads only the Map's two Bases and its
## Token stock and hands them to the MatchController; each Base brings its Flag, its zone, its pad
## and its SpawnPoint markers itself (Base). The Token stock (MapField.token_stock) goes to begin()
## as it is: the controller copies it for each Player and refuses a Map without a usable one, so
## this scene checks nothing about it
## (production/epics/wasteland-fire/story-008-tokens-garage-and-loss.md AC-1 and AC-9). The Map is
## World's first child (the node Map, unique name %Map), so a Map node that acts on the Units in its
## physics tick runs before the Units do, in every tick.
##
## One world, two views (AC-1, AC-2). World sits in the window's own World3D, outside both
## SubViewports, and neither SubViewport sets own_world_3d or a world_3d, so both render the
## window's World3D: the same field and the same two Units in one physics space, so the Units can
## meet. Each SubViewport holds exactly one current Camera3D, its Player's; the window's own
## viewport has none and draws only the containers. Views splits the window into two equal halves,
## 640 x 720 each in the project's 1280 x 720 window, with its theme separation set to 0 (the
## default 4 would make both views 638 wide); the Divider is an overlay that takes no layout
## space. In a larger window the canvas_items stretch mode (project.godot, Story 001) keeps the
## views at 640 x 720 and scales the picture up (the Story 002 evidence doc keeps the run).
##
## Physics interpolation (Story 001 AC-5, carried into this scene). A Control is OFF by default
## and a Node3D inherits its parent's mode, so a World left at INHERIT under this Control root
## would draw both Units at the physics tick rate on a faster display. World therefore sets the
## mode ON itself and the Units inherit it; the two ChaseCameras set themselves OFF, as
## ChaseCamera documents (measured on 4.7.2; the Story 002 evidence doc keeps the run).
##
## Input (AC-3 to AC-6). The Players are separated by Input Map layouts, not by devices: each
## PlayerDriveInput reads the actions under its own prefix (p1_ or p2_, declared in project.godot
## and stored in this scene), so each layout moves only its own Unit and holding both moves both.
## The Round's keys work the same way: each PlayerMatchInput reads the self_destruct and
## debug_damage actions under its own prefix and calls its own Unit (Story 003 AC-5, AC-8).
## Godot 4.7 does not tell two keyboards apart, and it moved the keyboard's device ID from 0 to
## InputEvent.DEVICE_ID_KEYBOARD, so nothing in this project compares InputEvent.device with 0,
## and this script reads no input.
##
## The views (Story 010, production/epics/wasteland-fire/story-010-camera-from-above.md AC-4 and
## AC-5). Each camera starts in the view from above (above_camera_settings.tres, the first entry of
## its Player's list of views) and its PlayerCameraInput, which reads that Player's p1_ or p2_camera
## key, steps it through the list: the view from above, then the chase view of Stories 001 to 009
## (chase_camera_settings.tres), then round again. The list, the two resources and the keys are data
## of this scene and of project.godot; the other Player's camera is never touched.
##
## Player colour. Each Unit is coloured on its Body mesh only, by a material_override on the
## instanced Body node in this scene (the Motorbike's mesh is one shared resource, so a material
## on the mesh would recolour both); the Nose keeps its cream, so the facing stays readable. Both
## Motorbike instances are marked editable in the .tscn, because the editor's save drops the
## overrides of an instance that is not, and the cross-branch references are %UniqueName paths,
## which the editor rewrites as relative paths on save (both measured on 4.7.2; the Story 002
## evidence doc keeps the runs).
##
## Performance (AC-7): both views render the shared world, so the frame and draw-call budgets in
## .claude/docs/technical-preferences.md are for the two together. Nothing here draws or updates
## per frame.
##
## Shots (Story 005). A Weapon adds its Shots under World and they belong to the node group
## SHOT_GROUP (shot.tscn stores it). A Round that ends pauses the tree with every shot in flight
## frozen, and restart() unpauses it, so this scene frees the whole group when the MatchController
## emits round_started: no shot of the Round before flies on into the next one and hits a Unit
## just chosen on its Base.
##
## Players and Structures (Story 012). Before the Round begins this scene sets each Unit's
## player_index (0 for Player 1, 1 for Player 2) and, for each Base in Player order, the
## player_index of every Structure in the Base's structures list: the one place that knows which
## Player owns what, so a Shot can leave a Player's own pieces alone. When a Round starts again
## it calls restore() on every Structure of both Bases, from those lists and with no search of
## the tree (design/rules.md, Technology and conventions). The controller's restart() seats every
## Flag and benches both Units before it emits round_started, so no Unit or Flag is inside a
## piece when it comes back (production/epics/wasteland-fire/story-012-flag-walls.md AC-5). The
## handler is connected after begin(), so it runs at every restart and not at the first Round's
## start, whose standing pieces come from each Structure's own _ready().
##
## The Map's own pieces (Story 019). A piece that belongs to no Base, Map 01's scrap walls' Wall
## Panels, is listed in the field's neutral_structures (MapField). It gets no player_index, so it
## stays at -1 and a Shot of either Player damages it, and it is restored with the Bases' pieces at
## every restart, from that list and with no search of the tree. _arm_turrets() stays on the Bases'
## lists.
##
## Turrets (Story 013). A Turret is a Structure, so it is listed in its Base's structures, gets its
## Player index and is restored at every restart like a Flag Wall. Before the Round begins this
## scene also arms each one of them with arm(): the other Player's Unit, the node the Shots are
## added under (World, the parent of the Units, where the Weapons put theirs) and the Round's
## MatchRules, found from the Bases' lists with no search of the tree. A Turret of a Map that has
## none is simply not there; one never armed stays idle. Its Shots belong to the shots group, so
## _free_shots() frees them at every restart
## (production/epics/wasteland-fire/story-013-turrets.md AC-7).
##
## Mines (Story 014). Each Player's MineLayer lays that Player's Mines under World, and every Mine
## belongs to the node group MINE_GROUP (mine.tscn stores it). A MineLayer must know where a Mine
## may not be laid, so before the Round begins this scene hands each one the two Bases, from the
## field and with no search of the tree. A Round that starts again frees the whole group, the way
## it frees the Shots: the MatchController benches both Units before round_started, so no Truck
## holds a Mine count and no Mine of the Round before is left on the Map
## (production/epics/wasteland-fire/story-014-truck-mines.md AC-7). The handler is connected after
## begin(), so it runs at every restart and not at the first Round's start, when no Mine exists.
##
## Explosions (Story 016). When the MatchController announces a destruction it counted (unit_destroyed:
## the other Player's Shots, a Turret's Shot, a Mine, a Self-destruct, the Gyrocopter's Fuel crash, and
## any later way of destroying a Unit that ends in Unit.destroy()), this scene instances explosion_scene
## under World, where the Units are, and blasts it at the Unit as it was drawn: the Unit's child named
## Model (Unit.MODEL_NODE_NAME) raised by the height of the type's collision_center, so a ground Unit's
## explosion is at the middle of its box and a Gyrocopter's where it was seen in the air, and the Unit's
## own origin in its place when it has no model. The size is the larger horizontal side of the type's
## collision_size and the floor the chunks fall to is the height of the Unit's origin. One listener on
## unit_destroyed is the whole rule: a Swap and every bench go through Unit.leave_play(), which never
## emits `destroyed`, and a destruction the controller refuses (a Player who is not alive) goes out as
## no signal, so none of them plays one; and it is a link on the Round's signal and never on
## Unit.destroyed, which nothing new listens to. The handler runs inside the tick of whoever destroyed
## the Unit (a Shot, a Mine, PlayerMatchInput, the Unit), as a Weapon adds its Shot there. The Explosion
## is a picture only (it holds no body and nothing in the Round reads it), keeps playing under the
## Round-over pause, and belongs to the node group EXPLOSION_GROUP, which a Round that starts again
## frees, the way it frees the Mines. The scene is data of this scene: with no explosion_scene nothing
## listens to the Round for it and no explosion is ever added (the evidence runner takes it away for
## every scenario written before it: tools/evidence/split_screen_harness.gd), and one cleared later plays
## nothing. One is instanced and freed before the Round begins (_warm_up_explosion()).
## (production/epics/wasteland-fire/story-016-unit-explosions.md AC-1 to AC-4, AC-7)
##
## Fuel Cans (Story 006). The Map brings its own Fuel Cans at fixed spots (Map 01's are in
## production/epics/wasteland-fire/story-007-the-map.md; Story 006 kept five greybox Cans in this
## scene until Map 01 replaced them). Each Can polls its own zone, refills the Unit that touches it
## and comes back on its own after its delay (FuelCan), and its root belongs to the node group
## FUEL_CAN_GROUP (fuel_can.tscn stores it), so this scene finds every Can of whichever Map is the
## field with no node path. The Round-over pause stops the Cans with the tree, so when the
## MatchController emits round_started again this scene calls restock() on the whole group: a
## Round that starts again has every Can back at its spot
## (production/epics/wasteland-fire/story-006-fuel-and-fuel-cans.md AC-6).
##
## Fuel zones (Story 023). Map 01 has no Fuel Cans since its depot became the Fuel building: the depot
## holds two SupplyZones, each of which polls its own box every tick and refuels the Units stopped in
## it, so this scene hands them nothing to refuel with and a Round that starts again needs no handler for them (a zone
## keeps only its last tick's list). The Fuel Can code and its group stay, and so does the restock
## above, for the Cans that remain: the greybox field's, and the nine the evidence runner puts back on
## Map 01 for the scenarios written before the story (docs/tech-debt-register.md, TD-015).
## (production/epics/wasteland-fire/story-023-fuel-building.md AC-1, AC-3)
##
## Ammunition zones and the Mines (Story 024). Map 01 also has two ammunition buildings, each
## with an ammunition zone, and lists all four of its supply zones in the field's supply_zones.
## An ammunition zone polls its own box like a Fuel zone and rearms the Weapon of the Unit it
## lists, so before the Round begins this scene hands every ammunition zone both Weapons
## (player_1_weapon and player_2_weapon, in Player order), and hands both MineLayers every zone,
## which they keep clear of Mines (_hand_supply_zones(): from the field's list, with no search of
## the tree, and never as a NodePath into the Map, which the evidence runner may rebuild after
## the exports were resolved). A Round that starts again needs no handler for them: a zone keeps
## only its last tick's list and the Weapons refill themselves at every spawn.
## (production/epics/wasteland-fire/story-024-ammunition-buildings.md AC-2, AC-4)
##
## Tyre tracks (Story 026). A Map that has a TyreTracks node lists it in the field's tyre_tracks
## (MapField). Before the Round begins this scene hands it both Units, in Player order, and it
## connects round_started to the node's clear() after begin(), so every restart starts on clean
## ground and the first Round starts on the clean ground the node begins with. Both come from that
## export and not from a search of the tree or a singleton; a Map with none hands nothing, and the
## evidence runner takes the node away for every scenario written before it.
## (production/epics/wasteland-fire/story-026-tyre-tracks.md AC-3, AC-7)
##
## Other Maps and their pieces (Story 038). The scene is saved with Map 01; the map choice
## (src/ui/map_choice/map_choice.gd) instances it and calls use_map() with the chosen Map before it
## enters the tree, so _ready() begins the Round on that Map. A Map may list a Player's pieces outside
## the Base (MapField.player_1_outposts and player_2_outposts, Map 02's field Turrets): each is given
## its Player, armed if it is a Turret and restored at every restart with the Base's pieces
## (_pieces_of()). The Map's Bushes (MapField.bushes) stand again at every restart too.
## (production/epics/wasteland-fire/story-038-map-02-and-map-choice.md AC-1, AC-5, AC-6)

## The name of World's Map node, the one use_map() replaces (Story 038).
const MAP_NODE_NAME: StringName = &"Map"

## The node group every Shot in flight belongs to; _free_shots() frees it at every Round start.
const SHOT_GROUP: StringName = &"shots"

## The node group every Mine belongs to; _free_mines() frees it at every restart.
const MINE_GROUP: StringName = &"mines"

## The node group every Explosion belongs to; _free_explosions() frees it at every restart.
const EXPLOSION_GROUP: StringName = &"explosions"

## The node group every smoke screen belongs to (Story 042); _free_smokes() frees it at every restart.
const SMOKE_GROUP: StringName = &"smokes"

## The gap between the views of one column, pixels, and the colour of a place no Player has (Story 048).
const VIEW_GAP: int = 4
const EMPTY_VIEW_COLOUR: Color = Color(0.06, 0.06, 0.07, 1.0)
## The dead zone an action gets when project.godot gives it none.
const DEFAULT_DEADZONE: float = 0.2

## The node group every Fuel Can belongs to; _restock_fuel_cans() brings the whole group back
## whenever a Round starts again. Empty on the shipped Map 01 since Story 023.
const FUEL_CAN_GROUP: StringName = &"fuel_cans"

## The Map both Units drive on, typed MapField so any Map scene can be it (Story 007 AC-9). It
## carries the two Bases (player_1_base and player_2_base) where each Player's Unit starts the
## Round and respawns, and the Map's Token stock, which this scene hands to the MatchController
## with the Bases. It sits under World, so it is in the shared world.
@export var field: MapField

## The Unit Player 1 drives. It sits under World, beside Player 1's PlayerDriveInput.
@export var player_1_unit: Unit

## The Unit Player 2 drives. It sits under World, beside Player 2's PlayerDriveInput.
@export var player_2_unit: Unit

## The camera that chases Player 1's Unit. It sits in the SubViewport of Player 1's view.
@export var player_1_camera: ChaseCamera

## The camera that chases Player 2's Unit. It sits in the SubViewport of Player 2's view.
@export var player_2_camera: ChaseCamera

## The MineLayer of Player 1's Unit (Story 014). It sits under World, beside the Weapons.
@export var player_1_mine_layer: MineLayer

## The MineLayer of Player 2's Unit. It sits under World, beside the Weapons.
@export var player_2_mine_layer: MineLayer

## The Weapon of Player 1's Unit (Story 024). It sits under World, beside the input nodes. An
## ammunition zone rearms it while Player 1's Unit stands in the zone.
@export var player_1_weapon: Weapon

## The Weapon of Player 2's Unit. It sits under World, beside the input nodes.
@export var player_2_weapon: Weapon

## The node that owns the Round's state: who is alive, the respawn timers and the Flags.
## _ready() hands it the Units, the Bases and the cameras. It sits after the views in this scene's
## root, with RoundRestartInput after it, and what the screen shows about the Round (the respawn
## countdown, the HUD and the Round-over screen) listens to it.
@export var match_controller: MatchController

## The picture a destroyed Unit plays (Story 016): explosion.tscn, whose root is an Explosion. Optional: with
## none nothing listens to the Round for it and no explosion is ever added.
@export var explosion_scene: PackedScene

## Players 3 and 4, made by apply_lineup() (Story 048), each a Dictionary of its "unit", "camera",
## "weapon" and "mine_layer". Empty in a Round of two.
var _extra_players: Array[Dictionary] = []
## The lineup this scene plays (apply_lineup()), or null for the two Players of the scene as saved.
var lineup: Lineup = null

## Puts `map_scene` in place of the Map this scene was saved with (Story 038), before the scene
## enters the tree: the map choice calls it on a freshly instanced launch scene. World's Map is
## freed at once (remove_child() and free(), so none of its nodes stays in a node group for a frame),
## the new Map is instanced as World's first child under the same name and unique name, owned by
## this scene, and field points at it: the export was resolved to the old Map when the scene was
## instanced. Returns false, with an error and nothing changed, when the scene is already in the tree,
## when map_scene is null or when its root is not a MapField.
func use_map(map_scene: PackedScene) -> bool:
	if is_inside_tree():
		push_error("SplitScreen '%s': use_map() is called after the scene entered the tree, so the Map is not replaced." % name)
		return false
	if map_scene == null:
		push_error("SplitScreen '%s': use_map() got no scene, so the Map is not replaced." % name)
		return false
	var instance: Node = map_scene.instantiate()
	var map: MapField = instance as MapField
	if map == null:
		push_error("SplitScreen '%s': the root of %s is not a MapField, so the Map is not replaced." % [name, map_scene.resource_path])
		instance.free()
		return false
	var world: Node3D = get_node("World") as Node3D
	var old: Node = world.get_node_or_null(NodePath(String(MAP_NODE_NAME)))
	if old != null:
		world.remove_child(old)
		old.free()
	map.name = MAP_NODE_NAME
	map.unique_name_in_owner = true
	world.add_child(map)
	world.move_child(map, 0)
	map.owner = self
	field = map
	return true


func _ready() -> void:
	var missing: String = _first_unassigned()
	if not missing.is_empty():
		var reason: String = "The field (with both its Bases), both Units, both cameras and the MatchController must all be assigned."
		push_error("SplitScreen '%s': %s is not assigned, so the Round does not begin and no Unit is placed. %s" % [name, missing, reason])
		return
	var units: Array[Unit] = all_units()
	var team_bases: Array[Base] = [field.player_1_base, field.player_2_base]
	var bases: Array[Base] = []
	for player: int in units.size():
		bases.append(team_bases[team_of(player)])
	var cameras: Array[ChaseCamera] = all_cameras()
	_assign_players(units, team_bases)
	_hand_silhouette_layers(units, cameras)
	_arm_turrets(units, team_bases)
	_hand_bases_to_mine_layers(team_bases)
	_hand_supply_zones()
	_hand_tyre_tracks(units)
	_warm_up_models()
	_warm_up_explosion()
	match_controller.begin(units, bases, cameras, field.token_stock)
	match_controller.round_started.connect(_free_shots)
	match_controller.round_started.connect(_restock_fuel_cans)
	match_controller.round_started.connect(_restore_structures)
	match_controller.round_started.connect(_free_mines)
	match_controller.round_started.connect(_free_smokes)
	if field.tyre_tracks != null:
		match_controller.round_started.connect(field.tyre_tracks.clear)
	if explosion_scene != null:
		match_controller.unit_destroyed.connect(_explode)
		match_controller.round_started.connect(_free_explosions)


## The name of the first required reference that is not assigned, or an empty string when all
## twelve are: the ten exports and the field's two Bases.
func _first_unassigned() -> String:
	if field == null:
		return "field"
	if field.player_1_base == null:
		return "field.player_1_base"
	if field.player_2_base == null:
		return "field.player_2_base"
	if player_1_unit == null:
		return "player_1_unit"
	if player_2_unit == null:
		return "player_2_unit"
	if player_1_camera == null:
		return "player_1_camera"
	if player_2_camera == null:
		return "player_2_camera"
	if match_controller == null:
		return "match_controller"
	if player_1_mine_layer == null:
		return "player_1_mine_layer"
	if player_2_mine_layer == null:
		return "player_2_mine_layer"
	if player_1_weapon == null:
		return "player_1_weapon"
	if player_2_weapon == null:
		return "player_2_weapon"
	return ""


## Sets the Player of each Unit and of each Structure in its Base's list, in Player order: index 0
## is Player 1, 1 is Player 2. An entry of a list that is not assigned is skipped (Base warns).
func _assign_players(units: Array[Unit], bases: Array[Base]) -> void:
	for player: int in units.size():
		units[player].player_index = team_of(player)
	for team: int in bases.size():
		for structure: Structure in _pieces_of(team, bases):
			if structure != null:
				structure.player_index = team


## Gives each Player's camera the silhouette layer it never draws, the other Player's (Story 027 AC-4),
## read from the SilhouetteSettings the Units carry, so the layers are written in one file and a
## camera cannot be left drawing the other Player's silhouette. Units with no settings leave their
## cameras drawing every layer, as before the story.
func _hand_silhouette_layers(units: Array[Unit], cameras: Array[ChaseCamera]) -> void:
	for player: int in cameras.size():
		# Story 048: a Unit's silhouette is on its Team's layer (player_index is the Team), so each view
		# leaves out the other Team's and shows the Teammates' with its own.
		var settings: SilhouetteSettings = units[player].silhouette
		if settings != null:
			cameras[player].never_drawn_layers = settings.layer_of(1 - team_of(player))


## Arms every Turret in each Base's structures list (Story 013): the target is the other Player's
## Unit, so a Turret of Player N's Base fires at Player N + 1's, wrapping round; the Shots go under
## the node the Units are under. A Structure that is not a Turret is left alone.
func _arm_turrets(units: Array[Unit], bases: Array[Base]) -> void:
	for team: int in bases.size():
		var enemies: Array[Unit] = []
		for player: int in units.size():
			if team_of(player) != team:
				enemies.append(units[player])
		for structure: Structure in _pieces_of(team, bases):
			var turret: Turret = structure as Turret
			if turret != null and not enemies.is_empty():
				if enemies.size() == 1:
					turret.arm(enemies[0], units[0].get_parent(), match_controller.rules)
				else:
					turret.arm_targets(enemies, units[0].get_parent(), match_controller.rules)


## Hands both MineLayers the two Bases, in Player order, before the Round begins (Story 014): the
## MineLayer refuses a lay in or near either of them.
func _hand_bases_to_mine_layers(bases: Array[Base]) -> void:
	for layer: MineLayer in all_mine_layers():
		layer.bases = bases


## Hands on the Map's supply zones, in Player order, before the Round begins (Story 024): every
## ammunition zone gets both Weapons, and it rearms the one whose Unit it lists; both MineLayers
## get every zone, and refuse a lay in or near any of them. The list is the field's own
## (MapField.supply_zones), so a Map with none hands nothing.
func _hand_supply_zones() -> void:
	var weapons: Array[Weapon] = all_weapons()
	for zone: SupplyZone in field.supply_zones:
		if zone != null and zone.kind == SupplyZone.Kind.AMMO:
			zone.weapons = weapons
	for layer: MineLayer in all_mine_layers():
		layer.supply_zones = field.supply_zones


## Hands the Map's tyre tracks both Units, in Player order, before the Round begins (Story 026 AC-7):
## from the field's own export, so a Map with none hands nothing.
func _hand_tyre_tracks(units: Array[Unit]) -> void:
	if field.tyre_tracks != null:
		field.tyre_tracks.units = units.duplicate()


## Instances each of the match's Unit types' model scenes once and frees it at once, before the
## Round begins (Story 007 AC-14): a model makes its meshes the first time one of its type enters
## the tree, at a cost a spawn would show, and caches them (a MeshUnitModel reads its mesh file and
## the box of its vertices; a KitUnitModel builds them from the author's concept kit: measured on
## 4.7.2, the Story 007 evidence doc keeps the run), so that cost falls here, hidden by the Round's
## start, and never at a spawn in the Round. Each model is under this scene for that only: it is
## never drawn and prints nothing.
func _warm_up_models() -> void:
	for stats: UnitStats in match_controller.unit_types():
		if stats == null or stats.model == null:
			continue
		var model: Node = stats.model.instantiate()
		add_child(model)
		remove_child(model)
		model.free()


## Instances the explosion scene once, adds it and frees it at once, before the Round begins (Story 016), as
## _warm_up_models() does the models: the first Explosion ever made takes 12 to 16 ms to instantiate and each one
## after it 0.1 to 0.6 ms (measured windowed on 4.7.2; the Story 016 evidence doc keeps the runs), which would
## land in the frame of the Round's first destruction, whose own work already takes 10 to 17 ms. Nothing is
## drawn and nothing is printed. With no explosion_scene nothing is made.
func _warm_up_explosion() -> void:
	if explosion_scene == null:
		return
	var warm: Node = explosion_scene.instantiate()
	add_child(warm)
	remove_child(warm)
	warm.free()


## Frees every Shot still in flight (the SHOT_GROUP nodes) when a Round starts or restarts, so the
## Round-over pause cannot carry a shot into the next Round. Each shot stops its tick first, so a
## shot queued to be freed cannot still hit something on the tick of the restart.
func _free_shots() -> void:
	for shot: Node in get_tree().get_nodes_in_group(SHOT_GROUP):
		shot.set_physics_process(false)
		shot.queue_free()


## Frees every Mine on the Map (the MINE_GROUP nodes) when a Round starts again (Story 014 AC-7):
## armed, live or flashing alike. Each Mine stops its tick first, so one queued to be freed cannot
## still go off on the tick of the restart.
func _free_mines() -> void:
	for mine: Node in get_tree().get_nodes_in_group(MINE_GROUP):
		mine.set_physics_process(false)
		mine.queue_free()


## Frees every smoke screen still hanging (the SMOKE_GROUP nodes) when a Round starts again (Story 042).
func _free_smokes() -> void:
	for cloud: Node in get_tree().get_nodes_in_group(SMOKE_GROUP):
		cloud.set_physics_process(false)
		cloud.queue_free()


## Frees every Explosion still playing (the EXPLOSION_GROUP nodes) when a Round starts again (Story 016
## AC-3): one that plays on under the Round-over pause is gone with the restart. Each stops its tick
## first, so one queued to be freed cannot still count a tick.
func _free_explosions() -> void:
	for blast: Node in get_tree().get_nodes_in_group(EXPLOSION_GROUP):
		blast.set_physics_process(false)
		blast.queue_free()


## Plays the explosion of a destruction the Round counted (Story 016 AC-1, AC-4), for the Unit of
## `player_index` (0 for Player 1): the scene is added under the Units' parent and blasted in this one
## call, at the Unit's Model (the Unit's own origin when it has none) raised by the type's
## collision_center height, with the larger horizontal side of the type's collision_size as its size and
## the height of the Unit's origin as the floor.
func _explode(player_index: int) -> void:
	if explosion_scene == null:
		return
	var unit: Unit = all_units()[player_index]
	var instance: Node = explosion_scene.instantiate()
	var blast: Explosion = instance as Explosion
	if blast == null:
		push_error("SplitScreen '%s': the root of explosion_scene is not an Explosion, so a destroyed Unit explodes nowhere." % name)
		instance.free()
		return
	var model: Node3D = unit.get_node_or_null(String(Unit.MODEL_NODE_NAME)) as Node3D
	var origin: Vector3 = model.global_position if model != null else unit.global_position
	var centre: Vector3 = origin + Vector3.UP * unit.stats.collision_center.y
	unit.get_parent().add_child(blast)
	blast.blast(centre, maxf(unit.stats.collision_size.x, unit.stats.collision_size.z), unit.global_position.y)


## Brings every Structure of both Bases, and the Map's own (MapField.neutral_structures, Story 019),
## back whole when a Round starts again (Story 012 AC-5): the controller has seated every Flag and
## benched both Units by then, so nothing stands where a piece returns. A piece that is standing is
## refilled, a fallen one stands again.
func _restore_structures() -> void:
	var bases: Array[Base] = [field.player_1_base, field.player_2_base]
	for player: int in bases.size():
		for structure: Structure in _pieces_of(player, bases):
			if structure != null:
				structure.restore()
	for structure: Structure in field.neutral_structures:
		if structure != null:
			structure.restore()
	for bush: Bush in field.bushes:
		if bush != null:
			bush.restore()


## The pieces of the Player at `player`: the Structures of that Player's Base, then that Player's
## outposts on the field (MapField.outposts_of(), Story 038), in that order.
func _pieces_of(player: int, bases: Array[Base]) -> Array[Structure]:
	var pieces: Array[Structure] = bases[player].structures.duplicate()
	pieces.append_array(field.outposts_of(player))
	return pieces


## Brings every Fuel Can (the FUEL_CAN_GROUP nodes) back at its spot when a Round starts again
## (Story 006 AC-6): FuelCan.restock() shows a taken Can and makes it available, and leaves an
## available one alone. A Can taken late in a Round would otherwise still be away when the next
## Round starts, until its own delay ran out. Since Story 023 the shipped Map 01 has no Can, so
## this finds none there; it serves the greybox field's Cans and the evidence runner's.
func _restock_fuel_cans() -> void:
	for node: Node in get_tree().get_nodes_in_group(FUEL_CAN_GROUP):
		var fuel_can: FuelCan = node as FuelCan
		if fuel_can != null:
			fuel_can.restock()


## Every Player's Unit, in Player order: Player 1's and Player 2's, then those apply_lineup() made.
func all_units() -> Array[Unit]:
	var list: Array[Unit] = [player_1_unit, player_2_unit]
	for extra: Dictionary in _extra_players:
		list.append(extra["unit"] as Unit)
	return list


## Every Player's camera, in Player order.
func all_cameras() -> Array[ChaseCamera]:
	var list: Array[ChaseCamera] = [player_1_camera, player_2_camera]
	for extra: Dictionary in _extra_players:
		list.append(extra["camera"] as ChaseCamera)
	return list


## Every Player's Weapon, in Player order.
func all_weapons() -> Array[Weapon]:
	var list: Array[Weapon] = [player_1_weapon, player_2_weapon]
	for extra: Dictionary in _extra_players:
		list.append(extra["weapon"] as Weapon)
	return list


## Every Player's MineLayer, in Player order.
func all_mine_layers() -> Array[MineLayer]:
	var list: Array[MineLayer] = [player_1_mine_layer, player_2_mine_layer]
	for extra: Dictionary in _extra_players:
		list.append(extra["mine_layer"] as MineLayer)
	return list


## The Team of the Player (Story 048): the lineup's entry, or the Player's own index without one.
func team_of(player_index: int) -> int:
	if lineup != null and player_index < lineup.teams.size():
		return lineup.teams[player_index]
	return player_index


## Plays a lineup (Story 048; Martin, 2026-10-23): two to four Players in two Teams, each on a pad or a
## keyboard half. Call it on a freshly instanced launch scene, after use_map() and before it enters the
## tree, as the map choice does. Players 3 and 4 are made from Player 2's nodes (_duplicate_rig()); every
## Unit, HUD band and choice panel takes its Team's colours; with more than two Players the views stand
## in two columns, Orange on the left and Teal on the right, an empty place showing a dark panel; the
## Players' actions get the keys of their keyboard half and no other (_apply_inputs()); PadAssignment
## gives each listed pad to its Player only, with the lineup's pad layout when it carries the Players'
## controls (Story 060); the Round-over screens name the winning Team; and the
## MatchController gets the Teams. Returns false, with an error and nothing changed, when the scene is
## in the tree or the lineup cannot be played (Lineup.is_playable()).
func apply_lineup(new_lineup: Lineup) -> bool:
	if is_inside_tree():
		push_error("SplitScreen '%s': apply_lineup() is called after the scene entered the tree, so the lineup is not played." % name)
		return false
	if new_lineup == null or not new_lineup.is_playable():
		push_error("SplitScreen '%s': the lineup cannot be played (two to four Players, both sides taken, each device once), so the Round keeps its two Players." % name)
		return false
	lineup = new_lineup
	var count: int = lineup.player_count()
	var team_materials: Array[Material] = [player_1_unit.team_material, player_2_unit.team_material]
	var body_materials: Array[Material] = [_body_material(player_1_unit), _body_material(player_2_unit)]
	var views: Node = get_node("Views")
	var edges: Array = [_edge_of(views.get_node("Player1View/SubViewport/Player1Hud")), _edge_of(views.get_node("Player2View/SubViewport/Player2Hud"))]
	for number: int in range(3, count + 1):
		_extra_players.append(_duplicate_rig(number))
	var units: Array[Unit] = all_units()
	for player: int in count:
		var team: int = lineup.teams[player]
		units[player].team_material = team_materials[team]
		var body: MeshInstance3D = units[player].get_node_or_null("Body") as MeshInstance3D
		if body != null:
			body.material_override = body_materials[team]
		var view: Node = views.get_node("Player%dView/SubViewport" % (player + 1))
		for node: Node in view.get_children():
			if &"edge_style" in node:
				node.set(&"edge_style", edges[team])
			if node is RoundOverScreen:
				(node as RoundOverScreen).use_team_names = true
	if count > 2:
		_lay_out_views(count)
	_apply_inputs()
	var pads: PadAssignment = get_node_or_null("PadAssignment") as PadAssignment
	if pads != null:
		var prefixes: Array[StringName] = []
		for player: int in count:
			prefixes.append(StringName("p%d_" % (player + 1)))
		pads.action_prefixes = prefixes
		if lineup.controls != null:
			pads.layout = lineup.controls.pad_layout()
		var reserved: Dictionary[int, int] = {}
		for player: int in count:
			if not Lineup.is_keyboard(lineup.devices[player]):
				reserved[lineup.devices[player]] = player
		pads.reserved = reserved
	match_controller.set_teams(lineup.teams)
	return true


## The Body's material override of a Unit as the scene was saved (its Team look), or null.
func _body_material(unit: Unit) -> Material:
	var body: MeshInstance3D = unit.get_node_or_null("Body") as MeshInstance3D
	return body.material_override if body != null else null


## A node's edge_style, or null when it has none.
func _edge_of(node: Node) -> Variant:
	return node.get(&"edge_style") if node != null and &"edge_style" in node else null


## Makes Player `number` (3 or 4) from Player 2's nodes (Story 048): every child of World whose name
## starts with Player2 and Player 2's view are duplicated, renamed (Player2 -> Player<number> in every
## node name), added beside the originals and owned by this scene; every Node reference among their
## properties that pointed into Player 2's nodes points into the copies, every action_prefix p2_ becomes
## p<number>_, and every exported player_index of 1 (Player 2's) becomes number - 1. Returns the new
## Player's "unit", "camera", "weapon" and "mine_layer".
func _duplicate_rig(number: int) -> Dictionary:
	var world: Node = get_node("World")
	var views: Node = get_node("Views")
	var pairs: Array = []
	var roots: Array[Node] = []
	for child: Node in world.get_children():
		if String(child.name).begins_with("Player2"):
			roots.append(child)
	roots.append(views.get_node("Player2View"))
	var copies: Array[Node] = []
	# A SubViewport under a stretching container refuses the size the duplicate copies into it (a
	# warning per copy), so the view's stretch is off while it is duplicated and back on after.
	var view: SubViewportContainer = views.get_node("Player2View") as SubViewportContainer
	var stretch: bool = view.stretch
	view.stretch = false
	for original: Node in roots:
		var copy: Node = original.duplicate()
		_pair_up(original, copy, pairs)
		copies.append(copy)
	view.stretch = stretch
	for copy: Node in copies:
		if copy is SubViewportContainer:
			(copy as SubViewportContainer).stretch = stretch
	var mapping: Dictionary = {}
	for pair: Array in pairs:
		mapping[pair[0]] = pair[1]
	var tag: String = "Player%d" % number
	for pair: Array in pairs:
		var copy: Node = pair[1]
		if (pair[0] as Node).owner == self:
			copy.unique_name_in_owner = false
		copy.name = String(copy.name).replace("Player2", tag)
	for index: int in roots.size():
		roots[index].get_parent().add_child(copies[index])
	for pair: Array in pairs:
		var original: Node = pair[0]
		var copy: Node = pair[1]
		if original.owner == self:
			copy.owner = self
			copy.unique_name_in_owner = original.unique_name_in_owner
		_repoint(copy, mapping, number)
	var unit: Unit = world.get_node(tag + "Unit") as Unit
	return {
		"unit": unit,
		"camera": views.get_node("%sView/SubViewport/%sCamera" % [tag, tag]) as ChaseCamera,
		"weapon": world.get_node(tag + "Weapon") as Weapon,
		"mine_layer": world.get_node(tag + "MineLayer") as MineLayer,
	}


## Pairs a node with its duplicate and their children with each other, depth first, into `pairs`.
func _pair_up(original: Node, copy: Node, pairs: Array) -> void:
	pairs.append([original, copy])
	for index: int in original.get_child_count():
		if index < copy.get_child_count():
			_pair_up(original.get_child(index), copy.get_child(index), pairs)


## Points a duplicated node's Node properties at the duplicates (`mapping`), and gives it Player
## `number`'s action prefix and player index (_duplicate_rig()).
func _repoint(copy: Node, mapping: Dictionary, number: int) -> void:
	for property: Dictionary in copy.get_property_list():
		if (property["usage"] & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var key: StringName = property["name"]
		if property["type"] == TYPE_OBJECT:
			var value: Variant = copy.get(key)
			if value is Node and mapping.has(value):
				copy.set(key, mapping[value])
		elif key == &"action_prefix" and copy.get(key) == &"p2_":
			copy.set(key, StringName("p%d_" % number))
		elif key == &"player_index" and not (copy is Unit) and property["type"] == TYPE_INT and copy.get(key) == 1:
			copy.set(key, number - 1)


## Stands the views in two columns (Story 048): Orange's Players on the left, Teal's on the right, in
## Player order from the top, and a dark panel where a column has one view fewer than the other.
func _lay_out_views(count: int) -> void:
	var views: Node = get_node("Views")
	var columns: Array[VBoxContainer] = []
	for team: int in 2:
		var column := VBoxContainer.new()
		column.name = "OrangeColumn" if team == 0 else "TealColumn"
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override(&"separation", VIEW_GAP)
		columns.append(column)
		views.add_child(column)
		column.owner = self
	for player: int in count:
		var view: Control = views.get_node("Player%dView" % (player + 1)) as Control
		view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		view.owner = null
		views.remove_child(view)
		columns[lineup.teams[player]].add_child(view)
		view.owner = self
	var tallest: int = maxi(columns[0].get_child_count(), columns[1].get_child_count())
	for column: VBoxContainer in columns:
		while column.get_child_count() < tallest:
			var blank := ColorRect.new()
			blank.name = "EmptyView"
			blank.color = EMPTY_VIEW_COLOUR
			blank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			blank.size_flags_vertical = Control.SIZE_EXPAND_FILL
			blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.add_child(blank)


## Gives each Player's actions the keys of that Player's keyboard half and nothing else on the
## keyboard (Story 048): the halves are the keys project.godot gives Player 1 and Player 2, read from
## the project settings, so a change made here before is never read back, or, when the lineup carries
## the Players' controls (Story 060), ControlBindings.keyboard_keys(); Players 3 and 4 get their
## actions made (named as Player 1's, with Player 1's dead zones) the first time.
func _apply_inputs() -> void:
	var sets: Dictionary = {Lineup.KEYBOARD_1: _project_keys("p1_"), Lineup.KEYBOARD_2: _project_keys("p2_")}
	if lineup.controls != null:
		sets = {Lineup.KEYBOARD_1: lineup.controls.keyboard_keys("p1_"), Lineup.KEYBOARD_2: lineup.controls.keyboard_keys("p2_")}
	var suffixes: Array[String] = []
	for keys: Dictionary in sets.values():
		for suffix: String in keys:
			if not suffixes.has(suffix):
				suffixes.append(suffix)
	for number: int in range(1, Lineup.MAX_PLAYERS + 1):
		for suffix: String in suffixes:
			var action: StringName = StringName("p%d_%s" % [number, suffix])
			if not InputMap.has_action(action):
				InputMap.add_action(action, _project_deadzone("p1_" + suffix))
			for event: InputEvent in InputMap.action_get_events(action):
				if event is InputEventKey:
					InputMap.action_erase_event(action, event)
	for player: int in lineup.player_count():
		var device: int = lineup.devices[player]
		if not Lineup.is_keyboard(device):
			continue
		var keys: Dictionary = sets[device]
		for suffix: String in keys:
			for event: InputEvent in keys[suffix]:
				InputMap.action_add_event(StringName("p%d_%s" % [player + 1, suffix]), event)


## The key events project.godot gives the actions of a prefix, by action suffix.
static func _project_keys(prefix: String) -> Dictionary:
	var keys: Dictionary = {}
	for property: Dictionary in ProjectSettings.get_property_list():
		var setting: String = property["name"]
		if not setting.begins_with("input/" + prefix):
			continue
		var entry: Variant = ProjectSettings.get_setting(setting)
		if not (entry is Dictionary):
			continue
		var events: Array = []
		for event: Variant in (entry as Dictionary).get("events", []):
			if event is InputEventKey:
				events.append(event)
		keys[setting.trim_prefix("input/" + prefix)] = events
	return keys


## The dead zone project.godot gives an action, or 0.2.
static func _project_deadzone(action: String) -> float:
	var entry: Variant = ProjectSettings.get_setting("input/" + action)
	return float((entry as Dictionary).get("deadzone", DEFAULT_DEADZONE)) if entry is Dictionary else DEFAULT_DEADZONE
