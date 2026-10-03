class_name TokenLedger
extends RefCounted
## The Token stock of one Round, as the MatchController keeps it: how many Tokens of each Unit type
## each Player has left, copied from the Map's stock when the Round starts, one Token taken for
## every destruction, and the answer to whether a Player has lost, which is when that Player has no
## Token left of the one type that can carry the Flag. The controller owns one, starts it in begin()
## and again in restart(), takes a Token in its `destroyed` handler, asks has_lost() once per
## physics tick and emits every signal; this class emits none, is not a node and reads no input, so
## a test can drive it with a stock and a list of types and read back the answers. It is a class of
## its own and not more lines in the controller because Story 008's Implementation Notes
## (docs/tech-debt-register.md TD-008) send the stock and the loss to a small helper beside
## FlagRules; the controller still grows by the three queries, the loss check and their docs.
##
## Implements: production/epics/wasteland-fire/story-008-tokens-garage-and-loss.md AC-1 (each
## Player starts the Round with one count per Unit type, copied from the Map's data; a stock that
## gives no Token to the type that carries the Flag is refused with a sentence that names it),
## AC-2 (a destroyed Unit costs one Token of its own type, taken at the destruction), AC-4 (the
## loss: a Player with no Token left of that type) and AC-9 (no count is written here: every
## number comes from the stock); design/rules.md "Tokens and the Garage" and "Destruction and
## respawn". Vocabulary: CONTEXT.md (Token, Player, Unit, Round, Flag, Map).
##
## The count of one type for one Player. The table is complete; a pair it does not list cannot
## happen.
##   (none) -> n     start(): at begin() and again at restart(), the stock's count of the type
##                   is copied by value, for every Player and every type of the Round, so both
##                   Players start from the Map's numbers and nothing of the Round before is left
##                   (n is never below 0)
##   n      -> n - 1 take(): one Token is taken when a Unit of the type is destroyed, never when
##                   one is spawned, so the Unit in play is not yet subtracted (n is at least 1)
##   0      -> 0     take(): refused with one warning; a count never goes below 0
##   n      -> n     everything else: a choice, a spawn, a bench, a pause, the end of the Round
## A Player has lost when its count of the carrier type, the one type whose UnitStats.can_carry is
## true, is 0 (has_lost()): the destruction of its last Motorbike in the data. The controller asks
## once per physics tick, after the deliveries. Nothing else counts as a loss: a type that runs
## out, or a Unit of a type this ledger does not count, changes no Player's standing.
##
## Keyed by type id. A count is kept per UnitStats.type_id (&"motorbike", ...), the key the stock
## uses, and not per index into the controller's unit_types: the controller's rules can be
## replaced while it runs (the destruction scenario puts a copy in), and a type's Tokens follow
## the type whatever the order or the length of the list it reads at that moment.
##
## A copy, never the stock. start() writes each count by value, one assignment per key, into a
## Dictionary of the ledger's own for each Player, and keeps no reference to the stock or to
## stock.counts. A Dictionary is a reference, so keeping stock.counts would write every Token
## taken through to the .tres, which every Round loads again; and Resource.duplicate() does not
## make the copy either, because it shares the counts dictionary with the original (measured on
## Godot 4.7.2 in Story 008's engine preflight; duplicate_deep() and a new TokenStock do not).

## The id (UnitStats.type_id) of the one type that can carry the Flag, whose count decides the
## loss. Empty before start(), and after a start() whose types have none.
var _carrier_id: StringName = &""

## One entry per Player, in Player order: that Player's Tokens left per type, a
## Dictionary[StringName, int] keyed by UnitStats.type_id (a typed Dictionary cannot be the
## element type of a typed Array, so the entries are typed when they are made). Empty before
## start().
var _counts: Array[Dictionary] = []


## Copies the stock into a count per Player and per type: the start of a Round, called from
## begin() and again from restart(). For each of player_count Players it makes a Dictionary of
## its own holding stock.count_of(type_id) for every entry of types, by value and never below 0,
## and it remembers the first entry whose can_carry is true as the carrier type. Whatever the
## ledger held before is dropped. Ask first_problem() first: a null stock is refused here with one
## error and leaves the ledger empty (nobody has lost), and a null entry of types is skipped.
func start(stock: TokenStock, types: Array[UnitStats], player_count: int) -> void:
	_counts.clear()
	_carrier_id = &""
	if stock == null:
		push_error("TokenLedger: start() was given no Token stock, so no Player has any Token and nobody can lose.")
		return
	for stats: UnitStats in types:
		if stats != null and stats.can_carry:
			_carrier_id = stats.type_id
			break
	for _player_index: int in maxi(player_count, 0):
		var counts: Dictionary[StringName, int] = {}
		for stats: UnitStats in types:
			if stats != null:
				counts[stats.type_id] = maxi(stock.count_of(stats.type_id), 0)
		_counts.append(counts)


## The Tokens the Player has left of the type: its entry, or 0 for a type_id the ledger does not
## count (an empty one included), for a Player outside the Round and before start().
func count_of(player_index: int, type_id: StringName) -> int:
	if player_index < 0 or player_index >= _counts.size():
		return 0
	return _counts[player_index].get(type_id, 0)


## Takes one Token of the type from the Player: the destruction of a Unit of that type. True when
## a Token was there. At 0, for a type_id the ledger does not count (an empty one, from a Unit
## without stats, included) and for a Player outside the Round it takes nothing, pushes ONE
## warning that says which of the three it was, and returns false: a count never goes below 0.
func take(player_index: int, type_id: StringName) -> bool:
	if player_index < 0 or player_index >= _counts.size():
		push_warning("TokenLedger: no Token was taken: player_index %d is not in the Round." % player_index)
		return false
	if not _counts[player_index].has(type_id):
		push_warning("TokenLedger: no Token was taken from player_index %d: the type_id '%s' is not one of the Round's Unit types." % [player_index, type_id])
		return false
	var left: int = _counts[player_index][type_id]
	if left <= 0:
		push_warning("TokenLedger: no Token was taken from player_index %d: it has none of '%s' left." % [player_index, type_id])
		return false
	_counts[player_index][type_id] = left - 1
	return true


## True when the Player has lost: its count of the carrier type is 0. False for a Player outside
## the Round, before start(), and while the ledger has no carrier type (nobody can lose then).
func has_lost(player_index: int) -> bool:
	if _carrier_id.is_empty() or player_index < 0 or player_index >= _counts.size():
		return false
	return count_of(player_index, _carrier_id) <= 0


## The type_id of the one type that can carry the Flag, the type whose last Token loses the Round
## (the Motorbike in the data), or an empty id before start() and when the types given to it had
## none.
func carrier_type_id() -> StringName:
	return _carrier_id


## What is wrong with a Token stock and the Unit types it is for, as one sentence naming the
## problem, or an empty string when nothing is wrong: begin() asks it before it changes anything.
## Checked in this order, the first problem wins: no stock; a negative count (named by its type id);
## a stock key that no type_id of the types matches (named by the key: a typo would silently make
## a type unavailable); a type without a type_id, or two types with the same one (named by their
## indexes); no type that can carry the Flag, or several (named by their display names); no Token
## of the one that can (named by its display name), because a Player with none could neither
## carry a Flag nor lose. A null entry of types is skipped: the controller checks those first.
static func first_problem(stock: TokenStock, types: Array[UnitStats]) -> String:
	if stock == null:
		return "the Map has no Token stock"
	var problem: String = _first_count_problem(stock, types)
	if problem.is_empty():
		problem = _first_type_problem(types)
	if problem.is_empty():
		problem = _first_carrier_problem(stock, types)
	return problem


## The first negative count of the stock, else the first stock key that no type matches, as a
## sentence; or an empty string.
static func _first_count_problem(stock: TokenStock, types: Array[UnitStats]) -> String:
	for type_id: StringName in stock.counts:
		if stock.counts[type_id] < 0:
			return "the Token stock holds %d for '%s', and a count cannot be below zero" % [stock.counts[type_id], type_id]
	for type_id: StringName in stock.counts:
		if not _has_type(types, type_id):
			return "the Token stock counts '%s', but no Unit type of the Round has that type_id" % type_id
	return ""


## The first type without a type_id, else the first pair of types that share one, as a sentence
## naming the indexes into the types; or an empty string.
static func _first_type_problem(types: Array[UnitStats]) -> String:
	for type_index: int in types.size():
		var stats: UnitStats = types[type_index]
		if stats == null:
			continue
		if stats.type_id.is_empty():
			return "unit_types[%d] ('%s') has no type_id, so no count can be kept for it" % [type_index, stats.display_name]
		for earlier: int in type_index:
			if types[earlier] != null and types[earlier].type_id == stats.type_id:
				return "unit_types[%d] and unit_types[%d] share the type_id '%s', and one count cannot serve two types" % [earlier, type_index, stats.type_id]
	return ""


## No type that can carry the Flag, or several, or no Token of the one that can, as a sentence; or
## an empty string.
static func _first_carrier_problem(stock: TokenStock, types: Array[UnitStats]) -> String:
	var carriers: Array[UnitStats] = []
	for stats: UnitStats in types:
		if stats != null and stats.can_carry:
			carriers.append(stats)
	if carriers.is_empty():
		return "no Unit type can carry the Flag, so no Player could lose"
	if carriers.size() > 1:
		var names: PackedStringArray = []
		for carrier: UnitStats in carriers:
			names.append(_label(carrier))
		return "%d Unit types can carry the Flag (%s), and the loss is decided by exactly one of them" % [carriers.size(), ", ".join(names)]
	if stock.count_of(carriers[0].type_id) < 1:
		return "the Token stock gives no Token to %s, the type that can carry the Flag, so a Player could neither carry a Flag nor lose" % _label(carriers[0])
	return ""


## True when one of the types has the type_id.
static func _has_type(types: Array[UnitStats], type_id: StringName) -> bool:
	for stats: UnitStats in types:
		if stats != null and stats.type_id == type_id:
			return true
	return false


## The name a sentence calls a type by: its display_name, or its type_id while it has none.
static func _label(stats: UnitStats) -> String:
	return stats.display_name if not stats.display_name.is_empty() else String(stats.type_id)
