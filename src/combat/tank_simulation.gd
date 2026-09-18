class_name TankSimulation
extends RefCounted

const Command = preload("res://src/combat/tank_command.gd")


static func integrate(
	position: Vector2,
	payload: Dictionary,
	speed: float,
	delta: float,
	arena_bounds: Rect2
) -> Dictionary:
	var command := Command.sanitize(payload)
	var velocity: Vector2 = command.movement * maxf(0.0, speed)
	var next_position := position + velocity * maxf(0.0, delta)
	next_position = next_position.clamp(arena_bounds.position, arena_bounds.end)
	return {
		"position": next_position,
		"velocity": velocity,
		"aim": command.aim,
		"sequence": command.sequence,
	}

