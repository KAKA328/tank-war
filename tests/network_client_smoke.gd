extends SceneTree

const ArenaScene = preload("res://scenes/world/arena.tscn")

var _arena: Node
var _session: Node
var _elapsed := 0.0
var _reported := false
var _saw_local_move := false
var _saw_remote_damage := false
var _saw_remote_death := false
var _saw_remote_respawn := false
var _saw_match_over := false
var _requested_restart := false
var _saw_restart := false
var _initial_local_position := Vector2.ZERO
var _death_seen_at := -1.0
var _local_id := 0
var _remote_id := 0
var _restart_seen_at := -1.0


func _initialize() -> void:
	call_deferred("_start_client")


func _start_client() -> void:
	_session = get_root().get_node("NetworkSession")
	_session.state_changed.connect(_on_state_changed)
	var result: Error = _session.join_game("127.0.0.1:7010")
	if result != OK:
		push_error("SMOKE_CLIENT_FAILED: %s" % error_string(result))
		quit(1)
		return


func _on_state_changed(next_state: int, _message: String) -> void:
	if next_state != 3 or _arena != null:
		return
	_arena = ArenaScene.instantiate()
	get_root().add_child(_arena)


func _process(delta: float) -> bool:
	_elapsed += delta
	if _arena == null:
		if _elapsed >= 45.0:
			print("SMOKE_CLIENT_TIMEOUT")
			quit(2)
		return false
	var tanks: Dictionary = _arena.get("_tanks")
	if not _reported and tanks.size() >= 2:
		_reported = true
		_local_id = int(_arena.get("_local_player_id"))
		if not tanks.has(_local_id):
			_local_id = int(tanks.keys()[0])
		for candidate in tanks.keys():
			if int(candidate) != _local_id:
				_remote_id = int(candidate)
				break
		_initial_local_position = tanks[_local_id].global_position
		_arena.set_physics_process(false)
		print("SMOKE_CLIENT_JOINED ids=%s local=%d remote=%d" % [tanks.keys(), _local_id, _remote_id])
	if _reported and tanks.has(_local_id):
		var local_tank = tanks[_local_id]
		var movement := Vector2.DOWN if _elapsed < 0.8 else Vector2.ZERO
		var aim := Vector2.RIGHT
		if tanks.has(_remote_id):
			aim = tanks[_remote_id].global_position - local_tank.global_position
		if not _saw_match_over:
			_arena.submit_input.rpc_id(1, {
				"movement": movement,
				"aim": aim,
				"fire": _elapsed >= 1.0,
				"sequence": int(_elapsed * 60.0),
			})
		_saw_local_move = _saw_local_move or local_tank.global_position.distance_to(_initial_local_position) > 8.0
		if tanks.has(_remote_id):
			_saw_remote_damage = _saw_remote_damage or tanks[_remote_id].health < tanks[_remote_id].max_health
			if tanks[_remote_id].destroyed and not _saw_remote_death:
				_saw_remote_death = true
				_death_seen_at = _elapsed
			if _saw_remote_death and not tanks[_remote_id].destroyed and _elapsed - _death_seen_at > 2.5:
				_saw_remote_respawn = true
	var snapshot: Dictionary = _arena.get("_remote_match_snapshot")
	var state := int(snapshot.get("state", 0))
	if state == 2 and not _saw_match_over:
		_saw_match_over = true
	if _saw_match_over and not _requested_restart:
		_requested_restart = true
		_arena.request_restart.rpc_id(1)
	var scores: Dictionary = snapshot.get("scores", {})
	if _saw_match_over and _requested_restart and state == 1 and scores.values().all(func(value): return int(value) == 0):
		_saw_restart = true
		if _restart_seen_at < 0.0:
			_restart_seen_at = _elapsed
	if _saw_restart and _elapsed - _restart_seen_at >= 7.0:
		if _saw_restart:
			print("SMOKE_CLIENT_FLAGS move=%s damage=%s death=%s respawn=%s over=%s restart=%s" % [_saw_local_move, _saw_remote_damage, _saw_remote_death, _saw_remote_respawn, _saw_match_over, _saw_restart])
			quit(0 if _reported and _saw_local_move and _saw_remote_damage and _saw_remote_death and _saw_remote_respawn and _saw_match_over and _saw_restart else 3)
	if _elapsed >= 45.0:
		print("SMOKE_CLIENT_TIMEOUT")
		quit(2)
	return false
