class_name MatchRules
extends Resource
## Tuning values for one Round: how long a destroyed Unit waits before it respawns at its
## Player's Base, and how hard the debug-damage key hits.
##
## Implements: design/game-brief.md MVP feature 3 (Bases, destruction and respawn) and
## production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-3 (the respawn delay
## defaults to 3 seconds and is a data tuning value) and AC-8 (a debug key damages the local Unit
## until Story 005 brings weapons, and is gated so it can be switched off); design/rules.md
## "Destruction, respawn and unit swap" ("a delay of about three seconds (tuning value)"). One
## .tres holds them (data/match_rules.tres); MatchController and PlayerMatchInput read it.
##
## Data only. Both read these numbers and never write them. The .tres is shared, so treat it as
## read-only at runtime (duplicate() it for a private copy).
##
## Every default below is 0.0 on purpose, for the reason UnitStats gives: the engine leaves a
## property out of a saved .tres when it equals the script default, so a tuned number that
## happened to match a default would live in this script and vanish from the data file. The 3
## seconds of AC-3 is the value in match_rules.tres, not in this script. MatchController refuses
## to begin a Round while respawn_delay_seconds is zero or less.

## Seconds a destroyed Unit waits before it respawns at its Player's Base (Story 003 AC-3). The
## MatchController counts it in physics time, so it does not depend on the frame rate. It must
## stay above zero.
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:s") var respawn_delay_seconds: float = 0.0

## Hit points one press of a Player's debug-damage key takes off that Player's own Unit (Story 003
## AC-8), the stand-in for a weapon until Story 005. Zero turns the debug keys off: that is the
## gate which keeps them out of a build with weapons. Story 005 sets it to zero, or removes the
## keys.
@export_range(0.0, 1000.0, 1.0, "or_greater", "suffix:hp") var debug_damage: float = 0.0
