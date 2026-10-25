# Story 052 evidence: A Teammate's Unit in play holds its Token

> **Story**: `production/epics/wasteland-fire/story-052-last-carrier-of-a-team.md`
> **Type**: Logic (headless)
> **Written**: 2026-10-25, in a cloud session (Linux, Godot 4.7.2 official build)

| AC | Result | Check |
|---|---|---|
| AC-1 first of two falls | PASS: Orange at 2 Motorbike Tokens with both Players on Motorbikes; one destroyed: 1 left, the Round runs, the Teammate drives | `teams_last_carrier` R1 |
| AC-2 Token held | PASS: the fallen Player: Motorbike tokens_free 0, can_choose false, choose refused; a Buggy may be taken; a Teal Player: 4 of 5 free | `teams_last_carrier` R2 |
| AC-3 last one falls | PASS: the second destroyed: Orange 0, Round over, Teal wins | `teams_last_carrier` R3 |
| AC-4 one Player per Team | PASS: `tokens` and `tokens_data` as before | regression (story 051's evidence) |

Seeded defect: `can_choose()` back on `tokens_left()` fails R2 (can_choose true, choose not refused).
