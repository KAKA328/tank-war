# Web Play Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let friends open a Godot Web build from GitHub Pages while the existing authoritative match simulation runs through a WebSocket-capable headless server.

**Architecture:** Keep `Arena` and its RPC messages transport-neutral. `NetworkSession` selects ENet/UDP for native builds and WebSocket for `ws://` or `wss://` endpoints. A separate headless server entry point owns the same scene and authoritative Arena; GitHub Pages only serves the static web export.

**Tech Stack:** Godot 4.7 GDScript, `WebSocketMultiplayerPeer`, Godot Web export (WebAssembly/WebGL 2 Compatibility), GitHub Actions Pages deployment.

---

### Task 1: Transport selection through TDD

**Files:**
- Modify: `src/network/network_endpoint.gd`
- Modify: `src/network/network_session.gd`
- Modify: `tests/test_core.gd`

- [x] Test parsing `ws://host:port/path` and `wss://host/path` without changing native `host:port` behavior.
- [x] Test that a WebSocket client session selects `WebSocketMultiplayerPeer` and native sessions still select ENet.
- [x] Implement explicit `host_websocket_game()` for a headless server and `join_game()` scheme detection.
- [x] Run the headless suite and verify all existing tests remain green (67 checks).

### Task 2: Browser menu and server entry point

**Files:**
- Modify: `src/ui/main_menu.gd`
- Modify: `scenes/ui/main_menu.tscn`
- Create: `server/websocket_server.gd`
- Create: `server/server.tscn`

- [x] In Web builds, hide the native host controls and present a configurable `wss://` server URL.
- [x] Add a headless server entry point that binds WebSocket, instantiates `Arena`, and keeps the process alive.
- [x] Add tests for the server scene loading.

### Task 3: Web export and Pages workflow

**Files:**
- Create: `export_presets.cfg`
- Create: `.github/workflows/pages.yml`
- Modify: `.gitignore`
- Modify: `README.md`

- [x] Add a single-threaded Web export preset writing `builds/web/index.html`.
- [x] Add a Pages workflow that installs Godot 4.7.2, exports Web, adds `.nojekyll`, and deploys the artifact.
- [x] Keep `builds/` and generated exports ignored.
- [x] Document Pages URL, required external `wss://` server, and native ENet fallback.

### Task 4: Verification

**Files:**
- Modify: `tests/test_core.gd`
- Create: `tests/websocket_smoke.gd`

- [x] Run headless unit tests, editor import, and main-scene startup.
- [x] Run a native WebSocket server and WebSocket client smoke test covering connect and player assignment.
- [x] Run a local Web export and verify `index.html`, `.wasm`, `.pck`, and `.js` are generated without parser errors.
- [x] Push the implementation to the public repository.
- [ ] In repository Settings → Pages, select GitHub Actions as the Pages source.
