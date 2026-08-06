extends CharacterBody2D

## Minimal M1 dragon controller: automatic jumping and horizontal steering.

const GRAVITY := 2400.0
const JUMP_VELOCITY := -1150.0
const MOVE_SPEED := 520.0
const TOUCH_TAP_MOVE_SECONDS := 0.22

var active := false
var _screen_width := 1080.0
var _touch_direction := 0.0
var _touch_index := -1
var _touch_is_down := false
var _tap_move_time_left := 0.0


func _ready() -> void:
	_screen_width = get_viewport_rect().size.x


func _physics_process(delta: float) -> void:
	if not active:
		velocity = Vector2.ZERO
		return

	if not _touch_is_down:
		_tap_move_time_left = maxf(0.0, _tap_move_time_left - delta)
		if is_zero_approx(_tap_move_time_left):
			_touch_direction = 0.0

	var keyboard_direction := Input.get_axis("ui_left", "ui_right")
	var horizontal_input := clampf(keyboard_direction + _touch_direction, -1.0, 1.0)
	velocity.x = horizontal_input * MOVE_SPEED
	velocity.y += GRAVITY * delta
	var was_descending := velocity.y >= 0.0

	move_and_slide()

	# One-way platform contacts become floors only while the player is descending.
	if was_descending and is_on_floor():
		_apply_platform_landing()

	_wrap_around_screen()


func _unhandled_input(event: InputEvent) -> void:
	if not active or not event is InputEventScreenTouch:
		return

	var touch := event as InputEventScreenTouch
	if touch.pressed and _touch_index == -1:
		_touch_index = touch.index
		_touch_is_down = true
		_touch_direction = -1.0 if touch.position.x < _screen_width * 0.5 else 1.0
		_tap_move_time_left = TOUCH_TAP_MOVE_SECONDS
		get_viewport().set_input_as_handled()
	elif not touch.pressed and touch.index == _touch_index:
		_touch_index = -1
		_touch_is_down = false
		get_viewport().set_input_as_handled()


func start_movement() -> void:
	active = true


func stop_movement() -> void:
	active = false
	_touch_index = -1
	_touch_is_down = false
	_touch_direction = 0.0
	_tap_move_time_left = 0.0


func get_jump_height() -> float:
	return (JUMP_VELOCITY * JUMP_VELOCITY) / (2.0 * GRAVITY)


func _apply_platform_landing() -> void:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if collision.get_normal().y < -0.5:
			var platform := collision.get_collider()
			if platform and platform.has_method("on_player_landed"):
				platform.call("on_player_landed", self)
			break

	# Spring platforms set a negative velocity above. Every other landing keeps
	# the original M1 automatic jump unchanged.
	if velocity.y >= 0.0:
		velocity.y = JUMP_VELOCITY


func _wrap_around_screen() -> void:
	if global_position.x < 0.0:
		global_position.x = _screen_width
	elif global_position.x > _screen_width:
		global_position.x = 0.0
