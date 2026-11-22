# Story 070: Burn 3 s; Self-destruct only on an empty tank; the swap waits 3 s

> **Epic**: Wasteland Fire — First Playable
> **Status**: Done
> **Layer**: Core
> **Type**: Logic + Config/Data
> **Estimate**: S
> **Last Updated**: 2026-11-22

## Context

**Requirement**: Martin, 2026-11-22: "cas horenia skratme na 3s. jednu vec pridajme. nemozes resetnut vozidlo len tak. musi Ti dojst fuel. a ked si ides sam vymenit voz, budes mat 3 respawn time aby si to nezneuzival."

## Acceptance Criteria

- [x] AC-1: The Flame Tank's fire burns 3 s (truck_stats.tres burn_seconds).
- [x] AC-2: The swap at the own Base waits rules.swap_respawn_seconds (3 s) before the next Unit appears; the respawn countdown shows it.
- [x] AC-3: Outside the own Base, the Self-destruct key does nothing while the Unit has Fuel (rules.self_destruct_needs_empty_fuel); with an empty tank it destroys as before. The swap at home is unchanged.

## Test Evidence

`swap_wait` W1–W3; `flame_tank` F2 at 3 s; `unit_swap` unchanged (it runs without Story 070's rules).
