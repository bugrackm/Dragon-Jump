extends Node2D

## Owns an RNG-isolated stream of platform coins and enemy coin drops.

signal coin_collected

const SCREEN_WIDTH := 1080.0
const BOTTOM_FREE_BUFFER := 300.0
const SAFE_PLATFORM_COUNT := 10
const PLATFORM_COIN_CHANCE := 0.40
const PLATFORM_COIN_OFFSET_Y := -48.0
const DROP_MIN_COUNT := 1
const DROP_MAX_COUNT := 3
const DROP_SCATTER_X := 60.0
const DROP_SCATTER_Y := 30.0
const SCREEN_EDGE_MARGIN := 20.0

const PLATFORM_TYPE_STATIC := &"static"
const PLATFORM_TYPE_MOVING := &"moving"
const PLATFORM_TYPE_SPRING := &"spring"

@export var coin_scene: PackedScene

var _coin_rng := RandomNumberGenerator.new()
var _player: CharacterBody2D
var _camera: Camera2D
var _platform_manager: Node2D
var _coins: Array[Area2D] = []
var _active := false
var _difficulty_factor := 0.0
var _coin_chance := PLATFORM_COIN_CHANCE


func initialize(
		player: CharacterBody2D,
		camera: Camera2D,
		run_rng_seed: int,
		platform_manager: Node2D
) -> void:
	_player = player
	_camera = camera
	_platform_manager = platform_manager
	_coin_rng.seed = run_rng_seed * 7 + 3
	_coins.clear()
	_active = true
	_difficulty_factor = 0.0
	_coin_chance = PLATFORM_COIN_CHANCE

	var callback := Callable(self, "_on_platform_spawned")
	if not _platform_manager.is_connected("platform_spawned", callback):
		# EnemyManager connects after CoinManager but handles the signal immediately.
		# Deferring this callback lets it reserve static-monster platforms first.
		_platform_manager.connect(
			"platform_spawned",
			callback,
			Object.CONNECT_DEFERRED
		)


func update_difficulty(factor: float) -> void:
	_difficulty_factor = clampf(factor, 0.0, 1.0)
	_coin_chance = lerpf(PLATFORM_COIN_CHANCE, 0.65, _difficulty_factor)


func update_for_camera(camera_y: float) -> void:
	if not _active:
		return

	var free_line := ScreenLayout.visible_bottom(camera_y) + BOTTOM_FREE_BUFFER
	var world := get_parent()
	var survivors: Array[Area2D] = []
	for coin in _coins:
		if not is_instance_valid(coin) or coin.is_queued_for_deletion():
			continue
		if coin.get_parent() == world and coin.global_position.y > free_line:
			coin.queue_free()
			continue
		survivors.append(coin)
	_coins = survivors


func set_active(is_active: bool) -> void:
	_active = is_active
	for coin in _coins:
		if is_instance_valid(coin) and not coin.is_queued_for_deletion():
			coin.call("set_active", _active)


func _on_platform_spawned(
		platform: Node2D,
		spawn_index: int,
		platform_type: StringName,
		_center: Vector2,
		_travel_half_width: float
) -> void:
	if not _active or not is_instance_valid(platform):
		return
	if spawn_index <= SAFE_PLATFORM_COUNT:
		return
	if platform_type not in [
		PLATFORM_TYPE_STATIC,
		PLATFORM_TYPE_MOVING,
		PLATFORM_TYPE_SPRING,
	]:
		return
	if bool(platform.get_meta("has_static_monster", false)):
		return
	if _coin_rng.randf() >= _coin_chance:
		return

	var coin := _create_coin()
	coin.position = Vector2(0.0, PLATFORM_COIN_OFFSET_Y)
	platform.add_child(coin)


func _on_enemy_destroyed(enemy_position: Vector2) -> void:
	if not _active:
		return

	# Defer the actual spawn: enemy_destroyed fires from area_entered during
	# physics flush, and adding a new Area2D in that window triggers
	# "Can't change this state while flushing queries".
	call_deferred("_spawn_enemy_drops", enemy_position)


func _spawn_enemy_drops(enemy_position: Vector2) -> void:
	if not _active:
		return

	var world := get_parent()
	var drop_count := _coin_rng.randi_range(DROP_MIN_COUNT, DROP_MAX_COUNT)
	for _drop_index in drop_count:
		var coin := _create_coin()
		world.add_child(coin)
		coin.global_position = Vector2(
			clampf(
				enemy_position.x + _coin_rng.randf_range(-DROP_SCATTER_X, DROP_SCATTER_X),
				SCREEN_EDGE_MARGIN,
				SCREEN_WIDTH - SCREEN_EDGE_MARGIN
			),
			enemy_position.y + _coin_rng.randf_range(-DROP_SCATTER_Y, DROP_SCATTER_Y)
		)


func _create_coin() -> Area2D:
	var coin := coin_scene.instantiate() as Area2D
	coin.call("initialize", _player)
	coin.connect("coin_collected", _on_coin_collected.bind(coin))
	_coins.append(coin)
	return coin


func _on_coin_collected(coin: Area2D) -> void:
	_coins.erase(coin)
	coin_collected.emit()
