extends Node

## Canvas geometry. Insets use Vector4(left, top, right, bottom), in virtual px.
signal layout_changed

const GAME_WIDTH := 1080.0
const BASE_HEIGHT := 1920.0

var visible_size := Vector2(GAME_WIDTH, BASE_HEIGHT)
var safe_insets := Vector4.ZERO
## Vector4(-1, -1, -1, -1) disables the override; other values replace real insets.
@export var debug_insets_override := Vector4(-1, -1, -1, -1):
	set(value):
		debug_insets_override = value
		if is_inside_tree():
			refresh()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_read_debug_args()
	get_tree().root.size_changed.connect(refresh)
	refresh()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		if is_inside_tree():
			refresh.call_deferred()


func refresh() -> void:
	var next_size := get_viewport().get_visible_rect().size
	var next_insets := Vector4.ZERO
	if debug_insets_override != Vector4(-1, -1, -1, -1):
		next_insets = debug_insets_override.max(Vector4.ZERO)
	elif DisplayServer.get_name() != "headless":
		var window_px := Vector2(DisplayServer.window_get_size())
		var safe_rect := Rect2(DisplayServer.get_display_safe_area())
		# Desktop safe areas are screen-relative, whereas a window may be anywhere.
		# Only fullscreen desktop windows share the display's coordinate space.
		var fullscreen := DisplayServer.window_get_mode() in [
			DisplayServer.WINDOW_MODE_FULLSCREEN,
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
		]
		if OS.has_feature("mobile") or fullscreen:
			if not OS.has_feature("mobile"):
				safe_rect.position -= Vector2(DisplayServer.window_get_position())
			next_insets = compute_safe_insets(safe_rect, window_px, next_size)
	if not visible_size.is_equal_approx(next_size) or not safe_insets.is_equal_approx(next_insets):
		visible_size = next_size
		safe_insets = next_insets
		layout_changed.emit()


func half_height() -> float:
	return visible_size.y * 0.5


func visible_top(camera_y: float) -> float:
	return camera_y - half_height()


func visible_bottom(camera_y: float) -> float:
	return camera_y + half_height()


static func compute_visible_size(screen_px: Vector2) -> Vector2:
	if screen_px.x <= 0.0 or screen_px.y <= 0.0:
		return Vector2(GAME_WIDTH, BASE_HEIGHT)
	return Vector2(GAME_WIDTH, maxf(BASE_HEIGHT, GAME_WIDTH * screen_px.y / screen_px.x))


static func compute_safe_insets(safe_rect_px: Rect2, screen_px: Vector2,
		visible: Vector2) -> Vector4:
	if screen_px.x <= 0.0 or screen_px.y <= 0.0 or visible.x <= 0.0 or visible.y <= 0.0:
		return Vector4.ZERO
	var scale_factor := minf(screen_px.x / visible.x, screen_px.y / visible.y)
	var content_size := visible * scale_factor
	var content := Rect2((screen_px - content_size) * 0.5, content_size)
	var safe_content := content.intersection(safe_rect_px)
	# Empty/invalid display reports cannot describe this window's safe region.
	if not safe_content.has_area():
		return Vector4.ZERO
	return Vector4(
		safe_content.position.x - content.position.x,
		safe_content.position.y - content.position.y,
		content.end.x - safe_content.end.x,
		content.end.y - safe_content.end.y
	).max(Vector4.ZERO) / scale_factor


func _read_debug_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--fake-safe-area="):
			continue
		var parts := argument.trim_prefix("--fake-safe-area=").split(",")
		if parts.size() != 2 and parts.size() != 4:
			push_warning("Expected --fake-safe-area=TOP,BOTTOM[,LEFT,RIGHT] in virtual px")
			continue
		var valid := true
		for part in parts:
			valid = valid and part.is_valid_float()
		if not valid:
			push_warning("Safe-area override values must be numbers")
			continue
		debug_insets_override = Vector4(
			float(parts[2]) if parts.size() == 4 else 0.0,
			float(parts[0]),
			float(parts[3]) if parts.size() == 4 else 0.0,
			float(parts[1])
		)
