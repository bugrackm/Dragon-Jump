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
var _touch_state: TouchState = TouchState.IDLE
var _primary_touch_index := -1
var _touch_direction := 0.0
var _held_touches := {}  # touch index -> side direction, in press order
var _state_elapsed := 0.0
var _tilt_output := 0.0
var _double_jump_requested := false
var _fire_requested := false
var _space_is_down := false
var _keyboard_glide_blocked := false
var _last_space_press_msec := -KEYBOARD_DOUBLE_PRESS_MSEC


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
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
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
	_held_touches.clear()
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
			# Overlapping press: the last pressed finger wins.
			_begin_touch(touch, _overlap_state())
	elif _held_touches.has(touch.index):
		_held_touches.erase(touch.index)
		if touch.index == _primary_touch_index:
			if _held_touches.is_empty():
				_release_primary_touch()
			else:
				# Fall back to the most recently pressed finger still down.
				_primary_touch_index = _held_touches.keys().back()
				_touch_direction = _held_touches[_primary_touch_index]
				_touch_state = _overlap_state()
				_state_elapsed = 0.0
	else:
		return

	_refresh_outputs()
	get_viewport().set_input_as_handled()


func _handle_screen_drag(drag: InputEventScreenDrag) -> void:
	if not _held_touches.has(drag.index):
		return

	var direction := _side_direction(drag.position.x)
	_held_touches[drag.index] = direction
	if drag.index == _primary_touch_index:
		_touch_direction = direction
	_refresh_outputs()


func _overlap_state() -> TouchState:
	return TouchState.GLIDING if _touch_state == TouchState.GLIDING else TouchState.HOLDING


func _side_direction(x: float) -> float:
	return -1.0 if x < ScreenLayout.GAME_WIDTH * 0.5 else 1.0


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
	_touch_direction = _side_direction(touch.position.x)
	_held_touches.erase(touch.index)
	_held_touches[touch.index] = _touch_direction
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
	var finger_down := (
		_touch_state == TouchState.FIRST_DOWN
		or _touch_state == TouchState.HOLDING
		or _touch_state == TouchState.SECOND_DOWN
		or _touch_state == TouchState.GLIDING
	)
	var touch_output := _touch_direction if finger_down else 0.0
	horizontal_direction = clampf(touch_output + _tilt_output, -1.0, 1.0)
	glide_active = (
		_touch_state == TouchState.GLIDING
		or (_space_is_down and not _keyboard_glide_blocked)
	)


func _reset_touch() -> void:
	_touch_state = TouchState.IDLE
	_primary_touch_index = -1
	_held_touches.clear()
	_touch_direction = 0.0
	_state_elapsed = 0.0
