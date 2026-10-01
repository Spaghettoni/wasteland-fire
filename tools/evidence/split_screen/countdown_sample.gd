extends RefCounted
## One instant of the countdown scenario (countdown_trace.gd takes them, countdown_audit.gd judges them):
## for each Player whether the label is drawn, its text, the controller's seconds for that Player and
## whether the controller says that Player's Unit is alive. Loaded with a preload constant: nothing under
## tools/ declares a class_name. Tooling only: nothing under src/ depends on this file.

## Whether each label is visible in the tree.
var visible: Array[bool] = [false, false]
## What each label's text is.
var text: Array[String] = ["", ""]
## The controller's seconds_until_respawn for each Player.
var seconds: Array[float] = [0.0, 0.0]
## The controller's is_alive for each Player.
var alive: Array[bool] = [true, true]
