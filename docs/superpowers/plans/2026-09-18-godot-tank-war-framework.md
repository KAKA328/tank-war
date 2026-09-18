# Godot Tank War Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build a runnable Godot 4 framework for a server-authoritative 2D tank game with LAN/UDP-tunnel connection flow and testable AI/combat foundations.

**Architecture:** A small main scene owns menu presentation while an autoloaded `NetworkSession` owns ENet lifecycle. Pure scripts parse endpoints, reflect trajectories, and score projectile threats so the same deterministic logic can run on the authoritative host and in headless tests.

**Tech Stack:** Godot 4.7, typed GDScript, ENet/UDP, dependency-free headless GDScript tests.

**Status:** Framework and 1v1 match loop implemented; final verification completed on 2026-09-19.

The follow-up gameplay slice is also implemented: bounded tank commands, arena integration, tank and projectile scenes, menu-to-arena transition, server-side input routing, snapshots, player spawning, host-side damage, respawn, score, match-over and restart. The current verification suite reports 61 passing checks.

## 1v1 Match Loop Addendum

**Goal:** Complete a host-authoritative 1v1 match with configurable respawn delay and winning score.

**Architecture:** `MatchRules` is a pure state machine that accepts server-side kill events and time advancement. The arena owns one instance, applies respawn commands to tanks, broadcasts match snapshots, and exposes a HUD. Clients never mutate health, score, respawn, or winner state.

**Files:**
- Create: `src/match/match_rules.gd`
- Modify: `scenes/world/arena.tscn`
- Create: `tests/network_host_smoke.gd`
- Create: `tests/network_client_smoke.gd`
- Modify: `src/world/arena.gd`
- Modify: `src/actors/tank_controller.gd`
- Modify: `tests/test_core.gd`

### Task 6: Match rules through TDD

- [x] Write tests for start state, one-time scoring, respawn countdown, configurable target score, and match-over rejection.
- [x] Implement `MatchRules` as a dependency-free state machine.
- [x] Run the headless suite and keep all existing checks green (61 checks).

### Task 7: Server integration

- [x] Connect tank destruction to the server-owned match state.
- [x] Apply configurable respawn positions and countdown through the host.
- [x] Broadcast match snapshots to clients and reject client-side match mutations.

### Task 8: HUD and two-process verification

- [x] Add score, health, respawn countdown, and match-over controls.
- [x] Run host and client Godot processes on `127.0.0.1:7010`.
- [x] Verify movement, firing, damage, death, respawn, scoring, match-over, and restart.

---

## File map

- `project.godot`: project settings, main scene, display size, and `NetworkSession` autoload.
- `src/core/game_config.gd`: shared port and player-count constants.
- `src/network/network_endpoint.gd`: validates and parses `host[:port]` strings.
- `src/network/network_session.gd`: creates/joins/closes ENet sessions and emits UI-safe status signals.
- `src/combat/trajectory.gd`: deterministic reflection calculation.
- `src/ai/threat_evaluator.gd`: calculates time until a moving projectile reaches a tank danger radius.
- `src/ui/main_menu.gd`: adapts buttons and text fields to `NetworkSession` calls.
- `scenes/ui/main_menu.tscn`: runnable connection menu.
- `src/match/match_rules.gd`: dependency-free score, respawn, and match-over state machine.
- `src/world/arena.gd`: host-authoritative simulation, match snapshots, and restart RPC.
- `scenes/world/arena.tscn`: match HUD and restart controls.
- `tests/run_tests.gd`: minimal headless test runner.
- `tests/test_core.gd`: behavior tests for parsing, reflection, threat timing, session defaults, tank respawn, HUD nodes, and match rules.
- `tests/network_host_smoke.gd` / `tests/network_client_smoke.gd`: two-process connection and full-match acceptance tests.

### Task 1: Project configuration and headless test harness

**Files:**
- Create: `project.godot`
- Create: `.gitignore`
- Create: `tests/run_tests.gd`

- [x] **Step 1: Add project configuration**

```ini
[application]
run/main_scene="res://scenes/ui/main_menu.tscn"

[autoload]
NetworkSession="*res://src/network/network_session.gd"
```

- [x] **Step 2: Add a runner that loads test suites and exits nonzero on failure**

```gdscript
extends SceneTree

func _initialize() -> void:
    var failures := TestCore.run_all()
    quit(1 if failures > 0 else 0)
```

- [x] **Step 3: Run the empty harness**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: exit code `0` after reporting the suite summary.

### Task 2: Endpoint parsing through TDD

**Files:**
- Create: `tests/test_core.gd`
- Create: `src/network/network_endpoint.gd`
- Create: `src/core/game_config.gd`

- [x] **Step 1: Write parsing tests**

```gdscript
assert_equal(NetworkEndpoint.parse("192.168.1.8"), {"ok": true, "host": "192.168.1.8", "port": 7000})
assert_equal(NetworkEndpoint.parse("example.net:8123"), {"ok": true, "host": "example.net", "port": 8123})
assert_false(NetworkEndpoint.parse("host:70000").ok)
```

- [x] **Step 2: Run and verify RED**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: FAIL because `network_endpoint.gd` does not exist.

- [x] **Step 3: Implement the minimum parser**

```gdscript
static func parse(text: String, default_port: int = 7000) -> Dictionary:
    var value := text.strip_edges()
    if value.is_empty():
        return {"ok": false, "error": "服务器地址不能为空"}
    var parts := value.rsplit(":", true, 1)
    var port := default_port if parts.size() == 1 else int(parts[1])
    if port < 1 or port > 65535:
        return {"ok": false, "error": "端口必须在 1 到 65535 之间"}
    return {"ok": true, "host": parts[0], "port": port}
```

- [x] **Step 4: Run and verify GREEN**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: all endpoint tests pass.

### Task 3: Combat and AI calculations through TDD

**Files:**
- Modify: `tests/test_core.gd`
- Create: `src/combat/trajectory.gd`
- Create: `src/ai/threat_evaluator.gd`

- [x] **Step 1: Write reflection and threat tests**

```gdscript
assert_vector_close(Trajectory.reflect_velocity(Vector2(10, 0), Vector2(-1, 0)), Vector2(-10, 0))
assert_float_close(ThreatEvaluator.time_to_impact(Vector2(100, 0), Vector2(-50, 0), 10.0), 1.8)
assert_equal(ThreatEvaluator.time_to_impact(Vector2(100, 0), Vector2(50, 0), 10.0), -1.0)
```

- [x] **Step 2: Run and verify RED**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: FAIL because calculation scripts do not exist.

- [x] **Step 3: Implement deterministic calculations**

```gdscript
static func reflect_velocity(velocity: Vector2, surface_normal: Vector2) -> Vector2:
    return velocity.bounce(surface_normal.normalized())

static func time_to_impact(relative_position: Vector2, relative_velocity: Vector2, danger_radius: float) -> float:
    var closing_speed := -relative_position.normalized().dot(relative_velocity)
    if closing_speed <= 0.0:
        return -1.0
    return maxf(0.0, (relative_position.length() - danger_radius) / closing_speed)
```

- [x] **Step 4: Run and verify GREEN**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: all combat and AI tests pass.

### Task 4: Session lifecycle and runnable menu

**Files:**
- Modify: `tests/test_core.gd`
- Create: `src/network/network_session.gd`
- Create: `src/ui/main_menu.gd`
- Create: `scenes/ui/main_menu.tscn`

- [x] **Step 1: Write session-default tests**

```gdscript
var session := NetworkSessionClass.new()
assert_equal(session.state, NetworkSessionClass.State.OFFLINE)
assert_equal(session.bound_port, 0)
```

- [x] **Step 2: Run and verify RED**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: FAIL because `network_session.gd` does not exist.

- [x] **Step 3: Implement ENet host/join/leave methods and status signals**

```gdscript
func host_game(port: int = GameConfig.DEFAULT_PORT) -> Error:
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(port, GameConfig.MAX_PLAYERS)
    if error == OK:
        multiplayer.multiplayer_peer = peer
        state = State.HOSTING
    return error
```

- [x] **Step 4: Connect the menu to the session API**

```gdscript
func _on_host_pressed() -> void:
    NetworkSession.host_game(int(port_edit.text))

func _on_join_pressed() -> void:
    NetworkSession.join_game(address_edit.text)
```

- [x] **Step 5: Run and verify GREEN**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: all session-default tests pass.

### Task 5: Final import and runtime verification

**Files:**
- Verify: all files above

- [x] **Step 1: Run the complete headless suite**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: exit code `0`, all checks pass, no parser errors.

- [x] **Step 2: Import the project without opening a window**

Run: `godot --headless --path . --editor --quit`
Expected: exit code `0`, no missing resource or invalid project-setting errors.

- [x] **Step 3: Launch the main scene briefly**

Run: `godot --headless --path . --quit-after 2`
Expected: menu scene initializes and exits without runtime errors.

