extends Node2D

## Composes the M1 systems and owns the small amount of cross-system wiring.

@export var run_seed := 13_371_337

@onready var run_session = $RunSession
@onready var profile_store = $ProfileStore
@onready var platform_manager = $World/PlatformManager
@onready var player = $World/Player
@onready var camera: Camera2D = $World/Camera2D
@onready var hud = $HUD

var _highest_camera_y := 960.0


func _ready() -> void:
	run_session.score_changed.connect(_on_score_changed)
	run_session.game_over.connect(_on_game_over)
	profile_store.high_score_changed.connect(hud.set_high_score)

	_highest_camera_y = camera.position.y
	run_session.start_new_run(run_seed, player.global_position.y)
	platform_manager.initialize(
		run_session.rng,
		Vector2(540.0, 1740.0),
		player.JUMP_VELOCITY,
		player.GRAVITY,
		player.MOVE_SPEED
	)
	hud.set_score(0)
	hud.set_high_score(profile_store.high_score)
	player.start_movement()


func _physics_process(_delta: float) -> void:
	if run_session.state != run_session.RunState.PLAYING:
		return

	run_session.update_player_altitude(player.global_position.y)
	_follow_player_upward()
	platform_manager.update_for_camera(camera.position.y)

	var camera_bottom := camera.position.y + get_viewport_rect().size.y * 0.5
	if player.global_position.y > camera_bottom:
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
	profile_store.update_high_score(final_score)
	hud.set_high_score(profile_store.high_score)
	hud.show_game_over(final_score)

