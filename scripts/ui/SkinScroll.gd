extends ScrollContainer

## Mouse and touch drags share a deadzone and cancel buttons before GUI release.
const UiFx := preload("res://scripts/ui/UiFx.gd")

var _tracking := false
var _dragging := false
var _touch_index := -1
var _origin := Vector2.ZERO
var _scroll_origin := 0
var _cancelled_buttons: Array[BaseButton] = []


func _ready() -> void:
	visibility_changed.connect(_reset_gesture)


func is_dragging() -> bool:
	return _dragging


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and not _tracking:
			_begin(event.position, event.index)
		elif not event.pressed and event.index == _touch_index:
			_end()
	elif event is InputEventScreenDrag and _tracking and event.index == _touch_index:
		_move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and _touch_index < 0:
		if event.pressed:
			_begin(event.position, -1)
		else:
			_end()
	elif event is InputEventMouseMotion and _tracking and _touch_index < 0:
		_move(event.position)


func _begin(point: Vector2, touch_index: int) -> void:
	if not get_global_rect().has_point(point):
		return
	var scrollbar := get_v_scroll_bar()
	if scrollbar.is_visible_in_tree() and scrollbar.get_global_rect().has_point(point):
		return
	_reset_gesture()
	_tracking = true
	_touch_index = touch_index
	_origin = point
	_scroll_origin = scroll_vertical


func _move(point: Vector2) -> void:
	if not _dragging and point.distance_to(_origin) > scroll_deadzone:
		_dragging = true
		for button in find_children("*", "BaseButton", true, false):
			if not button.disabled:
				_cancelled_buttons.append(button)
				button.disabled = true
				UiFx.stop(button, &"press")
				button.scale = Vector2.ONE
	if _dragging:
		scroll_vertical = _scroll_origin + roundi(_origin.y - point.y)
		get_viewport().set_input_as_handled()


func _end() -> void:
	if not _tracking:
		return
	if _dragging:
		get_viewport().set_input_as_handled()
		_reset_gesture.call_deferred()
	else:
		_reset_gesture()


func _reset_gesture() -> void:
	for button in _cancelled_buttons:
		if is_instance_valid(button):
			button.disabled = false
	_cancelled_buttons.clear()
	_tracking = false
	_dragging = false
	_touch_index = -1
