class_name MatchController
extends Node
## Owns the state of one Round: whose Unit is alive, who is waiting to respawn and when. It puts
## each Player's Unit on that Player's Base at the start of the Round and again at every respawn.
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-1 (each
## Player's Unit starts the Round at its own Base), AC-3 (a destroyed Unit respawns at its
## Player's Base after a delay that is a data tuning value, 3 seconds in match_rules.tres), AC-4
## (respawns are unlimited: nothing here counts lives or caps respawns) and AC-7 (the Round's state,
## who is alive and the respawn timers, lives in this one node, which emits unit_destroyed and
## unit_spawned; Units never reach into each other or into a singleton); design/game-brief.md MVP
## feature 3 (Bases, destruction and respawn); design/rules.md "Destruction, respawn and unit
## swap" (a destroyed Unit respawns at its player's Base, without limit, after a delay of about
## three seconds, a tuning value). Vocabulary: CONTEXT.md (Player, Unit, Base, Round). The node and
## its rules resource keep the names the story gave them (MatchController, MatchRules; AC-7); in
## prose the thing they serve is the Round, as CONTEXT.md has it.
##
## Signals up, calls down. A Unit emits `destroyed` and nothing else: it never calls this
## controller, the other Unit or a singleton. The controller listens, then calls down: it asks the
## Unit to spawn() and the camera to snap_to_target(). Everything it touches is handed to it once,
## by begin() (dependency injection: no node path, no autoload, no static state), so a test can
## build one from stand-in Units, Bases and cameras without the split-screen scene. Player index 0
## is Player 1.
##
## It knows nothing about the screen. A HUD node listens to unit_destroyed and unit_spawned and asks
## seconds_until_respawn(); this script references no UI class, draws nothing and holds no text, so
## the display can change, or go, without touching the Round. It reads no input either: what a key
## does to a Unit is PlayerMatchInput's business, and that acts on the Unit, so a Self-destruct
## reaches its respawn by the same path as a lost fight.
##
## State per Player. Each Player's state is independent of the other's: both can wait at once,
## each with its own due frame. The table is complete; a pair it does not list cannot happen.
##   OUT_OF_ROUND -> ALIVE         begin() put the Unit in play: emit unit_spawned
##   OUT_OF_ROUND -> OUT_OF_ROUND  begin() could not (the Unit refused to drive): push_error
##   ALIVE        -> WAITING       the Unit emitted destroyed: stamp the frame, emit unit_destroyed
##   WAITING      -> ALIVE         the physics frame reached the stamp and the spawn point, or a
##                                 spare spawn point, is free: spawn there, emit unit_spawned
##   WAITING      -> WAITING       the frame reached the stamp but another Unit stands on the spawn
##                                 point and on every spare one: look again next tick (the
##                                 paragraph on a respawn onto another Unit)
##   WAITING      -> OUT_OF_ROUND  a node of the Player (Unit, Base, spawn point, camera) was
##                                 freed: one push_error
## A `destroyed` from a Player who is not ALIVE is ignored with a warning: a Unit that is not alive
## cannot be destroyed, so only a Unit spawned behind this controller's back could send one.
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
## reached and stays so: the first tick after the unpause looks for a free spot again.
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
## belong to Stories 004 and 005 (raids, weapons). The start of the Round does not wait: nothing
## stands on a Base then, and the Units have not left the places the scene put them.

## A Player's Unit left play, and that Player now waits out the respawn delay. The wait is
## already stamped when this fires, so seconds_until_respawn(player_index) is the full delay in a
## handler and is_alive(player_index) is false. Player 1 is index 0.
signal unit_destroyed(player_index: int)

## A Player's Unit was put on that Player's Base, on its spawn point or, when that was taken, on a
## spare one: once for each Player when the Round begins, and at every respawn. The Unit is alive
## at full hit points and its camera has snapped behind it; is_alive(player_index) is already true
## when this fires.
signal unit_spawned(player_index: int)

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
## point, or else a spare one). The wait is counted in physics ticks, not in delta: see the class
## doc.
func _physics_process(_delta: float) -> void:
	var frame: int = Engine.get_physics_frames()
	for player_index: int in _state.size():
		if _state[player_index] == State.WAITING and frame >= _respawn_frame[player_index]:
			_try_respawn(player_index)


## Starts the Round: puts every Player's Unit on that Player's Base (Story 003 AC-1) by the same
## path a respawn uses, and from then on listens for the Units' destroyed signals. Call it once,
## from the composition root (SplitScreen), with the Units, Bases and cameras already in the tree.
## The three arrays hold one entry per Player, in the same order, Player 1 first: the Unit that
## Player drives, the Base it starts and respawns at, and the camera that chases that Unit. When
## anything is wrong (rules missing or a delay not above zero, no Players, arrays of different
## sizes, an entry that is null or not in the tree, a Base without a spawn point or with a spawn
## point off its pad) it pushes one error naming the problem and does nothing: no spawn, no
## connection, no signal. A second call after a successful one is refused the same way. A Unit
## that cannot be put in play (it refused to drive in _ready()) pushes an error and leaves only its
## own Player out of the Round.
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
	for player_index: int in _units.size():
		_units[player_index].destroyed.connect(_on_unit_destroyed.bind(player_index))
	for player_index: int in _units.size():
		_spawn(player_index, _bases[player_index].spawn_point.global_transform)


## True while the Player's Unit is in play. False while it waits to respawn, before begin(), and
## for a player_index that is not in the Round.
func is_alive(player_index: int) -> bool:
	return _is_player(player_index) and _state[player_index] == State.ALIVE


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


## The one spawn path: the start of the Round and every respawn (Story 003 AC-1, AC-3). The Unit
## goes to the given pose first (a Base's spawn point or spare spawn point) and the camera snaps
## after it (the order of a teleport; see Unit.spawn() and ChaseCamera.snap_to_target()). The
## Player is ALIVE before the signal goes out, so a listener sees it alive. Called from a physics
## tick, or from begin() before the first.
func _spawn(player_index: int, at: Transform3D) -> void:
	var unit: Unit = _units[player_index]
	unit.spawn(at)
	_is_blocked[player_index] = false
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


## True when the Unit, the Base, its spawn point or the camera of the Player was freed.
func _has_freed_node(player_index: int) -> bool:
	var base: Base = _bases[player_index]
	if not is_instance_valid(_units[player_index]) or not is_instance_valid(_cameras[player_index]):
		return true
	return not is_instance_valid(base) or not is_instance_valid(base.spawn_point)


## Pushes the due frame of every WAITING Player on by this many ticks: the time the node did not
## run. A blocked wait is left alone: its due frame is already reached, and must stay so for the
## first tick after the unpause to look for a free spot.
func _push_waits_on(ticks: int) -> void:
	for player_index: int in _state.size():
		if _state[player_index] == State.WAITING and not _is_blocked[player_index]:
			_respawn_frame[player_index] += ticks


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
	if not is_instance_valid(cameras[player_index]):
		return "cameras[%d] is null" % player_index
	return ""


## A Unit left play: stamp the frame at which its Player respawns, then tell the listeners. The
## state and the stamp are set before the signal goes out, so a handler already sees the Player
## waiting with the full delay.
func _on_unit_destroyed(player_index: int) -> void:
	if _state[player_index] != State.ALIVE:
		push_warning("MatchController '%s': the Unit of player_index %d was destroyed while that Player was not ALIVE (State %d), so the destruction is ignored." % [name, player_index, _state[player_index]])
		return
	_respawn_frame[player_index] = _now() + _delay_ticks()
	_is_blocked[player_index] = false
	_state[player_index] = State.WAITING
	unit_destroyed.emit(player_index)
