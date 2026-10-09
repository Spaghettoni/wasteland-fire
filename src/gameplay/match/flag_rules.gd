class_name FlagRules
extends RefCounted
## The Flag rules of one Round, as the MatchController applies them: who carries which
## Flag, which Player may pick a Flag up on this tick, and the calls down to the Flags
## (carry_by(), drop_at(), seat_at()). The controller owns one, decides when a Player may act at all
## (alive and settled after a spawn), runs the rules in order once per physics tick and emits every
## signal; this class emits none, is not a node and reads no input, so a test can drive it with
## stand-in Units and Bases and read back the answers.
##
## Implements: production/epics/wasteland-fire/story-013-turrets.md AC-5 (the other Player cannot
## take a Flag while a Structure of its Base whose data says locks_flag stands: a Turret, and the
## owner is never locked);
## production/epics/wasteland-fire/story-004-water-canister-and-win.md AC-2 (a Unit
## whose data says can_carry picks a Flag up by touching it; a Unit carries one Flag at a
## time; carrying is gated by the data flag, never by a type check), AC-3 (the Flag of a
## destroyed Carrier drops at the wreck), AC-4 (an owner may pick up its own dropped Flag and
## carry it home, where it is re-seated) and AC-5 (a delivery is the other Player's Flag in the
## own Base zone; the controller decides the win from is_in_own_zone() and carried_flag());
## design/rules.md "Resources" (the Flag and its handling). Vocabulary: CONTEXT.md (Player,
## Unit, Base, Flag, Carrier).
##
## Indexing. The Flag of Player N is Flag N: its index is its owner's Player index (0 is
## Player 1) and the index of its Base in the controller's arrays, so bases[N].flag is Player
## N's Flag and bases[N].flag_seat its seat.
##
## Who may pick a Flag up (AC-2, AC-4), tested by taker_of() for a Flag that is not carried,
## over the Players in index order: the controller says the Player may act, the Unit is alive, its
## data says can_carry, it carries nothing, the Flag's PickupZone reports the Unit touching it,
## and the Player is not the Flag's owner while the Flag stands at home (an owner picks up
## its own Flag only once it has been dropped). The first Player that qualifies is the taker, so
## two Players touching one Flag on one tick is decided by index, the lower wins. The owner
## gate and the carries-nothing gate are read here, the alive gate from the Unit, the touch from the
## Flag's zone: every answer is polled, nothing is remembered between ticks except who carries
## what, so a Flag lying where two Units stand is taken on the first tick a taker qualifies.
##
## The lock (Story 013 AC-5). A Player who is not the Flag's owner does not qualify while a
## Structure in the Flag's Base's structures list stands and its data says locks_flag: the Flag
## rules read that switch and name no class. It is tested before the touch query. The owner is never
## locked, so its own dropped Flag is taken wherever it lies. The lock lifts on the first tick the
## last such Structure has fallen: a Unit already touching the Flag takes it then. is_locked_out()
## answers the notice's question: would this Player's Unit take a Flag this tick but for the lock.
##
## The calls down. pick_up() hands the Flag to the Unit (Flag.carry_by()), drop()
## stands it where the Carrier is (drop_at(), at the Unit's global position: the wreck when
## `destroyed` fired), reseat() and seat_all() stand it on its Base's seat (seat_at()). pick_up(),
## reseat() and seat_all() run from the controller's physics tick, or from begin() before the
## first. drop() runs inside the Unit's `destroyed` emission and inherits its caller's context,
## which must be a tick and never a physics signal handler: drop_at() reparents a node that holds
## an Area3D, and the physics server refuses that while it flushes area and body signals (see
## Unit.apply_damage() and destroy()).

## The answer of carried_flag(), taker_of(), drop() and reseat() when there is no Flag.
const NONE: int = -1

var _units: Array[Unit] = []
var _bases: Array[Base] = []
## One entry per Player: the index of the Flag that Player's Unit carries, or NONE.
var _carried: Array[int] = []


## Keeps the controller's own Unit and Base arrays, one entry per Player in Player order (the same
## arrays begin() validated), by reference and not as copies: a Unit the controller replaces in its
## table (Story 005's Unit choice) is seen here with no second update path. Nobody carries anything
## yet.
func _init(units: Array[Unit], bases: Array[Base]) -> void:
	_units = units
	_bases = bases
	_carried.resize(_units.size())
	_carried.fill(NONE)


## The Flag of the given index: bases[flag_index].flag.
func flag(flag_index: int) -> Flag:
	return _bases[flag_index].flag


## The index of the Flag the Player's Unit carries, or NONE.
func carried_flag(player_index: int) -> int:
	return _carried[player_index]


## True while the Player's Unit carries a Flag that is not its own.
func is_carrying_enemy(player_index: int) -> bool:
	return _carried[player_index] != NONE and _carried[player_index] != player_index


## True while the Player's own Flag stands on its Base's seat (Flag.State.AT_HOME).
func is_own_at_home(player_index: int) -> bool:
	return flag(player_index).state == Flag.State.AT_HOME


## True while the Player's own Base zone reports that Player's Unit inside it, as the physics
## server last reported it (about two ticks behind the Unit's movement; see Base).
func is_in_own_zone(player_index: int) -> bool:
	return _bases[player_index].zone.overlaps_body(_units[player_index])


## The first Player, in index order, who may pick up the Flag of the given index on this tick
## (class doc), or NONE: when the Flag is carried, or nobody qualifies. may_act holds one flag
## per Player, true while the controller lets that Player act (alive and settled after a spawn).
func taker_of(flag_index: int, may_act: Array[bool]) -> int:
	var target: Flag = flag(flag_index)
	if target.state == Flag.State.CARRIED:
		return NONE
	for player_index: int in _units.size():
		if may_act[player_index] and _qualifies(player_index, target, flag_index):
			return player_index
	return NONE


## Hands the Flag to the Player's Unit: Flag.carry_by() and the bookkeeping. Call it
## with the answer of taker_of().
func pick_up(player_index: int, flag_index: int) -> void:
	flag(flag_index).carry_by(_units[player_index])
	_carried[player_index] = flag_index


## Stands the Flag the Player's Unit carries where the Unit is (the wreck, when called from the
## Unit's `destroyed`; AC-3) and forgets the carry. Returns that Flag's index, or NONE when
## the Unit carried nothing, and then nothing moved.
func drop(player_index: int) -> int:
	var flag_index: int = _carried[player_index]
	if flag_index == NONE:
		return NONE
	flag(flag_index).drop_at(_units[player_index].global_position)
	_carried[player_index] = NONE
	return flag_index


## Stands the Flag the Player's Unit carries on that Flag's Base's seat (its owner brought
## it home; AC-4) and forgets the carry. Returns that Flag's index, or NONE when the Unit
## carried nothing, and then nothing moved.
func reseat(player_index: int) -> int:
	var flag_index: int = _carried[player_index]
	if flag_index == NONE:
		return NONE
	_seat(flag_index)
	_carried[player_index] = NONE
	return flag_index


## Stands every Flag on its Base's seat, a carried one included (Flag.seat_at()
## reparents it home), and forgets every carry: the start of a Round and a restart.
func seat_all() -> void:
	for flag_index: int in _bases.size():
		_seat(flag_index)
	_carried.fill(NONE)


## True when the Player's Unit would take a Flag on this tick but for the lock (class doc): the
## Round lets the Player act, a Flag that is not carried and not its own lies within the Unit's
## touch, the Unit may carry and carries nothing, and a standing Structure of that Flag's Base locks
## it. False for a Unit that already carries a Flag, which could not take a second one anyway.
func is_locked_out(player_index: int, may_act: Array[bool]) -> bool:
	if not may_act[player_index]:
		return false
	for flag_index: int in _bases.size():
		var target: Flag = flag(flag_index)
		if target.state != Flag.State.CARRIED and _is_locked_for(player_index, flag_index) \
				and _qualifies(player_index, target, flag_index, false):
			return true
	return false


## The pick-up test of one Player for one Flag that is not carried (class doc), cheapest
## checks first and the physics query last. honour_lock false skips the lock, for is_locked_out().
func _qualifies(player_index: int, target: Flag, flag_index: int, honour_lock: bool = true) -> bool:
	if _carried[player_index] != NONE:
		return false
	var unit: Unit = _units[player_index]
	if not unit.is_alive or not unit.can_carry:
		return false
	if player_index == flag_index and target.state == Flag.State.AT_HOME:
		return false
	if honour_lock and _is_locked_for(player_index, flag_index):
		return false
	return target.is_touching(unit)


## True when the Player is not the Flag's owner and a Structure of the Flag's Base stands whose data
## says locks_flag (class doc).
func _is_locked_for(player_index: int, flag_index: int) -> bool:
	if player_index == flag_index:
		return false
	for structure: Structure in _bases[flag_index].structures:
		if structure != null and structure.is_standing and structure.locks_flag:
			return true
	return false


func _seat(flag_index: int) -> void:
	flag(flag_index).seat_at(_bases[flag_index].flag_seat.global_transform)
