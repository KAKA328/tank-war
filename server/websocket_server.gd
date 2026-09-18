extends Node

const ArenaScene = preload("res://scenes/world/arena.tscn")
const NetworkSessionType = preload("res://src/network/network_session.gd")

@export var port := 7001

var _arena: Node


func _ready() -> void:
	var configured_port := _port_from_arguments()
	if configured_port > 0:
		port = configured_port
	var session: NetworkSessionType = get_node("/root/NetworkSession")
	var result := session.host_websocket_game(port)
	if result != OK:
		push_error("WebSocket server failed: %s" % error_string(result))
		get_tree().quit(1)
		return
	_arena = ArenaScene.instantiate()
	add_child(_arena)
	print("WEBSOCKET_SERVER_READY port=%d" % port)


func _port_from_arguments() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			var value := argument.trim_prefix("--port=")
			if value.is_valid_int():
				return int(value)
	return 0
