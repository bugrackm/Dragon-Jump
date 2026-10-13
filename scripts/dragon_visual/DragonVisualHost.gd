extends Node2D

## Owns the current visual. Skins may supply a visual_scene PackedScene or an optional visual_scene_path.

signal visual_changed(visual: Node)

@onready var _visual: Node = $Sprite

var _visual_scene: PackedScene = preload("res://scenes/dragon_visuals/SpriteDragonVisual.tscn")


func get_visual() -> Node:
	return _visual


func apply_skin(skin: Resource) -> void:
	var visual_scene: PackedScene
	if skin != null and "visual_scene" in skin:
		visual_scene = skin.get("visual_scene") as PackedScene
	elif skin != null and "visual_scene_path" in skin:
		var scene_path: String = skin.get("visual_scene_path")
		if not scene_path.is_empty():
			visual_scene = load(scene_path) as PackedScene
	if visual_scene != null and visual_scene != _visual_scene:
		var next_visual := visual_scene.instantiate()
		remove_child(_visual)
		_visual.queue_free()
		_visual = next_visual
		_visual_scene = visual_scene
		_visual.name = "Visual"
		add_child(_visual)
		visual_changed.emit(_visual)
	_visual.apply_skin(skin)
