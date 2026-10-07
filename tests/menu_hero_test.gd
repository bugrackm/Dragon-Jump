extends SceneTree

## Real routing plus deterministic pose sampling catches interrupted entrances and drift.
const UiFx := preload("res://scripts/ui/UiFx.gd")
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
	root.content_scale_size = Vector2i(1080, 1920)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
	root.size = Vector2i(1080, 1920)
	await process_frame
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	main.audio_manager.stop_all_audio()
	var hero: Node = main._main_menu.get_node("HeroAnimator")
	var backdrop: Node = main._menu_backdrop
	_expect(paused, "menu pauses tree")
	_expect(hero.logo.texture == load("res://assets/ui/menu/menu_logo.png"), "logo texture loads")
	var sprite := main._main_menu.find_child("MenuDragon", true, false) as Sprite2D
	_expect(sprite != null and sprite.texture == load("res://assets/ui/menu/menu_dragon.png"), "single dragon texture loads")
	_expect(main._main_menu.find_child("TitleLabel", true, false) == null, "old title removed")
	_expect(main._main_menu.find_children("*", "AnimatedSprite2D", true, false).is_empty(), "no frame animation in menu")
	_expect(hero.entrance_running and hero.logo_motion.position.y < 0, "boot starts drop entrance")
	_expect(not hero.sparkles.visible, "sparkles wait for landing")
	hero.set_process(false)
	await process_frame
	await process_frame
	var initial_y: float = hero.logo_motion.position.y
	await create_timer(0.15).timeout
	_expect(hero.logo_motion.position.y > initial_y and paused, "entrance advances while paused")
	await create_timer(1.0).timeout
	_expect(not hero.entrance_running and hero.logo_motion.transform.is_equal_approx(Transform2D.IDENTITY), "entrance ends at exact rest transform")
	_expect(hero.sparkles.visible and hero.sparkles._stars.size() == 4, "drawn sparkle node and four stars visible after landing")
	hero.set_process(true)
	var before: float = hero._elapsed
	var dragon_before: Transform2D = hero.dragon.transform
	var island := backdrop.get_node("Atmosphere/FarIsland") as Sprite2D
	var island_before := island.position
	await create_timer(0.2).timeout
	_expect(hero._elapsed > before and not hero.dragon.transform.is_equal_approx(dragon_before), "hero idle advances paused")
	_expect(island.position != island_before, "islands drift paused")
	_expect(hero.sparkles._reveal > 0.0 and hero.sparkles._elapsed > 0.0, "sparkles pop and twinkle paused")
	hero._elapsed = 4.25
	hero._process(0.0)
	var sweep: float = hero.logo.material.get_shader_parameter("sweep")
	_expect(sweep > 0.0 and sweep < 1.0, "shine crosses logo during 0.6 second sweep")
	hero._elapsed = 4.7
	hero._process(0.0)
	_expect(hero.logo.material.get_shader_parameter("sweep") == -1.0, "shine rests between sweeps")
	_check_dragon(hero.dragon, sprite)
	_check_atmosphere(backdrop, hero.card)

	for route in ["shop", "settings"]:
		main.call("_show_" + route)
		_expect(not hero.is_processing() and not hero.dragon.is_processing(), "hidden hero stops clocks for " + route)
		var stopped: float = hero._elapsed
		await create_timer(0.1).timeout
		_expect(hero._elapsed == stopped, "hidden hero does no per-frame work")
		main.call("_hide_" + route)
		_expect(not hero.entrance_running and hero.logo_motion.transform.is_equal_approx(Transform2D.IDENTITY), route + " return rests without replay")
		_expect(main._menu_backdrop == backdrop, route + " preserves atmosphere")
		await create_timer(0.15).timeout
		_expect(hero.is_processing() and hero.dragon.is_processing(), route + " return resumes idle")

	var particles := backdrop.get_node("Atmosphere/Embers")
	var old_hero: WeakRef = weakref(hero)
	var old_island: WeakRef = weakref(island)
	var old_particles: WeakRef = weakref(particles)
	main._start_game()
	_expect(not paused and not is_instance_valid(backdrop), "start unpauses and frees backdrop")
	_expect(not hero.is_processing() and not hero.dragon.is_processing(), "start immediately stops hero clocks")
	_expect(not hero.has_meta(&"ui_fx_entrance"), "start cancels entrance tween")
	main.set_physics_process(false)
	main._current_world.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	_expect(old_hero.get_ref() == null and old_island.get_ref() == null and old_particles.get_ref() == null, "all hero and atmosphere nodes freed during gameplay")
	main._pause_game()
	main._pause_overlay.get_node("%Card/Content/QuitButton").pressed.emit()
	hero = main._main_menu.get_node("HeroAnimator")
	_expect(hero.entrance_running and hero.logo_motion.position.y < 0, "pause Home replays entrance")
	await create_timer(0.1).timeout
	main._show_shop()
	main._hide_shop()
	_expect(not hero.entrance_running and hero.logo_motion.transform.is_equal_approx(Transform2D.IDENTITY), "interrupted entrance returns at rest")
	await create_timer(1.0).timeout
	_expect(absf(hero.logo_motion.position.y) <= 3.0 and hero.sparkles.visible, "no stale entrance moves reopened logo")
	main._start_game()
	main.set_physics_process(false)
	main._current_world.process_mode = Node.PROCESS_MODE_DISABLED
	main._game_over_screen.show_screen(0, 0, 0, false)
	main._game_over_screen.get_node("%Card/Content/MenuButton").pressed.emit()
	hero = main._main_menu.get_node("HeroAnimator")
	_expect(hero.entrance_running, "game-over Home replays entrance")
	main._show_settings()
	main._hide_settings()
	_expect(not hero.entrance_running and hero.logo_motion.transform.is_equal_approx(Transform2D.IDENTITY), "Settings also cancels interrupted entrance")
	main._start_game()
	main._quit_to_menu()
	hero = main._main_menu.get_node("HeroAnimator")
	_expect(hero.entrance_running, "fresh menu starts entrance before repeated open")
	main._show_main_menu()
	_expect(not hero.entrance_running and hero.logo_motion.transform.is_equal_approx(Transform2D.IDENTITY), "repeated open during entrance settles at rest")
	main.audio_manager.stop_all_audio()
	await create_timer(0.3, true, false, true).timeout
	main.free()
	paused = false
	await process_frame
	print("menu_hero_checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)


func _check_dragon(dragon: Node2D, sprite: Sprite2D) -> void:
	dragon.apply_pose(0.0)
	var base := dragon.transform
	var hop_base: Transform2D = dragon.hop.transform
	dragon.apply_hop(0.16)
	_expect(dragon.hop.scale.x > 1.0 and dragon.hop.scale.y < 1.0, "hop anticipates with squash")
	dragon.apply_hop(0.48)
	_expect(is_equal_approx(dragon.hop.position.y, -60.0) and dragon.hop.scale.y > 1.0, "hop rises sixty pixels with stretch")
	dragon.apply_hop(0.80)
	_expect(dragon.hop.position == Vector2.ZERO and dragon.hop.scale.y < 1.0, "hop lands with small squash")
	dragon.apply_pose(4.0)
	_expect(dragon.hop.transform.is_equal_approx(hop_base), "full hop cycle returns exactly to base")
	var bounded := true
	var reset := true
	dragon._elapsed = 0.0
	for frame in 24960:
		dragon._process(1.0 / 60.0)
		bounded = bounded and absf(dragon.position.x) <= 20.001 and absf(dragon.position.y) <= 14.001
		bounded = bounded and absf(dragon.rotation) <= deg_to_rad(4.001) and dragon.scale.x >= 0.9749 and dragon.scale.x <= 1.0251
		if (frame + 1) % 240 == 0:
			reset = reset and dragon.hop.transform.is_equal_approx(hop_base)
	_expect(bounded and reset and not sprite.flip_h, "416 simulated seconds remain bounded; every hop resets without flipping")
	_expect(dragon.transform.is_equal_approx(base) and dragon.hop.transform.is_equal_approx(hop_base), "all independent periods return to base after 416 seconds")


func _check_atmosphere(backdrop: Node, card: Control) -> void:
	var far := backdrop.get_node("Atmosphere/FarIsland") as Sprite2D
	var near := backdrop.get_node("Atmosphere/NearIsland") as Sprite2D
	_expect(far.texture != null and near.texture != null and far.texture != near.texture, "two existing island textures load")
	_expect(far.scale.x < near.scale.x and far.modulate.a < near.modulate.a, "far island smaller and hazier")
	var glow := backdrop.get_node("Atmosphere/FireGlow") as TextureRect
	_expect(is_equal_approx(glow.position.y, 1920.0 * 0.74) and is_equal_approx(glow.size.y, 1920.0 * 0.26), "glow occupies bottom 26 percent")
	_expect(glow.texture.gradient.get_color(0).a == 0.0, "glow fades to transparent")
	var embers := backdrop.get_node("Atmosphere/Embers") as CPUParticles2D
	_expect(embers.emitting and embers.can_process() and paused, "CPU embers run paused")
	_expect(embers.color_ramp.get_color(3).a == 0.0, "embers fade completely")
	_expect(embers.process_mode == Node.PROCESS_MODE_ALWAYS and embers.amount >= 40, "full-width ember emitter always processes")
	_expect(is_equal_approx(embers.emission_rect_extents.x * 2.0, 1080.0), "ember emitter spans full width")
