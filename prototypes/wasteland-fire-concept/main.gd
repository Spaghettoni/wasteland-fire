# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is the two-Player split-screen Water Canister run fun on one keyboard?
# Date: 2026-09-30
#
# Everything is built in code from this one node: field, walls, two Bases, two
# canisters, two bikes, two viewports with a chase camera and a status label each.
# Run:      godot --path . --windowed --resolution 1280x720
# Autoplay: godot --path . --windowed --resolution 1280x720 --write-movie shots/run.png --quit-after 900 -- --autoplay=run
#           --autoplay=run   P1 bot steals and delivers, P2 idle        -> proves the win path
#           --autoplay=chase P1 bot steals, P2 bot defends once (tackle) -> proves drop + recovery + win
extends Node3D

const FIELD := 80.0
const BASE_X := 30.0
const BASE_SIZE := 8.0
const WIN_HOLD_FRAMES := 90

const BikeScript := preload("res://bike.gd")
const CanisterScript := preload("res://canister.gd")
const CamScript := preload("res://cam_follow.gd")

var bikes: Array = []
var canisters: Array = []
var labels: Array = []
var round_over := false
var winner := 0
var win_frame := 0
var frame := 0
var autoplay_mode := ""
var tackles_done := 0
var sd_timer := 0
var sd_done := false
var last_label_text: Array = ["", ""]


func _ready() -> void:
	_setup_input()
	_build_world()
	for p in [1, 2]:
		var x := -BASE_X if p == 1 else BASE_X
		_build_base(p, x)
		canisters.append(_build_canister(p, Vector3(x, 0.6, 0)))
		# Spawn at the front-left of the pad, not on the canister, so nobody blocks the pickup by standing still.
		bikes.append(_build_bike(p, Vector3(x + (3.0 if p == 1 else -3.0), 0, 3.5), -PI / 2 if p == 1 else PI / 2))
	_build_ui()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autoplay="):
			autoplay_mode = a.substr(11)
	if autoplay_mode != "":
		bikes[0].bot_active = true
		bikes[1].bot_active = autoplay_mode in ["chase", "block"]
		print("HOME P1=", bikes[0].home, " P2=", bikes[1].home)
	print("PROTOTYPE READY autoplay=", autoplay_mode)


func _setup_input() -> void:
	var keys := {
		"p1_throttle": KEY_W, "p1_reverse": KEY_S, "p1_left": KEY_A, "p1_right": KEY_D, "p1_selfdestruct": KEY_Q,
		"p2_throttle": KEY_UP, "p2_reverse": KEY_DOWN, "p2_left": KEY_LEFT, "p2_right": KEY_RIGHT, "p2_selfdestruct": KEY_ENTER,
		"restart": KEY_R,
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		InputMap.action_add_event(action, ev)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _player_color(p: int) -> Color:
	return Color(0.2, 0.5, 1.0) if p == 1 else Color(1.0, 0.3, 0.25)


func _box_body(size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	body.add_child(mi)
	body.position = pos
	add_child(body)
	return body


func _build_world() -> void:
	var h := FIELD / 2.0
	_box_body(Vector3(FIELD, 1, FIELD), Vector3(0, -0.5, 0), Color(0.5, 0.45, 0.36))
	var wall := Color(0.35, 0.3, 0.25)
	_box_body(Vector3(FIELD, 3, 1), Vector3(0, 1.5, -h), wall)
	_box_body(Vector3(FIELD, 3, 1), Vector3(0, 1.5, h), wall)
	_box_body(Vector3(1, 3, FIELD), Vector3(-h, 1.5, 0), wall)
	_box_body(Vector3(1, 3, FIELD), Vector3(h, 1.5, 0), wall)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, 30, 0)
	light.shadow_enabled = true
	add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.78, 0.64, 0.46)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment = e
	add_child(env)


func _build_base(p: int, x: float) -> void:
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(BASE_SIZE, 3, BASE_SIZE)
	shape.shape = bs
	area.add_child(shape)
	var pad := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(BASE_SIZE, 0.2, BASE_SIZE)
	pad.mesh = pm
	pad.material_override = _mat(_player_color(p).darkened(0.3))
	pad.position.y = -1.4
	area.add_child(pad)
	area.position = Vector3(x, 1.5, 0)
	area.body_entered.connect(_on_base_entered.bind(p))
	add_child(area)


func _build_canister(p: int, home: Vector3) -> Area3D:
	var c = CanisterScript.new()
	c.owner_player = p
	c.home = home
	c.world = self
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.8
	cs.height = 1.6
	shape.shape = cs
	c.add_child(shape)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.45
	cm.height = 1.2
	mi.mesh = cm
	mi.material_override = _mat(_player_color(p).lightened(0.45))
	c.add_child(mi)
	c.position = home
	add_child(c)
	return c


func _build_bike(p: int, home: Vector3, yaw: float) -> CharacterBody3D:
	var b = BikeScript.new()
	b.player = p
	b.home = home
	b.home_yaw = yaw
	b.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.4, 1.0, 2.6)
	shape.shape = bs
	shape.position.y = 0.5
	b.add_child(shape)
	var body_mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 0.8, 2.6)
	body_mesh.mesh = bm
	body_mesh.position.y = 0.5
	body_mesh.material_override = _mat(_player_color(p))
	b.add_child(body_mesh)
	var nose := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(0.8, 0.5, 0.6)
	nose.mesh = nm
	nose.position = Vector3(0, 1.1, -0.9)
	nose.material_override = _mat(Color.WHITE)
	b.add_child(nose)
	var mount := Marker3D.new()
	mount.name = "Mount"
	mount.position = Vector3(0, 1.5, 0.6)
	b.add_child(mount)
	b.mount = mount
	b.destroyed.connect(_on_bike_destroyed)
	b.position = home
	b.rotation.y = yaw
	add_child(b)
	return b


func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 4)
	add_child(hbox)
	for p in [1, 2]:
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var sv := SubViewport.new()
		var cam = CamScript.new()
		cam.target = bikes[p - 1]
		sv.add_child(cam)
		cam.current = true
		var label := Label.new()
		label.position = Vector2(14, 10)
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		sv.add_child(label)
		labels.append(label)
		svc.add_child(sv)
		hbox.add_child(svc)


func _on_base_entered(body, base_player: int) -> void:
	if round_over or not (body is CharacterBody3D):
		return
	if not body.alive or body.player != base_player or body.carrying == null:
		return
	var c = body.carrying
	if c.owner_player != base_player:
		_win(base_player)
	else:
		c.call_deferred("return_home")


func _win(p: int) -> void:
	round_over = true
	winner = p
	win_frame = frame
	for b in bikes:
		b.bot_active = false
		b.speed = 0.0
	print("ROUND OVER winner=P", p, " frame=", frame)


func _on_bike_destroyed(_bike) -> void:
	tackles_done += 1


func _drive_bots() -> void:
	for i in 2:
		var me = bikes[i]
		var enemy = bikes[1 - i]
		if not me.bot_active or not me.alive:
			continue
		var my_can = canisters[i]
		var their_can = canisters[1 - i]
		var target := Vector3.INF
		if me.carrying != null:
			target = Vector3(-BASE_X if me.player == 1 else BASE_X, 0, 0)
		elif me.player == 2 and autoplay_mode == "block":
			# The blocker: wait mid-field on the thief's return line, lunge when the Carrier is close, then recover and park.
			if enemy.alive and enemy.carrying != null and tackles_done < 1 and enemy.global_position.distance_to(me.global_position) < 14.0:
				target = enemy.global_position + enemy.velocity * 0.25
			elif not my_can.at_home and my_can.held_by == null:
				target = my_can.global_position
			elif tackles_done < 1:
				target = Vector3(0, 0, -4.0)
			else:
				target = me.home
		elif me.player == 2:
			# The defender: ambush beside the thief's line while they approach, chase the Carrier with
			# lead pursuit once (tackle), recover the dropped canister, then park off the canister.
			if enemy.alive and enemy.carrying != null and tackles_done < 1:
				target = enemy.global_position + enemy.velocity * 0.3
			elif not my_can.at_home and my_can.held_by == null:
				target = my_can.global_position
			elif tackles_done < 1 and enemy.alive and enemy.global_position.x > -15.0:
				target = Vector3(BASE_X - 4.0, 0, 6.0)   # beside the canister on the spawn side, off the thief's line
			else:
				target = me.home
		elif not my_can.at_home and my_can.held_by == null:
			target = my_can.global_position
		elif their_can.held_by == null:
			target = their_can.global_position
		me.bot_target = target
	if autoplay_mode == "selfdestruct" and not sd_done and bikes[0].alive and bikes[0].carrying != null:
		sd_timer += 1
		if sd_timer > 90:
			sd_done = true
			bikes[0].die()


func _update_labels() -> void:
	for p in [1, 2]:
		var b = bikes[p - 1]
		var own = canisters[p - 1]
		var text := "P%d   %s\n" % [p, "W A S D · Q self-destruct" if p == 1 else "ARROWS · ENTER self-destruct"]
		if round_over:
			text += "PLAYER %d WINS — R to restart" % winner
		elif not b.alive:
			text += "Respawn in %d" % ceili(b.respawn_left)
		elif b.carrying != null:
			text += "CARRYING their canister — get home!" if b.carrying.owner_player != p else "Bringing your canister home"
		elif not own.at_home:
			text += "Your canister is AWAY"
		else:
			text += "Steal their canister"
		labels[p - 1].text = text
		if text != last_label_text[p - 1]:
			last_label_text[p - 1] = text
			print("EVENT frame=", frame, " P", p, ": ", text.get_slice("\n", 1))


func _process(_delta: float) -> void:
	frame += 1
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if autoplay_mode != "" and not round_over:
		_drive_bots()
		if frame % 120 == 0:
			var b0 = bikes[0]
			var c2 = canisters[1]
			print("T", frame / 60, " can2 parent=", c2.get_parent().name, " at=", c2.global_position, " P1 pos=", b0.global_position, " yaw=", snappedf(b0.rotation.y, 0.01), " speed=", snappedf(b0.speed, 0.1), " target=", b0.bot_target, " carrying=", b0.carrying != null, " alive=", b0.alive, " bot=", b0.bot_active)
	_update_labels()
	if round_over and autoplay_mode != "" and frame - win_frame > WIN_HOLD_FRAMES:
		get_tree().quit()
