extends Node

## Owns touch gestures, tilt input, and raw keyboard ability shortcuts.

enum TouchState {
	IDLE,
	FIRST_DOWN,
	HOLDING,
	FIRST_TAP_WINDOW,
	SECOND_DOWN,
	GLIDING,
}

const FIRST_TAP_MAX_SECONDS := 0.20
const DOUBLE_TAP_WINDOW_SECONDS := 0.30
const SECOND_HOLD_SECONDS := 0.15
const TILT_DEAD_ZONE := 0.15
const TILT_SMOOTHING := 0.15
const KEYBOARD_DOUBLE_PRESS_MSEC := 300

var horizontal_direction := 0.0
var glide_active := false

var _active := false
var _screen_width := 1080.0
var _touch_state: TouchState = TouchState.IDLE
var _primary_touch_index := -1
var _touch_direction := 0.0
var _state_elapsed := 0.0
var _tilt_output := 0.0
var _double_jump_requested := false
var _fire_requested := false
var _space_is_down := false
var _keyboard_glide_blocked := false
var _last_space_press_msec := -KEYBOARD_DOUBLE_PRESS_MSEC


func _ready() -> void:
	_screen_width = get_viewport().get_visible_rect().size.x


func _process(delta: float) -> void:
	if not _active:
		return

	_advance_touch_state(delta)
	_update_tilt()
	_refresh_outputs()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventKey:
		_handle_key(event as InputEventKey)


func consume_double_jump_request() -> bool:
	var was_requested := _double_jump_requested
	_double_jump_requested = false
	return was_requested


func consume_fire_request() -> bool:
	var was_requested := _fire_requested
	_fire_requested = false
	return was_requested


func set_active(is_active: bool) -> void:
	_active = is_active
	if _active:
		return

	_touch_state = TouchState.IDLE
	_primary_touch_index = -1
	_touch_direction = 0.0
	_state_elapsed = 0.0
	_tilt_output = 0.0
	_double_jump_requested = false
	_fire_requested = false
	_space_is_down = false
	_keyboard_glide_blocked = false
	_last_space_press_msec = -KEYBOARD_DOUBLE_PRESS_MSEC
	horizontal_direction = 0.0
	glide_active = false


func cancel_glide_on_landing() -> void:
	if _touch_state == TouchState.GLIDING:
		_touch_state = TouchState.HOLDING
		_state_elapsed = 0.0
	if _space_is_down:
		_keyboard_glide_blocked = true
	_refresh_outputs()


func get_touch_state() -> TouchState:
	return _touch_state


func _handle_screen_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		if _touch_state == TouchState.IDLE:
			_begin_touch(touch, TouchState.FIRST_DOWN)
		elif _touch_state == TouchState.FIRST_TAP_WINDOW:
			_begin_touch(touch, TouchState.SECOND_DOWN)
		else:
			return
	elif touch.index == _primary_touch_index:
		_release_primary_touch()
	else:
		return

	_refresh_outputs()
	get_viewport().set_input_as_handled()


func _handle_key(key_event: InputEventKey) -> void:
	if key_event.echo:
		return

	var is_space := (
		key_event.keycode == KEY_SPACE
		or key_event.physical_keycode == KEY_SPACE
	)
	if is_space:
		_space_is_down = key_event.pressed
		if key_event.pressed:
			_keyboard_glide_blocked = false
			var now_msec := Time.get_ticks_msec()
			if now_msec - _last_space_press_msec < KEYBOARD_DOUBLE_PRESS_MSEC:
				_double_jump_requested = true
			_last_space_press_msec = now_msec
		else:
			_keyboard_glide_blocked = false
		_refresh_outputs()
		get_viewport().set_input_as_handled()
		return

	var is_fire := key_event.keycode == KEY_F or key_event.physical_keycode == KEY_F
	if is_fire and key_event.pressed:
		_fire_requested = true
		get_viewport().set_input_as_handled()


func _begin_touch(touch: InputEventScreenTouch, next_state: TouchState) -> void:
	_primary_touch_index = touch.index
	_touch_direction = -1.0 if touch.position.x < _screen_width * 0.5 else 1.0
	_touch_state = next_state
	_state_elapsed = 0.0


func _release_primary_touch() -> void:
	match _touch_state:
		TouchState.FIRST_DOWN:
			if _state_elapsed <= FIRST_TAP_MAX_SECONDS:
				_touch_state = TouchState.FIRST_TAP_WINDOW
			else:
				_reset_touch()
		TouchState.HOLDING:
			_reset_touch()
		TouchState.SECOND_DOWN:
			if _state_elapsed < SECOND_HOLD_SECONDS:
				_double_jump_requested = true
			_reset_touch()
		TouchState.GLIDING:
			_reset_touch()
		_:
			_reset_touch()

	if _touch_state == TouchState.FIRST_TAP_WINDOW:
		_primary_touch_index = -1
		_state_elapsed = 0.0


func _advance_touch_state(delta: float) -> void:
	_state_elapsed += delta
	match _touch_state:
		TouchState.FIRST_DOWN:
			if _state_elapsed > FIRST_TAP_MAX_SECONDS:
				_touch_state = TouchState.HOLDING
				_state_elapsed = 0.0
		TouchState.FIRST_TAP_WINDOW:
			if _state_elapsed >= DOUBLE_TAP_WINDOW_SECONDS:
				_reset_touch()
		TouchState.SECOND_DOWN:
			if _state_elapsed >= SECOND_HOLD_SECONDS:
				_touch_state = TouchState.GLIDING
				_state_elapsed = 0.0


func _update_tilt() -> void:
	var accelerometer := Input.get_accelerometer()
	var target := 0.0
	if accelerometer != Vector3.ZERO and absf(accelerometer.x) >= TILT_DEAD_ZONE:
		target = clampf(accelerometer.x, -1.0, 1.0)
	_tilt_output = lerpf(_tilt_output, target, TILT_SMOOTHING)


func _refresh_outputs() -> void:
	var touch_output := 0.0 if _touch_state == TouchState.IDLE else _touch_direction
	horizontal_direction = clampf(touch_output + _tilt_output, -1.0, 1.0)
	glide_active = (
		_touch_state == TouchState.GLIDING
		or (_space_is_down and not _keyboard_glide_blocked)
	)


func _reset_touch() -> void:
	_touch_state = TouchState.IDLE
	_primary_touch_index = -1
	_touch_direction = 0.0
	_state_elapsed = 0.0
