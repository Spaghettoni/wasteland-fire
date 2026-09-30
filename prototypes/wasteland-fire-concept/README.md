<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question: Is the two-Player split-screen Water Canister run fun on one keyboard? -->
<!-- Date: 2026-09-30 -->

# Wasteland Fire — concept prototype (throwaway)

**Hypothesis:** if two Players on one keyboard drive arcade kinematic Motorbikes on a split screen to steal each other's Water Canister and bring it home, the chase feels tense and readable — true if both complete a run, the Carrier is caught at least once, and nobody asks which keys are theirs after minute one.

**Status:** concluded — built and playtested 2026-09-30; hypothesis CONFIRMED, verdict **PROCEED**. The tester missed a fire button (weapons were cut on purpose). See `REPORT.md`.

**Findings so far (bots + captured frames in `shots/`):** every rule of the vertical slice runs end to end; a steal-and-deliver takes ≈ 8 s at these speeds (probably too fast); a defender parked on its own canister blocks the pickup outright (weapons or canister placement must answer this); two kinematic bikes meeting head-on stop dead; respawn must re-enable collision a physics frame *after* the teleport or the dropped canister re-attaches under Jolt.

Two Motorbikes, two greybox Bases, two Water Canisters, one keyboard, split screen.
Everything is built in code from `main.gd`; there is no art and no menu.

## Run

```
godot --path prototypes/wasteland-fire-concept --windowed --resolution 1280x720
```

| | Player 1 (left) | Player 2 (right) |
|---|---|---|
| Throttle / reverse | W / S | ↑ / ↓ |
| Steer | A / D | ← / → |
| Self-destruct | Q | Enter |
| Restart the Round | R | R |

Rules in the build: touch the other Player's canister with your Motorbike to carry it;
bring it into your own Base pad to win. If a bike that is **not** carrying touches the
Carrier, the Carrier is destroyed and drops the canister where it stood (this contact
rule stands in for the weapons of story 005). A destroyed bike respawns at its Base
after 3 s. Drive your own dropped canister back into your Base to re-seat it.

## Unattended check (bots)

```
godot --path prototypes/wasteland-fire-concept --windowed --resolution 1280x720 --write-movie shots/run.png   --quit-after 900  -- --autoplay=run
godot --path prototypes/wasteland-fire-concept --windowed --resolution 1280x720 --write-movie shots/chase.png --quit-after 2400 -- --autoplay=chase
```

`run`: P1 bot steals and delivers, P2 idle — proves the win path.
`chase`: P1 bot steals; P2 bot ambushes and pursues once — in four tuning attempts it never caught the Carrier.
`selfdestruct`: P1 bot steals and self-destructs 1.5 s later — proves drop, respawn and re-pickup.
`block`: P2 bot parks mid-field on the return line and lunges — proves the tackle, the drop, the defender recovering and re-seating its own canister, and the second attempt. The process quits ~1.5 s after the win screen. Frames go to the path you give `--write-movie` (one PNG per frame; use a scratch folder).
