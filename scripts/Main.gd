extends Node2D

## Routes top-level screens and composes a fresh gameplay world for each run.

const MAIN_MENU_SCENE := preload("res://scenes/MainMenu.tscn")
const GAME_OVER_SCREEN_SCENE := preload("res://scenes/GameOverScreen.tscn")
const SETTINGS_MENU_SCENE := preload("res://scenes/SettingsMenu.tscn")
const PAUSE_OVERLAY_SCENE := preload("res://scenes/PauseOverlay.tscn")
const SHOP_SCREEN_SCENE := preload("res://scenes/ShopScreen.tscn")

@export var run_seed := 0
@export var world_scene: PackedScene

@onready var run_session = $RunSession
@onready var profile_store = $ProfileStore
@onready var audio_manager: AudioManager = $AudioManager
@onready var hud = $HUD

var _main_menu: CanvasLayer
var _game_over_screen: CanvasLayer
var _settings_menu: CanvasLayer
var _pause_overlay: CanvasLayer
var _shop_screen: CanvasLayer
var _settings_return_to_pause := false

var _current_world: Node2D
var _platform_manager
var _coin_manager
var _enemy_manager
var _player
var _camera: Camera2D
var _rising_fire

## Camera auto-scroll speeds (px/s) once the fire is active; scaled by difficulty.
@export var auto_scroll_min := 30.0
@export var auto_scroll_max := 120.0

var _highest_camera_y := 0.0
var _last_difficulty_factor := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	audio_manager.initialize(profile_store)
	run_session.score_changed.connect(_on_score_changed)
	run_session.game_over.connect(_on_game_over)
	profile_store.high_score_changed.connect(hud.set_high_score)
	profile_store.coins_changed.connect(hud.set_coins)
	run_session.run_coins_changed.connect(_on_run_coins_changed)
	hud.fire_requested.connect(_on_fire_requested)
	hud.pause_requested.connect(_pause_game)

	_create_persistent_overlays()
	_show_main_menu()
	hud.hide_gameplay_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_cleanly()


## Stops audio and lets the audio server drop its playbacks before quitting,
## so the music stream is not still referenced at shutdown.
func _quit_cleanly() -> void:
	audio_manager.stop_all_audio()
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit()


func _on_run_coins_changed(amount: int) -> void:
	hud.set_coins(profile_store.total_coins + amount)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if event.keycode != KEY_ESCAPE or not event.pressed or event.echo:
		return
	if is_instance_valid(_shop_screen) and _shop_screen.visible:
		_hide_shop()
		get_viewport().set_input_as_handled()
		return

	if is_instance_valid(_settings_menu) and _settings_menu.visible:
		_hide_settings()
		get_viewport().set_input_as_handled()
		return

	if run_session.state == run_session.RunState.PLAYING:
		_pause_game()
	elif run_session.state == run_session.RunState.PAUSED:
		_resume_game()
	else:
		return
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _current_world == null or not is_instance_valid(_current_world):
		return
	if run_session.state != run_session.RunState.PLAYING:
		return

	run_session.update_player_altitude(_player.global_position.y)
	var difficulty_factor: float = run_session.get_difficulty_factor()
	var reached_new_endpoint := (
		difficulty_factor != _last_difficulty_factor
		and difficulty_factor in [0.0, 1.0]
	)
	if (
		reached_new_endpoint
		or absf(difficulty_factor - _last_difficulty_factor) >= 0.01
	):
		_platform_manager.update_difficulty(difficulty_factor)
		_enemy_manager.update_difficulty(difficulty_factor)
		_coin_manager.update_difficulty(difficulty_factor)
		_rising_fire.set_difficulty(difficulty_factor)
		_last_difficulty_factor = difficulty_factor
	_follow_player_upward(delta)
	_platform_manager.update_for_camera(_camera.position.y)
	_enemy_manager.update_for_camera(_camera.position.y)
	_coin_manager.update_for_camera(_camera.position.y)


func _create_persistent_overlays() -> void:
	_settings_menu = SETTINGS_MENU_SCENE.instantiate() as CanvasLayer
	add_child(_settings_menu)
	_settings_menu.call("set_audio_manager", audio_manager)
	_settings_menu.connect("back_requested", _hide_settings)
	_settings_menu.visible = false

	_game_over_screen = GAME_OVER_SCREEN_SCENE.instantiate() as CanvasLayer
	add_child(_game_over_screen)
	_game_over_screen.call("set_audio_manager", audio_manager)
	_game_over_screen.connect("retry_requested", _retry)
	_game_over_screen.connect("menu_requested", _quit_to_menu)
	_game_over_screen.visible = false

	_pause_overlay = PAUSE_OVERLAY_SCENE.instantiate() as CanvasLayer
	add_child(_pause_overlay)
	_pause_overlay.call("set_audio_manager", audio_manager)
	_pause_overlay.connect("resume_requested", _resume_game)
	_pause_overlay.connect("settings_requested", _show_settings_from_pause)
	_pause_overlay.connect("quit_to_menu_requested", _quit_to_menu)
	_pause_overlay.visible = false

	_shop_screen = SHOP_SCREEN_SCENE.instantiate() as CanvasLayer
	add_child(_shop_screen)
	_shop_screen.call("set_audio_manager", audio_manager)
	_shop_screen.connect("back_requested", _hide_shop)
	_shop_screen.connect("purchase_made", _on_shop_purchase_made)
	_shop_screen.visible = false


func _ensure_main_menu() -> void:
	if is_instance_valid(_main_menu):
		return
	_main_menu = MAIN_MENU_SCENE.instantiate() as CanvasLayer
	add_child(_main_menu)
	_main_menu.call("set_audio_manager", audio_manager)
	_main_menu.connect("play_requested", _start_game)
	_main_menu.connect("settings_requested", _show_settings)
	_main_menu.connect("shop_requested", _show_shop)


func _show_main_menu() -> void:
	_ensure_main_menu()
	_main_menu.call("refresh", profile_store)
	_main_menu.visible = true


func _start_game() -> void:
	if world_scene == null:
		push_error("Main requires a World PackedScene.")
		return
	if is_instance_valid(_current_world):
		return

	if is_instance_valid(_main_menu):
		_main_menu.visible = false
		_main_menu.queue_free()
		_main_menu = null
	_settings_menu.visible = false
	_game_over_screen.visible = false
	_pause_overlay.visible = false
	_shop_screen.visible = false
	get_tree().paused = false

	_current_world = world_scene.instantiate() as Node2D
	if _current_world == null:
		push_error("World scene root must be a Node2D.")
		_show_main_menu()
		return
	add_child(_current_world)
	_current_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	_setup_world()


func _setup_world() -> void:
	_platform_manager = _current_world.get_node("PlatformManager")
	_coin_manager = _current_world.get_node("CoinManager")
	_enemy_manager = _current_world.get_node("EnemyManager")
	_player = _current_world.get_node("Player")
	_camera = _current_world.get_node("Camera2D") as Camera2D
	# Preserve the start-of-run world bottom at 1920 on every aspect ratio.
	_camera.position.y = ScreenLayout.BASE_HEIGHT - ScreenLayout.half_height()
	_highest_camera_y = _camera.position.y
	_rising_fire = _current_world.get_node("RisingFire")
	_rising_fire.player_burned.connect(run_session.end_run)
	var jump_height: float = _player.JUMP_VELOCITY * _player.JUMP_VELOCITY / (2.0 * _player.GRAVITY)
	_rising_fire.setup(_camera, _player, 1722.0, jump_height)

	_coin_manager.coin_collected.connect(_on_coin_collected)
	_enemy_manager.enemy_destroyed.connect(_coin_manager._on_enemy_destroyed)
	_enemy_manager.enemy_destroyed.connect(_on_enemy_destroyed)
	_player.ability_controller.cooldown_changed.connect(hud.set_fire_cooldown)
	_player.ability_controller.cooldown_changed.connect(_on_fire_cooldown_changed)
	_player.configure_abilities(
		profile_store.is_double_jump_unlocked(),
		profile_store.is_glide_unlocked(),
		profile_store.get_fire_breath_level()
	)

	_last_difficulty_factor = -1.0
	_player.initialize_abilities(_current_world, _enemy_manager, _camera)
	var actual_seed := run_seed if run_seed != 0 else randi()
	run_session.start_new_run(actual_seed, _player.global_position.y)
	_coin_manager.initialize(
		_player,
		_camera,
		run_session.rng_seed,
		_platform_manager
	)
	_enemy_manager.initialize(run_session, _platform_manager, _player)
	_platform_manager.initialize(
		run_session.rng,
		Vector2(540.0, 1740.0),
		_player.JUMP_VELOCITY,
		_player.GRAVITY,
		_player.MOVE_SPEED
	)

	hud.set_score(0)
	hud.set_high_score(profile_store.high_score)
	hud.set_coins(profile_store.total_coins)
	hud.show_playing()
	_player.start_movement()


func _pause_game() -> void:
	if not run_session.pause_run():
		return
	hud.hide_gameplay_ui()
	get_tree().paused = true
	audio_manager.duck_music()
	_pause_overlay.visible = true


func _resume_game() -> void:
	if run_session.state != run_session.RunState.PAUSED:
		return
	get_tree().paused = false
	audio_manager.unduck_music()
	run_session.resume_run()
	_pause_overlay.visible = false
	hud.show_playing()


func _retry() -> void:
	audio_manager.restart_music()
	_game_over_screen.visible = false
	_free_current_world()
	_start_game()


func _quit_to_menu() -> void:
	get_tree().paused = false
	audio_manager.restart_music()
	_free_current_world()
	run_session.state = run_session.RunState.READY
	hud.hide_gameplay_ui()
	_game_over_screen.visible = false
	_pause_overlay.visible = false
	_settings_menu.visible = false
	_shop_screen.visible = false
	_show_main_menu()


func _show_settings() -> void:
	if run_session.state != run_session.RunState.READY:
		return
	_settings_return_to_pause = false
	_settings_menu.call("open", profile_store)


func _show_settings_from_pause() -> void:
	_settings_return_to_pause = true
	_pause_overlay.visible = false
	_settings_menu.call("open", profile_store)


func _hide_settings() -> void:
	_settings_menu.visible = false
	if _settings_return_to_pause:
		_settings_return_to_pause = false
		_pause_overlay.visible = true


func _show_shop() -> void:
	if run_session.state != run_session.RunState.READY:
		return
	if not is_instance_valid(_main_menu) or not _main_menu.visible:
		return
	if (
		_settings_menu.visible
		or _pause_overlay.visible
		or _game_over_screen.visible
		or _shop_screen.visible
	):
		return

	_main_menu.visible = false
	_shop_screen.call("open", profile_store)
	_shop_screen.visible = true
	_shop_screen.call("grab_focus_on_first_button")


func _hide_shop() -> void:
	if not is_instance_valid(_shop_screen) or not _shop_screen.visible:
		return
	_shop_screen.visible = false
	_show_main_menu()


func _on_shop_purchase_made() -> void:
	hud.set_coins(profile_store.total_coins)
	if is_instance_valid(_main_menu):
		_main_menu.call("refresh", profile_store)


func _free_current_world() -> void:
	if is_instance_valid(_current_world):
		remove_child(_current_world)
		_current_world.queue_free()
	_current_world = null
	_platform_manager = null
	_coin_manager = null
	_enemy_manager = null
	_player = null
	_camera = null
	_rising_fire = null


func _follow_player_upward(delta: float) -> void:
	if _rising_fire.is_active():
		var scroll_speed := lerpf(auto_scroll_min, auto_scroll_max, run_session.get_difficulty_factor())
		_highest_camera_y -= scroll_speed * delta
		_camera.position.y = _highest_camera_y
	if _player.global_position.y < _highest_camera_y:
		_highest_camera_y = _player.global_position.y
		_camera.position.y = _highest_camera_y


func _on_score_changed(new_score: int) -> void:
	hud.set_score(new_score)
	hud.set_high_score(maxi(profile_store.high_score, new_score))


func _on_game_over(final_score: int) -> void:
	audio_manager.play_sfx(&"sfx_death")
	if is_instance_valid(_camera):
		_camera.call("start_shake")
	get_tree().paused = false
	if is_instance_valid(_player):
		_player.stop_movement()
	if is_instance_valid(_rising_fire):
		_rising_fire.stop()
	if is_instance_valid(_enemy_manager):
		_enemy_manager.set_active(false)
	if is_instance_valid(_coin_manager):
		_coin_manager.set_active(false)
	profile_store.update_high_score(final_score)
	profile_store.add_coins(run_session.run_coins)
	hud.hide_gameplay_ui()
	_game_over_screen.call(
		"show_screen",
		final_score,
		profile_store.high_score,
		run_session.run_coins
	)


func _on_coin_collected() -> void:
	audio_manager.play_sfx(&"sfx_coin")
	run_session.add_run_coin()


func _on_enemy_destroyed(_enemy_position: Vector2) -> void:
	audio_manager.play_sfx(&"sfx_enemy_destroyed")


func _on_fire_cooldown_changed(is_on_cooldown: bool) -> void:
	if is_on_cooldown:
		audio_manager.play_sfx(&"sfx_fire")


func _on_fire_requested() -> void:
	if run_session.state != run_session.RunState.PLAYING:
		return
	if is_instance_valid(_player):
		_player.request_fire()
