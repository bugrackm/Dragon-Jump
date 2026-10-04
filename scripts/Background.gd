extends ParallaxBackground


func _ready() -> void:
	ScreenLayout.layout_changed.connect(_apply_layout)
	_apply_layout()


func _apply_layout() -> void:
	var height := ScreenLayout.visible_size.y
	var sky := $Sky/Sprite as Sprite2D
	sky.position = ScreenLayout.visible_size * 0.5
	sky.scale = Vector2(
		maxf(ScreenLayout.BASE_HEIGHT, ScreenLayout.visible_size.x),
		maxf(ScreenLayout.BASE_HEIGHT, height)
	) / sky.texture.get_size()
	# At run start the camera canvas translation is height - BASE_HEIGHT.
	# Parallax applies only motion_scale of that translation; compensate the
	# remainder so every landscape's bottom still lands at the visible bottom.
	for layer_name in ["FarLandscape", "MidLandscape", "NearLandscape"]:
		var landscape := get_node(layer_name) as ParallaxLayer
		var sprite := landscape.get_node("Sprite") as Sprite2D
		sprite.position.y = ScreenLayout.BASE_HEIGHT * 0.5 + (
			(height - ScreenLayout.BASE_HEIGHT) * (1.0 - landscape.motion_scale.y)
		)
