extends SceneTree

## Builds the shared cartoon UI theme, including embedded toggle and slider art.
const SKY := Color("3ea4fc")
const SKY_DARK := Color("1e6fc0")
const GRASS := Color("5bc236")
const GRASS_DARK := Color("2e7d1e")
const TITLE_OUTLINE := Color("1b5e20")
const INK := Color("1a2e4a")
const GOLD := Color("ffd23f")
const FIRE := Color("ff8a1f")
const FIRE_DARK := Color("c2410c")
const CARD := Color(1.0, 0.9764706, 0.9254902, 0.92)
const DISABLED := Color("b8c2cc")
const WHITE := Color.WHITE

var _theme := Theme.new()
var _title: Font = load("res://assets/ui/fonts/LilitaOne-Regular.ttf")
var _body: Font
var _resource_count := 0


func _initialize() -> void:
	var fredoka: Font = load("res://assets/ui/fonts/Fredoka-Variable.ttf")
	var weight := TextServerManager.get_primary_interface().name_to_tag("wght")
	if fredoka.get_supported_variation_list().has(weight):
		var variation := FontVariation.new()
		variation.base_font = fredoka
		variation.variation_opentype = {weight: 600.0}
		_body = variation
	else:
		_body = _title
		push_warning("Fredoka weight axis unavailable; using Lilita for body text.")
	_theme.default_font = _body
	_theme.default_font_size = 36
	_button("Button", GRASS, GRASS_DARK)
	_button("SecondaryButton", SKY, SKY_DARK)
	_button("AccentButton", FIRE, FIRE_DARK)
	_button("IconButton", SKY, SKY_DARK)
	_button("FireButton", FIRE, FIRE_DARK, 70)
	_theme.set_constant("icon_max_width", "IconButton", 72)
	_theme.set_font_size("font_size", "FireButton", 34)
	_label("Label", _body, 36, INK)
	_label("TitleLabel", _title, 110, WHITE, TITLE_OUTLINE, 18)
	_theme.set_color("font_shadow_color", "TitleLabel", TITLE_OUTLINE.darkened(0.3))
	_theme.set_constant("shadow_offset_x", "TitleLabel", 0)
	_theme.set_constant("shadow_offset_y", "TitleLabel", 10)
	_theme.set_constant("shadow_outline_size", "TitleLabel", 12)
	_label("HeaderLabel", _title, 72, WHITE, TITLE_OUTLINE, 12)
	_label("StatLabel", _title, 44, GOLD, INK, 8)
	_label("HudLabel", _title, 56, WHITE, INK, 8)
	_label("HudSubLabel", _title, 36, WHITE, INK, 6)
	_label("BadgeLabel", _title, 36, WHITE)
	_label("ShopNameLabel", _body, 38, INK)
	_label("ShopPriceLabel", _title, 38, GOLD, INK, 6)
	_panel("Card", CARD, 40, 8, 48)
	var card := _theme.get_stylebox("panel", "Card") as StyleBoxFlat
	card.shadow_color = Color(INK, 0.3)
	card.shadow_size = 16
	card.shadow_offset = Vector2(0, 10)
	_panel("ShopRow", Color(1, 1, 1, 0.72), 24, 4, 16)
	_panel("Badge", FIRE, 32, 4, 12)
	_toggles()
	_slider()
	_name_subresources(_theme, {})
	DirAccess.make_dir_recursive_absolute("res://assets/ui/theme")
	var error := ResourceSaver.save(_theme, "res://assets/ui/theme/dragon_theme.tres")
	if error != OK:
		push_error("Theme save failed: %s" % error_string(error))
		quit(1)
		return
	print("UI theme generated; body font: %s" % _body.get_font_name())
	quit()


func _box(color: Color, radius: int, border: int, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = INK
	box.set_corner_radius_all(radius)
	box.set_border_width_all(border)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box


func _button(type: StringName, face: Color, dark: Color, radius := 28) -> void:
	if type != &"Button":
		_theme.set_type_variation(type, "Button")
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var color := face
		if state == "hover":
			color = face.lightened(0.12)
		elif state == "disabled":
			color = DISABLED
		var box := _box(color, radius, 6, 14)
		box.content_margin_left = 24
		box.content_margin_right = 24
		if state in ["pressed", "hover_pressed"]:
			box.bg_color = face.lerp(dark, 0.15)
			box.expand_margin_top = -6
			box.expand_margin_bottom = 6
			box.content_margin_top += 6
			box.content_margin_bottom -= 6
		elif state != "disabled":
			box.shadow_color = Color(INK, 0.6)
			box.shadow_offset = Vector2(0, 8)
			box.shadow_size = 1
		_theme.set_stylebox(state, type, box)
	var focus := _box(Color.TRANSPARENT, radius, 4, 0)
	focus.border_color = GOLD
	focus.set_expand_margin_all(3)
	_theme.set_stylebox("focus", type, focus)
	_theme.set_font("font", type, _title)
	_theme.set_font_size("font_size", type, 44)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_theme.set_color(state, type, WHITE)
	_theme.set_color("font_disabled_color", type, Color(1, 1, 1, 0.8))
	_theme.set_color("font_outline_color", type, INK)
	_theme.set_constant("outline_size", type, 6)
	_theme.set_constant("h_separation", type, 18)
	_theme.set_constant("icon_max_width", type, 48)


func _label(type: StringName, font: Font, size: int, color: Color,
		outline := Color.TRANSPARENT, outline_size := 0) -> void:
	if type != &"Label":
		_theme.set_type_variation(type, "Label")
	_theme.set_font("font", type, font)
	_theme.set_font_size("font_size", type, size)
	_theme.set_color("font_color", type, color)
	_theme.set_color("font_outline_color", type, outline)
	_theme.set_constant("outline_size", type, outline_size)


func _panel(type: StringName, color: Color, radius: int, border: int, padding: int) -> void:
	_theme.set_type_variation(type, "PanelContainer")
	_theme.set_stylebox("panel", type, _box(color, radius, border, padding))


## Rasterize capsules with a dark outline and a white circular thumb.
func _toggle_texture(on: bool, disabled: bool) -> ImageTexture:
	var image := Image.create(112, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in 64:
		for x in 112:
			var point := Vector2(x + 0.5, y + 0.5)
			var distance := point.distance_to(Vector2(clampf(point.x, 32, 80), 32))
			if distance <= 31:
				var face := GRASS if on else SKY_DARK
				if disabled:
					face = DISABLED
				image.set_pixel(x, y, INK if distance > 26 else face)
			if point.distance_to(Vector2(80 if on else 32, 32)) <= 22:
				image.set_pixel(x, y, WHITE)
	return ImageTexture.create_from_image(image)


func _toggles() -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		_theme.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	for disabled in [false, true]:
		for on in [false, true]:
			var key := "checked" if on else "unchecked"
			if disabled:
				key += "_disabled"
			var texture := _toggle_texture(on, disabled)
			_theme.set_icon(key, "CheckButton", texture)
			_theme.set_icon(key + "_mirrored", "CheckButton", texture)


func _slider() -> void:
	for item in ["slider", "grabber_area", "grabber_area_highlight"]:
		var track := _box(DISABLED if item == "slider" else GRASS, 10, 3, 0)
		track.content_margin_top = 8
		track.content_margin_bottom = 8
		_theme.set_stylebox(item, "HSlider", track)
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
		var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for y in 48:
			for x in 48:
				var distance := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(24, 24))
				if distance <= 24:
					var face := DISABLED if state == "grabber_disabled" else WHITE
					image.set_pixel(x, y, INK if distance > 19 else face)
		_theme.set_icon(state, "HSlider", ImageTexture.create_from_image(image))


## ResourceSaver otherwise assigns random embedded IDs on each invocation.
func _name_subresources(resource: Resource, visited: Dictionary) -> void:
	if visited.has(resource):
		return
	visited[resource] = true
	if not resource.resource_path.is_empty():
		return
	_resource_count += 1
	resource.resource_scene_unique_id = "%s_%03d" % [resource.get_class(), _resource_count]
	for property in resource.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			var value: Variant = resource.get(property.name)
			if value is Resource:
				_name_subresources(value, visited)
