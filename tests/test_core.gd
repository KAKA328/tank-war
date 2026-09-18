extends RefCounted

const NetworkEndpoint = preload("res://src/network/network_endpoint.gd")
const NetworkSessionClass = preload("res://src/network/network_session.gd")
const TankCommand = preload("res://src/combat/tank_command.gd")
const TankSimulation = preload("res://src/combat/tank_simulation.gd")
const ThreatEvaluator = preload("res://src/ai/threat_evaluator.gd")
const Trajectory = preload("res://src/combat/trajectory.gd")
const MainMenuScene = preload("res://scenes/ui/main_menu.tscn")
const MainMenuScript = preload("res://src/ui/main_menu.gd")
const TankScene = preload("res://scenes/world/tank.tscn")
const ArenaScene = preload("res://scenes/world/arena.tscn")
const ServerScene = preload("res://server/server.tscn")
const MatchRules = preload("res://src/match/match_rules.gd")

var check_count := 0
var _failures := 0


func run_all() -> int:
	_test_endpoint_uses_default_port()
	_test_endpoint_accepts_explicit_port()
	_test_endpoint_accepts_websocket_urls()
	_test_transport_selection()
	_test_endpoint_rejects_invalid_values()
	_test_session_starts_offline_and_rejects_invalid_input()
	_test_reflection_uses_surface_normal()
	_test_threat_time_detects_approach_and_miss()
	_test_tank_command_is_bounded_and_normalized()
	_test_tank_simulation_clamps_to_arena_bounds()
	_test_tank_health_is_server_mutated()
	_test_main_menu_exposes_connection_controls()
	_test_main_menu_opens_arena_after_connection()
	_test_arena_exposes_tank_and_status_nodes()
	_test_websocket_server_scene_exposes_script()
	_test_match_rules_score_respawn_and_finish()
	return _failures


func _test_endpoint_uses_default_port() -> void:
	_assert_equal(
		NetworkEndpoint.parse("192.168.1.8"),
		{"ok": true, "host": "192.168.1.8", "port": 7000},
		"address without port uses the game default"
	)


func _test_endpoint_accepts_explicit_port() -> void:
	_assert_equal(
		NetworkEndpoint.parse(" example.net:8123 "),
		{"ok": true, "host": "example.net", "port": 8123},
		"address accepts an explicit port and surrounding spaces"
	)


func _test_endpoint_accepts_websocket_urls() -> void:
	var endpoint := NetworkEndpoint.parse("wss://game.example.com/match")
	_assert_true(endpoint.get("ok", false), "WebSocket URL is accepted")
	_assert_equal(endpoint.get("scheme", ""), "wss", "WebSocket scheme is preserved")
	_assert_equal(endpoint.get("url", ""), "wss://game.example.com/match", "WebSocket URL is preserved")


func _test_transport_selection() -> void:
	var websocket_endpoint := NetworkEndpoint.parse("wss://game.example.com/match")
	var native_endpoint := NetworkEndpoint.parse("192.168.1.8:7000")
	_assert_equal(NetworkSessionClass.transport_for_endpoint(websocket_endpoint), "websocket", "WebSocket endpoint selects WebSocket transport")
	_assert_equal(NetworkSessionClass.transport_for_endpoint(native_endpoint), "enet", "native endpoint selects ENet transport")


func _test_endpoint_rejects_invalid_values() -> void:
	_assert_false(NetworkEndpoint.parse("").get("ok", true), "empty address is rejected")
	_assert_false(NetworkEndpoint.parse("host:").get("ok", true), "missing port is rejected")
	_assert_false(NetworkEndpoint.parse("host:abc").get("ok", true), "nonnumeric port is rejected")
	_assert_false(NetworkEndpoint.parse("host:70000").get("ok", true), "out-of-range port is rejected")


func _test_session_starts_offline_and_rejects_invalid_input() -> void:
	var session := NetworkSessionClass.new()
	_assert_equal(session.state, NetworkSessionClass.State.OFFLINE, "session starts offline")
	_assert_equal(session.bound_port, 0, "offline session has no bound port")
	_assert_equal(session.host_game(0), ERR_INVALID_PARAMETER, "host rejects port zero")
	_assert_equal(session.join_game(""), ERR_INVALID_PARAMETER, "join rejects an empty endpoint")
	_assert_equal(session.state, NetworkSessionClass.State.OFFLINE, "invalid input keeps session offline")
	session.state = NetworkSessionClass.State.HOSTING
	session.bound_port = 7000
	_assert_equal(session.host_game(0), ERR_INVALID_PARAMETER, "active session still rejects an invalid port")
	_assert_equal(session.state, NetworkSessionClass.State.HOSTING, "invalid request preserves active session state")
	_assert_equal(session.bound_port, 7000, "invalid request preserves active bound port")
	session.free()


func _test_reflection_uses_surface_normal() -> void:
	_assert_vector_close(
		Trajectory.reflect_velocity(Vector2(10.0, 0.0), Vector2(-1.0, 0.0)),
		Vector2(-10.0, 0.0),
		"horizontal impact reflects horizontal velocity"
	)
	_assert_vector_close(
		Trajectory.reflect_velocity(Vector2(10.0, 10.0), Vector2.UP),
		Vector2(10.0, -10.0),
		"floor normal reflects the vertical component"
	)


func _test_threat_time_detects_approach_and_miss() -> void:
	_assert_float_close(
		ThreatEvaluator.time_to_impact(Vector2(100.0, 0.0), Vector2(-50.0, 0.0), 10.0),
		1.8,
		"approaching projectile returns first circle intersection"
	)
	_assert_float_close(
		ThreatEvaluator.time_to_impact(Vector2(100.0, 10.0), Vector2(-50.0, 0.0), 10.0),
		2.0,
		"tangent projectile is detected"
	)
	_assert_equal(
		ThreatEvaluator.time_to_impact(Vector2(100.0, 20.0), Vector2(-50.0, 0.0), 10.0),
		-1.0,
		"projectile outside the danger circle is not a threat"
	)
	_assert_equal(
		ThreatEvaluator.time_to_impact(Vector2(100.0, 0.0), Vector2(50.0, 0.0), 10.0),
		-1.0,
		"departing projectile is not a threat"
	)


func _test_tank_command_is_bounded_and_normalized() -> void:
	var command := TankCommand.sanitize({
		"movement": Vector2(3.0, 4.0),
		"aim": Vector2.ZERO,
		"fire": 1,
		"sequence": -9,
	})
	_assert_vector_close(command.movement, Vector2(0.6, 0.8), "movement is clamped to unit length")
	_assert_vector_close(command.aim, Vector2.RIGHT, "zero aim uses a stable fallback direction")
	_assert_equal(command.fire, true, "fire input is normalized to a boolean")
	_assert_equal(command.sequence, 0, "negative sequence numbers are rejected")


func _test_tank_simulation_clamps_to_arena_bounds() -> void:
	var result := TankSimulation.integrate(
		Vector2(95.0, 50.0),
		{"movement": Vector2.RIGHT, "aim": Vector2.RIGHT, "sequence": 1},
		100.0,
		0.1,
		Rect2(0.0, 0.0, 100.0, 100.0)
	)
	_assert_vector_close(result.position, Vector2(100.0, 50.0), "tank position is clamped to arena bounds")
	_assert_vector_close(result.velocity, Vector2(100.0, 0.0), "tank velocity follows sanitized movement")


func _test_tank_health_is_server_mutated() -> void:
	var tank := TankScene.instantiate()
	_assert_equal(tank.health, 100, "tank starts with full health")
	_assert_equal(tank.apply_damage(25), 75, "damage reduces health")
	_assert_false(tank.destroyed, "nonlethal damage keeps tank alive")
	_assert_equal(tank.apply_damage(100), 0, "lethal damage clamps health at zero")
	_assert_true(tank.destroyed, "lethal damage marks tank destroyed")
	tank.respawn(Vector2(123.0, 456.0))
	_assert_equal(tank.global_position, Vector2(123.0, 456.0), "respawn moves tank to its spawn point")
	_assert_equal(tank.health, tank.max_health, "respawn restores full health")
	_assert_false(tank.destroyed, "respawn clears destroyed state")
	tank.free()


func _test_main_menu_exposes_connection_controls() -> void:
	var menu := MainMenuScene.instantiate()
	var menu_script: Script = menu.get_script()
	_assert_true(menu_script != null and menu_script.can_instantiate(), "menu script compiles and can instantiate")
	_assert_true(menu.get_node_or_null("Panel/Margin/VBox/HostRow/Port") != null, "menu has a host port field")
	_assert_true(menu.get_node_or_null("Panel/Margin/VBox/JoinRow/Address") != null, "menu has a join address field")
	_assert_true(menu.get_node_or_null("Panel/Margin/VBox/Status") != null, "menu has a status label")
	_assert_equal(menu.get_node("Panel/Margin/VBox/HostRow/Port").text, "7000", "menu uses the default host port")
	_assert_equal(menu.get_node("Panel/Margin/VBox/JoinRow/Address").text, "127.0.0.1:7000", "menu defaults to loopback")
	menu.free()


func _test_arena_exposes_tank_and_status_nodes() -> void:
	var arena := ArenaScene.instantiate()
	_assert_true(arena.get_script() != null and arena.get_script().can_instantiate(), "arena script compiles and can instantiate")
	_assert_true(arena.get_node_or_null("Tank") != null, "arena has a local tank node")
	_assert_true(arena.get_node_or_null("Hud/Status") != null, "arena has a status label")
	_assert_true(arena.get_node_or_null("Hud/Score") != null, "arena has a score label")
	_assert_true(arena.get_node_or_null("Hud/Restart") != null, "arena has a restart button")
	arena.free()


func _test_websocket_server_scene_exposes_script() -> void:
	var server := ServerScene.instantiate()
	_assert_true(server.get_script() != null and server.get_script().can_instantiate(), "WebSocket server scene script compiles")
	server.free()


func _test_main_menu_opens_arena_after_connection() -> void:
	_assert_true(
		MainMenuScript.should_open_arena(NetworkSessionClass.State.HOSTING),
		"host state opens the arena"
	)
	_assert_true(
		MainMenuScript.should_open_arena(NetworkSessionClass.State.CONNECTED),
		"connected state opens the arena"
	)
	_assert_false(
		MainMenuScript.should_open_arena(NetworkSessionClass.State.OFFLINE),
		"offline state stays in the menu"
	)


func _test_match_rules_score_respawn_and_finish() -> void:
	var rules := MatchRules.new(2, 3.0)
	_assert_equal(rules.state, MatchRules.State.WAITING, "match starts waiting")
	rules.start_match([1, 2])
	_assert_equal(rules.state, MatchRules.State.PLAYING, "match starts playing")
	_assert_equal(rules.score_for(1), 0, "players start with zero score")
	var first_kill := rules.record_kill(1, 2)
	_assert_true(first_kill.accepted, "server accepts a kill during play")
	_assert_equal(rules.score_for(1), 1, "killer receives one point")
	_assert_true(rules.is_respawning(2), "victim enters respawn state")
	_assert_false(rules.record_kill(1, 2).accepted, "duplicate kill during respawn is rejected")
	_assert_equal(rules.advance(2.9).size(), 0, "respawn waits for the configured delay")
	_assert_equal(rules.advance(0.1), [2], "victim becomes ready after the delay")
	_assert_false(rules.is_respawning(2), "victim leaves respawn state")
	rules.record_kill(1, 2)
	_assert_equal(rules.state, MatchRules.State.MATCH_OVER, "target score ends the match")
	_assert_equal(rules.winner_id, 1, "killer becomes the winner")
	_assert_false(rules.record_kill(2, 1).accepted, "match over rejects further kills")


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	check_count += 1
	if actual != expected:
		_failures += 1
		push_error("%s: expected %s, got %s" % [label, expected, actual])


func _assert_false(actual: bool, label: String) -> void:
	_assert_equal(actual, false, label)


func _assert_true(actual: bool, label: String) -> void:
	_assert_equal(actual, true, label)


func _assert_float_close(actual: float, expected: float, label: String, tolerance := 0.0001) -> void:
	check_count += 1
	if not is_equal_approx(actual, expected) and absf(actual - expected) > tolerance:
		_failures += 1
		push_error("%s: expected %f, got %f" % [label, expected, actual])


func _assert_vector_close(actual: Vector2, expected: Vector2, label: String, tolerance := 0.0001) -> void:
	check_count += 1
	if actual.distance_to(expected) > tolerance:
		_failures += 1
		push_error("%s: expected %s, got %s" % [label, expected, actual])
