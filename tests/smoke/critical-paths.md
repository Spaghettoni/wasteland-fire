# Smoke Test: Critical Paths

**Purpose**: Run these 10-15 checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches straight into the Map without crash (no main menu in the First Playable — `run/main_scene` is set once story 001 lands)
2. A new Round can be started (R on the Round-over screen, once story 004 lands)
3. Both keyboard layouts respond without freezing

## Core Mechanic (update per story)

<!-- Add the primary mechanic for each story here as it is implemented -->
4. [Story 001 — Motorbike drives with W/A/S/D, chase camera follows, 60 fps at 1280×720]
5. [Story 002 — two viewports, both Players drive at once]
6. [Story 004 — steal, drop, recover, deliver; Round-over screen]
7. [Story 008 — a destruction costs a Token of its type; the choice shows the counts and dims a type with none; the last Motorbike Token loses the Round; both Players losing it on one tick shows "Nobody wins!"]

## Data Integrity

8. Restarting a Round resets Units, Flags, both Token stocks and HUD (once story 008 lands)
9. Unit tuning values load from their `.tres` data, not code (once story 001 lands)

## Performance

10. No visible frame rate drops on the dev machine (60fps target, two viewports)
11. No memory growth over 5 minutes of play (once the core loop is implemented)
