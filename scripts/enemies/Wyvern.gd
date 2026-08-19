extends Area2D

## Flying hazard with deterministic sinusoidal horizontal movement.

## Deadzone around cos == 0 where facing is ambiguous (near turnaround); the
## current facing is retained rather than flipped.
const FACING_EPSILON := 0.01

@onready var _sprite: AnimatedSprite2D = $Sprite

var _center_x := 0.0
var _half_range := 50.0
var _speed := 150.0
var _phase := 0.0
var _elapsed := 0.0
var _active := true
var _flip_h := false


func configure(center_x: float, half_range: float, speed: float, phase: float) -> void:
	_center_x = center_x
	_half_range = half_range
	_speed = speed
	_phase = phase
	position.x = _center_x + sin(_phase) * _half_range
	_update_facing(cos(_phase))


func _ready() -> void:
	_sprite.flip_h = _flip_h


func _physics_process(delta: float) -> void:
	if not _active:
		return

	_elapsed += delta
	var angular_speed := _speed / _half_range
	var angle := _phase + _elapsed * angular_speed
	position.x = _center_x + sin(angle) * _half_range
	_update_facing(cos(angle))


## Updates the desired facing from the sign of `cos_value` (the analytic
## derivative of the sinusoidal motion), ignoring the near-zero deadzone
## around turnarounds so facing does not flip when momentarily stationary.
func _update_facing(cos_value: float) -> void:
	if cos_value > FACING_EPSILON:
		_flip_h = false
	elif cos_value < -FACING_EPSILON:
		_flip_h = true
	else:
		return

	if _sprite:
		_sprite.flip_h = _flip_h


func set_active(is_active: bool) -> void:
	_active = is_active
	set_physics_process(_active)
	set_deferred("monitoring", _active)


func get_patrol_center_x() -> float:
	return _center_x


func get_patrol_half_range() -> float:
	return _half_range


func get_patrol_speed() -> float:
	return _speed


func get_initial_phase() -> float:
	return _phase
