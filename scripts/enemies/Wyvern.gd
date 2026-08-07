extends Area2D

## Flying hazard with deterministic sinusoidal horizontal movement.

var _center_x := 0.0
var _half_range := 50.0
var _speed := 150.0
var _phase := 0.0
var _elapsed := 0.0
var _active := true


func configure(center_x: float, half_range: float, speed: float, phase: float) -> void:
	_center_x = center_x
	_half_range = half_range
	_speed = speed
	_phase = phase
	position.x = _center_x + sin(_phase) * _half_range


func _physics_process(delta: float) -> void:
	if not _active:
		return

	_elapsed += delta
	var angular_speed := _speed / _half_range
	position.x = _center_x + sin(_phase + _elapsed * angular_speed) * _half_range


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
