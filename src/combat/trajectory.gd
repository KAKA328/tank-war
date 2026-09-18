class_name Trajectory
extends RefCounted


static func reflect_velocity(velocity: Vector2, surface_normal: Vector2) -> Vector2:
	if surface_normal.is_zero_approx():
		return velocity
	return velocity.bounce(surface_normal.normalized())

