extends SceneTree

const ArenaScene = preload("res://scenes/world/arena.tscn")

var _arena: Node
var _elapsed := 0.0
var _initial_host_position := Vector2.ZERO
var _saw_host_move := false
var _saw_remote_move := false
var _saw_damage := false
var _saw_death := false
var _saw_respawn := false
var _saw_score := false
var _saw_match_over := false
var _saw_restart := false
var _restart_seen_at := -1.0
var _death_seen_at := -1.0
var _remote_id := 0
var _initial_remote_position := Vector2.ZERO


func _initialize() -> void:
	call_deferred("_start_host")


func _start_host() -> void:
	var session = get_root().get_node("NetworkSession")
	var result: Error = session.host_game(7010)
	if result != OK:
		push_error("SMOKE_HOST_FAILED: %s" % error_string(result))
		quit(1)
		return
	_arena = ArenaScene.instantiate()
	get_root().add_child(_arena)
	_initial_host_position = _arena.get_node("Tank").global_position
	Input.action_press("move_right")
	print("SMOKE_HOST_READY")


func _process(delta: float) -> bool:
	_elapsed += delta
	if _arena == null:
		return false
	if _elapsed >= 0.6:
		Input.action_release("move_right")
	var tanks: Dictionary = _arena.get("_tanks")
	if _remote_id == 0 and tanks.size() >= 2:
		for candidate in tanks.keys():
			if int(candidate) != 1:
				_remote_id = int(candidate)
				_initial_remote_position = tanks[_remote_id].global_position
				break
	if tanks.has(1):
		var host_tank = tanks[1]
		_saw_host_move = _saw_host_move or host_tank.global_position.distance_to(_initial_host_position) > 8.0
		_saw_damage = _saw_damage or host_tank.health < host_tank.max_health
		if host_tank.destroyed and not _saw_death:
			_saw_death = true
			_death_seen_at = _elapsed
		if _saw_death and not host_tank.destroyed and _elapsed - _death_seen_at > 2.5:
			_saw_respawn = true
	if _remote_id != 0 and tanks.has(_remote_id):
		_saw_remote_move = _saw_remote_move or tanks[_remote_id].global_position.distance_to(_initial_remote_position) > 8.0
	var rules = _arena.get("_match_rules")
	if rules != null:
		for score in rules.snapshot().get("scores", {}).values():
			_saw_score = _saw_score or int(score) > 0
		if rules.state == 2:
			_saw_match_over = true
		var scores: Dictionary = rules.snapshot().get("scores", {})
		var scores_zero := true
		for score in scores.values():
			scores_zero = scores_zero and int(score) == 0
		if _saw_match_over and rules.state == 1 and scores_zero:
			_saw_restart = true
			if _restart_seen_at < 0.0:
				_restart_seen_at = _elapsed
	if _saw_restart and _elapsed - _restart_seen_at >= 5.0:
		return _finish(0)
	if _elapsed >= 45.0:
		return _finish(2)
	return false


func _finish(code: int) -> bool:
	print("SMOKE_HOST_TANKS=%d" % int(_arena.get("_tanks").size()))
	print("SMOKE_HOST_FLAGS move=%s remote_move=%s damage=%s death=%s respawn=%s score=%s over=%s restart=%s" % [_saw_host_move, _saw_remote_move, _saw_damage, _saw_death, _saw_respawn, _saw_score, _saw_match_over, _saw_restart])
	quit(code if _saw_host_move and _saw_remote_move and _saw_damage and _saw_death and _saw_respawn and _saw_score and _saw_match_over and _saw_restart else 3)
	return true
