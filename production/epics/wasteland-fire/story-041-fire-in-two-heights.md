# Story 041: Shots in two Heights: low at ground Units, high at the Gyrocopter

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-22

## Context

**GDD**: `design/rules.md` ("Heights", "Camera and controls"); `CONTEXT.md` (Height, Tall piece)
**Requirement**: Martin, 2026-10-22: "hitbox bude rozdeleny - gyro hore, vozidla dole, vezicky cez obe vysky. a teda strielat sa bude dat ukazovakom dole a ukazovakom na tom mensom buttone hore. tak isto treba pridat klavesy na to" (the hitbox will be split: the gyro high, the vehicles low, the turrets through both heights; you fire low with the index finger on the trigger and high with it on the smaller button above; keys are needed for it too). His answer of the same day: a high shot flies over the walls and the cover ("1. ano").

Until now every Shot flew at one height and hit every Unit (story 020: every hit volume spans both Heights).

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM

---

## Acceptance Criteria

- [x] AC-1: A low Shot hits ground Units and never the Gyrocopter; a high Shot hits the Gyrocopter and never a ground Unit.
- [x] AC-2: A Turret stands through both Heights: low and high Shots both damage it.
- [x] AC-3: A high Shot flies over every low piece (Wall Panels, Flag Walls, cover, wrecks, small buildings, cliffs, water); a Tall piece (corner towers, water tower legs, Fuel tanks, Turrets, the Map's edge) stops it. A low Shot stops where every Shot stopped before.
- [x] AC-4: A Turret fires high at a Gyrocopter (so a wall no longer hides one from it) and low at a ground Unit, as before.
- [x] AC-5: Inputs: low fire as before (Space / Period, a pad's RT, LT and A), high fire on Left Shift (Player 1), Right Shift (Player 2) and a pad's RB; both from the same load at the type's cadence.
- [x] AC-6: A high Shot's tracer is drawn 2.9 m above the flight line, at the Gyrocopter's height; the hit test stays at the one shooting height (0.5 m), against colliders that stand through both Heights.
- [x] AC-7: All data (`match_rules.tres`: low mask 67, high mask 17, lift 2.9; `project.godot`; `pad_layout.tres`); the older scenarios keep their outputs unless they declare `FIRE_HEIGHTS`.

---

## Implementation Notes

- `MatchRules.shot_collision_mask` (low: map, units, cover) and `high_shot_collision_mask` (map, gyrocopters); `shot_mask(high)`; `high_shot_lift`.
- `Weapon.set_high_trigger()`; with both triggers held the high one wins. `PlayerFireInput` reads `<prefix>fire_high` when the action exists.
- `Turret._target_mask()` picks the mask by the target's `can_fly` for its sight, its path test and its Shots.
- `Shot.lift_tracer()` raises the drawn tracer only.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `fire_heights` (H1 to H7), twice byte-identical; two frames in `production/qa/evidence/story-041-fire-in-two-heights/`; the regression of every older scenario; Martin's play.

**Status**: [x] Created 2026-10-22: `production/qa/evidence/story-041-fire-in-two-heights-evidence.md`

---

## Dependencies

- Depends on: story 020 (two Heights), story 040 (the pad layout).
- Unlocks: story 042 (secondary weapons on LT).
