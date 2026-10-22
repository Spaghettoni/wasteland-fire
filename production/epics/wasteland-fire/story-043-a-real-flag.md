# Story 043: A real flag

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-22

## Context

**GDD**: `design/rules.md` ("A real flag"); `CONTEXT.md` (Flag)
**Requirement**: Martin, 2026-10-22: "(spravme z toho flag btw)" and "vlajka je teraz kanister, spravme z nej realnu vlajku" (the Flag is a canister now; make it a real flag). The rules of the Flag do not change.

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: The Flag is a steel pole about 3 m tall with a cloth in its owner's Team colour (every panel painted), on a steel foot while it stands on its seat.
- [x] AC-2: The cloth waves (four hinged panels, each turning a little about the pole's axis, the wave running out from the pole).
- [x] AC-3: A Motorbike carries it like a banner, the cloth streaming behind; no foot.
- [x] AC-4: A dropped Flag is planted: the mast leans 9° and sinks 0.25 m, no foot; seated again it stands upright on its foot. The rules (pick-up, drop, delivery) are unchanged.
- [x] AC-5: The look: frames of the Flag on its seat, carried, planted, and close-ups.

---

## Implementation Notes

- `flag.tscn` rebuilt: `Stand`, `Mast` (`Pole`, `Finial`, `Cloth` with `Hinge1`..`Hinge4`, each with a panel), `PickupZone` unchanged. `body_mesh` is the first panel; `cloth_meshes` the others.
- `Flag` gains exports for the look (`wave_amplitude`, `wave_speed`, `wave_phase`, `drop_tilt_degrees`, `drop_sink`, `carry_yaw_degrees`) and `_show_state()` called by `carry_by()`, `drop_at()`, `seat_at()`.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `real_flag` (F1 to F4); five frames in `production/qa/evidence/story-043-a-real-flag/`; `flag_run`, `flag_open` and the flag scenarios of the regression; Martin's sign-off.

**Status**: [x] Created 2026-10-22: `production/qa/evidence/story-043-a-real-flag-evidence.md`

---

## Dependencies

- Depends on: story 004 (the Flag), story 039 (the open Flag).
- Unlocks: none.
