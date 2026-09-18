extends Control

const NetworkSessionType = preload("res://src/network/network_session.gd")
const ArenaScenePath := "res://scenes/world/arena.tscn"

@onready var port_edit: LineEdit = $Panel/Margin/VBox/HostRow/Port
@onready var address_edit: LineEdit = $Panel/Margin/VBox/JoinRow/Address
@onready var host_button: Button = $Panel/Margin/VBox/HostRow/HostButton
@onready var join_button: Button = $Panel/Margin/VBox/JoinRow/JoinButton
@onready var leave_button: Button = $Panel/Margin/VBox/LeaveButton
@onready var status_label: Label = $Panel/Margin/VBox/Status
@onready var network_session: NetworkSessionType = get_node("/root/NetworkSession")

var _arena_opening := false


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	network_session.state_changed.connect(_on_session_state_changed)
	if OS.has_feature("web"):
		port_edit.visible = false
		host_button.visible = false
		$Panel/Margin/VBox/HostHint.text = "浏览器模式"
		address_edit.text = "wss://127.0.0.1:7001"
		address_edit.placeholder_text = "wss://服务器域名/路径"
		$Panel/Margin/VBox/Subtitle.text = "浏览器 WebSocket 联机"
	_on_session_state_changed(network_session.state, "未连接")


func _on_host_pressed() -> void:
	var text := port_edit.text.strip_edges()
	if not text.is_valid_int():
		status_label.text = "端口必须是整数"
		return
	network_session.host_game(int(text))


func _on_join_pressed() -> void:
	network_session.join_game(address_edit.text)


func _on_leave_pressed() -> void:
	network_session.leave_game()


func _on_session_state_changed(next_state: int, message: String) -> void:
	status_label.text = message
	leave_button.disabled = next_state == NetworkSessionType.State.OFFLINE
	host_button.disabled = next_state != NetworkSessionType.State.OFFLINE
	join_button.disabled = next_state != NetworkSessionType.State.OFFLINE
	if should_open_arena(next_state) and not _arena_opening:
		_arena_opening = true
		call_deferred("_open_arena")


static func should_open_arena(next_state: int) -> bool:
	return next_state == NetworkSessionType.State.HOSTING or next_state == NetworkSessionType.State.CONNECTED


func _open_arena() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file(ArenaScenePath)
