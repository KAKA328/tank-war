extends Node2D

const Config = preload("res://src/core/game_config.gd")
const Command = preload("res://src/combat/tank_command.gd")
const NetworkSessionType = preload("res://src/network/network_session.gd")
const TankControllerType = preload("res://src/actors/tank_controller.gd")
const ProjectileControllerType = preload("res://src/actors/projectile_controller.gd")
const TankScene = preload("res://scenes/world/tank.tscn")
const ProjectileScene = preload("res://scenes/world/projectile.tscn")

@onready var status_label: Label = $Hud/Status
@onready var back_button: Button = $Hud/Back
@onready var tank: TankControllerType = $Tank
@onready var network_session: NetworkSessionType = get_node_or_null("/root/NetworkSession")

var _tanks: Dictionary = {}
var _pending_commands: Dictionary = {}
var _command_times: Dictionary = {}
var _local_player_id := 1
var _input_sequence := 0
var _input_accumulator := 0.0
var _snapshot_accumulator := 0.0
var _spawn_index := 0


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_register_tank(tank, 1)
	var session_state := NetworkSessionType.State.OFFLINE
	if network_session != null:
		session_state = network_session.state
	if session_state == NetworkSessionType.State.HOSTING:
		status_label.text = "主机模式 · UDP %d · WASD 移动 · 鼠标左键开火" % network_session.bound_port
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	elif session_state == NetworkSessionType.State.CONNECTED:
		status_label.text = "已连接 · 正在同步玩家"
		call_deferred("_request_join")
	else:
		status_label.text = "本地测试模式 · WASD 移动 · 鼠标左键开火"
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _is_server_authority():
		_pending_commands[1] = _capture_local_command()
		_command_times[1] = Time.get_ticks_msec() / 1000.0
		for player_id in _tanks:
			var player_tank: TankControllerType = _tanks[player_id]
			if player_tank.destroyed:
				continue
			var command: Dictionary = _pending_commands.get(player_id, _neutral_command())
			var received_at: float = _command_times.get(player_id, 0.0)
			if player_id != 1 and Time.get_ticks_msec() / 1000.0 - received_at > Config.INPUT_TIMEOUT:
				command = _neutral_command()
			player_tank.apply_command(command, delta)
		_snapshot_accumulator += delta
		if _is_networked() and _snapshot_accumulator >= Config.SNAPSHOT_INTERVAL:
			_snapshot_accumulator = 0.0
			receive_snapshot.rpc(_build_snapshot())
	elif _is_networked():
		_input_accumulator += delta
		if _input_accumulator >= 1.0 / 30.0:
			_input_accumulator = 0.0
			submit_input.rpc_id(1, _capture_local_command())
	else:
		var local_tank: TankControllerType = _tanks.get(_local_player_id, tank)
		local_tank.apply_command(_capture_local_command(), delta)


func _capture_local_command() -> Dictionary:
	var local_tank: TankControllerType = _tanks.get(_local_player_id, tank)
	var aim := get_global_mouse_position() - local_tank.global_position
	_input_sequence += 1
	return Command.sanitize({
		"movement": Input.get_vector("move_left", "move_right", "move_up", "move_down"),
		"aim": aim,
		"fire": Input.is_action_pressed("fire"),
		"sequence": _input_sequence,
	})


func _neutral_command() -> Dictionary:
	return {"movement": Vector2.ZERO, "aim": Vector2.RIGHT, "fire": false, "sequence": 0}


func _is_networked() -> bool:
	return network_session != null and network_session.state != NetworkSessionType.State.OFFLINE


func _is_server_authority() -> bool:
	return not _is_networked() or multiplayer.is_server()


func _register_tank(player_tank: TankControllerType, player_id: int) -> void:
	player_tank.tank_id = player_id
	player_tank.set_multiplayer_authority(1)
	if not player_tank.shot_requested.is_connected(_on_tank_shot_requested):
		player_tank.shot_requested.connect(_on_tank_shot_requested)
	_tanks[player_id] = player_tank


func _spawn_tank_local(player_id: int, spawn_position: Vector2) -> TankControllerType:
	if _tanks.has(player_id):
		var existing: TankControllerType = _tanks[player_id]
		existing.global_position = spawn_position
		return existing
	var spawned: TankControllerType = TankScene.instantiate()
	add_child(spawned)
	spawned.global_position = spawn_position
	_register_tank(spawned, player_id)
	return spawned


func _next_spawn_position() -> Vector2:
	var positions := [Vector2(640, 360), Vector2(220, 160), Vector2(1060, 560), Vector2(1060, 160), Vector2(220, 560)]
	var result: Vector2 = positions[_spawn_index % positions.size()]
	_spawn_index += 1
	return result


func _on_tank_shot_requested(origin: Vector2, direction: Vector2, owner_id: int, sequence: int) -> void:
	if not _is_server_authority():
		return
	_spawn_projectile(origin, direction, owner_id, sequence)
	if _is_networked():
		spawn_projectile_remote.rpc(origin, direction, owner_id, sequence)


func _spawn_projectile(origin: Vector2, direction: Vector2, owner_id: int, sequence: int) -> void:
	var projectile: ProjectileControllerType = ProjectileScene.instantiate()
	add_child(projectile)
	projectile.setup(origin, direction, owner_id, sequence)
	if _is_server_authority():
		projectile.hit_target.connect(_on_projectile_hit)


func _on_projectile_hit(target: TankControllerType) -> void:
	if not _is_server_authority() or target.destroyed:
		return
	target.apply_damage(Config.PROJECTILE_DAMAGE)


func _on_peer_connected(peer_id: int) -> void:
	_pending_commands[peer_id] = _neutral_command()
	_command_times[peer_id] = Time.get_ticks_msec() / 1000.0


func _on_peer_disconnected(peer_id: int) -> void:
	_pending_commands.erase(peer_id)
	_command_times.erase(peer_id)
	if _tanks.has(peer_id):
		var remote_tank: TankControllerType = _tanks[peer_id]
		_tanks.erase(peer_id)
		remote_tank.queue_free()
		despawn_tank_remote.rpc(peer_id)


@rpc("any_peer", "reliable")
func request_join() -> void:
	if not _is_server_authority() or not _is_networked():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 1 or _tanks.has(peer_id):
		return
	var spawn_position := _next_spawn_position()
	_spawn_tank_local(peer_id, spawn_position)
	_pending_commands[peer_id] = _neutral_command()
	_command_times[peer_id] = Time.get_ticks_msec() / 1000.0
	spawn_tank_remote.rpc(peer_id, spawn_position)
	assign_player.rpc_id(peer_id, peer_id, spawn_position)


@rpc("authority", "call_remote", "reliable")
func spawn_tank_remote(player_id: int, spawn_position: Vector2) -> void:
	_spawn_tank_local(player_id, spawn_position)


@rpc("authority", "call_remote", "reliable")
func assign_player(player_id: int, spawn_position: Vector2) -> void:
	_local_player_id = player_id
	var local_tank := _spawn_tank_local(player_id, spawn_position)
	local_tank.tank_id = player_id
	status_label.text = "玩家 %d 已加入 · WASD 移动 · 鼠标左键开火" % player_id


@rpc("authority", "call_remote", "reliable")
func despawn_tank_remote(player_id: int) -> void:
	if not _tanks.has(player_id):
		return
	var remote_tank: TankControllerType = _tanks[player_id]
	_tanks.erase(player_id)
	remote_tank.queue_free()


@rpc("any_peer", "unreliable_ordered")
func submit_input(payload: Dictionary) -> void:
	if not _is_server_authority() or not _is_networked():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 1 or not _tanks.has(peer_id):
		return
	_pending_commands[peer_id] = Command.sanitize(payload)
	_command_times[peer_id] = Time.get_ticks_msec() / 1000.0


@rpc("authority", "call_remote", "unreliable_ordered")
func receive_snapshot(snapshot: Array) -> void:
	if _is_server_authority():
		return
	for state: Dictionary in snapshot:
		var player_id: int = state.id
		var player_tank: TankControllerType = _tanks.get(player_id)
		if player_tank == null:
			player_tank = _spawn_tank_local(player_id, state.position)
		player_tank.global_position = state.position
		player_tank.set_aim(state.aim)
		player_tank.health = clampi(int(state.health), 0, player_tank.max_health)
		player_tank.destroyed = player_tank.health <= 0


@rpc("authority", "call_remote", "unreliable_ordered")
func spawn_projectile_remote(origin: Vector2, direction: Vector2, owner_id: int, sequence: int) -> void:
	_spawn_projectile(origin, direction, owner_id, sequence)


func _request_join() -> void:
	if _is_networked() and not multiplayer.is_server():
		request_join.rpc_id(1)


func _on_back_pressed() -> void:
	if network_session != null:
		network_session.leave_game()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _build_snapshot() -> Array:
	var snapshot: Array = []
	for player_id in _tanks:
		var player_tank: TankControllerType = _tanks[player_id]
		snapshot.append({
			"id": player_id,
			"position": player_tank.global_position,
			"aim": player_tank.get_aim(),
			"health": player_tank.health,
		})
	return snapshot


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color("#101a22"), true)
	draw_rect(Rect2(48.0, 48.0, 1184.0, 624.0), Color("#172a31"), true)
	for x in range(48, 1233, 48):
		draw_line(Vector2(x, 48), Vector2(x, 672), Color(0.15, 0.31, 0.31, 0.3), 1.0)
	for y in range(48, 673, 48):
		draw_line(Vector2(48, y), Vector2(1232, y), Color(0.15, 0.31, 0.31, 0.3), 1.0)
	draw_rect(Rect2(48.0, 48.0, 1184.0, 624.0), Color("#67d6a4"), false, 3.0)
