extends RefCounted
## Scenario resource_bars of the split screen evidence harness (split_screen_harness.gd): Fuel lasts three times longer and the
## HUD shows Fuel and ammo as two coloured bars with icons (Story 036; the burn made half the old instead of a third on 2026-10-19), on Map 01 with the shipped data, real keys. CHECK lines:
##  R1 the data: every type's fuel_use and fuel_use_idle are half the rates before the story (the runner's
##     LEGACY_036_FUEL_RATES), the tank is unchanged (AC-1, AC-5).
##  R2 the burn: Player 1's Motorbike driven on W for BURN_TICKS and standing for BURN_TICKS burns what the new rates give,
##     half the old (AC-1).
##  R3 the band: in each view, right of the hit-point bar on the same row, the Fuel icon, the Fuel bar, the ammo icon and the
##     ammo bar, in that order, inside the 640 px view and inside the Team edge; no Fuel line, no Label on that row but the
##     hit-point line, no Ammo line under the band; the ammo bar's colour is none of the hit-point green, the Fuel amber or
##     either Team colour (AC-2, AC-3, AC-4).
##  R4 the bars follow: the Fuel bar shows the Unit's Fuel and its tank, the ammo bar the Weapon's Shots and its load, and
##     Space (Player 1's fire) lowers Player 1's ammo bar and not Player 2's (AC-2).
##  R5 no Unit in play: a Weapon announcing capacity 0 (its count emptied while no Unit is chosen) leaves the ammo bar and
##     its icon shown, the bar empty, as the Fuel bar is; its load back fills it (AC-3, Martin 2026-10-19).
## Implements: production/epics/wasteland-fire/story-036-slower-fuel-and-resource-bars.md AC-1 to AC-5.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=resource_bars

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## The slower Fuel and the resource bars, as shipped.
const RESOURCE_BARS: bool = true
## The ammunition as shipped (a load per type).
const AMMO: bool = true
## The shipped match rules, whose unit types hold the rates.
const MATCH_RULES_PATH: String = "res://src/gameplay/match/data/match_rules.tres"
## The view's width, px.
const VIEW_WIDTH: float = 640.0
## Ticks driven, then ticks standing, for the burn.
const BURN_TICKS: int = 600
## Ticks the fire key is held.
const FIRE_TICKS: int = 30
## A burn compared with the rate, Fuel units.
const BURN_TOLERANCE: float = 0.05
## A bar's value against the Fuel: a ProgressBar keeps its value to its step, 0.01 by default.
const BAR_STEP_TOLERANCE: float = 0.01
## The old rate over the new one (Martin, 2026-10-19: a third was too slow, half it is).
const SLOWDOWN: float = 2.0
## A colour compared with another: the sum of the RGB differences below this is the same colour.
const COLOUR_TOLERANCE: float = 0.2
## Player 1's throttle and fire keys (project.godot p1_throttle, p1_fire).
const KEY_THROTTLE_1: Key = KEY_W
const KEY_FIRE_1: Key = KEY_SPACE
## The Team edges (split_screen.tscn).
const EDGE_PATHS: Array[String] = ["res://src/ui/hud/data/team_orange_edge.tres", "res://src/ui/hud/data/team_teal_edge.tres"]

var _h: Harness
var _kit: Kit


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	await _kit.advance(2)
	_check_data()
	await _check_burn()
	_check_band()
	await _check_follow()
	_check_no_count()
	_h.finish("burn_ticks=%d" % BURN_TICKS)


func _hud(player: int) -> PlayerHud:
	return _h.split.get_node("Views/Player%dView/SubViewport/Player%dHud" % [player + 1, player + 1]) as PlayerHud


func _check_data() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var lines: PackedStringArray = PackedStringArray()
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	for stats: UnitStats in rules.unit_types:
		var old: Array = Harness.LEGACY_036_FUEL_RATES[stats.type_id]
		lines.append("%s %.3f / %.3f (was %.3f / %.3f), tank %.0f" % [stats.type_id, stats.fuel_use, stats.fuel_use_idle, old[0], old[1], stats.fuel_capacity])
		_kit.need(problems, is_equal_approx(stats.fuel_use * SLOWDOWN, old[0]) and is_equal_approx(stats.fuel_use_idle * SLOWDOWN, old[1]),
			"%s burns %.4f / %.4f" % [stats.type_id, stats.fuel_use, stats.fuel_use_idle])
	_kit.verdict("R1_data", problems, "; ".join(lines))


func _check_burn() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var unit: Unit = _h.split.player_1_unit
	var stats: UnitStats = unit.stats
	var start: float = unit.fuel
	_h.set_key(KEY_THROTTLE_1, true)
	await _kit.advance(BURN_TICKS)
	_h.set_key(KEY_THROTTLE_1, false)
	var after_drive: float = unit.fuel
	await _kit.advance(BURN_TICKS)
	var after_stand: float = unit.fuel
	var seconds: float = float(BURN_TICKS) / Engine.physics_ticks_per_second
	var driven: float = start - after_drive
	var stood: float = after_drive - after_stand
	_kit.need(problems, absf(driven - stats.fuel_use * seconds) < BURN_TOLERANCE * 10.0, "drove %.3f, rate gives %.3f" % [driven, stats.fuel_use * seconds])
	_kit.need(problems, stood > 0.0 and stood < driven, "stood %.3f" % stood)
	_kit.verdict("R2_burn", problems, "Motorbike, %d ticks on W: %.3f Fuel (%.3f at the new rate, %.3f at the old); then %d ticks standing: %.3f (rates %.3f and %.3f per s): a full tank of %.0f lasts %.0f s driving, was %.0f s" % [
		BURN_TICKS, driven, stats.fuel_use * seconds, stats.fuel_use * SLOWDOWN * seconds, BURN_TICKS, stood, stats.fuel_use, stats.fuel_use_idle,
		stats.fuel_capacity, stats.fuel_capacity / stats.fuel_use, stats.fuel_capacity / (stats.fuel_use * SLOWDOWN)])


func _fill_colour(bar: ProgressBar) -> Color:
	var style: StyleBoxFlat = bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	return style.bg_color if style != null else Color.TRANSPARENT


func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < COLOUR_TOLERANCE


func _check_band() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var lines: PackedStringArray = PackedStringArray()
	for player: int in 2:
		var hud: PlayerHud = _hud(player)
		var hp: ProgressBar = hud.get_node("%HitPointsBar")
		var order: Array[Control] = [hp, hud.get_node("%FuelIcon"), hud.get_node("%FuelBar"), hud.get_node("%AmmoIcon"), hud.get_node("%AmmoBar")]
		var rects: PackedStringArray = PackedStringArray()
		for index: int in order.size():
			var rect: Rect2 = order[index].get_rect()
			rects.append("%s(%d,%d:%dx%d)" % [order[index].name, rect.position.x, rect.position.y, rect.size.x, rect.size.y])
			_kit.need(problems, order[index].visible, "p%d %s hidden" % [player + 1, order[index].name])
			_kit.need(problems, rect.end.x <= VIEW_WIDTH, "p%d %s past the view" % [player + 1, order[index].name])
			_kit.need(problems, rect.get_center().y > hp.get_rect().position.y and rect.get_center().y < hp.get_rect().end.y, "p%d %s off the row" % [player + 1, order[index].name])
			if index > 0:
				_kit.need(problems, rect.position.x >= order[index - 1].get_rect().end.x, "p%d %s overlaps %s" % [player + 1, order[index].name, order[index - 1].name])
		_kit.need(problems, hud.get_node_or_null("%FuelLabel") == null, "p%d still has a Fuel line" % (player + 1))
		var row_labels: PackedStringArray = PackedStringArray()
		for child: Node in hud.get_children():
			if child is Label and child.visible and (child as Label).get_rect().intersects(hp.get_rect().merge(order[4].get_rect())):
				row_labels.append(child.name)
		# Since Story 051 no text shows in the row: the hit-point line is hidden (the bar alone).
		_kit.need(problems, row_labels.is_empty(), "p%d row labels %s" % [player + 1, row_labels])
		var view: Node = hud.get_parent()
		_kit.need(problems, view.find_children("*", "AmmoCount", true, false).is_empty(), "p%d view still has an Ammo line" % (player + 1))
		var ammo: Color = _fill_colour(order[4])
		var others: Array[Color] = [_fill_colour(hp), _fill_colour(order[2])]
		for path: String in EDGE_PATHS:
			others.append((load(path) as StyleBoxFlat).border_color)
		for other: Color in others:
			_kit.need(problems, not _same(ammo, other), "p%d ammo colour %s like %s" % [player + 1, ammo.to_html(false), other.to_html(false)])
		lines.append("p%d %s; ammo %s, others %s; row labels %s" % [player + 1, " ".join(rects), ammo.to_html(false), ", ".join(others.map(func(c: Color) -> String: return c.to_html(false))), row_labels])
	_kit.verdict("R3_band", problems, " | ".join(lines))


func _check_follow() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var units: Array[Unit] = [_h.split.player_1_unit, _h.split.player_2_unit]
	var weapons: Array[Weapon] = [_h.split.player_1_weapon, _h.split.player_2_weapon]
	var before: Array[float] = []
	for player: int in 2:
		var hud: PlayerHud = _hud(player)
		var fuel_bar: ProgressBar = hud.get_node("%FuelBar")
		var ammo_bar: ProgressBar = hud.get_node("%AmmoBar")
		_kit.need(problems, absf(fuel_bar.value - units[player].fuel) <= BAR_STEP_TOLERANCE and is_equal_approx(fuel_bar.max_value, units[player].fuel_capacity), "p%d Fuel bar %.2f/%.0f, Unit %.2f/%.0f" % [player + 1, fuel_bar.value, fuel_bar.max_value, units[player].fuel, units[player].fuel_capacity])
		_kit.need(problems, int(ammo_bar.value) == weapons[player].shots_left and int(ammo_bar.max_value) == weapons[player].capacity, "p%d ammo bar %d/%d" % [player + 1, ammo_bar.value, ammo_bar.max_value])
		before.append(ammo_bar.value)
	_h.set_key(KEY_FIRE_1, true)
	await _kit.advance(FIRE_TICKS)
	_h.set_key(KEY_FIRE_1, false)
	await _kit.advance(1)
	var after: Array[float] = [(_hud(0).get_node("%AmmoBar") as ProgressBar).value, (_hud(1).get_node("%AmmoBar") as ProgressBar).value]
	_kit.need(problems, after[0] < before[0] and int(after[0]) == weapons[0].shots_left, "p1 ammo bar %.0f -> %.0f, Weapon %d" % [before[0], after[0], weapons[0].shots_left])
	_kit.need(problems, after[1] == before[1], "p2 ammo bar %.0f -> %.0f" % [before[1], after[1]])
	_kit.verdict("R4_follow", problems, "Fuel bars %.2f and %.2f of %.0f; Space for %d ticks: p1 ammo bar %.0f -> %.0f (Weapon %d of %d), p2 %.0f -> %.0f" % [
		units[0].fuel, units[1].fuel, units[0].fuel_capacity, FIRE_TICKS, before[0], after[0], weapons[0].shots_left, weapons[0].capacity, before[1], after[1]])


func _check_no_count() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var weapon: Weapon = _h.split.player_1_weapon
	var hud: PlayerHud = _hud(0)
	var bar: Control = hud.get_node("%AmmoBar")
	var icon: Control = hud.get_node("%AmmoIcon")
	weapon.ammo_changed.emit(0, 0)
	var shown_empty: bool = bar.visible and icon.visible and is_zero_approx((bar as ProgressBar).value)
	weapon.ammo_changed.emit(weapon.shots_left, weapon.capacity)
	var back: bool = bar.visible and icon.visible and int((bar as ProgressBar).value) == weapon.shots_left
	_kit.need(problems, shown_empty, "capacity 0: bar %s, icon %s, value %.0f" % [bar.visible, icon.visible, (bar as ProgressBar).value])
	_kit.need(problems, back, "the load back: bar %s, icon %s, value %.0f" % [bar.visible, icon.visible, (bar as ProgressBar).value])
	_kit.verdict("R5_no_unit", problems, "capacity 0: bar and icon shown, bar empty %s; load %d back: filled %s" % [shown_empty, weapon.capacity, back])
