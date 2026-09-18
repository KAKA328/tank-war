extends SceneTree

const ArenaScene = preload("res://scenes/world/arena.tscn")
const NetworkSessionType = preload("res://src/network/network_session.gd")

var _role := ""
var _arena: Node
var _session: NetworkSessionType
var _elapsed := 0.0
var _connected := false


func _initialize() -> void:
	_role = "client"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.trim_prefix("--role=")
	call_deferred("_start")


func _start() -> void:
	_session = get_root().get_node("NetworkSession")
	if _role == "host":
		var result := _session.host_websocket_game(7011)
		if result != OK:
			push_error("WEBSOCKET_HOST_FAILED: %s" % error_string(result))
			quit(1)
			return
		_spawn_arena()
		print("WEBSOCKET_HOST_READY")
	else:
		_session.state_changed.connect(_on_state_changed)
		var result := _session.join_game("ws://127.0.0.1:7011")
		if result != OK:
			push_error("WEBSOCKET_CLIENT_FAILED: %s" % error_string(result))
			quit(1)


func _on_state_changed(next_state: int, _message: String) -> void:
	if next_state == NetworkSessionType.State.CONNECTED:
		_connected = true
		_spawn_arena()


func _spawn_arena() -> void:
	if _arena != null:
		return
	_arena = ArenaScene.instantiate()
	get_root().add_child(_arena)


func _process(delta: float) -> bool:
	_elapsed += delta
	if _arena != null and _arena.get("_tanks").size() >= 2:
		print("WEBSOCKET_%s_JOINED tanks=%d" % [_role.to_upper(), int(_arena.get("_tanks").size())])
		quit(0)
		return true
	if _elapsed >= 8.0:
		push_error("WEBSOCKET_%s_TIMEOUT connected=%s" % [_role.to_upper(), _connected])
		quit(2)
		return true
	return false
