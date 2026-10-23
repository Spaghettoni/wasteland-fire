class_name Lineup
extends RefCounted
## Who plays and on which side (Story 048; Martin, 2026-10-23: "4 player split screen ... 4
## ovladace, alebo dvaja klavesnicu a 2 ovladace ... aj 2 v 1 alebo 3 v 1 ... pick a side"): one
## entry per Player, in Player order, each a device and a Team. The Pick a side screen makes it,
## the map choice passes it on, the launch scene plays it (SplitScreen.apply_lineup()), and the way
## back to the map choice hands it back, so the Players keep their sides.
##
## Implements: production/epics/wasteland-fire/story-048-four-players.md AC-1, AC-2.
##
## A device is a pad's device id (0 or more) or one of the two keyboard halves: KEYBOARD_1, the
## keys of Player 1 in project.godot (W A S D, Space, ...), and KEYBOARD_2, Player 2's (the arrows,
## Period, ...). A Team is ORANGE (0, Base A) or TEAL (1, Base B). The order is the Players' order
## in the Round: every Orange Player first, then every Teal one, so Player 1 is always Orange and the
## last Player always Teal.

## The keyboard half with Player 1's keys in project.godot.
const KEYBOARD_1: int = -2
## The keyboard half with Player 2's keys in project.godot.
const KEYBOARD_2: int = -3
## The Teams, as indices of the Map's Bases: Orange plays from player_1_base, Teal from player_2_base.
const ORANGE: int = 0
const TEAL: int = 1
## The most Players a Round takes.
const MAX_PLAYERS: int = 4

## One entry per Player: the device that Player plays with.
var devices: Array[int] = []
## One entry per Player: that Player's Team.
var teams: Array[int] = []


## A lineup of the given devices and Teams, put in Player order (Orange first, each side in the
## order given). Entries past MAX_PLAYERS are dropped.
static func of(device_list: Array[int], team_list: Array[int]) -> Lineup:
	var lineup := Lineup.new()
	for team: int in [ORANGE, TEAL]:
		for index: int in mini(device_list.size(), team_list.size()):
			if team_list[index] == team and lineup.devices.size() < MAX_PLAYERS:
				lineup.devices.append(device_list[index])
				lineup.teams.append(team)
	return lineup


## How many Players play.
func player_count() -> int:
	return devices.size()


## True when it can be played: two to four Players, each side with at least one, every device used
## once.
func is_playable() -> bool:
	if devices.size() < 2 or devices.size() > MAX_PLAYERS or devices.size() != teams.size():
		return false
	if not teams.has(ORANGE) or not teams.has(TEAL):
		return false
	for index: int in devices.size():
		if devices.find(devices[index]) != index:
			return false
	return true


## True when the device is one of the keyboard halves.
static func is_keyboard(device: int) -> bool:
	return device == KEYBOARD_1 or device == KEYBOARD_2
