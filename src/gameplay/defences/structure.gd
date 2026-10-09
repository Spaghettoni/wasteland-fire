class_name Structure
extends StaticBody3D
## A damageable piece of the Map that is not a Unit: solid while it stands, rubble that blocks
## nothing once its hit points are gone, and back with all of them when the Round is played again.
## A Flag Wall is one (Story 012); so is a Turret (Story 013), which extends it.
##
## Implements: production/epics/wasteland-fire/story-012-flag-walls.md AC-2 to AC-5, AC-8 and
## AC-9; design/rules.md "Turrets, Flag Walls and Mines". Vocabulary: CONTEXT.md (Flag Wall).
##
## What a Shot needs from a body before it damages it (see Shot): an apply_damage() method, a
## type_id that is a StringName and, to spare a Player's own pieces, a player_index. This node
## offers all three, so a Shot treats it as it treats a Unit and no branch in code names a type;
## the Structure knows no Unit, no Base and no Round. SplitScreen sets player_index once and calls
## restore() when a Round starts again; nothing else drives it, and no key or rule builds, repairs
## or captures one.
##
## Falling. destroy() takes the piece out of play the way a Unit leaves play (Unit.destroy()):
## collision_layer and collision_mask go to zero in that same tick, the look it showed is hidden
## and the rubble shown. With both zero the body neither collides nor is collided with, and
## nothing logs. The node keeps its process_mode: PROCESS_MODE_DISABLED made Jolt log 'Parameter
## "space" is null' when a Unit's destroy() ran inside its own physics tick (Unit's class doc), so
## it is not used. Call apply_damage() and destroy() from a physics tick or from _process, never
## from an Area3D or body signal handler, for the reason Unit.apply_damage() gives. Whether a body
## whose layer was zeroed inside a tick still answers a ray query in that same tick is measured by
## the flag_walls scenario (story 012, "Measure first"), not assumed.
##
## Coming back. restore() refills the hit points, gives back the layer and mask the scene had when
## it entered the tree, shows the intact look and hides the damaged looks and the rubble. Call it
## only while no Unit overlaps the piece: a Unit inside a piece that regains its layer would be
## pushed out of it, as a Unit put down inside another is (Unit's class doc; not measured for a
## Structure, because the shipped game never does it). A restart guarantees it: every Flag is
## seated and both Units are benched before the Round starts again.
##
## Looking hurt (Story 012 AC-9). While it stands, a piece shows how much of its hit points it has
## lost: each of the stats' damaged_below fractions has a node in damaged_looks, and below a
## fraction of its hit points the piece shows that fraction's node in place of intact. Only the
## look changes: the collider, the physics layer and what a Shot or a Unit meets stay those of the
## whole piece until it falls. The look follows each hit that changes the hit points; the fall
## shows the wreck and restore() the intact look. A list of looks that does not match the
## fractions is one error in _ready(), and the piece then shows only its intact look until it
## falls.
##
## Stats that are missing or unusable (StructureStats.first_problem()) are one error in _ready().
## The piece then stays plain, solid geometry and logs nothing more: type_id is empty, is_standing
## is false, and apply_damage() and restore() do nothing. That matters because a Shot reads
## type_id from every body it may damage, and a bare stats.type_id would raise a script error on
## every Shot that ends on such a piece.

## Emitted when the hit points change: with the hit points left and the maximum, once per hit that
## the piece survives, once with zero when it falls and once with the maximum when it is restored.
## Never for an ignored call. For display and the evidence: nothing in the game listens to it.
signal hit_points_changed(hit_points: float, max_hit_points: float)

## Emitted once when the piece falls, after hit_points_changed. For display and the evidence:
## nothing in the game listens to it.
signal destroyed

## Emitted when restore() has brought the piece back, after hit_points_changed. For display and the
## evidence: nothing in the game listens to it.
signal restored

## What the piece is made of: its type id, its hit points and the fractions of them below which it
## looks hurt (a StructureStats .tres). Required; a piece without usable stats is plain, solid
## geometry (class doc). The resource is shared, so never write to it at runtime.
@export var stats: StructureStats

## The node shown while the piece stands and no damaged look is due, hidden while one is and once
## it has fallen. Optional; the Flag Wall's is its drawn box, a direct MeshInstance3D child named
## Mesh (the Gyrocopter's model rises to the top of a body's direct GeometryInstance3D children).
@export var intact: Node3D

## The node shown once the piece has fallen, hidden while it stands. Optional; the Flag Wall's is
## a few low boxes with no collider. It is hidden in the scene.
@export var wreck: Node3D

## The nodes shown in place of intact as a standing piece loses hit points, one per fraction of the
## stats' damaged_below and in the same order: below the first fraction of its hit points the first
## is shown, below the second the second, and so on, and each is hidden otherwise (class doc,
## Looking hurt). Optional; empty by default, for stats with no fractions. The Flag Wall's are
## MeshDamaged1 and MeshDamaged2, hidden in the scene: each a direct MeshInstance3D child that
## draws the same box as Mesh, darker and cracked, with chunks at its foot and no collider.
@export var damaged_looks: Array[Node3D] = []

## The Player this piece belongs to: 0 for Player 1, 1 for Player 2, -1 for none. SplitScreen sets
## it once, before the Round begins, from the Base whose list holds the piece. A Shot reads it to
## end on a Player's own piece and do nothing to it; at -1 every Shot damages it.
var player_index: int = -1

## Which kind of piece this is: stats.type_id, for the damage matrix. Empty while the stats are
## refused. Read-only: assigning to it pushes an error and changes nothing; it is the StructureStats
## data.
var type_id: StringName:
	get:
		return stats.type_id if _usable else &""
	set(_value):
		push_error("Structure '%s': type_id is read-only. It is the StructureStats data." % name)

## Hit points left: the stats' maximum while the piece stands whole, down to zero, which makes it
## fall. Zero while the stats are refused. Read-only: assigning to it pushes an error and changes
## nothing; it moves only through apply_damage(), destroy() and restore().
var hit_points: float:
	get:
		return _hit_points
	set(_value):
		push_error("Structure '%s': hit_points is read-only. Change it with apply_damage(), destroy() or restore()." % name)

## Whether this piece keeps its Base's Flag from the other Player while it stands: stats.locks_flag,
## the data (Story 013 AC-5; true for a Turret, false for a Flag Wall). False while the stats are
## refused. A fallen piece locks nothing: the Flag rules ask is_standing too. Read-only: assigning
## to it pushes an error and changes nothing.
var locks_flag: bool:
	get:
		return stats.locks_flag if _usable else false
	set(_value):
		push_error("Structure '%s': locks_flag is read-only. It is the StructureStats data." % name)

## True while the piece stands (solid, with hit points left); false once it has fallen and while
## its stats are refused. Read-only: assigning to it pushes an error and changes nothing.
var is_standing: bool:
	get:
		return _standing
	set(_value):
		push_error("Structure '%s': is_standing is read-only. Change it with destroy() or restore()." % name)

var _usable: bool = false
var _standing: bool = false
var _hit_points: float = 0.0
## Whether damaged_looks matches the stats' damaged_below fractions (_looks_problem()); while it
## does not, the piece shows only its intact look until it falls.
var _looks_usable: bool = false
## The physics layer and mask the scene gave the piece when it entered the tree, which restore()
## gives back.
var _scene_layer: int = 0
var _scene_mask: int = 0


func _ready() -> void:
	_scene_layer = collision_layer
	_scene_mask = collision_mask
	var problem: String = _stats_problem()
	if not problem.is_empty():
		push_error("Structure '%s': %s, so it stays plain solid geometry that nothing can damage." % [name, problem])
		return
	_usable = true
	_standing = true
	_hit_points = stats.max_hit_points
	var looks_problem: String = _looks_problem()
	_looks_usable = looks_problem.is_empty()
	if not _looks_usable:
		push_error("Structure '%s': %s, so it shows only its intact look until it falls." % [name, looks_problem])
	_show_look()


## Takes hit points off a standing piece: subtracts amount, never below zero, and makes the piece
## fall when none are left. A hit it survives shows the look its hit points now call for (class
## doc, Looking hurt) and emits hit_points_changed once; the lethal hit emits it once from
## destroy(), with zero. Ignored, with nothing emitted, when amount is zero, negative or NaN and
## when the piece has fallen, so a fallen piece cannot fall twice. A Shot calls it from its own
## physics tick (see Shot); call it from a tick, never from a physics signal handler.
func apply_damage(amount: float) -> void:
	if not _standing or not (amount > 0.0):
		return
	_hit_points = maxf(_hit_points - amount, 0.0)
	if _hit_points <= 0.0:
		destroy()
		return
	_show_look()
	hit_points_changed.emit(_hit_points, stats.max_hit_points)


## Makes a standing piece fall at once, whatever its hit points: its layer and mask go to zero, the
## look it showed is hidden and the rubble shown, then hit_points_changed is emitted with zero and
## then `destroyed`, once each. Does nothing when the piece has fallen or its stats are refused.
## Call it from a tick, never from a physics signal handler (apply_damage()).
func destroy() -> void:
	if not _standing:
		return
	_standing = false
	_hit_points = 0.0
	collision_layer = 0
	collision_mask = 0
	_show_look()
	hit_points_changed.emit(_hit_points, stats.max_hit_points)
	destroyed.emit()


## Brings the piece back whole, standing or fallen: the hit points to the maximum, the layer and
## mask the scene gave it, the intact look shown and the damaged looks and the rubble hidden, then
## hit_points_changed with the maximum and then `restored`, once each. Does nothing while the stats
## are refused. Call it only while no Unit overlaps the piece (class doc).
func restore() -> void:
	if not _usable:
		return
	_standing = true
	_hit_points = stats.max_hit_points
	collision_layer = _scene_layer
	collision_mask = _scene_mask
	_show_look()
	hit_points_changed.emit(_hit_points, stats.max_hit_points)
	restored.emit()


## What is wrong with the stats, as a sentence, or an empty String when they are usable.
func _stats_problem() -> String:
	if stats == null:
		return "stats is not assigned"
	var problem: String = stats.first_problem()
	return "" if problem.is_empty() else "stats are refused: %s" % problem


## What is wrong with damaged_looks against the stats' damaged_below fractions, as a sentence, or
## an empty String when each fraction has its node.
func _looks_problem() -> String:
	if damaged_looks.size() != stats.damaged_below.size():
		return "%d damaged looks for %d damaged_below fractions" % [damaged_looks.size(), stats.damaged_below.size()]
	for index: int in damaged_looks.size():
		if damaged_looks[index] == null:
			return "damaged look %d is not assigned" % (index + 1)
	return ""


## How many of the stats' damaged_below fractions the hit points are below: 0 while the piece keeps
## enough of them for every damaged look, 1 below the first fraction, 2 below the second, and so on.
## Below is strict: a piece at exactly a fraction of its hit points still shows the look above it.
func _damage_stage() -> int:
	var stage: int = 0
	for fraction: float in stats.damaged_below:
		if _hit_points < fraction * stats.max_hit_points:
			stage += 1
	return stage


## Shows the one look that fits the piece and hides the others: the wreck once it has fallen, else
## the damaged look of its stage, else the intact look. While damaged_looks is refused the stage
## stays 0, so its nodes are hidden. A look that is not assigned is skipped.
func _show_look() -> void:
	var stage: int = _damage_stage() if _standing and _looks_usable else 0
	if intact != null:
		intact.visible = _standing and stage == 0
	for index: int in damaged_looks.size():
		var look: Node3D = damaged_looks[index]
		if look != null:
			look.visible = _standing and stage == index + 1
	if wreck != null:
		wreck.visible = not _standing
