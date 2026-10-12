# Frozen scenes (evidence only)

Nothing under `src/` uses a file here. The evidence runner (`tools/evidence/split_screen_harness.gd`)
swaps these in for the scenarios written before the story that changed the shipped piece, so their
retained outputs stay what they were measured with.

| File | What it is |
|---|---|
| `turret_story_013.tscn` | The Turret of Story 013 as `main` had it at 2f59a2c, before Story 015: a drum 1 m tall under a head, a collider 1.8 m tall, no damaged look, and the map art's trim on the drum (`TurretPedestalTrim`) and on the head. The runner puts one in each Turret place of a Map Base for every scenario that does not declare `TURRET_LOOKS` (`_apply_turret_looks_off()`). It runs the shipped `turret.gd` and `structure.gd`, which are inert on it: its `intact` is `Look`, it names no worn parts, and the runner empties the stats' `damaged_below`. |

A frozen scene is a byte copy (`git show <commit>:<path>`): never edit one to follow the shipped
piece. When a later story changes what the older scenarios would see, add a new frozen copy.
