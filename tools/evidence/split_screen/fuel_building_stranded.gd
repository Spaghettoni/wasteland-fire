extends RefCounted
## Running dry in the Story 023 scenario fuel_building, AC-5: a ground Unit that runs out of Fuel anywhere but in a Fuel zone stays
## stranded (nothing on the Map refuels it, the throttle moves it nowhere) and its Player's view shows the out-of-Fuel hint offering the
## Self-destruct, which brings a new Unit with a full tank; inside the own Base the hint offers the Swap and it does the same; a Unit that is
## dry while stopped in a Fuel zone is refuelled there, its hint goes, and it drives on, where one just outside the zone stays dry. Real
## keys. Tooling only. Implements: production/epics/wasteland-fire/story-023-fuel-building.md AC-5.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit23: GDScript = preload("res://tools/evidence/split_screen/fuel_building_kit.gd")

const SETTINGS_PATH: String = "res://src/gameplay/supply/data/supply_settings.tres"
## Where a Truck runs dry far from the depot and the Bases: open flat, 48 m from the west zone.
const FAR_SPOT: Vector3 = Vector3(-60.0, 0.0, -8.0)
## Ticks a stranded Unit is watched with the throttle held.
const STRANDED_TICKS: int = 600
## Ticks the first gift to a Unit spawned dry in a zone may be late (measured by the rate module: the third row).
const FIRST_GIFT_ROW: int = 3
## Metres a Unit that drives on must get from where it was.
const DRIVE_ON: float = 5.0
## Ticks of the drive on, and of the pair at the zone's face.
const DRIVE_TICKS: int = 120
const EDGE_TICKS: int = 150
## How far in and out of the zone's west face a Truck's nose is, metres.
const EDGE_DEPTH: float = 0.2

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit23
var _q: Quick
var _settings: SupplySettings


func _init(kit: Kit23) -> void:
	_k = kit
	_q = kit.q()
	_settings = load(SETTINGS_PATH) as SupplySettings


func run() -> void:
	await _stranded_far_away()
	await _swap_in_the_base()
	await _dry_in_a_zone()
	await _dry_at_the_face()


## How many rows a Player's record shows the hint on.
func _hint_rows(player: int) -> int:
	var count: int = 0
	for row: Dictionary in _k.rows(player):
		count += 1 if bool(row["hint"]) else 0
	return count


## An empty Truck far from every zone, the throttle held for STRANDED_TICKS: its tank stays at exactly zero, it does not move, its hint is
## on every row and names the Self-destruct; the Self-destruct then brings a new Truck with a whole tank and the hint goes.
func _stranded_far_away() -> void:
	var problems: PackedStringArray = []
	await _k.park(1)
	await _k.put(0, Quick.TRUCK, FAR_SPOT, Vector3.RIGHT, 0.0)
	_k.watch.clear()
	_k.watch.logging = true
	await _k.a.k.drive(0, STRANDED_TICKS)
	_k.watch.logging = false
	var hint: SelfDestructHint = _q.hints[0]
	var worst: float = 0.0
	for row: Dictionary in _k.rows(0):
		worst = maxf(worst, float(row["fuel"]))
	_q.kit.need(problems, worst == 0.0 and _k.unit(0).is_stranded, "the stranded Truck held up to %.6f Fuel (stranded %s)" % [worst, _k.unit(0).is_stranded])
	_q.kit.need(problems, _k.unit(0).global_position.distance_to(FAR_SPOT) < 0.05, "the stranded Truck moved %.3f m with the throttle held" % _k.unit(0).global_position.distance_to(FAR_SPOT))
	_q.kit.need(problems, _hint_rows(0) == _k.rows(0).size() and hint.visible and hint.text.contains("Self-destruct") and hint.text.contains("Tab"), "the hint showed on %d of %d rows and read '%s'" % [_hint_rows(0), _k.rows(0).size(), hint.text])
	_q.kit.need(problems, _hint_rows(1) == 0, "Player 2's hint showed on %d rows" % _hint_rows(1))
	await _q.tokens.destruct(0)
	_q.kit.need(problems, await _q.tokens.spawn(0, Quick.TRUCK), "no new Truck came after the Self-destruct")
	var fresh: Unit = _k.unit(0)
	_q.kit.need(problems, is_equal_approx(fresh.fuel, fresh.fuel_capacity) and fresh.fuel_capacity > 0.0 and not hint.visible, "the new Truck holds %.1f of %.1f Fuel and the hint is shown %s" % [fresh.fuel, fresh.fuel_capacity, hint.visible])
	measured.append("stranded_%d_ticks_fuel_%.1f" % [STRANDED_TICKS, worst])
	_q.kit.verdict("stranded_far_from_the_depot", problems, "an empty Truck %.0f m from the west zone stayed at exactly %.1f Fuel for %d ticks with the throttle held, motionless, the hint ('%s') on every row; its Self-destruct (Tab) brought a new Truck with %.1f of %.1f Fuel and the hint went" % [absf(FAR_SPOT.x - _k.centre(0).x), worst, STRANDED_TICKS, hint.text if hint.visible else "Out of Fuel! Press Tab to Self-destruct", fresh.fuel, fresh.fuel_capacity])


## An empty Truck inside its own Base: the hint offers the swap, and the key swaps the Unit for a new Truck with a whole tank.
func _swap_in_the_base() -> void:
	var problems: PackedStringArray = []
	var swap: Object = _k.a.swap()
	var hint: SelfDestructHint = _q.hints[0]
	await _k.a.mines().put_stranded(0, swap.inside_point(0), swap.into_base(0))
	_q.kit.need(problems, await swap.wait_swappable(0) >= 0, "the Base's zone never reported the stranded Truck")
	await _q.kit.advance(Kit23.SETTLE)
	var text: String = hint.text
	_q.kit.need(problems, hint.visible and text.contains("swap") and text.contains("Tab"), "the hint in the Base read '%s' (shown %s)" % [text, hint.visible])
	await _q.tokens.destruct(0)
	_q.kit.need(problems, await _q.tokens.spawn(0, Quick.TRUCK), "no new Truck came after the swap")
	var fresh: Unit = _k.unit(0)
	_q.kit.need(problems, is_equal_approx(fresh.fuel, fresh.fuel_capacity) and not hint.visible, "the swapped-in Truck holds %.1f of %.1f Fuel and the hint is shown %s" % [fresh.fuel, fresh.fuel_capacity, hint.visible])
	measured.append("swap_hint=%s" % text.replace(" ", "_"))
	_q.kit.verdict("stranded_in_the_base_is_swapped", problems, "an empty Truck inside its own Base showed '%s', and the key swapped it for a new Truck with %.1f of %.1f Fuel" % [text, fresh.fuel, fresh.fuel_capacity])


## A Truck spawned empty in the west zone is stranded for the first rows, with its hint, until the zone's first gift; its hint goes and it
## drives on.
func _dry_in_a_zone() -> void:
	var problems: PackedStringArray = []
	await _k.park(0)
	await _k.put_recorded(0, Quick.TRUCK, _k.centre(0), Vector3.RIGHT, 0.0, 2 * FIRST_GIFT_ROW + 10)
	var hint: SelfDestructHint = _q.hints[0]
	var shown: int = _hint_rows(0)
	var first: int = _k.first_gain(0)
	_q.kit.need(problems, shown >= 1 and shown <= FIRST_GIFT_ROW and first == FIRST_GIFT_ROW, "the hint showed on %d rows and the first gift came in row %d" % [shown, first])
	_q.kit.need(problems, not bool(_k.rows(0).back()["hint"]) and not hint.visible and not _k.unit(0).is_stranded, "the hint is still shown (%s) or the Unit still stranded" % hint.visible)
	var before: Vector3 = _k.unit(0).global_position
	await _k.a.k.drive(0, DRIVE_TICKS)
	_q.kit.need(problems, _k.unit(0).global_position.distance_to(before) >= DRIVE_ON, "the Truck drove on only %.2f m" % _k.unit(0).global_position.distance_to(before))
	measured.append("dry_in_zone_hint_rows=%d_first_gift_row=%d" % [shown, first])
	_q.kit.verdict("dry_in_a_zone_is_refuelled_and_drives_on", problems, "a Truck spawned empty in the west zone was stranded, its hint shown, on %d rows and was given its first Fuel in row %d; the hint went and with the throttle held it drove %.1f m on" % [shown, first, _k.unit(0).global_position.distance_to(before)])
	await _k.park(0)


## Two empty Trucks, one with its nose EDGE_DEPTH inside the west face of the zone and one the same distance outside: the first is refuelled,
## the second stays at zero with its hint on.
func _dry_at_the_face() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	var face: float = _k.centre(0).x - 3.0
	var outcome: PackedStringArray = []
	for depth: float in [EDGE_DEPTH, -EDGE_DEPTH]:
		await _k.put(0, Quick.TRUCK, Vector3(face - stats.collision_size.z / 2.0 + depth, 0.0, 0.0), Vector3.RIGHT, 0.0)
		_k.watch.clear()
		_k.watch.logging = true
		await _q.kit.advance(EDGE_TICKS)
		_k.watch.logging = false
		var inside: bool = depth > 0.0
		var fuel: float = float(_k.rows(0).back()["fuel"])
		_q.kit.need(problems, (fuel > 0.0) == inside and (fuel == 0.0) == (not inside), "the Truck with its nose %.1f m %s the face ended with %.3f Fuel" % [absf(depth), "inside" if inside else "outside", fuel])
		_q.kit.need(problems, bool(_k.rows(0).back()["hint"]) == (not inside), "the hint was %s with the nose %.1f m %s the face" % ["shown" if bool(_k.rows(0).back()["hint"]) else "hidden", absf(depth), "inside" if inside else "outside"])
		outcome.append("%s: %.1f Fuel" % ["inside" if inside else "outside", fuel])
	_q.kit.verdict("dry_at_the_zone_face", problems, "two empty Trucks at the west face of the zone, the nose %.1f m inside and %.1f m outside, after %d ticks: %s; the one outside stayed stranded with its hint on" % [EDGE_DEPTH, EDGE_DEPTH, EDGE_TICKS, ", ".join(outcome)])
	await _k.park(0)
