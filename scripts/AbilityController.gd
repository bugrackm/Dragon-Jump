extends Node

## Owns fire cooldown, projectile spawning, and cleanup.

signal cooldown_changed(is_on_cooldown: bool)

const FIRE_COOLDOWN_SECONDS := 0.5
const FIRE_PROJECTILE_SCENE := preload("res://scenes/FireProjectile.tscn")
const PROJECTILE_SPAWN_OFFSET := Vector2(0.0, -58.0)

@onready var _player := get_parent() as CharacterBody2D
@onready var _input_controller := get_node("../InputController")

var _world: Node2D
var _enemy_manager: Node
var _camera: Camera2D
var _cooldown_left := 0.0
var _active := false
var _projectiles: Array[Area2D] = []


func initialize(
		world: Node2D,
		enemy_manager: Node,
		camera: Camera2D
	) -> void:
	_world = world
	_enemy_manager = enemy_manager
	_camera = camera


func _process(delta: float) -> void:
	_prune_projectiles()
	if not _active:
		return

	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
		if is_zero_approx(_cooldown_left):
			cooldown_changed.emit(false)

	if _input_controller.call("consume_fire_request"):
		request_fire()


func request_fire() -> void:
	if (
		not _active
		or _cooldown_left > 0.0
		or _world == null
	):
		return

	_cooldown_left = FIRE_COOLDOWN_SECONDS
	cooldown_changed.emit(true)
	_spawn_projectile()


func set_active(is_active: bool) -> void:
	_active = is_active
	if _active:
		return

	_cooldown_left = 0.0
	cooldown_changed.emit(false)
	for projectile in _projectiles:
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			projectile.call("set_active", false)
			projectile.queue_free()
	_projectiles.clear()


func is_on_cooldown() -> bool:
	return _cooldown_left > 0.0


func _spawn_projectile() -> void:
	var projectile := FIRE_PROJECTILE_SCENE.instantiate() as Area2D
	_world.add_child(projectile)
	projectile.global_position = _player.global_position + PROJECTILE_SPAWN_OFFSET
	projectile.call("initialize", _enemy_manager, _camera)
	_projectiles.append(projectile)


func _prune_projectiles() -> void:
	var survivors: Array[Area2D] = []
	for projectile in _projectiles:
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			survivors.append(projectile)
	_projectiles = survivors
