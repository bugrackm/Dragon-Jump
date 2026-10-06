extends SceneTree

## Theme, screen transitions and animation regressions, including interrupted effects.
const UiFx := preload("res://scripts/ui/UiFx.gd")


class UnsavedProfile extends Node:
	var high_score := 1200

	func update_high_score(value: int) -> bool:
		high_score = maxi(high_score, value)
		return false

	func add_coins(_amount: int) -> void:
		pass

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
	_check_theme()
	root.content_scale_size = Vector2i(1080, 1920)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
	root.size = Vector2i(1080, 1920)
	await process_frame
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	main.audio_manager.stop_all_audio()
	var backdrop: ParallaxBackground = main._menu_backdrop
	_expect(is_instance_valid(backdrop), "menu backdrop exists")
	_expect(main.find_children("*", "ParallaxBackground", true, false).size() == 1, "one menu parallax")
	var dragon := main._main_menu.find_child("MenuDragon", true, false) as AnimatedSprite2D
	_expect(dragon.sprite_frames == load("res://assets/sprites/player/dragon_frames.tres"), "menu shares dragon frames")
	_expect(dragon.is_playing(), "menu dragon animates")
	_expect(not main.hud.get_node("MarginContainer/Rows").visible, "menu hides HUD stats")
	await _check_living_menu(main._main_menu, dragon)
	var play: Button = main._main_menu.get_node("%Card").get_node("Content/PlayButton")
	_expect(play.get_theme_font("font").get_font_name().contains("Lilita"), "project theme reaches menu buttons")
	for height in [1920, 2400, 2520]:
		root.size = Vector2i(1080, height)
		await process_frame
		await process_frame
		_expect(backdrop.scroll_offset.is_equal_approx(Vector2(0, height - 1920)), "menu scroll at %d" % height)
		var sky := backdrop.get_node("Sky/Sprite") as Sprite2D
		_expect((sky.get_global_transform_with_canvas() * sky.get_rect()).encloses(
			Rect2(0, 0, 1080, height)), "menu sky coverage %d" % height)
		for layer_name in ["FarLandscape", "MidLandscape", "NearLandscape"]:
			var sprite := backdrop.get_node(layer_name + "/Sprite") as Sprite2D
			var rect: Rect2 = sprite.get_global_transform_with_canvas() * sprite.get_rect()
			_expect(is_equal_approx(rect.end.y, height), "menu landscape bottom " + layer_name)
	var cloud_x: float = backdrop.get_node("FarClouds").motion_offset.x
	paused = true
	await create_timer(0.1, true, false, true).timeout
	_expect(backdrop.get_node("FarClouds").motion_offset.x != cloud_x, "clouds drift while paused")
	for layer_name in ["FarLandscape", "MidLandscape", "NearLandscape"]:
		_expect(backdrop.get_node(layer_name).motion_offset.x == 0, "landscape stays still " + layer_name)
	paused = false
	main._show_shop()
	main._hide_shop()
	main._show_shop()
	await create_timer(0.35).timeout
	_expect(main._is_open(main._shop_screen), "rapid shop reopen wins")
	_expect(not main._main_menu.visible, "shop hides main menu")
	_expect(not main.hud.get_node("MarginContainer/Rows").visible, "shop hides HUD stats")
	_expect(main._shop_screen.visible and main._menu_backdrop == backdrop, "shop retains backdrop")
	main._hide_shop()
	main._show_settings()
	var settings = main._settings_menu
	_expect(not main._main_menu.visible, "settings hides main menu")
	_expect(not main.hud.get_node("MarginContainer/Rows").visible, "menu settings hides HUD stats")
	_expect(settings.visible and main._menu_backdrop == backdrop, "settings retains backdrop")
	_expect(settings.sound_icon.texture == (settings.SOUND_ON if settings.sound_toggle.button_pressed
		else settings.SOUND_OFF), "sound icon sync on open")
	_expect(settings.music_icon.texture == (settings.MUSIC_ON if settings.music_toggle.button_pressed
		else settings.MUSIC_OFF), "music icon sync on open")
	# Disconnect persistence before exercising toggles; tests must not change saved settings.
	settings._profile_store = null
	settings._audio_manager = null
	for enabled in [false, true]:
		settings.sound_toggle.button_pressed = enabled
		settings.music_toggle.button_pressed = enabled
		_expect(settings.sound_icon.texture == (settings.SOUND_ON if enabled else settings.SOUND_OFF), "sound icon toggle")
		_expect(settings.music_icon.texture == (settings.MUSIC_ON if enabled else settings.MUSIC_OFF), "music icon toggle")
	main._hide_settings()
	_expect(main._is_open(main._main_menu), "settings returns to main menu immediately")
	_expect(main._menu_backdrop == backdrop, "settings return retains backdrop")
	main._show_settings()
	await create_timer(0.35).timeout
	_expect(main._is_open(settings) and not main._main_menu.visible, "rapid menu settings reopen wins")
	main._hide_settings()
	await create_timer(0.35).timeout
	_expect(not settings.visible and main._is_open(main._main_menu), "settings fade returns cleanly to menu")
	main._start_game()
	_expect(not is_instance_valid(backdrop) and main._menu_backdrop == null, "backdrop freed on start")
	_expect(main.find_children("*", "ParallaxBackground", true, false).size() == 1, "exactly one gameplay parallax")
	_expect(main.hud.get_node("MarginContainer/Rows").visible, "start shows HUD stats")
	main.set_physics_process(false)
	main._current_world.process_mode = Node.PROCESS_MODE_DISABLED
	await _check_transitions(main)
	await _check_feedback(main)
	await _check_numbers(main)
	var player_sprite: AnimatedSprite2D = main._player.get_node("VisualRoot/Sprite")
	_expect(player_sprite.sprite_frames == load("res://assets/sprites/player/dragon_frames.tres"), "player shares dragon frames")
	main.hud.set_fire_cooldown(true)
	_expect(is_equal_approx(main.hud.fire_button.self_modulate.a, 0.45), "fire cooldown dim preserved")
	main.hud.set_fire_cooldown(false)
	_expect(is_equal_approx(main.hud.fire_button.self_modulate.a, 1.0), "fire cooldown reset preserved")
	main._game_over_screen.show_screen(5000, 5000, 50, true)
	main._game_over_screen.get_node("%Card/Content/RetryButton").pressed.emit()
	_expect(not main._game_over_screen.visible and main.run_session.state == main.run_session.RunState.PLAYING, "retry works during pop and restarts play")
	main._game_over_screen.show_screen(5000, 5000, 50, true)
	main._game_over_screen.get_node("%Card/Content/MenuButton").pressed.emit()
	_expect(is_instance_valid(main._menu_backdrop), "backdrop recreated on return")
	_expect(not main.hud.get_node("MarginContainer/Rows").visible, "return to menu hides HUD stats")
	await create_timer(0.4).timeout
	_expect(not main._game_over_screen.visible and not main._pause_overlay.visible, "quit cancels overlay transitions")
	main.audio_manager.stop_all_audio()
	main.free()
	await process_frame
	print("ui_fx_checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)


func _check_theme() -> void:
	var path: String = ProjectSettings.get_setting("gui/theme/custom", "")
	_expect(path == "res://assets/ui/theme/dragon_theme.tres", "project theme configured")
	var theme := load(path) as Theme
	_expect(theme != null, "theme loads")
	if theme == null:
		return
	for type in ["SecondaryButton", "AccentButton", "IconButton", "FireButton"]:
		_expect(theme.get_type_variation_base(type) == &"Button", "button variation " + type)
	for type in ["TitleLabel", "HeaderLabel", "StatLabel", "HudLabel", "HudSubLabel", "BadgeLabel", "ShopNameLabel", "ShopPriceLabel"]:
		_expect(theme.get_type_variation_base(type) == &"Label", "label variation " + type)
	for type in ["Card", "ShopRow", "Badge"]:
		_expect(theme.get_type_variation_base(type) == &"PanelContainer", "panel variation " + type)
	var title := theme.get_font("font", "TitleLabel")
	_expect(title != null and title.get_font_name().contains("Lilita"), "Lilita loads")
	var body := theme.get_font("font", "Label") as FontVariation
	_expect(body != null and body.base_font.get_font_name().contains("Fredoka"), "Fredoka variation loads")
	if body != null:
		var weight := TextServerManager.get_primary_interface().name_to_tag("wght")
		_expect(body.base_font.get_supported_variation_list().has(weight), "Fredoka supports weight axis")
		_expect(body.variation_opentype.get(weight) == 600.0, "Fredoka weight 600")
		var rid := body.get_rids()[0]
		_expect(TextServerManager.get_primary_interface().font_get_variation_coordinates(rid).get(weight) == 600.0,
			"text server applies weight 600")
	for type in ["Button", "SecondaryButton", "AccentButton", "IconButton", "FireButton"]:
		var normal := theme.get_stylebox("normal", type) as StyleBoxFlat
		var pressed := theme.get_stylebox("pressed", type) as StyleBoxFlat
		_expect(normal.shadow_size == 1 and pressed.shadow_size == 0, "pressed shadow " + type)
		_expect(pressed.expand_margin_top == -6 and pressed.expand_margin_bottom == 6, "pressed face drops " + type)
		_expect(normal.get_minimum_size() == pressed.get_minimum_size(), "pressed minimum size stable " + type)
		_expect(theme.get_stylebox("disabled", type).shadow_size == 0, "disabled shadow " + type)
	for name in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		_expect(theme.get_icon(name, "CheckButton") is ImageTexture, "embedded toggle " + name)
	for name in ["grabber", "grabber_highlight", "grabber_disabled"]:
		_expect(theme.get_icon(name, "HSlider") is ImageTexture, "embedded slider " + name)


func _check_living_menu(menu: CanvasLayer, dragon: AnimatedSprite2D) -> void:
	await process_frame
	await process_frame
	var title := menu.find_child("TitleLabel", true, false) as Control
	var original_position := title.position
	var dragon_position := dragon.position
	for tree_paused in [false, true]:
		paused = tree_paused
		await create_timer(0.15).timeout
		_expect(not title.position.is_equal_approx(original_position), "title bobs paused=%s" % tree_paused)
		_expect(not title.scale.is_equal_approx(Vector2.ONE), "title breathes paused=%s" % tree_paused)
		_expect(not dragon.position.is_equal_approx(dragon_position), "dragon travels paused=%s" % tree_paused)
	# Advance to both turns and the flap boundary without waiting a whole flight cycle.
	dragon._elapsed = 3.0
	dragon._flap_clock = 2.99
	dragon._process(0.02)
	_expect(dragon.flip_h and dragon.animation == &"double_jump", "dragon turns and flaps")
	await create_timer(0.3).timeout
	_expect(dragon.animation == &"glide" and dragon.is_playing(), "flap returns to glide while paused")
	dragon._elapsed = 7.0
	dragon._process(0.02)
	_expect(not dragon.flip_h, "dragon turns back")
	paused = false


func _check_transitions(main: Node) -> void:
	var overlay: CanvasLayer = main._pause_overlay
	var card := overlay.get_node("%Card") as Control
	var background := overlay.get_node("Background") as Control
	main._pause_game()
	_expect(card.scale.is_equal_approx(Vector2.ONE * 0.85), "open begins with card pop")
	_expect(is_zero_approx(background.modulate.a), "open begins with transparent background")
	await create_timer(0.06).timeout
	_expect(card.scale.x > 0.85 and not card.scale.is_equal_approx(Vector2.ONE), "card pop survives initial container layout")
	main._resume_game()
	_expect(not paused and UiFx.is_closing(overlay), "resume unpauses immediately during fade")
	_expect(background.mouse_filter == Control.MOUSE_FILTER_IGNORE, "closing background passes input")
	_expect(card.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED, "closing card disables input")
	_expect(card.get_node("Content/ResumeButton").get_mouse_filter_with_override() == Control.MOUSE_FILTER_IGNORE, "closing button cannot intercept clicks")
	_expect(not main._is_open(overlay), "closing overlay is logically closed")
	main._pause_game()
	await create_timer(0.4).timeout
	_expect(overlay.visible and paused and not UiFx.is_closing(overlay), "rapid pause resume pause wins")
	_expect(card.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(card.modulate.a, 1.0), "reopened card settles")
	_expect(is_equal_approx(background.modulate.a, 1.0), "reopened background settles")
	_expect(background.mouse_filter == Control.MOUSE_FILTER_STOP, "reopened background captures input")
	_expect(card.get_node("Content/ResumeButton").get_mouse_filter_with_override() == Control.MOUSE_FILTER_STOP, "reopened button accepts input")
	_expect(main.hud.get_node("MarginContainer/Rows").visible, "pause keeps HUD stats")
	main._show_settings_from_pause()
	_expect(not overlay.visible and main._settings_menu.visible and paused, "pause settings replaces overlay")
	main._hide_settings()
	_expect(main._is_open(overlay) and paused, "immediate settings back restores pause")
	await create_timer(0.4).timeout
	_expect(not main._settings_menu.visible and overlay.visible, "pause settings fade completes")
	_expect(main._menu_backdrop == null and main._main_menu == null, "pause settings does not open main menu")
	main._resume_game()
	await create_timer(0.3).timeout
	_expect(not paused and not overlay.visible, "resume fade ends unpaused and hidden")
	_expect(card.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(card.modulate.a, 1.0), "closed overlay reset")


func _check_feedback(main: Node) -> void:
	var coin := main.hud.get_node("MarginContainer/Rows/CoinRow/CoinIcon") as Control
	_expect(not coin.has_meta(&"ui_fx_bounce"), "run start does not bounce coins")
	main._on_run_coins_changed(0)
	_expect(not coin.has_meta(&"ui_fx_bounce"), "zero coins do not bounce")
	for tree_paused in [false, true]:
		paused = tree_paused
		main._on_run_coins_changed(1)
		await create_timer(0.06).timeout
		_expect(coin.scale.x > 1.0, "pickup coin bounce paused=%s" % tree_paused)
		main._on_run_coins_changed(2)
		await create_timer(0.4).timeout
		_expect(coin.scale.is_equal_approx(Vector2.ONE), "repeated coin bounce settles")
		UiFx.open_screen(main._pause_overlay)
		await create_timer(0.3).timeout
		var button := main._pause_overlay.get_node("%Card/Content/ResumeButton") as Button
		UiFx.wire_press_fx(main._pause_overlay)
		var down_connections := button.button_down.get_connections().size()
		UiFx.wire_press_fx(main._pause_overlay)
		_expect(button.button_down.get_connections().size() == down_connections, "press wiring is idempotent")
		button.button_down.emit()
		await create_timer(0.08).timeout
		_expect(button.scale.x < 1.0, "button squashes paused=%s" % tree_paused)
		button.button_up.emit()
		button.button_down.emit()
		button.button_up.emit()
		await create_timer(0.3).timeout
		_expect(button.scale.is_equal_approx(Vector2.ONE), "fast button taps settle")
		button.button_down.emit()
		UiFx.hide_now(main._pause_overlay)
		await create_timer(0.1).timeout
		_expect(button.scale.is_equal_approx(Vector2.ONE), "hide cancels held press")
		var fire: Button = main.hud.fire_button
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		main.hud.set_fire_cooldown(false)
		fire._gui_input(touch)
		await create_timer(0.06).timeout
		_expect(fire.scale.x > 1.0, "fire input bounces paused=%s" % tree_paused)
		main.hud.set_fire_cooldown(true)
		await create_timer(0.4).timeout
		_expect(fire.scale.is_equal_approx(Vector2.ONE), "fire bounce settles")
		_expect(is_equal_approx(fire.self_modulate.a, 0.45), "bounce preserves cooldown dim")
		fire._gui_input(touch)
		await create_timer(0.06).timeout
		_expect(fire.scale.is_equal_approx(Vector2.ONE), "cooldown fire input does not bounce")
	paused = false


func _check_numbers(main: Node) -> void:
	var screen: CanvasLayer = main._game_over_screen
	var badge := screen.get_node("%Card/Content/BadgeHolder/NewBestBadge") as Control
	var score := screen.get_node("%Card/Content/ScoreLabel") as Label
	var coins := screen.get_node("%Card/Content/CoinsRow/CoinsLabel") as Label
	for tree_paused in [false, true]:
		paused = tree_paused
		screen.show_screen(1234, 1234, 7, true)
		_expect(not badge.visible and score.text == "Altitude: 0", "fresh count starts hidden and zero")
		_expect(not screen.get_node("%Card/Content/RetryButton").disabled, "retry usable during count")
		_expect(not screen.get_node("%Card/Content/MenuButton").disabled, "menu usable during count")
		await create_timer(0.5).timeout
		_expect(score.text != "Altitude: 0" and score.text != "Altitude: 1234", "score counts after pop")
		_expect(coins.text == "Coins this run: 0" and not badge.visible, "coins and badge wait for score")
		await create_timer(1.5).timeout
		_expect(score.text == "Altitude: 1234" and coins.text == "Coins this run: 7", "counts finish paused=%s" % tree_paused)
		_expect(badge.visible and badge.scale.is_equal_approx(Vector2.ONE), "new best badge pops")
		screen.show_screen(88, 1234, 2, false)
		_expect(not badge.visible, "non-record hides badge immediately")
		await create_timer(0.45).timeout
		screen.show_screen(42, 1234, 1, false)
		await create_timer(2.0).timeout
		_expect(score.text == "Altitude: 42" and coins.text == "Coins this run: 1" and not badge.visible, "reshow cancels stale counts")
		screen.show_screen(9999, 9999, 99, true)
		await create_timer(0.4).timeout
		UiFx.hide_now(screen)
		var stopped_text := score.text
		await create_timer(1.2).timeout
		_expect(not screen.visible and not badge.visible and score.text == stopped_text, "hide cancels count and pending badge")
	paused = false
	# Saving can fail after the in-memory record changes; the badge still celebrates it.
	var saved_store: Node = main.profile_store
	var unsaved := UnsavedProfile.new()
	main.add_child(unsaved)
	main.profile_store = unsaved
	main._on_game_over(1234)
	_expect(main.hud.get_node("MarginContainer/Rows").visible, "game over keeps HUD stats")
	await create_timer(1.5).timeout
	_expect(badge.visible, "new best uses previous record even when saving returns false")
	main._on_game_over(1234)
	await create_timer(1.5).timeout
	_expect(not badge.visible, "tied record does not show new best")
	main._on_game_over(1000)
	await create_timer(1.5).timeout
	_expect(not badge.visible, "lower score does not show new best")
	main.profile_store = saved_store
	unsaved.free()
