class_name NetworkSessionController
extends Node

const Config = preload("res://src/core/game_config.gd")
const Endpoint = preload("res://src/network/network_endpoint.gd")

signal state_changed(next_state: int, message: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

enum State {
	OFFLINE,
	HOSTING,
	CONNECTING,
	CONNECTED,
}

var state: State = State.OFFLINE
var bound_port := 0
var last_error := ""


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func host_game(port: int = Config.DEFAULT_PORT) -> Error:
	if port < 1 or port > 65535:
		return _reject("端口必须在 1 到 65535 之间")

	leave_game(false)
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port, Config.MAX_PLAYERS)
	if result != OK:
		return _reject("创建服务器失败：%s" % error_string(result), result)

	multiplayer.multiplayer_peer = peer
	bound_port = port
	_set_state(State.HOSTING, "已创建房间，UDP 端口 %d" % port)
	return OK


func join_game(endpoint_text: String) -> Error:
	var endpoint := Endpoint.parse(endpoint_text)
	if not endpoint.get("ok", false):
		return _reject(endpoint.get("error", "服务器地址无效"))

	leave_game(false)
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(endpoint.host, endpoint.port)
	if result != OK:
		return _reject("连接初始化失败：%s" % error_string(result), result)

	multiplayer.multiplayer_peer = peer
	bound_port = endpoint.port
	_set_state(State.CONNECTING, "正在连接 %s:%d" % [endpoint.host, endpoint.port])
	return OK


func leave_game(announce := true) -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	bound_port = 0
	last_error = ""
	if announce:
		_set_state(State.OFFLINE, "未连接")
	else:
		state = State.OFFLINE


func _reject(message: String, code: Error = ERR_INVALID_PARAMETER) -> Error:
	last_error = message
	state_changed.emit(state, message)
	return code


func _set_state(next_state: State, message: String) -> void:
	state = next_state
	state_changed.emit(state, message)


func _on_connected_to_server() -> void:
	_set_state(State.CONNECTED, "已连接服务器")


func _on_connection_failed() -> void:
	leave_game(false)
	_reject("无法连接服务器", ERR_CANT_CONNECT)


func _on_server_disconnected() -> void:
	leave_game(false)
	_set_state(State.OFFLINE, "服务器已断开")


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)
