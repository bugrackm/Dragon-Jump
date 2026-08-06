extends Node2D

## Deterministically builds a reachable chain of one-way platforms above the player.

@export var platform_scene: PackedScene

const SCREEN_WIDTH := 1080.0
const SCREEN_HEIGHT := 1920.0
const PLATFORM_HALF_WIDTH := 120.0
const MIN_PLATFORM_CENTER_X := PLATFORM_HALF_WIDTH
const MAX_PLATFORM_CENTER_X := SCREEN_WIDTH - PLATFORM_HALF_WIDTH
const TOP_SPAWN_BUFFER := 600.0
const BOTTOM_FREE_BUFFER := 300.0
const SAFE_PLATFORM_COUNT := 10

var _rng: RandomNumberGenerator
var _platforms: Array[StaticBody2D] = []
var _highest_platform_position := Vector2.ZERO
var _spawned_count := 0
var _jump_velocity := -1150.0
var _gravity := 2400.0
var _move_speed := 520.0
var _jump_height := 275.0
var _camera_y := SCREEN_HEIGHT * 0.5
var _initialized := false


func initialize(
		run_rng: RandomNumberGenerator,
		start_platform_position: Vector2,
		jump_velocity: float,
		gravity: float,
		move_speed: float
) -> void:
	_rng = run_rng
	_jump_velocity = jump_velocity
	_gravity = gravity
	_move_speed = move_speed
	_jump_height = (_jump_velocity * _jump_velocity) / (2.0 * _gravity)
	_highest_platform_position = start_platform_position
	_spawned_count = 0

	_spawn_platform(start_platform_position)
	_fill_above_camera()
	_initialized = true


func update_for_camera(camera_y: float) -> void:
	if not _initialized:
		return

	_camera_y = camera_y
	_fill_above_camera()
	_free_platforms_below_camera()


func _fill_above_camera() -> void:
	var spawn_ceiling := _camera_y - SCREEN_HEIGHT * 0.5 - TOP_SPAWN_BUFFER
	while _highest_platform_position.y > spawn_ceiling:
		_spawn_next_platform()


func _spawn_next_platform() -> void:
	var max_vertical_gap := _jump_height * 0.8
	var safe_region := _spawned_count < SAFE_PLATFORM_COUNT
	var gap_min_factor := 0.55 if safe_region else 0.62
	var gap_max_factor := 0.76 if safe_region else 1.0
	var vertical_gap := _rng.randf_range(
		max_vertical_gap * gap_min_factor,
		max_vertical_gap * gap_max_factor
	)

	# Use the descending root of the jump equation to calculate available air time.
	var discriminant := maxf(
		0.0,
		_jump_velocity * _jump_velocity - 2.0 * _gravity * vertical_gap
	)
	var landing_time := (absf(_jump_velocity) + sqrt(discriminant)) / _gravity
	var physical_horizontal_reach := _move_speed * landing_time
	var design_horizontal_limit := SCREEN_WIDTH * 0.7
	var safety_factor := 0.55 if safe_region else 0.75
	var reachable_horizontal_gap := minf(
		design_horizontal_limit,
		physical_horizontal_reach * safety_factor
	)

	var horizontal_offset := _rng.randf_range(
		-reachable_horizontal_gap,
		reachable_horizontal_gap
	)
	var next_x := clampf(
		_highest_platform_position.x + horizontal_offset,
		MIN_PLATFORM_CENTER_X,
		MAX_PLATFORM_CENTER_X
	)
	var next_position := Vector2(next_x, _highest_platform_position.y - vertical_gap)

	_spawn_platform(next_position)
	_highest_platform_position = next_position


func _spawn_platform(spawn_position: Vector2) -> void:
	var platform := platform_scene.instantiate() as StaticBody2D
	platform.position = spawn_position
	add_child(platform)
	_platforms.append(platform)
	_spawned_count += 1


func _free_platforms_below_camera() -> void:
	var free_line := _camera_y + SCREEN_HEIGHT * 0.5 + BOTTOM_FREE_BUFFER
	for platform in _platforms.duplicate():
		if is_instance_valid(platform) and platform.position.y > free_line:
			_platforms.erase(platform)
			platform.queue_free()

