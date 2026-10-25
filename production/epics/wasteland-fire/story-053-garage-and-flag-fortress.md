# Story 053: The Garage and the Flag fortress may be two places

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**Requirement**: Martin, 2026-10-25, for the islands Map: "spravme to tak, ze jedna vec je garaz a ina je vlajkova pevnost" (let one thing be the Garage and another the flag fortress); "chcem to skusit tak ze garaz bude v 1 rohu a vlajka co sa snazis ukradnut bude v protilahlom".

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: A Base may name a flag zone (`Base.flag_zone`) apart from its zone: a carried enemy Flag wins in the flag zone, not in the Garage's zone; the own Flag goes home there.
- [x] AC-2: The Swap stays in the Garage's zone.
- [x] AC-3: No Mine is laid in or before either zone.
- [x] AC-4: A Base without a flag zone (Map 01, Map 02) works as before.

---

## Implementation Notes

- `Base.flag_zone` and `delivery_zone()`; `FlagRules.is_in_flag_zone()` for deliveries; `MineLayer.is_in_no_mine_area()` keeps both zones clear.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `map_03` A4 (delivery in the fortress, not in the Garage; the Swap in the Garage, not in the fortress); `mines`, `flag_open`, `teams` and the regression unchanged.

**Status**: [x] Created 2026-10-25: `production/qa/evidence/story-054-map-03-archipelago-evidence.md` (shared with story 054)

---

## Dependencies

- Depends on: story 004 (delivery), story 011 (Swap), story 014 (Mines).
- Unlocks: story 054.
