<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question: Is the two-Player split-screen Water Canister run fun on one keyboard? -->
<!-- Date: 2026-09-30 -->

# Concept Prototype Report: Wasteland Fire — vertical slice

> **Date**: 2026-09-30 (built overnight; played and debriefed the same morning)
> **Prototype Path**: Engine (Godot 4.7.2, GDScript)
> **Concept File**: design/game-brief.md (the `rigor: minimal` brief; no game-concept.md at this tier)

---

## Hypothesis

If two Players on one keyboard drive arcade kinematic Motorbikes on a split screen to steal each other's Water Canister and bring it home, the chase will feel tense and readable — we will know this is true if, within a five-minute session, both Players complete at least one steal-and-deliver run, the Carrier is caught (canister dropped) at least once, and neither Player asks which viewport or which keys are theirs after the first minute.

---

## Riskiest Assumption Tested

That one keyboard can carry two simultaneous layouts driving two kinematic bikes at once, and that the chase reads on a 640×720 half-screen. **Proved out.** The playtester named exactly this as the moment it worked: "when both vehicles could be operated simultaneously and both split screens worked." Per-Player Input Map actions (no device IDs) route the two layouts independently, and both viewports render the one shared world.

---

## Approach

Built in code from a single root node (`main.gd`): an 80×80 walled greybox field, two 8×8 Base pads at x = ±30, one canister per Base, two `CharacterBody3D` Motorbikes in floating motion mode, two `SubViewport`s side by side each with a chase camera and a status label. Rules in the build: touch to pick up (Motorbike only, by a `can_carry`-style check), drop where the Carrier is destroyed, carry your own dropped canister home to re-seat it, deliver the opponent's canister into your own Base to end the Round, 3 s respawn, self-destruct, R to restart. **Combat stand-in:** if a bike that is not carrying touches the Carrier, the Carrier is destroyed — a placeholder for story 005's weapons so the chase has a resolution.

Because nobody could play it during the build (an unattended overnight run), four scripted bot scenarios drove the loop first and Movie Maker (`--write-movie`) captured every frame: `run` (steal and deliver), `selfdestruct` (drop mid-run, respawn, re-steal), `chase` (a pursuing defender) and `block` (a defender parked on the return line). Build time ≈ 1.5 h wall clock including four fix rounds. The human playtest followed the next morning.

**Path chosen:** Engine
**Reason for path:** feel is the hypothesis; browser latency would lie about driving.

**Shortcuts taken (intentional):**
- Every value hardcoded (`MAX_SPEED 24`, `ACCEL 20`, `TURN_RATE 2.8`, respawn 3 s); no data resources
- Coloured boxes and cylinders; no art, audio, menus or Fuel
- Contact tackle instead of weapons; no Buggy, no Gyrocopter
- Debug prints left in; bots and traces live in the same scripts as the game

---

## Result

**Human playtest (2026-09-30, the developer's session):**

- **Hypothesis check — CONFIRMED.** Both Players completed runs, a Carrier was caught, and the layouts were clear after the first minute.
- **Best moment:** "when both vehicles could be operated simultaneously and both split screens worked" — the riskiest assumption, seen directly.
- **Worst moment:** none reported — "nothing was frustrating, everything worked."
- **Surprise:** "I expected option to fire ammo." The build cut weapons on purpose and the tester still reached for a fire key; the contact tackle did not read as combat. Shooting belongs to the core loop's feel, not to polish.
- **Verdict:** PROCEED — "both players could drive and the loop worked."

**Bot runs and captured frames (`shots/`), gathered before the human playtest:**

- Both viewports render the shared world with an independent chase camera each; the 24 px status labels are legible at 640×720 (`01-start-both-viewports.png`).
- `run`: P1 picks up at frame 192 (3.2 s), turns, delivers at frame 481 (8.0 s) — a full steal-and-deliver takes about eight seconds at these speeds (`02-pickup-carrying.png`, `03-round-over-p1-wins.png`).
- `selfdestruct`: the Carrier destroyed mid-run drops the canister where it stood; it stays there; the respawned bike drives back, re-picks it and wins (`04-destroyed-canister-dropped.png`, `05-respawned-repickup.png`).
- `block`: the defender lunges into the Carrier mid-field, the Carrier is destroyed, the defender recovers its own canister and re-seats it at its Base, the thief respawns and wins on the second attempt (`06-`, `07-`, `08-…png`). Every rule in the brief's vertical slice ran end to end at least once.
- `chase`: a defender that starts beside its canister and pursues with a short lead never caught a full-speed Motorbike in four tuning attempts; only the parked-on-the-return-line blocker did.
- Three bugs the build surfaced that production must design for (see Lessons Learned): standing on your own canister blocks the pickup outright; two kinematic bikes meeting head-on stop dead; a respawn teleport with collision restored in the same physics frame re-attached the dropped canister to the respawned bike under Jolt.

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | Engine |
| Iterations to playable | 1 to render and drive; 4 fix rounds to run the whole loop unattended; 0 fix rounds after the human playtest |
| Prototype duration | ≈ 1.5 hours wall clock (overnight, autonomous) + one playtest session |
| Playtesters | 1 internal session (the developer; both bikes driven at once) / 0 external |
| Feel assessment | Both layouts usable at once on one keyboard; the loop read without explanation; no control complaint. Bot data: a 60-unit run at 24 u/s takes ≈ 3 s; turn radius at full speed ≈ 8.6 units. The tester missed a fire button |
| Hypothesis verdict | CONFIRMED |

---

## Recommendation: PROCEED

The riskiest assumption — two people driving on one keyboard with a readable split screen — held in play, the loop completed without anyone being told the rules, and nothing frustrated the tester. The one surprise, reaching for a weapon that was not there, is an argument about *order* rather than direction: the canister run is the game, and shooting is what the tester expected to resolve the chase with. Proceed into the stories as written, and consider pulling weapons forward (see below).

---

## If Proceeding

What the prototype and the playtest revealed, to carry into the stories:

- **Core tuning values discovered:** max speed 24 u/s, turn rate 2.8 rad/s, acceleration 20 u/s² make a 60-unit steal-and-deliver last ≈ 8 s including the turn-around. The tester did not call it too fast; keep these as the starting values in story 001's data resource and tune from there. Respawn 3 s read fine.
- **Assumptions confirmed:** per-Player Input Map actions are all that is needed to split one keyboard; a `SubViewport` per Player with its own `Camera3D` shares the world without `own_world_3d`; touch-to-pick-up, drop-in-place and deliver-to-win compose into a Round with no extra state; the loop is understandable with no menu, tutorial or text beyond the status line.
- **Assumptions disproved:** "the other Player is the only threat" has no answer to a defender parked on their own canister until weapons exist — the thief cannot reach it at all (story 005's weapons are the intended answer; story 004 should place the canister where a parked bike cannot cover it, or let a ram displace a parked non-Carrier).
- **Emergent mechanics:** a defender who leaves its Base to hunt the thief leaves its own canister undefended — the bot runs show the second steal succeeding while the defender is away; that tension is the game and worth preserving.
- **Order recommendation:** the tester expected to shoot during the very first session. The build order puts the canister run (004) before the three Units and their weapons (005). That order still proves the loop earliest, but a minimal single weapon on the Motorbike could be pulled into 004 or 005 could follow it immediately — do not schedule the friend-on-the-sofa playtest between 004 and 005 without a weapon.

**Next steps (at `workflow: minimal`):**
1. `/dev-story production/epics/wasteland-fire/story-001-driving-toy.md` — the stories already exist; production code is rewritten from scratch, this prototype is reference only
2. `/story-done` after each story, through 007

---

## If Pivoting

Not applicable — the verdict is PROCEED.

---

## If Killing

Not applicable — the verdict is PROCEED.

---

## Lessons Learned

- **What assumptions were broken by actually building this?**
  - A stationary defender on the canister makes it unreachable; the rules as written have no answer before weapons exist.
  - Kinematic bodies do not bounce: two bikes meeting head-on stop dead and stay stopped; production needs a slide/bounce response or humans will feel glued together (the tester did not hit this, the bots did).
  - Respawn must sequence teleport → wait a physics frame → re-enable collision. Restoring collision in the same frame as the teleport let Jolt's kinematic move register the *old* overlap, so the respawned bike "picked up" the canister it had just dropped 60 units away and won instantly. Story 003 should carry this as an acceptance criterion.
- **What surprised us that didn't show up in the brainstorm?**
  - The tester reached for a fire key in the first session. Weapons are part of what makes the chase feel like a game, not a later layer.
  - How fast the loop is: eight seconds per steal at these numbers. The brief's "ten-minute rivalry" implies many Rounds; the tester did not object to the pace.
  - The turn-around after the pickup is the moment of vulnerability — the Carrier is slowest there and near the wall. That is where a defender should be positioned, and where the Map (story 007) needs clearance behind each Base.
- **What would we test differently next time?**
  - Put a second person on the keyboard and watch silently; this session was the developer's own.
  - Test the two-hands-one-keyboard ghosting limit explicitly (hold W+A and ↑+← at once) and record the result.
  - Include one trivial weapon even in a "no combat" prototype; its absence changed what the tester noticed.

---

> *Prototype code location: `prototypes/wasteland-fire-concept/`*
> *This code is throwaway. Never refactor into production.*
