extends "res://scripts/Background.gd"

## Atmosphere shares the menu backdrop lifetime, including Shop and Settings.
var _elapsed := 0.0


func _apply_layout() -> void:
	super._apply_layout()
	scroll_offset = Vector2(0, ScreenLayout.visible_size.y - ScreenLayout.BASE_HEIGHT)
	var viewport_size := ScreenLayout.visible_size
	var glow := $Atmosphere/FireGlow as TextureRect
	var glow_height := viewport_size.y * 0.26
	glow.position = Vector2(0, viewport_size.y - glow_height)
	glow.size = Vector2(viewport_size.x, glow_height)
	var embers := $Atmosphere/Embers as CPUParticles2D
	embers.position = Vector2(viewport_size.x * 0.5, viewport_size.y)
	embers.emission_rect_extents = Vector2(viewport_size.x * 0.5, 12.0)
	# Fade out around 38 % of the visible height at ~170 px/s average rise.
	embers.lifetime = clampf(viewport_size.y * 0.38 / 170.0, 2.5, 6.0)
	_place_islands()


func _place_islands() -> void:
	var viewport_size := ScreenLayout.visible_size
	$Atmosphere/FarIsland.position = Vector2(72, viewport_size.y * 0.40) + Vector2(sin(_elapsed * TAU / 9.0) * 18.0, sin(_elapsed * TAU / 6.5) * 12.0)
	$Atmosphere/NearIsland.position = Vector2(viewport_size.x - 70, viewport_size.y * 0.53) + Vector2(sin(_elapsed * TAU / 11.0) * 22.0, sin(_elapsed * TAU / 4.8) * 16.0)


func _process(delta: float) -> void:
	_elapsed += delta
	$FarClouds.motion_offset.x = fposmod($FarClouds.motion_offset.x + 12.0 * delta, 1080.0)
	$NearClouds.motion_offset.x = fposmod($NearClouds.motion_offset.x + 24.0 * delta, 1080.0)
	_place_islands()
