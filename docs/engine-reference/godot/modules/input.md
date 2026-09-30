# Godot Input — Quick Reference

Last verified: 2026-09-30 | Engine: Godot 4.7.2

## What Changed Since ~4.3 (LLM Cutoff)

### 4.7 Changes
<!-- 4.7 items: the migration guide (https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html) for breaking/behavior/default changes; the 4.7 release page, curated changelogs and 4.7 class references for the rest. GH-nnnn is pull request nnnn in godotengine/godot -->
- **PITFALL (3D local multiplayer)**: the device IDs for mouse and keyboard were changed from `0` to `InputEvent.DEVICE_ID_MOUSE` and `InputEvent.DEVICE_ID_KEYBOARD` "because some joypads may use `0` as their ID" (GH-116274). Guide: "Check the input event by type or compare the device ID `InputEvent.device` to the constants `InputEvent.DEVICE_ID_MOUSE` and `InputEvent.DEVICE_ID_KEYBOARD` instead." (the guide names no event classes; for example `event is InputEventKey` / `event is InputEventMouseButton`, the pattern in "Input Events" below). 4.7 class reference: `InputEvent.DEVICE_ID_KEYBOARD` is 16 and `InputEvent.DEVICE_ID_MOUSE` is 32; the release page says the change "does not add support for differentiating between multiple keyboards or mice connected to the same system"; saved `device=0` input maps are normalised on load (GH-116526).
  ```gdscript
  func is_keyboard_wrong(event: InputEvent) -> bool:  # WRONG in 4.7: keyboard and mouse IDs changed from 0
      return event.device == 0
  func is_keyboard(event: InputEvent) -> bool:  # RIGHT (for the mouse use InputEvent.DEVICE_ID_MOUSE)
      return event.device == InputEvent.DEVICE_ID_KEYBOARD
  ```
- **4.7.2 fixes**: simultaneous Shift release (GH-120327); mouse performance at high polling rates on Windows (GH-109639)

### 4.6 Changes
- **Dual-focus system**: Mouse/touch focus is now separate from keyboard/gamepad focus
  - Visual feedback differs by input method
  - Custom focus implementations may need updating
- **Select Mode keybind changed**: "Select Mode" is now `v` key; old mode renamed "Transform Mode" (`q` key)

### 4.5 Changes
- **SDL3 gamepad driver**: Gamepad handling delegated to SDL library for better cross-platform support
- **Recursive Control disable**: Single property disables mouse/focus for entire node hierarchies

### 4.3 Changes (in training data)
- **InputEventShortcut**: Dedicated event type for menu shortcuts (optional)

## Current API Patterns

### Input Actions (unchanged)
```gdscript
func _physics_process(delta: float) -> void:
    var input_dir: Vector2 = Input.get_vector(
        &"move_left", &"move_right", &"move_forward", &"move_back"
    )
    if Input.is_action_just_pressed(&"jump"):
        jump()
```

### Input Events (unchanged)
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            handle_click(event.position)
    elif event is InputEventKey:
        if event.keycode == KEY_ESCAPE and event.pressed:
            toggle_pause()
```

### Focus Management (4.6 — CHANGED)
```gdscript
# Mouse/touch and keyboard/gamepad focus are now SEPARATE
# Visual styles may differ depending on which input method is active
# If you have custom focus drawing, test with both input methods

# Standard approach still works:
func _ready() -> void:
    %StartButton.grab_focus()  # Keyboard/gamepad focus

# But be aware: mouse hover focus != keyboard focus in 4.6
```

### Gamepad (4.5+ — SDL3 backend)
```gdscript
# API unchanged, but SDL3 provides:
# - Better device detection across platforms
# - Improved rumble support
# - More consistent button mapping

func _input(event: InputEvent) -> void:
    if event is InputEventJoypadButton:
        if event.button_index == JOY_BUTTON_A and event.pressed:
            confirm_selection()
```

## Common Mistakes
- Not testing both mouse and keyboard focus paths (dual-focus in 4.6)
- Assuming `grab_focus()` affects mouse focus (it only affects keyboard/gamepad in 4.6)
- Using string literals instead of `StringName` (`&"action"`) for action names in hot paths
- Comparing `InputEvent.device` to `0` to detect the keyboard or mouse — their IDs are `InputEvent.DEVICE_ID_KEYBOARD` (16) and `InputEvent.DEVICE_ID_MOUSE` (32) since 4.7, and `0` may be a joypad
- Expecting per-keyboard device IDs for two players on one machine: 4.7 does not distinguish multiple keyboards; give each player separate key bindings (inference from the release-page statement)
