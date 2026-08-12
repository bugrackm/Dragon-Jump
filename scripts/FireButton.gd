extends Button

## Floating fire button with exclusive touch capture.

signal fire_requested

var _fire_enabled := true


func _gui_input(event: InputEvent) -> void:
	accept_event()
	if not _fire_enabled:
		return

	if event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			fire_requested.emit()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if (
			mouse_event.device != InputEvent.DEVICE_ID_EMULATION
			and mouse_event.button_index == MOUSE_BUTTON_LEFT
			and mouse_event.pressed
		):
			fire_requested.emit()


func set_state(enabled: bool) -> void:
	_fire_enabled = enabled
	self_modulate = Color(1.0, 1.0, 1.0, 1.0 if _fire_enabled else 0.45)
