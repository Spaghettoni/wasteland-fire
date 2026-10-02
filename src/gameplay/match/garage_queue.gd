class_name GarageQueue
extends RefCounted
## The Garage of one Round, as the MatchController runs it: which Player's Unit is in play, which
## Player is choosing the next Unit type and which has chosen, which Player waits out the respawn
## delay and until which physics frame, the bench that takes a Unit out of play while its Player
## chooses, the one spawn path that puts the chosen type on its Base (the start of the Round, every
## respawn and a restart) with its search for a free spot, the wait's pause bookkeeping, and the
## two settle rules: a spawn is held back for a few ticks after a bench, and a Player's pick-ups and
## deliveries for a few ticks after a spawn. The controller owns one, calls it from begin(),
## restart(), choose(), its physics tick, its `destroyed` handler and its pause notifications, and
## emits every signal; this class emits none and returns what the controller must announce (whether
## a choice was accepted, the Players it put in play, whether a destruction counted), is not a node
## and reads no input, so a test can drive it with stand-in Units, Bases and cameras and read back
## the answers.
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-1 (every
## Unit starts on its Player's Base), AC-3 (a destroyed Unit respawns on its Base after the delay),
## AC-4 (a Unit parked on the enemy's spawn point cannot keep that enemy out of play) and AC-7 (the
## names: the per-Player state, the waits and the spawn path were MatchController's own until Story
## 005 paid docs/tech-debt-register.md TD-008 by moving them here unchanged, so the messages still
## name the MatchController, the node a reader finds in the tree); the spawn settle rule of
## production/epics/wasteland-fire/story-004-water-canister-and-win.md (below);
## production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-6 (at every spawn the
## Player chooses the Unit type before the Unit appears: at the start of the Round it appears as
## soon as it is chosen, after a destruction once it is chosen and the delay has passed, whichever
## is later, and the other Player plays on meanwhile) and AC-5 (the spot check is made as the
## chosen type); design/game-brief.md MVP features 3 (Bases, destruction and respawn) and 5 (the
## four Units); design/rules.md "Tokens and the Garage" and "Destruction and respawn". Vocabulary:
## CONTEXT.md (Player, Unit, Base, Garage, Round). Player index 0 is Player 1.
##
## State per Player (MatchController.State). Each Player's state is independent of the other's:
## both can choose or wait at once, each with its own due frame. WAITING covers two halves: the
## Player has not chosen yet (is_choosing()), or has chosen and waits for the due frame, the bench
## settle or a free spot (chosen_type_index()). The table is complete; a pair it does not list
## cannot happen.
##   OUT_OF_ROUND -> WAITING       bench() from begin() or restart(): the Unit is put on its Base's
##                                 spawn point and benched (Unit.leave_play()); the Player chooses,
##                                 due at once
##   WAITING      -> WAITING       choose(): the Player chose a type, and the choice stands until
##                                 the Unit appears: true, and the controller emits unit_chosen
##   WAITING      -> ALIVE         tick(): the Player has chosen, the physics frame reached the due
##                                 stamp and the bench settle, and the spawn point, or a spare one,
##                                 is free of bodies for the chosen type: spawn there as that type,
##                                 the Player is in the returned list and the controller emits
##                                 unit_spawned
##   WAITING      -> WAITING       tick(): the Player has not chosen; or has chosen but the due
##                                 frame or the bench settle has not come; or another Unit stands
##                                 on the spawn point and on every spare one: look again next tick
##                                 (the paragraph on a respawn onto another Unit)
##   WAITING      -> WAITING       bench() from restart(): the wait is cancelled, the choice
##                                 cleared and the Unit put on its spawn point; the Player chooses
##   WAITING      -> OUT_OF_ROUND  tick(): a node of the Player (Unit, Base, spawn point, camera)
##                                 was freed, or the Unit is not alive after spawn() (it refused to
##                                 drive in _ready()): one push_error each
##   ALIVE        -> WAITING       note_destroyed(): the Unit emitted destroyed: stamp the frame,
##                                 clear the choice, true, and the controller drops the canister it
##                                 carried (if any) at the wreck and emits unit_destroyed; or
##                                 bench() from restart(): the Unit is put on its spawn point and
##                                 benched, the Player chooses
## A note_destroyed() for a Player who is not ALIVE is refused with a warning and false: a Unit
## that is not alive cannot be destroyed, so only a Unit spawned behind the controller's back could
## send one. A choose() for a Player who is not WAITING, or who has chosen already, is refused with
## false and nothing changes; the Round's own refusals (not begun, over, an index outside the data)
## are the controller's, before it asks.
##
## The choice (Story 005 AC-6). The two halves of a respawn are independent: the due frame runs
## from the destruction whether or not the Player has chosen, and the choice may come before or
## after it, so the Unit appears once both have come, whichever is later; at the start of the
## Round and after a restart the due frame is the bench's own, so there the Unit appears as soon
## as it is chosen and the bench has settled. A choice stands until the Unit appears, is cleared by
## a destruction and by a bench, and cannot be changed once made. The type is the data's: tick()
## spawns with the controller's rules.unit_types[choice], read live at the spawn, and asks
## Unit.is_spot_taken(spot, that type) first, so a Truck is checked as a Truck before it is put
## down (AC-5). Nothing here names a type.
##
## The bench settle rule. A Unit.spawn() that changes the collider, issued on the first physics
## tick after that same Unit's previous teleport, is thrown by the physics server (measured on
## Godot 4.7.2 with Jolt: a Truck spawned one tick after its bench flew 10 m onto the other Unit's
## roof; the same spawn two or more ticks after the teleport lands exactly and stays; the Story 005
## evidence doc keeps the run), and every bench teleports the Unit to its spawn point. So bench()
## stamps the physics frame and tick() spawns a chosen Player no earlier than SPAWN_SETTLE_TICKS
## frames after it: a choice confirmed on the tick after the bench costs the Player at most that
## many ticks, a choice made later costs nothing. It is the same engine latency with a margin as
## the spawn settle rule's, so it is the same constant.
##
## The spawn settle rule. On the tick after Unit.spawn() the physics server still reports the Unit
## overlapping whatever stood at its OLD position (measured on Godot 4.7.2 with Jolt: a respawned
## Carrier was reported touching its own dropped canister 10 m away, for one tick; the Story 004
## evidence doc keeps the probe), so without a guard a Player would re-pick its dropped canister
## from its Base, or deliver an enemy canister lying at its wreck. _spawn() therefore stamps the
## physics frame per Player and may_act() holds that Player back until SPAWN_SETTLE_TICKS frames
## have passed: at every spawn, so at the start of the Round, at every respawn and after a restart.
## The count is an engine latency with a margin, not a tuning value, so it is a constant here and
## not a MatchRules field.
##
## The respawn wait is an absolute physics-frame stamp, not a Timer and not a countdown. When a
## Unit is destroyed note_destroyed() stores Engine.get_physics_frames() plus the delay in ticks
## (rules.respawn_delay_seconds times Engine.physics_ticks_per_second, rounded, and at least one),
## and tick() respawns the Player once the frame number reaches it and the Player has chosen. A
## Timer fires a tick early or late depending on where it sits in the tree relative to the code
## that starts it, and a float countdown carries rounding error (repeated subtraction of 1/60 does
## not land on exactly zero), so neither gives the same tick count from every call context; the
## stamp does, because the frame number is constant inside a tick. So the wait is exactly
## round(delay * tick rate) ticks from the destroy tick to the spawn tick, for the data's delay and
## for any other, with seconds_until_respawn() falling every tick from the delay to zero (the Story
## 003 evidence doc keeps the measurements); a Player who chooses later than that appears on the
## tick of the choice. The count is in physics ticks, so the render frame rate does not move it;
## Engine.time_scale is not tested, and nothing in the game sets it.
##
## The wait honours pause. Engine.get_physics_frames() keeps counting while the tree is paused,
## although the controller stops processing, so a stamp would run out under the pause.
## note_paused() notes the frame, note_unpaused() pushes every stamp on by the ticks that passed,
## and seconds_until_respawn() reads the noted frame while paused, so a pause menu sees a frozen
## value. A node that does not process for another reason (its process_mode) gets the same two
## notifications, so the time it did not run does not count either: a pause longer than the whole
## delay ends with as many ticks of the wait still to run as were left when it began. A wait that
## was already due and blocked when the pause began is not pushed on, because its stamp is reached
## and stays so: the first tick after the unpause looks for a free spot again. A settle stamp or a
## bench stamp taken before the pause began is pushed on the same way, so a pause never counts as
## settled ticks: the physics server does not step while the tree is paused (the Story 004
## evidence doc keeps the run), so the ghost overlap the settle rules guard against would survive
## the pause unstepped. The pause of a won Round ends in restart() after every Player was benched,
## later than the pause began, so the benches' own stamps are not pushed; their due frames, taken
## at the frame the pause began, are pushed to the frame of the unpause: due at once, as meant.
##
## The respawn runs inside a physics tick, never from _process: inside a tick the drawn Unit and
## its camera jump together in one rendered frame, while from _process the frame of the teleport
## still draws the Unit at the wreck after the camera has snapped (ChaseCamera.snap_to_target()).
## The start of the Round is the same spawn call, made from the first tick on which the Player has
## chosen and the bench has settled; the bench itself, from begin(), comes before the first tick.
##
## A respawn onto another Unit. A Unit put down inside another one is not separated cleanly (see
## Unit.is_spot_taken()): it is pushed through the floor, thrown into the air or left on the other's
## roof, and the Player's only way out would be to destroy itself again. So when the due frame comes
## the Unit is put on the Base's spawn point if no other Unit stands there, else on the first free
## one of the Base's spare_spawn_points, on that same tick: a Player parked on the enemy's spawn
## point cannot keep that enemy out of play, and a destroyed Unit respawns after the delay (AC-3,
## AC-4). A Unit is never put down inside another one: only when the spawn point and every spare
## are taken does the Player stay WAITING, and then tick() looks again every physics tick and
## spawns on the first tick a spot is free. While blocked, seconds_until_respawn() reads one tick,
## so a countdown never shows a waiting Player as done. The policy is decided here and open to the
## designer; the alternatives, waiting for ever or a spawn that destroys what stands there, belong
## to a later story (raids, weapons). The same search serves the start of the Round and a restart,
## where a Player who chose late may find the other Player's Unit on its Base.

## Physics ticks after a spawn during which the Player's pick-ups and deliveries are skipped, and
## physics ticks after a bench before which no spawn is made: on the tick after Unit.spawn() the
## engine still reports an overlap at the Unit's old position, and a collider swapped on the tick
## after a teleport is thrown (one tick each; the class doc names the measurements), and two more
## are margin. An engine latency, not a tuning value, so a constant and not a MatchRules field.
const SPAWN_SETTLE_TICKS: int = 3

## The answer of chosen_type_index() while the Player has not chosen.
const NO_CHOICE: int = -1

var _units: Array[Unit] = []
var _bases: Array[Base] = []
var _cameras: Array[ChaseCamera] = []
## The MatchController this queue serves. Its rules export is read live, at every destruction and
## every spawn, as the controller read it before the move (rules.respawn_delay_seconds is the wait,
## Story 003 AC-3; rules.unit_types holds the types a choice indexes, Story 005; a rules resource
## assigned to the controller after begin() is honoured by the next destruction and spawn), and its
## name goes into the messages. Never written here.
var _owner: MatchController = null
## One MatchController.State per Player.
var _state: Array[int] = []
## One physics frame per Player: the frame at which that Player respawns. Read only while WAITING.
var _respawn_frame: Array[int] = []
## One flag per Player: true while that Player's respawn is due but another Unit stands on the
## spawn point and on every spare one. Cleared at every spawn, every bench and every destruction.
var _is_blocked: Array[bool] = []
## One physics frame per Player: the frame of that Player's last spawn (the spawn settle rule).
var _settle_frame: Array[int] = []
## One type index per Player, into the controller's rules.unit_types: the choice that stands, or
## NO_CHOICE while the Player is choosing. Meaningful only while WAITING.
var _choice: Array[int] = []
## One physics frame per Player: the frame of that Player's last bench (the bench settle rule).
var _bench_frame: Array[int] = []
## True between note_paused() and note_unpaused(), and the physics frame of the first.
var _is_paused: bool = false
var _pause_frame: int = 0


## Keeps the controller itself (for its rules and its name, read live) and its own Unit, Base and
## camera arrays, one entry per Player in Player order (the same arrays begin() validated), by
## reference and not as copies. Every Player starts OUT_OF_ROUND with no wait, no choice, unblocked
## and unsettled (frame 0). Call it once, from begin(), after the validation; before it the queue
## holds no Player, and only the pause bookkeeping runs.
func enlist(owner: MatchController, units: Array[Unit], bases: Array[Base], cameras: Array[ChaseCamera]) -> void:
	_owner = owner
	_units = units
	_bases = bases
	_cameras = cameras
	_state.resize(_units.size())
	_state.fill(MatchController.State.OUT_OF_ROUND)
	_respawn_frame.resize(_units.size())
	_respawn_frame.fill(0)
	_is_blocked.resize(_units.size())
	_is_blocked.fill(false)
	_settle_frame.resize(_units.size())
	_settle_frame.fill(0)
	_choice.resize(_units.size())
	_choice.fill(NO_CHOICE)
	_bench_frame.resize(_units.size())
	_bench_frame.fill(0)


## Takes the Player's Unit out of play while the Player chooses the next type: the start of the
## Round (begin()) and a restart. The Unit is put on its Base's spawn point first (global_transform,
## then Unit.reset_motion(): the teleport order) and its camera snapped after it, so each view
## shows its own Base while its Player chooses, then benched with Unit.leave_play() (a destroyed
## Unit is left benched where the teleport put it; one that refused to drive is placed and left
## alone, and the spawn after its Player's choice reports it). A pending wait is cancelled, the
## choice cleared, and the Player is WAITING and due at once: at the frame the waits are measured
## against, so a bench during the pause of a won Round is due on the first tick after the unpause.
## The bench frame is stamped (the bench settle rule). Called from begin() before the first tick,
## or from restart() inside a tick.
func bench(player_index: int) -> void:
	var unit: Unit = _units[player_index]
	unit.global_transform = _bases[player_index].spawn_point.global_transform
	unit.reset_motion()
	_cameras[player_index].snap_to_target()
	unit.leave_play()
	_state[player_index] = MatchController.State.WAITING
	_respawn_frame[player_index] = _now()
	_is_blocked[player_index] = false
	_choice[player_index] = NO_CHOICE
	_bench_frame[player_index] = Engine.get_physics_frames()


## The Player chose the type at type_index into the controller's rules.unit_types (the controller
## has checked the Round and the index): accepted, true, when the Player is WAITING and has not
## chosen since its last spawn, bench or destruction, and the controller emits unit_chosen; else
## false and nothing changes. The choice stands until tick() puts the Unit in play.
func choose(player_index: int, type_index: int) -> bool:
	if not is_choosing(player_index):
		return false
	_choice[player_index] = type_index
	return true


## True while the Player is WAITING and has not chosen: the time the choice panel is shown and the
## choice keys are read. False while the Player is in play, has chosen, is out of the Round, before
## enlist() and for a player_index that is not in the Round.
func is_choosing(player_index: int) -> bool:
	return (_is_player(player_index) and _state[player_index] == MatchController.State.WAITING
		and _choice[player_index] == NO_CHOICE)


## The type index the Player chose, which stands until its Unit appears, or NO_CHOICE (-1): while
## the Player is choosing, in play, out of the Round, before enlist() and for a player_index that
## is not in the Round.
func chosen_type_index(player_index: int) -> int:
	if not _is_player(player_index) or _state[player_index] != MatchController.State.WAITING:
		return NO_CHOICE
	return _choice[player_index]


## The Garage's physics tick: spawns every WAITING Player who has chosen, whose due frame has
## come, whose bench has settled (the bench settle rule) and whose Base has a free spot for the
## chosen type (the spawn point, or else a spare one). Returns the indices of the Players it put in
## play, in Player order, for the controller to announce with unit_spawned, one each. The wait and
## the settle rules are counted in physics ticks, not in delta: see the class doc. Nothing happens
## before enlist().
func tick() -> Array[int]:
	var spawned: Array[int] = []
	var frame: int = Engine.get_physics_frames()
	for player_index: int in _state.size():
		if _state[player_index] != MatchController.State.WAITING or _choice[player_index] == NO_CHOICE:
			continue
		if frame < _respawn_frame[player_index] or frame - _bench_frame[player_index] < SPAWN_SETTLE_TICKS:
			continue
		if _try_respawn(player_index):
			spawned.append(player_index)
	return spawned


## A Unit left play: stamps the frame at which its Player respawns, clears the choice (the Player
## chooses the next type, Story 005 AC-6) and puts the Player in WAITING, so a handler of the
## controller's unit_destroyed already sees the Player waiting with the full delay and choosing.
## True when the destruction counted; false, with one warning, when the Player was not ALIVE (class
## doc), and then nothing changes and the controller announces nothing.
func note_destroyed(player_index: int) -> bool:
	if _state[player_index] != MatchController.State.ALIVE:
		push_warning("MatchController '%s': the Unit of player_index %d was destroyed while that Player was not ALIVE (State %d), so the destruction is ignored." % [_owner.name, player_index, _state[player_index]])
		return false
	_respawn_frame[player_index] = _now() + _delay_ticks()
	_is_blocked[player_index] = false
	_choice[player_index] = NO_CHOICE
	_state[player_index] = MatchController.State.WAITING
	return true


## The controller's NOTIFICATION_PAUSED: notes the frame the pause began. A second note before the
## unpause changes nothing.
func note_paused() -> void:
	if not _is_paused:
		_is_paused = true
		_pause_frame = Engine.get_physics_frames()


## The controller's NOTIFICATION_UNPAUSED: pushes every wait on by the ticks the pause lasted (the
## class doc, the paragraph on pause). An unpause with no pause before it (the node entered a
## paused tree) changes nothing.
func note_unpaused() -> void:
	if _is_paused:
		_is_paused = false
		_push_waits_on(Engine.get_physics_frames() - _pause_frame)


## True while the Player's Unit is in play. False while it chooses or waits to respawn, before
## enlist(), and for a player_index that is not in the Round.
func is_alive(player_index: int) -> bool:
	return _is_player(player_index) and _state[player_index] == MatchController.State.ALIVE


## Seconds until the Player's Unit may respawn: the full delay on the tick of the destruction, then
## counting down to zero, whether or not the Player has chosen; zero while a Player who has not
## chosen could appear at once (the start of the Round, a restart, a delay that has run out). 0.0
## while the Player is alive, before enlist(), and for a player_index that is not in the Round. It
## is the stamped frame minus the current physics frame, over the tick rate, so it is exact: a
## countdown that shows ceili() of it changes digit on whole seconds (3 for the first second of a 3
## second delay, then 2, then 1). Safe to poll from _process: the frame number read there is the
## last completed tick's. While the respawn is due and chosen but every spot of the Base is taken
## it reads one tick, so a countdown never shows a Player who is still waiting as done; and while
## the tree is paused it reads the value of the moment the pause began.
func seconds_until_respawn(player_index: int) -> float:
	if not _is_player(player_index) or _state[player_index] != MatchController.State.WAITING:
		return 0.0
	var ticks_left: int = maxi(_respawn_frame[player_index] - _now(), 0)
	if _is_blocked[player_index]:
		ticks_left = 1
	return float(ticks_left) / float(Engine.physics_ticks_per_second)


## One flag per Player, in Player order: true while that Player may pick up and deliver on this
## tick, that is ALIVE and settled, SPAWN_SETTLE_TICKS physics frames after its last spawn (the
## spawn settle rule, class doc). The controller hands it to the canister rules. Empty before
## enlist().
func may_act() -> Array[bool]:
	var frame: int = Engine.get_physics_frames()
	var flags: Array[bool] = []
	for player_index: int in _state.size():
		flags.append(_state[player_index] == MatchController.State.ALIVE
			and frame - _settle_frame[player_index] >= SPAWN_SETTLE_TICKS)
	return flags


## The one spawn path: the start of the Round, every respawn and a restart (Story 003 AC-1, AC-3;
## Story 004 AC-6; Story 005 AC-6). The Unit becomes the chosen type and goes to the given pose (a
## Base's spawn point or spare spawn point) in Unit.spawn(at, type_stats), the camera snaps after
## it (the order of a teleport; see ChaseCamera.snap_to_target()), the choice is spent and the
## settle frame stamped (class doc). The Player is ALIVE when this returns true, so a listener of
## the controller's unit_spawned sees it alive; false, with one error, when the Unit is not alive
## after spawn(), and then the Player is OUT_OF_ROUND. Called from a physics tick.
func _spawn(player_index: int, at: Transform3D, type_stats: UnitStats) -> bool:
	var unit: Unit = _units[player_index]
	unit.spawn(at, type_stats)
	_is_blocked[player_index] = false
	_choice[player_index] = NO_CHOICE
	_settle_frame[player_index] = Engine.get_physics_frames()
	if not unit.is_alive:
		_state[player_index] = MatchController.State.OUT_OF_ROUND
		push_error("MatchController '%s': the Unit of player_index %d is not alive after spawn(), so that Player is out of the Round. The Unit reported why." % [_owner.name, player_index])
		return false
	_cameras[player_index].snap_to_target()
	_state[player_index] = MatchController.State.ALIVE
	return true


## A due and chosen spawn: puts the Player's Unit, as the chosen type, on its Base's spawn point
## unless another Unit stands where that type's collider would go, else on the first free spare
## spawn point of the Base, in their order, and returns whether the Player is in play after it;
## when every spot is taken the Player stays WAITING and the next tick asks again. Drops the Player
## out of the Round when one of its nodes was freed since enlist(), with one error instead of one
## per tick. The standing choice is an index that MatchController.choose() already range-checked
## against the shared rules.unit_types.
func _try_respawn(player_index: int) -> bool:
	if _has_freed_node(player_index):
		_state[player_index] = MatchController.State.OUT_OF_ROUND
		_is_blocked[player_index] = false
		push_error("MatchController '%s': a node of player_index %d was freed, so that Player is out of the Round." % [_owner.name, player_index])
		return false
	var type_stats: UnitStats = _owner.rules.unit_types[_choice[player_index]]
	var unit: Unit = _units[player_index]
	var base: Base = _bases[player_index]
	var spots: Array[Marker3D] = [base.spawn_point]
	spots.append_array(base.spare_spawn_points)
	for spot: Marker3D in spots:
		if not is_instance_valid(spot) or not spot.is_inside_tree():
			continue
		if not unit.is_spot_taken(spot.global_transform, type_stats):
			return _spawn(player_index, spot.global_transform, type_stats)
	_is_blocked[player_index] = true
	return false


## True when the Unit, the Base, its spawn point or the camera of the Player was freed.
func _has_freed_node(player_index: int) -> bool:
	var base: Base = _bases[player_index]
	if not is_instance_valid(_units[player_index]) or not is_instance_valid(_cameras[player_index]):
		return true
	return not is_instance_valid(base) or not is_instance_valid(base.spawn_point)


## Pushes the due frame of every WAITING Player, and the settle and bench stamps of every Player
## stamped before the pause began, on by this many ticks: the time the controller did not run
## (class doc, the paragraph on pause). A blocked wait is left alone: its due frame is already
## reached, and must stay so for the first tick after the unpause to look for a free spot. A stamp
## taken during the pause (restart()'s benches) is later than the pause's frame and stays.
func _push_waits_on(ticks: int) -> void:
	for player_index: int in _state.size():
		if _state[player_index] == MatchController.State.WAITING and not _is_blocked[player_index]:
			_respawn_frame[player_index] += ticks
		if _settle_frame[player_index] <= _pause_frame:
			_settle_frame[player_index] += ticks
		if _bench_frame[player_index] <= _pause_frame:
			_bench_frame[player_index] += ticks


## The physics frame the waits are measured against: the frame the pause began while paused.
func _now() -> int:
	return _pause_frame if _is_paused else Engine.get_physics_frames()


## The respawn delay in physics ticks: the tuned seconds, read from the controller's rules export
## at the call, times the tick rate, rounded, and never less than one, so a destroyed Unit is
## always out of play for at least one tick.
func _delay_ticks() -> int:
	return maxi(roundi(_owner.rules.respawn_delay_seconds * float(Engine.physics_ticks_per_second)), 1)


## True for an index of a Player in this Round.
func _is_player(player_index: int) -> bool:
	return player_index >= 0 and player_index < _state.size()
