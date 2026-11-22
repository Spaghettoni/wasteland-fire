# Evidence: Story 070 — burn 3 s; Self-destruct only on an empty tank; the swap waits 3 s

Date: 2026-11-22 · Godot 4.7.2 · Linux, headless checks.

- `swap_wait` RESULT ok checks=3: W1 swap at home: wait 3.00 s, countdown shown; the Motorbike chosen at once appeared 3.00 s after the swap. W2 out of the Base with 49.9 Fuel: the key left the Unit in play. W3 the tank emptied: the key destroyed the Unit.
- `flame_tank` F2: 54.1 burned in the 3 s of fire (46.9 to 68.4 expected with the puffs still in the air at the release, which land, hit and rekindle).
- `unit_swap` unchanged (runs without Story 070's rules unless SWAP_WAIT).
- Full regression (132 scenarios): the same exits as the run before; swap_wait new and passing.
