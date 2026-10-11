extends CharacterBody2D

## Dragon controller: automatic jumping, steering, double jump, and glide.

const GRAVITY := 2400.0
const JUMP_VELOCITY := -1150.0
const MOVE_SPEED := 520.0
const DOUBLE_JUMP_COOLDOWN := 1.0
const GAME_WIDTH := preload("res://scripts/ScreenLayout.gd").GAME_WIDTH
const JUMP_DUST_SCENE := preload("res://scenes/effects/JumpDust.tscn")
const FLAP_PUFF_SCENE := preload("res://scenes/effects/FlapPuff.tscn")

@onready var input_controller := $InputController
@onready var ability_controller := $AbilityController
@onready var animation_controller := $AnimationController
@onready var glide_trail: CPUParticles2D = $GlideTrail
@onready var mouth_flame: CPUParticles2D = $MouthFlame

var active := false
var double_jump_enabled := false
var glide_enabled := false
var _can_double_jump := true
var _double_jump_cooldown_left := 0.0
var _glide_sound_active := false


func _ready() -> void:
	ability_controller.cooldown_changed.connect(_on_fire_cooldown_changed)


func _physics_process(delta: float) -> void:
	if not active:
		velocity = Vector2.ZERO
		return

	var keyboard_direction := Input.get_axis("ui_left", "ui_right")
	var horizontal_input := clampf(
		keyboard_direction + float(input_controller.get("horizontal_direction")),
		-1.0,
		1.0
	)
	velocity.x = horizontal_input * MOVE_SPEED

	var on_floor_before_move := is_on_floor()
	if on_floor_before_move:
		_can_double_jump = true

	if _double_jump_cooldown_left > 0.0:
		_double_jump_cooldown_left = maxf(0.0, _double_jump_cooldown_left - delta)

	var double_jump_requested := bool(input_controller.call("consume_double_jump_request"))
	var double_jump_just_triggered := false
	var can_double_jump := (
		double_jump_enabled
		and _can_double_jump
		and _double_jump_cooldown_left <= 0.0
	)
	var is_gliding := (
		glide_enabled
		and bool(input_controller.get("glide_active"))
		and not on_floor_before_move
		and velocity.y > 0.0
	)
	var current_gravity := GRAVITY * 0.25 if is_gliding else GRAVITY
	velocity.y += current_gravity * delta
	if double_jump_requested and not on_floor_before_move and can_double_jump:
		velocity.y = JUMP_VELOCITY
		_can_double_jump = false
		_double_jump_cooldown_left = DOUBLE_JUMP_COOLDOWN
		double_jump_just_triggered = true
	var was_descending := velocity.y >= 0.0

	move_and_slide()

	# One-way platform contacts become floors only while the player is descending.
	if was_descending and is_on_floor():
		_apply_platform_landing()
		_can_double_jump = true
		input_controller.call("cancel_glide_on_landing")

	_wrap_around_screen()
	if double_jump_just_triggered:
		_spawn_flap_puff()
		animation_controller.call("trigger_double_jump")
		_play_sfx(&"sfx_double_jump")
	var animation_is_gliding := (
		glide_enabled
		and bool(input_controller.get("glide_active"))
		and not is_on_floor()
		and velocity.y > 0.0
	)
	glide_trail.emitting = animation_is_gliding
	if glide_trail.emitting:
		var flow := velocity
		if flow.length() > 1.0:
			glide_trail.direction = -flow.normalized()
			var flow_angle := rad_to_deg(flow.angle())
			glide_trail.angle_min = flow_angle
			glide_trail.angle_max = flow_angle
	_set_glide_sound_active(animation_is_gliding)
	animation_controller.call("update_animation", animation_is_gliding)


func apply_skin(skin: Resource) -> void:
	$VisualRoot.apply_skin(skin)


func configure_abilities(double_jump: bool, glide: bool, fire_level: int) -> void:
	double_jump_enabled = double_jump
	glide_enabled = glide
	ability_controller.call(
		"set_fire_cooldown",
		ProfileStore.get_fire_cooldown_for_level(fire_level)
	)


func start_movement() -> void:
	active = true
	_can_double_jump = true
	input_controller.call("set_active", true)
	ability_controller.call("set_active", true)


func stop_movement() -> void:
	active = false
	glide_trail.emitting = false
	mouth_flame.emitting = false
	_set_glide_sound_active(false)
	input_controller.call("set_active", false)
	ability_controller.call("set_active", false)
	animation_controller.call("stop")


func initialize_abilities(
		world: Node2D,
		enemy_manager: Node,
		camera: Camera2D
	) -> void:
	ability_controller.call("initialize", world, enemy_manager, camera)


func request_fire() -> void:
	ability_controller.call("request_fire")


func get_jump_height() -> float:
	return (JUMP_VELOCITY * JUMP_VELOCITY) / (2.0 * GRAVITY)


func _apply_platform_landing() -> void:
	_play_sfx(&"sfx_jump")
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if collision.get_normal().y < -0.5:
			_spawn_jump_dust(collision.get_position())
			var platform := collision.get_collider()
			if platform and platform.has_method("on_player_landed"):
				platform.call("on_player_landed", self)
			break

	# Spring platforms set a negative velocity above. Every other landing keeps
	# the original M1 automatic jump unchanged.
	if velocity.y >= 0.0:
		velocity.y = JUMP_VELOCITY


func _spawn_jump_dust(world_position: Vector2) -> void:
	var effect_parent := get_parent()
	if effect_parent == null:
		return
	var dust := JUMP_DUST_SCENE.instantiate() as CPUParticles2D
	effect_parent.add_child(dust)
	dust.global_position = world_position
	dust.finished.connect(dust.queue_free)
	dust.emitting = true


func _spawn_flap_puff() -> void:
	var effect_parent := get_parent()
	if effect_parent == null:
		return
	var puff := FLAP_PUFF_SCENE.instantiate() as CPUParticles2D
	effect_parent.add_child(puff)
	puff.global_position = global_position + Vector2(0.0, 30.0)
	puff.finished.connect(puff.queue_free)
	puff.emitting = true


func _wrap_around_screen() -> void:
	if global_position.x < 0.0:
		global_position.x = GAME_WIDTH
	elif global_position.x > GAME_WIDTH:
		global_position.x = 0.0


func _on_fire_cooldown_changed(is_on_cooldown: bool) -> void:
	if is_on_cooldown:
		animation_controller.call("trigger_fire")
		mouth_flame.restart()


func _set_glide_sound_active(is_gliding: bool) -> void:
	if is_gliding == _glide_sound_active:
		return
	_glide_sound_active = is_gliding
	var audio_manager := _get_audio_manager()
	if audio_manager == null:
		return
	if _glide_sound_active:
		audio_manager.call("play_sfx", &"sfx_glide")
	else:
		audio_manager.call("stop_sfx", &"sfx_glide")


func _play_sfx(sound_name: StringName) -> void:
	var audio_manager := _get_audio_manager()
	if audio_manager != null:
		audio_manager.call("play_sfx", sound_name)


func _get_audio_manager() -> Node:
	return get_tree().get_first_node_in_group(&"audio_manager")
