class_name NetworkEndpoint
extends RefCounted

const Config = preload("res://src/core/game_config.gd")


static func parse(text: String, default_port: int = Config.DEFAULT_PORT) -> Dictionary:
	var value := text.strip_edges()
	if value.is_empty():
		return _error("服务器地址不能为空")
	if default_port < 1 or default_port > 65535:
		return _error("默认端口必须在 1 到 65535 之间")

	var host := value
	var port := default_port
	var separator_index := value.rfind(":")
	if separator_index >= 0:
		host = value.left(separator_index).strip_edges()
		var port_text := value.substr(separator_index + 1).strip_edges()
		if port_text.is_empty() or not port_text.is_valid_int():
			return _error("端口必须是整数")
		port = int(port_text)

	if host.is_empty():
		return _error("服务器地址不能为空")
	if port < 1 or port > 65535:
		return _error("端口必须在 1 到 65535 之间")

	return {"ok": true, "host": host, "port": port}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
