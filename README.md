# Wasteland Fire

A two-player split-screen 3D vehicle game for one keyboard and one couch, in
the spirit of Return Fire (1995). Drive wasteland Motorbikes, Buggies, Trucks
and Gyrocopters, steal the other Player's Flag and haul it home on a Motorbike
before your Fuel runs dry and your Tokens run out.

Built in Godot 4.7.2 with GDScript. A hobby project, made for playing with
friends at home.

![Concept sheet: Motorbike, Buggy, Gyrocopter and Truck](assets/art/vehicles/vehicle-design.png)

## How it plays

- Two Players share one keyboard and one screen, split side by side.
- Each Player spawns Units from the Garage at their Base, paying one Token of
  that type per spawn. The Map sets the Token stock.
- Four Units. The Motorbike is fast, weak and the only one that can carry a
  Flag. The Buggy beats the Truck, the Truck beats the Gyrocopter and the
  Gyrocopter beats the Buggy. Only the Gyrocopter crosses cliffs and water.
- Every Unit burns Fuel while moving. Fuel Cans on the Map refill it.
- Win by delivering the opponent's Flag to your own Base. Lose by losing your
  last Motorbike, because without one you can never carry a Flag.

The rules of record are in `design/rules.md`, the one-page brief in
`design/game-brief.md` and the vocabulary in `CONTEXT.md`.

## Status

| Story | What | State |
|---|---|---|
| 001 | Driving toy: one Motorbike, chase camera, arcade kinematic driving | Done |
| 002 | Split screen for two, one fixed keyboard layout per Player | Done |
| 003 | Bases, destruction and respawn, self-destruct | Done |
| 004 | The Flag and the win, per-Player HUD, round-over screen | Done, code still calls it the Water Canister |
| 005 | Four Units and the counter triangle | Done |
| 006 | Fuel and Fuel Cans | Done |
| 007 | Map 01 with the Team colours | Done |
| 008 | Tokens, the Garage and the loss | Planned |

Map 01 and the four Units have their low-poly look: the Map is built from
Godot's built-in meshes with textures generated in code, and the Units are the
concept models under `assets/art/`, merged into a few surfaces each when the
game loads. The older evidence scenarios still run on the greybox field.

## Controls

| | Player 1 | Player 2 |
|---|---|---|
| Throttle / reverse | W / S | Up / Down |
| Steer | A / D | Left / Right |
| Fire | Space | Period |
| Choose a Unit (previous / next) | A / D | Left / Right |
| Confirm the Unit | Space | Period |
| Self-destruct | Tab | Enter |

Each Player chooses a Unit type at the start of a Round and after every
destruction, with the choice panel at the bottom of their own view. R restarts
from the round-over screen. Keys 1 and 2 used to damage each Player's own Unit
for testing; they are off now that weapons exist, and `debug_damage` in
`src/gameplay/match/data/match_rules.tres` brings them back.

Every Unit spawns with half a tank. The amber Fuel gauge beside the hit points
empties while the Unit moves and holds while it stands still. Drive over an amber
Fuel Can to refill from it; the Can comes back at the same spot after about 20
seconds. A ground Unit with no Fuel stops but can still turn and fire, and a
Gyrocopter with no Fuel crashes. Self-destruct still works with an empty tank.

Map 01 is an island about 300 by 100 metres. Orange is Player 1 at the west
Base and Teal is Player 2 at the east Base; each Base is a walled compound with
one gate facing the centre, a roofless Garage and a water tower over the Flag.
A canyon road runs along the north and a cracked salt flat fills the middle,
with a Fuel depot of five Cans at its centre and wrecks, containers and scrap
walls for cover. Two shallow fords across the flat slow ground Units to half
speed. A rocky ridge in the south, cut by two channels, is crossed only by the
Gyrocopter, and the sea around the island stops every Unit.

## Running it

1. Install Godot 4.7.2. The project is pinned to that version; see
   `docs/engine-reference/godot/VERSION.md`.
2. Open the project folder in the editor and press Play, or from the repo
   root:

```
godot --path .
```

The game launches straight into the split screen. There is no menu yet.

Tests use gdUnit4 and run headless. The same suite runs in GitHub Actions on
every push:

```
godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

## Repository layout

- `src/gameplay/` is the game: units, match rules, split screen, maps, chase
  camera and the Flag (still named `canister`). `src/ui/hud/` is the HUD.
- `tests/` holds the gdUnit4 tests.
- `design/` holds the brief, the rules of record and the author's Slovak
  source with its English translation.
- `production/` holds the epic, the stories and the retained QA evidence, one
  folder of screenshots per story.
- `assets/art/` holds the vehicle concept models, a shared palette and a
  showcase scene that renders them.
- `docs/` holds engine reference notes pinned to Godot 4.7.2 and the
  framework's workflow guide.
- `.claude/` holds the agents, skills and hooks of the development framework
  described below.

## Concept art

Four vehicles in one kit, kitbashed from Godot's built-in meshes with
procedural rust and paint-chip textures, rendered by the engine itself.

| Motorbike | Buggy |
|---|---|
| ![Motorbike](assets/art/vehicles/wasteland_motorbike/renders/wasteland_motorbike_front.png) | ![Buggy](assets/art/vehicles/wasteland_buggy/renders/wasteland_buggy_front.png) |

| Gyrocopter | Truck |
|---|---|
| ![Gyrocopter](assets/art/vehicles/wasteland_gyrocopter/renders/wasteland_gyrocopter_front.png) | ![Truck](assets/art/vehicles/wasteland_truck/renders/wasteland_truck_front.png) |

## How it is made

The project is developed with [Claude Code](https://claude.com/claude-code)
inside [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)
by Donchitos, a studio-shaped set of agents, skills and quality gates for
Claude Code. The framework turns the work into stories with acceptance
criteria, reviews and retained evidence. The design, the decisions and the
playtesting are the author's.

## Credits and licence

- Game design, code and art: copyright 2026 Tomas Kunzo. A licence for the
  game's own content has not been chosen yet.
- Development framework: Claude Code Game Studios by Donchitos, MIT licence,
  see `LICENSE`.
- Test framework: gdUnit4 by Mike Schulze, MIT licence, see
  `addons/gdUnit4/LICENSE`.
- Inspiration: Return Fire (1995). No code or assets from it are used.
