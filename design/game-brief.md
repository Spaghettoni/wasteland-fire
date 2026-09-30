# Game Brief: Wasteland Fire

<!--
THE ONE-PAGE BRIEF. At the `minimal` workflow tier this is the ENTIRE design doc —
it replaces the full concept doc, systems decomposition, and per-system GDDs.
Rules of record: design/rules.md (translated from the author's Slovak source).
Vocabulary: CONTEXT.md — Player, Base, Water Canister, Carrier, Round, Unit,
Motorbike, Buggy, Gyrocopter, Self-destruct, Fuel, Fuel Can, Map, First Playable.
Engine is set separately (project.yaml / /setup-engine) — not restated here.
Written 2026-09-30 by /brainstorm (Lean Brief flow, autonomous run).
-->

**One-sentence pitch:** Two friends on one couch drive wasteland Motorbikes, Buggies and Gyrocopters across a split screen to steal each other's Water Canister and haul it home before the Fuel runs dry.

## Core loop
- Spawn at your Base, pick a Unit (Motorbike, Buggy or Gyrocopter) and drive out, burning Fuel.
- Hunt the other Player with the Unit that beats theirs; grab Fuel Cans to keep moving.
- Reach their Base on a Motorbike, touch their Water Canister and carry it home while they chase you.
- Get destroyed → respawn at your Base about three seconds later with a partial tank, pick a Unit, go again.

## Player goal & fail state — what "working" looks like
- Goal: deliver the opponent's Water Canister to your own Base — the Round ends the moment it arrives.
- Fail: the opponent delivers yours first. Nothing else ends a Round: destroyed Units respawn without limit, a stranded Unit can Self-destruct, and a dropped canister stays where it fell until a Motorbike touches it.

## MVP — what must exist to be the game
<!-- Each item becomes one story; numbered in build order. -->
1. **Driving toy** — one Motorbike on a greybox plane: keyboard throttle and steering, chase camera, arcade kinematic movement that is fun to drive for five minutes.
2. **Split screen for two** — two side-by-side viewports, one Unit and one fixed keyboard layout per Player, both driving at once.
3. **Bases, destruction and respawn** — two greybox Bases; a destroyed Unit respawns at its Player's Base after a delay of about three seconds (tuning value); a Self-destruct action so a stranded Unit can respawn.
4. **Water Canister and the win** — one canister per Base; only a Motorbike picks it up, by touching it; it drops where the Carrier is destroyed and never returns home on its own; the Carrier can shoot; a Player may carry their own canister back; delivering the opponent's canister to your own Base ends the Round. Per-Player HUD (hit points, canister status; the Fuel gauge arrives with item 6) and a Round-over screen with restart.
5. **Three Units and the triangle** — Motorbike, Buggy and Gyrocopter with hit points and one weapon each; damage ×2 against the Unit you beat, ×½ against the Unit you lose to, ×1 against your own type; only the Buggy's gun can hit the Gyrocopter; the Gyrocopter flies over terrain; Unit type is chosen at every spawn, and driving into your own Base swaps it without dying.
6. **Fuel and Fuel Cans** — every Unit burns Fuel while moving, the Gyrocopter fastest; an empty ground Unit stops but can still turn and fire; an empty Gyrocopter crashes and counts as destroyed; a fresh Unit spawns with a fixed partial tank; Fuel Cans at fixed Map spots refill and respawn.
7. **The Map** — one small arena holding both Bases and the Fuel Can spawn points, dressed with a ready-made low-poly kit so it reads as one coherent wasteland.

## Out of scope — not building this
- No online play, no AI bots or drones, no turrets or mines — the other Player is the only threat.
- No second Map, no map editor, no destructible buildings.
- Keyboard only: no gamepad support, no key-rebinding UI.
- No music or sound, no custom-made art (ready-made kits only), no menus beyond the Round-over screen, no save or settings, no export or Steam work — run from the editor or a local build.
- Nothing from Return Fire that the rules dropped: no flag hunt in towers, no ammo or repair economy, no radar.

## Build order
1. Driving toy — stop when one Motorbike is fun to drive for five minutes; nothing else matters until it is.
2. Split screen for two.
3. Bases, destruction and respawn.
4. Water Canister and the win — with 1–3 this is the vertical slice: two Motorbikes, two Bases, one canister run. Put a friend on the sofa here, before the triangle exists.
5. Three Units and the triangle.
6. Fuel and Fuel Cans.
7. The Map — greybox stays until the loop is proven; the low-poly dressing comes last.

---
**Who it's for / what they feel:** Two friends on one couch who want a ten-minute rivalry — the panic of being chased with the canister and the grin of stealing it back.

**Art & audio direction:** Ready-made low-poly kits (Kenney, Quaternius), flat-shaded palette textures in rust, dust and sun-bleached bone; no audio in the First Playable.

**Reference game:** Return Fire (1995) — its two-player split-screen capture run with vehicle counters; the MVP keeps the canister run and the Unit triangle and drops towers, turrets, mines, the hidden-flag hunt and the classical soundtrack.
