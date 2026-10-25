# Story 052: A Teammate's Unit in play holds its Token

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**Requirement**: Martin, 2026-10-25: "Ked 2 hraci hraju spolu, obaja maju moto a jedna z nich zomre, prehrali. To by tak nemalo byt. Az ked obe zomru." (When two Players play together, both on Motorbikes, and one of them dies, they have lost. It should not be so: only when both die.)

Cause: a Token is taken when a Unit is destroyed, never when it spawns, and a Team shares one stock (story 048). `can_choose()` asked only whether the Team had a Token left, so with one Motorbike Token left both Teammates could take a Motorbike; the first to fall took the last Token and the Team lost with the second still driving.

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: With both Teammates on Motorbikes, the first to fall does not end the Round.
- [x] AC-2: A Teammate's Unit in play, or chosen and waiting to appear, holds one Token of its type: a Player may take a type only while `tokens_free()` (the Team's Tokens left less those held by Teammates) is above 0; the choice panel shows that count and dims a type with none free.
- [x] AC-3: The Team loses when its last Motorbike falls with no Motorbike Token left; the other Team wins.
- [x] AC-4: With one Player per Team nothing changes (the regression).

---

## Implementation Notes

- `MatchController.tokens_free()`; `can_choose()` asks it. `UnitChoice` shows it and refreshes on a Teammate's choice, spawn, destruction and swap as well as the Player's own.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `teams_last_carrier` R1–R3 (a seeded defect, `can_choose()` back on `tokens_left()`, fails R2); the regression.

**Status**: [x] Created 2026-10-25: `production/qa/evidence/story-052-last-carrier-of-a-team-evidence.md`

---

## Dependencies

- Depends on: story 048 (Teams), story 008 (Tokens).
- Unlocks: none.
