# Story 057: The Flag is delivered to the Garage

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**Requirement**: Martin, 2026-10-25, after his first Round on Map 03: "vlajka sa musi doviezt do garaze aby sa vyhralo, nie do pevnosti (the Flag must be brought to the Garage to win, not to the fortress)".

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: On Map 03 a carried enemy Flag wins in the own Garage's zone and not in the own fortress.
- [x] AC-2: The own Flag is brought home to the Garage too and goes back to its seat in the fortress.
- [x] AC-3: The fortress's zone (`Base.flag_zone`) keeps Mines away; Maps 01 and 02 are unchanged.

---

## Implementation Notes

- `MatchController._apply_deliveries()` asks `is_in_own_zone()` again; `Base.delivery_zone()` and `FlagRules.is_in_flag_zone()` are gone.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `map_03` A4 (Garage wins, fortress does not); the regression.

**Status**: [x] Created 2026-10-25: `production/qa/evidence/story-058-maps-cleanup-evidence.md` (shared by stories 055 to 058)

---

## Dependencies

- Depends on: stories 053 and 054.
- Unlocks: none.
