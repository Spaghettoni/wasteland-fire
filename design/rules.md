# Wasteland Fire: rules and mechanics

Source: the "Wasteland Fire" artifact (https://claude.ai/artifact/3dVGdvULzywJvn8GDLEXDP), pasted by the author on 2026-09-29 and translated from Slovak. Only rules and mechanics were taken from it. Input devices, visual fidelity and process conventions are decided in conversation, not taken from the source. Items marked "decided 2026-09-29" were settled in conversation the same day. When the artifact changes, update this file in the same change.

## Objective

Two players, each with their own Base. A player wins the Round the moment they deliver the opponent's Water Canister (the "flag") to their own Base.

## Units: rock, paper, scissors

| Unit | Role | Beats | Loses to |
|---|---|---|---|
| Motorbike (motorka) | Fast, weak, the only Unit that carries a Water Canister | Buggy, by going around it; more agile | Gyrocopter |
| Buggy (ozbrojená bugina) | Heavy, anti-aircraft machine gun | Gyrocopter | Motorbike |
| Gyrocopter (gyrokoptéra) | Flies over terrain, shoots from above; burns Fuel fastest | Motorbike | Buggy |

- The triangle is confirmed as written (decided 2026-09-29).
- The Motorbike is the only Carrier (decided 2026-09-29).
- How "beats" works (decided 2026-09-29): Units have hit points. Damage follows an explicit table: double damage against the Unit you beat, half damage against the Unit you lose to, normal damage against your own type. One hard rule sits on top: only the Buggy's gun can hit the Gyrocopter. Exact hit points, damage and speeds are tuning values, not rules.

## Resources

- **Fuel.** Every Unit consumes Fuel while moving; the Gyrocopter consumes the most. Without Fuel a Unit can neither drive nor fly. Fuel Cans respawn at fixed places on the Map.
- **Running out of Fuel (decided 2026-09-29).** A ground Unit with no Fuel stops but can still turn and fire. A Gyrocopter with no Fuel crashes and counts as destroyed. Every Unit has a self-destruct action so a stranded player can respawn.
- **Water.** One Water Canister sits in each Base. When the Carrier is destroyed, the canister stays lying where it was.
- **Handling the Water Canister (decided 2026-09-29).** A Motorbike picks a canister up by touching it. A player may carry their own canister back to their Base after it was stolen and dropped. The Carrier can shoot. A dropped canister never returns home on its own.

## Destruction, respawn and unit swap

- A destroyed Unit respawns at its player's Base.
- Respawns are unlimited, after a delay of about three seconds (tuning value). The player picks the Unit type at every spawn. Driving into your own Base lets you swap Unit type without dying. A fresh Unit spawns with a fixed partial tank of Fuel, so dying is never a free refuel (decided 2026-09-29).

## Hazards

None in the First Playable. The other player is the only threat; turrets, mines, drones and AI units are excluded (decided 2026-09-29).

## First Playable (the source's "version 0.1")

- Local split screen for two players; no online multiplayer. Input is keyboard only for now (decided 2026-09-29).
- One small Map.
- Three Units, respawning at the Base after destruction.
- Fuel and Water as above.
- Win: deliver the opponent's Water Canister to your own Base.
- Online play, AI bots and further maps are outside the First Playable.

## Tuning values to set during prototyping (not rules)

Hit points per Unit; damage per weapon; speed, acceleration and turn rate per Unit; Fuel capacity, burn rate per Unit and starting tank at spawn; Fuel Can amount, spawn points and respawn time; respawn delay; Map size.
