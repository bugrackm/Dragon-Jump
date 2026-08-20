extends Area2D

## Upward fire projectile that destroys the first enemy Area2D it overlaps.

const SPEED := 800.0
const TTL_SECONDS := 3.0
const CAMERA_TOP_MARGIN := 200.0
const FIRE_BURST_SCENE := preload("res://scenes/effects/FireBurst.tscn")

var _enemy_manager: Node
var _camera: Camera2D
var _elapsed := 0.0
var _active := true
var _destroyed := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func initialize(enemy_manager: Node, camera: Camera2D) -> void:
	_enemy_manager = enemy_manager
	_camera = camera
	_spawn_fire_burst()


func _spawn_fire_burst() -> void:
	var effect_parent := get_parent()
	if effect_parent == null:
		return
	var burst := FIRE_BURST_SCENE.instantiate() as CPUParticles2D
	effect_parent.add_child(burst)
	burst.global_position = global_position
	burst.finished.connect(burst.queue_free)
	burst.emitting = true


func _physics_process(delta: float) -> void:
	if not _active:
		return

	global_position.y -= SPEED * delta
	_elapsed += delta
	if _elapsed >= TTL_SECONDS or _is_above_camera_limit():
		_destroyed = true
		queue_free()


func set_active(is_active: bool) -> void:
	_active = is_active
	set_physics_process(_active)
	set_deferred("monitoring", _active)


func _on_area_entered(other_area: Area2D) -> void:
	if (
		_destroyed
		or not _active
		or not other_area.has_meta("enemy_type")
		or _enemy_manager == null
	):
		return

	_destroyed = true
	_enemy_manager.call("destroy_enemy", other_area)
	queue_free()


func _is_above_camera_limit() -> bool:
	if _camera == null or not is_instance_valid(_camera):
		return false
	var camera_top := _camera.global_position.y - get_viewport_rect().size.y * 0.5
	return global_position.y < camera_top - CAMERA_TOP_MARGIN
