extends Node2D

## Deterministically coordinates platform-owned monsters and flying wyverns.

signal enemy_destroyed(enemy_position: Vector2)

const SCREEN_WIDTH := 1080.0
const BOTTOM_FREE_BUFFER := 300.0
const FIRST_ENEMY_PLATFORM_INDEX := 16
const MAX_CONCURRENT_ENEMIES := 5
const MIN_PLATFORMS_BETWEEN_OPPORTUNITIES := 3
const MAX_PLATFORMS_BETWEEN_OPPORTUNITIES := 5
const WYVERN_WEIGHT := 0.60
const WYVERN_HALF_RANGE_MIN := 180.0
const WYVERN_HALF_RANGE_MAX := 400.0
const WYVERN_SPEED_MIN := 180.0
const WYVERN_SPEED_MAX := 320.0
const WYVERN_SPAWN_ATTEMPTS := 5
const WYVERN_VERTICAL_EXCLUSION := 150.0
const WYVERN_HORIZONTAL_EXCLUSION := 200.0
const STATIC_MONSTER_OFFSET_Y := -48.0

const PLATFORM_TYPE_STATIC := &"static"
const PLATFORM_TYPE_SPRING := &"spring"


class PlatformRecord:
	var platform: Node2D
	var center: Vector2
	var travel_half_width: float

	func _init(
			new_platform: Node2D,
			new_center: Vector2,
			new_travel_half_width: float
	) -> void:
		platform = new_platform
		center = new_center
		travel_half_width = new_travel_half_width


@export var wyvern_scene: PackedScene
@export var static_monster_scene: PackedScene

var _enemy_rng := RandomNumberGenerator.new()
var _run_session: Node
var _platform_manager: Node2D
var _player: CharacterBody2D
var _platform_records: Array[PlatformRecord] = []
var _enemies: Array[Area2D] = []
var _platforms_until_opportunity := 0
var _active := false
var _difficulty_factor := 0.0
var _max_concurrent_enemies := MAX_CONCURRENT_ENEMIES
var _min_platforms_between := MIN_PLATFORMS_BETWEEN_OPPORTUNITIES
var _max_platforms_between := MAX_PLATFORMS_BETWEEN_OPPORTUNITIES
var _wyvern_speed_min := WYVERN_SPEED_MIN
var _wyvern_speed_max := WYVERN_SPEED_MAX


func initialize(
		run_session: Node,
		platform_manager: Node2D,
		player: CharacterBody2D
) -> void:
	_run_session = run_session
	_platform_manager = platform_manager
	_player = player
	_enemy_rng.seed = int(_run_session.get("rng_seed"))
	_platform_records.clear()
	_enemies.clear()
	_platforms_until_opportunity = 0
	_active = true
	_difficulty_factor = 0.0
	_max_concurrent_enemies = MAX_CONCURRENT_ENEMIES
	_min_platforms_between = MIN_PLATFORMS_BETWEEN_OPPORTUNITIES
	_max_platforms_between = MAX_PLATFORMS_BETWEEN_OPPORTUNITIES
	_wyvern_speed_min = WYVERN_SPEED_MIN
	_wyvern_speed_max = WYVERN_SPEED_MAX

	var callback := Callable(self, "_on_platform_spawned")
	if not _platform_manager.is_connected("platform_spawned", callback):
		_platform_manager.connect("platform_spawned", callback)


func update_difficulty(factor: float) -> void:
	_difficulty_factor = clampf(factor, 0.0, 1.0)
	_max_concurrent_enemies = int(round(lerpf(
		float(MAX_CONCURRENT_ENEMIES),
		7.0,
		_difficulty_factor
	)))
	_min_platforms_between = int(round(lerpf(
		float(MIN_PLATFORMS_BETWEEN_OPPORTUNITIES),
		2.0,
		_difficulty_factor
	)))
	_max_platforms_between = int(round(lerpf(
		float(MAX_PLATFORMS_BETWEEN_OPPORTUNITIES),
		3.0,
		_difficulty_factor
	)))
	_max_platforms_between = maxi(_max_platforms_between, _min_platforms_between)
	_wyvern_speed_min = int(round(lerpf(
		WYVERN_SPEED_MIN,
		220.0,
		_difficulty_factor
	)))
	_wyvern_speed_max = int(round(lerpf(
		WYVERN_SPEED_MAX,
		400.0,
		_difficulty_factor
	)))
	_wyvern_speed_max = maxf(_wyvern_speed_max, _wyvern_speed_min)


func update_for_camera(camera_y: float) -> void:
	if not _active:
		return

	_prune_platform_records()
	_prune_enemies()
	var free_line := ScreenLayout.visible_bottom(camera_y) + BOTTOM_FREE_BUFFER
	for enemy in _enemies:
		if enemy.get_parent() == self and enemy.global_position.y > free_line:
			enemy.queue_free()
	_prune_enemies()


func set_active(is_active: bool) -> void:
	_active = is_active
	for enemy in _enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.call("set_active", _active)


func get_active_enemy_count() -> int:
	_prune_enemies()
	return _enemies.size()


func destroy_enemy(enemy: Area2D) -> void:
	if (
		not is_instance_valid(enemy)
		or enemy.is_queued_for_deletion()
		or not _enemies.has(enemy)
	):
		return

	_enemies.erase(enemy)
	enemy_destroyed.emit(enemy.global_position)
	enemy.queue_free()


func _on_platform_spawned(
		platform: Node2D,
		spawn_index: int,
		platform_type: StringName,
		center: Vector2,
		travel_half_width: float
) -> void:
	var previous_record: PlatformRecord
	if not _platform_records.is_empty():
		previous_record = _platform_records.back()

	var current_record := PlatformRecord.new(platform, center, travel_half_width)
	_platform_records.append(current_record)

	if not _active or spawn_index < FIRST_ENEMY_PLATFORM_INDEX:
		return

	if _platforms_until_opportunity > 0:
		_platforms_until_opportunity -= 1
		return

	_prune_enemies()
	var spawn_wyvern := _enemy_rng.randf() < WYVERN_WEIGHT
	if _enemies.size() < _max_concurrent_enemies:
		if spawn_wyvern and previous_record != null:
			_try_spawn_wyvern(previous_record, current_record)
		elif not spawn_wyvern:
			_try_spawn_static_monster(platform, platform_type)

	_platforms_until_opportunity = _enemy_rng.randi_range(
		_min_platforms_between,
		_max_platforms_between
	)


func _try_spawn_wyvern(lower_platform: PlatformRecord, upper_platform: PlatformRecord) -> void:
	var gap_top := minf(lower_platform.center.y, upper_platform.center.y)
	var gap_bottom := maxf(lower_platform.center.y, upper_platform.center.y)
	for _attempt in WYVERN_SPAWN_ATTEMPTS:
		var half_range := _enemy_rng.randf_range(
			WYVERN_HALF_RANGE_MIN,
			WYVERN_HALF_RANGE_MAX
		)
		var center_x := _enemy_rng.randf_range(half_range, SCREEN_WIDTH - half_range)
		var spawn_y := _enemy_rng.randf_range(gap_top, gap_bottom)
		var speed := _enemy_rng.randf_range(_wyvern_speed_min, _wyvern_speed_max)
		var phase := _enemy_rng.randf_range(0.0, TAU)
		if _is_wyvern_position_blocked(center_x, spawn_y, half_range):
			continue

		var wyvern := wyvern_scene.instantiate() as Area2D
		wyvern.position = Vector2(center_x, spawn_y)
		wyvern.call("configure", center_x, half_range, speed, phase)
		wyvern.set_meta("enemy_type", &"wyvern")
		wyvern.body_entered.connect(_on_enemy_body_entered)
		add_child(wyvern)
		_enemies.append(wyvern)
		return


func _try_spawn_static_monster(platform: Node2D, platform_type: StringName) -> void:
	if platform_type not in [PLATFORM_TYPE_STATIC, PLATFORM_TYPE_SPRING]:
		return

	var monster := static_monster_scene.instantiate() as Area2D
	monster.position = Vector2(0.0, STATIC_MONSTER_OFFSET_Y)
	monster.set_meta("enemy_type", &"static_monster")
	monster.body_entered.connect(_on_enemy_body_entered)
	platform.set_meta("has_static_monster", true)
	platform.add_child(monster)
	_enemies.append(monster)


func _is_wyvern_position_blocked(center_x: float, spawn_y: float, half_range: float) -> bool:
	var patrol_left := center_x - half_range
	var patrol_right := center_x + half_range
	for record in _platform_records:
		if not _is_platform_record_valid(record):
			continue
		var vertical_distance := absf(spawn_y - record.center.y)
		if vertical_distance > WYVERN_VERTICAL_EXCLUSION:
			continue

		var horizontal_blocked := _is_patrol_endpoint_near_platform(
			patrol_left,
			record
		) or _is_patrol_endpoint_near_platform(patrol_right, record)
		if vertical_distance <= WYVERN_VERTICAL_EXCLUSION and horizontal_blocked:
			return true
	return false


func _is_patrol_endpoint_near_platform(endpoint_x: float, record: PlatformRecord) -> bool:
	var center_distance := _wrap_aware_horizontal_distance(endpoint_x, record.center.x)
	if center_distance <= WYVERN_HORIZONTAL_EXCLUSION:
		return true
	if record.travel_half_width <= 0.0:
		return false

	var left_distance := _wrap_aware_horizontal_distance(
		endpoint_x,
		record.center.x - record.travel_half_width
	)
	var right_distance := _wrap_aware_horizontal_distance(
		endpoint_x,
		record.center.x + record.travel_half_width
	)
	return minf(left_distance, right_distance) <= WYVERN_HORIZONTAL_EXCLUSION


func _wrap_aware_horizontal_distance(first_x: float, second_x: float) -> float:
	var direct_distance := absf(first_x - second_x)
	return minf(direct_distance, SCREEN_WIDTH - direct_distance)


func _on_enemy_body_entered(body: Node2D) -> void:
	if not _active or body != _player:
		return
	_run_session.call("end_run")


func _prune_platform_records() -> void:
	var survivors: Array[PlatformRecord] = []
	for record in _platform_records:
		if _is_platform_record_valid(record):
			survivors.append(record)
	_platform_records = survivors


func _prune_enemies() -> void:
	var survivors: Array[Area2D] = []
	for enemy in _enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var parent := enemy.get_parent()
		if parent == null or parent.is_queued_for_deletion():
			continue
		survivors.append(enemy)
	_enemies = survivors


func _is_platform_record_valid(record: PlatformRecord) -> bool:
	return (
		record != null
		and is_instance_valid(record.platform)
		and not record.platform.is_queued_for_deletion()
	)
