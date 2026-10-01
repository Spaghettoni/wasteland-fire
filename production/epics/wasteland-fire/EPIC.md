# Epic: Wasteland Fire — First Playable

> **Status**: Active
> **Tier**: `workflow: minimal` — implicit epic synthesised from `design/game-brief.md` by `/create-stories` on 2026-09-30. No GDD, ADRs, TR registry or control manifest exist at this tier; every story traces to the brief.
> **Governing ADRs**: N/A (minimal — no ADRs)
> **Last Updated**: 2026-10-01: brought to version 0.1 of the author's artifact (the source is archived under `design/source/`; the rules of record are `design/rules.md`).

## Goal

Two friends on one couch drive wasteland Motorbikes, Buggies, Trucks and Gyrocopters across a split screen to steal each other's Flag and haul it home on a Motorbike, paying a Token for every wreck and burning Fuel they must keep finding.

## Scope (the brief's MVP list)

1. Driving toy
2. Split screen for two
3. Bases, destruction and respawn
4. Flag and the win (built as story 004, "Water Canister and the win")
5. Four Units and the triangle
6. Fuel and Fuel Cans
7. Map 01
8. Tokens, the Garage and the loss

## Ordering (the brief's Build order — this is the plan; no sprint plan at `minimal`)

001 → 002 → 003 → 004 → 005 → 006 → 007 → 008. Stories 001 to 004 are the vertical slice (two Motorbikes, two Bases, one Flag run) and are Complete as of 2026-10-01: the sofa test with a friend belongs here, after 004 and before the triangle exists. Greybox until 007. Story 008 comes last because it changes how a Round ends and renames the Water Canister code to the Flag; if Map 01 is late, 008 may run before 007 (its Dependencies say how). The v0.1 playtest follows 008: with it the First Playable is complete.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Driving toy | Visual/Feel | Complete | N/A (minimal) |
| 002 | Split screen for two | Integration | Complete | N/A (minimal) |
| 003 | Bases, destruction and respawn | Logic | Complete | N/A (minimal) |
| 004 | Water Canister and the win (the Flag of v0.1) | Integration | Complete | N/A (minimal) |
| 005 | Four Units and the triangle | Logic | Ready | N/A (minimal) |
| 006 | Fuel and Fuel Cans | Logic | Ready | N/A (minimal) |
| 007 | Map 01 | Visual/Feel | Ready | N/A (minimal) |
| 008 | Tokens, the Garage and the loss | Integration | Ready | N/A (minimal) |
