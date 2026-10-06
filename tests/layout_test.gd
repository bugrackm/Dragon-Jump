extends SceneTree

const LAYOUT := preload("res://scripts/ScreenLayout.gd")
const HEIGHTS := [1920, 2340, 2400, 2520]
var _checks := 0
var _failures := 0
var _layout: Node


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + description)


func _run() -> void:
	_layout = root.get_node("ScreenLayout")
	if OS.get_cmdline_user_args().has("--fake-safe-area=120,90"):
		_expect(_layout.safe_insets == Vector4(0, 120, 0, 90), "command-line safe area")
	for pair in [
		[Vector2(1080, 1920), Vector2(1080, 1920)],
		[Vector2(1080, 2340), Vector2(1080, 2340)],
		[Vector2(1440, 3200), Vector2(1080, 2400)],
		[Vector2(1080, 2520), Vector2(1080, 2520)],
		[Vector2(1536, 2048), Vector2(1080, 1920)],
	]:
		_expect(LAYOUT.compute_visible_size(pair[0]).is_equal_approx(pair[1]), "visible size %s" % pair[0])
	_expect(LAYOUT.compute_safe_insets(Rect2(0, 0, 1440, 3200),
		Vector2(1440, 3200), Vector2(1080, 2400)) == Vector4.ZERO, "full safe rect")
	_expect(LAYOUT.compute_safe_insets(Rect2(0, 120, 1440, 2990),
		Vector2(1440, 3200), Vector2(1080, 2400)).is_equal_approx(
		Vector4(0, 90, 0, 67.5)), "phone pixel conversion")
	# Tablet content occupies x=192..1344, at 16/15 screen px per virtual px.
	_expect(LAYOUT.compute_safe_insets(Rect2(100, 0, 1336, 2048),
		Vector2(1536, 2048), Vector2(1080, 1920)) == Vector4.ZERO, "insets inside pillarbox bars")
	_expect(LAYOUT.compute_safe_insets(Rect2(224, 64, 1088, 1952),
		Vector2(1536, 2048), Vector2(1080, 1920)).is_equal_approx(
		Vector4(30, 60, 30, 30)), "pillarbox content insets")
	_expect(LAYOUT.compute_safe_insets(Rect2(4000, 4000, 100, 100),
		Vector2(1080, 1920), Vector2(1080, 1920)) == Vector4.ZERO, "nonintersecting desktop report")
	_expect(LAYOUT.compute_visible_size(Vector2.ZERO) == Vector2(1080, 1920), "invalid screen fallback")

	root.content_scale_size = Vector2i(1080, 1920)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
	for height in HEIGHTS:
		root.size = Vector2i(1080, height)
		await process_frame
		_expect(_layout.visible_size.is_equal_approx(Vector2(1080, height)), "live viewport %d" % height)
		var camera_y: float = LAYOUT.BASE_HEIGHT - height * 0.5
		_expect(is_equal_approx(_layout.visible_bottom(camera_y), LAYOUT.BASE_HEIGHT), "world bottom %d" % height)
		_expect(is_equal_approx(_layout.visible_top(camera_y), LAYOUT.BASE_HEIGHT - height), "world top %d" % height)
		await _check_background(height)
	await _check_ui()
	_sample_sky()
	print("layout_checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
	await create_timer(0.3, true, false, true).timeout
	quit(0 if _failures == 0 else 1)


func _check_ui() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, 2400)
	root.add_child(viewport)
	var hud = load("res://scenes/HUD.tscn").instantiate()
	viewport.add_child(hud)
	hud.show_playing()
	var menus: Array[CanvasLayer] = []
	for scene_name in ["MainMenu", "GameOverScreen", "PauseOverlay", "SettingsMenu", "ShopScreen"]:
		var menu := load("res://scenes/%s.tscn" % scene_name).instantiate() as CanvasLayer
		viewport.add_child(menu)
		menu.visible = true
		menus.append(menu)
	_layout.debug_insets_override = Vector4.ZERO
	var changes := [0]
	var on_change := func() -> void: changes[0] += 1
	_layout.layout_changed.connect(on_change)
	for insets in [Vector4(0, 120, 0, 90), Vector4(60, 140, 80, 100), Vector4.ZERO]:
		_layout.debug_insets_override = insets
		var count: int = changes[0]
		_layout.refresh()
		_expect(changes[0] == count, "unchanged refresh emits no signal")
		await process_frame
		await process_frame
		var safe_rect := Rect2(Vector2(insets.x, insets.y),
			Vector2(viewport.size) - Vector2(insets.x + insets.z, insets.y + insets.w))
		for path in ["MarginContainer/Rows/ScoreLabel", "MarginContainer/Rows/CoinLabel", "PauseButton", "FireButton"]:
			_expect(safe_rect.encloses((hud.get_node(path) as Control).get_global_rect()), "safe HUD " + path)
		var pause_rect: Rect2 = hud.get_node("PauseButton").get_global_rect()
		_expect(pause_rect.size.x >= 120 and pause_rect.size.y >= 120, "pause touch target")
		_expect(is_equal_approx(pause_rect.position.y, _edge(40, insets.y)), "pause top design margin")
		_expect(is_equal_approx(pause_rect.end.x, viewport.size.x - _edge(40, insets.z)), "pause right design margin")
		_expect(is_equal_approx(hud.get_node("FireButton").get_global_rect().end.y,
			viewport.size.y - _edge(40, insets.w)), "fire bottom design margin")
		_expect(is_equal_approx((hud.get_node("MarginContainer/Rows") as Control).get_global_rect().position.y,
			_edge(36, insets.y)), "score top design margin")
		for menu in menus:
			_expect(safe_rect.is_equal_approx(menu.get_node("CenterContainer").get_global_rect()), "safe content " + menu.name)
			_expect(menu.get_node("Background").get_global_rect().is_equal_approx(
				Rect2(Vector2.ZERO, Vector2(viewport.size))), "full bleed " + menu.name)
			for button in menu.find_children("*", "BaseButton"):
				_expect(safe_rect.encloses(button.get_global_rect()), "safe menu button " + menu.name + "/" + button.name)
	_expect(changes[0] == 3, "override changes emit once each")
	_layout.debug_insets_override = Vector4(-10, 120, -20, 90)
	_expect(_layout.safe_insets == Vector4(0, 120, 0, 90), "debug insets clamp nonnegative")
	_layout.layout_changed.disconnect(on_change)
	viewport.free()
	_layout.debug_insets_override = Vector4(-1, -1, -1, -1)


## Distance from the screen edge: the design gap without a cutout, otherwise
## just below the cutout (12 px padding) unless the design gap is larger.
func _edge(gap: float, inset: float) -> float:
	return gap if inset <= 0.0 else maxf(gap, inset + 12.0)


func _check_background(height: int) -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	main.audio_manager.set_sound_enabled(false)
	main._start_game()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main._camera.force_update_scroll()
	await process_frame
	var background: ParallaxBackground = main._current_world.get_node("Background")
	var screen := Rect2(0, 0, 1080, height)
	var sky := background.get_node("Sky/Sprite") as Sprite2D
	_expect(_sprite_rect(sky).encloses(screen), "sky at start %d" % height)
	for layer_name in ["FarLandscape", "MidLandscape", "NearLandscape"]:
		var sprite := background.get_node(layer_name + "/Sprite") as Sprite2D
		var rect := _sprite_rect(sprite)
		_expect(is_equal_approx(rect.end.y, height), "landscape bottom %s %d: %s" % [layer_name, height, rect])
	for layer_name in ["FarClouds", "NearClouds"]:
		_expect(background.get_node(layer_name).motion_mirroring.y >= 2520, "cloud period " + layer_name)
	# Move the player and invoke the existing follow code; never write camera position.
	main._player.position.y = -4000
	main._follow_player_upward(0.0)
	main._camera.force_update_scroll()
	await process_frame
	_expect(_sprite_rect(sky).encloses(screen), "sky during climb %d" % height)
	var camera_y: float = main._camera.position.y
	root.size = Vector2i(1080, 2400 if height != 2400 else 2520)
	await process_frame
	main._camera.force_update_scroll()
	await process_frame
	_expect(is_equal_approx(main._camera.position.y, camera_y), "resize preserves altimeter")
	_expect(_sprite_rect(sky).encloses(Rect2(Vector2.ZERO, _layout.visible_size)), "sky after resize")
	main._platform_manager.update_for_camera(camera_y)
	_expect(main._platform_manager._highest_platform_position.y <= _layout.visible_top(camera_y)
		- main._platform_manager.TOP_SPAWN_BUFFER, "live spawn ceiling")
	main.audio_manager.get_music_player().stop()
	main.free()
	root.size = Vector2i(1080, height)
	await process_frame


func _sprite_rect(sprite: Sprite2D) -> Rect2:
	return sprite.get_global_transform_with_canvas() * sprite.get_rect()


func _sample_sky() -> void:
	var sky := (load("res://assets/sprites/background/bg_layer1.png") as Texture2D).get_image()
	var sample := Color(0, 0, 0, 0)
	var count := 0
	for y in range(0, 128, 16):
		for x in range(512, 1536, 64):
			sample += sky.get_pixel(x, y)
			count += 1
	sample /= float(count)
	print("sky_top_sample=%s" % sample)
	var clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	_expect(absf(clear.r - sample.r) < 0.001 and absf(clear.g - sample.g) < 0.001
		and absf(clear.b - sample.b) < 0.001, "clear color matches sky top")
