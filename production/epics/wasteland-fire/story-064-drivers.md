# Story 064: A driver in every vehicle

> **Epic**: Wasteland Fire — First Playable
> **Status**: Done
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-22

## Context

**Requirement**: Martin, 2026-11-22: "paci sa mi aj to ze tam je ten panak hore. chcem aby v kazdom vozidle bolo vidno panaka."

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: Every vehicle shows its driver: a chunky low-poly figure, a little over life size, with a Team-coloured helmet and shoulder pads, dark goggles, a beard, a leather vest and bare arms in gloves. The rider leans to the Motorbike's grips with his feet on the pegs; the Buggy's driver holds the wheel in the left seat; the Gyrocopter's pilot holds the stick; the Flame Tank's driver stands in the ring behind the rocket pod.
- [x] AC-2: The drivers are part of each model's file (`wasteland_kit.driver()`), so they are painted, shaded and turn with the model like the rest of it.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: frames of each vehicle in the chase view.

**Status**: [x] `production/qa/evidence/story-063-064-evidence.md`
