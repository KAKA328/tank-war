class_name ProjectileController
extends Area2D

const TankControllerType = preload("res://src/actors/tank_controller.gd")

signal hit_target(target: Node2D, attacker_id: int)

@export var speed := 420.0
@export var lifetime := 3.0

var direction := Vector2.RIGHT
var owner_id := 0
var sequence := 0
var _age := 0.0


func setup(spawn_position: Vector2, travel_direction: Vector2, source_id: int, shot_sequence: int) -> void:
	global_position = spawn_position
	direction = travel_direction.normalized() if not travel_direction.is_zero_approx() else Vector2.RIGHT
	owner_id = source_id
	sequence = shot_sequence
	queue_redraw()


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * maxf(0.0, delta)
	_age += maxf(0.0, delta)
	if _age >= lifetime or not Rect2(-32.0, -32.0, 1344.0, 784.0).has_point(global_position):
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color("#ffcf56"))
	draw_line(-direction * 8.0, Vector2.ZERO, Color("#fff3b0"), 3.0, true)


func _on_body_entered(body: Node2D) -> void:
	var tank := body as TankControllerType
	if tank == null or tank.tank_id == owner_id or tank.destroyed:
		return
	hit_target.emit(tank, owner_id)
	queue_free()
