# Godot Networking — Quick Reference

Last verified: 2026-09-30 | Engine: Godot 4.7.2

## What Changed Since ~4.3 (LLM Cutoff)

### 4.7 Changes
<!-- 4.7 items: the migration guide (https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html) for breaking/behavior/default changes; the 4.7 release page, curated changelogs and 4.7 class references for the rest. GH-nnnn is pull request nnnn in godotengine/godot -->
- **ENet**: the DTLS server no longer leaks peers (GH-114834)
- **UDP server**: peer connection fix (GH-120369)
- **`HTTPRequest`**: missing redirect status codes added (GH-91261)
- **Downloads**: incomplete file downloads are removed automatically (GH-117448); files are no longer deleted after a chunked transfer completes (GH-118240)
- **TLS**: mbedTLS updated to 3.6.7 in 4.7.1 (GH-121055); 4.7.2 always uses Godot's OS as the entropy source (GH-121759)
- **Multiplayer (4.7.2)**: peers no longer stop replicating after deleting a node they spawned with `MultiplayerSpawner` (GH-109864)
- **No release-page item**: the release page has no networking item

### 4.6 Changes
- **Networking section in breaking changes**: See the official migration guide for
  specifics at the 4.5→4.6 level

### 4.5 Changes
- **No major networking API breaks** — core multiplayer API remains stable

## Current API Patterns

### High-Level Multiplayer
```gdscript
# Server
func host_game(port: int = 9999) -> void:
    var peer := ENetMultiplayerPeer.new()
    peer.create_server(port)
    multiplayer.multiplayer_peer = peer
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# Client
func join_game(address: String, port: int = 9999) -> void:
    var peer := ENetMultiplayerPeer.new()
    peer.create_client(address, port)
    multiplayer.multiplayer_peer = peer
```

### RPCs
```gdscript
# Server-authoritative pattern
@rpc("any_peer", "call_local", "reliable")
func request_action(action_data: Dictionary) -> void:
    if not multiplayer.is_server():
        return
    # Validate on server, then broadcast
    _execute_action.rpc(action_data)

@rpc("authority", "call_local", "reliable")
func _execute_action(action_data: Dictionary) -> void:
    # All peers execute the validated action
    pass
```

### MultiplayerSpawner and MultiplayerSynchronizer
```gdscript
# Use MultiplayerSpawner for automatic node replication
# Use MultiplayerSynchronizer for property synchronization

# MultiplayerSynchronizer setup:
# 1. Add as child of the node to sync
# 2. Configure replication properties in editor
# 3. Set visibility filters for relevancy
```

### SceneMultiplayer Configuration
```gdscript
func _ready() -> void:
    var scene_mp := multiplayer as SceneMultiplayer
    scene_mp.auth_callback = _authenticate_peer
    scene_mp.server_relay = false  # Direct peer connections

func _authenticate_peer(id: int, data: PackedByteArray) -> void:
    # Custom authentication logic
    pass
```

## Common Mistakes
- Not using `"any_peer"` for client-to-server RPCs (defaults to authority only)
- Trusting client data without server-side validation
- Using `"unreliable"` for game state changes (use for position updates only)
- Not setting multiplayer authority (`set_multiplayer_authority()`) on spawned nodes
