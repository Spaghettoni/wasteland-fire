class_name MatchController
extends Node
## Owns the state of one Round: whose Unit is alive, who is choosing the next Unit type and who
## waits to respawn and when, who carries which Flag, how many Tokens of each Unit type each Player
## has left, and whether the Round still runs or has ended. It benches each Player's Unit on that
## Player's Base at the start of the Round and at a restart while the Player chooses a type, puts
## the chosen type on the Base once the choice is made and the delay has passed, seats each Base's
## Flag, takes a Token at every destruction, applies the Flag rules and the loss once per physics
## tick, and freezes the game when a delivery or a loss ends the Round, until restart().
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-1, AC-3,
## AC-4 and AC-7; production/epics/wasteland-fire/story-004-water-canister-and-win.md AC-2, AC-3,
## AC-4, AC-5 and AC-6; production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-6
## (at every spawn, the start of the Round, after a destruction and after a restart, the Player
## chooses the Unit type before the Unit appears; at the start it appears as soon as it is chosen,
## after a destruction once it is chosen and the delay has passed, whichever is later, and the
## other Player plays on meanwhile);
## production/epics/wasteland-fire/story-008-tokens-garage-and-loss.md AC-1 to AC-5 and AC-9 (the
## Map's Token stock, a Token per destruction, the choice from the Tokens left, the loss of the last
## Motorbike and the double loss; every count is data); design/game-brief.md MVP features 3 (Bases,
## destruction and respawn), 4 (Flag and the win), 5 (the four Units) and 8 (Tokens, the Garage and
## the loss); design/rules.md "Tokens and the Garage", "Destruction and respawn" and "Resources".
## Vocabulary: CONTEXT.md (Player, Unit, Base, Garage, Round, Flag, Carrier, Token).
## The node and its rules resource keep the names the story gave them (MatchController, MatchRules;
## Story 003 AC-7); in prose the thing they serve is the Round, as CONTEXT.md has it. Story 008 gave
## the objective its own name in code, the Flag (Flag, FlagRules, flag_*), where Story 004 built it
## as the Water Canister.
##
## Signals up, calls down. A Unit emits `destroyed` and nothing else: it never calls this
## controller, the other Unit, a Flag or a singleton. The controller listens, then calls down:
## it asks the Unit to leave_play() and spawn(), the camera to snap_to_target() and a Flag to
## carry_by(), drop_at() or seat_at() (through FlagRules, which keeps who carries what).
## Everything it touches is handed to it once, by begin() (dependency injection: no node path, no
## autoload, no static state), so a test can build one from stand-in Units, Bases and cameras
## without the split-screen scene. Player index 0 is Player 1. The Flag of Player N is
## Flag N: its index is its owner's Player index and the index of its Base in begin()'s arrays,
## and that index is what the Flag signals carry. A type index is an index into
## rules.unit_types, the order of the data (unit_types()); Tokens are counted by the type's
## UnitStats.type_id, not by that index (TokenLedger).
##
## It knows nothing about the screen. A HUD node listens to round_started, unit_destroyed,
## unit_spawned and the Flag signals and asks seconds_until_respawn(), flag_status(), tokens_left()
## and carrier_type_index(); the choice panel listens to round_started, unit_destroyed,
## unit_chosen, unit_spawned and round_over and asks is_choosing(), chosen_type_index(),
## unit_types() and tokens_left(); the Round-over screen listens to round_over and round_started;
## this script references no UI class, draws nothing and holds no text, so the display can
## change, or go, without touching the Round. It reads no input either: what a key
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
## flag_dropped and unit_destroyed for every destruction it counted. Moved there in Story 005
## (docs/tech-debt-register.md TD-008) with no change of behaviour, then given the choice.
##
## Tokens and the loss (Story 008). The Token stock lives in a TokenLedger (token_ledger.gd), whose
## class doc keeps the state table of a count. begin() copies the Map's TokenStock into it per
## Player and per type, and refuses the Round when the stock cannot be used; restart() copies it
## again, both before round_started; _on_unit_destroyed() takes one Token of the destroyed Unit's
## type before any signal goes out; choose() refuses a type with no Token left. A Player loses in
## the tick in which it has no Token left of the type that can carry the Flag, the Motorbike in the
## data (_apply_losses(), after the deliveries): the other Player wins, and when both have none by
## that tick it is a double loss and nobody wins.
##
## The order of a physics frame, which the loss relies on. The loss is decided in this node's tick,
## so every way a Unit is destroyed must run earlier in the same physics frame. Measured on Godot
## 4.7.2 with Jolt (Story 008's engine preflight, with the launch scene's nodes), a frame runs
## PlayerDriveInput, PlayerMatchInput and PlayerChoiceInput at priority -1; then, at the default
## priority 0 and in tree order, the Map's nodes, the Fuel Cans, the Units, PlayerFireInput, the
## Shots (children of World, which comes before this node), this node and RoundRestartInput; then
## the Weapons at +1. A Self-destruct calls Unit.destroy() in PlayerMatchInput's tick; a Shot's kill
## and a Gyrocopter's Fuel crash happen in the Shot's and the Unit's own ticks (a Shot fired in one
## frame first moves in the next); and `destroyed` reaches _on_unit_destroyed() synchronously inside
## that tick. So two Self-destructs in one frame, or a Self-destruct with a lethal Shot, are all
## seen by this node's tick of that frame: one double loss. RoundRestartInput (process mode ALWAYS,
## it only calls restart()) and the Weapons come after this node and destroy nothing. Once this tick
## pauses the tree no pausable node later in the frame ticks (measured with pausable nodes at +5 and
## last in the tree), so a destruction a frame later is not a double loss: the Round is over
## already. The guarantee is the default priority and the position in the tree (World before this
## node), not a priority declared here: a source of destruction moved behind this node, or given a
## priority above 0, would split a double loss over two frames.
##
## Round state, one for the whole Round (RoundState). The table is complete:
##   RUNNING -> OVER     a Player's Unit carrying the other Player's Flag was reported inside
##                       its own Base zone: that Player wins; the tree is paused at the end of that
##                       tick, then emit round_over(winner)
##   RUNNING -> OVER     the loss: after the deliveries found none, exactly one Player has no
##                       Token left of the carrier type: the other Player wins; the tree is paused
##                       at the end of that tick, then emit round_over(winner)
##   RUNNING -> OVER     the double loss: both Players have none by that tick: nobody wins
##                       (winner_index() is NO_WINNER, is_round_over() true); the tree is paused
##                       at the end of that tick, then emit round_over(NO_WINNER)
##   OVER    -> RUNNING  restart(): every Flag seated, every Unit benched on its Base with its
##                       Player choosing, both Token stocks full again, the tree unpaused, emit
##                       round_started
##   RUNNING -> RUNNING  everything else: a destruction (also one that spends the last Token of a
##                       type but the carrier's), a choice, a spawn, a pick-up, a drop, an owner's
##                       re-seat, a Unit in its own Base empty-handed, both Players choosing or
##                       waiting at once
## begin() starts RUNNING and emits round_started after the benches, the seating and the full
## stocks, with both Players choosing and no Unit in play; restart() while RUNNING is refused with
## a warning. Only a delivery or a loss ends a Round (Story 008 AC-5): a type that runs out, or a
## Self-destruct or a Fuel crash that does not spend the last Token of the carrier type, end
## nothing. A delivery of the tick is applied first and the loss is looked for only while the Round
## still runs, so the delivery decides.

## A Player's Unit left play, and that Player now chooses the next type and waits out the respawn
## delay, whichever ends later. The wait is already stamped and the previous choice cleared when
## this fires, so seconds_until_respawn(player_index) is the full delay in a handler,
## is_alive(player_index) is false and is_choosing(player_index) is true. Player 1 is index 0. When
## the Unit carried a Flag, flag_dropped went out just before this. The Unit's Token is already
## taken, so tokens_left() reads the new count in a handler; the Round is not over yet even for the
## Player's last Motorbike, because the loss is decided by this controller's tick of the same frame
## (class doc), and round_over follows it.
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
## Players choosing a type, and every Flag stands on its Base's seat. Emitted by begin() after
## its benches and by restart() after the unpause, so is_round_over() is false and is_choosing() is
## true for every Player in a handler, and both Token stocks are full: tokens_left() reads the
## Map's counts. A HUD refreshes its Flag status and its Token count on it; the Round-over screen
## hides; the choice panel shows.
signal round_started

## The Round ended (Story 004 AC-5, Story 008 AC-4): a delivery won it (the Unit of winner_index
## carried the other Player's Flag into its own Base zone), a loss ended it (the other Player's last
## Motorbike was destroyed and winner_index is the Player who still has one), or both Players lost
## their last Motorbike by that tick and winner_index is NO_WINNER. The tree is already paused when
## this fires and stays so until restart(); is_round_over() is true and winner_index() is this value
## in a handler. Test is_round_over() before reading NO_WINNER as "nobody won".
signal round_over(winner_index: int)

## The Unit of carrier_index picked up the Flag of flag_index (its owner's Player index) by
## touching it (AC-2). The Flag already rides on the Unit when this fires.
signal flag_picked_up(carrier_index: int, flag_index: int)

## The Flag of flag_index dropped at its Carrier's wreck: the Carrier was destroyed (AC-3).
## It lies there until a Unit picks it up or the Round restarts; nothing moves it home on its own.
signal flag_dropped(flag_index: int)

## The Flag of flag_index stands on its Base's seat again: its owner carried it into the
## own Base (AC-4). Not emitted by begin() or restart(), which announce their seating with
## round_started.
signal flag_seated(flag_index: int)

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

## Whether the Round is still played or has ended; one for the whole Round. The transitions are in
## the class doc.
enum RoundState {
	## Before begin(), and from begin() or restart() until a delivery or a loss ends it.
	RUNNING,
	## A delivery won, or a loss ended it (one Player's last Motorbike, or both Players'): the tree
	## is paused, winner_index() names the winner or is NO_WINNER after the double loss, and only
	## restart() leaves this state.
	OVER,
}

## What a Player's HUD shows about the Flags (Story 004 AC-7), the answer of flag_status().
enum FlagStatus {
	## The Player's own Flag stands on its Base's seat, and the Player carries nothing foreign.
	OWN_AT_HOME,
	## The Player's own Flag is away: stolen, lying dropped, or on its way home on its owner's
	## Unit; and the Player carries nothing foreign.
	OWN_AWAY,
	## The Player's Unit carries the other Player's Flag.
	CARRYING_ENEMY,
}

## The answer of winner_index() while nobody has won: while the Round runs, before begin(), and
## after a double loss (is_round_over() tells the last from the first two).
const NO_WINNER: int = -1

## The answer of chosen_type_index() while the Player has not chosen.
const NO_CHOICE: int = GarageQueue.NO_CHOICE

## Physics ticks after a spawn during which the Player's pick-ups and deliveries are skipped, and
## after a bench before which no spawn is made; GarageQueue holds the value and the reasons.
const SPAWN_SETTLE_TICKS: int = GarageQueue.SPAWN_SETTLE_TICKS

## The tuning values (a MatchRules .tres, for example match_rules.tres): rules.respawn_delay_seconds
## is the wait between a destruction and the respawn (Story 003 AC-3), rules.unit_types the types a
## Player chooses from, in the order of the choice (Story 005 AC-6), which the Map's Token stock
## counts by type_id (Story 008). Required: begin() refuses to start the Round without it, while
## the delay is not above zero, while unit_types is empty or while one of its entries is unusable
## (UnitStats.first_problem()). The resource is shared, so never write to it at runtime.
@export var rules: MatchRules

var _units: Array[Unit] = []
var _bases: Array[Base] = []
var _cameras: Array[ChaseCamera] = []
## The per-Player state, the choice, the waits and the spawn path (class doc). Enlisted by
## begin(); before that it holds no Player, and only its pause bookkeeping runs.
var _garage: GarageQueue = GarageQueue.new()
## Who carries which Flag, and the calls down to the Flags. Built by begin().
var _flags: FlagRules = null
## The Tokens each Player has left per Unit type, and who has lost (class doc). Started by begin()
## and restart(), before round_started; before begin() it holds no Player.
var _ledger: TokenLedger = TokenLedger.new()
## The Map's Token stock that begin() was given, kept for restart(); this node only reads it.
var _token_stock: TokenStock = null
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
## while the Round runs, the Flag rules in their order (pick-ups, then deliveries), the loss (only
## while no delivery ended the Round in this tick) and, when the Round ended, the pause of the tree
## and the winner. The wait and the settle rules are counted in physics ticks, not in delta: see
## GarageQueue. Where this tick sits in the physics frame is in the class doc.
func _physics_process(_delta: float) -> void:
	for player_index: int in _garage.tick():
		unit_spawned.emit(player_index)
	if _round_state != RoundState.RUNNING or _flags == null:
		return
	var may_act: Array[bool] = _garage.may_act()
	_apply_pick_ups(may_act)
	_apply_deliveries(may_act)
	if _round_state == RoundState.RUNNING:
		_apply_losses()
	if _round_state == RoundState.OVER:
		get_tree().paused = true
		round_over.emit(_winner)


## Starts the Round: puts every Player's Unit on that Player's Base and benches it there, out of
## play, with the Player choosing a type (Story 005 AC-6; the Unit appears by the one spawn path
## once chosen: Story 003 AC-1), seats every Flag on its Base's seat (Story 004 AC-1), emits
## round_started, and from then on listens for the Units' destroyed signals; it spawns nobody and
## emits no unit_spawned. Call it once, from the composition root (SplitScreen), with the Units,
## Bases and cameras already in the tree. The three arrays hold one entry per Player, in the same
## order, Player 1 first: the Unit that Player drives, the Base it starts and respawns at, which
## also holds that Player's Flag and its seat, and the camera that chases that Unit. The
## token_stock is the Map's (MapField.token_stock): begin() copies its counts into the Round's own
## ledger and never writes to it (Story 008 AC-1). When anything is wrong (rules missing, a delay
## not above zero, no unit_types or one that is unusable, no Players, arrays of different sizes, an
## entry that is null or not in the tree, a Base without a spawn point, a Flag or a Flag seat, or
## with a spawn point off its pad, or a Token stock that cannot be used: TokenLedger.first_problem()
## says which) it pushes one error naming the problem and does nothing: no bench, no connection, no
## signal, no state, and a later call with good arguments begins the Round. A second call after a
## successful one is refused the same way. A Unit that cannot be put in play (it refused to drive in
## _ready()) is benched like any other; the spawn after its Player's first choice pushes an error
## and leaves only that Player out of the Round.
func begin(units: Array[Unit], bases: Array[Base], cameras: Array[ChaseCamera], token_stock: TokenStock) -> void:
	if _has_begun:
		push_error("MatchController '%s': begin() was called twice. A Round begins once." % name)
		return
	var problem: String = _first_problem(units, bases, cameras, token_stock)
	if not problem.is_empty():
		push_error("MatchController '%s': %s, so the Round does not begin." % [name, problem])
		return
	_has_begun = true
	_token_stock = token_stock
	_units.assign(units)
	_bases.assign(bases)
	_cameras.assign(cameras)
	_garage.enlist(self, _units, _bases, _cameras)
	_flags = FlagRules.new(_units, _bases)
	_round_state = RoundState.RUNNING
	_winner = NO_WINNER
	_start_ledger()
	for player_index: int in _units.size():
		_units[player_index].destroyed.connect(_on_unit_destroyed.bind(player_index))
	for player_index: int in _units.size():
		_garage.bench(player_index)
	_flags.seat_all()
	round_started.emit()


## Starts the Round again after a win or a loss (Story 004 AC-6, Story 008 AC-7): every Flag is
## seated on its Base's seat (a carried one goes home), every Player's Unit is put on its Base's
## spawn point and benched there with the Player choosing a type again (a pending wait and a
## standing choice are cancelled; the Unit appears, at the full hit points of the chosen type, once
## chosen: Story 005 AC-6), the Round is RUNNING, both Token stocks are copied from the Map's again,
## the tree is unpaused and round_started goes out, in that order, so its listeners read full
## counts; no unit_spawned goes out here, and a bench or a restart costs no Token. Only while the
## Round is over: a call while it runs pushes a warning and does nothing.
func restart() -> void:
	if _round_state != RoundState.OVER:
		push_warning("MatchController '%s': restart() was called while the Round is running, so nothing happens. It restarts a Round that is over." % name)
		return
	_flags.seat_all()
	for player_index: int in _units.size():
		_garage.bench(player_index)
	_round_state = RoundState.RUNNING
	_winner = NO_WINNER
	_start_ledger()
	get_tree().paused = false
	round_started.emit()


## The Player chooses the type at type_index (into unit_types()) for its next Unit (Story 005
## AC-6). True when accepted: the Round has begun and runs, type_index is an index of
## rules.unit_types, the Player has a Token left of that type (can_choose(); Story 008 AC-3, and
## the one guard of it, so no key and no panel can spawn a type that has none), and the Player is
## WAITING and has not chosen since its last spawn, bench or destruction; then unit_chosen goes
## out and the Unit appears by the one spawn path once the delay has passed, the bench has settled
## and a spot is free (at once at the start of the Round and after a restart). Otherwise false,
## nothing changes and no signal goes out: a Player in play, a second choice, a Round that is over
## or has not begun, an index outside the data, a type with no Token left.
func choose(player_index: int, type_index: int) -> bool:
	if not _has_begun or _round_state != RoundState.RUNNING:
		return false
	if type_index < 0 or type_index >= rules.unit_types.size():
		return false
	if not can_choose(player_index, type_index):
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


## The Tokens the Player has left of the Unit type at type_index (into unit_types()): that Player's
## count of the type's type_id. The Unit in play is still counted, because a Token is taken at the
## destruction and never at the spawn: with five Motorbike Tokens it reads 5 while the first
## Motorbike drives and 4 once that one is destroyed. Read-only, no signal, and safe to call from a
## handler of unit_destroyed (the Token of that destruction is already taken) and of round_started
## (the stocks are full). 0 for a player_index that is not in the Round, for a type_index outside
## unit_types(), before begin() and after a refused begin().
func tokens_left(player_index: int, type_index: int) -> int:
	var types: Array[UnitStats] = unit_types()
	if not _is_player(player_index) or type_index < 0 or type_index >= types.size():
		return 0
	var stats: UnitStats = types[type_index]
	return _ledger.count_of(player_index, stats.type_id) if stats != null else 0


## True when the Player has a Token left of the Unit type at type_index: tokens_left() is above 0,
## and nothing else. It does not look at the Round or at the Player's state (choose() does, and
## refuses a type for which this is false), so a choice panel can ask it which types may be picked.
## Read-only, no signal, safe in any handler, with the bounds of tokens_left().
func can_choose(player_index: int, type_index: int) -> bool:
	return tokens_left(player_index, type_index) > 0


## The index into unit_types() of the one Unit type that can carry the Flag, the Motorbike in the
## data and the type whose last Token loses the Round, or -1 before a successful begin(), after a
## refused one, and when the types read now hold no type of that id. Test it for -1 before using it:
## GDScript reads a negative index from the end of an array, so unit_types()[-1] is the last type
## and not an error. Read-only, no signal, safe in any handler.
func carrier_type_index() -> int:
	var carrier_id: StringName = _ledger.carrier_type_id()
	if not _has_begun or carrier_id.is_empty():
		return -1
	var types: Array[UnitStats] = unit_types()
	for type_index: int in types.size():
		if types[type_index] != null and types[type_index].type_id == carrier_id:
			return type_index
	return -1


## True while the Player's Unit is in play. False while it chooses or waits to respawn, before
## begin(), and for a player_index that is not in the Round.
func is_alive(player_index: int) -> bool:
	return _garage.is_alive(player_index)


## True from the tick a delivery or a loss ended the Round until restart(). False before begin().
func is_round_over() -> bool:
	return _round_state == RoundState.OVER


## The Player index that won the Round (0 is Player 1), or NO_WINNER (-1), which means two things:
## the Round runs (or has not begun) and nobody has won yet, or it ended with no winner, the double
## loss. Only is_round_over() tells them apart, so a listener tests it first and reads this only
## when it is true; round_over carries the same value. There is no second sentinel.
func winner_index() -> int:
	return _winner


## What the Player's HUD shows about the Flags, a FlagStatus value: CARRYING_ENEMY while
## that Player's Unit carries a Flag that is not its own; else OWN_AT_HOME while the Player's
## own Flag stands on its seat; else OWN_AWAY (stolen, lying dropped, or on its way home on its
## owner's Unit). OWN_AT_HOME before begin() and for a player_index not in the Round: what a Round
## shows at its start. Ask it when flag_picked_up, flag_dropped, flag_seated or
## round_started arrives: every change of the answer is announced by one of them.
func flag_status(player_index: int) -> int:
	if not _is_player(player_index) or _flags == null:
		return FlagStatus.OWN_AT_HOME
	if _flags.is_carrying_enemy(player_index):
		return FlagStatus.CARRYING_ENEMY
	if _flags.is_own_at_home(player_index):
		return FlagStatus.OWN_AT_HOME
	return FlagStatus.OWN_AWAY


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


## Rule (1) of the tick: each Flag that is not carried goes to the first Player who qualifies
## (FlagRules.taker_of(); class doc), and the pick-up is announced.
func _apply_pick_ups(may_act: Array[bool]) -> void:
	for flag_index: int in _bases.size():
		var taker: int = _flags.taker_of(flag_index, may_act)
		if taker != FlagRules.NONE:
			_flags.pick_up(taker, flag_index)
			flag_picked_up.emit(taker, flag_index)


## Rule (2) of the tick: a Player who may act, carries a Flag and is reported inside its own
## Base zone either wins (the other Player's Flag: the Round is OVER, announced by
## _physics_process after the pause) or brings its own Flag home (re-seated, announced here).
## Two deliveries on one tick: the lower Player index wins, as for pick-ups; the loop stops at the
## first win, so the other Player's delivery is not applied.
func _apply_deliveries(may_act: Array[bool]) -> void:
	for player_index: int in _units.size():
		var flag_index: int = _flags.carried_flag(player_index)
		if flag_index == FlagRules.NONE or not may_act[player_index]:
			continue
		if not _flags.is_in_own_zone(player_index):
			continue
		if flag_index == player_index:
			_flags.reseat(player_index)
			flag_seated.emit(flag_index)
		else:
			_round_state = RoundState.OVER
			_winner = player_index
			return


## The loss check of the tick (Story 008 AC-4), run after the deliveries and only while the Round is
## still RUNNING: a Player with no Token left of the carrier type has lost (TokenLedger.has_lost()).
## When exactly one Player has not lost, the Round is OVER with that Player as the winner; when both
## have lost, OVER with NO_WINNER (the double loss); when nobody has, nothing happens. Announced by
## _physics_process after the pause, like a delivery. It reads the ledger as the tick finds it, so
## every destruction earlier in the frame is in it (the class doc, on the order of a physics frame).
func _apply_losses() -> void:
	var lost: int = 0
	var survivor: int = NO_WINNER
	for player_index: int in _units.size():
		if _ledger.has_lost(player_index):
			lost += 1
		else:
			survivor = player_index
	if lost == 0:
		return
	_round_state = RoundState.OVER
	_winner = survivor if lost == _units.size() - 1 else NO_WINNER


## Copies the Map's Token stock into the ledger for every Player and every type the rules hold now:
## begin() and restart(), before round_started in both.
func _start_ledger() -> void:
	_ledger.start(_token_stock, unit_types(), _units.size())


## True for an index of a Player in this Round.
func _is_player(player_index: int) -> bool:
	return player_index >= 0 and player_index < _units.size()


## What is wrong with the arguments of begin() and the rules, as a sentence, or an empty string
## when there is nothing wrong. The Token stock is checked last, against the types the rules hold.
func _first_problem(units: Array[Unit], bases: Array[Base], cameras: Array[ChaseCamera], token_stock: TokenStock) -> String:
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
	return TokenLedger.first_problem(token_stock, rules.unit_types)


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
	var flag_problem: String = _first_flag_problem(bases[player_index], player_index)
	if not flag_problem.is_empty():
		return flag_problem
	if not is_instance_valid(cameras[player_index]):
		return "cameras[%d] is null" % player_index
	return ""


## What is wrong with a Base's Flag and Flag seat (Story 004: begin() reads both), or an
## empty string.
func _first_flag_problem(base: Base, player_index: int) -> String:
	if not is_instance_valid(base.flag):
		return "bases[%d].flag is not assigned" % player_index
	if not base.flag.is_inside_tree():
		return "bases[%d].flag is not in the tree" % player_index
	if not is_instance_valid(base.flag_seat):
		return "bases[%d].flag_seat is not assigned" % player_index
	if not base.flag_seat.is_inside_tree():
		return "bases[%d].flag_seat is not in the tree" % player_index
	return ""


## A Unit left play: the garage queue stamps the frame at which its Player may respawn and clears
## the Player's choice (the next type is chosen anew, Story 005 AC-6), or refuses with a warning
## when that Player was not ALIVE, and then nothing happens; the Flag it carried drops at the wreck
## (rule (3); AC-3), one Token of its type is taken (Story 008 AC-2), then the listeners are told.
## The state, the stamp and the Token are set before the signals go out, so a handler already sees
## the Player waiting with the full delay and choosing, and the new count, and flag_dropped goes out
## before unit_destroyed. The Token is the destroyed Unit's own type's, read from the type_id of its
## stats; a Unit without stats, or of a type the Round does not count, takes none: one warning from
## the ledger, and never a loss. The handler does not look at the Round state: a Unit destroyed
## while the Round is OVER (nothing in the game does it: only nodes that run through the pause
## could, and none destroys anything) still costs its Token and is still announced, and the result
## stays what it was, because the loss is looked for in the tick of a RUNNING Round only; restart()
## refills.
func _on_unit_destroyed(player_index: int) -> void:
	if not _garage.note_destroyed(player_index):
		return
	var dropped: int = _flags.drop(player_index)
	var stats: UnitStats = _units[player_index].stats
	_ledger.take(player_index, stats.type_id if stats != null else &"")
	if dropped != FlagRules.NONE:
		flag_dropped.emit(dropped)
	unit_destroyed.emit(player_index)
