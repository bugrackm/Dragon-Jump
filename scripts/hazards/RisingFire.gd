extends Node2D

## World-space pressure from below; camera position is read-only.
signal player_burned

enum SpeedModel { RUBBER_BAND, CONSTANT, SCREEN_BAND }

@export var speed_model: SpeedModel = SpeedModel.SCREEN_BAND
@export var rise_speed_min := 90.0
@export var rise_speed_max := 170.0
@export var leash_below_screen := 40.0
## SCREEN_BAND: how far the fire top sits above the screen bottom (world units).
@export var visible_band := 70.0
@export var kill_inset := 24.0
@export var activation_margin := 40.0

var fire_top_y := 2340.0
var _camera: Camera2D
var _player: Node2D
var _activation_y := 0.0
var _difficulty := 0.0
var _active := false
var _stopped := true

@onready var _flames: CPUParticles2D = $Flames


func setup(camera: Camera2D, player: Node2D, ground_top_y: float, jump_height: float) -> void:
	_camera = camera
	_player = player
	_activation_y = ground_top_y - (jump_height + activation_margin)
	fire_top_y = maxf(ground_top_y + 600.0, ScreenLayout.visible_bottom(_camera.position.y) + leash_below_screen)
	global_position.y = fire_top_y
	_difficulty = 0.0
	_active = false
	_stopped = false
	visible = false
	_flames.emitting = false
	set_physics_process(true)


func set_difficulty(factor: float) -> void:
	_difficulty = clampf(factor, 0.0, 1.0)


func is_active() -> bool:
	return _active


func stop() -> void:
	_stopped = true
	_active = false
	_flames.emitting = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if _stopped or not is_instance_valid(_camera) or not is_instance_valid(_player):
		return
	var camera_bottom := ScreenLayout.visible_bottom(_camera.position.y)
	if not _active:
		if _player.global_position.y >= _activation_y:
			return
		_active = true
		fire_top_y = camera_bottom + leash_below_screen
		visible = true
		_flames.emitting = true

	fire_top_y -= lerpf(rise_speed_min, rise_speed_max, _difficulty) * delta
	if speed_model == SpeedModel.SCREEN_BAND:
		fire_top_y = maxf(fire_top_y, camera_bottom - visible_band)
	if speed_model != SpeedModel.CONSTANT:
		fire_top_y = minf(fire_top_y, camera_bottom + leash_below_screen)
	global_position.y = fire_top_y
	if _player.global_position.y > fire_top_y + kill_inset:
		stop()
		player_burned.emit()
