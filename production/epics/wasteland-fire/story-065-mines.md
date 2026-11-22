# Story 065: Mines hit their own Team, and look better

> **Epic**: Wasteland Fire — First Playable
> **Status**: Done
> **Layer**: Feature
> **Type**: Logic + Visual/Feel
> **Estimate**: S
> **Last Updated**: 2026-11-22

## Context

**Requirement**: Martin, 2026-11-22: "myslim ze miny nevybuchnu na friendly fire. A mali by. Tiez ich zmenme nech su pekne. Kusok mensie a nech blikaju vo farbach timu." Also: "chcem aby ostal horet aj tvoj kamos ked prejde cez plamen" (the Flame Tank's fire, story 063).

## Acceptance Criteria

- [x] AC-1: A live Mine goes off under any ground Unit, its own Team's too (`MineSettings.spares_own_team` false, undoing story 048's rule).
- [x] AC-2: A Mine is drawn as a small dark casing with a rim and studs (radius 0.5 m, its trigger stays 0.8 m) and a Team light on top that blinks fast while it arms and slower (0.8 s) once it is live.
- [x] AC-3: A Teammate hit by the Flame Tank's flames keeps burning like an enemy (the shooter himself never burns).

## Test Evidence

`mines_gyro_065` M1, M2; `flame_tank` F5; frames in `production/qa/evidence/story-065-066/`. Scenarios without `MINE_LOOKS` keep the disc and the rule they were written with.
