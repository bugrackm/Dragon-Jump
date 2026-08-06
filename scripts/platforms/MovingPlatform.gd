extends AnimatableBody2D

## A deterministic horizontal platform whose motion is synchronized to physics.

@export_range(80.0, 200.0, 1.0) var travel_range := 140.0
@export_range(60.0, 120.0, 1.0) var travel_speed := 90.0

var _center_position := Vector2.ZERO
var _elapsed := 0.0


func _ready() -> void:
	_center_position = position


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var half_range := travel_range * 0.5
	var angular_speed := travel_speed / half_range
	position.x = _center_position.x + sin(_elapsed * angular_speed) * half_range


func configure_movement(new_travel_range: float, new_travel_speed: float) -> void:
	travel_range = clampf(new_travel_range, 80.0, 200.0)
	travel_speed = clampf(new_travel_speed, 60.0, 120.0)


func get_travel_half_width() -> float:
	return travel_range * 0.5
