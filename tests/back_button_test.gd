extends SceneTree

const PROFILE_PATH := "user://profile.cfg"
var _checks := 0
var _failures := 0
var _profile_backup := PackedByteArray()
var _profile_existed := false


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + description)


func _back(main: Node) -> void:
	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await create_timer(0.8).timeout


func _run() -> void:
	_profile_existed = FileAccess.file_exists(PROFILE_PATH)
	if _profile_existed:
		_profile_backup = FileAccess.get_file_as_bytes(PROFILE_PATH)
	root.content_scale_size = Vector2i(1080, 1920)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
	root.size = Vector2i(1080, 1920)
	await process_frame
	_expect(not ProjectSettings.get_setting("application/config/quit_on_go_back", true), "quit_on_go_back disabled")
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	main.audio_manager.stop_all_audio()
	main._suppress_quit = true
	await create_timer(0.8).timeout

	_expect(main._is_open(main._main_menu), "boot shows main menu")
	main._show_shop()
	_expect(main._is_open(main._shop_screen), "shop opens")
	await _back(main)
	_expect(not main._is_open(main._shop_screen) and main._is_open(main._main_menu), "back from shop returns to menu")
	_expect(not main._quit_requested, "back from shop does not quit")

	main._show_settings()
	_expect(main._is_open(main._settings_menu), "settings opens from menu")
	await _back(main)
	_expect(not main._is_open(main._settings_menu) and main._is_open(main._main_menu), "back from settings returns to menu")
	_expect(not main._quit_requested, "back from settings does not quit")

	main._start_game()
	await create_timer(0.8).timeout
	_expect(main.run_session.state == main.run_session.RunState.PLAYING, "run is playing")
	await _back(main)
	_expect(main.run_session.state == main.run_session.RunState.PAUSED and main._is_open(main._pause_overlay), "back during play pauses")

	main._show_settings_from_pause()
	_expect(main._is_open(main._settings_menu) and main._settings_return_to_pause, "settings opens from pause")
	await _back(main)
	_expect(not main._is_open(main._settings_menu) and main._is_open(main._pause_overlay), "back from settings returns to pause")

	await _back(main)
	_expect(main.run_session.state == main.run_session.RunState.PLAYING, "back from pause resumes")
	_expect(not main._quit_requested, "no quit during run")

	main.run_session.end_run()
	await create_timer(0.8).timeout
	_expect(main.run_session.state == main.run_session.RunState.GAME_OVER and main._is_open(main._game_over_screen), "game over shown")
	await _back(main)
	_expect(main._is_open(main._main_menu) and not main._quit_requested, "back from game over returns to menu")

	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_expect(main._quit_requested, "back from main menu requests quit")

	if _profile_existed:
		var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
		file.store_buffer(_profile_backup)
	elif FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	print("back_button_checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
	quit(1 if _failures > 0 else 0)
