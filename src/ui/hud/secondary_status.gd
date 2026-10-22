class_name SecondaryStatus
extends Label
## The line under a Player's HUD band that shows the secondary weapon of the Buggy and the
## Gyrocopter (Story 042): the nitro's state for a Buggy, the smoke screens left for a Gyrocopter.
## The Truck's Mines keep their own line (MineCount); for every other type the line is hidden. It
## reads the Player's NitroBooster and SmokeLauncher every frame and owns nothing. The texts are data
## of the scene.
##
## Implements: production/epics/wasteland-fire/story-042-secondary-weapons.md AC-5.

@export var nitro_booster: NitroBooster
@export var smoke_launcher: SmokeLauncher
@export var nitro_ready_text: String = ""
@export var nitro_on_text: String = ""
## The cooldown line, with a %d for the whole seconds left.
@export var nitro_cooling_format: String = ""
## The smoke line, with two %d: left and capacity.
@export var smoke_format: String = ""


func _process(_delta: float) -> void:
	var shown: String = ""
	if nitro_booster != null:
		match nitro_booster.state():
			NitroBooster.State.READY:
				shown = tr(nitro_ready_text)
			NitroBooster.State.BOOSTING:
				shown = tr(nitro_on_text)
			NitroBooster.State.COOLING:
				shown = tr(nitro_cooling_format) % ceili(nitro_booster.seconds_left())
	if shown.is_empty() and smoke_launcher != null and smoke_launcher.capacity() > 0:
		shown = tr(smoke_format) % [smoke_launcher.smoke_left(), smoke_launcher.capacity()]
	text = shown
	visible = not shown.is_empty()
