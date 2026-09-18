extends Node2D

const Config = preload("res://src/core/game_config.gd")
const Command = preload("res://src/combat/tank_command.gd")
const NetworkSessionType = preload("res://src/network/network_session.gd")
const TankControllerType = preload("res://src/actors/tank_controller.gd")
const ProjectileControllerType = preload("res://src/actors/projectile_controller.gd")
const MatchRulesType = preload("res://src/match/match_rules.gd")
const TankScene = preload("res://scenes/world/tank.tscn")
const ProjectileScene = preload("res://scenes/world/projectile.tscn")

@onready var status_label: Label = $Hud/Status
@onready var score_label: Label = $Hud/Score
@onready var health_label: Label = $Hud/Health
@onready var countdown_label: Label = $Hud/Countdown
@onready var match_over_label: Label = $Hud/MatchOver
@onready var restart_button: Button = $Hud/Restart
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
var _spawn_index := 1
var _spawn_positions: Dictionary = {}
var _match_rules: MatchRulesType
var _remote_match_snapshot: Dictionary = {}


func _ready() -> void:
	_match_rules = MatchRulesType.new(Config.TARGET_SCORE, Config.RESPAWN_DELAY)
	restart_button.pressed.connect(_on_restart_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_register_tank(tank, 1)
	_spawn_positions[1] = tank.global_position
	match_over_label.visible = false
	restart_button.visible = false
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
		status_label.text = "本地测试模式 · 等待第二名玩家"
	_update_hud()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _is_server_authority():
		if _match_rules.state == MatchRulesType.State.PLAYING:
			for player_id in _match_rules.advance(delta):
				_respawn_tank(int(player_id))
		_pending_commands[1] = _capture_local_command()
		_command_times[1] = Time.get_ticks_msec() / 1000.0
		for player_id in _tanks:
			var player_tank: TankControllerType = _tanks[player_id]
			if player_tank.destroyed:
				continue
			if _match_rules.state == MatchRulesType.State.MATCH_OVER:
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
		if not local_tank.destroyed:
			local_tank.apply_command(_capture_local_command(), delta)
	_update_hud()


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
	_spawn_positions[player_id] = spawn_position
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
	if not _is_server_authority() or _match_rules.state != MatchRulesType.State.PLAYING:
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


func _on_projectile_hit(target: TankControllerType, attacker_id: int) -> void:
	if not _is_server_authority() or target.destroyed or _match_rules.state != MatchRulesType.State.PLAYING:
		return
	if target.apply_damage(Config.PROJECTILE_DAMAGE) <= 0:
		_match_rules.record_kill(attacker_id, target.tank_id)


func _on_peer_connected(peer_id: int) -> void:
	_pending_commands[peer_id] = _neutral_command()
	_command_times[peer_id] = Time.get_ticks_msec() / 1000.0


func _on_peer_disconnected(peer_id: int) -> void:
	_pending_commands.erase(peer_id)
	_command_times.erase(peer_id)
	_spawn_positions.erase(peer_id)
	if _tanks.has(peer_id):
		var remote_tank: TankControllerType = _tanks[peer_id]
		_tanks.erase(peer_id)
		remote_tank.queue_free()
		despawn_tank_remote.rpc(peer_id)
	if _tanks.size() < 2:
		_match_rules.state = MatchRulesType.State.WAITING


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
	_maybe_start_match()


func _maybe_start_match() -> void:
	if not _is_server_authority() or _match_rules.state != MatchRulesType.State.WAITING:
		return
	if _tanks.size() >= 2:
		_match_rules.start_match(_tanks.keys())


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
func receive_snapshot(snapshot: Dictionary) -> void:
	if _is_server_authority():
		return
	_remote_match_snapshot = snapshot.get("match", {})
	for state: Dictionary in snapshot.get("tanks", []):
		var player_id: int = int(state.get("id", 0))
		var player_tank: TankControllerType = _tanks.get(player_id)
		if player_tank == null:
			player_tank = _spawn_tank_local(player_id, state.get("position", Vector2.ZERO))
		player_tank.global_position = state.get("position", player_tank.global_position)
		player_tank.set_aim(state.get("aim", Vector2.RIGHT))
		player_tank.health = clampi(int(state.get("health", player_tank.max_health)), 0, player_tank.max_health)
		player_tank.destroyed = player_tank.health <= 0


@rpc("authority", "call_remote", "unreliable_ordered")
func spawn_projectile_remote(origin: Vector2, direction: Vector2, owner_id: int, sequence: int) -> void:
	_spawn_projectile(origin, direction, owner_id, sequence)


func _request_join() -> void:
	if _is_networked() and not multiplayer.is_server():
		request_join.rpc_id(1)


@rpc("any_peer", "reliable")
func request_restart() -> void:
	if not _is_server_authority() or _match_rules.state != MatchRulesType.State.MATCH_OVER:
		return
	_restart_match()


func _restart_match() -> void:
	_match_rules.start_match(_tanks.keys())
	for player_id in _tanks:
		_respawn_tank(int(player_id))
	_pending_commands.clear()
	_command_times.clear()
	if _is_networked():
		restart_remote.rpc()


@rpc("authority", "call_remote", "reliable")
func restart_remote() -> void:
	for player_id in _tanks:
		_respawn_tank(int(player_id))
	_remote_match_snapshot = _match_rules.snapshot()


func _respawn_tank(player_id: int) -> void:
	if _tanks.has(player_id):
		var player_tank: TankControllerType = _tanks[player_id]
		var spawn_position: Vector2 = _spawn_positions[player_id] if _spawn_positions.has(player_id) else _next_spawn_position()
		player_tank.respawn(spawn_position)


func _on_restart_pressed() -> void:
	if _is_server_authority() and _match_rules.state == MatchRulesType.State.MATCH_OVER:
		_restart_match()
	elif _is_networked():
		request_restart.rpc_id(1)


func _on_back_pressed() -> void:
	if network_session != null:
		network_session.leave_game()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _update_hud() -> void:
	var snapshot := _match_rules.snapshot() if _is_server_authority() else _remote_match_snapshot
	var scores: Dictionary = snapshot.get("scores", {})
	var local_tank: TankControllerType = _tanks.get(_local_player_id, tank)
	var opponent_id := 0
	for player_id in scores.keys():
		if int(player_id) != 1:
			opponent_id = int(player_id)
			break
	score_label.text = "比分  P1 %d : %d P2" % [int(scores.get(1, 0)), int(scores.get(opponent_id, 0))]
	health_label.text = "生命  %d / %d" % [local_tank.health, local_tank.max_health]
	var state := int(snapshot.get("state", MatchRulesType.State.WAITING))
	if state == MatchRulesType.State.PLAYING:
		var respawn_left := float(snapshot.get("respawns", {}).get(_local_player_id, 0.0))
		countdown_label.text = "重生 %.1f 秒" % respawn_left if respawn_left > 0.0 else "战斗中"
		match_over_label.visible = false
		restart_button.visible = false
	elif state == MatchRulesType.State.MATCH_OVER:
		var winner_id := int(snapshot.get("winner_id", 0))
		match_over_label.text = "玩家 %s 获胜" % ("1" if winner_id == 1 else "2")
		match_over_label.visible = true
		restart_button.visible = true
		countdown_label.text = "比赛结束"
	else:
		countdown_label.text = "等待两名玩家"
		match_over_label.visible = false
		restart_button.visible = false


func _build_snapshot() -> Dictionary:
	var tanks_snapshot: Array = []
	for player_id in _tanks:
		var player_tank: TankControllerType = _tanks[player_id]
		tanks_snapshot.append({
			"id": player_id,
			"position": player_tank.global_position,
			"aim": player_tank.get_aim(),
			"health": player_tank.health,
		})
	return {"tanks": tanks_snapshot, "match": _match_rules.snapshot()}


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color("#101a22"), true)
	draw_rect(Rect2(48.0, 48.0, 1184.0, 624.0), Color("#172a31"), true)
	for x in range(48, 1233, 48):
		draw_line(Vector2(x, 48), Vector2(x, 672), Color(0.15, 0.31, 0.31, 0.3), 1.0)
	for y in range(48, 673, 48):
		draw_line(Vector2(48, y), Vector2(1232, y), Color(0.15, 0.31, 0.31, 0.3), 1.0)
	draw_rect(Rect2(48.0, 48.0, 1184.0, 624.0), Color("#67d6a4"), false, 3.0)
