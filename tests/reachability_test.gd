extends SceneTree

## Seeded solid-chain, optional-hazard, and all-pairs spacing audit.
const PLAYER_SCRIPT := preload("res://scripts/Player.gd")
const ANCHOR := Vector2(540.0, 1740.0)
const SEED_COUNT := 1000
const MAX_ALTITUDE := 8000.0
const CAMERA_STEP := 80.0
const VISIBLE_HEIGHTS := [1920, 2340, 2400, 2520]
const EPSILON := 0.001

var _screen_layout: Node
var _records: Array[Dictionary] = []
var _checked := 0
var _chain_violations := 0
var _stacking_violations := 0
var _hazard_violations := 0
var _hazards := 0
var _hazard_steps := 0
var _min_gap := INF
var _max_gap := 0.0
var _printed_example := false
var _integration_checks := 0
var _integration_failures := 0


class AuditedManager:
	extends "res://scripts/PlatformManager.gd"
	var hazard_steps := 0

	func _select_platform_type() -> StringName:
		var selected := super._select_platform_type()
		if selected in [&"breakable", &"disappearing"]:
			hazard_steps += 1
		return selected


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_screen_layout = root.get_node("ScreenLayout")
	root.content_scale_size = Vector2i(1080, 1920)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
	var failures := 0
	for height in VISIBLE_HEIGHTS:
		root.size = Vector2i(1080, height)
		await process_frame
		_screen_layout.refresh()
		_checked = 0
		_chain_violations = 0
		_stacking_violations = 0
		_hazard_violations = 0
		_hazards = 0
		_hazard_steps = 0
		_min_gap = INF
		_max_gap = 0.0
		_printed_example = false
		_integration_checks = 0
		_integration_failures = 0
		_expect(is_equal_approx(_screen_layout.visible_size.y, height), "real visible height")
		print("visible_height=%d" % height)
		await _check_height()
		_expect(_checked >= SEED_COUNT * 10 and _integration_checks >= 30, "full audit completed")
		failures += _chain_violations + _stacking_violations + _hazard_violations + _integration_failures
	print("heights=%d seeds_total=%d violations=%d" % [VISIBLE_HEIGHTS.size(), SEED_COUNT * VISIBLE_HEIGHTS.size(), failures])
	await create_timer(0.3, true, false, true).timeout
	quit(0 if failures == 0 else 1)


func _check_height() -> void:
	var initial_camera_y: float = _screen_layout.BASE_HEIGHT - _screen_layout.half_height()
	for seed_value in range(1, SEED_COUNT + 1):
		_records.clear()
		var manager := AuditedManager.new()
		manager.platform_scene = preload("res://scenes/Platform.tscn")
		manager.moving_platform_scene = preload("res://scenes/platforms/MovingPlatform.tscn")
		manager.breakable_platform_scene = preload("res://scenes/platforms/BreakablePlatform.tscn")
		manager.disappearing_platform_scene = preload("res://scenes/platforms/DisappearingPlatform.tscn")
		manager.spring_platform_scene = preload("res://scenes/platforms/SpringPlatform.tscn")
		manager.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(manager)
		manager.platform_spawned.connect(_record_platform)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		manager.initialize(rng, ANCHOR, PLAYER_SCRIPT.JUMP_VELOCITY,
			PLAYER_SCRIPT.GRAVITY, PLAYER_SCRIPT.MOVE_SPEED)
		var altitude := 0.0
		while altitude < MAX_ALTITUDE:
			altitude += CAMERA_STEP
			manager.update_difficulty(clampf(altitude / 5000.0, 0.0, 1.0))
			manager.update_for_camera(initial_camera_y - altitude)
		_check_chain(seed_value)
		_hazard_steps += manager.hazard_steps
		manager.free()
		# Flush the manager's queued platform deletions between seeds.
		await process_frame
	print("seeds=%d platforms_checked=%d r_chain_violations=%d no_stacking_violations=%d hazard_reachable_violations=%d" % [
		SEED_COUNT, _checked, _chain_violations, _stacking_violations, _hazard_violations])
	print("hazard_share=%.4f%% min_chain_gap=%.4f max_chain_gap=%.4f hazard_steps=%d skipped_extras=%d skipped_extra_rate=%.4f%%" % [
		100.0 * _hazards / _checked, _min_gap, _max_gap, _hazard_steps,
		_hazard_steps - _hazards, 100.0 * (_hazard_steps - _hazards) / maxi(1, _hazard_steps)])
	_check_world_and_fire()
	await process_frame
	print("world_fire_checks=%d failures=%d" % [_integration_checks, _integration_failures])


func _record_platform(_platform: Node2D, index: int, platform_type: StringName,
		center: Vector2, travel_half_width: float) -> void:
	_records.append({"position": center, "type": platform_type, "travel": travel_half_width, "index": index})


func _is_hazard(record: Dictionary) -> bool:
	return record.type in [&"breakable", &"disappearing"]


func _check_chain(seed_value: int) -> void:
	var jump_height := PLAYER_SCRIPT.JUMP_VELOCITY * PLAYER_SCRIPT.JUMP_VELOCITY / (2.0 * PLAYER_SCRIPT.GRAVITY)
	var max_vertical_gap := 0.8 * jump_height
	var chain := {"position": ANCHOR, "type": &"ground", "travel": 0.0, "index": 1}
	var previous_chain := chain
	for record in _records:
		_checked += 1
		if _is_hazard(record):
			_hazards += 1
			var valid := _reachable(previous_chain, record, jump_height)
			valid = valid and previous_chain.position.y - record.position.y >= 30.0 - EPSILON
			valid = valid and record.position.y - chain.position.y >= 30.0 - EPSILON
			valid = valid and record.position.x >= 120.0 and record.position.x <= 960.0
			valid = valid and record.index == chain.index and chain.index > 10
			for neighbor in [previous_chain, chain]:
				valid = valid and absf(neighbor.position.x - record.position.x) >= 260.0 + neighbor.travel - EPSILON
			if not valid:
				_hazard_violations += 1
				_example(seed_value, "hazard", previous_chain, record)
		else:
			var gap: float = chain.position.y - record.position.y
			_min_gap = minf(_min_gap, gap)
			_max_gap = maxf(_max_gap, gap)
			var valid := _reachable(chain, record, 1.1 * max_vertical_gap)
			valid = valid and gap >= 0.55 * max_vertical_gap - EPSILON
			valid = valid and record.index == chain.index + 1
			if record.index <= 10 or chain.type != &"static" and chain.type != &"ground":
				valid = valid and record.type == &"static"
			if not valid:
				_chain_violations += 1
				_example(seed_value, "chain", chain, record)
			previous_chain = chain
			chain = record
	# Check every pair, including extras from different chain steps.
	for first_index in range(_records.size()):
		var first := _records[first_index]
		for second_index in range(first_index + 1, _records.size()):
			var second := _records[second_index]
			var overlaps: bool = absf(first.position.x - second.position.x) < 260.0 + first.travel + second.travel
			if overlaps and absf(first.position.y - second.position.y) < 0.55 * max_vertical_gap - EPSILON:
				_stacking_violations += 1
				_example(seed_value, "stacking", first, second)


func _reachable(source: Dictionary, target: Dictionary, max_rise: float) -> bool:
	var rise: float = source.position.y - target.position.y
	var discriminant := maxf(0.0, PLAYER_SCRIPT.JUMP_VELOCITY * PLAYER_SCRIPT.JUMP_VELOCITY
		- 2.0 * PLAYER_SCRIPT.GRAVITY * rise)
	var landing_time := (absf(PLAYER_SCRIPT.JUMP_VELOCITY) + sqrt(discriminant)) / PLAYER_SCRIPT.GRAVITY
	var reach := minf(1080.0 * 0.7, PLAYER_SCRIPT.MOVE_SPEED * landing_time * 0.75)
	var horizontal: float = absf(source.position.x - target.position.x) + source.travel + target.travel
	return rise > 0.0 and rise <= max_rise + EPSILON and horizontal <= reach + EPSILON


func _example(seed_value: int, rule: String, first: Dictionary, second: Dictionary) -> void:
	if not _printed_example:
		_printed_example = true
		print("example seed=%d rule=%s first=%s second=%s" % [seed_value, rule, first, second])


func _expect(condition: bool, description: String) -> void:
	_integration_checks += 1
	if not condition:
		_integration_failures += 1
		printerr("FAIL: " + description)


func _layout(manager: Node2D) -> Array:
	var result: Array = []
	for platform: Node2D in manager.get("_platforms"):
		result.append([platform.position, platform.get_meta("platform_type"),
			platform.call("get_travel_half_width") if platform.has_method("get_travel_half_width") else 0.0])
	return result


func _check_world_and_fire() -> void:
	# Exercise the real wiring synchronously, without driving the camera directly.
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	# Keep dummy-backend audio playback out of this synchronous physics audit.
	main.audio_manager.set_sound_enabled(false)
	main.run_seed = 1
	main._start_game()
	var world: Node2D = main._current_world
	var player: Node2D = main._player
	var fire = main._rising_fire
	var camera: Camera2D = main._camera
	_expect(is_equal_approx(camera.position.y, _screen_layout.BASE_HEIGHT - _screen_layout.half_height()), "initial camera uses visible height")
	_expect(is_equal_approx(_screen_layout.visible_bottom(camera.position.y), _screen_layout.BASE_HEIGHT), "start world bottom")
	_expect(main._platform_manager._highest_platform_position.y <= _screen_layout.visible_top(camera.position.y) - main._platform_manager.TOP_SPAWN_BUFFER, "initial spawn ceiling above view")
	var initial_layout := _layout(main._platform_manager)
	var ground := world.get_node("Ground") as StaticBody2D
	var collider := ground.get_node("CollisionShape2D") as CollisionShape2D
	var shape := collider.shape as RectangleShape2D
	_expect(is_equal_approx(collider.global_position.y - shape.size.y * 0.5, 1722.0), "ground top")
	_expect(collider.global_position.x - shape.size.x * 0.5 <= -200.0
		and collider.global_position.x + shape.size.x * 0.5 >= 1280.0, "ground width")
	_expect(collider.global_position.y + shape.size.y * 0.5 >= 2300.0, "ground depth")
	_expect(not collider.one_way_collision and ground.collision_layer == 2 and ground.collision_mask == 1, "ground collision")
	_expect(player.position == Vector2(540.0, 1678.0), "unchanged player start")
	_expect(initial_layout[0][0].y < ANCHOR.y, "no start platform")
	for index in range(9):
		_expect(initial_layout[index][1] == &"static", "safe platform %d" % index)
	_expect(fire.speed_model == 2 and fire.visible_band == 70.0 and fire.rise_speed_min == 90.0 and fire.rise_speed_max == 170.0
		and fire.leash_below_screen == 40.0 and fire.kill_inset == 12.0 and fire.activation_margin == 40.0, "fire export defaults")
	var jump_height: float = PLAYER_SCRIPT.JUMP_VELOCITY * PLAYER_SCRIPT.JUMP_VELOCITY / (2.0 * PLAYER_SCRIPT.GRAVITY)
	var inactive_y: float = fire.fire_top_y
	player.position.y = 1722.0 - jump_height
	fire._physics_process(30.0)
	_expect(fire.fire_top_y == inactive_y and not fire.visible, "ground-only jump never activates")
	# Vector2 coordinates are float32; round up so this is truly above the
	# inactive side of the float64 threshold rather than a fraction below it.
	player.position.y = ceilf(1722.0 - (jump_height + fire.activation_margin))
	fire._physics_process(1.0)
	_expect(fire.fire_top_y == inactive_y, "above activation threshold stays inactive")
	player.position.y -= 1.0
	fire._physics_process(0.0)
	var leash_y: float = _screen_layout.visible_bottom(camera.position.y) + fire.leash_below_screen
	_expect(fire.fire_top_y == leash_y and fire.visible, "activation starts at leash")
	fire.set_difficulty(0.0)
	fire._physics_process(1.0)
	_expect(is_equal_approx(fire.fire_top_y, leash_y - 90.0), "minimum rise speed")
	fire.set_difficulty(1.0)
	fire._physics_process(1.0)
	_expect(is_equal_approx(fire.fire_top_y, leash_y - 110.0), "maximum rise speed clamps at visible band")
	fire.fire_top_y = leash_y + 500.0
	fire._physics_process(0.0)
	_expect(fire.fire_top_y == leash_y, "screen-band leash clamps")
	var band_y: float = _screen_layout.visible_bottom(camera.position.y) - fire.visible_band
	fire.fire_top_y = band_y + 5.0
	fire._physics_process(1.0)
	_expect(fire.fire_top_y == band_y, "screen-band pins fire to visible band")
	for model in [2, 0]:
		fire.speed_model = model
		for pair in [[0.0, 90.0], [1.0, 170.0]]:
			fire.set_difficulty(pair[0])
			fire.fire_top_y = leash_y
			fire._physics_process(0.5)
			_expect(is_equal_approx(leash_y - fire.fire_top_y, pair[1] * 0.5),
				"unclamped rise rate %.0f px/s model %d" % [pair[1], model])
	fire.speed_model = 0
	fire.fire_top_y = leash_y + 500.0
	fire._physics_process(0.0)
	_expect(fire.fire_top_y == leash_y, "rubber-band leash clamps")
	fire.speed_model = 1
	fire.fire_top_y = leash_y + 500.0
	fire._physics_process(1.0)
	_expect(is_equal_approx(fire.fire_top_y, leash_y + 330.0), "constant mode has no leash")
	main._pause_game()
	_expect(paused and not fire.can_process(), "fire stops processing while paused")
	main._resume_game()
	_expect(not paused and fire.can_process(), "fire resumes with tree")
	var burns := [0]
	fire.player_burned.connect(func() -> void: burns[0] += 1)
	player.position.y = fire.fire_top_y + fire.kill_inset
	fire._physics_process(0.0)
	_expect(burns[0] == 0, "kill inset boundary is strict")
	player.position.y += 1.0
	fire._physics_process(0.0)
	_expect(burns[0] == 1 and main.run_session.state == main.run_session.RunState.GAME_OVER,
		"burn signal ends run")
	var stopped_y: float = fire.fire_top_y
	fire._physics_process(100.0)
	_expect(burns[0] == 1 and fire.fire_top_y == stopped_y and not fire.is_physics_processing(),
		"burn emits once and stops")
	main._retry()
	_expect(_layout(main._platform_manager) == initial_layout, "same seed reproduces layout on retry")
	_expect(not main._rising_fire.visible and not main._rising_fire.get("_active"), "retry resets fire")
	main.run_session.end_run()
	_expect(not main._rising_fire.is_physics_processing(), "other game-over causes also stop fire")
	main.audio_manager.get_music_player().stop()
	main.free()
