extends RefCounted

## Shared, interruptible UI effects that keep running while gameplay is paused.
const OPEN_DURATION := 0.24
const CLOSE_DURATION := 0.12
const TRANSIENT_SLOTS := [&"press", &"bounce", &"count", &"badge", &"numbers"]


static func stop(node: Node, slot: StringName) -> void:
	var key := StringName("ui_fx_" + slot)
	if node.has_meta(key):
		var tween: Tween = node.get_meta(key)
		if tween != null and tween.is_valid():
			tween.kill()
		node.remove_meta(key)


static func tween_for(node: Node, slot: StringName) -> Tween:
	stop(node, slot)
	var tween := node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	node.set_meta(StringName("ui_fx_" + slot), tween)
	return tween


static func _reset(layer: CanvasLayer) -> void:
	var background := layer.get_node("Background") as Control
	var center := layer.get_node("CenterContainer") as Control
	var card := layer.get_node("%Card") as Control
	if not background.has_meta(&"ui_fx_mouse_filter"):
		background.set_meta(&"ui_fx_mouse_filter", background.mouse_filter)
	background.mouse_filter = background.get_meta(&"ui_fx_mouse_filter")
	background.modulate.a = 1.0
	center.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	center.modulate.a = 1.0
	card.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	card.modulate.a = 1.0
	card.scale = Vector2.ONE
	card.pivot_offset_ratio = Vector2(0.5, 0.5)
	layer.remove_meta(&"closing")


static func _stop_transients(node: Node) -> void:
	for slot in TRANSIENT_SLOTS:
		if node is Control and slot in [&"press", &"bounce", &"badge"] and node.has_meta(StringName("ui_fx_" + slot)):
			node.scale = Vector2.ONE
		stop(node, slot)
	for child in node.get_children():
		_stop_transients(child)


static func open_screen(layer: CanvasLayer) -> void:
	stop(layer, &"screen")
	_stop_transients(layer)
	_reset(layer)
	layer.visible = true
	var card := layer.get_node("%Card") as Control
	var background := layer.get_node("Background") as Control
	card.scale = Vector2.ONE * 0.85
	background.modulate.a = 0.0
	var tween := tween_for(layer, &"screen").set_parallel()
	tween.tween_property(card, "scale", Vector2.ONE, OPEN_DURATION).from(Vector2.ONE * 0.85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(background, "modulate:a", 1.0, 0.15)


static func close_screen(layer: CanvasLayer) -> void:
	stop(layer, &"screen")
	_stop_transients(layer)
	layer.set_meta(&"closing", true)
	var background := layer.get_node("Background") as Control
	var center := layer.get_node("CenterContainer") as Control
	var card := layer.get_node("%Card") as Control
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	card.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	var tween := tween_for(layer, &"screen").set_parallel()
	tween.tween_property(background, "modulate:a", 0.0, CLOSE_DURATION)
	tween.tween_property(center, "modulate:a", 0.0, CLOSE_DURATION)
	tween.chain().tween_callback(func() -> void:
		layer.visible = false
		_reset(layer)
	)


static func hide_now(layer: CanvasLayer) -> void:
	stop(layer, &"screen")
	_stop_transients(layer)
	layer.visible = false
	_reset(layer)


static func is_closing(layer: CanvasLayer) -> bool:
	return bool(layer.get_meta(&"closing", false))


static func wire_press_fx(root: Node) -> void:
	for node in root.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button.has_signal("fire_requested") or button.has_meta(&"ui_fx_wired"):
			continue
		button.set_meta(&"ui_fx_wired", true)
		button.pivot_offset_ratio = Vector2(0.5, 0.5)
		button.button_down.connect(func() -> void:
			tween_for(button, &"press").tween_property(button, "scale", Vector2.ONE * 0.94, 0.06)
		)
		button.button_up.connect(func() -> void:
			tween_for(button, &"press").tween_property(button, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		)
		button.visibility_changed.connect(func() -> void:
			if not button.is_visible_in_tree():
				stop(button, &"press")
				button.scale = Vector2.ONE
		)


static func bounce(control: Control) -> void:
	control.pivot_offset_ratio = Vector2(0.5, 0.5)
	var tween := tween_for(control, &"bounce")
	tween.tween_property(control, "scale", Vector2.ONE * 1.12, 0.08)
	tween.tween_property(control, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func count_up(label: Label, fmt: String, to: int, dur: float) -> Tween:
	label.text = fmt % 0
	var tween := tween_for(label, &"count")
	tween.tween_method(func(value: int) -> void: label.text = fmt % value, 0, to, dur)
	return tween


static func pop_badge(control: Control) -> void:
	control.visible = true
	control.pivot_offset_ratio = Vector2(0.5, 0.5)
	control.scale = Vector2.ONE * 0.5
	tween_for(control, &"badge").tween_property(control, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func idle_bob(control: Control, amplitude: float, period: float) -> void:
	if not control.has_meta(&"ui_fx_idle_origin"):
		control.set_meta(&"ui_fx_idle_origin", control.position)
	var origin: Vector2 = control.get_meta(&"ui_fx_idle_origin")
	control.pivot_offset_ratio = Vector2(0.5, 0.5)
	var tween := tween_for(control, &"idle").set_loops()
	tween.tween_method(func(phase: float) -> void:
		control.position = origin + Vector2(0, sin(phase) * amplitude)
		control.scale = Vector2.ONE * (1.0 + sin(phase) * 0.012)
	, 0.0, TAU, period)
