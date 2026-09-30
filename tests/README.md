# Test Infrastructure

**Engine**: Godot 4.7.2
**Test Framework**: GdUnit4 (v6.2.1, installed under `addons/gdUnit4/` from the GitHub release)
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-09-30

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
```

```
production/qa/
  evidence/       # Screenshot logs and manual test sign-off records
```

> **Manual evidence lives under `production/qa/evidence/`, not `tests/`** — that
> is where every consumer reads it.

## Running Tests

```bash
godot --headless --path . --import
godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

Run the import first. A fresh clone has no `.godot/` class cache, and a run
without one exits 1 — `GdUnitCmdTool.gd` did not load, so no test ran.

Exit codes: **0** every test passed; **100** a test failed; **101** every test
passed but a test leaked nodes (a warning); 103 / 104 gdUnit4 could not run
(headless refused, Godot older than 4.3); 105 a test script does not parse.
`--remote-debug tcp://127.0.0.1:0` is required — without it a script error
opens Godot's interactive debugger and the run waits at a `debug>` prompt. Every
run prints two `ERROR:` lines about the remote port; they are expected. A run
that finds no tests prints `No test cases found` and exits 0 — that is not a
pass. The folder is `addons/gdUnit4/` with a **capital U**. Reports land in
`reports/` (gitignored).

## Installing GdUnit4

Already installed (v6.2.1) and enabled in `project.godot` (`[editor_plugins]`).
To reinstall or update:
```
1. Open Godot → AssetLib → search "GdUnit4" → Download & Install
2. Enable the plugin: Project → Project Settings → Plugins → GdUnit4 ✓
3. Restart the editor
4. Verify: res://addons/gdUnit4/bin/GdUnitCmdTool.gd exists (capital U)
```

## Test Naming

Names follow the engine's language (`.claude/rules/test-standards.md`):
- **Godot**: file `[system]_[feature]_test.gd`, function `test_[scenario]_[expected]`
  — `combat_damage_test.gd` → `test_base_attack_returns_expected_damage()`

Example: `tests/unit/framework/framework_smoke_test.gd` — one assertion that
proves the runner works on the pinned engine. Replace it with real tests.

## Story Type → Test Evidence

| Story Type | Required Evidence | Location |
|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` |
| Visual/Feel | Screenshot + lead sign-off | `production/qa/evidence/` |
| UI | Retained screenshot of each screen touched | `production/qa/evidence/` |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` |

At `qa.level: minimal` (this project) tests are **waived** — advisory, never
"must exist and pass" — but the retained screenshot for Visual/Feel and UI
stories is not. Raise `qa.level` with `/settings` to make tests required.

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging.
