extends SceneTree

## Real physics: the rising fire waits for the first platform landing.

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + description)


func _run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	main.audio_manager.set_sound_enabled(false)
	main.run_seed = 1
	main._start_game()
	var player: CharacterBody2D = main._player
	var fire = main._rising_fire
	var ground: Node = main._current_world.get_node("Ground")
	var landings: Array = []
	player.landed.connect(func(collider: Object) -> void: landings.append(collider))

	# No input, standing clear of every platform within reach: the dragon keeps bouncing on the ground.
	var platforms: Array = main._platform_manager.get("_platforms")
	var clear_x := -1.0
	for x in range(80, 1001, 20):
		var blocked := false
		for platform: Node2D in platforms:
			if platform.global_position.y > 1722.0 - 500.0 and absf(platform.global_position.x - x) < 220.0:
				blocked = true
		if not blocked:
			clear_x = x
			break
	_expect(clear_x >= 0.0, "found a clear spot on the ground")
	player.global_position.x = clear_x
	for i in 150:
		await physics_frame
	_expect(landings.size() >= 2, "dragon bounced on the ground")
	_expect(landings.all(func(collider: Object) -> bool: return collider == ground), "only ground landings so far")
	_expect(not fire.is_active() and not fire.visible, "ground bouncing never starts the fire")

	# Jump to the first platform's height beside it without touching it.
	var lowest: Node2D = null
	for platform: Node2D in platforms:
		if lowest == null or platform.global_position.y > lowest.global_position.y:
			lowest = platform
	var beside_x := lowest.global_position.x + 360.0 if lowest.global_position.x < 540.0 else lowest.global_position.x - 360.0
	player.global_position = Vector2(beside_x, lowest.global_position.y - 20.0)
	player.velocity = Vector2(0.0, -200.0)
	for i in 10:
		await physics_frame
	_expect(not fire.is_active(), "reaching platform height without landing keeps fire off")

	# Drop the dragon onto the lowest platform.
	landings.clear()
	player.global_position = Vector2(lowest.global_position.x, lowest.global_position.y - 120.0)
	player.velocity = Vector2.ZERO
	var frames := 0
	while frames < 120 and not landings.has(lowest):
		await physics_frame
		frames += 1
	_expect(landings.has(lowest), "dragon landed on the lowest platform")
	await physics_frame
	await physics_frame
	_expect(fire.is_active() and fire.visible, "first platform landing starts the fire")

	main._retry()
	_expect(not main._rising_fire.is_active(), "retry resets the landing gate")
	main.audio_manager.stop_all_audio()
	main.queue_free()
	await process_frame
	print("fire_start_checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)
