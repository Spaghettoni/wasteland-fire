# Story 063: The Flame Tank replaces the Truck

> **Epic**: Wasteland Fire — First Playable
> **Status**: Done
> **Layer**: Feature
> **Type**: Logic + Visual/Feel
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-22

## Context

**Requirement**: Martin, 2026-11-22, with a picture he made: "paci sa mi plamenomet. a mohol by to byt take nieco na pasoch ... vymenme terajsi truck za toto. plamene ale musi palit dostatocne pred seba. ... do vysky bude zatial strielat rakety ako doteraz." His answers: 20 m; "pali vsetkych ale Teba nie. nebude ostavat na zemi ale bude ostavat na veziach, budovach, muroch, nepriatelskych vozoch. 5s a bude davat polovicny dmg over time"; the Mines stay; the world's new look comes later.

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM (a new kind of fire; old scenarios fire the Truck)

---

## Acceptance Criteria

- [x] AC-1: The Truck type (id `truck`, its collider, speed, hit points, Tokens and Mines unchanged) is drawn as a tracked Flame Tank in the concept's style: tracks with road wheels and spiked guards, a Team glacis with a skull over a barred grille and a ram of spikes, a flamethrower nozzle each side, a Team fuel drum with skulls, exhaust stacks, a rocket pod on a pintle and its driver on top. Its name in the game is Flame Tank.
- [x] AC-2: Its low fire is a flamethrower: glowing puffs from the two nozzles in turn, slightly spread, that reach 20 m past the nozzles and swell and cool as they fly. 2.5 damage a puff, 12.5 puffs a second (31 a second before the matrix, the Truck's old rate).
- [x] AC-3: The flames burn everybody but the one who fires: the shooter's Teammates' Units too; Structures as Shots do.
- [x] AC-4: What the flames hit keeps burning for 5 s after the last puff, at half the flame's damage a second (times the matrix), with flames and smoke on it: a Structure (Turret, building, wall), or a Unit of the other Team. Fires do not stack; they go out when the target falls or leaves play. Nothing burns on the ground.
- [x] AC-5: Its high fire is the red rockets as before (25 damage, 0.8 s, 40 m). Its load is 250: a puff spends 1, a rocket 10 (20 s of flame or 25 rockets).

---

## Implementation Notes

- `tools/blender/build_truck.py` rewritten (the Flame Tank); `wasteland_truck.glb` rebuilt.
- `UnitStats`: `high_ammo_cost`, the Flamer group (`flame_shot_scene`, `flame_damage`, `flame_interval_seconds`, `flame_range`, `flame_speed`, `flame_nozzle_side`, `flame_spread_degrees`, `burn_seconds`, `burn_share`). `truck_stats.tres`: the numbers, the name, track contacts for the tyre tracks.
- `Weapon._fire_flame()`, `Weapon.burning_scene`; `FlameShot` (`flame_shot.tscn`, `spatial_fx_flame.gdshader`); `Burning` (`burning.tscn`).
- Evidence runner: scenarios without `FLAME_TANK` keep the Truck's old weapon, load, name and tyre contacts (`_apply_flame_tank_off()`).

---

## Test Evidence

**Story Type**: Logic + Visual/Feel
**Required evidence**: `flame_tank` F1–F4; frames from a windowed run; the regression.

**Status**: [x] `production/qa/evidence/story-063-064-evidence.md`

---

## Dependencies

- Depends on: stories 005, 022, 041, 061.
- Unlocks: the world's new look (next).
