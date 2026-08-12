extends Node2D

## Composes the M1 systems and owns the small amount of cross-system wiring.

@export var run_seed := 13_371_337

@onready var run_session = $RunSession
@onready var profile_store = $ProfileStore
@onready var platform_manager = $World/PlatformManager
@onready var coin_manager = $World/CoinManager
@onready var enemy_manager = $World/EnemyManager
@onready var player = $World/Player
@onready var world: Node2D = $World
@onready var camera: Camera2D = $World/Camera2D
@onready var hud = $HUD

var _highest_camera_y := 960.0
var _last_difficulty_factor := -1.0


func _ready() -> void:
	_last_difficulty_factor = -1.0
	run_session.score_changed.connect(_on_score_changed)
	run_session.game_over.connect(_on_game_over)
	profile_store.high_score_changed.connect(hud.set_high_score)
	profile_store.coins_changed.connect(hud.set_coins)
	coin_manager.coin_collected.connect(_on_coin_collected)
	enemy_manager.enemy_destroyed.connect(coin_manager._on_enemy_destroyed)
	hud.fire_requested.connect(player.request_fire)
	player.ability_controller.cooldown_changed.connect(hud.set_fire_cooldown)

	_highest_camera_y = camera.position.y
	player.initialize_abilities(world, enemy_manager, camera)
	run_session.start_new_run(run_seed, player.global_position.y)
	coin_manager.initialize(player, camera, run_session.rng_seed, platform_manager)
	enemy_manager.initialize(run_session, platform_manager, player)
	platform_manager.initialize(
		run_session.rng,
		Vector2(540.0, 1740.0),
		player.JUMP_VELOCITY,
		player.GRAVITY,
		player.MOVE_SPEED
	)
	hud.set_score(0)
	hud.set_high_score(profile_store.high_score)
	hud.set_coins(profile_store.total_coins)
	hud.show_playing()
	player.start_movement()


func _physics_process(_delta: float) -> void:
	if run_session.state != run_session.RunState.PLAYING:
		return

	run_session.update_player_altitude(player.global_position.y)
	var difficulty_factor: float = run_session.get_difficulty_factor()
	var reached_new_endpoint := (
		difficulty_factor != _last_difficulty_factor
		and difficulty_factor in [0.0, 1.0]
	)
	if (
		reached_new_endpoint
		or absf(difficulty_factor - _last_difficulty_factor) >= 0.01
	):
		platform_manager.update_difficulty(difficulty_factor)
		enemy_manager.update_difficulty(difficulty_factor)
		coin_manager.update_difficulty(difficulty_factor)
		_last_difficulty_factor = difficulty_factor
	_follow_player_upward()
	platform_manager.update_for_camera(camera.position.y)
	enemy_manager.update_for_camera(camera.position.y)
	coin_manager.update_for_camera(camera.position.y)

	var camera_bottom := camera.position.y + get_viewport_rect().size.y * 0.5
	# Tighter death line: 35% of screen below camera center.
	# This prevents the player from getting stuck on a low platform after
	# falling through a breakable/disappearing platform.
	var death_line := camera_bottom + get_viewport_rect().size.y * 0.35
	if player.global_position.y > death_line:
		run_session.end_run()


func _follow_player_upward() -> void:
	if player.global_position.y < _highest_camera_y:
		_highest_camera_y = player.global_position.y
		camera.position.y = _highest_camera_y


func _on_score_changed(new_score: int) -> void:
	hud.set_score(new_score)
	hud.set_high_score(maxi(profile_store.high_score, new_score))


func _on_game_over(final_score: int) -> void:
	player.stop_movement()
	enemy_manager.set_active(false)
	coin_manager.set_active(false)
	profile_store.update_high_score(final_score)
	hud.set_high_score(profile_store.high_score)
	hud.show_game_over(final_score)


func _on_coin_collected() -> void:
	profile_store.add_coins(1)
