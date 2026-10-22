# Story 046: Every wall for both sides, a smaller Flag, white bars

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-22

## Context

**GDD**: `design/rules.md` ("Every wall for both sides; a smaller Flag; white bars")
**Requirement**: Martin, 2026-10-22, after playing story 045's build: "vlajka by mala byt mensia, prilis ju vidno v kricku" (the flag should be smaller, it shows too much in a bush); "truck aj gyro maju zlty bar, nie biely" (the Truck and the Gyrocopter have a yellow bar, not white); "chcem aby uplne vsetky mury boli rovnake a znicitelne pre obe strany" (I want absolutely every wall the same and breakable for both sides). He also asked whether the colours look muted (answered with a before / after proposal, not changed here).

Reading taken: "every wall" is every Wall Panel and Flag Wall (they already share one look and one data file); the corner towers and the Turrets are not walls and keep their rules.

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: A Player's own Shots damage that Player's walls (Wall Panels, Flag Walls); every wall shares `flag_wall_stats.tres`, now `spared_by_owner = false`. A Turret still takes nothing from its own Player.
- [x] AC-2: The Flag's pole is 1.9 m and its cloth 1.32 by 0.7 m (top of the Flag 1.9 to 2.2 m above its seat); a Motorbike carrying it in a Bush shows at most a sliver of cloth.
- [x] AC-3: Every secondary bar is white on grey with a dark edge.
- [x] AC-4: The older scenarios keep their outputs (the runner spares owners again unless a scenario declares `SECONDARY`).

---

## Implementation Notes

- `StructureStats.spared_by_owner` (default true), `Structure.spares_owner`; `Shot._damage_target()` skips a piece of the shooter's Player only when it spares its owner.
- `flag.tscn` resized; `real_flag` F1 now expects 1.9 to 2.2 m.
- `secondary_status.tscn` gives every style the boost's white on grey.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `secondary` X7 (new), `real_flag` F1; frames in `production/qa/evidence/story-046-walls-flag-bars/`; the regression.

**Status**: [x] Created 2026-10-22: `production/qa/evidence/story-046-walls-flag-bars-evidence.md`

---

## Dependencies

- Depends on: stories 039, 043, 045.
- Unlocks: none.
