extends RefCounted
## The "Out of ammo" notice of the Story 022 scenario ammo: AC-5. On the tick a Unit fires its last Shot, and again at every new
## press of the fire key while its gun is empty, that Player's notice line, and only that Player's, shows "Out of ammo" for about
## 1.5 s, replacing whatever the line showed (a refused Mine lay's words, say); a key held down says it once, not once per tick;
## the line hides when the Round ends. The Mines line and the refusals work as before. Real keys; the notice is read every tick
## and inside the Weapon's own report. Tooling only. Implements:
## production/epics/wasteland-fire/story-022-ammo-and-full-start.md AC-5.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit22: GDScript = preload("res://tools/evidence/split_screen/ammo_kit.gd")
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")

const TEXT: String = "Out of ammo"
const NONE_LEFT: String = "No Mines left"
## The notice's time the story gives, in seconds, and the ticks it is allowed to be off by (a frame at each end).
const SHOW_SECONDS: float = 1.5
const SLACK_TICKS: int = 2
## Ticks a key stays held beyond the last Shot, and ticks a sample of the notice is taken for after a press.
const HELD_BEYOND: int = 300
const SAMPLE_TICKS: int = 150
## Ticks into a showing notice a second press is made, to see the time restart.
const SECOND_PRESS_AT: int = 45

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit22
var _q: Quick
## The notice line of each Player as sampled at the end of each tick since the sampler was set: "hidden" or its text.
var _samples: Array = [[], []]


func _init(kit: Kit22) -> void:
	_k = kit
	_q = kit.q()


func run() -> void:
	await _last_shot_and_held_key()
	await _new_presses()
	await _replaces_a_refusal()
	await _round_end()


## The ticks, counted from index `from` of the samples, that a Player's notice read `text` without a break: {start, length}.
func _run_of(player: int, text: String, from: int = 0) -> Dictionary:
	var start: int = -1
	var length: int = 0
	for index: int in range(from, _samples[player].size()):
		if _samples[player][index] == text:
			start = index if start < 0 else start
			length += 1
		elif start >= 0:
			break
	return {"start": start, "length": length}


func _sample() -> void:
	for player: int in Kit22.Kit.PLAYERS:
		_samples[player].append(_k.note(player))


func _sampling(on: bool) -> void:
	_q.kit.on_tick = _sample if on else Callable()


## A new Truck holds its key through the whole load and beyond it: one "Out of ammo" on the tick of the last Shot, shown for about
## 1.5 s and not again while the key stays down; the other Player's line never shows it.
func _last_shot_and_held_key() -> void:
	var problems: PackedStringArray = []
	await _k.arena_put(0, Quick.TRUCK)
	var mark: int = _k.empties[0].size()
	var other_mark: int = _k.empties[1].size()
	_samples = [[], []]
	_sampling(true)
	var fired: Array[Dictionary] = await _k.hold(0, _k.cadence_ticks(Quick.TRUCK) * _k.weapon(0).capacity + HELD_BEYOND)
	_sampling(false)
	_q.kit.need(problems, fired.size() == _k.weapon(0).capacity, "the Truck fired %d Shots" % fired.size())
	_q.kit.need(problems, _k.empties[0].size() == mark + 1, "%d reports of an empty gun came for one load and a key held %d ticks beyond it" % [_k.empties[0].size() - mark, HELD_BEYOND])
	if _k.empties[0].size() > mark and not fired.is_empty():
		var report: Dictionary = _k.empties[0][mark]
		_q.kit.need(problems, int(report["frame"]) == int(fired[-1]["frame"]) and report["note"] == TEXT, "the report came in frame %d (the last Shot in %d) with the notice reading '%s'" % [report["frame"], fired[-1]["frame"], report["note"]])
	var shown: Dictionary = _run_of(0, TEXT)
	var expected: int = roundi(SHOW_SECONDS * Engine.physics_ticks_per_second)
	_q.kit.need(problems, absi(int(shown["length"]) - expected) <= SLACK_TICKS, "the notice showed for %d ticks, expected %d (1.5 s)" % [shown["length"], expected])
	_q.kit.need(problems, _run_of(0, TEXT, int(shown["start"]) + int(shown["length"]))["length"] == 0, "the notice showed again while the key stayed down")
	_q.kit.need(problems, _k.empties[1].size() == other_mark and not _samples[1].has(TEXT), "the other Player's notice showed it")
	measured.append("notice_ticks=%d" % int(shown["length"]))
	_q.kit.verdict("notice_at_the_last_shot", problems, "a Truck holding its fire key from a full load through its 25th Shot and %d ticks beyond it made one report of an empty gun, in the frame of the last Shot, with the notice already reading 'Out of ammo'; it showed for %d ticks (1.5 s is %d) and not again while the key stayed down, and the other Player's notice never read it" % [HELD_BEYOND, int(shown["length"]), expected])


## Every new press while empty says it again, in place of the time left: after the first notice has gone, three presses a few
## seconds apart each show it for 1.5 s; a press made 45 ticks into a showing notice restarts the time.
func _new_presses() -> void:
	var problems: PackedStringArray = []
	var mark: int = _k.empties[0].size()
	_samples = [[], []]
	_sampling(true)
	for _press: int in 3:
		await _k.press(0)
		await _q.kit.advance(SAMPLE_TICKS)
	_sampling(false)
	_q.kit.need(problems, _k.empties[0].size() == mark + 3, "three presses of an empty gun made %d reports" % (_k.empties[0].size() - mark))
	var lengths: PackedInt32Array = []
	var from: int = 0
	for _press: int in 3:
		var shown: Dictionary = _run_of(0, TEXT, from)
		lengths.append(int(shown["length"]))
		from = int(shown["start"]) + int(shown["length"]) + 1 if int(shown["start"]) >= 0 else from
	var expected: int = roundi(SHOW_SECONDS * Engine.physics_ticks_per_second)
	for length: int in lengths:
		_q.kit.need(problems, absi(length - expected) <= SLACK_TICKS, "a press showed the notice for %d ticks, expected %d" % [length, expected])
	var again_mark: int = _k.empties[0].size()
	_samples = [[], []]
	_sampling(true)
	await _k.press(0)
	await _q.kit.advance(SECOND_PRESS_AT)
	await _k.press(0)
	await _q.kit.advance(SAMPLE_TICKS)
	_sampling(false)
	var restarted: Dictionary = _run_of(0, TEXT)
	_q.kit.need(problems, _k.empties[0].size() == again_mark + 2 and int(restarted["length"]) >= SECOND_PRESS_AT + expected - SLACK_TICKS - 2, "two presses %d ticks apart made %d reports and the notice showed %d ticks, expected about %d" % [SECOND_PRESS_AT, _k.empties[0].size() - again_mark, restarted["length"], SECOND_PRESS_AT + expected])
	_q.kit.verdict("notice_at_every_new_press", problems, "with the Truck's gun empty each of three presses of the fire key, seconds apart, made a report and showed 'Out of ammo' for %s ticks (1.5 s is %d); a second press 45 ticks into a showing notice restarted the time (%d ticks in all)" % [lengths, expected, int(restarted["length"])])


## An empty Truck that has laid its last Mine: a lay is refused with "No Mines left", a press of the fire key replaces it with
## "Out of ammo", and the next refused lay replaces that, as a refused Mine lay replaces whatever the line showed.
func _replaces_a_refusal() -> void:
	var problems: PackedStringArray = []
	var layer: MineLayer = _k.mines().layers[0]
	while layer.mines_left > 0:
		await _k.mines().lay(0)
	await _k.mines().lay(0)
	_q.kit.need(problems, _k.note(0) == NONE_LEFT, "a lay with no Mine left shows '%s'" % _k.note(0))
	await _k.press(0)
	_q.kit.need(problems, _k.note(0) == TEXT, "a press of the empty gun over '%s' shows '%s'" % [NONE_LEFT, _k.note(0)])
	await _k.mines().lay(0)
	_q.kit.need(problems, _k.note(0) == NONE_LEFT, "a refused lay over '%s' shows '%s'" % [TEXT, _k.note(0)])
	_q.kit.need(problems, _k.line(0) == "Ammo 0 / 25" and _k.mines().line(0) == "Mines 0 / 5", "the lines read '%s' and '%s'" % [_k.line(0), _k.mines().line(0)])
	await _q.kit.advance(SAMPLE_TICKS)
	_q.kit.need(problems, _k.note(0) == "hidden", "the notice is still '%s' %d ticks later" % [_k.note(0), SAMPLE_TICKS])
	_q.kit.verdict("notice_replaces_the_refusal", problems, "an empty Truck with no Mine left: a refused lay showed 'No Mines left', a press of the fire key replaced it with 'Out of ammo', the next refused lay replaced that with 'No Mines left' again; the lines read 'Ammo 0 / 25' and 'Mines 0 / 5', and the notice was gone %d ticks later" % SAMPLE_TICKS)


## The notice goes when the Round ends: Player 2's empty Carrier presses the fire key and, a few ticks later, carries the Flag
## into its own Base; the line hides at once, and stays hidden through the Round-over screen and after R.
func _round_end() -> void:
	var problems: PackedStringArray = []
	await _k.arena_put(1, Quick.MOTORBIKE)
	await _k.empty_gun(1)
	await _k.k.walls().restore_all(true)
	await _k.k.walls().turrets_down()
	_k.k.flags().wall(0, Walls.GATE).destroy()
	await _q.kit.advance(Walls.SETTLE)
	var taken: bool = await _k.k.flags().take_flag(1, 0, Walls.GATE)
	await _k.k.flags().back_out(1, 0, Walls.GATE)
	await _k.press(1)
	_q.kit.need(problems, taken and _k.note(1) == TEXT, "the notice reads '%s' before the delivery (taken %s)" % [_k.note(1), taken])
	var swap: Object = _k.swap()
	swap.flags.teleport(1, swap.inside_point(1), swap.into_base(1))
	await _q.kit.advance(Swap.ZONE_WAIT_TICKS + Kit22.SETTLE)
	_q.kit.need(problems, _q.controller.is_round_over() and _k.note(1) == "hidden", "with the Round over the notice reads '%s'" % _k.note(1))
	await _q.kit.advance(SAMPLE_TICKS)
	_q.kit.need(problems, _k.note(1) == "hidden", "under the Round-over screen the notice reads '%s'" % _k.note(1))
	await _k.k.flags().restart()
	_q.kit.need(problems, _k.note(0) == "hidden" and _k.note(1) == "hidden", "after R the notices read '%s' and '%s'" % [_k.note(0), _k.note(1)])
	_q.kit.verdict("notice_hidden_when_the_round_ends", problems, "the empty Carrier's 'Out of ammo' was showing when it carried the Flag into its Base a few ticks after the press: the Round ended and the line was hidden in that tick, stayed so under the Round-over screen, and after R both notices were hidden")
