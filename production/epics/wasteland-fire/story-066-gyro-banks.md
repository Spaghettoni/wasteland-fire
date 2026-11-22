# Story 066: The Gyrocopter banks into turns

> **Epic**: Wasteland Fire — First Playable
> **Status**: Done
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: XS
> **Last Updated**: 2026-11-22

## Context

**Requirement**: Martin, 2026-11-22: "Este by sa mi pacilo keby sa gyrokoptera naklanala podobne ako motorka".

## Acceptance Criteria

- [x] AC-1: The Gyrocopter's drawn body banks into a turn (up to 18°) and dips its nose a little when it speeds up, on springs like the Motorbike (UnitBodyMotion), and does not bob.
- [x] AC-2: It tilts about its model's origin, so its drawn height stays the hover height; its collider, Shots and height are untouched.

## Test Evidence

`mines_gyro_065` G1 (rolled 18.7°, origin off its height by 0.0000 m); `production/qa/evidence/story-065-066/gyro-banks-into-turn.png`.
