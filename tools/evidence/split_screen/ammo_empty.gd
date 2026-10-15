extends RefCounted
## The empty gun of the Story 022 scenario ammo: AC-2. A Unit with no Shots left fires nothing (no Shot while the key is
## held, none for a press, a release and a press again, none after any wait), and everything else works as with Shots left:
## it drives and turns, an empty Truck lays its Mines, the Self-destruct destroys it and the Swap at the own Base puts it
## away, and an empty Motorbike picks up, carries and delivers a Flag (the Round ends by its delivery). Real keys. Tooling
## only. Implements: production/epics/wasteland-fire/story-022-ammo-and-full-start.md AC-2.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit22: GDScript = preload("res://tools/evidence/split_screen/ammo_kit.gd")
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")

## Ticks of a held key and of a wait with an empty gun.
const HELD_TICKS: int = 300
const WAIT_TICKS: int = 600
## Presses of the fire key, a release and the gap between them, in ticks.
const PRESSES: int = 4
const PRESS_GAP: int = 30
## Ticks a Unit is driven and turned to see that it still does.
const DRIVE_TICKS: int = 90
## The least a driving Unit moves and a turning Unit turns in those ticks (metres, radians).
const MOVED_MIN: float = 5.0
const TURNED_MIN: float = 0.3

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit22
var _q: Quick


func _init(kit: Kit22) -> void:
	_k = kit
	_q = kit.q()


func run() -> void:
	await _fires_nothing()
	await _drives_and_turns()
	await _truck_lays()
	await _self_destruct()
	await _swap()
	await _flag()


## A Buggy with its load spent: the key held, four presses with a release and a gap between, a long wait and the key
## held again fire nothing, and the count stays at zero.
func _fires_nothing() -> void:
	var problems: PackedStringArray = []
	await _k.arena_put(0, Quick.BUGGY)
	await _k.empty_gun(0)
	var gun: Weapon = _k.weapon(0)
	_q.kit.need(problems, gun.shots_left == 0 and gun.capacity > 0, "the gun is not empty: %d of %d" % [gun.shots_left, gun.capacity])
	var events: int = _k.changes[0].size()
	var held: Array[Dictionary] = await _k.hold(0, HELD_TICKS)
	_q.kit.need(problems, held.is_empty(), "%d Shots came while the key was held on an empty gun" % held.size())
	var pressed: int = 0
	for _press: int in PRESSES:
		pressed += (await _k.press(0)).size()
		await _q.kit.advance(PRESS_GAP)
	_q.kit.need(problems, pressed == 0, "%d Shots came for %d presses, releases and presses again" % [pressed, PRESSES])
	await _q.kit.advance(WAIT_TICKS)
	var after_wait: int = (await _k.press(0)).size() + (await _k.hold(0, HELD_TICKS)).size()
	_q.kit.need(problems, after_wait == 0, "%d Shots came after a wait of %d ticks" % [after_wait, WAIT_TICKS])
	_q.kit.need(problems, gun.shots_left == 0 and _k.changes[0].size() == events and _k.line(0) == "Ammo 0 / %d" % gun.capacity, "the count moved while the gun was empty: %d left, %d reports since, the line reads '%s'" % [gun.shots_left, _k.changes[0].size() - events, _k.line(0)])
	_q.kit.verdict("empty_gun_fires_nothing", problems, "a Buggy with its 50 Shots spent fired none while the fire key was held for %d ticks, for %d presses with a release between, for a press after a wait of %d ticks, or while it was held again; the count stayed at 0 of %d and nothing was reported" % [HELD_TICKS, PRESSES, WAIT_TICKS, gun.capacity])


## The same empty Buggy still drives and still turns on the spot.
func _drives_and_turns() -> void:
	var problems: PackedStringArray = []
	var unit: Unit = _k.unit(0)
	var from: Vector3 = unit.global_position
	_q.harness.drive(0, 1, 0)
	await _q.kit.advance(DRIVE_TICKS)
	_q.harness.drive(0, 0, 0)
	var moved: float = unit.global_position.distance_to(from)
	_q.kit.need(problems, moved >= MOVED_MIN, "the empty Buggy moved only %.2f m in %d ticks of throttle" % [moved, DRIVE_TICKS])
	var yaw: float = Quick.yaw(unit)
	_q.harness.drive(0, 0, 1)
	await _q.kit.advance(DRIVE_TICKS)
	_q.harness.drive(0, 0, 0)
	var turned: float = absf(Quick.turned(yaw, Quick.yaw(unit)))
	_q.kit.need(problems, turned >= TURNED_MIN, "the empty Buggy turned only %.2f rad in %d ticks of steering" % [turned, DRIVE_TICKS])
	_q.kit.need(problems, _k.weapon(0).shots_left == 0, "driving gave the gun %d Shots" % _k.weapon(0).shots_left)
	measured.append("empty_moved=%.1f" % moved)
	_q.kit.verdict("empty_unit_drives_and_turns", problems, "the empty Buggy drove %.1f m in %d ticks of throttle and turned %.2f rad in %d ticks of steering, and its gun stayed empty" % [moved, DRIVE_TICKS, turned, DRIVE_TICKS])


## An empty Truck still lays its Mines: a press lays one, the count goes 5 to 4, and the two lines read side by side.
func _truck_lays() -> void:
	var problems: PackedStringArray = []
	await _k.arena_put(0, Quick.TRUCK)
	await _k.empty_gun(0)
	var layer: MineLayer = _k.mines().layers[0]
	var before: int = _k.mines().laid.size()
	var record: Dictionary = await _k.mines().lay(0)
	_q.kit.need(problems, not record.is_empty() and _k.mines().laid.size() == before + 1, "the empty Truck's press laid %d Mines" % (_k.mines().laid.size() - before))
	_q.kit.need(problems, layer.mines_left == layer.capacity - 1 and _k.weapon(0).shots_left == 0, "the Truck holds %d of %d Mines and %d Shots" % [layer.mines_left, layer.capacity, _k.weapon(0).shots_left])
	_q.kit.need(problems, _k.line(0) == "Ammo 0 / 25" and _k.mines().line(0) == "Mines 4 / 5", "the lines read '%s' and '%s'" % [_k.line(0), _k.mines().line(0)])
	_q.kit.verdict("empty_truck_lays", problems, "a Truck with its 25 Shots spent laid a Mine for one press of E: Mines 5 -> 4 beside 'Ammo 0 / 25', the gun still empty")


## The Self-destruct destroys an empty Unit and costs a Token, as with Shots left; the Player then chooses a Buggy.
func _self_destruct() -> void:
	var problems: PackedStringArray = []
	var tokens: int = _k.k.tokens(0, Quick.TRUCK)
	var mark: int = _q.tokens.events.size()
	await _q.tokens.destruct(0)
	await _q.tokens.wait_for(&"destroyed", mark)
	await _q.kit.advance(Kit22.SETTLE)
	_q.kit.need(problems, not _q.controller.is_alive(0) and _q.controller.is_choosing(0), "the Self-destruct did not destroy the empty Truck (alive %s, choosing %s)" % [_q.controller.is_alive(0), _q.controller.is_choosing(0)])
	_q.kit.need(problems, _k.k.tokens(0, Quick.TRUCK) == tokens - 1, "the Truck Tokens went %d -> %d" % [tokens, _k.k.tokens(0, Quick.TRUCK)])
	_q.kit.need(problems, _k.line(0) == "hidden" and _k.weapon(0).shots_left == 0 and _k.weapon(0).capacity == 0, "the destroyed Truck still shows '%s' (%d of %d)" % [_k.line(0), _k.weapon(0).shots_left, _k.weapon(0).capacity])
	_q.kit.need(problems, await _q.tokens.spawn(0, Quick.BUGGY), "no Buggy came into play after the choice")
	_q.kit.verdict("empty_self_destruct", problems, "the Self-destruct destroyed the empty Truck outside the own Base, took one Truck Token (%d -> %d), left no count behind and a Buggy was chosen" % [tokens, tokens - 1])


## The Swap at the own Base puts an empty Unit away at no cost, and the Player chooses again at once.
func _swap() -> void:
	var problems: PackedStringArray = []
	await _k.arena_put(0, Quick.BUGGY)
	await _k.empty_gun(0)
	await _k.swap().enter(0)
	var swappable: int = await _k.swap().wait_swappable(0)
	var tokens: int = _k.k.tokens(0, Quick.BUGGY)
	var swaps: int = _k.swap().swaps.size()
	await _q.tokens.destruct(0)
	await _q.kit.advance(Kit22.SETTLE)
	_q.kit.need(problems, swappable >= 0 and _k.swap().swaps.size() == swaps + 1 and _q.controller.is_choosing(0), "the Swap did not put the empty Buggy away (swappable %d, swaps %d -> %d, choosing %s)" % [swappable, swaps, _k.swap().swaps.size(), _q.controller.is_choosing(0)])
	_q.kit.need(problems, _k.k.tokens(0, Quick.BUGGY) == tokens, "the Swap cost a Token: %d -> %d" % [tokens, _k.k.tokens(0, Quick.BUGGY)])
	_q.kit.need(problems, await _q.tokens.spawn(0, Quick.MOTORBIKE), "no Motorbike came into play after the Swap")
	_q.kit.verdict("empty_swap", problems, "the Swap at the own Base put the empty Buggy away with no Token taken (%d), the Player chose a Motorbike at once and it appeared" % tokens)


## An empty Motorbike takes the other Base's Flag through the Gate, carries it out and delivers it home: the Round ends.
func _flag() -> void:
	var problems: PackedStringArray = []
	await _k.arena_put(1, Quick.MOTORBIKE)
	await _k.empty_gun(1)
	var gun: Weapon = _k.weapon(1)
	await _k.k.walls().restore_all(true)
	await _k.k.walls().turrets_down()
	_k.k.flags().wall(0, Walls.GATE).destroy()
	await _q.kit.advance(Walls.SETTLE)
	var taken: bool = await _k.k.flags().take_flag(1, 0, Walls.GATE)
	_q.kit.need(problems, taken and _k.k.flags().carrying(1) and gun.shots_left == 0, "the empty Motorbike did not take the Flag (taken %s, carrying %s, %d Shots)" % [taken, _k.k.flags().carrying(1), gun.shots_left])
	await _k.k.flags().back_out(1, 0, Walls.GATE)
	var delivered: bool = await _k.k.flags().deliver(1)
	_q.kit.need(problems, delivered and _q.controller.is_round_over() and gun.shots_left == 0, "the Round did not end by the empty Carrier's delivery (delivered %s, over %s, %d Shots)" % [delivered, _q.controller.is_round_over(), gun.shots_left])
	_q.kit.need(problems, _k.line(1) == "Ammo 0 / 100", "the Round-over screen sits over the line '%s'" % _k.line(1))
	await _k.k.flags().restart()
	_q.kit.verdict("empty_motorbike_carries_a_flag", problems, "a Motorbike with its 100 Shots spent took Base A's Flag through the broken Gate wall, backed out and delivered it: the Round ended by its delivery, the gun still empty ('Ammo 0 / 100'); R then started a fresh Round")
