# Story 039: No Turret locks a Flag, and the Motorbike breaks walls

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (two data lines and the evidence)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-21

## Context

**GDD**: `design/rules.md` ("Turrets, Flag Walls and Mines"); `CONTEXT.md` (Turret, Flag Wall, Wall Panel)
**Requirement**: Martin's request of 2026-10-21, made in a session: "to pravidlo ze treba znicit vezicky aby sa dala ukradnut vlajka chcem prec. a aby aj motorka moze nicit veze aj mury" (I want the rule that the Turrets must be destroyed before the Flag can be stolen gone; and the Motorbike should be able to destroy the Turrets and the walls too).

Today a Base's Flag cannot be taken while a Turret of that Base stands (story 013's hard rule: `TurretStats.locks_flag`, read by FlagRules) and the Motorbike's Shots do nothing to a Wall Panel or a Flag Wall (the damage matrix's `motorbike>flag_wall` 0.0, story 012). The Motorbike's Shots already damage a Turret (no pair is listed for it: 20 Shots break one).

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none

---

## Acceptance Criteria

- [x] AC-1: A Flag can be taken while its Base's Turrets stand: `turret_stats.tres` sets `locks_flag` false, so FlagRules never locks one and the "Destroy the turrets first" line never shows; the code stays, gated by the data.
- [x] AC-2: The Motorbike's Shots damage the other Player's Wall Panels and Flag Walls at the full multiplier: the pair `motorbike>flag_wall` is gone from `damage_matrix.tres` (its default, 1.0); its own Player's pieces still take no damage.
- [x] AC-3: The Motorbike's Shots still damage a Turret.
- [x] AC-4: The older evidence scenarios keep their outputs: the runner puts the lock and the pair back unless a scenario declares `FLAG_OPEN`.

---

## Out of Scope

- The other types' damage to walls and Turrets (unchanged).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: the scenario `flag_open` (F1 to F4), run twice byte-identical, and the regression of the older scenarios; recorded in `production/qa/evidence/story-038-map-02-and-map-choice-evidence.md`, section Story 039.

**Status**: [x] Created 2026-10-21

---

## Dependencies

- Depends on: None.
- Unlocks: None.
