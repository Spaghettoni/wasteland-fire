# Story 048: Up to four Players in two Teams, Pick a side

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-23

## Context

**GDD**: `design/rules.md` ("Up to four Players in two Teams"); `CONTEXT.md` (Team, Lineup, Pick a side)
**Requirement**: Martin, 2026-10-23: "mozeme skusit spravit ten 4 player split screen? ideal aby ludia mohli pouzivat aj 4 ovladace, alebo, dvaja klavesnicu a 2 ovladace. a nech je kludne moznost aj 2 v 1 alebo 3 v 1. nech tam je nieco v uvode ze pick a side. a ked pohnes packu/sipku rovno sa zaregistruje aj ovladac aj vyberie strana" (four-player split screen with up to four pads, or two on the keyboard and two pads; 2 v 1 and 3 v 1 too; a Pick a side screen at the start; moving the stick or an arrow registers the device and picks the side at once). His answers the same day: one Base and one shared Token stock per Team; "nech ta moze zranit super, aj jeho miny, vlastne veze ta nezrania" (only the other Team hurts you, its Mines too; your own Turrets do not); moving left or right picks the side at once.

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (the Round's rules and the launch scene)

---

## Acceptance Criteria

- [x] AC-1: The game opens on Pick a side. A pad (left stick, D-pad) or a keyboard half (A / D; the arrows) joins by moving left (Orange) or right (Teal); further moves step Orange, not playing, Teal; at most four devices.
- [x] AC-2: A / Space / Period makes a Player on a side ready, B / Tab / Enter makes a ready Player not ready or takes one out; with both sides taken and every Player on a side ready, the map choice opens with the lineup, which the Round plays and the way back keeps.
- [x] AC-3: Two to four Players; with three or four the screen is split in four, Orange's views left, Teal's right, a dark panel in an empty place; each Player's Unit, HUD band and choice panel in the Team's colours.
- [x] AC-4: Each Player plays on its own device only: a keyboard half's keys on that Player's actions and no other's, a pad on its own Player.
- [x] AC-5: A Team shares one Base (and Garage), one Flag and one Token stock; a Team loses with its last Motorbike Token; any Player delivering the other Team's Flag wins for the Team; the Round-over screen names the Team.
- [x] AC-6: Only the other Team hurts: a Teammate's Shots do nothing to you; a Mine goes off only under the other Team (`mine_settings.tres` `spares_own_team`); Turrets fire at the nearest Unit of the other Team they can see.
- [x] AC-7: A Round of two Players (one per Team) is what it was; the older scenarios keep their outputs.
- [x] AC-8: The look: frames of Pick a side, the map choice and a four-way split.

---

## Implementation Notes

- `Lineup` (devices and Teams, Orange first). `PickSide` reads raw key and pad events; the keyboard halves are Player 1's and Player 2's keys of project.godot, read from the project settings.
- `SplitScreen.apply_lineup()`: Players 3 and 4 are duplicates of Player 2's nodes (renamed, Node references re-pointed, prefix `p<n>_`), the views stand in two columns, `_apply_inputs()` rewrites the keyboard events of `p1_`..`p4_`, `PadAssignment.reserved` ties each pad to its Player.
- `MatchController.set_teams()`, `team_of()`, `team_count()`; `FlagRules` keeps one Flag per Team; the TokenLedger counts per Team; the winner is a Team.
- A Unit's `player_index` is its Team (Shots, Mines and Turrets compare it); the controller's arrays stay per Player.
- `Turret.arm_targets()`; `RoundOverScreen.team_winner_texts`.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `teams` (T1 to T7), `teams_three` (E1 to E3), `tools/evidence/lobby/pick_side_check.gd` (L1 to L6), `tools/evidence/map_choice/map_choice_check.gd`; frames in `production/qa/evidence/story-048-four-players/`; the regression; a four-Player test with real pads.

**Status**: [x] Created 2026-10-23: `production/qa/evidence/story-048-four-players-evidence.md`

---

## Dependencies

- Depends on: stories 032 and 040 (pads), 038 (the map choice), 046 (walls for both).
- Unlocks: Maps with more Bases (1 v 1 v 1 v 1), online play.
