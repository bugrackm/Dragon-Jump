extends SceneTree

## Builds the classic rig from parts.json and captures 1x and 2x runtime previews.

const DATA_PATH := "res://assets/dragon_rig/classic/parts.json"
const OUTPUT_PATH := "res://docs/codex-briefs/ref/rig_018a_godot.png"


func _initialize() -> void:
	_render.call_deferred()


func _load_data() -> Dictionary:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _build_part(name: String, data: Dictionary, atlas: Texture2D, nodes: Dictionary) -> Node2D:
	if nodes.has(name):
		return nodes[name]
	var part: Dictionary = data.parts[name]
	var node := Node2D.new()
	node.name = name
	nodes[name] = node
	var parent_name: String = part.parent
	if parent_name.is_empty():
		return node
	var parent := _build_part(parent_name, data, atlas, nodes)
	parent.add_child(node)
	node.position = Vector2(float(part.offset[0]), float(part.offset[1]))
	return node


func _add_sprites(data: Dictionary, atlas: Texture2D, nodes: Dictionary) -> void:
	for name: String in data.parts:
		var part: Dictionary = data.parts[name]
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = atlas
		sprite.region_enabled = true
		sprite.region_rect = Rect2(
			float(part.region[0]), float(part.region[1]),
			float(part.region[2]), float(part.region[3])
		)
		sprite.centered = false
		sprite.offset = -Vector2(float(part.pivot[0]), float(part.pivot[1]))
		sprite.z_index = int(part.z)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		nodes[name].add_child(sprite)


func _build_rig(data: Dictionary, atlas: Texture2D) -> Node2D:
	var nodes: Dictionary = {}
	for name: String in data.parts:
		_build_part(name, data, atlas, nodes)
	_add_sprites(data, atlas, nodes)
	return nodes[data.root]


func _global_pivots(data: Dictionary) -> Dictionary:
	var result: Dictionary = {data.root: Vector2.ZERO}
	while result.size() < data.parts.size():
		for name: String in data.parts:
			if result.has(name):
				continue
			var part: Dictionary = data.parts[name]
			var parent_name: String = part.parent
			if result.has(parent_name):
				result[name] = result[parent_name] + Vector2(float(part.offset[0]), float(part.offset[1]))
	return result


func _rig_bounds(data: Dictionary) -> Rect2:
	var pivots := _global_pivots(data)
	var bounds := Rect2()
	var first := true
	for name: String in data.parts:
		var part: Dictionary = data.parts[name]
		var top_left: Vector2 = pivots[name] - Vector2(float(part.pivot[0]), float(part.pivot[1]))
		var rect := Rect2(top_left, Vector2(float(part.region[2]), float(part.region[3])))
		bounds = rect if first else bounds.merge(rect)
		first = false
	return bounds


func _render() -> void:
	var data := _load_data()
	var atlas := load("res://assets/dragon_rig/classic/" + String(data.atlas)) as Texture2D
	if data.is_empty() or atlas == null:
		printerr("rig_preview=FAIL data_or_atlas")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(500, 330)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("e8eaed")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var bounds := _rig_bounds(data)
	var texture_scale := float(data.texture_scale)
	var rig_1x := _build_rig(data, atlas)
	rig_1x.scale = Vector2.ONE * texture_scale
	rig_1x.position = Vector2(24.0, 42.0) - bounds.position * texture_scale
	viewport.add_child(rig_1x)
	var rig_2x := _build_rig(data, atlas)
	rig_2x.scale = Vector2.ONE * texture_scale * 2.0
	rig_2x.position = Vector2(190.0, 42.0) - bounds.position * texture_scale * 2.0
	viewport.add_child(rig_2x)
	await process_frame
	await process_frame
	await process_frame
	var scaled_size := bounds.size * texture_scale
	if DisplayServer.get_name() == "headless":
		print(
			"rig_preview=CHECK_ONLY capture=UNAVAILABLE nodes=%d bbox_atlas=%dx%d bbox_game=%.2fx%.2f" % [
				data.parts.size(), int(round(bounds.size.x)), int(round(bounds.size.y)), scaled_size.x, scaled_size.y,
			]
		)
		quit(0)
		return
	var image := viewport.get_texture().get_image()
	if image == null:
		printerr("rig_preview=FAIL capture_image_is_null")
		quit(1)
		return
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print(
		"rig_preview=%s nodes=%d bbox_atlas=%dx%d bbox_game=%.2fx%.2f" % [
			"PASS" if error == OK else "FAIL", data.parts.size(),
			int(round(bounds.size.x)), int(round(bounds.size.y)), scaled_size.x, scaled_size.y,
		]
	)
	quit(0 if error == OK else 1)
