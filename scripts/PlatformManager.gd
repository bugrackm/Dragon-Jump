extends Node2D

## Deterministically builds a reachable chain of one-way platforms above the player.

signal platform_spawned(platform: Node2D, spawn_index: int, platform_type: StringName, center: Vector2, travel_half_width: float)

@export var platform_scene: PackedScene
@export var moving_platform_scene: PackedScene
@export var breakable_platform_scene: PackedScene
@export var disappearing_platform_scene: PackedScene
@export var spring_platform_scene: PackedScene

const SCREEN_WIDTH := 1080.0
const SCREEN_HEIGHT := 1920.0
const PLATFORM_HALF_WIDTH := 120.0
const MIN_PLATFORM_CENTER_X := PLATFORM_HALF_WIDTH
const MAX_PLATFORM_CENTER_X := SCREEN_WIDTH - PLATFORM_HALF_WIDTH
const TOP_SPAWN_BUFFER := 600.0
const BOTTOM_FREE_BUFFER := 300.0
const SAFE_PLATFORM_COUNT := 10
const MOVING_RANGE_MIN := 80.0
const MOVING_RANGE_MAX := 200.0
const MOVING_SPEED_MIN := 60.0
const MOVING_SPEED_MAX := 120.0

const PLATFORM_TYPE_STATIC := &"static"
const PLATFORM_TYPE_MOVING := &"moving"
const PLATFORM_TYPE_BREAKABLE := &"breakable"
const PLATFORM_TYPE_DISAPPEARING := &"disappearing"
const PLATFORM_TYPE_SPRING := &"spring"

var _rng: RandomNumberGenerator
var _platforms: Array[Node2D] = []
var _highest_platform_position := Vector2.ZERO
var _highest_platform_travel_half_width := 0.0
var _last_platform_type := PLATFORM_TYPE_STATIC
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
	_highest_platform_travel_half_width = 0.0
	_last_platform_type = PLATFORM_TYPE_STATIC
	_spawned_count = 0

	_spawn_platform(start_platform_position, PLATFORM_TYPE_STATIC)
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
	# Non-static platforms (breakable, disappearing) are hazards the player
	# can fall through. Reduce the vertical gap after them so the next static
	# platform is always comfortably within reach even if the player drops.
	var gap_max_factor := 0.76 if safe_region else 1.0
	if _last_platform_type in [PLATFORM_TYPE_BREAKABLE, PLATFORM_TYPE_DISAPPEARING]:
		gap_max_factor = 0.65
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

	var platform_type := _select_platform_type()
	var moving_range := 0.0
	var moving_speed := 0.0
	var next_travel_half_width := 0.0
	if platform_type == PLATFORM_TYPE_MOVING:
		moving_range = _rng.randf_range(MOVING_RANGE_MIN, MOVING_RANGE_MAX)
		moving_speed = _rng.randf_range(MOVING_SPEED_MIN, MOVING_SPEED_MAX)
		next_travel_half_width = moving_range * 0.5

	# Both travel envelopes count against the landing budget. This makes even the
	# farthest opposing points of two adjacent platforms reachable.
	var center_offset_limit := maxf(
		0.0,
		reachable_horizontal_gap
			- _highest_platform_travel_half_width
			- next_travel_half_width
	)
	var screen_min_x := MIN_PLATFORM_CENTER_X + next_travel_half_width
	var screen_max_x := MAX_PLATFORM_CENTER_X - next_travel_half_width
	var reachable_min_x := maxf(
		screen_min_x,
		_highest_platform_position.x - center_offset_limit
	)
	var reachable_max_x := minf(
		screen_max_x,
		_highest_platform_position.x + center_offset_limit
	)
	var next_x := _rng.randf_range(reachable_min_x, reachable_max_x)
	var next_position := Vector2(next_x, _highest_platform_position.y - vertical_gap)

	_spawn_platform(next_position, platform_type, moving_range, moving_speed)
	_highest_platform_position = next_position
	_highest_platform_travel_half_width = next_travel_half_width
	_last_platform_type = platform_type


func _select_platform_type() -> StringName:
	if _spawned_count < SAFE_PLATFORM_COUNT:
		return PLATFORM_TYPE_STATIC
	if _last_platform_type != PLATFORM_TYPE_STATIC:
		return PLATFORM_TYPE_STATIC

	var roll := _rng.randf()
	if roll < 0.50:
		return PLATFORM_TYPE_STATIC
	if roll < 0.65:
		return PLATFORM_TYPE_MOVING
	if roll < 0.77:
		return PLATFORM_TYPE_BREAKABLE
	if roll < 0.87:
		return PLATFORM_TYPE_DISAPPEARING
	return PLATFORM_TYPE_SPRING


func _spawn_platform(
		spawn_position: Vector2,
		platform_type: StringName,
		moving_range := 0.0,
		moving_speed := 0.0
) -> void:
	var selected_scene := _get_platform_scene(platform_type)
	var platform := selected_scene.instantiate() as Node2D
	platform.position = spawn_position
	platform.set_meta("platform_type", platform_type)
	if platform_type == PLATFORM_TYPE_MOVING:
		platform.call("configure_movement", moving_range, moving_speed)
	add_child(platform)
	_platforms.append(platform)
	_spawned_count += 1
	emit_signal("platform_spawned", platform, _spawned_count, platform_type, spawn_position, moving_range * 0.5)


func _get_platform_scene(platform_type: StringName) -> PackedScene:
	match platform_type:
		PLATFORM_TYPE_MOVING:
			return moving_platform_scene
		PLATFORM_TYPE_BREAKABLE:
			return breakable_platform_scene
		PLATFORM_TYPE_DISAPPEARING:
			return disappearing_platform_scene
		PLATFORM_TYPE_SPRING:
			return spring_platform_scene
		_:
			return platform_scene


func _free_platforms_below_camera() -> void:
	var free_line := _camera_y + SCREEN_HEIGHT * 0.5 + BOTTOM_FREE_BUFFER
	var survivors: Array[Node2D] = []
	for platform in _platforms:
		if not is_instance_valid(platform):
			continue
		if platform.position.y > free_line:
			platform.queue_free()
		else:
			survivors.append(platform)
	_platforms = survivors
