# Epic: Wasteland Fire — First Playable

> **Status**: Active
> **Tier**: `workflow: minimal` — implicit epic synthesised from `design/game-brief.md` by `/create-stories` on 2026-09-30. No GDD, ADRs, TR registry or control manifest exist at this tier; every story traces to the brief.
> **Governing ADRs**: N/A (minimal — no ADRs)
> **Last Updated**: 2026-10-21: story 038 (Map 02, the map choice, the Bushes, wrecks and small buildings) added and built, from Martin's request and three answers of the same day; 2026-10-16: stories 027 to 031 (the light and the colour with your own Unit seen through cover, the water, the fire and smoke, the hits and shots, the air) added as Ready, from the developer's request of 2026-10-15 and their four answers of that day; 2026-10-15: stories 025 and 026 (the Gyrocopter's rotor and propeller turn; ground Units leave tyre tracks) added as Ready, from the developer's request and their four answers of the same day; 2026-10-10: stories 015 to 024 (the Turrets' damage looks, Unit explosions, badly damaged Units, the Base walls and then the Garage and scrap walls as Wall Panels, two Heights, the Gyrocopter's crash, ammo and the full start, the Fuel building, the ammunition buildings) added as Ready, from the author's comments of 2026-10-10 (archived under `design/source/`) and the developer's ten answers of the same day; 2026-10-09: story 014 (the Truck's Mines) Complete, the last story of the build order; 2026-10-08: stories 012 (Flag Walls, with the damaged looks the developer added when it closed) and 013 (Turrets) Complete; stories 012 to 014 (Flag Walls, Turrets, the Truck's Mines) added as Ready after the First Playable, from the developer's request and the author's board of 2026-10-07 (archived under `design/source/`); 2026-10-04: story 011 (the Unit swap at the own Base) Complete, with story 010 (the camera from above) and story 009 (playtest quick fixes) after the first playtest with friends; story 008 Complete, so all eight stories of the First Playable are built (2026-10-01: brought to version 0.1 of the author's artifact; the source is archived under `design/source/`; the rules of record are `design/rules.md`).

## Goal

Two friends on one couch drive wasteland Motorbikes, Buggies, Trucks and Gyrocopters across a split screen to steal each other's Flag and haul it home on a Motorbike, paying a Token for every wreck and burning Fuel they must keep finding; since 2026-10-10 they burn Fuel and fire ammo that they restock only at the supply buildings (the comments; decided 2026-10-10; stories 022 to 024).

## Scope (the brief's MVP list)

1. Driving toy
2. Split screen for two
3. Bases, destruction and respawn
4. Flag and the win (built as story 004, "Water Canister and the win")
5. Four Units and the triangle
6. Fuel and Fuel Cans
7. Map 01
8. Tokens, the Garage and the loss

## Ordering (the brief's Build order — this is the plan; no sprint plan at `minimal`)

001 → 002 → 003 → 004 → 005 → 006 → 007 → 008. Stories 001 to 004 are the vertical slice (two Motorbikes, two Bases, one Flag run) and are Complete as of 2026-10-01: the sofa test with a friend belongs here, after 004 and before the triangle exists. Greybox until 007. Story 008 comes last because it changes how a Round ends and renames the Water Canister code to the Flag; if Map 01 is late, 008 may run before 007 (its Dependencies say how). The v0.1 playtest follows 008: with it the First Playable is complete. Story 008 was closed on 2026-10-03, so the First Playable is built and the playtest is next.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Driving toy | Visual/Feel | Complete | N/A (minimal) |
| 002 | Split screen for two | Integration | Complete | N/A (minimal) |
| 003 | Bases, destruction and respawn | Logic | Complete | N/A (minimal) |
| 004 | Water Canister and the win (the Flag of v0.1) | Integration | Complete | N/A (minimal) |
| 005 | Four Units and the triangle | Logic | Complete | N/A (minimal) |
| 006 | Fuel and Fuel Cans | Logic | Complete | N/A (minimal) |
| 007 | Map 01 | Visual/Feel | Complete | N/A (minimal) |
| 008 | Tokens, the Garage and the loss | Integration | Complete | N/A (minimal) |

## After the first playtest (2026-10-03)

The author's list from the first playtest with friends (`story-009-playtest-quick-fixes.md` quotes it in Slovak with a translation). Quick fixes first (decided 2026-10-03): items 3 to 7 in story 009; the camera from almost straight above (item 1) and the Unit swap at the own Base (item 2) follow as their own stories once the author has played 009.

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 009 | Playtest quick fixes: solid depot tanks, the Gyrocopter over the cover, turning on the spot, the idle Fuel burn, the out-of-Fuel Self-destruct hint | Integration | Complete | N/A (minimal) |
| 010 | The camera from above: almost straight down with a slight forward tilt, one key per Player back to the chase view | Visual/Feel | Complete | N/A (minimal) |
| 011 | The Unit swap at the own Base: Self-destruct inside the own Base puts the Unit away for free | Integration | Complete | N/A (minimal) |

## After the First Playable: Turrets, Flag Walls and Mines (2026-10-07)

The developer's request of 2026-10-07 for Turrets, walls around the Flag and the Truck's Mines, and five cards of the author's board shared the same day (archived under `design/source/` as `wasteland-fire-board-2026-10-07.png`, `.sk.txt` and `.en.md`; each story quotes its card in Slovak with a translation). Three of them, Turrets, destructible walls and Mines, are this batch, together with the Bushes card's line-of-sight rule for the Turrets; the rest of the Bushes card and "Simplify Map 01" come later (decided 2026-10-07). The developer's four answers of that day and the rules are in `design/rules.md`, Turrets, Flag Walls and Mines. Built in this order (reading, 2026-10-07): the Flag Walls first, a passive target for the new way Shots damage what is not a Unit, then the Turrets, then the Truck's Mines.

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 012 | Flag Walls: four panels between each water tower's legs around the Flag, broken by every Unit but the Motorbike and flown over by the Gyrocopter; new Units appear on the Garage's side spots | Integration | Complete | N/A (minimal) |
| 013 | Turrets: two per Base outside the Gate fire at the other Player's Unit; no Flag can be taken while a Turret of its Base stands | Integration | Complete | N/A (minimal) |
| 014 | The Truck's Mines: 5 per Truck, live after 3 s, destroying any ground Unit that drives onto them; never laid in or near a Base | Integration | Complete | N/A (minimal) |

## After the author's comments of 2026-10-10: damage, walls, Heights and supplies

The author's nine comments after playing stories 012 to 014, pasted by the developer on 2026-10-10 and archived under `design/source/` as `wasteland-fire-comments-2026-10-10.sk.txt` (Slovak) and `wasteland-fire-comments-2026-10-10.en.md` (English; where they differ the Slovak wins); each story quotes its comment or comments in Slovak with the archived translation. The author's board has no cards for these features (the developer, 2026-10-10). The developer's ten answers of 2026-10-10, the recommended option every time, and the rules are in `design/rules.md`, mainly Units, Heights, Resources, Destruction and respawn, and Turrets, Flag Walls and Mines; two of the answers lift exclusions of `design/game-brief.md` (no ammo economy; the Base walls standing all Round). Built in this order, one story per fresh session (decided 2026-10-10): the Turrets' damaged looks at their final height first, sized against the flying Gyrocopter's drawn band, which that story measures; then the explosion, whose smoke the badly damaged Units may reuse; then every wall a Wall Panel, in two stories, the Base walls first; then the two Heights, once the Turrets and every wall have their final height, and the Gyrocopter's crash into a Tall piece; then ammo with full supplies for every new Unit; then the Fuel building that replaces the Fuel Cans, and last the ammunition buildings, with no Mines at any supply zone. The developer's "all eight" are ten stories: the wall story is built as two (decided 2026-10-10), and so is the supply story, because the drafts' review found it more than one build session (reading, 2026-10-10); until story 024, ammo comes back only with a new Unit.

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 015 | Turrets show their damage: two damaged looks below 80% and 35% of their hit points, as the Flag Walls have, and the Turrets grow to about 3 m so that their heads reach the high Height, sized against the flying Gyrocopter's drawn band, which the story measures first | Visual/Feel | Complete | N/A (minimal) |
| 016 | A destroyed Unit explodes: a flash, a fireball, debris and smoke for about 2 s at every destruction, the Self-destruct and the Gyrocopter's Fuel crash included, never at a Swap | Visual/Feel | Complete | N/A (minimal) |
| 017 | Badly damaged Units smoke and slow down: at or below 20% of its hit points a Unit smokes and moves at half speed | Integration | Complete | N/A (minimal) |
| 018 | The Base walls become Wall Panels: both Bases' back, side and Gate walls become 2 m panels of the Flag Walls' kind with 40 hit points; the corner towers stay | Integration | Complete | N/A (minimal) |
| 019 | The Garage walls and the scrap walls become Wall Panels: both Garages' back and side walls and the two scrap walls in the field, which stop being Cover | Integration | Complete | N/A (minimal) |
| 020 | Two Heights: the Gyrocopter flies high, at one constant height over every low piece, and never descends; every Tall piece stops it, and every hit volume spans both Heights | Integration | Complete | N/A (minimal) |
| 021 | A Gyrocopter that flies into a Tall piece crashes: faster than its crash speed it is destroyed and explodes; a graze or a slow nudge only stops it | Logic | Complete | N/A (minimal) |
| 022 | Ammo, and full supplies for every new Unit: a load of ammo per type, an empty gun fires nothing, and every new Unit starts with a full tank and a full load of ammo | Logic | Complete | N/A (minimal) |
| 023 | The Fuel building replaces the Fuel Cans: the centre depot becomes the Fuel building, with a supply zone on each Base-facing side that refills the Fuel of a Unit that stops in it, and the nine Fuel Cans leave Map 01 | Integration | Complete | N/A (minimal) |
| 024 | The ammunition buildings, and no Mines at the supply zones: an ammunition building on each half refills the ammo of a Unit that stops in its zone; no Mine can be laid in or around a supply zone | Integration | Complete | N/A (minimal) |

## After the developer's request of 2026-10-15: the rotor and the tyre tracks

The developer asked on 2026-10-15 for a smooth animation of the Gyrocopter's spinning blades ("blurred is fine, but it needs to be recognizable enough") and for tyre tracks behind the ground vehicles, asking whether Terrain3D could make them. Their four answers of the same day, the recommended option every time, are in `design/rules.md`, Teams and visual style: blades with a smear; a track map that the ground's shader reads, not Terrain3D (its maps hold one pixel per terrain vertex, too coarse for tyres 0.20 to 0.36 m wide) and not ribbon meshes; marks that fade over about a minute; and two stories, each built in a fresh session with `/dev-story`. No card of the author's board was named for them. They are built one after the other, never beside each other, because both edit the evidence runner and re-baseline the same outputs (reading, 2026-10-15: the rotor first, the smaller of the two).

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 025 | The Gyrocopter's rotor and propeller turn: two Team-coloured blades, each trailing a soft smear over about a quarter turn, and a pusher propeller whose rate follows the throttle | Visual/Feel | Complete | N/A (minimal) |
| 026 | Ground Units leave tyre tracks: darker, packed ruts under each tyre on the sand, the canyon road and the salt flat, drawn by the ground from one track map and fading over about a minute | Visual/Feel | Complete | N/A (minimal) |

## After the developer's request of 2026-10-15: the light, the water, the fire, the hits and the air

The developer asked on 2026-10-15 whether the game uses shaders and whether they could improve the visuals. It had four of its own (the ground's, the rocks', the rotor's smear and the greybox floor's), and six ideas were offered; the developer asked for stories for five of them ("create stories for each of those except number 5"; the fifth, more marks in story 026's track map, was left out). Their four answers of the same day are in `design/rules.md`, Teams and visual style: no card of the author's board names these looks; one story per idea; only the Player's own Unit shows through cover, in that Player's view; and a hit shows as a short white flash on any Unit, Turret, Wall Panel or Flag Wall a Shot damages, with Units charring in patches as they lose hit points and a red pulse at the edges of the view whose Unit was hit. Build story 027 first (its glow is what makes the fire and the tracers of 029 and 030 bloom) and story 031 after story 026 (both edit the ground's shader), each in a fresh session with `/dev-story` and never beside another story; stories 030 and 031 are larger than L and may take two sessions each.

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 027 | The light and the colour, and your own Unit through cover: a tone mapper instead of Linear, glow for what is brighter than white, a colour grade, and a Team-coloured silhouette of your own Unit where cover hides it, in your view only | Visual/Feel | Ready | N/A (minimal) |
| 028 | Water that moves and shines: ripples, the sun's glint and the sky's reflection on the sea, the channels and the fords, and foam along the banks and the shore | Visual/Feel | Ready | N/A (minimal) |
| 029 | Fire and smoke drawn by shaders: a ragged, white-hot fireball that darkens to soot, and smoke that breaks up from its edges with a lit and a shaded side | Visual/Feel | Ready | N/A (minimal) |
| 030 | Hits and shots: a white flash on whatever a Shot damages, Units that char as they lose hit points, glowing tracers, muzzle flashes, and sparks or dust where a Shot ends | Visual/Feel | Ready | N/A (minimal) |
| 031 | The air: sand drifting along the wind, heat haze in the distance, a dusty sky, and a red pulse at the edges of the view whose Unit is hit | Visual/Feel | Ready | N/A (minimal) |

## After Martin's request of 2026-10-18: controllers, then four Players

Martin asked on 2026-10-18 to play with the Xbox controllers paired with his PC, and later to play two against two on four views, with a menu to pick which Player has which controller and, later still, rebinding of every pad and keyboard. He was offered four steps and chose to start with the controllers (decided 2026-10-18). Story 032 is written; stories 033 (two teams of two on four views), 034 (a join screen: each Player takes a slot with a pad or a key and picks a team) and 035 (rebinding, saved between runs) are planned and written later, 033 once Martin answers how the teams share the Bases, the Tokens and the Flags and whether teammates can hurt each other. Story 032 touches only the input and the hints, so it can be built beside the visual stories 027 to 031; story 033 rewrites `split_screen.gd` and the HUD and should not be built beside them.

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 032 | Xbox controllers: the first two connected pads belong to Player 1 and Player 2 beside their keyboard layouts; analog triggers and stick, A fire, X Mine, Y camera, View Self-destruct, Menu restart; pads that come and go mid-Round; the hints name the pad's buttons | Integration | Complete | N/A (minimal) |

## After Martin's request of 2026-10-19: slower Fuel and the resource bars

Martin asked on 2026-10-19 for Fuel to burn three times slower (after playing it, half: the same day) and for the Fuel and the ammo to be two bars side by side, each its own colour, with an icon and no text. Numbered 036 so that the planned 033 to 035 (four Players, the join screen, rebinding) keep their numbers.

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 036 | Fuel lasts twice as long, and Fuel and ammo are two coloured bars with icons: half of every burn rate; a jerrycan and the amber Fuel bar, cartridges and a blue ammo bar, no text, right of the hit-point bar | UI | Complete | N/A (minimal) |

## After Martin's playtest of 2026-10-19: a hollow ridge and a blind Turret

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 037 | RidgeWest's top is drawn (rebuilt from `build_rocks.py`, every rock top facing up), and a Turret sees, aims at and fires on a Gyrocopter over a cliff while a cliff still hides a ground Unit | Integration | Complete | N/A (minimal) |

## After Martin's request of 2026-10-21: Map 02

Martin asked on 2026-10-21 to put Map 02, the schematic of 2026-10-16, into the game. His three answers of that day: a map choice before the match, the Bushes, wrecks and small buildings all in, the Tokens of Map 01 (`design/rules.md`, Map 02 and the map choice).

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 038 | Map 02, a map choice before the match, and the Bushes, wrecks and small buildings: the canyon Map from the schematic, built by `tools/maps/build_map_02.py`; the launch screen with both Maps and the way back to it from the Round-over screen; Outposts; Bushes that hide from Turrets and fall under a Buggy or a Truck; breakable wrecks and huts | Integration | In Progress | N/A (minimal) |
| 041 | Shots in two Heights: low Shots hit ground Units, high Shots (Left / Right Shift, RB) hit the Gyrocopter and fly over walls and cover; Turrets are hit by both and fire high at a Gyrocopter (Martin, 2026-10-22) | Integration | In Progress | N/A (minimal) |
| 040 | On a pad the left stick drives (up forward, down reverse) and either trigger or A fires (Martin, 2026-10-22) | Integration | In Progress | N/A (minimal) |
| 039 | No Turret locks a Flag, and the Motorbike breaks Wall Panels and Flag Walls (Martin, 2026-10-21) | Logic | In Progress | N/A (minimal) |
