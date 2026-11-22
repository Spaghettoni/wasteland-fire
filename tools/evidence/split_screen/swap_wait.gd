extends RefCounted
## Scenario swap_wait of the split screen evidence harness (split_screen_harness.gd): Story 070 on the shipped data and Map 01,
## with real keys (Martin, 2026-11-22: "nemozes resetnut vozidlo len tak. musi Ti dojst fuel. a ked si ides sam vymenit voz,
## budes mat 3 respawn time aby si to nezneuzival"). CHECK lines:
##  W1 the swap waits: Player 1 swaps its Motorbike at home; the respawn countdown shows rules.swap_respawn_seconds, and the
##     Motorbike chosen at once appears no sooner than that after the swap.
##  W2 no Self-destruct with Fuel: out of its Base with Fuel in the tank, the key does nothing (the Unit stays in play, no
##     destruction, its Tokens kept).
##  W3 Self-destruct on an empty tank: the same Unit with its tank emptied is destroyed by the key.
## Implements: production/epics/wasteland-fire/story-070-swap-wait-empty-destruct.md AC-2 and AC-3. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=swap_wait

const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")

const OWN_CHOICE: bool = true
const OWN_BASE_SWAP: bool = true
const SWAP_WAIT: bool = true
const SHIPPED_CAMERA: bool = true
const STOCK_COUNTS: Dictionary = {&"motorbike": 3, &"buggy": 3, &"truck": 3, &"gyrocopter": 3}
const WATCHDOG_SECONDS: float = 120.0
## Ticks the Unit stands outside before the key, so the zone has let go of it.
const OUT_TICKS: int = 12
const AFTER_KEY_TICKS: int = 10
const SECONDS_TOLERANCE: float = 0.05

var _s: Swap


func run(harness: Node) -> void:
	_s = Swap.new(harness)
	await _s.both_play()
	await _check_swap_waits()
	await _check_no_destruct_with_fuel()
	_s.close()
	harness.finish("swap_wait=%.1fs needs_empty=%s" % [_s.controller.rules.swap_respawn_seconds, _s.controller.rules.self_destruct_needs_empty_fuel])


func _check_swap_waits() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var wait: float = _s.controller.rules.swap_respawn_seconds
	var swaps_before: int = _s.swaps.size()
	await _s.zone_latency(0)
	await _s.q.kit.press_settled(Tokens.keys(&"destruct", 0))
	var swapped: bool = _s.swaps.size() > swaps_before
	var record: Dictionary = _s.swaps[-1] if swapped else {}
	var swap_tick: int = int(record.get("tick", 0))
	await _s.q.kit.advance(2)
	var countdown: bool = _s.q.units.countdowns[0].visible
	var appeared: bool = await _s.q.tokens.choose(0, Quick.MOTORBIKE) and await _s.q.units.wait_alive(0, _s.q.harness.ticks_in(wait) + Kit.RESPAWN_SLACK_TICKS) >= 0
	var waited: float = float(_s.spawned_tick(0) - swap_tick) / float(Engine.physics_ticks_per_second)
	_s.q.kit.need(problems, swapped, "the key at home did not swap")
	_s.q.kit.need(problems, absf(float(record.get("wait_s", 0.0)) - wait) <= SECONDS_TOLERANCE, "the swap's wait read %.2f s, %.2f expected" % [float(record.get("wait_s", 0.0)), wait])
	_s.q.kit.need(problems, countdown, "no respawn countdown after the swap")
	_s.q.kit.need(problems, appeared and waited >= wait - SECONDS_TOLERANCE, "the next Unit appeared %.2f s after the swap (appeared %s), the wait %.2f s" % [waited, appeared, wait])
	_s.q.kit.verdict("W1_the_swap_waits", problems, "swap at home: wait %.2f s, countdown shown %s; the Motorbike chosen at once appeared %.2f s after the swap" % [
		float(record.get("wait_s", 0.0)), countdown, waited])


func _check_no_destruct_with_fuel() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var unit: Unit = _s.q.units.units[0]
	await _s.wait_swappable(0)
	_s.flags.teleport(0, _s.outside_point(0), _s.gate_way(0))
	await _s.q.kit.advance(OUT_TICKS)
	var destroyed_before: int = _s.count("destroyed 0")
	var fuel: float = unit.fuel
	var swap_possible: bool = _s.controller.can_swap(0)
	await _s.q.kit.press_settled(Tokens.keys(&"destruct", 0))
	await _s.q.kit.advance(AFTER_KEY_TICKS)
	var kept: bool = _s.controller.is_alive(0) and _s.count("destroyed 0") == destroyed_before
	_s.q.kit.need(problems, not swap_possible, "the Unit was still in its Base's zone")
	_s.q.kit.need(problems, kept, "Self-destruct with %.1f Fuel destroyed the Unit" % fuel)
	_s.q.kit.verdict("W2_no_destruct_with_fuel", problems, "out of the Base with %.1f Fuel: the key left the Unit in play %s" % [fuel, kept])

	problems = PackedStringArray()
	unit._fuel = 0.0
	await _s.q.kit.advance(2)
	var empty: bool = unit.is_fuel_empty
	await _s.q.kit.press_settled(Tokens.keys(&"destruct", 0))
	await _s.q.kit.advance(AFTER_KEY_TICKS)
	var gone: bool = not _s.controller.is_alive(0) and _s.count("destroyed 0") == destroyed_before + 1
	_s.q.kit.need(problems, empty, "the tank did not read empty")
	_s.q.kit.need(problems, gone, "Self-destruct on an empty tank did not destroy the Unit")
	_s.q.kit.verdict("W3_destruct_on_empty", problems, "the tank emptied (empty %s): the key destroyed the Unit %s" % [empty, gone])
