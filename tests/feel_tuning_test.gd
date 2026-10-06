extends SceneTree

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + description)


func _touch(input: Node, pressed: bool, x: float, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.pressed = pressed
	event.index = index
	event.position = Vector2(x, 1000.0)
	input._handle_screen_touch(event)


func _new_input() -> Node:
	var input: Node = load("res://scripts/InputController.gd").new()
	root.add_child(input)
	input.set_active(true)
	return input


func _run() -> void:
	_check_input()
	await _check_fire_and_camera()
	print("checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
	await create_timer(0.3, true, false, true).timeout
	quit(1 if _failures > 0 else 0)


func _check_input() -> void:
	var input := _new_input()
	var states = input.TouchState

	# Short tap: output is zero immediately after release.
	_touch(input, true, 900.0)
	_expect(input.horizontal_direction == 1.0, "tap down moves right")
	input._advance_touch_state(0.05)
	_touch(input, false, 900.0)
	_expect(input.get_touch_state() == states.FIRST_TAP_WINDOW, "tap enters double-tap window")
	_expect(input.horizontal_direction == 0.0, "tap release zeroes direction")
	input._advance_touch_state(0.1)
	input._refresh_outputs()
	_expect(input.horizontal_direction == 0.0, "direction stays zero in tap window")
	input._advance_touch_state(0.25)
	input._refresh_outputs()
	_expect(input.get_touch_state() == states.IDLE and input.horizontal_direction == 0.0, "window lapse returns to idle")

	# Hold: non-zero while held, zero after release.
	_touch(input, true, 100.0)
	input._advance_touch_state(0.5)
	input._refresh_outputs()
	_expect(input.get_touch_state() == states.HOLDING and input.horizontal_direction == -1.0, "hold moves left")
	_touch(input, false, 100.0)
	_expect(input.horizontal_direction == 0.0 and input.get_touch_state() == states.IDLE, "hold release stops")

	# Multi-touch: last pressed finger wins, with fallback on release.
	_touch(input, true, 900.0, 0)
	input._advance_touch_state(0.5)
	_touch(input, true, 100.0, 1)
	_expect(input.get_touch_state() == states.HOLDING and input.horizontal_direction == -1.0, "overlap press switches direction immediately")
	_touch(input, false, 900.0, 0)
	_expect(input.get_touch_state() == states.HOLDING and input.horizontal_direction == -1.0, "releasing older finger keeps newest")
	_touch(input, false, 100.0, 1)
	_expect(input.get_touch_state() == states.IDLE and input.horizontal_direction == 0.0, "last release stops")

	_touch(input, true, 900.0, 0)
	input._advance_touch_state(0.5)
	_touch(input, true, 100.0, 1)
	_touch(input, false, 100.0, 1)
	_expect(input.get_touch_state() == states.HOLDING and input.horizontal_direction == 1.0, "newest release falls back to older finger")
	input.cancel_glide_on_landing()
	_expect(input.horizontal_direction == 1.0, "landing cancel keeps direction while finger down")
	_touch(input, false, 100.0, 7)
	_expect(input.horizontal_direction == 1.0 and input.get_touch_state() == states.HOLDING, "unknown index release ignored")
	_touch(input, false, 900.0, 0)
	_expect(input.horizontal_direction == 0.0, "fallback finger release stops")

	# Three fingers.
	_touch(input, true, 900.0, 0)
	input._advance_touch_state(0.5)
	_touch(input, true, 100.0, 1)
	_touch(input, true, 900.0, 2)
	_expect(input.horizontal_direction == 1.0, "third finger becomes primary")
	_touch(input, false, 900.0, 2)
	_expect(input.horizontal_direction == -1.0, "falls back to second finger")
	_touch(input, false, 900.0, 0)
	_expect(input.horizontal_direction == -1.0, "non-primary release only removes it")
	_touch(input, false, 100.0, 1)
	_expect(input.horizontal_direction == 0.0 and input.get_touch_state() == states.IDLE, "all fingers up stops")

	# Overlap during glide keeps glide and steers; never a double jump.
	_touch(input, true, 100.0, 0)
	input._advance_touch_state(0.05)
	_touch(input, false, 100.0, 0)
	_touch(input, true, 100.0, 0)
	input._advance_touch_state(0.2)
	_touch(input, true, 900.0, 1)
	input._refresh_outputs()
	_expect(input.get_touch_state() == states.GLIDING and input.glide_active and input.horizontal_direction == 1.0, "overlap during glide steers and keeps glide")
	_touch(input, false, 900.0, 1)
	_expect(input.get_touch_state() == states.GLIDING and input.horizontal_direction == -1.0, "glide fallback keeps glide")
	_touch(input, false, 100.0, 0)
	_expect(not input.consume_double_jump_request(), "overlap never double-jumps")
	_touch(input, true, 100.0, 0)
	input._advance_touch_state(0.05)
	_touch(input, true, 900.0, 1)
	_touch(input, false, 900.0, 1)
	_touch(input, false, 100.0, 0)
	_expect(not input.consume_double_jump_request() and input.get_touch_state() == states.IDLE, "overlap during first press is not a tap")

	# Drag across the midline flips direction.
	_touch(input, true, 900.0, 0)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(100.0, 1000.0)
	input._handle_screen_drag(drag)
	_expect(input.horizontal_direction == -1.0, "drag across midline flips direction")
	drag.index = 5
	drag.position = Vector2(900.0, 1000.0)
	input._handle_screen_drag(drag)
	_expect(input.horizontal_direction == -1.0, "drag from unknown index ignored")
	input._advance_touch_state(0.5)
	_touch(input, false, 100.0, 0)
	_expect(input.horizontal_direction == 0.0, "release after drag stops")

	# Tap + quick tap: double jump, second touch follows its side.
	_touch(input, true, 100.0)
	input._advance_touch_state(0.05)
	_touch(input, false, 100.0)
	_touch(input, true, 900.0)
	_expect(input.get_touch_state() == states.SECOND_DOWN and input.horizontal_direction == 1.0, "second touch follows its side")
	input._advance_touch_state(0.05)
	_touch(input, false, 900.0)
	_expect(input.consume_double_jump_request(), "tap+tap requests double jump")
	_expect(input.horizontal_direction == 0.0, "double tap release stops")

	# Tap + hold: glide.
	_touch(input, true, 100.0)
	input._advance_touch_state(0.05)
	_touch(input, false, 100.0)
	_touch(input, true, 100.0)
	input._advance_touch_state(0.2)
	input._refresh_outputs()
	_expect(input.glide_active and input.horizontal_direction == -1.0, "tap+hold glides")
	_touch(input, false, 100.0)
	_expect(not input.glide_active and input.horizontal_direction == 0.0, "glide release stops")
	input.free()


func _check_fire_and_camera() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	main.audio_manager.set_sound_enabled(false)
	main.run_seed = 1
	main._start_game()
	var player: Node2D = main._player
	var fire = main._rising_fire
	var camera: Camera2D = main._camera
	var layout: Node = root.get_node("ScreenLayout")

	_expect(main.auto_scroll_min == 30.0 and main.auto_scroll_max == 120.0, "auto-scroll defaults")
	var start_y := camera.position.y
	main._follow_player_upward(1.0)
	_expect(camera.position.y == start_y, "no auto-scroll before fire is active")

	# Activate the fire, then keep the player pinned high so only auto-scroll moves the camera.
	player.position.y = 1000.0
	player.velocity = Vector2.ZERO
	fire._physics_process(0.0)
	_expect(fire.is_active(), "fire active after leaving ground")
	player.position.y = camera.position.y + 10.0

	var before := camera.position.y
	main.run_session.score = 0
	main._follow_player_upward(1.0)
	_expect(is_equal_approx(before - camera.position.y, 30.0), "auto-scroll min at difficulty 0")
	main.run_session.score = 1000000
	before = camera.position.y
	main._follow_player_upward(1.0)
	_expect(is_equal_approx(before - camera.position.y, 120.0), "auto-scroll max at difficulty 1")

	var monotonic := true
	var last := camera.position.y
	main.run_session.score = 2500
	for i in 120:
		player.position.y = camera.position.y + 10.0
		main._follow_player_upward(1.0 / 60.0)
		if camera.position.y > last:
			monotonic = false
		last = camera.position.y
	_expect(monotonic, "camera never moves down")
	player.position.y = camera.position.y - 500.0
	main._follow_player_upward(1.0 / 60.0)
	_expect(is_equal_approx(camera.position.y, player.position.y), "camera follows faster climber")

	# Fire converges to the visible band.
	player.position.y = camera.position.y - 100.0
	for i in 600:
		fire._physics_process(1.0 / 60.0)
	var band_y: float = layout.visible_bottom(camera.position.y) - fire.visible_band
	_expect(is_equal_approx(fire.fire_top_y, band_y), "fire pinned to visible band")

	# Player sinking into the band burns once and ends the run.
	var burns := [0]
	fire.player_burned.connect(func() -> void: burns[0] += 1)
	player.position.y = fire.fire_top_y + fire.kill_inset + 1.0
	fire._physics_process(0.0)
	fire._physics_process(0.0)
	_expect(burns[0] == 1, "player_burned emitted once")
	_expect(main.run_session.state == main.run_session.RunState.GAME_OVER, "burn ends run")
	var frozen := camera.position.y
	main._physics_process(1.0)
	_expect(camera.position.y == frozen, "no auto-scroll after game over")

	# Retry resets camera and fire.
	main._retry()
	player = main._player
	fire = main._rising_fire
	camera = main._camera
	_expect(is_equal_approx(camera.position.y, start_y) and is_equal_approx(main._highest_camera_y, start_y), "retry resets camera")
	_expect(not fire.is_active(), "retry: fire inactive until player leaves ground")
	main._physics_process(1.0)
	_expect(is_equal_approx(camera.position.y, start_y), "retry: no auto-scroll before activation")
	player.position.y = 1000.0
	fire._physics_process(0.0)
	_expect(fire.is_active(), "retry: fire activates after leaving ground")

	# Pause gating.
	player.position.y = camera.position.y + 10.0
	main._pause_game()
	var paused_y := camera.position.y
	main._physics_process(1.0)
	_expect(main.run_session.state != main.run_session.RunState.PLAYING and camera.position.y == paused_y, "no auto-scroll while paused")
	main._resume_game()
	main.audio_manager.get_music_player().stop()
	main.free()
