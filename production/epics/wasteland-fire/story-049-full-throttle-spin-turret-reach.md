# Story 049: Full throttle on a leaned stick, a faster spot turn, a longer Turret reach

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**Requirement**: Martin, 2026-10-25, after a test: "ked zatocis packou na ovladaci - tak sa znizi rychlost. to nechceme, chcem bolo teda jedno ci drizis packu dopredu alebo hore do polky alebo uplne, nema to mat vplyv na rychlost. ale mozme spravit ze vozidlo bude samo gradualne zrychlovat bez ohladu na zatacianie. ale to zrychlenie by malo mat rychly nabeh do maxima." (steering with the stick slows the Unit; however far up the stick is, the speed must not change; the Unit may ramp up by itself, quickly); "ked sa otacas na mieste malo by to byt rychlejsie ako teraz" (turning on the spot should be faster); "vezicka ma o kusocek kratsi dostrel ako vozidla" (the Turret reaches a little less far than the Units).

His answers the same day: keep the acceleration as it is (about 1.1 to 1.2 s to top speed), turn on the spot 1.5 times as fast, and give the Turret a little more reach than any Unit.

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: On a pad the stick held straight up, half up, just past `full_throttle_from` (0.4) or leaned up and sideways gives the Unit the same speed as the keyboard's throttle key; just short of it gives none, so a stick leaned sideways with a little up still turns on the spot. Reverse the same. Steering stays analog; the acceleration is the type's as before.
- [x] AC-2: Every type turns on the spot at 1.5 times its old rate (three quarters of its `turn_rate`): Motorbike 2.10, Buggy 1.73, Truck 0.67, Gyrocopter 1.16 rad/s. The empty-tank turn rate stays as it was.
- [x] AC-3: The Turret's range is 45 m (was 35 m), so it reaches 46.6 m to a target's centre, beyond every type's reach to its centre (the Truck's 43.8 m): a Truck as far out as its Shots reach the drum is fired on and hit.
- [x] AC-4: The 108 earlier scenarios differ from story 048's outputs only where these numbers show.

---

## Implementation Notes

- `PlayerDriveInput` rounds the throttle to -1, 0 or +1 (`signf`); a key is 1 already.
- `PadLayout.full_throttle_from` and `full_throttle_suffixes` (throttle, reverse) in `pad_layout.tres`: `PadAssignment` gives those actions that dead zone on a pad (`PadLayout.deadzone_for()`), every other action keeps 0.2.
- `spot_turn_rate` in the four `*_stats.tres`; `weapon_range` in `turret_stats.tres`.
- Evidence changes: `turrets` reach check moved from 50 to 30 degrees off the rest heading (at 45 m the canyon's south rock stands in the old line, 37.6 m out) with offsets of 0.15 m from the range; `turrets_data` expects a 45 m range instead of the Buggy's; `turrets` damage's Truck-outranges-the-Turret line is turned round (the Turret now answers); `pads_stick` predicts the half-up strength from the throttle's own dead zone.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `full_throttle` T1–T3; `pads_stick`, `spot_turn`, `turrets`; the regression; Martin's test on Windows with a pad.

**Status**: [x] Created 2026-10-25: `production/qa/evidence/story-049-full-throttle-spin-turret-reach-evidence.md`

---

## Dependencies

- Depends on: story 040 (the left stick drives), story 009 (turning on the spot), story 013 (Turrets).
- Unlocks: none.
