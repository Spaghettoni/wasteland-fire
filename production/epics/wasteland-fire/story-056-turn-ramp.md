# Story 056: A turn on the spot picks up speed

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**Requirement**: Martin, 2026-10-25, after his first Round on Map 03: "je tazke mierit ked stojis teraz, kedze sa vozidla rychlo otacaju ... ked stlacis, zacne sa otacat pomaly a za nejaky cas to naberie rychlost a otaca sa rychlejsie (it is hard to aim standing, the Units turn fast; when you press, start slow and pick up speed)".

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: A steer held while turning on the spot starts at `spot_turn_start_share` (0.25) of the spot rate and rises evenly to all of it over `spot_turn_ramp_seconds` (0.5 s), every type.
- [x] AC-2: A release, or a steer the other way, starts it over.
- [x] AC-3: A rolling Unit's turn has no ramp.

---

## Implementation Notes

- `UnitStats.spot_turn_ramp_seconds`, `spot_turn_start_share`; `Unit._ramp_spot_turn()`. The runner gives the older scenarios no ramp unless they declare `TURN_RAMP`.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `turn_ramp` R1 to R3; the regression.

**Status**: [x] Created 2026-10-25: `production/qa/evidence/story-058-maps-cleanup-evidence.md` (shared by stories 055 to 058)

---

## Dependencies

- Depends on: stories 053 and 054.
- Unlocks: none.
