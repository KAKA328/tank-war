class_name TankCommand
extends RefCounted

const MAX_SEQUENCE := 2147483647


static func sanitize(payload: Dictionary) -> Dictionary:
	var raw_movement: Variant = payload.get("movement", Vector2.ZERO)
	var raw_aim: Variant = payload.get("aim", Vector2.RIGHT)
	var movement: Vector2 = raw_movement if raw_movement is Vector2 else Vector2.ZERO
	var aim: Vector2 = raw_aim if raw_aim is Vector2 else Vector2.RIGHT
	if movement.length_squared() > 1.0:
		movement = movement.normalized()
	if aim.is_zero_approx():
		aim = Vector2.RIGHT
	else:
		aim = aim.normalized()

	return {
		"movement": movement,
		"aim": aim,
		"fire": bool(payload.get("fire", false)),
		"sequence": clampi(int(payload.get("sequence", 0)), 0, MAX_SEQUENCE),
	}

