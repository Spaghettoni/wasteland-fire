# Godot UI — Quick Reference

Last verified: 2026-09-30 | Engine: Godot 4.7.2

## What Changed Since ~4.3 (LLM Cutoff)

### 4.7 Changes
<!-- 4.7 items: the migration guide (https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html) for breaking/behavior/default changes; the 4.7 release page, curated changelogs and 4.7 class references for the rest. GH-nnnn is pull request nnnn in godotengine/godot -->
- **Newly created projects**: the default stretch mode is now `canvas_items` (previously `disabled`) and the default stretch aspect is now `expand` (previously `keep`); change them under `display/window/stretch/mode` and `display/window/stretch/aspect`.
- **`Control.accessibility_live`**: type `DisplayServer.AccessibilityLiveMode` → `AccessibilityServer.AccessibilityLiveMode` (GDScript ✔ · C# binary ❌ · C# source ❌ · GH-116839).
- **`RichTextLabel`**: enum field `ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` renamed to `ImageUpdateMask.UPDATE_WIDTH_UNIT` (GDScript ❌ · C# binary ✔ · C# source ❌ · GH-112617).
- **`RichTextLabel.add_image` and `update_image`**: `width` and `height` parameter types `int` → `float` (GDScript ✔ · C# binary ✔ with compat · C# source ✔); `width_in_percent` → `width_unit` and `height_in_percent` → `height_unit`, type `bool` → `RichTextLabel.ImageUnit` (GDScript ✔ · C# binary ✔ with compat · C# source ❌); GH-112617.
- **`RichTextLabel.add_image` and `update_image`**: defaults, listed in the guide under the old names `width_in_percent` and `height_in_percent`: `false` → `0`. `RichTextLabel.ImageUnit` in the 4.7 class reference (https://docs.godotengine.org/en/4.7/classes/class_richtextlabel.html): `IMAGE_UNIT_PIXEL` = 0 ("Images drawn with this unit will be in pixels."), `IMAGE_UNIT_PERCENT` = 1 ("…in percentages of the control width."), `IMAGE_UNIT_EM` = 2 ("…in percentages of the surrounding font size."); `width_unit` and `height_unit` default to `0`. (inference: the old `false` corresponds to `IMAGE_UNIT_PIXEL` and the old `true` to `IMAGE_UNIT_PERCENT`, from the member names and the default `0` replacing `false`; neither page states the mapping.)
- **`Font.find_variation`**: new `palette_index` and `custom_colors` optional parameters (GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-117149). `TreeItem.select`: new `set_as_cursor` optional parameter (same marks · GH-119367).
- **`ResourceImporterDynamicFont.hinting`**: default `1` → `3`. Guide's advice for changed defaults: manually set the old value to get a similar behavior to the previous version.
- **`Control` offset transform**: `offset_transform_enabled` plus `offset_transform_position`, `offset_transform_position_ratio`, `offset_transform_rotation`, `offset_transform_scale`, `offset_transform_pivot`, `offset_transform_pivot_ratio`; `offset_transform_visual_only` defaults to `true` (GH-87081)
- **`Control.custom_maximum_size`** (default `Vector2(-1, -1)`, meaning no maximum) (GH-116640)
- **`RichTextLabel`**: images can scale with the font size, for example `[img height=1em]` (GH-112617); method signature changes are in the migration guide
- **Accessibility**: landmark navigation (GH-114449); accessibility methods and enums moved from `DisplayServer` to `AccessibilityServer` (GH-116839)
- **Deprecated**: `TabContainer.all_tabs_in_front`, "due to now being useless" (GH-118623)

### 4.6 Changes
- **Dual-focus system**: Mouse/touch focus is now SEPARATE from keyboard/gamepad focus
  - Visual feedback differs by input method
  - Custom focus implementations may need updating
- **TabContainer**: Tab properties editable directly in Inspector
- **TileMapLayer scene tile rotation**: Scene tiles can be rotated like atlas tiles

### 4.5 Changes
- **FoldableContainer**: New accordion-style UI node for collapsible sections
- **Recursive Control behavior**: Disable mouse/focus for entire node hierarchies
  with a single property
- **Screen reader support**: Control nodes work with AccessKit
- **Live translation preview**: Test different locales in-editor
- **`RichTextLabel.push_meta`**: Added optional `tooltip` parameter (from 4.4)

### 4.4 Changes
- **`GraphEdit.connect_node`**: Added optional `keep_alive` parameter

## Current API Patterns

### Theme and Style (4.6)
```gdscript
# Editor uses new "Modern" theme by default
# For game UI, use custom themes as before:
var theme := Theme.new()
theme.set_color(&"font_color", &"Label", Color.WHITE)
theme.set_font_size(&"font_size", &"Label", 24)
```

### Focus Management (4.6 — CHANGED)
```gdscript
# Keyboard/gamepad focus (grab_focus still works)
func _ready() -> void:
    %StartButton.grab_focus()

# IMPORTANT: In 4.6, mouse hover is separate from keyboard focus
# Both can be active simultaneously on different controls
# Test your UI with BOTH mouse and keyboard/gamepad

# Focus neighbors (unchanged)
%Button1.focus_neighbor_bottom = %Button2.get_path()
%Button1.focus_neighbor_right = %Button3.get_path()
```

### FoldableContainer (4.5 — NEW)
```gdscript
# Accordion-style collapsible container
# Add as parent of content you want to make collapsible
# Children show/hide when header is clicked
# Configure via editor properties or code
```

### Recursive Disable (4.5 — NEW)
```gdscript
# Disable all mouse/focus interactions for a hierarchy
# Useful for disabling entire menu sections
%SettingsPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
# In 4.5+, this can propagate recursively to children
```

### Localization-Ready UI (best practice)
```gdscript
# Use tr() for all visible strings
label.text = tr("MENU_START_GAME")

# Use auto-wrap for labels (text length varies by language)
label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# Test with live translation preview in editor (4.5+)
```

## Common Mistakes
- Assuming `grab_focus()` affects mouse focus (keyboard/gamepad only in 4.6)
- Not testing UI with both mouse and gamepad after upgrading to 4.6
- Hardcoding strings instead of using `tr()` for localization
- Not using `FoldableContainer` for collapsible UI (new in 4.5, cleaner than custom)
- Calling accessibility methods on `DisplayServer` — they moved to the `AccessibilityServer` singleton in 4.7
- Animating a Control inside a container by setting `position`/`scale` directly (the container resets it) instead of `offset_transform_*` (4.7)
