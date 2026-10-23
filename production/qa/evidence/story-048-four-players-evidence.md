# Story 048 evidence: Up to four Players in two Teams, Pick a side

> **Story**: `production/epics/wasteland-fire/story-048-four-players.md`
> **Type**: Integration (headless scenarios, screen checks, windowed frames)
> **Written**: 2026-10-23, by `/dev-story` in a cloud session (Linux, Godot 4.7.2 official build)
> **Sign-off**: [ ] Martin and friends, after a Round with four real pads (or two pads and the keyboard) on `WastelandFire-2026-10-23-four-players.exe`

## Acceptance criteria, as measured

| AC | Result | Check |
|---|---|---|
| AC-1 Pick a side, join by moving | PASS: the project opens on it; A joins Keyboard 1 to Orange, pad 0's stick right and Right (Keyboard 2) join Teal, pad 1's D-pad left joins Orange, a fifth pad is refused; Left steps to the middle and on, B takes a Player who is not ready out | `pick_side_check` L1 to L3 |
| AC-2 ready, map choice, lineup kept | PASS: four ready, the map choice opens with devices [Keyboard 1, pad 1, pad 0, Keyboard 2], Teams [0, 0, 1, 1]; Space starts a Round of four; two keyboard halves start a Round of two in the old views; `map_choice_check` (K1 now expects the project to open on Pick a side) passes K1 to K6 | `pick_side_check` L4 to L6 |
| AC-3 four-way split, colours | PASS: views [Player1, Player2] left, [Player3, Player4] right; 2 v 1: [Player3, EmptyView] on the right; Units in their Team's materials | `teams` T1, `teams_three` E1, frames |
| AC-4 each on its own device | PASS: Up (Keyboard 2) moves only Player 3's Unit; Players 2 and 4 have no keys; pad 0's stick moves Player 2's, pad 1's A fires Player 4's Weapon | `teams` T1, T2 |
| AC-5 shared Base, Flag, Tokens | PASS: all four in play after choosing, Teammates 8 m apart in their Garage; Tokens [4, 4, 5, 5] after Player 1's Motorbike; Player 2 delivers Teal's Flag: Orange (Team 0) wins, the four screens read "Orange wins!"; Teal's five Motorbikes gone in 2 v 1: Orange wins | `teams` T1, T3, T7, `teams_three` E3 |
| AC-6 only the other Team hurts | PASS: Player 2's Shots leave Player 1 at 10000, Player 3's take 25; an Orange Mine leaves an Orange Unit alone and destroys a Teal one; Teal Turrets armed with both Orange Units, one fires at the one 15 m off | `teams` T4 to T6, `teams_three` E2 |
| AC-7 two Players as before | PASS: see the regression | — |
| AC-8 the look | frames below | — |

## Seeded defects

| Mutation | Caught by |
|---|---|
| Each Unit's player_index is its Player, not its Team, and the Tokens are counted per Player | `teams` T1, T3 to T7 (6 of 7 fail) |

## Regression

All 107 scenarios captured again (the 104 of story 047 with `pad_back`, `teams`, `teams_three`). The runner gives every scenario that does not declare `TEAMS` the Mines of before (one goes off under its own Team too). Against story 046's capture only frame-rate timings, engine stack line numbers, and lint counts of files this story extended differ (`fuel_building` 78 → 80 scripts, `mines` 428 → 429 lines, `tokens_data` 19 → 20 files, 1640 → 1717 lines, 9 integer literals with Lineup's constants; all pass).

## Merged on story 027

Tomáš pushed story 027 (the light and colour of Map 01, your own Unit through cover) while this story was built, on the same base. This story was rebased onto it; one conflict in `split_screen.gd` (both changed `_ready()`), joined by hand: a Unit's silhouette sits on its Team's layer (its player_index is the Team), so each view leaves out the other Team's layer and shows the Teammates' with its own (`_hand_silhouette_layers()` now asks `team_of()`). The smoke list's items were renumbered (027 is 35, this story 36). On the merged tree: the 108 headless scenarios (the 107 above and `see_through`) against the capture before the merge differ only in timings, stack line numbers and lint counts; `see_through` passes its 20 checks; `teams`, `teams_three`, `pad_back`, `pick_side_check` and `map_choice_check` pass, and two warnings the four-way split logged (a view moved with its owner set, a SubViewport size copied under a stretching container) are gone. The frames were taken again on the merged tree. Story 027's note stands: under Map 01's new tone mapping its supply zones no longer match their HUD bars exactly (story 045).

## Frames

`pick_side_check` windowed (1280 x 720, compatibility renderer): `pick-01-empty.png`, `pick-02-four-joined.png`, `pick-03-three-ready.png`, `pick-04-map-choice.png`, `pick-05-match-four-players.png` (four choice panels, Orange left, Teal right). `teams_showcase` with the Forward+ renderer (Vulkan): `01-four-players-in-their-garages.png`, `02-four-players-driving-out.png` (a Motorbike and a Buggy for Orange, a Truck and a Gyrocopter for Teal, each bar in its place).

## Human checks

1. Do four views of 640 x 360 give enough to see on your screen?
2. Is joining by moving natural, and is Tab / Enter right for a keyboard Player to go back?
3. With one Token stock per Team, does 3 v 1 or 2 v 1 feel fair, or should the smaller Team get more?
