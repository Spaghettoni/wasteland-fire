class_name MatchController
extends Node
## Owns the state of one Round: whose Unit is alive, who is choosing the next Unit type and who
## waits to respawn and when, who carries which Water Canister, and whether the Round still runs
## or has been won. It benches each Player's Unit on that Player's Base at the start of the Round
## and at a restart while the Player chooses a type, puts the chosen type on the Base once the
## choice is made and the delay has passed, seats each Base's canister, applies the canister rules
## once per physics tick, and freezes the game when a delivery wins the Round, until restart().
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-1, AC-3,
## AC-4 and AC-7; production/epics/wasteland-fire/story-004-water-canister-and-win.md AC-2, AC-3,
## AC-4, AC-5 and AC-6; production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-6
## (at every spawn, the start of the Round, after a destruction and after a restart, the Player
## chooses the Unit type before the Unit appears, with every type available; at the start it
## appears as soon as it is chosen, after a destruction once it is chosen and the delay has passed,
## whichever is later, and the other Player plays on meanwhile); design/game-brief.md MVP features
## 3 (Bases, destruction and respawn), 4 (Water Canister and the win) and 5 (the four Units);
## design/rules.md "Tokens and the Garage", "Destruction and respawn" and "Resources". Vocabulary:
## CONTEXT.md (Player, Unit, Base, Garage, Round, Water Canister, Carrier). The node and its rules
## resource keep the names the story gave them (MatchController, MatchRules; Story 003 AC-7); in
## prose the thing they serve is the Round, as CONTEXT.md has it. The objective keeps its Story
## 004 name in code (canister) until Story 008 renames it.
##
## Signals up, calls down. A Unit emits `destroyed` and nothing else: it never calls this
## controller, the other Unit, a canister or a singleton. The controller listens, then calls down:
## it asks the Unit to leave_play() and spawn(), the camera to snap_to_target() and a canister to
## carry_by(), drop_at() or seat_at() (through CanisterRules, which keeps who carries what).
## Everything it touches is handed to it once, by begin() (dependency injection: no node path, no
## autoload, no static state), so a test can build one from stand-in Units, Bases and cameras
## without the split-screen scene. Player index 0 is Player 1. The canister of Player N is
## canister N: its index is its owner's Player index and the index of its Base in begin()'s arrays,
## and that index is what the canister signals carry. A type index is an index into
## rules.unit_types, the order of the data (unit_types()).
##
## It knows nothing about the screen. A HUD node listens to unit_destroyed, unit_spawned and the
## canister signals and asks seconds_until_respawn() and canister_status(); the choice panel
## listens to round_started, unit_destroyed, unit_chosen, unit_spawned and round_over and asks
## is_choosing(), chosen_type_index() and unit_types(); the Round-over screen listens to round_over
## and round_started; this script references no UI class, draws nothing and holds no text, so the
## display can change, or go, without touching the Round. It reads no input either: what a key
## does to a Unit is PlayerMatchInput's business, and that acts on the Unit, so a Self-destruct
## reaches its respawn by the same path as a lost fight; the choice keys are PlayerChoiceInput's,
## which calls choose(); the restart key is RoundRestartInput's, which calls restart().
##
## State per Player. The per-Player state (State: OUT_OF_ROUND, ALIVE, WAITING, where WAITING
## covers both the Player choosing and the Player waiting, chosen, for the delay or a free spot)
## with its complete transition table, the choice, the respawn wait and its pause bookkeeping, the
## bench, the one spawn path with its search for a free spot and the two settle rules live in
## GarageQueue (src/gameplay/match/garage_queue.gd), one per controller, and its class doc keeps
## the paragraphs on each. The controller calls it from begin(), restart(), choose(), its physics
## tick, its `destroyed` handler and its pause notifications, and announces what it returns:
## unit_chosen for a choice it accepted, unit_spawned for every Player it put in play,
## canister_dropped and unit_destroyed for every destruction it counted. Moved there in Story 005
## (docs/tech-debt-register.md TD-008) with no change of behaviour, then given the choice.
##
## Round state, one for the whole Round (RoundState). The table is complete:
##   RUNNING -> OVER     a Player's Unit carrying the other Player's canister was reported inside
##                       its own Base zone: that Player wins; the tree is paused at the end of that
##                       tick, then emit round_over(winner)
##   OVER    -> RUNNING  restart(): every canister seated, every Unit benched on its Base with its
##                       Player choosing, the tree unpaused, emit round_started
##   RUNNING -> RUNNING  everything else: a destruction, a choice, a spawn, a pick-up, a drop, an
##                       owner's re-seat, a Unit in its own Base empty-handed, both Players choosing
##                       or waiting at once
## begin() starts RUNNING and emits round_started after the benches and the seating, with both
## Players choosing and no Unit in play; restart() while RUNNING is refused with a warning. The win
## is decided by delivery and nothing else (AC-5).

## A Player's Unit left play, and that Player now chooses the next type and waits out the respawn
## delay, whichever ends later. The wait is already stamped and the previous choice cleared when
## this fires, so seconds_until_respawn(player_index) is the full delay in a handler,
## is_alive(player_index) is false and is_choosing(player_index) is true. Player 1 is index 0. When
## the Unit carried a canister, canister_dropped went out just before this.
signal unit_destroyed(player_index: int)

## A Player chose the type at type_index (into unit_types()): choose() accepted it. The choice
## stands until the Unit appears, so chosen_type_index(player_index) is this value in a handler and
## is_choosing(player_index) is false; unit_spawned follows once the delay has passed, the bench has
## settled and a spot is free, on this tick at the earliest.
signal unit_chosen(player_index: int, type_index: int)

## A Player's Unit was put on that Player's Base as the chosen type, on its spawn point or, when
## that was taken, on a spare one: at every spawn, that is after every choice, at the start of the
## Round, after a destruction and after a restart alike. The Unit is alive at the full hit points
## of its type and its camera has snapped behind it; is_alive(player_index) is already true and
## chosen_type_index(player_index) is -1 again when this fires.
signal unit_spawned(player_index: int)

## The Round began, or began again: both Units are benched on their Bases, hidden, with both
## Players choosing a type, and every canister stands on its Base's seat. Emitted by begin() after
## its benches and by restart() after the unpause, so is_round_over() is false and is_choosing() is
## true for every Player in a handler. A HUD refreshes its canister status on it; the Round-over
## screen hides; the choice panel shows.
signal round_started

## A delivery won the Round (AC-5): the Unit of winner_index carried the other Player's canister
## into its own Base zone. The tree is already paused when this fires and stays so until restart();
## is_round_over() is true and winner_index() is this value in a handler.
signal round_over(winner_index: int)

## The Unit of carrier_index picked up the canister of canister_index (its owner's Player index) by
## touching it (AC-2). The canister already rides on the Unit when this fires.
signal canister_picked_up(carrier_index: int, canister_index: int)

## The canister of canister_index dropped at its Carrier's wreck: the Carrier was destroyed (AC-3).
## It lies there until a Unit picks it up or the Round restarts; nothing moves it home on its own.
signal canister_dropped(canister_index: int)

## The canister of canister_index stands on its Base's seat again: its owner carried it into the
## own Base (AC-4). Not emitted by begin() or restart(), which announce their seating with
## round_started.
signal canister_seated(canister_index: int)

## Where one Player is in the Round. The transitions are in GarageQueue's class doc.
enum State {
	## Not in the Round: before begin(), or the Unit could not be put in play, or a node of the
	## Player was freed.
	OUT_OF_ROUND,
	## The Player's Unit is in play.
	ALIVE,
	## The Player's Unit is out of play: benched at the start of the Round or a restart, or
	## destroyed. The Player is choosing the next type (is_choosing()), or has chosen and waits for
	## the delay, the bench settle and a free spot on its Base (chosen_type_index()).
	WAITING,
}

## Whether the Round is still played or has been won; one for the whole Round. The transitions
## are in the class doc.
enum RoundState {
	## Before begin(), and from begin() or restart() until a delivery wins.
	RUNNING,
	## A delivery won: the tree is paused, winner_index() names the winner, and only restart()
	## leaves this state.
	OVER,
}

## What a Player's HUD shows about the canisters (Story 004 AC-7), the answer of canister_status().
enum CanisterStatus {
	## The Player's own canister stands on its Base's seat, and the Player carries nothing foreign.
	OWN_AT_HOME,
	## The Player's own canister is away: stolen, lying dropped, or on its way home on its owner's
	## Unit; and the Player carries nothing foreign.
	OWN_AWAY,
	## The Player's Unit carries the other Player's canister.
	CARRYING_ENEMY,
}

## The answer of winner_index() while nobody has won.
const NO_WINNER: int = -1

## The answer of chosen_type_index() while the Player has not chosen.
const NO_CHOICE: int = GarageQueue.NO_CHOICE

## Physics ticks after a spawn during which the Player's pick-ups and deliveries are skipped, and
## after a bench before which no spawn is made; GarageQueue holds the value and the reasons.
const SPAWN_SETTLE_TICKS: int = GarageQueue.SPAWN_SETTLE_TICKS

## The tuning values (a MatchRules .tres, for example match_rules.tres): rules.respawn_delay_seconds
## is the wait between a destruction and the respawn (Story 003 AC-3), rules.unit_types the types a
## Player chooses from, in the order of the choice (Story 005 AC-6). Required: begin() refuses to
## start the Round without it, while the delay is not above zero, while unit_types is empty or
## while one of its entries is unusable (UnitStats.first_problem()). The resource is shared, so
## never write to it at runtime.
@export var rules: MatchRules

var _units: Array[Unit] = []
var _bases: Array[Base] = []
var _cameras: Array[ChaseCamera] = []
## The per-Player state, the choice, the waits and the spawn path (class doc). Enlisted by
## begin(); before that it holds no Player, and only its pause bookkeeping runs.
var _garage: GarageQueue = GarageQueue.new()
## Who carries which canister, and the calls down to the canisters. Built by begin().
var _canisters: CanisterRules = null
var _round_state: RoundState = RoundState.RUNNING
var _winner: int = NO_WINNER
var _has_begun: bool = false


## Forwards the pause notifications to the garage queue, which notes the frame a pause began and,
## when it ends, pushes every wait on by the ticks it lasted (its class doc, the paragraph on
## pause). An unpause with no pause before it (the node entered a paused tree) changes nothing.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED:
			_garage.note_paused()
		NOTIFICATION_UNPAUSED:
			_garage.note_unpaused()


## The garage queue's tick first: every WAITING Player who has chosen, whose due frame has come,
## whose bench has settled and whose Base has a free spot for the chosen type (the spawn point, or
## else a spare one) is spawned as that type, and announced here with one unit_spawned each; then,
## while the Round runs, the canister rules in their order (pick-ups, then deliveries) and, when a
## delivery won, the pause of the tree and the winner. The wait and the settle rules are counted in
## physics ticks, not in delta: see GarageQueue.
func _physics_process(_delta: float) -> void:
	for player_index: int in _garage.tick():
		unit_spawned.emit(player_index)
	if _round_state != RoundState.RUNNING or _canisters == null:
		return
	var may_act: Array[bool] = _garage.may_act()
	_apply_pick_ups(may_act)
	_apply_deliveries(may_act)
	if _round_state == RoundState.OVER:
		get_tree().paused = true
		round_over.emit(_winner)


## Starts the Round: puts every Player's Unit on that Player's Base and benches it there, out of
## play, with the Player choosing a type (Story 005 AC-6; the Unit appears by the one spawn path
## once chosen: Story 003 AC-1), seats every canister on its Base's seat (Story 004 AC-1), emits
## round_started, and from then on listens for the Units' destroyed signals; it spawns nobody and
## emits no unit_spawned. Call it once, from the composition root (SplitScreen), with the Units,
## Bases and cameras already in the tree. The three arrays hold one entry per Player, in the same
## order, Player 1 first: the Unit that Player drives, the Base it starts and respawns at, which
## also holds that Player's canister and its seat, and the camera that chases that Unit. When
## anything is wrong (rules missing, a delay not above zero, no unit_types or one that is unusable,
## no Players, arrays of different sizes, an entry that is null or not in the tree, a Base without
## a spawn point, a canister or a canister seat, or with a spawn point off its pad) it pushes one
## error naming the problem and does nothing: no bench, no connection, no signal. A second call
## after a successful one is refused the same way. A Unit that cannot be put in play (it refused to
## drive in _ready()) is benched like any other; the spawn after its Player's first choice pushes an
## error and leaves only that Player out of the Round.
func begin(units: Array[Unit], bases: Array[Base], cameras: Array[ChaseCamera]) -> void:
	if _has_begun:
		push_error("MatchController '%s': begin() was called twice. A Round begins once." % name)
		return
	var problem: String = _first_problem(units, bases, cameras)
	if not problem.is_empty():
		push_error("MatchController '%s': %s, so the Round does not begin." % [name, problem])
		return
	_has_begun = true
	_units.assign(units)
	_bases.assign(bases)
	_cameras.assign(cameras)
	_garage.enlist(self, _units, _bases, _cameras)
	_canisters = CanisterRules.new(_units, _bases)
	_round_state = RoundState.RUNNING
	_winner = NO_WINNER
	for player_index: int in _units.size():
		_units[player_index].destroyed.connect(_on_unit_destroyed.bind(player_index))
	for player_index: int in _units.size():
		_garage.bench(player_index)
	_canisters.seat_all()
	round_started.emit()


## Starts the Round again after a win (Story 004 AC-6): every canister is seated on its Base's
## seat (a carried one goes home), every Player's Unit is put on its Base's spawn point and benched
## there with the Player choosing a type again (a pending wait and a standing choice are
## cancelled; the Unit appears, at the full hit points of the chosen type, once chosen: Story 005
## AC-6), the Round is RUNNING, the tree is unpaused and round_started goes out, in that order; no
## unit_spawned goes out here. Only while the Round is over: a call while it runs pushes a warning
## and does nothing.
func restart() -> void:
	if _round_state != RoundState.OVER:
		push_warning("MatchController '%s': restart() was called while the Round is running, so nothing happens. It restarts a Round that is over." % name)
		return
	_canisters.seat_all()
	for player_index: int in _units.size():
		_garage.bench(player_index)
	_round_state = RoundState.RUNNING
	_winner = NO_WINNER
	get_tree().paused = false
	round_started.emit()


## The Player chooses the type at type_index (into unit_types()) for its next Unit (Story 005
## AC-6). True when accepted: the Round has begun and runs, the Player is WAITING and has not
## chosen since its last spawn, bench or destruction, and type_index is an index of
## rules.unit_types; then unit_chosen goes out and the Unit appears by the one spawn path once the
## delay has passed, the bench has settled and a spot is free (at once at the start of the Round
## and after a restart). Otherwise false and nothing changes: a Player in play, a second choice, a
## Round that is over or has not begun, an index outside the data.
func choose(player_index: int, type_index: int) -> bool:
	if not _has_begun or _round_state != RoundState.RUNNING:
		return false
	if type_index < 0 or type_index >= rules.unit_types.size():
		return false
	if not _garage.choose(player_index, type_index):
		return false
	unit_chosen.emit(player_index, type_index)
	return true


## True while the Player is out of play and has not chosen the next type: the time the choice
## panel is shown and the choice keys are read. False while the Player's Unit is in play, while a
## choice stands, before begin(), and for a player_index that is not in the Round.
func is_choosing(player_index: int) -> bool:
	return _garage.is_choosing(player_index)


## The type index (into unit_types()) the Player chose and that stands until its Unit appears, or
## NO_CHOICE (-1): while the Player is choosing, in play, before begin(), and for a player_index
## that is not in the Round.
func chosen_type_index(player_index: int) -> int:
	return _garage.chosen_type_index(player_index)


## The types a Player chooses from, in the order of the choice: rules.unit_types, the very
## resources, not copies, so a reader may show their display_name and must not write to them. An
## empty array while rules is not assigned.
func unit_types() -> Array[UnitStats]:
	if rules == null:
		var none: Array[UnitStats] = []
		return none
	return rules.unit_types


## True while the Player's Unit is in play. False while it chooses or waits to respawn, before
## begin(), and for a player_index that is not in the Round.
func is_alive(player_index: int) -> bool:
	return _garage.is_alive(player_index)


## True from the tick a delivery won the Round until restart(). False before begin().
func is_round_over() -> bool:
	return _round_state == RoundState.OVER


## The Player index that won the Round (0 is Player 1), or NO_WINNER (-1) while the Round runs
## and before begin().
func winner_index() -> int:
	return _winner


## What the Player's HUD shows about the canisters, a CanisterStatus value: CARRYING_ENEMY while
## that Player's Unit carries a canister that is not its own; else OWN_AT_HOME while the Player's
## own canister stands on its seat; else OWN_AWAY (stolen, lying dropped, or on its way home on its
## owner's Unit). OWN_AT_HOME before begin() and for a player_index not in the Round: what a Round
## shows at its start. Ask it when canister_picked_up, canister_dropped, canister_seated or
## round_started arrives: every change of the answer is announced by one of them.
func canister_status(player_index: int) -> int:
	if not _is_player(player_index) or _canisters == null:
		return CanisterStatus.OWN_AT_HOME
	if _canisters.is_carrying_enemy(player_index):
		return CanisterStatus.CARRYING_ENEMY
	if _canisters.is_own_at_home(player_index):
		return CanisterStatus.OWN_AT_HOME
	return CanisterStatus.OWN_AWAY


## Seconds until the Player's Unit may respawn: the full delay on the tick of the destruction, then
## counting down to zero, whether or not the Player has chosen; zero while only the choice is
## missing (the start of the Round, a restart, a delay that has run out). 0.0 while the Player is
## alive, before begin(), and for a player_index that is not in the Round. It is the stamped frame
## minus the current physics frame, over the tick rate, so it is exact: a countdown that shows
## ceili() of it changes digit on whole seconds (3 for the first second of a 3 second delay, then
## 2, then 1). Safe to poll from _process: the frame number read there is the last completed
## tick's. While the respawn is due and chosen but every spot of the Base is taken it reads one
## tick, so a countdown never shows a Player who is still waiting as done; and while the tree is
## paused it reads the value of the moment the pause began.
func seconds_until_respawn(player_index: int) -> float:
	return _garage.seconds_until_respawn(player_index)


## Rule (1) of the tick: each canister that is not carried goes to the first Player who qualifies
## (CanisterRules.taker_of(); class doc), and the pick-up is announced.
func _apply_pick_ups(may_act: Array[bool]) -> void:
	for canister_index: int in _bases.size():
		var taker: int = _canisters.taker_of(canister_index, may_act)
		if taker != CanisterRules.NONE:
			_canisters.pick_up(taker, canister_index)
			canister_picked_up.emit(taker, canister_index)


## Rule (2) of the tick: a Player who may act, carries a canister and is reported inside its own
## Base zone either wins (the other Player's canister: the Round is OVER, announced by
## _physics_process after the pause) or brings its own canister home (re-seated, announced here).
## Two deliveries on one tick: the lower Player index wins, as for pick-ups; the loop stops at the
## first win, so the other Player's delivery is not applied.
func _apply_deliveries(may_act: Array[bool]) -> void:
	for player_index: int in _units.size():
		var canister_index: int = _canisters.carried_canister(player_index)
		if canister_index == CanisterRules.NONE or not may_act[player_index]:
			continue
		if not _canisters.is_in_own_zone(player_index):
			continue
		if canister_index == player_index:
			_canisters.reseat(player_index)
			canister_seated.emit(canister_index)
		else:
			_round_state = RoundState.OVER
			_winner = player_index
			return


## True for an index of a Player in this Round.
func _is_player(player_index: int) -> bool:
	return player_index >= 0 and player_index < _units.size()


## What is wrong with the arguments of begin() and the rules, as a sentence, or an empty string
## when there is nothing wrong.
func _first_problem(units: Array[Unit], bases: Array[Base], cameras: Array[ChaseCamera]) -> String:
	if rules == null:
		return "rules is not assigned"
	if not (rules.respawn_delay_seconds > 0.0):
		return "rules.respawn_delay_seconds is %s and must be above zero" % rules.respawn_delay_seconds
	var types_problem: String = _first_type_problem()
	if not types_problem.is_empty():
		return types_problem
	if units.is_empty():
		return "no Players were given"
	if bases.size() != units.size() or cameras.size() != units.size():
		return "it needs one Unit, one Base and one camera per Player but got %d Units, %d Bases and %d cameras" % [units.size(), bases.size(), cameras.size()]
	for player_index: int in units.size():
		var problem: String = _first_player_problem(units, bases, cameras, player_index)
		if not problem.is_empty():
			return problem
	return ""


## What is wrong with rules.unit_types, the types a Player chooses from (Story 005): empty, or an
## entry that is null or unusable (UnitStats.first_problem()), named by its index; or an empty
## string.
func _first_type_problem() -> String:
	if rules.unit_types.is_empty():
		return "rules.unit_types is empty, and a Player must have a type to choose"
	for type_index: int in rules.unit_types.size():
		var type_stats: UnitStats = rules.unit_types[type_index]
		if type_stats == null:
			return "rules.unit_types[%d] is null" % type_index
		var type_problem: String = type_stats.first_problem()
		if not type_problem.is_empty():
			return "rules.unit_types[%d] ('%s') is unusable: %s" % [type_index, type_stats.display_name, type_problem]
	return ""


## What is wrong with the entries of one Player in the arguments of begin(), or an empty string.
func _first_player_problem(units: Array[Unit], bases: Array[Base], cameras: Array[ChaseCamera], player_index: int) -> String:
	if not is_instance_valid(units[player_index]):
		return "units[%d] is null" % player_index
	if not units[player_index].is_inside_tree():
		return "units[%d] is not in the tree" % player_index
	if not is_instance_valid(bases[player_index]):
		return "bases[%d] is null" % player_index
	var spawn_point: Marker3D = bases[player_index].spawn_point
	if not is_instance_valid(spawn_point):
		return "bases[%d].spawn_point is not assigned" % player_index
	if not spawn_point.is_inside_tree():
		return "bases[%d].spawn_point is not in the tree" % player_index
	var spawn_problem: String = bases[player_index].first_spawn_problem()
	if not spawn_problem.is_empty():
		return "bases[%d]: %s" % [player_index, spawn_problem]
	var canister_problem: String = _first_canister_problem(bases[player_index], player_index)
	if not canister_problem.is_empty():
		return canister_problem
	if not is_instance_valid(cameras[player_index]):
		return "cameras[%d] is null" % player_index
	return ""


## What is wrong with a Base's canister and canister seat (Story 004: begin() reads both), or an
## empty string.
func _first_canister_problem(base: Base, player_index: int) -> String:
	if not is_instance_valid(base.canister):
		return "bases[%d].canister is not assigned" % player_index
	if not base.canister.is_inside_tree():
		return "bases[%d].canister is not in the tree" % player_index
	if not is_instance_valid(base.canister_seat):
		return "bases[%d].canister_seat is not assigned" % player_index
	if not base.canister_seat.is_inside_tree():
		return "bases[%d].canister_seat is not in the tree" % player_index
	return ""


## A Unit left play: the garage queue stamps the frame at which its Player may respawn and clears
## the Player's choice (the next type is chosen anew, Story 005 AC-6), or refuses with a warning
## when that Player was not ALIVE, and then nothing happens; the canister it carried drops at the
## wreck (rule (3); AC-3), then the listeners are told. The state and the stamp are set before the
## signals go out, so a handler already sees the Player waiting with the full delay and choosing,
## and canister_dropped goes out before unit_destroyed.
func _on_unit_destroyed(player_index: int) -> void:
	if not _garage.note_destroyed(player_index):
		return
	var dropped: int = _canisters.drop(player_index)
	if dropped != CanisterRules.NONE:
		canister_dropped.emit(dropped)
	unit_destroyed.emit(player_index)
