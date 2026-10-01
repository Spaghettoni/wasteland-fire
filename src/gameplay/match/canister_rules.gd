class_name CanisterRules
extends RefCounted
## The Water Canister rules of one Round, as the MatchController applies them: who carries which
## canister, which Player may pick a canister up on this tick, and the calls down to the canisters
## (carry_by(), drop_at(), seat_at()). The controller owns one, decides when a Player may act at all
## (alive and settled after a spawn), runs the rules in order once per physics tick and emits every
## signal; this class emits none, is not a node and reads no input, so a test can drive it with
## stand-in Units and Bases and read back the answers.
##
## Implements: production/epics/wasteland-fire/story-004-water-canister-and-win.md AC-2 (a Unit
## whose data says can_carry picks a canister up by touching it; a Unit carries one canister at a
## time; carrying is gated by the data flag, never by a type check), AC-3 (the canister of a
## destroyed Carrier drops at the wreck), AC-4 (an owner may pick up its own dropped canister and
## carry it home, where it is re-seated) and AC-5 (a delivery is the other Player's canister in the
## own Base zone; the controller decides the win from is_in_own_zone() and carried_canister());
## design/rules.md "Resources" and "Handling the Water Canister". Vocabulary: CONTEXT.md (Player,
## Unit, Base, Water Canister, Carrier).
##
## Indexing. The canister of Player N is canister N: its index is its owner's Player index (0 is
## Player 1) and the index of its Base in the controller's arrays, so bases[N].canister is Player
## N's canister and bases[N].canister_seat its seat.
##
## Who may pick a canister up (AC-2, AC-4), tested by taker_of() for a canister that is not carried,
## over the Players in index order: the controller says the Player may act, the Unit is alive, its
## data says can_carry, it carries nothing, the canister's PickupZone reports the Unit touching it,
## and the Player is not the canister's owner while the canister stands at home (an owner picks up
## its own canister only once it has been dropped). The first Player that qualifies is the taker, so
## two Players touching one canister on one tick is decided by index, the lower wins. The owner
## gate and the carries-nothing gate are read here, the alive gate from the Unit, the touch from the
## canister's zone: every answer is polled, nothing is remembered between ticks except who carries
## what, so a canister lying where two Units stand is taken on the first tick a taker qualifies.
##
## The calls down. pick_up() hands the canister to the Unit (WaterCanister.carry_by()), drop()
## stands it where the Carrier is (drop_at(), at the Unit's global position: the wreck when
## `destroyed` fired), reseat() and seat_all() stand it on its Base's seat (seat_at()). pick_up(),
## reseat() and seat_all() run from the controller's physics tick, or from begin() before the
## first. drop() runs inside the Unit's `destroyed` emission and inherits its caller's context,
## which must be a tick and never a physics signal handler: drop_at() reparents a node that holds
## an Area3D, and the physics server refuses that while it flushes area and body signals (see
## Unit.apply_damage() and destroy()).

## The answer of carried_canister(), taker_of(), drop() and reseat() when there is no canister.
const NONE: int = -1

var _units: Array[Unit] = []
var _bases: Array[Base] = []
## One entry per Player: the index of the canister that Player's Unit carries, or NONE.
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


## The canister of the given index: bases[canister_index].canister.
func canister(canister_index: int) -> WaterCanister:
	return _bases[canister_index].canister


## The index of the canister the Player's Unit carries, or NONE.
func carried_canister(player_index: int) -> int:
	return _carried[player_index]


## True while the Player's Unit carries a canister that is not its own.
func is_carrying_enemy(player_index: int) -> bool:
	return _carried[player_index] != NONE and _carried[player_index] != player_index


## True while the Player's own canister stands on its Base's seat (WaterCanister.State.AT_HOME).
func is_own_at_home(player_index: int) -> bool:
	return canister(player_index).state == WaterCanister.State.AT_HOME


## True while the Player's own Base zone reports that Player's Unit inside it, as the physics
## server last reported it (about two ticks behind the Unit's movement; see Base).
func is_in_own_zone(player_index: int) -> bool:
	return _bases[player_index].zone.overlaps_body(_units[player_index])


## The first Player, in index order, who may pick up the canister of the given index on this tick
## (class doc), or NONE: when the canister is carried, or nobody qualifies. may_act holds one flag
## per Player, true while the controller lets that Player act (alive and settled after a spawn).
func taker_of(canister_index: int, may_act: Array[bool]) -> int:
	var target: WaterCanister = canister(canister_index)
	if target.state == WaterCanister.State.CARRIED:
		return NONE
	for player_index: int in _units.size():
		if may_act[player_index] and _qualifies(player_index, target, canister_index):
			return player_index
	return NONE


## Hands the canister to the Player's Unit: WaterCanister.carry_by() and the bookkeeping. Call it
## with the answer of taker_of().
func pick_up(player_index: int, canister_index: int) -> void:
	canister(canister_index).carry_by(_units[player_index])
	_carried[player_index] = canister_index


## Stands the canister the Player's Unit carries where the Unit is (the wreck, when called from the
## Unit's `destroyed`; AC-3) and forgets the carry. Returns that canister's index, or NONE when
## the Unit carried nothing, and then nothing moved.
func drop(player_index: int) -> int:
	var canister_index: int = _carried[player_index]
	if canister_index == NONE:
		return NONE
	canister(canister_index).drop_at(_units[player_index].global_position)
	_carried[player_index] = NONE
	return canister_index


## Stands the canister the Player's Unit carries on that canister's Base's seat (its owner brought
## it home; AC-4) and forgets the carry. Returns that canister's index, or NONE when the Unit
## carried nothing, and then nothing moved.
func reseat(player_index: int) -> int:
	var canister_index: int = _carried[player_index]
	if canister_index == NONE:
		return NONE
	_seat(canister_index)
	_carried[player_index] = NONE
	return canister_index


## Stands every canister on its Base's seat, a carried one included (WaterCanister.seat_at()
## reparents it home), and forgets every carry: the start of a Round and a restart.
func seat_all() -> void:
	for canister_index: int in _bases.size():
		_seat(canister_index)
	_carried.fill(NONE)


## The pick-up test of one Player for one canister that is not carried (class doc), cheapest
## checks first and the physics query last.
func _qualifies(player_index: int, target: WaterCanister, canister_index: int) -> bool:
	if _carried[player_index] != NONE:
		return false
	var unit: Unit = _units[player_index]
	if not unit.is_alive or not unit.can_carry:
		return false
	if player_index == canister_index and target.state == WaterCanister.State.AT_HOME:
		return false
	return target.is_touching(unit)


func _seat(canister_index: int) -> void:
	canister(canister_index).seat_at(_bases[canister_index].canister_seat.global_transform)
