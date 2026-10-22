# Story 040: On a pad the left stick drives and the triggers fire

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S (one data file and the evidence)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-22

## Context

**GDD**: `design/rules.md` ("Camera and controls"); story 032 (Xbox controllers)
**Requirement**: Martin's request of 2026-10-22, made in a session: "chcem aby pohyb fungoval s lavou packou na controlleri, teda aj dopredu/dozadu. ukazovakom sa bude strielat" (I want movement to work with the left stick on the controller, forward and back too; the index finger will fire).

Story 032 put the throttle on RT, the reverse on LT and the steering on the left stick (and the D-pad), with A to fire.

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: The left stick drives: up is the throttle and down the reverse, both analog past the dead zone (0.2) as the triggers were; left and right still steer (and move the Unit choice); the D-pad still steers.
- [x] AC-2: Either trigger fires ("ukazovák", the index finger), and so does A, which also still confirms the Unit choice; neither trigger drives any more.
- [x] AC-3: Every input stays data (`pad_layout.tres`); the hints keep naming the stick and A.
- [x] AC-4: The older evidence scenarios keep their outputs: the runner gives them the layout of stories 032 to 039 (`tools/evidence/frozen/pad_layout_story_032.tres`) unless they declare `STICK_DRIVE`.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: the scenario `pads_stick` (S1 to S4), twice byte-identical, in `production/qa/evidence/story-040-left-stick-drives/`; `pads`, `pads_data` and `pads_showcase` unchanged against story 039's tree; Martin's check on his pads.

**Status**: [x] Created 2026-10-22: `pads_stick.txt` (S1: stick up 1.000 and 10.17 m forward in 60 ticks, half up 0.375, stick down 1.000 and 4.41 m back, Player 2 still, stick left turns 0.700 rad; S2: RT, LT and A each fire 2 Shots in 20 ticks and press no drive action; S3: the hint reads "Stick left / Stick right to choose, A to confirm"; S4: the data). Seeded: the two trigger bindings left out → S2, S4 fail.

---

## Dependencies

- Depends on: story 032.
- Unlocks: None.
