extends RefCounted
## What the Story 015 scenarios (turret_looks and the modules it runs: turret_looks_data,
## turret_looks_stages, turret_looks_fight and turret_looks_growth; and turret_looks_showcase and
## turret_looks_fps) share on top of the Story 013 kit (turrets_kit.gd): the nodes of a Turret's looks
## by name, which look and which steel a Turret shows, the look its hit points call for and the
## story's numbers. A look is read from the scene's nodes by name, never from the Structure's own
## list, so a Structure that shows the wrong one is seen. Tooling only: nothing under src/ depends on
## this file; loaded with a preload constant. Implements:
## production/epics/wasteland-fire/story-015-turret-damage-looks.md, Test Evidence.

## The nodes of a Turret's drums by path from the Turret, in the order of the hit points they stand
## for: the whole drum (AC-1) and the first and second damaged drums (AC-2); and its rubble.
const LOOK_NAMES: Array[String] = ["Look/Pedestal", "Look/PedestalDamaged1", "Look/PedestalDamaged2"]
const RUBBLE_NAME: String = "Rubble"
## The turning head, its Team-colour band and the two parts of it that wear the darker steel.
const HEAD_NAME: String = "Look/Head"
const BAND_NAME: String = "Look/Head/Band"
const WORN_NAMES: Array[String] = ["Look/Head/Dome", "Look/Head/Barrel"]
## The story's fractions of the hit points below which a Turret shows its two damaged looks (AC-1).
const DAMAGED_BELOW: Array[float] = [0.8, 0.35]
## The Shot, counted from 1, after which each type's Shots first show a Turret's first look, its
## second look and bring it down (AC-1, at 100 hit points and the damage of 25, 12, 15 and 5 at x1.0).
const CHANGES: Dictionary = {&"motorbike": [5, 14, 20], &"buggy": [2, 6, 9], &"truck": [1, 3, 4], &"gyrocopter": [2, 5, 7]}
## Hit points taken off a whole Turret to leave it exactly at the first fraction and at the second
## (20 and 65 of 100: the edge test's inputs), and then a little more to put it just below.
const TO_FIRST: float = 20.0
const TO_SECOND: float = 65.0
const JUST_BELOW: float = 0.5
## Ticks a showcase moment holds before it is read, so the frame shows a settled view; ticks the
## camera needs to settle after the view is switched; ticks a moment may take to arrive.
const HOLD_TICKS: int = 30
const VIEW_TICKS: int = 60
const LIMIT_TICKS: int = 900
## The views' settings files, by name: the view from above's and the chase view's.
const ABOVE_FILE: String = "above_camera_settings.tres"
const CHASE_FILE: String = "chase_camera_settings.tres"
## Metres the canyon-side Turret is shot at from: the canyon Fuel Can's place behind the south rock
## (world x, z of Base A's side), where no Turret sees a Unit and every Shot hits.
const CANYON_CAN: Vector3 = Vector3(-88.0, 0.0, -26.0)


## Which look a Turret shows, read from its nodes by name: 0 the whole drum, 1 or 2 the first or
## second damaged drum, -1 the rubble, or -2 unless exactly one of them is shown.
static func look_shown(who: Turret) -> int:
	var shown: Array[int] = []
	for index: int in LOOK_NAMES.size():
		var look: Node3D = who.get_node_or_null(LOOK_NAMES[index]) as Node3D
		if look != null and look.visible:
			shown.append(index)
	var rubble: Node3D = who.get_node_or_null(RUBBLE_NAME) as Node3D
	if rubble != null and rubble.visible:
		shown.append(-1)
	return shown[0] if shown.size() == 1 else -2


## The head's visibility as the Turret's own node says it.
static func head_visible(who: Turret) -> bool:
	var head: Node3D = who.get_node_or_null(HEAD_NAME) as Node3D
	return head != null and head.visible


## The steel a worn part of the head wears now: the part's material_override, null while it wears
## its mesh's own. Index into WORN_NAMES.
static func steel_of(who: Turret, index: int) -> Material:
	var part: GeometryInstance3D = who.get_node_or_null(WORN_NAMES[index]) as GeometryInstance3D
	return part.material_override if part != null else null


## True when the head's worn parts both wear the steel a look calls for (the stage's steel from the
## Turret's own list, none at 0) and its band wears its Base's Team material.
static func head_dressed(who: Turret, look: int, team: Material) -> bool:
	var want: Material = who.worn_steel[look - 1] if look >= 1 and look <= who.worn_steel.size() else null
	var band: MeshInstance3D = who.get_node_or_null(BAND_NAME) as MeshInstance3D
	return steel_of(who, 0) == want and steel_of(who, 1) == want and band != null and band.material_override == team


## The look the given stats' fractions predict at `hit_points`: -1 the rubble at 0, else how many of
## the damaged_below fractions of the maximum it is below (0 whole, 1, 2). Strictly below.
static func predicted(hit_points: float, stats: StructureStats) -> int:
	if hit_points <= 0.0:
		return -1
	var look: int = 0
	for fraction: float in stats.damaged_below:
		look += 1 if hit_points < fraction * stats.max_hit_points else 0
	return look


## How bright a material's colour is (the Rec. 709 weights of its albedo): the order of two steels.
static func shade(material: BaseMaterial3D) -> float:
	var colour: Color = material.albedo_color
	return 0.2126 * colour.r + 0.7152 * colour.g + 0.0722 * colour.b


## The Shot, counted from 1, after which a run of Shots of `damage` each at a Turret of `stats`
## first leaves each look: [first look, second look, fall], computed from the data.
static func changes_of(stats: StructureStats, damage: float) -> Array[int]:
	var found: Array[int] = [-1, -1, -1]
	var hit_points: float = stats.max_hit_points
	var count: int = 0
	while hit_points > 0.0 and count < 1000:
		hit_points = maxf(hit_points - damage, 0.0)
		count += 1
		var look: int = predicted(hit_points, stats)
		var slot: int = 2 if look == -1 else look - 1
		if look != 0 and found[slot] < 0:
			found[slot] = count
	return found
