# Story 067: Every weapon hurts every vehicle alike

> **Epic**: Wasteland Fire — First Playable
> **Status**: Done
> **Layer**: Core
> **Type**: Config/Data
> **Estimate**: XS
> **Last Updated**: 2026-11-22

## Context

**Requirement**: Martin, 2026-11-22: "vidim, ze naozajstne rozdiely su v pohyblivosti a type zbrani. a to je dobre. nechcem aby niektore vozdidla uberali niektorym viac a niektorym menej. to dajme prec. stale by mal byt rozny pocet hp."

## Acceptance Criteria

- [x] AC-1: The damage matrix holds no multiplier between Unit types: every Shot, flame and burn does its own damage to every type (the triangle buggy > truck > gyrocopter > buggy is gone).
- [x] AC-2: The types keep their own hit points (Motorbike 40, Buggy 100, Flame Tank 220, Gyrocopter 70).

## Test Evidence

`flame_tank` F6 (and F2 now expects the burn at 1.0). Older scenarios keep the triangle in memory unless they declare `FLAT_DAMAGE`.
