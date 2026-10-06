extends "res://scripts/Background.gd"

## Reuses the run-start landscape without a camera; only wrapping clouds drift.
func _apply_layout() -> void:
	super._apply_layout()
	scroll_offset = Vector2(0, ScreenLayout.visible_size.y - ScreenLayout.BASE_HEIGHT)


func _process(delta: float) -> void:
	$FarClouds.motion_offset.x = fposmod($FarClouds.motion_offset.x + 12.0 * delta, 1080.0)
	$NearClouds.motion_offset.x = fposmod($NearClouds.motion_offset.x + 24.0 * delta, 1080.0)
