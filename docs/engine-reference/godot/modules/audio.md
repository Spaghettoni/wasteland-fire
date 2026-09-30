# Godot Audio — Quick Reference

Last verified: 2026-09-30 | Engine: Godot 4.7.2

## What Changed Since ~4.3 (LLM Cutoff)

No major breaking changes to the audio API in 4.4–4.6. 4.7 removes
`AudioEffectSpectrumAnalyzer.tap_back_pos` and changes the `AudioStreamPlayer`
`area_mask` default (see 4.7 Changes). Otherwise the core audio system remains
stable.

### 4.7 Changes
<!-- 4.7 items: the migration guide (https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html) for breaking/behavior/default changes; the 4.7 release page, curated changelogs and 4.7 class references for the rest. GH-nnnn is pull request nnnn in godotengine/godot -->
- **PITFALL (3D local multiplayer)**: `AudioStreamPlayer` default `area_mask` changed from `1` to `0` (disabled) (GH-107679). If you use the `audio_bus_override` feature on `Area2D` or `Area3D` **and** the `AudioStreamPlayer` default `area_mask` (just layer `1` ticked): "you will need to reset the mask to layer `1` — otherwise, the bus overrides will stop working." A mask set to anything except layer `1` "will continue to work as expected."
- **`AudioEffectSpectrumAnalyzer.tap_back_pos`**: removed; replacement: none stated in the guide (GDScript ❌ · C# binary ❌ · C# source ❌ · GH-114355). Per the curated 4.7 changelog the effect no longer returns jittered values (GH-114355) and, per the PR, "magnitudes will update less frequently"; the Hann window is fixed (GH-116830).
- **`AudioStreamPlayer3D` with several cameras** (GH-114080): cameras/audio listeners in viewports with `Viewport.audio_listener_enable_3d` enabled (default `false` per the 4.7 Viewport class reference) are merged by taking the maximum volume for each output channel (reverb likewise); cameras in other viewports are skipped; fixes "Audio only plays on one viewport (3D)"
- **`AudioStreamInteractive`**: `TRANSITION_TO_TIME_PREVIOUS_POSITION` is now bound (GH-114129)
- **No release-page item**: the release page has no audio item; the `area_mask` default change and the `tap_back_pos` removal are in the migration guide

### 4.6 Changes
- **No audio-specific breaking changes** in this release

### 4.5 Changes
- **No audio-specific breaking changes** in this release

## Current API Patterns

### Playing Audio
```gdscript
@onready var sfx_player: AudioStreamPlayer = %SFXPlayer
@onready var music_player: AudioStreamPlayer = %MusicPlayer

func play_sfx(stream: AudioStream) -> void:
    sfx_player.stream = stream
    sfx_player.play()

func play_music(stream: AudioStream, fade_time: float = 1.0) -> void:
    var tween: Tween = create_tween()
    tween.tween_property(music_player, "volume_db", -80.0, fade_time)
    await tween.finished
    music_player.stream = stream
    music_player.volume_db = 0.0
    music_player.play()
```

### 3D Spatial Audio
```gdscript
@onready var audio_3d: AudioStreamPlayer3D = %AudioPlayer3D

func _ready() -> void:
    audio_3d.max_distance = 50.0
    audio_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
    audio_3d.unit_size = 10.0
```

### Audio Buses
```gdscript
# Set bus volumes
AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), volume_db)
AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), volume_db)

# Mute a bus
AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)
```

### Object Pooling for SFX
```gdscript
# Pre-create multiple AudioStreamPlayer nodes for concurrent sounds
var _sfx_pool: Array[AudioStreamPlayer] = []

func _ready() -> void:
    for i in range(8):
        var player := AudioStreamPlayer.new()
        player.bus = &"SFX"
        add_child(player)
        _sfx_pool.append(player)

func play_pooled(stream: AudioStream) -> void:
    for player in _sfx_pool:
        if not player.playing:
            player.stream = stream
            player.play()
            return
```

## Common Mistakes
- Creating new AudioStreamPlayer nodes at runtime instead of pooling
- Not using audio buses for volume categories (Music, SFX, UI, Voice)
- Using `_process()` for audio timing instead of signals (`finished`)
- Relying on the `AudioStreamPlayer` default `area_mask` for `Area2D`/`Area3D` `audio_bus_override` — the default became `0` (disabled) in 4.7; tick layer `1` explicitly
- Expecting a second split-screen camera to hear 3D audio: only viewports with `audio_listener_enable_3d` enabled are merged (4.7)
