# Story 004: Water Canister and the win

> **Epic**: Wasteland Fire — First Playable
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 4 — *Water Canister and the win: one canister per Base; only a Motorbike picks it up, by touching it; it drops where the Carrier is destroyed and never returns home on its own; a Player may carry their own canister back; delivering the opponent's canister to your own Base ends the Round. Per-Player HUD (hit points, canister status) and a Round-over screen with restart.*

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (the **Player goal & fail state** field + the MVP feature this story implements), scoped to this story:*

- [ ] AC-1: At Round start each Base holds one visible Water Canister in its Player's colour.
- [ ] AC-2: A Motorbike that touches a canister picks it up; the canister visibly rides on the Unit, which is now the Carrier. Pick-up is gated by a per-Unit `can_carry` flag in the Unit's data (true only for the Motorbike), not by a type check in code.
- [ ] AC-3: When the Carrier is destroyed, the canister drops at that spot and stays there; it never returns to its Base on its own.
- [ ] AC-4: A Player may pick up their own dropped canister and carry it back; entering their own Base with it re-seats it at the Base.
- [ ] AC-5: The Round ends the moment a Carrier holding the opponent's canister enters their own Base zone; the win is decided by delivery, nothing else (the goal and fail state of the brief).
- [ ] AC-6: A Round-over screen names the winning Player and offers restart on a key; restart resets both Units to their Bases, both canisters to their Bases, hit points and the HUD, and starts a new Round.
- [ ] AC-7: Each viewport has a HUD showing that Player's hit points and canister status: carrying the opponent's canister / own canister at home / own canister away (stolen or dropped).
- [ ] AC-8: All text and elements of the HUD and the Round-over screen fit inside a 640×720 viewport with no clipping or overflow.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers into the pinned engine reference, not decisions:*

- Canister = scene with `Area3D` + mesh; `body_entered` → if the body's stats say `can_carry`, attach (reparent to a mount `Marker3D` on the Unit); on the Carrier's `destroyed` signal, detach at the Carrier's global position.
- Base `Area3D` `body_entered`: if the body carries the opponent's canister → match controller `round_over(winner)`; if it carries its own → re-seat.
- Round state machine in the match controller (Running → Over); the Round-over screen and HUD listen to its signals — no polling.
- HUD per viewport: a `CanvasLayer`/`Control` inside each `SubViewport`; the project uses `canvas_items` / `expand` stretch (`project.godot`), so lay out with anchors, test at 640×720 per half.
- `docs/engine-reference/godot/modules/ui.md` § 4.7 Changes: `Control.custom_maximum_size` and offset transforms exist if HUD animation is wanted; accessibility calls moved to `AccessibilityServer`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: weapons — "the Carrier can shoot" is verified there; only-Motorbike-carries is enforced here by data and exercised there once other Units exist.
- Story 006: the Fuel gauge on the HUD.
- Story 007: the real arena; Bases stay greybox.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration test OR documented playtest: waived at `qa.level: minimal` — record one full canister run (steal, drop, recover, deliver) as a playtest note in `production/qa/evidence/story-004-water-canister-and-win-evidence.md`.
- Screenshots are not waived; this story touches screens, so retain a frame of each: both HUDs during play, a carry state, the Round-over screen — in `production/qa/evidence/story-004-water-canister-and-win/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 must be DONE
- Unlocks: Story 005 (and the vertical-slice playtest: two Motorbikes, two Bases, one canister run)
