# Story 069: Burning vehicles show it; the stick keeps its direction

> **Epic**: Wasteland Fire — First Playable
> **Status**: Done
> **Layer**: Presentation / Core
> **Type**: Visual/Feel + Logic
> **Estimate**: S
> **Last Updated**: 2026-11-22

## Context

**Requirement**: Martin, 2026-11-22:
- "chcel by som vidiet, ze vozidla horia, nevidno to teraz"
- "ked cuvam a otacam sa packou na ovladaci, zrazu z toho ze cuvam dolava napr, sa pri jemnom pohybe stane ze idem dolava dopredu. stane sa to ked si nevsimnem a jemne posuniem packu dopredu - nechtiac. je na to nejaky best practice ktory tomu zabrani"

Why the fire did not show: the flames were dropped in the world at the burning vehicle's spot, so a driving vehicle left them behind at once, and half were born inside its body.

## Acceptance Criteria

- [x] AC-1: A burning vehicle's flames and smoke ride along with it (they take its velocity) and rise from its top, not inside it.
- [x] AC-2: A burning thing throws a flickering orange glow on itself and the ground; it goes out with the fire.
- [x] AC-3: The direction lock: once driving one way, a stick pushed the other way turns the Unit round only past switch_from (0.8 of its travel); a smaller push keeps it going the way it went. The keyboard turns at once.
- [x] AC-4: The lock lets go after release_seconds (0.35 s) of neutral throttle, so reverse → spot turn → a little up drives forward.

## Test Evidence

`flame_tank` F7 (the fire rides), `direction_lock` L1–L3, `full_throttle` unchanged; frame `production/qa/evidence/story-069/burning-buggy-driving.png`.
