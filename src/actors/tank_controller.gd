class_name TankController
extends CharacterBody2D

const Simulation = preload("res://src/combat/tank_simulation.gd")

signal shot_requested(origin: Vector2, direction: Vector2, owner_id: int, sequence: int)
signal health_changed(current: int, maximum: int)
signal destroyed_signal(tank_id: int)

@export var tank_id := 1
@export var move_speed := 180.0
@export var fire_cooldown := 0.35
@export var arena_bounds := Rect2(48.0, 48.0, 1184.0, 624.0)
@export var max_health := 100
@export var autonomous_input := false

var health := 100
var destroyed := false
var _aim := Vector2.RIGHT
var _cooldown_left := 0.0
var _sequence := 0


func _ready() -> void:
	health = max_health
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not autonomous_input:
		return
	if multiplayer.multiplayer_peer != null and not is_multiplayer_authority():
		return
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var aim := get_global_mouse_position() - global_position
	var wants_fire := Input.is_action_pressed("fire")
	apply_command({
		"movement": movement,
		"aim": aim,
		"fire": wants_fire,
		"sequence": _sequence + 1,
	}, delta)


func apply_command(payload: Dictionary, delta: float) -> void:
	if destroyed:
		return
	var result := Simulation.integrate(global_position, payload, move_speed, delta, arena_bounds)
	global_position = result.position
	velocity = result.velocity
	_aim = result.aim
	_cooldown_left = maxf(0.0, _cooldown_left - maxf(0.0, delta))
	if bool(payload.get("fire", false)) and _cooldown_left <= 0.0:
		_sequence = maxi(_sequence + 1, int(result.sequence))
		_cooldown_left = fire_cooldown
		shot_requested.emit(global_position + _aim * 28.0, _aim, tank_id, _sequence)
	queue_redraw()


func apply_damage(amount: int) -> int:
	if destroyed:
		return health
	health = clampi(health - maxi(0, amount), 0, max_health)
	health_changed.emit(health, max_health)
	if health == 0:
		destroyed = true
		destroyed_signal.emit(tank_id)
		queue_redraw()
	return health


func respawn(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	health = max_health
	destroyed = false
	_cooldown_left = 0.0
	health_changed.emit(health, max_health)
	queue_redraw()


func get_aim() -> Vector2:
	return _aim


func set_aim(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		_aim = direction.normalized()
		queue_redraw()


func _draw() -> void:
	var body_color := Color("#57606a") if destroyed else Color("#2ec27e")
	draw_rect(Rect2(-18.0, -14.0, 36.0, 28.0), body_color, true)
	draw_rect(Rect2(-14.0, -10.0, 28.0, 20.0), Color("#1b6e52"), true)
	draw_circle(Vector2.ZERO, 9.0, Color("#78f0b8"))
	draw_line(Vector2.ZERO, _aim * 30.0, Color("#f5f7e8"), 5.0, true)
