class_name ThreatEvaluator
extends RefCounted


static func time_to_impact(
	relative_position: Vector2,
	relative_velocity: Vector2,
	danger_radius: float
) -> float:
	if danger_radius <= 0.0:
		return -1.0

	var radius_squared := danger_radius * danger_radius
	var distance_term := relative_position.length_squared() - radius_squared
	if distance_term <= 0.0:
		return 0.0

	var speed_squared := relative_velocity.length_squared()
	if is_zero_approx(speed_squared):
		return -1.0

	var linear_term := 2.0 * relative_position.dot(relative_velocity)
	var discriminant := linear_term * linear_term - 4.0 * speed_squared * distance_term
	if discriminant < 0.0:
		return -1.0

	var first_impact := (-linear_term - sqrt(discriminant)) / (2.0 * speed_squared)
	return first_impact if first_impact >= 0.0 else -1.0
