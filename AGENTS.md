# Tank War Project Rules

## Runtime

- Target Godot 4.7.x with typed GDScript.
- Use the built-in ENet multiplayer peer over UDP.
- The host is the authoritative game server and may also be a local player.
- Keep the first milestone desktop-only: Windows host/client with LAN or UDP tunnel connectivity.

## Layout

- `scenes/ui/`: menus and lobby presentation.
- `scenes/world/`: match and gameplay scenes.
- `src/core/`: configuration and application state.
- `src/network/`: endpoint parsing, session lifecycle, and RPC boundaries.
- `src/combat/`: deterministic projectile and reflection calculations.
- `src/ai/`: perception and decision calculations; server-only at runtime.
- `src/actors/`: network-aware tank and projectile scene scripts.
- `src/world/`: authoritative arena orchestration and spawn rules.
- `src/match/`: pure match state, scoring, respawn, and round rules.
- `tests/`: custom dependency-free headless test runner and test cases.
- `docs/superpowers/plans/`: implementation plans.

## Network rules

- Use UDP port `7000` by default and allow an explicit `host:port` override.
- Validate addresses, ports, numeric input, RPC senders, and command ranges.
- Clients submit commands; only the server mutates authoritative world state.
- Do not synchronize UI nodes or depend on frame rate for simulation results.

## Code conventions

- Prefer small typed scripts and pure static functions for calculations.
- Use explicit return types and exported configuration where Godot supports them.
- Signals describe events; direct node references handle local ownership.
- No engine add-ons are required for the framework milestone.

## Verification

```powershell
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --editor --quit
```

All tests and the project import check must pass before handing off changes.
