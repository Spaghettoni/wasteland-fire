class_name SecondaryStatus
extends Control
## The secondary weapon's bar under a Player's HUD band (Story 044; Martin, 2026-10-22: "dat tam ku
## kazdemu vozitku nejaky bar co sa dobija aj s popisom smoke/mine/boost a pri moto drop flag ked je
## to aktualne"; Story 042 showed a line of text there). A name and a bar: "Boost" for a Buggy (the
## bar drains while the nitro runs and fills while it recharges), "Smoke" for a Gyrocopter, "Mine"
## for a Truck (each fills while it recharges), "Drop flag" for a Unit carrying a Flag (full: the
## key drops it now). Full and in ready_style when the next press works; in charging_style while it
## fills. Hidden for a Unit with nothing on the key (a Motorbike carrying nothing).
##
## Display only (.claude/rules/ui-code.md): it reads the Player's NitroBooster, SmokeLauncher,
## MineLayer and FlagDropper every frame and owns nothing. The names are data of the scene, through
## tr().
##
## Implements: production/epics/wasteland-fire/story-044-secondaries-recharge.md AC-5.

@export var nitro_booster: NitroBooster
@export var smoke_launcher: SmokeLauncher
@export var mine_layer: MineLayer
@export var flag_dropper: FlagDropper
## The name and the bar. Required.
@export var name_label: Label
@export var bar: ProgressBar
@export var ready_style: StyleBox
@export var charging_style: StyleBox
@export var boost_text: String = ""
@export var smoke_text: String = ""
@export var mine_text: String = ""
@export var drop_text: String = ""


## The name shown now, empty when the bar is hidden (for the evidence and the HUD alike).
func shown_name() -> String:
	return name_label.text if visible and name_label != null else ""


## The bar's value now, 0 to 1.
func shown_charge() -> float:
	return bar.value if bar != null else 0.0


func _process(_delta: float) -> void:
	if name_label == null or bar == null:
		return
	var label: String = ""
	var charge: float = 0.0
	var ready: bool = false
	if flag_dropper != null and flag_dropper.can_drop():
		label = drop_text
		charge = 1.0
		ready = true
	elif nitro_booster != null and nitro_booster.state() != NitroBooster.State.NONE:
		label = boost_text
		charge = nitro_booster.charge()
		ready = nitro_booster.state() == NitroBooster.State.READY
	elif smoke_launcher != null and smoke_launcher.has_smoke():
		label = smoke_text
		charge = smoke_launcher.charge()
		ready = smoke_launcher.is_ready()
	elif mine_layer != null and mine_layer.recharges():
		label = mine_text
		charge = mine_layer.charge()
		ready = charge >= 1.0
	visible = not label.is_empty()
	if not visible:
		return
	name_label.text = tr(label)
	bar.value = charge
	var style: StyleBox = ready_style if ready else charging_style
	if style != null:
		bar.add_theme_stylebox_override(&"fill", style)
