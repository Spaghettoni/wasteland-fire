# Story 042: Secondary weapons on LT: Mines, nitro, smoke screen

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-22

## Context

**GDD**: `design/rules.md` ("Secondary weapons"); `CONTEXT.md` (Secondary weapon, Nitro, Smoke screen)
**Requirement**: Martin, 2026-10-22: "rovnako by som chcel aby malo kazde vozidlo secondary zbran. truck ma miny - lavy ukazovak. motorka mozno moze lavym ukazovakom dropnut flag. bugina neviem co, vrtulnik neviem co - kludne navrhni" (every vehicle should have a secondary weapon; the Truck has Mines on the left index finger; the Motorbike maybe drops the Flag; Buggy and Gyrocopter: propose something). His answers: "1. ano 2. skusme nitro 3. dajme ze velka dymova clona - gyro bude v strede a nikto nebude vediet kam poleti 4. zatial nic" (1. yes, LT is the secondary and no longer fires; 2. try nitro; 3. a big smoke screen, the gyro sits in the middle and nobody knows where it will fly; 4. nothing for the Motorbike for now).

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM

---

## Acceptance Criteria

- [x] AC-1: The secondary key is E (Player 1), Comma (Player 2) and a pad's LT; LT no longer fires and X is bound to nothing. The Truck lays a Mine on it, as before.
- [x] AC-2: The Buggy's nitro: 2 s at 1.6 times its top speed and acceleration forward, then 8 s before it fires again; unlimited; every new Buggy has it ready.
- [x] AC-3: The Gyrocopter's smoke screen: dropped where it is, radius 12 m, 6 s with a 1.5 s fade; 2 per Gyrocopter, none refilled. It hides everything in and behind it from both views and from every Turret, ground Units and the Gyrocopter alike; nothing collides with it; a restart clears it.
- [x] AC-4: The Motorbike's secondary key does nothing.
- [x] AC-5: Each view shows the secondary's state: "Nitro ready", "Nitro!", "Nitro in N s", "Smoke N / 2"; nothing for a Truck (its Mines line stays) or a Motorbike.
- [x] AC-6: All values are data (`buggy_stats.tres`, `gyrocopter_stats.tres`, `smoke_settings.tres`, `turret_stats.tres` sight masks 416 / 256, `pad_layout.tres`, `project.godot` layer 9 "smoke"); the older scenarios keep their outputs unless they declare `SECONDARY`.
- [x] AC-7: The look: frames of the nitro and of the smoke screen.

---

## Implementation Notes

- `NitroBooster` and `SmokeLauncher` (`src/gameplay/secondary/`), one of each per Player under `World`, read `<prefix>lay_mine` on its press and follow their Unit's type like `MineLayer`. `Unit.boost_speed(share)` multiplies the forward top speed and the acceleration for one tick.
- `SmokeCloud`: nine puffs scaled to the radius, opaque until its fade; a `StaticBody3D` on layer 9 that only Turret sight rays test. `SplitScreen` frees the `smokes` group on `round_started`.
- `SecondaryStatus` in each view, where the Mines line sits (the two never show together).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `secondary` (X1 to X5), twice byte-identical; two frames in `production/qa/evidence/story-042-secondary-weapons/`; the regression of every older scenario; Martin's play.

**Status**: [x] Created 2026-10-22: `production/qa/evidence/story-042-secondary-weapons-evidence.md`

---

## Dependencies

- Depends on: story 014 (Mines), story 041 (the pad layout's fire bindings).
- Unlocks: story 044 (the secondaries recharge in 15 s, the Motorbike drops the Flag), which changes the counts and times above.
