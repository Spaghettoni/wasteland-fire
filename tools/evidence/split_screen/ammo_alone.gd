extends RefCounted
## Scenario ammo_alone of the split screen evidence harness (split_screen_harness.gd): the opt-in AMMO declared by itself, Story 022
## AC-7. The runner keeps the pieces of the ammunition for a scenario that declares AMMO, and nothing of the Turrets or the Mines: each
## view keeps its Ammo line and its notice line (the notice keep rule reads AMMO as well as TURRETS and MINES), the Mine lines and the
## Turrets stay out, and a Motorbike that fires its whole load has its last Shot say "Out of ammo" on the notice line and its line read
## "Ammo 0 / 100". The scenario ammo declares TURRETS and MINES too, which keep the notice line by themselves, so this is the one that
## tells the keep rule's AMMO clause. Headless, real keys. Tooling only. Implements:
## production/epics/wasteland-fire/story-022-ammo-and-full-start.md AC-5 and AC-7.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=ammo_alone

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## This scenario makes the choice itself, with its own keys, and declares the ammunition and nothing else.
const OWN_CHOICE: bool = true
const AMMO: bool = true
## Simulated seconds: the Motorbike's load takes 20.
const WATCHDOG_SECONDS: float = 120.0
## The Motorbike's load and its cadence in ticks, the test inputs of the check, and the ticks the key is held (the load and some more).
const LOAD: int = 100
const CADENCE: int = 12
const HELD_TICKS: int = 1300

var _q: Quick


func run(harness: Node) -> void:
	_q = Quick.new(harness)
	_pieces()
	await _q.tokens.spawn(0, Quick.MOTORBIKE)
	await _q.kit.advance(Quick.Kit.START_TICKS)
	await _last_shot()
	_q.close()
	harness.finish("alone=1")


## What the views hold: an Ammo line and a notice line each, the notice wired to the Player's Weapon, no Mines line, and no Turrets.
func _pieces() -> void:
	var problems: PackedStringArray = []
	for player: int in Quick.Kit.PLAYERS:
		var view: Viewport = _q.units.cameras[player].get_viewport()
		var lines: Array[Node] = view.find_children("*", "AmmoCount", false, false)
		var notices: Array[Node] = view.find_children("*", "PlayerNotice", false, false)
		var mines: Array[Node] = view.find_children("*", "MineCount", false, false)
		_q.kit.need(problems, lines.size() == 1 and notices.size() == 1 and mines.is_empty(), "view %d holds %d Ammo lines, %d notices and %d Mines lines" % [player + 1, lines.size(), notices.size(), mines.size()])
		if notices.size() == 1:
			_q.kit.need(problems, (notices[0] as PlayerNotice).weapon == _q.units.weapons[player] and (notices[0] as PlayerNotice).out_of_ammo_text == "Out of ammo", "the notice of view %d is not wired to its Weapon" % (player + 1))
	_q.kit.need(problems, _q.harness.split.find_children("*", "Turret", true, false).is_empty(), "the Turrets stand")
	_q.kit.verdict("alone_keeps_the_lines", problems, "a scenario that declares AMMO alone keeps both views' Ammo line and notice line (each notice on its own Player's Weapon) and has no Mines line and no Turret")


## The Motorbike holds its fire key through its whole load: one 'out of ammo' on the last Shot, the notice reading it, the line at 0 of 100.
func _last_shot() -> void:
	var problems: PackedStringArray = []
	var gun: Weapon = _q.units.weapons[0]
	var notice: PlayerNotice = _q.units.cameras[0].get_viewport().find_children("*", "PlayerNotice", false, false)[0] as PlayerNotice
	var line: AmmoCount = _q.units.cameras[0].get_viewport().find_children("*", "AmmoCount", false, false)[0] as AmmoCount
	var said: Array[String] = []
	gun.out_of_ammo.connect(func() -> void: said.append(notice.text if notice.visible else "hidden"))
	await _q.units.hold_fire(0, HELD_TICKS)
	_q.kit.need(problems, gun.shots_left == 0 and gun.capacity == LOAD and line.visible and line.text == "Ammo 0 / %d" % LOAD, "the Weapon holds %d of %d and the line reads '%s' (shown %s)" % [gun.shots_left, gun.capacity, line.text, line.visible])
	_q.kit.need(problems, said == ["Out of ammo"], "the notice read %s when the gun said it was out of ammo" % [said])
	_q.kit.verdict("alone_says_out_of_ammo", problems, "the Motorbike's %d Shots %d ticks apart ended with one report of an empty gun, the notice line reading 'Out of ammo' inside it, and 'Ammo 0 / %d' on the Ammo line" % [LOAD, CADENCE, LOAD])
