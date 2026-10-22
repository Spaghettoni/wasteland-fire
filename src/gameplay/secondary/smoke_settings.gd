class_name SmokeSettings
extends Resource
## The Gyrocopter's smoke screen as data (Story 042): how big it is, how long it hangs, how fast it
## fades. One .tres (data/smoke_settings.tres) for every cloud.

## The cloud's radius, metres: inside and behind it a Turret sees nothing, and the views see little.
@export_range(1.0, 50.0, 0.5, "or_greater", "suffix:m") var radius: float = 0.0
## Seconds the cloud hangs where it was dropped, its fade included.
@export_range(0.5, 60.0, 0.5, "or_greater", "suffix:s") var seconds: float = 0.0
## Seconds at the end over which it fades out.
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:s") var fade_seconds: float = 0.0
## How opaque the puffs are at full strength (0 to 1).
@export_range(0.0, 1.0, 0.01) var opacity: float = 0.0
