class_name MatchController
extends Node
## Owns the state of one Round: whose Unit is alive, who is waiting to respawn and when, who
## carries which Water Canister, and whether the Round still runs or has been won. It puts each
## Player's Unit on that Player's Base at the start of the Round and again at every respawn, seats
## each Base's canister, applies the canister rules once per physics tick, and freezes the game
## when a delivery wins the Round, until restart().
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-1, AC-3,
## AC-4 and AC-7; production/epics/wasteland-fire/story-004-water-canister-and-win.md AC-2, AC-3,
## AC-4, AC-5 and AC-6; design/game-brief.md MVP features 3 (Bases, destruction and respawn) and 4
## (Water Canister and the win); design/rules.md "Destruction, respawn and unit swap", "Resources"
## and "Handling the Water Canister". Vocabulary: CONTEXT.md (Player, Unit, Base, Round, Water
## Canister, Carrier). The node and its rules resource keep the names the story gave them
## (MatchController, MatchRules; Story 003 AC-7); in prose the thing they serve is the Round, as
## CONTEXT.md has it.
##
## Signals up, calls down. A Unit emits `destroyed` and nothing else: it never calls this
## controller, the other Unit, a canister or a singleton. The controller listens, then calls down:
## it asks the Unit to spawn(), the camera to snap_to_target() and a canister to carry_by(),
## drop_at() or seat_at() (through CanisterRules, which keeps who carries what). Everything it
## touches is handed to it once, by begin() (dependency injection: no node path, no autoload, no
## static state), so a test can build one from stand-in Units, Bases and cameras without the
## split-screen scene. Player index 0 is Player 1. The canister of Player N is canister N: its
## index is its owner's Player index and the index of its Base in begin()'s arrays, and that index
## is what the canister signals carry.
##
## It knows nothing about the screen. A HUD node listens to unit_destroyed, unit_spawned and the
## canister signals and asks seconds_until_respawn() and canister_status(); the Round-over screen
## listens to round_over and round_started; this script references no UI class, draws nothing and
## holds no text, so the display can change, or go, without touching the Round. It reads no input
## either: what a key does to a Unit is PlayerMatchInput's business, and that acts on the Unit, so
## a Self-destruct reaches its respawn by the same path as a lost fight; the restart key is
## RoundRestartInput's, which calls restart().
##
## State per Player. Each Player's state is independent of the other's: both can wait at once,
## each with its own due frame. The table is complete; a pair it does not list cannot happen.
##   OUT_OF_ROUND -> ALIVE         begin() or restart() put the Unit in play: emit unit_spawned
##   OUT_OF_ROUND -> OUT_OF_ROUND  begin() or restart() could not (the Unit refused to drive):
##                                 push_error
##   ALIVE        -> WAITING       the Unit emitted destroyed: stamp the frame, drop the canister
##                                 it carried (if any) at the wreck, emit unit_destroyed
##   ALIVE        -> ALIVE         restart(): the Unit is put back on its Base's spawn point at
##                                 full hit points: emit unit_spawned
##   WAITING      -> ALIVE         the physics frame reached the stamp and the spawn point, or a
##                                 spare spawn point, is free: spawn there, emit unit_spawned; or
##                                 restart(): the wait is cancelled and the Unit put on its spawn
##                                 point, emit unit_spawned
##   WAITING      -> WAITING       the frame reached the stamp but another Unit stands on the spawn
##                                 point and on every spare one: look again next tick (the
##                                 paragraph on a respawn onto another Unit)
##   WAITING      -> OUT_OF_ROUND  a node of the Player (Unit, Base, spawn point, camera) was
##                                 freed: one push_error
## A `destroyed` from a Player who is not ALIVE is ignored with a warning: a Unit that is not alive
## cannot be destroyed, so only a Unit spawned behind this controller's back could send one.
##
## Round state, one for the whole Round (RoundState). The table is complete:
##   RUNNING -> OVER     a Player's Unit carrying the other Player's canister was reported inside
##                       its own Base zone: that Player wins; the tree is paused at the end of that
##                       tick, then emit round_over(winner)
##   OVER    -> RUNNING  restart(): every canister seated, every Unit spawned on its Base, the
##                       tree unpaused, emit round_started
##   RUNNING -> RUNNING  everything else: a destruction, a respawn, a pick-up, a drop, an owner's
##                       re-seat, a Unit in its own Base empty-handed, both Units waiting at once
## begin() starts RUNNING and emits round_started after the spawns and the seating; restart() while
## RUNNING is refused with a warning. The win is decided by delivery and nothing else (AC-5).
##
## The spawn settle rule. On the tick after Unit.spawn() the physics server still reports the Unit
## overlapping whatever stood at its OLD position (measured on Godot 4.7.2 with Jolt: a respawned
## Carrier was reported touching its own dropped canister 10 m away, for one tick; the Story 004
## evidence doc keeps the probe), so without a guard a Player would re-pick its dropped canister
## from its Base, or deliver an enemy canister lying at its wreck. _spawn() therefore stamps the
## physics frame per Player and the rules skip that Player until SPAWN_SETTLE_TICKS frames have
## passed: at the start of the Round, at every respawn and at a restart. The count is an engine
## latency with a margin, not a tuning value, so it is a constant here and not a MatchRules field.
##
## The respawn wait is an absolute physics-frame stamp, not a Timer and not a countdown. When a
## Unit is destroyed the controller stores Engine.get_physics_frames() plus the delay in ticks
## (rules.respawn_delay_seconds times Engine.physics_ticks_per_second, rounded, and at least one),
## and _physics_process respawns the Player once the frame number reaches it. A Timer fires a tick
## early or late depending on where it sits in the tree relative to the code that starts it, and a
## float countdown carries rounding error (repeated subtraction of 1/60 does not land on exactly
## zero), so neither gives the same tick count from every call context; the stamp does, because the
## frame number is constant inside a tick. So the wait is exactly round(delay * tick rate) ticks
## from the destroy tick to the spawn tick, for the data's delay and for any other, with
## seconds_until_respawn() falling every tick from the delay to zero (the Story 003 evidence doc
## keeps the measurements). The count is in physics ticks, so the render frame rate does not move
## it; Engine.time_scale is not tested, and nothing in the game sets it.
##
## The wait honours pause. Engine.get_physics_frames() keeps counting while the tree is paused,
## although this node stops processing, so a stamp would run out under the pause.
## NOTIFICATION_PAUSED notes the frame, NOTIFICATION_UNPAUSED pushes every stamp on by the ticks
## that passed, and seconds_until_respawn() reads the noted frame while paused, so a pause menu sees
## a frozen value. A node that does not process for another reason (its process_mode) gets the same
## two notifications, so the time it did not run does not count either: a pause longer than the
## whole delay ends with as many ticks of the wait still to run as were left when it began. A wait
## that was already due and blocked when the pause began is not pushed on, because its stamp is
## reached and stays so: the first tick after the unpause looks for a free spot again. A settle
## stamp taken before the pause began is pushed on the same way, so a pause never counts as settled
## ticks: the physics server does not step while the tree is paused (the Story 004 evidence doc
## keeps the run), so the ghost overlap the settle rule guards against would survive the pause
## unstepped. The pause of a won Round ends in restart() after every wait was cancelled by a spawn
## and every settle stamp was taken again, later than the pause began, so it pushes nothing.
##
## The respawn runs inside a physics tick, never from _process: inside a tick the drawn Unit and
## its camera jump together in one rendered frame, while from _process the frame of the teleport
## still draws the Unit at the wreck after the camera has snapped (ChaseCamera.snap_to_target()).
## The start of the Round is the same spawn call, made from begin() before the first tick.
##
## A respawn onto another Unit. A Unit put down inside another one is not separated cleanly (see
## Unit.is_spot_taken()): it is pushed through the floor, thrown into the air or left on the other's
## roof, and the Player's only way out would be to destroy itself again. So when the due frame comes
## the Unit is put on the Base's spawn point if no other Unit stands there, else on the first free
## one of the Base's spare_spawn_points, on that same tick: a Player parked on the enemy's spawn
## point cannot keep that enemy out of play, and a destroyed Unit respawns after the delay (AC-3,
## AC-4). A Unit is never put down inside another one: only when the spawn point and every spare
## are taken does the Player stay WAITING, and then the controller looks again every physics tick
## and spawns on the first tick a spot is free. While blocked, seconds_until_respawn() reads one
## tick, so a countdown never shows a waiting Player as done. The policy is decided here and open to
## the designer; the alternatives, waiting for ever or a spawn that destroys what stands there,
## belong to a later story (raids, weapons). The start of the Round does not wait: nothing
## stands on a Base then, and the Units have not left the places the scene put them.

## A Player's Unit left play, and that Player now waits out the respawn delay. The wait is
## already stamped when this fires, so seconds_until_respawn(player_index) is the full delay in a
## handler and is_alive(player_index) is false. Player 1 is index 0. When the Unit carried a
## canister, canister_dropped went out just before this.
signal unit_destroyed(player_index: int)

## A Player's Unit was put on that Player's Base, on its spawn point or, when that was taken, on a
## spare one: once for each Player when the Round begins, at every respawn and at every restart.
## The Unit is alive at full hit points and its camera has snapped behind it; is_alive(player_index)
## is already true when this fires.
signal unit_spawned(player_index: int)

## The Round began, or began again: both Units stand on their Bases at full hit points and every
## canister stands on its Base's seat. Emitted by begin() after its spawns and by restart() after
## the unpause, so is_round_over() is false in a handler. A HUD refreshes its canister status on
## it; the Round-over screen hides.
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

## Where one Player is in the Round. The transitions are in the class doc.
enum State {
	## Not in the Round: before begin(), or begin() could not put the Unit in play, or a node of the
	## Player was freed.
	OUT_OF_ROUND,
	## The Player's Unit is in play.
	ALIVE,
	## The Player's Unit was destroyed and waits for its respawn frame, and for a free spot on its
	## Base.
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

## Physics ticks after a spawn during which the Player's pick-ups and deliveries are skipped: on
## the tick after Unit.spawn() the engine still reports an overlap at the Unit's old position (one
## tick; the class doc names the measurement), and two more are margin. An engine latency, not a
## tuning value, so a constant and not a MatchRules field.
const SPAWN_SETTLE_TICKS: int = 3

## The answer of winner_index() while nobody has won.
const NO_WINNER: int = -1

## The tuning values (a MatchRules .tres, for example match_rules.tres): rules.respawn_delay_seconds
## is the wait between a destruction and the respawn (Story 003 AC-3). Required: begin() refuses to
## start the Round without it, or while the delay is not above zero. The resource is shared, so
## never write to it at runtime.
@export var rules: MatchRules

var _units: Array[Unit] = []
var _bases: Array[Base] = []
var _cameras: Array[ChaseCamera] = []
## One State per Player.
var _state: Array[int] = []
## One physics frame per Player: the frame at which that Player respawns. Read only while WAITING.
var _respawn_frame: Array[int] = []
## One flag per Player: true while that Player's respawn is due but another Unit stands on the
## spawn point and on every spare one. Cleared at every spawn and every destruction.
var _is_blocked: Array[bool] = []
## One physics frame per Player: the frame of that Player's last spawn (the settle rule).
var _settle_frame: Array[int] = []
## Who carries which canister, and the calls down to the canisters. Built by begin().
var _canisters: CanisterRules = null
var _round_state: RoundState = RoundState.RUNNING
var _winner: int = NO_WINNER
var _has_begun: bool = false
## True between NOTIFICATION_PAUSED and NOTIFICATION_UNPAUSED, and the physics frame of the first.
var _is_paused: bool = false
var _pause_frame: int = 0


## Notes the frame a pause began and, when it ends, pushes every wait on by the ticks it lasted. An
## unpause with no pause before it (the node entered a paused tree) changes nothing.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED:
			if not _is_paused:
				_is_paused = true
				_pause_frame = Engine.get_physics_frames()
		NOTIFICATION_UNPAUSED:
			if _is_paused:
				_is_paused = false
				_push_waits_on(Engine.get_physics_frames() - _pause_frame)


## Respawns every WAITING Player whose due frame has come and whose Base has a free spot (the spawn
## point, or else a spare one), then, while the Round runs, applies the canister rules in their
## order (pick-ups, then deliveries) and, when a delivery won, pauses the tree and announces the
## winner. The wait and the settle rule are counted in physics ticks, not in delta: see the class
## doc.
func _physics_process(_delta: float) -> void:
	var frame: int = Engine.get_physics_frames()
	for player_index: int in _state.size():
		if _state[player_index] == State.WAITING and frame >= _respawn_frame[player_index]:
			_try_respawn(player_index)
	if _round_state != RoundState.RUNNING or _canisters == null:
		return
	var may_act: Array[bool] = []
	for player_index: int in _state.size():
		may_act.append(_state[player_index] == State.ALIVE
			and frame - _settle_frame[player_index] >= SPAWN_SETTLE_TICKS)
	_apply_pick_ups(may_act)
	_apply_deliveries(may_act)
	if _round_state == RoundState.OVER:
		get_tree().paused = true
		round_over.emit(_winner)


## Starts the Round: puts every Player's Unit on that Player's Base (Story 003 AC-1) by the same
## path a respawn uses, seats every canister on its Base's seat (Story 004 AC-1), emits
## round_started, and from then on listens for the Units' destroyed signals. Call it once, from
## the composition root (SplitScreen), with the Units, Bases and cameras already in the tree. The
## three arrays hold one entry per Player, in the same order, Player 1 first: the Unit that Player
## drives, the Base it starts and respawns at, which also holds that Player's canister and its
## seat, and the camera that chases that Unit. When anything is wrong (rules missing or a delay
## not above zero, no Players, arrays of different sizes, an entry that is null or not in the
## tree, a Base without a spawn point, a canister or a canister seat, or with a spawn point off
## its pad) it pushes one error naming the problem and does nothing: no spawn, no connection, no
## signal. A second call after a successful one is refused the same way. A Unit that cannot be put
## in play (it refused to drive in _ready()) pushes an error and leaves only its own Player out of
## the Round.
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
	_state.resize(_units.size())
	_state.fill(State.OUT_OF_ROUND)
	_respawn_frame.resize(_units.size())
	_respawn_frame.fill(0)
	_is_blocked.resize(_units.size())
	_is_blocked.fill(false)
	_settle_frame.resize(_units.size())
	_settle_frame.fill(0)
	_canisters = CanisterRules.new(_units, _bases)
	_round_state = RoundState.RUNNING
	_winner = NO_WINNER
	for player_index: int in _units.size():
		_units[player_index].destroyed.connect(_on_unit_destroyed.bind(player_index))
	for player_index: int in _units.size():
		_spawn(player_index, _bases[player_index].spawn_point.global_transform)
	_canisters.seat_all()
	round_started.emit()


## Starts the Round again after a win (Story 004 AC-6): every canister is seated on its Base's
## seat (a carried one goes home), every Player's Unit is put on its Base's spawn point by the one
## spawn path (a pending respawn wait is cancelled, hit points are refilled, unit_spawned goes
## out), the Round is RUNNING, the tree is unpaused and round_started goes out, in that order.
## Only while the Round is over: a call while it runs pushes a warning and does nothing.
func restart() -> void:
	if _round_state != RoundState.OVER:
		push_warning("MatchController '%s': restart() was called while the Round is running, so nothing happens. It restarts a Round that is over." % name)
		return
	_canisters.seat_all()
	for player_index: int in _units.size():
		_spawn(player_index, _bases[player_index].spawn_point.global_transform)
	_round_state = RoundState.RUNNING
	_winner = NO_WINNER
	get_tree().paused = false
	round_started.emit()


## True while the Player's Unit is in play. False while it waits to respawn, before begin(), and
## for a player_index that is not in the Round.
func is_alive(player_index: int) -> bool:
	return _is_player(player_index) and _state[player_index] == State.ALIVE


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


## Seconds until the Player's Unit respawns: the full delay on the tick of the destruction, then
## counting down to zero. 0.0 while the Player is alive, before begin(), and for a player_index
## that is not in the Round. It is the stamped frame minus the current physics frame, over the
## tick rate, so it is exact: a countdown that shows ceili() of it changes digit on whole
## seconds (3 for the first second of a 3 second delay, then 2, then 1). Safe to poll from _process:
## the frame number read there is the last completed tick's. While the respawn is due but every
## spot of the Base is taken it reads one tick, so a countdown never shows a Player who is still
## waiting as done; and while the tree is paused it reads the value of the moment the pause began.
func seconds_until_respawn(player_index: int) -> float:
	if not _is_player(player_index) or _state[player_index] != State.WAITING:
		return 0.0
	var ticks_left: int = maxi(_respawn_frame[player_index] - _now(), 0)
	if _is_blocked[player_index]:
		ticks_left = 1
	return float(ticks_left) / float(Engine.physics_ticks_per_second)


## The one spawn path: the start of the Round, every respawn and a restart (Story 003 AC-1, AC-3;
## Story 004 AC-6). The Unit goes to the given pose first (a Base's spawn point or spare spawn
## point) and the camera snaps after it (the order of a teleport; see Unit.spawn() and
## ChaseCamera.snap_to_target()); the settle frame is stamped (class doc). The Player is ALIVE
## before the signal goes out, so a listener sees it alive. Called from a physics tick, or from
## begin() before the first.
func _spawn(player_index: int, at: Transform3D) -> void:
	var unit: Unit = _units[player_index]
	unit.spawn(at)
	_is_blocked[player_index] = false
	_settle_frame[player_index] = Engine.get_physics_frames()
	if not unit.is_alive:
		_state[player_index] = State.OUT_OF_ROUND
		push_error("MatchController '%s': the Unit of player_index %d is not alive after spawn(), so that Player is out of the Round. The Unit reported why." % [name, player_index])
		return
	_cameras[player_index].snap_to_target()
	_state[player_index] = State.ALIVE
	unit_spawned.emit(player_index)


## A due respawn: puts the Player's Unit on its Base's spawn point unless another Unit stands
## there, else on the first free spare spawn point of the Base, in their order; when every spot is
## taken the Player stays WAITING and the next tick asks again. Drops the Player out of the Round
## when one of its nodes was freed since begin(), with one error instead of one per tick.
func _try_respawn(player_index: int) -> void:
	if _has_freed_node(player_index):
		_state[player_index] = State.OUT_OF_ROUND
		_is_blocked[player_index] = false
		push_error("MatchController '%s': a node of player_index %d was freed, so that Player is out of the Round." % [name, player_index])
		return
	var unit: Unit = _units[player_index]
	var base: Base = _bases[player_index]
	var spots: Array[Marker3D] = [base.spawn_point]
	spots.append_array(base.spare_spawn_points)
	for spot: Marker3D in spots:
		if not is_instance_valid(spot) or not spot.is_inside_tree():
			continue
		if not unit.is_spot_taken(spot.global_transform):
			_spawn(player_index, spot.global_transform)
			return
	_is_blocked[player_index] = true


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


## True when the Unit, the Base, its spawn point or the camera of the Player was freed.
func _has_freed_node(player_index: int) -> bool:
	var base: Base = _bases[player_index]
	if not is_instance_valid(_units[player_index]) or not is_instance_valid(_cameras[player_index]):
		return true
	return not is_instance_valid(base) or not is_instance_valid(base.spawn_point)


## Pushes the due frame of every WAITING Player, and the settle stamp of every Player stamped
## before the pause began, on by this many ticks: the time the node did not run (class doc, the
## paragraph on pause). A blocked wait is left alone: its due frame is already reached, and must
## stay so for the first tick after the unpause to look for a free spot. A settle stamp taken
## during the pause (restart()'s) is later than the pause's frame and stays.
func _push_waits_on(ticks: int) -> void:
	for player_index: int in _state.size():
		if _state[player_index] == State.WAITING and not _is_blocked[player_index]:
			_respawn_frame[player_index] += ticks
		if _settle_frame[player_index] <= _pause_frame:
			_settle_frame[player_index] += ticks


## The physics frame the waits are measured against: the frame the pause began while paused.
func _now() -> int:
	return _pause_frame if _is_paused else Engine.get_physics_frames()


## The respawn delay in physics ticks: the tuned seconds times the tick rate, rounded, and never
## less than one, so a destroyed Unit is always out of play for at least one tick.
func _delay_ticks() -> int:
	return maxi(roundi(rules.respawn_delay_seconds * float(Engine.physics_ticks_per_second)), 1)


## True for an index of a Player in this Round.
func _is_player(player_index: int) -> bool:
	return player_index >= 0 and player_index < _state.size()


## What is wrong with the arguments of begin() and the rules, as a sentence, or an empty string
## when there is nothing wrong.
func _first_problem(units: Array[Unit], bases: Array[Base], cameras: Array[ChaseCamera]) -> String:
	if rules == null:
		return "rules is not assigned"
	if not (rules.respawn_delay_seconds > 0.0):
		return "rules.respawn_delay_seconds is %s and must be above zero" % rules.respawn_delay_seconds
	if units.is_empty():
		return "no Players were given"
	if bases.size() != units.size() or cameras.size() != units.size():
		return "it needs one Unit, one Base and one camera per Player but got %d Units, %d Bases and %d cameras" % [units.size(), bases.size(), cameras.size()]
	for player_index: int in units.size():
		var problem: String = _first_player_problem(units, bases, cameras, player_index)
		if not problem.is_empty():
			return problem
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


## A Unit left play: stamp the frame at which its Player respawns, drop the canister it carried at
## the wreck (rule (3); AC-3), then tell the listeners. The state and the stamp are set before the
## signals go out, so a handler already sees the Player waiting with the full delay, and
## canister_dropped goes out before unit_destroyed.
func _on_unit_destroyed(player_index: int) -> void:
	if _state[player_index] != State.ALIVE:
		push_warning("MatchController '%s': the Unit of player_index %d was destroyed while that Player was not ALIVE (State %d), so the destruction is ignored." % [name, player_index, _state[player_index]])
		return
	_respawn_frame[player_index] = _now() + _delay_ticks()
	_is_blocked[player_index] = false
	_state[player_index] = State.WAITING
	var dropped: int = _canisters.drop(player_index)
	if dropped != CanisterRules.NONE:
		canister_dropped.emit(dropped)
	unit_destroyed.emit(player_index)
